"""Pruebas de tools/reduce_palette.py (arte final de Alerta Mayor, 2026-10-22).
Uso: python3 -m unittest tests/test_reduce_palette.py
"""

import os
import sys
import unittest

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import reduce_palette  # noqa: E402

GPL = os.path.join(ROOT, "assets", "palettes", "mundo1.gpl")
NO_CARMIN = ["carmin", "carmin_brillo"]


class ReducePaletteTest(unittest.TestCase):
    def setUp(self):
        self.palette = reduce_palette.load_gpl(GPL)
        self.by_name = dict(self.palette)

    def test_loads_mundo1(self):
        self.assertEqual(len(self.palette), 17)
        self.assertEqual(self.by_name["alerta"], (255, 74, 42))
        self.assertEqual(self.by_name["carmin"], (224, 0, 74))

    def test_reds_never_fall_into_carmin(self):
        allowed = reduce_palette.select_colors(self.palette, exclude=NO_CARMIN)
        # Rojos y rosas que, con toda la paleta, irian a carmin o carmin_brillo.
        reds = [(224, 0, 74), (230, 10, 80), (200, 0, 60), (255, 90, 140), (250, 100, 150), (190, 20, 50)]
        full = self.palette
        self.assertIn(reduce_palette.nearest((224, 0, 74), full), {self.by_name["carmin"]})
        for c in reds:
            got = reduce_palette.nearest(c, allowed)
            self.assertNotIn(got, (self.by_name["carmin"], self.by_name["carmin_brillo"]), c)

    def test_reduce_image_maps_to_palette_and_keeps_transparency(self):
        allowed = reduce_palette.select_colors(
            self.palette, only=["noche_profunda", "alerta", "alerta_sombra", "banner_blanco", "banner_gris"])
        img = Image.new("RGBA", (4, 1), (0, 0, 0, 0))
        img.putpixel((0, 0), (240, 80, 40, 255))   # naranja de la IA -> alerta
        img.putpixel((1, 0), (150, 40, 30, 255))   # ladrillo -> alerta_sombra
        img.putpixel((2, 0), (250, 250, 250, 255))  # blanco -> banner_blanco
        out = reduce_palette.reduce_image(img, allowed)
        self.assertEqual(out.getpixel((0, 0)), self.by_name["alerta"] + (255,))
        self.assertEqual(out.getpixel((1, 0)), self.by_name["alerta_sombra"] + (255,))
        self.assertEqual(out.getpixel((2, 0)), self.by_name["banner_blanco"] + (255,))
        self.assertEqual(out.getpixel((3, 0)), (0, 0, 0, 0))
        self.assertEqual(reduce_palette.check_image(out, allowed), [])

    def test_check_reports_foreign_colors_and_partial_alpha(self):
        allowed = reduce_palette.select_colors(self.palette, exclude=NO_CARMIN)
        img = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        img.putpixel((0, 0), (224, 0, 74, 255))
        img.putpixel((1, 0), (255, 74, 42, 100))
        errs = reduce_palette.check_image(img, allowed)
        self.assertEqual(len(errs), 2)

    def test_unknown_name_is_an_error(self):
        with self.assertRaises(ValueError):
            reduce_palette.select_colors(self.palette, exclude=["rojo"])


if __name__ == "__main__":
    unittest.main()
