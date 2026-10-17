#!/usr/bin/env python3
"""Valida el arte de la tienda de Calc por pistas (tools/gen_calc_chips.py; tanda M1 de
docs/propuesta-mejoras.md).

Para cada PNG del script: que existe y tiene su .import, el tamano de la hoja y de sus cuadros,
colores solo de assets/palettes/hub.gpl y sin rojos, alfa 0 o 255, transparencia y algo opaco en
cada chip, cuadros de nivel opacos, que el PNG en disco es igual al que dibuja el script hoy, que
cada estado de recuadro se distingue de los demas y que data/hub.json (seccion calc, art) usa las
mismas rutas, tamanos y nombres de iconos y estados.

Uso (desde la raiz del repo): python3 -I tools/validate_calc_chips.py
Sale con 1 si hay errores.
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
from validate_world1_assets import check_asset, load_gpl  # noqa: E402
import gen_calc_chips as gen  # noqa: E402

# Rojos reservados fuera del hub (assets/palettes/hub.gpl): nunca en el arte del hub.
RESERVED_REDS = {(0xdc, 0x00, 0x00), (0xff, 0x38, 0x38)}


def main():
    hub = load_gpl(os.path.join(REPO, "assets/palettes/hub.gpl"), set())
    errs = []
    expected = gen.outputs()
    specs = {
        gen.CHIPS_PATH: {"frame_size": [gen.CHIP, gen.CHIP], "columns": len(gen.ICONS), "rows": len(gen.CHIP_ROWS),
                         "needs_transparency": True},
        gen.BOXES_PATH: {"frame_size": [gen.BOX_W, gen.BOX_H], "columns": len(gen.BOXES), "rows": 1,
                         "needs_transparency": False},
    }
    for rel, img in expected.items():
        path = os.path.join(REPO, rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 -I tools/gen_calc_chips.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (importalo con Godot --import)")
        entry = dict(specs[rel], path=path, seamless_x=False)
        errs += check_asset(entry, hub)
        disk = Image.open(path).convert("RGBA")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_calc_chips.py (regeneralo)")
        if any(px[3] == 255 and px[:3] in RESERVED_REDS for px in disk.getdata()):
            errs.append(f"{rel}: usa un rojo reservado")
    boxes = expected[gen.BOXES_PATH]
    frames = [boxes.crop((i * gen.BOX_W, 0, (i + 1) * gen.BOX_W, gen.BOX_H)).tobytes() for i in range(len(gen.BOXES))]
    if len(set(frames)) != len(frames):
        errs.append("calc_level_boxes.png: hay estados de recuadro iguales")
    chips = expected[gen.CHIPS_PATH]
    for col, icon in enumerate(gen.ICONS):
        a = chips.crop((col * gen.CHIP, 0, (col + 1) * gen.CHIP, gen.CHIP)).tobytes()
        b = chips.crop((col * gen.CHIP, gen.CHIP, (col + 1) * gen.CHIP, 2 * gen.CHIP)).tobytes()
        if a == b:
            errs.append(f"calc_chips.png: el chip {icon} elegido no se distingue del normal")
    with open(os.path.join(REPO, "data/hub.json"), encoding="utf-8") as fh:
        art = json.load(fh)["calc"].get("art", {})
    checks = [("chips", "res://" + gen.CHIPS_PATH), ("boxes", "res://" + gen.BOXES_PATH)]
    for key, res in checks:
        if art.get(key) != res:
            errs.append(f"data/hub.json calc.art.{key}: {art.get(key)!r} (deberia ser {res!r})")
    if art.get("chip_size") != [gen.CHIP, gen.CHIP] or art.get("box_size") != [gen.BOX_W, gen.BOX_H]:
        errs.append("data/hub.json calc.art: chip_size o box_size no coinciden con el generador")
    if art.get("chip_icons") != gen.ICONS or art.get("box_states") != gen.BOXES:
        errs.append("data/hub.json calc.art: chip_icons o box_states no coinciden con el generador")
    print("\n".join(errs) if errs else f"OK ({len(expected)} PNG)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
