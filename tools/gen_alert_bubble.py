#!/usr/bin/env python3
"""Genera los sprites de la Burbuja de alerta (Mundo 1) con los colores de assets/palettes/mundo1.gpl.

Lee tamanos y animaciones de data/enemies/alert_bubble.json (seccion "sprites"). Cada cuadro se
dibuja en una rejilla logica de 48x48 "pixeles" de 2x2 px (lienzo de 96x96, pies abajo-centro),
como el tileset. Solo colores del mundo (sin debug_cian) y alfa 0/255.

Animaciones (bubble_<anim>_<NN>.png en assets/sprites/enemies/):
  idle        flota: sube y baja 1 px logico con un leve aplastamiento (patrulla, peligrosa)
  stunned     aturdida: gris apagado, "!" apagado, borde superior claro de plataforma
              (borde_luz, como las plataformas de una via del tileset) y chispas que giran
  anticipate  aviso de fin del aturdimiento (A8): alterna aturdida y alerta cada vez mas
              rapido, se hincha, tiembla y el "!" brilla; el ultimo cuadro es la alerta plena
  pop         se revienta: destello, anillo roto y gotas que se alejan

Tambien escribe assets/sprites/enemies/_bubble_preview.png: todos los cuadros x2 sobre el fondo
del mundo (noche_profunda y resplandor), su silueta en negro y muestras de alerta, carmin y cian.

Uso: python3 tools/gen_alert_bubble.py
"""
import json
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "enemies", "alert_bubble.json")
UNIT = 2
CLEAR = (0, 0, 0, 0)


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


with open(DATA, encoding="utf-8") as _fh:
    CFG = json.load(_fh)["sprites"]
P = load_palette(res_to_path(CFG["palette"]))
FW, FH = CFG["frame_size"]
LW, LH = FW // UNIT, FH // UNIT  # 48x48 logicos
OUT_DIR = res_to_path(CFG["dir"])
PREFIX = CFG["prefix"]

# Centro y radio de la burbuja en pixeles logicos. Borde inferior del contorno en y = 46
# (2 px logicos sobre los pies: flota) y superior en y = 6.
CX, CY, R = 24.0, 26.0, 19.0


class Frame:
    def __init__(self):
        self.px = [[None] * LW for _ in range(LH)]

    def put(self, x, y, color):
        if 0 <= x < LW and 0 <= y < LH and color is not None:
            self.px[y][x] = color

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < LW and 0 <= y < LH else None

    def rect(self, x0, y0, x1, y1, color):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, color)

    def image(self):
        img = Image.new("RGBA", (FW, FH), CLEAR)
        d = ImageDraw.Draw(img)
        for y in range(LH):
            for x in range(LW):
                c = self.px[y][x]
                if c is not None:
                    d.rectangle([x * UNIT, y * UNIT, x * UNIT + UNIT - 1, y * UNIT + UNIT - 1], fill=P[c])
        return img


def inside(x, y, cx, cy, rx, ry):
    dx = (x + 0.5 - cx) / rx
    dy = (y + 0.5 - cy) / ry
    return dx * dx + dy * dy <= 1.0


def bubble(f, cx=CX, cy=CY, rx=R, ry=R, body="alerta", shade="alerta_sombra", outline="noche_profunda",
           hi="banner_blanco", mark="banner_blanco", mark_shadow="alerta_sombra", cap=None, glow=None):
    """Burbuja con contorno, sombra abajo a la derecha, brillo arriba a la izquierda y el signo "!".

    cap: color del borde superior (plataforma) que sustituye al contorno en la parte de arriba.
    glow: color de un anillo exterior de 1 px (brillo de la anticipacion)."""
    x0, x1 = int(cx - rx - 3), int(cx + rx + 3)
    y0, y1 = int(cy - ry - 3), int(cy + ry + 3)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if inside(x, y, cx, cy, rx, ry):
                # sombra: lo que queda fuera de un circulo desplazado arriba a la izquierda
                lit = inside(x, y, cx - 2.5, cy - 2.5, rx - 1.0, ry - 1.0)
                f.put(x, y, body if lit else shade)
            elif inside(x, y, cx, cy, rx + 1.0, ry + 1.0):
                f.put(x, y, outline)
            elif glow is not None and inside(x, y, cx, cy, rx + 2.0, ry + 2.0):
                f.put(x, y, glow)
    if cap is not None:
        # borde superior grueso y plano: se lee como el canto de una plataforma
        top = int(math.floor(cy - ry))
        for x in range(int(cx - rx * 0.62), int(math.ceil(cx + rx * 0.62))):
            for y in range(top - 1, top + 2):
                if f.get(x, y) is not None:
                    f.put(x, y, cap)
    if hi is not None:
        # arco de brillo arriba a la izquierda y un punto
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if not inside(x, y, cx, cy, rx, ry):
                    continue
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(dx / rx, dy / ry)
                ang = math.degrees(math.atan2(dy, dx)) % 360
                if 0.70 <= d <= 0.84 and 200 <= ang <= 250:
                    f.put(x, y, hi)
        f.put(int(cx - rx * 0.62), int(cy - ry * 0.25), hi)
    if mark is not None:
        exclamation(f, cx, cy, ry, mark, mark_shadow)


def exclamation(f, cx, cy, ry, color, shadow):
    """Signo "!" grueso: barra de 4 px que se estrecha y punto de 4x4, con sombra a la derecha."""
    left = int(round(cx)) - 2
    top = int(round(cy - ry * 0.62))
    rows = []
    for i in range(12):
        w0 = 0 if i < 8 else 1
        rows.append((top + i, left + w0, left + 3 - w0))
    dot_top = top + 14
    for i in range(4):
        rows.append((dot_top + i, left, left + 3))
    if shadow is not None:
        for y, a, b in rows:
            f.put(b + 1, y + 1, shadow)
            f.put(b + 1, y, shadow)
        for x in range(left + 1, left + 5):
            f.put(x, dot_top + 4, shadow)
    for y, a, b in rows:
        for x in range(a, b + 1):
            f.put(x, y, color)


def spark(f, x, y, color, big=True):
    f.put(x, y, color)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        f.put(x + dx, y + dy, color)
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            f.put(x + dx, y + dy, color)


# ------------------------------------------------------------------ animaciones
def idle_frames(n):
    # sube y baja un pixel logico; abajo se aplasta un poco (rebote blando)
    bob = [0, -1, -1, 0, 1, 1]
    frames = []
    for i in range(n):
        b = bob[i % len(bob)]
        squash = 0.6 if b > 0 else 0.0
        f = Frame()
        bubble(f, cy=CY + b + squash * 0.5, rx=R + squash * 0.5, ry=R - squash * 0.5)
        frames.append(f)
    return frames


STUN = dict(body="banner_gris", shade="resplandor", mark="tile_luz", mark_shadow=None, hi="banner_blanco",
            cap="borde_luz")


# Filas logicas que se recortan de la cupula al aturdirse: la parte de arriba queda plana.
FLAT_CUT = 3


def flatten_top(f, flat_y):
    """Corta la cupula por encima de flat_y y pone un canto plano: contorno oscuro y dos filas de
    borde_luz (el mismo canto claro que las plataformas de una via del tileset)."""
    xs = [x for x in range(LW) if f.get(x, flat_y + 2) is not None]
    for y in range(flat_y):
        for x in range(LW):
            f.px[y][x] = None
    if not xs:
        return
    a, b = min(xs), max(xs)
    f.rect(a, flat_y - 1, b, flat_y - 1, "noche_profunda")
    f.rect(a + 1, flat_y, b - 1, flat_y + 1, "borde_luz")
    f.put(a, flat_y, "noche_profunda")
    f.put(b, flat_y, "noche_profunda")
    f.put(a, flat_y + 1, "noche_profunda")
    f.put(b, flat_y + 1, "noche_profunda")


def stunned(f, sparks_phase=None, rx=R + 0.5, ry=R - 1.0):
    # desinflada: un poco mas ancha y baja, con el borde de arriba plano y claro
    cy = CY + 1.0
    bubble(f, cy=cy, rx=rx, ry=ry, **STUN)
    flatten_top(f, int(math.floor(cy - ry)) + FLAT_CUT)
    if sparks_phase is not None:
        top = cy - ry
        for k in range(2):
            a = sparks_phase + k * math.pi
            sx = int(round(CX + math.cos(a) * 12))
            sy = int(round(top - 3 + math.sin(a) * 2.5))
            spark(f, sx, sy, "banner_blanco" if k == 0 else "ambar", big=math.sin(a) < 0)


def stunned_frames(n):
    frames = []
    for i in range(n):
        f = Frame()
        stunned(f, sparks_phase=i * 2 * math.pi / n)
        frames.append(f)
    return frames


def alert(f, swell=0.0, dx=0, glow=False, mark="banner_blanco"):
    bubble(f, cx=CX + dx, cy=CY - swell * 0.5, rx=R + swell, ry=R + swell * 0.5, mark=mark,
           glow="banner_blanco" if glow else None)


def anticipate_frames(n):
    # alterna aturdida (S) y alerta (A); la alerta dura cada vez mas, se hincha y tiembla.
    script = [
        ("S", {}),
        ("S", {"mark": "alerta"}),
        ("A", {"swell": 0.0}),
        ("S", {"mark": "alerta"}),
        ("A", {"swell": 1.0, "dx": -1}),
        ("S", {"mark": "alerta"}),
        ("A", {"swell": 1.5, "dx": 1, "glow": True}),
        ("A", {"swell": 2.0, "dx": -1, "glow": True}),
        ("A", {"swell": 2.0, "dx": 0, "glow": True}),
    ]
    frames = []
    for i in range(n):
        kind, kw = script[min(i, len(script) - 1)]
        f = Frame()
        if kind == "S":
            stunned(f)
            if kw.get("mark"):
                exclamation(f, CX, CY + 1.0, R - 1.0, kw["mark"], None)
        else:
            alert(f, **kw)
        frames.append(f)
    return frames


def pop_frames(n):
    frames = []
    # 0: destello hinchado
    f = Frame()
    bubble(f, rx=R + 2.5, ry=R + 1.5, cy=CY - 1, body="banner_blanco", shade="alerta", hi=None,
           mark="alerta", mark_shadow=None)
    frames.append(f)
    # 1: anillo roto en 8 trozos
    f = Frame()
    for y in range(LH):
        for x in range(LW):
            dx, dy = x + 0.5 - CX, y + 0.5 - (CY - 1)
            d = math.hypot(dx, dy)
            ang = math.degrees(math.atan2(dy, dx)) % 45
            if R + 0.5 <= d <= R + 3.0 and 8 <= ang <= 37:
                f.put(x, y, "alerta" if d < R + 2.0 else "alerta_sombra")
    spark(f, int(CX), int(CY - 1), "banner_blanco")
    frames.append(f)
    # 2-4: gotas que se alejan y se apagan
    for dist, size, color, edge in ((15, 3, "alerta", "alerta_sombra"), (18, 2, "alerta", "alerta_sombra"),
                                    (21, 1, "banner_gris", None)):
        f = Frame()
        for k in range(8):
            a = math.radians(22.5 + k * 45)
            gx = int(round(CX + math.cos(a) * dist - size / 2))
            gy = int(round(CY - 1 + math.sin(a) * dist - size / 2))
            f.rect(gx, gy, gx + size - 1, gy + size - 1, color)
            if edge is not None:
                f.rect(gx + 1, gy + size - 1, gx + size - 1, gy + size - 1, edge)
        if dist == 15:
            spark(f, int(CX), int(CY - 1), "banner_blanco", big=False)
        frames.append(f)
    return frames[:n]


BUILDERS = {"idle": idle_frames, "stunned": stunned_frames, "anticipate": anticipate_frames, "pop": pop_frames}


def preview(sheets):
    scale = 2
    pad = 8
    cols = max(len(v) for v in sheets.values())
    cell = FW * scale + pad
    rows = len(sheets)
    img = Image.new("RGBA", (pad + cols * cell, pad + rows * 3 * cell + 3 * cell), P["noche_profunda"])
    d = ImageDraw.Draw(img)
    y = pad
    for name, frames in sheets.items():
        for bg_i, bg in enumerate(("noche_profunda", "resplandor", None)):
            for i, im in enumerate(frames):
                x = pad + i * cell
                big = im.resize((FW * scale, FH * scale), Image.NEAREST)
                if bg is None:
                    sil = Image.new("RGBA", big.size, P["banner_blanco"])
                    black = Image.new("RGBA", big.size, (0, 0, 0, 255))
                    sil.paste(black, (0, 0), big)
                    img.paste(sil, (x, y))
                else:
                    d.rectangle([x, y, x + FW * scale - 1, y + FH * scale - 1], fill=P[bg])
                    img.paste(big, (x, y), big)
            y += cell
    # muestras de color: alerta, alerta_sombra, carmin, carmin_brillo y el cian del pulso/Debug
    for i, name in enumerate(("alerta", "alerta_sombra", "carmin", "carmin_brillo", "debug_cian")):
        x = pad + i * cell
        d.rectangle([x, y, x + FW * scale - 1, y + FH * scale - 1], fill=P[name])
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for old in os.listdir(OUT_DIR):
        if old.startswith(PREFIX + "_") and old.endswith(".png"):
            os.remove(os.path.join(OUT_DIR, old))
    sheets = {}
    for anim, spec in CFG["animations"].items():
        frames = [f.image() for f in BUILDERS[anim](spec["frames"])]
        assert len(frames) == spec["frames"], anim
        sheets[anim] = frames
        for i, im in enumerate(frames):
            im.save(os.path.join(OUT_DIR, f"{PREFIX}_{anim}_{i:02d}.png"))
    preview(sheets).save(os.path.join(OUT_DIR, "_bubble_preview.png"))
    print(f"gen_alert_bubble: {sum(len(v) for v in sheets.values())} cuadros en {OUT_DIR}")


if __name__ == "__main__":
    main()
