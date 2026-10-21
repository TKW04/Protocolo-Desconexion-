#!/usr/bin/env python3
"""Genera el arte del 1-3 «No molestar» (paso 8 de docs/propuesta-1-3.md §7, 2026-10-20).

Arte por script (sin AutoSprite), estilo circuito limpio de tools/gen_calc_encounter.py.
Solo colores de assets/palettes/mundo1.gpl + assets/palettes/effects_pulse.gpl; fondo
transparente, alfa 0 o 255. El rojo (alerta, alerta_sombra) solo en lo que dana y sus
avisos (la campana y su onda); el ambar, en nada (es de los puntos de atencion).

Salidas (rutas relativas a assets/sprites/):
  props/dnd/dnd_switch_off_00..01.png    64x64  interruptor «No molestar» apagado (luna apagada)
  props/dnd/dnd_switch_hit_00..02.png    64x64  golpeado por el pulso (destello y anillo)
  props/dnd/dnd_switch_on_00..01.png     64x64  encendido (luna creciente en borde_luz, cian)
  props/dnd/blink_w<n>_on_00..04.png     64n x 32  plataforma que parpadea (n = 1-3 tiles)
                                         encendida con 0-4 segmentos llenos
  props/dnd/blink_w<n>_warn_00.png       64n x 32  cuadro «apagado» del parpadeo de aviso
  props/dnd/blink_w<n>_off_00.png        64n x 32  apagada: contorno punteado
  props/dnd/rhythm_icon_dim_00.png       64x64  icono de vibracion del metronomo (reposo)
  props/dnd/rhythm_icon_lit_00.png       64x64  icono de vibracion (al empezar el ciclo)
  props/dnd/exceptions_frame_00.png      24x24  nine-patch del panel «Excepciones» (margen 8)
  props/dnd/exceptions_contact_00.png    16x16  persona generica
  props/dnd/exceptions_star_00.png       16x16  estrella de favorito (borde_luz, no ambar)
  props/dnd/dash_trail_00..01.png        32x4   fila de la estela del dash (se repite en x)
  props/dnd/banner_dash_card_00.png      128x64 dibujo de la ficha del banner obligatorio
                                         (banner_sweep_00 de gen_world1_enemies con la estela
                                         del dash cruzandolo y el techo bajo)
  enemies/alarm_bell/alarm_bell_rest_00.png      64x64  campana quieta (arriba de su celda)
  enemies/alarm_bell/alarm_bell_warn_00..01.png  64x64  aviso: tiembla (-2 / +2 px), badajo rojo
  enemies/alarm_bell/alarm_bell_ring_00..01.png  64x64  suena (arcos de sonido)
  enemies/alarm_bell/alarm_wave_00..01.png       48x64  onda (se repite en y; las flechas bajan)
  enemies/alarm_bell/alarm_warn_line_00.png      64x8   linea discontinua roja del suelo
  dnd_objects_frames.tres                SpriteFrames del interruptor (dnd_switch_off/hit/on)

Uso (desde la raiz del repo):
  python3 tools/gen_world1_dnd.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_world1_dnd.py (en tools/run_tests.sh).
"""
import math
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, Canvas, REPO  # noqa: E402
from gen_hub_objects import sprite_frames_tres  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

N = PAL["noche_profunda"]
TS = PAL["tile_sombra"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]
BL = PAL["borde_luz"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
R = PAL["resplandor"]
FM = PAL["fondo_medio"]
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]
A = PAL["alerta"]
AS = PAL["alerta_sombra"]
CLEAR = (0, 0, 0, 0)

# Prohibidos en todo este arte (el ambar es de los puntos; el carmin, del punto debil).
FORBIDDEN = ("carmin", "carmin_brillo", "ambar", "ambar_sombra")
# Ademas, sin rojos fuera de la campana (el rojo es dano y sus avisos).
RED = ("alerta", "alerta_sombra")
RED_OK_PREFIX = ("enemies/alarm_bell/", "props/dnd/banner_dash_card")

SWITCH_ANIMS = [
    ("dnd_switch_off", "props/dnd/dnd_switch_off", 2, 2.0, True),
    ("dnd_switch_hit", "props/dnd/dnd_switch_hit", 3, 12.0, False),
    ("dnd_switch_on", "props/dnd/dnd_switch_on", 2, 3.0, True),
]
FRAMES_TRES = "dnd_objects_frames.tres"
PAD = (32, 38)
BLINK_WIDTHS = (1, 2, 3)
BLINK_H = 32
SEG_COUNT = 4
BANNER_SRC = "enemies/banner_sweep_00.png"


def disc(cv, cx, cy, r, color):
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            if x * x + y * y <= r * r + r * 0.6:
                cv.p(cx + x, cy + y, color)


def ring(cv, cx, cy, r, color):
    for y in range(-r - 1, r + 2):
        for x in range(-r - 1, r + 2):
            d = math.hypot(x, y)
            if r - 0.5 <= d < r + 0.5:
                cv.p(cx + x, cy + y, color)


def crescent(cv, cx, cy, r, color, shade=None):
    """Luna creciente: disco de radio r menos un disco desplazado arriba a la derecha."""
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            inside = x * x + y * y <= r * r + r * 0.6
            bite = (x - r * 0.55) ** 2 + (y + r * 0.35) ** 2 <= (r * 0.8) ** 2
            if inside and not bite:
                cv.p(cx + x, cy + y, color)
    if shade is not None:  # borde interior del creciente (sombra)
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                inside = x * x + y * y <= r * r + r * 0.6
                bite = (x - r * 0.55) ** 2 + (y + r * 0.35) ** 2 <= (r * 0.8) ** 2
                near = (x - r * 0.55) ** 2 + (y + r * 0.35) ** 2 <= (r * 0.8 + 1.2) ** 2
                if inside and not bite and near:
                    cv.p(cx + x, cy + y, shade)


# ------------------------------------------------------------ interruptor «No molestar»
def dnd_switch(state, f):
    cv = Canvas(64, 64)
    x0, y0, x1, y1 = 8, 14, 55, 62
    on = state == "on"
    cv.box(x0, y0, x1, y1, TL)
    cv.hline(x0 + 1, x1 - 1, y0 + 1, C if on else BL)
    cv.vline(x0 + 1, y0 + 2, y1 - 1, C if on else BL)
    cv.vline(x1 - 1, y0 + 2, y1 - 1, TB)
    cv.hline(x0 + 2, x1 - 1, y1 - 1, TB)
    for (x, y) in ((11, 17), (52, 17), (11, 59), (52, 59)):
        cv.p(x, y, G)
    # rotulo: tres rayas cortas (texto ilegible a esta escala) arriba a la izquierda
    for i, ln in enumerate((9, 6, 8)):
        cv.hline(14, 14 + ln, 18 + i * 2, TB)
    # LED de estado
    led = {"off": TL if f == 0 else G, "hit": CC, "on": C if f == 0 else CC}[state]
    cv.rect(45, 18, 47, 19, N)
    cv.rect(45, 18, 46, 19, led)
    cx, cy = PAD
    disc(cv, cx, cy, 13, N)
    if state == "off":
        disc(cv, cx, cy, 12, G)
        disc(cv, cx, cy, 10, TS)
        crescent(cv, cx - 1, cy, 7, TL if f == 0 else FM)
    elif state == "hit":
        disc(cv, cx, cy, 12, TS)
        if f == 0:
            disc(cv, cx, cy, 8, C)
            crescent(cv, cx - 1, cy, 7, W)
        elif f == 1:
            ring(cv, cx, cy, 10, C)
            ring(cv, cx, cy, 9, CC)
            crescent(cv, cx - 1, cy, 7, W, BL)
        else:
            ring(cv, cx, cy, 12, CC)
            ring(cv, cx, cy, 11, C)
            crescent(cv, cx - 1, cy, 7, BL, R)
            for (x, y) in ((cx - 15, cy - 9), (cx + 15, cy + 9), (cx + 14, cy - 10), (cx - 14, cy + 10)):
                cv.sparkle(x, y)
    else:
        disc(cv, cx, cy, 12, C)
        disc(cv, cx, cy, 10, TS)
        crescent(cv, cx - 1, cy, 7, BL, R)
        cv.p(cx - 5, cy - 3, W)
        # estrellitas junto a la luna (laten)
        if f == 0:
            cv.p(cx + 5, cy - 5, CC)
            cv.p(cx + 6, cy + 3, CD)
        else:
            cv.sparkle(cx + 5, cy - 5)
            cv.p(cx + 6, cy + 3, C)
    cv.rect(31, 52, 32, 61, N)
    cv.rect(31, 53, 32, 60, C if on else TB)
    return cv.img


# ---------------------------------------------------------- plataforma que parpadea
def _seg_x0(w):
    total = SEG_COUNT * 10 + (SEG_COUNT - 1) * 4
    return (w - total) // 2


def blink_on(n, lit):
    w = 64 * n
    cv = Canvas(w, BLINK_H)
    cv.box(0, 0, w - 1, BLINK_H - 1, TL)
    cv.rect(1, 1, w - 2, 3, BL)
    cv.hline(2, w - 3, 1, W)
    cv.hline(1, w - 2, BLINK_H - 2, TB)
    cv.vline(w - 2, 4, BLINK_H - 2, TB)
    x0 = _seg_x0(w)
    for i in range(SEG_COUNT):
        sx = x0 + i * 14
        cv.rect(sx - 1, 13, sx + 10, 22, N)
        if i < lit:
            cv.rect(sx, 14, sx + 9, 21, BL)
            cv.hline(sx, sx + 9, 14, W)
        else:
            cv.rect(sx, 14, sx + 9, 21, TS)
    if n >= 2:  # marcas de vibracion en los extremos
        for side in (0, 1):
            bx = 6 if side == 0 else w - 10
            for k in range(2):
                x = bx + k * 2 if side == 0 else bx + 2 - k * 2
                cv.vline(x, 12 + k, 23 - k, TB)
                cv.p(x, 12 + k, G)
    return cv.img


def blink_warn(n):
    w = 64 * n
    cv = Canvas(w, BLINK_H)
    cv.rect(0, 0, w - 1, BLINK_H - 1, N)
    cv.rect(2, 2, w - 3, BLINK_H - 3, CLEAR)
    cv.rect(1, 1, w - 2, 1, BL)
    cv.rect(1, BLINK_H - 2, w - 2, BLINK_H - 2, BL)
    cv.vline(1, 1, BLINK_H - 2, BL)
    cv.vline(w - 2, 1, BLINK_H - 2, BL)
    for (x, y) in ((0, 0), (w - 1, 0), (0, BLINK_H - 1), (w - 1, BLINK_H - 1)):
        cv.p(x, y, CLEAR)
    return cv.img


def blink_off(n):
    w = 64 * n
    cv = Canvas(w, BLINK_H)
    on_len, period = 6, 10
    for x in range(1, w - 1):
        if (x - 1) % period < on_len:
            cv.rect(x, 0, x, 1, R)
            cv.rect(x, BLINK_H - 2, x, BLINK_H - 1, R)
    for y in range(1, BLINK_H - 1):
        if (y - 1) % period < on_len:
            cv.rect(0, y, 1, y, R)
            cv.rect(w - 2, y, w - 1, y, R)
    return cv.img


# ------------------------------------------------------------- icono del metronomo
def rhythm_icon(lit):
    """Icono del metronomo como parte del FONDO (2026-10-20): el celular se dibuja
    como los rotulos del fondo (relleno fondo_medio, contorno resplandor, pantalla
    en cielo), sin el cuerpo metalico banner_gris ni el contorno noche_profunda de
    los objetos, para que no parezca algo que se recoge. Encendido, solo el
    contorno, la pantalla y los arcos se iluminan."""
    cv = Canvas(64, 64)
    cx, cy = 32, 32
    edge = BL if lit else R
    # celular 20x36: cuerpo plano con contorno de 1 px, sin sombra
    cv.rect(cx - 10, cy - 18, cx + 9, cy + 17, edge)
    cv.rect(cx - 9, cy - 17, cx + 8, cy + 16, FM)
    cv.rect(cx - 7, cy - 14, cx + 6, cy + 9, R if lit else PAL["cielo"])
    if lit:
        cv.hline(cx - 5, cx + 4, cy - 8, BL)
        cv.hline(cx - 5, cx + 1, cy - 5, BL)
    cv.hline(cx - 4, cx + 3, cy + 13, edge)
    cv.hline(cx - 3, cx + 2, cy - 16, edge)
    color = BL if lit else FM
    for side in (-1, 1):
        ox = cx + side * (6 if lit else 4)
        for r in (18, 25):
            for y in range(-r - 2, r + 3):
                for x in range(-r - 2, r + 3):
                    d = math.hypot(x + 0.5, y + 0.5)
                    if not (r - 1 <= d < r + 1):
                        continue
                    ang = math.atan2(y + 0.5, (x + 0.5) * side)
                    if abs(ang) <= 0.55:
                        cv.p(ox + x, cy + y, W if lit and abs(ang) < 0.12 else color)
    return cv.img


# ------------------------------------------------------------------- campana de alarma
def bell(cv, dx, clapper):
    """Campana en un lienzo de 64x64 (la celda), colgada del techo (y = 0)."""
    cx = 32 + dx
    cv.rect(cx - 9, 0, cx + 8, 3, N)
    cv.rect(cx - 8, 0, cx + 7, 2, TL)
    cv.rect(cx - 2, 4, cx + 1, 7, N)
    cv.rect(cx - 1, 4, cx, 7, G)
    rows = []
    for y in range(8, 33):
        t = (y - 8) / 24.0
        half = int(round(6 + 9 * t ** 1.4))
        if y >= 30:
            half = 17
        rows.append((y, half))
    for y, half in rows:
        cv.hline(cx - half - 1, cx + half, y, N)
    for y, half in rows[1:-1]:
        cv.hline(cx - half, cx + half - 1, y, G)
        cv.hline(cx + half - 4, cx + half - 1, y, TL)       # sombra a la derecha
        if y < 28:
            cv.p(cx - half + 2, y, W)                         # brillo a la izquierda
    cv.hline(cx - 6, cx + 5, 8, N)
    cv.hline(cx - 16, cx + 15, 30, BL)                         # labio
    cv.hline(cx - 17, cx + 16, 33, N)
    # badajo
    disc(cv, cx, 36, 3, N)
    disc(cv, cx, 36, 2, clapper)
    if clapper == A:
        cv.p(cx - 1, 35, W)


def bell_rest():
    cv = Canvas(64, 64)
    bell(cv, 0, AS)
    return cv.img


def bell_warn(f):
    cv = Canvas(64, 64)
    dx = -2 if f == 0 else 2
    bell(cv, dx, A)
    # marcas de temblor al lado contrario al desplazamiento
    side = 1 if f == 0 else -1
    bx = 32 + dx + side * 21
    for k, y in enumerate((14, 20, 26)):
        cv.hline(min(bx, bx + side * (2 + k % 2)), max(bx, bx + side * (2 + k % 2)), y, A)
    return cv.img


def bell_ring(f):
    cv = Canvas(64, 64)
    bell(cv, 0, A)
    for side in (-1, 1):
        for r in ((22, 28) if f == 0 else (25, 31)):
            for y in range(-r - 2, r + 3):
                for x in range(-r - 2, r + 3):
                    d = math.hypot(x + 0.5, y + 0.5)
                    if r - 0.5 <= d < r + 0.5:
                        ang = math.atan2(y + 0.5, (x + 0.5) * side)
                        if abs(ang) <= 0.35:
                            cv.p(32 + x, 20 + y, W if r < 26 else A)
    return cv.img


def alarm_wave(f):
    cv = Canvas(48, 64)
    cv.rect(0, 0, 47, 63, A)
    cv.rect(6, 0, 41, 63, AS)
    off = 0 if f == 0 else 8
    for base in range(-16, 64, 16):
        top = base + off
        for k in range(10):
            for t in range(3):
                y = (top + (9 - k) + t) % 64
                if 0 <= y < 64:
                    cv.p(23 - k, y, W)
                    cv.p(24 + k, y, W)
    return cv.img


def alarm_warn_line():
    cv = Canvas(64, 8)
    for x0 in range(0, 64, 16):
        cv.rect(x0 + 2, 2, x0 + 11, 5, AS)
        cv.hline(x0 + 2, x0 + 11, 2, A)
    return cv.img


# ------------------------------------------------------------- panel «Excepciones»
def exceptions_frame():
    cv = Canvas(24, 24)
    cv.rect(0, 0, 23, 23, N)
    cv.rect(1, 1, 22, 22, TL)
    cv.hline(1, 22, 1, BL)
    cv.rect(3, 3, 20, 20, TB)
    cv.hline(3, 20, 3, TS)
    cv.hline(1, 22, 22, TS)
    for (x, y) in ((0, 0), (23, 0), (0, 23), (23, 23)):
        cv.p(x, y, CLEAR)
    return cv.img


def exceptions_contact():
    cv = Canvas(16, 16)
    disc(cv, 8, 5, 4, N)
    disc(cv, 8, 5, 3, G)
    cv.p(7, 3, W)
    for y, half in ((10, 5), (11, 6), (12, 7), (13, 7), (14, 7)):
        cv.hline(8 - half - 1, 8 + half, y, N)
    for y, half in ((11, 5), (12, 6), (13, 6)):
        cv.hline(8 - half, 8 + half - 1, y, G)
    cv.hline(4, 6, 11, W)
    cv.hline(1, 15, 15, CLEAR)
    cv.hline(2, 14, 14, N)
    return cv.img


def exceptions_star():
    cv = Canvas(16, 16)
    mask = Image.new("L", (16, 16), 0)
    pts = []
    for k in range(10):
        r = 7.2 if k % 2 == 0 else 3.0
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((7.5 + math.cos(a) * r, 8.2 + math.sin(a) * r))
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    for y in range(16):
        for x in range(16):
            if mask.getpixel((x, y)):
                cv.p(x, y, BL)
    cv.halo(N)
    cv.p(7, 4, W)
    cv.p(7, 5, W)
    cv.p(6, 7, W)
    return cv.img


# --------------------------------------------------------------------- dash
def dash_trail(f):
    cv = Canvas(32, 4)
    off = 0 if f == 0 else 8
    for x in range(32):
        xx = (x + off) % 32
        if xx % 16 in (13, 14):        # huecos de la linea de datos
            continue
        cv.p(x, 0, BL)
        cv.p(x, 1, R)
        cv.p(x, 2, R)
    for xx in (4, 20):                 # bits de datos que brillan
        x = (xx - off) % 32
        cv.p(x, 1, W)
    for xx in (9, 26):
        x = (xx - off) % 32
        cv.p(x, 3, FM)
    return cv.img


def banner_dash_card():
    base = Image.open(os.path.join(REPO, "assets/sprites", BANNER_SRC)).convert("RGBA")
    cv = Canvas(128, 64)
    cv.img.alpha_composite(base)
    cv.px = cv.img.load()
    # techo bajo justo encima del banner
    top = min(y for y in range(64) for x in range(128) if base.getpixel((x, y))[3] == 255)
    cv.rect(0, max(top - 6, 0), 127, top - 2, N)
    cv.rect(0, max(top - 6, 0), 127, top - 4, TL)
    cv.hline(0, 127, top - 4, BL)
    # estela del dash que lo atraviesa: una banda de datos a la altura del pecho
    for i, (y, x0, x1) in enumerate(((30, 0, 127), (37, 16, 112))):
        for x in range(x0, x1 + 1):
            if (x + i * 7) % 24 in (20, 21):
                continue
            cv.p(x, y - 1, N)
            cv.p(x, y, BL)
            cv.p(x, y + 1, R)
            cv.p(x, y + 2, R)
            cv.p(x, y + 3, N)
    return cv.img


# --------------------------------------------------------------------- salidas
def outputs():
    out = {}
    for anim, prefix, n, _fps, _loop in SWITCH_ANIMS:
        state = anim.rsplit("_", 1)[1]
        for f in range(n):
            out[f"{prefix}_{f:02d}.png"] = dnd_switch(state, f)
    for n in BLINK_WIDTHS:
        for k in range(SEG_COUNT + 1):
            out[f"props/dnd/blink_w{n}_on_{k:02d}.png"] = blink_on(n, k)
        out[f"props/dnd/blink_w{n}_warn_00.png"] = blink_warn(n)
        out[f"props/dnd/blink_w{n}_off_00.png"] = blink_off(n)
    out["props/dnd/rhythm_icon_dim_00.png"] = rhythm_icon(False)
    out["props/dnd/rhythm_icon_lit_00.png"] = rhythm_icon(True)
    out["props/dnd/exceptions_frame_00.png"] = exceptions_frame()
    out["props/dnd/exceptions_contact_00.png"] = exceptions_contact()
    out["props/dnd/exceptions_star_00.png"] = exceptions_star()
    for f in range(2):
        out[f"props/dnd/dash_trail_{f:02d}.png"] = dash_trail(f)
    out["props/dnd/banner_dash_card_00.png"] = banner_dash_card()
    out["enemies/alarm_bell/alarm_bell_rest_00.png"] = bell_rest()
    for f in range(2):
        out[f"enemies/alarm_bell/alarm_bell_warn_{f:02d}.png"] = bell_warn(f)
        out[f"enemies/alarm_bell/alarm_bell_ring_{f:02d}.png"] = bell_ring(f)
        out[f"enemies/alarm_bell/alarm_wave_{f:02d}.png"] = alarm_wave(f)
    out["enemies/alarm_bell/alarm_warn_line_00.png"] = alarm_warn_line()
    return out


def frames_resource():
    return sprite_frames_tres([
        (anim, ["res://assets/sprites/%s_%02d.png" % (prefix, i) for i in range(n)], fps, loop)
        for anim, prefix, n, fps, loop in SWITCH_ANIMS])


def preview(imgs, path, scale=4):
    bg = PAL["cielo"]
    pad = 6
    rows = {}
    for k, im in imgs.items():
        rows.setdefault(os.path.dirname(k) + "/" + os.path.basename(k).split("_")[0], []).append(im)
    width = max(sum(im.width + pad for im in ims) for ims in rows.values()) + pad
    height = sum(max(im.height for im in ims) + pad for ims in rows.values()) + pad
    sheet = Image.new("RGBA", (width, height), bg)
    y = pad
    for ims in rows.values():
        x = pad
        for im in ims:
            sheet.alpha_composite(im, (x, y))
            x += im.width + pad
        y += max(im.height for im in ims) + pad
    sheet.resize((width * scale, height * scale), Image.NEAREST).save(path)


if __name__ == "__main__":
    imgs = outputs()
    dest = os.path.join(REPO, "assets/sprites")
    if "--dry-run" not in sys.argv:
        for k, im in imgs.items():
            p = os.path.join(dest, k)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            im.save(p)
        with open(os.path.join(dest, FRAMES_TRES), "w", encoding="utf-8") as fh:
            fh.write(frames_resource())
    if "--preview" in sys.argv:
        preview(imgs, sys.argv[sys.argv.index("--preview") + 1],
                int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 4)
    print(f"{len(imgs)} PNG + {FRAMES_TRES}")
