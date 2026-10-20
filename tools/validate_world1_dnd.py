#!/usr/bin/env python3
"""Valida el arte del 1-3 «No molestar» (tools/gen_world1_dnd.py; paso 8 de
docs/propuesta-1-3.md §7).

Para cada PNG que genera el script: que existe y tiene su .import, que es igual a lo
que dibuja el script hoy y, salvo la pose provisional de Isak (arte de IA, sin .gpl),
su tamano, colores solo de mundo1.gpl + effects_pulse.gpl, alfa 0 o 255 y fondo
transparente (salvo la onda, que llena su lienzo) (check_asset de tools/validate_world1_assets.py); que no usa el ambar ni
el carmin y que el rojo (alerta, alerta_sombra) solo sale en la campana y su onda (y
en la ficha del banner, que lo trae). Comprueba ademas que
assets/sprites/dnd_objects_frames.tres esta al dia.

Uso (desde la raiz del repo): python3 -I tools/validate_world1_dnd.py
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
import gen_world1_dnd as gen  # noqa: E402

# La onda de la campana se repite en vertical y llena su lienzo (sin fondo transparente).
OPAQUE_OK = ("enemies/alarm_bell/alarm_wave_",)


def main():
    pal = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), set())
           | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    forbidden = {gen.PAL[name][:3] for name in gen.FORBIDDEN}
    red = {gen.PAL[name][:3] for name in gen.RED}
    errs = []
    expected = gen.outputs()
    for rel, img in expected.items():
        path = os.path.join(REPO, "assets/sprites", rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 tools/gen_world1_dnd.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (abre el proyecto en Godot o importalo con --import)")
        disk = Image.open(path).convert("RGBA")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_world1_dnd.py (regeneralo)")
        if rel.startswith("isak/"):
            if disk.size != (128, 128):
                errs.append(f"{rel}: mide {disk.size}, no 128x128")
            continue
        errs += check_asset({"path": path, "frame_size": list(img.size), "columns": 1, "rows": 1,
                             "needs_transparency": not rel.startswith(OPAQUE_OK), "seamless_x": False}, pal)
        opaque = [px[:3] for px in disk.getdata() if px[3] == 255]
        if any(c in forbidden for c in opaque):
            errs.append(f"{rel}: usa el ambar o el carmin (prohibidos)")
        if not rel.startswith(gen.RED_OK_PREFIX) and any(c in red for c in opaque):
            errs.append(f"{rel}: usa rojo (solo para lo que dana y sus avisos)")
    tres = os.path.join(REPO, "assets/sprites", gen.FRAMES_TRES)
    if not os.path.exists(tres):
        errs.append(f"{gen.FRAMES_TRES}: no existe")
    else:
        with open(tres, encoding="utf-8") as fh:
            if fh.read() != gen.frames_resource():
                errs.append(f"{gen.FRAMES_TRES}: no esta al dia (python3 tools/gen_world1_dnd.py)")
    print("\n".join(errs) if errs else f"OK ({len(expected)} PNG + {gen.FRAMES_TRES})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
