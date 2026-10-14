#!/usr/bin/env python3
"""Importa una hoja de sprites de Isak generada con IA y la convierte en cuadros
listos para el juego.

Pasos (ver docs/guia-sprites-ia.md):
  1. Corta la hoja en una rejilla de N columnas x M filas (o la autodetecta
     buscando bandas vacias entre personajes).
  2. Quita el fondo: usa la transparencia si la hoja ya la trae; si no, el
     color dominante del borde de cada celda, con tolerancia (relleno desde el
     borde y luego los huecos cerrados con tolerancia mas estricta).
  3. Quita la sombra eliptica del suelo: detecta el color gris de la parte de
     abajo del personaje y lo borra por relleno, solo en la franja de los pies.
     Las botas se conservan porque su contorno oscuro corta el relleno.
  4. Umbral de alfa: cada pixel queda con alfa 0 o 255.
  5. Escala con vecino mas cercano (NEAREST) con UN SOLO factor para toda la
     hoja, calculado para que la altura visible del cuadro de referencia sea
     --target-height (96 px).
  6. Coloca cada cuadro en un canvas de --canvas (128x128) con los pies en la
     ultima fila y centrados. Por defecto (--align sheet) usa el mismo
     desplazamiento para todos los cuadros, medido en el cuadro de referencia,
     asi el movimiento relativo de la hoja se conserva y no se introduce
     temblor. Con --align feet cada cuadro se ancla por sus propios pies.
  7. Valida cada salida y guarda <prefix>_<anim>_<NN>.png.

Uso:
  python3 tools/import_sheet.py HOJA.png --anim idle [--cols 6 --rows 6]
      [--frames 36] [--target-height 96] [--canvas 128]
      [--out assets/sprites/isak] [--prefix isak] [--dry-run]
      [--preview vista.png]

Devuelve 0 si todos los cuadros son validos y 1 si alguno falla (2 si los
argumentos o la hoja no sirven).
"""

import argparse
import os
import sys
from collections import Counter, deque

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# --- utilidades de color --------------------------------------------------------
def color_dist(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]))


def saturation(c):
    return max(c[:3]) - min(c[:3])


def lightness(c):
    return (max(c[:3]) + min(c[:3])) // 2


# --- rejilla --------------------------------------------------------------------
def content_mask_fn(sheet):
    """Devuelve una funcion (x, y) -> bool de 'hay contenido' para autodetectar."""
    px = sheet.load()
    w, h = sheet.size
    if has_transparency(sheet):
        return lambda x, y: px[x, y][3] > 16
    border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)]
    bg = Counter(c[:3] for c in border).most_common(1)[0][0]
    return lambda x, y: color_dist(px[x, y], bg) > 40


def runs(flags):
    out, start = [], None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(flags)))
    return out


def autodetect_grid(sheet):
    w, h = sheet.size
    has = content_mask_fn(sheet)
    step = 2
    colf = [any(has(x, y) for y in range(0, h, step)) for x in range(w)]
    rowf = [any(has(x, y) for x in range(0, w, step)) for y in range(h)]
    # ignora bandas diminutas (ruido) al contar
    cols = [r for r in runs(colf) if r[1] - r[0] > w * 0.01]
    rows = [r for r in runs(rowf) if r[1] - r[0] > h * 0.01]
    return len(cols), len(rows)


def has_transparency(img):
    if img.mode != "RGBA":
        return False
    a = img.getchannel("A")
    hist = a.histogram()
    return hist[0] > (img.size[0] * img.size[1]) * 0.05


# --- limpieza de una celda ------------------------------------------------------
def flood(px, w, h, seeds, accept):
    seen = bytearray(w * h)
    q = deque()
    for (x, y) in seeds:
        if 0 <= x < w and 0 <= y < h and not seen[y * w + x] and accept(x, y):
            seen[y * w + x] = 1
            q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and accept(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))
    return seen


def remove_background(cell, transparent_sheet, tol):
    img = cell.copy()
    px = img.load()
    w, h = img.size
    if transparent_sheet:
        return img
    border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)]
    border += [px[0, y] for y in range(h)] + [px[w - 1, y] for y in range(h)]
    bg = Counter(c[:3] for c in border).most_common(1)[0][0]
    seeds = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    seeds += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    seen = flood(px, w, h, seeds, lambda x, y: color_dist(px[x, y], bg) <= tol)
    tight = max(4, tol // 2)
    for y in range(h):
        for x in range(w):
            if seen[y * w + x] or color_dist(px[x, y], bg) <= tight:
                px[x, y] = (0, 0, 0, 0)
    remove_fringe(img, bg, tol)
    return img


def remove_fringe(img, bg, tol, passes=2):
    """Quita el halo de borde mezclado con el fondo (antialias). Solo mira
    pixeles opacos que tocan un transparente. Con fondo de color (magenta,
    verde) borra los que estan tenidos hacia el tono del fondo; con fondo gris
    o blanco, los que se parecen al fondo con tolerancia doble."""
    px = img.load()
    w, h = img.size
    m = sum(bg) / 3.0
    v = (bg[0] - m, bg[1] - m, bg[2] - m)
    vn = (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) ** 0.5
    for _ in range(passes):
        kill = []
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                if not c[3]:
                    continue
                if vn > 60:
                    pm = sum(c[:3]) / 3.0
                    proj = ((c[0] - pm) * v[0] + (c[1] - pm) * v[1] + (c[2] - pm) * v[2]) / vn
                    if proj > 110:  # muy tenido del fondo: hueco interior, aunque no sea borde
                        kill.append((x, y))
                        continue
                edge = any(not (0 <= nx < w and 0 <= ny < h) or not px[nx, ny][3]
                           for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
                if not edge:
                    continue
                if vn > 60:
                    pm = sum(c[:3]) / 3.0
                    proj = ((c[0] - pm) * v[0] + (c[1] - pm) * v[1] + (c[2] - pm) * v[2]) / vn
                    if proj > 40:
                        kill.append((x, y))
                elif color_dist(c, bg) <= tol * 2:
                    kill.append((x, y))
        if not kill:
            break
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)


def threshold_alpha(img, cut):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= cut else (0, 0, 0, 0)


def bbox_alpha(img, cut=1):
    return img.getchannel("A").point(lambda v: 255 if v >= cut else 0).getbbox()


def detect_shadow_color(cells, max_sat, min_light):
    """Busca el color de la sombra en la fila mas baja de cada celda. La sombra
    eliptica asoma por debajo y a los lados de las botas, asi que la fila mas
    baja del contenido es casi toda sombra. Devuelve None si no parece sombra."""
    samples = []
    for cell in cells:
        bb = bbox_alpha(cell, 128)
        if not bb:
            continue
        px = cell.load()
        for y in range(bb[3] - 3, bb[3]):
            for x in range(bb[0], bb[2]):
                c = px[x, y]
                if c[3] >= 128:
                    samples.append(c)
    if not samples:
        return None
    quant = Counter((c[0] // 8, c[1] // 8, c[2] // 8) for c in samples)
    (qr, qg, qb), n = quant.most_common(1)[0]
    cand = [c for c in samples if (c[0] // 8, c[1] // 8, c[2] // 8) == (qr, qg, qb)]
    mean = tuple(sum(c[i] for c in cand) // len(cand) for i in range(3))
    share = sum(1 for c in samples if color_dist(c, mean) <= 24) / len(samples)
    # sombra = gris (poca saturacion), clara o semitransparente, y dominante abajo
    if saturation(mean) <= max_sat and lightness(mean) >= min_light and share >= 0.5:
        return mean
    return None


def remove_shadow(img, shadow, tol, band_frac):
    """Borra por relleno los pixeles del color de la sombra conectados con la
    parte baja del cuadro, solo dentro de la franja de los pies."""
    px = img.load()
    w, h = img.size
    bb = bbox_alpha(img, 1)
    if not bb:
        return 0
    top, bottom = bb[1], bb[3]
    band_top = bottom - int((bottom - top) * band_frac)

    def is_shadow(x, y):
        c = px[x, y]
        if y < band_top or c[3] == 0:
            return False
        if color_dist(c, shadow) <= tol:
            return True
        # bordes antialias de la sombra: semitransparentes y grises claros
        return c[3] < 200 and saturation(c) <= 30 and lightness(c) >= lightness(shadow) - 60

    seeds = [(x, y) for y in range(max(band_top, bottom - 4), bottom) for x in range(w)]
    seen = flood(px, w, h, seeds, is_shadow)
    # el relleno tambien entra por los lados de la elipse
    removed = 0
    for i, s in enumerate(seen):
        if s:
            px[i % w, i // w] = (0, 0, 0, 0)
            removed += 1
    return removed


def drop_specks(img, min_frac=0.004, min_px=6):
    """Quita islas pequenas (restos de sombra o de fondo) que no tocan al
    personaje principal."""
    px = img.load()
    w, h = img.size
    seen = bytearray(w * h)
    comps = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and not seen[y * w + x]:
                comp = []
                q = deque([(x, y)])
                seen[y * w + x] = 1
                while q:
                    cx, cy = q.popleft()
                    comp.append((cx, cy))
                    for nx in (cx - 1, cx, cx + 1):
                        for ny in (cy - 1, cy, cy + 1):
                            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny][3]:
                                seen[ny * w + nx] = 1
                                q.append((nx, ny))
                comps.append(comp)
    if not comps:
        return 0
    biggest = max(len(c) for c in comps)
    limit = max(min_px, int(biggest * min_frac))
    dropped = 0
    for c in comps:
        if len(c) < limit:
            for (x, y) in c:
                px[x, y] = (0, 0, 0, 0)
            dropped += len(c)
    return dropped


def feet_anchor(img):
    """Punto de apoyo: (centro x de los pies, fila mas baja). Los pies son los
    pixeles del 8% inferior del personaje."""
    bb = bbox_alpha(img, 1)
    if not bb:
        return None
    left, top, right, bottom = bb
    band = max(1, int((bottom - top) * 0.08))
    px = img.load()
    xs = [x for y in range(bottom - band, bottom) for x in range(left, right) if px[x, y][3]]
    return ((min(xs) + max(xs) + 1) / 2.0, bottom)


# --- validacion -----------------------------------------------------------------
def validate(img, size, target, tol, clipped):
    errors = []
    if img.size != (size, size):
        errors.append(f"tamano {img.size}, se esperaba {size}x{size}")
    a = img.getchannel("A")
    hist = a.histogram()
    semi = sum(hist[1:255])
    if semi:
        errors.append(f"{semi} pixeles semitransparentes")
    w, h = img.size
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)), a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    if any(corners) or hist[0] == 0:
        errors.append("el fondo no es transparente (esquinas opacas)")
    bb = a.getbbox()
    vis_h = (bb[3] - bb[1]) if bb else 0
    if not bb:
        errors.append("cuadro vacio")
    elif abs(vis_h - target) > target * tol:
        errors.append(f"altura visible {vis_h} px fuera de {target} +/- {int(target * tol)}")
    if clipped:
        errors.append(f"{clipped} pixeles quedaron fuera del canvas (recortados)")
    return errors, vis_h, bb


# --- vista previa ---------------------------------------------------------------
def make_preview(frames, cols, size, zoom, path, baseline):
    rows = (len(frames) + cols - 1) // cols
    cell = size * zoom
    gap = 4
    W = cols * cell + (cols + 1) * gap
    H = rows * cell + (rows + 1) * gap
    out = Image.new("RGBA", (W, H), (40, 40, 48, 255))
    d = ImageDraw.Draw(out)
    for i, fr in enumerate(frames):
        cx = gap + (i % cols) * (cell + gap)
        cy = gap + (i // cols) * (cell + gap)
        # tablero para ver la transparencia
        for ty in range(0, cell, 16):
            for tx in range(0, cell, 16):
                c = (200, 200, 205, 255) if (tx // 16 + ty // 16) % 2 else (235, 235, 240, 255)
                d.rectangle([cx + tx, cy + ty, cx + tx + 15, cy + ty + 15], fill=c)
        big = fr.resize((cell, cell), Image.NEAREST)
        out.alpha_composite(big, (cx, cy))
        # guias: centro (cian) y linea base (magenta)
        mx = cx + (size // 2) * zoom
        d.line([mx, cy, mx, cy + cell - 1], fill=(0, 200, 220, 255))
        by = cy + baseline * zoom + zoom - 1
        d.line([cx, by, cx + cell - 1, by], fill=(230, 0, 160, 255))
        d.text((cx + 3, cy + 2), f"{i:02d}", fill=(20, 20, 20, 255))
    out.save(path)


# --- principal ------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(description="Importa una hoja de sprites generada con IA.")
    ap.add_argument("sheet", help="ruta de la hoja PNG")
    ap.add_argument("--anim", required=True, help="nombre de la animacion (idle, walk, run...)")
    ap.add_argument("--cols", type=int, help="columnas de la rejilla (si no, autodetecta)")
    ap.add_argument("--rows", type=int, help="filas de la rejilla (si no, autodetecta)")
    ap.add_argument("--frames", type=int, help="cuadros usados, en orden de lectura (por defecto todos)")
    ap.add_argument("--ref-frame", type=int, default=0,
                    help="celda de referencia (Isak de pie) para la escala y el anclaje (0); "
                         "puede ser una celda posterior a --frames, que no se exporta")
    ap.add_argument("--target-height", type=int, default=96, help="altura visible del personaje en px (96)")
    ap.add_argument("--canvas", type=int, default=128, help="lado del canvas cuadrado (128)")
    ap.add_argument("--baseline", type=int, help="fila de la planta de los pies (por defecto la ultima)")
    ap.add_argument("--align", choices=("sheet", "feet", "ground"), default="sheet",
                    help="sheet: mismo desplazamiento para todos (no tiembla, respeta saltos); "
                         "feet: cada cuadro anclado por sus pies; ground: x de la referencia "
                         "y planta de cada cuadro en la linea base (ciclos de paso con suelo irregular)")
    ap.add_argument("--height-tol", type=float, default=0.2,
                    help="tolerancia relativa de la altura visible (0.2; sube para salto o muerte)")
    ap.add_argument("--bg-tol", type=int, default=40, help="tolerancia del color de fondo (40)")
    ap.add_argument("--shadow", choices=("auto", "off"), default="auto", help="quitar sombra del suelo")
    ap.add_argument("--shadow-tol", type=int, default=36, help="tolerancia del color de la sombra (36)")
    ap.add_argument("--alpha-cut", type=int, default=128, help="umbral de alfa (128)")
    ap.add_argument("--out", default=os.path.join("assets", "sprites", "isak"), help="carpeta de salida")
    ap.add_argument("--prefix", default="isak", help="prefijo de los archivos (isak)")
    ap.add_argument("--dry-run", action="store_true", help="no escribe los cuadros")
    ap.add_argument("--preview", help="guarda una vista ampliada x4 de los cuadros en esta ruta")
    args = ap.parse_args(argv)

    try:
        sheet = Image.open(args.sheet).convert("RGBA")
    except OSError as e:
        print(f"ERROR: no se pudo abrir la hoja: {e}", file=sys.stderr)
        return 2
    W, H = sheet.size
    transparent = has_transparency(sheet)

    cols, rows = args.cols, args.rows
    if not cols or not rows:
        dc, dr = autodetect_grid(sheet)
        cols, rows = cols or dc, rows or dr
        print(f"Rejilla autodetectada: {cols} columnas x {rows} filas")
    if cols < 1 or rows < 1:
        print("ERROR: rejilla no valida; pasa --cols y --rows", file=sys.stderr)
        return 2
    if W % cols or H % rows:
        print(f"AVISO: la hoja ({W}x{H}) no se divide exacto en {cols}x{rows}; se recorta el sobrante")
    cw, ch = W // cols, H // rows
    total = cols * rows
    n = args.frames or total
    if n > total or n < 1:
        print(f"ERROR: --frames {n} fuera de rango (1..{total})", file=sys.stderr)
        return 2
    if not 0 <= args.ref_frame < total:
        print(f"ERROR: --ref-frame fuera de rango (0..{total - 1})", file=sys.stderr)
        return 2
    print(f"Hoja {W}x{H}, celdas de {cw}x{ch}, {n} cuadros, fondo "
          f"{'transparente' if transparent else 'de color (se quita)'}")

    # 1-2: cortar y quitar fondo
    # la referencia puede ser una celda extra despues de los cuadros usados
    # (p. ej. Isak de pie en la ultima celda de la hoja de salto): se usa para
    # la escala y el anclaje, pero no se exporta
    indices = list(range(n)) + ([args.ref_frame] if args.ref_frame >= n else [])
    ref_idx = args.ref_frame if args.ref_frame < n else n
    cells = []
    for i in indices:
        x0, y0 = (i % cols) * cw, (i // cols) * ch
        cell = sheet.crop((x0, y0, x0 + cw, y0 + ch))
        cells.append(remove_background(cell, transparent, args.bg_tol))

    # 3: sombra
    shadow = None
    if args.shadow == "auto":
        shadow = detect_shadow_color(cells, max_sat=30, min_light=110)
        print(f"Sombra del suelo: {'detectada, color ' + str(shadow) if shadow else 'no detectada'}")
    for i, cell in enumerate(cells):
        removed = remove_shadow(cell, shadow, args.shadow_tol, band_frac=0.15) if shadow else 0
        threshold_alpha(cell, args.alpha_cut)
        drop_specks(cell)
        if shadow and removed == 0:
            print(f"  aviso: celda {indices[i]:02d} sin sombra reconocible")

    # 5: factor unico de escala desde el cuadro de referencia
    ref = cells[ref_idx]
    rbb = bbox_alpha(ref)
    if not rbb:
        print("ERROR: el cuadro de referencia esta vacio", file=sys.stderr)
        return 2
    ref_h = rbb[3] - rbb[1]
    factor = args.target_height / ref_h
    sw, sh = max(1, round(cw * factor)), max(1, round(ch * factor))
    print(f"Altura del personaje en la referencia: {ref_h} px -> factor {factor:.4f} (celda {sw}x{sh})")
    scaled = [c.resize((sw, sh), Image.NEAREST) for c in cells]

    # 6: anclaje
    size = args.canvas
    baseline = size - 1 if args.baseline is None else args.baseline
    ref_anchor = feet_anchor(scaled[ref_idx])
    frames, failed, report = [], 0, []
    for i, sc in enumerate(scaled[:n]):
        own = feet_anchor(sc) or ref_anchor
        if args.align == "sheet":
            anchor = ref_anchor
        elif args.align == "ground":
            anchor = (ref_anchor[0], own[1])
        else:
            anchor = own
        dx = round(size / 2 - anchor[0])
        dy = baseline + 1 - anchor[1]
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(sc, (dx, dy), sc)
        # pixeles que caen fuera del canvas
        total_px = sum(sc.getchannel("A").histogram()[1:])
        in_px = sum(canvas.getchannel("A").histogram()[1:])
        clipped = total_px - in_px
        threshold_alpha(canvas, args.alpha_cut)
        errs, vis_h, vbb = validate(canvas, size, args.target_height, args.height_tol, clipped)
        fa = feet_anchor(canvas)
        report.append((i, vis_h, fa, errs))
        frames.append(canvas)
        if errs:
            failed += 1

    # informe
    xs = [r[2][0] for r in report if r[2]]
    bs = [r[2][1] for r in report if r[2]]
    print(f"{'cuadro':>6} {'alto':>4} {'pies_x':>6} {'base':>4}  estado")
    for i, vis_h, fa, errs in report:
        fx, fb = (f"{fa[0]:.1f}", fa[1] - 1) if fa else ("-", "-")
        print(f"{i:>6} {vis_h:>4} {fx:>6} {fb:>4}  {'OK' if not errs else '; '.join(errs)}")
    if xs:
        print(f"Deriva de los pies entre cuadros: x {min(xs):.1f}..{max(xs):.1f} "
              f"({max(xs) - min(xs):.1f} px), base {min(bs) - 1}..{max(bs) - 1}")

    # 7: guardar
    out_dir = args.out if os.path.isabs(args.out) else os.path.join(os.getcwd(), args.out)
    if not args.dry_run:
        os.makedirs(out_dir, exist_ok=True)
        for i, fr in enumerate(frames):
            fr.save(os.path.join(out_dir, f"{args.prefix}_{args.anim}_{i:02d}.png"))
        stale = [f for f in os.listdir(out_dir)
                 if f.startswith(f"{args.prefix}_{args.anim}_") and f[len(args.prefix) + len(args.anim) + 2:-4].isdigit()
                 and int(f[len(args.prefix) + len(args.anim) + 2:-4]) >= n]
        print(f"Guardados {n} cuadros en {out_dir}")
        if stale:
            print(f"AVISO: quedan cuadros antiguos de esta animacion: {', '.join(sorted(stale))}")
    else:
        print("Simulacion (--dry-run): no se guardo ningun cuadro")
    if args.preview:
        make_preview(frames, cols if n >= cols else n, size, 4, args.preview, baseline)
        print(f"Vista previa x4: {args.preview}")

    if failed:
        print(f"FALLO: {failed} de {n} cuadros no pasan la validacion")
        return 1
    print(f"OK: {n} cuadros validos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
