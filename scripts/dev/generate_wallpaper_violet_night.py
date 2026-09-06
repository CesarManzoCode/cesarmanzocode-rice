#!/usr/bin/env python3
"""
generate_wallpaper_violet_night.py — procedurally generates the
violet-night theme's wallpaper pack as plain PNGs, using only the Python
standard library.

This script is a DEV-TIME tool only. It is never invoked by install.sh /
apply.sh / uninstall.sh, so Python is not a runtime dependency of the rice
— only of regenerating the committed wallpapers/violet-night-*.png assets.

Usage:
    python3 scripts/dev/generate_wallpaper_violet_night.py <variant> <output.png> [WxH]
    python3 scripts/dev/generate_wallpaper_violet_night.py all wallpapers/ [WxH]

Variants: nebula, monolith, drift, halo

Every variant uses a fixed, variant-specific seed, so the same script +
same variant + same resolution always produces byte-identical output (see
tests/run_tests.sh's determinism check).

Identity: nocturnal / abstract / elegant / atmospheric — soft violet-blue
glows and deep, near-black geometric planes, never a neon grid, glitch/
scanline effect, or RGB-gamer palette. Uses the shared Canvas's
`radial_glow`/`blend_px` helpers for the glow work.
"""

import math
import random
import sys

from wallpaper_lib import DEFAULT_HEIGHT, DEFAULT_WIDTH, Canvas

# ---- shared violet-night palette (see themes/violet-night/hypr.lua) --------
BG = (0x0A, 0x08, 0x12)
C_ALT = (0x10, 0x0D, 0x1D)
SURFACE = (0x16, 0x12, 0x2A)
SURFACE_ALT = (0x1E, 0x18, 0x36)
BORDER = (0x34, 0x2B, 0x52)
MUTED = (0x8C, 0x84, 0xAD)
DEEP_VIOLET = (0x22, 0x1A, 0x40)
GLOW_VIOLET = (0x6B, 0x4A, 0xB8)
ACCENT = (0xA9, 0x70, 0xFF)
ACCENT_SOFT = (0xC6, 0xA3, 0xFF)
COOL_WHITE = (0xE7, 0xE3, 0xF6)

VARIANTS = ("nebula", "monolith", "drift", "halo")

# One fixed seed per variant. Never derived from the current time, host,
# or any other runtime state — this is exactly what makes regeneration
# deterministic.
SEEDS = {
    "nebula": 20260906_11,
    "monolith": 20260906_12,
    "drift": 20260906_13,
    "halo": 20260906_14,
}


def _draw_ring(c, cx, cy, r, color, peak_alpha=0.25, thickness=2, n=720):
    """A thin, faint circular ring built from blended points — for a
    subtle "halo" accent that a plain fill_circle can't produce (no
    stroke primitive in the shared Canvas)."""
    for i in range(n):
        theta = (i / n) * math.tau
        for t in range(thickness):
            rr = r + t
            x = cx + rr * math.cos(theta)
            y = cy + rr * math.sin(theta)
            c.blend_px(x, y, color, peak_alpha)


# ---- variant 1: NEBULA (hero / default) ------------------------------------
#
# Several overlapping soft radial glows in deep blue-violet tones, low
# peak alpha so they read as atmosphere/depth rather than distinct orbs.
# A couple of very dim, large dark planes behind them for structure. No
# hard geometric accents — this is the most "mood" of the four.


def draw_nebula(c, rnd):
    w, h = c.w, c.h

    # Large, very dark planes first — quiet structure well below the glows.
    for _ in range(3):
        x0 = rnd.uniform(-w * 0.2, w * 0.8)
        y0 = rnd.uniform(-h * 0.1, h * 1.1)
        length = rnd.uniform(w * 0.7, w * 1.3)
        angle = rnd.choice([0.3, -0.3, 0.5]) + rnd.uniform(-0.05, 0.05)
        dx, dy = math.cos(angle) * length, math.sin(angle) * length
        thickness = rnd.uniform(h * 0.15, h * 0.3)
        nx, ny = -dy, dx
        norm = math.hypot(nx, ny) or 1
        nx, ny = nx / norm * thickness, ny / norm * thickness
        p0 = (x0, y0)
        p1 = (x0 + dx, y0 + dy)
        p2 = (x0 + dx + nx, y0 + dy + ny)
        p3 = (x0 + nx, y0 + ny)
        shade = rnd.choice([C_ALT, SURFACE])
        c.fill_triangle((p0, p1, p2), shade)
        c.fill_triangle((p0, p2, p3), shade)

    # Soft overlapping glows — the actual "nebula" content.
    glow_specs = [
        (w * 0.28, h * 0.32, min(w, h) * 0.5, GLOW_VIOLET, 0.30),
        (w * 0.68, h * 0.58, min(w, h) * 0.42, DEEP_VIOLET, 0.35),
        (w * 0.82, h * 0.22, min(w, h) * 0.28, GLOW_VIOLET, 0.22),
        (w * 0.18, h * 0.78, min(w, h) * 0.3, DEEP_VIOLET, 0.28),
    ]
    for cx, cy, r, color, alpha in glow_specs:
        jx = rnd.uniform(-w * 0.02, w * 0.02)
        jy = rnd.uniform(-h * 0.02, h * 0.02)
        c.radial_glow(cx + jx, cy + jy, r, color, peak_alpha=alpha)

    # One tight, bright accent core — the single "hot" point in the frame.
    cx, cy = w * 0.685, h * 0.575
    c.radial_glow(cx, cy, min(w, h) * 0.09, ACCENT, peak_alpha=0.5)
    c.radial_glow(cx, cy, min(w, h) * 0.025, ACCENT_SOFT, peak_alpha=0.7)

    # A handful of faint, tiny far points — restrained, not a starfield.
    for _ in range(14):
        x = rnd.uniform(0, w)
        y = rnd.uniform(0, h * 0.6)
        r = rnd.uniform(0.6, 1.4)
        c.blend_px(x, y, MUTED, rnd.uniform(0.15, 0.35))


# ---- variant 2: MONOLITH ----------------------------------------------------
#
# Large dark violet architectural planes (fracture-like), each with a
# faint violet rim-light along one edge instead of a plain white cut —
# reads as lit-from-within structure, not a neon outline.


def draw_monolith(c, rnd):
    w, h = c.w, c.h
    shades = [C_ALT, SURFACE, SURFACE_ALT]

    for _ in range(5):
        x0 = rnd.uniform(-w * 0.15, w * 0.85)
        y0 = rnd.uniform(-h * 0.1, h * 1.1)
        length = rnd.uniform(w * 0.6, w * 1.2)
        angle = rnd.choice([0.35, -0.35, 0.55, -0.55]) + rnd.uniform(-0.05, 0.05)
        dx, dy = math.cos(angle) * length, math.sin(angle) * length
        thickness = rnd.uniform(h * 0.1, h * 0.22)
        nx, ny = -dy, dx
        norm = math.hypot(nx, ny) or 1
        nx, ny = nx / norm * thickness, ny / norm * thickness
        p0 = (x0, y0)
        p1 = (x0 + dx, y0 + dy)
        p2 = (x0 + dx + nx, y0 + dy + ny)
        p3 = (x0 + nx, y0 + ny)
        shade = rnd.choice(shades)
        c.fill_triangle((p0, p1, p2), shade)
        c.fill_triangle((p0, p2, p3), shade)

        # Rim-light along the leading edge — a soft violet glow traced as
        # a chain of small blended dots, not a hard white line.
        n_steps = 24
        for i in range(n_steps + 1):
            t = i / n_steps
            x = p0[0] + t * dx
            y = p0[1] + t * dy
            c.blend_px(x, y, ACCENT, 0.35)
            c.blend_px(x, y - 1, ACCENT_SOFT, 0.15)

    # One quiet ambient glow low in the frame for depth, well below the
    # rim-lights in intensity.
    c.radial_glow(w * 0.5, h * 0.85, min(w, h) * 0.5, DEEP_VIOLET, peak_alpha=0.22)

    # A couple of dim structural lines, well below the rim-lights.
    for _ in range(3):
        x0 = rnd.uniform(0, w)
        y0 = rnd.uniform(0, h)
        angle = rnd.uniform(-0.6, 0.6)
        length = rnd.uniform(w * 0.15, w * 0.4)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, BORDER, thickness=1)


# ---- variant 3: DRIFT --------------------------------------------------------
#
# Long, soft diagonal glow bands drifting across the frame — minimal and
# atmospheric, built entirely from radial_glow chains rather than hard
# lines. No grid, no scanlines.


def draw_drift(c, rnd):
    w, h = c.w, c.h

    bands = [
        (w * -0.1, h * 0.15, w * 0.75, h * 0.55, GLOW_VIOLET, 0.05),
        (w * 0.1, h * 0.85, w * 1.05, h * 0.35, DEEP_VIOLET, 0.055),
        (w * -0.05, h * 0.7, w * 0.55, h * 0.95, GLOW_VIOLET, 0.045),
    ]
    for x0, y0, x1, y1, color, alpha in bands:
        length = math.hypot(x1 - x0, y1 - y0)
        n_steps = max(1, int(length / 6))
        band_r = min(w, h) * rnd.uniform(0.1, 0.14)
        for i in range(n_steps + 1):
            t = i / n_steps
            x = x0 + t * (x1 - x0)
            y = y0 + t * (y1 - y0)
            c.radial_glow(x, y, band_r, color, peak_alpha=alpha)

    # One bright, tight glow core off-center — the focal point.
    fx, fy = w * 0.74, h * 0.3
    c.radial_glow(fx, fy, min(w, h) * 0.16, ACCENT, peak_alpha=0.28)
    c.radial_glow(fx, fy, min(w, h) * 0.035, ACCENT_SOFT, peak_alpha=0.6)

    # A single faint straight line for quiet definition, kept short.
    c.draw_line(w * 0.08, h * 0.92, w * 0.4, h * 0.78, BORDER, thickness=1)


# ---- variant 4: HALO ---------------------------------------------------------
#
# The most minimal of the four: mostly empty near-black-violet, one
# large soft glow off-center with a couple of faint concentric rings —
# built to sit quietly behind Kitty/Rofi without competing with either.


def draw_halo(c, rnd):
    w, h = c.w, c.h

    fx, fy = w * 0.71, h * 0.66
    c.radial_glow(fx, fy, min(w, h) * 0.34, DEEP_VIOLET, peak_alpha=0.4)
    c.radial_glow(fx, fy, min(w, h) * 0.16, GLOW_VIOLET, peak_alpha=0.35)
    c.radial_glow(fx, fy, min(w, h) * 0.05, ACCENT, peak_alpha=0.55)

    _draw_ring(c, fx, fy, min(w, h) * 0.24, ACCENT_SOFT, peak_alpha=0.06, thickness=2)
    _draw_ring(c, fx, fy, min(w, h) * 0.32, BORDER, peak_alpha=0.05, thickness=2)

    # One quiet long diagonal, well clear of the focal glow.
    c.draw_line(w * -0.05, h * 0.12, w * 0.42, h * 0.4, C_ALT, thickness=1)

    # A handful of faint, tiny far points for atmosphere.
    for _ in range(10):
        x = rnd.uniform(0, w)
        y = rnd.uniform(0, h * 0.5)
        c.blend_px(x, y, MUTED, rnd.uniform(0.12, 0.28))


DRAW_FNS = {
    "nebula": draw_nebula,
    "monolith": draw_monolith,
    "drift": draw_drift,
    "halo": draw_halo,
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
            dest = os.path.join(out_path, f"violet-night-{v}.png")
            canvas.write_png(dest)
            print(f"wrote {dest} ({width}x{height})")
        return

    canvas = render(variant, width, height)
    canvas.write_png(out_path)
    print(f"wrote {out_path} ({width}x{height})")


if __name__ == "__main__":
    main()
