"""Scroll forzado del Mundo 2 para el validador (2026-10-22, paso 9 de docs/propuesta-mundo-2.md §7.1).

ScrollSim reproduce scripts/player/scroll_camera.gd (ScrollCamera) con la seccion `scroll` del nivel y
data/camera_scroll.json: el borde de abajo de la vista sube en tiempo del mundo con la velocidad del tramo
(stages, por la fila del borde de abajo; default_speed_tiles_s fuera), se para en el inicio hasta que los
pies de Isak suben por encima de start_resume_row, en cada parada (stops) hasta que suben por encima de su
resume_row y arriba del todo; las inversiones (reverses) lo hacen bajar duration_s (con `trigger`, zona de celdas
[columna, fila, ancho, alto], las arma Isak al entrar con los pies y empiezan reverse_warn_s despues; at_row es el
respaldo; 2-3, paso 14). El plan del camino
(tools/level_plan.py, check_scroll) lo avanza con los pies de Isak cuadro a cuadro.
"""
import json
import math
import os

VIEW_H = 720.0


def load_config(root):
    with open(os.path.join(root, "data", "camera_scroll.json"), encoding="utf-8") as handle:
        return json.load(handle)


class ScrollSim:
    def __init__(self, level, root, tile=64.0, view_h=VIEW_H):
        cfg = load_config(root)
        self.cfg = cfg
        self.T = float(tile)
        self.view_h = float(view_h)
        scroll = level.get("scroll", {})
        rows = len(level["grid"])
        self.level_bottom = rows * self.T
        self.default_speed = float(scroll.get("default_speed_tiles_s", 0.5)) * self.T
        self.stages = [(float(s["y_from"]) * self.T, (float(s["y_to"]) + 1.0) * self.T,
                        float(s["speed_tiles_s"]) * self.T) for s in scroll.get("stages", [])]
        self.stops = sorted(({"id": str(s["id"]), "line": (float(s["at_row"]) + 1.0) * self.T,
                              "resume": float(s["resume_row"]) * self.T, "done": False}
                             for s in scroll.get("stops", [])), key=lambda s: -s["line"])
        self.reverses = [{"line": (float(r["at_row"]) + 1.0) * self.T, "duration": float(r["duration_s"]),
                          "speed": float(r["speed_tiles_s"]) * self.T, "done": False, "armed": -1.0,
                          "zone": tuple(float(v) * self.T for v in r["trigger"]) if r.get("trigger") else None}
                         for r in scroll.get("reverses", [])]
        self.reverse_warn_s = float(cfg.get("reverse_warn_s", 1.0))
        self.start_line = min((float(scroll["start_bottom_row"]) + 1.0) * self.T, self.level_bottom) \
            if "start_bottom_row" in scroll else self.level_bottom
        self.start_resume = float(scroll.get("start_resume_row", 0)) * self.T
        self.ceiling_px = float(cfg.get("ceiling_above_view_px", 128.0))
        self.restart()

    def restart(self):
        for s in self.stops:
            s["done"] = False
        for r in self.reverses:
            r["done"] = False
            r["armed"] = -1.0
        self.bottom = self.start_line
        self.parked = -1
        self.reversing = -1
        self.reverse_left = 0.0
        self.started_at = None
        self.time = 0.0

    @property
    def top(self):
        return self.bottom - self.view_h

    def top_limit(self):
        return self.view_h

    def speed_at(self, bottom):
        row_line = bottom - 0.5
        for top, bot, speed in self.stages:
            if top <= row_line <= bot:
                return speed
        return self.default_speed

    def damaging_edge(self):
        return "top" if self.reversing >= 0 else "bottom"

    def ceiling(self):
        """y minima de la cabeza (techo de carga), -inf al invertir."""
        return -math.inf if self.reversing >= 0 else self.top - self.ceiling_px

    def _start_reverse(self, i):
        rev = self.reverses[i]
        rev["done"] = True
        rev["armed"] = -1.0
        self.reversing = i
        self.reverse_left = rev["duration"]
        self.parked = -2

    def step(self, feet, dt, x=None):
        """Avanza `dt` s del mundo con los pies de Isak en la y `feet` (y la x `x`, para las zonas que arman una
        inversion; sin x no se arman)."""
        self.time += dt
        if self.parked != -2:
            resume = self.start_resume if self.parked == -1 else self.stops[self.parked]["resume"]
            if feet < resume:
                if self.parked >= 0:
                    self.stops[self.parked]["done"] = True
                elif self.started_at is None:
                    self.started_at = self.time
                self.parked = -2
            else:
                return
        if self.reversing >= 0:
            rev = self.reverses[self.reversing]
            self.bottom = min(self.bottom + rev["speed"] * dt, self.level_bottom)
            self.reverse_left -= dt
            if self.reverse_left <= 0.0:
                self.reversing = -1
            return
        for i, rev in enumerate(self.reverses):
            if rev["done"] or rev["zone"] is None:
                continue
            if rev["armed"] < 0.0:
                zx, zy, zw, zh = rev["zone"]
                if x is not None and zx <= x < zx + zw and zy <= feet - 1.0 < zy + zh:
                    rev["armed"] = self.reverse_warn_s
            else:
                rev["armed"] -= dt
                if rev["armed"] <= 0.0:
                    self._start_reverse(i)
                    return
        speed = self.speed_at(self.bottom)
        nxt = max(self.bottom - speed * dt, self.top_limit())
        for i, stop in enumerate(self.stops):
            if not stop["done"] and nxt <= stop["line"] <= self.bottom:
                nxt = stop["line"]
                self.parked = i
                break
        for i, rev in enumerate(self.reverses):
            if not rev["done"] and nxt <= rev["line"] <= self.bottom:
                nxt = rev["line"]
                self._start_reverse(i)
                break
        self.bottom = nxt

    def is_parked(self):
        return self.parked != -2

    def margin(self, feet, head):
        """Distancia (px) de Isak al borde que dana: pies sobre el de abajo o cabeza bajo el de arriba."""
        if self.damaging_edge() == "top":
            return head - self.top
        return self.bottom - feet

    def copy_state(self):
        return (self.bottom, self.parked, self.reversing, self.reverse_left, self.started_at, self.time,
                tuple(s["done"] for s in self.stops), tuple((r["done"], r["armed"]) for r in self.reverses))

    def restore(self, st):
        (self.bottom, self.parked, self.reversing, self.reverse_left, self.started_at, self.time,
         stops, revs) = st
        for s, d in zip(self.stops, stops):
            s["done"] = d
        for r, (d, a) in zip(self.reverses, revs):
            r["done"], r["armed"] = d, a
