"""Nivel 1-3 «No molestar» (data/levels/1-3.json; paso 10 de docs/propuesta-1-3.md §7, 2026-10-20):
esquema y alcanzabilidad sin avisos, estructura y tramos, obtencion del gesto Deslizar en la sala
«Ajustes», banner obligatorio con el dash, ritmo de las plataformas, tunel de alarmas, secretos
(A con el Debug y sin el dash; B y C solo con el dash aereo), economia, camino exportado, escena y
subidas al dia, y el 1-3 jugable desde el hub.
Uso: python3 -m unittest tests/test_level_1_3.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "1-3.json")
SECTIONS = [("Inicio: Ajustes", 0, 22), ("Tramo 1: Silenciados", 23, 72), ("Tramo 2: Vibración", 73, 130),
            ("Tramo 3: Interrupciones", 131, 185), ("Tramo 4: Alarmas", 186, 240),
            ("Cierre: Pantalla de bloqueo", 241, 259)]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def enemy(level, eid):
    return next(e for e in level["enemies"] if e["id"] == eid)


def section_of(level, col):
    return next(s["name"] for s in level["sections"] if s["x_from"] <= col <= s["x_to"])


class Level13Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 1-3 valida sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("1-3", "No molestar", 1, 3, 360))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (260, 14), "Horizontal de 260 x 14 (§3.0)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["abilities_available"], {"pulse": True, "laser": True, "debug": True, "dash": False},
                         "Pulso, laser y Debug del 1-1 y el 1-2; el dash se obtiene en «Ajustes»")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertNotIn("stands_for", lvl, "El 1-3 real es el subnivel 1-3 (stands_for solo en salas *_test)")
        # Suelo general en la fila 10 (Isak de pie en la 9), como el 1-1.
        start = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "P")
        goal = next((c, r) for r, row in enumerate(lvl["grid"]) for c, ch in enumerate(row) if ch == "G")
        self.assertEqual(start, (4, 9), "Vortice de llegada en (4, 9)")
        self.assertEqual(section_of(lvl, goal[0]), "Cierre: Pantalla de bloqueo")
        terminal = obj(lvl, "terminal_bloqueo")
        self.assertEqual((terminal["type"], terminal["x"], terminal["y"]), ("exit_terminal", goal[0], goal[1] - 1))
        self.assertEqual(lvl["unlocks"], [], "Alerta Mayor aun no existe: la terminal vuelve al hub")
        cps = {c["id"]: (c["x"], c["y"]) for c in lvl["checkpoints"]}
        self.assertEqual(cps, {"sync_1": (75, 9), "sync_2": (187, 9)}, "Al entrar a los Tramos 2 y 4")

    def test_economy(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        secret_points = sum(int(s.get("points", 0)) for s in lvl["secrets"])
        self.assertEqual((points, points - secret_points, secret_points), (9, 6, 3), "6 en la ruta + 3 en secretos")
        chargers = {o["params"]["id"]: o for o in lvl["objects"] if o["type"] == "charger"}
        self.assertEqual(sorted(chargers), ["cargador_1", "cargador_2", "cargador_3"])
        self.assertTrue(all(c["params"]["reusable"] and c["params"]["cooldown_s"] == 10.0 for c in chargers.values()))
        self.assertLess(chargers["cargador_1"]["x"], 27, "cargador_1 antes del banner obligatorio")
        self.assertEqual(chargers["cargador_2"]["x"] - 75, 2, "cargador_2 junto a sync_1")
        self.assertEqual(chargers["cargador_3"]["x"] - 187, 2, "cargador_3 junto a sync_2")
        banks = [o for o in lvl["objects"] if o["type"] == "power_bank_pickup"]
        self.assertEqual(len(banks), 1, "Un power bank vacio, en el secreto C")
        self.assertFalse([o for o in lvl["objects"] if o["type"] == "extra_life_pickup"], "Sin vida extra (N = 3)")
        self.assertEqual(self.result["plan"]["sync_damage"], 0.0, "Sin dano de puntos rojos en el camino")
        self.assertTrue(all(b["hits"] == 0 for b in self.result["plan"]["badges"]))

    def test_dash_is_obtained_in_ajustes_and_the_first_banner_needs_it(self):
        sw = obj(self.level, "dnd_1_3")
        self.assertEqual((sw["type"], sw["x"], sw["y"], sw["params"]["ability"], sw["params"]["story_line"]),
                         ("dnd_switch", 14, 9, "dash", "dnd_1_3"))
        gate = next(g for g in self.result["gates"] if g["id"] == "dnd_1_3")
        self.assertEqual(gate["ability"], "dash")
        # 1a: pasillo de techo bajo (filas 8-9 libres, la 7 solida) sin nicho, banner hacia Isak.
        banner = enemy(self.level, "banner_dash")
        p = banner["params"]
        self.assertEqual((banner["x"], banner["y"], banner["help_id"]), (38, 9, "spam_banner_dash"))
        self.assertEqual((p["direction"], p["corridor_tiles"], p["sweep_speed_px_s"], p["interval_s"],
                          p["knockback_to_entry"]), (-1, 12, 320.0, 3.0, True))
        grid = self.level["grid"]
        for col in range(27, 39):
            self.assertEqual((grid[7][col], grid[8][col], grid[9][col] in ".E"), ("#", ".", True), "columna %d" % col)
        self.assertEqual(self.level["validation"]["dash_required"], ["banner_dash"])
        # Holgura de tiempo del bot frente a banners, campanas y ritmo (2026-10-20, paso 11).
        self.assertEqual(self.level["validation"]["hazard_margin_s"], 0.1)
        item = next(b for b in self.result["plan"]["banners"] if "banner_dash" in b["banners"])
        req = item["dash_required"]["banner_dash"]
        self.assertEqual((req["without_dash_walking"], req["without_dash_running"], req["with_dash"]),
                         (False, False, True), "Solo se cruza con el dash")
        self.assertGreaterEqual(req["dash_window_s"], 0.3, "Ventana minima del dash de 0,3 s")
        # El primer uso obligatorio del dash tiene un cargador a pie (regla anti-atasco).
        self.assertGreater(self.result["plan"]["energy"]["min"], 0.0)

    def test_rhythm_platforms_and_tunnel(self):
        zone = obj(self.level, "ritmo_2")
        self.assertEqual((zone["type"], zone["params"]["tempo_steps_s"], zone["params"]["loop"],
                          zone["params"]["start"]), ("rhythm_zone", [3.2, 2.6, 2.0], True, "on_enter"))
        blinks = [o for o in self.level["objects"] if o["type"] == "blink_platform"]
        self.assertEqual(len(blinks), 5, "2a: A y B; 2b: A, B y C")
        self.assertTrue(all(o["params"]["rhythm"] == "ritmo_2" for o in blinks))
        self.assertTrue(all(section_of(self.level, o["x"]) == "Tramo 2: Vibración" for o in blinks))
        tunnel = obj(self.level, "tunel_alarmas")
        self.assertEqual([s["cycle_s"] for s in tunnel["params"]["stages"]], [2.0, 1.6, 1.4], "Se acelera por posicion")
        bells = [e for e in self.level["enemies"] if e["type"] == "alarm_bell"]
        self.assertEqual(len(bells), 9)
        self.assertTrue(all(e["params"]["rhythm"] == "tunel_alarmas" for e in bells))
        rhythm_banners = [e["id"] for e in self.level["enemies"]
                          if e["type"] == "spam_banner" and e["params"].get("rhythm") == "tunel_alarmas"]
        self.assertEqual(rhythm_banners, ["banner_4a", "banner_4b", "banner_4c"])
        items = self.result["plan"]["banners"]
        blink_items = [b for b in items if b["blinks"]]
        self.assertEqual(sorted(i for b in blink_items for i in b["blinks"]), sorted(o["params"]["id"] for o in blinks),
                         "El plan cruza todas las plataformas al compas")
        tunnel_item = next(b for b in items if b["bells"])
        self.assertEqual(sorted(tunnel_item["bells"]), sorted(e["id"] for e in bells))
        self.assertEqual(tunnel_item["rhythm"], ["tunel_alarmas"])

    def test_secret_a_excepciones_needs_the_debug_and_not_the_dash(self):
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        a = items["secreto_excepciones"]
        self.assertEqual((a["without_debug"], a["with_debug"], a["forbid_abilities"]), (False, True, ["dash"]))
        wall = obj(self.level, "pared_excepciones")
        self.assertEqual((wall["type"], wall["x"], wall["y"], wall["params"]["visible_only_with_debug"]),
                         ("glitch_wall", 120, 3, True))
        pickup = obj(self.level, "mensaje_1_3")
        self.assertEqual((pickup["type"], pickup["x"], pickup["y"], pickup["params"]["memory_id"]),
                         ("memory_pickup", 125, 4, "msg_1_3"), "En su celda de §5.4")
        panel = obj(self.level, "panel_excepciones")
        self.assertEqual((panel["params"]["title"], panel["params"]["contacts"]),
                         ("Permitir llamadas de: Favoritos", ["Mamá", "Abuelito"]))
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_1_3")
        self.assertEqual((memory["secret"], memory["reachable_without_debug"], memory["reachable_with_debug"],
                          memory["mandatory"]), ("secreto_excepciones", False, True, False))

    def test_secrets_b_and_c_need_the_air_dash(self):
        """B (repisa sobre el 1c) y C (repisa a la salida del tunel) estan a 4 tiles en horizontal y 4 filas
        sobre el suelo: con el dash se alcanzan; sin el interruptor «No molestar» (sin dash), no. Sin
        enemigos para que la comprobacion sea rapida (no cambian la geometria)."""
        base = copy.deepcopy(self.level)
        base["grid"] = [row.replace("E", ".") for row in base["grid"]]
        base["enemies"] = []
        base["validation"].pop("dash_required")
        with_dash = vl.validate(copy.deepcopy(base), check_schema=False)
        no_dash = copy.deepcopy(base)
        no_dash["objects"] = [o for o in no_dash["objects"] if o["type"] != "dnd_switch"]
        without = vl.validate(no_dash, check_schema=False)
        for sid in ("secreto_silenciados", "secreto_alarma_pospuesta"):
            yes = next(i for i in with_dash["secrets"]["items"] if i["id"] == sid)
            self.assertTrue(yes["reachable"], "%s con el dash" % sid)
            no = next(i for i in without["secrets"]["items"] if i["id"] == sid)
            self.assertFalse(no["reachable"], "%s sin el dash" % sid)
        bank = next(o for o in self.level["objects"] if o["type"] == "power_bank_pickup")
        c = next(s for s in self.level["secrets"] if s["id"] == "secreto_alarma_pospuesta")
        self.assertEqual((bank["x"], bank["y"]), (c["x"], c["y"]))
        self.assertEqual((c["reward"], c["points"]), (["power_bank", "attention_points"], 1))

    def test_exported_path(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "1-3"))
        steps = path["steps"]
        actions = [s["action"] for s in steps]
        for action in ("pulse", "dash", "wait_beat", "wait_phase", "charge", "goal"):
            self.assertIn(action, actions)
        first_pulse = next(s for s in steps if s["action"] == "pulse")
        self.assertEqual((first_pulse["target"]["type"], first_pulse.get("face_back")), ("dnd_switch", True),
                         "Lo primero: el pulso de espaldas al interruptor «No molestar»")
        dashes = [s for s in steps if s["action"] == "dash"]
        self.assertGreater(dashes[0]["i"], first_pulse["i"], "Ningun dash antes de obtener el gesto")
        self.assertTrue(26 <= dashes[0]["from"]["cell"][0] and dashes[0]["to"]["cell"][0] <= 39,
                        "El primer dash cruza el pasillo obligatorio")
        finals = [s for s in steps if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_bloqueo")])
        self.assertEqual(actions[-1], "goal")
        self.assertTrue(all(s.get("energy_after", 1.0) >= 0.0 for s in steps))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_hub_after_the_1_2(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m1 = next(w for w in hub["worlds"] if w["id"] == "m1")
        entry = next(lv for lv in m1["levels"] if lv["id"] == "1-3")
        self.assertEqual((entry["name"], entry["playable"]), ("No molestar", True))
        with open(os.path.join(ROOT, "data", "levels", "1-2.json"), encoding="utf-8") as handle:
            self.assertIn({"type": "level", "id": "1-3"}, json.load(handle)["unlocks"])
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "1-3.tscn")))


if __name__ == "__main__":
    unittest.main()
