#!/usr/bin/env python3
"""Valida sprites de animacion contra una paleta GIMP (.gpl).

Comprueba en cada PNG cuyo nombre no empiece por '_' ni contenga '_sheet':
  - nombre con patron <entidad>_<anim>_<NN>(_placeholder).png
  - tamano (por defecto 64x64)
  - solo colores de la paleta, mas transparente (alfa 0); sin alfa parcial
  - fondo transparente (las cuatro esquinas con alfa 0)

Uso:
    python3 tools/validate_sprites.py [DIR] [--palette GPL] [--size WxH]
Por defecto: assets/sprites/isak con assets/palettes/isak.gpl y 64x64.
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""

import argparse
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAME_RE = re.compile(r"^[a-z0-9]+_[a-z0-9]+_\d{2}(_placeholder)?\.png$")


def load_gpl(path):
    colors = set()
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines or lines[0].strip() != "GIMP Palette":
        raise ValueError(f"{path}: no es una paleta GIMP")
    for line in lines[1:]:
        s = line.strip()
        if not s or s.startswith("#") or ":" in s.split()[0]:
            continue
        parts = s.split()
        if len(parts) >= 3 and all(p.isdigit() for p in parts[:3]):
            colors.add(tuple(int(p) for p in parts[:3]))
    return colors


def check(path, palette, size):
    errors = []
    name = os.path.basename(path)
    if not NAME_RE.match(name):
        errors.append("nombre no cumple <entidad>_<anim>_<NN>(_placeholder).png")
    img = Image.open(path).convert("RGBA")
    if img.size != size:
        errors.append(f"tamano {img.size[0]}x{img.size[1]}, se esperaba {size[0]}x{size[1]}")
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if img.getpixel((x, y))[3] != 0:
            errors.append(f"fondo no transparente en la esquina ({x},{y})")
            break
    bad = set()
    partial = 0
    for r, g, b, a in img.getdata():
        if a == 0:
            continue
        if a != 255:
            partial += 1
        elif (r, g, b) not in palette:
            bad.add((r, g, b))
    if partial:
        errors.append(f"{partial} pixeles con alfa parcial")
    if bad:
        sample = ", ".join("#%02X%02X%02X" % c for c in sorted(bad)[:5])
        errors.append(f"{len(bad)} colores fuera de paleta: {sample}")
    return errors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", nargs="?", default=os.path.join(ROOT, "assets", "sprites", "isak"))
    ap.add_argument("--palette", default=os.path.join(ROOT, "assets", "palettes", "isak.gpl"))
    ap.add_argument("--size", default="64x64")
    args = ap.parse_args()

    size = tuple(int(v) for v in args.size.lower().split("x"))
    try:
        palette = load_gpl(args.palette)
    except (OSError, ValueError) as e:
        print(f"ERROR paleta: {e}")
        return 1

    files = sorted(
        f for f in os.listdir(args.dir)
        if f.lower().endswith(".png") and not f.startswith("_") and "_sheet" not in f
    )
    if not files:
        print(f"ERROR: no hay sprites en {args.dir}")
        return 1

    failed = 0
    for f in files:
        errs = check(os.path.join(args.dir, f), palette, size)
        if errs:
            failed += 1
            for e in errs:
                print(f"FALLO {f}: {e}")
    print(f"{len(files) - failed}/{len(files)} sprites validos ({len(palette)} colores en paleta)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
