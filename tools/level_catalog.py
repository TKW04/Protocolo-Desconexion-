"""Catalogo de objetos y recursos por mundo de los niveles (2026-10-22, paso 2 de
docs/propuesta-mundo-2.md §8).

- load_catalog(root, world): data/world<N>_objects.json. Desde el Mundo 2, los tipos
  genericos del Mundo 1 (cargador, punto de sincronizacion, pared con glitch,
  vortices, recogidas...) mas los del mundo: se unen los `types` (gana el del mundo)
  y las demas secciones del mundo se anaden o sustituyen a las del Mundo 1.
- tileset_json(root, world) y background_res(root, world): el tileset y el fondo del
  mundo; si aun no existen (el arte del Mundo 2 es el paso 10), los del Mundo 1 como
  PROVISIONALES.

La usan tools/build_level.py, tools/validate_level_schema.py y tools/validate_level.py.
"""
import copy
import json
import os

BASE_WORLD = 1


def _load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def catalog_path(root, world):
    return os.path.join(root, "data", "world%d_objects.json" % int(world))


def load_catalog(root, world):
    """Catalogo del mundo `world` (con los tipos del Mundo 1 debajo desde el Mundo 2).
    Lanza OSError / ValueError si falta o no se puede leer el del Mundo 1."""
    world = int(world)
    base = _load(catalog_path(root, BASE_WORLD))
    if world == BASE_WORLD or not os.path.exists(catalog_path(root, world)):
        return base
    own = _load(catalog_path(root, world))
    merged = copy.deepcopy(base)
    for key, value in own.items():
        if key == "types":
            merged.setdefault("types", {}).update(copy.deepcopy(value))
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def tileset_json(root, world):
    path = os.path.join(root, "data", "tileset_mundo%d.json" % int(world))
    if os.path.exists(path):
        return path
    return os.path.join(root, "data", "tileset_mundo%d.json" % BASE_WORLD)


def background_res(root, world):
    res = "res://scenes/levels/world%d_background.tscn" % int(world)
    if os.path.exists(os.path.join(root, res[len("res://"):])):
        return res
    return "res://scenes/levels/world%d_background.tscn" % BASE_WORLD
