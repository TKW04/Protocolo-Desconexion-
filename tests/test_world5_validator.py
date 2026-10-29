"""Paso 8 de docs/propuesta-mundo-5.md §7.1 y §8 (2026-10-29): el validador modela el Mundo 5 «La Tienda»
(tools/world5_model.py). 8a: economia (precios, saldo desde 0 y nunca por debajo de min_balance, Devoluciones),
tentacion (deriva, multiplicadores y tope; quieto no acaba en un foso mortal), cajas sorpresa (contenido fijo, aviso
del Debug, orden seguro), atajos (camino largo obligatorio, --buy) y cuentas regresivas. 8b: la Combinacion
(Embestida, Filo y Sismo) con sus obstaculos y la anti-redundancia de §3.9, la regla de las estanterias (ningun golpe
suelto alcanza a dos del mismo grupo), Terminos y condiciones, lista de deseos y presupuesto de camino. Las salas de
los pasos 2-7 validan con el camino exportado y los negativos sinteticos fallan como deben; un nivel sin nada del
Mundo 5 no cambia.
Uso: python3 -I tests/test_world5_validator.py
"""

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import validate_level  # noqa: E402
import world5_model  # noqa: E402

LEVELS = os.path.join(ROOT, "data", "levels")
ROOMS = ("ofertas_test", "tienda_test", "cajas_test", "rebajas_test", "combos_test", "deseos_test")
_CACHE = {}


def load(name):
    with open(os.path.join(LEVELS, name + ".json"), encoding="utf-8") as handle:
        return json.load(handle)


def run(level, export=None, schema=True, buy=False):
    return validate_level.validate(level, ROOT, export=export, check_schema=schema, buy=buy)


def room(name):
    """Resultado y camino exportado de una sala (cacheados: el combos_test tarda)."""
    if name not in _CACHE:
        export = []
        _CACHE[name] = (run(load(name), export=export), export)
    return _CACHE[name]


def messages(result):
    return [e["message"] for e in result["errors"]]


def warnings(result):
    return [w["message"] for w in result["warnings"]]


def set_cell(level, x, y, char):
    row = level["grid"][y]
    level["grid"][y] = row[:x] + char + row[x + 1:]


def obj(level, obj_id):
    return next(o for o in level["objects"] if (o.get("params") or {}).get("id") == obj_id)


def actions(export):
    return [s["action"] for s in export[0]["steps"]]


def catalog(level):
    return level_catalog.load_catalog(ROOT, int(level.get("world", 1)))


class LowerTest(unittest.TestCase):
    def test_levels_without_world5_are_unchanged(self):
        for name in ("1-1", "1-2", "2-1", "3-1", "3-3", "4-1", "4-3", "1-boss", "4-boss"):
            level = load(name)
            self.assertFalse(world5_model.has_world5(level), name)
            self.assertIs(world5_model.lower(level, catalog(level)), level, name)

    def test_pieces_become_known_ones(self):
        level = load("rebajas_test")
        low = world5_model.lower(level, catalog(level))
        types = [o["type"] for o in low["objects"]]
        self.assertIn("rhythm_zone", types, "La cuenta sin trigger lleva su metronomo")
        blink = next(o for o in low["objects"] if o["type"] == "blink_platform")
        self.assertAlmostEqual(blink["params"]["on_fraction"], 5.0 / 6.0)
        self.assertEqual(sum(1 for o in low["objects"] if o["type"] == "countdown_platform"), 1,
                         "La de la trampa (trigger) se queda: tabla fija en el camino frugal")
        level = load("deseos_test")
        low = world5_model.lower(level, catalog(level))
        self.assertEqual(low["grid"][9][12:15], "---", "Lista de deseos: tarjeta de una via")
        strike = next(o for o in low["objects"] if o["params"].get("id") == "tachon_prueba")
        self.assertEqual(strike["type"], "glitch_wall")
        self.assertTrue(strike["params"]["visible_only_with_debug"])
        level = load("combos_test")
        low = world5_model.lower(level, catalog(level))
        trial = next(o for o in low["objects"] if o["params"].get("id") == "prueba_gratis_test")
        self.assertEqual((trial["type"], trial["params"]["ability"]), ("dnd_switch", "combo"))

    def test_pull_numbers(self):
        level = load("ofertas_test")
        rules = validate_level.Rules(ROOT)
        model = validate_level.LevelModel(world5_model.lower(level, catalog(level)), rules)
        w5 = model.w5
        drift, away, toward = w5.pull(1.0)
        self.assertEqual((drift, round(away, 3), round(toward, 3)), (60.0, 0.6, 1.15))
        drift, away, _t = w5.pull(2.0)
        self.assertEqual((drift, away), (90.0, 0.45), "Suma con tope")
        self.assertGreater(rules.walk_speed * away - drift, 0.0, "Siempre hay salida andando")


class RoomsTest(unittest.TestCase):
    def test_rooms_validate_with_export(self):
        for name in ROOMS:
            result, export = room(name)
            self.assertTrue(result["ok"], "%s: %s" % (name, messages(result)))
            self.assertTrue(export and export[0]["steps"], name)
            self.assertIn("world5", result, name)

    def test_combos_room_uses_the_three_combos(self):
        result, export = room("combos_test")
        acts = actions(export)
        for a in ("combo_ram", "combo_edge", "combo_quake"):
            self.assertIn(a, acts)
        obstacles = {o["id"]: o for o in result["world5"]["obstacles"]}
        for oid in ("persiana_salida", "persiana_pared", "saldos_prueba", "ranura_prueba"):
            self.assertTrue(obstacles[oid]["used"] and obstacles[oid]["required"], oid)
        self.assertTrue(all(e["ok"] for e in result["world5"]["shelf_rule"]))
        edge = next(s for s in export[0]["steps"] if s["action"] == "combo_edge")
        self.assertTrue(edge["compressed"])
        self.assertEqual(edge["energy_cost"], 15.0)
        self.assertIn("ranura_prueba", [r for s in export[0]["steps"] if s["action"] == "combo_edge"
                                        for r in s.get("rails", [])])

    def test_room_steps(self):
        self.assertIn("resist_pull", actions(room("ofertas_test")[1]))
        self.assertIn("reject_terms", actions(room("rebajas_test")[1]))
        self.assertEqual(room("rebajas_test")[0]["world5"]["terms"][0]["via"], "laser")
        self.assertIn("cancel_subscription", actions(room("cajas_test")[1]))
        self.assertNotIn("pay_door", actions(room("tienda_test")[1]), "El camino frugal no paga")
        self.assertEqual(room("deseos_test")[0]["world5"]["wish_stops"], [])
        for name in ROOMS:
            self.assertGreaterEqual(room(name)[0]["world5"].get("ledger", {"min": 0})["min"], 0, name)

    def test_buy_path(self):
        export = []
        result = run(load("tienda_test"), export=export, buy=True)
        self.assertTrue(result["ok"], messages(result))
        acts = actions(export)
        self.assertIn("pay_door", acts)
        self.assertIn("refund", acts)
        buy = result["world5"]["buy"]
        self.assertEqual(buy["paid"], ["atajo_trampa"])
        self.assertEqual(buy["ledger"]["refunded"], 5, "Lo pagado en el atajo con trampa + 2 del secreto")
        self.assertGreaterEqual(buy["ledger"]["min"], 0)


class EconomyNegativesTest(unittest.TestCase):
    def test_unpayable_shop(self):
        level = load("tienda_test")
        for x in (3, 4, 5):
            set_cell(level, x, 9, ".")
        result = run(level, schema=False)
        self.assertTrue(any("economia: tienda tienda_sync cuesta 3" in m for m in messages(result)), messages(result))

    def test_mandatory_edge_with_price(self):
        level = load("tienda_test")
        for y in (4, 6, 8):
            level["grid"][y] = level["grid"][y].replace("-", ".")
        result = run(level, schema=False)
        self.assertTrue(any("arista obligatoria con precio" in m for m in messages(result)), messages(result))

    def test_negative_balance_when_buying(self):
        level = load("tienda_test")
        obj(level, "atajo_trampa")["params"]["cost"] = 4
        result = run(level, schema=False, buy=True)
        msgs = messages(result)
        self.assertTrue(any("comprando: saldo negativo" in m for m in msgs), msgs)
        self.assertTrue(any("atajo con trampa atajo_trampa cuesta 4" in m for m in msgs), msgs)

    def test_too_much_to_buy(self):
        level = load("tienda_test")
        obj(level, "atajo_calc")["params"]["cost"] = 4
        result = run(level, schema=False)
        self.assertTrue(any("max_spend_per_level" in m for m in messages(result)), messages(result))


class TemptationNegativesTest(unittest.TestCase):
    def test_offer_drags_into_a_deadly_pit(self):
        level = load("ofertas_test")
        # Sin la Oferta colgada (su tiron anula el de la del carrito a la derecha) y con un foso sin fondo en las
        # columnas 20-21: quieto en la 22, la Oferta del carrito lo arrastra al foso.
        level["enemies"] = [e for e in level["enemies"] if e["id"] != "oferta_colgada"]
        for y in (10, 11):
            set_cell(level, 20, y, ".")
            set_cell(level, 21, y, ".")
        result = run(level, schema=False)
        self.assertTrue(any("foso mortal" in m for m in messages(result)), messages(result))


class BoxNegativesTest(unittest.TestCase):
    def _walled(self, contents, debug=True):
        level = load("cajas_test")
        level["abilities_available"]["debug"] = debug
        for x, oid in zip((7, 9, 11, 13), ("caja_energia", "caja_puntos", "caja_suscripcion", "caja_vacia")):
            for y in range(1, 8):
                set_cell(level, x, y, "#")
            if oid in contents:
                obj(level, oid)["params"]["content"] = contents[oid]
                obj(level, oid)["params"].pop("amount", None)
        return level

    def test_blocking_box_hides_harm_without_warning(self):
        result = run(self._walled({}, debug=False), schema=False)
        self.assertTrue(any("caja_suscripcion tapa el camino y esconde subscription sin aviso" in m
                            for m in messages(result)), messages(result))

    def test_chain_without_safe_order(self):
        bad = {k: "subscription" for k in ("caja_energia", "caja_puntos", "caja_suscripcion", "caja_vacia")}
        result = run(self._walled(bad), schema=False)
        self.assertTrue(any("cajas en cadena sin orden seguro" in m for m in messages(result)), messages(result))

    def test_chain_with_safe_order(self):
        result = run(self._walled({}), schema=False)
        self.assertFalse(any("cajas en cadena" in m for m in messages(result)), messages(result))
        self.assertTrue(all(b["blocks_path"] for b in result["world5"]["boxes"]))


class ComboNegativesTest(unittest.TestCase):
    def test_obstacle_without_combo(self):
        level = load("combos_test")
        level["objects"] = [o for o in level["objects"] if o["type"] != "free_trial_box"]
        result = run(level, schema=False)
        msgs = messages(result)
        self.assertFalse(result["ok"])
        self.assertTrue(any("persiana persiana_salida solo lo abre la Embestida y el nivel no tiene la Combinacion" in m
                            for m in msgs), msgs)
        self.assertTrue(any("ranura de precios ranura_prueba: solo la cruza el Filo" in m for m in msgs), msgs)

    def test_shutter_not_with_a_plain_ground_pound(self):
        level = load("combos_test")
        level["abilities_available"]["dash"] = False  # sin dash no hay Embestida; el golpe al suelo sigue
        result = run(level, schema=False)
        self.assertFalse(result["ok"], "La persiana no cae con un golpe al suelo normal")

    def test_rail_bypassed_without_filo(self):
        level = load("combos_test")
        # La ranura colgada en lo alto del piso de arriba: el hoyo de la banda (una fila, sin dano) se cruza andando.
        obj(level, "ranura_prueba")["y"] = 1
        obj(level, "ranura_prueba")["params"]["height_tiles"] = 3
        result = run(level, schema=False)
        self.assertTrue(any("ranura de precios ranura_prueba: el camino principal no la cruza con un Filo" in m
                            for m in messages(result)), messages(result))

    def test_shelves_too_close(self):
        level = load("combos_test")
        obj(level, "saldos_b")["x"] = 33
        result = run(level, schema=False)
        self.assertTrue(any("un solo golpe" in m and "saldos_a" in m for m in messages(result)), messages(result))

    def test_quake_with_part_of_the_group_out_of_view(self):
        level = load("combos_test")
        obj(level, "saldos_c")["x"] = 47
        obj(level, "terminal_combos")["x"] = 48
        set_cell(level, 46, 11, ".")
        set_cell(level, 48, 11, "G")
        rules = validate_level.Rules(ROOT)
        low = world5_model.lower(level, catalog(level))
        model = validate_level.LevelModel(low, rules)
        gate = next(g for g in model.gates if g.kind == "shelf")
        self.assertEqual(model.w5.quake_view_missing(gate, (32, 11), frozenset()), ["saldos_c"])
        result = run(level, schema=False)
        self.assertFalse(result["ok"], "Sin el grupo entero en la vista el Sismo no lo tumba")

    def test_no_combo_with_the_debug(self):
        level = load("combos_test")
        level["abilities_available"]["combo"] = True
        rules = validate_level.Rules(ROOT)
        model = validate_level.LevelModel(world5_model.lower(level, catalog(level)), rules)
        from world3_model import Pinched
        state = frozenset()
        self.assertTrue(model.w5.pinched_combo_edges(Pinched((23, 11)), state, False))
        self.assertEqual(model.w5.pinched_combo_edges(Pinched((23, 11)), state, True), [])
        shutter = next(g for g in model.gates if g.kind == "shutter" and g.obj_id == "persiana_salida")
        self.assertTrue(model.can_open(shutter, (12, 7), state, False))
        self.assertFalse(model.can_open(shutter, (12, 7), state, True))


class TermsNegativesTest(unittest.TestCase):
    def test_only_accept_has_a_price(self):
        level = load("rebajas_test")
        for y in (8, 9):
            set_cell(level, 28, y, ".")
            set_cell(level, 29, y, ".")
        level["abilities_available"]["combo"] = False
        result = run(level, schema=False)
        self.assertTrue(any("arista obligatoria con precio" in m and "ACEPTAR" in m for m in messages(result)),
                        messages(result))


class BudgetTest(unittest.TestCase):
    def test_budget_out_of_range_warns(self):
        level = load("ofertas_test")
        level["target_duration_s"] = 200
        result = run(level, schema=False)
        self.assertTrue(any("presupuesto de camino" in w for w in warnings(result)), warnings(result))
        dur = result["world5"]["budget"]["duration_s"]
        level["target_duration_s"] = round(dur / 0.47)
        result = run(level, schema=False)
        self.assertFalse(any("presupuesto de camino" in w for w in warnings(result)), warnings(result))
        self.assertTrue(40.0 <= result["world5"]["budget"]["pct"] <= 55.0)


if __name__ == "__main__":
    unittest.main()
