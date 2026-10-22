#!/usr/bin/env python3
"""Genera las ilustraciones de los recuerdos de jefe (paso 7 de
docs/propuesta-recuerdos.md §7 y §11.3, 2026-10-22).

Una ilustracion pixel-art por jefe para su capa **Kernel** (la escena completa;
6 en total) y, de cada una, la version **Caché** (la misma imagen borrosa:
pixelada en bloques de BLOCK px con la moda del bloque y un velo en damero que
deja la escena incompleta por los bordes). La capa Raíz y los mensajes van solo
con texto (decision del usuario del 2026-10-18, §8.3). POR SCRIPT, sin
AutoSprite (decision del 2026-10-19, §9.1).

Escenas (data/memories.json, capa Kernel de cada mundo):
  1 Fragmento de concentración: la cocina de noche; Isak y el Abuelito con la
    lupa, el circuito y el LED que por fin enciende.
  2 Fragmento de tiempo: el patio al atardecer; la radio en la silla, el
    Abuelito y Mamá, tres tazas (una esperando) e Isak en la puerta con el
    celular.
  3 Fragmento de imagen: la foto movida de Isak riendo, despeinado y con
    grasa en la mejilla, junto al altavoz desarmado.
  4 Fragmento de amistades: el garaje con la puerta a medio subir, tres bicis
    e Isak poniendo la cadena mientras sus amigos aplauden.
  5 Fragmento de voluntad: la puerta de casa con el letrero «Se arreglan
    cosas», la caja de radios, Isak soldando y la vecina con su radio.
  6 Fragmento de pausa: el escalón de la entrada de noche, el Abuelito e Isak
    sentados con dos tazas, la farola y la luna.

Paleta: SOLO colores de assets/palettes/mundo1.gpl + effects_pulse.gpl (como el
resto del arte del juego), SIN rojos (alerta, alerta_sombra, carmin,
carmin_brillo: el rojo es dano). El ambar (y su sombra) es la luz calida de casa
y la piel iluminada por ella; los detalles cian de Isak (cuello y celular) usan
debug_cian. Opacas (sin transparencia). Personajes sin texto ni voz.

Salidas (rutas relativas a assets/sprites/):
  ui/memories/memory_art_w<N>.png        128x64  capa Kernel (nitida)
  ui/memories/memory_art_w<N>_cache.png  128x64  capa Caché (borrosa)
NotasAlbum las muestra en la ficha del recuerdo (memory_art de la seccion album
de data/hub.json).

Uso (desde la raiz del repo):
  python3 tools/gen_memory_art.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_memory_art.py (en tools/run_tests.sh).
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, Canvas, REPO  # noqa: E402
from PIL import Image  # noqa: E402

SIZE = (128, 64)
WORLDS = (1, 2, 3, 4, 5, 6)
BLOCK = 4
PATH_SHARP = "ui/memories/memory_art_w%d.png"
PATH_CACHE = "ui/memories/memory_art_w%d_cache.png"
# Colores prohibidos (validador): el rojo es dano.
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo")

NP = PAL["noche_profunda"]
SKY = PAL["cielo"]
FM = PAL["fondo_medio"]
RS = PAL["resplandor"]
TS = PAL["tile_sombra"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]
BL = PAL["borde_luz"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
AM = PAL["ambar"]
AMS = PAL["ambar_sombra"]
CY = PAL["debug_cian"]
CC = PAL["pulse_core"]
CD = PAL["pulse_dim"]

SKIN = AMS      # piel a la luz calida de casa
SKIN_HI = AM    # brillo de la piel


class Art(Canvas):
    """Canvas opaco con primitivas de ilustracion."""

    def __init__(self, bg):
        super().__init__(*SIZE)
        self.rect(0, 0, SIZE[0] - 1, SIZE[1] - 1, bg)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.p(x0, y0, c)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disc(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r * 0.6:
                    self.p(x, y, c)

    def ring(self, cx, cy, r, c):
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if r * r - r <= d <= r * r + r:
                    self.p(x, y, c)

    def dither(self, x0, y0, x1, y1, c, phase=0):
        """Damero de `c` sobre lo que haya (transicion suave sin colores nuevos)."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if (x + y + phase) % 2 == 0:
                    self.p(x, y, c)

    def glow(self, cx, cy, r, c, phase=0):
        """Luz de una lampara: damero dentro de r/2 y un pixel de cada cuatro hasta r.
        Solo tine el fondo oscuro (no pisa figuras ni objetos ya dibujados)."""
        dark = {NP, SKY, TS, TB, FM}
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if not (0 <= x < self.w and 0 <= y < self.h) or self.px[x, y] not in dark:
                    continue
                d = (x - cx) ** 2 + (y - cy) ** 2
                if d <= (r * r) // 4 and (x + y + phase) % 2 == 0:
                    self.p(x, y, c)
                elif d <= r * r and x % 2 == 0 and (y + phase) % 2 == 0:
                    self.p(x, y, c)

    def stars(self, pts, c=BL):
        for (x, y) in pts:
            self.p(x, y, c)


def head(a, cx, cy, hair, style="isak", smile=True, face_dir=0):
    """Cabeza de 9x9 a la luz calida: pelo `hair`, ojos y sonrisa de 1 px.
    style: isak (pelo desordenado), abuelito (canas y calva), mama (melena),
    friend (pelo corto)."""
    a.disc(cx, cy, 4, NP)
    a.disc(cx, cy, 3, SKIN)
    a.p(cx - 2 + face_dir, cy - 2, SKIN_HI)
    if style == "isak":
        for x in range(cx - 4, cx + 5):
            a.p(x, cy - 4, hair)
            a.p(x, cy - 3, hair)
        for (dx, dy) in ((-4, -5), (-2, -6), (0, -5), (2, -6), (4, -5), (-4, -2), (4, -2), (5, -3)):
            a.p(cx + dx, cy + dy, hair)
    elif style == "abuelito":
        for (dx, dy) in ((-4, -1), (-4, 0), (4, -1), (4, 0), (-3, -3), (3, -3), (-4, -2), (4, -2)):
            a.p(cx + dx, cy + dy, hair)
        a.hline(cx - 2, cx + 2, cy - 4, SKIN)       # calva
        a.p(cx - 1, cy - 4, SKIN_HI)
        a.hline(cx - 1 + face_dir, cx + 1 + face_dir, cy + 2, G)   # bigote
    elif style == "mama":
        for x in range(cx - 4, cx + 5):
            a.p(x, cy - 4, hair)
        for y in range(cy - 3, cy + 5):
            a.p(cx - 4, y, hair)
            a.p(cx + 4, y, hair)
        a.p(cx - 3, cy - 3, hair)
        a.p(cx + 3, cy - 3, hair)
    else:
        for x in range(cx - 4, cx + 5):
            a.p(x, cy - 4, hair)
        a.p(cx - 4, cy - 3, hair)
        a.p(cx + 4, cy - 3, hair)
    # ojos y boca
    a.p(cx - 1 + face_dir, cy, NP)
    a.p(cx + 2 + face_dir, cy, NP)
    if smile:
        a.p(cx - 1 + face_dir, cy + 2, NP)
        a.p(cx + face_dir, cy + 3 if style != "abuelito" else cy + 2, NP)
        a.p(cx + 1 + face_dir, cy + 3 if style != "abuelito" else cy + 2, NP)
        a.p(cx + 2 + face_dir, cy + 2, NP)


def torso(a, cx, top, bottom, coat, trim=None, width=6):
    """Tronco con hombros redondeados de ancho 2*width+1, de `top` a `bottom`."""
    a.rect(cx - width, top + 1, cx + width, bottom, NP)
    a.rect(cx - width + 1, top, cx + width - 1, bottom, NP)
    a.rect(cx - width + 1, top + 1, cx + width - 1, bottom, coat)
    if trim is not None:
        a.p(cx - 2, top + 1, trim)       # cuello
        a.p(cx + 2, top + 1, trim)
        a.p(cx - width + 1, top + 2, trim)  # parche del hombro


def isak(a, cx, top, bottom, face_dir=0, smile=True):
    """Isak: chaqueta gris oscura con detalles cian en cuello y hombro."""
    torso(a, cx, top + 5, bottom, TL, trim=CY)
    head(a, cx, top, NP, "isak", smile, face_dir)


def table(a, y, x0=0, x1=None, top=TL, front=TS):
    x1 = SIZE[0] - 1 if x1 is None else x1
    a.hline(x0, x1, y, BL)
    a.rect(x0, y + 1, x1, y + 3, top)
    a.rect(x0, y + 4, x1, SIZE[1] - 1, front)
    a.hline(x0, x1, y + 4, NP)


def cup(a, x, y, full=False, steam=False):
    a.rect(x, y, x + 3, y + 3, NP)
    a.rect(x + 1, y, x + 2, y + 2, W)
    a.p(x + 4, y + 1, W)
    if full:
        a.hline(x + 1, x + 2, y, AMS)
    if steam:
        a.p(x + 1, y - 2, G)
        a.p(x + 2, y - 3, G)
        a.p(x + 1, y - 4, G)


def radio(a, x, y, w=14, h=9, open_back=False):
    a.rect(x, y, x + w, y + h, NP)
    a.rect(x + 1, y + 1, x + w - 1, y + h - 1, TL)
    for yy in range(y + 2, y + h - 1, 2):            # rejilla
        for xx in range(x + 2, x + w // 2, 2):
            a.p(xx, yy, TB)
    a.disc(x + w - 4, y + h // 2, 2, G)               # dial
    a.p(x + w - 4, y + h // 2, NP)
    a.line(x + 2, y, x - 2, y - 6, G)                 # antena
    if open_back:
        a.rect(x + w // 2, y + 2, x + w - 7, y + h - 2, RS)
        a.p(x + w // 2 + 1, y + 3, BL)


# --- Escenas (capa Kernel) ---

def scene_w1():
    """Cocina de noche: Isak suelda, el Abuelito acerca la lupa, el LED enciende."""
    a = Art(TB)
    a.dither(0, 0, 127, 40, TS, 1)
    # ventana con la noche
    a.rect(6, 4, 30, 22, NP)
    a.rect(7, 5, 29, 21, SKY)
    a.vline(18, 5, 21, NP)
    a.hline(7, 29, 13, NP)
    a.stars([(10, 8), (24, 7), (14, 17), (27, 18)])
    # lampara colgante y su luz
    a.vline(64, 0, 6, NP)
    a.rect(59, 7, 69, 9, G)
    a.hline(60, 68, 10, NP)
    a.glow(64, 16, 22, AMS)
    a.rect(62, 10, 66, 11, AM)
    # Isak (izquierda) y el Abuelito (derecha), sentados tras la mesa
    isak(a, 42, 22, 45, face_dir=1)
    torso(a, 90, 31, 45, FM)
    head(a, 90, 26, G, "abuelito", True, -1)
    table(a, 44)
    # placa del circuito con pistas y el LED encendido
    a.rect(52, 46, 76, 52, NP)
    a.rect(53, 47, 75, 51, RS)
    a.hline(55, 63, 49, BL)
    a.vline(63, 48, 50, BL)
    a.hline(66, 72, 48, BL)
    a.rect(69, 49, 71, 50, TS)                       # chip
    a.p(58, 47, AM)                                  # LED
    a.p(58, 46, CC)
    a.p(57, 45, AM)
    a.p(59, 45, AM)
    a.p(58, 44, AM)
    # soldador (mano de Isak)
    a.line(44, 44, 54, 48, G)
    a.p(55, 48, W)
    a.rect(42, 42, 44, 44, SKIN)
    # lupa (mano del Abuelito)
    a.line(84, 42, 76, 38, TS)
    a.ring(70, 35, 4, G)
    a.disc(70, 35, 3, RS)
    a.p(69, 34, W)
    a.rect(84, 41, 86, 43, SKIN)
    return a.img


def scene_w2():
    """Patio al atardecer: radio en la silla, el Abuelito y Mamá, tres tazas, Isak en la puerta."""
    a = Art(SKY)
    a.rect(0, 0, 127, 10, FM)
    a.dither(0, 11, 127, 18, FM)
    a.rect(0, 19, 127, 30, RS)
    a.dither(0, 26, 127, 34, AMS)
    a.disc(40, 34, 6, AM)                             # sol bajo
    a.dither(30, 26, 52, 34, AM, 1)
    a.rect(0, 35, 127, 63, TB)                        # suelo del patio
    a.hline(0, 127, 35, TL)
    a.dither(0, 36, 127, 40, TL)
    # casa a la derecha con la puerta encendida
    a.rect(100, 4, 127, 63, TS)
    a.hline(100, 127, 4, BL)
    a.rect(106, 22, 120, 52, NP)
    a.rect(107, 23, 119, 52, AMS)
    a.dither(107, 23, 119, 52, AM)
    # Isak en la puerta con el celular (luz cian en la cara)
    torso(a, 113, 35, 52, TL, trim=CY, width=5)
    head(a, 113, 30, NP, "isak", False, -1)
    a.rect(109, 39, 110, 41, CY)
    a.p(110, 38, CC)
    # mesa con tres tazas (una esperando, llena y humeando)
    a.rect(56, 44, 86, 46, TL)
    a.hline(56, 86, 44, BL)
    a.vline(58, 47, 56, TL)
    a.vline(84, 47, 56, TL)
    cup(a, 60, 40)
    cup(a, 68, 40)
    cup(a, 77, 40, full=True, steam=True)
    # silla con la radio abierta y el Abuelito sentado a su lado
    a.rect(8, 44, 26, 46, TL)
    a.vline(9, 47, 56, TL)
    a.vline(25, 47, 56, TL)
    radio(a, 10, 34, open_back=True)
    torso(a, 36, 41, 56, FM, width=5)
    head(a, 36, 36, G, "abuelito", True, -1)
    a.rect(29, 46, 31, 48, SKIN)
    a.line(31, 47, 24, 43, G)                         # destornillador
    # Mamá de pie, con las instrucciones
    torso(a, 50, 33, 56, RS, width=5)
    head(a, 50, 28, NP, "mama", True, -1)
    a.rect(42, 36, 46, 41, W)
    a.hline(43, 45, 38, G)
    a.hline(43, 45, 40, G)
    return a.img


def scene_w3():
    """La foto movida: Isak riendo, despeinado, con grasa en la mejilla; el altavoz desarmado."""
    a = Art(TB)
    a.dither(0, 0, 127, 63, TS, 1)
    a.glow(64, 30, 34, AMS)
    table(a, 50)
    # altavoz desarmado y un destornillador sobre la mesa
    a.disc(16, 46, 7, NP)
    a.disc(16, 46, 6, TL)
    a.disc(16, 46, 3, TB)
    a.disc(16, 46, 1, G)
    a.line(100, 56, 116, 53, G)
    a.rect(112, 52, 117, 54, RS)
    # la foto (marco blanco, ligeramente movida: doble contorno)
    a.rect(38, 4, 90, 58, NP)
    a.rect(39, 5, 89, 57, W)
    a.rect(42, 8, 86, 48, AMS)
    a.dither(42, 8, 86, 48, TB)
    a.dither(42, 8, 86, 20, AM, 1)
    # Isak de cerca: cabeza grande riendo
    a.disc(64, 32, 13, NP)
    a.disc(64, 32, 12, SKIN)
    a.dither(54, 22, 74, 30, SKIN_HI, 1)
    for x in range(51, 78):                           # pelo revuelto
        for y in range(18, 25 - abs(x - 64) // 5):
            a.p(x, y, NP)
    for (x, y) in ((50, 22), (52, 17), (56, 16), (60, 14), (64, 15), (68, 14), (72, 16), (76, 17),
                   (78, 21), (49, 25), (79, 25), (58, 15), (70, 15)):
        a.p(x, y, NP)
        a.p(x, y + 1, NP)
    for dx in (-6, 5):                                # ojos cerrados de reír (arcos)
        a.hline(64 + dx - 1, 64 + dx + 2, 30, NP)
        a.p(64 + dx - 2, 31, NP)
        a.p(64 + dx + 3, 31, NP)
    a.rect(58, 35, 70, 40, NP)                        # boca abierta
    a.rect(59, 35, 69, 36, W)
    a.rect(60, 38, 68, 39, TS)
    a.rect(73, 34, 75, 35, TB)                        # mancha de grasa
    a.p(76, 35, TB)
    # cuello de la chaqueta con el detalle cian
    a.rect(52, 44, 76, 48, TL)
    a.p(58, 45, CY)
    a.p(70, 45, CY)
    # sombra doble del borde (la foto está movida)
    a.dither(86, 8, 88, 48, G)
    return a.img


def bike(a, x, y, frame_c=RS):
    a.ring(x, y, 5, G)
    a.ring(x + 16, y, 5, G)
    a.p(x, y, NP)
    a.p(x + 16, y, NP)
    a.line(x, y, x + 6, y - 7, frame_c)
    a.line(x + 6, y - 7, x + 13, y - 7, frame_c)
    a.line(x + 13, y - 7, x + 16, y, frame_c)
    a.line(x + 6, y - 7, x + 8, y, frame_c)
    a.line(x, y, x + 8, y, frame_c)
    a.hline(x + 4, x + 7, y - 9, NP)                  # sillin
    a.line(x + 13, y - 7, x + 14, y - 11, G)          # manillar


def scene_w4():
    """Garaje: la puerta a medio subir, tres bicis, Isak pone la cadena y sus amigos aplauden."""
    a = Art(TB)
    # puerta a medio subir (lamas) y la calle de noche por debajo
    a.rect(0, 0, 127, 20, TL)
    for y in range(2, 20, 3):
        a.hline(0, 127, y, TB)
    a.hline(0, 127, 20, NP)
    a.rect(0, 21, 127, 34, SKY)
    a.stars([(12, 25), (40, 23), (70, 27), (98, 24), (120, 28)])
    a.rect(0, 30, 127, 34, FM)
    a.rect(0, 35, 127, 63, TS)                        # suelo del garaje
    a.hline(0, 127, 35, TL)
    a.glow(64, 23, 22, AMS)                           # bombilla
    a.disc(64, 23, 2, AM)
    a.p(64, 21, W)
    # bicis: dos apoyadas, la del amigo con la cadena suelta
    bike(a, 6, 56, FM)
    bike(a, 100, 56, RS)
    bike(a, 48, 57, BL)
    a.line(56, 57, 62, 60, G)                         # cadena colgando
    a.line(62, 60, 64, 57, G)
    # Isak de rodillas junto a la bici
    torso(a, 74, 47, 58, TL, trim=CY, width=5)
    head(a, 74, 42, NP, "isak", True, -1)
    a.rect(66, 55, 68, 57, SKIN)
    # dos amigos aplaudiendo (brazos arriba)
    for (cx, coat, hair) in ((30, FM, NP), (90, RS, TL)):
        torso(a, cx, 38, 58, coat, width=5)
        head(a, cx, 33, hair, "friend", True, 0)
        a.line(cx - 5, 40, cx - 8, 33, coat)
        a.line(cx + 5, 40, cx + 8, 33, coat)
        a.rect(cx - 9, 31, cx - 8, 32, SKIN)
        a.rect(cx + 8, 31, cx + 9, 32, SKIN)
    a.stars([(26, 29), (34, 29), (86, 29), (94, 29)], W)   # destellos del aplauso
    return a.img


def scene_w5():
    """La puerta de casa: el letrero «Se arreglan cosas», la caja de radios, Isak suelda, la vecina llega."""
    a = Art(SKY)
    a.dither(0, 0, 127, 20, FM)
    a.rect(0, 46, 127, 63, TB)                        # acera
    a.hline(0, 127, 46, TL)
    # fachada y puerta
    a.rect(56, 2, 127, 45, TS)
    a.hline(56, 127, 2, BL)
    a.rect(80, 12, 104, 45, NP)
    a.rect(81, 13, 103, 45, TL)
    a.vline(92, 13, 45, TB)
    a.p(98, 30, AM)                                   # pomo
    # letrero escrito a mano en la puerta
    a.rect(83, 16, 101, 25, NP)
    a.rect(84, 17, 100, 24, W)
    for (x0, x1, y) in ((86, 91, 19), (93, 98, 19), (86, 95, 22)):
        for x in range(x0, x1 + 1):
            a.p(x, y + (x % 3 == 0), NP)
    # lámpara del portal
    a.rect(108, 14, 111, 18, AM)
    a.glow(110, 17, 12, AMS)
    # el Abuelito en la puerta, brazos cruzados
    torso(a, 116, 33, 45, FM, width=5)
    head(a, 116, 28, G, "abuelito", True, -1)
    a.hline(111, 121, 38, SKIN)
    # escalón y caja de radios
    a.rect(60, 42, 110, 45, TL)
    a.hline(60, 110, 42, BL)
    a.rect(62, 32, 78, 41, AMS)
    a.hline(62, 78, 32, AM)
    radio(a, 63, 27, w=8, h=5)
    radio(a, 71, 29, w=7, h=4)
    # Isak sentado con una radio en las rodillas y el soldador
    torso(a, 46, 35, 52, TL, trim=CY, width=5)
    head(a, 46, 30, NP, "isak", True, -1)
    radio(a, 36, 44, w=12, h=7, open_back=True)
    a.line(52, 44, 44, 47, G)
    a.p(43, 47, W)
    a.p(42, 46, CC)
    # la vecina llega con su radio
    torso(a, 14, 36, 58, RS, width=5)
    head(a, 14, 31, G, "mama", True, 1)
    radio(a, 18, 42, w=10, h=6)
    return a.img


def scene_w6():
    """El escalón de noche: el Abuelito e Isak sentados con dos tazas; la farola y la luna."""
    a = Art(NP)
    a.dither(0, 20, 127, 40, SKY)
    a.rect(0, 41, 127, 63, SKY)
    a.stars([(8, 6), (22, 14), (40, 4), (58, 11), (77, 5), (90, 15), (104, 3), (52, 22), (14, 26)])
    a.disc(110, 12, 6, W)                             # luna
    a.disc(112, 10, 5, NP)
    a.p(104, 10, G)
    # farola con su luz cálida
    a.vline(16, 18, 52, TL)
    a.rect(13, 14, 19, 17, NP)
    a.rect(14, 15, 18, 17, AM)
    a.glow(16, 17, 14, AMS)
    a.rect(0, 52, 127, 63, TB)                        # calle
    a.hline(0, 127, 52, TL)
    # fachada y escalón
    a.rect(40, 18, 127, 51, TS)
    a.hline(40, 127, 18, TL)
    a.rect(84, 22, 100, 46, NP)                       # puerta entornada con luz
    a.rect(85, 23, 99, 46, TB)
    a.rect(85, 23, 88, 46, AMS)
    a.rect(44, 47, 124, 51, TL)
    a.hline(44, 124, 47, BL)
    # el Abuelito e Isak sentados en el escalón, mirando la calle
    torso(a, 60, 35, 47, FM, width=5)
    head(a, 60, 30, G, "abuelito", True, 0)
    torso(a, 75, 36, 47, TL, trim=CY, width=5)
    head(a, 75, 31, NP, "isak", True, 0)
    cup(a, 64, 43, full=True, steam=True)
    cup(a, 69, 43, full=True, steam=True)
    # piernas en el escalón de abajo
    a.rect(55, 48, 65, 51, TB)
    a.rect(70, 48, 80, 51, TB)
    return a.img


SCENES = {1: scene_w1, 2: scene_w2, 3: scene_w3, 4: scene_w4, 5: scene_w5, 6: scene_w6}


def blur(img):
    """Capa Caché: bloques de BLOCK px con el color mas frecuente del bloque y un velo
    en damero de noche_profunda por los bordes y en bloques sueltos (escena incompleta)."""
    src = img.load()
    out = Image.new("RGBA", img.size)
    dst = out.load()
    w, h = img.size
    for by in range(0, h, BLOCK):
        for bx in range(0, w, BLOCK):
            counts = {}
            for y in range(by, min(by + BLOCK, h)):
                for x in range(bx, min(bx + BLOCK, w)):
                    counts[src[x, y]] = counts.get(src[x, y], 0) + 1
            c = max(sorted(counts), key=lambda k: counts[k])
            for y in range(by, min(by + BLOCK, h)):
                for x in range(bx, min(bx + BLOCK, w)):
                    dst[x, y] = c
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    for y in range(h):
        for x in range(w):
            # elipse normalizada: 0 en el centro, 1 en el borde
            d = ((x - cx) / (w / 2.0)) ** 2 + ((y - cy) / (h / 2.0)) ** 2
            bx, by = x // BLOCK, y // BLOCK
            hole = (bx * 7 + by * 13) % 17 == 0
            if d > 1.0 or (d > 0.7 and (x + y) % 2 == 0) or (hole and (x + y) % 2 == 0):
                dst[x, y] = NP
    return out


def outputs():
    out = {}
    for world in WORLDS:
        sharp = SCENES[world]()
        out[PATH_SHARP % world] = sharp
        out[PATH_CACHE % world] = blur(sharp)
    return out


def preview(imgs, path, scale=4):
    pad = 4
    keys = sorted(imgs)
    cols = 2
    rows = (len(keys) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (SIZE[0] + pad) + pad, rows * (SIZE[1] + pad) + pad), PAL["cielo"])
    for i, k in enumerate(sorted(keys, key=lambda k: (int(k.split("_w")[1][0]), "cache" in k))):
        sheet.alpha_composite(imgs[k], (pad + (i % cols) * (SIZE[0] + pad), pad + (i // cols) * (SIZE[1] + pad)))
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(path)


if __name__ == "__main__":
    imgs = outputs()
    dest = os.path.join(REPO, "assets/sprites")
    if "--dry-run" not in sys.argv:
        for k, im in imgs.items():
            p = os.path.join(dest, k)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            im.save(p)
    if "--preview" in sys.argv:
        preview(imgs, sys.argv[sys.argv.index("--preview") + 1],
                int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 4)
    print(f"{len(imgs)} PNG")
