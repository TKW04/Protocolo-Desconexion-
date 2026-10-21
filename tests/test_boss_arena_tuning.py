#!/usr/bin/env python3
"""Ajustes de la arena de Alerta Mayor tras la primera prueba (2026-10-21, docs/propuesta-jefe-alerta-mayor.md
§6.4): escala propia del mundo con el Debug (debug_world_scale), separacion de la rafaga, laterales de una via
en la fase 3 y la subida a la plataforma central en Raíz.
"""

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tests", "support"))
import build_level  # noqa: E402
import puzzle_levels as pz  # noqa: E402
import validate_boss as vb  # noqa: E402
import validate_level as vl  # noqa: E402
import validate_level_schema as vls  # noqa: E402

LEVEL = os.path.join(ROOT, "data", "levels", "1-boss.json")
BOSS = os.path.join(ROOT, "data", "bosses", "alert_major.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def messages(result):
    return [e["message"] for e in result["errors"]]


class WorldScaleTest(unittest.TestCase):
    """1) debug_world_scale: la arena va a x0,7 con el Debug; los demas niveles, a la global (x0,5)."""

    @classmethod
    def setUpClass(cls):
        cls.level = load(LEVEL)
        cls.boss = load(BOSS)
        cls.result = vb.validate_arena(cls.level)

    def test_arena_uses_0_7(self):
        self.assertEqual(self.level["debug_world_scale"], 0.7)
        self.assertTrue(self.result["ok"], messages(self.result))
        self.assertAlmostEqual(self.result["boss"]["debug_world_scale"], 0.7)
        with open(os.path.join(ROOT, "scenes", "levels", "1-boss.tscn"), encoding="utf-8") as handle:
            self.assertIn("debug_world_scale = 0.7", handle.read())

    def test_other_levels_do_not_use_it(self):
        for name in ("1-1", "1-2", "1-3", "boss_test"):
            self.assertNotIn("debug_world_scale", load(os.path.join(ROOT, "data", "levels", "%s.json" % name)), name)
            with open(os.path.join(ROOT, "scenes", "levels", "%s.tscn" % name), encoding="utf-8") as handle:
                self.assertNotIn("debug_world_scale", handle.read(), name)

    def test_schema_range(self):
        level = copy.deepcopy(self.level)
        for value in (0.1, 0.7, 1):
            level["debug_world_scale"] = value
            self.assertEqual(vls.validate_level(level, ROOT), [], value)
        for value in (0, -0.5, 1.2, "0.7", True):
            level["debug_world_scale"] = value
            self.assertTrue(any("debug_world_scale" in e for e in vls.validate_level(level, ROOT)), value)

    def test_build_level_writes_the_field_only_if_present(self):
        level = copy.deepcopy(self.level)
        self.assertIn("debug_world_scale = 0.7", build_level.build_scene(level, ROOT))
        del level["debug_world_scale"]
        self.assertNotIn("debug_world_scale", build_level.build_scene(level, ROOT))

    def test_rules_keep_the_debug_4_ratio(self):
        rules = vl.Rules(ROOT, None, vl.DEFAULT_JUMP_EFFICIENCY, vl.DEFAULT_LIMIT, True)
        self.assertAlmostEqual(rules.debug_world_scale, 0.5)
        rules.set_level_debug_world_scale(0.7)
        self.assertAlmostEqual(rules.debug_world_scale, 0.7)
        self.assertEqual(rules.changed_by_upgrades(), {}, "la escala del nivel no es una mejora")
        up = rules.with_upgrades(["debug:4"])
        self.assertAlmostEqual(up.debug_world_scale, 0.56, msg="Debug 4: 0,7 x 0,4 / 0,5")
        self.assertAlmostEqual(rules.with_allies(()).debug_world_scale, 0.7)
        none = vl.Rules(ROOT, None, vl.DEFAULT_JUMP_EFFICIENCY, vl.DEFAULT_LIMIT, True)
        none.set_level_debug_world_scale(None)
        self.assertAlmostEqual(none.debug_world_scale, 0.5)

    def test_plan_uses_the_level_scale(self):
        level = pz.hidden_gap(chip=True)
        base = vl.validate(copy.deepcopy(level))
        level["debug_world_scale"] = 0.8
        fast = vl.validate(level)
        self.assertTrue(base["ok"] and fast["ok"], messages(fast))
        self.assertNotIn("debug_world_scale", base["plan"]["energy"])
        self.assertAlmostEqual(fast["plan"]["energy"]["debug_world_scale"], 0.8)
        self.assertGreater(fast["plan"]["duration_world_s"], base["plan"]["duration_world_s"],
                           "con el mundo menos lento el mismo camino pasa mas tiempo del mundo")
        self.assertIn("    mundo con el Debug en este nivel: x0.8 (debug_world_scale)", vl.format_plan(fast["plan"]))

    def test_windows_need_more_with_a_faster_world_but_fit(self):
        level = copy.deepcopy(self.level)
        level["debug_world_scale"] = 0.5
        slow = vb.validate_arena(level, boss=self.boss)
        need = {(w["phase"], w["spot"]): w["need_s"] for w in self.result["boss"]["windows"]}
        for w in slow["boss"]["windows"]:
            self.assertGreaterEqual(need[(w["phase"], w["spot"])] + 1e-9, w["need_s"], w["spot"])
            self.assertLessEqual(need[(w["phase"], w["spot"])], w["window_s"], w["spot"])

    def test_running_charge_strategy(self):
        rules = vl.Rules(ROOT, None, vl.DEFAULT_JUMP_EFFICIENCY, vl.DEFAULT_LIMIT, True)
        rules.set_level_debug_world_scale(0.7)
        arena = type("A", (), {"rules": rules})()
        poses = rules.pulse_pose_s + rules.laser_pose_s
        travel = 2.23
        expected = rules.debug_hold_s + 0.7 * (travel - rules.debug_hold_s + poses)
        self.assertAlmostEqual(vb._window_need(arena, travel), expected)
        self.assertAlmostEqual(vb._window_need(arena, 0.0), rules.debug_hold_s + 0.7 * poses)

    def test_mark_fits_the_worst_clumsy_window(self):
        mark = self.result["boss"]["mark"]
        for lap in ("1", "2", "3"):
            self.assertGreaterEqual(mark[lap]["shots"], mark[lap]["need"], lap)
            self.assertGreaterEqual(mark[lap]["shots_with_debug"], mark[lap]["shots"], lap)
        boss = copy.deepcopy(self.boss)
        boss["laps"]["3"]["mark_duration_s"] = 0.5
        msgs = messages(vb.validate_arena(self.level, boss=boss))
        self.assertTrue(any("vuelta 3: en la marca" in m for m in msgs), msgs)

    def test_energy_margins_unchanged(self):
        # El gasto del Debug va en tiempo real y el modelo torpe cuenta segundos reales: el mundo mas rapido
        # no lo sube (§6.4). Margenes: Caché 32,5, Kernel 22,5 y Raíz 20.
        for lap, margin in (("1", 32.5), ("2", 22.5), ("3", 20.0)):
            self.assertAlmostEqual(self.result["boss"]["energy"][lap]["base"]["min_margin"], margin, places=2)

    def test_telegraphs_last_longer_with_the_debug(self):
        text = vb.format_text("1-boss", self.result)
        self.assertIn("mundo con el Debug: x0.7 (los avisos duran x1.43 en tiempo real con el Debug)", text)


class BurstSpacingTest(unittest.TestCase):
    """2) Rafaga: notificaciones cada 0,9 s (antes 0,5; 0,75 no bastaba: el dash acerca a Isak a la siguiente) y
    burst_every_s 4,75 (antes 4,5): el dash las atraviesa una a una."""

    @classmethod
    def setUpClass(cls):
        cls.level = load(LEVEL)
        cls.boss = load(BOSS)

    def test_spacing_is_0_9_and_fits_the_burst_interval(self):
        self.assertEqual(self.boss["phase2"]["burst_spacing_s"], 0.9)
        self.assertEqual(self.boss["phase2"]["burst_every_s"], 4.75)
        result = vb.validate_arena(self.level, boss=self.boss)
        self.assertTrue(result["ok"], messages(result))
        rep = result["boss"]
        self.assertLessEqual(rep["burst_busy_s"], rep["burst_every_s"])
        self.assertGreaterEqual(rep["burst_dash"]["spacing_s"], rep["burst_dash"]["dash_cycle_s"])
        self.assertLessEqual(rep["burst_dash"]["pass_s"], rep["burst_dash"]["invulnerable_s"])

    def test_old_and_0_75_spacing_cannot_be_dashed(self):
        for value in (0.5, 0.75):
            boss = copy.deepcopy(self.boss)
            boss["phase2"]["burst_spacing_s"] = value
            msgs = messages(vb.validate_arena(self.level, boss=boss))
            self.assertTrue(any("no se atraviesa con el dash" in m for m in msgs), (value, msgs))

    def test_longer_burst_needs_its_interval(self):
        boss = copy.deepcopy(self.boss)
        boss["phase2"]["burst_every_s"] = 4.5
        msgs = messages(vb.validate_arena(self.level, boss=boss))
        self.assertTrue(any("dos rafagas" in m for m in msgs), msgs)

    def test_help_text_still_matches(self):
        text = load(os.path.join(ROOT, "data", "help.json"))["types"]["notification_shot"]["text"]
        self.assertIn("deslízate a través de cada una", text)
        self.assertIn("retrocediendo un paso", text)
        self.assertIn("cambia de altura", text)


class SidePlatformsTest(unittest.TestCase):
    """3) Laterales de la fase 3 de una via (blink_platform one_way) y campanas fuera de ellas (2, 11 y 21)."""

    @classmethod
    def setUpClass(cls):
        cls.level = load(LEVEL)
        cls.boss = load(BOSS)

    def blinks(self, level):
        return [o for o in level["objects"] if o["type"] == "blink_platform"]

    def test_arena_blinks_are_one_way_and_bells_moved(self):
        self.assertEqual([o["params"].get("one_way") for o in self.blinks(self.level)], [True] * 4)
        bells = sorted(e["x"] for e in self.level["enemies"] if e["type"] == "alarm_bell")
        self.assertEqual(bells, [2, 11, 21])
        result = vb.validate_arena(self.level, boss=self.boss)
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["boss"]["bell_cols"], [2, 11, 21])
        with open(os.path.join(ROOT, "scenes", "levels", "1-boss.tscn"), encoding="utf-8") as handle:
            self.assertEqual(handle.read().count("one_way = true"), 4)

    def test_bells_over_the_side_platforms_are_an_error(self):
        level = copy.deepcopy(self.level)
        grid = [list(row) for row in level["grid"]]
        for e in level["enemies"]:
            if e["id"] in ("campana_1", "campana_3"):
                grid[e["y"]][e["x"]] = "."
                e["x"] = 5 if e["id"] == "campana_1" else 18
                grid[e["y"]][e["x"]] = "E"
        level["grid"] = ["".join(r) for r in grid]
        self.assertEqual(vls.validate_level(level, ROOT), [])
        msgs = messages(vb.validate_arena(level, boss=self.boss))
        self.assertTrue(any("campana campana_1 cae encima" in m for m in msgs), msgs)
        self.assertTrue(any("campana campana_3 cae encima" in m for m in msgs), msgs)

    def test_schema_one_way_is_boolean(self):
        level = copy.deepcopy(self.level)
        self.blinks(level)[0]["params"]["one_way"] = "si"
        self.assertTrue(any("one_way debe ser true o false" in e for e in vls.validate_level(level, ROOT)))

    def test_1_3_keeps_solid_blinks(self):
        level = load(os.path.join(ROOT, "data", "levels", "1-3.json"))
        self.assertFalse(any("one_way" in o.get("params", {}) for o in self.blinks(level)))
        with open(os.path.join(ROOT, "scenes", "levels", "1-3.tscn"), encoding="utf-8") as handle:
            self.assertNotIn("one_way = true", handle.read())


if __name__ == "__main__":
    unittest.main()
