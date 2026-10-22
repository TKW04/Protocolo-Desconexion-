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
import upgrade_catalog  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, "tests", "support"))
import tower_level  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "1-1.json")
SCRIPT = os.path.join(ROOT, "tools", "validate_level_schema.py")


def upgrade_catalog_total(catalog):
    """Puntos que cuestan todas las compras (niveles 2-5 de las cinco pistas)."""
    return sum(lv["cost"]["attention_points"] for _, lv in upgrade_catalog.purchasable_levels(catalog))


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
        # no paga todas. Desde la tanda M1 (2026-10-17) las compras son los niveles 2-5 de las pistas de
        # data/upgrades.json y Pulso amplio es el nivel 2 del Pulso (legacy_id wide_pulse), a 25.
        points = "".join(lvl["grid"]).count("o")
        catalog = upgrade_catalog.load_catalog()
        wide_track, wide_level = upgrade_catalog.resolve(catalog, "wide_pulse")
        self.assertEqual((wide_track, wide_level), ("pulso", 2))
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        gated_points = sum(int(s.get("points", 0)) for s in lvl["secrets"] if s.get("requires_upgrade"))
        route = points - secret_points
        self.assertEqual((points, route, secret_points, gated_points), (9, 6, 3, 0))
        costs = {"%s:%d" % (tid, lv["level"]): lv["cost"]["attention_points"]
                 for tid, lv in upgrade_catalog.purchasable_levels(catalog)}
        costs["wide_pulse"] = costs["pulso:2"]
        self.assertEqual(costs["wide_pulse"], 25, "Pulso amplio mantiene su precio")
        self.assertLess(points, min(costs.values()), "un solo mapa completo no paga ninguna mejora")
        self.assertGreaterEqual(3 * points, costs["wide_pulse"], "tres mapas completos pagan Pulso amplio")
        self.assertLess(3 * points - costs["wide_pulse"], 5, "y sobran pocos puntos")
        self.assertLess(3 * route, costs["wide_pulse"], "solo con la ruta de tres mapas no llega")
        self.assertGreater(upgrade_catalog_total(catalog), 18 * points, "una vuelta no paga todas las mejoras")
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

    def test_level_1_2_economy(self):
        # Economia del 1-2 (docs/propuesta-1-2.md §5-§6, paso 13, 2026-10-16): como el 1-1, 9 puntos
        # (6 en la ruta + 3 en secretos: A 2 con Debug, B 1), 2 cargadores en los pisos + 1 en la azotea
        # (acertijo de Calc, tanda H2 del paso 14, 2026-10-17), un power bank (vacio) en el secreto C y
        # sin vida extra. Pulso amplio (25) sigue pagandose al terminar el 1-3.
        with open(os.path.join(ROOT, "data", "levels", "1-2.json"), encoding="utf-8") as handle:
            lvl = json.load(handle)
        self.assertEqual(vls.validate_level(lvl), [])
        points = "".join(lvl["grid"]).count("o")
        secrets = {s["id"]: s for s in lvl["secrets"]}
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (9, 6, 3))
        self.assertEqual((secrets["secreto_spam"]["points"], secrets["secreto_spam"].get("needs_debug")), (2, True))
        self.assertEqual(secrets["secreto_borradores"]["points"], 1)
        self.assertEqual(secrets["secreto_olvidado"]["object"], "power_bank_pickup")
        banks = [o for o in lvl["objects"] if o["type"] == "power_bank_pickup"]
        self.assertEqual(len(banks), 1, "un solo power bank en el 1-2")
        self.assertEqual((banks[0]["x"], banks[0]["y"]),
                         (secrets["secreto_olvidado"]["x"], secrets["secreto_olvidado"]["y"]))
        chargers = [o for o in lvl["objects"] if o["type"] == "charger"]
        self.assertEqual(sorted(c["params"]["id"] for c in chargers), ["cargador_1", "cargador_2", "cargador_3"])
        self.assertTrue(all(c["params"]["reusable"] for c in chargers))
        self.assertFalse(any(o["type"] == "extra_life_pickup" for o in lvl["objects"]), "sin vida extra en el 1-2")
        catalog = upgrade_catalog.load_catalog()
        costs = {"wide_pulse": upgrade_catalog.level_entry(catalog, "pulso", 2)["cost"]["attention_points"]}
        first = "".join(self.level["grid"]).count("o")
        self.assertLess(first + points, costs["wide_pulse"], "1-1 + 1-2 aun no pagan Pulso amplio")
        self.assertGreaterEqual(first + 2 * points, costs["wide_pulse"], "con el 1-3 (unos 9 mas) si")
        # Un cargador en cada gasto obligatorio: el acertijo y el Debug del piso 2, los Posponer del 3 y
        # el acertijo de Calc en la azotea (Debug para la pared y el panel, laser al interruptor).
        self.assertEqual(sorted(c["y"] for c in chargers), [9, 24, 41])
        rows = {s["name"]: (s["y_from"], s["y_to"]) for s in lvl["sections"]}
        roof = next(c for c in chargers if c["params"]["id"] == "cargador_3")
        self.assertTrue(rows["Azotea"][0] <= roof["y"] <= rows["Azotea"][1], "cargador_3 en la azotea")

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

    # --- Mensaje de secreto (memory_pickup y recompensa memory; paso 4 de docs/propuesta-recuerdos.md) ---

    def _secret_a(self):
        return next(s for s in self.level["secrets"] if s["id"] == "secreto_puente_servicio")

    def test_secret_a_offers_the_message_with_its_point(self):
        sec = self._secret_a()
        self.assertEqual((sec["reward"], sec["points"], sec["memory_id"]), (["attention_points", "memory"], 1, "msg_1_1"))
        self.assertEqual(sec["gates"], ["puente_servicio"], "Sin cambiar lo que exige")
        self.assertNotIn("needs_debug", sec)
        self.assertNotIn("requires_upgrade", sec)
        pickup = obj(self.level, "memory_pickup")
        self.assertEqual((pickup["x"], pickup["y"], pickup["params"]), (96, 4, {"id": "mensaje_1_1", "memory_id": "msg_1_1"}))
        self.assertEqual(vls.validate_level(self.level), [])
        sec["reward"] = "memory"  # tambien sola
        self.assertEqual(vls.validate_level(self.level), [])

    def test_unknown_or_malformed_reward(self):
        self._secret_a()["reward"] = ["attention_points", "tesoro"]
        self.assert_fails(self.level, "reward 'tesoro' desconocida")
        self._secret_a()["reward"] = []
        self.assert_fails(self.level, "reward debe ser un texto o una lista de textos no vacia")
        self._secret_a()["reward"] = ["memory", "memory"]
        self.assert_fails(self.level, "reward repetida")

    def test_memory_reward_needs_a_valid_memory_id(self):
        del self._secret_a()["memory_id"]
        self.assert_fails(self.level, "la recompensa memory necesita memory_id")
        self._secret_a()["memory_id"] = "msg_9_9"
        self.assert_fails(self.level, "memory_id 'msg_9_9' no esta en data/memories.json")
        self._secret_a()["memory_id"] = "boss_w1_l1"
        self.assert_fails(self.level, "memory_id 'boss_w1_l1' no es un mensaje de secreto")
        self._secret_a()["memory_id"] = "msg_1_2"
        self.assert_fails(self.level, "el mensaje msg_1_2 es del nivel 1-2 y del secreto secreto_spam")

    def test_memory_id_without_memory_reward(self):
        self._secret_a()["reward"] = "attention_points"
        self.assert_fails(self.level, "memory_id sin la recompensa memory")

    def test_memory_reward_needs_its_pickup(self):
        self.level["objects"] = [o for o in self.level["objects"] if o["type"] != "memory_pickup"]
        self.assert_fails(self.level, "no hay ningun memory_pickup con memory_id 'msg_1_1'")

    def test_memory_pickup_rules(self):
        self._add("memory_pickup", {"id": "mensaje_2", "memory_id": "msg_1_1"})
        self.assert_fails(self.level, "ya hay otro memory_pickup con memory_id 'msg_1_1'")
        self.level = load_level()
        self._add("memory_pickup", {"id": "mensaje_2", "memory_id": "msg_1_3"})
        self.assert_fails(self.level, "ningun secreto ofrece el mensaje msg_1_3")
        self.level = load_level()
        self._add("memory_pickup", {"id": "mensaje_2", "memory_id": "boss_w1_l2"})
        self.assert_fails(self.level, "memory_id 'boss_w1_l2' no es un mensaje de secreto (kind secret)")
        self.level = load_level()
        del obj(self.level, "memory_pickup")["params"]["memory_id"]
        self.assert_fails(self.level, "falta el param obligatorio 'memory_id'")
        self.level = load_level()
        pickup = obj(self.level, "memory_pickup")
        pickup["y"] = 5  # el suelo de la repisa
        self.assert_fails(self.level, "dentro de terreno o pinchos")

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

    # --- Secreto «Excepciones» (2026-10-20, paso 7 de docs/propuesta-1-3.md §7 y §5.4) ---

    def _excepciones(self):
        with open(os.path.join(ROOT, "data", "levels", "excepciones_test.json"), encoding="utf-8") as fh:
            return json.load(fh)

    def test_excepciones_room_is_valid(self):
        level = self._excepciones()
        self.assertEqual(vls.validate_level(level), [])
        self.assertEqual(level["stands_for"], "1-3")
        wall = obj(level, "glitch_wall")
        self.assertIs(wall["params"]["visible_only_with_debug"], True)
        sec = level["secrets"][0]
        self.assertEqual((sec["id"], sec["memory_id"], sec["needs_debug"], sec["forbid_abilities"]),
                         ("secreto_excepciones", "msg_1_3", True, ["dash"]))
        self.assertEqual(obj(level, "memory_pickup")["params"]["memory_id"], "msg_1_3")

    def test_glitch_wall_visible_only_with_debug_is_boolean(self):
        obj(self.level, "glitch_wall")["params"]["visible_only_with_debug"] = True
        self.assertEqual(vls.validate_level(self.level), [])
        obj(self.level, "glitch_wall")["params"]["visible_only_with_debug"] = "si"
        self.assert_fails(self.level, "visible_only_with_debug debe ser true o false")

    def test_exceptions_panel_rules(self):
        entry = self._add("exceptions_panel", {"id": "panel_test", "width_tiles": 3, "height_tiles": 2,
                                               "contacts": ["Mamá"]})
        entry["y"] -= 2  # en la pared del fondo, por encima del suelo
        self.assertEqual(vls.validate_level(self.level), [])
        self.level["objects"][-1]["params"]["contacts"] = []
        self.assert_fails(self.level, "contacts debe ser una lista no vacia de nombres")
        self.level["objects"][-1]["params"]["contacts"] = ["Mamá"]
        self.level["objects"][-1]["params"]["title"] = " "
        self.assert_fails(self.level, "title debe ser un texto no vacio")
        self.level["objects"][-1]["params"]["title"] = "Favoritos"
        self.level["objects"][-1]["params"]["height_tiles"] = 1
        self.assert_fails(self.level, "height_tiles = 1 fuera de [2, 8]")

    def test_forbid_abilities(self):
        level = self._excepciones()
        level["secrets"][0]["forbid_abilities"] = ["volar"]
        self.assert_fails(level, "habilidad desconocida en forbid_abilities: 'volar'")
        level["secrets"][0]["forbid_abilities"] = []
        self.assert_fails(level, "forbid_abilities debe ser una lista no vacia")
        level["secrets"][0]["forbid_abilities"] = ["dash", "dash"]
        self.assert_fails(level, "forbid_abilities debe ser una lista no vacia")

    def test_stands_for_rules(self):
        level = self._excepciones()
        del level["stands_for"]
        self.assert_fails(level, "el mensaje msg_1_3 es del nivel 1-3")
        level["stands_for"] = "2-1"
        self.assert_fails(level, "'stands_for' (2-1) no es del mundo 1")
        level["stands_for"] = "uno"
        self.assert_fails(level, "'stands_for' debe ser un subnivel")
        self.level["stands_for"] = "1-3"
        self.assert_fails(self.level, "'stands_for' solo vale en un nivel de prueba")

    # --- Interruptor «No molestar» (2026-10-19, paso 3 de docs/propuesta-1-3.md §7) ---

    def test_dnd_switch_is_valid_and_only_gives_dash(self):
        self._add("dnd_switch", {"id": "dnd_test", "ability": "dash", "story_line": "dnd_1_3"})
        self._add("eco_line", {"id": "eco_dash", "text": "Hola.", "unless_ability": "dash"})
        self.assertEqual(vls.validate_level(self.level), [])
        self.level = load_level()
        self._add("dnd_switch", {"id": "dnd_test", "ability": "laser"})
        self.assert_fails(self.level, "ability 'laser' no admitido")
        self.level = load_level()
        self._add("dnd_switch", {"id": "dnd_test"})
        self.assert_fails(self.level, "falta el param obligatorio 'ability'")
        self.level = load_level()
        self._add("dnd_switch", {"id": "dnd_test", "ability": "dash", "story_line": "otra"})
        self.assert_fails(self.level, "story_line 'otra' no admitido")

    def test_dnd_switch_inside_terrain(self):
        entry = self._add("dnd_switch", {"id": "dnd_test", "ability": "dash"})
        set_cell(self.level, entry["x"], entry["y"], "#")
        self.assert_fails(self.level, "fila %d, columna %d: objects" % (entry["y"], entry["x"]))

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
        # dash es conocida desde el 2026-10-19 (salas del 1-3) y ground_pound desde el 2026-10-22 (Mundo 2).
        self.level["abilities_available"]["compress"] = True
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


class CorreoPuzzleSchemaTest(unittest.TestCase):
    """Objetos del acertijo del laser (2026-10-16, paso 3 de docs/propuesta-1-2.md §10): enlaces
    laser_receiver -> relay_receiver -> bridge_inactive y ad_cover -> popup_blocker, cable y
    refill_energy del chip del Debug."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "levels", "correo_test.json"), encoding="utf-8") as handle:
            self.level = json.load(handle)

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def obj(self, kind):
        return next(o for o in self.level["objects"] if o["type"] == kind)

    def test_committed_correo_test_level_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])
        kinds = {o["type"] for o in self.level["objects"]}
        self.assertTrue({"laser_receiver", "relay_receiver", "ad_cover", "bridge_inactive", "popup_blocker",
                         "ability_pickup", "charger"} <= kinds)

    def test_reader_target_must_be_a_relay(self):
        self.obj("laser_receiver")["params"]["target"] = "puente_correo"
        self.assert_fails(self.level, "no es el id de ningun relay_receiver")

    def test_relay_target_must_be_a_bridge(self):
        self.obj("relay_receiver")["params"]["target"] = "nada"
        self.assert_fails(self.level, "no es el id de ningun bridge_inactive")

    def test_ad_target_must_be_a_popup(self):
        self.obj("ad_cover")["params"]["target"] = "receptor_enlazado_1"
        self.assert_fails(self.level, "no es el id de ningun popup_blocker")

    def test_ad_must_be_on_the_close_button_cell(self):
        self.obj("ad_cover")["x"] = 16
        self.assert_fails(self.level, "celda del boton de cerrar")

    def test_required_params(self):
        del self.obj("ad_cover")["params"]["text"]
        self.assert_fails(self.level, "falta el param obligatorio 'text'")
        del self.obj("relay_receiver")["params"]["target"]
        self.assert_fails(self.level, "falta el param obligatorio 'target'")

    def test_cable_and_window(self):
        reader = self.obj("laser_receiver")["params"]
        reader["cable"] = [[14, 8], [99, 8]]
        self.assert_fails(self.level, "fuera del grid")
        reader["cable"] = [[14, "8"]]
        self.assert_fails(self.level, "debe ser [columna, fila]")
        reader["cable"] = []
        reader["window_s"] = 0
        self.assert_fails(self.level, "window_s debe ser un numero > 0")

    def test_reader_inside_terrain_fails(self):
        self.obj("laser_receiver")["x"] = 15
        self.assert_fails(self.level, "dentro de terreno")

    def test_refill_energy_must_be_bool(self):
        self.obj("ability_pickup")["params"]["refill_energy"] = "si"
        self.assert_fails(self.level, "refill_energy debe ser true o false")


class RedDotAndBannerSchemaTest(unittest.TestCase):
    """Punto rojo (notification_badge) y banner (spam_banner) del 1-2 (pasos 4 y 5,
    2026-10-16): params por tipo con su rango (level_params del JSON del enemigo), pasillo
    del banner dentro del grid y sin celdas solidas y ciclo con reposo. Sala mensajes_test."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "levels", "mensajes_test.json"), encoding="utf-8") as fh:
            self.level = json.load(fh)

    def enemy(self, eid):
        return next(e for e in self.level["enemies"] if e["id"] == eid)

    def assert_fails(self, fragment):
        errors = vls.validate_level(self.level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_test_room_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])
        types = sorted({e["type"] for e in self.level["enemies"]})
        self.assertEqual(types, ["notification_badge", "spam_banner"])

    def test_badge_params_by_type_and_range(self):
        self.enemy("badge_1")["params"]["patrol_range_px"] = 256
        self.assert_fails("params.patrol_range_px no existe para notification_badge")
        self.enemy("badge_1")["params"] = {"chase_speed_px_s": 900}
        self.assert_fails("params.chase_speed_px_s = 900 fuera de [20.0, 200.0]")
        self.enemy("badge_1")["params"] = {"health": "dos"}
        self.assert_fails("params.health debe ser un numero")
        self.enemy("badge_1")["params"] = {"health": 1, "stun_duration_s": 2.5, "wake_radius_px": 256}
        self.assertEqual(vls.validate_level(self.level), [])

    def test_banner_direction_and_int_corridor(self):
        self.enemy("banner_1")["params"]["direction"] = 0
        self.assert_fails("params.direction debe ser uno de [-1, 1]")
        self.enemy("banner_1")["params"] = {"corridor_tiles": 12.5}
        self.assert_fails("params.corridor_tiles debe ser un entero")
        self.enemy("banner_1")["params"] = {"phase_s": -1}
        self.assert_fails("params.phase_s = -1 fuera de")

    def test_banner_corridor_inside_grid_and_free(self):
        self.enemy("banner_1")["params"]["corridor_tiles"] = 20
        self.assert_fails("banner 'banner_1': celda solida dentro de su pasillo")
        self.enemy("banner_1")["params"] = {"corridor_tiles": 21, "direction": -1}  # hasta la pared de la columna 0
        self.assert_fails("banner 'banner_1': celda solida dentro de su pasillo")
        self.enemy("banner_2")["params"]["corridor_tiles"] = 40
        self.assert_fails("banner 'banner_2':")

    def test_banner_cycle_needs_rest(self):
        self.enemy("banner_1")["params"]["interval_s"] = 1.6
        self.assert_fails("interval_s 1.60 menor que aviso + barrido + reposo minimo")
        self.enemy("banner_1")["params"]["interval_s"] = 2.5
        self.enemy("banner_1")["params"]["sweep_speed_px_s"] = 1280
        errors = [e for e in vls.validate_level(self.level) if "banner_1" in e]
        self.assertEqual(errors, [])

    def test_banner_corridor_wider_than_banner(self):
        self.enemy("banner_1")["params"]["corridor_tiles"] = 2
        self.assert_fails("params.corridor_tiles = 2 fuera de [3, 40]")


class DashBannerSchemaTest(unittest.TestCase):
    """Banner obligatorio con el dash (knockback_to_entry, 2026-10-19, paso 4 de
    docs/propuesta-1-3.md §5.2): booleano, techo bajo en todo el pasillo (sin nicho ni salto), celda
    de vuelta libre y con suelo, ayuda propia spam_banner_dash y el dash en abilities_available.
    Sala silenciados_test."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "levels", "silenciados_test.json"), encoding="utf-8") as fh:
            self.level = json.load(fh)

    def enemy(self, eid):
        return next(e for e in self.level["enemies"] if e["id"] == eid)

    def set_cell(self, col, row, char):
        line = self.level["grid"][row]
        self.level["grid"][row] = line[:col] + char + line[col + 1:]

    def assert_fails(self, fragment):
        errors = vls.validate_level(self.level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_test_room_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.enemy("banner_dash")["params"]["knockback_to_entry"])
        self.assertEqual(self.enemy("banner_dash")["help_id"], "spam_banner_dash")
        self.assertTrue(self.level["abilities_available"]["dash"])

    def test_knockback_to_entry_must_be_bool(self):
        self.enemy("banner_dash")["params"]["knockback_to_entry"] = 1
        self.assert_fails("params.knockback_to_entry debe ser true o false")

    def test_mandatory_corridor_needs_low_ceiling_everywhere(self):
        self.set_cell(10, 8, ".")  # un hueco en el techo: un nicho
        self.assert_fails("banner 'banner_dash' (knockback_to_entry): el pasillo debe tener techo bajo")
        self.setUp()
        for col in range(6, 18):  # techo de 3 filas: se salta
            self.set_cell(col, 8, ".")
        self.assert_fails("techo bajo en todo su largo")

    def test_without_knockback_the_same_corridor_is_free_to_have_a_niche(self):
        self.enemy("banner_dash")["params"]["knockback_to_entry"] = False
        self.set_cell(10, 8, ".")
        self.assertEqual(vls.validate_level(self.level), [])

    def test_return_cell_must_be_free_with_floor(self):
        self.set_cell(5, 10, "#")
        self.assert_fails("la entrada del pasillo (la celda de vuelta) debe estar libre")
        self.setUp()
        self.set_cell(5, 11, ".")
        self.assert_fails("la entrada del pasillo (la celda de vuelta) debe estar libre, con suelo")

    def test_own_help_id_must_exist(self):
        self.enemy("banner_dash")["help_id"] = "spam_banner_otro"
        self.assert_fails("help_id 'spam_banner_otro' no esta en data/help.json")

    def test_dash_is_a_known_ability(self):
        self.level["abilities_available"]["dash"] = "si"
        self.assert_fails("abilities_available.dash debe ser true o false")

    def test_dash_required_lists_existing_banners(self):
        """validation.dash_required (paso 9 de docs/propuesta-1-3.md §6.1): ids de banners del nivel, sin
        repetir."""
        self.assertEqual(self.level["validation"]["dash_required"], ["banner_dash"])
        self.level["validation"]["dash_required"] = ["banner_otro"]
        self.assert_fails("validation.dash_required: el banner 'banner_otro' no existe")
        self.level["validation"]["dash_required"] = []
        self.assert_fails("validation.dash_required debe ser una lista no vacia de ids de banners")
        self.level["validation"]["dash_required"] = ["banner_dash", "banner_dash"]
        self.assert_fails("validation.dash_required debe ser una lista no vacia de ids de banners")


class RhythmSchemaTest(unittest.TestCase):
    """Metronomo y plataformas que parpadean (2026-10-19, paso 5 de docs/propuesta-1-3.md §5.3): zona
    dentro del grid, ciclos validos, start de los admitidos, plataforma con su metronomo, dentro de su
    zona, con grupo y con la parte encendida >= aviso + 0,25 s. Sala vibracion_test."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "levels", "vibracion_test.json"), encoding="utf-8") as fh:
            self.level = json.load(fh)

    def obj(self, oid):
        return next(o for o in self.level["objects"] if o["params"].get("id") == oid)

    def assert_fails(self, fragment):
        errors = vls.validate_level(self.level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_test_room_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])

    def test_zone_inside_grid(self):
        self.obj("ritmo_v")["params"]["zone"] = [6, 1, 40, 10]
        self.assert_fails("se sale del grid")
        self.obj("ritmo_v")["params"]["zone"] = [6, 1, 25]
        self.assert_fails("zone debe ser [columna, fila, ancho, alto]")

    def test_tempo_steps_and_start(self):
        self.obj("ritmo_v")["params"]["tempo_steps_s"] = []
        self.assert_fails("tempo_steps_s debe ser una lista no vacia")
        self.obj("ritmo_v")["params"]["tempo_steps_s"] = [3.2, 0.2]
        self.assert_fails("tempo_steps_s debe ser una lista no vacia de segundos entre 0.5 y 12")
        self.setUp()
        self.obj("ritmo_v")["params"]["start"] = "nunca"
        self.assert_fails("start 'nunca' no admitido")
        self.setUp()
        self.obj("ritmo_v")["params"]["loop"] = "si"
        self.assert_fails("loop debe ser true o false")

    def test_platform_needs_its_rhythm_and_group(self):
        self.obj("blink_2a_a")["params"]["rhythm"] = "otro"
        self.assert_fails("rhythm 'otro' no es el id de ningun rhythm_zone")
        self.setUp()
        self.obj("blink_2a_a")["params"]["group"] = " "
        self.assert_fails("group debe ser un texto no vacio")

    def test_platform_inside_its_zone(self):
        self.obj("ritmo_v")["params"]["zone"] = [10, 1, 20, 10]
        self.assert_fails("la plataforma se sale de la zona de su metronomo ritmo_v")

    def test_on_time_fits_the_warning(self):
        self.obj("blink_2b_a")["params"]["on_fraction"] = 0.4
        self.assert_fails("menos que el aviso (0.75 s) + 0.25 s")
        self.setUp()
        self.obj("ritmo_v")["params"]["tempo_steps_s"] = [3.2, 2.6, 1.6]
        self.assert_fails("encendida 0.80 s con el ciclo mas corto (1.60 s)")

    def test_platform_cells_must_be_empty(self):
        line = self.level["grid"][8]
        self.level["grid"][8] = line[:18] + "#" + line[19:]
        self.assert_fails("ocupa una celda que el grid debe dejar vacia")


class AlarmTunnelSchemaTest(unittest.TestCase):
    """Tunel de alarmas, campanas y banners con ritmo (2026-10-19, paso 6 de docs/propuesta-1-3.md
    §5.5): tramos en orden dentro de la zona, campana colgada del techo con la onda hasta el suelo y
    ciclo con reposo, banners con rhythm existente y ciclo que cabe. Sala alarmas_test."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "levels", "alarmas_test.json"), encoding="utf-8") as fh:
            self.level = json.load(fh)

    def tunnel(self):
        return next(o for o in self.level["objects"] if o["type"] == "alarm_tunnel")

    def enemy(self, eid):
        return next(e for e in self.level["enemies"] if e["id"] == eid)

    def assert_fails(self, fragment):
        errors = vls.validate_level(self.level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_test_room_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])
        kinds = sorted({e["type"] for e in self.level["enemies"]})
        self.assertEqual(kinds, ["alarm_bell", "spam_banner"])

    def test_stages_in_order_inside_the_zone(self):
        self.tunnel()["params"]["stages"][1]["x_from"] = 10
        self.assert_fails("los tramos van en orden y sin solaparse")
        self.setUp()
        self.tunnel()["params"]["stages"][2]["x_to"] = 36
        self.assert_fails("columnas 24-36 fuera de la zona")
        self.setUp()
        self.tunnel()["params"]["stages"][0]["cycle_s"] = 0.2
        self.assert_fails("cycle_s debe estar entre 0.5 y 12 s")
        self.setUp()
        self.tunnel()["params"]["stages"] = []
        self.assert_fails("stages debe ser una lista no vacia")

    def test_bell_hangs_from_the_ceiling_and_reaches_the_floor(self):
        self.enemy("bell_4b_2")["params"]["wave_tiles"] = 3
        self.assert_fails("campana 'bell_4b_2': la onda (3 celdas) cruza terreno solido")
        self.setUp()
        self.enemy("bell_4b_2")["params"]["wave_tiles"] = 1
        self.assert_fails("campana 'bell_4b_2': la onda debe llegar al suelo")

    def test_bell_needs_a_ceiling(self):
        bell = self.enemy("bell_4a_1")
        row = self.level["grid"][7]
        self.level["grid"][7] = row[:9] + "." + row[10:]
        self.assertIn("campana 'bell_4a_1': debe colgar del techo",
                      " ".join(vls.validate_level(self.level)))
        self.assertEqual(bell["x"], 9)

    def test_rhythm_must_exist_and_leave_rest(self):
        self.enemy("bell_4a_1")["params"]["rhythm"] = "otro"
        self.assert_fails("enemigo 'bell_4a_1': rhythm 'otro' no es el id de ningun")
        self.setUp()
        self.tunnel()["params"]["stages"][2]["cycle_s"] = 1.1
        self.assert_fails("el ciclo mas corto de tunel_alarmas (1.10 s) es menor que aviso + onda + reposo minimo")
        self.assert_fails("es menor que aviso + barrido + reposo minimo")
        self.setUp()
        self.enemy("banner_4a")["params"]["rhythm"] = 3
        self.assert_fails("params.rhythm debe ser un texto")

    def test_bell_without_rhythm_uses_interval(self):
        p = self.enemy("bell_4a_1")["params"]
        del p["rhythm"]
        p["interval_s"] = 1.2
        self.assert_fails("campana 'bell_4a_1': interval_s 1.20 menor que aviso + onda + reposo minimo")
        p["interval_s"] = 2.0
        self.assertEqual(vls.validate_level(self.level), [])


class TowerObjectsSchemaTest(unittest.TestCase):
    """Recordatorio, Posponer, pop-up translucido y barra del 99 % del 1-2 (pasos 6, 7 y 8,
    2026-10-16): params con su rango (level_params del catalogo), enlaces Posponer -> grupos
    de recordatorios, boton del pop-up dentro de la ventana (y anuncio encima) y oleadas
    validas. Salas recordatorios_test, overlay_test y actualizaciones_test."""

    def load(self, name):
        with open(os.path.join(ROOT, "data", "levels", "%s.json" % name), encoding="utf-8") as fh:
            return json.load(fh)

    def find_obj(self, level, oid):
        return next(o for o in level["objects"] if o["params"].get("id") == oid)

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_test_rooms_are_valid(self):
        for name in ("recordatorios_test", "overlay_test", "actualizaciones_test"):
            self.assertEqual(vls.validate_level(self.load(name)), [], name)

    def test_reminder_params_and_cells(self):
        level = self.load("recordatorios_test")
        rem = self.find_obj(level, "posponer_a")
        rem["params"]["width_tiles"] = 4
        self.assert_fails(level, "width_tiles = 4 fuera de [1, 3]")
        rem["params"]["width_tiles"] = 1.5
        self.assert_fails(level, "width_tiles debe ser un entero")
        rem["params"]["width_tiles"] = 2
        rem["params"]["warn_s"] = 0.25
        self.assert_fails(level, "warn_s = 0.25 fuera de [0.5, 1.0]")
        rem["params"]["warn_s"] = 1.0
        rem["params"]["timer_s"] = 1.0
        self.assert_fails(level, "warn_s (1.0) debe ser menor que timer_s (1.0)")
        rem["params"]["timer_s"] = 2.0
        rem["params"]["group"] = ""
        self.assert_fails(level, "group debe ser un texto no vacio")
        level = self.load("recordatorios_test")
        set_cell(level, 13, 8, "#")
        self.assert_fails(level, "ocupa una celda que el grid debe dejar vacia")

    def test_snooze_links_and_cap(self):
        level = self.load("recordatorios_test")
        snooze = self.find_obj(level, "snooze_1")
        snooze["params"]["targets"] = ["no_existe"]
        self.assert_fails(level, "target 'no_existe' no es el group de ningun reminder_platform")
        snooze["params"]["targets"] = []
        self.assert_fails(level, "targets debe ser una lista no vacia")
        snooze["params"]["targets"] = ["posponer_1"]
        snooze["params"]["cap_s"] = 2.0
        self.assert_fails(level, "cap_s (2.0) debe ser >= extend_s (4.0)")
        snooze["params"]["cap_s"] = 50
        self.assert_fails(level, "cap_s = 50 fuera de [1.0, 30.0]")

    def test_overlay_button_inside_and_ad_cover(self):
        level = self.load("overlay_test")
        ov = self.find_obj(level, "overlay_1")
        ov["params"]["close_button_px"] = [310, 224]
        self.assert_fails(level, "el boton de cerrar")
        ov["params"]["close_button_px"] = [8, 224]
        ov["params"]["opacity"] = 0.2
        self.assert_fails(level, "opacity = 0.2 fuera de [0.5, 0.95]")
        ov["params"]["opacity"] = 0.7
        # Un anuncio en la celda del boton (12, 9) es valido; en otra celda, no.
        level["objects"].append({"type": "ad_cover", "x": 12, "y": 9,
                                 "params": {"id": "ad_o", "target": "overlay_1", "text": "Saltar anuncio en 5…"}})
        self.assertEqual(vls.validate_level(level), [])
        level["objects"][-1]["x"] = 13
        self.assert_fails(level, "debe estar en la celda del boton de cerrar de 'overlay_1'")

    def test_update_bar_zone_and_waves(self):
        level = self.load("actualizaciones_test")
        bar = self.find_obj(level, "barra_99")
        bar["params"]["zone"] = [4, 1, 40, 10]
        self.assert_fails(level, "se sale del grid")
        bar["params"]["zone"] = [4, 1, 20]
        self.assert_fails(level, "zone debe ser [columna, fila, ancho, alto]")
        level = self.load("actualizaciones_test")
        waves = self.find_obj(level, "barra_99")["params"]["waves"]
        waves[0]["t"] = 0.5
        self.assert_fails(level, "t = 0.5 fuera de [0.75, wait_s 20.0)")
        waves[0]["t"] = 25.0
        self.assert_fails(level, "t = 25.0 fuera de")
        waves[0]["t"] = 4.0
        waves[1]["type"] = "spam_banner"
        self.assert_fails(level, "type 'spam_banner' no admitido")
        waves[1]["type"] = "alert_bubble"
        waves[2]["x"] = 2
        self.assert_fails(level, "x = 2 fuera de la zona")
        waves[2]["x"] = 11
        waves[3]["params"] = {"chase_speed_px_s": 900}
        self.assert_fails(level, "params.chase_speed_px_s = 900 fuera de")
        waves[3]["params"] = {}
        waves[4]["extra"] = 1
        self.assert_fails(level, "campo desconocido 'extra'")
        del waves[4]["extra"]
        self.find_obj(level, "barra_99")["params"]["wait_s"] = 100
        self.assert_fails(level, "wait_s = 100 fuera de [3.0, 60.0]")
        level = self.load("actualizaciones_test")
        set_cell(level, 24, 9, "#")
        self.assert_fails(level, "ocupa una celda que el grid debe dejar vacia")


class ValidationBlockSchemaTest(unittest.TestCase):
    """Bloque opcional `validation` (2026-10-16, paso 10 de docs/propuesta-1-2.md §10): parametros
    del diseno que comprueba tools/validate_level.py (margen de tiempo, Posponer obligatorio,
    laser / Debug obligatorios, energia inicial y presupuesto de Sync Rate)."""

    def load(self, name):
        with open(os.path.join(ROOT, "data", "levels", "%s.json" % name), encoding="utf-8") as fh:
            return json.load(fh)

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_rooms_with_validation_are_valid(self):
        for name in ("recordatorios_test", "correo_test"):
            level = self.load(name)
            self.assertIn("validation", level)
            self.assertEqual(vls.validate_level(level), [], name)

    def test_all_fields(self):
        level = self.load("recordatorios_test")
        level["validation"] = {"time_margin_s": 1.0, "snooze_required": ["posponer_1"], "laser_required": True,
                               "debug_required": False, "start_energy": 50, "sync_damage_budget": 10,
                               "hazard_margin_s": 0.1}
        self.assertEqual(vls.validate_level(level), [])

    def test_bad_values(self):
        level = self.load("recordatorios_test")
        level["validation"] = {"tiempo": 1}
        self.assert_fails(level, "validation: campo desconocido 'tiempo'")
        level["validation"] = {"time_margin_s": -1}
        self.assert_fails(level, "validation.time_margin_s debe ser un numero entre 0 y 30")
        level["validation"] = {"hazard_margin_s": 0.8}
        self.assert_fails(level, "validation.hazard_margin_s debe ser un numero entre 0 y 0.5")
        level["validation"] = {"start_energy": 150}
        self.assert_fails(level, "validation.start_energy debe ser un numero entre 0 y 100")
        level["validation"] = {"laser_required": "si"}
        self.assert_fails(level, "validation.laser_required debe ser un booleano")
        level["validation"] = {"snooze_required": ["no_existe"]}
        self.assert_fails(level, "validation.snooze_required: el grupo de recordatorios 'no_existe' no existe")
        level["validation"] = {"snooze_required": "posponer_1"}
        self.assert_fails(level, "validation.snooze_required debe ser una lista")
        level["validation"] = []
        self.assert_fails(level, "'validation' debe ser un objeto")


class CalcRoomSchemaTest(unittest.TestCase):
    """Acertijo de la azotea del 1-2 (encuentro con Calc, 2026-10-17, tanda H1 del paso 14):
    data/levels/calc_test.json y variantes rotas (ids, enlaces, parametros en rango, guion de Eco)."""

    def load(self):
        with open(os.path.join(ROOT, "data", "levels", "calc_test.json"), encoding="utf-8") as fh:
            return json.load(fh)

    def find_obj(self, level, oid):
        return next(o for o in level["objects"] if o["params"].get("id") == oid)

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_calc_test_is_valid(self):
        self.assertEqual(vls.validate_level(self.load()), [])

    def test_switch_params_in_range(self):
        level = self.load()
        self.find_obj(level, "interruptor_luz")["params"]["pulses"] = 7
        self.assert_fails(level, "pulses = 7 fuera de [1, 6]")
        self.find_obj(level, "interruptor_luz")["params"]["pulses"] = 2.5
        self.assert_fails(level, "pulses debe ser un entero")
        level = self.load()
        self.find_obj(level, "panel_oculto")["params"]["done_if_ally"] = "cortana"
        self.assert_fails(level, "done_if_ally 'cortana' no admitido")
        level = self.load()
        self.find_obj(level, "dock_calc")["params"]["charge_s"] = 0.1
        self.assert_fails(level, "charge_s = 0.1 fuera de [0.5, 20.0]")
        level = self.load()
        del self.find_obj(level, "interruptor_laser")["params"]["id"]
        self.assert_fails(level, "falta el param obligatorio 'id'")

    def test_links(self):
        level = self.load()
        self.find_obj(level, "pared_glitch")["params"]["door_when"] = "dock_calc"
        self.assert_fails(level, "door_when 'dock_calc' no es el id de ningun power_switch ni debug_switch")
        level = self.load()
        self.find_obj(level, "pared_glitch")["params"]["lamps"] = ["a", "b", "c", "d"]
        self.assert_fails(level, "lamps debe ser una lista de a lo sumo 3 ids")
        level = self.load()
        self.find_obj(level, "pared_glitch")["params"]["height_tiles"] = 3
        self.assert_fails(level, "la puerta (door_when) solo admite un bloque de 1x2")
        level = self.load()
        self.find_obj(level, "cuarto")["params"]["switch"] = "nada"
        self.assert_fails(level, "switch 'nada' no es el id")
        level = self.load()
        self.find_obj(level, "cuarto")["params"]["width_tiles"] = 40
        self.assert_fails(level, "el cuarto se sale del grid")
        level = self.load()
        self.find_obj(level, "dock_calc")["params"]["requires"] = []
        self.assert_fails(level, "requires debe ser una lista no vacia")
        self.find_obj(level, "dock_calc")["params"]["requires"] = ["fantasma"]
        self.assert_fails(level, "requires 'fantasma' no es el id")
        level = self.load()
        self.find_obj(level, "terminal_azotea")["params"]["power_source"] = "interruptor_luz"
        self.assert_fails(level, "power_source 'interruptor_luz' no es el id de ningun charge_dock")
        self.find_obj(level, "terminal_azotea")["params"]["requires_power"] = "si"
        self.assert_fails(level, "requires_power debe ser true o false")

    def test_calc_path(self):
        level = self.load()
        self.find_obj(level, "calc")["params"]["path"] = [[7, 9]]
        self.assert_fails(level, "path debe ser una lista de al menos 2 celdas")
        self.find_obj(level, "calc")["params"]["path"] = [[7, 9], [13, 3]]
        self.assert_fails(level, "path[1] [13, 3] fuera del grid o en terreno")
        self.find_obj(level, "calc")["params"]["path"] = [[8, 9], [13, 9]]
        self.assert_fails(level, "path[0] debe ser su celda (7, 9)")
        self.find_obj(level, "calc")["params"]["dock"] = "terminal_azotea"
        self.assert_fails(level, "dock 'terminal_azotea' no es el id de ningun charge_dock")

    def test_eco_guide(self):
        level = self.load()
        self.find_obj(level, "guia_calc")["params"]["guide"] = "no_existe"
        self.assert_fails(level, "guide 'no_existe' no esta en data/eco_guides.json")
        level = self.load()
        level["objects"] = [o for o in level["objects"] if o["params"].get("id") != "panel_oculto"]
        level["objects"][[o["params"].get("id") for o in level["objects"]].index("dock_calc")]["params"]["requires"] = \
            ["interruptor_luz"]
        level["objects"][[o["params"].get("id") for o in level["objects"]].index("pared_glitch")]["params"]["lamps"] = []
        self.assert_fails(level, "object 'panel_oculto' no es el id de ninguna pieza del nivel")

    def test_guide_steps(self):
        guides = {"g": {"steps": [{"do": "bailar"}, {"do": "line"}, {"do": "wait_ability", "ability": "salto"},
                                  {"do": "wait_s", "seconds": 0}, {"do": "fly"}, {"do": "line", "text": " "}]}}
        validator = vls.LevelValidator(self.load())
        validator.grid = self.load()["grid"]
        validator._check_guide("guia", 1, 1, "g", guides, {})
        joined = "\n".join(validator.errors)
        for fragment in ("accion desconocida", "(line): falta 'text'", "ability debe ser una de pulse, laser, debug",
                         "seconds debe estar en (0, 30]", "(fly): necesita object o cell", "text debe ser un texto no vacio"):
            self.assertIn(fragment, joined)


if __name__ == "__main__":
    unittest.main()
