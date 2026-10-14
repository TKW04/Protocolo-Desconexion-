#!/usr/bin/env python3
"""Valida el arte del HUD (tools/gen_hud_assets.py y tools/gen_hud_font.py).

Lee la seccion "assets" de data/hud.json y comprueba en cada PNG:
  - nombre hud_<nombre>.png (minusculas, digitos y '_') dentro de assets/sprites/ui/
  - tamano = frame_size x (columns, rows), con cuadros y lienzo multiplos de 8
  - solo colores de assets/palettes/mundo1.gpl (16 colores + debug_cian)
  - alfa 0 o 255 (sin semitransparencias)
  - ningun cuadro vacio (salvo los huecos del atlas de la fuente)
Ademas:
  - todo PNG de assets/sprites/ui/ esta en la lista o es una vista (empieza por '_')
  - la fuente (data/hud.json -> font, BMFont de texto) apunta al atlas de la lista, tiene
    todos los glifos de font_glyphs, sus glifos caben en el atlas y su tamano es font_size

Uso: python3 tools/validate_ui_assets.py [--data data/hud.json]
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""
import argparse
import json
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo1.gpl")
UI_DIR = os.path.join(ROOT, "assets", "sprites", "ui")
NAME_RE = re.compile(r"^hud_[a-z0-9]+(_[a-z0-9]+)*\.png$")
GRID = 8
# Assets cuyo atlas puede tener celdas vacias (la fuente no llena todas las celdas).
SPARSE = ("font",)


def res_to_path(res):
    return os.path.join(ROOT, res.replace("res://", "", 1))


def load_gpl(path):
    colors = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            parts = s.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                colors.add(tuple(int(p) for p in parts[:3]))
    return colors


def check_asset(key, entry, palette):
    errors = []
    path = res_to_path(entry["path"])
    name = os.path.basename(path)
    if os.path.dirname(os.path.abspath(path)) != UI_DIR:
        errors.append(f"{key}: {entry['path']} no esta en assets/sprites/ui/")
    if not NAME_RE.match(name):
        errors.append(f"{key}: nombre '{name}' no sigue hud_<nombre>.png")
    if not os.path.exists(path):
        return errors + [f"{name}: no existe"]
    img = Image.open(path).convert("RGBA")
    fw, fh = entry["frame_size"]
    cols, rows = entry["columns"], entry["rows"]
    if fw % GRID or fh % GRID:
        errors.append(f"{name}: cuadro {fw}x{fh} no es multiplo de {GRID}")
    if img.size != (fw * cols, fh * rows):
        return errors + [f"{name}: tamano {img.size} distinto de {(fw * cols, fh * rows)}"]
    if img.width % GRID or img.height % GRID:
        errors.append(f"{name}: tamano {img.size} no es multiplo de {GRID}")
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
    if key not in SPARSE:
        alpha = img.getchannel("A")
        for row in range(rows):
            for col in range(cols):
                box = (col * fw, row * fh, col * fw + fw, row * fh + fh)
                if alpha.crop(box).getbbox() is None:
                    errors.append(f"{name}: cuadro ({col}, {row}) vacio")
    return errors


def parse_fnt(path):
    info, chars, page = {}, {}, None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if not parts:
                continue
            attrs = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', line))
            attrs = {k: v.strip('"') for k, v in attrs.items()}
            if parts[0] in ("info", "common"):
                info.update(attrs)
            elif parts[0] == "page":
                page = attrs["file"]
            elif parts[0] == "char":
                chars[int(attrs["id"])] = {k: int(v) for k, v in attrs.items()}
    return info, chars, page


def check_font(data, assets):
    errors = []
    fnt = res_to_path(data.get("font", ""))
    if not os.path.exists(fnt):
        return [f"fuente: no existe {data.get('font')}"]
    info, chars, page = parse_fnt(fnt)
    atlas = assets.get("font", {}).get("path", "")
    if page is None or os.path.join(os.path.dirname(fnt), page) != res_to_path(atlas):
        errors.append(f"fuente: la pagina '{page}' no es el atlas {atlas}")
    if int(info.get("size", -1)) != data["font_size"]:
        errors.append(f"fuente: size {info.get('size')} distinto de font_size {data['font_size']}")
    for ch in data["font_glyphs"]:
        if ord(ch) not in chars:
            errors.append(f"fuente: falta el glifo '{ch}'")
    sw, sh = int(info.get("scaleW", 0)), int(info.get("scaleH", 0))
    for cid, c in chars.items():
        if c["x"] + c["width"] > sw or c["y"] + c["height"] > sh:
            errors.append(f"fuente: el glifo {chr(cid)!r} se sale del atlas")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", default=os.path.join(ROOT, "data", "hud.json"))
    args = parser.parse_args()
    with open(args.data, encoding="utf-8") as fh:
        data = json.load(fh)
    assets = data["assets"]
    palette = load_gpl(GPL)
    errors = []
    for key, entry in assets.items():
        errors += check_asset(key, entry, palette)
    listed = {os.path.basename(res_to_path(e["path"])) for e in assets.values()}
    for name in sorted(os.listdir(UI_DIR)):
        if name.endswith(".png") and not name.startswith("_") and name not in listed:
            errors.append(f"{name}: PNG del HUD que no esta en data/hud.json (o es una vista sin '_')")
    errors += check_font(data, assets)
    for e in errors:
        print("ERROR:", e)
    print(f"validate_ui_assets: {len(assets)} assets, {len(errors)} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
