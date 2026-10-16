"""Pruebas de tools/validate_level.py (alcanzabilidad) sobre data/levels/1-1.json y
variantes rotas construidas en memoria.
Uso: python3 -m unittest tests/test_validate_level.py
"""

import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level as vl  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "1-1.json")
SCRIPT = os.path.join(ROOT, "tools", "validate_level.py")

_BASE = None
_BASE_RESULT = None


def base_level():
    global _BASE
    if _BASE is None:
        with open(LEVEL_PATH, encoding="utf-8") as handle:
            _BASE = json.load(handle)
    return copy.deepcopy(_BASE)


def base_result():
    global _BASE_RESULT
    if _BASE_RESULT is None:
        _BASE_RESULT = vl.validate(base_level())
    return _BASE_RESULT


def set_cell(level, x, y, char):
    row = level["grid"][y]
    level["grid"][y] = row[:x] + char + row[x + 1:]


def fill(level, cols, rows, char):
    for y in rows:
        for x in cols:
            set_cell(level, x, y, char)


def obj(level, kind):
    return next(o for o in level["objects"] if o["type"] == kind)


def obj_id(level, oid):
    return next(o for o in level["objects"] if o.get("params", {}).get("id") == oid)


def secret(level, sid):
    return next(s for s in level["secrets"] if s["id"] == sid)


def messages(result, key="errors"):
    return [e["message"] for e in result[key]]


class RealLevelTest(unittest.TestCase):
    def test_level_1_1_passes_with_path_and_margin(self):
        result = base_result()
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        margins = result["margins"]
        self.assertLessEqual(margins["max_horizontal"], vl.DEFAULT_LIMIT)
        self.assertLessEqual(margins["max_vertical"], vl.DEFAULT_LIMIT)
        self.assertGreater(margins["min_margin"], 0.0)
        actions = [a["action"] for a in result["path"]]
        self.assertEqual(actions[-1], "goal")
        pulses = [a["object"] for a in result["path"] if a["action"] == "pulse"]
        # Las puertas obligatorias se abren con el pulso y en el orden del nivel (1-1 ampliado); las
        # de los secretos (puente_servicio, popup_alto) no entran en el camino principal, y las
        # Burbujas en abierto (2026-10-15) se pueden saltar: solo burbuja_1 (3a) obliga al pulso.
        # Sala del laser (3b, rediseno 2026-10-15): dos receptores en escalera y un pop-up en alto.
        self.assertEqual(pulses, ["puente puente_1", "puente puente_2", "puente puente_3", "Burbuja burbuja_1",
                                  "puente puente_laser_1", "puente puente_laser_2", "pop-up popup_laser",
                                  "pop-up popup_1", "pop-up popup_2", "puente puente_4", "pop-up popup_3"])
        self.assertNotIn("laser", actions, "la meta no necesita disparar el laser")
        pickups = [a for a in result["path"] if a["action"] == "pickup"]
        # Encuentro con Eco (2026-10-16): el pulso no existe al empezar; lo da el encuentro.
        self.assertEqual([a["object"] for a in pickups], ["encuentro con Eco eco_encuentro",
                                                          "objeto de habilidad laser_1_1"])
        self.assertEqual(result["pulse"], {"from_start": False, "given_by": ["eco_encuentro"],
                                           "encounter": ["eco_encuentro"], "available_from_col": 10})
        self.assertLess(actions.index("pickup"), actions.index("pulse"), "el encuentro va antes de todo pulso")
        self.assertLess(actions.index("pickup"), [a.get("object") for a in result["path"]].index("pop-up popup_1"))
        self.assertEqual(result["checkpoints"][0]["reachable_from"], "P")
        # Terminal de salida (2026-10-15): se activa con el pulso desde la propia celda G.
        self.assertEqual(result["exit_terminals"], [{"id": "terminal_salida", "pulse_from": [9, 290]}])
        # El laser: se alcanza, es obligatorio (en el camino de la meta) y la meta se alcanza sin usarlo.
        abilities = result["abilities"]
        self.assertEqual(abilities["pickups"], [
            {"id": "eco_encuentro", "ability": "pulse", "row": 0, "col": 10, "reachable": True, "mandatory": True,
             "secret": False, "encounter": True},
            {"id": "laser_1_1", "ability": "laser", "row": 5, "col": 173, "reachable": True, "mandatory": True,
             "secret": False}])
        self.assertTrue(abilities["goal_without_laser"])
        for bubble in (g for g in result["gates"] if g["kind"] == "bubble"):
            self.assertEqual(bubble["bypassable"], bubble["open"], bubble["id"])
            self.assertNotIn("pop_ledge", bubble, "ya no se busca repisa para reventarla")
            if bubble["col"] > 173:
                # Tras el laser, todas se pueden matar disparando desde su propio suelo.
                self.assertIsNotNone(bubble["laser_from"], bubble["id"])
                self.assertEqual(bubble["laser_from"][0], bubble["row"], bubble["id"])
        health = {g["id"]: g["health"] for g in result["gates"] if g["kind"] == "bubble"}
        self.assertEqual(health["burbuja_cierre"], 3.0)
        self.assertEqual(health["burbuja_3"], 2.0)
        # Los secretos de puntos (celdas S, sin 'h') se alcanzan (y sus puertas son opcionales: sin avisos).
        items = {i["id"]: i for i in result["secrets"]["items"]}
        for sid in ("secreto_puente_servicio", "secreto_techo", "secreto_popup_alto"):
            self.assertTrue(items[sid]["reachable"], sid)
        self.assertIn("bridge:puente_servicio", items["secreto_puente_servicio"]["secret_gates_opened"])
        # Secreto del Pulso amplio (2026-10-15): el unico power bank del 1-1; sin la mejora no se
        # llega, con ella si.
        wide = items["secreto_pulso_amplio"]
        self.assertEqual(wide["object"], "power_bank_pickup")
        self.assertEqual(wide["requires_upgrade"], "wide_pulse")
        self.assertFalse(wide["reachable_without_upgrade"])
        self.assertTrue(wide["reachable_with_upgrade"])
        self.assertEqual(result["rules"]["pulse_radius_px"], 96.0)

    def test_level_1_1_with_wide_pulse_upgrade(self):
        """Con Pulso amplio comprado el nivel sigue valido (meta, soft-locks) y el secreto se alcanza."""
        result = vl.validate(base_level(), upgrades=["wide_pulse"])
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        self.assertEqual(result["rules"]["pulse_radius_px"], 112.0)
        self.assertEqual(result["rules"]["base_pulse_radius_px"], 96.0)
        items = {i["id"]: i for i in result["secrets"]["items"]}
        self.assertTrue(items["secreto_pulso_amplio"]["reachable"])
        self.assertIn("popup:popup_lejano", items["secreto_pulso_amplio"]["secret_gates_opened"])

    def test_wide_pulse_button_distance_is_between_radii(self):
        """Pegado al pop-up (columna 129, fila 4, mirando a la izquierda) el boton queda a 104 px del
        celular: mas que el radio base (96) y no mas que el mejorado (112)."""
        level = base_level()
        rules = vl.Rules()
        model = vl.LevelModel(level, rules)
        gate = model.gate("popup:popup_lejano")
        T = model.T
        x = 130 * T - 64 + rules.hitbox_w * 0.5  # centro de Isak pegado a la cara derecha del pop-up
        px, py = x - rules.phone_x, 5 * T + rules.phone_y
        bx0, by0, bx1, by1, _ = gate.openers[0]
        dist = ((px - min(max(px, bx0), bx1)) ** 2 + (py - min(max(py, by0), by1)) ** 2) ** 0.5
        self.assertAlmostEqual(dist, 104.0)
        catalog = vl.load_upgrades()
        self.assertGreater(dist, rules.pulse_radius)
        self.assertLessEqual(dist, float(catalog["wide_pulse"]["value"]))
        met = frozenset({"encounter:eco_encuentro"})  # tras el encuentro con Eco (pulso)
        self.assertFalse(model.can_open(gate, (129, 4), met))
        upgraded = vl.LevelModel(level, rules.with_upgrades(["wide_pulse"]))
        self.assertTrue(upgraded.can_open(upgraded.gate("popup:popup_lejano"), (129, 4), met))
        self.assertFalse(upgraded.can_open(upgraded.gate("popup:popup_lejano"), (129, 4), frozenset()),
                         "sin pasar por el encuentro no hay pulso")

    def test_uses_game_physics_file(self):
        rules = vl.Rules()
        with open(os.path.join(ROOT, "data", "isak_physics.json"), encoding="utf-8") as handle:
            physics = json.load(handle)
        self.assertEqual(rules.walk_speed, physics["walk_speed"])
        self.assertAlmostEqual(rules.nominal_height, physics["jump_velocity"] ** 2 / (2 * physics["gravity"]))
        self.assertAlmostEqual(rules.jump_height, rules.nominal_height * vl.DEFAULT_JUMP_EFFICIENCY)
        self.assertEqual((rules.hitbox_w, rules.hitbox_h), (32.0, 80.0))

    def test_cli_exit_codes_and_json(self):
        ok = subprocess.run([sys.executable, SCRIPT, "--json", LEVEL_PATH], capture_output=True, text=True)
        self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
        data = json.loads(ok.stdout)[LEVEL_PATH]
        self.assertTrue(data["ok"])
        self.assertIn("min_margin", data["margins"])
        upgraded = subprocess.run([sys.executable, SCRIPT, "--upgrades", "wide_pulse", LEVEL_PATH],
                                  capture_output=True, text=True)
        self.assertEqual(upgraded.returncode, 0, upgraded.stdout + upgraded.stderr)
        self.assertIn("radio 112 px", upgraded.stdout)
        unknown = subprocess.run([sys.executable, SCRIPT, "--upgrades", "no_existe", LEVEL_PATH],
                                 capture_output=True, text=True)
        self.assertEqual(unknown.returncode, 2)
        strict = subprocess.run([sys.executable, SCRIPT, "--limit", "0.7", LEVEL_PATH], capture_output=True, text=True)
        self.assertNotEqual(strict.returncode, 0)
        self.assertIn("exige", strict.stdout)


class BrokenVariantsTest(unittest.TestCase):
    def assert_fails(self, level, *needles, schema=True):
        result = vl.validate(level, check_schema=schema)
        self.assertFalse(result["ok"], "deberia fallar")
        text = "\n".join(messages(result))
        for needle in needles:
            self.assertIn(needle, text)
        return result

    def test_exit_terminal_needs_the_pulse(self):
        level = base_level()
        level["abilities_available"]["pulse"] = False
        level["objects"] = [o for o in level["objects"] if o["type"] != "eco_encounter"]
        self.assert_fails(level, "terminal de salida terminal_salida necesita el pulso", schema=False)

    def test_pulse_does_not_exist_before_the_encounter(self):
        """Encuentro con Eco (2026-10-16): un receptor antes del encuentro exige un pulso que aun no
        existe (aunque el nivel tenga un camino si el pulso estuviera)."""
        level = base_level()
        enc = obj(level, "eco_encounter")
        enc["x"] = 60  # el encuentro pasa detras del puente_1 (receptor en la columna 56)
        result = self.assert_fails(level, "puente puente_1 exige el pulso y esta antes de encuentro con Eco",
                                   schema=False)
        self.assertIn("aun no se tiene", "\n".join(messages(result)))

    def test_bubble_under_ceiling_before_the_encounter_fails(self):
        level = base_level()
        obj(level, "eco_encounter")["x"] = 140  # tras burbuja_1 (techo bajo del 3a)
        self.assert_fails(level, "Burbuja burbuja_1 exige el pulso y esta antes de encuentro con Eco", schema=False)

    def test_skippable_encounter_fails(self):
        """El encuentro tiene que ser obligatorio: si se puede pasar sin tocarlo, falla."""
        level = base_level()
        enc = obj(level, "eco_encounter")
        enc["params"]["height_tiles"] = 2  # zona en lo alto (filas 0-1): se pasa por debajo
        result = vl.validate(level, check_schema=False)
        self.assertIn("pulso", " ".join(messages(result)))
        self.assertFalse(result["ok"])

    def test_level_with_pulse_from_start_needs_no_encounter(self):
        level = base_level()
        level["abilities_available"]["pulse"] = True
        level["objects"] = [o for o in level["objects"] if o["type"] != "eco_encounter"]
        result = vl.validate(level)
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["pulse"], {"from_start": True, "given_by": [], "encounter": []})

    def test_exit_terminal_out_of_pulse_reach(self):
        level = base_level()
        catalog_rect = [0, -900, 64, 32]  # zona de golpe muy por encima: el pulso no llega
        rules = vl.Rules()
        validator = vl.Validator(level, rules)
        validator.model.catalog = dict(validator.model.catalog)
        validator.model.catalog["exit_terminal"] = {"hit_rect_px": catalog_rect}
        result = validator.run()
        self.assertFalse(result["ok"])
        self.assertIn("el pulso no la alcanza", "\n".join(messages(result)))

    def test_gap_of_five_tiles(self):
        level = base_level()
        fill(level, range(20, 25), (10, 11, 12), ".")
        self.assert_fails(level, "no hay camino de P a G", "fila 12")

    def test_step_of_four_tiles(self):
        level = base_level()
        fill(level, (51, 52), range(6, 10), "#")
        self.assert_fails(level, "no hay camino de P a G", "columna 50")

    def test_jump_over_limit_is_reported(self):
        level = base_level()
        fill(level, (22, 23), (10, 11, 12), ".")  # foso sin fondo alcanzable
        fill(level, range(24, 30), (9,), "#")  # la otra orilla un tile mas alta (hasta la Burbuja de la 30)
        self.assert_fails(level, "exige 89 % del alcance horizontal", "limite 85 %")

    def test_without_receiver(self):
        level = base_level()
        level["objects"] = [o for o in level["objects"] if o["type"] != "receiver"]
        self.assert_fails(level, "puente puente_1 no tiene receptor", schema=False)

    def test_without_popup_button(self):
        level = base_level()
        del obj_id(level, "popup_1")["params"]["close_button_px"]
        self.assert_fails(level, "pop-up popup_1 no tiene boton", schema=False)

    def test_popup_button_out_of_pulse_reach(self):
        level = base_level()
        obj_id(level, "popup_1")["params"]["close_button_px"] = [4, 8]
        self.assert_fails(level, "el pulso no alcanza boton de cerrar", "columna 215")

    def test_raised_ceiling_only_warns_that_pulse_is_optional(self):
        level = base_level()
        fill(level, range(126, 140), (6, 7), ".")  # techo de 3a (Burbuja en la columna 132)
        result = vl.validate(level)
        self.assertTrue(result["ok"], messages(result))
        self.assertTrue(any("pulso no es obligatorio para la Burbuja" in w for w in messages(result, "warnings")))

    def test_open_bubble_under_ceiling_warns(self):
        level = base_level()
        next(e for e in level["enemies"] if e["id"] == "burbuja_1")["open"] = True
        result = vl.validate(level)
        self.assertTrue(result["ok"], messages(result))
        self.assertTrue(any("burbuja_1 esta marcada en abierto (open) pero bloquea" in w
                            for w in messages(result, "warnings")))

    def test_open_bubble_needs_no_ledge(self):
        """Desde el 2026-10-15 pisarla no la mata: una Burbuja en abierto sin repisa no avisa."""
        level = base_level()
        fill(level, range(184, 189), (7,), ".")  # repisa del 3c (burbuja_3 y burbuja_4)
        set_cell(level, 186, 6, ".")  # y su punto
        result = vl.validate(level)
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])

    # --- Laser (rediseno 2026-10-15) ---

    def test_laser_pickup_skippable_warns(self):
        """Sin el techo bajo del tunel, la celda del laser se salta: deja de ser obligatorio."""
        level = base_level()
        fill(level, range(172, 176), (1, 2, 3), ".")
        result = vl.validate(level)
        self.assertTrue(any("laser_1_1 (laser) no es obligatorio" in w for w in messages(result, "warnings")),
                        messages(result, "warnings"))
        laser = next(p for p in result["abilities"]["pickups"] if p["id"] == "laser_1_1")
        self.assertFalse(laser["mandatory"])

    def test_laser_pickup_unreachable(self):
        level = base_level()
        pickup = obj(level, "ability_pickup")
        pickup["y"] = 0  # encima de la sala, fuera del alcance
        self.assert_fails(level, "objeto de habilidad laser_1_1 (laser) no se alcanza", schema=False)

    def test_laser_reaches_bubble_from_afar_and_stops_at_walls(self):
        level = base_level()
        rules = vl.Rules()
        model = vl.LevelModel(level, rules)
        gate = model.gate("bubble:burbuja_3")  # (182, 9), patrulla de 128 px
        with_laser = frozenset({"pickup:laser_1_1"})
        self.assertTrue(model.laser_possible)
        self.assertFalse(model.has_laser(frozenset()))
        self.assertTrue(model.has_laser(with_laser))
        far = (176, 9)  # a 4 tiles, en su suelo
        self.assertTrue(model.laser_hits(gate, far, with_laser))
        self.assertTrue(model.can_open(gate, far, with_laser))
        self.assertFalse(model.can_open(gate, far, frozenset()), "sin el laser el pulso no llega tan lejos")
        self.assertFalse(model.can_open(gate, far, with_laser, use_laser=False))
        self.assertFalse(model.laser_hits(gate, (186, 6), with_laser), "desde la repisa el haz pasa por encima")
        # Una pared entre Isak y la Burbuja corta el haz.
        fill(level, (179,), (8, 9), "#")
        walled = vl.LevelModel(level, rules)
        self.assertFalse(walled.laser_hits(walled.gate("bubble:burbuja_3"), far, with_laser))
        # Alcance maximo: 768 px.
        self.assertFalse(model.laser_hits(model.gate("bubble:burbuja_cierre"), (176, 9), with_laser))

    def test_extended_bridge_is_a_thin_board(self):
        """Un puente extendido es una tabla fina en lo alto de su celda: se puede estar de pie debajo,
        pero no atravesarla saltando."""
        level = base_level()
        model = vl.LevelModel(level, vl.Rules())
        opened = frozenset({"bridge:puente_laser_1"})  # (159-162, 8), 2 tiles sobre el suelo
        world = model.world(opened)
        self.assertTrue(world.is_node(160, 9), "de pie bajo el puente")
        self.assertTrue(world.is_node(160, 7), "de pie encima")
        self.assertTrue(world.collides((160.5) * 64, 9 * 64 - 40), "la cabeza choca con la tabla")
        edges = {e["to"] for e in world.compute_edges((160, 9))}
        self.assertNotIn((160, 7), edges, "no se sube atravesando la tabla")

    def test_spikes_at_spawn(self):
        level = base_level()
        set_cell(level, 4, 3, "P")  # P en el aire (el 1-1 la tiene en el suelo desde 2026-10-15)
        set_cell(level, 4, 9, "^")  # donde cae Isak desde P
        self.assert_fails(level, "pinchos en el punto de aparicion P", "columna 4", schema=False)

    def test_spikes_at_checkpoint(self):
        level = base_level()
        set_cell(level, 151, 9, "^")
        self.assert_fails(level, "pinchos en el primer tile del punto de sincronizacion sync_1", schema=False)

    def test_unreachable_checkpoint(self):
        level = base_level()
        set_cell(level, 60, 2, "C")
        level["checkpoints"].append({"id": "sync_2", "x": 60, "y": 2})
        self.assert_fails(level, "sync_2 inalcanzable desde sync_1", "fila 2, columna 60")

    def test_pit_without_step_is_soft_lock(self):
        level = base_level()
        set_cell(level, 59, 12, ".")  # sin el escalon el foso del puente no tiene salida
        self.assert_fails(level, "soft-lock", "fila 12, columnas 59-64")

    def test_bridge_not_needed_warns(self):
        level = base_level()
        fill(level, range(59, 65), (10, 11, 12), "#")
        obj(level, "bridge_inactive")["y"] = 9
        obj(level, "bridge_inactive")["params"]["length_tiles"] = 1
        obj(level, "bridge_inactive")["x"] = 65
        fill(level, (65,), (9,), ".")
        result = vl.validate(level, check_schema=False)
        self.assertTrue(any("puente puente_1 no es obligatorio" in w for w in messages(result, "warnings")),
                        messages(result, "warnings"))

    def test_upgrade_secret_reachable_without_upgrade_fails(self):
        level = base_level()
        obj_id(level, "popup_lejano")["params"]["close_button_px"] = [60, 192]  # 96 px: llega el pulso base
        self.assert_fails(level, "secreto_pulso_amplio (power_bank_pickup) se alcanza sin la mejora wide_pulse")

    def test_upgrade_secret_unreachable_even_with_upgrade_fails(self):
        level = base_level()
        obj_id(level, "popup_lejano")["params"]["close_button_px"] = [36, 192]  # 120 px: ni con 112
        self.assert_fails(level, "secreto_pulso_amplio (power_bank_pickup) no se alcanza ni con la mejora wide_pulse")

    def test_points_secret_must_be_reachable(self):
        level = base_level()
        del secret(level, "secreto_pulso_amplio")["requires_upgrade"]
        self.assert_fails(level, "el secreto secreto_pulso_amplio (power_bank_pickup) no se alcanza")
        # Con la mejora comprada se alcanza y no hay error.
        result = vl.validate(level, upgrades=["wide_pulse"])
        self.assertTrue(result["ok"], messages(result))

    def test_unknown_upgrade(self):
        with self.assertRaises(ValueError):
            vl.validate(base_level(), upgrades=["no_existe"])

    def test_hidden_platform_secret(self):
        level = base_level()
        # Secreto en lo alto, solo accesible por dos plataformas ocultas.
        set_cell(level, 66, 8, "h")
        set_cell(level, 68, 6, "h")
        set_cell(level, 68, 5, "S")
        level["secrets"].append({"id": "secreto_h", "x": 68, "y": 5, "needs_debug": True})
        result = vl.validate(level, check_schema=False)
        self.assertTrue(result["ok"], messages(result))
        item = next(i for i in result["secrets"]["items"] if i["id"] == "secreto_h")
        self.assertFalse(item["without_debug"])
        self.assertTrue(item["with_debug"])
        # Si se llega sin Debug, falla.
        set_cell(level, 69, 8, "S")
        level["secrets"].append({"id": "secreto_facil", "x": 69, "y": 8, "needs_debug": True})
        self.assert_fails(level, "secreto_facil se alcanza sin pasar por plataformas ocultas", schema=False)

    def test_extra_life_behind_glitch_wall_needs_debug(self):
        """Regla 4b (2026-10-16): la vida extra del 1-1 esta tras la pared con glitch del secreto D:
        no se alcanza sin Debug, si con Debug, y no es obligatoria."""
        item = next(i for i in base_result()["extra_lives"] if i["id"] == "vida_extra_1_1")
        self.assertTrue(item["behind_glitch_wall"])
        self.assertFalse(item["reachable_without_debug"])
        self.assertTrue(item["reachable_with_debug"])
        self.assertFalse(item["mandatory"])

    def test_extra_life_unreachable_even_with_debug(self):
        level = base_level()
        fill(level, [297], [8, 9], "#")  # tapia delante de la pared con glitch
        self.assert_fails(level, "la vida extra vida_extra_1_1 no se alcanza ni con el Debug", schema=False)

    def test_extra_life_in_the_open_is_reachable_without_debug(self):
        level = base_level()
        obj_id(level, "vida_extra_1_1")["x"] = 296
        result = vl.validate(level, check_schema=False)
        self.assertTrue(result["ok"], messages(result))
        item = result["extra_lives"][0]
        self.assertFalse(item["behind_glitch_wall"])
        self.assertTrue(item["reachable_without_debug"])


if __name__ == "__main__":
    unittest.main()
