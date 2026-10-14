#!/usr/bin/env python3
"""Genera el arte del cuadro de texto de Eco con la paleta del Mundo 1.

Rutas y cuadros: data/eco_text_box.json -> assets. Solo colores de mundo1.gpl, alfa 0/255.
  eco_text_panel.png  16x16, NinePatch (margen panel_margin_px = 3): esquinas recortadas,
                      contorno noche_profunda, linea borde_luz y fondo noche_profunda
                      (mismo lenguaje que la barra de estado del HUD)
  eco_icon.png        16x16, esfera de Eco (docs 12.1: luz blanca y azul con un arco de
                      pixeles que hace de sonrisa): halo resplandor, anillo borde_luz,
                      nucleo banner_blanco y sonrisa en resplandor
  _eco_text_box_preview_x8.png  vista ampliada x8 (no la usa el juego)

Uso: python3 tools/gen_eco_text_box.py
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_hud_assets as ga  # noqa: E402  (paleta y rutas)

ROOT = ga.ROOT
P = ga.P
DATA = os.path.join(ROOT, "data", "eco_text_box.json")
PREVIEW = os.path.join(ga.OUT_DIR, "_eco_text_box_preview_x8.png")
PREVIEW_SCALE = 8

# Panel: '.' transparente, 'o' noche_profunda, 'b' borde_luz. Solo importan las esquinas
# (3x3) y los lados: el centro se estira.
PANEL_KEY = {".": None, "o": "noche_profunda", "b": "borde_luz"}
PANEL_CORNER = [".oo", "obb", "obo"]
SIDE = "obo"   # lados, de fuera hacia dentro

# Esfera de Eco: 'r' resplandor, 'l' borde_luz, 'w' banner_blanco, 's' sonrisa (resplandor).
ICON_KEY = {".": None, "r": "resplandor", "l": "borde_luz", "w": "banner_blanco", "s": "resplandor"}
ICON = [
    "................",
    ".....rrrrrr.....",
    "...rrllllllrr...",
    "..rlllwwwwlllr..",
    "..rllwwwwwwllr..",
    ".rllwwwwwwwwllr.",
    ".rlwwwwwwwwwwlr.",
    ".rlwwwwwwwwwwlr.",
    ".rlwswwwwwwswlr.",
    ".rlwwswwwwswwlr.",
    ".rllwwsssswwllr.",
    "..rllwwwwwwllr..",
    "..rlllwwwwlllr..",
    "...rrllllllrr...",
    ".....rrrrrr.....",
    "................",
]


def load_spec():
    with open(DATA, encoding="utf-8") as fh:
        return json.load(fh)


def draw_panel(spec, margin):
    fw, fh = spec["frame_size"]
    img = Image.new("RGBA", (fw, fh), ga.CLEAR)
    assert len(PANEL_CORNER) == margin
    for y in range(fh):
        for x in range(fw):
            # Distancia al borde mas cercano en cada eje, recortada a la esquina.
            cx = min(x, fw - 1 - x)
            cy = min(y, fh - 1 - y)
            if cx < margin and cy < margin:
                key = PANEL_CORNER[cy][cx]
            elif cx < margin:
                key = SIDE[cx]
            elif cy < margin:
                key = SIDE[cy]
            else:
                key = "o"
            color = PANEL_KEY[key]
            if color:
                img.putpixel((x, y), P[color])
    return img


def draw_icon(spec):
    fw, fh = spec["frame_size"]
    assert len(ICON) == fh and all(len(r) == fw for r in ICON)
    img = Image.new("RGBA", (fw, fh), ga.CLEAR)
    for y, row in enumerate(ICON):
        for x, v in enumerate(row):
            if ICON_KEY[v]:
                img.putpixel((x, y), P[ICON_KEY[v]])
    return img


def main():
    data = load_spec()
    assets = data["assets"]
    panel = draw_panel(assets["panel"], data["panel_margin_px"])
    icon = draw_icon(assets["icon"])
    panel.save(ga.res_to_path(assets["panel"]["path"]))
    icon.save(ga.res_to_path(assets["icon"]["path"]))
    # Vista: panel estirado a 64x24 con el icono dentro, sobre el cielo.
    m = data["panel_margin_px"]
    w, h = 64, 24
    view = Image.new("RGBA", (w + 4, h + 4), P["cielo"])
    big = Image.new("RGBA", (w, h), ga.CLEAR)
    src = panel
    for y in range(h):
        sy = y if y < m else (src.height - (h - y) if y >= h - m else m)
        for x in range(w):
            sx = x if x < m else (src.width - (w - x) if x >= w - m else m)
            big.putpixel((x, y), src.getpixel((sx, sy)))
    view.alpha_composite(big, (2, 2))
    view.alpha_composite(icon, (2 + 4, 2 + 4))
    view.resize((view.width * PREVIEW_SCALE, view.height * PREVIEW_SCALE), Image.NEAREST).save(PREVIEW)
    print("gen_eco_text_box: %s, %s" % (assets["panel"]["path"], assets["icon"]["path"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
