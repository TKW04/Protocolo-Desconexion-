#!/usr/bin/env python3
"""Validador de ESQUEMA y reglas estructurales de un nivel (data/levels/<m>-<n>.json).

No comprueba alcanzabilidad (eso es tools/validate_level.py, paso 15): solo que el
archivo tenga la forma que espera el generador de niveles.

Reglas:
  - campos obligatorios y sus tipos; tile_size igual al de data/isak_physics.json;
  - grid rectangular, solo caracteres de la leyenda, al menos ceil(720 / tile_size) filas;
  - exactamente un P y un G;
  - checkpoints <-> celdas C del grid (uno a uno), enemigos <-> celdas E (uno a uno),
    secretos <-> celdas S, o {object: <tipo>} con un objeto de ese tipo en su x, y;
    requires_upgrade (si esta) es una mejora de data/upgrades.json ("pista:nivel" o legacy_id) y needs_debug un booleano;
    forbid_abilities (2026-10-20, paso 7 de docs/propuesta-1-3.md) una lista no vacia de habilidades conocidas;
    reward (opcional) es una recompensa conocida o una lista de ellas (attention_points, power_bank,
    extra_life, memory); la recompensa memory (mensaje de secreto, 2026-10-19, paso 4 de
    docs/propuesta-recuerdos.md) lleva memory_id: un mensaje (kind secret) de data/memories.json de
    ESTE nivel y ESTE secreto, con un objeto memory_pickup del nivel con ese memory_id; puede convivir
    con otra recompensa (p. ej. ["attention_points", "memory"]);
  - enemigos con tipo existente (data/enemies/<type>.json); sus params, numeros > 0 o, si el
    JSON del tipo trae level_params (punto rojo y banner, 2026-10-16), solo los listados y en su
    rango; el banner, con su pasillo dentro del grid y sin celdas solidas y un ciclo con reposo y,
    con knockback_to_entry (banner obligatorio con el dash del 1-3, 2026-10-19), techo bajo en todo
    el pasillo (sin nicho) y la celda de vuelta libre y con suelo; con rhythm, el metronomo existe y su
    ciclo mas corto deja aviso + barrido + reposo; la campana de alarma (alarm_bell) cuelga del techo,
    su onda llega al suelo sin cruzar terreno y su ciclo deja aviso + onda + reposo;
  - objects {type, x, y, params} con tipo del catalogo (data/world<N>_objects.json),
    params obligatorios presentes y sin params desconocidos, dentro del grid, y sin
    pisar terreno; params con valores de `allowed` del catalogo (ability_pickup.ability);
    encuentro con Eco (eco_encounter, 2026-10-16): como mucho uno por nivel, en un
    nivel con abilities_available.pulse false (el pulso lo da el encuentro) y con
    Eco (eco_offset_tiles, dos enteros) dentro de la zona y en una celda libre;
    cargador (charger) con amount > 0, cooldown_s >= 0 y reusable booleano;
    vida extra (extra_life_pickup, 2026-10-16): como mucho una por nivel (se coge
    una vez por mapa) y secret_id (id del registro) un texto no vacio;
    mensaje de secreto (memory_pickup, 2026-10-19): memory_id de un mensaje (kind secret) de
    data/memories.json, uno por memory_id en el nivel y ofrecido por un secreto (recompensa memory);
    receptores apuntando a un puente existente; la puerta de salida contiene la G;
    objetos con level_params en el catalogo (2026-10-16: recordatorio, Posponer, pop-up
    translucido, barra del 99 %): params numericos en su rango; recordatorio con group y
    warn_s < timer_s; Posponer con targets = grupos de recordatorios existentes y
    cap_s >= extend_s; pop-up translucido con el boton dentro de la ventana (un ad_cover
    puede taparlo); barra del 99 % con zone dentro del grid y oleadas {t, type, x, params}
    validas (t entre el aviso y wait_s, type de wave_types, x en la zona, params del enemigo);
  - ids unicos (checkpoints, enemigos, secretos y params.id de los objetos);
  - sin pinchos en P ni en C ni en las 8 celdas vecinas de una C;
  - tramos (sections, opcional): {name, x_from, x_to, y_from, y_to, patterns}; x e y
    son opcionales (por defecto todo el ancho / todo el alto; y_from e y_to van juntos)
    y dentro del grid; los rectangulos no se solapan; sin y (niveles horizontales, como
    el 1-1) van ademas de izquierda a derecha; patterns es una lista de textos
    (lenguaje de combinaciones de docs/propuesta-1-2.md §0). Niveles verticales
    (2026-10-16, paso 1 de docs/propuesta-1-2.md §10): el grid admite cualquier alto
    (minimo ceil(720 / tile_size) filas; la torre del 1-2 tiene 62);
  - camara (camera, opcional): {vertical: "simple" | "tower" | "autoscroll", limits: "grid"};
  - scroll forzado (scroll, solo con camera.vertical "autoscroll", 2026-10-22, paso 2 de
    docs/propuesta-mundo-2.md §8): ancho 20, arranque, tramos de velocidad, paradas, inversiones y
    tarjetas seguras (ver _check_scroll);
  - gasto del Debug del nivel (debug_drain_scale, opcional, 2026-10-21): numero entre 0 y 1 que
    multiplica el gasto del Debug en ese nivel (por defecto 1; la arena de Alerta Mayor, 0,5);
  - escala del mundo con el Debug del nivel (debug_world_scale, opcional, 2026-10-21): numero entre 0 y 1
    que sustituye a la global (0,5) en ese nivel (la arena de Alerta Mayor, 0,7); sin el campo, la global;
  - parametros de validacion (validation, opcional, paso 10): {time_margin_s, snooze_required,
    laser_required, debug_required, start_energy, sync_damage_budget, ceiling_margin_px,
    dash_required, hazard_margin_s} (ver
    _check_validation);
  - arena de jefe (kind "boss", 2026-10-21, paso 5 de docs/propuesta-jefe-alerta-mayor.md §6): id
    <mundo>-boss, boss = id de data/bosses/<boss>.json con un objeto de ese tipo en el nivel, SIN meta G
    (la pelea termina con el golpe final); objetos y enemigos pueden llevar active_in_phase (lista de
    fases 1..n del jefe: inactivos hasta esas fases) y una plataforma que parpadea con active_in_phase
    puede reemplazar celdas '-' del grid (el jefe las borra al activarla); fuera de una arena,
    active_in_phase es un error;
  - id: <mundo>-<nivel> o, para un nivel de prueba que no es del juego, <nombre>_test
    (p. ej. tower_test; su escena es scenes/levels/<nombre>_test.tscn);
    un nivel de prueba puede llevar stands_for «W-N» (2026-10-20): hace las veces de ese subnivel
    para los mensajes de secreto (el memory_id de su recompensa memory es de ese nivel);
  - ayuda de Eco con Q: todo help_id (del tipo en el catalogo, del enemigo en
    data/enemies/<type>.json o propio de un objeto, enemigo o checkpoint del
    nivel; "" = sin Q) existe en data/help.json.

Uso: python3 tools/validate_level_schema.py data/levels/1-1.json [...]
Sale con 0 si todo esta bien y 1 si hay errores (con fila/columna cuando aplica).
"""

import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import upgrade_catalog  # noqa: E402
import level_catalog  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRID_CHARS = set("#.^-hPGCoES")
SCREEN_HEIGHT_PX = 720
REQUIRED_FIELDS = {
    "id": str,
    "name": str,
    "world": int,
    "tile_size": int,
    "debug_color": str,
    "grid": list,
    "checkpoints": list,
    "secrets": list,
    "enemies": list,
    "objects": list,
    "unlocks": list,
}
KNOWN_ABILITIES = {"pulse", "debug", "laser", "dash", "ground_pound"}
# Modos de camara (camera.vertical): simple = Camera2D de Isak con suavizado (1-1);
# tower = camara de torre (scripts/player/tower_camera.gd, data/camera_tower.json).
# autoscroll = scroll forzado del Mundo 2 (2026-10-22; scripts/player/scroll_camera.gd,
# data/camera_scroll.json y la seccion scroll del nivel; ver _check_scroll).
CAMERA_VERTICAL_MODES = ("simple", "tower", "autoscroll")
# Scroll forzado: ancho del nivel (la camara no se mueve en horizontal), velocidades y
# distancia maxima en filas entre tarjetas seguras (docs/propuesta-mundo-2.md §3.1-§3.2).
AUTOSCROLL_WIDTH_TILES = 20
SCROLL_SPEED_RANGE = (0.2, 1.5)
SCROLL_SAFE_GAP_ROWS = 6
SCROLL_KEYS = ("start_resume_row", "start_bottom_row", "default_speed_tiles_s", "stages", "stops", "reverses",
               "safe_respawn")
CAMERA_LIMITS = ("grid",)
# Nivel de prueba (no es del juego, no se enlaza desde el hub): <nombre>_test.
TEST_LEVEL_ID = re.compile(r"[a-z][a-z0-9_]*_test")
# Objetos que ocupan celdas que el grid debe dejar vacias ('.'): son solidos o lo seran.
BLOCKING_TYPES = {"bridge_inactive", "glitch_wall", "popup_blocker", "reminder_platform", "update_bar",
                  "blink_platform"}
# Objetos que no pueden estar dentro de terreno solido ni de pinchos.
NON_SOLID_PLACED = {"receiver", "exit_door", "exit_terminal", "charger", "ability_pickup", "extra_life_pickup",
                    "memory_pickup",
                    "laser_receiver", "relay_receiver", "snooze_button", "power_switch", "debug_switch",
                    "laser_switch", "charge_dock", "calc_actor", "dnd_switch", "exceptions_panel", "boss_dummy",
                    "alert_major"}
# Arena de jefe (kind "boss", 2026-10-21): id <mundo>-boss y tamano del jefe Alerta Mayor en tiles
# (cuerpo inflado arriba, 4 x 4 desde su celda).
LEVEL_KINDS = ("level", "boss")
BOSS_LEVEL_ID = re.compile(r"\d+-boss")
BOSS_FOOTPRINT_TILES = {"alert_major": (4, 4)}
# Acertijo de la azotea del 1-2 (encuentro con Calc, 2026-10-17, tanda H1 del paso 14):
# interruptores (piezas que se «hacen»), punto de carga de 2x1 y acciones del guion de Eco.
SWITCH_TYPES = ("power_switch", "debug_switch", "laser_switch")
CALC_PIECE_TYPES = SWITCH_TYPES + ("glitch_wall", "charge_dock", "calc_actor", "dark_room", "exit_terminal")
GUIDE_ACTIONS = {"wait_near": ("object",), "wait_inside": ("object",), "wait_done": ("object",),
                 "wait_ability": ("ability",), "wait_s": ("seconds",), "wait_quiet": (), "fly": (), "back": (),
                 "line": ("text",),
                 "point_help": ("object", "text")}
GUIDE_ABILITIES = ("pulse", "laser", "debug")
DOOR_MAX_LAMPS = 3
# Recompensas de un secreto (campo reward: una o una lista). memory = mensaje de secreto
# (memory_pickup; docs/propuesta-recuerdos.md §7 paso 4), con memory_id.
SECRET_REWARDS = ("attention_points", "power_bank", "extra_life", "memory")
MEMORIES_JSON = os.path.join("data", "memories.json")
# Metronomos (2026-10-19, pasos 5 y 6 de docs/propuesta-1-3.md): rhythm_zone y alarm_tunnel; ciclo
# admitido (s).
RHYTHM_TYPES = ("rhythm_zone", "alarm_tunnel")
RHYTHM_CYCLE_S = (0.5, 12.0)
# Barra del 99 % (2026-10-16): puerta de 1 x 3 tiles; aviso de cada caida = 9 cuadros a 12 fps.
UPDATE_BAR_HEIGHT = 3
UPDATE_BAR_WARN_S = 9 / 12.0


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value):
    return (isinstance(value, (int, float))) and not isinstance(value, bool)


class LevelValidator:
    def __init__(self, level, root=ROOT):
        self.level = level
        self.root = root
        self.errors = []
        self.grid = []
        self.width = 0
        self.height = 0
        self.ids = {}
        self.object_anchors = set()

    def error(self, message, row=None, col=None):
        if row is not None and col is not None:
            message = "fila %d, columna %d: %s" % (row, col, message)
        self.errors.append(message)

    def cell(self, x, y):
        return self.grid[y][x]

    def in_bounds(self, x, y):
        return 0 <= x < self.width and 0 <= y < self.height

    # --- Carga de datos auxiliares ---

    def _load_json(self, rel_path):
        path = os.path.join(self.root, rel_path)
        try:
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, ValueError) as exc:
            self.error("no se pudo leer %s (%s)" % (rel_path, exc))
            return None

    def _load_catalog(self):
        """Catalogo del mundo del nivel (desde el Mundo 2, con los tipos del Mundo 1; tools/level_catalog.py)."""
        try:
            return level_catalog.load_catalog(self.root, self.level["world"])
        except (OSError, ValueError) as exc:
            self.error("no se pudo leer el catalogo de objetos del mundo %s (%s)" % (self.level.get("world"), exc))
            return None

    # --- Reglas ---

    def validate(self):
        if not isinstance(self.level, dict):
            self.error("el nivel debe ser un objeto JSON")
            return self.errors
        self._check_fields()
        if self.errors:
            return self.errors
        self._check_grid()
        if self.errors:
            return self.errors
        self._check_markers()
        self._check_checkpoints()
        self._check_enemies()
        self._check_objects()
        self._check_secrets()
        self._check_spikes()
        self._check_unlocks()
        self._check_sections()
        self._check_camera()
        self._check_scroll()
        self._check_validation()
        self._check_help()
        return self.errors

    def _check_help(self):
        help_path = os.path.join(self.root, "data", "help.json")
        if not os.path.exists(help_path):
            return
        known = set((self._load_json("data/help.json") or {}).get("types", {}))
        catalog = self._load_catalog() or {}
        used = []
        types = catalog.get("types", {})
        for i, obj in enumerate(self.level["objects"]):
            if isinstance(obj, dict):
                default = types.get(obj.get("type"), {}).get("help_id")
                used.append(("objects[%d]" % i, obj.get("help_id", default)))
        for enemy in self.level["enemies"]:
            if isinstance(enemy, dict) and isinstance(enemy.get("type"), str):
                path = os.path.join(self.root, "data", "enemies", "%s.json" % enemy["type"])
                default = None
                if os.path.exists(path):
                    default = (self._load_json("data/enemies/%s.json" % enemy["type"]) or {}).get("help_id")
                used.append(("enemigo %s" % enemy.get("id"), enemy.get("help_id", default)))
        for cp in self.level["checkpoints"]:
            if isinstance(cp, dict):
                used.append(("checkpoint %s" % cp.get("id"), cp.get("help_id",
                             catalog.get("checkpoint", {}).get("help_id"))))
        if self._cells_with("o"):
            used.append(("puntos de atencion", catalog.get("attention_point", {}).get("help_id")))
        for what, help_id in used:
            if help_id in (None, ""):
                continue
            if not isinstance(help_id, str) or help_id not in known:
                self.error("%s: help_id '%s' no esta en data/help.json" % (what, help_id))

    def _check_fields(self):
        for key, kind in REQUIRED_FIELDS.items():
            if key not in self.level:
                self.error("falta el campo obligatorio '%s'" % key)
            elif kind is int and not _is_int(self.level[key]):
                self.error("'%s' debe ser un entero" % key)
            elif kind is not int and not isinstance(self.level[key], kind):
                self.error("'%s' debe ser de tipo %s" % (key, kind.__name__))
        if self.errors:
            return
        kind = self.level.get("kind", "level")
        if kind not in LEVEL_KINDS:
            self.error("'kind' debe ser uno de %s" % ", ".join(LEVEL_KINDS))
            return
        if kind == "boss":
            self._check_boss_fields()
        elif "boss" in self.level:
            self.error("'boss' solo vale en una arena de jefe (kind \"boss\")")
        if TEST_LEVEL_ID.fullmatch(self.level["id"]):
            pass  # nivel de prueba: el mundo sale de 'world'
        elif kind == "boss" and BOSS_LEVEL_ID.fullmatch(self.level["id"]):
            if int(self.level["id"].split("-")[0]) != self.level["world"]:
                self.error("'id' (%s) no coincide con 'world' (%d)" % (self.level["id"], self.level["world"]))
        elif kind == "boss":
            self.error("'id' de una arena de jefe debe ser <mundo>-boss (p. ej. 1-boss) o <nombre>_test")
        elif not re.fullmatch(r"\d+-\d+", self.level["id"]):
            self.error("'id' debe tener la forma <mundo>-<nivel> (p. ej. 1-1) o <nombre>_test (nivel de prueba)")
        elif int(self.level["id"].split("-")[0]) != self.level["world"]:
            self.error("'id' (%s) no coincide con 'world' (%d)" % (self.level["id"], self.level["world"]))
        physics = self._load_json("data/isak_physics.json")
        if physics is not None and self.level["tile_size"] != int(physics.get("tile_size", 0)):
            self.error("tile_size %d distinto del de data/isak_physics.json (%s)"
                       % (self.level["tile_size"], physics.get("tile_size")))
        abilities = self.level.get("abilities_available", {})
        if not isinstance(abilities, dict):
            self.error("'abilities_available' debe ser un objeto {habilidad: bool}")
        else:
            for name, value in abilities.items():
                if name not in KNOWN_ABILITIES:
                    self.error("habilidad desconocida en abilities_available: '%s'" % name)
                elif not isinstance(value, bool):
                    self.error("abilities_available.%s debe ser true o false" % name)
        if "debug_drain_scale" in self.level:
            # Gasto del Debug por nivel (2026-10-21, paso 4 de docs/propuesta-jefe-alerta-mayor.md §6):
            # multiplica DebugMode.get_drain_per_second() en este nivel (arena del jefe: 0,5).
            scale = self.level["debug_drain_scale"]
            if not _is_number(scale) or not 0.0 <= scale <= 1.0:
                self.error("'debug_drain_scale' debe ser un numero entre 0 y 1 (1 = gasto normal)")
        if "debug_world_scale" in self.level:
            # Escala del mundo con el Debug por nivel (2026-10-21, docs/propuesta-jefe-alerta-mayor.md §6.4):
            # sustituye a world_time_scale de data/debug_mode.json en este nivel (arena del jefe: 0,7).
            scale = self.level["debug_world_scale"]
            if not _is_number(scale) or not 0.0 < scale <= 1.0:
                self.error("'debug_world_scale' debe ser un numero mayor que 0 y como mucho 1 (1 = sin ralentizar)")
        if "stands_for" in self.level:
            # Sala de prueba que hace las veces de un subnivel (2026-10-20, paso 7 de
            # docs/propuesta-1-3.md: la sala «Excepciones» ofrece msg_1_3 del 1-3).
            target = self.level["stands_for"]
            if not TEST_LEVEL_ID.fullmatch(self.level["id"]):
                self.error("'stands_for' solo vale en un nivel de prueba (<nombre>_test)")
            elif not (isinstance(target, str) and re.fullmatch(r"\d+-\d+", target)):
                self.error("'stands_for' debe ser un subnivel <mundo>-<nivel> (p. ej. 1-3)")
            elif int(target.split("-")[0]) != self.level["world"]:
                self.error("'stands_for' (%s) no es del mundo %d" % (target, self.level["world"]))

    def is_boss_arena(self):
        return self.level.get("kind") == "boss"

    def _check_boss_fields(self):
        """Arena de jefe: boss es el id de data/bosses/<boss>.json."""
        boss = self.level.get("boss")
        if not isinstance(boss, str) or not boss:
            self.error("una arena de jefe necesita 'boss' (id de data/bosses/<boss>.json)")
        elif not os.path.isfile(os.path.join(self.root, "data", "bosses", "%s.json" % boss)):
            self.error("'boss' '%s' sin data/bosses/%s.json" % (boss, boss))

    def _boss_phase_count(self):
        """Fases del jefe de la arena (las de la vuelta 1 de su JSON; 3 por defecto)."""
        boss = self.level.get("boss")
        data = None
        if isinstance(boss, str) and os.path.isfile(os.path.join(self.root, "data", "bosses", "%s.json" % boss)):
            data = self._load_json("data/bosses/%s.json" % boss)
        laps = (data or {}).get("laps", {})
        counts = [len(e.get("hits_per_phase", [])) for e in laps.values() if isinstance(e, dict)]
        return max(counts) if counts else 3

    def _check_active_in_phase(self, entry, what, x=None, y=None):
        """active_in_phase (arena de jefe): lista no vacia de fases 1..n sin repetir."""
        if "active_in_phase" not in entry:
            return
        if not self.is_boss_arena():
            self.error("%s: active_in_phase solo vale en una arena de jefe (kind \"boss\")" % what, y, x)
            return
        phases = entry["active_in_phase"]
        n = self._boss_phase_count()
        if not (isinstance(phases, list) and phases and all(_is_int(p) and 1 <= p <= n for p in phases)
                and len(set(phases)) == len(phases)):
            self.error("%s: active_in_phase debe ser una lista de fases distintas entre 1 y %d" % (what, n), y, x)

    def _check_grid(self):
        grid = self.level["grid"]
        if not grid or not all(isinstance(row, str) for row in grid):
            self.error("'grid' debe ser una lista no vacia de cadenas")
            return
        self.grid = grid
        self.height = len(grid)
        self.width = len(grid[0])
        for y, row in enumerate(grid):
            if len(row) != self.width:
                self.error("la fila mide %d y la primera %d (grid no rectangular)"
                           % (len(row), self.width), y, min(len(row), self.width) - 1)
            for x, char in enumerate(row):
                if char not in GRID_CHARS:
                    self.error("caracter no valido '%s'" % char, y, x)
        min_rows = math.ceil(SCREEN_HEIGHT_PX / self.level["tile_size"])
        if self.height < min_rows:
            self.error("el grid tiene %d filas; hacen falta al menos %d para %d px de alto"
                       % (self.height, min_rows, SCREEN_HEIGHT_PX))

    def _cells_with(self, char):
        return [(x, y) for y, row in enumerate(self.grid) for x, c in enumerate(row) if c == char]

    def _check_markers(self):
        if self.is_boss_arena():
            # La pelea termina con el golpe final: la arena no tiene meta.
            for (x, y) in self._cells_with("G"):
                self.error("una arena de jefe no tiene meta G (la pelea acaba con el golpe final)", y, x)
        for char, name in (("P", "inicio (P)"), ("G", "meta (G)")):
            if char == "G" and self.is_boss_arena():
                continue
            cells = self._cells_with(char)
            if len(cells) != 1:
                where = ", ".join("fila %d columna %d" % (y, x) for x, y in cells) or "ninguno"
                self.error("debe haber exactamente un %s y hay %d (%s)" % (name, len(cells), where))

    def _register_id(self, ident, what):
        if not isinstance(ident, str) or not ident:
            self.error("%s sin 'id' de texto" % what)
            return
        if ident in self.ids:
            self.error("id duplicado '%s' (%s y %s)" % (ident, self.ids[ident], what))
        else:
            self.ids[ident] = what

    def _check_point_entry(self, entry, what):
        """Comprueba {id, x, y} y devuelve (x, y) o None."""
        if not isinstance(entry, dict):
            self.error("%s debe ser un objeto" % what)
            return None
        self._register_id(entry.get("id"), what)
        x, y = entry.get("x"), entry.get("y")
        if not (_is_int(x) and _is_int(y)):
            self.error("%s '%s' necesita x e y enteros" % (what, entry.get("id")))
            return None
        if not self.in_bounds(x, y):
            self.error("%s '%s' fuera del grid" % (what, entry.get("id")), y, x)
            return None
        return (x, y)

    def _check_paired(self, entries, char, what):
        listed = set()
        for i, entry in enumerate(entries):
            pos = self._check_point_entry(entry, "%s %d" % (what, i))
            if pos is None:
                continue
            listed.add(pos)
            if self.cell(*pos) != char:
                self.error("%s '%s' no esta sobre una celda '%s' (hay '%s')"
                           % (what, entry.get("id"), char, self.cell(*pos)), pos[1], pos[0])
        for (x, y) in self._cells_with(char):
            if (x, y) not in listed:
                self.error("celda '%s' sin entrada en la lista de %s" % (char, what), y, x)

    def _check_checkpoints(self):
        self._check_paired(self.level["checkpoints"], "C", "checkpoints")

    def _check_enemies(self):
        self._check_paired(self.level["enemies"], "E", "enemies")
        for entry in self.level["enemies"]:
            if not isinstance(entry, dict):
                continue
            kind = entry.get("type")
            if not isinstance(kind, str) or not os.path.isfile(
                    os.path.join(self.root, "data", "enemies", "%s.json" % kind)):
                self.error("enemigo '%s': tipo '%s' sin data/enemies/%s.json"
                           % (entry.get("id"), kind, kind))
            if "open" in entry and not isinstance(entry["open"], bool):
                self.error("enemigo '%s': open debe ser booleano" % entry.get("id"))
            self._check_active_in_phase(entry, "enemigo '%s'" % entry.get("id"), entry.get("x"), entry.get("y"))
            params = entry.get("params", {})
            if not isinstance(params, dict):
                self.error("enemigo '%s': 'params' debe ser un objeto" % entry.get("id"))
                continue
            data = None
            if isinstance(kind, str) and os.path.isfile(os.path.join(self.root, "data", "enemies", "%s.json" % kind)):
                data = self._load_json("data/enemies/%s.json" % kind)
            spec = data.get("level_params") if isinstance(data, dict) else None
            if isinstance(spec, dict):
                self._check_enemy_params(entry, params, spec)
            else:
                for key, value in params.items():
                    if not _is_number(value) or value <= 0:
                        self.error("enemigo '%s': params.%s debe ser un numero > 0" % (entry.get("id"), key))
            if kind == "spam_banner" and isinstance(data, dict):
                self._check_banner(entry, params, data)
            if kind == "alarm_bell" and isinstance(data, dict):
                self._check_bell(entry, params, data)

    def _check_enemy_params(self, entry, params, spec):
        """Params por instancia segun level_params del JSON del enemigo (2026-10-16: punto rojo y
        banner): solo los listados, numericos, en [min, max], enteros si int, o en values."""
        eid = entry.get("id")
        for key, value in params.items():
            rule = spec.get(key)
            if key.startswith("_") or not isinstance(rule, dict):
                self.error("enemigo '%s': params.%s no existe para %s (admite: %s)"
                           % (eid, key, entry.get("type"), ", ".join(k for k in sorted(spec) if not k.startswith("_"))))
                continue
            if rule.get("bool"):
                if not isinstance(value, bool):
                    self.error("enemigo '%s': params.%s debe ser true o false" % (eid, key))
                continue
            if rule.get("string"):
                if not isinstance(value, str):
                    self.error("enemigo '%s': params.%s debe ser un texto" % (eid, key))
                continue
            if not _is_number(value):
                self.error("enemigo '%s': params.%s debe ser un numero" % (eid, key))
                continue
            if rule.get("int") and not _is_int(value):
                self.error("enemigo '%s': params.%s debe ser un entero" % (eid, key))
            if "values" in rule and value not in rule["values"]:
                self.error("enemigo '%s': params.%s debe ser uno de %s" % (eid, key, rule["values"]))
            if "min" in rule and value < rule["min"] or "max" in rule and value > rule["max"]:
                self.error("enemigo '%s': params.%s = %s fuera de [%s, %s]"
                           % (eid, key, value, rule.get("min"), rule.get("max")))

    def _check_banner(self, entry, params, data):
        """Banner: el pasillo (corridor_tiles celdas desde la E hacia direction) cabe en el grid sin
        celdas solidas, y el ciclo deja reposo: interval_s >= aviso + barrido + min_rest_s."""
        eid = entry.get("id")
        x, y = entry.get("x"), entry.get("y")
        if not (_is_int(x) and _is_int(y)):
            return
        get = lambda k: params.get(k, data.get(k))  # noqa: E731
        tiles, direction = get("corridor_tiles"), get("direction")
        if not (_is_int(tiles) and direction in (-1, 1)):
            return
        for i in range(int(tiles)):
            cx = x + direction * i
            if not self.in_bounds(cx, y):
                self.error("banner '%s': el pasillo (%d celdas) sale del grid" % (eid, tiles), y, cx)
                break
            if self.cell(cx, y) == "#":
                self.error("banner '%s': celda solida dentro de su pasillo" % eid, y, cx)
                break
        try:
            tile = float(self.level.get("tile_size", 64))
            warn = float(data["anticipation_frames"]) / float(data["anim_fps"])
            sweep = (tiles * tile - float(data["banner_size"][0])) / float(get("sweep_speed_px_s"))
            if sweep <= 0:
                self.error("banner '%s': el pasillo debe ser mas ancho que el banner" % eid)
            elif self._rhythm_rest(eid, get("rhythm"), warn + sweep + float(data.get("min_rest_s", 0.0)),
                                   "aviso + barrido + reposo minimo"):
                pass
            elif float(get("interval_s")) < warn + sweep + float(data.get("min_rest_s", 0.0)):
                self.error("banner '%s': interval_s %.2f menor que aviso + barrido + reposo minimo (%.2f s)"
                           % (eid, float(get("interval_s")), warn + sweep + float(data.get("min_rest_s", 0.0))))
        except (KeyError, TypeError, ValueError, ZeroDivisionError):
            self.error("banner '%s': datos del banner incompletos" % eid)
        if get("knockback_to_entry") is True:
            self._check_banner_dash(eid, x, y, int(tiles), direction)

    def _rhythm_rest(self, eid, rid, need, what):
        """Con `rhythm` (banner o campana del 1-3, 2026-10-19): el metronomo existe y su ciclo mas corto
        deja `need` s (aviso + barrido/onda + reposo minimo). Verdadero si hay rhythm (ya comprobado)."""
        if rid in (None, ""):
            return False
        rhythms = self._rhythms() if isinstance(self.level.get("objects"), list) else {}
        if rid not in rhythms:
            self.error("enemigo '%s': rhythm '%s' no es el id de ningun %s" % (eid, rid, " ni ".join(RHYTHM_TYPES)))
            return True
        shortest = rhythms[rid][2]
        if shortest is not None and shortest < need - 1e-9:
            self.error("enemigo '%s': el ciclo mas corto de %s (%.2f s) es menor que %s (%.2f s)"
                       % (eid, rid, shortest, what, need))
        return True

    def _check_bell(self, entry, params, data):
        """Campana de alarma (alarm_bell, 2026-10-19, paso 6 de docs/propuesta-1-3.md §5.5): colgada del
        techo (la celda de encima solida), la onda de wave_tiles celdas sin terreno solido hasta el suelo
        (la celda siguiente solida) y un ciclo con reposo (el de su rhythm o interval_s >= aviso + onda +
        min_rest_s)."""
        eid = entry.get("id")
        x, y = entry.get("x"), entry.get("y")
        if not (_is_int(x) and _is_int(y)):
            return
        get = lambda k: params.get(k, data.get(k))  # noqa: E731
        tiles = get("wave_tiles")
        if not _is_int(tiles) or tiles < 1:
            return
        if not self.in_bounds(x, y - 1) or self.cell(x, y - 1) != "#":
            self.error("campana '%s': debe colgar del techo (la celda de encima solida)" % eid, y, x)
        for j in range(tiles):
            if not self.in_bounds(x, y + j) or self.cell(x, y + j) == "#":
                self.error("campana '%s': la onda (%d celdas) cruza terreno solido o sale del grid" % (eid, tiles),
                           y + j, x)
                return
        if not self.in_bounds(x, y + tiles) or self.cell(x, y + tiles) != "#":
            self.error("campana '%s': la onda debe llegar al suelo (la celda tras sus %d celdas, solida)"
                       % (eid, tiles), y + tiles, x)
        try:
            need = float(data["anticipation_frames"]) / float(data["anim_fps"]) + float(get("wave_s")) \
                + float(data.get("min_rest_s", 0.0))
        except (KeyError, TypeError, ValueError, ZeroDivisionError):
            self.error("campana '%s': datos de la campana incompletos" % eid)
            return
        if not self._rhythm_rest(eid, get("rhythm"), need, "aviso + onda + reposo minimo") \
                and float(get("interval_s")) < need - 1e-9:
            self.error("campana '%s': interval_s %.2f menor que aviso + onda + reposo minimo (%.2f s)"
                       % (eid, float(get("interval_s")), need))

    def _check_banner_dash(self, eid, x, y, tiles, direction):
        """Banner obligatorio con el dash (knockback_to_entry, 2026-10-19, paso 4 de
        docs/propuesta-1-3.md §5.2): techo bajo en todo el pasillo (2 filas libres: la de encima de
        Isak libre y la siguiente solida; no hay salto ni nicho) y la celda de vuelta (la siguiente al
        final del barrido) libre, con suelo y con sitio para Isak."""
        for i in range(tiles):
            cx = x + direction * i
            if not self.in_bounds(cx, y - 2):
                return
            if self.cell(cx, y - 1) not in ".oE" or self.cell(cx, y - 2) != "#":
                self.error("banner '%s' (knockback_to_entry): el pasillo debe tener techo bajo en todo su largo "
                           "(2 filas libres y la de encima solida; sin nicho)" % eid, y - 1, cx)
                return
        rx = x + direction * tiles
        if not (self.in_bounds(rx, y + 1) and self.in_bounds(rx, y - 1)) or self.cell(rx, y) in "#^" \
                or self.cell(rx, y - 1) in "#^" or self.cell(rx, y + 1) not in "#-":
            self.error("banner '%s' (knockback_to_entry): la entrada del pasillo (la celda de vuelta) debe estar "
                       "libre, con suelo y con sitio para Isak" % eid, y, rx)

    def _footprint(self, kind, x, y, params, defaults):
        def get(name, fallback):
            return params.get(name, defaults.get(name, fallback))
        if kind == "bridge_inactive":
            length = get("length_tiles", 1)
            step = -1 if get("direction", "right") == "left" else 1
            if not _is_int(length) or length < 1:
                return None
            return [(x + step * i, y) for i in range(length)]
        if kind in ("receiver", "snooze_button"):
            return [(x, y)]
        if kind in ("reminder_platform", "blink_platform"):
            w = get("width_tiles", 1)
            if not _is_int(w) or w < 1:
                return None
            return [(x + i, y) for i in range(w)]
        if kind == "update_bar":
            return [(x, y + j) for j in range(UPDATE_BAR_HEIGHT)]
        if kind == "charge_dock":
            return [(x, y), (x + 1, y)]
        if kind in BOSS_FOOTPRINT_TILES:
            w, h = BOSS_FOOTPRINT_TILES[kind]
            return [(x + i, y + j) for j in range(h) for i in range(w)]
        if kind == "boss_dummy":
            # Jefe «saco» de boss_test (paso 3 de docs/propuesta-jefe-alerta-mayor.md): 2 x 2 tiles
            # apoyado en (x, y): columnas x y x+1, filas y-1 e y.
            return [(x + i, y - j) for j in range(2) for i in range(2)]
        if kind in ("power_switch", "debug_switch", "laser_switch", "calc_actor", "eco_guide", "dnd_switch"):
            return [(x, y)]
        w, h = get("width_tiles", 1), get("height_tiles", 1)
        if not (_is_int(w) and _is_int(h)) or w < 1 or h < 1:
            return None
        return [(x + i, y + j) for j in range(h) for i in range(w)]

    def _check_objects(self):
        catalog = self._load_catalog()
        if catalog is None:
            return
        types = catalog.get("types", {})
        bridges = set()
        receivers = []
        # Enlaces del acertijo del laser (2026-10-16, paso 3 de docs/propuesta-1-2.md §10):
        # laser_receiver -> relay_receiver -> bridge_inactive y ad_cover -> popup_blocker.
        relays = set()
        popups = {}
        # Recordatorios y Posponer (2026-10-16, paso 6): grupos de recordatorios enlazados.
        reminder_groups = set()
        snoozes = []
        links = []
        doors = []
        encounters = []
        extra_lives = []
        self.memory_pickups = {}
        self.object_anchors = set()
        for i, obj in enumerate(self.level["objects"]):
            what = "objects[%d]" % i
            if not isinstance(obj, dict):
                self.error("%s debe ser un objeto {type, x, y, params}" % what)
                continue
            missing = [k for k in ("type", "x", "y", "params") if k not in obj]
            if missing:
                self.error("%s: faltan %s" % (what, ", ".join(missing)))
                continue
            kind, x, y, params = obj["type"], obj["x"], obj["y"], obj["params"]
            if kind not in types:
                self.error("%s: tipo '%s' no esta en data/world%d_objects.json" % (what, kind, self.level["world"]))
                continue
            what = "%s (%s)" % (what, kind)
            if not (_is_int(x) and _is_int(y)):
                self.error("%s: x e y deben ser enteros" % what)
                continue
            if not isinstance(params, dict):
                self.error("%s: 'params' debe ser un objeto" % what)
                continue
            if not self.in_bounds(x, y):
                self.error("%s fuera del grid" % what, y, x)
                continue
            entry = types[kind]
            for field in entry.get("required", []):
                if field not in params:
                    self.error("%s: falta el param obligatorio '%s'" % (what, field), y, x)
            for field in params:
                if field not in entry.get("fields", {}):
                    self.error("%s: param desconocido '%s'" % (what, field), y, x)
            for field in ("text",):
                if field in params and (not isinstance(params[field], str) or not params[field].strip()):
                    self.error("%s: '%s' debe ser un texto no vacio" % (what, field), y, x)
            for field, allowed in entry.get("allowed", {}).items():
                if field in params and params[field] not in allowed:
                    self.error("%s: %s '%s' no admitido (validos: %s)"
                               % (what, field, params[field], ", ".join(allowed)), y, x)
            if kind == "charger":
                self._check_charger(what, x, y, params)
            if kind == "glitch_wall" and not isinstance(params.get("visible_only_with_debug", False), bool):
                self.error("%s: visible_only_with_debug debe ser true o false" % what, y, x)
            if kind == "glitch_wall" and "cover" in params:
                self._check_glitch_cover(what, x, y, params["cover"])
            if kind == "exceptions_panel":
                self._check_exceptions_panel(what, x, y, params)
            if kind == "boss_dummy":
                for cx in (x, x + 1):
                    if not self.in_bounds(cx, y + 1) or self.cell(cx, y + 1) != "#":
                        self.error("%s: necesita suelo solido bajo sus dos columnas (fila %d)" % (what, y + 1), y + 1, cx)
            if isinstance(entry.get("level_params"), dict):
                self._check_object_params(what, x, y, params, entry["level_params"])
            self._check_active_in_phase(obj, what, x, y)
            if kind in BOSS_FOOTPRINT_TILES and (not self.is_boss_arena() or self.level.get("boss") != kind):
                self.error("%s: el jefe solo va en su arena (kind \"boss\" con boss \"%s\")" % (what, kind), y, x)
            self.object_anchors.add((kind, (x, y)))
            if "id" in params:
                self._register_id(params["id"], what)
            cells = self._footprint(kind, x, y, params, entry.get("defaults", {}))
            if cells is None:
                self.error("%s: tamano no valido (width/height/length deben ser enteros >= 1)" % what, y, x)
                continue
            for (cx, cy) in cells:
                if not self.in_bounds(cx, cy):
                    self.error("%s: se sale del grid" % what, cy, cx)
                    break
                char = self.cell(cx, cy)
                replaces = kind == "blink_platform" and char == "-" and "active_in_phase" in obj \
                    and self.is_boss_arena()
                if kind in BLOCKING_TYPES and char != "." and not replaces:
                    self.error("%s ocupa una celda que el grid debe dejar vacia ('.'), hay '%s'"
                               % (what, char), cy, cx)
                elif kind in NON_SOLID_PLACED and char in "#^":
                    self.error("%s dentro de terreno o pinchos ('%s')" % (what, char), cy, cx)
            if kind == "bridge_inactive":
                if params.get("direction", "right") not in ("left", "right"):
                    self.error("%s: direction debe ser 'left' o 'right'" % what, y, x)
                bridges.add(params.get("id"))
            elif kind == "receiver":
                receivers.append((what, x, y, params.get("target")))
            elif kind == "relay_receiver":
                relays.add(params.get("id"))
                receivers.append((what, x, y, params.get("target")))
            elif kind == "laser_receiver":
                links.append((what, x, y, params.get("target"), "relay_receiver"))
                self._check_laser_receiver(what, x, y, params)
            elif kind == "ad_cover":
                links.append((what, x, y, params.get("target"), "popup_blocker"))
            elif kind == "popup_blocker":
                popups[params.get("id")] = (x, y, params)
            elif kind == "overlay_popup":
                popups[params.get("id")] = (x, y, params)
                self._check_overlay(what, x, y, params, entry.get("defaults", {}))
            elif kind == "reminder_platform":
                group = params.get("group")
                if not isinstance(group, str) or not group.strip():
                    self.error("%s: group debe ser un texto no vacio" % what, y, x)
                else:
                    reminder_groups.add(group)
                d = entry.get("defaults", {})
                timer, warn = params.get("timer_s", d.get("timer_s")), params.get("warn_s", d.get("warn_s"))
                if _is_number(timer) and _is_number(warn) and warn >= timer:
                    self.error("%s: warn_s (%s) debe ser menor que timer_s (%s)" % (what, warn, timer), y, x)
            elif kind == "snooze_button":
                snoozes.append((what, x, y, params, entry.get("defaults", {})))
            elif kind == "update_bar":
                self._check_update_bar(what, x, y, params, entry)
            elif kind == "ability_pickup":
                if "refill_energy" in params and not isinstance(params["refill_energy"], bool):
                    self.error("%s: refill_energy debe ser true o false" % what, y, x)
            elif kind in ("exit_door", "exit_terminal"):
                doors.append((what, x, y, set(cells)))
            elif kind == "extra_life_pickup":
                extra_lives.append((what, x, y))
                sid = params.get("secret_id")
                if not isinstance(sid, str) or not sid.strip():
                    self.error("%s: secret_id debe ser un texto no vacio (id del registro)" % what, y, x)
            elif kind == "memory_pickup":
                self._check_memory_pickup(what, x, y, params)
            elif kind == "eco_encounter":
                encounters.append((what, x, y))
                self._check_eco_encounter(what, x, y, params, entry.get("defaults", {}))
        self._check_calc_room()
        self._check_rhythm()
        if self.is_boss_arena() and isinstance(self.level.get("boss"), str):
            bosses = [o for o in self.level["objects"] if isinstance(o, dict) and o.get("type") == self.level["boss"]]
            if len(bosses) != 1:
                self.error("la arena debe tener exactamente un objeto '%s' (el jefe) y tiene %d"
                           % (self.level["boss"], len(bosses)))
        for (what, x, y) in extra_lives[1:]:
            self.error("%s: solo puede haber una vida extra por nivel" % what, y, x)
        if len(encounters) > 1:
            for (what, x, y) in encounters[1:]:
                self.error("%s: solo puede haber un encuentro con Eco por nivel" % what, y, x)
        if encounters and self.level.get("abilities_available", {}).get("pulse", False):
            what, x, y = encounters[0]
            self.error("%s: el encuentro con Eco da el pulso; el nivel debe empezar sin el "
                       "(abilities_available.pulse false)" % what, y, x)
        for (what, x, y, params, defaults) in snoozes:
            self._check_snooze(what, x, y, params, defaults, reminder_groups)
        for (what, x, y, target) in receivers:
            if target not in bridges:
                self.error("%s: target '%s' no es el id de ningun bridge_inactive" % (what, target), y, x)
        for (what, x, y, target, kind) in links:
            ids = relays if kind == "relay_receiver" else set(popups)
            if target not in ids:
                kinds = kind if kind == "relay_receiver" else "popup_blocker ni overlay_popup"
                self.error("%s: target '%s' no es el id de ningun %s" % (what, target, kinds), y, x)
            elif kind == "popup_blocker":
                px, py, pp = popups[target]
                button = pp.get("close_button_px")
                size = pp.get("close_button_size_px", 24 if self._is_overlay_id(target) else 16)
                if isinstance(button, list) and len(button) == 2 and all(_is_number(v) for v in button) \
                        and _is_number(size):
                    t = self.level["tile_size"]
                    cell = (px + int((button[0] + size * 0.5) // t), py + int((button[1] + size * 0.5) // t))
                    if (x, y) != cell:
                        self.error("%s: debe estar en la celda del boton de cerrar de '%s' (columna %d, fila %d)"
                                   % (what, target, cell[0], cell[1]), y, x)
        goals = self._cells_with("G")
        for (what, x, y, cells) in doors:
            if len(goals) == 1 and goals[0] not in cells:
                self.error("%s no contiene la meta G (fila %d, columna %d)"
                           % (what, goals[0][1], goals[0][0]), y, x)

    def _check_calc_room(self):
        """Piezas del acertijo de la azotea del 1-2 (2026-10-17, tanda H1 del paso 14): enlaces por id
        con el tipo correcto, puerta solo en bloques de 1x2 con a lo sumo 3 luces, terminal con
        corriente enlazada a un punto de carga, recorrido de Calc por celdas libres y guion de Eco
        existente con acciones y piezas validas."""
        ids = {}
        for obj in self.level["objects"]:
            if isinstance(obj, dict) and isinstance(obj.get("params"), dict) and isinstance(obj["params"].get("id"), str):
                ids[obj["params"]["id"]] = obj.get("type")
        guides = None
        for i, obj in enumerate(self.level["objects"]):
            if not (isinstance(obj, dict) and isinstance(obj.get("params"), dict)):
                continue
            kind, x, y, params = obj.get("type"), obj.get("x"), obj.get("y"), obj["params"]
            what = "objects[%d] (%s)" % (i, kind)

            def link(field, kinds, value=None):
                target = params.get(field) if value is None else value
                if not isinstance(target, str) or ids.get(target) not in kinds:
                    self.error("%s: %s '%s' no es el id de ningun %s" % (what, field, target, " ni ".join(kinds)), y, x)

            if kind == "glitch_wall" and ("door_when" in params or "lamps" in params):
                link("door_when", ("power_switch", "debug_switch"))
                if params.get("width_tiles", 1) != 1 or params.get("height_tiles", 2) != 2:
                    self.error("%s: la puerta (door_when) solo admite un bloque de 1x2" % what, y, x)
                lamps = params.get("lamps", [])
                if not isinstance(lamps, list) or len(lamps) > DOOR_MAX_LAMPS:
                    self.error("%s: lamps debe ser una lista de a lo sumo %d ids" % (what, DOOR_MAX_LAMPS), y, x)
                else:
                    for lamp in lamps:
                        link("lamps", CALC_PIECE_TYPES, lamp)
            elif kind == "dark_room":
                link("switch", ("power_switch", "debug_switch"))
                w, h = params.get("width_tiles", 4), params.get("height_tiles", 4)
                if isinstance(w, int) and isinstance(h, int) and not self.in_bounds(x + w - 1, y + h - 1):
                    self.error("%s: el cuarto se sale del grid" % what, y, x)
            elif kind == "charge_dock":
                req = params.get("requires")
                if not isinstance(req, list) or not req:
                    self.error("%s: requires debe ser una lista no vacia de ids" % what, y, x)
                else:
                    for r in req:
                        link("requires", CALC_PIECE_TYPES, r)
            elif kind == "calc_actor":
                link("dock", ("charge_dock",))
                path = params.get("path")
                if not (isinstance(path, list) and len(path) >= 2):
                    self.error("%s: path debe ser una lista de al menos 2 celdas [columna, fila]" % what, y, x)
                else:
                    for j, cell in enumerate(path):
                        if not (isinstance(cell, list) and len(cell) == 2 and all(_is_int(v) for v in cell)):
                            self.error("%s: path[%d] debe ser [columna, fila] (enteros)" % (what, j), y, x)
                        elif not self.in_bounds(cell[0], cell[1]) or self.cell(cell[0], cell[1]) in "#^":
                            self.error("%s: path[%d] %s fuera del grid o en terreno" % (what, j, cell), y, x)
                    if isinstance(path[0], list) and path[0] != [x, y]:
                        self.error("%s: path[0] debe ser su celda (%d, %d)" % (what, x, y), y, x)
            elif kind == "exit_terminal" and ("requires_power" in params or "power_source" in params):
                if not isinstance(params.get("requires_power", False), bool):
                    self.error("%s: requires_power debe ser true o false" % what, y, x)
                if params.get("requires_power"):
                    link("power_source", ("charge_dock",))
            elif kind == "eco_guide":
                if guides is None:
                    guides = (self._load_json("data/eco_guides.json") or {}).get("guides", {})
                self._check_guide(what, x, y, params.get("guide"), guides, ids)

    def _rhythms(self):
        """{id: (tipo, zona, ciclo mas corto)} de los metronomos del nivel (rhythm_zone y, desde el paso
        6, alarm_tunnel); zona = (columna, fila, ancho, alto) o None si no es valida."""
        out = {}
        for obj in self.level["objects"]:
            if not isinstance(obj, dict) or obj.get("type") not in RHYTHM_TYPES or not isinstance(obj.get("params"), dict):
                continue
            p = obj["params"]
            zone = p.get("zone")
            ok = isinstance(zone, list) and len(zone) == 4 and all(_is_int(v) for v in zone) and zone[2] >= 1 \
                and zone[3] >= 1
            out[p.get("id")] = (obj["type"], tuple(zone) if ok else None, self._shortest_cycle(obj["type"], p))
        return out

    def _shortest_cycle(self, kind, p):
        if kind == "alarm_tunnel":
            cycles = [s.get("cycle_s") for s in p.get("stages", []) if isinstance(s, dict)]
        else:
            cycles = p.get("tempo_steps_s", [])
        cycles = [c for c in cycles if _is_number(c)] if isinstance(cycles, list) else []
        return min(cycles) if cycles else None

    def _check_rhythm(self):
        """Metronomo y plataformas que parpadean (2026-10-19, paso 5 de docs/propuesta-1-3.md §5.3):
        rhythm_zone con zona dentro del grid, ciclos de RHYTHM_CYCLE_S y loop booleano; blink_platform
        con rhythm existente, dentro de su zona, group no vacio y on_fraction x el ciclo mas corto >=
        aviso (warn_frames / anim_fps) + min_on_extra_s."""
        rhythms = self._rhythms()
        catalog = self._load_catalog() or {}
        cfg = catalog.get("blink_platform", {})
        defaults = catalog.get("types", {}).get("blink_platform", {}).get("defaults", {})
        warn = float(cfg.get("warn_frames", 9)) / float(cfg.get("anim_fps", 12.0))
        extra = float(cfg.get("min_on_extra_s", 0.25))
        lo, hi = RHYTHM_CYCLE_S
        for i, obj in enumerate(self.level["objects"]):
            if not (isinstance(obj, dict) and isinstance(obj.get("params"), dict)):
                continue
            kind, x, y, p = obj.get("type"), obj.get("x"), obj.get("y"), obj["params"]
            what = "objects[%d] (%s)" % (i, kind)
            if kind in RHYTHM_TYPES:
                zone = rhythms.get(p.get("id"), (None, None, None))[1]
                if zone is None:
                    self.error("%s: zone debe ser [columna, fila, ancho, alto] (enteros, ancho y alto >= 1)" % what, y, x)
                elif not (self.in_bounds(zone[0], zone[1]) and self.in_bounds(zone[0] + zone[2] - 1, zone[1] + zone[3] - 1)):
                    self.error("%s: zone %s se sale del grid" % (what, list(zone)), y, x)
                if "loop" in p and not isinstance(p["loop"], bool):
                    self.error("%s: loop debe ser true o false" % what, y, x)
                if kind == "alarm_tunnel":
                    self._check_stages(what, x, y, p.get("stages"), zone)
                if kind == "rhythm_zone":
                    steps = p.get("tempo_steps_s")
                    if not (isinstance(steps, list) and steps and all(_is_number(v) and lo <= v <= hi for v in steps)):
                        self.error("%s: tempo_steps_s debe ser una lista no vacia de segundos entre %g y %g"
                                   % (what, lo, hi), y, x)
            elif kind == "blink_platform":
                if not isinstance(p.get("one_way", False), bool):
                    self.error("%s: one_way debe ser true o false" % what, y, x)
                group = p.get("group")
                if not isinstance(group, str) or not group.strip():
                    self.error("%s: group debe ser un texto no vacio" % what, y, x)
                rid = p.get("rhythm")
                if rid not in rhythms:
                    self.error("%s: rhythm '%s' no es el id de ningun %s" % (what, rid, " ni ".join(RHYTHM_TYPES)), y, x)
                    continue
                _, zone, shortest = rhythms[rid]
                w = p.get("width_tiles", defaults.get("width_tiles", 2))
                if zone is not None and _is_int(x) and _is_int(y) and _is_int(w):
                    if not (zone[0] <= x and x + w <= zone[0] + zone[2] and zone[1] <= y < zone[1] + zone[3]):
                        self.error("%s: la plataforma se sale de la zona de su metronomo %s" % (what, rid), y, x)
                on = p.get("on_fraction", defaults.get("on_fraction", 0.5))
                if shortest is not None and _is_number(on) and on * shortest < warn + extra - 1e-9:
                    self.error("%s: encendida %.2f s con el ciclo mas corto (%.2f s): menos que el aviso (%.2f s) + "
                               "%.2f s" % (what, on * shortest, shortest, warn, extra), y, x)

    def _check_stages(self, what, x, y, stages, zone):
        """Tramos del tunel de alarmas (2026-10-19, paso 6): lista no vacia de {x_from, x_to, cycle_s}, en
        orden y sin solaparse, dentro de las columnas de la zona, con ciclos de RHYTHM_CYCLE_S."""
        lo, hi = RHYTHM_CYCLE_S
        if not isinstance(stages, list) or not stages:
            self.error("%s: stages debe ser una lista no vacia de {x_from, x_to, cycle_s}" % what, y, x)
            return
        previous = None
        for j, st in enumerate(stages):
            tag = "%s: stages[%d]" % (what, j)
            if not isinstance(st, dict) or set(st) != {"x_from", "x_to", "cycle_s"}:
                self.error("%s debe ser {x_from, x_to, cycle_s}" % tag, y, x)
                return
            a, b, c = st["x_from"], st["x_to"], st["cycle_s"]
            if not (_is_int(a) and _is_int(b) and a <= b):
                self.error("%s: x_from y x_to deben ser columnas (enteros, x_from <= x_to)" % tag, y, x)
                return
            if not (_is_number(c) and lo <= c <= hi):
                self.error("%s: cycle_s debe estar entre %g y %g s" % (tag, lo, hi), y, x)
            if previous is not None and a <= previous:
                self.error("%s: los tramos van en orden y sin solaparse" % tag, y, x)
            previous = b
            if zone is not None and not (zone[0] <= a and b < zone[0] + zone[2]):
                self.error("%s: columnas %d-%d fuera de la zona" % (tag, a, b), y, x)

    def _check_guide(self, what, x, y, guide_id, guides, ids):
        guide = guides.get(guide_id) if isinstance(guide_id, str) else None
        if not isinstance(guide, dict) or not isinstance(guide.get("steps"), list) or not guide["steps"]:
            self.error("%s: guide '%s' no esta en data/eco_guides.json (o no tiene pasos)" % (what, guide_id), y, x)
            return
        for j, step in enumerate(guide["steps"]):
            tag = "%s: paso %d" % (what, j)
            if not isinstance(step, dict) or step.get("do") not in GUIDE_ACTIONS:
                self.error("%s: accion desconocida (validas: %s)" % (tag, ", ".join(GUIDE_ACTIONS)), y, x)
                continue
            for field in GUIDE_ACTIONS[step["do"]]:
                if field not in step:
                    self.error("%s (%s): falta '%s'" % (tag, step["do"], field), y, x)
            if "object" in step and step["object"] not in ids:
                self.error("%s (%s): object '%s' no es el id de ninguna pieza del nivel"
                           % (tag, step["do"], step["object"]), y, x)
            if step["do"] == "fly" and "object" not in step and "cell" not in step:
                self.error("%s (fly): necesita object o cell" % tag, y, x)
            if "text" in step and (not isinstance(step["text"], str) or not step["text"].strip()):
                self.error("%s: text debe ser un texto no vacio" % tag, y, x)
            if step["do"] == "wait_ability" and step.get("ability") not in GUIDE_ABILITIES:
                self.error("%s: ability debe ser una de %s" % (tag, ", ".join(GUIDE_ABILITIES)), y, x)
            if step["do"] == "wait_s" and not (_is_number(step.get("seconds")) and 0 < step["seconds"] <= 30):
                self.error("%s: seconds debe estar en (0, 30]" % tag, y, x)

    def _is_overlay_id(self, ident):
        return any(isinstance(o, dict) and o.get("type") == "overlay_popup"
                   and isinstance(o.get("params"), dict) and o["params"].get("id") == ident
                   for o in self.level.get("objects", []))

    def _check_glitch_cover(self, what, x, y, cover):
        """Terreno falso de una pared con glitch (2026-10-22): [x, y, ancho, alto] en celdas,
        enteros, tamano >= 1, dentro del grid, sin terreno ('#') dentro (tapa una sala libre)."""
        if not (isinstance(cover, list) and len(cover) == 4 and all(_is_int(v) for v in cover)) \
                or cover[2] < 1 or cover[3] < 1:
            self.error("%s: cover debe ser [x, y, ancho, alto] (enteros, tamano >= 1)" % what, y, x)
            return
        cx, cy, w, h = cover
        for j in range(h):
            for i in range(w):
                if not self.in_bounds(cx + i, cy + j):
                    self.error("%s: cover se sale del grid" % what, cy + j, cx + i)
                    return
                if self.cell(cx + i, cy + j) == "#":
                    self.error("%s: cover tapa terreno ('#'): solo celdas libres" % what, cy + j, cx + i)
                    return

    def _check_exceptions_panel(self, what, x, y, params):
        """Decorado de la sala «Excepciones» (2026-10-20): title texto no vacio y contacts lista de
        nombres no vacios."""
        if "title" in params and not (isinstance(params["title"], str) and params["title"].strip()):
            self.error("%s: title debe ser un texto no vacio" % what, y, x)
        contacts = params.get("contacts")
        if contacts is not None and not (isinstance(contacts, list) and contacts
                                         and all(isinstance(c, str) and c.strip() for c in contacts)):
            self.error("%s: contacts debe ser una lista no vacia de nombres" % what, y, x)

    def _check_object_params(self, what, x, y, params, spec):
        """Params numericos de un objeto con level_params en el catalogo (2026-10-16: recordatorio,
        Posponer, pop-up translucido y barra del 99 %): numericos, en [min, max] y enteros si int."""
        for key, rule in spec.items():
            if key.startswith("_") or key not in params or not isinstance(rule, dict):
                continue
            value = params[key]
            if not _is_number(value):
                self.error("%s: %s debe ser un numero" % (what, key), y, x)
                continue
            if rule.get("int") and not _is_int(value):
                self.error("%s: %s debe ser un entero" % (what, key), y, x)
            if "min" in rule and value < rule["min"] or "max" in rule and value > rule["max"]:
                self.error("%s: %s = %s fuera de [%s, %s]" % (what, key, value, rule.get("min"), rule.get("max")),
                           y, x)

    def _check_snooze(self, what, x, y, params, defaults, groups):
        """Posponer: targets = lista no vacia de grupos de recordatorios del nivel; cap_s >= extend_s."""
        targets = params.get("targets")
        if not isinstance(targets, list) or not targets:
            self.error("%s: targets debe ser una lista no vacia de grupos de recordatorios" % what, y, x)
        else:
            for target in targets:
                if not isinstance(target, str) or target not in groups:
                    self.error("%s: target '%s' no es el group de ningun reminder_platform" % (what, target), y, x)
        extend = params.get("extend_s", defaults.get("extend_s"))
        cap = params.get("cap_s", defaults.get("cap_s"))
        if _is_number(extend) and _is_number(cap) and cap < extend:
            self.error("%s: cap_s (%s) debe ser >= extend_s (%s)" % (what, cap, extend), y, x)

    def _check_overlay(self, what, x, y, params, defaults):
        """Pop-up translucido: el boton de cerrar dentro de la ventana."""
        button = params.get("close_button_px")
        size = params.get("close_button_size_px", defaults.get("close_button_size_px", 24))
        w = params.get("width_tiles", defaults.get("width_tiles", 1))
        h = params.get("height_tiles", defaults.get("height_tiles", 1))
        if not (isinstance(button, list) and len(button) == 2 and all(_is_number(v) for v in button)):
            self.error("%s: close_button_px debe ser [x, y] en px" % what, y, x)
            return
        if not (_is_number(size) and _is_int(w) and _is_int(h)):
            return
        t = self.level["tile_size"]
        if button[0] < 0 or button[1] < 0 or button[0] + size > w * t or button[1] + size > h * t:
            self.error("%s: el boton de cerrar (%s, %s px) se sale de la ventana" % (what, button, size), y, x)

    def _check_update_bar(self, what, x, y, params, entry):
        """Barra del 99 %: zona dentro del grid y oleadas {t, type, x, params} con t entre el aviso y
        wait_s, type de wave_types, x dentro de la zona y params validos para ese enemigo."""
        zone = params.get("zone")
        if not (isinstance(zone, list) and len(zone) == 4 and all(_is_int(v) for v in zone)) \
                or zone[2] < 1 or zone[3] < 1:
            self.error("%s: zone debe ser [columna, fila, ancho, alto] (enteros, ancho y alto >= 1)" % what, y, x)
            zone = None
        elif not (self.in_bounds(zone[0], zone[1]) and self.in_bounds(zone[0] + zone[2] - 1, zone[1] + zone[3] - 1)):
            self.error("%s: zone %s se sale del grid" % (what, zone), y, x)
        wait = params.get("wait_s", entry.get("defaults", {}).get("wait_s", 20.0))
        waves = params.get("waves")
        if not isinstance(waves, list):
            self.error("%s: waves debe ser una lista de {t, type, x, params}" % what, y, x)
            return
        if len(waves) > int(entry.get("max_waves", 12)):
            self.error("%s: demasiadas oleadas (%d; maximo %d)" % (what, len(waves), entry.get("max_waves", 12)), y, x)
        allowed = entry.get("wave_types", [])
        for i, wave in enumerate(waves):
            tag = "%s: waves[%d]" % (what, i)
            if not isinstance(wave, dict):
                self.error("%s debe ser un objeto {t, type, x, params}" % tag, y, x)
                continue
            for key in wave:
                if key not in ("t", "type", "x", "params"):
                    self.error("%s: campo desconocido '%s'" % (tag, key), y, x)
            t = wave.get("t")
            if not _is_number(t):
                self.error("%s: t debe ser un numero (segundos de la espera)" % tag, y, x)
            elif _is_number(wait) and not (UPDATE_BAR_WARN_S <= t < wait):
                self.error("%s: t = %s fuera de [%.2f, wait_s %s) (aviso de 9 cuadros antes de caer)"
                           % (tag, t, UPDATE_BAR_WARN_S, wait), y, x)
            kind = wave.get("type")
            if kind not in allowed:
                self.error("%s: type '%s' no admitido (validos: %s)" % (tag, kind, ", ".join(allowed)), y, x)
            col = wave.get("x")
            if not _is_int(col):
                self.error("%s: x debe ser una columna (entero)" % tag, y, x)
            elif zone is not None and not (zone[0] <= col < zone[0] + zone[2]):
                self.error("%s: x = %d fuera de la zona (columnas %d-%d)" % (tag, col, zone[0], zone[0] + zone[2] - 1),
                           y, x)
            wparams = wave.get("params", {})
            if not isinstance(wparams, dict):
                self.error("%s: params debe ser un objeto" % tag, y, x)
            elif kind in allowed:
                data = self._load_json("data/enemies/%s.json" % kind)
                spec = data.get("level_params") if isinstance(data, dict) else None
                fake = {"id": "%s (oleada %d)" % (params.get("id", what), i), "type": kind}
                if isinstance(spec, dict):
                    self._check_enemy_params(fake, wparams, spec)
                else:
                    for key, value in wparams.items():
                        if not _is_number(value) or value <= 0:
                            self.error("%s: params.%s debe ser un numero > 0" % (tag, key), y, x)

    def _check_eco_encounter(self, what, x, y, params, defaults):
        """Eco flotando (eco_offset_tiles) dentro de la zona del encuentro y en una celda libre."""
        offset = params.get("eco_offset_tiles", defaults.get("eco_offset_tiles"))
        if not (isinstance(offset, list) and len(offset) == 2 and all(_is_int(v) for v in offset)):
            self.error("%s: eco_offset_tiles debe ser [columna, fila] (enteros)" % what, y, x)
            return
        w = params.get("width_tiles", defaults.get("width_tiles", 1))
        h = params.get("height_tiles", defaults.get("height_tiles", 1))
        if not (0 <= offset[0] < w and 0 <= offset[1] < h):
            self.error("%s: Eco (eco_offset_tiles %s) queda fuera de la zona del encuentro" % (what, offset), y, x)
            return
        ex, ey = x + offset[0], y + offset[1]
        if self.in_bounds(ex, ey) and self.cell(ex, ey) in "#^":
            self.error("%s: Eco flota dentro de terreno o pinchos ('%s')" % (what, self.cell(ex, ey)), ey, ex)

    def _check_laser_receiver(self, what, x, y, params):
        """Lector laser: window_s > 0 y cable = lista de [columna, fila] enteros dentro del grid."""
        if "window_s" in params and (not _is_number(params["window_s"]) or params["window_s"] <= 0):
            self.error("%s: window_s debe ser un numero > 0" % what, y, x)
        cable = params.get("cable", [])
        if not isinstance(cable, list):
            self.error("%s: cable debe ser una lista de [columna, fila]" % what, y, x)
            return
        for i, cell in enumerate(cable):
            if not (isinstance(cell, list) and len(cell) == 2 and all(_is_int(v) for v in cell)):
                self.error("%s: cable[%d] debe ser [columna, fila] (enteros)" % (what, i), y, x)
            elif not self.in_bounds(cell[0], cell[1]):
                self.error("%s: cable[%d] %s fuera del grid" % (what, i, cell), y, x)

    def _check_charger(self, what, x, y, params):
        """Cargador (2026-10-15): amount > 0, cooldown_s >= 0 y reusable booleano."""
        if "amount" in params and (not _is_number(params["amount"]) or params["amount"] <= 0):
            self.error("%s: amount debe ser un numero > 0" % what, y, x)
        if "cooldown_s" in params and (not _is_number(params["cooldown_s"]) or params["cooldown_s"] < 0):
            self.error("%s: cooldown_s debe ser un numero >= 0" % what, y, x)
        if "reusable" in params and not isinstance(params["reusable"], bool):
            self.error("%s: reusable debe ser true o false" % what, y, x)

    def _memories(self):
        """{id: entrada} de data/memories.json (cacheado; vacio si no se puede leer)."""
        if not hasattr(self, "_memories_cache"):
            data = self._load_json(MEMORIES_JSON)
            items = data.get("memories", []) if isinstance(data, dict) else []
            self._memories_cache = {m.get("id"): m for m in items if isinstance(m, dict)}
        return self._memories_cache

    def _check_memory_pickup(self, what, x, y, params):
        """Mensaje de secreto (memory_pickup, 2026-10-19): memory_id de un mensaje (kind secret) de
        data/memories.json; uno por memory_id en el nivel (el secreto que lo ofrece se comprueba en
        _check_secrets)."""
        mid = params.get("memory_id")
        if not isinstance(mid, str) or not mid.strip():
            self.error("%s: memory_id debe ser un texto no vacio (id de data/memories.json)" % what, y, x)
            return
        memory = self._memories().get(mid)
        if memory is None:
            self.error("%s: memory_id '%s' no esta en data/memories.json" % (what, mid), y, x)
        elif memory.get("kind") != "secret":
            self.error("%s: memory_id '%s' no es un mensaje de secreto (kind secret)" % (what, mid), y, x)
        if mid in self.memory_pickups:
            self.error("%s: ya hay otro memory_pickup con memory_id '%s' en el nivel" % (what, mid), y, x)
            return
        self.memory_pickups[mid] = (what, x, y)

    def _check_secret_reward(self, entry, what, pos, claimed):
        """Recompensa del secreto (reward: texto o lista) y, con memory, su memory_id (2026-10-19)."""
        if "reward" not in entry:
            rewards = []
        elif isinstance(entry["reward"], str):
            rewards = [entry["reward"]]
        elif isinstance(entry["reward"], list) and entry["reward"] \
                and all(isinstance(r, str) for r in entry["reward"]):
            rewards = list(entry["reward"])
        else:
            self.error("%s '%s': reward debe ser un texto o una lista de textos no vacia"
                       % (what, entry.get("id")), pos[1], pos[0])
            return
        for r in rewards:
            if r not in SECRET_REWARDS:
                self.error("%s '%s': reward '%s' desconocida (validas: %s)"
                           % (what, entry.get("id"), r, ", ".join(SECRET_REWARDS)), pos[1], pos[0])
        if len(set(rewards)) != len(rewards):
            self.error("%s '%s': reward repetida" % (what, entry.get("id")), pos[1], pos[0])
        mid = entry.get("memory_id")
        if "memory" not in rewards:
            if "memory_id" in entry:
                self.error("%s '%s': memory_id sin la recompensa memory" % (what, entry.get("id")), pos[1], pos[0])
            return
        if not isinstance(mid, str) or not mid.strip():
            self.error("%s '%s': la recompensa memory necesita memory_id (id de data/memories.json)"
                       % (what, entry.get("id")), pos[1], pos[0])
            return
        memory = self._memories().get(mid)
        if memory is None:
            self.error("%s '%s': memory_id '%s' no esta en data/memories.json" % (what, entry.get("id"), mid),
                       pos[1], pos[0])
        elif memory.get("kind") != "secret":
            self.error("%s '%s': memory_id '%s' no es un mensaje de secreto (kind secret)"
                       % (what, entry.get("id"), mid), pos[1], pos[0])
        elif memory.get("level") != (self.level.get("stands_for") or self.level.get("id")) \
                or memory.get("secret") != entry.get("id"):
            self.error("%s '%s': el mensaje %s es del nivel %s y del secreto %s en data/memories.json"
                       % (what, entry.get("id"), mid, memory.get("level"), memory.get("secret")), pos[1], pos[0])
        if mid in claimed:
            self.error("%s '%s': el mensaje %s ya lo ofrece el secreto %s" % (what, entry.get("id"), mid, claimed[mid]),
                       pos[1], pos[0])
        claimed[mid] = entry.get("id")
        if mid not in self.memory_pickups:
            self.error("%s '%s': no hay ningun memory_pickup con memory_id '%s' en el nivel"
                       % (what, entry.get("id"), mid), pos[1], pos[0])

    def _check_secrets(self):
        listed = set()
        claimed = {}
        for i, entry in enumerate(self.level["secrets"]):
            what = "secrets %d" % i
            if not isinstance(entry, dict):
                self.error("%s debe ser un objeto" % what)
                continue
            pos = self._check_point_entry(entry, what)
            if pos is None:
                continue
            self._check_secret_reward(entry, what, pos, claimed)
            if "requires_upgrade" in entry:
                # Mejoras de Calc por pistas (tanda M1): "pista:nivel" o un legacy_id (wide_pulse).
                catalog = upgrade_catalog.load_catalog(self.root)
                if upgrade_catalog.resolve(catalog, entry["requires_upgrade"]) is None:
                    self.error("%s '%s': requires_upgrade '%s' no esta en data/upgrades.json"
                               % (what, entry.get("id"), entry["requires_upgrade"]), pos[1], pos[0])
            if "needs_debug" in entry and not isinstance(entry["needs_debug"], bool):
                self.error("%s '%s': needs_debug debe ser booleano" % (what, entry.get("id")), pos[1], pos[0])
            if "forbid_abilities" in entry:
                # Ruta del secreto sin esas habilidades (2026-10-20, paso 7 de docs/propuesta-1-3.md §5.4:
                # «Excepciones» sin el dash). El validador de alcanzabilidad la exige en el paso 9.
                forbid = entry["forbid_abilities"]
                if not (isinstance(forbid, list) and forbid and all(isinstance(a, str) for a in forbid)) \
                        or len(set(forbid)) != len(forbid):
                    self.error("%s '%s': forbid_abilities debe ser una lista no vacia de habilidades sin repetir"
                               % (what, entry.get("id")), pos[1], pos[0])
                else:
                    for name in forbid:
                        if name not in KNOWN_ABILITIES:
                            self.error("%s '%s': habilidad desconocida en forbid_abilities: '%s'"
                                       % (what, entry.get("id"), name), pos[1], pos[0])
            if "object" in entry:
                if (entry["object"], pos) not in self.object_anchors:
                    self.error("%s '%s': no hay ningun objeto '%s' en esa celda"
                               % (what, entry.get("id"), entry["object"]), pos[1], pos[0])
                continue
            listed.add(pos)
            if self.cell(*pos) != "S":
                self.error("%s '%s' no esta sobre una celda 'S' ni referencia un objeto"
                           % (what, entry.get("id")), pos[1], pos[0])
        for (x, y) in self._cells_with("S"):
            if (x, y) not in listed:
                self.error("celda 'S' sin entrada en la lista de secrets", y, x)
        for mid, (what, x, y) in sorted(getattr(self, "memory_pickups", {}).items()):
            if mid not in claimed:
                self.error("%s: ningun secreto ofrece el mensaje %s (recompensa memory con memory_id)"
                           % (what, mid), y, x)

    def _check_spikes(self):
        for (x, y) in self._cells_with("P"):
            if y + 1 < self.height and self.cell(x, y + 1) == "^":
                self.error("pinchos justo debajo del inicio P", y + 1, x)
        for (x, y) in self._cells_with("C"):
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if self.in_bounds(nx, ny) and self.cell(nx, ny) == "^":
                        self.error("pinchos junto al punto de sincronizacion C (fila %d, columna %d)"
                                   % (y, x), ny, nx)

    def _check_unlocks(self):
        for i, entry in enumerate(self.level["unlocks"]):
            if not isinstance(entry, dict) or not isinstance(entry.get("type"), str) \
                    or not isinstance(entry.get("id"), str):
                self.error("unlocks[%d] debe ser {\"type\": texto, \"id\": texto}" % i)


    def _check_sections(self):
        """'sections' (opcional): tramos del documento en orden. Cada tramo es un rectangulo
        de celdas: x_from/x_to (por defecto todo el ancho) e y_from/y_to (por defecto todo el
        alto; van juntos). No se solapan. Sin y en ningun tramo (nivel horizontal, 1-1) van
        ademas de izquierda a derecha. `patterns` (opcional): lista de nombres de patrones."""
        sections = self.level.get("sections", [])
        if not isinstance(sections, list):
            self.error("'sections' debe ser una lista")
            return
        horizontal = all(isinstance(e, dict) and "y_from" not in e and "y_to" not in e for e in sections)
        previous_end = -1
        rects = []
        for i, entry in enumerate(sections):
            if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
                self.error("sections[%d] debe ser {name, x_from, x_to[, y_from, y_to]}" % i)
                continue
            name = entry["name"]
            rect = self._section_rect(i, entry)
            if rect is None:
                continue
            x0, x1, y0, y1 = rect
            patterns = entry.get("patterns", [])
            if not isinstance(patterns, list) or not all(isinstance(p, str) and p.strip() for p in patterns):
                self.error("sections[%d] '%s': patterns debe ser una lista de textos no vacios" % (i, name))
            if horizontal:
                if x0 <= previous_end:
                    self.error("sections[%d] '%s' se solapa o va antes que la anterior" % (i, name))
                previous_end = x1
                continue
            for j, (other, ox0, ox1, oy0, oy1) in enumerate(rects):
                if x0 <= ox1 and ox0 <= x1 and y0 <= oy1 and oy0 <= y1:
                    self.error("sections[%d] '%s' se solapa con sections[%d] '%s' (columnas %d-%d, filas %d-%d)"
                               % (i, name, j, other, max(x0, ox0), min(x1, ox1), max(y0, oy0), min(y1, oy1)))
            rects.append((name, x0, x1, y0, y1))

    def _section_rect(self, i, entry):
        """(x_from, x_to, y_from, y_to) del tramo con los valores por defecto, o None si no es valido."""
        name = entry["name"]
        has_x = "x_from" in entry or "x_to" in entry
        has_y = "y_from" in entry or "y_to" in entry
        x0, x1 = entry.get("x_from", 0 if not has_x else None), entry.get("x_to", self.width - 1 if not has_x else None)
        y0, y1 = entry.get("y_from", 0 if not has_y else None), entry.get("y_to", self.height - 1 if not has_y else None)
        if not (_is_int(x0) and _is_int(x1)) or not (0 <= x0 <= x1 < self.width):
            self.error("sections[%d] '%s': x_from/x_to no validos (columnas 0-%d, x_from <= x_to)"
                       % (i, name, self.width - 1))
            return None
        if not (_is_int(y0) and _is_int(y1)) or not (0 <= y0 <= y1 < self.height):
            self.error("sections[%d] '%s': y_from/y_to no validos (filas 0-%d, y_from <= y_to, los dos juntos)"
                       % (i, name, self.height - 1))
            return None
        return (x0, x1, y0, y1)

    def _check_scroll(self):
        """Scroll forzado (2026-10-22, paso 2 de docs/propuesta-mundo-2.md §8): con camera.vertical
        "autoscroll" el nivel mide AUTOSCROLL_WIDTH_TILES de ancho y lleva scroll {start_resume_row,
        start_bottom_row?, default_speed_tiles_s?, stages?, stops?, reverses?, safe_respawn}: filas
        dentro del grid, velocidades en SCROLL_SPEED_RANGE, tramos sin solaparse, paradas con id unico y
        resume_row por encima de su at_row y a la vista (o dos tiles por encima), inversiones con
        duracion de 0 a 10 s, y tarjetas seguras [x, y] en celdas libres con suelo ('#' o '-') debajo,
        a SCROLL_SAFE_GAP_ROWS filas o menos entre si desde el inicio hasta arriba. Sin autoscroll no
        hay seccion scroll."""
        mode = self.level.get("camera", {}).get("vertical") if isinstance(self.level.get("camera"), dict) else None
        if mode != "autoscroll":
            if "scroll" in self.level:
                self.error("'scroll' solo vale con camera.vertical \"autoscroll\"")
            return
        if self.width != AUTOSCROLL_WIDTH_TILES:
            self.error("un nivel con scroll forzado mide %d tiles de ancho (tiene %d)" % (AUTOSCROLL_WIDTH_TILES,
                                                                                        self.width))
        scroll = self.level.get("scroll")
        if not isinstance(scroll, dict):
            self.error("camera.vertical \"autoscroll\" exige la seccion 'scroll' (objeto)")
            return
        for key in scroll:
            if key not in SCROLL_KEYS:
                self.error("scroll: campo desconocido '%s'" % key)
        rows = self.height
        view_rows = SCREEN_HEIGHT_PX / float(self.level["tile_size"])

        def row_ok(value, what):
            if not _is_int(value) or not 0 <= value < rows:
                self.error("scroll.%s debe ser una fila del grid (0-%d)" % (what, rows - 1))
                return False
            return True

        def speed_ok(value, what):
            lo, hi = SCROLL_SPEED_RANGE
            if not _is_number(value) or not lo <= value <= hi:
                self.error("scroll.%s debe estar entre %g y %g tiles/s" % (what, lo, hi))

        if "start_resume_row" not in scroll:
            self.error("scroll: falta start_resume_row (fila que arranca el scroll al subir por encima)")
        else:
            row_ok(scroll["start_resume_row"], "start_resume_row")
        if "start_bottom_row" in scroll:
            row_ok(scroll["start_bottom_row"], "start_bottom_row")
        if "default_speed_tiles_s" in scroll:
            speed_ok(scroll["default_speed_tiles_s"], "default_speed_tiles_s")
        bands = []
        for i, stage in enumerate(scroll.get("stages", [])):
            tag = "stages[%d]" % i
            if not isinstance(stage, dict) or set(stage) - {"y_from", "y_to", "speed_tiles_s"}:
                self.error("scroll.%s debe ser {y_from, y_to, speed_tiles_s}" % tag)
                continue
            if row_ok(stage.get("y_from"), tag + ".y_from") and row_ok(stage.get("y_to"), tag + ".y_to"):
                if stage["y_from"] > stage["y_to"]:
                    self.error("scroll.%s: y_from debe ser <= y_to" % tag)
                else:
                    for other in bands:
                        if not (stage["y_to"] < other[0] or stage["y_from"] > other[1]):
                            self.error("scroll.%s se solapa con otro tramo" % tag)
                    bands.append((stage["y_from"], stage["y_to"]))
            speed_ok(stage.get("speed_tiles_s"), tag + ".speed_tiles_s")
        ids = set()
        for i, stop in enumerate(scroll.get("stops", [])):
            tag = "stops[%d]" % i
            if not isinstance(stop, dict) or set(stop) - {"id", "at_row", "resume_row"}:
                self.error("scroll.%s debe ser {id, at_row, resume_row}" % tag)
                continue
            if not isinstance(stop.get("id"), str) or not stop["id"] or stop["id"] in ids:
                self.error("scroll.%s: id debe ser un texto no vacio y unico" % tag)
            ids.add(stop.get("id"))
            if row_ok(stop.get("at_row"), tag + ".at_row") and row_ok(stop.get("resume_row"), tag + ".resume_row"):
                line = stop["at_row"] + 1
                if not line - view_rows - 2 <= stop["resume_row"] < line:
                    self.error("scroll.%s: resume_row debe quedar a la vista de la parada (o hasta 2 filas por "
                               "encima)" % tag)
        for i, rev in enumerate(scroll.get("reverses", [])):
            tag = "reverses[%d]" % i
            if not isinstance(rev, dict) or set(rev) - {"at_row", "duration_s", "speed_tiles_s"}:
                self.error("scroll.%s debe ser {at_row, duration_s, speed_tiles_s}" % tag)
                continue
            row_ok(rev.get("at_row"), tag + ".at_row")
            if not _is_number(rev.get("duration_s")) or not 0.0 < rev["duration_s"] <= 10.0:
                self.error("scroll.%s.duration_s debe estar entre 0 y 10 s" % tag)
            speed_ok(rev.get("speed_tiles_s"), tag + ".speed_tiles_s")
        safe_rows = []
        safe = scroll.get("safe_respawn")
        if not isinstance(safe, list) or not safe:
            self.error("scroll.safe_respawn debe ser una lista no vacia de celdas [x, y]")
            return
        for i, cell in enumerate(safe):
            if not (isinstance(cell, list) and len(cell) == 2 and all(_is_int(v) for v in cell)):
                self.error("scroll.safe_respawn[%d] debe ser [x, y]" % i)
                continue
            x, y = cell
            if not self.in_bounds(x, y) or not self.in_bounds(x, y + 1):
                self.error("scroll.safe_respawn[%d] fuera del grid" % i)
                continue
            if self.cell(x, y) in "#^" or self.cell(x, y + 1) not in "#-":
                self.error("scroll.safe_respawn[%d]: la celda debe estar libre y con suelo ('#' o '-') debajo"
                           % i, y, x)
                continue
            safe_rows.append(y)
        if not safe_rows:
            return
        safe_rows.sort()
        start_row = scroll.get("start_bottom_row", rows - 1)
        top_row = int(math.ceil(view_rows)) - 1
        if _is_int(start_row) and safe_rows[-1] < start_row - SCROLL_SAFE_GAP_ROWS:
            self.error("scroll.safe_respawn: ninguna tarjeta segura a %d filas o menos del inicio (fila %d)"
                       % (SCROLL_SAFE_GAP_ROWS, start_row))
        if safe_rows[0] > top_row + SCROLL_SAFE_GAP_ROWS:
            self.error("scroll.safe_respawn: ninguna tarjeta segura a %d filas o menos de lo alto (fila %d)"
                       % (SCROLL_SAFE_GAP_ROWS, top_row))
        for a, b in zip(safe_rows, safe_rows[1:]):
            if b - a > SCROLL_SAFE_GAP_ROWS:
                self.error("scroll.safe_respawn: entre las filas %d y %d no hay tarjeta segura (maximo %d filas)"
                           % (a, b, SCROLL_SAFE_GAP_ROWS))

    def _check_camera(self):
        """'camera' (opcional): {vertical: simple | tower, limits: grid}."""
        if "camera" not in self.level:
            return
        camera = self.level["camera"]
        if not isinstance(camera, dict):
            self.error("'camera' debe ser un objeto {vertical, limits}")
            return
        for key in camera:
            if key not in ("vertical", "limits"):
                self.error("camera: campo desconocido '%s'" % key)
        if camera.get("vertical", "simple") not in CAMERA_VERTICAL_MODES:
            self.error("camera.vertical '%s' no admitido (validos: %s)"
                       % (camera.get("vertical"), ", ".join(CAMERA_VERTICAL_MODES)))
        if camera.get("limits", "grid") not in CAMERA_LIMITS:
            self.error("camera.limits '%s' no admitido (validos: %s)" % (camera.get("limits"), ", ".join(CAMERA_LIMITS)))


    def _check_validation(self):
        """'validation' (opcional, 2026-10-16, paso 10 de docs/propuesta-1-2.md §10): parametros del
        diseno que comprueba tools/validate_level.py. time_margin_s (>= 0: lo que debe sobrar en
        ventanas y cuentas; 1,5 s por defecto), snooze_required (grupos de recordatorios que SOLO se
        cruzan con el Posponer), laser_required y debug_required (booleanos: la meta exige el laser /
        el Debug), start_energy (0-100, energia al empezar; 100 por defecto) y sync_damage_budget
        (>= 0, Sync Rate que pueden quitar los enemigos en el camino; 0 por defecto) y, desde el
        2026-10-17, ceiling_margin_px (0-64: holgura de techo calibrada con el Isak real; sin el campo,
        el modelo de techo del paso 10) y, desde el paso 9 de docs/propuesta-1-3.md, dash_required (ids
        de banners cuyo pasillo SOLO se cruza con el dash) y, desde el 2026-10-20 (bot del 1-3),
        hazard_margin_s (0-0,5: holgura de tiempo frente a banners, campanas y plataformas que parpadean
        en la busqueda por tiempo; 0 por defecto)."""
        if "validation" not in self.level:
            return
        val = self.level["validation"]
        if not isinstance(val, dict):
            self.error("'validation' debe ser un objeto")
            return
        numbers = {"time_margin_s": (0.0, 30.0), "start_energy": (0.0, 100.0), "sync_damage_budget": (0.0, 100.0),
                   "ceiling_margin_px": (0.0, 64.0), "hazard_margin_s": (0.0, 0.5)}
        for key, value in val.items():
            if key in numbers:
                lo, hi = numbers[key]
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not lo <= value <= hi:
                    self.error("validation.%s debe ser un numero entre %g y %g" % (key, lo, hi))
            elif key in ("laser_required", "debug_required"):
                if not isinstance(value, bool):
                    self.error("validation.%s debe ser un booleano" % key)
            elif key == "snooze_required":
                groups = {str(o.get("params", {}).get("group")) for o in self.level["objects"]
                          if isinstance(o, dict) and o.get("type") == "reminder_platform"}
                if not isinstance(value, list) or not all(isinstance(g, str) for g in value):
                    self.error("validation.snooze_required debe ser una lista de grupos de recordatorios")
                else:
                    for g in value:
                        if g not in groups:
                            self.error("validation.snooze_required: el grupo de recordatorios '%s' no existe" % g)
            elif key == "dash_required":
                # Paso 9 de docs/propuesta-1-3.md §6.1: banners cuyo pasillo SOLO se cruza con el dash.
                banners = {str(e.get("id")) for e in self.level.get("enemies", [])
                           if isinstance(e, dict) and e.get("type") == "spam_banner"}
                if not isinstance(value, list) or not value or not all(isinstance(b, str) for b in value) \
                        or len(set(value)) != len(value):
                    self.error("validation.dash_required debe ser una lista no vacia de ids de banners, sin repetir")
                else:
                    for b in value:
                        if b not in banners:
                            self.error("validation.dash_required: el banner '%s' no existe" % b)
            else:
                self.error("validation: campo desconocido '%s'" % key)


def validate_level(level, root=ROOT):
    """Devuelve la lista de errores (vacia si el nivel es valido)."""
    return LevelValidator(level, root).validate()


def validate_file(path, root=ROOT):
    try:
        with open(path, encoding="utf-8") as handle:
            level = json.load(handle)
    except (OSError, ValueError) as exc:
        return ["no se pudo leer %s (%s)" % (path, exc)]
    return validate_level(level, root)


def main(argv):
    if len(argv) < 2:
        print("Uso: python3 tools/validate_level_schema.py data/levels/<m>-<n>.json [...]", file=sys.stderr)
        return 2
    failed = False
    for path in argv[1:]:
        errors = validate_file(path)
        if errors:
            failed = True
            print("%s: %d error(es)" % (path, len(errors)))
            for message in errors:
                print("  - " + message)
        else:
            print("%s: OK" % path)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
