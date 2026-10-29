#!/usr/bin/env python3
"""Arte por script de los objetos y enemigos del Mundo 5 «La Tienda» (paso 9 de docs/propuesta-mundo-5.md §8 y §6.3).

En el juego los objetos y enemigos del Mundo 5 se dibujan por codigo (cada script lee sus colores por nombre de la
seccion palette de data/world5_objects.json y de la seccion de su tipo); este script dibuja lo mismo con la paleta
del mundo (tools/palette_mundo5_provisional.py con la variante elegida de tools/palette_mundo5_variants.py) en PNG,
que usan las fichas del album (tools/gen_album_cards.py), la comparativa de paletas
(tools/palette_mundo5_variants.py --preview) y sirven de referencia del aspecto. 1 px = 1 px de pantalla. Los
textos de los carteles son renglones (barras) y las cifras, digitos de 3 x 5 px a x2: el juego escribe el texto
con la fuente. Reglas de §6.1 en el dibujo: nada rojo ni naranja (el precio tachado, en magenta), el blanco
(debug_blanco) solo en lo que enseña o hace brillar el Debug y siempre con contorno tienda_noche de 1 px.

Objetos (assets/sprites/props/world5/):
  shop_item_00.png             tienda (64 x 96): estante con el producto de Sync (cruz magenta) y su etiqueta
  shop_item_energy_00.png      tienda (64 x 96): el producto de energia (pila violeta)
  shortcut_door_00.png         atajo (64 x 192): puerta de 40 px con el cartel amarillo «Atajo: 3 ◆»
  shortcut_door_debug_00.png   atajo con el Debug: el icono blanco de la trampa (reloj de «Procesando») encima
  shortcut_door_open_00.png    atajo pagado: el hueco abierto
  refund_desk_00.png           Devoluciones (128 x 96): mostrador con su cartel crema
  surprise_box_00.png          caja sorpresa (64 x 64): caja crema con lazo magenta y «?»
  surprise_box_debug_00.png    caja con el Debug: translucida (trama) con su contenido (rombo de puntos) y contorno
  surprise_box_open_00.png     caja abierta
  countdown_platform_00.png    cuenta regresiva (128 x 32): tarjeta amarilla con 5 segmentos magenta
  terms_gate_00.png            Terminos y condiciones (256 x 192): puerta de letra pequena, «ACEPTAR» enorme al pie
                               y el «rechazar» diminuto arriba
  shutter_00.png               persiana de suelo (192 x 64): lamas con candado y cartel
  shutter_wall_00.png          persiana de pared (64 x 192)
  price_rail_00.png            ranura de precios (192 x 192): hilos con etiquetas y la fila libre del Filo
  clearance_shelf_00.png       estanteria de saldos en pie (64 x 128) con su etiqueta «SALDO»
  clearance_shelf_down_00.png  estanteria tumbada (128 x 64)
  free_trial_box_00.png        «Prueba gratis» (96 x 96): caja de regalo magenta con lazo amarillo y brillo
  wishlist_platform_00.png     lista de deseos (192 x 64): tarjeta crema con borde magenta y el reloj encima
  wish_strike_00.png           tachon (192 x 64): renglon crema tachado en magenta
  calc_register_00.png         caja registradora de Calc (64 x 192): puerta con la pantalla LCD «2 / 0»
  sale_sign_00.png             cartel de rebajas (128 x 64): decorado, «-50» en magenta sobre amarillo
Enemigos (assets/sprites/enemies/world5/; la Suscripcion, PROVISIONAL hasta AutoSprite, paso 24 y opcional):
  offer_sign_00.png            Oferta de pie (64 x 64): cartel amarillo con el «99» tachado en magenta y el «9»
  offer_sign_wall_00.png       Oferta colgada (64 x 48)
  subscription_placeholder_00.png  Suscripcion (48 x 48): tarjeta con sonrisa y brillo magenta (nunca roja)

Uso: python3 -I tools/gen_world5_objects.py [--check]   (--check: 1 si algun PNG no esta al dia o se sale de la
paleta del Mundo 5)
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo5_provisional as pal  # noqa: E402

OUT_OBJECTS = os.path.join("assets", "sprites", "props", "world5")
OUT_ENEMIES = os.path.join("assets", "sprites", "enemies", "world5")


def palette_colors(rows):
    return {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in rows}


COLORS = palette_colors(pal.COLORS + [pal.DEBUG])


def C(name):
    return COLORS[name]


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ------------------------------------------------------------------ piezas comunes
DIGITS = {
    "0": ("###", "#.#", "#.#", "#.#", "###"), "1": (".#.", "##.", ".#.", ".#.", "###"),
    "2": ("###", "..#", "###", "#..", "###"), "3": ("###", "..#", ".##", "..#", "###"),
    "5": ("###", "#..", "###", "..#", "###"), "9": ("###", "#.#", "###", "..#", "###"),
    "-": ("...", "...", "###", "...", "..."), "?": ("###", "..#", ".##", "...", ".#."),
}


def digits(d, x, y, text, color, k=2):
    """Cifras de 3 x 5 px a escala k (el juego las escribe con la fuente)."""
    for ch in text:
        rows = DIGITS[ch]
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c == "#":
                    d.rectangle((x + i * k, y + j * k, x + i * k + k - 1, y + j * k + k - 1), fill=C(color))
        x += 4 * k
    return x


def text_lines(d, x0, y0, widths, color="negro_medio", gap=6, h=2):
    for k, w in enumerate(widths):
        d.rectangle((x0, y0 + k * gap, x0 + w, y0 + k * gap + h - 1), fill=C(color))


def rhombus(d, cx, cy, r, color, outline=None):
    pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    d.polygon(pts, fill=C(color), outline=C(outline) if outline else None)


def frame(d, x0, y0, x1, y1, fill, edge="gris_etiqueta"):
    d.rectangle((x0, y0, x1, y1), fill=C(fill), outline=C(edge))


def battery(d, cx, cy, color):
    d.rectangle((cx - 6, cy - 9, cx + 6, cy + 9), outline=C(color), width=2)
    d.rectangle((cx - 2, cy - 12, cx + 2, cy - 10), fill=C(color))
    d.rectangle((cx - 3, cy - 1, cx + 3, cy + 6), fill=C(color))


def price_tag(d, x0, y0, text, fill="amarillo_rebajas", ink="negro_medio"):
    w = 4 * 2 * len(text) + 12
    d.rectangle((x0, y0, x0 + w, y0 + 15), fill=C(fill), outline=C("tienda_noche"))
    end = digits(d, x0 + 3, y0 + 3, text, ink)
    rhombus(d, end + 2, y0 + 8, 3, ink)
    return w


def door_frame(d, h, door="negro_medio"):
    """Marco gris de 64 px con la puerta de 40 px centrada (ShortcutDoor / CalcRegister, width_px 40)."""
    d.rectangle((0, 0, 63, h - 1), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))
    d.rectangle((12, 8, 51, h - 1), fill=C(door))
    d.line((12, 8, 51, 8), fill=C("gris_etiqueta"))


def outline_opaque(img, color):
    """Contorno de 1 px por fuera de lo opaco (regla 2 de §6.1: lo que revela el Debug)."""
    src = img.copy().load()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = x + dx, y + dy
                if 0 <= qx < img.width and 0 <= qy < img.height and src[qx, qy][3] == 255:
                    px[x, y] = C(color)
                    break
    return img


def trap_icon(size=20):
    """Icono de la trampa «Procesando pago…» (reloj) en debug_blanco con contorno de 1 px."""
    img, d = canvas(size + 2, size + 2)
    r = size // 2
    d.ellipse((1, 1, size, size), outline=C("debug_blanco"), width=2)
    d.line((r + 1, 5, r + 1, r + 1), fill=C("debug_blanco"), width=2)
    d.line((r + 1, r + 1, r + 5, r + 3), fill=C("debug_blanco"), width=2)
    return outline_opaque(img, "tienda_noche")


# ------------------------------------------------------------------ objetos
def shop_item(product="sync"):
    img, d = canvas(64, 96)
    d.rectangle((4, 56, 59, 63), fill=C("gris_etiqueta"))              # balda
    d.rectangle((4, 64, 59, 95), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))
    d.rectangle((14, 22, 49, 55), fill=C("negro_medio"), outline=C("gris_etiqueta"))   # caja del producto
    if product == "sync":                                              # cruz de Sync (como ShopItem)
        d.rectangle((22, 28, 41, 47), outline=C("magenta_neon"), width=2)
        d.rectangle((30, 31, 33, 44), fill=C("magenta_neon"))
        d.rectangle((25, 36, 38, 39), fill=C("magenta_neon"))
    else:
        battery(d, 32, 39, "violeta_neon")
    d.line((32, 4, 32, 10), fill=C("gris_etiqueta"))
    price_tag(d, 14, 72, "3" if product == "sync" else "2")   # prices.shop_item de data/economy.json
    text_lines(d, 10, 90, [44], "gris_etiqueta")
    return img


def shortcut_door(state="closed"):
    img, d = canvas(64, 192)
    door_frame(d, 192, "tienda_noche" if state == "open" else "negro_medio")
    if state == "open":
        for y in range(16, 188, 8):
            d.line((14, y, 49, y), fill=C("negro_fondo"))
        return img
    d.rectangle((6, 20, 57, 41), fill=C("amarillo_rebajas"), outline=C("amarillo_sombra"))
    end = digits(d, 10, 26, "3", "negro_medio")
    rhombus(d, end + 4, 31, 4, "negro_medio")
    text_lines(d, 30, 26, [22, 16], "negro_medio")
    d.rectangle((44, 100, 47, 112), fill=C("gris_etiqueta"))           # tirador
    text_lines(d, 18, 150, [26, 18, 22], "gris_escaparate")
    if state == "debug":
        icon = trap_icon()
        img.alpha_composite(icon, (32 - icon.width // 2, 60))
    return img


def refund_desk():
    img, d = canvas(128, 96)
    d.rectangle((8, 8, 119, 33), fill=C("crema_cartel"), outline=C("crema_sombra"))
    text_lines(d, 18, 16, [92, 60], "negro_medio", gap=8, h=3)
    d.line((30, 34, 30, 47), fill=C("gris_etiqueta"))
    d.line((97, 34, 97, 47), fill=C("gris_etiqueta"))
    d.rectangle((0, 48, 127, 55), fill=C("gris_etiqueta"))             # encimera
    d.rectangle((4, 56, 123, 95), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))
    for x in (20, 60, 100):
        d.rectangle((x - 10, 66, x + 10, 86), outline=C("negro_medio"))
    rhombus(d, 64, 76, 5, "amarillo_rebajas")
    return img


def surprise_box(state="closed"):
    img, d = canvas(64, 64)
    if state == "debug":
        px = img.load()
        for y in range(4, 60):
            for x in range(4, 60):
                if (x + y) % 2 == 0:                                   # translucida: trama al 50 %
                    px[x, y] = C("crema_sombra")
        rhombus(d, 32, 32, 12, "amarillo_rebajas")
        rhombus(d, 32, 32, 5, "amarillo_sombra")
        return outline_opaque(img, "tienda_noche")
    if state == "open":
        d.rectangle((4, 24, 59, 59), fill=C("crema_sombra"), outline=C("negro_medio"))
        d.rectangle((8, 28, 55, 34), fill=C("negro_medio"))
        d.polygon([(4, 24), (0, 6), (20, 14)], fill=C("crema_sombra"), outline=C("negro_medio"))
        d.polygon([(59, 24), (63, 6), (43, 14)], fill=C("crema_sombra"), outline=C("negro_medio"))
        return img
    d.rectangle((4, 4, 59, 59), fill=C("crema_sombra"), outline=C("negro_medio"))
    d.rectangle((4, 4, 59, 13), fill=C("crema_cartel"), outline=C("negro_medio"))    # tapa
    d.rectangle((28, 4, 35, 59), fill=C("magenta_neon"))
    d.rectangle((4, 30, 59, 37), fill=C("magenta_neon"))
    d.ellipse((20, 0, 31, 8), outline=C("magenta_neon"), width=2)
    d.ellipse((32, 0, 43, 8), outline=C("magenta_neon"), width=2)
    digits(d, 12, 40, "?", "negro_medio")
    return img


def countdown_platform():
    img, d = canvas(128, 32)
    d.rectangle((0, 0, 127, 31), fill=C("amarillo_rebajas"), outline=C("amarillo_sombra"))
    for k in range(5):
        x = 6 + k * 24
        d.rectangle((x, 20, x + 19, 27), fill=C("magenta_neon" if k < 3 else "gris_etiqueta"))
    text_lines(d, 8, 6, [70, 40], "negro_medio", gap=6, h=3)
    return img


def terms_gate():
    img, d = canvas(256, 192)
    d.rectangle((0, 0, 63, 191), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))
    d.rectangle((12, 8, 51, 191), fill=C("crema_cartel"))
    for y in range(20, 180, 5):                                         # letra pequena
        d.line((15, y, 15 + 18 + (y * 7) % 14, y), fill=C("gris_etiqueta"))
    d.rectangle((44, 9, 51, 16), fill=C("violeta_neon"))                # «rechazar» diminuto (8 px)
    d.rectangle((68, 160, 255, 191), fill=C("amarillo_rebajas"), outline=C("amarillo_sombra"))   # ACEPTAR
    text_lines(d, 112, 170, [100], "negro_medio", h=8)
    return img


def shutter(wall=False):
    w, h = (64, 192) if wall else (192, 64)
    img, d = canvas(w, h)
    d.rectangle((0, 0, w - 1, h - 1), fill=C("gris_escaparate"), outline=C("negro_medio"))
    if wall:
        for y in range(8, h, 8):
            d.line((2, y, w - 3, y), fill=C("gris_etiqueta"))
        d.rectangle((8, 70, 55, 91), fill=C("crema_cartel"), outline=C("crema_sombra"))
        text_lines(d, 12, 76, [36, 26], "negro_medio")
        d.rectangle((26, 150, 37, 161), fill=C("amarillo_rebajas"), outline=C("negro_medio"))
    else:
        for x in range(8, w, 8):
            d.line((x, 2, x, h - 3), fill=C("gris_etiqueta"))
        d.rectangle((56, 18, 135, 39), fill=C("crema_cartel"), outline=C("crema_sombra"))
        text_lines(d, 62, 24, [66, 44], "negro_medio")
        d.rectangle((150, 24, 161, 35), fill=C("amarillo_rebajas"), outline=C("negro_medio"))
    return img


def price_rail():
    img, d = canvas(192, 192)
    slot_row = 1                                                       # fila libre del Filo (desde abajo)
    for k, x in enumerate(range(40, 160, 16)):
        d.line((x, 0, x, 191), fill=C("gris_etiqueta"))
        for row in range(3):
            if row == 2 - slot_row:
                continue
            y = 12 + row * 64 + (k % 2) * 10
            d.rectangle((x - 6, y, x + 6, y + 18), fill=C("crema_cartel"), outline=C("negro_medio"))
            d.rectangle((x - 3, y + 6, x + 3, y + 8), fill=C("magenta_neon"))
    return img


def clearance_shelf(down=False):
    if down:
        img, d = canvas(128, 64)
        d.rectangle((0, 24, 127, 63), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))
        for x in (6, 40, 74, 100):
            d.rectangle((x, 30, x + 20, 56), fill=C("crema_sombra"), outline=C("negro_medio"))
        d.rectangle((50, 12, 81, 23), fill=C("amarillo_rebajas"), outline=C("negro_medio"))
        return img
    img, d = canvas(64, 128)
    d.rectangle((0, 0, 63, 127), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))
    for y in (40, 84, 124):
        d.rectangle((2, y, 61, y + 3), fill=C("gris_etiqueta"))
    for y, xs in ((16, (6, 30)), (60, (10, 36)), (104, (6, 28))):
        for x in xs:
            d.rectangle((x, y, x + 20, y + 23), fill=C("crema_sombra"), outline=C("negro_medio"))
    d.rectangle((14, 2, 49, 13), fill=C("amarillo_rebajas"), outline=C("negro_medio"))
    text_lines(d, 19, 6, [25], "negro_medio", h=3)
    return img


def free_trial_box():
    img, d = canvas(96, 96)
    for k in range(8):                                                 # brillo blanco del regalo (rayos)
        x, y = ((48, 4), (88, 48), (48, 90), (6, 48), (18, 16), (78, 16), (18, 80), (78, 80))[k]
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=C("debug_blanco"))
    d.rectangle((20, 30, 75, 85), fill=C("magenta_sombra"), outline=C("negro_medio"))
    d.rectangle((16, 22, 79, 33), fill=C("magenta_sombra"), outline=C("negro_medio"))
    d.rectangle((44, 22, 51, 85), fill=C("amarillo_rebajas"))
    d.ellipse((32, 12, 47, 24), outline=C("amarillo_rebajas"), width=3)
    d.ellipse((48, 12, 63, 24), outline=C("amarillo_rebajas"), width=3)
    d.rectangle((24, 56, 40, 70), fill=C("crema_cartel"))
    text_lines(d, 26, 59, [12, 8], "negro_medio", gap=5)
    return outline_opaque(img, "tienda_noche")


def wishlist_platform():
    img, d = canvas(192, 64)
    d.rectangle((0, 32, 191, 63), fill=C("crema_cartel"), outline=C("magenta_neon"))
    for y in (42, 50):
        d.line((8, y, 183, y), fill=C("crema_sombra"))
    # Reloj «que cuenta pasos» sobre la tarjeta.
    d.rectangle((88, 4, 103, 31), fill=C("gris_escaparate"))
    d.ellipse((82, 8, 109, 28), fill=C("amarillo_rebajas"), outline=C("negro_medio"))
    d.ellipse((88, 12, 103, 24), fill=C("negro_medio"))
    d.line((95, 18, 99, 15), fill=C("amarillo_rebajas"))
    return img


def wish_strike():
    img, d = canvas(192, 64)
    d.rectangle((0, 16, 191, 47), fill=C("crema_cartel"), outline=C("crema_sombra"))
    text_lines(d, 10, 28, [170], "negro_medio", h=4)
    d.rectangle((4, 29, 187, 31), fill=C("magenta_neon"))
    return img


def calc_register():
    img, d = canvas(64, 192)
    door_frame(d, 192)
    d.rectangle((8, 18, 55, 59), fill=C("gris_escaparate"), outline=C("gris_etiqueta"))   # cuerpo
    d.rectangle((12, 22, 51, 51), fill=C("crema_sombra"))                                  # LCD «Atajo: 2 / Trampa: 0»
    end = digits(d, 16, 25, "2", "negro_medio")
    rhombus(d, end + 3, 30, 3, "negro_medio")
    text_lines(d, end + 9, 29, [8], "negro_medio")
    end = digits(d, 16, 39, "0", "negro_medio")
    text_lines(d, end + 2, 43, [14], "negro_medio")
    for k in range(3):
        d.rectangle((14 + k * 13, 62, 22 + k * 13, 68), fill=C("gris_etiqueta"))
    d.rectangle((44, 100, 47, 112), fill=C("gris_etiqueta"))
    return img


def sale_sign():
    img, d = canvas(128, 64)
    d.rectangle((0, 0, 127, 47), fill=C("amarillo_rebajas"), outline=C("amarillo_sombra"))
    digits(d, 12, 8, "-5", "magenta_neon", k=5)
    digits(d, 56, 8, "0", "magenta_neon", k=5)
    text_lines(d, 84, 12, [30, 22, 26], "negro_medio", gap=8, h=3)
    d.line((32, 48, 32, 63), fill=C("gris_etiqueta"))
    d.line((96, 48, 96, 63), fill=C("gris_etiqueta"))
    return img


# ------------------------------------------------------------------ enemigos
def offer_sign(wall=False):
    h = 48 if wall else 64
    img, d = canvas(64, h)
    top = 0 if wall else 4
    d.rectangle((4, top, 59, top + 40), fill=C("amarillo_rebajas"), outline=C("amarillo_sombra"))
    digits(d, 8, top + 5, "99", "negro_medio")
    d.line((6, top + 9, 26, top + 5), fill=C("magenta_neon"), width=2)    # precio tachado: magenta, nunca rojo
    digits(d, 30, top + 12, "9", "magenta_neon", k=5)
    text_lines(d, 8, top + 22, [16, 12], "negro_medio")
    if wall:
        d.line((14, top + 41, 14, 47), fill=C("gris_etiqueta"))
        d.line((49, top + 41, 49, 47), fill=C("gris_etiqueta"))
    else:
        d.rectangle((29, top + 41, 34, 63), fill=C("gris_etiqueta"))
        d.rectangle((18, 60, 45, 63), fill=C("gris_escaparate"))
    return img


def subscription_placeholder():
    img, d = canvas(48, 48)
    d.rounded_rectangle((6, 12, 41, 39), radius=4, fill=C("violeta_neon"), outline=C("magenta_neon"), width=2)
    d.rectangle((10, 17, 19, 22), fill=C("amarillo_rebajas"))          # chip de la tarjeta
    d.ellipse((24, 18, 28, 22), fill=C("tienda_noche"))
    d.ellipse((32, 18, 36, 22), fill=C("tienda_noche"))
    d.arc((14, 20, 38, 36), 20, 160, fill=C("tienda_noche"), width=2)   # sonrisa
    d.polygon([(6, 16), (0, 10), (4, 22)], fill=C("magenta_sombra"))   # alitas
    d.polygon([(41, 16), (47, 10), (43, 22)], fill=C("magenta_sombra"))
    return img


OBJECTS = {
    "shop_item_00.png": shop_item, "shop_item_energy_00.png": lambda: shop_item("energy"),
    "shortcut_door_00.png": shortcut_door, "shortcut_door_debug_00.png": lambda: shortcut_door("debug"),
    "shortcut_door_open_00.png": lambda: shortcut_door("open"), "refund_desk_00.png": refund_desk,
    "surprise_box_00.png": surprise_box, "surprise_box_debug_00.png": lambda: surprise_box("debug"),
    "surprise_box_open_00.png": lambda: surprise_box("open"), "countdown_platform_00.png": countdown_platform,
    "terms_gate_00.png": terms_gate, "shutter_00.png": shutter, "shutter_wall_00.png": lambda: shutter(True),
    "price_rail_00.png": price_rail, "clearance_shelf_00.png": clearance_shelf,
    "clearance_shelf_down_00.png": lambda: clearance_shelf(True), "free_trial_box_00.png": free_trial_box,
    "wishlist_platform_00.png": wishlist_platform, "wish_strike_00.png": wish_strike,
    "calc_register_00.png": calc_register, "sale_sign_00.png": sale_sign,
}
ENEMIES = {
    "offer_sign_00.png": offer_sign, "offer_sign_wall_00.png": lambda: offer_sign(True),
    "subscription_placeholder_00.png": subscription_placeholder,
}
## Lo que puede llevar debug_blanco (regla 3 de §6.1: el blanco, reservado al Debug): lo que revela el Debug y el
## brillo de la «Prueba gratis» (su seccion usa glow: debug_blanco), siempre con contorno tienda_noche.
WHITE_ALLOWED = ("shortcut_door_debug_00.png", "free_trial_box_00.png")


def binarize(img):
    """Alfa 0 o 255 (los bordes suavizados de PIL, al color opaco o fuera)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            a = px[x, y][3]
            if 0 < a < 255:
                px[x, y] = px[x, y][:3] + (255,) if a >= 128 else (0, 0, 0, 0)
    return img


def outputs():
    return ({name: binarize(build()) for name, build in OBJECTS.items()},
            {name: binarize(build()) for name, build in ENEMIES.items()})


def outputs_for(rows):
    """Los mismos dibujos con otra paleta (filas (nombre, hex, funcion) con el Debug); no escribe nada."""
    global COLORS
    saved = COLORS
    COLORS = palette_colors(rows)
    try:
        return outputs()
    finally:
        COLORS = saved


def off_palette(images, rows):
    """Nombres de PNG con algun color opaco fuera de la paleta (validador)."""
    allowed = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for _n, v, _r in rows}
    bad = []
    for name, img in images.items():
        colors = {c[:3] for _count, c in img.getcolors(1 << 16) or [] if c[3] == 255}
        if colors - allowed:
            bad.append(name)
    return bad


def rule_errors(images):
    """Reglas de §6.1 sobre el dibujo: sin rojo de dano ni ambar de los puntos en ningun objeto o enemigo; el
    blanco del Debug solo en WHITE_ALLOWED; cada imagen, con algo opaco."""
    banned = {C(n)[:3] for n in ("alerta", "alerta_sombra", "ambar", "ambar_sombra")}
    white = C("debug_blanco")[:3]
    errors = []
    for name, img in images.items():
        used = {c[:3] for _count, c in img.getcolors(1 << 16) or [] if c[3] == 255}
        if not used:
            errors.append("%s esta vacio" % name)
        if used & banned:
            errors.append("%s usa el rojo de dano o el ambar de los puntos (reservados)" % name)
        if white in used and name not in WHITE_ALLOWED:
            errors.append("%s usa el blanco del Debug (reservado: regla 3 de §6.1)" % name)
    return errors


def write_or_check(out_dir, images, check):
    errors = []
    for name, img in images.items():
        path = os.path.join(REPO, out_dir, name)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                errors.append("%s no esta al dia (python3 -I tools/gen_world5_objects.py)" % os.path.join(out_dir, name))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
    if check and os.path.isdir(os.path.join(REPO, out_dir)):
        for name in sorted(os.listdir(os.path.join(REPO, out_dir))):
            if name.endswith(".png") and name not in images:
                errors.append("%s: no lo produce tools/gen_world5_objects.py" % os.path.join(out_dir, name))
    return errors


def main(argv):
    check = "--check" in argv
    objects, enemies = outputs()
    errors = write_or_check(OUT_OBJECTS, objects, check) + write_or_check(OUT_ENEMIES, enemies, check)
    images = dict(objects, **enemies)
    for name in off_palette(images, pal.COLORS + [pal.DEBUG]):
        errors.append("%s usa colores fuera de la paleta del Mundo 5" % name)
    errors += rule_errors(images)
    for error in errors:
        print("gen_world5_objects: %s" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
