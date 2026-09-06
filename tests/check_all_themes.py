#!/usr/bin/env python3
"""
tests/check_all_themes.py — theme-agnostic invariants that must hold for
EVERY theme under themes/<name>/, discovered from the filesystem (never a
hardcoded theme list), so a 5th/6th theme is covered automatically:

  - hypr.lua declares name/colors/geometry with the keys windows.lua and
    animations.lua actually read;
  - every component file apply.sh knows how to install for a theme that
    ships it exists and is well-formed (rofi/kitty/swaync/waybar colors,
    hyprlock.conf, brave manifest);
  - a wallpaper pack: wallpapers/<theme>.png (canonical) plus at least 3
    wallpapers/<theme>-*.png variants, all valid truecolor RGB PNGs at
    >=1920x1080, with the canonical file byte-identical to one of them;
  - no theme hardcodes a user/monitor/absolute-repo path.

Dev-time check, no Hyprland/lua required. Gated in tests/run_tests.sh like
tests/check_wallpapers.py.
"""

import json
import os
import re
import struct
import sys
import zlib

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
THEMES_DIR = os.path.join(REPO_ROOT, "themes")
WALLPAPERS_DIR = os.path.join(REPO_ROOT, "wallpapers")

failures = []


def check(name, cond):
    if cond:
        print(f"  ok {name}")
    else:
        print(f"  ✗ {name}")
        failures.append(name)


def read_png_header(path):
    with open(path, "rb") as f:
        data = f.read(33)
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    width, height, bit_depth, color_type = struct.unpack("!IIBB", data[16:26])
    return width, height, bit_depth, color_type


REQUIRED_GEOMETRY_KEYS = {
    "border_size", "gaps_in", "gaps_out", "rounding", "blur_enabled",
    "blur_size", "blur_passes", "blur_noise", "blur_contrast",
    "blur_brightness", "blur_vibrancy", "blur_vibrancy_darkness",
    "shadow_enabled", "active_opacity", "inactive_opacity",
}
REQUIRED_COLOR_KEYS = {
    "background", "background_alt", "surface", "surface_alt", "foreground",
    "foreground_strong", "muted", "subtle", "border_inactive",
    "border_active", "accent",
}

BRAVE_ALLOWED_COLOR_KEYS = {
    "background_tab", "background_tab_inactive",
    "background_tab_incognito", "background_tab_incognito_inactive",
    "bookmark_text", "button_background",
    "frame", "frame_inactive", "frame_incognito", "frame_incognito_inactive",
    "ntp_background", "ntp_header", "ntp_link", "ntp_text",
    "omnibox_background", "omnibox_text",
    "tab_background_text", "tab_background_text_inactive",
    "tab_background_text_incognito", "tab_background_text_incognito_inactive",
    "tab_text", "toolbar", "toolbar_button_icon", "toolbar_text",
}

HARDCODE_PATTERNS = [
    re.compile(r"/home/[a-zA-Z_][a-zA-Z0-9_-]*/"),
    re.compile(r"\bHDMI-A-1\b"),
    re.compile(re.escape(REPO_ROOT)),
]


def strip_lua_comments(text):
    """Drop --[[ ... ]] block comments and full-line/trailing "--" comments
    so a theme's own prose (explaining a blur value, say) never confuses
    the key extraction below."""
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)
    return text


def parse_lua_table_block(text, table_name):
    """Best-effort extraction of `<table_name> = { ... }`'s top-level
    `key = value,` pairs as strings — good enough to check which keys a
    theme's hypr.lua sets without a real Lua parser (none is available in
    this headless environment; see run_tests.sh's own `command -v lua`
    guard for why this repo already tolerates that)."""
    text = strip_lua_comments(text)
    m = re.search(rf"{table_name}\s*=\s*{{", text)
    if not m:
        return None
    depth = 0
    start = m.end() - 1
    i = start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    body = text[start + 1 : i]
    keys = re.findall(r"(?:^|,)\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=", body)
    return set(keys)


def main():
    if not os.path.isdir(THEMES_DIR):
        check("themes/ directory exists", False)
        return finish()

    theme_names = sorted(
        d for d in os.listdir(THEMES_DIR)
        if os.path.isdir(os.path.join(THEMES_DIR, d))
    )
    check(f"at least one theme discovered under themes/ (found: {theme_names})", len(theme_names) > 0)

    for theme in theme_names:
        tdir = os.path.join(THEMES_DIR, theme)
        print(f"-- theme: {theme} --")

        hypr_lua = os.path.join(tdir, "hypr.lua")
        check(f"{theme}: hypr.lua exists", os.path.isfile(hypr_lua))
        if os.path.isfile(hypr_lua):
            text = open(hypr_lua).read()
            check(f"{theme}: hypr.lua declares name = \"{theme}\"",
                  re.search(rf'name\s*=\s*"{re.escape(theme)}"', text) is not None)

            colors = parse_lua_table_block(text, "colors")
            check(f"{theme}: colors table present", colors is not None)
            if colors is not None:
                missing = REQUIRED_COLOR_KEYS - colors
                check(f"{theme}: colors has all keys windows.lua/waybar/etc. expect ({sorted(missing) or 'none missing'})",
                      not missing)

            geometry = parse_lua_table_block(text, "geometry")
            check(f"{theme}: geometry table present", geometry is not None)
            if geometry is not None:
                missing = REQUIRED_GEOMETRY_KEYS - geometry
                check(f"{theme}: geometry has all keys windows.lua expects ({sorted(missing) or 'none missing'})",
                      not missing)

            check(f"{theme}: wallpaper field points at wallpapers/{theme}.png",
                  f'wallpapers/{theme}.png' in text)

            for pat in HARDCODE_PATTERNS:
                check(f"{theme}: hypr.lua has no hardcoded path ({pat.pattern})", not pat.search(text))

        # ---- theme-specific component files (only checked if present —
        # apply.sh always installs the ones a component enables, so a
        # theme MUST ship all of these; brave is optional/best-effort). ----
        for rel in ("rofi/colors.rasi", "kitty/colors.conf", "swaync/colors.css",
                    "waybar/colors.css", "hyprlock.conf"):
            path = os.path.join(tdir, rel)
            check(f"{theme}: {rel} present", os.path.isfile(path))
            if os.path.isfile(path):
                text = open(path).read()
                for pat in HARDCODE_PATTERNS:
                    check(f"{theme}: {rel} has no hardcoded path ({pat.pattern})", not pat.search(text))

        brave_manifest = os.path.join(tdir, "brave", "manifest.json")
        if os.path.isfile(brave_manifest):
            try:
                d = json.load(open(brave_manifest))
                check(f"{theme}: brave manifest is valid JSON", True)
            except Exception as e:
                check(f"{theme}: brave manifest is valid JSON ({e})", False)
                d = None
            if d is not None:
                check(f"{theme}: brave manifest_version == 3", d.get("manifest_version") == 3)
                colors = d.get("theme", {}).get("colors", {})
                check(f"{theme}: brave manifest has theme.colors", len(colors) > 0)
                used = set(colors.keys())
                check(f"{theme}: brave manifest only uses documented Chromium theme.colors keys",
                      used <= BRAVE_ALLOWED_COLOR_KEYS)
                ok_rgb = all(
                    isinstance(v, list) and len(v) == 3 and all(isinstance(c, int) and 0 <= c <= 255 for c in v)
                    for v in colors.values()
                )
                check(f"{theme}: every brave theme color is a 3-element [0-255] RGB array", ok_rgb)
                for forbidden in ("permissions", "host_permissions", "content_scripts", "background"):
                    check(f"{theme}: brave manifest has no '{forbidden}'", forbidden not in d)
        else:
            print(f"  ({theme}: no brave/manifest.json — brave component will be skipped for this theme, apply.sh handles that)")

        # ---- wallpaper pack ----
        canonical = os.path.join(WALLPAPERS_DIR, f"{theme}.png")
        check(f"{theme}: canonical wallpapers/{theme}.png exists", os.path.isfile(canonical))

        variants = sorted(
            f for f in os.listdir(WALLPAPERS_DIR)
            if f.startswith(f"{theme}-") and f.endswith(".png")
        ) if os.path.isdir(WALLPAPERS_DIR) else []
        check(f"{theme}: at least 3 wallpaper variants present (found {len(variants)}: {variants})",
              len(variants) >= 3)

        for v in variants:
            path = os.path.join(WALLPAPERS_DIR, v)
            try:
                width, height, bit_depth, color_type = read_png_header(path)
                check(f"{theme}: {v} is truecolor RGB (2), no alpha", color_type == 2)
                check(f"{theme}: {v} is at least 1920x1080", width >= 1920 and height >= 1080)
            except Exception as e:
                check(f"{theme}: {v} is a readable PNG ({e})", False)

        if os.path.isfile(canonical) and variants:
            with open(canonical, "rb") as f:
                canonical_bytes = f.read()
            matches = any(
                canonical_bytes == open(os.path.join(WALLPAPERS_DIR, v), "rb").read()
                for v in variants
            )
            check(f"{theme}: canonical wallpapers/{theme}.png matches one of its own variants exactly",
                  matches)

    finish()


def finish():
    if failures:
        print(f"\n{len(failures)} check(s) failed")
        sys.exit(1)
    print("\nall checks passed")


if __name__ == "__main__":
    main()
