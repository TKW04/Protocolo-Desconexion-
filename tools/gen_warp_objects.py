#!/usr/bin/env python3
"""Genera los sprites del vortice de llegada y salida de Isak y de la terminal de
salida del nivel (estilo circuito limpio).

Vortice (assets/sprites/effects/vortex/, 96x96): tres anillos cian partidos en
arcos que giran en sentidos alternos, con nodos de 2x2 en los extremos de los
arcos y patillas cortas en el anillo exterior (como las trazas de un circuito).
Animaciones: vortex_open (4 cuadros: los anillos crecen desde el centro),
vortex_spin (4, bucle: abierto y girando) y vortex_close (6: los anillos se
cierran hacia el centro y acaban en un destello en cruz).

Terminal de salida (assets/sprites/props/exit_terminal/, 64x128 = 1x2 tiles,
apoyada en el borde inferior): monitor moderno de marco fino sobre un pedestal
con una traza de circuito. Animaciones: terminal_off (2: pantalla apagada con
el cursor parpadeando en pulse_dim), terminal_prompt (2: Isak cerca; marco
interior y cursor en cian), terminal_boot (4, sin bucle: la pantalla se enciende
en cian desde una linea central) y terminal_on (2, bucle: pantalla cian con
lineas de codigo, LED encendido y halo cian).

Solo colores de assets/palettes/mundo1.gpl y assets/palettes/effects_pulse.gpl
(sin rojo, carmin ni ambar). Fondo transparente, alfa 0 o 255. La salida es
determinista. Tambien escribe assets/sprites/warp_objects_frames.tres (un
SpriteFrames con una animacion por estado y sus fps) que usa WarpVortex
(scripts/levels/warp_vortex.gd).

Uso (desde la raiz del repo):
  python3 tools/gen_warp_objects.py [--dry-run] [--preview <png> [--scale N]]
--dry-run no escribe nada; --preview guarda una hoja ampliada (x4 por defecto).
Validador: tools/validate_warp_objects.py. Pillow puede estar en el site de
usuario: se anade a sys.path a mano para que funcione tambien con python3 -I.
"""
import math
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, Canvas, preview  # noqa: E402

REPO = os.path.dirname(TOOLS)
FRAMES_TRES = "assets/sprites/warp_objects_frames.tres"

N = PAL["noche_profunda"]
BL = PAL["borde_luz"]
R = PAL["resplandor"]
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]
W = PAL["banner_blanco"]

VORTEX_SIZE = 96
# Anillos: radio (px, abierto del todo), grosor, color, numero de arcos, apertura
# de cada arco (grados), sentido de giro y color de los nodos de los extremos.
RINGS = [
    {"r": 42.0, "w": 2.0, "color": CD, "arcs": 3, "span": 80.0, "dir": 1, "node": BL},
    {"r": 32.0, "w": 2.0, "color": C, "arcs": 2, "span": 120.0, "dir": -1, "node": CC},
    {"r": 21.0, "w": 2.0, "color": CC, "arcs": 4, "span": 50.0, "dir": 2, "node": C},
]
PIN_COUNT = 8
PIN_LEN = 4

# Animaciones del vortice: (nombre, escalas de los anillos por cuadro, paso de giro
# por cuadro (grados), fps, bucle).
VORTEX_ANIMS = [
    ("vortex_open", [0.22, 0.46, 0.72, 1.0], 22.5, 12.0, False),
    ("vortex_spin", [1.0, 1.0, 1.0, 1.0], 22.5, 12.0, True),
    ("vortex_close", [1.0, 0.8, 0.6, 0.4, 0.22, 0.0], 30.0, 12.0, False),
]


def _in_arcs(theta, start, arcs, span):
    step = 360.0 / arcs
    rel = (theta - start) % step
    return rel <= span


def ring(cv, cx, cy, radius, width, color, arcs, span, start, node):
    """Arcos de un anillo (pixeles cuya distancia al centro esta a +-width/2 del radio)."""
    if radius < 7.0:
        return
    r0, r1 = radius - width / 2.0, radius + width / 2.0
    lo, hi = int(cx - r1 - 1), int(cx + r1 + 2)
    for y in range(max(lo, 0), min(hi, cv.h)):
        for x in range(max(lo, 0), min(hi, cv.w)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if r0 <= d < r1 and _in_arcs(math.degrees(math.atan2(dy, dx)), start, arcs, span):
                cv.p(x, y, color)
    # Nodos de 2x2 en los extremos de cada arco (terminales del circuito).
    if radius < 12.0:
        return
    for i in range(arcs):
        for a in (start + i * 360.0 / arcs, start + i * 360.0 / arcs + span):
            t = math.radians(a)
            nx, ny = int(round(cx + radius * math.cos(t) - 1)), int(round(cy + radius * math.sin(t) - 1))
            cv.rect(nx, ny, nx + 1, ny + 1, node)


def pins(cv, cx, cy, radius, start, count, length, color):
    """Patillas radiales cortas por fuera del anillo exterior."""
    for i in range(count):
        t = math.radians(start + i * 360.0 / count)
        for k in range(1, length + 1):
            d = radius + 2.0 + k
            cv.p(int(math.floor(cx + d * math.cos(t))), int(math.floor(cy + d * math.sin(t))), color)


def spark(cv, cx, cy, arm):
    """Destello en cruz: centro pulse_core, brazos debug_cian y puntas pulse_dim."""
    x, y = int(cx) - 1, int(cy) - 1
    cv.rect(x, y, x + 1, y + 1, CC)
    for k in range(2, arm + 2):
        col = C if k < arm else CD
        for (px, py) in ((x - k + 1, y), (x + k, y), (x, y - k + 1), (x, y + k)):
            cv.rect(px, py, px, py + 1, col) if px in (x - k + 1, x + k) else cv.rect(px, py, px + 1, py, col)


def vortex(scale, angle):
    cv = Canvas(VORTEX_SIZE, VORTEX_SIZE)
    cx = cy = VORTEX_SIZE / 2.0
    if scale <= 0.0:
        spark(cv, cx, cy, 6)
        return cv.img
    for ring_def in RINGS:
        ring(cv, cx, cy, ring_def["r"] * scale, ring_def["w"], ring_def["color"], ring_def["arcs"],
             ring_def["span"], angle * ring_def["dir"], ring_def["node"])
    if scale >= 0.7:
        pins(cv, cx, cy, RINGS[0]["r"] * scale, angle * 0.5, PIN_COUNT, PIN_LEN if scale >= 1.0 else 2, R)
    if scale < 0.5:
        spark(cv, cx, cy, 3 if scale < 0.3 else 2)
    return cv.img


def vortex_frames():
    """{nombre de animacion: [imagenes]} con el giro continuo de una animacion a la siguiente."""
    out = {}
    angle = 0.0
    for name, scales, step, _fps, _loop in VORTEX_ANIMS:
        imgs = []
        for s in scales:
            imgs.append(vortex(s, angle))
            angle += step
        out[name] = imgs
    return out


# ------------------------------------------------------------------ terminal (64x128)
TS = PAL["tile_sombra"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]

TERMINAL_W, TERMINAL_H = 64, 128
# Monitor y pantalla (inclusivos).
MON = (4, 30, 59, 75)
SCREEN = (8, 34, 55, 69)
# (nombre, cuadros, fps, bucle)
TERMINAL_ANIMS = [
    ("terminal_off", 2, 2.0, True),
    ("terminal_prompt", 2, 4.0, True),
    ("terminal_boot", 4, 12.0, False),
    ("terminal_on", 2, 4.0, True),
]
# Lineas de "codigo" de la pantalla encendida: (x, ancho) por fila de 3 px.
CODE = [(0, 18), (4, 24), (4, 12), (8, 20), (4, 28), (0, 10), (4, 16), (8, 22), (0, 26), (4, 14)]


def terminal_body(cv, led):
    """Pedestal, cuello y monitor (sin la pantalla)."""
    # Base del pedestal.
    cv.box(12, 119, 51, 127, TB)
    cv.hline(13, 50, 120, TL)
    cv.hline(13, 50, 126, TS)
    # Cuello con traza de circuito.
    cv.rect(27, 78, 36, 118, N)
    cv.rect(28, 78, 35, 118, TB)
    cv.vline(28, 78, 118, TL)
    cv.vline(35, 78, 118, TS)
    cv.vline(31, 80, 114, R)
    cv.rect(31, 115, 32, 116, BL)
    cv.rect(30, 80, 33, 81, BL)
    # Soporte bajo el monitor.
    cv.rect(22, 75, 41, 79, N)
    cv.rect(23, 76, 40, 78, TB)
    cv.hline(23, 40, 76, TL)
    # Monitor: marco fino con bisel.
    x0, y0, x1, y1 = MON
    cv.box(x0, y0, x1, y1, TB)
    cv.hline(x0 + 1, x1 - 1, y0 + 1, BL)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, TL)
    cv.vline(x1 - 1, y0 + 2, y1 - 1, TS)
    cv.hline(x0 + 2, x1 - 1, y1 - 1, TS)
    sx0, sy0, sx1, sy1 = SCREEN
    cv.rect(sx0 - 1, sy0 - 1, sx1 + 1, sy1 + 1, N)
    # LED de encendido abajo a la derecha del marco.
    cv.rect(x1 - 6, y1 - 4, x1 - 5, y1 - 3, led)


def screen_fill(cv, color):
    sx0, sy0, sx1, sy1 = SCREEN
    cv.rect(sx0, sy0, sx1, sy1, color)


def cursor(cv, x, y, color):
    cv.rect(x, y, x + 4, y + 1, color)


def prompt_glyph(cv, x, y, color):
    """'>' de 3x5."""
    for (dx, dy) in ((0, 0), (1, 1), (2, 2), (1, 3), (0, 4)):
        cv.p(x + dx, y + dy, color)


def terminal(state, f):
    cv = Canvas(TERMINAL_W, TERMINAL_H)
    sx0, sy0, sx1, sy1 = SCREEN
    if state == "off":
        terminal_body(cv, TL)
        screen_fill(cv, TS)
        # Reflejo diagonal tenue de pantalla apagada.
        for k in range(6):
            cv.p(sx1 - 10 + k, sy0 + 2 + k, TB)
            cv.p(sx1 - 6 + k, sy0 + 2 + k, TB)
        prompt_glyph(cv, sx0 + 3, sy1 - 7, CD)
        if f == 0:
            cursor(cv, sx0 + 8, sy1 - 4, CD)
    elif state == "prompt":
        terminal_body(cv, CD)
        screen_fill(cv, TS)
        cv.rect(sx0, sy0, sx1, sy0, CD)
        cv.rect(sx0, sy1, sx1, sy1, CD)
        cv.rect(sx0, sy0, sx0, sy1, CD)
        cv.rect(sx1, sy0, sx1, sy1, CD)
        prompt_glyph(cv, sx0 + 3, sy1 - 7, C)
        if f == 0:
            cursor(cv, sx0 + 8, sy1 - 4, C)
    elif state == "boot":
        terminal_body(cv, C)
        screen_fill(cv, TS)
        cy = (sy0 + sy1) // 2
        half = [1, 5, 11, 18][f]
        if f == 0:
            cv.hline(sx0 + 8, sx1 - 8, cy, C)
            cv.hline(sx0 + 18, sx1 - 18, cy, CC)
        else:
            cv.rect(sx0, max(sy0, cy - half), sx1, min(sy1, cy + half), CD if f < 3 else C)
            cv.hline(sx0, sx1, max(sy0, cy - half), C)
            cv.hline(sx0, sx1, min(sy1, cy + half), C)
            cv.hline(sx0 + 4, sx1 - 4, cy, CC)
    else:  # on
        terminal_body(cv, C)
        screen_fill(cv, CD)
        shift = f * 3
        for i, (x, w) in enumerate(CODE):
            y = sy0 + 2 + i * 3 - shift
            if sy0 + 1 <= y <= sy1 - 10:
                cv.hline(sx0 + 3 + x, min(sx0 + 3 + x + w, sx1 - 3), y, C if i % 3 else CC)
        prompt_glyph(cv, sx0 + 3, sy1 - 7, CC)
        cursor(cv, sx0 + 8, sy1 - 4, CC if f == 0 else C)
        # Halo cian alrededor del monitor (solo en el cuadro 0: late).
        if f == 0:
            x0, y0, x1, y1 = MON
            cv.hline(x0 + 1, x1 - 1, y0 - 1, C)
            cv.vline(x0 - 1, y0 + 1, y1 - 1, C)
            cv.vline(x1 + 1, y0 + 1, y1 - 1, C)
    return cv.img


def outputs():
    """{ruta relativa a assets/sprites: imagen}."""
    out = {}
    for name, imgs in vortex_frames().items():
        for i, im in enumerate(imgs):
            out[f"effects/vortex/{name}_{i:02d}.png"] = im
    for name, count, _fps, _loop in TERMINAL_ANIMS:
        for f in range(count):
            out[f"props/exit_terminal/{name}_{f:02d}.png"] = terminal(name.split("_", 1)[1], f)
    return out


def animations():
    """[(nombre, [rutas res://], fps, bucle)] para el SpriteFrames."""
    anims = []
    for name, scales, _step, fps, loop in VORTEX_ANIMS:
        paths = ["res://assets/sprites/effects/vortex/%s_%02d.png" % (name, i) for i in range(len(scales))]
        anims.append((name, paths, fps, loop))
    for name, count, fps, loop in TERMINAL_ANIMS:
        paths = ["res://assets/sprites/props/exit_terminal/%s_%02d.png" % (name, i) for i in range(count)]
        anims.append((name, paths, fps, loop))
    return anims


def sprite_frames_tres(anims):
    """Texto de un recurso SpriteFrames de Godot 4 con las animaciones dadas."""
    paths = [p for _, ps, _, _ in anims for p in ps]
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(paths) + 1), ""]
    ids = {}
    for i, p in enumerate(paths, start=1):
        ids[p] = "%d_%s" % (i, os.path.splitext(os.path.basename(p))[0])
        lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (p, ids[p]))
    lines += ["", "[resource]"]
    blocks = []
    for name, ps, fps, loop in anims:
        frames = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % ids[p] for p in ps)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                      % (frames, "true" if loop else "false", name, fps))
    lines.append("animations = [" + ", ".join(blocks) + "]")
    return "\n".join(lines) + "\n"


def main(argv):
    imgs = outputs()
    dest = os.path.join(REPO, "assets/sprites")
    if "--dry-run" not in argv:
        for k, im in imgs.items():
            p = os.path.join(dest, k)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            im.save(p)
        with open(os.path.join(REPO, FRAMES_TRES), "w", encoding="utf-8") as fh:
            fh.write(sprite_frames_tres(animations()))
    if "--preview" in argv:
        preview(imgs, argv[argv.index("--preview") + 1],
                int(argv[argv.index("--scale") + 1]) if "--scale" in argv else 4)
    print(f"{len(imgs)} PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
