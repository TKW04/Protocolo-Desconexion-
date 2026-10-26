#!/usr/bin/env python3
"""Arte final del Comentarista (paso 23 de docs/propuesta-mundo-2.md; plan y
gasto en docs/plan-arte-mundo-2.md §2, ejecutado el 2026-10-26).

Rehace los cuadros del Comentarista desde las hojas de AutoSprite guardadas en
hojas/commenter/<anim>/spritesheet.png (5 x 5 cuadros de 512 px):

  1. Una sola transformacion para todas las hojas: la celda 0 de `idle` (el
     personaje base) da la caja de lo opaco, que pasa a BODY_ART (24 x 28
     pixeles de arte = 48 x 56 px del juego, el body_size de
     data/enemies/commenter.json, cola incluida). Se deja MARGIN_ART alrededor
     para los mofletes inflados del `spit` y las estrellas del `stunned`.
  2. Cada celda se reduce a esa rejilla (media por caja, alfa premultiplicado),
     el alfa se umbraliza y tools/reduce_palette.py la pasa a la paleta B
     (mundo2.gpl) solo con ALLOWED: cuerpo -> feed_resplandor / feed_medio,
     bisel -> tarjeta_borde, mofletes -> magenta, contorno -> feed_noche, ojos
     y texto -> blanco / gris (sin rojos ni ambares: las estrellas del
     aturdido quedan blancas).
  3. En las celdas de KEEP_BODY_ONLY se borra todo lo que no esta unido al
     cuerpo (la mancha opaca mas grande): el bocadillo que la IA dibuja al
     escupir (el de verdad lo lanza el juego por la columna de delante).
  4. Se amplia x GRID (2) sin filtro: lienzo de CANVAS (80 x 88 px) con el
     cuerpo a MARGIN_PX del borde izquierdo y del de arriba
     (scripts/enemies/commenter.gd, ART_MARGIN_PX).

Salida: assets/sprites/enemies/commenter/commenter_<anim>_<NN>.png. Las
celdas estan en ANIMS; los fps y el uso, en Commenter.ART_ANIMS.

Uso:
    python3 -I tools/import_commenter.py           # rehace los PNG
    python3 -I tools/import_commenter.py --check   # comprueba que estan al dia
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

SHEETS = os.path.join(ROOT, "hojas", "commenter")
OUT = os.path.join(ROOT, "assets", "sprites", "enemies", "commenter")
GPL = os.path.join(ROOT, "assets", "palettes", "mundo2.gpl")
PREFIX = "commenter"
ALLOWED = ["feed_noche", "feed_medio", "feed_resplandor", "tarjeta_borde",
           "blanco", "gris", "magenta", "magenta_sombra"]
GRID = 2
BODY_ART = (24, 28)
MARGIN_ART = 8
CANVAS_ART = (BODY_ART[0] + 2 * MARGIN_ART, BODY_ART[1] + 2 * MARGIN_ART)
CANVAS = (CANVAS_ART[0] * GRID, CANVAS_ART[1] * GRID)
MARGIN_PX = MARGIN_ART * GRID
ALPHA_CUT = 128
COLS = ROWS = 5
PAD = 256
REF = ("idle", 0)

## anim: celdas en orden de salida.
## idle: las 25 menos la ultima (= la primera) en bucle; parpadeo en la 12.
## spit: 9 de aviso (se infla: anticipation_frames = 9) + 5 tras escupir.
## stunned: 24 en bucle (se tambalea, las estrellas giran).
ANIMS = {
    "idle": "0-23",
    "spit": "0,3,4,5,6,8,10,11,13,14,15,16,17,18",
    "stunned": "0-23",
}
## Celdas (anim, celda) donde solo se queda el cuerpo (sin el bocadillo escupido).
KEEP_BODY_ONLY = {("spit", 14), ("spit", 15)}


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
    """Celda con PAD px transparentes alrededor (el margen sale de la celda)."""
    cw, ch = sheet.width // COLS, sheet.height // ROWS
    x, y = (index % COLS) * cw, (index // COLS) * ch
    out = Image.new("RGBA", (cw + 2 * PAD, ch + 2 * PAD), (0, 0, 0, 0))
    out.paste(sheet.crop((x, y, x + cw, y + ch)), (PAD, PAD))
    return out


def opaque_box(img):
    alpha = img.getchannel("A").point(lambda a: 255 if a >= ALPHA_CUT else 0)
    box = alpha.getbbox()
    if box is None:
        raise SystemExit("celda de referencia vacia")
    return box


def keep_largest_blob(img):
    """Deja solo la mancha opaca (4-vecinos) mas grande de `img` (alfa 0/255)."""
    px = img.load()
    w, h = img.size
    seen = set()
    best = []
    for y0 in range(h):
        for x0 in range(w):
            if (x0, y0) in seen or px[x0, y0][3] == 0:
                continue
            blob, stack = [], [(x0, y0)]
            seen.add((x0, y0))
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n][3]:
                        seen.add(n)
                        stack.append(n)
            if len(blob) > len(best):
                best = blob
    keep = set(best)
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and (x, y) not in keep:
                px[x, y] = (0, 0, 0, 0)
    return img


def to_art(cell, box, body_only):
    """Celda -> lienzo de CANVAS_ART pixeles de arte con la caja `box` en el cuerpo."""
    x0, y0, x1, y1 = box
    sx = (x1 - x0) / BODY_ART[0]
    sy = (y1 - y0) / BODY_ART[1]
    src = (x0 - MARGIN_ART * sx, y0 - MARGIN_ART * sy,
           x0 + (BODY_ART[0] + MARGIN_ART) * sx, y0 + (BODY_ART[1] + MARGIN_ART) * sy)
    pre = cell.convert("RGBa")
    small = pre.resize(CANVAS_ART, Image.BOX, box=src).convert("RGBA")
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            p = px[x, y]
            px[x, y] = (p[0], p[1], p[2], 255) if p[3] >= ALPHA_CUT else (0, 0, 0, 0)
    return keep_largest_blob(small) if body_only else small


def build(out_dir):
    allowed = reduce_palette.select_colors(reduce_palette.load_gpl(GPL), only=ALLOWED)
    sheets = {a: Image.open(os.path.join(SHEETS, a, "spritesheet.png")).convert("RGBA") for a in ANIMS}
    box = opaque_box(cell_image(sheets[REF[0]], REF[1]))
    files = []
    for anim, spec in ANIMS.items():
        for i, c in enumerate(parse_cells(spec)):
            art = to_art(cell_image(sheets[anim], c), box, (anim, c) in KEEP_BODY_ONLY)
            img = reduce_palette.reduce_image(art, allowed).resize(CANVAS, Image.NEAREST)
            name = f"{PREFIX}_{anim}_{i:02d}.png"
            img.save(os.path.join(out_dir, name))
            files.append(name)
    return files, allowed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    if not args.check:
        os.makedirs(OUT, exist_ok=True)
        files, _ = build(OUT)
        print(f"Escritos {len(files)} cuadros del Comentarista en {os.path.relpath(OUT, ROOT)}")
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
                bad.append(f"{f}: no esta al dia (python3 -I tools/import_commenter.py)")
            errs = reduce_palette.check_image(a, allowed)
            if errs:
                bad.append(f"{f}: {'; '.join(errs)}")
            w, h = a.size
            if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                bad.append(f"{f}: esquinas opacas")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {len(files)} cuadros del Comentarista")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
