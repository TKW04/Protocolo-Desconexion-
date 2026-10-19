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


def long_banner_corridor(niche=False):
    """Pasillo de 16 tiles (columnas 18-33) con un solo banner que barre en el sentido en que anda
    Isak, cada 3 s (como banner_2 del 1-2; 2026-10-19), bajo un techo a 2 tiles del suelo (sin
    saltar por encima). Andando se tarda unos 4,9 s en cruzar la franja del banner: el barrido
    siguiente le alcanza siempre. Con `niche`, un nicho de refugio a medio pasillo (repisa de una via
    de 2 tiles en la fila 9, columnas 26-27, con el techo abierto encima, columnas 25-28): se espera
    ahi a que pase el barrido."""
    level = banner_tunnel()
    level["enemies"] = [e for e in level["enemies"] if e["id"] == "banner_1"]
    banner = level["enemies"][0]
    banner["x"] = 18
    banner["params"]["corridor_tiles"] = 16
    set_cell(level, 33, 10, ".")
    set_cell(level, 20, 10, ".")
    set_cell(level, 18, 10, "E")
    for x in (17, 18):
        for y in (6, 7, 8):
            set_cell(level, x, y, "#")
    if niche:
        for x in range(25, 29):
            for y in (6, 7, 8):
                set_cell(level, x, y, ".")
        set_cell(level, 26, 9, "-")
        set_cell(level, 27, 9, "-")
    return level


def banner_walk_hits(level, exported, hitbox, walk_speed, sample_dt=1.0 / 120.0):
    """Comprobacion independiente del plan (2026-10-19): recorre los pasos `walk` y `wait` del camino
    exportado (isak-path/1) a su velocidad real y devuelve los golpes de banner [(paso, x)]. El reloj
    de cada banner se ancla en la espera de fase anterior (`banner_cycle_s` al terminarla, como hace
    el bot) y avanza con el tiempo del mundo de los pasos. Comprueba ademas que cada `walk` dura lo
    que se tarda andando (walk_speed)."""
    with open(os.path.join(ROOT, "data", "enemies", "spam_banner.json"), encoding="utf-8") as handle:
        base = json.load(handle)
    tile = level["tile_size"]
    banners = {}
    for enemy in level["enemies"]:
        if enemy["type"] != "spam_banner":
            continue
        p = dict(base)
        p.update(enemy.get("params", {}))
        warn = p["anticipation_frames"] / p["anim_fps"]
        corridor = p["corridor_tiles"] * tile
        sweep = (corridor - p["banner_size"][0]) / p["sweep_speed_px_s"]
        interval = max(p["interval_s"], warn + sweep + 0.01)
        banners[enemy["id"]] = {
            "dir": p["direction"], "corridor": corridor, "bw": p["banner_size"][0], "warn": warn,
            "rest": interval - warn - sweep, "interval": interval, "speed": p["sweep_speed_px_s"],
            "entry": (enemy["x"] + 0.5) * tile - tile * 0.5 * p["direction"],
            "dw": p["damage_size"][0], "dh": p["damage_size"][1],
            "bottom": (enemy["y"] + 1) * tile - p["damage_bottom_px"]}

    def rect(b, cycle):
        t = cycle % b["interval"]
        if t < b["rest"] + b["warn"]:
            return None
        progress = min((t - b["rest"] - b["warn"]) * b["speed"], b["corridor"] - b["bw"])
        cx = b["entry"] + b["dir"] * (b["bw"] * 0.5 + progress)
        return (cx - b["dw"] * 0.5, b["bottom"] - b["dh"], cx + b["dw"] * 0.5, b["bottom"])

    hw, hh = hitbox[0] * 0.5, hitbox[1]
    steps = exported["steps"]
    anchor = None
    hits = []
    for k, s in enumerate(steps):
        if s["action"] == "wait_phase":
            end = s["t_world"] + s["seconds"]
            anchor = {bid: (end, c) for bid, c in s["banner_cycle_s"].items()}
            continue
        if anchor is None or s["action"] not in ("walk", "wait") or k + 1 >= len(steps):
            continue
        t0, t1 = s["t_world"], steps[k + 1]["t_world"]
        if s["action"] == "walk":
            x0, feet = s["from"]["feet_px"]
            x1 = s["to"]["feet_px"][0]
            assert abs(s["duration_s"] - abs(x1 - x0) / walk_speed) < 0.02, s
        else:
            x0, feet = s["at"]["feet_px"]
            x1 = x0
        n = max(1, int((t1 - t0) / sample_dt))
        for j in range(n + 1):
            tw = t0 + (t1 - t0) * j / n
            x = x0 + (x1 - x0) * j / n
            for bid, (a_t, a_c) in anchor.items():
                r = rect(banners[bid], a_c + tw - a_t)
                if r and r[0] < x + hw and r[2] > x - hw and r[1] < feet and r[3] > feet - hh:
                    hits.append((s["i"], round(x)))
                    break
    return hits


def deep(level):
    return copy.deepcopy(level)
