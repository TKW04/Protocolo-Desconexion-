"""Ilustraciones de los recuerdos de jefe (tools/gen_memory_art.py y
tools/validate_memory_art.py; paso 7 de docs/propuesta-recuerdos.md §11.3, 2026-10-22).

- El arte en disco es valido y esta al dia (el validador sale con 0).
- 6 escenas Kernel de 128x64 y su version Caché borrosa: solo colores de la paleta del
  Mundo 1, sin rojos, opacas, deterministas y con el velo de los bordes.
- La configuracion de data/hub.json: capas 1 y 2 con imagen, la 3 (Raíz) sin ella.

Uso: python3 -m unittest tests/test_memory_art.py
"""
import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_memory_art as gen  # noqa: E402
import validate_memory_art as vma  # noqa: E402
from validate_world1_assets import load_gpl  # noqa: E402


def _load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return json.load(fh)


class MemoryArtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.imgs = gen.outputs()
        cls.pal = (load_gpl(os.path.join(ROOT, "assets/palettes/mundo1.gpl"), set())
                   | load_gpl(os.path.join(ROOT, "assets/palettes/effects_pulse.gpl"), set()))

    def test_validator_exits_zero(self):
        result = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools/validate_memory_art.py")],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_six_kernel_scenes_and_their_cache_versions(self):
        self.assertEqual(len(self.imgs), 12)
        for world in range(1, 7):
            self.assertIn(gen.PATH_SHARP % world, self.imgs)
            self.assertIn(gen.PATH_CACHE % world, self.imgs)

    def test_palette_size_and_no_reds(self):
        reds = {gen.PAL[name][:3] for name in gen.FORBIDDEN}
        for rel, img in self.imgs.items():
            self.assertEqual(img.size, gen.SIZE, rel)
            colors = {px for px in img.getdata()}
            for px in colors:
                self.assertEqual(px[3], 255, "%s: opaca" % rel)
                self.assertIn(px[:3], self.pal, rel)
                self.assertNotIn(px[:3], reds, rel)

    def test_warm_light_and_isak_cyan_in_every_kernel_scene(self):
        for world in range(1, 7):
            colors = {px[:3] for px in self.imgs[gen.PATH_SHARP % world].getdata()}
            self.assertIn(gen.AM[:3], colors, "Luz cálida de casa (mundo %d)" % world)
            self.assertIn(gen.CY[:3], colors, "Detalle cian de Isak (mundo %d)" % world)
            self.assertGreaterEqual(len(colors), 8, "Escena con variedad (mundo %d)" % world)

    def test_cache_is_blurred_with_a_veil(self):
        np = gen.NP
        for world in range(1, 7):
            cache = self.imgs[gen.PATH_CACHE % world]
            sharp = self.imgs[gen.PATH_SHARP % world]
            self.assertNotEqual(cache.tobytes(), sharp.tobytes())
            px = cache.load()
            self.assertEqual(px[0, 0], np, "Velo en la esquina (mundo %d)" % world)
            self.assertLess(len(set(cache.getdata())), len(set(sharp.getdata())) + 1)

    def test_deterministic(self):
        again = gen.outputs()
        for rel, img in self.imgs.items():
            self.assertEqual(img.tobytes(), again[rel].tobytes(), rel)

    def test_config_has_cache_and_kernel_only(self):
        hub, memories = _load("data/hub.json"), _load("data/memories.json")
        self.assertEqual(vma.check_config(hub, memories), [])
        bad = copy.deepcopy(hub)
        bad["album"]["memory_art"]["3"] = "res://x_%d.png"
        self.assertTrue(any("Raíz" in e for e in vma.check_config(bad, memories)))
        bad = copy.deepcopy(hub)
        del bad["album"]["memory_art"]["1"]
        self.assertTrue(any("memory_art[1]" in e for e in vma.check_config(bad, memories)))


if __name__ == "__main__":
    unittest.main()
