"""Mundo 4 «El Chat» en el validador (2026-10-28, paso 9 de docs/propuesta-mundo-4.md §7.1 y §8): congelado y zonas «Visto», burbujas, «escribiendo…», autocorrector, Linterna y oscuridad, Troll, Troll
disfrazado, Fantasma, Sticker, muro de texto y ola de «Visto» para tools/validate_level.py y
tools/level_plan.py.

lower(level, catalog, allies) devuelve una copia del nivel con las piezas del Mundo 4 traducidas a las que el
validador ya conoce (sin objetos ni enemigos del Mundo 4 se devuelve tal cual: la salida del 1-1 al 3-3 y de las
arenas es identica byte a byte):

  - burbujas fijas (chat_bubble sin `deleted`), «escribiendo…» (typing_bubble) y autocorrector
    (autocorrect_bubble, con su largo CORREGIDO en su ranura: §7.1, «el plan no puede contar con el ancho
    "antes" una vez disparado») son plataformas de una via: '-' en sus celdas del grid (tarjeta de 32 px arriba
    de la celda, como una '-'). Las eliminadas no existen para el grafo;
  - los pasos en tinta (ink_only con kind step) son '-' solo con la Linterna (un flashlight_pickup en el nivel o
    `linterna` en --allies); sin ella, nada;
  - «¿Deshacer escritura?» (undo_prompt; UndoPrompt hereda de DndSwitch) es un `dnd_switch` (pulso de espaldas)
    con la configuracion de su seccion (`_config`) y la marca TYPED_UNDO como `ability` (no da ninguna habilidad:
    desde el 2026-10-28, al retirarse Agitar, solo deshace los muros de texto del nivel);
  - el muro de texto (typed_wall) es una pieza `_pound_card` de 1 x height_tiles con `wall` y `_typed`: una
    pared que se abre en cuanto el «¿Deshacer escritura?» esta usado (desde cualquier celda junto a ella; antes la
    abria la onda de Agitar); el plan espera su borrado (erase_s) si llega a la vez.

World4(model, Gate) se crea solo con algo del Mundo 4 (LevelModel.w4). Agitar (shockwave) esta retirado: nada del
validador lo usa. Sobre el camino principal:

  - Zonas «Visto» (seen_zone): peligro de TIEMPO (la congelacion cuesta freeze_s, sin dano). Toda zona siempre
    activa que el camino cruza tiene su doble check a tiro de pulso desde una celda de pie del camino antes de
    entrar (paso `pulse_seen`, que la interrumpe interrupt_s, 4 s); si no, error. Con ciclo, el plan espera el
    hueco (`wait`, como mucho off_s + on_s). Regla de §3.3 (la del 4-1, en todo el Mundo 4 desde que no hay
    Agitar que libere): ningun peligro (pinchos, linea de un Troll, Fantasma o Sticker) alcanza a Isak congelado
    en una zona: error si uno queda a FROZEN_REACH_TILES (1) o menos de ella.
  - «Escribiendo…»: la burbuja existe desde type_s (1,0 s) despues de su disparo (`trigger`: otra burbuja que el
    camino pisa antes; `trigger_zone`: celdas que el camino toca antes). Si el camino aterriza en ella, el plan
    espera lo que falte en la celda de despegue (`wait_typing`); si el disparo no ocurre antes de despegar, o la
    celda de despegue es otra «escribiendo…» con ciclo que se elimina antes de que la espera termine (on_s), es
    un error («pide saltar antes de 1,0 s»).
  - Autocorrector: si el camino aterriza en el, el plan espera el cursor (`wait_autocorrect`, cursor_s 0,75 s)
    en la celda de despegue. «Engaña, no mata»: bajo cada columna que deja al descubierto hay suelo ('#' o '-') a
    max_drop_tiles (3) filas o menos y sin pinchos por medio; si no, error (pozo mortal).
  - Linterna y Modo oscuro: los pasos en tinta solo con ella (arriba); la legibilidad de §3.6 la comprueba el
    esquema. Salida: zonas oscuras y si hay Linterna.
  - Troll: si el camino entra en su linea (cuerpos solapados en vertical y a detect_tiles o menos), el plan lo
    aturde antes con un pulso (si lo alcanza desde esa celda); si no, error.
    Troll disfrazado: si el camino pasa a unmask_tiles (2) o menos, el nivel necesita el Debug para distinguirlo
    (error si no lo tiene). Fantasma: al entrar en su detect_tiles (3), el plan espera a que reaparezca
    (`wait_ghost`, vanish_s + hidden_s + anticipacion) y lo aturde con un pulso. Sticker: a detect_tiles (6) o
    menos, un pulso lo desinfla para siempre (+5; pulse_deflates de data/enemies/sticker.json).
    Acecho (params.lurk de Troll y Sticker, 2026-10-28, peligros ocultos del Modo oscuro): solo cambia lo que
    se ve (ojos a oscuras hasta que ataca), no el comportamiento ni los tiempos: el plan lo trata igual y la
    salida lo marca «(acecha a oscuras)»; el esquema exige que este dentro de una dark_zone.
  - Ola de «Visto» (seen_wave): amenaza movil en X (generaliza el borde del scroll de tools/scroll_model.py):
    arranca al cruzar Isak start_col, avanza con la velocidad de la seccion del frente, espera en cada parada
    hasta que Isak cruza resume_col (una vez) y se apaga en end_col. Se simula sobre la linea de tiempo del plan
    (tiempo del mundo): el frente nunca puede quedar a menos de validation.wave_margin_tiles (3) de la espalda
    de Isak; si no, error («la ola alcanza a Isak»). Las paradas que el camino pasa salen en la salida
    (`wait_wave` queda reservado para los niveles reales: hoy ninguna sala necesita esperar en una parada).

Camino exportado (isak-path/1): pasos nuevos pulse_seen, wait_typing, wait_autocorrect, wait_ghost y wait_wave
(este ultimo, reservado). El paso `shake` (Agitar) ya no se genera; level_plan lo sigue entendiendo.
"""
import copy
import math

WORLD4_TYPES = ("seen_zone", "chat_bubble", "typing_bubble", "autocorrect_bubble", "flashlight_pickup",
                "dark_zone", "ink_only", "seen_wave", "undo_prompt", "typed_wall", "papelera_actor")
WORLD4_ENEMIES = ("troll", "troll_mimic", "sticker", "ghost")
BUBBLE_TYPES = ("chat_bubble", "typing_bubble", "autocorrect_bubble")
# Pasos nuevos del camino exportado.
WAIT_ACTIONS = ("wait_typing", "wait_autocorrect", "wait_ghost", "wait_wave")
ACTIONS = ("shake", "pulse_seen") + WAIT_ACTIONS
# Distancia (tiles) a la que un peligro alcanza a Isak congelado en una zona «Visto» (regla del 4-1).
FROZEN_REACH_TILES = 1
# Marca del «¿Deshacer escritura?» en el grafo (no es una habilidad: deshace los muros de texto).
TYPED_UNDO = "typed_undo"
# Margen de la ola por defecto (tiles; validation.wave_margin_tiles, §7.1: 3 en Caché).
WAVE_MARGIN_TILES = 3.0
PULSE_SAMPLE_PX = 4.0
EPS = 1e-6


def _params(catalog, obj):
    params = dict(catalog.get("types", {}).get(obj.get("type"), {}).get("defaults", {}))
    params.update(obj.get("params", {}) if isinstance(obj.get("params"), dict) else {})
    return params


def has_world4(level):
    if level.get("_world4"):
        return True  # ya bajado por lower()
    return any(isinstance(o, dict) and o.get("type") in WORLD4_TYPES for o in level.get("objects", [])) or any(
        isinstance(e, dict) and e.get("type") in WORLD4_ENEMIES for e in level.get("enemies", []))


def bubble_width(text, cfg):
    """Largo en tiles por el texto (la regla de ChatBubble.width_for_text y build_level.bubble_width)."""
    per = int(cfg.get("chars_per_tile", 6))
    tiles = -(-len(text) // per)
    return max(int(cfg.get("min_tiles", 1)), min(int(cfg.get("max_tiles", 8)), tiles))


def bubble_cells(kind, x, y, params, cfg):
    """Celdas de una burbuja en el grafo: su largo (el autocorrector, el corregido dentro de su ranura)."""
    w = bubble_width(str(params.get("text", "")), cfg)
    if kind != "autocorrect_bubble":
        return [(x + i, y) for i in range(w)]
    wc = bubble_width(str(params.get("corrected", "")), cfg)
    slot = max(w, wc)
    anchor = str(params.get("anchor", params.get("side", "left")) or "left")
    x0 = x if anchor == "left" else x + slot - wc
    return [(x0 + i, y) for i in range(wc)]


def autocorrect_uncovered(x, y, params, cfg):
    """Columnas que el autocorrector deja al descubierto al corregirse (las de antes que ya no estan)."""
    w = bubble_width(str(params.get("text", "")), cfg)
    wc = bubble_width(str(params.get("corrected", "")), cfg)
    slot = max(w, wc)
    side = str(params.get("anchor", params.get("side", "left")) or "left")
    before = {x + i for i in range(w)} if side == "left" else {x + slot - w + i for i in range(w)}
    after = {c for c, _ in bubble_cells("autocorrect_bubble", x, y, params, cfg)}
    return sorted(before - after)


def flashlight_possible(level, allies=()):
    return "linterna" in set(allies or ()) or any(
        isinstance(o, dict) and o.get("type") == "flashlight_pickup" for o in level.get("objects", []))


def lower(level, catalog, allies=()):
    if not has_world4(level):
        return level
    out = copy.deepcopy(level)
    grid = [list(row) for row in out["grid"]]
    rows, cols = len(grid), len(grid[0]) if grid else 0
    cfg = catalog.get("chat_bubble", {})
    lamp = flashlight_possible(level, allies)

    def one_way(cells):
        for c, r in cells:
            if 0 <= r < rows and 0 <= c < cols and grid[r][c] == ".":
                grid[r][c] = "-"

    objects = []
    for obj in out.get("objects", []):
        kind = obj.get("type")
        p = _params(catalog, obj)
        x, y = obj.get("x", 0), obj.get("y", 0)
        if kind in BUBBLE_TYPES:
            if not (kind == "chat_bubble" and p.get("deleted")):
                one_way(bubble_cells(kind, x, y, p, cfg))
        elif kind == "ink_only" and p.get("kind") == "step" and lamp:
            one_way([(x + i, y) for i in range(int(p.get("width_tiles", 1)))])
        elif kind == "undo_prompt":
            params = dict(obj.get("params", {}))
            params["ability"] = TYPED_UNDO
            params["_config"] = "undo_prompt"
            objects.append({"type": "dnd_switch", "x": x, "y": y, "params": params})
            continue
        elif kind == "typed_wall":
            h = int(p.get("height_tiles", 3))
            objects.append({"type": "_pound_card", "x": x, "y": y, "params": {
                "id": str(p.get("id", "typed_wall_%d_%d" % (x, y))), "width_tiles": 1, "rows": h, "one_way": False,
                "hidden": False, "card_height_px": h * 64.0, "pounds": 1, "wall": True, "_typed": True}})
            continue
        objects.append(obj)
    out["objects"] = objects
    out["grid"] = ["".join(row) for row in grid]
    out["_world4"] = True
    return out


def _cell_rect(T, c0, r0, w, h):
    return (c0 * T, r0 * T, (c0 + w) * T, (r0 + h) * T)


def _rect_dist(a, b):
    dx = max(a[0] - b[2], b[0] - a[2], 0.0)
    dy = max(a[1] - b[3], b[1] - a[3], 0.0)
    return math.hypot(dx, dy)


class World4:
    def __init__(self, model, gate_cls=None):
        self.m = model
        T = model.T
        level = model.level
        catalog = model.catalog
        self.cfg_bubble = catalog.get("chat_bubble", {})
        self.cfg_zone = catalog.get("seen_zone", {})
        self.cfg_wave = catalog.get("seen_wave", {})
        abilities = self._load_abilities(model)
        sw = abilities.get("shockwave", {}) if isinstance(abilities.get("shockwave"), dict) else {}
        # Agitar retirado (2026-10-28): solo se guardan sus cifras para el paso `shake` de level_plan (que ya no
        # se genera).
        self.shake_radius = float(sw.get("radius_px", 160.0))
        self.shake_cost = float(sw.get("energy_cost", 10.0))
        self.shake_s = float(sw.get("windup_s", 0.15)) + float(sw.get("exposed_s", 0.25))
        self.typed_erase_s = float(catalog.get("typed_wall", {}).get("erase_s", 0.4))
        self.lamp = flashlight_possible(level, getattr(model.rules, "allies", ()))
        self.zones = []
        self.typing = []
        self.autocorrect = []
        self.bubbles = {}  # id -> celdas (todas las burbujas, para los disparos por id)
        self.darks = []
        self.wave = None
        for obj in level.get("objects", []):
            kind = obj.get("type")
            p = _params(catalog, obj)
            x, y = obj.get("x", 0), obj.get("y", 0)
            oid = str(p.get("id", "%s_%d_%d" % (kind, x, y)))
            if kind == "seen_zone":
                w, h = int(p.get("width_tiles", 2)), int(p.get("height_tiles", 1))
                side = str(p.get("icon", "left"))
                iw, ih = self.cfg_zone.get("icon_size_px", [36, 28])
                ex = x * T if side == "left" else (x + w) * T
                cy = (y + h * 0.5) * T
                icon = (ex - iw * 0.5, cy - ih * 0.5, ex + iw * 0.5, cy + ih * 0.5, "doble check de %s" % oid)
                cyc = p.get("on_s") is not None and p.get("off_s") is not None
                self.zones.append({"id": oid, "cells": {(x + i, y + j) for j in range(h) for i in range(w)},
                                   "rect": _cell_rect(T, x, y, w, h), "icon": icon, "side": side,
                                   "freeze_s": float(p.get("freeze_s", 1.5)), "cycle": cyc,
                                   "on_s": float(p.get("on_s", 0.0) or 0.0), "off_s": float(p.get("off_s", 0.0) or 0.0),
                                   "cell": (x, y)})
            elif kind in BUBBLE_TYPES:
                cells = bubble_cells(kind, x, y, p, self.cfg_bubble)
                self.bubbles[oid] = set(cells)
                if kind == "typing_bubble":
                    zone = p.get("trigger_zone")
                    self.typing.append({"id": oid, "cells": set(cells), "trigger": str(p.get("trigger", "") or ""),
                                        "zone": zone if isinstance(zone, list) and len(zone) == 4 else None,
                                        "cycle_s": p.get("cycle_s"), "on_s": p.get("on_s"), "cell": (x, y)})
                elif kind == "autocorrect_bubble":
                    self.autocorrect.append({"id": oid, "cells": set(cells), "cell": (x, y),
                                             "uncovered": autocorrect_uncovered(x, y, p, self.cfg_bubble)})
            elif kind == "dark_zone":
                zone = [x, y, int(p.get("width_tiles", 1)), int(p.get("height_tiles", 1))]
                self.darks.append({"id": oid, "zone": zone})
            elif kind == "seen_wave":
                self.wave = {"id": oid, "col": x, "start_col": int(p.get("start_col", x)),
                             "end_col": int(p.get("end_col", model.cols - 1)),
                             "default": float(p.get("default_speed_tiles_s", 1.0)),
                             "sections": list(p.get("sections", []) or []), "stops": list(p.get("stops", []) or [])}
        self.enemies = []
        for e in level.get("enemies", []):
            kind = e.get("type")
            if kind not in WORLD4_ENEMIES:
                continue
            data = dict(self._enemy_data(model, "troll" if kind == "troll_mimic" else kind))
            if kind == "troll_mimic":
                data.update(self._enemy_data(model, "troll_mimic"))
            data.update(e.get("params", {}) if isinstance(e.get("params"), dict) else {})
            bw, bh = data.get("body_size", [40.0, 56.0])
            x, y = e.get("x", 0), e.get("y", 0)
            feet = ((x + 0.5) * T, (y + 1) * T)
            body = (feet[0] - bw * 0.5, feet[1] - bh, feet[0] + bw * 0.5, feet[1])
            if kind == "ghost":
                span = float(data.get("patrol_range_px", 256.0))
                body = (body[0] - span * 0.5, body[1], body[2] + span * 0.5, body[3])
            self.enemies.append({"id": str(e.get("id", "%s_%d_%d" % (kind, x, y))), "kind": kind, "cell": (x, y),
                                 "body": body, "data": data})

    @staticmethod
    def _load_abilities(model):
        import json
        import os
        path = os.path.join(model.rules.root, "data", "isak_abilities.json")
        try:
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, ValueError):
            return {}

    @staticmethod
    def _enemy_data(model, kind):
        import json
        import os
        path = os.path.join(model.rules.root, "data", "enemies", "%s.json" % kind)
        try:
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, ValueError):
            return {}

    # --- Muro de texto («¿Deshacer escritura?») ---

    def typed_opens(self, gate, node, state):
        """El muro de texto (pieza _pound_card con _typed) esta deshecho: el «¿Deshacer escritura?» ya se uso."""
        return any(g.kind == "dnd" and g.ability == TYPED_UNDO and g.gid in state for g in self.m.gates)

    def explain_typed(self, gate, state):
        if not any(g.kind == "dnd" and g.ability == TYPED_UNDO for g in self.m.gates):
            return "%s solo lo deshace un «¿Deshacer escritura?» y el nivel no tiene ninguno" % gate.label()
        return "%s solo lo deshace el «¿Deshacer escritura?» y no se alcanza antes" % gate.label()

    # --- Comprobaciones sobre el camino principal (sin tiempo) ---

    def check(self, validator, start, goal_cells):
        rep = validator.report
        info = {"zones": [], "autocorrect": [], "dark": {"zones": len(self.darks), "flashlight": self.lamp},
                "mimics": []}
        validator.result["world4"] = info
        m = self.m
        T = m.T
        # Regla de §3.3 (la del 4-1; en todo el Mundo 4 desde que no hay Agitar): nada alcanza a Isak congelado.
        if self.zones:
            for z in self.zones:
                reach = FROZEN_REACH_TILES * T
                near = [s[4] for s in m.spike_rects if _rect_dist(z["rect"], s) <= reach]
                for en in self.enemies:
                    d = en["data"]
                    if en["kind"] in ("troll", "troll_mimic"):
                        line = (en["body"][0] - float(d.get("detect_tiles", 9.0)) * T, en["body"][1],
                                en["body"][2] + float(d.get("detect_tiles", 9.0)) * T, en["body"][3])
                        if _rect_dist(z["rect"], line) <= EPS:
                            near.append("linea del Troll %s" % en["id"])
                    elif _rect_dist(z["rect"], en["body"]) <= (float(d.get("detect_tiles", 3.0)) + FROZEN_REACH_TILES) * T:
                        near.append("%s %s" % ("Fantasma" if en["kind"] == "ghost" else "Sticker", en["id"]))
                if near:
                    rep.error("zona «Visto» %s: un peligro alcanza a Isak congelado (no hay nada que lo libere "
                              "antes: regla de §3.3): %s" % (z["id"], ", ".join(near)), z["cell"][1], z["cell"][0], z["id"])
        # Autocorrector: engaña, no mata.
        cfg_drop = int(self.cfg_bubble.get("max_drop_tiles", 3))
        for a in self.autocorrect:
            c0, r0 = a["cell"]
            bad = []
            for c in a["uncovered"]:
                ok = False
                for r in range(r0 + 1, min(m.rows, r0 + 1 + cfg_drop)):
                    ch = m.grid[r][c] if 0 <= c < m.cols else "#"
                    if ch == "^":
                        break
                    if ch in "#-":
                        ok = True
                        break
                if not ok:
                    bad.append(c)
            info["autocorrect"].append({"id": a["id"], "uncovered": a["uncovered"], "pits": bad})
            if bad:
                rep.error("autocorrector %s: deja un pozo mortal bajo la(s) columna(s) %s (sin suelo a %d filas o "
                          "menos, o con pinchos): engaña, no mata" % (a["id"], ", ".join(str(c) for c in bad), cfg_drop),
                          r0, c0, a["id"])
        main = getattr(validator, "main", None)
        if not main or not main.get("ok"):
            return
        nodes = []
        for stage in main["stages"]:
            nodes.extend(_stage_nodes(stage))
        # Troll disfrazado: si el camino pasa cerca, hace falta el Debug para distinguirlo.
        debug_possible = m.debug_base or any(g.kind == "pickup" and g.ability == "debug" for g in m.gates)
        for en in self.enemies:
            if en["kind"] != "troll_mimic":
                continue
            reach = float(en["data"].get("unmask_tiles", 2.0)) * T
            near = any(_rect_dist(_body_rect(m, n), en["body"]) <= reach for n in nodes)
            info["mimics"].append({"id": en["id"], "near_path": near})
            if near and not debug_possible:
                rep.error("Troll disfrazado %s: el camino pasa a %.0f tiles o menos y el nivel no tiene el Debug para "
                          "distinguirlo de una burbuja de amigo" % (en["id"], reach / T), en["cell"][1], en["cell"][0],
                          en["id"])

    # --- Plan del camino (con tiempo) ---

    def plan(self, planner, steps):
        """Inserta los pasos del Mundo 4 (pulse_seen, esperas y pulsos a enemigos), comprueba la ola y
        devuelve los pasos."""
        info = planner.v.result.setdefault("world4", {})
        steps = self._plan_zones(planner, steps, info)
        steps = self._plan_bubbles(planner, steps, info)
        steps = self._plan_enemies(planner, steps, info)
        self._plan_wave(planner, steps, info)
        return steps

    def _move_nodes(self, s):
        if s["action"] == "move":
            return [s["from"], s["to"]]
        node = s.get("at")
        return [tuple(node)] if node is not None else []

    def _plan_zones(self, planner, steps, info):
        m = self.m
        out = []
        done = set()
        zinfo = info.setdefault("zones", [])
        for i, s in enumerate(steps):
            if s["action"] == "move":
                for z in self.zones:
                    if z["id"] in done or not (_body_cells(s["to"]) & z["cells"]):
                        continue
                    done.add(z["id"])
                    entry = {"id": z["id"], "cycle": z["cycle"], "at": [s["to"][1], s["to"][0]]}
                    if z["cycle"]:
                        wait = z["off_s"] + z["on_s"]
                        out.append({"action": "wait", "at": s["from"], "seconds": wait, "state": s["state"],
                                    "reason": "hueco del ciclo de la zona «Visto» %s" % z["id"]})
                        entry["wait_s"] = round(wait, 2)
                    else:
                        shot = self._pulse_from(out, s, z["icon"])
                        if shot is None:
                            planner.error("zona «Visto» %s: el camino la cruza y su doble check no esta a tiro de pulso "
                                          "desde ninguna celda de pie antes de entrar" % z["id"], s["to"], z["id"])
                        else:
                            node, x, facing = shot
                            out.append({"action": "pulse_seen", "at": node, "state": s["state"],
                                        "shot": {"x": x, "facing": facing},
                                        "target": {"type": "seen_zone", "id": z["id"]}})
                            entry["pulse_from"] = [node[1], node[0]]
                    zinfo.append(entry)
            out.append(s)
        return out

    def _pulse_from(self, out, s, rect):
        """Celda de pie del camino (la de despegue o las anteriores, hasta 6 pasos) desde la que el pulso alcanza
        `rect`: (nodo, x, mirada) o None."""
        m = self.m
        cands = [s["from"]] + [p["from"] for p in reversed(out[-6:]) if p["action"] == "move"]
        for node in cands:
            if not m.has_pulse(s["state"]):
                return None
            hit = self._pulse_x(rect, node, s["state"])
            if hit is not None:
                return (node,) + hit
        return None

    def _pulse_x(self, rect, node, state):
        m = self.m
        rules = m.rules
        w = m.world(state, False)
        c, r = node
        feet = (r + 1) * m.T
        x = c * m.T
        while x <= (c + 1) * m.T + EPS:
            if not w.collides(x, feet) and not w.in_hazard(x, feet):
                for facing in (1, -1):
                    px, py = x + rules.phone_x * facing, feet + rules.phone_y
                    qx = min(max(px, rect[0]), rect[2])
                    qy = min(max(py, rect[1]), rect[3])
                    if math.hypot(px - qx, py - qy) <= rules.pulse_radius + EPS:
                        return (x, facing)
            x += PULSE_SAMPLE_PX
        return None

    def _plan_bubbles(self, planner, steps, info):
        type_s = float(self.cfg_bubble.get("type_s", 1.0))
        cursor_s = float(self.cfg_bubble.get("cursor_s", 0.75))
        planner.timeline(steps)
        out = []
        touched = {}  # id de burbuja / zona -> indice del primer paso que la toca
        tinfo = info.setdefault("typing", [])
        ainfo = info.setdefault("autocorrect_waits", [])
        waited = set()
        for i, s in enumerate(steps):
            if s["action"] == "move":
                land = _body_cells(s["to"])
                feet_cell = (s["to"][0], s["to"][1] + 1)
                for t in self.typing:
                    if t["id"] in waited or feet_cell not in t["cells"]:
                        continue
                    waited.add(t["id"])
                    trig = t["trigger"]
                    k = touched.get(("bubble", trig)) if trig else touched.get(("zone", t["id"]))
                    if k is None:
                        planner.error("«escribiendo…» %s: el camino aterriza en ella sin haberla disparado antes "
                                      "(%s)" % (t["id"], "burbuja %s" % trig if trig else "zona de disparo"),
                                      s["to"], t["id"])
                        continue
                    # Desde que el paso que la dispara termina (los pies en la burbuja o el cuerpo en la zona).
                    fired = out[k].get("tw", 0.0) + planner.duration(out[k]) * (
                        planner.rules.debug_world_scale if out[k].get("debug_active") else 1.0)
                    elapsed = s.get("tw", 0.0) - fired
                    wait = max(0.0, type_s - elapsed)
                    under = self._typing_under(s["from"])
                    if under is not None and under["cycle_s"] is not None and under["on_s"] is not None \
                            and wait > float(under["on_s"]) + EPS:
                        planner.error("«escribiendo…» %s pide saltar antes de %.1f s: la espera (%.2f s) no cabe en la "
                                      "ventana de la «escribiendo…» %s desde la que despega (on_s %.2f s)"
                                      % (t["id"], type_s, wait, under["id"], float(under["on_s"])), s["from"], t["id"])
                    if wait > EPS:
                        out.append({"action": "wait_typing", "at": s["from"], "seconds": round(wait, 3),
                                    "state": s["state"], "reason": "«escribiendo…» %s" % t["id"],
                                    "target": {"type": "typing_bubble", "id": t["id"]}})
                    tinfo.append({"id": t["id"], "wait_s": round(wait, 2), "at": [s["from"][1], s["from"][0]]})
                for a in self.autocorrect:
                    if a["id"] in waited or feet_cell not in a["cells"]:
                        continue
                    waited.add(a["id"])
                    out.append({"action": "wait_autocorrect", "at": s["from"], "seconds": cursor_s,
                                "state": s["state"], "reason": "cursor del autocorrector %s" % a["id"],
                                "target": {"type": "autocorrect_bubble", "id": a["id"]}})
                    ainfo.append({"id": a["id"], "at": [s["from"][1], s["from"][0]]})
                for node in (s["from"], s["to"]):
                    under = (node[0], node[1] + 1)
                    for bid, cells in self.bubbles.items():
                        if under in cells:
                            touched.setdefault(("bubble", bid), len(out))
                    for t in self.typing:
                        z = t["zone"]
                        if z and any(z[0] <= c < z[0] + z[2] and z[1] <= r < z[1] + z[3] for c, r in _body_cells(node)):
                            touched.setdefault(("zone", t["id"]), len(out))
            out.append(s)
        # Los pasos insertados no tienen tiempo: se rehace la linea de tiempo para lo que sigue.
        planner.timeline(out)
        return out

    def _typing_under(self, node):
        below = (node[0], node[1] + 1)
        return next((t for t in self.typing if below in t["cells"]), None)

    def _plan_enemies(self, planner, steps, info):
        """Troll, Fantasma y Sticker: al entrar el camino en su alcance (el Troll, en su linea), el plan lo aturde
        desde la primera celda de pie desde la que llega el pulso (al Sticker lo desinfla para siempre). El Fantasma
        antes se esfuma y reaparece detras: wait_ghost y el pulso a su sitio de reaparicion. Si el camino llega a pasar junto al enemigo
        (a trigger_tiles: 1,5 el Sticker, 1 los demas) sin haberlo aturdido, es un error."""
        m = self.m
        T = m.T
        out = []
        handled = set()
        engaged = set()
        einfo = info.setdefault("enemies", [])
        for s in steps:
            if s["action"] == "move":
                body = _body_rect(m, s["from"])
                for en in self.enemies:
                    if en["id"] in handled or en["kind"] == "troll_mimic":
                        continue
                    d = en["data"]
                    b = en["body"]
                    reach = float(d.get("detect_tiles", 3.0)) * T
                    if en["kind"] == "troll":
                        inside = body[1] < b[3] and b[1] < body[3] and _rect_dist(body, b) <= reach
                    else:
                        inside = _rect_dist(body, b) <= reach
                    if not inside:
                        continue
                    engaged.add(en["id"])
                    entry = {"id": en["id"], "type": en["kind"], "at": [s["from"][1], s["from"][0]]}
                    if d.get("lurk") is True:
                        entry["lurk"] = True
                    target_rect = b
                    if en["kind"] == "ghost":
                        direction = 1.0 if s["to"][0] >= s["from"][0] else -1.0
                        fx = (s["from"][0] + 0.5) * T - direction * float(d.get("behind_tiles", 2.0)) * T
                        bw, bh = d.get("body_size", [40.0, 56.0])
                        feet = (s["from"][1] + 1) * T
                        target_rect = (fx - bw * 0.5, feet - bh, fx + bw * 0.5, feet)
                    use = self._stun_step(s, en, target_rect)
                    if use is None and en["kind"] == "sticker":
                        # El Sticker persigue a Isak por su suelo y se para a trigger_tiles para inflarse: si
                        # esta en el mismo suelo, el plan lo espera quieto (lo que tarda en llegar) y lo desinfla
                        # con el pulso cuando se infla a su lado (2026-10-28, sin Agitar que llegaba de lejos).
                        feet_y = (s["from"][1] + 1) * T
                        if abs(b[3] - feet_y) <= T * 0.5:
                            cx = (s["from"][0] + 0.5) * T
                            direction = 1.0 if (b[0] + b[2]) * 0.5 >= cx else -1.0
                            bw, bh = d.get("body_size", [40.0, 40.0])
                            fx = cx + direction * float(d.get("trigger_tiles", 1.5)) * T
                            near = (fx - bw * 0.5, feet_y - bh, fx + bw * 0.5, feet_y)
                            use = self._stun_step(s, en, near)
                            if use is not None:
                                gap = max(0.0, abs((b[0] + b[2]) * 0.5 - fx))
                                wait = gap / max(float(d.get("chase_speed_px_s", 120.0)), 1.0)
                                if wait > EPS:
                                    out.append({"action": "wait", "at": s["from"], "seconds": round(wait, 3),
                                                "state": s["state"],
                                                "reason": "Sticker %s: esperar a que llegue" % en["id"],
                                                "target": {"type": "sticker", "id": en["id"]}})
                                    entry["wait_s"] = round(wait, 2)
                    if use is None:
                        close = float(d.get("trigger_tiles", 1.0)) * T
                        if _rect_dist(_body_rect(m, s["to"]), b) <= close and en["kind"] != "ghost":
                            handled.add(en["id"])
                            planner.error("%s %s: el camino pasa junto a el sin poder aturdirlo antes (el pulso no lo "
                                          "alcanza desde ninguna celda de pie)" % (_enemy_name(en["kind"]),
                                                                                         en["id"]), s["to"], en["id"])
                        elif en["kind"] == "ghost":
                            handled.add(en["id"])
                            planner.error("Fantasma %s: reaparece detras de Isak en (fila %d, columna %d) y el pulso "
                                          "no llega a su sitio" % (en["id"], s["from"][1], s["from"][0]),
                                          s["from"], en["id"])
                        continue
                    if en["kind"] == "ghost":
                        wait = float(d.get("vanish_s", 0.3)) + float(d.get("hidden_s", 1.0)) + \
                            float(d.get("anticipation_frames", 9)) / float(d.get("anim_fps", 12.0))
                        out.append({"action": "wait_ghost", "at": s["from"], "seconds": round(wait, 3),
                                    "state": s["state"], "reason": "Fantasma %s: esperar a que reaparezca" % en["id"],
                                    "target": {"type": "ghost", "id": en["id"]}})
                        entry["wait_s"] = round(wait, 2)
                    out.append(use)
                    handled.add(en["id"])
                    entry["with"] = use["action"]
                    einfo.append(entry)
            out.append(s)
        return out

    def _stun_step(self, s, en, rect):
        node, state = s["from"], s["state"]
        target = {"type": en["kind"], "id": en["id"]}
        if self.m.has_pulse(state):
            hit = self._pulse_x(rect, node, state)
            if hit is not None:
                return {"action": "pulse", "at": node, "state": state, "shot": {"x": hit[0], "facing": hit[1]},
                        "target": target}
        return None

    def _plan_wave(self, planner, steps, info):
        wave = self.wave
        if wave is None:
            return
        T = self.m.T
        margin = float(self.m.validation.get("wave_margin_tiles", WAVE_MARGIN_TILES))
        planner.timeline(steps)
        front = (wave["col"] + 1) * T
        started = False
        stops = [dict(st) for st in wave["stops"]]
        passed = set()
        closest = None
        tw_prev = 0.0
        hit = None
        for s in steps:
            samples = planner.samples(s) if s["action"] == "move" else None
            d = planner.duration(s) * (planner.rules.debug_world_scale if s.get("debug_active") else 1.0)
            if not samples:
                node = s.get("at") or s.get("to") or s.get("from")
                feet = planner.feet(tuple(node)) if node is not None else (0.0, 0.0)
                samples = [(feet[0], feet[1], False)] * max(1, int(round(d / (1.0 / 60.0))))
            dt = d / len(samples) if samples else 0.0
            for (x, _feet, _air) in samples:
                col = x / T
                if not started and col >= wave["start_col"]:
                    started = True
                if started and front < (wave["end_col"] + 1) * T:
                    held = False
                    for st in stops:
                        if st["id"] in passed:
                            continue
                        if col >= st["resume_col"]:
                            passed.add(st["id"])
                            continue
                        if front >= (st["at_col"] + 1) * T - EPS:
                            held = True
                            front = (st["at_col"] + 1) * T
                            break
                    if not held:
                        front += self._wave_speed(front / T) * T * dt
                        for st in stops:
                            if st["id"] not in passed and front > (st["at_col"] + 1) * T:
                                front = (st["at_col"] + 1) * T
                back = x - self.m.hw
                gap = (back - front) / T
                if started and (closest is None or gap < closest[0]):
                    closest = (gap, s)
                if started and gap < margin - EPS and hit is None:
                    hit = (gap, s)
        info["wave"] = {"id": wave["id"], "margin_tiles": margin,
                        "closest_tiles": None if closest is None else round(closest[0], 2),
                        "stops_passed": sorted(passed)}
        if hit is not None:
            node = hit[1].get("to") or hit[1].get("at")
            planner.error("la ola de «Visto» %s alcanza a Isak: queda a %.1f tiles de su espalda (margen %.0f, "
                          "validation.wave_margin_tiles)" % (wave["id"], hit[0], margin),
                          tuple(node) if node is not None else None, wave["id"])

    def _wave_speed(self, col):
        for sec in self.wave["sections"]:
            if sec.get("x_from", 0) <= col < sec.get("x_to", 0):
                v0 = float(sec.get("speed_tiles_s", self.wave["default"]))
                v1 = sec.get("speed_to_tiles_s")
                if v1 is None:
                    return v0
                k = (col - sec["x_from"]) / max(sec["x_to"] - sec["x_from"], EPS)
                return v0 + (float(v1) - v0) * min(max(k, 0.0), 1.0)
        return self.wave["default"]


def _enemy_name(kind):
    return {"troll": "Troll", "troll_mimic": "Troll disfrazado", "ghost": "Fantasma", "sticker": "Sticker"}[kind]


def _body_cells(node):
    c, r = node[0], node[1]
    return {(c, r), (c, r - 1)}


def _body_rect(model, node):
    c, r = node[0], node[1]
    x, feet = (c + 0.5) * model.T, (r + 1) * model.T
    return (x - model.hw, feet - model.hh, x + model.hw, feet)


def _stage_nodes(stage):
    out = [stage["end"]]
    node = stage["end"]
    parent = stage["parent"]
    while parent.get(node) is not None:
        node = parent[node][0]
        out.append(node)
    return out


def format_lines(result):
    w4 = result.get("world4")
    if not w4:
        return []
    out = []
    for z in w4.get("zones", []):
        if "wait_s" in z:
            out.append("  zona «Visto» %s: con ciclo; el camino espera %.1f s antes de cruzarla" % (z["id"], z["wait_s"]))
        elif "pulse_from" in z:
            out.append("  zona «Visto» %s: pulso al doble check desde (fila %d, columna %d)" % (
                z["id"], z["pulse_from"][0], z["pulse_from"][1]))
    for t in w4.get("typing", []):
        out.append("  «escribiendo…» %s: espera %.2f s en (fila %d, columna %d)" % (t["id"], t["wait_s"], t["at"][0],
                                                                                 t["at"][1]))
    for a in w4.get("autocorrect_waits", []):
        out.append("  autocorrector %s: espera el cursor en (fila %d, columna %d)" % (a["id"], a["at"][0], a["at"][1]))
    dark = w4.get("dark")
    if dark and dark["zones"]:
        out.append("  Modo oscuro: %d zona(s); Linterna %s" % (dark["zones"], "si" if dark["flashlight"] else "no"))
    for e in w4.get("enemies", []):
        out.append("  %s %s: %s desde (fila %d, columna %d)%s" % (
            _enemy_name(e["type"]), e["id"], "pulso", e["at"][0], e["at"][1],
            (", tras esperar %.2f s a que llegue" if e["type"] == "sticker" else ", tras esperar %.2f s a que reaparezca")
            % e["wait_s"] if "wait_s" in e else "") + (" (acecha a oscuras)" if e.get("lurk") else ""))
    for mm in w4.get("mimics", []):
        if mm["near_path"]:
            out.append("  Troll disfrazado %s: junto al camino (el Debug lo distingue)" % mm["id"])
    wave = w4.get("wave")
    if wave:
        out.append("  ola de «Visto» %s: como mucho a %s tiles de la espalda de Isak (margen %.0f)%s" % (
            wave["id"], "-" if wave["closest_tiles"] is None else "%.1f" % wave["closest_tiles"], wave["margin_tiles"],
            "; paradas pasadas: %s" % ", ".join(wave["stops_passed"]) if wave["stops_passed"] else ""))
    return out
