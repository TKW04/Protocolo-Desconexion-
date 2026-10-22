#!/usr/bin/env python3
"""Arte final de Alerta Mayor (paso 16 de docs/propuesta-jefe-alerta-mayor.md;
plan en docs/plan-arte-jefe-alerta-mayor.md, ejecutado el 2026-10-22).

Rehace los cuadros del cuerpo del jefe desde las hojas de AutoSprite guardadas
en hojas/alert_major/<anim>/spritesheet.png (5 x 5 cuadros de 256 px):

  1. tools/import_sheet.py corta, quita el fondo y escala cada hoja con un
     factor comun: UP_SCALE (4/3) para los estados de arriba (hover, inflate,
     descend, ascend: el badge redondo mide ~229 px, 4 x 4 tiles) y DOWN_SCALE
     (0,9) para los de abajo y las copias (window, lunge_warn, lunge: el badge
     desinflado mide ~183 x 80). El jefe flota: --align sheet (respeta el
     balanceo de la hoja) con la planta de la referencia en FOOT_PX por debajo
     del centro del lienzo; el juego coloca el cuadro con ese dato (art de
     data/bosses/alert_major.json).
  2. El inflado gana un contorno banner_blanco (aviso de escupir y de
     dividirse, como el provisional): la quita de fondo se come el blanco.
  3. tools/reduce_palette.py lo reduce a mundo1.gpl con solo los colores del
     badge (PALETTE_ONLY): ningun rojo cae en carmin (el carmin es del nucleo,
     que dibuja WeakPoint).

Salida: assets/sprites/bosses/alert_major_<anim>_<NN>.png. Las animaciones,
los cuadros y los fps del juego estan en ANIMS (y en data/bosses/alert_major.json).

Uso:
    python3 tools/import_boss_alert_major.py           # rehace los PNG
    python3 tools/import_boss_alert_major.py --check   # comprueba que estan al dia
"""

import argparse
import contextlib
import io
import os
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import import_sheet  # noqa: E402
import reduce_palette  # noqa: E402

SHEETS = os.path.join(ROOT, "hojas", "alert_major")
OUT = os.path.join(ROOT, "assets", "sprites", "bosses")
GPL = os.path.join(ROOT, "assets", "palettes", "mundo1.gpl")
PREFIX = "alert_major"
UP_SCALE = 1.333333
DOWN_SCALE = 0.9
## Colores del badge (plan §2.2): sin carmin ni carmin_brillo.
PALETTE_ONLY = ["noche_profunda", "alerta", "alerta_sombra", "banner_blanco", "banner_gris"]
## Contorno del inflado (banner_blanco) y desde que cuadro sale.
OUTLINE_PX = 3
OUTLINE_FROM = 4

## anim: (hoja, celdas, factor, lienzo, fila base, celda de referencia)
## La planta de la referencia queda en la fila base: FOOT = base + 1 - lienzo / 2
## por debajo del centro (110 px arriba, 112 / 128 abajo; ver art.anims del JSON).
ANIMS = {
    "hover": ("hover", "0-23", UP_SCALE, 256, 237, 0),
    "inflate": ("inflate", "0,3,5,7,8,9,12", UP_SCALE, 320, 269, 0),
    "descend": ("descend", "0,8,10,12,15,24", UP_SCALE, 320, 269, 0),
    "ascend": ("ascend", "0,3,5,13,14,16,24", UP_SCALE, 384, 301, 24),
    "window": ("window", "0-23", DOWN_SCALE, 224, 223, 0),
    "lunge_warn": ("lunge", "0,3,5,6,7,8", DOWN_SCALE, 256, 255, 0),
    "lunge": ("lunge", "12,15,17,19,21,23", DOWN_SCALE, 256, 255, 0),
}


def import_anim(anim, out_dir):
    sheet, cells, scale, canvas, baseline, ref = ANIMS[anim]
    args = [os.path.join(SHEETS, sheet, "spritesheet.png"), "--anim", anim, "--cols", "5", "--rows", "5",
            "--cells", cells, "--ref-frame", str(ref), "--scale", str(scale), "--canvas", str(canvas),
            "--baseline", str(baseline), "--align", "sheet", "--shadow", "off", "--height-tol", "3",
            "--target-height", "100", "--out", out_dir, "--prefix", PREFIX]
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = import_sheet.main(args)
    if code != 0:
        print(buf.getvalue())
        raise SystemExit(f"import_sheet fallo en '{anim}' (codigo {code})")


def add_outline(img, color, width):
    """Contorno exterior de `width` px (8 vecinos) alrededor de lo opaco."""
    src = img.copy()
    a = src.getchannel("A")
    w, h = src.size
    pa = a.load()
    out = src.load()
    opaque = {(x, y) for y in range(h) for x in range(w) if pa[x, y]}
    ring = set()
    for (x, y) in opaque:
        for dy in range(-width, width + 1):
            for dx in range(-width, width + 1):
                if dx * dx + dy * dy > width * width + 1:
                    continue
                q = (x + dx, y + dy)
                if 0 <= q[0] < w and 0 <= q[1] < h and q not in opaque:
                    ring.add(q)
    for q in ring:
        out[q] = color + (255,)
    return src


def build(out_dir):
    palette = reduce_palette.load_gpl(GPL)
    allowed = reduce_palette.select_colors(palette, only=PALETTE_ONLY)
    white = dict(palette)["banner_blanco"]
    files = []
    for anim in ANIMS:
        import_anim(anim, out_dir)
        n = len(import_sheet.parse_cells(ANIMS[anim][1]))
        for i in range(n):
            path = os.path.join(out_dir, f"{PREFIX}_{anim}_{i:02d}.png")
            img = reduce_palette.reduce_image(Image.open(path), allowed)
            if anim == "inflate" and i >= OUTLINE_FROM:
                img = add_outline(img, white, OUTLINE_PX)
            img.save(path)
            files.append(os.path.basename(path))
    return files, allowed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    if not args.check:
        files, _ = build(OUT)
        print(f"Escritos {len(files)} cuadros de Alerta Mayor en {os.path.relpath(OUT, ROOT)}")
        return 0
    with tempfile.TemporaryDirectory() as tmp:
        files, allowed = build(tmp)
        bad = []
        for f in files:
            mine, theirs = os.path.join(OUT, f), os.path.join(tmp, f)
            if not os.path.exists(mine):
                bad.append(f"{f}: falta")
                continue
            a, b = Image.open(mine).convert("RGBA"), Image.open(theirs).convert("RGBA")
            if a.size != b.size or a.tobytes() != b.tobytes():
                bad.append(f"{f}: no esta al dia (python3 tools/import_boss_alert_major.py)")
            errs = reduce_palette.check_image(a, allowed)
            if errs:
                bad.append(f"{f}: {'; '.join(errs)}")
            w, h = a.size
            if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                bad.append(f"{f}: esquinas opacas")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {len(files)} cuadros de Alerta Mayor")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
