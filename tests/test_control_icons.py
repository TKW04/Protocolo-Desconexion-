"""Iconos de Pausa > Ajustes > Controles (tools/gen_control_icons.py; 2026-10-30,
peticion del usuario tras el 5-2): estan al dia, uno por fila de menu_rows de
data/settings.json, con la paleta del hub y contraste frente al panel, y el
validador detecta un icono roto (negativos).

Uso: python3 -I tests/test_control_icons.py (Pillow: /usr/bin/python3).
"""
import json
import os
import site
import sys
import unittest

sys.path.append(site.getusersitepackages())
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image  # noqa: E402
import gen_control_icons as gci  # noqa: E402


class ControlIconsTest(unittest.TestCase):
    def setUp(self):
        self.pal = {c[:3] for c in gci.hub.PAL.values()}
        self.bg = gci.panel_color()

    def test_check_passes(self):
        self.assertEqual(gci.check(), 0)

    def test_one_icon_per_menu_row(self):
        with open(gci.SETTINGS, encoding="utf-8") as fh:
            rows = json.load(fh)["controls"]["menu_rows"]
        outs = gci.outputs()
        self.assertEqual(len(rows), len(outs), "Una fila, un icono")
        ids = {r["id"] for r in rows}
        for needed in ("move_left", "move_right", "jump", "dash", "compress", "pulse", "laser", "debug",
                       "ground_pound", "hide", "combo_ram", "combo_edge", "combo_quake", "help", "pause",
                       "restart"):
            self.assertIn(needed, ids, "Fila de %s" % needed)
        for row in rows:
            self.assertIn(row["icon"][len(gci.RES_DIR):], outs)

    def test_icons_are_valid_and_distinct(self):
        outs = gci.outputs()
        seen = set()
        for name, img in outs.items():
            self.assertEqual(gci.check_icon(name, img, self.pal, self.bg), [], name)
            data = img.tobytes()
            self.assertNotIn(data, seen, "%s repite otro icono" % name)
            seen.add(data)
        left = outs[gci.file_name("move_left")]
        right = outs[gci.file_name("move_right")]
        self.assertEqual(left.transpose(Image.FLIP_LEFT_RIGHT).tobytes(), right.tobytes(), "Espejo")

    def test_validator_catches_bad_icons(self):
        dull = Image.new("RGBA", (gci.SIZE, gci.SIZE), (0, 0, 0, 0))
        dull.putpixel((5, 5), gci.hub.FP)
        self.assertTrue(any("contraste" in e for e in gci.check_icon("x", dull, self.pal, self.bg)))
        red = gci.icon("pause").copy()
        red.putpixel((3, 3), (0xff, 0x38, 0x38, 255))
        errs = gci.check_icon("x", red, self.pal, self.bg)
        self.assertTrue(any("reservado" in e for e in errs) and any("fuera de hub.gpl" in e for e in errs))
        semi = gci.icon("pause").copy()
        semi.putpixel((3, 3), (255, 255, 255, 128))
        self.assertTrue(any("alfa" in e for e in gci.check_icon("x", semi, self.pal, self.bg)))
        self.assertTrue(gci.check_icon("x", Image.new("RGBA", (16, 16)), self.pal, self.bg))

    def test_contrast_formula(self):
        self.assertAlmostEqual(gci.contrast((255, 255, 255), (0, 0, 0)), 21.0, places=3)
        self.assertAlmostEqual(gci.contrast((10, 10, 10), (10, 10, 10)), 1.0, places=3)


if __name__ == "__main__":
    unittest.main()
