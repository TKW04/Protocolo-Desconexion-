"""Pruebas de conjunto del Mundo 4 «El Chat» (paso 21 de docs/propuesta-mundo-4.md §8 y §7.4, 2026-10-28).

Negativos de diseño sobre los datos y el modelo del validador (la fisica real la prueban tests/test_world4_negatives.gd,
tests/test_seen_wave.gd y tests/test_frozen.gd):

- **Los Mundos 1-3 no cambian**: el modelo del Mundo 4 (tools/world4_model.py) devuelve sin tocar TODOS los niveles,
  arenas y salas de prueba de los Mundos 1-3 y la pagina 2 del hub (la salida del validador, identica: comparacion del
  paso 21 en §8.1 con las herramientas anteriores al Mundo 4, en Cache, Kernel y Raiz).
- **La ola no mata sola**: el golpe de la ola quita menos que el Sync Rate maximo (y el codigo nunca baja de 1); cada
  punto de sincronizacion de un nivel con ola queda dentro de una parada (la ola espera antes de el hasta que Isak lo
  deja atras), asi que reaparecer nunca deja a Isak con la ola encima.
- **Congelarse no mata**: ni la zona «Visto» ni el congelado tienen dano propio en los datos.
Uso: python3 tests/test_world4_negatives.py
"""

import glob
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import world4_model  # noqa: E402

SYNC_RATE_MAX = 100.0


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def levels_of(worlds):
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "levels", "*.json"))):
        level = load(path)
        if int(level.get("world", 1)) in worlds:
            out.append((os.path.basename(path), level))
    return out


class Worlds1To3UnchangedTest(unittest.TestCase):
    def test_world4_model_leaves_every_earlier_level_untouched(self):
        found = levels_of((1, 2, 3))
        self.assertGreaterEqual(len(found), 30, "Niveles, arenas y salas de los Mundos 1-3")
        hub = load(os.path.join(ROOT, "data", "hub_update.json"))
        for name, level in found + [("hub_update.json", hub)]:
            catalog = level_catalog.load_catalog(ROOT, int(level.get("world", 1)))
            self.assertIs(world4_model.lower(level, catalog), level, name)


class WaveNeverKillsTest(unittest.TestCase):
    def setUp(self):
        self.objects = load(os.path.join(ROOT, "data", "world4_objects.json"))

    def test_one_hit_never_empties_the_sync_rate(self):
        cfg = self.objects["seen_wave"]
        self.assertLess(float(cfg.get("edge_damage", 10.0)), SYNC_RATE_MAX)
        self.assertGreater(float(cfg.get("freeze_s", 2.0)), 0.0)

    def test_every_sync_point_waits_inside_a_stop(self):
        with_wave = 0
        for name, level in levels_of((4,)):
            waves = [o for o in level["objects"] if o["type"] == "seen_wave"]
            if not waves:
                continue
            with_wave += 1
            stops = waves[0]["params"].get("stops", [])
            for cp in level.get("checkpoints", []):
                inside = [s for s in stops if int(s["at_col"]) < int(cp["x"]) < int(s["resume_col"])]
                self.assertTrue(inside, "%s: %s sin parada de la ola que lo cubra" % (name, cp["id"]))
        self.assertGreaterEqual(with_wave, 2, "El 4-3 y ola_test tienen ola")


class FreezingNeverKillsTest(unittest.TestCase):
    def test_no_damage_in_the_seen_zone_nor_in_the_frozen_state(self):
        objects = load(os.path.join(ROOT, "data", "world4_objects.json"))
        abilities = load(os.path.join(ROOT, "data", "isak_abilities.json"))
        for section in (objects["seen_zone"], abilities.get("frozen", {})):
            self.assertFalse([k for k in section if "damage" in k and not k.startswith("_")], section)
        self.assertTrue(abilities.get("frozen"), "Seccion frozen de data/isak_abilities.json")


if __name__ == "__main__":
    unittest.main()
