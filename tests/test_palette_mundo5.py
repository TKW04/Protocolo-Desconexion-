"""Paleta PROVISIONAL del Mundo 5 (paso 0 de docs/propuesta-mundo-5.md §8; tools/palette_mundo5_provisional.py).

- La paleta real cumple las 7 reglas de §6.1 y el .gpl y la seccion palette de data/world5_objects.json estan al dia
  (--check sale con 0).
- El blanco del Debug es el decidido por el usuario (A, #ffffff) y coincide con debug_colors["5"] de data/hud.json.
- Casos negativos sinteticos: un Debug rojizo, contorno claro, un «blanco» en la paleta, naranja de rebajas, amarillo
  que se parece al ambar, lima o turquesa en los neones, fondo que apaga a Isak y reservados cambiados.
- El catalogo del Mundo 5 une los tipos de los Mundos 1-4 y trae su paleta; data/economy.json tiene los valores de §3.1.

Uso: PATH=/usr/bin:$PATH python3 -I tests/test_palette_mundo5.py
"""
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import palette_mundo5_provisional as pal  # noqa: E402
import palette_mundo5_variants as variants  # noqa: E402


def _with(**hexes):
    return [(n, hexes.get(n, v), r) for n, v, r in pal.COLORS]


class PaletteMundo5Test(unittest.TestCase):
    def test_real_palette_passes_check(self):
        result = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "palette_mundo5_provisional.py"),
                                 "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(pal.check_rules(), [])

    def test_sixteen_colors_plus_decided_white(self):
        self.assertEqual(len(pal.COLORS), 16)
        self.assertEqual(pal.DEBUG[:2], ("debug_blanco", "ffffff"))
        names = [n for n, _v, _r in pal.COLORS]
        for name in ("tienda_noche", "negro_fondo", "amarillo_rebajas", "magenta_neon", "violeta_neon", "alerta",
                     "ambar"):
            self.assertIn(name, names)

    def _fails(self, rule, colors=None, debug_hex=None):
        errors = pal.check_rules(colors, debug_hex)
        self.assertTrue(any(e.startswith(rule) for e in errors), errors)

    def test_white_matches_hud(self):
        self.assertEqual(pal._hud_debug(), "ffffff")
        errors = pal.check_rules(None, "e8f0ff")  # la opcion B ya no cuadra con data/hud.json
        self.assertTrue(any("data/hud.json" in e for e in errors), errors)

    def test_white_against_damage_red(self):
        self._fails("regla 1", None, "ff5a40")
        m = pal.metrics()
        self.assertGreaterEqual(m["de_white_red"], 30.0)
        self.assertGreaterEqual(m["de_white_red_debug"], 30.0)

    def test_black_outline_on_yellow_and_tint(self):
        self._fails("regla 2", _with(tienda_noche="b0a040"))

    def test_white_is_reserved_to_debug(self):
        self._fails("regla 3", _with(crema_cartel="fafafa"))
        self.assertLessEqual(pal.metrics()["max_l"], pal.MAX_L)

    def test_no_red_or_orange_signs(self):
        self._fails("regla 4", _with(magenta_neon="ff6a3d"))  # naranja de rebajas
        self._fails("regla 4", _with(magenta_sombra="c02020"))

    def test_yellow_against_amber_and_point_outline(self):
        self._fails("regla 5", _with(amarillo_rebajas="ffb000"))
        self.assertIn(5, pal._outline_worlds())

    def test_no_lime_or_cyan_neons(self):
        self._fails("regla 6", _with(violeta_neon="c8ff3d"))
        self._fails("regla 6", _with(violeta_neon="30e0c0"))

    def test_isak_on_black(self):
        self._fails("regla 7", _with(negro_fondo="4aa0b0"))

    def test_reserved_colors(self):
        errors = pal.check_rules(_with(alerta="ff3a2a"))
        self.assertTrue(any("reservado" in e for e in errors), errors)

    def test_world5_catalog_has_types_of_worlds_1_to_4(self):
        catalog = level_catalog.load_catalog(ROOT, 5)
        types = catalog["types"]
        self.assertIn("charger", types)
        self.assertIn("fragile_card", types)
        self.assertIn("like_platform", types)
        self.assertIn("seen_zone", types)
        self.assertEqual(catalog["palette"]["debug_blanco"], "#ffffff")
        self.assertNotIn("debug_blanco", level_catalog.load_catalog(ROOT, 4)["palette"])

    def test_economy_values(self):
        with open(os.path.join(ROOT, "data", "economy.json"), encoding="utf-8") as fh:
            eco = json.load(fh)
        self.assertEqual(eco["min_balance"], 0)
        self.assertEqual(eco["points_per_map"], 12)
        shop = eco["prices"]["shop_item"]
        self.assertEqual((shop["sync"]["cost"], shop["sync"]["sync"]), (3, 25))
        self.assertEqual((shop["energy"]["cost"], shop["energy"]["energy"]), (2, 40))
        self.assertEqual(eco["prices"]["shortcut_door"]["cost"], 3)
        self.assertEqual(eco["prices"]["calc_register"]["cost"], 2)
        self.assertEqual(eco["subscription"]["drain_cap"], 5)
        self.assertEqual(eco["refund_desk"]["bonus_points"], 2)
        self.assertEqual(eco["boss_tokens"]["start"], 12)
        lo, hi = eco["buy_all_per_level"]
        self.assertLessEqual(hi, eco["max_spend_per_level"])
        self.assertLess(eco["max_spend_per_level"], eco["points_per_map"])
        self.assertLessEqual(lo, hi)


class PaletteMundo5VariantsTest(unittest.TestCase):
    """Paso 9: las 3 variantes cumplen las 7 reglas de §6.1; la elegida (B, la de mayor margen minimo de
    contraste) es la del juego, en assets/palettes/mundo5.gpl (la provisional ya no existe)."""

    def test_three_variants_pass_and_the_chosen_one_is_used(self):
        self.assertEqual(sorted(variants.VARIANTS), ["A", "B", "C"])
        self.assertEqual(variants.check_variants(), [])
        self.assertEqual(variants.ACTIVE, "B")
        own = {n: v for n, v, _r in pal.COLORS if n not in variants.RESERVED}
        self.assertEqual(own, variants.VARIANTS["B"]["hex"])
        self.assertEqual(pal.DEBUG[1], "ffffff")
        self.assertTrue(os.path.exists(os.path.join(ROOT, "assets", "palettes", "mundo5.gpl")))
        self.assertFalse(os.path.exists(os.path.join(ROOT, "assets", "palettes", "mundo5_provisional.gpl")))
        worst = {vid: variants.min_margin(m)[0] for vid, m in variants.measures().items()}
        self.assertEqual(max(worst, key=worst.get), "B", worst)


if __name__ == "__main__":
    unittest.main()
