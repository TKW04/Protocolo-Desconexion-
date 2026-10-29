"""Nivel 5-2 «Prueba gratis» (data/levels/5-2.json; paso 13 de docs/propuesta-mundo-5.md §8, 2026-10-29): esquema y
alcanzabilidad sin avisos, horizontal de 323 x 14 por plantas, la «Prueba gratis» que da la Combinación al empezar y la
persiana de la salida de «Paquete completo» (Embestida obligatoria a 8 tiles), los obstáculos de los combos en el camino
necesario (cinco persianas, cinco ranuras de precios y tres grupos de estanterías de saldos, cada uno falla sin su
combo: anti-redundancia de §3.9), las Suscripciones del Tramo 4, las cuatro protecciones de la economía (nada
obligatorio cuesta, la caja de Calc se paga con lo cogido antes, saldo nunca por debajo de 0, el atajo legítimo no va a
Devoluciones), los secretos (A con el Debug: la tienda de Calc y msg_5_2; B con el Filo; C con un Sismo bien colocado),
el camino exportado (frugal y comprador) y su duración frente al objetivo (40-55 %), escena y subidas al día y el 5-2
jugable desde la carpeta del Mundo 5. Las pasadas con mejoras, al máximo y con el tope del acceso las hace
tools/run_tests.sh sobre data/levels/*.json.
Uso: python3 tests/test_level_5_2.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "5-2.json")
SECTIONS = [("Inicio «Paquete completo»", 0, 24), ("Tramo 1 «Embestida»", 25, 90), ("Tramo 2 «Filo»", 91, 161),
            ("Pausa", 162, 166), ("Tramo 3 «Sismo»", 167, 241), ("Tramo 4 «Prueba terminada»", 242, 312),
            ("Cierre «Caja de pago»", 313, 322)]
SHUTTERS = ["persiana_salida", "persiana_banda_a", "persiana_banda_b", "persiana_pared", "persiana_t4"]
RAILS = ["ranura_suelo", "ranura_b2", "ranura_b3", "ranura_t4"]
SHELVES = ["saldos_b2", "saldos_suelo", "saldos_t4"]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def of_type(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def section_of(level, col):
    return next(s["name"] for s in level["sections"] if s["x_from"] <= col <= s["x_to"])


def lowered_validator(level):
    """Validador con las piezas de los Mundos 2-5 bajadas, como validate_level.validate."""
    import level_catalog
    import world2_model
    import world3_model
    import world4_model
    import world5_model
    cat = level_catalog.load_catalog(vl.ROOT, 5)
    level = world3_model.lower(world2_model.lower(copy.deepcopy(level), cat), cat)
    level = world5_model.lower(world4_model.lower(level, cat, ()), cat)
    rules = vl.Rules(vl.ROOT, None, vl.DEFAULT_JUMP_EFFICIENCY, vl.DEFAULT_LIMIT, False, (), ())
    return vl.Validator(level, rules), rules


class Level52Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        cls.exported = []
        cls.result = vl.validate(copy.deepcopy(cls.level), export=cls.exported)
        cls.bought = []
        cls.buy = vl.validate(copy.deepcopy(cls.level), export=cls.bought, buy=True)

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 5-2 valida sin avisos")
        self.assertTrue(self.buy["ok"], self.buy["errors"])
        self.assertEqual(self.buy["warnings"], [], "El camino del comprador, sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("5-2", "Prueba gratis", 5, 5, 540))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (323, 14),
                         "Horizontal de 14 filas (§4); 323 columnas por el presupuesto de camino (§8.1)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["debug_color"], "blanco")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": True, "combo": False}, "Todo el kit; la Combinación se obtiene en el inicio")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertEqual(lvl["checkpoints"], [{"id": "sync_1", "x": 164, "y": 5}], "sync_1 en la Pausa")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "5-3"}])

    def test_free_trial_gives_the_combo_and_the_exit_needs_the_ram(self):
        box = of_type(self.level, "free_trial_box")
        self.assertEqual([(o["params"]["id"], o["x"], o["y"]) for o in box], [("prueba_gratis", 12, 5)])
        shutter = obj(self.level, "persiana_salida")
        self.assertEqual((shutter["x"], shutter["params"]["orientation"], shutter["params"]["length_tiles"]),
                         (20, "floor", 4), "La salida es una persiana en el suelo (cols 20-23), a 8 tiles")
        steps = self.exported[0]["steps"]
        first_combo = next(i for i, s in enumerate(steps) if s["action"].startswith("combo_"))
        got = next(i for i, s in enumerate(steps) if s["action"] == "pulse"
                   and s.get("target", {}).get("type") == "dnd_switch")
        self.assertLess(got, first_combo, "La Combinación se obtiene antes del primer combo")
        self.assertEqual((steps[first_combo]["action"], steps[first_combo]["target"]["id"]),
                         ("combo_ram", "persiana_salida"))
        no_combo = copy.deepcopy(self.level)
        no_combo["objects"] = [o for o in no_combo["objects"] if o["type"] != "free_trial_box"]
        res = vl.validate(no_combo, check_schema=False)
        self.assertFalse(res["ok"], "Sin la Combinación no se sale de «Paquete completo»")

    def test_every_combo_obstacle_is_on_the_path_and_needs_its_combo(self):
        obstacles = {o["id"]: o for o in self.result["world5"]["obstacles"]}
        for oid in SHUTTERS + RAILS + SHELVES:
            self.assertEqual((obstacles[oid]["used"], obstacles[oid].get("required")), (True, True),
                             "%s en el camino y sin su combo no se llega (§3.9)" % oid)
        for oid in ("ranura_probador", "saldos_secreto"):
            self.assertFalse(obstacles[oid]["used"], "%s es de un secreto" % oid)
        actions = [s["action"] for s in self.exported[0]["steps"]]
        self.assertEqual((actions.count("combo_ram"), actions.count("combo_edge"), actions.count("combo_quake")),
                         (5, 4, 3), "12 combos: Embestidas (1 + 3 + 1), Filos (3 + 1) y Sismos (2 + 1)")
        by_section = {}
        for s in self.exported[0]["steps"]:
            if s["action"].startswith("combo_"):
                col = (s.get("at") or s.get("from"))["cell"][0]
                by_section.setdefault(section_of(self.level, col), []).append(s["action"])
        self.assertEqual(by_section["Tramo 1 «Embestida»"], ["combo_ram"] * 3)
        self.assertEqual(by_section["Tramo 2 «Filo»"], ["combo_edge"] * 3)
        self.assertEqual(by_section["Tramo 3 «Sismo»"], ["combo_quake"] * 2)
        self.assertEqual(by_section["Tramo 4 «Prueba terminada»"], ["combo_ram", "combo_edge", "combo_quake"],
                         "Tramo 4: persiana, ranura y estanterías, en ese orden")
        shelves = {e["group"]: e for e in self.result["world5"]["shelf_rule"]}
        self.assertEqual({g: (e["shelves"], e["ok"]) for g, e in shelves.items()},
                         {"saldos_b2": (3, True), "saldos_suelo": (4, True), "saldos_t4": (2, True),
                          "saldos_secreto": (2, True)}, "Ningún golpe suelto alcanza a dos del mismo grupo")

    def test_combo_ram_costs_the_air_dash_too(self):
        rams = [s for s in self.exported[0]["steps"] if s["action"] == "combo_ram"]
        self.assertTrue(all(s["energy_cost"] == 25.0 for s in rams), "Embestida = dash aéreo (10) + combo (15)")
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 25.0, "La energía nunca baja de 25 (§4.2.1)")

    def test_subscriptions_and_offers(self):
        subs = self.result["world5"]["subscriptions"]
        self.assertEqual([(s["id"], s["cancel"], s["defeat"]) for s in subs],
                         [("suscripcion_t1", "pulse", "laser"), ("suscripcion_t4_a", "pulse", "laser"),
                          ("suscripcion_t4_b", "pulse", "laser")])
        self.assertEqual(sorted(section_of(self.level, e["x"]) for e in self.level["enemies"]
                                if e["type"] == "subscription"),
                         ["Tramo 1 «Embestida»", "Tramo 4 «Prueba terminada»", "Tramo 4 «Prueba terminada»"])
        offers = [e for e in self.level["enemies"] if e["type"] == "offer_sign"]
        self.assertEqual(len(offers), 3)
        self.assertGreater(self.result["world5"]["temptation"]["min_escape_px_s"], 0)

    def test_economy_four_protections(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        boxes = [o for o in of_type(lvl, "surprise_box") if o["params"]["content"] == "points"]
        self.assertEqual((points, sum(o["params"]["amount"] for o in boxes)), (10, 2),
                         "12 puntos: 7 de ruta + la caja de 2 + 1 del secreto A + 2 del C (§4.2.1)")
        eco = self.result["world5"]["economy"]
        items = {i["id"]: i for i in eco["items"]}
        self.assertEqual({k: v["cost"] for k, v in items.items()}, {"caja_calc": 2})
        self.assertEqual(eco["total"], 2, "Comprarlo todo cuesta 2: el atajo de Calc (§4.2.1)")
        self.assertGreaterEqual(items["caja_calc"]["points_before"], 2)
        ledger = self.result["world5"]["ledger"]
        self.assertEqual((ledger["profile"], ledger["start"], ledger["spent"], ledger["min"]), ("frugal", 0, 0, 0))
        actions = {s["action"] for s in self.exported[0]["steps"]}
        self.assertFalse(actions & {"buy", "pay_door"}, "El camino frugal no paga")
        buy = self.buy["world5"]["buy"]
        self.assertEqual((buy["paid"], buy["ledger"]["min"], buy["ledger"]["refunded"]), (["caja_calc"], 0, 0),
                         "El comprador paga el atajo de Calc; lo legítimo no va a Devoluciones")
        register = obj(lvl, "caja_calc")
        self.assertNotIn("trap", register["params"], "El atajo de Calc no tiene trampa")
        chargers = sorted(o["params"]["id"] for o in of_type(lvl, "charger"))
        self.assertEqual(chargers, ["cargador_1", "cargador_2", "cargador_3", "cargador_4"],
                         "Un cargador a pie de cada tramo (§4.2.1; cuatro, ver §8.1)")
        self.assertEqual(section_of(lvl, obj(lvl, "cargador_4")["x"]), "Tramo 4 «Prueba terminada»")
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertEqual(of_type(lvl, "extra_life_pickup"), [], "Sin vida extra en el 5-2")

    def test_secret_a_calc_shop_needs_the_debug(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_tienda_calc")
        self.assertEqual((a["memory_id"], a["needs_debug"], a["gates"]), ("msg_5_2", True, ["caja_calc"]))
        self.assertEqual(sorted(a["reward"]), ["attention_points", "memory"])
        self.assertTrue(obj(self.level, "pared_tienda_calc")["params"]["visible_only_with_debug"])
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_5_2")
        self.assertEqual((memory["reachable_without_debug"], memory["reachable_with_debug"], memory["mandatory"]),
                         (False, True, False))
        self.assertEqual(section_of(self.level, obj(self.level, "caja_calc")["x"]), "Cierre «Caja de pago»",
                         "El cuarto de Calc, debajo del Cierre")

    def test_secret_b_needs_the_edge_and_c_a_placed_quake(self):
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertTrue(items["secreto_probador"]["reachable"])
        self.assertEqual(items["secreto_saldo_de_saldos"]["secret_gates_opened"], ["shelf:saldos_secreto"])
        b = next(s for s in self.level["secrets"] if s["id"] == "secreto_probador")
        self.assertEqual((b["object"], b["reward"], b["gates"]), ("power_bank_pickup", "power_bank",
                                                                 ["ranura_probador"]))
        # Sin cruzar su ranura con un Filo, el probador no se alcanza.
        val, rules = lowered_validator(self.level)
        start, _ = val.spawn_node(val.find("P")[0])
        w5 = val.model.w5
        w5.disabled_rails, w5._edge_cache, val.model._edges = frozenset({"ranura_probador"}), {}, {}
        run = val.progression(start, frozenset(), rules.limit, targets={(b["x"], b["y"])})
        self.assertFalse(run["ok"], "El probador pide el Filo")
        # C: la estantería lejana solo entra en la vista desde la columna justo antes de la primera.
        from world3_model import Pinched
        w5.disabled_rails, w5._edge_cache, val.model._edges = frozenset(), {}, {}
        gate = next(g for g in w5.gates if g.obj_id == "saldos_secreto")
        state = frozenset(g.gid for g in val.model.gates)
        near = obj(self.level, "saldos_secreto_1")["x"] + 1
        self.assertIsNotNone(w5.quake_info(gate, Pinched((near, 8)), state), "Desde junto a la primera, sí")
        self.assertIsNone(w5.quake_info(gate, Pinched((near + 2, 8)), state), "Al otro lado del pozo, no")

    def test_exported_path_and_duration(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "5-2"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("walk", "jump", "fall", "pinch", "unpinch", "combo_ram", "combo_edge", "combo_quake",
                       "cancel_subscription", "open_box", "goal"):
            self.assertIn(action, actions)
        rams = [s for s in path["steps"] if s["action"] == "combo_ram"]
        self.assertTrue(all("land_px" in s["ram"] for s in rams), "Cada Embestida dice dónde aterriza")
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_pagar")])
        seconds = self.result["plan"]["duration_s"]
        target = self.level["target_duration_s"]
        self.assertTrue(0.40 * target <= seconds <= 0.55 * target,
                        "Camino del validador entre el 40 y el 55 %% del objetivo: %.1f s de %d" % (seconds, target))
        buy_actions = [s["action"] for s in self.bought[0]["steps"]]
        self.assertIn("pay_door", buy_actions)
        self.assertLess(self.bought[0]["duration_s"], path["duration_s"], "El atajo de Calc ahorra tiempo")

    def test_checkout_door(self):
        terminal = obj(self.level, "terminal_pagar")
        self.assertEqual((terminal["params"]["text"], terminal["params"]["skin"], terminal["params"]["offline_text"]),
                         ("Pagar", "checkout", "Su prueba gratis se ha convertido en suscripción anual."))

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_5_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m5 = next(w for w in hub["worlds"] if w["id"] == "m5")
        rows = [(lv["id"], lv["playable"], lv.get("available_text")) for lv in m5["levels"]]
        self.assertEqual(rows, [("5-1", True, None), ("5-2", True, "Nueva oferta"), ("5-3", True, "Nueva oferta"),
                                ("5-boss", False, None)], "5-2 y 5-3 jugables (paso 14); el jefe, «Próximamente»")
        icon = m5["levels"][1]["icon"]
        self.assertTrue(os.path.exists(os.path.join(ROOT, icon[len("res://"):])), icon)
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "5-2.tscn")))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_5_2"]
        self.assertEqual((msg["level"], msg["secret"], msg["sender"], msg["world"], msg["first_lap"], msg["subject"]),
                         ("5-2", "secreto_tienda_calc", "Abuelito", 5, 1, "Herramientas"))
        self.assertLessEqual(len(msg["text"]), 280)


if __name__ == "__main__":
    unittest.main()
