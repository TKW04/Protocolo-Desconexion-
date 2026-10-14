#!/usr/bin/env python3
"""Valida los sprites de los enemigos generados (p. ej. tools/gen_alert_bubble.py).

Para cada data/enemies/*.json con seccion "sprites" comprueba:
  - cada animacion tiene exactamente "frames" PNG <prefix>_<anim>_<NN>.png (00, 01, ...) y no
    sobra ninguno con ese prefijo
  - tamano = frame_size, entre 64x64 y 128x128 (enemigos a 1280x720, pixel-art-pipeline)
  - solo colores de la paleta (sin los nombres de palette_exclude) y alfa 0 o 255
  - fondo transparente (las cuatro esquinas con alfa 0) y algo opaco en cada cuadro
  - si el JSON trae anticipation_frames: coincide con los cuadros de "anticipate", esta entre 6
    y 12 (CLAUDE.md, A8) y anticipate va a anim_fps
Los archivos que empiezan por '_' (vistas previas) se ignoran.

Uso: python3 tools/validate_enemy_sprites.py [json ...]
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""
import glob
import json
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN_SIZE, MAX_SIZE = 64, 128
ANTICIPATION_MIN, ANTICIPATION_MAX = 6, 12


def res_to_path(res):
    return os.path.join(ROOT, res.replace("res://", "", 1))


def load_gpl(path, exclude):
    colors = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]) and parts[3] not in exclude:
                colors.add(tuple(int(p) for p in parts[:3]))
    return colors


def check_png(path, size, palette):
    errors = []
    name = os.path.basename(path)
    img = Image.open(path).convert("RGBA")
    if img.size != size:
        return [f"{name}: tamano {img.size} distinto de {size}"]
    px = img.load()
    bad_alpha, bad_colors, opaque = 0, {}, 0
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a not in (0, 255):
                bad_alpha += 1
            elif a == 255:
                opaque += 1
                if (r, g, b) not in palette:
                    bad_colors.setdefault((r, g, b), (x, y))
    if bad_alpha:
        errors.append(f"{name}: {bad_alpha} pixeles semitransparentes")
    for c, (x, y) in list(bad_colors.items())[:10]:
        errors.append(f"{name}: color fuera de la paleta #{''.join('%02x' % v for v in c)} en ({x}, {y})")
    w, h = size
    if any(px[x, y][3] != 0 for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
        errors.append(f"{name}: las esquinas deben ser transparentes")
    if opaque == 0:
        errors.append(f"{name}: cuadro vacio")
    return errors


def check_enemy(json_path):
    with open(json_path, encoding="utf-8") as fh:
        data = json.load(fh)
    spr = data.get("sprites")
    if spr is None:
        return [], 0
    errors = []
    label = os.path.basename(json_path)
    size = tuple(spr["frame_size"])
    if not all(MIN_SIZE <= v <= MAX_SIZE for v in size):
        errors.append(f"{label}: frame_size {size} fuera de {MIN_SIZE}-{MAX_SIZE} px")
    palette = load_gpl(res_to_path(spr["palette"]), set(spr.get("palette_exclude", [])))
    directory = res_to_path(spr["dir"])
    prefix = spr["prefix"]
    expected = set()
    for anim, spec in spr["animations"].items():
        for i in range(spec["frames"]):
            name = f"{prefix}_{anim}_{i:02d}.png"
            expected.add(name)
            path = os.path.join(directory, name)
            if not os.path.exists(path):
                errors.append(f"{label}: falta {name}")
                continue
            errors += check_png(path, size, palette)
    pattern = re.compile(rf"^{re.escape(prefix)}_[a-z0-9_]+_\d{{2}}\.png$")
    for path in glob.glob(os.path.join(directory, f"{prefix}_*.png")):
        name = os.path.basename(path)
        if name not in expected:
            errors.append(f"{label}: sobra {name}" if pattern.match(name) else f"{label}: nombre invalido {name}")
    if "anticipation_frames" in data:
        n = int(data["anticipation_frames"])
        anim = spr["animations"].get("anticipate")
        if not ANTICIPATION_MIN <= n <= ANTICIPATION_MAX:
            errors.append(f"{label}: anticipation_frames {n} fuera de {ANTICIPATION_MIN}-{ANTICIPATION_MAX}")
        if anim is None or anim["frames"] != n:
            errors.append(f"{label}: la animacion anticipate debe tener {n} cuadros")
        elif abs(float(anim["fps"]) - float(data["anim_fps"])) > 1e-6:
            errors.append(f"{label}: anticipate debe ir a anim_fps ({data['anim_fps']})")
    return errors, len(expected)


def main():
    paths = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "data", "enemies", "*.json")))
    errors, total = [], 0
    for p in paths:
        e, n = check_enemy(p)
        errors += e
        total += n
    if errors:
        print("validate_enemy_sprites: FALLOS")
        for e in errors:
            print("  - " + e)
        return 1
    print(f"validate_enemy_sprites: OK ({total} PNG en {len(paths)} enemigo(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
