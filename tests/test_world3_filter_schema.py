"""Filtros del Mundo 3 en las herramientas de niveles (2026-10-26, paso 3 de
docs/propuesta-mundo-3.md §8, §3.2; decision 5 de §9: el filtro engana, no mata): la sala
data/levels/filtro_test.json pasa el esquema y su escena esta al dia; variantes rotas que el
esquema rechaza (cartel vacio, suelo falso sin fondo, caida de mas de 3 tiles, foso sin
salida, suelo falso fuera del filtro o en un filtro movil, umbral de una plataforma de likes
tapado, positions mal formadas) y lo que genera tools/build_level.py (pinchos ocultos fuera de
Tiles, con dano 10 y empuje a la entrada; Cover sin colision).
Uso: python3 -m unittest tests/test_world3_filter_schema.py
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

FILTRO_TEST = os.path.join(ROOT, "data", "levels", "filtro_test.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def set_cell(level, x, y, ch):
    row = list(level["grid"][y])
    row[x] = ch
    level["grid"][y] = "".join(row)


class FilterSchemaTest(unittest.TestCase):
    def setUp(self):
        self.base = load(FILTRO_TEST)

    def fixed(self, level):
        return next(o for o in level["objects"] if o["params"].get("id") == "filtro_orejitas")

    def moving(self, level):
        return next(o for o in level["objects"] if o["params"].get("id") == "filtro_movil")

    def errors(self, level):
        return vls.validate_level(level, ROOT)

    def assert_error(self, level, text):
        errors = self.errors(level)
        self.assertTrue(any(text in e for e in errors), "se esperaba «%s» en %s" % (text, errors))

    def test_room_passes(self):
        self.assertEqual(self.errors(self.base), [])

    def test_scene_is_up_to_date(self):
        self.assertEqual(build_level.main(["build_level", "--check", FILTRO_TEST]), 0)

    def test_label_is_required(self):
        level = copy.deepcopy(self.base)
        self.fixed(level)["params"]["label"] = "  "
        self.assert_error(level, "la zona siempre se ve como zona")
        del self.fixed(level)["params"]["label"]
        self.assert_error(level, "falta el param obligatorio 'label'")

    def test_too_small_zone_fails(self):
        level = copy.deepcopy(self.base)
        self.fixed(level)["params"]["height_tiles"] = 1
        self.assert_error(level, "height_tiles = 1 fuera de")

    def test_fake_floor_without_bottom_fails(self):
        level = copy.deepcopy(self.base)
        for y in range(10, 14):
            set_cell(level, 16, y, ".")
        self.assert_error(level, "no hay fondo")

    def test_drop_over_three_fails(self):
        level = copy.deepcopy(self.base)
        for x in (16, 17):
            for y in (12,):
                set_cell(level, x, y, ".")
        # Fondo a 3 filas (12 -> 13): caida 3, vale si tiene salida; a 4 no.
        level["grid"].append(level["grid"][-1])
        for x in (16, 17):
            set_cell(level, x, 13, ".")
        self.assert_error(level, "deja caer 4 tiles")

    def test_pit_without_exit_fails(self):
        level = copy.deepcopy(self.base)
        for x in (16, 17):
            set_cell(level, x, 12, ".")
        self.assert_error(level, "no tiene salida")
        # Abierto por un lado al nivel del fondo: vale.
        set_cell(level, 15, 12, ".")
        set_cell(level, 15, 11, ".")
        errors = self.errors(level)
        self.assertFalse(any("no tiene salida" in e for e in errors), errors)

    def test_fake_floor_outside_the_filter_fails(self):
        level = copy.deepcopy(self.base)
        self.fixed(level)["params"]["fake_floor"].append([23, 10, 1, 1])
        set_cell(level, 23, 10, ".")
        self.assert_error(level, "fake_floor fuera del filtro")

    def test_fake_floor_on_terrain_fails(self):
        level = copy.deepcopy(self.base)
        self.fixed(level)["params"]["fake_floor"].append([10, 10, 1, 1])
        self.assert_error(level, "el grid debe dejar el foso vacio")

    def test_fake_floor_only_on_fixed_filters(self):
        level = copy.deepcopy(self.base)
        self.moving(level)["params"]["fake_floor"] = [[29, 9, 1, 1]]
        self.assert_error(level, "solo va en filtros fijos")

    def test_filter_never_hides_a_like_threshold(self):
        level = copy.deepcopy(self.base)
        level["objects"].append({"type": "like_platform", "x": 9, "y": 3, "params": {"threshold": 5}})
        # Plataforma justo encima del filtro (fila 3): su cifra va en la fila 2, fuera; vale.
        self.assertEqual(self.errors(level), [])
        level["objects"][-1]["y"] = 5
        self.assert_error(level, "tapa el umbral de la plataforma de likes")

    def test_positions_rules(self):
        level = copy.deepcopy(self.base)
        self.moving(level)["params"]["positions"][0] = [28, 5]
        self.assert_error(level, "el primer sitio de positions")
        level = copy.deepcopy(self.base)
        self.moving(level)["params"]["positions"] = [[27, 5]]
        self.assert_error(level, "2 o 3 sitios")
        level = copy.deepcopy(self.base)
        del self.moving(level)["params"]["cycle_s"]
        self.assert_error(level, "necesita cycle_s")
        level = copy.deepcopy(self.base)
        self.fixed(level)["params"]["cycle_s"] = 4.0
        self.assert_error(level, "cycle_s solo vale con positions")
        level = copy.deepcopy(self.base)
        self.moving(level)["params"]["positions"][2] = [43, 5]
        self.assert_error(level, "se sale del grid")


class FilterBuildTest(unittest.TestCase):
    def test_hidden_spikes_and_cover(self):
        level = load(FILTRO_TEST)
        text = build_level.build_scene(level)
        catalog = build_level.level_catalog.load_catalog(ROOT, 3)
        hidden = build_level.filter_hidden_spikes(level, catalog)
        self.assertEqual(sorted(hidden), [(11, 9), (28, 9), (33, 9), (38, 9)])
        self.assertTrue(all(direction == -1.0 for (_, direction) in hidden.values()))
        block = text.split('[node name="Spikes_11_9"', 1)[1].split("[node", 1)[0]
        self.assertIn("damage = 10.0", block)
        self.assertIn("hidden_by_filter = true", block)
        self.assertIn("knockback_direction = -1.0", block)
        self.assertIn('[node name="Cover" type="TileMapLayer" parent="Objects/filtro_orejitas"]', text)
        self.assertIn('[node name="HiddenSpikes" type="TileMapLayer" parent="Objects/filtro_movil"]', text)
        cover = text.split('parent="Objects/filtro_orejitas"]', 1)[1].split("[node", 1)[0]
        self.assertIn("collision_enabled = false", cover)


if __name__ == "__main__":
    unittest.main()
