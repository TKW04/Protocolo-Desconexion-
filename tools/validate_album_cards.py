#!/usr/bin/env python3
"""Valida las fichas del album de Notas (tools/gen_album_cards.py).

Comprueba en assets/sprites/ui/album/: estan todos los PNG que produce el
generador (y ninguno mas), 64x64, alfa 0 o 255, con pixeles opacos, al dia con el
generador (mismos pixeles); las fichas solo usan colores de su sprite de origen
y las siluetas solo `sombra` y `base` de assets/palettes/hub.gpl; cada tipo de
data/help.json tiene ficha.

Uso (desde la raiz del repo): python3 -I tools/validate_album_cards.py
Sale con 1 si hay errores.
"""
import glob
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_album_cards as gen  # noqa: E402

DIR = os.path.join(REPO, gen.OUT)


def colors(img):
    return {c for c in img.getdata() if c[3] == 255}


def main():
    errs = []
    expected = gen.outputs()
    files = {os.path.basename(f) for f in glob.glob(os.path.join(DIR, "*.png"))}
    for k in sorted(set(expected) - files):
        errs.append(f"falta {k} (regenera con python3 -I tools/gen_album_cards.py)")
    for k in sorted(files - set(expected)):
        errs.append(f"{k}: no lo produce el generador")
    for t in gen.help_types():
        if t not in gen.SOURCES:
            errs.append(f"{t}: tipo de data/help.json sin ficha en gen_album_cards.SOURCES")
    for k in sorted(files & set(expected)):
        img = Image.open(os.path.join(DIR, k)).convert("RGBA")
        if img.size != (gen.MAX, gen.MAX):
            errs.append(f"{k}: tamano {img.size}")
            continue
        if any(0 < a < 255 for a in img.getchannel("A").getdata()):
            errs.append(f"{k}: alfa distinto de 0 o 255")
        if not colors(img):
            errs.append(f"{k}: vacio")
        if img.tobytes() != expected[k].tobytes():
            errs.append(f"{k}: distinto de lo que genera tools/gen_album_cards.py (regenera)")
        if k.endswith("_silhouette.png"):
            if not colors(img) <= {gen.SHADOW, gen.OUTLINE}:
                errs.append(f"{k}: la silueta usa colores fuera de sombra/base")
        else:
            t = k[len("album_card_"):-len(".png")]
            src = Image.open(os.path.join(REPO, gen.SOURCES[t][0])).convert("RGBA")
            if not colors(img) <= colors(src):
                errs.append(f"{k}: colores que no estan en su sprite de origen")
    print("\n".join(errs) if errs else f"validate_album_cards: OK ({len(files)} PNG)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
