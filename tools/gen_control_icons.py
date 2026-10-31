#!/usr/bin/env python3
"""Iconos de las filas de Pausa > Ajustes > Controles (2026-10-30, peticion del
usuario tras el 5-2: «en el menu de controles vamos a colocar iconos a cada
movimiento y solo vas a colocar la tecla o el boton»; docs/05-hub.md §13.7).

Un icono de 12 x 12 px de arte por movimiento, con el estilo y la paleta de los
iconos del menu de pausa (menu_pause_* de tools/gen_hub_objects.py: colores de
assets/palettes/hub.gpl, contorno fondo_profundo de 1 px alrededor de lo opaco,
fondo transparente). Se dibujan con plantillas de 12 x 12 caracteres:
  # texto_claro   t texto_tenue   c acento_cian   b cian_brillo   a ambar
  o borde         . transparente
El de restablecer reutiliza el dibujo de menu_pause_reset (_pause_reset).

Salida: assets/sprites/controls/ctrl_<id>_00.png (un PNG por fila de menu_rows de
data/settings.json; la clave icon de cada fila apunta aqui).

--check (lo ejecuta tools/run_tests.sh) no escribe nada y falla si:
  - falta un PNG, sobra uno o no coincide pixel a pixel con lo que se genera;
  - un PNG no mide 12 x 12, tiene alfa distinto de 0 / 255, colores fuera de
    hub.gpl o un rojo reservado (#dc0000, #ff3838);
  - un icono no tiene contraste: menos de MIN_STRONG_PX pixeles con contraste
    WCAG >= MIN_CONTRAST frente al fondo del panel del menu
    (assets/sprites/ui/eco_text_panel.png, centro) o el borde transparente de
    1 px no esta libre (el contorno debe caber);
  - una fila de menu_rows no tiene icono o apunta a un archivo que no se genera.

Uso: python3 -I tools/gen_control_icons.py [--check] [--preview <png>]
"""
import json
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_hub_objects as hub  # noqa: E402

OUT_DIR = os.path.join(REPO, "assets", "sprites", "controls")
RES_DIR = "res://assets/sprites/controls/"
PANEL = os.path.join(REPO, "assets", "sprites", "ui", "eco_text_panel.png")
SETTINGS = os.path.join(REPO, "data", "settings.json")
SIZE = 12
RESERVED = {(0xdc, 0x00, 0x00), (0xff, 0x38, 0x38)}
MIN_CONTRAST = 3.0
MIN_STRONG_PX = 10

CMAP = {"#": hub.TC, "t": hub.TT, "c": hub.CA, "b": hub.CB, "a": hub.AM, "o": hub.BO}

# Plantillas de 12 x 12 (la fila 0, la 11 y las columnas 0 y 11 quedan libres
# para el contorno, salvo donde el dibujo lo pide).
STAMPS = {
    # Mover: flecha con la punta cian.
    "move_left": [
        "............",
        "............",
        ".....#......",
        "....##......",
        "...###......",
        "..c#######..",
        "..c#######..",
        "...###......",
        "....##......",
        ".....#......",
        "............",
        "............",
    ],
    # Saltar: flecha hacia arriba sobre el suelo.
    "jump": [
        "............",
        ".....cc.....",
        "....####....",
        "...######...",
        ".....##.....",
        ".....##.....",
        ".....##.....",
        "............",
        "..tttttttt..",
        "..tttttttt..",
        "............",
        "............",
    ],
    # Caminar (mantener; 2026-10-31, Isak corre por defecto): figura que anda.
    "walk": [
        "............",
        ".....##.....",
        ".....##.....",
        "....###.....",
        "...#.##.....",
        "...#.##.#...",
        "....###.....",
        "....#.#.....",
        "...#...#....",
        "...#....#...",
        "..tt....tt..",
        "............",
    ],
    # Pulso: onda alrededor de un nucleo cian.
    "pulse": [
        "............",
        "....####....",
        "...#....#...",
        "..#......#..",
        ".#...cc...#.",
        ".#..cccc..#.",
        ".#..cccc..#.",
        ".#...cc...#.",
        "..#......#..",
        "...#....#...",
        "....####....",
        "............",
    ],
    # Laser: el celular y su rayo.
    "laser": [
        "............",
        "............",
        "............",
        ".ttt........",
        ".t#t........",
        ".t#tccccccb.",
        ".t#tccccccb.",
        ".t#t........",
        ".ttt........",
        "............",
        "............",
        "............",
    ],
    # Debug: el ojo que ve lo oculto.
    "debug": [
        "............",
        "............",
        "............",
        "....####....",
        "..##....##..",
        ".#...cc...#.",
        ".#..cccc..#.",
        ".#...cc...#.",
        "..##....##..",
        "....####....",
        "............",
        "............",
    ],
    # Deslizar (dash): flecha con estela.
    "dash": [
        "............",
        "............",
        "............",
        ".tt....#....",
        ".......##...",
        ".tt.######c.",
        ".tt.######c.",
        ".......##...",
        ".tt....#....",
        "............",
        "............",
        "............",
    ],
    # Comprimir: dos puntas que aprietan una barra.
    "compress": [
        "............",
        "...######...",
        "....####....",
        ".....##.....",
        "............",
        ".cccccccccc.",
        ".cccccccccc.",
        "............",
        ".....##.....",
        "....####....",
        "...######...",
        "............",
    ],
    # Golpe al suelo: flecha abajo que choca con el suelo.
    "ground_pound": [
        "............",
        ".....##.....",
        ".....##.....",
        ".....##.....",
        "...######...",
        "....####....",
        ".....##.....",
        ".a...cc...a.",
        "..a......a..",
        ".tttttttttt.",
        ".tttttttttt.",
        "............",
    ],
    # Ocultarte: silueta cortada por el glitch cian.
    "hide": [
        "............",
        "....tttt....",
        "....tttt....",
        "............",
        "...cccccc...",
        "...c.cc.c...",
        "............",
        "...cccccc...",
        "...c....c...",
        "...cc..cc...",
        "............",
        "............",
    ],
    # Embestida: caida en diagonal contra la persiana.
    "combo_ram": [
        "............",
        ".##.........",
        ".###........",
        "..###.......",
        "...###......",
        "....###.....",
        ".....###.tt.",
        "......##.tt.",
        "....####.tt.",
        "........att.",
        ".tttttt.att.",
        "............",
    ],
    # Filo: el cuerpo plano cruza la ranura de precios.
    "combo_edge": [
        "............",
        ".tttttttttt.",
        ".tttttttttt.",
        "............",
        ".......#....",
        ".cccccc###..",
        ".cccccc###..",
        ".......#....",
        "............",
        ".tttttttttt.",
        ".tttttttttt.",
        "............",
    ],
    # Sismo: comprimido cae y la onda recorre el suelo.
    "combo_quake": [
        "............",
        "....cccc....",
        "............",
        ".....##.....",
        "...######...",
        "....####....",
        ".....##.....",
        "............",
        "..a..aa..a..",
        ".aaaaaaaaaa.",
        ".tttttttttt.",
        "............",
    ],
    # Ayuda de Eco: la Q dorada.
    "help": [
        "............",
        "....aaaa....",
        "...a....a...",
        "..a......a..",
        "..a......a..",
        "..a......a..",
        "..a...a..a..",
        "...a...aa...",
        "....aaaaa...",
        ".........aa.",
        "............",
        "............",
    ],
    # Pausa: dos barras.
    "pause": [
        "............",
        "............",
        "...##..##...",
        "...##..##...",
        "...##..##...",
        "...##..##...",
        "...##..##...",
        "...##..##...",
        "...##..##...",
        "...##..##...",
        "............",
        "............",
    ],
}
MIRRORS = {"move_right": "move_left"}
DRAWN = {"restart": hub._pause_reset}
ICONS = ["move_left", "move_right", "jump", "walk", "pulse", "laser", "debug", "dash", "compress",
         "ground_pound", "hide", "combo_ram", "combo_edge", "combo_quake", "help", "pause", "restart"]


def icon(name):
    cv = hub.Canvas(SIZE, SIZE)
    if name in DRAWN:
        DRAWN[name](cv)
    else:
        rows = STAMPS[MIRRORS.get(name, name)]
        assert len(rows) == SIZE and all(len(r) == SIZE for r in rows), name
        if name in MIRRORS:
            rows = [r[::-1] for r in rows]
        cv.stamp(0, 0, rows, CMAP)
    cv.halo(hub.FP)
    return cv.img


def file_name(name):
    return f"ctrl_{name}_00.png"


def outputs():
    return {file_name(n): icon(n) for n in ICONS}


def _lum(c):
    def ch(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def contrast(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def panel_color():
    img = Image.open(PANEL).convert("RGBA")
    return img.getpixel((img.width // 2, img.height // 2))[:3]


def check_icon(name, img, pal, bg):
    errs = []
    if img.size != (SIZE, SIZE):
        return [f"{name}: mide {img.size}, no {SIZE}x{SIZE}"]
    strong = 0
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = img.getpixel((x, y))
            if a not in (0, 255):
                errs.append(f"{name}: alfa {a} en ({x}, {y})")
            if a == 0:
                continue
            if (r, g, b) in RESERVED:
                errs.append(f"{name}: rojo reservado en ({x}, {y})")
            if (r, g, b) not in pal:
                errs.append(f"{name}: color #{r:02x}{g:02x}{b:02x} fuera de hub.gpl en ({x}, {y})")
            if contrast((r, g, b), bg) >= MIN_CONTRAST:
                strong += 1
    if strong < MIN_STRONG_PX:
        errs.append(f"{name}: solo {strong} px con contraste >= {MIN_CONTRAST} frente al panel")
    return errs


def check():
    errs = []
    pal = {c[:3] for c in hub.PAL.values()}
    bg = panel_color()
    expected = outputs()
    present = sorted(f for f in os.listdir(OUT_DIR) if f.endswith(".png")) if os.path.isdir(OUT_DIR) else []
    for k in sorted(set(expected) - set(present)):
        errs.append(f"falta {k} (regenera con python3 -I tools/gen_control_icons.py)")
    for k in sorted(set(present) - set(expected)):
        errs.append(f"{k}: no lo produce el generador")
    for k in sorted(set(present) & set(expected)):
        cur = Image.open(os.path.join(OUT_DIR, k)).convert("RGBA")
        errs += check_icon(k, cur, pal, bg)
        if cur.tobytes() != expected[k].convert("RGBA").tobytes():
            errs.append(f"{k}: distinto de lo que genera (regenera)")
    with open(SETTINGS, encoding="utf-8") as fh:
        rows = json.load(fh)["controls"].get("menu_rows", [])
    if not rows:
        errs.append("data/settings.json: controls.menu_rows vacio")
    for row in rows:
        path = str(row.get("icon", ""))
        if not path.startswith(RES_DIR) or path[len(RES_DIR):] not in expected:
            errs.append(f"fila {row.get('id')}: icono {path!r} no lo genera este script")
    print("\n".join(errs) if errs else f"gen_control_icons --check: OK ({len(expected)} iconos, fondo del panel "
          f"#{bg[0]:02x}{bg[1]:02x}{bg[2]:02x})")
    return 1 if errs else 0


def preview(path):
    imgs = outputs()
    sheet = Image.new("RGBA", (len(imgs) * (SIZE + 2) * 4, (SIZE + 2) * 4), panel_color() + (255,))
    for i, k in enumerate(sorted(imgs)):
        sheet.alpha_composite(imgs[k].resize((SIZE * 4, SIZE * 4), Image.NEAREST), (i * (SIZE + 2) * 4 + 4, 4))
    sheet.save(path)


def main(argv):
    if "--check" in argv:
        return check()
    if "--preview" in argv:
        preview(argv[argv.index("--preview") + 1])
        return 0
    os.makedirs(OUT_DIR, exist_ok=True)
    for k, img in outputs().items():
        img.save(os.path.join(OUT_DIR, k))
    print(f"gen_control_icons: {len(ICONS)} iconos en {os.path.relpath(OUT_DIR, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
