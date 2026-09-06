#!/usr/bin/env python3
"""
generate_wallpaper_ember_forge.py — procedurally generates the ember-forge
theme's final wallpaper pack as plain PNGs, using only the Python standard
library.

This script is a DEV-TIME tool only. It is never invoked by install.sh /
apply.sh / uninstall.sh, so Python is not a runtime dependency of the rice
— only of regenerating the committed wallpapers/*.png assets.

Usage:
    python3 scripts/dev/generate_wallpaper_ember_forge.py <variant> <output.png> [WxH]
    python3 scripts/dev/generate_wallpaper_ember_forge.py all wallpapers/ [WxH]

Variants: temper, truss, fissure, plate

Identity: industrial/carbon — hard geometry, diagonals, fractures; a
sensation of heat and mechanical control without a single literal flame
shape anywhere (no flame silhouettes, no lava). Copper/amber appears only
as thin seams, node marks, and small contained glows on top of large,
mostly-empty carbon/near-black planes — never as a filled warm background.

Every variant uses a fixed, variant-specific seed, so the same script +
same variant + same resolution always produces byte-identical output (see
tests/run_tests.sh's determinism check). No network, no AI image
generation, no Pillow/ImageMagick — a plain PNG encoder using zlib from the
standard library (shared via wallpaper_lib.py).
"""

import math
import random
import sys

from wallpaper_lib import DEFAULT_HEIGHT, DEFAULT_WIDTH, Canvas

# ---- shared ember-forge palette (see themes/ember-forge/hypr.lua colors) ---
BG = (0x0C, 0x09, 0x07)
CARBON_1 = (0x14, 0x0F, 0x0B)
CARBON_2 = (0x1D, 0x16, 0x10)
CARBON_3 = (0x28, 0x1E, 0x16)
BROWN = (0x3D, 0x2E, 0x23)
MUTED = (0x9C, 0x85, 0x70)
COPPER = (0xC9, 0x75, 0x36)
AMBER = (0xE8, 0x97, 0x3B)
WARM_WHITE = (0xFF, 0xF6, 0xEC)

VARIANTS = ("temper", "truss", "fissure", "plate")

# One fixed seed per variant. Never derived from the current time, host,
# or any other runtime state — this is exactly what makes regeneration
# deterministic.
SEEDS = {
    "temper": 20260906_11,
    "truss": 20260906_12,
    "fissure": 20260906_13,
    "plate": 20260906_14,
}

# ---- canvas primitives live in wallpaper_lib.py (shared, not edited here) -


# ---- variant 1: TEMPER (hero / default) ------------------------------------
#
# Large, dark carbon planes on long diagonals (same family of gesture as a
# tempered-steel cross-section), with a couple of thin copper seams cutting
# across them and a small, contained glow where a seam terminates — heat
# read through material, never a flame shape.


def draw_temper(c, rnd):
    w, h = c.w, c.h

    shades = [CARBON_1, CARBON_2, CARBON_3]
    n_planes = 6
    for _ in range(n_planes):
        x0 = rnd.uniform(-w * 0.2, w * 0.9)
        y0 = rnd.uniform(-h * 0.1, h * 1.1)
        length = rnd.uniform(w * 0.6, w * 1.3)
        angle = rnd.choice([0.32, -0.32, 0.5, -0.5]) + rnd.uniform(-0.05, 0.05)
        dx, dy = math.cos(angle) * length, math.sin(angle) * length
        thickness = rnd.uniform(h * 0.08, h * 0.2)
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

    # One or two thin copper seams — the signature accent, sparing.
    seam_ends = []
    for _ in range(rnd.choice([1, 2])):
        x0 = rnd.uniform(0, w * 0.3)
        y0 = rnd.uniform(h * 0.15, h * 0.85)
        angle = rnd.uniform(-0.45, 0.45)
        length = rnd.uniform(w * 0.55, w * 0.9)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, COPPER, thickness=1)
        seam_ends.append((x1, y1))

    # A small, contained glow at one seam terminus — heat, not fire.
    if seam_ends:
        gx, gy = rnd.choice(seam_ends)
        c.radial_glow(gx, gy, min(w, h) * 0.05, AMBER, peak_alpha=0.35)

    # A few dim structural lines for depth, well below the accents.
    for _ in range(4):
        x0 = rnd.uniform(0, w)
        y0 = rnd.uniform(0, h)
        angle = rnd.uniform(-0.6, 0.6)
        length = rnd.uniform(w * 0.2, w * 0.5)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, BROWN, thickness=1)


# ---- variant 2: TRUSS -------------------------------------------------------
#
# An industrial diagonal truss — crossing structural beams like a tower or
# gantry, with small node marks at intersections. Firm and mechanical, not
# a perspective "hacker" grid.


def draw_truss(c, rnd):
    w, h = c.w, c.h

    n_bays = 7
    bay_w = w / n_bays
    top_y, bot_y = h * 0.12, h * 0.94

    nodes = []
    for i in range(n_bays + 1):
        x = i * bay_w
        nodes.append((x, top_y))
        nodes.append((x, bot_y))

    # Top and bottom chords.
    for i in range(n_bays):
        c.draw_line(i * bay_w, top_y, (i + 1) * bay_w, top_y, BROWN, thickness=2)
        c.draw_line(i * bay_w, bot_y, (i + 1) * bay_w, bot_y, BROWN, thickness=2)

    # Verticals + alternating diagonals (Warren truss pattern).
    for i in range(n_bays + 1):
        x = i * bay_w
        color = CARBON_3 if i % 2 else BROWN
        c.draw_line(x, top_y, x, bot_y, color, thickness=1)

    for i in range(n_bays):
        x0, x1 = i * bay_w, (i + 1) * bay_w
        if i % 2 == 0:
            c.draw_line(x0, top_y, x1, bot_y, CARBON_3, thickness=1)
        else:
            c.draw_line(x0, bot_y, x1, top_y, CARBON_3, thickness=1)

    # A single copper diagonal spanning several bays — the accent beam.
    start = rnd.randint(0, n_bays - 3)
    span = rnd.randint(3, min(4, n_bays - start))
    x0, x1 = start * bay_w, (start + span) * bay_w
    if rnd.random() < 0.5:
        c.draw_line(x0, top_y, x1, bot_y, COPPER, thickness=2)
    else:
        c.draw_line(x0, bot_y, x1, top_y, COPPER, thickness=2)

    # Rivet-like node marks at a subset of intersections.
    for (nx, ny) in nodes:
        if rnd.random() < 0.5:
            c.fill_circle(nx, ny, 3, MUTED)

    # One node lit as the focal point.
    fx, fy = rnd.choice(nodes)
    c.fill_circle(fx, fy, 4, AMBER)
    c.radial_glow(fx, fy, min(w, h) * 0.045, AMBER, peak_alpha=0.3)


# ---- variant 3: FISSURE -----------------------------------------------------
#
# Jagged crack lines radiating from a couple of origin points across large
# carbon planes — like stress fractures in tempered material, each crack
# thinning as it travels, with copper only at the crack itself, never a
# filled glow field.


def draw_fissure(c, rnd):
    w, h = c.w, c.h

    # Base plate: a few large, very dark carbon panels.
    for _ in range(4):
        x0 = rnd.uniform(-w * 0.1, w * 0.7)
        y0 = rnd.uniform(-h * 0.1, h * 0.7)
        pw = rnd.uniform(w * 0.4, w * 0.7)
        ph = rnd.uniform(h * 0.35, h * 0.65)
        shade = rnd.choice([CARBON_1, CARBON_2])
        c.fill_rect(x0, y0, x0 + pw, y0 + ph, shade)

    def crack(x, y, angle, segments, length):
        for i in range(segments):
            angle += rnd.uniform(-0.5, 0.5)
            seg_len = length * (0.85 ** i) * rnd.uniform(0.7, 1.1)
            nx = x + seg_len * math.cos(angle)
            ny = y + seg_len * math.sin(angle)
            color = COPPER if i < 2 else BROWN
            c.draw_line(x, y, nx, ny, color, thickness=1)
            # occasional short branch
            if i > 0 and rnd.random() < 0.3:
                branch_angle = angle + rnd.choice([-1, 1]) * rnd.uniform(0.5, 1.0)
                bx = x + seg_len * 0.6 * math.cos(branch_angle)
                by = y + seg_len * 0.6 * math.sin(branch_angle)
                c.draw_line(x, y, bx, by, BROWN, thickness=1)
            x, y = nx, ny

    origins = [
        (rnd.uniform(w * 0.15, w * 0.85), rnd.uniform(h * 0.15, h * 0.85))
        for _ in range(2)
    ]
    for ox, oy in origins:
        crack(ox, oy, rnd.uniform(0, math.tau), rnd.randint(5, 8), rnd.uniform(w * 0.05, w * 0.09))

    # Small contained glow right at each origin — the "hot" source of the
    # fracture, not a flame shape.
    for ox, oy in origins:
        c.radial_glow(ox, oy, min(w, h) * 0.03, AMBER, peak_alpha=0.4)


# ---- variant 4: PLATE -------------------------------------------------------
#
# The most minimal of the four: mostly empty near-black, a single offset
# carbon plate with riveted corners and one copper edge-seam. Built to sit
# behind Kitty/Rofi without competing with either.


def draw_plate(c, rnd):
    w, h = c.w, c.h

    # Off-center plate — clear of the exact-center quiet zone.
    px0, py0 = w * 0.52, h * 0.58
    pw, ph = w * 0.34, h * 0.3
    px1, py1 = px0 + pw, py0 + ph

    c.fill_rect(px0, py0, px1, py1, CARBON_2)
    # Inset border, a touch brighter, for definition.
    c.draw_line(px0, py0, px1, py0, BROWN, thickness=1)
    c.draw_line(px1, py0, px1, py1, BROWN, thickness=1)
    c.draw_line(px1, py1, px0, py1, BROWN, thickness=1)
    c.draw_line(px0, py1, px0, py0, BROWN, thickness=1)

    # One copper seam along the top edge only — sparing accent.
    c.draw_line(px0, py0, px1, py0, COPPER, thickness=2)

    # Rivet marks at the four corners.
    for (rx, ry) in ((px0, py0), (px1, py0), (px1, py1), (px0, py1)):
        c.fill_circle(rx, ry, 3, MUTED)

    # One quiet long diagonal elsewhere on the canvas, and a small glow
    # near the plate's top-left rivet.
    c.draw_line(w * -0.05, h * 0.12, w * 0.45, h * 0.5, CARBON_3, thickness=1)
    c.radial_glow(px0, py0, min(w, h) * 0.035, AMBER, peak_alpha=0.3)


DRAW_FNS = {
    "temper": draw_temper,
    "truss": draw_truss,
    "fissure": draw_fissure,
    "plate": draw_plate,
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
            dest = os.path.join(out_path, f"ember-forge-{v}.png")
            canvas.write_png(dest)
            print(f"wrote {dest} ({width}x{height})")
        return

    canvas = render(variant, width, height)
    canvas.write_png(out_path)
    print(f"wrote {out_path} ({width}x{height})")


if __name__ == "__main__":
    main()
