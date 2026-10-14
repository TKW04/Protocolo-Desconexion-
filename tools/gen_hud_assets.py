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
                            fila = estado (0 apagada, 1 encendida, 2 Sync Rate bajo, 3 rastro de dano)
  hud_battery_shell.png     32x16, marco de la bateria con polo
  hud_battery_segments.png  5x3 cuadros de 32x16 (alineados con el marco): columna = segmento,
                            fila = estado (0 vacio, 1 lleno en debug_cian, 2 rastro de dano/consumo)
  hud_attention.png         16x16, icono de punto de atencion (rombo ambar con ambar_sombra)
  hud_charge_ring.png       16 cuadros de 16x16, anillo de carga del Debug: el cuadro k muestra
                            (k+1)/16 lleno en sentido horario desde arriba, sobre la pista tile_luz
  _hud_assets_preview_x8.png  vista ampliada x8 sobre noche_profunda (no la usa el juego)

La fuente bitmap la genera tools/gen_hud_font.py. El validador es tools/validate_ui_assets.py.

Uso: python3 tools/gen_hud_assets.py
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

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
SIGNAL_BAR_W = 3
SIGNAL_BAR_GAP = 1
SIGNAL_BASE_Y = 13          # fila inferior de las barras (misma base que la bateria)
SIGNAL_HEIGHTS = (4, 7, 10, 13)
# estado -> (color principal, color de la columna derecha/sombra, color del pixel superior)
SIGNAL_STATES = (
    ("tile_luz", "tile_luz", "tile_luz"),            # 0 apagada
    ("banner_blanco", "banner_gris", "banner_blanco"),  # 1 encendida
    ("alerta", "alerta_sombra", "alerta"),           # 2 Sync Rate bajo
    ("alerta_sombra", "alerta_sombra", "alerta"),    # 3 rastro de dano
)


def draw_signal(spec):
    s = Sheet(spec)
    assert s.cols == len(SIGNAL_HEIGHTS) and s.rows == len(SIGNAL_STATES)
    for bar, h in enumerate(SIGNAL_HEIGHTS):
        x0 = 1 + bar * (SIGNAL_BAR_W + SIGNAL_BAR_GAP)
        x1 = x0 + SIGNAL_BAR_W - 1
        y0 = SIGNAL_BASE_Y - h + 1
        for row, (main, shade, top) in enumerate(SIGNAL_STATES):
            s.rect(bar, row, x0, y0, x1 - 1, SIGNAL_BASE_Y, main)
            s.rect(bar, row, x1, y0, x1, SIGNAL_BASE_Y, shade)
            s.rect(bar, row, x0, y0, x1, y0, top)
    return s.save()


# ------------------------------------------------------------------ bateria (energia de Debug)
BAT_X0, BAT_X1 = 1, 28      # cuerpo (inclusivo)
BAT_Y0, BAT_Y1 = 2, 13
TIP_X0, TIP_X1 = 29, 30
TIP_Y0, TIP_Y1 = 5, 10
SEG_X0, SEG_Y0, SEG_Y1 = 3, 4, 11
SEG_W, SEG_GAP = 4, 1
SEG_STATES = ("tile_luz", "debug_cian", "alerta_sombra")  # vacio, lleno, rastro


def draw_battery_shell(spec):
    s = Sheet(spec)
    c = "banner_blanco"
    s.rect(0, 0, BAT_X0 + 1, BAT_Y0, BAT_X1 - 1, BAT_Y0, c)       # arriba (esquinas recortadas)
    s.rect(0, 0, BAT_X0 + 1, BAT_Y1, BAT_X1 - 1, BAT_Y1, "banner_gris")  # abajo, en sombra
    s.rect(0, 0, BAT_X0, BAT_Y0 + 1, BAT_X0, BAT_Y1 - 1, c)       # izquierda
    s.rect(0, 0, BAT_X1, BAT_Y0 + 1, BAT_X1, BAT_Y1 - 1, "banner_gris")  # derecha, en sombra
    s.rect(0, 0, TIP_X0, TIP_Y0, TIP_X1 - 1, TIP_Y1, "banner_gris")
    s.rect(0, 0, TIP_X1, TIP_Y0 + 1, TIP_X1, TIP_Y1 - 1, "banner_gris")  # polo redondeado
    return s.save()


def draw_battery_segments(spec):
    s = Sheet(spec)
    assert s.rows == len(SEG_STATES)
    for seg in range(s.cols):
        x0 = SEG_X0 + seg * (SEG_W + SEG_GAP)
        assert x0 + SEG_W - 1 < BAT_X1 - 1, "los segmentos no caben en el marco"
        for row, color in enumerate(SEG_STATES):
            s.rect(seg, row, x0, SEG_Y0, x0 + SEG_W - 1, SEG_Y1, color)
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
    ]
    preview(images)
    for key in ("panel", "signal", "battery_shell", "battery_segments", "attention_icon", "charge_ring"):
        print("gen_hud_assets:", spec[key]["path"])
    print("gen_hud_assets: vista", os.path.relpath(PREVIEW, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
