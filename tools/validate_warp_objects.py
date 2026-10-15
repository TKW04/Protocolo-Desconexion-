#!/usr/bin/env python3
"""Valida los sprites del vortice y de la terminal de salida (tools/gen_warp_objects.py).

Para cada PNG que lista el generador comprueba tamano, colores solo de
mundo1.gpl + effects_pulse.gpl (sin rojo, carmin ni ambar), alfa 0 o 255 y fondo
transparente (check_asset de tools/validate_world1_assets.py), que el PNG del
disco es el que genera el script (al dia) y que el SpriteFrames
(assets/sprites/warp_objects_frames.tres) coincide con el que escribiria.

Uso (desde la raiz del repo): python3 tools/validate_warp_objects.py
Sale con 1 si hay errores. Pillow puede estar en el site de usuario: se anade a
sys.path a mano para que funcione tambien con python3 -I.
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
import gen_warp_objects as gen  # noqa: E402

FORBIDDEN = {"alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra"}


def main():
    pal = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), FORBIDDEN)
           | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    errs = []
    imgs = gen.outputs()
    for rel, expected in sorted(imgs.items()):
        path = os.path.join(REPO, "assets/sprites", rel)
        errs += check_asset({"path": path, "frame_size": list(expected.size), "columns": 1, "rows": 1,
                             "needs_transparency": True, "seamless_x": False}, pal)
        if os.path.exists(path) and Image.open(path).convert("RGBA").tobytes() != expected.tobytes():
            errs.append(f"{rel}: no coincide con tools/gen_warp_objects.py (regenera)")
    tres = os.path.join(REPO, gen.FRAMES_TRES)
    if not os.path.exists(tres):
        errs.append(f"{gen.FRAMES_TRES}: no existe")
    else:
        with open(tres, encoding="utf-8") as fh:
            if fh.read() != gen.sprite_frames_tres(gen.animations()):
                errs.append(f"{gen.FRAMES_TRES}: no coincide con tools/gen_warp_objects.py (regenera)")
    print("\n".join(errs) if errs else f"OK ({len(imgs)} PNG y {gen.FRAMES_TRES})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
