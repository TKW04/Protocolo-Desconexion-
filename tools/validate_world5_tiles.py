#!/usr/bin/env python3
"""Valida el tileset y el fondo del centro comercial del Mundo 5 (paso 9 de docs/propuesta-mundo-5.md §8 y §6.1).

- Tileset (tools/gen_world5_tiles.py): atlas y data/tileset_mundo5.json al dia; las reglas de
  tools/validate_tileset.py con ese mapa (paleta del Mundo 5, la de la variante elegida, alfa, costuras, bloques que encajan);
  el TileSet res://assets/tilesets/mundo5.tres existe y usa ese atlas.
- Fondo (tools/gen_world5_background.py): capas, data/world5_background.json y scenes/levels/world5_background.tscn
  al dia; solo colores de la paleta; la capa opaca se repite sin costura (periodo de 128 px en los bordes) y las
  demas no tienen nada en el borde.
- Contraste de Isak y Eco con el fondo (regla 7 de §6.1; como tools/measure_tower_contrast.py, luminancia WCAG):
  sobre el fondo compuesto, el cian de Isak (los dos de su hoja) y la esfera de Eco (la de siempre: Eco se ve
  igual en todos los mundos) contrastan >= 3:1 con los colores dominantes (los que cubren >= 10 % del fondo) y con al menos el
  90 % de los pixeles; igual sobre las baldosas del tileset (los bloques solidos). Imprime las medidas (las cita
  docs/propuesta-mundo-5.md §8.1, paso 9).

Uso: python3 -I tools/validate_world5_tiles.py [--verbose]   (sale con 1 si hay errores)
"""
import os
import site
import subprocess
import sys
from collections import Counter

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_world5_background as bg  # noqa: E402
import palette_mundo5_provisional as pal  # noqa: E402
from gen_energy_objects import load_gpl  # noqa: E402

TARGET = 3.0
MIN_COVERAGE = 0.90
DOMINANT = 0.10


def _hx(v):
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))


def contrast_report(img):
    counts = Counter(c[:3] for c in img.getdata() if c[3] == 255)
    total = sum(counts.values())
    out = {}
    for who, hexes in (("Isak", pal.ISAK_CYANS), ("Eco", pal.ECO_COLORS)):
        cyans = [_hx(h) for h in hexes]
        ok = sum(n for c, n in counts.items() if min(pal.ratio(k, c) for k in cyans) >= TARGET)
        dominant = [c for c, n in counts.items() if n >= DOMINANT * total]
        worst_dom = min(min(pal.ratio(k, c) for k in cyans) for c in dominant)
        out[who] = {"coverage": ok / total, "worst_dominant": worst_dom}
    return out


def tiles_report():
    """Contraste sobre los bloques solidos del atlas (lo que pisa Isak)."""
    import json
    with open(os.path.join(REPO, "data", "tileset_mundo5.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    atlas = Image.open(os.path.join(REPO, "assets", "sprites", "tiles", "mundo5_tileset.png")).convert("RGBA")
    t = data["tile_size"]
    out = Image.new("RGBA", (t * 8, t * 8), (0, 0, 0, 0))
    solids = [e["atlas"] for e in data["tiles"] if e["kind"] == "solid"]
    for k, (col, row) in enumerate(solids[:64]):
        out.alpha_composite(atlas.crop((col * t, row * t, col * t + t, row * t + t)), ((k % 8) * t, (k // 8) * t))
    return contrast_report(out)


def main(argv):
    errs = []
    for tool in ("gen_world5_tiles.py", "gen_world5_background.py"):
        r = subprocess.run([sys.executable, "-I", os.path.join(TOOLS, tool), "--check"], capture_output=True, text=True)
        if r.returncode != 0:
            errs.append(r.stderr.strip() or "%s --check fallo" % tool)
    r = subprocess.run([sys.executable, "-I", os.path.join(TOOLS, "validate_tileset.py"), "--map",
                        os.path.join("data", "tileset_mundo5.json")], capture_output=True, text=True, cwd=REPO)
    if r.returncode != 0:
        errs.append("validate_tileset (mundo5): " + (r.stdout + r.stderr).strip())
    tres = os.path.join(REPO, "assets", "tilesets", "mundo5.tres")
    if not os.path.exists(tres):
        errs.append("falta assets/tilesets/mundo5.tres ($GODOT --headless --path . -s tools/build_tileset_mundo1.gd "
                    "-- --map res://data/tileset_mundo5.json)")
    elif "res://assets/sprites/tiles/mundo5_tileset.png" not in open(tres, encoding="utf-8").read():
        errs.append("assets/tilesets/mundo5.tres no usa el atlas del Mundo 5")
    allowed = {c[:3] for c in load_gpl(pal.GPL).values()}
    layers = bg.layers()
    for (_n, name, _s), img in zip(bg.LAYERS, layers.values()):
        used = {c[:3] for c in img.getdata() if c[3] == 255}
        if not used <= allowed:
            errs.append("%s: colores fuera de la paleta del Mundo 5" % name)
        if any(0 < a < 255 for a in img.getchannel("A").getdata()):
            errs.append("%s: alfa distinto de 0 o 255" % name)
    first = layers[bg.LAYERS[0][1]]
    if first.crop((0, 0, 128, bg.H)).tobytes() != first.crop((bg.W - 128, 0, bg.W, bg.H)).tobytes():
        errs.append("%s: no se repite sin costura" % bg.LAYERS[0][1])
    for _n, name, _s in bg.LAYERS[1:]:
        img = layers[name]
        edge = [img.getpixel((x, y))[3] for x in (0, 1, bg.W - 2, bg.W - 1) for y in range(bg.H)]
        if any(edge):
            errs.append("%s: hay dibujo en el borde (costura al repetirse)" % name)
    report = contrast_report(bg.composite())
    tiles = tiles_report()
    for who, m in report.items():
        if m["worst_dominant"] < TARGET:
            errs.append("%s sobre los colores dominantes del fondo < 3:1 (%.2f)" % (who, m["worst_dominant"]))
        if m["coverage"] < MIN_COVERAGE:
            errs.append("%s >= 3:1 solo en el %.0f %% del fondo (< %.0f %%)"
                        % (who, m["coverage"] * 100, MIN_COVERAGE * 100))
    for who, m in tiles.items():
        if m["worst_dominant"] < TARGET:
            errs.append("%s sobre las baldosas < 3:1 (%.2f)" % (who, m["worst_dominant"]))
    if "--verbose" in argv or errs:
        for who, m in tiles.items():
            print("validate_world5_tiles: %s sobre las baldosas: >= 3:1 en el %.1f %%; peor color dominante %.2f:1"
                  % (who, m["coverage"] * 100, m["worst_dominant"]))
        for who, m in report.items():
            print("validate_world5_tiles: %s: >= 3:1 en el %.1f %% del fondo; peor color dominante %.2f:1"
                  % (who, m["coverage"] * 100, m["worst_dominant"]))
    print("\n".join(errs) if errs else "validate_world5_tiles: OK")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
