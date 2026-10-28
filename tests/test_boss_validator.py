#!/usr/bin/env python3
"""Arena del jefe del Mundo 1 y validador de arenas (paso 5 de docs/propuesta-jefe-alerta-mayor.md §6,
2026-10-21; tools/validate_boss.py, al que delega tools/validate_level.py con kind "boss").

La arena data/levels/1-boss.json pasa (esquema y validador) y los margenes de energia de la pelea torpe son
los de §2.4.7: Caché 55 / 60 / 67,5 (margen >= 25 en todas las fases), Kernel >= 20 y Raíz exactamente 20 en
la fase 3 con 3 lanzamientos por ronda (decision del usuario del 2026-10-21; con 4, 10). Casos negativos
sinteticos: cargador a mas de 4 tiles, pico > maximo - 20, dos carriles barridos a la vez, aviso fuera de
6-12 cuadros, dos campanas a la vez, nucleo fuera de alcance, ventana corta y modelo incoherente; y el
esquema de las arenas (sin G, jefe obligatorio, active_in_phase solo en arenas).
"""

import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_boss as vb  # noqa: E402
import validate_level as vl  # noqa: E402
import validate_level_schema as vls  # noqa: E402

LEVEL = os.path.join(ROOT, "data", "levels", "1-boss.json")
BOSS = os.path.join(ROOT, "data", "bosses", "alert_major.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


class ArenaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.level = load(LEVEL)
        cls.boss = load(BOSS)
        cls.result = vb.validate_arena(cls.level)

    def run_arena(self, level=None, boss=None):
        return vb.validate_arena(level or self.level, boss=boss or self.boss)

    def messages(self, result):
        return [e["message"] for e in result["errors"]]

    def energy(self, result, lap, scenario="base"):
        return result["boss"]["energy"][str(lap)][scenario]

    # --- La arena real ---

    def test_schema_and_validator_pass(self):
        self.assertEqual(vls.validate_level(self.level, ROOT), [])
        self.assertTrue(self.result["ok"], self.messages(self.result))
        via_level = vl.validate(self.level)
        self.assertTrue(via_level["ok"])
        self.assertIn("boss", via_level, "validate_level delega en validate_boss")
        self.assertIn("arena de jefe", vl.format_text("1-boss", via_level))

    def test_cli_passes_and_access_cap_is_handled_per_lap(self):
        for extra in ([], ["--access-cap"], ["--upgrades", "pulso:5,laser:5,debug:5,sync:5,energia:5"]):
            proc = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_level.py")] + extra + [LEVEL],
                                  cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_lanes_and_chargers(self):
        rep = self.result["boss"]
        self.assertLessEqual(rep["sweep_busy_s"], rep["sweep_interval_s"])
        self.assertLessEqual(rep["burst_busy_s"], rep["burst_every_s"])
        self.assertLessEqual(rep["charger_worst_tiles"], 4)
        self.assertLessEqual(rep["charger_second_worst_tiles"], 7)

    def test_windows_cover_every_spot(self):
        spots = {(w["phase"], w["spot"]) for w in self.result["boss"]["windows"]}
        for expected in [(1, "floor_center"), (2, "platform_left"), (2, "platform_right"),
                         (2, "platform_left (escudo)"), (3, "platform_left"), (3, "floor_center"),
                         (3, "platform_right"), (3, "platform_center")]:
            self.assertIn(expected, spots)
        for w in self.result["boss"]["windows"]:
            self.assertGreaterEqual(w["window_s"], w["need_s"], w)
            self.assertGreater(w["pulse_cells"], 0, w)

    def test_energy_margins_as_in_the_proposal(self):
        cache = self.energy(self.result, 1)
        self.assertEqual([p["peak"] for p in cache["phases"]], [55.0, 60.0, 67.5], "§2.4.7: 55 / 60 / 68")
        self.assertGreaterEqual(cache["min_margin"], 25.0)
        self.assertAlmostEqual(cache["debug_drain_per_s"], 5.0, "Debug a un cuarto: 5/s")
        kernel = self.energy(self.result, 2)
        self.assertGreaterEqual(kernel["min_margin"], 20.0)
        self.assertEqual(kernel["phases"][2]["peak"], 77.5, "Kernel: 78 (22)")
        raiz = self.energy(self.result, 3)
        self.assertEqual(raiz["phases"][2]["peak"], 80.0, "Raíz fase 3 con 3 lanzamientos: 80 (20)")
        self.assertEqual(raiz["min_margin"], 20.0)
        for lap in ("1", "2", "3"):
            for scenario in ("tope del acceso", "todo al maximo"):
                self.assertGreaterEqual(self.energy(self.result, lap, scenario)["min_margin"], 20.0)

    def test_raiz_with_four_launches_does_not_fit(self):
        boss = copy.deepcopy(self.boss)
        boss["laps"]["3"]["phase3"]["launches_per_round"] = 4
        result = self.run_arena(boss=boss)
        self.assertFalse(result["ok"])
        self.assertTrue(any("vuelta 3, fase 3" in m for m in self.messages(result)), self.messages(result))
        self.assertEqual(self.energy(result, 3)["phases"][2]["peak"], 90.0)

    # --- Negativos ---

    def test_charger_too_far(self):
        level = copy.deepcopy(self.level)
        level["objects"] = [o for o in level["objects"]
                            if not (o["type"] == "charger" and o["params"]["id"] in ("cargador_2", "cargador_3"))]
        msgs = self.messages(self.run_arena(level=level))
        self.assertTrue(any("sin cargador a 4 tiles" in m for m in msgs), msgs)

    def test_peak_over_max_minus_margin(self):
        level = copy.deepcopy(self.level)
        level["debug_drain_scale"] = 1.0
        msgs = self.messages(self.run_arena(level=level))
        self.assertTrue(any("pico de la pelea torpe" in m for m in msgs), msgs)

    def test_two_lanes_swept_at_once(self):
        boss = copy.deepcopy(self.boss)
        boss["phase1"]["sweep_interval_s"] = 2.0
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("barrerian los dos carriles a la vez" in m for m in msgs), msgs)
        boss = copy.deepcopy(self.boss)
        boss["phase2"]["burst_every_s"] = 2.5
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("dos rafagas" in m for m in msgs), msgs)

    def test_lane_without_refuge(self):
        boss = copy.deepcopy(self.boss)
        boss["arena"]["lanes"]["high"]["surface_row"] = 9
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("no hay refugio" in m for m in msgs), msgs)

    def test_telegraph_out_of_range(self):
        boss = copy.deepcopy(self.boss)
        boss["phase1"]["spit_warn_frames"] = 4
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("escupir Burbujas" in m and "de 6 a 12" in m for m in msgs), msgs)

    def test_art_inflate_never_outlasts_its_warning(self):
        # Arte final (paso 16, 2026-10-22): la animacion de inflarse no puede durar mas que el aviso.
        self.assertIn("art_inflate_s", self.result["boss"])
        self.assertLessEqual(self.result["boss"]["art_inflate_s"], 7 / 12.0 + 1e-6)
        boss = copy.deepcopy(self.boss)
        boss["art"]["anims"]["inflate"]["frames"] = 12
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("inflate dura" in m and "escupir" in m for m in msgs), msgs)
        boss = copy.deepcopy(self.boss)
        del boss["art"]["anims"]["window"]
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("falta la animacion 'window'" in m for m in msgs), msgs)

    def test_two_bells_at_once(self):
        level = copy.deepcopy(self.level)
        for e in level["enemies"]:
            if e["id"] == "campana_2":
                e["params"]["offset"] = 0.1
        msgs = self.messages(self.run_arena(level=level))
        self.assertTrue(any("suenan a la vez" in m for m in msgs), msgs)

    def test_core_out_of_reach_and_short_window(self):
        boss = copy.deepcopy(self.boss)
        boss["arena"]["spots"]["floor_center"] = [12.0, 2]
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("no se alcanza con el pulso" in m for m in msgs), msgs)
        boss = copy.deepcopy(self.boss)
        boss["phase1"]["window_s"] = 2.0
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("fase 1: la ventana" in m for m in msgs), msgs)

    def test_blink_too_short_for_the_fastest_beat(self):
        boss = copy.deepcopy(self.boss)
        boss["laps"]["3"]["phase3"]["blink_on_fraction"] = 0.55
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("vuelta 3: plataformas que parpadean" in m for m in msgs), msgs)

    def test_model_must_match_the_hits(self):
        boss = copy.deepcopy(self.boss)
        boss["validation_model"]["laps"]["1"]["windows"][0] = [0, 1, 1]
        msgs = self.messages(self.run_arena(boss=boss))
        self.assertTrue(any("suman 2 golpes y la fase tiene 3" in m for m in msgs), msgs)


class ArenaSchemaTest(unittest.TestCase):
    def setUp(self):
        self.level = load(LEVEL)

    def errors(self, level):
        return vls.validate_level(level, ROOT)

    def test_no_goal_in_an_arena(self):
        level = copy.deepcopy(self.level)
        level["grid"][9] = level["grid"][9][:21] + "G" + level["grid"][9][22:]
        self.assertTrue(any("no tiene meta G" in e for e in self.errors(level)))

    def test_needs_its_boss(self):
        level = copy.deepcopy(self.level)
        level["objects"] = [o for o in level["objects"] if o["type"] != "alert_major"]
        self.assertTrue(any("exactamente un objeto 'alert_major'" in e for e in self.errors(level)))
        level = copy.deepcopy(self.level)
        level["boss"] = "no_existe"
        self.assertTrue(any("sin data/bosses/no_existe.json" in e for e in self.errors(level)))

    def test_active_in_phase_only_in_arenas(self):
        level = copy.deepcopy(self.level)
        level["enemies"][0]["active_in_phase"] = [4]
        self.assertTrue(any("active_in_phase debe ser" in e for e in self.errors(level)))
        other = load(os.path.join(ROOT, "data", "levels", "1-3.json"))
        other["objects"][0]["active_in_phase"] = [1]
        self.assertTrue(any("solo vale en una arena" in e for e in self.errors(other)))

    def test_id_and_kind(self):
        level = copy.deepcopy(self.level)
        del level["kind"]
        errs = self.errors(level)
        self.assertTrue(errs)
        level = copy.deepcopy(self.level)
        level["kind"] = "jefe"
        self.assertTrue(any("'kind' debe ser" in e for e in self.errors(level)))

    def test_blink_replaces_one_way_only_with_active_in_phase(self):
        level = copy.deepcopy(self.level)
        for o in level["objects"]:
            if o["type"] == "blink_platform":
                del o["active_in_phase"]
        self.assertTrue(any("debe dejar vacia" in e for e in self.errors(level)))

    def test_climbs_fixture_up_to_date(self):
        proc = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "level_climbs.py"), "--check", LEVEL],
                              cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)



class AutoplayArenaTest(unittest.TestCase):
    """Arena 2-boss de Autoplay (pasos 15-17 de docs/propuesta-mundo-2.md, 2026-10-23): esquema, comprobaciones
    basicas y validador completo (§7.2: cinta, cabezal, laser a la pantalla, ventanas, avisos a x2, pausa y
    energia torpe por acceso), con casos negativos sinteticos."""

    @classmethod
    def setUpClass(cls):
        cls.boss = load(os.path.join(ROOT, "data", "bosses", "autoplay.json"))

    def setUp(self):
        self.level = load(os.path.join(ROOT, "data", "levels", "2-boss.json"))

    def run_arena(self, boss=None, level=None):
        return vb.validate_arena(level or self.level, ROOT, boss=boss or self.boss)

    def messages(self, result):
        return " | ".join(e["message"] for e in result["errors"])

    def test_schema_ok_and_fits_on_screen(self):
        self.assertEqual(vls.validate_level(self.level, ROOT), [])
        self.assertEqual((len(self.level["grid"][0]) * 64, len(self.level["grid"]) * 64), (1280, 704))
        result = vl.validate(self.level, ROOT)
        self.assertTrue(result["ok"], result["errors"])
        self.assertEqual(result["warnings"], [], "validador completo: sin el aviso de los pasos 15-16")
        self.assertLessEqual(result["boss"]["charger_worst_tiles"], 3.5)

    def test_energy_margins_of_the_clumsy_fight_in_every_access(self):
        result = self.run_arena()
        energy = result["boss"]["energy"]
        self.assertEqual(sorted(energy), ["1", "2", "3"])
        for lap, scenarios in energy.items():
            self.assertEqual(sorted(scenarios), ["base", "todo al maximo", "tope del acceso"])
            for name, e in scenarios.items():
                self.assertGreaterEqual(e["min_margin"], 20.0, (lap, name))
        # Un golpe por pausa (pause_hits, 2026-10-23): un laser acertado y uno fallado por ventana.
        self.assertEqual([ph["peak"] for ph in energy["1"]["base"]["phases"]], [50.0, 50.0, 60.0])

    def test_conveyor_reaches_the_bar_and_every_slot_is_hit(self):
        rep = self.run_arena()["boss"]
        self.assertEqual(rep["bar_cells"], [10, 10])
        conv = rep["conveyor"]
        self.assertLess(conv["lo_px"], conv["hi_px"])
        self.assertLessEqual(conv["worst_wait_s"], 1.7)
        self.assertEqual(rep["laser"]["slots"], {"left": True, "center": True, "right": True})
        self.assertGreater(rep["laser"]["floor_cells"], 0)

    def test_windows_from_the_bar_with_k_2_and_from_the_floor_in_cache(self):
        rep = self.run_arena()["boss"]
        self.assertEqual(len(rep["aw_windows"]), 9)
        for w in rep["aw_windows"]:
            self.assertLessEqual(w["need_bar_s"], w["window_s"] + 1e-6, w)
            if w["lap"] == "1":
                self.assertTrue(w["floor_required"])
                self.assertLessEqual(w["need_floor_s"], w["window_s"] + 1e-6, w)
        third = [w for w in rep["aw_windows"] if w["phase"] == 3]
        self.assertTrue(all(abs(w["card_wait_s"] * 2 - rep["conveyor"]["worst_wait_s"]) < 0.01 for w in third),
                        "la cinta va a x2 en la fase 3")

    def test_telegraphs_also_at_x2(self):
        rep = self.run_arena()["boss"]
        third = [row for row in rep["clips"] if row["phase"] == 3][0]
        self.assertEqual(third["speed_scale"], 2.0)
        self.assertTrue(all(frames >= 6 for _, frames, _ in third["clips"]))
        boss = copy.deepcopy(self.boss)
        boss["clips"]["rays"]["anticipation_frames"] = 5
        self.assertIn("fase 3 (x2): aviso de 'rays' de 5", self.messages(self.run_arena(boss)))

    def test_fewer_cards_do_not_fit_the_window_from_the_floor(self):
        boss = copy.deepcopy(self.boss)
        boss["arena"]["conveyor"]["cards"] = 2
        msg = self.messages(self.run_arena(boss))
        self.assertIn("vuelta 1, fase 1: desde el suelo", msg)
        self.assertNotIn("vuelta 2, fase 1: desde el suelo", msg, "Kernel solo informa")

    def test_bar_out_of_reach_of_the_cards(self):
        boss = copy.deepcopy(self.boss)
        boss["arena"]["bar"]["surface_row"] = 4
        self.assertIn("cinta: no hay altura de tarjeta", self.messages(self.run_arena(boss)))

    def test_fast_playhead_and_short_window(self):
        boss = copy.deepcopy(self.boss)
        boss["laps"]["2"]["playhead_window_speed_tiles_s"] = 3.0
        boss["phase3"]["window_s"] = 2.5
        msg = self.messages(self.run_arena(boss))
        self.assertIn("vuelta 2: el cabezal en marcha avanza", msg)
        self.assertIn("vuelta 1, fase 3: la ventana dura 2.50", msg)

    def test_laser_rects_out_of_reach(self):
        boss = copy.deepcopy(self.boss)
        boss["arena"]["damage_rects"] = [[6, 1, 8, 1]]
        self.assertIn("laser: desde el slot", self.messages(self.run_arena(boss)))

    def test_slow_ray_dodge_and_sweep_too_slow_for_the_dash(self):
        boss = copy.deepcopy(self.boss)
        boss["clips"]["wave"]["speed_px_s"] = 300.0
        msg = self.messages(self.run_arena(boss))
        self.assertIn("fase 1: 'wave' a 300 px/s tarda", msg)

    def test_short_pause_and_energy_peak(self):
        boss = copy.deepcopy(self.boss)
        boss["laps"]["3"]["mark_duration_s"] = 0.9
        boss["validation_model"]["laps"]["1"]["debug_s"] = [12.0, 4.0, 4.0]
        msg = self.messages(self.run_arena(boss))
        self.assertIn("vuelta 3: en la marca de 0.90 s caben", msg)
        self.assertIn("base, vuelta 1, fase 1: pico de la pelea torpe", msg)

    def test_model_must_add_the_heals_of_phase_2(self):
        boss = copy.deepcopy(self.boss)
        boss["validation_model"]["heals"] = [0, 0, 0]
        self.assertIn("las ventanas suman 5 golpes y la fase tiene 4", self.messages(self.run_arena(boss)))

    def test_model_cannot_ask_more_hits_per_window_than_the_pause_gives(self):
        boss = copy.deepcopy(self.boss)
        boss["validation_model"]["laps"]["1"]["windows"] = [[0, 2, 1, 1], [0, 1, 1, 1, 1, 1], [0, 1, 1, 1, 1]]
        msg = self.messages(self.run_arena(boss))
        self.assertIn("vuelta 1: la pelea torpe pide 2 golpe(s) en una ventana y cada pausa da 1 (pause_hits)", msg)

    def test_pause_hits_and_ray_volleys_are_reported(self):
        rep = self.run_arena()["boss"]
        self.assertEqual({lap: m.get("pause_hits") for lap, m in rep["mark"].items()}, {"1": 1, "2": 1, "3": 1})
        self.assertEqual(rep["ray_volleys"]["laps"], {"3": [1, 1, 2]})
        boss = copy.deepcopy(self.boss)
        boss["laps"]["3"]["ray_volleys"] = [1, 1, 0]
        self.assertIn("rayos: ray_volleys >= 1", self.messages(self.run_arena(boss)))

    def test_one_boss_output_does_not_use_the_autoplay_model(self):
        result = vb.validate_arena(load(LEVEL), ROOT)
        self.assertNotIn("aw_windows", result["boss"])
        self.assertIn("windows", result["boss"])

    def test_taller_arena_does_not_fit(self):
        level = copy.deepcopy(self.level)
        level["grid"] = level["grid"][:-1] + [level["grid"][-2], level["grid"][-1]]
        result = vb.validate_basic_arena(level, load(os.path.join(ROOT, "data", "bosses", "autoplay.json")), ROOT)
        self.assertTrue(any("no cabe entera" in e["message"] for e in result["errors"]))

    def test_charger_far_from_the_floor_fails(self):
        level = copy.deepcopy(self.level)
        level["objects"] = [o for o in level["objects"] if o.get("params", {}).get("id") != "cargador_2"]
        result = vb.validate_basic_arena(level, load(os.path.join(ROOT, "data", "bosses", "autoplay.json")), ROOT)
        self.assertTrue(any("sin cargador" in e["message"] for e in result["errors"]))


class CuratorArenaTest(unittest.TestCase):
    """Arena 3-boss de La Curadora (paso 16 de docs/propuesta-mundo-3.md, §7.2, 2026-10-27): validador completo
    (avisos, refugios, ventanas por fase y acceso, cazador de la fase 2, marcos pequenos de la fase 3, marca, energia
    torpe y cargadores), con casos negativos sinteticos."""

    @classmethod
    def setUpClass(cls):
        cls.boss = load(os.path.join(ROOT, "data", "bosses", "curator.json"))
        cls.result = vb.validate_arena(load(os.path.join(ROOT, "data", "levels", "3-boss.json")), ROOT)

    def setUp(self):
        self.level = load(os.path.join(ROOT, "data", "levels", "3-boss.json"))

    def run_arena(self, boss=None, level=None):
        return vb.validate_arena(level or self.level, ROOT, boss=boss or self.boss)

    def messages(self, result):
        return " | ".join(e["message"] for e in result["errors"])

    def test_full_validator_passes_without_the_pending_warning(self):
        self.assertEqual(vls.validate_level(self.level, ROOT), [])
        result = vl.validate(self.level, ROOT)
        self.assertTrue(result["ok"], result["errors"])
        self.assertEqual(result["warnings"], [], "validador completo: sin el aviso del paso 15")
        self.assertIn("cur_windows", result["boss"])

    def test_energy_margins_of_the_clumsy_fight_in_every_access(self):
        energy = self.result["boss"]["energy"]
        self.assertEqual(sorted(energy), ["1", "2", "3"])
        for lap, scenarios in energy.items():
            self.assertEqual(sorted(scenarios), ["base", "todo al maximo", "tope del acceso"])
            for name, e in scenarios.items():
                self.assertGreaterEqual(e["min_margin"], 20.0, (lap, name))
        self.assertEqual([ph["peak"] for ph in energy["1"]["base"]["phases"]], [45.0, 55.0, 50.0])

    def test_windows_fit_by_phase_and_access(self):
        windows = self.result["boss"]["cur_windows"]
        self.assertEqual(len(windows), 13)
        for w in windows:
            self.assertLessEqual(w["need_s"], w["window_s"] + 1e-6, w)
        froms = {(w["lap"], w["phase"], w["from"]): w["k"] for w in windows}
        self.assertEqual(froms[("1", 1, "platform")], 2.0)
        self.assertEqual(froms[("2", 1, "platforms")], 1.0, "Kernel: la lente puede bajar al otro lado")
        self.assertEqual(froms[("3", 3, "after_close")], 1.0)

    def test_hunter_route_through_the_corner_mirrors(self):
        hunter = self.result["boss"]["cur_hunter"]
        self.assertEqual(hunter["corners"], {"left": "nw", "right": "ne"})
        self.assertEqual(sorted({tuple(c[0]) for c in hunter["cells"]}), [(7, 9), (8, 9), (10, 9), (11, 9)])
        level = copy.deepcopy(self.level)
        row = list(level["grid"][3])
        row[3] = "#"
        level["grid"][3] = "".join(row)
        self.assertIn("el camino cazador -> espejo left -> espalda cruza terreno",
                      self.messages(self.run_arena(level=level)))

    def test_small_frame_free_on_every_close(self):
        frames = self.result["boss"]["cur_frames"]
        for side, f in frames["sides"].items():
            self.assertLessEqual(f["worst_s"], frames["close_s"], side)
        level = copy.deepcopy(self.level)
        level["objects"].append({"type": "charger", "x": 1, "y": 9,
                                 "params": {"id": "cargador_x", "amount": 50.0, "reusable": True, "cooldown_s": 4.0}})
        row = list(level["grid"][9])
        row[18] = "#"
        level["grid"][9] = "".join(row)
        msg = self.messages(self.run_arena(level=level))
        self.assertIn("marco pequeno left ocupado en la fase 3: charger 'cargador_x'", msg)
        self.assertIn("marco pequeno right ocupado: hay terreno", msg)

    def test_frame_closing_too_fast_to_escape(self):
        boss = copy.deepcopy(self.boss)
        boss["phase3"]["frame_warn_frames"] = 6
        boss["phase3"]["frame_close_s"] = 0.0
        self.assertIn("marco que se cierra (left): desde", self.messages(self.run_arena(boss)))

    def test_short_telegraphs(self):
        boss = copy.deepcopy(self.boss)
        boss["flash"]["warn_frames"] = 5
        boss["phase3"]["frame_warn_frames"] = 13
        msg = self.messages(self.run_arena(boss))
        self.assertIn("aviso de 'flash': 5 cuadros", msg)
        self.assertIn("aviso de 'marco que se cierra': 13 cuadros", msg)

    def test_energy_margin_too_small(self):
        boss = copy.deepcopy(self.boss)
        boss["validation_model"]["laps"]["3"]["debug_s"] = [3.5, 12.0, 5.0]
        self.assertIn("base, vuelta 3, fase 2: pico de la pelea torpe 95.0", self.messages(self.run_arena(boss)))

    def test_short_window_and_two_hits_per_window(self):
        boss = copy.deepcopy(self.boss)
        boss["phase3"]["window_s"] = 2.5
        boss["validation_model"]["laps"]["1"]["windows"][0] = [0, 2, 1]
        msg = self.messages(self.run_arena(boss))
        self.assertIn("vuelta 1, fase 3: la ventana dura 2.50", msg)
        self.assertIn("vuelta 1: la pelea torpe pide 2 golpes en una ventana", msg)

    def test_short_mark_slow_chargers_and_few_likes(self):
        boss = copy.deepcopy(self.boss)
        boss["laps"]["3"]["mark_duration_s"] = 0.5
        boss["laps"]["3"]["charger_cooldown_s"] = 11.0
        boss["respawn_min_likes"] = 3
        msg = self.messages(self.run_arena(boss))
        self.assertIn("vuelta 3: en la marca de 0.50 s caben", msg)
        self.assertIn("vuelta 3: los cargadores se enfrian 11.0", msg)
        self.assertIn("likes al empezar cada fase 3 < umbral", msg)

    def test_other_bosses_do_not_use_the_curator_model(self):
        for name in ("1-boss", "2-boss"):
            rep = vb.validate_arena(load(os.path.join(ROOT, "data", "levels", "%s.json" % name)), ROOT)["boss"]
            self.assertNotIn("cur_windows", rep, name)


class SeenArenaTest(unittest.TestCase):
    """Arena 4-boss de El Visto (paso 17 de docs/propuesta-mundo-4.md, §7.2, 2026-10-28): validador completo (avisos y
    esquivar, reaparicion de la fase 1 a tiro, escudo a tiro de pulso desde las burbujas fijas y no desde el suelo,
    Stickers a tiro de pulso desde el suelo y tiempo entre tandas para desinflarlos, subir y pulsar el escudo,
    «escribiendo…» a tiro de pulso desde el suelo, ventanas por fase y acceso, marca, energia torpe sin Agitar
    —retirado el 2026-10-28— y cargadores), con casos negativos sinteticos."""

    @classmethod
    def setUpClass(cls):
        cls.boss = load(os.path.join(ROOT, "data", "bosses", "seen.json"))
        cls.result = vb.validate_arena(load(os.path.join(ROOT, "data", "levels", "4-boss.json")), ROOT)

    def setUp(self):
        self.level = load(os.path.join(ROOT, "data", "levels", "4-boss.json"))

    def run_arena(self, boss=None, level=None):
        return vb.validate_arena(level or self.level, ROOT, boss=boss or self.boss)

    def messages(self, result):
        return " | ".join(e["message"] for e in result["errors"])

    def test_full_validator_passes_without_the_pending_warning(self):
        self.assertEqual(vls.validate_level(self.level, ROOT), [])
        result = vl.validate(self.level, ROOT)
        self.assertTrue(result["ok"], result["errors"])
        self.assertEqual(result["warnings"], [], "validador completo: sin el aviso del paso 16")
        self.assertIn("seen_windows", result["boss"])
        self.assertGreater(result["boss"]["reachable_cells"], 36, "las burbujas de una via cuentan")

    def test_energy_margins_of_the_clumsy_fight_in_every_access(self):
        energy = self.result["boss"]["energy"]
        self.assertEqual(sorted(energy), ["1", "2", "3"])
        for lap, scenarios in energy.items():
            self.assertEqual(sorted(scenarios), ["base", "todo al maximo", "tope del acceso"])
            for name, e in scenarios.items():
                self.assertGreaterEqual(e["min_margin"], 20.0, (lap, name))
        # Sin Agitar (2026-10-28): la fase 2 ya no paga 2 Agitares por ventana ni la 3 uno por mensaje.
        self.assertEqual([ph["peak"] for ph in energy["1"]["base"]["phases"]], [47.5, 45.0, 50.0])

    def test_windows_fit_by_phase_and_access(self):
        windows = self.result["boss"]["seen_windows"]
        self.assertEqual(len(windows), 18)
        for w in windows:
            self.assertLessEqual(w["need_s"], w["window_s"] + 1e-6, w)
        froms = {(w["lap"], w["phase"], w["from"], w["k"]): w["strategy"] for w in windows}
        self.assertEqual(froms[("1", 1, "floor", 2.0)], "debug_on", "Fase 1: el Debug se enciende leyendo el rastro")
        self.assertEqual(froms[("1", 3, "typing_bubble", 2.0)], "debug")
        self.assertEqual(froms[("3", 3, "typing", 1.0)], "debug_on")

    def test_shield_from_the_fixed_bubbles_and_never_from_the_floor(self):
        p2 = self.result["boss"]["seen_phase2"]
        # Pulso (96 px) desde el borde interior de las burbujas fijas (columnas 5-6 y 13-14).
        self.assertEqual(sorted(tuple(c) for c in p2["shield_cells"]), [(5, 5), (6, 5), (13, 5), (14, 5)])
        self.assertEqual(p2["floor_cells"], 0)
        self.assertTrue(p2["clean_cells"], "los Stickers quedan a tiro de pulso desde el suelo")
        self.assertEqual(p2["shield_layers"], 2, "Kernel: dos capas, dos pulsos")
        self.assertLessEqual(p2["climb_s"] + p2["pulse_cycle_s"], p2["sticker_interval_s"])
        boss = copy.deepcopy(self.boss)
        boss["arena"]["shield_margin_px"] = 300.0
        self.assertIn("fase 2: el escudo se alcanza con el pulso desde el suelo", self.messages(self.run_arena(boss)))
        boss = copy.deepcopy(self.boss)
        boss["arena"]["shield_margin_px"] = 0.0
        boss["arena"]["body"] = [7, 1, 6, 1]
        self.assertIn("fase 2: el escudo no queda a tiro de pulso", self.messages(self.run_arena(boss)))
        boss = copy.deepcopy(self.boss)
        boss["phase2"]["sticker_interval_s"] = 2.0
        self.assertIn("fase 2: entre tandas de Stickers hay 2.00 s", self.messages(self.run_arena(boss)))

    def test_the_arena_does_not_use_shockwave(self):
        level = copy.deepcopy(self.level)
        self.assertNotIn("shockwave", level["abilities_available"])
        level["abilities_available"]["shockwave"] = True
        self.assertIn("la arena no usa Agitar", self.messages(self.run_arena(level=level)))
        self.assertNotIn("shakes", json.dumps(self.boss["validation_model"]))

    def test_typing_bubble_within_pulse_from_the_floor(self):
        self.assertGreater(self.result["boss"]["seen_phase3"]["typing_floor_cells"], 0)
        boss = copy.deepcopy(self.boss)
        boss["arena"]["typing_rect"] = [7, 3, 6, 2]
        self.assertIn("fase 3: el «escribiendo…» no queda a tiro de pulso desde el suelo",
                      self.messages(self.run_arena(boss)))

    def test_without_fixed_bubbles_the_shield_cannot_be_reached(self):
        level = copy.deepcopy(self.level)
        level["objects"] = [o for o in level["objects"] if o.get("params", {}).get("id") not in ("burbuja_baja_izq",
                                                                                                  "burbuja_baja_der")]
        msg = self.messages(self.run_arena(level=level))
        self.assertIn("la burbuja fija left", msg)
        self.assertIn("no se alcanza desde P", msg)

    def test_short_telegraphs_window_and_mark(self):
        boss = copy.deepcopy(self.boss)
        boss["ghost_dash"]["warn_frames"] = 5
        boss["laps"]["3"]["dot_interval_s"] = 0.4
        boss["phase3"]["window_s"] = 2.5
        boss["laps"]["2"]["mark_duration_s"] = 0.2
        msg = self.messages(self.run_arena(boss))
        self.assertIn("aviso de 'reaparicion': 5 cuadros", msg)
        self.assertIn("vuelta 3: cada punto del «escribiendo…» dura 0.40 s", msg)
        self.assertIn("vuelta 1, fase 3: la ventana dura 2.50", msg)
        self.assertIn("vuelta 2: en la marca de 0.20 s caben", msg)

    def test_energy_margin_too_small_and_slow_chargers(self):
        boss = copy.deepcopy(self.boss)
        boss["validation_model"]["laps"]["2"]["debug_s"] = [4.0, 14.0, 4.5]
        boss["laps"]["3"]["charger_cooldown_s"] = 13.0
        msg = self.messages(self.run_arena(boss))
        self.assertIn("base, vuelta 2, fase 2: pico de la pelea torpe 100.0", msg)
        self.assertIn("vuelta 3: los cargadores se enfrian 13.0", msg)

    def test_two_hits_per_window_fail(self):
        boss = copy.deepcopy(self.boss)
        boss["validation_model"]["laps"]["1"]["windows"][0] = [0, 2, 1]
        self.assertIn("vuelta 1: la pelea torpe pide 2 golpes en una ventana", self.messages(self.run_arena(boss)))

    def test_other_bosses_do_not_use_the_seen_model(self):
        for name in ("1-boss", "2-boss", "3-boss"):
            rep = vb.validate_arena(load(os.path.join(ROOT, "data", "levels", "%s.json" % name)), ROOT)["boss"]
            self.assertNotIn("seen_windows", rep, name)


if __name__ == "__main__":
    unittest.main()
