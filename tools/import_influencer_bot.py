#!/usr/bin/env python3
"""Arte final del Influencer bot (paso 23 de docs/propuesta-mundo-3.md; plan y
gasto en docs/plan-arte-mundo-3.md, ejecutado el 2026-10-27).

Mismo proceso que tools/import_boss_curator.py (paleta B del Mundo 3 sin rojos,
ambares ni Debug; mofletes a corazon_rosa; contorno galeria_noche) sobre
hojas/influencer/<anim>/spritesheet.png (5 x 5 cuadros de 256): la caja de la
celda 0 de cada animacion pasa a 64 pixeles de arte de alto con la misma escala
en x (centrado, pies abajo), con 8 de margen, y se amplia x2: lienzo de 96 x 160
con la criatura y el pedestal en los 64 x 128 del pedestal de 1 x 2 tiles
(scripts/enemies/influencer_bot.gd, ART_*). Salida:
assets/sprites/enemies/world3/influencer_bot_<anim>_<NN>.png.

Uso:
    python3 -I tools/import_influencer_bot.py           # rehace los PNG
    python3 -I tools/import_influencer_bot.py --check   # comprueba que estan al dia
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_boss_curator as base  # noqa: E402

INFLUENCER = base.Spec(
    sheets=os.path.join(base.ROOT, "hojas", "influencer"),
    out=os.path.join(base.ROOT, "assets", "sprites", "enemies", "world3"),
    prefix="influencer_bot",
    anims={
        # Posa en bucle (sin la 24, = la 0).
        "idle": "0-23",
        # Aviso del flash (9 cuadros = anticipation_frames): junta los brazos y carga.
        "flash_charge": "0,3,6,9,12,15,18,21,24",
        # Aturdido por el pulso, en bucle.
        "stunned": "0-23",
    },
    body_art=(32, 64),
    margin_art=8,
    grid=2,
    fit="height",
)

if __name__ == "__main__":
    sys.exit(base.main(INFLUENCER, "el Influencer bot"))
