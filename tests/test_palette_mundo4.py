"""Paleta PROVISIONAL del Mundo 4 (paso 0 de docs/propuesta-mundo-4.md §8; tools/palette_mundo4_provisional.py).

- La paleta real cumple las 5 reglas de §6.1 y el .gpl y la seccion palette de data/world4_objects.json estan al dia
  (--check sale con 0).
- El coral del Debug es el decidido por el usuario (B, #ff9f7a) y coincide en la paleta, en debug_colors["4"] de
  data/hud.json y en el CORAL de tools/gen_hub_update_art.py; el coral provisional anterior (A, #ff7f66) falla la
  regla 1 con el tinte del Debug.
- Casos negativos sinteticos: crema que se parece al ambar, fondo que apaga a Isak o que no es marino, puntos de Eco
  del color del «escribiendo…», verde saturado o acido, reservados cambiados y velos que se comen los contornos.
- El catalogo del Mundo 4 une los tipos de los Mundos 1-3 y trae su paleta (tools/level_catalog.py).

Uso: PATH=/usr/bin:$PATH python3 -I tests/test_palette_mundo4.py
"""
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import palette_mundo4_provisional as pal  # noqa: E402


def _with(**hexes):
    return [(n, hexes.get(n, v), r) for n, v, r in pal.COLORS]


class PaletteMundo4Test(unittest.TestCase):
    def test_real_palette_passes_check(self):
        result = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "palette_mundo4_provisional.py"),
                                 "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(pal.check_rules(), [])

    def test_sixteen_colors_plus_decided_coral(self):
        self.assertEqual(len(pal.COLORS), 16)
        self.assertEqual(pal.DEBUG[:2], ("debug_coral", "ff9f7a"))
        names = [n for n, _v, _r in pal.COLORS]
        for name in ("chat_noche", "marino_fondo", "crema", "verde_apagado", "gris_oscuro", "alerta", "ambar"):
            self.assertIn(name, names)

    def _fails(self, rule, colors=None, debug_hex=None):
        errors = pal.check_rules(colors, debug_hex)
        self.assertTrue(any(e.startswith(rule) for e in errors), errors)

    def test_coral_against_damage_red(self):
        # La provisional A (#ff7f66): dE 30 sin tinte, pero con el tinte del Debug el rojo se le acerca.
        errors = pal.check_rules(None, "ff7f66")
        self.assertTrue(any("tinte del Debug" in e for e in errors), errors)
        self._fails("regla 1", None, "ff5a40")  # casi el rojo de dano
        self._fails("regla 1", None, "3a2030")  # no se ve sobre el marino

    def test_coral_matches_hud_and_hub(self):
        self.assertEqual(pal._hud_debug(), pal.DEBUG[1])
        self.assertEqual(pal._hub_coral(), pal.DEBUG[1])
        # Cualquier otro coral no cuadra con data/hud.json ni con el hub.
        errors = pal.check_rules(None, "f78fa0")
        self.assertTrue(any("data/hud.json" in e for e in errors), errors)
        self.assertTrue(any("gen_hub_update_art.py" in e for e in errors), errors)

    def test_amber_like_cream_fails(self):
        self._fails("regla 2", _with(crema="ffb030"))
        self._fails("regla 2", _with(crema_sombra="e8a020"))

    def test_background_and_eco_dots(self):
        self._fails("regla 3", _with(marino_fondo="5a8aa0"))   # claro: apaga a Isak y a Eco
        self._fails("regla 3", _with(marino_fondo="381a2a"))   # no es marino
        self._fails("regla 3", _with(crema="2ad8f4"))          # los puntos del «escribiendo…» en cian

    def test_saturated_or_acid_green_fails(self):
        self._fails("regla 4", _with(verde_apagado="40c060"))
        self._fails("regla 4", _with(verde_sombra="9ae040"))
        self._fails("regla 4", _with(verde_apagado="7d8a9a"))  # ya no es verde

    def test_reserved_colors(self):
        errors = pal.check_rules(_with(alerta="ff3a2a"))
        self.assertTrue(any("reservado" in e for e in errors), errors)

    def test_dark_and_frozen_veils(self):
        m = pal.metrics()
        for key in ("cr_dark_outline", "cr_dark_dots", "cr_dark_checks", "cr_frozen_outline"):
            self.assertGreaterEqual(m[key], 3.0, key)
        self._fails("regla 5", _with(verde_apagado="3c4e40"))  # checks oscuros en el Modo oscuro
        self._fails("regla 5", _with(gris_oscuro="8890a0"))    # velo del congelado claro: contorno perdido

    def test_world4_catalog_has_types_of_worlds_1_to_3(self):
        catalog = level_catalog.load_catalog(ROOT, 4)
        types = catalog["types"]
        self.assertIn("charger", types)        # Mundo 1
        self.assertIn("fragile_card", types)   # Mundo 2
        self.assertIn("like_platform", types)  # Mundo 3
        self.assertEqual(catalog["palette"]["debug_coral"], "#" + pal.DEBUG[1])
        self.assertNotIn("debug_coral", level_catalog.load_catalog(ROOT, 3)["palette"])


if __name__ == "__main__":
    unittest.main()
