"""Nivel 3-1 «Galería de perfil» (data/levels/3-1.json; paso 10 de docs/propuesta-mundo-3.md §8, 2026-10-26):
esquema y alcanzabilidad sin avisos, estructura y tramos, likes (corazones, plataformas ♥5 / ♥10 / ♥15 con su
publicacion anti-atasco), Influencer y Ladron, pared de espejo con las plataformas del reflejo, secretos (A solo con
Pellizcar: requires_abilities; B con «Borrar publicaciones» y sin dash; C con el Debug y el dash aereo), economia,
camino exportado, escena y subidas al dia, y el 3-1 jugable desde la carpeta del Mundo 3.
Uso: python3 -m unittest tests/test_level_3_1.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "3-1.json")
SECTIONS = [("Inicio «Perfil»", 0, 20), ("Tramo 1 «Corazones»", 21, 70), ("Tramo 2 «Pose»", 71, 118),
            ("Pausa", 119, 123), ("Tramo 3 «Ladrón»", 124, 170), ("Tramo 4 «Del otro lado»", 171, 210),
            ("Cierre «Publicar»", 211, 219)]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def of_type(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def section_of(level, col):
    return next(s["name"] for s in level["sections"] if s["x_from"] <= col <= s["x_to"])


class Level31Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 3-1 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("3-1", "Galería de perfil", 3, 3, 360))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (220, 14), "Horizontal de 220 x 14 (§4.1)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["debug_color"], "green", "Debug verde acido en el Mundo 3")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": False}, "Todo el kit del Mundo 2; Pellizcar, no (llega en el 3-2)")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertNotIn("stands_for", lvl)
        start = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "P")
        goal = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "G")
        self.assertEqual(start, (3, 11), "Vortice de llegada en (3, 11)")
        self.assertEqual(section_of(lvl, goal[0]), "Cierre «Publicar»")
        terminal = obj(lvl, "terminal_publicar")
        self.assertEqual((terminal["type"], terminal["x"], terminal["y"], terminal["params"]["text"]),
                         ("exit_terminal", goal[0], goal[1] - 1, "Publicar"))
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "3-2"}])
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}, {"sync_1": (121, 11)},
                         "Un punto de sincronizacion a mitad (doc), en la Pausa")

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (7, 6, 1),
                         "6 en la ruta (uno por tramo) + 1 en el secreto A")
        chargers = {o["params"]["id"]: o for o in of_type(lvl, "charger")}
        self.assertEqual(sorted(chargers), ["cargador_1", "cargador_2"])
        self.assertEqual((chargers["cargador_1"]["x"], chargers["cargador_2"]["x"]), (96, 176))
        self.assertTrue(all(c["params"]["reusable"] and c["params"]["amount"] == 50.0
                            and c["params"]["cooldown_s"] == 10.0 for c in chargers.values()))
        self.assertEqual(len(of_type(lvl, "like_source")), 3, "3 publicaciones")
        self.assertEqual(len(of_type(lvl, "heart_pickup")), 18, "18 corazones en el Tramo 1")
        self.assertTrue(all(section_of(lvl, o["x"]) == "Tramo 1 «Corazones»" for o in of_type(lvl, "heart_pickup")))
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1, "El power bank, en el secreto A")
        lives = of_type(lvl, "extra_life_pickup")
        self.assertEqual([(o["params"]["id"], o["params"]["secret_id"]) for o in lives], [("vida_extra_3_1", "C")],
                         "La vida extra del Mundo 3 (N = 3: la anterior fue la del 2-1)")
        self.assertEqual(sorted(o["params"]["memory_id"] for o in of_type(lvl, "memory_pickup")),
                         ["msg_3_1", "msg_3_2"])
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 50.0, "Energia de sobra (obligatoria ~20)")

    def test_likes_platforms_and_anti_softlock(self):
        plats = {o["params"]["id"]: o["params"] for o in of_type(self.level, "like_platform")}
        normal = sorted(p["threshold"] for p in plats.values() if not p.get("invert"))
        self.assertEqual(normal, [5, 10, 15], "Escalera 5 -> 10 en el Tramo 1 y el umbral 15 del Ladron")
        inverse = [i for i, p in plats.items() if p.get("invert")]
        self.assertEqual(sorted(inverse), ["inversa_1", "inversa_2", "inversa_3"])
        self.assertTrue(all(section_of(self.level, obj(self.level, i)["x"]) == "Tramo 3 «Ladrón»" for i in inverse))
        likes = self.result["world3"]["likes"]
        self.assertEqual(likes["thresholds"], [5, 10, 15], likes)
        self.assertGreaterEqual(likes["final"], 15)
        used = {u["id"]: u for u in likes["used"]}
        self.assertEqual(sorted(used), ["likes_10", "likes_15", "likes_5"], "El camino pisa las tres")
        self.assertEqual((used["likes_5"]["sync"], used["likes_5"]["publication"]), ("P", "publicacion_foso"),
                         "Anti-atasco: la publicacion junto al foso, alcanzable sin likes")
        self.assertEqual((used["likes_15"]["sync"], used["likes_15"]["publication"]), ("sync_1", "publicacion_vitrina"))

    def test_enemies_and_mirror(self):
        enemies = {e["id"]: e for e in self.level["enemies"]}
        self.assertEqual(sorted((e["type"], e["x"]) for e in enemies.values()),
                         [("influencer_bot", 84), ("influencer_bot", 104), ("like_thief", 147)])
        self.assertEqual(section_of(self.level, 84), "Tramo 2 «Pose»")
        report = {e["id"]: e for e in self.result["world3"]["enemies"]}
        self.assertEqual((report["ladron_1"]["thefts"], report["ladron_1"]["stuns"]), (0, 1),
                         "0 robos: el pulso lo aturde antes del contacto")
        for iid in ("influencer_1", "influencer_2"):
            self.assertEqual((report[iid]["flashes"], report[iid]["blind"]), (0, []), "Ningun flash ciega (%s)" % iid)
        self.assertEqual(report["influencer_1"]["covered"], 1, "Las columnas-marco tapan el flash")
        wall = obj(self.level, "pared_espejo")
        self.assertEqual((wall["type"], wall["x"], wall["params"]["width_tiles"]), ("mirror_wall", 182, 7),
                         "Pared de espejo en las columnas 182-188")
        seen = {m["id"]: m for m in self.result["world3"]["mirror_only"]}
        self.assertEqual(sorted(seen), ["reflejo_1", "reflejo_2"])
        self.assertTrue(all(m["wall"] == "pared_espejo" and m["seen"] for m in seen.values()), "Se ven en el espejo")
        self.assertTrue(seen["reflejo_2"]["on_path"] and seen["reflejo_2"]["wall_in_view"],
                        "El camino cruza el foso por el reflejo, con la pared a la vista")
        self.assertFalse(self.level["validation"].get("debug_required", False), "El espejo hace innecesario el Debug")

    def test_secret_a_needs_compress(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_marco_decorativo")
        self.assertEqual((a["requires_abilities"], a["memory_id"], a["points"]), (["compress"], "msg_3_2", 1))
        self.assertEqual(sorted(a["reward"]), ["attention_points", "memory", "power_bank"])
        frame = obj(self.level, "marco_decorativo")
        self.assertEqual((frame["type"], frame["x"], frame["y"], frame["params"]["orientation"]),
                         ("small_frame", 58, 11, "wall"), "Marco pequeno en la pared (col. 58, fila 11)")
        grid = self.level["grid"]
        self.assertEqual((grid[10][58], grid[11][58], grid[12][58]), ("#", ".", "#"), "Hueco de 1 fila")
        item = next(i for i in self.result["secrets"]["items"] if i["id"] == "secreto_marco_decorativo")
        self.assertEqual(item["requires_abilities"], ["compress"])
        self.assertTrue(item["reachable"], "Con Pellizcar se alcanza")
        self.assertFalse(item["reachable_without_abilities"], "Sin Pellizcar, no (no cuenta en la primera visita)")
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_3_2")
        self.assertEqual((memory["secret"], memory["requires_abilities"]), ("secreto_marco_decorativo", ["compress"]))

    def test_secret_b_needs_the_reset_and_not_the_dash(self):
        b = next(s for s in self.level["secrets"] if s["id"] == "secreto_sin_likes")
        self.assertEqual((b["reward"], b["memory_id"], b["forbid_abilities"]), ("memory", "msg_3_1", ["dash"]))
        reset = obj(self.level, "borrar_publicaciones")
        self.assertEqual((reset["type"], section_of(self.level, reset["x"])), ("like_reset", "Tramo 3 «Ladrón»"))
        item = next(i for i in self.result["secrets"]["items"] if i["id"] == "secreto_sin_likes")
        self.assertTrue(item["reachable"])
        no_reset = copy.deepcopy(self.level)
        no_reset["objects"] = [o for o in no_reset["objects"] if o["type"] != "like_reset"]
        without = vl.validate(no_reset, check_schema=False)
        self.assertFalse(next(i for i in without["secrets"]["items"] if i["id"] == "secreto_sin_likes")["reachable"],
                         "Sin «Borrar publicaciones» no se llega a la vitrina")

    def test_secret_c_needs_the_debug_and_the_air_dash(self):
        c = next(s for s in self.level["secrets"] if s["id"] == "secreto_vida_extra")
        self.assertEqual((c["object"], c["needs_debug"], c["reward"]), ("glitch_wall", True, "extra_life"))
        wall = obj(self.level, "pared_vida_extra")
        self.assertEqual((wall["x"], wall["params"]["visible_only_with_debug"]), (206, True))
        life = next(i for i in self.result["extra_lives"] if i["id"] == "vida_extra_3_1")
        self.assertEqual((life["reachable_without_debug"], life["reachable_with_debug"], life["mandatory"]),
                         (False, True, False))
        no_dash = copy.deepcopy(self.level)
        no_dash["abilities_available"]["dash"] = False
        without = vl.validate(no_dash, check_schema=False)
        life = next(i for i in without["extra_lives"] if i["id"] == "vida_extra_3_1")
        self.assertFalse(life["reachable_with_debug"], "Sin el dash aereo no se llega a la repisa")
        self.assertEqual([e for e in without["errors"] if "vida_extra" not in e["message"]], [],
                         "El camino principal no necesita el dash")

    def test_exported_path(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "3-1"))
        steps = path["steps"]
        actions = [s["action"] for s in steps]
        for action in ("heart", "pulse", "jump", "goal"):
            self.assertIn(action, actions)
        self.assertNotIn("pinch", actions, "Sin Pellizcar en el camino")
        self.assertGreaterEqual(actions.count("heart"), 15, "Corazones suficientes para el umbral 15")
        thief_pulses = [s for s in steps if s["action"] == "pulse" and s["target"]["type"] == "like_thief"]
        self.assertEqual(len(thief_pulses), 1, "Un pulso al Ladron antes de que robe")
        finals = [s for s in steps if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_publicar")])
        self.assertEqual(actions[-1], "goal")
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in steps))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_3_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m3 = next(w for w in hub["worlds"] if w["id"] == "m3")
        self.assertEqual(m3["unlocked_by"], ["2-boss"], "La carpeta M3 se abre al vencer a Autoplay")
        rows = [(lv["id"], lv["name"], lv["playable"], lv.get("kind")) for lv in m3["levels"]]
        self.assertEqual(rows, [("3-1", "Galería de perfil", True, None), ("3-2", "Sin filtro", False, None),
                                ("3-3", "Espejo, espejito", False, None), ("3-boss", "La Curadora", False, "boss")])
        self.assertTrue(all(lv["laps"] == [1] for lv in m3["levels"]))
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "3-1.tscn")))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        self.assertEqual((memories["msg_3_1"]["level"], memories["msg_3_1"]["secret"], memories["msg_3_1"]["order"]),
                         ("3-1", "secreto_sin_likes", 1))
        self.assertEqual((memories["msg_3_2"]["level"], memories["msg_3_2"]["secret"], memories["msg_3_2"]["order"]),
                         ("3-1", "secreto_marco_decorativo", 2), "msg_3_2 es del capitulo del 3-2, en el 3-1")


if __name__ == "__main__":
    unittest.main()
