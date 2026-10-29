"""Nivel 5-1 «Oferta del día» (data/levels/5-1.json; paso 10 de docs/propuesta-mundo-5.md §8, 2026-10-29):
esquema y alcanzabilidad sin avisos, horizontal de 260 x 14 por plantas (tres pasadas por tramo, que suben y bajan),
la tentación (patrón 23), la tienda, las cajas sorpresa (patrón 24), la Suscripción suelta, el atajo con trampa y la
cuenta regresiva sobre el foso (patrón 28), las cuatro protecciones de la economía (nada obligatorio cuesta, todo se
paga con lo cogido antes en el nivel, saldo nunca por debajo de 0, Devoluciones en el secreto A), los secretos (A con
el Debug y sin dash, B y C con el dash aéreo), el camino exportado (frugal y comprador) y su duración frente al
objetivo (40-55 %), escena y subidas al día, la puerta «Pagar» y el 5-1 jugable desde la carpeta del Mundo 5. Las
pasadas con mejoras, al máximo y con el tope del acceso las hace tools/run_tests.sh sobre data/levels/*.json.
Uso: python3 tests/test_level_5_1.py
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "5-1.json")
SECTIONS = [("Inicio «Entrada»", 0, 13), ("Tramo 1 «Pasillo de ofertas»", 14, 80), ("Tramo 2 «Primera tienda»", 81, 135),
            ("Pausa", 136, 140), ("Tramo 3 «Caja sorpresa»", 141, 195), ("Tramo 4 «Atajo»", 196, 249),
            ("Cierre «Caja de pago»", 250, 259)]


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def of_type(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def section_of(level, col):
    return next(s["name"] for s in level["sections"] if s["x_from"] <= col <= s["x_to"])


def without(level, *abilities):
    out = copy.deepcopy(level)
    for name in abilities:
        out["abilities_available"][name] = False
    return vl.validate(out, check_schema=False)


class Level51Test(unittest.TestCase):
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
        self.assertEqual(self.result["warnings"], [], "El 5-1 valida sin avisos")
        self.assertTrue(self.buy["ok"], self.buy["errors"])
        self.assertEqual(self.buy["warnings"], [], "El camino del comprador, sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("5-1", "Oferta del día", 5, 4, 480))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (260, 14), "Horizontal de 14 filas (§4)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["debug_color"], "blanco", "Debug blanco en el Mundo 5")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": True}, "Todo el kit salvo la Combinación (§4.1)")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertEqual(lvl["checkpoints"], [{"id": "sync_1", "x": 138, "y": 11}], "sync_1 en la Pausa (doc)")
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "5-2"}])
        for row in (6, 9):
            self.assertGreater(lvl["grid"][row].count("-"), 150, "Bandas de una vía en la fila %d" % row)

    def test_plants_force_three_passes(self):
        """Por plantas (§4, §11.1): el camino recorre las bandas casi enteras, sin atajos verticales."""
        walked = sum(abs(s["to"]["cell"][0] - s["from"]["cell"][0]) for s in self.exported[0]["steps"]
                     if s["action"] in ("walk", "resist_pull"))
        self.assertGreater(walked, 550, "Tiles andados en horizontal: %d" % walked)
        rows = {s["to"]["cell"][1] for s in self.exported[0]["steps"] if s["action"] in ("walk", "resist_pull")}
        self.assertTrue({11, 8, 5} <= rows, "Las tres pasadas: suelo, B2 y B3")

    def test_economy_four_protections(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        boxes = [o for o in of_type(lvl, "surprise_box") if o["params"]["content"] == "points"]
        a = next(s for s in lvl["secrets"] if s["id"] == "secreto_devoluciones")
        self.assertEqual((points, sum(o["params"]["amount"] for o in boxes), a["points"]), (8, 2, 2),
                         "12 puntos: 8 en la rejilla + la caja de 2 + los 2 de Devoluciones (§4.1.1)")
        eco = self.result["world5"]["economy"]
        items = {i["id"]: i for i in eco["items"]}
        self.assertEqual({k: v["cost"] for k, v in items.items()},
                         {"tienda_sync": 3, "tienda_energia": 2, "atajo_dos_plantas": 3})
        self.assertEqual(eco["total"], 8, "Comprarlo todo cuesta 8 (§4.1.1)")
        # (2) todo se paga con lo cogido antes en el nivel, desde un saldo de 0.
        for item in items.values():
            self.assertGreaterEqual(item["points_before"], item["cost"], item["id"])
        # (1) nada obligatorio cuesta: el camino frugal no paga nada y la puerta del atajo no es obligatoria.
        ledger = self.result["world5"]["ledger"]
        self.assertEqual((ledger["profile"], ledger["start"], ledger["spent"]), ("frugal", 0, 0))
        actions = {s["action"] for s in self.exported[0]["steps"]}
        self.assertFalse(actions & {"buy", "pay_door", "open_box"}, "El camino frugal no compra ni abre a ciegas")
        # (3) sin deuda: el saldo nunca baja de 0, ni frugal ni comprador.
        self.assertEqual(ledger["min"], 0)
        buy = self.buy["world5"]["buy"]
        self.assertEqual(buy["ledger"]["min"], 0)
        self.assertEqual(buy["paid"], ["atajo_dos_plantas"], "El comprador paga el atajo")
        self.assertEqual(buy["bought"], ["tienda_energia"], "Y lo que le deja la reserva del atajo")
        # (4) Devoluciones en el secreto A.
        desk = of_type(lvl, "refund_desk")
        self.assertEqual([(o["params"]["id"], section_of(lvl, o["x"])) for o in desk], [("devoluciones_5_1", "Pausa")])
        door = obj(lvl, "atajo_dos_plantas")
        self.assertEqual((door["params"]["trap"], door["x"], door["y"]), ("subscription", 240, 3),
                         "El atajo esconde una Suscripción (doc)")
        chargers = {o["params"]["id"]: o for o in of_type(lvl, "charger")}
        self.assertEqual(sorted(chargers), ["cargador_1", "cargador_2"])
        self.assertTrue(all(c["params"]["reusable"] and c["params"]["amount"] == 50.0
                            and c["params"]["cooldown_s"] == 10.0 for c in chargers.values()))
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertGreaterEqual(self.result["plan"]["energy"]["min"], 50.0, "Energía de sobra")

    def test_shop_boxes_offers_and_countdown(self):
        lvl = self.level
        shops = {o["params"]["product"]: (o["x"], o["y"]) for o in of_type(lvl, "shop_item")}
        self.assertEqual(shops, {"sync": (104, 8), "energy": (106, 8)}, "La tienda, a mitad de B2 del Tramo 2")
        self.assertEqual(sorted(o["params"]["content"] for o in of_type(lvl, "surprise_box")),
                         ["empty", "energy", "points", "subscription"], "Patrón 24")
        self.assertTrue(all(section_of(lvl, o["x"]) == "Tramo 3 «Caja sorpresa»" and o["y"] == 5
                            for o in of_type(lvl, "surprise_box")), "En la banda alta del Tramo 3")
        self.assertFalse(any(b["blocks_path"] for b in self.result["world5"]["boxes"]), "Ninguna tapa el camino")
        offers = [e for e in lvl["enemies"] if e["type"] == "offer_sign"]
        self.assertEqual(len(offers), 6)
        self.assertEqual(lvl["grid"][11][17], "^", "El carrito con pinchos junto a la Oferta de pie (patrón 23)")
        self.assertGreater(self.result["world5"]["resist_pull"], 10, "Tramos andando contra el tirón")
        self.assertGreater(self.result["world5"]["temptation"]["min_escape_px_s"], 0, "Siempre se sale andando")
        subs = self.result["world5"]["subscriptions"]
        self.assertEqual([(s["id"], s["cancel"]) for s in subs], [("suscripcion_t3", "pulse")])
        countdown = of_type(lvl, "countdown_platform")
        self.assertEqual([(o["params"]["id"], o["x"], o["params"]["width_tiles"]) for o in countdown],
                         [("cuenta_foso", 246, 3)])
        self.assertEqual([lvl["grid"][r][245:250] for r in (12, 13)], [".....", "....."], "Foso mortal")

    def test_secret_a_refunds_need_the_debug_without_dash(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_devoluciones")
        self.assertEqual((a["memory_id"], a["needs_debug"], a["forbid_abilities"]), ("msg_5_1", True, ["dash"]))
        self.assertEqual(sorted(a["reward"]), ["attention_points", "memory"])
        wall = obj(self.level, "pared_devoluciones")
        self.assertTrue(wall["params"]["visible_only_with_debug"])
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_5_1")
        self.assertEqual((memory["reachable_without_debug"], memory["reachable_with_debug"], memory["mandatory"]),
                         (False, True, False))

    def test_secrets_b_and_c_need_the_air_dash(self):
        b = next(s for s in self.level["secrets"] if s["id"] == "secreto_oferta_de_verdad")
        c = next(s for s in self.level["secrets"] if s["id"] == "secreto_vida_extra")
        self.assertEqual((b["object"], b["reward"]), ("power_bank_pickup", "power_bank"))
        self.assertEqual((c["object"], c["reward"]), ("extra_life_pickup", "extra_life"))
        lives = of_type(self.level, "extra_life_pickup")
        self.assertEqual([(o["params"]["id"], o["params"]["secret_id"]) for o in lives], [("vida_extra_5_1", "C")],
                         "La vida extra del Mundo 5 (N = 3: la anterior fue la del 4-1)")
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertTrue(items["secreto_oferta_de_verdad"]["reachable"])
        no_dash = without(self.level, "dash")
        items = {i["id"]: i for i in no_dash["secrets"]["items"]}
        self.assertFalse(items["secreto_oferta_de_verdad"]["reachable"], "Sin el dash aéreo no se llega a B")
        self.assertFalse(items["secreto_vida_extra"]["reachable"], "Ni a C")
        self.assertEqual([e for e in no_dash["errors"] if "secreto" not in e["message"]
                          and "vida_extra" not in e["message"]], [], "El camino principal no necesita el dash")

    def test_exported_path_and_duration(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "5-1"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("walk", "jump", "fall", "resist_pull", "cancel_subscription", "goal"):
            self.assertIn(action, actions)
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_pagar")])
        seconds = self.result["plan"]["duration_s"]
        target = self.level["target_duration_s"]
        self.assertTrue(0.40 * target <= seconds <= 0.55 * target,
                        "Camino del validador entre el 40 y el 55 %% del objetivo (§4): %.1f s de %d" % (seconds, target))
        self.assertEqual(self.result["world5"]["budget"]["target_s"], 480)
        # El comprador: paga la puerta, cancela la Suscripción de la trampa y llega antes.
        buy_actions = [s["action"] for s in self.bought[0]["steps"]]
        for action in ("pay_door", "buy", "cancel_subscription"):
            self.assertIn(action, buy_actions)
        self.assertLess(self.bought[0]["duration_s"], path["duration_s"], "El atajo ahorra las dos plantas")

    def test_checkout_door(self):
        terminal = obj(self.level, "terminal_pagar")
        self.assertEqual((terminal["params"]["text"], terminal["params"]["skin"], terminal["params"]["offline_text"]),
                         ("Pagar", "checkout", "Total: 0. Gracias por mirar."))
        with open(os.path.join(ROOT, "data", "world1_objects.json"), encoding="utf-8") as handle:
            skins = json.load(handle)["exit_terminal"]["skins"]
        res = skins["checkout"]
        self.assertTrue(os.path.exists(os.path.join(ROOT, res[len("res://"):])), res)
        done = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "gen_world5_exit_checkout.py"),
                               "--check"], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)

    def test_scene_and_climbs_are_up_to_date(self):
        for cmd in (["build_level.py", "--check", LEVEL_PATH], ["level_climbs.py", "--check", LEVEL_PATH]):
            done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", cmd[0])] + cmd[1:],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, "%s: %s" % (cmd[0], done.stdout + done.stderr))

    def test_playable_from_the_world_5_folder(self):
        with open(os.path.join(ROOT, "data", "hub.json"), encoding="utf-8") as handle:
            hub = json.load(handle)
        m5 = next(w for w in hub["worlds"] if w["id"] == "m5")
        self.assertEqual((m5["unlocked_by"], m5["requires_upgrade"], m5["page"], m5["col"]),
                         (["4-boss"], "hub_update_4_6", 2, 14), "Reglas de desbloqueo sin cambios")
        self.assertEqual(m5["miniature"], "res://assets/sprites/hub/icons/world_icon_m5_00.png")
        rows = [(lv["id"], lv["name"], lv["playable"], lv.get("kind"), lv.get("available_text")) for lv in m5["levels"]]
        self.assertEqual(rows, [("5-1", "Oferta del día", True, None, None),
                                ("5-2", "Prueba gratis", False, None, "Nueva oferta"),
                                ("5-3", "Última oportunidad", False, None, "Nueva oferta"),
                                ("5-boss", "El Vendedor", False, "boss", None)])
        self.assertTrue(all(lv["laps"] == [1] for lv in m5["levels"]))
        for entry in [m5] + m5["levels"]:
            res = entry.get("icon", entry.get("miniature"))
            self.assertTrue(os.path.exists(os.path.join(ROOT, res[len("res://"):])), res)
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "5-1.tscn")))
        remark = next(r for r in hub["calc"]["remarks"] if r["after_level"] == "5-1")
        self.assertIn("{gastado}", remark["text"])
        self.assertEqual(remark["text_if_zero"], "Gastado fuera: 0. Bien.")
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_5_1"]
        self.assertEqual((msg["level"], msg["secret"], msg["sender"], msg["world"], msg["first_lap"]),
                         ("5-1", "secreto_devoluciones", "Abuelito", 5, 1))
        self.assertLessEqual(len(msg["text"]), 280)


if __name__ == "__main__":
    unittest.main()
