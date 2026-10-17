#!/usr/bin/env python3
"""Genera el arte de los objetos de los pisos 3 y 4 del 1-2 (pasos 6, 7 y 8 de
docs/propuesta-1-2.md §10; §3.1, §3.3, §3.4 y §7): recordatorio, boton Posponer,
pop-up translucido y barra de actualizacion del 99 % con sus oleadas.

Estilo circuito limpio, como tools/gen_world1_puzzle.py. Solo colores de
assets/palettes/mundo1.gpl + assets/palettes/effects_pulse.gpl y SIN rojos ni
ambar (alerta, alerta_sombra, carmin, carmin_brillo, ambar, ambar_sombra), salvo
la flecha que anuncia la caida de enemigos (effects/drop_arrow: rojo alerta, es un
aviso de amenaza). El cian es el Debug y lo interactivo (el boton Posponer, el
boton de cerrar). Fondo transparente, alfa 0 o 255: la translucidez del pop-up la
pone el juego con modulate.

Salidas (rutas relativas a assets/sprites/props/tower/):
  reminder_w{1,2,3}_idle_00..01.png     64w x 32  recordatorio de w tiles: tarjeta
                                                  con cabecera, despertador y ranura
                                                  del temporizador (los segmentos los
                                                  dibuja el juego)
  reminder_w{1,2,3}_warn_00..01.png     64w x 32  aviso antes de caer (el despertador
                                                  suena; el juego lo hace temblar)
  reminder_w{1,2,3}_fall_00..02.png     64w x 32  caida: se agrieta, se parte, trozos
  reminder_w{1,2,3}_respawn_00..02.png  64w x 32  repuesto: contorno, relleno, entero
  reminder_seg_00..02.png               8x5       segmento del temporizador: apagado,
                                                  encendido, aviso
  reminder_zz_00..01.png                16x16     «Zz» sobre el recordatorio pospuesto
  snooze_wait_00.png                    48x48     boton Posponer sin cuenta que posponer
  snooze_ready_00..01.png               48x48     listo (su grupo cuenta): diana cian
  snooze_hit_00..02.png                 48x48     golpeado: «Zzz» que sale volando
  snooze_cooldown_00..03.png            48x48     enfriamiento (cuadros de progreso)
  overlay_frame_00.png                  48x48     ventana del pop-up translucido
                                                  (nine-patch: 4 px, cabecera de 16)
  overlay_frame_debug_00.png            48x48     la misma vista con el Debug: solo
                                                  contorno cian discontinuo (nine-patch)
  overlay_close_00..02.png              24x24     boton de cerrar: normal, brillo, golpe
  overlay_bell_00.png                   12x12     icono de la cabecera
  overlay_sample_00.png                 64x48     ventana en miniatura (ficha del album)
  update_bar_progress_00..01.png        64x192    barra de actualizacion subiendo
  update_bar_stuck_00..03.png           64x192    trabada en el 99 % (el hueco parpadea,
                                                  la rueda gira)
  update_bar_full_00..01.png            64x192    llena (100 %)
  update_bar_open_00..03.png            64x192    completada: se recoge hacia el techo
  package_fall_00..01.png               32x32     paquete que cae del techo
  package_open_00..02.png               32x32     el paquete se abre (sale el enemigo)
  drop_arrow_00..01.png                 32x32     flecha roja de aviso en el techo
  drop_shadow_00..01.png                48x12     sombra en el suelo donde caera
  tower_objects_frames.tres (en assets/sprites/)  SpriteFrames con todas las
                                                  animaciones (nombres = prefijos)

Uso (desde la raiz del repo):
  python3 tools/gen_world1_tower.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_world1_tower.py (en tools/run_tests.sh).
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, Canvas, REPO  # noqa: E402
from gen_hub_objects import sprite_frames_tres  # noqa: E402
from PIL import Image  # noqa: E402

N = PAL["noche_profunda"]
TS = PAL["tile_sombra"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]
BL = PAL["borde_luz"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
R = PAL["resplandor"]
FM = PAL["fondo_medio"]
SKY = PAL["cielo"]
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]
A = PAL["alerta"]
AS = PAL["alerta_sombra"]
CLEAR = (0, 0, 0, 0)

# Colores prohibidos en este arte (validador). RED_ALLOWED: los unicos dibujos que
# pueden usar el rojo alerta (avisan de una amenaza).
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra")
RED_ALLOWED = ("drop_arrow",)
RED_NAMES = ("alerta", "alerta_sombra")

# Dibujos opacos enteros (sin fondo transparente): segmentos y ventana del nine-patch.
OPAQUE = ("reminder_seg_", "overlay_frame_00")

SUB = "props/tower"
# (animacion, prefijo, cuadros, fps, bucle) del SpriteFrames.
ANIMS = []
for _w in (1, 2, 3):
    ANIMS += [
        ("reminder_w%d_idle" % _w, "%s/reminder_w%d_idle" % (SUB, _w), 2, 2.0, True),
        ("reminder_w%d_warn" % _w, "%s/reminder_w%d_warn" % (SUB, _w), 2, 12.0, True),
        ("reminder_w%d_fall" % _w, "%s/reminder_w%d_fall" % (SUB, _w), 3, 12.0, False),
        ("reminder_w%d_respawn" % _w, "%s/reminder_w%d_respawn" % (SUB, _w), 3, 12.0, False),
    ]
ANIMS += [
    ("reminder_seg", SUB + "/reminder_seg", 3, 1.0, False),
    ("reminder_zz", SUB + "/reminder_zz", 2, 4.0, True),
    ("snooze_wait", SUB + "/snooze_wait", 1, 1.0, True),
    ("snooze_ready", SUB + "/snooze_ready", 2, 3.0, True),
    ("snooze_hit", SUB + "/snooze_hit", 3, 12.0, False),
    ("snooze_cooldown", SUB + "/snooze_cooldown", 4, 1.0, False),
    ("overlay_frame", SUB + "/overlay_frame", 1, 1.0, True),
    ("overlay_frame_debug", SUB + "/overlay_frame_debug", 1, 1.0, True),
    ("overlay_close", SUB + "/overlay_close", 3, 1.0, False),
    ("overlay_bell", SUB + "/overlay_bell", 1, 1.0, True),
    ("overlay_sample", SUB + "/overlay_sample", 1, 1.0, True),
    ("update_bar_progress", SUB + "/update_bar_progress", 2, 6.0, True),
    ("update_bar_stuck", SUB + "/update_bar_stuck", 4, 6.0, True),
    ("update_bar_full", SUB + "/update_bar_full", 2, 6.0, True),
    ("update_bar_open", SUB + "/update_bar_open", 4, 12.0, False),
    ("package_fall", SUB + "/package_fall", 2, 8.0, True),
    ("package_open", SUB + "/package_open", 3, 12.0, False),
    ("drop_arrow", SUB + "/drop_arrow", 2, 12.0, True),
    ("drop_shadow", SUB + "/drop_shadow", 2, 12.0, True),
]
FRAMES_TRES = "tower_objects_frames.tres"
SIZES = {
    "reminder_w1": (64, 32), "reminder_w2": (128, 32), "reminder_w3": (192, 32),
    "reminder_seg": (8, 5), "reminder_zz": (16, 16),
    "snooze": (48, 48),
    "overlay_frame": (48, 48), "overlay_close": (24, 24), "overlay_bell": (12, 12), "overlay_sample": (64, 48),
    "update_bar": (64, 192),
    "package": (32, 32), "drop_arrow": (32, 32), "drop_shadow": (48, 12),
}

GLYPHS = {
    "Z": ["####", "...#", "..#.", ".#..", "####"],
    "z": ["###", "..#", ".#.", "###"],
}

# Ranura del temporizador del recordatorio: segmentos de 8x5 cada 10 px desde
# (SEG_X0, SEG_Y). El juego los dibuja encima de la tarjeta (data/world1_objects.json).
SEG_X0, SEG_Y, SEG_STEP, SEG_COUNT = 23, 14, 9, 4


def stamp(cv, ox, oy, rows, color):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                cv.p(ox + i, oy + j, color)


def stamp_outlined(cv, ox, oy, rows, color, outline):
    pts = {(ox + i, oy + j) for j, row in enumerate(rows) for i, ch in enumerate(row) if ch == "#"}
    for (x, y) in pts:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in pts:
                    cv.p(x + dx, y + dy, outline)
    for (x, y) in pts:
        cv.p(x, y, color)


def disc(cv, cx, cy, r, color):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r:
                cv.p(x, y, color)


def circle(cv, cx, cy, r, color, keep=None):
    """Circunferencia de 1 px (radio r); keep(angulo_en_cuartos) filtra arcos."""
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if r * r - r <= d2 <= r * r + r:
                if keep is None or keep(x - cx, y - cy):
                    cv.p(x, y, color)


# ------------------------------------------------------- recordatorio (64w x 32)
def clock(cv, cx, cy, face, rim, hand, ring=False):
    """Despertador de 13 px: dos campanas arriba, esfera y agujas."""
    for bx in (cx - 4, cx + 4):
        cv.rect(bx - 1, cy - 7, bx + 1, cy - 6, rim)
    disc(cv, cx, cy, 6, N)
    disc(cv, cx, cy, 5, rim)
    disc(cv, cx, cy, 3, face)
    cv.vline(cx, cy - 3, cy, hand)
    cv.hline(cx, cx + 2, cy, hand)
    cv.rect(cx - 3, cy + 6, cx - 2, cy + 7, N)
    cv.rect(cx + 2, cy + 6, cx + 3, cy + 7, N)
    if ring:  # ondas de sonido a los lados
        for (x, dir_) in ((cx - 9, -1), (cx + 9, 1)):
            cv.vline(x, cy - 2, cy + 2, hand)
            cv.p(x + dir_, cy - 4, hand)
            cv.p(x + dir_, cy + 4, hand)


def reminder_card(cv, w, header=FM, body=W, shade=G, face=W, rim=FM, hand=N, ring=False, lines=G):
    width = 64 * w
    cv.box(0, 0, width - 1, 31, body)
    cv.rect(1, 1, width - 2, 5, header)
    cv.hline(1, width - 2, 6, N)
    # puntos de la cabecera (como una notificacion)
    for x in range(4, 10, 3):
        cv.p(x, 3, BL)
    cv.hline(1, width - 2, 29, shade)
    cv.hline(1, width - 2, 30, shade)
    clock(cv, 11, 18, face, rim, hand, ring)
    # ranura del temporizador
    x1 = SEG_X0 + SEG_STEP * (SEG_COUNT - 1) + 8
    cv.rect(SEG_X0 - 2, SEG_Y - 2, x1 + 1, SEG_Y + 6, N)
    cv.hline(SEG_X0 - 1, x1, SEG_Y + 6, TB)
    # lineas de texto falso en las demas casillas
    for k in range(1, w):
        x0 = 64 * k + 4
        cv.hline(x0, x0 + 44, 12, lines)
        cv.hline(x0, x0 + 30, 17, lines)
        cv.hline(x0, x0 + 38, 22, lines)


def reminder(w, state, f=0):
    cv = Canvas(64 * w, 32)
    if state == "idle":
        reminder_card(cv, w, hand=N if f == 0 else FM, rim=FM if f == 0 else R)
    elif state == "warn":
        if f == 0:
            reminder_card(cv, w, ring=True)
        else:
            reminder_card(cv, w, header=R, body=BL, shade=TL, face=W, rim=W, hand=N, ring=True, lines=TL)
    elif state == "fall":
        width = 64 * w
        if f == 0:      # grieta en zigzag desde el centro de arriba
            reminder_card(cv, w, body=W)
            x = width // 2
            for y in range(1, 31):
                cv.p(x, y, N)
                x += 1 if (y // 3) % 2 == 0 else -1
            cv.sparkle(width // 2, 2, core=W, arm=BL)
        else:
            src = Canvas(64 * w, 32)
            reminder_card(src, w, body=G if f == 1 else TL, header=TL if f == 1 else TB,
                          shade=TL if f == 1 else TB, lines=TL if f == 1 else TB)
            half = width // 2
            dy_l, dy_r = (2, 4) if f == 1 else (6, 10)
            left = src.img.crop((0, 0, half - 1, 32 - dy_r))
            right = src.img.crop((half + 1, 0, width, 32 - dy_r))
            if f == 1:
                cv.img.paste(left, (0, dy_l), left)
                cv.img.paste(right, (half + 1, dy_r), right)
            else:       # trozos que caen
                for i, (x0, w0) in enumerate(((0, half // 2), (half // 2 + 3, half // 2 - 3),
                                              (half + 2, half // 2), (half + half // 2 + 4, half // 2 - 4))):
                    piece = src.img.crop((x0, 8, x0 + w0, 20))
                    cv.img.paste(piece, (x0, 12 + (i % 2) * 6), piece)
            cv.px = cv.img.load()
    else:  # respawn
        width = 64 * w
        if f == 0:      # contorno discontinuo
            for x in range(0, width):
                if x % 4 < 2:
                    cv.p(x, 0, BL)
                    cv.p(x, 31, BL)
            for y in range(0, 32):
                if y % 4 < 2:
                    cv.p(0, y, BL)
                    cv.p(width - 1, y, BL)
        elif f == 1:    # contorno y relleno a medias (damero)
            cv.rect(0, 0, width - 1, 31, BL)
            cv.rect(1, 1, width - 2, 30, CLEAR)
            cv.rect(1, 1, width - 2, 5, FM)
            for y in range(7, 31):
                for x in range(1, width - 1):
                    if (x + y) % 2 == 0:
                        cv.p(x, y, W)
        else:
            reminder_card(cv, w)
            cv.sparkle(3, 3, core=CC, arm=W)
            cv.sparkle(width - 4, 27, core=CC, arm=W)
    return cv.img


def reminder_seg(f):
    cv = Canvas(8, 5)
    cv.rect(0, 0, 7, 4, (TL, W, BL)[f])
    if f == 1:
        cv.hline(0, 7, 4, G)
    return cv.img


def reminder_zz(f):
    cv = Canvas(16, 16)
    oy = 1 if f == 0 else 0
    stamp_outlined(cv, 2, 7 + oy, GLYPHS["Z"], W, N)
    stamp_outlined(cv, 9, 2 + oy, GLYPHS["z"], W, N)
    return cv.img


# ------------------------------------------------------ boton Posponer (48x48)
def snooze_plate(cv):
    cv.box(4, 4, 43, 43, TL)
    cv.hline(5, 42, 5, BL)
    cv.vline(5, 6, 42, BL)
    cv.hline(6, 42, 42, TB)
    cv.vline(42, 6, 42, TB)
    for (x, y) in ((7, 7), (40, 7), (7, 40), (40, 40)):
        cv.p(x, y, G)


def snooze(state, f=0):
    cv = Canvas(48, 48)
    snooze_plate(cv)
    cx, cy = 24, 24
    if state == "wait":
        circle(cv, cx, cy, 15, TB, keep=lambda x, y: (x + y) % 2 == 0)
        disc(cv, cx, cy, 11, N)
        disc(cv, cx, cy, 10, G)
        disc(cv, cx, cy, 8, BL)
        stamp(cv, cx - 5, cy - 1, GLYPHS["Z"], TL)
        stamp(cv, cx + 1, cy - 5, GLYPHS["z"], TL)
    elif state == "ready":
        circle(cv, cx, cy, 15, C if f == 0 else CC)
        circle(cv, cx, cy, 14, CD)
        disc(cv, cx, cy, 11, N)
        disc(cv, cx, cy, 10, W)
        disc(cv, cx, cy, 8, W if f == 0 else CC)
        stamp(cv, cx - 5, cy - 1, GLYPHS["Z"], FM)
        stamp(cv, cx + 1, cy - 5, GLYPHS["z"], FM)
        if f == 1:
            cv.sparkle(9, 9, big=True)
    elif state == "hit":
        circle(cv, cx, cy, 15, CC if f == 0 else C)
        disc(cv, cx, cy, 11, N)
        disc(cv, cx, cy, 10, C if f == 0 else W)
        disc(cv, cx, cy + 1, 8, CC if f == 0 else C)
        # «Zzz» que sale volando hacia arriba a la derecha
        zs = ((cx - 4, cy - 2), (cx + 4, cy - 10), (cx + 10, cy - 17))
        for k, (x, y) in enumerate(zs[:f + 1]):
            glyph = GLYPHS["Z"] if k == f else GLYPHS["z"]
            stamp_outlined(cv, x + f * 2, y - f * 2, glyph, W, N)
        if f == 0:
            cv.sparkle(cx, cy, core=W, arm=CC, big=True)
        else:
            cv.sparkle(8, 12 + f * 4, core=CC, arm=CD)
    else:  # cooldown: el anillo se rellena por cuartos (f + 1 de 4 encendidos al acabar)
        quarters = f
        def lit(x, y):
            q = (0 if x >= 0 and y < 0 else 1 if x > 0 and y >= 0 else 2 if x <= 0 and y > 0 else 3)
            return q < quarters
        circle(cv, cx, cy, 15, TB, keep=lambda x, y: not lit(x, y))
        circle(cv, cx, cy, 15, C, keep=lit)
        disc(cv, cx, cy, 11, N)
        disc(cv, cx, cy, 10, G)
        disc(cv, cx, cy, 8, BL)
        stamp(cv, cx - 5, cy - 1, GLYPHS["Z"], TL)
        stamp(cv, cx + 1, cy - 5, GLYPHS["z"], TL)
    return cv.img


# --------------------------------------------------- pop-up translucido (48x48)
def overlay_frame(debug=False):
    cv = Canvas(48, 48)
    if debug:
        # contorno discontinuo (periodo 4, encaja al repetir los bordes) y esquinas
        for x in range(48):
            if x % 4 < 2:
                cv.p(x, 0, C)
                cv.p(x, 47, C)
                cv.p(x, 15, CD)
        for y in range(48):
            if y % 4 < 2:
                cv.p(0, y, C)
                cv.p(47, y, C)
        for (x0, y0, sx, sy) in ((0, 0, 1, 1), (47, 0, -1, 1), (0, 47, 1, -1), (47, 47, -1, -1)):
            for i in range(4):
                cv.p(x0 + sx * i, y0, CC)
                cv.p(x0, y0 + sy * i, CC)
        return cv.img
    cv.rect(0, 0, 47, 47, N)
    cv.rect(1, 1, 46, 46, G)
    cv.rect(2, 2, 45, 13, FM)
    cv.hline(2, 45, 14, R)
    cv.hline(1, 46, 15, N)
    cv.rect(2, 16, 45, 44, W)
    cv.hline(2, 45, 45, G)
    return cv.img


def overlay_close(f):
    cv = Canvas(24, 24)
    if f == 1:
        cv.box(2, 2, 21, 21, CD, outline=C)
    cv.box(4, 4, 19, 19, (FM, R, C)[f])
    xcol = W
    for i in range(8):
        cv.p(8 + i, 8 + i, xcol)
        cv.p(15 - i, 8 + i, xcol)
        cv.p(9 + i, 8 + i, xcol)
        cv.p(14 - i, 8 + i, xcol)
    if f == 2:
        cv.sparkle(3, 3, core=W, arm=CC)
        cv.sparkle(20, 20, core=W, arm=CC)
    return cv.img


def overlay_bell(_f=0):
    cv = Canvas(12, 12)
    rows = ["....##....",
            "...####...",
            "..######..",
            "..######..",
            "..######..",
            ".########.",
            "##########",
            "....##....", ]
    stamp(cv, 1, 1, rows, W)
    return cv.img


def overlay_sample(_f=0):
    cv = Canvas(64, 48)
    frame = overlay_frame()
    # esquinas y bordes del nine-patch estirado a 64x48 (relleno plano)
    cv.img.paste(frame.crop((0, 0, 24, 48)), (0, 0))
    cv.img.paste(frame.crop((24, 0, 48, 48)), (40, 0))
    cv.img.paste(frame.crop((20, 0, 28, 48)).resize((16, 48), Image.NEAREST), (24, 0))
    cv.px = cv.img.load()
    cv.img.alpha_composite(overlay_bell(), (3, 2))
    for y, n in ((21, 40), (26, 30), (31, 36)):
        cv.hline(6, 6 + n, y, G)
    close = overlay_close(0).crop((4, 4, 20, 20))
    cv.img.paste(close, (44, 28))
    cv.px = cv.img.load()
    return cv.img


# --------------------------------------------- barra de actualizacion (64x192)
GX0, GX1, GY0, GY1 = 22, 41, 26, 181  # hueco del indicador (interior)


def bar_housing(cv):
    cv.box(4, 0, 59, 191, TB)
    cv.vline(5, 1, 190, TL)
    cv.hline(5, 58, 1, TL)
    cv.vline(58, 2, 190, TS)
    # remaches
    for y in (8, 96, 184):
        cv.p(10, y, G)
        cv.p(53, y, G)
    # cabecera con la pantallita de la rueda
    cv.box(16, 6, 47, 19, N, outline=TL)
    # indicador
    cv.rect(GX0 - 1, GY0 - 1, GX1 + 1, GY1 + 1, N)
    cv.rect(GX0, GY0, GX1, GY1, TS)
    # marcas de escala a los lados
    for y in range(GY0 + 8, GY1, 16):
        cv.hline(GX0 - 5, GX0 - 3, y, TL)
        cv.hline(GX1 + 3, GX1 + 5, y, TL)


def bar_fill(cv, fraction, phase, full=False):
    height = GY1 - GY0 + 1
    top = GY1 + 1 - int(round(height * fraction))
    for y in range(top, GY1 + 1):
        for x in range(GX0, GX1 + 1):
            if full:
                col = CC if (y + phase * 3) % 12 < 2 else C
            else:
                col = R if ((x + y + phase * 4) // 4) % 2 == 0 else FM
            cv.p(x, y, col)
    if top <= GY1:
        cv.hline(GX0, GX1, top, W if full else BL)
    return top


def spinner(cv, f, color):
    cx, cy = 31, 12
    pts = [(cx - 4, cy), (cx, cy - 3), (cx + 4, cy), (cx, cy + 3)]
    for i, (x, y) in enumerate(pts):
        cv.rect(x, y, x + 1, y + 1, color if i == f % 4 else TL)


def update_bar(state, f=0):
    cv = Canvas(64, 192)
    bar_housing(cv)
    if state == "progress":
        bar_fill(cv, 0.97, f)
        spinner(cv, f * 2, BL)
    elif state == "stuck":
        top = bar_fill(cv, 0.99, 0)
        # el hueco del 1 % parpadea
        cv.rect(GX0, GY0, GX1, top - 1, BL if f % 2 == 0 else TS)
        spinner(cv, f, W)
        # puntos suspensivos bajo la cabecera
        for k in range(3):
            cv.p(27 + k * 4, 22, W if k <= f % 3 else TL)
    elif state == "full":
        bar_fill(cv, 1.0, f, full=True)
        cv.box(16, 6, 47, 19, C, outline=TL)
        cv.rect(29, 10, 34, 15, CC)
        if f == 1:
            cv.sparkle(10, 30, core=W, arm=CC, big=True)
    else:  # open: se recoge hacia el techo
        full = Canvas(64, 192)
        bar_housing(full)
        bar_fill(full, 1.0, 0, full=True)
        cut = (f + 1) * 44
        cv.img = Image.new("RGBA", (64, 192), CLEAR)
        piece = full.img.crop((0, cut, 64, 192))
        cv.img.paste(piece, (0, 0), piece)
        cv.px = cv.img.load()
        # borde de abajo de la puerta recogida
        h = 192 - cut
        if h > 2:
            cv.hline(4, 59, h - 1, N)
            cv.hline(5, 58, h - 2, BL)
        cv.sparkle(8 + f * 12, min(h + 4, 186), core=CC, arm=CD)
    return cv.img


# --------------------------------------------------------- oleadas (paquetes)
def package_box(cv, ox, oy, lid_dy=0):
    cv.box(ox + 4, oy + 10, ox + 27, oy + 29, W)
    cv.hline(ox + 5, ox + 26, oy + 28, G)
    cv.vline(ox + 26, oy + 11, oy + 28, G)
    # tapa
    cv.box(ox + 2, oy + 6 - lid_dy, ox + 29, oy + 11 - lid_dy, G)
    cv.hline(ox + 3, ox + 28, oy + 7 - lid_dy, W)
    # cinta y flecha de descarga
    cv.vline(ox + 15, oy + 12, oy + 27, BL)
    cv.vline(ox + 16, oy + 12, oy + 27, BL)
    cv.rect(ox + 14, oy + 15, ox + 17, oy + 20, FM)
    cv.hline(ox + 12, ox + 19, oy + 21, FM)
    cv.hline(ox + 13, ox + 18, oy + 22, FM)
    cv.hline(ox + 14, ox + 17, oy + 23, FM)


def package(state, f=0):
    cv = Canvas(32, 32)
    if state == "fall":
        package_box(cv, 0, 0 if f == 0 else 1)
        # lineas de velocidad arriba
        for x in (8, 16, 23):
            cv.vline(x, 0, 3 - f, BL)
    else:
        if f == 0:
            package_box(cv, 0, 0, lid_dy=5)
            cv.sparkle(16, 4, core=W, arm=BL, big=True)
        elif f == 1:
            cv.box(4, 16, 27, 29, W)
            cv.hline(5, 26, 28, G)
            for (x, y) in ((4, 6), (26, 4), (15, 2)):
                cv.sparkle(x, y, core=CC, arm=CD, big=True)
        else:
            cv.hline(6, 25, 29, G)
            cv.sparkle(10, 20, core=BL, arm=TL)
            cv.sparkle(22, 14, core=BL, arm=TL)
    return cv.img


def drop_arrow(f):
    cv = Canvas(32, 32)
    oy = 2 * f
    rows = ["....####....",
            "....####....",
            "....####....",
            "....####....",
            "############",
            ".##########.",
            "..########..",
            "...######...",
            "....####....",
            ".....##....."]
    pts = {(10 + i, 9 + oy + j) for j, row in enumerate(rows) for i, ch in enumerate(row) if ch == "#"}
    for (x, y) in pts:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in pts:
                    cv.p(x + dx, y + dy, AS)
    for (x, y) in pts:
        cv.p(x, y, A)
    return cv.img


def drop_shadow(f):
    cv = Canvas(48, 12)
    rx, ry = (22, 5) if f == 0 else (16, 4)
    for y in range(12):
        for x in range(48):
            if ((x - 23.5) / rx) ** 2 + ((y - 5.5) / ry) ** 2 <= 1.0 and (x + y) % 2 == 0:
                cv.p(x, y, N)
    return cv.img


def outputs():
    out = {}
    for w in (1, 2, 3):
        for f in range(2):
            out["%s/reminder_w%d_idle_%02d.png" % (SUB, w, f)] = reminder(w, "idle", f)
            out["%s/reminder_w%d_warn_%02d.png" % (SUB, w, f)] = reminder(w, "warn", f)
        for f in range(3):
            out["%s/reminder_w%d_fall_%02d.png" % (SUB, w, f)] = reminder(w, "fall", f)
            out["%s/reminder_w%d_respawn_%02d.png" % (SUB, w, f)] = reminder(w, "respawn", f)
    for f in range(3):
        out["%s/reminder_seg_%02d.png" % (SUB, f)] = reminder_seg(f)
    for f in range(2):
        out["%s/reminder_zz_%02d.png" % (SUB, f)] = reminder_zz(f)
    out["%s/snooze_wait_00.png" % SUB] = snooze("wait")
    for f in range(2):
        out["%s/snooze_ready_%02d.png" % (SUB, f)] = snooze("ready", f)
    for f in range(3):
        out["%s/snooze_hit_%02d.png" % (SUB, f)] = snooze("hit", f)
    for f in range(4):
        out["%s/snooze_cooldown_%02d.png" % (SUB, f)] = snooze("cooldown", f)
    out["%s/overlay_frame_00.png" % SUB] = overlay_frame()
    out["%s/overlay_frame_debug_00.png" % SUB] = overlay_frame(debug=True)
    for f in range(3):
        out["%s/overlay_close_%02d.png" % (SUB, f)] = overlay_close(f)
    out["%s/overlay_bell_00.png" % SUB] = overlay_bell()
    out["%s/overlay_sample_00.png" % SUB] = overlay_sample()
    for f in range(2):
        out["%s/update_bar_progress_%02d.png" % (SUB, f)] = update_bar("progress", f)
        out["%s/update_bar_full_%02d.png" % (SUB, f)] = update_bar("full", f)
        out["%s/package_fall_%02d.png" % (SUB, f)] = package("fall", f)
        out["%s/drop_arrow_%02d.png" % (SUB, f)] = drop_arrow(f)
        out["%s/drop_shadow_%02d.png" % (SUB, f)] = drop_shadow(f)
    for f in range(4):
        out["%s/update_bar_stuck_%02d.png" % (SUB, f)] = update_bar("stuck", f)
        out["%s/update_bar_open_%02d.png" % (SUB, f)] = update_bar("open", f)
    for f in range(3):
        out["%s/package_open_%02d.png" % (SUB, f)] = package("open", f)
    return out


def size_of(rel):
    base = os.path.basename(rel)
    return next(s for k, s in sorted(SIZES.items(), key=lambda kv: -len(kv[0])) if base.startswith(k))


def frames_resource():
    return sprite_frames_tres([
        (anim, ["res://assets/sprites/%s_%02d.png" % (prefix, i) for i in range(n)], fps, loop)
        for anim, prefix, n, fps, loop in ANIMS])


def preview(imgs, path, scale=4):
    bg = PAL["cielo"]
    pad = 6
    rows = {}
    for k, im in imgs.items():
        rows.setdefault(os.path.basename(k).rsplit("_", 1)[0], []).append(im)
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
