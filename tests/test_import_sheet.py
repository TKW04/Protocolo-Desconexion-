"""Pruebas de tools/import_sheet.py (opcion --stabilize).
Uso: python3 -m unittest tests/test_import_sheet.py
"""

import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import import_sheet  # noqa: E402

BODY = (60, 60, 70, 255)


def frame(noise=(), extra=(), block_y=4):
    """Cuadro 16x16 con un bloque opaco (filas block_y..block_y+7), pixeles con
    ruido de color (+10) y pixeles opacos aislados extra."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(block_y, block_y + 8):
        for x in range(4, 12):
            img.putpixel((x, y), BODY)
    for (x, y) in noise:
        img.putpixel((x, y), (70, 70, 80, 255))
    for (x, y) in extra:
        img.putpixel((x, y), BODY)
    return img


class StabilizeTest(unittest.TestCase):
    def test_color_noise_and_isolated_flips_are_held(self):
        frames = [frame(), frame(noise=[(5, 5), (8, 9)]), frame(extra=[(2, 2)]), frame(noise=[(10, 6)])]
        out = import_sheet.stabilize_frames(frames, tol=40)
        for f in out:
            self.assertEqual(import_sheet.changed_pixels(out[0], f), 0)

    def test_real_motion_passes(self):
        # el bloque sube 1 px: cambian dos filas enteras (cambio coherente)
        frames = [frame(), frame(block_y=3), frame(block_y=3), frame()]
        out = import_sheet.stabilize_frames(frames, tol=40)
        self.assertEqual(out[1].getchannel("A").getbbox(), (4, 3, 12, 11))
        self.assertEqual(out[3].getchannel("A").getbbox(), (4, 4, 12, 12))

    def test_large_color_change_passes(self):
        blink = frame()
        for x in range(6, 9):
            blink.putpixel((x, 6), (200, 150, 120, 255))
        out = import_sheet.stabilize_frames([frame(), blink, frame()], tol=40)
        self.assertEqual(out[1].getpixel((7, 6)), (200, 150, 120, 255))
        self.assertEqual(out[2].getpixel((7, 6)), BODY)


if __name__ == "__main__":
    unittest.main()
