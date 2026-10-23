#!/usr/bin/env python3
"""Arte PROVISIONAL del jefe del Mundo 2 «Autoplay» (2026-10-23, pasos 15-16 de docs/propuesta-mundo-2.md §8).

El cuerpo final saldra de AutoSprite (paso 23, con permiso del usuario); hasta entonces, formas planas con la
paleta B del Mundo 2 (assets/palettes/mundo2.gpl via tools/palette_mundo2_provisional.py) y el sufijo
_placeholder que pide CLAUDE.md para los jefes sin arte final. Las cajas y los tiempos ya son los definitivos
(data/bosses/autoplay.json); el arte final se encaja sin cambiarlos. En assets/sprites/bosses/:
  autoplay_screen_placeholder.png         pantalla 8 x 4 tiles (512 x 256) con marco de tarjeta y dos ojos-boton
                                          de play (magenta)
  autoplay_screen_paused_placeholder.png  la misma con los ojos en pausa (dos barras, gris): fotograma congelado
  autoplay_screen_off_placeholder.png     apagada (golpe final): negro y ojos apagados
  autoplay_stand_placeholder.png          pie de la pantalla (2 x 5 tiles, 128 x 320) hasta el suelo
  autoplay_playhead_placeholder.png       cabezal oculto: circulo gris (48 x 48) que se desliza por la barra
  autoplay_card_placeholder.png           tarjeta de la cinta (3 tiles, 192 x 24)
Los textos de la pantalla («A continuacion...», la cuenta, «x2») y las miniaturas de los clips los dibuja
scripts/bosses/autoplay.gd por codigo.

Uso: python3 -I tools/gen_boss_autoplay.py [--check]   (--check: 1 si algun PNG no esta al dia)
"""
import io
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo2_provisional as pal  # noqa: E402

OUT = os.path.join("assets", "sprites", "bosses")
C = {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in pal.COLORS + [pal.DEBUG]}


def rounded(d, box, r, fill):
    x0, y0, x1, y1 = box
    d.rectangle((x0 + r, y0, x1 - r, y1), fill=fill)
    d.rectangle((x0, y0 + r, x1, y1 - r), fill=fill)
    for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def screen(state):
    img = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rounded(d, (0, 0, 511, 255), 16, C["tarjeta_borde"])
    rounded(d, (6, 6, 505, 249), 12, C["tarjeta_sombra"])
    inner = C["feed_noche"] if state == "off" else C["feed_fondo"]
    rounded(d, (12, 12, 499, 243), 10, inner)
    if state != "off":
        # Bandas de un video borroso.
        for i, name in enumerate(("feed_medio", "feed_resplandor", "feed_medio")):
            d.rectangle((24, 150 + i * 22, 487, 160 + i * 22), fill=C[name])
    # Barra de progreso de la pantalla.
    d.rectangle((24, 222, 487, 227), fill=C["tarjeta_luz"])
    if state != "off":
        d.rectangle((24, 222, 200, 227), fill=C["magenta"])
    for cx in (176, 336):
        cy = 84
        ring = C["tarjeta_luz"] if state == "off" else (C["gris"] if state == "paused" else C["magenta"])
        d.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), fill=ring)
        d.ellipse((cx - 36, cy - 36, cx + 36, cy + 36), fill=C["feed_noche"])
        if state == "play":
            d.polygon([(cx - 12, cy - 20), (cx - 12, cy + 20), (cx + 20, cy)], fill=C["blanco"])
        elif state == "paused":
            d.rectangle((cx - 16, cy - 18, cx - 6, cy + 18), fill=C["gris"])
            d.rectangle((cx + 6, cy - 18, cx + 16, cy + 18), fill=C["gris"])
    return img


def stand():
    img = Image.new("RGBA", (128, 320), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((48, 0, 79, 299), fill=C["tarjeta_sombra"])
    d.rectangle((52, 0, 75, 299), fill=C["tarjeta_base"])
    d.rectangle((52, 0, 55, 299), fill=C["tarjeta_luz"])
    rounded(d, (8, 296, 119, 319), 6, C["tarjeta_luz"])
    rounded(d, (12, 300, 115, 319), 4, C["tarjeta_base"])
    return img


def playhead():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, 47, 47), fill=C["feed_noche"])
    d.ellipse((3, 3, 44, 44), fill=C["gris"])
    d.ellipse((12, 12, 35, 35), fill=C["blanco"])
    return img


def card():
    img = Image.new("RGBA", (192, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rounded(d, (0, 0, 191, 23), 5, C["tarjeta_base"])
    d.rectangle((5, 0, 186, 2), fill=C["tarjeta_borde"])
    d.rectangle((3, 3, 188, 6), fill=C["tarjeta_luz"])
    d.rectangle((5, 21, 186, 23), fill=C["tarjeta_sombra"])
    d.rectangle((12, 11, 60, 14), fill=C["magenta_sombra"])
    return img


def outputs():
    return {
        "autoplay_screen_placeholder.png": screen("play"),
        "autoplay_screen_paused_placeholder.png": screen("paused"),
        "autoplay_screen_off_placeholder.png": screen("off"),
        "autoplay_stand_placeholder.png": stand(),
        "autoplay_playhead_placeholder.png": playhead(),
        "autoplay_card_placeholder.png": card(),
    }


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=False)
    return buf.getvalue()


def main(argv):
    check = "--check" in argv
    stale = []
    for name, img in outputs().items():
        path = os.path.join(REPO, OUT, name)
        if check:
            if not os.path.exists(path):
                stale.append(name)
                continue
            with Image.open(path) as old:
                if old.convert("RGBA").tobytes() != img.tobytes() or old.size != img.size:
                    stale.append(name)
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(png_bytes(img))
            print("escrito", os.path.join(OUT, name))
    if check:
        for name in stale:
            print("desactualizado:", name)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
