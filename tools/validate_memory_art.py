#!/usr/bin/env python3
"""Valida las ilustraciones de los recuerdos de jefe (tools/gen_memory_art.py; paso 7
de docs/propuesta-recuerdos.md §11.3, 2026-10-22).

Comprueba, para cada PNG que genera el script: que existe y tiene su .import, su
tamano (128x64), colores solo de mundo1.gpl + effects_pulse.gpl, alfa 0 o 255 y
opaco (check_asset de tools/validate_world1_assets.py), sin rojos (el rojo es dano),
que el PNG en disco es igual al que dibuja el script hoy y que la version Caché es
distinta de la Kernel (borrosa). Ademas, que memory_art de la seccion album de
data/hub.json tiene ruta para las capas 1 (Caché) y 2 (Kernel) y NINGUNA para la 3
(Raíz: solo texto, §8.3) y que cada mundo con recuerdo de jefe en
data/memories.json tiene sus dos imagenes.

Uso (desde la raiz del repo): python3 -I tools/validate_memory_art.py
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
import gen_memory_art as gen  # noqa: E402


def check_config(hub, memories):
    """Errores de memory_art (data/hub.json) frente a los recuerdos de jefe."""
    errs = []
    art = hub.get("album", {}).get("memory_art")
    if not isinstance(art, dict):
        return ["data/hub.json: falta album.memory_art"]
    if "3" in art:
        errs.append("album.memory_art: la capa 3 (Raíz) no lleva ilustracion (solo texto)")
    expected = {"1": "res://assets/sprites/" + gen.PATH_CACHE, "2": "res://assets/sprites/" + gen.PATH_SHARP}
    for layer, pattern in expected.items():
        if art.get(layer) != pattern:
            errs.append("album.memory_art[%s]: debe ser %s" % (layer, pattern))
    worlds = sorted({m["world"] for m in memories.get("memories", []) if m.get("kind") == "boss"})
    for world in worlds:
        if world not in gen.SCENES:
            errs.append("mundo %d: tiene recuerdo de jefe y no tiene ilustracion" % world)
    return errs


def main():
    pal = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), set())
           | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    forbidden = {gen.PAL[name][:3] for name in gen.FORBIDDEN}
    errs = []
    expected = gen.outputs()
    for rel, img in expected.items():
        path = os.path.join(REPO, "assets/sprites", rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 tools/gen_memory_art.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (abre el proyecto en Godot o importalo con --import)")
        errs += check_asset({"path": path, "frame_size": list(gen.SIZE), "columns": 1, "rows": 1,
                             "needs_transparency": False, "seamless_x": False}, pal)
        disk = Image.open(path).convert("RGBA")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_memory_art.py (regeneralo)")
        if any(px[3] == 255 and px[:3] in forbidden for px in disk.getdata()):
            errs.append(f"{rel}: usa un rojo (prohibido: el rojo es dano)")
    for world in gen.WORLDS:
        sharp = expected[gen.PATH_SHARP % world]
        cache = expected[gen.PATH_CACHE % world]
        if sharp.tobytes() == cache.tobytes():
            errs.append(f"mundo {world}: la capa Caché no esta borrosa")
    with open(os.path.join(REPO, "data/hub.json"), encoding="utf-8") as fh:
        hub = json.load(fh)
    with open(os.path.join(REPO, "data/memories.json"), encoding="utf-8") as fh:
        memories = json.load(fh)
    errs += check_config(hub, memories)
    print("\n".join(errs) if errs else f"OK ({len(expected)} PNG)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
