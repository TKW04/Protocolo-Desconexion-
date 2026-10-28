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
- Variante ambar (2026-10-16, Eco lleva la Q): Eco «brilla» en dorado mientras
  ofrece una ayuda (vuela junto al objeto con la Q encima) y mientras la
  explica. idle, talk y notice con sufijo _amber: esfera dorada (ambar con
  sombra y borde en ambar_sombra, brillo blanco), orbita ambar y un halo que
  late (pulso suave de brillo: sin halo -> ambar_sombra -> ambar ->
  ambar_sombra en los 4 cuadros del idle). glow_in (3 cuadros, sin bucle):
  normal con chispas ambar -> mezcla en damero (normal/ambar) -> ambar con halo
  fuerte; glow_out es la misma secuencia al reves (mismos PNG, solo en el
  SpriteFrames).

- Marco dorado del Mundo 3 (2026-10-26, paso 9 de docs/propuesta-mundo-3.md §6.3; docs/04-personajes.md §12.1):
  eco_frame_w3_00.png, un anillo de 1 px en el dorado apagado del Mundo 3 (assets/palettes/mundo3.gpl) justo por
  fuera del contorno de la esfera, con dos pixeles de brillo (dorado_luz) arriba a la izquierda. No es una
  animacion: EcoCompanion lo superpone (world_frames de data/eco_companion.json) en los niveles de ese mundo
  mientras la esfera esta entera (idle, talk, notice y sus _amber).

- Eco del Mundo 4 (2026-10-28, paso 11 de docs/propuesta-mundo-4.md §6.3; docs/04-personajes.md §12.1: «tres
  puntos de escribiendo…, sin cuerpo»): eco_w4_<anim>[_amber]_NN.png, tres puntos en fila (sin esfera, sin
  burbuja) en el cian de la ropa de Isak (nucleo #29defa, borde #36c0d4, contorno noche; desde el 2026-10-28,
  antes blanco y azul luz como la esfera, que se confundia con el «escribiendo…» crema) y la misma variante
  ambar de la Q. idle: los puntos laten de uno en uno (el 4.º cuadro, quietos);
  talk: botan por turnos; notice: los tres grandes con destello; appear: chispa y los puntos de uno en uno;
  glow_in: como el de la esfera. Sin variante _dim (el hub sigue con la esfera atenuada). Escribe ademas
  assets/sprites/eco_companion_w4_frames.tres con las mismas animaciones (las _dim apuntan a las de la
  esfera); EcoCompanion lo carga en los niveles del Mundo 4 (world_sprite_frames de data/eco_companion.json).
  Se distinguen del «escribiendo…» del nivel: aquellos son crema dentro de una burbuja con contorno.

Colores: normal solo de assets/palettes/mundo1.gpl (noche_profunda, cielo,
resplandor, borde_luz, banner_blanco; sin rojos, carmin ni ambar), _amber y
glow_in de mundo1.gpl con ambar y ambar_sombra (los dorados de los puntos de
atencion; sin rojos ni carmin) y _dim solo de hub.gpl (fondo_profundo, panel,
gris_apagado, gris_foto, texto_tenue, texto_claro). Fondo transparente, alfa 0 o 255. Salida determinista. Tambien
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
M3_GPL = "assets/palettes/mundo3.gpl"
FRAME_W3 = "%s/eco_frame_w3_00.png" % OUT_DIR
FRAMES_TRES_W4 = "assets/sprites/eco_companion_w4_frames.tres"
# Tres puntos del Mundo 4: centros (x) a la altura CY, radio normal y radio del que late.
W4_DOTS_X = (8.0, 16.0, 24.0)
W4_R, W4_R_BIG = 2.6, 3.6

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
    # Dorado (ofrece o explica una ayuda): mismos papeles con el ambar del Mundo 1.
    "amber": {
        "outline": M1["noche_profunda"],
        "rim": M1["ambar_sombra"],
        "shade": M1["ambar_sombra"],
        "core": M1["ambar"],
        "smile": M1["cielo"],
        "orbit": M1["ambar"],
        "node": M1["banner_blanco"],
        "spark_core": M1["banner_blanco"],
        "spark_arm": M1["ambar"],
        "wave_near": M1["ambar"],
        "wave_far": M1["ambar_sombra"],
        "halo": M1["ambar"],
        "halo_soft": M1["ambar_sombra"],
        "gleam": M1["banner_blanco"],
    },
}

# Tres puntos del Mundo 4 (2026-10-28, arreglo de las capturas del paso 22): el cian de la ropa de Isak (el de
# ECO_DOTS de tools/palette_mundo4_provisional.py, regla 3 de §6.1), no el blanco de la esfera: el «escribiendo…»
# del nivel es crema y se confundian. Nucleo #29defa, borde #36c0d4, contorno noche y destellos blancos.
W4_CYAN = (0x29, 0xde, 0xfa, 255)
W4_CYAN_SHADE = (0x36, 0xc0, 0xd4, 255)
ROLES["w4"] = {
    "outline": M1["noche_profunda"],
    "rim": W4_CYAN_SHADE,
    "core": W4_CYAN,
    "spark_core": M1["banner_blanco"],
    "spark_arm": W4_CYAN,
    "halo": W4_CYAN_SHADE,
    "halo_soft": W4_CYAN_SHADE,
}
W4_COLORS = {c[:3] for c in ROLES["w4"].values()}

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

# (nombre, cuadros, fps, bucle, variantes). disappear reutiliza appear al
# reves y glow_out, glow_in al reves (REVERSED).
ANIMS = [
    ("idle", 4, 6.0, True, ("normal", "dim", "amber")),
    ("talk", 3, 10.0, True, ("normal", "dim", "amber")),
    ("notice", 2, 8.0, False, ("normal", "dim", "amber")),
    ("appear", 4, 12.0, False, ("normal", "dim")),
    ("glow_in", 3, 12.0, False, ("normal",)),
]
REVERSED = [("disappear", "appear", 12.0, False), ("glow_out", "glow_in", 12.0, False)]
VARIANTS = ["normal", "dim", "amber"]
SUFFIX = {"normal": "", "dim": "_dim", "amber": "_amber"}
# Halo del idle ambar por cuadro (pulso suave de brillo): None = sin halo.
AMBER_PULSE = [None, "halo_soft", "halo", "halo_soft"]


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
        # Brillo de la esfera: arriba a la izquierda (2 px, nucleo; en la
        # variante ambar, un destello blanco de 2x2 con cola).
        if "gleam" in col:
            cv.rect(int(CX) - 6, int(CY) - 6, int(CX) - 5, int(CY) - 5, col["gleam"])
            cv.p(int(CX) - 4, int(CY) - 7, col["gleam"])
        else:
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


def blend(a, b, keep_b):
    """Mezcla en damero: los pixeles opacos de `b` donde keep_b(x, y), los de `a`
    en el resto (mismo lienzo; transparente donde ninguno es opaco)."""
    cv = Canvas(SIZE, SIZE)
    pa, pb = a.load(), b.load()
    for y in range(SIZE):
        for x in range(SIZE):
            first, second = (pb, pa) if keep_b(x, y) else (pa, pb)
            c = first[x, y] if first[x, y][3] == 255 else second[x, y]
            if c[3] == 255:
                cv.p(x, y, c)
    return cv.img


def frame(anim, f, variant):
    col = ROLES[variant]
    cv = Canvas(SIZE, SIZE)
    if anim == "glow_in":
        normal = frame("idle", 0, "normal")
        amber = frame("idle", 2, "amber")
        if f == 0:
            # Normal con cuatro chispas ambar en diagonal (empieza a brillar).
            cv = Canvas(SIZE, SIZE)
            cv.img.alpha_composite(normal)
            cv.px = cv.img.load()
            for x, y in ((5, 5), (26, 5), (5, 26), (26, 26)):
                spark(cv, ROLES["amber"], x, y, 1)
            return cv.img
        if f == 1:
            return blend(normal, amber, lambda x, y: (x + y) % 2 == 0)
        cv = Canvas(SIZE, SIZE)
        cv.img.alpha_composite(amber)
        cv.px = cv.img.load()
        halo(cv, ROLES["amber"]["halo"], RADIUS + 1.0)
        return cv.img
    if anim == "idle":
        sphere(cv, col, face="blink" if f == 3 else "smile")
        arcs = ORBIT_ARCS - 1 if variant == "dim" else ORBIT_ARCS
        if variant == "amber" and AMBER_PULSE[f] is not None:
            halo(cv, col[AMBER_PULSE[f]], RADIUS)
        orbit(cv, col, ORBIT_START + f * ORBIT_STEP, arcs)
    elif anim == "talk":
        sphere(cv, col, face=["open", "open_small", "smile"][f])
        if variant == "amber":
            halo(cv, col["halo_soft"], RADIUS)
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


def frame_w3():
    """Marco dorado de 1 px del Mundo 3 (anillo por fuera del contorno de la esfera completa)."""
    m3 = load_gpl(os.path.join(REPO, M3_GPL))
    cv = Canvas(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            if RADIUS + 1.0 <= _d(x, y) < RADIUS + 2.0:
                cv.p(x, y, m3["dorado"])
    for x, y in ((8, 6), (6, 8)):
        cv.p(x, y, m3["dorado_luz"])
    return cv.img


def _dot(cv, col, cx, cy, r):
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d < r - 1.0:
                cv.p(x, y, col["core"])
            elif d < r:
                cv.p(x, y, col["rim"])
            elif d < r + 1.0 and cv.get(x, y)[3] == 0:
                cv.p(x, y, col["outline"])


def _dot_halo(cv, color, cx, cy, r):
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r + 1.0 <= d < r + 2.0 and cv.get(x, y)[3] == 0:
                cv.p(x, y, color)


def frame_w4(anim, f, variant):
    """Eco del Mundo 4: tres puntos en fila (ver el encabezado)."""
    col = ROLES["w4" if variant == "normal" else variant]
    cv = Canvas(SIZE, SIZE)
    if anim == "glow_in":
        normal = frame_w4("idle", 0, "normal")
        amber = frame_w4("idle", 2, "amber")
        if f == 0:
            cv.img.alpha_composite(normal)
            cv.px = cv.img.load()
            for x, y in ((4, 9), (27, 9), (4, 23), (27, 23)):
                spark(cv, ROLES["amber"], x, y, 1)
            return cv.img
        if f == 1:
            return blend(normal, amber, lambda x, y: (x + y) % 2 == 0)
        cv.img.alpha_composite(amber)
        cv.px = cv.img.load()
        for cx in W4_DOTS_X:
            _dot_halo(cv, ROLES["amber"]["halo"], cx, CY, W4_R)
        return cv.img
    dots = []  # (cx, cy, r)
    if anim == "idle":
        for i, cx in enumerate(W4_DOTS_X):
            big = f < 3 and i == f
            dots.append((cx, CY - (1 if big else 0), W4_R_BIG if big else W4_R))
    elif anim == "talk":
        for i, cx in enumerate(W4_DOTS_X):
            dots.append((cx, CY - (2 if i == f else 0), W4_R))
    elif anim == "notice":
        for cx in W4_DOTS_X:
            dots.append((cx, CY, W4_R_BIG if f == 0 else W4_R + 0.5))
    elif anim == "appear":
        if f == 0:
            spark(cv, col, int(CX), int(CY), 3)
            return cv.img
        for cx in W4_DOTS_X[:f]:
            dots.append((cx, CY, W4_R))
    for cx, cy, r in dots:
        _dot(cv, col, cx, cy, r)
    if anim == "idle" and variant == "amber" and AMBER_PULSE[f] is not None:
        for cx, cy, r in dots:
            _dot_halo(cv, col[AMBER_PULSE[f]], cx, cy, r)
    elif anim == "talk" and variant == "amber":
        for cx, cy, r in dots:
            _dot_halo(cv, col["halo_soft"], cx, cy, r)
    elif anim == "notice":
        for cx, cy, r in dots:
            _dot_halo(cv, col["halo"] if f == 0 else col["halo_soft"], cx, cy, r)
        if f == 0:
            spark(cv, col, 27, 7, 2)
        else:
            cv.p(27, 7, col["spark_arm"])
    return cv.img


# Icono del cuadro de texto en el Mundo 4 (16x16; world_icons de data/eco_text_box.json): los tres puntos cian en
# lugar de la esfera de assets/sprites/ui/eco_icon.png. Lo escribe main() aparte de outputs() (no es un cuadro
# de 32x32 del companero).
ICON_W4 = "assets/sprites/eco/eco_icon_w4.png"
ICON_W4_SIZE = 16


def icon_w4():
    col = ROLES["w4"]
    cv = Canvas(ICON_W4_SIZE, ICON_W4_SIZE)
    for cx in (3.5, 8.0, 12.5):
        for y in range(ICON_W4_SIZE):
            for x in range(ICON_W4_SIZE):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - 8.0)
                if d < 1.3:
                    cv.p(x, y, col["core"])
                elif d < 2.2:
                    cv.p(x, y, col["rim"])
                elif d < 3.0 and cv.get(x, y)[3] == 0:
                    cv.p(x, y, col["outline"])
    return cv.img


def w4_name(anim, variant):
    return "%s/eco_w4_%s_%%02d.png" % (OUT_DIR, anim_name(anim, variant))


def anim_name(anim, variant):
    return anim + SUFFIX[variant]


def outputs():
    """{ruta relativa a assets/sprites: imagen}."""
    out = {}
    for variant in VARIANTS:
        for anim, count, _fps, _loop, variants in ANIMS:
            if variant not in variants:
                continue
            for f in range(count):
                out["%s/eco_%s_%02d.png" % (OUT_DIR, anim_name(anim, variant), f)] = frame(anim, f, variant)
    out[FRAME_W3] = frame_w3()
    for variant in ("normal", "amber"):
        for anim, count, _fps, _loop, variants in ANIMS:
            if variant not in variants:
                continue
            for f in range(count):
                out[w4_name(anim, variant) % f] = frame_w4(anim, f, variant)
    return out


def animations():
    """[(nombre, [rutas res://], fps, bucle)] para el SpriteFrames."""
    anims = []
    for variant in VARIANTS:
        for anim, count, fps, loop, variants in ANIMS:
            if variant not in variants:
                continue
            name = anim_name(anim, variant)
            paths = ["res://assets/sprites/%s/eco_%s_%02d.png" % (OUT_DIR, name, i) for i in range(count)]
            anims.append((name, paths, fps, loop))
        for target, source, fps, loop in REVERSED:
            entry = [a for a in ANIMS if a[0] == source][0]
            if variant not in entry[4]:
                continue
            src = anim_name(source, variant)
            paths = ["res://assets/sprites/%s/eco_%s_%02d.png" % (OUT_DIR, src, i) for i in reversed(range(entry[1]))]
            anims.append((anim_name(target, variant), paths, fps, loop))
    return anims


def animations_w4():
    """SpriteFrames del Eco del Mundo 4: las mismas animaciones con los tres puntos (las _dim, las de la esfera)."""
    anims = []
    for name, paths, fps, loop in animations():
        if name.endswith("_dim"):
            anims.append((name, paths, fps, loop))
            continue
        anims.append((name, [p.replace("/eco_", "/eco_w4_", 1) for p in paths], fps, loop))
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
        with open(os.path.join(REPO, FRAMES_TRES_W4), "w", encoding="utf-8") as fh:
            fh.write(sprite_frames_tres(animations_w4()))
        os.makedirs(os.path.dirname(os.path.join(REPO, ICON_W4)), exist_ok=True)
        icon_w4().save(os.path.join(REPO, ICON_W4))
    if "--preview" in argv:
        preview(argv[argv.index("--preview") + 1],
                int(argv[argv.index("--scale") + 1]) if "--scale" in argv else 8)
    print(f"{len(imgs)} PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
