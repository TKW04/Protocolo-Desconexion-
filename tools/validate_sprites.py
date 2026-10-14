#!/usr/bin/env python3
"""Valida los sprites de animacion importados (tools/import_sheet.py).

Comprueba en cada PNG cuyo nombre no empiece por '_' ni contenga '_sheet':
  - nombre con patron <entidad>_<anim>_<NN>.png (anim puede llevar '_',
    p. ej. isak_jump_rise_00.png); ya no hay *_placeholder.png
  - tamano (por defecto DEFAULT_SIZE, 128x128: canvas de Isak a 1280x720)
  - sin alfa parcial (cada pixel es opaco o transparente)
  - fondo transparente (las cuatro esquinas con alfa 0)
  - pies en la fila base: el pixel opaco mas bajo esta en la ultima fila
  - en las animaciones de pie (STANDING_ANIMS) la altura visible esta en
    TARGET_HEIGHT +/- HEIGHT_TOL
La paleta del arte importado es libre (hojas generadas con IA): --palette solo
se usa si se pide con --check-palette.

Uso:
    python3 tools/validate_sprites.py [DIR] [--size WxH] [--check-palette GPL]
Por defecto: assets/sprites/isak y 128x128.
--size acepta WxH o un solo numero para lienzos cuadrados (p. ej. --size 64).
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""

import argparse
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
## Tamano esperado del canvas por defecto (Isak: 128x128 a 1280x720).
DEFAULT_SIZE = "128x128"
NAME_RE = re.compile(r"^[a-z0-9]+_[a-z0-9]+(_[a-z0-9]+)*_\d{2}\.png$")
## Altura visible de Isak de pie (px) y tolerancia.
TARGET_HEIGHT = 96
HEIGHT_TOL = 4
## Animaciones en las que Isak esta de pie en todos los cuadros.
STANDING_ANIMS = ("idle", "terminal_intro", "terminal_loop", "terminal_outro")


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


def anim_of(name):
    """isak_jump_rise_00.png -> 'jump_rise'."""
    return name[:-4].split("_", 1)[1].rsplit("_", 1)[0] if name.count("_") >= 2 else ""


def check(path, palette, size):
    errors = []
    name = os.path.basename(path)
    if not NAME_RE.match(name):
        errors.append("nombre no cumple <entidad>_<anim>_<NN>.png")
    img = Image.open(path).convert("RGBA")
    if img.size != size:
        errors.append(f"tamano {img.size[0]}x{img.size[1]}, se esperaba {size[0]}x{size[1]}")
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if img.getpixel((x, y))[3] != 0:
            errors.append(f"fondo no transparente en la esquina ({x},{y})")
            break
    check_palette = palette is not None
    bb = img.getchannel("A").point(lambda v: 255 if v else 0).getbbox()
    if not bb:
        errors.append("cuadro vacio")
    else:
        if bb[3] != h:
            errors.append(f"pies en la fila {bb[3] - 1}, se esperaba la fila base {h - 1}")
        if anim_of(name) in STANDING_ANIMS and abs((bb[3] - bb[1]) - TARGET_HEIGHT) > HEIGHT_TOL:
            errors.append(f"altura de pie {bb[3] - bb[1]} px fuera de {TARGET_HEIGHT} +/- {HEIGHT_TOL}")
    bad = set()
    partial = 0
    for r, g, b, a in img.getdata():
        if a == 0:
            continue
        if a != 255:
            partial += 1
        elif check_palette and (r, g, b) not in palette:
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
    ap.add_argument("--check-palette", metavar="GPL",
                    help="exige que los colores opacos esten en esta paleta GIMP (desactivado por defecto)")
    ap.add_argument("--size", default=DEFAULT_SIZE, help="tamano esperado WxH o N (por defecto %(default)s)")
    args = ap.parse_args()

    try:
        parts = [int(v) for v in args.size.lower().split("x")]
        size = (parts[0], parts[0]) if len(parts) == 1 else (parts[0], parts[1])
        if len(parts) > 2 or min(size) <= 0:
            raise ValueError
    except ValueError:
        print(f"ERROR: --size invalido '{args.size}' (usa WxH o N)")
        return 1
    palette = None
    if args.check_palette:
        try:
            palette = load_gpl(args.check_palette)
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
    placeholders = [f for f in files if "_placeholder" in f]
    for f in placeholders:
        print(f"FALLO {f}: quedan placeholders; el arte importado los sustituye")
    failed += len(placeholders)
    for f in files:
        errs = check(os.path.join(args.dir, f), palette, size)
        if errs:
            failed += 1
            for e in errs:
                print(f"FALLO {f}: {e}")
    anims = sorted({anim_of(f) for f in files})
    print(f"{len(files) - failed}/{len(files)} sprites validos en {len(anims)} animaciones "
          f"({', '.join(anims)}); paleta {'comprobada' if palette else 'libre'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
