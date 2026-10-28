"""Nivel 4-1 «Chats recientes» (data/levels/4-1.json; paso 11 de docs/propuesta-mundo-4.md §8, 2026-10-28):
esquema y alcanzabilidad sin avisos en todas las pasadas, torre de 24 x 96 en bandas (pasarelas que se recorren
enteras), burbujas (largo por texto, eliminada, «jajaja» y puente largo), las cuatro «escribiendo…» del Modo
oscuro, el Troll de la Pausa, las zonas «Visto» del Piso 4 (regla del 4-1: sin peligros junto a ellas), secretos
(A con el Debug y sin dash, B con Pellizcar, C con el Debug y el dash aereo), economia, camino exportado y su
duracion frente al objetivo (40-55 %), escena y subidas al dia, y el 4-1 jugable desde la carpeta del Mundo 4. Las pasadas con mejoras, con todo al maximo
y con el tope del acceso las hace tools/run_tests.sh sobre data/levels/*.json.
Uso: python3 tests/test_level_4_1.py
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
import world4_model as w4  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "4-1.json")
SECTIONS = [("Azotea «En línea»", 0, 11), ("Piso 4 «Visto»", 12, 31), ("Piso 3 «Troll»", 32, 46), ("Pausa", 47, 48),
            ("Piso 2 «Escribiendo…»", 49, 64), ("Piso 1 «Burbujas»", 65, 81), ("Vestíbulo «Lista de chats»", 82, 95)]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def of_type(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def section_of(level, row):
    return next(s["name"] for s in level["sections"] if s["y_from"] <= row <= s["y_to"])


def without(level, *abilities):
    out = copy.deepcopy(level)
    for name in abilities:
        out["abilities_available"][name] = False
    return vl.validate(out, check_schema=False)


class Level41Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 4-1 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("4-1", "Chats recientes", 4, 4, 420))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (24, 96), "Torre de 24 x 96 (§4.1)")
        self.assertEqual(lvl["camera"]["vertical"], "tower")
        self.assertEqual(lvl["debug_color"], "coral", "Debug coral en el Mundo 4")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": True, "shockwave": False}, "Todo el kit del Mundo 3; Agitar, no (llega en el 4-2)")
        self.assertEqual([(s["name"], s["y_from"], s["y_to"]) for s in lvl["sections"]], SECTIONS)
        start = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "P")
        goal = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "G")
        self.assertEqual(section_of(lvl, start[1]), "Vestíbulo «Lista de chats»", "Se sube de la fila 95 a la 0")
        self.assertEqual(section_of(lvl, goal[1]), "Azotea «En línea»")
        terminal = obj(lvl, "terminal_enviar")
        self.assertEqual((terminal["type"], terminal["x"], terminal["y"], terminal["params"]["text"]),
                         ("exit_terminal", goal[0], goal[1] - 1, "Enviar"))
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "4-2"}])
        self.assertEqual({c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}, {"sync_1": (12, 47)})
        self.assertEqual(section_of(lvl, 47), "Pausa", "Un punto de sincronizacion a mitad (doc)")

    def test_bands_force_the_whole_width(self):
        """Sin atajos verticales: el camino recorre las pasarelas casi enteras (decision del paso 11)."""
        walked = sum(abs(s["to"]["cell"][0] - s["from"]["cell"][0]) for s in self.exported[0]["steps"]
                     if s["action"] == "walk")
        self.assertGreater(walked, 300, "Tiles andados en horizontal: %d" % walked)

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (8, 6, 2),
                         "6 en la ruta (uno por piso) + A + B (§4.1.1)")
        rows = sorted(r for r, row in enumerate(lvl["grid"]) for ch in row if ch == "o")
        route = [r for r in rows if r not in (57, 47)]
        self.assertEqual(sorted({section_of(lvl, r) for r in route}),
                         sorted(name for name, _, _ in SECTIONS if name != "Pausa"), "Un punto por piso")
        chargers = {o["params"]["id"]: o for o in of_type(lvl, "charger")}
        self.assertEqual(sorted(chargers), ["cargador_1", "cargador_2"])
        self.assertTrue(all(c["params"]["reusable"] and c["params"]["amount"] == 50.0
                            and c["params"]["cooldown_s"] == 10.0 for c in chargers.values()))
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1, "El power bank, en el secreto B")
        lives = of_type(lvl, "extra_life_pickup")
        self.assertEqual([(o["params"]["id"], o["params"]["secret_id"]) for o in lives], [("vida_extra_4_1", "C")],
                         "La vida extra del Mundo 4 (N = 3: la anterior fue la del 3-1)")
        self.assertEqual([o["params"]["memory_id"] for o in of_type(lvl, "memory_pickup")], ["msg_4_1"])
        lamp = of_type(lvl, "flashlight_pickup")
        self.assertEqual(len(lamp), 1)
        self.assertEqual(section_of(lvl, lamp[0]["y"]), "Vestíbulo «Lista de chats»", "La Linterna, a la llegada")
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 50.0, "Energia de sobra (obligatoria ~20)")

    def test_bubbles(self):
        cfg = {"chars_per_tile": 6, "min_tiles": 1, "max_tiles": 8}
        bubbles = of_type(self.level, "chat_bubble")
        widths = {o["params"]["id"]: w4.bubble_width(o["params"]["text"], cfg) for o in bubbles}
        self.assertEqual(widths["b1_jaja"], 2, "Un «jajaja» de 2 entre dos huecos (doc)")
        self.assertEqual(widths["b1_puente"], 7, "Un mensaje largo de 7 que hace de puente (doc)")
        self.assertEqual(min(widths.values()), 1)
        self.assertEqual(max(widths.values()), 8)
        deleted = [o for o in bubbles if o["params"].get("deleted")]
        self.assertEqual([o["params"]["id"] for o in deleted], ["b1_borrado"])
        self.assertEqual(section_of(self.level, deleted[0]["y"]), "Piso 1 «Burbujas»")
        self.assertTrue(all("width_tiles" not in o["params"] for o in bubbles), "El largo lo pone el texto")

    def test_typing_in_the_dark(self):
        typing = of_type(self.level, "typing_bubble")
        self.assertEqual(sorted(o["params"]["id"] for o in typing), ["t1", "t2", "t3", "t4"], "Patron 18, cuatro veces")
        dark = obj(self.level, "modo_oscuro")["params"]
        zone = (obj(self.level, "modo_oscuro")["x"], obj(self.level, "modo_oscuro")["y"], dark["width_tiles"],
                dark["height_tiles"])
        for o in typing:
            self.assertEqual(section_of(self.level, o["y"]), "Piso 2 «Escribiendo…»")
            self.assertTrue(zone[1] <= o["y"] < zone[1] + zone[3], "%s en el Modo oscuro" % o["params"]["id"])
        waits = {t["id"]: t["wait_s"] for t in self.result["world4"]["typing"]}
        self.assertEqual(sorted(waits), ["t1", "t2", "t3", "t4"], "El camino aterriza en las cuatro")
        self.assertTrue(all(0.0 <= w <= 1.0 for w in waits.values()), waits)
        self.assertTrue(self.result["world4"]["dark"]["flashlight"])

    def test_troll_is_stunned_on_the_path(self):
        enemies = {e["id"]: e for e in self.level["enemies"]}
        self.assertEqual([(e["type"], e["x"], e["y"]) for e in enemies.values()], [("troll", 22, 45)])
        report = {e["id"]: e for e in self.result["world4"]["enemies"]}
        self.assertEqual(report["troll_1"]["with"], "pulse", "El camino lo aturde con el pulso")
        self.assertEqual(report["troll_1"]["at"], [45, 20], "Desde la burbuja a su altura (el escalon de la banda 48)")
        self.assertEqual(section_of(self.level, 45), "Piso 3 «Troll»")

    def test_seen_zones_of_floor_4(self):
        zones = {o["params"]["id"]: o for o in of_type(self.level, "seen_zone")}
        self.assertEqual(sorted(zones), ["visto_aire", "visto_ciclo", "visto_ciclo_2", "visto_ciclo_3", "visto_ciclo_4",
                                         "visto_suelo"])
        self.assertTrue(all(section_of(self.level, z["y"]) == "Piso 4 «Visto»" for z in zones.values()),
                        "Primeras zonas «Visto» en el Piso 4 (doc)")
        info = {z["id"]: z for z in self.result["world4"]["zones"]}
        self.assertIn("pulse_from", info["visto_suelo"])
        self.assertIn("pulse_from", info["visto_aire"], "Patron 19: pulso al check y pasar")
        for zid in ("visto_ciclo", "visto_ciclo_2", "visto_ciclo_3", "visto_ciclo_4"):
            self.assertTrue(info[zid]["cycle"])
            self.assertEqual(info[zid]["wait_s"], 9.0)
        self.assertFalse(self.level["abilities_available"]["shockwave"],
                         "Regla del 4-1: sin Agitar, ningun peligro junto a una zona (la comprueba el validador)")

    def test_secret_a_old_message_needs_the_debug_without_dash(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_mensaje_antiguo")
        self.assertEqual((a["memory_id"], a["points"], a["needs_debug"], a["forbid_abilities"]),
                         ("msg_4_1", 1, True, ["dash"]))
        self.assertEqual(sorted(a["reward"]), ["attention_points", "memory"])
        grid = self.level["grid"]
        self.assertEqual(grid[58][14:19], "hhhhh", "La burbuja oculta que sale de t2 (doc)")
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_4_1")
        self.assertEqual((memory["reachable_without_debug"], memory["reachable_with_debug"], memory["mandatory"]),
                         (False, True, False))

    def test_secret_b_archived_needs_compress(self):
        b = next(s for s in self.level["secrets"] if s["id"] == "secreto_archivado")
        self.assertEqual((b["object"], b["points"]), ("power_bank_pickup", 1))
        frame = obj(self.level, "marco_archivado")
        self.assertEqual((frame["type"], frame["x"], frame["y"], frame["params"]["orientation"]),
                         ("small_frame", 6, 47, "wall"))
        grid = self.level["grid"]
        self.assertEqual((grid[46][6], grid[47][6], grid[48][6]), ("#", ".", "#"), "Hueco de 1 fila")
        item = next(i for i in self.result["secrets"]["items"] if i["id"] == "secreto_archivado")
        self.assertTrue(item["reachable"])
        no_pinch = without(self.level, "compress")
        self.assertFalse(next(i for i in no_pinch["secrets"]["items"] if i["id"] == "secreto_archivado")["reachable"],
                         "Sin Pellizcar no se entra")
        self.assertEqual([e for e in no_pinch["errors"] if "secreto_archivado" not in e["message"]], [],
                         "El camino principal no necesita Pellizcar")

    def test_secret_c_extra_life_needs_the_debug_and_the_air_dash(self):
        c = next(s for s in self.level["secrets"] if s["id"] == "secreto_vida_extra")
        self.assertEqual((c["object"], c["needs_debug"], c["reward"]), ("glitch_wall", True, "extra_life"))
        wall = obj(self.level, "pared_vida_extra")
        self.assertTrue(wall["params"]["visible_only_with_debug"])
        life = next(i for i in self.result["extra_lives"] if i["id"] == "vida_extra_4_1")
        self.assertEqual((life["reachable_without_debug"], life["reachable_with_debug"], life["mandatory"]),
                         (False, True, False))
        no_dash = without(self.level, "dash")
        life = next(i for i in no_dash["extra_lives"] if i["id"] == "vida_extra_4_1")
        self.assertFalse(life["reachable_with_debug"], "Sin el dash aereo no se llega a la repisa")
        self.assertEqual([e for e in no_dash["errors"] if "vida_extra" not in e["message"]], [],
                         "El camino principal no necesita el dash")

    def test_exported_path_and_duration(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "4-1"))
        steps = path["steps"]
        actions = [s["action"] for s in steps]
        for action in ("walk", "jump", "pulse", "pulse_seen", "wait_typing", "wait", "goal"):
            self.assertIn(action, actions)
        self.assertEqual(actions.count("wait_typing"), 4)
        self.assertEqual(actions.count("pulse_seen"), 2)
        self.assertNotIn("shake", actions, "Sin Agitar en el 4-1")
        troll = [s for s in steps if s["action"] == "pulse" and s["target"]["type"] == "troll"]
        self.assertEqual(len(troll), 1, "Un pulso al Troll")
        finals = [s for s in steps if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_enviar")])
        self.assertEqual(actions[-1], "goal")
        seconds = self.result["plan"]["duration_s"]
        target = self.level["target_duration_s"]
        self.assertTrue(0.40 * target <= seconds <= 0.55 * target,
                        "Camino del validador entre el 40 y el 55 %% del objetivo (§4): %.1f s de %d" % (seconds, target))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_4_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m4 = next(w for w in hub["worlds"] if w["id"] == "m4")
        self.assertEqual((m4["unlocked_by"], m4["requires_upgrade"], m4["page"]), (["3-boss"], "hub_update_4_6", 2))
        self.assertEqual(m4["miniature"], "res://assets/sprites/hub/icons/world_icon_m4_00.png")
        rows = [(lv["id"], lv["name"], lv["playable"], lv.get("kind"), lv.get("available_text")) for lv in m4["levels"]]
        self.assertEqual(rows, [("4-1", "Chats recientes", True, None, None),
                                ("4-2", "Grupo sin respuesta", True, None, "Nuevo mensaje"),
                                ("4-3", "Mensajes sin leer", True, None, "Nuevo mensaje"),
                                ("4-boss", "El Visto", True, "boss", None)])
        self.assertTrue(all(lv["laps"] == [1] for lv in m4["levels"]))
        for entry in [m4] + m4["levels"]:
            res = entry.get("icon", entry.get("miniature"))
            self.assertTrue(os.path.exists(os.path.join(ROOT, res[len("res://"):])), res)
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "4-1.tscn")))
        remark = next(r for r in hub["calc"]["remarks"] if r["after_level"] == "4-1")
        self.assertEqual(remark["text"], "Mensajes enviados: 0. Recibidos: 37. Saldo: preocupante.")
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_4_1"]
        self.assertEqual((msg["level"], msg["secret"], msg["sender"], msg["world"], msg["first_lap"]),
                         ("4-1", "secreto_mensaje_antiguo", "Tomi", 4, 1))


if __name__ == "__main__":
    unittest.main()
