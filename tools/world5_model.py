"""Mundo 5 «La Tienda» en el validador (2026-10-29, paso 8 de docs/propuesta-mundo-5.md §7.1 y §8): economia,
tentacion, cajas sorpresa, atajos, cuentas regresivas, Suscripciones (8a) y la Combinacion con sus obstaculos,
Terminos y condiciones, lista de deseos y presupuesto de camino (8b) para tools/validate_level.py y
tools/level_plan.py. Sin nada del Mundo 5 no se usa: la salida de los Mundos 1-4 y de las arenas es identica byte a
byte.

lower(level, catalog) devuelve una copia del nivel con las piezas que el validador ya conoce:

  - tachon (wish_strike, hereda de GlitchWall) -> glitch_wall con visible_only_with_debug;
  - cuenta regresiva (countdown_platform) sin `trigger` -> blink_platform con su propio metronomo (rhythm_zone
    `_cd_<id>` que empieza siempre: ciclo count_s + fold_s, encendida count_s); el plan espera el peor caso
    (paso `wait_countdown`). Con `trigger` (la salida de la trampa countdown) espera solida hasta que salta la
    trampa: el camino frugal no paga, asi que es una tabla fija de card_height_px (World5.apply_world);
  - lista de deseos (wishlist_platform) -> '-' en sus celdas (tarjeta de una via de 32 px, como una '-'), con su
    Oferta integrada como fuente de tentacion;
  - «Prueba gratis» (free_trial_box, hereda de DndSwitch) -> dnd_switch con ability `combo` y su seccion.

World5(model, Gate) (LevelModel.w5) anade las puertas del Mundo 5 (Gate con kind de GATE_KINDS y su w5_label):

  - `pay` (shortcut_door y calc_register): puerta solida de 1 x height_tiles que abre un PULSO DE ESPALDAS pagando
    su precio. Nunca obligatoria: el camino principal la tiene prohibida (como las de un secreto); si la meta solo
    se alcanza pagando, error («arista obligatoria con precio»);
  - `box` (surprise_box): caja solida de su celda; la abre el pulso de cara desde su fila, el golpe al suelo
    encima o el laser (la destruye). Contenido fijo de los datos;
  - `terms` / `terms_accept` (terms_gate): la puerta la abren «rechazar» (laser desde un suelo de enfrente, o un
    Filo que roza el boton) o «ACEPTAR» (cualquier pulso al boton; engancha una Suscripcion: con precio, como el
    atajo, asi que el plan elige rechazar);
  - `shutter` (persiana): solida; solo la rompe una Embestida cuya onda (wave_half_width_px a cada lado de donde
    aterriza, wave_height_px por encima y wave_below_px por debajo) la alcanza;
  - `shelf` (un grupo de clearance_shelf): todas las del grupo solidas; solo las tumba a la vez un Sismo desde
    una celda comprimida cuyo aterrizaje tiene el grupo entero en la vista (VIEW_HALF_W_PX a cada lado) y en su
    planta (la franja de la onda a ras del suelo).

La ranura de precios (price_rail) no es una puerta: sus etiquetas son peligros del grafo (empujan: ningun
movimiento normal puede tocarlas) y solo la cruza el Filo, una arista nueva desde los nodos comprimidos
(Pellizcar en el suelo, salto comprimido y Deslizar: distance_px en duration_s con la caja comprimida y gravedad
0; despues sigue comprimido). La Embestida y el Sismo son acciones de las puertas de arriba (combo_ram,
combo_quake). Los tres cuestan energy_cost (15; la Embestida, ademas, el dash aereo del que sale: 10), solo con `combo` (abilities_available o la «Prueba gratis") y
los dos gestos que combinan, nunca con el Debug.

Sobre el camino (check) y en el plan (plan): economia desde un saldo de 0 (cada cosa que se vende cuesta como
mucho lo que hay antes en la ruta, el total como mucho max_spend_per_level, saldo nunca por debajo de
min_balance, Devoluciones), tentacion (deriva y multiplicadores por zona con suma y tope; quieto nunca acaba en un
foso mortal; siempre hay salida andando; resist_pull), cajas (contenido con aviso, orden seguro con la energia),
Suscripciones (cancel_subscription), anti-redundancia de §3.9 (cada obstaculo del camino exige su combo), regla
de las estanterias (ningun golpe suelto alcanza a dos del mismo grupo), lista de deseos (ninguna parada de add_s
sobre un deseo) y presupuesto de camino (porcentaje de target_duration_s; aviso fuera del 40-55 %).

Camino exportado (isak-path/1): pasos nuevos buy, pay_door, open_box, wait_countdown, cancel_subscription,
combo_ram, combo_edge, combo_quake, reject_terms, resist_pull y refund. Con --buy se exporta el camino del
comprador (paga los atajos que cruza, compra en las tiendas por las que pasa y pide las Devoluciones).
"""
import copy
import json
import math
import os

WORLD5_TYPES = ("shop_item", "shortcut_door", "refund_desk", "surprise_box", "countdown_platform", "terms_gate",
                "shutter", "price_rail", "clearance_shelf", "free_trial_box", "wishlist_platform", "wish_strike",
                "calc_register")
WORLD5_ENEMIES = ("offer_sign", "subscription")
GATE_KINDS = ("pay", "box", "terms", "terms_accept", "shutter", "shelf")
COSTLY_KINDS = ("pay", "terms_accept")
ACTIONS = ("buy", "pay_door", "open_box", "wait_countdown", "cancel_subscription", "combo_ram", "combo_edge",
           "combo_quake", "reject_terms", "resist_pull", "refund")
SAFE_CONTENT = ("points", "energy", "empty")
COMBO_ABILITY = "combo"
# Segundos que el Debug esta activo para leer una caja (tras la carga): lo que cuesta mirar dentro.
LOOK_S = 1.0
# Media vista de la camara (sin camara, 640 px a cada lado: decision 4 del paso 1).
VIEW_HALF_W_PX = 640.0
# Presupuesto de camino (decision 10 de §9): porcentaje del objetivo target_duration_s.
BUDGET = (0.40, 0.55)
SIM_DT = 1.0 / 60.0
SAMPLE_S = 0.05
AFTER_APEX_S = 0.15
EPS = 1e-6


def _params(catalog, obj):
    params = dict(catalog.get("types", {}).get(obj.get("type"), {}).get("defaults", {}))
    params.update(obj.get("params", {}) if isinstance(obj.get("params"), dict) else {})
    return params


def has_world5(level):
    if level.get("_world5"):
        return True
    if COMBO_ABILITY in (level.get("abilities_available") or {}):
        return True
    return any(isinstance(o, dict) and o.get("type") in WORLD5_TYPES for o in level.get("objects", [])) or any(
        isinstance(e, dict) and e.get("type") in WORLD5_ENEMIES for e in level.get("enemies", []))


def is_pinched(node):
    return getattr(node, "pinched", False)


def lower(level, catalog):
    if not has_world5(level):
        return level
    out = copy.deepcopy(level)
    grid = [list(row) for row in out["grid"]]
    rows, cols = len(grid), len(grid[0]) if grid else 0
    cfg_cd = catalog.get("countdown_platform", {})
    objects = []
    for obj in out.get("objects", []):
        kind = obj.get("type")
        p = _params(catalog, obj)
        x, y = obj.get("x", 0), obj.get("y", 0)
        oid = str(p.get("id", "%s_%d_%d" % (kind, x, y)))
        if kind == "wish_strike":
            objects.append({"type": "glitch_wall", "x": x, "y": y, "params": {
                "id": oid, "width_tiles": int(p.get("width_tiles", 1)), "height_tiles": int(p.get("height_tiles", 2)),
                "visible_only_with_debug": True}})
            continue
        if kind == "countdown_platform" and not p.get("trigger"):
            count = float(p.get("count_s", cfg_cd.get("count_s", 5.0)))
            fold = float(cfg_cd.get("fold_s", 1.0))
            zid = "_cd_" + oid
            objects.append({"type": "rhythm_zone", "x": 0, "y": 0, "params": {
                "id": zid, "zone": [0, 0, cols, rows], "tempo_steps_s": [count + fold], "cycles_per_step": 1,
                "loop": True, "start": "always"}})
            objects.append({"type": "blink_platform", "x": x, "y": y, "params": {
                "id": oid, "width_tiles": int(p.get("width_tiles", 2)), "rhythm": zid,
                "on_fraction": count / (count + fold), "offset": 0.0, "_countdown": True}})
            continue
        if kind == "wishlist_platform":
            for i in range(int(p.get("width_tiles", 3))):
                if 0 <= y < rows and 0 <= x + i < cols and grid[y][x + i] == ".":
                    grid[y][x + i] = "-"
        if kind == "free_trial_box":
            params = dict(obj.get("params", {}))
            params["ability"] = COMBO_ABILITY
            params["_config"] = "free_trial_box"
            objects.append({"type": "dnd_switch", "x": x, "y": y, "params": params})
            continue
        objects.append(obj)
    out["objects"] = objects
    out["grid"] = ["".join(row) for row in grid]
    out["_world5"] = True
    return out


def _load(root, *parts):
    try:
        with open(os.path.join(root, *parts), encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def _rect_hit(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def _gap(a, b):
    """Separacion horizontal y vertical entre dos rectangulos (0 si se solapan en ese eje)."""
    return max(a[0] - b[2], b[0] - a[2], 0.0), max(a[1] - b[3], b[1] - a[3], 0.0)


def _grow(r, d):
    return (r[0] - d, r[1] - d, r[2] + d, r[3] + d)


def _cells_rect(T, cells):
    cs = [c for c, _ in cells]
    rs = [r for _, r in cells]
    return (min(cs) * T, min(rs) * T, (max(cs) + 1) * T, (max(rs) + 1) * T)


class World5:
    def __init__(self, model, gate_cls):
        self.m = model
        m = model
        T = m.T
        level = m.level
        cat = m.catalog
        root = m.rules.root
        self.economy = _load(root, "data", "economy.json")
        prices = self.economy.get("prices", {})
        abilities = _load(root, "data", "isak_abilities.json")
        self.cfg_combo = abilities.get("combo", {}) if isinstance(abilities.get("combo"), dict) else {}
        self.combo_cost = float(self.cfg_combo.get("energy_cost", 15.0))
        self.cfg_ram = self.cfg_combo.get("ram", {})
        self.cfg_edge = self.cfg_combo.get("edge", {})
        self.cfg_quake = self.cfg_combo.get("quake", {})
        offer = _load(root, "data", "enemies", "offer_sign.json")
        self.offer_data = offer
        self.field = dict(offer.get("field", {}))
        self.sub_data = _load(root, "data", "enemies", "subscription.json")
        avail = level.get("abilities_available", {}) or {}
        self.combo_base = bool(avail.get(COMBO_ABILITY, False))
        self.gates = []
        self.shops = []
        self.refunds = []
        self.rails = []
        self.static_cards = []
        self.wishes = []
        self.sources = []
        self.subs = []
        self.countdowns = []
        self.points = {(c, r) for r, row in enumerate(m.grid) for c, ch in enumerate(row) if ch == "o"}
        self.disabled_rails = frozenset()
        self._edge_cache = {}
        self._ram_cache = {}
        self._quake_cache = {}
        self._graze_cache = {}

        def gate(gid, kind, oid, label, cells, openers, x, y):
            g = gate_cls(gid, kind, oid, cells=cells, openers=openers, col=x, row=y, tile=T)
            g.w5_label = label
            self.gates.append(g)
            return g

        shelf_groups = {}
        for obj in level.get("objects", []):
            kind = obj.get("type")
            p = _params(cat, obj)
            x, y = obj.get("x", 0), obj.get("y", 0)
            oid = str(p.get("id", "%s_%d_%d" % (kind, x, y)))
            cfg = cat.get(kind, {})
            if kind == "shop_item":
                hit = cfg.get("hit_rect", [4, -24, 56, 72])
                x0, y0 = x * T + hit[0], y * T + hit[1]
                product = str(p.get("product", "sync"))
                cost = p.get("cost")
                if cost is None or int(cost) < 0:
                    cost = prices.get("shop_item", {}).get(product, {}).get("cost", 0)
                self.shops.append({"id": oid, "product": product, "cost": int(cost), "cell": (x, y),
                                   "rect": (x0, y0, x0 + hit[2], y0 + hit[3], "tienda %s" % oid),
                                   "pose_s": float(cfg.get("pose_s", 0.45))})
            elif kind in ("shortcut_door", "calc_register"):
                h = int(p.get("height_tiles", 3))
                w = float(cfg.get("width_px", 40))
                door = (x * T + (T - w) * 0.5, y * T, x * T + (T + w) * 0.5, (y + h) * T)
                grow = float(cfg.get("hit_grow_px", 24))
                legit = kind == "calc_register"
                trap = "" if legit else str(p.get("trap", "") or "")
                cost = p.get("cost")
                if cost is None:
                    cost = prices.get(kind, {}).get("cost", 3 if kind == "shortcut_door" else 2)
                name = "caja registradora de Calc" if legit else ("atajo con trampa" if trap else "atajo")
                g = gate("pay:" + oid, "pay", oid, "%s %s" % (name, oid), [(x, y + i) for i in range(h)],
                         [_grow(door, grow) + ("%s %s" % (name, oid),)], x, y)
                g.cost = int(cost)
                g.trap = trap
                g.legit = legit or not trap
                g.obj_type = kind
                g.door = door
                g.pose_s = float(cfg.get("pose_s", 0.45))
                g.processing_s = float(cat.get("shortcut_door", {}).get("processing_s", 1.5))
            elif kind == "refund_desk":
                hit = cfg.get("hit_rect", [0, -24, 64, 72])
                x0, y0 = x * T + hit[0], y * T + hit[1]
                self.refunds.append({"id": oid, "cell": (x, y), "pose_s": float(cfg.get("pose_s", 0.45)),
                                     "rect": (x0, y0, x0 + hit[2], y0 + hit[3], "Devoluciones %s" % oid)})
            elif kind == "surprise_box":
                b = cfg.get("box_rect", [4, 8, 56, 56])
                rect = (x * T + b[0], y * T + b[1], x * T + b[0] + b[2], y * T + b[1] + b[3])
                g = gate("box:" + oid, "box", oid, "caja sorpresa %s" % oid, [(x, y)],
                         [rect + ("caja sorpresa %s" % oid,)], x, y)
                g.content = str(p.get("content", "empty"))
                g.amount = int(p.get("amount", 1)) if g.content == "points" else 0
                g.energy = float(cfg.get("energy", 30.0)) if g.content == "energy" else 0.0
            elif kind == "terms_gate":
                h = int(p.get("height_tiles", 3))
                w = float(cfg.get("width_px", 40))
                door = (x * T + (T - w) * 0.5, y * T, x * T + (T + w) * 0.5, (y + h) * T)
                side = str(p.get("side", "left"))
                aw = float(cfg.get("accept_tiles", 3)) * T
                ax = door[0] - aw if side == "left" else door[2]
                accept = (ax, door[3] - T, ax + aw, door[3])
                rs = cfg.get("reject_size_px", [8, 16])
                # En el grafo la puerta ocupa la celda entera: el boton se pega a la cara de la celda (si no, el
                # laser chocaria con la propia celda antes de llegar).
                rx = x * T - float(rs[0]) if side == "left" else (x + 1) * T
                ry = door[1] + float(cfg.get("reject_top_px", 0))
                reject = (rx, ry, rx + float(rs[0]), ry + float(rs[1]))
                cells = [(x, y + i) for i in range(h)]
                g = gate("terms:" + oid, "terms", oid, "Terminos y condiciones %s" % oid, cells,
                         [reject + ("boton rechazar de %s" % oid,)], x, y)
                ga = gate("terms_accept:" + oid, "terms_accept", oid, "boton ACEPTAR de %s" % oid, cells,
                          [accept + ("boton ACEPTAR de %s" % oid,)], x, y)
                g.partner, ga.partner = ga.gid, g.gid
                g.graze = float(cfg.get("edge_graze_px", 4))
                g.side = ga.side = side
            elif kind == "shutter":
                n = int(p.get("length_tiles", 2))
                orient = str(p.get("orientation", "floor"))
                cells = [(x + i, y) for i in range(n)] if orient == "floor" else [(x, y + i) for i in range(n)]
                rect = _cells_rect(T, cells)
                g = gate("shutter:" + oid, "shutter", oid, "persiana %s" % oid, cells,
                         [rect + ("persiana %s" % oid,)], x, y)
                g.orientation = orient
            elif kind == "price_rail":
                inset = float(cfg.get("inset_px", 32))
                w, h = int(p.get("width_tiles", 4)), int(p.get("height_tiles", 4))
                srow = min(max(int(p.get("slot_row", 2)), 0), h - 1)
                rail = (x * T + inset, y * T, x * T + inset + max(w * T - 2 * inset, 8.0), (y + h) * T)
                slot = (rail[0], (y + srow) * T, rail[2], (y + srow + 1) * T)
                tags = []
                if slot[1] > rail[1] + 0.5:
                    tags.append((rail[0], rail[1], rail[2], slot[1], "etiquetas de la ranura %s (empujan)" % oid))
                if rail[3] > slot[3] + 0.5:
                    tags.append((rail[0], slot[3], rail[2], rail[3], "etiquetas de la ranura %s (empujan)" % oid))
                self.rails.append({"id": oid, "cell": (x, y), "rect": rail, "slot": slot, "tags": tags})
            elif kind == "clearance_shelf":
                h = int(p.get("height_tiles", 2))
                group = str(p.get("group", oid))
                shelf_groups.setdefault(group, []).append({"id": oid, "cell": (x, y),
                                                           "cells": [(x, y + i) for i in range(h)],
                                                           "rect": (x * T, y * T, (x + 1) * T, (y + h) * T)})
            elif kind == "countdown_platform" and p.get("trigger"):
                thick = float(cfg.get("card_height_px", 32))
                cells = [(x + i, y) for i in range(int(p.get("width_tiles", 2)))]
                self.static_cards.append({"id": oid, "cells": cells, "thick": thick, "trigger": str(p["trigger"])})
                self.countdowns.append({"id": oid, "trigger": str(p["trigger"]), "cell": (x, y)})
            elif kind == "wishlist_platform":
                wt = int(p.get("width_tiles", 3))
                item_tile = int(p.get("item_tile", -1))
                col = wt * 0.5 if item_tile < 0 else item_tile + 0.5
                fx, fy = x * T + col * T, y * T
                isz = cfg.get("item_size_px", [40, 40])
                item = (fx - isz[0] * 0.5, fy - isz[1], fx + isz[0] * 0.5, fy)
                cx, cy = (item[0] + item[2]) * 0.5, (item[1] + item[3]) * 0.5
                rad = float(p.get("radius_tiles", 6.0)) * T
                hh = float(p.get("height_tiles", 3.0)) * T * 0.5
                wish = {"id": oid, "cell": (x, y), "cells": [(x + i, y) for i in range(wt)], "item_x": fx,
                        "card_y": y * T, "half": float(cfg.get("item_half_width_px", 24.0)),
                        "add_s": float(cfg.get("add_s", 1.5)), "item": item}
                self.wishes.append(wish)
                self.sources.append({"id": oid, "kind": "wishlist_platform", "zone": (cx - rad, cy - hh, cx + rad, cy + hh),
                                     "cx": cx, "strength": float(p.get("strength", 1.0)), "rect": item,
                                     "cell": (x, y), "mount": "floor"})
        for group, items in sorted(shelf_groups.items()):
            cells = [c for it in items for c in it["cells"]]
            g = gate("shelf:" + group, "shelf", group, "estanterias de saldos %s" % group, cells,
                     [it["rect"] + ("estanteria %s" % it["id"],) for it in items], items[0]["cell"][0],
                     items[0]["cell"][1])
            g.shelves = items
        for e in level.get("enemies", []):
            kind = e.get("type")
            x, y = e.get("x", 0), e.get("y", 0)
            p = e.get("params", {}) if isinstance(e.get("params"), dict) else {}
            eid = str(e.get("id", "%s_%d_%d" % (kind, x, y)))
            if kind == "offer_sign":
                d = dict(offer)
                d.update(p)
                mount = str(d.get("mount", "floor"))
                size = d.get("wall_body_size", [56.0, 48.0]) if mount == "wall" else d.get("body_size", [56.0, 64.0])
                fx, fy = (x + 0.5) * T, (y + 1) * T
                body = (fx - size[0] * 0.5, fy - size[1], fx + size[0] * 0.5, fy)
                cx, cy = fx, fy - size[1] * 0.5
                rad = float(d.get("radius_tiles", 5.0)) * T
                hh = float(d.get("height_tiles", 3.0)) * T * 0.5
                self.sources.append({"id": eid, "kind": "offer_sign", "zone": (cx - rad, cy - hh, cx + rad, cy + hh),
                                     "cx": cx, "strength": float(d.get("strength", 1.0)), "rect": body,
                                     "cell": (x, y), "mount": mount, "stun_s": float(d.get("stun_s", 3.0))})
            elif kind == "subscription":
                d = dict(self.sub_data)
                d.update(p)
                self.subs.append({"id": eid, "cell": (x, y), "center": ((x + 0.5) * T, (y + 0.5) * T),
                                  "wake": float(d.get("wake_radius_px", 5 * T)),
                                  "speed": float(d.get("chase_speed_px_s", 90.0))})
        m.gates.extend(self.gates)
        self.combo_gates = [g for g in m.gates if g.kind == "dnd" and g.ability == COMBO_ABILITY]
        for g in self.combo_gates:
            g.w5_label = "«Prueba gratis» %s" % g.obj_id
        self.combo_possible = self.combo_base or bool(self.combo_gates)

    # --- Habilidades ---

    def has_combo(self, state):
        if not self.combo_possible or COMBO_ABILITY in self.m.forbidden:
            return False
        return self.combo_base or any(g.gid in state for g in self.combo_gates)

    def _compress(self, state):
        w3 = self.m.w3
        return w3 is not None and w3.has_compress(state)

    def can_ram(self, state):
        return self.has_combo(state) and self.m.has_dash(state) and self.m.has_pound(state)

    def can_edge(self, state):
        return self.has_combo(state) and self.m.has_dash(state) and self._compress(state)

    def can_quake(self, state):
        return self.has_combo(state) and self.m.has_pound(state) and self._compress(state)

    def costly_gids(self):
        return frozenset(g.gid for g in self.gates if g.kind in COSTLY_KINDS)

    # --- Mundo ---

    def apply_world(self, world, state, debug):
        m = world.m
        rows, cols = m.rows, m.cols
        for g in self.gates:
            if g.kind == "terms_accept":
                continue
            if g.gid in state or (g.kind == "terms" and g.partner in state):
                continue
            for c, r in g.cells:
                if 0 <= r < rows and 0 <= c < cols:
                    world.solid[r][c] = True
                    world.support[r][c] = True
        for rail in self.rails:
            world.hazards.extend(rail["tags"])
        for card in self.static_cards:
            for c, r in card["cells"]:
                if 0 <= r < rows and 0 <= c < cols and not world.solid[r][c]:
                    world.support[r][c] = True
                    world.thin[(c, r)] = card["thick"]

    # --- Puertas ---

    def near(self, gate, node):
        T = self.m.T
        x = (node[0] + 0.5) * T
        if gate.kind == "shelf":
            reach = VIEW_HALF_W_PX + T
        elif gate.kind == "shutter":
            reach = 8 * T
        elif gate.kind in ("terms", "box"):
            reach = max(self.m.rules.laser_range, self.m.rules.pulse_radius) + T
        else:
            reach = self.m.rules.pulse_radius + T
        return any(o[0] - reach <= x <= o[2] + reach for o in gate.openers)

    def can_open(self, gate, node, state, debug=False, use_laser=True):
        m = self.m
        k = gate.kind
        if k == "shelf":
            return is_pinched(node) and debug is not True and self.can_quake(state) and \
                self.quake_info(gate, node, state) is not None
        if k == "terms":
            if is_pinched(node):
                return debug is not True and self.can_edge(state) and self.graze_info(gate, node, state) is not None
            return use_laser and m.has_laser(state) and m.laser_shot(gate.openers[0], node, state, debug) is not None
        if is_pinched(node):
            return False
        if k in ("pay", "terms_accept"):
            return m.has_pulse(state) and m.pulse_hits(gate.openers, node, state, debug)
        if k == "box":
            return self.box_method(gate, node, state, debug, use_laser) is not None
        if k == "shutter":
            return debug is not True and self.can_ram(state) and self.ram_info(gate, node, state) is not None
        return False

    def box_method(self, gate, node, state, debug=False, use_laser=True):
        """Como se abre la caja desde `node`: pulse (de cara, en su fila) o laser (la destruye); None si no se
        puede. El golpe al suelo encima tambien la abre en el juego, pero en el grafo dejaria a Isak sin suelo en la
        celda de encima: el plan no lo usa."""
        m = self.m
        if node[1] == gate.row and m.has_pulse(state) and m.pulse_hits(gate.openers, node, state, debug):
            return "pulse"
        if use_laser and m.has_laser(state) and m.laser_shot(gate.openers[0], node, state, debug) is not None:
            return "laser"
        return None

    def ram_info(self, gate, node, state):
        """Embestida desde `node` cuya onda alcanza la persiana: salto vertical, dash aereo desde el arco (al
        empezar, a mitad o al final del tramo del dash) y caida en diagonal (angle_deg, speed_px_s) hasta el
        suelo; nunca hacia un foso ni a pinchos. Devuelve el detalle o None."""
        key = (gate.gid, node, state)
        if key in self._ram_cache:
            return self._ram_cache[key]
        m = self.m
        rules = m.rules
        T = m.T
        w = m.world(state, False)
        out = None
        c, r = node
        feet = (r + 1) * T
        half = float(self.cfg_ram.get("wave_half_width_px", 128.0))
        above = float(self.cfg_ram.get("wave_height_px", 64.0))
        below = float(self.cfg_ram.get("wave_below_px", 8.0))
        speed = float(self.cfg_ram.get("speed_px_s", 960.0))
        ang = math.radians(float(self.cfg_ram.get("angle_deg", 45.0)))
        target = gate.openers[0][:4]
        # Desde encima de la propia persiana no: rota, Isak se queda sin suelo (el plan sigue desde la celda de
        # despegue).
        if w.is_node(c, r) and (c, r + 1) not in set(gate.cells):
            t_apex = rules.jump_v0 / rules.gravity
            for d in (1, -1):
                if out is not None:
                    break
                for x0 in ((c + 0.5) * T, c * T + m.hw + 1.0, (c + 1) * T - m.hw - 1.0):
                    if out is not None:
                        break
                    arc = {"want_traj": True}
                    w.simulate(x0, feet, -rules.jump_v0, 0.0, x0, head_lag=True, info=arc)
                    traj = arc.get("traj") or []
                    k = int(round(SAMPLE_S / SIM_DT))
                    while k < len(traj) and k * SIM_DT <= t_apex + AFTER_APEX_S + EPS:
                        xa, ya = traj[k]
                        if ya < feet - EPS:
                            xs = w.dash_run(xa, ya, d, air=True)
                            if xs:
                                for j in sorted({0, len(xs) // 2, len(xs) - 1}):
                                    land = self._diagonal(w, xs[j], ya, d, speed, ang)
                                    if land is None:
                                        continue
                                    lx, ly, fall_s = land
                                    wave = (lx - half, ly - above, lx + half, ly + below)
                                    if _rect_hit(wave, target):
                                        out = {"dir": d, "x0": round(x0, 1), "dash_after_s": round(k * SIM_DT, 3),
                                               "dash_frames": j + 1, "dash_y": round(ya, 1),
                                               "land_px": [round(lx, 1), round(ly, 1)],
                                               "seconds": round(k * SIM_DT + (j + 1) * SIM_DT + fall_s +
                                                                float(self.cfg_ram.get("land_pose_s", 0.3)), 3)}
                                        break
                                if out is not None:
                                    break
                        k += int(round(SAMPLE_S / SIM_DT))
        self._ram_cache[key] = out
        return out

    def _diagonal(self, w, x, y, d, speed, ang):
        """Caida de la Embestida desde (x, y): en diagonal hasta tocar suelo (contra una pared, en vertical).
        Devuelve (x, pies, segundos) o None si cae fuera del nivel o toca un peligro."""
        m = self.m
        step = 2.0
        vx, vy = math.cos(ang) * step * d, math.sin(ang) * step
        bottom = m.rows * m.T + m.hh
        dist = 0.0
        for _ in range(20000):
            if w.collides(x, y + 1.0):
                return x, y, dist / speed
            nx, ny = x + vx, y + vy
            if not w.collides(nx, ny):
                x, y = nx, ny
            elif not w.collides(x, ny):
                y = ny
            else:
                ny = y + 1.0
                if w.collides(x, ny):
                    return x, y, dist / speed
                y = ny
            dist += step
            if w.in_hazard(x, y) or y > bottom:
                return None
        return None

    def quake_info(self, gate, node, state):
        """Sismo desde la celda comprimida `node`: salto comprimido (algun cuadro en el aire), caida en vertical
        a la misma celda y onda a ras de su suelo por toda la vista; tumba el grupo si TODAS sus estanterias
        estan en la vista y en esa franja. Devuelve el detalle o None."""
        key = (gate.gid, node, state)
        if key in self._quake_cache:
            return self._quake_cache[key]
        out = None
        m = self.m
        T = m.T
        cm = m.w3.cmodel
        cw = cm.world(state, False)
        c, r = node
        feet = (r + 1) * T
        above = float(self.cfg_quake.get("wave_height_px", 64.0))
        below = float(self.cfg_quake.get("wave_below_px", 8.0))
        if cw.is_node(c, r):
            for x0 in ((c + 0.5) * T, c * T + cm.hw + 1.0, (c + 1) * T - cm.hw - 1.0):
                arc = {"want_traj": True}
                cw.simulate(x0, feet, -cm.rules.jump_v0, 0.0, x0, head_lag=True, info=arc)
                traj = arc.get("traj") or []
                apex = min((y for _, y in traj), default=feet)
                if apex > feet - 4.0:
                    continue  # sin hueco para saltar comprimido
                band = (x0 - VIEW_HALF_W_PX, feet - above, x0 + VIEW_HALF_W_PX, feet + below)
                if all(_rect_hit(band, s["rect"]) for s in gate.shelves):
                    rise = feet - apex
                    drop = float(self.cfg_quake.get("drop_speed_px_s", 960.0))
                    t_up = math.sqrt(2.0 * rise / max(cm.rules.gravity, 1.0))
                    out = {"x_px": round(x0, 1), "apex_px": round(apex, 1),
                           "seconds": round(t_up + rise / drop + float(self.cfg_quake.get("land_pose_s", 0.35)), 3)}
                    break
        self._quake_cache[key] = out
        return out

    def quake_view_missing(self, gate, node, state):
        """Estanterias del grupo fuera de la vista o de la planta desde la celda comprimida `node`."""
        T = self.m.T
        x0, feet = (node[0] + 0.5) * T, (node[1] + 1) * T
        band = (x0 - VIEW_HALF_W_PX, feet - float(self.cfg_quake.get("wave_height_px", 64.0)),
                x0 + VIEW_HALF_W_PX, feet + float(self.cfg_quake.get("wave_below_px", 8.0)))
        return [s["id"] for s in gate.shelves if not _rect_hit(band, s["rect"])]

    # --- Filo ---

    def _filo_sweeps(self, node, state):
        """Filos desde la celda comprimida `node`: [(x0, jump_speed, k, xs, y, dir, pre)] (salto comprimido en el
        sitio o andando, Filo desde el arco cada SAMPLE_S hasta la cumbre + AFTER_APEX_S)."""
        m = self.m
        T = m.T
        cm = m.w3.cmodel
        cw = cm.world(state, False)
        c, r = node
        if not cw.is_node(c, r):
            return []
        feet = (r + 1) * T
        dist = float(self.cfg_edge.get("distance_px", 256.0))
        frames = max(1, int(round(float(self.cfg_edge.get("duration_s", 0.22)) / SIM_DT)))
        stepx = dist / frames
        t_apex = cm.rules.jump_v0 / max(cm.rules.gravity, 1.0)
        out = []
        for d in (1, -1):
            edge_x = (c + 1) * T if d > 0 else c * T
            starts = [(c + 0.5) * T]
            if not cw.collides(edge_x, feet):
                starts.append(edge_x)
            for jspeed in (0.0, cm.rules.walk_speed):
                for x0 in starts:
                    arc = {"want_traj": True}
                    xt = x0 + d * 1e6 if jspeed > 0.0 else x0
                    cw.simulate(x0, feet, -cm.rules.jump_v0, jspeed, xt, head_lag=True, info=arc)
                    traj = arc.get("traj") or []
                    k = int(round(SAMPLE_S / SIM_DT))
                    while k < len(traj) and k * SIM_DT <= t_apex + AFTER_APEX_S + EPS:
                        xa, ya = traj[k]
                        if ya < feet - EPS:
                            xs = []
                            x = xa
                            ok = True
                            for _ in range(frames):
                                nx = x + d * stepx
                                if cw.collides(nx, ya):
                                    if d > 0:
                                        cand = math.floor((nx + cm.hw - EPS) / T) * T - cm.hw
                                    else:
                                        cand = (math.floor((nx - cm.hw) / T) + 1) * T + cm.hw
                                    if (cand - x) * d > EPS and not cw.collides(cand, ya):
                                        xs.append(cand)
                                    break
                                x = nx
                                if cw.in_hazard(x, ya):
                                    ok = False
                                    break
                                xs.append(x)
                            if ok and xs:
                                out.append((x0, jspeed, k, xs, ya, d, list(traj[:k])))
                        k += int(round(SAMPLE_S / SIM_DT))
        return out

    def pinched_combo_edges(self, node, state, debug):
        """Aristas del Filo desde una celda comprimida (solo con combo, el dash y Pellizcar; nunca con el Debug):
        tras el tramo del Filo Isak sigue comprimido a end_speed_px_s y cae hasta una celda comprimida."""
        if debug is True or not self.can_edge(state):
            return []
        m = self.m
        key = (node, m.local_key(node, state), self.disabled_rails)
        if key in self._edge_cache:
            return self._edge_cache[key]
        T = m.T
        cm = m.w3.cmodel
        cw = cm.world(state, False)
        from world3_model import Pinched
        best = {}
        feet = (node[1] + 1) * T
        dist = float(self.cfg_edge.get("distance_px", 256.0))
        end_speed = float(self.cfg_edge.get("end_speed_px_s", 160.0))
        for x0, jspeed, k, xs, ya, d, pre in self._filo_sweeps(node, state):
            x1 = xs[-1]
            if self.disabled_rails and any(rail["id"] in self.disabled_rails and self._crosses(rail, xs[0], x1, ya)
                                           for rail in self.rails):
                continue
            for xt in (None, x1):
                sim = {"want_traj": True}
                to, _ = cw.simulate(x1 + d * EPS * 10, ya, 0.0, end_speed, x1 + d * 1e6 if xt is None else xt,
                                    info=sim)
                if to is None or to == (node[0], node[1]):
                    continue
                rise = feet - (to[1] + 1) * T
                travel = abs(((to[0] + 0.5) * T) - x0)
                # Exigencia horizontal: lo que hay que recorrer en el aire ademas del tramo fijo del Filo, frente al
                # alcance del salto comprimido andando.
                reach = cm.rules.reach(max(rise, 0.0), cm.rules.walk_speed)
                extra = max(0.0, travel - dist - T * 0.5)
                h = min(extra / reach, 1.0) if reach > EPS else 0.0
                v = max(0.0, rise) / max(cm.rules.jump_height, 1.0)
                if rise > cm.rules.jump_height + EPS:
                    continue
                e = {"to": Pinched(to), "kind": "combo_edge", "h": h, "v": v, "x0": x0, "travel": travel,
                     "rise": rise, "speed": "walk", "xt": x0 + d * 1e6 if jspeed > 0.0 else x0,
                     "vy0": -cm.rules.jump_v0, "time": k * SIM_DT + len(xs) * SIM_DT + sim.get("time", 0.0),
                     "land_x": sim.get("land_x"), "pinched": True, "walk_px_s": cm.rules.walk_speed,
                     "combo": "edge", "energy_cost": self.combo_cost,
                     "rails": [rl["id"] for rl in self.rails if self._crosses(rl, xs[0], x1, ya)],
                     "dash": {"dir": d, "air": True, "xs": xs, "y": ya, "pre": pre, "x_start": pre[-1][0] if pre else x0,
                              "after_s": k * SIM_DT, "jump_speed": jspeed, "fall": list(sim.get("traj") or []),
                              "fall_xt": xt}}
                kk = (e["to"], "combo_edge")
                old = best.get(kk)
                if old is None or (round(max(h, v), 6), round(e["time"], 6)) < (round(max(old["h"], old["v"]), 6),
                                                                               round(old["time"], 6)):
                    best[kk] = e
        out = list(best.values())
        self._edge_cache[key] = out
        return out

    def _crosses(self, rail, xa, xb, y):
        lo, hi = min(xa, xb), max(xa, xb)
        r = rail["rect"]
        return lo < r[2] and hi > r[0] and r[1] <= y <= r[3] + EPS

    def graze_info(self, gate, node, state):
        """Filo desde la celda comprimida `node` cuya caja roza el boton «rechazar» (grow edge_graze_px)."""
        key = (gate.gid, node, state)
        if key in self._graze_cache:
            return self._graze_cache[key]
        out = None
        cm = self.m.w3.cmodel
        target = _grow(gate.openers[0][:4], gate.graze)
        # Atajo (paso 14, mismo resultado): un Filo no llega mas lejos que su tramo (distance_px) mas el arco del salto
        # comprimido (andando, hasta la cumbre + AFTER_APEX_S) desde cualquier punto de la celda; sin barrer
        # (_filo_sweeps simula cada salto) si el boton queda fuera de ese alcance.
        T = self.m.T
        t_air = cm.rules.jump_v0 / max(cm.rules.gravity, 1.0) + AFTER_APEX_S + SAMPLE_S
        reach = float(self.cfg_edge.get("distance_px", 256.0)) + cm.rules.walk_speed * t_air + cm.hw + T
        c, r = node
        if target[0] > (c + 1) * T + reach or target[2] < c * T - reach or \
                target[3] < (r + 1) * T - cm.rules.jump_height - cm.hh - T or target[1] > (r + 1) * T + T:
            self._graze_cache[key] = None
            return None
        for x0, jspeed, k, xs, ya, d, pre in self._filo_sweeps(node, state):
            xa = pre[-1][0] if pre else x0
            box = (min(xa, xs[-1]) - cm.hw, ya - cm.hh, max(xa, xs[-1]) + cm.hw, ya)
            if _rect_hit(box, target):
                out = {"x0": round(x0, 1), "dir": d, "jump_speed": jspeed, "edge_after_s": round(k * SIM_DT, 3),
                       "y_px": round(ya, 1), "seconds": round(k * SIM_DT + len(xs) * SIM_DT, 3)}
                break
        self._graze_cache[key] = out
        return out

    # --- Tentacion ---

    def weight(self, px, py, stunned=()):
        dead = float(self.field.get("dead_zone_px", 4.0))
        w = 0.0
        ids = []
        for s in self.sources:
            if s["id"] in stunned:
                continue
            z = s["zone"]
            if not (z[0] <= px <= z[2] and z[1] <= py <= z[3]):
                continue
            dx = s["cx"] - px
            if abs(dx) < dead:
                continue
            w += s["strength"] if dx > 0 else -s["strength"]
            ids.append(s["id"])
        return w, ids

    def pull(self, w):
        """(deriva px/s, multiplicador al alejarse, al acercarse) para un peso con signo (§3.3, decision 3 del
        paso 2)."""
        f = self.field
        a = abs(w)
        drift = min(a * float(f.get("drift_px_s", 60.0)), float(f.get("drift_cap_px_s", 90.0)))
        away = max(1.0 - (1.0 - float(f.get("away_mult", 0.6))) * a, float(f.get("away_min_mult", 0.45)))
        cap_w = float(f.get("drift_cap_px_s", 90.0)) / max(float(f.get("drift_px_s", 60.0)), 1.0)
        toward = 1.0 + (float(f.get("toward_mult", 1.15)) - 1.0) * min(a, cap_w)
        return drift, away, toward

    def _drift_from(self, w, node):
        """Quieto en `node`: Isak deriva hacia la Oferta hasta quedarse encima (zona muerta), contra una pared o
        en otra celda. Devuelve None (bien) o el motivo si acaba en un foso mortal."""
        m = self.m
        T = m.T
        x, feet = (node[0] + 0.5) * T, (node[1] + 1) * T
        for _ in range(4):
            for _ in range(4000):
                wt, _ids = self.weight(x, feet - m.hh * 0.5)
                if abs(wt) < EPS:
                    return None
                d = 1.0 if wt > 0 else -1.0
                nx = x + d * 2.0
                if w.collides(nx, feet):
                    return None
                x = nx
                c0 = int(math.floor((x - m.hw + 1.0) / T))
                c1 = int(math.floor((x + m.hw - 1.0) / T))
                r = int(math.floor((feet + 1.0) / T))
                if not (w.is_support(c0, r) or w.is_support(c1, r)):
                    break
            else:
                return None
            drift, _a, _t = self.pull(wt)
            to, why = w.simulate(x, feet, 0.0, drift, x + d * 1e6)
            if to is None:
                if why and "fuera del nivel" in why:
                    return why
                return None
            x, feet = (to[0] + 0.5) * T, (to[1] + 1) * T
        return None

    # --- Comprobaciones sin tiempo ---

    def check(self, validator, start, goal_cells):
        rep = validator.report
        m = self.m
        T = m.T
        info = {"economy": {}, "combo": {"possible": self.combo_possible}, "obstacles": [], "boxes": [],
                "temptation": {"sources": len(self.sources)}, "terms": [], "shelf_rule": []}
        validator.result["world5"] = info
        econ = self.economy
        max_spend = int(econ.get("max_spend_per_level", 11))
        priced = [("tienda", s["id"], s["cost"]) for s in self.shops] + \
                 [("caja registradora de Calc" if g.obj_type == "calc_register" else "atajo", g.obj_id, g.cost)
                  for g in self.gates if g.kind == "pay"]
        total = sum(c for _, _, c in priced)
        info["economy"].update({"priced": len(priced), "total": total, "max_spend_per_level": max_spend})
        if priced and total > max_spend:
            rep.error("economia: comprarlo todo en el nivel cuesta %d y el maximo es %d (max_spend_per_level de "
                      "data/economy.json)" % (total, max_spend))
        # Combinacion: obstaculos sin combo posible.
        names = {"shutter": "la Embestida", "shelf": "el Sismo"}
        for g in self.gates:
            if g.kind in names and not self.combo_possible:
                rep.error("%s solo lo abre %s y el nivel no tiene la Combinacion (ni abilities_available.combo ni "
                          "una «Prueba gratis»)" % (g.label(), names[g.kind]), g.row, g.col, g.label())
        for rail in self.rails:
            if not self.combo_possible:
                rep.error("ranura de precios %s: solo la cruza el Filo y el nivel no tiene la Combinacion"
                          % rail["id"], rail["cell"][1], rail["cell"][0], rail["id"])
        self._check_shelf_rule(rep, info)
        main = getattr(validator, "main", None)
        if main is None or not main.get("ok"):
            costly = self.costly_gids()
            if costly:
                forbid = frozenset(g for g in validator.secret_gates() if g not in costly)
                paid = validator.progression(start, frozenset(), validator.rules.limit, forbid=forbid,
                                             targets=goal_cells)
                if paid["ok"]:
                    used = [st["gate"].label() for st in paid["stages"] if st["gate"] is not None
                            and st["gate"].gid in costly]
                    rep.error("arista obligatoria con precio: la meta solo se alcanza pagando (%s); el camino largo "
                              "tiene que existir" % ", ".join(used))
            return
        final_state = main["stages"][-1]["state"]
        self._check_economy(validator, start, final_state, info)
        self._check_temptation(validator, main, info)
        self._check_boxes(validator, main, info)
        self._check_obstacles(validator, start, goal_cells, main, info)
        for st in main["stages"]:
            g = st["gate"]
            if g is not None and g.kind == "terms":
                via = "Filo" if is_pinched(st["end"]) else "laser"
                info["terms"].append({"id": g.obj_id, "via": via, "at": [st["end"][1], st["end"][0]]})

    def _check_shelf_rule(self, rep, info):
        """Ningun golpe suelto (golpe al suelo, Embestida o pulso, el mayor alcance) llega a dos estanterias del
        mismo grupo: si no, un grupo de dos caeria sin el Sismo (pendiente del paso 6)."""
        rules = self.m.rules
        waves = [("Embestida", 2.0 * float(self.cfg_ram.get("wave_half_width_px", 128.0)),
                  float(self.cfg_ram.get("wave_height_px", 64.0)) + float(self.cfg_ram.get("wave_below_px", 8.0))),
                 ("golpe al suelo", 2.0 * rules.pound_half_width, rules.pound_height + rules.pound_below)]
        for g in self.gates:
            if g.kind != "shelf":
                continue
            entry = {"group": g.obj_id, "shelves": len(g.shelves), "ok": True}
            info["shelf_rule"].append(entry)
            items = g.shelves
            for i in range(len(items)):
                for j in range(i + 1, len(items)):
                    a, b = items[i]["rect"], items[j]["rect"]
                    gx, gy = _gap(a, b)
                    hit = [name for name, ww, hh in waves if gx < ww - EPS and gy < hh - EPS]
                    if math.hypot(gx, gy) < 2.0 * rules.pulse_radius - EPS:
                        hit.append("pulso")
                    if hit:
                        entry["ok"] = False
                        rep.error("estanterias de saldos %s: un solo golpe (%s) alcanza a la vez a %s y %s (se "
                                  "separan %.0f px; hace falta al menos %.0f para que solo las tumbe el Sismo)"
                                  % (g.obj_id, ", ".join(hit), items[i]["id"], items[j]["id"], gx,
                                     max(max(ww for _, ww, _h in waves), 2.0 * rules.pulse_radius)),
                                  items[j]["cell"][1], items[j]["cell"][0], items[j]["id"])

    def _times(self, start, state):
        times, _parent = self.m.time_search({start: 0.0}, state, dash=True)
        return times

    def _check_economy(self, validator, start, state, info):
        """Cada cosa que se vende cuesta como mucho los puntos que hay antes en la ruta (desde un saldo de 0):
        los de las celdas 'o' que Isak toca antes (por tiempo, sin pagar nada; con una celda de tolerancia) que la celda
        desde la que la compra."""
        m = self.m
        rep = validator.report
        costly = self.costly_gids()
        st = frozenset(g for g in state if g not in costly)
        times = self._times(start, st)
        point_t = {}
        for n, t in times.items():
            for cell in ({(n[0], n[1])} if is_pinched(n) else {(n[0], n[1]), (n[0], n[1] - 1)}):
                if cell in self.points and t < point_t.get(cell, float("inf")):
                    point_t[cell] = t
        items = []
        for s in self.shops:
            items.append(("tienda", s["id"], s["cost"], [s["rect"]], s["cell"]))
        for g in self.gates:
            if g.kind == "pay":
                items.append(("caja registradora de Calc" if g.obj_type == "calc_register" else
                              ("atajo con trampa" if g.trap else "atajo"), g.obj_id, g.cost, g.openers, (g.col, g.row)))
        out = []
        for what, oid, cost, rects, cell in items:
            use = [t for n, t in times.items() if not is_pinched(n) and m.pulse_hits(rects, n, st)]
            if not use:
                rep.warning("%s %s: no se alcanza para pagar desde ningun sitio" % (what, oid), cell[1], cell[0], oid)
                out.append({"what": what, "id": oid, "cost": cost, "reachable": False})
                continue
            t_use = min(use)
            # Tolerancia de una celda andando: Isak al borde de la celda de compra ya toca la del punto de al lado.
            tol = m.T / max(m.rules.walk_speed, 1.0)
            before = sum(1 for t in point_t.values() if t <= t_use + tol + EPS)
            out.append({"what": what, "id": oid, "cost": cost, "points_before": before, "reachable": True})
            if cost > before:
                rep.error("economia: %s %s cuesta %d y antes en la ruta solo hay %d punto(s) (desde un saldo de 0: "
                          "impagable para quien lo gasto todo en Calc)" % (what, oid, cost, before), cell[1], cell[0], oid)
        info["economy"]["items"] = out
        info["economy"]["points"] = len(self.points)

    def _check_temptation(self, validator, main, info):
        """Quieto en cualquier celda (del camino alcanzable) dentro de una zona de tentacion nunca acaba en un foso
        mortal, y alejarse andando siempre avanza (andar x multiplicador - deriva > 0)."""
        if not self.sources:
            return
        m = self.m
        rep = validator.report
        rules = m.rules
        state = main["stages"][-1]["state"]
        w = m.world(state, False)
        reached = set()
        for st in main["stages"]:
            reached |= {n for n in st["cost"] if not is_pinched(n)}
        worst = None
        bad = set()
        for n in sorted(reached, key=lambda n: (n[1], n[0])):
            x, feet = (n[0] + 0.5) * m.T, (n[1] + 1) * m.T
            wt, ids = self.weight(x, feet - m.hh * 0.5)
            if not ids:
                continue
            drift, away, _t = self.pull(wt)
            v = rules.walk_speed * away - drift
            worst = v if worst is None else min(worst, v)
            if v <= EPS and "slow" not in bad:
                bad.add("slow")
                rep.error("tentacion: en (fila %d, columna %d) alejarse andando no avanza (%.0f px/s): siempre tiene "
                          "que haber salida" % (n[1], n[0], v), n[1], n[0], ids[0])
            why = self._drift_from(w, n)
            if why and ids[0] not in bad:
                bad.add(ids[0])
                rep.error("tentacion: quieto en (fila %d, columna %d), %s arrastra a Isak a un foso mortal (%s): la "
                          "tentacion engaña, no mata" % (n[1], n[0], ", ".join(ids), why), n[1], n[0], ids[0])
        info["temptation"]["min_escape_px_s"] = None if worst is None else round(worst, 1)

    def _check_boxes(self, validator, main, info):
        """Cajas que tapan el camino: sin aviso (el Debug) no pueden esconder nada que dañe; orden seguro con la
        energia: mirar dentro de cada caja peligrosa cuesta LOOK_S de Debug (y el laser, si la destruye) y las de
        energia la devuelven."""
        m = self.m
        rep = validator.report
        rules = m.rules
        opened = [(st["gate"], st["state"], st["end"]) for st in main["stages"]
                  if st["gate"] is not None and st["gate"].kind == "box"]
        for g in self.gates:
            if g.kind == "box":
                entry = {"id": g.obj_id, "content": g.content,
                         "blocks_path": any(o[0] is g for o in opened)}
                info["boxes"].append(entry)
        drain = rules.debug_drain * float(m.level.get("debug_drain_scale", 1.0))
        energy = float(m.validation.get("start_energy", rules.energy_max))
        cap = rules.energy_max
        look = LOOK_S * drain
        harmful = []
        for g, state, node in opened:
            if g.content in SAFE_CONTENT:
                continue
            if not m.has_debug(state):
                rep.error("caja sorpresa %s tapa el camino y esconde %s sin aviso (sin el Debug no se ve lo que hay "
                          "dentro)" % (g.obj_id, g.content), g.row, g.col, g.label())
            harmful.append(g)
        # Orden seguro (el mejor: las de energia primero).
        for g, _s, _n in opened:
            if g.content == "energy":
                energy = min(cap, energy + g.energy)
        for g in harmful:
            need = look + (rules.laser_cost if m.laser_possible else 0.0)
            if energy + EPS < need:
                rep.error("cajas en cadena sin orden seguro: no queda energia para mirar %s con el Debug (quedan %.0f, "
                          "hacen falta %.0f)" % (g.label(), energy, need), g.row, g.col, g.label())
                break
            energy -= need
        info["boxes_energy_left"] = round(energy, 1)

    def _check_obstacles(self, validator, start, goal_cells, main, info):
        """Anti-redundancia (§3.9): cada persiana y grupo de estanterias que abre el camino, y cada ranura que cruza
        con un Filo, hace falta: sin ese obstaculo (sin su combo) la meta no se alcanza. Los que el camino no usa y
        no son de un secreto (su id en `gates`), error: se rodean sin su combo."""
        m = self.m
        rep = validator.report
        used_gates = {st["gate"].gid for st in main["stages"] if st["gate"] is not None}
        used_rails = set()
        for st in main["stages"]:
            for _u, e in _path(st["parent"], st["end"]):
                used_rails.update(e.get("rails", []) if e.get("combo") == "edge" else [])
        secret = validator.secret_gates()
        secret_ids = set()
        for s in m.level.get("secrets", []):
            secret_ids.update(str(i) for i in s.get("gates", []))
        limit = validator.rules.limit
        for g in self.gates:
            if g.kind not in ("shutter", "shelf"):
                continue
            entry = {"id": g.obj_id, "kind": g.kind, "used": g.gid in used_gates}
            info["obstacles"].append(entry)
            if g.gid not in used_gates:
                if g.gid not in secret and self.combo_possible:
                    rep.error("%s: el camino principal no lo usa: se rodea sin su combo (§3.9; si es de un secreto, "
                              "va en sus `gates`)" % g.label(), g.row, g.col, g.label())
                continue
            run = validator.progression(start, frozenset(), limit, forbid=validator.secret_gates() | {g.gid},
                                        targets=goal_cells)
            entry["required"] = not run["ok"]
            if run["ok"]:
                rep.error("%s no exige %s: sin abrirla tambien se llega a la meta (§3.9)"
                          % (g.label(), "la Embestida" if g.kind == "shutter" else "el Sismo"), g.row, g.col, g.label())
        for rail in self.rails:
            entry = {"id": rail["id"], "kind": "price_rail", "used": rail["id"] in used_rails}
            info["obstacles"].append(entry)
            if rail["id"] not in used_rails:
                if rail["id"] not in secret_ids and self.combo_possible:
                    rep.error("ranura de precios %s: el camino principal no la cruza con un Filo: se rodea sin el (§3.9; "
                              "si es de un secreto, va en sus `gates`)" % rail["id"], rail["cell"][1], rail["cell"][0],
                              rail["id"])
                continue
            saved = (self.disabled_rails, self._edge_cache, m._edges)
            self.disabled_rails = frozenset({rail["id"]})
            self._edge_cache, m._edges = {}, {}
            try:
                run = validator.progression(start, frozenset(), limit, forbid=validator.secret_gates(),
                                            targets=goal_cells)
            finally:
                self.disabled_rails, self._edge_cache, m._edges = saved
            entry["required"] = not run["ok"]
            if run["ok"]:
                rep.error("ranura de precios %s no exige el Filo: sin cruzarla con el se llega a la meta (§3.9)"
                          % rail["id"], rail["cell"][1], rail["cell"][0], rail["id"])

    # --- Pasos del plan ---

    def gate_steps(self, planner, g, n, state):
        m = self.m
        tgt = {"type": {"pay": getattr(g, "obj_type", "shortcut_door"), "box": "surprise_box", "terms": "terms_gate",
                        "terms_accept": "terms_gate", "shutter": "shutter", "shelf": "clearance_shelf"}[g.kind],
               "id": g.obj_id}
        if g.kind == "pay":
            return [{"action": "pay_door", "at": n, "shot": m.pulse_shot(g.openers, n, state), "state": state,
                     "face_back": True, "pose_s": g.pose_s, "cost": g.cost, "trap": g.trap, "target": tgt}]
        if g.kind == "terms_accept":
            return [{"action": "pulse", "at": n, "shot": m.pulse_shot(g.openers, n, state), "state": state,
                     "target": dict(tgt, button="accept"), "hooks": "subscription"}]
        if g.kind == "terms":
            if is_pinched(n):
                gi = self.graze_info(g, n, state)
                return [{"action": "reject_terms", "at": n, "state": state, "via": "combo_edge", "graze": gi,
                         "energy_w5": self.combo_cost, "seconds": gi["seconds"] if gi else 0.3,
                         "target": dict(tgt, button="reject")}]
            shot = m.laser_shot(g.openers[0], n, state)
            return [{"action": "reject_terms", "at": n, "state": state, "via": "laser", "shot": shot,
                     "energy_w5": m.rules.laser_cost, "target": dict(tgt, button="reject")}]
        if g.kind == "box":
            how = self.box_method(g, n, state)
            steps = []
            look = g.content not in SAFE_CONTENT and m.has_debug(state)
            # Lo que el Debug ensena que dana (Suscripcion u Oferta) se destruye con el laser, sin abrirla: es lo que
            # ya cuenta el orden seguro de _check_boxes (mirar + laser). Abrirla con el pulso la soltaria (paso 14).
            # El laser solo sale limpio desde cerca de la caja (desde mas lejos choca con su celda): se busca la celda
            # de la misma fila mas cercana, yendo hacia ella, desde la que el disparo la alcanza.
            if look and how == "pulse" and m.has_laser(state):
                d = 1 if g.col > n[0] else -1
                for c in range(n[0], g.col, d):
                    if m.laser_shot(g.openers[0], (c, n[1]), state) is not None:
                        how, n = "laser", (c, n[1])
                        break
            if look:
                steps.append({"action": "debug_on", "at": n, "state": state, "reason": "mirar dentro de %s" % g.obj_id,
                              "target": tgt})
                steps.append({"action": "wait", "at": n, "seconds": LOOK_S, "state": state,
                              "reason": "el Debug ensena el contenido de %s" % g.obj_id, "target": tgt})
                steps.append({"action": "debug_off", "at": n, "state": state})
            if how == "laser":
                shot = m.laser_shot(g.openers[0], n, state)
            elif how == "pulse":
                shot = m.pulse_shot(g.openers, n, state)
            else:
                shot = {"x": m.pound_x(g, n, state, False), "facing": 1}
            steps.append({"action": "open_box", "at": n, "state": state, "with": how, "content": g.content,
                          "amount": g.amount, "looked": look, "shot": shot,
                          "energy_w5": m.rules.laser_cost if how == "laser" else 0.0, "target": tgt})
            return steps
        if g.kind == "shutter":
            info = self.ram_info(g, n, state)
            # La Embestida sale de un dash aereo, que cobra su energia al salir: combo + dash (el bot del 5-2 lo midio).
            return [{"action": "combo_ram", "at": n, "state": state, "ram": info,
                     "energy_w5": self.combo_cost + m.rules.dash_cost,
                     "seconds": info["seconds"] if info else 0.5, "breaks": [g.obj_id], "target": tgt}]
        if g.kind == "shelf":
            info = self.quake_info(g, n, state)
            return [{"action": "combo_quake", "at": n, "state": state, "quake": info, "energy_w5": self.combo_cost,
                     "seconds": info["seconds"] if info else 0.5, "breaks": [s["id"] for s in g.shelves],
                     "target": dict(tgt, group=g.obj_id)}]
        return []

    def duration(self, planner, s):
        r = planner.rules
        a = s["action"]
        if a in ("buy", "pay_door", "refund"):
            return max(r.pulse_pose_s, s.get("pose_s", 0.0)) + SIM_DT
        if a == "cancel_subscription":
            return r.pulse_pose_s
        if a == "open_box":
            return {"laser": r.laser_pose_s, "pulse": r.pulse_pose_s}.get(s.get("with"), r.pound_s)
        if a == "reject_terms":
            return r.laser_pose_s if s.get("via") == "laser" else s.get("seconds", 0.3)
        if a in ("combo_ram", "combo_quake", "wait_countdown"):
            return s.get("seconds", 0.0)
        return 0.0

    def plan(self, planner, steps):
        """Pasos del Mundo 5 sobre el camino: (comprador) pagar los atajos que cruza, comprar y Devoluciones;
        tentacion (resist_pull y pulsos si un salto no llega), Suscripciones, lista de deseos, cuentas y saldo."""
        info = planner.v.result.setdefault("world5", {})
        buy = getattr(planner, "w5_buy", False)
        if buy:
            info = info.setdefault("buy", {})
        if buy:
            steps = self._plan_buy(planner, steps, info)
        steps = self._plan_temptation(planner, steps, info)
        steps = self._plan_subscriptions(planner, steps, info)
        self._plan_wishes(planner, steps, info)
        for s in steps:
            if s["action"] == "wait_beat" and str(s.get("beat", {}).get("rhythm", "")).startswith("_cd_"):
                s["action"] = "wait_countdown"
                s["countdown"] = s["beat"]["rhythm"][4:]
        self._ledger(planner, steps, info, buy)
        return steps

    def _crossing(self, planner, s, rect):
        if s["action"] != "move":
            return False
        m = self.m
        for x, feet, _air in planner.samples(s):
            if _rect_hit((x - m.hw, feet - m.hh, x + m.hw, feet), rect):
                return True
        return False

    def _plan_buy(self, planner, steps, info):
        m = self.m
        out = []
        paid = set()
        bought = set()
        pending_trap = []
        balance = 0
        taken = set()
        # Lo que cuestan los atajos que el camino cruza (el comprador lo reserva antes de comprar en las tiendas).
        crossed = [g for g in self.gates if g.kind == "pay" and any(self._crossing(planner, st, g.door) for st in steps)]
        reserve = sum(g.cost for g in crossed)
        for i, s in enumerate(steps):
            if s["action"] == "move":
                for g in self.gates:
                    if g.kind != "pay" or g.gid in paid or not self._crossing(planner, s, g.door):
                        continue
                    paid.add(g.gid)
                    cands = [s["from"]] + [p["from"] for p in reversed(out[-8:]) if p["action"] == "move"]
                    node = next((c for c in cands if not is_pinched(c) and m.has_pulse(s["state"])
                                 and m.pulse_hits(g.openers, c, s["state"])), None)
                    if node is None:
                        planner.error("%s no se puede pagar antes de cruzarla" % g.label(), s["from"], g.obj_id)
                        continue
                    out.append({"action": "pay_door", "at": node, "shot": m.pulse_shot(g.openers, node, s["state"]),
                                "state": s["state"], "face_back": True, "pose_s": g.pose_s, "cost": g.cost,
                                "trap": g.trap, "target": {"type": g.obj_type, "id": g.obj_id}})
                    balance -= g.cost
                    reserve -= g.cost if g in crossed else 0
                    if g.trap:
                        pending_trap.append(g)
            out.append(s)
            if s["action"] == "move":
                for n in (s["from"], s["to"]):
                    for c in ({(n[0], n[1])} if is_pinched(n) else {(n[0], n[1]), (n[0], n[1] - 1)}) & self.points:
                        if c not in taken:
                            taken.add(c)
                            balance += 1
                while pending_trap and self._crossing(planner, s, pending_trap[0].door):
                    g = pending_trap.pop(0)
                    if g.trap == "processing":
                        out.append({"action": "wait", "at": s["to"], "seconds": g.processing_s, "state": s["state"],
                                    "reason": "trampa processing de %s: «Verificando pago…» (congelado y golpe al "
                                              "liberarse)" % g.obj_id, "target": {"type": g.obj_type, "id": g.obj_id}})
                    elif g.trap == "subscription":
                        out.append({"action": "cancel_subscription", "at": s["to"], "state": s["state"],
                                    "shot": {"x": (s["to"][0] + 0.5) * m.T, "facing": 1},
                                    "target": {"type": "subscription", "id": "trampa:" + g.obj_id}})
                to = s["to"]
                if is_pinched(to):
                    continue
                for shop in self.shops:
                    if shop["id"] not in bought and balance - reserve >= shop["cost"] and m.has_pulse(s["state"]) and \
                            m.pulse_hits([shop["rect"]], to, s["state"]):
                        bought.add(shop["id"])
                        balance -= shop["cost"]
                        out.append({"action": "buy", "at": to, "shot": m.pulse_shot([shop["rect"]], to, s["state"]),
                                    "state": s["state"], "face_back": True, "pose_s": shop["pose_s"],
                                    "cost": shop["cost"], "product": shop["product"],
                                    "target": {"type": "shop_item", "id": shop["id"]}})
                for desk in self.refunds:
                    if desk["id"] not in bought and paid and m.has_pulse(s["state"]) and \
                            m.pulse_hits([desk["rect"]], to, s["state"]):
                        bought.add(desk["id"])
                        out.append({"action": "refund", "at": to, "shot": m.pulse_shot([desk["rect"]], to, s["state"]),
                                    "state": s["state"], "face_back": True, "pose_s": desk["pose_s"],
                                    "target": {"type": "refund_desk", "id": desk["id"]}})
        return out

    def _plan_temptation(self, planner, steps, info):
        if not self.sources:
            return steps
        m = self.m
        rules = m.rules
        out = []
        stunned = {}
        resist = []
        stuns = []
        planner.timeline(steps)
        for s in steps:
            tw = s.get("tw", 0.0)
            active = {k for k, until in stunned.items() if tw < until}
            if s["action"] == "move" and not s["edge"].get("dash"):
                e = s["edge"]
                u, v = planner.feet(s["from"]), planner.feet(s["to"])
                mx = (u[0] + v[0]) * 0.5
                wt, ids = self.weight(mx, (u[1] + v[1]) * 0.5 - m.hh * 0.5, active)
                if ids and abs(v[0] - u[0]) > EPS:
                    d = 1.0 if v[0] > u[0] else -1.0
                    drift, away, toward = self.pull(wt)
                    base = e.get("walk_px_s") or rules.walk_speed
                    if d * wt > 0:
                        speed = base * toward + drift
                    else:
                        speed = base * away - drift
                    if e["kind"] == "walk":
                        if speed <= EPS:
                            planner.error("tentacion: alejarse andando de %s no avanza" % ", ".join(ids), s["to"], ids[0])
                        else:
                            s["walk_speed"] = speed
                            if d * wt < 0:
                                s["resist"] = {"sources": ids, "weight": round(wt, 3), "walk_speed_px_s": round(speed, 1)}
                                resist.append(ids[0])
                    elif d * wt < 0 and e.get("time", 0.0) > EPS:
                        need = abs(e.get("land_x", v[0]) - e["x0"]) / max(planner.air_time(s), EPS)
                        jspeed = rules.walk_speed if e.get("speed") == "walk" else rules.run_speed
                        if e.get("pinched"):
                            jspeed = e.get("walk_px_s") or jspeed
                        avail = jspeed * away - drift
                        if need > avail + EPS:
                            src = next((x for x in self.sources if x["id"] in ids and x["kind"] == "offer_sign"), None)
                            shot = None
                            if src is not None and not is_pinched(s["from"]) and m.has_pulse(s["state"]):
                                shot = m.pulse_shot([src["rect"] + (src["id"],)], s["from"], s["state"])
                            if shot is None:
                                planner.error("tentacion: %s impide el salto de (fila %d, columna %d) a (fila %d, "
                                              "columna %d): hacen falta %.0f px/s y contra el tiron hay %.0f (aturdela "
                                              "con el pulso o usa el dash)" % (", ".join(ids), s["from"][1],
                                                                               s["from"][0], s["to"][1], s["to"][0],
                                                                               need, avail), s["from"], ids[0])
                            else:
                                out.append({"action": "pulse", "at": s["from"], "shot": shot, "state": s["state"],
                                            "reason": "apagar el tiron de %s" % src["id"],
                                            "target": {"type": "offer_sign", "id": src["id"]}})
                                stunned[src["id"]] = tw + src.get("stun_s", 3.0)
                                stuns.append(src["id"])
            out.append(s)
        planner.timeline(out)
        info["resist_pull"] = len(resist)
        info["offer_stuns"] = stuns
        return out

    def _plan_subscriptions(self, planner, steps, info):
        if not self.subs:
            return steps
        m = self.m
        out = []
        done = set()
        sinfo = info.setdefault("subscriptions", [])
        for s in steps:
            out.append(s)
            if s["action"] != "move":
                continue
            to = s["to"]
            x, feet = planner.feet(to)
            cy = feet - m.hh * 0.5
            for sub in self.subs:
                if sub["id"] in done:
                    continue
                dist = math.hypot(sub["center"][0] - x, sub["center"][1] - cy)
                if dist > sub["wake"] + EPS:
                    continue
                if is_pinched(to):
                    continue
                done.add(sub["id"])
                entry = {"id": sub["id"], "at": [to[1], to[0]]}
                facing = 1 if sub["center"][0] >= x else -1
                if m.has_pulse(s["state"]) or m.has_pound(s["state"]):
                    wait = max(0.0, dist - m.hw) / max(sub["speed"], 1.0)
                    out.append({"action": "wait", "at": to, "seconds": round(wait, 3), "state": s["state"],
                                "reason": "la Suscripcion %s llega y se engancha" % sub["id"],
                                "target": {"type": "subscription", "id": sub["id"]}})
                    out.append({"action": "cancel_subscription", "at": to, "state": s["state"],
                                "with": "pulse" if m.has_pulse(s["state"]) else "ground_pound",
                                "shot": {"x": x, "facing": facing}, "target": {"type": "subscription", "id": sub["id"]}})
                    entry["cancel"] = out[-1]["with"]
                    entry["wait_s"] = round(wait, 2)
                    if m.has_laser(s["state"]):
                        out.append({"action": "laser", "at": to, "state": s["state"], "shot": {"x": x, "facing": facing},
                                    "target": {"type": "subscription", "id": sub["id"], "defeat": True}})
                        entry["defeat"] = "laser"
                else:
                    entry["cancel"] = None
                    s["w5_hook"] = sub["id"]
                sinfo.append(entry)
        return out

    def _plan_wishes(self, planner, steps, info):
        if not self.wishes:
            return
        m = self.m
        T = m.T
        planner.timeline(steps)
        stops = []
        run = None
        for s in steps + [{"action": "move"}]:
            node = None if s["action"] == "move" else s.get("at")
            if node is not None:
                node = tuple(node)
            if run is not None and node == run[0]:
                run[1] += planner.duration(s)
                continue
            if run is not None:
                stops.append(tuple(run))
            run = [node, planner.duration(s)] if node is not None else None
        bad = []
        for node, secs in stops:
            x, feet = (node[0] + 0.5) * T, (node[1] + 1) * T
            for wsh in self.wishes:
                on_card = abs(feet - wsh["card_y"]) < 1.0 and wsh["cells"][0][0] * T <= x <= (wsh["cells"][-1][0] + 1) * T
                if not on_card:
                    continue
                drift, _a, _t = self.pull(1.0)
                need = wsh["add_s"] + max(0.0, abs(x - wsh["item_x"]) - wsh["half"]) / max(drift, 1.0)
                if secs + EPS >= need:
                    bad.append(wsh["id"])
                    planner.error("lista de deseos %s: el camino se para %.1f s sobre ella (con %.1f s llega al objeto "
                                  "y «Añadido al carrito»)" % (wsh["id"], secs, need), node, wsh["id"])
        info["wish_stops"] = bad

    def _ledger(self, planner, steps, info, buy):
        """Saldo del intento desde 0 (peor caso: se gasto todo en Calc): +1 por punto que toca el camino, cajas de
        puntos, compras y atajos, Suscripciones que drenan (tope drain_cap, nunca por debajo de min_balance) y
        Devoluciones (lo drenado y lo pagado en atajos con trampa, mas bonus_points)."""
        econ = self.economy
        sub = econ.get("subscription", {})
        cap = int(sub.get("drain_cap", 5))
        floor = int(econ.get("min_balance", 0))
        bonus = int(econ.get("refund_desk", {}).get("bonus_points", 2))
        balance = 0
        low = 0
        spent = 0
        refundable = 0
        refunded = 0
        taken = set()
        for s in steps:
            a = s["action"]
            if a == "move":
                for n in (s["from"], s["to"]):
                    cells = {(n[0], n[1])} if is_pinched(n) else {(n[0], n[1]), (n[0], n[1] - 1)}
                    for c in cells & self.points:
                        if c not in taken:
                            taken.add(c)
                            balance += 1
                if s.get("w5_hook"):
                    drained = min(cap, max(0, balance - floor))
                    balance -= drained
                    refundable += drained
            elif a == "open_box" and s.get("content") == "points" and s.get("with") != "laser":
                balance += int(s.get("amount", 0))
            elif a == "open_box" and s.get("content") == "subscription" and s.get("with") != "laser":
                pass  # el plan la cancela con el pulso antes del primer drenaje (2 s)
            elif a in ("buy", "pay_door"):
                cost = int(s.get("cost", 0))
                if balance - cost < floor:
                    planner.error("saldo negativo: %s %s cuesta %d y el saldo es %d (minimo %d)" % (
                        "la compra" if a == "buy" else "el atajo", s["target"]["id"], cost, balance, floor),
                        s.get("at"), s["target"]["id"])
                balance -= cost
                spent += cost
                if a == "pay_door" and s.get("trap"):
                    refundable += cost
                s["balance_after"] = balance
            elif a == "refund":
                gain = refundable + bonus
                balance += gain
                refunded += gain
                refundable = 0
                s["amount"] = gain
            low = min(low, balance)
        info["ledger"] = {"profile": "buy" if buy else "frugal", "start": 0, "end": balance, "min": low,
                          "spent": spent, "refunded": refunded, "points_on_path": len(taken),
                          "rollback_returns": spent}

    def buy_planner(self, validator):
        """Camino del comprador (--buy): la progresion con los atajos y la caja de Calc ya pagables (abiertos en el
        grafo; el plan inserta pay_door antes de cruzarlos), sin «ACEPTAR». Sus errores llevan «comprando: »."""
        import level_plan
        main = getattr(validator, "main", None)
        start = validator.result.get("start")
        if not main or not main.get("ok") or start is None:
            return None
        pay = frozenset(g.gid for g in self.gates if g.kind == "pay")
        accept = frozenset(g.gid for g in self.gates if g.kind == "terms_accept")
        forbid = frozenset(g for g in validator.secret_gates() if g not in pay) | accept
        run = validator.progression(start, pay, validator.rules.limit, forbid=forbid, targets=validator.goal_cells)
        if not run["ok"]:
            validator.report.error("comprando: la meta no se alcanza con los atajos pagados")
            return None
        validator.main = run
        try:
            planner = level_plan.Planner(validator)
            planner.w5_buy = True
            steps = planner.run()
        finally:
            validator.main = main
        for message, node, obj in planner.errors:
            if node is not None:
                validator.report.error("comprando: " + message, node[1], node[0], obj)
            else:
                validator.report.error("comprando: " + message, obj=obj)
        for message, node, obj in planner.warnings:
            validator.report.warning("comprando: " + message, obj=obj)
        if steps is None:
            return None
        info = validator.result.setdefault("world5", {}).setdefault("buy", {})
        info["duration_s"] = planner.info.get("duration_s")
        info["steps"] = len(steps)
        info["paid"] = [s["target"]["id"] for s in steps if s["action"] == "pay_door"]
        info["bought"] = [s["target"]["id"] for s in steps if s["action"] == "buy"]
        info["refund"] = [s["target"]["id"] for s in steps if s["action"] == "refund"]
        return planner

    def budget(self, planner):
        target = planner.level.get("target_duration_s")
        info = planner.v.result.setdefault("world5", {})
        dur = planner.info.get("duration_s")
        if not target or dur is None:
            info["budget"] = {"duration_s": dur, "target_s": None}
            return
        pct = float(dur) / float(target)
        info["budget"] = {"duration_s": dur, "target_s": target, "pct": round(pct * 100.0, 1),
                          "range": [BUDGET[0] * 100, BUDGET[1] * 100]}
        if not (BUDGET[0] - EPS <= pct <= BUDGET[1] + EPS):
            planner.warning("presupuesto de camino: %.1f s es el %.0f %% de los %d s del objetivo (fuera del %d-%d %%)"
                            % (dur, pct * 100.0, int(target), BUDGET[0] * 100, BUDGET[1] * 100))

    # --- Exportacion y texto ---

    def export_extra(self, item, s):
        a = s["action"]
        if a == "move":
            e = s["edge"]
            if e.get("combo") == "edge":
                item["action"] = "combo_edge"
                item["compressed"] = True
                item["energy_cost"] = e.get("energy_cost")
                if e.get("rails"):
                    item["rails"] = list(e["rails"])
            elif s.get("resist"):
                item["action"] = "resist_pull"
                item["pull"] = s["resist"]
            return
        for key in ("cost", "trap", "product", "content", "amount", "looked", "via", "balance_after", "countdown"):
            if key in s and s[key] not in (None, ""):
                item[key] = s[key]
        if a == "open_box":
            item["with"] = s.get("with")
        if a == "cancel_subscription":
            item["with"] = s.get("with", "pulse")
        if a in ("buy", "pay_door", "refund"):
            item["face_back"] = True
            item["pose_s"] = s.get("pose_s")
        if a in ("combo_ram", "combo_quake", "reject_terms", "wait_countdown"):
            item["seconds"] = round(s.get("seconds", 0.0), 3)
            if s.get("energy_w5"):
                item["energy_cost"] = s["energy_w5"]
        if a == "combo_ram" and s.get("ram"):
            item["ram"] = s["ram"]
        if a == "combo_quake" and s.get("quake"):
            item["quake"] = s["quake"]
            item["compressed"] = True
        if a == "reject_terms" and s.get("graze"):
            item["graze"] = s["graze"]
            item["compressed"] = True
        if a in ("combo_ram", "combo_quake"):
            item["breaks"] = list(s.get("breaks", []))
        if a == "wait_countdown":
            item["beat"] = {k: v for k, v in s.get("beat", {}).items() if k != "rhythm"}

    def describe_gate(self, g, n, stage):
        k = g.kind
        where = "(fila %d, columna %d)" % (n[1], n[0])
        if k == "pay":
            text = "pulso de espaldas desde %s -> paga %d por %s" % (where, g.cost, g.label())
            return {"action": "pay_door", "from": [n[1], n[0]], "object": g.label(), "text": text}
        if k == "box":
            how = self.box_method(g, n, stage["state"]) or "?"
            verb = {"pulse": "pulso de cara", "ground_pound": "golpe al suelo encima", "laser": "laser (la destruye)"}
            return {"action": "open_box", "from": [n[1], n[0]], "object": g.label(),
                    "text": "%s desde %s -> %s (%s)" % (verb.get(how, how), where, g.label(), g.content)}
        if k == "terms":
            via = "Filo que roza «rechazar»" if is_pinched(n) else "laser a «rechazar»"
            return {"action": "reject_terms", "from": [n[1], n[0]], "object": g.label(),
                    "text": "%s desde %s -> abre %s sin coste" % (via, where, g.label())}
        if k == "terms_accept":
            return {"action": "pulse", "from": [n[1], n[0]], "object": g.label(),
                    "text": "pulso desde %s -> %s (engancha una Suscripcion)" % (where, g.label())}
        if k == "shutter":
            return {"action": "combo_ram", "from": [n[1], n[0]], "object": g.label(),
                    "text": "Embestida (salto, Deslizar y abajo) desde %s -> rompe %s" % (where, g.label())}
        return {"action": "combo_quake", "from": [n[1], n[0]], "object": g.label(),
                "text": "Sismo (comprimido, salto y abajo) desde %s -> tumba a la vez %s" % (where, g.label())}


def _path(parent, target):
    out = []
    node = target
    while parent.get(node) is not None:
        prev, edge = parent[node]
        out.append((prev, edge))
        node = prev
    out.reverse()
    return out


def format_lines(result):
    w5 = result.get("world5")
    if not w5:
        return []
    out = []
    econ = w5.get("economy") or {}
    if econ.get("priced"):
        out.append("  economia: %d cosa(s) con precio, %d en total (maximo %d); puntos del nivel: %d" % (
            econ["priced"], econ["total"], econ["max_spend_per_level"], econ.get("points", 0)))
        for it in econ.get("items", []):
            if it.get("reachable"):
                out.append("    %s %s: cuesta %d, antes en la ruta %d punto(s)" % (
                    it["what"], it["id"], it["cost"], it["points_before"]))
    led = w5.get("ledger")
    if led:
        out.append("  saldo (%s, desde 0): termina en %d, minimo %d, gastado %d, devuelto %d, %d punto(s) en el camino"
                   % ("comprador" if led["profile"] == "buy" else "frugal", led["end"], led["min"], led["spent"],
                      led["refunded"], led["points_on_path"]))
    tem = w5.get("temptation") or {}
    if tem.get("sources"):
        out.append("  tentacion: %d fuente(s); alejarse andando como minimo a %s px/s; %d tramo(s) contra el tiron%s" % (
            tem["sources"], "-" if tem.get("min_escape_px_s") is None else "%.0f" % tem["min_escape_px_s"],
            w5.get("resist_pull", 0),
            "; pulso a %s" % ", ".join(w5["offer_stuns"]) if w5.get("offer_stuns") else ""))
    for b in w5.get("boxes", []):
        out.append("  caja sorpresa %s: %s%s" % (b["id"], b["content"], "; tapa el camino" if b["blocks_path"] else ""))
    for sinfo in w5.get("subscriptions", []):
        out.append("  Suscripcion %s: %s en (fila %d, columna %d)" % (
            sinfo["id"], ("cancelada con %s%s" % ("el pulso" if sinfo["cancel"] == "pulse" else "el golpe al suelo",
                                                 " y derrotada con el laser" if sinfo.get("defeat") else ""))
            if sinfo.get("cancel") else "drena (sin pulso ni golpe al suelo)", sinfo["at"][0], sinfo["at"][1]))
    for t in w5.get("terms", []):
        out.append("  Terminos y condiciones %s: rechazar con %s desde (fila %d, columna %d)" % (
            t["id"], "el laser" if t["via"] == "laser" else "un Filo", t["at"][0], t["at"][1]))
    combo = w5.get("combo") or {}
    obst = w5.get("obstacles") or []
    if obst or combo.get("possible"):
        out.append("  Combinacion: %s" % ("si" if combo.get("possible") else "no"))
    for o in obst:
        name = {"shutter": "persiana", "shelf": "estanterias", "price_rail": "ranura"}[o["kind"]]
        if o["used"]:
            out.append("    %s %s: en el camino; %s" % (name, o["id"], "exige su combo" if o.get("required") else
                                                         "NO exige su combo"))
        else:
            out.append("    %s %s: fuera del camino principal" % (name, o["id"]))
    for e in w5.get("shelf_rule", []):
        out.append("    estanterias %s: %d; ningun golpe suelto alcanza a dos: %s" % (
            e["group"], e["shelves"], "si" if e["ok"] else "NO"))
    if w5.get("wish_stops") is not None:
        out.append("  lista de deseos: %s" % ("sin paradas sobre un deseo" if not w5["wish_stops"] else
                                              "paradas sobre %s" % ", ".join(w5["wish_stops"])))
    bud = w5.get("budget")
    if bud and bud.get("target_s"):
        out.append("  presupuesto de camino: %.1f s = %.0f %% de %d s (objetivo %d-%d %%)" % (
            bud["duration_s"], bud["pct"], int(bud["target_s"]), bud["range"][0], bud["range"][1]))
    buyi = w5.get("buy")
    if buyi and buyi.get("ledger"):
        led = buyi["ledger"]
        out.append("  camino del comprador: %s s; paga %s; compra %s; Devoluciones %s; saldo termina en %d (minimo %d, "
                   "gastado %d, devuelto %d)" % (
                       buyi.get("duration_s"), ", ".join(buyi.get("paid", [])) or "nada",
                       ", ".join(buyi.get("bought", [])) or "nada", ", ".join(buyi.get("refund", [])) or "no",
                       led["end"], led["min"], led["spent"], led["refunded"]))
    return out
