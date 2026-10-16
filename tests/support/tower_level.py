"""Torre sintetica para las pruebas Python de niveles verticales (paso 1 de
docs/propuesta-1-2.md §10, 2026-10-16). No es un nivel del juego: genera en memoria
un nivel con la estructura de la torre del 1-2 (vestibulo abajo, pisos de alto fijo y
azotea arriba con la terminal de salida), forjados con un hueco de plataformas de una
via alternando de lado y, dentro de cada piso, repisas de una via en zigzag cada 2
filas (subidas de 2 tiles) que se solapan una columna con la siguiente.

Por defecto mide 28 x 62 tiles como la torre del 1-2: azotea 0-7, cuatro pisos de 12
filas (8-19, 20-31, 32-43, 44-55) y vestibulo 56-61.
"""

HUECO = 4  # ancho del hueco de cada forjado (columnas 1-4 o 23-26)


def _mirror(c0, c1, width):
    return width - 1 - c1, width - 1 - c0


def make_tower(floors=4, floor_h=12, roof_h=8, lobby_h=6, width=28, level_id="tower_test"):
    if floor_h % 2 or lobby_h != 6 or roof_h < 4:
        raise ValueError("pisos de alto par, vestibulo de 6 filas y azotea de al menos 4")
    height = roof_h + floors * floor_h + lobby_h
    g = [["." for _ in range(width)] for _ in range(height)]

    def put(r, c0, c1, ch):
        for c in range(c0, c1 + 1):
            g[r][c] = ch

    for r in range(height):
        g[r][0] = g[r][width - 1] = "#"
    put(0, 0, width - 1, "#")
    put(height - 1, 0, width - 1, "#")
    left_hole = (1, HUECO)
    right_hole = _mirror(1, HUECO, width)
    sections = []
    # Vestibulo: suelo en la ultima fila; dos repisas bajo el hueco de la derecha.
    bottom = height - 1
    put(bottom - 2, right_hole[0] - 3, right_hole[0], "-")
    put(bottom - 4, right_hole[0], right_hole[1], "-")
    sections.append({"name": "Vestíbulo", "y_from": height - lobby_h, "y_to": height - 1})
    # Pisos de abajo arriba: el suelo de cada uno es la ultima fila de su banda.
    n = (floor_h - 2) // 2
    for i in range(floors):
        floor_row = height - lobby_h - 1 - i * floor_h
        top_row = floor_row - floor_h + 1
        put(floor_row, 1, width - 2, "#")
        leftwards = i % 2 == 0
        entry = right_hole if leftwards else left_hole
        put(floor_row, entry[0], entry[1], "-")
        steps = [(1 + 4 * k, 5 + 4 * k) for k in range(n)][::-1]
        for k, (c0, c1) in enumerate(steps):
            if not leftwards:
                c0, c1 = _mirror(c0, c1, width)
            put(floor_row - 2 * (k + 1), c0, c1, "-")
        sections.append({"name": "Piso %d" % (i + 1), "y_from": top_row, "y_to": floor_row,
                         "patterns": ["zigzag"]})
    # Azotea: su suelo tiene el hueco del ultimo piso.
    roof_floor = roof_h - 1
    put(roof_floor, 1, width - 2, "#")
    last_left = (floors - 1) % 2 == 0
    hole = left_hole if last_left else right_hole
    put(roof_floor, hole[0], hole[1], "-")
    sections.append({"name": "Azotea", "y_from": 0, "y_to": roof_floor})
    g[bottom - 1][3] = "P"
    goal_col = 22 if last_left else 5
    g[roof_floor - 1][goal_col] = "G"
    return {
        "id": level_id,
        "name": "Torre sintética",
        "world": 1,
        "tile_size": 64,
        "debug_color": "cyan",
        "abilities_available": {"pulse": True, "debug": False},
        "camera": {"vertical": "tower", "limits": "grid"},
        "sections": sections[::-1],
        "grid": ["".join(row) for row in g],
        "checkpoints": [],
        "secrets": [],
        "enemies": [],
        "objects": [{"type": "exit_terminal", "x": goal_col, "y": roof_floor - 2,
                     "params": {"id": "terminal_torre", "text": "Marcar como leído",
                                "width_tiles": 1, "height_tiles": 2}}],
        "unlocks": [],
    }
