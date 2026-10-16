#!/usr/bin/env python3
"""Valida el arte del hub (tools/gen_hub_objects.py) en assets/sprites/hub/.

Para cada PNG comprueba, con check_asset de tools/validate_world1_assets.py:
tamano segun su carpeta y prefijo, colores solo de assets/palettes/hub.gpl, alfa
0 o 255 y fondo transparente (el fondo de pantalla debe ser opaco); los tiles que
se repiten en horizontal, sin costura. Ademas: ningun rojo reservado
(#dc0000, #ff3838), estan todos los archivos que produce el generador (y ninguno
mas), los PNG estan al dia con el generador (mismos pixeles) y los SpriteFrames
(assets/sprites/hub/*_frames.tres) coinciden con los que escribiria.

Uso (desde la raiz del repo, sin argumentos): python3 -I tools/validate_hub_objects.py
Sale con 1 si hay errores. Pillow puede estar en el site de usuario: se anade a
sys.path a mano para que funcione tambien con python3 -I.
"""
import glob
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
from validate_world1_assets import check_asset, load_gpl  # noqa: E402
import gen_hub_objects  # noqa: E402

HUB = os.path.join(REPO, "assets", "sprites", "hub")
RESERVED = {(0xdc, 0x00, 0x00), (0xff, 0x38, 0x38)}
# (carpeta, prefijo): (ancho, alto, needs_transparency)
SIZES = {
    ("background", "hub_bg_"): (1280, 720, False),
    ("tiles", "dock_top_"): (64, 64, False),
    ("tiles", "dock_fill"): (64, 64, False),
    ("tiles", "one_way_"): (64, 64, True),
    ("folders", "folder_"): (128, 128, True),
    ("notas", "notas_"): (64, 128, True),
    ("calc", "calc_"): (64, 96, True),
    ("dock_slots", "dock_slot_"): (64, 96, True),
    ("papelera", "papelera_"): (64, 96, True),
    ("icons", "icon_"): (16, 16, True),
    ("album", "album_cell"): (40, 40, True),
    ("album", "album_folder_"): (32, 32, True),
    ("icons", "world_icon_"): (16, 16, True),
    ("icons", "page_dot_"): (8, 8, True),
}
SEAMLESS = ("dock_top_center", "dock_fill_00", "dock_fill_alt", "one_way_center")


def main():
    pal = load_gpl(os.path.join(REPO, "assets", "palettes", "hub.gpl"), set())
    errs = []
    if pal & RESERVED:
        errs.append("hub.gpl contiene un rojo reservado")
    files = sorted(glob.glob(os.path.join(HUB, "*", "*.png")))
    expected = gen_hub_objects.outputs()
    rel = {os.path.relpath(f, HUB).replace(os.sep, "/") for f in files}
    for k in sorted(set(expected) - rel):
        errs.append(f"falta {k} (regenera con python3 -I tools/gen_hub_objects.py)")
    for k in sorted(rel - set(expected)):
        errs.append(f"{k}: no lo produce el generador")
    for f in files:
        folder, name = os.path.basename(os.path.dirname(f)), os.path.basename(f)
        key = next((k for k in SIZES if k[0] == folder and name.startswith(k[1])), None)
        if key is None:
            errs.append(f"{folder}/{name}: carpeta o prefijo desconocido")
            continue
        w, h, transp = SIZES[key]
        errs += check_asset({"path": f, "frame_size": [w, h], "columns": 1, "rows": 1,
                             "needs_transparency": transp,
                             "seamless_x": name.startswith(SEAMLESS)}, pal)
        k = f"{folder}/{name}"
        if k in expected:
            cur = Image.open(f).convert("RGBA")
            if cur.size == expected[k].size and cur.tobytes() != expected[k].convert("RGBA").tobytes():
                errs.append(f"{k}: distinto de lo que genera tools/gen_hub_objects.py (regenera)")
    for k, text in gen_hub_objects.frames_resources().items():
        tres = os.path.join(HUB, k)
        if not os.path.exists(tres):
            errs.append(f"falta {k} (regenera con python3 -I tools/gen_hub_objects.py)")
        else:
            with open(tres, encoding="utf-8") as fh:
                if fh.read() != text:
                    errs.append(f"{k}: distinto de lo que genera tools/gen_hub_objects.py (regenera)")
    print("\n".join(errs) if errs else f"validate_hub_objects: OK ({len(files)} PNG, {len(pal)} colores de hub.gpl)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
