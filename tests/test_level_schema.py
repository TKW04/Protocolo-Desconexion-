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
sys.path.insert(0, os.path.join(ROOT, "tests", "support"))
import tower_level  # noqa: E402

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
        self.assertEqual(lvl["abilities_available"], {"pulse": False, "debug": False})  # pulso: encuentro con Eco
        self.assertNotIn("debug", json.dumps(lvl["unlocks"]))
        self.assertGreaterEqual(len(lvl["grid"]), 12)
        self.assertEqual("".join(lvl["grid"]).count("^"), 0, "1-1 sin pinchos")
        # Economia (decision 2026-10-15, revisada el mismo dia; docs/propuesta-1-1-ampliado.md §6): unos 9
        # puntos por mapa (los puntos no se recapturan). Un mapa solo no paga ninguna mejora; tres mapas
        # completos (1-1 a 1-3) pagan justo Pulso amplio, sin que sobren muchos; una vuelta (18 mapas)
        # no paga todas.
        points = "".join(lvl["grid"]).count("o")
        with open(os.path.join(ROOT, "data", "upgrades.json"), encoding="utf-8") as handle:
            upgrades = {u["id"]: u for u in json.load(handle)["upgrades"]}
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        gated_points = sum(int(s.get("points", 0)) for s in lvl["secrets"] if s.get("requires_upgrade"))
        route = points - secret_points
        self.assertEqual((points, route, secret_points, gated_points), (9, 6, 3, 0))
        costs = {uid: u["cost"]["attention_points"] for uid, u in upgrades.items()}
        self.assertLess(points, min(costs.values()), "un solo mapa completo no paga ninguna mejora")
        self.assertGreaterEqual(3 * points, costs["wide_pulse"], "tres mapas completos pagan Pulso amplio")
        self.assertLess(3 * points - costs["wide_pulse"], 5, "y sobran pocos puntos")
        self.assertLess(3 * route, costs["wide_pulse"], "solo con la ruta de tres mapas no llega")
        self.assertGreater(sum(costs.values()), 18 * points, "una vuelta no paga todas las mejoras")
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (300, 14))
        # Un solo power bank (vacio) en el 1-1: el del secreto que exige Pulso amplio.
        banks = [o for o in lvl["objects"] if o["type"] == "power_bank_pickup"]
        self.assertEqual(len(banks), 1, "un solo power bank en el 1-1")
        wide = next(s for s in lvl["secrets"] if s.get("requires_upgrade"))
        self.assertEqual((wide["id"], wide["requires_upgrade"], wide["object"]),
                         ("secreto_pulso_amplio", "wide_pulse", "power_bank_pickup"))
        self.assertEqual((banks[0]["x"], banks[0]["y"]), (wide["x"], wide["y"]))
        # Burbujas: solo la del Tramo 3a bajo techo bajo; las demas en abierto ("open").
        self.assertEqual([e["id"] for e in lvl["enemies"] if not e.get("open")], ["burbuja_1"])
        self.assertGreaterEqual(sum(1 for e in lvl["enemies"] if e.get("open")), 3)
        # Rediseno para el laser (2026-10-15): un ability_pickup del laser a mitad del mapa (tras el
        # punto de sincronizacion), Burbujas antes (se esquivan o aturden) y despues (se matan), una
        # con vida 3 al final, y dos cargadores con los valores por defecto del catalogo.
        lasers = [o for o in lvl["objects"] if o["type"] == "ability_pickup"]
        self.assertEqual([(o["params"]["id"], o["params"]["ability"]) for o in lasers], [("laser_1_1", "laser")])
        laser_x = lasers[0]["x"]
        width = len(lvl["grid"][0])
        self.assertLess(abs(laser_x - width / 2), width * 0.1, "el laser se obtiene a mitad del nivel")
        self.assertGreater(laser_x, lvl["checkpoints"][0]["x"])
        before = [e for e in lvl["enemies"] if e["x"] < lvl["enemies"][[e["id"] for e in lvl["enemies"]].index(
            "burbuja_1")]["x"] and e.get("open")]
        after = [e for e in lvl["enemies"] if e["x"] > laser_x]
        self.assertGreaterEqual(len(before), 2, "Burbujas al principio (tutorial)")
        self.assertGreaterEqual(len(after), 4, "Burbujas tras el laser")
        self.assertTrue(all(e.get("open") for e in after))
        self.assertEqual([e["id"] for e in lvl["enemies"] if e["params"].get("health") == 3.0], ["burbuja_cierre"])
        chargers = [o for o in lvl["objects"] if o["type"] == "charger"]
        self.assertEqual(len(chargers), 2)
        self.assertTrue(any(laser_x < c["x"] < min(e["x"] for e in after) for c in chargers),
                        "un cargador entre el laser y la primera Burbuja que cuesta energia")
        # La linea del primer disparo se elimino (2026-10-16, propuesta de asistentes §4.1).
        first_shot = [o for o in lvl["objects"] if o["params"].get("trigger_event") == "laser_fired"]
        self.assertEqual(len(first_shot), 0, "sin linea de Eco del primer disparo")
        kinds = [o["type"] for o in lvl["objects"]]
        for kind in ("eco_encounter", "eco_line", "receiver", "bridge_inactive", "popup_blocker", "exit_terminal",
                     "glitch_wall"):
            self.assertIn(kind, kinds)
        # Encuentro con Eco (2026-10-16): el 1-1 empieza sin pulso y Eco lo da en las columnas 10-12.
        self.assertFalse(lvl["abilities_available"]["pulse"])
        self.assertEqual((obj(lvl, "eco_encounter")["x"], obj(lvl, "eco_encounter")["y"]), (10, 0))
        self.assertEqual([o["params"]["id"] for o in lvl["objects"] if o["type"] == "eco_line"], ["eco_laser"],
                         "solo queda la historia del laser")
        self.assertEqual(obj(lvl, "exit_terminal")["params"]["text"], "Marcar como leído")
        self.assertNotIn("exit_door", kinds, "la puerta se sustituyo por la terminal (2026-10-15)")
        # Orden de los tramos: aterrizaje -> puente -> Burbuja bajo techo -> laser -> pop-up -> terminal.
        popup_1 = next(o for o in lvl["objects"] if o["params"].get("id") == "popup_1")
        low = next(e for e in lvl["enemies"] if e["id"] == "burbuja_1")
        xs = [obj(lvl, "eco_encounter")["x"], obj(lvl, "bridge_inactive")["x"], low["x"], laser_x,
              popup_1["x"], obj(lvl, "exit_terminal")["x"]]
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

        # Puentes sobre foso de la ruta (hacia la derecha y a la altura del suelo de su izquierda; el
        # de servicio del secreto A y los de la sala del laser van por el aire).
        bridges = [o for o in self.level["objects"]
                   if o["type"] == "bridge_inactive" and o["params"].get("direction", "right") == "right"
                   and o["y"] == surface(o["x"] - 1)]
        bridge_cols = set()
        for bridge in bridges:
            bridge_cols |= set(range(bridge["x"], bridge["x"] + bridge["params"]["length_tiles"]))
        # Sala del laser (2026-10-15): su base de 4 tiles se sube por puentes en alto (los que no
        # cruzan un foso); la pared justo tras su ultimo tile no es una subida a pie.
        raised_ends = {o["x"] + o["params"]["length_tiles"] for o in self.level["objects"]
                       if o["type"] == "bridge_inactive" and o["params"].get("direction", "right") == "right"
                       and o["y"] != surface(o["x"] - 1)}
        width = len(grid[0])
        for x in range(1, width - 2):
            if x in bridge_cols or x + 1 in bridge_cols or surface(x + 1) == 0 or x + 1 in raised_ends:
                continue  # puente, pared de limite hasta arriba o base de la sala del laser
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
            if seg[0] in bridge_cols or seg[1] in bridge_cols or seg[1] + 1 in raised_ends:
                continue  # foso de un puente o suelo bajo los puentes en alto de la sala del laser
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
        del alcance del salto. Desde el 2026-10-15 solo burbuja_1 (3a); las demas van en abierto
        ("open": test_level_1_1_open_bubbles). La prueba de simulacion es tests/test_tramo3_ceiling.gd."""
        with open(os.path.join(ROOT, "data", "isak_physics.json"), encoding="utf-8") as handle:
            phys = json.load(handle)
        with open(os.path.join(ROOT, "data", "enemies", "alert_bubble.json"), encoding="utf-8") as handle:
            bubble_data = json.load(handle)
        for bubble in self.level["enemies"]:
            if bubble.get("open"):
                continue
            with self.subTest(bubble=bubble["id"]):
                self._check_low_ceiling(bubble, phys, bubble_data)

    def test_level_1_1_open_bubbles(self):
        """Burbujas en abierto (2026-10-15): sin techo sobre su patrulla (se pueden saltar). Desde el
        rediseno para el laser ya no necesitan repisa (pisarlas no las mata); la repisa de una via a
        3 tiles del 3c sigue para usar la Burbuja aturdida de escalon hasta el punto de la ruta.
        Simulacion: tests/test_level_1_1.gd."""
        with open(os.path.join(ROOT, "data", "enemies", "alert_bubble.json"), encoding="utf-8") as handle:
            bubble_data = json.load(handle)
        grid = self.level["grid"]
        tile = self.level["tile_size"]
        for bubble in self.level["enemies"]:
            if not bubble.get("open"):
                continue
            with self.subTest(bubble=bubble["id"]):
                half = bubble["params"]["patrol_range_px"] / 2.0 + bubble_data["body_size"][0] / 2.0
                center = (bubble["x"] + 0.5) * tile
                c0, c1 = int((center - half) // tile), int((center + half - 1e-6) // tile)
                for c in range(c0, c1 + 1):
                    self.assertFalse(any(grid[r][c] == "#" for r in range(bubble["y"] + 1)),
                                     "techo sobre la patrulla en la columna %d" % c)
                if bubble["id"] in ("burbuja_3", "burbuja_4"):
                    ledge_row = bubble["y"] + 1 - 3
                    near = [c for c in range(c0 - 1, c1 + 2) if grid[ledge_row][c] == "-"]
                    self.assertTrue(near, "repisa de una via a 3 tiles junto a la patrulla")
                    run = set(near)
                    for c in near:
                        for step in (1, -1):
                            k = c + step
                            while grid[ledge_row][k] == "-":
                                run.add(k)
                                k += step
                    self.assertTrue(any(grid[ledge_row - 1][c] == "o" for c in run), "punto en la repisa")

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

    def test_unknown_help_id(self):
        obj(self.level, "popup_blocker")["help_id"] = "teletransporte"
        self.assert_fails(self.level, "help_id 'teletransporte' no esta en data/help.json")
        self.level["enemies"][0]["help_id"] = "nadie"
        self.assert_fails(self.level, "help_id 'nadie' no esta en data/help.json")

    def test_empty_help_id_means_no_prompt(self):
        obj(self.level, "popup_blocker")["help_id"] = ""
        self.assertEqual(vls.validate_level(self.level), [])

    def test_object_missing_required_param(self):
        del obj(self.level, "popup_blocker")["params"]["close_button_px"]
        self.assert_fails(self.level, "falta el param obligatorio 'close_button_px'")

    def test_object_unknown_param(self):
        obj(self.level, "exit_terminal")["params"]["color"] = "rojo"
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

    # --- Cargador y objeto de habilidad (2026-10-15) ---

    def _add(self, kind, params):
        x, y = find(self.level, "P")
        entry = {"type": kind, "x": x + 1, "y": y, "params": params}
        self.level["objects"].append(entry)
        return entry

    def test_charger_and_ability_pickup_are_valid(self):
        self._add("charger", {"id": "cargador_test", "amount": 50.0, "reusable": False, "cooldown_s": 20.0})
        self._add("ability_pickup", {"id": "laser_test", "ability": "laser"})
        self.level["abilities_available"]["laser"] = False
        self.assertEqual(vls.validate_level(self.level), [])

    def test_ability_pickup_unknown_ability(self):
        self._add("ability_pickup", {"id": "laser_1", "ability": "teletransporte"})
        self.assert_fails(self.level, "ability 'teletransporte' no admitido")

    def test_eco_line_trigger_event_allowed_values(self):
        self._add("eco_line", {"id": "eco_test", "text": "Hola.", "trigger_event": "laser_fired"})
        self.assertEqual(vls.validate_level(self.level), [])
        self._add("eco_line", {"id": "eco_test_2", "text": "Hola.", "trigger_event": "teletransporte"})
        self.assert_fails(self.level, "trigger_event 'teletransporte' no admitido")

    def test_eco_encounter_needs_level_without_pulse(self):
        self.level["abilities_available"]["pulse"] = True
        self.assert_fails(self.level, "el nivel debe empezar sin el (abilities_available.pulse false)")

    def test_only_one_extra_life_per_level(self):
        self._add("extra_life_pickup", {"id": "vida_extra_2", "secret_id": "E"})
        self.assert_fails(self.level, "solo puede haber una vida extra por nivel")

    def test_extra_life_needs_secret_id(self):
        obj(self.level, "extra_life_pickup")["params"]["secret_id"] = " "
        self.assert_fails(self.level, "secret_id debe ser un texto no vacio")
        del obj(self.level, "extra_life_pickup")["params"]["secret_id"]
        self.assert_fails(self.level, "falta el param obligatorio 'secret_id'")

    def test_only_one_eco_encounter(self):
        self._add("eco_encounter", {"id": "eco_otro"})
        self.assert_fails(self.level, "solo puede haber un encuentro con Eco por nivel")

    def test_eco_encounter_eco_inside_zone_and_free_cell(self):
        level = load_level()
        obj(level, "eco_encounter")["params"]["eco_offset_tiles"] = [5, 7]
        self.assert_fails(level, "queda fuera de la zona del encuentro")
        level = load_level()
        obj(level, "eco_encounter")["params"]["eco_offset_tiles"] = [2, 9]
        set_cell(level, 12, 9, "#")
        self.assert_fails(level, "Eco flota dentro de terreno")
        level = load_level()
        obj(level, "eco_encounter")["params"]["eco_offset_tiles"] = [2.5, 7]
        self.assert_fails(level, "eco_offset_tiles debe ser [columna, fila]")

    def test_ability_pickup_requires_ability(self):
        self._add("ability_pickup", {"id": "laser_1"})
        self.assert_fails(self.level, "falta el param obligatorio 'ability'")

    def test_charger_bad_params(self):
        self._add("charger", {"id": "c1", "amount": 0})
        self.assert_fails(self.level, "amount debe ser un numero > 0")
        self.level = load_level()
        self._add("charger", {"id": "c1", "cooldown_s": -1})
        self.assert_fails(self.level, "cooldown_s debe ser un numero >= 0")
        self.level = load_level()
        self._add("charger", {"id": "c1", "reusable": "si"})
        self.assert_fails(self.level, "reusable debe ser true o false")

    def test_charger_inside_terrain(self):
        entry = self._add("charger", {"id": "c1"})
        set_cell(self.level, entry["x"], entry["y"], "#")
        self.assert_fails(self.level, "charger) dentro de terreno")

    def test_object_out_of_grid(self):
        obj(self.level, "bridge_inactive")["params"]["length_tiles"] = 500
        self.assert_fails(self.level, "se sale del grid")

    def test_exit_terminal_must_contain_goal(self):
        obj(self.level, "exit_terminal")["x"] -= 3
        self.assert_fails(self.level, "no contiene la meta G")

    def test_exit_door_must_contain_goal(self):
        terminal = obj(self.level, "exit_terminal")
        terminal["type"] = "exit_door"
        terminal["x"] -= 3
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


class VerticalSchemaTest(unittest.TestCase):
    """Niveles verticales (2026-10-16, paso 1 de docs/propuesta-1-2.md §10): alto > 14 (la torre
    del 1-2 tiene 62 filas), tramos con y_from/y_to, camara de torre e id de nivel de prueba."""

    def setUp(self):
        self.level = tower_level.make_tower()

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_tower_28x62_is_valid(self):
        self.assertEqual((len(self.level["grid"]), len(self.level["grid"][0])), (62, 28))
        self.assertEqual(vls.validate_level(self.level), [])

    def test_horizontal_sections_of_1_1_still_need_order(self):
        level = load_level()
        self.assertTrue(all("y_from" not in s for s in level["sections"]))
        self.assertEqual(vls.validate_level(level), [])

    def test_vertical_sections_default_to_full_width(self):
        self.assertTrue(all("x_from" not in s for s in self.level["sections"]))
        self.level["sections"][0].update({"x_from": 0, "x_to": 27})
        self.assertEqual(vls.validate_level(self.level), [])

    def test_side_by_side_sections_in_the_same_floor_are_valid(self):
        floor = next(s for s in self.level["sections"] if s["name"] == "Piso 1")
        index = self.level["sections"].index(floor)
        self.level["sections"][index:index + 1] = [
            {"name": "Piso 1a", "x_from": 14, "x_to": 27, "y_from": floor["y_from"], "y_to": floor["y_to"]},
            {"name": "Piso 1b", "x_from": 0, "x_to": 13, "y_from": floor["y_from"], "y_to": floor["y_to"]}]
        self.assertEqual(vls.validate_level(self.level), [])

    def test_overlapping_floors_fail(self):
        self.level["sections"][1]["y_to"] += 1  # el piso 4 invade el suelo de la azotea... y al reves
        self.level["sections"][0]["y_to"] = self.level["sections"][1]["y_from"]
        self.assert_fails(self.level, "se solapa con sections[")

    def test_overlapping_side_by_side_sections_fail(self):
        self.level["sections"].append({"name": "Extra", "x_from": 20, "x_to": 27, "y_from": 60, "y_to": 61})
        self.assert_fails(self.level, "'Extra' se solapa con sections[")

    def test_rows_out_of_range_fail(self):
        self.level["sections"][-1]["y_to"] = 62
        self.assert_fails(self.level, "y_from/y_to no validos")

    def test_rows_reversed_fail(self):
        self.level["sections"][-1].update({"y_from": 61, "y_to": 56})
        self.assert_fails(self.level, "y_from/y_to no validos")

    def test_y_from_without_y_to_fails(self):
        del self.level["sections"][-1]["y_to"]
        self.assert_fails(self.level, "y_from/y_to no validos")

    def test_non_integer_rows_fail(self):
        self.level["sections"][-1]["y_from"] = 56.0
        self.assert_fails(self.level, "y_from/y_to no validos")

    def test_patterns_must_be_texts(self):
        self.level["sections"][1]["patterns"] = ["aturdir_y_rematar", ""]
        self.assert_fails(self.level, "patterns debe ser una lista de textos")

    def test_camera_modes(self):
        self.level["camera"]["vertical"] = "simple"
        self.assertEqual(vls.validate_level(self.level), [])
        self.level["camera"]["vertical"] = "espiral"
        self.assert_fails(self.level, "camera.vertical 'espiral' no admitido")
        self.level["camera"] = {"vertical": "tower", "limits": "libre"}
        self.assert_fails(self.level, "camera.limits 'libre' no admitido")
        self.level["camera"] = {"vertical": "tower", "zoom": 2}
        self.assert_fails(self.level, "camera: campo desconocido 'zoom'")

    def test_test_level_ids(self):
        self.assertEqual(self.level["id"], "tower_test")
        self.level["id"] = "torre"
        self.assert_fails(self.level, "<nombre>_test (nivel de prueba)")
        self.level["id"] = "1-2"
        self.assertEqual(vls.validate_level(self.level), [])

    def test_short_grid_still_fails(self):
        self.level["grid"] = self.level["grid"][-11:]
        self.assert_fails(self.level, "hacen falta al menos 12")

    def test_committed_tower_test_level_is_valid(self):
        path = os.path.join(ROOT, "data", "levels", "tower_test.json")
        if not os.path.exists(path):
            self.skipTest("sin data/levels/tower_test.json")
        with open(path, encoding="utf-8") as handle:
            level = json.load(handle)
        self.assertEqual(vls.validate_level(level), [])
        self.assertGreater(len(level["grid"]), 14)
        self.assertEqual(level["camera"]["vertical"], "tower")
        self.assertTrue(all("y_from" in s and "y_to" in s for s in level["sections"]))


if __name__ == "__main__":
    unittest.main()
