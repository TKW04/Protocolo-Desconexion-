#!/usr/bin/env python3
"""Arte por script de los objetos y enemigos del Mundo 4 «El Chat» (paso 10 de docs/propuesta-mundo-4.md §8 y §6.3).

En el juego los objetos y enemigos del Mundo 4 se dibujan por codigo (cada script lee sus colores por nombre de la
seccion palette de data/world4_objects.json); este script dibuja lo mismo con la paleta del mundo
(tools/palette_mundo4_provisional.py con la variante elegida de tools/palette_mundo4_variants.py) en PNG, que usan
las fichas del album (tools/gen_album_cards.py), la comparativa de paletas (tools/palette_mundo4_variants.py
--preview) y sirven de referencia del aspecto. 1 px = 1 px de pantalla. El texto de las burbujas son renglones
(barras): el juego escribe el texto con la fuente.

Objetos (assets/sprites/props/world4/):
  chat_bubble_00.png          burbuja fija (192 x 40): tarjeta crema con cola a la izquierda, dos renglones y hora
  chat_bubble_friend_00.png   burbuja de amigo (192 x 40) con avatar redondo e inicial
  chat_bubble_deleted_00.png  «Se eliminó este mensaje» (192 x 40): contorno discontinuo, sin relleno
  typing_bubble_00.png        «escribiendo…» (64 x 40): burbuja con contorno y tres puntos crema
  autocorrect_bubble_00.png   autocorrector (128 x 40): burbuja con el cursor
  seen_zone_00.png            zona «Visto» (128 x 64): velo verde apagado, contorno discontinuo y doble check
  seen_wave_00.png            ola «Leído» (64 x 192): velo gris, columna de dobles checks y frente rojo
  flashlight_pickup_00.png    Linterna (32 x 32)
  dark_zone_00.png            Modo oscuro (64 x 64): velo chat_noche con el circulo de luz
  ink_only_00.png             paso en tinta (64 x 32): renglon crema discontinuo
  undo_prompt_00.png          «¿Deshacer escritura?» (160 x 88): ventana de sistema con el celular que se sacude
  typed_wall_00.png           muro de texto (64 x 192): bloque crema con renglones
Enemigos (assets/sprites/enemies/world4/; el Troll, PROVISIONAL hasta AutoSprite, paso 24):
  troll_placeholder_00.png    Troll (64 x 64): avatar anonimo gris con el bocadillo de los tres puntos
  troll_mimic_00.png          Troll disfrazado (128 x 64): burbuja de amigo con las costuras rojas del Debug
  troll_message_00.png        mensaje del Troll (64 x 32): bocadillo crema con contorno rojo (dana)
  ghost_00.png                Fantasma (64 x 64): sabana blanca con ojos huecos
  sticker_00.png              Sticker (48 x 48): cara redonda crema con mejillas
  seen_boss_placeholder_00.png  El Visto (192 x 96, a media escala; paso 20): dos checks blancos y el gris «sin leer»
  seen_shield_00.png          escudo de El Visto (160 x 112): anillo de burbujas crema alrededor del doble check
  seen_typing_00.png          «escribiendo…» gigante (192 x 64): burbuja marino_luz con tres puntos, uno apagado

Uso: python3 -I tools/gen_world4_objects.py [--check]   (--check: 1 si algun PNG no esta al dia)
"""
import math
import os
import re
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo4_provisional as pal  # noqa: E402

OUT_OBJECTS = os.path.join("assets", "sprites", "props", "world4")
OUT_ENEMIES = os.path.join("assets", "sprites", "enemies", "world4")


def palette_colors(rows):
    return {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in rows}


COLORS = palette_colors(pal.COLORS + [pal.DEBUG])


def C(name):
    return COLORS[name]


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


# ------------------------------------------------------------------ piezas comunes
def card(d, box, fill="crema", edge="crema_sombra", tail="left"):
    """Tarjeta de burbuja con esquinas redondeadas, sombra abajo y cola."""
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius=6, fill=C(fill), outline=C(edge))
    d.line((x0 + 4, y1 - 1, x1 - 4, y1 - 1), fill=C(edge))
    if tail == "left":
        d.polygon(((x0, y1 - 10), (x0 - 6, y1), (x0 + 8, y1 - 2)), fill=C(fill), outline=C(edge))
    elif tail == "right":
        d.polygon(((x1, y1 - 10), (x1 + 6, y1), (x1 - 8, y1 - 2)), fill=C(fill), outline=C(edge))


def text_lines(d, x0, y0, widths, color="marino_medio"):
    for k, w in enumerate(widths):
        d.rectangle((x0, y0 + k * 8, x0 + w, y0 + k * 8 + 3), fill=C(color))


def dashed_rect(d, box, color, dash=6):
    x0, y0, x1, y1 = box
    for x in range(x0, x1, dash * 2):
        d.line((x, y0, min(x + dash, x1), y0), fill=C(color))
        d.line((x, y1, min(x + dash, x1), y1), fill=C(color))
    for y in range(y0, y1, dash * 2):
        d.line((x0, y, x0, min(y + dash, y1)), fill=C(color))
        d.line((x1, y, x1, min(y + dash, y1)), fill=C(color))


def check(d, x, y, color, size=6):
    d.line((x, y + size // 2, x + size // 2, y + size), fill=C(color), width=2)
    d.line((x + size // 2, y + size, x + size + 2, y - 1), fill=C(color), width=2)


def double_check(d, x, y, color="verde_apagado"):
    check(d, x, y, color)
    check(d, x + 6, y, color)


def dots(d, cx, cy, color="crema", r=3, gap=10):
    for k in (-1, 0, 1):
        x = cx + k * gap
        d.ellipse((x - r, cy - r, x + r, cy + r), fill=C(color))


def avatar(d, cx, cy, r, fill, initial_color):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=C(fill), outline=C("chat_noche"))
    # Inicial «L» (Lia) en pixeles.
    d.rectangle((cx - 3, cy - 5, cx - 2, cy + 4), fill=C(initial_color))
    d.rectangle((cx - 3, cy + 3, cx + 3, cy + 4), fill=C(initial_color))


# ------------------------------------------------------------------ objetos
def chat_bubble():
    img, d = canvas(192, 40)
    card(d, (8, 2, 189, 33))
    text_lines(d, 16, 10, [140, 96])
    text_lines(d, 160, 26, [20], "gris_medio")
    return img


def chat_bubble_friend():
    img, d = canvas(192, 40)
    card(d, (28, 2, 189, 33))
    avatar(d, 12, 26, 10, "verde_apagado", "blanco_pantalla")
    text_lines(d, 36, 10, [120, 80])
    return img


def chat_bubble_deleted():
    img, d = canvas(192, 40)
    dashed_rect(d, (8, 2, 189, 33), "crema_sombra")
    text_lines(d, 20, 14, [120], "gris_medio")
    return img


def typing_bubble():
    img, d = canvas(64, 40)
    d.rounded_rectangle((6, 4, 61, 33), radius=6, outline=C("crema"), fill=C("marino_medio"))
    d.polygon(((6, 23), (1, 33), (14, 31)), fill=C("marino_medio"), outline=C("crema"))
    dots(d, 34, 19)
    return img


def autocorrect_bubble():
    img, d = canvas(128, 40)
    card(d, (8, 2, 125, 33))
    text_lines(d, 16, 14, [60])
    d.rectangle((80, 9, 81, 26), fill=C("marino_fondo"))
    d.rectangle((86, 14, 112, 17), fill=C("gris_claro"))
    return img


def seen_zone():
    img, d = canvas(128, 64)
    veil = C("verde_apagado")[:3] + (255,)
    for y in range(2, 62, 4):
        for x in range(2 + (y // 4) % 2 * 2, 126, 4):
            d.point((x, y), fill=veil)
    dashed_rect(d, (1, 1, 126, 62), "verde_apagado", 8)
    d.rectangle((0, 18, 20, 44), fill=C("marino_fondo"), outline=C("verde_apagado"))
    double_check(d, 2, 26)
    return img


def seen_wave():
    img, d = canvas(64, 192)
    for y in range(0, 192, 2):
        for x in range((y // 2) % 2, 48, 2):
            d.point((x, y), fill=C("gris_oscuro"))
    for y in range(12, 192, 32):
        double_check(d, 30, y)
    d.rectangle((48, 0, 51, 191), fill=C("alerta"))
    d.rectangle((52, 0, 52, 191), fill=C("alerta_sombra"))
    return img


def flashlight_pickup():
    img, d = canvas(32, 32)
    d.rectangle((12, 14, 19, 29), fill=C("gris_medio"), outline=C("chat_noche"))
    d.polygon(((9, 14), (22, 14), (19, 8), (12, 8)), fill=C("gris_claro"), outline=C("chat_noche"))
    d.ellipse((12, 3, 19, 9), fill=C("crema"))
    d.rectangle((15, 18, 16, 21), fill=C("crema"))
    return img


def dark_zone():
    img, d = canvas(64, 64)
    d.rectangle((0, 0, 63, 63), fill=C("chat_noche"))
    d.ellipse((14, 14, 49, 49), fill=C("marino_medio"))
    d.ellipse((22, 22, 41, 41), fill=C("marino_luz"))
    return img


def ink_only():
    img, d = canvas(64, 32)
    dashed_rect(d, (1, 2, 62, 12), "crema", 4)
    text_lines(d, 8, 20, [40], "crema_sombra")
    return img


def undo_prompt():
    img, d = canvas(160, 88)
    d.rectangle((0, 0, 159, 87), fill=C("marino_luz"))
    d.rectangle((3, 3, 156, 84), fill=C("marino_fondo"))
    d.rectangle((3, 3, 156, 14), fill=C("marino_medio"))
    text_lines(d, 30, 22, [100], "blanco_pantalla")
    text_lines(d, 44, 34, [72], "gris_claro")
    d.rectangle((74, 48, 85, 67), fill=C("crema"))
    d.rectangle((76, 50, 83, 65), fill=C("marino_fondo"))
    for side in (-1, 1):
        x = 80 + side * 11
        d.line((x, 52, x + side * 3, 57), fill=C("blanco_pantalla"))
        d.line((x + side * 3, 57, x, 62), fill=C("blanco_pantalla"))
    return img


def typed_wall():
    img, d = canvas(64, 192)
    d.rectangle((0, 0, 63, 191), fill=C("crema"), outline=C("crema_sombra"))
    for k, w in enumerate((44, 30, 20)):
        text_lines(d, 6, 28 + k * 64, [w], "marino_fondo")
    d.rectangle((54, 152, 55, 166), fill=C("marino_fondo"))
    return img


# ------------------------------------------------------------------ enemigos
def troll_placeholder():
    img, d = canvas(64, 64)
    d.ellipse((18, 18, 45, 45), fill=C("gris_medio"), outline=C("chat_noche"))
    d.rectangle((14, 42, 49, 63), fill=C("gris_oscuro"), outline=C("chat_noche"))
    d.ellipse((24, 22, 39, 37), fill=C("gris_claro"))
    d.rectangle((30, 26, 33, 29), fill=C("gris_oscuro"))
    d.rectangle((31, 32, 32, 33), fill=C("gris_oscuro"))
    d.rounded_rectangle((34, 2, 63, 16), radius=4, fill=C("marino_medio"), outline=C("crema"))
    dots(d, 48, 9, r=2, gap=7)
    return img


def troll_mimic():
    img, d = canvas(128, 64)
    card(d, (28, 26, 125, 57))
    avatar(d, 12, 50, 10, "verde_apagado", "blanco_pantalla")
    text_lines(d, 36, 36, [60])
    for x in range(30, 124, 8):
        d.line((x, 25, x + 3, 25), fill=C("alerta"))
        d.line((x, 58, x + 3, 58), fill=C("alerta"))
    return img


def troll_message():
    img, d = canvas(64, 32)
    d.rounded_rectangle((2, 4, 61, 27), radius=5, fill=C("crema"), outline=C("alerta"), width=2)
    text_lines(d, 12, 14, [30], "marino_fondo")
    return img


def ghost():
    img, d = canvas(64, 64)
    d.pieslice((12, 4, 51, 43), 180, 360, fill=C("blanco_pantalla"), outline=C("gris_claro"))
    d.rectangle((12, 24, 51, 54), fill=C("blanco_pantalla"))
    d.line((12, 24, 12, 54), fill=C("gris_claro"))
    d.line((51, 24, 51, 54), fill=C("gris_claro"))
    for k in range(4):
        x = 12 + k * 10
        d.polygon(((x, 54), (x + 5, 61), (x + 10, 54)), fill=C("blanco_pantalla"), outline=C("gris_claro"))
    d.ellipse((22, 20, 29, 29), fill=C("marino_fondo"))
    d.ellipse((34, 20, 41, 29), fill=C("marino_fondo"))
    return img


def sticker():
    img, d = canvas(48, 48)
    d.ellipse((4, 4, 43, 43), fill=C("crema"), outline=C("chat_noche"))
    d.ellipse((14, 16, 19, 22), fill=C("chat_noche"))
    d.ellipse((28, 16, 33, 22), fill=C("chat_noche"))
    d.arc((14, 20, 33, 35), 20, 160, fill=C("chat_noche"), width=2)
    d.ellipse((9, 25, 14, 29), fill=C("crema_sombra"))
    d.ellipse((33, 25, 38, 29), fill=C("crema_sombra"))
    return img


def _check_blocks(d, x0, y0, block, color, small=False):
    """El check de bloques de Seen._make_body_texture (brazo corto y largo)."""
    short, long_, size = (2, 5, block) if small else (5, 12, block * 2)
    for i in range(short):
        x, y = x0 + i * block, y0 + i * block
        d.rectangle((x, y, x + size - 1, y + size - 1), fill=C(color))
    for i in range(long_):
        x, y = x0 + (short + i) * block, y0 + (short - 1 - i) * block
        if y >= 0:
            d.rectangle((x, y, x + size - 1, y + size - 1), fill=C(color))


def seen_boss_body(d, ox=0, oy=0):
    """El cuerpo de 384 x 192 de Seen a media escala (bloques de 4 px)."""
    for k in range(2):
        _check_blocks(d, ox + 20 + k * 56, oy + 36, 4, "blanco_pantalla")
    _check_blocks(d, ox + 80, oy + 68, 4, "gris_medio", small=True)


def seen_boss_placeholder():
    img, d = canvas(192, 96)
    d.rectangle((2, 2, 189, 93), outline=C("gris_claro"), width=2)
    seen_boss_body(d)
    return img


def seen_shield():
    img, d = canvas(160, 112)
    seen_boss_body(d, -16, 8)
    for k in range(12):
        a = 2 * math.pi * k / 12
        cx, cy = 80 + math.cos(a) * 66, 56 + math.sin(a) * 42
        d.rounded_rectangle((cx - 10, cy - 6, cx + 10, cy + 6), radius=3, fill=C("crema"), outline=C("crema_sombra"))
    return img


def seen_typing():
    img, d = canvas(192, 64)
    d.rounded_rectangle((4, 4, 187, 59), radius=10, fill=C("marino_luz"), outline=C("gris_claro"), width=2)
    for k, color in enumerate(("blanco_pantalla", "blanco_pantalla", "gris_medio")):
        x = 48 + k * 48
        d.ellipse((x - 12, 20, x + 12, 44), fill=C(color))
    return img


OBJECTS = {
    "chat_bubble_00.png": chat_bubble, "chat_bubble_friend_00.png": chat_bubble_friend,
    "chat_bubble_deleted_00.png": chat_bubble_deleted, "typing_bubble_00.png": typing_bubble,
    "autocorrect_bubble_00.png": autocorrect_bubble, "seen_zone_00.png": seen_zone, "seen_wave_00.png": seen_wave,
    "flashlight_pickup_00.png": flashlight_pickup, "dark_zone_00.png": dark_zone, "ink_only_00.png": ink_only,
    "undo_prompt_00.png": undo_prompt, "typed_wall_00.png": typed_wall,
}
ENEMIES = {
    "troll_placeholder_00.png": troll_placeholder, "troll_mimic_00.png": troll_mimic,
    "troll_message_00.png": troll_message, "ghost_00.png": ghost, "sticker_00.png": sticker,
    "seen_boss_placeholder_00.png": seen_boss_placeholder, "seen_shield_00.png": seen_shield,
    "seen_typing_00.png": seen_typing,
}


def binarize(img):
    """Alfa 0 o 255 (los bordes suavizados de PIL, al color opaco o fuera)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            a = px[x, y][3]
            if 0 < a < 255:
                px[x, y] = px[x, y][:3] + (255,) if a >= 128 else (0, 0, 0, 0)
    return img


def outputs():
    return ({name: binarize(build()) for name, build in OBJECTS.items()},
            {name: binarize(build()) for name, build in ENEMIES.items()})


def outputs_for(rows):
    """Los mismos dibujos con otra paleta (filas (nombre, hex, funcion) con el Debug); no escribe nada."""
    global COLORS
    saved = COLORS
    COLORS = palette_colors(rows)
    try:
        return outputs()
    finally:
        COLORS = saved


def off_palette(images, rows):
    """Nombres de PNG con algun color opaco fuera de la paleta (validador)."""
    allowed = {tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for _n, v, _r in rows}
    bad = []
    for name, img in images.items():
        colors = {c[:3] for _count, c in img.getcolors(1 << 16) or [] if c[3] == 255}
        if colors - allowed:
            bad.append(name)
    return bad


## PNG de otros importadores en las mismas carpetas (no los produce este script).
IMPORTED_ART = re.compile(r"^troll_(idle|typing|shot|stunned)_\d\d\.png$")


def write_or_check(out_dir, images, check):
    errors = []
    for name, img in images.items():
        path = os.path.join(REPO, out_dir, name)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                errors.append("%s no esta al dia (python3 -I tools/gen_world4_objects.py)" % os.path.join(out_dir, name))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
    if check and os.path.isdir(os.path.join(REPO, out_dir)):
        for name in sorted(os.listdir(os.path.join(REPO, out_dir))):
            # El arte final del Troll lo escribe tools/import_troll.py (etapa 3b del paso 24).
            if name.endswith(".png") and name not in images and not IMPORTED_ART.match(name):
                errors.append("%s: no lo produce tools/gen_world4_objects.py" % os.path.join(out_dir, name))
    return errors


def main(argv):
    check = "--check" in argv
    objects, enemies = outputs()
    errors = write_or_check(OUT_OBJECTS, objects, check) + write_or_check(OUT_ENEMIES, enemies, check)
    for name in off_palette(dict(objects, **enemies), pal.COLORS + [pal.DEBUG]):
        errors.append("%s usa colores fuera de la paleta del Mundo 4" % name)
    for error in errors:
        print("gen_world4_objects: %s" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
