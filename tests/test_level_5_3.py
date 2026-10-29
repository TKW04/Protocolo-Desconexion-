"""Nivel 5-3 «Última oportunidad» (data/levels/5-3.json; paso 14 de docs/propuesta-mundo-5.md §8, 2026-10-29): esquema y
alcanzabilidad sin avisos, horizontal de 315 x 14 por plantas, con la Combinación al entrar; Tramo 1 de cuentas regresivas
encadenadas sobre fosos y huecos de las bandas con Ofertas al otro lado; Tramo 2 de cajas sorpresa en cadena (siete que
tapan el camino en tres grupos, sin cargador, una de energía por grupo, las peligrosas se miran con el Debug y se
destruyen con el láser: orden seguro); Tramo 3 con la tienda, el atajo con trampa «Verificando pago…», las
Suscripciones, Términos y condiciones (rechazar con el láser) y las estanterías de saldos (Sismo); Tramo 4 sobre la
lista de deseos sin pararse; las cuatro protecciones de la economía; los secretos (A: el tachón con el Debug y msg_5_3,
sin dash; B: la trastienda a oscuras con la Linterna; C: la última caja tras salto + dash aéreo); el camino exportado
(frugal y comprador) y su duración frente al objetivo (40-55 %); escena y subidas al día; el 5-3 jugable desde la
carpeta del Mundo 5 y la fila de El Vendedor desbloqueada (jugable desde el paso 18). Las dos validaciones (frugal y comprador)
se lanzan en paralelo en dos procesos (cada una tarda unos 2,5 min). Las pasadas con mejoras, al máximo y con el tope
del acceso las hace tools/run_tests.sh sobre data/levels/*.json.
Uso: python3 tests/test_level_5_3.py
"""

import concurrent.futures
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

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "5-3.json")
SECTIONS = [("Inicio «Rebajas finales»", 0, 19), ("Tramo 1 «Solo por hoy»", 20, 100),
            ("Tramo 2 «Cajas en cadena»", 101, 181), ("Pausa", 182, 186), ("Tramo 3 «Todo a la vez»", 187, 272),
            ("Pausa", 273, 277), ("Tramo 4 «Lista de deseos»", 278, 304), ("Cierre «Pago realizado»", 305, 314)]
PATH_BOXES = {"caja_g1_1": "energy", "caja_g1_2": "points", "caja_g1_3": "subscription", "caja_g2_1": "empty",
              "caja_g2_2": "offer", "caja_g2_3": "energy", "caja_g3_1": "energy"}


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def _variant(name):
    """Variantes del 5-3 para los negativos: sin el Debug, sin la Linterna (sin el flashlight_pickup) y con el
    secreto C sin dash."""
    level = load_level()
    if name == "no_debug":
        level["abilities_available"]["debug"] = False
    elif name == "no_lamp":
        level["objects"] = [o for o in level["objects"] if o["type"] != "flashlight_pickup"]
    elif name == "c_no_dash":
        next(s for s in level["secrets"] if s["id"] == "secreto_ultima_caja")["forbid_abilities"] = ["dash"]
    return level


def _run(buy, variant=None):
    """Validacion completa en un proceso aparte: (resultado, caminos exportados)."""
    exported = []
    if variant is None:
        result = vl.validate(load_level(), export=exported, buy=buy)
    else:
        result = vl.validate(_variant(variant), check_schema=False)
    return result, exported


def obj(level, oid):
    return next(o for o in level["objects"] if o["params"].get("id") == oid)


def of_type(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def section_of(level, col):
    return next(s["name"] for s in level["sections"] if s["x_from"] <= col <= s["x_to"])


class Level53Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load_level()
        with concurrent.futures.ProcessPoolExecutor(max_workers=5) as pool:
            frugal, bought = pool.submit(_run, False), pool.submit(_run, True)
            variants = {name: pool.submit(_run, False, name) for name in ("no_debug", "no_lamp", "c_no_dash")}
            cls.result, cls.exported = frugal.result()
            cls.buy, cls.bought = bought.result()
            cls.variants = {name: job.result()[0] for name, job in variants.items()}

    def test_schema_and_reachability_without_warnings(self):
        self.assertEqual(vls.validate_level(self.level), [])
        self.assertTrue(self.result["ok"], self.result["errors"])
        self.assertEqual(self.result["warnings"], [], "El 5-3 valida sin avisos")
        self.assertTrue(self.buy["ok"], self.buy["errors"])
        self.assertEqual(self.buy["warnings"], [], "El camino del comprador, sin avisos")

    def test_structure_and_sections(self):
        lvl = self.level
        self.assertEqual((lvl["id"], lvl["name"], lvl["world"], lvl["difficulty"], lvl["target_duration_s"]),
                         ("5-3", "Última oportunidad", 5, 5, 600))
        self.assertEqual((len(lvl["grid"][0]), len(lvl["grid"])), (315, 14),
                         "Horizontal de 14 filas (§4); 315 columnas por el presupuesto de camino (§8.1)")
        self.assertEqual(lvl["camera"]["vertical"], "simple")
        self.assertEqual(lvl["abilities_available"],
                         {"pulse": True, "laser": True, "debug": True, "dash": True, "ground_pound": True,
                          "compress": True, "combo": True}, "Todo el kit, con la Combinación")
        self.assertEqual([(s["name"], s["x_from"], s["x_to"]) for s in lvl["sections"]], SECTIONS)
        self.assertEqual([c["id"] for c in lvl["checkpoints"]], ["sync_1", "sync_2"])
        self.assertEqual(lvl["unlocks"], [{"type": "level", "id": "5-boss"}], "Desbloquea la fila de El Vendedor")
        self.assertTrue(lvl["validation"]["laser_required"], "«rechazar» solo con el láser")

    def test_tramo_1_chained_countdowns(self):
        cds = of_type(self.level, "countdown_platform")
        by = {}
        for o in cds:
            by.setdefault(section_of(self.level, o["x"]), []).append(o["params"]["id"])
        self.assertEqual(len(by["Tramo 1 «Solo por hoy»"]), 9, "Nueve cuentas en las tres pasadas del Tramo 1")
        self.assertEqual(set(by), {"Tramo 1 «Solo por hoy»"})
        grid = self.level["grid"]
        for o in cds:
            if o["y"] == 12:
                self.assertEqual(grid[13][o["x"]], ".", "%s sobre un foso mortal" % o["params"]["id"])
        offers = [e for e in self.level["enemies"] if e["type"] == "offer_sign"
                  and section_of(self.level, e["x"]) == "Tramo 1 «Solo por hoy»"]
        self.assertEqual(len(offers), 3, "Ofertas al otro lado de los huecos de las bandas (patrón 28)")
        cd_ids = {o["params"]["id"] for o in cds}
        landed = {s.get("countdown") for s in self.exported[0]["steps"] if s["action"] == "wait_countdown"}
        self.assertTrue(landed <= cd_ids, "Las esperas del camino son de las cuentas del nivel")

    def test_tramo_2_boxes_in_chain_with_a_safe_order(self):
        boxes = {b["id"]: b for b in self.result["world5"]["boxes"]}
        self.assertEqual({k: (v["content"], v["blocks_path"]) for k, v in boxes.items() if k in PATH_BOXES},
                         {k: (c, True) for k, c in PATH_BOXES.items()}, "Siete cajas tapan el camino")
        self.assertEqual(len(boxes), 8, "Ocho cajas (las siete del camino y la del secreto C)")
        self.assertFalse(boxes["caja_secreto_c"]["blocks_path"])
        for group in ("g1", "g2", "g3"):
            self.assertIn("energy", [c for k, c in PATH_BOXES.items() if "_%s_" % group in k],
                          "Una caja de energía en cada grupo")
        t2 = [o for o in of_type(self.level, "charger") if section_of(self.level, o["x"]) == "Tramo 2 «Cajas en cadena»"]
        self.assertEqual(t2, [], "Sin cargador en el Tramo 2")
        self.assertGreaterEqual(self.result["world5"]["boxes_energy_left"], 0)
        steps = self.exported[0]["steps"]
        opened = {s["target"]["id"]: s for s in steps if s["action"] == "open_box"}
        self.assertEqual(set(opened), set(PATH_BOXES))
        for oid in ("caja_g1_3", "caja_g2_2"):
            self.assertEqual((opened[oid]["with"], opened[oid].get("looked")), ("laser", True),
                             "%s: el Debug enseña lo que daña y el láser la destruye sin abrirla" % oid)
        for oid in set(PATH_BOXES) - {"caja_g1_3", "caja_g2_2"}:
            self.assertEqual(opened[oid]["with"], "pulse", "%s se abre con el pulso" % oid)
        looks = [s for s in steps if s["action"] == "debug_on" and s.get("target", {}).get("type") == "surprise_box"]
        self.assertEqual(len(looks), 2, "Solo se miran las dos peligrosas (energía para mirar pocas)")
        # Sin el Debug, las peligrosas tapan el camino sin aviso.
        self.assertTrue(any("sin aviso" in e["message"] for e in self.variants["no_debug"]["errors"]),
                        self.variants["no_debug"]["errors"])

    def test_tramo_3_shop_shortcut_terms_and_shelves(self):
        w5 = self.result["world5"]
        self.assertEqual([(t["id"], t["via"]) for t in w5["terms"]], [("terminos_t3", "laser")])
        obstacles = {o["id"]: o for o in w5["obstacles"]}
        self.assertEqual((obstacles["saldos_t3"]["used"], obstacles["saldos_t3"].get("required")), (True, True),
                         "Las estanterías del Tramo 3 exigen el Sismo (§3.9)")
        door = obj(self.level, "atajo_verificando")
        self.assertEqual(door["params"]["trap"], "processing")
        self.assertEqual(section_of(self.level, door["x"]), "Tramo 3 «Todo a la vez»")
        subs = self.result["world5"]["subscriptions"]
        self.assertEqual(sorted((s["id"], s["cancel"], s["defeat"]) for s in subs),
                         [("suscripcion_t3_a", "pulse", "laser"), ("suscripcion_t3_b", "pulse", "laser")])
        offers = {section_of(self.level, e["x"]) + str(e["y"]) for e in self.level["enemies"]
                  if e["type"] == "offer_sign" and section_of(self.level, e["x"]) == "Tramo 3 «Todo a la vez»"}
        self.assertEqual(len(offers), 3, "Ofertas en las tres plantas del Tramo 3")
        self.assertEqual(sorted(o["params"]["product"] for o in of_type(self.level, "shop_item")), ["energy", "sync"])

    def test_tramo_4_wishlist_without_stops(self):
        wishes = of_type(self.level, "wishlist_platform")
        self.assertEqual(len(wishes), 4)
        self.assertTrue(all(section_of(self.level, o["x"]) == "Tramo 4 «Lista de deseos»" for o in wishes))
        self.assertEqual(self.result["world5"]["wish_stops"], [], "Ninguna parada sobre un deseo")
        self.assertEqual(self.buy["world5"]["wish_stops"], [])
        grid = self.level["grid"]
        x0 = next(s["x_from"] for s in self.level["sections"] if s["name"] == "Tramo 4 «Lista de deseos»")
        self.assertIn("^", grid[11][x0:x0 + 20], "Planta baja con pinchos (−10, con salida)")
        self.assertEqual(grid[12][x0:x0 + 20], "#" * 20, "Con suelo: no es un foso mortal")

    def test_economy_four_protections(self):
        lvl = self.level
        points = "".join(lvl["grid"]).count("o")
        boxes = [o for o in of_type(lvl, "surprise_box") if o["params"]["content"] == "points"]
        self.assertEqual((points, sum(o["params"]["amount"] for o in boxes)), (9, 3),
                         "12 puntos: 8 de ruta + la caja de 2 + 1 del secreto A + la caja de 1 del C (§4.3.1)")
        eco = self.result["world5"]["economy"]
        items = {i["id"]: i for i in eco["items"]}
        self.assertEqual({k: v["cost"] for k, v in items.items()},
                         {"tienda_sync": 3, "tienda_energia": 2, "atajo_verificando": 3})
        self.assertEqual(eco["total"], 8, "Comprarlo todo cuesta 8 (§4.3.1)")
        for k, v in items.items():
            self.assertGreaterEqual(v["points_before"], v["cost"], "%s se paga con lo cogido antes" % k)
        ledger = self.result["world5"]["ledger"]
        self.assertEqual((ledger["profile"], ledger["start"], ledger["spent"], ledger["min"]), ("frugal", 0, 0, 0))
        self.assertFalse({s["action"] for s in self.exported[0]["steps"]} & {"buy", "pay_door"}, "El frugal no paga")
        buy = self.buy["world5"]["buy"]
        self.assertEqual((buy["paid"], buy["ledger"]["min"]), (["atajo_verificando"], 0),
                         "El comprador paga el atajo; el saldo nunca baja de 0")
        chargers = sorted(o["params"]["id"] for o in of_type(lvl, "charger"))
        self.assertEqual(chargers, ["cargador_1", "cargador_2", "cargador_3"], "Tres cargadores (ninguno en el Tramo 2)")
        self.assertEqual(len(of_type(lvl, "power_bank_pickup")), 1)
        self.assertEqual(of_type(lvl, "extra_life_pickup"), [], "Sin vida extra en el 5-3")

    def test_secrets(self):
        a = next(s for s in self.level["secrets"] if s["id"] == "secreto_tachon")
        self.assertEqual((a["memory_id"], a["needs_debug"], a["forbid_abilities"]), ("msg_5_3", True, ["dash"]))
        memory = next(m for m in self.result["memories"] if m["memory_id"] == "msg_5_3")
        self.assertEqual((memory["reachable_without_debug"], memory["reachable_with_debug"], memory["mandatory"]),
                         (False, True, False))
        self.assertEqual(len(of_type(self.level, "wish_strike")), 1)
        items = {i["id"]: i for i in self.result["secrets"]["items"]}
        self.assertTrue(items["secreto_trastienda"]["reachable"], "B: la trastienda con la Linterna")
        self.assertTrue(items["secreto_ultima_caja"]["reachable"], "C: la última caja")
        self.assertEqual(items["secreto_ultima_caja"]["secret_gates_opened"], ["box:caja_secreto_c"])
        # B: sin el paso en tinta (sin la Linterna) no se llega.
        self.assertTrue(any("secreto_trastienda" in e["message"] for e in self.variants["no_lamp"]["errors"]), "B pide la Linterna")
        self.assertTrue(any(o["type"] == "dark_zone" for o in self.level["objects"]))
        # C: sin el dash no se llega a la repisa de la última caja.
        self.assertTrue(any("secreto_ultima_caja" in e["message"] for e in self.variants["c_no_dash"]["errors"]),
                        "C pide el dash (energía de sobra)")

    def test_exported_path_and_duration(self):
        self.assertEqual(len(self.exported), 1)
        path = self.exported[0]
        self.assertEqual((path["format"], path["level"]), ("isak-path/1", "5-3"))
        actions = [s["action"] for s in path["steps"]]
        for action in ("walk", "jump", "dash", "pinch", "unpinch", "open_box", "debug_on", "combo_quake",
                       "cancel_subscription", "reject_terms", "resist_pull", "goal"):
            self.assertIn(action, actions)
        finals = [s for s in path["steps"] if s.get("final")]
        self.assertEqual([(s["action"], s["target"]["id"]) for s in finals], [("pulse", "terminal_pagar")])
        seconds = self.result["plan"]["duration_s"]
        target = self.level["target_duration_s"]
        self.assertTrue(0.40 * target <= seconds <= 0.55 * target,
                        "Camino del validador entre el 40 y el 55 %% del objetivo: %.1f s de %d" % (seconds, target))
        buy_actions = [s["action"] for s in self.bought[0]["steps"]]
        self.assertIn("pay_door", buy_actions)
        pay = next(s for s in self.bought[0]["steps"] if s["action"] == "pay_door")
        self.assertEqual((pay["target"]["id"], pay["trap"], pay["cost"]), ("atajo_verificando", "processing", 3))
        self.assertLess(self.bought[0]["duration_s"], path["duration_s"], "El atajo ahorra tiempo")

    def test_checkout_door(self):
        terminal = obj(self.level, "terminal_pagar")
        self.assertEqual((terminal["params"]["text"], terminal["params"]["skin"], terminal["params"]["offline_text"]),
                         ("Pagar", "checkout", "Pago realizado. Gracias por elegirnos."))
        eco = obj(self.level, "eco_cierre_5_3")
        self.assertEqual(eco["params"]["text"], "¿Ves? Ya no tienes que elegir nada.")

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
                                ("5-boss", True, None)], "5-3 jugable; El Vendedor, jugable (paso 18)")
        icon = m5["levels"][2]["icon"]
        self.assertTrue(os.path.exists(os.path.join(ROOT, icon[len("res://"):])), icon)
        self.assertTrue(os.path.exists(os.path.join(ROOT, "scenes", "levels", "5-3.tscn")))
        with open(os.path.join(ROOT, "data", "memories.json"), encoding="utf-8") as handle:
            memories = {m["id"]: m for m in json.load(handle)["memories"]}
        msg = memories["msg_5_3"]
        self.assertEqual((msg["level"], msg["secret"], msg["sender"], msg["world"], msg["first_lap"], msg["subject"]),
                         ("5-3", "secreto_tachon", "Abuelito", 5, 1, "El letrero"))
        self.assertLessEqual(len(msg["text"]), 280)


if __name__ == "__main__":
    unittest.main()
