#!/usr/bin/env python3
"""Valida el arte del encuentro con Calc (tools/gen_calc_encounter.py; tanda H1 del paso 14
de docs/propuesta-1-2.md).

Para cada PNG que genera el script: que existe, su tamano, colores solo de su paleta
(objetos del cuarto: mundo1.gpl + effects_pulse.gpl, sin rojos ni ambar; Calc: hub.gpl, sin
rojos), alfa 0 o 255, pixeles opacos en cada cuadro (y transparencia salvo la puerta, que
llena su bloque de pared), que el PNG en disco es igual al que dibuja el script hoy, que
tiene su .import y que assets/sprites/calc_encounter_frames.tres y calc_actor_frames.tres
estan al dia.

Uso (desde la raiz del repo): python3 -I tools/validate_calc_encounter.py
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
import gen_calc_encounter as gen  # noqa: E402


def main():
    world = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), set())
             | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    hub = load_gpl(os.path.join(REPO, "assets/palettes/hub.gpl"), set())
    forbidden = {gen.PAL[name][:3] for name in gen.FORBIDDEN}
    errs = []
    expected = gen.outputs()
    anims = gen.OBJ_ANIMS + gen.CALC_ANIMS
    anim_files = {"%s_%02d.png" % (prefix, i) for _, prefix, n, _, _ in anims for i in range(n)}
    if anim_files != set(expected):
        errs.append("ANIMS y outputs() no coinciden: %s" % sorted(anim_files ^ set(expected)))
    for rel, img in expected.items():
        path = os.path.join(REPO, "assets/sprites", rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 -I tools/gen_calc_encounter.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (importalo con Godot --import)")
        size = gen.size_of(rel)
        opaque_ok = os.path.basename(rel).startswith(gen.OPAQUE_OK)
        errs += check_asset({"path": path, "frame_size": list(size), "columns": 1, "rows": 1,
                             "needs_transparency": not opaque_ok, "seamless_x": False},
                            hub if gen.is_calc(rel) else world)
        disk = Image.open(path).convert("RGBA")
        if not any(px[3] == 255 for px in disk.getdata()):
            errs.append(f"{rel}: cuadro sin pixeles opacos")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_calc_encounter.py (regeneralo)")
        if not gen.is_calc(rel) and any(px[3] == 255 and px[:3] in forbidden for px in disk.getdata()):
            errs.append(f"{rel}: usa un rojo o el ambar (prohibidos en estos objetos)")
    for name, text in gen.frames_resources().items():
        tres = os.path.join(REPO, "assets/sprites", name)
        if not os.path.exists(tres):
            errs.append(f"{name}: no existe")
            continue
        with open(tres, encoding="utf-8") as fh:
            if fh.read() != text:
                errs.append(f"{name}: no esta al dia (python3 -I tools/gen_calc_encounter.py)")
    print("\n".join(errs) if errs else f"OK ({len(expected)} PNG + {gen.OBJ_TRES} + {gen.CALC_TRES})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
