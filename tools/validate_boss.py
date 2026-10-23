#!/usr/bin/env python3
"""Validador de ARENAS DE JEFE (kind "boss"; paso 5 de docs/propuesta-jefe-alerta-mayor.md §6, §4.2).

Una pelea no es un camino de P a G: tools/validate_level.py delega aqui las arenas (data/levels/<m>-boss.json)
y este modulo comprueba, con los datos del jefe (data/bosses/<boss>.json: arena, fases, laps y
validation_model) y los mismos valores de juego que el validador de niveles (Rules: fisica, pulso, laser,
Debug, dash, energia y mejoras de data/upgrades.json):

  1. Terreno: desde P se alcanzan los dos carriles (suelo y alto) con la fisica de Isak (el modelo de
     validate_level sobre la geometria de las fases 1-2, sin ataques: tools/level_climbs.py mide esas
     subidas con el Isak real).
  2. Carriles: el dano de un carril (barrido del banner o rafaga de notificaciones) no alcanza a Isak de pie
     en el otro (el otro es el refugio), y ningun ataque barre los dos a la vez: los barridos de la fase 1
     (aviso + recorrido) caben en su intervalo y las rafagas de la fase 2 (aviso + disparos + cruce) en el
     suyo.
  3. Cargadores: desde cada celda del suelo hay uno a charger_max_tiles como mucho y otro a
     charger_second_max_tiles (por si el primero se enfria); ninguno bajo una plataforma ni donde aterriza
     el jefe en la fase 1.
  4. Avisos: todo ataque se anticipa de 6 a 12 cuadros (regla fija del diseño), contados en tiempo del mundo;
     con el Debug (debug_world_scale del nivel, 0,7 en la arena) duran 1 / escala veces mas en tiempo real,
     nunca menos que sin el (escala <= 1).
  5. Alcance del nucleo en cada sitio de ventana (fase 1: suelo del centro; fase 2: las plataformas del
     escudo, con su boton al alcance del pulso; fase 3: los sitios de las copias de cada acceso): pulso desde
     una celda de pie alcanzable (circulo del pulso contra el del nucleo) y laser desde una celda de pie de su
     carril (el haz a la altura del celular, sin terreno en medio).
  6. Ventanas con k = window_k (propuesta-1-2.md §0.1): ventana (s del mundo) >= k x (recorrido desde la
     peor celda de window_from + carga del Debug + pose del pulso que marca + pose del primer laser), con la
     estrategia mas favorable (Debug al llegar, Debug primero o Debug cargado en marcha —la carga no para a
     Isak—: con el Debug activo el mundo va a la escala del nivel, debug_world_scale, o a la global, y el
     recorrido cuenta menos en tiempo del mundo). En la fase 2 la ventana empieza al
     cerrar el escudo (recorrido 0) y el escudo debe esperar perch_s >= k x (recorrido + pose del pulso).
  7. Fase 3 por acceso: nunca dos ondas de campana a la vez en ningun paso del compas (hueco seguro), cada
     campana cabe en el compas mas corto (aviso + onda + reposo), las plataformas que parpadean encendidas
     >= aviso + 0,25 s con el compas mas corto, copias <= sitios y lanzamientos <= copias.
  7c. Subida a la plataforma central en la fase 3 (§6.4; Raíz, cuarta copia): con la geometria de la fase 3
     (laterales que parpadean: de una via si one_way, si no macizas) hay camino desde el suelo de window_from
     a la central pasando por una lateral, sin el dash (el Debug puede seguir activo) o con el salto + dash
     aereo (soltando el Debug: no se combinan); la lateral encendida da tiempo a aterrizar y despegar antes de
     su aviso (compas mas corto, sin el Debug: a x1); la ventana cubre ademas la espera a que la lateral se
     encienda; y hay celdas de la central fuera de la onda de las campanas desde las que el pulso llega al
     nucleo (y la de llegada tampoco esta bajo una campana).
  7b. Marca (§6.4): en la marca de cada acceso (mark_duration_s, tiempo del mundo; el caso peor es sin el
     Debug, a x1) caben los laseres de la peor ventana de la pelea torpe (golpes / dano + fallados).
  8. ENERGIA (§2.4.7): la pelea torpe de validation_model (por acceso y fase: ventanas con sus golpes,
     Debug por ventana con debug_drain_scale del nivel, dashes, laseres fallados) con la barra base (100),
     con el tope del acceso y con todo al maximo: el pico por ventana <= energia maxima - min_margin. Informa
     del gasto, las cargas de 50 y el desvio por fase.

Uso: python3 tools/validate_level.py data/levels/1-boss.json (o este modulo directamente, con las mismas
opciones basicas: python3 tools/validate_boss.py [--json] [--upgrades ...] data/levels/1-boss.json).
"""

import argparse
import copy
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import upgrade_catalog  # noqa: E402
import validate_level as vl  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EPS = 1e-6
# Regla fija: todo ataque se anticipa de 6 a 12 cuadros.
TELEGRAPH_FRAMES = (6, 12)
# Tiempo de una subida de 2 tiles (un salto hasta la repisa; aproximado).
CLIMB_S = 0.45
MAX_TRACK = "max"
# Reaccion en una lateral que parpadea: de aterrizar a despegar otra vez (s; §6.4, subida a la central).
LATERAL_REACT_S = 0.2
CENTER_SPOT = "platform_center"
# Parte del enfriamiento del dash en que Isak puede volver corriendo hacia atras (§6.4, rafaga).
DASH_RETREAT_FRACTION = 0.5


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def _err(errors, message, row=None, col=None):
    errors.append({"message": message, "row": row, "col": col, "object": None})


# --- Geometria ---

def geometry_level(level, phase_objects=False):
    """Copia del nivel sin el jefe ni los ataques (para el modelo de movimiento de validate_level): sin
    enemigos, solo los cargadores y una G de servicio en la ultima celda libre del suelo de la fila de P."""
    g = copy.deepcopy(level)
    for key in ("kind", "boss"):
        g.pop(key, None)
    g["id"] = "arena_test"
    g["enemies"] = []
    g["objects"] = [o for o in g.get("objects", []) if o.get("type") == "charger"]
    g.pop("validation", None)
    grid = [row.replace("E", ".") for row in g["grid"]]
    pr = next(r for r, row in enumerate(grid) if "P" in row)
    row = list(grid[pr])
    for c in range(len(row) - 1, -1, -1):
        if row[c] == ".":
            row[c] = "G"
            break
    grid[pr] = "".join(row)
    g["grid"] = grid
    return g


class Arena:
    """Datos de la arena: celdas de pie alcanzables desde P, sitios, carriles y cargadores."""

    def __init__(self, level, boss, rules):
        self.level = level
        self.boss = boss
        self.rules = rules
        self.T = float(level["tile_size"])
        self.grid = level["grid"]
        self.rows, self.cols = len(self.grid), len(self.grid[0])
        geo = geometry_level(level)
        validator = vl.Validator(geo, rules)
        self.model = validator.model
        start = next((c, r) for r, row in enumerate(geo["grid"]) for c, ch in enumerate(row) if ch == "P")
        cost, _ = vl.search(self.model, start, self.model.initial, rules.limit, debug=False)
        self.reachable = set(cost)
        self.world = self.model.world(self.model.initial)
        self.arena = boss.get("arena", {})
        self.spots = {k: (float(v[0]), int(v[1])) for k, v in self.arena.get("spots", {}).items()}
        self.lanes = self.arena.get("lanes", {})
        self.chargers = [(o["x"], o["y"], o.get("params", {})) for o in level.get("objects", [])
                         if o.get("type") == "charger"]

    def solid(self, c, r):
        if not (0 <= c < self.cols and 0 <= r < self.rows):
            return True
        return self.grid[r][c] == "#"

    def lane_cells(self, lane):
        """Celdas de pie de un carril (fila de encima de su superficie) dentro de sus columnas."""
        data = self.lanes[lane]
        r = int(data["surface_row"]) - 1
        return [(c, r) for c in range(int(data["from_col"]), int(data["to_col"]) + 1) if self.world.is_node(c, r)]

    def spot_feet(self, spot):
        x, surface = self.spots[spot]
        return (x * self.T, surface * self.T)

    def core_pos(self, spot):
        fx, fy = self.spot_feet(spot)
        off = self.arena.get("core_offset_px", [0, -56])
        return (fx + float(off[0]), fy + float(off[1]))

    def feet(self, node):
        c, r = node
        return ((c + 0.5) * self.T, (r + 1) * self.T)

    def phone(self, node, facing):
        fx, fy = self.feet(node)
        return (fx + facing * self.rules.phone_x, fy + self.rules.phone_y)

    def travel_s(self, a, b):
        """Recorrido aproximado corriendo de la celda a a la b (s reales): horizontal a run_speed y un salto
        por cada 2 filas de diferencia."""
        dx = abs(a[0] - b[0]) * self.T / self.rules.run_speed
        climbs = math.ceil(abs(a[1] - b[1]) / 2.0)
        return dx + climbs * CLIMB_S


# --- Reglas ---

def _telegraphs(boss, root):
    """(nombre, cuadros) de todos los avisos de la pelea."""
    out = []
    p1, p2, p3 = boss.get("phase1", {}), boss.get("phase2", {}), boss.get("phase3", {})
    for name, value in (("fase 1: escupir Burbujas", p1.get("spit_warn_frames")),
                        ("fase 2: pop-up", p2.get("popup_warn_frames")),
                        ("fase 2: rafaga", p2.get("burst_warn_frames")),
                        ("fase 3: dividirse", p3.get("split_warn_frames")),
                        ("fase 3: lanzamiento", p3.get("launch_warn_frames"))):
        out.append((name, value))
    banner = load_json(os.path.join(root, "data", "enemies", "spam_banner.json"))
    out.append(("fase 1: barrido (spam_banner)", banner.get("anticipation_frames")))
    bell = load_json(os.path.join(root, "data", "enemies", "alarm_bell.json"))
    out.append(("fase 3: campana (alarm_bell)", bell.get("anticipation_frames")))
    catalog = load_json(os.path.join(root, "data", "world1_objects.json"))
    out.append(("fase 3: plataforma que parpadea", catalog.get("blink_platform", {}).get("warn_frames")))
    return out


def anim_fps(boss):
    return float(boss.get("arena", {}).get("anim_fps", 12.0))


def check_lanes(arena, boss, root, errors, report):
    """Carriles: alcanzables, separados (refugio) y nunca barridos a la vez."""
    T = arena.T
    banner = load_json(os.path.join(root, "data", "enemies", "spam_banner.json"))
    lanes = {}
    for lane in ("floor", "high"):
        if lane not in arena.lanes:
            _err(errors, "falta el carril '%s' en arena.lanes" % lane)
            return
        cells = arena.lane_cells(lane)
        reach = [c for c in cells if c in arena.reachable]
        if not reach:
            _err(errors, "el carril '%s' no tiene celdas de pie alcanzables desde P" % lane)
        lanes[lane] = float(arena.lanes[lane]["surface_row"]) * T
    hb = arena.rules.hitbox_h
    shot_h = float(boss.get("phase2", {}).get("shot_size_px", [64, 32])[1])
    dmg_h = float(banner["damage_size"][1])
    dmg_bottom = float(banner["damage_bottom_px"])
    for lane, feet in lanes.items():
        bands = [("barrido", feet - dmg_bottom - dmg_h, feet - dmg_bottom),
                 ("rafaga", feet + arena.rules.phone_y - shot_h / 2.0, feet + arena.rules.phone_y + shot_h / 2.0)]
        for other, ofeet in lanes.items():
            if other == lane:
                continue
            for what, top, bottom in bands:
                if top < ofeet and bottom > ofeet - hb:
                    _err(errors, "el %s del carril '%s' alcanza a Isak de pie en el carril '%s' (no hay refugio)"
                         % (what, lane, other))
    # Fase 1: barridos alternos.
    p1 = boss.get("phase1", {})
    interval = float(p1.get("sweep_interval_s", 0.0))
    warn = float(banner["anticipation_frames"]) / float(banner["anim_fps"])
    busy = 0.0
    for sw in p1.get("sweeps", []):
        lane = arena.lanes.get(sw.get("lane"))
        if lane is None:
            _err(errors, "fase 1: barrido en un carril desconocido '%s'" % sw.get("lane"))
            continue
        span = int(lane["to_col"]) - int(lane["from_col"]) + 1
        entry = int(sw.get("entry_col", -1))
        d = int(sw.get("direction", 0))
        if not ((entry == int(lane["from_col"]) and d == 1) or (entry == int(lane["to_col"]) and d == -1)):
            _err(errors, "fase 1: el barrido del carril '%s' debe entrar por un extremo hacia dentro" % sw.get("lane"))
        r = int(lane["surface_row"]) - 1
        for c in range(int(lane["from_col"]), int(lane["to_col"]) + 1):
            if arena.solid(c, r):
                _err(errors, "fase 1: celda solida en el pasillo del barrido del carril '%s'" % sw.get("lane"), r, c)
                break
        sweep = (span * T - float(banner["banner_size"][0])) / float(banner["sweep_speed_px_s"])
        busy = max(busy, warn + sweep)
    lanes_used = {sw.get("lane") for sw in p1.get("sweeps", [])}
    if len(lanes_used) > 1 and busy > interval + EPS:
        _err(errors, "fase 1: un barrido dura %.2f s (aviso + recorrido) y salen cada %.2f s: barrerian los dos "
                     "carriles a la vez" % (busy, interval))
    report["sweep_busy_s"] = round(busy, 3)
    report["sweep_interval_s"] = interval
    # Fase 2: rafagas.
    p2 = boss.get("phase2", {})
    lane = arena.lanes.get("floor", {})
    span = (int(lane.get("to_col", 0)) - int(lane.get("from_col", 0)) + 1) * T
    burst = float(p2.get("burst_warn_frames", 9)) / anim_fps(boss) \
        + (int(p2.get("burst_shots", 1)) - 1) * float(p2.get("burst_spacing_s", 0.0)) \
        + span / max(float(p2.get("shot_speed_px_s", 1.0)), 1.0)
    every = float(p2.get("burst_every_s", 0.0))
    if burst > every + EPS:
        _err(errors, "fase 2: una rafaga dura %.2f s (aviso + disparos + cruce) y salen cada %.2f s: dos rafagas "
                     "(y dos carriles) a la vez" % (burst, every))
    report["burst_busy_s"] = round(burst, 3)
    report["burst_every_s"] = every
    # Rafaga atravesable con el dash (§6.4): entre dos notificaciones (tiempo del mundo; el caso peor es sin el
    # Debug, a x1) el dash vuelve a estar listo (duracion + enfriamiento, tiempo real) y cada notificacion
    # pasa por Isak dentro de la invulnerabilidad del dash. El dash acerca a Isak dash_distance a la siguiente
    # (dash_distance / velocidad de la notificacion antes); en el enfriamiento vuelve corriendo hacia atras,
    # aprox. la mitad del enfriamiento a run_speed (la otra mitad frena la velocidad de salida del dash).
    # Calibrado con el Isak real en tests/test_alert_major.gd (0,85 s no basta; 0,9 s si).
    r = arena.rules
    spacing = float(p2.get("burst_spacing_s", 0.0))
    retreat = min(r.dash_distance, r.run_speed * r.dash_cooldown_s * DASH_RETREAT_FRACTION)
    cycle = r.dash_duration + r.dash_cooldown_s \
        + (r.dash_distance - retreat) / max(float(p2.get("shot_speed_px_s", 1.0)), 1.0)
    shot_w = float(p2.get("shot_size_px", [64, 32])[0])
    passing = (shot_w + r.hitbox_w) / max(float(p2.get("shot_speed_px_s", 1.0)), 1.0)
    if int(p2.get("burst_shots", 1)) > 1 and spacing + EPS < cycle:
        _err(errors, "fase 2: las notificaciones de la rafaga salen cada %.2f s y el dash tarda %.2f s en volver: "
                     "no se atraviesa con el dash" % (spacing, cycle))
    if passing > r.dash_invulnerable_s + EPS:
        _err(errors, "fase 2: una notificacion tarda %.2f s en pasar por Isak y el dash es invulnerable %.2f s"
                     % (passing, r.dash_invulnerable_s))
    report["burst_dash"] = {"spacing_s": spacing, "dash_cycle_s": round(cycle, 3), "pass_s": round(passing, 3),
                            "invulnerable_s": r.dash_invulnerable_s}


def check_chargers(arena, boss, errors, report):
    model = boss.get("validation_model", {})
    max1 = float(model.get("charger_max_tiles", 4))
    max2 = float(model.get("charger_second_max_tiles", 7))
    floor = arena.lane_cells("floor") if "floor" in arena.lanes else []
    xs = [c for c, r, _ in arena.chargers]
    if not xs:
        _err(errors, "la arena no tiene cargadores")
        return
    worst1 = worst2 = 0.0
    for c, r in floor:
        d = sorted(abs(c - x) for x in xs)
        worst1 = max(worst1, d[0])
        if d[0] > max1 + EPS:
            _err(errors, "celda del suelo sin cargador a %g tiles o menos (el mas cercano a %d)" % (max1, d[0]), r, c)
        if len(d) > 1:
            worst2 = max(worst2, d[1])
            if d[1] > max2 + EPS:
                _err(errors, "celda del suelo sin un segundo cargador a %g tiles o menos (a %d)" % (max2, d[1]), r, c)
    down = boss.get("arena", {}).get("body_down_px", [128, 128])
    spot = boss.get("phase1", {}).get("window_spot")
    if spot in arena.spots:
        fx, _ = arena.spot_feet(spot)
        lo, hi = (fx - float(down[0]) / 2.0) / arena.T, (fx + float(down[0]) / 2.0) / arena.T
    else:
        lo = hi = None
    for c, r, params in arena.chargers:
        if lo is not None and lo - 1 <= c < hi + 1:
            _err(errors, "cargador en la zona donde aterriza el jefe en la fase 1", r, c)
        for rr in range(r - 2, r):
            if 0 <= rr < arena.rows and arena.grid[rr][c] == "-":
                _err(errors, "cargador bajo una plataforma", r, c)
                break
        if (c, r) not in arena.reachable:
            _err(errors, "cargador no alcanzable desde P", r, c)
    report["charger_worst_tiles"] = worst1
    report["charger_second_worst_tiles"] = worst2


def check_telegraphs(boss, root, errors, report, world_scale=1.0):
    """Avisos en cuadros del mundo (6-12). Con el Debug el mundo va a `world_scale` (<= 1): en tiempo real
    duran 1 / world_scale veces mas, nunca menos que sin el Debug (accesibilidad, §6.4)."""
    lo, hi = TELEGRAPH_FRAMES
    items = []
    for name, frames in _telegraphs(boss, root):
        if not isinstance(frames, (int, float)) or not lo <= frames <= hi:
            _err(errors, "aviso de '%s': %s cuadros (deben ser de %d a %d)" % (name, frames, lo, hi))
        items.append((name, frames))
    if not 0.0 < world_scale <= 1.0 + EPS:
        _err(errors, "con el Debug el mundo va a x%g: los avisos durarian menos que sin el Debug" % world_scale)
    check_art_telegraphs(boss, errors, report)
    report["telegraphs"] = items
    report["debug_world_scale"] = round(world_scale, 3)


def check_art_telegraphs(boss, errors, report):
    """Arte final (paso 16, 2026-10-22): la animacion de inflarse (aviso de escupir y de dividirse) va por
    tiempo y no puede durar mas que esos avisos (si no, el ataque saldria con el cuerpo a medio inflar) ni
    menos de 6 cuadros del mundo; el aviso del lanzamiento (lunge_warn) y el lanzamiento (lunge) van por la
    fraccion de su tiempo en el codigo, asi que duran exactamente launch_warn_frames y lunge_s. Los tiempos
    los manda el codigo: el arte nunca acorta un aviso."""
    art = boss.get("art")
    if not art:
        return
    anims = art.get("anims", {})
    fps = anim_fps(boss)
    lo = TELEGRAPH_FRAMES[0] / fps
    inflate = anims.get("inflate")
    if inflate:
        dur = float(inflate.get("frames", 0)) / float(inflate.get("fps", 12.0))
        for name, frames in (("escupir", boss.get("phase1", {}).get("spit_warn_frames")),
                             ("dividirse", boss.get("phase3", {}).get("split_warn_frames"))):
            if isinstance(frames, (int, float)) and dur > frames / fps + EPS:
                _err(errors, "arte: inflate dura %.2f s, mas que el aviso de %s (%.2f s)" % (dur, name, frames / fps))
        if dur < lo - EPS:
            _err(errors, "arte: inflate dura %.2f s (< %d cuadros del mundo)" % (dur, TELEGRAPH_FRAMES[0]))
        report["art_inflate_s"] = round(dur, 3)
    for name in ("hover", "inflate", "descend", "ascend", "window", "lunge_warn", "lunge"):
        if name not in anims:
            _err(errors, "arte: falta la animacion '%s' en art.anims" % name)


def _reach_cells(arena, spot):
    """(celdas de pulso, celdas de laser) alcanzables desde P para el nucleo en `spot`."""
    core = arena.core_pos(spot)
    radius = arena.rules.pulse_radius + float(load_json(os.path.join(arena.rules.root, "data", "weak_point.json"))
                                                 ["radius_px"])
    core_r = radius - arena.rules.pulse_radius
    pulse, laser = [], []
    for node in sorted(arena.reachable):
        for facing in (1.0, -1.0):
            px, py = arena.phone(node, facing)
            if math.hypot(px - core[0], py - core[1]) <= radius + EPS:
                pulse.append((node, facing))
            dx = core[0] - px
            if abs(py - core[1]) <= core_r and dx * facing > 0 and abs(dx) <= arena.rules.laser_range:
                r = node[1]
                c0, c1 = sorted((int(px // arena.T), int(core[0] // arena.T)))
                if not any(arena.solid(c, r) for c in range(c0, c1 + 1)):
                    laser.append((node, facing))
    return pulse, laser


def _window_need(arena, travel):
    """Tiempo del mundo minimo de una ventana con el recorrido `travel` (s reales): la mejor de dos
    estrategias (Debug al llegar o Debug primero)."""
    r = arena.rules
    poses = r.pulse_pose_s + r.laser_pose_s
    after = travel + r.debug_hold_s + r.debug_world_scale * poses
    first = r.debug_hold_s + r.debug_world_scale * (travel + poses)
    # Debug cargado en marcha (§6.4): la carga no para a Isak (solo impide el dash); corre mientras carga y el
    # resto del recorrido va ya con el mundo lento.
    running = r.debug_hold_s + r.debug_world_scale * (max(travel - r.debug_hold_s, 0.0) + poses)
    return min(after, first, running)


def check_windows(arena, boss, errors, report):
    model = boss.get("validation_model", {})
    k = float(model.get("window_k", 2.0))
    froms = model.get("window_from", {})
    p1, p2, p3 = boss.get("phase1", {}), boss.get("phase2", {}), boss.get("phase3", {})
    out = []

    def from_cells(phase):
        spec = froms.get(str(phase), {"lane": "floor", "cols": [0, arena.cols - 1]})
        cells = [n for n in arena.lane_cells(spec.get("lane", "floor"))
                 if spec["cols"][0] <= n[0] <= spec["cols"][1] and n in arena.reachable]
        return cells

    def worst_travel(cells, targets):
        if not cells or not targets:
            return None
        return max(min(arena.travel_s(a, b) for b in targets) for a in cells)

    def spot_check(phase, spot, window_s, travel_from=True, label=None):
        label = label or spot
        if spot not in arena.spots:
            _err(errors, "fase %d: sitio '%s' no esta en arena.spots" % (phase, spot))
            return
        pulse, laser = _reach_cells(arena, spot)
        if not pulse:
            _err(errors, "fase %d: el nucleo en '%s' no se alcanza con el pulso desde ninguna celda de pie" % (phase, spot))
        if not laser:
            _err(errors, "fase %d: el nucleo en '%s' no se alcanza con el laser desde ninguna celda de pie" % (phase, spot))
        if not pulse:
            return
        travel = worst_travel(from_cells(phase), [n for n, _ in pulse]) if travel_from else 0.0
        if travel is None:
            _err(errors, "fase %d: no hay celdas de salida (window_from) alcanzables" % phase)
            return
        need = k * _window_need(arena, travel)
        if window_s + EPS < need:
            _err(errors, "fase %d: la ventana en '%s' dura %.2f s del mundo y hacen falta %.2f (k = %g x (recorrido "
                         "%.2f s + Debug + poses))" % (phase, label, window_s, need, k, travel))
        out.append({"phase": phase, "spot": label, "window_s": window_s, "need_s": round(need, 3),
                    "travel_s": round(travel, 3), "pulse_cells": len(pulse), "laser_cells": len(laser)})

    spot_check(1, p1.get("window_spot"), float(p1.get("window_s", 0.0)))
    # Fase 2: escudo (boton al alcance del pulso) y ventana desde la plataforma.
    shield = p2.get("shield", {})
    down = boss.get("arena", {}).get("body_down_px", [128, 128])
    for spot in p2.get("perch_spots", []):
        spot_check(2, spot, float(p2.get("window_s", 0.0)), travel_from=False)
        if spot not in arena.spots:
            continue
        fx, fy = arena.spot_feet(spot)
        left, top = fx - float(down[0]) / 2.0, fy - float(down[1])
        bx, by = shield.get("close_button_px", [0, 0])
        size = float(shield.get("close_button_size_px", 24))
        rect = (left + float(bx), top + float(by), size, size)
        cells = []
        for node in arena.reachable:
            for facing in (1.0, -1.0):
                px, py = arena.phone(node, facing)
                cx = min(max(px, rect[0]), rect[0] + rect[2])
                cy = min(max(py, rect[1]), rect[1] + rect[3])
                if math.hypot(px - cx, py - cy) <= arena.rules.pulse_radius + EPS:
                    cells.append(node)
        if not cells:
            _err(errors, "fase 2: el boton del escudo en '%s' no se alcanza con el pulso" % spot)
            continue
        travel = worst_travel(from_cells(2), cells)
        need = k * (travel + arena.rules.pulse_pose_s) if travel is not None else 0.0
        perch = float(p2.get("perch_s", 0.0))
        if perch + EPS < need:
            _err(errors, "fase 2: el escudo en '%s' espera %.2f s y hacen falta %.2f para llegar a su boton "
                         "(k = %g)" % (spot, perch, need, k))
        out.append({"phase": 2, "spot": spot + " (escudo)", "window_s": perch, "need_s": round(need, 3),
                    "travel_s": round(travel or 0.0, 3), "pulse_cells": len(set(cells)), "laser_cells": 0})
    spots = p3.get("copy_spots", [])
    copies = max(int(e.get("phase3", {}).get("copies", 3)) for e in boss.get("laps", {}).values())
    for spot in spots[:copies]:
        spot_check(3, spot, float(p3.get("window_s", 0.0)))
    report["windows"] = out


def _intervals_overlap(a, b, cycle):
    """Dos intervalos [inicio, fin) modulo `cycle` se solapan."""
    for s1, e1 in _wrap(a, cycle):
        for s2, e2 in _wrap(b, cycle):
            if s1 < e2 - EPS and s2 < e1 - EPS:
                return True
    return False


def _wrap(iv, cycle):
    s, e = iv[0] % cycle, iv[0] % cycle + (iv[1] - iv[0])
    if e <= cycle + EPS:
        return [(s, e)]
    return [(s, cycle), (0.0, e - cycle)]


def check_phase3(arena, boss, root, errors, report):
    bell_data = load_json(os.path.join(root, "data", "enemies", "alarm_bell.json"))
    catalog = load_json(os.path.join(root, "data", "world1_objects.json"))
    blink_cfg = catalog.get("blink_platform", {})
    bwarn = float(blink_cfg.get("warn_frames", 9)) / float(blink_cfg.get("anim_fps", 12.0))
    extra = float(blink_cfg.get("min_on_extra_s", 0.25))
    warn = float(bell_data["anticipation_frames"]) / float(bell_data["anim_fps"])
    bells = [e for e in arena.level.get("enemies", []) if e.get("type") == "alarm_bell" and 3 in e.get("active_in_phase", [])]
    blinks = [o for o in arena.level.get("objects", []) if o.get("type") == "blink_platform"
              and 3 in o.get("active_in_phase", [])]
    spots = boss.get("phase3", {}).get("copy_spots", [])
    out = {}
    for lap, entry in sorted(boss.get("laps", {}).items()):
        p3 = entry.get("phase3", {})
        steps = [float(v) for v in p3.get("tempo_steps_s", [])]
        if not steps:
            _err(errors, "vuelta %s: phase3.tempo_steps_s vacio" % lap)
            continue
        shortest = min(steps)
        copies, launches = int(p3.get("copies", 3)), int(p3.get("launches_per_round", 3))
        if copies > len(spots):
            _err(errors, "vuelta %s: %d copias y solo %d sitios (phase3.copy_spots)" % (lap, copies, len(spots)))
        if launches > copies:
            _err(errors, "vuelta %s: %d lanzamientos por ronda y solo %d copias" % (lap, launches, copies))
        for b in bells:
            wave = float(b.get("params", {}).get("wave_s", bell_data["wave_s"]))
            need = warn + wave + float(bell_data.get("min_rest_s", 0.0))
            if shortest + EPS < need:
                _err(errors, "vuelta %s: la campana %s no cabe en el compas de %.2f s (aviso + onda + reposo %.2f s)"
                     % (lap, b["id"], shortest, need))
        for cycle in steps:
            waves = []
            for b in bells:
                p = b.get("params", {})
                wave = float(p.get("wave_s", bell_data["wave_s"]))
                start = float(p.get("offset", 0.0)) * cycle + warn
                waves.append((b["id"], (start, start + wave)))
            for i in range(len(waves)):
                for j in range(i + 1, len(waves)):
                    if _intervals_overlap(waves[i][1], waves[j][1], cycle):
                        _err(errors, "vuelta %s: con el compas de %.2f s suenan a la vez %s y %s (sin hueco seguro)"
                             % (lap, cycle, waves[i][0], waves[j][0]))
        on = float(p3.get("blink_on_fraction", 0.5))
        if blinks and on * shortest + EPS < bwarn + extra:
            _err(errors, "vuelta %s: plataformas que parpadean encendidas %.2f s con el compas de %.2f s: menos que el "
                         "aviso (%.2f s) + %.2f s" % (lap, on * shortest, shortest, bwarn, extra))
        out[lap] = {"tempo_steps_s": steps, "copies": copies, "launches_per_round": launches, "blink_on_fraction": on}
    report["phase3"] = out
    # Campanas fuera de las plataformas que parpadean (§6.4): su onda no cae encima de las laterales, que son el
    # sitio para subir y disparar al nucleo.
    T = arena.T
    half = float(bell_data.get("damage_width_px", 48.0)) / 2.0
    for b in bells:
        cx = (int(b["x"]) + 0.5) * T
        for o in blinks:
            w = int(o.get("params", {}).get("width_tiles", 2))
            if cx + half > int(o["x"]) * T + EPS and cx - half < (int(o["x"]) + w) * T - EPS:
                _err(errors, "la onda de la campana %s cae encima de la plataforma que parpadea %s"
                     % (b["id"], o.get("params", {}).get("id")), int(b["y"]), int(b["x"]))
    report["bell_cols"] = sorted(int(b["x"]) for b in bells)


def phase3_geometry(level):
    """Nivel de la fase 3 para el modelo de movimiento: las celdas de las plataformas que parpadean son '-' si
    son de una via (one_way) y '#' si no (cajas macizas: no se suben desde debajo)."""
    geo = geometry_level(level)
    grid = [list(row) for row in geo["grid"]]
    for o in level.get("objects", []):
        if o.get("type") != "blink_platform" or 3 not in o.get("active_in_phase", []):
            continue
        p = o.get("params", {})
        for c in range(int(o["x"]), int(o["x"]) + int(p.get("width_tiles", 2))):
            grid[int(o["y"])][c] = "-" if p.get("one_way") else "#"
    geo["grid"] = ["".join(r) for r in grid]
    return geo


def _climb_path(model, sources, targets, limit):
    """Mejor camino (lista de (desde, hasta, tipo, dash)) desde alguna celda de `sources` a una de `targets`."""
    best = None
    for src in sources:
        cost, parent = vl.search(model, src, model.initial, limit, debug=False)
        for t in targets:
            if t not in cost:
                continue
            path, n = [], t
            while parent.get(n):
                p, e = parent[n]
                path.append((p, e["to"], e.get("kind"), bool(e.get("dash"))))
                n = p
            path.reverse()
            key = (cost[t], len(path))
            if best is None or key < best[0]:
                best = (key, path)
    return best[1] if best else None


def check_center_climb(arena, boss, root, errors, report):
    """Regla 7c: subida a la plataforma central en la fase 3 (accesos con copia en CENTER_SPOT)."""
    spots = boss.get("phase3", {}).get("copy_spots", [])
    if CENTER_SPOT not in spots or CENTER_SPOT not in arena.spots:
        return
    idx = spots.index(CENTER_SPOT)
    laps = [lap for lap, e in sorted(boss.get("laps", {}).items())
            if int(e.get("phase3", {}).get("copies", 3)) > idx]
    if not laps:
        return
    rules, T = arena.rules, arena.T
    level = arena.level
    _, surface = arena.spots[CENTER_SPOT]
    row = surface - 1
    center_cells = [(c, row) for c in range(arena.cols) if arena.world.is_node(c, row)]
    blinks = [o for o in level.get("objects", []) if o.get("type") == "blink_platform"
              and 3 in o.get("active_in_phase", [])]
    lateral_rows = {int(o["y"]) - 1 for o in blinks}
    lateral_cols = {c for o in blinks for c in range(int(o["x"]), int(o["x"]) + int(o.get("params", {}).get("width_tiles", 2)))}
    spec = boss.get("validation_model", {}).get("window_from", {}).get("3", {"lane": "floor", "cols": [0, arena.cols]})
    sources = [n for n in arena.lane_cells(spec.get("lane", "floor")) if spec["cols"][0] <= n[0] <= spec["cols"][1]]
    out = {"cells": len(center_cells)}
    paths = {}
    for name, dash in (("sin dash", False), ("salto + dash aereo", True)):
        geo = phase3_geometry(level)
        geo["abilities_available"] = dict(geo.get("abilities_available", {}), dash=dash)
        model = vl.Validator(geo, rules).model
        path = _climb_path(model, sources, center_cells, rules.limit)
        if path is not None:
            paths[name] = path
    if not paths:
        _err(errors, "fase 3: la plataforma central no se alcanza desde el suelo (ni con el salto + dash aereo) con "
                     "las laterales de la fase 3")
        report["center_climb"] = out
        return
    # Con el Debug activo no hay dash: si el camino sin dash existe, el Debug puede seguir encendido.
    name = "sin dash" if "sin dash" in paths else "salto + dash aereo"
    path = paths[name]
    out["path"] = name
    out["paths"] = sorted(paths)
    out["moves"] = ["%s %s->%s" % (k + (" (dash)" if d else ""), a, b) for a, b, k, d in path]
    # Tiempo de pie en la lateral: de aterrizar a despegar (reaccion + lo que ande por ella).
    stand = LATERAL_REACT_S
    used_lateral = False
    for a, b, kind, dash in path:
        if b[1] in lateral_rows and b[0] in lateral_cols:
            used_lateral = True
        if a[1] in lateral_rows and b[1] == a[1] and a[0] in lateral_cols:
            stand += abs(b[0] - a[0]) * T / rules.run_speed
    out["via_lateral"] = used_lateral
    catalog = load_json(os.path.join(root, "data", "world1_objects.json"))
    cfg = catalog.get("blink_platform", {})
    warn = float(cfg.get("warn_frames", 9)) / float(cfg.get("anim_fps", 12.0))
    bell_data = load_json(os.path.join(root, "data", "enemies", "alarm_bell.json"))
    half = float(bell_data.get("damage_width_px", 48.0)) / 2.0 + rules.hitbox_w / 2.0
    bells = [(e, (int(e["x"]) + 0.5) * T) for e in level.get("enemies", [])
             if e.get("type") == "alarm_bell" and 3 in e.get("active_in_phase", [])]

    def under_bell(node):
        x = (node[0] + 0.5) * T
        return [e["id"] for e, cx in bells if abs(x - cx) < half - EPS]

    landing = path[-1][1]
    if under_bell(landing):
        _err(errors, "fase 3: se llega a la plataforma central bajo la campana %s" % under_bell(landing)[0],
             landing[1], landing[0])
    pulse, _ = _reach_cells(arena, CENTER_SPOT)
    safe = sorted({n for n, _ in pulse if n[1] == row and not under_bell(n)})
    if not safe:
        _err(errors, "fase 3: en la plataforma central no hay sitio fuera de la onda de las campanas desde el que el "
                     "pulso llegue al nucleo")
    out["safe_pulse_cells"] = len(safe)
    out["landing"] = landing
    out["stand_s"] = round(stand, 3)
    k = float(boss.get("validation_model", {}).get("window_k", 2.0))
    window = float(boss.get("phase3", {}).get("window_s", 0.0))
    travel = max(min(arena.travel_s(a, b) for b in center_cells) for a in sources if a in arena.reachable)
    laps_out = {}
    for lap in laps:
        p3 = boss["laps"][lap].get("phase3", {})
        cycle = min(float(v) for v in p3.get("tempo_steps_s", [2.0]))
        on = float(p3.get("blink_on_fraction", 0.5)) * cycle
        wait = cycle - on
        if used_lateral and on + EPS < warn + stand:
            _err(errors, "vuelta %s: la lateral encendida %.2f s con el compas de %.2f s no da para aterrizar y "
                         "despegar (%.2f s) antes de su aviso (%.2f s)" % (lap, on, cycle, stand, warn))
        if name == "sin dash":
            base = _window_need(arena, travel)
        else:
            # Soltando el Debug para el dash: recorrido a x1 y despues la carga.
            base = travel + rules.debug_hold_s + rules.debug_world_scale * (rules.pulse_pose_s + rules.laser_pose_s)
        need = k * (base + (wait if used_lateral else 0.0))
        if window + EPS < need:
            _err(errors, "vuelta %s: la ventana en la central dura %.2f s del mundo y hacen falta %.2f (k = %g x "
                         "(recorrido %.2f s + espera a la lateral %.2f s + Debug + poses))"
                 % (lap, window, need, k, travel, wait))
        laps_out[lap] = {"on_s": round(on, 3), "margin_s": round(on - warn - stand, 3), "wait_s": round(wait, 3),
                         "need_s": round(need, 3), "window_s": window}
    out["laps"] = laps_out
    report["center_climb"] = out


def mark_shots(rules, seconds):
    """Laseres que caben en `seconds` reales desde la marca: el primero tras su pose y cada uno de los siguientes
    tras la pose y el enfriamiento (cuenta conservadora)."""
    if seconds + EPS < rules.laser_pose_s:
        return 0
    return 1 + int(math.floor((seconds - rules.laser_pose_s) / (rules.laser_pose_s + rules.laser_cooldown_s) + EPS))


def check_mark(arena, boss, errors, report):
    """La marca (mark_duration_s, tiempo del mundo) en el caso peor (sin el Debug, el mundo a x1) da para los
    laseres de la peor ventana de la pelea torpe; informa de lo que dura en tiempo real con el Debug."""
    rules = arena.rules
    model = boss.get("validation_model", {})
    misses = int(model.get("misses_per_window", 1))
    out = {}
    for lap, entry in sorted(boss.get("laps", {}).items()):
        mark = float(entry.get("mark_duration_s", 0.0))
        lm = model.get("laps", {}).get(str(lap), {})
        worst = max((h for windows in lm.get("windows", []) for h in windows), default=0)
        cap = int(entry.get("pause_hits", 0))
        if cap > 0:
            # Autoplay: cada pausa se acaba tras pause_hits impactos de laser (el modelo torpe no puede pedir mas).
            if worst > cap:
                _err(errors, "vuelta %s: la pelea torpe pide %d golpe(s) en una ventana y cada pausa da %d (pause_hits)"
                     % (lap, worst, cap))
            worst = min(worst, cap)
        need = int(math.ceil(worst)) + misses
        shots = mark_shots(rules, mark)
        if shots < need:
            _err(errors, "vuelta %s: en la marca de %.2f s caben %d laser(es) y la peor ventana torpe pide %d "
                         "(%d golpe(s) + %d fallado(s))" % (lap, mark, shots, need, worst, misses))
        scale = max(rules.debug_world_scale, EPS)
        out[lap] = {"mark_s": mark, "real_with_debug_s": round(mark / scale, 3), "shots": shots,
                    "shots_with_debug": mark_shots(rules, mark / scale), "need": need}
        if cap > 0:
            out[lap]["pause_hits"] = cap
    report["mark"] = out


# --- Energia ---

def energy_rules(base_rules, upgrades):
    rules = base_rules.with_upgrades(upgrades) if upgrades else base_rules
    damage = upgrade_catalog.effective_value(rules.upgrade_catalog, rules.upgrade_levels,
                                             "isak_abilities.laser_damage", 1.0)
    return rules, max(int(round(damage)), 1)


def energy_lap(arena, boss, lap, rules, laser_damage, errors, scenario, root):
    model = boss.get("validation_model", {})
    lm = model.get("laps", {}).get(str(lap))
    entry = boss.get("laps", {}).get(str(lap), {})
    if lm is None:
        _err(errors, "validation_model.laps sin la vuelta %s" % lap)
        return None
    scale = float(arena.level.get("debug_drain_scale", 1.0))
    drain = rules.debug_drain * scale
    margin = float(model.get("min_margin", 20.0))
    emax = rules.energy_max
    misses = int(model.get("misses_per_window", 1))
    dashes = model.get("dashes_per_window", [1, 1, 0])
    extra = model.get("extra_debug_s", [0, 0, 0])
    early = model.get("early_debug_s", [0, 0, 0])
    kills = model.get("bubble_kills", [0, 0, 0])
    launches = int(entry.get("phase3", {}).get("launches_per_round", 3))
    hits = entry.get("hits_per_phase", [])
    bubble = load_json(os.path.join(root, "data", "enemies", "alert_bubble.json"))
    drop = float(bubble.get("drops", {}).get("debug_energy", 0.0))
    bubble_lasers = math.ceil(float(bubble.get("health", 2.0)) / laser_damage)
    refill = float(boss.get("phase_change_refill", {}).get("energy", 0.0))
    charge = max((float(p.get("amount", 50.0)) for _, _, p in arena.chargers), default=50.0)
    detour = float(model.get("detour_s_per_charge", 1.3))
    energy = emax
    phases = []
    for p, windows in enumerate(lm.get("windows", [])):
        if p < len(hits) and sum(windows) != hits[p]:
            _err(errors, "validation_model vuelta %s fase %d: las ventanas suman %d golpes y la fase tiene %d"
                 % (lap, p + 1, sum(windows), hits[p]))
        n_dash = launches if p == 2 else int(dashes[p] if p < len(dashes) else 0)
        peaks = []
        for h in windows:
            debug_s = float(lm["debug_s"][p]) + float(extra[p] if p < len(extra) else 0.0)
            if h == 0:
                debug_s += float(early[p] if p < len(early) else 0.0)
            lasers = math.ceil(h / laser_damage) + misses
            peaks.append(debug_s * drain + n_dash * rules.dash_cost + lasers * rules.laser_cost)
        peak = max(peaks) if peaks else 0.0
        kill = int(kills[p] if p < len(kills) else 0)
        spend = sum(peaks) + kill * bubble_lasers * rules.laser_cost
        income = kill * drop + (refill if p > 0 else 0.0)
        need = max(0.0, spend - energy - income)
        charges = int(math.ceil(need / charge - EPS)) if need > 0 else 0
        energy = min(emax, energy + income + charges * charge - spend)
        if peak > emax - margin + EPS:
            _err(errors, "%s, vuelta %s, fase %d: pico de la pelea torpe %.1f con %.0f de energia (margen %.1f < %.0f)"
                 % (scenario, lap, p + 1, peak, emax, emax - peak, margin))
        phases.append({"peak": round(peak, 2), "margin": round(emax - peak, 2), "spend": round(spend, 2),
                       "charges": charges, "detour_s": round(charges * detour, 2), "end_energy": round(energy, 2)})
    return {"energy_max": emax, "debug_drain_per_s": round(drain, 3), "laser_cost": rules.laser_cost,
            "laser_damage": laser_damage, "dash_cost": rules.dash_cost, "phases": phases,
            "min_margin": round(min((ph["margin"] for ph in phases), default=0.0), 2),
            "total_spend": round(sum(ph["spend"] for ph in phases), 2),
            "total_charges": sum(ph["charges"] for ph in phases),
            "total_detour_s": round(sum(ph["detour_s"] for ph in phases), 2)}


def check_energy(arena, boss, base_rules, upgrades, errors, report, root, lap_fn=None):
    lap_fn = lap_fn or energy_lap
    catalog = base_rules.upgrade_catalog
    out = {}
    for lap in sorted(boss.get("laps", {}), key=int):
        cap = ["%s:%d" % (t["id"], upgrade_catalog.access_cap(catalog, t["id"], int(lap)))
               for t in upgrade_catalog.tracks(catalog)]
        top = ["%s:%d" % (t["id"], max(int(lv["level"]) for lv in t.get("levels", [])))
               for t in upgrade_catalog.tracks(catalog)]
        scenarios = [("base", []), ("tope del acceso", cap), ("todo al maximo", top)]
        if upgrades:
            scenarios.append(("mejoras %s" % ",".join(upgrades), list(upgrades)))
        lap_out = {}
        for name, ups in scenarios:
            rules, damage = energy_rules(base_rules, ups)
            res = lap_fn(arena, boss, int(lap), rules, damage, errors, name, root)
            if res is not None:
                lap_out[name] = res
        out[lap] = lap_out
    report["energy"] = out


# --- Entrada ---

def validate_arena(level, root=ROOT, boss=None, upgrades=(), physics_path=None,
                   jump_efficiency=vl.DEFAULT_JUMP_EFFICIENCY, limit=vl.DEFAULT_LIMIT):
    """Valida una arena de jefe ya cargada (y con el esquema comprobado). `boss`: datos del jefe (por defecto
    data/bosses/<level.boss>.json; las pruebas pasan uno modificado)."""
    errors, warnings = [], []
    if boss is None:
        boss = load_json(os.path.join(root, "data", "bosses", "%s.json" % level["boss"]))
    if boss.get("id") == "autoplay":
        return validate_autoplay_arena(level, boss, root, upgrades, physics_path, jump_efficiency, limit)
    if boss.get("id") != "alert_major":
        return validate_basic_arena(level, boss, root, physics_path, jump_efficiency, limit)
    rules = vl.Rules(root, physics_path, jump_efficiency, limit, True)
    # Escala del mundo con el Debug propia de la arena (debug_world_scale, §6.4); sin el campo, la global.
    rules.set_level_debug_world_scale(level.get("debug_world_scale"))
    arena = Arena(level, boss, rules)
    report = {"boss": boss.get("id"), "reachable_cells": len(arena.reachable)}
    check_lanes(arena, boss, root, errors, report)
    check_chargers(arena, boss, errors, report)
    check_telegraphs(boss, root, errors, report, rules.debug_world_scale)
    check_windows(arena, boss, errors, report)
    check_phase3(arena, boss, root, errors, report)
    check_mark(arena, boss, errors, report)
    check_center_climb(arena, boss, root, errors, report)
    check_energy(arena, boss, rules, list(upgrades), errors, report, root)
    return {"ok": not errors, "errors": errors, "warnings": warnings, "path": [], "boss": report}


# Pantalla de referencia (resolucion base del juego).
SCREEN_PX = (1280, 720)


def validate_basic_arena(level, boss, root=ROOT, physics_path=None,
                         jump_efficiency=vl.DEFAULT_JUMP_EFFICIENCY, limit=vl.DEFAULT_LIMIT):
    """Comprobaciones basicas de la arena de un jefe sin modelo propio (las de Autoplay hasta su validador
    completo, paso 17 de docs/propuesta-mundo-2.md: validate_autoplay_arena las incluye): cabe entera en
    pantalla, desde P se alcanza el carril del suelo, cada celda del suelo tiene un cargador a
    arena.charger_max_tiles (3,5) o menos y todos los avisos de sus clips duran de 6 a 12 cuadros. Deja un aviso
    de que falta el validador completo."""
    errors, warnings = [], []
    rules = vl.Rules(root, physics_path, jump_efficiency, limit, True)
    rules.set_level_debug_world_scale(level.get("debug_world_scale"))
    arena = Arena(level, boss, rules)
    report = {"boss": boss.get("id"), "reachable_cells": len(arena.reachable)}
    _basic_checks(arena, boss, root, errors, report)
    warnings.append({"message": "validador completo de %s (cabezal, ventanas, cuenta y energia torpe por acceso) "
                                "pendiente" % boss.get("id"),
                     "row": None, "col": None, "object": None})
    return {"ok": not errors, "errors": errors, "warnings": warnings, "path": [], "boss": report}


def _basic_checks(arena, boss, root, errors, report):
    """Pantalla, carril del suelo, cargadores a arena.charger_max_tiles y avisos de los clips (6-12 cuadros)."""
    w, h = arena.cols * arena.T, arena.rows * arena.T
    if w > SCREEN_PX[0] or h > SCREEN_PX[1]:
        _err(errors, "la arena mide %d x %d px y no cabe entera en %d x %d" % (w, h, SCREEN_PX[0], SCREEN_PX[1]))
    floor = arena.lane_cells("floor") if "floor" in arena.lanes else []
    if not floor or not any(c in arena.reachable for c in floor):
        _err(errors, "desde P no se alcanza el carril del suelo")
    max1 = float(boss.get("arena", {}).get("charger_max_tiles", 3.5))
    xs = [c for c, r, _ in arena.chargers]
    worst = worst2 = 0.0
    if not xs:
        _err(errors, "la arena no tiene cargadores")
    for c, r in floor:
        if not xs:
            break
        ds = sorted(abs(c - x) for x in xs)
        d = ds[0]
        worst = max(worst, d)
        if len(ds) > 1:
            worst2 = max(worst2, ds[1])
        if d > max1 + EPS:
            _err(errors, "celda del suelo sin cargador a %g tiles o menos (el mas cercano a %d)" % (max1, d), r, c)
    for c, r, _ in arena.chargers:
        if (c, r) not in arena.reachable:
            _err(errors, "cargador no alcanzable desde P", r, c)
    report["charger_worst_tiles"] = worst
    report["charger_second_worst_tiles"] = worst2
    banner = load_json(os.path.join(root, "data", "enemies", "spam_banner.json"))
    clips = boss.get("clips", {})
    tele = [("ola y barrido", int(banner.get("anticipation_frames", 9))),
            ("rayos", int(clips.get("rays", {}).get("anticipation_frames", 9))),
            ("cuenta atras", int(clips.get("shots", {}).get("warn_frames", 9)))]
    for name, frames in tele:
        if not 6 <= frames <= 12:
            _err(errors, "aviso de %s de %d cuadros (regla: de 6 a 12)" % (name, frames))
    report["telegraphs"] = [(n, "%d cuadros" % f) for n, f in tele]


# --- Autoplay (Mundo 2; paso 17 de docs/propuesta-mundo-2.md, §7.2) ---
#
# Valores de juego: data/bosses/autoplay.json (arena, clips, fases, laps y validation_model), data/levels/2-boss.json
# (geometria, cargadores, debug_drain_scale y debug_world_scale) y los de Rules (fisica, salto, golpe al suelo,
# laser, Debug, dash y mejoras): nada se copia aqui. Reglas:
#   A. Las basicas (_basic_checks): pantalla, carril del suelo, cargadores a <= 3,5 tiles y avisos de 6-12 cuadros.
#   B. Carriles (suelo y barra): la ola del suelo no alcanza a Isak de pie en la barra ni el barrido alto al del
#      suelo (refugio); un clip a la vez (el codigo los encadena). Olas, barridos y proyectiles se atraviesan con el
#      dash a x1 y a la velocidad de cada fase (lo que tardan en pasar por Isak <= invulnerabilidad del dash); un
#      rayo se esquiva dentro de su aviso; cada tanda de rayos deja columnas libres.
#   C. Avisos por fase: los de los clips en cuadros del MUNDO tambien a la speed_scale de la fase 3 (x2): el codigo
#      no los acelera; con el Debug duran 1 / debug_world_scale mas en tiempo real.
#   D. Cinta de tarjetas (unica subida a la barra): con el salto del validador hay una altura de tarjeta desde la
#      que se sube del suelo (altura <= salto) y se llega a la barra (subida restante <= salto); el modelo de
#      movimiento con las tarjetas a esa altura alcanza la barra desde P; espera maxima a una tarjeta util
#      (tiempo del mundo) en cada fase.
#   E. Cabezal: cada slot y todo el recorrido de la ventana caen en la barra alcanzable, y los pies de Isak en la
#      barra quedan dentro de la caja del golpe (playhead_box_px); con el cabezal en marcha (Kernel y Raíz), lo
#      que avanza durante la caida del golpe (con el Debug, que lo exige) cabe en la caja (se puede adelantar).
#   F. Laser a la pantalla extendida (arena.damage_rects): desde cada slot de la barra y desde alguna celda del
#      suelo (el haz a la altura del celular, dentro del rectangulo o hacia el, a laser_range sin terreno).
#   G. Ventanas con k = window_k desde la peor celda de la barra (Isak en la barra, la solucion de §5.4) hasta el
#      slot de la fase (fase 1: window_slot; 2-3: el peor de seek_slots), por acceso: ventana (s del mundo; fase 2 =
#      la cuenta laps.<n>.countdown_s) >= k x (recorrido + carga del Debug + golpe hasta aterrizar), con la mejor
#      estrategia de _window_need. El primer laser va DENTRO de la pausa, que congela la ventana: lo cubre H.
#   G2. Subida desde el suelo (climb_k, accesos de climb_required_laps): desde la peor celda del suelo, correr a la
#      cinta mas conveniente + espera a la tarjeta + salto a la barra + recorrido por la barra + Debug + golpe cabe
#      en la ventana. En los demas accesos solo se informa (hay que esperar la ventana en la barra).
#   H. Pausa (mark_duration_s, sin el Debug: el caso peor) >= laseres de la peor ventana torpe (check_mark).
#   I. Energia torpe por acceso (base, tope del acceso y todo al maximo): pico por ventana <= maximo - min_margin.

def _rects_px(cells_rects, T):
    return [(float(c) * T, float(r) * T, float(w) * T, float(h) * T) for c, r, w, h in cells_rects]


def autoplay_conveyor(boss, rules, T):
    """Alturas utiles de la cinta y espera maxima (s del mundo a x1) a una tarjeta util."""
    arena = boss.get("arena", {})
    conv = arena.get("conveyor", {})
    bottom, top = float(conv.get("bottom_row", 10)), float(conv.get("top_row", 3))
    length = (bottom - top) * T
    cards = max(int(conv.get("cards", 2)), 1)
    speed = float(conv.get("speed_tiles_s", 0.5)) * T
    bar_rise = (bottom - float(arena.get("bar", {}).get("surface_row", 6))) * T
    jump = rules.jump_height
    lo, hi = bar_rise - jump, jump
    spacing = length / cards
    worst = 0.0
    if lo <= hi + EPS and speed > 0:
        steps = 400
        for i in range(steps):
            phase = spacing * i / steps
            best = None
            for k in range(cards):
                h = (phase + k * spacing) % length
                if lo - EPS <= h <= hi + EPS:
                    t = 0.0
                elif h < lo:
                    t = (lo - h) / speed
                else:
                    t = (length - h + lo) / speed
                best = t if best is None else min(best, t)
            worst = max(worst, best)
    mid = (max(lo, 0.0) + min(hi, length)) / 2.0
    snap_row = int(round(bottom - mid / T))
    return {"lo_px": lo, "hi_px": hi, "bar_rise_px": bar_rise, "length_px": length, "cards": cards,
            "spacing_px": spacing, "speed_px_s": speed, "worst_wait_s": worst, "snapshot_row": snap_row,
            "columns": [list(map(int, c)) for c in conv.get("columns", [])]}


def conveyor_level(level, conveyor):
    """Copia del nivel con las tarjetas de la cinta quietas en snapshot_row (plataformas de una via '-')."""
    g = copy.deepcopy(level)
    grid = [list(row) for row in g["grid"]]
    r = conveyor["snapshot_row"]
    for a, b in conveyor["columns"]:
        for c in range(a, b + 1):
            if grid[r][c] == ".":
                grid[r][c] = "-"
    g["grid"] = ["".join(row) for row in grid]
    return g


def _laser_hits(arena, node, facing, rects):
    """El laser de Isak de pie en `node` mirando a `facing` da en alguno de `rects` (px: x, y, w, h)."""
    px, py = arena.phone(node, facing)
    for x, y, w, h in rects:
        if x <= px <= x + w and y <= py <= y + h:
            return True
        if not y <= py <= y + h:
            continue
        edge = x if facing > 0 else x + w
        dx = edge - px
        if dx * facing < 0 or abs(dx) > arena.rules.laser_range + EPS:
            continue
        c0, c1 = sorted((int(px // arena.T), int(edge // arena.T)))
        if not any(arena.solid(c, node[1]) for c in range(c0, c1 + 1)):
            return True
    return False


def _clip_checks(arena, boss, root, errors, report):
    """B y C: carriles, dash a traves de cada clip y avisos por fase."""
    rules, T = arena.rules, arena.T
    banner = load_json(os.path.join(root, "data", "enemies", "spam_banner.json"))
    bell = load_json(os.path.join(root, "data", "enemies", "alarm_bell.json"))
    clips = boss.get("clips", {})
    lanes = boss.get("arena", {}).get("lanes", {})
    feet = {k: float(v["surface_row"]) * T for k, v in lanes.items()}
    dmg_w, dmg_h = (float(v) for v in banner["damage_size"])
    dmg_bottom = float(banner["damage_bottom_px"])
    for lane in ("floor", "bar"):
        if lane not in feet:
            _err(errors, "falta el carril '%s' en arena.lanes" % lane)
            return
    for lane, other in (("floor", "bar"), ("bar", "floor")):
        top, bottom = feet[lane] - dmg_bottom - dmg_h, feet[lane] - dmg_bottom
        if top < feet[other] and bottom > feet[other] - rules.hitbox_h:
            _err(errors, "el %s del carril '%s' alcanza a Isak de pie en '%s' (no hay refugio)"
                 % ("barrido" if lane == "bar" else "ola", lane, other))
    fps = anim_fps(boss)
    rays = clips.get("rays", {})
    shots = clips.get("shots", {})
    floor_cols = int(lanes["floor"]["to_col"]) - int(lanes["floor"]["from_col"]) + 1
    if int(rays.get("count", 3)) >= floor_cols:
        _err(errors, "rayos: %d por tanda y %d columnas en el suelo (sin hueco seguro)" % (rays.get("count", 3), floor_cols))
    volleys = {str(lap): e["ray_volleys"] for lap, e in boss.get("laps", {}).items() if e.get("ray_volleys")}
    if volleys:
        # Raiz, fase 3 (§5.8): rayos en dos tandas; cada tanda vuelve a empezar en la columna de Isak y respeta el
        # hueco seguro de arriba; entre tandas, un respiro (las campanas ya libres).
        gap = float(rays.get("volley_gap_s", 0.5))
        if gap < 0.0 or any(int(v) < 1 for vols in volleys.values() for v in vols):
            _err(errors, "rayos: ray_volleys >= 1 y volley_gap_s >= 0 (%s, %g)" % (volleys, gap))
        report["ray_volleys"] = {"gap_s": gap, "laps": volleys}
    ray_half = float(bell.get("damage_width_px", 48.0)) / 2.0
    escape = (ray_half + rules.hitbox_w / 2.0) / rules.run_speed
    out = []
    for p in (1, 2, 3):
        phase = boss.get("phase%d" % p, {})
        scale = float(phase.get("speed_scale", 1.0))
        names = phase.get("clips", [])
        tele = {"wave": int(banner.get("anticipation_frames", 9)), "sweep_high": int(banner.get("anticipation_frames", 9)),
                "rays": int(rays.get("anticipation_frames", 9)), "countdown_shots": int(shots.get("warn_frames", 9))}
        row = {"phase": p, "speed_scale": scale, "clips": []}
        for name in names:
            if name not in tele:
                _err(errors, "fase %d: clip desconocido '%s'" % (p, name))
                continue
            frames = tele[name]
            if not TELEGRAPH_FRAMES[0] <= frames <= TELEGRAPH_FRAMES[1]:
                _err(errors, "fase %d (x%g): aviso de '%s' de %d cuadros del mundo (regla: de 6 a 12)" % (p, scale, name, frames))
            warn_s = frames / fps
            if name in ("wave", "sweep_high"):
                speed = float(clips.get(name, {}).get("speed_px_s", banner["sweep_speed_px_s"])) * scale
                pass_s = (dmg_w + rules.hitbox_w) / max(speed, 1.0)
                if pass_s > rules.dash_invulnerable_s + EPS:
                    _err(errors, "fase %d: '%s' a %g px/s tarda %.2f s en pasar por Isak y el dash es invulnerable %.2f s"
                         % (p, name, speed, pass_s, rules.dash_invulnerable_s))
                answer = "dash %.2f s" % pass_s
            elif name == "countdown_shots":
                speed = float(shots.get("speed_px_s", 480.0)) * scale
                pass_s = (float(shots.get("size_px", [64, 32])[0]) + rules.hitbox_w) / max(speed, 1.0)
                if pass_s > rules.dash_invulnerable_s + EPS:
                    _err(errors, "fase %d: un proyectil de la cuenta tarda %.2f s en pasar por Isak (dash %.2f s)"
                         % (p, pass_s, rules.dash_invulnerable_s))
                answer = "dash %.2f s" % pass_s
            else:
                if escape > warn_s + EPS:
                    _err(errors, "fase %d: salir de la columna de un rayo cuesta %.2f s y el aviso dura %.2f s" % (p, escape, warn_s))
                answer = "salir de la columna %.2f s" % escape
            row["clips"].append((name, frames, answer))
        out.append(row)
    report["clips"] = out
    report["debug_world_scale"] = round(rules.debug_world_scale, 3)
    if not 0.0 < rules.debug_world_scale <= 1.0 + EPS:
        _err(errors, "con el Debug el mundo va a x%g: los avisos durarian menos que sin el Debug" % rules.debug_world_scale)


def _phase_window(boss, lap_entry, p):
    if p == 2:
        return float(lap_entry.get("countdown_s", 5.0))
    return float(boss.get("phase%d" % p, {}).get("window_s", 5.0))


def _phase_slots(boss, p):
    phase = boss.get("phase%d" % p, {})
    if phase.get("seek"):
        return list(phase.get("seek_slots", []))
    return [phase.get("window_slot", "center")]


def _bar_travel(rules, T, a_x, b_x, head_v_tiles):
    """Recorrido (s reales) de x=a a x=b por la barra con el cabezal en marcha a head_v_tiles (tiles/s del
    mundo; con el Debug activo va a la escala del mundo): en el caso peor se aleja de Isak."""
    v = head_v_tiles * T * rules.debug_world_scale
    return abs(a_x - b_x) * T / max(rules.run_speed - v, 1.0)


def validate_autoplay_arena(level, boss, root=ROOT, upgrades=(), physics_path=None,
                            jump_efficiency=vl.DEFAULT_JUMP_EFFICIENCY, limit=vl.DEFAULT_LIMIT):
    errors, warnings = [], []
    rules = vl.Rules(root, physics_path, jump_efficiency, limit, True)
    rules.set_level_debug_world_scale(level.get("debug_world_scale"))
    plain = Arena(level, boss, rules)
    T = plain.T
    report = {"boss": boss.get("id"), "reachable_cells": len(plain.reachable)}
    _basic_checks(plain, boss, root, errors, report)
    _clip_checks(plain, boss, root, errors, report)
    model = boss.get("validation_model", {})
    ab = boss.get("arena", {})
    # D. Cinta.
    conv = autoplay_conveyor(boss, rules, T)
    report["conveyor"] = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in conv.items()}
    if conv["lo_px"] > conv["hi_px"] + EPS:
        _err(errors, "cinta: no hay altura de tarjeta desde la que subir del suelo (<= %.0f px) y llegar a la barra "
                     "(%.0f px por encima del suelo)" % (conv["hi_px"], conv["bar_rise_px"]))
        return {"ok": False, "errors": errors, "warnings": warnings, "path": [], "boss": report}
    arena = Arena(conveyor_level(level, conv), boss, rules)
    bar = ab.get("bar", {})
    bar_row = int(bar.get("surface_row", 6)) - 1
    bar_cells = [(c, bar_row) for c in range(int(bar.get("from_col", 5)), int(bar.get("to_col", 14)) + 1)]
    bar_reach = [n for n in bar_cells if n in arena.reachable]
    report["bar_cells"] = [len(bar_reach), len(bar_cells)]
    if not bar_reach:
        _err(errors, "la barra no se alcanza desde P subiendo por la cinta (tarjetas en la fila %d)" % conv["snapshot_row"])
    # E. Cabezal.
    slots = {k: float(v) for k, v in ab.get("slots", {}).items()}
    surface = float(bar.get("surface_row", 6)) * T
    box = [float(v) for v in ab.get("playhead_box_px", [-32, -44, 64, 76])]
    lift = float(ab.get("playhead_lift_px", 20.0))
    if not (box[1] - EPS <= lift <= box[1] + box[3] + EPS and box[0] <= 0.0 <= box[0] + box[2]):
        _err(errors, "cabezal: los pies de Isak en la barra (a %g px bajo su centro) quedan fuera de su caja %s"
             % (lift, box))
    used = sorted({s for p in (1, 2, 3) for s in _phase_slots(boss, p)})
    for name in used:
        if name not in slots:
            _err(errors, "cabezal: slot '%s' no esta en arena.slots" % name)
            continue
        if (int(slots[name]), bar_row) not in bar_reach:
            _err(errors, "cabezal: el slot '%s' (x %.1f) no cae en una celda alcanzable de la barra" % (name, slots[name]))
    lo_x, hi_x = float(ab.get("playhead_from_x", 5.5)), float(ab.get("playhead_to_x", 14.5))
    for x in (lo_x, hi_x):
        if (int(x), bar_row) not in bar_reach:
            _err(errors, "cabezal: su recorrido llega a x %.1f, fuera de la barra alcanzable" % x)
    head = {}
    for lap, entry in sorted(boss.get("laps", {}).items()):
        v = float(entry.get("playhead_window_speed_tiles_s", 0.0))
        worst_scale = max(float(boss.get("phase%d" % p, {}).get("speed_scale", 1.0)) for p in (1, 2, 3))
        drift = v * worst_scale * T * rules.debug_world_scale * rules.pound_land_s
        if drift > box[2] + EPS:
            _err(errors, "vuelta %s: el cabezal en marcha avanza %.0f px durante el golpe (con el Debug) y su caja "
                         "mide %.0f" % (lap, drift, box[2]))
        head[lap] = round(drift, 1)
    report["playhead_drift_px"] = head
    # F. Laser.
    rects = _rects_px(ab.get("damage_rects", []), T)
    slot_laser = {}
    for name in used:
        if name not in slots:
            continue
        node = (int(slots[name]), bar_row)
        ok = any(_laser_hits(arena, node, f, rects) for f in (1.0, -1.0))
        slot_laser[name] = ok
        if not ok:
            _err(errors, "laser: desde el slot '%s' de la barra no se alcanza la pantalla" % name)
    floor_cells = [n for n in plain.lane_cells("floor") if n in plain.reachable]
    floor_laser = [n for n in floor_cells if any(_laser_hits(plain, n, f, rects) for f in (1.0, -1.0))]
    if not floor_laser:
        _err(errors, "laser: desde el suelo no se alcanza la pantalla ni su pie")
    bar_laser = [n for n in bar_reach if any(_laser_hits(arena, n, f, rects) for f in (1.0, -1.0))]
    report["laser"] = {"slots": slot_laser, "bar_cells": len(bar_laser), "floor_cells": len(floor_laser),
                       "floor_total": len(floor_cells)}
    # G y G2. Ventanas.
    k = float(model.get("window_k", 2.0))
    climb_k = float(model.get("climb_k", 1.0))
    climb_laps = {str(v) for v in model.get("climb_required_laps", [1])}
    columns = conv["columns"]
    windows = []
    for lap, entry in sorted(boss.get("laps", {}).items()):
        v = float(entry.get("playhead_window_speed_tiles_s", 0.0))
        for p in (1, 2, 3):
            scale = float(boss.get("phase%d" % p, {}).get("speed_scale", 1.0))
            window = _phase_window(boss, entry, p)
            worst_bar = worst_floor = 0.0
            for name in _phase_slots(boss, p):
                if name not in slots:
                    continue
                sx = slots[name]
                for n in bar_reach:
                    worst_bar = max(worst_bar, _bar_travel(rules, T, n[0] + 0.5, sx, v * scale))
                for n in floor_cells:
                    best = None
                    for a, b in columns:
                        side = b if b < sx else a  # borde de la cinta hacia la barra
                        edge = int(bar.get("from_col", 5)) + 0.5 if b < sx else int(bar.get("to_col", 14)) + 0.5
                        run = (abs(n[0] - side) * T) / rules.run_speed
                        t = run + CLIMB_S + _bar_travel(rules, T, edge, sx, v * scale)
                        best = t if best is None else min(best, t)
                    worst_floor = max(worst_floor, best or 0.0)
            need = k * _window_need_pound(rules, worst_bar)
            wait = conv["worst_wait_s"] / max(scale, EPS)
            climb = climb_k * (_window_need_pound(rules, worst_floor) + wait)
            if window + EPS < need:
                _err(errors, "vuelta %s, fase %d: la ventana dura %.2f s del mundo y desde la barra hacen falta %.2f "
                             "(k = %g x (recorrido %.2f s + Debug + golpe))" % (lap, p, window, need, k, worst_bar))
            required = lap in climb_laps
            if required and window + EPS < climb:
                _err(errors, "vuelta %s, fase %d: desde el suelo (cinta: espera %.2f s) hacen falta %.2f s del mundo y la "
                             "ventana dura %.2f" % (lap, p, wait, climb, window))
            windows.append({"lap": lap, "phase": p, "window_s": window, "need_bar_s": round(need, 3),
                            "travel_bar_s": round(worst_bar, 3), "need_floor_s": round(climb, 3),
                            "card_wait_s": round(wait, 3), "floor_required": required})
    report["aw_windows"] = windows
    # H. Pausa.
    check_mark(arena, boss, errors, report)
    # I. Energia.
    check_energy(arena, boss, rules, list(upgrades), errors, report, root, lap_fn=energy_lap_autoplay)
    return {"ok": not errors, "errors": errors, "warnings": warnings, "path": [], "boss": report}


def _window_need_pound(rules, travel):
    """Como _window_need, con el golpe al suelo hasta aterrizar (la pausa empieza ahi y congela la ventana) en
    lugar de las poses del pulso y del laser."""
    pose = rules.pound_land_s
    after = travel + rules.debug_hold_s + rules.debug_world_scale * pose
    first = rules.debug_hold_s + rules.debug_world_scale * (travel + pose)
    running = rules.debug_hold_s + rules.debug_world_scale * (max(travel - rules.debug_hold_s, 0.0) + pose)
    return min(after, first, running)


def energy_lap_autoplay(arena, boss, lap, rules, laser_damage, errors, scenario, root):
    """Pelea torpe de Autoplay por fase (validation_model): ventanas con sus golpes (la fase 2 suma los que
    recupera la cuenta: heals), Debug por ventana (debug_s, mas early_debug_s en la ventana perdida) al gasto de
    la arena, dashes por ventana y un laser fallado por ventana. Sin Burbujas: solo cargadores y el relleno del
    cambio de fase."""
    model = boss.get("validation_model", {})
    lm = model.get("laps", {}).get(str(lap))
    entry = boss.get("laps", {}).get(str(lap), {})
    if lm is None:
        _err(errors, "validation_model.laps sin la vuelta %s" % lap)
        return None
    drain = rules.debug_drain * float(arena.level.get("debug_drain_scale", 1.0))
    margin = float(model.get("min_margin", 20.0))
    emax = rules.energy_max
    misses = int(model.get("misses_per_window", 1))
    dashes = model.get("dashes_per_window", [1, 1, 1])
    early = model.get("early_debug_s", [0, 0, 0])
    heals = model.get("heals", [0, 0, 0])
    hits = entry.get("hits_per_phase", [])
    refill = float(boss.get("phase_change_refill", {}).get("energy", 0.0))
    charge = max((float(p.get("amount", 50.0)) for _, _, p in arena.chargers), default=50.0)
    detour = float(model.get("detour_s_per_charge", 1.3))
    energy = emax
    phases = []
    for p, windows in enumerate(lm.get("windows", [])):
        heal = int(heals[p] if p < len(heals) else 0)
        if p < len(hits) and sum(windows) != hits[p] + heal:
            _err(errors, "validation_model vuelta %s fase %d: las ventanas suman %d golpes y la fase tiene %d (+%d que "
                         "recupera)" % (lap, p + 1, sum(windows), hits[p], heal))
        peaks = []
        for h in windows:
            debug_s = float(lm["debug_s"][p]) + (float(early[p] if p < len(early) else 0.0) if h == 0 else 0.0)
            lasers = math.ceil(h / laser_damage) + misses
            peaks.append(debug_s * drain + int(dashes[p] if p < len(dashes) else 0) * rules.dash_cost
                         + lasers * rules.laser_cost)
        peak = max(peaks) if peaks else 0.0
        spend = sum(peaks)
        income = refill if p > 0 else 0.0
        need = max(0.0, spend - energy - income)
        charges = int(math.ceil(need / charge - EPS)) if need > 0 else 0
        energy = min(emax, energy + income + charges * charge - spend)
        if peak > emax - margin + EPS:
            _err(errors, "%s, vuelta %s, fase %d: pico de la pelea torpe %.1f con %.0f de energia (margen %.1f < %.0f)"
                 % (scenario, lap, p + 1, peak, emax, emax - peak, margin))
        phases.append({"peak": round(peak, 2), "margin": round(emax - peak, 2), "spend": round(spend, 2),
                       "charges": charges, "detour_s": round(charges * detour, 2), "end_energy": round(energy, 2)})
    return {"energy_max": emax, "debug_drain_per_s": round(drain, 3), "laser_cost": rules.laser_cost,
            "laser_damage": laser_damage, "dash_cost": rules.dash_cost, "phases": phases,
            "min_margin": round(min((ph["margin"] for ph in phases), default=0.0), 2),
            "total_spend": round(sum(ph["spend"] for ph in phases), 2),
            "total_charges": sum(ph["charges"] for ph in phases),
            "total_detour_s": round(sum(ph["detour_s"] for ph in phases), 2)}


def format_text(path, result):
    out = []
    status = "OK" if result["ok"] else "FALLA"
    out.append("%s: %s (%d error(es), %d aviso(s))" % (path, status, len(result["errors"]), len(result["warnings"])))
    rep = result.get("boss") or {}
    if rep:
        out.append("  arena de jefe: %s; %d celdas de pie alcanzables desde P" % (rep.get("boss"),
                                                                                rep.get("reachable_cells", 0)))
        if "sweep_busy_s" in rep:
            out.append("  carriles: barrido %.2f s cada %.2f s; rafaga %.2f s cada %.2f s; nunca los dos a la vez"
                       % (rep["sweep_busy_s"], rep["sweep_interval_s"], rep["burst_busy_s"], rep["burst_every_s"]))
        if "burst_dash" in rep:
            bd = rep["burst_dash"]
            out.append("  rafaga con el dash: notificaciones cada %.2f s, el dash vuelve en %.2f s; cada una pasa en "
                       "%.2f s (invulnerable %.2f s)" % (bd["spacing_s"], bd["dash_cycle_s"], bd["pass_s"],
                                                       bd["invulnerable_s"]))
        if "charger_worst_tiles" in rep:
            out.append("  cargadores: el mas cercano a %g tiles como mucho; el segundo, a %g"
                       % (rep["charger_worst_tiles"], rep["charger_second_worst_tiles"]))
        if rep.get("telegraphs"):
            out.append("  avisos: " + "; ".join("%s %s" % (n, f) for n, f in rep["telegraphs"]))
        if "debug_world_scale" in rep:
            out.append("  mundo con el Debug: x%g (los avisos duran x%.2f en tiempo real con el Debug)"
                       % (rep["debug_world_scale"], 1.0 / max(rep["debug_world_scale"], EPS)))
        for w in rep.get("windows", []):
            out.append("  ventana fase %d en %s: %.2f s (hacen falta %.2f; recorrido %.2f s; pulso desde %d celdas, "
                       "laser desde %d)" % (w["phase"], w["spot"], w["window_s"], w["need_s"], w["travel_s"],
                                            w["pulse_cells"], w["laser_cells"]))
        for lap, p3 in sorted((rep.get("phase3") or {}).items()):
            out.append("  fase 3, vuelta %s: compas %s s, %d copias, %d lanzamientos por ronda, parpadeo %.2f"
                       % (lap, "/".join("%g" % v for v in p3["tempo_steps_s"]), p3["copies"],
                          p3["launches_per_round"], p3["blink_on_fraction"]))
        cc = rep.get("center_climb")
        if cc and cc.get("path"):
            out.append("  subida a la central (fase 3): %s (caminos: %s); %s; llega a %s; %d celda(s) para el pulso "
                       "fuera de las campanas" % (cc["path"], ", ".join(cc["paths"]), "; ".join(cc["moves"][-2:]),
                                                  list(cc["landing"]), cc["safe_pulse_cells"]))
            for lap, c in sorted(cc["laps"].items()):
                out.append("    vuelta %s: lateral encendida %.2f s (margen %.2f s tras aterrizar y despegar antes del "
                           "aviso), espera %.2f s; ventana %.2f s (hacen falta %.2f)"
                           % (lap, c["on_s"], c["margin_s"], c["wait_s"], c["window_s"], c["need_s"]))
        for row in rep.get("clips", []):
            out.append("  fase %d (x%g): %s" % (row["phase"], row["speed_scale"], "; ".join(
                "%s aviso %d cuadros del mundo, %s" % c for c in row["clips"])))
        cv = rep.get("conveyor")
        if cv:
            out.append("  cinta: %d tarjetas por columna cada %.2f tiles a %g px/s; util de %.0f a %.0f px sobre el suelo "
                       "(barra a %.0f); espera maxima %.2f s del mundo a x1; tarjetas del modelo en la fila %d"
                       % (cv["cards"], cv["spacing_px"] / 64.0, cv["speed_px_s"], cv["lo_px"], cv["hi_px"],
                          cv["bar_rise_px"], cv["worst_wait_s"], cv["snapshot_row"]))
        if "bar_cells" in rep:
            out.append("  barra: %d de %d celdas alcanzables por la cinta; cabezal en marcha durante el golpe: %s px"
                       % (rep["bar_cells"][0], rep["bar_cells"][1],
                          ", ".join("vuelta %s %g" % kv for kv in sorted(rep.get("playhead_drift_px", {}).items()))))
        if rep.get("laser"):
            la = rep["laser"]
            out.append("  laser a la pantalla: slots %s; desde %d celdas de la barra y %d de %d del suelo"
                       % (", ".join("%s %s" % (k, "si" if v else "NO") for k, v in sorted(la["slots"].items())),
                          la["bar_cells"], la["floor_cells"], la["floor_total"]))
        for w in rep.get("aw_windows", []):
            out.append("  ventana vuelta %s fase %d: %.2f s; desde la barra hacen falta %.2f (recorrido %.2f s); desde el "
                       "suelo %.2f (espera a la tarjeta %.2f s)%s" % (w["lap"], w["phase"], w["window_s"], w["need_bar_s"],
                                                                     w["travel_bar_s"], w["need_floor_s"], w["card_wait_s"],
                                                                     "" if w["floor_required"] else " [solo informa]"))
        for lap, m in sorted((rep.get("mark") or {}).items()):
            out.append("  marca, vuelta %s: %g s del mundo (%g s reales con el Debug); caben %d laser(es) sin el Debug "
                       "y %d con el; la peor ventana torpe pide %d" % (lap, m["mark_s"], m["real_with_debug_s"],
                                                                      m["shots"], m["shots_with_debug"], m["need"]))
            if "pause_hits" in m:
                out[-1] += "; cada pausa acaba tras %d impacto(s) de laser (pause_hits)" % m["pause_hits"]
        rv = rep.get("ray_volleys")
        if rv:
            out.append("  rayos en tandas: %s (respiro de %g s del mundo entre tandas, /speed_scale)"
                       % ("; ".join("vuelta %s fases %s" % (lap, "/".join(str(v) for v in vols))
                                    for lap, vols in sorted(rv["laps"].items())), rv["gap_s"]))
        for lap, scen in sorted((rep.get("energy") or {}).items()):
            for name, e in scen.items():
                peaks = " / ".join("%g (%g)" % (ph["peak"], ph["margin"]) for ph in e["phases"])
                out.append("  energia vuelta %s, %s (max %g, Debug %g/s, laser %g x%d, dash %g): picos torpes %s; "
                           "gasto %g, %d cargas, desvio %g s" % (lap, name, e["energy_max"], e["debug_drain_per_s"],
                                                                 e["laser_cost"], e["laser_damage"], e["dash_cost"],
                                                                 peaks, e["total_spend"], e["total_charges"],
                                                                 e["total_detour_s"]))
    for e in result["errors"]:
        where = ""
        if e.get("row") is not None and e.get("col") is not None:
            where = "fila %d, columna %d: " % (e["row"], e["col"])
        out.append("  ERROR: " + where + e["message"])
    for w in result["warnings"]:
        out.append("  aviso: " + w["message"])
    return "\n".join(out)


def main(argv):
    parser = argparse.ArgumentParser(description="Valida una arena de jefe (kind boss).")
    parser.add_argument("levels", nargs="+")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--upgrades", default="")
    args = parser.parse_args(argv[1:])
    failed = False
    outputs = {}
    import validate_level_schema
    for path in args.levels:
        level = load_json(path)
        schema = validate_level_schema.validate_level(level, ROOT)
        if schema:
            result = {"ok": False, "errors": [{"message": "esquema: " + e, "row": None, "col": None, "object": None}
                                              for e in schema], "warnings": [], "path": []}
        else:
            ups = [u.strip() for u in args.upgrades.split(",") if u.strip()]
            result = validate_arena(level, upgrades=ups)
        failed = failed or not result["ok"]
        if args.json:
            outputs[path] = result
        else:
            print(format_text(path, result))
    if args.json:
        print(json.dumps(outputs, ensure_ascii=False, indent=1, default=list))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
