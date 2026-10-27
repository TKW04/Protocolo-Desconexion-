"""Mundo 3 «La Vitrina» en el validador (2026-10-26, paso 8a de docs/propuesta-mundo-3.md §7.1 y §8):
Pellizcar, likes, filtros y espejos fijos para tools/validate_level.py y tools/level_plan.py.

lower(level, catalog) devuelve una copia del nivel en la que la herramienta «Recortar» (crop_tool; CropTool
hereda de DndSwitch en el juego) es un `dnd_switch` que da `ability` (compress) con la configuracion de la
seccion crop_tool (`_config`): Pellizcar es una habilidad del grafo que se obtiene en ella (o
abilities_available.compress). Sin crop_tool el nivel se devuelve tal cual.

World3(model) se crea solo si el nivel tiene algo del Mundo 3 (LevelModel.w3; si no, None y nada cambia: la
salida del 1-1 al 2-3 y de las arenas es identica byte a byte). Modela:

  - Pellizcar (§3.3): los nodos comprimidos son Pinched(c, r) (una tupla (c, r) que no es igual a la normal):
    caja de compress.width_px x height_px (32 x 40), andar a walk_speed_px_s (160, sin correr) y salto de
    jump_height_px (96) x --jump-efficiency, con el mismo modelo de movimiento (World sobre una copia del
    LevelModel con esas medidas). Aristas «pinch» (de pie, normal -> comprimido) y «unpinch» (comprimido ->
    normal, solo si la caja normal cabe en la celda: la vuelta exige sitio), de squash_s (0,15 s) cada una.
    Comprimido no hay pulso, laser, dash ni golpe al suelo (pulse_hits / laser_shot / pound_x no valen desde un
    nodo comprimido). Los huecos de 1 fila (marcos pequenos) solo se cruzan comprimido. La busqueda cobra un
    poco cada movimiento comprimido (PINCH_SEARCH_COST) para recuperar el tamano en cuanto se puede. Regla de
    diseno de §3.3.2 en el camino principal (error): toda salida comprimida (ultima celda en la que la caja
    normal no cabe) recupera el tamano a <= RECOVER_MAX_TILES (4) y ningun tramo comprimido pasa de
    COMPRESSED_MAX_TILES (12). Salida: «Pellizcar: tramo ... (cols. a-b): N marcos, X tiles comprimido como
    maximo». Camino exportado: pasos pinch / unpinch y los movimientos comprimidos con "compressed": true.
  - Likes (§3.1) como estado: el estado lleva la cifra del intento como una ficha "likes=N" (0-30). Lo que
    cambia el mundo son solo los UMBRALES cumplidos (las claves de la cache de movimientos llevan que
    plataformas de likes estan encendidas, no la cifra). Corazones (heart_pickup, +value, una vez por intento:
    su gid queda en el estado), publicaciones (like_source: un pulso da +gain hasta likes.max, reutilizable con
    cooldown_s: el plan espera el enfriamiento entre dos usos seguidos) y «Borrar publicaciones» (like_reset:
    pulso de espaldas -> 0) son acciones de la progresion (like_gates, aparte de model.gates: no son puertas
    obligatorias). La progresion solo usa una publicacion mientras quede un umbral normal por cumplir y el reset
    mientras haya una plataforma inversa apagada; no repite una accion que deja el mismo estado en el mismo
    sitio. Abilities_available.compress tambien da Pellizcar (en KNOWN_ABILITIES del esquema desde el paso 8b).
    Plataformas de likes
    (like_platform): tabla de card_height_px arriba de su celda, encendida con likes >= threshold (invert:
    likes < threshold); one_way, solo apoyo. Las perdidas por golpe no se modelan (el camino no recibe golpes; el
    Ladron, paso 8b, mas abajo). Regla anti-atasco: cada plataforma de likes que pisa el camino
    tiene una publicacion alcanzable SIN likes desde el ultimo punto de sincronizacion (o P) antes de ella. En
    el grafo de los soft-locks (regla 7) entran las publicaciones y el reset (no los corazones: conservador).
  - Filtros (§3.2): dentro de un filtro fijo, la franja de cada peligro oculto (pincho '^' o fake_floor; la
    celda, BLIND_PAD_TILES a cada lado y BLIND_ABOVE_TILES por encima: donde la caja de Isak lo pisa o le pasa
    por encima) es, sin el Debug activo, un peligro del grafo (el jugador no ve lo que hay debajo): solo se pasa
    con el Debug (movimientos «con Debug» del grafo; el plan enciende el Debug y cuenta la energia). El resto
    del filtro (suelo real lejos de lo escondido) se cruza sin el Debug: un filtro largo no pide la barra entera
    (filtro_test: 14 tiles, unos 129 de energia con el Debug todo el rato). Filtro movil (positions): sin el
    Debug vale todo lo que el filtro descubre en algun momento de su ciclo (los peligros no se mueven: se
    memoriza); solo pide el Debug la franja de los peligros que tapan TODOS sus sitios (simplificacion
    documentada de «las celdas que el filtro descubrio en el ciclo anterior»). Antes de cada filtro que el camino cruza con el Debug hay un
    cargador a la vista (a <= VIEW_TILES columnas de su entrada; error si no). Las reglas sin simular
    (pinchos -10 sin pozos mortales, caida <= 3 tiles con salida, umbral sin tapar) son del esquema.
  - Espejos (§3.4): con espejos fijos en el nivel el laser se traza con rebotes (mirror '/', '\\' gira 90
    grados, '|' vuelve; punto de rebote en la linea del cristal como Mirror.reflection_point; alcance restante;
    como mucho mirror.max_bounces = 3: el siguiente espejo lo para) contra el terreno, las tablas finas
    (puentes, plataformas del reflejo) y el objetivo (lector laser, interruptor laser, anuncio, Posponer,
    Burbuja). Asi el acertijo lector -> receptor enlazado -> puente funciona por espejos. Salida por lector:
    desde donde, cuantos rebotes y cuanto alcance; un lector que solo se alcanzaria con mas de 3 rebotes es un
    error. El espejo cazador, paso 8b (mas abajo).
  - Plataformas del reflejo (mirror_only): solidas para el grafo (tabla de height_px arriba de su celda); el
    validador comprueba que cada una se ve en su pared de espejo mas cercana (reflejada dentro del cristal) y
    que, si el camino la pisa, la pared esta a la vista (VIEW_TILES / 2 columnas) desde donde salta.

Paso 8b (2026-10-26, §7.1): enemigos, espejo cazador, Reflejo falso, placas y puertas de marco.

  - Espejo cazador (hunter_mirror, §3.6): indestructible y sin colision. Con Isak (centro de su caja) a
    <= track_radius_tiles gira 45 grados hacia el cada turn_interval_s (0,6 s); fuera de su radio vuelve a la
    orientacion de reposo (facing). EL PULSO REFLEJADO ES UNA ARISTA: un receptor (puente con receiver o
    relay_receiver) tambien se activa si el pulso de Isak alcanza al cazador y su haz (beam_tiles, cortado por el
    terreno, grosor beam_width_px) en una orientacion que pueda tener en ese momento toca el receptor
    (LevelModel.receiver_hits). Orientaciones posibles desde una celda de pie: la de reposo si Isak esta fuera
    del radio o llega a pulsarlo antes del primer giro (le sobra HUNTER_APPROACH_FRACTION del intervalo andando
    desde el borde del radio) y las del giro hacia Isak (esperando quieto). El plan simula la orientacion por
    tiempo desde que Isak entra en su radio y, si al pulsarlo aun no mira al receptor, inserta una espera
    wait_hunter (o es un error si no llegara a mirarlo). LASER: se refleja en el cazador hacia donde mira desde
    las celdas fuera de su radio (en reposo) si la orientacion es horizontal o vertical; desde dentro del radio o
    en diagonal el cazador para el disparo (congelarlo con el pulso para disparar desde dentro no se modela:
    conservador).
  - Placas «Posa aqui» (pose_plate) y puertas de marco (frame_door): la puerta es solida en el grafo hasta que
    Isak pisa una de sus placas (accion de la progresion «plate:<id>», como los likes); el plan comprueba el
    tiempo: placa pisada por Isak o por el Reflejo falso, hold_s (0,3 s) de mas, apertura de open_s (0,2 s;
    solida mientras se abre), aviso de close_warn_frames antes de cerrarse y nunca con alguien en el hueco. Si la
    puerta aun esta cerrada cuando el camino llega, espera wait_reflection delante (el reflejo pisa la placa con
    su retraso); si no se abriria a tiempo, error.
  - Reflejo falso (false_reflection): en su sala (zone) sale al cruzar Isak el eje de su pared de espejo, espera
    delay_s en el punto de cruce sin danar y despues repite la posicion de Isak de hace delay_s (1 s; con el Debug
    el retraso real crece: no se modela, se usa 1 s). Regla: con el reflejo activo y sin aturdir,
    |Isak(t) - Isak(t - 1 s)| >= REFLECTION_GAP_TILES (1 tile). Si no se cumple, el plan aturde al reflejo con un
    pulso desde una celda de pie (3 s, sigue pisando la placa) o es un error.
  - Influencer bot: linea de vision con terreno (franja de sight_band_px a la altura de la lente, sight_tiles,
    facing, rayo de la lente a Isak cortado por solidos y tablas). Si al terminar la carga (0,75 s) aun ve a Isak,
    el flash ciega veil_hold_s + veil_fade_s (1,5 s) sin dano; ningun salto o caida «preciso» (exigencia mayor que
    BLIND_JUMP_MAX) puede empezar durante la ceguera: el plan aturde al bot con el pulso antes del flash (desde
    una celda de pie) o es un error. Taparse o salir de su vista durante la carga lo resuelve.
  - Ladron de likes: patrulla, aviso, persecucion a chase_speed_px_s dentro de su correa, huida y busqueda (sin
    likes), en 1D por su fila. Robo = contacto persiguiendo con likes > 0 y sin dash: el plan lo aturde antes con
    el pulso (desde una celda de pie) o es un error (0 robos en la solucion).
  - Secretos con requires_abilities (LevelModel / Validator): se comprueban con esas habilidades (como si el
    nivel las diera) y sin ellas no cuentan como inalcanzables.
  Camino exportado: wait_hunter, wait_reflection y pulsos a influencer_bot / like_thief / false_reflection; el
  pulso al cazador lleva target.via_hunter {id, facing}.
"""
import copy
import json
import math
import os

EPS = 1e-6
INF = float("inf")
SIM_DT = 1.0 / 60.0
DT_SIM = SIM_DT
# Paso del muestreo de posiciones de pie dentro de una celda (el de validate_level.PULSE_SAMPLE_PX).
SAMPLE_PX = 4.0
# Coste extra en la busqueda de cada movimiento comprimido (recuperar el tamano en cuanto se pueda).
PINCH_SEARCH_COST = 0.05
# Regla de diseno de §3.3.2.
RECOVER_MAX_TILES = 4
COMPRESSED_MAX_TILES = 12
# Ancho de la vista en tiles (1280 / 64): cargador «a la vista» antes de un filtro; la pared de espejo esta a la
# vista si queda a media pantalla del salto.
VIEW_TILES = 20
# Franja de un peligro oculto de un filtro que solo se pisa con el Debug: tiles a cada lado y por encima (la caja
# de Isak de pie encima o saltandolo).
BLIND_PAD_TILES = 1
BLIND_ABOVE_TILES = 2
# Rebotes que se prueban para explicar un lector fuera del limite (mirror.max_bounces).
DIAG_BOUNCES = 8

ENEMIES_8B = ("influencer_bot", "like_thief", "false_reflection")
OBJECTS_8B = ("hunter_mirror", "pose_plate", "frame_door")
WORLD3_TYPES = ("heart_pickup", "like_source", "like_platform", "like_reset", "crop_tool", "filter_zone",
                "small_frame", "mirror", "mirror_wall", "mirror_only") + OBJECTS_8B
LIKE_KINDS = ("heart", "like_source", "like_reset")
# Acciones de la progresion del Mundo 3 (los likes y, paso 8b, pisar una placa «Posa aqui»).
ACTION_KINDS = LIKE_KINDS + ("plate",)
# --- Paso 8b ---
FACINGS = ("e", "ne", "n", "nw", "w", "sw", "s", "se")
# Exigencia (max(h, v)) a partir de la cual un salto o una caida es «preciso» y no puede empezar con la ceguera del
# flash (decision del paso 8b: la mitad del alcance; los saltos cortos y las bajadas se hacen a ciegas).
BLIND_JUMP_MAX = 0.5
# El cazador aun mira a su reposo si Isak llega a pulsarlo andando desde el borde de su radio en esta fraccion del
# intervalo de giro (el plan lo comprueba con el tiempo exacto).
HUNTER_APPROACH_FRACTION = 0.75
# Al pulsar el cazador no debe estar a punto de girar (s antes del giro).
HUNTER_TURN_MARGIN_S = 0.1
# Espera maxima (s) que se prueba para que el cazador mire al receptor o una puerta de marco se abra.
MAX_WAIT_S = 6.0
# Correcciones maximas del plan (pulsos y esperas insertados) por pasada.
MAX_FIXES = 24
# Margen (s) de las esperas por una puerta de marco (dos cuadros).
WAIT_MARGIN_S = 2.0 / 60.0
# Distancia minima (tiles) entre Isak y donde estaba 1 s antes con el Reflejo falso activo (§7.1).
REFLECTION_GAP_TILES = 1.0
WAIT_KINDS = ("wait", "wait_hunter", "wait_reflection")


class Pinched(tuple):
    """Nodo comprimido (Pellizcar): se desempaqueta como (c, r) pero no es igual a la tupla normal (c, r)."""
    __slots__ = ()
    pinched = True

    def __new__(cls, node):
        return tuple.__new__(cls, (node[0], node[1]))

    def __eq__(self, other):
        return isinstance(other, Pinched) and tuple.__eq__(self, other)

    def __ne__(self, other):
        return not self.__eq__(other)

    def __hash__(self):
        return hash(("pinched", self[0], self[1]))

    def __repr__(self):
        return "Pinched(%d, %d)" % (self[0], self[1])

    def __getnewargs__(self):
        return ((self[0], self[1]),)


def is_pinched(node):
    return getattr(node, "pinched", False)


def plain(node):
    return (node[0], node[1])


def _params(catalog, obj):
    params = dict(catalog.get("types", {}).get(obj["type"], {}).get("defaults", {}))
    params.update(obj.get("params", {}))
    return params


def has_world3(level):
    abilities = level.get("abilities_available", {}) or {}
    if abilities.get("compress"):
        return True
    if any(isinstance(e, dict) and e.get("type") in ENEMIES_8B for e in level.get("enemies", [])):
        return True
    return any(isinstance(o, dict) and o.get("type") in WORLD3_TYPES for o in level.get("objects", []))


def facing_vector(index):
    a = float(index % 8) * math.pi * 0.25
    return math.cos(a), -math.sin(a)


def index_for_vector(dx, dy):
    if abs(dx) < EPS and abs(dy) < EPS:
        return 0
    return int(round(math.atan2(-dy, dx) / (math.pi * 0.25))) % 8


def step_toward(cur, target):
    diff = (target - cur) % 8
    if diff == 0:
        return cur
    return (cur + (1 if diff <= 4 else -1)) % 8


def turn_path(start, target):
    seq = [start]
    while seq[-1] != target and len(seq) < 9:
        seq.append(step_toward(seq[-1], target))
    return seq


def segment_hits_rect(a, b, rect):
    """Liang-Barsky (HunterMirror.segment_hits_rect)."""
    x0, y0, x1, y1 = rect[:4]
    if x0 <= a[0] <= x1 and y0 <= a[1] <= y1:
        return True
    dx, dy = b[0] - a[0], b[1] - a[1]
    t0, t1 = 0.0, 1.0
    for p, q in ((-dx, a[0] - x0), (dx, x1 - a[0]), (-dy, a[1] - y0), (dy, y1 - a[1])):
        if abs(p) < 1e-9:
            if q < 0.0:
                return False
            continue
        t = q / p
        if p < 0.0:
            t0 = max(t0, t)
        else:
            t1 = min(t1, t)
        if t0 > t1:
            return False
    return True


def rects_overlap(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


def lower(level, catalog):
    """crop_tool -> dnd_switch con _config crop_tool y ability compress (el resto queda igual)."""
    if not any(isinstance(o, dict) and o.get("type") == "crop_tool" for o in level.get("objects", [])):
        return level
    out = copy.deepcopy(level)
    objects = []
    for obj in out.get("objects", []):
        if obj.get("type") != "crop_tool":
            objects.append(obj)
            continue
        p = _params(catalog, obj)
        params = dict(obj.get("params", {}))
        params["id"] = str(p.get("id", "crop_%d_%d" % (obj["x"], obj["y"])))
        params["ability"] = str(p.get("ability", "compress") or "compress")
        params["_config"] = "crop_tool"
        objects.append({"type": "dnd_switch", "x": obj["x"], "y": obj["y"], "params": params})
    out["objects"] = objects
    return out


def _real_jump_height(v0, gravity, dt=SIM_DT):
    v, h = v0, 0.0
    while True:
        v -= gravity * dt
        if v <= 0.0:
            return h
        h += v * dt


def _rect_cells(rect):
    x, y, w, h = rect
    return {(x + i, y + j) for j in range(h) for i in range(w)}


class World3:
    def __init__(self, model, gate_cls):
        self.m = model
        self.Gate = gate_cls
        level = model.level
        T = model.T
        cat = model.catalog
        rules = model.rules
        abilities = level.get("abilities_available", {}) or {}
        data = {}
        try:
            with open(os.path.join(rules.root, "data", "isak_abilities.json"), encoding="utf-8") as handle:
                data = json.load(handle).get("compress", {}) or {}
        except (OSError, ValueError):
            data = {}
        self.cfg_compress = data
        self.squash_s = float(data.get("squash_s", 0.15))
        # --- Pellizcar ---
        self.compress_base = bool(abilities.get("compress", False))
        self.crop_gates = [g for g in model.gates if g.kind == "dnd" and g.ability == "compress"]
        self.compress_possible = self.compress_base or bool(self.crop_gates)
        self._cmodel = None
        self._edges = {}
        # --- Likes ---
        likes_cfg = cat.get("likes", {})
        self.likes_max = int(likes_cfg.get("max", 30))
        self.like_platforms = []
        self.like_gates = []
        thick = float(cat.get("like_platform", {}).get("card_height_px", 32))
        for obj in level.get("objects", []):
            p = _params(cat, obj)
            x, y = obj["x"], obj["y"]
            kind = obj["type"]
            if kind == "like_platform":
                w = int(p.get("width_tiles", 2))
                self.like_platforms.append({
                    "id": str(p.get("id", "likes_%d_%d" % (x, y))), "cells": [(x + i, y) for i in range(w)],
                    "threshold": int(p.get("threshold", 5)), "invert": bool(p.get("invert", False)),
                    "one_way": bool(p.get("one_way", False)), "thick": thick, "col": x, "row": y,
                    "span": (x, x + w - 1)})
            elif kind == "heart_pickup":
                hid = str(p.get("id", "heart_%d_%d" % (x, y)))
                g = gate_cls("heart:" + hid, "heart", hid, cells=[(x, y)], col=x, row=y, tile=T)
                g.value = int(p.get("value", 1))
                self.like_gates.append(g)
            elif kind in ("like_source", "like_reset"):
                cfg = cat.get(kind, {})
                hit = cfg.get("hit_rect", [4, 4, 56, 48] if kind == "like_source" else [8, -14, 48, 48])
                oid = str(p.get("id", "%s_%d_%d" % (kind, x, y)))
                x0, y0 = x * T + float(hit[0]), y * T + float(hit[1])
                rect = (x0, y0, x0 + float(hit[2]), y0 + float(hit[3]), "%s %s" % (
                    "publicacion" if kind == "like_source" else "Borrar publicaciones", oid))
                g = gate_cls(("pub:" if kind == "like_source" else "reset:") + oid, kind, oid, openers=[rect],
                             col=x, row=y, tile=T)
                g.gain = int(p.get("gain", 5))
                g.cooldown_s = float(p.get("cooldown_s", 8.0))
                g.pose_s = float(cfg.get("pose_s", 0.45))
                self.like_gates.append(g)
        self.thresholds = sorted({p["threshold"] for p in self.like_platforms})
        self.normal_max = max([p["threshold"] for p in self.like_platforms if not p["invert"]] + [0])
        self.inverse = [p for p in self.like_platforms if p["invert"]]
        self.pubs = [g for g in self.like_gates if g.kind == "like_source"]
        self.resets = [g for g in self.like_gates if g.kind == "like_reset"]
        self.hearts = [g for g in self.like_gates if g.kind == "heart"]
        # --- Filtros ---
        self.filters = []
        grid = model.grid
        for obj in level.get("objects", []):
            if obj["type"] != "filter_zone":
                continue
            p = _params(cat, obj)
            w, h = int(p.get("width_tiles", 6)), int(p.get("height_tiles", 4))
            positions = p.get("positions") or [[obj["x"], obj["y"]]]
            rects = [(int(px), int(py), w, h) for px, py in positions]
            covered = set()
            for rect in rects:
                covered |= _rect_cells(rect)
            always = set(_rect_cells(rects[0]))
            for rect in rects[1:]:
                always &= _rect_cells(rect)
            moving = len(rects) > 1
            spikes = sorted((c, r) for (c, r) in covered if 0 <= r < model.rows and 0 <= c < model.cols
                            and grid[r][c] == "^")
            floors = [tuple(int(v) for v in f) for f in (p.get("fake_floor") or [])] if not moving else []
            # Lo que el jugador no puede leer sin el Debug: alrededor de cada peligro oculto (pincho o suelo falso)
            # la franja que la caja de Isak toca al pisarlo o pasarle por encima (BLIND_PAD_TILES a los lados, el
            # cuerpo por encima), dentro del filtro; en el movil, solo dentro de lo que tapan TODOS sus sitios.
            hidden = set(spikes)
            for fx, fy, fw, fh in floors:
                hidden |= _rect_cells((fx, fy, fw, fh))
            zone = always if moving else covered
            blind = set()
            for hc, hr in hidden:
                if (hc, hr) not in zone:
                    continue
                for dc in range(-BLIND_PAD_TILES, BLIND_PAD_TILES + 1):
                    for dr in range(-BLIND_ABOVE_TILES, 2):
                        if (hc + dc, hr + dr) in zone:
                            blind.add((hc + dc, hr + dr))
            entry = str(p.get("entry", "left"))
            self.filters.append({
                "id": str(p.get("id", "filter_%d_%d" % (obj["x"], obj["y"]))), "label": str(p.get("label", "")),
                "rects": rects, "cells": covered, "blind": blind, "moving": moving, "spikes": spikes,
                "fake_floor": floors, "entry": entry, "cycle_s": float(p.get("cycle_s", 0.0) or 0.0),
                "col": obj["x"], "row": obj["y"],
                "entry_col": min(c for c, _ in covered) if entry == "left" else max(c for c, _ in covered),
                "hazards": self._blind_rects(blind, T, str(p.get("id", "")))})
        # --- Espejos ---
        mcfg = cat.get("mirror", {})
        self.max_bounces = int(mcfg.get("max_bounces", 3))
        self.mirrors = []
        hit = mcfg.get("hit_rect", [0, 0, 64, 64])
        for obj in level.get("objects", []):
            if obj["type"] != "mirror":
                continue
            p = _params(cat, obj)
            x0, y0 = obj["x"] * T + float(hit[0]), obj["y"] * T + float(hit[1])
            rect = (x0, y0, x0 + float(hit[2]), y0 + float(hit[3]))
            self.mirrors.append({"id": str(p.get("id", "mirror_%d_%d" % (obj["x"], obj["y"]))),
                                 "orient": str(p.get("orientation", "/")), "rect": rect,
                                 "center": ((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5),
                                 "cell": (obj["x"], obj["y"])})
        wall_cfg = cat.get("mirror_wall", {})
        frame_px = float(wall_cfg.get("frame_px", 8))
        self.mirror_walls = []
        for obj in level.get("objects", []):
            if obj["type"] != "mirror_wall":
                continue
            p = _params(cat, obj)
            w, h = int(p.get("width_tiles", 6)), int(p.get("height_tiles", 4))
            rect = (obj["x"] * T, obj["y"] * T, (obj["x"] + w) * T, (obj["y"] + h) * T)
            side = str(p.get("side", "center"))
            axis = rect[0] if side == "left" else rect[2] if side == "right" else (rect[0] + rect[2]) * 0.5
            self.mirror_walls.append({"id": str(p.get("id", "mirror_wall_%d_%d" % (obj["x"], obj["y"]))),
                                      "rect": rect, "axis": axis,
                                      "glass": (rect[0] + frame_px, rect[1] + frame_px, rect[2] - frame_px,
                                                rect[3] - frame_px)})
        only_h = float(cat.get("mirror_only", {}).get("height_px", 32))
        self.mirror_only = []
        for obj in level.get("objects", []):
            if obj["type"] != "mirror_only":
                continue
            p = _params(cat, obj)
            w = int(p.get("width_tiles", 2))
            self.mirror_only.append({"id": str(p.get("id", "mirror_only_%d_%d" % (obj["x"], obj["y"]))),
                                     "cells": [(obj["x"] + i, obj["y"]) for i in range(w)], "thick": only_h,
                                     "one_way": bool(p.get("one_way", False)), "col": obj["x"], "row": obj["y"],
                                     "rect": (obj["x"] * T, obj["y"] * T, (obj["x"] + w) * T, obj["y"] * T + only_h)})
        self.small_frames = []
        for obj in level.get("objects", []):
            if obj["type"] != "small_frame":
                continue
            p = _params(cat, obj)
            n = int(p.get("length_tiles", 1))
            vertical = str(p.get("orientation", "wall")) in ("floor", "ceiling")
            cells = [(obj["x"], obj["y"] + i) for i in range(n)] if vertical else [(obj["x"] + i, obj["y"]) for i in range(n)]
            self.small_frames.append({"id": str(p.get("id", "frame_%d_%d" % (obj["x"], obj["y"]))), "cells": set(cells)})
        self._build_8b(level, cat, T, gate_cls)

    # --- Paso 8b: construccion ---

    def _enemy_data(self, kind):
        try:
            with open(os.path.join(self.m.rules.root, "data", "enemies", "%s.json" % kind), encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, ValueError):
            return {}

    def _build_8b(self, level, cat, T, gate_cls):
        self.influencers, self.thieves, self.reflections = [], [], []
        for e in level.get("enemies", []):
            kind = e.get("type")
            if kind not in ENEMIES_8B:
                continue
            p = dict(self._enemy_data(kind))
            p.update(e.get("params") or {})
            fx, fy = (e["x"] + 0.5) * T, (e["y"] + 1) * T
            eid = str(e.get("id", "%s_%d_%d" % (kind, e["x"], e["y"])))
            if kind == "influencer_bot":
                bw, bh = (float(v) for v in p.get("body_size", [48.0, 120.0]))
                self.influencers.append({
                    "id": eid, "cell": (e["x"], e["y"]), "lens": (fx, fy - float(p.get("lens_height_px", 96.0))),
                    "band": float(p.get("sight_band_px", 64.0)) * 0.5, "sight": float(p.get("sight_tiles", 8)) * T,
                    "facing": int(p.get("facing", 0)),
                    "warn": float(p.get("anticipation_frames", 9)) / float(p.get("anim_fps", 12.0)),
                    "cooldown": float(p.get("cooldown_s", 3.0)), "stun": float(p.get("stun_s", 3.0)),
                    "veil": float(p.get("veil_hold_s", 1.0)) + float(p.get("veil_fade_s", 0.5)),
                    "body": (fx - bw * 0.5, fy - bh, fx + bw * 0.5, fy)})
            elif kind == "like_thief":
                self.thieves.append({"id": eid, "cell": (e["x"], e["y"]), "spawn": (fx, fy), "p": p})
            else:
                wall = next((w for w in self.mirror_walls if w["id"] == str(p.get("mirror_wall", ""))), None)
                zone = p.get("zone")
                zrect = None
                if isinstance(zone, list) and len(zone) == 4:
                    zrect = (zone[0] * T, zone[1] * T, (zone[0] + zone[2]) * T, (zone[1] + zone[3]) * T)
                self.reflections.append({
                    "id": eid, "cell": (e["x"], e["y"]), "wall": wall["id"] if wall else None,
                    "axis": wall["axis"] if wall else fx, "zone": zrect, "delay": float(p.get("delay_s", 1.0)),
                    "stun": float(p.get("stun_s", 3.0)),
                    "emerge": float(p.get("emerge_frames", 9)) / float(p.get("anim_fps", 60.0))})
        hcfg = cat.get("hunter_mirror", {})
        self.hunters = []
        for obj in level.get("objects", []):
            if obj["type"] != "hunter_mirror":
                continue
            p = _params(cat, obj)
            hit = hcfg.get("hit_rect", [0, 0, 64, 64])
            x0, y0 = obj["x"] * T + float(hit[0]), obj["y"] * T + float(hit[1])
            rect = (x0, y0, x0 + float(hit[2]), y0 + float(hit[3]))
            facing = str(p.get("facing", "e"))
            self.hunters.append({
                "id": str(p.get("id", "hunter_%d_%d" % (obj["x"], obj["y"]))), "cell": (obj["x"], obj["y"]),
                "rect": rect, "center": ((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5),
                "rest": FACINGS.index(facing) if facing in FACINGS else 0,
                "radius": float(p.get("track_radius_tiles", hcfg.get("track_radius_tiles", 3.0))) * T,
                "interval": float(hcfg.get("turn_interval_s", 0.6)),
                "warn": float(hcfg.get("warn_frames", 9)) / float(hcfg.get("anim_fps", 60.0)),
                "freeze": float(hcfg.get("freeze_s", 3.0)), "beam": float(hcfg.get("beam_tiles", 6)) * T,
                "beam_half": float(hcfg.get("beam_width_px", 24)) * 0.5})
        dcfg = cat.get("frame_door", {})
        self.doors = []
        for obj in level.get("objects", []):
            if obj["type"] != "frame_door":
                continue
            p = _params(cat, obj)
            x, y = obj["x"], obj["y"]
            self.doors.append({
                "id": str(p.get("id", "door_%d_%d" % (x, y))), "cells": [(x, y + i) for i in range(3)],
                "rect": (x * T, y * T, (x + 1) * T, (y + 3) * T), "col": x, "row": y, "plates": [],
                "open_s": float(dcfg.get("open_s", 0.2)),
                "warn": float(dcfg.get("close_warn_frames", 9)) / float(dcfg.get("anim_fps", 60.0))})
        pcfg = cat.get("pose_plate", {})
        self.plates = []
        for obj in level.get("objects", []):
            if obj["type"] != "pose_plate":
                continue
            p = _params(cat, obj)
            x, y = obj["x"], obj["y"]
            pid = str(p.get("id", "plate_%d_%d" % (x, y)))
            g = gate_cls("plate:" + pid, "plate", pid, cells=[(x, y)], col=x, row=y, tile=T)
            g.target = str(p.get("target", ""))
            inset, tol, h = float(pcfg.get("inset_px", 8)), float(pcfg.get("press_tolerance_px", 12)), float(
                pcfg.get("plate_height_px", 8))
            g.press = (x * T + inset, (y + 1) * T - h - tol, (x + 1) * T - inset, (y + 1) * T + tol)
            g.hold_s = float(pcfg.get("hold_s", 0.3))
            g.feet_fraction = float(pcfg.get("feet_fraction", 0.5))
            self.plates.append(g)
            self.like_gates.append(g)
            for d in self.doors:
                if d["id"] == g.target:
                    d["plates"].append(g.gid)
        self.isak_w = self.m.rules.hitbox_w

    @property
    def keyed(self):
        """El estado de la progresion cambia el terreno (plataformas de likes o puertas de marco)."""
        return bool(self.like_platforms or self.plates)

    @property
    def softlock_actions(self):
        return bool(self.pubs or self.resets or self.plates)

    def door_open(self, d, state):
        return any(gid in state for gid in d["plates"])

    @staticmethod
    def _blind_rects(cells, T, fid):
        out = []
        for c, r in sorted(cells):
            out.append((c * T, r * T, (c + 1) * T, (r + 1) * T, "filtro %s (sin el Debug no se ve lo que esconde)" % fid))
        return out

    # --- Mundo ---

    def apply_world(self, world, state, debug):
        """Plataformas de likes encendidas, plataformas del reflejo y, sin el Debug, la vista ciega de los filtros."""
        m = world.m
        T = m.T
        rows, cols = m.rows, m.cols
        likes = self.likes_of(state)
        boards = [(p["cells"], p["thick"], p["one_way"]) for p in self.like_platforms if self.platform_on(p, likes)]
        boards += [(p["cells"], p["thick"], p["one_way"]) for p in self.mirror_only]
        for cells, thick, one_way in boards:
            for c, r in cells:
                if not (0 <= r < rows and 0 <= c < cols):
                    continue
                world.support[r][c] = True
                if one_way:
                    continue
                if thick < T - EPS:
                    world.thin[(c, r)] = thick
                else:
                    world.solid[r][c] = True
        if not debug:
            for f in self.filters:
                world.hazards.extend(f["hazards"])
        for d in self.doors:
            # Puerta de marco (paso 8b): solida hasta que Isak pisa una de sus placas (el plan comprueba el tiempo).
            if self.door_open(d, state):
                continue
            for c, r in d["cells"]:
                if 0 <= r < rows and 0 <= c < cols:
                    world.solid[r][c] = True
                    world.support[r][c] = True

    # --- Likes ---

    @staticmethod
    def likes_of(state):
        for tok in state:
            if tok.startswith("likes="):
                return int(tok[6:])
        return 0

    @staticmethod
    def with_likes(state, value):
        out = frozenset(t for t in state if not t.startswith("likes="))
        return out | {"likes=%d" % value} if value > 0 else out

    @staticmethod
    def platform_on(p, likes):
        return likes < p["threshold"] if p["invert"] else likes >= p["threshold"]

    def like_key(self, lo, hi, state):
        likes = self.likes_of(state)
        key = tuple(("likes", p["id"]) for p in self.like_platforms
                    if not (p["span"][1] < lo or p["span"][0] > hi) and self.platform_on(p, likes))
        if self.plates:
            key = key + tuple(("door", d["id"]) for d in self.doors
                              if lo <= d["col"] <= hi and self.door_open(d, state))
        return key

    def apply(self, state, gate):
        """Estado tras una accion de likes (corazon, publicacion o reset) o una placa (paso 8b)."""
        likes = self.likes_of(state)
        if gate.kind == "plate":
            return state | {gate.gid}
        if gate.kind == "heart":
            return self.with_likes(state | {gate.gid}, min(self.likes_max, likes + gate.value))
        if gate.kind == "like_source":
            return self.with_likes(state, min(self.likes_max, likes + gate.gain))
        return self.with_likes(state, 0)

    def useful(self, gate, state):
        likes = self.likes_of(state)
        if gate.kind in ("heart", "plate"):
            return gate.gid not in state
        if gate.kind == "like_source":
            return likes < min(self.normal_max, self.likes_max)
        return likes > 0 and any(not self.platform_on(p, likes) for p in self.inverse)

    def can_act(self, gate, node, state):
        m = self.m
        if gate.kind == "plate":
            return (node[0], node[1]) in set(gate.cells)  # de pie en la celda de la placa
        if gate.kind == "heart":
            c, r = node
            cells = {(c, r)} if is_pinched(node) else {(c, r), (c, r - 1)}
            return bool(cells & set(gate.cells))
        if is_pinched(node) or not m.has_pulse(state):
            return False
        return m.pulse_hits(gate.openers, node, state)

    def near(self, gate, node):
        T = self.m.T
        if gate.kind in ("heart", "plate"):
            return gate.col - 1 <= node[0] <= gate.col + 1
        reach = self.m.rules.pulse_radius + T
        x = (node[0] + 0.5) * T
        return any(o[0] - reach <= x <= o[2] + reach for o in gate.openers)

    def like_options(self, cost, state, seen):
        """Opciones de la progresion: (coste, columna, accion, nodo) para cada accion de likes util. `seen`: pares
        (estado, nodo) ya visitados (no se repite una accion que deja el mismo estado en el mismo sitio)."""
        out = []
        if not self.like_gates:
            return out
        for g in self.like_gates:
            if not self.useful(g, state):
                continue
            nxt = self.apply(state, g)
            for n in sorted(cost, key=lambda n: (cost[n], n[0], n[1])):
                if self.near(g, n) and self.can_act(g, n, state):
                    if (nxt, n) not in seen:
                        out.append((cost[n], n[0], g, n))
                    break
        return out

    def extra_iterations(self):
        return len(self.hearts) + (self.likes_max // 5 + 1) * (len(self.pubs) + len(self.resets)) + 2 + len(self.plates)

    def softlock_nexts(self, node, state):
        """Publicaciones, reset y placas en el grafo de los soft-locks (sin los corazones: conservador)."""
        out = []
        for g in self.plates:
            if g.gid not in state and self.can_act(g, node, state):
                out.append((node, state | {g.gid}))
        likes = self.likes_of(state)
        for g in self.pubs + self.resets:
            if g.kind == "like_source" and likes >= self.likes_max:
                continue
            if g.kind == "like_reset" and likes == 0:
                continue
            if self.near(g, node) and self.can_act(g, node, state):
                out.append((node, self.apply(state, g)))
        return out

    # --- Pellizcar ---

    def has_compress(self, state):
        m = self.m
        if not self.compress_possible or "compress" in m.forbidden:
            return False
        return self.compress_base or any(g.gid in state for g in self.crop_gates)

    @property
    def cmodel(self):
        """Copia del LevelModel con la caja, la velocidad y el salto comprimidos (sus mundos aparte)."""
        if self._cmodel is None:
            m = self.m
            rules = copy.copy(m.rules)
            d = self.cfg_compress
            g = rules.gravity
            rules.walk_speed = float(d.get("walk_speed_px_s", 160.0))
            rules.run_speed = rules.walk_speed
            rules.allow_run = False
            rules.hitbox_w = float(d.get("width_px", 32.0))
            rules.hitbox_h = float(d.get("height_px", 40.0))
            rules.nominal_height = float(d.get("jump_height_px", 96.0))
            rules.jump_height = rules.nominal_height * rules.jump_efficiency
            rules.jump_v0 = math.sqrt(2.0 * g * rules.jump_height)
            v0 = math.sqrt(2.0 * g * rules.nominal_height)
            rules.jump_v0_game = v0
            rules.real_jump_height = _real_jump_height(v0, g)
            cm = copy.copy(m)
            cm.rules = rules
            cm.hw = rules.hitbox_w * 0.5
            cm.hh = rules.hitbox_h
            cm._worlds = {}
            cm._edges = {}
            self._cmodel = cm
        return self._cmodel

    def _size_edge(self, node, kind):
        T = self.m.T
        cx = (node[0] + 0.5) * T
        to = Pinched(node) if kind == "pinch" else plain(node)
        e = {"to": to, "kind": kind, "h": 0.0, "v": 0.0, "x0": cx, "travel": 0.0, "rise": 0.0, "speed": "walk",
             "xt": cx, "vy0": 0.0, "time": self.squash_s, "land_x": cx}
        if kind == "pinch":
            e["pinched"] = True
        return e

    def pinch_edges(self, node, state, debug):
        """Arista pinch desde un nodo normal (de pie, comprimirse siempre cabe)."""
        cw = self.cmodel.world(state, debug)
        if cw.is_node(node[0], node[1]):
            return [self._size_edge(node, "pinch")]
        return []

    def pinched_edges(self, node, state, debug):
        """Movimientos desde un nodo comprimido: los del mundo comprimido y la vuelta al tamano si cabe."""
        m = self.m
        key = (node, m.local_key(node, state), debug)
        if key in self._edges:
            return self._edges[key]
        out = []
        pn = plain(node)
        cw = self.cmodel.world(state, debug)
        speed = self.cmodel.rules.walk_speed
        for e in cw.compute_edges(pn):
            e = dict(e)
            e["to"] = Pinched(e["to"])
            e["pinched"] = True
            e["walk_px_s"] = speed
            out.append(e)
        if m.world(state, debug).is_node(pn[0], pn[1]):
            out.append(self._size_edge(pn, "unpinch"))
        self._edges[key] = out
        return out

    def world_for(self, node, state, debug):
        return self.cmodel.world(state, debug) if is_pinched(node) else self.m.world(state, debug)

    # --- Espejos: trazado del laser ---

    @staticmethod
    def _line_dir(orient):
        if orient == "/":
            return (1.0 / math.sqrt(2.0), -1.0 / math.sqrt(2.0))
        if orient == "\\":
            return (1.0 / math.sqrt(2.0), 1.0 / math.sqrt(2.0))
        return (0.0, 1.0)

    def _reflect(self, hx, hy, orient):
        if orient == "|":
            return -hx, -hy
        dx, dy = self._line_dir(orient)
        dot = hx * dx + hy * dy
        rx, ry = 2.0 * dot * dx - hx, 2.0 * dot * dy - hy
        return float(round(rx)), float(round(ry))

    def _reflection_point(self, x, y, hx, hy, center, orient):
        dx, dy = self._line_dir(orient)
        denom = hx * dy - hy * dx
        cx, cy = center[0] - x, center[1] - y
        if abs(denom) < 1e-4:
            s = cx * hx + cy * hy
        else:
            s = (cx * dy - cy * dx) / denom
        s = max(s, 0.0)
        return x + hx * s, y + hy * s, s

    @staticmethod
    def _enter(rect, x, y, hx, hy, half):
        """Distancia (>= 0) a la que el haz desde (x, y) con direccion (hx, hy) entra en `rect`, o None."""
        x0, y0, x1, y1 = rect[:4]
        if hy == 0.0:
            if y + half < y0 or y - half > y1:
                return None
            if x0 <= x <= x1:
                return 0.0
            near = x0 if hx > 0 else x1
            d = (near - x) * hx
            return d if d >= 0.0 else None
        if x + half < x0 or x - half > x1:
            return None
        if y0 <= y <= y1:
            return 0.0
        near = y0 if hy > 0 else y1
        d = (near - y) * hy
        return d if d >= 0.0 else None

    def _wall(self, w, x, y, hx, hy, limit, half):
        """Distancia al primer solido (o tabla fina) en la direccion del haz, hasta `limit` (INF si nada)."""
        m = self.m
        T = m.T
        steps = int(limit / T) + 3
        if hy == 0.0:
            r0, r1 = int(math.floor((y - half) / T)), int(math.floor((y + half - EPS) / T))
            c0 = int(math.floor((x - (EPS if hx < 0 else 0.0)) / T))
            for k in range(steps):
                c = c0 + k * (1 if hx > 0 else -1)
                for r in range(r0, r1 + 1):
                    blocked = w.is_solid(c, r)
                    if not blocked and (c, r) in w.thin:
                        blocked = y - half < r * T + w.thin[(c, r)] and y + half > r * T
                    if blocked:
                        face = c * T if hx > 0 else (c + 1) * T
                        return max(0.0, (face - x) * hx)
            return INF
        c0, c1 = int(math.floor((x - half) / T)), int(math.floor((x + half - EPS) / T))
        r0 = int(math.floor((y - (EPS if hy < 0 else 0.0)) / T))
        for k in range(steps):
            r = r0 + k * (1 if hy > 0 else -1)
            if r < 0 or r >= m.rows:
                return INF
            for c in range(c0, c1 + 1):
                if w.is_solid(c, r):
                    face = r * T if hy > 0 else (r + 1) * T
                    return max(0.0, (face - y) * hy)
                if (c, r) in w.thin:
                    top, bottom = r * T, r * T + w.thin[(c, r)]
                    if hy < 0:
                        if y > bottom - EPS:
                            return y - bottom
                        if y >= top:
                            return 0.0
                    else:
                        if y < top + EPS:
                            return top - y
                        if y <= bottom:
                            return 0.0
        return INF

    def trace(self, w, x, y, hx, hy, rect, max_bounces=None, hunters=None):
        """Trazado del laser con rebotes hasta `rect`: {"dist", "bounces", "mirrors", "points"} o None.
        `hunters` (paso 8b): espejos cazadores [{"id", "rect", "center", "out": (hx, hy) o None}]: el disparo sale
        de su centro hacia `out` (cuenta como rebote) o, con None, lo paran."""
        if hunters:
            return self._trace_hunters(w, x, y, hx, hy, rect, max_bounces, hunters)
        rules = self.m.rules
        max_bounces = self.max_bounces if max_bounces is None else max_bounces
        remaining = rules.laser_range
        half = rules.laser_thickness * 0.5
        traveled = 0.0
        bounces = 0
        used = []
        points = [(x, y)]
        excluded = None
        for _ in range(max_bounces + 2):
            d_target = self._enter(rect, x, y, hx, hy, half)
            d_wall = self._wall(w, x, y, hx, hy, remaining, half)
            d_mirror, mirror = INF, None
            for mi in self.mirrors:
                if mi is excluded:
                    continue
                d = self._enter(mi["rect"], x, y, hx, hy, 0.0)
                if d is not None and d < d_mirror:
                    d_mirror, mirror = d, mi
            if d_target is not None and d_target <= min(d_wall, d_mirror, remaining) + EPS:
                points.append((x + hx * d_target, y + hy * d_target))
                return {"dist": traveled + d_target, "bounces": bounces, "mirrors": used, "points": points}
            if mirror is None or d_mirror > remaining + EPS or d_mirror >= d_wall - EPS:
                return None
            if bounces >= max_bounces:
                return None  # el espejo para el disparo (limite de rebotes)
            hx0, hy0 = hx, hy
            ax, ay = x + hx * d_mirror, y + hy * d_mirror
            bx, by, extra = self._reflection_point(ax, ay, hx, hy, mirror["center"], mirror["orient"])
            traveled += d_mirror + extra
            remaining -= d_mirror + extra
            if remaining <= EPS:
                return None
            hx, hy = self._reflect(hx0, hy0, mirror["orient"])
            x, y = bx, by
            bounces += 1
            used.append(mirror["id"])
            points.append((x, y))
            excluded = mirror
        return None

    def _trace_hunters(self, w, x, y, hx, hy, rect, max_bounces, hunters):
        """trace() con los espejos cazadores como reflectores (paso 8b)."""
        rules = self.m.rules
        max_bounces = self.max_bounces if max_bounces is None else max_bounces
        remaining = rules.laser_range
        half = rules.laser_thickness * 0.5
        traveled = 0.0
        bounces = 0
        used = []
        points = [(x, y)]
        excluded = None
        for _ in range(max_bounces + 2):
            d_target = self._enter(rect, x, y, hx, hy, half)
            d_wall = self._wall(w, x, y, hx, hy, remaining, half)
            d_mirror, mirror = INF, None
            for mi in self.mirrors + hunters:
                if mi is excluded:
                    continue
                d = self._enter(mi["rect"], x, y, hx, hy, 0.0)
                if d is not None and d < d_mirror:
                    d_mirror, mirror = d, mi
            if d_target is not None and d_target <= min(d_wall, d_mirror, remaining) + EPS:
                points.append((x + hx * d_target, y + hy * d_target))
                return {"dist": traveled + d_target, "bounces": bounces, "mirrors": used, "points": points}
            if mirror is None or d_mirror > remaining + EPS or d_mirror >= d_wall - EPS:
                return None
            if bounces >= max_bounces:
                return None
            ax, ay = x + hx * d_mirror, y + hy * d_mirror
            if "out" in mirror:
                if mirror["out"] is None:
                    return None  # cazador en una orientacion que no se modela: para el disparo
                bx, by = mirror["center"]
                extra = math.hypot(bx - ax, by - ay)
                nhx, nhy = mirror["out"]
            else:
                bx, by, extra = self._reflection_point(ax, ay, hx, hy, mirror["center"], mirror["orient"])
                nhx, nhy = self._reflect(hx, hy, mirror["orient"])
            traveled += d_mirror + extra
            remaining -= d_mirror + extra
            if remaining <= EPS:
                return None
            hx, hy = nhx, nhy
            x, y = bx, by
            bounces += 1
            used.append(mirror["id"])
            points.append((x, y))
            excluded = mirror
        return None

    def hunter_reflectors(self, node):
        """Cazadores para el laser desde `node`: fuera de su radio miran a su reposo (si es horizontal o vertical,
        reflejan); dentro o en diagonal, paran el disparo."""
        out = []
        cx, cy = self.isak_center(node)
        for h in self.hunters:
            out_dir = None
            if math.hypot(cx - h["center"][0], cy - h["center"][1]) > h["radius"] + EPS and h["rest"] % 2 == 0:
                vx, vy = facing_vector(h["rest"])
                out_dir = (float(round(vx)), float(round(vy)))
            out.append({"id": h["id"], "rect": h["rect"], "center": h["center"], "out": out_dir})
        return out

    def isak_center(self, node):
        T = self.m.T
        hh = self.cmodel.hh if is_pinched(node) else self.m.hh
        return (node[0] + 0.5) * T, (node[1] + 1) * T - hh * 0.5

    def laser_shot(self, rect, node, state, debug=False, max_bounces=None):
        """Como LevelModel.laser_shot, con el trazado por espejos."""
        if is_pinched(node):
            return None
        m = self.m
        rules = m.rules
        if rules.laser_range <= 0.0:
            return None
        w = m.world(state, debug if debug in (True, False) else False)
        c, r = node
        T = m.T
        feet = (r + 1) * T
        py = feet + rules.phone_y
        x = c * T
        hunters = self.hunter_reflectors(node) if self.hunters else None
        while x <= (c + 1) * T + EPS:
            if not w.collides(x, feet):
                for facing in (1.0, -1.0):
                    px = x + rules.phone_x * facing
                    hit = self.trace(w, px, py, facing, 0.0, rect, max_bounces, hunters)
                    if hit is not None:
                        return {"x": x, "facing": facing, "dist": hit["dist"], "bounces": hit["bounces"],
                                "mirrors": list(hit["mirrors"]), "points": hit["points"]}
            x += SAMPLE_PX
        return None

    # --- Espejo cazador: pulso reflejado (paso 8b) ---

    def beam_end(self, h, index, w):
        """Fin del haz del cazador `h` mirando a `index`: beam_tiles o el primer solido (HunterMirror.get_beam_end)."""
        T = self.m.T
        x0, y0 = h["center"]
        vx, vy = facing_vector(index)
        step = 4.0
        d = 0.0
        while d < h["beam"] - EPS:
            nd = min(d + step, h["beam"])
            x, y = x0 + vx * nd, y0 + vy * nd
            c, r = int(math.floor(x / T)), int(math.floor(y / T))
            if (c, r) != h["cell"] and w.is_solid(c, r):
                return x0 + vx * d, y0 + vy * d
            d = nd
        return x0 + vx * h["beam"], y0 + vy * h["beam"]

    def beam_touches(self, h, index, rects, w):
        a = h["center"]
        b = self.beam_end(h, index, w)
        g = h["beam_half"]
        return any(segment_hits_rect(a, b, (r[0] - g, r[1] - g, r[2] + g, r[3] + g)) for r in rects)

    def hunter_options(self, h, node):
        """Orientaciones (indice, giros desde el reposo) que puede tener el cazador cuando Isak lo pulsa desde
        `node`: fuera de su radio, el reposo; dentro, el reposo si Isak llega antes del primer giro y las del giro
        hacia Isak (esperando quieto)."""
        cx, cy = self.isak_center(node)
        dx, dy = cx - h["center"][0], cy - h["center"][1]
        dist = math.hypot(dx, dy)
        if dist > h["radius"] + EPS:
            return [(h["rest"], 0)]
        seq = list(enumerate(turn_path(h["rest"], index_for_vector(dx, dy))))
        approach = self.m.rules.walk_speed * h["interval"] * HUNTER_APPROACH_FRACTION
        if len(seq) > 1 and h["radius"] - dist > approach:
            seq = seq[1:]
        return [(idx, k) for k, idx in seq]

    def beam_hit(self, rects, node, state, debug=False):
        """El pulso desde `node` alcanza un cazador cuyo haz toca `rects` en una orientacion posible:
        {"hunter", "index", "turns", "shot"} o None."""
        if not self.hunters or is_pinched(node) or not rects:
            return None
        m = self.m
        if not m.has_pulse(state):
            return None
        w = m.world(state, False)
        for h in self.hunters:
            shot = m.pulse_shot([h["rect"]], node, state, debug)
            if shot is None:
                continue
            for idx, k in self.hunter_options(h, node):
                if self.beam_touches(h, idx, rects, w):
                    return {"hunter": h, "index": idx, "turns": k, "shot": shot}
        return None

    def beam_step_info(self, rects, node, state):
        """(shot, via_hunter) para el paso del plan de un pulso que llega por el cazador (o (None, None))."""
        hit = self.beam_hit(rects, node, state)
        if hit is None:
            return None, None
        return hit["shot"], {"id": hit["hunter"]["id"], "facing": FACINGS[hit["index"]], "turns": hit["turns"]}

    def beam_note(self, rects, node, state):
        hit = self.beam_hit(rects, node, state) if self.hunters else None
        if hit is None or self.m.pulse_hits(rects, node, state):
            return ""
        return " (por el espejo cazador %s mirando al %s)" % (hit["hunter"]["id"], FACINGS[hit["index"]])

    # --- Comprobaciones tras el camino principal ---

    def check(self, v, start, goal_cells):
        """Pellizcar, likes, filtros y espejos sobre el camino principal (Validator.main)."""
        out = {}
        main = v.main
        if main["ok"]:
            nodes, states = self._path_nodes(v, main)
            if self.compress_possible:
                out["pinch"] = self._check_pinch(v, nodes, states)
            if self.like_platforms or any(g.kind in LIKE_KINDS for g in self.like_gates):
                out["likes"] = self._check_likes(v, main, nodes, states, start)
            if self.filters:
                out["filters"] = self._check_filters(v, main)
            if self.mirror_only:
                out["mirror_only"] = self._check_mirror_only(v, main)
        if self.mirrors:
            out["mirrors"] = self._check_mirrors(v, main)
        if out:
            v.result["world3"] = out

    def _path_nodes(self, v, run):
        """Nodos del camino en orden y el estado con el que se pisa cada uno."""
        nodes, states = [], []
        for stage in run["stages"]:
            if stage["end"] is None:
                continue
            seg = _path(stage["parent"], stage["end"])
            nodes.append(stage["src"])
            states.append(stage["state"])
            for _, e in seg:
                nodes.append(e["to"])
                states.append(stage["state"])
            if stage.get("relay"):
                for _, e in stage["relay"]["path"]:
                    nodes.append(e["to"])
                    states.append(stage["state"])
        return nodes, states

    def _check_pinch(self, v, nodes, states):
        m = self.m
        T = m.T
        runs = []
        i = 0
        while i < len(nodes):
            if not is_pinched(nodes[i]):
                i += 1
                continue
            j = i
            while j + 1 < len(nodes) and is_pinched(nodes[j + 1]):
                j += 1
            runs.append((i, j))
            i = j + 1
        items = []
        for a, b in runs:
            seq = nodes[a:b + 1]
            prev = nodes[a - 1] if a > 0 else seq[0]
            nxt = nodes[b + 1] if b + 1 < len(nodes) else None
            tiles = sum(abs(q[0] - p[0]) for p, q in zip(seq, seq[1:]))
            tight = [k for k, n in enumerate(seq) if not m.world(states[a + k], False).is_node(n[0], n[1])]
            recover = None
            if tight and nxt is not None:
                last = tight[-1]
                recover = sum(abs(q[0] - p[0]) + abs(q[1] - p[1]) for p, q in zip(seq[last:], seq[last + 1:]))
            cells = set()
            chain = [prev] + seq + ([nxt] if nxt is not None else [])
            for p, q in zip(chain, chain[1:]):
                for n in (p, q):
                    cells |= {(n[0], n[1])} if is_pinched(n) else {(n[0], n[1]), (n[0], n[1] - 1)}
                if p[0] == q[0]:
                    lo, hi = sorted((p[1], q[1]))
                    cells |= {(p[0], rr) for rr in range(lo, hi + 1)}
            frames = sorted(f["id"] for f in self.small_frames if f["cells"] & cells)
            cols = [n[0] for n in seq]
            item = {"from": [seq[0][1], seq[0][0]], "to": [seq[-1][1], seq[-1][0]], "cols": [min(cols), max(cols)],
                    "tiles": float(tiles), "frames": frames, "recover_tiles": recover,
                    "section": m.section_name(seq[0][0], seq[0][1]), "ends_compressed": nxt is None}
            items.append(item)
            if recover is not None and recover > RECOVER_MAX_TILES:
                t = seq[tight[-1]]
                v.report.error("Pellizcar: la salida comprimida de (fila %d, columna %d) no deja recuperar el tamano "
                               "hasta %d tiles (maximo %d, docs/propuesta-mundo-3.md §3.3.2)"
                               % (t[1], t[0], recover, RECOVER_MAX_TILES), t[1], t[0])
            if tiles > COMPRESSED_MAX_TILES:
                v.report.error("Pellizcar: el camino va comprimido %d tiles seguidos de (fila %d, columna %d) a (fila %d, "
                               "columna %d) (maximo %d, §3.3.2)" % (tiles, seq[0][1], seq[0][0], seq[-1][1], seq[-1][0],
                                                                   COMPRESSED_MAX_TILES), seq[0][1], seq[0][0])
        sections = []
        for it in items:
            name = it["section"] or ""
            sec = next((s for s in sections if s["name"] == name), None)
            if sec is None:
                span = next(((s.get("x_from", 0), s.get("x_to", m.cols - 1)) for s in m.sections
                             if s.get("name", "") == name), None) if name else None
                sec = {"name": name, "cols": list(span) if span else list(it["cols"]), "frames": [], "max_tiles": 0.0,
                       "runs": 0}
                sections.append(sec)
            sec["runs"] += 1
            sec["frames"] = sorted(set(sec["frames"]) | set(it["frames"]))
            sec["max_tiles"] = max(sec["max_tiles"], it["tiles"])
            if not name:
                sec["cols"] = [min(sec["cols"][0], it["cols"][0]), max(sec["cols"][1], it["cols"][1])]
        return {"runs": items, "sections": sections, "available": True,
                "box_px": [self.cmodel.rules.hitbox_w, self.cmodel.rules.hitbox_h],
                "walk_speed_px_s": self.cmodel.rules.walk_speed, "jump_height_px": round(self.cmodel.rules.jump_height, 1),
                "squash_s": self.squash_s}

    def _check_likes(self, v, main, nodes, states, start):
        m = self.m
        T = m.T
        hearts = pubs = resets = 0
        for stage in main["stages"]:
            g = stage.get("gate")
            if g is None or g.kind not in LIKE_KINDS:
                continue
            hearts += g.kind == "heart"
            pubs += g.kind == "like_source"
            resets += g.kind == "like_reset"
        final = self.likes_of(main["stages"][-1]["state"])
        used = []
        cell_of = {}
        for p in self.like_platforms:
            for cell in p["cells"]:
                cell_of[cell] = p
        for idx, n in enumerate(nodes):
            p = cell_of.get((n[0], n[1] + 1))
            if p is None or not self.platform_on(p, self.likes_of(states[idx])):
                continue
            if any(u["id"] == p["id"] for u in used):
                continue
            used.append({"id": p["id"], "threshold": p["threshold"], "invert": p["invert"], "index": idx,
                         "likes": self.likes_of(states[idx]), "at": [n[1], n[0]]})
        # Regla anti-atasco: una publicacion alcanzable sin likes desde el ultimo punto de sincronizacion.
        cps = []
        for cp in v.level.get("checkpoints", []):
            cps.append((cp["id"], (cp["x"], cp["y"])))
        for u in used:
            if u["invert"]:
                continue
            src_name, src_node, src_state = "P", start, frozenset()
            for k in range(u["index"]):
                n = nodes[k]
                body = {(n[0], n[1])} if is_pinched(n) else {(n[0], n[1]), (n[0], n[1] - 1)}
                for cid, cell in cps:
                    if cell in body:
                        node, _ = v.spawn_node(cell)
                        if node is not None:
                            src_name, src_node, src_state = cid, node, states[k]
            base = self.with_likes(frozenset(t for t in src_state if not t.startswith("heart:")), 0)
            reach = _search(m, src_node, base, m.rules.limit)
            source = None
            for g in self.pubs:
                for n in sorted(reach, key=lambda n: (reach[n], n[0], n[1])):
                    if self.near(g, n) and self.can_act(g, n, base):
                        source = g.obj_id
                        break
                if source:
                    break
            u["sync"] = src_name
            u["publication"] = source
            if source is None:
                v.report.error("anti-atasco: la plataforma de likes %s (likes %d) esta en el camino y desde %s no se "
                               "alcanza ninguna publicacion (like_source) sin likes: perder likes bloquearia el nivel "
                               "(docs/propuesta-mundo-3.md §3.1)" % (u["id"], u["threshold"], src_name),
                               u["at"][0], u["at"][1], u["id"])
        return {"thresholds": list(self.thresholds), "platforms": [
            {"id": p["id"], "threshold": p["threshold"], "invert": p["invert"]} for p in self.like_platforms],
            "hearts": hearts, "publications": pubs, "resets": resets, "final": final,
            "used": [{k: u[k] for k in ("id", "threshold", "invert", "likes", "at", "sync", "publication") if k in u}
                     for u in used]}

    def _check_filters(self, v, main):
        m = self.m
        T = m.T
        crossed = {}
        for stage in main["stages"]:
            if stage["end"] is None:
                continue
            for _, e in _path(stage["parent"], stage["end"]):
                if not e.get("debug"):
                    continue
                n = e["to"]
                body = {(n[0], n[1])} if is_pinched(n) else {(n[0], n[1]), (n[0], n[1] - 1)}
                for f in self.filters:
                    if f["blind"] & body:
                        crossed.setdefault(f["id"], n)
        items = []
        for f in self.filters:
            item = {"id": f["id"], "moving": f["moving"], "spikes": len(f["spikes"]), "fake_floor": len(f["fake_floor"]),
                    "needs_debug": bool(f["blind"]), "crossed_with_debug": f["id"] in crossed, "charger": None,
                    "positions": len(f["rects"]), "cycle_s": f["cycle_s"]}
            if f["id"] in crossed:
                entry = f["entry_col"]
                lo, hi = (entry - VIEW_TILES, entry) if f["entry"] == "left" else (entry, entry + VIEW_TILES)
                ch = next((c for c in sorted(m.chargers, key=lambda c: abs(c["cell"][0] - entry))
                           if lo <= c["cell"][0] <= hi), None)
                if ch is not None:
                    item["charger"] = {"id": ch["id"], "col": ch["cell"][0]}
                else:
                    v.report.error("el filtro %s es obligatorio (solo se cruza con el Debug) y no hay un cargador a la "
                                   "vista antes de su entrada (columnas %d-%d; docs/propuesta-mundo-3.md §3.2)"
                                   % (f["id"], lo, hi), f["row"], f["col"], "filtro %s" % f["id"])
            items.append(item)
        return items

    def _check_mirror_only(self, v, main):
        m = self.m
        T = m.T
        items = []
        on = {}
        for stage in main["stages"]:
            if stage["end"] is None:
                continue
            for prev, e in _path(stage["parent"], stage["end"]):
                n = e["to"]
                for p in self.mirror_only:
                    if (n[0], n[1] + 1) in p["cells"] and p["id"] not in on:
                        on[p["id"]] = (prev, n)
        for p in self.mirror_only:
            rect = p["rect"]
            cx, cy = (rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5
            wall = None
            best = INF
            for w in self.mirror_walls:
                wx, wy = (w["rect"][0] + w["rect"][2]) * 0.5, (w["rect"][1] + w["rect"][3]) * 0.5
                d = (wx - cx) ** 2 + (wy - cy) ** 2
                if d < best:
                    best, wall = d, w
            item = {"id": p["id"], "wall": None, "seen": False, "on_path": p["id"] in on}
            if wall is not None:
                rx0, rx1 = 2.0 * wall["axis"] - rect[2], 2.0 * wall["axis"] - rect[0]
                g = wall["glass"]
                seen = rx0 < g[2] and rx1 > g[0] and rect[1] < g[3] and rect[3] > g[1]
                item.update({"wall": wall["id"], "seen": seen,
                             "reflected_cols": [int(math.floor(rx0 / T)), int(math.floor((rx1 - EPS) / T))]})
            if not item["seen"]:
                v.report.error("la plataforma del reflejo %s no se ve en ninguna pared de espejo (mirror_wall): reflejada "
                               "en %s cae fuera del cristal" % (p["id"], item["wall"] or "-"), p["row"], p["col"],
                               "plataforma del reflejo %s" % p["id"])
            elif p["id"] in on:
                prev, n = on[p["id"]]
                g = wall["rect"]
                x = (prev[0] + 0.5) * T
                gap = 0.0 if g[0] <= x <= g[2] else min(abs(x - g[0]), abs(x - g[2]))
                item["from"] = [prev[1], prev[0]]
                item["wall_in_view"] = gap <= VIEW_TILES * T * 0.5
                if not item["wall_in_view"]:
                    v.report.error("el camino salta a la plataforma del reflejo %s desde (fila %d, columna %d) sin la pared "
                                   "de espejo %s a la vista" % (p["id"], prev[1], prev[0], wall["id"]), prev[1], prev[0])
            items.append(item)
        return items

    def _laser_targets(self):
        m = self.m
        out = [("lector", lec["id"], lec["rect"], lec["cell"]) for lec in m.lectors.values()]
        for g in m.gates:
            if g.kind == "lswitch":
                out.append(("interruptor laser", g.obj_id, g.openers[0], (g.col, g.row)))
        return out

    def _check_mirrors(self, v, main):
        m = self.m
        state = main["stages"][-1]["state"] if main.get("stages") else frozenset()
        nodes = sorted({plain(n) for n in main.get("reached", set()) if not is_pinched(n)}, key=lambda n: (n[0], n[1]))
        items = []
        for what, tid, rect, cell in self._laser_targets():
            if not m.has_laser(state):
                break
            best = None
            for n in nodes:
                shot = self.laser_shot(rect, n, state)
                if shot is not None and (best is None or (shot["bounces"], shot["dist"]) < (
                        best[1]["bounces"], best[1]["dist"])):
                    best = (n, shot)
            item = {"what": what, "id": tid, "cell": [cell[1], cell[0]], "from": None}
            if best is not None:
                n, shot = best
                item.update({"from": [n[1], n[0]], "bounces": shot["bounces"], "mirrors": shot["mirrors"],
                             "dist_px": round(shot["dist"], 1), "range_px": m.rules.laser_range})
            else:
                more = None
                for n in nodes:
                    shot = self.laser_shot(rect, n, state, max_bounces=DIAG_BOUNCES)
                    if shot is not None and (more is None or shot["bounces"] < more[1]["bounces"]):
                        more = (n, shot)
                if more is not None:
                    n, shot = more
                    item["needs_bounces"] = shot["bounces"]
                    v.report.error("el %s %s solo se alcanzaria con %d rebotes del laser (desde (fila %d, columna %d)); "
                                   "el maximo es %d (mirror.max_bounces)" % (what, tid, shot["bounces"], n[1], n[0],
                                                                             self.max_bounces), cell[1], cell[0], tid)
            items.append(item)
        return items

    # --- Explicacion de fallos ---

    def explain(self, v, reached, state):
        """Errores concretos del Mundo 3 cuando no hay camino (antes del generico)."""
        m = self.m
        out = []
        cols = [n[0] for n in reached]
        far = max(cols) if cols else 0
        for f in self.filters:
            if not f["blind"]:
                continue
            c0 = min(c for c, _ in f["blind"])
            if c0 > far + m.K + 2 or max(c for c, _ in f["blind"]) < far - 1:
                continue
            if not (m.debug_base or any(g.kind == "pickup" and g.ability == "debug" for g in m.gates)):
                out.append(("el filtro %s esconde %s: solo se cruza con el Debug encendido y el nivel no lo tiene"
                            % (f["id"], "pinchos o suelo falso" if f["fake_floor"] else "pinchos"), f["row"], f["col"]))
            elif not m.has_debug(state):
                out.append(("el filtro %s solo se cruza con el Debug encendido y aun no se tiene" % f["id"],
                            f["row"], f["col"]))
        likes = self.likes_of(state)
        for p in self.like_platforms:
            if p["invert"] or self.platform_on(p, likes):
                continue
            if p["span"][0] > far + m.K + 2 or p["span"][1] < far - m.K - 2:
                continue
            out.append(("la plataforma de likes %s (likes %d) sigue apagada: el camino llega con %d like(s) y no "
                        "alcanza mas corazones ni una publicacion" % (p["id"], p["threshold"], likes), p["row"], p["col"]))
        if self.compress_possible and not self.has_compress(state):
            for f in self.small_frames:
                c = min(cc for cc, _ in f["cells"])
                if abs(c - far) <= m.K + 2:
                    out.append(("el marco pequeno %s solo se cruza comprimido y Pellizcar aun no se tiene (lo da %s)"
                                % (f["id"], ", ".join(g.label() for g in self.crop_gates) or "-"),
                                min(r for _, r in f["cells"]), c))
        elif not self.compress_possible:
            for f in self.small_frames:
                c = min(cc for cc, _ in f["cells"])
                if abs(c - far) <= m.K + 2:
                    out.append(("el marco pequeno %s solo se cruza comprimido y el nivel no tiene Pellizcar (ni "
                                "abilities_available.compress ni una herramienta Recortar)" % f["id"],
                                min(r for _, r in f["cells"]), c))
        for d in self.doors:
            if self.door_open(d, state) or abs(d["col"] - far) > m.K + 2:
                continue
            plates = [g for g in self.plates if g.gid in d["plates"]]
            out.append(("la puerta de marco %s sigue cerrada: el camino no llega a %s" % (
                d["id"], ", ".join("su placa %s" % g.obj_id for g in plates) or "ninguna placa (no tiene)"),
                d["row"], d["col"]))
        for h in self.hunters:
            if abs(h["cell"][0] - far) > m.K + 4:
                continue
            w = m.world(state, False)
            for g in m.gates:
                if g.kind != "bridge" or g.gid in state or not g.openers:
                    continue
                if not any(self.beam_touches(h, i, g.openers, w) for i in range(8)):
                    continue
                looks = [FACINGS[i] for i in range(8) if self.beam_touches(h, i, g.openers, w)]
                out.append(("%s: el espejo cazador %s solo llevaria el pulso al receptor mirando al %s y no mira asi "
                            "desde ninguna celda alcanzable desde la que se le pulsa (reposo %s; gira hacia Isak a "
                            "<= %.1f tiles)" % (g.label(), h["id"], "/".join(looks), FACINGS[h["rest"]],
                                                h["radius"] / m.T), h["cell"][1], h["cell"][0]))
        return out


def _path(parent, target):
    out = []
    node = target
    while parent.get(node) is not None:
        prev, edge = parent[node]
        out.append((prev, edge))
        node = prev
    out.reverse()
    return out


def _search(model, source, state, limit):
    """Alcance (nodos -> exigencia) desde `source` en `state` (busqueda de cuello de botella sencilla)."""
    import heapq
    best = {source: 0.0}
    heap = [(0.0, 0, source)]
    k = 0
    while heap:
        c, _, node = heapq.heappop(heap)
        if c > best.get(node, INF) + EPS:
            continue
        for e in model.edges(node, state, "auto"):
            d = max(e["h"], e["v"])
            if d > limit + EPS:
                continue
            nc = max(c, d)
            to = e["to"]
            if nc < best.get(to, INF) - EPS:
                best[to] = nc
                k += 1
                heapq.heappush(heap, (nc, k, to))
    return best


# --- Plan del camino (tools/level_plan.py) ---

def plan_steps(planner, g, n, state, stage, last_pub):
    """Pasos del plan para una accion de likes de la progresion. `last_pub`: {id: True} de la publicacion usada en
    la accion anterior (si se repite seguida, se espera su enfriamiento)."""
    if g.kind == "plate":
        return []  # pisar la placa es parte del recorrido (el plan comprueba la puerta con el tiempo)
    likes = stage.get("likes_after")
    if g.kind == "heart":
        return [{"action": "heart", "at": n, "state": state, "likes_after": likes,
                 "target": {"type": "heart_pickup", "id": g.obj_id, "likes_after": likes}}]
    shot = planner.m.pulse_shot(g.openers, n, state)
    if g.kind == "like_reset":
        return [{"action": "like_reset", "at": n, "shot": shot, "state": state, "face_back": True, "pose_s": g.pose_s,
                 "count": 1, "of": 1, "target": {"type": "like_reset", "id": g.obj_id, "likes_after": 0}}]
    out = []
    if last_pub.get("id") == g.obj_id:
        out.append({"action": "wait", "at": n, "seconds": g.cooldown_s, "state": state,
                    "reason": "enfriamiento de la publicacion %s" % g.obj_id,
                    "target": {"type": "like_source", "id": g.obj_id}})
    out.append({"action": "pulse", "at": n, "shot": shot, "state": state,
                "target": {"type": "like_source", "id": g.obj_id, "likes_after": likes}})
    return out


# --- Plan del camino: espejo cazador, enemigos, Reflejo falso y puertas de marco (paso 8b) ---

def _step_frames(planner, steps):
    """Cuadros del camino (Planner.frames) y el primer cuadro de cada paso (con uno de mas al final)."""
    frames = planner.frames(steps)
    first = []
    n = 0
    for s in steps:
        first.append(n)
        n += len(planner.samples(s))
    first.append(n)
    return frames, first


def _step_pinched(s):
    if s["action"] == "move":
        return is_pinched(s["to"]) or is_pinched(s["from"])
    return is_pinched(s.get("at") or ())


def _end_frame(steps, first):
    for i, s in enumerate(steps):
        if s.get("final"):
            return first[i + 1]
    return first[-1]


def _pulse_reach(rules, x, feet, facings, rect):
    for f in facings:
        px, py = x + rules.phone_x * f, feet + rules.phone_y
        qx = min(max(px, rect[0]), rect[2])
        qy = min(max(py, rect[1]), rect[3])
        if math.hypot(px - qx, py - qy) <= rules.pulse_radius + EPS:
            return True
    return False


def _cell_of(T, x, feet):
    return (int(x // T), int(round(feet / T)) - 1)


def _hunter_advance(h, st, cx, cy, dt):
    """Un paso de HunterMirror.advance con Isak (centro de su caja) en (cx, cy)."""
    if st["freeze"] > 0.0:
        st["freeze"] -= dt
        if st["freeze"] <= 0.0:
            st["freeze"] = 0.0
            st["turn"] = 0.0
        return
    dx, dy = cx - h["center"][0], cy - h["center"][1]
    target = index_for_vector(dx, dy) if math.hypot(dx, dy) <= h["radius"] else h["rest"]
    if target == st["idx"]:
        st["turn"] = 0.0
        return
    st["turn"] += dt
    if st["turn"] >= h["interval"] - 0.0001:
        st["idx"] = step_toward(st["idx"], target)
        st["turn"] = 0.0


def plan_hunters(planner, steps):
    """Orientacion del espejo cazador por tiempo en los pulsos que llegan por su haz (target.via_hunter): si al
    pulsarlo aun no mira donde hace falta, espera wait_hunter delante del pulso; si esperando no llegaria, error."""
    w3 = planner.m.w3
    if w3 is None or not w3.hunters:
        return steps
    items = []
    for _ in range(MAX_FIXES):
        problem, items = _sim_hunters(planner, w3, steps)
        if problem is None:
            break
        i, h, st, need, x, feet = problem
        s = steps[i]
        wait = _hunter_wait(planner, w3, h, st, need, x, feet)
        node = s["at"]
        if wait is None:
            planner.error("espejo cazador %s: cuando el camino lo pulsa desde (fila %d, columna %d) mira al %s y su haz "
                          "solo llega a %s mirando al %s; esperando quieto no llega a mirar asi (docs/propuesta-mundo-3.md "
                          "§3.6)" % (h["id"], node[1], node[0], FACINGS[st["idx"]], s["target"].get("id"), FACINGS[need]),
                          node, h["id"])
            break
        steps = steps[:i] + [{"action": "wait_hunter", "at": node, "seconds": wait, "state": s["state"],
                              "reason": "esperar a que el espejo cazador %s mire al %s" % (h["id"], FACINGS[need]),
                              "target": {"type": "hunter_mirror", "id": h["id"], "facing": FACINGS[need]}}] + steps[i:]
        if s.get("relay"):
            s["relay"] = dict(s["relay"], time_s=s["relay"]["time_s"] + wait)
        via = s["target"]["via_hunter"]
        via["wait_s"] = round(via.get("wait_s", 0.0) + wait, 3)
    planner.v.result.setdefault("world3", {})["hunters"] = items
    return steps


def _sim_hunters(planner, w3, steps):
    frames, first = _step_frames(planner, steps)
    rules = planner.rules
    sts = [{"idx": h["rest"], "turn": 0.0, "freeze": 0.0} for h in w3.hunters]
    items = []
    end = _end_frame(steps, first)
    for f in range(min(end, len(frames))):
        i, k, x, feet, air, debug, action, _ = frames[f]
        s = steps[i]
        dt = DT_SIM * (rules.debug_world_scale if debug else 1.0)
        hh = w3.cmodel.hh if _step_pinched(s) else w3.m.hh
        cx, cy = x, feet - hh * 0.5
        if action == "pulse" and k == 0:
            shot = s.get("shot")
            facings = (shot["facing"],) if shot else (1.0, -1.0)
            via = (s.get("target") or {}).get("via_hunter")
            for h, st in zip(w3.hunters, sts):
                if via and via["id"] == h["id"]:
                    need = FACINGS.index(via["facing"])
                    dx, dy = cx - h["center"][0], cy - h["center"][1]
                    target = index_for_vector(dx, dy) if math.hypot(dx, dy) <= h["radius"] else h["rest"]
                    ok = st["freeze"] > 0.0 or (st["idx"] == need and (
                        target == need or st["turn"] <= h["interval"] - HUNTER_TURN_MARGIN_S))
                    if st["freeze"] > 0.0:
                        ok = st["idx"] == need
                    if not ok:
                        return (i, h, dict(st), need, x, feet), items
                    items.append({"id": h["id"], "from": [s["at"][1], s["at"][0]], "facing": via["facing"],
                                  "target": s["target"].get("id"), "wait_s": via.get("wait_s", 0.0),
                                  "t": round(f * DT_SIM, 2)})
                if _pulse_reach(rules, x, feet, facings, h["rect"]):
                    st["freeze"] = h["freeze"]
                    st["turn"] = 0.0
        for h, st in zip(w3.hunters, sts):
            _hunter_advance(h, st, cx, cy, dt)
    return None, items


def _hunter_wait(planner, w3, h, st, need, x, feet):
    """Segundos de espera quieto (pies en x, feet) hasta que el cazador mira a `need`, o None."""
    st = dict(st)
    cx, cy = x, feet - w3.m.hh * 0.5
    t = 0.0
    while t < MAX_WAIT_S:
        _hunter_advance(h, st, cx, cy, DT_SIM)
        t += DT_SIM
        if st["idx"] == need and st["freeze"] <= 0.0 and st["turn"] <= EPS:
            return round(t + DT_SIM, 4)
    return None


def plan_enemies(planner, steps):
    """Influencer, Ladron, Reflejo falso y puertas de marco a lo largo del camino (simulacion por cuadros): inserta
    pulsos que aturden y esperas wait_reflection; lo que no se resuelve es un error."""
    w3 = planner.m.w3
    if w3 is None or not (w3.influencers or w3.thieves or w3.reflections or w3.doors):
        return steps
    attempts = {}
    res = None
    for _ in range(MAX_FIXES + 1):
        res = _EnemySim(planner, w3, steps).run()
        fix = res["fix"]
        if fix is None:
            break
        key = fix.get("key")
        attempts[key] = attempts.get(key, 0) + 1
        if attempts[key] > 3:
            res["errors"].append(fix["fail"])
            break
        steps = _apply_fix(steps, fix)
    else:
        res["errors"].append(("no se pudieron resolver los enemigos del Mundo 3 con %d pulsos o esperas" % MAX_FIXES,
                              None, None))
    seen = set()
    for message, node, obj in res["errors"]:
        if message in seen:
            continue
        seen.add(message)
        planner.error(message, node, obj)
    planner.v.result.setdefault("world3", {})["enemies"] = res["info"]
    return steps


def _apply_fix(steps, fix):
    pos, off = fix["pos"], fix.get("offset", 0)
    new = fix["step"]
    if off:
        s = steps[pos]
        a = {k: v for k, v in s.items() if not k.startswith("_") and k != "final"}
        a["seconds"] = off * DT_SIM
        b = {k: v for k, v in s.items() if not k.startswith("_")}
        b["seconds"] = max(0.0, s.get("seconds", 0.0) - off * DT_SIM)
        return steps[:pos] + [a, new, b] + steps[pos + 1:]
    return steps[:pos] + [new] + steps[pos:]


class _EnemySim:
    def __init__(self, planner, w3, steps, probe=None):
        self.p = planner
        self.w3 = w3
        self.m = w3.m
        self.T = self.m.T
        self.rules = planner.rules
        self.steps = steps
        self.probe = probe  # {"door": id, "from": cuadro}: solo busca cuando se abre esa puerta
        self.frames, self.first = _step_frames(planner, steps)
        self.end = min(_end_frame(steps, self.first), len(self.frames))
        self.errors = []
        self.fix = None

    # --- Utilidades ---

    def node_at(self, f):
        _, _, x, feet = self.frames[f][:4]
        return _cell_of(self.T, x, feet)

    def insertion(self, g):
        """Donde se inserta un paso para que ocurra en el cuadro g: (pos, offset, nodo, cuadro) o None."""
        i, k = self.frames[g][0], self.frames[g][1]
        s = self.steps[i]
        if s["action"] == "move":
            n = len(self.p.samples(s))
            if s["kind"] == "walk" and k >= n / 2:
                node, pos, frame = s["to"], i + 1, self.first[i + 1]
            else:
                node, pos, frame = s["from"], i, self.first[i]
            off = 0
        elif s["action"] in WAIT_KINDS:
            node = s.get("at")
            pos, off, frame = i, k, g
            if k == 0:
                frame = self.first[i]
        else:
            node = s.get("at")
            pos, off, frame = i + 1, 0, self.first[i + 1]
        if node is None or is_pinched(node):
            return None
        return (pos, off, tuple(node), frame)

    def pulse_fix(self, frames, rect_at, target, reverse=False):
        """Pulso insertado desde una celda de pie que alcanza rect_at(F) en el cuadro F del pulso."""
        seen = set()
        m = self.m
        order = sorted(frames, reverse=reverse)
        for g in order:
            cand = self.insertion(g)
            if cand is None or cand in seen:
                continue
            seen.add(cand)
            pos, off, node, frame = cand
            if frame > max(frames) or frame >= len(self.frames) + 1:
                continue
            rect = rect_at(min(frame, len(self.frames) - 1))
            if rect is None:
                continue
            state = self.steps[self.frames[g][0]]["state"]
            if not m.has_pulse(state):
                continue
            # Un pulso que aturde a un enemigo no puede tocar de paso a un espejo cazador (lo congelaria en la
            # orientacion de ese momento y su haz no llegaria a su receptor; paso 13, sala del examen del 3-3).
            avoid = [h["rect"] for h in self.w3.hunters] or None
            shot = m.pulse_shot([rect], node, state, avoid=avoid)
            if shot is None:
                continue
            step = {"action": "pulse", "at": node, "shot": shot, "state": state, "target": dict(target)}
            return {"pos": pos, "offset": off, "step": step}
        return None

    # --- Isak ---

    def isak(self, f):
        i, k, x, feet, air, debug, action, dinv = self.frames[f]
        s = self.steps[i]
        pinched = _step_pinched(s)
        hh = self.w3.cmodel.hh if pinched else self.m.hh
        return {"i": i, "k": k, "x": x, "feet": feet, "air": air, "debug": debug, "action": action, "dash": dinv,
                "hh": hh, "s": s, "state": s["state"]}

    def rect(self, x, feet, hh):
        hw = self.m.hw
        return (x - hw, feet - hh, x + hw, feet)

    # --- Influencer ---

    def sees(self, inf, x, feet, hh, world):
        top = feet - hh
        lx, ly = inf["lens"]
        if feet < ly - inf["band"] or top > ly + inf["band"]:
            return False
        dx = x - lx
        if abs(dx) > inf["sight"] + EPS:
            return False
        if inf["facing"] != 0 and abs(dx) > EPS and (1 if dx > 0 else -1) != inf["facing"]:
            return False
        ay = min(max(ly, top), feet)
        dist = math.hypot(dx, ay - ly)
        n = max(1, int(dist / 4.0))
        T = self.T
        for j in range(1, n + 1):
            px, py = lx + dx * j / n, ly + (ay - ly) * j / n
            c, r = int(math.floor(px / T)), int(math.floor(py / T))
            if world.is_solid(c, r):
                return False
            if (c, r) in world.thin and r * T <= py <= r * T + world.thin[(c, r)]:
                return False
        return True

    def precise_jumps(self, f0, f1):
        out = []
        for j, s in enumerate(self.steps):
            if not (f0 <= self.first[j] < f1) or s["action"] != "move":
                continue
            e = s["edge"]
            if e["kind"] in ("walk", "pinch", "unpinch"):
                continue
            if max(e["h"], e["v"]) > BLIND_JUMP_MAX + EPS:
                out.append((j, s))
        return out

    # --- Ladron ---

    def thief_move(self, st, vx, dt, world):
        """Mueve al ladron por su fila; devuelve True si una pared lo para."""
        if abs(vx) < EPS:
            return False
        nx = st["x"] + vx * dt
        lead = nx + (24.0 if vx > 0 else -24.0)
        c, r = int(math.floor(lead / self.T)), int(math.floor((st["feet"] - 1.0) / self.T))
        if world.is_solid(c, r):
            return True
        st["x"] = nx
        return False

    def thief_clamp(self, st, vx):
        lx0, _, lx1, _ = st["leash"]
        if vx > 0.0 and st["x"] + 24.0 >= lx1:
            return 0.0
        if vx < 0.0 and st["x"] - 24.0 <= lx0:
            return 0.0
        return vx

    def thief_sees(self, st, cx, cy, radius):
        lx0, ly0, lx1, ly1 = st["leash"]
        if not (lx0 <= cx <= lx1 and ly0 <= cy <= ly1):
            return False
        return math.hypot(cx - st["x"], cy - (st["feet"] - 24.0)) <= radius + EPS

    def thief_rect(self, st):
        return (st["x"] - 24.0, st["feet"] - 48.0, st["x"] + 24.0, st["feet"])

    # --- Placas ---

    @staticmethod
    def presses(g, x, feet, air, width):
        if air:
            return False
        px0, py0, px1, py1 = g.press
        if feet < py0 or feet > py1:
            return False
        half = width * 0.5 * g.feet_fraction
        return x + half >= px0 and x - half <= px1

    # --- Simulacion ---

    def run(self):
        w3, m, T, rules = self.w3, self.m, self.T, self.rules
        frames = self.frames
        D = int(round(1.0 / DT_SIM))
        infl = [{"d": d, "state": "idle", "t": 0.0, "left": 0.0, "charge_f": None, "charges": 0, "flashes": 0,
                 "covered": 0, "stuns": 0, "blind": []} for d in w3.influencers]
        thieves = []
        for d in w3.thieves:
            p = d["p"]
            sx, sf = d["spawn"]
            lw, lh = float(p.get("leash_width_px", 768.0)), float(p.get("leash_height_px", 320.0))
            thieves.append({"d": d, "p": p, "x": sx, "feet": sf, "origin": sx, "dir": float(p.get("start_direction", 1)),
                            "state": "patrol", "t": 0.0, "left": 0.0, "notice_f": None, "notices": 0, "stuns": 0,
                            "thefts": 0, "leash": (sx - lw / 2, sf - 24.0 - lh / 2, sx + lw / 2, sf - 24.0 + lh / 2),
                            "hist": []})
        refls = [{"d": d, "state": "dormant", "side": 0, "fe": None, "pos": None, "left": 0.0, "stuns": 0,
                  "min_gap": None, "emerged": None, "hist": [], "violating": False, "contacts": 0} for d in w3.reflections]
        plates = {g.gid: {"g": g, "hold": 0.0, "holding": False, "by": set()} for g in w3.plates}
        doors = [{"d": d, "state": "closed", "t": 0.0, "open": 0.0, "solid": True, "crossed": None, "opened_at": None,
                  "blocked_err": False} for d in w3.doors]
        xs, fs, airs, hhs = [], [], [], []
        hw = m.hw
        for f in range(self.end):
            me = self.isak(f)
            x, feet, air, hh, state = me["x"], me["feet"], me["air"], me["hh"], me["state"]
            xs.append(x)
            fs.append(feet)
            airs.append(air)
            hhs.append(hh)
            dt = DT_SIM * (rules.debug_world_scale if me["debug"] else 1.0)
            world = m.world(state, False)
            irect = self.rect(x, feet, hh)
            cx, cy = x, feet - hh * 0.5
            pulse = me["action"] == "pulse" and me["k"] == 0
            facings = ()
            if pulse:
                shot = me["s"].get("shot")
                facings = (shot["facing"],) if shot else (1.0, -1.0)
            # --- Influencer ---
            for st in infl:
                d = st["d"]
                if pulse and _pulse_reach(rules, x, feet, facings, d["body"]):
                    st["state"], st["left"] = "stunned", d["stun"]
                    st["stuns"] += 1
                    continue
                st["t"] += dt
                if st["state"] == "idle":
                    if self.sees(d, x, feet, hh, world):
                        st["state"], st["t"], st["charge_f"] = "charge", 0.0, f
                        st["charges"] += 1
                elif st["state"] == "charge":
                    if st["t"] >= d["warn"] - 0.0001:
                        if self.sees(d, x, feet, hh, world):
                            st["flashes"] += 1
                            f1 = f + int(math.ceil(d["veil"] / DT_SIM))
                            jumps = self.precise_jumps(f, f1)
                            st["blind"].append({"t0": round(f * DT_SIM, 2), "t1": round(f1 * DT_SIM, 2),
                                                "jumps": len(jumps)})
                            if jumps and self.probe is None:
                                fix = self.pulse_fix(list(range(st["charge_f"], f)), lambda F, d=d: d["body"],
                                                     {"type": "influencer_bot", "id": d["id"]})
                                j, sj = jumps[0]
                                fail = ("Influencer %s: su flash ciega a Isak %.1f s desde los %.1f s y el camino exige "
                                        "un salto preciso durante la ceguera (de (fila %d, columna %d) a (fila %d, "
                                        "columna %d), %.0f %%); ni lo tapa el terreno ni el pulso lo aturde antes "
                                        "(docs/propuesta-mundo-3.md §3.6)" % (
                                            d["id"], d["veil"], f * DT_SIM, sj["from"][1], sj["from"][0], sj["to"][1],
                                            sj["to"][0], 100 * max(sj["edge"]["h"], sj["edge"]["v"])),
                                        sj["from"], d["id"])
                                if fix is not None:
                                    fix.update({"key": ("influencer", d["id"], st["charges"]), "fail": fail})
                                    self.fix = fix
                                    return self.result(infl, thieves, refls, doors)
                                self.errors.append(fail)
                        else:
                            st["covered"] += 1
                        st["state"], st["t"] = "cooldown", 0.0
                elif st["state"] == "cooldown":
                    if st["t"] >= d["cooldown"]:
                        st["state"], st["t"] = "idle", 0.0
                elif st["state"] == "stunned":
                    st["left"] -= dt
                    if st["left"] <= 0.0:
                        st["state"], st["t"] = "idle", 0.0
            # --- Ladron ---
            likes = World3.likes_of(state)
            for st in thieves:
                p = st["p"]
                st["hist"].append(self.thief_rect(st))
                if pulse and _pulse_reach(rules, x, feet, facings, self.thief_rect(st)):
                    st["state"], st["t"], st["left"] = "stunned", 0.0, float(p.get("stun_s", 3.0))
                    st["stuns"] += 1
                    continue
                st["t"] += dt
                s0 = st["state"]
                if s0 == "patrol":
                    vx = st["dir"] * float(p.get("patrol_speed_px_s", 80.0))
                    wall = self.thief_move(st, vx, dt, world)
                    turn = wall
                    probe_x = st["x"] + st["dir"] * (24.0 + 2.0)
                    if not world.is_support(int(math.floor(probe_x / T)), int(math.floor((st["feet"] + 1.0) / T))):
                        turn = True
                    half = float(p.get("patrol_range_px", 256.0)) * 0.5
                    if half > 0.0:
                        if st["dir"] > 0 and st["x"] >= st["origin"] + half:
                            turn = True
                        elif st["dir"] < 0 and st["x"] <= st["origin"] - half:
                            turn = True
                    if turn:
                        st["dir"] = -st["dir"]
                    if self.thief_sees(st, cx, cy, float(p.get("detect_radius_px", 256.0))):
                        st["state"], st["t"] = ("notice" if likes > 0 else "search"), 0.0
                        if likes > 0:
                            st["notice_f"] = f
                            st["notices"] += 1
                elif s0 == "notice":
                    if st["t"] >= float(p.get("anticipation_frames", 9)) / float(p.get("anim_fps", 12.0)):
                        st["state"], st["t"] = "chase", 0.0
                elif s0 == "chase":
                    if not self.thief_sees(st, cx, cy, float(p.get("give_up_radius_px", 448.0))):
                        self.thief_back(st)
                    else:
                        dx = x - st["x"]
                        vx = (1.0 if dx > 0 else -1.0) * float(p.get("chase_speed_px_s", 140.0)) if abs(dx) > 2.0 else 0.0
                        self.thief_move(st, self.thief_clamp(st, vx), dt, world)
                        if not me["dash"] and rects_overlap(irect, self.thief_rect(st)):
                            if likes > 0:
                                fail = ("Ladron de likes %s: alcanza a Isak en (fila %d, columna %d) a los %.1f s y le "
                                        "roba likes; el camino tiene que evitarlo o aturdirlo antes con el pulso (0 "
                                        "robos; docs/propuesta-mundo-3.md §7.1)" % (
                                            st["d"]["id"], self.node_at(f)[1], self.node_at(f)[0], f * DT_SIM),
                                        self.node_at(f), st["d"]["id"])
                                if self.probe is None:
                                    start = st["notice_f"] if st["notice_f"] is not None else max(0, f - D)
                                    hist = st["hist"]
                                    fix = self.pulse_fix(list(range(start, f + 1)),
                                                         lambda F, hist=hist: hist[F] if F < len(hist) else None,
                                                         {"type": "like_thief", "id": st["d"]["id"]})
                                    if fix is not None:
                                        fix.update({"key": ("thief", st["d"]["id"], st["thefts"]), "fail": fail})
                                        self.fix = fix
                                        return self.result(infl, thieves, refls, doors)
                                    self.errors.append(fail)
                                st["thefts"] += 1
                                st["state"], st["t"] = "flee", 0.0
                            else:
                                st["state"], st["t"] = "search", 0.0
                elif s0 == "flee":
                    away = -1.0 if x > st["x"] else 1.0
                    st["dir"] = away
                    self.thief_move(st, self.thief_clamp(st, away * float(p.get("flee_speed_px_s", 200.0))), dt, world)
                    if st["t"] >= float(p.get("flee_s", 2.0)):
                        self.thief_back(st)
                elif s0 == "search":
                    if st["t"] >= float(p.get("search_s", 1.0)):
                        self.thief_back(st)
                elif s0 == "stunned":
                    st["left"] -= dt
                    if st["left"] <= 0.0:
                        self.thief_back(st)
            # --- Reflejo falso ---
            for st in refls:
                d = st["d"]
                z = d["zone"]
                inside = z is None or (z[0] <= cx < z[2] and z[1] <= cy < z[3])
                if not inside:
                    if st["state"] != "dormant":
                        st["state"], st["pos"] = "dormant", None
                    st["side"] = 0
                    st["hist"].append(None)
                    st["violating"] = False
                    continue
                if pulse and st["pos"] is not None:
                    px, pf, _, ph = st["pos"]
                    if _pulse_reach(rules, x, feet, facings, self.rect(px, pf, ph)):
                        st["state"], st["left"] = "stunned", d["stun"]
                        st["stuns"] += 1
                if st["state"] == "dormant":
                    side = 1 if x > d["axis"] else (-1 if x < d["axis"] else 0)
                    if st["side"] and side and side != st["side"]:
                        st["state"], st["fe"] = "emerging", f
                        st["emerged"] = [int(round(feet / T)) - 1, int(x // T)]
                        st["pos"] = (x, feet, air, hh)
                    if side:
                        st["side"] = side
                elif st["state"] == "emerging":
                    fe = st["fe"]
                    st["pos"] = (xs[fe], fs[fe], airs[fe], hhs[fe])
                    if (f - fe) * DT_SIM >= max(d["emerge"], d["delay"]) - 0.0001:
                        st["state"] = "active"
                elif st["state"] == "stunned":
                    st["left"] -= dt
                    if st["left"] <= 0.0:
                        st["state"] = "active"
                if st["state"] == "active":
                    j = max(f - int(round(d["delay"] / DT_SIM)), st["fe"])
                    st["pos"] = (xs[j], fs[j], airs[j], hhs[j])
                st["hist"].append(self.rect(st["pos"][0], st["pos"][1], st["pos"][3]) if st["pos"] else None)
                if st["state"] != "active":
                    st["violating"] = False
                    continue
                gap = math.hypot(x - st["pos"][0], feet - st["pos"][1])
                st["min_gap"] = gap if st["min_gap"] is None else min(st["min_gap"], gap)
                if gap < T * REFLECTION_GAP_TILES - EPS:
                    if st["violating"]:
                        continue
                    st["violating"] = True
                    st["contacts"] += 1
                    node = self.node_at(f)
                    fail = ("Reflejo falso %s: alcanza a Isak en (fila %d, columna %d) a los %.1f s (Isak a %.0f px de "
                            "donde estaba %.0f s antes; minimo %g tile) y el pulso no lo aturde a tiempo desde una celda "
                            "de pie (docs/propuesta-mundo-3.md §7.1)" % (
                                d["id"], node[1], node[0], f * DT_SIM, gap, d["delay"], REFLECTION_GAP_TILES),
                            node, d["id"])
                    if self.probe is None:
                        hist = st["hist"]
                        lo = max(st["fe"], f - D)
                        fix = self.pulse_fix(list(range(lo, f + 1)),
                                             lambda F, hist=hist: hist[F] if F < len(hist) else None,
                                             {"type": "false_reflection", "id": d["id"]}, reverse=True)
                        if fix is not None:
                            fix.update({"key": ("reflection", d["id"], st["stuns"]), "fail": fail})
                            self.fix = fix
                            return self.result(infl, thieves, refls, doors)
                        self.errors.append(fail)
                else:
                    st["violating"] = False
            # --- Placas y puertas ---
            for ps in plates.values():
                g = ps["g"]
                by = set()
                if self.presses(g, x, feet, air, m.rules.hitbox_w):
                    by.add("Isak")
                for st in refls:
                    if st["pos"] is not None and st["state"] != "dormant":
                        px, pf, pa, _ = st["pos"]
                        if self.presses(g, px, pf, pa, m.rules.hitbox_w):
                            by.add("reflejo %s" % st["d"]["id"])
                ps["by"] |= by
                if by:
                    ps["hold"] = g.hold_s
                else:
                    ps["hold"] = max(ps["hold"] - dt, 0.0)
                ps["holding"] = bool(by) or ps["hold"] > 0.0
            for ds in doors:
                d = ds["d"]
                held = any(plates[gid]["holding"] for gid in d["plates"])
                ds["t"] += dt
                if ds["state"] == "closed" and held:
                    ds["state"], ds["t"] = "opening", 0.0
                if ds["state"] == "opening":
                    ds["open"] = min(ds["open"] + dt / max(d["open_s"], 0.001), 1.0)
                    if ds["open"] >= 1.0:
                        ds["state"], ds["t"], ds["solid"] = "open", 0.0, False
                        if ds["opened_at"] is None:
                            ds["opened_at"] = round(f * DT_SIM, 2)
                elif ds["state"] == "open":
                    if not held:
                        ds["state"], ds["t"] = "warn", 0.0
                elif ds["state"] == "warn":
                    blocked = rects_overlap(irect, d["rect"]) or any(
                        st["pos"] is not None and st["state"] != "dormant"
                        and rects_overlap(self.rect(st["pos"][0], st["pos"][1], st["pos"][3]), d["rect"])
                        for st in refls)
                    if held:
                        ds["state"], ds["t"] = "open", 0.0
                    elif ds["t"] >= d["warn"] - 0.0001 and not blocked:
                        ds["state"], ds["t"], ds["solid"] = "closing", 0.0, True
                elif ds["state"] == "closing":
                    if held:
                        ds["state"], ds["t"] = "opening", 0.0
                    else:
                        ds["open"] = max(ds["open"] - dt / max(d["open_s"], 0.001), 0.0)
                        if ds["open"] <= 0.0:
                            ds["state"], ds["t"] = "closed", 0.0
                if self.probe is not None:
                    if d["id"] == self.probe["door"] and f >= self.probe["from"] and not ds["solid"]:
                        return {"probe_open": f}
                    continue
                if rects_overlap(irect, d["rect"]):
                    if ds["solid"]:
                        if ds["blocked_err"]:
                            continue
                        fix = self.door_fix(ds, f)
                        if fix is not None and "step" in fix:
                            self.fix = fix
                            return self.result(infl, thieves, refls, doors)
                        ds["blocked_err"] = True
                        self.errors.append(fix["fail"])
                    elif ds["crossed"] is None:
                        ds["crossed"] = round(f * DT_SIM, 2)
        if self.probe is not None:
            return {"probe_open": None}
        return self.result(infl, thieves, refls, doors, plates)

    def thief_back(self, st):
        if abs(st["origin"] - st["x"]) > 1.0:
            st["dir"] = 1.0 if st["origin"] > st["x"] else -1.0
        st["state"], st["t"] = "patrol", 0.0

    def door_fix(self, ds, f):
        d = ds["d"]
        i = self.frames[f][0]
        s = self.steps[i]
        node = s["from"] if s["action"] == "move" else s.get("at")
        cell = self.node_at(f)
        plates = ", ".join(g.obj_id for g in self.w3.plates if g.gid in d["plates"]) or "-"
        fail = ("puerta de marco %s: sigue cerrada cuando el camino llega a (fila %d, columna %d) a los %.1f s y ni "
                "esperando delante la sostiene a tiempo su placa (%s) con Isak o el Reflejo falso (abierta mientras la "
                "pisan y %.1f s mas; docs/propuesta-mundo-3.md §3.6)" % (
                    d["id"], cell[1], cell[0], f * DT_SIM, plates,
                    next((g.hold_s for g in self.w3.plates if g.gid in d["plates"]), 0.3)), cell, d["id"])
        if node is None or self.steps[i]["action"] in WAIT_KINDS:
            return {"fail": fail}
        node = tuple(node)
        wait = {"action": "wait_reflection", "at": node, "seconds": MAX_WAIT_S, "state": s["state"]}
        probe = _EnemySim(self.p, self.w3, self.steps[:i] + [wait], probe={"door": d["id"], "from": self.first[i]})
        res = probe.run()
        if res.get("probe_open") is None:
            return {"fail": fail}
        secs = (res["probe_open"] - self.first[i]) * DT_SIM + WAIT_MARGIN_S
        step = {"action": "wait_reflection", "at": node, "seconds": round(secs, 4), "state": s["state"],
                "reason": "esperar a que se abra la puerta de marco %s (su placa la pisa el Reflejo falso)" % d["id"],
                "target": {"type": "frame_door", "id": d["id"]}}
        return {"pos": i, "offset": 0, "step": step, "key": ("door", d["id"], i), "fail": fail}

    def result(self, infl, thieves, refls, doors, plates=None):
        info = []
        for st in infl:
            info.append({"kind": "influencer_bot", "id": st["d"]["id"], "charges": st["charges"],
                         "flashes": st["flashes"], "covered": st["covered"], "stuns": st["stuns"],
                         "blind": st["blind"]})
        for st in thieves:
            info.append({"kind": "like_thief", "id": st["d"]["id"], "notices": st["notices"], "stuns": st["stuns"],
                         "thefts": st["thefts"]})
        for st in refls:
            info.append({"kind": "false_reflection", "id": st["d"]["id"], "emerged": st["emerged"],
                         "min_gap_tiles": None if st["min_gap"] is None else round(st["min_gap"] / self.T, 2),
                         "stuns": st["stuns"], "contacts": st["contacts"]})
        waits = {}
        for s in self.steps:
            if s["action"] == "wait_reflection" and (s.get("target") or {}).get("type") == "frame_door":
                waits[s["target"]["id"]] = waits.get(s["target"]["id"], 0.0) + s.get("seconds", 0.0)
        for ds in doors:
            d = ds["d"]
            by = set()
            if plates:
                for gid in d["plates"]:
                    by |= plates[gid]["by"]
            info.append({"kind": "frame_door", "id": d["id"],
                         "plates": [g.obj_id for g in self.w3.plates if g.gid in d["plates"]],
                         "pressed_by": sorted(by), "opened_at_s": ds["opened_at"], "crossed_at_s": ds["crossed"],
                         "wait_s": round(waits.get(d["id"], 0.0), 2)})
        return {"fix": self.fix, "errors": self.errors, "info": info}


# --- Texto ---

def format_lines(result):
    w3 = result.get("world3")
    if not w3:
        return []
    out = []
    pinch = w3.get("pinch")
    if pinch:
        if not pinch["sections"]:
            out.append("  Pellizcar: caja %.0f x %.0f, %.0f px/s, salto %.0f px; el camino no va comprimido" % (
                pinch["box_px"][0], pinch["box_px"][1], pinch["walk_speed_px_s"], pinch["jump_height_px"]))
        for s in pinch["sections"]:
            out.append("  Pellizcar: %s (cols. %d-%d): %d marco(s), %.1f tiles comprimido como maximo" % (
                "tramo %s" % s["name"] if s["name"] else "sin tramo", s["cols"][0], s["cols"][1], len(s["frames"]),
                s["max_tiles"]))
        for r in pinch["runs"]:
            out.append("    comprimido de (fila %d, columna %d) a (fila %d, columna %d): %.1f tiles%s%s" % (
                r["from"][0], r["from"][1], r["to"][0], r["to"][1], r["tiles"],
                "" if r["recover_tiles"] is None else ", recupera el tamano a %d tile(s) de la salida" % r["recover_tiles"],
                ", marcos %s" % ", ".join(r["frames"]) if r["frames"] else ""))
    likes = w3.get("likes")
    if likes:
        th = ", ".join("%d%s" % (p["threshold"], " (inversa)" if p["invert"] else "") for p in likes["platforms"])
        out.append("  likes: umbrales %s; el camino recoge %d corazon(es), usa %d publicacion(es) y %d reset(s) y acaba "
                   "con %d" % (th or "-", likes["hearts"], likes["publications"], likes["resets"], likes["final"]))
        for u in likes["used"]:
            extra = ""
            if not u["invert"]:
                extra = "; anti-atasco: publicacion %s alcanzable sin likes desde %s" % (u["publication"], u["sync"]) \
                    if u.get("publication") else "; anti-atasco: SIN publicacion desde %s" % u.get("sync", "P")
            out.append("    plataforma %s (likes %d%s) pisada en (fila %d, columna %d) con %d like(s)%s" % (
                u["id"], u["threshold"], ", inversa" if u["invert"] else "", u["at"][0], u["at"][1], u["likes"], extra))
    for f in w3.get("filters", []):
        what = []
        if f["spikes"]:
            what.append("%d pincho(s)" % f["spikes"])
        if f["fake_floor"]:
            what.append("%d suelo(s) falso(s)" % f["fake_floor"])
        hidden = " y ".join(what) or "nada"
        if f["moving"]:
            head = "  filtro movil %s (%d sitios, %g s): esconde %s; %s" % (
                f["id"], f["positions"], f["cycle_s"], hidden,
                "la parte que tapan todos sus sitios pide el Debug" if f["needs_debug"] else
                "lo que tapa queda al descubierto en su ciclo: se cruza sin el Debug memorizandolo (simplificacion)")
        else:
            head = "  filtro %s: esconde %s; %s" % (f["id"], hidden, "junto a lo que esconde solo se pasa con el Debug encendido"
                                                    if f["needs_debug"] else "no pide el Debug")
        if f["crossed_with_debug"]:
            head += "; el camino lo cruza con el Debug%s" % (
                " (cargador %s a la vista, columna %d)" % (f["charger"]["id"], f["charger"]["col"]) if f["charger"] else "")
        out.append(head)
    for it in w3.get("mirrors", []):
        if it.get("from"):
            out.append("  espejos: %s %s: laser desde (fila %d, columna %d), %d rebote(s)%s, %.0f de %.0f px" % (
                it["what"], it["id"], it["from"][0], it["from"][1], it["bounces"],
                " (%s)" % ", ".join(it["mirrors"]) if it["mirrors"] else "", it["dist_px"], it["range_px"]))
        else:
            out.append("  espejos: %s %s: el laser no lo alcanza%s" % (
                it["what"], it["id"], " (haria falta %d rebotes)" % it["needs_bounces"] if it.get("needs_bounces") else ""))
    for it in w3.get("mirror_only", []):
        out.append("  plataforma del reflejo %s: %s%s" % (
            it["id"], "se ve en %s (reflejada en las columnas %d-%d)" % (it["wall"], it["reflected_cols"][0],
                                                                       it["reflected_cols"][1])
            if it["seen"] else "NO se ve en ninguna pared de espejo",
            "; el camino la pisa saltando desde (fila %d, columna %d)%s" % (
                it["from"][0], it["from"][1], ", con la pared a la vista" if it.get("wall_in_view") else "")
            if it.get("from") else ""))
    for it in w3.get("hunters", []):
        out.append("  espejo cazador %s: pulso desde (fila %d, columna %d) mirando al %s -> haz a %s%s" % (
            it["id"], it["from"][0], it["from"][1], it["facing"], it["target"],
            " (espera %.2f s a que gire)" % it["wait_s"] if it.get("wait_s") else " (sin esperar)"))
    for it in w3.get("enemies", []):
        kind = it["kind"]
        if kind == "influencer_bot":
            blind = [b for b in it["blind"]]
            out.append("  Influencer %s: lo ve %d vez(es); %d flash(es) que ciegan%s, %d tapado(s) o fuera de su vista, "
                       "%d aturdido(s) con el pulso" % (
                           it["id"], it["charges"], it["flashes"],
                           " (%s)" % ", ".join("%.1f-%.1f s%s" % (b["t0"], b["t1"], ", %d salto(s) preciso(s)" % b["jumps"]
                                                                  if b["jumps"] else ", sin saltos precisos")
                                               for b in blind) if blind else "",
                           it["covered"], it["stuns"]))
        elif kind == "like_thief":
            out.append("  Ladron de likes %s: lo persigue %d vez(es), %d aturdido(s) con el pulso, %d robo(s)" % (
                it["id"], it["notices"], it["stuns"], it["thefts"]))
        elif kind == "false_reflection":
            if it["emerged"] is None:
                out.append("  Reflejo falso %s: no sale (el camino no cruza su pared de espejo en su sala)" % it["id"])
            else:
                out.append("  Reflejo falso %s: sale en (fila %d, columna %d); Isak a %s tile(s) como minimo de donde "
                           "estaba 1 s antes; %d aturdido(s) con el pulso%s" % (
                               it["id"], it["emerged"][0], it["emerged"][1],
                               "-" if it["min_gap_tiles"] is None else "%.2f" % it["min_gap_tiles"], it["stuns"],
                               ", %d alcance(s)" % it["contacts"] if it["contacts"] else ""))
        elif kind == "frame_door":
            out.append("  puerta de marco %s (placa %s): la pisan %s; abierta a los %s, el camino la cruza a los %s%s" % (
                it["id"], ", ".join(it["plates"]) or "-", " y ".join(it["pressed_by"]) or "nadie",
                "-" if it["opened_at_s"] is None else "%.2f s" % it["opened_at_s"],
                "-" if it["crossed_at_s"] is None else "%.2f s" % it["crossed_at_s"],
                " (espera %.2f s al reflejo)" % it["wait_s"] if it.get("wait_s") else ""))
    return out
