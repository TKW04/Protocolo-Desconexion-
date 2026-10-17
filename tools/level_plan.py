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
    celdas seguras y saltos en el sitio; el bot espera en la entrada a la fase indicada.
  - Puntos rojos (notification_badge): simulacion a lo largo del camino; si se va a lanzar y el
    pulso lo alcanza, se aturde (pulso insertado). El dano que quede tiene que caber en
    validation.sync_damage_budget (0 por defecto).
  - Barra del 99 % (update_bar): espera fija (rise_s + wait_s + full_s) en su zona; las oleadas no
    se modelan (se esquivan o se aturden; no es obligatorio derrotarlas).
  - Energia: empieza en validation.start_energy (100); laser 10 por disparo, Debug 20/s; cargadores
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

DT = 1.0 / 60.0
EPS = 1e-6
INF = float("inf")
# Disparos al Posponer que se prueban dentro de un mismo cruce de recordatorios.
MAX_SNOOZE_SHOTS = 3
# Celdas de margen alrededor de la zona de un banner para la busqueda por tiempo.
HAZARD_PAD = 4
# Paso de fase de la busqueda de banners (s).
PHASE_BIN = 1.0 / 30.0
# Iteraciones maximas de la simulacion de puntos rojos (cada aturdimiento reinicia).
MAX_STUNS = 12
# Cuenta minima (s) de un recordatorio cuando Isak esta encima o le llega el disparo al Posponer.
REMINDER_STAND_S = 0.1
# Huecos de tiempo (s) sin plataformas ocultas que no apagan el Debug entre dos tramos.
DEBUG_GAP_S = 1.0


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


def rects_overlap(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


class Planner:
    def __init__(self, validator):
        self.v = validator
        self.m = validator.model
        self.rules = validator.rules
        self.level = validator.level
        self.T = self.m.T
        self.val = self.m.validation
        self.margin = self.m.time_margin()
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
        for stage in run["stages"]:
            state = stage["state"]
            last_state = state
            for u, e in path_to(stage["parent"], stage["end"]):
                steps.append(self.move(u, e, state))
            g = stage["gate"]
            if g is None:
                continue
            n = stage["end"]
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
            if g.kind == "bar":
                steps.append({"action": "wait", "at": n, "seconds": g.wait_s, "state": state,
                              "reason": "barra del 99 %% %s" % g.obj_id,
                              "target": {"type": "update_bar", "id": g.obj_id}})
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
            return self.m.edge_time(s["from"], s["edge"])
        if a == "hop":
            return s["time"]
        if a == "laser":
            return r.laser_pose_s + s.get("extra_wait", 0.0)
        if a == "pulse":
            return r.pulse_pose_s
        if a in ("wait", "wait_phase"):
            return s.get("seconds", 0.0)
        if a == "debug_on":
            return r.debug_hold_s + r.debug_fade_s
        return 0.0

    def node_of(self, s):
        return s.get("at") or s.get("to")

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
                n = max(1, int(round(T / speed / DT)))
                return [(cu[0] + (cv[0] - cu[0]) * (i + 1) / n, cu[1], False) for i in range(n)]
            out = []
            x0 = e["x0"]
            n = int(round(abs(x0 - cu[0]) / speed / DT))
            out += [(cu[0] + (x0 - cu[0]) * (i + 1) / max(n, 1), cu[1], False) for i in range(n)]
            out += [(x0, cu[1], False)] * int(round(0.06 / DT))
            info = {"want_traj": True}
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
        steps = self.check_energy(steps)
        self.info["bars"] = []
        for st in steps:
            if st.get("target", {}).get("type") == "update_bar":
                g = next(g for g in self.m.gates if g.kind == "bar" and g.obj_id == st["target"]["id"])
                self.info["bars"].append({"id": g.obj_id, "wait_s": round(g.wait_s, 2), "at": [st["at"][1], st["at"][0]],
                                          "wave_enemies": len(g.waves)})
        total, total_world = self.timeline(steps)
        self.info["duration_s"] = round(total, 2)
        self.info["duration_world_s"] = round(total_world, 2)
        self.steps = steps
        return steps

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
            i = j + 1
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
            out.extend(steps[a:b + 1])
            out.append({"action": "debug_off", "at": steps[b]["to"], "state": steps[b]["state"]})
            cursor = b + 1
            seconds = sum(self.duration(steps[k]) for k in range(a, b + 1))
            self.info["debug"]["segments"].append({"from": [at[1], at[0]], "to": [steps[b]["to"][1], steps[b]["to"][0]],
                                                   "active_s": round(seconds, 2),
                                                   "energy": round(seconds * self.rules.debug_drain, 1)})
        out.extend(steps[cursor:])
        self.info["debug"]["required"] = any(steps[i].get("debug") for i in need)
        return out

    def valid_in_debug(self, s):
        if s["action"] != "move":
            return True
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
        """Lista de cuadros (indice de paso, cuadro dentro del paso, x, pies, en_el_aire, debug)."""
        out = []
        debug = False
        for i, s in enumerate(steps):
            if s["action"] == "debug_on":
                debug = True
            elif s["action"] == "debug_off":
                debug = False
            for k, (x, feet, air) in enumerate(self.samples(s)):
                out.append((i, k, x, feet, air, debug, s["action"]))
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
        for idx, (i, k, x, feet, air, debug, action) in enumerate(frames):
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
                    if invuln <= 0.0 and rects_overlap(self.hurt_rect(x, feet), drect):
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
        i, k, x, feet, air, debug, action = frames[idx]
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

    # --- Banners ---

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
            out.append({"id": enemy["id"], "dir": direction, "corridor": corridor, "bw": bw, "warn": warn,
                        "sweep": sweep, "interval": interval, "rest": interval - warn - sweep,
                        "phase": float(p.get("phase_s", 0.0)), "entry": entry, "speed": float(p["sweep_speed_px_s"]),
                        "dw": dw, "dh": dh, "bottom": bottom, "cell": (enemy["x"], enemy["y"]),
                        "band": (min(a, b), bottom - dh, max(a, b), bottom)})
        return out

    def banner_rect(self, b, tw):
        t = (tw + b["phase"]) % b["interval"]
        if t < b["rest"] + b["warn"]:
            return None
        progress = min(max((t - b["rest"] - b["warn"]) * b["speed"], 0.0), max(b["corridor"] - b["bw"], 0.0))
        cx = b["entry"] + b["dir"] * (b["bw"] * 0.5 + progress)
        return (cx - b["dw"] * 0.5, b["bottom"] - b["dh"], cx + b["dw"] * 0.5, b["bottom"])

    def exposed(self, x, feet, banners):
        rect = self.hurt_rect(x, feet)
        return any(rects_overlap(rect, b["band"]) for b in banners)

    def check_banners(self, steps):
        banners = self.banner_data()
        self.info["banners"] = []
        if not banners:
            return steps
        period = banners[0]["interval"]
        if any(abs(b["interval"] - period) > EPS for b in banners):
            period = min(12.0, max(b["interval"] for b in banners) * len(banners))
        exposed = [any(self.exposed(x, f, banners) for x, f, _ in self.samples(s)) for s in steps]
        idx = [k for k, flag in enumerate(exposed) if flag]
        if not idx:
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
                if not self.exposed(x, f, banners):
                    entry_idx = k
                    break
            entry = tuple(steps[entry_idx]["to"]) if entry_idx is not None else tuple(self.v.result["start"])
            first = entry_idx + 1 if entry_idx is not None else 0
            # Salida: primera celda de pie segura despues del tramo (o la ultima del camino).
            exit_idx = None
            for k in [m for m in moves if m >= b]:
                x, f = self.feet(steps[k]["to"])
                if not self.exposed(x, f, banners):
                    exit_idx = k
                    break
            dwell = 0.0
            if exit_idx is None:
                exit_idx = moves[-1] if moves[-1] >= first else first
                if any(st.get("final") for st in steps[exit_idx + 1:]):
                    dwell = self.rules.pulse_pose_s + 0.1
            exit_node = tuple(steps[exit_idx]["to"])
            state = steps[exit_idx]["state"]
            plan = self.hazard_search(entry, exit_node, state, banners, period, dwell)
            item = {"banners": [bn["id"] for bn in banners], "entry": [entry[1], entry[0]],
                    "exit": [exit_node[1], exit_node[0]], "period_s": round(period, 3)}
            self.info["banners"].append(item)
            out.extend(steps[cursor:first])
            if plan is None:
                self.error("banners %s: no hay forma de cruzar su pasillo sin dano entre (fila %d, columna %d) y "
                           "(fila %d, columna %d) (esperas en sitios seguros y saltos en el sitio)" % (
                               ", ".join(bn["id"] for bn in banners), entry[1], entry[0], exit_node[1], exit_node[0]),
                           entry)
                out.extend(steps[first:exit_idx + 1])
                cursor = exit_idx + 1
                continue
            item.update({"start_phase_s": round(plan["phase"], 3), "crossing_s": round(plan["time"], 2),
                         "waits": sum(1 for st in plan["steps"] if st["action"] == "wait"),
                         "hops": sum(1 for st in plan["steps"] if st["action"] == "hop")})
            for st in plan["steps"]:
                st.setdefault("state", state)
            out.append({"action": "wait_phase", "at": entry, "state": state, "period_s": period,
                        "phase_s": plan["phase"], "hazards": [bn["id"] for bn in banners],
                        "banner_cycle_s": {bn["id"]: round((plan["phase"] + bn["phase"]) % bn["interval"], 3)
                                           for bn in banners}})
            out.extend(plan["steps"])
            # Lo que no es movimiento dentro del tramo (recogidas, cargadores) se conserva al final.
            out.extend(st for st in steps[first:exit_idx + 1] if st["action"] in ("pickup", "charge"))
            cursor = exit_idx + 1
        out.extend(steps[cursor:])
        self.resolve_phase_waits(out, banners)
        return out

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

    def hop(self, node, state):
        """Salto en el sitio (para dejar pasar un banner por debajo)."""
        x, feet = self.feet(node)
        info = {"want_traj": True}
        w = self.m.world(state, False)
        to, _ = w.simulate(x, feet, -self.rules.jump_v0, 0.0, x, info=info)
        if to != node:
            return None
        traj = [(px, py, True) for px, py in info["traj"]]
        return {"action": "hop", "at": node, "time": len(traj) * DT + 0.06,
                "traj": traj + [(x, feet, False)] * int(round(0.06 / DT))}

    def hazard_search(self, entry, exit_node, state, banners, period, dwell):
        """Dijkstra por (celda, fase) en la zona de los banners: andar, saltar, esperar en una celda
        segura o saltar en el sitio sin tocar ningun banner en barrido."""
        T = self.T
        bins = max(1, int(round(period / PHASE_BIN)))
        cols = [int(b["band"][0] // T) for b in banners] + [int(b["band"][2] // T) for b in banners]
        rows = [int(b["bottom"] // T) for b in banners]
        c_lo = min(cols + [entry[0], exit_node[0]]) - HAZARD_PAD
        c_hi = max(cols + [entry[0], exit_node[0]]) + HAZARD_PAD
        r_lo = min(rows + [entry[1], exit_node[1]]) - HAZARD_PAD
        r_hi = max(rows + [entry[1], exit_node[1]]) + 1
        region = lambda n: c_lo <= n[0] <= c_hi and r_lo <= n[1] <= r_hi

        def safe_at(samples, phase_t):
            for k, (x, f, _) in enumerate(samples):
                tw = phase_t + (k + 1) * DT
                hr = self.hurt_rect(x, f)
                for b in banners:
                    rect = self.banner_rect(b, tw)
                    if rect is not None and rects_overlap(hr, rect):
                        return False
            return True

        sample_cache = {}

        def edge_samples(u, e):
            key = (u, e["to"], e["kind"], e["x0"], e.get("xt"))
            if key not in sample_cache:
                sample_cache[key] = self.samples(self.move(u, e, state))
            return sample_cache[key]

        hop_cache = {}
        heap = []
        best = {}
        parent = {}
        for ph in range(bins):
            key = (entry, ph)
            best[key] = 0.0
            parent[key] = None
            heap.append((0.0, ph, entry))
        heapq.heapify(heap)
        static_cache = {}

        def standing(node):
            if node not in static_cache:
                x, f = self.feet(node)
                static_cache[node] = [(x, f, False)] * max(1, int(round(PHASE_BIN / DT)))
            return static_cache[node]

        goal = None
        expansions = 0
        while heap:
            t, ph, node = heapq.heappop(heap)
            if t > best.get((node, ph), INF) + EPS:
                continue
            expansions += 1
            if expansions > 400000:
                break
            phase_t = ph * PHASE_BIN
            if node == exit_node:
                x, f = self.feet(node)
                if dwell <= 0.0 or safe_at([(x, f, False)] * int(round(dwell / DT)), phase_t):
                    goal = (node, ph)
                    break
            # Esperar un paso de fase.
            cand = []
            if safe_at(standing(node), phase_t):
                cand.append((node, PHASE_BIN, {"action": "wait"}))
            if node not in hop_cache:
                hop_cache[node] = self.hop(node, state)
            hp = hop_cache[node]
            if hp is not None and safe_at(hp["traj"], phase_t):
                cand.append((node, hp["time"], {"action": "hop"}))
            for e in self.m.edges(node, state, "auto"):
                if max(e["h"], e["v"]) > self.rules.limit + EPS or not region(e["to"]):
                    continue
                smp = edge_samples(node, e)
                if safe_at(smp, phase_t):
                    cand.append((e["to"], len(smp) * DT, {"action": "move", "e": e}))
            for to, d, act in cand:
                nph = int(round((phase_t + d) / PHASE_BIN)) % bins
                nt = t + d
                key = (to, nph)
                if nt < best.get(key, INF) - EPS:
                    best[key] = nt
                    parent[key] = ((node, ph), act)
                    heapq.heappush(heap, (nt, nph, to))
        if goal is None:
            return None
        seq = []
        key = goal
        while parent.get(key) is not None:
            prev, act = parent[key]
            seq.append((prev, act))
            key = prev
        seq.reverse()
        start_phase = key[1] * PHASE_BIN
        out = []
        for (node, _), act in seq:
            if act["action"] == "wait":
                if out and out[-1]["action"] == "wait" and out[-1]["at"] == node:
                    out[-1]["seconds"] += PHASE_BIN
                else:
                    out.append({"action": "wait", "at": node, "seconds": PHASE_BIN, "reason": "banner"})
            elif act["action"] == "hop":
                hp = dict(hop_cache[node])
                out.append(hp)
            else:
                out.append(self.move(node, act["e"], state))
        return {"phase": start_phase, "time": best[goal], "steps": out}

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
            elif a == "debug_on":
                k = i + 1
                active = 0.0
                while k < len(steps) and steps[k]["action"] != "debug_off":
                    active += self.duration(steps[k])
                    k += 1
                need = active * r.debug_drain
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

    def describe(self, s):
        a = s["action"]
        tgt = s.get("target", {})
        if a == "laser":
            return "laser a %s %s" % (tgt.get("type", ""), tgt.get("id", ""))
        if a == "debug_on":
            return "Debug %.1f s" % s.get("active_s", 0.0)
        return a


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
