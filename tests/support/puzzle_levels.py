"""Salas sinteticas para las pruebas Python del plan del camino (paso 10 de
docs/propuesta-1-2.md §10, 2026-10-16). No son niveles del juego: se generan en memoria
para comprobar que el validador encuentra lo posible y detecta lo imposible (Debug y
plataformas ocultas, energia, banners) sin tocar data/levels/.
"""

import copy
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_room(name):
    """Copia de una sala de prueba de data/levels/<name>.json."""
    with open(os.path.join(ROOT, "data", "levels", "%s.json" % name), encoding="utf-8") as handle:
        return json.load(handle)


def set_cell(level, x, y, char):
    row = level["grid"][y]
    level["grid"][y] = row[:x] + char + row[x + 1:]


def obj_by_id(level, oid):
    return next(o for o in level["objects"] if o.get("params", {}).get("id") == oid)


def hidden_gap(chip=True, refill=True, debug_required=True, start_energy=None, charger=False):
    """Sala de 20 x 12 con el patron de 2c («Falta una plataforma»): la repisa de salida (columnas
    1-6, de pie en la fila 6) termina ante un hueco de 4 tiles (columnas 7-10) que no se salta;
    en medio, una plataforma oculta 'h' de 2 tiles (columnas 8-9) que solo es solida con el Debug.
    Debajo, un foso (filas 7-10) con una repisa de una via que devuelve a la salida, nunca al otro
    lado. El chip del Debug (columna 4) con refill_energy; la terminal en la columna 17."""
    grid = [
        "####################",
        "#..................#",
        "#..................#",
        "#..................#",
        "#..................#",
        "#..................#",
        "#.P..............G.#",
        "#######.hh.#########",
        "#######....#########",
        "#######-...#########",
        "#######....#########",
        "####################",
    ]
    objects = [{"type": "exit_terminal", "x": 17, "y": 5,
                "params": {"id": "terminal_hueco", "text": "Marcar como leído", "width_tiles": 1, "height_tiles": 2}}]
    if chip:
        objects.append({"type": "ability_pickup", "x": 4, "y": 6,
                        "params": {"id": "chip_debug", "ability": "debug", "refill_energy": bool(refill)}})
    if charger:
        objects.append({"type": "charger", "x": 3, "y": 6,
                        "params": {"id": "cargador_h", "amount": 50.0, "reusable": True, "cooldown_s": 10.0}})
    validation = {}
    if debug_required:
        validation["debug_required"] = True
    if start_energy is not None:
        validation["start_energy"] = start_energy
    level = {
        "id": "hueco_test",
        "name": "Falta una plataforma (sintetica)",
        "world": 1,
        "tile_size": 64,
        "debug_color": "cyan",
        "abilities_available": {"pulse": True, "laser": False, "debug": False},
        "sections": [{"name": "Falta una plataforma", "x_from": 0, "x_to": 19, "patterns": []}],
        "grid": grid,
        "checkpoints": [],
        "secrets": [],
        "enemies": [],
        "objects": objects,
        "unlocks": [],
    }
    if validation:
        level["validation"] = validation
    return level


def banner_tunnel(ceiling=True):
    """Pasillo de 14 tiles con dos banners desfasados (como mensajes_test) bajo un techo a 2 tiles
    del suelo (`ceiling`): sin sitio para saltar por encima del banner ni nicho, no se cruza sin
    dano."""
    level = load_room("mensajes_test")
    level["enemies"] = [e for e in level["enemies"] if e["type"] == "spam_banner"]
    # Quita los puntos rojos del grid (sus celdas E).
    set_cell(level, 9, 9, ".")
    set_cell(level, 13, 7, ".")
    if ceiling:
        for x in range(19, 35):
            for y in (6, 7, 8):
                set_cell(level, x, y, "#")
    return level


def deep(level):
    return copy.deepcopy(level)
