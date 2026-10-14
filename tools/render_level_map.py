#!/usr/bin/env python3
"""Imagen de revision de un nivel (data/levels/<m>-<n>.json): el grid con la paleta del
mundo, simbolos para objetos, enemigos, checkpoints, secretos y puntos de atencion,
bandas de los tramos (`sections`) con su ancho en tiles y una regla cada 10 tiles.

Cada tile de 64 px se dibuja a 16 px (escala 1/4) para que el nivel entero quepa en una
imagen. Es una herramienta de revision, no un asset del juego.

Uso: python3 tools/render_level_map.py data/levels/1-1.json [salida.png]
Salida por defecto: assets/levels_preview/<id>_mapa.png
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 16
TOP = 64
BOTTOM = 112
SIDE = 16


def load_palette(path):
    colors = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                colors[parts[3]] = tuple(int(p) for p in parts[:3])
    return colors


FONT_CANDIDATES = [  # con tildes; si no hay ninguna, la de Pillow (sin tildes)
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.isfile(path):
            return ImageFont.truetype(path, size)
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def render(level, palette):
    grid = level["grid"]
    rows, cols = len(grid), len(grid[0])
    width = cols * CELL + 2 * SIDE
    height = TOP + rows * CELL + BOTTOM
    img = Image.new("RGB", (width, height), palette["noche_profunda"])
    d = ImageDraw.Draw(img)
    small, normal = font(10), font(12)

    def box(x, y, w=1, h=1):
        x0, y0 = SIDE + x * CELL, TOP + y * CELL
        return (x0, y0, x0 + w * CELL - 1, y0 + h * CELL - 1)

    def solid(x, y):
        return not (0 <= x < cols and 0 <= y < rows) or grid[y][x] == "#"

    # Fondo de la zona de juego.
    d.rectangle((SIDE, TOP, SIDE + cols * CELL - 1, TOP + rows * CELL - 1), fill=palette["cielo"])

    # Tiles de la leyenda base.
    for y, row in enumerate(grid):
        for x, char in enumerate(row):
            x0, y0, x1, y1 = box(x, y)
            if char == "#":
                d.rectangle((x0, y0, x1, y1), fill=palette["tile_base"])
                if not solid(x, y - 1):
                    d.rectangle((x0, y0, x1, y0 + 2), fill=palette["borde_luz"])
            elif char == "-":
                d.rectangle((x0, y0, x1, y0 + 3), fill=palette["borde_luz"])
            elif char == "^":
                d.polygon([(x0, y1), ((x0 + x1) // 2, y0 + 4), (x1, y1)], fill=palette["alerta"])
            elif char == "h":
                d.rectangle((x0, y0, x1, y0 + 3), outline=palette["debug_cian"])
            elif char == "o":
                cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
                d.polygon([(cx, cy - 5), (cx + 5, cy), (cx, cy + 5), (cx - 5, cy)],
                          fill=palette["ambar"], outline=palette["ambar_sombra"])
            elif char == "S":
                d.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), outline=palette["carmin_brillo"])

    def label(x_px, y_px, text, color, fnt=small, anchor="mm"):
        d.text((x_px, y_px), text, fill=color, font=fnt, anchor=anchor)

    # Objetos.
    for obj in level.get("objects", []):
        kind, x, y, p = obj["type"], obj["x"], obj["y"], obj.get("params", {})
        if kind == "bridge_inactive":
            n = p.get("length_tiles", 4)
            step = -1 if p.get("direction", "right") == "left" else 1
            xs = [x + step * i for i in range(n)]
            x0, y0, _, _ = box(min(xs), y)
            x1 = x0 + n * CELL - 1
            for xx in range(x0, x1, 6):
                d.line((xx, y0 + 1, min(xx + 3, x1), y0 + 1), fill=palette["borde_luz"], width=3)
            label((x0 + x1) // 2, y0 + 9, "puente (%d)" % n, palette["borde_luz"])
        elif kind == "receiver":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 4, y0 + 2, x1 - 4, y1), fill=palette["banner_gris"])
            d.rectangle((x0 + 6, y0 + 4, x1 - 6, y0 + 7), fill=palette["alerta"])
            label((x0 + x1) // 2, y0 - 7, "R", palette["banner_blanco"])
        elif kind == "glitch_wall":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), p.get("height_tiles", 2))
            d.rectangle((x0, y0, x1, y1), fill=palette["tile_base"])
            for yy in range(y0 + 2, y1, 4):
                d.line((x0 + (yy % 3), yy, x1 - 2 + (yy % 2), yy), fill=palette["carmin_brillo"])
        elif kind == "popup_blocker":
            w, h = p.get("width_tiles", 3), p.get("height_tiles", 4)
            x0, y0, x1, y1 = box(x, y, w, h)
            d.rectangle((x0, y0, x1, y1), fill=palette["banner_blanco"], outline=palette["banner_gris"], width=2)
            d.rectangle((x0, y0, x1, y0 + 5), fill=palette["banner_gris"])
            bx, by = p.get("close_button_px", [0, 0])
            bs = max(2, p.get("close_button_size_px", 16) // 4)
            cx, cy = x0 + bx // 4, y0 + by // 4
            d.rectangle((cx, cy, cx + bs, cy + bs), fill=palette["alerta"])
            label((x0 + x1) // 2, (y0 + y1) // 2, "pop-up", palette["noche_profunda"])
        elif kind == "exit_door":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), p.get("height_tiles", 2))
            d.rectangle((x0 + 1, y0, x1 - 1, y1), fill=palette["banner_blanco"], outline=palette["borde_luz"])
            d.rectangle((x1 - 5, (y0 + y1) // 2, x1 - 3, (y0 + y1) // 2 + 2), fill=palette["alerta"])
            label((x0 + x1) // 2, y0 - 8, p.get("text", "puerta"), palette["banner_blanco"])
        elif kind == "eco_line":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), p.get("height_tiles", 4))
            for xx in range(x0, x1, 6):
                d.line((xx, y0, min(xx + 2, x1), y0), fill=palette["resplandor"])
                d.line((xx, y1, min(xx + 2, x1), y1), fill=palette["resplandor"])
            for yy in range(y0, y1, 6):
                d.line((x0, yy, x0, min(yy + 2, y1)), fill=palette["resplandor"])
                d.line((x1, yy, x1, min(yy + 2, y1)), fill=palette["resplandor"])
            label((x0 + x1) // 2, y0 + 8, "Eco", palette["banner_blanco"])
            label(x0 + 2, TOP + 10, 'Eco: "%s"' % p.get("text", ""), palette["banner_gris"], anchor="lm")

    # Enemigos con su rango de patrulla.
    tile = level["tile_size"]
    for enemy in level.get("enemies", []):
        x0, y0, x1, y1 = box(enemy["x"], enemy["y"])
        cx = (x0 + x1) // 2
        half = enemy.get("params", {}).get("patrol_range_px", 256.0) / 2.0 / tile * CELL
        d.line((cx - half, y1 + 1, cx + half, y1 + 1), fill=palette["alerta_sombra"], width=2)
        d.line((cx - half, y1 - 3, cx - half, y1 + 1), fill=palette["alerta_sombra"], width=2)
        d.line((cx + half, y1 - 3, cx + half, y1 + 1), fill=palette["alerta_sombra"], width=2)
        d.ellipse((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill=palette["alerta"], outline=palette["alerta_sombra"])
        label(cx, y0 - 8, "Burbuja" if enemy["type"] == "alert_bubble" else enemy["type"], palette["alerta"])

    # Inicio, checkpoints y meta.
    for y, row in enumerate(grid):
        for x, char in enumerate(row):
            x0, y0, x1, y1 = box(x, y)
            if char == "P":
                d.rectangle((x0 + 4, y0, x1 - 4, y1), fill=palette["banner_blanco"])
                label((x0 + x1) // 2, y0 - 8, "P (cae)", palette["banner_blanco"])
                d.line(((x0 + x1) // 2, y1 + 2, (x0 + x1) // 2, y1 + 18), fill=palette["banner_gris"])
            elif char == "C":
                d.line((x0 + 3, y0 - 8, x0 + 3, y1), fill=palette["banner_blanco"], width=2)
                d.polygon([(x0 + 4, y0 - 8), (x1, y0 - 4), (x0 + 4, y0)], fill=palette["debug_cian"])
                label((x0 + x1) // 2, y0 - 16, "C", palette["debug_cian"], normal)
            elif char == "G":
                label((x0 + x1) // 2, y1 + 0, "G", palette["noche_profunda"])

    # Secretos que son objetos.
    for secret in level.get("secrets", []):
        x0, y0, x1, y1 = box(secret["x"], secret["y"])
        label(x0 - 2, y0 - 8, "secreto", palette["carmin_brillo"], anchor="rm")

    # Bandas de tramos (arriba) con su ancho en tiles.
    band_colors = [palette["fondo_medio"], palette["tile_luz"]]
    for i, sec in enumerate(level.get("sections", [])):
        x0 = SIDE + sec["x_from"] * CELL
        x1 = SIDE + (sec["x_to"] + 1) * CELL - 1
        d.rectangle((x0, 8, x1, TOP - 14), fill=band_colors[i % 2])
        n = sec["x_to"] - sec["x_from"] + 1
        label((x0 + x1) // 2, 18, sec["name"], palette["banner_blanco"], normal)
        label((x0 + x1) // 2, 34, "%d tiles  (x %d-%d)" % (n, sec["x_from"], sec["x_to"]), palette["borde_luz"])
        for xx in (x0, x1):
            for yy in range(TOP - 14, TOP + rows * CELL, 6):
                d.line((xx, yy, xx, yy + 2), fill=palette["banner_gris"])

    # Regla cada 10 tiles y distancias.
    ry = TOP + rows * CELL + 6
    for x in range(0, cols + 1):
        px = SIDE + x * CELL
        if x % 10 == 0:
            d.line((px, ry, px, ry + 8), fill=palette["banner_gris"])
            label(px, ry + 16, str(x), palette["banner_gris"])
        elif x % 5 == 0:
            d.line((px, ry, px, ry + 4), fill=palette["tile_luz"])
    walk = 220.0
    px_total = cols * tile
    summary = ("%s %s  |  %dx%d tiles (%d x %d px)  |  1 tile = 64 px dibujado a %d px  |  "
               "recorrido sin paradas: %.0f s caminando a %.0f px/s"
               % (level["id"], level["name"], cols, rows, px_total, rows * tile, CELL,
                  px_total / walk, walk))
    label(SIDE, ry + 36, summary, palette["banner_blanco"], normal, anchor="lm")

    # Leyenda.
    ly = ry + 64
    items = [("#", "solido", palette["tile_base"]), ("-", "una via", palette["borde_luz"]),
             ("o", "punto de atencion", palette["ambar"]), ("E", "Burbuja + patrulla", palette["alerta"]),
             ("C", "punto de sincronizacion", palette["debug_cian"]), ("R", "receptor", palette["banner_gris"]),
             ("~", "puente retraido", palette["borde_luz"]), ("W", "pared con glitch (secreto)", palette["carmin_brillo"]),
             ("X", "pop-up (rojo = boton)", palette["banner_blanco"]), ("D", "puerta / meta G", palette["banner_blanco"]),
             ("e", "zona de Eco", palette["resplandor"])]
    lx = SIDE
    for _, text, color in items:
        d.rectangle((lx, ly - 5, lx + 10, ly + 5), fill=color)
        d.text((lx + 16, ly), text, fill=palette["banner_gris"], font=small, anchor="lm")
        lx += 24 + int(d.textlength(text, font=small)) + 14
    return img


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        level = json.load(handle)
    palette = load_palette(os.path.join(ROOT, "assets", "palettes", "mundo%d.gpl" % level["world"]))
    out = argv[2] if len(argv) > 2 else os.path.join(ROOT, "assets", "levels_preview", "%s_mapa.png" % level["id"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    render(level, palette).save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
