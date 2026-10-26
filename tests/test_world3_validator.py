"""Paso 8a de docs/propuesta-mundo-3.md §8 (2026-10-26): el validador modela Pellizcar, los likes, los filtros y
los espejos fijos del Mundo 3 «La Vitrina» (tools/world3_model.py). Las salas de los pasos 2-5 y 7 validan (con
el camino exportado) y los negativos sinteticos fallan como deben: umbral sin publicacion, filtro obligatorio sin
Debug o sin energia, espejo de 4 rebotes, hueco de 1 fila sin Pellizcar y la regla de diseno de §3.3.2.
Uso: python3 -m unittest tests/test_world3_validator.py
"""

import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import level_catalog  # noqa: E402
import validate_level  # noqa: E402
import world3_model  # noqa: E402

LEVELS = os.path.join(ROOT, "data", "levels")


def load(name):
    with open(os.path.join(LEVELS, name + ".json"), encoding="utf-8") as handle:
        return json.load(handle)


def run(level, export=None, schema=True):
    return validate_level.validate(level, ROOT, export=export, check_schema=schema)


def messages(result):
    return [e["message"] for e in result["errors"]]


def set_cell(level, x, y, char):
    row = level["grid"][y]
    level["grid"][y] = row[:x] + char + row[x + 1:]


def drop(level, obj_id):
    level["objects"] = [o for o in level["objects"] if (o.get("params") or {}).get("id") != obj_id]


def obj(level, obj_id):
    return next(o for o in level["objects"] if (o.get("params") or {}).get("id") == obj_id)


class PinchedNodeTest(unittest.TestCase):
    def test_pinched_is_not_the_normal_node(self):
        p = world3_model.Pinched((3, 4))
        self.assertNotEqual(p, (3, 4))
        self.assertNotEqual((3, 4), p)
        self.assertEqual(p, world3_model.Pinched((3, 4)))
        self.assertEqual(len({p, (3, 4)}), 2)
        c, r = p
        self.assertEqual((c, r), (3, 4))
        self.assertEqual(copy.deepcopy(p), p)
        self.assertEqual(validate_level.body_cells(p), {(3, 4)})
        self.assertEqual(validate_level.body_cells((3, 4)), {(3, 4), (3, 3)})


class RoomsTest(unittest.TestCase):
    """Las salas del Mundo 3 de los pasos 2-5 y 7 validan y exportan su camino."""

    def test_rooms_validate_and_export(self):
        for name in ("likes_test", "recorte_test", "filtro_test", "espejos_test", "vitrina_test"):
            export = []
            result = run(load(name), export)
            self.assertTrue(result["ok"], "%s: %s" % (name, messages(result)))
            self.assertTrue(export and export[0]["steps"], name)

    def test_lowering_crop_tool(self):
        level = world3_model.lower(load("recorte_test"), level_catalog.load_catalog(ROOT, 3))
        switch = next(o for o in level["objects"] if o["type"] == "dnd_switch")
        self.assertEqual(switch["params"]["ability"], "compress")
        self.assertEqual(switch["params"]["_config"], "crop_tool")


class PinchTest(unittest.TestCase):
    def test_recorte_uses_the_crop_tool_and_pinches(self):
        export = []
        result = run(load("recorte_test"), export)
        self.assertTrue(result["ok"], messages(result))
        actions = [st["action"] for st in export[0]["steps"]]
        self.assertIn("pinch", actions)
        self.assertIn("unpinch", actions)
        self.assertLess(actions.index("pulse"), actions.index("pinch"))  # primero la herramienta
        crop = next(st for st in export[0]["steps"] if st["action"] == "pulse" and st["target"]["type"] == "crop_tool")
        self.assertEqual(crop["target"]["ability"], "compress")
        self.assertTrue(any(st.get("compressed") for st in export[0]["steps"]))
        pinch = result["world3"]["pinch"]
        self.assertEqual(len(pinch["runs"]), 2)
        self.assertLessEqual(max(r["tiles"] for r in pinch["runs"]), world3_model.COMPRESSED_MAX_TILES)
        frames = set()
        for r in pinch["runs"]:
            frames |= set(r["frames"])
        self.assertEqual(frames, {"marco_pared", "marco_suelo"})
        text = validate_level.format_text("recorte_test", result)
        self.assertIn("Pellizcar: sin tramo", text)

    def test_one_row_gap_without_pinch_fails(self):
        level = load("recorte_test")
        drop(level, "recortar_prueba")
        result = run(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("marco pequeno marco_pared" in m and "Pellizcar" in m for m in messages(result)),
                        messages(result))

    def test_long_compressed_stretch_is_an_error(self):
        # Tunel de 1 fila de 15 tiles: va comprimido mas de 12 seguidos.
        result = run(pinch_room(tunnel=15), schema=False)
        self.assertTrue(any("comprimido" in m and "maximo 12" in m for m in messages(result)), messages(result))

    def test_short_tunnel_is_fine_with_abilities_available(self):
        result = run(pinch_room(tunnel=8), schema=False)
        self.assertTrue(result["ok"], messages(result))
        self.assertEqual(result["world3"]["pinch"]["runs"][0]["tiles"], 9.0)

    def test_late_recovery_is_an_error(self):
        # El tunel acaba en un pozo de 6 filas: comprimido hasta abajo antes de poder recuperar el tamano.
        result = run(pinch_room(tunnel=5, shaft=True), schema=False)
        self.assertTrue(any("no deja recuperar el tamano" in m for m in messages(result)), messages(result))


def pinch_room(tunnel, shaft=False):
    """Sala sintetica con Pellizcar desde el inicio (abilities_available.compress): inicio en las columnas 1-6, tunel
    de 1 fila de `tunnel` tiles y sala de salida; con `shaft`, el tunel acaba en un pozo hasta la fila 11."""
    width = 7 + tunnel + 10
    rows = ["#" * width]
    for r in range(1, 13):
        row = ["#"] * width
        for c in range(1, width - 1):
            if c <= 6:
                row[c] = "." if r <= 5 else "#"
            elif c < 7 + tunnel:
                row[c] = "." if r == 5 else "#"
            elif shaft:
                if c == 7 + tunnel:
                    row[c] = "." if 5 <= r <= 11 else "#"
                else:
                    row[c] = "." if 6 <= r <= 11 else "#"
            else:
                row[c] = "." if r <= 5 else "#"
        rows.append("".join(row))
    g_row = 11 if shaft else 5
    rows[5] = rows[5][:2] + "P" + rows[5][3:]
    gc = width - 3
    rows[g_row] = rows[g_row][:gc] + "G" + rows[g_row][gc + 1:]
    rows[12] = "#" * width
    return {"id": "pinch_room_test", "name": "Pellizcar (sintetica)", "world": 3, "tile_size": 64,
            "debug_color": "green", "abilities_available": {"pulse": True, "compress": True},
            "checkpoints": [], "secrets": [], "enemies": [], "unlocks": [],
            "objects": [{"type": "exit_terminal", "x": gc, "y": g_row - 1,
                         "params": {"id": "t", "width_tiles": 1, "height_tiles": 2}}],
            "grid": rows}


class LikesTest(unittest.TestCase):
    def test_vitrina_collects_likes_for_the_platform(self):
        export = []
        result = run(load("vitrina_test"), export)
        self.assertTrue(result["ok"], messages(result))
        likes = result["world3"]["likes"]
        self.assertEqual([u["id"] for u in likes["used"]], ["likes_10"])
        self.assertGreaterEqual(likes["used"][0]["likes"], 10)
        self.assertEqual(likes["used"][0]["publication"], "publicacion")
        steps = export[0]["steps"]
        self.assertTrue(any(st["action"] == "heart" for st in steps))
        pub = [st for st in steps if st["action"] == "pulse" and st.get("target", {}).get("type") == "like_source"]
        self.assertTrue(pub)
        self.assertEqual(pub[-1]["target"]["likes_after"], 10)

    def test_publication_reused_waits_its_cooldown(self):
        # Sin corazones: dos usos de la publicacion (5 + 5), con su enfriamiento entre medias.
        level = load("vitrina_test")
        for i in range(1, 6):
            drop(level, "corazon_%d" % i)
        export = []
        result = run(level, export)
        self.assertTrue(result["ok"], messages(result))
        steps = export[0]["steps"]
        pubs = [i for i, st in enumerate(steps) if st["action"] == "pulse"
                and st.get("target", {}).get("type") == "like_source"]
        self.assertEqual(len(pubs), 2)
        waits = [st for st in steps[pubs[0]:pubs[1]] if st["action"] == "wait"]
        self.assertTrue(waits and waits[0]["seconds"] >= 8.0, steps[pubs[0]:pubs[1] + 1])

    def test_threshold_without_publication_fails(self):
        # Diez corazones y ninguna publicacion: el camino llega, pero perder likes bloquearia el nivel.
        level = load("vitrina_test")
        drop(level, "publicacion")
        for i in range(6, 11):
            level["objects"].append({"type": "heart_pickup", "x": 3 + i, "y": 9, "params": {"id": "corazon_%d" % i}})
        result = run(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("anti-atasco" in m and "likes_10" in m for m in messages(result)), messages(result))

    def test_not_enough_likes_fails(self):
        level = load("vitrina_test")
        drop(level, "publicacion")
        result = run(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("likes_10" in m and "apagada" in m for m in messages(result)), messages(result))

    def test_inverse_platform_needs_the_reset(self):
        # ♥5 normal para el primer muro y ♥5 inversa para el segundo: hay que borrar las publicaciones entre medias.
        grid = ["#" * 26] + ["#" + "." * 24 + "#" for _ in range(9)] + ["#" * 26, "#" * 26]
        for c in (11, 12, 18, 19):
            for r in (7, 8, 9):
                grid[r] = grid[r][:c] + "#" + grid[r][c + 1:]
        grid[9] = grid[9][:2] + "P" + grid[9][3:22] + "G" + grid[9][23:]
        level = {"id": "inversa_test", "name": "Inversa (sintetica)", "world": 3, "tile_size": 64,
                 "debug_color": "green", "abilities_available": {"pulse": True}, "checkpoints": [], "secrets": [],
                 "enemies": [], "unlocks": [], "grid": grid, "objects": [
                     {"type": "like_source", "x": 5, "y": 9, "params": {"id": "pub"}},
                     {"type": "like_platform", "x": 9, "y": 8, "params": {"id": "normal_5", "threshold": 5}},
                     {"type": "like_reset", "x": 14, "y": 9, "params": {"id": "borrar"}},
                     {"type": "like_platform", "x": 16, "y": 8, "params": {"id": "inversa_5", "threshold": 5,
                                                                          "invert": True}},
                     {"type": "exit_terminal", "x": 22, "y": 8, "params": {"id": "t", "width_tiles": 1,
                                                                          "height_tiles": 2}}]}
        export = []
        result = run(level, export, schema=False)
        self.assertTrue(result["ok"], messages(result))
        actions = [st["action"] for st in export[0]["steps"]]
        self.assertIn("like_reset", actions)
        used = {u["id"]: u for u in result["world3"]["likes"]["used"]}
        self.assertEqual(used["normal_5"]["likes"], 5)
        self.assertEqual(used["inversa_5"]["likes"], 0)
        # Sin el reset no se llega.
        level["objects"] = [o for o in level["objects"] if o["type"] != "like_reset"]
        self.assertFalse(run(level, schema=False)["ok"])


class FilterTest(unittest.TestCase):
    def test_fixed_filter_needs_debug_and_moving_filter_does_not(self):
        export = []
        result = run(load("filtro_test"), export)
        self.assertTrue(result["ok"], messages(result))
        filters = {f["id"]: f for f in result["world3"]["filters"]}
        self.assertTrue(filters["filtro_orejitas"]["needs_debug"])
        self.assertTrue(filters["filtro_orejitas"]["crossed_with_debug"])
        self.assertEqual(filters["filtro_orejitas"]["charger"]["id"], "cargador_filtro")
        self.assertFalse(filters["filtro_movil"]["needs_debug"])
        self.assertIn("debug_on", [st["action"] for st in export[0]["steps"]])

    def test_mandatory_filter_without_debug_fails(self):
        level = load("filtro_test")
        level["abilities_available"]["debug"] = False
        result = run(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("filtro_orejitas" in m and "Debug" in m for m in messages(result)), messages(result))

    def test_mandatory_filter_without_charger_in_view_fails(self):
        level = load("filtro_test")
        drop(level, "cargador_filtro")
        result = run(level)
        self.assertTrue(any("cargador a la vista" in m for m in messages(result)), messages(result))

    def test_mandatory_filter_without_energy_fails(self):
        level = load("filtro_test")
        drop(level, "cargador_filtro")
        level["validation"] = {"start_energy": 10}
        result = run(level)
        self.assertFalse(result["ok"])
        self.assertTrue(any("energia" in m for m in messages(result)), messages(result))

    def test_moving_filter_with_overlap_needs_debug(self):
        # Dos sitios que se solapan sobre el pincho de la columna 28: esa parte nunca se ve sin el Debug.
        level = load("filtro_test")
        mov = obj(level, "filtro_movil")
        mov["params"]["positions"] = [[27, 5], [28, 5]]
        result = run(level, schema=False)
        filters = {f["id"]: f for f in result["world3"]["filters"]}
        self.assertTrue(filters["filtro_movil"]["needs_debug"])


class MirrorTest(unittest.TestCase):
    def test_espejos_traces_the_lectors(self):
        result = run(load("espejos_test"))
        self.assertTrue(result["ok"], messages(result))
        lectors = {m["id"]: m for m in result["world3"]["mirrors"]}
        self.assertEqual(lectors["lector_techo"]["bounces"], 1)
        self.assertEqual(lectors["lector_techo"]["mirrors"], ["espejo_sube"])
        self.assertEqual(lectors["lector_cadena"]["bounces"], 3)
        self.assertEqual(lectors["lector_cadena"]["mirrors"], ["cadena_1", "cadena_2", "cadena_3"])
        only = {p["id"]: p for p in result["world3"]["mirror_only"]}
        self.assertEqual(only["reflejo_1"]["reflected_cols"], [30, 30])
        self.assertEqual(only["reflejo_2"]["reflected_cols"], [28, 28])
        self.assertTrue(all(p["seen"] for p in only.values()))

    def test_mirrors_open_the_relay_when_it_is_mandatory(self):
        # Muro en la columna 12 con un hueco a la altura del puente: el puente es obligatorio y el lector del techo
        # solo se alcanza por el espejo '/'.
        level = load("espejos_test")
        for r in (2, 3, 4, 7, 8, 9):
            set_cell(level, 12, r, "#")
        set_cell(level, 7, 8, "#")  # escalon para subir al puente
        export = []
        result = run(level, export, schema=False)
        self.assertTrue(result["ok"], messages(result))
        steps = export[0]["steps"]
        lasers = [st for st in steps if st["action"] == "laser" and st["target"]["type"] == "laser_receiver"]
        self.assertTrue(lasers, [st["action"] for st in steps])

    def test_four_bounces_fail(self):
        # Cuarto espejo en la cadena: el lector solo se alcanzaria con 4 rebotes.
        level = load("espejos_test")
        chain = obj(level, "cadena_3")
        chain["params"]["orientation"] = "\\"
        level["objects"].append({"type": "mirror", "x": 19, "y": 7, "params": {"id": "cadena_4", "orientation": "\\"}})
        obj(level, "lector_cadena")["y"] = 7
        obj(level, "lector_cadena")["x"] = 21
        set_cell(level, 23, 7, "#")  # que no se le dispare de frente desde la pared de espejo
        result = run(level, schema=False)
        self.assertTrue(any("lector_cadena" in m and "4 rebotes" in m for m in messages(result)), messages(result))

    def test_mirror_only_outside_the_glass_fails(self):
        level = load("espejos_test")
        obj(level, "reflejo_1")["x"] = 23
        set_cell(level, 23, 9, ".")
        result = run(level, schema=False)
        self.assertTrue(any("reflejo_1" in m and "no se ve" in m for m in messages(result)), messages(result))


class OutputTest(unittest.TestCase):
    def test_world1_and_2_rooms_have_no_world3_block(self):
        for name in ("correo_test", "ajustes_test", "tarjetas_test"):
            self.assertNotIn("world3", run(load(name)), name)


if __name__ == "__main__":
    unittest.main()
