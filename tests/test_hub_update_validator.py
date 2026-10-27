"""Validador de la pagina 2 del hub «Actualizacion del sistema» (paso 4 de docs/propuesta-hub-mundos-4-6.md §2.7,
2026-10-27; tools/hub_update_model.py, al que delega tools/validate_level.py con data/hub_update.json): con todas las
habilidades se hacen V1, V2, V3 y se llega al instalador; sin el dash o sin el golpe al suelo falla V2, sin Pellizcar
falla V3 y sin el Debug falla V1; RE no se alcanza desde el suelo, el bloque no sin la plataforma y el nicho no con el
marco cerrado; ventanas con margen y energia dentro de la barra; datos rotos dan error.
Uso: python3 tests/test_hub_update_validator.py
"""

import contextlib
import copy
import io
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import hub_update_model  # noqa: E402
import validate_level as vl  # noqa: E402

DATA_PATH = os.path.join(ROOT, "data", "hub_update.json")


def load_data():
    with open(DATA_PATH, encoding="utf-8") as handle:
        return json.load(handle)


class HubUpdateValidatorTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = load_data()
        cls.result = hub_update_model.validate_hub_update(cls.data)

    def test_valid_with_all_abilities(self):
        r = self.result
        self.assertTrue(r["ok"], r["errors"])
        for cid in hub_update_model.CHECK_IDS:
            self.assertTrue(r["checks"][cid]["ok"], (cid, r["checks"][cid].get("why")))

    def test_required_negatives_fail(self):
        neg = self.result["negatives"]
        self.assertFalse(neg["dash"]["v2"], "sin dash, V2 no se alcanza")
        self.assertFalse(neg["ground_pound"]["v2"], "sin golpe al suelo, V2 no se alcanza")
        self.assertFalse(neg["compress"]["v3"], "sin Pellizcar, V3 no se alcanza")
        self.assertFalse(neg["debug"]["v1"], "sin Debug, V1 no se alcanza")

    def test_negatives_only_break_their_check(self):
        neg = self.result["negatives"]
        self.assertEqual({c: neg["dash"][c] for c in ("v1", "v3", "installer")}, {"v1": True, "v3": True,
                                                                                  "installer": True})
        self.assertEqual({c: neg["compress"][c] for c in ("v1", "v2", "installer")}, {"v1": True, "v2": True,
                                                                                      "installer": True})
        self.assertEqual({c: neg["debug"][c] for c in ("v2", "v3", "installer")}, {"v2": True, "v3": True,
                                                                                   "installer": True})
        self.assertFalse(any(neg["pulse"][c] for c in hub_update_model.CHECK_IDS), "sin pulso no se hace nada")
        self.assertFalse(neg["laser"]["v1"] or neg["laser"]["v3"])

    def test_design_rules(self):
        c = self.result["checks"]
        self.assertEqual(c["v1"]["relay_from_floor"], [], "RE no se alcanza desde el suelo")
        self.assertTrue(c["v1"]["shelf"], "se sube a la repisa de RE")
        self.assertFalse(c["v2"]["block_without_platform"], "el bloque no se alcanza sin la plataforma")
        self.assertTrue(c["v2"]["leap"]["dash"], "al bloque se llega con el dash aereo")
        self.assertFalse(c["v3"]["niche_with_barrier"], "el nicho no se alcanza con el marco cerrado")
        self.assertGreaterEqual(c["v3"]["bounces"], 1, "lector3 por el espejo")
        self.assertTrue(c["v2"]["returns"] and c["v3"]["returns"], "sin atascos")

    def test_windows_and_energy(self):
        c = self.result["checks"]
        for cid in ("v1", "v2"):
            self.assertGreaterEqual(c[cid]["margin_s"], vl.DEFAULT_TIME_MARGIN_S - vl.EPS, cid)
        e = self.result["energy"]
        self.assertLessEqual(e["need"], e["max"])
        self.assertGreater(e["need"], 0.0)

    def test_cli_delegates(self):
        # validate_level.main con data/hub_update.json delega en hub_update_model (en el proceso: reutiliza el
        # resultado ya calculado).
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = vl.main(["validate_level.py", DATA_PATH])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("acertijo del hub (pagina 2) OK", out.getvalue())
        self.assertIn("sin dash: fallan V2", out.getvalue())

    def test_levels_are_not_hub_update(self):
        with open(os.path.join(ROOT, "data", "levels", "1-1.json"), encoding="utf-8") as handle:
            self.assertFalse(hub_update_model.is_hub_update(json.load(handle)))
        self.assertTrue(hub_update_model.is_hub_update(self.data))


class HubUpdateValidatorBrokenDataTest(unittest.TestCase):
    """Datos rotos (sin los negativos, para ir rapido): el validador lo detecta."""

    def _validate(self, mutate):
        data = copy.deepcopy(load_data())
        mutate(data)
        return hub_update_model.validate_hub_update(data, negatives=False)

    def test_low_shelf_lets_pulse_reach_re_from_floor(self):
        r = self._validate(lambda d: d["v1"].__setitem__("shelf_height_px", 64))
        self.assertFalse(r["ok"])
        self.assertTrue(any("RE desde el suelo" in e["message"] for e in r["errors"]), r["errors"])

    def test_short_platform_window(self):
        r = self._validate(lambda d: d["v2"].__setitem__("up_s", 1.5))
        self.assertFalse(r["ok"])
        self.assertTrue(any(e["message"].startswith("V2: a la ventana") for e in r["errors"]), r["errors"])


if __name__ == "__main__":
    unittest.main()
