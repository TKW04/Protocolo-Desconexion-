#!/usr/bin/env python3
"""Fondo del centro comercial del Mundo 5 «La Tienda» por script (paso 9 de docs/propuesta-mundo-5.md §8 y §6.3).

Fondo horizontal en tres capas de 1280 x 720 que se repiten sin costura (como el del 1-1 y el del Mundo 3), con la
paleta del Mundo 5 (variante elegida):
  mundo5_bg_galeria.png      opaca: galeria de madrugada (negro_fondo) con escaparates apagados cada 128 px
                             (cristal negro_medio con marco gris_escaparate), cornisa oscura arriba y zocalo
                             de baldosa abajo
  mundo5_bg_escaparates.png  en paralaje: maniquies en gris_escaparate, carteles de precio amarillos pequenos
                             (precios que parpadean: en el PNG, encendidos) y la escalera mecanica al fondo
  mundo5_bg_neones.png       neones del techo en magenta y violeta (tiras finas: tramados para que no lave el fondo)
en assets/sprites/backgrounds/, data/world5_background.json (formato de data/world1_background.json, que lee
scripts/levels/world1_background.gd) y scenes/levels/world5_background.tscn (World5Background, que hereda de
World1Background; tools/level_catalog.py lo usa para los niveles con "world": 5).

Lo claro y lo saturado del fondo (carteles amarillos, neones) es poco a proposito: el cian de Isak y la esfera de
Eco tienen que contrastar >= 3:1 con el fondo (regla 7 de §6.1); lo mide
tools/validate_world5_tiles.py.

Uso: python3 -I tools/gen_world5_background.py [--check]
"""
import json
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_world5_objects as obj  # noqa: E402

W, H = 1280, 720
BG_DIR = os.path.join("assets", "sprites", "backgrounds")
LAYERS = (("Galeria", "mundo5_bg_galeria.png", 0.1), ("Escaparates", "mundo5_bg_escaparates.png", 0.25),
          ("Neones", "mundo5_bg_neones.png", 0.45))
DATA_REL = os.path.join("data", "world5_background.json")
SCENE_REL = os.path.join("scenes", "levels", "world5_background.tscn")
FLOOR_Y = 600


def C(name):
    return obj.C(name)


def galeria():
    """Capa opaca: periodo de 128 px (se repite sin costura)."""
    img, d = obj.canvas(W, H)
    d.rectangle((0, 0, W - 1, H - 1), fill=C("negro_fondo"))
    d.rectangle((0, 0, W - 1, 35), fill=C("tienda_noche"))            # cornisa
    d.rectangle((0, 36, W - 1, 41), fill=C("negro_medio"))
    for x in range(0, W, 128):                                          # escaparates apagados
        d.rectangle((x + 12, 96, x + 115, FLOOR_Y - 72), fill=C("negro_medio"), outline=C("gris_escaparate"))
        d.line((x + 63, 96, x + 63, FLOOR_Y - 72), fill=C("gris_escaparate"))
        d.rectangle((x + 12, 70, x + 115, 87), fill=C("gris_escaparate"))   # rotulo apagado
        d.rectangle((x + 30, 76, x + 97, 80), fill=C("negro_medio"))
    d.rectangle((0, FLOOR_Y - 60, W - 1, H - 1), fill=C("negro_medio"))   # zocalo de baldosa
    d.rectangle((0, FLOOR_Y - 60, W - 1, FLOOR_Y - 59), fill=C("gris_escaparate"))
    for x in range(0, W, 64):
        d.line((x, FLOOR_Y - 58, x, H - 1), fill=C("negro_fondo"))
    return img


MANNEQUINS = (80, 336, 720, 1000)
TAGS = ((190, 300), (470, 260), (600, 330), (860, 280), (1130, 310))
ESCALATOR = (900, 1180)


def escaparates():
    img, d = obj.canvas(W, H)
    for mx in MANNEQUINS:                                                # maniquies en los escaparates
        d.ellipse((mx - 9, 200, mx + 8, 217), fill=C("gris_escaparate"))
        d.rectangle((mx - 4, 218, mx + 3, 224), fill=C("gris_escaparate"))
        d.polygon([(mx - 22, 226), (mx + 21, 226), (mx + 14, 330), (mx - 15, 330)], fill=C("gris_escaparate"))
        d.rectangle((mx - 13, 331, mx - 6, 440), fill=C("gris_escaparate"))
        d.rectangle((mx + 5, 331, mx + 12, 440), fill=C("gris_escaparate"))
        d.rectangle((mx - 20, 448, mx + 19, 453), fill=C("gris_escaparate"))
    for tx, ty in TAGS:                                                  # precios que parpadean (pequenos)
        d.rectangle((tx, ty, tx + 27, ty + 13), fill=C("amarillo_sombra"))
        d.rectangle((tx + 4, ty + 5, tx + 19, ty + 7), fill=C("negro_medio"))
    x0, x1 = ESCALATOR                                                   # escalera mecanica al fondo
    for k in range(0, 14):
        x = x0 + k * 20
        y = FLOOR_Y - 80 - k * 24
        if x + 20 > x1:
            break
        d.rectangle((x, y, x + 19, y + 3), fill=C("gris_escaparate"))
    d.line((x0, FLOOR_Y - 70, x1 - 20, FLOOR_Y - 70 - (x1 - 20 - x0) * 6 // 5), fill=C("gris_escaparate"), width=3)
    return img


NEONS = ((60, 250, "magenta_neon"), (420, 560, "violeta_neon"), (760, 860, "magenta_neon"),
         (1000, 1200, "violeta_neon"))


def neones():
    img, d = obj.canvas(W, H)
    px = img.load()
    for a, b, color in NEONS:
        d.rectangle((a, 48, b, 49), fill=C(color))                       # tira de neon
        d.rectangle((a, 50, b, 50), fill=C(color.replace("_neon", "_sombra") if color == "magenta_neon"
                                         else "negro_medio"))
        for y in range(52, 64):                                          # resplandor tramado al 25 %
            for x in range(a, b + 1):
                if (x + y) % 2 == 0 and y % 4 < 2:
                    px[x, y] = C("magenta_sombra")
    return img


def layers():
    return {name: builder() for (_n, name, _s), builder in zip(LAYERS, (galeria, escaparates, neones))}


def composite():
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for img in layers().values():
        out.alpha_composite(img)
    return out


def data_text():
    data = {
        "_notes": ("Fondo del centro comercial del Mundo 5 (generado por tools/gen_world5_background.py; no editar a "
                   "mano). Mismo formato que data/world1_background.json (scripts/levels/world1_background.gd): "
                   "capas de atras hacia delante con scroll_scale y repeat_size; galeria con escaparates apagados, "
                   "maniquies, precios y la escalera mecanica en paralaje y neones del techo. Sin capa de torre (los "
                   "niveles del Mundo 5 son horizontales por plantas)."),
        "z_index": -100,
        "layers": [{"name": n, "texture": "res://" + os.path.join(BG_DIR, f).replace(os.sep, "/"),
                    "scroll_scale": [s, 0.0], "repeat_size": [W, 0], "repeat_times": 3}
                   for n, f, s in LAYERS],
    }
    return json.dumps(data, indent="\t", ensure_ascii=False) + "\n"


# La escena usa World5Background (hereda de World1Background): el audio del Mundo 5 (amb_w5_mall, mus_w5_level;
# paso 20) se enlazara por su clase, como en los Mundos 3 y 4.
SCENE_TEXT = ('[gd_scene load_steps=2 format=3]\n\n'
              '[ext_resource type="Script" path="res://scripts/levels/world5_background.gd" id="1_bg"]\n\n'
              '[node name="World5Background" type="Node2D"]\n'
              'script = ExtResource("1_bg")\n'
              'data_path = "res://data/world5_background.json"\n')


def main(argv):
    check = "--check" in argv
    errors = []
    for name, img in layers().items():
        path = os.path.join(REPO, BG_DIR, name)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                errors.append("%s no esta al dia" % os.path.join(BG_DIR, name))
        else:
            img.save(path, optimize=True)
    for rel, text in ((DATA_REL, data_text()), (SCENE_REL, SCENE_TEXT)):
        path = os.path.join(REPO, rel)
        if check:
            if not os.path.exists(path) or open(path, encoding="utf-8").read() != text:
                errors.append("%s no esta al dia" % rel)
        else:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
    for error in errors:
        print("gen_world5_background: %s (python3 -I tools/gen_world5_background.py)" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
