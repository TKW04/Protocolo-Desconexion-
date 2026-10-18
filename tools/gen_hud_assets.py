#!/usr/bin/env python3
"""Genera el arte pixel art del HUD del Mundo 1 con los colores de assets/palettes/mundo1.gpl.

Pixel base del HUD: se dibuja a resolucion nativa ("pixeles de arte") y el juego lo escala
x hud_pixel_scale (2, entero) a 1280x720, como los tiles (32 px de arte = 64 px). Las rutas,
cuadros, columnas y filas salen de la seccion "assets" de data/hud.json (el generador
comprueba que su dibujo encaja). Solo colores de la paleta (debug_cian incluido: es el color
del Debug del HUD) y alfa 0/255.

Salidas (assets/sprites/ui/):
  hud_panel.png             16x16, fondo de la barra de estado (NinePatch): noche_profunda con
                            linea de borde_luz abajo y un pixel oscuro debajo para separar del juego
  hud_signal.png            4x4 cuadros de 16x16: columna = barra (0-3, de menor a mayor),
                            fila = estado (0 apagada, 1 encendida, 2 Sync Rate bajo, 3 rastro de dano).
                            Estilo "circuito limpio" del drop de Sync Rate (docs/estilizacion-energia.md):
                            nodo octogonal (contorno noche_profunda, anillo banner_blanco/banner_gris,
                            fondo tile_base) con las barras dentro. El nodo va en los cuadros de la
                            columna 0, que siempre se dibuja.
  hud_battery_shell.png     2 cuadros de 32x16 (filas): 0 con energia, 1 vacia. Estilo del drop de
                            energia: carcasa con contorno de esquinas recortadas, bisel, celda cian con
                            rayo (apagada en tonos de tile si esta vacia), divisor, ventana oscura y borne
                            metalico
  hud_battery_segments.png  5x3 cuadros de 32x16 (alineados con el marco): columna = segmento,
                            fila = estado (0 vacio en tile_base, 1 lleno en debug_cian con brillo
                            banner_blanco, 2 rastro de dano/consumo)
  hud_attention.png         16x16, icono de punto de atencion (rombo ambar con ambar_sombra)
  hud_charge_ring.png       16 cuadros de 16x16, anillo de carga del Debug: el cuadro k muestra
                            (k+1)/16 lleno en sentido horario desde arriba, sobre la pista tile_luz
  hud_lives.png             2 cuadros de 16x16 (columnas): 0 vida (intento) llena, 1 vacia. Mini
                            telefono de 10x13 px (x 3-12, filas 1-13) en estilo circuito
                            (docs/propuesta-asistentes-y-vidas.md §9): lleno = bisel banner_blanco /
                            banner_gris y pantalla encendida en resplandor con una traza de 1 px y su
                            nodo en banner_blanco; vacio = apagado en tile_luz, pantalla tile_sombra con
                            una grieta diagonal (distinta forma ademas de color, por daltonismo). Sin rojo.
  hud_hide.png              2 cuadros de 16x16 (columnas): icono «oculto» del Ocultarte (Pulso 4 de las
                            mejoras de Calc, tanda M2; docs/propuesta-mejoras.md §4 y §9): silueta de Isak
                            (cabeza y torso) discontinua en debug_cian con dos filas desplazadas 1 px (el
                            glitch del efecto) y un punto banner_blanco de brillo; 0 normal, 1 apagado para
                            el parpadeo del aviso (Sync Rate o energia por debajo del 20 %) en tile_luz con
                            el punto en banner_gris. No usa el color clave del Debug (el Ocultarte es cian
                            en todos los mundos). Sin rojo.
  _hud_assets_preview_x8.png  vista ampliada x8 sobre noche_profunda (no la usa el juego)

La fuente bitmap la genera tools/gen_hud_font.py. El validador es tools/validate_ui_assets.py.

Uso: python3 tools/gen_hud_assets.py
"""
import json
import math
import os
import site
import sys

# Con -I no se carga el site de usuario (donde puede estar Pillow): se anade a mano.
sys.path.append(site.getusersitepackages())
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo1.gpl")
HUD_JSON = os.path.join(ROOT, "data", "hud.json")
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "ui")
PREVIEW = os.path.join(OUT_DIR, "_hud_assets_preview_x8.png")
PREVIEW_SCALE = 8
CLEAR = (0, 0, 0, 0)


def load_palette(path):
    pal = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            parts = s.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                pal[parts[3]] = tuple(int(p) for p in parts[:3]) + (255,)
    return pal


P = load_palette(GPL)


def res_to_path(res):
    return os.path.join(ROOT, res.replace("res://", "", 1))


def load_assets_spec():
    with open(HUD_JSON, encoding="utf-8") as fh:
        return json.load(fh)["assets"]


class Sheet:
    def __init__(self, spec):
        self.fw, self.fh = spec["frame_size"]
        self.cols, self.rows = spec["columns"], spec["rows"]
        self.path = res_to_path(spec["path"])
        self.img = Image.new("RGBA", (self.fw * self.cols, self.fh * self.rows), CLEAR)
        self.d = ImageDraw.Draw(self.img)

    def rect(self, col, row, x0, y0, x1, y1, color):
        """Rectangulo inclusivo en coordenadas del cuadro (col, row)."""
        ox, oy = col * self.fw, row * self.fh
        assert 0 <= x0 <= x1 < self.fw and 0 <= y0 <= y1 < self.fh, (x0, y0, x1, y1)
        self.d.rectangle([ox + x0, oy + y0, ox + x1, oy + y1], fill=P[color])

    def px(self, col, row, x, y, color):
        self.img.putpixel((col * self.fw + x, row * self.fh + y), P[color] if color else CLEAR)

    def save(self):
        self.img.save(self.path)
        return self.img


# ------------------------------------------------------------------ barra de estado
def draw_panel(spec):
    s = Sheet(spec)
    s.rect(0, 0, 0, 0, s.fw - 1, s.fh - 3, "noche_profunda")
    s.rect(0, 0, 0, s.fh - 2, s.fw - 1, s.fh - 2, "borde_luz")
    s.rect(0, 0, 0, s.fh - 1, s.fw - 1, s.fh - 1, "noche_profunda")
    return s.save()


# ------------------------------------------------------------------ senal (Sync Rate)
# Nodo octogonal (como el drop de Sync Rate) de NODE_W x NODE_H con esquinas cortadas en diagonal
# NODE_CUT px; dentro, 4 barras de SIGNAL_BAR_W px separadas SIGNAL_BAR_GAP, con base en la fila
# SIGNAL_BASE_Y. Filas 1-13, como la carcasa de la bateria (la linea del panel son las filas 14-15). El contorno noche_profunda
# del drop lo pone aqui el propio panel (noche_profunda): el borde del nodo es ya el anillo
# banner_blanco/banner_gris, y asi las barras tienen el mismo sitio que antes.
NODE_X0, NODE_Y0, NODE_W, NODE_H = 0, 1, 16, 13
NODE_CUT = 2
SIGNAL_BAR_W = 2
SIGNAL_BAR_GAP = 1
SIGNAL_BAR_X0 = 2
SIGNAL_BASE_Y = 11
SIGNAL_HEIGHTS = (3, 5, 7, 9)
# estado -> (color principal, color de la columna derecha/sombra, color del pixel superior)
SIGNAL_STATES = (
    ("tile_luz", "tile_luz", "tile_luz"),            # 0 apagada
    ("banner_blanco", "banner_gris", "banner_blanco"),  # 1 encendida
    ("alerta", "alerta_sombra", "alerta"),           # 2 Sync Rate bajo
    ("alerta_sombra", "alerta_sombra", "alerta"),    # 3 rastro de dano
)


def node_layers():
    """Pixeles del nodo octogonal: (anillo, nucleo) como conjuntos de (x, y)."""
    shape = set()
    for y in range(NODE_H):
        k = min(y, NODE_H - 1 - y)
        cut = max(NODE_CUT - k, 0)
        for x in range(cut, NODE_W - cut):
            shape.add((NODE_X0 + x, NODE_Y0 + y))

    def inner(cells):
        return {(x, y) for (x, y) in cells
                if all((x + dx, y + dy) in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}

    core = inner(shape)
    return shape - core, core


def draw_signal(spec):
    s = Sheet(spec)
    assert s.cols == len(SIGNAL_HEIGHTS) and s.rows == len(SIGNAL_STATES)
    ring, core = node_layers()
    cx, cy = NODE_X0 + (NODE_W - 1) / 2, NODE_Y0 + (NODE_H - 1) / 2
    right, bottom = max(x for x, _ in ring), max(y for _, y in ring)
    for row in range(s.rows):
        for (x, y) in ring:
            # luz arriba/izquierda, sombra abajo/derecha (bisel del estilo circuito)
            shade = x == right or y == bottom or (x > cx and y > cy)
            s.px(0, row, x, y, "banner_gris" if shade else "banner_blanco")
        for (x, y) in core:
            s.px(0, row, x, y, "tile_base")
    for bar, h in enumerate(SIGNAL_HEIGHTS):
        x0 = SIGNAL_BAR_X0 + bar * (SIGNAL_BAR_W + SIGNAL_BAR_GAP)
        x1 = x0 + SIGNAL_BAR_W - 1
        y0 = SIGNAL_BASE_Y - h + 1
        for (x, y) in ((x0, y0), (x1, SIGNAL_BASE_Y)):
            assert (x, y) in core, "la barra %d se sale del nodo" % bar
        for row, (main, shade, top) in enumerate(SIGNAL_STATES):
            s.rect(bar, row, x0, y0, x1 - 1, SIGNAL_BASE_Y, main)
            s.rect(bar, row, x1, y0, x1, SIGNAL_BASE_Y, shade)
            s.rect(bar, row, x0, y0, x1, y0, top)
    return s.save()


# ------------------------------------------------------------------ bateria (energia de Debug)
# Carcasa 30x13 (x 0-29, filas 1-13) con contorno noche_profunda de esquinas recortadas y bisel
# (borde_luz arriba/izquierda, tile_luz abajo/derecha: sobre el panel noche_profunda el tile_base no
# se veria); a la izquierda la celda de energia con el
# rayo; un divisor; la ventana oscura (tile_sombra) con los 5 segmentos; y el borne a la derecha.
BAT_X0, BAT_X1 = 0, 29
BAT_Y0, BAT_Y1 = 1, 13
CELL_X0, CELL_X1 = 2, 6
DIVIDER_X = 7
WIN_X0, WIN_X1 = 8, 27
IN_Y0, IN_Y1 = 3, 11
TIP_X0, TIP_X1 = 30, 31
TIP_Y0, TIP_Y1 = 4, 10
SEG_X0, SEG_Y0, SEG_Y1 = 8, 4, 10
SEG_W, SEG_GAP = 3, 1
# Rayo de la celda (5x9, filas IN_Y0-IN_Y1); '#' = rayo.
CELL_BOLT = (
    "....#",
    "...##",
    "..##.",
    ".##..",
    "#####",
    "..##.",
    ".##..",
    "##...",
    "#....",
)
# Fila del marco -> (fondo de la celda, rayo): 0 con energia (rayo en el color clave, que el
# shader cambia por el del Debug del mundo), 1 vacia (tonos de tile: apagada).
SHELL_STATES = (("tile_sombra", "debug_cian"), ("tile_sombra", "tile_luz"))
# Segmentos: estado -> (relleno, brillo del pixel superior izquierdo).
SEG_STATES = (("tile_base", "tile_base"), ("debug_cian", "banner_blanco"), ("alerta_sombra", "alerta_sombra"))


def draw_battery_shell(spec):
    s = Sheet(spec)
    assert s.rows == len(SHELL_STATES)
    for row, (cell_bg, bolt) in enumerate(SHELL_STATES):
        s.rect(0, row, BAT_X0, BAT_Y0, BAT_X1, BAT_Y1, "noche_profunda")
        for x, y in ((BAT_X0, BAT_Y0), (BAT_X1, BAT_Y0), (BAT_X0, BAT_Y1), (BAT_X1, BAT_Y1)):
            s.px(0, row, x, y, None)
        s.rect(0, row, BAT_X0 + 1, BAT_Y0 + 1, BAT_X1 - 1, BAT_Y1 - 1, "tile_luz")
        s.rect(0, row, BAT_X0 + 1, BAT_Y0 + 1, BAT_X1 - 1, BAT_Y0 + 1, "borde_luz")
        s.rect(0, row, BAT_X0 + 1, BAT_Y0 + 1, BAT_X0 + 1, BAT_Y1 - 1, "borde_luz")
        s.rect(0, row, BAT_X0 + 2, BAT_Y1 - 1, BAT_X1 - 1, BAT_Y1 - 1, "tile_luz")
        s.rect(0, row, BAT_X1 - 1, BAT_Y0 + 2, BAT_X1 - 1, BAT_Y1 - 1, "tile_luz")
        # celda de energia con el rayo
        s.rect(0, row, CELL_X0, IN_Y0, CELL_X1, IN_Y1, cell_bg)
        assert len(CELL_BOLT) == IN_Y1 - IN_Y0 + 1 and len(CELL_BOLT[0]) == CELL_X1 - CELL_X0 + 1
        for j, line in enumerate(CELL_BOLT):
            for i, ch in enumerate(line):
                if ch == "#":
                    s.px(0, row, CELL_X0 + i, IN_Y0 + j, bolt)
        # divisor y ventana de los segmentos
        s.rect(0, row, DIVIDER_X, IN_Y0, DIVIDER_X, IN_Y1, "noche_profunda")
        s.rect(0, row, WIN_X0, IN_Y0, WIN_X1, IN_Y1, "tile_sombra")
        # borne metalico (como el del drop): contorno, banner_gris y brillo banner_blanco
        s.rect(0, row, TIP_X0, TIP_Y0, TIP_X1, TIP_Y1, "noche_profunda")
        s.px(0, row, TIP_X1, TIP_Y0, None)
        s.px(0, row, TIP_X1, TIP_Y1, None)
        s.rect(0, row, TIP_X0, TIP_Y0 + 1, TIP_X0, TIP_Y1 - 1, "banner_gris")
        s.px(0, row, TIP_X0, TIP_Y0 + 1, "banner_blanco")
    return s.save()


def draw_battery_segments(spec):
    s = Sheet(spec)
    assert s.rows == len(SEG_STATES)
    for seg in range(s.cols):
        x0 = SEG_X0 + seg * (SEG_W + SEG_GAP)
        assert WIN_X0 <= x0 and x0 + SEG_W - 1 <= WIN_X1, "los segmentos no caben en la ventana"
        for row, (fill, glint) in enumerate(SEG_STATES):
            s.rect(seg, row, x0, SEG_Y0, x0 + SEG_W - 1, SEG_Y1, fill)
            s.px(seg, row, x0, SEG_Y0, glint)
    return s.save()


# ------------------------------------------------------------------ icono de puntos de atencion
# Rombo (la misma forma que el objeto punto de atencion del nivel) de 2*R+1 px: relleno ambar,
# borde inferior derecho en ambar_sombra (luz arriba e izquierda) y un punto central en sombra.
ATTENTION_R = 6
ATTENTION_DOT_R = 1


def draw_attention(spec):
    s = Sheet(spec)
    # Centro: filas 1-13 (el mismo alto que las barras de senal; no toca la linea del panel).
    cx, cy = s.fw // 2, ATTENTION_R + 1
    for y in range(s.fh):
        for x in range(s.fw):
            dx, dy = x - cx, y - cy
            dist = abs(dx) + abs(dy)
            if dist > ATTENTION_R:
                continue
            edge = dist == ATTENTION_R
            if dist <= ATTENTION_DOT_R:
                color = "ambar_sombra"
            elif edge and (dx + dy) >= 0:
                color = "ambar_sombra"
            else:
                color = "ambar"
            s.px(0, 0, x, y, color)
    return s.save()


# ------------------------------------------------------------------ anillo de carga del Debug
RING_CENTER = 8.0
RING_OUTER = 6.1
RING_INNER = 3.9


def ring_pixels():
    """Pixeles del anillo con su angulo (0 = arriba, horario, en vueltas 0-1)."""
    out = []
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - RING_CENTER, y + 0.5 - RING_CENTER
            d = math.hypot(dx, dy)
            if RING_INNER <= d < RING_OUTER:
                turns = (math.atan2(dx, -dy) / (2 * math.pi)) % 1.0
                out.append((x, y, turns))
    return out


def draw_charge_ring(spec):
    s = Sheet(spec)
    steps = s.cols
    pixels = ring_pixels()
    for k in range(steps):
        filled = (k + 1) / steps
        for x, y, turns in pixels:
            s.px(k, 0, x, y, "debug_cian" if turns < filled - 1e-9 else "tile_luz")
    return s.save()


# ------------------------------------------------------------------ vidas (intentos)
# Mini telefono (docs/propuesta-asistentes-y-vidas.md §9, HUD de vidas): cuerpo de LIFE_X0-LIFE_X1 x
# LIFE_Y0-LIFE_Y1 con esquinas cortadas, pantalla LIFE_SCREEN y boton abajo. El borde oscuro lo pone
# el panel (noche_profunda), como en la senal.
LIFE_X0, LIFE_X1, LIFE_Y0, LIFE_Y1 = 3, 12, 1, 13
LIFE_SCREEN = (5, 3, 10, 10)
# Traza de circuito de la pantalla encendida (polilinea) y su nodo final (2x1).
LIFE_TRACE = ((6, 9), (6, 6), (9, 6), (9, 4))
# Grieta de la pantalla apagada (diagonal).
LIFE_CRACK = ((9, 4), (8, 5), (8, 6), (7, 7), (6, 8), (6, 9))
# estado -> (bisel luz, bisel sombra, pantalla, traza, boton)
LIFE_STATES = (
    ("banner_blanco", "banner_gris", "resplandor", "banner_blanco", "banner_gris"),  # 0 llena
    ("tile_luz", "tile_luz", "tile_sombra", "tile_luz", "tile_base"),            # 1 vacia
)


def draw_lives(spec):
    s = Sheet(spec)
    assert s.cols == len(LIFE_STATES) and s.rows == 1
    for col, (light, shade, screen, trace, button) in enumerate(LIFE_STATES):
        s.rect(col, 0, LIFE_X0, LIFE_Y0, LIFE_X1, LIFE_Y1, shade)
        s.rect(col, 0, LIFE_X0, LIFE_Y0, LIFE_X1 - 1, LIFE_Y0, light)
        s.rect(col, 0, LIFE_X0, LIFE_Y0, LIFE_X0, LIFE_Y1 - 1, light)
        for x, y in ((LIFE_X0, LIFE_Y0), (LIFE_X1, LIFE_Y0), (LIFE_X0, LIFE_Y1), (LIFE_X1, LIFE_Y1)):
            s.px(col, 0, x, y, None)
        # interior del cuerpo (tile_base) y pantalla
        s.rect(col, 0, LIFE_X0 + 1, LIFE_Y0 + 1, LIFE_X1 - 1, LIFE_Y1 - 1, "tile_base")
        x0, y0, x1, y1 = LIFE_SCREEN
        s.rect(col, 0, x0, y0, x1, y1, screen)
        # altavoz arriba y boton abajo
        s.rect(col, 0, 7, LIFE_Y0 + 1, 8, LIFE_Y0 + 1, "noche_profunda")
        s.rect(col, 0, 7, LIFE_Y1 - 1, 8, LIFE_Y1 - 1, button)
        if col == 0:
            for (ax, ay), (bx, by) in zip(LIFE_TRACE, LIFE_TRACE[1:]):
                s.rect(col, 0, min(ax, bx), min(ay, by), max(ax, bx), max(ay, by), trace)
            s.rect(col, 0, 9, 3, 10, 3, trace)  # nodo de la traza
            s.px(col, 0, 6, 9, "banner_gris")
        else:
            for x, y in LIFE_CRACK:
                s.px(col, 0, x, y, trace)
    return s.save()


# ------------------------------------------------------------------ icono «oculto» (Ocultarte)
HIDE_SHAPE = (
    "................",
    "......####......",
    ".....#....#.....",
    ".....#....#.....",
    ".....#....#.....",
    "......####......",
    "................",
    "....########....",
    "...#........#...",
    "..#..........#..",
    "..#..........#..",
    "..#..........#..",
    "..#..........#..",
    "..############..",
    "................",
    "................",
)
# Filas del glitch (se desplazan 1 px a la derecha) y hueco de la linea discontinua.
HIDE_GLITCH_ROWS = (9, 10)
HIDE_GAP_EVERY = 3
HIDE_SPARK = (7, 3)
# estado -> (trazo, brillo)
HIDE_STATES = (("debug_cian", "banner_blanco"), ("tile_luz", "banner_gris"))


def draw_hide(spec):
    s = Sheet(spec)
    assert s.cols == len(HIDE_STATES) and s.rows == 1 and (s.fw, s.fh) == (16, 16)
    for col, (stroke, spark) in enumerate(HIDE_STATES):
        n = 0
        for y, row in enumerate(HIDE_SHAPE):
            shift = 1 if y in HIDE_GLITCH_ROWS else 0
            for x, ch in enumerate(row):
                if ch != "#":
                    continue
                n += 1
                if n % HIDE_GAP_EVERY == 0:
                    continue
                if 0 <= x + shift < s.fw:
                    s.px(col, 0, x + shift, y, stroke)
        s.px(col, 0, HIDE_SPARK[0], HIDE_SPARK[1], spark)
    return s.save()


# ------------------------------------------------------------------ vista ampliada
def preview(images):
    pad = 4
    w = max(i.width for i in images) + 2 * pad
    h = sum(i.height + pad for i in images) + pad
    sheet = Image.new("RGBA", (w, h), P["noche_profunda"])
    y = pad
    for img in images:
        sheet.alpha_composite(img, (pad, y))
        y += img.height + pad
    sheet.resize((w * PREVIEW_SCALE, h * PREVIEW_SCALE), Image.NEAREST).save(PREVIEW)


def main():
    spec = load_assets_spec()
    os.makedirs(OUT_DIR, exist_ok=True)
    images = [
        draw_panel(spec["panel"]),
        draw_signal(spec["signal"]),
        draw_battery_shell(spec["battery_shell"]),
        draw_battery_segments(spec["battery_segments"]),
        draw_attention(spec["attention_icon"]),
        draw_charge_ring(spec["charge_ring"]),
        draw_lives(spec["lives"]),
        draw_hide(spec["hide"]),
    ]
    preview(images)
    for key in ("panel", "signal", "battery_shell", "battery_segments", "attention_icon", "charge_ring", "lives", "hide"):
        print("gen_hud_assets:", spec[key]["path"])
    print("gen_hud_assets: vista", os.path.relpath(PREVIEW, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
