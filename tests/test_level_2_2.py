"""Nivel 2-2 «Un video más» (data/levels/2-2.json; paso 13 de docs/propuesta-mundo-2.md §8, diseno en §4.2 y
§4.2.1, 2026-10-23): esquema y alcanzabilidad sin avisos, estructura y tramos, el reproductor que da el golpe al
suelo al empezar (sin el, la meta no se alcanza), las puertas del golpe (fragiles de pie y del suelo), el enjambre con
Historias, el bucle con la salida por el Debug + golpe al suelo (tarjeta fragil oculta), las parejas de videos con
desfase, secretos (A bajo el nivel con msg_2_2, B el power bank, C en el pasillo de servicio), economia, cierre con la
cuenta automatica, camino exportado, escena y subidas al dia, y el 2-2 jugable desde la carpeta del Mundo 2.
Uso: python3 -m unittest tests/test_level_2_2.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "2-2.json")
H = 156


def row(h):
    """Fila del grid de la altura h (h 0 = suelo de la sala de inicio; h -6 a -1, bajo el nivel)."""
    return 149 - h


SECTIONS = [("Bajo el nivel", row(-1), row(-6)), ("Inicio «El reproductor»", row(13), row(0)),
            ("Tramo 1 «Romper para pasar»", row(39), row(14)), ("Tramo 2 «Enjambre»", row(61), row(40)),
            ("Pausa", row(65), row(62)), ("Tramo 3 «Uno más, otra vez»", row(99), row(66)),
            ("Tramo 4 «Autoplay»", row(139), row(100)), ("Cierre «Siguiente video»", 0, row(140))]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def enemy(level, eid):
    return next(e for e in level["enemies"] if e["id"] == eid)


def section_of(level, r):
    return next(s["name"] for s in level["sections"] if s["y_from"] <= r <= s["y_to"])


class Level22Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 2-2 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("2-2", "Un video más", 2, 3, 360))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (20, H), "Feed de 20 x 156 (§4.2)")
        self.assertEqual(lvl["camera"]["vertical"], "autoscroll")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": False},
                         "El golpe al suelo se obtiene en el reproductor")
        self.assertEqual([(s["name"], s["y_from"], s["y_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertTrue(all(r[0] == "#" and r[-1] == "#" for r in lvl["grid"]), "Columnas 0 y 19: el marco")
        start = next((c, r) for r, line in enumerate(lvl["grid"]) for c, ch in enumerate(line) if ch == "P")
        goal = next((c, r) for r, line in enumerate(lvl["grid"]) for c, ch in enumerate(line) if ch == "G")
        self.assertEqual(section_of(lvl, start[1]), "Inicio «El reproductor»")
        self.assertEqual(section_of(lvl, goal[1]), "Cierre «Siguiente video»")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "2-3"}])
        self.assertEqual([c["id"] for c in lvl["checkpoints"]], ["sync_1"], "Un punto de sincronizacion")
        self.assertEqual(section_of(lvl, lvl["checkpoints"][0]["y"]), "Pausa")

    def test_forced_scroll_accelerates_in_the_last_section(self):
        scroll = self.level["scroll"]
        speeds = {s["y_from"]: s["speed_tiles_s"] for s in scroll["stages"]}
        self.assertEqual((speeds[row(13)], speeds[row(39)], speeds[row(61)]), (0.5, 0.6, 0.5))
        self.assertEqual([speeds[row(114)], speeds[row(129)], speeds[0]], [0.7, 0.8, 0.9],
                         "Tramo 4: el scroll se acelera en tres pasos (h 100, 115, 130)")
        self.assertEqual([s["id"] for s in scroll["stops"]], ["sync_1"])
        info = self.result["plan"]["scroll"]
        self.assertGreaterEqual(info["margin_min_tiles"], 3.0, "Nunca a menos de 3 tiles del borde")
        self.assertEqual(info["loops"], ["bucle_uno_mas"])
        self.assertTrue(230.0 <= self.result["plan"]["duration_s"] <= 260.0,
                        "Camino de unos 230-260 s (§4.2): %.1f" % self.result["plan"]["duration_s"])

    def test_the_player_gives_the_ground_pound_at_the_start(self):
        player = obj(self.level, "reproductor_2_2")
        self.assertEqual((player["type"], player["params"]["ability"], player["params"]["story_line"]),
                         ("pause_player", "ground_pound", "pausa_2_2"))
        self.assertEqual(section_of(self.level, player["y"]), "Inicio «El reproductor»")
        steps = self.exported[0]["steps"]
        first_pound = next(i for i, s in enumerate(steps) if s["action"] == "ground_pound")
        pulse = next(i for i, s in enumerate(steps) if s["action"] == "pulse")
        self.assertLess(pulse, first_pound, "Primero el reproductor, luego el golpe")
        self.assertEqual((steps[pulse]["target"]["type"], steps[pulse]["face_back"]), ("pause_player", True))
        self.assertEqual(steps[first_pound]["breaks"], ["puerta_reproductor"], "El primer uso: la puerta de la sala")
        door = obj(self.level, "puerta_reproductor")
        self.assertEqual((door["x"], door["params"]["variant"]), (12, "upright"), "Fragil de pie en la columna 12")
        self.assertLessEqual(door["x"] - player["x"], 6, "Uso obligatorio a 6 tiles de la obtencion")
        # Sin el reproductor no hay golpe al suelo y la puerta de la sala no se abre.
        base = copy.deepcopy(self.level)
        base["objects"] = [o for o in base["objects"] if o["type"] != "pause_player"]
        self.assertFalse(vl.validate(base, check_schema=False)["ok"], "Sin el gesto no se sale de la sala de inicio")

    def test_ground_pound_doors_of_section_1(self):
        breaks = [b for s in self.exported[0]["steps"] if s["action"] == "ground_pound" for b in s["breaks"]]
        self.assertEqual(breaks, ["puerta_reproductor", "puerta_paso_1", "suelo_paso_2", "salida_oculta"])
        self.assertEqual(obj(self.level, "puerta_paso_1")["params"]["variant"], "upright")
        floor = obj(self.level, "suelo_paso_2")
        self.assertEqual(floor["params"]["trigger"], "pound_only", "Fragil del suelo que solo rompe el golpe")
        falls = [s for s in self.exported[0]["steps"] if s["action"] == "fall"
                 and s["from"]["cell"][1] == floor["y"] - 1]
        self.assertTrue(falls and all(f["to"]["cell"][1] - f["from"]["cell"][1] <= 3 for f in falls),
                        "Patron 10: caida de 3 tiles o menos")
        self.assertEqual(section_of(self.level, floor["y"]), "Tramo 1 «Romper para pasar»")
        self.assertEqual(section_of(self.level, enemy(self.level, "video_ola")["y"]), "Tramo 1 «Romper para pasar»")

    def test_swarm_with_story_cards(self):
        zones = {o["params"]["id"]: o for o in self.level["objects"] if o["type"] == "clone_zone"}
        self.assertEqual(sorted(zones), ["enjambre_1", "enjambre_2", "enjambre_repisa"])
        stories = [o for o in self.level["objects"] if o["type"] == "story_card"]
        self.assertEqual(len(stories), 2, "Una Historia que esperar en cada sala del enjambre")
        for zone_id, story in zip(("enjambre_1", "enjambre_2"), stories):
            c, r, w, h = zones[zone_id]["params"]["zone"]
            self.assertTrue(c <= story["x"] < c + w and r <= story["y"] < r + h, "La Historia, dentro de la zona")
            self.assertEqual(section_of(self.level, r), "Tramo 2 «Enjambre»")
        blinks = [b for b in self.result["plan"]["banners"] if b.get("blinks")]
        self.assertEqual(sorted(i for b in blinks for i in b["blinks"]), ["historia_1", "historia_2"])
        clones = {c["id"]: c for c in self.result["plan"]["clones"]}
        self.assertGreater(clones["enjambre_2"]["spawned"], 0, "Quedarse a esperar hace nacer clones")
        self.assertEqual(section_of(self.level, obj(self.level, "cargador_1")["y"]), "Tramo 2 «Enjambre»")

    def test_no_scroll_wait_on_a_story_card(self):
        """Paso 13: de pie sobre una Historia esta se apaga (1,6 s de 3,2): las esperas del scroll del tramo con
        tiempo van antes de el, nunca encima de la Historia ni en medio del cruce."""
        cells = set()
        for o in self.level["objects"]:
            if o["type"] == "story_card":
                cells.update((o["x"] + dx, o["y"]) for dx in range(o["params"]["width_tiles"]))
        waits = [s for s in self.exported[0]["steps"] if s["action"] in ("wait_scroll", "wait")]
        self.assertEqual([s["at"]["cell"] for s in waits if (s["at"]["cell"][0], s["at"]["cell"][1] + 1) in cells],
                         [])
        self.assertIn("el scroll sube (antes del tramo con tiempo)", [s.get("reason") for s in waits])

    def test_loop_exit_needs_the_debug_and_the_ground_pound(self):
        loop = obj(self.level, "bucle_uno_mas")
        band = loop["params"]["band"]
        self.assertEqual(band[1] - band[0], 20, "Bucle largo (periodo 20)")
        card = obj(self.level, "salida_oculta")
        self.assertEqual((card["params"]["hidden"], card["params"]["trigger"], card["x"], card["params"]["width_tiles"]),
                         (True, "pound_only", 8, 3), "Fragil oculta en el suelo de la banda (columnas 8-10)")
        self.assertTrue(band[0] <= card["y"] <= band[1])
        self.assertEqual(card["y"], row(86))
        self.assertFalse(self.result["requirements"]["goal_without_debug"], "Sin el Debug no se sale del bucle")
        steps = self.exported[0]["steps"]
        pound = next(s for s in steps if s["action"] == "ground_pound" and s["breaks"] == ["salida_oculta"])
        self.assertTrue(pound["debug"], "El golpe a la oculta, con el Debug activo")
        on = max(i for i, s in enumerate(steps) if s["action"] == "debug_on" and i < steps.index(pound))
        self.assertEqual(steps[on]["target"]["id"], "salida_oculta")
        ex = loop["params"]["exit"]
        self.assertEqual((ex[0], ex[2]), (1, 3), "Pasillo de servicio por la izquierda")
        for eid in ("video_rayo_bucle_1", "video_rayo_bucle_2", "comentarista"):
            self.assertEqual(section_of(self.level, enemy(self.level, eid)["y"]), "Tramo 3 «Uno más, otra vez»")
        self.assertEqual(enemy(self.level, "comentarista")["type"], "commenter")
        sync = self.level["checkpoints"][0]
        self.assertEqual(obj(self.level, "cargador_2")["y"], sync["y"], "cargador_2 junto a sync_1")

    def test_video_pairs_enter_together_with_offset_clips(self):
        for left, right in (("video_par_1_izq", "video_par_1_der"), ("video_par_2_izq", "video_par_2_der")):
            a, b = enemy(self.level, left), enemy(self.level, right)
            self.assertEqual(a["y"], b["y"], "Entran a la vez en la vista")
            self.assertEqual(a["params"]["clip"], b["params"]["clip"], "Mismo clip (el plan las desfasa bien)")
            offset = abs(b["params"].get("start_delay_s", 0.0) - a["params"].get("start_delay_s", 0.0))
            self.assertGreaterEqual(offset, 0.5, "Clips desfasados 0,5 s o mas")
            self.assertEqual(section_of(self.level, a["y"]), "Tramo 4 «Autoplay»")
        feeds = sorted(i for bn in self.result["plan"]["banners"] for i in bn.get("feed", []))
        self.assertIn("video_par_2_izq", feeds)
        self.assertIn("video_par_2_der", feeds)
        self.assertEqual(section_of(self.level, obj(self.level, "cargador_3")["y"]), "Tramo 4 «Autoplay»")

    def test_secret_a_under_the_level_gives_msg_2_2(self):
        secret = next(s for s in self.level["secrets"] if s["id"] == "secreto_bajo_el_nivel")
        self.assertEqual((secret["points"], secret["memory_id"], secret["gates"]), (2, "msg_2_2", ["grieta_bajo_el_nivel"]))
        self.assertEqual(section_of(self.level, secret["y"]), "Bajo el nivel")
        crack = obj(self.level, "grieta_bajo_el_nivel")
        self.assertEqual((crack["y"], crack["params"]["trigger"]), (row(0), "pound_only"),
                         "Una tarjeta del suelo de la sala de inicio")
        pickup = obj(self.level, "mensaje_2_2")
        self.assertEqual((pickup["x"], pickup["y"]), (secret["x"], secret["y"]))
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertTrue(items["secreto_bajo_el_nivel"]["reachable"])
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_2_2")
        self.assertEqual((memory["reachable_without_debug"], memory["mandatory"]), (True, False))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            msg = next(m for m in json.load(handle)["memories"] if m["id"] == "msg_2_2")
        self.assertEqual((msg["sender"], msg["level"], msg["secret"], msg["first_lap"], msg["subject"]),
                         ("Mamá", "2-2", "secreto_bajo_el_nivel", 1, "Tu taza"))
        self.assertNotIn("grieta_bajo_el_nivel",
                         [b for s in self.exported[0]["steps"] if s["action"] == "ground_pound" for b in s["breaks"]],
                         "El camino no rompe la tarjeta del secreto")
        # Sin el golpe (sin el reproductor), el secreto no se alcanza.
        base = copy.deepcopy(self.level)
        base["objects"] = [o for o in base["objects"] if o["type"] != "pause_player"]
        items = {i["id"]: i for i in vl.validate(base, check_schema=False)["secrets"]["items"]}
        self.assertFalse(items["secreto_bajo_el_nivel"]["reachable"])

    def test_secrets_b_and_c(self):
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertTrue(items["secreto_repisa_enjambre"]["reachable"])
        self.assertTrue(items["secreto_servicio"]["reachable"])
        bank = obj(self.level, "power_bank_2_2")
        zone = obj(self.level, "enjambre_repisa")["params"]["zone"]
        self.assertTrue(zone[0] <= bank["x"] < zone[0] + zone[2] and zone[1] <= bank["y"] < zone[1] + zone[3],
                        "El power bank, dentro de la zona de clones de la repisa")
        door = obj(self.level, "puerta_servicio")
        self.assertEqual(door["params"]["variant"], "upright")
        self.assertIn("pound:puerta_servicio", items["secreto_servicio"]["secret_gates_opened"])

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (9, 6, 3),
                         "9 puntos: 6 en la ruta + 3 en secretos (§4.2.1)")
        chargers = sorted(o["params"]["id"] for o in lvl["objects"] if o["type"] == "charger")
        self.assertEqual(chargers, ["cargador_1", "cargador_2", "cargador_3"])
        self.assertEqual(len([o for o in lvl["objects"] if o["type"] == "power_bank_pickup"]), 1, "1 power bank")
        self.assertFalse([o for o in lvl["objects"] if o["type"] == "extra_life_pickup"], "Sin vida extra")
        self.assertGreater(self.result["plan"]["energy"]["min"], 0.0)

    def test_closing_card_counts_down_and_leaves_alone(self):
        terminal = obj(self.level, "terminal_siguiente_video")
        self.assertEqual((terminal["params"]["countdown_s"], terminal["help_id"]), (3.0, ""))
        self.assertEqual(self.result["exit_terminals"],
                         [{"id": "terminal_siguiente_video", "pulse_from": None, "countdown_s": 3.0}])
        texts = [o["params"]["text"] for o in self.level["objects"] if o["type"] == "feed_sign"]
        self.assertFalse([t for t in texts if "vuelta" in t.lower()], "La UI nunca dice «vuelta»")

    def test_exported_path(self):
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "2-2"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("wait_scroll", "wait_phase", "wait_beat", "ground_pound", "debug_on", "debug_off", "goal"):
            self.assertIn(action, actions)
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("wait", "terminal_siguiente_video")])
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in path["steps"]))

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
        self.assertEqual(rows[:2], [("2-1", "Para ti", True), ("2-2", "Un video más", True)])
        self.assertEqual(m2["levels"][1].get("available_text"), "Siguiente video", "§4.6: tras el 2-1")
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "2-2.tscn")))


if __name__ == "__main__":
    unittest.main()
