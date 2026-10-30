#!/usr/bin/env python3
"""Arte final de El Vendedor (paso 24 de docs/propuesta-mundo-5.md, etapa 2; plan y
gasto en docs/plan-arte-mundo-5.md, ejecutado el 2026-10-30).

Rehace los cuadros de la maquina desde las hojas de AutoSprite guardadas en
hojas/vendor/<anim>/spritesheet.png (5 x 5 cuadros de 512):

  1. En cada animacion, la celda de referencia (la primera de CELLS: la pose de la
     que sale) da la caja del CUERPO de la maquina (las columnas casi enteras de
     opaco; los brazos, que solo ocupan unas filas, quedan fuera). Esa caja llena
     BODY_ART pixeles de arte (fit "box": se estira en x para pasar de la
     proporcion ~0,6:1 del dibujo a la de la caja de 4 x 5 tiles, 0,8:1; los
     brazos se estiran con ella) con MARGIN_ART de margen (los brazos, a los
     lados). Todas las celdas de la animacion usan la misma transformacion.
  2. Cada celda se reduce (media por caja, alfa premultiplicado), el alfa se
     umbraliza y pasa a mundo5.gpl sin los rojos (dano y el «Cancelar»), los
     ambares (puntos de atencion) ni el blanco del Debug (EXCLUDE); los pixeles
     sueltos se quitan (despeckle). El cuerpo cae en gris_escaparate y la
     pantalla en negro_medio (aclarar antes de reducir las juntaba en el mismo
     gris con ruido). Para que la silueta no se funda con el fondo oscuro de la
     arena (leccion del Troll en el 4-1) el borde va a EDGE (violeta neon:
     «violet neon trim» del prompt), que se lee sobre el negro y el gris del
     gran almacen.
  3. Se amplia x GRID sin filtro.

La maquina SIEMPRE mira a un lado (Vendor.get_facing): las hojas miran a la
DERECHA (idle, turn, throw) o de frente (processing, offer, defeat); el juego las
refleja cuando mira a la izquierda (turn, de derecha a izquierda: reflejada va de
izquierda a derecha). No hay arte de espaldas: la espalda la marca el «Cancelar»
(WeakPoint, por codigo).

Lienzo de CANVAS px colocado en BODY_OFFSET_PX de la esquina de la caja
(Vendor.ART_BODY_OFFSET). Salida: assets/sprites/bosses/vendor/vendor_<anim>_<NN>.png.
Las animaciones y celdas estan en ANIMS (los fps y cuando suena cada una, en
Vendor.ART_ANIMS).

Uso:
    python3 -I tools/import_boss_vendor.py           # rehace los PNG
    python3 -I tools/import_boss_vendor.py --check   # comprueba que estan al dia
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
from import_boss_curator import ALPHA_CUT, cell_image, parse_cells  # noqa: E402

GPL = os.path.join(ROOT, "assets", "palettes", "mundo5.gpl")
## Rojos (dano, el «Cancelar»), ambares (puntos de atencion) y el blanco del Debug fuera.
EXCLUDE = ["alerta", "alerta_sombra", "ambar", "ambar_sombra", "debug_blanco"]
FORBIDDEN = EXCLUDE
EDGE = "violeta_neon"
SHEETS = os.path.join(ROOT, "hojas", "vendor")
OUT = os.path.join(ROOT, "assets", "sprites", "bosses", "vendor")
PREFIX = "vendor"

## Cuerpo: 64 x 80 pixeles de arte a rejilla 4 = la caja de 4 x 5 tiles (256 x 320).
BODY_ART = (64, 80)
## Margen en pixeles de arte (x: los brazos a los lados; y: el balanceo).
MARGIN_ART = (32, 6)
GRID = 4
CANVAS_ART = (BODY_ART[0] + 2 * MARGIN_ART[0], BODY_ART[1] + 2 * MARGIN_ART[1])
CANVAS = (CANVAS_ART[0] * GRID, CANVAS_ART[1] * GRID)
## Esquina del lienzo respecto a la de la caja (px del juego); la copia
## Vendor.ART_BODY_OFFSET (tests/test_import_boss_vendor.py).
BODY_OFFSET_PX = (-MARGIN_ART[0] * GRID, -MARGIN_ART[1] * GRID)
## Columna del cuerpo: opaca en al menos esta fraccion del alto de lo opaco.
BODY_COLUMN = 0.7

## anim: celdas (la referencia es la primera).
ANIMS = {
    # Reposo mirando a Isak (la hoja mira a la derecha); bucle (sin la 24, = la 0).
    "idle": "0-23",
    # Giro (aviso de turn.warn_frames + turn.anim_s): de derecha a izquierda.
    "turn": "0-24",
    # Fase 2: lanza una tanda de cajas (una vez).
    "throw": "0-24",
    # «Procesando devolucion…» / «Procesando pago…»; bucle.
    "processing": "0-23",
    # Ofrece (paga una plataforma, empieza una oferta); bucle.
    "offer": "0-23",
    # Golpe final: se apaga y se queda en la ultima.
    "defeat": "0-24",
}


def body_box(cell):
    """Caja del cuerpo en la celda: el tramo mas ancho de columnas casi enteras."""
    alpha = cell.getchannel("A").point(lambda a: 255 if a >= ALPHA_CUT else 0)
    box = alpha.getbbox()
    if box is None:
        raise SystemExit("celda de referencia vacia")
    px = alpha.load()
    w, h = alpha.size
    tall = box[3] - box[1]
    cols = [x for x in range(w) if sum(1 for y in range(h) if px[x, y]) >= BODY_COLUMN * tall]
    runs = []
    for x in cols:
        if runs and x == runs[-1][1] + 1:
            runs[-1][1] = x
        else:
            runs.append([x, x])
    x0, x1 = max(runs, key=lambda r: r[1] - r[0])
    ys = [y for y in range(h) for x in range(x0, x1 + 1, 4) if px[x, y]]
    return (x0, min(ys), x1 + 1, max(ys) + 1)


def source_rect(box):
    x0, y0, x1, y1 = box
    sx, sy = (x1 - x0) / BODY_ART[0], (y1 - y0) / BODY_ART[1]
    mx, my = MARGIN_ART
    return (x0 - mx * sx, y0 - my * sy, x1 + mx * sx, y1 + my * sy)


def to_art(cell, src):
    pad = max(cell.size)
    big = Image.new("RGBA", (cell.width + 2 * pad, cell.height + 2 * pad), (0, 0, 0, 0))
    big.paste(cell, (pad, pad))
    src = (src[0] + pad, src[1] + pad, src[2] + pad, src[3] + pad)
    small = big.convert("RGBa").resize(CANVAS_ART, Image.BOX, box=src).convert("RGBA")
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            p = px[x, y]
            if p[3] >= ALPHA_CUT:
                px[x, y] = (p[0], p[1], p[2], 255)
            else:
                px[x, y] = (0, 0, 0, 0)
    return small


def despeckle(img):
    """Quita los pixeles sueltos: uno opaco cuyos 4 vecinos opacos son todos de otro
    mismo color pasa a ese color (el ruido de la pantalla y del cuerpo al reducir)."""
    px = img.load()
    w, h = img.size
    changes = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            p = px[x, y]
            if not p[3]:
                continue
            n = [px[x + 1, y], px[x - 1, y], px[x, y + 1], px[x, y - 1]]
            if all(q[3] for q in n) and all(q == n[0] for q in n) and n[0] != p:
                changes.append((x, y, n[0]))
    for x, y, q in changes:
        px[x, y] = q
    return img


def reduce_art(art, allowed, rgb):
    """Paleta, sin pixeles sueltos, y borde de la silueta en EDGE."""
    edge_color = rgb[EDGE] + (255,)
    out = despeckle(reduce_palette.reduce_image(art, allowed))
    px = out.load()
    w, h = out.size
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
        px[x, y] = edge_color
    return out


def allowed_colors():
    return reduce_palette.select_colors(reduce_palette.load_gpl(GPL), exclude=EXCLUDE)


def build(out_dir):
    allowed = allowed_colors()
    rgb = dict(allowed)
    files = []
    os.makedirs(out_dir, exist_ok=True)
    for anim, cells_spec in ANIMS.items():
        sheet = Image.open(os.path.join(SHEETS, anim, "spritesheet.png")).convert("RGBA")
        cells = parse_cells(cells_spec)
        src = source_rect(body_box(cell_image(sheet, cells[0])))
        for i, c in enumerate(cells):
            art = reduce_art(to_art(cell_image(sheet, c), src), allowed, rgb)
            name = f"{PREFIX}_{anim}_{i:02d}.png"
            art.resize(CANVAS, Image.NEAREST).save(os.path.join(out_dir, name))
            files.append(name)
    return files, allowed


def check():
    bad = []
    full = reduce_palette.load_gpl(GPL)
    forbidden = {tuple(c) for n, c in full if n in FORBIDDEN}
    with tempfile.TemporaryDirectory() as tmp:
        files, allowed = build(tmp)
        for f in files:
            mine, theirs = os.path.join(OUT, f), os.path.join(tmp, f)
            if not os.path.exists(mine):
                bad.append(f"{f}: falta")
                continue
            a, b = Image.open(mine).convert("RGBA"), Image.open(theirs).convert("RGBA")
            if a.size != b.size or a.tobytes() != b.tobytes():
                bad.append(f"{f}: no esta al dia")
            errs = reduce_palette.check_image(a, allowed)
            if errs:
                bad.append(f"{f}: {'; '.join(errs)}")
            if any(p[3] and p[:3] in forbidden for p in a.getdata()):
                bad.append(f"{f}: rojo, ambar o el blanco del Debug (reservados)")
            w, h = a.size
            if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                bad.append(f"{f}: esquinas opacas")
        extra = sorted(f for f in os.listdir(OUT) if f.endswith(".png") and f not in files) if os.path.isdir(OUT) else []
        for f in extra:
            bad.append(f"{f}: sobra")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {len(files)} cuadros de El Vendedor")
    return 1 if bad else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Arte final de El Vendedor (AutoSprite)")
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    if args.check:
        return check()
    files, _ = build(OUT)
    print(f"Escritos {len(files)} cuadros de El Vendedor en {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
