#!/usr/bin/env python3
"""Dibujos PROVISIONALES de las tarjetas del Mundo 2 para las fichas del album (2026-10-22,
paso 4 de docs/propuesta-mundo-2.md §8).

En el juego la tarjeta fragil y la Historia se dibujan por codigo (scripts/levels/feed_card_draw.gd);
el album de Notas necesita un PNG de origen por tipo de ayuda (tools/gen_album_cards.py), asi que
este script dibuja lo mismo, con la paleta PROVISIONAL del Mundo 2
(tools/palette_mundo2_provisional.py: hex sin cerrar), en assets/sprites/props/world2/:
  fragile_card_00.png   tarjeta de 1 tile (64 x 32) con la grieta a medias y 4 segmentos
  story_card_00.png     Historia de 1 tile (64 x 32) con la barra de progreso llena
  loop_sign_00.png      cartel «Solo uno mas» de la seccion en bucle (paso 5)
  autoplay_video_00.png video en autoplay (2 x 2 tiles a media escala, 64 x 64) con la miniatura de la ola
                        y el marco rojo del aviso (paso 6)
  video_clone_00.png    clon de «Un video mas» (48 x 40) con el triangulo de reproducir (paso 7)
  commenter_00.png      Comentarista (48 x 56) con su cara de texto «...» y un bocadillo inflandose (paso 7;
                        solo texto, sin AutoSprite)
  loading_wall_00.png   muro «Cargando mas...» (1 x 3 tiles a media escala, 32 x 96) con el circulo de carga
                        a un tercio (paso 7)
  pause_player_00.png   reproductor con el boton de pausa (2 x 1,4 tiles a media escala, 64 x 44) con la pantalla,
                        el boton «||» y la barra de progreso con el cabezal (paso 8)
El arte final del mundo (paso 10) los sustituira.

Uso: python3 -I tools/gen_world2_cards.py [--check]   (--check: 1 si algun PNG no esta al dia)
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo2_provisional as pal  # noqa: E402

OUT = os.path.join("assets", "sprites", "props", "world2")
COLORS = {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
          for name, value, _ in pal.COLORS + [pal.DEBUG]}


def card(fill="tarjeta_base", top=None):
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 4
    d.rectangle((r, 0, 63 - r, 31), fill=COLORS[fill])
    d.rectangle((0, r, 63, 31 - r), fill=COLORS[fill])
    d.rectangle((r, 0, 63 - r, 1), fill=COLORS["tarjeta_borde"])
    d.rectangle((2, 2, 61, 5), fill=COLORS["tarjeta_luz"])
    d.rectangle((r, 30, 63 - r, 31), fill=COLORS["tarjeta_sombra"])
    if top:
        d.rectangle((4, 0, 59, 1), fill=COLORS[top])
    return img, d


def segments(d, lit, count=4):
    width = (64 - 16 - 2 * (count - 1)) // count
    for i in range(count):
        x = 8 + i * (width + 2)
        d.rectangle((x, 8, x + width - 1, 10), fill=COLORS["blanco" if i < lit else "tarjeta_sombra"])


def fragile():
    img, d = card()
    points = [(32, 16), (38, 19), (44, 13), (50, 17)]
    d.line(points, fill=COLORS["blanco"], width=2)
    d.line([(32, 16), (26, 13), (20, 19), (14, 15)], fill=COLORS["blanco"], width=2)
    segments(d, 2)
    return img


def story():
    img, d = card("magenta_sombra", "magenta")
    segments(d, 4)
    return img


def loop_sign():
    """Cartel «Solo uno mas» (seccion en bucle) en miniatura: tarjeta con dos lineas de texto y una flecha
    circular."""
    img, d = card()
    d.rectangle((8, 12, 40, 14), fill=COLORS["blanco"])
    d.rectangle((8, 18, 30, 20), fill=COLORS["gris"])
    d.arc((44, 9, 56, 21), 30, 330, fill=COLORS["blanco"], width=2)
    d.polygon([(55, 9), (59, 13), (53, 14)], fill=COLORS["blanco"])
    return img


def autoplay_video():
    """Video en autoplay (paso 6) a media escala: tarjeta de 64 x 64 con la pantalla, la miniatura de la
    ola (tres lineas en zigzag) con el marco rojo del aviso y la barra de progreso del clip."""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 2
    d.rectangle((r, 0, 63 - r, 63), fill=COLORS["tarjeta_base"])
    d.rectangle((0, r, 63, 63 - r), fill=COLORS["tarjeta_base"])
    d.rectangle((r, 0, 63 - r, 0), fill=COLORS["tarjeta_borde"])
    d.rectangle((1, 1, 62, 2), fill=COLORS["tarjeta_luz"])
    d.rectangle((r, 63, 63 - r, 63), fill=COLORS["tarjeta_sombra"])
    d.rectangle((4, 6, 59, 50), fill=COLORS["alerta"])
    d.rectangle((6, 8, 57, 48), fill=COLORS["feed_noche"])
    for i in range(3):
        y = 16 + i * 10
        pts = [(9 + k * 8, y + (2 if (k + i) % 2 == 0 else -2)) for k in range(7)]
        d.line(pts, fill=COLORS["alerta"], width=2)
    d.rectangle((6, 55, 57, 56), fill=COLORS["tarjeta_sombra"])
    d.rectangle((6, 55, 34, 56), fill=COLORS["magenta"])
    return img


def small_card(w, h, fill="tarjeta_base"):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 3
    d.rectangle((r, 0, w - 1 - r, h - 1), fill=COLORS[fill])
    d.rectangle((0, r, w - 1, h - 1 - r), fill=COLORS[fill])
    d.rectangle((r, 0, w - 1 - r, 1), fill=COLORS["tarjeta_borde"])
    d.rectangle((2, 2, w - 3, 4), fill=COLORS["tarjeta_luz"])
    d.rectangle((r, h - 2, w - 1 - r, h - 1), fill=COLORS["tarjeta_sombra"])
    return img, d


def video_clone():
    """Clon (paso 7): tarjeta magenta oscura de 48 x 40 con su pantalla y el triangulo de reproducir."""
    img, d = small_card(48, 40, "magenta_sombra")
    d.rectangle((6, 8, 41, 31), fill=COLORS["feed_noche"])
    d.polygon([(19, 13), (19, 27), (31, 20)], fill=COLORS["blanco"])
    return img


def commenter():
    """Comentarista (paso 7, solo texto): tarjeta de 48 x 56 con «...» y un bocadillo blanco con borde rojo."""
    img, d = small_card(48, 56)
    for i in range(3):
        d.rectangle((13 + i * 9, 34, 16 + i * 9, 37), fill=COLORS["blanco"])
    d.rectangle((26, 10, 45, 21), fill=COLORS["alerta"])
    d.rectangle((28, 12, 43, 19), fill=COLORS["blanco"])
    d.polygon([(30, 21), (34, 21), (30, 25)], fill=COLORS["alerta"])
    return img


def loading_wall():
    """Muro «Cargando mas...» (paso 7) a media escala: 32 x 96 con un circulo de 3 segmentos (1 lleno)."""
    img, d = small_card(32, 96)
    box = (6, 38, 25, 57)
    d.arc(box, -90 + 7, 30 - 7, fill=COLORS["blanco"], width=3)
    d.arc(box, 30 + 7, 150 - 7, fill=COLORS["tarjeta_sombra"], width=3)
    d.arc(box, 150 + 7, 270 - 7, fill=COLORS["tarjeta_sombra"], width=3)
    d.rectangle((8, 84, 23, 85), fill=COLORS["gris"])
    return img


def pause_player():
    """Reproductor con el boton de pausa (paso 8) a media escala: 64 x 44 con la pantalla, el boton «||» en
    blanco y la barra de progreso con el cabezal magenta."""
    img, d = small_card(64, 44)
    d.rectangle((3, 4, 60, 31), fill=COLORS["feed_fondo"])
    d.rectangle((25, 10, 28, 25), fill=COLORS["blanco"])
    d.rectangle((35, 10, 38, 25), fill=COLORS["blanco"])
    d.rectangle((3, 36, 60, 37), fill=COLORS["tarjeta_sombra"])
    d.rectangle((3, 36, 38, 37), fill=COLORS["gris"])
    d.rectangle((37, 35, 39, 38), fill=COLORS["magenta"])
    return img


def outputs():
    return {"fragile_card_00.png": fragile(), "story_card_00.png": story(), "loop_sign_00.png": loop_sign(),
            "autoplay_video_00.png": autoplay_video(), "video_clone_00.png": video_clone(),
            "commenter_00.png": commenter(), "loading_wall_00.png": loading_wall(),
            "pause_player_00.png": pause_player()}


def main(argv):
    check = "--check" in argv
    errors = []
    for name, img in outputs().items():
        path = os.path.join(REPO, OUT, name)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                errors.append("%s no esta al dia (python3 -I tools/gen_world2_cards.py)" % os.path.join(OUT, name))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
    for error in errors:
        print("gen_world2_cards: " + error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
