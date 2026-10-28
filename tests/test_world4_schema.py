"""Objetos del Mundo 4 en las herramientas de niveles (2026-10-28, paso 2 de
docs/propuesta-mundo-4.md §8): la sala data/levels/visto_test.json pasa el esquema y su escena
esta al dia; variantes rotas que el esquema rechaza (zona «Visto» con el doble check contra el
terreno, con medio ciclo, demasiado grande o dentro del terreno).
Uso: python3 -I tests/test_world4_schema.py
"""

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level_schema as vls  # noqa: E402
import build_level  # noqa: E402

VISTO_TEST = os.path.join(ROOT, "data", "levels", "visto_test.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def set_cell(level, x, y, ch):
    row = list(level["grid"][y])
    row[x] = ch
    level["grid"][y] = "".join(row)


def by_id(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


class World4SchemaBase(unittest.TestCase):
    def errors(self, level):
        return vls.validate_level(level, ROOT)

    def assert_error(self, level, text):
        errors = self.errors(level)
        self.assertTrue(any(text in e for e in errors), "se esperaba «%s» en %s" % (text, errors))


class SeenZoneSchemaTest(World4SchemaBase):
    def setUp(self):
        self.base = load(VISTO_TEST)

    def test_room_passes(self):
        self.assertEqual(self.errors(self.base), [])

    def test_scene_is_up_to_date(self):
        self.assertEqual(build_level.main(["build_level", "--check", VISTO_TEST]), 0)

    def test_shockwave_is_a_known_ability(self):
        self.assertIn("shockwave", vls.KNOWN_ABILITIES)
        self.assertTrue(self.base["abilities_available"]["shockwave"])

    def test_icon_must_face_free_cell(self):
        level = copy.deepcopy(self.base)
        set_cell(level, 8, 8, "#")
        self.assert_error(level, "doble check")

    def test_cycle_needs_both_values(self):
        level = copy.deepcopy(self.base)
        del by_id(level, "visto_aire")["params"]["off_s"]
        self.assert_error(level, "on_s y off_s van juntos")

    def test_size_limits(self):
        level = copy.deepcopy(self.base)
        by_id(level, "visto_suelo")["params"]["width_tiles"] = 5
        self.assertTrue(self.errors(level))

    def test_not_inside_terrain(self):
        level = copy.deepcopy(self.base)
        set_cell(level, 9, 9, "#")
        self.assert_error(level, "dentro de terreno")


if __name__ == "__main__":
    unittest.main()
