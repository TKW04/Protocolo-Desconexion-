"""Isak en el cuadro de texto (2026-10-29, paso 6 de docs/propuesta-mundo-5.md §4.2.2 y
decision 13 de su §9: Isak habla por primera vez, interlocutor `isak` de
data/eco_text_box.json). Escribe dos PNG de 16x16 en la paleta del Mundo 1
(assets/palettes/mundo1.gpl, la del cuadro de Eco; el cian es debug_cian, el de los
detalles luminosos de la chaqueta de Isak):

  assets/sprites/ui/eco_isak_icon.png    cara de Isak: pelo oscuro, cara en
                                         banner_gris, cuello de la chaqueta gris
                                         oscura (tile_base) con el detalle cian y el
                                         celular encendido en la mano.
  assets/sprites/ui/eco_isak_panel.png   panel del estilo `isak` (nine-patch, margen
                                         3): la chaqueta (tile_base con bisel
                                         tile_luz) y la linea cian del cuello y el
                                         hombro como borde, esquinas cortadas.

PROVISIONAL (por script, hasta el arte final). Uso: python3 -I tools/gen_isak_text_box.py
[--check] (--check: falla si los PNG no estan al dia). Pillow puede estar en el site
de usuario: se anade a sys.path a mano para que funcione tambien con python3 -I.
"""
import os
import site
import sys

sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(REPO, "assets", "palettes", "mundo1.gpl")
OUT = os.path.join(REPO, "assets", "sprites", "ui")
CLEAR = (0, 0, 0, 0)


def load_gpl(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                out[parts[3]] = (int(parts[0]), int(parts[1]), int(parts[2]), 255)
    return out


PAL = load_gpl(GPL)
NP = PAL["noche_profunda"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]
TS = PAL["tile_sombra"]
BG = PAL["banner_gris"]
BW = PAL["banner_blanco"]
CY = PAL["debug_cian"]


def icon():
    img = Image.new("RGBA", (16, 16), CLEAR)
    px = img.load()

    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[x, y] = c

    # Pelo y cara.
    rect(4, 1, 11, 3, NP)
    rect(3, 2, 3, 6, NP)
    rect(4, 4, 11, 9, BG)
    rect(12, 2, 12, 6, NP)
    px[6, 6] = NP
    px[9, 6] = NP
    rect(7, 8, 8, 8, TL)
    # Chaqueta gris oscura con el cuello y el hombro cian.
    rect(2, 11, 13, 15, TB)
    rect(5, 10, 10, 10, TB)
    rect(4, 11, 5, 11, CY)
    rect(10, 11, 11, 11, CY)
    px[2, 12] = CY
    px[13, 12] = CY
    rect(7, 11, 8, 15, TS)
    # Celular encendido en la mano.
    rect(11, 13, 13, 15, NP)
    px[12, 14] = CY
    return img


def panel():
    img = Image.new("RGBA", (16, 16), CLEAR)
    px = img.load()
    for y in range(16):
        for x in range(16):
            edge = x in (0, 15) or y in (0, 15)
            corner = (x in (0, 15)) and (y in (0, 15))
            if corner:
                continue
            px[x, y] = NP if edge else TB
    # Linea cian del cuello y el hombro (borde) y bisel tile_luz.
    for i in range(1, 15):
        px[i, 1] = CY
        px[1, i] = CY
        px[i, 14] = TL
        px[14, i] = TL
    px[1, 1] = BW
    return img


def main(argv):
    check = "--check" in argv
    outputs = {"eco_isak_icon.png": icon(), "eco_isak_panel.png": panel()}
    failed = False
    for name, img in outputs.items():
        path = os.path.join(OUT, name)
        if check:
            if not os.path.exists(path) or list(Image.open(path).convert("RGBA").getdata()) != list(img.getdata()):
                print("gen_isak_text_box: %s no esta al dia" % name)
                failed = True
            continue
        img.save(path)
        print("escrito", os.path.relpath(path, REPO))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
