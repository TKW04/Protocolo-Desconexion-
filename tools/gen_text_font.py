#!/usr/bin/env python3
"""Genera la fuente bitmap propia para textos en espanol (cuadro de Eco, interfaz).

Glifos pixel art propios (sin fuentes externas) en banner_blanco sobre transparente, con la
paleta del Mundo 1. Metricas (pixeles de arte; ver data/text_font.json -> _notes):
  celda de 12 filas, tamano 12, interlineado 13 (lineHeight del .fnt), base 10
  filas 0-2   zona de acentos de las mayusculas (acento de 2 filas + 1 de aire)
  filas 3-9   mayusculas (7 filas), ascendentes de b d f h k l t
  filas 5-9   altura x de las minusculas (acentos de minuscula en 2-3, punto de i/j en 3)
  filas 10-11 descendentes (g j p q y , ; ¡ ¿)
Ancho proporcional (avance = ancho + 1); digitos iguales a los del HUD (5x7, avance 6).
Las letras acentuadas se componen: letra base + marca (aguda, dieresis, virgulilla).

Salidas:
  assets/sprites/ui/text_font.png   atlas (celdas de 8x16; columnas/filas de data/text_font.json)
  assets/sprites/ui/text_font.fnt   descripcion BMFont (texto) que Godot importa como FontFile
  assets/sprites/ui/text_font_lcd.fnt  la MISMA fuente (mismo atlas y metricas) con avance fijo
                                    (monoespaciada; lcd_advance de data/text_font.json): estilo
                                    LCD de Calc en el cuadro de texto (2026-10-17, tanda H3 del
                                    paso 14 del 1-2). Cada glifo va centrado en su celda; los mas
                                    anchos que la celda (rombo del icono en linea, raya) conservan
                                    su avance proporcional. Digitos: los del HUD, como siempre.
  assets/sprites/ui/_text_font_preview_x4.png  todos los glifos y frases de prueba x4 (no la usa el juego)

Uso: python3 tools/gen_text_font.py
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_hud_assets as ga  # noqa: E402  (paleta y rutas)
import gen_hud_font as hf  # noqa: E402  (digitos del HUD)

ROOT = ga.ROOT
P = ga.P
DATA = os.path.join(ROOT, "data", "text_font.json")
FNT_PATH = os.path.join(ga.OUT_DIR, "text_font.fnt")
LCD_FNT_PATH = os.path.join(ga.OUT_DIR, "text_font_lcd.fnt")
LCD_FACE = "IsakTextLCD"
PREVIEW = os.path.join(ga.OUT_DIR, "_text_font_preview_x4.png")
PREVIEW_SCALE = 4
FACE = "IsakText"
COLOR = "banner_blanco"
LINE_HEIGHT = 12     # alto de la celda del glifo (y tamano de la fuente)
LINE_ADVANCE = 13    # lineHeight del .fnt: 1 fila de aire entre lineas (descendente / acento)
BASE = 10            # fila de la linea base (las letras terminan en la fila 9)
BLOCK_TOP = 3        # primera fila del bloque de 9 filas (7 sobre la base + 2 descendentes)
SPACE_ADVANCE = 3
DIGIT_ADVANCE = 6

# --- Glifos base: 7 filas (sobre la base) o 9 (con descendentes), en coordenadas del bloque. ---
UPPER = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
}


def x_height(rows, desc=None):
    """Minuscula sin ascendente: 2 filas vacias + 5 de altura x (+ 2 de descendente)."""
    w = len(rows[0])
    return ["." * w] * 2 + rows + (desc or [])


LOWER = {
    "a": x_height([".###.", "....#", ".####", "#...#", ".####"]),
    "b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####."],
    "c": x_height([".####", "#....", "#....", "#....", ".####"]),
    "d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####"],
    "e": x_height([".###.", "#...#", "#####", "#....", ".###."]),
    "f": ["..##", ".#..", "####", ".#..", ".#..", ".#..", ".#.."],
    "g": x_height([".####", "#...#", "#...#", "#...#", ".####"], ["....#", ".###."]),
    "h": ["#....", "#....", "#.##.", "##..#", "#...#", "#...#", "#...#"],
    "i": ["#", ".", "#", "#", "#", "#", "#"],
    "j": ["...#", "....", "...#", "...#", "...#", "...#", "...#", "#..#", ".##."],
    "k": ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#"],
    "l": ["#.", "#.", "#.", "#.", "#.", "#.", ".#"],
    "m": x_height(["##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"]),
    "n": x_height(["#.##.", "##..#", "#...#", "#...#", "#...#"]),
    "o": x_height([".###.", "#...#", "#...#", "#...#", ".###."]),
    "p": x_height(["####.", "#...#", "#...#", "#...#", "####."], ["#....", "#...."]),
    "q": x_height([".####", "#...#", "#...#", "#...#", ".####"], ["....#", "....#"]),
    "r": x_height(["#.##", "##..", "#...", "#...", "#..."]),
    "s": x_height([".####", "#....", ".###.", "....#", "####."]),
    "t": ["....", ".#..", "####", ".#..", ".#..", ".#..", "..##"],
    "u": x_height(["#...#", "#...#", "#...#", "#..##", ".##.#"]),
    "v": x_height(["#...#", "#...#", "#...#", ".#.#.", "..#.."]),
    "w": x_height(["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."]),
    "x": x_height(["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]),
    "y": x_height(["#...#", "#...#", "#...#", "#...#", ".####"], ["....#", ".###."]),
    "z": x_height(["#####", "...#.", "..#..", ".#...", "#####"]),
}
# Bases sin punto para las vocales minusculas acentuadas (i sin punto).
DOTLESS = {"i": ["."] * 2 + ["#"] * 5}

PUNCT = {
    ".": ["."] * 6 + ["#"],
    ",": [".."] * 6 + [".#", "#."],
    ";": ["..", "..", ".#", "..", "..", "..", ".#", "#."],
    ":": [".", ".", "#", ".", ".", ".", "#"],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    "¡": [".", ".", "#", ".", "#", "#", "#", "#", "#"],
    "?": [".##.", "#..#", "...#", "..#.", ".#..", "....", ".#.."],
    "¿": ["....", "....", "..#.", "....", "..#.", ".#..", "#...", "#..#", ".##."],
    "-": ["..."] * 4 + ["###", "...", "..."],
    "–": ["....."] * 4 + ["#####", ".....", "....."],
    "—": ["......."] * 4 + ["#######", ".......", "......."],
    '"': ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    "(": ["..#", ".#.", "#..", "#..", "#..", "#..", ".#.", "..#"],
    ")": ["#..", ".#.", "..#", "..#", "..#", "..#", ".#.", "#.."],
    "/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
    "+": [".....", ".....", "..#..", "..#..", "#####", "..#..", "..#.."],
    "…": ["....."] * 6 + ["#.#.#"],
    # Indicacion de tecla para cerrar las lineas importantes de Eco ("▼ [Espacio]", 2026-10-15).
    "[": ["##", "#.", "#.", "#.", "#.", "#.", "#.", "##"],
    "]": ["##", ".#", ".#", ".#", ".#", ".#", ".#", "##"],
    "▼": ["....."] * 3 + ["#####", ".###.", "..#..", "....."],
    # Hueco del icono en linea del punto de atencion (2026-10-17, marcador {icono:atencion} de
    # data/eco_text_box.json): el ancho del icono; el cuadro de Eco dibuja encima el rombo ambar.
    "◆": ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
    # Comillas angulares y punto medio de los textos de los recuerdos (2026-10-19): centrados en
    # la altura x (fila 7 de la celda), sin tocar la base.
    "«": ["...."] * 3 + [".#.#", "#.#.", ".#.#", "...."],
    "»": ["...."] * 3 + ["#.#.", ".#.#", "#.#.", "...."],
    "·": ["."] * 4 + ["#", ".", "."],
}

# --- Marcas diacriticas: (filas, fila de inicio en la celda para mayuscula, para minuscula). ---
ACUTE = [".#", "#."]          # se apoya con su pixel inferior izquierdo sobre la columna central
DIAERESIS = [".#.#."]
TILDE = [".##.#", "#..#."]
MARKS = {
    "acute": (ACUTE, 0, 2),
    "diaeresis": (DIAERESIS, 1, 3),
    "tilde": (TILDE, 0, 2),
}
COMPOSED = {
    "Á": ("A", "acute"), "É": ("E", "acute"), "Í": ("I", "acute"), "Ó": ("O", "acute"),
    "Ú": ("U", "acute"), "Ü": ("U", "diaeresis"), "Ñ": ("N", "tilde"),
    "á": ("a", "acute"), "é": ("e", "acute"), "í": ("i", "acute"), "ó": ("o", "acute"),
    "ú": ("u", "acute"), "ü": ("u", "diaeresis"), "ñ": ("n", "tilde"),
}


def to_cell(block_rows):
    """Coloca un glifo de bloque (7 o 9 filas) en una celda de LINE_HEIGHT filas."""
    w = len(block_rows[0])
    assert all(len(r) == w for r in block_rows), block_rows
    assert len(block_rows) in (7, 8, 9), block_rows
    rows = ["." * w] * BLOCK_TOP + list(block_rows)
    rows += ["." * w] * (LINE_HEIGHT - len(rows))
    return rows


def compose(base_ch, mark):
    base = DOTLESS.get(base_ch, None) or UPPER.get(base_ch) or LOWER[base_ch]
    cell = [list(r) for r in to_cell(base)]
    rows, upper_row, lower_row = MARKS[mark]
    top = upper_row if base_ch.isupper() else lower_row
    w = len(cell[0])
    mw = len(rows[0])
    if mark == "acute":
        x0 = w // 2
    else:
        x0 = (w - mw) // 2
    new_w = max(w, x0 + mw)
    for line in cell:
        line.extend("." * (new_w - w))
    for dy, line in enumerate(rows):
        for dx, v in enumerate(line):
            if v == "#":
                assert cell[top + dy][x0 + dx] == ".", (base_ch, mark)
                cell[top + dy][x0 + dx] = "#"
    return ["".join(r) for r in cell]


def build_glyphs():
    glyphs = {}
    for ch, rows in list(UPPER.items()) + list(LOWER.items()) + list(PUNCT.items()):
        glyphs[ch] = to_cell(rows)
    for ch, (base, mark) in COMPOSED.items():
        glyphs[ch] = compose(base, mark)
    for ch in "0123456789%":
        glyphs[ch] = to_cell(hf.GLYPHS[ch])
    return glyphs


def advance_of(ch, width):
    return DIGIT_ADVANCE if ch.isdigit() else width + 1


def lcd_metrics(width, cell):
    """(xoffset, avance) monoespaciado: centrado en la celda de `cell` (ancho maximo cell - 1)."""
    if width + 1 > cell:
        return 0, width + 1
    return (cell - 1 - width) // 2, cell


def fnt_lines(face, atlas, png_path, chars):
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 '
        'padding=0,0,0,0 spacing=0,0 outline=0' % (face, LINE_HEIGHT),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
        "alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0" % (LINE_ADVANCE, BASE, atlas.width, atlas.height),
        'page id=0 file="%s"' % os.path.basename(png_path),
        "chars count=%d" % len(chars),
    ]
    for cid, x, y, w, h, xo, yo, adv in sorted(chars):
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
                     % (cid, x, y, w, h, xo, yo, adv))
    return lines


def main():
    with open(DATA, encoding="utf-8") as fh:
        data = json.load(fh)
    spec = data["assets"]["font"]
    glyphs = build_glyphs()
    missing = [c for c in data["font_glyphs"] if c != " " and c not in glyphs]
    extra = [c for c in glyphs if c not in data["font_glyphs"]]
    if missing or extra:
        print("gen_text_font: faltan %s / sobran %s respecto a font_glyphs" % (missing, extra))
        return 1
    if data["font_size"] != LINE_HEIGHT:
        print("gen_text_font: font_size %s distinto de %d" % (data["font_size"], LINE_HEIGHT))
        return 1
    fw, fh = spec["frame_size"]
    cols, rows = spec["columns"], spec["rows"]
    if len(glyphs) > cols * rows:
        print("gen_text_font: el atlas no tiene celdas para %d glifos" % len(glyphs))
        return 1
    atlas = Image.new("RGBA", (fw * cols, fh * rows), ga.CLEAR)
    chars = []
    order = [c for c in data["font_glyphs"] if c != " "]
    for i, ch in enumerate(order):
        cell = glyphs[ch]
        width = len(cell[0])
        assert width <= fw and len(cell) == LINE_HEIGHT <= fh, ch
        cx, cy = (i % cols) * fw, (i // cols) * fh
        for y, line in enumerate(cell):
            for x, v in enumerate(line):
                if v == "#":
                    atlas.putpixel((cx + x, cy + y), P[COLOR])
        chars.append((ord(ch), cx, cy, width, LINE_HEIGHT, 0, 0, advance_of(ch, width)))
    chars.append((ord(" "), 0, 0, 0, 0, 0, 0, SPACE_ADVANCE))
    png_path = ga.res_to_path(spec["path"])
    atlas.save(png_path)
    with open(FNT_PATH, "w", encoding="utf-8") as fh_out:
        fh_out.write("\n".join(fnt_lines(FACE, atlas, png_path, chars)) + "\n")
    cell = int(data["lcd_advance"])
    lcd = []
    for cid, x, y, w, h, _, yo, _ in chars:
        xo, adv = lcd_metrics(w, cell) if cid != ord(" ") else (0, cell)
        lcd.append((cid, x, y, w, h, xo, yo, adv))
    with open(LCD_FNT_PATH, "w", encoding="utf-8") as fh_out:
        fh_out.write("\n".join(fnt_lines(LCD_FACE, atlas, png_path, lcd)) + "\n")
    write_preview(atlas, {chr(c[0]): c for c in chars}, order)
    print("gen_text_font: %s, %s (%d glifos)" % (spec["path"], os.path.relpath(FNT_PATH, ROOT), len(chars)))
    return 0


# --- Vista de verificacion ---
SAMPLES = [
    "Bienvenido. He optimizado tu espacio.",
    "Marcar como leído",
    "¿Qué pasa, señor Ñandú? ¡Cuidado!",
    "ÁÉÍÓÚ áéíóú ü ñ Ü Ñ",
    "¿Seguro que quieres seguir concentrado? Tenemos ofertas",
    "gjpqy / g q / o ó / i í l 1 I 100 % x3 12:00 (sí) \"no\" 'ya' a-b c–d e—f…",
    "«Abuelito» · Mamá · «¿Comiste?»",
]
PARAGRAPH = ("Hemos detectado que estás feliz. Esto es un error. Mira cuánto tiempo ahorramos "
             "juntos; yo decido por ti, así no te equivocas. ¿Por qué querrías volver? "
             "Pingüino, cigüeña, año, niño, mañana: 3 + 4 son 7 – 100 % optimizado.")
WRAP_WIDTH = 200
MARGIN = 4


def text_width(text, adv):
    return sum(adv[ch][7] for ch in text)


def wrap(text, adv, width):
    out, line = [], ""
    for word in text.split(" "):
        cand = word if not line else line + " " + word
        if text_width(cand, adv) <= width or not line:
            line = cand
        else:
            out.append(line)
            line = word
    out.append(line)
    return out


def write_preview(atlas, adv, order):
    lines = []
    per_row = 24
    for i in range(0, len(order), per_row):
        lines.append(" ".join(order[i:i + per_row]))
    lines.append("")
    lines += SAMPLES
    lines.append("")
    lines += wrap(PARAGRAPH, adv, WRAP_WIDTH)
    width = max(text_width(t, adv) for t in lines) + MARGIN * 2
    width = max(width, WRAP_WIDTH + MARGIN * 2)
    img = Image.new("RGBA", (width, LINE_ADVANCE * len(lines) + MARGIN * 2), P["noche_profunda"])
    for row, text in enumerate(lines):
        x, y = MARGIN, MARGIN + row * LINE_ADVANCE
        for ch in text:
            _, gx, gy, gw, gh, _, _, a = adv[ch]
            if gw:
                img.alpha_composite(atlas.crop((gx, gy, gx + gw, gy + gh)), (x, y))
            x += a
    img.resize((img.width * PREVIEW_SCALE, img.height * PREVIEW_SCALE), Image.NEAREST).save(PREVIEW)


if __name__ == "__main__":
    sys.exit(main())
