"""Nivel 3-3 «Espejo, espejito» (data/levels/3-3.json; paso 13 de docs/propuesta-mundo-3.md §8, 2026-10-27):
esquema y alcanzabilidad sin avisos, estructura y tramos, la sala de espejos (lectores por uno y dos rebotes y el
espejo cazador con su espera), los dos lados de la pared de marcos (plataformas del reflejo vistas en la pared de
espejo del otro lado y el marco pequeno), el Reflejo falso con las placas y puertas de marco, el examen (likes,
filtro, Ladrones, cazador y reflejo juntos: pulso al reflejo de espaldas sin tocar al cazador), secretos (A con el
Debug y sin dash, con msg_3_3; B con tres rebotes; C con 25 likes), economia, camino exportado, escena y subidas al
dia, el marco dorado de salida y el 3-3 jugable tras el 3-2 con la fila del jefe desbloqueada al completarlo.
Uso: python3 -m unittest tests/test_level_3_3.py
"""

import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level as vl  # noqa: E402
import validate_level_schema as vls  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "3-3.json")
SECTIONS = [("Inicio", 0, 14), ("Tramo 1 «Sala de espejos»", 15, 78), ("Tramo 2 «Ambos lados»", 79, 138),
            ("Pausa", 139, 143), ("Tramo 3 «Reflejo falso»", 144, 200), ("Tramo 4 «Examen»", 201, 266),
            ("Cierre «Marco dorado»", 267, 279)]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def of_type(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def section_of(level, col):
    return next(s["name"] for s in level["sections"] if s["x_from"] <= col <= s["x_to"])


def secret_item(result, sid):
    return next(i for i in result["secrets"]["items"] if i["id"] == sid)


class Level33Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)
        cls.steps = cls.exported[0]["steps"]

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 3-3 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("3-3", "Espejo, espejito", 3, 4, 480))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (280, 14), "Horizontal de 280 x 14 (§4.3)")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": True}, "Todo el kit")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        goal = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "G")
        terminal = obj(lvl, "marco_dorado")
        self.assertEqual((terminal["type"], terminal["x"], terminal["y"], terminal["params"]["skin"]),
                         ("exit_terminal", goal[0], goal[1] - 1, "golden_frame"), "Marco dorado gigante")
        self.assertEqual(section_of(lvl, goal[0]), "Cierre «Marco dorado»")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "3-boss"}], "Desbloquea la fila del jefe")
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}, {"sync_1": (141, 11)})

    def test_mirror_room_readers_and_hunter(self):
        mirrors = self.result["world3"]
        lasers = [s for s in self.steps if s["action"] == "laser"]
        self.assertEqual([s["target"]["id"] for s in lasers], ["lector_techo", "lector_doble"])
        self.assertTrue(all(section_of(self.level, s["at"]["cell"][0]) == "Tramo 1 «Sala de espejos»" for s in lasers))
        waits = [s for s in self.steps if s["action"] == "wait_hunter"]
        self.assertEqual(waits[0]["target"], {"type": "hunter_mirror", "id": "cazador_sala", "facing": "n"})
        via = [s for s in self.steps if s["action"] == "pulse" and "via_hunter" in s["target"]]
        self.assertEqual([(s["target"]["id"], s["target"]["via_hunter"]["id"], s["target"]["via_hunter"]["facing"])
                          for s in via],
                         [("puente_cazador", "cazador_sala", "n"), ("puente_examen", "cazador_examen", "n")])
        self.assertIsNotNone(mirrors)
        no_laser = copy.deepcopy(self.level)
        no_laser["abilities_available"]["laser"] = False
        self.assertFalse(vl.validate(no_laser, check_schema=False)["ok"], "Sin el laser no se cruza la sala")

    def test_both_sides_of_the_frame_wall(self):
        frame = obj(self.level, "marco_lados")
        self.assertEqual((frame["x"], frame["y"], frame["params"]["orientation"]), (100, 11, "wall"))
        wall = obj(self.level, "pared_lados")
        self.assertEqual(wall["params"]["side"], "right", "La pared de espejo enseña el otro lado")
        self.assertEqual([s["action"] for s in self.steps].count("pinch"), 1)
        pinch = next(s for s in self.steps if s["action"] == "pinch")
        self.assertEqual(section_of(self.level, pinch["at"]["cell"][0]), "Tramo 2 «Ambos lados»")
        no_only = copy.deepcopy(self.level)
        no_only["objects"] = [o for o in no_only["objects"] if o["type"] != "mirror_only"]
        self.assertFalse(vl.validate(no_only, check_schema=False)["ok"], "Sin las plataformas del reflejo no se sube")

    def test_false_reflection_plates_and_doors(self):
        doors = [s["target"]["id"] for s in self.steps if s["action"] == "wait_reflection"]
        self.assertEqual(sorted(set(doors)), ["puerta_1", "puerta_2", "puerta_examen"],
                         "El reflejo sostiene las tres puertas")
        enemies = {e["id"]: e for e in self.result["world3"]["enemies"]}
        self.assertIn("reflejo_falso", enemies)
        no_reflection = copy.deepcopy(self.level)
        no_reflection["enemies"] = [e for e in no_reflection["enemies"] if e["type"] != "false_reflection"]
        no_reflection["grid"] = [row[:151] + "." + row[152:] if r == 11 else row
                                 for r, row in enumerate(no_reflection["grid"])]
        no_reflection["grid"] = [row[:248] + "." + row[249:] if r == 11 else row
                                 for r, row in enumerate(no_reflection["grid"])]
        self.assertFalse(vl.validate(no_reflection, check_schema=False)["ok"],
                         "Sin el reflejo Isak solo no llega a la puerta abierta")

    def test_exam_pulses_the_reflection_without_touching_the_hunter(self):
        pulse = [s for s in self.steps if s["action"] == "pulse" and s["target"]["type"] == "false_reflection"]
        self.assertEqual(len(pulse), 1)
        p = pulse[0]
        self.assertEqual(p["target"]["id"], "reflejo_examen")
        self.assertEqual(p["facing"], -1, "De espaldas al cazador")
        hunter = obj(self.level, "cazador_examen")
        phone_x = p["x_px"] - 36.0
        self.assertGreater(hunter["x"] * 64 - phone_x, 96.0, "El pulso al reflejo no llega al cazador")
        thieves = {e["id"]: e for e in self.result["world3"]["enemies"] if e["kind"] == "like_thief"}
        self.assertEqual({i: (e["thefts"], e["stuns"]) for i, e in thieves.items()},
                         {"ladron_1": (0, 1), "ladron_2": (0, 1)})
        filt = obj(self.level, "filtro_examen")
        self.assertEqual(section_of(self.level, filt["x"]), "Tramo 4 «Examen»")
        debug_on = [s for s in self.steps if s["action"] == "debug_on"]
        self.assertEqual(len(debug_on), 1, "El Debug solo en el filtro del examen")
        likes = {u["id"]: u for u in self.result["world3"]["likes"]["used"]}
        self.assertEqual(sorted(likes), ["likes_10", "likes_15"])
        self.assertEqual(likes["likes_15"]["publication"], "publicacion_pausa", "Anti-atasco desde sync_1")

    def test_secret_a_hidden_vitrine_with_msg_3_3(self):
        a = secret_item(self.result, "secreto_vitrina_oculta")
        self.assertEqual((a["without_debug"], a["with_debug"]), (False, True))
        secret = next(s for s in self.level["secrets"] if s["id"] == "secreto_vitrina_oculta")
        self.assertEqual((secret["memory_id"], secret["forbid_abilities"], secret["points"]), ("msg_3_3", ["dash"], 2))
        pickup = obj(self.level, "mensaje_3_3")
        self.assertEqual((pickup["x"], pickup["y"], pickup["params"]["memory_id"]), (secret["x"], secret["y"], "msg_3_3"))
        wall = obj(self.level, "pared_vitrina")
        self.assertTrue(wall["params"]["visible_only_with_debug"])
        self.assertEqual(wall["params"]["cover"], [217, 10, 3, 2], "Interior tapado")
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_3_3"]
        self.assertEqual((msg["level"], msg["secret"], msg["order"], msg["sender"], msg["subject"]),
                         ("3-3", "secreto_vitrina_oculta", 3, "Mamá", "Fondo de pantalla"))

    def test_secret_b_needs_three_bounces(self):
        self.assertTrue(secret_item(self.result, "secreto_doble_rebote")["reachable"])
        no_hunter = copy.deepcopy(self.level)
        no_hunter["objects"] = [o for o in no_hunter["objects"] if o["params"].get("id") != "cazador_rebote"]
        self.assertFalse(secret_item(vl.validate(no_hunter, check_schema=False), "secreto_doble_rebote")["reachable"],
                         "Sin el cazador el laser no llega al lector")

    def test_secret_c_needs_twenty_five_likes(self):
        self.assertTrue(secret_item(self.result, "secreto_umbral_25")["reachable"])
        self.assertEqual(obj(self.level, "likes_25")["params"]["threshold"], 25)
        no_plat = copy.deepcopy(self.level)
        no_plat["objects"] = [o for o in no_plat["objects"] if o["params"].get("id") != "likes_25"]
        self.assertFalse(secret_item(vl.validate(no_plat, check_schema=False), "secreto_umbral_25")["reachable"])

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (10, 6, 4), "6 en la ruta + 4 en secretos")
        self.assertEqual(sorted(o["params"]["id"] for o in of_type(lvl, "charger")),
                         ["cargador_1", "cargador_2", "cargador_3"])
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertEqual(of_type(lvl, "extra_life_pickup"), [])
        self.assertEqual([o["params"]["memory_id"] for o in of_type(lvl, "memory_pickup")], ["msg_3_3"])
        self.assertEqual(len(of_type(lvl, "heart_pickup")), 15)
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 20.0, "Margen de energia")

    def test_exported_path(self):
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "3-3"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("pinch", "unpinch", "heart", "laser", "pulse", "wait_hunter", "wait_reflection", "debug_on",
                       "goal"):
            self.assertIn(action, actions)
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "marco_dorado")])
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in path["steps"]))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH],
                    ["gen_world3_exit_frame.py", "--check"]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_after_the_3_2_and_boss_row_still_coming_soon(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m3 = next(w for w in hub["worlds"] if w["id"] == "m3")
        rows = {lv.get("id"): lv for lv in m3["levels"]}
        self.assertTrue(rows["3-3"]["playable"])
        self.assertEqual(rows["3-3"]["available_text"], "Nueva foto")
        self.assertFalse(rows["3-boss"]["playable"], "La Curadora sigue «Próximamente» hasta el paso 17")
        with open(os.path.join(ROOT, "data", "levels", "3-2.json"), encoding="utf-8") as handle:
            self.assertEqual(json.load(handle)["unlocks"], [{"type": "level", "id": "3-3"}])
        with open(os.path.join(ROOT, "data", "world1_objects.json"), encoding="utf-8") as handle:
            skins = json.load(handle)["exit_terminal"]["skins"]
        self.assertTrue(os.path.exists(os.path.join(ROOT, skins["golden_frame"].replace("res://", ""))))


if __name__ == "__main__":
    unittest.main()
