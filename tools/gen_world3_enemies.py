#!/usr/bin/env python3
"""Arte por script de los enemigos del Mundo 3 «La Vitrina» (paso 9 de docs/propuesta-mundo-3.md §8 y §6.3).

Como los objetos (tools/gen_world3_objects.py): en el juego se dibujan por codigo; estos PNG son la referencia y el
origen de las fichas del album. Paleta del mundo (variante elegida). Salida en assets/sprites/enemies/world3/:
  like_thief_00.png                 Ladron de likes (48 x 48): mano con puno de marco dorado, dedos rosados
  like_thief_warn_00.png            el aviso (dedos encendidos en blanco brillante) y la bolsa con la cifra
  influencer_bot_placeholder_00.png Influencer bot PROVISIONAL (64 x 128): pedestal y criatura con lente; el arte
                                    final es de AutoSprite (paso 23 de §8, con permiso)
  false_reflection_00.png           Reflejo falso (128 x 128): el primer cuadro de Isak (isak_idle_00) con la
                                    variante saturada (x saturation de data/enemies/false_reflection.json) y el
                                    tinte rosa_pastel al 25 %, como el shader de la pared de espejo
El espejo cazador es un objeto (tools/gen_world3_objects.py).

Uso: python3 -I tools/gen_world3_enemies.py [--check]
"""
import colorsys
import json
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_world3_objects as obj  # noqa: E402

OUT = os.path.join("assets", "sprites", "enemies", "world3")
ISAK = os.path.join(REPO, "assets", "sprites", "isak", "isak_idle_00.png")
REFLECTION_TINT_K = 0.25


def C(name):
    return obj.C(name)


def like_thief(warn=False):
    img, d = obj.canvas(48, 48)
    # puno con marco dorado
    d.rectangle((12, 34, 35, 47), fill=C("dorado"))
    d.rectangle((12, 34, 35, 34), fill=C("dorado_luz"))
    d.rectangle((12, 45, 35, 47), fill=C("marco_sombra"))
    # palma
    d.rectangle((10, 18, 37, 34), fill=C("gris_perla"))
    d.rectangle((10, 32, 37, 33), fill=C("rosa_sombra"))
    finger = "blanco_brillante" if warn else "rosa_pastel"
    for i, x in enumerate((10, 17, 24, 31)):
        top = 4 if i in (1, 2) else 8
        d.rectangle((x, top, x + 5, 18), fill=C(finger))
        d.rectangle((x, top, x + 5, top), fill=C("rosa_sombra"))
    d.rectangle((38, 22, 44, 27), fill=C(finger))  # pulgar
    # ojo de la mano (galeria_noche) para leerla como criatura
    d.rectangle((20, 24, 23, 27), fill=C("galeria_noche"))
    d.rectangle((26, 24, 29, 27), fill=C("galeria_noche"))
    if warn:
        d.rectangle((0, 0, 9, 9), fill=C("galeria_noche"))
        obj.heart(d, 1, 1, 1, border=None)
    return img


def like_thief_warn():
    return like_thief(True)


def influencer_bot_placeholder():
    img, d = obj.canvas(64, 128)
    # pedestal (1 x 1 tile abajo)
    d.rectangle((6, 72, 57, 127), fill=C("blanco_brillante"))
    d.rectangle((6, 72, 57, 75), fill=C("gris_perla"))
    d.rectangle((2, 64, 61, 71), fill=C("dorado"))
    d.rectangle((2, 64, 61, 64), fill=C("dorado_luz"))
    d.rectangle((2, 120, 61, 127), fill=C("dorado"))
    # criatura que posa
    d.ellipse((12, 18, 51, 63), fill=C("rosa_pastel"))
    d.ellipse((12, 18, 51, 63), outline=C("rosa_sombra"), width=1)
    # cabeza-camara con lente
    d.rectangle((16, 2, 47, 25), fill=C("galeria_noche"))
    d.rectangle((26, 0, 37, 2), fill=C("galeria_noche"))
    d.ellipse((22, 6, 41, 23), fill=C("gris_perla"))
    d.ellipse((26, 10, 37, 19), fill=C("galeria_noche"))
    d.rectangle((33, 11, 35, 13), fill=C("blanco_brillante"))
    d.rectangle((41, 4, 45, 7), fill=C("blanco_brillante"))  # flash
    # brazos en pose
    d.line((14, 38, 4, 26), fill=C("rosa_sombra"), width=4)
    d.line((49, 38, 59, 30), fill=C("rosa_sombra"), width=4)
    return img


def _saturate(c, k):
    h, s, v = colorsys.rgb_to_hsv(*(x / 255.0 for x in c[:3]))
    r, g, b = colorsys.hsv_to_rgb(h, min(1.0, s * k), v)
    return tuple(round(x * 255) for x in (r, g, b))


def false_reflection():
    with open(os.path.join(REPO, "data", "enemies", "false_reflection.json"), encoding="utf-8") as fh:
        k = float(json.load(fh)["saturation"])
    tint = C("rosa_pastel")
    src = Image.open(ISAK).convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    for y in range(src.height):
        for x in range(src.width):
            c = sp[x, y]
            if c[3] < 128:
                continue
            r, g, b = _saturate(c, k)
            op[x, y] = (round(r + (tint[0] - r) * REFLECTION_TINT_K), round(g + (tint[1] - g) * REFLECTION_TINT_K),
                        round(b + (tint[2] - b) * REFLECTION_TINT_K), 255)
    return out


BUILDERS = {
    "like_thief_00.png": like_thief, "like_thief_warn_00.png": like_thief_warn,
    "influencer_bot_placeholder_00.png": influencer_bot_placeholder, "false_reflection_00.png": false_reflection,
}
## Dibujos que no salen solo de la paleta del mundo (el Reflejo parte del sprite de Isak).
NOT_PALETTE_ONLY = {"false_reflection_00.png"}


def outputs():
    return {name: obj.binarize(build()) for name, build in BUILDERS.items()}


def outputs_for(rows):
    saved = obj.COLORS
    obj.COLORS = obj.palette_colors(rows)
    try:
        return outputs()
    finally:
        obj.COLORS = saved


def main(argv):
    return obj.write_or_check(OUT, outputs(), "--check" in argv, "gen_world3_enemies")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
