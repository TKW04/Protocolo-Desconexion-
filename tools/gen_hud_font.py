#!/usr/bin/env python3
"""Genera la fuente bitmap propia del HUD (numeros y simbolos) con la paleta del Mundo 1.

Glifos de 5x7 pixeles de arte (':' de 1 px de ancho) en celdas de 8x8, dibujados en
banner_blanco sobre transparente. Digitos monoespaciados (avance 6) para que los numeros no
bailen. Se escriben:
  assets/sprites/ui/hud_font.png   atlas (cuadro, columnas y filas de data/hud.json -> assets.font)
  assets/sprites/ui/hud_font.fnt   descripcion BMFont (texto) que Godot importa como FontFile
  assets/sprites/ui/_hud_font_preview_x8.png   muestra ampliada x8 (no la usa el juego)

El juego la usa a su tamano (font_size de data/hud.json = SIZE) y la escala x2 entera con el
resto del HUD. Los glifos que el HUD necesita estan en data/hud.json -> font_glyphs; el
generador falla si falta alguno. Sin letras: el alcance para textos en espanol (A-Z, tildes,
n con tilde, signos de apertura) es una propuesta pendiente (docs/preguntas.md, A11).

Uso: python3 tools/gen_hud_font.py
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_hud_assets as ga  # noqa: E402  (paleta y rutas)

ROOT = ga.ROOT
P = ga.P
COLOR = "banner_blanco"
SIZE = 8          # tamano de la fuente (alto de linea) en pixeles de arte
BASE = 7          # linea base: los glifos ocupan las filas 0-6
SPACE_ADVANCE = 3
ADVANCE = 6       # 5 px de glifo + 1 de separacion
FNT_PATH = os.path.join(ga.OUT_DIR, "hud_font.fnt")
PREVIEW = os.path.join(ga.OUT_DIR, "_hud_font_preview_x8.png")
FACE = "IsakHudDigits"

GLYPHS = {
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    "x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    ":": [".", ".", "#", ".", ".", "#", "."],
}


def load_spec():
    with open(ga.HUD_JSON, encoding="utf-8") as fh:
        data = json.load(fh)
    return data, data["assets"]["font"]


def main():
    data, spec = load_spec()
    missing = [c for c in data["font_glyphs"] if c != " " and c not in GLYPHS]
    if missing:
        print("gen_hud_font: faltan glifos", missing)
        return 1
    if data["font_size"] != SIZE:
        print("gen_hud_font: font_size de data/hud.json (%s) distinto de %d" % (data["font_size"], SIZE))
        return 1
    fw, fh = spec["frame_size"]
    cols, rows = spec["columns"], spec["rows"]
    if len(GLYPHS) > cols * rows:
        print("gen_hud_font: el atlas no tiene celdas para %d glifos" % len(GLYPHS))
        return 1
    atlas = Image.new("RGBA", (fw * cols, fh * rows), ga.CLEAR)
    chars = []
    for i, (ch, rows_px) in enumerate(GLYPHS.items()):
        cx, cy = (i % cols) * fw, (i // cols) * fh
        width = len(rows_px[0])
        assert len(rows_px) == BASE and all(len(r) == width for r in rows_px), ch
        for y, line in enumerate(rows_px):
            for x, v in enumerate(line):
                if v == "#":
                    atlas.putpixel((cx + x, cy + y), P[COLOR])
        advance = ADVANCE if ch.isdigit() or width == 5 else width + 1
        chars.append((ord(ch), cx, cy, width, BASE, 0, 0, advance))
    chars.append((ord(" "), 0, 0, 0, 0, 0, 0, SPACE_ADVANCE))
    png_path = ga.res_to_path(spec["path"])
    atlas.save(png_path)
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 '
        'padding=0,0,0,0 spacing=0,0 outline=0' % (FACE, SIZE),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
        "alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0" % (SIZE, BASE, atlas.width, atlas.height),
        'page id=0 file="%s"' % os.path.basename(png_path),
        "chars count=%d" % len(chars),
    ]
    for cid, x, y, w, h, xo, yo, adv in sorted(chars):
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
                     % (cid, x, y, w, h, xo, yo, adv))
    with open(FNT_PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    # Muestra: "100 % 12 x3 12:00" con el avance real.
    sample = "100 % 50 % 15 % 12 x3 12:00"
    adv = {chr(c[0]): c for c in chars}
    w = sum(adv[ch][7] for ch in sample) + 4
    img = Image.new("RGBA", (w, SIZE + 4), P["noche_profunda"])
    x = 2
    for ch in sample:
        _, gx, gy, gw, gh, _, _, a = adv[ch]
        if gw:
            img.alpha_composite(atlas.crop((gx, gy, gx + gw, gy + gh)), (x, 2))
        x += a
    img.resize((img.width * 8, img.height * 8), Image.NEAREST).save(PREVIEW)
    print("gen_hud_font: %s, %s (%d glifos)" % (spec["path"], os.path.relpath(FNT_PATH, ROOT), len(chars)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
