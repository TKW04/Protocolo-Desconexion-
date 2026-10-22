"""Objetos del Mundo 2 como piezas que el validador ya modela (2026-10-22, paso 4 de
docs/propuesta-mundo-2.md §8).

lower(level, catalog) devuelve una copia del nivel en la que:
  - cada tarjeta fragil que cuenta al pisarla (fragile_card con trigger on_step, ni oculta ni de pie)
    es un recordatorio de un grupo propio (reminder_platform: tabla que cae timer_s despues de pisarla y
    vuelve a los respawn_s; FragileCard reutiliza ReminderPlatform en el juego);
  - cada Historia (story_card) es una plataforma que parpadea (blink_platform) que sigue su metronomo
    (rhythm) o, con su propio reloj, un metronomo sintetico que arranca con el nivel (rhythm_zone con
    start always, ciclo cycle_s; StoryCard reutiliza BlinkPlatform y RhythmZone en el juego) con
    on_fraction = on_s / cycle_s;
  - las tarjetas fragiles que solo rompe el golpe al suelo (trigger pound_only, de pie u ocultas) son
    terreno solido ('#'; las de una via, '-'): el golpe que las rompe lo modela el paso 9.
Un nivel sin objetos del Mundo 2 se devuelve tal cual (la salida del Mundo 1 no cambia).
"""
import copy

WORLD2_TYPES = ("fragile_card", "story_card")


def _params(catalog, obj):
    params = dict(catalog.get("types", {}).get(obj["type"], {}).get("defaults", {}))
    params.update(obj.get("params", {}))
    return params


def has_world2_objects(level):
    return any(isinstance(o, dict) and o.get("type") in WORLD2_TYPES for o in level.get("objects", []))


def lower(level, catalog):
    if not has_world2_objects(level):
        return level
    out = copy.deepcopy(level)
    grid = [list(row) for row in out["grid"]]
    objects = []
    for obj in out.get("objects", []):
        kind = obj.get("type")
        if kind not in WORLD2_TYPES:
            objects.append(obj)
            continue
        p = _params(catalog, obj)
        x, y = int(obj["x"]), int(obj["y"])
        width = int(p.get("width_tiles", 2))
        oid = str(p.get("id", "%s_%d_%d" % (kind, x, y)))
        if kind == "fragile_card":
            upright = p.get("variant", "floor") == "upright"
            if p.get("trigger", "on_step") == "on_step" and not upright and not p.get("hidden", False):
                objects.append({"type": "reminder_platform", "x": x, "y": y, "params": {
                    "id": oid, "group": "_fragil_" + oid, "width_tiles": width,
                    "timer_s": float(p.get("timer_s", 0.6)), "warn_s": float(p.get("warn_s", 0.5)),
                    "respawn_s": float(p.get("respawn_s", 3.0))}})
                continue
            char = "-" if p.get("one_way", False) and not upright else "#"
            for dy in range(2 if upright else 1):
                for dx in range(width):
                    grid[y + dy][x + dx] = char
            continue
        rhythm = str(p.get("rhythm", "") or "")
        on_fraction = float(p.get("on_fraction", 0.5))
        if not rhythm:
            cycle = float(p.get("cycle_s", 3.2))
            rhythm = "_historia_" + oid
            on_fraction = float(p.get("on_s", 1.6)) / max(cycle, 0.05)
            objects.append({"type": "rhythm_zone", "x": x, "y": y, "params": {
                "id": rhythm, "zone": [x, y, width, 1], "tempo_steps_s": [cycle], "cycles_per_step": 1,
                "loop": True, "start": "always"}})
        objects.append({"type": "blink_platform", "x": x, "y": y, "params": {
            "id": oid, "rhythm": rhythm, "group": str(p.get("group", "H") or "H"), "width_tiles": width,
            "on_fraction": on_fraction, "offset": float(p.get("offset", 0.0)),
            "one_way": bool(p.get("one_way", False))}})
    out["objects"] = objects
    out["grid"] = ["".join(row) for row in grid]
    return out
