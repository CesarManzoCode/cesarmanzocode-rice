#!/usr/bin/env python3
"""
generate_wallpaper.py — procedurally generates the monochrome theme
wallpaper as a plain PNG, using only the Python standard library.

This script is a DEV-TIME tool only. It is never invoked by install.sh /
apply.sh / uninstall.sh, so Python is not a runtime dependency of the rice
— only of regenerating the committed wallpapers/monochrome.png asset.

Usage:
    python3 scripts/dev/generate_wallpaper.py wallpapers/monochrome.png
"""

import random
import struct
import sys
import zlib

WIDTH = 1920
HEIGHT = 1080
SEED = 20260906  # fixed seed -> deterministic output

BG = (0x05, 0x05, 0x05)
POLY_SHADES = [(0x0B, 0x0B, 0x0B), (0x10, 0x10, 0x10), (0x14, 0x14, 0x14), (0x18, 0x18, 0x18)]
LINE_DIM = (0x38, 0x38, 0x38)
LINE_MID = (0x9A, 0x9A, 0x9A)
LINE_BRIGHT = (0xF0, 0xF0, 0xF0)
LINE_WHITE = (0xFF, 0xFF, 0xFF)


def make_canvas(w, h, color):
    row = bytes(color) * w
    return [bytearray(row) for _ in range(h)]


def set_px(canvas, x, y, color):
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        o = x * 3
        canvas[y][o : o + 3] = bytes(color)


def fill_triangle(canvas, pts, color):
    (x0, y0), (x1, y1), (x2, y2) = pts
    ymin = max(int(min(y0, y1, y2)), 0)
    ymax = min(int(max(y0, y1, y2)), HEIGHT - 1)

    def edge(ax, ay, bx, by, px, py):
        return (bx - ax) * (py - ay) - (by - ay) * (px - ax)

    area = edge(x0, y0, x1, y1, x2, y2)
    if area == 0:
        return
    for y in range(ymin, ymax + 1):
        xs = []
        for (ax, ay), (bx, by) in ((( x0, y0), (x1, y1)), ((x1, y1), (x2, y2)), ((x2, y2), (x0, y0))):
            if ay == by:
                continue
            if min(ay, by) <= y < max(ay, by):
                t = (y - ay) / (by - ay)
                xs.append(ax + t * (bx - ax))
        if len(xs) >= 2:
            xa, xb = sorted(xs)[:2]
            xa, xb = int(round(xa)), int(round(xb))
            for x in range(max(xa, 0), min(xb, WIDTH - 1) + 1):
                set_px(canvas, x, y, color)


def draw_line(canvas, x0, y0, x1, y1, color, thickness=1):
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
                set_px(canvas, x + ox, y + oy, color)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy


def write_png(path, canvas):
    def chunk(tag, data):
        return (
            struct.pack("!I", len(data))
            + tag
            + data
            + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack("!IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0)
    raw = bytearray()
    for row in canvas:
        raw.append(0)  # filter type: none
        raw.extend(row)
    idat = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    out_path = sys.argv[1]

    rnd = random.Random(SEED)
    canvas = make_canvas(WIDTH, HEIGHT, BG)

    # Large, dark, low-contrast polygon field (abstract/technical feel).
    cols, rows = 9, 6
    cell_w, cell_h = WIDTH / cols, HEIGHT / rows
    for gy in range(rows):
        for gx in range(cols):
            if rnd.random() < 0.55:
                continue
            cx0, cy0 = gx * cell_w, gy * cell_h
            jitter = 0.35
            p0 = (cx0 + rnd.uniform(0, cell_w * jitter), cy0 + rnd.uniform(0, cell_h * jitter))
            p1 = (cx0 + cell_w - rnd.uniform(0, cell_w * jitter), cy0 + rnd.uniform(0, cell_h * jitter))
            p2 = (cx0 + rnd.uniform(0, cell_w), cy0 + cell_h - rnd.uniform(0, cell_h * jitter))
            p3 = (cx0 + cell_w - rnd.uniform(0, cell_w * jitter), cy0 + cell_h - rnd.uniform(0, cell_h * jitter))
            shade = rnd.choice(POLY_SHADES)
            fill_triangle(canvas, (p0, p1, p2), shade)
            fill_triangle(canvas, (p1, p3, p2), shade)

    # Sparse fine white/gray lines crossing the canvas (technical accents).
    n_lines = 26
    for _ in range(n_lines):
        y0 = rnd.uniform(0, HEIGHT)
        y1 = y0 + rnd.uniform(-160, 160)
        x0 = rnd.uniform(-100, WIDTH * 0.4)
        x1 = x0 + rnd.uniform(WIDTH * 0.3, WIDTH * 0.9)
        color = rnd.choices([LINE_DIM, LINE_MID, LINE_BRIGHT], weights=[6, 3, 1])[0]
        draw_line(canvas, x0, y0, x1, y1, color, thickness=1)

    # A handful of short, bright high-contrast accent segments.
    for _ in range(6):
        x0 = rnd.uniform(0, WIDTH)
        y0 = rnd.uniform(0, HEIGHT)
        length = rnd.uniform(60, 220)
        angle = rnd.uniform(0, 6.283)
        x1 = x0 + length * __import__("math").cos(angle)
        y1 = y0 + length * __import__("math").sin(angle)
        draw_line(canvas, x0, y0, x1, y1, LINE_WHITE, thickness=1)

    write_png(out_path, canvas)
    print(f"wrote {out_path} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
