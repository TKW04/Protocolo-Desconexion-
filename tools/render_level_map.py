#!/usr/bin/env python3
"""Imagen de revision de un nivel (data/levels/<m>-<n>.json): el grid con la paleta del
mundo, simbolos para objetos, enemigos, checkpoints, secretos y puntos de atencion,
techos colgados (cara de abajo resaltada y alto del hueco hasta el suelo),
bandas de los tramos (`sections`) con su ancho en tiles y una regla cada 10 tiles.
En un nivel vertical (tramos con y_from/y_to, p. ej. la torre del 1-2; 2026-10-16) los
tramos se dibujan como bandas a la derecha con sus filas, hay una regla vertical cada 10
filas a la izquierda y la leyenda se parte en varias lineas.

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
# Nivel vertical: margen izquierdo (regla de filas) y derecho (bandas de los tramos).
VERTICAL_LEFT = 40
VERTICAL_RIGHT = 260
MIN_WIDTH = 900


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


def is_vertical(level):
    return any("y_from" in sec or "y_to" in sec for sec in level.get("sections", []))


def bubble_tiles(text):
    """Largo en tiles de una burbuja del Mundo 4: la regla de bubble_width de tools/build_level.py
    (1 tile cada 6 caracteres, entre 1 y 8; valores por defecto de la seccion chat_bubble)."""
    return max(1, min(8, -(-len(text) // 6)))


def render(level, palette):
    grid = level["grid"]
    rows, cols = len(grid), len(grid[0])
    vertical = is_vertical(level)
    left = VERTICAL_LEFT if vertical else SIDE
    right = VERTICAL_RIGHT if vertical else SIDE
    width = cols * CELL + left + right
    # Ancho minimo tambien en horizontal (2026-10-22): la arena del jefe (24 tiles) cortaba
    # el resumen y la leyenda. Los mapas de 1-1, 1-2 y 1-3 ya son mas anchos.
    width = max(width, MIN_WIDTH)
    height = TOP + rows * CELL + BOTTOM + (48 if vertical else 0)
    # Holgura para leyendas de varias lineas; se recorta al final (2026-10-22).
    img = Image.new("RGB", (width, height + 80), palette["noche_profunda"])
    d = ImageDraw.Draw(img)
    small, normal = font(10), font(12)

    def box(x, y, w=1, h=1):
        x0, y0 = left + x * CELL, TOP + y * CELL
        return (x0, y0, x0 + w * CELL - 1, y0 + h * CELL - 1)

    def solid(x, y):
        return not (0 <= x < cols and 0 <= y < rows) or grid[y][x] == "#"

    # Fondo de la zona de juego.
    d.rectangle((left, TOP, left + cols * CELL - 1, TOP + rows * CELL - 1), fill=palette["cielo"])

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

    # Techos colgados (p. ej. el techo bajo del Tramo 3): cara de abajo en borde_luz, el
    # hueco libre hasta el suelo con una linea discontinua y el alto del hueco en tiles.
    def clearance(x, y):
        """Celdas libres bajo la celda solida (x, y) hasta el siguiente solido, o None."""
        if not solid(x, y) or solid(x, y + 1):
            return None
        free = 0
        while y + 1 + free < rows and not solid(x, y + 1 + free):
            free += 1
        return free if y + 1 + free < rows else None

    for y in range(rows):
        x = 0
        while x < cols:
            gap = clearance(x, y)
            if gap is None or gap > 4 or all(solid(x, yy) for yy in range(0, y + 1)):
                x += 1
                continue
            end = x
            while end + 1 < cols and clearance(end + 1, y) == gap:
                end += 1
            x0, y0, _, y1 = box(x, y)
            x1 = box(end, y)[2]
            d.rectangle((x0, y1 - 2, x1, y1), fill=palette["borde_luz"])
            for xx in (x0 + 3, x1 - 3):
                for yy in range(y1 + 3, y1 + gap * CELL - 1, 5):
                    d.line((xx, yy, xx, yy + 2), fill=palette["borde_luz"])
            if end - x >= 3:
                label((x0 + x1) // 2, (y0 + y1) // 2, "techo: hueco %d tiles" % gap,
                      palette["banner_blanco"])
            x = end + 1

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
        elif kind == "exit_terminal":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), p.get("height_tiles", 2))
            mx = (x0 + x1) // 2
            d.rectangle((x0 + 1, y0 + (y1 - y0) // 4, x1 - 1, (y0 + y1) // 2 + 2), fill=palette["tile_sombra"],
                        outline=palette["debug_cian"])
            d.line((mx, (y0 + y1) // 2 + 2, mx, y1), fill=palette["tile_luz"])
            d.line((x0 + 3, y1, x1 - 3, y1), fill=palette["tile_luz"])
            label(mx, y0 - 8, p.get("text", "terminal"), palette["banner_blanco"])
        # Acertijo de Calc (tanda H2 del paso 14 del 1-2, 2026-10-17).
        elif kind == "dark_room":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 4), p.get("height_tiles", 4))
            for xx in range(x0, x1, 8):
                d.line((xx, y0, min(xx + 3, x1), y0), fill=palette["banner_gris"])
                d.line((xx, y1, min(xx + 3, x1), y1), fill=palette["banner_gris"])
            for yy in range(y0, y1, 8):
                d.line((x0, yy, x0, min(yy + 3, y1)), fill=palette["banner_gris"])
                d.line((x1, yy, x1, min(yy + 3, y1)), fill=palette["banner_gris"])
            label(x1 - 4, y0 + 8, "cuarto a oscuras", palette["banner_gris"], anchor="rm")
        elif kind in ("power_switch", "debug_switch"):
            x0, y0, x1, y1 = box(x, y)
            color = palette["debug_cian"] if kind == "debug_switch" else palette["banner_blanco"]
            d.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 5), outline=color, width=2)
            n = int(p.get("pulses", 3 if kind == "power_switch" else 1))
            for i in range(n):
                cx = (x0 + x1) // 2 + (i - (n - 1) / 2.0) * 4
                d.rectangle((cx - 1, y0 - 3, cx + 1, y0 - 1), fill=palette["ambar"])
            label((x0 + x1) // 2, y1 + 6, ("oculto" if kind == "debug_switch" else "pulso x%d" % n), color)
        elif kind == "laser_switch":
            x0, y0, x1, y1 = box(x, y)
            cx, cy = (x0 + 3 * x1) // 4, (y0 + y1) // 2
            d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), outline=palette["debug_cian"], width=2)
            d.ellipse((cx - 1, cy - 1, cx + 1, cy + 1), fill=palette["debug_cian"])
            label((x0 + x1) // 2, y0 - 7, "laser", palette["debug_cian"])
        elif kind == "charge_dock":
            x0, y0, x1, y1 = box(x, y, 2, 1)
            d.rectangle((x0 + 2, y1 - 5, x1 - 2, y1), fill=palette["tile_luz"], outline=palette["debug_cian"])
            label((x0 + x1) // 2, y0 + 6, "carga", palette["debug_cian"])
        elif kind == "calc_actor":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 4, y0 + 2, x1 - 4, y1), fill=palette["banner_gris"], outline=palette["banner_blanco"])
            label((x0 + x1) // 2, y1 + 6, "Calc 3 %", palette["banner_blanco"])
        elif kind == "charger":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 5, y0 + 1, x1 - 5, y1), fill=palette["tile_luz"], outline=palette["debug_cian"])
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
        # Piezas del 1-3 y de la arena del jefe (2026-10-22, paso 12 de propuesta-1-3.md).
        elif kind in ("rhythm_zone", "alarm_tunnel"):
            zx, zy, zw, zh = p.get("zone", [x, y, 1, 1])
            x0, y0, x1, y1 = box(zx, zy, zw, zh)
            for xx in range(x0, x1, 10):
                d.line((xx, y0, min(xx + 4, x1), y0), fill=palette["resplandor"])
                d.line((xx, y1, min(xx + 4, x1), y1), fill=palette["resplandor"])
            for yy in range(y0, y1, 10):
                d.line((x0, yy, x0, min(yy + 4, y1)), fill=palette["resplandor"])
                d.line((x1, yy, x1, min(yy + 4, y1)), fill=palette["resplandor"])
            ix0, iy0, ix1, iy1 = box(x, y)
            d.rectangle((ix0 + 5, iy0 + 2, ix1 - 5, iy1 - 2), outline=palette["borde_luz"])
            if kind == "alarm_tunnel":
                for stage in p.get("stages", []):
                    sx0 = box(stage["x_from"], zy)[0]
                    sx1 = box(stage["x_to"], zy)[2]
                    d.line((sx0 + 1, y0 + 2, sx1 - 1, y0 + 2), fill=palette["resplandor"], width=2)
                    label((sx0 + sx1) // 2, y0 - 7, "compas %.1f s" % stage["cycle_s"], palette["resplandor"])
            else:
                steps = "/".join("%.1f" % s for s in p.get("tempo_steps_s", []))
                label(ix1 + 3, (iy0 + iy1) // 2, "metronomo %s s" % steps, palette["resplandor"], anchor="lm")
        elif kind == "blink_platform":
            w = p.get("width_tiles", 1)
            x0, y0, x1, _ = box(x, y, w, 1)
            for xx in range(x0, x1, 5):
                d.line((xx, y0, min(xx + 2, x1), y0), fill=palette["resplandor"], width=4)
            label((x0 + x1) // 2, y0 + 9, p.get("group", "?"), palette["resplandor"])
        elif kind == "dnd_switch":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 5), outline=palette["banner_blanco"], width=2)
            d.ellipse((x0 + 5, y0 + 5, x1 - 6, y1 - 8), fill=palette["borde_luz"])
            d.ellipse((x0 + 8, y0 + 4, x1 - 3, y1 - 9), fill=palette["tile_sombra"])
            label((x0 + x1) // 2, y0 - 7, "No molestar (dash)", palette["banner_blanco"])
        elif kind == "exceptions_panel":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 3), p.get("height_tiles", 2))
            d.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), outline=palette["banner_gris"])
            label((x0 + x1) // 2, (y0 + y1) // 2, "Excepciones", palette["banner_gris"])
        elif kind == "memory_pickup":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 3, y0 + 5, x1 - 3, y1 - 4), fill=palette["banner_blanco"])
            d.line((x0 + 3, y0 + 5, (x0 + x1) // 2, y0 + 9, x1 - 3, y0 + 5), fill=palette["banner_gris"])
        elif kind == "power_bank_pickup":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 5, y0 + 3, x1 - 5, y1 - 2), outline=palette["debug_cian"])
            d.rectangle((x0 + 7, y0 + 1, x1 - 7, y0 + 3), fill=palette["debug_cian"])
        # Mundo 2 (paso 11 de docs/propuesta-mundo-2.md, el 2-1 real; 2026-10-22).
        elif kind == "fragile_card":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 2), 1)
            for xx in range(x0, x1, 6):
                d.line((xx, y0, min(xx + 3, x1), y0 + 3), fill=palette["borde_luz"], width=2)
            label((x0 + x1) // 2, y0 - 7, "fragil", palette["borde_luz"])
        # Mundo 2, el 2-2 real (paso 13 de docs/propuesta-mundo-2.md; 2026-10-23).
        elif kind == "story_card":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 2), 1)
            for xx in range(x0, x1, 6):
                d.line((xx, y0, min(xx + 3, x1), y0), fill=palette["resplandor"], width=2)
            label((x0 + x1) // 2, y0 - 7, "historia", palette["resplandor"])
        elif kind == "pause_player":
            x0, y0, x1, y1 = box(x - 1, y - 1, 3, 2)
            d.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), outline=palette["debug_cian"], width=2)
            label((x0 + x1) // 2, y0 - 7, "reproductor (golpe al suelo)", palette["debug_cian"])
        elif kind == "loop_section":
            top, bottom = p["band"]
            x0, y0, _, _ = box(0, top)
            _, _, x1, y1 = box(cols - 1, bottom)
            for yy in (y0, y1):
                for xx in range(x0, x1, 8):
                    d.line((xx, yy, xx + 4, yy), fill=palette["resplandor"], width=2)
            ex = p["exit"]
            ex0, ey0, ex1, ey1 = box(ex[0], ex[1], ex[2], ex[3])
            d.rectangle((ex0, ey0, ex1, ey1), outline=palette["debug_cian"])
            label(x0 + 4, y0 + 8, "bucle (banda %d-%d)" % (top, bottom), palette["resplandor"], anchor="lm")
            label((ex0 + ex1) // 2, ey0 - 7, "salida", palette["debug_cian"])
        elif kind == "clone_zone":
            zc, zr, zw, zh = p["zone"]
            x0, y0, x1, y1 = box(zc, zr, zw, zh)
            for xx in range(x0, x1, 8):
                d.line((xx, y0, xx + 3, y0), fill=palette["alerta_sombra"])
                d.line((xx, y1, xx + 3, y1), fill=palette["alerta_sombra"])
            label((x0 + x1) // 2, y0 + 8, "zona de clones", palette["alerta"])
        # Mundo 2, el 2-3 real (paso 14 de docs/propuesta-mundo-2.md; 2026-10-23).
        elif kind == "loading_wall":
            x0, y0, x1, y1 = box(x, y, 1, int(p.get("height_tiles", 3)))
            d.rectangle((x0 + 2, y0 + 1, x1 - 2, y1 - 1), outline=palette["alerta"], width=2)
            label((x0 + x1) // 2, y0 - 7, "muro (3 golpes)", palette["alerta"])
        elif kind == "feed_sign":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 4), p.get("height_tiles", 1))
            d.rectangle((x0 + 1, y0 + 2, x1 - 1, y1 - 2), outline=palette["banner_gris"])
            label((x0 + x1) // 2, (y0 + y1) // 2, p.get("text", "").split("\n")[0][:28], palette["banner_gris"])
        elif kind == "extra_life_pickup":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 4, y0 + 3, x1 - 4, y1 - 3), outline=palette["debug_cian"], width=2)
            label((x0 + x1) // 2, y1 + 6, "vida extra", palette["debug_cian"])
        # Mundo 3 «La Vitrina» (paso 21 de docs/propuesta-mundo-3.md; 2026-10-27).
        elif kind == "heart_pickup":
            x0, y0, x1, y1 = box(x, y)
            cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
            d.polygon([(cx - 4, cy - 2), (cx, cy + 4), (cx + 4, cy - 2), (cx, cy - 1)], fill=palette["carmin"])
        elif kind == "like_platform":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 2), 1)
            d.rectangle((x0 + 1, y0 + 1, x1 - 1, y0 + 4), outline=palette["carmin"])
            tag = "%s%d" % ("<" if p.get("invert") else "♥", int(p.get("threshold", 0)))
            label((x0 + x1) // 2, y0 - 7, tag, palette["carmin"])
        elif kind in ("like_source", "like_reset", "crop_tool"):
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), outline=palette["carmin"], width=2)
            tag = {"like_source": "publicacion", "like_reset": "borrar", "crop_tool": "Recortar (Pellizcar)"}[kind]
            label((x0 + x1) // 2, y0 - 7, tag, palette["carmin"])
        elif kind == "filter_zone":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), p.get("height_tiles", 1))
            for xx in range(x0, x1, 8):
                d.line((xx, y0, xx + 4, y0), fill=palette["borde_luz"])
                d.line((xx, y1, xx + 4, y1), fill=palette["borde_luz"])
            label(x0 + 2, y0 + 8, "filtro" + (" movil" if p.get("positions") else ""), palette["borde_luz"], anchor="lm")
            for fc, fr, fw, fh in p.get("fake_floor", []):
                fx0, fy0, fx1, fy1 = box(fc, fr, fw, fh)
                d.rectangle((fx0, fy0, fx1, fy1), outline=palette["alerta"])
        elif kind == "small_frame":
            n = int(p.get("length_tiles", 1))
            vertical = p.get("orientation", "wall") in ("floor", "ceiling")
            x0, y0, x1, y1 = box(x, y, 1 if vertical else n, n if vertical else 1)
            d.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), outline=palette["resplandor"], width=2)
            label((x0 + x1) // 2, y0 - 7, "marco", palette["resplandor"])
        elif kind in ("mirror", "hunter_mirror"):
            x0, y0, x1, y1 = box(x, y)
            o = p.get("orientation", "|")
            if kind == "hunter_mirror":
                d.ellipse((x0 + 3, y0 + 3, x1 - 3, y1 - 3), outline=palette["debug_cian"], width=2)
                label((x0 + x1) // 2, y0 - 7, "cazador", palette["debug_cian"])
            elif o == "/":
                d.line((x0 + 2, y1 - 2, x1 - 2, y0 + 2), fill=palette["debug_cian"], width=2)
            elif o == "\\":
                d.line((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=palette["debug_cian"], width=2)
            else:
                d.line(((x0 + x1) // 2, y0 + 2, (x0 + x1) // 2, y1 - 2), fill=palette["debug_cian"], width=2)
        elif kind == "mirror_wall":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), p.get("height_tiles", 1))
            d.rectangle((x0, y0, x1, y1), outline=palette["debug_cian"])
            label((x0 + x1) // 2, y0 + 8, "pared de espejo", palette["debug_cian"])
        elif kind == "mirror_only":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), 1)
            for xx in range(x0, x1, 4):
                d.line((xx, y0, min(xx + 2, x1), y0), fill=palette["debug_cian"], width=3)
        elif kind == "pose_plate":
            x0, y0, x1, y1 = box(x, y)
            d.rectangle((x0 + 2, y1 - 4, x1 - 2, y1 - 1), fill=palette["borde_luz"])
            label((x0 + x1) // 2, y0 + 6, "placa", palette["borde_luz"])
        elif kind == "frame_door":
            x0, y0, x1, y1 = box(x, y, 1, 3)
            d.rectangle((x0 + 3, y0 + 1, x1 - 3, y1 - 1), outline=palette["borde_luz"], width=2)
            label((x0 + x1) // 2, y0 - 7, "puerta de marco", palette["borde_luz"])
        elif kind == "curator":
            x0, y0, x1, y1 = box(x, y, 8, 4)
            d.rectangle((x0, y0, x1, y1), outline=palette["borde_luz"], width=2)
            label((x0 + x1) // 2, (y0 + y1) // 2, "La Curadora", palette["banner_blanco"], normal)
        # Mundo 4 «El Chat» (paso 22 de docs/propuesta-mundo-4.md; 2026-10-28).
        elif kind in ("chat_bubble", "typing_bubble", "autocorrect_bubble"):
            w = bubble_tiles(p.get("text", ""))
            if kind == "autocorrect_bubble":
                w = max(w, bubble_tiles(p.get("corrected", "")))
            x0, y0, x1, y1 = box(x, y, w, 1)
            color = {"chat_bubble": palette["banner_blanco"], "typing_bubble": palette["resplandor"],
                     "autocorrect_bubble": palette["ambar"]}[kind]
            if p.get("side", "left") == "right":
                d.rectangle((x0 + 1, y0 + 1, x1 - 1, y0 + 6), fill=palette["fondo_medio"], outline=color)
            else:
                d.rectangle((x0 + 1, y0 + 1, x1 - 1, y0 + 6), outline=color)
            if kind == "typing_bubble":
                label((x0 + x1) // 2, y0 - 7, "escribiendo", color)
            elif kind == "autocorrect_bubble":
                label((x0 + x1) // 2, y0 - 7, "autocorrector", color)
        elif kind == "seen_zone":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 2), p.get("height_tiles", 1))
            d.rectangle((x0, y0, x1, y1), outline=palette["alerta"], width=2)
            label((x0 + x1) // 2, y0 - 7, "Visto", palette["alerta"])
        elif kind == "dark_zone":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 4), p.get("height_tiles", 4))
            for xx in range(x0, x1, 8):
                d.line((xx, y0, min(xx + 3, x1), y0), fill=palette["banner_gris"])
                d.line((xx, y1, min(xx + 3, x1), y1), fill=palette["banner_gris"])
            for yy in range(y0, y1, 8):
                d.line((x0, yy, x0, min(yy + 3, y1)), fill=palette["banner_gris"])
                d.line((x1, yy, x1, min(yy + 3, y1)), fill=palette["banner_gris"])
            label(x0 + 4, y0 + 8, "Modo oscuro", palette["banner_gris"], anchor="lm")
        elif kind == "ink_only":
            x0, y0, x1, y1 = box(x, y, p.get("width_tiles", 1), 1)
            for xx in range(x0, x1, 4):
                d.line((xx, y0, min(xx + 2, x1), y0), fill=palette["ambar"], width=3)
            label((x0 + x1) // 2, y0 + 9, "tinta", palette["ambar"])
        elif kind == "flashlight_pickup":
            x0, y0, x1, y1 = box(x, y)
            d.polygon([(x0 + 4, y0 + 6), (x1 - 2, y0 + 2), (x1 - 2, y1 - 2), (x0 + 4, y1 - 6)],
                      outline=palette["ambar"])
            label((x0 + x1) // 2, y0 - 7, "Linterna", palette["ambar"])
        elif kind == "seen_wave":
            start, end = p.get("start_col", 0), p.get("end_col", cols - 1)
            sx0, _, sx1, _ = box(start, 0, end - start + 1, 1)
            yy = TOP + rows * CELL - 4
            d.line((sx0, yy, sx1, yy), fill=palette["alerta"], width=2)
            label(sx0 + 4, yy - 8, "ola de Visto (col %d-%d)" % (start, end), palette["alerta"], anchor="lm")
            for stop in p.get("stops", []):
                px = box(stop["at_col"], 0)[0]
                d.line((px, TOP, px, TOP + rows * CELL), fill=palette["alerta_sombra"])
                label(px + 3, TOP + 18, "parada", palette["alerta"], anchor="lm")
        elif kind in ("papelera_actor", "undo_prompt", "typed_wall"):
            hh = 3 if kind == "typed_wall" else 1
            x0, y0, x1, y1 = box(x, y, 1, hh)
            d.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), outline=palette["banner_blanco"], width=2)
            tag = {"papelera_actor": "Papelera", "undo_prompt": "Deshacer", "typed_wall": "muro de texto"}[kind]
            label((x0 + x1) // 2, y0 - 7, tag, palette["banner_blanco"])
        elif kind == "seen":
            x0, y0, x1, y1 = box(x, y, 6, 3)
            d.rectangle((x0, y0, x1, y1), outline=palette["alerta"], width=2)
            label((x0 + x1) // 2, (y0 + y1) // 2, "El Visto", palette["banner_blanco"], normal)
        elif kind == "alert_major":
            # Jefe: caja de su badge de 256 px (4 x 4 tiles) centrada en su celda.
            x0, y0, x1, y1 = box(x - 2, y, 4, 4)
            d.rectangle((x0, y0, x1, y1), outline=palette["alerta"], width=2)
            d.ellipse((x0 + 12, y0 + 12, x1 - 12, y1 - 12), outline=palette["alerta"], width=2)
            label((x0 + x1) // 2, (y0 + y1) // 2, "Alerta Mayor", palette["banner_blanco"], normal)

    # Inversiones del scroll con zona que las arma (2-3, paso 14 de docs/propuesta-mundo-2.md).
    for rev in level.get("scroll", {}).get("reverses", []):
        if rev.get("trigger"):
            zc, zr, zw, zh = rev["trigger"]
            x0, y0, x1, y1 = box(zc, zr, zw, zh)
            d.rectangle((x0, y0, x1, y1), outline=palette["resplandor"])
            label((x0 + x1) // 2, y1 + 6, "inversion %g s" % rev["duration_s"], palette["resplandor"])

    # Enemigos con su rango de patrulla.
    tile = level["tile_size"]
    for enemy in level.get("enemies", []):
        x0, y0, x1, y1 = box(enemy["x"], enemy["y"])
        cx = (x0 + x1) // 2
        ep = enemy.get("params", {})
        if enemy["type"] == "alarm_bell":
            # Campana colgada del techo: onda discontinua hasta el suelo, sin patrulla.
            d.polygon([(cx - 6, y1 - 2), (cx + 6, y1 - 2), (cx + 4, y0 + 4), (cx - 4, y0 + 4)],
                      fill=palette["alerta"], outline=palette["alerta_sombra"])
            yy = y1 + 1
            while yy < TOP + rows * CELL and not solid(enemy["x"], (yy - TOP) // CELL):
                d.line((cx, yy, cx, yy + 3), fill=palette["alerta"])
                yy += 7
            continue
        if enemy["type"] == "spam_banner":
            n = int(ep.get("corridor_tiles", 8))
            step = int(ep.get("direction", -1))
            xa = cx
            xb = cx + step * n * CELL
            d.line((min(xa, xb), y1 - 4, max(xa, xb), y1 - 4), fill=palette["alerta_sombra"], width=2)
            head = xb
            d.polygon([(head, y1 - 4), (head - step * 6, y1 - 8), (head - step * 6, y1)], fill=palette["alerta"])
            d.rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), fill=palette["alerta"], outline=palette["alerta_sombra"])
            tag = "banner"
            if ep.get("knockback_to_entry"):
                tag = "banner (solo dash)"
            elif "rhythm" in ep:
                tag = "banner al compas"
            label(cx, y0 - 8, tag, palette["alerta"])
            continue
        if enemy["type"] == "autoplay_video":
            # Video en autoplay (Mundo 2): tarjeta de 2 x 2 desde su celda de abajo a la izquierda.
            vx0, vy0, vx1, vy1 = box(enemy["x"], enemy["y"] - 1, 2, 2)
            d.rectangle((vx0 + 1, vy0 + 1, vx1 - 1, vy1 - 1), outline=palette["alerta"], width=2)
            d.polygon([(vx0 + 10, vy0 + 8), (vx0 + 10, vy1 - 8), (vx1 - 9, (vy0 + vy1) // 2)], fill=palette["alerta"])
            label((vx0 + vx1) // 2, vy0 - 8, "video (%s)" % ep.get("clip", "?"), palette["alerta"])
            continue
        if enemy["type"] == "notification_badge":
            lw = ep.get("leash_width_px", 512.0) / tile * CELL
            lh = ep.get("leash_height_px", 256.0) / tile * CELL
            cy = (y0 + y1) // 2
            lx0, lx1 = int(cx - lw / 2), int(cx + lw / 2)
            ly0, ly1 = int(cy - lh / 2), int(cy + lh / 2)
            for xx in range(lx0, lx1, 8):
                d.line((xx, ly0, xx + 3, ly0), fill=palette["alerta_sombra"])
                d.line((xx, ly1, xx + 3, ly1), fill=palette["alerta_sombra"])
            for yy in range(ly0, ly1, 8):
                d.line((lx0, yy, lx0, yy + 3), fill=palette["alerta_sombra"])
                d.line((lx1, yy, lx1, yy + 3), fill=palette["alerta_sombra"])
            d.ellipse((x0 + 3, y0 + 3, x1 - 3, y1 - 3), fill=palette["carmin"], outline=palette["alerta"])
            label(cx, y0 - 8, "punto rojo", palette["alerta"])
            continue
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

    # Bandas de tramos: arriba con su ancho en tiles (horizontales) o a la derecha con sus
    # filas (verticales, tramos con y_from/y_to).
    band_colors = [palette["fondo_medio"], palette["tile_luz"]]
    for i, sec in enumerate(level.get("sections", [])):
        sx0, sx1 = sec.get("x_from", 0), sec.get("x_to", cols - 1)
        if vertical:
            sy0, sy1 = sec.get("y_from", 0), sec.get("y_to", rows - 1)
            bx0 = left + cols * CELL + 8
            by0, by1 = TOP + sy0 * CELL, TOP + (sy1 + 1) * CELL - 1
            d.rectangle((bx0, by0, bx0 + 10, by1), fill=band_colors[i % 2])
            label(bx0 + 18, (by0 + by1) // 2 - 8, sec["name"], palette["banner_blanco"], normal, anchor="lm")
            extra = "" if (sx0, sx1) == (0, cols - 1) else ", x %d-%d" % (sx0, sx1)
            label(bx0 + 18, (by0 + by1) // 2 + 8, "%d tiles de alto (filas %d-%d%s)" % (sy1 - sy0 + 1, sy0, sy1, extra),
                  palette["borde_luz"], anchor="lm")
            for yy in (by0, by1):
                for xx in range(left + sx0 * CELL, left + (sx1 + 1) * CELL, 6):
                    d.line((xx, yy, xx + 2, yy), fill=palette["banner_gris"])
            continue
        x0 = left + sx0 * CELL
        x1 = left + (sx1 + 1) * CELL - 1
        d.rectangle((x0, 8, x1, TOP - 14), fill=band_colors[i % 2])
        n = sx1 - sx0 + 1
        label((x0 + x1) // 2, 18, sec["name"], palette["banner_blanco"], normal)
        label((x0 + x1) // 2, 34, "%d tiles  (x %d-%d)" % (n, sx0, sx1), palette["borde_luz"])
        for xx in (x0, x1):
            for yy in range(TOP - 14, TOP + rows * CELL, 6):
                d.line((xx, yy, xx, yy + 2), fill=palette["banner_gris"])

    # Regla cada 10 tiles y distancias (y en vertical, otra cada 10 filas a la izquierda).
    ry = TOP + rows * CELL + 6
    for x in range(0, cols + 1):
        px = left + x * CELL
        if x % 10 == 0:
            d.line((px, ry, px, ry + 8), fill=palette["banner_gris"])
            label(px, ry + 16, str(x), palette["banner_gris"])
        elif x % 5 == 0:
            d.line((px, ry, px, ry + 4), fill=palette["tile_luz"])
    if vertical:
        for y in range(0, rows + 1):
            py = TOP + y * CELL
            if y % 10 == 0:
                d.line((left - 10, py, left - 2, py), fill=palette["banner_gris"])
                label(left - 14, py, str(y), palette["banner_gris"], anchor="rm")
            elif y % 5 == 0:
                d.line((left - 6, py, left - 2, py), fill=palette["tile_luz"])
    walk = 220.0
    px_total = cols * tile
    summary = ("%s %s  |  %dx%d tiles (%d x %d px)  |  1 tile = 64 px dibujado a %d px  |  "
               "recorrido sin paradas: %.0f s caminando a %.0f px/s"
               % (level["id"], level["name"], cols, rows, px_total, rows * tile, CELL,
                  px_total / walk, walk))
    if vertical:
        summary = ("%s %s  |  %dx%d tiles (%d x %d px)  |  1 tile = 64 px dibujado a %d px  |  nivel vertical"
                   % (level["id"], level["name"], cols, rows, px_total, rows * tile, CELL))
    label(SIDE, ry + 36, summary, palette["banner_blanco"], normal, anchor="lm")

    # Leyenda.
    ly = ry + 64
    items = [("#", "solido", palette["tile_base"]), ("-", "una via", palette["borde_luz"]),
             ("o", "punto de atencion", palette["ambar"]), ("E", "Burbuja + patrulla", palette["alerta"]),
             ("C", "punto de sincronizacion", palette["debug_cian"]), ("R", "receptor", palette["banner_gris"]),
             ("~", "puente retraido", palette["borde_luz"]), ("W", "pared con glitch (secreto)", palette["carmin_brillo"]),
             ("X", "pop-up (rojo = boton)", palette["banner_blanco"]), ("D", "puerta / meta G", palette["banner_blanco"]),
             ("e", "zona de Eco", palette["resplandor"]),
             ("I", "interruptor / panel oculto / laser / carga (acertijo de Calc)", palette["debug_cian"]),
             ("T", "techo colgado (cara de abajo)", palette["borde_luz"])]
    present = {o["type"] for o in level.get("objects", []) + level.get("enemies", [])}
    extra = [("blink_platform", "plataforma que parpadea (grupo)", palette["resplandor"]),
             ("rhythm_zone", "zona del metronomo / tunel (compas)", palette["resplandor"]),
             ("spam_banner", "banner y su barrido", palette["alerta"]),
             ("notification_badge", "punto rojo y su correa", palette["carmin"]),
             ("alarm_bell", "campana y su onda", palette["alerta"]),
             ("memory_pickup", "mensaje (recuerdo)", palette["banner_blanco"]),
             ("power_bank_pickup", "power bank", palette["debug_cian"]),
             ("alert_major", "jefe", palette["alerta"]),
             ("chat_bubble", "burbuja (relleno = de Isak)", palette["banner_blanco"]),
             ("typing_bubble", "«escribiendo…»", palette["resplandor"]),
             ("autocorrect_bubble", "autocorrector", palette["ambar"]),
             ("seen_zone", "zona «Visto»", palette["alerta"]),
             ("dark_zone", "Modo oscuro", palette["banner_gris"]),
             ("ink_only", "tinta (con la Linterna)", palette["ambar"]),
             ("seen_wave", "ola de «Visto» y paradas", palette["alerta"]),
             ("seen", "jefe El Visto", palette["alerta"])]
    items += [(k, text, color) for k, text, color in extra
              if k in present or (k == "rhythm_zone" and "alarm_tunnel" in present)]
    lx = SIDE
    for _, text, color in items:
        if lx + 24 + d.textlength(text, font=small) > width - SIDE:
            lx, ly = SIDE, ly + 20
        d.rectangle((lx, ly - 5, lx + 10, ly + 5), fill=color)
        d.text((lx + 16, ly), text, fill=palette["banner_gris"], font=small, anchor="lm")
        lx += 24 + int(d.textlength(text, font=small)) + 14
    return img.crop((0, 0, width, max(height, ly + 16)))


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        level = json.load(handle)
    # El Mundo 2 usa el tileset y el fondo del Mundo 1 hasta su arte (paso 10 de docs/propuesta-mundo-2.md):
    # el mapa de revision, tambien su paleta.
    palette = load_palette(os.path.join(ROOT, "assets", "palettes", "mundo1.gpl"))
    out = argv[2] if len(argv) > 2 else os.path.join(ROOT, "assets", "levels_preview", "%s_mapa.png" % level["id"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    render(level, palette).save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
