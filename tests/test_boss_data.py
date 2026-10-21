#!/usr/bin/env python3
"""Datos de los jefes (data/bosses/*.json; paso 2 de docs/propuesta-jefe-alerta-mayor.md §6).

Sala de prueba boss_test (paso 3): el jefe «saco» (boss_dummy) de 2 x 2 tiles necesita suelo
solido debajo y celdas libres; su arte es provisional (_placeholder) y esta al dia, sin carmin.

Alerta Mayor: 9 golpes en la vuelta 1 (Caché, 3/3/3) y 12 en las vueltas 2 y 3 (Kernel y Raíz,
4/4/4); el contador baja de 99 a 0 y marca 66 y 33 al cambiar de fase (la misma cuenta que
BossBase.counter_for); recargas de cambio de fase +25/+25 y reaparicion con energia >= 50.
"""

import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level_schema as vls  # noqa: E402


def counter_for(top, remaining, total):
    # Igual que BossBase.counter_for (roundi de Godot: mitades lejos de 0).
    value = top * remaining / total
    return int(value + 0.5)


class AlertMajorDataTest(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(ROOT, "data", "bosses", "alert_major.json"), encoding="utf-8") as handle:
            self.data = json.load(handle)

    def test_identity_and_refills(self):
        self.assertEqual(self.data["id"], "alert_major")
        self.assertEqual(self.data["counter"], {"max": 99, "full_label": "99+"})
        self.assertEqual(self.data["phase_change_refill"], {"energy": 25.0, "sync": 25.0})
        self.assertEqual(self.data["respawn_min_energy"], 50.0)
        self.assertFalse([k for k in self.data if "rollback" in k], "Sin rollback en el jefe del Mundo 1 (decision 1)")

    def test_hits_per_lap(self):
        laps = self.data["laps"]
        self.assertEqual(sorted(laps), ["1", "2", "3"])
        self.assertEqual(laps["1"]["hits_per_phase"], [3, 3, 3])
        self.assertEqual(laps["2"]["hits_per_phase"], [4, 4, 4])
        self.assertEqual(laps["3"]["hits_per_phase"], [4, 4, 4])

    def test_phase_thresholds_are_66_and_33(self):
        top = self.data["counter"]["max"]
        for lap, entry in self.data["laps"].items():
            hits = entry["hits_per_phase"]
            total = sum(hits)
            remaining = total
            thresholds = []
            for h in hits:
                remaining -= h
                thresholds.append(counter_for(top, remaining, total))
            self.assertEqual(thresholds, [66, 33, 0], "vuelta %s" % lap)
        caches = [counter_for(top, r, 9) for r in range(9, -1, -1)]
        self.assertEqual(caches, [99, 88, 77, 66, 55, 44, 33, 22, 11, 0])

    def test_mark_duration_per_lap(self):
        # La marca (2026-10-21, §2.3): Caché 4 s, Kernel 3 s, Raíz 2,5 s (tiempo del mundo).
        marks = {lap: entry["mark_duration_s"] for lap, entry in self.data["laps"].items()}
        self.assertEqual(marks, {"1": 4.0, "2": 3.0, "3": 2.5})
        with open(os.path.join(ROOT, "data", "bosses", "boss_dummy.json"), encoding="utf-8") as handle:
            dummy = json.load(handle)
        self.assertEqual({lap: e["mark_duration_s"] for lap, e in dummy["laps"].items()}, marks)
        with open(os.path.join(ROOT, "data", "weak_point.json"), encoding="utf-8") as handle:
            weak = json.load(handle)
        self.assertEqual(weak["mark_duration_s"], 4.0)
        # Cabe al menos el pulso que marca (0,33 s) y dos laseres (~0,7 s cada uno).
        self.assertGreaterEqual(min(marks.values()), 0.33 + 2 * 0.7)



class AlertMajorFightDataTest(unittest.TestCase):
    """Pelea de Alerta Mayor (pasos 5-8, 2026-10-21): datos por acceso y arte provisional."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "bosses", "alert_major.json"), encoding="utf-8") as handle:
            self.data = json.load(handle)

    def test_laps_fight_settings(self):
        laps = self.data["laps"]
        self.assertEqual([laps[k]["charger_cooldown_s"] for k in ("1", "2", "3")], [4.0, 5.0, 6.0])
        self.assertEqual([laps[k]["phase2"]["popup_max"] for k in ("1", "2", "3")], [2, 3, 3])
        self.assertEqual([laps[k]["phase3"]["tempo_steps_s"] for k in ("1", "2", "3")],
                         [[2.0], [2.0, 1.6], [2.0, 1.6, 1.4]])
        self.assertEqual([laps[k]["phase3"]["copies"] for k in ("1", "2", "3")], [3, 3, 4])
        # Decision del usuario (2026-10-21): en Raíz, 3 lanzamientos por ronda en vez de 4.
        self.assertEqual([laps[k]["phase3"]["launches_per_round"] for k in ("1", "2", "3")], [3, 3, 3])

    def test_texts_are_marked_as_proposals(self):
        texts = self.data["texts"]
        lines = [texts["intro"]] + list(texts["phase_lines"].values()) + list(texts["popups"])
        for line in lines:
            self.assertIn("PROPUESTA", line)
            for banned in ("vuelta", "Easy", "Normal", "Hard"):
                self.assertNotIn(banned, line, "La UI nunca dice vuelta ni Easy/Normal/Hard")

    def test_alert_major_placeholder_art_is_up_to_date(self):
        done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_boss_alert_major.py"), "--check"],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


class BossTestRoomTest(unittest.TestCase):
    """Sala boss_test y objeto boss_dummy (paso 3)."""

    def setUp(self):
        with open(os.path.join(ROOT, "data", "levels", "boss_test.json"), encoding="utf-8") as handle:
            self.level = json.load(handle)

    def dummy(self, level):
        return next(o for o in level["objects"] if o["type"] == "boss_dummy")

    def test_room_is_valid_with_dummy_charger_and_terminal(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertEqual(self.level["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True})
        dummy = self.dummy(self.level)
        self.assertEqual((dummy["x"], dummy["y"], dummy["params"]["id"]), (9, 9, "saco"))
        charger = next(o for o in self.level["objects"] if o["type"] == "charger")
        self.assertEqual(charger["params"]["cooldown_s"], 4.0, "Cargador de arena: 4 s")
        self.assertEqual(self.level["debug_drain_scale"], 0.25,
                         "Debug a un cuarto de gasto, como la arena con la marca (§2.4.7)")

    def test_dummy_needs_floor_and_free_cells(self):
        level = copy.deepcopy(self.level)
        self.dummy(level)["y"] = 7
        errors = vls.validate_level(level)
        self.assertTrue(any("necesita suelo solido" in e for e in errors), errors)
        level = copy.deepcopy(self.level)
        row = list(level["grid"][8])
        row[10] = "#"
        level["grid"][8] = "".join(row)
        errors = vls.validate_level(level)
        self.assertTrue(any("dentro de terreno" in e for e in errors), errors)

    def test_placeholder_art_is_up_to_date(self):
        done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_boss_dummy_placeholder.py"),
                               "--check"], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        for state in ("up", "down"):
            self.assertTrue(os.path.exists(os.path.join(
                ROOT, "assets", "sprites", "bosses", "boss_dummy_%s_placeholder.png" % state)))


if __name__ == "__main__":
    unittest.main()
