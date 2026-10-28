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
               folder_completed_00, folder_all_done_00 (carpeta
               generica de respaldo) y, por mundo con carpeta,
               folder_<m>_{locked,available_00..01,completed,all_done}
               (icono grande del mundo, 2026-10-26)            128x128
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
  charger/     charger_ready_00..03, charger_cooling_00..07,
               charger_spent_00 (cargador de energia del dock: el
               dibujo de tools/gen_energy_objects.py con los colores
               del Mundo 1 cambiados por los del hub, CHARGER_REMAP) 32x64
  album/       album_cell_00, album_cell_selected_00 (marco de
               ficha del album de Notas)                       40x40
               album_folder_closed_00, album_folder_open_00,
               album_folder_locked_00 (carpeta de un mundo en el
               album: visitado, elegida/abierta, sin alcanzar)  32x32
  icons/       icon_airplane_mode_00, icon_unsaved_00          16x16
               icon_settings_00 (ajustes: abre el menu de pausa)
               icon_notas_00 (quien habla en el cuadro de texto: Notas)
               icon_calc_00 (quien habla en el cuadro de texto: Calc,
               con su visor despierto; 2026-10-17, tanda H3)
               icon_papelera_00 (quien habla en el cuadro de texto: la
               Papelera del 4-2, su cubo con la tapa y un archivo;
               2026-10-28, paso 8 de docs/propuesta-mundo-4.md)
               lcd_panel_00 (nine-patch del estilo LCD del cuadro de
               texto de Calc: bisel del cuerpo y pantalla cian_tenue
               con el texto en fondo_profundo; margen de 3 px)       16x16
               world_icon_m1_00 (miniatura del Mundo 1:
               campana de notificaciones, en la carpeta)       16x16
               world_icon_m2_00, world_icon_m3_00, world_icon_m4_00 (miniaturas de
               los Mundos 2 y 3 para el album)                 16x16
               page_dot_current_00, page_dot_other_00          8x8
  menu/        menu_<opcion>_00 y menu_level_<id>_00 (+ _off_00):
               iconos de las opciones de Notas y de las carpetas 12x12
               menu_attention_00 y menu_access_<cache|kernel|root>_00
               (cabecera de Notas, 2026-10-26)                 12x12
               menu_pause_<opcion>_00 (opciones del menu de pausa,
               data/pause_menu.json option_icons; 2026-10-27)  12x12

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
    else:  # completed (todos los subniveles) / all_done (TODO obtenido: con check)
        folder_shape(cv, CA, FP, CB, CT)
        cv.box(sx0, sy0, sx1, sy1, CB, CT, cut=False)
        cv.hline(6, 30, 52, CT)
        cv.rect(30, 51, 31, 52, FP)
        if state == "all_done":
            cv.stamp(44, 44, CHECK, {"#": FP})
    return cv.x2()


# ------------------------------------------- carpetas con el icono del mundo (2026-10-26)
# Peticion del usuario (2026-10-26): la carpeta de cada mundo deja de ser una
# carpeta generica y pasa a ser un icono grande que lo representa (Mundo 1
# Notificaciones: campana; Mundo 2 El Feed: tarjeta de video con el boton de
# reproducir y la barra de progreso en ambar; Mundo 3 La Vitrina: foto
# instantanea con marco). Rejilla logica de 64x64 (x2 = 128x128), como la
# carpeta. Abajo a la izquierda, la placa del numero (lo escribe FolderStation);
# abajo a la derecha, la insignia del estado: candado (locked) o check (all_done:
# TODO el mundo obtenido, HubWorlds.is_world_all_done). Estados: locked (gris,
# GRAY_MAP), available (2 cuadros: el 1 con halo cian_tenue), completed (todos los
# subniveles, sin check) y all_done (con check).
GRAY_MAP = {FP: FP, SO: SO, PA: PA, DK: DK, BA: BA, GA: BA, GF: GA, TR: BA, BO: GA, TT: GA,
            TC: GF, CT: BA, CA: GA, CB: GF, AM: GA, AS: BA}
NUMBER_PLATE = (2, 44, 19, 59)   # placa del numero (logico, inclusivo)
STATE_BADGE = (44, 44, 61, 59)   # insignia del estado (logico, inclusivo)


def remap(cv, mapping):
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.px[x, y]
            if c[3] and c in mapping:
                cv.px[x, y] = mapping[c]


def big_bell(cv):
    cx = 31.5
    # Asa: anillo sobre la cupula.
    for y in range(6, 13):
        for x in range(26, 38):
            if 2.0 <= math.hypot(x - cx, y - 10) <= 3.6:
                cv.p(x, y, TT)
    for y in range(12, 41):
        t = (y - 12) / 28.0
        half = 6.5 + 8.5 * t ** 0.55 + max(0, y - 35) * 1.1
        x0, x1 = int(round(cx - half)), int(round(cx + half))
        cv.hline(x0, x1, y, TC)
        cv.hline(int(round(cx + half * 0.45)), x1, y, TT)  # sombra a la derecha
        if y < 34:
            cv.hline(x0 + 2, x0 + 3, y, CB)  # brillo a la izquierda
    cv.box(10, 40, 53, 44, BO, FP, cut=True)  # borde inferior
    cv.hline(11, 52, 41, TC)
    for y in range(44, 51):
        for x in range(27, 37):
            if math.hypot(x - cx, y - 46.5) <= 3.4:
                cv.p(x, y, CA)  # badajo: el aviso, en cian
    # Ondas de sonido a los lados.
    for side in (-1, 1):
        for y in range(16, 37):
            for x in range(0, 64):
                d = math.hypot(x - cx, (y - 26) * 1.15)
                if (side < 0 and x < 12) or (side > 0 and x > 51):
                    if 22.5 <= d <= 24.2 or 27.5 <= d <= 29.2:
                        cv.p(x, y, CA)


def big_feed(cv):
    # Tarjetas del feed asomando por detras y la tarjeta de video delante.
    cv.box(16, 5, 47, 12, BA, TR)
    cv.box(12, 9, 51, 15, PA, TR)
    cv.box(7, 13, 56, 49, PA, BO)
    cv.rect(10, 16, 53, 39, SO)  # pantalla
    cv.hline(10, 53, 16, FP)
    # Boton de reproducir (triangulo en ambar con sombra).
    for y in range(19, 37):
        k = 9 - abs(y - 27.5)
        if k > 0:
            x1 = 26 + int(k * 1.6)
            cv.hline(26, x1, y, AM)
            cv.p(x1, y, AS)
    cv.vline(26, 19, 36, AS)
    # Barra de progreso con el cabezal.
    cv.rect(10, 43, 53, 44, GA)
    cv.rect(10, 43, 33, 44, AM)
    cv.box(32, 41, 36, 46, TC, FP, cut=True)
    # Puntos de la cabecera.
    for x in (47, 50):
        cv.rect(x, 18, x + 1, 19, TT)


def big_photo(cv):
    # Foto instantanea de la vitrina: una detras, girada, y la de delante.
    cv.box(24, 6, 57, 40, TT, GF)
    cv.rect(27, 9, 54, 31, GA)
    cv.box(6, 12, 45, 49, TC, TT)
    cv.rect(10, 16, 41, 39, CT)  # foto
    cv.rect(10, 16, 41, 25, CA)  # cielo
    for y in range(17, 23):
        for x in range(30, 40):
            if math.hypot(x - 35, y - 20) <= 2.8:
                cv.p(x, y, AM)  # sol
    for y in range(26, 40):  # montanas
        for x in range(10, 42):
            if y >= 26 + abs(x - 19) * 0.9 or y >= 31 + abs(x - 33) * 0.8:
                cv.p(x, y, TR if y < 33 else BO)
    cv.hline(12, 30, 44, GF)  # pie de foto
    # Destello (brilla, «todo pulido»).
    for x, y in ((52, 44), (52, 43), (52, 45), (51, 44), (53, 44), (52, 42), (52, 46), (50, 44), (54, 44)):
        cv.p(x, y, CB)


def big_chat(cv):
    # Mundo 4 «El Chat» (2026-10-27, paso 7 de docs/propuesta-hub-mundos-4-6.md): dos bocadillos, el de
    # delante con los tres puntos de «escribiendo...» y el de detras con renglones. Colores del hub (el coral
    # del Mundo 4 sigue abierto: decision del usuario).
    cv.box(22, 6, 57, 29, TT, GF)
    cv.rect(25, 9, 54, 26, GA)
    for y in (13, 18, 23):
        cv.hline(28, 50 if y != 23 else 42, y, TT)
    for k in range(4):  # cola del de detras, hacia la derecha
        cv.hline(48 - k, 50, 30 + k, GF)
    cv.box(6, 18, 45, 45, TC, TT)
    cv.rect(9, 21, 42, 42, CB)
    for k in range(6):  # cola del de delante, hacia la izquierda
        cv.hline(12, 16 - k // 2, 46 + k, TT)
        cv.p(12, 46 + k, TT)
    cv.rect(13, 45, 16, 46, TC)
    for x in (15, 24, 33):  # «escribiendo...»
        cv.rect(x, 30, x + 4, 34, CT)
        cv.rect(x + 1, 30, x + 3, 31, CA)


def big_shop(cv):
    # Mundo 5 «La Tienda»: bolsa de la compra con asas y la etiqueta del precio en ambar.
    for y in range(6, 18):  # asas
        for x in range(16, 48):
            d = math.hypot((x - 31.5) / 1.3, y - 17)
            if 8.0 <= d <= 10.2 and y < 17:
                cv.p(x, y, TT)
    cv.box(8, 16, 55, 52, TC, TT)
    cv.rect(11, 19, 52, 49, CB)
    cv.hline(11, 52, 19, TC)
    for x in (22, 41):  # remaches de las asas
        cv.rect(x - 1, 21, x + 1, 23, TT)
    cv.vline(52, 20, 49, GF)
    cv.hline(11, 52, 49, GF)
    # Etiqueta del precio (cuelga de la bolsa) con su agujero.
    cv.box(30, 30, 51, 43, AM, AS)
    cv.rect(33, 33, 35, 35, AS)
    cv.hline(38, 48, 35, AS)
    cv.hline(38, 45, 39, AS)
    cv.vline(31, 24, 30, AS)


def big_cloud(cv):
    # Mundo 6 «La Nube»: nube con la flecha de subir en cian.
    blobs = ((20, 30, 11), (32, 22, 13), (45, 30, 10), (14, 38, 8), (50, 38, 8))
    for y in range(6, 50):
        for x in range(2, 62):
            inside = any(math.hypot(x - bx, y - by) <= r for bx, by, r in blobs) or (14 <= x <= 50 and 30 <= y <= 46)
            if inside:
                cv.p(x, y, TC)
    # Sombra abajo a la derecha y brillo arriba.
    for y in range(6, 50):
        for x in range(2, 62):
            if cv.get(x, y) == TC and (cv.get(x, y + 2) != TC or cv.get(x + 2, y) != TC):
                cv.p(x, y, TT)
    for x in range(26, 36):
        cv.p(x, 11, CB)
    # Flecha de subir.
    for k in range(6):
        cv.hline(31 - k, 32 + k, 24 + k, CA)
    cv.rect(29, 30, 34, 41, CA)
    cv.vline(29, 30, 41, CT)


WORLD_ICONS = {"m1": big_bell, "m2": big_feed, "m3": big_photo, "m4": big_chat, "m5": big_shop, "m6": big_cloud}


def world_folder(world, state, frame):
    cv = Canvas(64, 64)
    WORLD_ICONS[world](cv)
    cv.halo(FP)
    if state == "locked":
        remap(cv, GRAY_MAP)
    elif state == "available" and frame == 1:
        cv.halo(CT)
    # Placa del numero (el numero lo escribe FolderStation).
    border = {"locked": GA, "available": CA, "completed": TT, "all_done": CA}[state]
    nx0, ny0, nx1, ny1 = NUMBER_PLATE
    cv.box(nx0, ny0, nx1, ny1, FP, border)
    cv.hline(nx0 + 2, nx1 - 2, ny0 + 1, PA)
    bx0, by0, bx1, by1 = STATE_BADGE
    if state == "locked":
        cv.box(bx0, by0, bx1, by1, FP, GA)
        cv.stamp(bx0 + 5, by0 + 4, LOCK, {"#": TT})
    elif state == "all_done":
        cv.box(bx0, by0, bx1, by1, CA, FP)
        cv.hline(bx0 + 2, bx1 - 2, by0 + 1, CB)
        cv.stamp(bx0 + 3, by0 + 4, CHECK, {"#": FP})
    return cv.x2()


def world_icon_feed():
    """Miniatura del Mundo 2 (album): tarjeta de video con el boton en ambar."""
    cv = Canvas(16, 16)
    cv.box(1, 2, 14, 13, PA, BO)
    cv.rect(3, 4, 12, 9, SO)
    for y in range(4, 10):
        k = 3 - abs(y - 6.5)
        if k > 0:
            cv.hline(6, 6 + int(k * 1.5), y, AM)
    cv.hline(3, 12, 11, GA)
    cv.hline(3, 7, 11, AM)
    cv.halo(FP)
    return cv.img


def world_icon_photo():
    """Miniatura del Mundo 3 (album): foto instantanea con su marco."""
    cv = Canvas(16, 16)
    cv.box(2, 1, 13, 14, TC, TT)
    cv.rect(4, 3, 11, 9, CT)
    cv.rect(4, 3, 11, 5, CA)
    cv.p(9, 4, AM)
    for x in range(4, 12):
        cv.vline(x, 7 + abs(x - 6) // 2 if x < 9 else 8, 9, TR)
    cv.hline(4, 9, 12, GF)
    cv.halo(FP)
    return cv.img


def world_icon_chat():
    """Miniatura del Mundo 4 (album y carpeta; paso 11 de docs/propuesta-mundo-4.md §4.6): bocadillo de chat con
    los tres puntos de «escribiendo…»."""
    cv = Canvas(16, 16)
    cv.box(1, 2, 14, 11, PA, BO)
    cv.rect(3, 12, 4, 12, BO)   # cola del bocadillo
    cv.p(3, 13, BO)
    for x in (4, 7, 10):
        cv.rect(x, 6, x + 1, 7, CA)
    cv.halo(FP)
    return cv.img


# ---------------------------------------------- iconos de los menus del hub (12x12)
# Peticion del usuario (2026-10-26): iconos junto a las opciones de los menus de
# Notas (Guardar con un disquete, Album, Apodo, Volver; Si / No de la
# confirmacion) y de las carpetas (un icono por subnivel, el jefe con la
# estrella de puntas de jefe, Volver y Entrar sin guardar). 12x12 px de arte (x2
# en pantalla, la altura de una linea de la fuente de textos), trazo claro y
# contorno fondo_profundo. Las variantes _off (subnivel bloqueado o
# «Proximamente») pasan por GRAY_MAP.
MENU = 12
MENU_STAMPS = {
    "save": (["#########...",
              "#bmmmsmmb#..",
              "#bmmmsmmbb#.",
              "#bmmmmmmbbb#",
              "#bbbbbbbbbb#",
              "#bllllllllb#",
              "#blkkkkkklb#",
              "#bllllllllb#",
              "#blkkkkkklb#",
              "#bllllllllb#",
              "#bbbbbbbbbb#",
              "############"],
             {"#": FP, "b": TR, "m": TC, "s": SO, "l": TC, "k": GF}),
    "album": (["###########.",
               "#sccccccccc#",
               "#scwwwwwwwc#",
               "#scwppppawc#",
               "#scwpppppwc#",
               "#scwpgpppwc#",
               "#scwgggpgwc#",
               "#scwwwwwwwc#",
               "#sccccccccc#",
               "#scctttttcc#",
               "#sccccccccc#",
               "###########."],
              {"#": FP, "s": BO, "c": TR, "w": TC, "p": CA, "a": AM, "g": CT, "t": TT}),
    "nickname": (["............",
                  "....####....",
                  "....#kk#....",
                  "############",
                  "#wwwwwwwwww#",
                  "#whhhwllllw#",
                  "#whhhwwwwww#",
                  "#wbbbwlllww#",
                  "#bbbbbwwwww#",
                  "#wwwwwwwwww#",
                  "############",
                  "............"],
                 {"#": FP, "w": TC, "h": CA, "b": TR, "l": GF, "k": BO}),
}


def _menu_canvas():
    return Canvas(MENU, MENU)


def menu_icon(name):
    cv = _menu_canvas()
    if name in MENU_STAMPS:
        rows, cmap = MENU_STAMPS[name]
        assert all(len(r) == MENU for r in rows) and len(rows) == MENU, name
        cv.stamp(0, 0, rows, cmap)
        return cv
    draw = MENU_DRAW[name]
    draw(cv)
    cv.halo(FP)
    return cv


def _menu_back(cv):
    # Flecha de vuelta (punta a la izquierda y curva hacia abajo a la derecha).
    for y, x0, x1 in ((2, 3, 3), (3, 2, 3), (4, 1, 8), (5, 1, 9), (6, 2, 3), (7, 3, 3)):
        cv.hline(x0, x1, y, TC)
    for y in range(5, 9):
        cv.hline(9, 10, y, TC)
    cv.hline(4, 9, 9, TC)
    cv.hline(4, 8, 10, TC)
    cv.p(9, 4, TT)


def _menu_yes(cv):
    cv.stamp(0, 2, CHECK, {"#": CA})


def _menu_no(cv):
    for i in range(8):
        cv.rect(2 + i, 2 + i, 3 + i, 2 + i, TT)
        cv.rect(8 - i, 2 + i, 9 - i, 2 + i, TT)


def _menu_enter(cv):
    for y, x0, x1 in ((3, 4, 4), (4, 4, 5), (5, 0, 6), (6, 0, 6), (7, 4, 5), (8, 4, 4)):
        cv.hline(x0, x1, y, TC)
    cv.rect(9, 1, 10, 10, CA)  # el vortice / la puerta
    cv.vline(8, 2, 9, CT)


def _menu_inbox(cv):  # 1-1 Bandeja de entrada: sobre con aviso
    cv.rect(1, 3, 9, 9, TC)
    for i in range(4):
        cv.p(2 + i, 4 + i, GF)
        cv.p(8 - i, 4 + i, GF)
    cv.rect(9, 1, 10, 2, CA)


def _menu_tower(cv):  # 1-2 Centro de notificaciones: torre de 4 pisos
    cv.rect(5, 0, 6, 1, BO)
    cv.rect(2, 2, 9, 2, BO)
    cv.rect(2, 3, 9, 10, TT)
    for k in range(4):
        y = 3 + k * 2
        cv.rect(3, y, 4, y, CA)
        cv.rect(7, y, 8, y, CA)


def _menu_moon(cv):  # 1-3 No molestar: luna
    for y in range(MENU):
        for x in range(MENU):
            if math.hypot(x - 5, y - 6) <= 4.6 and math.hypot(x - 7.5, y - 4.2) > 3.8:
                cv.p(x, y, TC if x < 4 else TT)
    cv.p(9, 2, CB)
    cv.p(10, 7, CB)


def _menu_boss_alert(cv):  # Jefe Alerta Mayor: senal de alerta con «!»
    for y in range(1, 11):
        half = (y - 1) * 0.55
        cv.hline(int(round(5.5 - half - 0.5)), int(round(5.5 + half + 0.5)), y, TC)
    cv.hline(0, 11, 10, TT)
    cv.rect(5, 4, 6, 7, FP)
    cv.rect(5, 9, 6, 9, FP)


def _menu_boss_autoplay(cv):  # Jefe Autoplay: boton de reproducir que no para
    for y in range(MENU):
        for x in range(MENU):
            if math.hypot(x - 5.5, y - 5.5) <= 5.2:
                cv.p(x, y, AM if x + y < 13 else AS)
    for y in range(3, 9):
        k = 3 - abs(y - 5.5)
        if k > 0:
            cv.hline(4, 4 + int(k * 1.4), y, FP)


HEART = ["............",
         "............",
         "..aaa..sss..",
         ".aaaaasssss.",
         ".awaaasssss.",
         ".aaaaasssss.",
         "..aaaassss..",
         "...aaasss...",
         "....aass....",
         ".....as.....",
         "............",
         "............"]


def _menu_heart(cv):  # 2-1 Para ti: corazon (lo que te recomiendan)
    cv.stamp(0, 0, HEART, {"a": AM, "s": AS, "w": TC})


def _menu_video_plus(cv):  # 2-2 Un video mas: tarjeta con reproducir y «+»
    cv.rect(0, 3, 8, 10, TT)
    cv.rect(1, 4, 7, 9, SO)
    for y in range(5, 9):
        k = 2 - abs(y - 6.5)
        if k > 0:
            cv.hline(3, 3 + int(k * 1.5), y, AM)
    cv.rect(9, 0, 9, 4, CA)
    cv.rect(7, 2, 11, 2, CA)


def _menu_scroll(cv):  # 2-3 Scroll infinito: lista que no acaba y flecha abajo
    for y in (0, 3):
        cv.rect(1, y, 10, y + 1, TT)
    cv.rect(1, 6, 10, 6, GA)
    for i in range(4):  # chevron hacia abajo, 2 px de grosor
        cv.rect(2 + i, 7 + i, 3 + i, 7 + i, AM)
        cv.rect(8 - i, 7 + i, 9 - i, 7 + i, AM)


def _menu_attention(cv):  # puntos de atencion: el rombo ambar del HUD (hud_attention) a 12 px
    for y in range(MENU):
        for x in range(MENU):
            d = abs(x - 5.5) + abs(y - 5.5)
            if d <= 5.0:
                cv.p(x, y, AS if (x - 5.5) + (y - 5.5) >= 3.0 else AM)
    cv.rect(5, 5, 6, 6, AS)
    cv.p(4, 3, TC)


def _menu_access_cache(cv):  # acceso Caché: chip de memoria con patillas
    cv.rect(3, 3, 8, 8, CA)
    cv.rect(4, 4, 7, 7, FP)
    cv.rect(5, 5, 6, 6, CB)
    for k in (4, 7):
        cv.hline(1, 2, k, TT)
        cv.hline(9, 10, k, TT)
        cv.vline(k, 1, 2, TT)
        cv.vline(k, 9, 10, TT)


def _menu_access_kernel(cv):  # acceso Kernel: nucleo (anillo y centro)
    for y in range(MENU):
        for x in range(MENU):
            r = math.hypot(x - 5.5, y - 5.5)
            if 4.3 <= r <= 5.6:
                cv.p(x, y, AM)
            elif r <= 2.3:
                cv.p(x, y, CB if x + y <= 10 else CA)


def _menu_access_root(cv):  # acceso Raíz: tronco y raices hacia abajo
    cv.rect(5, 0, 6, 5, TC)
    for i in range(4):
        cv.p(4 - i, 6 + i, TT)
        cv.p(7 + i, 6 + i, TT)
    cv.vline(5, 6, 10, TT)
    cv.vline(6, 6, 9, TT)
    for x, y in ((1, 10), (10, 10), (5, 11)):
        cv.p(x, y, CA)


def _menu_unknown(cv):  # subnivel sin icono propio
    for y, x0, x1 in ((1, 4, 7), (2, 3, 8), (3, 3, 4), (3, 7, 8), (4, 6, 8), (5, 5, 7), (6, 5, 6), (7, 5, 6),
                      (9, 5, 6), (10, 5, 6)):
        cv.hline(x0, x1, y, TT)


# --- Mundo 3 «La Vitrina» (2026-10-27, peticion del usuario: el hub mostraba
# «?» en sus filas). Paleta del hub (sin el verde acido del Mundo 3, que no esta
# en hub.gpl): trazo claro y acento cian_brillo / ambar como los Mundos 1 y 2.

def _menu_gallery(cv):  # 3-1 Galeria de perfil: rejilla 2x2 de fotos, la 1.ª el perfil
    for x0, y0 in ((1, 1), (6, 1), (1, 6), (6, 6)):
        cv.rect(x0, y0, x0 + 4, y0 + 4, TR)
    cv.rect(2, 2, 4, 4, BO)          # foto de perfil: cabeza y hombros
    cv.p(3, 2, TC)
    cv.hline(2, 4, 5, TC)
    cv.rect(3, 3, 3, 3, TC)
    for x0, y0 in ((6, 1), (1, 6), (6, 6)):  # miniaturas: sol y colina
        cv.p(x0 + 3, y0 + 1, CB)
        cv.hline(x0, x0 + 4, y0 + 4, TT)
        cv.hline(x0 + 1, x0 + 2, y0 + 3, TT)


def _menu_no_filter(cv):  # 3-2 Sin filtro: lente con una raya que la tacha
    for y in range(MENU):
        for x in range(MENU):
            r = math.hypot(x - 5.5, y - 5.5)
            if 3.6 <= r <= 5.4:
                cv.p(x, y, TC if x + y < 12 else TT)
            elif r < 3.6:
                cv.p(x, y, TR)
    cv.rect(3, 3, 4, 4, CB)
    for i in range(10):  # raya de 2 px de abajo-izquierda a arriba-derecha
        cv.rect(1 + i, 10 - i, 2 + i, 10 - i, AM)


def _menu_mirror(cv):  # 3-3 Espejo, espejito: espejo de mano
    for y in range(MENU):
        for x in range(MENU):
            e = ((x - 5.5) / 4.6) ** 2 + ((y - 3.8) / 3.9) ** 2
            if e <= 1.0:
                cv.p(x, y, CT if e < 0.55 else BO)
    for i in range(3):  # reflejo en diagonal
        cv.p(4 + i, 3 - i + 1, CB)
    cv.p(3, 4, CB)
    cv.rect(5, 8, 6, 11, TT)
    cv.rect(5, 8, 5, 11, TC)


def _menu_boss_curator(cv):  # Jefe La Curadora: marco dorado con corona y un ojo
    cv.rect(1, 3, 10, 11, AM)
    cv.rect(2, 4, 9, 10, AS)
    cv.rect(3, 5, 8, 9, SO)
    for x in (2, 5, 6, 9):  # corona
        cv.vline(x, 0, 2, AM)
    cv.hline(2, 9, 2, AM)
    cv.hline(4, 7, 7, TC)     # ojo
    cv.hline(5, 6, 6, TC)
    cv.hline(5, 6, 8, TC)
    cv.rect(5, 7, 6, 7, CA)


def _menu_recent_chats(cv):  # 4-1 Chats recientes: tres filas de la lista de chats (avatar y linea)
    for y0 in (1, 5, 9):
        cv.rect(1, y0, 2, y0 + 1, CA if y0 == 1 else TT)
        cv.hline(4, 10, y0, TC)
        cv.hline(4, 7, y0 + 1, TR)


def _menu_group(cv):  # 4-2 Grupo sin respuesta: tres avatares apagados y un bocadillo vacio
    for x0 in (0, 4, 8):
        cv.rect(x0 + 1, 6, x0 + 2, 7, TT)
        cv.hline(x0, x0 + 3, 9, TT)
        cv.hline(x0, x0 + 3, 10, TR)
    cv.rect(3, 0, 8, 3, BO)
    cv.rect(4, 1, 7, 2, SO)
    cv.p(4, 4, BO)


def _menu_unread(cv):  # 4-3 Mensajes sin leer: bocadillo con el punto de no leidos
    cv.rect(0, 2, 9, 9, BO)
    cv.rect(1, 3, 8, 8, PA)
    cv.p(1, 10, BO)
    cv.hline(2, 7, 5, TC)
    cv.hline(2, 5, 7, TR)
    cv.rect(9, 0, 11, 2, AM)


def _menu_boss_seen(cv):  # Jefe El Visto: el doble check
    for dx, col in ((0, CT), (4, CA)):
        for k in range(3):          # pata corta
            cv.rect(dx + k, 6 + k, dx + k, 7 + k, col)
        for k in range(6):          # pata larga
            cv.rect(dx + 3 + k, 7 - k, dx + 3 + k, 8 - k, col)


# --- Menu de pausa (2026-10-27, peticion del usuario: «iconicemos el menu de
# ESC»). Mismo sistema, tamano y contorno que los de Notas y las carpetas.

def _pause_resume(cv):  # Reanudar: reproducir
    for y in range(1, 11):
        k = 5 - abs(y - 5.5)
        if k > 0:
            cv.hline(3, 3 + int(k * 1.4), y, TC if y < 6 else TT)
    cv.p(3, 5, CB)


def _pause_settings(cv):  # Ajustes: el engranaje del HUD del hub a 12 px
    for y in range(MENU):
        for x in range(MENU):
            dx, dy = x - 5.5, y - 5.5
            r = math.hypot(dx, dy)
            a = (math.degrees(math.atan2(dy, dx)) + 360.0) % 45.0
            if 1.9 <= r <= 3.9 or (11.0 <= a <= 34.0 and 3.9 < r <= 5.7):
                cv.p(x, y, TT if dx + dy > 3.0 else TC)
    cv.rect(5, 5, 6, 6, CA)


def _pause_exit_hub(cv):  # Salir al hub: casita con la puerta cian
    for y in range(0, 6):
        cv.hline(max(0, 5 - y), min(11, 6 + y), y, TC)
    cv.rect(2, 6, 9, 11, TT)
    cv.rect(5, 8, 6, 11, CA)


def _pause_quit(cv):  # Cerrar el juego: simbolo de encendido
    for y in range(MENU):
        for x in range(MENU):
            r = math.hypot(x - 5.5, y - 6.0)
            ang = math.degrees(math.atan2(x - 5.5, -(y - 6.0)))
            if 3.6 <= r <= 5.3 and abs(ang) > 38.0:
                cv.p(x, y, TC if y < 8 else TT)
    cv.rect(5, 0, 6, 6, TC)


def _pause_eco_help(cv):  # Ayudas de Eco: Eco brillando en dorado con su Q
    for y in range(MENU):
        for x in range(MENU):
            r = math.hypot(x - 5.5, y - 5.5)
            if r <= 5.4:
                cv.p(x, y, AM if x + y < 12 else AS)
    cv.rect(4, 3, 7, 3, FP)   # Q
    cv.rect(4, 7, 7, 7, FP)
    cv.vline(3, 4, 6, FP)
    cv.vline(8, 4, 6, FP)
    cv.p(7, 8, FP)
    cv.p(8, 9, FP)
    cv.p(2, 2, TC)


def _pause_low_sync(cv):  # Reducir efectos de Sync bajo: senal con una barra
    for i, h in enumerate((3, 5, 7, 9)):
        x = 1 + i * 3
        cv.rect(x, 10 - h, x + 1, 10, TC if i == 0 else GA)
    cv.hline(0, 11, 11, TT)


def _pause_debug_outline(cv):  # Contorno del Debug: plataforma de contorno discontinuo
    for i in range(10):
        if (i // 2) % 2 == 0:
            for x, y in ((1 + i, 1), (10 - i, 10), (1, 10 - i), (10, 1 + i)):
                cv.p(x, y, CB)
    cv.rect(3, 3, 8, 8, CT)
    cv.rect(4, 4, 7, 7, CA)


def _pause_rhythm(cv):  # Senales sonoras de ritmo: nota musical
    cv.vline(7, 0, 8, TC)
    cv.rect(8, 1, 9, 2, TC)
    cv.p(10, 3, TC)
    cv.rect(3, 7, 6, 10, TC)
    cv.rect(3, 10, 3, 10, CLEAR)
    cv.rect(6, 7, 6, 7, CLEAR)
    cv.rect(4, 9, 5, 9, TT)
    cv.p(1, 3, CA)
    cv.p(0, 2, CA)


def _pause_sound(cv):  # Sonido / volumen: altavoz con ondas
    cv.rect(0, 4, 2, 7, TT)
    for x in range(3, 6):
        cv.vline(x, 4 - (x - 2), 7 + (x - 2), TC)
    for y in range(3, 9):
        cv.p(8 if 4 <= y <= 7 else 7, y, CA)
    for y in range(1, 11):
        cv.p(10 if 3 <= y <= 8 else 9, y, CT)


def _pause_display(cv):  # Pantalla: monitor
    cv.rect(0, 1, 11, 8, TT)
    cv.rect(1, 2, 10, 7, SO)
    cv.rect(2, 3, 4, 4, CA)
    cv.hline(2, 8, 6, CT)
    cv.rect(5, 9, 6, 9, TT)
    cv.hline(3, 8, 10, TC)


def _pause_controls(cv):  # Controles: mando
    cv.rect(1, 3, 10, 8, TT)
    cv.rect(0, 5, 11, 9, TT)
    cv.rect(0, 9, 2, 10, TT)
    cv.rect(9, 9, 11, 10, TT)
    cv.hline(1, 10, 3, TC)
    cv.hline(2, 4, 6, FP)   # cruceta
    cv.vline(3, 5, 7, FP)
    cv.p(8, 5, CA)
    cv.p(9, 6, AM)


def _pause_window_mode(cv):  # Modo de ventana: ventana con su barra
    cv.rect(1, 1, 10, 10, TT)
    cv.rect(2, 2, 9, 3, BO)
    cv.rect(2, 4, 9, 9, SO)
    cv.rect(8, 2, 9, 3, CA)
    cv.hline(3, 6, 6, CT)
    cv.hline(3, 4, 8, CT)


def _pause_window_size(cv):  # Tamano de ventana: flecha doble en diagonal
    for i in range(8):
        cv.rect(2 + i, 9 - i, 2 + i, 9 - i, TC)
    cv.rect(1, 6, 1, 10, TC)
    cv.rect(1, 10, 5, 10, TC)
    cv.rect(10, 1, 10, 5, TC)
    cv.rect(6, 1, 10, 1, TC)
    cv.rect(0, 0, 3, 0, CT)
    cv.rect(0, 0, 0, 3, CT)
    cv.rect(8, 11, 11, 11, CT)
    cv.rect(11, 8, 11, 11, CT)


def _pause_scale_mode(cv):  # Escalado: rejilla de pixeles
    for j in range(3):
        for i in range(3):
            cv.rect(1 + i * 3 + i // 2 * 0, 1 + j * 3, 3 + i * 3, 3 + j * 3, TC if (i + j) % 2 == 0 else TR)
    cv.rect(10, 1, 11, 11, CLEAR)
    cv.rect(1, 10, 11, 11, CLEAR)


def _pause_reset(cv):  # Restablecer valores: flecha en circulo
    for y in range(MENU):
        for x in range(MENU):
            r = math.hypot(x - 5.5, y - 6.0)
            ang = math.degrees(math.atan2(y - 6.0, x - 5.5))
            if 3.4 <= r <= 5.0 and not (-80.0 < ang < -20.0):
                cv.p(x, y, TC if y < 7 else TT)
    cv.rect(8, 0, 11, 0, CA)   # punta
    cv.rect(11, 0, 11, 3, CA)
    cv.rect(10, 1, 10, 2, CA)


def _pause_swap(cv):  # Intercambiar: dos flechas opuestas
    cv.hline(1, 9, 3, TC)
    cv.vline(8, 1, 5, TC)
    cv.vline(9, 2, 4, TC)
    cv.hline(2, 10, 8, CA)
    cv.vline(3, 6, 10, CA)
    cv.vline(2, 7, 9, CA)


MENU_DRAW = {"back": _menu_back, "yes": _menu_yes, "no": _menu_no, "enter": _menu_enter,
             "level_1_1": _menu_inbox, "level_1_2": _menu_tower, "level_1_3": _menu_moon,
             "level_1_boss": _menu_boss_alert, "level_2_1": _menu_heart, "level_2_2": _menu_video_plus,
             "level_2_3": _menu_scroll, "level_2_boss": _menu_boss_autoplay, "level_unknown": _menu_unknown,
             "attention": _menu_attention, "access_cache": _menu_access_cache,
             "access_kernel": _menu_access_kernel, "access_root": _menu_access_root,
             "level_3_1": _menu_gallery, "level_3_2": _menu_no_filter, "level_3_3": _menu_mirror,
             "level_3_boss": _menu_boss_curator,
             "level_4_1": _menu_recent_chats, "level_4_2": _menu_group, "level_4_3": _menu_unread,
             "level_4_boss": _menu_boss_seen,
             "pause_resume": _pause_resume, "pause_settings": _pause_settings, "pause_exit_hub": _pause_exit_hub,
             "pause_quit": _pause_quit, "pause_eco_help": _pause_eco_help, "pause_low_sync": _pause_low_sync,
             "pause_debug_outline": _pause_debug_outline, "pause_rhythm": _pause_rhythm,
             "pause_sound": _pause_sound, "pause_display": _pause_display, "pause_controls": _pause_controls,
             "pause_window_mode": _pause_window_mode, "pause_window_size": _pause_window_size,
             "pause_scale_mode": _pause_scale_mode, "pause_reset": _pause_reset, "pause_swap": _pause_swap}
MENU_ICONS = ["save", "album", "nickname", "back", "yes", "no", "enter",
              "level_1_1", "level_1_2", "level_1_3", "level_1_boss",
              "level_2_1", "level_2_2", "level_2_3", "level_2_boss",
              "level_3_1", "level_3_2", "level_3_3", "level_3_boss",
              "level_4_1", "level_4_2", "level_4_3", "level_4_boss", "level_unknown",
              "attention", "access_cache", "access_kernel", "access_root",
              "pause_resume", "pause_settings", "pause_exit_hub", "pause_quit", "pause_eco_help",
              "pause_low_sync", "pause_debug_outline", "pause_rhythm", "pause_sound", "pause_display",
              "pause_controls", "pause_window_mode", "pause_window_size", "pause_scale_mode",
              "pause_reset", "pause_swap"]


def menu_outputs():
    out = {}
    for name in MENU_ICONS:
        cv = menu_icon(name)
        out[f"menu/menu_{name}_00.png"] = cv.img
        if name.startswith("level_"):
            off = Canvas(MENU, MENU)
            off.img.paste(cv.img)
            off.px = off.img.load()
            remap(off, GRAY_MAP)
            out[f"menu/menu_{name}_off_00.png"] = off.img
    return out


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


def icon_calc():
    """Icono de Calc para el cuadro de texto: su cara despierta (visor oscuro con
    los ojos a media asta en acento_cian, como calc_awake) y el teclado."""
    cv = Canvas(16, 16)
    cv.box(2, 0, 13, 15, GF, FP)
    cv.hline(3, 12, 1, BO)
    cv.rect(4, 2, 11, 7, FP)
    cv.rect(5, 3, 10, 6, SO)
    cv.hline(5, 6, 4, CA)
    cv.hline(9, 10, 4, CA)
    cv.hline(6, 9, 6, CT)
    for r in range(2):
        for c in range(3):
            kx, ky = 4 + c * 3, 9 + r * 3
            cv.rect(kx, ky, kx + 1, ky + 1, CA if (c == 2 and r == 1) else (PA if c < 2 else CT))
    return cv.img


def icon_papelera():
    """Icono de la Papelera para el cuadro de texto (la del 4-2, paso 8 de
    docs/propuesta-mundo-4.md): su cubo (base y contorno cian_tenue, como el arte
    «empty» de la estacion) con la tapa gris_apagado y un archivo asomando."""
    cv = Canvas(16, 16)
    file_icon(cv, 5, 0)
    cv.rect(2, 4, 13, 6, GA)
    cv.hline(2, 13, 4, CT)
    cv.hline(2, 13, 6, CT)
    cv.rect(6, 3, 9, 3, CT)
    for y in range(7, 16):
        inset = (y - 7) // 4
        cv.hline(3 + inset, 12 - inset, y, BA)
        cv.p(3 + inset, y, CT)
        cv.p(12 - inset, y, CT)
    cv.hline(5, 10, 15, CT)
    for x in (6, 9):
        cv.vline(x, 9, 13, CT)
    return cv.img


def lcd_panel():
    """Panel del estilo LCD de Calc (nine-patch 16x16, margen 3): contorno
    fondo_profundo con esquinas cortadas, bisel del cuerpo de Calc (gris_foto
    arriba e izquierda, base abajo y derecha) y pantalla cian_tenue con una
    linea de sombra arriba (cristal hundido). El texto va en fondo_profundo."""
    cv = Canvas(16, 16)
    cv.box(0, 0, 15, 15, CT, FP)
    cv.hline(1, 14, 1, GF)
    cv.vline(1, 1, 14, GF)
    cv.hline(1, 14, 14, BA)
    cv.vline(14, 2, 14, BA)
    cv.hline(2, 13, 2, SO)
    cv.vline(2, 2, 13, SO)
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


# ------------------------------------------------------------- cargador
# Cargador de energia del hub (2026-10-16): el MISMO dibujo que el de los niveles
# (tools/gen_energy_objects.py, charger; estados ready/cooling/spent con los
# mismos cuadros) con los colores del Mundo 1 que no estan en hub.gpl cambiados
# por su rol equivalente del hub (contorno, pantalla, sombra y cuerpo). Los demas
# (borde_luz, resplandor y los cian) ya son colores del hub con el mismo hex.
def _energy_module():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gen_energy_objects
    return gen_energy_objects


def charger_remap():
    ge = _energy_module()
    return {ge.N: FP,    # noche_profunda -> fondo_profundo (contorno)
            ge.TS: SO,   # tile_sombra -> sombra (pantalla)
            ge.TB: PA,   # tile_base -> panel (sombra del cuerpo, trazas apagadas)
            ge.TL: DK}   # tile_luz -> dock (cuerpo)


def charger(state, f=0, progress=0.0):
    ge = _energy_module()
    remap = charger_remap()
    im = ge.charger(state, f, progress).copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] and c in remap:
                px[x, y] = remap[c]
    return im


def page_dot(current):
    cv = Canvas(8, 8)
    cv.stamp(0, 0, DOT_FULL if current else DOT_RING, {"#": TC if current else TT})
    return cv.img


# ------------------------------------- hub de varias paginas (paso 7, 2026-10-27)
# docs/propuesta-hub-mundos-4-6.md §3.2 y §5.1: fondo de las paginas 2 y 3, candado
# de 5 ranuras de La Nube e instalador (HubInstaller y su decorado apagado). Solo
# colores de hub.gpl. Lo que lleva los colores del Debug de los Mundos 2 y 3 (o el
# coral PROVISIONAL del Mundo 4) va en tools/gen_hub_update_art.py.

def page_background(page):
    """Fondo de la pagina `page` (2 o 3): el mismo ambiente de la 1 sin la foto. Las trazas
    de la izquierda siguen las que salen por la derecha de la pagina anterior (y 58, 150 y 226
    en la 1; y 90 y 200 en la 2) y el motivo de arriba queda tenue (dock y panel) para no
    competir con las piezas: la 2, una ventana del sistema con su barra de progreso vacia; la
    3, una nube de trazas (La Nube)."""
    cv = Canvas(BG_W, BG_H, BA)
    if page == 2:
        traces = [[(0, 58), (40, 58), (52, 70), (84, 70)],
                  [(0, 150), (30, 150), (42, 138), (80, 138)],
                  [(0, 226), (56, 226), (70, 240), (70, 272)],
                  [(639, 90), (596, 90), (584, 102), (548, 102)],
                  [(639, 200), (604, 200), (590, 214), (590, 272)],
                  [(200, 272), (236, 272), (248, 260), (392, 260), (404, 272), (440, 272)]]
    else:
        traces = [[(0, 90), (44, 90), (56, 78), (96, 78)],
                  [(0, 200), (36, 200), (50, 214), (50, 272)],
                  [(600, 64), (560, 64), (548, 76), (520, 76)],
                  [(610, 180), (572, 180), (560, 168), (528, 168)],
                  [(232, 272), (268, 272), (280, 260), (360, 260), (372, 272), (408, 272)]]
    for pts in traces:
        trace(cv, pts)
    if page == 2:
        x0, y0, x1, y1 = 212, 44, 428, 150
        cv.rect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, FP)
        cv.rect(x0, y0, x1, y1, DK)
        cv.rect(x0, y0, x1, y0 + 9, PA)
        for k in range(3):
            cv.rect(x1 - 8 - k * 7, y0 + 3, x1 - 5 - k * 7, y0 + 6, GA)
        cv.hline(x0 + 6, x0 + 60, y0 + 5, DK)
        for y in (y0 + 24, y0 + 34, y0 + 44):
            cv.hline(x0 + 14, x1 - 60 if y != y0 + 44 else x1 - 110, y, PA)
        bx0, by0, bx1, by1 = x0 + 14, y1 - 30, x1 - 14, y1 - 18
        cv.rect(bx0, by0, bx1, by1, FP)
        cv.rect(bx0 + 1, by0 + 1, bx1 - 1, by1 - 1, PA)
        for x in range(bx0 + 3, bx1 - 2, 12):
            cv.rect(x, by0 + 3, x + 5, by1 - 3, BA)
        trace(cv, [(320, y1 + 2), (320, 186), (332, 198), (332, 232)])
    else:
        # Nube arriba, por encima de los avisos de la carpeta M6 (columna 9), y los datos que
        # suben por los lados (nunca por detras de la carpeta ni de sus placas).
        blobs = ((290, 66, 20), (320, 52, 28), (354, 64, 22), (272, 78, 12), (370, 80, 13))
        inside = set()
        for y in range(16, 100):
            for x in range(240, 400):
                if any(math.hypot(x - bx, (y - by) * 1.15) <= r for bx, by, r in blobs) \
                        or (272 <= x <= 370 and 66 <= y <= 90):
                    inside.add((x, y))
        for x, y in inside:
            edge = any((x + ex, y + ey) not in inside for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            cv.p(x, y, TR if edge else DK)
        for pts in ([(212, 236), (212, 96), (224, 84), (262, 84)], [(428, 236), (428, 96), (416, 84), (380, 84)]):
            trace(cv, pts)
            for y in range(112, 230, 18):  # datos que suben a la nube
                cv.rect(pts[0][0] - 1, y, pts[0][0] + 1, y + 3, PA)
    return cv.x2()


LOCK_W, LOCK_SHACKLE, LOCK_BODY = 55, 8, 15  # candado de La Nube (logico; x2 en pantalla)
LOCK_SLOT, LOCK_GAP, LOCK_MARGIN = 7, 3, 4


def cloud_lock_plate(slots=5):
    """Candado de `slots` ranuras de La Nube (FolderStation._CloudLock): arco arriba y
    cuerpo con las ranuras vacias; cada recuerdo obtenido enciende la suya
    (cloud_lock_slot_on). 55 x 23 de arte (x2 = 110 x 46)."""
    cv = Canvas(LOCK_W, LOCK_SHACKLE + LOCK_BODY)
    cx = (LOCK_W - 1) / 2.0
    for y in range(0, LOCK_SHACKLE + 2):
        for x in range(LOCK_W):
            d = math.hypot((x - cx) / 1.6, y - LOCK_SHACKLE - 1)
            if 5.5 <= d <= 8.6:
                cv.p(x, y, GF if d < 7.2 else TT)
    top = LOCK_SHACKLE
    cv.box(0, top, LOCK_W - 1, top + LOCK_BODY - 1, PA, FP)
    cv.hline(2, LOCK_W - 3, top + 1, GF)
    cv.hline(2, LOCK_W - 3, top + LOCK_BODY - 2, SO)
    for i in range(slots):
        x = LOCK_MARGIN + i * (LOCK_SLOT + LOCK_GAP)
        cv.rect(x - 1, top + 3, x + LOCK_SLOT, top + 4 + LOCK_SLOT, GA)
        cv.rect(x, top + 4, x + LOCK_SLOT - 1, top + 3 + LOCK_SLOT, FP)
    return cv.x2()


def cloud_lock_slot_on():
    cv = Canvas(LOCK_SLOT, LOCK_SLOT, CA)
    cv.hline(0, LOCK_SLOT - 1, 0, CB)
    cv.vline(0, 0, LOCK_SLOT - 1, CB)
    cv.hline(1, LOCK_SLOT - 1, LOCK_SLOT - 1, CT)
    cv.vline(LOCK_SLOT - 1, 1, LOCK_SLOT - 1, CT)
    return cv.x2()


DOWNLOAD = ["..####..", "..####..", "..####..", "########", ".######.", "..####..", "...##...", "........",
            "########"]


def installer(state, f):
    """Instalador de la actualizacion (HubInstaller, 2 x 3 tiles; 64 x 96 de arte, x2): torre
    con pantalla, la flecha de descarga y tres pilotos (las tres verificaciones). Estados de
    HubStation: powered_off (el decorado apagado tras instalar), off (2 cuadros: la flecha
    late), prompt (borde cian, 2 cuadros) y active (pantalla encendida, 2 cuadros)."""
    cv = Canvas(64, 96)
    dead = state == "powered_off"
    edge = CA if state in ("prompt", "active") else (GA if dead else BO)
    cv.box(6, 4, 57, 87, PA, FP)
    cv.rect(7, 5, 56, 5, edge)
    cv.vline(7, 6, 86, edge if not dead else GA)
    cv.vline(56, 6, 86, SO)
    cv.hline(8, 55, 86, SO)
    # Pantalla.
    sx0, sy0, sx1, sy1 = 12, 10, 51, 45
    screen = {"powered_off": DK, "off": FP, "prompt": FP, "active": CT}[state]
    cv.box(sx0 - 1, sy0 - 1, sx1 + 1, sy1 + 1, screen, FP, cut=False)
    arrow = {"powered_off": BA, "off": TT if f == 0 else CT, "prompt": CA, "active": CB}[state]
    cv.stamp(28, 18, DOWNLOAD, {"#": arrow})
    if state == "active":
        cv.hline(sx0 + 3, sx1 - 3, sy1 - 5, FP)
        cv.hline(sx0 + 3, sx0 + 3 + (sx1 - sx0 - 6) * (1 + f) // 3, sy1 - 5, CB)
    elif not dead:
        cv.hline(sx0 + 3, sx1 - 3, sy1 - 5, PA)
    # Tres pilotos (V1-V3), rejilla de ventilacion y patas.
    for k in range(3):
        x = 19 + k * 10
        cv.rect(x, 52, x + 5, 55, FP)
        lit = state == "active" or (state == "prompt" and f == k % 2)
        cv.rect(x + 1, 53, x + 4, 54, (CA if lit else GA) if not dead else SO)
    for y in range(62, 80, 4):
        cv.hline(14, 49, y, FP if not dead else SO)
        cv.hline(14, 49, y + 1, TR if not dead else PA)
    cv.rect(10, 88, 17, 91, FP)
    cv.rect(46, 88, 53, 91, FP)
    if state == "prompt" and f == 1:
        cv.halo(CT)
    return cv.x2()


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
    out["folders/folder_all_done_00.png"] = folder("all_done", 0)
    for world in WORLD_ICONS:
        out[f"folders/folder_{world}_locked_00.png"] = world_folder(world, "locked", 0)
        for f in range(2):
            out[f"folders/folder_{world}_available_{f:02d}.png"] = world_folder(world, "available", f)
        out[f"folders/folder_{world}_completed_00.png"] = world_folder(world, "completed", 0)
        out[f"folders/folder_{world}_all_done_00.png"] = world_folder(world, "all_done", 0)
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
    out["icons/world_icon_m2_00.png"] = world_icon_feed()
    out["icons/world_icon_m3_00.png"] = world_icon_photo()
    out["icons/world_icon_m4_00.png"] = world_icon_chat()
    out["icons/icon_notas_00.png"] = icon_notas()
    out["icons/icon_calc_00.png"] = icon_calc()
    out["icons/icon_papelera_00.png"] = icon_papelera()
    out["icons/lcd_panel_00.png"] = lcd_panel()
    out["album/album_cell_00.png"] = album_cell(False)
    out["album/album_cell_selected_00.png"] = album_cell(True)
    for st in ("closed", "open", "locked"):
        out[f"album/album_folder_{st}_00.png"] = album_folder(st)
    out["icons/page_dot_current_00.png"] = page_dot(True)
    out["icons/page_dot_other_00.png"] = page_dot(False)
    # Mismos cuadros y progresos que tools/gen_energy_objects.py (outputs).
    for f in range(4):
        out[f"charger/charger_ready_{f:02d}.png"] = charger("ready", f)
    for i in range(8):
        out[f"charger/charger_cooling_{i:02d}.png"] = charger("cooling", progress=i / 7 * 0.875 + 0.0)
    out["charger/charger_spent_00.png"] = charger("spent")
    out.update(menu_outputs())
    out["background/hub_bg_page2_00.png"] = page_background(2)
    out["background/hub_bg_page3_00.png"] = page_background(3)
    out["lock/cloud_lock_plate_00.png"] = cloud_lock_plate()
    out["lock/cloud_lock_slot_on_00.png"] = cloud_lock_slot_on()
    out["installer/installer_powered_off_00.png"] = installer("powered_off", 0)
    for st in ("off", "prompt", "active"):
        for f in range(2):
            out[f"installer/installer_{st}_{f:02d}.png"] = installer(st, f)
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
                           ("completed", "folders/folder_completed", 1, 1.0, True),
                           ("all_done", "folders/folder_all_done", 1, 1.0, True)],
    # Una por mundo con carpeta (icono grande del mundo; folder_frames de worlds).
    **{f"folder_{w}_frames.tres": [("locked", f"folders/folder_{w}_locked", 1, 1.0, True),
                                   ("available", f"folders/folder_{w}_available", 2, 2.0, True),
                                   ("completed", f"folders/folder_{w}_completed", 1, 1.0, True),
                                   ("all_done", f"folders/folder_{w}_all_done", 1, 1.0, True)]
       for w in WORLD_ICONS},
    "installer_frames.tres": [("powered_off", "installer/installer_powered_off", 1, 1.0, True),
                              ("off", "installer/installer_off", 2, 1.5, True),
                              ("prompt", "installer/installer_prompt", 2, 3.0, True),
                              ("active", "installer/installer_active", 2, 4.0, True)],
    "calc_frames.tres": [("powered_off", "calc/calc_off", 1, 1.0, True),
                         ("sleep", "calc/calc_sleep", 3, 2.0, True),
                         ("awake", "calc/calc_awake", 4, 3.0, True)],
    "papelera_frames.tres": [("dormant", "dock_slots/dock_slot_trash", 1, 1.0, True),
                             ("active", "papelera/papelera_active", 4, 6.0, True),
                             ("emptying", "papelera/papelera_emptying", 4, 8.0, False),
                             ("empty", "papelera/papelera_empty", 1, 1.0, True)],
    # Mismas animaciones (nombre, cuadros, fps y bucle) que las charger_* de
    # assets/sprites/energy_objects_frames.tres: las usa Charger (EnergySprite).
    "charger_frames.tres": [("charger_ready", "charger/charger_ready", 4, 8.0, True),
                            ("charger_cooling", "charger/charger_cooling", 8, 0.0, False),
                            ("charger_spent", "charger/charger_spent", 1, 0.0, False)],
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
    # Solo los mundos con carpeta en la pagina 1 del hub (con col y page 1; los
    # 4-6 van a las paginas 2 y 3, paso 0 de docs/propuesta-hub-mundos-4-6.md).
    folder_worlds = [w for w in hub["worlds"] if "col" in w and int(w.get("page", 1)) == 1]
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
    if "charger" in hub:  # cargador del dock (celda sobre el suelo, centrado en x)
        put("charger/charger_ready_00.png", int(hub["charger"]["col"]), 8, dx=16, bottom=True)
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
