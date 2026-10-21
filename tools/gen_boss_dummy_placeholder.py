#!/usr/bin/env python3
"""Arte PROVISIONAL del jefe «saco» de la sala boss_test (paso 3 de
docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21). Sufijo _placeholder (regla 3 de
CLAUDE.md): el arte final de Alerta Mayor llega en el paso 16, con AutoSprite y su coste
aprobado por el usuario. Aqui no se gasta nada: es un dibujo por script.

Un badge rojo anaranjado (alerta, con sombra alerta_sombra y contorno noche_profunda) con
«99+» en banner_blanco, en dos estados de 64x64 (se dibujan a x2, 128 px = 2x2 tiles):
  bosses/boss_dummy_up_placeholder.png    inflado, arriba (fuera de alcance)
  bosses/boss_dummy_down_placeholder.png  desinflado, abajo (ventana: se golpea el nucleo)
Solo colores de assets/palettes/mundo1.gpl y SIN carmin ni carmin_brillo: el carmin es solo
del nucleo (WeakPoint, que se dibuja aparte). Fondo transparente, alfa 0 o 255.

Uso (desde la raiz del repo):
  python3 tools/gen_boss_dummy_placeholder.py           escribe los PNG
  python3 tools/gen_boss_dummy_placeholder.py --check   sale con 1 si no estan al dia o la
                                                        paleta no se cumple (en tools/run_tests.sh)
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from gen_energy_objects import PAL, Canvas, REPO  # noqa: E402
from PIL import Image  # noqa: E402

N = PAL["noche_profunda"]
A = PAL["alerta"]
AS = PAL["alerta_sombra"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
FORBIDDEN = ("carmin", "carmin_brillo")
SIZE = 64
OUT = {
    "up": "bosses/boss_dummy_up_placeholder.png",
    "down": "bosses/boss_dummy_down_placeholder.png",
}
# Glifos de 3x5 para «99+».
GLYPHS = {
    "9": ["###", "#.#", "###", "..#", "###"],
    "+": ["...", ".#.", "###", ".#.", "..."],
}


def text(cv, x, y, s, color, scale):
    for ch in s:
        rows = GLYPHS[ch]
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c == "#":
                    cv.rect(x + i * scale, y + j * scale, x + i * scale + scale - 1, y + j * scale + scale - 1, color)
        x += 4 * scale


def badge(state):
    cv = Canvas(SIZE, SIZE)
    if state == "up":
        x0, y0, x1, y1 = 4, 4, 59, 59
    else:
        x0, y0, x1, y1 = 4, 24, 59, 63
    cv.box(x0, y0, x1, y1, A, outline=N)
    # Esquinas redondeadas: un pixel mas recortado.
    for x, y in ((x0 + 1, y0), (x0, y0 + 1), (x1 - 1, y0), (x1, y0 + 1),
                 (x0 + 1, y1), (x0, y1 - 1), (x1 - 1, y1), (x1, y1 - 1)):
        cv.p(x, y, (0, 0, 0, 0))
    cv.rect(x0 + 1, y1 - 4, x1 - 1, y1 - 1, AS)
    if state == "up":
        text(cv, 16, 23, "99+", W, 3)
    else:
        text(cv, 21, 37, "99+", G, 2)
    return cv.img


def outputs():
    return {path: badge(state) for state, path in OUT.items()}


def check_palette(img):
    allowed = {tuple(v[:3]) for k, v in PAL.items() if k not in FORBIDDEN}
    for (r, g, b, a) in img.getdata():
        if a not in (0, 255):
            return "alfa %d" % a
        if a == 255 and (r, g, b) not in allowed:
            return "color fuera de paleta (%d, %d, %d)" % (r, g, b)
    return None


def main(argv):
    check = "--check" in argv
    status = 0
    for rel, img in outputs().items():
        path = os.path.join(REPO, "assets", "sprites", rel)
        problem = check_palette(img)
        if problem:
            print("%s: %s" % (rel, problem))
            status = 1
        if check:
            if not os.path.exists(path) or list(Image.open(path).convert("RGBA").getdata()) != list(img.getdata()):
                print("%s: no esta al dia (python3 tools/gen_boss_dummy_placeholder.py)" % rel)
                status = 1
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            img.save(path)
            print("escrito", rel)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
