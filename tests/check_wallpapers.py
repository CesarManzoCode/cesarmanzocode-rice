#!/usr/bin/env python3
"""
tests/check_wallpapers.py — verifies the final wallpaper pack's invariants
using only the Python standard library (no Pillow): each variant exists at
1920x1080, is truecolor RGB with no alpha, is strictly grayscale (R==G==B
on every pixel), the canonical wallpapers/monochrome.png is byte-identical
to the chosen default variant, and the generator is reproducible (same
script + same variant + same resolution -> same SHA256).

Dev-time check, not run by install.sh/apply.sh. Gated in tests/run_tests.sh
on `command -v python3` like the rest of that file's JSON/Brave checks.
"""

import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import zlib

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WALLPAPERS_DIR = os.path.join(REPO_ROOT, "wallpapers")
GENERATOR = os.path.join(REPO_ROOT, "scripts", "dev", "generate_wallpaper.py")

VARIANTS = ["fracture", "grid", "signal", "void"]
DEFAULT_VARIANT = "fracture"

failures = []


def check(name, cond):
    if cond:
        print(f"  ok {name}")
    else:
        print(f"  ✗ {name}")
        failures.append(name)


def read_png_rgb(path):
    """Minimal PNG reader: single IDAT-or-not, any number of IDAT chunks,
    filter type 0/none rows only need not hold — real de-filtering (types
    0-4) is implemented below since zlib.compress(..., 9) may pick a
    non-zero filter internally... but this repo's own writer always uses
    filter 0, so this stays a plain "unfilter" implementation matching
    that, not a general-purpose PNG decoder.
    """
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos = 8
    width = height = bit_depth = color_type = None
    idat = bytearray()
    while pos < len(data):
        length = struct.unpack("!I", data[pos : pos + 4])[0]
        tag = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 8 + length + 4  # skip CRC
        if tag == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack("!IIBB", chunk[:10])
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    assert width is not None, "no IHDR"
    raw = zlib.decompress(bytes(idat))

    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    assert bit_depth == 8, f"unsupported bit depth {bit_depth}"
    stride = width * channels
    rows = []
    prev = bytearray(stride)
    o = 0
    for _y in range(height):
        ftype = raw[o]
        o += 1
        line = bytearray(raw[o : o + stride])
        o += stride
        if ftype == 0:
            pass
        elif ftype == 1:  # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:  # Average
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                line[i] = (line[i] + (a + b) // 2) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        else:
            raise AssertionError(f"unsupported filter type {ftype}")
        rows.append(bytes(line))
        prev = line
    return width, height, color_type, channels, rows


def main():
    for variant in VARIANTS:
        path = os.path.join(WALLPAPERS_DIR, f"monochrome-{variant}.png")
        check(f"{variant}: file exists", os.path.isfile(path))
        if not os.path.isfile(path):
            continue

        width, height, color_type, channels, rows = read_png_rgb(path)
        check(f"{variant}: resolution is at least 1920x1080", width >= 1920 and height >= 1080)
        check(f"{variant}: color type is truecolor RGB (2), no alpha", color_type == 2 and channels == 3)

        grayscale_ok = True
        for row in rows:
            for i in range(0, len(row), 3):
                if not (row[i] == row[i + 1] == row[i + 2]):
                    grayscale_ok = False
                    break
            if not grayscale_ok:
                break
        check(f"{variant}: strictly grayscale (R == G == B everywhere)", grayscale_ok)

    # Canonical alias matches the chosen default variant exactly.
    canonical = os.path.join(WALLPAPERS_DIR, "monochrome.png")
    default_path = os.path.join(WALLPAPERS_DIR, f"monochrome-{DEFAULT_VARIANT}.png")
    check("canonical wallpapers/monochrome.png exists", os.path.isfile(canonical))
    if os.path.isfile(canonical) and os.path.isfile(default_path):
        with open(canonical, "rb") as f1, open(default_path, "rb") as f2:
            check(
                f"wallpapers/monochrome.png is byte-identical to monochrome-{DEFAULT_VARIANT}.png (the chosen default)",
                f1.read() == f2.read(),
            )

    # Determinism: regenerating a variant at the same resolution reproduces
    # the exact same bytes (SHA256), proving the generator has no hidden
    # non-determinism (time-based seed, dict-order dependence, etc.).
    with tempfile.TemporaryDirectory() as tmp:
        for variant in VARIANTS:
            committed = os.path.join(WALLPAPERS_DIR, f"monochrome-{variant}.png")
            if not os.path.isfile(committed):
                continue
            regenerated = os.path.join(tmp, f"{variant}.png")
            subprocess.run(
                [sys.executable, GENERATOR, variant, regenerated, "1920x1080"],
                check=True,
                cwd=REPO_ROOT,
                stdout=subprocess.DEVNULL,
            )
            with open(committed, "rb") as f1, open(regenerated, "rb") as f2:
                h1 = hashlib.sha256(f1.read()).hexdigest()
                h2 = hashlib.sha256(f2.read()).hexdigest()
            check(f"{variant}: regeneration is deterministic (same SHA256)", h1 == h2)

    # The generator must stay a dev-time-only tool: apply.sh/install.sh must
    # never shell out to python3/generate_wallpaper.py at runtime.
    for script in ("apply.sh", "install.sh", "uninstall.sh"):
        with open(os.path.join(REPO_ROOT, script)) as f:
            text = f.read()
        check(
            f"{script} never invokes the wallpaper generator or python3",
            "generate_wallpaper" not in text and "python3" not in text and "python " not in text,
        )

    if failures:
        print(f"\n{len(failures)} check(s) failed")
        sys.exit(1)
    print("\nall checks passed")


if __name__ == "__main__":
    main()
