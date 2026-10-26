#!/usr/bin/env python3
"""Plan del camino de un nivel (paso 10 de docs/propuesta-1-2.md §10, 2026-10-16).

Lo usa tools/validate_level.py despues de encontrar el camino de P a G (las puertas y las
habilidades como estado del grafo): convierte ese camino en una secuencia de pasos con tiempos
y comprueba lo que un grafo de celdas no ve:

  - Acertijo lector laser -> receptor enlazado -> puente (patron 2): del disparo al pulso tiene
    que sobrar el margen (validation.time_margin_s, 1,5 s por defecto) dentro de la ventana
    window_s (tiempo del mundo). Lo calcula LevelModel.relay_plan (el disparo mas cercano en tiempo:
    un 2.o disparo rellena la ventana, asi que cuenta el ultimo).
  - Recordatorios (reminder_platform): cuenta compartida por grupo desde que Isak pisa uno; el
    camino tiene que salir del grupo con el margen antes de que caiga. Posponer (snooze_button):
    el laser desde una celda del grupo suma extend_s (tope cap_s, enfriamiento cooldown_s). Con
    validation.snooze_required [grupos] se exige que SIN Posponer no de tiempo y CON el si.
  - Pop-up translucido (overlay_popup): si tapa el camino, se cierra con el pulso desde el camino
    (o un desvio corto) o se ve con el Debug; si no, aviso de que se cruza a ciegas.
  - Debug: tramos del camino que solo existen con el Debug activo (plataformas 'h'); se enciende
    manteniendo activation_hold_s y gasta drain_per_second de energia en tiempo real.
  - Banners (spam_banner): amenaza periodica; busqueda por tiempo (celda, fase) con esperas en
    celdas seguras y saltos en el sitio; el bot espera en la entrada a la fase indicada. Desde el paso 9
    de docs/propuesta-1-3.md (2026-10-20) la misma busqueda lleva el dash (invulnerable, enfriamiento),
    los banners y campanas que siguen un metronomo (rhythm_zone / alarm_tunnel, con su estado exacto),
    las plataformas que parpadean (solo se pisan encendidas) y validation.dash_required.
  - Puntos rojos (notification_badge): simulacion a lo largo del camino; si se va a lanzar y el
    pulso lo alcanza, se aturde (pulso insertado). El dano que quede tiene que caber en
    validation.sync_damage_budget (0 por defecto).
  - Barra del 99 % (update_bar): espera fija (rise_s + wait_s + full_s) en su zona; las oleadas no
    se modelan (se esquivan o se aturden; no es obligatorio derrotarlas).
  - Energia: empieza en validation.start_energy (100); laser 10 por disparo, dash 10, Debug 20/s; cargadores
    tocados (+amount, enfriamiento), chip del Debug con refill_energy (llena) y drops de lo que se
    mata. Si falta energia en un paso obligatorio, desvio a un cargador alcanzable; si no hay,
    error «sin energia en el paso N».

El resultado (dict) va en result["plan"] y, con --export-path, se escribe como JSON para un bot
determinista (formato «isak-path/1», documentado en .claude/skills/level-builder/SKILL.md).

No modela: las oleadas de la barra, la persecucion de enemigos que caen del techo, la aceleracion
fina de Isak (usa velocidad constante y un arranque START_S tras cada salto o pose), el
retroceso al recibir dano ni la energia que gasta el jugador en lo opcional.
"""

import heapq
import math

import world3_model

DT = 1.0 / 60.0
EPS = 1e-6
INF = float("inf")
FORMAT = "isak-path/1"
# Disparos al Posponer que se prueban dentro de un mismo cruce de recordatorios.
MAX_SNOOZE_SHOTS = 3
# Celdas de margen alrededor de la zona de un banner para la busqueda por tiempo.
HAZARD_PAD = 4
# Celdas que una muestra de un movimiento puede alejarse de las celdas de pie de la zona de la busqueda por
# tiempo, en x (cuerpo de Isak; saltos, caidas y dashes van de una celda de la zona a otra) y en y (cumbre
# del salto de 3 tiles + el cuerpo): el periodo de la fase se calcula con las amenazas del reloj del nivel
# de esa caja (paso 10 del 1-3; si un movimiento toca otra, la busqueda se repite con el periodo general).
SEARCH_REACH_X_TILES = 2
SEARCH_REACH_Y_TILES = 6
# Paso de fase de la busqueda de banners (s).
PHASE_BIN = 1.0 / 30.0
# Iteraciones maximas de la simulacion de puntos rojos (cada aturdimiento reinicia).
MAX_STUNS = 12
# Cuenta minima (s) de un recordatorio cuando Isak esta encima o le llega el disparo al Posponer.
REMINDER_STAND_S = 0.1
# Huecos de tiempo (s) sin plataformas ocultas que no apagan el Debug entre dos tramos.
DEBUG_GAP_S = 1.0
# Tiempo (s reales) con el Debug activo junto al panel oculto para que lo descubra (tanda H2 del paso
# 14 del 1-2: PowerSwitch lo descubre en el primer cuadro con el Debug activo cerca; se deja margen).
REVEAL_S = 0.2
# Dash (paso 9 de docs/propuesta-1-3.md): coste extra (s) de cada dash en la busqueda por tiempo (gasta
# energia: se prefiere esperar o andar si da igual), ventana minima (s) para lanzar el dash de un banner
# obligatorio (validation.dash_required) y hasta donde se mide esa ventana.
DASH_PLAN_COST = 1.0
DASH_WINDOW_MIN_S = 0.3
DASH_WINDOW_SCAN_S = 1.0
# Celda (s) del enfriamiento del dash en el estado de la busqueda por tiempo.
DASH_COOLDOWN_BIN = 0.1
# Arranque desde parado tras un salto (s; el START_S de tools/validate_level.py, edge_time).
START_S = 0.06
# Pasos que dejan a Isak parado (el siguiente movimiento arranca acelerando con el arco real; tambien los
# saltos, caidas y dashes: el bot frena en el centro de la celda de llegada).
REST_ACTIONS = ("wait", "wait_phase", "wait_beat", "hop", "pulse", "laser", "debug_on", "debug_off", "ground_pound",
                "wait_scroll", "like_reset")
# Scroll forzado (Mundo 2, paso 9 de docs/propuesta-mundo-2.md §7.1): espera maxima por el techo de carga (s) y
# margen frente al borde que dana por defecto (tiles; 3 en dificultad 2-3 y 2 en dificultad 4).
SCROLL_MAX_WAIT_S = 120.0
SCROLL_HEAD_MARGIN_PX = 8.0
# Mundo 2, paso 9b: tipos de amenaza con tiempo del feed (proyectiles de la cuenta y del Comentarista; rayo del
# video, que cae en la columna de Isak al empezar el clip), vista de la camara (px; la tarjeta del video entera
# a la vista activa sus clips), paso (px) con el que se busca el terreno que apaga un proyectil y golpes al suelo
# que el plan puede anadir para limpiar zonas de clones.
FEED_KINDS = ("shot", "ray")
VIEW_W_PX = 1280.0
VIEW_H_PX = 720.0
SHOT_PROBE_PX = 4.0
MAX_CLONE_POUNDS = 40


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
        return {(c, r)}  # comprimido (Mundo 3, paso 8a)
    return {(c, r), (c, r - 1)}


def rects_overlap(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


class Planner:
    def __init__(self, validator):
        self.v = validator
        self.m = validator.model
        self.rules = validator.rules
        self.level = validator.level
        # Gasto del Debug en este nivel (2026-10-21, paso 4 de docs/propuesta-jefe-alerta-mayor.md §6): el de las
        # reglas (con mejoras) por debug_drain_scale del nivel (1 sin el campo: los demas niveles no cambian).
        self.debug_drain = self.rules.debug_drain * float(self.level.get("debug_drain_scale", 1.0))
        self.T = self.m.T
        self.val = self.m.validation
        self.margin = self.m.time_margin()
        # Holgura de tiempo frente a banners, campanas y plataformas que parpadean (validation.hazard_margin_s;
        # 0 por defecto): cada muestra de la busqueda por tiempo tiene que ser segura con las amenazas
        # adelantadas o retrasadas hasta ese margen (2026-10-20, bot del 1-3).
        self.hazard_margin = float(self.val.get("hazard_margin_s", 0.0))
        self.errors = []
        self.warnings = []
        self.info = {}

    # --- Utilidades ---

    def error(self, message, node=None, obj=None):
        self.errors.append((message, node, obj))

    def warning(self, message, node=None, obj=None):
        self.warnings.append((message, node, obj))

    def feet(self, node):
        return ((node[0] + 0.5) * self.T, (node[1] + 1) * self.T)

    def hurt_rect(self, x, feet):
        return (x - self.m.hw, feet - self.m.hh, x + self.m.hw, feet)

    def move(self, u, e, state):
        return {"action": "move", "kind": e["kind"], "from": u, "to": e["to"], "edge": e, "state": state,
                "debug": bool(e.get("debug"))}

    # --- Pasos desde la progresion ---

    def build_steps(self, run):
        steps = []
        last_state = frozenset()
        last_pub = {}
        for stage in run["stages"]:
            state = stage["state"]
            last_state = state
            for u, e in path_to(stage["parent"], stage["end"]):
                steps.append(self.move(u, e, state))
            g = stage["gate"]
            if g is None:
                continue
            n = stage["end"]
            if g.kind in world3_model.LIKE_KINDS:
                # Mundo 3 (paso 8a): corazon, publicacion (con su enfriamiento si se repite seguida) o reset.
                steps.extend(world3_model.plan_steps(self, g, n, state, stage, last_pub))
                last_pub = {"id": g.obj_id} if g.kind == "like_source" else {}
                continue
            last_pub = {}
            if g.kind == "pickup":
                steps.append(self.pickup_step(g, n))
                continue
            relay = stage.get("relay")
            if relay is not None:
                lector = g.relay["lector"]
                steps.append({"action": "laser", "at": n, "shot": relay["shot_info"], "state": state,
                              "target": {"type": "laser_receiver", "id": lector["id"], "rect": lector["rect"][:4]},
                              "timed": "relay:" + g.obj_id})
                for u, e in relay["path"]:
                    steps.append(self.move(u, e, state) | {"timed": "relay:" + g.obj_id})
                b = relay["pulse"]
                shot = self.m.pulse_shot(g.openers, b, state)
                steps.append({"action": "pulse", "at": b, "shot": shot, "state": state,
                              "target": {"type": "relay_receiver", "id": g.relay["id"], "opens": g.label()},
                              "relay": {"gate": g.obj_id, "lector": lector["id"], "window_s": lector["window"],
                                        "time_s": relay["time"]}})
                continue
            if g.kind == "pound":
                # Golpe al suelo (Mundo 2, paso 9): desde la celda de pie la onda alcanza la tarjeta fragil; la
                # oculta solo con el Debug activo (se enciende antes y se apaga despues). Rota, Isak cae por ella.
                # Muro «Cargando mas...» (paso 9b): g.pounds golpes seguidos desde la misma celda, con el
                # enfriamiento del gesto entre ellos; se rompe con el ultimo.
                x = self.m.pound_x(g, n, state, g.hidden)
                if g.hidden:
                    steps.append({"action": "debug_on", "at": n, "state": state, "reason": "ver la grieta de %s" % g.obj_id,
                                  "target": {"type": "fragile_card", "id": g.obj_id}})
                kind = "loading_wall" if g.wall else "fragile_card"
                for k in range(g.pounds):
                    st = {"action": "ground_pound", "at": n, "shot": {"x": x, "facing": 1}, "state": state,
                          "air": False, "breaks": [g.obj_id] if k == g.pounds - 1 else [], "debug": g.hidden,
                          "target": {"type": kind, "id": g.obj_id}}
                    if g.pounds > 1:
                        st.update({"count": k + 1, "of": g.pounds, "cooldown_before": k > 0})
                    steps.append(st)
                if g.hidden:
                    steps.append({"action": "debug_off", "at": n, "state": state})
                continue
            if g.kind == "bar":
                steps.append({"action": "wait", "at": n, "seconds": g.wait_s, "state": state,
                              "reason": "barra del 99 %% %s" % g.obj_id,
                              "target": {"type": "update_bar", "id": g.obj_id}})
                continue
            if g.kind == "switch":
                # Acertijo de Calc (tanda H2): el panel oculto se descubre con el Debug (encender, un
                # momento activo cerca y apagar: queda marcado) y despues, como el interruptor de pulso,
                # `pulses` pulsos desde el suelo, cada uno con Isak de espaldas pose_s.
                kind = "debug_switch" if g.hidden else "power_switch"
                if g.hidden:
                    steps.append({"action": "debug_on", "at": n, "state": state, "reason": "descubrir %s" % g.obj_id,
                                  "target": {"type": kind, "id": g.obj_id}})
                    steps.append({"action": "wait", "at": n, "seconds": REVEAL_S, "state": state,
                                  "reason": "el Debug descubre el panel oculto %s" % g.obj_id,
                                  "target": {"type": kind, "id": g.obj_id}})
                    steps.append({"action": "debug_off", "at": n, "state": state})
                shot = self.m.pulse_shot(g.openers, n, state)
                for k in range(g.pulses):
                    steps.append({"action": "pulse", "at": n, "shot": shot, "state": state, "face_back": True,
                                  "pose_s": g.pose_s, "count": k + 1, "of": g.pulses,
                                  "target": {"type": kind, "id": g.obj_id}})
                continue
            if g.kind == "dnd":
                # Interruptor No molestar (1-3, paso 9): un pulso de espaldas da el dash. El reproductor con el
                # boton de pausa (Mundo 2, paso 9b) da asi el golpe al suelo.
                shot = self.m.pulse_shot(g.openers, n, state)
                steps.append({"action": "pulse", "at": n, "shot": shot, "state": state, "face_back": True,
                              "pose_s": g.pose_s, "count": 1, "of": 1,
                              "target": {"type": "pause_player" if getattr(g, "player", False) else (
                                  "crop_tool" if getattr(g, "crop", False) else "dnd_switch"),
                                         "id": g.obj_id, "ability": g.ability}})
                continue
            if g.kind == "lswitch":
                shot = self.m.laser_shot(g.openers[0], n, state)
                steps.append({"action": "laser", "at": n, "shot": shot, "state": state,
                              "target": {"type": "laser_switch", "id": g.obj_id, "rect": g.openers[0][:4]}})
                continue
            if g.kind == "dock":
                steps.append({"action": "wait", "at": n, "seconds": g.wait_s, "state": state,
                              "reason": "Calc entra, se carga en %s y se teletransporta" % g.obj_id,
                              "target": {"type": "charge_dock", "id": g.obj_id, "calc": g.calc_id}})
                continue
            if g.kind == "ad":
                shot = self.m.laser_shot(g.openers[0], n, state)
                steps.append({"action": "laser", "at": n, "shot": shot, "state": state,
                              "target": {"type": "ad_cover", "id": g.obj_id, "rect": g.openers[0][:4]}})
                continue
            if g.kind == "bubble" and not self.m.can_open(g, n, state, use_laser=False):
                shot = self.m.laser_shot(g.openers[0], n, state)
                for i in range(max(1, int(math.ceil(g.health)))):
                    steps.append({"action": "laser", "at": n, "shot": shot, "state": state,
                                  "target": {"type": "alert_bubble", "id": g.obj_id}, "repeat": i})
                steps[-1]["kills"] = g.obj_id
                continue
            shot = self.m.pulse_shot(g.openers, n, state)
            kind = {"bridge": "receiver", "popup": "popup_blocker", "bubble": "alert_bubble"}.get(g.kind, g.kind)
            steps.append({"action": "pulse", "at": n, "shot": shot, "state": state,
                          "target": {"type": kind, "id": g.obj_id, "opens": g.label()}})
        end = run["stages"][-1]["end"]
        # Terminal de salida: pulso desde la celda que encontro el validador (normalmente la meta).
        for item in self.v.result.get("exit_terminals", []):
            if item.get("countdown_s"):
                # Cuenta automatica (cierre del 2-1): Isak espera en la meta a que la terminal se active sola.
                steps.append({"action": "wait", "at": end, "seconds": float(item["countdown_s"]), "state": last_state,
                              "reason": "cuenta de la terminal %s" % item["id"], "final": True,
                              "target": {"type": "exit_terminal", "id": item["id"]}})
                break
            frm = item.get("pulse_from")
            if not frm:
                continue
            node = (frm[1], frm[0])
            if node != end:
                sub = self.walk_between(end, node, last_state)
                if sub is None:
                    continue
                steps.extend(self.move(u, e, last_state) for u, e in sub)
                end = node
            obj = next((o for o in self.level.get("objects", []) if o["type"] == "exit_terminal"), None)
            rect = None
            if obj is not None:
                hit = self.m.catalog.get("exit_terminal", {}).get("hit_rect_px", [0, 0, self.T, 2 * self.T])
                x0, y0 = obj["x"] * self.T + hit[0], obj["y"] * self.T + hit[1]
                rect = (x0, y0, x0 + hit[2], y0 + hit[3])
            shot = self.m.pulse_shot([rect], node, last_state) if rect else None
            steps.append({"action": "pulse", "at": node, "shot": shot, "state": last_state, "final": True,
                          "target": {"type": "exit_terminal", "id": item["id"]}})
            break
        steps.append({"action": "goal", "at": end, "state": last_state})
        self.add_touches(steps)
        return steps

    def pickup_step(self, g, n):
        refill = False
        for obj in self.level.get("objects", []):
            if obj["type"] == "ability_pickup" and str(obj.get("params", {}).get("id")) == g.obj_id:
                refill = bool(obj.get("params", {}).get("refill_energy", False))
        return {"action": "pickup", "at": n, "gate": g.gid, "ability": g.ability, "refill": refill,
                "target": {"type": "eco_encounter" if getattr(g, "encounter", False) else "ability_pickup",
                           "id": g.obj_id}}

    def walk_between(self, a, b, state):
        times, parent = self.m.time_search({a: 0.0}, state)
        if b not in times:
            return None
        return path_to(parent, b)

    def add_touches(self, steps):
        """Recogidas de paso (chip, encuentro) y cargadores que toca el camino."""
        taken = {s["gate"] for s in steps if s["action"] == "pickup"}
        out = []
        for s in steps:
            out.append(s)
            if s["action"] != "move":
                continue
            node = s["to"]
            cells = body_cells(node)
            for g in self.m.gates:
                if g.kind == "pickup" and g.gid not in taken and cells & set(g.cells):
                    taken.add(g.gid)
                    out.append(self.pickup_step(g, node))
            x, feet = self.feet(node)
            for ch in self.m.chargers:
                if rects_overlap(self.hurt_rect(x, feet), ch["rect"]):
                    out.append({"action": "charge", "at": node, "charger": ch,
                                "target": {"type": "charger", "id": ch["id"]}})
        steps[:] = out

    # --- Duracion y muestras ---

    def duration(self, s):
        a = s["action"]
        r = self.rules
        if a == "move":
            real = self.real_arc(s)
            if real is not None:
                speed = r.walk_speed
                cv = self.feet(s["to"])
                base = (abs(s["edge"]["x0"] - self.feet(s["from"])[0]) / speed + real[0]
                        + abs(real[2] - cv[0]) / speed + START_S)
            else:
                base = self.m.edge_time(s["from"], s["edge"], s.get("walk_speed"))
            return base + self.rest_lag(s) if s.get("from_rest") else base
        if a == "hop":
            return s["time"]
        if a == "laser":
            return r.laser_pose_s + s.get("extra_wait", 0.0)
        if a == "pulse" or a == "like_reset":
            if s.get("face_back"):
                # Interruptor del acertijo de Calc: de espaldas pose_s (no se puede volver a pulsar hasta que
                # Isak vuelve de perfil) y un cuadro.
                return max(r.pulse_pose_s, s.get("pose_s", 0.0)) + DT
            return r.pulse_pose_s
        if a in ("wait", "wait_phase", "wait_beat", "wait_scroll"):
            return s.get("seconds", 0.0)
        if a == "ground_pound":
            return r.pound_s + (r.pound_cooldown_s if s.get("cooldown_before") else 0.0)
        if a == "debug_on":
            return r.debug_hold_s + r.debug_fade_s
        return 0.0

    def node_of(self, s):
        return s.get("at") or s.get("to")

    def real_arc(self, s):
        """Arco real del juego de un salto marcado con arc="real" (lo marca la busqueda por tiempo con
        ctx["real_arc"]): (s en el aire, trayectoria [(x, pies)], x de aterrizaje) o None (no es un salto
        o el arco real no acaba en la fila de llegada con suelo hasta su celda: se usa el conservador).

        Bot del 1-3 (2026-10-20): el arco del grafo usa la altura conservadora (jump_height, 176,6 px) y
        bajo un techo bajo roza el techo casi en la cumbre; el Isak real (unos 184 px) choca antes y
        aterriza ~0,15 s antes (salto 46 -> 49 del 1b), asi que la linea de tiempo de las amenazas iba
        retrasada. Aterrizando antes de la celda de llegada, Isak anda por la fila hasta su centro."""
        if s["action"] != "move" or s.get("arc") != "real":
            return None
        e = s["edge"]
        if e["kind"] == "walk" or e.get("dash") or e.get("vy0", 0.0) >= 0.0:
            return None
        if "_real" in s:
            return s["_real"]
        out = None
        cu = self.feet(s["from"])
        w = self.m.world(s["state"], bool(s.get("debug")))
        info = {"want_traj": True}
        speed = self.rules.walk_speed if e["speed"] == "walk" else self.rules.run_speed
        # Desde parado donde esta (tras una espera): acelera en el aire (air_acceleration) desde 0.
        accel = self.rules.air_accel if self.standing_jump(s) and self.rules.air_accel > 0.0 else None
        to, _ = w.simulate(e["x0"], cu[1], -self.rules.jump_v0_game, speed, e["xt"], info=info, game=True,
                           accel=accel)
        if to is not None and info.get("traj") and to[1] == e["to"][1]:
            lo, hi = sorted((to[0], e["to"][0]))
            if all(w.is_node(c, to[1]) for c in range(lo, hi + 1)):
                out = (info["time"], list(info["traj"]), info.get("land_x", info["traj"][-1][0]))
        s["_real"] = out
        return out

    def rest_walk(self, dist, speed):
        """Andar `dist` px desde parado (ground_acceleration hasta `speed`): segundos y funcion t -> px."""
        a = self.rules.ground_accel
        if a <= 0.0:
            return dist / speed, lambda t: min(speed * t, dist)
        ta = speed / a
        da = 0.5 * a * ta * ta
        dur = math.sqrt(2.0 * dist / a) if dist <= da else ta + (dist - da) / speed

        def at(t):
            d = 0.5 * a * t * t if t < ta else da + speed * (t - ta)
            return min(d, dist)
        return dur, at

    def rest_lag(self, s):
        """Segundos de mas de un movimiento que empieza con Isak parado (from_rest; tras una espera o un salto
        en el sitio, en la busqueda por tiempo con el arco real): andar hasta el despegue acelerando
        (ground_acceleration) o, si despega donde esta, el salto acelerando en el aire (air_acceleration), que
        aterriza mas atras y anda mas. El bot del 1-3 iba ~0,1 s por detras del camino en cada arranque."""
        e = s["edge"]
        speed = self.rules.walk_speed
        if e["kind"] == "walk":
            sp = s.get("walk_speed") or speed
            return self.rest_walk(self.T, sp)[0] - self.T / sp
        d = abs(e["x0"] - self.feet(s["from"])[0])
        if d > EPS:
            return self.rest_walk(d, speed)[0] - d / speed
        return 0.0  # salto desde parado: el arco real ya acelera en el aire (real_arc)

    def standing_jump(self, s):
        """Salto (no dash) que despega parado donde esta (from_rest y sin andar hasta el despegue)."""
        e = s["edge"]
        return bool(s.get("from_rest")) and abs(e["x0"] - self.feet(s["from"])[0]) <= EPS

    def rest_jump_fails(self, s):
        """Con el arco real, un salto desde parado que no llega a la fila de llegada (p. ej. pegado al lado de
        una plataforma: la pared frena a Isak): la busqueda por tiempo no lo usa."""
        e = s["edge"]
        return (s.get("arc") == "real" and e["kind"] != "walk" and not e.get("dash") and e.get("vy0", 0.0) < 0.0
                and self.standing_jump(s) and self.real_arc(s) is None)

    def air_time(self, s):
        """Segundos en el aire de un movimiento (el arco real si lo lleva)."""
        real = self.real_arc(s)
        return real[0] if real is not None else s["edge"].get("time", 0.0)

    def samples(self, s):
        """Posiciones de los pies de Isak (x, pies, en_el_aire) cuadro a cuadro durante el paso."""
        cached = s.get("_samples")
        if cached is not None and cached[0] == self.duration(s):
            return cached[1]
        out = self._samples(s)
        s["_samples"] = (self.duration(s), out)
        return out

    def _samples(self, s):
        T = self.T
        if s["action"] == "move":
            e = s["edge"]
            u, v = s["from"], e["to"]
            cu, cv = self.feet(u), self.feet(v)
            speed = self.rules.walk_speed
            if e["kind"] == "walk":
                wspeed = s.get("walk_speed") or e.get("walk_px_s") or speed
                if s.get("from_rest"):
                    return self.rest_walk_samples(cu, cv[0], wspeed)
                n = max(1, int(round(T / wspeed / DT)))
                return [(cu[0] + (cv[0] - cu[0]) * (i + 1) / n, cu[1], False) for i in range(n)]
            if e["kind"] in ("pinch", "unpinch"):
                # Mundo 3 (paso 8a): comprimirse / recuperar el tamano en el sitio (squash_s).
                return [(cu[0], cu[1], False)] * max(1, int(round(self.duration(s) / DT)))
            if e.get("dash"):
                return self._dash_samples(s, e, cu, cv)
            out = []
            x0 = e["x0"]
            if s.get("from_rest") and abs(x0 - cu[0]) > EPS:
                out += self.rest_walk_samples(cu, x0, speed)
            else:
                n = int(round(abs(x0 - cu[0]) / speed / DT))
                out += [(cu[0] + (x0 - cu[0]) * (i + 1) / max(n, 1), cu[1], False) for i in range(n)]
            out += [(x0, cu[1], False)] * int(round(0.06 / DT))
            real = self.real_arc(s)
            if real is not None:
                out += [(x, y, True) for x, y in real[1]]
            else:
                info = {"want_traj": True}
                if e.get("pinched"):
                    w = self.m.w3.world_for(e["to"], s["state"], bool(s.get("debug")))
                    w.simulate(x0, cu[1], e.get("vy0", 0.0), e["walk_px_s"], e["xt"], head_lag=e["kind"] != "fall",
                               info=info)
                else:
                    w = self.m.world(s["state"], bool(s.get("debug")))
                    w.simulate(x0, cu[1], e.get("vy0", 0.0), speed if e["speed"] == "walk" else self.rules.run_speed,
                               e["xt"], head_lag=e["kind"] != "fall", info=info)
                out += [(x, y, True) for x, y in (info.get("traj") or [])]
            land = out[-1][0] if out else cv[0]
            n = int(round(abs(land - cv[0]) / speed / DT))
            out += [(land + (cv[0] - land) * (i + 1) / max(n, 1), cv[1], False) for i in range(n)]
            return out
        if s["action"] == "hop":
            return list(s["traj"])
        node = self.node_of(s)
        x, feet = (s["shot"]["x"], (node[1] + 1) * T) if s.get("shot") else self.feet(node)
        return [(x, feet, False)] * int(round(self.duration(s) / DT))

    def rest_walk_samples(self, cu, x_to, speed):
        """Muestras de andar desde parado de cu hasta x_to (rest_walk)."""
        dist = abs(x_to - cu[0])
        dur, at = self.rest_walk(dist, speed)
        n = max(1, int(round(dur / DT)))
        sgn = 1.0 if x_to >= cu[0] else -1.0
        return [(cu[0] + sgn * at(dur * (i + 1) / n), cu[1], False) for i in range(n)]

    def _dash_samples(self, s, e, cu, cv):
        """Muestras de un movimiento con dash (paso 9): andar hasta donde sale, arranque, el arco del salto
        hasta el dash (si es aereo), el dash (invulnerable dash_invulnerable_s desde su primer cuadro:
        s["_inv"]), la caida y andar hasta el centro de la celda de llegada."""
        speed = self.rules.walk_speed
        dash = e["dash"]
        out = []
        x0 = e["x0"]
        if s.get("from_rest") and abs(x0 - cu[0]) > EPS:
            out += self.rest_walk_samples(cu, x0, speed)
        else:
            n = int(round(abs(x0 - cu[0]) / speed / DT))
            out += [(cu[0] + (x0 - cu[0]) * (i + 1) / max(n, 1), cu[1], False) for i in range(n)]
        out += [(x0, cu[1], False)] * int(round(0.06 / DT))
        out += [(x, y, True) for x, y in dash["pre"]]
        k_inv = len(out)
        out += [(x, dash["y"], bool(dash["air"])) for x in dash["xs"]]
        out += [(x, y, True) for x, y in dash["fall"]]
        land = out[-1][0]
        n = int(round(abs(land - cv[0]) / speed / DT))
        out += [(land + (cv[0] - land) * (i + 1) / max(n, 1), cv[1], False) for i in range(n)]
        s["_inv"] = (k_inv, k_inv + int(round(self.rules.dash_invulnerable_s / DT)))
        s["_dash_frames"] = (k_inv, k_inv + len(dash["xs"]))
        return out

    def invulnerable_range(self, s):
        """Cuadros (inicio, fin) de las muestras de un paso con Isak invulnerable por el dash."""
        if s["action"] != "move" or not s["edge"].get("dash"):
            return (0, 0)
        self.samples(s)
        return s.get("_inv", (0, 0))

    def dash_frames(self, s):
        """Cuadros (inicio, fin) del tramo del dash en las muestras de un paso (o (0, 0))."""
        if s["action"] != "move" or not s["edge"].get("dash"):
            return (0, 0)
        self.samples(s)
        return s.get("_dash_frames", (0, 0))

    def timeline(self, steps):
        """Tiempo real y del mundo al empezar cada paso (el Debug activo va a world_time_scale)."""
        t = tw = 0.0
        debug = False
        for s in steps:
            s["t"] = t
            s["tw"] = tw
            d = self.duration(s)
            if s["action"] == "debug_on":
                # La carga no gasta ni ralentiza; el mundo se ralentiza al terminarla.
                t += d
                tw += d
                debug = True
                continue
            if s["action"] == "debug_off":
                debug = False
            s["debug_active"] = debug
            t += d
            tw += d * (self.rules.debug_world_scale if debug else 1.0)
        return t, tw

    # --- Plan completo ---

    def run(self):
        main = self.v.main
        if not main["ok"]:
            return None
        steps = self.build_steps(main)
        self.check_relays(steps)
        steps = self.check_reminders(steps)
        steps = self.check_overlays(steps)
        steps = self.add_debug_segments(steps)
        steps = self.check_badges(steps)
        steps = self.check_banners(steps)
        steps = self.check_clones(steps)
        steps = self.check_scroll(steps)
        steps = self.check_energy(steps)
        self.check_loop_energy(steps)
        self.info["bars"] = []
        for st in steps:
            if st.get("target", {}).get("type") == "update_bar":
                g = next(g for g in self.m.gates if g.kind == "bar" and g.obj_id == st["target"]["id"])
                self.info["bars"].append({"id": g.obj_id, "wait_s": round(g.wait_s, 2), "at": [st["at"][1], st["at"][0]],
                                          "wave_enemies": len(g.waves)})
        total, total_world = self.timeline(steps)
        self.info["calc_puzzle"] = self.puzzle_info(steps)
        self.info["duration_s"] = round(total, 2)
        self.info["duration_world_s"] = round(total_world, 2)
        self.steps = steps
        return steps

    # --- Scroll forzado (Mundo 2, paso 9 de docs/propuesta-mundo-2.md §7.1) ---

    def check_scroll(self, steps):
        """Con camera.vertical "autoscroll": el borde de abajo de la vista sube solo (tools/scroll_model.py,
        tiempo del mundo). Avanza el scroll con los pies de Isak cuadro a cuadro por todo el camino y comprueba
        que, mientras el scroll se mueve, Isak nunca queda a menos de validation.scroll_margin_tiles (3 en
        dificultad 2-3, 2 en dificultad 4) del borde que dana (parado, basta con no tocarlo). Antes de un
        movimiento que el techo de carga impediria (Isak no puede adelantarse a la vista: el techo corta el arco
        y hace falta que los pies aun suban por encima del sitio de llegada) inserta una espera wait_scroll
        hasta que el scroll suba lo bastante; si el movimiento va con el Debug
        activo, la espera se hace antes de encenderlo (asi no gasta energia). Las esperas cuentan para el
        margen. Secciones en bucle: el camino tiene que llegar a la salida antes de que el borde de arriba de
        la vista llegue a la banda (si no, se repetiria)."""
        if self.level.get("camera", {}).get("vertical") != "autoscroll":
            return steps
        self.timeline(steps)
        prewaits = {}
        result = None
        for _attempt in range(40):
            result = self._scroll_pass(steps, prewaits)
            if result[0] == "ok":
                break
            _, index, seconds = result
            prewaits[index] = prewaits.get(index, 0.0) + seconds
        if result is None or result[0] != "ok":
            result = self._scroll_pass(steps, prewaits, allow_debug_waits=True)
        _, out, info, errors = result
        for message, node in errors:
            self.error(message, node)
        self.info["scroll"] = info
        return out

    def _group_entry(self, steps, idx, any_action=False):
        """Indice del movimiento que entra en el grupo de recordatorios (o tarjeta fragil) sobre el que
        empieza el paso `idx`; None si no empieza sobre uno. Si ese movimiento sale a su vez de otro grupo
        (de una fragil a otra), el que entra en el primero de la cadena. Con any_action (paso 14, 2-3) vale
        tambien para un paso que no es un movimiento (una espera de fase en `at`)."""
        if steps[idx]["action"] == "move":
            node = steps[idx]["from"]
        elif any_action:
            node = steps[idx].get("at") or steps[idx].get("from")
            if node is None:
                return None
        else:
            return None
        group = self.group_of_node(node)
        entry = None
        while group is not None:
            found = None
            for k in range(idx - 1, -1, -1):
                st = steps[k]
                if st["action"] == "move" and self.group_of_node(st["to"]) == group \
                        and self.group_of_node(st["from"]) != group:
                    found = k
                    break
            if found is None:
                return entry
            entry, idx = found, found
            group = self.group_of_node(steps[found]["from"])
        return entry

    def _on_blink(self, step):
        """Verdadero si el paso empieza, acaba o espera de pie sobre una plataforma que parpadea (Historia)."""
        for key in ("from", "to", "at"):
            node = step.get(key)
            if not node:
                continue
            x, feet = (node[0] + 0.5) * self.T, (node[1] + 1) * self.T
            for bl in self.m.blink_items:
                rect = bl["rect"]
                if rect[0] - EPS <= x <= rect[2] + EPS and abs(rect[1] - feet) < 1.0:
                    return True
        return False

    def _timed_entry(self, steps, idx):
        """Primer paso (o su wait_phase) del tramo con tiempo de la busqueda por amenazas que contiene el paso
        `idx`, si en ese tramo Isak pisa una plataforma que parpadea (una Historia, 2-2): una espera del scroll
        en medio lo desacompasaria (de pie sobre la Historia, se apaga), asi que va antes del tramo (paso 13 de
        docs/propuesta-mundo-2.md). None si no."""
        if steps[idx].get("timed") != "hazard":
            return None
        k = idx
        while k > 0 and steps[k - 1].get("timed") == "hazard":
            k -= 1
        j = idx
        while j + 1 < len(steps) and steps[j + 1].get("timed") == "hazard":
            j += 1
        if not any(self._on_blink(st) for st in steps[k:j + 1]):
            return None
        if k > 0 and steps[k - 1]["action"] == "wait_phase":
            k -= 1
        return k if k < idx else None

    def _scroll_pass(self, steps, prewaits, allow_debug_waits=False):
        """Una pasada del scroll por el camino con las esperas previas `prewaits` ({indice del debug_on: s}).
        ("ok", pasos, info, errores) o ("prewait", indice del debug_on, s) si un movimiento con el Debug
        activo necesitaria esperar al scroll."""
        import scroll_model
        T = self.T
        sim = scroll_model.ScrollSim(self.level, self.rules.root, T)
        difficulty = self.level.get("difficulty", 3)
        default_req = 3.0 if not isinstance(difficulty, (int, float)) or difficulty <= 3 else 2.0
        req = float(self.val.get("scroll_margin_tiles", default_req))
        hh = self.m.hh
        loops = [dict(lp, solved=False, reported=False) for lp in self.level.get("_loops", [])]
        info = {"required_tiles": req, "margin_min_tiles": None, "at": None, "waits": 0, "wait_s": 0.0,
                "start_s": None, "loops": [lp["id"] for lp in loops]}
        errors = []
        worst = [INF, None, None]
        touched = [False]

        def watch(x, feet, idx, node):
            margin = sim.margin(feet, feet - hh)
            if margin < 0.0 and not touched[0]:
                touched[0] = True
                errors.append(("el borde del scroll alcanza a Isak en el paso %d (el camino va mas despacio que el "
                               "feed)" % idx, node))
            if not sim.is_parked() and margin < worst[0]:
                worst[0], worst[1], worst[2] = margin, node, idx
            for lp in loops:
                if lp["solved"] or lp["reported"]:
                    continue
                ex = lp["exit"]
                if ex[0] * T <= x < (ex[0] + ex[2]) * T and ex[1] * T <= feet - 1.0 < (ex[1] + ex[3]) * T:
                    lp["solved"] = True
                elif sim.top <= lp["band"][0] * T + EPS and feet >= lp["band"][0] * T:
                    lp["reported"] = True
                    errors.append(("seccion en bucle %s: el borde de arriba de la vista llega a la banda antes de "
                                   "que el camino alcance la salida (se repetiria)" % lp["id"], node))

        def wait_at(node, seconds, scale, idx):
            x, feet = self.feet(node)
            for _ in range(int(round(seconds / DT))):
                sim.step(feet, DT * scale, x)
                watch(x, feet, idx, node)

        out = []
        last_debug_on = None
        timed_entries = self.__dict__.setdefault("_timed_entries", set())
        for idx, s in enumerate(steps):
            scale = self.rules.debug_world_scale if s.get("debug_active") else 1.0
            node = self.node_of(s) or s.get("from")
            if s["action"] == "debug_on":
                last_debug_on = idx
                if prewaits.get(idx):
                    wait_at(node, prewaits[idx], 1.0, idx)
                    out.append({"action": "wait_scroll", "at": node, "seconds": prewaits[idx], "state": s["state"],
                                "reason": "el scroll sube (antes del Debug)"})
                    info["waits"] += 1
                    info["wait_s"] += prewaits[idx]
            elif prewaits.get(idx):
                at = s.get("from") or node
                wait_at(at, prewaits[idx], scale, idx)
                out.append({"action": "wait_scroll", "at": at, "seconds": prewaits[idx], "state": s["state"],
                            "reason": "el scroll sube (antes del tramo con tiempo)" if idx in timed_entries
                            else "el scroll sube (antes de la tarjeta fragil)"})
                info["waits"] += 1
                info["wait_s"] += prewaits[idx]
            samples = self.samples(s) if self.duration(s) > 0.0 else []
            if s["action"] == "move" and samples:
                # El techo de carga corta el arco (la cabeza no sube mas), pero el salto vale si con el arco
                # cortado los pies aun suben por encima del sitio donde aterriza (HEAD_MARGIN_PX de holgura).
                head_min = min(self.feet(s["from"])[1], self.feet(s["to"])[1]) - hh - SCROLL_HEAD_MARGIN_PX
                if head_min < sim.ceiling() - EPS:
                    fx, ffeet = self.feet(s["from"])
                    saved = sim.copy_state()
                    waited = 0.0
                    while head_min < sim.ceiling() - EPS and waited < SCROLL_MAX_WAIT_S:
                        sim.step(ffeet, DT * scale, fx)
                        waited += DT
                    if s.get("debug_active") and last_debug_on is not None and not allow_debug_waits:
                        return ("prewait", last_debug_on, max(waited * scale, DT))
                    # De pie sobre un recordatorio o una tarjeta fragil la cuenta corre: la espera va antes del
                    # movimiento que entra en su grupo (paso 12 de docs/propuesta-mundo-2.md, 2-1).
                    entry = self._group_entry(steps, idx)
                    if entry is not None:
                        # Si se entra en la fragil desde un tramo con tiempo con una Historia (de la Historia a la
                        # fragil, 2-3), la espera va antes de ese tramo (de pie sobre la Historia se apagaria).
                        timed = self._timed_entry(steps, entry)
                        if timed is not None:
                            entry = timed
                            self._timed_entries.add(entry)
                    if entry is None:
                        entry = self._timed_entry(steps, idx)
                        # Si el tramo con tiempo empieza de pie sobre una tarjeta fragil, la espera va antes de
                        # pisarla (paso 14 de docs/propuesta-mundo-2.md, 2-3).
                        fragile = None if entry is None else self._group_entry(steps, entry, any_action=True)
                        if fragile is not None:
                            entry = fragile
                        elif entry is not None:
                            self._timed_entries.add(entry)
                    if entry is not None and not allow_debug_waits:
                        return ("prewait", entry, max(waited * scale, DT))
                    sim.restore(saved)
                    wait_at(s["from"], waited, scale, idx)
                    if head_min < sim.ceiling() - EPS:
                        errors.append(("el camino sube por encima del techo de carga y el scroll no avanza (paso %d)"
                                       % idx, s["from"]))
                    else:
                        out.append({"action": "wait_scroll", "at": s["from"], "seconds": waited, "state": s["state"],
                                    "reason": "el scroll sube (techo de carga)"})
                        info["waits"] += 1
                        info["wait_s"] += waited
            if samples:
                dt = self.duration(s) / len(samples)
                for x, feet, _air in samples:
                    sim.step(feet, dt * scale, x)
                    watch(x, feet, idx, node)
            if sim.started_at is not None and info["start_s"] is None:
                info["start_s"] = round(sim.started_at, 2)
            out.append(s)
        if worst[1] is not None:
            margin_tiles = worst[0] / T
            info["margin_min_tiles"] = round(margin_tiles, 2)
            info["at"] = [worst[1][1], worst[1][0]]
            if 0.0 <= margin_tiles < req - EPS:
                errors.append(("el camino queda a %.1f tiles del borde del scroll (minimo %g; paso %d)"
                               % (margin_tiles, req, worst[2]), worst[1]))
        info["wait_s"] = round(info["wait_s"], 2)
        return ("ok", out, info, errors)

    # --- Acertijo de Calc (tanda H2 del paso 14 del 1-2) ---

    def puzzle_info(self, steps):
        """Resumen del acertijo de la azotea en el plan: pulsos de espaldas, laser al interruptor, Debug
        (pared y panel), espera de Calc y energia en cada pieza. Vacio si el nivel no lo tiene."""
        kinds = ("power_switch", "debug_switch", "laser_switch", "charge_dock", "glitch_wall")
        items = []
        for s in steps:
            tgt = s.get("target", {})
            if tgt.get("type") not in kinds:
                continue
            node = self.node_of(s)
            entry = {"action": s["action"], "type": tgt["type"], "id": tgt["id"],
                     "at": None if node is None else [node[1], node[0]], "t": round(s.get("t", 0.0), 2)}
            if s["action"] == "pulse":
                entry["count"] = s.get("count")
                entry["of"] = s.get("of")
            if s["action"] == "wait":
                entry["seconds"] = round(s["seconds"], 2)
            if "energy_after" in s:
                entry["energy_after"] = s["energy_after"]
            items.append(entry)
        if not items:
            return {}
        lasers = [i for i in items if i["action"] == "laser"]
        pulses = [i for i in items if i["action"] == "pulse"]
        waits = [i for i in items if i["action"] == "wait" and i["type"] == "charge_dock"]
        reveals = [i for i in items if i["action"] == "debug_on"]
        dissolves = [i for i in items if i["type"] == "glitch_wall"]
        first = min(i["t"] for i in items)
        last = max(i["t"] + i.get("seconds", 0.0) for i in items)
        return {"steps": items, "pulses": len(pulses), "lasers": len(lasers),
                "laser_from": lasers[0]["at"] if lasers else None,
                "debug_uses": len(reveals) + len(dissolves),
                "calc_wait_s": waits[0]["seconds"] if waits else None,
                "duration_s": round(last - first, 2)}

    # --- Acertijo lector -> receptor enlazado ---

    def check_relays(self, steps):
        items = []
        for s in steps:
            relay = s.get("relay")
            if not relay:
                continue
            spare = relay["window_s"] - relay["time_s"]
            item = {"bridge": relay["gate"], "lector": relay["lector"], "window_s": relay["window_s"],
                    "time_s": round(relay["time_s"], 2), "spare_s": round(spare, 2), "margin_s": self.margin,
                    "shot_from": None}
            items.append(item)
            if spare < self.margin - EPS:
                self.error("acertijo %s -> %s: del disparo al pulso hacen falta %.1f s de los %.1f s de la ventana; "
                           "sobran %.1f s y el margen minimo es %.1f s" % (
                               relay["lector"], relay["gate"], relay["time_s"], relay["window_s"], spare,
                               self.margin), s["at"], relay["gate"])
        for s in steps:
            if s["action"] == "laser" and s.get("timed", "").startswith("relay:"):
                for item in items:
                    if "relay:" + item["bridge"] == s["timed"] and item["shot_from"] is None:
                        item["shot_from"] = [s["at"][1], s["at"][0]]
        self.info["relays"] = items

    # --- Recordatorios y Posponer ---

    def group_of_node(self, node):
        return self.m.reminder_group_of.get((node[0], node[1] + 1))

    def check_reminders(self, steps):
        groups = self.m.reminder_groups
        required = [str(g) for g in self.val.get("snooze_required", [])]
        items = []
        if not groups:
            for g in required:
                self.error("validation.snooze_required: el grupo de recordatorios %s no existe" % g)
            self.info["reminders"] = items
            return steps
        crossed = set()
        i = 0
        while i < len(steps):
            s = steps[i]
            if s["action"] != "move":
                i += 1
                continue
            group = self.group_of_node(s["to"])
            if group is None:
                i += 1
                continue
            # Cruce: desde el aterrizaje en el grupo hasta el primer movimiento que sale de el.
            j = i + 1
            while j < len(steps) and not (steps[j]["action"] == "move" and self.group_of_node(steps[j]["to"]) != group):
                j += 1
            if j >= len(steps):
                break
            entry, exit_node = s["to"], steps[j]["to"]
            state = steps[j]["state"]
            info = groups[group]
            crossed.add(group)
            original = self.crossing_left(steps[i + 1:j + 1], info["timer"])
            no_snooze = self.cross_search(group, entry, exit_node, state, shots=False, margin=0.0)
            with_snooze = self.cross_search(group, entry, exit_node, state, shots=True, margin=self.margin)
            no_snooze_margin = self.cross_search(group, entry, exit_node, state, shots=False, margin=self.margin)
            item = {"group": group, "timer_s": info["timer"], "warn_s": info["warn"], "respawn_s": info["respawn"],
                    "entry": [entry[1], entry[0]], "exit": [exit_node[1], exit_node[0]],
                    "crossing_s": round(info["timer"] - original, 2) if original is not None else None,
                    "without_snooze": None if no_snooze is None else round(no_snooze["slack"], 2),
                    "with_snooze": None if with_snooze is None else round(with_snooze["slack"], 2),
                    "snooze_shots": 0, "required": group in required}
            items.append(item)
            choice = None
            label = "grupo de recordatorios %s" % group
            if group in required:
                if no_snooze is not None:
                    self.error("%s: se cruza SIN Posponer (sobran %.1f s de %.1f s) y el diseno lo exige "
                               "(validation.snooze_required)" % (label, no_snooze["slack"], info["timer"]), entry, group)
                elif with_snooze is None:
                    self.error("%s: no se cruza ni con el Posponer con %.1f s de margen" % (label, self.margin),
                               entry, group)
                choice = with_snooze or no_snooze
            else:
                if original is not None and original >= self.margin - EPS:
                    choice = None  # el cruce del camino ya cabe en la cuenta
                elif no_snooze_margin is not None:
                    choice = no_snooze_margin
                elif with_snooze is not None:
                    choice = with_snooze
                else:
                    t_need = None if original is None else info["timer"] - original
                    self.error("%s: cae antes de cruzarlo (cuenta de %.1f s; el recorrido sobre sus recordatorios "
                               "dura %s y no queda el margen de %.1f s%s)" % (
                                   label, info["timer"], "%.1f s" % t_need if t_need is not None else "demasiado",
                                   self.margin, ", ni con el Posponer" if self.snoozes_for(group) else ""),
                               entry, group)
            if choice is not None:
                new = choice["steps"]
                for st in new:
                    st.setdefault("state", state)
                item["snooze_shots"] = sum(1 for st in new if st["action"] == "laser")
                item["planned_slack_s"] = round(choice["slack"], 2)
                item["min_left_s"] = round(choice["min_left"], 2)
                if item["snooze_shots"] and choice["min_left"] < info["warn"] - EPS:
                    self.warning("%s: la cuenta baja a %.2f s (dentro de su aviso de %.1f s) antes de que llegue el "
                                 "Posponer; poco margen para el disparo" % (label, choice["min_left"], info["warn"]),
                                 entry, group)
                steps = steps[:i + 1] + new + steps[j + 1:]
                j = i + len(new)
            else:
                item["planned_slack_s"] = None if original is None else round(original, 2)
            # El movimiento que sale del grupo puede aterrizar en otro (2-1: dash de una fragil a otra): ese
            # cruce tambien se comprueba (antes se saltaba).
            i = j if self.group_of_node(steps[j]["to"]) is not None else j + 1
        for g in required:
            if g not in groups:
                self.error("validation.snooze_required: el grupo de recordatorios %s no existe" % g)
            elif g not in crossed:
                self.error("grupo de recordatorios %s (validation.snooze_required): el camino no lo cruza, se llega a "
                           "la meta sin el" % g, None, g)
        self.info["reminders"] = items
        return steps

    def crossing_left(self, segment, timer):
        """Cuenta que queda al salir del grupo por el camino original (None si cae antes)."""
        left = timer
        for s in segment[:-1]:
            left -= self.duration(s)
            if left < 0.0:
                return None
        last = segment[-1]
        left -= self.departure(last["from"], last["edge"])
        return left

    def departure(self, node, e):
        speed = self.rules.walk_speed
        if e["kind"] == "walk":
            return 0.5 * self.T / speed
        return abs(e["x0"] - (node[0] + 0.5) * self.T) / speed + 0.06

    def snoozes_for(self, group):
        return [sn for sn in self.m.snoozes if group in sn["targets"]]

    def cross_search(self, group, entry, exit_node, state, shots, margin):
        """Cruce de un grupo con su cuenta: sin disparos o con los menos disparos al Posponer que
        bastan (1, 2... hasta MAX_SNOOZE_SHOTS). None si no se cruza."""
        if not shots:
            return self._cross_search(group, entry, exit_node, state, 0, margin)
        for k in range(0, MAX_SNOOZE_SHOTS + 1):
            found = self._cross_search(group, entry, exit_node, state, k, margin)
            if found is not None:
                return found
        return None

    def _cross_search(self, group, entry, exit_node, state, max_shots, margin):
        """Busqueda del cruce de un grupo con su cuenta (maximo tiempo restante en cada celda):
        movimientos sobre sus recordatorios y hasta `max_shots` disparos al Posponer."""
        shots = max_shots > 0
        info = self.m.reminder_groups[group]
        r = self.rules
        snoozes = self.snoozes_for(group) if shots else []
        # Margen al salir del grupo: `margin`. De pie sobre un recordatorio (o al llegar el disparo al
        # Posponer) basta con que siga ahi (REMINDER_STAND_S); el minimo se informa (min_left_s).
        stand = min(margin, REMINDER_STAND_S)
        start = (entry, 0)
        best = {start: info["timer"]}
        parent = {start: None}
        heap = [(-info["timer"], entry, 0, False)]
        found = None
        while heap:
            neg, node, k, last_shot = heapq.heappop(heap)
            left = -neg
            if left < best.get((node, k), -INF) - EPS:
                continue
            for e in self.m.edges(node, state, "auto"):
                if max(e["h"], e["v"]) > r.limit + EPS:
                    continue
                to = e["to"]
                if to == exit_node:
                    slack = left - self.departure(node, e)
                    if slack >= margin - EPS and (found is None or slack > found[0]):
                        found = (slack, (node, k), e)
                    continue
                if self.group_of_node(to) != group:
                    continue
                nl = left - self.m.edge_time(node, e)
                if nl < stand - EPS:
                    continue
                key = (to, k)
                if nl > best.get(key, -INF) + EPS:
                    best[key] = nl
                    parent[key] = ((node, k), {"action": "move", "e": e})
                    heapq.heappush(heap, (-nl, to, k, False))
            if k < max_shots:
                for sn in snoozes:
                    shot = self.m.laser_shot(sn["rect"], node, state)
                    if shot is None:
                        continue
                    wait = max(0.0, max(sn["cooldown"], r.laser_cooldown_s) - r.laser_pose_s) if last_shot else 0.0
                    hit = wait + 0.05 + shot["dist"] / r.laser_speed
                    at_hit = left - hit
                    if at_hit <= stand - EPS:
                        continue
                    extended = max(at_hit, min(at_hit + sn["extend"], sn["cap"]))
                    # Isak sigue quieto hasta el impacto (si llega despues de la pose).
                    nl = extended - max(0.0, r.laser_pose_s + wait - hit)
                    if nl < stand - EPS:
                        continue
                    key = (node, k + 1)
                    if nl > best.get(key, -INF) + EPS:
                        best[key] = nl
                        parent[key] = ((node, k), {"action": "laser", "snooze": sn, "shot": shot, "wait": wait,
                                                   "after": max(0.0, hit - wait - r.laser_pose_s),
                                                   "at_hit": at_hit, "timer_hit": hit})
                        heapq.heappush(heap, (-nl, node, k + 1, True))
        if found is None:
            return None
        slack, key, last_edge = found
        seq = [{"action": "move", "e": last_edge, "from": key[0]}]
        while parent.get(key) is not None:
            prev, act = parent[key]
            act = dict(act)
            act["from"] = prev[0]
            seq.append(act)
            key = prev
        seq.reverse()
        # Cuenta minima a lo largo del cruce elegido (al aterrizar en cada recordatorio y al llegar
        # cada disparo al Posponer).
        lows = []
        left = info["timer"]
        for act in seq[:-1]:
            if act["action"] == "move":
                left -= self.m.edge_time(act["from"], act["e"])
                lows.append(left)
            else:
                lows.append(act["at_hit"])
                sn = act["snooze"]
                ext = max(act["at_hit"], min(act["at_hit"] + sn["extend"], sn["cap"]))
                left = ext - max(0.0, r.laser_pose_s + act["wait"] - act["timer_hit"])
        out = []
        for act in seq:
            if act["action"] == "move":
                out.append(self.move(act["from"], act["e"], state))
            else:
                sn = act["snooze"]
                out.append({"action": "laser", "at": act["from"], "shot": act["shot"], "state": state,
                            "extra_wait": act["wait"] + act["after"], "wait_before_s": act["wait"],
                            "timed": "reminder:" + group,
                            "target": {"type": "snooze_button", "id": sn["id"], "rect": sn["rect"][:4],
                                       "group": group}})
        return {"slack": slack, "steps": out, "min_left": min(lows + [slack])}

    # --- Pop-ups translucidos ---

    def check_overlays(self, steps):
        items = []
        for ov in self.m.overlays:
            first = None
            for i, s in enumerate(steps):
                if s["action"] == "move" and body_cells(s["to"]) & ov["cells"]:
                    first = i
                    break
            item = {"id": ov["id"], "covers_path": first is not None, "closed_from": None, "debug_view": False}
            items.append(item)
            if first is None:
                continue
            done = False
            for i in range(first - 1, -1, -1):
                s = steps[i]
                node = s.get("to") if s["action"] == "move" else s.get("at")
                if node is None or s["action"] == "goal":
                    continue
                state = s.get("state", frozenset())
                if ov["cover"] and ov["cover"] not in state:
                    continue
                if not self.m.has_pulse(state):
                    continue
                shot = self.m.pulse_shot([ov["button"]], node, state)
                if shot is not None:
                    steps = steps[:i + 1] + [{"action": "pulse", "at": node, "shot": shot, "state": state,
                                              "target": {"type": "overlay_popup", "id": ov["id"]}}] + steps[i + 1:]
                    item["closed_from"] = [node[1], node[0]]
                    done = True
                    break
            if done:
                continue
            state = steps[first].get("state", frozenset())
            if self.m.has_debug(state):
                item["debug_view"] = True
                for s in steps[first:]:
                    if s["action"] == "move" and body_cells(s["to"]) & ov["cells"]:
                        s["see_with_debug"] = ov["id"]
            else:
                self.warning("pop-up translucido %s: tapa el camino y no se cierra con el pulso desde el camino ni se ve "
                             "con el Debug: se cruza a ciegas" % ov["id"], ov["cell"], ov["id"])
        self.info["overlays"] = items
        return steps

    # --- Debug ---

    def add_debug_segments(self, steps):
        """Enciende el Debug antes de los tramos que lo necesitan (plataformas 'h', pared con glitch o
        un pop-up visto a traves) y lo apaga despues."""
        need = [i for i, s in enumerate(steps) if s["action"] == "move" and (s.get("debug") or s.get("see_with_debug"))]
        self.info["debug"] = {"segments": [], "required": False}
        if not need:
            return steps
        segments = []
        start = prev = need[0]
        for i in need[1:]:
            gap = sum(self.duration(steps[k]) for k in range(prev + 1, i))
            valid = all(self.valid_in_debug(steps[k]) for k in range(prev + 1, i))
            if gap <= DEBUG_GAP_S and valid:
                prev = i
                continue
            segments.append((start, prev))
            start = prev = i
        segments.append((start, prev))
        out = []
        cursor = 0
        for a, b in segments:
            out.extend(steps[cursor:a])
            at = steps[a]["from"]
            out.append({"action": "debug_on", "at": at, "state": steps[a]["state"]})
            wall = self.glitch_crossed(steps[a:b + 1])
            if wall is not None and self.m.glitch_dissolve_s > 0.0:
                # Tanda H2: la pared con glitch se disuelve (tiempo del mundo, a world_time_scale con el
                # Debug) antes de poder cruzarla.
                out.append({"action": "wait", "at": at, "state": steps[a]["state"],
                            "seconds": self.m.glitch_dissolve_s / max(self.rules.debug_world_scale, 0.001),
                            "reason": "la pared con glitch %s se disuelve" % wall,
                            "target": {"type": "glitch_wall", "id": wall}})
            out.extend(steps[a:b + 1])
            out.append({"action": "debug_off", "at": steps[b]["to"], "state": steps[b]["state"]})
            cursor = b + 1
            seconds = sum(self.duration(steps[k]) for k in range(a, b + 1))
            if wall is not None and self.m.glitch_dissolve_s > 0.0:
                seconds += self.m.glitch_dissolve_s / max(self.rules.debug_world_scale, 0.001)
            self.info["debug"]["segments"].append({"from": [at[1], at[0]], "to": [steps[b]["to"][1], steps[b]["to"][0]],
                                                   "active_s": round(seconds, 2),
                                                   "energy": round(seconds * self.debug_drain, 1)})
        out.extend(steps[cursor:])
        self.info["debug"]["required"] = any(steps[i].get("debug") for i in need)
        return out

    def glitch_crossed(self, steps):
        """Id de la primera pared con glitch (aun solida en ese estado) que cruzan los movimientos."""
        for s in steps:
            if s["action"] != "move":
                continue
            cells = body_cells(s["to"])
            for wall in self.m.glitch_walls:
                door = "switch:" + wall["door_when"] if wall["door_when"] else None
                if door and door in s["state"]:
                    continue
                if cells & set(wall["cells"]):
                    return wall["id"]
        return None

    def valid_in_debug(self, s):
        if s["action"] in ("debug_on", "debug_off"):
            return False  # el Debug que descubre un panel oculto va aparte
        if s["action"] != "move":
            return True
        if s["edge"].get("dash"):
            return False  # el dash no se combina con el Debug (paso 9 de docs/propuesta-1-3.md)
        return any(e["to"] == s["to"] for e in self.m.edges(s["from"], s["state"], True))

    # --- Puntos rojos ---

    def badge_data(self):
        out = []
        for enemy in self.level.get("enemies", []):
            if enemy["type"] != "notification_badge":
                continue
            data = self.v.enemy_data("notification_badge")
            p = dict(data)
            p.update(enemy.get("params", {}))
            spawn = ((enemy["x"] + 0.5) * self.T, (enemy["y"] + 1) * self.T + float(p["center_y"]))
            out.append({"id": enemy["id"], "spawn": spawn, "p": p, "cell": (enemy["x"], enemy["y"])})
        return out

    def check_badges(self, steps):
        badges = self.badge_data()
        self.info["badges"] = []
        if not badges:
            return steps
        for _ in range(MAX_STUNS + 1):
            result = self.simulate_badges(steps, badges)
            if result["stun"] is None:
                break
            i, k, bid, shot, node = result["stun"]
            steps = self.insert_pulse(steps, i, k, bid, shot, node)
        damage = result["damage"]
        for b in badges:
            self.info["badges"].append({"id": b["id"], "hits": result["hits"].get(b["id"], 0),
                                        "stuns": sum(1 for s in steps if s.get("target", {}).get("id") == b["id"])})
        self.info["sync_damage"] = damage
        budget = float(self.val.get("sync_damage_budget", 0.0))
        if damage > budget + EPS:
            self.error("los puntos rojos quitan %.0f de Sync Rate en el camino (presupuesto %.0f, "
                       "validation.sync_damage_budget)" % (damage, budget))
        return steps

    def frames(self, steps):
        """Lista de cuadros (indice de paso, cuadro dentro del paso, x, pies, en_el_aire, debug, accion,
        invulnerable por el dash)."""
        out = []
        debug = False
        for i, s in enumerate(steps):
            if s["action"] == "debug_on":
                debug = True
            elif s["action"] == "debug_off":
                debug = False
            smp = self.samples(s)
            inv = self.invulnerable_range(s)
            for k, (x, feet, air) in enumerate(smp):
                out.append((i, k, x, feet, air, debug, s["action"], inv[0] <= k < inv[1]))
        return out

    def simulate_badges(self, steps, badges):
        T = self.T
        frames = self.frames(steps)
        r = self.rules
        hits = {}
        damage = 0.0
        invuln = 0.0
        states = []
        for b in badges:
            p = b["p"]
            lw, lh = float(p["leash_width_px"]), float(p["leash_height_px"])
            states.append({"b": b, "pos": list(b["spawn"]), "state": "idle", "timer": 0.0, "dir": (1.0, 0.0),
                           "leash": (b["spawn"][0] - lw / 2, b["spawn"][1] - lh / 2, b["spawn"][0] + lw / 2,
                                     b["spawn"][1] + lh / 2), "dead": False})
        for idx, (i, k, x, feet, air, debug, action, dash_inv) in enumerate(frames):
            dt = DT * (r.debug_world_scale if debug else 1.0)
            invuln = max(0.0, invuln - DT)
            cx, cy = x, feet - 48.0
            for st in states:
                if st["dead"]:
                    continue
                p = st["b"]["p"]
                bx, by = st["pos"]
                dx, dy = cx - bx, cy - by
                dist = math.hypot(dx, dy)
                inside = st["leash"][0] <= cx <= st["leash"][2] and st["leash"][1] <= cy <= st["leash"][3]
                s = st["state"]
                if s == "idle":
                    if inside and dist <= float(p["wake_radius_px"]):
                        st["state"] = "chase"
                elif s == "chase":
                    if not (inside and dist <= float(p["give_up_radius_px"])):
                        st["state"] = "return"
                    elif dist <= float(p["lunge_radius_px"]):
                        st["state"] = "anticipate"
                        st["timer"] = float(p["anticipation_frames"]) / float(p["anim_fps"])
                        # Isak de pie y el pulso lo alcanza: se aturde (paso insertado).
                        stun = self.stun_shot(frames, idx, st)
                        if stun is not None:
                            return {"stun": stun, "damage": damage, "hits": hits}
                    else:
                        self.badge_move(st, dx / max(dist, EPS) * float(p["chase_speed_px_s"]),
                                        dy / max(dist, EPS) * float(p["chase_speed_px_s"]), dt)
                elif s == "anticipate":
                    if dist > 0.5:
                        st["dir"] = (dx / dist, dy / dist)
                    st["timer"] -= dt
                    if st["timer"] <= 0.0:
                        st["state"] = "lunge"
                        st["timer"] = float(p["lunge_s"])
                elif s == "lunge":
                    sp = float(p["lunge_speed_px_s"])
                    self.badge_move(st, st["dir"][0] * sp, st["dir"][1] * sp, dt)
                    st["timer"] -= dt
                    half = float(p["damage_size"][0]) / 2, float(p["damage_size"][1]) / 2
                    drect = (st["pos"][0] - half[0], st["pos"][1] - half[1], st["pos"][0] + half[0], st["pos"][1] + half[1])
                    if invuln <= 0.0 and not dash_inv and rects_overlap(self.hurt_rect(x, feet), drect):
                        damage += float(p["contact_damage"])
                        hits[st["b"]["id"]] = hits.get(st["b"]["id"], 0) + 1
                        invuln = 1.0
                        st["timer"] = 0.0
                    if st["timer"] <= 0.0:
                        st["state"] = "recover"
                        st["timer"] = float(p["recover_s"])
                elif s == "recover":
                    st["timer"] -= dt
                    if st["timer"] <= 0.0:
                        st["state"] = "chase"
                elif s == "return":
                    hx, hy = st["b"]["spawn"][0] - bx, st["b"]["spawn"][1] - by
                    hd = math.hypot(hx, hy)
                    if inside and dist <= float(p["wake_radius_px"]):
                        st["state"] = "chase"
                    elif hd <= max(4.0, float(p["return_speed_px_s"]) * dt):
                        st["pos"] = list(st["b"]["spawn"])
                        st["state"] = "idle"
                    else:
                        sp = float(p["return_speed_px_s"])
                        self.badge_move(st, hx / hd * sp, hy / hd * sp, dt)
                elif s == "stunned":
                    st["timer"] -= dt
                    if st["timer"] <= 0.0:
                        st["state"] = "chase"
            # Pulso del plan: aturde a los puntos rojos que alcance.
            if action == "pulse" and k == 0:
                s = steps[i]
                for st in states:
                    if s.get("target", {}).get("id") == st["b"]["id"] or self.pulse_reaches_badge(s, st):
                        st["state"] = "stunned"
                        st["timer"] = float(st["b"]["p"]["stun_duration_s"])
        return {"stun": None, "damage": damage, "hits": hits}

    def badge_move(self, st, vx, vy, dt):
        """Vuela; el terreno lo para (por ejes) y no sale de su correa."""
        T = self.T
        half = 24.0
        world = self.m.world(frozenset(), False)
        for axis, vel in ((0, vx), (1, vy)):
            pos = list(st["pos"])
            pos[axis] += vel * dt
            c0, c1 = int(math.floor((pos[0] - half) / T)), int(math.floor((pos[0] + half - EPS) / T))
            r0, r1 = int(math.floor((pos[1] - half) / T)), int(math.floor((pos[1] + half - EPS) / T))
            blocked = any(world.is_solid(c, rr) for c in range(c0, c1 + 1) for rr in range(r0, r1 + 1))
            if not blocked:
                st["pos"] = pos
        lx0, ly0, lx1, ly1 = st["leash"]
        st["pos"][0] = min(max(st["pos"][0], lx0), lx1)
        st["pos"][1] = min(max(st["pos"][1], ly0), ly1)

    def pulse_reaches_badge(self, s, st):
        shot = s.get("shot")
        node = s.get("at")
        if node is None:
            return False
        feet = (node[1] + 1) * self.T
        x = shot["x"] if shot else self.feet(node)[0]
        for facing in ((shot["facing"],) if shot else (1.0, -1.0)):
            px, py = x + self.rules.phone_x * facing, feet + self.rules.phone_y
            bx, by = st["pos"]
            qx = min(max(px, bx - 24.0), bx + 24.0)
            qy = min(max(py, by - 24.0), by + 24.0)
            if math.hypot(px - qx, py - qy) <= self.rules.pulse_radius + EPS:
                return True
        return False

    def stun_shot(self, frames, idx, st):
        """Si Isak esta de pie en este cuadro y el pulso alcanza al punto rojo, donde se inserta."""
        i, k, x, feet, air, debug, action, _ = frames[idx]
        if air or action in ("laser", "pulse", "hop"):
            return None
        bx, by = st["pos"]
        for facing in (1.0 if bx >= x else -1.0,):
            px, py = x + self.rules.phone_x * facing, feet + self.rules.phone_y
            qx = min(max(px, bx - 24.0), bx + 24.0)
            qy = min(max(py, by - 24.0), by + 24.0)
            if math.hypot(px - qx, py - qy) <= self.rules.pulse_radius + EPS:
                node = (int(x // self.T), int(round(feet / self.T)) - 1)
                return (i, k, st["b"]["id"], {"x": x, "facing": facing}, node)
        return None

    def insert_pulse(self, steps, i, k, bid, shot, node):
        """Inserta un pulso hacia el punto rojo `bid` en la celda de pie mas cercana al cuadro k del
        paso i (al empezar o al terminar un andar; antes de un salto; tras una espera o accion)."""
        s = steps[i]
        if s["action"] == "move" and s["kind"] == "walk" and k >= len(self.samples(s)) / 2:
            at, pos = s["to"], i + 1
        elif s["action"] == "move":
            at, pos = s["from"], i
        else:
            at, pos = tuple(s.get("at") or node), i + 1
        x = (s["shot"]["x"] if s["action"] != "move" and s.get("shot") else self.feet(at)[0])
        pulse = {"action": "pulse", "at": at, "shot": {"x": x, "facing": shot["facing"]},
                 "state": s.get("state", frozenset()), "target": {"type": "notification_badge", "id": bid}}
        return steps[:pos] + [pulse] + steps[pos:]

    # --- Banners, campanas y plataformas que parpadean (amenazas con tiempo) ---
    #
    # Paso 9 de docs/propuesta-1-3.md (§6.1): ademas de los banners de siempre (reloj del nivel, fase libre:
    # el bot espera en la entrada a la fase indicada), los banners y campanas con `rhythm` y las plataformas
    # que parpadean siguen un metronomo (rhythm_zone) o un tunel de alarmas (alarm_tunnel): su reloj es el
    # del metronomo, que arranca cuando Isak entra en su zona (start on_enter) y, en el tunel, se acelera por
    # la columna mas avanzada. La busqueda por tiempo lleva el estado exacto de cada metronomo (arrancado,
    # ciclos, segundos del ciclo, columna mas avanzada), el enfriamiento del dash y la fase del nivel. Un
    # movimiento con dash deja a Isak invulnerable dash_invulnerable_s desde el primer cuadro del dash: los
    # banners y las ondas no le dan en esos cuadros. Las plataformas que parpadean solo se pisan (o se tocan)
    # encendidas. Sin nada de esto (el 1-2), la busqueda es la de siempre (misma salida byte a byte).

    def banner_data(self):
        out = []
        for enemy in self.level.get("enemies", []):
            if enemy["type"] != "spam_banner":
                continue
            data = self.v.enemy_data("spam_banner")
            p = dict(data)
            p.update(enemy.get("params", {}))
            T = self.T
            direction = int(p["direction"])
            corridor = float(p["corridor_tiles"]) * T
            bw = float(p["banner_size"][0])
            warn = float(p["anticipation_frames"]) / float(p["anim_fps"])
            sweep = max(corridor - bw, 0.0) / float(p["sweep_speed_px_s"])
            interval = max(float(p["interval_s"]), warn + sweep + 0.01)
            feet = (enemy["y"] + 1) * T
            entry = (enemy["x"] + 0.5) * T - T * 0.5 * direction
            a, b = entry, entry + direction * corridor
            dw, dh = float(p["damage_size"][0]), float(p["damage_size"][1])
            bottom = feet - float(p["damage_bottom_px"])
            # Banner con ritmo (tunel de alarmas del 1-3): su intervalo es el ciclo de su metronomo (sin el
            # metronomo en el nivel, interval_s, como SpamBanner).
            rhythm = str(p.get("rhythm", "") or "")
            if rhythm not in self.m.zones:
                rhythm = ""
            out.append({"id": enemy["id"], "dir": direction, "corridor": corridor, "bw": bw, "warn": warn,
                        "sweep": sweep, "interval": interval, "rest": interval - warn - sweep,
                        "phase": float(p.get("phase_s", 0.0)), "entry": entry, "speed": float(p["sweep_speed_px_s"]),
                        "dw": dw, "dh": dh, "bottom": bottom, "cell": (enemy["x"], enemy["y"]),
                        "band": (min(a, b), bottom - dh, max(a, b), bottom), "kind": "banner", "rhythm": rhythm,
                        "rhythm_offset": float(p.get("rhythm_offset", 0.0)),
                        "knockback": bool(p.get("knockback_to_entry", False))})
        return out

    def bell_data(self):
        """Campanas de alarma (alarm_bell): onda vertical de un tile (damage_width_px) desde lo alto de su
        celda hasta el suelo (wave_tiles celdas) durante wave_s tras el aviso; con su metronomo (rhythm,
        desplazado offset) o con su propio interval_s y phase_s (reloj del nivel). Antes de que arranque
        su metronomo, quieta."""
        out = []
        for enemy in self.level.get("enemies", []):
            if enemy["type"] != "alarm_bell":
                continue
            p = dict(self.v.enemy_data("alarm_bell"))
            p.update(enemy.get("params", {}))
            T = self.T
            warn = float(p["anticipation_frames"]) / float(p["anim_fps"])
            wave = float(p["wave_s"])
            cx = (enemy["x"] + 0.5) * T
            dw = float(p.get("damage_width_px", 48.0))
            top = enemy["y"] * T
            band = (cx - dw * 0.5, top, cx + dw * 0.5, top + int(p["wave_tiles"]) * T)
            rhythm = str(p.get("rhythm", "") or "")
            if rhythm not in self.m.zones:
                rhythm = ""
            out.append({"id": enemy["id"], "kind": "bell", "warn": warn, "wave": wave,
                        "interval": max(float(p["interval_s"]), warn + wave + 0.01), "phase": float(p.get("phase_s", 0.0)),
                        "rhythm": rhythm, "offset": float(p.get("offset", 0.0)), "band": band, "bottom": band[3],
                        "cell": (enemy["x"], enemy["y"])})
        return out

    def hazards(self):
        """Amenazas con tiempo del nivel: banners y campanas (dano por contacto) y plataformas que parpadean
        con metronomo (solo se pisan encendidas). `level`: las que van con el reloj del nivel (sin rhythm)."""
        if getattr(self, "_hazards", None) is None:
            banners = self.banner_data()
            bells = self.bell_data()
            # Mundo 2 (paso 9b): videos en autoplay (ola, rayo y cuenta) y Comentaristas, con el reloj del nivel.
            feed = self.feed_data()
            blinks = []
            for bl in self.m.blink_items:
                if bl["rhythm"] in self.m.zones:
                    blinks.append(dict(bl, kind="blink", band=bl["rect"], bottom=bl["rect"][3]))
            timed = banners + bells + feed
            self._hazards = {"banners": banners, "bells": bells, "blinks": blinks, "timed": timed, "feed": feed,
                             "level": [h for h in timed if not h["rhythm"]], "all": timed + blinks,
                             "legacy": not (bells or blinks or feed or self.m.dash_possible
                                            or any(b["rhythm"] for b in banners))}
        return self._hazards


    # --- Mundo 2 (paso 9b de docs/propuesta-mundo-2.md): videos en autoplay y Comentaristas ---
    # Amenazas con el reloj del nivel, como los banners (el bot espera en la entrada a la fase del plan):
    #   - ola del video (clip wave): un SpamBanner en modo disparo por la fila de abajo de la tarjeta, como un
    #     banner cuyo intervalo es el del clip (clip_s, o aviso + barrido + min_rest_s);
    #   - rayo (clip ray): onda de 1 tile (damage_width_px de alarm_bell) desde la fila de arriba de la tarjeta
    #     ray_tiles celdas hacia abajo, ray_wave_s tras el aviso, en la columna de Isak AL EMPEZAR EL CLIP: la
    #     busqueda recuerda esa columna en su estado (si Isak no tenia la tarjeta entera a la vista, no cae);
    #   - cuenta (clip count) y Comentarista: proyectiles (NotificationShot, size_px sin girar) que salen al
    #     terminar el aviso y vuelan a shot_speed_px_s hasta shot_range_tiles o hasta el terreno ('#').
    # La activacion por camara (el clip empieza al entrar la tarjeta entera en la vista) no fija la fase: como
    # con los banners, la busqueda elige la fase y el camino exportado la sincroniza (wait_phase, clip_cycle_s).
    # start_delay_s (2026-10-23, paso 13: las parejas del 2-2) desplaza la fase del video (-start_delay_s): dos
    # videos del MISMO clip que entran a la vez en la vista (mismas filas) guardan en el juego el desfase de sus
    # start_delay_s, y asi tambien en el plan (sin start_delay_s, fase 0 como antes). Una ola y un rayo juntos
    # no quedan bien desfasados (la ola mide su ciclo desde el barrido): el 2-2 no los empareja.
    # El pulso (pausa 3 s) y el laser no se usan en el plan: basta con esquivarlos.

    def view_rect(self, card):
        """Posiciones del centro del cuerpo de Isak con las que la tarjeta `card` (px) se ve entera, con la
        camara centrada en Isak (VIEW_W_PX x VIEW_H_PX)."""
        cx, cy = (card[0] + card[2]) * 0.5, (card[1] + card[3]) * 0.5
        hx = max(VIEW_W_PX * 0.5 - (card[2] - card[0]) * 0.5, 0.0)
        hy = max(VIEW_H_PX * 0.5 - (card[3] - card[1]) * 0.5, 0.0)
        return (cx - hx, cy - hy, cx + hx, cy + hy)

    def in_view(self, view, x, feet):
        y = feet - self.m.hh * 0.5
        return view[0] <= x <= view[2] and view[1] <= y <= view[3]

    def shot_travel(self, origin, vel, size, probe_dy, range_px):
        """Distancia (px) que vuela un proyectil desde `origin` con direccion `vel` (unitaria) hasta
        range_px o hasta que el punto de prueba (centro + (0, probe_dy)) entra en terreno solido."""
        grid = self.m.grid
        d = 0.0
        while d < range_px:
            nd = min(d + SHOT_PROBE_PX, range_px)
            px, py = origin[0] + vel[0] * nd, origin[1] + vel[1] * nd + probe_dy
            c, r = int(math.floor(px / self.T)), int(math.floor(py / self.T))
            if not (0 <= r < len(grid) and 0 <= c < len(grid[r])) or grid[r][c] == "#":
                return nd
            d = nd
        return range_px

    def shot_item(self, eid, kind_of, warn, interval, phase, origin, vel, speed, size, travel):
        hw, hh = size[0] * 0.5, size[1] * 0.5
        end = (origin[0] + vel[0] * travel, origin[1] + vel[1] * travel)
        band = (min(origin[0], end[0]) - hw, min(origin[1], end[1]) - hh, max(origin[0], end[0]) + hw,
                max(origin[1], end[1]) + hh)
        return {"id": eid, "kind": "shot", "feed": kind_of, "warn": warn, "launch": warn, "interval": interval,
                "phase": phase, "rhythm": "", "origin": origin, "vel": (vel[0] * speed, vel[1] * speed),
                "half": (hw, hh), "travel_s": travel / max(speed, 1.0), "band": band, "bottom": band[3]}

    def feed_data(self):
        out = []
        T = self.T
        for enemy in self.level.get("enemies", []):
            if enemy["type"] == "autoplay_video":
                p = dict(self.v.enemy_data("autoplay_video"))
                p.update(enemy.get("params", {}))
                x, y = int(enemy["x"]), int(enemy["y"])
                cw, ch = int(p["card_tiles"][0]), int(p["card_tiles"][1])
                card = (x * T, (y + 1 - ch) * T, (x + cw) * T, (y + 1) * T)
                facing = 1 if int(p["facing"]) >= 0 else -1
                warn = float(p["anticipation_frames"]) / float(p["anim_fps"])
                clip = str(p["clip"])
                rest_min = float(p.get("min_rest_s", 0.25))
                delay = float(p.get("start_delay_s", 0.0))
                if clip == "wave":
                    b = dict(self.v.enemy_data("spam_banner"))
                    corridor = float(p["wave_tiles"]) * T
                    bw = float(b["banner_size"][0])
                    bwarn = float(b["anticipation_frames"]) / float(b["anim_fps"])
                    sweep = max(corridor - bw, 0.0) / float(b["sweep_speed_px_s"])
                    interval = max(float(p["clip_s"]), warn + sweep + rest_min)
                    bx = x + (cw - 1 if facing > 0 else 0)
                    by = y + int(p.get("wave_row_offset", 0))
                    feet = (by + 1) * T
                    entry = (bx + 0.5) * T - T * 0.5 * facing
                    a, bnd = entry, entry + facing * corridor
                    dw, dh = float(b["damage_size"][0]), float(b["damage_size"][1])
                    bottom = feet - float(b["damage_bottom_px"])
                    out.append({"id": enemy["id"], "dir": facing, "corridor": corridor, "bw": bw, "warn": bwarn,
                                "sweep": sweep, "interval": interval, "rest": interval - bwarn - sweep,
                                "phase": (-delay) % interval if delay else 0.0,
                                "entry": entry, "speed": float(b["sweep_speed_px_s"]), "dw": dw, "dh": dh,
                                "bottom": bottom, "cell": (bx, by),
                                "band": (min(a, bnd), bottom - dh, max(a, bnd), bottom), "kind": "banner",
                                "rhythm": "", "rhythm_offset": 0.0, "knockback": False, "feed": "autoplay_video",
                                "clip_shift": interval - bwarn - sweep})
                elif clip == "ray":
                    wave = float(p["ray_wave_s"])
                    interval = max(float(p["clip_s"]), warn + wave + rest_min)
                    bell = self.v.enemy_data("alarm_bell")
                    dw = float(bell.get("damage_width_px", 48.0))
                    top = card[1] + int(p.get("ray_top_offset", 0)) * T
                    bottom = top + int(p["ray_tiles"]) * T
                    view = self.view_rect(card)
                    c0, c1 = int(math.floor(view[0] / T)), int(math.floor(view[2] / T))
                    out.append({"id": enemy["id"], "kind": "ray", "feed": "autoplay_video", "warn": warn,
                                "wave": wave, "interval": interval, "phase": (-delay) % interval if delay else 0.0,
                                "rhythm": "", "dw": dw,
                                "top": top, "bottom_px": bottom, "view": view,
                                "band": (c0 * T, top, (c1 + 1) * T, bottom), "bottom": bottom, "cell": (x, y)})
                else:
                    attack = float(p.get("count_attack_s", 0.5))
                    interval = max(float(p["clip_s"]), warn + attack + rest_min)
                    origin = ((card[0] + card[2]) * 0.5, (card[1] + card[3]) * 0.5)
                    speed = float(p["shot_speed_px_s"])
                    size = (float(p["shot_size_px"][0]), float(p["shot_size_px"][1]))
                    degs = list(p.get("fan_deg", [0.0]))
                    for i in range(int(p.get("fan_count", len(degs)))):
                        ang = math.radians(float(degs[i]) if i < len(degs) else 0.0) * facing
                        vel = (facing * math.cos(ang), facing * math.sin(ang))
                        travel = self.shot_travel(origin, vel, size, 0.0, float(p["shot_range_tiles"]) * T)
                        out.append(self.shot_item(enemy["id"], "autoplay_video", warn, interval,
                                                  (-delay) % interval if delay else 0.0, origin, vel, speed, size,
                                                  travel))
            elif enemy["type"] == "commenter":
                p = dict(self.v.enemy_data("commenter"))
                p.update(enemy.get("params", {}))
                x, y = int(enemy["x"]), int(enemy["y"])
                facing = 1 if int(p["facing"]) >= 0 else -1
                warn = float(p["anticipation_frames"]) / float(p["anim_fps"])
                interval = max(float(p["interval_s"]), warn + float(p.get("min_rest_s", 0.25)))
                origin = ((x + 0.5 + facing * int(p.get("shot_col_offset", 1))) * T, (y + 1) * T - T * 0.5)
                speed = float(p["shot_speed_px_s"])
                size = (float(p["shot_size_px"][0]), float(p["shot_size_px"][1]))
                # Commenter._step_shots apaga el bocadillo cuando su borde de arriba toca terreno.
                travel = self.shot_travel(origin, (0.0, -1.0), size, -size[1] * 0.5, float(p["shot_range_tiles"]) * T)
                # Su reloj corre desde el inicio del nivel, desplazado offset_s (ciclo = tiempo - offset_s).
                out.append(self.shot_item(enemy["id"], "commenter", warn, interval, -float(p.get("offset_s", 0.0)),
                                          origin, (0.0, -1.0), speed, size, travel))
        return out

    def feed_rects(self, h, t, zs):
        """Zonas de dano de un proyectil o un rayo del feed a los `t` s de su ciclo."""
        if h["kind"] == "shot":
            out = []
            age = t - h["launch"]
            while age < h["travel_s"]:
                if age >= 0.0:
                    cx, cy = h["origin"][0] + h["vel"][0] * age, h["origin"][1] + h["vel"][1] * age
                    out.append((cx - h["half"][0], cy - h["half"][1], cx + h["half"][0], cy + h["half"][1]))
                age += h["interval"]
            return out
        if not (h["warn"] <= t < h["warn"] + h["wave"]):
            return []
        col = zs.get(("ray", h["id"])) if zs is not None else None
        if col is None:
            return [h["band"]]  # sin saber donde estaba Isak al empezar el clip: toda su franja
        if col < 0:
            return []
        cx = (col + 0.5) * self.T
        return [(cx - h["dw"] * 0.5, h["top"], cx + h["dw"] * 0.5, h["bottom_px"])]

    def feed_hits(self, h, tw, zs, box, margin):
        t = (tw + h["phase"]) % h["interval"]
        for d in (self.margin_offsets(margin) if margin > 0.0 else (0.0,)):
            for rect in self.feed_rects(h, (t + d) % h["interval"], zs):
                if rects_overlap(box, rect):
                    return True
        return False

    def ray_note(self, rays, zs, t0, t1, x, feet):
        """Al empezar un clip de un rayo entre t0 y t1 (reloj del nivel), la columna de Isak (o -1 si no tenia
        la tarjeta entera a la vista y el clip no empieza)."""
        for h in rays:
            c0 = (t0 + h["phase"]) % h["interval"]
            c1 = (t1 + h["phase"]) % h["interval"]
            if c1 < c0 or t1 - t0 >= h["interval"]:
                zs[("ray", h["id"])] = int(math.floor(x / self.T)) if self.in_view(h["view"], x, feet) else -1
            elif c1 >= h["warn"] + h["wave"]:
                # Pasado el rayo la columna ya no importa (menos estados en la busqueda).
                zs[("ray", h["id"])] = -1

    # --- Zonas de clones de «Un video mas» (Mundo 2, paso 9b) ---
    # Simulacion a lo largo del camino (como los puntos rojos), con CloneZone y VideoClone: con los pies de Isak
    # dentro de la zona, cada spawn_s (tiempo del mundo) un aviso de warn_frames a anim_fps y nace un clon en el
    # borde de la zona mas lejano a Isak, a ras de su fila de abajo, que patrulla hacia el centro a
    # patrol_speed_px_s y gira en los limites de la zona, en las paredes (y en el muro sin romper) y en los
    # bordes; tope max_clones (vivos + avisando); al salir, el reloj a cero. Un golpe al suelo cuya onda toca la
    # zona los elimina a todos, cancela el aviso y pone el reloj a cero. Si un clon alcanza a Isak (salvo en los
    # cuadros invulnerables del dash), el plan anade un golpe al suelo antes (en una celda de pie dentro de la
    # zona, o partiendo una espera) y vuelve a simular; si no hay golpe (o no llega a tiempo), error.

    def clone_zones(self):
        cfg = self.m.catalog.get("clone_zone", {})
        types = self.m.catalog.get("types", {}).get("clone_zone", {})
        data = None
        out = []
        T = self.T
        for obj in self.level.get("objects", []):
            if obj["type"] != "clone_zone":
                continue
            if data is None:
                data = self.v.enemy_data("video_clone")
            p = dict(types.get("defaults", {}))
            p.update(obj.get("params", {}))
            zc, zr, zw, zh = [int(v) for v in p["zone"]]
            rect = (zc * T, zr * T, (zc + zw) * T, (zr + zh) * T)
            out.append({"id": str(p.get("id", "clone_zone_%d_%d" % (obj["x"], obj["y"]))), "rect": rect,
                        "spawn_s": float(p.get("spawn_s", 1.5)), "max": int(p.get("max_clones", 6)),
                        "warn": float(cfg.get("warn_frames", 9)) / float(cfg.get("anim_fps", 12.0)),
                        "left": rect[0] + T * 0.5, "right": rect[2] - T * 0.5, "feet": rect[3],
                        "row": zr + zh - 1, "speed": float(data["patrol_speed_px_s"]),
                        "body": (float(data["body_size"][0]), float(data["body_size"][1])),
                        "damage": (float(data["damage_size"][0]), float(data["damage_size"][1]))})
        return out

    def clone_solid(self, c, r, walls):
        grid = self.m.grid
        if not (0 <= r < len(grid) and 0 <= c < len(grid[r])):
            return True
        return grid[r][c] == "#" or (c, r) in walls

    def clone_support(self, c, r, walls):
        grid = self.m.grid
        if not (0 <= r < len(grid) and 0 <= c < len(grid[r])):
            return False
        return grid[r][c] in "#-" or (c, r) in walls

    def simulate_clones(self, steps, zones):
        """Recorre el camino; devuelve {"hit": (paso, cuadro, zona, nodo) o None, "stats": por zona}."""
        T = self.T
        rules = self.rules
        self.timeline(steps)
        walls = {}
        for g in self.m.gates:
            if g.kind == "pound":
                for cell in g.cells:
                    walls[cell] = g.obj_id
        broken = set()
        st = {z["id"]: {"inside": 0.0, "warn": -1.0, "at": 0.0, "clones": [], "spawned": 0, "max": 0, "inside_s": 0.0,
                        "wave_pounds": 0, "removed": 0}
              for z in zones}
        land_k = int(round(rules.pound_land_s / DT))
        for i, s in enumerate(steps):
            smp = self.samples(s)
            if not smp:
                continue
            scale = rules.debug_world_scale if s.get("debug_active") else 1.0
            dt = self.duration(s) / len(smp) * scale
            inv = self.invulnerable_range(s)
            pound_at = None
            if s["action"] == "ground_pound":
                pound_at = min(len(smp) - 1, land_k + (int(round(rules.pound_cooldown_s / DT))
                                                       if s.get("cooldown_before") else 0))
            for k, (x, feet, _air) in enumerate(smp):
                live = {cell for cell, gid in walls.items() if gid not in broken}
                for z in zones:
                    zs = st[z["id"]]
                    if zs["warn"] >= 0.0:
                        zs["warn"] -= dt
                        if zs["warn"] <= 0.0:
                            zs["warn"] = -1.0
                            center = (z["rect"][0] + z["rect"][2]) * 0.5
                            zs["clones"].append([zs["at"], 1.0 if zs["at"] < center else -1.0])
                            zs["spawned"] += 1
                    r = z["rect"]
                    if r[0] <= x < r[2] and r[1] <= feet - 1.0 < r[3]:
                        zs["inside"] += dt
                        zs["inside_s"] += dt
                        if zs["inside"] >= z["spawn_s"]:
                            zs["inside"] -= z["spawn_s"]
                            if len(zs["clones"]) + (1 if zs["warn"] >= 0.0 else 0) >= z["max"]:
                                zs["inside"] = 0.0
                            else:
                                far_left = abs(x - z["left"]) >= abs(x - z["right"])
                                zs["at"] = z["left"] if far_left else z["right"]
                                zs["warn"] = z["warn"]
                    else:
                        zs["inside"] = 0.0
                    half = z["body"][0] * 0.5
                    for cl in zs["clones"]:
                        nx = cl[0] + cl[1] * z["speed"] * dt
                        lead = nx + cl[1] * half
                        col = int(math.floor(lead / T))
                        if (nx < z["left"] or nx > z["right"] or self.clone_solid(col, z["row"], live)
                                or not self.clone_support(col, z["row"] + 1, live)):
                            cl[1] = -cl[1]
                            nx = min(max(cl[0], z["left"]), z["right"])
                        cl[0] = nx
                    zs["max"] = max(zs["max"], len(zs["clones"]))
                    if not (inv[0] <= k < inv[1]) and zs["clones"]:
                        hr = self.hurt_rect(x, feet)
                        dw, dh = z["damage"]
                        top = z["feet"] - z["body"][1] * 0.5 - dh * 0.5
                        for cl in zs["clones"]:
                            if rects_overlap(hr, (cl[0] - dw * 0.5, top, cl[0] + dw * 0.5, top + dh)):
                                return {"hit": (i, k, z["id"], self.node_of(s) or s.get("to")), "stats": st}
                if pound_at is not None and k == pound_at:
                    wave = (x - rules.pound_half_width, feet - rules.pound_height, x + rules.pound_half_width,
                            feet + rules.pound_below)
                    for z in zones:
                        if rects_overlap(wave, z["rect"]):
                            zs = st[z["id"]]
                            # Paso 14 (2-3): cualquier golpe cuya onda toca la zona la limpia (tambien los del muro).
                            zs["wave_pounds"] += 1
                            zs["removed"] += len(zs["clones"]) + (1 if zs["warn"] >= 0.0 else 0)
                            zs["clones"] = []
                            zs["warn"] = -1.0
                            zs["inside"] = 0.0
                    broken.update(s.get("breaks", []))
        return {"hit": None, "stats": st}

    def hit_time(self, steps, hit):
        i, k = hit[0], hit[1]
        smp = self.samples(steps[i])
        return steps[i]["t"] + self.duration(steps[i]) * (k + 1) / max(len(smp), 1)

    def clone_pound(self, node, state, zid):
        x, feet = self.feet(node)
        return {"action": "ground_pound", "at": node, "shot": {"x": x, "facing": 1}, "state": state, "air": False,
                "breaks": [], "clears": [zid], "target": {"type": "clone_zone", "id": zid}}

    def pound_reaches(self, node, z):
        rules = self.rules
        x, feet = self.feet(node)
        wave = (x - rules.pound_half_width, feet - rules.pound_height, x + rules.pound_half_width,
                feet + rules.pound_below)
        return rects_overlap(wave, z["rect"])

    def clone_candidates(self, steps, hit, z):
        """Variantes del camino con un golpe al suelo que limpie la zona antes del golpe del clon: partiendo la
        espera en la que llega (si es una espera simple) o tras una celda de pie anterior dentro de la zona."""
        i, k, zid, _node = hit
        s = steps[i]
        out = []
        if s["action"] in ("wait", "wait_scroll") and not s.get("timed") and s.get("seconds", 0.0) > 0.0:
            node = tuple(s["at"])
            if self.m.has_pound(s["state"]) and self.pound_reaches(node, z):
                local = self.duration(s) * (k + 1) / max(len(self.samples(s)), 1)
                lead = self.rules.pound_land_s + 0.25
                while local - lead > 0.0:
                    first = dict(s, seconds=local - lead)
                    first.pop("_samples", None)
                    second = dict(s, seconds=s["seconds"] - (local - lead))
                    second.pop("_samples", None)
                    out.append(steps[:i] + [first, self.clone_pound(node, s["state"], zid), second] + steps[i + 1:])
                    lead += 0.5
        for j in range(i - 1, max(-1, i - 16), -1):
            sj = steps[j]
            if sj["action"] != "move":
                continue
            nxt = steps[j + 1]
            if sj.get("timed") and nxt.get("timed") and nxt["action"] != "wait_phase":
                continue  # dentro de un cruce con tiempo (banners, acertijos): no se interrumpe
            node = tuple(sj["to"])
            if not self.m.has_pound(sj["state"]) or not self.pound_reaches(node, z):
                continue
            if not self.m.world(sj["state"], False).is_node(*node):
                continue
            out.append(steps[:j + 1] + [self.clone_pound(node, sj["state"], zid)] + steps[j + 1:])
        return out

    def check_clones(self, steps):
        zones = self.clone_zones()
        if not zones:
            return steps
        by_id = {z["id"]: z for z in zones}
        added = {z["id"]: 0 for z in zones}
        result = self.simulate_clones(steps, zones)
        failed = None
        for _ in range(MAX_CLONE_POUNDS):
            if result["hit"] is None:
                break
            hit = result["hit"]
            t_hit = self.hit_time(steps, hit)
            chosen = None
            for cand in self.clone_candidates(steps, hit, by_id[hit[2]]):
                self.resolve_phase_waits(cand, None)
                res = self.simulate_clones(cand, zones)
                if res["hit"] is None or self.hit_time(cand, res["hit"]) > t_hit + EPS:
                    chosen = (cand, res)
                    break
            if chosen is None:
                failed = hit
                break
            steps, result = chosen
            added[hit[2]] += 1
        else:
            failed = result["hit"]
        self.timeline(steps)
        if failed is not None:
            self.resolve_phase_waits(steps, None)
            result = self.simulate_clones(steps, zones)
            i, k, zid, node = failed
            self.error("zona de clones %s: un clon alcanza a Isak en el paso %d%s y no hay golpe al suelo que la limpie "
                       "a tiempo (el camino pasa mas de %.1f s dentro; abilities_available.ground_pound o un "
                       "reproductor)" % (zid, i, "" if node is None else " (fila %d, columna %d)" % (node[1], node[0]),
                                         by_id[zid]["spawn_s"]), node, zid)
        stats = result["stats"]
        self.info["clones"] = [{"id": z["id"], "pounds": added[z["id"]], "spawned": stats[z["id"]]["spawned"],
                                "max_alive": stats[z["id"]]["max"], "inside_s": round(stats[z["id"]]["inside_s"], 2),
                                "wave_pounds": stats[z["id"]]["wave_pounds"], "removed": stats[z["id"]]["removed"]}
                               for z in zones]
        return steps

    # Metronomos (rhythm_zone / alarm_tunnel): estado (arrancado, ciclos, segundos del ciclo, columna mas
    # avanzada), como RhythmZone.step / AlarmTunnel.

    def zone_init(self, z):
        return (z["start"] == "always", 0, 0.0, -1)

    def zone_stage(self, z, st):
        idx = 0
        for i, stage in enumerate(z["stages"]):
            if st[3] >= int(stage.get("x_from", 0)):
                idx = i
        return idx

    def zone_cycle(self, z, st):
        if z["stages"]:
            return max(float(z["stages"][self.zone_stage(z, st)].get("cycle_s", 1.0)), 0.05)
        n = len(z["tempo"])
        k = st[1] // z["cycles_per_step"]
        return max(z["tempo"][k % n if z["loop"] else min(k, n - 1)], 0.05)

    def zone_inside(self, z, x, feet):
        r = z["rect"]
        return r[0] <= x < r[2] and r[1] <= feet - 1.0 < r[3]

    def zone_step(self, z, st, x, feet, dt):
        """Un cuadro del metronomo con Isak en (x, pies) y dt de tiempo del mundo."""
        started, cycles, t, max_col = st
        if not started:
            if z["start"] != "always" and not self.zone_inside(z, x, feet):
                return st
            started = True
        if z["stages"] and self.zone_inside(z, x, feet):
            max_col = max(max_col, int(math.floor(x / self.T)))
        t += dt
        cycle = self.zone_cycle(z, (started, cycles, t, max_col))
        while t >= cycle:
            t -= cycle
            cycles += 1
            cycle = self.zone_cycle(z, (started, cycles, t, max_col))
        return (started, cycles, t, max_col)

    def zone_shift(self, z, st, dt):
        """El metronomo `dt` segundos despues (o antes, dt < 0) sin moverse Isak (ventana del dash)."""
        if not st[0]:
            return st
        if dt >= 0.0:
            started, cycles, t, max_col = st
            t += dt
            cycle = self.zone_cycle(z, st)
            while t >= cycle:
                t -= cycle
                cycles += 1
                cycle = self.zone_cycle(z, (started, cycles, t, max_col))
            return (started, cycles, t, max_col)
        started, cycles, t, max_col = st
        t += dt
        while t < 0.0 and cycles > 0:
            cycles -= 1
            t += self.zone_cycle(z, (started, cycles, t, max_col))
        return (started, cycles, max(t, 0.0), max_col)

    def zone_phase(self, z, st):
        return min(max(st[2] / self.zone_cycle(z, st), 0.0), 1.0)

    def zone_key(self, z, st):
        started, cycles, t, _ = st
        if z["stages"]:
            c = self.zone_stage(z, st)
        elif z["loop"]:
            c = cycles % (len(z["tempo"]) * z["cycles_per_step"])
        else:
            c = min(cycles, (len(z["tempo"]) - 1) * z["cycles_per_step"])
        return (started, c, int(t / PHASE_BIN))

    def zone_beat(self, zid, st):
        """Fase del metronomo para el camino exportado (wait_beat)."""
        z = self.m.zones[zid]
        out = {"rhythm": zid, "cycle": st[1], "cycle_time_s": round(st[2], 3),
               "beat_phase": round(self.zone_phase(z, st), 4), "cycle_s": round(self.zone_cycle(z, st), 3)}
        if z["stages"]:
            out["stage"] = self.zone_stage(z, st)
        return out

    def banner_rect(self, b, tw):
        t = (tw + b["phase"]) % b["interval"]
        if t < b["rest"] + b["warn"]:
            return None
        progress = min(max((t - b["rest"] - b["warn"]) * b["speed"], 0.0), max(b["corridor"] - b["bw"], 0.0))
        cx = b["entry"] + b["dir"] * (b["bw"] * 0.5 + progress)
        return (cx - b["dw"] * 0.5, b["bottom"] - b["dh"], cx + b["dw"] * 0.5, b["bottom"])

    def hazard_rect(self, h, tw, zs):
        """Zona de dano activa de un banner o una campana (None si no dana) con el reloj del nivel tw y los
        metronomos zs ({id: estado})."""
        if h["kind"] == "banner":
            if not h["rhythm"]:
                return self.banner_rect(h, tw)
            z = self.m.zones[h["rhythm"]]
            st = zs.get(h["rhythm"])
            if st is None:
                return None  # fuera de la zona de la busqueda
            cycle = self.zone_cycle(z, st)
            interval = max(cycle, h["warn"] + h["sweep"] + 0.01)
            t = ((self.zone_phase(z, st) - h["rhythm_offset"]) % 1.0) * cycle
            rest = interval - h["warn"] - h["sweep"]
            if t < rest + h["warn"]:
                return None
            progress = min(max((t - rest - h["warn"]) * h["speed"], 0.0), max(h["corridor"] - h["bw"], 0.0))
            cx = h["entry"] + h["dir"] * (h["bw"] * 0.5 + progress)
            return (cx - h["dw"] * 0.5, h["bottom"] - h["dh"], cx + h["dw"] * 0.5, h["bottom"])
        if h["rhythm"]:
            z = self.m.zones[h["rhythm"]]
            st = zs.get(h["rhythm"])
            if st is None or not st[0]:
                return None
            t = ((self.zone_phase(z, st) - h["offset"]) % 1.0) * self.zone_cycle(z, st)
        else:
            t = (tw + h["phase"]) % h["interval"]
        if h["warn"] <= t < h["warn"] + h["wave"]:
            return h["band"]
        return None

    def blink_on(self, bl, zs):
        st = zs.get(bl["rhythm"])
        if st is None:
            return True  # fuera de la zona de la busqueda
        z = self.m.zones[bl["rhythm"]]
        return ((self.zone_phase(z, st) - bl["offset"]) % 1.0) < bl["on_fraction"]

    def sample_unsafe(self, x, feet, inv, tw, zs, hz, margin=0.0):
        """Id de la amenaza que alcanza a Isak en este cuadro (None si nada): banners y ondas (salvo
        invulnerable por el dash) y plataformas que parpadean apagadas que pisa o toca. Con `margin` (s,
        validation.hazard_margin_s) tambien con las amenazas adelantadas o retrasadas hasta ese margen y con la
        caja de Isak ensanchada en x lo que anda en ese tiempo frente a banners y ondas (margin * walk_speed: el
        bot no esta en el mismo sitio al mismo tiempo que el camino, p. ej. sigue andando los cuadros del
        despegue); las plataformas que parpadean solo con el margen de tiempo (son apoyo, no dano)."""
        hr = self.hurt_rect(x, feet)
        if not inv:
            hp = hr
            if margin > 0.0:
                pad = margin * self.rules.walk_speed
                hp = (hr[0] - pad, hr[1], hr[2] + pad, hr[3])
            for h in hz["timed"]:
                band = h["band"]
                if not (hp[0] < band[2] and hp[2] > band[0] and hp[1] < band[3] and hp[3] > band[1]):
                    continue  # la zona de dano nunca sale de su franja
                if h["kind"] in FEED_KINDS:
                    if self.feed_hits(h, tw, zs, hp if margin > 0.0 else hr, margin):
                        return h["id"]
                    continue
                if margin > 0.0:
                    if self.hazard_hits_window(h, tw, zs, hp, margin):
                        return h["id"]
                    continue
                rect = self.hazard_rect(h, tw, zs)
                if rect is not None and rects_overlap(hr, rect):
                    return h["id"]
        if hz["blinks"]:
            near = (hr[0] - 1.0, hr[1] - 1.0, hr[2] + 1.0, hr[3] + 1.0)
            for bl in hz["blinks"]:
                if not rects_overlap(near, bl["rect"]):
                    continue
                if margin > 0.0:
                    if not self.blink_on_window(bl, zs, margin):
                        return bl["id"]
                elif not self.blink_on(bl, zs):
                    return bl["id"]
        return None

    def margin_offsets(self, margin):
        n = int(round(margin / DT))
        return [k * DT for k in range(-n, n + 1)]

    def hazard_clock(self, h, tw, zs):
        """Reloj propio de un banner o una campana: (segundos de su ciclo, ciclo) o None si no esta en marcha.
        Con ritmo, el ciclo del metronomo en su estado actual (el margen no cambia de etapa)."""
        if h["rhythm"]:
            st = zs.get(h["rhythm"])
            if st is None or (h["kind"] != "banner" and not st[0]):
                return None
            z = self.m.zones[h["rhythm"]]
            cycle = self.zone_cycle(z, st)
            off = h["rhythm_offset"] if h["kind"] == "banner" else h["offset"]
            return ((self.zone_phase(z, st) - off) % 1.0) * cycle, cycle
        return (tw + h["phase"]) % h["interval"], h["interval"]

    def hazard_rect_at(self, h, t, cycle):
        """Zona de dano de `h` a los `t` s de su ciclo (hazard_rect con el reloj ya calculado)."""
        if h["kind"] == "banner":
            interval = max(cycle, h["warn"] + h["sweep"] + 0.01) if h["rhythm"] else h["interval"]
            rest = interval - h["warn"] - h["sweep"]
            if t < rest + h["warn"]:
                return None
            progress = min(max((t - rest - h["warn"]) * h["speed"], 0.0), max(h["corridor"] - h["bw"], 0.0))
            cx = h["entry"] + h["dir"] * (h["bw"] * 0.5 + progress)
            return (cx - h["dw"] * 0.5, h["bottom"] - h["dh"], cx + h["dw"] * 0.5, h["bottom"])
        if h["warn"] <= t < h["warn"] + h["wave"]:
            return h["band"]
        return None

    def hazard_hits_window(self, h, tw, zs, hr, margin):
        """La zona de dano de `h` toca la caja `hr` en algun momento de [tw - margin, tw + margin] (cuadro a
        cuadro, con el reloj de la amenaza desplazado)."""
        clock = self.hazard_clock(h, tw, zs)
        if clock is None:
            return False
        t, cycle = clock
        for d in self.margin_offsets(margin):
            rect = self.hazard_rect_at(h, (t + d) % cycle, cycle)
            if rect is not None and rects_overlap(hr, rect):
                return True
        return False

    def blink_on_window(self, bl, zs, margin):
        """La plataforma esta encendida en todo [t - margin, t + margin] (fuera de la busqueda, siempre)."""
        st = zs.get(bl["rhythm"])
        if st is None:
            return True
        z = self.m.zones[bl["rhythm"]]
        cycle = self.zone_cycle(z, st)
        ph = self.zone_phase(z, st) - bl["offset"]
        return all(((ph + d / cycle) % 1.0) < bl["on_fraction"] for d in self.margin_offsets(margin))

    def exposed(self, x, feet, hz):
        return bool(self.exposed_ids(x, feet, hz))

    def exposed_ids(self, x, feet, hz):
        """Amenazas cuya franja (pasillo del banner, columna de la onda, tarjeta de la plataforma) toca a Isak."""
        rect = self.hurt_rect(x, feet)
        out = [h["id"] for h in hz["timed"] if rects_overlap(rect, h["band"])]
        if hz["blinks"]:
            near = (rect[0] - 1.0, rect[1] - 1.0, rect[2] + 1.0, rect[3] + 1.0)
            out += [bl["id"] for bl in hz["blinks"] if rects_overlap(near, bl["rect"])]
        return out

    def zone_states_after(self, steps, zids):
        """Estado de los metronomos `zids` al final de `steps` (desde el principio del nivel) y, de cada uno,
        el indice del paso en que arranco (None si no). Usa la linea de tiempo (el Debug ralentiza)."""
        zs = {zid: self.zone_init(self.m.zones[zid]) for zid in zids}
        started_at = {zid: (0 if zs[zid][0] else None) for zid in zids}
        if not zids:
            return zs, started_at
        self.timeline(steps)
        for i, s in enumerate(steps):
            smp = self.samples(s)
            if not smp:
                continue
            d = self.duration(s) * (self.rules.debug_world_scale if s.get("debug_active") else 1.0)
            step = d / len(smp)
            for x, f, _ in smp:
                for zid in zids:
                    before = zs[zid][0]
                    zs[zid] = self.zone_step(self.m.zones[zid], zs[zid], x, f, step)
                    if zs[zid][0] and not before:
                        started_at[zid] = i
        return zs, started_at

    def dash_cooldown_after(self, steps):
        """Enfriamiento del dash que queda al final de `steps` (s)."""
        total = self.timeline(steps)[0] if steps else 0.0
        last_end = None
        for s in steps:
            fr = self.dash_frames(s)
            if fr[1] > fr[0]:
                smp = self.samples(s)
                last_end = s["t"] + fr[1] * self.duration(s) / max(len(smp), 1)
        if last_end is None:
            return 0.0
        return max(0.0, self.rules.dash_cooldown_s - (total - last_end))

    def check_banners(self, steps):
        hz = self.hazards()
        banners = hz["banners"]
        self.info["banners"] = []
        required = [str(b) for b in self.val.get("dash_required", [])]
        self._dash_required_seen = set()
        if not hz["all"]:
            self.check_dash_required_missing(required)
            return steps
        level = hz["level"]
        if hz["legacy"]:
            period = banners[0]["interval"]
            if any(abs(b["interval"] - period) > EPS for b in banners):
                period = min(12.0, max(b["interval"] for b in banners) * len(banners))
        else:
            period = level[0]["interval"] if level else 1.0
            if level and any(abs(b["interval"] - period) > EPS for b in level):
                period = min(12.0, max(b["interval"] for b in level) * len(level))
        if not hz["legacy"]:
            steps = self.apply_dash_cooldowns(steps)
        exposure = [set(i for x, f, _ in self.samples(s) for i in self.exposed_ids(x, f, hz)) for s in steps]
        idx = [k for k, ids in enumerate(exposure) if ids]
        if not idx:
            self.check_dash_required_missing(required)
            return steps
        # Tramos expuestos (separados por mas de 4 pasos seguros).
        regions = []
        for k in idx:
            if regions and k - regions[-1][1] <= 4:
                regions[-1][1] = k
            else:
                regions.append([k, k])
        moves = [k for k, s in enumerate(steps) if s["action"] == "move"]
        out = []
        cursor = 0
        for a, b in regions:
            if a < cursor:
                continue
            # Entrada: ultima celda de pie segura antes del tramo.
            entry_idx = None
            for k in reversed([m for m in moves if m < a]):
                x, f = self.feet(steps[k]["to"])
                if not self.exposed(x, f, hz):
                    entry_idx = k
                    break
            entry = tuple(steps[entry_idx]["to"]) if entry_idx is not None else tuple(self.v.result["start"])
            first = entry_idx + 1 if entry_idx is not None else 0
            # Salida: primera celda de pie segura despues del tramo (o la ultima del camino).
            exit_idx = None
            for k in [m for m in moves if m >= b]:
                x, f = self.feet(steps[k]["to"])
                if not self.exposed(x, f, hz):
                    exit_idx = k
                    break
            dwell = 0.0
            if exit_idx is None:
                exit_idx = moves[-1] if moves[-1] >= first else first
                if any(st.get("final") for st in steps[exit_idx + 1:]):
                    dwell = self.rules.pulse_pose_s + 0.1
            exit_node = tuple(steps[exit_idx]["to"])
            state = steps[exit_idx]["state"]
            if hz["legacy"]:
                ctx = {"free": True, "tw0": 0.0, "zones": {}, "cd": 0.0, "dash": False, "walk_speed": None,
                       "bounds": banners, "level": bool(banners), "margin": self.hazard_margin}
                involved = [bn["id"] for bn in banners]
            else:
                ids = set()
                for k in range(first, exit_idx + 1):
                    ids |= exposure[k]
                involved = list(dict.fromkeys(h["id"] for h in hz["all"] if h["id"] in ids))
                inv_h = [h for h in hz["all"] if h["id"] in ids]
                # Metronomos de las amenazas que caen en la zona de la busqueda (la de hazard_search).
                box = self.search_box(entry, exit_node, inv_h)
                near = [h for h in hz["all"] if rects_overlap(h["band"], box)]
                zids = sorted({h["rhythm"] for h in near if h["rhythm"]})
                prefix = out + steps[cursor:first]
                self.resolve_phase_waits(prefix, banners)
                zs, started_at = self.zone_states_after(prefix, zids)
                free = not any(st[0] for st in zs.values())
                tw0 = self.timeline(prefix)[1] if prefix else 0.0
                ctx = {"free": free, "tw0": tw0, "zones": zs, "cd": self.dash_cooldown_after(prefix),
                       "dash": True, "walk_speed": None, "bounds": inv_h, "local_period": True,
                       "level": any(not h["rhythm"] for h in inv_h if h["kind"] != "blink"),
                       "margin": self.hazard_margin, "real_arc": True,
                       # Isak llega parado a la entrada (espera de fase o un paso que lo deja quieto).
                       "rest": (free and any(not h["rhythm"] for h in inv_h if h["kind"] != "blink"))
                       or (bool(prefix) and (prefix[-1]["action"] in REST_ACTIONS
                                             or (prefix[-1]["action"] == "move" and prefix[-1]["kind"] != "walk")))}
                # Del arranque del metronomo a la entrada no se interrumpe (desvios a un cargador).
                for zid in zids:
                    if started_at.get(zid) is not None:
                        for st in prefix[started_at[zid]:]:
                            st.setdefault("timed", "rhythm:" + zid)
            plan = self.hazard_search(entry, exit_node, state, hz, period, dwell, ctx)
            item = {"banners": [bn["id"] for bn in banners] if hz["legacy"] else
                    [i for i in involved if any(bn["id"] == i for bn in banners)],
                    "entry": [entry[1], entry[0]], "exit": [exit_node[1], exit_node[0]], "period_s": round(period, 3)}
            if not hz["legacy"]:
                item.update({"bells": [i for i in involved if any(h["id"] == i for h in hz["bells"])],
                             "blinks": [i for i in involved if any(h["id"] == i for h in hz["blinks"])],
                             "rhythm": sorted(ctx["zones"]), "phase_free": ctx["free"] and ctx["level"]})
                if hz["feed"]:
                    item["banners"] = [i for i in item["banners"] if not any(h["id"] == i for h in hz["feed"])]
                    item["feed"] = [i for i in involved if any(h["id"] == i for h in hz["feed"])]
            self.info["banners"].append(item)
            out.extend(steps[cursor:first])
            if plan is None:
                names = ", ".join(involved) if not hz["legacy"] else ", ".join(bn["id"] for bn in banners)
                what = "banners" if hz["legacy"] else "amenazas con tiempo"
                self.error("%s %s: no hay forma de cruzar su %s sin dano entre (fila %d, columna %d) y "
                           "(fila %d, columna %d) (esperas en sitios seguros y saltos en el sitio%s)" % (
                               what, names, "pasillo" if hz["legacy"] else "tramo", entry[1], entry[0],
                               exit_node[1], exit_node[0],
                               "" if hz["legacy"] else (", dash" if self.m.dash_possible else "")),
                           entry)
                if not hz["legacy"]:
                    self.check_dash_required(required, involved, None, entry, exit_node, state, hz, period, dwell,
                                             ctx, item)
                out.extend(steps[first:exit_idx + 1])
                cursor = exit_idx + 1
                continue
            if not hz["legacy"]:
                # Periodo de la fase de esta busqueda (el de sus amenazas del reloj del nivel; paso 10 del 1-3).
                rp = plan.get("period", period)
                item["period_s"] = round(rp, 3)
            else:
                rp = period
            item.update({"crossing_s": round(plan["time"], 2),
                         "waits": sum(1 for st in plan["steps"] if st["action"] in ("wait", "wait_beat")),
                         "hops": sum(1 for st in plan["steps"] if st["action"] == "hop")})
            if hz["legacy"] or (ctx["free"] and ctx["level"]):
                item["start_phase_s"] = round(plan["phase"], 3)
                # Orden de las claves como antes del paso 9 (la salida JSON del 1-2 no cambia).
                item = {k: item[k] for k in ("banners", "entry", "exit", "period_s", "start_phase_s", "crossing_s",
                                             "waits", "hops") if k in item} | {k: v for k, v in item.items()}
                self.info["banners"][-1] = item
            if not hz["legacy"]:
                item["dashes"] = sum(1 for st in plan["steps"] if st["action"] == "move" and st["edge"].get("dash"))
            for st in plan["steps"]:
                st.setdefault("state", state)
                if not hz["legacy"]:
                    st["timed"] = "hazard"
            if hz["legacy"] or (ctx["free"] and ctx["level"]):
                level_h = banners if hz["legacy"] else [h for h in hz["level"] if h["id"] in involved]
                sync = {"action": "wait_phase", "at": entry, "state": state, "period_s": rp,
                        "phase_s": plan["phase"], "hazards": list(dict.fromkeys(bn["id"] for bn in level_h)),
                        "banner_cycle_s": {bn["id"]: round((plan["phase"] + bn["phase"]) % bn["interval"], 3)
                                           for bn in level_h if bn["kind"] == "banner" and not bn.get("feed")}}
                clips = {h["id"]: round(((plan["phase"] + h["phase"]) % h["interval"] - h.get("clip_shift", 0.0))
                                        % h["interval"], 3) for h in level_h if h.get("feed")}
                if clips:
                    sync["clip_cycle_s"] = clips
                bells = {bl["id"]: round((plan["phase"] + bl["phase"]) % bl["interval"], 3)
                         for bl in level_h if bl["kind"] == "bell"}
                if bells:
                    sync["bell_cycle_s"] = bells
                if not hz["legacy"]:
                    sync["timed"] = "hazard"
                out.append(sync)
            span = steps[first:exit_idx + 1]
            if any(st["action"] == "debug_on" for st in span):
                # El tramo con tiempo rehace los movimientos y el Debug se encendia dentro (2-1, 2026-10-22:
                # la salida del bucle empieza al alcance de los proyectiles de la cuenta): se vuelve a encender
                # justo antes del primer movimiento con el Debug de la busqueda (y se apaga tras el ultimo si
                # el tramo tambien lo apagaba).
                k0 = next((i for i, st in enumerate(plan["steps"]) if st.get("debug")), None)
                if k0 is not None:
                    on = next(st for st in span if st["action"] == "debug_on")
                    plan["steps"].insert(k0, dict(on, at=plan["steps"][k0]["from"], state=state, timed="hazard"))
                    if any(st["action"] == "debug_off" for st in span):
                        k1 = max(i for i, st in enumerate(plan["steps"]) if st.get("debug"))
                        off = next(st for st in span if st["action"] == "debug_off")
                        plan["steps"].insert(k1 + 1, dict(off, at=plan["steps"][k1]["to"], state=state,
                                                          timed="hazard"))
            out.extend(plan["steps"])
            if not hz["legacy"]:
                self.check_dash_required(required, involved, plan, entry, exit_node, state, hz, rp, dwell, ctx,
                                         item)
            # Lo que no es movimiento dentro del tramo (recogidas, cargadores) se conserva al final.
            out.extend(st for st in steps[first:exit_idx + 1] if st["action"] in ("pickup", "charge"))
            cursor = exit_idx + 1
        out.extend(steps[cursor:])
        self.resolve_phase_waits(out, banners)
        if not hz["legacy"]:
            out = self.apply_dash_cooldowns(out)
            self.resolve_phase_waits(out, banners)
        self.check_dash_required_missing(required)
        return out

    # --- Dash: enfriamiento y banner obligatorio (paso 9 de docs/propuesta-1-3.md) ---

    def apply_dash_cooldowns(self, steps):
        """Entre el final de un dash y el siguiente tiene que pasar dash_cooldown_s: si no, espera de pie
        antes del segundo (salvo dentro de un tramo con tiempo, que ya lo respeta la busqueda)."""
        cool = self.rules.dash_cooldown_s
        for _ in range(64):
            self.timeline(steps)
            last_end = None
            fixed = False
            for i, s in enumerate(steps):
                fr = self.dash_frames(s)
                if fr[1] <= fr[0]:
                    continue
                per = self.duration(s) / max(len(self.samples(s)), 1)
                start = s["t"] + fr[0] * per
                if last_end is not None and start < last_end + cool - EPS and not s.get("timed"):
                    wait = last_end + cool - start
                    steps = steps[:i] + [{"action": "wait", "at": s["from"], "seconds": wait, "state": s["state"],
                                          "reason": "enfriamiento del dash"}] + steps[i:]
                    fixed = True
                    break
                last_end = s["t"] + fr[1] * per
            if not fixed:
                break
        return steps

    def check_dash_required_missing(self, required):
        for bid in required:
            if bid not in self._dash_required_seen:
                self.error("banner %s (validation.dash_required): el camino no cruza su pasillo" % bid, None, bid)

    def check_dash_required(self, required, involved, plan, entry, exit_node, state, hz, period, dwell, ctx, item):
        """validation.dash_required: sin el dash (andando ni corriendo) no hay cruce sin dano del pasillo del
        banner y con el dash si, con una ventana para lanzarlo de al menos DASH_WINDOW_MIN_S."""
        mine = [bid for bid in required if bid in involved]
        if not mine:
            return
        self._dash_required_seen.update(mine)
        report = {}
        # Sin el dash, sin holgura de tiempo: el pasillo no se cruza ni con la sincronizacion exacta.
        walk = self.hazard_search(entry, exit_node, state, hz, period, dwell, dict(ctx, dash=False, margin=0.0))
        run = None
        if walk is None:
            run = self.hazard_search(entry, exit_node, state, hz, period, dwell,
                                     dict(ctx, dash=False, margin=0.0, walk_speed=self.rules.run_speed))
        window = None
        if plan is not None:
            window = self.dash_window(plan, ctx, hz, period, mine)
        for bid in mine:
            report[bid] = {"without_dash_walking": walk is not None, "without_dash_running": run is not None,
                           "with_dash": plan is not None,
                           "dash_window_s": None if window is None else round(window, 3)}
            if walk is not None or run is not None:
                self.error("banner %s: su pasillo se cruza SIN el dash (%s) y el diseno lo exige "
                           "(validation.dash_required)" % (bid, "andando" if walk is not None else "corriendo"),
                           entry, bid)
            elif plan is not None and (window is None or window < DASH_WINDOW_MIN_S - EPS):
                self.error("banner %s: con el dash se cruza, pero la ventana para lanzarlo es de %.2f s (minimo %.2f s)"
                           % (bid, window or 0.0, DASH_WINDOW_MIN_S), entry, bid)
        item["dash_required"] = report

    def dash_window(self, plan, ctx, hz, period, bids):
        """Ventana del dash que cruza el banner (s): el intervalo de adelantos y retrasos del momento en que se
        lanza con el que el encuentro con el banner sigue sin dano (Isak quieto donde sale hasta lanzarlo; si
        lo lanza antes, quieto donde cae hasta la hora del plan). Mide la precision que pide el dash, no la
        holgura del resto del cruce (esa la da la busqueda)."""
        steps = plan["steps"]
        bands = [h["band"] for h in hz["timed"] if h["id"] in bids]
        # Linea de tiempo del cruce: tiempo, reloj del nivel y metronomos al empezar cada paso.
        t = 0.0
        zs = dict(ctx["zones"])
        phase0 = plan["phase"] if (ctx["free"] and ctx["level"]) else (ctx["tw0"] % period if ctx["level"] else 0.0)
        starts = []
        target = None
        for j, s in enumerate(steps):
            smp = self.samples(s)
            d = self.duration(s)
            starts.append((t, dict(zs)))
            fr = self.dash_frames(s)
            if target is None and fr[1] > fr[0]:
                for x, f, _ in smp[fr[0]:fr[1]]:
                    hr = self.hurt_rect(x, f)
                    if any(rects_overlap(hr, band) for band in bands):
                        target = j
                        break
            step = d / max(len(smp), 1)
            for x, f, _ in smp:
                for zid in zs:
                    zs[zid] = self.zone_step(self.m.zones[zid], zs[zid], x, f, step)
            t += d
        if target is None:
            return None
        t_d, zs_d = starts[target]
        u = steps[target]["from"]

        def safe(delta):
            zs1 = {zid: self.zone_shift(self.m.zones[zid], st, delta) for zid, st in zs_d.items()}
            tw = phase0 + t_d + delta
            if delta > 0.0:
                # Quieto donde sale el dash hasta lanzarlo.
                x, f = self.feet(u)
                n = int(round(delta / DT))
                zs0 = dict(zs_d)
                for k in range(n):
                    zs0 = {zid: self.zone_step(self.m.zones[zid], st, x, f, DT) for zid, st in zs0.items()}
                    if self.sample_unsafe(x, f, False, phase0 + t_d + (k + 1) * DT, zs0, hz):
                        return False
                zs1 = zs0
            s = steps[target]
            smp = self.samples(s)
            d = self.duration(s)
            step = d / max(len(smp), 1)
            inv = self.invulnerable_range(s)
            for k, (x, f, _) in enumerate(smp):
                zs1 = {zid: self.zone_step(self.m.zones[zid], st, x, f, step) for zid, st in zs1.items()}
                if self.sample_unsafe(x, f, inv[0] <= k < inv[1], tw + (k + 1) * step, zs1, hz):
                    return False
            tw += d
            if delta < 0.0:
                # Lanzado antes: espera donde cae hasta la hora del plan (el resto del cruce no cambia).
                x, f = self.feet(s["to"])
                for k in range(int(round(-delta / DT))):
                    zs1 = {zid: self.zone_step(self.m.zones[zid], st, x, f, DT) for zid, st in zs1.items()}
                    if self.sample_unsafe(x, f, False, tw + (k + 1) * DT, zs1, hz):
                        return False
            return True

        if not safe(0.0):
            return 0.0
        lo = hi = 0.0
        k = 1
        while k * DT <= DASH_WINDOW_SCAN_S and safe(k * DT):
            hi = k * DT
            k += 1
        k = 1
        while k * DT <= DASH_WINDOW_SCAN_S and safe(-k * DT):
            lo = -k * DT
            k += 1
        return hi - lo + DT

    def resolve_phase_waits(self, steps, banners):
        """Segundos de cada espera de fase segun el tiempo del mundo al llegar (el plan concreto)."""
        for s in steps:
            if s["action"] == "wait_phase":
                s["seconds"] = 0.0
        self.timeline(steps)
        for s in steps:
            if s["action"] == "wait_phase":
                s["seconds"] = (s["phase_s"] - s["tw"]) % s["period_s"]
                self.timeline(steps)

    def hop(self, node, state, real=False):
        """Salto en el sitio (para dejar pasar un banner por debajo); `real`: con el arco real del juego."""
        x, feet = self.feet(node)
        info = {"want_traj": True}
        w = self.m.world(state, False)
        if real:
            to, _ = w.simulate(x, feet, -self.rules.jump_v0_game, 0.0, x, info=info, game=True)
        else:
            to, _ = w.simulate(x, feet, -self.rules.jump_v0, 0.0, x, info=info)
        if to != node:
            return None
        traj = [(px, py, True) for px, py in info["traj"]]
        return {"action": "hop", "at": node, "time": len(traj) * DT + 0.06,
                "traj": traj + [(x, feet, False)] * int(round(0.06 / DT))}

    def search_box(self, entry, exit_node, bounds):
        """Rectangulo (px) que cubre la zona de la busqueda por tiempo (celdas de pie y el cuerpo de Isak)."""
        T = self.T
        cols = [int(b["band"][0] // T) for b in bounds] + [int(b["band"][2] // T) for b in bounds]
        rows = [int(b["bottom"] // T) for b in bounds]
        c_lo = min(cols + [entry[0], exit_node[0]]) - HAZARD_PAD
        c_hi = max(cols + [entry[0], exit_node[0]]) + HAZARD_PAD
        r_lo = min(rows + [entry[1], exit_node[1]]) - HAZARD_PAD
        r_hi = max(rows + [entry[1], exit_node[1]]) + 1
        return (c_lo * T, (r_lo - 1) * T, (c_hi + 1) * T, (r_hi + 1) * T)

    def hazard_search(self, entry, exit_node, state, hz, period, dwell, ctx=None):
        """Dijkstra por (celda, fase) en la zona de las amenazas con tiempo: andar, saltar, esperar en una
        celda segura, saltar en el sitio y (paso 9) deslizar con el dash, sin tocar ningun banner en barrido,
        ninguna onda de campana ni una plataforma que parpadea apagada.

        Cada movimiento dura lo mismo que en la linea de tiempo del camino (edge_time: andar una celda a
        walk_speed, 64 / 220 = 0,29 s, no los 17 cuadros redondeados de sus muestras) y la fase de cada
        estado es la exacta de su cadena (fase de entrada + tiempo acumulado); la celda de fase
        (PHASE_BIN) solo agrupa estados. Hasta el 2026-10-19 la fase se redondeaba en cada paso y se
        quedaba atras 1/60 s por celda andada: un pasillo largo andando (banner_2 del 1-2, 16 tiles,
        4,7 s con un ciclo de 3 s) salia seguro y el barrido siguiente alcanzaba a Isak.

        ctx (paso 9): "free" (fase del reloj del nivel libre: el bot espera en la entrada) o "tw0" (reloj
        del nivel exacto en la entrada), "zones" (estado exacto de cada metronomo en la entrada; forma
        parte del estado de la busqueda), "cd" (enfriamiento del dash en la entrada), "dash" (se puede usar),
        "walk_speed" (andar a otra velocidad: corriendo) y "bounds" (amenazas que delimitan la zona)."""
        T = self.T
        if ctx is None:
            ctx = {"free": True, "tw0": 0.0, "zones": {}, "cd": 0.0, "dash": False, "walk_speed": None,
                   "bounds": hz["banners"], "level": True}
        level = ctx["level"]
        bounds = ctx["bounds"]
        # 2026-10-20 (bot del 1-3): holgura de tiempo frente a las amenazas (validation.hazard_margin_s) y
        # saltos con el arco real del juego (ctx["real_arc"]; los banners del 1-2 siguen con el conservador).
        margin = float(ctx.get("margin", 0.0))
        pad = margin * self.rules.walk_speed
        real_arc = bool(ctx.get("real_arc"))
        cols = [int(b["band"][0] // T) for b in bounds] + [int(b["band"][2] // T) for b in bounds]
        rows = [int(b["bottom"] // T) for b in bounds]
        c_lo = min(cols + [entry[0], exit_node[0]]) - HAZARD_PAD
        c_hi = max(cols + [entry[0], exit_node[0]]) + HAZARD_PAD
        r_lo = min(rows + [entry[1], exit_node[1]]) - HAZARD_PAD
        r_hi = max(rows + [entry[1], exit_node[1]]) + 1
        region = lambda n: c_lo <= n[0] <= c_hi and r_lo <= n[1] <= r_hi
        # Paso 10 del 1-3 (2026-10-20). (1) Cada movimiento, espera o salto en el sitio solo mira las amenazas
        # cuya franja toca la caja de sus muestras (`local`): las demas no pueden darle, asi que el resultado no
        # cambia (el 1-3 tiene 16 amenazas con tiempo en 260 columnas y cada muestra las recorria todas).
        # (2) Con ctx["local_period"], el periodo de la fase sale de las amenazas del reloj del nivel cercanas
        # a la zona (SEARCH_REACH_*), no de todas las del nivel: con un solo intervalo es exacto y hay muchas
        # menos fases (1-3: banners de 3 s y de 2,5 s en pasillos distintos; con el de todo el nivel, 12 s).
        # Si algun movimiento llegara a tocar otra amenaza del reloj del nivel, la busqueda se repite con el
        # periodo de siempre (nunca se acepta un cruce con una fase mal calculada).
        period_in = period
        period_ids = None
        if ctx.get("local_period") and level:
            rx, ry = SEARCH_REACH_X_TILES * T, SEARCH_REACH_Y_TILES * T
            near_box = (c_lo * T - rx, r_lo * T - ry, (c_hi + 1) * T + rx, (r_hi + 1) * T + ry)
            lvl = [h for h in hz["timed"] if not h["rhythm"] and rects_overlap(h["band"], near_box)]
            if lvl:
                period = lvl[0]["interval"]
                if any(abs(h["interval"] - period) > EPS for h in lvl):
                    period = min(12.0, max(h["interval"] for h in lvl) * len(lvl))
                period_ids = {h["id"] for h in lvl}
        outside = [False]
        hw, hh = self.m.hw, self.m.hh

        def local(samples):
            """Amenazas que pueden tocar alguna de estas muestras (la misma prueba que sample_unsafe)."""
            if not samples:
                return {"timed": [], "blinks": []}
            xs = [smp[0] for smp in samples]
            fs = [smp[1] for smp in samples]
            box = (min(xs) - hw - 1.0, min(fs) - hh - 1.0, max(xs) + hw + 1.0, max(fs) + 1.0)
            near = (box[0] - 1.0, box[1] - 1.0, box[2] + 1.0, box[3] + 1.0)
            # Con la holgura, la caja ensanchada de sample_unsafe (margin * walk_speed en x).
            wide = (box[0] - pad, box[1], box[2] + pad, box[3]) if pad > 0.0 else box
            timed = [h for h in hz["timed"] if rects_overlap(h["band"], wide)]
            if period_ids is not None and any(not h["rhythm"] and h["id"] not in period_ids for h in timed):
                outside[0] = True
            return {"timed": timed, "blinks": [bl for bl in hz["blinks"] if rects_overlap(bl["rect"], near)]}

        bins = max(1, int(round(period / PHASE_BIN))) if level else 1
        zids = sorted(ctx["zones"])
        zones = [self.m.zones[zid] for zid in zids]
        cool = self.rules.dash_cooldown_s
        walk_speed = ctx.get("walk_speed")

        # Rayos de los videos (paso 9b): la columna de Isak al empezar el clip viaja con cada estado de la busqueda
        # (en zs, sin formar parte de la clave: con ella los estados se multiplicaban por las columnas; asi gana
        # el que llega antes, y lo que se acepta siempre se ha comprobado con su propia columna).
        rays = [h for h in hz["timed"] if h["kind"] == "ray"]

        def zkey(zs):
            return tuple(self.zone_key(z, zs[zid]) for zid, z in zip(zids, zones))

        def cd_bin(cd):
            return int(math.ceil(cd / DASH_COOLDOWN_BIN - EPS)) if cd > EPS else 0

        def run(samples, phase_t, zs, step=DT, inv=(0, 0), zstep=None, hl=None):
            """Recorre las muestras; devuelve el estado de los metronomos al final o None si algo le da."""
            zstep = step if zstep is None else zstep
            hl = local(samples) if hl is None else hl
            check = bool(hl["timed"] or hl["blinks"])
            if rays:
                zs = dict(zs)
                ray_clock = [(h, ("ray", h["id"]), (phase_t + h["phase"]) % h["interval"]) for h in rays]
            for k, (x, f, _) in enumerate(samples):
                tw = phase_t + (k + 1) * step
                if zids:
                    zs = dict(zs)
                    for zid, z in zip(zids, zones):
                        zs[zid] = self.zone_step(z, zs[zid], x, f, zstep)
                if rays:
                    # ray_note, en linea (es de lo que mas se repite en la busqueda).
                    for h, rkey, c0 in ray_clock:
                        iv = h["interval"]
                        a = c0 + k * step
                        if (a + step) // iv != a // iv:
                            zs[rkey] = int(x // T) if self.in_view(h["view"], x, f) else -1
                        elif zs.get(rkey) != -1 and (a + step) % iv >= h["warn"] + h["wave"]:
                            zs[rkey] = -1
                if check and self.sample_unsafe(x, f, inv[0] <= k < inv[1], tw, zs, hl, margin):
                    return None
            return zs

        sample_cache = {}

        def edge_samples(u, e, rest=False):
            """Muestras del movimiento, su duracion real (la de la linea de tiempo), cuadros invulnerables y
            cuadros del dash. `rest`: Isak empieza parado (con el arco real)."""
            key = (u, e["to"], e["kind"], e["x0"], e.get("xt"), id(e) if e.get("dash") else None, rest)
            if key not in sample_cache:
                mv = self.move(u, e, state)
                if walk_speed is not None:
                    mv["walk_speed"] = walk_speed
                if real_arc:
                    mv["arc"] = "real"
                    if rest:
                        mv["from_rest"] = True
                if self.rest_jump_fails(mv):
                    sample_cache[key] = (None, 0.0, (0, 0), (0, 0), None)
                    return sample_cache[key]
                smp = self.samples(mv)
                sample_cache[key] = (smp, self.duration(mv), self.invulnerable_range(mv), self.dash_frames(mv),
                                     local(smp) if smp else {"timed": [], "blinks": []})
            return sample_cache[key]

        hop_cache = {}
        hop_local = {}
        heap = []
        best = {}
        parent = {}
        data = {}  # clave -> (t, fase de entrada, metronomos, enfriamiento, dashes)
        zs0 = dict(ctx["zones"])
        if rays:
            ex, ef = self.feet(entry)
            for h in rays:
                zs0[("ray", h["id"])] = int(math.floor(ex / T)) if self.in_view(h["view"], ex, ef) else -1
        cd0 = float(ctx.get("cd", 0.0))
        # Con el arco real, el estado lleva si Isak esta parado (tras una espera o un salto en el sitio): el
        # siguiente movimiento arranca acelerando (rest_lag). Sin el, siempre False (como antes).
        rest0 = bool(real_arc and ctx.get("rest"))
        if ctx["free"] or not level:
            seeds = [(ph, ph * PHASE_BIN) for ph in range(bins)]
        else:
            phase0 = ctx["tw0"] % period
            seeds = [(int(round(phase0 / PHASE_BIN)) % bins, phase0)]
        for ph, phase0 in seeds:
            key = (entry, ph, zkey(zs0), cd_bin(cd0), rest0)
            best[key] = 0.0
            parent[key] = None
            data[key] = (0.0, phase0, zs0, cd0, 0)
            heap.append((0.0, ph, entry, key[2], key[3], key[4]))
        heapq.heapify(heap)
        static_cache = {}

        def standing(node):
            if node not in static_cache:
                x, f = self.feet(node)
                smp = [(x, f, False)] * max(1, int(round(PHASE_BIN / DT)))
                static_cache[node] = (smp, local(smp))
            return static_cache[node]

        goal = None
        expansions = 0
        while heap:
            cost, ph, node, zk, cdb, rest = heapq.heappop(heap)
            key = (node, ph, zk, cdb, rest)
            if cost > best.get(key, INF) + EPS:
                continue
            expansions += 1
            if expansions > 400000:
                break
            t, phase0, zs, cd, ndash = data[key]
            phase_t = (phase0 + t) % period
            if node == exit_node:
                x, f = self.feet(node)
                if dwell <= 0.0 or run([(x, f, False)] * int(round(dwell / DT)), phase_t, zs) is not None:
                    goal = key
                    break
            # Esperar un paso de fase. Con la holgura (validation.hazard_margin_s), solo fuera de la franja de
            # todo banner y onda: si el bot llega tarde a la espera, espera otro ciclo alli sin que le den.
            cand = []
            smp, shl = standing(node)
            can_wait = margin <= 0.0 or not shl["timed"]
            nzs = run(smp, phase_t, zs, zstep=PHASE_BIN / len(smp), hl=shl) if can_wait else None
            if nzs is not None:
                cand.append((node, PHASE_BIN, {"action": "wait"}, nzs, None))
            if not can_wait:
                pass
            elif node not in hop_cache:
                hop_cache[node] = self.hop(node, state, real_arc)
                hop_local[node] = local(hop_cache[node]["traj"]) if hop_cache[node] is not None else None
            hp = hop_cache.get(node) if can_wait else None
            if hp is not None:
                nzs = run(hp["traj"], phase_t, zs, zstep=hp["time"] / max(len(hp["traj"]), 1), hl=hop_local[node])
                if nzs is not None:
                    cand.append((node, hp["time"], {"action": "hop"}, nzs, None))
            for e in self.m.edges(node, state, "auto"):
                if max(e["h"], e["v"]) > self.rules.limit + EPS or not region(e["to"]):
                    continue
                if e.get("dash") and not ctx["dash"]:
                    continue
                smp, d, inv, dfr, ehl = edge_samples(node, e, rest)
                if smp is None:
                    continue  # salto desde parado que no llega con el arco real
                step = d / max(len(smp), 1)
                if e.get("dash") and cd - dfr[0] * step > EPS:
                    continue  # aun en enfriamiento
                nzs = run(smp, phase_t, zs, step, inv, hl=ehl)
                if nzs is not None:
                    cand.append((e["to"], d, {"action": "move", "e": e}, nzs, (dfr, step) if e.get("dash") else None))
            for to, d, act, nzs, dash in cand:
                nt = t + d
                if dash is not None:
                    dfr, step = dash
                    ncd = max(0.0, cool - (d - dfr[1] * step))
                    ncost = cost + d + DASH_PLAN_COST
                    nd = ndash + 1
                else:
                    ncd = max(0.0, cd - d)
                    ncost = cost + d
                    nd = ndash
                nph = int(round(((phase0 + nt) % period) / PHASE_BIN)) % bins if level else 0
                # El bot frena en el centro de la celda al aterrizar de un salto, una caida o un dash.
                nrest = bool(real_arc and (act["action"] != "move" or act["e"]["kind"] != "walk"))
                nkey = (to, nph, zkey(nzs), cd_bin(ncd), nrest)
                if ncost < best.get(nkey, INF) - EPS:
                    best[nkey] = ncost
                    parent[nkey] = (key, act)
                    data[nkey] = (nt, phase0, nzs, ncd, nd)
                    heapq.heappush(heap, (ncost, nph, to, nkey[2], nkey[3], nrest))
        if outside[0]:
            return self.hazard_search(entry, exit_node, state, hz, period_in, dwell, dict(ctx, local_period=False))
        if goal is None:
            return None
        seq = []
        k = goal
        while parent.get(k) is not None:
            prev, act = parent[k]
            seq.append((prev, act, k))
            k = prev
        seq.reverse()
        start_phase = data[goal][1]
        out = []
        for prev, act, after in seq:
            node = prev[0]
            if act["action"] == "wait":
                zs_after = data[after][2]
                beat = None
                if zids:
                    on = [zid for zid in zids if zs_after[zid][0]]
                    if on:
                        beat = self.zone_beat(on[0], zs_after[on[0]])
                if out and out[-1]["action"] in ("wait", "wait_beat") and out[-1]["at"] == node:
                    out[-1]["seconds"] += PHASE_BIN
                    if beat is not None:
                        out[-1]["action"] = "wait_beat"
                        out[-1]["beat"] = beat
                else:
                    w = {"action": "wait", "at": node, "seconds": PHASE_BIN, "reason": "banner"}
                    if beat is not None:
                        w.update({"action": "wait_beat", "beat": beat, "reason": "compas"})
                    out.append(w)
            elif act["action"] == "hop":
                hp = dict(hop_cache[node])
                out.append(hp)
            else:
                mv = self.move(node, act["e"], state)
                if walk_speed is not None:
                    mv["walk_speed"] = walk_speed
                if real_arc:
                    mv["arc"] = "real"
                    if prev[4]:
                        mv["from_rest"] = True
                out.append(mv)
        # Paso 14 (2-3): un tramo al compas de una Historia sin ninguna espera al compas lleva una de 0 s al empezar,
        # con el compas de su primera Historia, para que el bot sincronice su reloj propio antes de cruzar (si no,
        # sale cuando el techo del scroll se lo permite y llega a la Historia apagada).
        hist = [zid for zid in (zids or []) if str(zid).startswith("_historia_")]
        if hist and seq and not any(st["action"] == "wait_beat" for st in out):
            zs0 = data[seq[0][0]][2]
            on = [zid for zid in hist if zs0[zid][0]]
            if on:
                out.insert(0, {"action": "wait_beat", "at": seq[0][0][0], "seconds": 0.0, "reason": "compas",
                               "beat": self.zone_beat(on[0], zs0[on[0]])})
        return {"phase": start_phase, "time": data[goal][0], "steps": out, "dashes": data[goal][4], "period": period}

    # --- Energia ---

    def check_energy(self, steps):
        return self.check_energy_with(steps, 0)

    def check_energy_with(self, steps, detours):
        """Energia a lo largo del camino; si falta en un paso obligatorio, desvio a un cargador
        (hasta 8) y se repasa desde el principio."""
        r = self.rules
        energy = float(self.val.get("start_energy", r.energy_max))
        cap = r.energy_max
        self.timeline(steps)
        ready_at = {}
        uses = sources = 0.0
        min_energy = energy
        i = 0
        while i < len(steps):
            s = steps[i]
            a = s["action"]
            need = 0.0
            if a == "laser":
                need = r.laser_cost
            elif a == "move" and s["edge"].get("dash"):
                need = r.dash_cost
            elif a == "debug_on":
                k = i + 1
                active = 0.0
                while k < len(steps) and steps[k]["action"] != "debug_off":
                    active += self.duration(steps[k])
                    k += 1
                need = active * self.debug_drain
                s["active_s"] = round(active, 2)
            if need > 0.0 and energy + EPS < need:
                fixed = self.charger_detour(steps, i, need, energy, ready_at) if detours < 8 else None
                if fixed is not None:
                    return self.check_energy_with(fixed, detours + 1)
                self.error("sin energia en el paso %d (%s): quedan %.0f y hacen falta %.0f%s" % (
                    i + 1, self.describe(s), energy, need,
                    "" if need <= cap else " (mas que la barra entera, %.0f)" % cap), s.get("at"))
                energy = max(energy - need, 0.0)
            else:
                energy -= need
            uses += need
            s["energy_before"] = round(energy + need, 1)
            if a == "drain":
                # Peor caso de un bucle (check_loop_energy): Isak entra sin energia.
                energy = 0.0
            if a == "charge":
                ch = s["charger"]
                if s["tw"] + EPS >= ready_at.get(ch["id"], 0.0) and energy < cap - EPS:
                    gain = min(cap - energy, ch["amount"])
                    energy += gain
                    sources += gain
                    ready_at[ch["id"]] = s["tw"] + ch["cooldown"] if ch["reusable"] else INF
            elif a == "pickup" and s.get("refill"):
                sources += cap - energy
                energy = cap
            if s.get("kills"):
                drop = float(self.v.enemy_data("alert_bubble").get("drops", {}).get("debug_energy", 0.0))
                gain = min(cap - energy, drop)
                energy += gain
                sources += gain
            s["energy_after"] = round(energy, 1)
            min_energy = min(min_energy, energy)
            i += 1
        self.info["energy"] = {"start": float(self.val.get("start_energy", r.energy_max)), "max": cap,
                               "used": round(uses, 1), "gained": round(sources, 1), "min": round(min_energy, 1),
                               "end": round(energy, 1), "charger_detours": detours}
        dashes = sum(1 for s in steps if s["action"] == "move" and s["edge"].get("dash"))
        if dashes:
            self.info["energy"]["dashes"] = dashes
        if "debug_drain_scale" in self.level:
            self.info["energy"]["debug_drain_per_s"] = round(self.debug_drain, 2)
        if "debug_world_scale" in self.level:
            self.info["energy"]["debug_world_scale"] = round(self.rules.debug_world_scale, 3)
        return steps

    def charger_detour(self, steps, i, need, energy, ready_at):
        """Inserta, antes del paso i (o antes del tramo con tiempo que lo contiene), ir a un cargador
        alcanzable, cargar (esperando su enfriamiento si hace falta) y volver."""
        if not self.m.chargers:
            return None
        k = i
        # No se interrumpe un tramo con tiempo (acertijo, recordatorios, banners) ni el Debug.
        while k > 0 and (steps[k - 1].get("timed") or steps[k - 1]["action"] in ("wait_phase", "debug_on")
                         or steps[k].get("timed")):
            k -= 1
        while k > 0 and steps[k - 1]["action"] not in ("move",):
            if steps[k - 1]["action"] in ("goal",):
                break
            k -= 1
        node = steps[k - 1]["to"] if k > 0 and steps[k - 1]["action"] == "move" else self.node_of(steps[k])
        if node is None:
            return None
        node = tuple(node)
        state = steps[k].get("state", frozenset())
        times, parent = self.m.time_search({node: 0.0}, state)
        best = None
        for ch in self.m.chargers:
            for n in times:
                x, f = self.feet(n)
                if rects_overlap(self.hurt_rect(x, f), ch["rect"]):
                    if best is None or times[n] < best[0]:
                        best = (times[n], n, ch)
        if best is None:
            return None
        _, target, ch = best
        go = path_to(parent, target)
        back_times, back_parent = self.m.time_search({target: 0.0}, state)
        if node not in back_times:
            return None
        back = path_to(back_parent, node)
        insert = [self.move(u, e, state) for u, e in go]
        t_arrive = steps[k].get("tw", 0.0) + sum(self.duration(s) for s in insert)
        wait = max(0.0, ready_at.get(ch["id"], 0.0) - t_arrive)
        if wait == INF:
            return None
        if wait > 0.0:
            insert.append({"action": "wait", "at": target, "seconds": wait, "state": state,
                           "reason": "enfriamiento del cargador %s" % ch["id"]})
        insert.append({"action": "charge", "at": target, "charger": ch, "state": state, "detour": True,
                       "target": {"type": "charger", "id": ch["id"]}})
        insert.extend(self.move(u, e, state) for u, e in back)
        if energy + ch["amount"] + EPS < need and need > self.rules.energy_max:
            return None
        return steps[:k] + insert + steps[k:]

    # --- Soft-lock de energia en los bucles (Mundo 2; arreglo tras la primera prueba del usuario, 2026-10-23) ---

    def _loop_repeat_s(self, band):
        """Segundos (tiempo del mundo) que tarda una repeticion de la banda: periodo / la velocidad mas alta
        del scroll con el borde de abajo en las filas que recorre durante la repeticion."""
        scroll = self.level.get("scroll", {}) if isinstance(self.level.get("scroll"), dict) else {}
        default = float(scroll.get("default_speed_tiles_s", 0.5))
        view = int(math.ceil(720.0 / self.T))
        rows = range(band[0] + view, band[1] + view + 1)
        speeds = []
        for r in rows:
            speed = default
            for st in scroll.get("stages", []):
                if st["y_from"] <= r <= st["y_to"]:
                    speed = float(st["speed_tiles_s"])
                    break
            speeds.append(abs(speed))
        top = max(speeds) if speeds else default
        return (band[1] - band[0]) / top if top > 0.0 else INF

    def check_loop_energy(self, steps):
        """Regla anti-atasco de los bucles (docs/propuesta-mundo-2.md §8.1, «arreglo tras la primera prueba del
        usuario»): la seccion en bucle se repite sin fin y su salida pide el Debug, asi que quien entra sin
        energia (la minima posible tras la parte previa es 0: nada impide gastarla antes, p. ej. en el secreto
        de la banda) tiene que poder recargar DENTRO de cada repeticion sin tocar el borde, o se queda atrapado.
        Exige, por cada bucle cuya salida gasta Debug en el camino: (1) un cargador dentro de la banda (sus
        filas se recorren en cada repeticion, asi que el cargador se repite con ella) que reponga, solo, todo
        lo que pide la salida, reutilizable y con un enfriamiento que no pase de una repeticion (peor caso de
        gasto: se gasta la carga entera, se falla y en la repeticion siguiente hay que poder volver a cargar);
        y (2) que el camino, entrando al bucle con 0 de energia y pasando por ese cargador, siga cumpliendo la
        energia, el margen del borde del scroll y llegue a la salida sin repetir. Si no: «soft-lock de
        energia»."""
        loops = self.level.get("_loops", [])
        if not loops or self.level.get("camera", {}).get("vertical") != "autoscroll":
            return
        T = self.T
        cap = self.rules.energy_max
        report = []
        for lp in loops:
            b0, b1 = lp["band"]
            ex = lp["exit"]

            def in_exit(node):
                x, feet = self.feet(node)
                return ex[0] * T <= x < (ex[0] + ex[2]) * T and ex[1] * T <= feet - 1.0 < (ex[1] + ex[3]) * T

            # Entrada al bucle: el primer paso con Isak en la banda o en las filas que la repiten debajo.
            view = int(math.ceil(720.0 / T))
            exit_i = entry_i = None
            for i, s in enumerate(steps):
                node = self.node_of(s)
                if node is None:
                    continue
                if entry_i is None and b0 <= node[1] < b1 + view:
                    entry_i = i
                if s["action"] == "move" and in_exit(s["to"]):
                    exit_i = i
                    break
            if exit_i is None or entry_i is None:
                continue
            need = sum(float(s.get("active_s", 0.0)) * self.debug_drain
                       for s in steps[entry_i:exit_i + 1] if s["action"] == "debug_on")
            if need <= EPS:
                continue
            repeat_s = self._loop_repeat_s(lp["band"])
            entry = {"id": lp["id"], "need": round(need, 1), "repeat_s": round(repeat_s, 1), "charger": None}
            report.append(entry)
            in_band = [ch for ch in self.m.chargers if b0 <= ch["cell"][1] <= b1]
            where = "filas %d-%d" % (b0, b1)
            if not in_band:
                self.error("seccion en bucle %s: soft-lock de energia: la salida pide %.0f de energia con el Debug y "
                           "dentro de la banda (%s) no hay ningun cargador; quien entre al bucle sin energia no puede "
                           "recargar y se queda atrapado" % (lp["id"], need, where))
                continue
            good = [ch for ch in in_band if ch["reusable"] and min(ch["amount"], cap) + EPS >= need
                    and ch["cooldown"] <= repeat_s + EPS]
            if not good:
                ch = in_band[0]
                why = ("es de un solo uso" if not ch["reusable"] else
                       "repone %.0f y la salida pide %.0f" % (min(ch["amount"], cap), need)
                       if min(ch["amount"], cap) + EPS < need else
                       "se enfria %.1f s y una repeticion dura %.1f s" % (ch["cooldown"], repeat_s))
                self.error("seccion en bucle %s: soft-lock de energia: el cargador %s de la banda no basta (%s)"
                           % (lp["id"], ch["id"], why), ch["cell"])
                continue
            failures = None
            for ch in good:
                errors = self._loop_worst_case(steps, entry_i, exit_i, ch)
                if not errors:
                    entry["charger"] = ch["id"]
                    entry["amount"] = min(ch["amount"], cap)
                    entry["cooldown_s"] = ch["cooldown"]
                    failures = None
                    break
                if failures is None:
                    failures = (ch, errors)
            if failures is not None:
                ch, errors = failures
                message, node = errors[0][0], errors[0][1]
                self.error("seccion en bucle %s: soft-lock de energia: entrando sin energia y recargando en %s, %s"
                           % (lp["id"], ch["id"], message), node)
        if report:
            self.info["loop_energy"] = report

    def _loop_worst_case(self, steps, entry_i, exit_i, ch):
        """Camino del peor caso: energia a 0 al entrar al bucle y recarga en el cargador `ch` de la banda (si
        el camino no pasa ya por el, con el desvio mas corto desde un movimiento antes del primer Debug).
        Devuelve los errores de energia y de scroll de ese camino (lista vacia si vale)."""
        first_debug = next((i for i in range(entry_i, exit_i + 1) if steps[i]["action"] == "debug_on"), exit_i)
        variant = [dict(s) for s in steps if s["action"] != "wait_scroll"]
        # Indices en `variant` (sin las esperas del scroll, que se recalculan).
        keep = [i for i, s in enumerate(steps) if s["action"] != "wait_scroll"]
        pos = {i: k for k, i in enumerate(keep)}
        v_entry = pos.get(entry_i, next((pos[i] for i in keep if i >= entry_i), len(variant)))
        v_debug = next((pos[i] for i in keep if i >= first_debug), len(variant))
        passes = any(s["action"] == "charge" and s["charger"]["id"] == ch["id"] for s in variant[v_entry:v_debug])
        if not passes:
            best = None
            for k in range(v_entry, v_debug):
                s = variant[k]
                if s["action"] != "move" or s.get("timed"):
                    continue
                node = tuple(s["to"])
                state = s.get("state", frozenset())
                times, parent = self.m.time_search({node: 0.0}, state, debug=False)
                for n in times:
                    x, f = self.feet(n)
                    if not rects_overlap(self.hurt_rect(x, f), ch["rect"]):
                        continue
                    back_times, back_parent = self.m.time_search({n: 0.0}, state, debug=False)
                    if node not in back_times:
                        continue
                    cost = times[n] + back_times[node]
                    if best is None or cost < best[0]:
                        best = (cost, k, node, n, parent, back_parent, state)
            if best is None:
                return [("el cargador %s no se alcanza sin el Debug desde el camino del bucle" % ch["id"], None)]
            _, k, node, target, parent, back_parent, state = best
            insert = [self.move(u, e, state) for u, e in path_to(parent, target)]
            insert.append({"action": "charge", "at": target, "charger": ch, "state": state, "detour": True,
                           "target": {"type": "charger", "id": ch["id"]}})
            insert.extend(self.move(u, e, state) for u, e in path_to(back_parent, node))
            variant = variant[:k + 1] + insert + variant[k + 1:]
        drain_at = self.node_of(variant[v_entry]) if v_entry < len(variant) else None
        variant.insert(v_entry, {"action": "drain", "at": drain_at, "state": variant[v_entry].get("state", frozenset())
                                 if v_entry < len(variant) else frozenset()})
        saved_errors, saved_info = self.errors, dict(self.info)
        self.errors = []
        try:
            variant = self.check_energy_with(variant, 8)
            self.check_scroll(variant)
            found = [(m, n) for m, n, _obj in self.errors]
        finally:
            self.errors, self.info = saved_errors, saved_info
        return found

    def describe(self, s):
        a = s["action"]
        tgt = s.get("target", {})
        if a == "laser":
            return "laser a %s %s" % (tgt.get("type", ""), tgt.get("id", ""))
        if a == "debug_on":
            return "Debug %.1f s" % s.get("active_s", 0.0)
        if a == "move" and s["edge"].get("dash"):
            to = s["edge"]["to"]
            return "dash hasta (fila %d, columna %d)" % (to[1], to[0])
        return a

    # --- Exportacion ---

    def export(self):
        T = self.T
        steps = self.steps
        self.timeline(steps)
        out = []

        def cell(n):
            return {"cell": [n[0], n[1]], "feet_px": [round((n[0] + 0.5) * T, 1), round((n[1] + 1) * T, 1)]}

        merged = []
        for s in steps:
            if (s["action"] == "move" and s["kind"] == "walk" and merged and merged[-1]["action"] == "move"
                    and merged[-1]["kind"] == "walk" and merged[-1].get("debug") == s.get("debug")
                    and merged[-1]["to"] == s["from"] and merged[-1]["to"][1] == s["to"][1]
                    and (s["to"][0] - s["from"][0]) * (merged[-1]["to"][0] - merged[-1]["from"][0]) > 0
                    and bool(merged[-1]["edge"].get("pinched")) == bool(s["edge"].get("pinched"))
                    and not s.get("timed") == "x"):
                merged[-1] = dict(merged[-1], to=s["to"], dur=merged[-1]["dur"] + self.duration(s))
                continue
            merged.append(dict(s, dur=self.duration(s)))
        for idx, s in enumerate(merged):
            a = s["action"]
            item = {"i": idx, "t": round(s["t"], 3), "t_world": round(s["tw"], 3),
                    "duration_s": round(s["dur"], 3)}
            if a == "move" and s["edge"].get("dash"):
                # Paso 9 de docs/propuesta-1-3.md §6.2: dash en el suelo o en el aire (tras un salto).
                e = s["edge"]
                dash = e["dash"]
                item["action"] = "dash"
                item["from"] = cell(s["from"])
                item["to"] = cell(s["to"])
                item["dir"] = int(dash["dir"])
                item["air"] = bool(dash["air"])
                item["takeoff_x_px"] = round(e["x0"], 1)
                item["from_px"] = [round(dash["x_start"], 1), round(dash["y"], 1)]
                item["to_px"] = [round(dash["xs"][-1], 1), round(dash["y"], 1)]
                if dash["air"]:
                    item["jump"] = {"speed": e["speed"],
                                    "target_x_px": None if abs(e["xt"]) > 1e5 else round(e["xt"], 1)}
                    item["dash_after_s"] = round(dash["after_s"], 3)
                fall_xt = dash.get("fall_xt")
                item["target_x_px"] = None if fall_xt is None or abs(fall_xt) > 1e5 else round(fall_xt, 1)
                item["dash_s"] = round(len(dash["xs"]) * DT, 3)
                item["air_s"] = round(e.get("time", 0.0), 3)
            elif a == "move" and s["kind"] in ("pinch", "unpinch"):
                # Mundo 3 (paso 8a): pulsar gesture_pinch en el sitio (comprimirse / pedir el tamano).
                item["action"] = s["kind"]
                item["at"] = cell(s["from"])
                item["squash_s"] = round(s["edge"].get("time", 0.0), 3)
            elif a == "move":
                e = s["edge"]
                item["action"] = s["kind"]
                item["from"] = cell(s["from"])
                item["to"] = cell(s["to"])
                if s["kind"] != "walk":
                    item["takeoff_x_px"] = round(e["x0"], 1)
                    item["target_x_px"] = None if e.get("xt") is None or abs(e["xt"]) > 1e5 else round(e["xt"], 1)
                    item["direction"] = 1 if (e.get("xt") or 0) >= e["x0"] else -1
                    item["speed"] = e["speed"]
                    item["air_s"] = round(self.air_time(s), 3)
                if s.get("debug"):
                    item["debug"] = True
                if e.get("pinched"):
                    item["compressed"] = True
                    item["walk_speed_px_s"] = e["walk_px_s"]
            else:
                item["action"] = a
                node = self.node_of(s)
                if node is not None:
                    item["at"] = cell(tuple(node))
                if s.get("shot"):
                    item["x_px"] = round(s["shot"]["x"], 1)
                    item["facing"] = int(s["shot"]["facing"])
                if s.get("target"):
                    tgt = {k: v for k, v in s["target"].items() if k != "rect"}
                    if "rect" in s["target"]:
                        tgt["rect_px"] = [round(v, 1) for v in s["target"]["rect"]]
                    item["target"] = tgt
                if a in ("wait", "wait_phase", "wait_beat", "wait_scroll"):
                    item["seconds"] = round(s.get("seconds", 0.0), 3)
                    if s.get("reason"):
                        item["reason"] = s["reason"]
                if a == "wait_phase":
                    item["period_s"] = round(s["period_s"], 3)
                    item["phase_s"] = round(s["phase_s"], 3)
                    item["hazards"] = s["hazards"]
                    item["banner_cycle_s"] = s["banner_cycle_s"]
                    if s.get("bell_cycle_s"):
                        item["bell_cycle_s"] = s["bell_cycle_s"]
                    if s.get("clip_cycle_s"):
                        # Paso 9b: segundos de su ciclo de cada video en autoplay y Comentarista (0 = empieza el
                        # aviso del clip o se infla el bocadillo).
                        item["clip_cycle_s"] = s["clip_cycle_s"]
                if a == "wait_beat":
                    # Paso 9: esperar a que el metronomo llegue a esta fase (al terminar la espera).
                    item["rhythm"] = s["beat"]["rhythm"]
                    item["beat"] = {k: v for k, v in s["beat"].items() if k != "rhythm"}
                if a == "laser" and s.get("extra_wait"):
                    item["wait_before_s"] = round(s.get("wait_before_s", 0.0), 3)
                    item["hold_after_s"] = round(s["extra_wait"] - s.get("wait_before_s", 0.0), 3)
                if a == "pickup":
                    item["ability"] = s["ability"]
                    if s.get("refill"):
                        item["refill_energy"] = True
                if a == "debug_on":
                    item["hold_s"] = self.rules.debug_hold_s
                    item["active_s"] = s.get("active_s")
                    if s.get("reason"):
                        item["reason"] = s["reason"]
                if s.get("face_back"):
                    # Interruptor del acertijo de Calc: Isak queda de espaldas pose_s (tiempo del mundo) tras
                    # el pulso; pulso count de of.
                    item["face_back"] = True
                    item["pose_s"] = s.get("pose_s")
                    item["count"] = s.get("count")
                    item["of"] = s.get("of")
                if a == "hop":
                    item["air_s"] = round(s["time"], 3)
                if a == "ground_pound":
                    # Golpe al suelo (Mundo 2): mantener el gesto hold_s en el suelo; rompe `breaks` (ids).
                    item["air"] = bool(s.get("air", False))
                    item["hold_s"] = self.rules.pound_hold_s
                    item["breaks"] = list(s.get("breaks", []))
                    if s.get("debug"):
                        item["debug"] = True
                    # Paso 9b: golpe count de of (muro «Cargando mas...»), tras esperar el enfriamiento, y zonas de
                    # clones que limpia la onda.
                    if s.get("of"):
                        item["count"] = s["count"]
                        item["of"] = s["of"]
                        if s.get("cooldown_before"):
                            item["cooldown_before_s"] = self.rules.pound_cooldown_s
                    if s.get("clears"):
                        item["clears"] = list(s["clears"])
                if s.get("final"):
                    item["final"] = True
            if a == "heart":
                item["likes_after"] = s.get("likes_after")
            if "energy_before" in s:
                item["energy_before"] = s["energy_before"]
                item["energy_after"] = s["energy_after"]
            out.append(item)
        start = self.v.result.get("start")
        physics = {"walk_speed_px_s": self.rules.walk_speed, "jump_height_px": round(self.rules.jump_height, 1),
                   "laser_pose_s": self.rules.laser_pose_s, "pulse_pose_s": self.rules.pulse_pose_s}
        w3 = self.m.w3
        if w3 is not None and w3.compress_possible:
            cr = w3.cmodel.rules
            physics["compress"] = {"box_px": [cr.hitbox_w, cr.hitbox_h], "walk_speed_px_s": cr.walk_speed,
                                   "jump_height_px": round(cr.jump_height, 1), "squash_s": w3.squash_s}
        return {
            "format": FORMAT,
            "level": self.level.get("id"),
            "tile_size": T,
            "physics": physics,
            "start": cell(tuple(start)) if start else None,
            "time_margin_s": self.margin,
            "duration_s": self.info.get("duration_s"),
            "duration_world_s": self.info.get("duration_world_s"),
            "energy": self.info.get("energy"),
            "steps": out,
        }


def plan_level(validator):
    """Ejecuta el plan sobre un Validator ya corrido; anade errores y avisos a su informe y devuelve
    (planner, info)."""
    planner = Planner(validator)
    steps = planner.run()
    rep = validator.report
    for message, node, obj in planner.errors:
        if node is not None:
            rep.error(message, node[1], node[0], obj)
        else:
            rep.error(message, obj=obj)
    for message, node, obj in planner.warnings:
        if node is not None:
            rep.warning(message, node[1], node[0], obj)
        else:
            rep.warning(message, obj=obj)
    if steps is None:
        return planner, None
    planner.info["steps"] = len(steps)
    planner.info["time_margin_s"] = planner.margin
    return planner, planner.info
