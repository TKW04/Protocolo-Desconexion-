#!/usr/bin/env python3
"""Arte por script de los objetos del Mundo 3 «La Vitrina» (paso 9 de docs/propuesta-mundo-3.md §8 y §6.3).

En el juego los objetos del Mundo 3 se dibujan por codigo (cada script lee sus colores por nombre de la seccion
palette de data/world3_objects.json); este script dibuja lo mismo con la paleta del mundo
(tools/palette_mundo3_provisional.py con la variante elegida de tools/palette_mundo3_variants.py) en PNG, que usan
las fichas del album (tools/gen_album_cards.py), la comparativa de paletas (tools/palette_mundo3_preview.py) y
sirven de referencia del aspecto. Salida en assets/sprites/props/world3/ (1 px = 1 px de pantalla):
  heart_pickup_00.png        corazon de likes (32 x 32): rosa con borde blanco brillante, nunca rojo
  like_source_00.png         publicacion (64 x 64): marco dorado con foto rosa, corazon y anillo de carga
  like_platform_on_00.png    plataforma de likes encendida (128 x 48): tarjeta rosa con marco y etiqueta «♥10»
  like_platform_off_00.png   la misma apagada (contorno discontinuo)
  like_platform_invert_00.png plataforma inversa (corazon tachado)
  like_reset_00.png          «Borrar publicaciones» (64 x 64): panel con papelera y corazon tachado
  crop_tool_00.png           «Recortar» (128 x 96): pantalla con la foto, lineas de recorte y tijeras
  filter_zone_00.png         filtro (128 x 112): capa rosa con marco, cinta y cartel
  small_frame_00.png         marco pequeno (64 x 64, de pared, hueco de 1 fila)
  mirror_00.png              espejo fijo «/» (64 x 64) con su pie
  mirror_wall_00.png         pared de espejo (128 x 128) con la plataforma del reflejo
  mirror_only_00.png         plataforma del reflejo vista con el Debug (64 x 32, contorno verde acido)
  hunter_mirror_00.png       espejo cazador (64 x 64): cabeza con ojo y cristal
  pose_plate_00.png          placa «Posa aqui» (64 x 24) con las huellas
  frame_door_00.png          puerta de marco (64 x 192) cerrada con su lampara
  hud_likes_00.png           HUD de likes (64 x 24): corazon y «12»
Sin _placeholder: son arte por script del mundo (la Curadora y el Influencer, de AutoSprite, si lo llevan).

Uso: python3 -I tools/gen_world3_objects.py [--check]   (--check: 1 si algun PNG no esta al dia)
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo3_provisional as pal  # noqa: E402

OUT = os.path.join("assets", "sprites", "props", "world3")


def palette_colors(rows):
    return {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in rows}


COLORS = palette_colors(pal.COLORS + [pal.DEBUG])


def C(name):
    return COLORS[name]


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ------------------------------------------------------------------ piezas comunes
def gold_frame(d, box, px=4):
    """Marco dorado apagado: bisel claro arriba / izquierda, sombra abajo / derecha y esquinas en dorado_luz."""
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=C("dorado"))
    d.rectangle((x0, y0, x1, y0), fill=C("dorado_luz"))
    d.rectangle((x0, y0, x0, y1), fill=C("dorado_luz"))
    d.rectangle((x0, y1, x1, y1), fill=C("marco_sombra"))
    d.rectangle((x1, y0, x1, y1), fill=C("marco_sombra"))
    d.rectangle((x0 + px - 1, y0 + px - 1, x1 - px + 1, y1 - px + 1), fill=C("marco_sombra"))
    for cx, cy in ((x0 + 1, y0 + 1), (x1 - 2, y0 + 1), (x0 + 1, y1 - 2), (x1 - 2, y1 - 2)):
        d.rectangle((cx, cy, cx + 1, cy + 1), fill=C("dorado_luz"))
    return (x0 + px, y0 + px, x1 - px, y1 - px)


HEART = ("0110110", "1111111", "1111111", "1111111", "0111110", "0011100", "0001000")


def heart(d, x, y, scale=2, fill="corazon_rosa", border="blanco_brillante", crossed=False):
    """Corazon de 7 x 7 celdas a `scale` con borde de 1 px en `border` y brillo."""
    cells = {(c, r) for r, line in enumerate(HEART) for c, ch in enumerate(line) if ch == "1"}
    if border:
        for c, r in cells:
            d.rectangle((x + c * scale - 1, y + r * scale - 1, x + c * scale + scale, y + r * scale + scale),
                        fill=C(border))
    for c, r in cells:
        d.rectangle((x + c * scale, y + r * scale, x + c * scale + scale - 1, y + r * scale + scale - 1),
                    fill=C(fill))
    d.rectangle((x + scale, y + scale, x + scale * 2 - 1, y + scale * 2 - 1), fill=C("blanco_brillante"))
    if crossed:
        w = 7 * scale
        d.line((x - 1, y + w, x + w, y - 1), fill=C("galeria_noche"), width=3)
        d.line((x - 1, y + w, x + w, y - 1), fill=C("blanco_brillante"), width=1)


DIGITS = {"0": ("111", "101", "101", "101", "111"), "1": ("010", "110", "010", "010", "111"),
          "2": ("111", "001", "111", "100", "111"), "5": ("111", "100", "111", "001", "111")}


def digits(d, x, y, text, color="blanco_brillante", scale=2):
    for ch in text:
        for r, line in enumerate(DIGITS[ch]):
            for c, bit in enumerate(line):
                if bit == "1":
                    d.rectangle((x + c * scale, y + r * scale, x + c * scale + scale - 1, y + r * scale + scale - 1),
                                fill=C(color))
        x += 4 * scale
    return x


def dashed_rect(d, box, color, dash=6, gap=6, width=2):
    x0, y0, x1, y1 = box
    for x in range(x0, x1 + 1, dash + gap):
        d.rectangle((x, y0, min(x + dash - 1, x1), y0 + width - 1), fill=C(color))
        d.rectangle((x, y1 - width + 1, min(x + dash - 1, x1), y1), fill=C(color))
    for y in range(y0, y1 + 1, dash + gap):
        d.rectangle((x0, y, x0 + width - 1, min(y + dash - 1, y1)), fill=C(color))
        d.rectangle((x1 - width + 1, y, x1, min(y + dash - 1, y1)), fill=C(color))


# ------------------------------------------------------------------ objetos
def heart_pickup():
    img, d = canvas(32, 32)
    heart(d, 5, 6, 3)
    return img


def like_source():
    img, d = canvas(64, 64)
    inner = gold_frame(d, (4, 4, 59, 51), 5)
    d.rectangle(inner, fill=C("rosa_pastel"))
    d.rectangle((inner[0], inner[3] - 10, inner[2], inner[3]), fill=C("rosa_sombra"))
    d.polygon([(inner[0], inner[3] - 10), (inner[0] + 14, inner[1] + 14), (inner[0] + 26, inner[3] - 10)],
              fill=C("rosa_sombra"))
    heart(d, 22, 22, 2)
    d.ellipse((47, 1, 61, 15), fill=C("galeria_noche"))
    d.arc((48, 2, 60, 14), -90, 180, fill=C("blanco_brillante"), width=2)
    d.rectangle((8, 56, 55, 57), fill=C("marco_sombra"))
    return img


def _like_card(state):
    img, d = canvas(128, 48)
    top = 16
    if state == "off":
        dashed_rect(d, (0, top, 127, top + 31), "rosa_sombra")
    else:
        d.rectangle((0, top, 127, top + 31), fill=C("dorado"))
        d.rectangle((0, top, 127, top), fill=C("dorado_luz"))
        d.rectangle((2, top + 2, 125, top + 29), fill=C("rosa_pastel"))
        d.rectangle((2, top + 2, 125, top + 3), fill=C("blanco_brillante"))
        d.rectangle((2, top + 25, 125, top + 29), fill=C("rosa_sombra"))
        d.rectangle((0, top + 31, 127, top + 31), fill=C("marco_sombra"))
    d.rectangle((2, 0, 37, 13), fill=C("galeria_noche"))
    heart(d, 5, 3, 1, border=None, crossed=(state == "invert"))
    digits(d, 16, 2, "10")
    return img


def like_platform_on():
    return _like_card("on")


def like_platform_off():
    return _like_card("off")


def like_platform_invert():
    return _like_card("invert")


def like_reset():
    img, d = canvas(64, 64)
    inner = gold_frame(d, (6, 8, 57, 55), 4)
    d.rectangle(inner, fill=C("galeria_noche"))
    # papelera
    d.rectangle((18, 26, 45, 29), fill=C("gris_perla"))
    d.rectangle((27, 23, 36, 25), fill=C("gris_perla"))
    d.polygon([(20, 31), (43, 31), (40, 50), (23, 50)], fill=C("gris_perla"))
    for x in (26, 31, 36):
        d.line((x, 34, x, 47), fill=C("galeria_noche"))
    heart(d, 25, 13, 2, crossed=True)
    return img


def crop_tool():
    img, d = canvas(128, 96)
    inner = gold_frame(d, (0, 0, 127, 95), 6)
    d.rectangle(inner, fill=C("galeria_noche"))
    photo = (20, 16, 107, 77)
    d.rectangle(photo, fill=C("rosa_pastel"))
    d.rectangle((photo[0], photo[3] - 14, photo[2], photo[3]), fill=C("rosa_sombra"))
    d.ellipse((70, 22, 86, 38), fill=C("blanco_brillante"))
    # lineas de recorte discontinuas (un tercio)
    for x in range(photo[0] - 4, photo[2] + 5, 8):
        d.rectangle((x, 48, x + 3, 48), fill=C("blanco_brillante"))
    for y in range(photo[1] - 4, photo[3] + 5, 8):
        d.rectangle((48, y, 48, y + 3), fill=C("blanco_brillante"))
    # tijeras
    d.ellipse((24, 56, 34, 66), outline=C("gris_perla"), width=2)
    d.ellipse((24, 70, 34, 80), outline=C("gris_perla"), width=2)
    d.line((33, 62, 46, 70), fill=C("gris_perla"), width=2)
    d.line((33, 74, 46, 64), fill=C("gris_perla"), width=2)
    return img


def filter_zone():
    img, d = canvas(128, 112)
    inner = gold_frame(d, (0, 16, 127, 111), 6)
    d.rectangle(inner, fill=C("rosa_pastel"))
    for i in range(4):
        d.rectangle((inner[0] + i * 2, inner[1] + i * 2, inner[2] - i * 2, inner[1] + i * 2), fill=C("blanco_brillante"))
    for x in range(inner[0], inner[2] - 3, 12):
        d.rectangle((x, inner[3] - 3, x + 5, inner[3] - 1), fill=C("rosa_sombra"))
    # destellos del filtro
    for cx, cy in ((34, 60), (90, 48), (66, 86)):
        d.rectangle((cx - 1, cy - 4, cx, cy + 3), fill=C("blanco_brillante"))
        d.rectangle((cx - 4, cy - 1, cx + 3, cy), fill=C("blanco_brillante"))
    # cartel
    d.rectangle((30, 0, 97, 13), fill=C("galeria_noche"))
    d.rectangle((30, 13, 97, 13), fill=C("rosa_pastel"))
    for k in range(5):
        d.rectangle((36 + k * 12, 5, 43 + k * 12, 8), fill=C("blanco_brillante"))
    return img


def small_frame():
    img, d = canvas(64, 64)
    # marco de pared: dos largueros de 10 px con su labio y el hueco de 1 fila entre ellos
    for y0 in (0, 54):
        d.rectangle((0, y0, 63, y0 + 9), fill=C("dorado"))
        d.rectangle((0, y0, 63, y0), fill=C("dorado_luz"))
        d.rectangle((0, y0 + 9, 63, y0 + 9), fill=C("marco_sombra"))
    d.rectangle((0, 10, 3, 53), fill=C("marco_sombra"))
    d.rectangle((60, 10, 63, 53), fill=C("marco_sombra"))
    for x, y in ((0, 0), (58, 0), (0, 58), (58, 58)):
        d.rectangle((x, y, x + 5, y + 5), fill=C("dorado_luz"))
    return img


def mirror():
    img, d = canvas(64, 64)
    d.rectangle((29, 50, 34, 63), fill=C("marco_sombra"))
    d.rectangle((20, 60, 43, 63), fill=C("marco_sombra"))
    d.line((8, 54, 56, 6), fill=C("dorado"), width=10)
    d.line((10, 52, 54, 8), fill=C("gris_perla"), width=6)
    d.line((12, 48, 50, 10), fill=C("blanco_brillante"), width=1)
    return img


def mirror_wall():
    img, d = canvas(128, 128)
    inner = gold_frame(d, (0, 0, 127, 127), 8)
    d.rectangle(inner, fill=C("trastienda_fondo"))
    d.polygon([(inner[0] + 10, inner[3]), (inner[0] + 40, inner[1]), (inner[0] + 52, inner[1]),
               (inner[0] + 22, inner[3])], fill=C("trastienda_medio"))
    # plataforma que solo se ve en el reflejo
    d.rectangle((40, 76, 103, 91), fill=C("blanco_brillante"))
    d.rectangle((41, 78, 102, 91), fill=C("rosa_pastel"))
    # Isak reflejado (silueta clara)
    d.rectangle((24, 54, 33, 75), fill=C("rosa_sombra"))
    d.ellipse((23, 44, 34, 55), fill=C("rosa_sombra"))
    d.rectangle((30, 58, 33, 61), fill=C("blanco_brillante"))
    return img


def mirror_only():
    img, d = canvas(64, 32)
    d.rectangle((4, 4, 59, 27), fill=C("rosa_sombra"))
    dashed_rect(d, (0, 0, 63, 31), "debug_verde", dash=6, gap=4)
    return img


def hunter_mirror():
    img, d = canvas(64, 64)
    d.rectangle((29, 44, 34, 63), fill=C("marco_sombra"))
    d.rectangle((20, 60, 43, 63), fill=C("marco_sombra"))
    d.ellipse((12, 6, 51, 45), fill=C("dorado"))
    d.ellipse((12, 6, 51, 45), outline=C("marco_sombra"), width=1)
    d.ellipse((17, 11, 46, 40), fill=C("gris_perla"))
    d.arc((19, 13, 44, 38), 200, 290, fill=C("blanco_brillante"), width=2)
    d.ellipse((27, 21, 36, 30), fill=C("galeria_noche"))
    d.rectangle((33, 22, 34, 23), fill=C("blanco_brillante"))
    # brillo de aviso del giro
    d.rectangle((50, 4, 53, 7), fill=C("dorado_luz"))
    return img


def pose_plate():
    img, d = canvas(64, 24)
    d.rectangle((8, 12, 55, 21), fill=C("dorado"))
    d.rectangle((8, 12, 55, 12), fill=C("dorado_luz"))
    d.rectangle((8, 21, 55, 23), fill=C("marco_sombra"))
    for x in (20, 36):
        d.ellipse((x, 14, x + 7, 19), fill=C("galeria_noche"))
    for x in (14, 22, 30, 38, 46):
        d.rectangle((x, 3, x + 3, 6), fill=C("blanco_brillante"))
    return img


def frame_door():
    img, d = canvas(64, 192)
    inner = gold_frame(d, (0, 0, 63, 191), 6)
    d.rectangle(inner, fill=C("trastienda_luz"))
    for y in range(inner[1] + 12, inner[3], 24):
        d.rectangle((inner[0] + 4, y, inner[2] - 4, y), fill=C("dorado"))
    d.rectangle((inner[0], inner[1], inner[2], inner[1] + 1), fill=C("dorado"))
    d.ellipse((26, 8, 37, 19), fill=C("marco_sombra"))
    d.ellipse((28, 10, 35, 17), fill=C("dorado_luz"))
    return img


def hud_likes():
    img, d = canvas(64, 24)
    d.rectangle((0, 0, 63, 23), fill=C("galeria_noche"))
    d.rectangle((0, 23, 63, 23), fill=C("rosa_pastel"))
    heart(d, 5, 5, 2)
    digits(d, 28, 6, "12")
    return img


BUILDERS = {
    "heart_pickup_00.png": heart_pickup, "like_source_00.png": like_source,
    "like_platform_on_00.png": like_platform_on, "like_platform_off_00.png": like_platform_off,
    "like_platform_invert_00.png": like_platform_invert, "like_reset_00.png": like_reset,
    "crop_tool_00.png": crop_tool, "filter_zone_00.png": filter_zone, "small_frame_00.png": small_frame,
    "mirror_00.png": mirror, "mirror_wall_00.png": mirror_wall, "mirror_only_00.png": mirror_only,
    "hunter_mirror_00.png": hunter_mirror, "pose_plate_00.png": pose_plate, "frame_door_00.png": frame_door,
    "hud_likes_00.png": hud_likes,
}


def binarize(img):
    """Alfa 0 o 255 (los arcos y elipses de PIL ya lo son; por si acaso)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            a = px[x, y][3]
            if 0 < a < 255:
                px[x, y] = px[x, y][:3] + (255,) if a >= 128 else (0, 0, 0, 0)
    return img


def outputs():
    return {name: binarize(build()) for name, build in BUILDERS.items()}


def outputs_for(rows):
    """Los mismos dibujos con otra paleta (filas (nombre, hex, funcion) con el Debug); no escribe nada."""
    global COLORS
    saved = COLORS
    COLORS = palette_colors(rows)
    try:
        return outputs()
    finally:
        COLORS = saved


def write_or_check(out_dir, images, check, tag):
    errors = []
    for name, img in images.items():
        path = os.path.join(REPO, out_dir, name)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                errors.append("%s no esta al dia (python3 -I tools/%s.py)" % (os.path.join(out_dir, name), tag))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
    if check and os.path.isdir(os.path.join(REPO, out_dir)):
        for name in sorted(os.listdir(os.path.join(REPO, out_dir))):
            if name.endswith(".png") and name not in images:
                errors.append("%s: no lo produce tools/%s.py" % (os.path.join(out_dir, name), tag))
    for error in errors:
        print("%s: %s" % (tag, error), file=sys.stderr)
    return 1 if errors else 0


def main(argv):
    return write_or_check(OUT, outputs(), "--check" in argv, "gen_world3_objects")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
