#!/usr/bin/env python3
"""Arte final de la pantalla de Autoplay (paso 23 de docs/propuesta-mundo-2.md;
plan y gasto en docs/plan-arte-mundo-2.md, ejecutado el 2026-10-23).

Rehace los cuadros de la pantalla del jefe desde las hojas de AutoSprite
guardadas en hojas/autoplay/<anim>/spritesheet.png (5 x 5 cuadros):

  1. En cada animacion, la celda de referencia (la primera de CELLS, que es la
     pose de partida) da la caja de lo opaco: esa caja pasa a SCREEN_ART
     (128 x 64 pixeles de arte) y se deja MARGIN_ART de margen alrededor para
     el temblor del x2 y el glitch de la derrota. Todas las celdas de la
     animacion usan la misma transformacion (respeta el movimiento).
  2. Cada celda se reduce a esa rejilla (media por caja, alfa premultiplicado),
     el alfa se umbraliza y tools/reduce_palette.py la pasa a mundo2.gpl sin los
     rojos ni los ambares (EXCLUDE): el magenta rosado de la IA cae en
     magenta / magenta_sombra, nunca en alerta (rojo = dano y punto debil).
  3. Se amplia x GRID (4) sin filtro: la pantalla mide 512 x 256 (la caja
     `screen` de 8 x 4 tiles de data/bosses/autoplay.json) en un lienzo de
     CANVAS (576 x 320); el juego lo coloca MARGIN_PX por encima y a la
     izquierda de la caja (scripts/bosses/autoplay.gd, ART_MARGIN_PX).

Salida: assets/sprites/bosses/autoplay_<anim>_<NN>.png. Las animaciones, las
celdas y los fps del juego estan en ANIMS (y en Autoplay.ART_ANIMS).
El pie (`stand`), el cabezal, las tarjetas de la cinta y las fichas del album
siguen por script (tools/gen_boss_autoplay.py).

Uso:
    python3 -I tools/import_boss_autoplay.py           # rehace los PNG
    python3 -I tools/import_boss_autoplay.py --check   # comprueba que estan al dia
"""

import argparse
import os
import site
import sys
import tempfile

sys.path.append(site.getusersitepackages())
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image  # noqa: E402
import reduce_palette  # noqa: E402

SHEETS = os.path.join(ROOT, "hojas", "autoplay")
OUT = os.path.join(ROOT, "assets", "sprites", "bosses")
GPL = os.path.join(ROOT, "assets", "palettes", "mundo2.gpl")
PREFIX = "autoplay"
## Rojos (dano) y ambares (puntos de atencion, Debug) fuera: la pantalla es indigo, violeta y magenta.
EXCLUDE = ["alerta", "alerta_sombra", "ambar", "ambar_sombra", "debug_ambar"]
GRID = 4
SCREEN_ART = (128, 64)
MARGIN_ART = 8
CANVAS_ART = (SCREEN_ART[0] + 2 * MARGIN_ART, SCREEN_ART[1] + 2 * MARGIN_ART)
CANVAS = (CANVAS_ART[0] * GRID, CANVAS_ART[1] * GRID)
MARGIN_PX = MARGIN_ART * GRID
ALPHA_CUT = 128
COLS = ROWS = 5

## anim: celdas (la primera es la referencia). Los fps y el bucle, en Autoplay.ART_ANIMS.
ANIMS = {
    "idle": "0-23",
    "clip_cast": "0,2,3,5,7,9,11,13",
    "countdown": "0-23",
    "paused": "0-23",
    "x2": "0-23",
    "defeat": "0,2,4,6,8,10,12,14,16,18,20,22,24",
}


def parse_cells(spec):
    out = []
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return out


def cell_image(sheet, index):
    cw, ch = sheet.width // COLS, sheet.height // ROWS
    x, y = (index % COLS) * cw, (index // COLS) * ch
    return sheet.crop((x, y, x + cw, y + ch))


def opaque_box(img):
    alpha = img.getchannel("A").point(lambda a: 255 if a >= ALPHA_CUT else 0)
    box = alpha.getbbox()
    if box is None:
        raise SystemExit("celda de referencia vacia")
    return box


def to_art(cell, box):
    """Celda -> lienzo de CANVAS_ART pixeles de arte con la caja `box` en la pantalla."""
    x0, y0, x1, y1 = box
    sx = (x1 - x0) / SCREEN_ART[0]
    sy = (y1 - y0) / SCREEN_ART[1]
    src = (x0 - MARGIN_ART * sx, y0 - MARGIN_ART * sy,
           x0 + (SCREEN_ART[0] + MARGIN_ART) * sx, y0 + (SCREEN_ART[1] + MARGIN_ART) * sy)
    pre = cell.convert("RGBa")
    small = pre.resize(CANVAS_ART, Image.BOX, box=src).convert("RGBA")
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            p = px[x, y]
            px[x, y] = (p[0], p[1], p[2], 255) if p[3] >= ALPHA_CUT else (0, 0, 0, 0)
    return small


def build(out_dir):
    allowed = reduce_palette.select_colors(reduce_palette.load_gpl(GPL), exclude=EXCLUDE)
    files = []
    for anim, spec in ANIMS.items():
        sheet = Image.open(os.path.join(SHEETS, anim, "spritesheet.png")).convert("RGBA")
        cells = parse_cells(spec)
        box = opaque_box(cell_image(sheet, cells[0]))
        for i, c in enumerate(cells):
            art = reduce_palette.reduce_image(to_art(cell_image(sheet, c), box), allowed)
            img = art.resize(CANVAS, Image.NEAREST)
            name = f"{PREFIX}_{anim}_{i:02d}.png"
            img.save(os.path.join(out_dir, name))
            files.append(name)
    return files, allowed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    if not args.check:
        files, _ = build(OUT)
        print(f"Escritos {len(files)} cuadros de Autoplay en {os.path.relpath(OUT, ROOT)}")
        return 0
    bad = []
    with tempfile.TemporaryDirectory() as tmp:
        files, allowed = build(tmp)
        for f in files:
            mine, theirs = os.path.join(OUT, f), os.path.join(tmp, f)
            if not os.path.exists(mine):
                bad.append(f"{f}: falta")
                continue
            a, b = Image.open(mine).convert("RGBA"), Image.open(theirs).convert("RGBA")
            if a.size != b.size or a.tobytes() != b.tobytes():
                bad.append(f"{f}: no esta al dia (python3 -I tools/import_boss_autoplay.py)")
            errs = reduce_palette.check_image(a, allowed)
            if errs:
                bad.append(f"{f}: {'; '.join(errs)}")
            w, h = a.size
            if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                bad.append(f"{f}: esquinas opacas")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {len(files)} cuadros de Autoplay")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
