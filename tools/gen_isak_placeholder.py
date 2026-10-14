#!/usr/bin/env python3
"""Genera los sprites PROVISIONALES (_placeholder) de Isak y su paleta.

Dibuja con indices de paleta en un canvas de 64x64 (unos 48 px visibles,
pies abajo y centrados). Isak mira a la derecha.

Uso:
    python3 tools/gen_isak_placeholder.py [--preview DIR]
    (no uses -I: Pillow esta en el site-packages de usuario)

Salidas:
    assets/palettes/isak.gpl
    assets/palettes/isak_palette_preview.png
    assets/sprites/isak/isak_<anim>_<NN>_placeholder.png
    assets/sprites/isak/isak_<anim>_sheet_placeholder.png
    <DIR>/isak_contact_x8.png (vista ampliada x8, nearest), si se pasa --preview

Los hex de la paleta son una PROPUESTA pendiente de aprobacion.
Pelo y piel no estan descritos en docs/: son valores provisionales neutros.
"""

import argparse
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL_DIR = os.path.join(ROOT, "assets", "palettes")
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "isak")
SIZE = 64
GROUND_Y = 62  # ultima fila de la suela (la fila 63 es el contorno)

# --- Paleta (PROPUESTA) ------------------------------------------------------
# indice 0 = transparente (no se guarda en el .gpl)
PALETTE = [
    ("outline", (0x16, 0x14, 0x1C)),        # contorno y montura de lentes
    ("tee_black", (0x26, 0x25, 0x2D)),      # camiseta negra
    ("logo_cream", (0xEF, 0xE4, 0xC4)),     # logo crema
    ("jacket_shadow", (0x48, 0x4C, 0x36)),  # chaqueta oliva desaturado, sombra
    ("jacket", (0x68, 0x6D, 0x4E)),         # chaqueta oliva desaturado, base
    ("jacket_light", (0x88, 0x8C, 0x6A)),   # chaqueta oliva desaturado, luz
    ("skin_shadow", (0xB0, 0x7A, 0x5A)),    # piel sombra (provisional)
    ("skin", (0xDC, 0xA4, 0x80)),           # piel (provisional)
    ("hair", (0x33, 0x25, 0x1E)),           # pelo (provisional)
    ("hair_light", (0x55, 0x3E, 0x30)),     # pelo luz (provisional)
    ("jeans_shadow", (0x2A, 0x3D, 0x5E)),   # jeans sombra
    ("jeans", (0x3E, 0x58, 0x86)),          # jeans base
    ("shoe", (0x3A, 0x38, 0x40)),           # zapatilla
    ("sole", (0xD6, 0xD4, 0xCC)),           # suela
    ("pack_shadow", (0x2C, 0x2E, 0x36)),    # mochila tecnica sombra
    ("pack", (0x45, 0x48, 0x52)),           # mochila tecnica base
    ("led_off", (0x1E, 0x4A, 0x52)),        # LED de Debug apagado
    ("world_cyan", (0x4F, 0xE3, 0xFF)),     # Mundo 1: contorno, reflejo, LED, rastro
    ("world_cyan_hi", (0xC8, 0xFA, 0xFF)),  # Mundo 1: brillo del reflejo/pulso
]
IDX = {name: i + 1 for i, (name, _) in enumerate(PALETTE)}


def write_gpl(path):
    with open(path, "w", encoding="utf-8") as f:
        f.write("GIMP Palette\n")
        f.write("Name: Isak (PROPUESTA, pendiente de aprobacion)\n")
        f.write("Columns: 4\n")
        f.write("# Paleta de Isak. Hex PROPUESTOS, no aprobados.\n")
        f.write("# Pelo y piel no estan definidos en docs/: valores provisionales.\n")
        f.write("# world_cyan* = color del Mundo 1 (contorno, reflejo, LED); cambia por mundo.\n")
        f.write("# El transparente (alfa 0) se admite aparte.\n")
        for name, (r, g, b) in PALETTE:
            f.write(f"{r:3d} {g:3d} {b:3d}\t{name}\n")


def write_palette_preview(path):
    from PIL import ImageFont
    font = ImageFont.load_default()
    sw, rows = 40, len(PALETTE)
    img = Image.new("RGB", (360, rows * (sw + 4) + 30), (40, 40, 48))
    d = ImageDraw.Draw(img)
    d.text((8, 8), "Paleta Isak - PROPUESTA (hex no aprobados)", fill=(230, 230, 230), font=font)
    for i, (name, rgb) in enumerate(PALETTE):
        y = 26 + i * (sw + 4)
        d.rectangle([8, y, 8 + sw * 2, y + sw], fill=rgb, outline=(0, 0, 0))
        d.text((8 + sw * 2 + 12, y + 8), f"{i + 1:2d} {name}", fill=(235, 235, 235), font=font)
        d.text((8 + sw * 2 + 12, y + 22), "#%02X%02X%02X" % rgb, fill=(180, 180, 180), font=font)
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    img.save(path)


# --- Primitivas ---------------------------------------------------------------
class Canvas:
    def __init__(self):
        self.px = [[0] * SIZE for _ in range(SIZE)]

    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[y][x] = IDX[c] if isinstance(c, str) else c

    def get(self, x, y):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            return self.px[y][x]
        return 0

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(round(y0)), int(round(y1)) + 1):
            for x in range(int(round(x0)), int(round(x1)) + 1):
                self.set(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

    def thick(self, p0, p1, w, c):
        """Segmento grueso estampando cuadrados de lado w."""
        (x0, y0), (x1, y1) = p0, p1
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        lo = -(w // 2)
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for dy in range(lo, lo + w):
                for dx in range(lo, lo + w):
                    self.set(math.floor(x + 0.5) + dx, math.floor(y + 0.5) + dy, c)

    def shift(self, dx, dy):
        new = [[0] * SIZE for _ in range(SIZE)]
        for y in range(SIZE):
            for x in range(SIZE):
                v = self.px[y][x]
                if v and 0 <= x + dx < SIZE and 0 <= y + dy < SIZE:
                    new[y + dy][x + dx] = v
        self.px = new

    def outline_and_rim(self, rim=True):
        """Contorno exterior de 1 px y luz de contorno de 1 px en la espalda/arriba."""
        filled = [[v != 0 for v in row] for row in self.px]
        for y in range(SIZE):
            for x in range(SIZE):
                if filled[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < SIZE and 0 <= yy < SIZE and filled[yy][xx]:
                        self.px[y][x] = IDX["outline"]
                        break
        if not rim:
            return
        cyan = IDX["world_cyan"]
        skip = {IDX["outline"], cyan, IDX["world_cyan_hi"], IDX["led_off"]}
        for y in range(SIZE):
            for x in range(SIZE):
                v = self.px[y][x]
                if not filled[y][x] or v in skip:
                    continue
                # luz de contrluz: borde izquierdo (espalda) y borde superior
                left_out = x == 0 or not filled[y][x - 1]
                top_out = y == 0 or not filled[y - 1][x]
                if (left_out and y < 50) or (top_out and y < 30 and x < 34):
                    self.px[y][x] = cyan

    def image(self):
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        put = img.putpixel
        for y in range(SIZE):
            for x in range(SIZE):
                v = self.px[y][x]
                if v:
                    put((x, y), PALETTE[v - 1][1] + (255,))
        return img


def polar(origin, angle_deg, length):
    """Angulo 0 = hacia abajo; positivo = hacia delante (derecha)."""
    a = math.radians(angle_deg)
    return (origin[0] + math.sin(a) * length, origin[1] + math.cos(a) * length)


# --- Figura -------------------------------------------------------------------
THIGH, SHIN = 10, 9
UPPER, FORE = 7, 6
HIP_Y = 42


class Pose:
    def __init__(self, **kw):
        self.front_leg = (0, 0)   # (angulo muslo, flexion rodilla)
        self.back_leg = (0, 0)
        self.front_arm = (8, 10)  # (angulo brazo, flexion codo hacia delante)
        self.back_arm = (-6, 10)
        self.lean = 0             # desplazamiento x del torso/cabeza
        self.breath = 0           # 0/1: hombros bajan 1 px
        self.airborne = False
        self.pack_bounce = 0      # rebote de mochila (px)
        self.led = True
        self.extras = None        # funcion(canvas, joints) para efectos
        self.__dict__.update(kw)


def leg_points(hip, leg):
    thigh, bend = leg
    knee = polar(hip, thigh, THIGH)
    ankle = polar(knee, thigh - bend, SHIN)
    return knee, ankle


def draw_leg(cv, hip, leg, dark):
    knee, ankle = leg_points(hip, leg)
    col = "jeans_shadow" if dark else "jeans"
    cv.thick(hip, knee, 4, col)
    cv.thick(knee, ankle, 4, col)
    ax, ay = round(ankle[0]), round(ankle[1])
    cv.rect(ax - 2, ay, ax + 3, ay + 1, "shoe")
    cv.rect(ax - 2, ay + 2, ax + 3, ay + 2, "sole")


def draw_arm(cv, shoulder, arm, dark):
    upper, bend = arm
    elbow = polar(shoulder, upper, UPPER)
    hand = polar(elbow, upper + bend, FORE)
    col = "jacket_shadow" if dark else "jacket"
    cv.thick(shoulder, elbow, 3, col)
    cv.thick(elbow, hand, 3, col)
    hx, hy = round(hand[0]), round(hand[1])
    cv.rect(hx - 1, hy, hx, hy + 1, "skin_shadow" if dark else "skin")
    return hand


def lowest_foot(pose):
    ys = []
    for hip, leg in (((33, HIP_Y), pose.front_leg), ((31, HIP_Y), pose.back_leg)):
        _, ankle = leg_points(hip, leg)
        ys.append(round(ankle[1]) + 2)
    return max(ys)


def draw_isak(pose):
    cv = Canvas()
    lx = pose.lean
    b = pose.breath
    sh_y = 29 + b

    # brazo trasero (detras del cuerpo)
    draw_arm(cv, (30 + lx, sh_y), pose.back_arm, dark=True)
    # pierna trasera
    draw_leg(cv, (31, HIP_Y), pose.back_leg, dark=True)

    # mochila (detras del torso)
    py = 28 + pose.pack_bounce + b
    cv.rect(21 + lx, py, 27 + lx, py + 11, "pack")
    cv.rect(21 + lx, py + 9, 27 + lx, py + 11, "pack_shadow")
    cv.rect(21 + lx, py, 21 + lx, py + 11, "pack_shadow")
    cv.rect(22 + lx, py + 5, 26 + lx, py + 5, "pack_shadow")  # cremallera/bolsillo
    cv.set(23 + lx, py + 2, "world_cyan" if pose.led else "led_off")  # LED

    # pierna delantera
    draw_leg(cv, (33, HIP_Y), pose.front_leg, dark=False)

    # torso: chaqueta abierta, camiseta negra delante
    top = 27 + b
    cv.rect(27 + lx, top, 37 + lx, 41, "jacket")
    cv.rect(27 + lx, top, 28 + lx, 41, "jacket_shadow")
    cv.rect(31 + lx, top + 1, 35 + lx, 41, "tee_black")
    cv.rect(36 + lx, top, 36 + lx, 41, "jacket_light")  # solapa delantera
    cv.rect(30 + lx, top + 1, 30 + lx, 41, "jacket_light")  # solapa
    # logo crema en el centro de la camiseta (rombo 3x3)
    lgx, lgy = 33 + lx, top + 5
    cv.set(lgx, lgy - 1, "logo_cream")
    cv.set(lgx - 1, lgy, "logo_cream")
    cv.set(lgx + 1, lgy, "logo_cream")
    cv.set(lgx, lgy + 1, "logo_cream")
    # correa de la mochila sobre el hombro
    cv.rect(29 + lx, top, 29 + lx, top + 9, "pack_shadow")
    # bajo de la chaqueta
    cv.rect(27 + lx, 41, 37 + lx, 41, "jacket_shadow")

    # cuello
    cv.rect(32 + lx, 25 + b, 34 + lx, 26 + b, "skin_shadow")

    # cabeza
    hx, hy = 33 + lx, 20 + b
    cv.ellipse(hx + 0.5, hy, 5.2, 5.6, "skin")
    # pelo: casquete y nuca
    cv.ellipse(hx - 0.5, hy - 3, 5.4, 3.2, "hair")
    cv.rect(hx - 5, hy - 3, hx - 2, hy + 3, "hair")
    cv.rect(hx + 3, hy - 5, hx + 6, hy - 3, "hair")  # flequillo
    cv.rect(hx - 2, hy - 6, hx + 2, hy - 6, "hair_light")
    cv.set(hx + 5, hy - 2, "hair")
    # oreja
    cv.set(hx - 1, hy + 1, "skin_shadow")
    cv.set(hx - 1, hy, "skin_shadow")
    # lentes: patilla + lente con reflejo
    cv.rect(hx, hy - 1, hx + 2, hy - 1, "outline")
    cv.rect(hx + 3, hy - 2, hx + 6, hy - 2, "outline")
    cv.rect(hx + 3, hy + 1, hx + 6, hy + 1, "outline")
    cv.rect(hx + 3, hy - 1, hx + 3, hy, "outline")
    cv.rect(hx + 6, hy - 1, hx + 6, hy, "outline")
    cv.rect(hx + 4, hy - 1, hx + 5, hy, "skin")
    cv.set(hx + 5, hy - 1, "world_cyan")
    cv.set(hx + 4, hy - 1, "world_cyan_hi")
    # boca / barbilla
    cv.set(hx + 4, hy + 3, "skin_shadow")

    # brazo delantero (encima del torso)
    hand = draw_arm(cv, (29 + lx, sh_y), pose.front_arm, dark=False)

    if pose.extras:
        pose.extras(cv, {"hand": hand, "head": (hx, hy), "lean": lx})

    # anclar pies al suelo (los cuadros aereos mantienen la altura de reposo)
    if pose.airborne:
        dy = 0
    else:
        dy = GROUND_Y - lowest_foot(pose)
    cv.shift(0, dy)
    cv.outline_and_rim()
    return cv.image()


# --- Animaciones ----------------------------------------------------------------
def anim_idle():
    frames = []
    for i in range(4):
        breath = 1 if i in (1, 2) else 0
        frames.append(Pose(
            front_leg=(4, 4), back_leg=(-3, 2),
            front_arm=(6, 8 + breath * 4), back_arm=(-6, 8),
            breath=breath, pack_bounce=breath,
        ))
    return frames


def anim_idle_terminal():
    """Saca la terminal holografica de la muneca y ajusta el visor (8 cuadros)."""
    def holo(level, touch=False):
        def fx(cv, j):
            hx, hy = j["hand"]
            if level > 0:
                # panel holografico encima de la muneca
                x0, y0 = round(hx) - 1, round(hy) - 9
                w = 7
                h = 2 + level * 2
                cv.rect(x0, y0 + (6 - h), x0 + w, y0 + 6, "world_cyan")
                for yy in range(y0 + (6 - h) + 1, y0 + 6, 2):
                    cv.rect(x0 + 1, yy, x0 + w - 2 - (yy % 3), yy, "world_cyan_hi")
        return fx

    p = dict(front_leg=(4, 4), back_leg=(-3, 2), back_arm=(-6, 8))
    seq = [
        Pose(front_arm=(20, 60), **p),
        Pose(front_arm=(35, 100), **p),
        Pose(front_arm=(35, 105), extras=holo(1), **p),
        Pose(front_arm=(35, 105), extras=holo(2), **p),
        Pose(front_arm=(35, 105), extras=holo(3), breath=1, **p),
        Pose(front_arm=(35, 105), extras=holo(3), **p),
        Pose(front_arm=(60, 150), extras=None, **p),   # se ajusta el visor
        Pose(front_arm=(20, 60), **p),
    ]
    return seq


def anim_walk():
    frames = []
    for i in range(6):
        ph = 2 * math.pi * i / 6
        s = math.sin(ph)
        c = math.cos(ph)
        front = (22 * s, 8 + max(0, -c) * 30)
        back = (-22 * s, 8 + max(0, c) * 30)
        frames.append(Pose(
            front_leg=front, back_leg=back,
            front_arm=(-18 * s, 15), back_arm=(18 * s, 15),
            pack_bounce=1 if i % 3 == 1 else 0,
        ))
    return frames


def anim_run():
    frames = []
    for i in range(6):
        ph = 2 * math.pi * i / 6
        s = math.sin(ph)
        c = math.cos(ph)
        front = (38 * s + 5, 15 + max(0, -c) * 70)
        back = (-38 * s + 5, 15 + max(0, c) * 70)
        frames.append(Pose(
            front_leg=front, back_leg=back,
            front_arm=(-45 * s + 5, 80), back_arm=(45 * s + 5, 80),
            lean=1, pack_bounce=1 if i % 3 == 0 else 0,
        ))
    return frames


def anim_jump():
    return [
        # 00 anticipacion: agachado
        Pose(front_leg=(55, 100), back_leg=(45, 95), front_arm=(-30, 20),
             back_arm=(-40, 20), lean=1, breath=1),
        # 01 subida: impulso, brazos arriba, una rodilla arriba
        Pose(front_leg=(50, 70), back_leg=(-10, 5), front_arm=(110, 0),
             back_arm=(100, 0), airborne=True, pack_bounce=2),
        # 02 apogeo: recogido
        Pose(front_leg=(70, 120), back_leg=(40, 110), front_arm=(80, 40),
             back_arm=(70, 40), airborne=True, pack_bounce=0),
        # 03 caida: piernas abajo, brazos abiertos
        Pose(front_leg=(15, 20), back_leg=(-10, 25), front_arm=(100, -30),
             back_arm=(90, -30), airborne=True, pack_bounce=-2),
        # 04 aplastamiento al aterrizar
        Pose(front_leg=(60, 110), back_leg=(50, 105), front_arm=(30, 30),
             back_arm=(20, 30), lean=1, breath=1, pack_bounce=1),
    ]


def anim_pulse():
    def burst(size, trail):
        def fx(cv, j):
            hx, hy = round(j["hand"][0]), round(j["hand"][1])
            if trail:
                for k in range(1, trail + 1):
                    cv.set(hx - 1 - k * 2, hy, "world_cyan")
            if size:
                cv.rect(hx + 1, hy - size + 1, hx + size, hy + size, "world_cyan")
                cv.rect(hx + 2, hy - size + 2, hx + size - 1, hy + size - 1, "world_cyan_hi")
        return fx

    legs = dict(front_leg=(18, 6), back_leg=(-14, 4))
    return [
        Pose(front_arm=(-20, 90), back_arm=(-10, 20), extras=None, **legs),
        Pose(front_arm=(90, 0), back_arm=(-25, 20), lean=1, extras=burst(2, 0), **legs),
        Pose(front_arm=(90, 0), back_arm=(-25, 20), lean=1, extras=burst(3, 3), **legs),
        Pose(front_arm=(60, 20), back_arm=(-15, 20), extras=burst(0, 2), **legs),
    ]


ANIMS = [
    ("idle", anim_idle),
    ("terminal", anim_idle_terminal),
    ("walk", anim_walk),
    ("run", anim_run),
    ("jump", anim_jump),
    ("pulse", anim_pulse),
]


def contact_sheet(all_frames, path, scale=8):
    cols = max(len(f) for _, f in all_frames)
    pad = 4
    cell = SIZE + pad
    bgs = [(26, 30, 52), (120, 128, 140)]  # oscuro (Mundo 1) y claro, para probar legibilidad
    w = cols * cell + pad
    h = len(all_frames) * 2 * cell + pad
    sheet = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    for r, (_, frames) in enumerate(all_frames):
        for v, bg in enumerate(bgs):
            y = pad + (r * 2 + v) * cell
            for c, img in enumerate(frames):
                x = pad + c * cell
                tile = Image.new("RGBA", (SIZE, SIZE), bg + (255,))
                tile.alpha_composite(img)
                sheet.paste(tile, (x, y))
    sheet = sheet.resize((w * scale, h * scale), Image.NEAREST)
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="carpeta donde guardar la vista ampliada x8")
    args = ap.parse_args()

    os.makedirs(PAL_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    write_gpl(os.path.join(PAL_DIR, "isak.gpl"))
    write_palette_preview(os.path.join(PAL_DIR, "isak_palette_preview.png"))

    all_frames = []
    for name, fn in ANIMS:
        frames = [draw_isak(p) for p in fn()]
        for i, img in enumerate(frames):
            img.save(os.path.join(OUT_DIR, f"isak_{name}_{i:02d}_placeholder.png"))
        sheet = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
        for i, img in enumerate(frames):
            sheet.paste(img, (i * SIZE, 0))
        sheet.save(os.path.join(OUT_DIR, f"isak_{name}_sheet_placeholder.png"))
        all_frames.append((name, frames))

    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        contact_sheet(all_frames, os.path.join(args.preview, "isak_contact_x8.png"))
    print(f"OK: {sum(len(f) for _, f in all_frames)} cuadros en {OUT_DIR}")


if __name__ == "__main__":
    main()
