"""Nivel 1-2 «Centro de notificaciones» (data/levels/1-2.json; paso 13 de docs/propuesta-1-2.md §10,
2026-10-16): esquema, alcanzabilidad con el plan del camino (acertijo, Posponer, Debug, banners,
puntos rojos y energia), camino exportado, secreto C con dos Posponer, escena al dia y
pestanas de la fachada. La economia del nivel esta en tests/test_level_schema.py.
Uso: python3 -m unittest tests/test_level_1_2.py
"""

import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build_level  # noqa: E402
import level_plan  # noqa: E402
import validate_level as vl  # noqa: E402
import validate_level_schema as vls  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, "tests", "support"))
import puzzle_levels as pz  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "1-2.json")
NEW_TYPES = ("overlay_popup", "laser_receiver", "relay_receiver", "ad_cover", "reminder_platform",
             "snooze_button", "update_bar", "charger", "bridge_inactive", "receiver", "popup_blocker",
             "power_bank_pickup", "exit_terminal", "power_switch", "debug_switch", "laser_switch", "charge_dock",
             "glitch_wall")
# Acertijo de la azotea (encuentro con Calc; tanda H2 del paso 14, 2026-10-17).
CALC_PIECES = ("pared_glitch", "interruptor_luz", "interruptor_laser", "panel_oculto", "dock_calc", "calc", "cuarto",
               "guia_calc")


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


class Level12Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [])
        upgraded = vl.validate(copy.deepcopy(self.level), upgrades=["wide_pulse"])
        self.assertTrue(upgraded["ok"], upgraded["errors"])

    def test_tower_structure(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"]),
                         ("1-2", "Centro de notificaciones", 1, 2))
        # 28 x 66 desde la tanda H2 (la azotea crecio 4 filas por arriba; antes 28 x 62).
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (28, 66))
        self.assertEqual(lvl["camera"]["vertical"], "tower")
        self.assertEqual([s["name"] for s in lvl["sections"]],
                         ["Azotea", "Piso 4: Actualizaciones", "Piso 3: Recordatorios", "Piso 2: Correo",
                          "Piso 1: Mensajes", "Vestíbulo"])
        # Vortice de llegada abajo (vestibulo) y terminal de salida arriba (azotea).
        rows = {s["name"]: (s["y_from"], s["y_to"]) for s in lvl["sections"]}
        p_row = next(r for r, row in enumerate(lvl["grid"]) if "P" in row)
        g_row = next(r for r, row in enumerate(lvl["grid"]) if "G" in row)
        self.assertTrue(rows["Vestíbulo"][0] <= p_row <= rows["Vestíbulo"][1])
        self.assertTrue(rows["Azotea"][0] <= g_row <= rows["Azotea"][1])
        terminal = next(o for o in lvl["objects"] if o["type"] == "exit_terminal")
        self.assertTrue(rows["Azotea"][0] <= terminal["y"] <= rows["Azotea"][1])
        # Puntos de sincronizacion al entrar a los pisos 2 y 4.
        cps = {c["id"]: c for c in lvl["checkpoints"]}
        self.assertEqual(sorted(cps), ["sync_1", "sync_2"])
        self.assertEqual(cps["sync_1"]["y"], rows["Piso 2: Correo"][1] - 1, "sync_1 en el suelo del piso 2")
        self.assertEqual(cps["sync_2"]["y"], rows["Piso 4: Actualizaciones"][1] - 1, "sync_2 en el suelo del piso 4")
        self.assertEqual([c["reachable_from"] for c in self.result["checkpoints"]], ["P", "sync_1"])
        # Sin enemigos nuevos aparte de los ya hechos; sin vida extra.
        self.assertEqual({e["type"] for e in lvl["enemies"]}, {"notification_badge", "spam_banner"})
        self.assertFalse(any(o["type"] == "extra_life_pickup" for o in lvl["objects"]))
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "1-3"}])

    def test_every_new_object_and_enemy_has_its_help_id(self):
        for o in self.level["objects"]:
            if o["type"] in NEW_TYPES:
                self.assertIn("help_id", o, "%s %s" % (o["type"], o["params"].get("id")))
        for e in self.level["enemies"]:
            self.assertEqual(e.get("help_id"), e["type"])

    def test_puzzles_and_timers_in_the_plan(self):
        val = self.level["validation"]
        self.assertTrue(val["laser_required"] and val["debug_required"])
        self.assertEqual(val["snooze_required"], ["posponer_3b", "posponer_3c"])
        plan = self.result["plan"]
        relay = plan["relays"][0]
        self.assertEqual((relay["lector"], relay["bridge"], relay["window_s"]), ("lector_1", "puente_correo", 6.0))
        self.assertGreaterEqual(relay["spare_s"], 1.5, "Acertijo con margen de 1,5 s")
        groups = {g["group"]: g for g in plan["reminders"]}
        for gid in ("posponer_3b", "posponer_3c"):
            self.assertIsNone(groups[gid]["without_snooze"], "%s no se cruza sin Posponer" % gid)
            self.assertGreaterEqual(groups[gid]["with_snooze"], 1.5, "%s con Posponer y margen" % gid)
            self.assertEqual(groups[gid]["snooze_shots"], 1)
        self.assertTrue(plan["debug"]["required"])
        self.assertEqual(plan["sync_damage"], 0.0, "Sin dano de puntos rojos en el camino")
        self.assertGreater(plan["energy"]["min"], 0.0)
        self.assertEqual([b["id"] for b in plan["bars"]], ["barra_99"])
        overlays = {o["id"]: o for o in plan["overlays"]}
        self.assertEqual(sorted(overlays), ["overlay_1", "overlay_2", "overlay_3"], "Un pop-up translucido en los pisos 1, 3 y 4")
        self.assertTrue(overlays["overlay_1"]["closed_from"] and overlays["overlay_3"]["closed_from"])
        self.assertTrue(overlays["overlay_2"]["closed_from"] or overlays["overlay_2"]["debug_view"],
                        "El del piso 3 (sobre el Posponer) se cierra con el pulso o se ve con el Debug")
        self.assertTrue(all(b["hits"] == 0 for b in plan["badges"]))

    def test_secret_a_needs_the_debug_and_the_others_do_not(self):
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertEqual((items["secreto_spam"]["without_debug"], items["secreto_spam"]["with_debug"]),
                         (False, True))
        self.assertTrue(items["secreto_borradores"]["reachable"])
        self.assertTrue(items["secreto_olvidado"]["reachable"])

    def test_spam_message_is_collectible_of_secret_a_with_the_debug(self):
        """Paso 4 de docs/propuesta-recuerdos.md (2026-10-19): el mensaje msg_1_2 esta en la celda
        (26, 37) de la carpeta de Spam, lo ofrece secreto_spam (junto a sus 2 puntos) y, como el
        secreto, no se alcanza sin Debug y si con el Debug del chip del mismo piso; nunca obligatorio."""
        sec = next(s for s in self.level["secrets"] if s["id"] == "secreto_spam")
        self.assertEqual((sec["reward"], sec["points"], sec["memory_id"]), (["attention_points", "memory"], 2, "msg_1_2"))
        pickup = next(o for o in self.level["objects"] if o["type"] == "memory_pickup")
        self.assertEqual((pickup["x"], pickup["y"], pickup["params"]["memory_id"]), (26, 37, "msg_1_2"))
        self.assertEqual(self.level["grid"][37][26], "o", "El punto de esa celda sigue")
        item = next(i for i in self.result["memories"] if i["memory_id"] == "msg_1_2")
        self.assertEqual(item["secret"], "secreto_spam")
        self.assertEqual((item["reachable_without_debug"], item["reachable_with_debug"], item["mandatory"]),
                         (False, True, False))

    def test_exported_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, "1-2.json")
            code = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_level.py"),
                                   "--export-path", out, LEVEL_PATH], capture_output=True, text=True).returncode
            self.assertEqual(code, 0)
            with open(out, encoding="utf-8") as handle:
                path = json.load(handle)
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "1-2"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("laser", "pulse", "pickup", "debug_on", "debug_off", "wait", "wait_phase", "charge"):
            self.assertIn(action, actions)
        self.assertEqual(actions[-1], "goal")
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual(len(finals), 1, "Un pulso final a la terminal")
        self.assertLess(actions.index("pickup"), actions.index("debug_on"), "Debug tras el chip")
        # Acertijo de Calc (tanda H2): pulsos de espaldas, laser al interruptor, Debug para el panel y la
        # espera de la carga de Calc, en ese orden de piezas y antes del pulso final.
        steps = path["steps"]
        backs = [s for s in steps if s.get("face_back")]
        self.assertEqual([(s["target"]["id"], s["count"], s["of"]) for s in backs],
                         [("interruptor_luz", 1, 3), ("interruptor_luz", 2, 3), ("interruptor_luz", 3, 3),
                          ("panel_oculto", 1, 1)])
        self.assertTrue(all(s["action"] == "pulse" and s["pose_s"] > 0 and s["facing"] in (1, -1) for s in backs))
        laser = next(s for s in steps if s.get("target", {}).get("type") == "laser_switch")
        self.assertEqual(laser["action"], "laser")
        self.assertEqual(laser["at"]["cell"], [19, 7], "Desde la repisa baja del cuarto")
        reveal = next(s for s in steps if s["action"] == "debug_on" and s.get("target", {}).get("type") == "debug_switch")
        self.assertEqual(steps[reveal["i"] + 2]["action"], "debug_off")
        dissolve = next(s for s in steps if s.get("target", {}).get("type") == "glitch_wall")
        self.assertEqual((dissolve["action"], steps[dissolve["i"] - 1]["action"]), ("wait", "debug_on"))
        charge = next(s for s in steps if s.get("target", {}).get("type") == "charge_dock")
        self.assertEqual(charge["action"], "wait")
        self.assertGreater(charge["seconds"], 5.0)
        order = [backs[0]["i"], laser["i"], backs[-1]["i"], charge["i"], finals[0]["i"]]
        self.assertEqual(order, sorted(order))
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in steps))

    def test_banner_corridors_are_safe_at_walking_speed(self):
        """Hallazgo del bot vertical (2026-10-18, corregido el 2026-10-19): el camino cruzaba andando el
        pasillo de banner_2 (piso 4, fila 20; 16 tiles, 4,7 s con un ciclo de 3 s) y el barrido
        siguiente alcanzaba a Isak hacia la columna 8; el validador lo daba por seguro porque su
        busqueda por fase andaba a 17 cuadros por celda y redondeaba la fase en cada paso. Ahora cada
        tramo andando del camino exportado, a walk_speed y con el reloj de los banners anclado en su
        espera de fase (como el bot), no toca ningun barrido; en el piso 4 el camino salta el banner
        o se refugia en el nicho (columnas 13-14) en vez de andar el pasillo entero."""
        rules = vl.Rules()
        hits = pz.banner_walk_hits(self.level, self.exported[0], (rules.hitbox_w, rules.hitbox_h),
                                   rules.walk_speed)
        self.assertEqual(hits, [])
        steps = self.exported[0]["steps"]
        wait = next(s for s in steps if s["action"] == "wait_phase" and s["at"]["cell"][1] == 20)
        crossing = steps[wait["i"] + 1:]
        crossing = crossing[:next(k for k, s in enumerate(crossing) if s["action"] == "pulse")]
        self.assertTrue(all(s["action"] != "walk" or s["from"]["cell"][0] - s["to"]["cell"][0] < 15
                            for s in crossing), "el pasillo de banner_2 no se anda de una vez")
        self.assertTrue(any(s["action"] in ("jump", "jump_run", "fall", "hop", "wait") for s in crossing))

    def test_secret_c_needs_two_snoozes_from_its_entry(self):
        """Variante: Isak empieza en el piso 3 y la meta esta en el nicho del secreto C (Posponer
        exigido en el grupo olvidado). Con un solo disparo al Posponer no da tiempo; con dos, si."""
        lvl = copy.deepcopy(self.level)
        grid = [list(r) for r in lvl["grid"]]
        for r, row in enumerate(grid):
            for c, ch in enumerate(row):
                if ch in "PGCS":
                    grid[r][c] = "."
        grid[34][3] = "P"
        grid[31][4] = "G"
        lvl["grid"] = ["".join(r) for r in grid]
        lvl["checkpoints"] = []
        lvl["secrets"] = []
        terminal = next(o for o in lvl["objects"] if o["type"] == "exit_terminal")
        terminal["x"], terminal["y"] = 4, 30
        terminal["params"]["requires_power"] = False  # sin el acertijo de la azotea
        lvl["validation"] = {"snooze_required": ["olvidado"], "time_margin_s": 1.0}
        saved = level_plan.MAX_SNOOZE_SHOTS
        try:
            found = {}
            for shots in (1, 2):
                level_plan.MAX_SNOOZE_SHOTS = shots
                result = vl.validate(copy.deepcopy(lvl), check_schema=False, allies=())
                group = next(g for g in result["plan"]["reminders"] if g["group"] == "olvidado")
                found[shots] = (group, [e["message"] for e in result["errors"] if "olvidado" in e["message"]])
        finally:
            level_plan.MAX_SNOOZE_SHOTS = saved
        self.assertEqual(found[1][0]["entry"], [31, 19], "Se entra por el primer recordatorio")
        self.assertIsNone(found[1][0]["with_snooze"], "Con un Posponer no da tiempo")
        self.assertTrue(found[1][1])
        self.assertEqual(found[2][1], [], "Con dos, si")
        self.assertEqual(found[2][0]["snooze_shots"], 2)
        self.assertGreaterEqual(found[2][0]["with_snooze"], 1.0)
        bank = obj(self.level, "power_bank_1_2")
        self.assertEqual((bank["x"], bank["y"]), (2, 31))

    def test_rooftop_holds_the_calc_puzzle(self):
        """Azotea de 11 filas (0-10) con el acertijo de Calc (tanda H2 del paso 14, 2026-10-17): la
        terminal apagada con corriente del punto de carga, la pared con glitch que se vuelve puerta, el
        cuarto a oscuras con sus tres piezas, Calc al 3 % y el cargador; todo con done_if_ally calc."""
        lvl = self.level
        rows = {s["name"]: (s["y_from"], s["y_to"]) for s in lvl["sections"]}
        self.assertEqual(rows["Azotea"], (0, 10))
        self.assertEqual(rows["Piso 4: Actualizaciones"], (11, 21))
        self.assertEqual(rows["Vestíbulo"], (60, 65))
        terminal = obj(lvl, "terminal_azotea")
        self.assertEqual((terminal["params"]["requires_power"], terminal["params"]["power_source"]), (True, "dock_calc"))
        self.assertEqual(lvl["grid"][terminal["y"] + 1][terminal["x"]], "G")
        for oid in CALC_PIECES:
            piece = obj(lvl, oid)
            self.assertEqual(piece["params"].get("done_if_ally"), "calc", oid)
            self.assertTrue(rows["Azotea"][0] <= piece["y"] <= rows["Azotea"][1], oid)
        self.assertEqual(obj(lvl, "interruptor_luz")["params"]["pulses"], 3)
        self.assertEqual(obj(lvl, "pared_glitch")["params"]["door_when"], "interruptor_luz")
        self.assertEqual(obj(lvl, "dock_calc")["params"]["requires"], ["interruptor_luz", "interruptor_laser", "panel_oculto"])
        # El guion de Eco usa los ids del nivel.
        with open(os.path.join(ROOT, "data", "eco_guides.json"), encoding="utf-8") as handle:
            guide = json.load(handle)["guides"]["calc_rooftop"]
        ids = {o["params"].get("id") for o in lvl["objects"]}
        self.assertTrue({s["object"] for s in guide["steps"] if "object" in s} <= ids)
        power = self.result["power"][0]
        self.assertEqual((power["id"], power["source"], power["powered_at_start"]), ("terminal_azotea", "dock_calc", False))
        # La espera de Calc que tambien mide tests/test_level_1_2_rooftop.gd con el juego (VALIDATOR_CALC_WAIT_S).
        self.assertAlmostEqual(power["wait_s"], 10.585, delta=0.011)

    def test_calc_puzzle_in_the_plan_with_margins(self):
        """Calc desconocida: el camino resuelve el acertijo (3 pulsos de espaldas, el laser desde la repisa
        baja, el Debug para la pared y para el panel, 1 pulso al panel y la espera de Calc) y la energia
        no baja de cero con el cargador de la azotea."""
        puzzle = self.result["plan"]["calc_puzzle"]
        self.assertEqual((puzzle["pulses"], puzzle["lasers"], puzzle["debug_uses"]), (4, 1, 2))
        self.assertEqual(puzzle["laser_from"], [7, 19])
        self.assertGreater(puzzle["calc_wait_s"], 5.0)
        roof = [s for s in puzzle["steps"] if "energy_after" in s]
        self.assertTrue(roof and min(s["energy_after"] for s in roof) >= 20.0, roof)
        path = [a["text"] for a in self.result["path"]]
        self.assertTrue(any("pulso x3 de espaldas" in t and "interruptor_luz" in t for t in path))
        self.assertTrue(any("Debug para descubrirlo" in t and "panel_oculto" in t for t in path))
        self.assertTrue(any("Calc entra" in t for t in path))
        self.assertTrue(any("cargador_3" in s.get("target", {}).get("id", "") for s in self.export_steps()
                            if s["action"] == "charge"))

    def test_calc_known_goes_straight_to_the_terminal(self):
        """Calc conocida (allies_met): las piezas arrancan hechas, la terminal tiene corriente y el camino
        va directo a ella (el validador valida los dos casos)."""
        known = self.result["allies_known"]
        self.assertEqual(known["allies"], ["calc"])
        self.assertTrue(known["ok"], known["errors"])
        self.assertEqual(known["puzzle_actions"], 0)
        direct = vl.validate(copy.deepcopy(self.level), allies=["calc"])
        self.assertTrue(direct["ok"], direct["errors"])
        self.assertNotIn("allies_known", direct)
        self.assertTrue(direct["power"][0]["powered_at_start"])
        self.assertEqual(direct["plan"]["calc_puzzle"], {})
        self.assertLess(direct["plan"]["duration_s"], self.result["plan"]["duration_s"] - 15.0)
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, "1-2_conocida.json")
            code = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_level.py"), "--allies", "calc",
                                   "--export-path", out, LEVEL_PATH], capture_output=True, text=True).returncode
            self.assertEqual(code, 0)
            with open(out, encoding="utf-8") as handle:
                steps = json.load(handle)["steps"]
        types = {s.get("target", {}).get("type") for s in steps}
        self.assertFalse(types & {"power_switch", "debug_switch", "laser_switch", "charge_dock", "glitch_wall"})
        self.assertTrue(steps[-2].get("final") and steps[-2]["target"]["id"] == "terminal_azotea")

    def export_steps(self):
        out = []
        vl.validate(copy.deepcopy(self.level), export=out, allies=())
        return out[0]["steps"]

    def test_scene_is_up_to_date_with_the_facade_tabs(self):
        for lid in ("1-1", "1-2"):
            path = os.path.join(ROOT, "data", "levels", "%s.json" % lid)
            code = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "build_level.py"), "--check", path],
                                  capture_output=True, text=True).returncode
            self.assertEqual(code, 0, "%s: escena al dia" % lid)
        tabs = build_level.tower_tabs(self.level, 64)
        self.assertEqual([label for label, _ in tabs], ["Actualizaciones", "Recordatorios", "Correo", "Mensajes"])
        with open(os.path.join(ROOT, "data", "world1_background.json"), encoding="utf-8") as handle:
            textures = json.load(handle)["tabs"]["textures"]
        self.assertTrue(all(label in textures for label, _ in tabs))
        with open(os.path.join(ROOT, "data", "levels", "tower_test.json"), encoding="utf-8") as handle:
            self.assertEqual(build_level.tower_tabs(json.load(handle), 64), [], "La torre de prueba no lleva pestanas")


if __name__ == "__main__":
    unittest.main()
