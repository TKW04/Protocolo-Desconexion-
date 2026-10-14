#!/usr/bin/env python3
"""Valida los assets de los objetos y del fondo del Mundo 1 (tools/gen_world1_objects.py).

Lee la lista "assets" de data/world1_objects.json y comprueba en cada PNG:
  - tamano = frame_size x (columns, rows)
  - solo colores de la paleta (assets/palettes/mundo1.gpl, sin los nombres de
    palette_exclude: el debug_cian es del Debug, no de los objetos del mundo)
  - alfa 0 o 255 (sin semitransparencias)
  - needs_transparency: cada cuadro tiene pixeles transparentes y opacos;
    si es falso, cada cuadro es opaco salvo como mucho 16 px (esquinas redondeadas)
  - seamless_x: sin costura al repetirse en horizontal (mismo criterio que
    tools/validate_tileset.py: el par ultima columna -> primera columna ya existe
    como par de columnas vecinas dentro del cuadro)

Uso: python3 tools/validate_world1_assets.py [--data data/world1_objects.json]
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""
import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def res_to_path(res):
    return res if os.path.isabs(res) else os.path.join(ROOT, res.replace("res://", "", 1))


def load_gpl(path, exclude):
    colors = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            parts = s.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]) and parts[3] not in exclude:
                colors.add(tuple(int(p) for p in parts[:3]))
    return colors


def check_asset(entry, palette):
    errors = []
    path = res_to_path(entry["path"])
    name = os.path.basename(path)
    if not os.path.exists(path):
        return [f"{name}: no existe"]
    img = Image.open(path).convert("RGBA")
    fw, fh = entry["frame_size"]
    cols, rows = entry["columns"], entry["rows"]
    if img.size != (fw * cols, fh * rows):
        errors.append(f"{name}: tamano {img.size} distinto de {(fw * cols, fh * rows)}")
        return errors
    px = img.load()
    bad_alpha, bad_colors = 0, {}
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a not in (0, 255):
                bad_alpha += 1
            elif a == 255 and (r, g, b) not in palette:
                bad_colors.setdefault((r, g, b), (x, y))
    if bad_alpha:
        errors.append(f"{name}: {bad_alpha} pixeles semitransparentes")
    for c, (x, y) in list(bad_colors.items())[:10]:
        errors.append(f"{name}: color fuera de la paleta #{''.join('%02x' % v for v in c)} en ({x}, {y})")
    for row in range(rows):
        for col in range(cols):
            frame = img.crop((col * fw, row * fh, col * fw + fw, row * fh + fh))
            where = f"{name} cuadro ({col}, {row})"
            clear = sum(1 for v in frame.getchannel("A").getdata() if v == 0)
            if entry["needs_transparency"]:
                if clear == 0 or clear == fw * fh:
                    errors.append(f"{where}: deberia tener fondo transparente y algo opaco")
            elif clear > 16:
                errors.append(f"{where}: deberia ser opaco ({clear} pixeles transparentes)")
            if entry["seamless_x"]:
                fpx = frame.load()
                columns = [tuple(fpx[x, y] for y in range(fh)) for x in range(fw)]
                if (columns[-1], columns[0]) not in set(zip(columns, columns[1:])):
                    errors.append(f"{where}: costura al repetirse en horizontal")
    return errors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(ROOT, "data", "world1_objects.json"))
    args = ap.parse_args()
    with open(args.data, encoding="utf-8") as fh:
        data = json.load(fh)
    palette = load_gpl(res_to_path(data["palette"]), set(data.get("palette_exclude", [])))
    errors = []
    for entry in data["assets"]:
        errors += check_asset(entry, palette)
    if errors:
        print("validate_world1_assets: FALLOS")
        for e in errors:
            print("  - " + e)
        return 1
    print(f"validate_world1_assets: OK ({len(data['assets'])} PNG, {len(palette)} colores de paleta)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
