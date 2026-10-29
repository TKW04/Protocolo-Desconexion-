#!/usr/bin/env python3
"""Valida el arte de Eco companero (tools/gen_eco_companion.py).

Para cada PNG que lista el generador comprueba, con check_asset de
tools/validate_world1_assets.py, tamano 32x32, alfa 0 o 255, fondo
transparente y colores: los normales solo de mundo1.gpl (sin rojo, carmin ni
ambar), los ambar (_amber_, glow_in: Eco ofrece o explica una ayuda) de
mundo1.gpl con ambar y ambar_sombra (sin rojo ni carmin) y con dorado de
verdad (ambar y ambar_sombra presentes; glow_in_00 al menos una chispa) y los
atenuados (_dim, hub) solo de hub.gpl (sin ambar ni los rojos
reservados); el marco dorado del Mundo 3 (eco_frame_w3_00) solo dorado y dorado_luz de mundo3.gpl. Ademas: no hay PNG de mas en la carpeta, los PNG estan al dia con
el generador y el SpriteFrames (assets/sprites/eco_companion_frames.tres)
coincide con el que escribiria. Eco se ve igual en todos los mundos (decision del usuario 2026-10-29,
docs/04-personajes.md §12.1): ni data/eco_companion.json declara un cuerpo por mundo (world_sprite_frames)
ni data/eco_text_box.json un icono por mundo (world_icons), y el unico marco por mundo (world_frames) es el
dorado del Mundo 3 (parte de la referencia de los Mundos 1-3).

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
FORBIDDEN_AMBER = FORBIDDEN_M1 - {"ambar", "ambar_sombra"}
FORBIDDEN_HUB = {"ambar", "ambar_sombra"}
AMBER = (0xff, 0xa0, 0x00)
AMBER_SHADOW = (0xa8, 0x5f, 0x00)
RESERVED = {(0xdc, 0x00, 0x00), (0xff, 0x38, 0x38)}

# Mundos con marco propio permitidos (world_frames): el dorado del Mundo 3, que forma parte de la referencia.
ALLOWED_WORLD_FRAMES = {"3": "res://assets/sprites/eco/companion/eco_frame_w3_00.png"}


def check_same_eco_everywhere():
    """Errores si algun mundo declara una variante de Eco (cuerpo, icono o marco nuevo)."""
    import json
    errs = []
    with open(os.path.join(REPO, "data/eco_companion.json"), encoding="utf-8") as fh:
        comp = json.load(fh)
    with open(os.path.join(REPO, "data/eco_text_box.json"), encoding="utf-8") as fh:
        box = json.load(fh)
    if comp.get("world_sprite_frames"):
        errs.append("data/eco_companion.json: world_sprite_frames declara un Eco distinto por mundo (Eco es igual en todos)")
    if comp.get("world_frames", {}) != ALLOWED_WORLD_FRAMES:
        errs.append("data/eco_companion.json: world_frames solo puede llevar el marco del Mundo 3")
    if box.get("world_icons"):
        errs.append("data/eco_text_box.json: world_icons declara un icono de Eco por mundo (Eco es igual en todos)")
    for sid, info in box.get("speakers", {}).items():
        if isinstance(info, dict) and "world_icon" in info:
            errs.append(f"data/eco_text_box.json: speakers.{sid}.world_icon (sin iconos de Eco por mundo)")
    for k in ("FRAMES_TRES_W4", "ICON_W4", "animations_w4", "frame_w4"):
        if hasattr(gen, k):
            errs.append(f"tools/gen_eco_companion.py: {k} (variante de Eco por mundo)")
    for rel in ("assets/sprites/eco_companion_w4_frames.tres", "assets/sprites/eco/eco_icon_w4.png"):
        if os.path.exists(os.path.join(REPO, rel)):
            errs.append(f"{rel}: sobra (Eco es igual en todos los mundos)")
    return errs


def main():
    pal_m1 = load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), FORBIDDEN_M1)
    pal_amber = load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), FORBIDDEN_AMBER)
    pal_hub = load_gpl(os.path.join(REPO, "assets/palettes/hub.gpl"), FORBIDDEN_HUB) - RESERVED
    errs = []
    imgs = gen.outputs()
    for rel, expected in sorted(imgs.items()):
        path = os.path.join(REPO, "assets/sprites", rel)
        base = os.path.basename(rel)
        if rel == gen.FRAME_W3:
            used = {c[:3] for c in expected.getdata() if c[3] == 255}
            gold = gen.load_gpl(os.path.join(REPO, gen.M3_GPL))
            want = {gold["dorado"][:3], gold["dorado_luz"][:3]}
            if not used or not used <= want:
                errs.append(f"{rel}: el marco del Mundo 3 solo usa dorado y dorado_luz de mundo3.gpl")
            if os.path.exists(path) and Image.open(path).convert("RGBA").tobytes() != expected.tobytes():
                errs.append(f"{rel}: no coincide con tools/gen_eco_companion.py (regenera)")
            elif not os.path.exists(path):
                errs.append(f"{rel}: falta (regenera con tools/gen_eco_companion.py)")
            continue
        amber = "_amber_" in base or "_glow_in_" in base
        pal = pal_hub if "_dim_" in base else (pal_amber if amber else pal_m1)
        if amber:
            used = {c[:3] for c in expected.getdata() if c[3] == 255}
            if AMBER not in used or ("_amber_" in base and AMBER_SHADOW not in used):
                errs.append(f"{rel}: la variante ambar no usa el dorado de mundo1.gpl")
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
    errs += check_same_eco_everywhere()
    print("\n".join(errs) if errs else f"OK ({len(imgs)} PNG y {gen.FRAMES_TRES})")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
