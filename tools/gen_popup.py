#!/usr/bin/env python3
"""Genera el pop-up bloqueante, su boton de cerrar y la puerta de salida del Mundo 1 (1-1).

Mismo estilo que tools/gen_world1_objects.py: pixeles logicos de 2x2 px, solo colores de
assets/palettes/mundo1.gpl (sin debug_cian) y alfa 0/255. El texto del pop-up y la etiqueta
de la puerta NO van en el PNG: los dibuja Godot con la fuente de textos (text_font).

Salidas:
  assets/sprites/tiles/mundo1_popup.png        ventana de 192x256 (3x4 tiles), 5 cuadros en fila:
                                               0 abierta; 1-4 cierre por pasos (desplazamiento de
                                               lineas, aplastado, raya, restos)
  assets/sprites/tiles/mundo1_popup_close.png  boton de cerrar diminuto de 16x16, 3 cuadros:
                                               0 normal (alerta con X blanca), 1 brillo, 2 acertado
  assets/sprites/tiles/mundo1_exit_door.png    puerta de 64x128 (1x2 tiles), 5 cuadros: 0 cerrada,
                                               1 cerrada con brillo, 2-3 abriendose, 4 abierta
                                               (hoja con una doble marca de "leido")
  assets/sprites/tiles/_mundo1_popup_door_preview_x2.png  vista ampliada x2 sobre el resplandor

Rojo (alerta) solo en el boton de cerrar: es lo interactivo/alerta del pop-up (regla del
Mundo 1). Valida tools/validate_world1_assets.py (lista "assets" de data/world1_objects.json).

Uso: python3 tools/gen_popup.py
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_tileset_mundo1 as ts  # noqa: E402

P = ts.P
UNIT = ts.UNIT  # 2 px por pixel logico
CLEAR = ts.CLEAR
TILES_DIR = os.path.join(ts.ROOT, "assets", "sprites", "tiles")
POPUP_PNG = os.path.join(TILES_DIR, "mundo1_popup.png")
CLOSE_PNG = os.path.join(TILES_DIR, "mundo1_popup_close.png")
DOOR_PNG = os.path.join(TILES_DIR, "mundo1_exit_door.png")
PREVIEW_PNG = os.path.join(TILES_DIR, "_mundo1_popup_door_preview_x2.png")

# Tamanos logicos.
PW, PH = 96, 128      # pop-up (192x256 px)
TITLE_H = 10          # barra de titulo
BW = 8                # boton (16x16 px)
DW, DH = 32, 64       # puerta (64x128 px)
POPUP_FRAMES = 5
DOOR_FRAMES = 5


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), CLEAR)
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x0, y0, x1, y1, color):
        if x1 < x0 or y1 < y0:
            return
        self.d.rectangle([x0, y0, x1, y1], fill=P[color] if color else CLEAR)

    def px(self, x, y, color):
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.img.putpixel((x, y), P[color] if color else CLEAR)

    def scaled(self):
        return self.img.resize((self.img.width * UNIT, self.img.height * UNIT), Image.NEAREST)


# ------------------------------------------------------------------ pop-up
def popup_open():
    c = Canvas(PW, PH)
    # Cuerpo blanco con contorno gris y sombra interior abajo/derecha.
    c.rect(0, 0, PW - 1, PH - 1, "banner_gris")
    c.rect(1, 1, PW - 2, PH - 2, "banner_blanco")
    c.rect(2, PH - 3, PW - 3, PH - 3, "banner_gris")
    c.rect(PW - 3, TITLE_H + 1, PW - 3, PH - 3, "banner_gris")
    # Barra de titulo (fondo_medio) con un icono de campana y "texto" de rayas.
    c.rect(1, 1, PW - 2, TITLE_H, "fondo_medio")
    # Esquinas redondeadas (transparentes).
    for (x, y) in [(0, 0), (PW - 1, 0), (0, PH - 1), (PW - 1, PH - 1)]:
        c.px(x, y, None)
    for (x, y) in [(1, 1), (PW - 2, 1)]:
        c.px(x, y, "banner_gris")
    c.rect(1, TITLE_H, PW - 2, TITLE_H, "resplandor")
    bell = ["..##..", ".####.", ".####.", "######", "..##.."]
    for y, row in enumerate(bell):
        for x, ch in enumerate(row):
            if ch == "#":
                c.px(4 + x, 3 + y, "banner_blanco")
    c.rect(13, 4, 40, 5, "borde_luz")
    c.rect(13, 7, 30, 7, "resplandor")
    # Tres "controles" de ventana apagados (grises: no son el boton de cerrar).
    for k in range(3):
        c.rect(PW - 20 + k * 6, 4, PW - 17 + k * 6, 7, "resplandor")
    # Boton grande falso abajo a la derecha (gris, sin texto): no cierra nada.
    c.rect(PW - 38, PH - 18, PW - 8, PH - 9, "banner_gris")
    c.rect(PW - 37, PH - 17, PW - 9, PH - 10, "borde_luz")
    c.rect(PW - 30, PH - 14, PW - 16, PH - 13, "banner_blanco")
    return c.img


def glitch_rows(img, shifts):
    """Copia con algunas bandas de filas desplazadas en horizontal: {y0: (y1, dx)}."""
    out = img.copy()
    for y0, (y1, dx) in shifts.items():
        band = img.crop((0, y0, img.width, y1 + 1))
        out.paste(Image.new("RGBA", band.size, CLEAR), (0, y0))
        out.paste(band, (dx, y0))
    return out


def popup_frames():
    base = popup_open()
    frames = [base]
    # 1: lineas desplazadas (glitch), mismo tamano.
    f1 = glitch_rows(base, {14: (21, 3), 40: (47, -4), 70: (73, 5), 100: (109, -3)})
    d1 = ImageDraw.Draw(f1)
    for (y, x0, x1, color) in [(17, 8, 50, "borde_luz"), (43, 30, 88, "resplandor"), (71, 4, 40, "borde_luz"),
                               (72, 60, 80, "banner_gris"), (104, 12, 70, "resplandor")]:
        d1.line([(x0, y), (x1, y)], fill=P[color])
    frames.append(f1)
    # 2: aplastado a la mitad de alto, centrado, con una banda desplazada.
    half = base.resize((PW - 8, PH // 2), Image.NEAREST)
    f2 = Image.new("RGBA", (PW, PH), CLEAR)
    f2.paste(half, (4, PH // 4))
    f2 = glitch_rows(f2, {44: (51, 4), 70: (75, -3)})
    d2 = ImageDraw.Draw(f2)
    for (y, x0, x1, color) in [(47, 10, 60, "borde_luz"), (72, 30, 86, "resplandor"), (58, 6, 30, "banner_gris")]:
        d2.line([(x0, y), (x1, y)], fill=P[color])
    frames.append(f2)
    # 3: una raya horizontal (la ventana casi cerrada).
    c3 = Canvas(PW, PH)
    mid = PH // 2
    c3.rect(10, mid - 3, PW - 11, mid + 2, "banner_gris")
    c3.rect(11, mid - 2, PW - 12, mid + 1, "banner_blanco")
    c3.rect(20, mid - 2, 40, mid - 2, "borde_luz")
    c3.rect(4, mid - 1, 8, mid, "banner_blanco")
    c3.rect(PW - 9, mid, PW - 5, mid, "banner_gris")
    frames.append(c3.img)
    # 4: restos de pixeles que se apagan.
    c4 = Canvas(PW, PH)
    for (x, y, color) in [(30, mid - 1, "banner_blanco"), (46, mid, "borde_luz"), (58, mid - 2, "banner_gris"),
                          (40, mid + 2, "banner_blanco"), (66, mid + 1, "borde_luz"), (24, mid + 1, "banner_gris")]:
        c4.rect(x, y, x + 1, y, color)
    c4.rect(46, mid - 1, 49, mid - 1, "banner_blanco")
    frames.append(c4.img)
    sheet = Image.new("RGBA", (PW * UNIT * POPUP_FRAMES, PH * UNIT), CLEAR)
    for k, f in enumerate(frames):
        sheet.paste(f.resize((PW * UNIT, PH * UNIT), Image.NEAREST), (k * PW * UNIT, 0))
    return sheet


def close_button(state):
    c = Canvas(BW, BW)
    edge = "alerta_sombra"
    fill = "alerta"
    if state == "glow":
        edge = "banner_blanco"
    c.rect(0, 0, BW - 1, BW - 1, edge)
    c.rect(1, 1, BW - 2, BW - 2, fill)
    if state == "hit":
        c.rect(1, 1, BW - 2, BW - 2, "banner_blanco")
        mark = "alerta"
    else:
        mark = "banner_blanco"
    for i in range(4):  # X de 4 px
        c.px(2 + i, 2 + i, mark)
        c.px(5 - i, 2 + i, mark)
    return c.scaled()


def close_sheet():
    sheet = Image.new("RGBA", (BW * UNIT * 3, BW * UNIT), CLEAR)
    for k, state in enumerate(("normal", "glow", "hit")):
        sheet.paste(close_button(state), (k * BW * UNIT, 0))
    return sheet


# ------------------------------------------------------------------ puerta
TICK = [(0, 2), (1, 3), (2, 4), (3, 3), (4, 2), (5, 1), (6, 0)]  # una marca de 7x5


def check_points():
    """Doble marca de "leido": dos marcas de 7x5 con 2 px de grosor, separadas 5 px."""
    pts = set()
    for ox in (0, 5):
        for (x, y) in TICK:
            pts.add((ox + x, y))
            pts.add((ox + x, y + 1))
    return pts


def door(frame):
    c = Canvas(DW, DH)
    glow = frame == 1
    # Marco (jamba) del color del tileset con canto de luz.
    c.rect(0, 0, DW - 1, DH - 1, "tile_base")
    c.rect(0, 0, DW - 1, 1, "borde_luz")
    c.rect(0, 0, 1, DH - 1, "tile_luz")
    c.rect(DW - 2, 0, DW - 1, DH - 1, "tile_sombra")
    inner = (3, 4, DW - 4, DH - 1)
    x0, y0, x1, y1 = inner
    # Hueco: luz del otro lado (se ve al abrir).
    c.rect(x0, y0, x1, y1, "resplandor")
    c.rect(x0, y0, x1, y0 + 1, "borde_luz")
    widths = {0: x1 - x0 + 1, 1: x1 - x0 + 1, 2: 16, 3: 7, 4: 0}
    w = widths[frame]
    if w > 0:
        # Hoja de la puerta: se pliega hacia la izquierda al abrirse.
        c.rect(x0, y0, x0 + w - 1, y1, "fondo_medio")
        c.rect(x0, y0, x0 + w - 1, y0, "tile_luz")
        c.rect(x0 + w - 1, y0, x0 + w - 1, y1, "cielo")
        if frame <= 1:
            # Doble marca de leido (centrada en la hoja) y tirador.
            mark = "borde_luz" if glow else "banner_gris"
            ox, oy = x0 + (w - 12) // 2, y0 + 16
            for (xx, yy) in check_points():
                c.px(ox + xx, oy + yy, mark)
            c.rect(x1 - 4, y0 + 32, x1 - 3, y0 + 35, "banner_blanco" if glow else "banner_gris")
            # Lineas de "mensaje" en la hoja.
            c.rect(x0 + 4, y0 + 42, x1 - 5, y0 + 42, "cielo")
            c.rect(x0 + 4, y0 + 46, x1 - 9, y0 + 46, "cielo")
    if glow:
        # Brillo de lo interactivo: canto de luz alrededor del hueco.
        c.rect(x0 - 1, y0 - 1, x1 + 1, y0 - 1, "banner_blanco")
        c.rect(x0 - 1, y0 - 1, x0 - 1, y1, "borde_luz")
        c.rect(x1 + 1, y0 - 1, x1 + 1, y1, "borde_luz")
    return c.scaled()


def door_sheet():
    sheet = Image.new("RGBA", (DW * UNIT * DOOR_FRAMES, DH * UNIT), CLEAR)
    for k in range(DOOR_FRAMES):
        sheet.paste(door(k), (k * DW * UNIT, 0))
    return sheet


def preview(popup, close, door_img):
    w = max(popup.width, door_img.width, close.width) + 16
    h = popup.height + door_img.height + close.height + 32
    base = Image.new("RGBA", (w, h), P["resplandor"])
    base.alpha_composite(popup, (8, 8))
    base.alpha_composite(close, (8, popup.height + 16))
    base.alpha_composite(door_img, (8, popup.height + close.height + 24))
    return base.resize((w * 2, h * 2), Image.NEAREST)


def main():
    os.makedirs(TILES_DIR, exist_ok=True)
    popup, close, door_img = popup_frames(), close_sheet(), door_sheet()
    popup.save(POPUP_PNG)
    close.save(CLOSE_PNG)
    door_img.save(DOOR_PNG)
    preview(popup, close, door_img).convert("RGB").save(PREVIEW_PNG)
    for p in (POPUP_PNG, CLOSE_PNG, DOOR_PNG, PREVIEW_PNG):
        print(p)


if __name__ == "__main__":
    main()
