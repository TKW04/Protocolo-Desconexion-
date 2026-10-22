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
import validate_level  # noqa: E402
import world2_model  # noqa: E402

SCROLL_TEST = os.path.join(ROOT, "data", "levels", "scroll_test.json")
BUCLE_TEST = os.path.join(ROOT, "data", "levels", "bucle_test.json")
TARJETAS_TEST = os.path.join(ROOT, "data", "levels", "tarjetas_test.json")


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



class CardsAndLoopTest(unittest.TestCase):
    """Tarjetas (paso 4) y bucles (paso 5) en el esquema y en el modelo del validador."""

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def test_rooms_are_valid(self):
        for path in (TARJETAS_TEST, BUCLE_TEST):
            self.assertEqual(vls.validate_level(load(path)), [], path)

    def test_fragile_warn_shorter_than_timer(self):
        level = load(TARJETAS_TEST)
        card = next(o for o in level["objects"] if o["params"].get("id") == "fragil_1")
        card["params"]["warn_s"] = 0.7
        self.assert_fails(level, "warn_s (0.7) debe ser menor que timer_s")

    def test_upright_card_needs_two_free_cells(self):
        level = load(TARJETAS_TEST)
        wall = next(o for o in level["objects"] if o["params"].get("id") == "fragil_de_pie")
        wall["y"] = 8
        self.assert_fails(level, "ocupa una celda que el grid debe dejar vacia")

    def test_story_too_short(self):
        level = load(TARJETAS_TEST)
        story = next(o for o in level["objects"] if o["type"] == "story_card")
        story["params"]["on_s"] = 0.6
        self.assert_fails(level, "on_s 0.60 s es menos que el aviso")

    def test_lowering_maps_cards_to_world1_pieces(self):
        level = load(TARJETAS_TEST)
        lowered = world2_model.lower(level, level_catalog.load_catalog(ROOT, 2))
        kinds = [o["type"] for o in lowered["objects"]]
        self.assertEqual(kinds.count("reminder_platform"), 2, "las dos fragiles que cuentan al pisarlas")
        self.assertEqual(kinds.count("blink_platform"), 2, "las dos Historias")
        self.assertEqual(kinds.count("rhythm_zone"), 2, "con su reloj propio")
        self.assertEqual(lowered["grid"][9][3], "#", "la oculta, terreno hasta el paso 9")
        self.assertIs(world2_model.lower(load(os.path.join(ROOT, "data", "levels", "1-1.json")),
                                         level_catalog.load_catalog(ROOT, 1)).__class__, dict)

    def test_world1_levels_are_not_lowered(self):
        level = load(os.path.join(ROOT, "data", "levels", "1-3.json"))
        self.assertIs(world2_model.lower(level, level_catalog.load_catalog(ROOT, 1)), level)

    def test_loop_must_repeat_below_the_band(self):
        level = load(BUCLE_TEST)
        row = level["grid"][50]
        level["grid"][50] = row[:12] + "#" + row[13:]
        self.assert_fails(level, "no repite la")

    def test_loop_band_too_short_and_needs_autoscroll(self):
        level = load(BUCLE_TEST)
        loop = next(o for o in level["objects"] if o["type"] == "loop_section")
        loop["params"]["band"] = [20, 30]
        self.assert_fails(level, "hacen falta al menos 13")
        level = load(BUCLE_TEST)
        level["camera"]["vertical"] = "tower"
        del level["scroll"]
        self.assert_fails(level, "solo vale con camera.vertical")

    def test_loop_exit_needs_the_debug(self):
        level = load(BUCLE_TEST)
        result = validate_level.validate(copy.deepcopy(level), ROOT)
        self.assertTrue(result["ok"], result["errors"])
        level["abilities_available"]["debug"] = False
        level["validation"] = {}
        result = validate_level.validate(level, ROOT)
        self.assertFalse(result["ok"], "sin el Debug no se sale del bucle")


if __name__ == "__main__":
    unittest.main()
