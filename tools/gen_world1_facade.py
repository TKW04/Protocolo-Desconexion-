#!/usr/bin/env python3
"""Genera la fachada de la torre del Mundo 1 (arte de fondo del paso 11 de
docs/propuesta-1-2.md §10; modo vertical «tower» de data/world1_background.json):
el centro de notificaciones visto como una torre de pestanas.

Estilo circuito limpio, como el resto del Mundo 1: pixeles logicos de 2x2 px,
solo colores de assets/palettes/mundo1.gpl + effects_pulse.gpl, sin rojos ni
ambar (el rojo es dano y el ambar, los puntos de atencion) ni el cian del Debug
(se reserva a lo interactivo). Alfa 0 o 255. Desde el 2026-10-17 (contraste del 1-2)
la fachada solo usa noche_profunda, cielo y fondo_medio (ni resplandor ni borde_luz,
que es el borde claro de las plataformas) y tiene una tarjeta por columna y periodo;
en modo torre las capas lejanas van ademas atenuadas (tower_dim de
data/world1_background.json). Las pestanas siguen con fondo_medio y borde_luz.

Salidas (assets/sprites/backgrounds/):
  mundo1_bg_fachada.png        1792x768 (896x384 logicos). Capa de la fachada que se
                               repite en VERTICAL sin costura: dos periodos identicos de
                               384 px (se dibuja con envoltura en y), asi que la union al
                               repetirse es la misma que la del centro. Columnas de
                               tarjetas de notificacion apagadas (icono y lineas de texto;
                               una por columna y periodo), pistas de
                               circuito verticales continuas y huecos transparentes por los
                               que se ve el cielo (fijo en Y en la torre: sin costura).
  mundo1_tab_<id>.png          pestana con rotulo de cada piso del 1-2 (Mensajes, Correo,
                               Recordatorios, Actualizaciones): solo glifos de la fuente
                               de textos (tools/gen_text_font.py, assets/sprites/ui/text_font.png)
                               en borde_luz sobre fondo_medio, con icono propio por piso.
  _mundo1_facade_preview.png   vista de revision: dos repeticiones de la fachada con las
                               cuatro pestanas encima (no la usa el juego)

World1Background (scripts/levels/world1_background.gd) pone la fachada como capa
«Fachada» en modo torre y las pestanas («Pestanas») en lo alto de cada piso cuyo
tramo se llame «Piso N: <rotulo>» (tools/build_level.py le pasa tab_labels y
tab_bands).

Uso (desde la raiz del repo): python3 tools/gen_world1_facade.py [--dry-run]
Validador: tools/validate_world1_facade.py (en tools/run_tests.sh).
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, REPO  # noqa: E402
import gen_text_font as tf  # noqa: E402
from PIL import Image  # noqa: E402

UNIT = 2
FACADE_W, FACADE_H = 896, 384          # logicos (x2 = 1792x768 px)
PERIOD = 192                            # periodo vertical (logico): FACADE_H / 2
BG_DIR = "backgrounds"
FACADE = BG_DIR + "/mundo1_bg_fachada.png"
PREVIEW = BG_DIR + "/_mundo1_facade_preview.png"
TABS = {
    "mensajes": "Mensajes",
    "correo": "Correo",
    "recordatorios": "Recordatorios",
    "actualizaciones": "Actualizaciones",
}
TAB_H = 22                              # alto logico de la pestana

N = PAL["noche_profunda"]
SKY = PAL["cielo"]
FM = PAL["fondo_medio"]
R = PAL["resplandor"]
TS = PAL["tile_sombra"]
BL = PAL["borde_luz"]
G = PAL["banner_gris"]
CLEAR = (0, 0, 0, 0)

# Colores que la fachada (no las pestanas) tampoco usa desde el 2026-10-17: los claros de las
# plataformas y de los objetos (validador).
FACADE_FORBIDDEN = ("resplandor", "borde_luz", "banner_blanco", "banner_gris", "tile_luz")

# Colores prohibidos en la fachada y las pestanas (validador).
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra", "debug_cian",
             "pulse_core", "pulse_mid", "pulse_dim")


class WrapCanvas:
    """Lienzo logico con envoltura en y (opcional): lo que sale por abajo entra por arriba."""

    def __init__(self, w, h, wrap_y=False):
        self.img = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.img.load()
        self.w, self.h, self.wrap_y = w, h, wrap_y

    def p(self, x, y, c):
        if self.wrap_y:
            y %= self.h
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):  # inclusivo
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.p(x, y, c)

    def box(self, x0, y0, x1, y1, fill, outline):
        """Caja con contorno de 1 px y esquinas cortadas."""
        self.rect(x0, y0, x1, y1, outline)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
        for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            self.p(x, y, CLEAR)

    def scaled(self):
        return self.img.resize((self.w * UNIT, self.h * UNIT), Image.NEAREST)


# --- Fachada ---

# Columnas de tarjetas: (x0, ancho, desfase vertical dentro del periodo). Desde el 2026-10-17
# (ajuste del 1-2 tras probarlo: «el fondo hace que se pierdan las plataformas») hay UNA tarjeta por
# columna y periodo (antes dos), mas estrechas, y todo baja un escalon de la paleta: relleno
# noche_profunda (mas oscuro que el cuerpo de los tiles, tile_base), contornos y lineas en cielo y
# los detalles en fondo_medio; ya no usa resplandor ni borde_luz (el borde claro de las plataformas).
COLUMNS = ((40, 196, 0), (350, 196, 112), (660, 196, 48))
CARD_H = 52


def card(cv, x0, y0, w, variant):
    """Tarjeta de notificacion apagada: caja noche_profunda con borde cielo, icono y lineas."""
    cv.box(x0, y0, x0 + w - 1, y0 + CARD_H - 1, N, SKY)
    # Cabecera (pestana de la tarjeta).
    cv.rect(x0 + 2, y0 + 2, x0 + w - 3, y0 + 3, SKY)
    # Icono: cuadro redondeado con un simbolo distinto por variante.
    ix, iy = x0 + 8, y0 + 12
    cv.box(ix, iy, ix + 21, iy + 21, N, SKY)
    if variant == 0:      # sobre
        cv.rect(ix + 4, iy + 6, ix + 17, iy + 15, SKY)
        for k in range(7):
            cv.p(ix + 4 + k, iy + 6 + k // 2 + 1, FM)
            cv.p(ix + 17 - k, iy + 6 + k // 2 + 1, FM)
    elif variant == 1:    # bocadillo
        cv.box(ix + 4, iy + 5, ix + 17, iy + 13, N, FM)
        cv.rect(ix + 6, iy + 14, ix + 7, iy + 16, FM)
    else:                 # campana
        cv.rect(ix + 8, iy + 4, ix + 13, iy + 5, FM)
        cv.rect(ix + 6, iy + 6, ix + 15, iy + 13, FM)
        cv.rect(ix + 5, iy + 14, ix + 16, iy + 15, FM)
        cv.rect(ix + 10, iy + 16, ix + 11, iy + 17, FM)
    # Lineas de texto (barras) de distinta longitud.
    tx = ix + 30
    lens = ((w - 54, w - 90), (w - 70, w - 110), (w - 60, w - 130))[variant]
    cv.rect(tx, y0 + 14, tx + lens[0], y0 + 15, SKY)
    cv.rect(tx, y0 + 22, tx + lens[1], y0 + 22, SKY)
    cv.rect(tx, y0 + 29, tx + lens[1] - 20, y0 + 29, SKY)
    # Hora en la esquina (puntos).
    cv.rect(x0 + w - 18, y0 + 6, x0 + w - 16, y0 + 7, SKY)
    cv.rect(x0 + w - 13, y0 + 6, x0 + w - 8, y0 + 7, SKY)


def trace(cv, x, nodes):
    """Pista de circuito vertical continua (envuelve en y) con nodos cada periodo."""
    for y in range(cv.h):
        cv.p(x, y, SKY)
    for ny in nodes:
        for k in range(2):
            cv.rect(x - 2, ny + k * PERIOD - 2, x + 2, ny + k * PERIOD + 2, SKY)
            cv.rect(x - 1, ny + k * PERIOD - 1, x + 1, ny + k * PERIOD + 1, FM)


def facade_logical():
    cv = WrapCanvas(FACADE_W, FACADE_H, wrap_y=True)
    # Marcos laterales de la torre (el canto del telefono).
    for x0, x1 in ((0, 9), (FACADE_W - 10, FACADE_W - 1)):
        cv.rect(x0, 0, x1, FACADE_H - 1, N)
        cv.rect(x0 + (9 if x0 == 0 else 0), 0, x0 + (9 if x0 == 0 else 0), FACADE_H - 1, SKY)
        for y in range(0, FACADE_H, 24):
            cv.rect(x0 + 3, y + 8, x1 - 3, y + 8, SKY)
    # Pistas entre columnas.
    trace(cv, 293, (30, 130))
    trace(cv, 603, (70, 170))
    for k in range(2):  # dos periodos identicos
        for ci, (x0, w, off) in enumerate(COLUMNS):
            y0 = k * PERIOD + off
            card(cv, x0, y0, w, ci % 3)
            # Conector de la tarjeta a su pista.
            if ci == 0:
                cv.rect(x0 + w, y0 + 26, 293, y0 + 26, SKY)
            elif ci == 1:
                cv.rect(x0 + w, y0 + 26, 603, y0 + 26, SKY)
            else:
                cv.rect(603, y0 + 26, x0 - 1, y0 + 26, SKY)
    return cv


def facade():
    return facade_logical().scaled()


# --- Pestanas ---

def text_cells(text):
    glyphs = tf.build_glyphs()
    out = []
    for ch in text:
        if ch == " ":
            out.append((None, tf.SPACE_ADVANCE, 0))
        else:
            rows = glyphs[ch]
            # xoffset propio de la fuente (la «j» desde el 2026-10-28, METRIC_OVERRIDES).
            out.append((rows, tf.advance_of(ch, len(rows[0])), tf.xoffset_of(ch)))
    return out


def text_width(text):
    return sum(adv for _, adv, _ in text_cells(text)) - 1


ICONS = {
    "mensajes": ["##########", "#........#", "#.##.###.#", "#........#", "#.####...#", "#........#",
                 "####.#####", "...##.....", "...#......"],
    "correo": ["##########", "##......##", "#.#....#.#", "#..#..#..#", "#...##...#", "#........#",
               "##########"],
    "recordatorios": ["..######..", ".#..#...#.", "#...#....#", "#...#....#", "#...###..#", "#........#",
                      ".#......#.", "..######..", ".#......#."],
    "actualizaciones": ["....##....", "...####...", "..##.###..", ".##...###.", "##.....###", ".........#",
                        "#.........", "###.....##", ".###...##.", "..###.##..", "...####...", "....##...."],
}


def tab(tab_id):
    label = TABS[tab_id]
    tw = text_width(label)
    icon = ICONS[tab_id]
    iw = len(icon[0])
    w = 8 + iw + 6 + tw + 10
    cv = WrapCanvas(w, TAB_H)
    # Forma de pestana: esquinas de arriba redondeadas, base recta y abierta (linea de piso).
    cv.rect(2, 0, w - 3, TAB_H - 1, R)
    cv.rect(1, 1, w - 2, TAB_H - 1, R)
    cv.rect(0, 2, w - 1, TAB_H - 1, R)
    cv.rect(2, 1, w - 3, TAB_H - 3, FM)
    cv.rect(1, 2, w - 2, TAB_H - 3, FM)
    cv.rect(3, 1, w - 4, 1, BL)            # brillo del canto superior
    cv.rect(0, TAB_H - 2, w - 1, TAB_H - 1, SKY)  # base: se apoya en la fachada
    # Icono.
    oy = (TAB_H - 2 - len(icon)) // 2
    for j, row in enumerate(icon):
        for i, ch in enumerate(row):
            if ch == "#":
                cv.p(8 + i, oy + j, BL)
    # Rotulo con los glifos de la fuente de textos.
    x = 8 + iw + 6
    ty = (TAB_H - 2 - 12) // 2 + 1
    for rows, adv, xo in text_cells(label):
        if rows is not None:
            for j, row in enumerate(rows):
                for i, ch in enumerate(row):
                    if ch == "#":
                        cv.p(x + xo + i, ty + j, BL)
        x += adv
    return cv.scaled()


def outputs():
    out = {FACADE: facade()}
    for tab_id in TABS:
        out["%s/mundo1_tab_%s.png" % (BG_DIR, tab_id)] = tab(tab_id)
    return out


def preview(imgs):
    fac = imgs[FACADE]
    sky = Image.open(os.path.join(REPO, "assets/sprites/backgrounds/mundo1_bg_cielo.png")).convert("RGBA")
    sheet = Image.new("RGBA", (fac.width, fac.height * 2), PAL["noche_profunda"])
    for k in range(2):
        for x in range(0, fac.width, sky.width):
            sheet.alpha_composite(sky, (x, k * fac.height))
    sheet.alpha_composite(fac, (0, 0))
    sheet.alpha_composite(fac, (0, fac.height))
    y = 24
    for tab_id in TABS:
        t = imgs["%s/mundo1_tab_%s.png" % (BG_DIR, tab_id)]
        sheet.alpha_composite(t, ((fac.width - t.width) // 2, y))
        y += fac.height // 2
    return sheet.convert("RGB")


if __name__ == "__main__":
    imgs = outputs()
    dest = os.path.join(REPO, "assets/sprites")
    if "--dry-run" not in sys.argv:
        for k, im in imgs.items():
            im.save(os.path.join(dest, k))
        preview(imgs).save(os.path.join(dest, PREVIEW))
    print("%d PNG + %s" % (len(imgs), PREVIEW))
