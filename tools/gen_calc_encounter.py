#!/usr/bin/env python3
"""Genera el arte del encuentro con Calc en la azotea del 1-2 (tanda H1 del paso 14 de
docs/propuesta-1-2.md; diseno en docs/propuesta-calc-encuentro.md).

Dos juegos de sprites, deterministas:

A) Objetos del cuarto trasero (assets/sprites/props/calc_room/, SpriteFrames
   assets/sprites/calc_encounter_frames.tres). Estilo circuito limpio como
   tools/gen_world1_puzzle.py. Solo colores de assets/palettes/mundo1.gpl +
   effects_pulse.gpl y SIN rojos ni ambar (aqui nada hace dano).
     power_switch_off/hit/on     64x64  interruptor de pulso en la pared del fondo
                                        (placa con almohadilla de anillos; las luces
                                        de 8x8 las dibuja el juego encima, y 0..13)
     debug_switch_off/hit/on     64x64  el mismo panel «visto con el Debug» (trazas y
                                        contorno discontinuo cian, lupa)
     switch_lamp_off/on           8x8   luz de un pulso (las coloca el juego)
     laser_switch_idle/hit/on    32x48  interruptor laser: diana como el lector laser y
                                        una palanca que sube al activarse
     power_door_appear/idle/open 64x128 la pared con glitch se convierte en una puerta
                                        (jambas y dintel de pared, hueco oscuro de paso,
                                        tres zocalos de luz en el dintel)
     charge_dock_idle/ready/charging/done 128x64  punto de carga: plataforma baja (la
                                        superficie en y 52) y pilar con ventana del medidor
     charge_gauge                16x48  medidor de 10 segmentos (11 cuadros de progreso)
     charge_spark                32x32  chispas de la carga

B) Calc en el nivel (assets/sprites/calc_actor/, SpriteFrames
   assets/sprites/calc_actor_frames.tres). Paleta assets/palettes/hub.gpl (Calc es arte
   del hub), sin rojos; el ambar solo en el icono de bateria baja. 64x96, pies abajo y
   centro, con el mismo cuerpo que calc_body()/calc() de tools/gen_hub_objects.py.
     calc_low (3 % de bateria), calc_wake, calc_walk, calc_charging, calc_charged,
     calc_teleport

Uso (desde la raiz del repo):
  python3 -I tools/gen_calc_encounter.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_calc_encounter.py.
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, Canvas, REPO  # noqa: E402
import gen_hub_objects as gh  # noqa: E402
from gen_world1_puzzle import disc, ring  # noqa: E402
from PIL import Image  # noqa: E402

N = PAL["noche_profunda"]
TS = PAL["tile_sombra"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]
BL = PAL["borde_luz"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]
CLEAR = (0, 0, 0, 0)

FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra")
HUB_FORBIDDEN = ()  # el hub no tiene rojos; el ambar se admite (bateria baja)

# (animacion, prefijo, cuadros, fps, bucle).
OBJ_ANIMS = [
    ("power_switch_off", "props/calc_room/power_switch_off", 2, 2.0, True),
    ("power_switch_hit", "props/calc_room/power_switch_hit", 3, 12.0, False),
    ("power_switch_on", "props/calc_room/power_switch_on", 2, 3.0, True),
    ("debug_switch_off", "props/calc_room/debug_switch_off", 2, 2.0, True),
    ("debug_switch_hit", "props/calc_room/debug_switch_hit", 3, 12.0, False),
    ("debug_switch_on", "props/calc_room/debug_switch_on", 2, 3.0, True),
    ("switch_lamp_off", "props/calc_room/switch_lamp_off", 1, 1.0, True),
    ("switch_lamp_on", "props/calc_room/switch_lamp_on", 1, 1.0, True),
    ("laser_switch_idle", "props/calc_room/laser_switch_idle", 2, 2.0, True),
    ("laser_switch_hit", "props/calc_room/laser_switch_hit", 3, 12.0, False),
    ("laser_switch_on", "props/calc_room/laser_switch_on", 2, 3.0, True),
    ("power_door_appear", "props/calc_room/power_door_appear", 6, 12.0, False),
    ("power_door_idle", "props/calc_room/power_door_idle", 2, 2.0, True),
    ("power_door_open", "props/calc_room/power_door_open", 2, 4.0, True),
    ("charge_dock_idle", "props/calc_room/charge_dock_idle", 2, 2.0, True),
    ("charge_dock_ready", "props/calc_room/charge_dock_ready", 2, 4.0, True),
    ("charge_dock_charging", "props/calc_room/charge_dock_charging", 4, 12.0, True),
    ("charge_dock_done", "props/calc_room/charge_dock_done", 2, 3.0, True),
    ("charge_gauge", "props/calc_room/charge_gauge", 11, 0.0, False),
    ("charge_spark", "props/calc_room/charge_spark", 4, 12.0, True),
]
CALC_ANIMS = [
    ("calc_low", "calc_actor/calc_low", 2, 2.0, True),
    ("calc_wake", "calc_actor/calc_wake", 3, 10.0, False),
    ("calc_walk", "calc_actor/calc_walk", 4, 8.0, True),
    ("calc_charging", "calc_actor/calc_charging", 4, 8.0, True),
    ("calc_charged", "calc_actor/calc_charged", 4, 3.0, True),
    ("calc_teleport", "calc_actor/calc_teleport", 8, 12.0, False),
]
OBJ_TRES = "calc_encounter_frames.tres"
CALC_TRES = "calc_actor_frames.tres"
SIZES = {
    "power_switch": (64, 64), "debug_switch": (64, 64), "switch_lamp": (8, 8), "laser_switch": (32, 48),
    "power_door": (64, 128), "charge_dock": (128, 64), "charge_gauge": (16, 48), "charge_spark": (32, 32),
    "calc_": (64, 96),
}
# Lienzos que pueden ser opacos del todo (la puerta llena su bloque de pared).
OPAQUE_OK = ("power_door",)


def lcg(seed):
    state = [seed & 0x7FFFFFFF]

    def nxt(n):
        state[0] = (state[0] * 1103515245 + 12345) & 0x7FFFFFFF
        return (state[0] >> 8) % n
    return nxt


def dashed_box(cv, x0, y0, x1, y1, color, phase=0):
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            if (x + phase) % 3 != 2:
                cv.p(x, y, color)
    for y in range(y0, y1 + 1):
        for x in (x0, x1):
            if (y + phase) % 3 != 2:
                cv.p(x, y, color)


# ------------------------------------------------------ interruptores de pulso (64x64)
PAD = (32, 38)


def switch_panel(kind, state, f):
    """Placa de pared x 8..55, y 14..62 con la almohadilla del pulso en PAD."""
    cv = Canvas(64, 64)
    debug = kind == "debug"
    x0, y0, x1, y1 = 8, 14, 55, 62
    if debug:
        cv.rect(x0, y0, x1, y1, N)
        cv.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, TS)
        lit = state != "off"
        dashed_box(cv, x0, y0, x1, y1, C if lit else CD, 0 if state != "off" else f)
        for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            cv.p(x, y, CLEAR)
        # trazas de circuito en las esquinas
        tc = C if state == "on" else CD
        for pts in (((11, 18), (17, 18), (20, 21)), ((52, 18), (46, 18), (43, 21)),
                    ((11, 58), (17, 58), (20, 55)), ((52, 58), (46, 58), (43, 55))):
            (ax, ay), (bx, by), (cx2, cy2) = pts
            cv.hline(min(ax, bx), max(ax, bx), ay, tc)
            step = 1 if cx2 > bx else -1
            for i in range(abs(cx2 - bx) + 1):
                cv.p(bx + i * step, by + (i if cy2 > by else -i), tc)
            cv.p(ax, ay, CC if state == "on" else C)
    else:
        cv.box(x0, y0, x1, y1, TL)
        cv.hline(x0 + 1, x1 - 1, y0 + 1, C if state == "on" else BL)
        cv.vline(x0 + 1, y0 + 2, y1 - 1, C if state == "on" else BL)
        cv.vline(x1 - 1, y0 + 2, y1 - 1, TB)
        cv.hline(x0 + 2, x1 - 1, y1 - 1, TB)
        for (x, y) in ((11, 17), (52, 17), (11, 59), (52, 59)):
            cv.p(x, y, G)
        # rejilla de ventilacion arriba a la izquierda
        for i in range(3):
            cv.hline(14, 22, 18 + i * 2, TB)
    # LED de estado arriba a la derecha
    led = {"off": (TL if f == 0 else G) if not debug else (CD if f == 0 else C),
           "hit": CC, "on": C if f == 0 else CC}[state]
    cv.rect(45, 18, 47, 19, N)
    cv.rect(45, 18, 46, 19, led)
    # almohadilla del pulso: anillos concentricos
    cx, cy = PAD
    disc(cv, cx, cy, 13, N)
    if state == "off":
        if debug:
            disc(cv, cx, cy, 12, TS)
            ring(cv, cx, cy, 11, CD, dashed=True)
            ring(cv, cx, cy, 7, CD, dashed=True)
            # lupa: el panel «visto con el Debug»
            ring(cv, cx - 1, cy - 1, 3, C)
            for i in range(3):
                cv.p(cx + 2 + i, cy + 2 + i, C)
        else:
            disc(cv, cx, cy, 12, G)
            disc(cv, cx, cy, 10, TS)
            disc(cv, cx, cy, 8, TB)
            ring(cv, cx, cy, 6, G)
            disc(cv, cx, cy, 3, TS)
            disc(cv, cx, cy, 1, TL if f == 0 else BL)
    elif state == "hit":
        disc(cv, cx, cy, 12, TS)
        if f == 0:
            disc(cv, cx, cy, 6, C)
            disc(cv, cx, cy, 4, CC)
            disc(cv, cx, cy, 1, W)
        elif f == 1:
            ring(cv, cx, cy, 9, C)
            ring(cv, cx, cy, 8, CC)
            disc(cv, cx, cy, 4, C)
            disc(cv, cx, cy, 2, CC)
        else:
            ring(cv, cx, cy, 12, CC)
            ring(cv, cx, cy, 11, C)
            ring(cv, cx, cy, 6, CD)
            disc(cv, cx, cy, 2, C)
            for (x, y) in ((cx - 15, cy - 9), (cx + 15, cy + 9), (cx + 14, cy - 10), (cx - 14, cy + 10)):
                cv.sparkle(x, y)
    else:  # on
        disc(cv, cx, cy, 12, C)
        disc(cv, cx, cy, 10, TS)
        ring(cv, cx, cy, 8, C)
        disc(cv, cx, cy, 6, CD if f == 0 else C)
        disc(cv, cx, cy, 3, CC)
        disc(cv, cx, cy, 1, W)
    # conducto que baja de la almohadilla al borde (cable a la pared)
    cv.rect(31, 52, 32, 61, N)
    cv.rect(31, 53, 32, 60, C if state == "on" else (CD if debug else TB))
    return cv.img


def switch_lamp(on):
    cv = Canvas(8, 8)
    cv.box(0, 0, 7, 7, TS if not on else C)
    if on:
        cv.rect(2, 2, 5, 5, C)
        cv.rect(3, 3, 4, 4, CC)
        cv.p(3, 3, W)
    else:
        cv.rect(2, 2, 5, 5, N)
        cv.hline(1, 6, 1, TL)
        cv.p(2, 2, TB)
    return cv.img


# ------------------------------------------------------------ interruptor laser (32x48)
def laser_switch(state, f=0):
    cv = Canvas(32, 48)
    cv.rect(26, 10, 31, 41, N)
    cv.rect(27, 11, 31, 40, TB)
    cv.hline(27, 31, 11, TL)
    cv.box(3, 6, 28, 46, TL)
    cv.hline(4, 27, 7, C if state == "on" else BL)
    cv.vline(4, 8, 45, C if state == "on" else BL)
    cv.vline(27, 8, 45, TB)
    cv.hline(5, 27, 45, TB)
    for (x, y) in ((6, 9), (25, 9), (6, 43), (25, 43)):
        cv.p(x, y, G)
    cx, cy = 16, 22
    disc(cv, cx, cy, 9, N)
    if state == "idle":
        disc(cv, cx, cy, 8, G)
        disc(cv, cx, cy, 6, TS)
        disc(cv, cx, cy, 4, W)
        disc(cv, cx, cy, 2, TS)
        cv.p(cx, cy, BL if f == 1 else TL)
    elif state == "hit":
        disc(cv, cx, cy, 8, CC if f != 1 else C)
        disc(cv, cx, cy, 6 if f == 0 else 5, C if f != 1 else CC)
        disc(cv, cx, cy, 3, W)
        if f == 2:
            for (x, y) in ((cx - 11, cy - 8), (cx + 9, cy - 11), (cx - 10, cy + 10)):
                cv.sparkle(x, y)
    else:
        disc(cv, cx, cy, 8, C)
        disc(cv, cx, cy, 6, TS)
        disc(cv, cx, cy, 4, C)
        disc(cv, cx, cy, 2, CC if f == 0 else W)
    # ranura de la palanca y palanca (abajo: apagado; arriba: encendido)
    cv.rect(9, 34, 22, 41, N)
    cv.rect(10, 35, 21, 40, TS)
    cv.rect(15, 36, 16, 39, TB)  # pivote
    up = state == "on" or (state == "hit" and f >= 1)
    if up:
        for i in range(5):
            cv.p(17 + i, 36 - i, C)
            cv.p(17 + i, 37 - i, CD)
        cv.rect(21, 31, 23, 32, CC)
    else:
        for i in range(5):
            cv.p(14 - i, 38 + i, G)
            cv.p(14 - i, 37 + i, TL)
        cv.rect(8, 42, 10, 43, G)
    return cv.img


# ------------------------------------------------------------------- puerta (64x128)
def wall_block():
    cv = Canvas(64, 128)
    cv.rect(0, 0, 63, 127, TB)
    for (x, y) in ((14, 18), (44, 9), (22, 52), (50, 70), (10, 96), (38, 112), (30, 34), (56, 40)):
        cv.rect(x, y, x + 2, y, TS)
        cv.rect(x, y, x, y + 2, TS)
        cv.p(x + 2, y + 2, TL)
    return cv


def door(state, f=0):
    cv = Canvas(64, 128)
    cv.rect(0, 0, 63, 127, TB)
    # dintel y jambas con relieve
    cv.hline(0, 63, 0, TL)
    cv.vline(0, 0, 127, TL)
    cv.vline(63, 0, 127, TS)
    for (x, y) in ((3, 40), (3, 90), (57, 60), (57, 108)):
        cv.rect(x, y, x + 2, y, TS)
        cv.rect(x, y, x, y + 2, TS)
    # hueco de paso
    cv.rect(10, 18, 53, 127, N)
    lit = state == "open"
    edge_l = (C if f == 0 else CC) if lit else TL
    edge_r = (C if f == 1 else CC) if lit else TS
    cv.vline(9, 17, 127, edge_l)
    cv.vline(54, 17, 127, edge_r)
    cv.hline(9, 54, 17, TL if not lit else C)
    cv.vline(10, 18, 127, TS)
    cv.hline(10, 53, 18, TS)
    # zocalos de las tres luces (las luces de 8x8 las pone el juego)
    cv.hline(10, 53, 14, TS)
    for cx in (20, 32, 44):
        cv.rect(cx - 5, 4, cx + 4, 13, N)
        cv.hline(cx - 5, cx + 4, 14, TL)
    # puerto de corriente en la jamba derecha
    cv.rect(57, 30, 60, 35, N)
    cv.rect(58, 31, 59, 34, (C if lit else (TL if f == 0 else G)))
    if lit:
        # brillo en el suelo del umbral
        for x in range(11, 53):
            if x % 2 == f:
                cv.p(x, 124, CD)
            cv.p(x, 125, CD)
        cv.hline(11, 52, 126, C)
        cv.hline(11, 52, 127, CC if f == 0 else C)
    else:
        cv.hline(11, 52, 127, TS)
        if f == 1:
            cv.p(31, 126, TS)
            cv.p(33, 126, TS)
    return cv.img


def door_appear(f):
    """De bloque con glitch a puerta: bandas de 4 px desplazadas que se resuelven."""
    if f == 5:
        return door("idle", 0)
    block = wall_block().img
    target = door("idle", 0)
    rnd = lcg(97)
    bands = [rnd(100) for _ in range(32)]
    shifts = [rnd(7) - 3 for _ in range(32)]
    out = Image.new("RGBA", (64, 128), CLEAR)
    threshold = f * 22  # f 0: casi todo bloque; f 4: casi todo puerta
    for b in range(32):
        src = target if bands[b] < threshold else block
        strip = src.crop((0, b * 4, 64, b * 4 + 4))
        dx = shifts[b] * (1 if 0 < f < 5 else 0) if (b + f) % 3 == 0 else 0
        base = Image.new("RGBA", (64, 4), TB)
        base.alpha_composite(strip, (dx, 0)) if dx >= 0 else base.alpha_composite(strip.crop((-dx, 0, 64, 4)), (0, 0))
        out.alpha_composite(base, (0, b * 4))
    cv = Canvas(64, 128)
    cv.img = out
    cv.px = out.load()
    # lineas de glitch (como la pared) que se apagan
    for i in range(6 - f):
        y = 8 + ((i * 37 + f * 11) % 112)
        x0 = (i * 19 + f * 7) % 40
        cv.hline(x0, x0 + 12 + (i % 3) * 4, y, TL)
        cv.p(x0 + 13 + (i % 3) * 4, y, BL)
    if f >= 3:
        cv.sparkle(10 + f * 6, 30 + f * 9)
    return out


# --------------------------------------------------------------- punto de carga (128x64)
def charge_dock(state, f=0):
    cv = Canvas(128, 64)
    # plataforma baja
    cv.box(4, 52, 107, 63, TL)
    cv.hline(5, 106, 53, BL)
    cv.hline(5, 106, 62, TB)
    for x in range(12, 100, 12):
        cv.rect(x, 57, x + 5, 58, TB)
    plate = {"idle": TS, "ready": TS, "charging": C, "done": C}[state]
    cv.rect(14, 52, 98, 54, N)
    cv.rect(15, 52, 97, 53, plate)
    if state == "ready":
        for x in range(15, 98):
            if (x + f * 2) % 4 < 2:
                cv.p(x, 52, C)
            else:
                cv.p(x, 52, CD)
        for cx in (30, 56, 82):  # chevrones hacia arriba
            col = C if f == 0 else CD
            cv.p(cx, 48, col)
            cv.p(cx - 1, 49, col)
            cv.p(cx + 1, 49, col)
    elif state == "charging":
        cv.hline(15, 97, 52, CC)
        rnd = lcg(31 + f)
        for i in range(9):
            x = 18 + i * 9 + rnd(4)
            top = 22 + ((i * 7 + f * 6) % 20)
            for y in range(top, 51):
                if (y + f + i) % 3 != 0:
                    cv.p(x, y, CD if y > top + 6 else C)
            cv.p(x, top, CC)
    elif state == "done":
        cv.hline(15, 97, 52, CC if f == 0 else C)
    else:
        cv.hline(15, 97, 52, TL)
    # pilar con la ventana del medidor
    cv.box(108, 8, 127, 63, TL)
    cv.vline(109, 9, 62, BL)
    cv.hline(109, 126, 9, BL)
    cv.rect(110, 58, 125, 61, TB)
    cv.vline(126, 9, 62, TB)
    cv.rect(110, 10, 125, 57, N)
    cv.rect(114, 4, 122, 8, N)
    led = {"idle": TS if f == 0 else TB, "ready": C if f == 0 else CD, "charging": CC, "done": C}[state]
    cv.rect(116, 5, 120, 7, led)
    # cable del pilar a la plataforma
    cv.hline(100, 108, 59, N)
    cv.hline(100, 107, 60, C if state in ("charging", "done") else TS)
    return cv.img


def charge_gauge(k):
    cv = Canvas(16, 48)
    cv.box(0, 0, 15, 47, TS)
    cv.hline(1, 14, 1, TB)
    for i in range(10):
        y1 = 44 - i * 4
        y0 = y1 - 2
        if i < k:
            cv.rect(2, y0, 13, y1, C)
            cv.hline(2, 13, y0, CC)
        else:
            cv.rect(2, y0, 13, y1, TB)
    return cv.img


def charge_spark(f):
    cv = Canvas(32, 32)
    rnd = lcg(53 + f * 17)
    for arm in range(3):
        x, y = 16, 16
        dx = (-1, 1, 1, -1)[(arm + f) % 4]
        dy = (-1, -1, 1, 1)[(arm * 3 + f) % 4]
        for seg in range(4):
            length = 2 + rnd(3)
            horiz = (seg + arm + f) % 2 == 0
            for _ in range(length):
                x += dx if horiz else 0
                y += 0 if horiz else dy
                cv.p(x, y, C)
            if seg == 3:
                cv.p(x, y, W)
    cv.p(16, 16, CC)
    cv.p(15, 16, C)
    cv.p(17, 16, C)
    return cv.img


# ----------------------------------------------------------------- Calc (64x96, hub)
HP = gh.PAL
FP, SO, PA, DK, BA, GA, GF = HP["fondo_profundo"], HP["sombra"], HP["panel"], HP["dock"], HP["base"], \
    HP["gris_apagado"], HP["gris_foto"]
BO, TT, CT, CA, CB, AM, AS = HP["borde"], HP["texto_tenue"], HP["cian_tenue"], HP["acento_cian"], \
    HP["cian_brillo"], HP["ambar"], HP["ambar_sombra"]
VX0, VY0, VX1, VY1 = gh.VISOR


def tired_face(cv, dy=0, eye=CT):
    for ex in (22, 35):
        cv.rect(ex, 39 + dy, ex + 5, 40 + dy, eye)
        cv.hline(ex, ex + 5, 38 + dy, FP)
    cv.hline(28, 34, 44 + dy, eye)


def battery_icon(cv, x, y, seg_color):
    """Bateria de 7x4 (contorno) con un segmento de 1 px."""
    cv.rect(x, y, x + 6, y + 3, TT)
    cv.rect(x + 1, y + 1, x + 5, y + 2, FP)
    cv.rect(x + 7, y + 1, x + 7, y + 2, TT)
    cv.rect(x + 1, y + 1, x + 1, y + 2, seg_color)


def calc_low(f):
    cv = gh.Canvas(64, 96)
    gh.calc_body(cv, BA, GA, DK, PA, DK, PA)
    cv.rect(VX0, VY0, VX1, VY1, FP)
    # bateria grande con un segmento que parpadea (~3 %)
    x, y = 25, 36
    cv.rect(x, y, x + 11, y + 6, GA)
    cv.rect(x + 1, y + 1, x + 10, y + 5, FP)
    cv.rect(x + 12, y + 2, x + 12, y + 4, GA)
    cv.rect(x + 2, y + 2, x + 3, y + 4, AM if f == 0 else AS)
    return cv.img


def calc_wake(f):
    cv = gh.Canvas(64, 96)
    if f == 0:
        gh.calc_body(cv, BA, GA, DK, PA, DK, PA)
        cv.rect(VX0, VY0, VX1, VY1, FP)
        cv.hline(VX0, VX1, 40, CT)
        cv.hline(VX0 + 6, VX1 - 6, 40, CA)
    elif f == 1:
        gh.calc_body(cv, GA, GF, BA, DK, GA, BA)
        cv.rect(VX0, VY0, VX1, VY1, FP)
        cv.rect(VX0, VY0, VX1, 39, SO)
        tired_face(cv, eye=CT)
        cv.rect(VX0, 41, VX1, VY1, FP)
    else:
        gh.calc_body(cv, GA, GF, BA, DK, GA, BA)
        cv.rect(VX0, VY0, VX1, VY1, SO)
        tired_face(cv, eye=CA)
        battery_icon(cv, 37, 33, AM)
    return cv.img


def calc_walk(f):
    body = gh.Canvas(64, 96)
    gh.calc_body(body, GA, GF, BA, DK, GA, BA)
    body.rect(VX0, VY0, VX1, VY1, SO)
    tired_face(body, eye=CA)
    battery_icon(body, 37, 33, AM if f % 2 == 0 else AS)
    # sin patas: se dibujan aparte
    body.rect(0, 94, 63, 95, (0, 0, 0, 0))
    bob = -1 if f in (1, 3) else 0
    out = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    out.alpha_composite(body.img, (0, bob))
    cv = gh.Canvas(64, 96)
    cv.img = out
    cv.px = out.load()
    left_up = f == 1
    right_up = f == 3
    for (x0, up) in ((16, left_up), (42, right_up)):
        y = 92 if up else 94
        cv.rect(x0, y, x0 + 5, y + 1, FP)
    return out


BOLT = ["...##", "..##.", ".##..", "#####", "..##.", ".##..", "##..."]


def calc_charging(f):
    cv = gh.Canvas(64, 96)
    gh.calc_body(cv, GF, BO, GA, PA, DK, CT)
    cv.rect(VX0, VY0, VX1, VY1, SO)
    cv.hline(VX0, VX1, VY0, PA)
    col = CA if f % 2 == 0 else CB
    cv.stamp(29, 36, BOLT, {"#": col})
    # barras de carga a los lados que suben
    for i in range(4):
        c = CA if i <= f else CT
        cv.rect(20, 44 - i * 3, 23, 45 - i * 3, c)
        cv.rect(40, 44 - i * 3, 43, 45 - i * 3, c)
    cv.rect(45, 29, 46, 30, CA if f % 2 == 0 else CT)
    return cv.img


def calc_teleport(k):
    src = gh.calc("awake", 0)
    spx = src.load()
    out = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    opx = out.load()
    cut = 96 - (k + 1) * 13
    for y in range(96):
        for x in range(64):
            c = spx[x, y]
            if c[3] == 0:
                continue
            if y < cut:
                opx[x, y] = c
            elif y < cut + 10 and y % 2 == 0:
                sx = x + ((y // 2) % 3 - 1) * (k + 1)
                if 0 <= sx < 64:
                    opx[sx, y] = CA if (x + y) % 3 else CB
    rnd = lcg(71 + k)
    for i in range(12):
        x = 14 + rnd(36)
        y = max(cut, 0) + rnd(30) - k
        if 0 <= y < 96:
            opx[x, y] = CB if i % 3 == 0 else CA
    return out


# ------------------------------------------------------------------------- salida
def outputs():
    out = {}
    room = "props/calc_room/"
    for kind in ("power", "debug"):
        for f in range(2):
            out[f"{room}{kind}_switch_off_{f:02d}.png"] = switch_panel(kind, "off", f)
            out[f"{room}{kind}_switch_on_{f:02d}.png"] = switch_panel(kind, "on", f)
        for f in range(3):
            out[f"{room}{kind}_switch_hit_{f:02d}.png"] = switch_panel(kind, "hit", f)
    out[f"{room}switch_lamp_off_00.png"] = switch_lamp(False)
    out[f"{room}switch_lamp_on_00.png"] = switch_lamp(True)
    for f in range(2):
        out[f"{room}laser_switch_idle_{f:02d}.png"] = laser_switch("idle", f)
        out[f"{room}laser_switch_on_{f:02d}.png"] = laser_switch("on", f)
        out[f"{room}power_door_idle_{f:02d}.png"] = door("idle", f)
        out[f"{room}power_door_open_{f:02d}.png"] = door("open", f)
        out[f"{room}charge_dock_idle_{f:02d}.png"] = charge_dock("idle", f)
        out[f"{room}charge_dock_ready_{f:02d}.png"] = charge_dock("ready", f)
        out[f"{room}charge_dock_done_{f:02d}.png"] = charge_dock("done", f)
    for f in range(3):
        out[f"{room}laser_switch_hit_{f:02d}.png"] = laser_switch("hit", f)
    for f in range(6):
        out[f"{room}power_door_appear_{f:02d}.png"] = door_appear(f)
    for f in range(4):
        out[f"{room}charge_dock_charging_{f:02d}.png"] = charge_dock("charging", f)
        out[f"{room}charge_spark_{f:02d}.png"] = charge_spark(f)
    for k in range(11):
        out[f"{room}charge_gauge_{k:02d}.png"] = charge_gauge(k)
    for f in range(2):
        out[f"calc_actor/calc_low_{f:02d}.png"] = calc_low(f)
    for f in range(3):
        out[f"calc_actor/calc_wake_{f:02d}.png"] = calc_wake(f)
    for f in range(4):
        out[f"calc_actor/calc_walk_{f:02d}.png"] = calc_walk(f)
        out[f"calc_actor/calc_charging_{f:02d}.png"] = calc_charging(f)
        out[f"calc_actor/calc_charged_{f:02d}.png"] = gh.calc("awake", f)
    for k in range(8):
        out[f"calc_actor/calc_teleport_{k:02d}.png"] = calc_teleport(k)
    return out


def is_calc(rel):
    return rel.startswith("calc_actor/")


def size_of(rel):
    base = os.path.basename(rel)
    return next(s for k, s in SIZES.items() if base.startswith(k))


def frames_resources():
    def res(anims):
        return sprite_frames(anims)
    return {OBJ_TRES: res(OBJ_ANIMS), CALC_TRES: res(CALC_ANIMS)}


def sprite_frames(anims):
    return gh.sprite_frames_tres([
        (anim, ["res://assets/sprites/%s_%02d.png" % (prefix, i) for i in range(n)], fps, loop)
        for anim, prefix, n, fps, loop in anims])


def preview(imgs, path, scale=6):
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
        for name, text in frames_resources().items():
            with open(os.path.join(dest, name), "w", encoding="utf-8") as fh:
                fh.write(text)
    if "--preview" in sys.argv:
        preview(imgs, sys.argv[sys.argv.index("--preview") + 1],
                int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 6)
    print(f"{len(imgs)} PNG + {OBJ_TRES} + {CALC_TRES}")
