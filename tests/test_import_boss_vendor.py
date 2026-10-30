"""Arte final de El Vendedor (tools/import_boss_vendor.py; paso 24 de
docs/propuesta-mundo-5.md, etapa 2, 2026-10-30; docs/plan-arte-mundo-5.md).

- `--check` sale con 0 con los PNG en disco y con 1 si uno no esta al dia.
- Cuadros por animacion = Vendor.ART_ANIMS; las que se reflejan (ART_FLIP).
- Lienzo de 512 x 368, esquinas transparentes, solo mundo5.gpl sin rojos,
  ambares ni el blanco del Debug.
- El cuerpo llena la caja de 4 x 5 tiles (arena.machine de data/bosses/vendor.json)
  en ART_BODY_OFFSET, que es el del importador.
- Contraste: el borde (violeta neon) llega a 3:1 con el fondo de la arena.

Uso: python3 -m unittest tests/test_import_boss_vendor.py
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
import import_boss_vendor as ibv  # noqa: E402
import reduce_palette  # noqa: E402
from PIL import Image  # noqa: E402

GD = os.path.join(ROOT, "scripts", "bosses", "vendor.gd")


def _gd_text():
    with open(GD, encoding="utf-8") as fh:
        return fh.read()


def _gd_vector(name):
    m = re.search(r"const %s: Vector2 = Vector2\(([-\d.]+), ([-\d.]+)\)" % name, _gd_text())
    return (float(m.group(1)), float(m.group(2)))


def _gd_anims():
    block = re.search(r"const ART_ANIMS: Dictionary = \{(.*?)\n\}", _gd_text(), re.S).group(1)
    return {k: int(n) for k, n in re.findall(r'"(\w+)": \[(\d+),', block)}


def _luminance(rgb):
    def ch(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _ratio(a, b):
    la, lb = sorted((_luminance(a), _luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


class ImportBossVendorTest(unittest.TestCase):
    def test_check_passes_on_disk(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(ibv.main(["--check"]), 0, out.getvalue())
        self.assertIn("OK", out.getvalue())

    def test_check_fails_when_a_frame_is_stale(self):
        name = "vendor_idle_00.png"
        with tempfile.TemporaryDirectory() as tmp:
            for f in os.listdir(ibv.OUT):
                if f.endswith(".png"):
                    shutil.copy(os.path.join(ibv.OUT, f), tmp)
            im = Image.open(os.path.join(tmp, name)).convert("RGBA")
            im.putpixel((im.width // 2, im.height // 2), (255, 74, 42, 255))
            im.save(os.path.join(tmp, name))
            old = ibv.OUT
            ibv.OUT = tmp
            try:
                with contextlib.redirect_stdout(io.StringIO()) as out:
                    self.assertEqual(ibv.main(["--check"]), 1)
            finally:
                ibv.OUT = old
        self.assertIn(name, out.getvalue())
        self.assertIn("reservados", out.getvalue())

    def test_frame_counts_match_vendor(self):
        anims = _gd_anims()
        self.assertEqual(set(anims), set(ibv.ANIMS))
        for anim, n in anims.items():
            self.assertEqual(len(ibv.parse_cells(ibv.ANIMS[anim])), n, anim)
            self.assertTrue(os.path.exists(os.path.join(ibv.OUT, f"vendor_{anim}_{n - 1:02d}.png")), anim)
            self.assertFalse(os.path.exists(os.path.join(ibv.OUT, f"vendor_{anim}_{n:02d}.png")), anim)
        flip = re.search(r"const ART_FLIP: Array\[String\] = \[(.*?)\]", _gd_text()).group(1)
        self.assertEqual(set(re.findall(r'"(\w+)"', flip)), {"idle", "turn", "throw"})

    def test_canvas_and_offset_match_the_machine_box(self):
        self.assertEqual(Image.open(os.path.join(ibv.OUT, "vendor_idle_00.png")).size, tuple(ibv.CANVAS))
        self.assertEqual(ibv.CANVAS, (512, 368))
        self.assertEqual(_gd_vector("ART_BODY_OFFSET"), tuple(float(v) for v in ibv.BODY_OFFSET_PX))
        with open(os.path.join(ROOT, "data", "bosses", "vendor.json"), encoding="utf-8") as fh:
            machine = json.load(fh)["arena"]["machine"]
        self.assertEqual((machine[2] * 64, machine[3] * 64), (ibv.BODY_ART[0] * ibv.GRID, ibv.BODY_ART[1] * ibv.GRID))
        # El cuerpo del dibujo llena la caja: la columna central es opaca de arriba abajo.
        im = Image.open(os.path.join(ibv.OUT, "vendor_offer_00.png")).convert("RGBA")
        ox, oy = -ibv.BODY_OFFSET_PX[0], -ibv.BODY_OFFSET_PX[1]
        col = [im.getpixel((ox + 128, y))[3] for y in range(im.height)]
        top = col.index(255)
        bottom = len(col) - 1 - col[::-1].index(255)
        self.assertLessEqual(abs(top - oy), ibv.GRID * 2, "arriba de la caja")
        self.assertLessEqual(abs(bottom + 1 - (oy + 320)), ibv.GRID * 2, "abajo de la caja")

    def test_edge_reads_on_the_arena_background(self):
        pal = dict(reduce_palette.load_gpl(ibv.GPL))
        edge = tuple(pal[ibv.EDGE])
        for bg in ("negro_fondo", "negro_medio", "gris_escaparate"):
            self.assertGreaterEqual(_ratio(edge, tuple(pal[bg])), 3.0, bg)
        im = Image.open(os.path.join(ibv.OUT, "vendor_idle_00.png")).convert("RGBA")
        px = im.load()
        w, h = im.size
        border = [px[x, y][:3] for y in range(h) for x in range(w)
                  if px[x, y][3] and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not px[x + dx, y + dy][3]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        self.assertTrue(border)
        self.assertTrue(all(c == edge for c in border), "todo el borde de la silueta en violeta neon")


if __name__ == "__main__":
    unittest.main()
