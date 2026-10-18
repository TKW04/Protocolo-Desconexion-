"""Catalogo de mejoras de Calc por pistas y su economia (tanda M1, docs/propuesta-mejoras.md §2-§3 y §7).

- Catalogo valido: cinco pistas (pulso, laser, debug, sync, energia) de 5 niveles, nivel 1 gratis,
  nombre, descripcion, coste y efecto en todos; 90 puntos por pista (Pulso 25/15/25/25, las demas
  15/20/30/25), 450 en total + 5 power banks (solo el nivel 5); tope por acceso Cache 3 / Kernel 4 /
  Raiz 5 (min_lap); desde la tanda M2 (2026-10-17) todos los niveles tienen efecto (implemented true).
- Textos sin las palabras de las vueltas (Vuelta, Easy, Normal, Hard).
- Presupuesto por vuelta (§3.3-§3.4): lo abierto en Cache y Kernel no es menor que lo ganable; con el
  ~93 % de los puntos de las tres vueltas se compra todo y con el 90 % no.
- Validador: --upgrades pista:nivel cambia el pulso y el laser como en el juego; wide_pulse = pulso:2.

Uso: python3 -m unittest tests/test_upgrade_economy.py
"""

import json
import math
import os
import re
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import upgrade_catalog as uc  # noqa: E402
import validate_level as vl  # noqa: E402

SCRIPT = os.path.join(ROOT, "tools", "validate_level.py")
LEVEL_1_1 = os.path.join(ROOT, "data", "levels", "1-1.json")
LEVEL_1_2 = os.path.join(ROOT, "data", "levels", "1-2.json")
TRACKS = ["pulso", "laser", "debug", "sync", "energia"]
COSTS = {
    "pulso": [25, 15, 25, 25],
    "laser": [15, 20, 30, 25],
    "debug": [15, 20, 30, 25],
    "sync": [15, 20, 30, 25],
    "energia": [15, 20, 30, 25],
}
# Niveles con efecto: todos desde la tanda M2 (2026-10-17); ninguno sale «Proximamente».
IMPLEMENTED = {
    "pulso": [2, 3, 4, 5],
    "laser": [2, 3, 4, 5],
    "debug": [2, 3, 4, 5],
    "sync": [2, 3, 4, 5],
    "energia": [2, 3, 4, 5],
}
FORBIDDEN = re.compile(r"\b(vuelta|vueltas|easy|normal|hard)\b", re.IGNORECASE)
LAPS = 3
MAPS_PER_LAP = 18


def points_per_map():
    with open(LEVEL_1_1, encoding="utf-8") as handle:
        return "".join(json.load(handle)["grid"]).count("o")


class CatalogTest(unittest.TestCase):
    def setUp(self):
        self.catalog = uc.load_catalog()

    def test_tracks_and_levels(self):
        self.assertEqual([t["id"] for t in uc.tracks(self.catalog)], TRACKS)
        for track in uc.tracks(self.catalog):
            levels = track["levels"]
            self.assertEqual([lv["level"] for lv in levels], [1, 2, 3, 4, 5], track["id"])
            self.assertEqual(levels[0]["cost"], {"attention_points": 0, "power_banks": 0}, "nivel 1 gratis")
            self.assertTrue(track["name"] and track["icon"])
            for lv in levels:
                self.assertTrue(lv["name"].strip(), (track["id"], lv["level"]))
                self.assertTrue(lv["description"].strip(), (track["id"], lv["level"]))
                if lv["level"] > 1:
                    self.assertTrue(lv["effects"], "cada nivel comprable tiene efecto")
                    for effect in lv["effects"]:
                        self.assertIn(".", effect["target"])
                        self.assertIsInstance(effect["value"], (int, float))

    def test_costs_90_per_track_and_450_total(self):
        for track in uc.tracks(self.catalog):
            costs = [lv["cost"]["attention_points"] for lv in track["levels"][1:]]
            self.assertEqual(costs, COSTS[track["id"]], track["id"])
            self.assertEqual(sum(costs), 90, track["id"])
            banks = [lv["cost"]["power_banks"] for lv in track["levels"]]
            self.assertEqual(banks, [0, 0, 0, 0, 1], "solo el nivel 5 pide un power bank")
        total = sum(lv["cost"]["attention_points"] for _, lv in uc.purchasable_levels(self.catalog))
        banks = sum(lv["cost"]["power_banks"] for _, lv in uc.purchasable_levels(self.catalog))
        self.assertEqual((total, banks), (450, 5))
        self.assertEqual(len(uc.purchasable_levels(self.catalog)), 20)

    def test_access_caps(self):
        for tid in TRACKS:
            self.assertEqual([uc.access_cap(self.catalog, tid, lap) for lap in (1, 2, 3)], [3, 4, 5], tid)

    def test_implemented_levels(self):
        for track in uc.tracks(self.catalog):
            got = [lv["level"] for lv in track["levels"][1:] if lv.get("implemented")]
            self.assertEqual(got, IMPLEMENTED[track["id"]], track["id"])

    def test_legacy_ids(self):
        self.assertEqual(uc.resolve(self.catalog, "wide_pulse"), ("pulso", 2))
        self.assertEqual(uc.resolve(self.catalog, "efficient_debug"), ("debug", 2))
        self.assertEqual(uc.resolve(self.catalog, "laser:3"), ("laser", 3))
        self.assertIsNone(uc.resolve(self.catalog, "laser:6"))
        self.assertIsNone(uc.resolve(self.catalog, "no_existe"))

    def test_effects_values(self):
        values = {
            ("pulso", "isak_abilities.pulse_radius_px", 96.0): [96, 112, 112],
            ("pulso", "game_state.pulse_stun_multiplier", 1.0): [1, 1, 1.5],
            ("laser", "isak_abilities.laser_cooldown_s", 0.4): [0.4, 0.3, 0.3, 0.3],
            ("laser", "isak_abilities.laser_energy_cost", 10.0): [10, 10, 8, 8],
            ("laser", "isak_abilities.laser_damage", 1.0): [1, 1, 1, 2],
            ("debug", "debug_mode.drain_per_second", 20.0): [20, 15, 15, 15, 15],
            ("debug", "debug_mode.reveal_linger_s", 0.0): [0, 0, 1.5, 1.5, 1.5],
            ("debug", "debug_mode.world_time_scale", 0.5): [0.5, 0.5, 0.5, 0.4, 0.4],
            ("debug", "debug_mode.activation_hold_s", 1.0): [1, 1, 1, 1, 0.4],
            ("sync", "game_state.sync_rate_max", 100.0): [100, 110, 120, 130, 130],
            ("energia", "game_state.debug_energy_max", 100.0): [100, 110, 120, 130, 130],
        }
        for (tid, target, base), expected in values.items():
            got = [uc.effective_value(self.catalog, {tid: lvl}, target, base) for lvl in range(1, len(expected) + 1)]
            self.assertEqual([round(v, 3) for v in got], [round(float(v), 3) for v in expected], (tid, target))
        # Un nivel sin implementar no se aplica aunque este comprado (catalogo copiado).
        import copy
        catalog = copy.deepcopy(self.catalog)
        for track in uc.tracks(catalog):
            if track["id"] == "debug":
                track["levels"][4]["implemented"] = False
        self.assertEqual(uc.effective_value(catalog, {"debug": 5}, "debug_mode.activation_hold_s", 1.0), 1.0)

    def test_texts_without_lap_words(self):
        texts = []
        for track in uc.tracks(self.catalog):
            texts.append(track["name"])
            for lv in track["levels"]:
                texts.extend((lv["name"], lv["description"]))
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            calc = json.load(handle)["calc"]
        texts.extend(v for k, v in calc["texts"].items() if not k.startswith("_") and isinstance(v, str))
        for text in texts:
            self.assertIsNone(FORBIDDEN.search(text), text)
        self.assertTrue(any("Kernel" in t for t in texts) or "%s" in calc["texts"]["state_access"])


class EconomyTest(unittest.TestCase):
    """docs/propuesta-mejoras.md §3.3 y §3.4 (presupuesto por vuelta y alcanzabilidad)."""

    def setUp(self):
        self.catalog = uc.load_catalog()
        self.per_lap = MAPS_PER_LAP * points_per_map()

    def opened_by_lap(self):
        out = []
        for lap in range(1, LAPS + 1):
            total = 0
            for tid in TRACKS:
                cap = uc.access_cap(self.catalog, tid, lap)
                total += sum(uc.level_entry(self.catalog, tid, lvl)["cost"]["attention_points"]
                             for lvl in range(2, cap + 1))
            out.append(total)
        return out

    def test_budget_per_lap(self):
        self.assertEqual(self.per_lap, 162)
        opened = self.opened_by_lap()
        earnable = [self.per_lap * lap for lap in range(1, LAPS + 1)]
        self.assertEqual(opened, [180, 325, 450])
        self.assertEqual(earnable, [162, 324, 486])
        for lap in (0, 1):
            self.assertGreaterEqual(opened[lap], earnable[lap],
                                    "en Cache y Kernel nunca sobran puntos sin nada que comprar")
        self.assertLessEqual(opened[2], earnable[2], "todo cabe en las tres vueltas")
        # La compra mas cara de los niveles 2-3 cabe de sobra al terminar Cache (~150 con el 93 %).
        dearest = max(uc.level_entry(self.catalog, tid, lvl)["cost"]["attention_points"]
                      for tid in TRACKS for lvl in (2, 3))
        self.assertEqual(dearest, 25)
        self.assertLess(dearest, math.floor(0.93 * self.per_lap))

    def test_reachable_with_93_percent(self):
        total = sum(lv["cost"]["attention_points"] for _, lv in uc.purchasable_levels(self.catalog))
        all_points = LAPS * self.per_lap
        self.assertGreaterEqual(math.floor(0.93 * all_points), total, "con el 93 % se compra todo")
        self.assertLess(math.floor(0.90 * all_points), total, "exigente: con el 90 % no llega")
        self.assertGreater(total / all_points, 0.9)
        # Con solo la ruta (6 de cada 9) se compran unas dos terceras partes.
        route = LAPS * MAPS_PER_LAP * 6
        self.assertLess(route, total)
        # Cumulado por vuelta con el 93 %: cada vuelta cubre lo abierto hasta entonces, salvo Cache, que
        # obliga a elegir (se abren 180 y se ganan ~150).
        cumulative = [math.floor(0.93 * self.per_lap * lap) for lap in range(1, LAPS + 1)]
        self.assertEqual(cumulative, [150, 301, 451])


class ValidatorUpgradesTest(unittest.TestCase):
    def test_rules_follow_track_levels(self):
        base = vl.Rules()
        rules = vl.Rules(upgrades=["pulso:2", "laser:3", "energia:4", "sync:2", "debug:2"])
        self.assertEqual((base.pulse_radius, base.laser_cost, base.energy_max), (96.0, 10.0, 100.0))
        self.assertEqual(rules.pulse_radius, 112.0)
        self.assertEqual(rules.laser_cost, 8.0)
        self.assertAlmostEqual(rules.laser_cooldown_s, 0.3)
        self.assertEqual((rules.energy_max, rules.sync_max, rules.debug_drain), (130.0, 110.0, 15.0))
        self.assertTrue(rules.has_upgrade("wide_pulse"))
        self.assertTrue(rules.has_upgrade("pulso:2"))
        self.assertFalse(rules.has_upgrade("pulso:3"))
        self.assertEqual(vl.Rules(upgrades=["wide_pulse"]).pulse_radius, 112.0)
        with self.assertRaises(ValueError):
            vl.Rules(upgrades=["pulso:6"])

    def test_cli_track_level(self):
        alias = subprocess.run([sys.executable, SCRIPT, "--upgrades", "wide_pulse", LEVEL_1_1],
                               capture_output=True, text=True)
        track = subprocess.run([sys.executable, SCRIPT, "--upgrades", "pulso:2", LEVEL_1_1],
                               capture_output=True, text=True)
        self.assertEqual((alias.returncode, track.returncode), (0, 0), track.stdout + track.stderr)
        self.assertEqual(alias.stdout.replace("wide_pulse", "pulso:2"), track.stdout,
                         "wide_pulse es un alias de pulso:2")
        laser = subprocess.run([sys.executable, SCRIPT, "--upgrades", "laser:3,energia:2", LEVEL_1_2],
                               capture_output=True, text=True)
        self.assertEqual(laser.returncode, 0, laser.stdout + laser.stderr)
        self.assertIn("coste del laser 8 (base 10)", laser.stdout)
        self.assertIn("energia maxima 110 (base 100)", laser.stdout)
        bad = subprocess.run([sys.executable, SCRIPT, "--upgrades", "laser:9", LEVEL_1_1],
                             capture_output=True, text=True)
        self.assertEqual(bad.returncode, 2)
        self.assertIn("mejora desconocida", bad.stdout + bad.stderr)

    def test_m2_rules_debug_world_scale_and_hold(self):
        """Tanda M2: Debug 4 (mundo x0,4) y Debug 5 (carga 0,4 s) en el modelo; el laser que perfora y la
        regeneracion pasiva no cambian ningun objetivo ni el presupuesto de energia."""
        base = vl.Rules()
        full = vl.Rules(upgrades=["pulso:5", "laser:5", "debug:5", "sync:5", "energia:5"])
        self.assertEqual((base.debug_world_scale, base.debug_hold_s), (0.5, 1.0))
        self.assertEqual((full.debug_world_scale, full.debug_hold_s), (0.4, 0.4))
        self.assertEqual(vl.Rules(upgrades=["debug:3"]).debug_world_scale, 0.5)
        self.assertNotIn("debug_world_time_scale", base.changed_by_upgrades())
        self.assertIn("debug_world_time_scale", full.changed_by_upgrades())

    def test_access_cap_pass(self):
        """--access-cap: cada pista en el tope del acceso del nivel (lap del JSON, Cache = nivel 3)."""
        with open(LEVEL_1_2, encoding="utf-8") as handle:
            level = json.load(handle)
        self.assertEqual(vl.access_cap_upgrades(level),
                         ["pulso:3", "laser:3", "debug:3", "sync:3", "energia:3"])
        self.assertEqual(vl.access_cap_upgrades(level, 3)[0], "pulso:5")
        out = subprocess.run([sys.executable, SCRIPT, "--access-cap", LEVEL_1_2], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn("mejoras: pulso:3, laser:3, debug:3, sync:3, energia:3", out.stdout)

    def test_full_upgrades_keep_levels_valid(self):
        """Con todas las pistas al maximo el 1-1 y el 1-2 siguen validos (las mejoras solo facilitan)."""
        for path in (LEVEL_1_1, LEVEL_1_2):
            out = subprocess.run([sys.executable, SCRIPT, "--upgrades", "pulso:5,laser:5,debug:5,sync:5,energia:5",
                                  path], capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
            self.assertIn("mundo con el Debug (x) 0.4 (base 0.5)", out.stdout)

    def test_secret_requires_track_level(self):
        """requires_upgrade admite "pista:nivel": el secreto del power bank del 1-1 con pulso:2."""
        with open(LEVEL_1_1, encoding="utf-8") as handle:
            level = json.load(handle)
        secret = next(s for s in level["secrets"] if s.get("requires_upgrade"))
        secret["requires_upgrade"] = "pulso:2"
        result = vl.validate(level)
        self.assertTrue(result["ok"], result["errors"])
        item = next(i for i in result["secrets"]["items"] if i["id"] == secret["id"])
        self.assertEqual((item["reachable_without_upgrade"], item["reachable_with_upgrade"]), (False, True))


if __name__ == "__main__":
    unittest.main()
