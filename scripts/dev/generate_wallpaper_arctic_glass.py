#!/usr/bin/env python3
"""
generate_wallpaper_arctic_glass.py — procedurally generates the
arctic-glass theme's wallpaper pack as plain PNGs, using only the Python
standard library.

This script is a DEV-TIME tool only. It is never invoked by install.sh /
apply.sh / uninstall.sh, so Python is not a runtime dependency of the rice
— only of regenerating the committed wallpapers/*.png assets.

Usage:
    python3 scripts/dev/generate_wallpaper_arctic_glass.py <variant> <output.png> [WxH]
    python3 scripts/dev/generate_wallpaper_arctic_glass.py all wallpapers/ [WxH]

Variants: shard, horizon, drift, aurora

Every variant uses a fixed, variant-specific seed, so the same script +
same variant + same resolution always produces byte-identical output (see
tests/run_tests.sh's determinism check).

Shares its raster/PNG plumbing (Canvas, quiet-zone dimming, PNG writer)
with monochrome's generator via scripts/dev/wallpaper_lib.py — not edited
here, only imported.
"""

import math
import random
import sys

from wallpaper_lib import DEFAULT_HEIGHT, DEFAULT_WIDTH, Canvas

# ---- arctic-glass palette (see docs/themes/arctic-glass.md) ---------------
BG = (0x0A, 0x0F, 0x16)
C_0D = (0x0D, 0x14, 0x1C)
C_12 = (0x12, 0x1B, 0x25)
C_1A = (0x1A, 0x25, 0x30)
C_2A = (0x2A, 0x3A, 0x46)
C_3D = (0x3D, 0x4C, 0x58)
C_8C = (0x8C, 0xA0, 0xAF)
ICE = (0x7F, 0xD8, 0xE8)
ICE_LIGHT = (0xA9, 0xE7, 0xF2)
WHITE = (0xFF, 0xFF, 0xFF)

VARIANTS = ("shard", "horizon", "drift", "aurora")

# One fixed seed per variant. Never derived from the current time, host,
# or any other runtime state — this is exactly what makes regeneration
# deterministic.
SEEDS = {
    "shard": 20260906_11,
    "horizon": 20260906_12,
    "drift": 20260906_13,
    "aurora": 20260906_14,
}


# ---- variant 1: SHARD (hero / default) -------------------------------------
#
# Large, dark blue-glass planes on long diagonals — like fracture but in
# arctic-glass's real cool-blue palette instead of grayscale — plus one or
# two thin ice-blue cuts and a soft glow behind them for depth. Sparse,
# architectural, not busy.


def draw_shard(c, rnd):
    w, h = c.w, c.h

    # A soft, cold glow well off-center so it never competes with the
    # centered Rofi quiet zone.
    c.radial_glow(w * 0.78, h * 0.24, min(w, h) * 0.5, ICE, peak_alpha=0.10)

    shades = [C_0D, C_12, C_1A]
    n_planes = 6
    for _ in range(n_planes):
        x0 = rnd.uniform(-w * 0.2, w * 0.9)
        y0 = rnd.uniform(-h * 0.1, h * 1.1)
        length = rnd.uniform(w * 0.6, w * 1.3)
        angle = rnd.choice([0.35, -0.35, 0.55, -0.55]) + rnd.uniform(-0.05, 0.05)
        dx, dy = math.cos(angle) * length, math.sin(angle) * length
        thickness = rnd.uniform(h * 0.08, h * 0.22)
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

    # One or two long, thin ice-blue cuts — the signature accent.
    for _ in range(rnd.choice([1, 2])):
        x0 = rnd.uniform(0, w * 0.3)
        y0 = rnd.uniform(h * 0.15, h * 0.85)
        angle = rnd.uniform(-0.5, 0.5)
        length = rnd.uniform(w * 0.6, w * 0.95)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, ICE, thickness=1)

    # A couple of dim structural lines for depth, well below the accents.
    for _ in range(4):
        x0 = rnd.uniform(0, w)
        y0 = rnd.uniform(0, h)
        angle = rnd.uniform(-0.6, 0.6)
        length = rnd.uniform(w * 0.2, w * 0.5)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, C_2A, thickness=1)


# ---- variant 2: HORIZON -----------------------------------------------------
#
# A cold, sparse perspective horizon — converging lines suggesting an icy
# plane stretching to a distant vanishing point, with a faint glow sitting
# on the horizon itself. Restrained, never a dense technical grid.


def draw_horizon(c, rnd):
    w, h = c.w, c.h
    vp = (w * 0.5, h * 0.42)  # vanishing point, above center

    c.radial_glow(vp[0], vp[1], min(w, h) * 0.35, ICE_LIGHT, peak_alpha=0.14)

    n_rays = 10
    for i in range(n_rays):
        t = i / (n_rays - 1)
        x_start = w * t
        color = C_1A if i % 3 else C_2A
        c.draw_line(x_start, h, vp[0], vp[1], color, thickness=1)

    n_bands = 7
    for i in range(1, n_bands + 1):
        t = (i / n_bands) ** 2.3
        y = h - t * (h - vp[1]) * 0.94
        span = 1 - t
        x0 = vp[0] - (w * 0.5) * span
        x1 = vp[0] + (w * 0.5) * span
        color = C_2A if i % 4 else C_1A
        c.draw_line(x0, y, x1, y, color, thickness=1)

    # The horizon line itself, in the ice accent — the single strongest
    # element in the frame.
    c.draw_line(w * 0.1, vp[1], w * 0.9, vp[1], ICE, thickness=1)
    c.draw_line(w * 0.2, h * 0.985, w * 0.8, h * 0.985, C_3D, thickness=1)


# ---- variant 3: DRIFT --------------------------------------------------------
#
# Very sparse: a handful of soft, cold glows drifting at different depths,
# like ice particles suspended in space. The quietest variant, built to sit
# behind Kitty/Rofi without competing with either.


def draw_drift(c, rnd):
    w, h = c.w, c.h

    # A few large, very soft background glows for atmosphere.
    for _ in range(3):
        x = rnd.uniform(w * 0.05, w * 0.95)
        y = rnd.uniform(h * 0.1, h * 0.9)
        r = rnd.uniform(min(w, h) * 0.22, min(w, h) * 0.4)
        c.radial_glow(x, y, r, ICE, peak_alpha=rnd.uniform(0.05, 0.09))

    # A scattering of small, crisp "particles" at varying brightness —
    # sparse, never a dense field.
    n = 22
    for _ in range(n):
        x = rnd.uniform(0, w)
        y = rnd.uniform(0, h)
        r = rnd.uniform(1.2, 3.2)
        color = rnd.choice([C_3D, C_8C, ICE_LIGHT])
        c.fill_circle(x, y, r, color)

    # One faint long diagonal for quiet structure, and a single crisp
    # ice-blue accent line near the focal cluster.
    c.draw_line(w * -0.05, h * 0.2, w * 0.55, h * 0.6, C_1A, thickness=1)
    fx, fy = w * 0.68, h * 0.62
    c.draw_line(fx - 40, fy - 90, fx + 20, fy + 30, ICE, thickness=1)


# ---- variant 4: AURORA -------------------------------------------------------
#
# Soft, sweeping bands of cold light low in the frame — an aurora-like
# atmosphere rather than a literal aurora (no green, no curl noise): a few
# broad, gently-angled glow bands over a near-black blue field.


def draw_aurora(c, rnd):
    w, h = c.w, c.h

    bands = 4
    for i in range(bands):
        t = i / (bands - 1)
        cx = w * (0.15 + 0.7 * t) + rnd.uniform(-40, 40)
        cy = h * (0.55 + 0.15 * math.sin(t * math.pi)) + rnd.uniform(-30, 30)
        r = rnd.uniform(min(w, h) * 0.3, min(w, h) * 0.5)
        color = ICE if i % 2 == 0 else ICE_LIGHT
        c.radial_glow(cx, cy, r, color, peak_alpha=rnd.uniform(0.06, 0.11))

    # A thin, quiet baseline and a couple of faint verticals for structure
    # so the glow doesn't float with nothing to anchor it.
    c.draw_line(0, h * 0.92, w, h * 0.92, C_2A, thickness=1)
    for _ in range(3):
        x = rnd.uniform(w * 0.1, w * 0.9)
        c.draw_line(x, h * 0.15, x, h * 0.92, C_1A, thickness=1)

    # One crisp ice-blue accent line, low-key, near the bottom third.
    x0 = w * 0.12
    x1 = w * 0.5
    c.draw_line(x0, h * 0.78, x1, h * 0.7, ICE, thickness=1)


DRAW_FNS = {
    "shard": draw_shard,
    "horizon": draw_horizon,
    "drift": draw_drift,
    "aurora": draw_aurora,
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
            dest = os.path.join(out_path, f"arctic-glass-{v}.png")
            canvas.write_png(dest)
            print(f"wrote {dest} ({width}x{height})")
        return

    canvas = render(variant, width, height)
    canvas.write_png(out_path)
    print(f"wrote {out_path} ({width}x{height})")


if __name__ == "__main__":
    main()
