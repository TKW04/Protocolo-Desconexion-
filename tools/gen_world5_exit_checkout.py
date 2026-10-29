#!/usr/bin/env python3
"""Puerta «Pagar» del Mundo 5 «La Tienda» (paso 10 de docs/propuesta-mundo-5.md §8, §3.7 y §4.1): aspecto
`checkout` de la terminal de salida (exit_terminal, seccion exit_terminal.skins de data/world1_objects.json), arte
por script con la paleta del Mundo 5 (tools/palette_mundo5_provisional.py, con la variante elegida en el paso 9).

Mismo tamano (64 x 128, la terminal de 1 x 2 tiles con los pies abajo), mismas animaciones, cuadros y fps que la
terminal de tools/gen_warp_objects.py (TERMINAL_ANIMS): el comportamiento no cambia (pulso, placa offline_text con
el total, giro de espaldas, vortice). Una caja de pago sobre su mostrador: pantalla con el total y el datafono.
  terminal_off     pantalla apagada con el renglon del total en gris (2 cuadros: el piloto parpadea)
  terminal_prompt  con Isak cerca, la pantalla se ilumina en amarillo y el piloto parpadea en magenta (2 cuadros)
  terminal_boot    la pantalla se llena de crema desde abajo (4 cuadros)
  terminal_on      pantalla crema con el «0» del total y el ticket que asoma (2 cuadros)
Reglas de §6.1: nada rojo ni ambar (el total va en magenta) y sin el blanco del Debug. Salida:
assets/sprites/props/world5_exit/checkout_<anim>_<nn>.png y assets/sprites/checkout_terminal_frames.tres.
Provisional (arte final con el del mundo, paso 24).

Uso: python3 -I tools/gen_world5_exit_checkout.py [--check]   (--check: 1 si algun archivo no esta al dia)
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import palette_mundo5_provisional as pal  # noqa: E402
import gen_warp_objects as warp  # noqa: E402

OUT = os.path.join("assets", "sprites", "props", "world5_exit")
FRAMES_TRES = os.path.join("assets", "sprites", "checkout_terminal_frames.tres")
COLORS = {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in pal.COLORS}
# Reservados (§6.1): el rojo de dano y el ambar de los puntos no salen en la puerta.
FORBIDDEN = ("alerta", "alerta_sombra", "ambar", "ambar_sombra")
W, H = warp.TERMINAL_W, warp.TERMINAL_H
BODY = (6, 10, 57, 70)       # caja (exterior inclusivo)
SCREEN = (11, 15, 52, 44)    # pantalla del total
PAD = (14, 50, 49, 66)       # teclado / datafono
COUNTER = (2, 78, 61, 127)   # mostrador hasta los pies


def C(name):
    assert name not in FORBIDDEN, name
    return COLORS[name]


# Cifras de 3 x 5 a x2 (como tools/gen_world5_objects.py).
ZERO = ("###", "#.#", "#.#", "#.#", "###")


def digit(d, x, y, rows, color):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "#":
                d.rectangle([x + 2 * i, y + 2 * j, x + 2 * i + 1, y + 2 * j + 1], fill=C(color))


def counter(d):
    x0, y0, x1, y1 = COUNTER
    d.rectangle([x0, y0, x1, y1], fill=C("gris_escaparate"))
    d.rectangle([x0, y0, x1, y0 + 3], fill=C("crema_sombra"))
    d.rectangle([x0, y0, x1, y1], outline=C("tienda_noche"))
    # Franja de rebajas del mostrador.
    d.rectangle([x0 + 1, 96, x1 - 1, 101], fill=C("amarillo_sombra"))
    for x in range(x0 + 3, x1 - 2, 8):
        d.rectangle([x, 97, x + 3, 100], fill=C("amarillo_rebajas"))
    d.rectangle([28, 71, 35, 77], fill=C("gris_etiqueta"))  # pie de la caja


def body(d, light):
    x0, y0, x1, y1 = BODY
    d.rectangle([x0, y0, x1, y1], fill=C("negro_medio"))
    d.rectangle([x0, y0, x1, y1], outline=C("crema_sombra" if light else "gris_etiqueta"))
    px0, py0, px1, py1 = PAD
    d.rectangle([px0, py0, px1, py1], fill=C("gris_escaparate"), outline=C("tienda_noche"))
    for j in range(3):
        for i in range(4):
            x, y = px0 + 3 + 8 * i, py0 + 3 + 5 * j
            d.rectangle([x, y, x + 4, y + 2], fill=C("gris_etiqueta" if not light else "crema_sombra"))


def pilot(d, on):
    d.rectangle([52, 4, 55, 7], fill=C("magenta_neon" if on else "magenta_sombra"))
    d.rectangle([51, 3, 56, 8], outline=C("tienda_noche"))


def total_row(d, color):
    x0, y0, x1, _ = SCREEN
    d.rectangle([x0 + 3, y0 + 4, x0 + 20, y0 + 6], fill=C(color))  # «Total:»


def build(state, f):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    counter(d)
    body(d, light=state in ("prompt", "on"))
    x0, y0, x1, y1 = SCREEN
    if state in ("off", "prompt"):
        d.rectangle([x0, y0, x1, y1], fill=C("amarillo_rebajas" if state == "prompt" else "tienda_noche"))
        total_row(d, "amarillo_sombra" if state == "prompt" else "gris_escaparate")
        pilot(d, on=f == 0)
    elif state == "boot":
        d.rectangle([x0, y0, x1, y1], fill=C("tienda_noche"))
        top = [40, 32, 24, 16][f]
        d.rectangle([x0, top, x1, y1], fill=C("crema_cartel"))
        total_row(d, "crema_sombra")
        pilot(d, on=True)
    else:  # on
        d.rectangle([x0, y0, x1, y1], fill=C("crema_cartel"))
        total_row(d, "gris_etiqueta")
        digit(d, 38, y0 + 14, ZERO, "magenta_neon")
        pilot(d, on=f == 0)
        # Ticket que asoma por arriba.
        d.rectangle([20, 2, 43, 9], fill=C("crema_cartel"), outline=C("crema_sombra"))
        for y in (4, 6):
            d.line([23, y, 40, y], fill=C("gris_etiqueta"))
    d.rectangle([x0, y0, x1, y1], outline=C("tienda_noche"))
    return img


def outputs():
    out = {}
    for name, count, _fps, _loop in warp.TERMINAL_ANIMS:
        for f in range(count):
            out["checkout_%s_%02d.png" % (name, f)] = build(name.split("_", 1)[1], f)
    return out


def frames_resource():
    anims = []
    for name, count, fps, loop in warp.TERMINAL_ANIMS:
        anims.append((name, ["res://%s/checkout_%s_%02d.png" % (OUT, name, f) for f in range(count)], fps, loop))
    return warp.sprite_frames_tres(anims)


def main(argv):
    check = "--check" in argv
    images = outputs()
    tres = frames_resource()
    errors = []
    allowed = {v for k, v in COLORS.items() if k not in FORBIDDEN}
    for name, img in images.items():
        for px in img.getdata():
            if px[3] not in (0, 255) or (px[3] == 255 and px not in allowed):
                errors.append("%s: color fuera de la paleta del Mundo 5 (o reservado) %s" % (name, px))
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
        print("gen_world5_exit_checkout: %s (python3 -I tools/gen_world5_exit_checkout.py)" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
