"""
wallpaper_lib.py — shared, theme-agnostic canvas + PNG encoder used by every
per-theme wallpaper generator under scripts/dev/.

Extracted from the original monochrome-only generate_wallpaper.py so that
arctic-glass/ember-forge/ivory-paper/violet-night (and any theme after them)
draw their own procedural wallpapers without re-implementing the raster/PNG
plumbing, and without touching monochrome's own generator.

Dev-time only: never imported by install.sh/apply.sh/uninstall.sh at
runtime, only by scripts/dev/generate_wallpaper*.py. Standard library only —
no Pillow, no network, no AI image generation.
"""

import math
import struct
import zlib

DEFAULT_WIDTH = 1920
DEFAULT_HEIGHT = 1080


class Canvas:
    """A plain RGB raster with the two "keep it quiet here" zones (a top
    bar strip, a centered launcher/box) baked into every pixel write, so a
    wallpaper never competes with Waybar or Rofi sitting on top of it.

    `bg` is the base color new pixels dim toward near those zones — pass
    each theme's own background color instead of hardcoding one.
    """

    def __init__(self, w, h, bg=(0x05, 0x05, 0x05)):
        self.w = w
        self.h = h
        self.bg = bg
        row = bytes(bg) * w
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
            color = tuple(round(bg + (c - bg) * f) for bg, c in zip(self.bg, color))
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

    def fill_circle(self, cx, cy, r, color):
        r = max(0, int(r))
        for y in range(max(0, int(cy - r)), min(self.h - 1, int(cy + r)) + 1):
            dy = y - cy
            dx = math.sqrt(max(0.0, r * r - dy * dy))
            self.fill_rect(cx - dx, y, cx + dx, y, color)

    def blend_px(self, x, y, color, alpha):
        """Alpha-blend `color` (0..1 alpha) onto the existing pixel — used
        for soft radial glows/gradients that plain opaque set_px can't do.
        Still runs through the same quiet-zone dimming as set_px.
        """
        x, y = int(x), int(y)
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        f = self._dim_factor(x, y)
        a = max(0.0, min(1.0, alpha)) * f
        if a <= 0:
            return
        o = x * 3
        cur = self.rows[y][o : o + 3]
        blended = tuple(round(cur[i] + (color[i] - cur[i]) * a) for i in range(3))
        self.rows[y][o : o + 3] = bytes(blended)

    def radial_glow(self, cx, cy, r, color, peak_alpha=0.5):
        """Soft radial falloff glow, alpha-blended pixel by pixel. Bounded
        to the circle's bounding box for speed."""
        r = max(1, int(r))
        for y in range(max(0, int(cy - r)), min(self.h - 1, int(cy + r)) + 1):
            for x in range(max(0, int(cx - r)), min(self.w - 1, int(cx + r)) + 1):
                dist = math.hypot(x - cx, y - cy)
                if dist > r:
                    continue
                a = peak_alpha * (1 - dist / r)
                self.blend_px(x, y, color, a)

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
