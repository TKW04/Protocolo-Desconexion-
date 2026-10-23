"""Nivel 2-3 «Scroll infinito» (data/levels/2-3.json; paso 14 de docs/propuesta-mundo-2.md §8, diseno en §4.3 y
§4.3.1, 2026-10-23): esquema y alcanzabilidad sin avisos, estructura y tramos, rafagas del Tramo 1, la inversion del
Tramo 2 (armada por su zona al bajar por los pisos que rompe el golpe al suelo), las Historias del Tramo 3 (con el
patron 13), el muro «Cargando más…» con la zona de clones (3 golpes que tambien la limpian), secretos (A fuera del feed
con msg_2_3, B el power bank, C con salto + dash), economia, cierre con la cuenta automatica, camino exportado, escena y
subidas al dia, y el 2-3 jugable desde la carpeta del Mundo 2.
Uso: python3 -m unittest tests/test_level_2_3.py
"""

import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import validate_level as vl  # noqa: E402
import validate_level_schema as vls  # noqa: E402
import world2_model  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "2-3.json")
H = 170


def row(h):
    """Fila del grid de la altura h (h 0 = suelo de la sala de inicio)."""
    return 169 - h


SECTIONS = [("Inicio", row(7), row(0)), ("Tramo 1 «Ráfagas»", row(45), row(8)), ("Pausa", row(49), row(46)),
            ("Tramo 2 «Al revés»", row(79), row(50)), ("Tramo 3 «Historias»", row(127), row(80)),
            ("Tramo 4 «Cargando más…»", row(159), row(128)), ("Cierre «Sin final»", 0, row(160))]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def enemy(level, eid):
    return next(e for e in level["enemies"] if e["id"] == eid)


def section_of(level, r):
    return next(s["name"] for s in level["sections"] if s["y_from"] <= r <= s["y_to"])


def reaches(level, cell, **abilities):
    """Alcanzabilidad del grafo (sin el plan) desde P hasta `cell` con abilities_available cambiadas."""
    level = copy.deepcopy(level)
    level["abilities_available"].update(abilities)
    level = world2_model.lower(level, level_catalog.load_catalog(ROOT, 2))
    v = vl.Validator(level, vl.Rules())
    start, _ = v.spawn_node(v.find("P")[0])
    v.goal_cells = {v.find("G")[0]}
    return v.progression(start, frozenset(), vl.INF, targets={tuple(cell)})["ok"]


class Level23Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)
        cls.steps = cls.exported[0]["steps"] if cls.exported else []

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 2-3 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("2-3", "Scroll infinito", 2, 4, 420))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (20, H), "Feed de 20 x 170 (§4.3)")
        self.assertEqual(lvl["camera"]["vertical"], "autoscroll")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True},
                         "Todo el kit")
        self.assertEqual([(s["name"], s["y_from"], s["y_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertTrue(all(r[0] == "#" and r[-1] == "#" for r in lvl["grid"]), "Columnas 0 y 19: el marco")
        start = next((c, r) for r, line in enumerate(lvl["grid"]) for c, ch in enumerate(line) if ch == "P")
        goal = next((c, r) for r, line in enumerate(lvl["grid"]) for c, ch in enumerate(line) if ch == "G")
        self.assertEqual(section_of(lvl, start[1]), "Inicio")
        self.assertEqual(section_of(lvl, goal[1]), "Cierre «Sin final»")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "2-boss"}])
        self.assertEqual([c["id"] for c in lvl["checkpoints"]], ["sync_1"], "Un punto de sincronizacion")
        self.assertEqual(section_of(lvl, lvl["checkpoints"][0]["y"]), "Pausa")

    def test_bursts_of_section_1(self):
        scroll = self.level["scroll"]
        tramo1 = [s for s in scroll["stages"] if s["y_from"] >= row(45) - 10]
        bursts = [s for s in tramo1 if s["speed_tiles_s"] == 1.2]
        self.assertEqual(len(bursts), 4, "Cuatro rafagas de 1,2 tiles/s")
        for b in bursts:
            seconds = (b["y_to"] - b["y_from"] + 1) / b["speed_tiles_s"]
            self.assertTrue(3.0 <= seconds <= 4.5, "Rafagas de 3-4 s: %.1f" % seconds)
        self.assertTrue(all(s["speed_tiles_s"] == 0.4 for s in tramo1 if s not in bursts), "Tramos lentos a 0,4")
        self.assertEqual(section_of(self.level, enemy(self.level, "video_rafagas")["y"]), "Tramo 1 «Ráfagas»")
        self.assertEqual([s["id"] for s in scroll["stops"]], ["sync_1", "muro_carga"])
        info = self.result["plan"]["scroll"]
        self.assertGreaterEqual(info["margin_min_tiles"], 3.0, "Nunca a menos de 3 tiles del borde que dana")
        self.assertTrue(220.0 <= self.result["plan"]["duration_s"] <= 260.0,
                        "Camino de unos 240 s (§8.1): %.1f" % self.result["plan"]["duration_s"])

    def test_reverse_is_armed_down_the_pit_and_the_pound_opens_it(self):
        rev = self.level["scroll"]["reverses"]
        self.assertEqual(len(rev), 1)
        self.assertEqual((rev[0]["duration_s"], rev[0]["speed_tiles_s"]), (6.0, 0.8), "6 s a 0,8 tiles/s (§4.3)")
        c, r, w, h = rev[0]["trigger"]
        self.assertEqual(section_of(self.level, r), "Tramo 2 «Al revés»")
        self.assertEqual(section_of(self.level, rev[0]["at_row"]), "Tramo 2 «Al revés»", "at_row, de respaldo")
        breaks = [b for s in self.steps if s["action"] == "ground_pound" for b in s["breaks"]]
        self.assertEqual(breaks[:4], ["bajada_1", "bajada_2", "bajada_3", "puerta_subida"],
                         "Patron 10 al reves: se baja rompiendo las fragiles con el golpe")
        for oid in ("bajada_1", "bajada_2", "bajada_3"):
            self.assertEqual(obj(self.level, oid)["params"]["trigger"], "pound_only")
        # La zona solo se pisa tras romper la primera bajada (despues de subir al borde).
        zone_rows = range(r, r + h)
        first = next(i for i, s in enumerate(self.steps)
                     if s.get("to", s.get("at", {})).get("cell", [0, 0])[1] in zone_rows
                     and c <= s.get("to", s.get("at", {})).get("cell", [0, 0])[0] < c + w)
        pound = next(i for i, s in enumerate(self.steps) if s["action"] == "ground_pound" and s["breaks"] == ["bajada_1"])
        self.assertLess(pound, first)
        self.assertEqual(enemy(self.level, "comentarista")["type"], "commenter")
        self.assertEqual(section_of(self.level, enemy(self.level, "comentarista")["y"]), "Tramo 2 «Al revés»")
        # Sin el golpe al suelo no se sale de la bajada (ni se rompe el muro).
        self.assertFalse(vl.validate(dict(copy.deepcopy(self.level), abilities_available=dict(
            self.level["abilities_available"], ground_pound=False)), check_schema=False)["ok"])

    def test_stories_of_section_3(self):
        stories = sorted(o["params"]["id"] for o in self.level["objects"] if o["type"] == "story_card")
        self.assertEqual(stories, ["historia_1", "historia_2", "historia_3", "historia_alta"])
        blinks = sorted({i for b in self.result["plan"]["banners"] for i in b.get("blinks", [])})
        self.assertEqual(blinks, ["historia_1", "historia_2", "historia_3"], "Las tres Historias del camino se pisan")
        # Patron 13: Historia -> fragil -> tarjeta (de la Historia a la tarjeta de encima hay 4 filas).
        h2, f1 = obj(self.level, "historia_2"), obj(self.level, "fragil_1")
        self.assertEqual(h2["y"] - f1["y"], 2)
        beats = [s for s in self.steps if s["action"] == "wait_beat"]
        self.assertTrue(beats and all(str(s.get("rhythm", "")).startswith("_historia_") for s in beats))
        self.assertEqual(section_of(self.level, obj(self.level, "cargador_2")["y"]), "Tramo 3 «Historias»")
        self.assertEqual(section_of(self.level, enemy(self.level, "video_historias")["y"]), "Tramo 3 «Historias»")

    def test_loading_wall_with_clones(self):
        wall = obj(self.level, "muro_carga")
        self.assertEqual((wall["type"], section_of(self.level, wall["y"])), ("loading_wall", "Tramo 4 «Cargando más…»"))
        zone = obj(self.level, "enjambre_muro")["params"]["zone"]
        pounds = [s for s in self.steps if s["action"] == "ground_pound" and s["target"]["id"] == "muro_carga"]
        self.assertEqual([(p["count"], p["of"]) for p in pounds], [(1, 3), (2, 3), (3, 3)])
        cell = pounds[0]["at"]["cell"]
        self.assertTrue(zone[0] <= cell[0] < zone[0] + zone[2] and zone[1] <= cell[1] < zone[1] + zone[3],
                        "Se golpea dentro de la zona de clones")
        clones = {c["id"]: c for c in self.result["plan"]["clones"]}["enjambre_muro"]
        self.assertGreater(clones["spawned"], 0, "Golpear el muro hace nacer clones")
        self.assertGreaterEqual(clones["wave_pounds"], 3, "Los golpes del muro tambien limpian la zona")
        stop = next(s for s in self.level["scroll"]["stops"] if s["id"] == "muro_carga")
        self.assertGreater(stop["at_row"], wall["y"] + 2, "El scroll se para con el muro a la vista")
        self.assertEqual(section_of(self.level, obj(self.level, "cargador_3")["y"]), "Tramo 4 «Cargando más…»")

    def test_secret_a_out_of_the_feed_gives_msg_2_3(self):
        secret = next(s for s in self.level["secrets"] if s["id"] == "secreto_fuera_del_feed")
        self.assertEqual((secret["points"], secret["memory_id"], secret["needs_debug"], secret["forbid_abilities"]),
                         (2, "msg_2_3", True, ["dash"]))
        self.assertEqual(section_of(self.level, secret["y"]), "Tramo 3 «Historias»")
        self.assertGreaterEqual(secret["x"], 16, "En el marco derecho, fuera del feed")
        pickup = obj(self.level, "mensaje_2_3")
        self.assertEqual((pickup["x"], pickup["y"]), (secret["x"], secret["y"]))
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_2_3")
        self.assertEqual((memory["reachable_without_debug"], memory["mandatory"]), (False, False))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            msg = next(m for m in json.load(handle)["memories"] if m["id"] == "msg_2_3")
        self.assertEqual((msg["sender"], msg["level"], msg["secret"], msg["first_lap"], msg["subject"]),
                         ("Mamá", "2-3", "secreto_fuera_del_feed", 1, "Ya suena"))

    def test_secrets_b_and_c(self):
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertTrue(items["secreto_al_reves"]["reachable"])
        self.assertTrue(items["secreto_historia_alta"]["reachable"])
        door = obj(self.level, "puerta_power_bank")
        self.assertEqual((door["x"], door["params"]["variant"]), (2, "upright"), "Fragil de pie en la columna 2")
        self.assertEqual(section_of(self.level, door["y"]), "Tramo 2 «Al revés»")
        self.assertIn("pound:puerta_power_bank", items["secreto_al_reves"]["secret_gates_opened"])
        high = next(s for s in self.level["secrets"] if s["id"] == "secreto_historia_alta")
        self.assertTrue(reaches(self.level, (high["x"], high["y"])))
        self.assertFalse(reaches(self.level, (high["x"], high["y"]), dash=False), "Solo con salto + dash aereo")

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (10, 6, 4),
                         "10 puntos: 6 en la ruta + 4 en secretos (§4.3.1)")
        chargers = sorted(o["params"]["id"] for o in lvl["objects"] if o["type"] == "charger")
        self.assertEqual(chargers, ["cargador_1", "cargador_2", "cargador_3"])
        self.assertEqual(len([o for o in lvl["objects"] if o["type"] == "power_bank_pickup"]), 1, "1 power bank")
        self.assertFalse([o for o in lvl["objects"] if o["type"] == "extra_life_pickup"], "Sin vida extra")
        self.assertGreater(self.result["plan"]["energy"]["min"], 0.0)

    def test_closing_card_counts_down_and_leaves_alone(self):
        terminal = obj(self.level, "terminal_scroll_infinito")
        self.assertEqual((terminal["params"]["countdown_s"], terminal["help_id"]), (3.0, ""))
        self.assertEqual(self.result["exit_terminals"],
                         [{"id": "terminal_scroll_infinito", "pulse_from": None, "countdown_s": 3.0}])
        texts = [o["params"]["text"] for o in self.level["objects"] if o["type"] == "feed_sign"]
        self.assertFalse([t for t in texts if "vuelta" in t.lower()], "La UI nunca dice «vuelta»")

    def test_exported_path(self):
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "2-3"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("wait_scroll", "wait_phase", "wait_beat", "ground_pound", "goal"):
            self.assertIn(action, actions)
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("wait", "terminal_scroll_infinito")])

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_2_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m2 = next(w for w in hub["worlds"] if w["id"] == "m2")
        rows = [(lv["id"], lv["name"], lv["playable"]) for lv in m2["levels"]]
        self.assertEqual(rows[:3], [("2-1", "Para ti", True), ("2-2", "Un video más", True),
                                    ("2-3", "Scroll infinito", True)])
        self.assertEqual(m2["levels"][2].get("available_text"), "Siguiente video")
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "2-3.tscn")))


if __name__ == "__main__":
    unittest.main()
