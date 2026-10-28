"""Arte final del Troll (tools/import_troll.py; paso 24 de docs/propuesta-mundo-4.md,
etapa 3b, 2026-10-28; docs/plan-arte-mundo-4.md).

- `--check` sale con 0 con los PNG en disco y con 1 si uno no esta al dia o
  tiene rojo / coral.
- Cuadros por animacion = Troll.ART_ANIMS; lienzo de 80 x 108 con esquinas
  transparentes; ART_OFFSET del script = ART_OFFSET_PX del importador.
- Pies en la ultima fila del dibujo (el origen del Troll) y ~76 px de alto: el
  dibujo sobresale por encima de la caja de 40 x 56 (body_size).

Uso: python3 -m unittest tests/test_import_troll.py
"""
import contextlib
import io
import json
import os
import re
import shutil
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import import_troll as it  # noqa: E402
from PIL import Image  # noqa: E402

GD = os.path.join(ROOT, "scripts", "enemies", "troll.gd")


def _gd_text():
    with open(GD, encoding="utf-8") as fh:
        return fh.read()


def _gd_anims():
    block = re.search(r"const ART_ANIMS: Dictionary = \{(.*?)\n\}", _gd_text(), re.S).group(1)
    return {k: int(n) for k, n in re.findall(r'"(\w+)": \[(\d+),', block)}


def _opaque_rows(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    return [y for y in range(im.height) if any(px[x, y][3] for x in range(im.width))]


class ImportTrollTest(unittest.TestCase):
    def test_check_passes_on_disk(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(it.main(["--check"]), 0, out.getvalue())
        self.assertIn("OK", out.getvalue())

    def test_check_fails_when_a_frame_is_stale_or_red(self):
        name = "troll_idle_00.png"
        with tempfile.TemporaryDirectory() as tmp:
            for f in os.listdir(it.OUT):
                if f.startswith("troll_") and f.endswith(".png"):
                    shutil.copy(os.path.join(it.OUT, f), tmp)
            im = Image.open(os.path.join(tmp, name)).convert("RGBA")
            im.putpixel((im.width // 2, im.height // 2), (255, 74, 42, 255))
            im.save(os.path.join(tmp, name))
            with contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(it.check(tmp), 1)
        self.assertIn(name, out.getvalue())
        self.assertIn("rojo o coral", out.getvalue())

    def test_frame_counts_match_the_troll(self):
        anims = _gd_anims()
        self.assertEqual(set(anims), set(it.ANIMS))
        for anim, n in anims.items():
            self.assertEqual(len(it.parse_cells(it.ANIMS[anim][1])), n, anim)
            self.assertTrue(os.path.exists(os.path.join(it.OUT, f"troll_{anim}_{n - 1:02d}.png")), anim)
            self.assertFalse(os.path.exists(os.path.join(it.OUT, f"troll_{anim}_{n:02d}.png")), anim)
        warn = re.search(r'"anticipation_frames": (\d+)', open(os.path.join(ROOT, "data", "enemies", "troll.json"),
                                                              encoding="utf-8").read())
        self.assertEqual(anims["typing"], int(warn.group(1)), "un cuadro de typing por cuadro del aviso")

    def test_canvas_offset_feet_and_height(self):
        m = re.search(r"const ART_OFFSET: Vector2 = Vector2\(([-\d.]+), ([-\d.]+)\)", _gd_text())
        self.assertEqual((float(m.group(1)), float(m.group(2))), tuple(float(v) for v in it.ART_OFFSET_PX))
        path = os.path.join(it.OUT, "troll_idle_00.png")
        self.assertEqual(Image.open(path).size, (80, 108))
        rows = _opaque_rows(path)
        feet = rows[-1] + 1 + it.ART_OFFSET_PX[1]
        self.assertEqual(feet, 0, "pies en el origen")
        height = rows[-1] + 1 - rows[0]
        self.assertAlmostEqual(height, 76, delta=2)
        gd_h = float(re.search(r"const ART_HEIGHT_PX: float = ([\d.]+)", _gd_text()).group(1))
        self.assertAlmostEqual(height, gd_h, delta=2)
        with open(os.path.join(ROOT, "data", "enemies", "troll.json"), encoding="utf-8") as fh:
            data = json.load(fh)
        self.assertGreater(height, data["body_size"][1], "sobresale por encima de la caja")
        self.assertFalse(data["art_placeholder"])


if __name__ == "__main__":
    unittest.main()
