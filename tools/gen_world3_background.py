#!/usr/bin/env python3
"""Fondo de la galeria del Mundo 3 «La Vitrina» por script (paso 9 de docs/propuesta-mundo-3.md §8 y §6.3).

Fondo horizontal en tres capas de 1280 x 720 que se repiten sin costura (como el del 1-1), con la paleta del
Mundo 3 (variante elegida):
  mundo3_bg_trastienda.png  opaca: papel pintado de la trastienda (malva medio-oscuro con franjas de
                            trastienda_medio), cornisa oscura arriba y zocalo con moldura abajo
  mundo3_bg_fotos.png       fotos enmarcadas en paralaje (marcos dorados finos y fotos oscuras con siluetas)
  mundo3_bg_focos.png       focos del techo con su haz tramado (trastienda_luz al 25 % de los pixeles)
en assets/sprites/backgrounds/, data/world3_background.json (formato de data/world1_background.json, que lee
scripts/levels/world1_background.gd) y scenes/levels/world3_background.tscn (el mismo script con ese JSON;
tools/level_catalog.py lo usa para los niveles con "world": 3).

Lo claro del fondo (marcos, haces) es poco a proposito: el cian de Isak y la esfera de Eco tienen que contrastar
>= 3:1 con el fondo (regla 3 de §6.1); lo mide tools/validate_world3_tiles.py.

Uso: python3 -I tools/gen_world3_background.py [--check]
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
import gen_world3_objects as obj  # noqa: E402

W, H = 1280, 720
BG_DIR = os.path.join("assets", "sprites", "backgrounds")
LAYERS = (("Trastienda", "mundo3_bg_trastienda.png", 0.1), ("Fotos", "mundo3_bg_fotos.png", 0.25),
          ("Focos", "mundo3_bg_focos.png", 0.45))
DATA_REL = os.path.join("data", "world3_background.json")
SCENE_REL = os.path.join("scenes", "levels", "world3_background.tscn")
FLOOR_Y = 600


def C(name):
    return obj.C(name)


def trastienda():
    img, d = obj.canvas(W, H)
    d.rectangle((0, 0, W - 1, H - 1), fill=C("trastienda_fondo"))
    for x in range(0, W, 64):        # papel pintado: franja doble cada 64 px
        d.rectangle((x + 30, 40, x + 31, FLOOR_Y - 60), fill=C("trastienda_medio"))
        d.rectangle((x + 34, 40, x + 34, FLOOR_Y - 60), fill=C("trastienda_medio"))
        for y in range(72, FLOOR_Y - 60, 64):   # rombo pequeno del estampado
            d.polygon([(x + 32, y - 3), (x + 35, y), (x + 32, y + 3), (x + 29, y)], fill=C("trastienda_medio"))
    d.rectangle((0, 0, W - 1, 31), fill=C("galeria_noche"))           # cornisa
    d.rectangle((0, 32, W - 1, 39), fill=C("trastienda_medio"))
    d.rectangle((0, FLOOR_Y - 60, W - 1, H - 1), fill=C("trastienda_medio"))   # zocalo
    d.rectangle((0, FLOOR_Y - 60, W - 1, FLOOR_Y - 58), fill=C("marco_sombra"))
    for x in range(0, W, 128):
        d.rectangle((x + 8, FLOOR_Y - 48, x + 119, FLOOR_Y + 40), outline=C("trastienda_fondo"), width=2)
    return img


PHOTOS = ((40, 120, 150, 110, "sun"), (250, 200, 96, 128, "portrait"), (420, 96, 180, 120, "hills"),
          (680, 170, 110, 140, "portrait"), (880, 110, 150, 100, "sun"), (1090, 190, 130, 110, "hills"))


def fotos():
    img, d = obj.canvas(W, H)
    for x, y, w, h, motif in PHOTOS:
        d.rectangle((x - 3, y - 3, x + w + 2, y + h + 2), fill=C("dorado"))
        d.rectangle((x - 3, y + h + 2, x + w + 2, y + h + 2), fill=C("marco_sombra"))
        d.rectangle((x, y, x + w - 1, y + h - 1), fill=C("galeria_noche"))
        if motif == "sun":
            d.ellipse((x + w - 40, y + 14, x + w - 20, y + 34), fill=C("trastienda_medio"))
            d.polygon([(x, y + h - 1), (x + w // 3, y + h // 2), (x + w * 2 // 3, y + h - 1)],
                      fill=C("trastienda_medio"))
        elif motif == "hills":
            d.polygon([(x, y + h - 1), (x + w // 4, y + h // 2), (x + w // 2, y + h - 20), (x + w * 3 // 4, y + h // 3),
                       (x + w - 1, y + h - 1)], fill=C("trastienda_medio"))
        else:
            cx = x + w // 2
            d.ellipse((cx - 18, y + 24, cx + 17, y + 59), fill=C("trastienda_medio"))
            d.rectangle((cx - 30, y + 66, cx + 29, y + h - 1), fill=C("trastienda_medio"))
        # cartela bajo la foto
        d.rectangle((x + w // 2 - 12, y + h + 8, x + w // 2 + 11, y + h + 13), fill=C("trastienda_medio"))
    return img


SPOTS = (96, 416, 736, 1056)


def focos():
    img, d = obj.canvas(W, H)
    px = img.load()
    for sx in SPOTS:
        d.rectangle((sx - 10, 24, sx + 9, 35), fill=C("marco_sombra"))
        d.rectangle((sx - 6, 36, sx + 5, 39), fill=C("dorado"))
        for y in range(40, 360):
            half = 6 + (y - 40) * 70 // 320
            for x in range(sx - half, sx + half):
                if (x + y) % 2 == 0 and y % 4 < 2 and 0 <= x < W:   # trama al 25 %
                    px[x, y] = C("trastienda_luz")
    return img


def layers():
    return {name: builder() for (_n, name, _s), builder in zip(LAYERS, (trastienda, fotos, focos))}


def composite():
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for img in layers().values():
        out.alpha_composite(img)
    return out


def data_text():
    data = {
        "_notes": ("Fondo de la galeria del Mundo 3 (generado por tools/gen_world3_background.py; no editar a mano). "
                   "Mismo formato que data/world1_background.json (scripts/levels/world1_background.gd): capas de "
                   "atras hacia delante con scroll_scale y repeat_size; trastienda malva, fotos enmarcadas en "
                   "paralaje y focos. Sin capa de torre (los niveles del Mundo 3 son horizontales)."),
        "z_index": -100,
        "layers": [{"name": n, "texture": "res://" + os.path.join(BG_DIR, f).replace(os.sep, "/"),
                    "scroll_scale": [s, 0.0], "repeat_size": [W, 0], "repeat_times": 3}
                   for n, f, s in LAYERS],
    }
    return json.dumps(data, indent="\t", ensure_ascii=False) + "\n"


SCENE_TEXT = ('[gd_scene load_steps=2 format=3]\n\n'
              '[ext_resource type="Script" path="res://scripts/levels/world1_background.gd" id="1_bg"]\n\n'
              '[node name="World3Background" type="Node2D"]\n'
              'script = ExtResource("1_bg")\n'
              'data_path = "res://data/world3_background.json"\n')


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
        print("gen_world3_background: %s (python3 -I tools/gen_world3_background.py)" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
