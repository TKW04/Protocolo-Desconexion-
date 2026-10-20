"""Validador del catalogo de audio (tools/validate_audio.py; 2026-10-20, docs/lista-sonidos.md).

El catalogo real es valido; un bus inexistente, una senal o clase que no existe, un sonido sin
entrada y un id que nombra la vuelta son errores; un archivo ausente no lo es (se lista aparte).
"""
import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import validate_audio as va  # noqa: E402


class AudioCatalogTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = va._load(va.DEFAULT_PATH)
        cls.layout = va.layout_buses()
        cls.signals = va.event_bus_signals()
        cls.classes = va.script_classes()

    def errors(self, data):
        return va.validate(data, self.layout, self.signals, self.classes)

    def mutated(self):
        return copy.deepcopy(self.data)

    def test_real_catalog_is_valid(self):
        self.assertEqual(self.errors(self.data), [])

    def test_layout_defines_the_six_buses(self):
        self.assertEqual(list(self.layout), va.BUSES)
        self.assertTrue(all(send == "Master" for bus, send in self.layout.items() if bus != "Master"))

    def test_unknown_bus_is_an_error(self):
        data = self.mutated()
        data["sounds"]["sfx_isak_jump"]["bus"] = "NoExiste"
        self.assertTrue(any("bus" in e for e in self.errors(data)))

    def test_unknown_signal_class_and_sound_are_errors(self):
        data = self.mutated()
        data["event_bus"].append({"signal": "no_existe", "sound": "sfx_isak_jump"})
        data["nodes"].append({"class": "NoExiste", "signal": "x", "sound": "sfx_isak_jump"})
        data["nodes"].append({"class": "Isak", "signal": "no_existe", "sound": "sfx_isak_jump"})
        data["nodes"].append({"class": "Isak", "signal": "hurt", "sound": "sfx_no_esta"})
        errors = self.errors(data)
        self.assertEqual(len(errors), 4, errors)

    def test_inherited_signal_is_accepted(self):
        data = self.mutated()
        data["nodes"].append({"class": "AlarmTunnel", "signal": "beat", "sound": "sfx_metronome_tick"})
        self.assertEqual(self.errors(data), [])

    def test_lap_words_and_bad_values(self):
        data = self.mutated()
        data["sounds"]["vox_eco_blip_normal"] = {"bus": "Voice"}
        data["sounds"]["sfx_x"] = {"bus": "World", "volume_db": 20, "pitch_random": 2, "loop": "si"}
        data["sounds"]["amb_y"] = {"bus": "Ambience", "loop": True, "time": "world"}
        errors = self.errors(data)
        self.assertTrue(any("vuelta" in e for e in errors))
        self.assertTrue(any("volume_db" in e for e in errors))
        self.assertTrue(any("pitch_random" in e for e in errors))
        self.assertTrue(any("booleano" in e for e in errors))
        self.assertTrue(any("bucle" in e for e in errors))

    def test_missing_file_is_not_an_error(self):
        data = self.mutated()
        data["sounds"]["sfx_sin_archivo"] = {"bus": "World", "files": ["no_existe_nunca"]}
        self.assertEqual(self.errors(data), [])
        self.assertIn("sfx_sin_archivo", va.missing_files(data))
        self.assertNotIn("sfx_isak_jump", va.missing_files(data))


if __name__ == "__main__":
    unittest.main()
