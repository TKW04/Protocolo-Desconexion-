#!/usr/bin/env python3
"""Valida el arte de los efectos de las mejoras de Calc de la tanda M2 (tools/gen_upgrade_fx.py).

Comprueba assets/sprites/effects/upgrade_fx.png: que existe y tiene su .import, el tamano de la hoja y
de sus cuadros (24x24, 6 columnas x 3 filas), colores solo de assets/palettes/mundo1.gpl y SIN los
rojos (alerta, alerta_sombra, carmin y carmin_brillo: el rojo es dano), alfa 0 o 255, transparencia y
algo opaco en cada cuadro, que el PNG en disco es igual al que dibuja el script hoy, que no hay dos
cuadros iguales dentro de una animacion y que data/upgrade_fx.json usa la misma ruta, cuadro,
columnas y filas. Tambien que el icono «oculto» del HUD (assets/sprites/ui/hud_hide.png, de
tools/gen_hud_assets.py) no usa rojos.

Uso (desde la raiz del repo): python3 -I tools/validate_upgrade_fx.py
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
import gen_upgrade_fx as gen  # noqa: E402

GPL = os.path.join(REPO, "assets/palettes/mundo1.gpl")
HUD_HIDE = "assets/sprites/ui/hud_hide.png"


def main():
    palette = load_gpl(GPL, set(gen.FORBIDDEN))
    reds = load_gpl(GPL, set()) - palette
    errs = []
    for rel, img in gen.outputs().items():
        path = os.path.join(REPO, rel)
        if not os.path.exists(path):
            errs.append(f"{rel}: no existe (python3 -I tools/gen_upgrade_fx.py)")
            continue
        if not os.path.exists(path + ".import"):
            errs.append(f"{rel}: falta el .import (importalo con Godot --import)")
        entry = {"path": path, "frame_size": [gen.FRAME, gen.FRAME], "columns": gen.COLUMNS,
                 "rows": len(gen.ROWS), "needs_transparency": True, "seamless_x": False}
        errs += check_asset(entry, palette)
        disk = Image.open(path).convert("RGBA")
        if disk.tobytes() != img.tobytes():
            errs.append(f"{rel}: no coincide con lo que dibuja tools/gen_upgrade_fx.py (regeneralo)")
        for row, name in enumerate(gen.ROWS):
            frames = [img.crop((c * gen.FRAME, row * gen.FRAME, (c + 1) * gen.FRAME, (row + 1) * gen.FRAME)).tobytes()
                      for c in range(gen.COLUMNS)]
            if len(set(frames)) != len(frames):
                errs.append(f"{rel}: la animacion {name} repite un cuadro")
    with open(os.path.join(REPO, "data/upgrade_fx.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    if data.get("texture") != "res://" + gen.OUT_PATH:
        errs.append(f"data/upgrade_fx.json texture: {data.get('texture')!r}")
    if data.get("frame_size") != [gen.FRAME, gen.FRAME] or data.get("columns") != gen.COLUMNS:
        errs.append("data/upgrade_fx.json: frame_size o columns no coinciden con el generador")
    rows = {name: anim.get("row") for name, anim in data.get("animations", {}).items()}
    if rows != {name: i for i, name in enumerate(gen.ROWS)}:
        errs.append(f"data/upgrade_fx.json animations: filas {rows} (deberian ser {gen.ROWS})")
    hide = Image.open(os.path.join(REPO, HUD_HIDE)).convert("RGBA")
    if any(px[3] == 255 and px[:3] in reds for px in hide.getdata()):
        errs.append(f"{HUD_HIDE}: usa un rojo")
    print("\n".join(errs) if errs else f"OK ({len(gen.outputs())} PNG + {HUD_HIDE})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
