"""Pruebas de conjunto del Mundo 3 «La Vitrina» (paso 20 de docs/propuesta-mundo-3.md §8, 2026-10-27).

Negativos de diseño comprobados sobre los niveles reales (3-1, 3-2, 3-3; los filtros tambien en filtro_test) con el
modelo del validador y la escena generada (la fisica real la prueban tests/test_world3_negatives.gd y
tests/test_filter_zone.gd):

- **Perder likes nunca bloquea** (§3.1, regla anti-atasco): cada plataforma de likes normal que pisa el camino tiene
  una publicacion (like_source, reutilizable) alcanzable SIN likes desde el ultimo punto de sincronizacion; en la arena
  3-boss se reaparece con respawn_min_likes >= el umbral de sus plataformas. Negativo: el 3-1 sin sus publicaciones
  anti-atasco falla (aunque los corazones bastarian para el camino).
- **El filtro no mata** (§3.2 regla 2, decision 5 de §9): todo pincho bajo un filtro es hidden_by_filter, quita 10
  (< Sync Rate maximo) y empuja hacia la entrada del filtro; junto a el, hacia la entrada, hay suelo sin pincho; ninguna
  columna bajo un filtro es un pozo sin fondo; el suelo falso deja caer <= 3 tiles a un foso con salida (el esquema).
  Negativo: un pozo sin fondo bajo el filtro del 3-2 lo detecta la comprobacion.
Uso: python3 -m unittest tests/test_world3_negatives.py
"""

import copy
import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level as vl  # noqa: E402
import validate_level_schema as vls  # noqa: E402

LEVELS = os.path.join(ROOT, "data", "levels")
SCENES = os.path.join(ROOT, "scenes", "levels")
WORLD3_LEVELS = ("3-1", "3-2", "3-3")
FILTER_LEVELS = ("3-2", "3-3", "filtro_test")
SYNC_RATE_MAX = 100.0


def load(name):
    with open(os.path.join(LEVELS, name + ".json"), encoding="utf-8") as handle:
        return json.load(handle)


def catalog_section(name):
    with open(os.path.join(ROOT, "data", "world3_objects.json"), encoding="utf-8") as handle:
        data = json.load(handle)
    return data["types"][name], data.get(name, {})


def objects(level, kind):
    return [o for o in level["objects"] if o["type"] == kind]


def filter_cells(obj):
    entry, _ = catalog_section("filter_zone")
    params = dict(entry.get("defaults", {}))
    params.update(obj.get("params", {}))
    w, h = int(params["width_tiles"]), int(params["height_tiles"])
    corners = params.get("positions") or [[obj["x"], obj["y"]]]
    cells = {(int(x) + i, int(y) + j) for (x, y) in corners for j in range(h) for i in range(w)}
    return cells, params


def hidden_spikes_in_scene(name):
    """{(col, fila): {damage, knockback_direction}} de los Spikes_* con hidden_by_filter de la escena generada."""
    with open(os.path.join(SCENES, name + ".tscn"), encoding="utf-8") as handle:
        text = handle.read()
    out = {}
    for block in text.split("\n[node ")[1:]:
        m = re.match(r'name="Spikes_(\d+)_(\d+)"', block)
        if not m or "hidden_by_filter = true" not in block:
            continue
        damage = re.search(r"^damage = ([\d.]+)", block, re.M)
        direction = re.search(r"^knockback_direction = (-?[\d.]+)", block, re.M)
        out[(int(m.group(1)), int(m.group(2)))] = {
            "damage": float(damage.group(1)) if damage else None,
            "knockback_direction": float(direction.group(1)) if direction else 0.0,
        }
    return out


def spike_runs_start(grid, cells):
    """Primera columna de cada tramo horizontal de '^' (asi nombra build_level.py los Spikes_<c>_<f>)."""
    starts = set()
    for (c, r) in cells:
        if grid[r][c] == "^" and not (c > 0 and grid[r][c - 1] == "^"):
            starts.add((c, r))
    return starts


def deadly_pits_under(level, cells):
    """Columnas bajo un filtro desde cuya celda mas alta del filtro no se llega a terreno ('#' o '-') sin salirse
    del grid: un pozo sin fondo escondido."""
    grid = level["grid"]
    rows = len(grid)
    pits = []
    for col in sorted({c for (c, _) in cells}):
        top = min(r for (c, r) in cells if c == col)
        r = top
        while r < rows and grid[r][col] not in "#-":
            r += 1
        if r >= rows:
            pits.append(col)
    return pits


class LikesNeverBlockTest(unittest.TestCase):
    """Perder likes nunca bloquea: una publicacion alcanzable sin likes antes de cada umbral del camino."""

    @classmethod
    def setUpClass(cls):
        cls.results = {name: vl.validate(copy.deepcopy(load(name)), ROOT) for name in WORLD3_LEVELS}

    def test_every_threshold_on_the_path_has_a_publication_reachable_without_likes(self):
        for name, result in self.results.items():
            with self.subTest(level=name):
                self.assertTrue(result["ok"], result["errors"])
                used = [u for u in result["world3"]["likes"]["used"] if not u["invert"]]
                self.assertTrue(used, "%s: el camino pisa plataformas de likes" % name)
                for u in used:
                    self.assertTrue(u.get("publication"),
                                    "%s: %s (♥%d) sin publicacion anti-atasco desde %s" %
                                    (name, u["id"], u["threshold"], u.get("sync")))
                pubs = {(o.get("params") or {}).get("id") for o in objects(load(name), "like_source")}
                self.assertTrue({u["publication"] for u in used} <= pubs)

    def test_curator_arena_respawns_with_enough_likes(self):
        with open(os.path.join(ROOT, "data", "bosses", "curator.json"), encoding="utf-8") as handle:
            boss = json.load(handle)
        thresholds = [o["params"]["threshold"] for o in objects(load("3-boss"), "like_platform")]
        self.assertTrue(thresholds)
        self.assertGreaterEqual(int(boss["respawn_min_likes"]), max(thresholds),
                                "Al reaparecer en la arena se llega al umbral de las plataformas")

    def test_3_1_without_its_anti_softlock_publications_fails(self):
        result = self.results["3-1"]
        cited = {u["publication"] for u in result["world3"]["likes"]["used"] if u.get("publication")}
        level = load("3-1")
        level["objects"] = [o for o in level["objects"] if (o.get("params") or {}).get("id") not in cited]
        bad = vl.validate(level, ROOT, check_schema=False)
        self.assertFalse(bad["ok"], "Sin publicaciones el 3-1 no debe validar")
        msgs = [e["message"] for e in bad["errors"]]
        self.assertTrue(any("anti-atasco" in m or "apagada" in m for m in msgs), msgs)


class FilterNeverKillsTest(unittest.TestCase):
    """El filtro engaña, no mata."""

    def test_hidden_spikes_take_ten_and_push_to_the_entry(self):
        _, cfg = catalog_section("filter_zone")
        damage = float(cfg["spike_hidden_damage"])
        self.assertEqual(damage, 10.0)
        self.assertLess(damage, SYNC_RATE_MAX)
        for name in FILTER_LEVELS:
            level = load(name)
            scene = hidden_spikes_in_scene(name)
            seen = set()
            with self.subTest(level=name):
                for f in objects(level, "filter_zone"):
                    cells, params = filter_cells(f)
                    direction = 1.0 if params.get("entry", "left") == "right" else -1.0
                    for start in spike_runs_start(level["grid"], cells):
                        self.assertIn(start, scene, "%s: el pincho %s del filtro %s no es hidden_by_filter"
                                      % (name, start, f["params"]["id"]))
                        spike = scene[start]
                        self.assertEqual(spike["damage"], damage, "%s %s: quita 10" % (name, start))
                        self.assertEqual(spike["knockback_direction"], direction,
                                         "%s %s: empuja hacia la entrada (%s)" % (name, start, params.get("entry")))
                        seen.add(start)
                self.assertEqual(set(scene), seen, "%s: todo pincho oculto esta bajo un filtro" % name)
        self.assertTrue(hidden_spikes_in_scene("3-2"), "El 3-2 tiene pinchos ocultos")
        self.assertTrue(hidden_spikes_in_scene("3-3"), "El 3-3 tiene pinchos ocultos")

    def test_the_push_lands_on_safe_ground(self):
        """Junto a cada pincho oculto, hacia la entrada, hay suelo sin pincho a <= 3 tiles (el empuje no tira a un
        pozo ni a otro pincho)."""
        for name in FILTER_LEVELS:
            level = load(name)
            grid = level["grid"]
            for f in objects(level, "filter_zone"):
                cells, params = filter_cells(f)
                step = 1 if params.get("entry", "left") == "right" else -1
                for (c, r) in sorted(cells):
                    if grid[r][c] != "^":
                        continue
                    nc = c + step
                    while grid[r][nc] == "^":
                        nc += step
                    with self.subTest(level=name, spike=(c, r)):
                        rr = r
                        while rr < len(grid) and grid[rr][nc] not in "#-^":
                            rr += 1
                        self.assertLess(rr, len(grid), "%s: pozo sin fondo junto al pincho (%d, %d)" % (name, c, r))
                        self.assertNotEqual(grid[rr][nc], "^", "%s: el empuje cae en otro pincho" % name)
                        self.assertLessEqual(rr - r, 3, "%s: el empuje deja caer mas de 3 tiles" % name)

    def test_no_bottomless_pit_under_a_filter(self):
        for name in FILTER_LEVELS:
            level = load(name)
            for f in objects(level, "filter_zone"):
                cells, _ = filter_cells(f)
                with self.subTest(level=name, filter=f["params"]["id"]):
                    self.assertEqual(deadly_pits_under(level, cells), [], "Pozo sin fondo bajo el filtro")

    def test_fake_floors_drop_at_most_three_tiles_with_an_exit(self):
        _, cfg = catalog_section("filter_zone")
        self.assertEqual(int(cfg["max_drop_tiles"]), 3)
        floors = 0
        for name in FILTER_LEVELS:
            level = load(name)
            errors = vls.validate_level(level)
            self.assertEqual([e for e in errors if "suelo falso" in str(e) or "fake_floor" in str(e)], [],
                             "%s: el esquema acepta sus suelos falsos" % name)
            for f in objects(level, "filter_zone"):
                for (fx, fy, fw, fh) in f["params"].get("fake_floor", []):
                    floors += 1
                    for col in range(fx, fx + fw):
                        r = fy + fh
                        while level["grid"][r][col] not in "#-":
                            r += 1
                        self.assertLessEqual(r - fy, 3, "%s: suelo falso en %d deja caer %d" % (name, col, r - fy))
        self.assertGreater(floors, 0, "Hay suelos falsos que comprobar")

    def test_a_bottomless_pit_under_the_filter_is_caught(self):
        level = load("3-2")
        f = objects(level, "filter_zone")[0]
        cells, _ = filter_cells(f)
        col = sorted({c for (c, _) in cells})[len({c for (c, _) in cells}) // 2]
        for r in range(min(r for (_, r) in cells), len(level["grid"])):
            row = level["grid"][r]
            level["grid"][r] = row[:col] + "." + row[col + 1:]
        self.assertEqual(deadly_pits_under(level, cells), [col])


if __name__ == "__main__":
    unittest.main()
