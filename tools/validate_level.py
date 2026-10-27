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
     4c. Mensaje de secreto (memory_pickup, 2026-10-19, paso 4 de
     docs/propuesta-recuerdos.md): cuenta como recogible del secreto que lo ofrece
     (recompensa memory con su memory_id) y respeta lo que ese secreto exige:
     con "needs_debug" no se alcanza sin Debug y si con el Debug (el del nivel o
     su chip, como en la regla 4); sin el, se alcanza sin Debug; con
     "requires_upgrade" no se alcanza sin la mejora y si con ella, y la mejora
     tiene que poder comprarse en el acceso del mensaje (first_lap de
     data/memories.json; min_lap de data/upgrades.json). Nunca es obligatorio.
     Mejoras (data/upgrades.json, pistas de Calc): el modelo usa los valores
     BASE salvo las mejoras de --upgrades ("pista:nivel", p. ej. laser:3, o un
     legacy_id: wide_pulse = pulso:2): alcance del pulso, coste y enfriamiento
     del laser, gasto del Debug y energia y Sync Rate maximos. Un
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
     alguna celda de pie alcanzable en el camino principal hacia G. Con
     countdown_s (cuenta automatica, cierre del 2-1, 2026-10-22) no hace falta
     el pulso: basta llegar a G; el plan espera la cuenta.
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
  8. Torre y tolerancia de techo (2026-10-16, paso 10 de docs/propuesta-1-2.md
     §10): al subir, la cabeza tambien se comprueba con el retraso de un salto
     desde parado + HEAD_MARGIN_PX (World.simulate head_lag): un salto que roza
     con la cabeza la esquina de una losa no cuenta. En niveles verticales el
     fallo dice piso y fila y las reglas por columnas (6d) no se aplican.
  9. Laser, Debug y tiempos (paso 10): el laser alcanza objetivos horizontales a
     la altura del celular (lector laser, anuncio, Posponer, Burbujas); el Debug
     (abilities_available.debug o su chip) da movimientos sobre 'h' (union de
     mundos, marcados "con Debug"); lector -> receptor enlazado -> puente dentro
     de window_s (relay_plan), anuncio antes del pulso al pop-up y barra del 99 %
     (espera). validation.laser_required / debug_required del nivel. El plan del
     camino (tools/level_plan.py) comprueba recordatorios y Posponer, pop-ups
     translucidos, tramos con Debug, banners, puntos rojos y energia, y exporta el
     camino (--export-path, formato isak-path/1). Solo los niveles del paso 10
     (Validator.is_advanced) llevan el plan en la salida: la del 1-1 no cambia.
  10. Dash, ritmo, tunel y campanas del 1-3 (paso 9 de docs/propuesta-1-3.md, 2026-10-20): el dash es
     estado del grafo (abilities_available.dash o el interruptor No molestar, dnd_switch) con movimientos
     en el suelo y en el aire (World.compute_dash_edges; nunca con el Debug); el plan cuenta su energia,
     su enfriamiento y su invulnerabilidad frente a banners y campanas, sigue los metronomos y las
     plataformas que parpadean, comprueba validation.dash_required y exporta pasos dash y wait_beat.
     forbid_abilities de un secreto: su ruta se busca sin esas habilidades (LevelModel.forbidding).
  11. Mundo 3 (paso 8a de docs/propuesta-mundo-3.md, 2026-10-26; tools/world3_model.py, LevelModel.w3): Pellizcar
     (nodos comprimidos y aristas pinch / unpinch), likes (corazones, publicaciones y reset como acciones de la
     progresion; plataformas por umbral; anti-atasco), filtros (Debug junto a lo que esconden; cargador a la
     vista) y espejos fijos (laser con rebotes, plataformas del reflejo). Sin nada del Mundo 3, w3 es None.
     Paso 8b: espejo cazador (pulso reflejado como arista hacia los receptores, receiver_hits; orientacion por
     tiempo en el plan), placas «Posa aqui» y puertas de marco (accion de la progresion; tiempo en el plan),
     Influencer, Ladron y Reflejo falso (simulados en el plan, que inserta pulsos y esperas) y secretos con
     requires_abilities (_granted: se comprueban con esas habilidades).

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
          [--upgrades pulso:2[,laser:3,...]] [--time-margin 1.5]
          [--export-path camino.json]
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
import upgrade_catalog  # noqa: E402
import level_catalog  # noqa: E402
import world2_model  # noqa: E402
import world3_model  # noqa: E402

DEFAULT_LIMIT = 0.85
DEFAULT_JUMP_EFFICIENCY = 0.92
SIM_DT = 1.0 / 60.0
SIM_MAX_S = 4.0
EPS = 1e-6
# Paso del muestreo de posiciones de pie dentro de una celda al comprobar el pulso.
PULSE_SAMPLE_PX = 4.0
# Tolerancia de techo (2026-10-16, paso 10 de docs/propuesta-1-2.md): margen conservador, en px,
# que se suma al retraso de un salto desde parado al comprobar la cabeza contra la esquina de
# una losa (unos 2 cuadros a 220 px/s). Ver World.simulate(head_lag=True).
HEAD_MARGIN_PX = 8.0
# Holgura de techo calibrada con el Isak real (2026-10-17, tests/test_level_climbs.gd): con
# validation.ceiling_margin_px en el nivel, una SUBIDA (salto que aterriza mas arriba) solo vale si,
# mientras sube, la cabeza queda a ceiling_margin_px o mas de todo solido de encima (con la altura
# real del salto a 60 Hz, no la de --jump-efficiency) y la caja queda a CORNER_MARGIN_PX o mas de la
# esquina de una losa (un solido por encima de la cabeza al despegar que no es una pared), tanto
# donde la pone el modelo como donde estaria despegando desde parado (sin los 8 px de
# HEAD_MARGIN_PX). Sin el campo, el modelo de techo del paso 10 no cambia (la salida del 1-1 es la
# misma byte a byte).
CORNER_MARGIN_PX = 8.0
# Tiempos del plan (paso 10): margen minimo por defecto que debe sobrar en ventanas y cuentas
# (validation.time_margin_s del nivel o --time-margin), arranque desde parado tras un salto o una
# pose y retraso del pulso desde que se pulsa hasta que toca (un cuadro).
DEFAULT_TIME_MARGIN_S = 1.5
START_S = 0.06
PULSE_DELAY_S = 1.0 / 60.0
INF = float("inf")
# Dash (paso 9 de docs/propuesta-1-3.md §6.1): instantes del arco de un salto en los que se prueba el
# dash aereo (cada DASH_SAMPLE_S desde el despegue hasta la cumbre + DASH_AFTER_APEX_S) y coste extra
# de un movimiento con dash en la busqueda del camino (gasta energia: solo se usa si hace falta).
DASH_SAMPLE_S = 0.05
DASH_AFTER_APEX_S = 0.15
DASH_SEARCH_COST = 0.2
# Mundo 3 (paso 8a, tools/world3_model.py): coste extra de cada movimiento comprimido en la busqueda.
PINCH_SEARCH_COST = world3_model.PINCH_SEARCH_COST


# --- Datos ---

def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def load_upgrades(root=ROOT):
    """Catalogo de mejoras de Calc por pistas (data/upgrades.json; tools/upgrade_catalog.py)."""
    return upgrade_catalog.load_catalog(root)


def effective_value(catalog, levels, target, base):
    """Igual que GameState.effective_value: `levels` es {pista: nivel} (parse_upgrades)."""
    return upgrade_catalog.effective_value(catalog, levels, target, base)


def _export_vector2(source, name):
    match = re.search(r"var %s\s*:\s*Vector2\s*=\s*Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)" % name, source)
    if not match:
        raise ValueError("no se encuentra '%s' en scripts/player/isak.gd" % name)
    return float(match.group(1)), float(match.group(2))


def sprite_frames(root, res_path):
    """Animaciones de un SpriteFrames .tres: nombre -> (cuadros, fps). Igual que
    SpriteFrames.get_frame_count / get_animation_speed (lo usan CalcActor y GlitchWall para sus
    tiempos)."""
    path = os.path.join(root, res_path.replace("res://", ""))
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return {}
    out = {}
    pattern = r'"frames":\s*\[(.*?)\],\s*"loop":\s*(?:true|false),\s*"name":\s*&"([\w]+)",\s*"speed":\s*([\d.]+)'
    for frames, name, speed in re.findall(pattern, text, re.S):
        out[name] = (frames.count('"texture"'), float(speed))
    return out


def anim_length(frames, name):
    count, speed = frames.get(name, (0, 1.0))
    return count / max(speed, 0.001)


def real_jump_height(v0, gravity, dt=SIM_DT):
    """Altura que sube Isak en el juego con un salto completo: velocidad inicial v0 (> 0 hacia
    arriba), la gravedad se aplica a la velocidad antes de moverse en cada cuadro de dt."""
    v, h = v0, 0.0
    while True:
        v -= gravity * dt
        if v <= 0.0:
            return h
        h += v * dt


class Rules:
    """Valores de juego que usa el modelo (todos leidos de los datos del proyecto)."""

    def __init__(self, root=ROOT, physics_path=None, jump_efficiency=DEFAULT_JUMP_EFFICIENCY,
                 limit=DEFAULT_LIMIT, allow_run=False, upgrades=(), allies=()):
        physics = load_json(physics_path or os.path.join(root, "data", "isak_physics.json"))
        # Asistentes ya conocidos (allies_met; tanda H2 del paso 14 del 1-2, 2026-10-17): las piezas
        # con done_if_ally de uno de ellos arrancan hechas (el acertijo de Calc no se repite).
        self.allies = tuple(allies)
        abilities = load_json(os.path.join(root, "data", "isak_abilities.json"))
        with open(os.path.join(root, "scripts", "player", "isak.gd"), encoding="utf-8") as handle:
            isak_source = handle.read()
        self.root = root
        self.gravity = float(physics["gravity"])
        self.fall_mult = float(physics["fall_gravity_multiplier"])
        self.walk_speed = float(physics["walk_speed"])
        self.run_speed = float(physics["run_speed"])
        # Aceleracion horizontal en el aire (scripts/player/isak.gd, apply_horizontal): con ella se
        # calcula el retraso de un salto desde parado frente al modelo de velocidad constante
        # (tolerancia de techo, 2026-10-16, paso 10 de docs/propuesta-1-2.md).
        self.air_accel = float(physics.get("air_acceleration", 0.0))
        self.ground_accel = float(physics.get("ground_acceleration", 0.0))
        self.tile = float(physics["tile_size"])
        self.coyote_s = float(physics["coyote_time_s"])
        jump_velocity = float(physics["jump_velocity"])
        self.nominal_height = jump_velocity * jump_velocity / (2.0 * self.gravity)
        self.jump_efficiency = float(jump_efficiency)
        self.jump_height = self.nominal_height * self.jump_efficiency
        self.jump_v0 = math.sqrt(2.0 * self.gravity * self.jump_height)
        # Altura real del salto en el juego (Isak.step a 60 Hz: la gravedad cambia la velocidad antes
        # de mover; unos 184 px): la usa la holgura de techo calibrada (ceiling_margin_px).
        self.real_jump_height = real_jump_height(-jump_velocity, self.gravity)
        # Velocidad inicial real del salto (px/s, > 0 hacia arriba): la usa el arco real de la busqueda por
        # tiempo (World.simulate con game=True; 2026-10-20, bot del 1-3).
        self.jump_v0_game = -jump_velocity
        self.limit = float(limit)
        self.allow_run = bool(allow_run)
        self.hitbox_w, self.hitbox_h = _export_vector2(isak_source, "hitbox_size")
        self.phone_x, self.phone_y = _export_vector2(isak_source, "pulse_effect_origin")
        self.base_pulse_radius = float(abilities["pulse_radius_px"])
        self.laser_range = float(abilities.get("laser_range_px", 0.0))
        self.laser_thickness = float(abilities.get("laser_thickness_px", 4.0))
        # Tiempos y energia de las habilidades (paso 10, plan del camino): pose del pulso, pose del
        # laser (anticipacion + brazo extendido, Isak.laser_pose_hold_s; bloquea el movimiento),
        # enfriamiento, coste y velocidad del proyectil; Debug (data/debug_mode.json) y energia maxima
        # (scripts/autoload/game_state.gd).
        self.pulse_pose_s = float(abilities.get("pulse_duration_s", 0.3333))
        hold = re.search(r"var laser_pose_hold_s\s*:\s*float\s*=\s*([\d.]+)", isak_source)
        self.laser_pose_s = float(abilities.get("laser_windup_s", 0.05)) + (float(hold.group(1)) if hold else 0.25)
        self.laser_cooldown_s = float(abilities.get("laser_cooldown_s", 0.4))
        self.laser_cost = float(abilities.get("laser_energy_cost", 10.0))
        self.laser_speed = float(abilities.get("laser_speed_px_s", 1200.0))
        debug_cfg = load_json(os.path.join(root, "data", "debug_mode.json"))
        self.debug_hold_s = float(debug_cfg.get("activation_hold_s", 1.0))
        self.debug_drain = float(debug_cfg.get("drain_per_second", 20.0))
        self.debug_world_scale = float(debug_cfg.get("world_time_scale", 0.5))
        self.debug_fade_s = float(debug_cfg.get("fade_in_s", 0.15))
        with open(os.path.join(root, "scripts", "autoload", "game_state.gd"), encoding="utf-8") as handle:
            energy = re.search(r"const DEBUG_ENERGY_MAX\s*:\s*float\s*=\s*([\d.]+)", handle.read())
        self.energy_max = float(energy.group(1)) if energy else 100.0
        sync = re.search(r"const SYNC_RATE_MAX\s*:\s*float\s*=\s*([\d.]+)", open(
            os.path.join(root, "scripts", "autoload", "game_state.gd"), encoding="utf-8").read())
        self.sync_max = float(sync.group(1)) if sync else 100.0
        # Dash (gesto Deslizar, 1-3; paso 9 de docs/propuesta-1-3.md §6.1): seccion dash de
        # data/isak_abilities.json. Tramo horizontal de dash_distance en dash_duration (gravedad 0),
        # invulnerable dash_invulnerable_s desde su inicio, dash_cost de energia al salir y
        # dash_cooldown_s desde el final; un dash aereo por salto. Tiempo real (no lo ralentiza el Debug).
        dash = abilities.get("dash", {}) if isinstance(abilities.get("dash"), dict) else {}
        self.dash_distance = float(dash.get("distance_px", 192.0))
        self.dash_duration = float(dash.get("duration_s", 0.2))
        self.dash_invulnerable_s = float(dash.get("invulnerable_s", 0.3))
        self.dash_cost = float(dash.get("energy_cost", 10.0))
        self.dash_cooldown_s = float(dash.get("cooldown_s", 0.5))
        self.dash_end_speed = float(dash.get("end_speed_px_s", 360.0))
        self.air_dashes = int(dash.get("air_dashes", 1))
        # Golpe al suelo (gesto Mantener presionado, Mundo 2; paso 9 de docs/propuesta-mundo-2.md §7.1):
        # seccion ground_pound de data/isak_abilities.json. Onda a ras de suelo (medio ancho, alto y margen
        # bajo los pies) y tiempos: carga en el suelo, saltito, caida y pose al aterrizar (tiempo real).
        pound = abilities.get("ground_pound", {}) if isinstance(abilities.get("ground_pound"), dict) else {}
        self.pound_hold_s = float(pound.get("ground_hold_s", 0.35))
        self.pound_hop_px = float(pound.get("ground_hop_px", 32.0))
        self.pound_drop_speed = float(pound.get("drop_speed_px_s", 960.0))
        self.pound_half_width = float(pound.get("wave_half_width_px", 96.0))
        self.pound_height = float(pound.get("wave_height_px", 64.0))
        self.pound_below = float(pound.get("wave_below_px", 8.0))
        self.pound_pose_s = float(pound.get("land_pose_s", 0.35))
        hop_up = math.sqrt(2.0 * max(self.pound_hop_px, 0.0) / self.gravity) if self.gravity > 0 else 0.0
        self.pound_s = self.pound_hold_s + hop_up + self.pound_hop_px / max(self.pound_drop_speed, 1.0) \
            + self.pound_pose_s
        # Paso 9b: la onda sale al aterrizar (antes de la pose) y entre dos golpes seguidos (muro «Cargando
        # mas...», 3 golpes) pasa el enfriamiento cooldown_s, que empieza al terminar la pose.
        self.pound_land_s = self.pound_s - self.pound_pose_s
        self.pound_cooldown_s = float(pound.get("cooldown_s", 0.4))
        self.time_margin = None  # --time-margin (si no, validation.time_margin_s del nivel o 1,5 s)
        self.physics_path = physics_path
        # Mejoras de Calc (tanda M1, 2026-10-17): --upgrades acepta "pista:nivel" (p. ej. laser:3) y los
        # legacy_id (wide_pulse = pulso:2). Se guardan tal cual (la salida los repite) y se resuelven a
        # niveles; el modelo usa el alcance del pulso, el coste y el enfriamiento del laser, el gasto del
        # Debug y los maximos de energia y Sync Rate de esos niveles (la misma regla que el juego).
        self.upgrades = tuple(upgrades)
        catalog = load_upgrades(root)
        self.upgrade_catalog = catalog
        self.upgrade_levels = upgrade_catalog.parse_upgrades(catalog, self.upgrades)
        self.base_laser_cost = self.laser_cost
        self.base_laser_cooldown_s = self.laser_cooldown_s
        self.base_debug_drain = self.debug_drain
        self.base_energy_max = self.energy_max
        self.base_sync_max = self.sync_max
        self.base_debug_world_scale = self.debug_world_scale
        self.base_debug_hold_s = self.debug_hold_s
        levels = self.upgrade_levels
        self.pulse_radius = effective_value(catalog, levels, "isak_abilities.pulse_radius_px", self.base_pulse_radius)
        self.laser_cost = effective_value(catalog, levels, "isak_abilities.laser_energy_cost", self.laser_cost)
        self.laser_cooldown_s = effective_value(catalog, levels, "isak_abilities.laser_cooldown_s",
                                                self.laser_cooldown_s)
        self.debug_drain = effective_value(catalog, levels, "debug_mode.drain_per_second", self.debug_drain)
        self.energy_max = effective_value(catalog, levels, "game_state.debug_energy_max", self.energy_max)
        self.sync_max = effective_value(catalog, levels, "game_state.sync_rate_max", self.sync_max)
        # Tanda M2 (2026-10-17): Debug 4 (el mundo a x0,4: las cuentas del mundo duran mas en tiempo real con
        # el Debug activo; el gasto sigue en tiempo real) y Debug 5 (carga de 0,4 s). El Debug 3 (revelado
        # persistente) solo da margen: el modelo sigue exigiendo el Debug activo para pisar lo oculto. El
        # Laser 5 (perfora) atraviesa enemigos y nunca el terreno ni los objetos del laser: el modelo no tiene
        # enemigos que tapen el haz, asi que no cambia ningun objetivo. Ocultarte y la regeneracion pasiva
        # (Sync 5, Energia 5) se ignoran (el presupuesto de energia no cuenta con recarga pasiva).
        self.debug_world_scale = effective_value(catalog, levels, "debug_mode.world_time_scale", self.debug_world_scale)
        self.debug_hold_s = effective_value(catalog, levels, "debug_mode.activation_hold_s", self.debug_hold_s)
        # Escala del mundo con el Debug propia del nivel (debug_world_scale; 2026-10-21,
        # docs/propuesta-jefe-alerta-mayor.md §6.4): None = la global; si no, set_level_debug_world_scale.
        self.config_debug_world_scale = self.base_debug_world_scale
        self.level_debug_world_scale = None

    def set_level_debug_world_scale(self, scale):
        """Escala del mundo con el Debug del nivel (debug_world_scale; None = la global). Sustituye a la base
        (0,5) y conserva la proporcion de las mejoras (Debug 4: 0,4 / 0,5), como DebugMode.get_world_time_scale."""
        if scale is None:
            return
        scale = float(scale)
        ratio = self.debug_world_scale / self.config_debug_world_scale if self.config_debug_world_scale > 0 else 1.0
        self.level_debug_world_scale = scale
        self.base_debug_world_scale = scale
        self.debug_world_scale = min(max(scale * ratio, 0.0), 1.0)

    def has_upgrade(self, upgrade_id):
        """Con las mejoras de --upgrades se tiene `upgrade_id` ("pista:nivel" o legacy_id)."""
        return upgrade_catalog.satisfies(self.upgrade_catalog, self.upgrade_levels, upgrade_id)

    def changed_by_upgrades(self):
        """Valores (aparte del pulso) que las mejoras cambian respecto a la base: {clave: (valor, base)}."""
        out = {}
        for key, value, base in (("laser_energy_cost", self.laser_cost, self.base_laser_cost),
                                 ("laser_cooldown_s", self.laser_cooldown_s, self.base_laser_cooldown_s),
                                 ("debug_drain_per_s", self.debug_drain, self.base_debug_drain),
                                 ("energy_max", self.energy_max, self.base_energy_max),
                                 ("sync_rate_max", self.sync_max, self.base_sync_max),
                                 ("debug_world_time_scale", self.debug_world_scale, self.base_debug_world_scale),
                                 ("debug_hold_s", self.debug_hold_s, self.base_debug_hold_s)):
            if abs(value - base) > EPS:
                out[key] = (value, base)
        return out

    def with_upgrades(self, extra):
        """Las mismas reglas con mas mejoras compradas."""
        ups = self.upgrades + tuple(u for u in extra if u not in self.upgrades)
        rules = Rules(self.root, self.physics_path, self.jump_efficiency, self.limit, self.allow_run, ups,
                      self.allies)
        rules.time_margin = self.time_margin
        rules.set_level_debug_world_scale(self.level_debug_world_scale)
        return rules

    def with_allies(self, allies):
        """Las mismas reglas con estos asistentes ya conocidos."""
        rules = Rules(self.root, self.physics_path, self.jump_efficiency, self.limit, self.allow_run, self.upgrades,
                      tuple(allies))
        rules.time_margin = self.time_margin
        rules.set_level_debug_world_scale(self.level_debug_world_scale)
        return rules

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

    def standing_lag(self, t, speed, extra=HEAD_MARGIN_PX):
        """Px que va por detras, a los `t` s de despegar, un salto desde parado (aceleracion
        air_acceleration hasta `speed`) frente al modelo de velocidad constante `speed`, mas
        HEAD_MARGIN_PX (despegar un par de cuadros tarde o algo antes del borde de la celda)."""
        if t <= 0.0:
            return 0.0
        if self.air_accel <= 0.0:
            return extra
        t_full = speed / self.air_accel
        if t < t_full:
            return speed * t - 0.5 * self.air_accel * t * t + extra
        return speed * t_full - 0.5 * self.air_accel * t_full * t_full + extra


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
        self.kind = kind  # bridge, popup, bubble, pickup; ad (anuncio, laser) y bar (barra del 99 %, espera)
        self.obj_id = obj_id
        self.cells = cells or []  # celdas solidas/apoyo (puente al abrir, pop-up al cerrar)
        self.rect = rect  # zona de dano (Burbuja)
        self.openers = openers or []  # rectangulos que el pulso debe tocar (px): (x0, y0, x1, y1, que)
        self.col = col
        self.row = row
        self.bypassable = False
        # Asistente que, conocido, deja la puerta hecha desde el principio (done_if_ally).
        self.done_if_ally = ""
        cols = [c for c, _ in self.cells]
        if rect is not None:
            cols += [int(rect[0] // tile), int(rect[2] // tile)]
        self.col_span = (min(cols), max(cols)) if cols else (col, col)

    def label(self):
        names = {"bridge": "puente", "popup": "pop-up", "bubble": "Burbuja", "pickup": "objeto de habilidad",
                 "terminal": "terminal de salida", "ad": "anuncio", "bar": "barra del 99 %",
                 "switch": "interruptor de pulso", "lswitch": "interruptor laser", "dock": "punto de carga",
                 "dnd": "interruptor No molestar", "pound": "tarjeta fragil",
                 "heart": "corazon", "like_source": "publicacion", "like_reset": "Borrar publicaciones",
                 "plate": "placa Posa aqui"}
        if getattr(self, "encounter", False):
            return "encuentro con Eco %s" % self.obj_id
        if self.kind == "switch" and getattr(self, "hidden", False):
            return "panel oculto %s" % self.obj_id
        if self.kind == "pound" and getattr(self, "wall", False):
            return "muro Cargando mas %s" % self.obj_id
        if self.kind == "dnd" and getattr(self, "player", False):
            return "reproductor %s" % self.obj_id
        if self.kind == "dnd" and getattr(self, "crop", False):
            return "herramienta Recortar %s" % self.obj_id
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
        self.catalog = level_catalog.load_catalog(rules.root, world)
        self.hazard_data = load_json(os.path.join(rules.root, "data", "hazards.json"))
        self.pulse = bool(level.get("abilities_available", {}).get("pulse", False))
        self.laser_base = bool(level.get("abilities_available", {}).get("laser", False))
        self.bridge_thickness = float(self.catalog.get("bridge", {}).get("collision_height_px", self.T))
        self.glitch = set()
        # Recordatorios (2026-10-16, paso 6 de docs/propuesta-1-2.md §10): PROVISIONAL, tabla
        # solida fina siempre presente (sin su cuenta, su caida ni el Posponer: paso 10).
        self.reminders = {}
        # Plataformas que parpadean (blink_platform, 1-3): en el grafo son tablas siempre presentes; el plan
        # del camino (tools/level_plan.py, paso 9 de docs/propuesta-1-3.md) solo deja pisarlas (o tocarlas)
        # mientras su metronomo las tiene encendidas. blink_items: {"id", "rhythm", "on_fraction", "offset",
        # "rect" (tarjeta en px), "cells"}.
        self.blinks = {}
        self.blink_items = []
        # Metronomos (rhythm_zone) y tuneles de alarmas (alarm_tunnel) por id (paso 9).
        self.zones = {}
        # Habilidades que una comprobacion prohibe (forbid_abilities de un secreto, paso 9): mientras
        # esten aqui, has_dash / has_laser / has_debug / has_pulse las dan por no disponibles.
        self.forbidden = frozenset()
        # Paso 10 (2026-10-16, docs/propuesta-1-2.md §10): objetos con tiempo, laser y Debug que usa
        # el plan del camino (tools/level_plan.py). Los recordatorios siguen siendo tablas en el grafo;
        # su cuenta, su caida y el Posponer se comprueban en el plan.
        self.reminder_groups = {}  # grupo -> {"cells", "timer", "warn", "respawn", "ids"}
        self.reminder_group_of = {}  # celda -> grupo
        self.lectors = {}  # id del lector laser -> {"rect", "target", "window", "cell"}
        self.snoozes = []  # botones Posponer: {"id", "rect", "targets", "extend", "cap", "cooldown", "cell"}
        self.overlays = []  # pop-ups translucidos: {"id", "cells", "button", "cell"}
        self.chargers = []  # cargadores: {"id", "cell", "rect", "amount", "reusable", "cooldown"}
        abilities = level.get("abilities_available", {})
        self.debug_base = bool(abilities.get("debug", False))
        self.dash_base = bool(abilities.get("dash", False))
        # Golpe al suelo (Mundo 2, paso 9 de docs/propuesta-mundo-2.md): abilities_available.ground_pound.
        self.pound_base = bool(abilities.get("ground_pound", False))
        self.validation = level.get("validation", {}) if isinstance(level.get("validation"), dict) else {}
        # Holgura de techo calibrada (2026-10-17): None = modelo del paso 10 (HEAD_MARGIN_PX).
        margin = self.validation.get("ceiling_margin_px")
        self.ceiling_margin = None if margin is None else float(margin)
        self._relay_cache = {}
        self.gates = []
        # Acertijo de la azotea del 1-2 (encuentro con Calc; tanda H2 del paso 14, 2026-10-17): celdas
        # de una pared con glitch que se vuelve puerta -> gid del interruptor (door_when), terminal que
        # necesita corriente y piezas que arrancan hechas con su asistente conocido.
        self.glitch_doors = {}
        self.glitch_walls = []  # {"id", "cells", "door_when"}
        self.terminal_power = []  # {"id", "source", "cell"}
        # Mundo 3 (paso 8a): Pellizcar, likes, filtros y espejos (tools/world3_model.py); None sin nada del Mundo 3.
        self.w3 = None
        self._build_objects()
        self._door_gids = set(self.glitch_doors.values())
        self.has_pound_gates = any(g.kind == "pound" for g in self.gates)
        allies = set(rules.allies)
        self.initial = frozenset(g.gid for g in self.gates if g.done_if_ally and g.done_if_ally in allies)
        # Las piezas con done_if_ally (para validar tambien el caso «asistente conocido»).
        self.ally_pieces = sorted({g.done_if_ally for g in self.gates if g.done_if_ally})
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
        # Hay dash en el nivel (abilities_available.dash o el interruptor No molestar; paso 9 del 1-3).
        self.dash_possible = self.dash_base or any(g.kind == "dnd" and g.ability == "dash" for g in self.gates)
        # Hay golpe al suelo (abilities_available.ground_pound o un reproductor con el boton de pausa que lo da;
        # paso 9b de docs/propuesta-mundo-2.md).
        self.pound_possible = self.pound_base or any(g.kind == "dnd" and g.ability == "ground_pound"
                                                     for g in self.gates)
        # Pasillos de los banners de validation.dash_required (paso 10 del 1-3, 2026-10-20): sin el dash son un
        # peligro del grafo (como una Burbuja sin aturdir): el golpe devuelve a la entrada y el plan demuestra
        # que ni andando ni corriendo se cruzan; con el dash, el plan busca el cruce al compas.
        self.dash_corridors = self._dash_corridors()
        if world3_model.has_world3(level):
            self.w3 = world3_model.World3(self, Gate)

    # Objetos.
    def _params(self, obj):
        entry = self.catalog["types"].get(obj["type"], {})
        params = dict(entry.get("defaults", {}))
        params.update(obj.get("params", {}))
        return params

    def _build_objects(self):
        T = self.T
        receivers = {}
        relays = {}  # id del puente -> id del receptor enlazado que lo extiende
        cfg_receiver = self.catalog.get("receiver", {})
        hit = cfg_receiver.get("hit_rect", [0, 0, T, T])

        def cell_rect(obj, rect, what):
            x0, y0 = obj["x"] * T + float(rect[0]), obj["y"] * T + float(rect[1])
            return (x0, y0, x0 + float(rect[2]), y0 + float(rect[3]), what)

        for obj in self.level.get("objects", []):
            p = self._params(obj)
            # relay_receiver (2026-10-16): receptor del pulso que solo responde con la corriente de su
            # lector laser (laser_receiver con target = su id) dentro de la ventana (paso 10: el
            # progreso lo abre solo si el camino dispara al lector y llega a tiempo; ver relay_plan).
            if obj["type"] in ("receiver", "relay_receiver"):
                rhit = self.catalog.get(obj["type"], {}).get("hit_rect", hit) if obj["type"] == "relay_receiver" else hit
                x0 = obj["x"] * T + rhit[0]
                y0 = obj["y"] * T + rhit[1]
                rect = (x0, y0, x0 + rhit[2], y0 + rhit[3], "receptor (fila %d, columna %d)" % (obj["y"], obj["x"]))
                receivers.setdefault(str(p.get("target", "")), []).append(rect)
                if obj["type"] == "relay_receiver":
                    relays[str(p.get("target", ""))] = str(p.get("id", ""))
            elif obj["type"] == "laser_receiver":
                cfg = self.catalog.get("laser_receiver", {})
                lid = str(p.get("id", ""))
                window = float(p.get("window_s", cfg.get("window_s", 6.0)) or cfg.get("window_s", 6.0))
                self.lectors[lid] = {"id": lid, "rect": cell_rect(obj, cfg.get("hit_rect", [0, 0, T, T]),
                                                                  "lector %s" % lid),
                                     "target": str(p.get("target", "")), "window": window,
                                     "cell": (obj["x"], obj["y"])}
            elif obj["type"] == "snooze_button":
                cfg = self.catalog.get("snooze_button", {})
                sid = str(p.get("id", "snooze_%d_%d" % (obj["x"], obj["y"])))
                self.snoozes.append({"id": sid, "rect": cell_rect(obj, cfg.get("hit_rect", [0, 0, T, T]),
                                                                  "Posponer %s" % sid),
                                     "targets": [str(t) for t in p.get("targets", [])],
                                     "extend": float(p.get("extend_s", 4.0)), "cap": float(p.get("cap_s", 8.0)),
                                     "cooldown": float(p.get("cooldown_s", 1.0)), "cell": (obj["x"], obj["y"])})
            elif obj["type"] == "overlay_popup":
                oid = str(p.get("id", "overlay_%d_%d" % (obj["x"], obj["y"])))
                w, h = int(p.get("width_tiles", 1)), int(p.get("height_tiles", 1))
                button = p.get("close_button_px", [0, 0])
                size = float(p.get("close_button_size_px", 24))
                bx, by = obj["x"] * T + float(button[0]), obj["y"] * T + float(button[1])
                self.overlays.append({"id": oid, "cell": (obj["x"], obj["y"]),
                                      "cells": {(obj["x"] + dx, obj["y"] + dy) for dy in range(h) for dx in range(w)},
                                      "button": (bx, by, bx + size, by + size, "boton de cerrar de %s" % oid),
                                      "cover": None})
            elif obj["type"] == "charger":
                size = self.catalog.get("charger", {}).get("size_px", [32, 64])
                x0 = obj["x"] * T + (T - float(size[0])) * 0.5
                y1 = (obj["y"] + 1) * T
                self.chargers.append({"id": str(p.get("id", "charger_%d_%d" % (obj["x"], obj["y"]))),
                                      "cell": (obj["x"], obj["y"]),
                                      "rect": (x0, y1 - float(size[1]), x0 + float(size[0]), y1),
                                      "amount": float(p.get("amount", 50.0)), "reusable": bool(p.get("reusable", True)),
                                      "cooldown": float(p.get("cooldown_s", 20.0))})
            elif obj["type"] == "reminder_platform":
                cfg = self.catalog.get("reminder_platform", {})
                thickness = float(cfg.get("card_height_px", T))
                group = str(p.get("group", ""))
                info = self.reminder_groups.setdefault(group, {
                    "group": group, "cells": set(), "ids": [], "timer": float(p.get("timer_s", 2.5)),
                    "warn": float(p.get("warn_s", 0.5)), "respawn": float(p.get("respawn_s", 3.0))})
                info["ids"].append(str(p.get("id", "reminder_%d_%d" % (obj["x"], obj["y"]))))
                for dx in range(int(p.get("width_tiles", 1))):
                    self.reminders[(obj["x"] + dx, obj["y"])] = thickness
                    info["cells"].add((obj["x"] + dx, obj["y"]))
                    self.reminder_group_of[(obj["x"] + dx, obj["y"])] = group
            elif obj["type"] == "blink_platform":
                # Plataforma que parpadea (1-3, paso 5 de docs/propuesta-1-3.md): tabla siempre presente en
                # el grafo; el plan (paso 9) solo la deja pisar encendida (su metronomo, on_fraction, offset).
                thickness = float(self.catalog.get("blink_platform", {}).get("card_height_px", T))
                width = int(p.get("width_tiles", 2))
                cells = []
                for dx in range(width):
                    self.blinks[(obj["x"] + dx, obj["y"])] = thickness
                    cells.append((obj["x"] + dx, obj["y"]))
                self.blink_items.append({
                    "id": str(p.get("id", "blink_%d_%d" % (obj["x"], obj["y"]))), "rhythm": str(p.get("rhythm", "") or ""),
                    "on_fraction": float(p.get("on_fraction", 0.5)), "offset": float(p.get("offset", 0.0)),
                    "rect": (obj["x"] * T, obj["y"] * T, (obj["x"] + width) * T, obj["y"] * T + thickness),
                    "cells": cells, "cell": (obj["x"], obj["y"])})
            elif obj["type"] in ("rhythm_zone", "alarm_tunnel"):
                # Metronomo / tunel de alarmas (paso 9): lo usan los banners y campanas con rhythm y las
                # plataformas que parpadean (RhythmZone / AlarmTunnel).
                zid = str(p.get("id", "%s_%d_%d" % (obj["type"], obj["x"], obj["y"])))
                zone = [int(v) for v in p.get("zone", [obj["x"], obj["y"], 1, 1])]
                self.zones[zid] = {
                    "id": zid, "type": obj["type"], "cell": (obj["x"], obj["y"]), "cells": zone,
                    "rect": (zone[0] * T, zone[1] * T, (zone[0] + zone[2]) * T, (zone[1] + zone[3]) * T),
                    "start": str(p.get("start", "on_enter")),
                    "tempo": [float(v) for v in p.get("tempo_steps_s", [])] or [1.0],
                    "cycles_per_step": max(int(p.get("cycles_per_step", 4)), 1),
                    "loop": bool(p.get("loop", True)),
                    "stages": [dict(s) for s in p.get("stages", [])] if obj["type"] == "alarm_tunnel" else []}
            elif obj["type"] == "glitch_wall":
                cells = []
                for dy in range(int(p.get("height_tiles", 1))):
                    for dx in range(int(p.get("width_tiles", 1))):
                        self.glitch.add((obj["x"] + dx, obj["y"] + dy))
                        cells.append((obj["x"] + dx, obj["y"] + dy))
                door = str(p.get("door_when", "") or "")
                self.glitch_walls.append({"id": str(p.get("id", "glitch_%d_%d" % (obj["x"], obj["y"]))),
                                          "cells": cells, "door_when": door, "cell": (obj["x"], obj["y"])})
                if door:
                    # Puerta (paso 14 del 1-2): con su interruptor activado deja de ser solida para siempre.
                    for cell in cells:
                        self.glitch_doors[cell] = "switch:" + door
            elif obj["type"] == "exit_terminal" and p.get("requires_power"):
                self.terminal_power.append({"id": str(p.get("id", "terminal_%d_%d" % (obj["x"], obj["y"]))),
                                            "source": str(p.get("power_source", "") or ""),
                                            "cell": (obj["x"], obj["y"])})
        for obj in self.level.get("objects", []):
            p = self._params(obj)
            if obj["type"] == "bridge_inactive":
                length = int(p.get("length_tiles", 1))
                step = 1 if p.get("direction", "right") == "right" else -1
                cells = [(obj["x"] + i * step, obj["y"]) for i in range(length)]
                bid = str(p.get("id", ""))
                gate = Gate("bridge:" + bid, "bridge", bid, cells=cells,
                            openers=receivers.get(bid, []), col=obj["x"], row=obj["y"], tile=T)
                if bid in relays:
                    rid = relays[bid]
                    gate.relay = {"id": rid, "lector": next((lec for lec in self.lectors.values()
                                                             if lec["target"] == rid), None)}
                self.gates.append(gate)
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
            elif obj["type"] == "update_bar":
                # Barra del 99 % (paso 10): puerta solida de 1 x 3 que se abre sola tras la espera
                # (rise_s + wait_s + full_s de tiempo del mundo) cuando Isak entra en su zona.
                cfg = self.catalog.get("update_bar", {})
                bid = str(p.get("id", "bar_%d_%d" % (obj["x"], obj["y"])))
                gate = Gate("bar:" + bid, "bar", bid, cells=[(obj["x"], obj["y"] + dy) for dy in range(3)],
                            col=obj["x"], row=obj["y"], tile=T)
                zone = p.get("zone", [obj["x"], obj["y"], 1, 3])
                gate.zone = tuple(int(v) for v in zone)
                gate.wait_s = float(p.get("rise_s", 1.0)) + float(p.get("wait_s", 20.0)) + float(cfg.get("full_s", 0.6))
                gate.waves = list(p.get("waves", []))
                self.gates.append(gate)
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
            elif obj["type"] in ("power_switch", "debug_switch"):
                # Interruptor de pulso / panel oculto (tanda H2 del paso 14 del 1-2): `pulses` pulsos que
                # alcancen su hit_rect, cada uno con Isak de espaldas pose_s (tiempo del mundo). El panel
                # oculto solo responde una vez descubierto con el Debug activo a reveal_radius_px.
                cfg = self.catalog.get("power_switch", {})
                sid = str(p.get("id", "switch_%d_%d" % (obj["x"], obj["y"])))
                gate = Gate("switch:" + sid, "switch", sid, openers=[cell_rect(obj, cfg.get("hit_rect", [8, -14, 48, 48]),
                                                                              "interruptor %s" % sid)],
                            col=obj["x"], row=obj["y"], tile=T)
                gate.pulses = int(p.get("pulses", 3 if obj["type"] == "power_switch" else 1))
                gate.pose_s = float(cfg.get("pose_s", 0.45))
                gate.hidden = obj["type"] == "debug_switch"
                gate.reveal_radius = float(cfg.get("reveal_radius_px", 256.0))
                gate.done_if_ally = str(p.get("done_if_ally", "") or "")
                self.gates.append(gate)
            elif obj["type"] == "_pound_card":
                # Tarjeta fragil que solo rompe el golpe al suelo (Mundo 2; tools/world2_model.py): solida
                # (o de una via) hasta que la onda de un golpe desde una celda de pie la alcanza; las ocultas,
                # solo con el Debug activo (se ve la grieta). Rota, Isak cae por ella.
                pid = str(p.get("id", "pound_%d_%d" % (obj["x"], obj["y"])))
                w, rows_n = int(p.get("width_tiles", 1)), int(p.get("rows", 1))
                cells = [(obj["x"] + dx, obj["y"] + dy) for dy in range(rows_n) for dx in range(w)]
                height = float(p.get("card_height_px", T))
                rect = (obj["x"] * T, obj["y"] * T, (obj["x"] + w) * T, obj["y"] * T + height,
                        "tarjeta fragil %s" % pid)
                gate = Gate("pound:" + pid, "pound", pid, cells=cells, openers=[rect], col=obj["x"], row=obj["y"],
                            tile=T)
                gate.hidden = bool(p.get("hidden", False))
                gate.one_way = bool(p.get("one_way", False))
                # Muro «Cargando mas...» (paso 9b): `pounds` golpes (3), cada uno desde una celda de pie.
                gate.pounds = max(1, int(p.get("pounds", 1)))
                gate.wall = bool(p.get("wall", False))
                self.gates.append(gate)
            elif obj["type"] == "dnd_switch":
                # Interruptor «No molestar» (1-3, paso 3; modelado en el paso 9): un pulso que alcanza su
                # hit_rect, con Isak de espaldas pose_s, da para siempre la habilidad `ability` (el dash).
                # El reproductor con el boton de pausa (Mundo 2, paso 9b; PausePlayer hereda de DndSwitch) llega
                # como dnd_switch con `_config` = pause_player (tools/world2_model.py) y da el golpe al suelo.
                config = str(p.get("_config", "") or "dnd_switch")
                cfg = self.catalog.get(config, {})
                sid = str(p.get("id", "dnd_%d_%d" % (obj["x"], obj["y"])))
                what = "reproductor" if config == "pause_player" else (
                    "herramienta Recortar" if config == "crop_tool" else "interruptor No molestar")
                gate = Gate("dnd:" + sid, "dnd", sid, openers=[cell_rect(obj, cfg.get("hit_rect", [8, -14, 48, 48]),
                                                                          "%s %s" % (what, sid))],
                            col=obj["x"], row=obj["y"], tile=T)
                gate.player = config == "pause_player"
                # Herramienta «Recortar» (Mundo 3, paso 8a; tools/world3_model.py): da Pellizcar (compress).
                gate.crop = config == "crop_tool"
                gate.ability = str(p.get("ability", "dash"))
                gate.pulses = 1
                gate.pose_s = float(cfg.get("pose_s", 0.45))
                self.gates.append(gate)
            elif obj["type"] == "laser_switch":
                # Interruptor laser: un impacto lo activa para siempre (sin ventana).
                cfg = self.catalog.get("laser_switch", {})
                sid = str(p.get("id", "laser_switch_%d_%d" % (obj["x"], obj["y"])))
                gate = Gate("lswitch:" + sid, "lswitch", sid,
                            openers=[cell_rect(obj, cfg.get("hit_rect", [32, -16, 32, 48]), "interruptor laser %s" % sid)],
                            col=obj["x"], row=obj["y"], tile=T)
                gate.done_if_ally = str(p.get("done_if_ally", "") or "")
                self.gates.append(gate)
            elif obj["type"] == "charge_dock":
                # Punto de carga: se arma con todas sus piezas hechas; Calc entra, se carga y se va al hub
                # (espera fija, wait_s); entonces tiene corriente.
                did = str(p.get("id", "dock_%d_%d" % (obj["x"], obj["y"])))
                gate = Gate("dock:" + did, "dock", did, col=obj["x"], row=obj["y"], tile=T)
                gate.requires = [str(r) for r in p.get("requires", [])]
                gate.charge_s = float(p.get("charge_s", 3.0))
                gate.done_if_ally = str(p.get("done_if_ally", "") or "")
                gate.dock_obj = obj
                self.gates.append(gate)
        # Anuncios (ad_cover, paso 10): tapan el boton de un pop-up (solido o translucido) hasta que
        # el laser los rompe; mientras, el pulso rebota.
        size = self.catalog.get("ad_cover", {}).get("size_px", [96, 48])
        for obj in self.level.get("objects", []):
            if obj["type"] != "ad_cover":
                continue
            p = self._params(obj)
            aid = str(p.get("id", "ad_%d_%d" % (obj["x"], obj["y"])))
            target = str(p.get("target", ""))
            button = None
            popup = next((g for g in self.gates if g.kind == "popup" and g.obj_id == target), None)
            if popup is not None and popup.openers:
                button = popup.openers[0]
            overlay = next((o for o in self.overlays if o["id"] == target), None)
            if overlay is not None:
                button = overlay["button"]
            if button is None:
                continue
            cx, cy = (button[0] + button[2]) * 0.5, (button[1] + button[3]) * 0.5
            rect = (cx - size[0] * 0.5, cy - size[1] * 0.5, cx + size[0] * 0.5, cy + size[1] * 0.5, "anuncio %s" % aid)
            gate = Gate("ad:" + aid, "ad", aid, openers=[rect], col=obj["x"], row=obj["y"], tile=T)
            gate.target = target
            self.gates.append(gate)
            if popup is not None:
                popup.cover = gate.gid
            if overlay is not None:
                overlay["cover"] = gate.gid
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
        self._link_calc_room()

    def _link_calc_room(self):
        """Enlaces del acertijo de Calc (tanda H2): las piezas que pide cada punto de carga (gid), el
        interruptor de cada puerta (su columna cuenta en la cache de movimientos de la pared) y la
        espera de Calc: despertar, caminar por su path (el ultimo punto, los pies en el dock), cargar
        charge_s, cara despierta charged_hold_s y el vortice (como CalcActor)."""
        T = self.T
        # Disolucion de la pared con glitch con el Debug (GlitchWall: cuadros de glitch_dissolve a
        # dissolve_fps, tiempo del mundo); el plan espera a que termine antes de cruzarla.
        self.glitch_dissolve_s = 0.0
        if self.glitch:
            cfg = self.catalog.get("glitch_wall", {})
            frames = sprite_frames(self.rules.root, "res://assets/sprites/extra_life_frames.tres")
            count = frames.get("glitch_dissolve", (len(cfg.get("dissolve_blink", [])), 12.0))[0]
            self.glitch_dissolve_s = count / max(float(cfg.get("dissolve_fps", 12.0)), 0.001)
        by_id = {g.obj_id: g for g in self.gates if g.kind in ("switch", "lswitch", "dock")}
        for g in self.gates:
            if g.kind == "switch":
                walls = [w for w in self.glitch_walls if w["door_when"] == g.obj_id]
                cols = [g.col] + [c for w in walls for c, _ in w["cells"]]
                g.col_span = (min(cols), max(cols))
            if g.kind != "dock":
                continue
            g.requires_gids = [by_id[r].gid if r in by_id else "missing:" + r for r in g.requires]
            calc_cfg = self.catalog.get("calc_actor", {})
            dock_cfg = self.catalog.get("charge_dock", {})
            actor = next((o for o in self.level.get("objects", []) if o["type"] == "calc_actor"
                          and str(o.get("params", {}).get("dock", "")) == g.obj_id), None)
            frames = sprite_frames(self.rules.root, str(calc_cfg.get("frames", "res://assets/sprites/calc_actor_frames.tres")))
            warp = sprite_frames(self.rules.root, str(calc_cfg.get("warp_frames", "res://assets/sprites/warp_objects_frames.tres")))
            feet = dock_cfg.get("calc_feet_px", [56, 52])
            dock_feet = (g.dock_obj["x"] * T + float(feet[0]), g.dock_obj["y"] * T + float(feet[1]))
            walk = 0.0
            if actor is not None:
                cells = actor.get("params", {}).get("path", []) or [[actor["x"], actor["y"]]]
                points = [((c + 0.5) * T, (r + 1.0) * T) for c, r in cells]
                if len(points) >= 2:
                    points[-1] = dock_feet
                else:
                    points.append(dock_feet)
                walk = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(points, points[1:]))
                g.calc_id = str(actor.get("params", {}).get("id", "calc"))
                g.calc_path = [list(c) for c in cells]
            else:
                g.calc_id = None
                g.calc_path = []
            speed = float(calc_cfg.get("walk_speed_px_s", 70.0))
            spins = max(int(calc_cfg.get("spins", 2)), 1)
            parts = {
                "wake_s": anim_length(frames, "calc_wake") if actor is not None else 0.0,
                "walk_s": walk / speed if actor is not None else 0.0,
                "charge_s": g.charge_s,
                "charged_hold_s": float(calc_cfg.get("charged_hold_s", 0.8)) if actor is not None else 0.0,
                "teleport_s": (anim_length(warp, "vortex_open") + anim_length(warp, "vortex_close")
                               + spins * anim_length(warp, "vortex_spin")) if actor is not None else 0.0,
            }
            # Unos cuadros de reaccion (el dock se arma, Calc lo ve en su siguiente cuadro, etc.).
            parts["frames_s"] = 4.0 * SIM_DT
            g.wait_parts = {k: round(v, 3) for k, v in parts.items()}
            g.wait_s = sum(parts.values())
            g.walk_px = walk

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
        """Nivel vertical (torre): camara de torre o de scroll forzado (Mundo 2) o tramos con y_from/y_to."""
        return self.level.get("camera", {}).get("vertical") in ("tower", "autoscroll") or any(
            "y_from" in s or "y_to" in s for s in self.sections)

    # Mundo en un estado (puertas abiertas + Debug).
    def world(self, state, debug=False):
        key = (state, debug, self.dash_blocked(state))
        if key not in self._worlds:
            self._worlds[key] = World(self, state, debug)
        return self._worlds[key]

    def local_key(self, node, state):
        c = node[0]
        lo, hi = c - self.K - 3, c + self.K + 3
        # Solo las puertas que cambian el terreno (tanda H2: el interruptor laser, el punto de carga, el
        # anuncio y las habilidades no; el interruptor de pulso, si abre una puerta con glitch).
        key = tuple(sorted(g.gid for g in self.gates
                           if g.gid in state and g.kind not in ("lswitch", "dock", "dnd")
                           and not (g.kind == "switch" and ("switch:" + g.obj_id) not in self._door_gids)
                           and not (g.col_span[1] < lo or g.col_span[0] > hi)))
        if self.w3 is not None and self.w3.keyed:
            # Mundo 3: las plataformas de likes encendidas cerca (los umbrales cumplidos, no la cifra) y las puertas de
            # marco abiertas (paso 8b).
            key = key + self.w3.like_key(lo, hi, state)
        return key

    def edges(self, node, state, debug=False):
        if debug == "auto":
            return self.union_edges(node, state) if self.has_debug(state) else self.edges(node, state, False)
        # Dash (paso 9 de docs/propuesta-1-3.md): sus movimientos se suman a los normales cuando la
        # habilidad esta disponible y nunca con el Debug activo (no se combinan).
        if self.w3 is not None and world3_model.is_pinched(node):
            return self.w3.pinched_edges(node, state, debug)
        dash = debug is False and self.has_dash(state)
        key = (node, self.local_key(node, state), debug) if not dash else (
            node, self.local_key(node, state), debug, "dash")
        if self.dash_blocked(state):
            key = key + ("nodash",)
        pinch = self.w3 is not None and self.w3.has_compress(state)
        if pinch:
            key = key + ("pinch",)
        if key not in self._edges:
            out = self.world(state, debug).compute_edges(node)
            if dash:
                out = out + self.world(state, False).compute_dash_edges(node)
            if pinch:
                out = out + self.w3.pinch_edges(node, state, debug)
            self._edges[key] = out
        return self._edges[key]

    def union_edges(self, node, state):
        """Movimientos con el Debug a mano (paso 10, 2026-10-16): los normales y, ademas, los que
        solo existen con el Debug activo (plataformas 'h' solidas, pared con glitch abierta),
        marcados con "debug": True. Encenderlo y apagarlo entre movimientos es libre en el grafo; la
        energia y la carga de activation_hold_s las cuenta el plan (tools/level_plan.py)."""
        key = (node, self.local_key(node, state), "union")
        if self.w3 is not None and (world3_model.is_pinched(node) or self.w3.has_compress(state)):
            key = key + ("pinch",)
        if self.has_dash(state):
            key = key + ("dash",)
        elif self.dash_blocked(state):
            key = key + ("nodash",)
        if key not in self._edges:
            normal = self.edges(node, state, False)
            seen = {e["to"] for e in normal}
            out = list(normal)
            for e in self.edges(node, state, True):
                if e["to"] not in seen:
                    extra = dict(e)
                    extra["debug"] = True
                    out.append(extra)
            self._edges[key] = out
        return self._edges[key]

    def has_debug(self, state):
        """El Debug se puede usar: lo da el nivel (abilities_available.debug) o ya se recogio su chip."""
        if "debug" in self.forbidden:
            return False
        return self.debug_base or any(g.kind == "pickup" and g.ability == "debug" and g.gid in state
                                      for g in self.gates)

    def has_pulse(self, state):
        """El pulso esta disponible: lo da el nivel desde el inicio o ya se paso por el encuentro con Eco
        (o se recogio un ability_pickup de pulso)."""
        if "pulse" in self.forbidden:
            return False
        return self.pulse or any(g.kind == "pickup" and g.ability == "pulse" and g.gid in state
                                 for g in self.gates)

    def has_laser(self, state):
        """El laser esta disponible: lo da el nivel o ya se recogio su ability_pickup."""
        if "laser" in self.forbidden:
            return False
        return self.laser_base or any(g.kind == "pickup" and g.ability == "laser" and g.gid in state
                                      for g in self.gates)

    def _dash_corridors(self):
        """[(id, rect px)] de la franja de dano de cada banner de validation.dash_required (la misma que la
        busqueda por tiempo de tools/level_plan.py: todo el pasillo, a la altura de su zona de dano)."""
        ids = {str(b) for b in (self.validation.get("dash_required") or [])}
        if not ids:
            return []
        data = load_json(os.path.join(self.rules.root, "data", "enemies", "spam_banner.json"))
        T = self.T
        out = []
        for enemy in self.level.get("enemies", []):
            if enemy.get("type") != "spam_banner" or str(enemy.get("id")) not in ids:
                continue
            p = dict(data)
            p.update(enemy.get("params", {}))
            direction = int(p["direction"])
            entry = (enemy["x"] + 0.5) * T - T * 0.5 * direction
            end = entry + direction * float(p["corridor_tiles"]) * T
            bottom = (enemy["y"] + 1) * T - float(p["damage_bottom_px"])
            out.append((str(enemy["id"]), (min(entry, end), bottom - float(p["damage_size"][1]),
                                           max(entry, end), bottom)))
        return out

    def dash_blocked(self, state):
        """Los pasillos de validation.dash_required cierran el paso: Isak aun no tiene el dash en este estado.
        No mira forbid_abilities: un secreto con forbid_abilities ["dash"] exige que SU ruta no use el dash,
        no que Isak no lo tenga (para llegar hasta alli ya cruzo el pasillo obligatorio con el)."""
        if not self.dash_corridors:
            return False
        return not (self.dash_base or any(g.kind == "dnd" and g.ability == "dash" and g.gid in state
                                          for g in self.gates))

    def has_pound(self, state):
        """El golpe al suelo esta disponible (abilities_available.ground_pound o, desde el paso 9b, ya se pauso un
        reproductor con el boton de pausa que lo da; Mundo 2)."""
        if "ground_pound" in self.forbidden:
            return False
        return self.pound_base or any(g.kind == "dnd" and g.ability == "ground_pound" and g.gid in state
                                      for g in self.gates)

    def pound_hits(self, gate, node, state, debug=False):
        """Verdadero si la onda de un golpe al suelo con Isak de pie en `node` alcanza la tarjeta `gate`
        (GroundPoundWave.rect_at: wave_half_width_px a cada lado de los pies, wave_height_px por encima
        y wave_below_px por debajo)."""
        return self.pound_x(gate, node, state, debug) is not None

    def pound_x(self, gate, node, state, debug=False):
        """x de los pies (dentro de la celda de pie) desde la que la onda alcanza la tarjeta, o None."""
        rules = self.rules
        if self.w3 is not None and world3_model.is_pinched(node):
            return None  # comprimido no hay golpe al suelo
        w = self.world(state, debug if debug in (True, False) else False)
        c, r = node
        feet = (r + 1) * self.T
        rect = gate.openers[0]
        x = c * self.T
        best = None
        while x <= (c + 1) * self.T + EPS:
            if not w.collides(x, feet) and not w.in_hazard(x, feet):
                wave = (x - rules.pound_half_width, feet - rules.pound_height, x + rules.pound_half_width,
                        feet + rules.pound_below)
                if wave[0] < rect[2] and rect[0] < wave[2] and wave[1] < rect[3] and rect[1] < wave[3]:
                    if best is None or abs(x - (c + 0.5) * self.T) < abs(best - (c + 0.5) * self.T):
                        best = x
            x += PULSE_SAMPLE_PX
        return best

    def has_dash(self, state):
        """El dash (gesto Deslizar) esta disponible: lo da el nivel (abilities_available.dash) o ya se
        activo el interruptor No molestar (paso 9 de docs/propuesta-1-3.md)."""
        if not self.dash_possible or "dash" in self.forbidden:
            return False
        return self.dash_base or any(g.kind == "dnd" and g.ability == "dash" and g.gid in state for g in self.gates)

    def forbidding(self, abilities):
        """Contexto (with) en el que esas habilidades no existen (forbid_abilities de un secreto)."""
        model = self

        class _Forbid:
            def __enter__(self):
                self.saved = model.forbidden
                model.forbidden = frozenset(model.forbidden | set(abilities))
                return model

            def __exit__(self, *exc):
                model.forbidden = self.saved
                return False
        return _Forbid()

    def can_open(self, gate, node, state, debug=False, use_laser=True):
        """Verdadero si desde `node` (de pie) se abre la puerta: el pulso toca algun rectangulo de
        la puerta, el laser alcanza a la Burbuja (si se puede usar) o, si es un ability_pickup,
        Isak toca su celda."""
        if self.w3 is not None and world3_model.is_pinched(node) and gate.kind not in ("pickup", "bar", "dock"):
            return False  # comprimido no hay pulso, laser ni golpe al suelo
        if gate.kind == "pickup":
            return bool(body_cells(node) & set(gate.cells))
        if gate.kind == "pound":
            # Golpe al suelo (Mundo 2): la onda alcanza la tarjeta; la oculta, solo con el Debug activo.
            if not self.has_pound(state):
                return False
            if gate.hidden and not (debug is True or (debug == "auto" and self.has_debug(state))):
                return False
            return self.pound_hits(gate, node, state, debug if debug in (True, False) else gate.hidden)
        if gate.kind == "dnd":
            # Interruptor No molestar: un pulso de espaldas (paso 9).
            return self.has_pulse(state) and self.pulse_hits(gate.openers, node, state, debug)
        if gate.kind == "bar":
            c0, r0, w, h = gate.zone
            return c0 <= node[0] < c0 + w and r0 <= node[1] < r0 + h
        if gate.kind == "ad":
            return use_laser and self.has_laser(state) and self.laser_hits(gate, node, state, debug)
        if gate.kind == "dock":
            # Se arma solo cuando todas sus piezas estan hechas (desde cualquier sitio).
            return all(r in state for r in gate.requires_gids)
        if gate.kind == "lswitch":
            return use_laser and self.has_laser(state) and self.laser_hits(gate, node, state, debug)
        if gate.kind == "switch":
            if not self.has_pulse(state):
                return False
            if gate.hidden and not (self.has_debug(state) and self.reveal_near(gate, node)):
                return False  # el panel oculto no se ve ni responde sin descubrirlo con el Debug
            return self.pulse_hits(gate.openers, node, state, debug)
        if gate.kind == "bubble" and use_laser and self.has_laser(state) and self.laser_hits(gate, node, state, debug):
            return True
        if not self.has_pulse(state) or not gate.openers:
            return False
        if getattr(gate, "cover", None) and gate.cover not in state:
            return False  # el anuncio tapa el boton: el pulso rebota
        if getattr(gate, "relay", None) is not None:
            if not use_laser or not self.has_laser(state):
                return False
            return node in self.relay_plan(gate, state, debug)["ok"]
        if gate.kind == "bridge":
            return self.receiver_hits(gate, node, state, debug)
        return self.pulse_hits(gate.openers, node, state, debug)

    def receiver_hits(self, gate, node, state, debug=False):
        """El pulso desde `node` activa el receptor de `gate`: lo alcanza o (Mundo 3, paso 8b) alcanza a un espejo
        cazador cuyo haz lo toca en una orientacion que puede tener (tools/world3_model.py)."""
        if self.pulse_hits(gate.openers, node, state, debug):
            return True
        return bool(self.w3 is not None and self.w3.hunters
                    and self.w3.beam_hit(gate.openers, node, state, debug) is not None)

    def reveal_near(self, gate, node):
        """El Debug activo descubre el panel oculto con los pies de Isak (centro de la celda de pie) a
        reveal_radius_px del centro de su zona (PowerSwitch._isak_near)."""
        rect = gate.openers[0]
        cx, cy = (rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5
        x, feet = (node[0] + 0.5) * self.T, (node[1] + 1) * self.T
        return math.hypot(x - cx, feet - cy) <= gate.reveal_radius + EPS

    def pulse_hits(self, rects, node, state, debug=False):
        """Verdadero si el pulso desde `node` (de pie, mirando a un lado) toca alguno de `rects`."""
        if not rects:
            return False
        if self.w3 is not None and world3_model.is_pinched(node):
            return False  # comprimido no hay pulso
        dbg = debug if debug in (True, False) else False
        w = self.world(state, dbg)
        c, r = node
        feet = (r + 1) * self.T
        x = c * self.T
        while x <= (c + 1) * self.T + EPS:
            if not w.collides(x, feet) and not w.in_hazard(x, feet):
                for facing in (1.0, -1.0):
                    px, py = x + self.rules.phone_x * facing, feet + self.rules.phone_y
                    for rect in rects:
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
        if not gate.openers:
            return False
        return self.laser_shot(gate.openers[0], node, state, debug) is not None

    def laser_shot(self, rect, node, state, debug=False):
        """Disparo del laser desde `node` que alcanza `rect` (lector, anuncio, Posponer, Burbuja):
        {"x": x de los pies, "facing": 1 / -1, "dist": px hasta el objetivo} o None. Horizontal a la
        altura del celular (pulse_effect_origin) desde una posicion de pie de la celda; alcance
        laser_range_px; lo cortan el terreno, los puentes extendidos y los pop-ups cerrados."""
        rules = self.rules
        if self.w3 is not None and (self.w3.mirrors or self.w3.hunters or world3_model.is_pinched(node)):
            # Mundo 3: trazado con rebotes en los espejos fijos y los cazadores (y comprimido no hay laser).
            return self.w3.laser_shot(rect, node, state, debug)
        if rules.laser_range <= 0.0:
            return None
        w = self.world(state, debug if debug in (True, False) else False)
        c, r = node
        T = self.T
        feet = (r + 1) * T
        py = feet + rules.phone_y
        half = rules.laser_thickness * 0.5
        bx0, by0, bx1, by1 = rect[:4]
        if py + half < by0 or py - half > by1:
            return None
        x = c * T
        while x <= (c + 1) * T + EPS:
            if not w.collides(x, feet):
                for facing in (1.0, -1.0):
                    px = x + rules.phone_x * facing
                    if bx0 <= px <= bx1:
                        return {"x": x, "facing": facing, "dist": 0.0}
                    near = bx0 if facing > 0 else bx1
                    dist = (near - px) * facing
                    if dist < 0.0 or dist > rules.laser_range + EPS:
                        continue
                    if not w.ray_blocked(px, near, py, half):
                        return {"x": x, "facing": facing, "dist": dist}
            x += PULSE_SAMPLE_PX
        return None

    def pulse_shot(self, rects, node, state, debug=False, avoid=None):
        """Como pulse_hits, pero devuelve {"x", "facing"} de la primera posicion que toca. `avoid` (paso 13 del
        Mundo 3, 2026-10-27): rectangulos que el pulso NO debe tocar desde esa posicion (un espejo cazador al
        lado de un Reflejo falso: el pulso que aturde al reflejo lo congelaria en otra orientacion); sin el
        parametro no cambia nada."""
        if self.w3 is not None and world3_model.is_pinched(node):
            return None
        dbg = debug if debug in (True, False) else False
        w = self.world(state, dbg)
        c, r = node
        feet = (r + 1) * self.T
        x = c * self.T

        def touches(px, py, rect):
            qx = min(max(px, rect[0]), rect[2])
            qy = min(max(py, rect[1]), rect[3])
            return math.hypot(px - qx, py - qy) <= self.rules.pulse_radius + EPS

        while x <= (c + 1) * self.T + EPS:
            if not w.collides(x, feet) and not w.in_hazard(x, feet):
                for facing in (1.0, -1.0):
                    px, py = x + self.rules.phone_x * facing, feet + self.rules.phone_y
                    if avoid and any(touches(px, py, rect) for rect in avoid):
                        continue
                    for rect in rects:
                        if touches(px, py, rect):
                            return {"x": x, "facing": facing}
            x += PULSE_SAMPLE_PX
        return None

    # --- Tiempos (paso 10) ---

    def time_margin(self):
        """Margen de tiempo minimo que debe sobrar en las ventanas y cuentas (s; validation.time_margin_s
        del nivel o --time-margin; 1,5 s por defecto)."""
        value = self.rules.time_margin
        if value is None:
            value = self.validation.get("time_margin_s", DEFAULT_TIME_MARGIN_S)
        return float(value)

    def edge_time(self, node, e, walk_speed=None):
        """Segundos de un movimiento del grafo: andar una celda a walk_speed; saltar o caer, el tiempo en
        el aire mas lo que se anda dentro de las celdas de salida y llegada (del centro al despegue y
        del aterrizaje al centro) y el arranque desde parado (START_S). Un dash (paso 9) cuenta igual: su
        `time` es el tramo del dash (y del salto y de la caida que lo rodean). `walk_speed` (paso 9):
        andar a otra velocidad (p. ej. corriendo por un pasillo, en la comprobacion de dash_required)."""
        T = self.T
        speed = e.get("walk_px_s") or self.rules.walk_speed
        if e["kind"] == "walk":
            return T / (speed if walk_speed is None else walk_speed)
        x_from = (node[0] + 0.5) * T
        to = e["to"]
        land = e.get("land_x")
        if land is None:
            land = e["x0"] + (e.get("travel", 0.0) + T * 0.5) * (1 if to[0] >= node[0] else -1)
        extra = abs(e["x0"] - x_from) / speed + abs(land - (to[0] + 0.5) * T) / speed
        return e.get("time", 0.0) + extra + START_S

    def time_search(self, sources, state, debug="auto", limit=None, region=None, dash=False):
        """Dijkstra por tiempo desde varias fuentes {nodo: segundos}: devuelve (t, parent). Respeta el
        limite de exigencia de los saltos; `region` (conjunto de nodos) restringe la busqueda. Sin `dash`
        no usa los movimientos con dash (gastan energia: los desvios y acertijos van sin el)."""
        limit = self.rules.limit if limit is None else limit
        best = dict(sources)
        parent = {n: None for n in sources}
        heap = [(t, n) for n, t in sources.items()]
        heapq.heapify(heap)
        while heap:
            t, node = heapq.heappop(heap)
            if t > best.get(node, INF) + EPS:
                continue
            for e in self.edges(node, state, debug):
                if max(e["h"], e["v"]) > limit + EPS:
                    continue
                if not dash and e.get("dash"):
                    continue
                to = e["to"]
                if region is not None and to not in region:
                    continue
                nt = t + self.edge_time(node, e)
                if nt < best.get(to, INF) - EPS:
                    best[to] = nt
                    parent[to] = (node, e)
                    heapq.heappush(heap, (nt, to))
        return best, parent

    def relay_plan(self, gate, state, debug="auto", sources=None):
        """Patron 2 (lector laser -> receptor enlazado -> puente): desde que celdas de pie el pulso
        activa el receptor con corriente. Para cada una, el menor tiempo desde un disparo al lector
        (desde cualquier celda de `sources`, o de todo el mapa) hasta el pulso: laser_pose_s (el
        disparo bloquea el movimiento) + recorrido + PULSE_DELAY_S. Devuelve {"ok": {B: t}, "best":
        {...} o None, "window": s, "shots": [celdas desde donde se dispara]}: `ok` son las celdas en
        las que el tiempo cabe en la ventana (el margen lo comprueba el plan)."""
        key = (gate.gid, state, debug, None if sources is None else id(sources))
        if self.forbidden:
            key = key + (self.forbidden,)
        if sources is None and key in self._relay_cache:
            return self._relay_cache[key]
        lector = gate.relay.get("lector") if gate.relay else None
        out = {"ok": {}, "best": None, "window": lector["window"] if lector else 0.0, "shots": []}
        if lector is None or not self.has_laser(state) or not self.has_pulse(state):
            if sources is None:
                self._relay_cache[key] = out
            return out
        nodes = sources if sources is not None else self.world(state, False).nodes()
        shots = {}
        for n in nodes:
            shot = self.laser_shot(lector["rect"], n, state, debug)
            if shot is not None:
                shots[n] = shot
        out["shots"] = sorted(shots)
        if shots:
            starts = {n: self.rules.laser_pose_s for n in shots}
            times, parent = self.time_search(starts, state, debug)
            for n, t in times.items():
                total = t + PULSE_DELAY_S
                if total <= lector["window"] + EPS and self.receiver_hits(gate, n, state, debug):
                    out["ok"][n] = total
            if out["ok"]:
                b = min(out["ok"], key=lambda n: (out["ok"][n], n[1], n[0]))
                path = path_to(parent, b)
                a = path[0][0] if path else b
                out["best"] = {"shot": a, "shot_info": shots[a], "pulse": b, "time": out["ok"][b],
                               "path": path, "lector": lector["id"]}
            else:
                # Lo mejor posible aunque no quepa (para explicar el fallo).
                cands = [(t + PULSE_DELAY_S, n) for n, t in times.items()
                         if self.receiver_hits(gate, n, state, debug)]
                if cands:
                    out["closest"] = min(cands)
        if sources is None:
            self._relay_cache[key] = out
        return out


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
        doors = model.glitch_doors
        for r, row in enumerate(model.grid):
            for c, ch in enumerate(row):
                glitch = (c, r) in model.glitch and not debug and not (doors and doors.get((c, r)) in state)
                if ch == "#" or glitch or (ch == "h" and debug):
                    self.solid[r][c] = True
                    self.support[r][c] = True
                elif ch == "-":
                    self.support[r][c] = True
        self.hazards = list(model.spike_rects)
        for (c, r), thickness in list(model.reminders.items()) + list(model.blinks.items()):
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
            elif g.kind in ("popup", "bar") and not opened:
                for c, r in g.cells:
                    if 0 <= r < rows and 0 <= c < cols:
                        self.solid[r][c] = True
                        self.support[r][c] = True
            elif g.kind == "pound" and not opened:
                # Tarjeta fragil entera (Mundo 2): solida, o solo apoyo si es de una via.
                for c, r in g.cells:
                    if 0 <= r < rows and 0 <= c < cols:
                        self.support[r][c] = True
                        if not g.one_way:
                            self.solid[r][c] = True
            elif g.kind == "bubble" and not opened and not g.bypassable:
                self.hazards.append(g.rect + ("Burbuja %s" % g.obj_id,))
        if model.dash_blocked(state):
            for bid, rect in model.dash_corridors:
                self.hazards.append(rect + ("banner %s (sin el dash)" % bid,))
        if model.w3 is not None:
            model.w3.apply_world(self, state, debug)

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

    def simulate(self, x, y, vy, speed, x_target, head_lag=False, info=None, game=False, accel=None, vx0=0.0):
        """Trayectoria con velocidad horizontal `speed` hacia x_target. Devuelve
        (nodo_de_llegada, None) o (None, motivo).

        head_lag (tolerancia de techo, 2026-10-16): al subir, la cabeza tambien se comprueba
        donde estaria Isak si hubiera despegado desde parado (rules.standing_lag: acelera con
        air_acceleration); si esa cabeza retrasada choca con un solido que la del modelo no toca
        (la esquina de una losa), cuenta como golpe de techo. Bajo un techo plano no cambia nada
        (las dos chocan a la vez). info (dict): recibe time (s en el aire), head_hit y traj
        (lista de (x, y) por paso, para el plan del camino).

        game (2026-10-20, bot del 1-3): integra como Isak.step a 60 Hz (la gravedad cambia la velocidad
        antes de mover y la de caida empieza con vy >= 0, Isak.apply_gravity); con vy = -jump_v0_game es
        el arco real del juego (unos 184 px), que bajo un techo choca antes y aterriza antes que el
        conservador. Solo lo usa la linea de tiempo de las amenazas (tools/level_plan.py); el alcance
        sigue con el conservador. accel (px/s^2): la velocidad horizontal empieza en vx0 (0 por defecto) y sube
        hasta `speed` (salto desde parado con air_acceleration); al chocar con una pared vuelve a 0, como en
        Godot (la caida tras un dash que topa con un escalon del techo baja en vertical)."""
        m = self.m
        T = m.T
        g = m.rules.gravity
        gm = g * m.rules.fall_mult
        dt = SIM_DT
        bottom = m.rows * T + m.hh
        direction = 1.0 if x_target > x else -1.0
        x_start = x
        y_start = y
        steps = 0
        # Holgura de techo calibrada (validation.ceiling_margin_px): solo en saltos (head_lag); las
        # celdas sin holgura se apuntan y, si el salto aterriza mas arriba, no vale.
        calibrated = head_lag and m.ceiling_margin is not None
        head_takeoff = y - m.hh
        v_margin = 0.0 if not calibrated else m.ceiling_margin + max(0.0, m.rules.real_jump_height - m.rules.jump_height)
        tight = set()
        traj = [] if info is not None and info.get("want_traj") else None
        traj_vy = [] if traj is not None else None
        if info is not None:
            info["traj"] = traj
            info["traj_vy"] = traj_vy
            info["time"] = 0.0
            info["head_hit"] = False
        cur = float(vx0)
        # Pared en el aire (2026-10-27, paso 11 de docs/propuesta-mundo-3.md, bot de la galeria): en Godot, al chocar
        # con una pared la velocidad horizontal vuelve a 0 (move_and_slide) y, ya libre, Isak acelera otra vez con
        # air_acceleration. El modelo conservador seguia a `speed` al instante y daba por bueno saltar andando una
        # columna de 1 x 2 desde la celda pegada a ella (3-1, columnas-marco 79 y 82), que el juego no pasa (sube
        # pegado y aterriza en lo alto). Solo en los niveles del Mundo 3 (w3): las salidas del 1-1 al 2-boss siguen
        # identicas byte a byte (sus bots ya recorren esos saltos; limite conocido).
        wall_regain = accel is None and m.w3 is not None and m.rules.air_accel > 0.0
        accel_now = accel
        for _ in range(int(SIM_MAX_S / dt)):
            steps += 1
            if info is not None:
                info["time"] = steps * dt
            if traj is not None:
                traj.append((x, y))
                traj_vy.append(vy)
            # Horizontal.
            if abs(x_target - x) > EPS:
                if accel_now is None:
                    step = speed * dt
                else:
                    cur = min(speed, cur + accel_now * dt)
                    step = cur * dt
                nx = x_target if abs(x_target - x) <= step else x + math.copysign(step, x_target - x)
                if not self.collides(nx, y):
                    x = nx
                elif nx > x:
                    cur = 0.0
                    if wall_regain:
                        accel_now = m.rules.air_accel
                    wall = math.floor((nx + m.hw - EPS) / T) * T
                    cand = wall - m.hw
                    if cand > x and not self.collides(cand, y):
                        x = cand
                else:
                    cur = 0.0
                    if wall_regain:
                        accel_now = m.rules.air_accel
                    wall = (math.floor((nx - m.hw) / T) + 1) * T
                    cand = wall + m.hw
                    if cand < x and not self.collides(cand, y):
                        x = cand
            # Vertical.
            acc = g if vy < 0.0 else gm
            if game:
                nvy = vy + acc * dt
                ny = y + nvy * dt
            else:
                ny = y + vy * dt + 0.5 * acc * dt * dt
                nvy = vy + acc * dt
            if ny < y:
                if calibrated:
                    lag_x = x
                    if speed > 0.0:
                        lag_x = x - direction * min(m.rules.standing_lag(steps * dt, speed, 0.0), abs(x - x_start))
                    if self.collides(x, ny):
                        tight |= self._head_cells(x, x, ny, head_takeoff, 0.0, 0.0)
                        y = min(y, self.ceiling_feet(x, ny))
                        vy = 0.0
                        if info is not None:
                            info["head_hit"] = True
                    elif self._lagged_ceiling(lag_x, y, ny):
                        tight |= self._head_cells(lag_x, lag_x, ny, head_takeoff, 0.0, 0.0)
                        y = min(y, self.ceiling_feet(lag_x, ny))
                        vy = 0.0
                        if info is not None:
                            info["head_hit"] = True
                    else:
                        tight |= self._head_cells(min(lag_x, x), max(lag_x, x), ny, head_takeoff, v_margin,
                                                  CORNER_MARGIN_PX)
                        y, vy = ny, nvy
                elif self.collides(x, ny):
                    y = min(y, self.ceiling_feet(x, ny))
                    vy = 0.0
                    if info is not None:
                        info["head_hit"] = True
                elif head_lag and speed > 0.0 and self._lagged_ceiling(
                        x - direction * min(m.rules.standing_lag(steps * dt, speed), abs(x - x_start)), y, ny):
                    lag_x = x - direction * min(m.rules.standing_lag(steps * dt, speed), abs(x - x_start))
                    y = min(y, self.ceiling_feet(lag_x, ny))
                    vy = 0.0
                    if info is not None:
                        info["head_hit"] = True
                else:
                    y, vy = ny, nvy
            else:
                landed = self._cross_support(x, y, ny)
                if landed is not None and calibrated and tight and (landed[1] + 1) * T < y_start - EPS:
                    # Subida sin holgura (el apoyo de la repisa de llegada no cuenta como techo).
                    lo, hi = self._ledge_span(landed)
                    if any(not (r == landed[1] + 1 and lo <= c <= hi) for c, r in tight):
                        if info is not None:
                            info["head_hit"] = True
                            info["tight"] = sorted(tight)
                        return None, "techo sin holgura"
                if landed is not None:
                    if traj is not None:
                        traj.append((x, (landed[1] + 1) * T))
                    if info is not None:
                        info["land_x"] = x
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

    def _lagged_ceiling(self, x, y, ny):
        """Verdadero si la caja en `x` choca al subir de `y` a `ny` con un solido que esta por
        encima de la cabeza (su borde de abajo no pasa de la cabeza en `y`): un techo, no una
        pared al lado."""
        head = y - self.m.hh
        return any(bottom <= head + EPS for bottom in self._obstacles(x, ny))

    def _cell_bottom(self, c, r):
        """Borde de abajo (px) de la celda si es solida o tiene una tabla fina; None si no."""
        if self.is_solid(c, r):
            return (r + 1) * self.m.T
        if (c, r) in self.thin:
            return r * self.m.T + self.thin[(c, r)]
        return None

    def _is_wall(self, c, r, head_takeoff):
        """La celda solida sigue en columna de solidos hasta la altura de la cabeza al despegar: es una
        pared (Isak se desliza por ella), no la esquina de una losa."""
        if not self.is_solid(c, r):
            return False
        rr = r + 1
        while rr * self.m.T < head_takeoff + self.m.T:
            if not self.is_solid(c, rr):
                return False
            rr += 1
        return True

    def _head_cells(self, xa, xb, feet, head_takeoff, v_margin, h_margin):
        """Celdas sin holgura con la caja de Isak barrida de xa a xb con los pies en `feet`: encima de
        la cabeza a menos de v_margin (y solapando en x) o, si estaban por encima de la cabeza al
        despegar y no son una pared, a menos de h_margin en horizontal a la altura del cuerpo."""
        m = self.m
        T = m.T
        head = feet - m.hh
        out = set()
        c0 = int(math.floor((xa - m.hw - h_margin) / T))
        c1 = int(math.floor((xb + m.hw + h_margin - EPS) / T))
        r0 = int(math.floor((head - v_margin) / T))
        r1 = int(math.floor((feet - EPS) / T))
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                bottom = self._cell_bottom(c, r)
                if bottom is None:
                    continue
                left, right = c * T, (c + 1) * T
                over_x = left < xb + m.hw - EPS and right > xa - m.hw + EPS
                if over_x and head - v_margin < bottom - EPS and bottom <= head + EPS:
                    out.add((c, r))
                    continue
                if bottom > head_takeoff + EPS or self._is_wall(c, r, head_takeoff):
                    continue
                near_x = left < xb + m.hw + h_margin - EPS and right > xa - m.hw - h_margin + EPS
                if near_x and r * T < feet - EPS and bottom > head + EPS:
                    out.add((c, r))
        return out

    def _ledge_span(self, node):
        c, r = node
        lo = hi = c
        while self.is_node(lo - 1, r):
            lo -= 1
        while self.is_node(hi + 1, r):
            hi += 1
        return lo, hi

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

    def unsupported_fall(self, node):
        """Golpe al suelo que rompe lo que se pisa (Mundo 2): el nodo se queda sin apoyo e Isak cae en
        vertical hasta el siguiente suelo. [] si el nodo no es un sitio libre."""
        c, r = node
        T = self.m.T
        if not (0 <= c < self.m.cols and 0 <= r < self.m.rows) or self.is_support(c, r + 1):
            return []
        x, feet = (c + 0.5) * T, (r + 1) * T
        if self.collides(x, feet) or self.in_hazard(x, feet):
            return []
        sim = {}
        to, _ = self.simulate(x, feet, 0.0, self.m.rules.walk_speed, x, info=sim)
        if to is None or to == node:
            return []
        drop = (to[1] + 1) * T - feet
        return [{"to": to, "kind": "fall", "h": 0.0, "v": 0.0, "x0": x, "travel": 0.0, "rise": -drop,
                 "speed": "walk", "xt": x, "vy0": 0.0, "time": sim.get("time", 0.0), "land_x": sim.get("land_x"),
                 "pound_fall": True}]

    def is_node_cell(self, c, r, x):
        """Celda de pie donde aterriza (puede estar en el borde: x en la linea entre dos celdas)."""
        return 0 <= c < self.m.cols and 0 <= r < self.m.rows and self.is_node(c, r)

    def compute_edges(self, node):
        """Movimientos desde un nodo: lista de dicts {to, kind, h, v, x0, x1, rise, travel, speed}."""
        m = self.m
        if not self.is_node(*node):
            # Solo con tarjetas que rompe el golpe al suelo (Mundo 2): el nodo se queda sin apoyo y se cae.
            return self.unsupported_fall(node) if m.has_pound_gates else []
        c, r = node
        T = m.T
        feet = (r + 1) * T
        best = {}

        order = {"walk": 0, "fall": 1, "jump": 2, "jump_run": 3}

        def add(to, kind, h, v, x0, travel, rise, speed_name, xt=None, vy0=0.0, time=0.0, land_x=None):
            key = (round(max(h, v), 6), round(h + v, 6), order[kind])
            old = best.get(to)
            if old is None or key < (round(max(old["h"], old["v"]), 6), round(old["h"] + old["v"], 6),
                                     order[old["kind"]]):
                # xt, vy0 y time (no salen en el informe): objetivo horizontal de la trayectoria,
                # velocidad vertical inicial y segundos en el aire (plan y camino exportado).
                best[to] = {"to": to, "kind": kind, "h": h, "v": v, "x0": x0, "travel": travel,
                            "rise": rise, "speed": speed_name, "xt": xt, "vy0": vy0, "time": time,
                            "land_x": land_x}

        for d in (1, -1):
            if self.is_node(c + d, r):
                add((c + d, r), "walk", 0.0, 0.0, (c + 0.5) * T, 0.0, 0.0, "walk", xt=(c + d + 0.5) * T,
                    time=T / m.rules.walk_speed)
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
                        sim = {}
                        to, _ = self.simulate(x0, feet, -m.rules.jump_v0, speed, x_target, head_lag=True, info=sim)
                        if to is None or to == node:
                            continue
                        rise = feet - (to[1] + 1) * T
                        travel = self._travel(x0, to, d)
                        h = travel / m.rules.reach(rise, speed) if travel > EPS else 0.0
                        v = max(0.0, rise) / m.rules.jump_height
                        if m.rules.reach(rise, speed) <= 0.0:
                            h = INF
                        add(to, "jump" if speed_name == "walk" else "jump_run", h, v, x0, travel, rise, speed_name,
                            xt=x_target, vy0=-m.rules.jump_v0, time=sim.get("time", 0.0), land_x=sim.get("land_x"))
                # Caidas desde el borde (sin saltar).
                if not self.is_support(c + d, r + 1) and not self.collides(edge_x, feet):
                    for xt in targets:
                        x_target = edge_x + d * 1e6 if xt is None else xt
                        if xt is not None and (xt - edge_x) * d < -EPS:
                            continue
                        start_x = edge_x + d * EPS * 10
                        sim = {}
                        to, _ = self.simulate(start_x, feet, 0.0, speed, x_target, info=sim)
                        if to is None or to == node:
                            continue
                        drop = (to[1] + 1) * T - feet
                        travel = self._travel(edge_x, to, d)
                        reach = m.rules.fall_reach(drop, speed)
                        h = (travel / reach if reach > 0 else INF) if travel > EPS else 0.0
                        add(to, "fall", h, 0.0, edge_x, travel, -drop, speed_name, xt=x_target, time=sim.get("time", 0.0),
                            land_x=sim.get("land_x"))
        return list(best.values())

    def _travel(self, x0, to, d):
        T = self.m.T
        near = to[0] * T if d > 0 else (to[0] + 1) * T
        return max(0.0, (near - x0) * d)

    # --- Dash (paso 9 de docs/propuesta-1-3.md §6.1) ---

    def dash_run(self, x, y, d, air=False):
        """Tramo del dash desde los pies en (x, y) hacia d: dash_distance en dash_duration (un cuadro de
        SIM_DT cada vez, gravedad 0). El terreno y los objetos solidos lo paran (Isak se queda pegado a
        la pared y el dash acaba antes); las plataformas de una via no frenan en horizontal. Devuelve la
        lista de x de cada cuadro (la ultima es el final) o None si toca pinchos o una Burbuja (la
        invulnerabilidad no se da por buena contra ellos: margen) o, con la holgura de techo calibrada y
        en el aire, si la cabeza pasa a menos de ceiling_margin_px de un solido."""
        m = self.m
        T = m.T
        frames = max(1, int(round(m.rules.dash_duration / SIM_DT)))
        step = m.rules.dash_distance / frames
        xs = []
        for _ in range(frames):
            nx = x + d * step
            if self.collides(nx, y):
                if d > 0:
                    cand = math.floor((nx + m.hw - EPS) / T) * T - m.hw
                else:
                    cand = (math.floor((nx - m.hw) / T) + 1) * T + m.hw
                if (cand - x) * d > EPS and not self.collides(cand, y):
                    xs.append(cand)
                break
            x = nx
            if self.in_hazard(x, y):
                return None
            if air and m.ceiling_margin is not None and self.collides(x, y - m.ceiling_margin):
                return None
            xs.append(x)
        return xs

    def stand_cell(self, x, r, d):
        """Celda de pie de la fila r bajo la x de los pies (en el borde, la de atras segun d), o None."""
        c = int(math.floor((x - d * EPS) / self.m.T))
        return (c, r) if self.is_node(c, r) else None

    def compute_dash_edges(self, node):
        """Movimientos con dash desde un nodo (paso 9): en el suelo (desde el centro de la celda o sus
        bordes, un tramo de dash_distance en la misma fila y, si acaba sin suelo, una caida) y en el aire
        (salto andando o en el sitio, dash desde el arco cada DASH_SAMPLE_S hasta la cumbre +
        DASH_AFTER_APEX_S y caida). Tras el dash Isak sigue a walk_speed (o se para y cae en vertical). Cada
        movimiento lleva "dash" (dir, air, xs, y, cuadros del salto antes del dash) y gasta dash_cost en el
        plan. Exigencia: vertical como un salto; horizontal, la distancia en el aire frente al alcance del
        salto mas dash_distance (0 en el suelo)."""
        m = self.m
        rules = m.rules
        if not self.is_node(*node):
            return []
        c, r = node
        T = m.T
        feet = (r + 1) * T
        best = {}
        speed = rules.walk_speed

        def add(e):
            key = (e["to"], e["kind"])
            old = best.get(key)
            if old is None or (round(max(e["h"], e["v"]), 6), round(e["time"], 6)) < (
                    round(max(old["h"], old["v"]), 6), round(old["time"], 6)):
                best[key] = e

        def fall_from(x1, y1, d, targets):
            out = []
            for xt in targets:
                sim = {"want_traj": True}
                # Tras el dash Isak sigue a walk_speed; si topa con una pared se para y vuelve a acelerar en el
                # aire (2026-10-20: el bot del 1-3 caia una celda antes bajo el escalon del techo del tunel).
                to, _ = self.simulate(x1 + d * EPS * 10, y1, 0.0, speed, x1 + d * 1e6 if xt is None else xt, info=sim,
                                      accel=rules.air_accel if rules.air_accel > 0.0 else None, vx0=speed)
                if to is None or to == node:
                    continue
                out.append((to, xt, sim))
            return out

        for d in (1, -1):
            edge_x = (c + 1) * T if d > 0 else c * T
            x_edge = edge_x if not self.collides(edge_x, feet) else edge_x - d * m.hw
            back_x = c * T if d > 0 else (c + 1) * T
            x_back = back_x if not self.collides(back_x, feet) else back_x + d * m.hw
            center = (c + 0.5) * T
            starts = [center] + [x for x in (x_edge, x_back) if abs(x - center) > EPS]
            cols = [(c + d * k) * T if d > 0 else (c + d * k + 1) * T for k in range(1, m.K + 4)]
            # En el suelo.
            for x0 in starts:
                xs = self.dash_run(x0, feet, d)
                if not xs:
                    continue
                x1 = xs[-1]
                info = {"dir": d, "air": False, "xs": xs, "y": feet, "pre": [], "x_start": x0}
                land = self.stand_cell(x1, r, d)
                if land is not None:
                    if land != node:
                        add({"to": land, "kind": "dash", "h": 0.0, "v": 0.0, "x0": x0,
                             "travel": abs(x1 - x0), "rise": 0.0, "speed": "walk", "xt": x1, "vy0": 0.0,
                             "time": len(xs) * SIM_DT, "land_x": x1, "dash": dict(info, fall=[], fall_xt=x1)})
                    continue
                for to, xt, sim in fall_from(x1, feet, d, [None, x1] + cols):
                    drop = (to[1] + 1) * T - feet
                    add({"to": to, "kind": "dash", "h": 0.0, "v": 0.0, "x0": x0,
                         "travel": self._travel(x0, to, d), "rise": -drop, "speed": "walk", "xt": x1, "vy0": 0.0,
                         "time": len(xs) * SIM_DT + sim.get("time", 0.0), "land_x": sim.get("land_x"),
                         "dash": dict(info, fall=list(sim.get("traj") or []), fall_xt=xt)})
            # En el aire (un dash por salto).
            if rules.air_dashes < 1:
                continue
            t_apex = rules.jump_v0 / rules.gravity
            ks = []
            t = DASH_SAMPLE_S
            while t <= t_apex + DASH_AFTER_APEX_S + EPS:
                ks.append(int(round(t / SIM_DT)))
                t += DASH_SAMPLE_S
            jump_speeds = [("walk", speed), ("stand", 0.0)]
            if rules.allow_run:
                jump_speeds.insert(1, ("run", rules.run_speed))
            for speed_name, jspeed in jump_speeds:
                for x0 in [x_edge, center] if jspeed > 0.0 else [center]:
                    arc = {"want_traj": True}
                    xt_jump = x0 + d * 1e6 if jspeed > 0.0 else x0
                    self.simulate(x0, feet, -rules.jump_v0, jspeed, xt_jump, head_lag=True, info=arc)
                    traj = arc.get("traj") or []
                    for k in ks:
                        if k >= len(traj):
                            break
                        xa, ya = traj[k]
                        if ya >= feet - EPS:
                            continue
                        xs = self.dash_run(xa, ya, d, air=True)
                        if not xs:
                            continue
                        x1 = xs[-1]
                        for to, xt, sim in fall_from(x1, ya, d, [None, x1]):
                            rise = feet - (to[1] + 1) * T
                            travel = self._travel(x0, to, d)
                            reach = rules.reach(rise, jspeed) + rules.dash_distance
                            h = travel / reach if travel > EPS else 0.0
                            v = max(0.0, rise) / rules.jump_height
                            if rise > rules.jump_height + EPS:
                                continue
                            add({"to": to, "kind": "jump_dash", "h": h, "v": v, "x0": x0, "travel": travel,
                                 "rise": rise, "speed": speed_name, "xt": xt_jump, "vy0": -rules.jump_v0,
                                 "time": k * SIM_DT + len(xs) * SIM_DT + sim.get("time", 0.0),
                                 "land_x": sim.get("land_x"),
                                 "dash": {"dir": d, "air": True, "xs": xs, "y": ya, "pre": list(traj[:k]),
                                          "x_start": xa, "after_s": k * SIM_DT, "jump_speed": jspeed,
                                          "fall": list(sim.get("traj") or []), "fall_xt": xt}})
        return list(best.values())


# --- Busqueda ---

# Coste secundario por movimiento (desempata caminos con la misma exigencia maxima).
STEP_COST = 0.01


def search(model, source, state, limit, debug="auto", avoid=None):
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
            cost = STEP_COST + (DASH_SEARCH_COST if e.get("dash") else 0.0)
            if e.get("pinched"):
                cost += PINCH_SEARCH_COST
            key = (round(max(c_max, dval), 9), round(c_sum + e["h"] + e["v"] + cost, 9))
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
    if node.__class__ is not tuple and getattr(node, "pinched", False):
        return {(c, r)}  # comprimido (Mundo 3): la caja cabe en su fila
    return {(c, r), (c, r - 1)}


class Validator:
    def __init__(self, level, rules):
        self.level = level
        self.rules = rules
        self.report = Report()
        self.model = LevelModel(level, rules)
        self.grid = level["grid"]
        self.result = {}
        self.export_requested = False
        self.planner = None
        # Meta y lo que necesita (terminal con requires_power: su fuente hecha; tanda H2 del paso 14).
        self.goal_cells = None
        self.goal_need = frozenset()

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

    def progression(self, source, gates0, limit, forbid=frozenset(), targets=None, debug="auto", avoid=None,
                    use_laser=True):
        """Avanza abriendo puertas hasta tocar `targets` (celdas). Devuelve dict con
        ok, stages [(src, state, cost, parent, opened_gate, opener_node, end_node)], reached.
        `avoid`: celdas que no se pisan; `use_laser`: si el laser (una vez disponible) abre puertas.
        Las piezas hechas de antemano (asistente conocido, model.initial) van siempre en el estado; si
        `targets` es la meta y la terminal necesita corriente, la meta solo cuenta con su fuente hecha
        (goal_need)."""
        state = frozenset(gates0) | self.model.initial
        need = self.goal_need if targets == self.goal_cells else frozenset()
        src = source
        stages = []
        reached_all = set()
        avoid = set(avoid) if avoid else None
        w3 = self.model.w3
        iterations = len(self.model.gates) + 1
        seen_states = None
        if w3 is not None and w3.like_gates:
            # Mundo 3 (paso 8a): corazones, publicaciones y reset de likes son acciones de la progresion; no se
            # repite un estado ya visto.
            iterations += w3.extra_iterations()
            seen_states = {(state, src)}
        for _ in range(iterations):
            cost, parent = search(self.model, src, state, limit, debug, avoid)
            reached_all |= set(cost)
            goal_nodes = [n for n in cost if self.touches(n, targets)] if need <= state else []
            if goal_nodes:
                end = min(goal_nodes, key=lambda n: (cost[n], n[0], n[1]))
                stages.append({"src": src, "state": state, "cost": cost, "parent": parent, "gate": None,
                               "end": end})
                return {"ok": True, "stages": stages, "reached": reached_all, "state": state}
            options = []
            relay_plans = {}
            for g in self.model.gates:
                if g.gid in state or g.gid in forbid or g.bypassable:
                    continue
                if getattr(g, "relay", None) is not None:
                    # Lector laser -> receptor enlazado (paso 10): el disparo sale de una celda ya
                    # alcanzable y el pulso tiene que llegar dentro de la ventana.
                    if not (use_laser and self.model.has_laser(state) and self.model.has_pulse(state)) or (
                            getattr(g, "cover", None) and g.cover not in state):
                        continue
                    plan = self.model.relay_plan(g, state, debug, sources=frozenset(cost))
                    relay_plans[g.gid] = plan
                    if plan["best"] is not None:
                        n = plan["best"]["pulse"]
                        options.append((cost.get(n, cost[plan["best"]["shot"]]), n[0], g, n))
                    continue
                for n in sorted(cost, key=lambda n: (cost[n], n[0], n[1])):
                    if self._gate_near(g, n) and self.model.can_open(g, n, state, debug, use_laser):
                        options.append((cost[n], n[0], g, n))
                        break
            if seen_states is not None:
                options += w3.like_options(cost, state, seen_states)
            if not options:
                stages.append({"src": src, "state": state, "cost": cost, "parent": parent, "gate": None,
                               "end": None, "relay_plans": relay_plans})
                return {"ok": False, "stages": stages, "reached": reached_all, "state": state}
            options.sort(key=lambda o: (o[0], o[1]))
            _, _, gate, opener = options[0]
            stage = {"src": src, "state": state, "cost": cost, "parent": parent, "gate": gate, "end": opener}
            if gate.gid in relay_plans:
                # El tramo hasta el disparo va por el arbol de la busqueda; del disparo al pulso, por el
                # camino mas rapido (relay_plan).
                stage["relay"] = relay_plans[gate.gid]["best"]
                stage["end"] = relay_plans[gate.gid]["best"]["shot"]
            stages.append(stage)
            if gate.kind in world3_model.ACTION_KINDS:
                state = w3.apply(state, gate)
                stage["likes_after"] = w3.likes_of(state)
                seen_states.add((state, opener))
            else:
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
        self.goal_cells = goal_cells
        self._check_power_sources()
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
            if model.w3 is not None:
                model.w3.check(self, start, goal_cells)
        else:
            self._describe_path(main)
        # Regla 2.
        self._check_checkpoints(start, main)
        # Regla 4 y secretos que son un objeto recogible.
        self._check_secrets(start, goal_cells)
        self._check_reachable_secrets(start)
        self._check_extra_lives(start, goal_cells)
        self._check_memory_pickups(start, goal_cells)
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
            # Paso 10: requisitos del diseno (laser / Debug) y plan del camino.
            self._check_requirements(start, goal_cells)
            if model.w3 is not None:
                # Mundo 3 (paso 8a): Pellizcar, likes, filtros y espejos sobre el camino principal.
                model.w3.check(self, start, goal_cells)
            if self.is_advanced() or self.export_requested:
                self._check_plan()
        return self.finish()

    def enemy_data(self, kind):
        """Datos de data/enemies/<kind>.json (cacheados)."""
        cache = self.__dict__.setdefault("_enemy_cache", {})
        if kind not in cache:
            cache[kind] = load_json(os.path.join(self.rules.root, "data", "enemies", "%s.json" % kind))
        return cache[kind]

    def is_advanced(self):
        """Nivel con objetos del paso 10 (laser a objetivos, recordatorios, pop-up translucido, barra,
        punto rojo, banner, chip del Debug, plataformas 'h' o bloque validation): se le hace el plan
        del camino (tools/level_plan.py) y se informa de el. El 1-1 no lo es (su salida no cambia)."""
        kinds = {"laser_receiver", "relay_receiver", "ad_cover", "reminder_platform", "snooze_button",
                 "overlay_popup", "update_bar", "power_switch", "debug_switch", "laser_switch", "charge_dock",
                 "dnd_switch", "blink_platform", "rhythm_zone", "alarm_tunnel", "clone_zone"}
        if self.model.w3 is not None:
            # Mundo 3 (paso 8a): plan del camino con los likes, el Debug de los filtros y Pellizcar.
            return True
        if any(o["type"] in kinds for o in self.level.get("objects", [])):
            return True
        if any(e["type"] in ("notification_badge", "spam_banner", "alarm_bell", "autoplay_video", "commenter")
               for e in self.level.get("enemies", [])):
            return True
        if self.model.dash_possible:
            # Paso 9 de docs/propuesta-1-3.md: el dash gasta energia y tiene enfriamiento (plan del camino).
            return True
        if any(g.kind == "pickup" and g.ability == "debug" for g in self.model.gates):
            return True
        if "validation" in self.level or self.model.is_vertical():
            return True
        return any("h" in row for row in self.grid) and self.model.debug_base

    def _check_plan(self):
        """Paso 10: plan del camino con tiempos, energia, enemigos y exportacion (tools/level_plan.py)."""
        import level_plan
        self.planner, info = level_plan.plan_level(self)
        if info is not None and (self.is_advanced() or self.export_requested):
            self.result["plan"] = info

    def _check_requirements(self, start, goal_cells):
        """validation.laser_required / debug_required (paso 10): el diseno exige el laser o el Debug
        para llegar a la meta."""
        val = self.model.validation
        forbid = self.secret_gates()
        info = {}
        if val.get("debug_required"):
            no_debug = self.progression(start, frozenset(), self.rules.limit, forbid=forbid, targets=goal_cells,
                                        debug=False)
            info["goal_without_debug"] = no_debug["ok"]
            if no_debug["ok"] and not self.model.initial:
                self.report.error("el nivel exige el Debug (validation.debug_required) pero la meta se alcanza sin "
                                  "plataformas ocultas ni el Debug")
        if info:
            self.result["requirements"] = info

    def _check_power_sources(self):
        """Terminal con requires_power (tanda H2 del paso 14 del 1-2): su power_source tiene que ser un
        punto de carga del nivel (charge_dock) y la meta solo cuenta cuando esta hecho (Calc cargada y
        teletransportada; goal_need). Las piezas que pide cada punto de carga existen."""
        m = self.model
        info = []
        need = set()
        for t in m.terminal_power:
            gate = next((g for g in m.gates if g.kind == "dock" and g.obj_id == t["source"]), None)
            entry = {"id": t["id"], "source": t["source"],
                     "powered_at_start": gate is not None and gate.gid in m.initial}
            if gate is None:
                self.report.error("la terminal %s necesita corriente de %s y no es un punto de carga del nivel"
                                  % (t["id"], t["source"] or "(sin power_source)"), t["cell"][1], t["cell"][0], t["id"])
            else:
                need.add(gate.gid)
                entry.update({"requires": list(gate.requires), "wait_s": round(gate.wait_s, 2),
                              "wait_parts": gate.wait_parts, "calc": gate.calc_id})
            info.append(entry)
        for g in m.gates:
            if g.kind != "dock":
                continue
            for rid, gid in zip(g.requires, g.requires_gids):
                if gid.startswith("missing:"):
                    self.report.error("%s pide la pieza %s, que no es un interruptor del nivel" % (g.label(), rid),
                                      g.row, g.col, g.label())
        self.goal_need = frozenset(need)
        if info:
            self.result["power"] = info

    def _check_laser_switches(self, seen):
        """El interruptor laser queda LEJOS (tanda H2): ninguna celda de pie alcanzable esta a su lado (misma
        fila, columna de al lado o la suya); solo se activa con el laser."""
        m = self.model
        nodes = {n for n, _ in seen}
        for g in m.gates:
            if g.kind != "lswitch" or g.gid in m.initial:
                continue
            near = sorted((n for n in nodes if n[1] == g.row and abs(n[0] - g.col) <= 1), key=lambda n: (n[0], n[1]))
            if near:
                n = near[0]
                self.report.error("%s se alcanza andando (Isak llega de pie a la fila %d, columna %d): tiene que "
                                  "quedar lejos, solo al alcance del laser" % (g.label(), n[1], n[0]),
                                  g.row, g.col, g.label())

    def _check_exit_terminals(self, main):
        """La terminal de salida se activa con el pulso desde el camino principal (sin mejoras ni laser)."""
        m = self.model
        T = m.T
        hit = m.catalog.get("exit_terminal", {}).get("hit_rect_px", [0, 0, T, 2 * T])
        last = main["stages"][-1]
        end_state = last["state"]
        if main["ok"]:
            # Habilidades recogidas de paso (p. ej. un encuentro con Eco que no hizo falta abrir
            # como puerta porque nada lo exigia antes de la terminal, como en una torre).
            touched = self._touched_pickups(main)
            end_state = end_state | touched
        terminals = []
        for obj in self.level.get("objects", []):
            if obj["type"] != "exit_terminal":
                continue
            tid = str(obj.get("params", {}).get("id", "terminal_%d_%d" % (obj["x"], obj["y"])))
            countdown = float(obj.get("params", {}).get("countdown_s", 0) or 0)
            if countdown > 0:
                # Cuenta automatica (2026-10-22, cierre del 2-1): sin pulso; la meta es llegar a la G
                # (dentro de la zona de la terminal) y esperar la cuenta.
                terminals.append({"id": tid, "pulse_from": None, "countdown_s": countdown})
                continue
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
                if m.can_open(gate, n, end_state, use_laser=False):
                    source = n
                    break
            if source is None:
                self.report.error("%s: el pulso no la alcanza desde ninguna celda del camino hacia la meta"
                                  % gate.label(), obj["y"], obj["x"], gate.label())
            terminals.append({"id": tid, "pulse_from": None if source is None else [source[1], source[0]]})
        self.result["exit_terminals"] = terminals

    def _main_nodes(self, run):
        """Nodos por los que pasa el camino de una progresion (en orden)."""
        nodes = []
        for stage in run["stages"]:
            if stage["end"] is None:
                continue
            seg = path_to(stage["parent"], stage["end"])
            nodes.append(stage["src"])
            nodes.extend(e["to"] for _, e in seg)
            if stage.get("relay"):
                nodes.extend(e["to"] for _, e in stage["relay"]["path"])
        return nodes

    def _touched_pickups(self, run):
        """gid de los ability_pickup / encuentros cuya celda toca el camino de `run`."""
        out = set()
        nodes = self._main_nodes(run)
        for g in self.model.gates:
            if g.kind != "pickup":
                continue
            cells = set(g.cells)
            if any(body_cells(n) & cells for n in nodes):
                out.add(g.gid)
        return frozenset(out)

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
        if m.is_vertical():
            # Torre (2026-10-16, paso 10): el orden por columnas no tiene sentido en vertical. Una
            # puerta que exija el pulso antes del encuentro deja sin camino a la meta (la busqueda
            # no la abre sin pulso) y lo explica _explain_failure ("aun no se tiene").
            info["vertical"] = True
            return
        first = min(g.col_span[0] for g in sources)
        info["available_from_col"] = first
        names = ", ".join(g.label() for g in sources)
        for g in m.gates:
            if g.kind == "pickup" or g.col_span[0] >= first:
                continue
            if g.kind == "bubble" and g.bypassable:
                continue
            if g.kind in ("bridge", "popup", "dnd") or g.kind == "bubble":
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
        if not self.model.has_debug(last["state"]) and any("h" in row for row in self.grid):
            # Paso 10: con las plataformas ocultas solidas (Debug) si se llegaria.
            with_debug = self.progression(start, frozenset(), INF, targets=goal_cells, debug=True)
            if with_debug["ok"]:
                rep.error("la meta solo se alcanza por plataformas ocultas 'h' (solidas con el Debug activo) y el Debug "
                          "no esta disponible (ni abilities_available.debug ni un chip ability_pickup de debug antes)")
        # Lo mas lejos que llega Isak: a la derecha en un nivel horizontal; arriba en una torre.
        if self.model.is_vertical():
            far = min(reached, key=lambda n: (n[1], -n[0]))
        else:
            far = max(reached, key=lambda n: (n[0], -n[1]))
        state = last["state"]
        pending = [g for g in self.model.gates if g.gid not in state and not g.bypassable and g.kind != "pickup"]
        near = (lambda g: abs(g.row - far[1]) <= 4) if self.model.is_vertical() else (
            lambda g: g.col_span[0] <= far[0] + self.model.K + 4)
        for g in pending:
            special = self._explain_gate_failure(g, state, last["cost"], near(g))
            if special is not None:
                if special:
                    rep.error(special, g.row, g.col, g.label())
                continue
            if not g.openers:
                what = {"bridge": "no tiene receptor", "popup": "no tiene boton de cerrar",
                        "bubble": "no se puede alcanzar", "ad": "no tiene zona", "bar": "no tiene zona"}[g.kind]
                rep.error("%s %s: el pulso no lo puede abrir" % (g.label(), what), g.row, g.col, g.label())
            elif not self.model.pulse_possible:
                rep.error("%s necesita el pulso y el nivel no lo tiene (abilities_available.pulse ni encuentro "
                          "con Eco)" % g.label(), g.row, g.col, g.label())
            elif not self.model.has_pulse(state):
                rep.error("%s necesita el pulso y aun no se tiene (lo da %s)" % (
                    g.label(), ", ".join(p.label() for p in self.model.gates
                                         if p.kind == "pickup" and p.ability == "pulse")), g.row, g.col, g.label())
            elif near(g):
                rep.error("%s: el pulso no alcanza %s desde ninguna celda alcanzable antes de el"
                          % (g.label(), " ni ".join(o[4] for o in g.openers)), g.row, g.col, g.label())
        if self.model.w3 is not None:
            for message, row, col in self.model.w3.explain(self, reached, state):
                rep.error(message, row, col)
        if not self.goal_need <= state and any(self.touches(n, goal_cells) for n in reached):
            # Tanda H2: se llega a la terminal pero no tiene corriente.
            missing = [g.label() for g in self.model.gates if g.gid in self.goal_need - state]
            rep.error("Isak llega a la meta pero la terminal de salida no tiene corriente (falta %s)"
                      % ", ".join(missing))
            return
        where = self.model.section_name(far[0], far[1]) or "sin tramo"
        if self.model.is_vertical():
            rep.error("no hay camino de P a G: Isak no sube de la fila %d (columna %d, %s); lo siguiente es la "
                      "fila %d" % (far[1], far[0], where, far[1] - 1), far[1], far[0])
        else:
            nxt = far[0] + 1
            rep.error("no hay camino de P a G: Isak no pasa de la fila %d, columna %d (%s); lo siguiente es la "
                      "columna %d" % (far[1], far[0], where, nxt), far[1], far[0])

    def _explain_gate_failure(self, g, state, reached, is_near):
        """Explicacion de una puerta del paso 10 que no se abre (anuncio, barra, lector -> receptor
        enlazado). None: la puerta es de las de siempre; "": nada que decir (lejos)."""
        m = self.model
        if g.kind == "pound":
            # Golpe al suelo (Mundo 2, paso 9 de docs/propuesta-mundo-2.md).
            if not is_near:
                return ""
            it = "lo" if getattr(g, "wall", False) else "la"
            if not m.pound_possible:
                return "%s solo %s rompe el golpe al suelo y el nivel no lo tiene (abilities_available.ground_pound " \
                    "ni un reproductor con el boton de pausa)" % (g.label(), it)
            if not m.has_pound(state):
                return "%s solo %s rompe el golpe al suelo y el reproductor que lo da no se alcanza antes" % (g.label(), it)
            if g.hidden and not m.debug_base:
                return "%s esta oculta: solo se ve (y se rompe) con el Debug y el nivel no lo tiene" % g.label()
            return "%s: la onda del golpe al suelo no %s alcanza desde ninguna celda alcanzable" % (g.label(), it)
        if g.kind == "dock":
            missing = [r for r, gid in zip(g.requires, g.requires_gids) if gid not in state]
            return "%s: Calc no se carga; faltan sin hacer: %s" % (g.label(), ", ".join(missing)) if missing else ""
        if g.kind == "lswitch":
            if not m.laser_possible:
                return "%s necesita el laser y el nivel no lo tiene" % g.label()
            if not m.has_laser(state):
                return "%s necesita el laser y aun no se tiene" % g.label()
            return ("%s: el laser no lo alcanza desde ninguna celda alcanzable (horizontal, a la altura del celular)"
                    % g.label())
        if g.kind == "switch" and g.hidden:
            debug_possible = m.debug_base or any(p.kind == "pickup" and p.ability == "debug" for p in m.gates)
            if not debug_possible:
                return ("%s solo se ve con el Debug y el nivel no lo tiene (ni abilities_available.debug ni un chip)"
                        % g.label())
            if not m.has_debug(state):
                return "%s solo se ve con el Debug y aun no se tiene" % g.label()
            near_nodes = [n for n in reached if m.reveal_near(g, n)]
            if not near_nodes:
                return ("%s: Isak no llega a %.0f px de el para descubrirlo con el Debug"
                        % (g.label(), g.reveal_radius))
            return "%s: el pulso no lo alcanza desde ninguna celda donde el Debug lo descubre" % g.label()
        if g.kind == "bar":
            if not is_near:
                return ""
            c0, r0, w, h = g.zone
            return ("%s: Isak no entra en su zona (columnas %d-%d, filas %d-%d) y no se arma"
                    % (g.label(), c0, c0 + w - 1, r0, r0 + h - 1))
        if g.kind == "ad":
            if not m.laser_possible:
                return "%s necesita el laser y el nivel no lo tiene" % g.label()
            if not m.has_laser(state):
                return "%s necesita el laser y aun no se tiene" % g.label()
            if not is_near:
                return ""
            return ("%s: el laser no lo alcanza desde ninguna celda alcanzable (horizontal, a la altura del "
                    "celular)" % g.label())
        relay = getattr(g, "relay", None)
        if relay is None:
            return None
        lector = relay.get("lector")
        if lector is None:
            return "%s: su receptor enlazado %s no tiene lector laser" % (g.label(), relay["id"])
        if not m.laser_possible:
            return "%s: el lector %s necesita el laser y el nivel no lo tiene" % (g.label(), lector["id"])
        if not m.has_laser(state):
            return "%s: el lector %s necesita el laser y aun no se tiene" % (g.label(), lector["id"])
        if getattr(g, "cover", None) and g.cover not in state:
            return ""
        plan = m.relay_plan(g, state, "auto", sources=frozenset(reached))
        if not plan["shots"]:
            return ("%s: el laser no alcanza el lector %s desde ninguna celda alcanzable (horizontal, a la altura "
                    "del celular)" % (g.label(), lector["id"]))
        closest = plan.get("closest")
        if closest is None:
            return ("%s: el pulso no alcanza el receptor enlazado %s desde ninguna celda a la que se llegue desde el "
                    "disparo al lector %s" % (g.label(), relay["id"], lector["id"]))
        t, b = closest
        return ("%s: la ventana del lector %s (%.1f s) no da tiempo: del disparo al pulso en (fila %d, columna %d) "
                "hacen falta %.1f s" % (g.label(), lector["id"], lector["window"], b[1], b[0], t))

    def _describe_path(self, run):
        actions = []
        edges_used = []

        def emit(segment, end):
            walk_from = None
            walk_pinched = False
            for prev, e in segment:
                edges_used.append((prev, e))
                if e["kind"] == "walk" and not e.get("debug"):
                    if walk_from is not None and bool(e.get("pinched")) != walk_pinched:
                        actions.append(self._walk_action(walk_from, prev, pinched=walk_pinched))
                        walk_from = None
                    if walk_from is None:
                        walk_from = prev
                        walk_pinched = bool(e.get("pinched"))
                    continue
                if walk_from is not None:
                    actions.append(self._walk_action(walk_from, prev, pinched=walk_pinched))
                    walk_from = None
                if e["kind"] in ("pinch", "unpinch"):
                    # Mundo 3 (paso 8a): comprimirse / recuperar el tamano (Pellizcar).
                    actions.append({"action": e["kind"], "at": [prev[1], prev[0]],
                                    "text": "%s en (fila %d, columna %d)%s" % (
                                        "comprimirse (Pellizcar)" if e["kind"] == "pinch" else "recuperar el tamano",
                                        prev[1], prev[0], self._section_suffix(prev[0], prev[1]))})
                    continue
                actions.append(self._walk_action(prev, e["to"], debug=True, pinched=bool(e.get("pinched")))
                               if e["kind"] == "walk" else self._move_action(prev, e))
            if walk_from is not None:
                actions.append(self._walk_action(walk_from, end, pinched=walk_pinched))

        for stage in run["stages"]:
            emit(path_to(stage["parent"], stage["end"]), stage["end"])
            if stage["gate"] is not None:
                n = stage["end"]
                g = stage["gate"]
                if g.kind == "plate":
                    # Mundo 3 (paso 8b): placa «Posa aqui» (el plan comprueba la puerta con el tiempo).
                    actions.append({"action": "plate", "from": [n[1], n[0]], "object": g.label(),
                                    "text": "pisa %s en (fila %d, columna %d) -> abre la puerta de marco %s"
                                            % (g.label(), n[1], n[0], g.target)})
                    continue
                if g.kind in world3_model.LIKE_KINDS:
                    # Mundo 3 (paso 8a): likes.
                    likes = stage.get("likes_after", 0)
                    if g.kind == "heart":
                        text = "recoge %s en (fila %d, columna %d) -> %d like(s)" % (g.label(), n[1], n[0], likes)
                    elif g.kind == "like_source":
                        text = "pulso desde (fila %d, columna %d) -> %s -> %d like(s)" % (n[1], n[0], g.label(), likes)
                    else:
                        text = "pulso de espaldas desde (fila %d, columna %d) -> %s -> 0 likes" % (n[1], n[0], g.label())
                    actions.append({"action": {"heart": "heart", "like_source": "pulse", "like_reset": "like_reset"}[g.kind],
                                    "from": [n[1], n[0]], "object": g.label(), "likes": likes, "text": text})
                    continue
                if g.kind == "pickup":
                    verb = "pasa por" if getattr(g, "encounter", False) else "recoge"
                    actions.append({"action": "pickup", "from": [n[1], n[0]], "object": g.label(),
                                    "text": "%s %s (%s) en (fila %d, columna %d)"
                                            % (verb, g.label(), g.ability, n[1], n[0])})
                    continue
                relay = stage.get("relay")
                if relay is not None:
                    # Patron 2: laser al lector, recorrido dentro de la ventana y pulso al receptor.
                    lector = relay["lector"]
                    actions.append({"action": "laser", "from": [n[1], n[0]], "object": "lector %s" % lector,
                                    "text": "laser desde (fila %d, columna %d) -> lector %s (ventana %.1f s)"
                                            % (n[1], n[0], lector, g.relay["lector"]["window"])})
                    emit(relay["path"], relay["pulse"])
                    b = relay["pulse"]
                    via = self.model.w3.beam_note(g.openers, b, stage["state"]) if (
                        self.model.w3 is not None and self.model.w3.hunters) else ""
                    actions.append({"action": "pulse", "from": [b[1], b[0]], "object": g.label(),
                                    "text": "pulso desde (fila %d, columna %d)%s -> receptor enlazado %s -> %s "
                                            "(%.1f s desde el disparo)"
                                            % (b[1], b[0], via, g.relay["id"], g.label(), relay["time"])})
                    continue
                if g.kind == "switch":
                    # Tanda H2: pulsos de espaldas (y, si es el panel oculto, antes el Debug que lo descubre).
                    actions.append({"action": "pulse", "from": [n[1], n[0]], "object": g.label(),
                                    "pulses": g.pulses, "face_back": True,
                                    "text": "%spulso x%d de espaldas desde (fila %d, columna %d) -> %s"
                                            % ("Debug para descubrirlo y " if g.hidden else "", g.pulses, n[1], n[0],
                                               g.label())})
                    continue
                if g.kind == "dnd":
                    # Paso 9 del 1-3: un pulso de espaldas da el dash.
                    actions.append({"action": "pulse", "from": [n[1], n[0]], "object": g.label(), "pulses": 1,
                                    "face_back": True,
                                    "text": "pulso de espaldas desde (fila %d, columna %d) -> %s (da el %s)"
                                            % (n[1], n[0], g.label(), g.ability)})
                    continue
                if g.kind == "pound":
                    # Mundo 2 (paso 9): golpe al suelo cuya onda rompe la tarjeta fragil (el muro «Cargando
                    # mas...», paso 9b: pounds golpes).
                    many = "%d golpes al suelo" % g.pounds if g.pounds > 1 else "golpe al suelo"
                    actions.append({"action": "ground_pound", "from": [n[1], n[0]], "object": g.label(),
                                    "text": "%s%s en (fila %d, columna %d) -> rompe %s"
                                            % ("Debug para ver la grieta y " if g.hidden else "", many, n[1], n[0],
                                               g.label())})
                    if g.pounds > 1:
                        actions[-1]["pounds"] = g.pounds
                    continue
                if g.kind == "lswitch":
                    actions.append({"action": "laser", "from": [n[1], n[0]], "object": g.label(),
                                    "text": "laser desde (fila %d, columna %d) -> %s (se queda activado)"
                                            % (n[1], n[0], g.label())})
                    continue
                if g.kind == "dock":
                    actions.append({"action": "wait", "from": [n[1], n[0]], "object": g.label(),
                                    "seconds": round(g.wait_s, 2),
                                    "text": "esperar %.1f s en (fila %d, columna %d) -> Calc entra, se carga en %s y se "
                                            "teletransporta: la terminal tiene corriente" % (g.wait_s, n[1], n[0], g.label())})
                    continue
                if g.kind == "bar":
                    actions.append({"action": "wait", "from": [n[1], n[0]], "object": g.label(),
                                    "seconds": round(g.wait_s, 2),
                                    "text": "esperar %.1f s en (fila %d, columna %d) -> %s se abre"
                                            % (g.wait_s, n[1], n[0], g.label())})
                    continue
                laser = g.kind == "ad" or (
                    g.kind == "bubble" and not self.model.can_open(g, n, stage["state"], use_laser=False))
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

    def _walk_action(self, a, b, debug=False, pinched=False):
        action = {"action": "walk", "from": [a[1], a[0]], "to": [b[1], b[0]],
                  "text": "andar%s de (fila %d, columna %d) a (fila %d, columna %d)%s%s"
                          % (" comprimido" if pinched else "", a[1], a[0], b[1], b[0], " con Debug" if debug else "",
                             self._section_suffix(b[0], b[1]))}
        if debug:
            action["debug"] = True
        if pinched:
            action["compressed"] = True
        return action

    def _move_action(self, prev, e):
        to = e["to"]
        names = {"jump": "saltar", "jump_run": "saltar corriendo", "fall": "caer", "dash": "deslizar (dash)",
                 "jump_dash": "saltar y deslizar en el aire (dash)"}
        rise = e["rise"]
        text = "%s de (fila %d, columna %d) a (fila %d, columna %d): %.0f px en el aire, %s %.0f px " \
               "-> %.0f %% horizontal, %.0f %% vertical%s%s" % (
                   names[e["kind"]], prev[1], prev[0], to[1], to[0], e["travel"],
                   "sube" if rise >= 0 else "baja", abs(rise), e["h"] * 100, e["v"] * 100,
                   (" (con Debug)" if e.get("debug") else "") + (" (comprimido)" if e.get("pinched") else ""),
                   self._section_suffix(to[0], to[1]))
        action = {"action": e["kind"], "from": [prev[1], prev[0]], "to": [to[1], to[0]],
                  "travel_px": round(e["travel"], 1), "rise_px": round(rise, 1),
                  "h": round(e["h"], 4), "v": round(e["v"], 4), "text": text}
        if e.get("debug"):
            action["debug"] = True
        if e.get("pinched"):
            action["compressed"] = True
        return action

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
            # requires_abilities (Mundo 3, paso 8b): con esas habilidades dadas.
            sv, sstart, needs = self._granted(s, start)
            without = sv.progression(sstart, frozenset(), self.rules.limit, targets=cell, debug=False)
            # Con la holgura calibrada (2026-10-17) el Debug se enciende donde hace falta (union de
            # movimientos, como en el camino): con el Debug siempre encendido una plataforma oculta
            # seria un techo en sitios donde nadie lo usa.
            mode = sv._debug_mode()
            # forbid_abilities (paso 9 de docs/propuesta-1-3.md): la ruta del secreto no usa esas habilidades
            # (p. ej. el dash); «sin Debug no se alcanza» se comprueba con todas.
            with sv.model.forbidding(self._forbidden_of(s)):
                with_debug = sv.progression(sstart, frozenset(), self.rules.limit, targets=cell, debug=mode)
            info.append({"id": s["id"], "without_debug": without["ok"], "with_debug": with_debug["ok"]})
            if needs:
                info[-1]["requires_abilities"] = list(needs)
            if self._forbidden_of(s):
                info[-1]["forbid_abilities"] = list(self._forbidden_of(s))
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

    def _debug_mode(self, calibrated=True):
        """Modo del Debug para «se alcanza con el Debug»: siempre encendido (True) o encendido donde hace falta
        ("auto", union de movimientos) con la holgura de techo calibrada (2026-10-17) o con el dash en el nivel
        (paso 9: el dash no se combina con el Debug; se apaga para deslizar)."""
        if (calibrated and self.model.ceiling_margin is not None) or self.model.dash_possible:
            return "auto"
        return True

    @staticmethod
    def _forbidden_of(secret):
        """Habilidades que la ruta del secreto no puede usar (forbid_abilities; paso 9 del 1-3)."""
        return tuple(str(a) for a in secret.get("forbid_abilities", []) or [])

    def _granted(self, secret, start):
        """requires_abilities (Mundo 3, paso 8b de docs/propuesta-mundo-3.md §7.1): el secreto se alcanza con un
        gesto obtenido mas adelante (p. ej. Pellizcar). Devuelve (validador, inicio, habilidades) con esas
        habilidades dadas desde el inicio (abilities_available), o (self, start, ()) sin el campo."""
        needs = tuple(str(a) for a in secret.get("requires_abilities", []) or [])
        if not needs:
            return self, start, ()
        cache = self.__dict__.setdefault("_granted_cache", {})
        if needs not in cache:
            import copy
            level = copy.deepcopy(self.level)
            abilities = dict(level.get("abilities_available") or {})
            for a in needs:
                abilities[a] = True
            level["abilities_available"] = abilities
            other = Validator(level, self.rules)
            other.goal_cells = self.goal_cells
            other_start, _ = other.spawn_node(self.find("P")[0])
            cache[needs] = (other, other_start)
        other, other_start = cache[needs]
        return other, other_start, needs

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
            forbid = self._forbidden_of(s)
            if forbid:
                item["forbid_abilities"] = list(forbid)
            # requires_abilities (Mundo 3, paso 8b): se comprueba con esas habilidades; sin ellas no cuenta como
            # inalcanzable (primera visita).
            sv, sstart, needs = self._granted(s, start)
            if needs:
                first = self.progression(start, frozenset(), self.rules.limit, targets=cell)
                item["requires_abilities"] = list(needs)
                item["reachable_without_abilities"] = first["ok"]
                if first["ok"]:
                    self.report.warning("el secreto %s se alcanza ya sin %s (requires_abilities)"
                                        % (what, ", ".join(needs)), s["y"], s["x"], s["id"])
            if not required or self.rules.has_upgrade(required):
                # Se tiene que alcanzar: sin las habilidades de forbid_abilities (paso 9).
                with sv.model.forbidding(forbid):
                    run = sv.progression(sstart, frozenset(), self.rules.limit, targets=cell)
            else:
                run = sv.progression(sstart, frozenset(), self.rules.limit, targets=cell)
            item.update({"reachable": run["ok"],
                         "secret_gates_opened": sorted(g for g in run["state"] if g in self.secret_gates())})
            if not required or self.rules.has_upgrade(required):
                if not run["ok"]:
                    self.report.error("el secreto %s no se alcanza%s%s" % (
                        what, " con la mejora %s" % required if required else "",
                        " ni con %s (requires_abilities)" % ", ".join(needs) if needs else ""), s["y"], s["x"], s["id"])
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
            with upgraded.model.forbidding(forbid):
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
            without = self.progression(start, frozenset(), self.rules.limit, targets={cell}, debug=False)
            item = {"id": oid, "cell": list(cell), "behind_glitch_wall": hidden,
                    "reachable_without_debug": without["ok"]}
            if hidden:
                with_debug = self.progression(start, frozenset(), self.rules.limit, targets={cell},
                                              debug=self._debug_mode(calibrated=False))
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

    def _check_memory_pickups(self, start, goal_cells):
        """Regla 4c (mensaje de secreto, memory_pickup; 2026-10-19): recogible del secreto que lo
        ofrece (recompensa memory), con lo que ese secreto exige y nada mas; nunca obligatorio."""
        objs = [o for o in self.level.get("objects", []) if o["type"] == "memory_pickup"]
        if not objs:
            return
        memories = {}
        data = load_json(os.path.join(self.rules.root, "data", "memories.json"))
        for m in (data or {}).get("memories", []):
            memories[m.get("id")] = m
        owners = {}
        for s in self.level.get("secrets", []):
            rewards = s.get("reward", [])
            rewards = [rewards] if isinstance(rewards, str) else list(rewards)
            if "memory" in rewards and s.get("memory_id"):
                owners[s["memory_id"]] = s
        items = []
        for obj in objs:
            cell = (obj["x"], obj["y"])
            mid = str(obj.get("params", {}).get("memory_id", ""))
            oid = str(obj.get("params", {}).get("id", mid))
            what = "%s (%s)" % (mid, oid)
            secret = owners.get(mid)
            item = {"id": oid, "memory_id": mid, "cell": list(cell), "secret": secret["id"] if secret else None}
            items.append(item)
            if secret is None:
                self.report.error("el mensaje %s no lo ofrece ningun secreto (recompensa memory)" % what,
                                  cell[1], cell[0], oid)
                continue
            needs_debug = bool(secret.get("needs_debug"))
            item["needs_debug"] = needs_debug
            # requires_abilities (Mundo 3, paso 8b): el mensaje se comprueba con esas habilidades.
            sv, sstart, needs = self._granted(secret, start)
            if needs:
                item["requires_abilities"] = list(needs)
            forbid = self._forbidden_of(secret)
            if forbid:
                item["forbid_abilities"] = list(forbid)
            # forbid_abilities (paso 9): lo que el secreto exige alcanzar se comprueba sin esas habilidades; lo
            # que NO debe alcanzarse (sin Debug, si lo exige), con todas.
            with sv.model.forbidding(() if needs_debug else forbid):
                without = sv.progression(sstart, frozenset(), self.rules.limit, targets={cell}, debug=False)
            item["reachable_without_debug"] = without["ok"]
            if needs_debug:
                mode = sv._debug_mode()
                with sv.model.forbidding(forbid):
                    with_debug = sv.progression(sstart, frozenset(), self.rules.limit, targets={cell}, debug=mode)
                item["reachable_with_debug"] = with_debug["ok"]
                if without["ok"]:
                    self.report.error("el mensaje %s se alcanza sin Debug (su secreto %s lo exige)"
                                      % (what, secret["id"]), cell[1], cell[0], oid)
                if not with_debug["ok"]:
                    self.report.error("el mensaje %s no se alcanza ni con el Debug" % what, cell[1], cell[0], oid)
            required = secret.get("requires_upgrade")
            if required:
                item["requires_upgrade"] = required
                catalog = upgrade_catalog.load_catalog(self.rules.root)
                resolved = upgrade_catalog.resolve(catalog, required)
                lap = int((memories.get(mid) or {}).get("first_lap", 1))
                if resolved is not None:
                    entry = upgrade_catalog.level_entry(catalog, resolved[0], resolved[1]) or {}
                    if int(entry.get("min_lap", 1)) > lap:
                        self.report.error("el mensaje %s exige %s, que en su acceso (%d) aun no se puede tener"
                                          % (what, required, lap), cell[1], cell[0], oid)
                if without["ok"] and not self.rules.has_upgrade(required):
                    self.report.error("el mensaje %s se alcanza sin la mejora %s de su secreto" % (what, required),
                                      cell[1], cell[0], oid)
                try:
                    upgraded = Validator(self.level, self.rules.with_upgrades([required]))
                    up_start, _ = upgraded.spawn_node(self.find("P")[0])
                    with upgraded.model.forbidding(forbid):
                        up_run = upgraded.progression(up_start, frozenset(), upgraded.rules.limit, targets={cell},
                                                      debug="auto" if needs_debug else False)
                    item["reachable_with_upgrade"] = up_run["ok"]
                    if not up_run["ok"]:
                        self.report.error("el mensaje %s no se alcanza ni con la mejora %s" % (what, required),
                                          cell[1], cell[0], oid)
                except ValueError as exc:
                    self.report.error("el mensaje %s pide una mejora que no existe: %s" % (what, exc),
                                      cell[1], cell[0], oid)
            elif not needs_debug and not without["ok"]:
                self.report.error("el mensaje %s no se alcanza sin Debug (su secreto %s no lo exige)"
                                  % (what, secret["id"]), cell[1], cell[0], oid)
            goal = self.progression(start, frozenset(), self.rules.limit, forbid=self.secret_gates(),
                                    targets=goal_cells, avoid={cell})
            item["mandatory"] = not goal["ok"]
            if not goal["ok"]:
                self.report.error("el mensaje %s es obligatorio: sin tocarlo no se llega a la meta" % what,
                                  cell[1], cell[0], oid)
        self.result["memories"] = items

    def _check_mandatory(self, start, goal_cells):
        secret = self.secret_gates()
        for g in self.model.gates:
            if g.bypassable or g.kind in ("pickup", "pound") or g.gid in self.model.initial:
                # Las tarjetas fragiles (Mundo 2) son atajos a proposito: no se exige que hagan falta.
                continue
            run = self.progression(start, frozenset(), INF, forbid=frozenset({g.gid}), targets=goal_cells)
            if g.gid in secret:
                if not run["ok"]:
                    self.report.warning("%s es de un secreto pero hace falta para llegar a la meta" % g.label(),
                                        g.row, g.col, g.label())
                continue
            if run["ok"]:
                what = {"bridge": "activar el receptor", "popup": "cerrar el pop-up",
                        "bubble": "aturdir la Burbuja", "ad": "romper el anuncio",
                        "bar": "esperar la barra", "switch": "activar el interruptor",
                        "lswitch": "disparar al interruptor", "dock": "cargar a Calc",
                        "dnd": "activar el interruptor No molestar (el dash)"}[g.kind]
                if g.kind == "dnd" and g.ability != "dash":
                    what = "activar %s (da el %s)" % (g.label(), g.ability)
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
        required = bool(self.model.validation.get("laser_required", False))
        if required:
            # Paso 10: el diseno exige el laser (lector, anuncio, Posponer...). Con un asistente conocido
            # (piezas hechas de antemano, tanda H2) no se exige: describe el nivel con su acertijo.
            self.result["abilities"]["laser_required"] = True
            if no_laser["ok"] and not self.model.initial:
                self.report.error("el nivel exige el laser (validation.laser_required) pero la meta se alcanza "
                                  "sin usarlo")
        elif self.model.laser_possible and not no_laser["ok"]:
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
            if g.open and g.col > first and g.laser_from is None and not m.is_vertical():
                self.report.warning("la Burbuja %s va tras el laser pero el laser no la alcanza desde ningun sitio"
                                    % g.obj_id, g.row, g.col, "Burbuja %s" % g.obj_id)

    def _gate_near(self, gate, node):
        """Verdadero si `node` esta cerca de algun rectangulo que abre la puerta (filtro barato
        antes de can_open: el pulso no llega mas lejos de su radio + medio tile; el laser, de su
        alcance; un ability_pickup se toca desde su columna o las de al lado)."""
        T = self.model.T
        if gate.kind == "pickup":
            return gate.col_span[0] - 1 <= node[0] <= gate.col_span[1] + 1
        if gate.kind == "bar":
            c0, r0, w, h = gate.zone
            return c0 <= node[0] < c0 + w and r0 <= node[1] < r0 + h
        if gate.kind == "dock":
            return True
        reach = self.rules.pulse_radius + T
        if gate.kind in ("bubble", "ad", "lswitch") and self.model.laser_possible:
            reach = max(reach, self.rules.laser_range + T)
        x = (node[0] + 0.5) * T
        if gate.kind == "bridge" and self.model.w3 is not None and self.model.w3.hunters:
            # Mundo 3 (paso 8b): el receptor tambien se activa pulsando un espejo cazador.
            if any(h["rect"][0] - reach <= x <= h["rect"][2] + reach for h in self.model.w3.hunters):
                return True
        return any(o[0] - reach <= x <= o[2] + reach for o in gate.openers)

    def _check_softlocks(self, main, goal_cells):
        """Grafo producto (nodo, puertas abiertas) restringido a lo que se alcanza desde P:
        hacia delante se anda, salta, cae o se abre una puerta desde donde el pulso la toca;
        hacia atras desde la meta se marcan los pares buenos. Soft-lock = par alcanzable desde
        el que ya no se llega a la meta."""
        m = self.model
        start = (main["stages"][0]["src"], m.initial)
        seen = {start}
        reverse = {}
        queue = [start]
        goals = []
        gates = [g for g in m.gates if not g.bypassable and (g.openers or g.kind in ("pickup", "bar", "dock"))]
        while queue:
            pair = queue.pop()
            node, state = pair
            if self.touches(node, goal_cells) and self.goal_need <= state:
                goals.append(pair)
            nexts = [(e["to"], state) for e in m.edges(node, state, "auto")]
            for g in gates:
                # Las tarjetas que solo rompe el golpe al suelo y estan ocultas se abren con el Debug activo
                # (2026-10-23, paso 13 del Mundo 2: la salida del bucle del 2-2; antes nunca se abrian aqui).
                debug = "auto" if g.kind == "pound" else False
                if g.gid not in state and self._gate_near(g, node) and m.can_open(g, node, state, debug):
                    nexts.append((node, state | {g.gid}))
            if m.w3 is not None and m.w3.softlock_actions:
                nexts += m.w3.softlock_nexts(node, state)
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
        self._check_laser_switches(seen)

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
        # Solo si una mejora los cambia (la salida sin mejoras o con wide_pulse no cambia).
        for key, (value, base) in self.rules.changed_by_upgrades().items():
            self.result["rules"][key] = value
            self.result["rules"]["base_" + key] = base
        if self.rules.allies:
            self.result["rules"]["allies"] = list(self.rules.allies)
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
            elif g.kind == "switch":
                entry.update({"pulses": g.pulses, "hidden": g.hidden, "pose_s": g.pose_s})
            elif g.kind == "dock":
                entry.update({"requires": list(g.requires), "wait_s": round(g.wait_s, 2)})
            elif g.kind == "dnd":
                entry["ability"] = g.ability
            elif g.kind == "pound" and g.pounds > 1:
                entry["pounds"] = g.pounds
            if g.kind in ("switch", "lswitch", "dock"):
                entry["done_at_start"] = g.gid in self.model.initial
            gates.append(entry)
        self.result["gates"] = gates
        return self.result


def validate(level, root=ROOT, limit=DEFAULT_LIMIT, jump_efficiency=DEFAULT_JUMP_EFFICIENCY, run=False,
             physics_path=None, check_schema=True, upgrades=(), time_margin=None, export=None, allies=None):
    """Valida un nivel ya cargado. Devuelve el dict de resultado (ok, errors, warnings, path, margins...).
    time_margin: margen de tiempo minimo (s) de las ventanas y cuentas (None: el del nivel o 1,5 s).
    export: lista; si se pasa, recibe el camino exportado (formato isak-path/1, tools/level_plan.py).
    allies (tanda H2 del paso 14 del 1-2): asistentes ya conocidos (allies_met). None = ninguno y, si el
    nivel tiene piezas con done_if_ally (el acertijo de Calc), se valida ademas el caso «conocidos»
    (result["allies_known"]: las piezas arrancan hechas y el camino va directo a la terminal); sus errores
    se suman con el prefijo «con <aliados> conocido(s)»."""
    if check_schema:
        schema_errors = validate_level_schema.validate_level(level, root)
        if schema_errors:
            return {"ok": False, "errors": [{"message": "esquema: " + e, "row": None, "col": None, "object": None}
                                            for e in schema_errors], "warnings": [], "path": []}
    if level.get("kind") == "boss":
        # Arena de jefe (2026-10-21, paso 5 de docs/propuesta-jefe-alerta-mayor.md §6): no hay camino de P a G
        # sino una pelea; la valida tools/validate_boss.py (carriles, cargadores, avisos, alcance del nucleo,
        # ventanas, compas de la fase 3 y energia de la pelea torpe). Sin camino que exportar.
        import validate_boss
        return validate_boss.validate_arena(level, root, upgrades=tuple(upgrades), physics_path=physics_path,
                                            jump_efficiency=jump_efficiency, limit=limit)
    # Mundo 2 (2026-10-22, paso 4 de docs/propuesta-mundo-2.md): tarjetas fragiles e Historias como las
    # piezas del Mundo 1 que reutilizan (tools/world2_model.py); sin ellas el nivel no cambia.
    level = world2_model.lower(level, level_catalog.load_catalog(root, int(level.get("world", 1))))
    # Mundo 3 (paso 8a de docs/propuesta-mundo-3.md): la herramienta Recortar como interruptor que da Pellizcar
    # (tools/world3_model.py); sin ella el nivel no cambia.
    level = world3_model.lower(level, level_catalog.load_catalog(root, int(level.get("world", 1))))
    rules = Rules(root, physics_path, jump_efficiency, limit, run or bool(level.get("allow_run", False)),
                  tuple(upgrades), tuple(allies or ()))
    rules.time_margin = time_margin
    rules.set_level_debug_world_scale(level.get("debug_world_scale"))
    validator = Validator(level, rules)
    validator.export_requested = export is not None
    result = validator.run()
    if export is not None and validator.planner is not None and getattr(validator.planner, "steps", None):
        export.append(validator.planner.export())
    if allies is None and validator.model.ally_pieces:
        known = Validator(level, rules.with_allies(validator.model.ally_pieces))
        # El terreno de cada estado de las puertas es el mismo: se reutilizan los mundos, los movimientos y
        # los acertijos del lector ya calculados (claves por gid y estado).
        known.model._worlds = validator.model._worlds
        known.model._edges = validator.model._edges
        known.model._relay_cache = validator.model._relay_cache
        known_result = known.run()
        plan = known_result.get("plan") or {}
        labels = {g.label() for g in known.model.gates if g.kind in ("switch", "lswitch", "dock")}
        puzzle = [a for a in known_result.get("path", []) if a.get("object") in labels]
        summary = {"allies": list(validator.model.ally_pieces), "ok": known_result["ok"],
                   "errors": known_result["errors"], "warnings": known_result["warnings"],
                   "path_actions": len(known_result.get("path", [])),
                   "puzzle_actions": len(puzzle),
                   "duration_s": plan.get("duration_s"),
                   "energy_min": (plan.get("energy") or {}).get("min"),
                   "power": known_result.get("power", [])}
        result["allies_known"] = summary
        prefix = "con %s conocido(s): " % ", ".join(validator.model.ally_pieces)
        for e in known_result["errors"]:
            result["errors"].append(dict(e, message=prefix + e["message"]))
        for w in known_result["warnings"]:
            result["warnings"].append(dict(w, message=prefix + w["message"]))
        if puzzle:
            result["errors"].append({"message": prefix + "el camino aun pasa por el acertijo (%s)"
                                     % ", ".join(a["object"] for a in puzzle), "row": None, "col": None,
                                     "object": None})
        result["ok"] = not result["errors"]
    return result


def _num(value):
    """Numero sin decimales si es entero (8, 0.3)."""
    return "%d" % value if abs(value - round(value)) < EPS else ("%g" % value)


def format_text(path, result):
    if "boss" in result:
        import validate_boss
        return validate_boss.format_text(path, result)
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
        changed = [(label, rules[key], rules["base_" + key]) for key, label in (
            ("laser_energy_cost", "coste del laser"), ("laser_cooldown_s", "enfriamiento del laser (s)"),
            ("debug_drain_per_s", "gasto del Debug (/s)"), ("energy_max", "energia maxima"),
            ("sync_rate_max", "Sync Rate maximo"), ("debug_world_time_scale", "mundo con el Debug (x)"),
            ("debug_hold_s", "carga del Debug (s)")) if key in rules]
        if changed:
            out.append("  mejoras: " + "; ".join("%s %s (base %s)" % (label, _num(value), _num(base))
                                                  for label, value, base in changed))
    for item in (result.get("secrets") or {}).get("items", []):
        if item.get("requires_abilities") and "reachable" in item:
            # Mundo 3 (paso 8b): secreto que se alcanza con un gesto obtenido mas adelante.
            out.append("  secreto %s: con %s %s; sin ello %s (no cuenta en la primera visita)" % (
                item["id"], ", ".join(item["requires_abilities"]),
                "se alcanza" if item["reachable"] else "no se alcanza",
                "se alcanza" if item.get("reachable_without_abilities") else "no se alcanza"))
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
    for item in result.get("memories") or []:
        if item.get("secret") is None:
            continue
        if item.get("needs_debug"):
            reach = "sin Debug %s; con el Debug %s" % (
                "se alcanza" if item["reachable_without_debug"] else "no se alcanza",
                "se alcanza" if item.get("reachable_with_debug") else "no se alcanza")
        else:
            reach = "se alcanza sin Debug" if item["reachable_without_debug"] else "no se alcanza sin Debug"
        if item.get("requires_upgrade"):
            reach += "; con %s %s" % (item["requires_upgrade"],
                                     "se alcanza" if item.get("reachable_with_upgrade") else "no se alcanza")
        if item.get("forbid_abilities"):
            reach += " (ruta sin %s)" % ", ".join(item["forbid_abilities"])
        if item.get("requires_abilities"):
            reach += " (con %s)" % ", ".join(item["requires_abilities"])
        out.append("  mensaje %s (%s, fila %d, columna %d) del secreto %s: %s; %s" % (
            item["memory_id"], item["id"], item["cell"][1], item["cell"][0], item["secret"], reach,
            "obligatorio" if item["mandatory"] else "opcional"))
    pulse = result.get("pulse")
    if pulse and not pulse["from_start"] and pulse["given_by"] and pulse.get("vertical"):
        out.append("  pulso: no existe al empezar; lo da %s (torre: sin regla por columnas)" % (
            ", ".join(pulse["given_by"])))
    elif pulse and not pulse["from_start"] and pulse["given_by"]:
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
        if item.get("countdown_s"):
            out.append("  terminal de salida %s: se activa sola con la cuenta de %g s al llegar a la meta (sin pulso)"
                       % (item["id"], item["countdown_s"]))
            continue
        out.append("  terminal de salida %s: %s" % (
            item["id"], "se activa con el pulso desde (fila %d, columna %d)" % tuple(frm) if frm else "NO se activa"))
    for item in result.get("power") or []:
        if item.get("powered_at_start"):
            out.append("  corriente de la terminal %s: %s ya hecho (asistente conocido): con corriente desde el inicio"
                       % (item["id"], item["source"]))
        elif "wait_s" in item:
            parts = item.get("wait_parts", {})
            out.append("  corriente de la terminal %s: %s con %s hechos; espera de Calc %.1f s (despertar %.1f, caminar "
                       "%.1f, carga %.1f, cara despierta %.1f, teletransporte %.1f)" % (
                           item["id"], item["source"], ", ".join(item["requires"]), item["wait_s"],
                           parts.get("wake_s", 0.0), parts.get("walk_s", 0.0), parts.get("charge_s", 0.0),
                           parts.get("charged_hold_s", 0.0), parts.get("teleport_s", 0.0)))
    known = result.get("allies_known")
    if known:
        out.append("  con %s conocido(s): %s; %d acciones (%d del acertijo)%s%s" % (
            ", ".join(known["allies"]), "OK" if known["ok"] else "FALLA", known["path_actions"],
            known["puzzle_actions"],
            "" if known.get("duration_s") is None else ", unos %.1f s" % known["duration_s"],
            "" if known.get("energy_min") is None else ", energia minima %.0f" % known["energy_min"]))
    out.extend(world3_model.format_lines(result))
    out.extend(format_plan(result.get("plan")))
    for e in result["errors"]:
        out.append("  ERROR: " + e["message"])
    for w in result["warnings"]:
        out.append("  AVISO: " + w["message"])
    return "\n".join(out)


def format_plan(plan):
    """Lineas del plan del camino (paso 10): acertijos, recordatorios, pop-ups, Debug, enemigos y
    energia."""
    if not plan:
        return []
    out = ["  plan: %d pasos, unos %.1f s (%.1f s de tiempo del mundo); margen de tiempo minimo %.1f s"
           % (plan.get("steps", 0), plan.get("duration_s", 0.0), plan.get("duration_world_s", 0.0),
              plan.get("time_margin_s", DEFAULT_TIME_MARGIN_S))]
    for r in plan.get("relays", []):
        out.append("    acertijo %s -> %s: disparo desde (fila %d, columna %d), pulso a los %.1f s de %.1f s de "
                   "ventana (sobran %.1f s)" % (r["lector"], r["bridge"], r["shot_from"][0], r["shot_from"][1],
                                                r["time_s"], r["window_s"], r["spare_s"]))
    puzzle = plan.get("calc_puzzle") or {}
    if puzzle:
        out.append("    acertijo de Calc: %d pulso(s) de espaldas, %d disparo(s) al interruptor laser%s, Debug %d vez/veces "
                   "(pared y panel), espera de Calc %s; unos %.1f s" % (
                       puzzle["pulses"], puzzle["lasers"],
                       " desde (fila %d, columna %d)" % tuple(puzzle["laser_from"]) if puzzle.get("laser_from") else "",
                       puzzle["debug_uses"],
                       "-" if puzzle.get("calc_wait_s") is None else "%.1f s" % puzzle["calc_wait_s"],
                       puzzle["duration_s"]))
    for r in plan.get("reminders", []):
        out.append("    recordatorios %s: cuenta %.1f s (aviso %.1f, vuelven a los %.1f); sin Posponer %s; con Posponer "
                   "%s; plan: %d disparo(s) al Posponer, sobran %s%s" % (
                       r["group"], r["timer_s"], r["warn_s"], r["respawn_s"],
                       "no da tiempo" if r["without_snooze"] is None else "sobran %.1f s" % r["without_snooze"],
                       "no da tiempo" if r["with_snooze"] is None else "sobran %.1f s" % r["with_snooze"],
                       r["snooze_shots"], "?" if r.get("planned_slack_s") is None else "%.1f s" % r["planned_slack_s"],
                       " (exige el Posponer)" if r["required"] else ""))
        if r.get("snooze_shots") and r.get("min_left_s") is not None:
            out.append("      la cuenta baja hasta %.1f s antes de que llegue el Posponer" % r["min_left_s"])
    for o in plan.get("overlays", []):
        if o["covers_path"]:
            how = ("se cierra con el pulso desde (fila %d, columna %d)" % tuple(o["closed_from"]) if o["closed_from"]
                   else "se ve con el Debug" if o["debug_view"] else "se cruza a ciegas")
            out.append("    pop-up translucido %s: tapa el camino; %s" % (o["id"], how))
    debug = plan.get("debug") or {}
    for seg in debug.get("segments", []):
        out.append("    Debug de (fila %d, columna %d) a (fila %d, columna %d): %.1f s activo, %.0f de energia"
                   % (seg["from"][0], seg["from"][1], seg["to"][0], seg["to"][1], seg["active_s"], seg["energy"]))
    for b in plan.get("banners", []):
        if "start_phase_s" in b:
            # Paso 9b: con videos en autoplay o Comentaristas, todas las amenazas del cruce.
            what = "banners %s" % ", ".join(b["banners"]) if not b.get("feed") else "amenazas %s" % ", ".join(
                b["banners"] + b.get("bells", []) + b["feed"])
            out.append("    %s: cruce de %.1f s desde (fila %d, columna %d) en la fase %.2f s de %.1f s "
                       "(%d espera(s), %d salto(s) en el sitio%s)" % (
                           what, b["crossing_s"], b["entry"][0], b["entry"][1], b["start_phase_s"],
                           b["period_s"], b["waits"], b["hops"],
                           ", %d dash(es)" % b["dashes"] if b.get("dashes") else ""))
        elif "crossing_s" in b:
            # Paso 9 de docs/propuesta-1-3.md: cruce al compas de un metronomo (sin fase libre).
            parts = [("banners", b.get("banners")), ("campanas", b.get("bells")), ("plataformas", b.get("blinks")),
                     ("videos y Comentaristas", b.get("feed"))]
            what = "; ".join("%s %s" % (k, ", ".join(v)) for k, v in parts if v)
            out.append("    al compas de %s (%s): cruce de %.1f s desde (fila %d, columna %d) (%d espera(s), %d salto(s) "
                       "en el sitio, %d dash(es))" % (", ".join(b.get("rhythm") or []) or "-", what, b["crossing_s"],
                                                     b["entry"][0], b["entry"][1], b["waits"], b["hops"],
                                                     b.get("dashes", 0)))
        for bid, req in sorted((b.get("dash_required") or {}).items()):
            out.append("      banner %s (dash_required): sin dash %s; con dash %s; ventana del dash %s" % (
                bid, "se cruza" if req["without_dash_walking"] or req["without_dash_running"] else "no se cruza",
                "se cruza" if req["with_dash"] else "no se cruza",
                "-" if req["dash_window_s"] is None else "%.2f s" % req["dash_window_s"]))
    for b in plan.get("bars", []):
        out.append("    barra del 99 %% %s: espera de %.1f s en (fila %d, columna %d); %d enemigo(s) en oleadas, que no se "
                   "modelan (se esquivan o se aturden; no hace falta derrotarlos)" % (
                       b["id"], b["wait_s"], b["at"][0], b["at"][1], b["wave_enemies"]))
    for z in plan.get("clones", []):
        # Paso 9b: zona de clones de «Un video mas» simulada a lo largo del camino.
        out.append("    zona de clones %s: %.1f s dentro, nacen %d clon(es) (como mucho %d a la vez); %d golpe(s) al suelo "
                   "para limpiarla" % (z["id"], z["inside_s"], z["spawned"], z["max_alive"], z["pounds"]))
    for b in plan.get("badges", []):
        out.append("    punto rojo %s: %d golpe(s), %d aturdido(s) con el pulso" % (b["id"], b["hits"], b["stuns"]))
    scroll = plan.get("scroll")
    if scroll:
        out.append("    scroll forzado: arranca a los %s; margen minimo %s tiles del borde%s (exigido %g); %d espera(s) por el "
                   "techo de carga (%.1f s)%s" % (
                       "-" if scroll["start_s"] is None else "%.1f s" % scroll["start_s"],
                       "-" if scroll["margin_min_tiles"] is None else "%.1f" % scroll["margin_min_tiles"],
                       "" if not scroll.get("at") else " en (fila %d, columna %d)" % tuple(scroll["at"]),
                       scroll["required_tiles"], scroll["waits"], scroll["wait_s"],
                       "; bucles: %s" % ", ".join(scroll["loops"]) if scroll.get("loops") else ""))
    for lp in plan.get("loop_energy", []):
        # Regla anti-atasco de los bucles (2026-10-23, arreglo tras la primera prueba del usuario).
        if lp.get("charger"):
            out.append("    bucle %s: la salida pide %.0f de energia; peor caso (entra sin energia): recarga en %s "
                       "(+%.0f, enfriamiento %.1f s; una repeticion dura %.1f s) y sale sin tocar el borde" % (
                           lp["id"], lp["need"], lp["charger"], lp["amount"], lp["cooldown_s"], lp["repeat_s"]))
    energy = plan.get("energy")
    if energy:
        out.append("    energia: empieza en %.0f, gasta %.0f, recupera %.0f, minimo %.0f, termina en %.0f%s%s" % (
            energy["start"], energy["used"], energy["gained"], energy["min"], energy["end"],
            "; %d desvio(s) a un cargador" % energy["charger_detours"] if energy["charger_detours"] else "",
            "; %d dash(es)" % energy["dashes"] if energy.get("dashes") else ""))
        if "debug_drain_per_s" in energy:
            out.append("    gasto del Debug en este nivel: %.1f/s (debug_drain_scale)" % energy["debug_drain_per_s"])
        if "debug_world_scale" in energy:
            out.append("    mundo con el Debug en este nivel: x%g (debug_world_scale)" % energy["debug_world_scale"])
    return out


def access_cap_upgrades(level, lap=None, root=ROOT):
    """Cada pista de data/upgrades.json en el tope del acceso de `lap` (por defecto el `lap` del JSON del
    nivel, 1 = Cache): ["pulso:3", "laser:3", ...]. La meta debe seguir alcanzandose con todo lo que el
    jugador puede tener comprado en esa vuelta (paso 9 de docs/propuesta-mejoras.md)."""
    catalog = load_upgrades(root)
    if level.get("kind") == "boss":
        # Las arenas de jefe validan cada acceso con su propio tope (tools/validate_boss.py).
        return []
    lap = int(lap if lap is not None else level.get("lap", 1))
    return ["%s:%d" % (t["id"], upgrade_catalog.access_cap(catalog, t["id"], lap)) for t in upgrade_catalog.tracks(catalog)]


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
                        help="mejoras compradas separadas por comas: pista:nivel de data/upgrades.json (p. ej. "
                             "pulso:2,laser:3) o un legacy_id (wide_pulse = pulso:2); por defecto ninguna")
    parser.add_argument("--access-cap", action="store_true",
                        help="anade todas las pistas en el tope del acceso del nivel (paso 9 de "
                             "docs/propuesta-mejoras.md): lap del JSON del nivel (1 Cache = nivel 3, 2 Kernel = 4, "
                             "3 Raiz = 5) o --lap")
    parser.add_argument("--lap", type=int, default=None, help="vuelta para --access-cap (1-3)")
    parser.add_argument("--time-margin", type=float, default=None,
                        help="margen minimo (s) que debe sobrar en ventanas y cuentas (por defecto "
                             "validation.time_margin_s del nivel o 1,5)")
    parser.add_argument("--export-path", default=None,
                        help="escribe el camino (pasos con tiempos, formato isak-path/1) en este JSON; un solo nivel")
    parser.add_argument("--allies", default=None,
                        help="asistentes ya conocidos (allies_met, p. ej. calc): las piezas con done_if_ally "
                             "arrancan hechas; sin la opcion se validan los dos casos y se exporta el de "
                             "desconocidos")
    args = parser.parse_args(argv[1:])
    if args.export_path and len(args.levels) != 1:
        print("--export-path admite un solo nivel", file=sys.stderr)
        return 2
    failed = False
    outputs = {}
    for path in args.levels:
        export = [] if args.export_path else None
        try:
            level = load_json(path)
            upgrades = [u.strip() for u in args.upgrades.split(",") if u.strip()]
            if args.access_cap:
                upgrades += access_cap_upgrades(level, args.lap)
            result = validate(level, limit=args.limit, jump_efficiency=args.jump_efficiency, run=args.run,
                              physics_path=args.physics,
                              upgrades=upgrades,
                              time_margin=args.time_margin, export=export,
                              allies=None if args.allies is None else
                              [a.strip() for a in args.allies.split(",") if a.strip()])
        except (OSError, ValueError, KeyError) as exc:
            print("%s: no se pudo validar (%s)" % (path, exc), file=sys.stderr)
            return 2
        if export is not None:
            if export:
                with open(args.export_path, "w", encoding="utf-8") as handle:
                    json.dump(export[0], handle, ensure_ascii=False, indent=1)
                    handle.write("\n")
                if not args.json:
                    print("camino exportado: %s (%d pasos)" % (args.export_path, len(export[0]["steps"])))
            else:
                print("%s: sin camino que exportar" % path, file=sys.stderr)
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
