#!/usr/bin/env python3
"""Arte final del Troll (paso 24 de docs/propuesta-mundo-4.md, etapa 3b; plan y
gasto en docs/plan-arte-mundo-4.md, ejecutado el 2026-10-28).

Rehace los cuadros del Troll desde las hojas de AutoSprite guardadas en
hojas/troll/<hoja>/spritesheet.png (5 x 5 cuadros de 512, frontal):

  1. En cada animacion, la celda de referencia (la 0 de su hoja: la base o la
     pose Typing, de la misma altura) da la caja de lo opaco. Esa caja pasa a
     BODY_ART pixeles de arte con la MISMA escala en x e y (fit "height",
     centrado en x, pies abajo) y MARGIN_ART de margen para el balanceo y las
     estrellas del aturdido. Todas las celdas de la animacion usan la misma
     transformacion.
  2. Cada celda se reduce (media por caja, alfa premultiplicado), el alfa se
     umbraliza y pasa a mundo4.gpl sin los rojos, los ambares ni el coral del
     Debug (rojo = dano; el contorno rojo del Modo oscuro lo dibuja el codigo),
     ni los marinos (fondo), las cremas (burbujas) ni los verdes (el «Visto»):
     el Troll queda en la rampa chat_noche -> gris_oscuro -> gris_medio ->
     gris_claro -> blanco_pantalla. El borde de la silueta va a chat_noche.
  3. Rejilla 1 (GRID 1: a 38 pixeles de arte x2 la sonrisa, el movil y las
     estrellas no se leian): 76 px de alto, que
     sobresalen 20 px por encima de la caja de 40 x 56 (body_size de
     data/enemies/troll.json; la caja no cambia, como El Visto). Lienzo de
     CANVAS px colocado en ART_OFFSET_PX del origen (los pies, abajo-centro;
     Troll.ART_OFFSET).

Las hojas no traen rotulos inventados (se revisaron a mano: el movil tiene la
pantalla lisa y el aturdido solo estrellas), asi que no hay limpieza.

Salida: assets/sprites/enemies/world4/troll_<anim>_<NN>.png. Las animaciones y
las celdas estan en ANIMS (los fps y cuando sale cada una, en Troll.ART_ANIMS).

Uso:
    python3 -I tools/import_troll.py           # rehace los PNG
    python3 -I tools/import_troll.py --check   # comprueba que estan al dia
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
from import_boss_curator import Spec, cell_image, opaque_box, parse_cells, source_rect, to_art  # noqa: E402
from import_boss_seen import reduce_art  # noqa: E402

GPL = os.path.join(ROOT, "assets", "palettes", "mundo4.gpl")
EXCLUDE = ["alerta", "alerta_sombra", "ambar", "ambar_sombra", "debug_coral", "marino_fondo", "marino_medio",
           "marino_luz", "crema", "crema_sombra", "verde_apagado", "verde_sombra"]
FORBIDDEN = ["alerta", "alerta_sombra", "debug_coral"]
SHEETS = os.path.join(ROOT, "hojas", "troll")
OUT = os.path.join(ROOT, "assets", "sprites", "enemies", "world4")

## anim: (hoja, celdas). La referencia es la celda 0 de la hoja.
ANIMS = {
    # Reposo: respira con las manos en el bolsillo; bucle (sin la 24, = la 0).
    "idle": ("idle", "0-23"),
    # Aviso (9 cuadros = anticipation_frames): saca el movil y escribe rapido.
    "typing": ("typing_shot", "0,2,4,6,8,10,12,14,16"),
    # Lanza: sube el movil de golpe con la sonrisa mas grande y lo baja.
    "shot": ("typing_shot", "18-23"),
    # Aturdido: se tambalea con la sonrisa en zigzag y tres estrellas; bucle
    # (sin las 0-2 ni las 21-24, sin estrellas: la base de partida y de vuelta).
    "stunned": ("stunned", "3-20"),
}

SPEC = Spec(sheets=SHEETS, out=OUT, prefix="troll", anims=ANIMS, body_art=(48, 76), margin_art=16, grid=1,
            fit="height")
## Esquina del lienzo respecto al origen del Troll (sus pies), en px del juego:
## centrado en x y con los pies en la fila de abajo del dibujo. Lo copia
## Troll.ART_OFFSET (tests/test_import_troll.py).
ART_OFFSET_PX = (-(SPEC.canvas[0] // 2), -(SPEC.body_art[1] + SPEC.margin_art) * SPEC.grid)


def allowed_colors():
    return reduce_palette.select_colors(reduce_palette.load_gpl(GPL), exclude=EXCLUDE)


def build(out_dir):
    allowed = allowed_colors()
    rgb = dict(allowed)
    files = []
    for anim, (sheet_name, cells_spec) in ANIMS.items():
        sheet = Image.open(os.path.join(SHEETS, sheet_name, "spritesheet.png")).convert("RGBA")
        src = source_rect(SPEC, opaque_box(cell_image(sheet, 0)))
        for i, c in enumerate(parse_cells(cells_spec)):
            art = reduce_art(to_art(SPEC, cell_image(sheet, c), src), allowed, rgb)
            img = art.resize(SPEC.canvas, Image.NEAREST)
            name = f"{SPEC.prefix}_{anim}_{i:02d}.png"
            img.save(os.path.join(out_dir, name))
            files.append(name)
    return files, allowed


def check(out=None):
    out = out or SPEC.out
    bad = []
    full = reduce_palette.load_gpl(GPL)
    forbidden = {tuple(c) for n, c in full if n in FORBIDDEN}
    with tempfile.TemporaryDirectory() as tmp:
        files, allowed = build(tmp)
        for f in files:
            mine, theirs = os.path.join(out, f), os.path.join(tmp, f)
            if not os.path.exists(mine):
                bad.append(f"{f}: falta")
                continue
            a, b = Image.open(mine).convert("RGBA"), Image.open(theirs).convert("RGBA")
            if a.size != b.size or a.tobytes() != b.tobytes():
                bad.append(f"{f}: no esta al dia")
            errs = reduce_palette.check_image(a, allowed)
            if errs:
                bad.append(f"{f}: {'; '.join(errs)}")
            if any(p[3] and p[:3] in forbidden for p in a.getdata()):
                bad.append(f"{f}: rojo o coral (reservados al dano y al Debug)")
            w, h = a.size
            if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                bad.append(f"{f}: esquinas opacas")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {len(files)} cuadros del Troll")
    return 1 if bad else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Arte final del Troll (AutoSprite)")
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    if args.check:
        return check()
    files, _ = build(OUT)
    print(f"Escritos {len(files)} cuadros del Troll en {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
