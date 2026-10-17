#!/usr/bin/env python3
"""Valida la fachada de la torre del Mundo 1 y sus pestanas (tools/gen_world1_facade.py;
paso 13 del 1-2, arte de fondo del paso 11 de docs/propuesta-1-2.md §10).

Comprueba, para cada PNG: que existe, su tamano, colores solo de mundo1.gpl +
effects_pulse.gpl, alfa 0 o 255, fondo transparente con algo opaco, que no usa
rojos, ambar ni los cianes del Debug y del pulso, que el PNG en disco es igual al
que dibuja el script hoy y que tiene su .import. La fachada ademas se repite en
VERTICAL sin costura (sus dos mitades son identicas y la union de abajo con arriba
es una de las uniones que ya hay dentro de la imagen) y la capa «Fachada» de
data/world1_background.json la usa en modo torre con repeat_size igual a su alto;
cada pestana de data/world1_background.json (tabs.textures) existe en el script. Desde el
2026-10-17 (contraste del 1-2): la fachada no usa los tonos claros de las plataformas y objetos
(resplandor, borde_luz, tile_luz, banner_*) y el velo de la torre (tower_dim) usa un color de la
paleta y atenuaciones de 0 a 1.

Uso (desde la raiz del repo): python3 -I tools/validate_world1_facade.py
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
import gen_world1_facade as gen  # noqa: E402


def seamless_y(img):
    px = img.load()
    rows = [tuple(px[x, y] for x in range(img.width)) for y in range(img.height)]
    return (rows[-1], rows[0]) in set(zip(rows, rows[1:]))


def main():
    pal = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), set())
           | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    forbidden = {gen.PAL[name][:3] for name in gen.FORBIDDEN}
    facade_forbidden = {gen.PAL[name][:3] for name in gen.FACADE_FORBIDDEN}
    errs = []
    expected = gen.outputs()
    for rel, img in expected.items():
        path = os.path.join(REPO, "assets/sprites", rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 tools/gen_world1_facade.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (importalo con Godot --import)")
        errs += check_asset({"path": path, "frame_size": list(img.size), "columns": 1, "rows": 1,
                             "needs_transparency": True, "seamless_x": False}, pal)
        disk = Image.open(path).convert("RGBA")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_world1_facade.py (regeneralo)")
        if any(px[3] == 255 and px[:3] in forbidden for px in disk.getdata()):
            errs.append(f"{rel}: usa un rojo, el ambar o un cian (prohibidos en el fondo)")
        if rel == gen.FACADE and any(px[3] == 255 and px[:3] in facade_forbidden for px in disk.getdata()):
            errs.append(f"{rel}: usa un tono claro de las plataformas u objetos (resplandor, borde_luz...)")
    fac = expected[gen.FACADE]
    if fac.size != (gen.FACADE_W * gen.UNIT, gen.FACADE_H * gen.UNIT):
        errs.append(f"{gen.FACADE}: tamano {fac.size}")
    half = fac.height // 2
    if fac.crop((0, 0, fac.width, half)).tobytes() != fac.crop((0, half, fac.width, fac.height)).tobytes():
        errs.append(f"{gen.FACADE}: las dos mitades no son identicas (periodo vertical)")
    if not seamless_y(fac):
        errs.append(f"{gen.FACADE}: costura al repetirse en vertical")
    with open(os.path.join(REPO, "data/world1_background.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    layer = next((lay for lay in data.get("layers", []) if lay.get("name") == "Fachada"), None)
    if layer is None:
        errs.append("data/world1_background.json: falta la capa Fachada")
    else:
        if layer.get("texture") != "res://assets/sprites/" + gen.FACADE or not layer.get("tower_only"):
            errs.append("data/world1_background.json: la capa Fachada no usa la fachada o no es tower_only")
        if [float(v) for v in layer.get("repeat_size", [])] != [0.0, float(fac.height)]:
            errs.append("data/world1_background.json: repeat_size de Fachada distinto de [0, %d]" % fac.height)
    # Velo de la torre (2026-10-17): color de la paleta y atenuacion entre 0 y 1 (global y por capa).
    dim = data.get("tower_dim")
    if not isinstance(dim, dict):
        errs.append("data/world1_background.json: falta tower_dim (velo de las capas en la torre)")
    else:
        if tuple(dim.get("color", [])) not in pal:
            errs.append("data/world1_background.json: tower_dim.color no es de la paleta")
        amounts = [dim.get("amount")] + [lay.get("tower", {}).get("dim") for lay in data.get("layers", [])
                                         if "dim" in lay.get("tower", {})]
        if not all(isinstance(a, (int, float)) and 0.0 <= a <= 1.0 for a in amounts):
            errs.append("data/world1_background.json: las atenuaciones de tower_dim van de 0 a 1")
    for label, tex in data.get("tabs", {}).get("textures", {}).items():
        rel = tex.replace("res://assets/sprites/", "")
        if rel not in expected:
            errs.append(f"pestana {label}: {tex} no la genera tools/gen_world1_facade.py")
    print("\n".join(errs) if errs else f"OK ({len(expected)} PNG)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
