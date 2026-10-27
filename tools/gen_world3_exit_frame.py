#!/usr/bin/env python3
"""Marco dorado de salida del 3-3 «Espejo, espejito» (paso 13 de docs/propuesta-mundo-3.md §8, §3.6 y §4.3):
aspecto `golden_frame` de la terminal de salida (exit_terminal, seccion exit_terminal.skins de
data/world1_objects.json), arte por script con la paleta del Mundo 3 (tools/palette_mundo3_provisional.py).

Mismo tamano (64 x 128, la terminal de 1 x 2 tiles con los pies abajo), mismas animaciones, cuadros y fps que
la terminal de tools/gen_warp_objects.py (TERMINAL_ANIMS): el comportamiento no cambia (pulso, giro de espaldas,
vortice). Un marco de foto dorado sobre un caballete con el lienzo:
  terminal_off     lienzo de terciopelo apagado con la silueta de una camara (2 cuadros: brillo del marco)
  terminal_prompt  con Isak cerca, un destello cruza el cristal y la lente se enciende (2 cuadros)
  terminal_boot    el lienzo se ilumina desde el centro (4 cuadros)
  terminal_on      lienzo encendido en rosa y blanco, marco con resplandor (2 cuadros)
Salida: assets/sprites/props/world3_exit/golden_frame_<anim>_<nn>.png y
assets/sprites/golden_frame_terminal_frames.tres. Provisional: el «marco dorado gigante» del arte final (mas
grande que la terminal) queda para el arte del mundo con el jefe.

Uso: python3 -I tools/gen_world3_exit_frame.py [--check]   (--check: 1 si algun archivo no esta al dia)
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
import gen_warp_objects as warp  # noqa: E402

OUT = os.path.join("assets", "sprites", "props", "world3_exit")
FRAMES_TRES = os.path.join("assets", "sprites", "golden_frame_terminal_frames.tres")
COLORS = {name: tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for name, value, _ in pal.COLORS}
W, H = warp.TERMINAL_W, warp.TERMINAL_H
# Marco (exterior inclusivo) y lienzo.
FRAME = (4, 6, 59, 91)
CANVAS = (10, 12, 53, 85)


def C(name):
    return COLORS[name]


def easel(d):
    """Caballete: dos patas y un travesano bajo el marco, hasta los pies (fila 127)."""
    d.line([(14, 92), (8, 127)], fill=C("marco_sombra"), width=3)
    d.line([(49, 92), (55, 127)], fill=C("marco_sombra"), width=3)
    d.line([(31, 92), (31, 127)], fill=C("marco_sombra"), width=3)
    d.rectangle([10, 108, 53, 110], fill=C("marco_sombra"))
    d.rectangle([11, 108, 52, 108], fill=C("dorado"))


def frame(d, light):
    x0, y0, x1, y1 = FRAME
    d.rectangle([x0, y0, x1, y1], fill=C("dorado"))
    d.rectangle([x0, y0, x1, y0 + 1], fill=C("dorado_luz" if light else "dorado"))
    d.rectangle([x0, y0, x0 + 1, y1], fill=C("dorado_luz" if light else "dorado"))
    d.rectangle([x0, y1 - 1, x1, y1], fill=C("marco_sombra"))
    d.rectangle([x1 - 1, y0, x1, y1], fill=C("marco_sombra"))
    d.rectangle([x0 + 3, y0 + 3, x1 - 3, y1 - 3], outline=C("marco_sombra"))
    # Adornos en las esquinas.
    for cx, cy in ((x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)):
        d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=C("dorado_luz"))
    # Copete del marco con la lente de camara.
    d.rectangle([24, 1, 39, 6], fill=C("dorado"))
    d.rectangle([24, 1, 39, 1], fill=C("dorado_luz"))


def lens(d, color):
    d.ellipse([28, 2, 35, 7], fill=C("galeria_noche"))
    d.ellipse([30, 3, 33, 6], fill=C(color))


def camera_mark(d, color):
    """Silueta de camara en el lienzo (la Curadora espera al otro lado)."""
    cx, cy = 31, 48
    d.rectangle([cx - 10, cy - 6, cx + 11, cy + 8], outline=C(color))
    d.rectangle([cx - 4, cy - 9, cx + 4, cy - 6], outline=C(color))
    d.ellipse([cx - 5, cy - 4, cx + 6, cy + 7], outline=C(color))
    d.rectangle([cx, cy + 1, cx + 1, cy + 2], fill=C(color))


def build(state, f):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    easel(d)
    frame(d, light=(state == "on" and f == 0) or (state == "off" and f == 1) or state == "prompt")
    x0, y0, x1, y1 = CANVAS
    if state in ("off", "prompt"):
        d.rectangle([x0, y0, x1, y1], fill=C("trastienda_fondo"))
        camera_mark(d, "trastienda_luz" if state == "off" else "gris_perla")
        lens(d, "trastienda_luz" if state == "off" else "rosa_pastel")
        if state == "prompt":
            k = 6 + f * 18  # destello diagonal que cruza el cristal
            for i in range(3):
                d.line([(x0 + k + i, y1), (x0 + k + i + 22, y0)], fill=C("dorado_luz" if i == 1 else "gris_perla"))
            d.rectangle([x0, y0, x1, y1], outline=C("rosa_sombra"))
    elif state == "boot":
        d.rectangle([x0, y0, x1, y1], fill=C("trastienda_fondo"))
        cy = (y0 + y1) // 2
        half = [3, 10, 22, 37][f]
        d.rectangle([x0, max(y0, cy - half), x1, min(y1, cy + half)], fill=C("rosa_pastel"))
        d.rectangle([x0, max(y0, cy - half // 3), x1, min(y1, cy + half // 3)], fill=C("blanco_brillante"))
        lens(d, "blanco_brillante")
    else:  # on
        d.rectangle([x0, y0, x1, y1], fill=C("rosa_pastel"))
        d.rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=C("blanco_brillante"))
        camera_mark(d, "rosa_sombra")
        lens(d, "blanco_brillante")
        if f == 0:
            fx0, fy0, fx1, fy1 = FRAME
            d.rectangle([fx0 - 1, fy0 - 1, fx1 + 1, fy1 + 1], outline=C("dorado_luz"))
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
            out["golden_frame_%s_%02d.png" % (name, f)] = build(name.split("_", 1)[1], f)
    return out


def frames_resource():
    anims = []
    for name, count, fps, loop in warp.TERMINAL_ANIMS:
        anims.append((name, ["res://%s/golden_frame_%s_%02d.png" % (OUT, name, f) for f in range(count)], fps, loop))
    return warp.sprite_frames_tres(anims)


def main(argv):
    check = "--check" in argv
    images = outputs()
    tres = frames_resource()
    errors = []
    for name, img in images.items():
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
        print("gen_world3_exit_frame: %s (python3 -I tools/gen_world3_exit_frame.py)" % error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
