"""Pruebas de tools/check_gut_log.sh (la comprobacion de tools/run_tests.sh que
evita que un script de prueba con un error de sintaxis deje la suite en verde:
GUT lo ignora y sale con 0). Prueba negativa sin archivos rotos en el repo: usa
salidas de GUT de ejemplo (copiadas de una ejecucion real de GUT 9.7 con un
test_*.gd roto, 2026-10-16) y una carpeta de pruebas temporal.
Uso: python3 -m unittest tests/test_run_tests_guard.py
"""

import os
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "check_gut_log.sh")

HEADER = """Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

---  GUT  ---
GUT version:  9.7.1
"""
# Lo que imprime GUT 9.7 cuando un test_*.gd tiene un error de sintaxis (y despues sale con 0).
BROKEN = """SCRIPT ERROR: Parse Error: Expected expression for variable initial value after "=".
          at: GDScript::reload (res://tests/test_b.gd:4)
ERROR: Failed to load script "res://tests/test_b.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
[GUT WARNING]:  Ignoring script res://tests/test_b.gd because it does not extend GutTest
"""
TAIL = """
Totals
------
Scripts               1
Tests                 1
Passing Tests         1
"""


def ran(path):
    # GUT subraya la ruta con codigos de color en lineas aparte.
    return "\x1b[4m\n%s\n\x1b[0m* test_ok\n1/1 passed.\n" % path


class CheckGutLogTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.tests = os.path.join(self.tmp.name, "tests")
        os.makedirs(os.path.join(self.tests, "support"))
        for name in ("test_a.gd", "test_b.gd", os.path.join("support", "helper.gd")):
            with open(os.path.join(self.tests, name), "w", encoding="utf-8") as handle:
                handle.write("extends GutTest\n")

    def tearDown(self):
        self.tmp.cleanup()

    def check(self, text, *extra):
        log = os.path.join(self.tmp.name, "gut.log")
        with open(log, "w", encoding="utf-8") as handle:
            handle.write(text)
        return subprocess.run(["bash", SCRIPT, log, self.tests, *extra], capture_output=True, text=True)

    def test_all_scripts_ran_passes(self):
        result = self.check(HEADER + ran("res://tests/test_a.gd") + ran("res://tests/test_b.gd") + TAIL)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_parse_error_fails_even_if_gut_is_green(self):
        result = self.check(HEADER + BROKEN + ran("res://tests/test_a.gd") + TAIL)
        self.assertEqual(result.returncode, 6)
        self.assertIn("Parse Error", result.stderr)
        self.assertIn("res://tests/test_b.gd", result.stderr)

    def test_parse_error_fails_in_a_partial_run(self):
        result = self.check(HEADER + BROKEN + ran("res://tests/test_a.gd") + TAIL, "--partial")
        self.assertEqual(result.returncode, 6)

    def test_script_that_did_not_run_fails(self):
        result = self.check(HEADER + ran("res://tests/test_a.gd") + TAIL)
        self.assertEqual(result.returncode, 6)
        self.assertIn("no ejecuto", result.stderr)
        self.assertIn("res://tests/test_b.gd", result.stderr)
        self.assertNotIn("helper.gd", result.stderr, "Los archivos de apoyo no son pruebas")

    def test_partial_run_does_not_require_every_script(self):
        result = self.check(HEADER + ran("res://tests/test_a.gd") + TAIL, "--partial")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_run_tests_uses_the_check(self):
        with open(os.path.join(ROOT, "tools", "run_tests.sh"), encoding="utf-8") as handle:
            text = handle.read()
        self.assertIn("check_gut_log.sh", text)
        self.assertIn("exit 6", text)


if __name__ == "__main__":
    unittest.main()
