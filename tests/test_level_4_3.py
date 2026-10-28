"""Nivel 4-3 «Mensajes sin leer» (data/levels/4-3.json; paso 14 de docs/propuesta-mundo-4.md §8, 2026-10-28):
esquema y alcanzabilidad sin avisos, nivel horizontal de 300 x 14 con la ola de «Visto» a la espalda (arranca al
cruzar la columna 20, 1,0 / 1,2 / 1,2 -> 1,6 tiles/s, paradas en los dos puntos de sincronizacion, se apaga a 6
tiles del cierre) y el camino del validador siempre a 3 tiles o mas de ella; Tramo 1 sin enemigos y Tramo 2 en
bandas (tres pasadas por bloque), Trolls disfrazados de Marco (el Debug los distingue) y Fantasmas, Tramo 3 recto
con huecos que crecen y Modo oscuro, los secretos (A con el Debug y sin dash en la parada de sync_1, B en tinta con
la Linterna, C dentro de una zona «Visto» en el aire), economia, el cierre segun V15 (la puerta «Responder más
tarde» con «Sin conexión»: Isak sale sin responder), camino exportado y su duracion frente al objetivo (40-55 %),
escena y subidas al dia, y el 4-3 jugable desde la carpeta del Mundo 4 con la fila del jefe desbloqueada.
Uso: python3 tests/test_level_4_3.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "4-3.json")
SECTIONS = [("Inicio «Sin leer (37)»", 0, 20), ("Tramo 1 «Recientes»", 21, 100), ("Pausa 1", 101, 108),
            ("Tramo 2 «Voces»", 109, 200), ("Pausa 2", 201, 206), ("Tramo 3 «Cada vez más lejos»", 207, 285),
            ("Cierre «Tomi»", 286, 299)]


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


class Level43Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 4-3 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("4-3", "Mensajes sin leer", 4, 5, 480))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (300, 14), "Horizontal de 300 x 14 (§4.3)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertNotIn("shockwave", lvl["abilities_available"], "Todo el kit, sin Agitar (retirado el 2026-10-28)")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "4-boss"}], "Desbloquea la fila del jefe")
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]},
                         {"sync_1": (104, 11), "sync_2": (203, 11)})
        self.assertEqual(section_of(lvl, 104), "Pausa 1")
        self.assertEqual(section_of(lvl, 203), "Pausa 2")

    def test_seen_wave_behind_isak(self):
        waves = of_type(self.level, "seen_wave")
        self.assertEqual(len(waves), 1)
        p = waves[0]["params"]
        self.assertEqual((p["start_col"], p["end_col"]), (20, 280), "Arranca al cruzar la 20 y se apaga a 6 del cierre")
        speeds = [(s["speed_tiles_s"], s.get("speed_to_tiles_s")) for s in p["sections"]]
        self.assertEqual(speeds, [(1.25, None), (1.45, None), (1.45, 1.95)],
                         "Un 20-25 %% mas rapida que el doc (1,0 / 1,2 / 1,2 -> 1,6): prueba del usuario del 2026-10-28")
        stops = {s["id"]: s for s in p["stops"]}
        self.assertEqual(sorted(stops), ["parada_sync_1", "parada_sync_2", "parada_vuelta_1", "parada_vuelta_2",
                                         "parada_vuelta_3"], "Y paradas en las vueltas de las bandas")
        self.assertLess(stops["parada_sync_1"]["at_col"], 101, "La ola espera antes de la Pausa 1 (secreto A)")
        info = self.result["world4"]["wave"]
        self.assertGreaterEqual(info["closest_tiles"], 3.0, "El camino nunca queda a menos de 3 tiles de la ola")
        self.assertEqual(sorted(info["stops_passed"]), sorted(stops))

        def slow(l):
            for o in l["objects"]:
                if o["type"] == "seen_wave":
                    o["params"]["start_col"] = 4
                    o["params"]["sections"][0]["speed_tiles_s"] = 2.0
        caught = variant(self.level, slow)
        self.assertTrue(any("ola" in e["message"] for e in caught["errors"]), "Mas rapida, la ola alcanza al camino")

    def test_tramo_1_has_no_enemies(self):
        t1 = [e for e in self.level["enemies"] if section_of(self.level, e["x"]) == "Tramo 1 «Recientes»"]
        self.assertEqual(t1, [], "Sin enemigos (doc)")
        lia = obj(self.level, "lia_2_dias")["params"]
        self.assertEqual((lia["friend"], lia["text"]), ("lia", "¿Estás bien? Hace días que no contestas."))
        typing = [o for o in of_type(self.level, "typing_bubble") if section_of(self.level, o["x"]) == "Tramo 1 «Recientes»"]
        self.assertEqual(len(typing), 2, "Dos «escribiendo…»")
        zone = obj(self.level, "visto_espalda")
        self.assertNotIn("on_s", zone["params"], "Zona obligatoria (patron 22)")
        info = {z["id"]: z for z in self.result["world4"]["zones"]}
        self.assertIn("pulse_from", info["visto_espalda"])

    def test_tramo_2_voices(self):
        lvl = self.level
        mimics = [e for e in lvl["enemies"] if e["type"] == "troll_mimic"]
        self.assertEqual(len(mimics), 3)
        self.assertTrue(all(e["params"]["friend"] == "marco" for e in mimics), "Burbujas «de Marco»")
        self.assertTrue(all(section_of(lvl, e["x"]) == "Tramo 2 «Voces»" for e in mimics))
        near = {m["id"]: m["near_path"] for m in self.result["world4"]["mimics"]}
        self.assertTrue(all(near.values()), "Junto al camino: el Debug los distingue")
        self.assertTrue(lvl["abilities_available"]["debug"])
        real = obj(lvl, "marco_torneo")["params"]
        self.assertEqual((real["friend"], real["text"]), ("marco", "Te guardé un lugar para el torneo."))
        ghosts = [e for e in lvl["enemies"] if e["type"] == "ghost"]
        self.assertEqual(len(ghosts), 6)
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        self.assertTrue(all(report[g["id"]]["with"] == "pulse" for g in ghosts))
        self.assertEqual(section_of(lvl, obj(lvl, "cargador_2")["x"]), "Tramo 2 «Voces»")

    def test_tramo_3_gaps_grow_in_the_dark(self):
        lvl = self.level
        grid = lvl["grid"]
        gaps = []
        c = 207
        while c <= 285:
            if grid[9][c] == "." and grid[8][c] == ".":
                start = c
                while c <= 285 and grid[9][c] == ".":
                    c += 1
                gaps.append(c - start)
            else:
                c += 1
        self.assertEqual(gaps, sorted(gaps), "Los huecos crecen hacia la derecha: %s" % gaps)
        self.assertEqual(gaps[0], 2)
        self.assertGreaterEqual(gaps[-1], 4)
        dark = obj(lvl, "madrugada")
        self.assertEqual(section_of(lvl, dark["x"]), "Tramo 3 «Cada vez más lejos»", "Modo oscuro en la segunda mitad")
        self.assertGreater(dark["x"], 246)
        chain = [o for o in of_type(lvl, "typing_bubble") if o["x"] > 270]
        self.assertEqual(len(chain), 2, "«hace 3 meses»: dos «escribiendo…» encadenadas")
        self.assertTrue(self.result["world4"]["dark"]["flashlight"])

    def test_lurkers_in_the_dark_of_tramo_3(self):
        """Peligros ocultos del Modo oscuro (2026-10-28, docs/propuesta-mundo-4.md §8.1): en la madrugada, un Troll
        que acecha en la repisa de las «escribiendo…» y un Sticker en la ultima repisa; el camino los aturde o
        desinfla con el pulso al aterrizar y la ola no alcanza a Isak."""
        lurkers = {e["id"]: e for e in self.level["enemies"] if e.get("params", {}).get("lurk")}
        self.assertEqual({k: (e["type"], e["x"], e["y"]) for k, e in lurkers.items()},
                         {"acechador_troll_t3": ("troll", 275, 8), "acechador_sticker_t3": ("sticker", 285, 8)})
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        for eid, e in lurkers.items():
            self.assertEqual(section_of(self.level, e["x"]), "Tramo 3 «Cada vez más lejos»", eid)
            self.assertEqual(report[eid]["with"], "pulse", eid)
            self.assertTrue(report[eid].get("lurk"), eid)

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (9, 6, 3), "6 en la ruta + 3 (§4.3.1)")
        self.assertEqual(sorted(c["params"]["id"] for c in of_type(lvl, "charger")),
                         ["cargador_1", "cargador_2", "cargador_3"])
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertEqual(of_type(lvl, "extra_life_pickup"), [])
        self.assertEqual([o["params"]["memory_id"] for o in of_type(lvl, "memory_pickup")], ["msg_4_3"])

    def test_secret_a_full_conversation_needs_the_debug_without_dash(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_conversacion")
        self.assertEqual((a["memory_id"], a["points"], a["needs_debug"], a["forbid_abilities"]),
                         ("msg_4_3", 2, True, ["dash"]))
        hidden = [c for r, row in enumerate(self.level["grid"]) for c, ch in enumerate(row) if ch == "h"]
        self.assertTrue(hidden and section_of(self.level, min(hidden)) == "Pausa 1",
                        "La escalera oculta sube desde la parada de sync_1")
        wall = obj(self.level, "pared_conversacion")
        self.assertTrue(wall["params"]["visible_only_with_debug"])
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_4_3")
        self.assertEqual((memory["reachable_without_debug"], memory["reachable_with_debug"], memory["mandatory"]),
                         (False, True, False))

    def test_secret_b_draft_needs_the_flashlight(self):
        self.assertTrue(secret_item(self.result, "secreto_borrador")["reachable"])
        ink = obj(self.level, "borrador_texto")["params"]
        self.assertIn("perdón por no", ink["text"])
        no_lamp = variant(self.level, lambda l: l.__setitem__(
            "objects", [o for o in l["objects"] if o["type"] != "flashlight_pickup"]))
        self.assertFalse(secret_item(no_lamp, "secreto_borrador")["reachable"], "Sin la Linterna no hay paso")

    def test_secret_c_inside_an_air_zone(self):
        self.assertTrue(secret_item(self.result, "secreto_visto_alto")["reachable"])
        zone = obj(self.level, "visto_alto")
        bubble = obj(self.level, "tres_meses_alta")
        self.assertEqual(zone["y"] + zone["params"]["height_tiles"], bubble["y"], "La zona cubre la burbuja alta")
        self.assertNotIn("on_s", zone["params"], "Siempre activa")
        self.assertEqual(zone["params"]["icon"], "right", "Su check, junto a «hace 2 semanas»: el pulso llega desde alli")
        self.assertEqual(obj(self.level, "sello_0")["x"], zone["x"] + zone["params"]["width_tiles"])

    def test_closing_v15_reply_later_without_connection(self):
        terminal = obj(self.level, "terminal_responder")["params"]
        self.assertEqual((terminal["text"], terminal["skin"], terminal["offline_text"]),
                         ("Responder más tarde", "chat_reply", "Sin conexión"))
        tomi = obj(self.level, "tomi_ultima")["params"]
        self.assertEqual((tomi["friend"], tomi["text"]), ("tomi", "Ok, cuando quieras hablar, aquí estoy."))
        end = next(o for o in of_type(self.level, "seen_wave"))["params"]["end_col"]
        self.assertEqual(286 - end, 6, "La ola se para a 6 tiles del cierre")

    def test_exported_path_and_duration(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "4-3"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("walk", "jump", "fall", "dash", "pulse", "pulse_seen", "wait_typing", "wait_ghost", "wait",
                       "goal"):
            self.assertIn(action, actions)
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_responder")])
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
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "4-3.tscn")))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_4_3"]
        self.assertEqual((msg["level"], msg["secret"], msg["sender"], msg["world"], msg["first_lap"]),
                         ("4-3", "secreto_conversacion", "Lía", 4, 1))


if __name__ == "__main__":
    unittest.main()
