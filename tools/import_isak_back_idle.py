#!/usr/bin/env python3
"""Importa la pose estatica de Isak de espaldas (isak_back_idle_00.png).

La pose sale de AutoSprite (generate_pose sobre el personaje "Isak", pose
"Back Idle", 1024x1024 con fondo de damero opaco). Este script la pasa por
tools/import_sheet.py como una hoja de 1x1: quita el fondo, umbral de alfa,
escala nearest a 96 px visibles y pies en la ultima fila de un canvas 128x128,
igual que los cuadros de perfil.

Uso (python3 -I, con Pillow en el site de usuario):
    python3 -I tools/import_isak_back_idle.py POSE.png [--dry-run]
        [--preview VISTA.png] [--compare COMPARA.png]
--compare guarda una vista x8 del cuadro de espaldas junto a isak_idle_00.

Tras importar se aplica una limpieza fija (CLEANUP): el borde de la IA deja
unos pixeles grises claros sueltos (arriba a la derecha del pelo y junto a la
mano derecha). Los aislados se quitan; los que hacen de contorno del pelo pasan
al contorno oscuro. Es idempotente; para aplicarla sola al PNG ya importado:
    python3 -I tools/import_isak_back_idle.py --clean-only
"""

import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)

import import_sheet  # noqa: E402
from PIL import Image  # noqa: E402

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "isak")
BACK_PATH = os.path.join(OUT_DIR, "isak_back_idle_00.png")
## Contorno oscuro del pelo (muestreado en el propio cuadro, p. ej. (80, 43)).
OUTLINE = (16, 9, 8, 255)
## Limpieza del borde: (x, y) -> color nuevo (None = transparente).
CLEANUP = {
    # Borde superior derecho del pelo: tira gris claro -> contorno oscuro.
    **{(x, 35): OUTLINE for x in range(69, 78)},
    (77, 40): OUTLINE,
    (80, 46): OUTLINE,
    # Pixel gris suelto fuera del pelo.
    (81, 43): None,
    # Columna gris suelta junto a la mano derecha y pixel bajo la mano.
    (83, 86): None,
    (83, 87): None,
    (83, 88): None,
    (84, 96): None,
}


def clean(path=BACK_PATH):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    changed = 0
    for (x, y), color in CLEANUP.items():
        new = color if color is not None else (0, 0, 0, 0)
        if px[x, y] != new:
            px[x, y] = new
            changed += 1
    if changed:
        im.save(path)
    print("limpieza: %d pixeles cambiados en %s" % (changed, path))


def compare(path, zoom=8):
    a = Image.open(os.path.join(OUT_DIR, "isak_idle_00.png")).convert("RGBA")
    b = Image.open(os.path.join(OUT_DIR, "isak_back_idle_00.png")).convert("RGBA")
    w, h = a.size
    out = Image.new("RGBA", (w * 2 * zoom, h * zoom), (60, 60, 70, 255))
    for i, im in enumerate((a, b)):
        big = im.resize((w * zoom, h * zoom), Image.NEAREST)
        out.alpha_composite(big, (i * w * zoom, 0))
    out.save(path)
    print("comparacion:", path)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv == ["--clean-only"]:
        clean()
        return 0
    cmp_path = None
    if "--compare" in argv:
        i = argv.index("--compare")
        cmp_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    rc = import_sheet.main([argv[0], "--anim", "back_idle", "--cols", "1",
                            "--rows", "1", "--out", OUT_DIR] + argv[1:])
    if rc in (0, None) and "--dry-run" not in argv:
        clean()
        if cmp_path:
            compare(cmp_path)
    return rc or 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
