#!/usr/bin/env python3
"""Genera los sprites del punto rojo (notification_badge) y del banner de spam (spam_banner) del
Mundo 1 (1-2, pasos 4 y 5 de docs/propuesta-1-2.md §10) con los colores de assets/palettes/mundo1.gpl.

Mismo estilo que la Burbuja de alerta (tools/gen_alert_bubble.py): pixeles logicos de 2x2 px,
contorno noche_profunda, rojo alerta con sombra alerta_sombra y brillo banner_blanco; aturdido en
gris (banner_gris / resplandor) con canto claro de plataforma (borde_luz) y chispas. Solo colores del
mundo (sin debug_cian: el cian es del Debug y de lo interactivo) y alfa 0/255. Tamanos y animaciones
de data/enemies/<tipo>.json (seccion "sprites").

Punto rojo (badge_<anim>_<NN>.png, 64x64, pies abajo-centro; el centro del cuerpo a 32 px):
  idle        dormido: flota despacio, «1» blanco, sin halo
  chase       persigue: halo de cuatro puntos que gira y estela corta debajo
  anticipate  aviso antes de lanzarse (9 cuadros): se infla, tiembla y destella en blanco
  lunge       lanzado: inflado con contorno blanco
  stunned     aturdido: gris, apagado, canto plano claro (plataforma) y chispas que giran
  wake        fin del aturdimiento (9 cuadros): alterna gris y rojo cada vez mas rapido
  deflect     chispa gris (el laser no le hace nada despierto); se dibuja encima del cuerpo
  pop         derrotado: destello, anillo roto y gotas
Banner (banner_<anim>_<NN>.png, 128x64; dibujado hacia la derecha):
  idle        ranura de la entrada del pasillo, apagada
  anticipate  aviso (9 cuadros): la ranura parpadea en rojo alerta y salen flechas
  sweep       el banner blanco «OFERTA / SOLO HOY» con icono de alerta; brillo que corre
  trail       estela de lineas de velocidad detras del banner

Escribe tambien assets/sprites/enemies/_badge_preview.png y _banner_preview.png (cuadros x2 sobre
noche_profunda, resplandor y silueta en negro).
Validador: tools/validate_world1_enemies.py (al dia con este generador y reglas de los enemigos).

Uso: python3 -I tools/gen_world1_enemies.py
"""
import json
import math
import os
import site
import sys

sys.path.append(site.getusersitepackages())
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNIT = 2
CLEAR = (0, 0, 0, 0)
ENEMIES = ("notification_badge", "spam_banner")


def res_to_path(res):
    return os.path.join(ROOT, res.replace("res://", "", 1))


def load_palette(path):
    colors = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                colors[parts[3]] = tuple(int(p) for p in parts[:3]) + (255,)
    return colors


def sprites_cfg(kind):
    with open(os.path.join(ROOT, "data", "enemies", kind + ".json"), encoding="utf-8") as fh:
        return json.load(fh)["sprites"]


P = load_palette(os.path.join(ROOT, "assets", "palettes", "mundo1.gpl"))


class Frame:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def put(self, x, y, color):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and color is not None:
            self.px[y][x] = color

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None

    def rect(self, x0, y0, x1, y1, color):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, color)

    def image(self):
        img = Image.new("RGBA", (self.w * UNIT, self.h * UNIT), CLEAR)
        d = ImageDraw.Draw(img)
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    d.rectangle([x * UNIT, y * UNIT, x * UNIT + UNIT - 1, y * UNIT + UNIT - 1], fill=P[c])
        return img


def inside(x, y, cx, cy, rx, ry):
    dx = (x + 0.5 - cx) / rx
    dy = (y + 0.5 - cy) / ry
    return dx * dx + dy * dy <= 1.0


def spark(f, x, y, color, big=True):
    f.put(x, y, color)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        f.put(x + dx, y + dy, color)
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            f.put(x + dx, y + dy, color)


# =================================================================== punto rojo (32x32 logicos)
BW, BH = 32, 32
CX, CY, R = 16.0, 16.0, 10.0

ONE = [".X.", "XX.", ".X.", ".X.", ".X.", ".X.", "XXX"]


def digit_one(f, cx, cy, color, shadow):
    x0 = int(round(cx)) - 2
    y0 = int(round(cy)) - 4
    cells = [(x0 + i, y0 + j) for j, row in enumerate(ONE) for i, ch in enumerate(row) if ch == "X"]
    if shadow is not None:
        for x, y in cells:
            if (x + 1, y + 1) not in cells:
                f.put(x + 1, y + 1, shadow)
    for x, y in cells:
        f.put(x, y, color)


def badge(f, cx=CX, cy=CY, rx=R, ry=R, body="alerta", shade="alerta_sombra", outline="noche_profunda",
          hi="banner_blanco", mark="banner_blanco", mark_shadow="alerta_sombra", glow=None, cap=None):
    """Circulo rojo con contorno, sombra abajo a la derecha, brillo arriba a la izquierda y «1»."""
    for y in range(int(cy - ry - 4), int(cy + ry + 4)):
        for x in range(int(cx - rx - 4), int(cx + rx + 4)):
            if inside(x, y, cx, cy, rx, ry):
                lit = inside(x, y, cx - 1.5, cy - 1.5, rx - 0.8, ry - 0.8)
                f.put(x, y, body if lit else shade)
            elif inside(x, y, cx, cy, rx + 1.0, ry + 1.0):
                f.put(x, y, outline)
            elif glow is not None and inside(x, y, cx, cy, rx + 2.0, ry + 2.0):
                f.put(x, y, glow)
    if cap is not None:
        top = int(math.floor(cy - ry))
        for x in range(int(cx - rx * 0.6), int(math.ceil(cx + rx * 0.6))):
            for y in range(top - 1, top + 1):
                if f.get(x, y) is not None:
                    f.put(x, y, cap)
    if hi is not None:
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if not inside(x, y, cx, cy, rx, ry):
                    continue
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(dx / rx, dy / ry)
                ang = math.degrees(math.atan2(dy, dx)) % 360
                if 0.66 <= d <= 0.86 and 205 <= ang <= 250:
                    f.put(x, y, hi)
    if mark is not None:
        digit_one(f, cx, cy, mark, mark_shadow)


def badge_idle(n):
    bob = [0, 0, -1, -1, 0, 0]
    out = []
    for i in range(n):
        f = Frame(BW, BH)
        badge(f, cy=CY + bob[i % len(bob)])
        out.append(f)
    return out


def badge_chase(n):
    out = []
    for i in range(n):
        f = Frame(BW, BH)
        b = -1 if i % 2 else 0
        # estela corta debajo (se mueve: va detras)
        for k, col in enumerate(("alerta_sombra", "alerta_sombra", "tile_luz")):
            f.put(CX - 1 + (i % 2), CY + R + 2 + k * 2 + b, col)
        badge(f, cy=CY + b)
        # halo: cuatro puntos que giran
        for k in range(4):
            a = i * math.pi / (2 * n) + k * math.pi / 2
            hx = int(round(CX + math.cos(a) * (R + 3.5)))
            hy = int(round(CY + b + math.sin(a) * (R + 3.5)))
            f.put(hx, hy, "banner_blanco" if k % 2 == 0 else "alerta")
        out.append(f)
    return out


def badge_anticipate(n):
    # se infla poco a poco, tiembla y destella en blanco los ultimos cuadros
    script = [(0.0, 0, None), (0.5, 0, None), (1.0, -1, None), (1.0, 1, None), (1.5, 0, None),
              (2.0, -1, "banner_blanco"), (2.0, 1, None), (2.5, 0, "banner_blanco"), (2.5, 0, "banner_blanco")]
    out = []
    for i in range(n):
        swell, dx, glow = script[min(i, len(script) - 1)]
        f = Frame(BW, BH)
        badge(f, cx=CX + dx, cy=CY - swell * 0.3, rx=R + swell, ry=R + swell, glow=glow,
              mark="banner_blanco" if glow is None else "alerta_sombra", mark_shadow=None if glow else "alerta_sombra",
              body="alerta" if glow is None else "banner_blanco", shade="alerta_sombra" if glow is None else "alerta",
              hi="banner_blanco" if glow is None else None)
        out.append(f)
    return out


def badge_lunge(n):
    out = []
    for i in range(n):
        f = Frame(BW, BH)
        badge(f, rx=R + 2.5, ry=R + 2.0, glow="banner_blanco" if i == 0 else "alerta")
        out.append(f)
    return out


STUN = dict(body="banner_gris", shade="resplandor", mark="tile_luz", mark_shadow=None, cap="borde_luz")


def badge_stunned_frame(phase=None):
    f = Frame(BW, BH)
    badge(f, cy=CY + 0.5, **STUN)
    if phase is not None:
        for k in range(2):
            a = phase + k * math.pi
            sx = int(round(CX + math.cos(a) * 8))
            sy = int(round(CY - R - 3 + math.sin(a) * 1.5))
            spark(f, sx, sy, "banner_blanco" if k == 0 else "ambar", big=math.sin(a) < 0)
    return f


def badge_stunned(n):
    return [badge_stunned_frame(i * 2 * math.pi / n) for i in range(n)]


def badge_wake(n):
    script = ["S", "S", "A", "S", "A", "S", "A", "A", "A"]
    out = []
    for i in range(n):
        kind = script[min(i, len(script) - 1)]
        if kind == "S":
            f = badge_stunned_frame()
            if i > 0:
                digit_one(f, CX, CY + 0.5, "alerta", None)
        else:
            f = Frame(BW, BH)
            badge(f, glow="banner_blanco" if i >= 6 else None)
        out.append(f)
    return out


def badge_deflect(n):
    # chispa gris: estrella blanca con rayos grises que se separan y se apagan (no hay dano)
    out = []
    for i in range(n):
        f = Frame(BW, BH)
        cx, cy = int(CX), int(CY)
        r0, r1 = [(0, 3), (2, 6), (5, 9), (8, 11)][min(i, 3)]
        for k in range(8):
            a = k * math.pi / 4
            long_ray = k % 2 == 0
            end = r1 if long_ray else r1 - 2
            for r in range(r0, end + 1):
                x = int(round(cx + math.cos(a) * r))
                y = int(round(cy + math.sin(a) * r))
                if i == 3:
                    if r == end:
                        f.put(x, y, "tile_luz")
                    continue
                f.put(x, y, "banner_blanco" if (r <= r0 + 1 and i < 2) else "banner_gris")
        if i == 0:
            spark(f, cx, cy, "banner_blanco")
        elif i == 1:
            spark(f, cx, cy, "banner_gris", big=False)
        out.append(f)
    return out


def badge_pop(n):
    out = []
    f = Frame(BW, BH)
    badge(f, rx=R + 2, ry=R + 2, body="banner_blanco", shade="alerta", hi=None, mark="alerta", mark_shadow=None)
    out.append(f)
    f = Frame(BW, BH)
    for y in range(BH):
        for x in range(BW):
            d = math.hypot(x + 0.5 - CX, y + 0.5 - CY)
            ang = math.degrees(math.atan2(y + 0.5 - CY, x + 0.5 - CX)) % 45
            if R + 0.5 <= d <= R + 2.5 and 8 <= ang <= 37:
                f.put(x, y, "alerta" if d < R + 1.5 else "alerta_sombra")
    spark(f, int(CX), int(CY), "banner_blanco")
    out.append(f)
    for dist, size, color in ((11, 2, "alerta"), (13, 2, "alerta_sombra"), (14, 1, "banner_gris")):
        f = Frame(BW, BH)
        for k in range(8):
            a = math.radians(22.5 + k * 45)
            gx = int(round(CX + math.cos(a) * dist - size / 2))
            gy = int(round(CY + math.sin(a) * dist - size / 2))
            f.rect(gx, gy, gx + size - 1, gy + size - 1, color)
        out.append(f)
    return out[:n]


BADGE = {"idle": badge_idle, "chase": badge_chase, "anticipate": badge_anticipate, "lunge": badge_lunge,
         "stunned": badge_stunned, "wake": badge_wake, "deflect": badge_deflect, "pop": badge_pop}


# =================================================================== banner (64x32 logicos)
NW, NH = 64, 32
FONT = {
    "O": ["XXX", "X.X", "X.X", "X.X", "XXX"],
    "F": ["XXX", "X..", "XX.", "X..", "X.."],
    "E": ["XXX", "X..", "XX.", "X..", "XXX"],
    "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
    "T": ["XXX", ".X.", ".X.", ".X.", ".X."],
    "A": [".X.", "X.X", "XXX", "X.X", "X.X"],
    "S": ["XXX", "X..", "XXX", "..X", "XXX"],
    "L": ["X..", "X..", "X..", "X..", "XXX"],
    "H": ["X.X", "X.X", "XXX", "X.X", "X.X"],
    "Y": ["X.X", "X.X", ".X.", ".X.", ".X."],
    "!": ["X", "X", "X", ".", "X"],
    " ": ["..", "..", "..", "..", ".."],
}


def text(f, x, y, s, color):
    for ch in s:
        g = FONT[ch]
        for j, row in enumerate(g):
            for i, c in enumerate(row):
                if c == "X":
                    f.put(x + i, y + j, color)
        x += len(g[0]) + 1
    return x


BX0, BX1, BY0, BY1 = 1, 62, 8, 31  # caja del banner (48 px de alto, a ras de suelo)


def banner_body(f, shine=None):
    f.rect(BX0, BY0, BX1, BY1, "noche_profunda")
    f.rect(BX0 + 1, BY0 + 1, BX1 - 1, BY1 - 1, "banner_blanco")
    f.rect(BX0 + 1, BY1 - 3, BX1 - 1, BY1 - 1, "banner_gris")
    for x, y in ((BX0, BY0), (BX1, BY0), (BX0, BY1), (BX1, BY1)):
        f.px[y][x] = None
    # icono de alerta a la izquierda
    f.rect(BX0 + 3, BY0 + 4, BX0 + 12, BY0 + 15, "alerta_sombra")
    f.rect(BX0 + 3, BY0 + 4, BX0 + 11, BY0 + 14, "alerta")
    text(f, BX0 + 7, BY0 + 6, "!", "banner_blanco")
    if shine is not None:
        for k in range(3):
            for y in range(BY0 + 1, BY1 - 3):
                x = shine + k - (y - BY0) // 3
                if BX0 + 14 <= x <= BX1 - 2 and f.get(x, y) == "banner_blanco":
                    f.put(x, y, "borde_luz" if k != 1 else "banner_gris")
    text(f, BX0 + 16, BY0 + 5, "OFERTA!", "alerta")
    text(f, BX0 + 16, BY0 + 13, "SOLO HOY", "alerta_sombra")
    # filo delantero (va hacia la derecha)
    f.rect(BX1 - 2, BY0 + 3, BX1 - 1, BY1 - 5, "alerta")


def banner_sweep(n):
    out = []
    for i in range(n):
        f = Frame(NW, NH)
        banner_body(f, shine=[20, 32, 44, None][i % 4])
        out.append(f)
    return out


def banner_trail(n):
    rows = [(BY0 + 3, 40, "banner_gris"), (BY0 + 8, 26, "resplandor"), (BY0 + 13, 48, "banner_gris"),
            (BY0 + 18, 30, "resplandor"), (BY1 - 3, 54, "banner_gris")]
    out = []
    for i in range(n):
        f = Frame(NW, NH)
        for k, (y, length, color) in enumerate(rows):
            length = max(6, length - i * 10 - (k % 2) * 4)
            x1 = NW - 1 - ((i + k) % 3) * 2
            for x in range(x1 - length, x1 + 1):
                # discontinua hacia atras: se deshace
                if (x1 - x) < length // 2 or (x + i) % 3 != 0:
                    f.put(x, y, color)
        out.append(f)
    return out


SLOT_X0, SLOT_X1 = 29, 34


def slot(f, light, arrows=0, arrow_color="tile_luz", glow=False):
    f.rect(SLOT_X0, 6, SLOT_X1, NH - 1, "noche_profunda")
    f.rect(SLOT_X0 + 1, 7, SLOT_X1 - 1, NH - 1, "tile_luz")
    f.rect(SLOT_X0 + 2, 8, SLOT_X1 - 2, NH - 1, "tile_sombra")
    f.rect(SLOT_X0 + 2, 15, SLOT_X1 - 2, 24, light)
    if glow:
        for y in range(6, NH):
            f.put(SLOT_X0 - 1, y, "banner_blanco" if y % 2 == 0 else "alerta")
            f.put(SLOT_X1 + 1, y, "banner_blanco" if y % 2 == 0 else "alerta")
    for k in range(arrows):
        ax = SLOT_X1 + 4 + k * 6
        for j in range(4):
            f.put(ax + j, 16 + j, arrow_color)
            f.put(ax + j, 23 - j, arrow_color)
            f.put(ax + j + 1, 16 + j, arrow_color)
            f.put(ax + j + 1, 23 - j, arrow_color)


def banner_idle(n):
    out = []
    for i in range(n):
        f = Frame(NW, NH)
        slot(f, "alerta_sombra" if i == 0 else "tile_base", arrows=1)
        out.append(f)
    return out


def banner_anticipate(n):
    # parpadeo cada vez mas rapido; las flechas se encienden una a una
    script = [("tile_base", 1, False), ("alerta", 1, False), ("tile_base", 1, False), ("alerta", 2, False),
              ("alerta_sombra", 2, False), ("alerta", 3, False), ("alerta", 3, True), ("banner_blanco", 4, True),
              ("alerta", 4, True)]
    out = []
    for i in range(n):
        light, arrows, glow = script[min(i, len(script) - 1)]
        f = Frame(NW, NH)
        slot(f, light, arrows=arrows, arrow_color="alerta" if light != "tile_base" else "alerta_sombra", glow=glow)
        out.append(f)
    return out


BANNER = {"idle": banner_idle, "anticipate": banner_anticipate, "sweep": banner_sweep, "trail": banner_trail}
BUILDERS = {"notification_badge": BADGE, "spam_banner": BANNER}


# =================================================================== salida
def sheets(kind):
    cfg = sprites_cfg(kind)
    out = {}
    for anim, spec in cfg["animations"].items():
        frames = [f.image() for f in BUILDERS[kind][anim](spec["frames"])]
        assert len(frames) == spec["frames"], (kind, anim)
        for im in frames:
            assert list(im.size) == list(cfg["frame_size"]), (kind, anim, im.size)
        out[anim] = frames
    return out


def outputs():
    """{ruta absoluta del PNG: imagen} de los dos enemigos."""
    files = {}
    for kind in ENEMIES:
        cfg = sprites_cfg(kind)
        directory = res_to_path(cfg["dir"])
        for anim, frames in sheets(kind).items():
            for i, im in enumerate(frames):
                files[os.path.join(directory, "%s_%s_%02d.png" % (cfg["prefix"], anim, i))] = im
    return files


def preview(kind):
    cfg = sprites_cfg(kind)
    fw, fh = cfg["frame_size"]
    scale, pad = 2, 8
    data = sheets(kind)
    cols = max(len(v) for v in data.values())
    cw, ch = fw * scale + pad, fh * scale + pad
    img = Image.new("RGBA", (pad + cols * cw, pad + len(data) * 3 * ch), P["noche_profunda"])
    d = ImageDraw.Draw(img)
    y = pad
    for frames in data.values():
        for bg in ("noche_profunda", "resplandor", None):
            for i, im in enumerate(frames):
                x = pad + i * cw
                big = im.resize((fw * scale, fh * scale), Image.NEAREST)
                if bg is None:
                    sil = Image.new("RGBA", big.size, P["banner_blanco"])
                    sil.paste(Image.new("RGBA", big.size, (0, 0, 0, 255)), (0, 0), big)
                    img.paste(sil, (x, y))
                else:
                    d.rectangle([x, y, x + fw * scale - 1, y + fh * scale - 1], fill=P[bg])
                    img.paste(big, (x, y), big)
            y += ch
    return img


def main():
    for kind in ENEMIES:
        cfg = sprites_cfg(kind)
        directory = res_to_path(cfg["dir"])
        os.makedirs(directory, exist_ok=True)
        for old in os.listdir(directory):
            if old.startswith(cfg["prefix"] + "_") and old.endswith(".png") and not old.startswith("_"):
                os.remove(os.path.join(directory, old))
    files = outputs()
    for path, im in files.items():
        im.save(path)
    for kind in ENEMIES:
        cfg = sprites_cfg(kind)
        preview(kind).save(os.path.join(res_to_path(cfg["dir"]), "_%s_preview.png" % cfg["prefix"]))
    print("gen_world1_enemies: %d cuadros" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
