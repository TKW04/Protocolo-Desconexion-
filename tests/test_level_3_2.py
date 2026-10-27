"""Nivel 3-2 «Sin filtro» (data/levels/3-2.json; paso 12 de docs/propuesta-mundo-3.md §8, 2026-10-27):
esquema y alcanzabilidad sin avisos, estructura y tramos, «Recortar» como puerta obligatoria de Pellizcar (sin ella
el marco de la salida del Estudio cierra el paso), marcos pequenos del camino, filtros (suelos falsos y pinchos
ocultos con el Debug y su cargador; el filtro movil), likes (♥10 con su publicacion anti-atasco; ♥20 del secreto B),
Ladron e Influencer, secretos (A con el Debug y Pellizcar; B con 20 likes; C con el dash aereo), economia, camino
exportado, escena y subidas al dia, y el 3-2 jugable desde la carpeta del Mundo 3 tras el 3-1.
Uso: python3 -m unittest tests/test_level_3_2.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "3-2.json")
SECTIONS = [("Inicio «Estudio»", 0, 22), ("Tramo 1 «Recorte»", 23, 75), ("Tramo 2 «Filtro»", 76, 124),
            ("Pausa", 125, 129), ("Tramo 3 «Mezcla»", 130, 186), ("Tramo 4 «El filtro se mueve»", 187, 240),
            ("Cierre «Publicar sin filtro»", 241, 249)]


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


class Level32Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 3-2 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("3-2", "Sin filtro", 3, 4, 420))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (250, 14), "Horizontal de 250 x 14 (§4.2)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": False}, "Pellizcar no viene dado: lo da «Recortar»")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        start = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "P")
        goal = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "G")
        self.assertEqual(start, (3, 11))
        terminal = obj(lvl, "terminal_sin_filtro")
        self.assertEqual((terminal["type"], terminal["x"], terminal["y"], terminal["params"]["text"]),
                         ("exit_terminal", goal[0], goal[1] - 1, "Publicar sin filtro"))
        self.assertEqual(section_of(lvl, goal[0]), "Cierre «Publicar sin filtro»")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "3-3"}])
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}, {"sync_1": (127, 11)})

    def test_crop_tool_gives_compress_and_is_mandatory(self):
        tool = obj(self.level, "recortar")
        self.assertEqual((tool["type"], tool["x"], tool["params"]["ability"], tool["params"]["story_line"]),
                         ("crop_tool", 12, "compress", "recorte_3_2"))
        exit_frame = obj(self.level, "marco_salida")
        self.assertEqual((exit_frame["x"], exit_frame["y"]), (21, 11), "La salida del Estudio es un marco pequeno")
        self.assertLessEqual(exit_frame["x"] - tool["x"], 9, "Uso obligatorio a 9 tiles de la obtencion")
        actions = [s["action"] for s in self.exported[0]["steps"]]
        crop = next(i for i, s in enumerate(self.exported[0]["steps"])
                    if s["action"] == "pulse" and s["target"]["type"] == "crop_tool")
        self.assertLess(crop, actions.index("pinch"), "«Recortar» antes del primer pellizco")
        no_tool = copy.deepcopy(self.level)
        no_tool["objects"] = [o for o in no_tool["objects"] if o["type"] != "crop_tool"]
        self.assertFalse(vl.validate(no_tool, check_schema=False)["ok"], "Sin «Recortar» no se sale del Estudio")
        line = obj(self.level, "eco_marco_galeria")
        self.assertEqual((line["type"], line["x"], line["params"]["text"]),
                         ("eco_line", 40, "Ese marco de la galería… ahora sí cabes."))
        self.assertFalse(line["params"].get("important", False), "No importante (Eco recuerda el secreto A del 3-1)")

    def test_small_frames_on_the_path(self):
        frames = {o["params"]["id"]: o for o in of_type(self.level, "small_frame")}
        self.assertEqual(sorted(frames), ["marco_entre_filtros", "marco_original", "marco_recorte_1",
                                          "marco_repisa", "marco_salida", "marco_suelo"])
        self.assertEqual(frames["marco_suelo"]["params"]["orientation"], "floor", "Marco en el suelo del Recorte")
        pinches = [s for s in self.exported[0]["steps"] if s["action"] == "pinch"]
        self.assertEqual(len(pinches), 4, "Estudio, dos del Recorte y el de entre filtros")
        self.assertTrue(all(section_of(self.level, s["at"]["cell"][0]) != "Tramo 3 «Mezcla»" for s in pinches))

    def test_filters_need_the_debug_with_a_charger_in_view(self):
        filters = {o["params"]["id"]: o for o in of_type(self.level, "filter_zone")}
        first = filters["filtro_orejitas"]
        self.assertEqual((first["x"], first["x"] + first["params"]["width_tiles"] - 1), (86, 112), "cols. 86-112")
        self.assertEqual(first["params"]["label"], "Filtro: Orejitas · Brillo +40")
        self.assertEqual(len(first["params"]["fake_floor"]), 2, "Dos suelos falsos")
        self.assertEqual(obj(self.level, "cargador_1")["x"], 82, "cargador_1 a la entrada")
        moving = filters["filtro_movil"]
        self.assertEqual((len(moving["params"]["positions"]), moving["params"]["cycle_s"]), (3, 4.0))
        debug_on = [s for s in self.exported[0]["steps"] if s["action"] == "debug_on"]
        sections = sorted({section_of(self.level, s["at"]["cell"][0]) for s in debug_on})
        self.assertEqual(sections, ["Tramo 2 «Filtro»", "Tramo 3 «Mezcla»", "Tramo 4 «El filtro se mueve»"],
                         "El Debug solo en los filtros")
        no_debug = copy.deepcopy(self.level)
        no_debug["abilities_available"]["debug"] = False
        self.assertFalse(vl.validate(no_debug, check_schema=False)["ok"], "Sin el Debug no se cruza el filtro")

    def test_likes_thief_and_influencer(self):
        plats = {o["params"]["id"]: o["params"] for o in of_type(self.level, "like_platform")}
        self.assertEqual({i: p["threshold"] for i, p in plats.items()}, {"likes_10": 10, "likes_20": 20})
        self.assertTrue(all(p.get("one_way") for p in plats.values()), "De una via")
        self.assertEqual(len(of_type(self.level, "heart_pickup")), 15)
        self.assertEqual(len(of_type(self.level, "like_source")), 2, "2 publicaciones")
        likes = self.result["world3"]["likes"]
        used = {u["id"]: u for u in likes["used"]}
        self.assertEqual(sorted(used), ["likes_10"], "El camino solo pisa la ♥10")
        self.assertEqual((used["likes_10"]["sync"], used["likes_10"]["publication"]),
                         ("sync_1", "publicacion_ladron"), "Anti-atasco: la publicacion junto al Ladron")
        report = {e["id"]: e for e in self.result["world3"]["enemies"]}
        self.assertEqual((report["ladron_1"]["thefts"], report["ladron_1"]["stuns"]), (0, 1))
        self.assertEqual(report["influencer_1"]["blind"], [], "Ningun flash ciega (la columna-marco lo tapa)")
        self.assertLess(self.level["enemies"][0]["x"], obj(self.level, "likes_10")["x"], "Ladron antes de la ♥10")

    def test_secret_a_needs_the_debug(self):
        a = secret_item(self.result, "secreto_original")
        self.assertEqual((a["without_debug"], a["with_debug"]), (False, True), "Debug + Pellizcar")
        frame = obj(self.level, "marco_original")
        self.assertEqual((frame["x"], frame["y"]), (95, 11), "Marco del sotano bajo el suelo falso")
        self.assertIn([94, 10, 1, 1], obj(self.level, "filtro_orejitas")["params"]["fake_floor"])

    def test_secret_b_needs_twenty_likes(self):
        b = secret_item(self.result, "secreto_pose_sin_flash")
        self.assertTrue(b["reachable"])
        no_plat = copy.deepcopy(self.level)
        no_plat["objects"] = [o for o in no_plat["objects"] if o["params"].get("id") != "likes_20"]
        self.assertFalse(secret_item(vl.validate(no_plat, check_schema=False), "secreto_pose_sin_flash")["reachable"],
                         "Sin la ♥20 no se llega a la repisa")

    def test_secret_c_needs_the_air_dash(self):
        self.assertTrue(secret_item(self.result, "secreto_repisa")["reachable"])
        no_dash = copy.deepcopy(self.level)
        no_dash["abilities_available"]["dash"] = False
        without = vl.validate(no_dash, check_schema=False)
        self.assertFalse(secret_item(without, "secreto_repisa")["reachable"], "Sin el dash aereo no")
        self.assertEqual([e for e in without["errors"] if "secreto_repisa" not in e["message"]], [],
                         "El camino principal no necesita el dash")

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (10, 6, 4), "6 en la ruta + 4 en secretos")
        self.assertEqual(sorted(o["params"]["id"] for o in of_type(lvl, "charger")),
                         ["cargador_1", "cargador_2", "cargador_3"])
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertEqual(of_type(lvl, "extra_life_pickup"), [], "Sin vida extra")
        self.assertEqual(of_type(lvl, "memory_pickup"), [], "Sin mensaje propio (msg_3_2 esta en el 3-1)")
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 20.0, "Margen de energia")

    def test_exported_path(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "3-2"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("pinch", "unpinch", "heart", "pulse", "debug_on", "goal"):
            self.assertIn(action, actions)
        self.assertEqual(actions.count("pinch"), actions.count("unpinch"), "Recupera el tamano tras cada marco")
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_sin_filtro")])
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in path["steps"]))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_3_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m3 = next(w for w in hub["worlds"] if w["id"] == "m3")
        rows = {lv.get("id"): lv for lv in m3["levels"]}
        self.assertTrue(rows["3-2"]["playable"])
        self.assertEqual(rows["3-2"]["available_text"], "Nueva foto")
        self.assertTrue(rows["3-3"]["playable"], "El 3-3 ya es jugable (paso 13)")
        self.assertTrue(rows["3-boss"]["playable"], "La Curadora jugable desde el paso 17")
        with open(os.path.join(ROOT, "data", "levels", "3-1.json"), encoding="utf-8") as handle:
            self.assertEqual(json.load(handle)["unlocks"], [{"type": "level", "id": "3-2"}], "Lo desbloquea el 3-1")
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "3-2.tscn")))


if __name__ == "__main__":
    unittest.main()
