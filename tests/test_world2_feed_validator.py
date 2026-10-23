"""Paso 9b de docs/propuesta-mundo-2.md (2026-10-22): el validador modela los enemigos y objetos de los pasos
6-8 del Mundo 2 «El Feed»: el video en autoplay (ola, rayo y cuenta como amenazas con tiempo), el Comentarista
(bocadillo periodico), la zona de clones de «Un video mas» (simulacion a lo largo del camino y golpes al suelo
que la limpian), el muro «Cargando mas…» (3 golpes a 1,5 tiles o menos) y el reproductor que da el gesto.
Uso: python3 -m unittest tests/test_world2_feed_validator.py
"""

import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import level_plan  # noqa: E402
import validate_level  # noqa: E402
import world2_model  # noqa: E402

LEVELS = os.path.join(ROOT, "data", "levels")


def load(name):
    with open(os.path.join(LEVELS, name + ".json"), encoding="utf-8") as handle:
        return json.load(handle)


def run(level, export=None, schema=True):
    return validate_level.validate(level, ROOT, export=export, check_schema=schema)


def messages(result):
    return [e["message"] for e in result["errors"]]


def set_cell(level, x, y, char):
    row = level["grid"][y]
    level["grid"][y] = row[:x] + char + row[x + 1:]


class RoomsTest(unittest.TestCase):
    """Las salas de los pasos 6-8 validan sin errores ni avisos con los enemigos ya modelados."""

    def test_rooms_validate_without_warnings(self):
        for name in ("autoplay_test", "clones_test", "carga_test", "reproductor_test"):
            result = run(load(name))
            self.assertTrue(result["ok"], "%s: %s" % (name, messages(result)))
            self.assertEqual([w["message"] for w in result["warnings"]], [], name)

    def test_autoplay_videos_are_timed_hazards(self):
        result = run(load("autoplay_test"))
        feed = set()
        for item in result["plan"]["banners"]:
            feed.update(item.get("feed", []))
        self.assertEqual(feed, {"video_ola", "video_rayo", "video_cuenta"}, result["plan"]["banners"])


class LoweringTest(unittest.TestCase):
    def test_pause_player_is_a_switch_that_gives_the_ground_pound(self):
        level = world2_model.lower(load("reproductor_test"), level_catalog.load_catalog(ROOT, 2))
        switch = next(o for o in level["objects"] if o["type"] == "dnd_switch")
        self.assertEqual(switch["params"]["ability"], "ground_pound")
        self.assertEqual(switch["params"]["_config"], "pause_player")
        self.assertFalse(any(o["type"] == "pause_player" for o in level["objects"]))

    def test_loading_wall_needs_three_pounds(self):
        level = world2_model.lower(load("carga_test"), level_catalog.load_catalog(ROOT, 2))
        wall = next(o for o in level["objects"] if o["type"] == "_pound_card")
        self.assertEqual(wall["params"]["pounds"], 3)
        self.assertTrue(wall["params"]["wall"])


class LoadingWallTest(unittest.TestCase):
    def test_three_pounds_are_exported(self):
        export = []
        result = run(load("carga_test"), export)
        self.assertTrue(result["ok"], messages(result))
        pounds = [st for st in export[0]["steps"] if st["action"] == "ground_pound"
                  and st.get("target", {}).get("type") == "loading_wall"]
        self.assertEqual([st["count"] for st in pounds], [1, 2, 3])
        self.assertEqual([st["breaks"] for st in pounds], [[], [], ["muro_carga"]])
        self.assertTrue(all(st["of"] == 3 for st in pounds))
        # Entre golpe y golpe, el enfriamiento del gesto.
        self.assertGreater(pounds[1]["duration_s"], pounds[0]["duration_s"])
        texts = [a["text"] for a in result["path"]]
        self.assertTrue(any("3 golpes al suelo" in t and "muro" in t for t in texts), texts)

    def test_wall_without_the_gesture_is_impossible(self):
        level = load("carga_test")
        level["abilities_available"]["ground_pound"] = False
        result = run(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("golpe al suelo" in m and "muro" in m for m in messages(result)), messages(result))

    def test_wall_out_of_reach_is_impossible(self):
        # Una pared baja delante del muro: desde ninguna celda de pie la onda (1,5 tiles) lo alcanza.
        level = load("carga_test")
        for y in (8, 9):
            set_cell(level, 12, y, "#")
            set_cell(level, 13, y, "#")
        set_cell(level, 11, 7, "#")
        result = run(level, schema=False)
        self.assertFalse(result["ok"], "la onda no alcanza el muro")
        self.assertTrue(any("muro Cargando mas muro_carga: la onda del golpe al suelo no lo alcanza" in m
                            for m in messages(result)), messages(result))

    def test_the_pause_player_gives_the_gesture_in_the_graph(self):
        level = load("carga_test")
        level["abilities_available"]["ground_pound"] = False
        level["objects"].insert(0, {"type": "pause_player", "x": 4, "y": 9, "params": {
            "id": "reproductor_carga", "ability": "ground_pound", "story_line": "pausa_2_2"}})
        export = []
        result = run(level, export)
        self.assertTrue(result["ok"], messages(result))
        steps = export[0]["steps"]
        pulse = next(i for i, st in enumerate(steps) if st.get("target", {}).get("type") == "pause_player")
        self.assertEqual(steps[pulse]["target"]["ability"], "ground_pound")
        self.assertTrue(steps[pulse].get("face_back"))
        first_pound = next(i for i, st in enumerate(steps) if st["action"] == "ground_pound")
        self.assertLess(pulse, first_pound, "primero el reproductor, despues los golpes")


class ClonesTest(unittest.TestCase):
    def narrow_zone_wait(self, pound):
        """Sala de espera de la barra del 99 % (actualizaciones_test) en el Mundo 2 con una zona de clones
        estrecha alrededor del sitio donde Isak espera 20 s."""
        level = load("actualizaciones_test")
        level["world"] = 2
        level["debug_color"] = "amber"
        level["abilities_available"]["ground_pound"] = pound
        level["objects"].append({"type": "clone_zone", "x": 2, "y": 7, "params": {
            "id": "zona_estrecha", "zone": [2, 7, 5, 4]}})
        return level

    def test_clones_test_room_is_cleared_on_the_way(self):
        # Al cruzar la mitad izquierda de la zona, el borde mas lejano es el de delante: el clon nace delante de
        # Isak y viene hacia el; el plan lo limpia con un golpe al suelo antes de que llegue.
        export = []
        result = run(load("clones_test"), export)
        self.assertTrue(result["ok"], messages(result))
        zone = result["plan"]["clones"][0]
        self.assertEqual(zone["id"], "zona_clones")
        self.assertGreaterEqual(zone["spawned"], 1)
        clears = [st for st in export[0]["steps"] if st.get("clears")]
        self.assertEqual(len(clears), zone["pounds"])

    def test_waiting_in_a_narrow_zone_without_the_gesture_fails(self):
        result = run(self.narrow_zone_wait(False))
        self.assertFalse(result["ok"])
        self.assertTrue(any("zona de clones zona_estrecha" in m for m in messages(result)), messages(result))

    def test_waiting_in_a_narrow_zone_with_the_gesture_pounds_them_away(self):
        export = []
        result = run(self.narrow_zone_wait(True), export)
        self.assertTrue(result["ok"], messages(result))
        zone = result["plan"]["clones"][0]
        self.assertGreater(zone["pounds"], 2, zone)
        clears = [st for st in export[0]["steps"] if st["action"] == "ground_pound"]
        self.assertTrue(clears and all(st.get("clears") == ["zona_estrecha"] for st in clears), clears)

    def test_carga_test_pounds_clear_the_zone(self):
        result = run(load("carga_test"))
        zone = result["plan"]["clones"][0]
        self.assertEqual(zone["id"], "zona_muro")
        self.assertGreater(zone["spawned"], 0, "mientras fuerza el muro nacen clones")


class VideoAndCommenterTest(unittest.TestCase):
    def wave_under_low_ceiling(self, dash):
        """La ola del video_ola barre 10 celdas bajo un techo bajo: sin dash, el pasillo (4 s andando) no cabe
        en el reposo del clip (0,95 s)."""
        level = load("autoplay_test")
        level["enemies"] = [e for e in level["enemies"] if e["id"] == "video_ola"]
        level["abilities_available"]["dash"] = dash
        for x in range(3, 15):
            set_cell(level, x, 7, "#")
        return level

    def test_wave_without_a_safe_window_fails(self):
        result = run(self.wave_under_low_ceiling(False), schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("video_ola" in m for m in messages(result)), messages(result))

    def test_wave_is_crossed_with_the_dash(self):
        # Con el dash (invulnerable 0,3 s) la ola se atraviesa.
        result = run(self.wave_under_low_ceiling(True), schema=False)
        self.assertTrue(result["ok"], messages(result))

    def test_commenter_with_a_safe_window(self):
        # Comentarista en mitad del pasillo de clones_test (sin la zona): el bocadillo sube por la columna 21 y
        # el camino la cruza en un hueco entre dos bocadillos; el camino exportado lleva su fase.
        level = load("clones_test")
        level["objects"] = [o for o in level["objects"] if o["type"] != "clone_zone"]
        level["enemies"] = [{"id": "comentarista_medio", "type": "commenter", "x": 20, "y": 9,
                             "params": {"facing": 1}}]
        set_cell(level, 20, 8, "#")
        export = []
        result = run(level, export, schema=False)
        self.assertTrue(result["ok"], messages(result))
        feed = set()
        for item in result["plan"]["banners"]:
            feed.update(item.get("feed", []))
        self.assertIn("comentarista_medio", feed)
        sync = [st for st in export[0]["steps"] if st["action"] == "wait_phase"]
        self.assertTrue(sync and "comentarista_medio" in sync[0]["clip_cycle_s"], sync)


class FeedHazardModelTest(unittest.TestCase):
    """Las amenazas del feed en el plan (sin buscar el camino): rayo en la columna de Isak al empezar el clip y
    bocadillo del Comentarista con su reloj desde el inicio del nivel."""

    def planner(self, level):
        level = world2_model.lower(level, level_catalog.load_catalog(ROOT, int(level.get("world", 1))))
        rules = validate_level.Rules(ROOT, None, validate_level.DEFAULT_JUMP_EFFICIENCY, validate_level.DEFAULT_LIMIT,
                                     False, (), ())
        return level_plan.Planner(validate_level.Validator(level, rules))

    def test_ray_falls_on_the_column_isak_had_when_the_clip_started(self):
        planner = self.planner(load("autoplay_test"))
        ray = next(h for h in planner.feed_data() if h["kind"] == "ray")
        self.assertAlmostEqual(ray["warn"], 0.75)
        self.assertAlmostEqual(ray["wave"], 0.4)
        during = ray["warn"] + 0.1
        rect = planner.feed_rects(ray, during, {("ray", "video_rayo"): 25})
        self.assertEqual(len(rect), 1)
        self.assertAlmostEqual((rect[0][0] + rect[0][2]) * 0.5, 25.5 * 64)
        self.assertEqual(rect[0][1], 4 * 64, "desde la fila de arriba de la tarjeta")
        self.assertEqual(rect[0][3], 10 * 64, "ray_tiles 6 hacia abajo")
        self.assertEqual(planner.feed_rects(ray, during, {("ray", "video_rayo"): -1}), [], "sin la tarjeta a la vista")
        self.assertEqual(planner.feed_rects(ray, 0.5, {("ray", "video_rayo"): 25}), [], "durante el aviso no dana")
        self.assertEqual(planner.feed_rects(ray, during, {}), [ray["band"]], "sin saber la columna: toda la franja")
        # La columna se apunta al empezar el clip, solo con la tarjeta entera a la vista.
        zs = {}
        planner.ray_note([ray], zs, ray["interval"] - 0.01, ray["interval"] + 0.01, 25.5 * 64, 10 * 64)
        self.assertEqual(zs[("ray", "video_rayo")], 25)
        planner.ray_note([ray], zs, ray["interval"] - 0.01, ray["interval"] + 0.01, 2.5 * 64, 10 * 64)
        self.assertEqual(zs[("ray", "video_rayo")], -1)

    def test_commenter_shot_rises_from_its_mouth_and_stops_at_the_ceiling(self):
        level = load("clones_test")
        level["enemies"][0]["params"]["offset_s"] = 1.0
        planner = self.planner(level)
        shot = next(h for h in planner.feed_data() if h["id"] == "comentarista")
        self.assertAlmostEqual(shot["phase"], -1.0, msg="reloj desde el inicio, desplazado offset_s")
        self.assertEqual(planner.feed_rects(shot, 0.5, {}), [], "durante el aviso no hay bocadillo")
        rect = planner.feed_rects(shot, shot["launch"], {})[0]
        self.assertAlmostEqual((rect[0] + rect[2]) * 0.5, 33.5 * 64, msg="columna de delante (facing -1)")
        self.assertAlmostEqual((rect[1] + rect[3]) * 0.5, 10 * 64 - 32)
        # Sube 12 tiles como mucho; el techo (fila 0) lo apaga antes: su borde de arriba llega a y = 64.
        self.assertAlmostEqual(shot["travel_s"], (10 * 64 - 32 - 16 - 64) / 320.0, delta=8.0 / 320.0)


if __name__ == "__main__":
    unittest.main()
