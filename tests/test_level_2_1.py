"""Nivel 2-1 «Para ti» (data/levels/2-1.json; paso 11 de docs/propuesta-mundo-2.md §8, diseno en §4.1 y
§4.1.1, 2026-10-22): esquema y alcanzabilidad sin avisos, estructura y tramos, scroll forzado (arranque,
tramos, parada en sync_1), videos en autoplay, bucle con la salida por el Debug, tarjetas fragiles y zona de
clones sin golpe al suelo, secretos (A con el Debug y sin el dash y msg_2_1; B, la vida extra, tras la pared
con glitch; C), economia, cierre con la cuenta automatica, camino exportado, escena y subidas al dia, y el
2-1 jugable desde la carpeta del Mundo 2.
Uso: python3 -m unittest tests/test_level_2_1.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "2-1.json")
H = 130


def row(h):
    return H - 1 - h


SECTIONS = [("Inicio «Para ti»", row(10), row(0)), ("Tramo 1 «Desliza hacia arriba»", row(39), row(11)),
            ("Tramo 2 «Reproducción automática»", row(61), row(40)), ("Pausa", row(63), row(62)),
            ("Tramo 3 «Solo uno más»", row(94), row(64)), ("Tramo 4 «Te podría gustar»", row(119), row(95)),
            ("Cierre «Siguiente video»", 0, row(120))]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def enemy(level, eid):
    return next(e for e in level["enemies"] if e["id"] == eid)


def section_of(level, r):
    return next(s["name"] for s in level["sections"] if s["y_from"] <= r <= s["y_to"])


class Level21Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 2-1 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("2-1", "Para ti", 2, 2, 300))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (20, 130), "Feed de 20 x 130 (§4.1)")
        self.assertEqual(lvl["camera"]["vertical"], "autoscroll")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": False},
                         "Todo el kit del Mundo 1; el golpe al suelo es del 2-2")
        self.assertEqual([(s["name"], s["y_from"], s["y_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertTrue(all(r[0] == "#" and r[-1] == "#" for r in lvl["grid"]), "Columnas 0 y 19: el marco")
        start = next((c, r) for r, line in enumerate(lvl["grid"]) for c, ch in enumerate(line) if ch == "P")
        goal = next((c, r) for r, line in enumerate(lvl["grid"]) for c, ch in enumerate(line) if ch == "G")
        self.assertEqual(start, (3, row(1)), "Vortice de llegada sobre el suelo de la sala de inicio")
        self.assertEqual(section_of(lvl, goal[1]), "Cierre «Siguiente video»")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "2-2"}])
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}, {"sync_1": (9, row(63))},
                         "Un punto de sincronizacion a mitad (doc)")

    def test_forced_scroll(self):
        scroll = self.level["scroll"]
        self.assertEqual(scroll["start_resume_row"], row(8), "Arranca al subir a h 8")
        speeds = sorted((s["y_from"], s["speed_tiles_s"]) for s in scroll["stages"])
        self.assertEqual([v for _, v in speeds], [1.1, 0.96, 0.96, 0.78],
                         "0,78 / 0,96 / 0,96 / 1,1 de abajo arriba (+30 % tras la primera prueba y +20-23 % tras la segunda)")
        self.assertEqual(scroll["stops"], [{"id": "sync_1", "at_row": row(62) + 2, "resume_row": row(63)}])
        info = self.result["plan"]["scroll"]
        self.assertGreaterEqual(info["margin_min_tiles"], 3.0, "Nunca a menos de 3 tiles del borde")
        self.assertEqual(info["loops"], ["bucle_para_ti"])
        self.assertTrue(120.0 <= self.result["plan"]["duration_s"] <= 150.0,
                        "Camino de unos 134 s con el scroll mas rapido (antes 160 s y 205 s): %.1f"
                        % self.result["plan"]["duration_s"])

    def test_loop_has_a_charger_against_the_energy_soft_lock(self):
        """Arreglo tras la primera prueba del usuario (2026-10-23): quien llegaba al bucle sin energia se
        quedaba atrapado. Cargador de carga completa dentro de la banda (se repite con ella), en el camino y
        fuera de la vista en el momento de la repeticion; el validador modela el peor caso."""
        loop = obj(self.level, "bucle_para_ti")
        charger = obj(self.level, "cargador_bucle")
        band = loop["params"]["band"]
        self.assertTrue(band[0] + 12 <= charger["y"] <= band[1], "En la banda, fuera de la vista al repetirse")
        self.assertEqual((charger["params"]["amount"], charger["params"]["reusable"]), (100.0, True))
        report = {lp["id"]: lp for lp in self.result["plan"]["loop_energy"]}
        entry = report["bucle_para_ti"]
        self.assertEqual(entry["charger"], "cargador_bucle")
        self.assertGreaterEqual(entry["amount"], entry["need"], "Una carga basta para la salida")
        self.assertLessEqual(entry["cooldown_s"], entry["repeat_s"], "Se enfria antes de la repeticion siguiente")

    def test_autoplay_videos(self):
        ola, rayo, cuenta = (enemy(self.level, i) for i in ("video_ola", "video_rayo", "video_cuenta"))
        self.assertEqual((ola["params"]["clip"], ola["x"], ola["y"]), ("wave", 1, row(47)), "Primero: ola, pared izq.")
        self.assertEqual((rayo["params"]["clip"], rayo["x"], rayo["y"]), ("ray", 17, row(55)))
        self.assertEqual(cuenta["params"]["clip"], "count")
        self.assertEqual(section_of(self.level, ola["y"]), "Tramo 2 «Reproducción automática»")
        self.assertEqual(section_of(self.level, cuenta["y"]), "Tramo 3 «Solo uno más»")
        feeds = sorted(i for b in self.result["plan"]["banners"] for i in b.get("feed", []))
        self.assertEqual(feeds, ["video_cuenta", "video_ola", "video_rayo"], "El plan cruza los tres videos")

    def test_loop_exit_needs_the_debug(self):
        loop = obj(self.level, "bucle_para_ti")
        self.assertEqual(loop["params"]["band"], [row(92), row(78)], "Banda h 78-92 (periodo 14)")
        self.assertTrue(self.level["validation"]["debug_required"])
        debug = self.result["plan"]["debug"]
        self.assertTrue(debug["required"])
        self.assertEqual(len(debug["segments"]), 1, "Un tramo de Debug: la salida del bucle")
        self.assertLessEqual(debug["segments"][0]["energy"], 60.0, "Unos 40-55 de energia (§4.1.1)")
        exit_cells = [(c, r) for r, line in enumerate(self.level["grid"]) for c, ch in enumerate(line) if ch == "h"
                      and c >= 15]
        self.assertTrue(exit_cells and all(row(92) <= r <= row(78) for _, r in exit_cells),
                        "Tarjetas ocultas de la salida a la derecha, dentro de la banda")
        sync = next(c for c in self.level["checkpoints"] if c["id"] == "sync_1")
        cargador = obj(self.level, "cargador_1")
        self.assertEqual(cargador["y"], sync["y"], "cargador_1 junto a sync_1 (cubre el Debug del bucle)")

    def test_fragile_cards_and_clone_zone_without_ground_pound(self):
        fragiles = [o for o in self.level["objects"] if o["type"] == "fragile_card"]
        self.assertEqual(len(fragiles), 3, "Las primeras tres tarjetas fragiles")
        self.assertTrue(all(o["params"]["width_tiles"] == 3 for o in fragiles))
        self.assertTrue(all(section_of(self.level, o["y"]) == "Tramo 4 «Te podría gustar»" for o in fragiles))
        zone = obj(self.level, "clones_te_podria")
        self.assertEqual(section_of(self.level, zone["params"]["zone"][1]), "Tramo 4 «Te podría gustar»")
        clones = self.result["plan"]["clones"]
        self.assertEqual([(c["id"], c["pounds"]) for c in clones], [("clones_te_podria", 0)],
                         "Se cruza avanzando, sin golpe al suelo (aun no lo tiene)")

    def test_secret_a_black_video_needs_the_debug_and_gives_msg_2_1(self):
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        a = items["secreto_video_negro"]
        self.assertEqual((a["without_debug"], a["with_debug"], a["forbid_abilities"]), (False, True, ["dash"]))
        pickup = obj(self.level, "mensaje_2_1")
        secret = next(s for s in self.level["secrets"] if s["id"] == "secreto_video_negro")
        self.assertEqual((pickup["x"], pickup["y"], pickup["params"]["memory_id"]), (secret["x"], secret["y"], "msg_2_1"))
        loop = obj(self.level, "bucle_para_ti")
        self.assertTrue(loop["params"]["band"][0] <= secret["y"] <= loop["params"]["band"][1], "En la banda del bucle")
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_2_1")
        self.assertEqual((memory["reachable_without_debug"], memory["reachable_with_debug"], memory["mandatory"]),
                         (False, True, False))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            msg = next(m for m in json.load(handle)["memories"] if m["id"] == "msg_2_1")
        self.assertEqual((msg["sender"], msg["level"], msg["secret"], msg["first_lap"]),
                         ("Mamá", "2-1", "secreto_video_negro", 1))

    def test_secret_b_extra_life_behind_the_glitch_wall(self):
        life = obj(self.level, "vida_extra_2_1")
        wall = obj(self.level, "pared_vida_extra")
        self.assertEqual((life["type"], life["params"]["secret_id"]), ("extra_life_pickup", "B"))
        self.assertEqual((wall["x"], wall["params"]["visible_only_with_debug"]), (18, True), "Columna 18 (§4.1.1)")
        item = next(i for i in self.result["extra_lives"] if i["id"] == "vida_extra_2_1")
        self.assertEqual((item["behind_glitch_wall"], item["reachable_without_debug"], item["reachable_with_debug"],
                          item["mandatory"]), (True, False, True, False))
        lives = [o for o in self.level["objects"] if o["type"] == "extra_life_pickup"]
        self.assertEqual(len(lives), 1, "Una vida extra por mapa: la del Mundo 2 (N = 3: tras la del 1-1)")
        # Sin el dash (salto + dash aereo desde la ultima fragil) no se llega a la repisa.
        base = copy.deepcopy(self.level)
        base["grid"] = [line.replace("E", ".") for line in base["grid"]]
        base["enemies"] = []
        base["abilities_available"]["dash"] = False
        without = vl.validate(base, check_schema=False)
        item = next(i for i in without["extra_lives"] if i["id"] == "vida_extra_2_1")
        self.assertFalse(item["reachable_with_debug"], "Sin el dash la repisa de la vida extra no se alcanza")

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (8, 6, 2),
                         "8 puntos: 6 en la ruta + 2 en secretos (§4.1.1)")
        chargers = sorted(o["params"]["id"] for o in lvl["objects"] if o["type"] == "charger")
        self.assertEqual(chargers, ["cargador_1", "cargador_2", "cargador_bucle"])
        self.assertFalse([o for o in lvl["objects"] if o["type"] == "power_bank_pickup"], "Sin power bank")
        self.assertGreater(self.result["plan"]["energy"]["min"], 0.0)

    def test_closing_card_counts_down_and_leaves_alone(self):
        terminal = obj(self.level, "terminal_siguiente_video")
        self.assertEqual((terminal["type"], terminal["params"]["countdown_s"], terminal["help_id"]),
                         ("exit_terminal", 3.0, ""), "Cuenta de 3 s y sin la Q del pulso (no miente)")
        sign = obj(self.level, "cartel_siguiente_video")
        self.assertIn("Quedan 3 segundos para el siguiente video", sign["params"]["text"])
        self.assertIn("No puedes cancelar", sign["params"]["text"])
        self.assertEqual(self.result["exit_terminals"],
                         [{"id": "terminal_siguiente_video", "pulse_from": None, "countdown_s": 3.0}])
        for oid, help_id in (("cartel_para_ti", "hud_clock"), ("cartel_desliza", "feed_edge")):
            self.assertEqual(obj(self.level, oid)["help_id"], help_id)
        texts = [o["params"]["text"] for o in self.level["objects"] if o["type"] == "feed_sign"]
        self.assertFalse([t for t in texts if "vuelta" in t.lower()], "La UI nunca dice «vuelta»")

    def test_exported_path(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "2-1"))
        steps = path["steps"]
        actions = [s["action"] for s in steps]
        for action in ("wait_scroll", "wait_phase", "debug_on", "debug_off", "charge", "goal"):
            self.assertIn(action, actions)
        self.assertNotIn("pulse", [a for a, s in zip(actions, steps) if s.get("final")], "La salida no usa el pulso")
        on = actions.index("debug_on")
        self.assertLess(on, actions.index("debug_off"))
        self.assertTrue(all(not s.get("debug") for s in steps[:on]), "El Debug se enciende antes de pisar lo oculto")
        finals = [s for s in steps if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"], s["seconds"]) for s in finals],
                         [("wait", "terminal_siguiente_video", 3.0)])
        self.assertEqual(actions[-1], "goal")
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in steps))

    def test_no_scroll_wait_on_a_fragile_card(self):
        """Paso 12 (bot del feed): de pie sobre una fragil la cuenta corre (0,6 s), asi que ninguna espera del
        scroll va encima de una; la de antes de la cadena fragil_1 -> dash -> fragil_2 va en la fila 32. El cruce
        de fragil_2 (se entra con el dash que sale de fragil_1) tambien se comprueba."""
        cells = set()
        for o in self.level["objects"]:
            if o["type"] == "fragile_card":
                cells.update((o["x"] + dx, o["y"]) for dx in range(o["params"]["width_tiles"]))
        waits = [s for s in self.exported[0]["steps"] if s["action"] in ("wait_scroll", "wait", "wait_phase")]
        on_card = [s["at"]["cell"] for s in waits if (s["at"]["cell"][0], s["at"]["cell"][1] + 1) in cells]
        self.assertEqual(on_card, [], "Esperas encima de una fragil")
        reasons = [s.get("reason") for s in waits]
        self.assertIn("el scroll sube (antes de la tarjeta fragil)", reasons)
        groups = [r["group"] for r in self.result["plan"]["reminders"]]
        self.assertEqual(sorted(groups), ["_fragil_fragil_1", "_fragil_fragil_2", "_fragil_fragil_3"])

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_2_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m2 = next(w for w in hub["worlds"] if w["id"] == "m2")
        self.assertEqual(m2["unlocked_by"], ["1-boss"], "Se abre al vencer a Alerta Mayor")
        rows = [(lv["id"], lv["name"], lv["playable"], lv.get("kind")) for lv in m2["levels"]]
        self.assertEqual(rows, [("2-1", "Para ti", True, None), ("2-2", "Un video más", True, None),
                                ("2-3", "Scroll infinito", True, None), ("2-boss", "Autoplay", True, "boss")])
        self.assertTrue(all(lv["laps"] == [1] for lv in m2["levels"]))
        m3 = next(w for w in hub["worlds"] if w["id"] == "m3")
        self.assertEqual(m3["unlocked_by"], ["2-boss"])
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "2-1.tscn")))


if __name__ == "__main__":
    unittest.main()
