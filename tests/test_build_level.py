"""Pruebas de tools/build_level.py (generador de la escena del nivel desde el JSON).
Uso: python3 -m unittest tests/test_build_level.py
"""

import copy
import hashlib
import json
import os
import re
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build_level as bl  # noqa: E402

LEVEL_PATH = os.path.join(ROOT, "data", "levels", "1-1.json")
SCENE_PATH = os.path.join(ROOT, "scenes", "levels", "1-1.tscn")
SCRIPT = os.path.join(ROOT, "tools", "build_level.py")


def load_level():
    with open(LEVEL_PATH, encoding="utf-8") as handle:
        return json.load(handle)


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def tile_cells(text):
    match = re.search(r"tile_map_data = PackedByteArray\(([^)]*)\)", text)
    data = [int(b) for b in match.group(1).split(",")]
    cells = {}
    for i in range(2, len(data), 12):
        u = lambda k: data[i + k] | (data[i + k + 1] << 8)
        cells[(u(0), u(2))] = (u(4), u(6), u(8), u(10))
    return data[:2], cells


class BuildLevelTest(unittest.TestCase):
    def test_idempotent_and_committed_scene_up_to_date(self):
        first = bl.build_scene(load_level())
        second = bl.build_scene(load_level())
        self.assertEqual(sha(first), sha(second))
        with open(SCENE_PATH, encoding="utf-8") as handle:
            committed = handle.read()
        self.assertEqual(sha(first), sha(committed), "regenera con: python3 tools/build_level.py data/levels/1-1.json")
        check = subprocess.run([sys.executable, SCRIPT, "--check", LEVEL_PATH], capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stdout + check.stderr)

    def test_tiles_follow_grid_and_neighbor_rules(self):
        level = load_level()
        header, cells = tile_cells(bl.build_scene(level))
        self.assertEqual(header, [0, 0])
        grid = level["grid"]
        expected = {(c, r) for r, row in enumerate(grid) for c, ch in enumerate(row) if ch in "#-^"}
        self.assertEqual(set(cells), expected)
        tilemap = bl.load_json(os.path.join(ROOT, "data", "tileset_mundo1.json"))
        # Una via: extremos y centro.
        self.assertEqual(list(cells[(27, 8)][1:3]), tilemap["one_way"]["left"])
        self.assertEqual(list(cells[(28, 8)][1:3]), tilemap["one_way"]["center"])
        self.assertEqual(list(cells[(30, 8)][1:3]), tilemap["one_way"]["right"])
        # Suelo con el cielo encima: mascara E|S|W = 14.
        self.assertEqual(list(cells[(5, 10)][1:3]), tilemap["solid"]["by_mask"]["14"])
        # La pared con glitch cuenta como solida para el tile de su derecha (columna 299, fila 8).
        solid = bl.solid_grid(level, bl.load_json(os.path.join(ROOT, "data", "world1_objects.json")))
        self.assertEqual(solid[8][298], "#")
        self.assertEqual(list(cells[(299, 8)][1:3]), bl.select_tile(solid, 8, 299, tilemap))

    def test_objects_params_and_positions(self):
        text = bl.build_scene(load_level())
        self.assertIn("close_button_position = Vector2(4, 192)", text)
        self.assertIn('[node name="popup_1" parent="Objects"', text)
        self.assertIn('target_id = &"puente_1"', text)
        self.assertIn('object_id = &"puente_1"', text)
        self.assertIn('level_id = "1-1"', text)
        self.assertIn("solid_neighbors = 7", text)
        self.assertIn("camera_limits = Rect2i(0, 0, 19200, 896)", text)
        self.assertIn('abilities_available = {"debug": false, "pulse": true}', text)
        self.assertIn('metadata/params = {"patrol_range_px": 320.0, "patrol_speed_px_s": 80.0}', text)
        # P en (4, 3): pies abajo-centro de la celda.
        self.assertRegex(text, r'\[node name="Isak" parent="\." instance=ExtResource\("[^"]+"\)\]\nposition = Vector2\(288, 256\)')
        self.assertEqual(text.count('parent="AttentionPoints"'), "".join(load_level()["grid"]).count("o"))
        self.assertIn('[node name="popup_lejano" parent="Objects"', text)
        self.assertIn("close_button_position = Vector2(52, 192)", text)
        # El 1-1 no tiene power banks (2026-10-15); el tipo se sigue generando (1-2 en adelante).
        self.assertNotIn("power_bank_pickup.tscn", text)
        level = copy.deepcopy(load_level())
        level["objects"].append({"type": "power_bank_pickup", "x": 96, "y": 4, "params": {"id": "power_bank_a"}})
        text = bl.build_scene(level)
        self.assertIn('[node name="power_bank_a" parent="Objects"', text)
        self.assertIn('object_id = &"power_bank_a"', text)

    def test_spikes_get_hazard_area(self):
        level = copy.deepcopy(load_level())
        row = level["grid"][9]
        level["grid"][9] = row[:40] + "^^^" + row[43:]
        text = bl.build_scene(level)
        self.assertIn('[node name="Spikes_40_9" type="Area2D" parent="Hazards"]', text)
        self.assertIn("spike_hazard.gd", text)
        self.assertIn("size = Vector2(192, 32)", text)
        _, cells = tile_cells(text)
        tilemap = bl.load_json(os.path.join(ROOT, "data", "tileset_mundo1.json"))
        self.assertEqual(list(cells[(41, 9)][1:3]), tilemap["spikes"]["floor"])


if __name__ == "__main__":
    unittest.main()
