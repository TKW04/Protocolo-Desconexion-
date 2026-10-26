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
  2b. Correcciones por script (CLEAN_HALO, RECENTER; ver abajo).
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


## Correcciones por script del 2026-10-26 (docs/plan-arte-mundo-2.md §1.4):
## - CLEAN_HALO: el brillo neon de la IA dejaba anillos lavanda (gris, bisel,
##   resplandor) alrededor de los ojos y del triangulo al reducir la paleta.
##   Dentro de cada ojo y en su halo (hasta EYE_BAND pixeles de arte mas alla
##   del radio, al menos EYE_HALO_MIN) esos colores se rellenan con lo que los
##   rodea (el ojo, el triangulo, el halo magenta oscuro o el fondo).
## - RECENTER: en `clip_cast` (encogerse) la IA bajaba la pantalla hasta 10
##   pixeles de arte (~30-40 px del juego) durante 2-3 cuadros; cada cuadro se
##   desplaza en vertical para que el centro de lo opaco siga en el de la
##   referencia (el encogido se conserva, la caida no).
CLEAN_HALO = {"idle", "clip_cast", "x2"}
RECENTER = {"clip_cast"}
LAVENDER = ["gris", "tarjeta_borde", "feed_resplandor", "tarjeta_luz"]
EYE_COLORS = ["blanco", "magenta"]
EYE_WINDOW = (14, 14, 129, 58)
EYE_SIZE = (10, 34)
EYE_BAND = 5
## Radio exterior minimo de la banda (el halo del brillo es mas ancho que el ojo
## encendido) y fila desde la que empieza la barra de progreso (no se toca).
EYE_HALO_MIN = 19
BAR_ROW = 57


def eye_discs(px, rgb):
    """[(cx, cy, r)] de los dos ojos: las dos manchas claras redondas mayores de EYE_WINDOW."""
    x0, y0, x1, y1 = EYE_WINDOW
    eye = {rgb[n] for n in EYE_COLORS}
    left = {(x, y) for y in range(y0, y1) for x in range(x0, x1) if px[x, y][3] and px[x, y][:3] in eye}
    blobs = []
    while left:
        stack = [left.pop()]
        blob = list(stack)
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in left:
                        left.remove(n)
                        stack.append(n)
                        blob.append(n)
        xs, ys = [p[0] for p in blob], [p[1] for p in blob]
        w, h = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        if EYE_SIZE[0] <= w <= EYE_SIZE[1] and EYE_SIZE[0] <= h <= EYE_SIZE[1] and abs(w - h) <= 8:
            blobs.append((len(blob), (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, max(w, h) / 2))
    blobs.sort(reverse=True)
    return [b[1:] for b in blobs[:2]]


def clean_halo(art, rgb):
    px = art.load()
    lav = {rgb[n] for n in LAVENDER}
    todo = set()
    for cx, cy, r in eye_discs(px, rgb):
        hi = max(r + EYE_BAND, EYE_HALO_MIN)
        for y in range(int(cy - hi) - 1, int(cy + hi) + 2):
            for x in range(int(cx - hi) - 1, int(cx + hi) + 2):
                if not (EYE_WINDOW[0] <= x < EYE_WINDOW[2] and 0 <= y < BAR_ROW):
                    continue
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= hi and px[x, y][3] and px[x, y][:3] in lav:
                    todo.add((x, y))
    # Relleno por mayoria de los vecinos que no son lavanda, de fuera hacia dentro.
    while todo:
        done = {}
        for x, y in todo:
            votes = {}
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n == (x, y) or n in todo or not (0 <= n[0] < art.width and 0 <= n[1] < art.height):
                        continue
                    p = px[n]
                    if p[3] and p[:3] not in lav:
                        votes[p[:3]] = votes.get(p[:3], 0) + 1
            if votes:
                done[(x, y)] = max(sorted(votes), key=lambda c: votes[c])
        if not done:
            break
        for (x, y), c in done.items():
            px[x, y] = c + (255,)
            todo.discard((x, y))
    return art


def center_y(img):
    box = img.getchannel("A").getbbox()
    return (box[1] + box[3]) / 2


def shift_y(img, dy):
    if dy == 0:
        return img
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, dy))
    return out


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
    rgb = dict(allowed)
    files = []
    for anim, spec in ANIMS.items():
        sheet = Image.open(os.path.join(SHEETS, anim, "spritesheet.png")).convert("RGBA")
        cells = parse_cells(spec)
        box = opaque_box(cell_image(sheet, cells[0]))
        ref_cy = None
        for i, c in enumerate(cells):
            art = reduce_palette.reduce_image(to_art(cell_image(sheet, c), box), allowed)
            if anim in RECENTER:
                if ref_cy is None:
                    ref_cy = center_y(art)
                art = shift_y(art, round(ref_cy - center_y(art)))
            if anim in CLEAN_HALO:
                art = clean_halo(art, rgb)
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
