"""Objetos del Mundo 4 en las herramientas de niveles (2026-10-28, pasos 2-3 de
docs/propuesta-mundo-4.md §8): las salas data/levels/visto_test.json y burbujas_test.json pasan
el esquema y sus escenas estan al dia; variantes rotas que el esquema rechaza (zona «Visto» con
el doble check contra el terreno o con medio ciclo; burbuja con un width_tiles que no cuadra con
el texto, texto vacio o con glifos fuera de la fuente, «escribiendo…» sin disparo, con un
disparo que no es una burbuja o con un ciclo demasiado corto, autocorrector que deja un pozo o
pinchos al descubierto; desde el paso 4, sala oscuro_test: escrito en tinta fuera de una
dark_zone, sin texto o sobre terreno, y dos Linternas en un nivel; desde el paso 5, sala
grupo_test: Troll con un ciclo sin reposo, Troll disfrazado sin texto, con un amigo desconocido o
sin suelo debajo, y params que no existen; desde el paso 6, sala fantasmas_test y params del
Fantasma fuera de rango) y lo que genera
tools/build_level.py (largo por el texto: 1 tile por cada 6 caracteres, entre 1 y 8).
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
BURBUJAS_TEST = os.path.join(ROOT, "data", "levels", "burbujas_test.json")
OSCURO_TEST = os.path.join(ROOT, "data", "levels", "oscuro_test.json")
GRUPO_TEST = os.path.join(ROOT, "data", "levels", "grupo_test.json")
FANTASMAS_TEST = os.path.join(ROOT, "data", "levels", "fantasmas_test.json")


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


class BubbleSchemaTest(World4SchemaBase):
    def setUp(self):
        self.base = load(BURBUJAS_TEST)

    def test_room_passes(self):
        self.assertEqual(self.errors(self.base), [])

    def test_scene_is_up_to_date(self):
        self.assertEqual(build_level.main(["build_level", "--check", BURBUJAS_TEST]), 0)

    def test_width_rule(self):
        self.assertEqual(build_level.bubble_width(""), 1)
        self.assertEqual(build_level.bubble_width("hola"), 1)
        self.assertEqual(build_level.bubble_width("123456"), 1)
        self.assertEqual(build_level.bubble_width("1234567"), 2)
        self.assertEqual(build_level.bubble_width("¿Sigues despierto?"), 3)
        self.assertEqual(build_level.bubble_width("x" * 100), 8, "maximo 8")
        self.assertEqual(vls._bubble_width("x" * 100), 8)

    def test_width_written_from_text(self):
        with open(os.path.join(ROOT, "scenes", "levels", "burbujas_test.tscn"), encoding="utf-8") as handle:
            text = handle.read()
        self.assertIn("corrected_width_tiles = 2", text, "«te echo»: 7 caracteres = 2 tiles")
        self.assertIn('trigger_id = &"burbuja_fija"', text)

    def test_width_that_does_not_match_is_rejected(self):
        level = copy.deepcopy(self.base)
        by_id(level, "burbuja_fija")["params"]["width_tiles"] = 2
        self.assert_error(level, "no cuadra con el texto")
        level = copy.deepcopy(self.base)
        by_id(level, "burbuja_fija")["params"]["width_tiles"] = 3
        self.assertEqual(self.errors(level), [], "el que cuadra vale")

    def test_text_required_and_glyphs(self):
        level = copy.deepcopy(self.base)
        by_id(level, "burbuja_fija")["params"]["text"] = "  "
        self.assert_error(level, "texto no vacio")
        level = copy.deepcopy(self.base)
        by_id(level, "burbuja_fija")["params"]["text"] = "hola ☃"
        self.assert_error(level, "glifos")

    def test_cells_must_be_empty(self):
        level = copy.deepcopy(self.base)
        set_cell(level, 7, 7, "#")
        self.assert_error(level, "vacia")

    def test_typing_needs_a_trigger(self):
        level = copy.deepcopy(self.base)
        del by_id(level, "escribiendo_1")["params"]["trigger"]
        self.assert_error(level, "necesita trigger")
        level = copy.deepcopy(self.base)
        by_id(level, "escribiendo_1")["params"]["trigger"] = "terminal_burbujas"
        self.assert_error(level, "no es el id de otra burbuja")
        level = copy.deepcopy(self.base)
        by_id(level, "escribiendo_1")["params"]["trigger"] = "escribiendo_1"
        self.assert_error(level, "no es el id de otra burbuja")

    def test_trigger_zone_shape(self):
        level = copy.deepcopy(self.base)
        by_id(level, "escribiendo_ciclo")["params"]["trigger_zone"] = [22, 6, 0, 4]
        self.assert_error(level, "trigger_zone")
        level = copy.deepcopy(self.base)
        by_id(level, "escribiendo_ciclo")["params"]["trigger_zone"] = [38, 6, 4, 4]
        self.assert_error(level, "se sale del grid")

    def test_typing_cycle_rules(self):
        level = copy.deepcopy(self.base)
        del by_id(level, "escribiendo_ciclo")["params"]["on_s"]
        self.assert_error(level, "cycle_s y on_s van juntos")
        level = copy.deepcopy(self.base)
        by_id(level, "escribiendo_ciclo")["params"]["cycle_s"] = 3.5
        self.assert_error(level, "cycle_s 3.50")

    def test_autocorrect_does_not_kill(self):
        level = copy.deepcopy(self.base)
        for r in (10, 11):
            set_cell(level, 30, r, ".")
        self.assert_error(level, "engana, no mata")
        level = copy.deepcopy(self.base)
        set_cell(level, 30, 9, "^")
        self.assert_error(level, "engana, no mata")

    def test_autocorrect_anchor_right_uncovers_left_column(self):
        level = copy.deepcopy(self.base)
        params = by_id(level, "autocorrector_1")["params"]
        params["anchor"] = "right"
        for r in (10, 11):
            set_cell(level, 28, r, ".")
        self.assert_error(level, "columna 28")

    def test_friend_and_side_values(self):
        level = copy.deepcopy(self.base)
        by_id(level, "burbuja_lia")["params"]["friend"] = "mama"
        self.assertTrue(self.errors(level))
        level = copy.deepcopy(self.base)
        by_id(level, "burbuja_lia")["params"]["side"] = "up"
        self.assertTrue(self.errors(level))


class DarkSchemaTest(World4SchemaBase):
    def setUp(self):
        self.base = load(OSCURO_TEST)

    def test_room_passes(self):
        self.assertEqual(self.errors(self.base), [])

    def test_scene_is_up_to_date(self):
        self.assertEqual(build_level.main(["build_level", "--check", OSCURO_TEST]), 0)

    def test_ink_must_be_inside_a_dark_zone(self):
        level = copy.deepcopy(self.base)
        by_id(level, "tinta_texto")["x"] = 33
        self.assert_error(level, "dentro de una dark_zone")

    def test_ink_decor_needs_text(self):
        level = copy.deepcopy(self.base)
        del by_id(level, "tinta_texto")["params"]["text"]
        self.assert_error(level, "necesita un text")

    def test_ink_step_needs_empty_cell(self):
        level = copy.deepcopy(self.base)
        set_cell(level, 27, 7, "#")
        self.assert_error(level, "(step) ocupa una celda")

    def test_one_flashlight_per_level(self):
        level = copy.deepcopy(self.base)
        extra = copy.deepcopy(by_id(level, "linterna_prueba"))
        extra["x"] = 7
        extra["params"]["id"] = "linterna_2"
        level["objects"].append(extra)
        self.assert_error(level, "una sola Linterna")

    def test_flashlight_not_in_terrain(self):
        level = copy.deepcopy(self.base)
        set_cell(level, 5, 9, "#")
        self.assert_error(level, "dentro de terreno")



def enemy(level, eid):
    return next(e for e in level["enemies"] if e["id"] == eid)


class GroupSchemaTest(World4SchemaBase):
    def setUp(self):
        self.base = load(GRUPO_TEST)

    def test_room_passes(self):
        self.assertEqual(self.errors(self.base), [])

    def test_scene_is_up_to_date(self):
        self.assertEqual(build_level.main(["build_level", "--check", GRUPO_TEST]), 0)

    def test_troll_cycle_needs_rest(self):
        level = copy.deepcopy(self.base)
        enemy(level, "troll_suelo")["params"]["interval_s"] = 0.5
        self.assert_error(level, "fuera de [1.5, 6.0]")

    def test_mimic_needs_text_and_known_friend(self):
        level = copy.deepcopy(self.base)
        enemy(level, "troll_lia")["params"]["text"] = " "
        self.assert_error(level, "'text' debe ser un texto no vacio")
        level = copy.deepcopy(self.base)
        enemy(level, "troll_lia")["params"]["friend"] = "mama"
        self.assert_error(level, "friend debe ser lia, marco o tomi")

    def test_mimic_needs_ground_below(self):
        level = copy.deepcopy(self.base)
        set_cell(level, 22, 10, ".")
        self.assert_error(level, "necesita suelo solido")

    def test_unknown_param_is_rejected(self):
        level = copy.deepcopy(self.base)
        enemy(level, "sticker_1")["params"] = {"blast_tiles": 3}
        self.assert_error(level, "params.blast_tiles no existe para sticker")



class GhostSchemaTest(World4SchemaBase):
    def setUp(self):
        self.base = load(FANTASMAS_TEST)

    def test_room_passes(self):
        self.assertEqual(self.errors(self.base), [])

    def test_scene_is_up_to_date(self):
        self.assertEqual(build_level.main(["build_level", "--check", FANTASMAS_TEST]), 0)

    def test_ghost_params_have_ranges(self):
        level = copy.deepcopy(self.base)
        enemy(level, "fantasma_pasillo")["params"]["detect_tiles"] = 9
        self.assert_error(level, "params.detect_tiles = 9 fuera de [2, 5]")
        level = copy.deepcopy(self.base)
        enemy(level, "fantasma_pasillo")["params"]["start_direction"] = 0
        self.assert_error(level, "params.start_direction debe ser uno de [-1, 1]")


if __name__ == "__main__":
    unittest.main()
