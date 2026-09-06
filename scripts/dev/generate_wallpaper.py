#!/usr/bin/env python3
"""
generate_wallpaper.py — procedurally generates the monochrome theme's final
wallpaper pack as plain PNGs, using only the Python standard library.

This script is a DEV-TIME tool only. It is never invoked by install.sh /
apply.sh / uninstall.sh, so Python is not a runtime dependency of the rice
— only of regenerating the committed wallpapers/*.png assets.

Usage:
    python3 scripts/dev/generate_wallpaper.py <variant> <output.png> [WxH]
    python3 scripts/dev/generate_wallpaper.py all wallpapers/ [WxH]

Variants: fracture, grid, signal, void

Every variant uses a fixed, variant-specific seed, so the same script +
same variant + same resolution always produces byte-identical output (see
tests/run_tests.sh's determinism check). No network, no AI image
generation, no Pillow/ImageMagick — a plain PNG encoder using zlib from the
standard library.
"""

import math
import random
import struct
import sys
import zlib

DEFAULT_WIDTH = 1920
DEFAULT_HEIGHT = 1080

# ---- shared monochrome palette (see README "final wallpaper pack") --------
BG = (0x05, 0x05, 0x05)
C_0B = (0x0B, 0x0B, 0x0B)
C_10 = (0x10, 0x10, 0x10)
C_18 = (0x18, 0x18, 0x18)
C_38 = (0x38, 0x38, 0x38)
C_55 = (0x55, 0x55, 0x55)
C_9A = (0x9A, 0x9A, 0x9A)
C_F0 = (0xF0, 0xF0, 0xF0)
WHITE = (0xFF, 0xFF, 0xFF)

VARIANTS = ("fracture", "grid", "signal", "void")

# One fixed seed per variant. Never derived from the current time, host,
# or any other runtime state — this is exactly what makes regeneration
# deterministic.
SEEDS = {
    "fracture": 20260906_1,
    "grid": 20260906_2,
    "signal": 20260906_3,
    "void": 20260906_4,
}

# ---- canvas primitives ------------------------------------------------------


class Canvas:
    """A plain RGB raster with the two "keep it quiet here" zones (Waybar's
    strip along the top, Rofi's box at dead center) baked into every pixel
    write — every variant gets this for free instead of re-implementing it.
    """

    def __init__(self, w, h):
        self.w = w
        self.h = h
        row = bytes(BG) * w
        self.rows = [bytearray(row) for _ in range(h)]

        # Waybar lives in the top ~50px (at 1080p) — scale with height so a
        # different resolution keeps the same relative quiet strip.
        self.top_band = max(1, round(h * (50 / 1080)))
        self.top_feather = max(1, round(h * (140 / 1080)))

        # Rofi is ~520px wide and appears centered; keep a generous margin
        # around that footprint quiet, not just the exact box. Feathered
        # rather than a hard cutoff — a sharp brightness step at the box
        # edge would itself read as an unintended rectangle in the image.
        cw, ch = min(w * 0.34, 640), min(h * 0.44, 460)
        self.center_box = (
            (w - cw) / 2,
            (h - ch) / 2,
            (w + cw) / 2,
            (h + ch) / 2,
        )
        self.center_feather = max(1, round(min(w, h) * 0.12))

    @staticmethod
    def _smoothstep(t):
        t = max(0.0, min(1.0, t))
        return t * t * (3 - 2 * t)

    def _dim_factor(self, x, y):
        factor = 1.0

        if y < self.top_band + self.top_feather:
            if y < self.top_band:
                f_top = 0.3
            else:
                f_top = 0.3 + 0.7 * self._smoothstep((y - self.top_band) / self.top_feather)
            factor *= f_top

        x0, y0, x1, y1 = self.center_box
        dx = max(x0 - x, 0.0, x - x1)
        dy = max(y0 - y, 0.0, y - y1)
        dist = math.hypot(dx, dy)
        if dist < self.center_feather:
            f_center = 0.4 + 0.6 * self._smoothstep(dist / self.center_feather)
            factor *= f_center

        return factor

    def set_px(self, x, y, color):
        x, y = int(x), int(y)
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        f = self._dim_factor(x, y)
        if f < 1.0:
            color = tuple(round(bg + (c - bg) * f) for bg, c in zip(BG, color))
        o = x * 3
        self.rows[y][o : o + 3] = bytes(color)

    def fill_triangle(self, pts, color):
        (x0, y0), (x1, y1), (x2, y2) = pts
        ymin = max(int(min(y0, y1, y2)), 0)
        ymax = min(int(max(y0, y1, y2)), self.h - 1)

        def edge(ax, ay, bx, by, px, py):
            return (bx - ax) * (py - ay) - (by - ay) * (px - ax)

        if edge(x0, y0, x1, y1, x2, y2) == 0:
            return
        for y in range(ymin, ymax + 1):
            xs = []
            for (ax, ay), (bx, by) in (((x0, y0), (x1, y1)), ((x1, y1), (x2, y2)), ((x2, y2), (x0, y0))):
                if ay == by:
                    continue
                if min(ay, by) <= y < max(ay, by):
                    t = (y - ay) / (by - ay)
                    xs.append(ax + t * (bx - ax))
            if len(xs) >= 2:
                xa, xb = sorted(xs)[:2]
                xa, xb = int(round(xa)), int(round(xb))
                for x in range(max(xa, 0), min(xb, self.w - 1) + 1):
                    self.set_px(x, y, color)

    def draw_line(self, x0, y0, x1, y1, color, thickness=1):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            for ox in range(thickness):
                for oy in range(thickness):
                    self.set_px(x + ox, y + oy, color)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def fill_rect(self, x0, y0, x1, y1, color):
        x0, x1 = sorted((int(x0), int(x1)))
        y0, y1 = sorted((int(y0), int(y1)))
        for y in range(max(y0, 0), min(y1, self.h - 1) + 1):
            for x in range(max(x0, 0), min(x1, self.w - 1) + 1):
                self.set_px(x, y, color)

    def write_png(self, path):
        def chunk(tag, data):
            return (
                struct.pack("!I", len(data))
                + tag
                + data
                + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)
            )

        sig = b"\x89PNG\r\n\x1a\n"
        ihdr = struct.pack("!IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)
        raw = bytearray()
        for row in self.rows:
            raw.append(0)  # filter type: none
            raw.extend(row)
        idat = zlib.compress(bytes(raw), 9)
        with open(path, "wb") as f:
            f.write(sig)
            f.write(chunk(b"IHDR", ihdr))
            f.write(chunk(b"IDAT", idat))
            f.write(chunk(b"IEND", b""))


# ---- variant 1: FRACTURE (hero / default) ----------------------------------
#
# Large, very dark geometric planes on long diagonals, one or two thin white
# cuts, plenty of negative space. Technical/architectural, not busy.


def draw_fracture(c, rnd):
    w, h = c.w, c.h

    # A handful of large diagonal-edged planes, each a very dark shade —
    # few and large, not a dense field.
    shades = [C_0B, C_10, C_18]
    n_planes = 6
    for _ in range(n_planes):
        # Long diagonal quads: pick a baseline diagonal and offset it.
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

    # One or two long, thin white/near-white cuts — the signature accent.
    for _ in range(rnd.choice([1, 2])):
        x0 = rnd.uniform(0, w * 0.3)
        y0 = rnd.uniform(h * 0.15, h * 0.85)
        angle = rnd.uniform(-0.5, 0.5)
        length = rnd.uniform(w * 0.6, w * 0.95)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, WHITE, thickness=1)

    # A couple of dim structural lines for depth, well below the accents.
    for _ in range(4):
        x0 = rnd.uniform(0, w)
        y0 = rnd.uniform(0, h)
        angle = rnd.uniform(-0.6, 0.6)
        length = rnd.uniform(w * 0.2, w * 0.5)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, C_38, thickness=1)


# ---- variant 2: GRID -------------------------------------------------------
#
# A subtle technical/perspective grid — never a "hacker terminal" look: no
# characters, no falling text, just converging lines.


def draw_grid(c, rnd):
    w, h = c.w, c.h
    vp = (w * 0.5, h * 0.32)  # vanishing point, slightly above center

    # Perspective floor lines converging toward the vanishing point.
    n_rays = 14
    for i in range(n_rays):
        t = i / (n_rays - 1)
        x_start = w * t
        color = C_18 if i % 3 else C_38
        c.draw_line(x_start, h, vp[0], vp[1], color, thickness=1)

    # Horizontal "depth" bands, denser near the vanishing point, sparser
    # near the bottom edge — a believable floor-grid falloff.
    n_bands = 10
    for i in range(1, n_bands + 1):
        # ease toward the vanishing point so bands compress with distance
        t = (i / n_bands) ** 2.2
        y = h - t * (h - vp[1]) * 0.94
        span = 1 - t
        x0 = vp[0] - (w * 0.55) * span
        x1 = vp[0] + (w * 0.55) * span
        color = C_38 if i % 4 else C_18
        c.draw_line(x0, y, x1, y, color, thickness=1)

    # A few white structural lines for definition — the grid's "frame",
    # not decoration on top of it.
    c.draw_line(w * 0.08, h, vp[0], vp[1], C_F0, thickness=1)
    c.draw_line(w * 0.92, h, vp[0], vp[1], C_F0, thickness=1)
    c.draw_line(w * 0.15, h * 0.98, w * 0.85, h * 0.98, C_9A, thickness=1)


# ---- variant 3: SIGNAL ------------------------------------------------------
#
# Several long trajectories with precise direction changes and small
# intersection marks — an abstract technical schematic, not a circuit-board
# cliché (no chips, no pads, no PCB traces).


def draw_signal(c, rnd):
    w, h = c.w, c.h

    def polyline(x, y, n_segments, avg_len, angle):
        pts = [(x, y)]
        for _ in range(n_segments):
            angle += rnd.choice([-1, 1]) * rnd.uniform(0.35, 1.1)
            length = avg_len * rnd.uniform(0.6, 1.3)
            x += length * math.cos(angle)
            y += length * math.sin(angle)
            pts.append((x, y))
        return pts

    paths = []
    for _ in range(8):
        x0 = rnd.uniform(0, w)
        y0 = rnd.uniform(0, h)
        angle = rnd.uniform(0, math.tau)
        pts = polyline(x0, y0, rnd.randint(3, 6), rnd.uniform(w * 0.09, w * 0.18), angle)
        paths.append(pts)
        color = C_38 if rnd.random() < 0.55 else C_9A
        for a, b in zip(pts, pts[1:]):
            c.draw_line(a[0], a[1], b[0], b[1], color, thickness=1)

    # Small intersection marks at a subset of path vertices — precise, not
    # scattered everywhere.
    for pts in paths:
        for p in pts[1:-1]:
            if rnd.random() < 0.4:
                c.fill_rect(p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3, C_9A)

    # One or two strong white segments as the focal accent.
    for _ in range(2):
        x0 = rnd.uniform(w * 0.1, w * 0.9)
        y0 = rnd.uniform(h * 0.1, h * 0.9)
        angle = rnd.uniform(0, math.tau)
        length = rnd.uniform(w * 0.14, w * 0.26)
        x1 = x0 + length * math.cos(angle)
        y1 = y0 + length * math.sin(angle)
        c.draw_line(x0, y0, x1, y1, WHITE, thickness=2)


# ---- variant 4: VOID --------------------------------------------------------
#
# The most minimal of the four: mostly empty #050505, a single geometric
# focal point off-center, a couple of very faint lines. Built to sit behind
# Kitty/Rofi without competing with either.


def draw_void(c, rnd):
    w, h = c.w, c.h

    # Off-center focal point — well clear of the exact-center quiet zone,
    # e.g. lower-right third.
    fx, fy = w * 0.72, h * 0.68
    size = min(w, h) * 0.16

    # A single faint triangle as the focal shape.
    p0 = (fx, fy - size)
    p1 = (fx + size * 0.9, fy + size * 0.5)
    p2 = (fx - size * 0.7, fy + size * 0.6)
    c.fill_triangle((p0, p1, p2), C_10)

    # Its outline, a touch brighter, for definition without adding bulk.
    c.draw_line(*p0, *p1, C_38)
    c.draw_line(*p1, *p2, C_38)
    c.draw_line(*p2, *p0, C_38)

    # One quiet long diagonal, and one short bright accent near the focus.
    c.draw_line(w * -0.05, h * 0.15, w * 0.5, h * 0.55, C_18, thickness=1)
    c.draw_line(fx - size * 0.3, fy - size * 1.1, fx + size * 0.2, fy - size * 1.6, WHITE, thickness=1)


DRAW_FNS = {
    "fracture": draw_fracture,
    "grid": draw_grid,
    "signal": draw_signal,
    "void": draw_void,
}


def render(variant, width, height):
    if variant not in VARIANTS:
        raise ValueError(f"unknown variant {variant!r}, expected one of {VARIANTS}")
    rnd = random.Random(SEEDS[variant])
    canvas = Canvas(width, height)
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
            dest = os.path.join(out_path, f"monochrome-{v}.png")
            canvas.write_png(dest)
            print(f"wrote {dest} ({width}x{height})")
        return

    canvas = render(variant, width, height)
    canvas.write_png(out_path)
    print(f"wrote {out_path} ({width}x{height})")


if __name__ == "__main__":
    main()
