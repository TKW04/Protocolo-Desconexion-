#!/usr/bin/env python3
"""Genera el punto de sincronizacion (checkpoint, celda C del level-builder) del Mundo 1.

Mismo estilo que tools/gen_world1_objects.py (pixeles logicos de 2x2 px, luz arriba e
izquierda). Es un poste-baliza de 2 tiles de alto (64x128 px, como la puerta) con una
bandera, como la "C" del mapa del nivel (bandera cian). La bandera izada queda por encima
de la cabeza de Isak (96 px), asi se ve aunque Isak reaparezca delante del poste.
  cuadro 0  apagado: bandera plegada a media asta en banner_gris, luz de la base apagada
  cuadro 1  activo A: bandera izada en debug_cian (lo interactivo puede usar el cian)
  cuadro 2  activo B: la misma bandera ondeando (punta desplazada) y luz de la base encendida
Solo colores de assets/palettes/mundo1.gpl (debug_cian incluido) y alfa 0/255. El validador
es tools/validate_world1_assets.py (entrada mundo1_checkpoint.png de data/world1_objects.json,
con palette_allow: ["debug_cian"]).

Uso: python3 tools/gen_checkpoint.py
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_tileset_mundo1 as ts  # noqa: E402
import gen_world1_objects as wo  # noqa: E402

P = ts.P
UNIT = ts.UNIT
W, H = 32, 64  # pixeles logicos (64x128 px)
OUT = os.path.join(wo.TILES_DIR, "mundo1_checkpoint.png")
POLE_X = 8  # columna izquierda del poste (2 px logicos de ancho)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W, H), ts.CLEAR)
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x0, y0, x1, y1, color):
        self.d.rectangle([x0, y0, x1, y1], fill=P[color])

    def px(self, x, y, color):
        self.img.putpixel((x, y), P[color])

    def scaled(self):
        return self.img.resize((W * UNIT, H * UNIT), Image.NEAREST)


def base(c, lit):
    """Pie de la baliza con su luz de estado."""
    c.rect(3, 58, 16, 63, "tile_base")
    c.rect(3, 58, 16, 58, "tile_luz")
    c.rect(16, 59, 16, 63, "tile_sombra")
    c.rect(5, 61, 14, 61, "noche_profunda")
    c.rect(8, 61, 11, 61, "debug_cian" if lit else "tile_luz")


def pole(c, top_lit):
    c.rect(POLE_X, 3, POLE_X + 1, 57, "banner_gris")
    c.rect(POLE_X + 1, 3, POLE_X + 1, 57, "tile_luz")
    c.rect(POLE_X - 1, 0, POLE_X + 2, 2, "banner_blanco" if top_lit else "banner_gris")


def flag(c, top, wave, color, light, shade):
    """Pano a la derecha del poste: borde de luz arriba, sombra abajo y punta ondeando."""
    x0 = POLE_X + 2
    rows = [18, 19, 20, 21, 21, 21, 20, 19, 17]
    for dy, length in enumerate(rows):
        y = top + dy
        x1 = x0 + length - 1 + (wave if 2 <= dy <= 6 else 0)
        c.rect(x0, y, x1, y, color)
        c.px(x1, y, shade)
    c.rect(x0, top, x0 + rows[0] - 2, top, light)
    c.rect(x0, top + len(rows) - 1, x0 + rows[-1] - 2, top + len(rows) - 1, shade)
    # marca de "sincronizado": dos barras en el pano
    for bx in (x0 + 5, x0 + 10):
        c.rect(bx, top + 3, bx + 1, top + 5, light)


def frame(state):
    c = Canvas()
    on = state != "off"
    base(c, lit=state == "on_b")
    pole(c, top_lit=on)
    if on:
        flag(c, 3, 1 if state == "on_b" else 0, "debug_cian", "banner_blanco", "fondo_medio")
    else:
        flag(c, 30, 0, "banner_gris", "borde_luz", "tile_luz")
    return c


def main():
    os.makedirs(wo.TILES_DIR, exist_ok=True)
    frames = [frame("off"), frame("on_a"), frame("on_b")]
    img = Image.new("RGBA", (W * UNIT * len(frames), H * UNIT), ts.CLEAR)
    for k, f in enumerate(frames):
        img.paste(f.scaled(), (k * W * UNIT, 0))
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
