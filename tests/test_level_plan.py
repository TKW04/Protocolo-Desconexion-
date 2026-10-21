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

    def test_silenciados_test_crosses_the_mandatory_banner_with_the_dash(self):
        """Paso 9 de docs/propuesta-1-3.md (2026-10-20): el banner obligatorio (knockback_to_entry,
        validation.dash_required) entra en el plan: sin el dash no se cruza (ni andando ni corriendo), con el
        dash si, con una ventana para lanzarlo de al menos 0,3 s; sin avisos de «no se modela»."""
        result, exported = checked("silenciados_test")
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        crossing = result["plan"]["banners"][0]
        self.assertEqual(set(crossing["banners"]), {"banner_dash", "banner_1b"})
        req = crossing["dash_required"]["banner_dash"]
        self.assertFalse(req["without_dash_walking"])
        self.assertFalse(req["without_dash_running"])
        self.assertTrue(req["with_dash"])
        self.assertGreaterEqual(req["dash_window_s"], 0.3)
        self.assertGreaterEqual(crossing["dashes"], 1)
        dashes = [s for s in exported["steps"] if s["action"] == "dash"]
        self.assertTrue(dashes)
        first = dashes[0]
        self.assertTrue(6 <= first["to"]["cell"][0] <= 18, "el dash cruza el pasillo obligatorio")
        self.assertEqual(first["energy_before"] - first["energy_after"], 10.0, "cada dash gasta 10")
        self.assertIn(first["dir"], (1, -1))
        self.assertIn("from_px", first)
        self.assertIn("to_px", first)
        self.assertEqual(result["plan"]["energy"]["dashes"], len(dashes))
        sync = next(s for s in exported["steps"] if s["action"] == "wait_phase")
        self.assertEqual(set(sync["banner_cycle_s"]), {"banner_dash", "banner_1b"})
        self.assert_export_shape(exported)
        # El camino exportado no toca ningun barrido andando (los dashes son invulnerables).
        rules = vl.Rules()
        hits = pz.banner_walk_hits(room("silenciados_test"), exported, (rules.hitbox_w, rules.hitbox_h),
                                   rules.walk_speed)
        self.assertEqual(hits, [])

    def test_vibracion_test_steps_on_blink_platforms_only_while_on(self):
        """Paso 9: las plataformas que parpadean siguen su metronomo (arranca al entrar en su zona) y el plan
        solo las pisa encendidas; sin avisos."""
        result, exported = checked("vibracion_test")
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        crossing = result["plan"]["banners"][0]
        self.assertEqual(crossing["rhythm"], ["ritmo_v"])
        self.assertTrue(set(crossing["blinks"]) & {"blink_2a_a", "blink_2a_b"})
        self.assertNotIn("start_phase_s", crossing, "el metronomo arranca al entrar: no hay fase libre")
        self.assertFalse(any(s["action"] == "wait_phase" for s in exported["steps"]))
        self.assertEqual(pz.blink_standing_problems(room("vibracion_test"), exported, "ritmo_v"), [])
        self.assert_export_shape(exported)

    def test_alarmas_test_crosses_the_tunnel_with_dashes(self):
        """Paso 9: el tunel de alarmas (compas por la columna mas avanzada), sus campanas y sus banners con
        rhythm entran en el plan; con techo de 2 filas en el 4b y el 4c, el dash; sin avisos."""
        result, exported = checked("alarmas_test")
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        crossing = result["plan"]["banners"][0]
        self.assertEqual(crossing["rhythm"], ["tunel_alarmas"])
        self.assertEqual(set(crossing["banners"]), {"banner_4a", "banner_4c"})
        self.assertEqual(len(crossing["bells"]), 6)
        self.assertGreaterEqual(crossing["dashes"], 1)
        self.assertFalse(any(s["action"] == "wait_phase" for s in exported["steps"]),
                         "el tunel arranca al entrar: no hay fase libre")
        for s in exported["steps"]:
            if s["action"] == "wait_beat":
                self.assertEqual(s["rhythm"], "tunel_alarmas")
                self.assertIn(s["beat"]["stage"], (0, 1, 2))
        self.assertGreaterEqual(result["plan"]["energy"]["used"], 10.0 * crossing["dashes"])
        self.assert_export_shape(exported)

    def test_excepciones_test_reaches_the_message_without_the_dash(self):
        """Paso 9: forbid_abilities ["dash"] del secreto «Excepciones»: su mensaje se alcanza con el Debug y
        sin el dash."""
        result, _ = checked("excepciones_test")
        self.assertTrue(result["ok"], messages(result))
        item = result["memories"][0]
        self.assertEqual(item["forbid_abilities"], ["dash"])
        self.assertFalse(item["reachable_without_debug"])
        self.assertTrue(item["reachable_with_debug"])
        secret = next(i for i in result["secrets"]["items"] if i["id"] == "secreto_excepciones")
        self.assertEqual(secret["forbid_abilities"], ["dash"])
        self.assertTrue(secret["with_debug"])

    def test_ajustes_test_gets_the_dash_from_the_switch(self):
        """Paso 9: el interruptor «No molestar» es una puerta (pulso de espaldas) que da el dash; en la sala no
        hace falta (aviso, como un ability_pickup opcional)."""
        result, _ = checked("ajustes_test")
        self.assertTrue(result["ok"], messages(result))
        gate = next(g for g in result["gates"] if g["kind"] == "dnd")
        self.assertEqual((gate["id"], gate["ability"]), ("dnd_ajustes", "dash"))
        self.assertTrue(any("interruptor No molestar dnd_ajustes no es obligatorio" in w
                            for w in messages(result, "warnings")), messages(result, "warnings"))

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


class DashAndRhythmTest(unittest.TestCase):
    """Paso 9 de docs/propuesta-1-3.md (2026-10-20): dash, banner obligatorio, ritmo, tunel, campanas,
    forbid_abilities e interruptor No molestar; casos negativos sinteticos (tests/support/puzzle_levels.py)."""

    def test_mandatory_banner_with_a_niche_fails(self):
        """Pasillo obligatorio con nichos en el techo: se cruza sin el dash (esperando en un nicho)."""
        result = vl.validate(pz.dash_corridor(niches=[(9, 10), (14, 15)]), check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("banner banner_dash: su pasillo se cruza SIN el dash" in m
                            and "validation.dash_required" in m for m in messages(result)), messages(result))

    def test_mandatory_banner_under_a_three_row_ceiling_fails(self):
        """Con 3 filas libres el banner se salta: el dash no es obligatorio."""
        result = vl.validate(pz.dash_corridor(open_ceiling=True), check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("banner banner_dash: su pasillo se cruza SIN el dash" in m for m in messages(result)),
                        messages(result))

    def test_banner_too_fast_for_the_invulnerability_fails(self):
        """Con una invulnerabilidad de 0,05 s el banner (148 px de solape a 1280 px/s relativos: 0,12 s) no se
        atraviesa: no hay cruce."""
        rules = vl.Rules()
        rules.dash_invulnerable_s = 0.05
        validator = vl.Validator(room("silenciados_test"), rules)
        result = validator.run()
        self.assertFalse(result["ok"])
        self.assertTrue(any("no hay forma de cruzar su tramo sin dano" in m and "banner_dash" in m
                            for m in messages(result)), messages(result))

    def test_dash_without_energy_fails(self):
        result = vl.validate(pz.dash_corridor(start_energy=0, charger=False), check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any(m.startswith("sin energia en el paso") and "dash" in m and "quedan 0 y hacen falta 10" in m
                            for m in messages(result)), messages(result))

    def test_dash_with_low_energy_detours_to_the_charger(self):
        export = []
        result = vl.validate(pz.dash_corridor(start_energy=5), check_schema=False, export=export)
        self.assertTrue(result["ok"], messages(result))
        steps = export[0]["steps"]
        charge = next(i for i, s in enumerate(steps) if s["action"] == "charge")
        first_dash = next(i for i, s in enumerate(steps) if s["action"] == "dash")
        self.assertLess(charge, first_dash, "carga antes del primer dash")

    def test_dash_cooldown_between_two_dashes(self):
        """Dos dashes seguidos: entre el final de uno y el principio del siguiente pasa el enfriamiento."""
        result, exported = checked("alarmas_test")
        cool = vl.Rules().dash_cooldown_s
        walk = vl.Rules().walk_speed

        def start(s):
            return s["t"] + abs(s["takeoff_x_px"] - s["from"]["feet_px"][0]) / walk + 0.06 + s.get("dash_after_s", 0.0)

        dashes = [s for s in exported["steps"] if s["action"] == "dash"]
        self.assertGreaterEqual(len(dashes), 2)
        for a, b in zip(dashes, dashes[1:]):
            self.assertGreaterEqual(start(b) - (start(a) + a["dash_s"]), cool - 0.02, (a, b))

    def test_blink_pit_needs_the_rhythm(self):
        """Pozo sin fondo que solo se cruza por las plataformas que parpadean: encendidas el 60 % con medio
        ciclo de desfase se cruza al compas; con el 20 % y 0,6 de desfase nunca hay donde caer."""
        export = []
        result = vl.validate(pz.blink_pit(), export=export)
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(pz.blink_standing_problems(pz.blink_pit(), export[0], "ritmo_v"), [])
        result = vl.validate(pz.blink_pit(on_fraction=0.2, offsets=(0.0, 0.6)), check_schema=False)
        self.assertFalse(result["ok"])
        self.assertTrue(any("blink_2a_a, blink_2a_b: no hay forma de cruzar su tramo sin dano" in m
                            for m in messages(result)), messages(result))

    def test_tunnel_without_dash_fails(self):
        """El 4c (techo de 2 filas, banner a 640 px/s en un compas de 1,4 s) no se cruza sin el dash."""
        level = room("alarmas_test")
        level["abilities_available"]["dash"] = False
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("no hay forma de cruzar su tramo sin dano" in m and "banner_4c" in m
                            for m in messages(result)), messages(result))

    def test_bells_are_dodged(self):
        """El plan nunca esta en la columna de una campana mientras suena (salvo en el dash): comprobacion con
        las muestras del propio plan y el reloj del tunel."""
        result, exported = checked("alarmas_test")
        level = room("alarmas_test")
        rules = vl.Rules()
        validator = vl.Validator(level, rules)
        validator.export_requested = True
        validator.run()
        planner = validator.planner
        hz = planner.hazards()
        bells_only = dict(hz, timed=hz["bells"], blinks=[])
        zs = {zid: planner.zone_init(planner.m.zones[zid]) for zid in planner.m.zones}
        planner.timeline(planner.steps)
        hits = []
        for s in planner.steps:
            smp = planner.samples(s)
            d = planner.duration(s)
            inv = planner.invulnerable_range(s)
            for k, (x, f, _) in enumerate(smp):
                for zid in zs:
                    zs[zid] = planner.zone_step(planner.m.zones[zid], zs[zid], x, f, d / len(smp))
                if planner.sample_unsafe(x, f, inv[0] <= k < inv[1], 0.0, zs, bells_only):
                    hits.append((s["action"], round(x)))
        self.assertEqual(hits, [])

    def test_zone_clock_tempo_steps_and_tunnel_stages(self):
        """Reloj de los metronomos como RhythmZone / AlarmTunnel: tempo_steps_s cada cycles_per_step ciclos con
        bucle; el tunel por la columna mas avanzada (no retrocede); antes de entrar, quieto."""
        validator = vl.Validator(room("vibracion_test"), vl.Rules())
        planner = __import__("level_plan").Planner(validator)
        z = validator.model.zones["ritmo_v"]
        st = planner.zone_init(z)
        self.assertEqual(planner.zone_step(z, st, 64.0 * 2, 640.0, 1.0), st, "fuera de la zona no arranca")
        inside = (64.0 * 10, 640.0)
        cycles = []
        for _ in range(int(32.0 / 0.05)):
            st = planner.zone_step(z, st, inside[0], inside[1], 0.05)
            cycles.append(planner.zone_cycle(z, st))
        self.assertEqual(cycles[0], 3.2)
        self.assertIn(2.6, cycles)
        self.assertIn(2.0, cycles)
        self.assertEqual(cycles[-1], 3.2, "vuelve al lento tras 4 x (3,2 + 2,6 + 2,0) = 31,2 s")
        validator = vl.Validator(room("alarmas_test"), vl.Rules())
        planner = __import__("level_plan").Planner(validator)
        z = validator.model.zones["tunel_alarmas"]
        st = planner.zone_init(z)
        st = planner.zone_step(z, st, 64.0 * 25 + 32, 704.0, 0.1)
        self.assertEqual(planner.zone_cycle(z, st), 1.4)
        st = planner.zone_step(z, st, 64.0 * 7 + 32, 704.0, 0.1)
        self.assertEqual(planner.zone_cycle(z, st), 1.4, "volver atras no lo hace mas lento")

    def test_forbidden_dash_hides_a_secret_behind_a_pit(self):
        """Secreto tras la pared con glitch y un pozo de 4 tiles: con el dash (salto y dash aereo, tras apagar
        el Debug) se alcanza; con forbid_abilities ["dash"], no."""
        result = vl.validate(pz.secret_behind_pit(forbid=False))
        self.assertTrue(result["ok"], messages(result))
        result = vl.validate(pz.secret_behind_pit(forbid=True))
        self.assertFalse(result["ok"])
        self.assertTrue(any("el mensaje msg_1_3 (mensaje_1_3) no se alcanza ni con el Debug" in m
                            for m in messages(result)), messages(result))

    def test_dnd_switch_gives_the_dash(self):
        """Pozo de 4 tiles que solo se cruza con el dash: el camino pulsa antes el interruptor No molestar (de
        espaldas); sin el interruptor no hay camino."""
        export = []
        result = vl.validate(pz.dnd_gap(), export=export)
        self.assertTrue(result["ok"], messages(result))
        steps = export[0]["steps"]
        switch = next(i for i, s in enumerate(steps) if s.get("target", {}).get("type") == "dnd_switch")
        self.assertTrue(steps[switch]["face_back"])
        self.assertEqual(steps[switch]["target"]["ability"], "dash")
        dash = next(i for i, s in enumerate(steps) if s["action"] == "dash")
        self.assertLess(switch, dash)
        result = vl.validate(pz.dnd_gap(switch=False))
        self.assertFalse(result["ok"])
        self.assertTrue(any("no hay camino de P a G" in m for m in messages(result)), messages(result))

    def test_dnd_switch_is_mandatory_through_dash_required(self):
        """Paso 10 (2026-10-20): sin el dash, el pasillo de un banner de validation.dash_required es un peligro
        del grafo (como una Burbuja sin aturdir; el plan demuestra ademas que no se cruza ni andando ni
        corriendo): el camino pasa por el interruptor No molestar, que es obligatorio, y no hay aviso. Sin
        dash_required, el pasillo se cruza en el grafo y sale el aviso de siempre."""
        result = vl.validate(pz.dash_corridor(switch=True))
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["warnings"], [])
        level = pz.dash_corridor(switch=True)
        level["validation"].pop("dash_required")
        result = vl.validate(level)
        self.assertTrue(any("interruptor No molestar dnd_prueba no es obligatorio" in w["message"]
                            for w in result["warnings"]), result["warnings"])

    def test_dash_required_banner_must_exist(self):
        level = room("silenciados_test")
        level["validation"]["dash_required"] = ["banner_x"]
        result = vl.validate(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("validation.dash_required: el banner 'banner_x' no existe" in m
                            for m in messages(result)), messages(result))


class HazardMarginTest(unittest.TestCase):
    """Bot del 1-3 (2026-10-20, docs/propuesta-1-3.md §7, paso 11): la busqueda por tiempo simula los saltos
    con el arco real del juego (bajo un techo bajo aterriza antes que el conservador) y, con
    validation.hazard_margin_s, exige holgura de tiempo frente a banners, campanas y ritmo y espera solo
    fuera de sus franjas."""

    def test_real_arc_lands_earlier_under_a_low_ceiling(self):
        """Pasillo de 4 filas (256 px) de silenciados_test, salto andando: el arco real (unos 184 px) choca
        con el techo y aterriza en unos 0,65 s (Isak real medido: 38 cuadros); el conservador (176,6 px) roza
        el techo en la cumbre y aterriza ~0,07 s mas tarde. Sin techo, el real sube lo de real_jump_height."""
        rules = vl.Rules()
        model = vl.LevelModel(room("silenciados_test"), rules)
        w = model.world(frozenset())
        x, feet = 24.5 * 64, 11 * 64
        cons, real = {}, {}
        to_c, _ = w.simulate(x, feet, -rules.jump_v0, rules.walk_speed, x + 1e6, head_lag=True, info=cons)
        to_r, _ = w.simulate(x, feet, -rules.jump_v0_game, rules.walk_speed, x + 1e6, info=real, game=True)
        self.assertEqual((to_c[1], to_r[1]), (10, 10))
        self.assertTrue(real["head_hit"])
        self.assertAlmostEqual(real["time"], 38 / 60.0, delta=2 / 60.0)
        self.assertGreater(cons["time"] - real["time"], 0.05)
        top = {"want_traj": True}
        x_open = 36.5 * 64
        w.simulate(x_open, feet, -rules.jump_v0_game, 0.0, x_open, info=top, game=True)
        rise = feet - min(y for _, y in top["traj"])
        self.assertAlmostEqual(rise, rules.real_jump_height, delta=1.0)

    def test_margin_needs_slack_in_the_crossing(self):
        """silenciados_test valida con 0,1 s de holgura; con 0,3 s no hay cruce sin dano."""
        ok = room("silenciados_test")
        ok["validation"]["hazard_margin_s"] = 0.1
        self.assertTrue(vl.validate(ok)["ok"])
        tight = room("silenciados_test")
        tight["validation"]["hazard_margin_s"] = 0.3
        result = vl.validate(tight)
        self.assertFalse(result["ok"])
        self.assertTrue(any("no hay forma de cruzar su tramo sin dano" in m for m in messages(result)), messages(result))

    def test_waits_with_margin_stay_out_of_the_bands(self):
        """alarmas_test: sin holgura espera al compas dentro de franjas del tunel; con 0,1 s, solo fuera de toda
        franja de banner y onda (si el bot llega tarde, espera otro ciclo sin que le den)."""
        def waits(margin):
            level = room("alarmas_test")
            if margin:
                level.setdefault("validation", {})["hazard_margin_s"] = margin
            validator = vl.Validator(level, vl.Rules())
            result = validator.run()
            self.assertTrue(result["ok"], messages(result))
            planner = validator.planner
            hz = planner.hazards()
            nodes = [tuple(s["at"]) for s in planner.steps if s["action"] in ("wait", "wait_beat", "hop")
                     and s.get("timed") == "hazard"]
            return [n for n in nodes if planner.exposed_ids(*planner.feet(n), {"timed": hz["timed"], "blinks": []})]
        self.assertTrue(waits(0.0), "Sin holgura hay esperas dentro de alguna franja")
        self.assertEqual(waits(0.1), [])

    def test_schema_range(self):
        level = room("silenciados_test")
        level["validation"]["hazard_margin_s"] = 0.8
        result = vl.validate(level)
        self.assertTrue(any("validation.hazard_margin_s debe ser un numero entre 0 y 0.5" in m
                            for m in messages(result)), messages(result))


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



class DebugDrainScaleTest(unittest.TestCase):
    """debug_drain_scale del nivel (2026-10-21, paso 4 de docs/propuesta-jefe-alerta-mayor.md §6): el plan
    gasta el Debug por ese factor (arena del jefe: 0,5) y sin el campo no cambia nada."""

    def test_half_scale_halves_the_debug_energy(self):
        level = pz.hidden_gap(chip=True)
        base = vl.validate(copy.deepcopy(level))
        self.assertTrue(base["ok"], messages(base))
        self.assertNotIn("debug_drain_per_s", base["plan"]["energy"])
        level["debug_drain_scale"] = 0.5
        half = vl.validate(level)
        self.assertTrue(half["ok"], messages(half))
        seg_base = base["plan"]["debug"]["segments"][0]
        seg_half = half["plan"]["debug"]["segments"][0]
        self.assertEqual(seg_half["active_s"], seg_base["active_s"], "el mismo tiempo con el Debug")
        self.assertAlmostEqual(seg_half["energy"], seg_base["energy"] / 2.0, places=1)
        self.assertAlmostEqual(half["plan"]["energy"]["used"], base["plan"]["energy"]["used"] / 2.0, places=1)
        self.assertEqual(half["plan"]["energy"]["debug_drain_per_s"], 10.0)
        self.assertIn("    gasto del Debug en este nivel: 10.0/s (debug_drain_scale)", vl.format_plan(half["plan"]))
        self.assertFalse(any("gasto del Debug en este nivel" in line for line in vl.format_plan(base["plan"])))

    def test_schema_accepts_0_to_1(self):
        import validate_level_schema as vls
        level = room("boss_test")
        for value in (0, 0.5, 1):
            level["debug_drain_scale"] = value
            self.assertEqual(vls.validate_level(level), [], value)
        for value in (1.5, -0.1, "0.5", True):
            level["debug_drain_scale"] = value
            self.assertTrue(any("debug_drain_scale" in e for e in vls.validate_level(level)), value)

    def test_existing_levels_do_not_use_it(self):
        for name in ("1-1", "1-2", "1-3"):
            with open(os.path.join(ROOT, "data", "levels", "%s.json" % name), encoding="utf-8") as handle:
                self.assertNotIn("debug_drain_scale", json.load(handle), name)
            with open(os.path.join(ROOT, "scenes", "levels", "%s.tscn" % name), encoding="utf-8") as handle:
                self.assertNotIn("debug_drain_scale", handle.read(), name)

    def test_boss_test_room_uses_a_quarter(self):
        # La marca (2026-10-21, docs/propuesta-jefe-alerta-mayor.md §2.4.7): la sala del saco gasta como la arena.
        with open(os.path.join(ROOT, "data", "levels", "boss_test.json"), encoding="utf-8") as handle:
            self.assertEqual(json.load(handle)["debug_drain_scale"], 0.25)
        with open(os.path.join(ROOT, "scenes", "levels", "boss_test.tscn"), encoding="utf-8") as handle:
            self.assertIn("debug_drain_scale = 0.25", handle.read())


if __name__ == "__main__":
    unittest.main()
