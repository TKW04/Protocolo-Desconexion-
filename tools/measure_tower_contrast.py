#!/usr/bin/env python3
"""Contraste de las plataformas con el fondo en capturas de una torre (2026-10-17, ajuste del 1-2:
«el fondo hace que se pierdan las plataformas»).

Lee las capturas de tools/render_level_1_2.gd (PNG de 1280x720 y, al lado, <nombre>.json con el
centro de la camara) y el nivel (data/levels/<id>.json). Por cada borde de arriba de plataforma
visible (tile '#' con aire encima o plataforma de una via '-') toma el color claro del borde (el
pixel mas luminoso de sus 4 filas de arriba, el borde_luz) y lo compara con el fondo de al lado:
una franja de 20 px por encima (de 4 a 24 px sobre el borde, el ancho del tile) y, en las de una
via, otra por debajo (de 20 a 36 px bajo el borde). Contraste de luminancia relativa WCAG:
(L_claro + 0,05) / (L_oscuro + 0,05). Por borde da la mediana de la franja y el percentil 10 (las
zonas peores); el resumen da cuantos bordes llegan a 3:1 y la mediana de todos.

Uso: python3 tools/measure_tower_contrast.py data/levels/1-2.json <carpeta_capturas> [--json salida.json]
"""

import argparse
import json
import os
import statistics
import sys

from PIL import Image

HUD_PX = 40          # franja del HUD arriba (no es fondo)
ABOVE = (4, 24)      # franja por encima del borde (px)
BELOW = (20, 36)     # franja por debajo del borde de una una via (px)
TARGET = 3.0


def luminance(rgb):
    def ch(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def ratio(a, b):
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def edges(level):
    grid = level["grid"]
    out = []
    for r, row in enumerate(grid):
        for c, ch in enumerate(row):
            above = grid[r - 1][c] if r > 0 else "#"
            if ch == "#" and above not in "#":
                out.append((c, r, "solido"))
            elif ch == "-":
                out.append((c, r, "una_via"))
    return out


def measure_shot(png, meta, level):
    T = float(level["tile_size"])
    img = Image.open(png).convert("RGB")
    px = img.load()
    w, h = img.size
    cx, cy = meta["camera_center"]
    ox, oy = cx - w / 2.0, cy - h / 2.0
    grid = level["grid"]
    results = []
    for c, r, kind in edges(level):
        sx0, sy = int(round(c * T - ox)), int(round(r * T - oy))
        if sx0 < 0 or sx0 + T > w or sy - ABOVE[1] < HUD_PX or sy + BELOW[1] >= h:
            continue
        top = [px[x, y] for y in range(sy, sy + 4) for x in range(sx0, sx0 + int(T))]
        edge = max(top, key=luminance)
        l_edge = luminance(edge)
        band = []
        if r > 0 and grid[r - 1][c] in ".SoECPG":
            band += [px[x, y] for y in range(sy - ABOVE[1], sy - ABOVE[0]) for x in range(sx0, sx0 + int(T))]
        if kind == "una_via" and r + 1 < len(grid) and grid[r + 1][c] in ".SoECPG":
            band += [px[x, y] for y in range(sy + BELOW[0], sy + BELOW[1]) for x in range(sx0, sx0 + int(T))]
        if not band:
            continue
        ratios = sorted(ratio(l_edge, luminance(p)) for p in band)
        results.append({"cell": [c, r], "kind": kind, "edge_rgb": list(edge),
                        "median": statistics.median(ratios), "p10": ratios[len(ratios) // 10]})
    return results


def summarize(items):
    if not items:
        return {"edges": 0}
    med = [i["median"] for i in items]
    p10 = [i["p10"] for i in items]
    return {"edges": len(items), "median": round(statistics.median(med), 2),
            "min_median": round(min(med), 2), "share_median_ge_3": round(sum(m >= TARGET for m in med) / len(med), 3),
            "median_p10": round(statistics.median(p10), 2),
            "share_p10_ge_3": round(sum(m >= TARGET for m in p10) / len(p10), 3)}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("level")
    parser.add_argument("shots")
    parser.add_argument("--json", default=None)
    args = parser.parse_args(argv[1:])
    with open(args.level, encoding="utf-8") as fh:
        level = json.load(fh)
    report = {"level": level["id"], "target": TARGET, "shots": {}}
    all_items = []
    for name in sorted(os.listdir(args.shots)):
        if not name.endswith(".png"):
            continue
        meta_path = os.path.join(args.shots, name[:-4] + ".json")
        if not os.path.exists(meta_path):
            continue
        with open(meta_path, encoding="utf-8") as fh:
            meta = json.load(fh)
        items = measure_shot(os.path.join(args.shots, name), meta, level)
        all_items += items
        report["shots"][name] = summarize(items)
        s = report["shots"][name]
        print("%-30s bordes %3d  mediana %5.2f:1  minima %5.2f:1  >=3:1 %5.1f %%  p10 mediana %5.2f:1"
              % (name, s.get("edges", 0), s.get("median", 0), s.get("min_median", 0),
                 100 * s.get("share_median_ge_3", 0), s.get("median_p10", 0)))
    report["total"] = summarize(all_items)
    t = report["total"]
    print("TOTAL: bordes %d, mediana %.2f:1, minima %.2f:1, con mediana >= 3:1 %.1f %%, p10 >= 3:1 %.1f %%"
          % (t.get("edges", 0), t.get("median", 0), t.get("min_median", 0), 100 * t.get("share_median_ge_3", 0),
             100 * t.get("share_p10_ge_3", 0)))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
