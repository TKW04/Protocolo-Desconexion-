#!/usr/bin/env python3
"""Pieza VERDE ACIDO del fondo del hub (Mundo 3 «La Vitrina»; paso 17 de docs/propuesta-mundo-3.md §8, 2026-10-27).

Arte PROVISIONAL por script (sin AutoSprite), hermana de tools/gen_hub_piece_w2.py: la foto rota del hub
(tools/gen_hub_objects.py) tiene cinco piezas; la 1 (arriba al centro) se enciende en cian con Alerta Mayor y la 2
(arriba a la izquierda) en ambar con Autoplay. Esta herramienta dibuja la pieza 3 (arriba a la derecha) como CAPA
ENCIMA del fondo encendido con la ambar ya en su sitio: el Mundo 3 solo se abre al vencer a Autoplay, asi que la
base es gen_hub_piece_w2.compose('on') (lo comprueba main) y cada imagen es la diferencia con ella (el resto,
transparente). Ni el fondo, ni la pieza ambar, ni sus validadores cambian. Colores de la pieza: paleta B del Mundo 3
(assets/palettes/mundo3.gpl: debug_verde y blanco_brillante, el brillo) y la sombra cian_tenue del hub (hub.gpl;
la paleta B no tiene un verde oscuro y la pieza 1 encendida ya la usa); lo que queda al recolocar la pieza usa los del
hub. En assets/sprites/hub_w3/:
  hub_piece_w3_hidden_00.png   transparente (Mundo 3 aun bloqueado: la pieza es una gris mas)
  hub_piece_w3_off_00/01.png   contorno verde que parpadea (Mundo 3 desbloqueado, sin completar)
  hub_piece_w3_on_00.png       la pieza en su sitio, encendida en verde acido con halo (carpeta del Mundo 3 completada)
  hub_piece_w3_frames.tres     SpriteFrames (hidden, off, on) que usa HubRoom (seccion room.pieces de data/hub.json)

Uso: python3 -I tools/gen_hub_piece_w3.py [--check]   (--check: 1 si algun archivo no esta al dia)
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

OUT = os.path.join("assets", "sprites", "hub_w3")
RES = "res://assets/sprites/hub_w3/"
PIECE = 2  # indice en gh.PIECES: la pieza 3 (arriba a la derecha)
M3 = gh.load_gpl(os.path.join(REPO, "assets", "palettes", "mundo3.gpl"))
VERDE, BRILLO, SOMBRA = M3["debug_verde"], M3["blanco_brillante"], gh.CT
LIT3 = {gh.GA: VERDE, gh.GF: BRILLO, gh.BA: SOMBRA, gh.DK: SOMBRA}


def compose(mode, frame=0):
    """Fondo con la pieza 1 (cian) y la 2 (ambar) encendidas y la pieza 3 en `mode`: 'base' (identico a
    w2.compose('on'); lo comprueba main), 'hint' (contorno verde; frame 0 vivo y 1 tenue) u 'on' (en su sitio,
    encendida en verde acido, con halo). Mismo orden de pintado que gh.background y w2.compose."""
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
    lit = {0: gh.LIT, w2.PIECE: w2.LIT2}
    if mode == "on":
        lit[PIECE] = LIT3
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
            cv.p(x0 + x + dx, y0 + y + dy, c)
        edge = gh.FP
        if i == w2.PIECE:
            edge = w2.AMBAR_SOMBRA
        elif i == PIECE and mode == "hint":
            edge = VERDE if frame == 0 else SOMBRA
        elif i == PIECE and mode == "on":
            edge = SOMBRA
        for x, y in pts:
            if any((x + ex, y + ey) not in inside for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.p(x0 + x + dx, y0 + y + dy, edge)
    halos = [(0, gh.CT), (w2.PIECE, w2.AMBAR)] + ([(PIECE, VERDE)] if mode == "on" else [])
    for i, color in halos:
        for x, y in insides[i]:
            for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + ex, y + ey)
                if q not in insides[i] and cv.get(x0 + q[0], y0 + q[1]) == gh.SO:
                    cv.p(x0 + q[0], y0 + q[1], color)
    sx, sy = x0 + 196, y0 + 30
    cv.p(sx, sy, gh.TC)
    for k in (1, 2, 3):
        for ex, ey in ((k, 0), (-k, 0), (0, k), (0, -k)):
            cv.p(sx + ex, sy + ey, gh.CB if k < 3 else gh.CA)
    return cv.x2()


def outputs():
    base = compose("base")
    return {
        "hub_piece_w3_hidden_00.png": Image.new("RGBA", base.size, (0, 0, 0, 0)),
        "hub_piece_w3_off_00.png": w2.overlay(compose("hint", 0), base),
        "hub_piece_w3_off_01.png": w2.overlay(compose("hint", 1), base),
        "hub_piece_w3_on_00.png": w2.overlay(compose("on"), base),
    }


def frames_tres():
    files = ["hub_piece_w3_hidden_00.png", "hub_piece_w3_off_00.png", "hub_piece_w3_off_01.png",
             "hub_piece_w3_on_00.png"]
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(files) + 1), ""]
    for i, f in enumerate(files, 1):
        lines.append('[ext_resource type="Texture2D" path="%s%s" id="%d_%s"]' % (RES, f, i, f[:-4]))
    lines.append("")
    lines.append("[resource]")

    def frames(ids):
        return ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%d_%s")\n}' % (i, files[i - 1][:-4]) for i in ids)
    anims = [("hidden", [1], 1.0), ("off", [2, 3], 1.5), ("on", [4], 1.0)]
    body = ", ".join('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (frames(ids), name, speed)
                     for name, ids, speed in anims)
    lines.append("animations = [%s]" % body)
    return "\n".join(lines) + "\n"


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def main(argv):
    out_dir = os.path.join(REPO, OUT)
    if list(compose("base").getdata()) != list(w2.compose("on").getdata()):
        print("gen_hub_piece_w3: compose('base') ya no coincide con gen_hub_piece_w2.compose('on')")
        return 1
    imgs = outputs()
    stale = []
    for name, img in imgs.items():
        path = os.path.join(out_dir, name)
        if "--check" in argv:
            if not os.path.exists(path) or list(Image.open(path).convert("RGBA").getdata()) != list(img.getdata()):
                stale.append(name)
        else:
            os.makedirs(out_dir, exist_ok=True)
            img.save(path, optimize=True)
    tres = frames_tres()
    tres_path = os.path.join(out_dir, "hub_piece_w3_frames.tres")
    if "--check" in argv:
        if not os.path.exists(tres_path) or open(tres_path, encoding="utf-8").read() != tres:
            stale.append("hub_piece_w3_frames.tres")
        if stale:
            print("gen_hub_piece_w3: sin actualizar: " + ", ".join(stale))
            return 1
        print("gen_hub_piece_w3: al dia (%d PNG)" % len(imgs))
        return 0
    with open(tres_path, "w", encoding="utf-8") as fh:
        fh.write(tres)
    print("gen_hub_piece_w3: %d PNG + frames" % len(imgs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
