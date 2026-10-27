#!/usr/bin/env python3
"""Valida el atlas del tileset del Mundo 1 (tools/gen_tileset_mundo1.py).

Comprueba:
  - tamano del PNG multiplo de tile_size (64) y que cada tile del mapa cabe en el atlas
  - solo colores de la paleta (assets/palettes/mundo1.gpl) en los pixeles opacos
  - alfa 0 o 255 (sin semitransparencias)
  - sin costuras al repetirse: si un tile tiene repeat_x, el par (ultima columna, primera
    columna) que aparece al ponerlo junto a si mismo ya existe como par de columnas vecinas
    dentro del tile (no crea una transicion nueva: vale para bordes lisos y para patrones
    periodicos como la rejilla); igual con las filas si tiene repeat_y
  - bloques solidos vecinos encajan: para cada par de mascaras cardinales que pueden ir
    juntas (A con vecino solido al este y B con vecino solido al oeste, con los mismos
    vecinos arriba y abajo; y lo mismo en vertical) el borde comun es identico
  - los tiles solidos son opacos (salvo las esquinas redondeadas exteriores) y los de
    una via y pinchos tienen fondo transparente (alguna fila superior/inferior libre)

Uso: python3 tools/validate_tileset.py [--map data/tileset_mundo1.json]
Devuelve 0 si todo es correcto y 1 si hay algun fallo.
"""
import argparse
import json
import os
import site
import sys

sys.path.append(site.getusersitepackages())  # Pillow en el site de usuario (tambien con python3 -I)
from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N, E, S, W = 1, 2, 4, 8


def res_to_path(res):
    return res if os.path.isabs(res) else os.path.join(ROOT, res.replace("res://", "", 1))


def load_gpl(path):
    colors = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            parts = s.split()
            if len(parts) >= 3 and all(p.isdigit() for p in parts[:3]):
                colors.add(tuple(int(p) for p in parts[:3]))
    return colors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", default=os.path.join(ROOT, "data", "tileset_mundo1.json"))
    args = ap.parse_args()
    with open(args.map, encoding="utf-8") as fh:
        m = json.load(fh)
    T = m["tile_size"]
    errors = []
    img = Image.open(res_to_path(m["atlas_png"])).convert("RGBA")
    palette = load_gpl(res_to_path(m["palette"]))
    w, h = img.size
    if w % T or h % T:
        errors.append(f"tamano {w}x{h} no es multiplo de {T}")
    if (w // T, h // T) != (m["columns"], m["rows"]):
        errors.append(f"rejilla {w // T}x{h // T} distinta de la del mapa {m['columns']}x{m['rows']}")
    px = img.load()
    bad_colors, bad_alpha = {}, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a not in (0, 255):
                bad_alpha += 1
            elif a == 255 and (r, g, b) not in palette:
                bad_colors.setdefault((r, g, b), (x, y))
    if bad_alpha:
        errors.append(f"{bad_alpha} pixeles semitransparentes")
    for c, (x, y) in list(bad_colors.items())[:10]:
        errors.append(f"color fuera de la paleta #{''.join('%02x' % v for v in c)} en ({x}, {y})")

    def tile_img(entry):
        cx, cy = entry["atlas"]
        return img.crop((cx * T, cy * T, cx * T + T, cy * T + T))

    def col(t, x):
        return [t.getpixel((x, y)) for y in range(T)]

    def row(t, y):
        return [t.getpixel((x, y)) for x in range(T)]

    seen = set()
    for e in m["tiles"]:
        cx, cy = e["atlas"]
        name = e["name"]
        if not (0 <= cx < m["columns"] and 0 <= cy < m["rows"]):
            errors.append(f"{name}: coordenadas {e['atlas']} fuera del atlas")
            continue
        if (cx, cy) in seen:
            errors.append(f"{name}: coordenadas {e['atlas']} repetidas")
        seen.add((cx, cy))
        t = tile_img(e)
        if e["repeat_x"]:
            cols = [tuple(col(t, x)) for x in range(T)]
            if (cols[-1], cols[0]) not in set(zip(cols, cols[1:])):
                errors.append(f"{name}: costura al repetirse en horizontal")
        if e["repeat_y"]:
            rows = [tuple(row(t, y)) for y in range(T)]
            if (rows[-1], rows[0]) not in set(zip(rows, rows[1:])):
                errors.append(f"{name}: costura al repetirse en vertical")
        alpha = t.getchannel("A")
        if e["kind"] == "solid":
            clear = sum(1 for v in alpha.getdata() if v == 0)
            if clear > 4 * 4:  # como mucho 4 esquinas de 2x2 px
                errors.append(f"{name}: solido con {clear} pixeles transparentes")
        elif e["kind"] in ("one_way", "hazard"):
            if alpha.getextrema() != (0, 255):
                errors.append(f"{name}: deberia tener fondo transparente y algo opaco")
        elif e["kind"] != "decor":
            errors.append(f"{name}: kind desconocido '{e['kind']}'")

    # encaje entre bloques solidos vecinos (sin esquinas interiores)
    by_mask = {int(k): v for k, v in m["solid"]["by_mask"].items()}
    tiles_by_mask = {k: img.crop((v[0] * T, v[1] * T, v[0] * T + T, v[1] * T + T)) for k, v in by_mask.items()}
    for a, ta in tiles_by_mask.items():
        for b, tb in tiles_by_mask.items():
            if a & E and b & W and (a & (N | S)) == (b & (N | S)) and col(ta, T - 1) != col(tb, 0):
                errors.append(f"solidos {a} -> {b}: el borde este/oeste no encaja")
            if a & S and b & N and (a & (E | W)) == (b & (E | W)) and row(ta, T - 1) != row(tb, 0):
                errors.append(f"solidos {a} sobre {b}: el borde sur/norte no encaja")
    for k in range(16):
        if k not in by_mask:
            errors.append(f"falta el solido de mascara {k}")

    if errors:
        print("validate_tileset: FALLOS")
        for e in errors:
            print("  - " + e)
        return 1
    print(f"validate_tileset: OK ({len(m['tiles'])} tiles, atlas {w}x{h}, {len(palette)} colores de paleta)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
