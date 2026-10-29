#!/usr/bin/env python3
"""Pieza BLANCA del fondo del hub y fondo completo (Mundo 5 «La Tienda»; paso 18 de docs/propuesta-mundo-5.md §8,
§4.6 y §6.1, 2026-10-29).

Arte PROVISIONAL por script (sin AutoSprite), hermana de tools/gen_hub_piece_w3.py y de la pieza 4 de
tools/gen_hub_update_art.py: la foto rota del hub (tools/gen_hub_objects.py) tiene cinco piezas; la 1 se enciende en
cian (Alerta Mayor), la 2 en ambar (Autoplay), la 3 en verde acido (La Curadora) y la 4 en coral (El Visto). Esta
herramienta dibuja la pieza 5 (la de abajo a la derecha, gh.PIECES[4]) como CAPA ENCIMA del fondo con las piezas 1-4
ya encendidas: el Mundo 5 solo se abre al vencer a El Visto, asi que la base es gen_hub_update_art.compose4('on') (lo
comprueba main) y cada imagen es la diferencia con ella (el resto, transparente). Color: el Debug del Mundo 5, BLANCO
PURO #ffffff (debug_blanco de assets/palettes/mundo5.gpl, decision 10.1 de la propuesta: variante A), con el
contorno del marco del hub (fondo_profundo) para que se distinga del fondo claro de la pagina 3 (§6.1). Con la pieza
5 la foto queda COMPLETA: la animacion `complete` es un destello blanco que recorre las cinco piezas, una por cuadro
(de la 1 a la 5), y despues HubRoom vuelve a `on`. En assets/sprites/hub_w5/:
  hub_piece_w5_hidden_00.png        transparente (Mundo 5 aun bloqueado: la pieza es una gris mas)
  hub_piece_w5_off_00/01.png        contorno blanco que parpadea (Mundo 5 disponible, sin completar)
  hub_piece_w5_on_00.png            la pieza en su sitio, encendida en blanco con halo (carpeta del Mundo 5 completada)
  hub_piece_w5_complete_00..04.png  fondo completo: destello blanco en la pieza 1, 2, 3, 4 y 5 (un cuadro cada una)
  hub_piece_w5_frames.tres          SpriteFrames (hidden, off, on, complete) que usa HubRoom (room.pieces de
                                    data/hub.json)

Uso: python3 tools/gen_hub_piece_w5.py [--check]   (necesita Pillow: /usr/bin/python3 sin -I en macOS;
--check: 1 si algun archivo no esta al dia o algun PNG se sale de la paleta)
"""
import io
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_hub_objects as gh  # noqa: E402
import gen_hub_piece_w2 as w2  # noqa: E402
import gen_hub_piece_w3 as w3  # noqa: E402
import gen_hub_update_art as w4  # noqa: E402

OUT = os.path.join("assets", "sprites", "hub_w5")
RES = "res://assets/sprites/hub_w5/"
PIECE5 = 4  # indice en gh.PIECES: la pieza de abajo a la derecha
BLANCO = gh.load_gpl(os.path.join(REPO, "assets", "palettes", "mundo5.gpl"))["debug_blanco"]
LIT5 = {gh.GA: BLANCO, gh.GF: gh.TC, gh.BA: gh.TT, gh.DK: gh.TT}
PALETTE = w4.PALETTE | {BLANCO[:3]}
COMPLETE_FRAMES = 5
COMPLETE_FPS = 6.0


def compose5(mode, frame=0):
    """Fondo con las piezas 1-4 encendidas y la 5 en `mode`: 'base' (= w4.compose4('on')), 'hint' (contorno blanco;
    frame 1 tenue), 'on' (en su sitio, encendida en blanco, con halo y el contorno del marco) o 'complete' (las cinco
    encendidas y la pieza `frame` (0-4, en el orden de gh.PIECES) con el destello blanco). Mismo orden de pintado que
    gen_hub_update_art.compose4."""
    cv = gh.Canvas(gh.BG_W, gh.BG_H, gh.BA)
    for pts in ([(0, 64), (52, 64), (64, 76), (96, 76)],
                [(0, 132), (40, 132), (52, 120), (92, 120)],
                [(0, 212), (60, 212), (76, 228), (76, 268)],
                [(20, 288), (20, 252), (36, 236), (96, 236)],
                [(639, 58), (588, 58), (576, 70), (544, 70)],
                [(639, 150), (604, 150), (592, 138), (548, 138)],
                [(639, 226), (580, 226), (566, 240), (566, 272)],
                [(256, 272), (300, 272), (312, 260), (420, 260), (432, 272), (480, 272)]):
        gh.trace(cv, pts)
    x0, y0, x1, y1 = gh.PHOTO
    cv.rect(x0 - 7, y0 - 7, x1 + 7, y1 + 7, gh.FP)
    cv.rect(x0 - 6, y0 - 6, x1 + 6, y1 + 6, gh.SO)
    cv.hline(x0 - 6, x1 + 6, y0 - 6, gh.PA)
    cv.vline(x0 - 6, y0 - 6, y1 + 6, gh.PA)
    photo = gh.photo_content()
    w, h = photo.size
    src = photo.load()
    insides = {}
    lit = {0: gh.LIT, w2.PIECE: w2.LIT2, w3.PIECE: w3.LIT3, w4.PIECE4: w4.LIT4}
    full = mode in ("on", "complete")
    if full:
        lit[PIECE5] = LIT5
    flash = frame if mode == "complete" else -1
    for i, poly in enumerate(gh.PIECES):
        placed = i in lit
        dx, dy = (0, 0) if placed else gh.OFFSETS[i]
        mpx = gh.polygon_mask(poly, w, h).load()
        pts = [(x, y) for y in range(h) for x in range(w) if mpx[x, y]]
        inside = set(pts)
        insides[i] = inside
        for x, y in pts:
            c = src[x, y]
            if placed:
                c = lit[i].get(c, c)
            if i == flash and c not in (gh.FP, gh.SO):
                c = BLANCO
            cv.p(x0 + x + dx, y0 + y + dy, c)
        edge = gh.FP
        if i == w2.PIECE:
            edge = w2.AMBAR_SOMBRA
        elif i == w3.PIECE:
            edge = w3.SOMBRA
        elif i == w4.PIECE4:
            edge = gh.AS
        elif i == PIECE5 and mode == "hint":
            edge = BLANCO if frame == 0 else gh.TT
        if i == flash:
            edge = BLANCO
        for x, y in pts:
            if any((x + ex, y + ey) not in inside for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.p(x0 + x + dx, y0 + y + dy, edge)
    halos = [(0, gh.CT), (w2.PIECE, w2.AMBAR), (w3.PIECE, w3.VERDE), (w4.PIECE4, w4.CORAL)]
    if full:
        halos.append((PIECE5, BLANCO))
    for i, color in halos:
        for x, y in insides[i]:
            for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + ex, y + ey)
                if q not in insides[i] and cv.get(x0 + q[0], y0 + q[1]) == gh.SO:
                    cv.p(x0 + q[0], y0 + q[1], BLANCO if i == flash else color)
    sx, sy = x0 + 196, y0 + 30
    cv.p(sx, sy, gh.TC)
    for k in (1, 2, 3):
        for ex, ey in ((k, 0), (-k, 0), (0, k), (0, -k)):
            cv.p(sx + ex, sy + ey, gh.CB if k < 3 else gh.CA)
    return cv.x2()


FILES = (["hub_piece_w5_hidden_00.png", "hub_piece_w5_off_00.png", "hub_piece_w5_off_01.png", "hub_piece_w5_on_00.png"]
         + ["hub_piece_w5_complete_%02d.png" % i for i in range(COMPLETE_FRAMES)])


def outputs():
    base = compose5("base")
    out = {FILES[0]: Image.new("RGBA", base.size, (0, 0, 0, 0)),
           FILES[1]: w2.overlay(compose5("hint", 0), base),
           FILES[2]: w2.overlay(compose5("hint", 1), base),
           FILES[3]: w2.overlay(compose5("on"), base)}
    for i in range(COMPLETE_FRAMES):
        out[FILES[4 + i]] = w2.overlay(compose5("complete", i), base)
    return out


def frames_tres():
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(FILES) + 1), ""]
    for i, f in enumerate(FILES, 1):
        lines.append('[ext_resource type="Texture2D" path="%s%s" id="%d_%s"]' % (RES, f, i, f[:-4]))
    lines.append("")
    lines.append("[resource]")

    def frames(ids):
        return ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%d_%s")\n}' % (i, FILES[i - 1][:-4]) for i in ids)
    anims = [("complete", list(range(5, 5 + COMPLETE_FRAMES)), COMPLETE_FPS, "false"), ("hidden", [1], 1.0, "true"),
             ("off", [2, 3], 1.5, "true"), ("on", [4], 1.0, "true")]
    body = ", ".join('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (frames(ids), loop, name, speed)
                     for name, ids, speed, loop in anims)
    lines.append("animations = [%s]" % body)
    return "\n".join(lines) + "\n"


def palette_errors(name, img):
    bad = set()
    for r, g, b, a in img.getdata():
        if a not in (0, 255):
            bad.add("alfa %d" % a)
        elif a == 255 and (r, g, b) not in PALETTE:
            bad.add("#%02x%02x%02x" % (r, g, b))
        elif a == 255 and (r, g, b) in w4.RESERVED:
            bad.add("rojo reservado #%02x%02x%02x" % (r, g, b))
    return ["%s: %s fuera de la paleta" % (name, c) for c in sorted(bad)]


def main(argv):
    out_dir = os.path.join(REPO, OUT)
    if list(compose5("base").getdata()) != list(w4.compose4("on").getdata()):
        print("gen_hub_piece_w5: compose5('base') ya no coincide con gen_hub_update_art.compose4('on')")
        return 1
    imgs = outputs()
    errors = []
    for name, img in imgs.items():
        errors.extend(palette_errors(name, img))
    if not any(px[3] for px in imgs[FILES[3]].getdata()):
        errors.append("la pieza 5 encendida no se ve")
    tres = frames_tres()
    tres_path = os.path.join(out_dir, "hub_piece_w5_frames.tres")
    if "--check" in argv:
        for name, img in imgs.items():
            path = os.path.join(out_dir, name)
            if not os.path.exists(path) or list(Image.open(path).convert("RGBA").getdata()) != list(img.getdata()):
                errors.append("%s: sin actualizar" % name)
        if not os.path.exists(tres_path) or open(tres_path, encoding="utf-8").read() != tres:
            errors.append("hub_piece_w5_frames.tres: sin actualizar")
        if errors:
            print("gen_hub_piece_w5: " + "; ".join(errors))
            return 1
        print("gen_hub_piece_w5: al dia (%d PNG)" % len(imgs))
        return 0
    if errors:
        print("gen_hub_piece_w5: " + "; ".join(errors))
        return 1
    os.makedirs(out_dir, exist_ok=True)
    for name, img in imgs.items():
        img.save(os.path.join(out_dir, name), optimize=True)
    with open(tres_path, "w", encoding="utf-8") as fh:
        fh.write(tres)
    print("gen_hub_piece_w5: %d PNG + frames" % len(imgs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
