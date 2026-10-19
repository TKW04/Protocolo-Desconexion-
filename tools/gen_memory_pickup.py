#!/usr/bin/env python3
"""Genera el arte del mensaje de secreto recogible (objeto memory_pickup; paso 4 de
docs/propuesta-recuerdos.md §7, 2026-10-19).

Un sobre de correo pequeno, estilo circuito limpio como tools/gen_extra_life.py:
cuerpo banner_blanco con sombra banner_gris, contorno noche_profunda, solapa en
borde_luz, un punto cian de «mensaje nuevo» en la esquina y halo cian que late. Solo
colores de assets/palettes/mundo1.gpl + assets/palettes/effects_pulse.gpl, SIN rojos
ni ambar (alerta, alerta_sombra, carmin, carmin_brillo, ambar, ambar_sombra): el rojo
es dano (y los puntos rojos son enemigos) y el ambar, puntos de atencion. Fondo
transparente, alfa 0 o 255. Se dibuja a x2 (draw_scale de la seccion memory_pickup de
data/world1_objects.json).

Salidas (rutas relativas a assets/sprites/):
  pickups/memory_pickup_idle_00..03.png     24x20  brillo y halo (el bote va por codigo)
  pickups/memory_pickup_collect_00..03.png  24x20  recogida: destello, la solapa se abre
                                                   y sale la hoja, anillo y chispas (el
                                                   ascenso va por codigo)
  memory_pickup_frames.tres                 SpriteFrames (memory_pickup_idle y
                                                   memory_pickup_collect) para MemoryPickup

Uso (desde la raiz del repo):
  python3 tools/gen_memory_pickup.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_memory_pickup.py (en tools/run_tests.sh).
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
TB = PAL["tile_base"]
BL = PAL["borde_luz"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
R = PAL["resplandor"]
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]

# Colores prohibidos en este arte (validador).
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra")

SIZE = (24, 20)
IDLE_FRAMES = 4
COLLECT_FRAMES = 4
# (animacion, prefijo, cuadros, fps, bucle) del SpriteFrames.
ANIMS = [
    ("memory_pickup_idle", "pickups/memory_pickup_idle", IDLE_FRAMES, 6.0, True),
    ("memory_pickup_collect", "pickups/memory_pickup_collect", COLLECT_FRAMES, 12.0, False),
]
FRAMES_TRES = "memory_pickup_frames.tres"

# Sobre: caja exterior (inclusiva) y vertice de la solapa.
X0, Y0, X1, Y1 = 3, 6, 20, 17
FLAP_TIP = (11, 12)


def envelope(cv, flash=False):
    """Sobre de 18x12 con esquinas cortadas, solapa en V y sombra abajo."""
    cv.box(X0, Y0, X1, Y1, W)
    if flash:
        return
    cv.hline(X0 + 1, X1 - 1, Y1 - 1, G)            # sombra del borde inferior
    cv.vline(X1 - 1, Y0 + 2, Y1 - 1, G)            # sombra del lado derecho
    # pliegues inferiores (diagonales tenues desde las esquinas de abajo al centro)
    for k in range(4):
        cv.p(X0 + 1 + k, Y1 - 1 - k, G)
        cv.p(X1 - 1 - k, Y1 - 1 - k, G)
    # solapa cerrada: V de borde_luz con contorno oscuro de 1 px
    tx, ty = FLAP_TIP
    for k in range(0, ty - Y0):
        cv.p(X0 + 1 + k, Y0 + 1 + k, BL)
        cv.p(X1 - 1 - k, Y0 + 1 + k, BL)
        cv.p(X0 + 2 + k, Y0 + 1 + k, R)
        cv.p(X1 - 2 - k, Y0 + 1 + k, R)
    cv.p(tx, ty, N)
    cv.p(tx + 1, ty, N)


def open_envelope(cv, letter_top):
    """Sobre abierto: solapa levantada detras, la hoja asomando y el bolsillo delante."""
    for k in range(6):                              # solapa (triangulo hacia arriba)
        cv.hline(X0 + k, X1 - k, Y0 - k, N)
        cv.hline(X0 + k + 1, X1 - k - 1, Y0 - k, BL)
    letter(cv, letter_top)
    cv.box(X0, Y0 + 3, X1, Y1, W, cut=False)        # bolsillo delantero
    cv.hline(X0 + 1, X1 - 1, Y1 - 1, G)
    cv.vline(X1 - 1, Y0 + 4, Y1 - 1, G)
    for k in range(5):                              # bordes del bolsillo hacia el centro
        cv.p(X0 + 1 + k, Y0 + 4 + k // 2, G)
        cv.p(X1 - 1 - k, Y0 + 4 + k // 2, G)


def new_dot(cv, lit=True):
    """Punto cian de «mensaje nuevo» en la esquina superior derecha (3x3 con contorno)."""
    cx, cy = X1 - 1, Y0 - 1
    cv.rect(cx - 2, cy - 2, cx + 2, cy + 2, N)
    for (x, y) in ((cx - 2, cy - 2), (cx + 2, cy - 2), (cx - 2, cy + 2), (cx + 2, cy + 2)):
        cv.px[x, y] = (0, 0, 0, 0)
    cv.rect(cx - 1, cy - 1, cx + 1, cy + 1, C if lit else CD)
    if lit:
        cv.p(cx - 1, cy - 1, CC)


def idle(f):
    cv = Canvas(*SIZE)
    envelope(cv)
    new_dot(cv, lit=f != 3)
    # 0 base; 1 halo tenue en damero; 2 halo cian entero y brillos; 3 punto apagado y brillo
    if f == 1:
        cv.halo(CD, only_dirs=lambda x, y: (x + y) % 2 == 0)
    if f == 2:
        cv.halo(CD)
        cv.sparkle(1, 3)
        cv.sparkle(22, 18)
    if f == 3:
        cv.sparkle(2, 18)
    return cv.img


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


def letter(cv, y_top):
    """Hoja que sale del sobre: 10x7 banner_blanco con contorno y tres renglones."""
    x0, x1 = 7, 16
    cv.box(x0, y_top, x1, y_top + 6, W, cut=False)
    for j, (a, b) in enumerate(((9, 14), (9, 13), (9, 12))):
        cv.hline(a, b, y_top + 2 + j * 2, G if j else R)


def collect(f):
    cv = Canvas(*SIZE)
    if f == 0:      # destello: el sobre entero en blanco con halo cian
        envelope(cv, flash=True)
        cv.halo(C)
    elif f == 1:    # la solapa se abre y asoma la hoja
        open_envelope(cv, 2)
        cv.sparkle(1, 2, big=True)
    elif f == 2:    # anillo cian y la hoja sube
        ring(cv, 11, 11, 8, C)
        letter(cv, 1)
        cv.sparkle(21, 16)
    else:           # anillo abierto (damero) y chispas que se apagan
        ring(cv, 11, 10, 9, CD, dashed=True)
        cv.p(11, 3, CC); cv.p(11, 2, CD)
        cv.sparkle(5, 7)
        cv.sparkle(18, 4)
    return cv.img


def outputs():
    out = {}
    for f in range(IDLE_FRAMES):
        out[f"pickups/memory_pickup_idle_{f:02d}.png"] = idle(f)
    for f in range(COLLECT_FRAMES):
        out[f"pickups/memory_pickup_collect_{f:02d}.png"] = collect(f)
    return out


def frames_resource():
    return sprite_frames_tres([
        (anim, ["res://assets/sprites/%s_%02d.png" % (prefix, i) for i in range(n)], fps, loop)
        for anim, prefix, n, fps, loop in ANIMS])


def preview(imgs, path, scale=8):
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
                int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 8)
    print(f"{len(imgs)} PNG + {FRAMES_TRES}")
