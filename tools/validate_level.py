#!/usr/bin/env python3
"""Validador de ALCANZABILIDAD de un nivel (skill level-builder, paso 15).

Lee data/isak_physics.json (los mismos valores que usa el juego), las medidas de
Isak (hitbox_size y pulse_effect_origin de scripts/player/isak.gd,
pulse_radius_px de data/isak_abilities.json), el catalogo de objetos del mundo,
los datos de los enemigos y de los peligros, y comprueba con un modelo de
movimiento por celdas:

  1. Hay un camino de P a G sin Debug.
  2. Cada C es alcanzable desde la anterior (o desde P).
  3. Ningun salto del camino exige mas del limite (--limit, 0.85) del alcance
     maximo de Isak caminando (horizontal y vertical por separado; corriendo
     solo si el nivel declara "allow_run": true o se pasa --run). Informa del
     margen minimo.
  4. Los secretos S con "needs_debug": true solo se alcanzan pasando por
     plataformas ocultas 'h' (con Debug) y la meta se alcanza sin Debug. Los
     secretos que son un objeto (glitch_wall) quedan fuera (V7).
     4b. La pared con glitch es solida sin Debug y libre con Debug (se disuelve,
     paso 14 de docs/propuesta-asistentes-y-vidas.md). Vida extra
     (extra_life_pickup): se alcanza; tapada por una pared con glitch, solo con
     Debug («alcanzable con Debug»); nunca es obligatoria. Los secretos
     que son otro objeto (p. ej. power_bank_pickup) y las S sin needs_debug
     (secretos de puntos) tienen que alcanzarse sin Debug.
     Mejoras (data/upgrades.json): el modelo usa los valores BASE salvo las
     mejoras de --upgrades (hoy solo afecta isak_abilities.pulse_radius_px). Un
     secreto con "requires_upgrade": <id> NO debe alcanzarse sin esa mejora y SI
     con ella (se comprueban las dos cosas en cada pasada); la meta se valida
     siempre sin ella.
  5. Sin pinchos en P (ni donde cae Isak al aparecer) ni en el primer tile de
     una C (la propia celda, la de debajo y las de los lados).
  6. Objetos que hacen de puerta: el puente no existe hasta que el pulso
     alcanza su receptor (extendido es una tabla solida de
     bridge.collision_height_px en lo alto de su celda: se pasa por debajo); el
     pop-up es solido hasta que el pulso alcanza su boton; la Burbuja bloquea el
     paso hasta aturdirla con el pulso o matarla con el laser (si el techo deja
     saltarla, solo avisa de que el pulso no es obligatorio, salvo si el enemigo
     lleva "open": true, en abierto a proposito; entonces solo avisa si en
     realidad bloquea: desde el 2026-10-15 pisarla no la mata y ya no se busca
     una repisa para reventarla; matarla con el laser es opcional). El pulso
     sale del celular de Isak de pie (pulse_effect_origin) con radio
     pulse_radius_px, desde una celda ya alcanzable. Avisa si una puerta no es
     obligatoria, salvo las de un secreto (campo `gates` de la entrada en
     `secrets`), que son opcionales a proposito y no entran en el camino
     principal.
  6b. Habilidades (objeto ability_pickup, p. ej. el laser): se recogen al
     tocar su celda y desde entonces la habilidad esta disponible (estado del
     grafo, como una puerta). El laser (laser_range_px de
     data/isak_abilities.json) sale horizontal del celular hacia donde mira
     Isak, choca con el terreno y mata Burbujas (abre su puerta). Comprueba que
     el objeto se alcanza, si es obligatorio (sin pisar su celda no se llega a
     la meta; si no lo es avisa, salvo si es de un secreto) y que la meta se
     alcanza SIN usar el laser. Informa de desde donde alcanza el laser a cada
     Burbuja y avisa si una Burbuja en abierto posterior al laser no se puede
     alcanzar con el.
  6c. Terminal de salida (exit_terminal, 2026-10-15): tocar G no basta, hay que
     activarla con el pulso. El nivel debe tener el pulso
     (abilities_available.pulse, o un encuentro con Eco que lo da) y el pulso
     (radio base, sin mejoras ni laser) debe alcanzar su hit_rect_px desde
     alguna celda de pie alcanzable en el camino principal hacia G.
  6d. Encuentro con Eco (eco_encounter, 2026-10-16, paso 6 de
     docs/propuesta-asistentes-y-vidas.md): con abilities_available.pulse
     false el pulso NO existe al empezar; lo da el encuentro (una zona de toda
     la altura: se activa al tocar cualquiera de sus celdas), que es un estado
     del grafo como el laser de un ability_pickup. El encuentro tiene que ser
     obligatorio y ninguna puerta que exija el pulso (puente con receptor,
     pop-up, Burbuja que no se puede saltar, terminal de salida) puede estar
     antes de el.
  7. Sin soft-locks: desde cualquier sitio alcanzable (en cada estado de las
     puertas, abriendolas tambien desde dentro de un foso) se puede llegar a la
     meta (p. ej. caer al foso del puente). Grafo producto (nodo, puertas
     abiertas) restringido a los pares que se alcanzan desde P.

Modelo de movimiento:
  - Isak es una caja de hitbox_size (32x80) con los pies en el origen. Esta de
    pie en una celda vacia (el cuerpo cabe y no toca pinchos) con apoyo debajo:
    '#', '-' (una via, se atraviesa desde abajo), puente activado, 'h' con Debug.
  - Andar a la celda vecina; saltos y caidas son trayectorias simuladas
    (dt = 1/60) con velocidad horizontal constante (walk_speed, o run_speed) que
    se detiene en el borde de la celda objetivo, gravedad `gravity` al subir y
    x fall_gravity_multiplier al bajar, choque con techos (corta la subida) y
    paredes (se queda pegado y sigue empujando). Altura real del salto =
    altura nominal (jump_velocity^2 / 2g) x --jump-efficiency (0.92 por defecto:
    a 60 Hz el salto real llega al 92-96 % de los 192 px nominales; se toma el
    valor bajo). El coyote time NO se usa (margen extra).
  - Exigencia de un salto: vertical = subida / altura real; horizontal =
    distancia en el aire entre el borde de la celda de salida y el borde de la
    de llegada / alcance a esa altura (velocidad x tiempo de vuelo). Una caida
    solo exige la parte horizontal.
  - Fosos con fondo: caer es un movimiento mas; desde el fondo hay que poder
    salir (si no, es un soft-lock). Caer por debajo del grid no lleva a ningun
    sitio (V3: reaparece en el ultimo suelo, no cuenta como camino).

Uso:
  python3 tools/validate_level.py data/levels/1-1.json [--json] [--limit 0.85]
          [--jump-efficiency 0.92] [--run] [--physics data/isak_physics.json]
          [--upgrades wide_pulse[,otra]]
Sale con 0 si no hay errores (los avisos no fallan), 1 si los hay y 2 si no se
pueden leer los datos. Los mensajes dicen fila y columna (y objeto).
"""

import argparse
import heapq
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level_schema  # noqa: E402

DEFAULT_LIMIT = 0.85
DEFAULT_JUMP_EFFICIENCY = 0.92
SIM_DT = 1.0 / 60.0
SIM_MAX_S = 4.0
EPS = 1e-6
# Paso del muestreo de posiciones de pie dentro de una celda al comprobar el pulso.
PULSE_SAMPLE_PX = 4.0
INF = float("inf")


# --- Datos ---

def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def load_upgrades(root=ROOT):
    """Catalogo de mejoras (data/upgrades.json) como dict id -> entrada, en orden."""
    data = load_json(os.path.join(root, "data", "upgrades.json"))
    return {str(u["id"]): u for u in data.get("upgrades", [])}


def effective_value(catalog, purchased, target, base):
    """Igual que GameState.effective_value: si varias mejoras compradas tocan el mismo
    target gana la ultima del catalogo."""
    value = base
    for uid, entry in catalog.items():
        if uid in purchased and entry.get("target") == target:
            value = float(entry["value"])
    return value


def _export_vector2(source, name):
    match = re.search(r"var %s\s*:\s*Vector2\s*=\s*Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)" % name, source)
    if not match:
        raise ValueError("no se encuentra '%s' en scripts/player/isak.gd" % name)
    return float(match.group(1)), float(match.group(2))


class Rules:
    """Valores de juego que usa el modelo (todos leidos de los datos del proyecto)."""

    def __init__(self, root=ROOT, physics_path=None, jump_efficiency=DEFAULT_JUMP_EFFICIENCY,
                 limit=DEFAULT_LIMIT, allow_run=False, upgrades=()):
        physics = load_json(physics_path or os.path.join(root, "data", "isak_physics.json"))
        abilities = load_json(os.path.join(root, "data", "isak_abilities.json"))
        with open(os.path.join(root, "scripts", "player", "isak.gd"), encoding="utf-8") as handle:
            isak_source = handle.read()
        self.root = root
        self.gravity = float(physics["gravity"])
        self.fall_mult = float(physics["fall_gravity_multiplier"])
        self.walk_speed = float(physics["walk_speed"])
        self.run_speed = float(physics["run_speed"])
        self.tile = float(physics["tile_size"])
        self.coyote_s = float(physics["coyote_time_s"])
        jump_velocity = float(physics["jump_velocity"])
        self.nominal_height = jump_velocity * jump_velocity / (2.0 * self.gravity)
        self.jump_efficiency = float(jump_efficiency)
        self.jump_height = self.nominal_height * self.jump_efficiency
        self.jump_v0 = math.sqrt(2.0 * self.gravity * self.jump_height)
        self.limit = float(limit)
        self.allow_run = bool(allow_run)
        self.hitbox_w, self.hitbox_h = _export_vector2(isak_source, "hitbox_size")
        self.phone_x, self.phone_y = _export_vector2(isak_source, "pulse_effect_origin")
        self.base_pulse_radius = float(abilities["pulse_radius_px"])
        self.laser_range = float(abilities.get("laser_range_px", 0.0))
        self.laser_thickness = float(abilities.get("laser_thickness_px", 4.0))
        self.physics_path = physics_path
        self.upgrades = tuple(upgrades)
        catalog = load_upgrades(root)
        unknown = [u for u in self.upgrades if u not in catalog]
        if unknown:
            raise ValueError("mejora desconocida en data/upgrades.json: %s" % ", ".join(unknown))
        self.pulse_radius = effective_value(catalog, self.upgrades, "isak_abilities.pulse_radius_px",
                                            self.base_pulse_radius)

    def with_upgrades(self, extra):
        """Las mismas reglas con mas mejoras compradas."""
        ups = self.upgrades + tuple(u for u in extra if u not in self.upgrades)
        return Rules(self.root, self.physics_path, self.jump_efficiency, self.limit, self.allow_run, ups)

    def speeds(self):
        out = [("walk", self.walk_speed)]
        if self.allow_run:
            out.append(("run", self.run_speed))
        return out

    def reach(self, rise, speed):
        """Alcance horizontal de un salto completo que aterriza `rise` px mas arriba."""
        if rise > self.jump_height + EPS:
            return 0.0
        t_up = self.jump_v0 / self.gravity
        t_down = math.sqrt(2.0 * max(0.0, self.jump_height - rise) / (self.gravity * self.fall_mult))
        return speed * (t_up + t_down)

    def fall_reach(self, drop, speed):
        if drop <= 0.0:
            return 0.0
        return speed * math.sqrt(2.0 * drop / (self.gravity * self.fall_mult))

    def max_reach(self, speed):
        return self.reach(0.0, speed)


# --- Problemas ---

class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []

    @staticmethod
    def _entry(message, row=None, col=None, obj=None):
        text = message
        where = []
        if row is not None:
            where.append("fila %d" % row)
        if col is not None:
            where.append("columna %d" % col)
        if obj:
            where.append(str(obj))
        if where:
            text = "%s (%s)" % (message, ", ".join(where))
        return {"message": text, "row": row, "col": col, "object": obj}

    def error(self, message, row=None, col=None, obj=None):
        self.errors.append(self._entry(message, row, col, obj))

    def warning(self, message, row=None, col=None, obj=None):
        self.warnings.append(self._entry(message, row, col, obj))


# --- Puertas (objetos que se abren con el pulso) ---

class Gate:
    def __init__(self, gid, kind, obj_id, cells=None, rect=None, openers=None, col=0, row=0, tile=64.0):
        self.gid = gid
        self.kind = kind  # bridge, popup, bubble, pickup
        self.obj_id = obj_id
        self.cells = cells or []  # celdas solidas/apoyo (puente al abrir, pop-up al cerrar)
        self.rect = rect  # zona de dano (Burbuja)
        self.openers = openers or []  # rectangulos que el pulso debe tocar (px): (x0, y0, x1, y1, que)
        self.col = col
        self.row = row
        self.bypassable = False
        cols = [c for c, _ in self.cells]
        if rect is not None:
            cols += [int(rect[0] // tile), int(rect[2] // tile)]
        self.col_span = (min(cols), max(cols)) if cols else (col, col)

    def label(self):
        names = {"bridge": "puente", "popup": "pop-up", "bubble": "Burbuja", "pickup": "objeto de habilidad",
                 "terminal": "terminal de salida"}
        if getattr(self, "encounter", False):
            return "encuentro con Eco %s" % self.obj_id
        return "%s %s" % (names[self.kind], self.obj_id)


# --- Modelo ---

class LevelModel:
    def __init__(self, level, rules):
        self.level = level
        self.rules = rules
        self.grid = level["grid"]
        self.rows = len(self.grid)
        self.cols = len(self.grid[0])
        self.T = float(level["tile_size"])
        self.hw = rules.hitbox_w * 0.5
        self.hh = rules.hitbox_h
        world = int(level.get("world", 1))
        self.catalog = load_json(os.path.join(rules.root, "data", "world%d_objects.json" % world))
        self.hazard_data = load_json(os.path.join(rules.root, "data", "hazards.json"))
        self.pulse = bool(level.get("abilities_available", {}).get("pulse", False))
        self.laser_base = bool(level.get("abilities_available", {}).get("laser", False))
        self.bridge_thickness = float(self.catalog.get("bridge", {}).get("collision_height_px", self.T))
        self.glitch = set()
        # Recordatorios (2026-10-16, paso 6 de docs/propuesta-1-2.md §10): PROVISIONAL, tabla
        # solida fina siempre presente (sin su cuenta, su caida ni el Posponer: paso 10).
        self.reminders = {}
        self.gates = []
        self._build_objects()
        self.spike_rects = self._spike_rects()
        self.sections = level.get("sections", [])
        self._worlds = {}
        self._edges = {}
        reach_cols = max(s for _, s in rules.speeds()) * 1.2 / self.T
        self.K = int(math.ceil(reach_cols)) + 1
        # Hay laser en el nivel (habilidad disponible o un ability_pickup que lo da).
        self.laser_possible = self.laser_base or any(
            g.kind == "pickup" and g.ability == "laser" for g in self.gates)
        # Hay pulso en el nivel (desde el inicio, o lo da un encuentro con Eco o un ability_pickup).
        self.pulse_possible = self.pulse or any(g.kind == "pickup" and g.ability == "pulse" for g in self.gates)

    # Objetos.
    def _params(self, obj):
        entry = self.catalog["types"].get(obj["type"], {})
        params = dict(entry.get("defaults", {}))
        params.update(obj.get("params", {}))
        return params

    def _build_objects(self):
        T = self.T
        receivers = {}
        cfg_receiver = self.catalog.get("receiver", {})
        hit = cfg_receiver.get("hit_rect", [0, 0, T, T])
        for obj in self.level.get("objects", []):
            p = self._params(obj)
            # relay_receiver (2026-10-16, paso 3 de docs/propuesta-1-2.md §10): PROVISIONAL, se
            # modela como un receptor del pulso (sin la corriente de su lector laser ni la ventana
            # de tiempo); el lector, el anuncio (ad_cover) y el tiempo son el paso 10.
            if obj["type"] in ("receiver", "relay_receiver"):
                x0 = obj["x"] * T + hit[0]
                y0 = obj["y"] * T + hit[1]
                rect = (x0, y0, x0 + hit[2], y0 + hit[3], "receptor (fila %d, columna %d)" % (obj["y"], obj["x"]))
                receivers.setdefault(str(p.get("target", "")), []).append(rect)
            elif obj["type"] == "reminder_platform":
                thickness = float(self.catalog.get("reminder_platform", {}).get("card_height_px", T))
                for dx in range(int(p.get("width_tiles", 1))):
                    self.reminders[(obj["x"] + dx, obj["y"])] = thickness
            elif obj["type"] == "glitch_wall":
                for dy in range(int(p.get("height_tiles", 1))):
                    for dx in range(int(p.get("width_tiles", 1))):
                        self.glitch.add((obj["x"] + dx, obj["y"] + dy))
        for obj in self.level.get("objects", []):
            p = self._params(obj)
            if obj["type"] == "bridge_inactive":
                length = int(p.get("length_tiles", 1))
                step = 1 if p.get("direction", "right") == "right" else -1
                cells = [(obj["x"] + i * step, obj["y"]) for i in range(length)]
                bid = str(p.get("id", ""))
                self.gates.append(Gate("bridge:" + bid, "bridge", bid, cells=cells,
                                       openers=receivers.get(bid, []), col=obj["x"], row=obj["y"], tile=T))
            elif obj["type"] == "popup_blocker":
                w, h = int(p.get("width_tiles", 1)), int(p.get("height_tiles", 1))
                cells = [(obj["x"] + dx, obj["y"] + dy) for dy in range(h) for dx in range(w)]
                openers = []
                button = p.get("close_button_px")
                if isinstance(button, list) and len(button) == 2:
                    size = float(p.get("close_button_size_px", 16))
                    bx, by = obj["x"] * T + float(button[0]), obj["y"] * T + float(button[1])
                    openers.append((bx, by, bx + size, by + size, "boton de cerrar"))
                pid = str(p.get("id", "popup_%d_%d" % (obj["x"], obj["y"])))
                self.gates.append(Gate("popup:" + pid, "popup", pid, cells=cells, openers=openers,
                                       col=obj["x"], row=obj["y"], tile=T))
            elif obj["type"] == "ability_pickup":
                # Habilidad para siempre al tocar su celda: no cambia el mundo, solo el estado.
                aid = str(p.get("id", "ability_%d_%d" % (obj["x"], obj["y"])))
                gate = Gate("pickup:" + aid, "pickup", aid, cells=[(obj["x"], obj["y"])], col=obj["x"],
                            row=obj["y"], tile=T)
                gate.ability = str(p.get("ability", ""))
                self.gates.append(gate)
            elif obj["type"] == "eco_encounter":
                # Encuentro con Eco: da el pulso al tocar cualquier celda de su zona (toda la altura).
                eid = str(p.get("id", "eco_encounter_%d_%d" % (obj["x"], obj["y"])))
                w, h = int(p.get("width_tiles", 1)), int(p.get("height_tiles", 1))
                cells = [(obj["x"] + dx, obj["y"] + dy) for dy in range(h) for dx in range(w)]
                gate = Gate("encounter:" + eid, "pickup", eid, cells=cells, col=obj["x"], row=obj["y"], tile=T)
                gate.ability = "pulse"
                gate.encounter = True
                self.gates.append(gate)
        for enemy in self.level.get("enemies", []):
            path = os.path.join(self.rules.root, "data", "enemies", "%s.json" % enemy["type"])
            if enemy["type"] != "alert_bubble" or not os.path.exists(path):
                continue
            data = load_json(path)
            params = dict(data)
            params.update(enemy.get("params", {}))
            rng = float(params["patrol_range_px"])
            cx = (enemy["x"] + 0.5) * T
            floor = (enemy["y"] + 1) * T
            dw, dh = float(data["damage_size"][0]), float(data["damage_size"][1])
            dcy = float(data["damage_center_y"])
            bw, bh = float(data["body_size"][0]), float(data["body_size"][1])
            damage = (cx - rng * 0.5 - dw * 0.5, floor + dcy - dh * 0.5, cx + rng * 0.5 + dw * 0.5, floor + dcy + dh * 0.5)
            body = (cx - rng * 0.5 - bw * 0.5, floor - bh, cx + rng * 0.5 + bw * 0.5, floor, "cuerpo de la Burbuja")
            gate = Gate("bubble:" + enemy["id"], "bubble", enemy["id"], rect=damage, openers=[body],
                        col=enemy["x"], row=enemy["y"], tile=T)
            gate.floor = floor
            gate.damage_width = dw
            gate.damage_top = -(dcy - dh * 0.5)  # altura de la parte de arriba sobre el suelo
            # Burbuja en abierto a proposito (campo "open" del enemigo): se puede saltar. Desde el
            # 2026-10-15 pisarla no la mata (solo el laser, segun su vida `health`).
            gate.open = bool(enemy.get("open", False))
            gate.health = float(params.get("health", 1.0))
            gate.laser_from = None
            self.gates.append(gate)

    def _spike_rects(self):
        spikes = self.hazard_data["spikes"]
        height = float(spikes["hitbox_height_px"])
        T = self.T
        rects = []
        for r, row in enumerate(self.grid):
            for c, ch in enumerate(row):
                if ch != "^":
                    continue
                above = self.grid[r - 1][c] if r > 0 else "#"
                below = self.grid[r + 1][c] if r + 1 < self.rows else "#"
                ceiling = above == "#" and below != "#"
                y0 = r * T if ceiling else (r + 1) * T - height
                rects.append((c * T, y0, (c + 1) * T, y0 + height, "pinchos (fila %d, columna %d)" % (r, c)))
        return rects

    def gate(self, gid):
        return next(g for g in self.gates if g.gid == gid)

    def section_name(self, col, row=None):
        """Tramo que contiene la celda: x_from/x_to e y_from/y_to (niveles verticales,
        2026-10-16) con todo el ancho / todo el alto por defecto; sin fila, solo la columna."""
        for s in self.sections:
            if not s.get("x_from", 0) <= col <= s.get("x_to", self.cols - 1):
                continue
            if row is None or s.get("y_from", 0) <= row <= s.get("y_to", self.rows - 1):
                return s.get("name", "")
        return ""

    def is_vertical(self):
        """Nivel vertical (torre): camara de torre o tramos con y_from/y_to."""
        return self.level.get("camera", {}).get("vertical") == "tower" or any(
            "y_from" in s or "y_to" in s for s in self.sections)

    # Mundo en un estado (puertas abiertas + Debug).
    def world(self, state, debug=False):
        key = (state, debug)
        if key not in self._worlds:
            self._worlds[key] = World(self, state, debug)
        return self._worlds[key]

    def local_key(self, node, state):
        c = node[0]
        lo, hi = c - self.K - 3, c + self.K + 3
        return tuple(sorted(g.gid for g in self.gates
                            if g.gid in state and not (g.col_span[1] < lo or g.col_span[0] > hi)))

    def edges(self, node, state, debug=False):
        key = (node, self.local_key(node, state), debug)
        if key not in self._edges:
            self._edges[key] = self.world(state, debug).compute_edges(node)
        return self._edges[key]

    def has_pulse(self, state):
        """El pulso esta disponible: lo da el nivel desde el inicio o ya se paso por el encuentro con Eco
        (o se recogio un ability_pickup de pulso)."""
        return self.pulse or any(g.kind == "pickup" and g.ability == "pulse" and g.gid in state
                                 for g in self.gates)

    def has_laser(self, state):
        """El laser esta disponible: lo da el nivel o ya se recogio su ability_pickup."""
        return self.laser_base or any(g.kind == "pickup" and g.ability == "laser" and g.gid in state
                                      for g in self.gates)

    def can_open(self, gate, node, state, debug=False, use_laser=True):
        """Verdadero si desde `node` (de pie) se abre la puerta: el pulso toca algun rectangulo de
        la puerta, el laser alcanza a la Burbuja (si se puede usar) o, si es un ability_pickup,
        Isak toca su celda."""
        if gate.kind == "pickup":
            return bool(body_cells(node) & set(gate.cells))
        if gate.kind == "bubble" and use_laser and self.has_laser(state) and self.laser_hits(gate, node, state, debug):
            return True
        if not self.has_pulse(state) or not gate.openers:
            return False
        w = self.world(state, debug)
        c, r = node
        feet = (r + 1) * self.T
        x = c * self.T
        while x <= (c + 1) * self.T + EPS:
            if not w.collides(x, feet) and not w.in_hazard(x, feet):
                for facing in (1.0, -1.0):
                    px, py = x + self.rules.phone_x * facing, feet + self.rules.phone_y
                    for rect in gate.openers:
                        qx = min(max(px, rect[0]), rect[2])
                        qy = min(max(py, rect[1]), rect[3])
                        if math.hypot(px - qx, py - qy) <= self.rules.pulse_radius + EPS:
                            return True
            x += PULSE_SAMPLE_PX
        return False

    def laser_hits(self, gate, node, state, debug=False):
        """Verdadero si un disparo del laser desde `node` (de pie, mirando a un lado) alcanza la
        patrulla de la Burbuja `gate`: el haz sale horizontal del celular, llega a laser_range_px y
        choca con el terreno (solidos, puentes extendidos y pop-ups cerrados)."""
        rules = self.rules
        if rules.laser_range <= 0.0 or not gate.openers:
            return False
        w = self.world(state, debug)
        c, r = node
        T = self.T
        feet = (r + 1) * T
        py = feet + rules.phone_y
        half = rules.laser_thickness * 0.5
        bx0, by0, bx1, by1 = gate.openers[0][:4]
        if py + half < by0 or py - half > by1:
            return False
        x = c * T
        while x <= (c + 1) * T + EPS:
            if not w.collides(x, feet):
                for facing in (1.0, -1.0):
                    px = x + rules.phone_x * facing
                    if bx0 <= px <= bx1:
                        return True
                    near = bx0 if facing > 0 else bx1
                    dist = (near - px) * facing
                    if dist < 0.0 or dist > rules.laser_range + EPS:
                        continue
                    if not w.ray_blocked(px, near, py, half):
                        return True
            x += PULSE_SAMPLE_PX
        return False


class World:
    """Celdas solidas, apoyos y peligros de un estado concreto de las puertas."""

    def __init__(self, model, state, debug):
        self.m = model
        self.state = state
        self.debug = debug
        rows, cols = model.rows, model.cols
        self.solid = [[False] * cols for _ in range(rows)]
        self.support = [[False] * cols for _ in range(rows)]
        # Celdas con una tabla solida fina arriba (puente extendido): (col, fila) -> grosor en px.
        self.thin = {}
        for r, row in enumerate(model.grid):
            for c, ch in enumerate(row):
                if ch == "#" or ((c, r) in model.glitch and not debug) or (ch == "h" and debug):
                    self.solid[r][c] = True
                    self.support[r][c] = True
                elif ch == "-":
                    self.support[r][c] = True
        self.hazards = list(model.spike_rects)
        for (c, r), thickness in model.reminders.items():
            if 0 <= r < rows and 0 <= c < cols:
                self.support[r][c] = True
                if thickness < model.T - EPS:
                    self.thin[(c, r)] = thickness
                else:
                    self.solid[r][c] = True
        for g in model.gates:
            opened = g.gid in state
            if g.kind == "bridge" and opened:
                for c, r in g.cells:
                    if 0 <= r < rows and 0 <= c < cols:
                        self.support[r][c] = True
                        if model.bridge_thickness < model.T - EPS:
                            self.thin[(c, r)] = model.bridge_thickness
                        else:
                            self.solid[r][c] = True
            elif g.kind == "popup" and not opened:
                for c, r in g.cells:
                    if 0 <= r < rows and 0 <= c < cols:
                        self.solid[r][c] = True
                        self.support[r][c] = True
            elif g.kind == "bubble" and not opened and not g.bypassable:
                self.hazards.append(g.rect + ("Burbuja %s" % g.obj_id,))

    def is_solid(self, c, r):
        if c < 0 or c >= self.m.cols:
            return True
        if r < 0 or r >= self.m.rows:
            return False
        return self.solid[r][c]

    def is_support(self, c, r):
        if c < 0 or c >= self.m.cols or r < 0 or r >= self.m.rows:
            return False
        return self.support[r][c]

    def _obstacles(self, x, feet):
        """Fondo (y de abajo) de cada solido que toca la caja de Isak con los pies en `feet`."""
        T = self.m.T
        c0, c1 = int(math.floor((x - self.m.hw) / T)), int(math.floor((x + self.m.hw - EPS) / T))
        r0, r1 = int(math.floor((feet - self.m.hh) / T)), int(math.floor((feet - EPS) / T))
        top = feet - self.m.hh
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                if self.is_solid(c, r):
                    yield (r + 1) * T
                elif (c, r) in self.thin:
                    board = r * T + self.thin[(c, r)]
                    if top < board - EPS and feet > r * T + EPS:
                        yield board

    def collides(self, x, feet):
        T = self.m.T
        c0, c1 = int(math.floor((x - self.m.hw) / T)), int(math.floor((x + self.m.hw - EPS) / T))
        r0, r1 = int(math.floor((feet - self.m.hh) / T)), int(math.floor((feet - EPS) / T))
        cols = self.m.cols
        rows = self.m.rows
        thin = self.thin
        for r in range(r0, r1 + 1):
            row = self.solid[r] if 0 <= r < rows else None
            for c in range(c0, c1 + 1):
                if c < 0 or c >= cols:
                    return True
                if row is not None and row[c]:
                    return True
                if thin and (c, r) in thin:
                    board = r * T + thin[(c, r)]
                    if feet - self.m.hh < board - EPS and feet > r * T + EPS:
                        return True
        return False

    def ceiling_feet(self, x, feet):
        """Pies de Isak pegado bajo el techo mas bajo que le toca la cabeza en `feet`."""
        return max(self._obstacles(x, feet)) + self.m.hh

    def ray_blocked(self, x0, x1, y, half):
        """Verdadero si el haz horizontal de x0 a x1 (alto 2*half en y) choca con un solido o con la
        tabla de un puente extendido."""
        T = self.m.T
        lo, hi = min(x0, x1), max(x0, x1)
        r0, r1 = int(math.floor((y - half) / T)), int(math.floor((y + half - EPS) / T))
        for c in range(int(math.floor(lo / T)), int(math.floor((hi - EPS) / T)) + 1):
            for r in range(r0, r1 + 1):
                if self.is_solid(c, r):
                    return True
                if (c, r) in self.thin and y - half < r * T + self.thin[(c, r)] and y + half > r * T:
                    return True
        return False

    def hazard_at(self, x, feet):
        x0, x1, y0, y1 = x - self.m.hw, x + self.m.hw, feet - self.m.hh, feet
        for h in self.hazards:
            if x0 < h[2] and x1 > h[0] and y0 < h[3] and y1 > h[1]:
                return h[4]
        return None

    def in_hazard(self, x, feet):
        return self.hazard_at(x, feet) is not None

    def is_node(self, c, r):
        if not (0 <= c < self.m.cols and 0 <= r < self.m.rows):
            return False
        if not self.is_support(c, r + 1):
            return False
        x, feet = (c + 0.5) * self.m.T, (r + 1) * self.m.T
        return not self.collides(x, feet) and not self.in_hazard(x, feet)

    def nodes(self):
        return [(c, r) for r in range(self.m.rows) for c in range(self.m.cols) if self.is_node(c, r)]

    def simulate(self, x, y, vy, speed, x_target):
        """Trayectoria con velocidad horizontal `speed` hacia x_target. Devuelve
        (nodo_de_llegada, None) o (None, motivo)."""
        m = self.m
        T = m.T
        g = m.rules.gravity
        gm = g * m.rules.fall_mult
        dt = SIM_DT
        bottom = m.rows * T + m.hh
        for _ in range(int(SIM_MAX_S / dt)):
            # Horizontal.
            if abs(x_target - x) > EPS:
                step = speed * dt
                nx = x_target if abs(x_target - x) <= step else x + math.copysign(step, x_target - x)
                if not self.collides(nx, y):
                    x = nx
                elif nx > x:
                    wall = math.floor((nx + m.hw - EPS) / T) * T
                    cand = wall - m.hw
                    if cand > x and not self.collides(cand, y):
                        x = cand
                else:
                    wall = (math.floor((nx - m.hw) / T) + 1) * T
                    cand = wall + m.hw
                    if cand < x and not self.collides(cand, y):
                        x = cand
            # Vertical.
            acc = g if vy < 0.0 else gm
            ny = y + vy * dt + 0.5 * acc * dt * dt
            nvy = vy + acc * dt
            if ny < y:
                if self.collides(x, ny):
                    y = min(y, self.ceiling_feet(x, ny))
                    vy = 0.0
                else:
                    y, vy = ny, nvy
            else:
                landed = self._cross_support(x, y, ny)
                if landed is not None:
                    return landed, None
                if self.collides(x, ny):
                    # Esquina: la capsula resbala hacia fuera del solido.
                    moved = False
                    for side in (1.0, -1.0):
                        for shift in (1.0, 4.0, 8.0, m.hw):
                            cand = x + side * shift
                            if not self.collides(cand, ny):
                                x = cand
                                moved = True
                                break
                        if moved:
                            break
                    if not moved:
                        return None, "atascado"
                y, vy = ny, nvy
            hazard = self.hazard_at(x, y)
            if hazard:
                return None, hazard
            if y > bottom:
                return None, "cae fuera del nivel"
        return None, "sin aterrizar"

    def _cross_support(self, x, y, ny):
        T = self.m.T
        # filas cuya cara de arriba (r * T) cruzan los pies: y < r*T <= ny (o y == r*T al empezar a caer)
        first = int(math.ceil(y / T - EPS))
        last = int(math.floor(ny / T + EPS))
        for r in range(max(first, 0), last + 1):
            top = r * T
            if top < y - EPS or top > ny + EPS:
                continue
            cands = [int(math.floor(x / T))]
            if abs(x / T - round(x / T)) < EPS:
                cands = [int(round(x / T)) - 1, int(round(x / T))]
            for c in cands:
                if self.is_support(c, r) and not self.collides(x, top) and self.is_node_cell(c, r - 1, x):
                    return (c, r - 1)
        return None

    def is_node_cell(self, c, r, x):
        """Celda de pie donde aterriza (puede estar en el borde: x en la linea entre dos celdas)."""
        return 0 <= c < self.m.cols and 0 <= r < self.m.rows and self.is_node(c, r)

    def compute_edges(self, node):
        """Movimientos desde un nodo: lista de dicts {to, kind, h, v, x0, x1, rise, travel, speed}."""
        m = self.m
        if not self.is_node(*node):
            return []
        c, r = node
        T = m.T
        feet = (r + 1) * T
        best = {}

        order = {"walk": 0, "fall": 1, "jump": 2, "jump_run": 3}

        def add(to, kind, h, v, x0, travel, rise, speed_name):
            key = (round(max(h, v), 6), round(h + v, 6), order[kind])
            old = best.get(to)
            if old is None or key < (round(max(old["h"], old["v"]), 6), round(old["h"] + old["v"], 6),
                                     order[old["kind"]]):
                best[to] = {"to": to, "kind": kind, "h": h, "v": v, "x0": x0, "travel": travel,
                            "rise": rise, "speed": speed_name}

        for d in (1, -1):
            if self.is_node(c + d, r):
                add((c + d, r), "walk", 0.0, 0.0, (c + 0.5) * T, 0.0, 0.0, "walk")
        for speed_name, speed in m.rules.speeds():
            for d in (1, -1):
                edge_x = (c + 1) * T if d > 0 else c * T
                x_edge = edge_x if not self.collides(edge_x, feet) else edge_x - d * m.hw
                starts = [x_edge]
                center = (c + 0.5) * T
                if abs(center - x_edge) > EPS:
                    starts.append(center)
                targets = [None]
                for k in range(0, m.K + 1):
                    c2 = c + d * k
                    targets.append(c2 * T if d > 0 else (c2 + 1) * T)
                for x0 in starts:
                    for xt in targets:
                        x_target = x0 + d * 1e6 if xt is None else xt
                        if xt is not None and (xt - x0) * d < -EPS:
                            continue
                        to, _ = self.simulate(x0, feet, -m.rules.jump_v0, speed, x_target)
                        if to is None or to == node:
                            continue
                        rise = feet - (to[1] + 1) * T
                        travel = self._travel(x0, to, d)
                        h = travel / m.rules.reach(rise, speed) if travel > EPS else 0.0
                        v = max(0.0, rise) / m.rules.jump_height
                        if m.rules.reach(rise, speed) <= 0.0:
                            h = INF
                        add(to, "jump" if speed_name == "walk" else "jump_run", h, v, x0, travel, rise, speed_name)
                # Caidas desde el borde (sin saltar).
                if not self.is_support(c + d, r + 1) and not self.collides(edge_x, feet):
                    for xt in targets:
                        x_target = edge_x + d * 1e6 if xt is None else xt
                        if xt is not None and (xt - edge_x) * d < -EPS:
                            continue
                        start_x = edge_x + d * EPS * 10
                        to, _ = self.simulate(start_x, feet, 0.0, speed, x_target)
                        if to is None or to == node:
                            continue
                        drop = (to[1] + 1) * T - feet
                        travel = self._travel(edge_x, to, d)
                        reach = m.rules.fall_reach(drop, speed)
                        h = (travel / reach if reach > 0 else INF) if travel > EPS else 0.0
                        add(to, "fall", h, 0.0, edge_x, travel, -drop, speed_name)
        return list(best.values())

    def _travel(self, x0, to, d):
        T = self.m.T
        near = to[0] * T if d > 0 else (to[0] + 1) * T
        return max(0.0, (near - x0) * d)


# --- Busqueda ---

# Coste secundario por movimiento (desempata caminos con la misma exigencia maxima).
STEP_COST = 0.01


def search(model, source, state, limit, debug=False, avoid=None):
    """Dijkstra de cuello de botella: minimiza la mayor exigencia del camino y, a igualdad,
    la suma de exigencias (+ STEP_COST por movimiento). Devuelve (cost, parent); cost[n] es
    la mayor exigencia del mejor camino hasta n. `avoid`: celdas que Isak no puede tocar de pie
    (p. ej. la de un ability_pickup, para saber si recogerlo es obligatorio)."""
    best = {source: (0.0, 0.0)}
    parent = {source: None}
    heap = [(0.0, 0.0, source)]
    while heap:
        c_max, c_sum, node = heapq.heappop(heap)
        if (c_max, c_sum) > best[node]:
            continue
        for e in model.edges(node, state, debug):
            dval = max(e["h"], e["v"])
            if dval > limit + EPS:
                continue
            key = (round(max(c_max, dval), 9), round(c_sum + e["h"] + e["v"] + STEP_COST, 9))
            to = e["to"]
            if avoid and body_cells(to) & avoid:
                continue
            if to not in best or key < best[to]:
                best[to] = key
                parent[to] = (node, e)
                heapq.heappush(heap, (key[0], key[1], to))
    return {n: k[0] for n, k in best.items()}, parent


def path_to(parent, target):
    out = []
    node = target
    while parent.get(node) is not None:
        prev, edge = parent[node]
        out.append((prev, edge))
        node = prev
    out.reverse()
    return out


def body_cells(node):
    c, r = node
    return {(c, r), (c, r - 1)}


class Validator:
    def __init__(self, level, rules):
        self.level = level
        self.rules = rules
        self.report = Report()
        self.model = LevelModel(level, rules)
        self.grid = level["grid"]
        self.result = {}

    def find(self, char):
        return [(c, r) for r, row in enumerate(self.grid) for c, ch in enumerate(row) if ch == char]

    def touches(self, node, cells):
        return bool(body_cells(node) & cells)

    # Aparicion: cae en vertical desde la celda.
    def spawn_node(self, cell, state=frozenset(), what="P"):
        w = self.model.world(state)
        c, r = cell
        T = self.model.T
        if w.is_node(c, r):
            return (c, r), None
        x, feet = (c + 0.5) * T, (r + 1) * T
        if w.collides(x, feet):
            return None, "%s dentro de terreno solido" % what
        if w.in_hazard(x, feet):
            return None, "%s en pinchos" % what
        node, why = w.simulate(x, feet, 0.0, 0.0, x)
        return node, why

    def progression(self, source, gates0, limit, forbid=frozenset(), targets=None, debug=False, avoid=None,
                    use_laser=True):
        """Avanza abriendo puertas hasta tocar `targets` (celdas). Devuelve dict con
        ok, stages [(src, state, cost, parent, opened_gate, opener_node, end_node)], reached.
        `avoid`: celdas que no se pisan; `use_laser`: si el laser (una vez disponible) abre puertas."""
        state = frozenset(gates0)
        src = source
        stages = []
        reached_all = set()
        avoid = set(avoid) if avoid else None
        for _ in range(len(self.model.gates) + 1):
            cost, parent = search(self.model, src, state, limit, debug, avoid)
            reached_all |= set(cost)
            goal_nodes = [n for n in cost if self.touches(n, targets)]
            if goal_nodes:
                end = min(goal_nodes, key=lambda n: (cost[n], n[0], n[1]))
                stages.append({"src": src, "state": state, "cost": cost, "parent": parent, "gate": None,
                               "end": end})
                return {"ok": True, "stages": stages, "reached": reached_all, "state": state}
            options = []
            for g in self.model.gates:
                if g.gid in state or g.gid in forbid or g.bypassable:
                    continue
                for n in sorted(cost, key=lambda n: (cost[n], n[0], n[1])):
                    if self._gate_near(g, n) and self.model.can_open(g, n, state, debug, use_laser):
                        options.append((cost[n], n[0], g, n))
                        break
            if not options:
                stages.append({"src": src, "state": state, "cost": cost, "parent": parent, "gate": None,
                               "end": None})
                return {"ok": False, "stages": stages, "reached": reached_all, "state": state}
            options.sort(key=lambda o: (o[0], o[1]))
            _, _, gate, opener = options[0]
            stages.append({"src": src, "state": state, "cost": cost, "parent": parent, "gate": gate,
                           "end": opener})
            state = state | {gate.gid}
            src = opener
        return {"ok": False, "stages": stages, "reached": reached_all, "state": state}

    # --- Reglas ---

    def run(self):
        rep = self.report
        model = self.model
        T = model.T
        starts = self.find("P")
        goals = self.find("G")
        if len(starts) != 1 or len(goals) != 1:
            rep.error("el grid necesita exactamente una P y una G")
            return self.finish()
        goal_cells = {goals[0]}
        self._check_bubbles()
        # Regla 5 (P) y nodo de inicio.
        start, why = self.spawn_node(starts[0])
        self._check_spawn_spikes(starts[0], start, "P")
        if start is None:
            rep.error("Isak no tiene donde aparecer desde P: %s" % why, starts[0][1], starts[0][0])
            return self.finish()
        self.result["start"] = start
        # Regla 1 y 3: camino estricto (exigencia <= limite).
        main = self.progression(start, frozenset(), self.rules.limit, forbid=self.secret_gates(),
                                targets=goal_cells)
        self.main = main
        if not main["ok"]:
            self._explain_failure(start, goal_cells)
            self.result["path"] = []
        else:
            self._describe_path(main)
        # Regla 2.
        self._check_checkpoints(start, main)
        # Regla 4 y secretos que son un objeto recogible.
        self._check_secrets(start, goal_cells)
        self._check_reachable_secrets(start)
        self._check_extra_lives(start, goal_cells)
        # Regla 6c: terminal de salida activable con el pulso.
        self._check_exit_terminals(main)
        # Regla 6d: el pulso no existe antes del encuentro con Eco.
        self._check_pulse_source()
        # Regla 6: puertas obligatorias.
        if main["ok"]:
            self._check_mandatory(start, goal_cells)
            # Regla 6b: habilidades (ability_pickup) y meta sin laser.
            self._check_pickups(start, goal_cells)
            # Regla 7: soft-locks (y desde donde alcanza el laser a cada Burbuja).
            self._check_softlocks(main, goal_cells)
        return self.finish()

    def _check_exit_terminals(self, main):
        """La terminal de salida se activa con el pulso desde el camino principal (sin mejoras ni laser)."""
        m = self.model
        T = m.T
        hit = m.catalog.get("exit_terminal", {}).get("hit_rect_px", [0, 0, T, 2 * T])
        last = main["stages"][-1]
        terminals = []
        for obj in self.level.get("objects", []):
            if obj["type"] != "exit_terminal":
                continue
            tid = str(obj.get("params", {}).get("id", "terminal_%d_%d" % (obj["x"], obj["y"])))
            x0, y0 = obj["x"] * T + hit[0], obj["y"] * T + hit[1]
            gate = Gate("terminal:" + tid, "terminal", tid, openers=[(x0, y0, x0 + hit[2], y0 + hit[3], "terminal")],
                        col=obj["x"], row=obj["y"], tile=T)
            if not m.pulse_possible:
                self.report.error("%s necesita el pulso y el nivel no lo tiene (abilities_available.pulse ni "
                                  "encuentro con Eco)" % gate.label(), obj["y"], obj["x"], gate.label())
                continue
            if not main["ok"]:
                continue
            source = None
            for n in sorted(last["cost"], key=lambda n: (abs(n[0] - obj["x"]), last["cost"][n], n[1])):
                if abs(n[0] - obj["x"]) > 3:
                    break
                if m.can_open(gate, n, last["state"], use_laser=False):
                    source = n
                    break
            if source is None:
                self.report.error("%s: el pulso no la alcanza desde ninguna celda del camino hacia la meta"
                                  % gate.label(), obj["y"], obj["x"], gate.label())
            terminals.append({"id": tid, "pulse_from": None if source is None else [source[1], source[0]]})
        self.result["exit_terminals"] = terminals

    def _check_pulse_source(self):
        """Regla 6d: de donde sale el pulso. Sin pulso al empezar, lo da el encuentro con Eco (o un
        ability_pickup de pulso): ninguna puerta que lo exija puede quedar antes de el."""
        m = self.model
        sources = [g for g in m.gates if g.kind == "pickup" and g.ability == "pulse"]
        info = {"from_start": m.pulse, "given_by": [g.obj_id for g in sources],
                "encounter": [g.obj_id for g in sources if getattr(g, "encounter", False)]}
        self.result["pulse"] = info
        if m.pulse or not sources:
            return
        first = min(g.col_span[0] for g in sources)
        info["available_from_col"] = first
        names = ", ".join(g.label() for g in sources)
        for g in m.gates:
            if g.kind == "pickup" or g.col_span[0] >= first:
                continue
            if g.kind == "bubble" and g.bypassable:
                continue
            if g.kind in ("bridge", "popup") or g.kind == "bubble":
                self.report.error("%s exige el pulso y esta antes de %s (columna %d): el pulso aun no existe"
                                  % (g.label(), names, first), g.row, g.col, g.label())
        for obj in self.level.get("objects", []):
            if obj["type"] == "exit_terminal" and obj["x"] < first:
                self.report.error("la terminal de salida exige el pulso y esta antes de %s (columna %d)"
                                  % (names, first), obj["y"], obj["x"])

    def _check_bubbles(self):
        """La Burbuja bloquea si bajo su patrulla Isak no puede pasarle por encima."""
        m = self.model
        r = self.rules
        for g in m.gates:
            if g.kind != "bubble":
                continue
            row_floor = int(round(g.floor / m.T))
            c0, c1 = int(g.rect[0] // m.T), int((g.rect[2] - EPS) // m.T)
            headroom = INF
            for c in range(max(c0, 0), min(c1, m.cols - 1) + 1):
                free = 0
                rr = row_floor - 1
                while rr >= 0 and m.grid[rr][c] != "#":
                    free += 1
                    rr -= 1
                headroom = min(headroom, INF if rr < 0 else free * m.T)
            apex = min(r.jump_height, headroom - r.hitbox_h)
            over = g.damage_top
            need = g.damage_width + r.hitbox_w
            dist = 0.0
            if apex > over:
                v_over = math.sqrt(max(0.0, r.jump_v0 ** 2 - 2 * r.gravity * over))
                v_apex = math.sqrt(max(0.0, r.jump_v0 ** 2 - 2 * r.gravity * apex))
                t_up = (v_over - v_apex) / r.gravity
                t_down = math.sqrt(2 * (apex - over) / (r.gravity * r.fall_mult))
                dist = r.walk_speed * (t_up + t_down)
            g.jump_over_px = dist
            g.headroom_px = headroom
            g.apex_px = apex
            if dist >= need:
                g.bypassable = True
                if not g.open:
                    self.report.warning(
                        "el pulso no es obligatorio para la Burbuja: con %s px libres sobre su patrulla Isak "
                        "eleva los pies %.0f px y recorre %.0f px por encima de su zona de dano (necesita %.0f)"
                        % ("inf" if headroom == INF else "%.0f" % headroom, apex, dist, need),
                        g.row, g.col, "Burbuja %s" % g.obj_id)
            if g.open and not g.bypassable:
                self.report.warning("la Burbuja %s esta marcada en abierto (open) pero bloquea el paso "
                                    "(%s px libres sobre su patrulla)"
                                    % (g.obj_id, "%.0f" % headroom), g.row, g.col, "Burbuja %s" % g.obj_id)

    def _check_spawn_spikes(self, cell, node, what):
        """Pinchos en la celda de aparicion, en la caida hasta el suelo o en el suelo."""
        c, r = cell
        check = [(c, r)]
        if node is not None:
            nc, nr = node
            check += [(nc, rr) for rr in range(r, nr + 2)]
        else:
            rr = r + 1
            while rr < len(self.grid) and self.grid[rr][c] not in "#-":
                check.append((c, rr))
                rr += 1
        for cc, rr in check:
            if 0 <= rr < len(self.grid) and self.grid[rr][cc] == "^":
                self.report.error("pinchos en el punto de aparicion %s" % what, rr, cc)
                return

    def _explain_failure(self, start, goal_cells):
        rep = self.report
        lenient = self.progression(start, frozenset(), INF, targets=goal_cells)
        if lenient["ok"]:
            for stage in lenient["stages"]:
                if stage["end"] is None:
                    continue
                for prev, e in path_to(stage["parent"], stage["end"]):
                    if max(e["h"], e["v"]) > self.rules.limit + EPS:
                        rep.error("salto de (fila %d, columna %d) a (fila %d, columna %d) exige %.0f %% del alcance "
                                  "horizontal y %.0f %% del vertical (limite %.0f %%)"
                                  % (prev[1], prev[0], e["to"][1], e["to"][0], e["h"] * 100, e["v"] * 100,
                                     self.rules.limit * 100), prev[1], prev[0])
            return
        last = lenient["stages"][-1]
        reached = last["cost"]
        # Lo mas lejos que llega Isak: a la derecha en un nivel horizontal; arriba en una torre.
        if self.model.is_vertical():
            far = min(reached, key=lambda n: (n[1], -n[0]))
        else:
            far = max(reached, key=lambda n: (n[0], -n[1]))
        state = last["state"]
        pending = [g for g in self.model.gates if g.gid not in state and not g.bypassable and g.kind != "pickup"]
        for g in pending:
            if not g.openers:
                what = {"bridge": "no tiene receptor", "popup": "no tiene boton de cerrar",
                        "bubble": "no se puede alcanzar"}[g.kind]
                rep.error("%s %s: el pulso no lo puede abrir" % (g.label(), what), g.row, g.col, g.label())
            elif not self.model.pulse_possible:
                rep.error("%s necesita el pulso y el nivel no lo tiene (abilities_available.pulse ni encuentro "
                          "con Eco)" % g.label(), g.row, g.col, g.label())
            elif not self.model.has_pulse(state):
                rep.error("%s necesita el pulso y aun no se tiene (lo da %s)" % (
                    g.label(), ", ".join(p.label() for p in self.model.gates
                                         if p.kind == "pickup" and p.ability == "pulse")), g.row, g.col, g.label())
            elif g.col_span[0] <= far[0] + self.model.K + 4:
                rep.error("%s: el pulso no alcanza %s desde ninguna celda alcanzable antes de el"
                          % (g.label(), " ni ".join(o[4] for o in g.openers)), g.row, g.col, g.label())
        where = self.model.section_name(far[0], far[1]) or "sin tramo"
        if self.model.is_vertical():
            rep.error("no hay camino de P a G: Isak no sube de la fila %d (columna %d, %s); lo siguiente es la "
                      "fila %d" % (far[1], far[0], where, far[1] - 1), far[1], far[0])
        else:
            nxt = far[0] + 1
            rep.error("no hay camino de P a G: Isak no pasa de la fila %d, columna %d (%s); lo siguiente es la "
                      "columna %d" % (far[1], far[0], where, nxt), far[1], far[0])

    def _describe_path(self, run):
        actions = []
        edges_used = []
        for stage in run["stages"]:
            segment = path_to(stage["parent"], stage["end"])
            walk_from = None
            for prev, e in segment:
                edges_used.append((prev, e))
                if e["kind"] == "walk":
                    if walk_from is None:
                        walk_from = prev
                    continue
                if walk_from is not None:
                    actions.append(self._walk_action(walk_from, prev))
                    walk_from = None
                actions.append(self._move_action(prev, e))
            if walk_from is not None:
                actions.append(self._walk_action(walk_from, stage["end"]))
            if stage["gate"] is not None:
                n = stage["end"]
                g = stage["gate"]
                if g.kind == "pickup":
                    verb = "pasa por" if getattr(g, "encounter", False) else "recoge"
                    actions.append({"action": "pickup", "from": [n[1], n[0]], "object": g.label(),
                                    "text": "%s %s (%s) en (fila %d, columna %d)"
                                            % (verb, g.label(), g.ability, n[1], n[0])})
                    continue
                laser = g.kind == "bubble" and not self.model.can_open(g, n, stage["state"], use_laser=False)
                actions.append({"action": "laser" if laser else "pulse", "from": [n[1], n[0]], "object": g.label(),
                                "text": "%s desde (fila %d, columna %d) -> %s"
                                        % ("laser" if laser else "pulso", n[1], n[0], g.label())})
        end = run["stages"][-1]["end"]
        actions.append({"action": "goal", "at": [end[1], end[0]],
                        "text": "meta G alcanzada en (fila %d, columna %d)" % (end[1], end[0])})
        jumps = [(p, e) for p, e in edges_used if e["kind"] != "walk"]
        max_h = max([e["h"] for _, e in jumps] + [0.0])
        max_v = max([e["v"] for _, e in jumps] + [0.0])
        worst_h = max(jumps, key=lambda pe: pe[1]["h"]) if jumps else None
        worst_v = max(jumps, key=lambda pe: pe[1]["v"]) if jumps else None
        self.result["path"] = actions
        self.result["margins"] = {
            "limit": self.rules.limit,
            "max_horizontal": round(max_h, 4),
            "max_vertical": round(max_v, 4),
            "min_margin_horizontal": round(self.rules.limit - max_h, 4),
            "min_margin_vertical": round(self.rules.limit - max_v, 4),
            "min_margin": round(self.rules.limit - max(max_h, max_v), 4),
            "worst_horizontal": self._edge_info(worst_h) if worst_h else None,
            "worst_vertical": self._edge_info(worst_v) if worst_v else None,
        }

    def _edge_info(self, pe):
        prev, e = pe
        return {"from": [prev[1], prev[0]], "to": [e["to"][1], e["to"][0]], "kind": e["kind"],
                "travel_px": round(e["travel"], 1), "rise_px": round(e["rise"], 1),
                "h": round(e["h"], 4), "v": round(e["v"], 4)}

    def _walk_action(self, a, b):
        return {"action": "walk", "from": [a[1], a[0]], "to": [b[1], b[0]],
                "text": "andar de (fila %d, columna %d) a (fila %d, columna %d)%s"
                        % (a[1], a[0], b[1], b[0], self._section_suffix(b[0], b[1]))}

    def _move_action(self, prev, e):
        to = e["to"]
        names = {"jump": "saltar", "jump_run": "saltar corriendo", "fall": "caer"}
        rise = e["rise"]
        text = "%s de (fila %d, columna %d) a (fila %d, columna %d): %.0f px en el aire, %s %.0f px " \
               "-> %.0f %% horizontal, %.0f %% vertical%s" % (
                   names[e["kind"]], prev[1], prev[0], to[1], to[0], e["travel"],
                   "sube" if rise >= 0 else "baja", abs(rise), e["h"] * 100, e["v"] * 100,
                   self._section_suffix(to[0], to[1]))
        return {"action": e["kind"], "from": [prev[1], prev[0]], "to": [to[1], to[0]],
                "travel_px": round(e["travel"], 1), "rise_px": round(rise, 1),
                "h": round(e["h"], 4), "v": round(e["v"], 4), "text": text}

    def _section_suffix(self, col, row=None):
        name = self.model.section_name(col, row)
        return " [%s]" % name if name else ""

    def _stage_of(self, run, node):
        for i, stage in enumerate(run["stages"]):
            if node in stage["cost"]:
                return i
        return None

    def _check_checkpoints(self, start, main):
        rep = self.report
        prev_node, prev_state, prev_name = start, frozenset(), "P"
        info = []
        for cp in self.level.get("checkpoints", []):
            cell = (cp["x"], cp["y"])
            node, why = self.spawn_node(cell, what="C %s" % cp["id"])
            self._check_checkpoint_spikes(cp, node)
            run = self.progression(prev_node, prev_state, self.rules.limit, targets={cell})
            ok = run["ok"]
            info.append({"id": cp["id"], "row": cp["y"], "col": cp["x"], "reachable_from": prev_name if ok else None})
            if not ok:
                rep.error("punto de sincronizacion %s inalcanzable desde %s" % (cp["id"], prev_name),
                          cp["y"], cp["x"], cp["id"])
                continue
            if node is None:
                rep.error("punto de sincronizacion %s sin suelo debajo (%s)" % (cp["id"], why), cp["y"], cp["x"],
                          cp["id"])
                continue
            prev_state = run["stages"][-1]["state"]
            prev_node, prev_name = node, cp["id"]
        self.result["checkpoints"] = info

    def _check_checkpoint_spikes(self, cp, node):
        c, r = cp["x"], cp["y"]
        cells = [(c, r), (c - 1, r), (c + 1, r), (c, r + 1)]
        if node is not None:
            cells += [(node[0], node[1] + 1)]
        for cc, rr in cells:
            if 0 <= rr < len(self.grid) and 0 <= cc < len(self.grid[0]) and self.grid[rr][cc] == "^":
                self.report.error("pinchos en el primer tile del punto de sincronizacion %s" % cp["id"], rr, cc,
                                  cp["id"])

    def _check_secrets(self, start, goal_cells):
        """Regla 4: los secretos S con "needs_debug": true solo se alcanzan por plataformas ocultas."""
        info = []
        debug_secrets = [s for s in self.level.get("secrets", []) if s.get("needs_debug") and not s.get("object")]
        if not debug_secrets:
            self.result["secrets"] = {"rule_4": "sin secretos con needs_debug: no aplica", "items": info}
            for s in self.level.get("secrets", []):
                if s.get("object"):
                    info.append({"id": s["id"], "object": s["object"], "note": "objeto (V7): fuera de la regla 4"})
            return
        for s in self.level.get("secrets", []):
            if s.get("object"):
                info.append({"id": s["id"], "object": s["object"], "note": "objeto (V7): fuera de la regla 4"})
                continue
            if not s.get("needs_debug"):
                continue
            cell = {(s["x"], s["y"])}
            without = self.progression(start, frozenset(), self.rules.limit, targets=cell, debug=False)
            with_debug = self.progression(start, frozenset(), self.rules.limit, targets=cell, debug=True)
            info.append({"id": s["id"], "without_debug": without["ok"], "with_debug": with_debug["ok"]})
            if without["ok"]:
                self.report.error("el secreto %s se alcanza sin pasar por plataformas ocultas" % s["id"],
                                  s["y"], s["x"], s["id"])
            elif not with_debug["ok"]:
                self.report.error("el secreto %s no se alcanza ni con las plataformas ocultas" % s["id"],
                                  s["y"], s["x"], s["id"])
        self.result["secrets"] = {"rule_4": "comprobada", "items": info}

    def secret_gates(self):
        """gid de las puertas que pertenecen a un secreto (campo `gates` de la entrada del secreto,
        con los params.id de los objetos): son opcionales a proposito."""
        ids = set()
        for s in self.level.get("secrets", []):
            ids.update(str(i) for i in s.get("gates", []))
        return frozenset(g.gid for g in self.model.gates if g.obj_id in ids)

    def _check_reachable_secrets(self, start):
        """Secretos que se recogen sin Debug: los que son un objeto recogible (no la pared con
        glitch) y los de una celda S sin "needs_debug" (regla 4). Se alcanzan
        abriendo las puertas que hagan falta (las suyas incluidas). Con "requires_upgrade" no deben
        alcanzarse sin esa mejora y si con ella."""
        info = self.result.setdefault("secrets", {}).setdefault("items", [])
        for s in self.level.get("secrets", []):
            obj = s.get("object")
            if obj == "glitch_wall" or (not obj and s.get("needs_debug")):
                continue
            cell = {(s["x"], s["y"])}
            what = "%s (%s)" % (s["id"], obj) if obj else s["id"]
            item = next((i for i in info if i.get("id") == s["id"]), None)
            if item is None:
                item = {"id": s["id"], "object": obj}
                info.append(item)
            required = s.get("requires_upgrade")
            run = self.progression(start, frozenset(), self.rules.limit, targets=cell)
            item.update({"reachable": run["ok"],
                         "secret_gates_opened": sorted(g for g in run["state"] if g in self.secret_gates())})
            if not required or required in self.rules.upgrades:
                if not run["ok"]:
                    self.report.error("el secreto %s no se alcanza%s" % (
                        what, " con la mejora %s" % required if required else ""), s["y"], s["x"], s["id"])
                continue
            item["requires_upgrade"] = required
            item["reachable_without_upgrade"] = run["ok"]
            if run["ok"]:
                self.report.error("el secreto %s se alcanza sin la mejora %s (radio del pulso %.0f px)"
                                  % (what, required, self.rules.pulse_radius), s["y"], s["x"], s["id"])
            try:
                upgraded = Validator(self.level, self.rules.with_upgrades([required]))
            except ValueError as exc:
                self.report.error("el secreto %s pide una mejora que no existe: %s" % (what, exc),
                                  s["y"], s["x"], s["id"])
                continue
            up_start, _ = upgraded.spawn_node(self.find("P")[0])
            up_run = upgraded.progression(up_start, frozenset(), upgraded.rules.limit, targets=cell)
            item["reachable_with_upgrade"] = up_run["ok"]
            item["pulse_radius_with_upgrade_px"] = upgraded.rules.pulse_radius
            if not up_run["ok"]:
                self.report.error("el secreto %s no se alcanza ni con la mejora %s (radio del pulso %.0f px)"
                                  % (what, required, upgraded.rules.pulse_radius), s["y"], s["x"], s["id"])

    def _check_extra_lives(self, start, goal_cells):
        """Regla 4b (vida extra, extra_life_pickup; 2026-10-16): se alcanza; si esta en una celda de
        una pared con glitch (que solo se abre con el Debug) NO se alcanza sin Debug y SI con Debug
        («alcanzable con Debug»); nunca es obligatoria (la meta se alcanza sin tocarla y sin Debug)."""
        items = []
        for obj in self.level.get("objects", []):
            if obj["type"] != "extra_life_pickup":
                continue
            cell = (obj["x"], obj["y"])
            oid = str(obj.get("params", {}).get("id", "vida extra"))
            hidden = cell in self.model.glitch
            without = self.progression(start, frozenset(), self.rules.limit, targets={cell})
            item = {"id": oid, "cell": list(cell), "behind_glitch_wall": hidden,
                    "reachable_without_debug": without["ok"]}
            if hidden:
                with_debug = self.progression(start, frozenset(), self.rules.limit, targets={cell}, debug=True)
                item["reachable_with_debug"] = with_debug["ok"]
                if without["ok"]:
                    self.report.error("la vida extra %s se alcanza sin Debug (la tapa una pared con glitch)" % oid,
                                      cell[1], cell[0], oid)
                if not with_debug["ok"]:
                    self.report.error("la vida extra %s no se alcanza ni con el Debug" % oid, cell[1], cell[0], oid)
            elif not without["ok"]:
                self.report.error("la vida extra %s no se alcanza" % oid, cell[1], cell[0], oid)
            goal = self.progression(start, frozenset(), self.rules.limit, forbid=self.secret_gates(),
                                    targets=goal_cells, avoid={cell})
            item["mandatory"] = not goal["ok"]
            if not goal["ok"]:
                self.report.error("la vida extra %s es obligatoria: sin tocarla no se llega a la meta" % oid,
                                  cell[1], cell[0], oid)
            items.append(item)
        self.result["extra_lives"] = items

    def _check_mandatory(self, start, goal_cells):
        secret = self.secret_gates()
        for g in self.model.gates:
            if g.bypassable or g.kind == "pickup":
                continue
            run = self.progression(start, frozenset(), INF, forbid=frozenset({g.gid}), targets=goal_cells)
            if g.gid in secret:
                if not run["ok"]:
                    self.report.warning("%s es de un secreto pero hace falta para llegar a la meta" % g.label(),
                                        g.row, g.col, g.label())
                continue
            if run["ok"]:
                what = {"bridge": "activar el receptor", "popup": "cerrar el pop-up",
                        "bubble": "aturdir la Burbuja"}[g.kind]
                self.report.warning("%s no es obligatorio: se llega a la meta sin %s" % (g.label(), what),
                                    g.row, g.col, g.label())

    def _check_pickups(self, start, goal_cells):
        """Regla 6b: cada ability_pickup se alcanza; si no es de un secreto debe ser obligatorio (sin
        tocar su celda no se llega a la meta). La meta se alcanza sin usar el laser."""
        info = []
        secret_ids = set()
        for s in self.level.get("secrets", []):
            secret_ids.update(str(i) for i in s.get("gates", []))
        forbid = self.secret_gates()
        for g in self.model.gates:
            if g.kind != "pickup":
                continue
            cells = set(g.cells)
            reach = self.progression(start, frozenset(), self.rules.limit, forbid=forbid, targets=cells)
            without = self.progression(start, frozenset(), INF, forbid=frozenset({g.gid}), targets=goal_cells,
                                       avoid=cells)
            item = {"id": g.obj_id, "ability": g.ability, "row": g.row, "col": g.col, "reachable": reach["ok"],
                    "mandatory": not without["ok"], "secret": g.obj_id in secret_ids}
            if getattr(g, "encounter", False):
                item["encounter"] = True
            info.append(item)
            if not reach["ok"]:
                self.report.error("%s (%s) no se alcanza" % (g.label(), g.ability), g.row, g.col, g.label())
            elif without["ok"] and getattr(g, "encounter", False):
                self.report.error("%s no es obligatorio: se llega a la meta sin pasar por el" % g.label(),
                                  g.row, g.col, g.label())
            elif without["ok"] and not item["secret"]:
                self.report.warning("%s (%s) no es obligatorio: se llega a la meta sin recogerlo"
                                    % (g.label(), g.ability), g.row, g.col, g.label())
        no_laser = self.progression(start, frozenset(), self.rules.limit, forbid=forbid, targets=goal_cells,
                                    use_laser=False)
        self.result["abilities"] = {"pickups": info, "goal_without_laser": no_laser["ok"]}
        if self.model.laser_possible and not no_laser["ok"]:
            self.report.warning("la meta solo se alcanza usando el laser")

    def _laser_info(self, seen):
        """Desde donde alcanza el laser a cada Burbuja (primera celda, de izquierda a derecha, con el
        laser ya disponible). Avisa si una Burbuja en abierto posterior al laser no se alcanza."""
        m = self.model
        if not m.laser_possible:
            return
        by_node = {}
        for node, state in seen:
            if m.has_laser(state) and node not in by_node:
                by_node[node] = state
        pickups = [g.col for g in m.gates if g.kind == "pickup" and g.ability == "laser"]
        first = min(pickups) if pickups else -1
        for g in m.gates:
            if g.kind != "bubble":
                continue
            for node in sorted((n for n in by_node if abs(n[1] - g.row) <= 1), key=lambda n: (n[0], n[1])):
                if m.laser_hits(g, node, by_node[node]):
                    g.laser_from = node
                    break
            if g.open and g.col > first and g.laser_from is None:
                self.report.warning("la Burbuja %s va tras el laser pero el laser no la alcanza desde ningun sitio"
                                    % g.obj_id, g.row, g.col, "Burbuja %s" % g.obj_id)

    def _gate_near(self, gate, node):
        """Verdadero si `node` esta cerca de algun rectangulo que abre la puerta (filtro barato
        antes de can_open: el pulso no llega mas lejos de su radio + medio tile; el laser, de su
        alcance; un ability_pickup se toca desde su columna o las de al lado)."""
        T = self.model.T
        if gate.kind == "pickup":
            return gate.col_span[0] - 1 <= node[0] <= gate.col_span[1] + 1
        reach = self.rules.pulse_radius + T
        if gate.kind == "bubble" and self.model.laser_possible:
            reach = max(reach, self.rules.laser_range + T)
        x = (node[0] + 0.5) * T
        return any(o[0] - reach <= x <= o[2] + reach for o in gate.openers)

    def _check_softlocks(self, main, goal_cells):
        """Grafo producto (nodo, puertas abiertas) restringido a lo que se alcanza desde P:
        hacia delante se anda, salta, cae o se abre una puerta desde donde el pulso la toca;
        hacia atras desde la meta se marcan los pares buenos. Soft-lock = par alcanzable desde
        el que ya no se llega a la meta."""
        m = self.model
        start = (main["stages"][0]["src"], frozenset())
        seen = {start}
        reverse = {}
        queue = [start]
        goals = []
        gates = [g for g in m.gates if not g.bypassable and (g.openers or g.kind == "pickup")]
        while queue:
            pair = queue.pop()
            node, state = pair
            if self.touches(node, goal_cells):
                goals.append(pair)
            nexts = [(e["to"], state) for e in m.edges(node, state)]
            for g in gates:
                if g.gid not in state and self._gate_near(g, node) and m.can_open(g, node, state):
                    nexts.append((node, state | {g.gid}))
            for nxt in nexts:
                reverse.setdefault(nxt, []).append(pair)
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        good = set(goals)
        queue = list(goals)
        while queue:
            pair = queue.pop()
            for prev in reverse.get(pair, []):
                if prev not in good:
                    good.add(prev)
                    queue.append(prev)
        found = sorted((p for p in seen if p not in good), key=lambda p: (sorted(p[1]), p[0][1], p[0][0]))
        # Un error por tramo horizontal de celdas seguidas (misma fila y estado).
        groups = []
        for n, state in found:
            if groups and groups[-1][2] == state and groups[-1][0][1] == n[1] and groups[-1][1][0] + 1 == n[0]:
                groups[-1][1] = n
            else:
                groups.append([n, n, state])
        for first, last, state in groups:
            opened = ", ".join(sorted(state)) or "ninguna puerta abierta"
            cols = "columna %d" % first[0] if first == last else "columnas %d-%d" % (first[0], last[0])
            self.report.error("soft-lock: si Isak llega a la fila %d, %s no puede volver al camino de la meta (%s)"
                              % (first[1], cols, opened), first[1], first[0])
        self.result["softlocks_checked_states"] = len({state for _, state in seen})
        self._laser_info(seen)

    def finish(self):
        self.result["ok"] = not self.report.errors
        self.result["errors"] = self.report.errors
        self.result["warnings"] = self.report.warnings
        self.result["rules"] = {
            "limit": self.rules.limit,
            "jump_efficiency": self.rules.jump_efficiency,
            "jump_height_px": round(self.rules.jump_height, 1),
            "nominal_jump_height_px": round(self.rules.nominal_height, 1),
            "walk_reach_px": round(self.rules.max_reach(self.rules.walk_speed), 1),
            "run_reach_px": round(self.rules.max_reach(self.rules.run_speed), 1),
            "allow_run": self.rules.allow_run,
            "coyote_time_used": False,
            "pulse_radius_px": self.rules.pulse_radius,
            "laser_range_px": self.rules.laser_range,
            "base_pulse_radius_px": self.rules.base_pulse_radius,
            "upgrades": list(self.rules.upgrades),
        }
        gates = []
        for g in self.model.gates:
            entry = {"id": g.obj_id, "kind": g.kind, "row": g.row, "col": g.col, "bypassable": g.bypassable}
            if g.kind == "bubble":
                entry["headroom_px"] = None if g.headroom_px == INF else g.headroom_px
                entry["jump_over_px"] = round(g.jump_over_px, 1)
                entry["open"] = g.open
                entry["health"] = g.health
                entry["laser_from"] = None if g.laser_from is None else [g.laser_from[1], g.laser_from[0]]
            elif g.kind == "pickup":
                entry["ability"] = g.ability
            gates.append(entry)
        self.result["gates"] = gates
        return self.result


def validate(level, root=ROOT, limit=DEFAULT_LIMIT, jump_efficiency=DEFAULT_JUMP_EFFICIENCY, run=False,
             physics_path=None, check_schema=True, upgrades=()):
    """Valida un nivel ya cargado. Devuelve el dict de resultado (ok, errors, warnings, path, margins...)."""
    if check_schema:
        schema_errors = validate_level_schema.validate_level(level, root)
        if schema_errors:
            return {"ok": False, "errors": [{"message": "esquema: " + e, "row": None, "col": None, "object": None}
                                            for e in schema_errors], "warnings": [], "path": []}
    rules = Rules(root, physics_path, jump_efficiency, limit, run or bool(level.get("allow_run", False)),
                  tuple(upgrades))
    return Validator(level, rules).run()


def format_text(path, result):
    out = []
    status = "OK" if result["ok"] else "FALLA"
    out.append("%s: %s (%d error(es), %d aviso(s))" % (path, status, len(result["errors"]), len(result["warnings"])))
    rules = result.get("rules")
    if rules:
        out.append("  fisica: salto real %.0f px (%.0f nominal x %.2f), alcance %.0f px caminando%s; limite %.0f %%; "
                   "sin coyote time" % (rules["jump_height_px"], rules["nominal_jump_height_px"],
                                        rules["jump_efficiency"], rules["walk_reach_px"],
                                        (", %.0f corriendo" % rules["run_reach_px"]) if rules["allow_run"] else "",
                                        rules["limit"] * 100))
        out.append("  pulso: radio %.0f px (base %.0f; mejoras: %s)" % (
            rules["pulse_radius_px"], rules["base_pulse_radius_px"], ", ".join(rules["upgrades"]) or "ninguna"))
    for item in (result.get("secrets") or {}).get("items", []):
        if "requires_upgrade" in item:
            out.append("  secreto %s: sin %s %s; con ella %s (radio %.0f px)" % (
                item["id"], item["requires_upgrade"],
                "se alcanza" if item["reachable_without_upgrade"] else "no se alcanza",
                "se alcanza" if item.get("reachable_with_upgrade") else "no se alcanza",
                item.get("pulse_radius_with_upgrade_px", 0.0)))
    for item in result.get("extra_lives") or []:
        if item["behind_glitch_wall"]:
            reach = "tras una pared con glitch: sin Debug %s; con Debug %s" % (
                "se alcanza" if item["reachable_without_debug"] else "no se alcanza",
                "se alcanza" if item.get("reachable_with_debug") else "no se alcanza")
        else:
            reach = "se alcanza" if item["reachable_without_debug"] else "no se alcanza"
        out.append("  vida extra %s (fila %d, columna %d): %s; %s" % (
            item["id"], item["cell"][1], item["cell"][0], reach,
            "obligatoria" if item["mandatory"] else "opcional"))
    pulse = result.get("pulse")
    if pulse and not pulse["from_start"] and pulse["given_by"]:
        out.append("  pulso: no existe al empezar; lo da %s (desde la columna %d)" % (
            ", ".join(pulse["given_by"]), pulse.get("available_from_col", -1)))
    margins = result.get("margins")
    if margins:
        out.append("  exigencia maxima: horizontal %.1f %%, vertical %.1f %% -> margen minimo %.1f puntos "
                   "(horizontal %.1f, vertical %.1f)" % (
                       margins["max_horizontal"] * 100, margins["max_vertical"] * 100, margins["min_margin"] * 100,
                       margins["min_margin_horizontal"] * 100, margins["min_margin_vertical"] * 100))
        for key, label in (("worst_horizontal", "peor salto horizontal"), ("worst_vertical", "peor salto vertical")):
            w = margins.get(key)
            if w:
                out.append("    %s: (fila %d, columna %d) -> (fila %d, columna %d), %.0f px en el aire, sube %.0f px"
                           % (label, w["from"][0], w["from"][1], w["to"][0], w["to"][1], w["travel_px"],
                              w["rise_px"]))
    if result.get("path"):
        out.append("  camino:")
        for action in result["path"]:
            out.append("    - " + action["text"])
    for cp in result.get("checkpoints", []):
        if cp.get("reachable_from"):
            out.append("  checkpoint %s (fila %d, columna %d): alcanzable desde %s"
                       % (cp["id"], cp["row"], cp["col"], cp["reachable_from"]))
    for g in result.get("gates", []):
        if g["kind"] == "bubble":
            out.append("  Burbuja %s: %s px libres sobre la patrulla, por encima de su zona de dano recorre %.0f px "
                       "-> %s" % (g["id"], "inf" if g["headroom_px"] is None else "%.0f" % g["headroom_px"],
                                  g["jump_over_px"], "se puede saltar" if g["bypassable"] else "bloquea hasta el pulso"))
            if g.get("laser_from"):
                out.append("    vida %.0f; el laser la alcanza desde (fila %d, columna %d)"
                           % (g["health"], g["laser_from"][0], g["laser_from"][1]))
    abilities = result.get("abilities")
    if abilities:
        for item in abilities["pickups"]:
            out.append("  %s %s (fila %d, columna %d): %s; %s" % (
                item["ability"], item["id"], item["row"], item["col"],
                "se alcanza" if item["reachable"] else "NO se alcanza",
                "obligatorio (en el camino de la meta)" if item["mandatory"] else "opcional"))
        out.append("  meta sin usar el laser: %s" % ("si" if abilities["goal_without_laser"] else "no"))
    for item in result.get("exit_terminals", []):
        frm = item["pulse_from"]
        out.append("  terminal de salida %s: %s" % (
            item["id"], "se activa con el pulso desde (fila %d, columna %d)" % tuple(frm) if frm else "NO se activa"))
    for e in result["errors"]:
        out.append("  ERROR: " + e["message"])
    for w in result["warnings"]:
        out.append("  AVISO: " + w["message"])
    return "\n".join(out)


def main(argv):
    parser = argparse.ArgumentParser(description="Valida la alcanzabilidad de un nivel con la fisica de Isak.")
    parser.add_argument("levels", nargs="+")
    parser.add_argument("--json", action="store_true", help="salida JSON para maquina")
    parser.add_argument("--limit", type=float, default=DEFAULT_LIMIT,
                        help="fraccion maxima del alcance que puede exigir un salto (0.85)")
    parser.add_argument("--jump-efficiency", type=float, default=DEFAULT_JUMP_EFFICIENCY,
                        help="altura real del salto / nominal (0.92, medido a 60 Hz)")
    parser.add_argument("--run", action="store_true", help="permite saltos corriendo (run_speed)")
    parser.add_argument("--physics", default=None, help="JSON de fisica (data/isak_physics.json)")
    parser.add_argument("--upgrades", default="",
                        help="mejoras compradas (ids de data/upgrades.json separados por comas); por defecto ninguna")
    args = parser.parse_args(argv[1:])
    failed = False
    outputs = {}
    for path in args.levels:
        try:
            level = load_json(path)
            result = validate(level, limit=args.limit, jump_efficiency=args.jump_efficiency, run=args.run,
                              physics_path=args.physics,
                              upgrades=[u.strip() for u in args.upgrades.split(",") if u.strip()])
        except (OSError, ValueError, KeyError) as exc:
            print("%s: no se pudo validar (%s)" % (path, exc), file=sys.stderr)
            return 2
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
