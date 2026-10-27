#!/usr/bin/env python3
"""Subidas de un nivel para la prueba de saltos reales (2026-10-17, ajuste del 1-2 tras probarlo).

Lista cada subida (salto que aterriza mas arriba) entre dos repisas que el validador
(tools/validate_level.py) acepta en el nivel con todas las puertas abiertas (puentes extendidos,
pop-ups solidos cerrados, barra abierta, habilidades recogidas, piezas del acertijo de Calc hechas). Solo
cuenta lo alcanzable desde P; los saltos que solo existen con el Debug encendido (plataformas 'h')
van marcados con "debug" (como la union de movimientos del validador). Una repisa es una tira de celdas de pie contiguas en una fila. Por
cada par (repisa de salida, repisa de llegada) se queda el salto que el validador ve mas facil
(andando antes que corriendo), con su x de despegue y la x donde soltar la direccion.

La prueba GUT tests/test_level_climbs.gd lee la salida (tests/fixtures/climbs_<id>.json), pone al
Isak real en la repisa de salida y ejecuta el salto (andando y corriendo, desde el borde y desde dos
tiles atras, con coyote) midiendo si aterriza, si la cabeza toca el techo y la holgura vertical y
horizontal que le queda.

Uso:
  python3 tools/level_climbs.py data/levels/1-2.json [--out tests/fixtures/climbs_1-2.json] [--check]
Arenas de jefe (kind boss, 2026-10-21): la geometria de las fases 1-2 (tools/validate_boss.geometry_level).
--check sale con 1 si el archivo no esta al dia (lo usa tools/run_tests.sh).
"""

import argparse
import json
import os
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_level as vl  # noqa: E402
import level_catalog  # noqa: E402
import world3_model  # noqa: E402

FORMAT = "isak-climbs/1"


def default_out(level):
    return os.path.join(ROOT, "tests", "fixtures", "climbs_%s.json" % level["id"])


def ledge_of(world, node):
    c, r = node
    c0 = c
    while world.is_node(c0 - 1, r):
        c0 -= 1
    c1 = c
    while world.is_node(c1 + 1, r):
        c1 += 1
    return (c0, c1, r)


def climbs(level, root=ROOT):
    # Con carrera: el jugador corre aunque el camino del validador vaya andando.
    rules = vl.Rules(root, None, vl.DEFAULT_JUMP_EFFICIENCY, vl.DEFAULT_LIMIT, allow_run=True)
    level_id = level["id"]
    if level.get("kind") == "boss":
        # Arena de jefe (2026-10-21, paso 5 de docs/propuesta-jefe-alerta-mayor.md §6): la geometria de las
        # fases 1-2 (plataformas de una via, sin el jefe ni sus ataques; tools/validate_boss.py).
        import validate_boss
        level = validate_boss.geometry_level(level)
    # Mundo 3 (paso 12 de docs/propuesta-mundo-3.md, el 3-2 real, 2026-10-27): la herramienta «Recortar» como el
    # interruptor que da Pellizcar, igual que en validate_level.validate (sin crop_tool el nivel no cambia); sin
    # esto el marco pequeno de la salida del Estudio cerraba el paso y el 3-2 salia con 0 subidas.
    level = world3_model.lower(level, level_catalog.load_catalog(root, int(level.get("world", 1))))
    validator = vl.Validator(level, rules)
    model = validator.model
    # Acertijo de Calc (tanda H2 del paso 14, 2026-10-17): con sus piezas hechas la pared con glitch es
    # una puerta y el cuarto de la azotea se recorre sin el Debug.
    # 1-3 (paso 10, 2026-10-20): con el interruptor No molestar activado (el dash), como el jugador tras la
    # sala «Ajustes»; sin el, el pasillo del banner obligatorio cierra el paso en el grafo.
    state = frozenset(g.gid for g in model.gates if g.kind in ("bridge", "popup", "bar", "pickup", "switch",
                                                                "lswitch", "dock", "dnd"))
    # Mundo 3 (paso 10 de docs/propuesta-mundo-3.md, el 3-1 real, 2026-10-26): con el contador al maximo, como
    # el jugador que va cogiendo los corazones: las plataformas de likes normales encendidas (las inversas,
    # de los secretos, apagadas). Sin objetos del Mundo 3 (w3 None) nada cambia.
    w3 = getattr(model, "w3", None)
    if w3 is not None and w3.like_platforms:
        state = w3.with_likes(state, w3.likes_max)
    # Mundo 3 (paso 13, el 3-3 real, 2026-10-27): con las placas «Posa aqui» pisadas, como el jugador al que el
    # Reflejo falso le sostiene la puerta; sin esto las puertas de marco cerraban el paso y el 3-3 solo tenia las
    # subidas de antes del Tramo 3. Sin placas nada cambia.
    if w3 is not None and getattr(w3, "plates", None):
        state = state | frozenset(g.gid for g in w3.plates)
    start_cell = validator.find("P")[0]
    start, why = validator.spawn_node(start_cell, state)
    if start is None:
        raise ValueError("P sin suelo: %s" % why)
    T = model.T
    seen = {start}
    queue = deque([start])
    groups = {}
    while queue:
        node = queue.popleft()
        for e in model.edges(node, state, "auto"):
            if max(e["h"], e["v"]) > rules.limit + vl.EPS:
                continue
            to = e["to"]
            if to not in seen:
                seen.add(to)
                queue.append(to)
            if e["kind"] not in ("jump", "jump_run") or e["rise"] <= vl.EPS:
                continue
            # Las subidas comprimido (Pellizcar) las mide tests/test_compress.gd con su caja; aqui, el Isak normal.
            if world3_model.is_pinched(node) or world3_model.is_pinched(to):
                continue
            w = model.world(state, bool(e.get("debug")))
            a, b = ledge_of(w, node), ledge_of(w, to)
            if a == b:
                continue
            key = (a, b)
            rank = (0 if e["kind"] == "jump" else 1, round(max(e["h"], e["v"]), 6), abs(node[0] - to[0]))
            old = groups.get(key)
            if old is None or rank < old[0]:
                groups[key] = (rank, node, e)
    out = []
    for (a, b), (_, node, e) in sorted(groups.items(), key=lambda kv: (-kv[0][0][2], kv[0][0][0], -kv[0][1][2],
                                                                        kv[0][1][0])):
        to = e["to"]
        direction = 1 if (e["xt"] if e["xt"] is not None else to[0] * T) >= e["x0"] else -1
        xt = e["xt"]
        if xt is not None and abs(xt - e["x0"]) > 1e5:
            xt = None
        out.append({
            "id": "%d,%d->%d,%d" % (node[0], node[1], to[0], to[1]),
            "section": model.section_name(node[0], node[1]),
            "from": {"cell": [node[0], node[1]], "ledge": [a[0], a[1]], "row": a[2]},
            "to": {"cell": [to[0], to[1]], "ledge": [b[0], b[1]], "row": b[2]},
            "rise_tiles": a[2] - b[2],
            "direction": direction,
            "speed": "walk" if e["kind"] == "jump" else "run",
            "takeoff_x_px": round(e["x0"], 3),
            "target_x_px": None if xt is None else round(xt, 3),
            "debug": bool(e.get("debug")),
        })
    return {"format": FORMAT, "level": level_id, "tile_size": T,
            "note": "Generado por tools/level_climbs.py; no editar a mano.", "climbs": out}


def dump(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + "\n"


def main(argv):
    parser = argparse.ArgumentParser(description="Subidas de un nivel para la prueba de saltos reales.")
    parser.add_argument("level")
    parser.add_argument("--out", default=None)
    parser.add_argument("--check", action="store_true", help="sale con 1 si el archivo no esta al dia")
    args = parser.parse_args(argv[1:])
    level = vl.load_json(args.level)
    out = args.out or default_out(level)
    text = dump(climbs(level))
    if args.check:
        try:
            with open(out, encoding="utf-8") as handle:
                current = handle.read()
        except OSError:
            current = None
        if current != text:
            print("%s no esta al dia: python3 tools/level_climbs.py %s" % (out, args.level), file=sys.stderr)
            return 1
        return 0
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("%s: %d subidas" % (out, len(json.loads(text)["climbs"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
