#!/usr/bin/env python3
"""Genera el arte de Eco como companero (docs/propuesta-asistentes-y-vidas.md §2.1
y §9; paso 4 de §10). Estilo circuito limpio, coherente con
assets/sprites/ui/eco_icon.png (docs/04-personajes.md §12.1: esfera de luz
blanca y azul con un arco de pixeles que hace de sonrisa).

Lienzo 32x32 por cuadro, esfera de unos 21 px centrada (16, 16). La cara (la
sonrisa) mira a la derecha: el codigo voltea el sprite con la direccion de
Isak. La oscilacion y el seguimiento los hace el codigo (EcoCompanion,
scripts/levels/eco_companion.gd), no los cuadros.

- idle (4 cuadros, bucle): orbita de tres arcos partidos con nodos de 2x2 (como
  el vortice) que gira 30 grados por cuadro (un tercio de vuelta = bucle sin
  salto); en el cuadro 3 la sonrisa «parpadea» (se queda en un arco corto).
- talk (3, bucle): la sonrisa se abre y se cierra y salen ondas de eco por el
  lado de la cara (sin orbita).
- notice (2, sin bucle): reaccion (habla o sale una Q): halo de 1 px, destello
  en cruz y sonrisa abierta.
- appear (4, sin bucle): chispa en cruz -> esfera pequena -> mediana con halo ->
  completa con halo (destello). disappear es la misma secuencia al reves (mismos
  PNG, solo en el SpriteFrames).
- Variante atenuada del hub (sin cobertura, propuesta §12 pregunta 7): las
  mismas animaciones con sufijo _dim, con la paleta del hub (assets/palettes/
  hub.gpl) en grises apagados y una orbita rota (dos arcos de tres).

Colores: normal solo de assets/palettes/mundo1.gpl (noche_profunda, cielo,
resplandor, borde_luz, banner_blanco; sin rojos, carmin ni ambar) y _dim solo de
hub.gpl (fondo_profundo, panel, gris_apagado, gris_foto, texto_tenue,
texto_claro). Fondo transparente, alfa 0 o 255. Salida determinista. Tambien
escribe assets/sprites/eco_companion_frames.tres (un SpriteFrames con una
animacion por estado y sus fps).

Uso (desde la raiz del repo):
  python3 -I tools/gen_eco_companion.py [--dry-run] [--preview <png> [--scale N]]
--dry-run no escribe nada; --preview guarda una hoja de contacto ampliada (x8
por defecto) sobre el fondo del Mundo 1 y del hub. Validador:
tools/validate_eco_companion.py. Pillow puede estar en el site de usuario: se
anade a sys.path a mano para que funcione tambien con python3 -I.
"""
import math
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
from gen_energy_objects import Canvas, load_gpl  # noqa: E402
from gen_warp_objects import sprite_frames_tres  # noqa: E402

REPO = os.path.dirname(TOOLS)
OUT_DIR = "eco/companion"
FRAMES_TRES = "assets/sprites/eco_companion_frames.tres"
SIZE = 32
CX = CY = 16.0
RADIUS = 10.5

M1 = load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"))
HUB = load_gpl(os.path.join(REPO, "assets/palettes/hub.gpl"))

# Papeles de color -> color de la paleta (normal: Mundo 1; dim: hub, apagado).
ROLES = {
    "normal": {
        "outline": M1["noche_profunda"],
        "rim": M1["resplandor"],
        "shade": M1["borde_luz"],
        "core": M1["banner_blanco"],
        "smile": M1["cielo"],
        "orbit": M1["resplandor"],
        "node": M1["borde_luz"],
        "spark_core": M1["banner_blanco"],
        "spark_arm": M1["borde_luz"],
        "wave_near": M1["borde_luz"],
        "wave_far": M1["resplandor"],
        "halo": M1["borde_luz"],
        "halo_soft": M1["resplandor"],
    },
    "dim": {
        "outline": HUB["fondo_profundo"],
        "rim": HUB["gris_apagado"],
        "shade": HUB["gris_foto"],
        "core": HUB["texto_tenue"],
        "smile": HUB["panel"],
        "orbit": HUB["gris_apagado"],
        "node": HUB["gris_foto"],
        "spark_core": HUB["texto_claro"],
        "spark_arm": HUB["gris_foto"],
        "wave_near": HUB["gris_foto"],
        "wave_far": HUB["gris_apagado"],
        "halo": HUB["gris_foto"],
        "halo_soft": HUB["gris_apagado"],
    },
}

# Orbita: radio, arcos, apertura de cada arco (grados) y giro por cuadro. Con
# tres arcos el dibujo se repite cada 120 grados: 4 cuadros x 30 = bucle limpio.
ORBIT_R = 14.0
ORBIT_ARCS = 3
ORBIT_SPAN = 55.0
ORBIT_STEP = 30.0
ORBIT_START = -20.0

# Sonrisas (centradas en la cara: 2 px hacia la derecha y 2 hacia abajo del centro).
FACE_DX, FACE_DY = 2, 2
SMILES = {
    # Arco de la sonrisa (como eco_icon.png, un poco mas ancho).
    "smile": [
        "#........#",
        ".#......#.",
        "..######..",
    ],
    # «Parpadeo» de la sonrisa: arco corto.
    "blink": [
        "..........",
        "..#....#..",
        "...####...",
    ],
    # Boca abierta (habla, reaccion): «D» rellena.
    "open": [
        ".########.",
        ".########.",
        "..######..",
        "...####...",
    ],
    "open_small": [
        "..........",
        "..######..",
        "...####...",
    ],
}

# (nombre, cuadros, fps, bucle). disappear reutiliza appear al reves.
ANIMS = [
    ("idle", 4, 6.0, True),
    ("talk", 3, 10.0, True),
    ("notice", 2, 8.0, False),
    ("appear", 4, 12.0, False),
]
DISAPPEAR = ("disappear", "appear", 12.0, False)
VARIANTS = ["normal", "dim"]


def _d(x, y):
    return math.hypot(x + 0.5 - CX, y + 0.5 - CY)


def sphere(cv, col, radius=RADIUS, face=None):
    """Esfera: contorno de 1 px, borde, nucleo blanco con sombra abajo a la derecha."""
    if radius < 1.0:
        return
    for y in range(SIZE):
        for x in range(SIZE):
            d = _d(x, y)
            if d < radius - 1.6:
                # Sombra: media luna abajo a la derecha (circulo desplazado arriba/izq.).
                lit = math.hypot(x + 0.5 - (CX - radius * 0.22), y + 0.5 - (CY - radius * 0.22))
                cv.p(x, y, col["shade"] if lit > radius - 2.4 else col["core"])
            elif d < radius:
                cv.p(x, y, col["rim"])
            elif d < radius + 1.0:
                cv.p(x, y, col["outline"])
    if face is not None and radius >= 8.0:
        rows = SMILES[face]
        ox = int(CX) + FACE_DX - len(rows[0]) // 2
        oy = int(CY) + FACE_DY - 1
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == "#":
                    cv.p(ox + i, oy + j, col["smile"])
        # Brillo de la esfera: arriba a la izquierda (2 px, nucleo).
        cv.p(int(CX) - 5, int(CY) - 6, col["core"])


def halo(cv, color, radius):
    """Anillo de 1 px por fuera del contorno de la esfera."""
    for y in range(SIZE):
        for x in range(SIZE):
            d = _d(x, y)
            if radius + 1.0 <= d < radius + 2.0 and cv.get(x, y)[3] == 0:
                cv.p(x, y, color)


def orbit(cv, col, angle, arcs_drawn=ORBIT_ARCS):
    """Arcos partidos de 1 px con nodos de 2x2 en sus extremos (circuito)."""
    step = 360.0 / ORBIT_ARCS
    for y in range(SIZE):
        for x in range(SIZE):
            d = _d(x, y)
            if not (ORBIT_R - 0.5 <= d < ORBIT_R + 0.5) or cv.get(x, y)[3] != 0:
                continue
            theta = math.degrees(math.atan2(y + 0.5 - CY, x + 0.5 - CX))
            rel = (theta - angle) % 360.0
            index, inside = int(rel // step), rel % step
            if index < arcs_drawn and inside <= ORBIT_SPAN:
                cv.p(x, y, col["orbit"])
    for i in range(arcs_drawn):
        a = math.radians(angle + i * step + ORBIT_SPAN)
        nx = int(round(CX + ORBIT_R * math.cos(a) - 1))
        ny = int(round(CY + ORBIT_R * math.sin(a) - 1))
        cv.rect(nx, ny, nx + 1, ny + 1, col["node"])


def spark(cv, col, x, y, arm):
    """Destello en cruz: centro de 1 px y brazos de `arm` px."""
    cv.p(x, y, col["spark_core"])
    for k in range(1, arm + 1):
        c = col["spark_core"] if k == 1 and arm > 2 else col["spark_arm"]
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            cv.p(x + dx, y + dy, c)


def waves(cv, col, frame):
    """Ondas de eco por el lado de la cara (derecha), alternando por cuadro."""
    rings = [(RADIUS + 2.5, col["wave_near"]), (RADIUS + 4.5, col["wave_far"])]
    span = [30.0, 42.0]
    for k, (r, color) in enumerate(rings):
        if frame == 2 and k == 1:
            continue  # cuadro 2: solo la onda cercana (la lejana se ha ido)
        if frame == 0 and k == 1:
            r -= 1.0
        for y in range(SIZE):
            for x in range(SIZE):
                d = _d(x, y)
                if r - 0.5 <= d < r + 0.5 and cv.get(x, y)[3] == 0:
                    theta = math.degrees(math.atan2(y + 0.5 - CY, x + 0.5 - CX))
                    if abs(theta) <= span[k]:
                        cv.p(x, y, color)


def frame(anim, f, variant):
    col = ROLES[variant]
    cv = Canvas(SIZE, SIZE)
    if anim == "idle":
        sphere(cv, col, face="blink" if f == 3 else "smile")
        arcs = ORBIT_ARCS if variant == "normal" else ORBIT_ARCS - 1
        orbit(cv, col, ORBIT_START + f * ORBIT_STEP, arcs)
    elif anim == "talk":
        sphere(cv, col, face=["open", "open_small", "smile"][f])
        waves(cv, col, f)
    elif anim == "notice":
        sphere(cv, col, face="open")
        halo(cv, col["halo"] if f == 0 else col["halo_soft"], RADIUS)
        if f == 0:
            spark(cv, col, 26, 5, 2)
        else:
            cv.p(26, 5, col["spark_arm"])
    elif anim == "appear":
        if f == 0:
            spark(cv, col, int(CX), int(CY), 3)
        elif f == 1:
            sphere(cv, col, radius=4.0)
            spark(cv, col, int(CX), int(CY) - 7, 2)
        elif f == 2:
            sphere(cv, col, radius=7.5)
            halo(cv, col["halo_soft"], 7.5)
        else:
            sphere(cv, col, face="smile")
            halo(cv, col["halo"], RADIUS)
    return cv.img


def anim_name(anim, variant):
    return anim if variant == "normal" else anim + "_dim"


def outputs():
    """{ruta relativa a assets/sprites: imagen}."""
    out = {}
    for variant in VARIANTS:
        for anim, count, _fps, _loop in ANIMS:
            for f in range(count):
                out["%s/eco_%s_%02d.png" % (OUT_DIR, anim_name(anim, variant), f)] = frame(anim, f, variant)
    return out


def animations():
    """[(nombre, [rutas res://], fps, bucle)] para el SpriteFrames."""
    anims = []
    for variant in VARIANTS:
        for anim, count, fps, loop in ANIMS:
            name = anim_name(anim, variant)
            paths = ["res://assets/sprites/%s/eco_%s_%02d.png" % (OUT_DIR, name, i) for i in range(count)]
            anims.append((name, paths, fps, loop))
        target, source, fps, loop = DISAPPEAR
        src = anim_name(source, variant)
        count = [c for a, c, _f, _l in ANIMS if a == source][0]
        paths = ["res://assets/sprites/%s/eco_%s_%02d.png" % (OUT_DIR, src, i) for i in reversed(range(count))]
        anims.append((anim_name(target, variant), paths, fps, loop))
    return anims


def preview(path, scale=8):
    """Hoja de contacto: una fila por animacion, sobre el fondo del mundo (normal)
    o del hub (dim), ampliada x`scale`."""
    rows = [(name, paths) for name, paths, _fps, _loop in animations()]
    gen = outputs()
    pad = 4
    cols = max(len(p) for _, p in rows)
    cell = (SIZE + pad) * scale
    sheet = Image.new("RGBA", (cols * cell + pad * scale, len(rows) * cell + pad * scale), (0, 0, 0, 255))
    for r, (name, paths) in enumerate(rows):
        bg = M1["cielo"] if not name.endswith("_dim") else HUB["base"]
        for c, p in enumerate(paths):
            rel = p.replace("res://assets/sprites/", "")
            im = gen[rel]
            x0, y0 = pad * scale + c * cell, pad * scale + r * cell
            tile = Image.new("RGBA", (SIZE * scale, SIZE * scale), bg)
            tile.alpha_composite(im.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            sheet.paste(tile, (x0, y0))
    sheet.save(path)


def main(argv):
    imgs = outputs()
    dest = os.path.join(REPO, "assets/sprites")
    if "--dry-run" not in argv:
        for k, im in imgs.items():
            p = os.path.join(dest, k)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            im.save(p)
        with open(os.path.join(REPO, FRAMES_TRES), "w", encoding="utf-8") as fh:
            fh.write(sprite_frames_tres(animations()))
    if "--preview" in argv:
        preview(argv[argv.index("--preview") + 1],
                int(argv[argv.index("--scale") + 1]) if "--scale" in argv else 8)
    print(f"{len(imgs)} PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
