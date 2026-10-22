#!/usr/bin/env python3
"""Reduce sprites importados (arte de IA) a una paleta .gpl por vecino mas cercano.

Paso 3 de docs/plan-arte-jefe-alerta-mayor.md §5 (arte final de Alerta Mayor,
2026-10-22): la regla del Mundo 1 es «solo colores de mundo1.gpl» y la
excepcion de paleta libre es solo para Isak. Ademas un rojo de la IA no debe
caer en carmin (el carmin es solo del nucleo, que dibuja el codigo): con
--exclude carmin,carmin_brillo esos colores no son candidatos y los rojos van
a alerta / alerta_sombra.

Cada pixel opaco (alfa > 0) pasa al color mas cercano (distancia RGB
ponderada por la percepcion: 2R, 4G, 3B) entre los colores permitidos y queda
con alfa 255; los transparentes quedan a (0, 0, 0, 0).

Uso:
    python3 tools/reduce_palette.py PNG... --palette assets/palettes/mundo1.gpl
        [--only noche_profunda,alerta,...] [--exclude carmin,carmin_brillo]
        [--check]
--only limita los candidatos a esos nombres; --exclude los quita.
--check no escribe: falla (1) si algun PNG tiene colores fuera de los
permitidos o alfa parcial. Devuelve 0 si todo va bien y 2 si los argumentos no
sirven.
"""

import argparse
import sys

from PIL import Image


def load_gpl(path):
    """[(nombre, (r, g, b))] en el orden del archivo."""
    colors = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("GIMP") or ":" in line.split()[0]:
                continue
            parts = line.split()
            if len(parts) < 3 or not all(p.isdigit() for p in parts[:3]):
                continue
            name = parts[3] if len(parts) > 3 else ""
            colors.append((name, (int(parts[0]), int(parts[1]), int(parts[2]))))
    return colors


def select_colors(colors, only=None, exclude=None):
    """Filtra la paleta por nombre. Error si un nombre no existe."""
    names = {n for n, _ in colors}
    for n in list(only or []) + list(exclude or []):
        if n not in names:
            raise ValueError(f"color '{n}' no esta en la paleta")
    out = [(n, c) for n, c in colors if (not only or n in only) and n not in (exclude or [])]
    if not out:
        raise ValueError("no queda ningun color permitido")
    return out


def nearest(rgb, allowed):
    r, g, b = rgb[:3]
    best, best_d = None, None
    for _, c in allowed:
        d = 2 * (r - c[0]) ** 2 + 4 * (g - c[1]) ** 2 + 3 * (b - c[2]) ** 2
        if best_d is None or d < best_d:
            best, best_d = c, d
    return best


def reduce_image(img, allowed):
    """Copia de `img` (RGBA) con cada pixel opaco en un color permitido."""
    src = img.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    cache = {}
    for y in range(src.height):
        for x in range(src.width):
            p = sp[x, y]
            if p[3] == 0:
                continue
            key = p[:3]
            if key not in cache:
                cache[key] = nearest(key, allowed)
            op[x, y] = cache[key] + (255,)
    return out


def check_image(img, allowed):
    """Lista de errores: colores fuera de los permitidos y alfa parcial."""
    ok = {c for _, c in allowed}
    bad, semi = set(), 0
    for p in img.convert("RGBA").getdata():
        if p[3] == 0:
            continue
        if p[3] != 255:
            semi += 1
        if p[:3] not in ok:
            bad.add(p[:3])
    errs = []
    if semi:
        errs.append(f"{semi} pixeles semitransparentes")
    if bad:
        errs.append(f"{len(bad)} colores fuera de la paleta permitida (p. ej. {sorted(bad)[:3]})")
    return errs


def main(argv=None):
    ap = argparse.ArgumentParser(description="Reduce PNG a una paleta .gpl (vecino mas cercano).")
    ap.add_argument("files", nargs="+")
    ap.add_argument("--palette", required=True)
    ap.add_argument("--only", help="nombres permitidos, separados por comas")
    ap.add_argument("--exclude", help="nombres prohibidos, separados por comas (p. ej. carmin,carmin_brillo)")
    ap.add_argument("--check", action="store_true", help="solo comprueba, no escribe")
    args = ap.parse_args(argv)
    split = lambda s: [p.strip() for p in s.split(",") if p.strip()] if s else None  # noqa: E731
    try:
        allowed = select_colors(load_gpl(args.palette), split(args.only), split(args.exclude))
    except (OSError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    failed = 0
    for path in args.files:
        img = Image.open(path)
        if args.check:
            errs = check_image(img, allowed)
            if errs:
                failed += 1
                print(f"{path}: {'; '.join(errs)}")
        else:
            reduce_image(img, allowed).save(path)
    if args.check:
        print(f"{'FALLO' if failed else 'OK'}: {len(args.files) - failed} de {len(args.files)} en la paleta "
              f"({', '.join(n for n, _ in allowed)})")
    else:
        print(f"Reducidos {len(args.files)} PNG a {len(allowed)} colores ({', '.join(n for n, _ in allowed)})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
