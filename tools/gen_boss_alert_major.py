#!/usr/bin/env python3
"""Arte PROVISIONAL de Alerta Mayor, el jefe del Mundo 1 (pasos 5-8 de docs/propuesta-jefe-alerta-mayor.md
§6, 2026-10-21). Sufijo _placeholder (regla 3 de CLAUDE.md): el arte final llega en el paso 16 con
AutoSprite y su coste aprobado por el usuario. Aqui no se gasta nada: es un dibujo por script.

Un badge redondo rojo anaranjado (alerta, sombra alerta_sombra, contorno noche_profunda y brillo
banner_blanco) con una campana; el contador («99+», «66»...) lo escribe el juego encima con la fuente de
textos. Estados (se dibujan a draw_scale x2 de data/bosses/alert_major.json):
  alert_major_rest_placeholder.png     128x128  inflado, flotando (4 x 4 tiles en pantalla)
  alert_major_inflate_placeholder.png  128x128  inflandose: aviso de escupir, dividirse (contorno blanco)
  alert_major_down_placeholder.png      64x64   desinflado, abajo (ventana; 2 x 2 tiles); tambien cada copia
  alert_major_clone_placeholder.png     64x64   copia de la fase 3: IGUAL que el desinflado a proposito
                                                (solo el Debug distingue la real por su nucleo)
  alert_major_lunge_placeholder.png     64x64   copia lanzandose (estirada, con estela)
  alert_major_pop_placeholder.png       64x64   «pop» de una copia descartada / desarme en pixeles
  notification_shot_placeholder.png     64x32   notificacion de la rafaga (fase 2)
  alert_major_shield_placeholder.png    32x32   icono del pop-up escudo (candado sobre la campana)
Solo colores de assets/palettes/mundo1.gpl y SIN carmin ni carmin_brillo: el carmin es solo del nucleo
(WeakPoint, que se dibuja aparte). Fondo transparente, alfa 0 o 255.

Uso (desde la raiz del repo):
  python3 tools/gen_boss_alert_major.py           escribe los PNG
  python3 tools/gen_boss_alert_major.py --check   sale con 1 si no estan al dia o la paleta no se cumple
                                                  (tests/test_boss_data.py, en tools/run_tests.sh)
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
B = PAL["borde_luz"]
CLEAR = (0, 0, 0, 0)
FORBIDDEN = ("carmin", "carmin_brillo")
DIR = "bosses/"

BELL = [
    "....##....",
    "...####...",
    "..######..",
    "..######..",
    "..######..",
    ".########.",
    "##########",
    "....##....",
]
LOCK = [
    "..####..",
    ".#....#.",
    ".#....#.",
    "########",
    "###..###",
    "###..###",
    "########",
]


def disk(cv, cx, cy, r, fill, outline=N, shade=AS, light=W):
    """Disco con contorno de 1 px, sombra abajo y un brillo arriba a la izquierda."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if d <= r - 1:
                cv.p(x, y, shade if y > cy + r * 0.75 else fill)
            elif d <= r:
                cv.p(x, y, outline)
    for i in range(int(r * 0.35)):
        cv.p(int(cx - r * 0.55) + i, int(cy - r * 0.6) - i // 3, light)


def stamp(cv, ox, oy, rows, color, scale=1):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                cv.rect(ox + i * scale, oy + j * scale, ox + i * scale + scale - 1, oy + j * scale + scale - 1, color)


def badge(size, r, outline=N, bell_scale=2):
    cv = Canvas(size, size)
    c = size / 2.0
    disk(cv, c, c, r, A, outline=outline)
    w = len(BELL[0]) * bell_scale
    stamp(cv, int(c - w / 2), int(c + r * 0.3), BELL, W, bell_scale)
    return cv.img


def lunge():
    cv = Canvas(64, 64)
    for i, x in enumerate((6, 12, 18)):
        cv.rect(x, 30 - i, x + 3, 33 + i, G)
    disk(cv, 38, 32, 22, A)
    stamp(cv, 28, 36, BELL, W, 2)
    return cv.img


def pop():
    cv = Canvas(64, 64)
    pts = [(10, 12), (50, 10), (32, 4), (6, 34), (58, 30), (14, 54), (48, 54), (32, 60), (22, 24), (42, 22),
           (24, 44), (40, 42)]
    for i, (x, y) in enumerate(pts):
        color = (A, AS, W)[i % 3]
        cv.rect(x, y, x + 3, y + 3, color)
        cv.p(x - 1, y - 1, N)
    return cv.img


def shot():
    cv = Canvas(64, 32)
    cv.box(2, 4, 61, 27, W, outline=N)
    cv.rect(3, 23, 60, 26, G)
    disk(cv, 14, 16, 8, A)
    for x in range(26, 56, 6):
        cv.rect(x, 11, x + 3, 12, G)
        cv.rect(x, 18, x + 2, 19, G)
    return cv.img


def shield_icon():
    cv = Canvas(32, 32)
    cv.box(2, 2, 29, 29, W, outline=N)
    stamp(cv, 6, 10, LOCK, N, 2)
    return cv.img


def outputs():
    return {
        DIR + "alert_major_rest_placeholder.png": badge(128, 58, bell_scale=3),
        DIR + "alert_major_inflate_placeholder.png": badge(128, 62, outline=W, bell_scale=3),
        DIR + "alert_major_down_placeholder.png": badge(64, 28, bell_scale=1),
        DIR + "alert_major_clone_placeholder.png": badge(64, 28, bell_scale=1),
        DIR + "alert_major_lunge_placeholder.png": lunge(),
        DIR + "alert_major_pop_placeholder.png": pop(),
        DIR + "notification_shot_placeholder.png": shot(),
        DIR + "alert_major_shield_placeholder.png": shield_icon(),
    }


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
                print("%s: no esta al dia (python3 tools/gen_boss_alert_major.py)" % rel)
                status = 1
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            img.save(path)
            print("escrito", rel)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
