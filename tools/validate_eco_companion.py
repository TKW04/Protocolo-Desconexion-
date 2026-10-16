#!/usr/bin/env python3
"""Valida el arte de Eco companero (tools/gen_eco_companion.py).

Para cada PNG que lista el generador comprueba, con check_asset de
tools/validate_world1_assets.py, tamano 32x32, alfa 0 o 255, fondo
transparente y colores: los normales solo de mundo1.gpl (sin rojo, carmin ni
ambar) y los atenuados (_dim, hub) solo de hub.gpl (sin ambar ni los rojos
reservados). Ademas: no hay PNG de mas en la carpeta, los PNG estan al dia con
el generador y el SpriteFrames (assets/sprites/eco_companion_frames.tres)
coincide con el que escribiria.

Uso (desde la raiz del repo): python3 -I tools/validate_eco_companion.py
Sale con 1 si hay errores.
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
import gen_eco_companion as gen  # noqa: E402
from gen_warp_objects import sprite_frames_tres  # noqa: E402

FORBIDDEN_M1 = {"alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra", "debug_cian"}
FORBIDDEN_HUB = {"ambar", "ambar_sombra"}
RESERVED = {(0xdc, 0x00, 0x00), (0xff, 0x38, 0x38)}


def main():
    pal_m1 = load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), FORBIDDEN_M1)
    pal_hub = load_gpl(os.path.join(REPO, "assets/palettes/hub.gpl"), FORBIDDEN_HUB) - RESERVED
    errs = []
    imgs = gen.outputs()
    for rel, expected in sorted(imgs.items()):
        path = os.path.join(REPO, "assets/sprites", rel)
        pal = pal_hub if "_dim_" in os.path.basename(rel) else pal_m1
        errs += check_asset({"path": path, "frame_size": [gen.SIZE, gen.SIZE], "columns": 1, "rows": 1,
                             "needs_transparency": True, "seamless_x": False}, pal)
        if os.path.exists(path) and Image.open(path).convert("RGBA").tobytes() != expected.tobytes():
            errs.append(f"{rel}: no coincide con tools/gen_eco_companion.py (regenera)")
    on_disk = {os.path.relpath(p, os.path.join(REPO, "assets/sprites"))
               for p in glob.glob(os.path.join(REPO, "assets/sprites", gen.OUT_DIR, "*.png"))}
    for extra in sorted(on_disk - set(imgs)):
        errs.append(f"{extra}: sobra (no lo genera tools/gen_eco_companion.py)")
    tres = os.path.join(REPO, gen.FRAMES_TRES)
    if not os.path.exists(tres):
        errs.append(f"{gen.FRAMES_TRES}: no existe")
    else:
        with open(tres, encoding="utf-8") as fh:
            if fh.read() != sprite_frames_tres(gen.animations()):
                errs.append(f"{gen.FRAMES_TRES}: no coincide con tools/gen_eco_companion.py (regenera)")
    print("\n".join(errs) if errs else f"OK ({len(imgs)} PNG y {gen.FRAMES_TRES})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
