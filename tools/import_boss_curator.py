#!/usr/bin/env python3
"""Arte final de La Curadora (paso 23 de docs/propuesta-mundo-3.md; plan y gasto
en docs/plan-arte-mundo-3.md, ejecutado el 2026-10-27).

Rehace los cuadros del marco del jefe desde las hojas de AutoSprite guardadas en
hojas/curator/<anim>/spritesheet.png (5 x 5 cuadros de 512, reducidas de 1024):

  1. En cada animacion, la celda de referencia (la primera de CELLS, la pose de
     partida) da la caja de lo opaco: esa caja pasa a BODY_ART (128 x 73
     pixeles de arte: el marco con la camara, la rejilla nativa del base
     estirado de hojas/curator/base_frame_native.png) con MARGIN_ART de margen
     para el temblor de la derrota, el giro y los destellos. Todas las celdas
     de la animacion usan la misma transformacion (respeta el movimiento).
  2. Cada celda se reduce a esa rejilla (media por caja, alfa premultiplicado),
     el alfa se umbraliza y pasa a mundo3.gpl sin los rojos, los ambares ni el
     Debug (EXCLUDE): rojo = dano y punto debil (la pantalla rota la dibuja
     WeakPoint). Los mofletes salmon de la IA van a corazon_rosa (CHEEK, nunca
     alerta) y el borde de la silueta a galeria_noche (contorno oscuro).
  3. Se amplia x GRID (4) sin filtro: el marco mide 512 x 292 en un lienzo de
     CANVAS (576 x 356). El juego lo coloca MARGIN_PX a la izquierda de la caja
     `frame` (8 x 4 tiles de data/bosses/curator.json) y TOP_PX + MARGIN_PX
     por encima, para que la lente caiga en lens_px (256, 24) y el borde de
     abajo del marco en el de la caja (scripts/bosses/curator.gd, ART_*).

Salida: assets/sprites/bosses/curator_<anim>_<NN>.png. Las animaciones y las
celdas estan en ANIMS (los fps y cuando suena cada una, en Curator.ART_ANIMS).
Los biombos, las fichas del album y los avisos siguen por script
(tools/gen_boss_curator.py; sus *_placeholder.png quedan de respaldo).

Uso:
    python3 -I tools/import_boss_curator.py           # rehace los PNG
    python3 -I tools/import_boss_curator.py --check   # comprueba que estan al dia
"""

import argparse
import os
import site
import sys
import tempfile

sys.path.append(site.getusersitepackages())
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image  # noqa: E402
import reduce_palette  # noqa: E402

GPL = os.path.join(ROOT, "assets", "palettes", "mundo3.gpl")
## Rojos (dano, punto debil), ambares (atencion) y el verde del Debug fuera.
EXCLUDE = ["alerta", "alerta_sombra", "ambar", "ambar_sombra", "debug_verde"]
ALPHA_CUT = 128
COLS = ROWS = 5


def is_cheek(rgb):
    """Salmon / rosa calido de los mofletes y la boca de la IA (va a corazon_rosa)."""
    r, g, b = rgb[:3]
    return r > 200 and r - g > 40 and 130 < b < 200


class Spec:
    """Como importar las hojas de un personaje (ver el docstring del modulo)."""

    def __init__(self, sheets, out, prefix, anims, body_art, margin_art, grid, fit="box"):
        self.sheets = sheets
        self.out = out
        self.prefix = prefix
        self.anims = anims
        self.body_art = body_art
        self.margin_art = margin_art
        self.grid = grid
        # "box": la caja de referencia llena body_art (puede cambiar la proporcion);
        # "height": misma escala en x e y, alto = body_art[1], centrado y con los pies abajo.
        self.fit = fit

    @property
    def canvas_art(self):
        return (self.body_art[0] + 2 * self.margin_art, self.body_art[1] + 2 * self.margin_art)

    @property
    def canvas(self):
        c = self.canvas_art
        return (c[0] * self.grid, c[1] * self.grid)


CURATOR = Spec(
    sheets=os.path.join(ROOT, "hojas", "curator"),
    out=os.path.join(ROOT, "assets", "sprites", "bosses"),
    prefix="curator",
    ## anim: celdas (la primera es la referencia).
    anims={
        # Bucle en reposo; sin las celdas 6-10 (un destello de la lente que se
        # confundiria con el aviso del flash) y sin la 24 (= la 0).
        "idle": "0-5,11-23",
        # Aviso del flash (9 cuadros = flash.warn_frames): baja la lente y carga.
        "flash": "0,3,6,9,12,15,18,21,24",
        # Ventana (baja a encuadrar): enfoca, en bucle.
        "frame_down": "0-23",
        # Fase 2: se da la vuelta (y al revés al empezar la fase 3).
        "turn": "0,2,4,6,8,10,12,14,16,18,20,22,24",
        # Fase 3 «Retrato perfecto»: el filtro posa, en bucle.
        "x_reflection": "0-23",
        # Golpe final: glitch, grietas y se apaga en gris.
        "defeat": "0,2,4,6,8,10,12,14,16,18,20,22,24",
    },
    body_art=(128, 73),
    margin_art=8,
    grid=4,
)
## La lente del base queda en la fila ~16 de la rejilla nativa (64 px): el
## lienzo sube TOP_PX sobre la caja para que caiga en lens_px.y = 24.
TOP_PX = 40


def parse_cells(spec):
    out = []
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return out


def cell_image(sheet, index):
    cw, ch = sheet.width // COLS, sheet.height // ROWS
    x, y = (index % COLS) * cw, (index // COLS) * ch
    return sheet.crop((x, y, x + cw, y + ch))


def opaque_box(img):
    alpha = img.getchannel("A").point(lambda a: 255 if a >= ALPHA_CUT else 0)
    box = alpha.getbbox()
    if box is None:
        raise SystemExit("celda de referencia vacia")
    return box


def source_rect(spec, box):
    """Rectangulo de la celda que cae en el lienzo de arte (margen incluido)."""
    x0, y0, x1, y1 = box
    bw, bh = spec.body_art
    m = spec.margin_art
    if spec.fit == "box":
        sx, sy = (x1 - x0) / bw, (y1 - y0) / bh
        return (x0 - m * sx, y0 - m * sy, x0 + (bw + m) * sx, y0 + (bh + m) * sy)
    s = (y1 - y0) / bh
    cx = (x0 + x1) / 2
    half = (bw / 2 + m) * s
    return (cx - half, y0 - m * s, cx + half, y1 + m * s)


def to_art(spec, cell, src):
    # Con margen transparente alrededor: la caja puede salirse de la celda.
    pad = max(cell.size)
    big = Image.new("RGBA", (cell.width + 2 * pad, cell.height + 2 * pad), (0, 0, 0, 0))
    big.paste(cell, (pad, pad))
    src = (src[0] + pad, src[1] + pad, src[2] + pad, src[3] + pad)
    pre = big.convert("RGBa")
    small = pre.resize(spec.canvas_art, Image.BOX, box=src).convert("RGBA")
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            p = px[x, y]
            px[x, y] = (p[0], p[1], p[2], 255) if p[3] >= ALPHA_CUT else (0, 0, 0, 0)
    return small


def reduce_art(art, allowed, rgb):
    """Paleta (mofletes a corazon_rosa) y contorno oscuro en el borde de la silueta."""
    cheek = rgb["corazon_rosa"] + (255,)
    night = rgb["galeria_noche"] + (255,)
    src = art.load()
    out = reduce_palette.reduce_image(art, allowed)
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] and is_cheek(src[x, y]):
                px[x, y] = cheek
    edge = []
    for y in range(h):
        for x in range(w):
            if not px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not px[nx, ny][3]:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = night
    return out


def build(spec, out_dir):
    allowed = reduce_palette.select_colors(reduce_palette.load_gpl(GPL), exclude=EXCLUDE)
    rgb = dict(allowed)
    files = []
    for anim, cells_spec in spec.anims.items():
        sheet = Image.open(os.path.join(spec.sheets, anim, "spritesheet.png")).convert("RGBA")
        cells = parse_cells(cells_spec)
        src = source_rect(spec, opaque_box(cell_image(sheet, cells[0])))
        for i, c in enumerate(cells):
            art = reduce_art(to_art(spec, cell_image(sheet, c), src), allowed, rgb)
            img = art.resize(spec.canvas, Image.NEAREST)
            name = f"{spec.prefix}_{anim}_{i:02d}.png"
            img.save(os.path.join(out_dir, name))
            files.append(name)
    return files, allowed


def check(spec, label):
    bad = []
    with tempfile.TemporaryDirectory() as tmp:
        files, allowed = build(spec, tmp)
        for f in files:
            mine, theirs = os.path.join(spec.out, f), os.path.join(tmp, f)
            if not os.path.exists(mine):
                bad.append(f"{f}: falta")
                continue
            a, b = Image.open(mine).convert("RGBA"), Image.open(theirs).convert("RGBA")
            if a.size != b.size or a.tobytes() != b.tobytes():
                bad.append(f"{f}: no esta al dia")
            errs = reduce_palette.check_image(a, allowed)
            if errs:
                bad.append(f"{f}: {'; '.join(errs)}")
            w, h = a.size
            if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                bad.append(f"{f}: esquinas opacas")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {len(files)} cuadros de {label}")
    return 1 if bad else 0


def main(spec, label, argv=None):
    ap = argparse.ArgumentParser(description=f"Arte final de {label} (AutoSprite)")
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    if args.check:
        return check(spec, label)
    files, _ = build(spec, spec.out)
    print(f"Escritos {len(files)} cuadros de {label} en {os.path.relpath(spec.out, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(CURATOR, "La Curadora"))
