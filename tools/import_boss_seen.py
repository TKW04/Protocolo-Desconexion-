#!/usr/bin/env python3
"""Arte final de El Visto (paso 24 de docs/propuesta-mundo-4.md, etapa 2; plan y
gasto en docs/plan-arte-mundo-4.md, ejecutado el 2026-10-28).

Rehace los cuadros del doble check desde las hojas de AutoSprite guardadas en
hojas/seen/<anim>/spritesheet.png (5 x 5 cuadros de 512, reducidas de 1024):

  1. En cada animacion, la celda de referencia (la primera de CELLS, la base:
     todas las animaciones empiezan en ella) da la caja de lo opaco (los dos
     checks y el check gris de debajo). Esa caja pasa a la rejilla de arte con
     la MISMA escala en x e y (fit "height", centrada en x): BODY_ART pixeles de
     arte con MARGIN_ART de margen para el temblor, el barrido y las estrellas.
     Todas las celdas de la animacion usan la misma transformacion.
  2. Cada celda se reduce (media por caja, alfa premultiplicado), el alfa se
     umbraliza y pasa a mundo4.gpl sin los rojos, los ambares ni el coral del
     Debug (EXCLUDE: rojo = dano y punto debil; el coral, solo el Debug) ni los
     marinos medios (el gris azulado del check «sin leer» caeria en marino_luz,
     que es fondo). El borde de la silueta va a chat_noche (contorno oscuro).
  3. Se amplia x GRID sin filtro.

Dos juegos (SPECS):
  - BODY: el cuerpo de 6 x 3 tiles (data/bosses/seen.json, arena.body = 384 x
    192). El doble check mide 288 x 208 (72 x 52 de arte, rejilla 4) en un lienzo
    de 336 x 256 que el juego coloca en BODY_OFFSET_PX de la esquina de la caja
    (Seen.ART_BODY_OFFSET): el check gris cae centrado en x y a la altura de
    perch_core_px (192, 160) y el lienzo sube 48 px sobre la caja (24 de ellos,
    los checks: la barra del jefe va a la derecha y no los tapa).
  - SILHOUETTE: la silueta de la fase 1 (96 x 96 centrada en el punto debil):
    el mismo doble check a 96 px de ancho (48 de arte, rejilla 2), con el check
    gris en el punto debil (Seen.ART_SILHOUETTE_OFFSET).

El halo opaco del base se quito antes de subirlo (upload_character «El Visto
(sin halo)»): el aura es de SeenFx, translucida, por codigo.

Salida: assets/sprites/bosses/seen_<anim>_<NN>.png (cuerpo) y
seen_small_<anim>_<NN>.png (silueta). Las animaciones y celdas estan en ANIMS
(los fps y cuando suena cada una, en Seen.ART_ANIMS).

Uso:
    python3 -I tools/import_boss_seen.py           # rehace los PNG
    python3 -I tools/import_boss_seen.py --check   # comprueba que estan al dia
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
from import_boss_curator import ALPHA_CUT, Spec, cell_image, opaque_box, parse_cells, source_rect, to_art  # noqa: E402

GPL = os.path.join(ROOT, "assets", "palettes", "mundo4.gpl")
## Rojos (dano, punto debil), ambares (puntos de atencion), el coral del Debug,
## los marinos medios (fondo), las cremas (burbujas) y los verdes (el «Visto»
## de las zonas) fuera: El Visto es solo la rampa de grises y el blanco. Sin
## esto el humo gris azulado caia en crema y la derrota gris en verde_apagado.
EXCLUDE = ["alerta", "alerta_sombra", "ambar", "ambar_sombra", "debug_coral", "marino_medio", "marino_luz",
           "crema", "crema_sombra", "verde_apagado", "verde_sombra"]
## Excepcion: el brillo del escudo es crema (como arena.shield_color).
ALLOW_EXTRA = {"shield": ["crema", "crema_sombra"]}
FORBIDDEN = ["alerta", "alerta_sombra", "debug_coral"]
SHEETS = os.path.join(ROOT, "hojas", "seen")
OUT = os.path.join(ROOT, "assets", "sprites", "bosses")

## anim: celdas (la referencia es la primera, o la de REF). El cuerpo y la
## silueta usan las mismas celdas (SMALL_ANIMS: las que dibuja la silueta).
ANIMS = {}  # se rellena abajo
SMALL_ANIMS = ["reappear", "charge"]
## charge: la referencia es la base (celda 0) aunque no se use.
REF = {"charge": 0}

BODY = Spec(sheets=SHEETS, out=OUT, prefix="seen", anims=ANIMS, body_art=(72, 52), margin_art=6, grid=4, fit="height")
SILHOUETTE = Spec(sheets=SHEETS, out=OUT, prefix="seen_small", anims={}, body_art=(48, 35), margin_art=4, grid=2, fit="height")
## Esquina del lienzo respecto a la esquina de arriba a la izquierda de la caja
## (cuerpo) y respecto al punto debil (silueta), en px del juego. Los copia
## Seen.ART_BODY_OFFSET / ART_SILHOUETTE_OFFSET (tests/test_import_boss_seen.py).
BODY_OFFSET_PX = (24, -48)
SILHOUETTE_OFFSET_PX = (-56, -70)


def _set_anims():
    ANIMS.update({
        # Reposo: flota y el check gris late; bucle (sin la 24, = la 0).
        "idle": "0-23",
        # Fase 1: se esfuma (sin la 6, un destello oscuro; la ultima, vacia, no
        # hace falta: el codigo lo oculta).
        "vanish": "0-5,7-23",
        # Fase 1: aparece detras de Isak (la silueta) y vuelve arriba (el cuerpo).
        "reappear": "0-24",
        # Fase 1: embiste (silueta; reflejado si va hacia la izquierda), en
        # bucle: sin las 8-11, en las que la estela tapa media celda.
        "charge": "3-7,12-14",
        # Fase 2: escudo levantado; bucle.
        "shield": "0-23",
        # Fase 3: «escribiendo…»; bucle.
        "typing": "0-23",
        # Ventanas de las fases 2 y 3 (en el suelo / aturdido); bucle.
        "stunned": "0-23",
        # Golpe final: grietas y se apaga en gris (se queda en la ultima).
        "defeat": "0-24",
    })
    SILHOUETTE.anims.update({k: ANIMS[k] for k in SMALL_ANIMS})


_set_anims()


## Rotulos que la IA pinto debajo del check gris (cajitas «Read receipt», una
## barra de texto, un bocadillo): [x0, y0, x1, y1] en px de la celda de 1024 y
## modo. "comp" borra las manchas opacas que caben enteras en el rectangulo (el
## check gris o las estrellas que lo tocan se quedan); "clear" borra todo lo
## que cae dentro; "light" borra lo claro (la barra de texto de typing toca la
## punta del check gris, que es oscuro).
CLEANUP = {
    "idle": [(404, 590, 528, 694, "comp")],
    "vanish": [(416, 836, 604, 944, "comp")],
    "reappear": [(420, 812, 560, 924, "comp")],
    "shield": [(416, 804, 596, 936, "comp")],
    "typing": [(372, 800, 644, 944, "light"), (372, 826, 644, 944, "clear")],
    "stunned": [(432, 812, 612, 936, "comp")],
}


def _components_inside(alpha, rect):
    """Manchas opacas (4-vecinos) de `alpha` que caben enteras en `rect`."""
    x0, y0, x1, y1 = rect
    w, h = alpha.size
    px = alpha.load()
    seen = set()
    out = []
    for sy in range(max(y0, 0), min(y1, h)):
        for sx in range(max(x0, 0), min(x1, w)):
            if px[sx, sy] < ALPHA_CUT or (sx, sy) in seen:
                continue
            stack = [(sx, sy)]
            seen.add((sx, sy))
            pts = []
            inside = True
            while stack:
                x, y = stack.pop()
                pts.append((x, y))
                if not (x0 <= x < x1 and y0 <= y < y1):
                    inside = False
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] >= ALPHA_CUT:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if inside:
                out.extend(pts)
    return out


def clean_cell(anim, cell):
    """Quita los rotulos de CLEANUP (coordenadas de 1024, escaladas a la celda)."""
    rects = CLEANUP.get(anim, [])
    if not rects:
        return cell
    k = cell.width / 1024.0
    cell = cell.copy()
    px = cell.load()
    for x0, y0, x1, y1, mode in rects:
        r = (int(x0 * k), int(y0 * k), int(x1 * k), int(y1 * k))
        if mode in ("clear", "light"):
            for y in range(r[1], r[3]):
                for x in range(r[0], r[2]):
                    p = px[x, y]
                    if mode == "clear" or 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2] > 150:
                        px[x, y] = (0, 0, 0, 0)
        else:
            for x, y in _components_inside(cell.getchannel("A"), r):
                px[x, y] = (0, 0, 0, 0)
    return cell


def reduce_art(art, allowed, rgb):
    """Paleta y contorno oscuro (chat_noche) en el borde de la silueta."""
    night = rgb["chat_noche"] + (255,)
    out = reduce_palette.reduce_image(art, allowed)
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
        px[x, y] = night
    return out


def allowed_colors(anim):
    exclude = [n for n in EXCLUDE if n not in ALLOW_EXTRA.get(anim, [])]
    return reduce_palette.select_colors(reduce_palette.load_gpl(GPL), exclude=exclude)


def build(spec, out_dir):
    files = []
    allowed_by_file = {}
    for anim, cells_spec in spec.anims.items():
        allowed = allowed_colors(anim)
        rgb = dict(allowed)
        sheet = Image.open(os.path.join(spec.sheets, anim, "spritesheet.png")).convert("RGBA")
        cells = parse_cells(cells_spec)
        ref = REF.get(anim, cells[0])
        src = source_rect(spec, opaque_box(clean_cell(anim, cell_image(sheet, ref))))
        for i, c in enumerate(cells):
            art = reduce_art(to_art(spec, clean_cell(anim, cell_image(sheet, c)), src), allowed, rgb)
            img = art.resize(spec.canvas, Image.NEAREST)
            name = f"{spec.prefix}_{anim}_{i:02d}.png"
            img.save(os.path.join(out_dir, name))
            files.append(name)
            allowed_by_file[name] = allowed
    return files, allowed_by_file


def check(specs, label):
    bad = []
    total = 0
    full = reduce_palette.load_gpl(GPL)
    forbidden = {tuple(c) for n, c in full if n in FORBIDDEN}
    for spec in specs:
        with tempfile.TemporaryDirectory() as tmp:
            files, allowed = build(spec, tmp)
            total += len(files)
            for f in files:
                mine, theirs = os.path.join(spec.out, f), os.path.join(tmp, f)
                if not os.path.exists(mine):
                    bad.append(f"{f}: falta")
                    continue
                a, b = Image.open(mine).convert("RGBA"), Image.open(theirs).convert("RGBA")
                if a.size != b.size or a.tobytes() != b.tobytes():
                    bad.append(f"{f}: no esta al dia")
                errs = reduce_palette.check_image(a, allowed[f])
                if errs:
                    bad.append(f"{f}: {'; '.join(errs)}")
                if any(p[3] and p[:3] in forbidden for p in a.getdata()):
                    bad.append(f"{f}: rojo o coral (reservados al dano y al Debug)")
                w, h = a.size
                if any(a.getpixel(c)[3] for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
                    bad.append(f"{f}: esquinas opacas")
    for b in bad:
        print(b)
    print(f"{'FALLO' if bad else 'OK'}: {total} cuadros de {label}")
    return 1 if bad else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Arte final de El Visto (AutoSprite)")
    ap.add_argument("--check", action="store_true", help="comprueba que los PNG estan al dia y en la paleta")
    args = ap.parse_args(argv)
    specs = [BODY, SILHOUETTE]
    if args.check:
        return check(specs, "El Visto")
    n = 0
    for spec in specs:
        files, _ = build(spec, spec.out)
        n += len(files)
    print(f"Escritos {n} cuadros de El Visto en {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
