"""Pruebas de tools/validate_level_schema.py sobre data/levels/1-1.json y variantes rotas.
Uso: python3 -m unittest tests/test_level_schema.py
"""

import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level_schema as vls  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "1-1.json")
SCRIPT = os.path.join(ROOT, "tools", "validate_level_schema.py")


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def set_cell(level, x, y, char):
    row = level["grid"][y]
    level["grid"][y] = row[:x] + char + row[x + 1:]


def find(level, char):
    for y, row in enumerate(level["grid"]):
        x = row.find(char)
        if x >= 0:
            return x, y
    raise AssertionError("no hay '%s' en el grid" % char)


def obj(level, kind):
    return next(o for o in level["objects"] if o["type"] == kind)


class LevelSchemaTest(unittest.TestCase):
    def setUp(self):
        self.level = load_level()

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(errors, "se esperaba un error con '%s'" % fragment)
        self.assertTrue(any(fragment in e for e in errors),
                        "ningun error contiene '%s': %s" % (fragment, errors))

    # --- Nivel real ---

    def test_level_1_1_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])

    def test_level_1_1_design_requirements(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["tile_size"], lvl["debug_color"]),
                         ("1-1", "Bandeja de entrada", 1, 64, "cyan"))
        self.assertEqual(lvl["abilities_available"], {"pulse": True, "debug": False})
        self.assertNotIn("debug", json.dumps(lvl["unlocks"]))
        self.assertGreaterEqual(len(lvl["grid"]), 12)
        self.assertEqual("".join(lvl["grid"]).count("^"), 0, "1-1 sin pinchos")
        # Economia (decision 2026-10-15, docs/propuesta-1-1-ampliado.md §6): pocos puntos por mapa
        # (los puntos no se recapturan). Solo la ruta no paga ninguna mejora; la ruta y los secretos
        # sin mejora pagan la primera (Pulso amplio) y ninguna otra cabe en un recorrido completo.
        points = "".join(lvl["grid"]).count("o")
        with open(os.path.join(ROOT, "data", "upgrades.json"), encoding="utf-8") as handle:
            upgrades = {u["id"]: u for u in json.load(handle)["upgrades"]}
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        gated_points = sum(int(s.get("points", 0)) for s in lvl["secrets"] if s.get("requires_upgrade"))
        route = points - secret_points
        self.assertEqual((points, route, secret_points, gated_points), (35, 20, 15, 5))
        costs = {uid: u["cost"]["attention_points"] for uid, u in upgrades.items()}
        self.assertLess(route, min(costs.values()), "la ruta sola no paga ninguna mejora")
        self.assertGreaterEqual(points - gated_points, costs["wide_pulse"], "el 1-1 completo paga Pulso amplio")
        for uid, cost in costs.items():
            if uid != "wide_pulse":
                self.assertGreater(cost, points, "%s no se paga con un solo 1-1" % uid)
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (300, 14))
        banks = [o for o in lvl["objects"] if o["type"] == "power_bank_pickup"]
        self.assertEqual(banks, [], "sin power banks en el 1-1: aparecen desde el 1-2 (con el Debug)")
        wide = next(s for s in lvl["secrets"] if s.get("requires_upgrade"))
        self.assertEqual((wide["id"], wide["requires_upgrade"]), ("secreto_pulso_amplio", "wide_pulse"))
        kinds = [o["type"] for o in lvl["objects"]]
        for kind in ("eco_line", "receiver", "bridge_inactive", "popup_blocker", "exit_door", "glitch_wall"):
            self.assertIn(kind, kinds)
        self.assertEqual(obj(lvl, "eco_line")["params"]["text"], "Bienvenido. He optimizado tu espacio.")
        self.assertEqual(obj(lvl, "exit_door")["params"]["text"], "Marcar como leído")
        # Orden de los tramos: aterrizaje -> puente -> Burbuja -> pop-up -> puerta.
        popup_1 = next(o for o in lvl["objects"] if o["params"].get("id") == "popup_1")
        xs = [obj(lvl, "eco_line")["x"], obj(lvl, "bridge_inactive")["x"], lvl["enemies"][0]["x"],
              popup_1["x"], obj(lvl, "exit_door")["x"]]
        self.assertEqual(xs, sorted(xs))
        # Un solo punto de sincronizacion, a mitad del mapa (decision 2026-10-14).
        self.assertEqual(len(lvl["checkpoints"]), 1)
        cx = lvl["checkpoints"][0]["x"]
        width = len(lvl["grid"][0])
        self.assertLessEqual(abs(cx - width / 2), width * 0.05)

    def test_level_1_1_jumps_within_margin(self):
        """Saltos del 1-1 dentro del 85 % del alcance (mismas formulas que PlayerPhysics).
        No es la validacion de alcanzabilidad (paso 15): solo las medidas pensadas."""
        with open(os.path.join(ROOT, "data", "isak_physics.json"), encoding="utf-8") as handle:
            phys = json.load(handle)
        tile = phys["tile_size"]
        g, v, m = phys["gravity"], phys["jump_velocity"], phys["fall_gravity_multiplier"]
        max_height = v * v / (2.0 * g)
        t_air = abs(v) / g + (2.0 * max_height / (g * m)) ** 0.5
        walk_gap_tiles = 0.85 * phys["walk_speed"] * t_air / tile
        step_tiles = 0.85 * max_height / tile
        real_height_tiles = 0.92 * max_height / tile  # el salto real a 60 Hz llega a ~92 %
        grid = self.level["grid"]
        rows = len(grid)

        def surface(x):
            # Suelo pisable: cima del bloque solido que sube desde la ultima fila
            # (un techo colgado, como el del Tramo 3, no es suelo).
            y = rows
            while y > 0 and grid[y - 1][x] == "#":
                y -= 1
            return y

        # Puentes de la ruta (hacia la derecha; el de servicio del secreto A va por el aire).
        bridges = [o for o in self.level["objects"]
                   if o["type"] == "bridge_inactive" and o["params"].get("direction", "right") == "right"]
        bridge_cols = set()
        for bridge in bridges:
            bridge_cols |= set(range(bridge["x"], bridge["x"] + bridge["params"]["length_tiles"]))
        width = len(grid[0])
        for x in range(1, width - 2):
            if x in bridge_cols or x + 1 in bridge_cols or surface(x + 1) == 0:
                continue  # puente o pared de limite hasta arriba
            rise = surface(x) - surface(x + 1)
            if rise > 0:
                self.assertLessEqual(rise, step_tiles,
                                     "subida de %d tiles en la columna %d" % (rise, x + 1))
        # Fosos: tramos de suelo al mismo nivel con los dos vecinos >= 2 tiles mas altos.
        # Fuera del puente deben poder saltarse caminando.
        segments = []
        for x in range(1, width - 1):
            if segments and segments[-1][2] == surface(x):
                segments[-1][1] = x
            else:
                segments.append([x, x, surface(x)])
        for left, seg, right in zip(segments, segments[1:], segments[2:]):
            if seg[0] in bridge_cols or seg[1] in bridge_cols:
                continue
            if seg[2] - left[2] >= 2 and seg[2] - right[2] >= 2:
                gap = seg[1] - seg[0] + 1
                self.assertLessEqual(gap, walk_gap_tiles, "foso de %d tiles en la columna %d" % (gap, seg[0]))
        # Los fosos de los puentes no se pueden saltar ni trepar: el puente es necesario.
        for bridge in bridges:
            length = bridge["params"]["length_tiles"]
            after = bridge["x"] + length
            self.assertGreater(length, 0.85 * phys["run_speed"] * t_air / tile, bridge["params"]["id"])
            self.assertGreater(surface(after - 1) - surface(after), real_height_tiles, bridge["params"]["id"])

    def test_level_1_1_tramo3_low_ceiling(self):
        """Tramo 3 (decision 2026-10-14): techo bajo de 2 tiles sobre toda la patrulla de la
        Burbuja (y algo mas), con escalones de 3 tiles a los lados y la cara de arriba fuera
        del alcance del salto. La prueba de simulacion es tests/test_tramo3_ceiling.gd."""
        with open(os.path.join(ROOT, "data", "isak_physics.json"), encoding="utf-8") as handle:
            phys = json.load(handle)
        with open(os.path.join(ROOT, "data", "enemies", "alert_bubble.json"), encoding="utf-8") as handle:
            bubble_data = json.load(handle)
        for bubble in self.level["enemies"]:
            with self.subTest(bubble=bubble["id"]):
                self._check_low_ceiling(bubble, phys, bubble_data)

    def _check_low_ceiling(self, bubble, phys, bubble_data):
        tile = phys["tile_size"]
        grid = self.level["grid"]
        floor_y = bubble["y"] + 1

        def ceiling(x):
            """(fila de abajo, fila de arriba) del techo colgado sobre el suelo, o None."""
            y = floor_y - 1
            while y >= 0 and grid[y][x] != "#":
                y -= 1
            if y < 0:
                return None
            top = y
            while top > 0 and grid[top - 1][x] == "#":
                top -= 1
            return y, top

        half_range = bubble["params"]["patrol_range_px"] / 2.0 + bubble_data["body_size"][0] / 2.0
        center = (bubble["x"] + 0.5) * tile
        first = int((center - half_range) // tile) - 1
        last = int((center + half_range) // tile) + 1
        for x in range(first, last + 1):
            c = ceiling(x)
            self.assertIsNotNone(c, "techo sobre la columna %d" % x)
            self.assertEqual(floor_y - 1 - c[0], 2, "hueco de 2 tiles en la columna %d" % x)
            self.assertGreater((floor_y - c[1]) * tile, phys["jump_height_px"],
                               "la cara de arriba del techo no se alcanza saltando (columna %d)" % x)
        # Escalones a los dos lados del tramo de 2 tiles: hueco de 3 tiles.
        def clearance(x):
            c = ceiling(x)
            return None if c is None else floor_y - 1 - c[0]
        while clearance(first - 1) == 2:
            first -= 1
        while clearance(last + 1) == 2:
            last += 1
        for x in (first - 1, last + 1):
            c = ceiling(x)
            self.assertIsNotNone(c, "escalon en la columna %d" % x)
            self.assertEqual(floor_y - 1 - c[0], 3, "escalon de 3 tiles en la columna %d" % x)
        # Bajo el techo Isak no levanta los pies por encima de la Burbuja.
        isak_height = 80.0
        self.assertLess(2 * tile - isak_height, bubble_data["body_size"][1])

    # --- Variantes rotas ---

    def test_missing_field(self):
        del self.level["objects"]
        self.assert_fails(self.level, "falta el campo obligatorio 'objects'")

    def test_tile_size_must_match_physics(self):
        self.level["tile_size"] = 32
        self.assert_fails(self.level, "tile_size 32")

    def test_non_rectangular_grid(self):
        self.level["grid"][5] = self.level["grid"][5][:-1]
        self.assert_fails(self.level, "fila 5, columna")

    def test_invalid_char(self):
        set_cell(self.level, 10, 3, "X")
        self.assert_fails(self.level, "fila 3, columna 10: caracter no valido 'X'")

    def test_too_few_rows(self):
        self.level["grid"] = self.level["grid"][-11:]
        self.assert_fails(self.level, "al menos 12")

    def test_two_starts(self):
        set_cell(self.level, 10, 3, "P")
        self.assert_fails(self.level, "exactamente un inicio (P)")

    def test_no_goal(self):
        x, y = find(self.level, "G")
        set_cell(self.level, x, y, ".")
        self.assert_fails(self.level, "exactamente un meta (G)")

    def test_checkpoint_not_on_c(self):
        self.level["checkpoints"][0]["x"] += 1
        self.assert_fails(self.level, "no esta sobre una celda 'C'")
        self.assert_fails(self.level, "celda 'C' sin entrada")

    def test_spike_next_to_checkpoint(self):
        x, y = find(self.level, "C")
        set_cell(self.level, x + 1, y + 1, "^")
        self.assert_fails(self.level, "fila %d, columna %d: pinchos junto al punto de sincronizacion" % (y + 1, x + 1))

    def test_spike_under_start(self):
        x, y = find(self.level, "P")
        set_cell(self.level, x, y + 1, "^")
        self.assert_fails(self.level, "pinchos justo debajo del inicio P")

    def test_enemy_unknown_type(self):
        self.level["enemies"][0]["type"] = "banner_inexistente"
        self.assert_fails(self.level, "sin data/enemies/banner_inexistente.json")

    def test_enemy_cell_without_entry(self):
        self.level["enemies"] = []
        self.assert_fails(self.level, "celda 'E' sin entrada")

    def test_unknown_object_type(self):
        self.level["objects"].append({"type": "teleport", "x": 2, "y": 2, "params": {}})
        self.assert_fails(self.level, "tipo 'teleport' no esta en data/world1_objects.json")

    def test_object_missing_required_param(self):
        del obj(self.level, "popup_blocker")["params"]["close_button_px"]
        self.assert_fails(self.level, "falta el param obligatorio 'close_button_px'")

    def test_object_unknown_param(self):
        obj(self.level, "exit_door")["params"]["color"] = "rojo"
        self.assert_fails(self.level, "param desconocido 'color'")

    def test_object_missing_fields(self):
        self.level["objects"].append({"type": "receiver", "x": 2})
        self.assert_fails(self.level, "faltan y, params")

    def test_receiver_bad_target(self):
        obj(self.level, "receiver")["params"]["target"] = "puente_x"
        self.assert_fails(self.level, "target 'puente_x' no es el id de ningun bridge_inactive")

    def test_blocking_object_over_terrain(self):
        popup = obj(self.level, "popup_blocker")
        set_cell(self.level, popup["x"] + 1, popup["y"] + 1, "#")
        self.assert_fails(self.level, "fila %d, columna %d: objects" % (popup["y"] + 1, popup["x"] + 1))

    def test_object_out_of_grid(self):
        obj(self.level, "bridge_inactive")["params"]["length_tiles"] = 500
        self.assert_fails(self.level, "se sale del grid")

    def test_exit_door_must_contain_goal(self):
        obj(self.level, "exit_door")["x"] -= 3
        self.assert_fails(self.level, "no contiene la meta G")

    def test_duplicate_ids(self):
        self.level["checkpoints"][0]["id"] = "burbuja_1"
        self.assert_fails(self.level, "id duplicado 'burbuja_1'")

    def test_secret_without_object(self):
        glitch = next(e for e in self.level["secrets"] if e.get("object") == "glitch_wall")
        glitch["x"] -= 1
        self.assert_fails(self.level, "no hay ningun objeto 'glitch_wall' en esa celda")

    def test_secret_requires_unknown_upgrade(self):
        wide = next(e for e in self.level["secrets"] if e.get("requires_upgrade"))
        wide["requires_upgrade"] = "no_existe"
        self.assert_fails(self.level, "requires_upgrade 'no_existe' no esta en data/upgrades.json")

    def test_secret_needs_debug_must_be_bool(self):
        self.level["secrets"][0]["needs_debug"] = "si"
        self.assert_fails(self.level, "needs_debug debe ser booleano")

    def test_unknown_ability(self):
        self.level["abilities_available"]["dash"] = True
        self.assert_fails(self.level, "habilidad desconocida")

    def test_sections_out_of_order(self):
        self.level["sections"].reverse()
        self.assert_fails(self.level, "se solapa o va antes")

    # --- Linea de comandos ---

    def _run(self, level):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "nivel.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(level, handle, ensure_ascii=False)
            return subprocess.run([sys.executable, SCRIPT, path], capture_output=True, text=True)

    def test_cli_exit_codes(self):
        self.assertEqual(self._run(self.level).returncode, 0)
        broken = copy.deepcopy(self.level)
        set_cell(broken, 10, 3, "X")
        result = self._run(broken)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fila 3, columna 10", result.stdout)


if __name__ == "__main__":
    unittest.main()
