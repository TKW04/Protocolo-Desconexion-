"""Nivel 4-2 «Grupo sin respuesta» (data/levels/4-2.json; paso 13 de docs/propuesta-mundo-4.md §8, 2026-10-28):
esquema y alcanzabilidad sin avisos, nivel horizontal de 260 x 14 en bandas (cada tramo se recorre en tres pasadas:
suelo, banda de la fila 9 y banda de la fila 6, que suben o bajan alternando), inicio «Mensajes borrados» con la
Papelera, el «¿Deshacer escritura?» que deshace el muro de texto a 8 tiles, los grupos de Trolls que se
aturden con el pulso (patron 20; sin Agitar desde el 2026-10-28), los Fantasmas, el autocorrector junto a las zonas
«Visto», los enjambres de Stickers que el pulso desinfla, los secretos (A con Pellizcar y la Linterna, B con el autocorrector al reves, C con «escribiendo…» y el
dash aereo), economia, camino exportado y su duracion frente al objetivo (40-55 %), escena y subidas al dia, y el
4-2 jugable desde la carpeta del Mundo 4. Las pasadas con mejoras, con todo al maximo y con el tope del acceso las
hace tools/run_tests.sh sobre data/levels/*.json.
Uso: python3 tests/test_level_4_2.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "4-2.json")
SECTIONS = [("Inicio «Mensajes borrados»", 0, 24), ("Tramo 1 «Grupo»", 25, 80), ("Tramo 2 «Fantasmas»", 81, 130),
            ("Pausa", 131, 135), ("Tramo 3 «Autocorrector»", 136, 195), ("Tramo 4 «Stickers»", 196, 250),
            ("Cierre «Salir del chat»", 251, 259)]


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


def variant(level, change):
    out = copy.deepcopy(level)
    change(out)
    return vl.validate(out, check_schema=False)


class Level42Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 4-2 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("4-2", "Grupo sin respuesta", 4, 4, 480))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (260, 14), "Horizontal de 260 x 14 (§4.2)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["debug_color"], "coral")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": True}, "Todo el kit (sin Agitar, retirado el 2026-10-28)")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        start = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "P")
        goal = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "G")
        self.assertEqual(start, (3, 11), "Vortice en (3, 11) (doc)")
        self.assertEqual(section_of(lvl, goal[0]), "Cierre «Salir del chat»")
        terminal = obj(lvl, "terminal_salir")
        self.assertEqual((terminal["type"], terminal["x"], terminal["y"], terminal["params"]["text"]),
                         ("exit_terminal", goal[0], goal[1] - 1, "Salir del chat"))
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "4-3"}])
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}, {"sync_1": (133, 11)})
        self.assertEqual(section_of(lvl, 133), "Pausa")

    def test_bands_force_three_passes(self):
        """Decision del paso 13: cada tramo se recorre en tres pasadas (no hay atajo entre bandas)."""
        walked = sum(abs(s["to"]["cell"][0] - s["from"]["cell"][0]) for s in self.exported[0]["steps"]
                     if s["action"] == "walk")
        self.assertGreater(walked, 2 * 260, "Tiles andados en horizontal: %d" % walked)
        rows = {s["to"]["cell"][1] for s in self.exported[0]["steps"] if s["action"] == "walk"}
        self.assertTrue({11, 8, 5} <= rows, "Pasa por el suelo y por las dos bandas: %s" % sorted(rows))

    def test_start_room_prompt_undoes_the_wall(self):
        lvl = self.level
        papelera = obj(lvl, "papelera_4_2")
        self.assertEqual((papelera["type"], papelera["x"], papelera["params"]["story"]), ("papelera_actor", 5, "papelera_4_2"))
        prompt = obj(lvl, "deshacer_4_2")
        self.assertEqual((prompt["type"], prompt["x"], prompt["params"]["story_line"]),
                         ("undo_prompt", 14, "deshacer_4_2"))
        self.assertNotIn("ability", prompt["params"], "Ya no da ninguna habilidad")
        wall = obj(lvl, "muro_4_2")
        self.assertEqual((wall["type"], wall["x"]), ("typed_wall", 22))
        self.assertEqual(wall["x"] - prompt["x"], 8, "El muro, a 8 tiles del panel que lo deshace")
        self.assertTrue(all(lvl["grid"][r][22] == "#" for r in range(1, 9)), "Sobre el muro, pared hasta el techo")
        deleted = [o for o in of_type(lvl, "chat_bubble") if o["params"].get("deleted") and o["x"] < 22]
        self.assertGreaterEqual(len(deleted), 3, "Sala llena de «Se eliminó este mensaje»")
        steps = self.exported[0]["steps"]
        self.assertNotIn("shake", [s["action"] for s in steps], "Sin Agitar en el camino")
        dnd = next(i for i, s in enumerate(steps) if s["action"] == "pulse" and s["target"]["type"] == "dnd_switch")
        wall_step = next(i for i, s in enumerate(steps) if s.get("target", {}).get("id") == "muro_4_2")
        self.assertLess(dnd, wall_step, "Primero el panel, despues se pasa el muro deshecho")
        self.assertEqual(steps[wall_step]["action"], "wait", "Solo espera su borrado si llega a la vez")
        no_prompt = variant(lvl, lambda l: l.__setitem__("objects", [o for o in l["objects"] if o["type"] != "undo_prompt"]))
        self.assertFalse(no_prompt["ok"], "Sin el «¿Deshacer escritura?» el muro no se cruza")

    def test_troll_groups_fall_to_pulses(self):
        enemies = [e for e in self.level["enemies"] if e["type"] == "troll"]
        groups = {}
        for e in enemies:
            if e["id"].startswith("troll_grupo_"):
                groups.setdefault(e["id"][len("troll_grupo_")], []).append(e)
        self.assertEqual(sorted(groups), ["1", "2", "3"], "Tres grupos en el Tramo 1")
        for name, members in groups.items():
            self.assertEqual(len({m["x"] for m in members}), 1, "Grupo %s apilado en una columna" % name)
            self.assertEqual(len({m["y"] for m in members}), len(members), "a distintas alturas")
            self.assertTrue(all(section_of(self.level, m["x"]) == "Tramo 1 «Grupo»" for m in members))
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        for name, members in groups.items():
            used = [report[m["id"]]["with"] for m in members if m["id"] in report]
            self.assertTrue(used, "Grupo %s: el camino aturde a los de su linea" % name)
            self.assertTrue(all(w == "pulse" for w in used), "Con el pulso (sin Agitar): %s" % used)

    def test_ghosts_in_tramo_2(self):
        ghosts = [e for e in self.level["enemies"] if e["type"] == "ghost"]
        self.assertEqual(len(ghosts), 6)
        self.assertTrue(all(section_of(self.level, g["x"]) == "Tramo 2 «Fantasmas»" for g in ghosts))
        self.assertEqual({g["y"] for g in ghosts}, {5, 8, 11}, "En las tres pasadas (la de la fila 8, bajo B3)")
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        for g in ghosts:
            self.assertEqual(report[g["id"]]["with"], "pulse")
            self.assertAlmostEqual(report[g["id"]]["wait_s"], 2.05)
        charger = obj(self.level, "cargador_1")
        self.assertEqual(section_of(self.level, charger["x"]), "Tramo 2 «Fantasmas»")

    def test_autocorrector_and_seen_zones_in_tramo_3(self):
        lvl = self.level
        zones = {o["params"]["id"]: o for o in of_type(lvl, "seen_zone")}
        self.assertTrue(all(section_of(lvl, z["x"]) == "Tramo 3 «Autocorrector»" for z in zones.values()))
        info = {z["id"]: z for z in self.result["world4"]["zones"]}
        self.assertIn("pulse_from", info["visto_suelo"])
        self.assertIn("pulse_from", info["visto_aire"], "Patron 19: pulso al check y pasar")
        cycles = [z for z in zones.values() if "on_s" in z["params"]]
        self.assertEqual(len(cycles), 4)
        auto = obj(lvl, "autocorrector_1")
        air = zones["visto_aire"]
        self.assertEqual(auto["y"], 9)
        self.assertTrue(air["x"] <= auto["x"] < air["x"] + air["params"]["width_tiles"],
                        "La zona en el aire, justo donde el autocorrector deja el hueco")
        waits = [a["id"] for a in self.result["world4"]["autocorrect_waits"]]
        self.assertIn("autocorrector_1", waits, "El camino espera el cursor")
        troll = next(e for e in lvl["enemies"] if e["id"] == "troll_visto")
        zone = zones["visto_suelo"]
        self.assertEqual(troll["y"], zone["y"] + zone["params"]["height_tiles"] - 1, "El Troll, a la altura de la zona")
        self.assertGreaterEqual(troll["x"] - zone["x"], 6, "Lejos de la zona: no alcanza a Isak congelado (§3.3)")
        self.assertNotIn("shake", self.result["world4"], "Sin Agitar")

    def test_sticker_swarms_in_tramo_4(self):
        # Los acechadores del Modo oscuro del Tramo 2 (2026-10-28) van aparte (test_lurkers_in_the_dark_tramo_2).
        stickers = [e for e in self.level["enemies"] if e["type"] == "sticker" and not e.get("params", {}).get("lurk")]
        self.assertEqual(len(stickers), 12)
        self.assertTrue(all(section_of(self.level, s["x"]) == "Tramo 4 «Stickers»" for s in stickers))
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        engaged = [s for s in stickers if s["id"] in report]
        self.assertGreaterEqual(len(engaged), 11, "El camino desinfla a los que despierta")
        self.assertTrue(all(report[s["id"]]["with"] == "pulse" for s in engaged), "El pulso los desinfla")
        landing = [s for s in stickers if s["y"] == 8 and s["x"] <= 240]
        self.assertEqual(len(landing), 3, "Tres alrededor de la llegada a B2")
        self.assertEqual(len({tuple(report[s["id"]]["at"]) for s in landing}), 1, "La tanda de B2, de un pulso")
        self.assertEqual(report["troll_stickers"]["type"], "troll")

    def test_lurkers_in_the_dark_tramo_2(self):
        """Peligros ocultos del Modo oscuro (2026-10-28, docs/propuesta-mundo-4.md §8.1): zona oscura nueva en el
        camino del Tramo 2 (columnas 94-104) con un Troll y dos Stickers que acechan; el camino los aturde o
        desinfla a todos con el pulso."""
        zones = {o["params"]["id"]: o for o in self.level["objects"] if o["type"] == "dark_zone"}
        self.assertEqual(sorted(zones), ["grupo_a_oscuras", "silenciado_oscuro"])
        z = zones["grupo_a_oscuras"]
        self.assertEqual((z["x"], z["y"], z["params"]["width_tiles"], z["params"]["height_tiles"]), (94, 1, 11, 11))
        lurkers = {e["id"]: e for e in self.level["enemies"] if e.get("params", {}).get("lurk")}
        self.assertEqual(sorted(lurkers), ["acechador_banda_media", "acechador_suelo", "acechador_troll_t2"])
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        for eid, e in lurkers.items():
            self.assertEqual(section_of(self.level, e["x"]), "Tramo 2 «Fantasmas»", eid)
            self.assertEqual(e["help_id"], "lurker", eid)
            self.assertEqual(report[eid]["with"], "pulse", eid)

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (10, 6, 4), "6 en la ruta + 4 (§4.2.1)")
        route_cols = sorted(c for row in lvl["grid"] for c, ch in enumerate(row) if ch == "o")
        sections = [section_of(lvl, c) for c in route_cols]
        for name, _, _ in SECTIONS:
            if name != "Pausa":
                self.assertIn(name, sections, "Un punto en %s" % name)
        chargers = of_type(lvl, "charger")
        self.assertEqual(sorted(c["params"]["id"] for c in chargers), ["cargador_1", "cargador_2", "cargador_3"])
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertEqual(of_type(lvl, "extra_life_pickup"), [], "Sin vida extra (doc)")
        self.assertEqual([o["params"]["memory_id"] for o in of_type(lvl, "memory_pickup")], ["msg_4_2"])
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 30.0)

    def test_secret_a_muted_needs_compress_and_the_flashlight(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_silenciado")
        self.assertEqual((a["memory_id"], a["points"], a["forbid_abilities"]), ("msg_4_2", 2, ["dash"]))
        frame = obj(self.level, "marco_silenciado")
        self.assertEqual((frame["type"], frame["params"]["orientation"]), ("small_frame", "wall"))
        self.assertTrue(obj(self.level, "garaje_silenciado")["params"]["deleted"], "Parece decorado")
        self.assertTrue(secret_item(self.result, "secreto_silenciado")["reachable"])
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_4_2")
        self.assertFalse(memory["mandatory"])
        no_lamp = variant(self.level, lambda l: l.__setitem__(
            "objects", [o for o in l["objects"] if o["type"] != "flashlight_pickup"]))
        self.assertFalse(secret_item(no_lamp, "secreto_silenciado")["reachable"], "Sin la Linterna no se cruza")

        def no_pinch(l):
            l["abilities_available"]["compress"] = False
        self.assertFalse(secret_item(variant(self.level, no_pinch), "secreto_silenciado")["reachable"],
                         "Sin Pellizcar no se entra")

    def test_secret_b_autocorrect_in_reverse(self):
        b = next(s for s in self.level["secrets"] if s["id"] == "secreto_ok_y_tu")
        self.assertEqual((b["object"], b["points"]), ("power_bank_pickup", 1))
        auto = obj(self.level, "ok_y_tu")["params"]
        self.assertEqual((auto["text"], auto["corrected"]), ("ok", "ok, ¿y tú qué tal? cuéntame"))
        self.assertTrue(secret_item(self.result, "secreto_ok_y_tu")["reachable"])

        def short(l):
            for o in l["objects"]:
                if o["params"].get("id") == "ok_y_tu":
                    o["params"]["corrected"] = "ok"
        self.assertFalse(secret_item(variant(self.level, short), "secreto_ok_y_tu")["reachable"],
                         "Sin el puente que crece no se llega")

    def test_secret_c_high_bubble_needs_typing_and_air_dash(self):
        self.assertTrue(secret_item(self.result, "secreto_burbuja_alta")["reachable"])

        def no_typing(l):
            l["objects"] = [o for o in l["objects"] if o["params"].get("id") != "escribiendo_c"]
        self.assertFalse(secret_item(variant(self.level, no_typing), "secreto_burbuja_alta")["reachable"])

        def no_dash(l):
            l["abilities_available"]["dash"] = False
        self.assertFalse(secret_item(variant(self.level, no_dash), "secreto_burbuja_alta")["reachable"])

    def test_exported_path_and_duration(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "4-2"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("walk", "jump", "fall", "pulse", "pulse_seen", "wait_typing", "wait_autocorrect",
                       "wait_ghost", "wait", "goal"):
            self.assertIn(action, actions)
        self.assertNotIn("shake", actions, "Sin Agitar (retirado el 2026-10-28)")
        self.assertEqual(actions.count("wait_ghost"), 6)
        self.assertNotIn("pinch", actions, "El camino no va comprimido (pozos de 1 columna)")
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_salir")])
        seconds = self.result["plan"]["duration_s"]
        target = self.level["target_duration_s"]
        self.assertTrue(0.40 * target <= seconds <= 0.55 * target,
                        "Camino del validador entre el 40 y el 55 %% del objetivo: %.1f s de %d" % (seconds, target))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_4_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m4 = next(w for w in hub["worlds"] if w["id"] == "m4")
        rows = [(lv["id"], lv["playable"]) for lv in m4["levels"]]
        self.assertEqual(rows, [("4-1", True), ("4-2", True), ("4-3", True), ("4-boss", True)])
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "4-2.tscn")))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_4_2"]
        self.assertEqual((msg["level"], msg["secret"], msg["sender"], msg["world"], msg["first_lap"]),
                         ("4-2", "secreto_silenciado", "Marco", 4, 1))


if __name__ == "__main__":
    unittest.main()
