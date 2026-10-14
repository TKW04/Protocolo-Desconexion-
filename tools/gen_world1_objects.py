#!/usr/bin/env python3
"""Genera los objetos del Mundo 1 para el nivel 1-1 con los colores de assets/palettes/mundo1.gpl.

Hermano de tools/gen_tileset_mundo1.py (mismo estilo: rejilla logica de 32x32 "pixeles" de
2x2 px por tile de 64, luz arriba e izquierda). Solo colores de la paleta del mundo (el
debug_cian queda reservado al Debug) y alfa 0/255.

Salidas (hojas de cuadros de 64x64 en una fila, salvo la pared):
  assets/sprites/tiles/mundo1_bridge.png        puente: retraido (off), materializandose (half), extendido (on)
  assets/sprites/tiles/mundo1_receiver.png      receptor: apagado A, apagado B (parpadeo), activado
  assets/sprites/tiles/mundo1_glitch_wall.png   pared con glitch: 4 cuadros (columnas) x 16 mascaras de
                                                vecinos solidos (filas, mismos bits N=1 E=2 S=4 W=8 que
                                                solid.by_mask de data/tileset_mundo1.json)
  assets/sprites/backgrounds/mundo1_bg_cielo.png        fondo lejano 1280x720, opaco (cielo y relojes)
  assets/sprites/backgrounds/mundo1_bg_fondo_medio.png  fondo medio 1280x720 (relojes y avisos), transparente arriba
  assets/sprites/backgrounds/mundo1_bg_resplandor.png   resplandor de pantalla y edificios 1280x720
  assets/sprites/tiles/_mundo1_objects_preview_x2.png   vista ampliada x2 de las hojas sobre el fondo
  assets/sprites/backgrounds/_mundo1_bg_preview.png      las tres capas compuestas (dos anchos seguidos)

Los fondos se repiten en horizontal sin costura (se dibujan con envoltura en x).
El validador es tools/validate_world1_assets.py (lee la lista "assets" de data/world1_objects.json).

Uso: python3 tools/gen_world1_objects.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_tileset_mundo1 as ts  # noqa: E402  (reutiliza paleta, Tile y bloques solidos)

ROOT = ts.ROOT
P = ts.P
L = ts.L          # 32 pixeles logicos por tile
TILE = ts.TILE    # 64 px
UNIT = ts.UNIT    # 2 px por pixel logico
CLEAR = ts.CLEAR
N, E, S, W = ts.N, ts.E, ts.S, ts.W

TILES_DIR = os.path.join(ROOT, "assets", "sprites", "tiles")
BG_DIR = os.path.join(ROOT, "assets", "sprites", "backgrounds")
BRIDGE_PNG = os.path.join(TILES_DIR, "mundo1_bridge.png")
RECEIVER_PNG = os.path.join(TILES_DIR, "mundo1_receiver.png")
GLITCH_PNG = os.path.join(TILES_DIR, "mundo1_glitch_wall.png")
OBJ_PREVIEW = os.path.join(TILES_DIR, "_mundo1_objects_preview_x2.png")
BG_PREVIEW = os.path.join(BG_DIR, "_mundo1_bg_preview.png")
BG_FILES = {
    "cielo": os.path.join(BG_DIR, "mundo1_bg_cielo.png"),
    "fondo_medio": os.path.join(BG_DIR, "mundo1_bg_fondo_medio.png"),
    "resplandor": os.path.join(BG_DIR, "mundo1_bg_resplandor.png"),
}
# Fondo: 640x360 logicos -> 1280x720 px.
BG_W, BG_H = 640, 360

GLITCH_FRAMES = 4


def strip(tiles):
    """Pega tiles logicos de 32x32 (escalados x2) en una fila."""
    img = Image.new("RGBA", (TILE * len(tiles), TILE), CLEAR)
    for k, t in enumerate(tiles):
        img.paste(t.scaled(), (k * TILE, 0))
    return img


# -------------------------------------------------------------------- puente
# La tabla ocupa las filas logicas 0-5 (12 px, igual que one_way_collision_height_px) y la
# celosia de debajo llega a la fila 11. Patrones con periodo 16: se repite sin costura.
PLANK_BOTTOM = 5
TRUSS_BOTTOM = 11


def bridge_on():
    t = ts.Tile()
    t.rect(0, 0, L - 1, 1, "borde_luz")
    t.rect(0, 2, L - 1, 4, "tile_luz")
    t.rect(0, PLANK_BOTTOM, L - 1, PLANK_BOTTOM, "tile_sombra")
    # juntas entre tablones y luces de "conectado" (pocas luces: solo en lo interactivo)
    for x in (0, 16):
        t.rect(x, 2, x, 4, "tile_base")
    for x in (7, 23):
        t.px(x, 3, "banner_blanco")
        t.px(x + 1, 3, "borde_luz")
    # celosia en V bajo la tabla
    for x in range(L):
        k = x % 16
        y = 6 + (k if k < 8 else 15 - k) * (TRUSS_BOTTOM - 7) // 7
        t.px(x, y, "tile_luz")
        if y + 1 <= TRUSS_BOTTOM - 1:
            t.px(x, y + 1, "tile_sombra")
    t.rect(0, TRUSS_BOTTOM, L - 1, TRUSS_BOTTOM, "tile_luz")
    return t


def bridge_half():
    """Cuadro intermedio: la tabla se materializa en lineas alternas, sin celosia."""
    t = ts.Tile()
    t.rect(0, 0, L - 1, 0, "borde_luz")
    for y in (2, 4):
        t.rect(0, y, L - 1, y, "tile_luz")
    for x in range(0, L, 4):
        t.px(x, 1, "borde_luz")
        t.px(x + 2, 3, "tile_luz")
    for x in (7, 23):
        t.px(x, 3, "borde_luz")
    return t


def bridge_off():
    """Puente desactivado: solo el contorno discontinuo de la tabla (se ve donde ira)."""
    t = ts.Tile()
    for x in range(0, L, 4):
        t.rect(x, 0, x + 1, 0, "borde_luz")
        t.rect(x + 2, PLANK_BOTTOM, x + 3, PLANK_BOTTOM, "banner_gris")
    for y in (2, 3):
        for x in (0, 16):
            t.px(x, y, "banner_gris")
    for x in (7, 23):
        t.px(x, 3, "banner_gris")
    return t


# ------------------------------------------------------------------- receptor
SCREEN = (9, 7, 22, 16)  # x0, y0, x1, y1 de la pantalla del receptor


def receiver(state):
    """Antena-receptor sobre un poste: caja con pantalla e icono de senal.
    state: 'off_a', 'off_b' (parpadeo del punto) u 'on'."""
    t = ts.Tile()
    on = state == "on"
    # base y poste
    t.rect(10, 29, 21, 31, "tile_base")
    t.rect(10, 29, 21, 29, "tile_luz")
    t.rect(14, 20, 17, 28, "tile_luz")
    t.rect(16, 20, 17, 28, "tile_sombra")
    # caja
    x0, y0, x1, y1 = 6, 4, 25, 19
    t.rect(x0, y0, x1, y1, "tile_base")
    t.rect(x0, y0, x1, y0, "banner_blanco" if on else "borde_luz")
    t.rect(x0, y0 + 1, x0, y1, "tile_luz")
    t.rect(x1, y0 + 1, x1, y1, "tile_sombra")
    t.rect(x0 + 1, y1, x1, y1, "tile_sombra")
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        t.px(x, y, None)
    # antena
    t.rect(21, 0, 21, 3, "tile_luz")
    t.px(21, 0, "banner_blanco" if on else "tile_luz")
    # pantalla con icono de senal (arcos hacia arriba desde el punto)
    sx0, sy0, sx1, sy1 = SCREEN
    t.rect(sx0, sy0, sx1, sy1, "noche_profunda")
    cx, cy = (sx0 + sx1) / 2.0, sy1 - 1.5
    for y in range(sy0, sy1 + 1):
        for x in range(sx0, sx1 + 1):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            if dy > 0 or abs(dx) > -dy + 0.6:
                continue  # solo el cono de 90 grados hacia arriba
            ring = round(d)
            if ring in (4, 7):
                t.px(x, y, ("banner_blanco" if ring == 4 else "borde_luz") if on else "tile_luz")
    dot = "banner_blanco" if on or state == "off_b" else "banner_gris"
    t.rect(int(cx) , int(cy) , int(cx) + 1, int(cy) + 1, dot)
    return t


# ----------------------------------------------------------- pared con glitch
# Bandas de filas (y0, y1, desplazamiento en pixeles logicos) por cuadro. El cuadro 0 es
# la pared limpia; los demas desplazan unas pocas lineas (glitch leve).
GLITCH_BANDS = [
    [],
    [(9, 11, 4), (24, 25, -3)],
    [(14, 16, -5), (6, 6, 2)],
    [(20, 22, 3), (3, 5, -4)],
]
# Trazos de "linea de barrido" por cuadro (x0, x1, y, color) y pixeles muertos (x, y, color):
# un destello minimo en el borde de las bandas, en colores de la propia pared.
GLITCH_STREAKS = [
    [],
    [(2, 12, 10, "tile_luz"), (20, 25, 24, "tile_luz")],
    [(14, 27, 15, "tile_luz"), (4, 7, 6, "tile_luz")],
    [(6, 16, 21, "tile_luz"), (22, 26, 4, "tile_luz")],
]
GLITCH_SPECKS = [
    [],
    [(13, 10, "borde_luz"), (19, 24, "banner_gris")],
    [(28, 15, "borde_luz"), (8, 6, "banner_gris")],
    [(17, 21, "borde_luz"), (21, 4, "banner_gris")],
]


def glitch_tile(mask, frame):
    base = ts.solid_tile(mask).img
    img = base.copy()
    for y0, y1, dx in GLITCH_BANDS[frame]:
        for y in range(y0, y1 + 1):
            row = [base.getpixel((x, y)) for x in range(L)]
            for x in range(L):
                src = row[(x - dx) % L]
                # no rompe las esquinas redondeadas (transparentes) del bloque
                if base.getpixel((x, y))[3] == 0 or src[3] == 0:
                    continue
                img.putpixel((x, y), src)
    for x0, x1, y, color in GLITCH_STREAKS[frame]:
        for x in range(x0, x1 + 1):
            if img.getpixel((x, y))[3] != 0:
                img.putpixel((x, y), P[color])
    for x, y, color in GLITCH_SPECKS[frame]:
        if img.getpixel((x, y))[3] != 0:
            img.putpixel((x, y), P[color])
    t = ts.Tile()
    t.img = img
    t.d = ImageDraw.Draw(img)
    return t


def glitch_sheet():
    img = Image.new("RGBA", (TILE * GLITCH_FRAMES, TILE * 16), CLEAR)
    for mask in range(16):
        for f in range(GLITCH_FRAMES):
            img.paste(glitch_tile(mask, f).scaled(), (f * TILE, mask * TILE))
    return img


# ---------------------------------------------------------------------- fondo
class Canvas:
    """Lienzo logico con envoltura horizontal (se repite sin costura)."""

    def __init__(self, fill=None):
        self.img = Image.new("RGBA", (BG_W, BG_H), P[fill] if fill else CLEAR)
        self.px_ = self.img.load()

    def px(self, x, y, color):
        if 0 <= y < BG_H:
            self.px_[x % BG_W, y] = P[color] if color else CLEAR

    def rect(self, x0, y0, x1, y1, color):
        for y in range(max(0, y0), min(BG_H - 1, y1) + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, color)

    def ring(self, cx, cy, r, width, color):
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                d = math.hypot(x - cx, y - cy)
                if r - width < d <= r:
                    self.px(x, y, color)

    def disc(self, cx, cy, r, color):
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                if math.hypot(x - cx, y - cy) <= r:
                    self.px(x, y, color)

    def hand(self, cx, cy, length, angle_deg, width, color):
        a = math.radians(angle_deg)
        for k in range(length + 1):
            x = round(cx + math.sin(a) * k)
            y = round(cy - math.cos(a) * k)
            for w in range(width):
                for v in range(width):
                    self.px(x + w, y + v, color)

    def clock(self, cx, cy, r, ring_color, hand_color, hour, minute, fill=None):
        if fill:
            self.disc(cx, cy, r, fill)
        self.ring(cx, cy, r, 2, ring_color)
        self.hand(cx, cy, int(r * 0.55), hour, 2, hand_color)
        self.hand(cx, cy, int(r * 0.8), minute, 2, hand_color)

    def scaled(self):
        return self.img.resize((BG_W * UNIT, BG_H * UNIT), Image.NEAREST)


SKY_TOP = 48  # filas logicas de noche profunda (96 px)


def bg_cielo():
    """Capa lejana, opaca: noche profunda arriba, cielo y relojes grandes."""
    c = Canvas("cielo")
    c.rect(0, 0, BG_W - 1, SKY_TOP - 1, "noche_profunda")
    # transicion en tablero de 2 filas (sin colores intermedios)
    for x in range(BG_W):
        c.px(x, SKY_TOP, "noche_profunda" if x % 2 == 0 else "cielo")
        c.px(x, SKY_TOP + 1, "noche_profunda" if x % 4 == 1 else "cielo")
    # puntos de senal en la noche
    for k, (x, y) in enumerate(((40, 14), (131, 30), (210, 9), (305, 24), (377, 12), (462, 34), (560, 19), (618, 6))):
        c.px(x, y, "fondo_medio")
        if k % 3 == 0:
            c.px(x + 1, y, "fondo_medio")
    for cx, cy, r, h, m in ((90, 104, 36, 300, 90), (330, 84, 26, 60, 180), (545, 112, 40, 150, 0)):
        c.clock(cx, cy, r, "fondo_medio", "fondo_medio", h, m)
        c.px(cx, cy, "resplandor")
    return c


MID_TOP = 150  # banda de fondo_medio (300 px)


def bg_fondo_medio():
    """Capa media: banda de fondo_medio con relojes que asoman y avisos flotando."""
    c = Canvas()
    c.rect(0, MID_TOP, BG_W - 1, BG_H - 1, "fondo_medio")
    # relojes-silueta que asoman por encima de la banda
    for cx, r, h, m in ((60, 30, 90, 240), (250, 22, 330, 150), (470, 34, 210, 30)):
        c.clock(cx, MID_TOP, r, "fondo_medio", "cielo", h, m, fill="fondo_medio")
        c.ring(cx, MID_TOP, r, 1, "resplandor")
        c.rect(cx - r - 2, MID_TOP + 1, cx + r + 2, MID_TOP + r + 2, "fondo_medio")
    # avisos (pastillas de notificacion) apagados
    for x0, y0, w in ((140, 70, 84), (330, 112, 64), (560, 58, 70)):
        x1, y1 = x0 + w, y0 + 18
        c.rect(x0, y0, x1, y1, "resplandor")
        c.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, "fondo_medio")
        for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            c.px(x, y, None)
        c.rect(x0 + 4, y0 + 4, x0 + 13, y0 + 13, "resplandor")
        c.rect(x0 + 18, y0 + 5, x1 - 10, y0 + 6, "cielo")
        c.rect(x0 + 18, y0 + 10, x0 + 18 + (w - 28) // 2, y0 + 11, "cielo")
    return c


GLOW_TOP = 190  # resplandor (380 px)


def bg_resplandor():
    """Capa cercana: resplandor de pantalla con edificios-telefono en fondo_medio."""
    c = Canvas()
    c.rect(0, GLOW_TOP, BG_W - 1, BG_H - 1, "resplandor")
    # (x, ancho, altura sobre el fondo de la capa)
    buildings = [(4, 54, 120), (70, 48, 96), (130, 30, 140), (172, 66, 110), (250, 40, 150),
                 (300, 58, 84), (372, 34, 128), (420, 70, 104), (502, 44, 142), (560, 74, 92)]
    for x0, w, h in buildings:
        top = BG_H - h
        c.rect(x0, top, x0 + w - 1, BG_H - 1, "fondo_medio")
        c.rect(x0, top, x0 + w - 1, top, "resplandor" if (x0 // 2) % 2 else "fondo_medio")
        # ventanas-pantalla (cuadrados de 6 con hueco de 6), alguna encendida
        for k, wy in enumerate(range(top + 8, BG_H - 12, 22)):
            for j, wx in enumerate(range(x0 + 6, x0 + w - 10, 18)):
                if (k * 3 + j + x0) % 4 == 0:
                    c.rect(wx, wy, wx + 7, wy + 7, "resplandor")
                elif (k + j * 2 + x0) % 7 == 0:
                    c.rect(wx, wy, wx + 7, wy + 1, "cielo")
        # antena en los edificios altos
        if h >= 128:
            c.rect(x0 + w // 2, top - 10, x0 + w // 2, top - 1, "fondo_medio")
            c.px(x0 + w // 2, top - 11, "alerta" if h >= 140 else "fondo_medio")
    return c


# -------------------------------------------------------------------- vistas
def checker(size):
    bg = Image.new("RGBA", size, (60, 64, 72, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, size[1], 16):
        for x in range(0, size[0], 16):
            if (x // 16 + y // 16) % 2:
                d.rectangle([x, y, x + 15, y + 15], fill=(80, 84, 94, 255))
    return bg


def objects_preview(bridge, recv, glitch):
    """Hojas sobre cuadros grises y sobre el resplandor del fondo, ampliadas x2."""
    rows = [bridge, recv, glitch.crop((0, 15 * TILE, GLITCH_FRAMES * TILE, 16 * TILE)),
            glitch.crop((0, 6 * TILE, GLITCH_FRAMES * TILE, 7 * TILE))]
    width = max(r.width for r in rows)
    sheet = Image.new("RGBA", (width * 2, TILE * len(rows)), CLEAR)
    for k, r in enumerate(rows):
        sheet.paste(r, (0, k * TILE))
        sheet.paste(r, (width, k * TILE))
    left = checker((width, sheet.height))
    right = Image.new("RGBA", (width, sheet.height), P["resplandor"])
    base = Image.new("RGBA", sheet.size)
    base.paste(left, (0, 0))
    base.paste(right, (width, 0))
    base.alpha_composite(sheet)
    return base.resize((base.width * 2, base.height * 2), Image.NEAREST)


def bg_preview(layers):
    img = Image.new("RGBA", (BG_W * UNIT * 2, BG_H * UNIT), CLEAR)
    for layer in layers:
        s = layer.scaled()
        img.alpha_composite(s, (0, 0))
        img.alpha_composite(s, (BG_W * UNIT, 0))
    return img


def main():
    os.makedirs(TILES_DIR, exist_ok=True)
    os.makedirs(BG_DIR, exist_ok=True)
    bridge = strip([bridge_off(), bridge_half(), bridge_on()])
    recv = strip([receiver("off_a"), receiver("off_b"), receiver("on")])
    glitch = glitch_sheet()
    bridge.save(BRIDGE_PNG)
    recv.save(RECEIVER_PNG)
    glitch.save(GLITCH_PNG)
    layers = [bg_cielo(), bg_fondo_medio(), bg_resplandor()]
    for name, layer in zip(("cielo", "fondo_medio", "resplandor"), layers):
        layer.scaled().save(BG_FILES[name])
    objects_preview(bridge, recv, glitch).save(OBJ_PREVIEW)
    bg_preview(layers).convert("RGB").save(BG_PREVIEW)
    for p in (BRIDGE_PNG, RECEIVER_PNG, GLITCH_PNG, *BG_FILES.values(), OBJ_PREVIEW, BG_PREVIEW):
        print(p)


if __name__ == "__main__":
    main()
