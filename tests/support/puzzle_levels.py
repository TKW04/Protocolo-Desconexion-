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


def dash_corridor(niches=(), open_ceiling=False, start_energy=None, charger=True):
    """Sala «Silenciados» (data/levels/silenciados_test.json, paso 9 de docs/propuesta-1-3.md) con el
    pasillo obligatorio del banner banner_dash (columnas 6-17, techo bajo) cambiado: `niches` abre nichos
    de una via en el techo (columnas de cada nicho, filas 7-8 libres y la repisa en la 9), `open_ceiling`
    deja 3 filas libres en todo el pasillo (se salta el banner) y `start_energy` / `charger` quitan
    energia. No pasan el esquema (knockback_to_entry exige techo bajo): check_schema=False."""
    level = load_room("silenciados_test")
    for cols in niches:
        # El hueco del techo es un tile mas ancho por cada lado: desde la repisa se baja andando.
        for x in range(min(cols) - 1, max(cols) + 2):
            for y in (7, 8):
                set_cell(level, x, y, ".")
        for x in cols:
            set_cell(level, x, 9, "-")
    if open_ceiling:
        for x in range(6, 18):
            set_cell(level, x, 8, ".")
    if start_energy is not None:
        level["validation"]["start_energy"] = start_energy
    if not charger:
        level["objects"] = [o for o in level["objects"] if o["type"] != "charger"]
    return level


def blink_pit(on_fraction=0.6, offsets=(0.0, 0.5)):
    """Sala «Vibracion» (data/levels/vibracion_test.json) con el foso del 2a (columnas 9-14) convertido en
    un pozo sin fondo: solo se cruza por las dos plataformas que parpadean (A en 9-10 y B en 12-13), al
    compas. `on_fraction` y `offsets` (A, B) cambian cuando estan encendidas (con 0,3 y medio ciclo de
    desfase nunca coinciden: no hay cruce)."""
    level = load_room("vibracion_test")
    for x in range(9, 15):
        set_cell(level, x, 11, ".")
    for oid, off in zip(("blink_2a_a", "blink_2a_b"), offsets):
        obj = obj_by_id(level, oid)
        obj["params"]["on_fraction"] = on_fraction
        obj["params"]["offset"] = off
    return level


def secret_behind_pit(forbid=True):
    """Sala «Excepciones» (data/levels/excepciones_test.json) con un pozo sin fondo de 4 tiles (columnas
    20-23) entre la pared con glitch y el secreto: andando no se salta; con el dash (salto y dash aereo)
    si. Con `forbid` el secreto lleva forbid_abilities ["dash"] (como en la sala): su ruta no se encuentra."""
    level = load_room("excepciones_test")
    for x in range(20, 24):
        set_cell(level, x, 11, ".")
    secret = level["secrets"][0]
    if not forbid:
        secret.pop("forbid_abilities", None)
    return level


def dnd_gap(switch=True):
    """Sala «Ajustes» (data/levels/ajustes_test.json) con un pozo sin fondo de 4 tiles (columnas 15-18)
    antes de la terminal: solo se cruza con el dash, que da el interruptor «No molestar» (columna 7) con un
    pulso de espaldas. Sin `switch`, no hay dash."""
    level = load_room("ajustes_test")
    for x in range(15, 19):
        set_cell(level, x, 11, ".")
    if not switch:
        level["objects"] = [o for o in level["objects"] if o["type"] != "dnd_switch"]
    return level


def blink_standing_problems(level, exported, zone_id, tile=64):
    """Comprobacion independiente del plan (paso 9): con el camino exportado (isak-path/1), el metronomo
    `zone_id` (arranca cuando los pies de Isak entran en su zona) y sus ciclos (tempo_steps_s, cycles_per_step,
    loop), devuelve los pasos que empiezan o acaban de pie sobre una plataforma que parpadea apagada
    [(paso, id)]. Mira solo los extremos de cada paso walk / wait / wait_beat (no el arco de los saltos)."""
    zone = next(o for o in level["objects"] if o["type"] == "rhythm_zone" and o["params"]["id"] == zone_id)["params"]
    zx, zy, zw, zh = zone["zone"]
    tempo = zone["tempo_steps_s"]
    per_step = zone.get("cycles_per_step", 4)
    blinks = [o for o in level["objects"] if o["type"] == "blink_platform" and o["params"]["rhythm"] == zone_id]

    def inside(cell):
        return zx <= cell[0] < zx + zw and zy <= cell[1] < zy + zh

    start = None
    for s in exported["steps"]:
        if start is not None:
            break
        a = (s.get("from") or s.get("at") or {}).get("cell")
        b = (s.get("to") or {}).get("cell")
        if a is not None and inside(a):
            start = s["t_world"]
        elif b is not None and inside(b):
            start = s["t_world"] + s["duration_s"]
            if s["action"] == "walk" and b[1] == a[1]:
                # Andando: entra cuando los pies cruzan el borde de la zona.
                x0, x1 = s["from"]["feet_px"][0], s["to"]["feet_px"][0]
                edge = zx * tile if x1 > x0 else (zx + zw) * tile
                start = s["t_world"] + s["duration_s"] * (edge - x0) / (x1 - x0)
    if start is None:
        return []

    def phase(t):
        t -= start
        if t < 0:
            return 0.0
        cycles = 0
        while True:
            cycle = tempo[(cycles // per_step) % len(tempo)]
            if t < cycle:
                return t / cycle
            t -= cycle
            cycles += 1

    problems = []
    for s in exported["steps"]:
        if s["action"] not in ("walk", "wait", "wait_beat"):
            continue
        ends = [(s.get("from") or s.get("at"))["cell"], (s.get("to") or s.get("at"))["cell"]]
        for cell, t in zip(ends, (s["t_world"], s["t_world"] + s["duration_s"])):
            for b in blinks:
                p = b["params"]
                if b["y"] == cell[1] + 1 and b["x"] <= cell[0] < b["x"] + p.get("width_tiles", 2):
                    local = (phase(t) - p.get("offset", 0.0)) % 1.0
                    if local >= p.get("on_fraction", 0.5) + 0.02 and local <= 0.98:
                        problems.append((s["i"], p["id"]))
    return problems


def deep(level):
    return copy.deepcopy(level)
