#!/usr/bin/env python3
"""Datos de los jefes (data/bosses/*.json; paso 2 de docs/propuesta-jefe-alerta-mayor.md §6).

Alerta Mayor: 9 golpes en la vuelta 1 (Caché, 3/3/3) y 12 en las vueltas 2 y 3 (Kernel y Raíz,
4/4/4); el contador baja de 99 a 0 y marca 66 y 33 al cambiar de fase (la misma cuenta que
BossBase.counter_for); recargas de cambio de fase +25/+25 y reaparicion con energia >= 50.
"""

import json
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


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


if __name__ == "__main__":
    unittest.main()
