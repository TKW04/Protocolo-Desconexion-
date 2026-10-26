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
    sitio. Abilities_available.compress lo admite el modelo, pero el esquema aun no (KNOWN_ABILITIES): por ahora
    Pellizcar llega por la herramienta. Plataformas de likes
    (like_platform): tabla de card_height_px arriba de su celda, encendida con likes >= threshold (invert:
    likes < threshold); one_way, solo apoyo. Las perdidas por golpe y el Ladron no se modelan aqui (el camino no
    recibe golpes; el Ladron es del paso 8b). Regla anti-atasco: cada plataforma de likes que pisa el camino
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
    error. El espejo cazador congelado es del paso 8b.
  - Plataformas del reflejo (mirror_only): solidas para el grafo (tabla de height_px arriba de su celda); el
    validador comprueba que cada una se ve en su pared de espejo mas cercana (reflejada dentro del cristal) y
    que, si el camino la pisa, la pared esta a la vista (VIEW_TILES / 2 columnas) desde donde salta.

Ganchos del paso 8b (sin modelar todavia): Influencer y Ladron (amenazas evitables: la salida los nombra),
espejo cazador, Reflejo falso, placas «Posa aqui» y requires_abilities.
"""
import copy
import json
import math
import os

EPS = 1e-6
INF = float("inf")
SIM_DT = 1.0 / 60.0
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

WORLD3_TYPES = ("heart_pickup", "like_source", "like_platform", "like_reset", "crop_tool", "filter_zone",
                "small_frame", "mirror", "mirror_wall", "mirror_only")
ENEMIES_8B = ("influencer_bot", "like_thief", "false_reflection")
OBJECTS_8B = ("hunter_mirror", "pose_plate", "frame_door")
LIKE_KINDS = ("heart", "like_source", "like_reset")


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
    return any(isinstance(o, dict) and o.get("type") in WORLD3_TYPES for o in level.get("objects", []))


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
        self.pending_8b = [("%s %s" % (e.get("type"), e.get("id", ""))).strip() for e in level.get("enemies", [])
                           if e.get("type") in ENEMIES_8B]
        self.pending_8b += ["%s %s" % (o["type"], (o.get("params") or {}).get("id", "")) for o in level.get("objects", [])
                            if o.get("type") in OBJECTS_8B]

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
        return tuple(("likes", p["id"]) for p in self.like_platforms
                     if not (p["span"][1] < lo or p["span"][0] > hi) and self.platform_on(p, likes))

    def apply(self, state, gate):
        """Estado tras una accion de likes (corazon, publicacion o reset)."""
        likes = self.likes_of(state)
        if gate.kind == "heart":
            return self.with_likes(state | {gate.gid}, min(self.likes_max, likes + gate.value))
        if gate.kind == "like_source":
            return self.with_likes(state, min(self.likes_max, likes + gate.gain))
        return self.with_likes(state, 0)

    def useful(self, gate, state):
        likes = self.likes_of(state)
        if gate.kind == "heart":
            return gate.gid not in state
        if gate.kind == "like_source":
            return likes < min(self.normal_max, self.likes_max)
        return likes > 0 and any(not self.platform_on(p, likes) for p in self.inverse)

    def can_act(self, gate, node, state):
        m = self.m
        if gate.kind == "heart":
            c, r = node
            cells = {(c, r)} if is_pinched(node) else {(c, r), (c, r - 1)}
            return bool(cells & set(gate.cells))
        if is_pinched(node) or not m.has_pulse(state):
            return False
        return m.pulse_hits(gate.openers, node, state)

    def near(self, gate, node):
        T = self.m.T
        if gate.kind == "heart":
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
        return len(self.hearts) + (self.likes_max // 5 + 1) * (len(self.pubs) + len(self.resets)) + 2

    def softlock_nexts(self, node, state):
        """Publicaciones y reset en el grafo de los soft-locks (sin los corazones: conservador)."""
        out = []
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

    def trace(self, w, x, y, hx, hy, rect, max_bounces=None):
        """Trazado del laser con rebotes hasta `rect`: {"dist", "bounces", "mirrors", "points"} o None."""
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
        while x <= (c + 1) * T + EPS:
            if not w.collides(x, feet):
                for facing in (1.0, -1.0):
                    px = x + rules.phone_x * facing
                    hit = self.trace(w, px, py, facing, 0.0, rect, max_bounces)
                    if hit is not None:
                        return {"x": x, "facing": facing, "dist": hit["dist"], "bounces": hit["bounces"],
                                "mirrors": list(hit["mirrors"]), "points": hit["points"]}
            x += SAMPLE_PX
        return None

    # --- Comprobaciones tras el camino principal ---

    def check(self, v, start, goal_cells):
        """Pellizcar, likes, filtros y espejos sobre el camino principal (Validator.main)."""
        out = {}
        main = v.main
        if main["ok"]:
            nodes, states = self._path_nodes(v, main)
            if self.compress_possible:
                out["pinch"] = self._check_pinch(v, nodes, states)
            if self.like_platforms or self.like_gates:
                out["likes"] = self._check_likes(v, main, nodes, states, start)
            if self.filters:
                out["filters"] = self._check_filters(v, main)
            if self.mirror_only:
                out["mirror_only"] = self._check_mirror_only(v, main)
        if self.mirrors:
            out["mirrors"] = self._check_mirrors(v, main)
        if self.pending_8b:
            out["pending_8b"] = list(self.pending_8b)
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
    if w3.get("pending_8b"):
        out.append("  sin modelar todavia (paso 8b, amenazas evitables): %s" % ", ".join(w3["pending_8b"]))
    return out
