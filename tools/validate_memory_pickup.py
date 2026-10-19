#!/usr/bin/env python3
"""Valida el arte del mensaje de secreto recogible (memory_pickup)
(tools/gen_memory_pickup.py).

Comprueba, para cada PNG que genera el script: que existe, su tamano, colores
solo de mundo1.gpl + effects_pulse.gpl, alfa 0 o 255, fondo transparente
(check_asset de tools/validate_world1_assets.py), que no usa rojos ni ambar
(el rojo es dano; el ambar, puntos de atencion), que el PNG en disco es igual al
que dibuja el script hoy, que tiene su .import y que
assets/sprites/memory_pickup_frames.tres esta al dia.

Uso (desde la raiz del repo): python3 -I tools/validate_memory_pickup.py
Sale con 1 si hay errores.
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
from validate_world1_assets import check_asset, load_gpl  # noqa: E402
import gen_memory_pickup as gen  # noqa: E402

SIZES = {"pickups/memory_pickup_": gen.SIZE}


def main():
    pal = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), set())
           | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    forbidden = {gen.PAL[name][:3] for name in gen.FORBIDDEN}
    errs = []
    expected = gen.outputs()
    for rel, img in expected.items():
        path = os.path.join(REPO, "assets/sprites", rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 tools/gen_memory_pickup.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (abre el proyecto en Godot o importalo con --import)")
        size = next(s for k, s in SIZES.items() if rel.startswith(k))
        errs += check_asset({"path": path, "frame_size": list(size), "columns": 1, "rows": 1,
                             "needs_transparency": True, "seamless_x": False}, pal)
        disk = Image.open(path).convert("RGBA")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_memory_pickup.py (regeneralo)")
        if any(px[3] == 255 and px[:3] in forbidden for px in disk.getdata()):
            errs.append(f"{rel}: usa un rojo o el ambar (prohibidos en el mensaje de secreto)")
    tres = os.path.join(REPO, "assets/sprites", gen.FRAMES_TRES)
    if not os.path.exists(tres):
        errs.append(f"{gen.FRAMES_TRES}: no existe")
    else:
        with open(tres, encoding="utf-8") as fh:
            if fh.read() != gen.frames_resource():
                errs.append(f"{gen.FRAMES_TRES}: no esta al dia (python3 tools/gen_memory_pickup.py)")
    print("\n".join(errs) if errs else f"OK ({len(expected)} PNG + {gen.FRAMES_TRES})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
