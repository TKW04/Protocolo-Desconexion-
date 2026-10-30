#!/usr/bin/env python3
"""Limpieza del base de El Vendedor antes de subirlo a AutoSprite (paso 24 de
docs/propuesta-mundo-5.md, etapa 2; notas en docs/plan-arte-mundo-5.md).

El base (hojas/vendor/base.png, 1024 x 1024) es pixel art a rejilla 8 (128 x 128
nativos). En la rejilla nativa:

  1. Fondo: relleno desde el borde de lo casi blanco; despues, el halo (grises
     claros sin color pegados al fondo, dos pasadas) tambien pasa a fondo. El
     fondo vuelve a ser blanco puro (#ffffff), como el base de El Visto subido.
  2. Rim light cian/turquesa del lado derecho y de los brazos -> violeta del
     borde (regla 6 de §6.1: el cian es de Isak).
  3. Productos (reglas 4 y 6): las cajas naranjas pasan a violeta neon y el
     naranja suelto de las etiquetas a amarillo sombra; las rojo-rosadas, a
     magenta sombra; la verde oliva, a gris violeta; el marron, a violeta oscuro.

Se amplia x 8 sin filtro y se guarda en hojas/vendor/base_upload.png (la que se
sube con upload_character). El cuerpo no se aclara ni se estira aqui: el
contraste con el fondo y la proporcion de la caja 4 x 5 los da el importador
(tools/import_boss_vendor.py), para que la IA anime desde las proporciones que
ella misma pinto.

Uso: python3 tools/clean_vendor_base.py   (Pillow; /usr/bin/python3 sin -I)
"""

import os
import site
import sys

sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "hojas", "vendor", "base.png")
OUT = os.path.join(ROOT, "hojas", "vendor", "base_upload.png")
GRID = 8
WHITE = (255, 255, 255)

TEAL = (114, 175, 183)
TRIM = (82, 64, 130)
ORANGE = (216, 111, 6)
RED = (211, 73, 98)
OLIVE = (67, 76, 40)
BROWN = (45, 30, 40)
VIOLET_NEON = (160, 102, 255)
YELLOW_SHADOW = (166, 146, 0)
MAGENTA_SHADOW = (150, 26, 144)
GREY_VIOLET = (93, 90, 116)
DARK_VIOLET = (37, 30, 50)
BIG_BLOB = 20


def near_white(p):
    return min(p) > 235


def light_grey(p):
    return min(p) > 190 and max(p) - min(p) < 40


def native(img):
    w, h = img.width // GRID, img.height // GRID
    out = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            out.putpixel((x, y), img.getpixel((x * GRID + GRID // 2, y * GRID + GRID // 2)))
    return out


def flood_background(img):
    w, h = img.size
    px = img.load()
    bg = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in bg or not near_white(px[x, y]):
            continue
        bg.add((x, y))
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in bg:
                stack.append((nx, ny))
    for _ in range(2):
        halo = []
        for y in range(h):
            for x in range(w):
                if (x, y) in bg or not light_grey(px[x, y]):
                    continue
                if any((x + dx, y + dy) in bg for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    halo.append((x, y))
        bg.update(halo)
    for x, y in bg:
        px[x, y] = WHITE
    return bg


def blobs(img, color):
    """Manchas (4-vecinos) de un color exacto."""
    w, h = img.size
    px = img.load()
    seen = set()
    out = []
    for sy in range(h):
        for sx in range(w):
            if px[sx, sy] != color or (sx, sy) in seen:
                continue
            stack = [(sx, sy)]
            seen.add((sx, sy))
            pts = []
            while stack:
                x, y = stack.pop()
                pts.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] == color:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            out.append(pts)
    return out


def recolor(img):
    px = img.load()
    for color, big, small in ((ORANGE, VIOLET_NEON, YELLOW_SHADOW), (RED, MAGENTA_SHADOW, MAGENTA_SHADOW)):
        for pts in blobs(img, color):
            for p in pts:
                px[p] = big if len(pts) >= BIG_BLOB else small
    simple = {TEAL: TRIM, OLIVE: GREY_VIOLET, BROWN: DARK_VIOLET}
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p in simple:
                px[x, y] = simple[p]
            elif p != WHITE and p[1] > p[0] + 30 and p[2] > p[0] + 30 and p[1] > 120:
                # Otros cian sueltos del rim light.
                px[x, y] = TRIM


def main():
    base = native(Image.open(SRC).convert("RGB"))
    flood_background(base)
    recolor(base)
    base.resize((base.width * GRID, base.height * GRID), Image.NEAREST).save(OUT)
    print(f"Escrito {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
