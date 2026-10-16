#!/usr/bin/env python3
"""Genera el arte de los objetos del acertijo «Correo certificado» del 1-2 y del chip
del Debug (pasos 3 y 9 de docs/propuesta-1-2.md §10; §4 y §7).

Estilo circuito limpio, como tools/gen_energy_objects.py y tools/gen_extra_life.py.
Solo colores de assets/palettes/mundo1.gpl + assets/palettes/effects_pulse.gpl y
SIN rojos ni ambar (alerta, alerta_sombra, carmin, carmin_brillo, ambar,
ambar_sombra): aqui nada hace dano ni es un punto debil; el cian es el Debug y lo
interactivo. Fondo transparente, alfa 0 o 255.

Salidas (rutas relativas a assets/sprites/):
  props/laser_receiver_idle_00..01.png     32x48  lector laser en reposo: diana gris
                                                  que parpadea (el centro se ilumina)
  props/laser_receiver_powered_00..03.png  32x48  lector disparado: diana cian con
                                                  anillos que laten (da corriente)
  props/laser_receiver_done_00.png         32x48  lector con su receptor ya activado
  props/relay_receiver_off_00..01.png      64x64  receptor enlazado sin corriente:
                                                  enchufe tachado (parpadea la raya)
  props/relay_receiver_powered_00..03.png  64x64  con corriente: enchufe cian y luces
                                                  que corren por el marco
  props/relay_receiver_on_00..01.png       64x64  activado (el puente ya esta)
  props/ad_cover_intact_00..01.png         96x48  anuncio sobre el boton del pop-up:
                                                  barra «AD», «x» gris falsa y barra
                                                  de cuenta atras que parpadea (el
                                                  texto lo escribe el juego)
  props/ad_cover_break_00..03.png          96x48  ruptura (grietas, trozos, chispas)
  effects/gray_spark_00..02.png            32x32  chispa gris: el pulso no hace nada
                                                  (receptor sin corriente, anuncio)
  pickups/debug_chip_idle_00..03.png       48x48  chip del Debug: lupa cian sobre el
                                                  chip, patas que se encienden en
                                                  ronda y halo
  pickups/debug_chip_collect_00..03.png    48x48  instalacion: destello, anillo cian
                                                  que se expande y chispas
  props/cable_off_00.png                   16x16  pieza de cable apagada (traza)
  props/cable_lit_00..03.png               16x16  pieza encendida con el flujo de
                                                  corriente (un trazo claro avanza)
  props/cable_dim_00.png                   16x16  pieza en el parpadeo del aviso
  props/cable_node_off_00.png              16x16  nodo (esquina o extremo) apagado
  props/cable_node_on_00.png               16x16  nodo encendido
  puzzle_objects_frames.tres                      SpriteFrames con todas las
                                                  animaciones (nombres = prefijos)

Uso (desde la raiz del repo):
  python3 tools/gen_world1_puzzle.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_world1_puzzle.py (en tools/run_tests.sh).
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
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]
CLEAR = (0, 0, 0, 0)

# Colores prohibidos en este arte (validador).
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra")

# (animacion, prefijo, cuadros, fps, bucle) del SpriteFrames.
ANIMS = [
    ("laser_receiver_idle", "props/laser_receiver_idle", 2, 2.0, True),
    ("laser_receiver_powered", "props/laser_receiver_powered", 4, 8.0, True),
    ("laser_receiver_done", "props/laser_receiver_done", 1, 1.0, True),
    ("relay_receiver_off", "props/relay_receiver_off", 2, 2.0, True),
    ("relay_receiver_powered", "props/relay_receiver_powered", 4, 8.0, True),
    ("relay_receiver_on", "props/relay_receiver_on", 2, 2.0, True),
    ("ad_cover_intact", "props/ad_cover_intact", 2, 2.0, True),
    ("ad_cover_break", "props/ad_cover_break", 4, 12.0, False),
    ("gray_spark", "effects/gray_spark", 3, 12.0, False),
    ("debug_chip_idle", "pickups/debug_chip_idle", 4, 6.0, True),
    ("debug_chip_collect", "pickups/debug_chip_collect", 4, 8.0, False),
    ("cable_off", "props/cable_off", 1, 1.0, True),
    ("cable_lit", "props/cable_lit", 4, 12.0, True),
    ("cable_dim", "props/cable_dim", 1, 1.0, True),
    ("cable_node_off", "props/cable_node_off", 1, 1.0, True),
    ("cable_node_on", "props/cable_node_on", 1, 1.0, True),
]
FRAMES_TRES = "puzzle_objects_frames.tres"
SIZES = {
    "laser_receiver": (32, 48), "relay_receiver": (64, 64), "ad_cover": (96, 48),
    "gray_spark": (32, 32), "debug_chip": (48, 48), "cable": (16, 16),
}

GLYPHS = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
}


def stamp(cv, ox, oy, rows, color):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                cv.p(ox + i, oy + j, color)


def ring(cv, cx, cy, r, color, dashed=False):
    """Anillo octogonal de 1 px (radio r) centrado en (cx, cy)."""
    pts = set()
    d = r // 2
    for i in range(-d, d + 1):
        pts |= {(cx + i, cy - r), (cx + i, cy + r), (cx - r, cy + i), (cx + r, cy + i)}
    for k in range(1, r - d):
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            pts.add((cx + sx * (d + k), cy + sy * (r - k)))
    for (x, y) in pts:
        if not dashed or (x + y) % 2 == 0:
            cv.p(x, y, color)


def disc(cv, cx, cy, r, color):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r:
                cv.p(x, y, color)


# ----------------------------------------------------------- lector laser (32x48)
def laser_receiver(state, f=0):
    """Placa atornillada a la pared (lado derecho del lienzo) con una diana.
    El centro de la diana (16, 24) queda a la altura del celular de Isak; el
    conector del cable sale por abajo (16, 47)."""
    cv = Canvas(32, 48)
    # soporte a la pared (derecha) y placa
    cv.rect(26, 10, 31, 37, N)
    cv.rect(27, 11, 31, 36, TB)
    cv.hline(27, 31, 11, TL)
    cv.box(3, 6, 28, 41, TL)
    cv.hline(4, 27, 7, BL)
    cv.vline(4, 8, 40, BL)
    cv.vline(27, 8, 40, TB)
    cv.hline(5, 27, 40, TB)
    # tornillos
    for (x, y) in ((6, 9), (25, 9), (6, 38), (25, 38)):
        cv.p(x, y, G)
    # conector del cable (abajo)
    cv.rect(13, 41, 18, 47, N)
    cv.rect(14, 41, 17, 46, TB if state == "idle" else CD)
    cv.hline(14, 17, 47, N)
    if state != "idle":
        cv.rect(15, 42, 16, 46, C)
    # diana: tres anillos centrados en (16, 24)
    cx, cy = 16, 24
    disc(cv, cx, cy, 10, N)
    if state == "idle":
        disc(cv, cx, cy, 9, G)
        disc(cv, cx, cy, 7, TS)
        disc(cv, cx, cy, 5, W)
        disc(cv, cx, cy, 3, TS)
        disc(cv, cx, cy, 1, BL if f == 1 else TL)
    else:
        outer = CC if (state == "powered" and f in (0, 2)) else C
        disc(cv, cx, cy, 9, outer)
        disc(cv, cx, cy, 7, N if state == "done" else TS)
        disc(cv, cx, cy, 5, C)
        disc(cv, cx, cy, 3, CD if state == "done" else (W if f == 1 else CC))
        disc(cv, cx, cy, 1, W)
    # mira (cruz fina de la diana)
    for d in range(11, 13):
        for (x, y) in ((cx - d, cy), (cx + d, cy), (cx, cy - d), (cx, cy + d)):
            cv.p(x, y, N)
    if state == "powered":
        # chispas de corriente alrededor (4 posiciones en ronda)
        spots = ((5, 13), (27, 13), (27, 35), (5, 35))
        x, y = spots[f]
        cv.sparkle(x, y, big=True)
    return cv.img


# ---------------------------------------------------- receptor enlazado (64x64)
def plug(cv, ox, oy, body, prong):
    """Enchufe de 12x12: dos patas arriba y cuerpo con cable abajo."""
    cv.rect(ox + 3, oy, ox + 4, oy + 3, prong)
    cv.rect(ox + 7, oy, ox + 8, oy + 3, prong)
    cv.rect(ox + 1, oy + 4, ox + 10, oy + 9, body)
    cv.rect(ox + 5, oy + 10, ox + 6, oy + 11, body)


def relay_receiver(state, f=0):
    """Caja sobre un poste (como el receptor del pulso) con un enchufe en la
    pantalla y el conector del cable a la derecha (a media altura, y = 32)."""
    cv = Canvas(64, 64)
    # poste y base
    cv.box(22, 58, 41, 63, TL)
    cv.hline(23, 40, 59, BL)
    cv.rect(28, 42, 35, 58, N)
    cv.rect(29, 42, 34, 57, TB)
    cv.vline(29, 42, 57, TL)
    # caja
    cv.box(12, 10, 51, 43, TL)
    cv.hline(13, 50, 11, BL)
    cv.vline(13, 12, 42, BL)
    cv.vline(50, 12, 42, TB)
    cv.hline(14, 50, 42, TB)
    # conector del cable a la derecha (y = 31..33)
    cv.rect(51, 29, 57, 35, N)
    cv.rect(52, 30, 57, 34, TB if state == "off" else CD)
    if state != "off":
        cv.hline(52, 57, 32, C)
    # pantalla
    sx0, sy0, sx1, sy1 = 17, 15, 46, 38
    lit = state != "off"
    cv.box(sx0, sy0, sx1, sy1, TS if state != "on" else CD, cut=False)
    if state == "off":
        plug(cv, 26, 20, G, BL)
        # raya que tacha el enchufe (diagonal de 2 px), parpadea
        col = W if f == 0 else TL
        for i in range(16):
            cv.p(24 + i, 34 - i, col)
            cv.p(25 + i, 34 - i, col)
    elif state == "powered":
        plug(cv, 26, 20, C, CC)
        # luces que corren por el marco de la pantalla (4 posiciones)
        frame_pts = [(x, sy0) for x in range(sx0, sx1 + 1)] + [(sx1, y) for y in range(sy0, sy1 + 1)] + \
                    [(x, sy1) for x in range(sx1, sx0 - 1, -1)] + [(sx0, y) for y in range(sy1, sy0 - 1, -1)]
        step = len(frame_pts) // 4
        for k in range(4):
            i = (f * step // 2 + k * step) % len(frame_pts)
            for j in range(4):
                cv.p(*frame_pts[(i + j) % len(frame_pts)], C)
        if f % 2 == 0:
            cv.sparkle(9, 7, big=True)
    else:  # on
        plug(cv, 26, 20, W, CC)
        cv.hline(sx0 + 2, sx1 - 2, sy1 - 2, CC if f == 0 else C)
        cv.p(sx0 + 2, sy0 + 2, CC)
    # piloto de estado en la caja (abajo a la izquierda de la pantalla)
    cv.rect(14, 39, 15, 40, (C if lit else (BL if f == 1 else TB)))
    return cv.img


# ------------------------------------------------------------- anuncio (96x48)
def ad_card(cv, bar_on):
    cv.box(0, 0, 95, 47, W)
    cv.hline(1, 94, 46, G)
    cv.vline(94, 1, 46, G)
    # barra superior con «AD» y la «x» falsa (gris)
    cv.rect(1, 1, 93, 9, G)
    cv.rect(3, 2, 13, 8, N)
    stamp(cv, 4, 3, GLYPHS["A"], W)
    stamp(cv, 8, 3, GLYPHS["D"], W)
    # «x» gris falsa (no se cierra)
    for i in range(5):
        cv.p(85 + i, 3 + i, TL)
        cv.p(89 - i, 3 + i, TL)
    # barra de cuenta atras bajo la barra superior
    cv.hline(2, 92, 11, TL)
    if bar_on:
        cv.hline(2, 60, 11, R)


def ad_cover(state, f=0):
    cv = Canvas(96, 48)
    if state == "intact":
        ad_card(cv, f == 0)
        return cv.img
    if f == 0:      # grietas: lineas oscuras desde el centro
        ad_card(cv, False)
        for (x0, y0, dx, dy, n) in ((48, 26, 1, 1, 14), (48, 26, -1, 1, 16), (48, 26, 2, -1, 12),
                                    (48, 26, -2, -1, 10), (48, 26, 1, 0, 30)):
            for i in range(n):
                cv.p(x0 + dx * i, y0 + dy * (i // 2), N)
        cv.sparkle(48, 26, core=W, arm=BL, big=True)
    elif f == 1:    # se parte en dos y se desplaza
        left = Canvas(96, 48)
        ad_card(left, False)
        src = left.img
        piece_l, piece_r = src.crop((0, 0, 47, 46)), src.crop((49, 2, 96, 48))
        cv.img.paste(piece_l, (0, 2), piece_l)
        cv.img.paste(piece_r, (49, 0), piece_r)
        cv.px = cv.img.load()
        cv.sparkle(48, 24, core=CC, arm=BL, big=True)
    elif f == 2:    # trozos pequenos que caen
        for (x, y, w, h, col) in ((6, 14, 10, 6, W), (22, 26, 8, 5, G), (40, 34, 6, 6, W), (58, 18, 9, 5, W),
                                  (72, 30, 8, 6, G), (84, 12, 6, 4, W), (30, 8, 5, 4, G)):
            cv.box(x, y, x + w, y + h, col)
        cv.sparkle(50, 22, core=CC, arm=CD)
    else:           # chispas que se apagan
        cv.sparkle(20, 30, core=BL, arm=TL)
        cv.sparkle(70, 20, core=BL, arm=TL)
        cv.p(46, 38, G)
        cv.p(55, 10, G)
    return cv.img


# ------------------------------------------------------------ chispa gris (32x32)
def gray_spark(f):
    cv = Canvas(32, 32)
    cx, cy = 16, 16
    if f == 0:
        cv.sparkle(cx, cy, core=W, arm=G, big=True)
    elif f == 1:
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            for k in range(4, 8):
                if k % 2 == 0 or (dx and dy):
                    cv.p(cx + dx * k, cy + dy * k, G)
        cv.p(cx, cy, BL)
    else:
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.p(cx + dx * 9, cy + dy * 9, TL)
            cv.p(cx + dx * 10, cy + dy * 10, TL)
    return cv.img


# ------------------------------------------------------- chip del Debug (48x48)
def chip_body(cv, f, flash=False):
    x0, y0, x1, y1 = 12, 12, 35, 35
    pins = (17, 23, 29)
    lit_side = f % 4
    for side in range(4):
        for i, p in enumerate(pins):
            col = W if flash else (C if (side == lit_side or i == 1) else CD)
            if side == 0:
                cv.rect(p - 1, 7, p, 11, N); cv.rect(p - 1, 7, p, 10, col)
            elif side == 2:
                cv.rect(p - 1, 36, p, 40, N); cv.rect(p - 1, 37, p, 40, col)
            elif side == 3:
                cv.rect(7, p - 1, 11, p, N); cv.rect(7, p - 1, 10, p, col)
            else:
                cv.rect(36, p - 1, 40, p, N); cv.rect(37, p - 1, 40, p, col)
    cv.box(x0, y0, x1, y1, W if flash else TB)
    if flash:
        return
    cv.hline(x0 + 1, x1 - 1, y0 + 1, TL)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, TL)
    cv.hline(x0 + 2, x1 - 1, y1 - 1, TS)
    cv.vline(x1 - 1, y0 + 2, y1 - 1, TS)
    # marco cian interior (el chip es del Debug)
    for x in range(x0 + 3, x1 - 2):
        cv.p(x, y0 + 3, CD); cv.p(x, y1 - 3, CD)
    for y in range(y0 + 3, y1 - 2):
        cv.p(x0 + 3, y, CD); cv.p(x1 - 3, y, CD)
    # lupa: lente cian (anillo) y mango en diagonal
    disc(cv, 22, 22, 6, N)
    disc(cv, 22, 22, 5, C)
    disc(cv, 22, 22, 3, TS)
    cv.p(21, 21, CC if f in (0, 2) else C)
    cv.p(20, 20, W if f == 1 else CC)
    for i in range(5):
        cv.rect(26 + i, 26 + i, 27 + i, 27 + i, N)
        cv.p(26 + i, 26 + i, C)
    # muesca de orientacion
    cv.p(x0 + 2, y0 + 2, BL)


def debug_chip_idle(f):
    cv = Canvas(48, 48)
    chip_body(cv, f)
    if f == 1:
        cv.halo(CD, only_dirs=lambda x, y: (x + y) % 2 == 0)
    if f == 2:
        cv.halo(CD)
        cv.sparkle(4, 5, big=True)
        cv.sparkle(43, 42)
    if f == 3:
        cv.sparkle(43, 5)
    return cv.img


def debug_chip_collect(f):
    cv = Canvas(48, 48)
    if f == 0:      # destello: el chip en blanco con halo cian
        chip_body(cv, 0, flash=True)
        cv.halo(C)
    elif f == 1:    # anillo cian
        ring(cv, 23, 23, 12, C)
        ring(cv, 23, 23, 6, CC)
        cv.sparkle(23, 23, core=W, arm=CC, big=True)
    elif f == 2:    # el anillo se abre (damero)
        ring(cv, 23, 23, 18, CD, dashed=True)
        ring(cv, 23, 23, 12, C, dashed=True)
        cv.sparkle(8, 9, big=True)
        cv.sparkle(39, 37)
    else:           # chispas que se apagan
        ring(cv, 23, 23, 21, CD, dashed=True)
        cv.sparkle(10, 34)
        cv.sparkle(37, 10)
        cv.p(23, 23, CC)
    return cv.img


# ---------------------------------------------------------------- cable (16x16)
def cable_piece(state, f=0):
    """Traza horizontal de 4 px (filas 6-9) con contorno; el flujo es un trazo claro
    de 4 px que avanza 4 px por cuadro hacia +x (la pieza se gira al dibujarla)."""
    cv = Canvas(16, 16)
    cv.hline(0, 15, 6, N)
    cv.hline(0, 15, 9, N)
    core = {"off": TB, "lit": C, "dim": CD}[state]
    cv.rect(0, 7, 15, 8, core)
    if state == "off":
        cv.hline(0, 15, 7, TL)
    if state == "lit":
        for x in range(f * 4, f * 4 + 4):
            cv.p(x, 7, CC)
            cv.p(x, 8, W if x == f * 4 + 3 else CC)
    return cv.img


def cable_node(on):
    cv = Canvas(16, 16)
    cv.box(4, 4, 11, 11, C if on else TB)
    if on:
        cv.rect(6, 6, 9, 9, CC)
    else:
        cv.rect(6, 6, 9, 9, TL)
        cv.hline(5, 10, 5, BL)
    return cv.img


def outputs():
    out = {}
    for f in range(2):
        out[f"props/laser_receiver_idle_{f:02d}.png"] = laser_receiver("idle", f)
        out[f"props/relay_receiver_off_{f:02d}.png"] = relay_receiver("off", f)
        out[f"props/relay_receiver_on_{f:02d}.png"] = relay_receiver("on", f)
        out[f"props/ad_cover_intact_{f:02d}.png"] = ad_cover("intact", f)
    for f in range(4):
        out[f"props/laser_receiver_powered_{f:02d}.png"] = laser_receiver("powered", f)
        out[f"props/relay_receiver_powered_{f:02d}.png"] = relay_receiver("powered", f)
        out[f"props/ad_cover_break_{f:02d}.png"] = ad_cover("break", f)
        out[f"pickups/debug_chip_idle_{f:02d}.png"] = debug_chip_idle(f)
        out[f"pickups/debug_chip_collect_{f:02d}.png"] = debug_chip_collect(f)
        out[f"props/cable_lit_{f:02d}.png"] = cable_piece("lit", f)
    out["props/laser_receiver_done_00.png"] = laser_receiver("done")
    for f in range(3):
        out[f"effects/gray_spark_{f:02d}.png"] = gray_spark(f)
    out["props/cable_off_00.png"] = cable_piece("off")
    out["props/cable_dim_00.png"] = cable_piece("dim")
    out["props/cable_node_off_00.png"] = cable_node(False)
    out["props/cable_node_on_00.png"] = cable_node(True)
    return out


def size_of(rel):
    base = os.path.basename(rel)
    return next(s for k, s in SIZES.items() if base.startswith(k))


def frames_resource():
    return sprite_frames_tres([
        (anim, ["res://assets/sprites/%s_%02d.png" % (prefix, i) for i in range(n)], fps, loop)
        for anim, prefix, n, fps, loop in ANIMS])


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
        with open(os.path.join(dest, FRAMES_TRES), "w", encoding="utf-8") as fh:
            fh.write(frames_resource())
    if "--preview" in sys.argv:
        preview(imgs, sys.argv[sys.argv.index("--preview") + 1],
                int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 6)
    print(f"{len(imgs)} PNG + {FRAMES_TRES}")
