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
  notas/       notas_powered_off_00 (apagada, antes de la presentacion),
               notas_off_00..01, notas_prompt_00..01,
               notas_active_00..01 (reskin de la copia local)  64x128
  calc/        calc_off_00 (apagada hasta conocerla),
               calc_sleep_00..02, calc_awake_00..03            64x96
  dock_slots/  dock_slot_flashlight_00, dock_slot_trash_00     64x96
  papelera/    papelera_active_00..03 (con contenido: parpadea en
               acento_cian y se tambalea), papelera_emptying_00..03
               (se vacia al recuperar), papelera_empty_00 (activada y
               vacia); la dormida es dock_slot_trash_00             64x96
  album/       album_cell_00, album_cell_selected_00 (marco de
               ficha del album de Notas)                       40x40
               album_folder_closed_00, album_folder_open_00,
               album_folder_locked_00 (carpeta de un mundo en el
               album: visitado, elegida/abierta, sin alcanzar)  32x32
  icons/       icon_airplane_mode_00, icon_unsaved_00          16x16
               icon_settings_00 (ajustes: abre el menu de pausa)
               icon_notas_00 (quien habla en el cuadro de texto: Notas)
               world_icon_m1_00 (miniatura del Mundo 1:
               campana de notificaciones, en la carpeta)       16x16
               page_dot_current_00, page_dot_other_00          8x8

El fondo, los tiles y las carpetas se dibujan en una rejilla logica de 2x2 px
(como el tileset del Mundo 1); Notas, Calc, huecos e iconos a 1 px (como
la terminal de salida, cuya silueta reutiliza Notas).

Uso (desde la raiz del repo):
  python3 -I tools/gen_hub_objects.py [--dry-run] [--preview <png> [--scale N]]
                                      [--scene <png>]
--dry-run no escribe nada; --preview guarda una hoja de contacto ampliada (x4 por
defecto); --scene guarda una composicion 1280x720 del hub con el mapa de §2.2.
Validador: tools/validate_hub_objects.py. Pillow puede estar en el site de
usuario: se anade a sys.path a mano para que funcione tambien con python3 -I.
"""
import json
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


# ------------------------------------------------------------- Notas (64x128)
# Reskin de la antigua «copia local» (docs/propuesta-asistentes-y-vidas.md §2.2 y
# §9): el mismo monitor (silueta de exit_terminal) con un bloc de notas con
# carita en la pantalla. Estados: powered_off (apagada: pantalla negra, sin LED,
# antes de que Eco la presente), off (encendida en reposo), prompt (Isak cerca) y
# active (panel abierto: escribe).
MON = (4, 30, 59, 75)
SCREEN = (8, 34, 55, 69)
PAD = (18, 38, 43, 67)  # hoja del bloc (inclusivo)


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
    if led is not None:
        cv.rect(x1 - 6, y1 - 4, x1 - 5, y1 - 3, led)


def notepad(cv, page, edge, ring, line, face, eyes="open", lines=3, ox=0, oy=0):
    """Hoja del bloc con espiral arriba, carita y renglones."""
    x0, y0, x1, y1 = PAD
    x0, y0, x1, y1 = x0 + ox, y0 + oy, x1 + ox, y1 + oy
    cv.box(x0, y0, x1, y1, page, edge)
    # Espiral: anillas sobre el borde superior.
    for x in range(x0 + 3, x1 - 1, 4):
        cv.rect(x, y0 - 2, x, y0 + 1, ring)
    # Carita: ojos de 2x2 (o arcos) y sonrisa.
    ey = y0 + 9
    for ex in (x0 + 7, x1 - 8):
        if eyes == "open":
            cv.rect(ex, ey, ex + 1, ey + 1, face)
        elif eyes == "closed":
            cv.hline(ex - 1, ex + 2, ey + 1, face)
        else:  # happy: arco hacia arriba
            cv.hline(ex, ex + 1, ey, face)
            cv.p(ex - 1, ey + 1, face)
            cv.p(ex + 2, ey + 1, face)
    mx = (x0 + x1) // 2
    cv.hline(mx - 3, mx + 2, ey + 6, face)
    cv.p(mx - 4, ey + 5, face)
    cv.p(mx + 3, ey + 5, face)
    for k in range(lines):
        y = y0 + 20 + k * 3
        if y < y1 - 1:
            cv.hline(x0 + 3, x1 - 3 - (k % 2) * 5, y, line)


def pencil(cv, x, y, body, tip):
    """Lapiz diagonal de 7 px que apunta abajo a la izquierda (x, y = punta)."""
    for k in range(1, 7):
        cv.p(x + k, y - k, body)
        cv.p(x + k + 1, y - k, body)
    cv.p(x, y, tip)


def notas(state, f):
    cv = Canvas(64, 128)
    sx0, sy0, sx1, sy1 = SCREEN
    if state == "powered_off":
        terminal_body(cv, None)
        cv.rect(sx0, sy0, sx1, sy1, FP)
        # Reflejo apagado y la hoja casi invisible.
        for k in range(6):
            cv.p(sx1 - 10 + k, sy0 + 2 + k, SO)
        x0, y0, x1, y1 = PAD
        cv.rect(x0, y0, x1, y0, SO)
        cv.rect(x0, y1, x1, y1, SO)
        cv.vline(x0, y0, y1, SO)
        cv.vline(x1, y0, y1, SO)
    elif state == "off":
        terminal_body(cv, GA if f == 0 else PA)
        cv.rect(sx0, sy0, sx1, sy1, SO)
        notepad(cv, DK, GA, GF, BA, TT, "open" if f == 0 else "closed")
    elif state == "prompt":
        terminal_body(cv, CT)
        cv.rect(sx0, sy0, sx1, sy1, SO)
        for xa, ya, xb, yb in ((sx0, sy0, sx1, sy0), (sx0, sy1, sx1, sy1),
                               (sx0, sy0, sx0, sy1), (sx1, sy0, sx1, sy1)):
            cv.rect(xa, ya, xb, yb, CT if f else CA)
        notepad(cv, TC, BO, CA, TR, FP, "open", oy=-1 if f == 0 else 0)
        pencil(cv, 46, 62, AM, FP)
    else:  # active
        terminal_body(cv, CA)
        cv.rect(sx0, sy0, sx1, sy1, CT)
        cv.rect(sx0, sy0, sx1, sy0, CA)
        notepad(cv, TC, CA, CB, TR, FP, "happy", lines=3 + f)
        # El lapiz escribe el renglon nuevo.
        x0, y0, x1, y1 = PAD
        y = y0 + 20 + (3 + f) * 3
        pencil(cv, x1 - 6 - f * 4, min(y, y1 - 2), AM, FP)
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
    if state == "off":
        # Apagada (antes de conocerla, propuesta §2.3 y §9): el cuerpo de Calc
        # dormida, mas oscuro, con la pantalla negra y sin animacion.
        calc_body(cv, BA, GA, DK, PA, DK, PA)
        cv.rect(vx0, vy0, vx1, vy1, FP)
        for k in range(5):
            cv.p(vx1 - 7 + k, vy0 + 2 + k, SO)
    elif state == "sleep":
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
    if kind == "flashlight":
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


# ------------------------------------------------------------- papelera (64x96)
# Papelera del hub (docs/propuesta-asistentes-y-vidas.md §2.5 y §9, paso 12 de
# §10): el mismo cubo que el hueco apagado (dock_slot_trash) pero encendido, con
# las flechas de reciclaje como traza de circuito. Estados: active (con
# contenido: borde que parpadea acento_cian / cian_tenue, archivos asomando bajo
# la tapa y tambaleo de 1 px con la tapa que salta), emptying (la tapa se abre y
# los archivos salen volando, 4 cuadros) y empty (activada y vacia, quieta).
# Sin rojo.
BIN_WOBBLE = (0, 1, 0, -1)
BIN_LID_LIFT = (0, 2, 0, 1)


def bin_body(cv, dx, fill, edge, mark):
    for y in range(45, 86):
        inset = (y - 45) // 7
        cv.hline(15 + inset + dx, 48 - inset + dx, y, fill)
        cv.p(15 + inset + dx, y, edge)
        cv.p(48 - inset + dx, y, edge)
    cv.hline(20 + dx, 43 + dx, 85, edge)
    # Flechas de reciclaje (triangulo de tres trazos con punta) en el frente.
    cx = 31 + dx
    trace(cv, [(cx - 6, 74), (cx, 62), (cx + 6, 74), (cx - 6, 74)], mark, mark)
    cv.p(cx - 1, 63, mark)
    cv.p(cx + 1, 63, mark)
    cv.rect(cx - 1, 68, cx + 1, 70, fill)


def bin_lid(cv, dx, lift, tilt, fill, edge):
    y0 = 36 - lift
    for x in range(12, 52):
        # Tapa inclinada: sube `tilt` px hacia la derecha.
        dy = (x - 12) * tilt // 40
        cv.vline(x + dx, y0 - dy, y0 + 8 - dy, fill)
        cv.p(x + dx, y0 - dy, edge)
        cv.p(x + dx, y0 + 8 - dy, edge)
    cv.vline(12 + dx, y0, y0 + 8, edge)
    cv.vline(51 + dx, y0 - tilt, y0 + 8 - tilt, edge)
    cv.box(25 + dx, y0 - 6 - tilt // 2, 38 + dx, y0 - tilt // 2, fill, edge)


def file_icon(cv, x, y, paper=TC, line=TR, corner=BO):
    """Archivo de 7x9 (hoja con esquina doblada y dos renglones)."""
    cv.rect(x, y, x + 6, y + 8, paper)
    cv.rect(x + 5, y, x + 6, y + 1, corner)
    cv.hline(x + 1, x + 4, y + 3, line)
    cv.hline(x + 1, x + 5, y + 5, line)
    cv.hline(x, x + 6, y + 8, line)


def papelera(state, f):
    cv = Canvas(64, 96)
    slot_base(cv)
    if state == "active":
        dx = BIN_WOBBLE[f]
        edge = CA if f % 2 == 0 else CT
        file_icon(cv, 18 + dx, 29 - BIN_LID_LIFT[f] * 2)
        file_icon(cv, 37 + dx, 30 - BIN_LID_LIFT[f], TC, TR, AM)
        bin_body(cv, dx, BA, edge, edge)
        bin_lid(cv, dx, BIN_LID_LIFT[f], 2 if f == 1 else 0, GA, edge)
        # Aviso: punto que parpadea sobre el asa (forma ademas de color).
        if f % 2 == 0:
            cv.rect(30 + dx, 22, 33 + dx, 25, CA)
            cv.rect(31 + dx, 21, 32 + dx, 26, CA)
    elif state == "emptying":
        bin_body(cv, 0, BA, CA, CA)
        bin_lid(cv, 0, 4 + f * 2, 6 + f * 2, GA, CA)
        for k, (x0, y0) in enumerate(((18, 30), (37, 28))):
            y = y0 - f * 7 - k * 3
            if f < 3:
                file_icon(cv, x0 + (k * 2 - 1) * f * 2, y, TC, TR, AM if k else BO)
        if f == 3:
            for x, y in ((20, 8), (42, 6), (31, 2)):
                cv.rect(x, y, x + 1, y + 1, CB)
    else:  # empty
        bin_body(cv, 0, PA, CT, CT)
        bin_lid(cv, 0, 0, 0, BA, CT)
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


def icon_settings():
    """Ajustes (menu de pausa) en el HUD del hub, junto al Modo Avion: engranaje
    de 8 dientes en texto_claro con sombra texto_tenue abajo a la derecha y el
    eje como un nodo de circuito en acento_cian (forma ademas de color)."""
    cv = Canvas(16, 16)
    cx = cy = 7.5
    for y in range(16):
        for x in range(16):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            a = (math.degrees(math.atan2(dy, dx)) + 360.0) % 45.0
            tooth = 11.0 <= a <= 34.0
            if 2.4 <= r <= 5.2 or (tooth and 5.2 < r <= 7.6):
                cv.p(x, y, TT if dx + dy > 4.0 else TC)
    cv.rect(7, 7, 8, 8, CA)
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


# Miniatura del mundo en su carpeta (2026-10-15, decision del usuario): un
# icono de 16x16 por mundo junto al numero. Mundo 1 (Notificaciones): campana.
# Los mundos bloqueados no llevan miniatura (no se adelanta nada).
# Semiancho de la campana por fila (centro entre x=7 y x=8), filas 3-11.
BELL_HALF = [2, 3, 4, 4, 4, 4, 4, 5, 6]


def world_icon_bell():
    cv = Canvas(16, 16)
    cv.rect(7, 1, 8, 2, TT)  # asa
    cv.p(7, 1, TC)
    for i, w in enumerate(BELL_HALF):
        y = 3 + i
        x0, x1 = 8 - w, 7 + w
        cv.hline(x0, x1, y, TC)
        cv.hline(x1 - 1, x1, y, TT)  # sombra a la derecha
        cv.p(x0, y, CB if i < 6 else TC)  # brillo a la izquierda
    cv.hline(1, 14, 12, TT)  # borde inferior
    cv.hline(2, 13, 12, BO)
    cv.rect(7, 13, 8, 14, CA)  # badajo: el aviso, en cian
    cv.halo(FP)  # contorno: se lee en la carpeta disponible y en la completada
    return cv.img


def icon_notas():
    """Icono de Notas para el cuadro de texto (quien habla): bloc con carita."""
    cv = Canvas(16, 16)
    cv.box(2, 2, 13, 15, TC, BO)
    for x in (4, 7, 10):
        cv.rect(x, 1, x, 3, CA)
    cv.rect(5, 6, 5, 7, FP)
    cv.rect(10, 6, 10, 7, FP)
    cv.hline(6, 9, 10, FP)
    cv.p(5, 9, FP)
    cv.p(10, 9, FP)
    cv.hline(4, 11, 13, TR)
    return cv.img


# ------------------------------------------------------- album de Notas (celdas)
# Marco de ficha del album (docs/propuesta-asistentes-y-vidas.md §3.5 y §9): 40x40
# px de arte (x2 en pantalla = 80 px; la ficha de 64 px de pantalla va centrada).
# cell: celda normal; cell_selected: la elegida, con borde acento_cian y
# esquinas marcadas (forma ademas de color).
CELL = 40


def album_cell(selected):
    cv = Canvas(CELL, CELL)
    cv.box(0, 0, CELL - 1, CELL - 1, FP, CA if selected else GA)
    cv.hline(2, CELL - 3, 1, PA)
    if selected:
        cv.box(1, 1, CELL - 2, CELL - 2, FP, CT, cut=False)
        cv.box(0, 0, CELL - 1, CELL - 1, CLEAR, CA)
        cv.rect(2, 2, CELL - 3, CELL - 3, FP)
        for x, y in ((1, 1), (CELL - 4, 1), (1, CELL - 4), (CELL - 4, CELL - 4)):
            cv.rect(x, y, x + 2, y + 2, CA)
    return cv.img


# Carpetas por mundo del album (2026-10-16): mismo dibujo que las carpetas del
# hub (pestana y cuerpo con contorno y esquinas cortadas) a 32x32. closed:
# mundo visitado (panel con borde acento_cian y traza); open: la elegida o la
# abierta (tapa abatida y una ficha asomando, forma ademas de color); locked:
# mundo sin alcanzar (gris apagado con candado; el album escribe «???»).
def album_folder(state):
    cv = Canvas(32, 32)
    if state == "locked":
        fill, outline, light, shade = GA, FP, GF, BA
    else:
        fill, outline, light, shade = PA, CA, TR, FP
    # Pestana y cuerpo trasero.
    cv.box(3, 5, 14, 11, fill, outline)
    cv.box(1, 8, 30, 28, fill, outline)
    cv.rect(4, 8, 13, 9, fill)
    cv.hline(4, 13, 6, light)
    cv.hline(2, 29, 9, light)
    if state == "open":
        # Ficha asomando y tapa abatida hacia delante (trapecio mas claro).
        cv.box(6, 4, 25, 18, TC, BO)
        cv.hline(9, 22, 8, TR)
        cv.hline(9, 19, 11, TR)
        cv.rect(20, 11, 21, 12, CA)
        for y in range(15, 30):
            k = (y - 15) // 5
            x0, x1 = 0 + k, 31 - k
            cv.hline(x0, x1, y, outline if y in (15, 29) else BO if y == 16 else PA)
            cv.p(x0, y, outline)
            cv.p(x1, y, outline)
        cv.p(0, 15, CLEAR)
        cv.p(31, 15, CLEAR)
        cv.hline(5, 18, 24, TR)
        cv.rect(18, 23, 19, 24, CA)
        return cv.img
    cv.vline(2, 10, 26, light)
    cv.hline(2, 29, 27, shade)
    cv.vline(29, 10, 27, shade)
    if state == "locked":
        cv.box(19, 16, 28, 26, FP, FP)
        cv.stamp(20, 17, LOCK, {"#": TT})
        cv.hline(4, 15, 24, BA)
    else:
        cv.hline(4, 20, 24, TR)
        cv.hline(4, 9, 24, CA)
        cv.rect(20, 23, 21, 24, BO)
        cv.vline(25, 13, 22, TR)
        cv.rect(25, 12, 26, 13, BO)
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
    out["notas/notas_powered_off_00.png"] = notas("powered_off", 0)
    for st in ("off", "prompt", "active"):
        for f in range(2):
            out[f"notas/notas_{st}_{f:02d}.png"] = notas(st, f)
    out["calc/calc_off_00.png"] = calc("off", 0)
    for f in range(3):
        out[f"calc/calc_sleep_{f:02d}.png"] = calc("sleep", f)
    for f in range(4):
        out[f"calc/calc_awake_{f:02d}.png"] = calc("awake", f)
    for k in ("flashlight", "trash"):
        out[f"dock_slots/dock_slot_{k}_00.png"] = dock_slot(k)
    for f in range(4):
        out[f"papelera/papelera_active_{f:02d}.png"] = papelera("active", f)
    for f in range(4):
        out[f"papelera/papelera_emptying_{f:02d}.png"] = papelera("emptying", f)
    out["papelera/papelera_empty_00.png"] = papelera("empty", 0)
    out["icons/icon_airplane_mode_00.png"] = icon_airplane()
    out["icons/icon_unsaved_00.png"] = icon_unsaved()
    out["icons/icon_settings_00.png"] = icon_settings()
    out["icons/world_icon_m1_00.png"] = world_icon_bell()
    out["icons/icon_notas_00.png"] = icon_notas()
    out["album/album_cell_00.png"] = album_cell(False)
    out["album/album_cell_selected_00.png"] = album_cell(True)
    for st in ("closed", "open", "locked"):
        out[f"album/album_folder_{st}_00.png"] = album_folder(st)
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
    "notas_frames.tres": [("powered_off", "notas/notas_powered_off", 1, 1.0, True),
                          ("off", "notas/notas_off", 2, 1.5, True),
                          ("prompt", "notas/notas_prompt", 2, 3.0, True),
                          ("active", "notas/notas_active", 2, 4.0, True)],
    "folder_frames.tres": [("locked", "folders/folder_locked", 1, 1.0, True),
                           ("available", "folders/folder_available", 2, 2.0, True),
                           ("completed", "folders/folder_completed", 1, 1.0, True)],
    "calc_frames.tres": [("powered_off", "calc/calc_off", 1, 1.0, True),
                         ("sleep", "calc/calc_sleep", 3, 2.0, True),
                         ("awake", "calc/calc_awake", 4, 3.0, True)],
    "papelera_frames.tres": [("dormant", "dock_slots/dock_slot_trash", 1, 1.0, True),
                             ("active", "papelera/papelera_active", 4, 6.0, True),
                             ("emptying", "papelera/papelera_emptying", 4, 8.0, False),
                             ("empty", "papelera/papelera_empty", 1, 1.0, True)],
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
    # Repisas y carpetas donde las pone el juego (data/hub.json: worlds y folders;
    # repisa shelf_height_px sobre el dock, alcanzable de un salto).
    with open(os.path.join(REPO, "data", "hub.json"), encoding="utf-8") as fh:
        hub = json.load(fh)
    floor_y = int(hub["room"]["floor_row"]) * T
    shelf_y = floor_y - int(hub["folders"]["shelf_height_px"])
    extra = int(hub["folders"]["shelf_extra_tiles"])
    # Solo los mundos con carpeta en el hub (con col; los 4-6 solo tienen nombre).
    folder_worlds = [w for w in hub["worlds"] if "col" in w]
    for world, st in zip(folder_worlds, ("available", "locked", "locked")):
        c0 = int(world["col"])
        for c in range(c0 - extra, c0 + 2 + extra):
            key = "one_way_left" if c == c0 - extra else "one_way_right" if c == c0 + 1 + extra else "one_way_center"
            bg.alpha_composite(imgs[f"tiles/{key}_00.png"], (c * T, shelf_y))
        fy = shelf_y - 128 + int(hub["folders"].get("folder_sink_px", 0))
        bg.alpha_composite(imgs[f"folders/folder_{st}_00.png"], (c0 * T, fy))
        mini = os.path.basename(world.get("miniature", ""))
        if st != "locked" and f"icons/{mini}" in imgs:
            mx, my, mw, mh = hub["folders"]["miniature_rect_px"]
            bg.alpha_composite(imgs[f"icons/{mini}"].resize((mw, mh), Image.NEAREST), (c0 * T + mx, fy + my))
    put("notas/notas_active_00.png", 1, 7)
    put("calc/calc_off_00.png", 7, 8, bottom=True, dy=-64 + 64 - 0)
    put("dock_slots/dock_slot_flashlight_00.png", 13, 8, bottom=True)
    put("dock_slots/dock_slot_trash_00.png", 10, 8, bottom=True)  # papelera dormida
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
