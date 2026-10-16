#!/usr/bin/env python3
"""Valida los sprites del punto rojo y del banner (tools/gen_world1_enemies.py).

Comprueba:
  - las reglas comunes de los enemigos (tools/validate_enemy_sprites.py: cuadros que tocan, tamano
    entre 64 y 128, solo colores de mundo1.gpl sin debug_cian, alfa 0/255, esquinas transparentes,
    anticipate = anticipation_frames entre 6 y 12 a anim_fps);
  - que los PNG estan al dia con el generador (mismos pixeles);
  - punto rojo: wake dura wake_warn_frames a anim_fps (aviso de 6-12 cuadros antes de volver a
    perseguir); el cuerpo despierto usa el rojo alerta y el aturdido no (gris);
  - banner: el barrido usa banner_blanco y alerta (blanco con aviso rojo), y el aviso usa alerta;
  - existe el SpriteFrames (frames_resource) con las animaciones del JSON.

Uso (desde la raiz del repo): python3 -I tools/validate_world1_enemies.py
Sale con 1 si hay errores.
"""
import json
import os
import re
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_world1_enemies as gen  # noqa: E402
import validate_enemy_sprites as common  # noqa: E402


def colors(path):
    return {c[:3] for c in Image.open(path).convert("RGBA").getdata() if c[3] == 255}


def rgb(name):
    return gen.P[name][:3]


def main():
    errs = []
    for kind in gen.ENEMIES:
        path = os.path.join(REPO, "data", "enemies", kind + ".json")
        e, _n = common.check_enemy(path)
        errs += e
    for path, im in gen.outputs().items():
        name = os.path.relpath(path, REPO)
        if not os.path.exists(path):
            errs.append("falta %s (regenera con python3 -I tools/gen_world1_enemies.py)" % name)
            continue
        if Image.open(path).convert("RGBA").tobytes() != im.tobytes():
            errs.append("%s: distinto de lo que genera tools/gen_world1_enemies.py (regenera)" % name)
    with open(os.path.join(REPO, "data", "enemies", "notification_badge.json"), encoding="utf-8") as fh:
        badge = json.load(fh)
    spr = badge["sprites"]
    wake = spr["animations"]["wake"]
    n = int(badge["wake_warn_frames"])
    if not 6 <= n <= 12 or wake["frames"] != n or abs(float(wake["fps"]) - float(badge["anim_fps"])) > 1e-6:
        errs.append("notification_badge: wake debe tener wake_warn_frames (6-12) cuadros a anim_fps")
    d = gen.res_to_path(spr["dir"])
    if rgb("alerta") not in colors(os.path.join(d, "badge_chase_00.png")):
        errs.append("notification_badge: despierto debe ser rojo alerta")
    if rgb("alerta") in colors(os.path.join(d, "badge_stunned_00.png")):
        errs.append("notification_badge: aturdido no debe llevar rojo alerta (apagado, gris)")
    sweep = colors(os.path.join(d, "banner_sweep_00.png"))
    if not {rgb("banner_blanco"), rgb("alerta")} <= sweep:
        errs.append("spam_banner: el barrido debe ser banner_blanco con alerta")
    if rgb("alerta") not in colors(os.path.join(d, "banner_anticipate_08.png")):
        errs.append("spam_banner: el aviso debe usar el rojo alerta")
    for kind in gen.ENEMIES:
        cfg = gen.sprites_cfg(kind)
        tres = gen.res_to_path(cfg["frames_resource"])
        if not os.path.exists(tres):
            errs.append("%s: falta %s (Godot --headless -s tools/build_enemy_frames.gd)" % (kind, cfg["frames_resource"]))
            continue
        with open(tres, encoding="utf-8") as fh:
            body = fh.read()
        names = set(re.findall(r'"name": &"([a-z_]+)"', body))
        if names != set(cfg["animations"]):
            errs.append("%s: animaciones de %s %s distintas de las del JSON" % (kind, cfg["frames_resource"], sorted(names)))
    if errs:
        print("validate_world1_enemies: FALLOS")
        for e in errs:
            print("  - " + e)
        return 1
    print("validate_world1_enemies: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
