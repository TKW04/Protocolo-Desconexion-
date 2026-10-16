#!/usr/bin/env python3
"""Generador de la escena de Godot de un nivel desde data/levels/<id>.json (paso 15).

Escribe scenes/levels/<id>.tscn como texto (sin abrir Godot), asi que es
reproducible: el mismo JSON produce byte a byte el mismo .tscn (las pruebas lo
comprueban con un hash). No hay que editar la escena a mano: se regenera.

Contenido de la escena (raiz GeneratedLevel, scripts/levels/generated_level.gd):
  - Background: scenes/levels/world<N>_background.tscn.
  - Tiles: TileMapLayer con el TileSet del mundo (data/tileset_mundo<N>.json):
    '#' solido con auto-tile por vecinos (las celdas de glitch_wall cuentan como
    solidas para los bordes), '-' una via, '^' pinchos (solo dibujo).
  - Hazards: un Area2D (scripts/levels/spike_hazard.gd) por tramo horizontal de
    '^', forma y capas de data/hazards.json.
  - HiddenPlatforms: scenes/levels/hidden_platform.tscn por cada 'h'.
  - AttentionPoints: scenes/levels/attention_point.tscn en el centro de cada 'o'.
  - Checkpoints: Marker2D Checkpoint (grupo "checkpoint") por cada C, en los
    pies de Isak (abajo-centro de la celda). La logica es del paso 16.
  - Secrets: Marker2D (grupo "secret") por cada S; los secretos con `object` son
    el propio objeto.
  - Objects: la escena del catalogo (data/world<N>_objects.json) en (x, y) * tile
    (esquina superior izquierda de la celda), con cada param asignado a su
    propiedad (`fields`); arrays de 2 numeros -> Vector2, ids -> StringName.
    exit_door y exit_terminal reciben level_id; glitch_wall recibe solid_neighbors calculado del grid.
  - Enemies: scenes/enemies/<type>.tscn en los pies (abajo-centro de la celda E);
    `params` va como metadata "params" y GeneratedLevel lo aplica tras _ready
    (patrol_range_px tambien como propiedad; params.health -> max_health, la vida
    de esa instancia, 2026-10-15).
  - Goal: Marker2D (grupo "goal") en la G (la puerta de salida la contiene).
  - Isak (P, pies abajo-centro de la celda) con camera_limits = tamano del grid,
    Hud y EcoTextBox.
  - Help: HelpSystem (scripts/levels/help_system.gd), la ayuda de Eco con Q
    (2026-10-15 (3)). Los objetos, puntos de atencion, checkpoints y enemigos con
    tipo de ayuda van en el grupo "help_target" con metadata/help_id: el help_id
    del tipo del catalogo (types.<tipo>.help_id, attention_point.help_id,
    checkpoint.help_id) o del enemigo (data/enemies/<tipo>.json); un objeto o
    enemigo del nivel lo sustituye con su propio "help_id" ("" = sin Q).

Uso:
  python3 tools/build_level.py data/levels/1-1.json        # escribe scenes/levels/1-1.tscn
  python3 tools/build_level.py --check data/levels/1-1.json  # 1 si el .tscn no esta al dia
  python3 tools/build_level.py --stdout data/levels/1-1.json
"""

import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LEVEL_SCRIPT = "res://scripts/levels/generated_level.gd"
SPIKE_SCRIPT = "res://scripts/levels/spike_hazard.gd"
CHECKPOINT_SCRIPT = "res://scripts/levels/checkpoint.gd"
ISAK_SCENE = "res://scenes/player/isak.tscn"
HUD_SCENE = "res://scenes/ui/hud.tscn"
ECO_SCENE = "res://scenes/ui/eco_text_box.tscn"
POINT_SCENE = "res://scenes/levels/attention_point.tscn"
HIDDEN_SCENE = "res://scenes/levels/hidden_platform.tscn"
HELP_SCRIPT = "res://scripts/levels/help_system.gd"
HELP_GROUP = "help_target"
HAZARDS_JSON = "data/hazards.json"
# Propiedades de los objetos que son StringName (ids que enlazan objetos).
STRING_NAME_PROPERTIES = {"object_id", "target_id", "ability", "trigger_event", "secret_id", "unless_ability"}
# Bits de vecinos de data/tileset_mundo1.json (solid.cardinal_bits).
N, E, S, W = 1, 2, 4, 8


def res_to_path(res):
    return os.path.join(ROOT, res[len("res://"):])


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


# --- Formato .tscn ---

def fmt_number(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    text = repr(float(value))
    return text if text != "-0.0" else "0.0"


def fmt_string(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def fmt_coord(value):
    """Coordenada en px: entera sin decimales si lo es (Vector2(288, 256))."""
    value = float(value)
    return str(int(value)) if value.is_integer() else fmt_number(value)


def fmt_vector2(x, y):
    return "Vector2(%s, %s)" % (fmt_coord(x), fmt_coord(y))


def fmt_value(value, string_name=False):
    if isinstance(value, bool) or isinstance(value, (int, float)):
        return fmt_number(value)
    if isinstance(value, str):
        return ("&" if string_name else "") + fmt_string(value)
    if isinstance(value, list):
        if len(value) == 2 and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in value):
            return fmt_vector2(value[0], value[1])
        return "[" + ", ".join(fmt_value(v) for v in value) + "]"
    if isinstance(value, dict):
        items = ", ".join("%s: %s" % (fmt_string(k), fmt_value(value[k])) for k in sorted(value))
        return "{" + items + "}"
    if value is None:
        return "null"
    raise ValueError("valor no soportado en .tscn: %r" % (value,))


class Scene:
    """Acumula ext_resources, sub_resources y nodos en orden fijo."""

    def __init__(self):
        self.ext = []  # (id, type, path)
        self.ext_ids = {}
        self.sub = []  # (id, type, [(prop, value)])
        self.sub_ids = {}
        self.nodes = []

    def ext_resource(self, kind, path):
        if path not in self.ext_ids:
            rid = "%d_%s" % (len(self.ext) + 1, os.path.splitext(os.path.basename(path))[0])
            self.ext_ids[path] = rid
            self.ext.append((rid, kind, path))
        return 'ExtResource("%s")' % self.ext_ids[path]

    def sub_resource(self, kind, props):
        key = (kind, tuple(props))
        if key not in self.sub_ids:
            rid = "%s_%d" % (kind, len(self.sub) + 1)
            self.sub_ids[key] = rid
            self.sub.append((rid, kind, props))
        return 'SubResource("%s")' % self.sub_ids[key]

    def node(self, name, kind=None, parent=None, instance=None, props=None, groups=None):
        header = '[node name="%s"' % name
        if kind:
            header += ' type="%s"' % kind
        if parent is not None:
            header += ' parent="%s"' % parent
        if instance:
            header += " instance=%s" % instance
        if groups:
            header += " groups=[%s]" % ", ".join(fmt_string(g) for g in groups)
        header += "]"
        self.nodes.append((header, props or []))

    def text(self):
        out = ["[gd_scene load_steps=%d format=3]" % (len(self.ext) + len(self.sub) + 1), ""]
        for rid, kind, path in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
        if self.ext:
            out.append("")
        for rid, kind, props in self.sub:
            out.append('[sub_resource type="%s" id="%s"]' % (kind, rid))
            for prop, value in props:
                out.append("%s = %s" % (prop, value))
            out.append("")
        for header, props in self.nodes:
            out.append(header)
            for prop, value in props:
                out.append("%s = %s" % (prop, value))
            out.append("")
        return "\n".join(out)


# --- Tiles ---

def solid_grid(level, catalog):
    """Grid con las celdas de glitch_wall marcadas como '#' (cuentan como solidas para los bordes)."""
    grid = [list(row) for row in level["grid"]]
    for obj in level.get("objects", []):
        if obj["type"] != "glitch_wall":
            continue
        params = dict(catalog["types"]["glitch_wall"].get("defaults", {}))
        params.update(obj.get("params", {}))
        for dy in range(int(params["height_tiles"])):
            for dx in range(int(params["width_tiles"])):
                grid[obj["y"] + dy][obj["x"] + dx] = "#"
    return ["".join(row) for row in grid]


def select_tile(grid, r, c, m):
    """Reglas de data/tileset_mundo<N>.json (igual que select_tile de tools/gen_tileset_mundo1.py)."""
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
            bits = m["solid"]["diagonal_empty_bits"]
            diag = (bits["NE"] if not solid(-1, 1) else 0) | (bits["SE"] if not solid(1, 1) else 0) | \
                   (bits["SW"] if not solid(1, -1) else 0) | (bits["NW"] if not solid(-1, -1) else 0)
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


def tile_map_data(level, catalog, tilemap):
    """PackedByteArray de TileMapLayer.tile_map_data: version 0 (uint16) y por celda
    x, y (int16), source, atlas x, atlas y, alternativa (uint16), little endian."""
    grid = solid_grid(level, catalog)
    original = level["grid"]
    source = int(tilemap["source_id"])
    data = [0, 0]

    def u16(v):
        v &= 0xFFFF
        return [v & 0xFF, v >> 8]

    for r in range(len(grid)):
        for c in range(len(grid[r])):
            if original[r][c] not in ("#", "-", "^"):
                continue
            atlas = select_tile(grid, r, c, tilemap)
            data += u16(c) + u16(r) + u16(source) + u16(int(atlas[0])) + u16(int(atlas[1])) + u16(0)
    return "PackedByteArray(%s)" % ", ".join(str(b) for b in data)


def spike_runs(level, tilemap):
    """Tramos horizontales de '^' con la misma orientacion: (fila, col_desde, col_hasta, techo)."""
    grid = level["grid"]
    runs = []
    for r, row in enumerate(grid):
        c = 0
        while c < len(row):
            if row[c] != "^":
                c += 1
                continue
            ceiling = select_tile(grid, r, c, tilemap) == tilemap["spikes"]["ceiling"]
            end = c
            while end + 1 < len(row) and row[end + 1] == "^" and \
                    (select_tile(grid, r, end + 1, tilemap) == tilemap["spikes"]["ceiling"]) == ceiling:
                end += 1
            runs.append((r, c, end, ceiling))
            c = end + 1
    return runs


def glitch_neighbors(level, obj, params):
    """Bits N/E/S/W de los lados del bloque con terreno solido ('#') al lado (fuera = solido)."""
    grid = level["grid"]
    rows, cols = len(grid), len(grid[0])
    x, y = obj["x"], obj["y"]
    w, h = int(params["width_tiles"]), int(params["height_tiles"])

    def solid(r, c):
        if 0 <= r < rows and 0 <= c < cols:
            return grid[r][c] == "#"
        return True

    mask = 0
    if any(solid(y - 1, x + i) for i in range(w)):
        mask |= N
    if any(solid(y + j, x + w) for j in range(h)):
        mask |= E
    if any(solid(y + h, x + i) for i in range(w)):
        mask |= S
    if any(solid(y + j, x - 1) for j in range(h)):
        mask |= W
    return mask


def find_cells(grid, char):
    return [(c, r) for r, row in enumerate(grid) for c, ch in enumerate(row) if ch == char]


# --- Escena ---

def help_tag(own, default):
    """(grupos, props) que apuntan un nodo a la ayuda con Q: help_id propio del
    objeto del nivel si lo tiene ("" = sin Q) o el de su tipo."""
    help_id = own.get("help_id", default) if isinstance(own, dict) else default
    if not help_id:
        return [], []
    return [HELP_GROUP], [("metadata/help_id", fmt_string(help_id))]


def enemy_help_id(enemy_type, root=ROOT):
    path = os.path.join(root, "data", "enemies", "%s.json" % enemy_type)
    if not os.path.exists(path):
        return None
    return load_json(path).get("help_id")


def build_scene(level, root=ROOT, warnings=None):
    if warnings is None:
        warnings = []
    world = int(level["world"])
    t = int(level["tile_size"])
    grid = level["grid"]
    rows, cols = len(grid), len(grid[0])
    catalog = load_json(os.path.join(root, "data", "world%d_objects.json" % world))
    tilemap = load_json(os.path.join(root, "data", "tileset_mundo%d.json" % world))
    hazards = load_json(os.path.join(root, HAZARDS_JSON))
    if int(tilemap["tile_size"]) != t or int(catalog["tile_size"]) != t:
        raise ValueError("tile_size del nivel (%d) distinto del tileset o del catalogo" % t)

    def feet(c, r):
        return fmt_vector2((c + 0.5) * t, (r + 1) * t)

    scene = Scene()
    abilities = dict(level.get("abilities_available", {}))
    root_name = "Level_" + level["id"].replace("-", "_")
    scene.node(root_name, "Node2D", props=[
        ("script", scene.ext_resource("Script", LEVEL_SCRIPT)),
        ("level_id", fmt_string(level["id"])),
        ("level_name", fmt_string(level["name"])),
        ("world", str(world)),
        ("tile_size", str(t)),
        ("size_tiles", "Vector2i(%d, %d)" % (cols, rows)),
        ("debug_color", fmt_string(level.get("debug_color", ""))),
        ("abilities_available", fmt_value(abilities)),
        ("source_path", fmt_string("res://data/levels/%s.json" % level["id"])),
    ])

    background = "res://scenes/levels/world%d_background.tscn" % world
    scene.node("Background", parent=".", instance=scene.ext_resource("PackedScene", background))

    scene.node("Tiles", "TileMapLayer", parent=".", props=[
        ("tile_map_data", tile_map_data(level, catalog, tilemap)),
        ("tile_set", scene.ext_resource("TileSet", tilemap["tileset"])),
    ])

    # Pinchos.
    scene.node("Hazards", "Node2D", parent=".")
    spikes = hazards["spikes"]
    height = float(spikes["hitbox_height_px"])
    for r, c0, c1, ceiling in spike_runs(level, tilemap):
        width = (c1 - c0 + 1) * t
        y = r * t + (height * 0.5 if ceiling else t - height * 0.5)
        name = "Spikes_%d_%d" % (c0, r)
        scene.node(name, "Area2D", parent="Hazards", props=[
            ("position", fmt_vector2(c0 * t + width * 0.5, y)),
            ("collision_layer", str(int(spikes["collision_layer"]))),
            ("collision_mask", str(int(spikes["collision_mask"]))),
            ("script", scene.ext_resource("Script", SPIKE_SCRIPT)),
        ])
        shape = scene.sub_resource("RectangleShape2D", [("size", fmt_vector2(width, height))])
        scene.node("CollisionShape2D", "CollisionShape2D", parent="Hazards/" + name, props=[("shape", shape)])

    scene.node("HiddenPlatforms", "Node2D", parent=".")
    for c, r in find_cells(grid, "h"):
        scene.node("Hidden_%d_%d" % (c, r), parent="HiddenPlatforms",
                   instance=scene.ext_resource("PackedScene", HIDDEN_SCENE),
                   props=[("position", fmt_vector2((c + 0.5) * t, (r + 0.5) * t))])

    scene.node("AttentionPoints", "Node2D", parent=".")
    point_groups, point_meta = help_tag(None, catalog.get("attention_point", {}).get("help_id"))
    for c, r in sorted(find_cells(grid, "o")):
        scene.node("Point_%d_%d" % (c, r), parent="AttentionPoints",
                   instance=scene.ext_resource("PackedScene", POINT_SCENE),
                   props=[("position", fmt_vector2((c + 0.5) * t, (r + 0.5) * t))] + point_meta,
                   groups=point_groups)

    scene.node("Checkpoints", "Node2D", parent=".")
    for cp in level.get("checkpoints", []):
        cp_groups, cp_meta = help_tag(cp, catalog.get("checkpoint", {}).get("help_id"))
        scene.node(cp["id"], "Marker2D", parent="Checkpoints", groups=["checkpoint"] + cp_groups, props=[
            ("position", feet(cp["x"], cp["y"])),
            ("script", scene.ext_resource("Script", CHECKPOINT_SCRIPT)),
            ("checkpoint_id", "&" + fmt_string(cp["id"])),
        ] + cp_meta)

    scene.node("Secrets", "Node2D", parent=".")
    for secret in level.get("secrets", []):
        if secret.get("object"):
            continue
        scene.node(secret["id"], "Marker2D", parent="Secrets", groups=["secret"], props=[
            ("position", fmt_vector2((secret["x"] + 0.5) * t, (secret["y"] + 0.5) * t)),
            ("metadata/secret_id", fmt_string(secret["id"])),
        ])

    # Objetos del catalogo.
    scene.node("Objects", "Node2D", parent=".")
    used_names = set()
    for obj in level.get("objects", []):
        entry = catalog["types"][obj["type"]]
        params = dict(entry.get("defaults", {}))
        params.update(obj.get("params", {}))
        name = str(params.get("id") or "%s_%d_%d" % (obj["type"], obj["x"], obj["y"]))
        if name in used_names:
            raise ValueError("nombre de objeto repetido: %s" % name)
        used_names.add(name)
        props = [("position", fmt_vector2(obj["x"] * t, obj["y"] * t))]
        if obj["type"] == "glitch_wall":
            computed = glitch_neighbors(level, obj, params)
            if "solid_neighbors" in obj.get("params", {}) and int(obj["params"]["solid_neighbors"]) != computed:
                warnings.append("glitch_wall (%d, %d): solid_neighbors del JSON %s != calculado del grid %d "
                                "(se usa el calculado)" % (obj["x"], obj["y"], obj["params"]["solid_neighbors"],
                                                           computed))
            params["solid_neighbors"] = computed
        for field in sorted(params):
            prop = entry["fields"].get(field)
            if prop is None:
                raise ValueError("%s: param '%s' sin propiedad en el catalogo" % (obj["type"], field))
            props.append((prop, fmt_value(params[field], prop in STRING_NAME_PROPERTIES)))
        if obj["type"] in ("exit_door", "exit_terminal"):
            props.append(("level_id", fmt_string(level["id"])))
        obj_groups, obj_meta = help_tag(obj, entry.get("help_id"))
        scene.node(name, parent="Objects", instance=scene.ext_resource("PackedScene", entry["scene"]),
                   props=props + obj_meta, groups=obj_groups)

    scene.node("Enemies", "Node2D", parent=".")
    for enemy in level.get("enemies", []):
        path = "res://scenes/enemies/%s.tscn" % enemy["type"]
        if not os.path.exists(res_to_path(path).replace("/", os.sep)) and root == ROOT:
            raise ValueError("no existe la escena del enemigo %s: %s" % (enemy["id"], path))
        params = enemy.get("params", {})
        props = [("position", feet(enemy["x"], enemy["y"]))]
        if "patrol_range_px" in params:
            props.append(("patrol_range_px", fmt_number(params["patrol_range_px"])))
        props.append(("metadata/params", fmt_value(params)))
        enemy_groups, enemy_meta = help_tag(enemy, enemy_help_id(enemy["type"], root))
        scene.node(enemy["id"], parent="Enemies", instance=scene.ext_resource("PackedScene", path),
                   props=props + enemy_meta, groups=enemy_groups)

    goal = find_cells(grid, "G")[0]
    scene.node("Goal", "Marker2D", parent=".", groups=["goal"], props=[("position", feet(*goal))])

    start = find_cells(grid, "P")[0]
    scene.node("Isak", parent=".", instance=scene.ext_resource("PackedScene", ISAK_SCENE), props=[
        ("position", feet(*start)),
        ("camera_limits", "Rect2i(0, 0, %d, %d)" % (cols * t, rows * t)),
    ])
    scene.node("Hud", parent=".", instance=scene.ext_resource("PackedScene", HUD_SCENE))
    scene.node("EcoTextBox", parent=".", instance=scene.ext_resource("PackedScene", ECO_SCENE))
    scene.node("Help", "Node", parent=".", props=[("script", scene.ext_resource("Script", HELP_SCRIPT))])
    return scene.text()


def output_path(level, root=ROOT):
    return os.path.join(root, "scenes", "levels", "%s.tscn" % level["id"])


def main(argv):
    parser = argparse.ArgumentParser(description="Genera scenes/levels/<id>.tscn desde data/levels/<id>.json.")
    parser.add_argument("levels", nargs="+", help="JSON de nivel (data/levels/<id>.json)")
    parser.add_argument("--check", action="store_true", help="no escribe; sale con 1 si el .tscn no esta al dia")
    parser.add_argument("--stdout", action="store_true", help="imprime la escena en vez de escribirla")
    args = parser.parse_args(argv[1:])
    status = 0
    for path in args.levels:
        level = load_json(path)
        warnings = []
        text = build_scene(level, warnings=warnings)
        for message in warnings:
            print("aviso: %s: %s" % (path, message), file=sys.stderr)
        out = output_path(level)
        rel = os.path.relpath(out, ROOT)
        if args.stdout:
            sys.stdout.write(text)
            continue
        current = None
        if os.path.exists(out):
            with open(out, encoding="utf-8") as handle:
                current = handle.read()
        if args.check:
            if current != text:
                print("%s no esta al dia con %s (python3 tools/build_level.py %s)" % (rel, path, path))
                status = 1
            else:
                print("%s: al dia" % rel)
            continue
        if current == text:
            print("%s: sin cambios" % rel)
            continue
        with open(out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print("%s: escrito" % rel)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
