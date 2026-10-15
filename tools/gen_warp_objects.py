#!/usr/bin/env python3
"""Genera los sprites del vortice de llegada y salida de Isak (estilo circuito limpio).

Vortice (assets/sprites/effects/vortex/, 96x96): tres anillos cian partidos en
arcos que giran en sentidos alternos, con nodos de 2x2 en los extremos de los
arcos y patillas cortas en el anillo exterior (como las trazas de un circuito).
Animaciones: vortex_open (4 cuadros: los anillos crecen desde el centro),
vortex_spin (4, bucle: abierto y girando) y vortex_close (6: los anillos se
cierran hacia el centro y acaban en un destello en cruz).

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


def outputs():
    """{ruta relativa a assets/sprites: imagen}."""
    out = {}
    for name, imgs in vortex_frames().items():
        for i, im in enumerate(imgs):
            out[f"effects/vortex/{name}_{i:02d}.png"] = im
    return out


def animations():
    """[(nombre, [rutas res://], fps, bucle)] para el SpriteFrames."""
    anims = []
    for name, scales, _step, fps, loop in VORTEX_ANIMS:
        paths = ["res://assets/sprites/effects/vortex/%s_%02d.png" % (name, i) for i in range(len(scales))]
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
