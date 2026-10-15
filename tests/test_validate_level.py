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
        # Las tres puertas se abren con el pulso y en el orden del nivel.
        self.assertEqual(pulses, ["puente puente_1", "Burbuja burbuja_1", "pop-up popup_1"])
        self.assertEqual(result["checkpoints"][0]["reachable_from"], "P")
        bubble = next(g for g in result["gates"] if g["kind"] == "bubble")
        self.assertFalse(bubble["bypassable"])

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

    def test_gap_of_five_tiles(self):
        level = base_level()
        fill(level, range(20, 25), (10, 11, 12), ".")
        self.assert_fails(level, "no hay camino de P a G", "fila 12")

    def test_step_of_four_tiles(self):
        level = base_level()
        fill(level, (56, 57), range(6, 10), "#")
        self.assert_fails(level, "no hay camino de P a G", "columna 55")

    def test_jump_over_limit_is_reported(self):
        level = base_level()
        fill(level, (22, 23), (10, 11, 12), ".")  # foso sin fondo alcanzable
        fill(level, range(24, 32), (9,), "#")  # la otra orilla un tile mas alta
        self.assert_fails(level, "exige 89 % del alcance horizontal", "limite 85 %")

    def test_without_receiver(self):
        level = base_level()
        level["objects"] = [o for o in level["objects"] if o["type"] != "receiver"]
        self.assert_fails(level, "puente puente_1 no tiene receptor", schema=False)

    def test_without_popup_button(self):
        level = base_level()
        del obj(level, "popup_blocker")["params"]["close_button_px"]
        self.assert_fails(level, "pop-up popup_1 no tiene boton", schema=False)

    def test_popup_button_out_of_pulse_reach(self):
        level = base_level()
        obj(level, "popup_blocker")["params"]["close_button_px"] = [4, 8]
        self.assert_fails(level, "el pulso no alcanza boton de cerrar", "columna 112")

    def test_raised_ceiling_only_warns_that_pulse_is_optional(self):
        level = base_level()
        fill(level, range(78, 92), (6, 7), ".")
        result = vl.validate(level)
        self.assertTrue(result["ok"], messages(result))
        self.assertTrue(any("pulso no es obligatorio para la Burbuja" in w for w in messages(result, "warnings")))

    def test_spikes_at_spawn(self):
        level = base_level()
        set_cell(level, 4, 9, "^")  # donde cae Isak desde P
        self.assert_fails(level, "pinchos en el punto de aparicion P", "columna 4", schema=False)

    def test_spikes_at_checkpoint(self):
        level = base_level()
        set_cell(level, 65, 9, "^")
        self.assert_fails(level, "pinchos en el primer tile del punto de sincronizacion sync_1", schema=False)

    def test_unreachable_checkpoint(self):
        level = base_level()
        set_cell(level, 60, 2, "C")
        level["checkpoints"].append({"id": "sync_2", "x": 60, "y": 2})
        self.assert_fails(level, "sync_2 inalcanzable desde sync_1", "fila 2, columna 60")

    def test_pit_without_step_is_soft_lock(self):
        level = base_level()
        set_cell(level, 48, 12, ".")  # sin el escalon el foso del puente no tiene salida
        self.assert_fails(level, "soft-lock", "fila 12, columnas 48-53")

    def test_bridge_not_needed_warns(self):
        level = base_level()
        fill(level, range(48, 54), (10,), "#")
        obj(level, "bridge_inactive")["y"] = 9
        obj(level, "bridge_inactive")["params"]["length_tiles"] = 1
        obj(level, "bridge_inactive")["x"] = 54
        fill(level, (54,), (9,), ".")
        result = vl.validate(level, check_schema=False)
        self.assertTrue(any("puente puente_1 no es obligatorio" in w for w in messages(result, "warnings")),
                        messages(result, "warnings"))

    def test_hidden_platform_secret(self):
        level = base_level()
        # Secreto en lo alto, solo accesible por dos plataformas ocultas.
        set_cell(level, 60, 8, "h")
        set_cell(level, 62, 6, "h")
        set_cell(level, 62, 5, "S")
        level["secrets"].append({"id": "secreto_h", "x": 62, "y": 5})
        result = vl.validate(level, check_schema=False)
        self.assertTrue(result["ok"], messages(result))
        item = next(i for i in result["secrets"]["items"] if i["id"] == "secreto_h")
        self.assertFalse(item["without_debug"])
        self.assertTrue(item["with_debug"])
        # Si se llega sin Debug, falla.
        set_cell(level, 63, 8, "S")
        level["secrets"].append({"id": "secreto_facil", "x": 63, "y": 8})
        self.assert_fails(level, "secreto_facil se alcanza sin pasar por plataformas ocultas", schema=False)


if __name__ == "__main__":
    unittest.main()
