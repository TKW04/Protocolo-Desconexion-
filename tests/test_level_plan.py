"""Pruebas del plan del camino (paso 10 de docs/propuesta-1-2.md §10, 2026-10-16):
tools/validate_level.py con el laser, el Debug, la energia, los temporizadores, los enemigos
y la exportacion del camino (tools/level_plan.py). Salas de prueba de data/levels/*_test.json
(resultado esperado de cada una) y casos NEGATIVOS sinteticos (tests/support/puzzle_levels.py)
que el validador tiene que detectar como imposibles.
Uso: python3 -m unittest tests/test_level_plan.py
"""

import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level as vl  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, "tests", "support"))
import puzzle_levels as pz  # noqa: E402

SCRIPT = os.path.join(ROOT, "tools", "validate_level.py")
_CACHE = {}


def room(name):
    return pz.load_room(name)


def checked(name):
    """Resultado y camino exportado de una sala de prueba (cacheados)."""
    if name not in _CACHE:
        export = []
        result = vl.validate(room(name), export=export)
        _CACHE[name] = (result, export[0] if export else None)
    return _CACHE[name]


def messages(result, key="errors"):
    return [e["message"] for e in result[key]]


def actions(exported):
    return [(s["action"], s.get("target", {}).get("id")) for s in exported["steps"]]


class RoomsTest(unittest.TestCase):
    """Cada sala de prueba: valida, con su camino exportado y el resultado esperado."""

    def assert_export_shape(self, exported):
        self.assertEqual(exported["format"], "isak-path/1")
        self.assertEqual(exported["tile_size"], 64)
        self.assertEqual(exported["steps"][-1]["action"], "goal")
        times = [s["t"] for s in exported["steps"]]
        self.assertEqual(times, sorted(times), "tiempos crecientes")
        for s in exported["steps"]:
            self.assertIn("duration_s", s)
            if s["action"] in ("walk", "jump", "jump_run", "fall"):
                self.assertIn("cell", s["from"])
                self.assertIn("feet_px", s["to"])
            if s["action"] in ("jump", "jump_run", "fall"):
                self.assertIn("takeoff_x_px", s)
                self.assertIn(s["direction"], (1, -1))
            if s["action"] in ("laser", "pulse") and s.get("target", {}).get("type") != "notification_badge":
                self.assertIn(s["facing"], (1, -1), s)
                self.assertIn("x_px", s)
        self.assertGreaterEqual(exported["energy"]["min"], 0.0)

    def test_correo_test_puzzle_with_margin_and_debug_chip(self):
        result, exported = checked("correo_test")
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        self.assertTrue(result["abilities"]["laser_required"])
        self.assertFalse(result["abilities"]["goal_without_laser"])
        relay = result["plan"]["relays"][0]
        self.assertEqual((relay["lector"], relay["bridge"]), ("lector_1", "puente_correo"))
        self.assertGreaterEqual(relay["spare_s"], 1.5, "sobra el margen de 1,5 s de la ventana de 6 s")
        self.assertEqual(relay["shot_from"][0], 10, "el disparo al lector sale del suelo de la sala")
        self.assert_export_shape(exported)
        seq = actions(exported)
        lector = seq.index(("laser", "lector_1"))
        self.assertEqual(seq[lector + 1:].count(("pulse", "receptor_enlazado_1")), 1)
        self.assertLess(seq.index(("laser", "anuncio_buzon")), seq.index(("pulse", "popup_buzon")),
                        "el anuncio se rompe antes de cerrar el pop-up")
        chip = next(s for s in exported["steps"] if s["action"] == "pickup")
        self.assertEqual(chip["ability"], "debug")
        self.assertTrue(chip["refill_energy"])
        self.assertEqual(chip["energy_after"], 100.0, "el chip llena la energia")
        final = [s for s in exported["steps"] if s.get("final")]
        self.assertEqual(final[0]["target"]["id"], "terminal_correo")
        self.assertEqual(result["plan"]["energy"]["used"], 20.0, "dos disparos: lector y anuncio")

    def test_recordatorios_test_needs_the_snooze(self):
        result, exported = checked("recordatorios_test")
        self.assertTrue(result["ok"], messages(result))
        groups = {r["group"]: r for r in result["plan"]["reminders"]}
        self.assertEqual(set(groups), {"suelto_a", "suelto_b", "posponer_1"})
        snooze = groups["posponer_1"]
        self.assertTrue(snooze["required"])
        self.assertIsNone(snooze["without_snooze"], "sin Posponer no da tiempo")
        self.assertGreaterEqual(snooze["with_snooze"], 1.5, "con el Posponer sobra el margen")
        self.assertEqual(snooze["snooze_shots"], 1)
        for loose in ("suelto_a", "suelto_b"):
            self.assertIsNotNone(groups[loose]["without_snooze"], "los sueltos se cruzan sin parar")
            self.assertEqual(groups[loose]["snooze_shots"], 0)
        # Aviso esperado: el disparo llega con la cuenta en su aviso (sala de 2 s, ajustada).
        self.assertTrue(any("posponer_1" in w and "Posponer" in w for w in messages(result, "warnings")),
                        messages(result, "warnings"))
        self.assert_export_shape(exported)
        shot = next(s for s in exported["steps"] if s["action"] == "laser")
        self.assertEqual(shot["target"]["id"], "snooze_1")
        self.assertEqual(shot["target"]["group"], "posponer_1")
        self.assertEqual(shot["at"]["cell"][1], 7, "de pie sobre un recordatorio")

    def test_overlay_test_closes_the_overlay_from_the_floor(self):
        result, exported = checked("overlay_test")
        self.assertTrue(result["ok"], messages(result))
        overlay = result["plan"]["overlays"][0]
        self.assertTrue(overlay["covers_path"])
        self.assertEqual(overlay["closed_from"][0], 10, "pulso desde el suelo")
        seq = actions(exported)
        close = seq.index(("pulse", "overlay_1"))
        first_up = next(i for i, s in enumerate(exported["steps"]) if s["action"] == "jump")
        self.assertLess(close, first_up, "se cierra antes de subir a la plataforma tapada")
        self.assert_export_shape(exported)

    def test_actualizaciones_test_waits_for_the_bar(self):
        result, exported = checked("actualizaciones_test")
        self.assertTrue(result["ok"], messages(result))
        bar = result["plan"]["bars"][0]
        self.assertEqual(bar["id"], "barra_99")
        self.assertAlmostEqual(bar["wait_s"], 21.6, places=1, msg="rise_s 1 + wait_s 20 + full_s 0,6")
        self.assertEqual(bar["wave_enemies"], 6)
        wait = next(s for s in exported["steps"] if s["action"] == "wait")
        self.assertEqual(wait["target"]["id"], "barra_99")
        self.assertGreaterEqual(exported["duration_s"], 21.6)
        self.assert_export_shape(exported)

    def test_mensajes_test_stuns_red_dots_and_times_the_banners(self):
        result, exported = checked("mensajes_test")
        self.assertTrue(result["ok"], messages(result))
        plan = result["plan"]
        self.assertEqual(plan["sync_damage"], 0.0)
        self.assertTrue(all(b["hits"] == 0 for b in plan["badges"]))
        banners = plan["banners"][0]
        self.assertEqual(set(banners["banners"]), {"banner_1", "banner_2"})
        self.assertIn("start_phase_s", banners)
        sync = next(s for s in exported["steps"] if s["action"] == "wait_phase")
        self.assertEqual(set(sync["banner_cycle_s"]), {"banner_1", "banner_2"})
        self.assertAlmostEqual(sync["period_s"], 3.0)
        stuns = [s for s in exported["steps"] if s.get("target", {}).get("type") == "notification_badge"]
        self.assertTrue(stuns, "los puntos rojos se aturden con el pulso, no se matan")
        self.assertFalse(any(s["action"] == "laser" for s in exported["steps"]))
        self.assert_export_shape(exported)

    def test_silenciados_test_skips_the_dash_banner_with_a_warning(self):
        """Paso 4 de docs/propuesta-1-3.md (2026-10-19): el banner obligatorio con el dash
        (knockback_to_entry) se omite del plan con un aviso hasta el paso 9; el del nicho, si."""
        result, exported = checked("silenciados_test")
        self.assertTrue(result["ok"], messages(result))
        warnings = messages(result, "warnings")
        self.assertTrue(any("banner banner_dash: su pasillo solo se cruza con el dash" in w for w in warnings),
                        warnings)
        banners = result["plan"]["banners"]
        self.assertEqual([b["banners"] for b in banners], [["banner_1b"]])
        sync = next(s for s in exported["steps"] if s["action"] == "wait_phase")
        self.assertEqual(set(sync["banner_cycle_s"]), {"banner_1b"})
        self.assert_export_shape(exported)

    def test_vibracion_test_treats_blink_platforms_as_fixed_with_a_warning(self):
        """Paso 5 de docs/propuesta-1-3.md (2026-10-19): sin modelar el ritmo (paso 9), las plataformas
        que parpadean son tablas fijas y sale un aviso."""
        result, exported = checked("vibracion_test")
        self.assertTrue(result["ok"], messages(result))
        self.assertTrue(any("plataformas que parpadean (5, blink_platform)" in w
                            for w in messages(result, "warnings")), messages(result, "warnings"))
        self.assertEqual(exported["steps"][-1]["action"], "goal")

    def test_tower_test_exports_the_climb(self):
        result, exported = checked("tower_test")
        self.assertTrue(result["ok"], messages(result))
        self.assert_export_shape(exported)
        self.assertEqual(exported["start"]["cell"], [3, 38])
        self.assertEqual(exported["steps"][-1]["at"]["cell"], [22, 2])
        jumps = [s for s in exported["steps"] if s["action"] == "jump"]
        self.assertTrue(all(s["to"]["cell"][1] <= s["from"]["cell"][1] for s in jumps), "solo sube")

    def test_level_1_1_has_no_plan_section(self):
        """El 1-1 no es un nivel del paso 10: su resultado no cambia (sin plan)."""
        result = vl.validate(vl.load_json(os.path.join(ROOT, "data", "levels", "1-1.json")))
        self.assertTrue(result["ok"], messages(result))
        self.assertNotIn("plan", result)
        self.assertNotIn("requirements", result)


class NegativeTest(unittest.TestCase):
    """Casos imposibles a proposito: el validador los detecta con un mensaje claro."""

    def test_window_too_short(self):
        level = room("correo_test")
        pz.obj_by_id(level, "lector_1")["params"]["window_s"] = 2.0
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("la ventana del lector lector_1 (2.0 s) no da tiempo" in m for m in messages(result)),
                        messages(result))

    def test_window_without_margin(self):
        level = room("correo_test")
        pz.obj_by_id(level, "lector_1")["params"]["window_s"] = 3.0
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("el margen minimo es 1.5 s" in m and "sobran 0.9 s" in m for m in messages(result)),
                        messages(result))
        relaxed = vl.validate(copy.deepcopy(level), time_margin=0.5)
        self.assertTrue(relaxed["ok"], messages(relaxed))

    def test_without_energy_and_without_charger(self):
        level = room("correo_test")
        level["validation"]["start_energy"] = 5
        level["objects"] = [o for o in level["objects"] if o["type"] != "charger"]
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any(m.startswith("sin energia en el paso") and "quedan 5 y hacen falta 10" in m
                            for m in messages(result)), messages(result))

    def test_low_energy_takes_a_detour_to_the_charger(self):
        level = room("correo_test")
        level["validation"]["start_energy"] = 5
        exported = []
        result = vl.validate(level, export=exported)
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["plan"]["energy"]["charger_detours"], 1)
        steps = exported[0]["steps"]
        charge = next(i for i, s in enumerate(steps) if s["action"] == "charge")
        first_laser = next(i for i, s in enumerate(steps) if s["action"] == "laser")
        self.assertLess(charge, first_laser, "carga antes del primer disparo")

    def test_hidden_platform_needs_the_debug(self):
        result = vl.validate(pz.hidden_gap(chip=False))
        self.assertFalse(result["ok"])
        self.assertTrue(any("solo se alcanza por plataformas ocultas 'h'" in m for m in messages(result)),
                        messages(result))

    def test_hidden_platform_after_the_chip(self):
        exported = []
        result = vl.validate(pz.hidden_gap(), export=exported)
        self.assertTrue(result["ok"], messages(result))
        debug = result["plan"]["debug"]
        self.assertTrue(debug["required"])
        self.assertEqual(len(debug["segments"]), 1)
        self.assertLess(debug["segments"][0]["energy"], 100.0)
        seq = [s["action"] for s in exported[0]["steps"]]
        self.assertLess(seq.index("pickup"), seq.index("debug_on"))
        self.assertLess(seq.index("debug_on"), seq.index("debug_off"))
        on = exported[0]["steps"][seq.index("debug_on")]
        self.assertEqual(on["hold_s"], 1.0)
        crossing = exported[0]["steps"][seq.index("debug_on") + 1:seq.index("debug_off")]
        self.assertTrue(any(s.get("debug") for s in crossing), "los saltos a la plataforma oculta van con Debug")

    def test_hidden_platform_without_energy(self):
        result = vl.validate(pz.hidden_gap(refill=False, start_energy=20))
        self.assertFalse(result["ok"])
        self.assertTrue(any(m.startswith("sin energia en el paso") and "Debug" in m and "quedan 20" in m
                            for m in messages(result)), messages(result))

    def test_debug_required_but_not_needed(self):
        level = pz.hidden_gap()
        level["grid"][7] = "#######.--.#########"
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("exige el Debug (validation.debug_required)" in m for m in messages(result)),
                        messages(result))

    def test_ledge_six_tiles_up(self):
        level = room("tower_test")
        for row in (31, 29):  # repisas del piso 1: la siguiente queda a 6 tiles del suelo (fila 33)
            level["grid"][row] = level["grid"][row].replace("-", ".")
        result = vl.validate(level, check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("Isak no sube de la fila 32" in m and "Piso 1" in m for m in messages(result)),
                        messages(result))

    def test_snooze_required_but_not_needed(self):
        level = room("recordatorios_test")
        for o in level["objects"]:
            if o["type"] == "reminder_platform" and o["params"]["group"] == "posponer_1":
                o["params"]["timer_s"] = 8.0
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("posponer_1: se cruza SIN Posponer" in m for m in messages(result)), messages(result))

    def test_snooze_out_of_reach(self):
        level = room("recordatorios_test")
        level["objects"] = [o for o in level["objects"] if o["type"] != "snooze_button"]
        result = vl.validate(level, check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("posponer_1: no se cruza ni con el Posponer" in m for m in messages(result)),
                        messages(result))

    def test_reminder_group_falls_before_crossing(self):
        level = room("recordatorios_test")
        del level["validation"]
        level["objects"] = [o for o in level["objects"] if o["type"] != "snooze_button"]
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("posponer_1: cae antes de cruzarlo" in m for m in messages(result)), messages(result))

    def test_banners_under_a_low_ceiling(self):
        result = vl.validate(pz.banner_tunnel())
        self.assertFalse(result["ok"])
        self.assertTrue(any("no hay forma de cruzar su pasillo sin dano" in m for m in messages(result)),
                        messages(result))

    def test_long_banner_corridor_needs_a_refuge_at_walking_speed(self):
        """Pasillo largo (16 tiles) con un banner que barre en el sentido de la marcha cada 3 s y sin
        sitio para saltarlo (como banner_2 del 1-2; 2026-10-19): andando no se cruza sin dano; con un
        nicho de refugio a medio pasillo, si, y el camino exportado no toca ningun barrido andando a
        walk_speed (comprobacion independiente de la busqueda por fase)."""
        result = vl.validate(pz.long_banner_corridor())
        self.assertFalse(result["ok"])
        self.assertTrue(any("banners banner_1: no hay forma de cruzar su pasillo sin dano" in m
                            for m in messages(result)), messages(result))
        level = pz.long_banner_corridor(niche=True)
        export = []
        result = vl.validate(level, export=export)
        self.assertTrue(result["ok"], messages(result))
        rules = vl.Rules()
        hitbox = (rules.hitbox_w, rules.hitbox_h)
        self.assertEqual(pz.banner_walk_hits(level, export[0], hitbox, rules.walk_speed), [])
        # Se refugia en el nicho: espera en su repisa o salta el banner bajo su techo abierto.
        self.assertTrue(any(s["action"] in ("jump", "jump_run", "hop", "wait")
                            and 25 <= (s.get("from") or s.get("at"))["cell"][0] <= 28
                            for s in export[0]["steps"] if s.get("from") or s.get("at")), "usa el nicho")
        # Los dos banners desfasados de mensajes_test, igual.
        room_result, exported = checked("mensajes_test")
        self.assertEqual(pz.banner_walk_hits(room("mensajes_test"), exported, hitbox, rules.walk_speed), [])

    def test_ad_cover_without_laser(self):
        level = room("correo_test")
        level["abilities_available"]["laser"] = False
        del level["validation"]
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("anuncio anuncio_buzon necesita el laser" in m for m in messages(result)),
                        messages(result))
        self.assertTrue(any("el lector lector_1 necesita el laser" in m for m in messages(result)), messages(result))

    def test_laser_required_but_not_needed(self):
        level = room("overlay_test")
        level["validation"] = {"laser_required": True}
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("exige el laser (validation.laser_required)" in m for m in messages(result)),
                        messages(result))


class CliTest(unittest.TestCase):
    def test_export_path_writes_the_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, "camino.json")
            proc = subprocess.run([sys.executable, SCRIPT, "--export-path", out,
                                   os.path.join(ROOT, "data", "levels", "overlay_test.json")],
                                  capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertIn("camino exportado", proc.stdout)
            with open(out, encoding="utf-8") as handle:
                data = json.load(handle)
            self.assertEqual(data["format"], "isak-path/1")
            self.assertEqual(data["level"], "overlay_test")

    def test_export_path_needs_a_single_level(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run([sys.executable, SCRIPT, "--export-path", os.path.join(tmp, "x.json"),
                                   os.path.join(ROOT, "data", "levels", "overlay_test.json"),
                                   os.path.join(ROOT, "data", "levels", "correo_test.json")],
                                  capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(proc.returncode, 2)

    def test_time_margin_option(self):
        level = room("correo_test")
        pz.obj_by_id(level, "lector_1")["params"]["window_s"] = 3.0
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "correo_corto_test.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump(level, handle)
            strict = subprocess.run([sys.executable, SCRIPT, path], capture_output=True, text=True, cwd=ROOT)
            relaxed = subprocess.run([sys.executable, SCRIPT, "--time-margin", "0.5", path],
                                     capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(strict.returncode, 1, strict.stdout)
        self.assertEqual(relaxed.returncode, 0, relaxed.stdout)


if __name__ == "__main__":
    unittest.main()
