"""Pruebas de conjunto del Mundo 5 «La Tienda» (paso 21 de docs/propuesta-mundo-5.md §8 y §7.4, 2026-10-29).

Negativos de diseño sobre los datos y el modelo del validador (la fisica real la prueba tests/test_world5_negatives.gd):

- **Los Mundos 1-4 no cambian**: ningun nivel, arena ni sala de los Mundos 1-4 (ni la pagina 2 del hub) declara la
  Combinacion en `abilities_available` ni lleva piezas del Mundo 5, asi que el modelo del Mundo 5
  (tools/world5_model.py) no se activa (`has_world5` falso) y devuelve el nivel sin tocar. La salida del validador de
  todos ellos es identica byte a byte a la de las herramientas anteriores al Mundo 5 (comparacion del paso 21 en §8.1).
- **Rejugar los Mundos 1-4 con la Combinacion no trivializa ningun secreto**: con `combo`, ningun secreto de Debug
  (regla 4) de los niveles reales de los Mundos 1-4 se alcanza sin el Debug (ComboKeepsDebugSecretsTest; el 4-1 se
  arreglo en el paso 21). La comparacion completa del paso 21 (§8.1: cada nivel con y sin `combo`, y con todo el kit
  con y sin `combo`; secretos, vidas extra, mensajes y puertas) es lenta y no va aqui. En el juego, ninguna pieza de
  los Mundos 1-4 escucha la Combinacion (tests/test_world5_negatives.gd).
- **Con 0 puntos se completan los tres niveles**: el validador cuenta el saldo desde 0 (tests/test_level_5_1.py,
  _5_2 y _5_3, frugal y comprador) y el bot de la tienda entra con 0 puntos (tests/test_mall_bot.gd). Aqui: los
  tres niveles reales tienen la economia del Mundo 5 y ningun atajo, tienda ni caja de Calc es la unica salida (eso
  lo comprueba el validador; aqui, que todos llevan precio de data/economy.json).
Uso: python3 -I tests/test_world5_negatives.py
"""

import copy
import glob
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import validate_level  # noqa: E402
import world2_model  # noqa: E402
import world3_model  # noqa: E402
import world4_model  # noqa: E402
import world5_model  # noqa: E402


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def levels_of(worlds):
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "levels", "*.json"))):
        level = load(path)
        if int(level.get("world", 1)) in worlds:
            out.append((os.path.basename(path), level))
    return out


def world5_types():
    objects = load(os.path.join(ROOT, "data", "world5_objects.json"))
    kinds = set(objects.get("types", {}).keys())
    for name in os.listdir(os.path.join(ROOT, "data", "enemies")):
        if name.endswith(".json") and int(load(os.path.join(ROOT, "data", "enemies", name)).get("world", 0)) == 5:
            kinds.add(name[:-5])
    return kinds | {"offer_sign", "subscription"}


class Worlds1To4UnchangedTest(unittest.TestCase):
    def setUp(self):
        found = levels_of((1, 2, 3, 4))
        self.assertGreaterEqual(len(found), 40, "Niveles, arenas y salas de los Mundos 1-4")
        self.levels = found + [("hub_update.json", load(os.path.join(ROOT, "data", "hub_update.json")))]

    def test_no_combo_and_no_world5_pieces(self):
        kinds = world5_types()
        for name, level in self.levels:
            self.assertNotIn(world5_model.COMBO_ABILITY, level.get("abilities_available") or {}, name)
            used = {o["type"] for o in level.get("objects", []) + level.get("enemies", [])}
            self.assertFalse(used & kinds, "%s: piezas del Mundo 5 %s" % (name, sorted(used & kinds)))

    def test_world5_model_leaves_every_earlier_level_untouched(self):
        for name, level in self.levels:
            self.assertFalse(world5_model.has_world5(level), name)
            catalog = level_catalog.load_catalog(ROOT, int(level.get("world", 1)))
            self.assertIs(world5_model.lower(level, catalog), level, name)


def debug_secret_reachable_without_debug(level, combo):
    """Regla 4 con o sin la Combinacion: para cada secreto con needs_debug, si se alcanza SIN el Debug (con todo lo
    demas del nivel). Solo la busqueda de cada secreto (lo que hace Validator._check_secrets), no el nivel entero."""
    level = copy.deepcopy(level)
    if combo:
        level.setdefault("abilities_available", {})[world5_model.COMBO_ABILITY] = True
    world = int(level.get("world", 1))
    for model in (world2_model, world3_model):
        level = model.lower(level, level_catalog.load_catalog(ROOT, world))
    level = world4_model.lower(level, level_catalog.load_catalog(ROOT, world), ())
    level = world5_model.lower(level, level_catalog.load_catalog(ROOT, world))
    rules = validate_level.Rules(ROOT, None, validate_level.DEFAULT_JUMP_EFFICIENCY, validate_level.DEFAULT_LIMIT,
                                 bool(level.get("allow_run", False)), (), ())
    rules.set_level_debug_world_scale(level.get("debug_world_scale"))
    validator = validate_level.Validator(level, rules)
    start, _ = validator.spawn_node(validator.find("P")[0])
    out = {}
    for s in level.get("secrets", []):
        if s.get("needs_debug") and not s.get("object"):
            sv, sstart, _ = validator._granted(s, start)
            run = sv.progression(sstart, frozenset(), rules.limit, targets={(s["x"], s["y"])}, debug=False)
            out[s["id"]] = run["ok"]
    return out


class ComboKeepsDebugSecretsTest(unittest.TestCase):
    """Paso 21 (2026-10-29): rejugar los Mundos 1-4 con la Combinacion no abre sin el Debug ningun secreto de Debug
    (regla 4) de sus niveles reales. Lo encontro la comparacion del paso 21: en el 4-1 el Filo (4 tiles comprimido con
    gravedad 0) llegaba sin el Debug al nicho del mensaje msg_4_1 desde la burbuja «escribiendo…» t2; se alejaron el
    borde de t2 y de las burbujas de Tomi y «lo vi» y la pasarela oculta crecio un tile (propuesta-mundo-4.md §8.1).
    Unos 100 s: una busqueda por secreto (no el validador entero)."""

    def test_debug_secrets_of_worlds_1_to_4_still_need_the_debug_with_the_combo(self):
        checked = 0
        for name, level in levels_of((1, 2, 3, 4)):
            if name.endswith("_test.json") or level.get("kind") == "boss":
                continue
            if not any(s.get("needs_debug") and not s.get("object") for s in level.get("secrets", [])):
                continue
            for sid, reachable in debug_secret_reachable_without_debug(level, combo=True).items():
                checked += 1
                self.assertFalse(reachable, "%s: el secreto %s se alcanza sin el Debug con la Combinacion" % (name, sid))
        self.assertGreaterEqual(checked, 8, "Secretos de Debug de 1-2, 1-3, 2-1, 2-3, 3-2, 3-3, 4-1 y 4-3")


class World5LevelsUseTheEconomyTest(unittest.TestCase):
    def test_the_three_levels_are_world5_and_priced_from_the_economy(self):
        economy = load(os.path.join(ROOT, "data", "economy.json"))
        self.assertIn("prices", economy)
        for lid in ("5-1", "5-2", "5-3"):
            level = load(os.path.join(ROOT, "data", "levels", lid + ".json"))
            self.assertTrue(world5_model.has_world5(level), lid)
            priced = [o for o in level["objects"] if o["type"] in ("shop_item", "shortcut_door", "calc_register")]
            self.assertTrue(priced, "%s: tiene algo con precio" % lid)
            # Ningun precio en el nivel: todos salen de data/economy.json (las protecciones de §3.1).
            for o in priced:
                self.assertNotIn("cost", o.get("params") or {}, "%s: %s sin precio propio" % (lid, o["params"]["id"]))


if __name__ == "__main__":
    unittest.main()
