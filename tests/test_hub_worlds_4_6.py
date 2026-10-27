"""Datos del upgrade del hub (paso 0 de docs/propuesta-hub-mundos-4-6.md, 2026-10-27): m4-m6 de data/hub.json con
page, col, requires_upgrade hub_update_4_6 y unlocked_by en orden (3-boss, 4-boss, 5-boss); la pagina 1 sigue con
M1-M3 en las columnas 4, 10 y 16 (el hub de hoy no cambia); seccion hub_upgrades con el acertijo tras 3-boss y la
bandera enforce_requires_upgrade (true desde el paso 5, la instalacion en el hub); guardado v6.
Uso: python3 -m unittest tests/test_hub_worlds_4_6.py
"""

import json
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HUB_PATH = os.path.join(ROOT, "data", "hub.json")
GAME_STATE = os.path.join(ROOT, "scripts", "autoload", "game_state.gd")
UPGRADE = "hub_update_4_6"


def load_hub():
    with open(HUB_PATH, encoding="utf-8") as handle:
        return json.load(handle)


class HubWorlds46DataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.hub = load_hub()
        cls.worlds = {w["id"]: w for w in cls.hub["worlds"]}

    def test_worlds_4_to_6(self):
        expected = {"m4": (2, 4, ["3-boss"]), "m5": (2, 14, ["4-boss"]), "m6": (3, 9, ["5-boss"])}
        for wid, (page, col, unlocked_by) in expected.items():
            world = self.worlds[wid]
            self.assertEqual(world.get("page"), page, wid)
            self.assertEqual(world.get("col"), col, wid)
            self.assertEqual(world.get("unlocked_by"), unlocked_by, wid)
            self.assertEqual(world.get("requires_upgrade"), UPGRADE, wid)
            self.assertFalse(world.get("unlocked", False), wid)

    def test_page_1_is_unchanged(self):
        page1 = [w for w in self.hub["worlds"] if "col" in w and int(w.get("page", 1)) == 1]
        self.assertEqual([(w["id"], w["col"]) for w in page1], [("m1", 4), ("m2", 10), ("m3", 16)])
        for w in page1:
            self.assertNotIn("requires_upgrade", w)

    def test_no_column_clash_per_page(self):
        used = {}
        for w in self.hub["worlds"]:
            if "col" not in w:
                continue
            page = int(w.get("page", 1))
            for c in (w["col"], w["col"] + 1):
                self.assertNotIn((page, c), used, "%s pisa a %s" % (w["id"], used.get((page, c))))
                used[(page, c)] = w["id"]

    def test_hub_upgrades_section(self):
        section = self.hub["hub_upgrades"]
        self.assertIs(section["enforce_requires_upgrade"], True, "Se aplica desde el paso 5 (instalacion)")
        self.assertEqual(section["upgrades"][UPGRADE]["after_level"], "3-boss")
        boss_ids = {lvl["id"] for w in self.hub["worlds"] for lvl in w.get("levels", [])}
        self.assertIn("3-boss", boss_ids)
        for w in self.hub["worlds"]:
            if "requires_upgrade" in w:
                self.assertIn(w["requires_upgrade"], section["upgrades"], w["id"])

    def test_game_state_knows_the_upgrade_and_v6(self):
        with open(GAME_STATE, encoding="utf-8") as handle:
            src = handle.read()
        self.assertRegex(src, r"const SAVE_VERSION: int = 6\b")
        self.assertIn('&"%s"' % UPGRADE, src)
        self.assertTrue(re.search(r'"hub_upgrades": _keys_sorted\(hub_upgrades\)', src), "Se escribe en el guardado")


if __name__ == "__main__":
    unittest.main()
