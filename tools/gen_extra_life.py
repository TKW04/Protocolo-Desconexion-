#!/usr/bin/env python3
"""Genera el arte de la vida extra y de la pared con glitch al abrirse con el Debug
(paso 14 de §10 de docs/propuesta-asistentes-y-vidas.md; §9, «Vida extra (pickup)»).

Estilo circuito limpio, como tools/gen_energy_objects.py; el motivo es el mini
telefono del icono de vidas del HUD (tools/gen_hud_assets.py, draw_lives), mas
grande, con «+1» en la pantalla y halo cian. Solo colores de
assets/palettes/mundo1.gpl + assets/palettes/effects_pulse.gpl, SIN rojos ni
ambar (alerta, alerta_sombra, carmin, carmin_brillo, ambar, ambar_sombra): el rojo
es dano y el ambar, puntos de atencion. Fondo transparente, alfa 0 o 255.

Salidas (rutas relativas a assets/sprites/):
  pickups/extra_life_idle_00..03.png     32x32  bote y brillo (el bote va por codigo)
  pickups/extra_life_collect_00..03.png  32x32  recogida: destello, anillo, «+1» y
                                                chispas (el ascenso va por codigo)
  effects/glitch_dissolve_00..05.png     64x64  capa que se dibuja sobre cada celda
                                                de la pared con glitch mientras se
                                                disuelve con el Debug (lineas
                                                desplazadas cian y bloques que se
                                                deshacen; la celda parpadea por codigo)
  extra_life_frames.tres                  SpriteFrames (animaciones idle, collect y
                                                dissolve) para ExtraLifePickup y
                                                GlitchWall

Uso (desde la raiz del repo):
  python3 tools/gen_extra_life.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_extra_life.py (en tools/run_tests.sh).
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
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]

# Colores prohibidos en este arte (validador).
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra")

# «+1» de 7x5 en la pantalla (las celdas # se pintan).
PLUS_ONE = [
    ".#...#.",
    "###.##.",
    ".#...#.",
    ".....#.",
    "....###",
]

IDLE_FRAMES = 4
COLLECT_FRAMES = 4
DISSOLVE_FRAMES = 6
# (animacion, prefijo, cuadros, fps, bucle) del SpriteFrames.
ANIMS = [
    ("extra_life_idle", "pickups/extra_life_idle", IDLE_FRAMES, 6.0, True),
    ("extra_life_collect", "pickups/extra_life_collect", COLLECT_FRAMES, 12.0, False),
    ("glitch_dissolve", "effects/glitch_dissolve", DISSOLVE_FRAMES, 12.0, False),
]
FRAMES_TRES = "extra_life_frames.tres"


def stamp(cv, ox, oy, rows, color):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                cv.p(ox + i, oy + j, color)


def phone(cv, flash=False):
    """Mini telefono del HUD a mayor tamano: cuerpo 12x22 con esquinas cortadas,
    bisel claro arriba-izquierda, pantalla encendida con «+1» y traza de circuito."""
    x0, y0, x1, y1 = 10, 5, 21, 26
    body = W if flash else G
    cv.box(x0, y0, x1, y1, body)
    if flash:
        return
    cv.hline(x0 + 1, x1 - 2, y0 + 1, W)          # bisel de luz
    cv.vline(x0 + 1, y0 + 1, y1 - 2, W)
    cv.rect(x0 + 2, y0 + 2, x1 - 1, y1 - 1, TB)  # interior del cuerpo
    cv.hline(x0 + 2, x1 - 1, y1 - 1, G)
    cv.rect(15, y0 + 2, 16, y0 + 2, N)           # altavoz
    sx0, sy0, sx1, sy1 = 12, 8, 19, 21           # pantalla
    cv.rect(sx0, sy0, sx1, sy1, R)
    stamp(cv, 12, 9, PLUS_ONE, W)
    # traza de circuito de la pantalla (como el icono del HUD) y su nodo
    cv.vline(13, 16, 19, W)
    cv.hline(13, 17, 19, W)
    cv.rect(18, 19, 19, 19, BL)
    cv.rect(15, y1 - 2, 16, y1 - 2, G)           # boton
    # pads de circuito a los lados (nodos, como los drops)
    for y in (11, 20):
        cv.p(x0 - 1, y, N); cv.p(x0 - 2, y, CD)
        cv.p(x1 + 1, y, N); cv.p(x1 + 2, y, CD)


def idle(f):
    cv = Canvas(32, 32)
    phone(cv)
    # 0 base; 1 halo tenue en damero; 2 halo cian entero y brillos; 3 brillo bajando
    if f == 1:
        cv.halo(CD, only_dirs=lambda x, y: (x + y) % 2 == 0)
    if f == 2:
        cv.halo(CD)
        cv.sparkle(5, 5, big=True)
        cv.sparkle(26, 27)
    if f == 3:
        cv.sparkle(26, 6)
        cv.p(12, 8, CC); cv.p(13, 8, CC)        # brillo de la pantalla
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


def plus_one_big(cv, ox, oy, color, outline=N):
    """«+1» con contorno de 1 px."""
    cells = {(ox + i, oy + j) for j, row in enumerate(PLUS_ONE) for i, ch in enumerate(row) if ch == "#"}
    for (x, y) in cells:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (x + dx, y + dy) not in cells:
                    cv.p(x + dx, y + dy, outline)
    for (x, y) in cells:
        cv.p(x, y, color)


def collect(f):
    cv = Canvas(32, 32)
    if f == 0:      # destello: el telefono entero en blanco con halo cian
        phone(cv, flash=True)
        cv.halo(C)
    elif f == 1:    # anillo cian y el «+1»
        ring(cv, 15, 16, 10, C)
        plus_one_big(cv, 12, 14, W)
        cv.sparkle(4, 4, big=True)
    elif f == 2:    # el anillo se abre (damero) y el «+1» sube
        ring(cv, 15, 15, 13, CD, dashed=True)
        plus_one_big(cv, 12, 10, W)
        cv.sparkle(27, 24)
        cv.sparkle(5, 25)
    else:           # chispas que se apagan
        cv.p(15, 9, CC); cv.p(15, 8, CD)
        cv.sparkle(8, 12)
        cv.sparkle(23, 7)
        cv.p(20, 18, CD); cv.p(10, 21, CD)
    return cv.img


def dissolve(f):
    """Capa de 64x64 sobre una celda de la pared con glitch mientras se abre."""
    cv = Canvas(64, 64)
    if f <= 2:
        # lineas de pixeles desplazadas (como las rafagas de la pared, en cian)
        rows = {0: (9, 30, 47), 1: (5, 18, 26, 39, 52, 58), 2: (3, 11, 20, 29, 36, 44, 51, 60)}[f]
        for k, y in enumerate(rows):
            x0 = (k * 13 + f * 7) % 24
            length = 18 + (k * 11 + f * 5) % 30
            col = C if (k + f) % 2 == 0 else CD
            cv.hline(x0, min(63, x0 + length), y, col)
            if f >= 1:
                cv.hline(min(63, x0 + length + 3), min(63, x0 + length + 6), y, CC)
        if f == 2:
            for y in range(0, 64, 8):          # rejilla de borrado
                for x in range((y // 8) % 2 * 4, 64, 8):
                    cv.rect(x, y, x + 1, y + 1, CD)
    else:
        # bloques de 4x4 que se deshacen y suben; quedan cada vez menos
        keep = {3: 3, 4: 5, 5: 9}[f]
        lift = (f - 3) * 6
        for by in range(0, 64, 8):
            for bx in range(0, 64, 8):
                h = (bx * 7 + by * 13 + bx * by) % 11
                if h % keep != 0:
                    continue
                y = by - lift + (h % 3)
                col = C if h % 2 == 0 else CD
                size = 3 if f == 3 else (2 if f == 4 else 1)
                cv.rect(bx + 2, y, bx + 2 + size - 1, y + size - 1, col)
        if f == 5:
            cv.sparkle(20, 14, big=True)
            cv.sparkle(44, 38)
    return cv.img


def outputs():
    out = {}
    for f in range(IDLE_FRAMES):
        out[f"pickups/extra_life_idle_{f:02d}.png"] = idle(f)
    for f in range(COLLECT_FRAMES):
        out[f"pickups/extra_life_collect_{f:02d}.png"] = collect(f)
    for f in range(DISSOLVE_FRAMES):
        out[f"effects/glitch_dissolve_{f:02d}.png"] = dissolve(f)
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
