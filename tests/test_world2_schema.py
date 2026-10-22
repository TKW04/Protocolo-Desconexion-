"""Pruebas del Mundo 2 en las herramientas de niveles (2026-10-22, docs/propuesta-mundo-2.md §8):
catalogo unido con los tipos del Mundo 1 (tools/level_catalog.py), tileset y fondo provisionales,
seccion scroll del esquema (paso 2) con la sala data/levels/scroll_test.json y variantes rotas,
y la paleta provisional al dia (paso 0).
Uso: python3 -m unittest tests/test_world2_schema.py
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
import level_catalog  # noqa: E402
import build_level  # noqa: E402

SCROLL_TEST = os.path.join(ROOT, "data", "levels", "scroll_test.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


class CatalogTest(unittest.TestCase):
    def test_world2_catalog_has_world1_types_underneath(self):
        world1 = level_catalog.load_catalog(ROOT, 1)
        world2 = level_catalog.load_catalog(ROOT, 2)
        for kind in world1["types"]:
            self.assertIn(kind, world2["types"], "el Mundo 2 conserva %s" % kind)
        self.assertIn("palette", world2)
        self.assertEqual(world2["palette"]["magenta"], load(os.path.join(ROOT, "data", "world2_objects.json"))[
            "palette"]["magenta"])

    def test_world1_catalog_is_unchanged(self):
        self.assertEqual(level_catalog.load_catalog(ROOT, 1), load(os.path.join(ROOT, "data", "world1_objects.json")))

    def test_world2_falls_back_to_world1_art(self):
        if not os.path.exists(os.path.join(ROOT, "data", "tileset_mundo2.json")):
            self.assertTrue(level_catalog.tileset_json(ROOT, 2).endswith("tileset_mundo1.json"))
        if not os.path.exists(os.path.join(ROOT, "scenes", "levels", "world2_background.tscn")):
            self.assertEqual(level_catalog.background_res(ROOT, 2), "res://scenes/levels/world1_background.tscn")

    def test_palette_is_up_to_date(self):
        result = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "palette_mundo2_provisional.py"),
                                 "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


class ScrollSchemaTest(unittest.TestCase):
    def setUp(self):
        self.level = load(SCROLL_TEST)

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_scroll_test_is_valid(self):
        self.assertEqual(vls.validate_level(self.level), [])

    def test_scene_passes_the_scroll_section_to_isak(self):
        text = build_level.build_scene(self.level)
        self.assertIn('camera_mode = &"autoscroll"', text)
        self.assertIn("scroll_config = {", text)
        self.assertIn("world1_background.tscn", text, "fondo provisional del Mundo 1")

    def test_scroll_needs_autoscroll(self):
        level = copy.deepcopy(self.level)
        level["camera"]["vertical"] = "tower"
        self.assert_fails(level, "'scroll' solo vale con camera.vertical")

    def test_autoscroll_needs_scroll(self):
        level = copy.deepcopy(self.level)
        del level["scroll"]
        self.assert_fails(level, "exige la seccion 'scroll'")

    def test_width_is_twenty(self):
        level = copy.deepcopy(self.level)
        level["grid"] = [row + row[-1] for row in level["grid"]]
        self.assert_fails(level, "mide 20 tiles de ancho")

    def test_speed_range(self):
        level = copy.deepcopy(self.level)
        level["scroll"]["stages"][0]["speed_tiles_s"] = 3.0
        self.assert_fails(level, "speed_tiles_s debe estar entre")

    def test_overlapping_stages(self):
        level = copy.deepcopy(self.level)
        level["scroll"]["stages"][1]["y_to"] = 40
        self.assert_fails(level, "se solapa")

    def test_stop_resume_out_of_view(self):
        level = copy.deepcopy(self.level)
        level["scroll"]["stops"][0]["resume_row"] = 5
        self.assert_fails(level, "resume_row debe quedar a la vista")

    def test_safe_cards_need_floor_and_spacing(self):
        level = copy.deepcopy(self.level)
        level["scroll"]["safe_respawn"].append([17, 12])
        self.assert_fails(level, "con suelo")
        level = copy.deepcopy(self.level)
        level["scroll"]["safe_respawn"] = [c for c in level["scroll"]["safe_respawn"] if not 36 <= c[1] <= 46]
        self.assert_fails(level, "no hay tarjeta segura")

    def test_unknown_scroll_field(self):
        level = copy.deepcopy(self.level)
        level["scroll"]["loops"] = []
        self.assert_fails(level, "campo desconocido 'loops'")


if __name__ == "__main__":
    unittest.main()
