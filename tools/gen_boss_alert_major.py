#!/usr/bin/env python3
"""Arte PROVISIONAL de Alerta Mayor, el jefe del Mundo 1 (pasos 5-8 de docs/propuesta-jefe-alerta-mayor.md
§6, 2026-10-21). Sufijo _placeholder (regla 3 de CLAUDE.md). Aqui no se gasta nada: es un dibujo por script.

El CUERPO del jefe (reposo, inflado, bajada, subida, ventana, copias y lanzamiento) tiene arte FINAL desde
el paso 16 (2026-10-22, AutoSprite): tools/import_boss_alert_major.py y AlertMajorBody. Aqui quedan las
piezas que siguen por script (interfaz y efectos; docs/plan-arte-jefe-alerta-mayor.md §2.1):
  alert_major_pop_placeholder.png       64x64   «pop» de una copia descartada (dibujado a x2)
  notification_shot_placeholder.png     64x32   notificacion de la rafaga (fase 2)
  alert_major_shield_placeholder.png    32x32   icono del pop-up escudo (candado sobre la campana)
  boss_bar_icon_placeholder.png         16x16   icono de la barra del jefe en el HUD (paso 9; BossBar)
  boss_bar_frame_placeholder.png        16x16   marco nine-patch (4 px) de la barra del jefe
  boss_reward_panel_placeholder.png     16x16   marco nine-patch (4 px) del panel de la recompensa (BossReward)
  alert_major_core_card_placeholder.png 64x64   ficha del album del nucleo marcado (UNICA con carmin)
  eco_boss_icon_placeholder.png         16x16   icono de Eco hablando por el jefe (eco_icon con interferencia)
El desarme en pixeles no tiene arte propio: PixelBurst suelta los pixeles de la textura del cuerpo.
Solo colores de assets/palettes/mundo1.gpl y SIN carmin ni carmin_brillo: el carmin es solo del nucleo
(WeakPoint, que se dibuja aparte; y su ficha del album, CARMIN_OK). Fondo transparente, alfa 0 o 255.

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


def bar_icon():
    """Icono de la barra del jefe en el HUD (paso 9): el badge en miniatura con una campana."""
    cv = Canvas(16, 16)
    disk(cv, 8, 8, 7, A)
    cv.rect(7, 4, 8, 4, W)
    cv.rect(6, 5, 9, 9, W)
    cv.rect(5, 10, 10, 10, W)
    cv.rect(7, 11, 8, 11, W)
    return cv.img


def bar_frame():
    """Marco nine-patch (4 px de margen) de la barra del jefe: fondo noche_profunda, borde banner_gris."""
    cv = Canvas(16, 16)
    cv.box(0, 0, 15, 15, N, outline=G)
    cv.hline(2, 13, 1, AS)
    return cv.img


def reward_panel():
    """Marco nine-patch (4 px) del panel de la recompensa (paso 11; BossReward): noche_profunda con borde
    borde_luz y un filete resplandor dentro; las esquinas de banner_blanco (sin rojos: es un recuerdo)."""
    cv = Canvas(16, 16)
    cv.box(0, 0, 15, 15, N, outline=B)
    cv.rect(2, 2, 13, 2, PAL["resplandor"])
    cv.rect(2, 13, 13, 13, PAL["resplandor"])
    for x, y in ((1, 1), (14, 1), (1, 14), (14, 14)):
        cv.p(x, y, W)
    return cv.img


def core_card():
    """Ficha del album del nucleo marcado (paso 11; ayuda alert_major_core): el nucleo carmin con su brillo y
    el halo de la marca en 8 segmentos banner_blanco. UNICA pieza de este script con carmin (es el nucleo)."""
    import math
    cv = Canvas(64, 64)
    c = 32.0
    for y in range(64):
        for x in range(64):
            d = ((x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2) ** 0.5
            ang = math.degrees(math.atan2(y + 0.5 - c, x + 0.5 - c)) % 45.0
            if 24 <= d <= 28 and 5.0 <= ang <= 40.0:
                cv.p(x, y, W)
            elif 20 < d <= 22:
                cv.p(x, y, N)
            elif d <= 20:
                cv.p(x, y, PAL["carmin"] if d > 8 else PAL["carmin_brillo"])
    for i in range(5):
        cv.p(22 + i, 19 - i // 2, PAL["carmin_brillo"])
    return cv.img


def eco_boss_icon():
    """Icono de Eco hablando por el jefe (paso 12; interlocutor eco_boss del cuadro de texto): el icono de
    Eco (assets/sprites/ui/eco_icon.png) con dos franjas desplazadas como interferencia."""
    src = Image.open(os.path.join(REPO, "assets", "sprites", "ui", "eco_icon.png")).convert("RGBA")
    out = src.copy()
    for rows, dx in (((4, 5), 2), ((10, 11), -2)):
        for y in rows:
            for x in range(16):
                out.putpixel((x, y), src.getpixel(((x - dx) % 16, y)) if 0 <= x - dx < 16 else CLEAR)
    for x in range(3, 13, 3):
        if out.getpixel((x, 8))[3] == 255:
            out.putpixel((x, 8), G + (255,) if len(G) == 3 else G)
    return out


# Piezas que pueden llevar carmin (solo el nucleo).
CARMIN_OK = (DIR + "alert_major_core_card_placeholder.png",)


def outputs():
    return {
        DIR + "boss_reward_panel_placeholder.png": reward_panel(),
        DIR + "eco_boss_icon_placeholder.png": eco_boss_icon(),
        DIR + "alert_major_core_card_placeholder.png": core_card(),
        DIR + "boss_bar_icon_placeholder.png": bar_icon(),
        DIR + "boss_bar_frame_placeholder.png": bar_frame(),
        DIR + "alert_major_pop_placeholder.png": pop(),
        DIR + "notification_shot_placeholder.png": shot(),
        DIR + "alert_major_shield_placeholder.png": shield_icon(),
    }


def check_palette(img, carmin=False):
    allowed = {tuple(v[:3]) for k, v in PAL.items() if carmin or k not in FORBIDDEN}
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
        problem = check_palette(img, rel in CARMIN_OK)
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
