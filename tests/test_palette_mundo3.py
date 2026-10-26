"""Paleta PROVISIONAL del Mundo 3 (paso 0 de docs/propuesta-mundo-3.md §8; tools/palette_mundo3_provisional.py).

- La paleta real cumple las 5 reglas de §6.1 y el .gpl y la seccion palette de data/world3_objects.json estan al dia
  (--check sale con 0).
- Casos negativos sinteticos: dorado saturado o con el tono del ambar, rosa oscuro, corazon rojo, fondo claro que
  apaga a Isak y a Eco, otro verde en la paleta, reservados cambiados y velo que se come el contorno rojo.
- El catalogo del Mundo 3 une los tipos de los Mundos 1, 2 y 3 (tools/level_catalog.py).

Uso: python3 -m unittest tests/test_palette_mundo3.py
"""
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import palette_mundo3_provisional as pal  # noqa: E402


def _with(**hexes):
    return [(n, hexes.get(n, v), r) for n, v, r in pal.COLORS]


class PaletteMundo3Test(unittest.TestCase):
    def test_real_palette_passes_check(self):
        result = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "palette_mundo3_provisional.py"),
                                 "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(pal.check_rules(), [])

    def test_sixteen_colors_plus_debug(self):
        self.assertEqual(len(pal.COLORS), 16)
        self.assertEqual(pal.DEBUG[0], "debug_verde")
        names = [n for n, _v, _r in pal.COLORS]
        for name in ("dorado", "rosa_pastel", "blanco_brillante", "trastienda_fondo", "corazon_rosa",
                     "galeria_noche", "alerta", "ambar"):
            self.assertIn(name, names)

    def _fails(self, rule, colors=None, debug_hex=None):
        errors = pal.check_rules(colors, debug_hex)
        self.assertTrue(any(e.startswith(rule) for e in errors), errors)

    def test_saturated_or_amber_gold_fails(self):
        self._fails("regla 1", _with(dorado="e8b020"))   # saturado
        self._fails("regla 1", _with(dorado="b38a5c"))   # tono < 45
        self._fails("regla 1", _with(dorado="f0a818"))   # casi el ambar de los puntos

    def test_dark_pink_or_red_heart_fails(self):
        self._fails("regla 2", _with(rosa_pastel="c06080"))
        self._fails("regla 2", _with(corazon_rosa="ff3a4a"))
        self._fails("regla 2", _with(corazon_rosa="ff6a90"))  # cerca del carmin_brillo

    def test_light_background_fails(self):
        self._fails("regla 3", _with(trastienda_fondo="b8a0c0"))
        self._fails("regla 3", _with(trastienda_fondo="3d5a62"))  # no es malva

    def test_other_green_fails(self):
        self._fails("regla 4", _with(gris_perla="60c060"))
        self._fails("regla 4", None, "ff8040")

    def test_reserved_colors(self):
        errors = pal.check_rules(_with(ambar="ffb000"))
        self.assertTrue(any("reservado" in e for e in errors), errors)

    def test_flash_veil_outline(self):
        m = pal.metrics()
        self.assertGreaterEqual(m["cr_flash_outline"], 3.0)
        # Sin la sombra roja (alerta pura sobre el velo) no llegaria a 3:1.
        self._fails("regla 5", _with(alerta_sombra="ff6a4a"))

    def test_world3_catalog_has_types_of_worlds_1_2_3(self):
        catalog = level_catalog.load_catalog(ROOT, 3)
        types = catalog["types"]
        self.assertIn("charger", types)        # Mundo 1
        self.assertIn("fragile_card", types)   # Mundo 2
        self.assertIn("like_platform", types)  # Mundo 3
        self.assertEqual(catalog["palette"]["debug_verde"], "#" + pal.DEBUG[1])
        # El Mundo 2 no cambia: no ve los tipos del Mundo 3.
        self.assertNotIn("like_platform", level_catalog.load_catalog(ROOT, 2)["types"])


if __name__ == "__main__":
    unittest.main()
