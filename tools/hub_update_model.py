"""Validador de la pagina 2 del hub «Actualizacion del sistema» (2026-10-27, paso 4 de
docs/propuesta-hub-mundos-4-6.md §2.7 y §5.2).

El hub no es un nivel (no tiene grid ni G): este modulo lee el acertijo de data/hub_update.json (celdas locales a
la pagina 2) y la sala de data/hub.json (suelo en floor_row, repisas de 160 px, estaciones) y monta con ellos un
nivel sintetico para el MISMO modelo de movimiento de tools/validate_level.py (LevelModel, World.simulate,
search, time_search, pulse_hits, laser_shot, Pellizcar y espejos de tools/world3_model.py). Lo usa
validate_level.py cuando se le pasa data/hub_update.json; la salida de los niveles y las arenas no cambia.

Rejilla: medio tile (32 px). La repisa de RE esta a 160 px del dock (y 416) y la plataforma «Cargando...» arriba en
y 448: con tiles de 64 la repisa caeria a mitad de celda, asi que el nivel sintetico usa tile_size 32 (40 x 22
celdas por pagina) y todas las piezas caen en el borde de una celda; el modelo de movimiento trabaja en px (la caja
de Isak de 32 x 80, el salto, el dash y la caja comprimida de 32 x 40 son los mismos). Solo se modela la pagina 2
(el borde izquierdo, que en el juego sigue a la pagina 1, es una pared: la pagina 1 no ayuda al acertijo). El techo
de la sala (y 0) queda por encima de cualquier salto.

Comprueba (con todas las habilidades: pulso, laser, Debug, dash, golpe al suelo y Pellizcar):

  V1 «Integridad»: lector1 solo se ve con el Debug (sin el no hay disparo); un laser desde una celda de pie lo
     alcanza; desde el suelo el pulso NO alcanza a RE (hay que subir a la repisa de una via) y el pulso desde una
     celda alcanzable si, dentro de la ventana (LevelModel.time_search, como relay_plan): necesita = pose del laser
     + recorrido + retraso del pulso; error si a la ventana le sobra menos de time_margin_s (1,5 s, el margen del
     validador del 1-2) y aviso si window_s < k x necesita (formula de ventana del 1-2, k = 3).
  V2 «Bufer»: el golpe al suelo con los pies sobre la placa (+-feet_tolerance_px) sube la plataforma up_s; el
     bloque de V2 no se alcanza con la plataforma abajo (ni con el dash) y con ella arriba si, con un movimiento
     directo desde la plataforma (salto, salto corriendo o con dash aereo); necesita = pose del golpe + recorrido
     placa -> plataforma + arranque, con el mismo margen y el mismo aviso de k que V1; el pulso desde lo alto del
     bloque alcanza V2.
  V3 «Recorte»: un laser desde una celda de pie rebota en el espejo y alcanza lector3 (trazado de world3_model);
     con la barrera del marco el nicho no se alcanza (ni comprimido); sin ella se entra comprimido, se recupera el
     tamano dentro y el pulso (sin comprimir) alcanza V3.
  Instalador: el pulso lo alcanza desde una celda de pie.
  Sin atascos: desde la repisa, lo alto del bloque y el nicho se vuelve a P2 (plataforma abajo; del nicho,
     comprimido).
  Energia: Debug (carga + pose del laser) + 2 laseres + los dashes del camino de V2 <= energia maxima (se llena al
     entrar al hub; el cargador_p2 da mas).
  Negativos (con el modelo mas permisivo: salto real a 60 Hz, corriendo, sin limite de exigencia): sin el Debug
     falla V1, sin el dash y sin el golpe al suelo falla V2 y sin Pellizcar falla V3. Se informa de lo que falla
     sin cada habilidad.

Exigencia: el hub no tiene caidas ni dano y sus repisas son las de la pagina 1 (160 px, «un salto desde el
dock»), por encima del limite de los niveles (0,85 del salto conservador): el modelo usa como limite el alcance
fisico (1,0) e informa de la exigencia de cada verificacion, con un aviso si pasa de 0,85. En el hub se puede
correr: los saltos corriendo cuentan (allow_run), con el salto conservador de --jump-efficiency (0,92).
"""

import copy
import json
import os
import re

import validate_level as vl

SUB = 2  # celdas del nivel sintetico por tile del hub
HUB_LIMIT = 1.0
DEFAULT_K = 3.0  # k de la formula de ventana del 1-2 (docs/propuesta-1-2.md §0.1, dificultad 1-2): aviso
ABILITIES = ("pulse", "laser", "debug", "dash", "ground_pound", "compress")
ABILITY_NAMES = {"pulse": "pulso", "laser": "laser", "debug": "Debug", "dash": "dash",
                 "ground_pound": "golpe al suelo", "compress": "Pellizcar"}
# Negativos exigidos (§2.7 y paso 4): sin la habilidad, esa verificacion no se puede hacer.
REQUIRED_NEGATIVES = (("debug", "v1"), ("dash", "v2"), ("ground_pound", "v2"), ("compress", "v3"))
CHECK_IDS = ("v1", "v2", "v3", "installer")


def is_hub_update(data):
    """Verdadero si el JSON es el acertijo del hub (data/hub_update.json) y no un nivel."""
    return isinstance(data, dict) and "grid" not in data and "checks" in data and "upgrade" in data


def _gd_export(root, rel, name, default):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as handle:
            m = re.search(r"@export var %s\s*:\s*\w+\s*=\s*([-\d.]+)" % re.escape(name), handle.read())
    except OSError:
        return default
    return float(m.group(1)) if m else default


class HubPage:
    """Geometria y piezas de la pagina 2 en px locales a la pagina (x 0 = borde izquierdo de la pagina)."""

    def __init__(self, data, root):
        self.data = data
        self.root = root
        hub = vl.load_json(os.path.join(root, "data", "hub.json"))
        room = hub["room"]
        self.T = float(vl.load_json(os.path.join(root, "data", "isak_physics.json"))["tile_size"])
        T = self.T
        self.cols, self.rows = int(room["size_tiles"][0]), int(room["size_tiles"][1])
        self.floor_row = int(room.get("floor_row", 9))
        self.floor_y = self.floor_row * T
        self.page = int(data.get("page", 2))
        page = next((p for p in room.get("pages", []) if int(p.get("page", 0)) == self.page), None)
        spawn = page["spawn_cell"] if page else room["spawn_cell"]
        self.spawn = (int(spawn[0]) - (self.page - 1) * self.cols, int(spawn[1]))
        cat = vl.level_catalog.load_catalog(root, 3)
        lr = cat.get("laser_receiver", {}).get("hit_rect", [32, -16, 32, 48])
        rr = cat.get("relay_receiver", {}).get("hit_rect", [12, 0, 40, 64])
        mh = cat.get("mirror", {}).get("hit_rect", [0, 0, 64, 64])
        v1, v2, v3 = data["v1"], data["v2"], data["v3"]
        terrain = data.get("terrain", {})
        # Terreno solido: dock (suelo) y los rectangulos de terrain; la barrera del marco aparte.
        self.solids = [(0.0, self.floor_y, self.cols * T, self.rows * T)]
        for key in ("block", "niche_wall"):
            r = terrain.get(key)
            if r:
                self.solids.append(self._cells_rect(r))
        fc = v3["frame_cell"]
        self.barrier = (fc[0] * T, fc[1] * T, (fc[0] + 1) * T, (fc[1] + 1) * T)
        # Repisa de una via de RE.
        self.shelf_y = self.floor_y - float(v1.get("shelf_height_px", 160))
        sc = v1.get("shelf_cols", [3, 6])
        self.shelf = (int(sc[0]) * T, self.shelf_y, (int(sc[1]) + 1) * T)
        # Plataforma temporal.
        pc = v2.get("platform_cols", [10, 11])
        top = float(v2.get("platform_top_px", 448))
        self.platform = (int(pc[0]) * T, top, (int(pc[1]) + 1) * T, top + float(v2.get("platform_thickness_px", 16)))
        self.up_s = float(v2.get("up_s", 3.0))
        self.warn_s = float(v2.get("warn_s", 0.5))
        # Piezas (rectangulos en px).
        self.lector1 = self._hit(v1["reader_cell"], lr)
        relay_x = int(v1.get("relay_col", 4)) * T
        self.relay = (relay_x + float(rr[0]), self.shelf_y - T + float(rr[1]),
                      relay_x + float(rr[0]) + float(rr[2]), self.shelf_y - T + float(rr[1]) + float(rr[3]))
        self.window_s = float(v1.get("window_s", 6.0))
        pw = _gd_export(root, "scripts/levels/pound_plate.gd", "plate_width_px", 64.0)
        ph = _gd_export(root, "scripts/levels/pound_plate.gd", "plate_height_px", 8.0)
        self.plate_tol = _gd_export(root, "scripts/levels/pound_plate.gd", "feet_tolerance_px", 16.0)
        p = v2["plate_cell"]
        self.plate = (p[0] * T + (T - pw) * 0.5, p[1] * T + T - ph, p[0] * T + (T + pw) * 0.5, (p[1] + 1) * T)
        m = v3["mirror_cell"]
        mx, my = m[0] * T + float(mh[0]), m[1] * T + float(mh[1])
        self.mirror = {"id": "hub_update_espejo", "orient": str(v3.get("mirror_orientation", "/")),
                       "rect": (mx, my, mx + float(mh[2]), my + float(mh[3])),
                       "center": (mx + float(mh[2]) * 0.5, my + float(mh[3]) * 0.5), "cell": tuple(m)}
        self.lector3 = self._hit(v3["reader_cell"], lr)
        # UpdateCheck.size (scripts/levels/update_check.gd): terminal de 1 x 2 tiles desde su celda.
        size = (T, 2.0 * T)
        self.checks = {}
        for spec in data.get("checks", []):
            c = spec["cell"]
            self.checks[str(spec["id"])] = {"name": str(spec.get("name", spec["id"])), "mode": str(spec.get("mode")),
                                            "rect": (c[0] * T, c[1] * T, c[0] * T + size[0], c[1] * T + size[1])}
        inst = data["installer"]
        ic, isz = inst["cell"], inst.get("size_tiles", [2, 3])
        hr = hub.get("station", {}).get("hit_rect_px", [0, 0, 64, 128])
        sx, sy = float(isz[0]) * T / 64.0, float(isz[1]) * T / 128.0
        ix, iy = ic[0] * T, ic[1] * T
        self.installer = (ix + hr[0] * sx, iy + hr[1] * sy, ix + (hr[0] + hr[2]) * sx, iy + (hr[1] + hr[3]) * sy)
        block = terrain.get("block", [17, 5, 3, 2])
        self.block = self._cells_rect(block)
        # Nicho: de la columna siguiente al marco al final del bloque, de la fila de la pared del nicho a la del marco.
        wall = terrain.get("niche_wall", [fc[0], fc[1] - 1, 1, 1])
        self.niche = ((fc[0] + 1) * T, wall[1] * T, (block[0] + block[2]) * T, (fc[1] + 1) * T)
        ch = hub.get("charger", {})
        self.charger_amount = float(cat.get("types", {}).get("charger", {}).get("defaults", {}).get(
            "amount", ch.get("amount", 50.0)) or 50.0)

    def _cells_rect(self, r):
        T = self.T
        return (r[0] * T, r[1] * T, (r[0] + r[2]) * T, (r[1] + r[3]) * T)

    def _hit(self, cell, hit):
        x, y = cell[0] * self.T + float(hit[0]), cell[1] * self.T + float(hit[1])
        return (x, y, x + float(hit[2]), y + float(hit[3]))

    # --- Nivel sintetico ---

    def level(self, barrier=True):
        t = self.T / SUB
        cols, rows = self.cols * SUB, self.rows * SUB
        grid = [["."] * cols for _ in range(rows)]
        solids = list(self.solids) + ([self.barrier] if barrier else [])
        for x0, y0, x1, y1 in solids:
            for r in range(int(round(y0 / t)), int(round(y1 / t))):
                for c in range(int(round(x0 / t)), int(round(x1 / t))):
                    if 0 <= r < rows and 0 <= c < cols:
                        grid[r][c] = "#"
        sr = int(round(self.shelf[1] / t))
        for c in range(int(round(self.shelf[0] / t)), int(round(self.shelf[2] / t))):
            if grid[sr][c] == ".":
                grid[sr][c] = "-"
        return {"id": "hub_update_p%d" % self.page, "world": 3, "tile_size": t,
                "grid": ["".join(row) for row in grid],
                "abilities_available": {a: True for a in ABILITIES},
                # Un objeto del Mundo 3 para que LevelModel monte world3_model (Pellizcar y espejos); el marco pequeno
                # no cambia el terreno.
                "objects": [{"type": "small_frame", "x": int(self.barrier[0] / t), "y": int(self.barrier[1] / t)}],
                "enemies": []}

    def model(self, rules, barrier=True, platform=False):
        m = vl.LevelModel(self.level(barrier), rules)
        t = m.T
        if platform:
            r = int(round(self.platform[1] / t))
            for c in range(int(round(self.platform[0] / t)), int(round(self.platform[2] / t))):
                m.reminders[(c, r)] = self.platform[3] - self.platform[1]
        m.w3.mirrors = [dict(self.mirror)]
        return m


# --- Utilidades ---

def _sub_node(page, cell):
    """Celda de pie del nivel sintetico para una celda de pie del hub (mitad izquierda)."""
    return (int(cell[0]) * SUB, int(cell[1]) * SUB + SUB - 1)


def _x_center(model, node):
    return (node[0] + 0.5) * model.T


def _feet(model, node):
    return (node[1] + 1) * model.T


def _plain(node):
    return node.__class__ is tuple


def _in_rect_nodes(model, nodes, rect, feet_y):
    """Nodos de pie (sin comprimir) con los pies en feet_y y el centro dentro de [rect.x0, rect.x1)."""
    return {n for n in nodes if _plain(n) and abs(_feet(model, n) - feet_y) < vl.EPS
            and rect[0] - vl.EPS <= _x_center(model, n) <= rect[2] + vl.EPS}


def _best_cost(cost, nodes):
    """Exigencia (mayor del camino) hasta el mejor de `nodes` alcanzables, o None."""
    vals = [cost[n] for n in nodes if n in cost]
    return min(vals) if vals else None


class _Context:
    def __init__(self, page, rules, k):
        self.page = page
        self.rules = rules
        self.k = k
        self.base = page.model(rules, barrier=True, platform=False)
        self.up = page.model(rules, barrier=True, platform=True)
        self.open = page.model(rules, barrier=False, platform=False)
        self.start = _sub_node(page, page.spawn)
        self.state = frozenset()
        self._reach = {}

    def forbidding(self, abilities):
        ctx = self

        class _F:
            def __enter__(self):
                self.cms = [m.forbidding(abilities) for m in (ctx.base, ctx.up, ctx.open)]
                for cm in self.cms:
                    cm.__enter__()
                return ctx

            def __exit__(self, *exc):
                for cm in self.cms:
                    cm.__exit__(*exc)
                return False
        return _F()

    def reach(self, model, source=None):
        key = (id(model), source or self.start, model.forbidden)
        if key not in self._reach:
            self._reach[key] = vl.search(model, source or self.start, self.state, self.rules.limit, debug=False)
        return self._reach[key]


def _check_v1(ctx, out):
    page, m = ctx.page, ctx.base
    res = {"ok": False}
    cost, _ = ctx.reach(m)
    if not m.has_laser(ctx.state):
        res["why"] = "sin laser no se activa lector1"
        return res
    if not m.has_debug(ctx.state):
        res["why"] = "lector1 solo se ve y se le apunta con el Debug"
        return res
    shots = {n: m.laser_shot(page.lector1, n, ctx.state) for n in cost if _plain(n)}
    shots = {n: s for n, s in shots.items() if s is not None}
    if not shots:
        res["why"] = "el laser no alcanza lector1 desde ninguna celda de pie alcanzable"
        return res
    floor = [n for n in cost if _plain(n) and abs(_feet(m, n) - page.floor_y) < vl.EPS]
    from_floor = sorted(n for n in floor if m.pulse_hits([page.relay], n, ctx.state))
    res["relay_from_floor"] = [list(n) for n in from_floor]
    if not m.has_pulse(ctx.state):
        res["why"] = "sin pulso no se activa RE"
        return res
    starts = {n: ctx.rules.laser_pose_s for n in shots}
    times, _ = m.time_search(starts, ctx.state, debug=False)
    cands = [(t + vl.PULSE_DELAY_S, n) for n, t in times.items() if _plain(n) and n in cost
             and m.pulse_hits([page.relay], n, ctx.state)]
    if not cands:
        res["why"] = "el pulso no alcanza RE desde ninguna celda de pie alcanzable"
        return res
    need, node = min(cands)
    pulse_nodes = [n for _, n in cands]
    res.update({"ok": True, "need_s": need, "window_s": page.window_s, "k": ctx.k,
                "window_ok": page.window_s + vl.EPS >= ctx.k * need, "pulse_node": list(node),
                "margin_s": page.window_s - need,
                "shot_node": list(min(shots, key=lambda n: (cost[n], n))),
                "exigencia": max(_best_cost(cost, pulse_nodes), _best_cost(cost, list(shots)))})
    res["energy"] = ctx.rules.debug_drain * (ctx.rules.debug_hold_s + ctx.rules.laser_pose_s) + ctx.rules.laser_cost
    res["shelf"] = bool(_in_rect_nodes(m, cost, (page.shelf[0], 0, page.shelf[2], 0), page.shelf[1]))
    return res


def _check_v2(ctx, out):
    page = ctx.page
    res = {"ok": False}
    m_base, m_up = ctx.base, ctx.up
    block_feet = page.block[1]
    cost_base, _ = ctx.reach(m_base)
    on_block_base = _in_rect_nodes(m_base, cost_base, page.block, block_feet)
    res["block_without_platform"] = bool(on_block_base)
    if not m_up.has_pound(ctx.state):
        res["why"] = "sin el golpe al suelo la placa no sube la plataforma"
        return res
    lo, hi = page.plate[0] - page.plate_tol, page.plate[2] + page.plate_tol
    plate_nodes = {n for n in cost_base if _plain(n) and abs(_feet(m_base, n) - page.floor_y) < vl.EPS
                   and lo - vl.EPS <= _x_center(m_base, n) <= hi + vl.EPS}
    if not plate_nodes:
        res["why"] = "no se llega a la placa"
        return res
    plat_nodes = _in_rect_nodes(m_up, m_up.world(ctx.state, False).nodes(), page.platform, page.platform[1])
    block_nodes = _in_rect_nodes(m_up, m_up.world(ctx.state, False).nodes(), page.block, block_feet)
    leaps = {}
    walk_leap = False
    for n in plat_nodes:
        for e in m_up.edges(n, ctx.state, False):
            if e["to"] in block_nodes and max(e["h"], e["v"]) <= ctx.rules.limit + vl.EPS:
                walk_leap = walk_leap or e.get("speed") != "run"
                best = leaps.get(n)
                score = (max(e["h"], e["v"]), 1 if e.get("dash") else 0)
                if best is None or score < best[0]:
                    leaps[n] = (score, e)
    if not leaps:
        res["why"] = "desde la plataforma no se llega al bloque de V2" + (
            "" if m_up.has_dash(ctx.state) else " (sin el dash)")
        return res
    # La plataforma sube al aterrizar el golpe (la onda); Isak sigue en la pose del golpe pound_pose_s.
    starts = {n: ctx.rules.pound_pose_s for n in plate_nodes}
    times, _ = m_up.time_search(starts, ctx.state, debug=False, region=None)
    cands = [(times[n] + vl.START_S, n) for n in leaps if n in times]
    if not cands:
        res["why"] = "no se sube a la plataforma desde la placa"
        return res
    need, pnode = min(cands)
    leap = leaps[pnode][1]
    landed = {leap["to"]}
    if not m_up.has_pulse(ctx.state) or not any(m_up.pulse_hits([page.checks["v2"]["rect"]], n, ctx.state)
                                                for n in block_nodes):
        res["why"] = "el pulso no alcanza V2 desde lo alto del bloque"
        return res
    cost_up, _ = ctx.reach(m_up)
    # Sin atascos: de lo alto del bloque se vuelve a P2 con la plataforma abajo.
    back, _ = ctx.reach(m_base, leap["to"])
    res.update({"ok": True, "need_s": need, "window_s": page.up_s, "k": ctx.k,
                "window_ok": page.up_s + vl.EPS >= ctx.k * need, "platform_node": list(pnode),
                "margin_s": page.up_s - need,
                "leap": {"kind": leap["kind"], "h": leap["h"], "v": leap["v"], "dash": bool(leap.get("dash")),
                         "speed": leap.get("speed")},
                "walk_leap": walk_leap,
                "exigencia": max(_best_cost(cost_up, plate_nodes) or 0.0, max(leap["h"], leap["v"])),
                "returns": ctx.start in back, "landed": [list(n) for n in sorted(landed)]})
    res["energy"] = ctx.rules.dash_cost if leap.get("dash") else 0.0
    return res


def _check_v3(ctx, out):
    page = ctx.page
    res = {"ok": False}
    m, mo = ctx.base, ctx.open
    cost, _ = ctx.reach(m)
    niche_feet = page.niche[3]
    niche_closed = [n for n in cost if page.niche[0] - vl.EPS <= _x_center(m, n) <= page.niche[2] + vl.EPS
                    and _feet(m, n) <= niche_feet + vl.EPS and _feet(m, n) > page.niche[1] + vl.EPS]
    res["niche_with_barrier"] = bool(niche_closed)
    if not m.has_laser(ctx.state):
        res["why"] = "sin laser no se activa lector3"
        return res
    shots = {}
    for n in cost:
        if _plain(n):
            s = m.laser_shot(page.lector3, n, ctx.state)
            if s is not None and s.get("bounces", 0) >= 1:
                shots[n] = s
    if not shots:
        res["why"] = "el laser no llega a lector3 por el espejo desde ninguna celda de pie alcanzable"
        return res
    shot_node = min(shots, key=lambda n: (cost[n], n))
    cost_o, _ = ctx.reach(mo)
    inside = [n for n in cost_o if _plain(n) and abs(_feet(mo, n) - niche_feet) < vl.EPS
              and page.niche[0] - vl.EPS <= _x_center(mo, n) <= page.niche[2] + vl.EPS]
    if not inside:
        res["why"] = "no se entra al nicho (y se recupera el tamano dentro)" + (
            "" if mo.w3.has_compress(ctx.state) else " sin Pellizcar")
        return res
    v3 = page.checks["v3"]["rect"]
    pulse = [n for n in inside if mo.pulse_hits([v3], n, ctx.state)]
    if not mo.has_pulse(ctx.state) or not pulse:
        res["why"] = "el pulso no alcanza V3 desde el nicho sin comprimir"
        return res
    back, _ = ctx.reach(mo, pulse[0])
    res.update({"ok": True, "shot_node": list(shot_node), "bounces": shots[shot_node].get("bounces", 0),
                "pulse_node": list(min(pulse)), "exigencia": max(cost[shot_node], _best_cost(cost_o, pulse)),
                "returns": ctx.start in back, "energy": ctx.rules.laser_cost})
    return res


def _check_installer(ctx, out):
    m = ctx.base
    cost, _ = ctx.reach(m)
    nodes = [n for n in cost if _plain(n) and m.pulse_hits([ctx.page.installer], n, ctx.state)]
    if not m.has_pulse(ctx.state) or not nodes:
        return {"ok": False, "why": "el pulso no alcanza el instalador"}
    return {"ok": True, "exigencia": _best_cost(cost, nodes)}


def _run(ctx):
    out = {}
    out["v1"] = _check_v1(ctx, out)
    out["v2"] = _check_v2(ctx, out)
    out["v3"] = _check_v3(ctx, out)
    out["installer"] = _check_installer(ctx, out)
    return out


def _err(errors, message):
    errors.append({"message": message, "row": None, "col": None, "object": None})


_CACHE = {}


def validate_hub_update(data, root=vl.ROOT, jump_efficiency=vl.DEFAULT_JUMP_EFFICIENCY, physics_path=None,
                        upgrades=(), k=None, negatives=True):
    """Valida el acertijo de la pagina 2. Devuelve {"ok", "errors", "warnings", "checks", "negatives", ...}.
    El resultado se recuerda en el proceso para los mismos datos y opciones (las pruebas lo piden varias veces)."""
    key = (json.dumps(data, sort_keys=True), root, jump_efficiency, physics_path, tuple(upgrades), k, negatives)
    if key not in _CACHE:
        _CACHE[key] = _validate(data, root, jump_efficiency, physics_path, upgrades, k, negatives)
    return copy.deepcopy(_CACHE[key])


def _validate(data, root, jump_efficiency, physics_path, upgrades, k, negatives):
    page = HubPage(data, root)
    validation = data.get("validation", {}) if isinstance(data.get("validation"), dict) else {}
    k = float(k if k is not None else validation.get("window_k", DEFAULT_K))
    errors, warnings = [], []
    rules = vl.Rules(root, physics_path, jump_efficiency, HUB_LIMIT, True, tuple(upgrades))
    margin = float(validation.get("time_margin_s", vl.DEFAULT_TIME_MARGIN_S))
    ctx = _Context(page, rules, k)
    checks = _run(ctx)
    for cid in CHECK_IDS:
        c = checks[cid]
        name = cid.upper() if cid != "installer" else "instalador"
        if not c["ok"]:
            _err(errors, "%s no se alcanza con todas las habilidades: %s" % (name, c.get("why", "?")))
            continue
        if c.get("exigencia") is not None and c["exigencia"] > vl.DEFAULT_LIMIT + vl.EPS:
            warnings.append({"message": "%s pide el %d %% del salto (limite de los niveles %d %%)"
                             % (name, int(round(c["exigencia"] * 100)), int(round(vl.DEFAULT_LIMIT * 100))),
                             "row": None, "col": None, "object": None})
        if "margin_s" in c and c["margin_s"] < margin - vl.EPS:
            _err(errors, "%s: a la ventana de %.2f s le sobran %.2f s (margen minimo %.2f s)"
                 % (name, c["window_s"], c["margin_s"], margin))
        elif "window_ok" in c and not c["window_ok"]:
            warnings.append({"message": "%s: ventana de %.2f s = %.2f x %.2f s (la formula del 1-2 pide k = %g)"
                             % (name, c["window_s"], c["window_s"] / c["need_s"], c["need_s"], k),
                             "row": None, "col": None, "object": None})
        if cid == "v2" and not c["walk_leap"]:
            warnings.append({"message": "V2: al bloque solo se llega con un salto corriendo%s (andando no llega)"
                             % (" + dash aereo" if c["leap"]["dash"] else ""), "row": None, "col": None, "object": None})
        if c.get("returns") is False:
            _err(errors, "%s: desde alli no se vuelve a P2 (atasco)" % name)
    v1, v2, v3 = checks["v1"], checks["v2"], checks["v3"]
    if v1.get("relay_from_floor"):
        _err(errors, "V1: el pulso alcanza RE desde el suelo (deberia hacer falta la repisa)")
    if v2.get("block_without_platform"):
        _err(errors, "V2: el bloque se alcanza sin la plataforma")
    if v3.get("niche_with_barrier"):
        _err(errors, "V3: el nicho se alcanza con el marco cerrado")
    energy = sum(checks[c].get("energy", 0.0) for c in ("v1", "v2", "v3") if checks[c]["ok"])
    energy_info = {"need": energy, "max": rules.energy_max, "charger": page.charger_amount,
                   "margin": rules.energy_max - energy}
    if energy > rules.energy_max + vl.EPS:
        _err(errors, "energia: el acertijo pide %.1f y la barra tiene %.1f" % (energy, rules.energy_max))
    neg = {}
    if negatives:
        # Modelo permisivo: salto real a 60 Hz, corriendo y el mismo limite fisico.
        eff = rules.real_jump_height / rules.nominal_height if rules.nominal_height > 0 else 1.0
        loose = vl.Rules(root, physics_path, max(eff, jump_efficiency), HUB_LIMIT, True, tuple(upgrades))
        lctx = _Context(page, loose, k)
        for ability in ABILITIES:
            with lctx.forbidding({ability}):
                res = _run(lctx)
            neg[ability] = {cid: res[cid]["ok"] for cid in CHECK_IDS}
            neg[ability]["why"] = {cid: res[cid].get("why") for cid in CHECK_IDS if not res[cid]["ok"]}
        for ability, cid in REQUIRED_NEGATIVES:
            if neg[ability][cid]:
                _err(errors, "sin %s, %s se sigue haciendo (deberia fallar)" % (ABILITY_NAMES[ability], cid.upper()))
    return {"ok": not errors, "kind": "hub_update", "page": page.page, "errors": errors, "warnings": warnings,
            "checks": checks, "energy": energy_info, "negatives": neg, "k": k, "limit": HUB_LIMIT,
            "spawn": list(page.spawn)}


def format_text(path, result):
    lines = ["%s: acertijo del hub (pagina %d) %s" % (path, result["page"], "OK" if result["ok"] else "CON ERRORES")]
    c = result["checks"]
    if c["v1"]["ok"]:
        v = c["v1"]
        lines.append("  V1: Debug + laser a lector1 y pulso a RE desde la repisa en %.2f s de %.1f (sobran %.2f s; "
                     "%.1f x, k = %g); exigencia %d %%" % (v["need_s"], v["window_s"], v["margin_s"],
                                                         v["window_s"] / v["need_s"], v["k"],
                                                         int(round(v["exigencia"] * 100))))
    if c["v2"]["ok"]:
        v = c["v2"]
        lines.append("  V2: golpe a la placa y a la plataforma en %.2f s de %.1f (sobran %.2f s; %.1f x, k = %g); "
                     "salto %s%s al bloque y pulso a V2; exigencia %d %%"
                     % (v["need_s"], v["window_s"], v["margin_s"], v["window_s"] / v["need_s"], v["k"],
                        "corriendo" if v["leap"]["speed"] == "run" else "andando",
                        " + dash aereo" if v["leap"]["dash"] else "", int(round(v["exigencia"] * 100))))
    if c["v3"]["ok"]:
        v = c["v3"]
        lines.append("  V3: laser por el espejo (%d rebote) a lector3, nicho comprimido y pulso a V3 sin comprimir; "
                     "exigencia %d %%"
                     % (v["bounces"], int(round(v["exigencia"] * 100))))
    if c["installer"]["ok"]:
        lines.append("  instalador: el pulso lo alcanza")
    e = result["energy"]
    lines.append("  energia: %.1f de %.1f (margen %.1f; cargador_p2 +%.0f)" % (e["need"], e["max"], e["margin"],
                                                                             e["charger"]))
    for ability, res in result.get("negatives", {}).items():
        failed = [cid.upper() if cid != "installer" else "instalador" for cid in CHECK_IDS if not res[cid]]
        lines.append("  sin %s: %s" % (ABILITY_NAMES[ability], ("fallan " + ", ".join(failed)) if failed
                                       else "se hace todo"))
    for w in result["warnings"]:
        lines.append("  AVISO: %s" % w["message"])
    for err in result["errors"]:
        lines.append("  ERROR: %s" % err["message"])
    return "\n".join(lines)
