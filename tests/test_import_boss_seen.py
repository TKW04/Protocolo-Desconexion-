"""Arte final de El Visto (tools/import_boss_seen.py; paso 24 de
docs/propuesta-mundo-4.md, etapa 2, 2026-10-28; docs/plan-arte-mundo-4.md).

- `--check` sale con 0 con los PNG en disco y con 1 si uno no esta al dia.
- Cuadros por animacion = Seen.ART_ANIMS (cuerpo) y ART_SMALL (silueta).
- Lienzos de 336 x 256 (cuerpo) y 112 x 86 (silueta), esquinas transparentes,
  solo mundo4.gpl sin rojos, ambares, coral ni cremas (salvo el escudo).
- El check gris del dibujo cae en ART_CHECK_PX de la caja (perch_core_px de
  data/bosses/seen.json centrado) y los desplazamientos del importador son los
  de scripts/bosses/seen.gd.

Uso: python3 -m unittest tests/test_import_boss_seen.py
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
import import_boss_seen as ibs  # noqa: E402
from PIL import Image  # noqa: E402

GD = os.path.join(ROOT, "scripts", "bosses", "seen.gd")


def _gd_text():
    with open(GD, encoding="utf-8") as fh:
        return fh.read()


def _gd_vector(name):
    m = re.search(r"const %s: Vector2 = Vector2\(([-\d.]+), ([-\d.]+)\)" % name, _gd_text())
    return (float(m.group(1)), float(m.group(2)))


def _gd_anims():
    block = re.search(r"const ART_ANIMS: Dictionary = \{(.*?)\n\}", _gd_text(), re.S).group(1)
    return {k: int(n) for k, n in re.findall(r'"(\w+)": \[(\d+),', block)}


def _grey_check_center(path, grid):
    """Centro de la mancha de abajo (el check gris), separada por una fila vacia."""
    im = Image.open(path).convert("RGBA")
    px = im.load()
    rows = [y for y in range(0, im.height, grid) if any(px[x, y][3] for x in range(im.width))]
    gaps = [b for a, b in zip(rows, rows[1:]) if b - a > grid]
    top = gaps[-1]
    pts = [(x, y) for y in range(top, im.height) for x in range(im.width) if px[x, y][3]]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return ((min(xs) + max(xs) + 1) / 2.0, (min(ys) + max(ys) + 1) / 2.0)


class ImportBossSeenTest(unittest.TestCase):
    def test_check_passes_on_disk(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(ibs.main(["--check"]), 0, out.getvalue())
        self.assertIn("OK", out.getvalue())

    def test_check_fails_when_a_frame_is_stale(self):
        name = "seen_idle_00.png"
        with tempfile.TemporaryDirectory() as tmp:
            for f in os.listdir(ibs.OUT):
                if f.startswith("seen_") and f.endswith(".png"):
                    shutil.copy(os.path.join(ibs.OUT, f), tmp)
            im = Image.open(os.path.join(tmp, name)).convert("RGBA")
            im.putpixel((im.width // 2, im.height // 2), (255, 74, 42, 255))
            im.save(os.path.join(tmp, name))
            old = (ibs.BODY.out, ibs.SILHOUETTE.out)
            ibs.BODY.out = ibs.SILHOUETTE.out = tmp
            try:
                with contextlib.redirect_stdout(io.StringIO()) as out:
                    self.assertEqual(ibs.main(["--check"]), 1)
            finally:
                ibs.BODY.out, ibs.SILHOUETTE.out = old
        self.assertIn(name, out.getvalue())
        self.assertIn("rojo o coral", out.getvalue())

    def test_frame_counts_match_seen(self):
        anims = _gd_anims()
        self.assertEqual(set(anims), set(ibs.ANIMS))
        for anim, n in anims.items():
            self.assertEqual(len(ibs.parse_cells(ibs.ANIMS[anim])), n, anim)
            self.assertTrue(os.path.exists(os.path.join(ibs.OUT, f"seen_{anim}_{n - 1:02d}.png")), anim)
            self.assertFalse(os.path.exists(os.path.join(ibs.OUT, f"seen_{anim}_{n:02d}.png")), anim)
        small = re.search(r"const ART_SMALL: Array\[String\] = \[(.*?)\]", _gd_text()).group(1)
        self.assertEqual(sorted(re.findall(r'"(\w+)"', small)), sorted(ibs.SMALL_ANIMS))
        for anim in ibs.SMALL_ANIMS:
            n = anims[anim]
            self.assertTrue(os.path.exists(os.path.join(ibs.OUT, f"seen_small_{anim}_{n - 1:02d}.png")), anim)

    def test_canvas_sizes(self):
        self.assertEqual(Image.open(os.path.join(ibs.OUT, "seen_idle_00.png")).size, (336, 256))
        self.assertEqual(Image.open(os.path.join(ibs.OUT, "seen_small_charge_00.png")).size, (112, 86))

    def test_offsets_match_seen_and_the_grey_check_is_centered(self):
        self.assertEqual(_gd_vector("ART_BODY_OFFSET"), tuple(float(v) for v in ibs.BODY_OFFSET_PX))
        self.assertEqual(_gd_vector("ART_SILHOUETTE_OFFSET"), tuple(float(v) for v in ibs.SILHOUETTE_OFFSET_PX))
        with open(os.path.join(ROOT, "data", "bosses", "seen.json"), encoding="utf-8") as fh:
            arena = json.load(fh)["arena"]
        cx, cy = _grey_check_center(os.path.join(ibs.OUT, "seen_idle_00.png"), ibs.BODY.grid)
        check = _gd_vector("ART_CHECK_PX")
        self.assertAlmostEqual(cx + ibs.BODY_OFFSET_PX[0], check[0], delta=0.5)
        self.assertAlmostEqual(cy + ibs.BODY_OFFSET_PX[1], check[1], delta=0.5)
        self.assertAlmostEqual(check[0], arena["perch_core_px"][0], delta=4.0, msg="centrado en la caja")
        self.assertEqual(check[1], arena["perch_core_px"][1])
        sx, sy = _grey_check_center(os.path.join(ibs.OUT, "seen_small_reappear_00.png"), ibs.SILHOUETTE.grid)
        self.assertAlmostEqual(sx + ibs.SILHOUETTE_OFFSET_PX[0], 0.0, delta=2.0, msg="silueta: check gris en el punto debil")
        self.assertAlmostEqual(sy + ibs.SILHOUETTE_OFFSET_PX[1], 0.0, delta=2.0)

    def test_only_the_shield_uses_cream(self):
        cream = {(242, 232, 208), (188, 176, 152)}
        for f in os.listdir(ibs.OUT):
            if not (f.startswith("seen_") and f.endswith(".png")) or "_shield_" in f:
                continue
            colors = {p[:3] for p in Image.open(os.path.join(ibs.OUT, f)).convert("RGBA").getdata() if p[3]}
            self.assertFalse(colors & cream, f)


if __name__ == "__main__":
    unittest.main()
