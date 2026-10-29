#!/usr/bin/env python3
"""Contraste de Isak y Eco con lo que tienen detras en capturas de las salas de prueba del Mundo 5 (paso 9 de
docs/propuesta-mundo-5.md §8 y regla 7 de §6.1).

Lee las capturas de tools/render_world5_rooms.gd: por cada <sala>_<n>.json (cajas de Isak y de Eco en pantalla)
toma <sala>_<n>_fondo.png (la misma vista sin ellos) y, dentro de cada caja, compara el cian de Isak (los dos de su
hoja) o los colores de la esfera de Eco (la misma en todos los mundos) con cada pixel del fondo: contraste de luminancia WCAG
(L_claro + 0,05) / (L_oscuro + 0,05). Pasa si el cian llega a 3:1 con al menos el 90 % de los pixeles de la caja y
con todos los colores dominantes (>= 10 % de la caja). Imprime una linea por caja y el resumen.

Uso: python3 tools/measure_world5_contrast.py <carpeta_capturas>   (sale con 1 si alguna caja no llega)
"""
import glob
import json
import os
import site
import sys
from collections import Counter

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import palette_mundo5_provisional as pal  # noqa: E402

TARGET = 3.0
MIN_COVERAGE = 0.90
DOMINANT = 0.10


def measure(img, box, cyans):
    w, h = img.size
    x0, y0, x1, y1 = (int(round(v)) for v in box)
    region = img.crop((max(0, x0), max(0, y0), min(w, x1), min(h, y1))).convert("RGB")
    counts = Counter(region.getdata())
    total = sum(counts.values())
    if total == 0:
        return None
    worst = {c: min(pal.ratio(k, c) for k in cyans) for c in counts}
    ok = sum(n for c, n in counts.items() if worst[c] >= TARGET)
    dominant = [worst[c] for c, n in counts.items() if n >= DOMINANT * total]
    return {"coverage": ok / total, "worst_dominant": min(dominant) if dominant else min(worst.values())}


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    folder = argv[0]
    colors = {who: [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in hexes]
              for who, hexes in (("isak", pal.ISAK_CYANS), ("eco", pal.ECO_COLORS))}
    failures, rows = 0, 0
    for meta in sorted(glob.glob(os.path.join(folder, "*_[0-9].json"))):
        base = meta[:-len(".json")]
        with open(meta, encoding="utf-8") as fh:
            boxes = json.load(fh)
        img = Image.open(base + "_fondo.png")
        for who in ("isak", "eco"):
            m = measure(img, boxes[who], colors[who])
            if m is None:
                continue
            rows += 1
            good = m["coverage"] >= MIN_COVERAGE and m["worst_dominant"] >= TARGET
            failures += 0 if good else 1
            print("%s %s: >= 3:1 en el %.1f %% de la caja; peor color dominante %.2f:1%s"
                  % (os.path.basename(base), who, m["coverage"] * 100, m["worst_dominant"], "" if good else "  FALLA"))
    print("measure_world5_contrast: %d cajas, %d fallan" % (rows, failures))
    return 1 if failures or rows == 0 else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
