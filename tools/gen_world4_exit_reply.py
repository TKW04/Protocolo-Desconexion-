#!/usr/bin/env python3
"""Puerta «Responder más tarde» del 4-3 «Mensajes sin leer» (paso 14 de docs/propuesta-mundo-4.md §8, §3.7 y §4.3):
aspecto `chat_reply` de la terminal de salida (exit_terminal, seccion exit_terminal.skins de
data/world1_objects.json), arte por script con la paleta del Mundo 4 (tools/palette_mundo4_provisional.py).

Mismo tamano (64 x 128, la terminal de 1 x 2 tiles con los pies abajo), mismas animaciones, cuadros y fps que
la terminal de tools/gen_warp_objects.py (TERMINAL_ANIMS): el comportamiento no cambia (pulso, «Sin conexión» con
offline_text, giro de espaldas, vortice). Un movil de pie con la conversacion y el campo de respuesta abajo:
  terminal_off     pantalla oscura con dos burbujas apagadas y el campo vacio (2 cuadros: el cursor parpadea)
  terminal_prompt  con Isak cerca, el campo se ilumina y el cursor parpadea (2 cuadros)
  terminal_boot    la pantalla se enciende desde el campo hacia arriba (4 cuadros)
  terminal_on      pantalla encendida en crema, el boton de enviar en verde apagado (2 cuadros)
Salida: assets/sprites/props/world4_exit/chat_reply_<anim>_<nn>.png y
assets/sprites/chat_reply_terminal_frames.tres. Provisional (arte final con el del mundo, paso 24).

Uso: python3 -I tools/gen_world4_exit_reply.py [--check]   (--check: 1 si algun archivo no esta al dia)
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo4_provisional as pal  # noqa: E402
import gen_warp_objects as warp  # noqa: E402

OUT = os.path.join("assets", "sprites", "props", "world4_exit")
FRAMES_TRES = os.path.join("assets", "sprites", "chat_reply_terminal_frames.tres")
COLORS = {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in pal.COLORS}
W, H = warp.TERMINAL_W, warp.TERMINAL_H
# Movil (exterior inclusivo), pantalla y campo de respuesta.
BODY = (8, 4, 55, 99)
SCREEN = (11, 10, 52, 86)
FIELD = (13, 76, 44, 84)
SEND = (46, 76, 51, 84)


def C(name):
    return COLORS[name]


def stand(d):
    """Peana: soporte del movil hasta los pies (fila 127)."""
    d.rectangle([28, 100, 35, 118], fill=C("gris_oscuro"))
    d.rectangle([16, 119, 47, 127], fill=C("gris_oscuro"))
    d.rectangle([16, 119, 47, 119], fill=C("gris_medio"))


def body(d, light):
    x0, y0, x1, y1 = BODY
    d.rectangle([x0, y0, x1, y1], fill=C("chat_noche"))
    d.rectangle([x0, y0, x1, y1], outline=C("gris_claro" if light else "gris_medio"))
    d.rectangle([28, 6, 35, 7], fill=C("gris_medio"))  # altavoz
    d.rectangle([29, 91, 34, 95], outline=C("gris_medio"))  # boton


def bubbles(d, color, edge):
    """Dos burbujas de la conversacion: la de Tomi (izquierda) y la que no se mando (derecha)."""
    d.rectangle([14, 16, 38, 26], fill=C(color), outline=C(edge))
    d.rectangle([14, 27, 16, 29], fill=C(edge))
    d.rectangle([25, 34, 49, 44], fill=C(color), outline=C(edge))
    d.rectangle([47, 45, 49, 47], fill=C(edge))
    for k in range(3):
        d.rectangle([18 + 6 * k, 20, 21 + 6 * k, 21], fill=C(edge))


def field(d, lit, cursor):
    x0, y0, x1, y1 = FIELD
    d.rectangle([x0, y0, x1, y1], fill=C("marino_medio" if lit else "marino_fondo"),
                outline=C("gris_claro" if lit else "gris_medio"))
    if cursor:
        d.rectangle([x0 + 3, y0 + 2, x0 + 4, y1 - 2], fill=C("blanco_pantalla" if lit else "gris_claro"))
    s0, t0, s1, t1 = SEND
    d.rectangle([s0, t0, s1, t1], fill=C("verde_sombra" if not lit else "verde_apagado"))
    d.polygon([(s0 + 1, t0 + 2), (s1 - 1, (t0 + t1) // 2), (s0 + 1, t1 - 2)], fill=C("chat_noche"))


def build(state, f):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stand(d)
    body(d, light=state in ("prompt", "on"))
    x0, y0, x1, y1 = SCREEN
    if state in ("off", "prompt"):
        d.rectangle([x0, y0, x1, y1], fill=C("marino_fondo"))
        bubbles(d, "marino_luz", "gris_medio")
        field(d, lit=state == "prompt", cursor=f == 0)
    elif state == "boot":
        d.rectangle([x0, y0, x1, y1], fill=C("marino_fondo"))
        top = [74, 58, 34, 10][f]
        d.rectangle([x0, top, x1, y1], fill=C("marino_luz"))
        bubbles(d, "marino_luz", "gris_claro")
        field(d, lit=True, cursor=True)
    else:  # on
        d.rectangle([x0, y0, x1, y1], fill=C("marino_luz"))
        bubbles(d, "crema", "crema_sombra")
        field(d, lit=True, cursor=f == 0)
        if f == 0:
            bx0, by0, bx1, by1 = BODY
            d.rectangle([bx0 - 1, by0 - 1, bx1 + 1, by1 + 1], outline=C("blanco_pantalla"))
    return binarize(img)


def binarize(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            a = px[x, y][3]
            if 0 < a < 255:
                px[x, y] = px[x, y][:3] + (255,) if a >= 128 else (0, 0, 0, 0)
    return img


def outputs():
    out = {}
    for name, count, _fps, _loop in warp.TERMINAL_ANIMS:
        for f in range(count):
            out["chat_reply_%s_%02d.png" % (name, f)] = build(name.split("_", 1)[1], f)
    return out


def frames_resource():
    anims = []
    for name, count, fps, loop in warp.TERMINAL_ANIMS:
        anims.append((name, ["res://%s/chat_reply_%s_%02d.png" % (OUT, name, f) for f in range(count)], fps, loop))
    return warp.sprite_frames_tres(anims)


def main(argv):
    check = "--check" in argv
    images = outputs()
    tres = frames_resource()
    errors = []
    allowed = set(COLORS.values())
    for name, img in images.items():
        for px in img.getdata():
            if px[3] == 255 and px not in allowed:
                errors.append("%s: color fuera de la paleta del Mundo 4 %s" % (name, px[:3]))
                break
        path = os.path.join(REPO, OUT, name)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.tobytes():
                errors.append("%s no esta al dia" % os.path.join(OUT, name))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
    tres_path = os.path.join(REPO, FRAMES_TRES)
    if check:
        if not os.path.exists(tres_path) or open(tres_path, encoding="utf-8").read() != tres:
            errors.append("%s no esta al dia" % FRAMES_TRES)
        if os.path.isdir(os.path.join(REPO, OUT)):
            for name in sorted(os.listdir(os.path.join(REPO, OUT))):
                if name.endswith(".png") and name not in images:
                    errors.append("%s: no lo produce este script" % os.path.join(OUT, name))
    else:
        with open(tres_path, "w", encoding="utf-8") as fh:
            fh.write(tres)
    for error in errors:
        print("gen_world4_exit_reply: %s (python3 -I tools/gen_world4_exit_reply.py)" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
