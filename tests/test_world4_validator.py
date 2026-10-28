"""Paso 9 de docs/propuesta-mundo-4.md §7.1 y §8 (2026-10-28): el validador modela el Mundo 4 «El Chat»
(tools/world4_model.py): Agitar (habilidad del grafo, el «¿Deshacer escritura?» que la da y el muro de texto que
solo ella abre), zonas «Visto» (pulse_seen o la espera del ciclo; regla del congelado del 4-1), burbujas,
«escribiendo…» (wait_typing), autocorrector (wait_autocorrect; engaña, no mata), pasos en tinta con la Linterna,
Troll, Troll disfrazado (Debug), Fantasma (wait_ghost), Sticker y la ola de «Visto». Las salas de los pasos 2-8
validan con el camino exportado y los negativos sinteticos de §7.1 fallan como deben; un nivel sin nada del
Mundo 4 no cambia.
Uso: python3 -I tests/test_world4_validator.py
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
import world4_model  # noqa: E402

LEVELS = os.path.join(ROOT, "data", "levels")
ROOMS = ("visto_test", "burbujas_test", "oscuro_test", "grupo_test", "fantasmas_test", "ola_test", "borrados_test")


def load(name):
    with open(os.path.join(LEVELS, name + ".json"), encoding="utf-8") as handle:
        return json.load(handle)


def run(level, export=None, schema=True, allies=None):
    return validate_level.validate(level, ROOT, export=export, check_schema=schema, allies=allies)


def messages(result):
    return [e["message"] for e in result["errors"]]


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
    def test_levels_without_world4_are_unchanged(self):
        for name in ("1-1", "1-2", "2-1", "3-1", "3-3", "1-boss"):
            level = load(name)
            self.assertIs(world4_model.lower(level, catalog(level)), level, name)

    def test_bubbles_become_one_way_and_deleted_ones_do_not(self):
        level = load("burbujas_test")
        low = world4_model.lower(level, catalog(level))
        self.assertEqual(low["grid"][7][5:8], "---", "La burbuja fija (18 caracteres: 3 tiles)")
        self.assertEqual(low["grid"][5][17:20], "...", "La eliminada no existe")
        # Autocorrector: el largo corregido (2 tiles) en su ranura anclada a la izquierda.
        self.assertEqual(low["grid"][7][28:31], "--.")

    def test_ink_steps_only_with_the_flashlight(self):
        level = load("oscuro_test")
        self.assertEqual(world4_model.lower(level, catalog(level))["grid"][7][27], "-", "Linterna en el nivel")
        level["objects"] = [o for o in level["objects"] if o["type"] != "flashlight_pickup"]
        self.assertEqual(world4_model.lower(level, catalog(level))["grid"][7][27], ".", "Sin Linterna, nada")
        self.assertEqual(world4_model.lower(level, catalog(level), ("linterna",))["grid"][7][27], "-", "Conocida")

    def test_undo_prompt_and_typed_wall(self):
        level = load("borrados_test")
        low = world4_model.lower(level, catalog(level))
        switch = next(o for o in low["objects"] if o["type"] == "dnd_switch")
        self.assertEqual(switch["params"]["_config"], "undo_prompt")
        self.assertEqual(switch["params"]["ability"], "shockwave")
        wall = next(o for o in low["objects"] if o["type"] == "_pound_card")
        self.assertTrue(wall["params"]["_shake"])
        self.assertEqual(wall["params"]["rows"], 3)


class RoomsTest(unittest.TestCase):
    """Las salas del Mundo 4 de los pasos 2-8 validan y exportan su camino."""

    @classmethod
    def setUpClass(cls):
        cls.results = {}
        for name in ROOMS:
            export = []
            cls.results[name] = (run(load(name), export), export)

    def test_rooms_validate_and_export(self):
        for name in ROOMS:
            result, export = self.results[name]
            self.assertTrue(result["ok"], "%s: %s" % (name, messages(result)))
            self.assertTrue(export and export[0]["steps"], name)

    def test_borrados_gets_shockwave_and_shakes_the_wall(self):
        result, export = self.results["borrados_test"]
        steps = export[0]["steps"]
        dnd = next(s for s in steps if s["action"] == "pulse" and s.get("face_back"))
        self.assertEqual(dnd["target"], {"type": "dnd_switch", "id": "deshacer_prueba", "ability": "shockwave"})
        shake = next(s for s in steps if s["action"] == "shake")
        self.assertEqual(shake["breaks"], ["muro_prueba"])
        self.assertAlmostEqual(shake["erase_s"], 0.4)
        self.assertLess(steps.index(dnd), steps.index(shake), "Primero el gesto, despues el muro")
        self.assertIn("Agitar: se obtiene en el nivel", validate_level.format_text("borrados_test", result))

    def test_visto_pulses_the_check_and_waits_the_cycle(self):
        result, export = self.results["visto_test"]
        steps = export[0]["steps"]
        seen = [s for s in steps if s["action"] == "pulse_seen"]
        self.assertEqual([s["target"]["id"] for s in seen], ["visto_suelo"])
        zones = {z["id"]: z for z in result["world4"]["zones"]}
        self.assertIn("pulse_from", zones["visto_suelo"])
        self.assertIn("wait_s", zones["visto_ciclo"], "Con ciclo, el plan espera el hueco")

    def test_ghost_waits_then_stuns(self):
        _result, export = self.results["fantasmas_test"]
        acts = actions(export)
        self.assertIn("wait_ghost", acts)
        k = acts.index("wait_ghost")
        self.assertIn(acts[k + 1], ("pulse", "shake"), "Tras esperar, el pulso a su reaparicion")

    def test_group_is_stunned(self):
        result, _export = self.results["grupo_test"]
        stunned = {e["id"] for e in result["world4"]["enemies"]}
        self.assertTrue({"troll_suelo", "troll_bloque", "troll_repisa", "sticker_1", "sticker_2"} <= stunned, stunned)

    def test_wave_keeps_its_margin(self):
        result, _export = self.results["ola_test"]
        wave = result["world4"]["wave"]
        self.assertGreaterEqual(wave["closest_tiles"], wave["margin_tiles"])
        self.assertIn("sync_ola", wave["stops_passed"])


class NegativesTest(unittest.TestCase):
    """Negativos sinteticos de §7.1."""

    def test_without_shockwave_the_typed_wall_is_not_crossed(self):
        level = load("borrados_test")
        level["objects"] = [o for o in level["objects"] if o["type"] != "undo_prompt"]
        result = run(level, schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("solo lo deshace Agitar" in m for m in messages(result)), messages(result))

    def test_typing_bubble_that_asks_to_jump_before_one_second(self):
        # Escalera de dos «escribiendo…» hasta la repisa de la meta: la primera (A, cols. 4-5) se escribe al salir
        # de P y tiene un ciclo con una ventana de 0,3 s; la segunda (B, col. 7) se escribe al pisar A. Hay que
        # saltar de A a B y B tarda 1,0 s: la espera no cabe en la ventana de A.
        grid = ["#" * 18] + ["#" + "." * 16 + "#" for _ in range(9)] + ["#" * 18, "#" * 18]
        level = {"id": "escribiendo_test", "name": "negativo", "world": 4, "tile_size": 64,
                 "abilities_available": {"pulse": True, "laser": False, "debug": False},
                 "checkpoints": [], "secrets": [], "enemies": [], "unlocks": [], "grid": grid,
                 "objects": [
                     {"type": "typing_bubble", "x": 4, "y": 8, "params": {
                         "id": "a", "text": "hola, sí", "trigger_zone": [1, 8, 2, 2], "cycle_s": 3.0, "on_s": 0.3}},
                     {"type": "typing_bubble", "x": 7, "y": 6, "params": {
                         "id": "b", "text": "ya voy", "trigger": "a"}}]}
        set_cell(level, 2, 9, "P")
        for c in (9, 10, 11):
            set_cell(level, c, 5, "#")
        set_cell(level, 10, 4, "G")
        result = run(level, export=[], schema=False)
        self.assertTrue(any("«escribiendo…» b pide saltar antes de 1.0 s" in m for m in messages(result)),
                        messages(result))
        # Sin el ciclo en A la espera cabe: el plan espera en A (wait_typing) y llega.
        level["objects"][0]["params"].pop("cycle_s")
        level["objects"][0]["params"].pop("on_s")
        export = []
        result = run(level, export=export, schema=False)
        self.assertTrue(result["ok"], messages(result))
        self.assertIn("wait_typing", actions(export))

    def test_mandatory_seen_zone_without_its_check_in_reach(self):
        level = load("visto_test")
        zone = obj(level, "visto_suelo")
        zone["params"].update({"width_tiles": 4, "icon": "right"})
        result = run(level, export=[], schema=False)
        self.assertTrue(any("su doble check no esta a tiro de pulso" in m for m in messages(result)),
                        messages(result))

    def test_hazard_reaching_the_frozen_isak_without_shockwave(self):
        level = load("visto_test")
        level["abilities_available"]["shockwave"] = False
        set_cell(level, 11, 9, "^")
        result = run(level, schema=False)
        self.assertTrue(any("alcanza a Isak congelado" in m for m in messages(result)), messages(result))
        # Con Agitar en el nivel la misma sala no tiene ese error.
        level["abilities_available"]["shockwave"] = True
        result = run(level, schema=False)
        self.assertFalse(any("alcanza a Isak congelado" in m for m in messages(result)), messages(result))

    def test_wave_catches_up_when_the_path_stops(self):
        level = load("ola_test")
        zone = obj(level, "visto_ola")
        zone["params"].update({"on_s": 6.0, "off_s": 6.0})
        result = run(level, export=[], schema=False)
        self.assertTrue(any("la ola de «Visto» ola_prueba alcanza a Isak" in m for m in messages(result)),
                        messages(result))

    def test_autocorrect_that_leaves_a_deadly_pit(self):
        level = load("burbujas_test")
        for r in (8, 9, 10, 11):
            set_cell(level, 30, r, ".")
        result = run(level, schema=False)
        self.assertTrue(any("autocorrector autocorrector_1: deja un pozo mortal" in m for m in messages(result)),
                        messages(result))

    def test_mimic_near_the_path_needs_the_debug(self):
        level = load("grupo_test")
        level["abilities_available"]["debug"] = False
        result = run(level, schema=False)
        self.assertTrue(any("Troll disfrazado" in m and "Debug" in m for m in messages(result)), messages(result))


if __name__ == "__main__":
    unittest.main()
