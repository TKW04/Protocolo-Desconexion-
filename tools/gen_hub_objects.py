#!/usr/bin/env python3
"""Genera el arte del hub del Mundo 1 (estilo circuito limpio, paleta del hub).

Paso 11 de docs/propuesta-hub-y-guardado.md (§6.1). Solo colores de
assets/palettes/hub.gpl (sin los rojos reservados), fondo transparente salvo el
fondo de pantalla, alfa 0 o 255. La salida es determinista.

Salidas (assets/sprites/hub/):
  background/  hub_bg_photo_off_00..01.png  1280x720  foto rota en gris; pieza 1
                                            con contorno cian que parpadea (hub del 1-1)
               hub_bg_photo_on_00.png       1280x720  pieza 1 recompuesta y encendida
  tiles/       dock_top_{left,center,right}, dock_fill, dock_fill_alt,
               one_way_{left,center,right,single}             64x64
  folders/     folder_locked_00, folder_available_00..01,
               folder_completed_00                             128x128
  local_copy/  local_copy_off_00..01, local_copy_prompt_00..01,
               local_copy_active_00..01                        64x128
  calc/        calc_sleep_00..02, calc_awake_00..03            64x96
  dock_slots/  dock_slot_notes_00, dock_slot_flashlight_00,
               dock_slot_trash_00                              64x96
  icons/       icon_airplane_mode_00, icon_unsaved_00          16x16
               page_dot_current_00, page_dot_other_00          8x8

El fondo, los tiles y las carpetas se dibujan en una rejilla logica de 2x2 px
(como el tileset del Mundo 1); copia local, Calc, huecos e iconos a 1 px (como
la terminal de salida, cuya silueta reutiliza la copia local).

Uso (desde la raiz del repo):
  python3 -I tools/gen_hub_objects.py [--dry-run] [--preview <png> [--scale N]]
                                      [--scene <png>]
--dry-run no escribe nada; --preview guarda una hoja de contacto ampliada (x4 por
defecto); --scene guarda una composicion 1280x720 del hub con el mapa de §2.2.
Validador: tools/validate_hub_objects.py. Pillow puede estar en el site de
usuario: se anade a sys.path a mano para que funcione tambien con python3 -I.
"""
import math
import os
import site
import sys

sys.path.append(site.getusersitepackages())
from PIL import Image, ImageDraw  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(REPO, "assets", "palettes", "hub.gpl")
OUT = "assets/sprites/hub"


def load_gpl(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            p = s.split()
            if len(p) >= 4 and all(v.isdigit() for v in p[:3]):
                out[p[3]] = tuple(int(v) for v in p[:3]) + (255,)
    return out


PAL = load_gpl(GPL)
FP = PAL["fondo_profundo"]
SO = PAL["sombra"]
PA = PAL["panel"]
DK = PAL["dock"]
BA = PAL["base"]
GA = PAL["gris_apagado"]
GF = PAL["gris_foto"]
TR = PAL["traza"]
BO = PAL["borde"]
TT = PAL["texto_tenue"]
TC = PAL["texto_claro"]
CT = PAL["cian_tenue"]
CA = PAL["acento_cian"]
CB = PAL["cian_brillo"]
AM = PAL["ambar"]
AS = PAL["ambar_sombra"]
CLEAR = (0, 0, 0, 0)


class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.img = Image.new("RGBA", (w, h), fill)
        self.px = self.img.load()
        self.w, self.h = w, h

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < self.w and 0 <= y < self.h else CLEAR

    def rect(self, x0, y0, x1, y1, c):  # inclusivo
        for y in range(max(y0, 0), min(y1, self.h - 1) + 1):
            for x in range(max(x0, 0), min(x1, self.w - 1) + 1):
                self.px[x, y] = c

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def box(self, x0, y0, x1, y1, fill, outline=FP, cut=True):
        """Caja con contorno de 1 px y esquinas cortadas."""
        self.rect(x0, y0, x1, y1, outline)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
        if cut:
            for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
                self.p(x, y, CLEAR)

    def stamp(self, ox, oy, rows, cmap):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in cmap:
                    self.p(ox + i, oy + j, cmap[ch])

    def halo(self, color):
        """Anillo de 1 px alrededor de lo opaco (no pisa lo opaco)."""
        ring = set()
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3] == 255:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        q = (x + dx, y + dy)
                        if 0 <= q[0] < self.w and 0 <= q[1] < self.h and self.px[q][3] == 0:
                            ring.add(q)
        for q in ring:
            self.px[q] = color

    def x2(self):
        return self.img.resize((self.w * 2, self.h * 2), Image.NEAREST)


def trace(cv, pts, color=TR, node=BO):
    """Traza de circuito de 1 px por una polilinea (tramos horizontales, verticales o a 45
    grados) con nodos de 2x2 en los extremos."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(n + 1):
            cv.p(x0 + (x1 - x0) * k // n, y0 + (y1 - y0) * k // n, color)
    for x, y in (pts[0], pts[-1]):
        cv.rect(x - 1, y - 1, x, y, node)


# ------------------------------------------------------------------ fondo (640x360 x2)
BG_W, BG_H = 640, 360
PHOTO = (112, 40, 528, 236)  # rectangulo de la foto (logico, inclusivo)
_TL, _TRc, _BR, _BL = (0, 0), (416, 0), (416, 196), (0, 196)
_A, _B, _C, _D = (118, 0), (268, 0), (238, 52), (180, 64)
_E, _F, _H, _I = (0, 110), (416, 88), (308, 196), (268, 130)
# Cinco piezas (coordenadas locales de la foto). La 1 es la de arriba al centro.
PIECES = [
    [_A, _B, _C, _D],
    [_TL, _A, _D, _E],
    [_B, _TRc, _F, _C],
    [_E, _D, _C, _I, _H, _BL],
    [_C, _F, _BR, _H, _I],
]
# Desplazamiento de cada pieza («desordenada»); la 1 vuelve a (0, 0) al encenderse.
OFFSETS = [(-1, -3), (-2, 1), (2, -1), (-1, 2), (2, 2)]


def photo_content():
    """La foto entera (en gris): cielo, sol, nubes y colinas. Contenido neutro a proposito:
    el diseno no dice que muestra la foto de Isak."""
    w, h = 417, 197
    cv = Canvas(w, h, GA)
    # Sol (sobre la pieza 1) con un aro de luz.
    sx, sy, r = 196, 30, 15
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - sx, y - sy)
            if d <= r:
                cv.px[x, y] = GF
    # Nubes: trazos horizontales.
    for x0, x1, y in ((40, 96, 34), (56, 120, 40), (300, 352, 26), (284, 330, 32), (232, 262, 58)):
        cv.hline(x0, x1, y, GF)
    # Colinas: lejana (base) y cercana (base) con borde de luz gris_foto.
    for x in range(w):
        far = int(108 + 14 * math.sin(x / 38.0) + 8 * math.sin(x / 17.0 + 1.3))
        near = int(146 + 18 * math.sin(x / 61.0 + 2.1) + 5 * math.sin(x / 13.0))
        cv.vline(x, far, h - 1, BA)
        cv.p(x, far, GF)
        cv.vline(x, near, h - 1, DK)
        cv.p(x, near, GA)
    return cv.img


LIT = {GA: CA, GF: CB, BA: CT, DK: CT}


def polygon_mask(poly, w, h):
    m = Image.new("1", (w, h), 0)
    ImageDraw.Draw(m).polygon(poly, fill=1, outline=1)
    return m


def background(state, frame):
    """state: 'off' (pieza 1 gris con contorno cian; frame 1 = contorno tenue) u 'on'."""
    cv = Canvas(BG_W, BG_H, BA)
    # Trazas de circuito a los lados de la foto y bajando hacia el dock.
    for pts in ([(0, 64), (52, 64), (64, 76), (96, 76)],
                [(0, 132), (40, 132), (52, 120), (92, 120)],
                [(0, 212), (60, 212), (76, 228), (76, 268)],
                [(20, 288), (20, 252), (36, 236), (96, 236)],
                [(639, 58), (588, 58), (576, 70), (544, 70)],
                [(639, 150), (604, 150), (592, 138), (548, 138)],
                [(639, 226), (580, 226), (566, 240), (566, 272)],
                [(256, 272), (300, 272), (312, 260), (420, 260), (432, 272), (480, 272)]):
        trace(cv, pts)
    # Marco de la foto (hueco en sombra).
    x0, y0, x1, y1 = PHOTO
    cv.rect(x0 - 7, y0 - 7, x1 + 7, y1 + 7, FP)
    cv.rect(x0 - 6, y0 - 6, x1 + 6, y1 + 6, SO)
    cv.hline(x0 - 6, x1 + 6, y0 - 6, PA)
    cv.vline(x0 - 6, y0 - 6, y1 + 6, PA)
    photo = photo_content()
    w, h = photo.size
    lit = state == "on"
    for i, poly in enumerate(PIECES):
        dx, dy = (0, 0) if (i == 0 and lit) else OFFSETS[i]
        mask = polygon_mask(poly, w, h)
        src = photo.load()
        mpx = mask.load()
        pts = [(x, y) for y in range(h) for x in range(w) if mpx[x, y]]
        inside = set(pts)
        for x, y in pts:
            c = src[x, y]
            if i == 0 and lit:
                c = LIT.get(c, c)
            cv.p(x0 + x + dx, y0 + y + dy, c)
        # Contorno de la pieza (borde interior de 1 px).
        if i == 0 and not lit:
            edge = CA if frame == 0 else CT
        else:
            edge = FP
        for x, y in pts:
            if any((x + ex, y + ey) not in inside for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.p(x0 + x + dx, y0 + y + dy, edge)
    if lit:
        # Halo cian de 1 px alrededor de la pieza encendida (sobre el hueco en sombra).
        dx, dy = 0, 0
        mask = polygon_mask(PIECES[0], w, h)
        mpx = mask.load()
        inside = {(x, y) for y in range(h) for x in range(w) if mpx[x, y]}
        for x, y in inside:
            for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + ex, y + ey)
                if q not in inside and cv.get(x0 + q[0], y0 + q[1]) == SO:
                    cv.p(x0 + q[0], y0 + q[1], CT)
        # Destello en cruz en el sol.
        sx, sy = x0 + 196, y0 + 30
        cv.p(sx, sy, TC)
        for k in (1, 2, 3):
            for ex, ey in ((k, 0), (-k, 0), (0, k), (0, -k)):
                cv.p(sx + ex, sy + ey, CB if k < 3 else CA)
    return cv.x2()


# ------------------------------------------------------------------ tiles (32x32 x2)
L = 32


def rivet(cv, x, y):
    cv.rect(x, y, x + 2, y + 2, PA)
    cv.rect(x + 1, y + 1, x + 2, y + 2, DK)
    cv.p(x + 2, y + 2, GF)


def dock_top(left_end, right_end):
    cv = Canvas(L, L, DK)
    cv.rect(0, 0, L - 1, 1, BO)
    cv.rect(0, 2, L - 1, 3, GF)
    for x in (5, 21):
        cv.p(x, 2, BO)
    # Traza de circuito grabada en la superficie (cruza el tile: encaja al repetirse).
    cv.hline(0, L - 1, 15, TR)
    cv.rect(12, 14, 13, 15, BO)
    cv.rect(28, 14, 29, 15, BO)
    rivet(cv, 6, 8)
    rivet(cv, 22, 20)
    cv.hline(0, L - 1, 28, PA)
    cv.hline(0, L - 1, 29, FP)
    cv.rect(0, 30, L - 1, 31, SO)
    if left_end:
        cv.rect(0, 0, 1, 29, GF)
        cv.rect(0, 0, 0, 3, BO)
        cv.p(0, 0, CLEAR)
    if right_end:
        cv.rect(L - 2, 2, L - 1, 29, PA)
        cv.p(L - 1, 0, CLEAR)
    return cv.x2()


def dock_fill(alt):
    cv = Canvas(L, L, SO)
    cv.hline(0, L - 1, 9, TR)
    cv.rect(6, 8, 7, 9, BO)
    if alt:
        cv.vline(22, 9, 20, TR)
        cv.rect(21, 20, 22, 21, BO)
        for k in range(3):
            cv.hline(8, 15, 18 + k * 2, FP)
    else:
        cv.p(12, 24, PA)
        cv.p(13, 24, PA)
    return cv.x2()


def one_way(left_end, right_end):
    cv = Canvas(L, L)
    x0 = 1 if left_end else 0
    x1 = L - 2 if right_end else L - 1
    cv.rect(x0, 0, x1, 1, BO)
    cv.rect(x0, 2, x1, 4, DK)
    cv.hline(x0, x1, 3, TR)
    cv.rect(x0, 5, x1, 5, FP)
    for x in (7, 23):
        cv.rect(x, 2, x + 1, 3, BO)
    for sx in (5, 21):
        cv.rect(sx, 6, sx + 1, 9, GF)
        cv.p(sx + 1, 9, PA)
        cv.rect(sx + 2, 6, sx + 2, 8, PA)
    if left_end:
        cv.rect(0, 1, 0, 4, BO)
        cv.p(0, 5, FP)
    if right_end:
        cv.rect(L - 1, 1, L - 1, 4, GF)
        cv.p(L - 1, 5, FP)
    return cv.x2()


# --------------------------------------------------------------- carpetas (64x64 x2)
SLOT = (12, 22, 51, 41)  # hueco para el numero del mundo o la miniatura (logico)
LOCK = [
    "..####..",
    ".#....#.",
    ".#....#.",
    "########",
    "###..###",
    "###..###",
    "####.###",
    "########",
]
CHECK = [
    "..........##",
    ".........###",
    "........###.",
    "##.....###..",
    "###...###...",
    ".###.###....",
    "..#####.....",
    "...###......",
]


def folder_shape(cv, fill, outline, light, shade):
    # Pestana y cuerpo con contorno de 1 px y esquinas cortadas.
    cv.box(4, 7, 26, 16, fill, outline)
    cv.box(2, 12, 61, 59, fill, outline)
    cv.rect(5, 12, 25, 13, fill)  # une la pestana con el cuerpo
    cv.hline(5, 25, 8, light)
    cv.hline(3, 60, 13, light)
    cv.hline(26, 60, 13, light)
    cv.vline(3, 14, 57, light)
    cv.hline(4, 60, 58, shade)
    cv.vline(60, 14, 58, shade)


def folder(state, frame):
    cv = Canvas(64, 64)
    sx0, sy0, sx1, sy1 = SLOT
    if state == "locked":
        folder_shape(cv, GA, FP, GF, BA)
        cv.box(sx0, sy0, sx1, sy1, SO, FP, cut=False)
        cv.hline(sx0 + 1, sx1 - 1, sy1 - 1, PA)
        # Candado (insignia abajo a la derecha).
        cv.box(44, 42, 57, 55, FP, FP)
        cv.stamp(46, 45, LOCK, {"#": TT})
        cv.hline(6, 30, 52, BA)
        cv.rect(30, 51, 31, 52, GF)
    elif state == "available":
        folder_shape(cv, PA, CA, TR, FP)
        cv.box(sx0, sy0, sx1, sy1, FP, CT, cut=False)
        cv.hline(sx0 + 1, sx1 - 1, sy0 + 1, SO)
        # Traza con nodos (circuito limpio) y un tramo encendido.
        cv.hline(6, 40, 51, TR)
        cv.hline(6, 18, 51, CA)
        cv.rect(40, 50, 41, 51, BO)
        cv.rect(5, 50, 6, 51, CA)
        cv.vline(48, 46, 55, TR)
        cv.rect(48, 45, 49, 46, BO)
        if frame == 1:
            cv.halo(CT)
    else:  # completed
        folder_shape(cv, CA, FP, CB, CT)
        cv.box(sx0, sy0, sx1, sy1, CB, CT, cut=False)
        cv.hline(6, 30, 52, CT)
        cv.rect(30, 51, 31, 52, FP)
        cv.stamp(44, 44, CHECK, {"#": FP})
    return cv.x2()


# ------------------------------------------------------------- copia local (64x128)
MON = (4, 30, 59, 75)
SCREEN = (8, 34, 55, 69)
# Disquete de 18x18 (icono de «copia local»).
DISK = [
    "################..",
    "#ssss######ssss##.",
    "#ssss#....#ssss###",
    "#ssss#....#ssss###",
    "#ssss######ssss###",
    "#sssssssssssssss##",
    "#ssssssssssssssss#",
    "#sllllllllllllls##",
    "#sllllllllllllls##",
    "#slddddddddddlls##",
    "#sllllllllllllls##",
    "#slddddddddlllls##",
    "#sllllllllllllls##",
    "#sllllllllllllls##",
    "#sllllllllllllls##",
    "#ssssssssssssssss#",
    "#################.",
]


def disk(cv, x, y, body, label, line, edge):
    cv.stamp(x, y, DISK, {"#": edge, "s": body, "l": label, "d": line, ".": body})


def terminal_body(cv, led):
    """Silueta de exit_terminal (tools/gen_warp_objects.py) con los colores del hub."""
    cv.box(12, 119, 51, 127, PA)
    cv.hline(13, 50, 120, GA)
    cv.hline(13, 50, 126, SO)
    cv.rect(27, 78, 36, 118, FP)
    cv.rect(28, 78, 35, 118, PA)
    cv.vline(28, 78, 118, GA)
    cv.vline(35, 78, 118, SO)
    cv.vline(31, 80, 114, TR)
    cv.rect(31, 115, 32, 116, BO)
    cv.rect(30, 80, 33, 81, BO)
    cv.rect(22, 75, 41, 79, FP)
    cv.rect(23, 76, 40, 78, PA)
    cv.hline(23, 40, 76, GA)
    x0, y0, x1, y1 = MON
    cv.box(x0, y0, x1, y1, PA)
    cv.hline(x0 + 1, x1 - 1, y0 + 1, BO)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, GA)
    cv.vline(x1 - 1, y0 + 2, y1 - 1, SO)
    cv.hline(x0 + 2, x1 - 1, y1 - 1, SO)
    sx0, sy0, sx1, sy1 = SCREEN
    cv.rect(sx0 - 1, sy0 - 1, sx1 + 1, sy1 + 1, FP)
    cv.rect(x1 - 6, y1 - 4, x1 - 5, y1 - 3, led)


def local_copy(state, f):
    cv = Canvas(64, 128)
    sx0, sy0, sx1, sy1 = SCREEN
    dx, dy = 23, 43  # disquete centrado en la pantalla (abajo deja sitio a la flecha)
    if state == "off":
        terminal_body(cv, GA if f == 0 else PA)
        cv.rect(sx0, sy0, sx1, sy1, SO)
        for k in range(6):
            cv.p(sx1 - 10 + k, sy0 + 2 + k, PA)
            cv.p(sx1 - 6 + k, sy0 + 2 + k, PA)
        disk(cv, dx, dy, PA, DK, GA, GA)
    elif state == "prompt":
        terminal_body(cv, CT)
        cv.rect(sx0, sy0, sx1, sy1, SO)
        for xa, ya, xb, yb in ((sx0, sy0, sx1, sy0), (sx0, sy1, sx1, sy1),
                               (sx0, sy0, sx0, sy1), (sx1, sy0, sx1, sy1)):
            cv.rect(xa, ya, xb, yb, CT if f else CA)
        disk(cv, dx, dy, PA, DK, CA, CA)
        # Flecha «copiar aqui» sobre el disquete (parpadea).
        if f == 0:
            arrow(cv, dx + 8, sy0 + 2, CA)
    else:  # active
        terminal_body(cv, CA)
        cv.rect(sx0, sy0, sx1, sy1, CB)
        cv.rect(sx0, sy0, sx1, sy0, CA)
        disk(cv, dx, dy, CT, CB, CA, FP)
        arrow(cv, dx + 8, sy0 + 2 + f * 2, CT)
        # Lineas de progreso a los lados.
        for k in range(3):
            cv.hline(sx0 + 3, sx0 + 10 - k * 2, sy0 + 12 + k * 4 + f, CT)
            cv.hline(sx1 - 10 + k * 2, sx1 - 3, sy0 + 12 + k * 4 + (1 - f), CT)
        if f == 0:
            x0, y0, x1, y1 = MON
            cv.hline(x0 + 1, x1 - 1, y0 - 1, CA)
            cv.vline(x0 - 1, y0 + 1, y1 - 1, CA)
            cv.vline(x1 + 1, y0 + 1, y1 - 1, CA)
    return cv.img


def arrow(cv, x, y, c):
    """Flecha hacia abajo de 3 px de ancho de asta y 7 de alto."""
    cv.rect(x, y, x + 1, y + 3, c)
    cv.hline(x - 2, x + 3, y + 4, c)
    cv.hline(x - 1, x + 2, y + 5, c)


# ------------------------------------------------------------------ Calc (64x96)
CALC = (12, 26, 51, 93)  # cuerpo (inclusivo)
VISOR = (17, 32, 46, 47)
Z_SMALL = ["#####", "...#.", "..#..", ".#...", "#####"]
Z_BIG = ["#######", "#######", "....##.", "...##..", "..##...", ".##....", "#######", "#######"]


def calc_body(cv, fill, light, shade, key, key_light, accent):
    x0, y0, x1, y1 = CALC
    cv.box(x0, y0, x1, y1, fill)
    cv.hline(x0 + 1, x1 - 1, y0 + 1, light)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, light)
    cv.vline(x1 - 1, y0 + 2, y1 - 1, shade)
    cv.hline(x0 + 2, x1 - 1, y1 - 1, shade)
    vx0, vy0, vx1, vy1 = VISOR
    cv.rect(vx0 - 1, vy0 - 1, vx1 + 1, vy1 + 1, FP)
    # Teclado de 4x4 (teclas de 5x5 con bisel); la ultima columna es la de operaciones.
    for r in range(4):
        for c in range(4):
            kx, ky = 17 + c * 8, 53 + r * 9
            col = accent if (c == 3) else key
            cv.rect(kx, ky, kx + 5, ky + 5, FP)
            cv.rect(kx, ky, kx + 4, ky + 4, col)
            cv.hline(kx, kx + 4, ky, key_light if c < 3 else light)
    # Patas sobre el dock.
    cv.rect(16, 94, 21, 95, FP)
    cv.rect(42, 94, 47, 95, FP)


def calc(state, f):
    cv = Canvas(64, 96)
    vx0, vy0, vx1, vy1 = VISOR
    if state == "sleep":
        calc_body(cv, GA, GF, BA, DK, GA, BA)
        cv.rect(vx0, vy0, vx1, vy1, PA)
        # Ojos cerrados (arcos hacia abajo) y boca pequena.
        for ex in (22, 35):
            cv.hline(ex, ex + 5, 39, TT)
            cv.p(ex, 38, TT)
            cv.p(ex + 5, 38, TT)
        cv.hline(29, 32, 44, GA)
        # «z» que sube (3 cuadros).
        if f == 0:
            cv.stamp(48, 18, Z_SMALL, {"#": TT})
        elif f == 1:
            cv.stamp(50, 12, Z_SMALL, {"#": TT})
            cv.stamp(46, 20, Z_SMALL, {"#": GA})
        else:
            cv.stamp(54, 4, Z_BIG, {"#": TT})
            cv.stamp(49, 14, Z_SMALL, {"#": GA})
    else:  # awake
        calc_body(cv, GF, BO, GA, PA, DK, CT)
        cv.rect(vx0, vy0, vx1, vy1, SO)
        cv.hline(vx0, vx1, vy0, PA)
        # Ojos rectangulares a media asta (humor seco); mira a un lado en el cuadro 2;
        # parpadea en el 3.
        look = 1 if f == 2 else 0
        for ex in (22, 35):
            if f == 3:
                cv.hline(ex + look, ex + 5 + look, 39, CA)
            else:
                cv.rect(ex + look, 37, ex + 5 + look, 40, CA)
                cv.hline(ex + look, ex + 5 + look, 36, FP)  # parpado recto
                cv.rect(ex + 1 + look, 38, ex + 2 + look, 39, CB)
        cv.hline(27, 35, 44, CA)
        cv.p(36, 43, CA)  # media sonrisa torcida
        # Tecla «=» encendida que late.
        kx, ky = 17 + 3 * 8, 53 + 3 * 9
        cv.rect(kx, ky, kx + 4, ky + 4, CA if f % 2 == 0 else CT)
        cv.hline(kx + 1, kx + 3, ky + 1, FP)
        cv.hline(kx + 1, kx + 3, ky + 3, FP)
        # LED de encendido.
        cv.rect(45, 29, 46, 30, CA if f % 2 == 0 else CT)
    return cv.img


# --------------------------------------------------------- huecos del dock (64x96)
def slot_base(cv):
    """Zocalo del hueco sobre el dock: placa oscura con contorno apagado."""
    cv.box(8, 86, 55, 95, PA, FP)
    cv.hline(9, 54, 87, GA)
    for x in (16, 47):
        cv.rect(x, 90, x + 1, 91, SO)


def dock_slot(kind):
    cv = Canvas(64, 96)
    slot_base(cv)
    if kind == "notes":
        # Nota adhesiva con esquina doblada y renglones.
        cv.box(14, 36, 49, 85, DK, GA)
        for k in range(8):
            cv.hline(49 - 7 + k, 49, 36 + k, CLEAR)
        for k in range(8):
            cv.p(42 + k, 36 + k, GA)
        cv.vline(42, 36, 43, GA)
        cv.hline(42, 49, 43, GA)
        for i, y in enumerate(range(50, 82, 5)):
            cv.hline(19, 44 - (i % 3) * 5, y, BA)
    elif kind == "flashlight":
        # Linterna vertical: cabeza ancha arriba, cuello y mango con boton.
        cv.box(16, 32, 47, 48, DK, GA)
        cv.hline(18, 45, 35, BA)
        cv.hline(18, 45, 36, BA)
        cv.box(21, 48, 42, 56, DK, GA, cut=False)
        cv.box(24, 56, 39, 85, DK, GA, cut=False)
        cv.rect(29, 62, 34, 68, BA)
        for y in (74, 77, 80):
            cv.hline(27, 36, y, BA)
        # Haz apagado (puntos hacia arriba).
        for k in range(0, 12, 3):
            cv.p(20 - k // 2, 28 - k, BA)
            cv.p(31, 28 - k, BA)
            cv.p(43 + k // 2, 28 - k, BA)
    else:  # trash
        cv.box(25, 30, 38, 36, DK, GA)  # asa
        cv.box(12, 36, 51, 44, DK, GA)  # tapa
        cv.hline(13, 50, 38, BA)
        # Cubo trapezoidal.
        for y in range(45, 86):
            inset = (y - 45) // 7
            cv.hline(15 + inset, 48 - inset, y, DK)
            cv.p(15 + inset, y, GA)
            cv.p(48 - inset, y, GA)
        cv.hline(15 + 5, 48 - 5, 85, GA)
        for x in (24, 31, 32, 39):
            cv.vline(x, 50, 80, BA)
    return cv.img


# ------------------------------------------------------------------ iconos
AIRPLANE = [
    ".......##.......",
    "......####......",
    "......####......",
    "......####......",
    "......####......",
    ".....######.....",
    "...##########...",
    ".##############.",
    "################",
    "##....####....##",
    "......####......",
    "......####......",
    ".....######.....",
    "....########....",
    "....###..###....",
    "................",
]
UNSAVED = [  # disquete con punto de aviso
    "##########......",
    "#ss#####s#s.....",
    "#ss#...#s#ss....",
    "#ss#####s#sss...",
    "#sssssssssssss..",
    "#sllllllllllss..",
    "#sllllllllllss..",
    "#slddddddddlss..",
    "#sllllllllllss..",
    "#slddddddlllss..",
    "#ssssssssssssss.",
    "###############.",
    "................",
    "................",
    "................",
    "................",
]
DOT_FULL = ["..####..", ".######.", "########", "########", "########", "########",
            ".######.", "..####.."]
DOT_RING = ["..####..", ".#....#.", "#......#", "#......#", "#......#", "#......#",
            ".#....#.", "..####.."]


def icon_airplane():
    cv = Canvas(16, 16)
    cv.stamp(0, 0, AIRPLANE, {"#": TC})
    return cv.img


def icon_unsaved():
    cv = Canvas(16, 16)
    cv.stamp(0, 2, UNSAVED[:12], {"#": AS, "s": AM, "l": AS, "d": AM})
    # Punto de aviso arriba a la derecha (forma ademas de color).
    for y in range(0, 5):
        for x in range(11, 16):
            if (x - 13) ** 2 + (y - 2) ** 2 <= 5:
                cv.p(x, y, AM)
    cv.p(13, 2, TC)
    return cv.img


def page_dot(current):
    cv = Canvas(8, 8)
    cv.stamp(0, 0, DOT_FULL if current else DOT_RING, {"#": TC if current else TT})
    return cv.img


# ------------------------------------------------------------------ salida
def outputs():
    """{ruta relativa a assets/sprites/hub: imagen} (orden estable)."""
    out = {}
    out["background/hub_bg_photo_off_00.png"] = background("off", 0)
    out["background/hub_bg_photo_off_01.png"] = background("off", 1)
    out["background/hub_bg_photo_on_00.png"] = background("on", 0)
    out["tiles/dock_top_left_00.png"] = dock_top(True, False)
    out["tiles/dock_top_center_00.png"] = dock_top(False, False)
    out["tiles/dock_top_right_00.png"] = dock_top(False, True)
    out["tiles/dock_fill_00.png"] = dock_fill(False)
    out["tiles/dock_fill_alt_00.png"] = dock_fill(True)
    out["tiles/one_way_left_00.png"] = one_way(True, False)
    out["tiles/one_way_center_00.png"] = one_way(False, False)
    out["tiles/one_way_right_00.png"] = one_way(False, True)
    out["tiles/one_way_single_00.png"] = one_way(True, True)
    out["folders/folder_locked_00.png"] = folder("locked", 0)
    out["folders/folder_available_00.png"] = folder("available", 0)
    out["folders/folder_available_01.png"] = folder("available", 1)
    out["folders/folder_completed_00.png"] = folder("completed", 0)
    for st in ("off", "prompt", "active"):
        for f in range(2):
            out[f"local_copy/local_copy_{st}_{f:02d}.png"] = local_copy(st, f)
    for f in range(3):
        out[f"calc/calc_sleep_{f:02d}.png"] = calc("sleep", f)
    for f in range(4):
        out[f"calc/calc_awake_{f:02d}.png"] = calc("awake", f)
    for k in ("notes", "flashlight", "trash"):
        out[f"dock_slots/dock_slot_{k}_00.png"] = dock_slot(k)
    out["icons/icon_airplane_mode_00.png"] = icon_airplane()
    out["icons/icon_unsaved_00.png"] = icon_unsaved()
    out["icons/page_dot_current_00.png"] = page_dot(True)
    out["icons/page_dot_other_00.png"] = page_dot(False)
    return out


# ------------------------------------------------------------- SpriteFrames
# Recursos SpriteFrames de Godot 4 (assets/sprites/hub/<nombre>_frames.tres) que
# usa el hub (HubRoom, HubStation, FolderStation): (animacion, prefijo de los
# PNG, cuadros, fps, bucle). Los escribe main() junto a los PNG y el validador
# comprueba que estan al dia.
FRAMES = {
    "hub_bg_frames.tres": [("off", "background/hub_bg_photo_off", 2, 1.5, True),
                           ("on", "background/hub_bg_photo_on", 1, 1.0, True)],
    "local_copy_frames.tres": [("off", "local_copy/local_copy_off", 2, 2.0, True),
                               ("prompt", "local_copy/local_copy_prompt", 2, 3.0, True),
                               ("active", "local_copy/local_copy_active", 2, 6.0, True)],
    "folder_frames.tres": [("locked", "folders/folder_locked", 1, 1.0, True),
                           ("available", "folders/folder_available", 2, 2.0, True),
                           ("completed", "folders/folder_completed", 1, 1.0, True)],
    "calc_frames.tres": [("sleep", "calc/calc_sleep", 3, 2.0, True),
                         ("awake", "calc/calc_awake", 4, 3.0, True)],
}


def frames_resources():
    """{ruta relativa a assets/sprites/hub: texto del .tres} (orden estable)."""
    out = {}
    for name, anims in FRAMES.items():
        out[name] = sprite_frames_tres([
            (anim, ["res://%s/%s_%02d.png" % (OUT, prefix, i) for i in range(n)], fps, loop)
            for anim, prefix, n, fps, loop in anims])
    return out


def sprite_frames_tres(anims):
    """Texto de un recurso SpriteFrames de Godot 4 con las animaciones dadas
    (mismo formato que tools/gen_warp_objects.py)."""
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


def preview(imgs, path, scale=4):
    """Hoja de contacto: una fila por animacion/estado (el fondo, a x1 aparte)."""
    groups = {}
    for k, im in imgs.items():
        if k.startswith("background/"):
            continue
        groups.setdefault(os.path.basename(k).rsplit("_", 1)[0], []).append(im)
    pad = 6
    rows = []
    row, wsum = [], 0
    for name, ims in groups.items():
        w = sum(im.width + pad for im in ims)
        if row and wsum + w > 300:
            rows.append(row)
            row, wsum = [], 0
        row.append(ims)
        wsum += w
    rows.append(row)
    sheet_w = 320 * scale
    sprite_h = sum(max(im.height for ims in r for im in ims) + pad for r in rows) * scale + pad * scale
    bgs = [im for k, im in imgs.items() if k.startswith("background/")]
    bg_h = sum(im.height // 2 + 8 for im in bgs)
    sheet = Image.new("RGBA", (max(sheet_w, 640), sprite_h + bg_h + 8), FP)
    y = pad * scale
    for r in rows:
        x = pad * scale
        for ims in r:
            for im in ims:
                big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
                cell = Image.new("RGBA", big.size, BA)
                cell.alpha_composite(big)
                sheet.alpha_composite(cell, (x, y))
                x += (im.width + pad) * scale
            x += pad * scale
        y += (max(im.height for ims in r for im in ims) + pad) * scale
    for im in bgs:
        sheet.alpha_composite(im.resize((im.width // 2, im.height // 2), Image.NEAREST), (0, y))
        y += im.height // 2 + 8
    sheet.save(path)


def scene(imgs, path, state="off"):
    """Composicion 1280x720 del hub del Mundo 1 segun el mapa de §2.2 (col, fila)."""
    T = 64
    bg = imgs["background/hub_bg_photo_%s_00.png" % state].copy()

    def put(key, col, row, dx=0, dy=0, bottom=False):
        im = imgs[key]
        x, y = col * T + dx, row * T + dy
        if bottom:  # apoyado sobre el borde inferior de la fila
            y = (row + 1) * T - im.height + dy
        bg.alpha_composite(im, (x, y))

    for c in range(20):
        key = "dock_top_left" if c == 0 else "dock_top_right" if c == 19 else "dock_top_center"
        put(f"tiles/{key}_00.png", c, 9)
        put("tiles/dock_fill_alt_00.png" if c % 5 == 2 else "tiles/dock_fill_00.png", c, 10)
    for c0, st in ((4, "completed"), (10, "available"), (16, "locked")):
        for c in range(c0 - 1, c0 + 3):
            key = "one_way_left" if c == c0 - 1 else "one_way_right" if c == c0 + 2 else "one_way_center"
            put(f"tiles/{key}_00.png", c, 5)
        put(f"folders/folder_{st}_00.png", c0, 3)
    put("local_copy/local_copy_active_00.png", 1, 7, dx=32)
    put("calc/calc_sleep_02.png", 7, 8, bottom=True, dy=-64 + 64 - 0)
    for c, k in ((10, "notes"), (13, "flashlight"), (16, "trash")):
        put(f"dock_slots/dock_slot_{k}_00.png", c, 8, bottom=True)
    # HUD (franja de prueba): Modo Avion, «sin guardar» e indicador de pagina.
    hud = Image.new("RGBA", (1280, 40), FP)
    bg.alpha_composite(hud, (0, 0))
    for key, x, y, s in (("icons/icon_airplane_mode_00.png", 16, 4, 2), ("icons/icon_unsaved_00.png", 1220, 4, 2),
                         ("icons/page_dot_current_00.png", 120, 690, 2)):
        im = imgs[key]
        bg.alpha_composite(im.resize((im.width * s, im.height * s), Image.NEAREST), (x, y))
    bg.save(path)


def main(argv):
    imgs = outputs()
    if "--dry-run" not in argv:
        for k, im in imgs.items():
            p = os.path.join(REPO, OUT, k)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            im.save(p, optimize=True)
        for k, text in frames_resources().items():
            with open(os.path.join(REPO, OUT, k), "w", encoding="utf-8") as fh:
                fh.write(text)
    if "--preview" in argv:
        preview(imgs, argv[argv.index("--preview") + 1],
                int(argv[argv.index("--scale") + 1]) if "--scale" in argv else 4)
    if "--scene" in argv:
        scene(imgs, argv[argv.index("--scene") + 1])
        p = argv[argv.index("--scene") + 1]
        scene(imgs, p.replace(".png", "_on.png"), "on")
    print(f"{len(imgs)} PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
