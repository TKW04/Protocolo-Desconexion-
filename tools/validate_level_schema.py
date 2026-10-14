#!/usr/bin/env python3
"""Validador de ESQUEMA y reglas estructurales de un nivel (data/levels/<m>-<n>.json).

No comprueba alcanzabilidad (eso es tools/validate_level.py, paso 15): solo que el
archivo tenga la forma que espera el generador de niveles.

Reglas:
  - campos obligatorios y sus tipos; tile_size igual al de data/isak_physics.json;
  - grid rectangular, solo caracteres de la leyenda, al menos ceil(720 / tile_size) filas;
  - exactamente un P y un G;
  - checkpoints <-> celdas C del grid (uno a uno), enemigos <-> celdas E (uno a uno),
    secretos <-> celdas S, o {object: <tipo>} con un objeto de ese tipo en su x, y;
  - enemigos con tipo existente (data/enemies/<type>.json);
  - objects {type, x, y, params} con tipo del catalogo (data/world<N>_objects.json),
    params obligatorios presentes y sin params desconocidos, dentro del grid, y sin
    pisar terreno; receptores apuntando a un puente existente; la puerta de salida
    contiene la G;
  - ids unicos (checkpoints, enemigos, secretos y params.id de los objetos);
  - sin pinchos en P ni en C ni en las 8 celdas vecinas de una C.

Uso: python3 tools/validate_level_schema.py data/levels/1-1.json [...]
Sale con 0 si todo esta bien y 1 si hay errores (con fila/columna cuando aplica).
"""

import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRID_CHARS = set("#.^-hPGCoES")
SCREEN_HEIGHT_PX = 720
REQUIRED_FIELDS = {
    "id": str,
    "name": str,
    "world": int,
    "tile_size": int,
    "debug_color": str,
    "grid": list,
    "checkpoints": list,
    "secrets": list,
    "enemies": list,
    "objects": list,
    "unlocks": list,
}
KNOWN_ABILITIES = {"pulse", "debug"}
# Objetos que ocupan celdas que el grid debe dejar vacias ('.'): son solidos o lo seran.
BLOCKING_TYPES = {"bridge_inactive", "glitch_wall", "popup_blocker"}
# Objetos que no pueden estar dentro de terreno solido ni de pinchos.
NON_SOLID_PLACED = {"receiver", "exit_door"}


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value):
    return (isinstance(value, (int, float))) and not isinstance(value, bool)


class LevelValidator:
    def __init__(self, level, root=ROOT):
        self.level = level
        self.root = root
        self.errors = []
        self.grid = []
        self.width = 0
        self.height = 0
        self.ids = {}
        self.object_anchors = set()

    def error(self, message, row=None, col=None):
        if row is not None and col is not None:
            message = "fila %d, columna %d: %s" % (row, col, message)
        self.errors.append(message)

    def cell(self, x, y):
        return self.grid[y][x]

    def in_bounds(self, x, y):
        return 0 <= x < self.width and 0 <= y < self.height

    # --- Carga de datos auxiliares ---

    def _load_json(self, rel_path):
        path = os.path.join(self.root, rel_path)
        try:
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, ValueError) as exc:
            self.error("no se pudo leer %s (%s)" % (rel_path, exc))
            return None

    # --- Reglas ---

    def validate(self):
        if not isinstance(self.level, dict):
            self.error("el nivel debe ser un objeto JSON")
            return self.errors
        self._check_fields()
        if self.errors:
            return self.errors
        self._check_grid()
        if self.errors:
            return self.errors
        self._check_markers()
        self._check_checkpoints()
        self._check_enemies()
        self._check_objects()
        self._check_secrets()
        self._check_spikes()
        self._check_unlocks()
        self._check_sections()
        return self.errors

    def _check_fields(self):
        for key, kind in REQUIRED_FIELDS.items():
            if key not in self.level:
                self.error("falta el campo obligatorio '%s'" % key)
            elif kind is int and not _is_int(self.level[key]):
                self.error("'%s' debe ser un entero" % key)
            elif kind is not int and not isinstance(self.level[key], kind):
                self.error("'%s' debe ser de tipo %s" % (key, kind.__name__))
        if self.errors:
            return
        if not re.fullmatch(r"\d+-\d+", self.level["id"]):
            self.error("'id' debe tener la forma <mundo>-<nivel> (p. ej. 1-1)")
        elif int(self.level["id"].split("-")[0]) != self.level["world"]:
            self.error("'id' (%s) no coincide con 'world' (%d)" % (self.level["id"], self.level["world"]))
        physics = self._load_json("data/isak_physics.json")
        if physics is not None and self.level["tile_size"] != int(physics.get("tile_size", 0)):
            self.error("tile_size %d distinto del de data/isak_physics.json (%s)"
                       % (self.level["tile_size"], physics.get("tile_size")))
        abilities = self.level.get("abilities_available", {})
        if not isinstance(abilities, dict):
            self.error("'abilities_available' debe ser un objeto {habilidad: bool}")
        else:
            for name, value in abilities.items():
                if name not in KNOWN_ABILITIES:
                    self.error("habilidad desconocida en abilities_available: '%s'" % name)
                elif not isinstance(value, bool):
                    self.error("abilities_available.%s debe ser true o false" % name)

    def _check_grid(self):
        grid = self.level["grid"]
        if not grid or not all(isinstance(row, str) for row in grid):
            self.error("'grid' debe ser una lista no vacia de cadenas")
            return
        self.grid = grid
        self.height = len(grid)
        self.width = len(grid[0])
        for y, row in enumerate(grid):
            if len(row) != self.width:
                self.error("la fila mide %d y la primera %d (grid no rectangular)"
                           % (len(row), self.width), y, min(len(row), self.width) - 1)
            for x, char in enumerate(row):
                if char not in GRID_CHARS:
                    self.error("caracter no valido '%s'" % char, y, x)
        min_rows = math.ceil(SCREEN_HEIGHT_PX / self.level["tile_size"])
        if self.height < min_rows:
            self.error("el grid tiene %d filas; hacen falta al menos %d para %d px de alto"
                       % (self.height, min_rows, SCREEN_HEIGHT_PX))

    def _cells_with(self, char):
        return [(x, y) for y, row in enumerate(self.grid) for x, c in enumerate(row) if c == char]

    def _check_markers(self):
        for char, name in (("P", "inicio (P)"), ("G", "meta (G)")):
            cells = self._cells_with(char)
            if len(cells) != 1:
                where = ", ".join("fila %d columna %d" % (y, x) for x, y in cells) or "ninguno"
                self.error("debe haber exactamente un %s y hay %d (%s)" % (name, len(cells), where))

    def _register_id(self, ident, what):
        if not isinstance(ident, str) or not ident:
            self.error("%s sin 'id' de texto" % what)
            return
        if ident in self.ids:
            self.error("id duplicado '%s' (%s y %s)" % (ident, self.ids[ident], what))
        else:
            self.ids[ident] = what

    def _check_point_entry(self, entry, what):
        """Comprueba {id, x, y} y devuelve (x, y) o None."""
        if not isinstance(entry, dict):
            self.error("%s debe ser un objeto" % what)
            return None
        self._register_id(entry.get("id"), what)
        x, y = entry.get("x"), entry.get("y")
        if not (_is_int(x) and _is_int(y)):
            self.error("%s '%s' necesita x e y enteros" % (what, entry.get("id")))
            return None
        if not self.in_bounds(x, y):
            self.error("%s '%s' fuera del grid" % (what, entry.get("id")), y, x)
            return None
        return (x, y)

    def _check_paired(self, entries, char, what):
        listed = set()
        for i, entry in enumerate(entries):
            pos = self._check_point_entry(entry, "%s %d" % (what, i))
            if pos is None:
                continue
            listed.add(pos)
            if self.cell(*pos) != char:
                self.error("%s '%s' no esta sobre una celda '%s' (hay '%s')"
                           % (what, entry.get("id"), char, self.cell(*pos)), pos[1], pos[0])
        for (x, y) in self._cells_with(char):
            if (x, y) not in listed:
                self.error("celda '%s' sin entrada en la lista de %s" % (char, what), y, x)

    def _check_checkpoints(self):
        self._check_paired(self.level["checkpoints"], "C", "checkpoints")

    def _check_enemies(self):
        self._check_paired(self.level["enemies"], "E", "enemies")
        for entry in self.level["enemies"]:
            if not isinstance(entry, dict):
                continue
            kind = entry.get("type")
            if not isinstance(kind, str) or not os.path.isfile(
                    os.path.join(self.root, "data", "enemies", "%s.json" % kind)):
                self.error("enemigo '%s': tipo '%s' sin data/enemies/%s.json"
                           % (entry.get("id"), kind, kind))
            params = entry.get("params", {})
            if not isinstance(params, dict):
                self.error("enemigo '%s': 'params' debe ser un objeto" % entry.get("id"))
                continue
            for key, value in params.items():
                if not _is_number(value) or value <= 0:
                    self.error("enemigo '%s': params.%s debe ser un numero > 0" % (entry.get("id"), key))

    def _footprint(self, kind, x, y, params, defaults):
        def get(name, fallback):
            return params.get(name, defaults.get(name, fallback))
        if kind == "bridge_inactive":
            length = get("length_tiles", 1)
            step = -1 if get("direction", "right") == "left" else 1
            if not _is_int(length) or length < 1:
                return None
            return [(x + step * i, y) for i in range(length)]
        if kind == "receiver":
            return [(x, y)]
        w, h = get("width_tiles", 1), get("height_tiles", 1)
        if not (_is_int(w) and _is_int(h)) or w < 1 or h < 1:
            return None
        return [(x + i, y + j) for j in range(h) for i in range(w)]

    def _check_objects(self):
        catalog_path = "data/world%d_objects.json" % self.level["world"]
        catalog = self._load_json(catalog_path)
        if catalog is None:
            return
        types = catalog.get("types", {})
        bridges = set()
        receivers = []
        doors = []
        self.object_anchors = set()
        for i, obj in enumerate(self.level["objects"]):
            what = "objects[%d]" % i
            if not isinstance(obj, dict):
                self.error("%s debe ser un objeto {type, x, y, params}" % what)
                continue
            missing = [k for k in ("type", "x", "y", "params") if k not in obj]
            if missing:
                self.error("%s: faltan %s" % (what, ", ".join(missing)))
                continue
            kind, x, y, params = obj["type"], obj["x"], obj["y"], obj["params"]
            if kind not in types:
                self.error("%s: tipo '%s' no esta en %s" % (what, kind, catalog_path))
                continue
            what = "%s (%s)" % (what, kind)
            if not (_is_int(x) and _is_int(y)):
                self.error("%s: x e y deben ser enteros" % what)
                continue
            if not isinstance(params, dict):
                self.error("%s: 'params' debe ser un objeto" % what)
                continue
            if not self.in_bounds(x, y):
                self.error("%s fuera del grid" % what, y, x)
                continue
            entry = types[kind]
            for field in entry.get("required", []):
                if field not in params:
                    self.error("%s: falta el param obligatorio '%s'" % (what, field), y, x)
            for field in params:
                if field not in entry.get("fields", {}):
                    self.error("%s: param desconocido '%s'" % (what, field), y, x)
            for field in ("text",):
                if field in params and (not isinstance(params[field], str) or not params[field].strip()):
                    self.error("%s: '%s' debe ser un texto no vacio" % (what, field), y, x)
            self.object_anchors.add((kind, (x, y)))
            if "id" in params:
                self._register_id(params["id"], what)
            cells = self._footprint(kind, x, y, params, entry.get("defaults", {}))
            if cells is None:
                self.error("%s: tamano no valido (width/height/length deben ser enteros >= 1)" % what, y, x)
                continue
            for (cx, cy) in cells:
                if not self.in_bounds(cx, cy):
                    self.error("%s: se sale del grid" % what, cy, cx)
                    break
                char = self.cell(cx, cy)
                if kind in BLOCKING_TYPES and char != ".":
                    self.error("%s ocupa una celda que el grid debe dejar vacia ('.'), hay '%s'"
                               % (what, char), cy, cx)
                elif kind in NON_SOLID_PLACED and char in "#^":
                    self.error("%s dentro de terreno o pinchos ('%s')" % (what, char), cy, cx)
            if kind == "bridge_inactive":
                if params.get("direction", "right") not in ("left", "right"):
                    self.error("%s: direction debe ser 'left' o 'right'" % what, y, x)
                bridges.add(params.get("id"))
            elif kind == "receiver":
                receivers.append((what, x, y, params.get("target")))
            elif kind == "exit_door":
                doors.append((what, x, y, set(cells)))
        for (what, x, y, target) in receivers:
            if target not in bridges:
                self.error("%s: target '%s' no es el id de ningun bridge_inactive" % (what, target), y, x)
        goals = self._cells_with("G")
        for (what, x, y, cells) in doors:
            if len(goals) == 1 and goals[0] not in cells:
                self.error("%s no contiene la meta G (fila %d, columna %d)"
                           % (what, goals[0][1], goals[0][0]), y, x)

    def _check_secrets(self):
        listed = set()
        for i, entry in enumerate(self.level["secrets"]):
            what = "secrets %d" % i
            if not isinstance(entry, dict):
                self.error("%s debe ser un objeto" % what)
                continue
            pos = self._check_point_entry(entry, what)
            if pos is None:
                continue
            if "object" in entry:
                if (entry["object"], pos) not in self.object_anchors:
                    self.error("%s '%s': no hay ningun objeto '%s' en esa celda"
                               % (what, entry.get("id"), entry["object"]), pos[1], pos[0])
                continue
            listed.add(pos)
            if self.cell(*pos) != "S":
                self.error("%s '%s' no esta sobre una celda 'S' ni referencia un objeto"
                           % (what, entry.get("id")), pos[1], pos[0])
        for (x, y) in self._cells_with("S"):
            if (x, y) not in listed:
                self.error("celda 'S' sin entrada en la lista de secrets", y, x)

    def _check_spikes(self):
        for (x, y) in self._cells_with("P"):
            if y + 1 < self.height and self.cell(x, y + 1) == "^":
                self.error("pinchos justo debajo del inicio P", y + 1, x)
        for (x, y) in self._cells_with("C"):
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if self.in_bounds(nx, ny) and self.cell(nx, ny) == "^":
                        self.error("pinchos junto al punto de sincronizacion C (fila %d, columna %d)"
                                   % (y, x), ny, nx)

    def _check_unlocks(self):
        for i, entry in enumerate(self.level["unlocks"]):
            if not isinstance(entry, dict) or not isinstance(entry.get("type"), str) \
                    or not isinstance(entry.get("id"), str):
                self.error("unlocks[%d] debe ser {\"type\": texto, \"id\": texto}" % i)


    def _check_sections(self):
        """'sections' (opcional): tramos del documento en orden, [x_from, x_to] sin solaparse."""
        sections = self.level.get("sections", [])
        if not isinstance(sections, list):
            self.error("'sections' debe ser una lista")
            return
        previous_end = -1
        for i, entry in enumerate(sections):
            if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
                self.error("sections[%d] debe ser {name, x_from, x_to}" % i)
                continue
            x0, x1 = entry.get("x_from"), entry.get("x_to")
            if not (_is_int(x0) and _is_int(x1)) or not (0 <= x0 <= x1 < self.width):
                self.error("sections[%d] '%s': x_from/x_to no validos" % (i, entry["name"]))
                continue
            if x0 <= previous_end:
                self.error("sections[%d] '%s' se solapa o va antes que la anterior" % (i, entry["name"]))
            previous_end = x1


def validate_level(level, root=ROOT):
    """Devuelve la lista de errores (vacia si el nivel es valido)."""
    return LevelValidator(level, root).validate()


def validate_file(path, root=ROOT):
    try:
        with open(path, encoding="utf-8") as handle:
            level = json.load(handle)
    except (OSError, ValueError) as exc:
        return ["no se pudo leer %s (%s)" % (path, exc)]
    return validate_level(level, root)


def main(argv):
    if len(argv) < 2:
        print("Uso: python3 tools/validate_level_schema.py data/levels/<m>-<n>.json [...]", file=sys.stderr)
        return 2
    failed = False
    for path in argv[1:]:
        errors = validate_file(path)
        if errors:
            failed = True
            print("%s: %d error(es)" % (path, len(errors)))
            for message in errors:
                print("  - " + message)
        else:
            print("%s: OK" % path)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
