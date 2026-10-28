#!/usr/bin/env python3
"""Arte del acertijo «Actualizacion del sistema» y de la instalacion del hub (2026-10-27, paso 7 de
docs/propuesta-hub-mundos-4-6.md §2.2, §3.1 y §5.1). Arte PROVISIONAL por script (sin AutoSprite).

Lo que solo usa los colores del hub (fondo de las paginas 2 y 3, carpetas M4-M6, candado de La Nube e
instalador) va en tools/gen_hub_objects.py. Aqui va lo que lleva los colores del Debug de cada mundo:
paleta del hub (assets/palettes/hub.gpl) + debug_ambar del Mundo 2 (#ffa858, mundo2.gpl) + debug_verde
del Mundo 3 (#a6ff2e, mundo3.gpl) + el CORAL de la pieza 4 (#ff9f7a «coral melocoton», decidido por el
usuario el 2026-10-27, docs/propuesta-mundo-4.md §10.1; antes #ff7f66 provisional; es el debug_coral de
tools/palette_mundo4_provisional.py, que comprueba que coinciden). Sin rojo (en el hub nada
hace dano). Arte a 1 px logico y x2 en pantalla, alfa 0 o 255. En assets/sprites/hub_update/:

  update_check_<v1|v2|v3>_<off_00|done_00|done_01|inert_00>.png   64x128  verificaciones (UpdateCheck):
        marco del color de su mundo (v1 cian, v2 ambar, v3 verde acido; data/hub_update.json colors) y los
        PICTOGRAMAS de las habilidades que pide (CHECK_ABILITIES); hecha = pantalla encendida (2 cuadros).
  pictogram_<habilidad>_00.png   24x24   pictogramas sueltos (pulso, laser y Debug de los chips de Calc,
        tools/gen_calc_chips.py; Deslizar, golpe al suelo y Pellizcar nuevos), para paneles y Notas.
  pound_plate_<on|inert>_00.png  64x32   placa de golpe al suelo (V2) con el dibujo de la onda.
  loading_platform_<00|01>.png   128x16  plataforma temporal «Cargando...» (dos cuadros de las franjas).
  edge_glitch_<00|01>.png        64x64   glitch del borde (HubEdgeGlitch; se repite en vertical; 01 =
        el cuadro del parpadeo).
  install_panel_00.png           532x124 panel de la instalacion (HubUpdateInstall; a la medida de
        hub_update_install.bar_size_px de data/hub.json) y install_bar_fill_<0|1|2>_00.png (un tercio de la
        barra en el color de cada verificacion).
  hub_piece_w4_<hidden_00|off_00|off_01|on_00>.png + hub_piece_w4_frames.tres   pieza 4 del fondo en
        coral (capa encima del fondo con las piezas 1-3 encendidas, como
        tools/gen_hub_piece_w3.py: base = gen_hub_piece_w3.compose('on'), lo comprueba main).

Uso: python3 -I tools/gen_hub_update_art.py [--check] [--preview <png>]
  --check: 1 si algun archivo no esta al dia o algun PNG se sale de la paleta (validador incluido).
"""
import io
import json
import math
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
import gen_calc_chips as chips  # noqa: E402

OUT = os.path.join("assets", "sprites", "hub_update")
RES = "res://assets/sprites/hub_update/"
FP, SO, PA, DK, BA, GA, GF, TR, BO = gh.FP, gh.SO, gh.PA, gh.DK, gh.BA, gh.GA, gh.GF, gh.TR, gh.BO
TT, TC, CT, CA, CB, AM, AS = gh.TT, gh.TC, gh.CT, gh.CA, gh.CB, gh.AM, gh.AS
CLEAR = gh.CLEAR
Canvas = gh.Canvas
AMBAR = gh.load_gpl(os.path.join(REPO, "assets", "palettes", "mundo2.gpl"))["debug_ambar"]
VERDE = gh.load_gpl(os.path.join(REPO, "assets", "palettes", "mundo3.gpl"))["debug_verde"]
CORAL = (0xff, 0x9f, 0x7a, 255)  # Debug del Mundo 4 (decidido 2026-10-27; = debug_coral de palette_mundo4_provisional.py)
PALETTE = {c[:3] for c in gh.PAL.values()} | {AMBAR[:3], VERDE[:3], CORAL[:3]}
RESERVED = {(0xdc, 0x00, 0x00), (0xff, 0x38, 0x38)}
CHECK_COLORS = {"v1": CA, "v2": AMBAR, "v3": VERDE}  # = colors de data/hub_update.json (lo comprueba main)
# Habilidades que pide cada verificacion (§2.3; el pulso, basico, no se dibuja): V1 Debug + laser (lector1
# oculto), V2 golpe al suelo + Deslizar (placa y bloque alto), V3 laser + Pellizcar (espejo y nicho).
CHECK_ABILITIES = {"v1": ["debug", "laser"], "v2": ["ground_pound", "dash"], "v3": ["laser", "pinch"]}

# Pictogramas nuevos de 12x12 (mismo formato que gen_calc_chips.ICON_ART: '#' claro, '+' color, 'o' sombra).
NEW_ICONS = {
    "dash": [  # flecha con lineas de velocidad (Deslizar)
        "............",
        "......#.....",
        "......##....",
        "#++...###...",
        "......####..",
        "+++++.#####.",
        "+++++.#####.",
        "......####..",
        "#++...###...",
        "......##....",
        "......#.....",
        "............",
    ],
    "ground_pound": [  # flecha abajo contra el suelo y la onda (golpe al suelo)
        "....####....",
        "....####....",
        "..########..",
        "...######...",
        "....####....",
        ".....##.....",
        "............",
        "############",
        "#oooooooooo#",
        "............",
        ".++......++.",
        "+..........+",
    ],
    "pinch": [  # marcas de recorte y flechas que aprietan (Pellizcar)
        "............",
        "..++....++..",
        "..++....++..",
        "............",
        "#...####...#",
        "##..#oo#..##",
        "###.#oo#.###",
        "##..#oo#..##",
        "#...####...#",
        "............",
        "..++....++..",
        "..++....++..",
    ],
}
ICONS = {**{k: chips.ICON_ART[k] for k in ("pulse", "laser", "debug")}, **NEW_ICONS}


def stamp_icon(cv, x, y, name, cmap):
    cv.stamp(x, y, ICONS[name], cmap)


# ------------------------------------------------------------- verificaciones (32x64 x2)
def update_check(check_id, state, frame=0):
    """state: off (pantalla apagada con los pictogramas), done (encendida; frame 1 = brillo) o inert
    (Papelera llena: todo gris)."""
    cv = Canvas(32, 64)
    color = CHECK_COLORS[check_id] if state != "inert" else GA
    cv.box(0, 0, 31, 56, color, FP)
    cv.rect(2, 2, 29, 54, PA)
    cv.hline(2, 29, 2, TR if state != "inert" else DK)
    if state == "done" and frame == 1:
        cv.rect(1, 1, 30, 1, TC)
    sx0, sy0, sx1, sy1 = 4, 4, 27, 45
    cv.rect(sx0, sy0, sx1, sy1, FP)
    lit = state == "done"
    if lit:
        cv.rect(sx0 + 1, sy0 + 1, sx1 - 1, sy1 - 1, color)
        cmap = {"#": FP, "+": FP, "o": color if frame == 0 else TC}
    elif state == "inert":
        cv.rect(sx0 + 1, sy0 + 1, sx1 - 1, sy1 - 1, DK)
        cmap = {"#": GA, "+": GA, "o": DK}
    else:
        cv.rect(sx0 + 1, sy0 + 1, sx1 - 1, sy1 - 1, SO)
        cmap = {"#": TC, "+": color, "o": PA}
    names = CHECK_ABILITIES[check_id]
    gap = 4
    total = len(names) * 12 + (len(names) - 1) * gap
    y = sy0 + 1 + (sy1 - sy0 - 1 - total) // 2
    for name in names:
        stamp_icon(cv, 10, y, name, cmap)
        y += 12 + gap
    # Debajo: la marca de hecho (V) o tres puntos de espera.
    if lit:
        for k, (dx, dy) in enumerate(((0, 0), (1, 1), (2, 2), (3, 1), (4, 0), (5, -1), (6, -2))):
            cv.rect(12 + dx, 50 + dy, 12 + dx, 51 + dy, color)
    else:
        for k in range(3):
            cv.rect(11 + k * 4, 50, 12 + k * 4, 51, GA if state == "inert" else TT)
    # Pie.
    cv.rect(11, 57, 20, 63, FP)
    cv.rect(12, 57, 19, 62, DK)
    cv.hline(12, 19, 57, GF)
    return cv.x2()


def pictogram(name):
    cv = Canvas(12, 12)
    stamp_icon(cv, 0, 0, name, {"#": TC, "+": CA, "o": CT})
    return cv.x2()


# ------------------------------------------------------------- V2: placa y plataforma
def pound_plate(inert):
    """Placa de 32x4 (x2 = 64x8) apoyada abajo con la onda del golpe encima (32x16 x2 = 64x32)."""
    cv = Canvas(32, 16)
    color = GA if inert else AMBAR
    cv.rect(0, 12, 31, 15, FP)
    cv.rect(1, 12, 30, 14, DK)
    cv.hline(1, 30, 12, color)
    cv.rect(13, 13, 18, 14, color)
    for r, c in ((3.5, color), (6.8, color), (10.0, TT if not inert else BA)):
        for x in range(32):
            for y in range(0, 12):
                d = math.hypot(x - 15.5, (y - 12) * 1.25)
                if r - 0.6 <= d <= r + 0.4 and y < 11:
                    cv.p(x, y, c)
    return cv.x2()


def loading_platform(frame):
    """Plataforma «Cargando...» de 64x8 (x2 = 128x16): losa con franjas que avanzan (2 cuadros)."""
    cv = Canvas(64, 8)
    cv.box(0, 0, 63, 7, PA, FP)
    cv.hline(1, 62, 1, AMBAR)
    for x in range(2, 62):
        if (x + frame * 3) % 6 < 3:
            cv.vline(x, 3, 5, AMBAR if (x // 6) % 2 == 0 else AS)
    cv.hline(2, 61, 6, DK)
    return cv.x2()


# ------------------------------------------------------------- glitch del borde (32x32 x2)
def edge_glitch(frame):
    """Franjas rotas en cian, ambar y verde acido pegadas al borde derecho (transparente detras)."""
    cv = Canvas(32, 32)
    colors = (CA, AMBAR, VERDE)
    shift = 3 if frame else 0
    for i in range(16):
        k = (i * 7 + shift * 5) % 11
        if k > 6:
            continue
        c = colors[(i + shift) % 3]
        w = 4 + ((k * 13) % 5) * 4
        x1 = 31 - ((k * 3 + shift) % 3) * 2
        h = 2 if k % 3 else 1
        cv.rect(x1 - w + 1, i * 2, x1, i * 2 + h - 1, c)
        if k % 2 == 0:  # pixeles sueltos (ruido)
            cv.p(x1 - w - 2, i * 2, c)
    return cv.x2()


# ------------------------------------------------------------- instalacion (barra)
def _bar_size():
    with open(os.path.join(REPO, "data", "hub.json"), encoding="utf-8") as fh:
        cfg = json.load(fh).get("hub_update_install", {})
    w, h = cfg.get("bar_size_px", [480, 24])
    return int(w), int(h)


def install_panel():
    """Panel de HubUpdateInstall (el rect panel.grow(2) de su _draw): borde cian, esquinas cortadas,
    flecha de descarga a cada lado del titulo y el hueco de la barra (bar_rect.grow(2))."""
    bw, bh = _bar_size()
    lw, lh = (bw + 48 + 4) // 2, (bh + 96 + 4) // 2
    cv = Canvas(lw, lh)
    cv.box(0, 0, lw - 1, lh - 1, CA, FP)
    cv.rect(1, 1, lw - 2, lh - 2, CA)
    cv.rect(2, 2, lw - 3, lh - 3, FP)
    cv.hline(3, lw - 4, 3, SO)
    for x in (8, lw - 16):
        cv.stamp(x, 8, gh.DOWNLOAD, {"#": CT})
    # bar_rect.grow(2) de _InstallArt: x 24 px y y 72 px desde la esquina del panel.grow(2).
    bx0, by0 = 12, 36
    bx1, by1 = bx0 + (bw + 4) // 2 - 1, by0 + (bh + 4) // 2 - 1
    cv.rect(bx0, by0, bx1, by1, BO)
    cv.rect(bx0 + 1, by0 + 1, bx1 - 1, by1 - 1, BA)
    for x in range(bx0 + 1, bx1, 8):
        cv.vline(x, by0 + 1, by1 - 1, DK)
    return cv.x2()


def install_bar_fill(index):
    bw, bh = _bar_size()
    color = (CA, AMBAR, VERDE)[index]
    shade = (CT, AS, CT)[index]
    w, h = bw // 6, bh // 2
    cv = Canvas(w, h, color)
    for y in range(h):
        for x in range(w):
            if (x + y) % 8 < 2:
                cv.p(x, y, shade)
    cv.hline(0, w - 1, 0, TC)
    return cv.x2()


# ------------------------------------------------------------- pieza 4 del fondo (coral #ff9f7a)
PIECE4 = 3  # indice en gh.PIECES: la pieza grande de abajo a la izquierda
LIT4 = {gh.GA: CORAL, gh.GF: TC, gh.BA: AS, gh.DK: AS}


def compose4(mode, frame=0):
    """Fondo con las piezas 1-3 encendidas y la 4 en `mode`: 'base' (= w3.compose('on')), 'hint'
    (contorno coral; frame 1 tenue) u 'on' (en su sitio, encendida en coral, con halo). Mismo orden de
    pintado que gen_hub_piece_w3.compose."""
    cv = Canvas(gh.BG_W, gh.BG_H, gh.BA)
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
    lit = {0: gh.LIT, w2.PIECE: w2.LIT2, w3.PIECE: w3.LIT3}
    if mode == "on":
        lit[PIECE4] = LIT4
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
        elif i == w3.PIECE:
            edge = w3.SOMBRA
        elif i == PIECE4 and mode == "hint":
            edge = CORAL if frame == 0 else AS
        elif i == PIECE4 and mode == "on":
            edge = AS
        for x, y in pts:
            if any((x + ex, y + ey) not in inside for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cv.p(x0 + x + dx, y0 + y + dy, edge)
    halos = [(0, gh.CT), (w2.PIECE, w2.AMBAR), (w3.PIECE, w3.VERDE)] + ([(PIECE4, CORAL)] if mode == "on" else [])
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


PIECE_FILES = ["hub_piece_w4_hidden_00.png", "hub_piece_w4_off_00.png", "hub_piece_w4_off_01.png",
               "hub_piece_w4_on_00.png"]


def piece_frames_tres():
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(PIECE_FILES) + 1), ""]
    for i, f in enumerate(PIECE_FILES, 1):
        lines.append('[ext_resource type="Texture2D" path="%s%s" id="%d_%s"]' % (RES, f, i, f[:-4]))
    lines.append("")
    lines.append("[resource]")

    def frames(ids):
        return ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%d_%s")\n}' % (i, PIECE_FILES[i - 1][:-4])
                         for i in ids)
    anims = [("hidden", [1], 1.0), ("off", [2, 3], 1.5), ("on", [4], 1.0)]
    body = ", ".join('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (frames(ids), name, speed)
                     for name, ids, speed in anims)
    lines.append("animations = [%s]" % body)
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------- salida
def outputs():
    out = {}
    for cid in CHECK_COLORS:
        out[f"update_check_{cid}_off_00.png"] = update_check(cid, "off")
        out[f"update_check_{cid}_done_00.png"] = update_check(cid, "done", 0)
        out[f"update_check_{cid}_done_01.png"] = update_check(cid, "done", 1)
        out[f"update_check_{cid}_inert_00.png"] = update_check(cid, "inert")
    for name in ICONS:
        out[f"pictogram_{name}_00.png"] = pictogram(name)
    out["pound_plate_on_00.png"] = pound_plate(False)
    out["pound_plate_inert_00.png"] = pound_plate(True)
    for f in range(2):
        out[f"loading_platform_{f:02d}.png"] = loading_platform(f)
        out[f"edge_glitch_{f:02d}.png"] = edge_glitch(f)
    out["install_panel_00.png"] = install_panel()
    for i in range(3):
        out[f"install_bar_fill_{i}_00.png"] = install_bar_fill(i)
    base = compose4("base")
    out[PIECE_FILES[0]] = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out[PIECE_FILES[1]] = w2.overlay(compose4("hint", 0), base)
    out[PIECE_FILES[2]] = w2.overlay(compose4("hint", 1), base)
    out[PIECE_FILES[3]] = w2.overlay(compose4("on"), base)
    return out


def palette_errors(name, img):
    errs = []
    bad = set()
    for r, g, b, a in img.convert("RGBA").getdata():
        if a not in (0, 255):
            errs.append(f"{name}: pixeles semitransparentes")
            break
        if a == 255 and ((r, g, b) not in PALETTE or (r, g, b) in RESERVED):
            bad.add((r, g, b))
    errs += [f"{name}: color fuera de la paleta #%02x%02x%02x" % c for c in sorted(bad)[:5]]
    return errs


def preview(imgs, path):
    keys = [k for k in imgs if not k.startswith("hub_piece") and not k.startswith("install_panel")]
    pad = 8
    w = sum(imgs[k].width + pad for k in keys) + pad
    h = max(imgs[k].height for k in keys) + 2 * pad
    sheet = Image.new("RGBA", (w, h + imgs["install_panel_00.png"].height + pad), BA)
    x = pad
    for k in keys:
        sheet.alpha_composite(imgs[k], (x, pad))
        x += imgs[k].width + pad
    sheet.alpha_composite(imgs["install_panel_00.png"], (pad, h))
    sheet.save(path)


def main(argv):
    with open(os.path.join(REPO, "data", "hub_update.json"), encoding="utf-8") as fh:
        colors = json.load(fh).get("colors", {})
    for cid, c in CHECK_COLORS.items():
        if str(colors.get(cid, "")).lower() != "#%02x%02x%02x" % c[:3]:
            print(f"gen_hub_update_art: el color de {cid} ya no coincide con data/hub_update.json")
            return 1
    if list(compose4("base").getdata()) != list(w3.compose("on").getdata()):
        print("gen_hub_update_art: compose4('base') ya no coincide con gen_hub_piece_w3.compose('on')")
        return 1
    imgs = outputs()
    out_dir = os.path.join(REPO, OUT)
    tres = piece_frames_tres()
    tres_path = os.path.join(out_dir, "hub_piece_w4_frames.tres")
    errs = []
    for name, img in imgs.items():
        errs += palette_errors(name, img)
    if "--check" in argv:
        expected = set(imgs) | {"hub_piece_w4_frames.tres"}
        present = {f for f in os.listdir(out_dir) if not f.endswith(".import")} if os.path.isdir(out_dir) else set()
        errs += [f"{f}: no lo produce el generador" for f in sorted(present - expected)]
        for name, img in imgs.items():
            path = os.path.join(out_dir, name)
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != img.convert("RGBA").tobytes():
                errs.append(f"{name}: sin actualizar (regenera con python3 -I tools/gen_hub_update_art.py)")
        if not os.path.exists(tres_path) or open(tres_path, encoding="utf-8").read() != tres:
            errs.append("hub_piece_w4_frames.tres: sin actualizar")
        if errs:
            print("gen_hub_update_art:\n  " + "\n  ".join(errs))
            return 1
        print("gen_hub_update_art: al dia (%d PNG)" % len(imgs))
        return 0
    if errs:
        print("gen_hub_update_art:\n  " + "\n  ".join(errs))
        return 1
    os.makedirs(out_dir, exist_ok=True)
    for name, img in imgs.items():
        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=True)
        with open(os.path.join(out_dir, name), "wb") as fh:
            fh.write(buf.getvalue())
    with open(tres_path, "w", encoding="utf-8") as fh:
        fh.write(tres)
    if "--preview" in argv:
        preview(imgs, argv[argv.index("--preview") + 1])
    print("gen_hub_update_art: %d PNG + frames" % len(imgs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
