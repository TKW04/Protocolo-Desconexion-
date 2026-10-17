#!/usr/bin/env python3
"""Genera el arte de la tienda de Calc por pistas (tanda M1 de docs/propuesta-mejoras.md §1 y §9).

Paleta del hub (assets/palettes/hub.gpl, sin los rojos reservados), estilo circuito limpio
como tools/gen_hub_objects.py (Calc es arte del hub), fondo transparente, alfa 0 o 255,
salida determinista. Dibujado a 1 px de arte (el panel se ve x2, pixel_scale de data/hub.json).

Salidas (assets/sprites/calc_shop/):
  calc_chips.png   24x24 por cuadro, 6 columnas x 2 filas
                   columnas: pulse (onda del celular), laser (haz), debug (ojo entre
                   corchetes), sync (barras de senal, la del HUD), energy (bateria con
                   rayo), unknown (chip «?», habilidad sin obtener)
                   filas: 0 normal (patas y marco gris azulado), 1 elegido (marco cian)
                   Chip de microcircuito con 3 patas por lado, como el chip del Debug.
  calc_level_boxes.png  10x14 por cuadro, 11 columnas x 1 fila (recuadros de nivel):
                   0 full (nivel comprado: relleno acento_cian), 1-2 next_a/next_b (el
                   siguiente que se puede comprar: contorno ambar que late), 3 empty
                   (comprable en este acceso, aun no el siguiente), 4 locked (por encima
                   del tope del acceso: gris oscuro con mini candado 5x5), 5 soon
                   («Proximamente»: contorno discontinuo y puntos), 6 unknown (pista con
                   chip «?»), 7-9 fill_1..fill_3 (se carga de abajo arriba al comprar),
                   10 flash (destello final, cian_brillo).
Lo usan CalcPanel (scripts/hub/calc_panel.gd) y data/hub.json (seccion calc, art).

Uso (desde la raiz del repo):
  python3 -I tools/gen_calc_chips.py [--dry-run] [--preview <png> [--scale N]]
Validador: tools/validate_calc_chips.py.
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_hub_objects as gh  # noqa: E402

REPO = gh.REPO
PAL = gh.PAL
FP, SO, PA, DK, BA = gh.FP, gh.SO, gh.PA, gh.DK, gh.BA
GA, GF, TR, BO = gh.GA, gh.GF, gh.TR, gh.BO
TT, TC, CT, CA, CB = gh.TT, gh.TC, gh.CT, gh.CA, gh.CB
AM, AS = gh.AM, gh.AS
CLEAR = gh.CLEAR
Canvas = gh.Canvas

CHIP = 24
ICONS = ["pulse", "laser", "debug", "sync", "energy", "unknown"]
CHIP_ROWS = ["normal", "selected"]
BOX_W, BOX_H = 10, 14
BOXES = ["full", "next_a", "next_b", "empty", "locked", "soon", "unknown", "fill_1", "fill_2", "fill_3", "flash"]
CHIPS_PATH = "assets/sprites/calc_shop/calc_chips.png"
BOXES_PATH = "assets/sprites/calc_shop/calc_level_boxes.png"

# Iconos de 12x12 dentro del cuerpo del chip ('#' trazo claro, '+' trazo principal, 'o' sombra).
ICON_ART = {
    "pulse": [  # celular con dos arcos de onda
        "............",
        "........+...",
        ".....+...+..",
        "......+...+.",
        ".##....+..+.",
        "#oo#...+...+",
        "#oo#...+...+",
        "#oo#...+..+.",
        "####..+...+.",
        "#oo#.+...+..",
        ".##.....+...",
        "............",
    ],
    "laser": [  # canon a la izquierda y haz horizontal con destello
        "............",
        "..........+.",
        "........+...",
        "##.......+.+",
        "###.........",
        "####++++#+##",
        "####++++#+##",
        "###.........",
        "##.......+.+",
        "........+...",
        "..........+.",
        "............",
    ],
    "debug": [  # ojo entre corchetes
        "............",
        "##........##",
        "#..........#",
        "#...####...#",
        "#..#oooo#..#",
        "#.#oo++oo#.#",
        "#.#oo++oo#.#",
        "#..#oooo#..#",
        "#...####...#",
        "#..........#",
        "##........##",
        "............",
    ],
    "sync": [  # cuatro barras de senal crecientes (la del HUD)
        "............",
        ".........++.",
        ".........++.",
        ".........++.",
        "......++.++.",
        "......++.++.",
        "......++.++.",
        "...++.++.++.",
        "...++.++.++.",
        "++.++.++.++.",
        "++.++.++.++.",
        "............",
    ],
    "energy": [  # bateria con rayo
        "............",
        "....####....",
        "...######...",
        "...#oooo#...",
        "...#oo+o#...",
        "...#o++o#...",
        "...#++++#...",
        "...#o++o#...",
        "...#o+oo#...",
        "...#oooo#...",
        "...######...",
        "............",
    ],
    "unknown": [  # signo de interrogacion
        "............",
        "....####....",
        "...##..##...",
        "...##..##...",
        ".......##...",
        "......##....",
        ".....##.....",
        ".....##.....",
        "............",
        ".....##.....",
        ".....##.....",
        "............",
    ],
}


def chip(icon, selected):
    """Chip de 24x24: patas (3 por lado), cuerpo con esquinas cortadas e icono de 12x12."""
    cv = Canvas(CHIP, CHIP)
    known = icon != "unknown"
    pin = (CA if selected else GF) if known else (CA if selected else GA)
    body = PA if known else DK
    edge = (CA if selected else BO) if known else (CA if selected else GA)
    # Patas: 3 por lado, de 2x3 (o 3x2), separadas 2 px.
    for k in range(3):
        c = 7 + k * 4
        cv.rect(c, 0, c + 1, 2, pin)
        cv.rect(c, CHIP - 3, c + 1, CHIP - 1, pin)
        cv.rect(0, c, 2, c + 1, pin)
        cv.rect(CHIP - 3, c, CHIP - 1, c + 1, pin)
    # Cuerpo de 20x20 con contorno oscuro y bisel.
    cv.box(2, 2, CHIP - 3, CHIP - 3, edge, outline=FP, cut=True)
    cv.rect(4, 4, CHIP - 5, CHIP - 5, body)
    cv.hline(4, CHIP - 5, 4, SO if not known else TR)
    # Muesca de orientacion (circuito).
    cv.p(5, 6, edge)
    if known:
        cmap = {"#": TC, "+": CA if not selected else CB, "o": CT}
    else:
        cmap = {"#": CA if selected else TT, "+": TT, "o": GA}
    cv.stamp(6, 6, ICON_ART[icon], cmap)
    return cv


def lock(cv, x, y, color, shade):
    """Mini candado de 5x5 (arco de 3x2 y cuerpo de 5x3 con ojo)."""
    cv.rect(x + 1, y, x + 3, y, color)
    cv.p(x + 1, y + 1, color)
    cv.p(x + 3, y + 1, color)
    cv.rect(x, y + 2, x + 4, y + 4, color)
    cv.p(x + 2, y + 3, shade)


def box(state):
    """Recuadro de nivel de 10x14."""
    cv = Canvas(BOX_W, BOX_H)
    x1, y1 = BOX_W - 1, BOX_H - 1
    if state == "full":
        cv.rect(0, 0, x1, y1, CT)
        cv.rect(1, 1, x1 - 1, y1 - 1, CA)
        cv.hline(1, x1 - 1, 1, CB)
    elif state in ("next_a", "next_b"):
        ring = AM if state == "next_a" else AS
        cv.rect(0, 0, x1, y1, ring)
        cv.rect(1, 1, x1 - 1, y1 - 1, SO)
        if state == "next_a":
            cv.hline(2, x1 - 2, y1 - 2, AS)
    elif state == "empty":
        cv.rect(0, 0, x1, y1, GF)
        cv.rect(1, 1, x1 - 1, y1 - 1, SO)
    elif state == "locked":
        cv.rect(0, 0, x1, y1, GA)
        cv.rect(1, 1, x1 - 1, y1 - 1, DK)
        lock(cv, 2, 5, TT, DK)
    elif state == "soon":
        cv.rect(0, 0, x1, y1, SO)
        for x in range(BOX_W):
            if x % 2 == 0:
                cv.p(x, 0, GA)
                cv.p(x, y1, GA)
        for y in range(BOX_H):
            if y % 2 == 0:
                cv.p(0, y, GA)
                cv.p(x1, y, GA)
        for y in (4, 7, 10):
            cv.rect(4, y - 1, 5, y, GF)
    elif state == "unknown":
        cv.rect(0, 0, x1, y1, GA)
        cv.rect(1, 1, x1 - 1, y1 - 1, BA)
    elif state.startswith("fill_"):
        step = int(state[-1])  # 1-3: un cuarto, la mitad, tres cuartos
        cv.rect(0, 0, x1, y1, AM)
        cv.rect(1, 1, x1 - 1, y1 - 1, SO)
        top = y1 - 1 - round((BOX_H - 2) * step / 4) + 1
        cv.rect(1, top, x1 - 1, y1 - 1, CA)
        cv.hline(1, x1 - 1, top, CB)
    elif state == "flash":
        cv.rect(0, 0, x1, y1, CA)
        cv.rect(1, 1, x1 - 1, y1 - 1, CB)
    else:
        raise ValueError(state)
    return cv


def outputs():
    """Ruta (relativa al repo) -> imagen."""
    sheet = Image.new("RGBA", (CHIP * len(ICONS), CHIP * len(CHIP_ROWS)), CLEAR)
    for row, name in enumerate(CHIP_ROWS):
        for col, icon in enumerate(ICONS):
            sheet.paste(chip(icon, name == "selected").img, (col * CHIP, row * CHIP))
    boxes = Image.new("RGBA", (BOX_W * len(BOXES), BOX_H), CLEAR)
    for col, state in enumerate(BOXES):
        boxes.paste(box(state).img, (col * BOX_W, 0))
    return {CHIPS_PATH: sheet, BOXES_PATH: boxes}


def preview(scale=6):
    """Hoja de contacto: los chips y, debajo, cinco filas de ejemplo como en la tienda."""
    outs = outputs()
    chips, boxes = outs[CHIPS_PATH], outs[BOXES_PATH]
    w = max(chips.width, 24 + 4 + 5 * (BOX_W + 2)) + 8
    rows = [("pulse", ["full", "full", "next_a", "locked", "locked"]),
            ("laser", ["full", "full", "full", "locked", "locked"]),
            ("unknown", ["unknown"] * 5),
            ("sync", ["full", "next_b", "empty", "locked", "locked"]),
            ("energy", ["full", "fill_2", "empty", "soon", "locked"])]
    h = chips.height + 8 + len(rows) * 26 + 8 + BOX_H + 8
    img = Image.new("RGBA", (w, h), PA)
    img.alpha_composite(chips, (4, 4))
    y = chips.height + 8
    for icon, states in rows:
        col = ICONS.index(icon)
        img.alpha_composite(chips.crop((col * CHIP, 0, col * CHIP + CHIP, CHIP)), (4, y))
        for i, state in enumerate(states):
            k = BOXES.index(state)
            img.alpha_composite(boxes.crop((k * BOX_W, 0, k * BOX_W + BOX_W, BOX_H)), (32 + i * (BOX_W + 2), y + 5))
        y += 26
    img.alpha_composite(boxes, (4, y + 4))
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def main(argv):
    dry = "--dry-run" in argv
    if "--preview" in argv:
        path = argv[argv.index("--preview") + 1]
        scale = int(argv[argv.index("--scale") + 1]) if "--scale" in argv else 6
        preview(scale).save(path)
        print("vista previa:", path)
    if dry:
        return 0
    for rel, img in outputs().items():
        path = os.path.join(REPO, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)
        print("escrito", rel)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
