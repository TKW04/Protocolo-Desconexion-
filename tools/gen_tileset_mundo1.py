#!/usr/bin/env python3
"""Genera el tileset del Mundo 1 (tiles de 64x64) con los colores de assets/palettes/mundo1.gpl.

Salidas:
  assets/sprites/tiles/mundo1_tileset.png   atlas en rejilla de 64 (8 columnas x 5 filas)
  data/tileset_mundo1.json                  mapa de tiles: coordenadas del atlas, tipo, y
                                            reglas de auto-seleccion por vecinos para el
                                            generador de niveles (paso 15)
  assets/sprites/tiles/_mundo1_tileset_preview_x2.png   atlas ampliado x2 con rejilla
  assets/sprites/tiles/_mundo1_composicion.png          trozo de nivel ensamblado con el atlas

Cada tile se dibuja en una rejilla logica de 32x32 "pixeles" de 2x2 px (UNIT), como el
resto del arte a 1280x720. Luz arriba e izquierda, sombra abajo y derecha.

Uso: python3 tools/gen_tileset_mundo1.py
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo1.gpl")
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "tiles")
ATLAS = os.path.join(OUT_DIR, "mundo1_tileset.png")
PREVIEW = os.path.join(OUT_DIR, "_mundo1_tileset_preview_x2.png")
COMPOSITION = os.path.join(OUT_DIR, "_mundo1_composicion.png")
MAP_JSON = os.path.join(ROOT, "data", "tileset_mundo1.json")

TILE = 64
UNIT = 2
L = TILE // UNIT  # 32 pixeles logicos por lado
COLUMNS = 8
ROWS = 5

# Bits de vecinos cardinales SOLIDOS (#) para elegir el tile de un bloque.
N, E, S, W = 1, 2, 4, 8
# Bits de diagonales VACIAS (solo para el interior, mascara cardinal 15).
NE, SE, SW, NW = 1, 2, 4, 8


def load_palette(path):
    pal = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            parts = s.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                pal[parts[3]] = tuple(int(p) for p in parts[:3]) + (255,)
    return pal


P = load_palette(GPL)
CLEAR = (0, 0, 0, 0)


class Tile:
    """Lienzo logico de 32x32; se escala x UNIT al pegarlo en el atlas."""

    def __init__(self, fill=None):
        self.img = Image.new("RGBA", (L, L), P[fill] if fill else CLEAR)
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x0, y0, x1, y1, color):
        """Rectangulo inclusivo en pixeles logicos."""
        if x1 < x0 or y1 < y0:
            return
        self.d.rectangle([x0, y0, x1, y1], fill=P[color] if color else CLEAR)

    def px(self, x, y, color):
        self.img.putpixel((x, y), P[color] if color else CLEAR)

    def scaled(self):
        return self.img.resize((TILE, TILE), Image.NEAREST)


# ----------------------------------------------------------------- bloques solidos
def rivet(t, x, y):
    """Remache hundido de 3x3: sombra arriba-izquierda, luz abajo-derecha."""
    t.rect(x, y, x + 2, y + 2, "tile_sombra")
    t.rect(x + 1, y + 1, x + 2, y + 2, "tile_base")
    t.px(x + 2, y + 2, "tile_luz")


def vent(t, x, y, w=6):
    """Rejilla pequena: tres ranuras horizontales."""
    for k in range(3):
        t.rect(x, y + k * 2, x + w - 1, y + k * 2, "tile_sombra")


def solid_tile(mask, diag=0, alt=False):
    t = Tile("tile_base")
    top, right, bottom, left = not mask & N, not mask & E, not mask & S, not mask & W
    # detalles discretos del interior (lejos de los bordes, para que no haya costuras)
    if alt:
        vent(t, 17, 8)
        rivet(t, 6, 20)
    else:
        rivet(t, 7, 9)
        t.rect(21, 21, 22, 22, "tile_sombra")
        t.px(22, 22, "tile_luz")
    y_side = 4 if top else 0
    if left:
        t.rect(0, y_side, 1, L - 1, "tile_luz")
    if right:
        t.rect(L - 2, y_side, L - 1, L - 1, "tile_sombra")
    if bottom:
        t.rect(0 if not left else 2, L - 2, L - 1, L - 1, "tile_sombra")
        if left:
            t.rect(0, L - 2, 1, L - 1, "tile_luz")
            t.px(1, L - 1, "tile_sombra")
    if top:
        t.rect(0, 0, L - 1, 1, "borde_luz")
        t.rect(0, 2, L - 1, 3, "tile_luz")
        # pequenos puntos de luz en la superficie (como LEDs de la maqueta)
        for x in (5, 21):
            t.px(x, 2, "borde_luz")
        if left:
            t.px(0, 0, None)
            t.rect(0, 1, 0, 3, "borde_luz")
        if right:
            t.px(L - 1, 0, None)
            t.rect(L - 2, 2, L - 1, 3, "tile_sombra")
    if bottom and right:
        t.px(L - 1, L - 1, None)
    if bottom and left:
        t.px(0, L - 1, None)
    # esquinas interiores: el borde superior del vecino llega a una pared (o al reves)
    if diag & NW:
        t.rect(0, 0, 1, 3, "tile_luz")
        t.px(0, 0, "borde_luz")
        t.px(1, 0, "borde_luz")
    if diag & NE:
        t.rect(L - 2, 0, L - 1, 1, "borde_luz")
        t.rect(L - 2, 2, L - 1, 3, "tile_luz")
    if diag & SW:
        t.rect(0, L - 2, 1, L - 1, "tile_sombra")
        t.px(0, L - 3, "tile_luz")
    if diag & SE:
        t.rect(L - 2, L - 2, L - 1, L - 1, "tile_sombra")
    return t


# ------------------------------------------------------- plataforma de una via
def one_way_tile(left_end, right_end):
    t = Tile()
    x0 = 1 if left_end else 0
    x1 = L - 2 if right_end else L - 1
    t.rect(x0, 0, x1, 1, "borde_luz")
    t.rect(x0, 2, x1, 4, "tile_luz")
    t.rect(x0, 5, x1, 5, "tile_sombra")
    # puntos de luz cada 16 (encaja al repetirse)
    for x in (7, 23):
        t.px(x, 3, "borde_luz")
    # soportes cada 16 pixeles logicos
    for sx in (5, 21):
        t.rect(sx, 6, sx + 1, 9, "tile_luz")
        t.px(sx + 1, 9, "tile_sombra")
        t.rect(sx + 2, 6, sx + 2, 8, "tile_sombra")
    if left_end:
        t.rect(0, 1, 0, 4, "borde_luz")
        t.px(0, 5, "tile_sombra")
    if right_end:
        t.rect(L - 1, 1, L - 1, 4, "tile_luz")
        t.px(L - 1, 5, "tile_sombra")
    return t


# ------------------------------------------------------------------- pinchos
def spike_floor():
    """Dos pinchos de 16 de ancho sobre una base metalica; mitad superior libre."""
    t = Tile()
    base_y = L - 4  # base: filas 28-31
    t.rect(0, base_y, L - 1, base_y + 1, "banner_gris")
    t.rect(0, base_y + 2, L - 1, L - 1, "tile_sombra")
    for k in range(4):
        t.px(3 + k * 8, base_y + 1, "tile_luz")
    apex_y = 12
    for sx in (0, 16):
        cx = sx + 8
        height = base_y - apex_y
        for y in range(apex_y, base_y):
            half = (y - apex_y) * 7 // height + 1  # 1..7
            xl, xr = cx - half, cx + half - 1
            tip = y < apex_y + 7
            t.rect(xl, y, xr, y, "alerta" if tip else "banner_gris")
            # contorno/sombra a la derecha y brillo a la izquierda
            t.px(xr, y, "alerta_sombra")
            if not tip and xr - xl >= 3:
                t.px(xl, y, "banner_blanco")
    return t


def spike_ceiling():
    t = spike_floor()
    t.img = t.img.transpose(Image.FLIP_TOP_BOTTOM)
    return t


# ------------------------------------------------------------- decorado de fondo
def decor_grid():
    """Rejilla de pantalla para el fondo (se repite en x e y)."""
    t = Tile("cielo")
    for k in range(0, L, 8):
        t.rect(k, 0, k, L - 1, "fondo_medio")
        t.rect(0, k, L - 1, k, "fondo_medio")
    for kx in range(0, L, 16):
        for ky in range(0, L, 16):
            t.px(kx, ky, "resplandor")
    return t


def decor_window():
    """Ventana de pantalla (pop-up apagado) para el fondo, 1 tile."""
    t = Tile("cielo")
    t.rect(3, 5, 28, 26, "fondo_medio")
    t.rect(4, 6, 27, 25, "cielo")
    t.rect(4, 6, 27, 9, "fondo_medio")
    t.rect(6, 7, 7, 8, "resplandor")
    t.rect(9, 7, 10, 8, "resplandor")
    t.rect(7, 13, 12, 18, "resplandor")
    t.rect(15, 13, 25, 14, "fondo_medio")
    t.rect(15, 17, 22, 18, "fondo_medio")
    t.rect(7, 21, 24, 22, "fondo_medio")
    return t


# ---------------------------------------------------------------------- atlas
def build():
    tiles = []  # dicts: name, atlas [x, y], kind, hazard, repeat_x, repeat_y, img

    def add(name, col, row, img, kind, hazard="", rx=False, ry=False, extra=None):
        entry = {"name": name, "atlas": [col, row], "kind": kind, "hazard": hazard,
                 "repeat_x": rx, "repeat_y": ry}
        if extra:
            entry.update(extra)
        tiles.append((entry, img))

    names = {0: "solid_single", 15: "solid_interior"}
    for m in range(16):
        name = names.get(m, "solid_" + "".join(k for k, b in (("n", N), ("e", E), ("s", S), ("w", W))
                                                 if m & b) + "_open")
        add(name, m % COLUMNS, m // COLUMNS, solid_tile(m), "solid",
            rx=bool(m & E and m & W), ry=bool(m & N and m & S), extra={"mask": m})
    add("solid_interior_alt", 0, 2, solid_tile(15, alt=True), "solid", rx=True, ry=True,
        extra={"mask": 15, "alt": True})
    for dmask in range(1, 16):
        slot = 16 + dmask  # filas 2 y 3, saltando (0, 2) que es interior_alt
        add("solid_inner_" + "".join(k for k, b in (("ne", NE), ("se", SE), ("sw", SW), ("nw", NW)) if dmask & b),
            slot % COLUMNS, slot // COLUMNS, solid_tile(15, diag=dmask), "solid", extra={"mask": 15, "diag": dmask})
    add("one_way_left", 0, 4, one_way_tile(True, False), "one_way")
    add("one_way_center", 1, 4, one_way_tile(False, False), "one_way", rx=True)
    add("one_way_right", 2, 4, one_way_tile(False, True), "one_way")
    add("one_way_single", 3, 4, one_way_tile(True, True), "one_way")
    add("spikes_floor", 4, 4, spike_floor(), "hazard", hazard="spikes", rx=True)
    add("spikes_ceiling", 5, 4, spike_ceiling(), "hazard", hazard="spikes", rx=True)
    add("decor_grid", 6, 4, decor_grid(), "decor", rx=True, ry=True)
    add("decor_window", 7, 4, decor_window(), "decor")

    atlas = Image.new("RGBA", (COLUMNS * TILE, ROWS * TILE), CLEAR)
    used = set()
    for entry, t in tiles:
        c, r = entry["atlas"]
        assert (c, r) not in used, entry
        used.add((c, r))
        atlas.paste(t.scaled(), (c * TILE, r * TILE))
    return atlas, [e for e, _ in tiles]


def write_map(entries):
    by_name = {e["name"]: e["atlas"] for e in entries}
    data = {
        "_notes": ("Tileset del Mundo 1 (generado por tools/gen_tileset_mundo1.py; no editar a mano). "
                   "Tiles de 64x64 en assets/sprites/tiles/mundo1_tileset.png, TileSet de Godot en "
                   "res://assets/tilesets/mundo1.tres (tools/build_tileset_mundo1.gd), fuente de atlas source_id. "
                   "Para el generador de niveles (paso 15), por caracter del grid: '#' solido: mascara cardinal de "
                   "vecinos SOLIDOS ('#'; fuera del grid cuenta como solido si outside_is_solid) con bits N=1, E=2, "
                   "S=4, W=8 -> solid.by_mask; si la mascara es 15 se mira la mascara de diagonales VACIAS (NE=1, "
                   "SE=2, SW=4, NW=8) -> solid.interior_by_diag (0 = interior; en el interior liso se alterna "
                   "solid.interior_alt cuando (fila*7 + columna*3) % alt_every == 0). '-' una via: left si no hay '-' "
                   "a la izquierda y si a la derecha, right al reves, single si no hay ninguno, center si hay los "
                   "dos. '^' pinchos: ceiling si arriba hay '#' y abajo no; si no, floor. Los pinchos no tienen "
                   "colision solida: el generador anade su Area de peligro (custom data hazard). 'h' no es un tile: "
                   "es scenes/levels/hidden_platform.tscn. decor: solo fondo, sin colision. kind = custom data "
                   "'kind' del TileSet (solid, one_way, hazard, decor). repeat_x / repeat_y: el tile puede "
                   "ponerse junto a si mismo en ese eje (tools/validate_tileset.py comprueba que no hay costura)."),
        "tile_size": TILE,
        "atlas_png": "res://assets/sprites/tiles/mundo1_tileset.png",
        "tileset": "res://assets/tilesets/mundo1.tres",
        "palette": "res://assets/palettes/mundo1.gpl",
        "source_id": 0,
        "columns": COLUMNS,
        "rows": ROWS,
        "outside_is_solid": True,
        "chars": {"#": "solid", "-": "one_way", "^": "spikes", "h": "hidden_platform_scene"},
        "solid": {
            "cardinal_bits": {"N": N, "E": E, "S": S, "W": W},
            "diagonal_empty_bits": {"NE": NE, "SE": SE, "SW": SW, "NW": NW},
            "by_mask": {str(e["mask"]): e["atlas"] for e in entries
                        if e["kind"] == "solid" and "diag" not in e and not e.get("alt")},
            "interior_by_diag": {"0": by_name["solid_interior"],
                                 **{str(e["diag"]): e["atlas"] for e in entries if "diag" in e}},
            "interior_alt": by_name["solid_interior_alt"],
            "alt_every": 5,
        },
        "one_way": {k: by_name["one_way_" + k] for k in ("left", "center", "right", "single")},
        "spikes": {"floor": by_name["spikes_floor"], "ceiling": by_name["spikes_ceiling"]},
        "decor": {"grid": by_name["decor_grid"], "window": by_name["decor_window"]},
        "one_way_collision_height_px": 12,
        "tiles": entries,
    }
    with open(MAP_JSON, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent="\t", ensure_ascii=False)
        fh.write("\n")
    return data


# ----------------------------------------------------- auto-seleccion (referencia)
def select_tile(grid, r, c, m):
    """Implementacion de referencia de las reglas de data/tileset_mundo1.json."""
    rows, cols = len(grid), len(grid[0])

    def at(rr, cc):
        if 0 <= rr < rows and 0 <= cc < cols:
            return grid[rr][cc]
        return "#" if m["outside_is_solid"] else "."

    ch = grid[r][c]
    if ch == "#":
        solid = lambda dr, dc: at(r + dr, c + dc) == "#"
        mask = (N if solid(-1, 0) else 0) | (E if solid(0, 1) else 0) | (S if solid(1, 0) else 0) | \
               (W if solid(0, -1) else 0)
        if mask == 15:
            diag = (NE if not solid(-1, 1) else 0) | (SE if not solid(1, 1) else 0) | \
                   (SW if not solid(1, -1) else 0) | (NW if not solid(-1, -1) else 0)
            if diag == 0 and (r * 7 + c * 3) % m["solid"]["alt_every"] == 0:
                return m["solid"]["interior_alt"]
            return m["solid"]["interior_by_diag"][str(diag)]
        return m["solid"]["by_mask"][str(mask)]
    if ch == "-":
        lw, rw = at(r, c - 1) == "-", at(r, c + 1) == "-"
        key = "center" if lw and rw else "left" if rw else "right" if lw else "single"
        return m["one_way"][key]
    if ch == "^":
        ceiling = at(r - 1, c) == "#" and at(r + 1, c) != "#"
        return m["spikes"]["ceiling" if ceiling else "floor"]
    return None


COMPOSITION_GRID = [
    "....................",
    "....................",
    ".........######.....",
    ".........#^^^^#.....",
    "....---.............",
    "...............--...",
    "..........-.........",
    ".............####...",
    "####.......^^#..#...",
    "####...--..####.#..#",
    "####^^.....#######.#",
    "##########..########",
]


def composition(atlas, m):
    """Trozo de nivel con el atlas sobre el fondo de la maqueta (1280x768)."""
    T = TILE
    rows, cols = len(COMPOSITION_GRID), len(COMPOSITION_GRID[0])
    img = Image.new("RGBA", (cols * T, rows * T), P["noche_profunda"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 2 * T, cols * T, rows * T], fill=P["cielo"])
    d.rectangle([0, 5 * T, cols * T, rows * T], fill=P["fondo_medio"])
    d.rectangle([0, 7 * T, cols * T, rows * T], fill=P["resplandor"])
    # decorado de fondo: rejilla y ventanas
    for cc in range(0, 4):
        for rr in range(1, 3):
            x, y = m["decor"]["grid"]
            img.paste(atlas.crop((x * T, y * T, x * T + T, y * T + T)), (cc * T, rr * T))
    for cc, rr in ((5, 1), (17, 3)):
        x, y = m["decor"]["window"]
        img.paste(atlas.crop((x * T, y * T, x * T + T, y * T + T)), (cc * T, rr * T))
    for r in range(rows):
        for c in range(cols):
            sel = select_tile(COMPOSITION_GRID, r, c, m)
            if sel is None:
                continue
            x, y = sel
            tile = atlas.crop((x * T, y * T, x * T + T, y * T + T))
            img.alpha_composite(tile, (c * T, r * T))
    isak_path = os.path.join(ROOT, "assets", "sprites", "isak", "isak_idle_00.png")
    if os.path.exists(isak_path):
        isak = Image.open(isak_path).convert("RGBA")
        img.alpha_composite(isak, (1 * T + T // 2 - 64, 8 * T - 128))
    return img


def preview(atlas):
    big = atlas.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (60, 64, 72, 255))
    for y in range(0, big.height, 16):
        for x in range(0, big.width, 16):
            if (x // 16 + y // 16) % 2:
                ImageDraw.Draw(bg).rectangle([x, y, x + 15, y + 15], fill=(80, 84, 94, 255))
    bg.alpha_composite(big)
    d = ImageDraw.Draw(bg)
    for k in range(0, big.width + 1, TILE * 2):
        d.line([k, 0, k, big.height], fill=(255, 0, 255, 255))
    for k in range(0, big.height + 1, TILE * 2):
        d.line([0, k, big.width, k], fill=(255, 0, 255, 255))
    return bg


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    atlas, entries = build()
    atlas.save(ATLAS)
    m = write_map(entries)
    preview(atlas).save(PREVIEW)
    composition(atlas, m).convert("RGB").save(COMPOSITION)
    print(ATLAS)
    print(MAP_JSON)
    print(PREVIEW)
    print(COMPOSITION)
    print(f"{len(entries)} tiles")


if __name__ == "__main__":
    main()
