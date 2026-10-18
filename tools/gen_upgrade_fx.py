#!/usr/bin/env python3
"""Genera los efectos de las mejoras de Calc de la tanda M2 (docs/propuesta-mejoras.md §2, §4 y §9).

Paleta del Mundo 1 (assets/palettes/mundo1.gpl) SIN rojos (alerta, alerta_sombra, carmin y
carmin_brillo quedan fuera: el rojo es dano), fondo transparente, alfa 0 o 255, salida
determinista. Pixeles de arte: el juego los dibuja x2 (scale de data/upgrade_fx.json), como los
tiles (32 px de arte = 64 px).

Salida: assets/sprites/effects/upgrade_fx.png, cuadros de 24x24, 6 columnas x 3 filas:
  fila 0 energy_return  Pulso de retorno (Pulso 5): «+4» en debug_cian con contorno noche_profunda y
                        una bateria pequena (carcasa banner_blanco, carga debug_cian) a la izquierda; nace de una chispa, sube y se deshace
                        con un tramado (6 cuadros).
  fila 1 pierce_spark   Laser que perfora (Laser 5): destello donde el haz atraviesa a un enemigo:
                        nucleo banner_blanco, estrella y anillo debug_cian que se abren y una raya
                        horizontal (el haz que sigue) en los cuadros 1-3 (6 cuadros).
  fila 2 lost_trail     Perseguidor que pierde el rastro con el Ocultarte (Pulso 4): «?» banner_blanco
                        con contorno noche_profunda sobre un bocadillo banner_gris; aparece, bota y se
                        deshace (6 cuadros).
Ademas escribe assets/sprites/effects/_upgrade_fx_preview_x8.png (vista, no la usa el juego).

Lo usa UpgradeFx (scripts/effects/upgrade_fx.gd, datos en data/upgrade_fx.json).
Uso (desde la raiz del repo): python3 -I tools/gen_upgrade_fx.py [--dry-run] [--preview <png>]
Validador: tools/validate_upgrade_fx.py.
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(REPO, "assets", "palettes", "mundo1.gpl")
OUT_PATH = "assets/sprites/effects/upgrade_fx.png"
PREVIEW_PATH = "assets/sprites/effects/_upgrade_fx_preview_x8.png"
FRAME = 24
COLUMNS = 6
ROWS = ["energy_return", "pierce_spark", "lost_trail"]
CLEAR = (0, 0, 0, 0)
# Colores de la paleta que NO se usan aqui (rojo = dano y puntos debiles).
FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo")


def load_palette(path):
    pal = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            parts = s.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                pal[parts[3]] = tuple(int(p) for p in parts[:3]) + (255,)
    return pal


P = load_palette(GPL)
CY = P["debug_cian"]
WH = P["banner_blanco"]
GR = P["banner_gris"]
NI = P["noche_profunda"]
BL = P["borde_luz"]

# Glifos de 5 px de ancho ('#' trazo).
GLYPHS = {
    "+": [".....",
          "..#..",
          "..#..",
          "#####",
          "..#..",
          "..#..",
          "....."],
    "4": ["...#.",
          "..##.",
          ".#.#.",
          "#..#.",
          "#####",
          "...#.",
          "...#."],
    "?": [".###.",
          "#...#",
          "....#",
          "...#.",
          "..#..",
          ".....",
          "..#.."],
}
# Bateria pequena (la energia del HUD): '#' carcasa banner_blanco, 'o' carga debug_cian.
BATTERY = [".##.",
           "####",
           "#oo#",
           "#oo#",
           "#oo#",
           "#oo#",
           "####"]


class Frame:
    def __init__(self):
        self.img = Image.new("RGBA", (FRAME, FRAME), CLEAR)
        self.px = self.img.load()

    def p(self, x, y, c):
        if 0 <= x < FRAME and 0 <= y < FRAME:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < FRAME and 0 <= y < FRAME else CLEAR

    def stamp(self, rows, x0, y0, color, fill=None):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    self.p(x0 + x, y0 + y, color)
                elif ch == "o" and fill is not None:
                    self.p(x0 + x, y0 + y, fill)

    def outline(self, color, only_over=None):
        """Contorno de 1 px (4 vecinos) alrededor de lo opaco."""
        solid = [(x, y) for y in range(FRAME) for x in range(FRAME) if self.px[x, y][3] == 255]
        solid_set = set(solid)
        for x, y in solid:
            if only_over is not None and self.px[x, y] not in only_over:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in solid_set and 0 <= q[0] < FRAME and 0 <= q[1] < FRAME:
                    self.p(q[0], q[1], color)

    def dither(self, keep_parity):
        """Tramado: quita los pixeles de una paridad (fundido sin semitransparencia)."""
        for y in range(FRAME):
            for x in range(FRAME):
                if (x + y) % 2 != keep_parity and self.px[x, y][3]:
                    self.px[x, y] = CLEAR

    def thin(self, step):
        """Deja solo uno de cada `step` pixeles opacos (deshacerse)."""
        n = 0
        for y in range(FRAME):
            for x in range(FRAME):
                if self.px[x, y][3]:
                    if n % step:
                        self.px[x, y] = CLEAR
                    n += 1


def spark(f, cx, cy, r, core=WH, ray=CY):
    """Chispa en cruz con nucleo."""
    f.p(cx, cy, core)
    for i in range(1, r + 1):
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            f.p(cx + dx, cy + dy, core if i == 1 else ray)


def plus_four(f, y):
    """Bateria + «+4» centrado en x, con su contorno."""
    x0 = (FRAME - (4 + 1 + 5 + 5)) // 2  # bateria, hueco, «+», «4» (el «+» trae su hueco)
    f.stamp(BATTERY, x0, y, WH, CY)
    f.stamp(GLYPHS["+"], x0 + 5, y, CY)
    f.stamp(GLYPHS["4"], x0 + 10, y, CY)
    f.outline(NI)


def energy_return(i):
    f = Frame()
    if i == 0:
        spark(f, 12, 15, 2)
        f.p(10, 13, CY)
        f.p(14, 17, CY)
        return f
    y = [0, 10, 8, 6, 4, 2][i]
    plus_four(f, y)
    if i == 2:  # estela de chispas bajo el texto
        for x, yy in ((9, 19), (14, 20), (12, 22)):
            f.p(x, yy, CY)
    if i == 3:
        for x, yy in ((10, 17), (13, 19)):
            f.p(x, yy, BL)
    if i == 4:
        f.dither(0)
    if i == 5:
        f.thin(3)
    return f


def pierce_spark(i):
    f = Frame()
    c = 12
    if i in (1, 2, 3):  # el haz que sigue: raya horizontal
        for x in range(FRAME):
            if i == 3 and x % 2:
                continue
            f.p(x, c, WH if i < 3 else BL)
    if i == 0:
        spark(f, c, c, 2)
    elif i == 1:
        spark(f, c, c, 4)
        for d in (1, 2):
            for sx, sy in ((d, d), (-d, d), (d, -d), (-d, -d)):
                f.p(c + sx, c + sy, CY)
        f.p(c, c, WH)
    elif i in (2, 3, 4):
        r = {2: 5, 3: 7, 4: 9}[i]
        # anillo discontinuo
        for k in range(32):
            if i == 4 and k % 2:
                continue
            import math
            a = k / 32.0 * 2 * math.pi
            f.p(round(c + r * math.cos(a)), round(c + r * math.sin(a)), CY)
        if i == 2:
            spark(f, c, c, 3)
        elif i == 3:
            spark(f, c, c, 1, core=WH, ray=WH)
    else:  # 5: restos
        for x, y in ((c - 9, c - 2), (c + 8, c + 3), (c + 2, c - 9), (c - 3, c + 9), (c, c)):
            f.p(x, y, CY if (x + y) % 2 else BL)
    return f


def lost_trail(i):
    f = Frame()
    if i == 0:
        f.p(12, 16, WH)
        f.p(11, 16, GR)
        f.p(13, 16, GR)
        f.p(12, 15, GR)
        f.p(12, 17, GR)
        return f
    dy = {1: 3, 2: 1, 3: 0, 4: 2, 5: 1}[i]
    # bocadillo redondeado banner_gris con cola abajo
    x0, y0, x1, y1 = 6, 2 + dy, 17, 14 + dy
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            corner = (x in (x0, x1)) and (y in (y0, y1))
            if not corner:
                f.p(x, y, GR)
    for x in range(x0 + 1, x1):
        for y in range(y0 + 1, y1):
            f.p(x, y, NI)
    f.p(9, y1 + 1, GR)
    f.p(8, y1 + 2, GR)
    f.stamp(GLYPHS["?"], 10, y0 + 3, WH)
    if i == 5:
        f.dither(1)
    return f


def sheet():
    img = Image.new("RGBA", (FRAME * COLUMNS, FRAME * len(ROWS)), CLEAR)
    makers = {"energy_return": energy_return, "pierce_spark": pierce_spark, "lost_trail": lost_trail}
    for row, name in enumerate(ROWS):
        for col in range(COLUMNS):
            img.paste(makers[name](col).img, (col * FRAME, row * FRAME))
    return img


def outputs():
    return {OUT_PATH: sheet()}


def preview(scale=8):
    img = sheet()
    bg = Image.new("RGBA", (img.width + 8, img.height + 8), P["cielo"])
    bg.alpha_composite(img, (4, 4))
    return bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST)


def main(argv):
    dry = "--dry-run" in argv
    if "--preview" in argv:
        path = argv[argv.index("--preview") + 1]
        preview().save(path)
        print("vista previa:", path)
    if dry:
        return 0
    for rel, img in outputs().items():
        path = os.path.join(REPO, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)
        print("escrito", rel)
    preview().save(os.path.join(REPO, PREVIEW_PATH))
    print("vista", PREVIEW_PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
