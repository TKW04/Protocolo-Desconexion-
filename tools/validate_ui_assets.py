#!/usr/bin/env python3
"""Valida el arte de la interfaz (HUD, fuente de textos y cuadro de Eco).

Generadores: tools/gen_hud_assets.py, tools/gen_hud_font.py, tools/gen_text_font.py y
tools/gen_eco_text_box.py. Lee la seccion "assets" de cada archivo de datos de la interfaz
(data/hud.json, data/text_font.json y data/eco_text_box.json si existen) y comprueba en cada PNG:
  - nombre <hud|text|eco>_<nombre>.png (minusculas, digitos y '_') dentro de assets/sprites/ui/
  - tamano = frame_size x (columns, rows), con cuadros y lienzo multiplos de 8
  - solo colores de assets/palettes/mundo1.gpl (16 colores + debug_cian)
  - alfa 0 o 255 (sin semitransparencias)
  - ningun cuadro vacio (salvo los huecos del atlas de la fuente)
Ademas:
  - bateria del HUD (data/hud.json): la fila 1 del marco (vacia) y la fila 0 de los segmentos
    (vacios) no tienen el color clave del Debug (colors.debug_key); la fila 0 del marco si (rayo)
  - todo PNG de assets/sprites/ui/ esta en alguna lista o es una vista (empieza por '_')
  - cada fuente (clave "font" de un archivo con font_glyphs, BMFont de texto) apunta al atlas
    de su lista, tiene todos los glifos de font_glyphs, sus glifos caben en el atlas y su
    tamano es font_size

Uso: python3 tools/validate_ui_assets.py [--data data/hud.json data/text_font.json ...]
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""
import argparse
import json
import os
import re
import site
import sys

# Con -I no se carga el site de usuario (donde puede estar Pillow): se anade a mano.
sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo1.gpl")
UI_DIR = os.path.join(ROOT, "assets", "sprites", "ui")
NAME_RE = re.compile(r"^(hud|text|eco)_[a-z0-9]+(_[a-z0-9]+)*\.png$")
DATA_FILES = [os.path.join(ROOT, "data", n) for n in ("hud.json", "text_font.json", "eco_text_box.json")]
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
        errors.append(f"{key}: nombre '{name}' no sigue <hud|text|eco>_<nombre>.png")
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


def check_battery(data):
    """La bateria vacia no tiene ningun pixel del color del Debug (se ve vacia del todo)."""
    errors = []
    assets = data.get("assets", {})
    key = data.get("colors", {}).get("debug_key")
    if key is None or "battery_shell" not in assets or "battery_segments" not in assets:
        return errors
    key = tuple(int(key.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))

    def has_key(entry, row):
        path = res_to_path(entry["path"])
        if not os.path.exists(path):
            return False
        img = Image.open(path).convert("RGBA")
        fh = entry["frame_size"][1]
        px = img.load()
        return any(px[x, y][3] == 255 and px[x, y][:3] == key
                   for y in range(row * fh, min((row + 1) * fh, img.height)) for x in range(img.width))

    shell, segs = assets["battery_shell"], assets["battery_segments"]
    if shell["rows"] != 2:
        return ["battery_shell: debe tener 2 filas (0 con energia, 1 vacia)"]
    if not has_key(shell, 0):
        errors.append("battery_shell: la fila 0 (con energia) no tiene el rayo en el color del Debug")
    if has_key(shell, 1):
        errors.append("battery_shell: la fila 1 (vacia) tiene el color del Debug")
    if has_key(segs, 0):
        errors.append("battery_segments: la fila 0 (vacio) tiene el color del Debug")
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
    parser.add_argument("--data", nargs="+", default=[p for p in DATA_FILES if os.path.exists(p)])
    args = parser.parse_args()
    palette = load_gpl(GPL)
    errors, listed, count = [], set(), 0
    for data_path in args.data:
        with open(data_path, encoding="utf-8") as fh:
            data = json.load(fh)
        assets = data.get("assets", {})
        count += len(assets)
        for key, entry in assets.items():
            errors += check_asset(key, entry, palette)
        listed |= {os.path.basename(res_to_path(e["path"])) for e in assets.values()}
        if "font_glyphs" in data:
            errors += check_font(data, assets)
        errors += check_battery(data)
    for name in sorted(os.listdir(UI_DIR)):
        if name.endswith(".png") and not name.startswith("_") and name not in listed:
            errors.append(f"{name}: PNG de la interfaz que no esta en ningun data/*.json (o es una vista sin '_')")
    for e in errors:
        print("ERROR:", e)
    print(f"validate_ui_assets: {count} assets, {len(errors)} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
