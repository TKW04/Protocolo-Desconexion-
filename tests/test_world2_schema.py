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
AUTOPLAY_TEST = os.path.join(ROOT, "data", "levels", "autoplay_test.json")
CLONES_TEST = os.path.join(ROOT, "data", "levels", "clones_test.json")
CARGA_TEST = os.path.join(ROOT, "data", "levels", "carga_test.json")
REPRODUCTOR_TEST = os.path.join(ROOT, "data", "levels", "reproductor_test.json")


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
        pound = [o for o in lowered["objects"] if o["type"] == "_pound_card"]
        self.assertEqual(sorted(o["params"]["id"] for o in pound), ["fragil_de_pie", "fragil_oculta"],
                         "las que solo rompe el golpe: puertas del golpe al suelo (paso 9)")
        self.assertTrue(next(o for o in pound if o["params"]["id"] == "fragil_oculta")["params"]["hidden"])
        self.assertEqual(next(o for o in pound if o["params"]["id"] == "fragil_de_pie")["params"]["rows"], 2)
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



class AutoplayVideoSchemaTest(unittest.TestCase):
    """Video en autoplay (paso 6): clip valido, tarjeta y ola sin celdas solidas y clip con reposo."""

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def video(self, level, vid):
        return next(e for e in level["enemies"] if e["id"] == vid)

    def set_cell(self, level, x, y, char):
        row = level["grid"][y]
        level["grid"][y] = row[:x] + char + row[x + 1:]

    def test_room_is_valid(self):
        self.assertEqual(vls.validate_level(load(AUTOPLAY_TEST)), [])

    def test_unknown_clip(self):
        level = load(AUTOPLAY_TEST)
        self.video(level, "video_ola")["params"]["clip"] = "loop"
        self.assert_fails(level, "clip debe ser wave, ray o count")

    def test_card_cells_must_be_free(self):
        level = load(AUTOPLAY_TEST)
        self.set_cell(level, 29, 4, "#")
        self.assert_fails(level, "celda solida dentro de la tarjeta")

    def test_wave_corridor_must_be_free(self):
        level = load(AUTOPLAY_TEST)
        self.set_cell(level, 8, 9, "#")
        self.assert_fails(level, "celda solida dentro de la ola")

    def test_clip_needs_rest(self):
        level = load(AUTOPLAY_TEST)
        params = self.video(level, "video_ola")["params"]
        params["wave_tiles"] = 14
        params["clip_s"] = 2.0
        self.assert_fails(level, "clip_s 2.00 menor que aviso + ataque + reposo minimo")

    def test_params_out_of_range(self):
        level = load(AUTOPLAY_TEST)
        self.video(level, "video_cuenta")["params"]["clip_s"] = 4.0
        self.assert_fails(level, "params.clip_s = 4.0 fuera de [2.0, 3.0]")


class FeedEnemiesSchemaTest(unittest.TestCase):
    """Paso 7: zona de clones con zone valida y suelo en sus bordes, Comentarista con la columna del bocadillo
    libre y ciclo con reposo, y muro «Cargando mas...» sobre el suelo (puerta del golpe en el validador)."""

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def obj(self, level, oid):
        return next(o for o in level["objects"] if o.get("params", {}).get("id") == oid)

    def set_cell(self, level, x, y, char):
        row = level["grid"][y]
        level["grid"][y] = row[:x] + char + row[x + 1:]

    def test_rooms_are_valid(self):
        self.assertEqual(vls.validate_level(load(CLONES_TEST)), [])
        self.assertEqual(vls.validate_level(load(CARGA_TEST)), [])

    def test_zone_must_be_a_rect_inside_the_grid(self):
        level = load(CLONES_TEST)
        self.obj(level, "zona_clones")["params"]["zone"] = [6, 5, 1, 5]
        self.assert_fails(level, "zone debe ser [columna, fila, ancho, alto]")
        level = load(CLONES_TEST)
        self.obj(level, "zona_clones")["params"]["zone"] = [30, 5, 10, 5]
        self.assert_fails(level, "se sale del grid")

    def test_zone_edges_need_floor(self):
        level = load(CLONES_TEST)
        self.obj(level, "zona_clones")["params"]["zone"] = [6, 3, 14, 5]
        self.assert_fails(level, "falta suelo '#' bajo")

    def test_zone_param_ranges(self):
        level = load(CLONES_TEST)
        self.obj(level, "zona_clones")["params"]["max_clones"] = 9
        self.assert_fails(level, "max_clones")

    def test_commenter_needs_a_free_column(self):
        level = load(CLONES_TEST)
        self.set_cell(level, 33, 9, "#")
        self.assert_fails(level, "columna del bocadillo")

    def test_commenter_interval_needs_rest(self):
        level = load(CLONES_TEST)
        level["enemies"][0]["params"]["interval_s"] = 0.9
        self.assert_fails(level, "params.interval_s = 0.9 fuera de")

    def test_wall_cells_must_be_free_and_on_the_floor(self):
        level = load(CARGA_TEST)
        self.set_cell(level, 14, 8, "#")
        errors = vls.validate_level(level)
        self.assertTrue(errors, "celda del muro ocupada")
        level = load(CARGA_TEST)
        self.obj(level, "muro_carga")["params"]["height_tiles"] = 2
        self.assert_fails(level, "el muro va sobre el suelo")

    def test_validator_opens_the_wall_with_a_ground_pound(self):
        level = world2_model.lower(load(CARGA_TEST), level_catalog.load_catalog(ROOT, 2))
        cards = [o for o in level["objects"] if o["type"] == "_pound_card"]
        self.assertEqual(len(cards), 1)
        self.assertEqual(cards[0]["params"]["rows"], 3)


class PausePlayerSchemaTest(unittest.TestCase):
    """Paso 8: el reproductor con el boton de pausa (pause_player) solo da el golpe al suelo, con la linea de
    Eco del Mundo 2, fuera del terreno; la sala reproductor_test es valida y el validador la acepta (desde el paso
    9b el reproductor da el golpe al suelo en el grafo: tests/test_world2_feed_validator.py)."""

    def assert_fails(self, level, fragment):
        errors = vls.validate_level(level)
        self.assertTrue(any(fragment in e for e in errors), "ningun error contiene '%s': %s" % (fragment, errors))

    def player(self, level):
        return next(o for o in level["objects"] if o["type"] == "pause_player")

    def test_room_is_valid(self):
        self.assertEqual(vls.validate_level(load(REPRODUCTOR_TEST)), [])

    def test_only_gives_the_ground_pound(self):
        level = load(REPRODUCTOR_TEST)
        self.player(level)["params"]["ability"] = "dash"
        self.assert_fails(level, "ability 'dash' no admitido")
        level = load(REPRODUCTOR_TEST)
        del self.player(level)["params"]["ability"]
        self.assert_fails(level, "falta el param obligatorio 'ability'")
        level = load(REPRODUCTOR_TEST)
        self.player(level)["params"]["story_line"] = "dnd_1_3"
        self.assert_fails(level, "story_line 'dnd_1_3' no admitido")

    def test_not_inside_terrain(self):
        level = load(REPRODUCTOR_TEST)
        obj = self.player(level)
        row = level["grid"][obj["y"]]
        level["grid"][obj["y"]] = row[:obj["x"]] + "#" + row[obj["x"] + 1:]
        self.assert_fails(level, "fila %d, columna %d: objects" % (obj["y"], obj["x"]))

    def test_scene_instances_the_player_with_its_ability(self):
        text = build_level.build_scene(load(REPRODUCTOR_TEST))
        self.assertIn("pause_player.tscn", text)
        self.assertIn('ability = &"ground_pound"', text)
        self.assertIn('metadata/help_id = "pause_player"', text)

    def test_validator_accepts_the_room(self):
        result = validate_level.validate(load(REPRODUCTOR_TEST), ROOT)
        self.assertTrue(result["ok"], [e["message"] for e in result["errors"]])


class ScrollValidatorTest(unittest.TestCase):
    """Paso 9 (parte del scroll, el golpe y los bucles): el scroll como amenaza que se mueve, el techo de carga
    (esperas wait_scroll), el golpe al suelo como puerta y los casos negativos."""

    def run_level(self, level, export=None):
        return validate_level.validate(level, ROOT, export=export)

    def messages(self, result):
        return [e["message"] for e in result["errors"]]

    def test_scroll_room_exports_waits(self):
        export = []
        result = self.run_level(load(SCROLL_TEST), export)
        self.assertTrue(result["ok"], self.messages(result))
        scroll = result["plan"]["scroll"]
        self.assertGreaterEqual(scroll["margin_min_tiles"], 3.0)
        self.assertGreater(scroll["waits"], 0, "el camino espera al scroll (techo de carga)")
        actions = [st["action"] for st in export[0]["steps"]]
        self.assertIn("wait_scroll", actions)

    def test_scroll_too_fast_fails(self):
        # Mas rapido de lo que el esquema admite (1,5 tiles/s), para ver que el plan lo detecta.
        level = load(SCROLL_TEST)
        level["scroll"]["stages"] = [{"y_from": 0, "y_to": 58, "speed_tiles_s": 4.0}]
        level["scroll"]["default_speed_tiles_s"] = 4.0
        result = validate_level.validate(level, ROOT, check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("borde del scroll" in m for m in self.messages(result)), self.messages(result))

    def test_required_margin(self):
        level = load(SCROLL_TEST)
        level["validation"] = {"scroll_margin_tiles": 6.0}
        result = self.run_level(level)
        self.assertTrue(any("tiles del borde del scroll (minimo 6" in m for m in self.messages(result)),
                        self.messages(result))

    def test_loop_must_be_solved_before_the_band_top(self):
        level = load(BUCLE_TEST)
        level["scroll"]["default_speed_tiles_s"] = 1.5
        result = self.run_level(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("bucle" in m or "borde del scroll" in m for m in self.messages(result)),
                        self.messages(result))

    def test_pound_gate_is_used_and_exported(self):
        export = []
        result = self.run_level(load(TARJETAS_TEST), export)
        self.assertTrue(result["ok"], self.messages(result))
        pounds = [st for st in export[0]["steps"] if st["action"] == "ground_pound"]
        self.assertIn(["fragil_de_pie"], [st["breaks"] for st in pounds], "rompe la tarjeta de pie")
        hidden = next(st for st in pounds if st["breaks"] == ["fragil_oculta"])
        self.assertTrue(hidden.get("debug"), "la oculta, con el Debug")
        self.assertAlmostEqual(pounds[0]["hold_s"], 0.35)

    def test_without_ground_pound_the_wall_blocks(self):
        level = load(TARJETAS_TEST)
        level["abilities_available"]["ground_pound"] = False
        result = self.run_level(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("golpe al suelo" in m for m in self.messages(result)), self.messages(result))

    def test_fragile_without_margin_fails(self):
        level = load(TARJETAS_TEST)
        for o in level["objects"]:
            if o["type"] == "fragile_card" and o["params"].get("id") in ("fragil_1", "fragil_2"):
                o["params"]["timer_s"] = 0.3
                o["params"]["warn_s"] = 0.25
        level["validation"]["time_margin_s"] = 0.3
        result = self.run_level(level)
        self.assertFalse(result["ok"], "0,3 s de cuenta con 0,3 s de margen: no da tiempo")


if __name__ == "__main__":
    unittest.main()
