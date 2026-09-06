#!/usr/bin/env python3
"""
generate_wallpaper_ivory_paper.py — procedurally generates the ivory-paper
theme's wallpaper pack as plain PNGs, using only the Python standard
library.

This script is a DEV-TIME tool only. It is never invoked by install.sh /
apply.sh / uninstall.sh, so Python is not a runtime dependency of the rice
— only of regenerating the committed wallpapers/*.png assets.

Usage:
    python3 scripts/dev/generate_wallpaper_ivory_paper.py <variant> <output.png> [WxH]
    python3 scripts/dev/generate_wallpaper_ivory_paper.py all wallpapers/ [WxH]

Variants: ledger, margin, fold, grain

Every variant uses a fixed, variant-specific seed, so the same script +
same variant + same resolution always produces byte-identical output.
No network, no AI image generation, no Pillow/ImageMagick — Canvas/PNG
plumbing lives in the shared scripts/dev/wallpaper_lib.py.

This is the rice's one LIGHT wallpaper pack: quiet paper tones, thin ink
lines, deliberately the sparsest/quietest of the four theme packs — never
grayscale-black like monochrome, never dark, and never busy/saturated.
"""

import math
import random
import sys

from wallpaper_lib import DEFAULT_HEIGHT, DEFAULT_WIDTH, Canvas

# ---- shared ivory-paper palette (see themes/ivory-paper/hypr.lua) ---------
BG = (0xF7, 0xF4, 0xEE)       # background
C_EF = (0xEF, 0xEA, 0xE0)     # background_alt
C_F1 = (0xF1, 0xEC, 0xE2)     # surface_alt
C_DD = (0xDD, 0xD6, 0xC7)     # border_inactive
C_C7 = (0xC7, 0xBF, 0xAE)     # subtle
C_8D = (0x8D, 0x85, 0x74)     # muted
INK = (0x26, 0x23, 0x19)      # foreground
INK_STRONG = (0x14, 0x12, 0x10)  # foreground_strong

VARIANTS = ("ledger", "margin", "fold", "grain")

# One fixed seed per variant. Never derived from the current time, host,
# or any other runtime state — this is exactly what makes regeneration
# deterministic.
SEEDS = {
    "ledger": 20260906_11,
    "margin": 20260906_12,
    "fold": 20260906_13,
    "grain": 20260906_14,
}

# ---- canvas primitives: Canvas itself lives in wallpaper_lib.py -----------


# ---- variant 1: LEDGER (hero / default) ------------------------------------
#
# Faint horizontal rule lines, like ledger/notebook paper — evenly spaced,
# very low contrast against the ivory ground, with a single quiet ink
# accent line near the bottom third. Nothing else.


def draw_ledger(c, rnd):
    w, h = c.w, c.h

    n_rules = 14
    spacing = h / (n_rules + 1)
    for i in range(1, n_rules + 1):
        y = i * spacing + rnd.uniform(-2, 2)
        color = C_DD if i % 4 else C_C7
        c.draw_line(w * 0.06, y, w * 0.94, y, color, thickness=1)

    # A single quiet ink accent rule, thicker and darker than the rest —
    # the one deliberate mark on the page.
    y_accent = spacing * (n_rules * 0.72)
    c.draw_line(w * 0.06, y_accent, w * 0.94, y_accent, INK, thickness=1)

    # One short vertical tick where the accent rule starts, evoking a
    # margin mark rather than a full ruled column.
    c.draw_line(w * 0.06, y_accent - 10, w * 0.06, y_accent + 10, INK, thickness=1)


# ---- variant 2: MARGIN ------------------------------------------------------
#
# A single vertical margin line, off-center, dividing the page unevenly —
# the quietest composition of the four: one line, one short mark, nothing
# more.


def draw_margin(c, rnd):
    w, h = c.w, c.h

    x = w * 0.22
    c.draw_line(x, h * 0.08, x, h * 0.92, C_C7, thickness=1)

    # A second, much fainter rule further right for quiet asymmetry.
    c.draw_line(w * 0.78, h * 0.18, w * 0.78, h * 0.82, C_DD, thickness=1)

    # One short ink dash crossing the main margin — a single deliberate
    # mark, positioned off the exact center so it stays clear of Rofi's
    # quiet zone.
    ty = h * 0.7
    c.draw_line(x - 14, ty, x + 14, ty, INK, thickness=2)


# ---- variant 3: FOLD --------------------------------------------------------
#
# A very soft diagonal crease across the page, as if the paper were once
# folded — a gentle gradient band, not a hard line, plus one thin ink
# accent following the same diagonal.


def draw_fold(c, rnd):
    w, h = c.w, c.h

    # The crease runs corner to corner-ish, softly.
    x0, y0 = -w * 0.05, h * 0.78
    x1, y1 = w * 1.05, h * 0.18

    steps = 60
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        # Soft perpendicular falloff, a handful of px either side.
        for off in range(-5, 6):
            dist = abs(off)
            alpha = max(0.0, 0.16 - dist * 0.03)
            if alpha <= 0:
                continue
            nx, ny = -(y1 - y0), (x1 - x0)
            norm = math.hypot(nx, ny) or 1
            nx, ny = nx / norm, ny / norm
            c.blend_px(x + nx * off, y + ny * off, C_8D, alpha)

    # One thin, crisp ink line riding just above the crease — the single
    # deliberate accent.
    c.draw_line(x0, y0 - 14, x1, y1 - 14, INK, thickness=1)


# ---- variant 4: GRAIN --------------------------------------------------------
#
# Sparse, tiny paper-grain flecks scattered thinly across the page, plus
# one quiet horizontal line — the most textural but still extremely
# restrained variant; built to sit quietly behind Kitty/Rofi.


def draw_grain(c, rnd):
    w, h = c.w, c.h

    n_flecks = 220
    for _ in range(n_flecks):
        x = rnd.uniform(0, w)
        y = rnd.uniform(0, h)
        shade = rnd.choice([C_EF, C_F1, C_DD, C_C7])
        c.fill_rect(x, y, x + 1, y + 1, shade)

    # One quiet horizontal line, well below center, as the page's single
    # structural mark.
    y = h * 0.82
    c.draw_line(w * 0.12, y, w * 0.88, y, C_8D, thickness=1)


DRAW_FNS = {
    "ledger": draw_ledger,
    "margin": draw_margin,
    "fold": draw_fold,
    "grain": draw_grain,
}


def render(variant, width, height):
    if variant not in VARIANTS:
        raise ValueError(f"unknown variant {variant!r}, expected one of {VARIANTS}")
    rnd = random.Random(SEEDS[variant])
    canvas = Canvas(width, height, bg=BG)
    DRAW_FNS[variant](canvas, rnd)
    return canvas


def _parse_size(arg):
    w, h = arg.lower().split("x", 1)
    return int(w), int(h)


def main():
    args = sys.argv[1:]
    if len(args) not in (2, 3):
        print(__doc__)
        sys.exit(1)

    variant, out_path = args[0], args[1]
    width, height = (DEFAULT_WIDTH, DEFAULT_HEIGHT)
    if len(args) == 3:
        width, height = _parse_size(args[2])

    if variant == "all":
        import os

        os.makedirs(out_path, exist_ok=True)
        for v in VARIANTS:
            canvas = render(v, width, height)
            dest = os.path.join(out_path, f"ivory-paper-{v}.png")
            canvas.write_png(dest)
            print(f"wrote {dest} ({width}x{height})")
        return

    canvas = render(variant, width, height)
    canvas.write_png(out_path)
    print(f"wrote {out_path} ({width}x{height})")


if __name__ == "__main__":
    main()
