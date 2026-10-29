"""Paleta PROVISIONAL del Mundo 5 «La Tienda» (paso 0 de docs/propuesta-mundo-5.md §8).

SOLO PARA DESARROLLO: los otros 16 colores los cierra el usuario en el paso 9 (3 variantes con maqueta), como en
los Mundos 1-4. Hasta entonces las piezas por script del Mundo 5 (carteles, cajas, tienda, salas de prueba...) usan
estos colores, que se leen por nombre de data/world5_objects.json (seccion palette).

EL BLANCO DEL DEBUG YA ESTA DECIDIDO (usuario, 2026-10-29, §10.1): opcion A «Blanco puro» #ffffff. Es el de
debug_colors["5"] de data/hud.json y sera el de la quinta pieza del hub (paso 18); --check comprueba que coinciden.

Negro con neones, amarillo chillon de rebajas, magenta y violeta (`07` §15.3). Se reservan los del Mundo 1 que
significan algo en todo el juego: alerta / alerta_sombra (dano) y ambar / ambar_sombra (puntos de atencion).

--check comprueba que el .gpl y la seccion palette estan al dia y las 7 reglas de docs/propuesta-mundo-5.md §6.1:
  1. blanco frente al rojo de dano (alerta / alerta_sombra) y al carmin del punto debil: dE >= 30, tambien con el
     tinte del Debug (assets/shaders/debug_overlay.gdshader + data/debug_mode.json); debug_colors["5"] es el blanco;
  2. el contorno negro de 1 px de lo que el Debug revela contrasta >= 3:1 sobre el amarillo y sobre el blanco del
     tinte (el amarillo tenido por el Debug);
  3. ningun color de la paleta por encima de L* 92 salvo el Debug (el blanco queda reservado al Debug);
  4. sin rojos ni naranjas fuera de los reservados: tono 0-45 o 330-360 saturado, o dE < 30 del rojo de dano, se
     prohibe (el precio tachado va en magenta);
  5. amarillo de los carteles frente al ambar de los puntos: dE >= 30; los puntos llevan contorno oscuro de 1 px
     (AttentionPoint.OUTLINE_WORLDS incluye el 5);
  6. sin verde lima ni cian en los neones: ningun color saturado de tono 70-200 ni a dE < 30 del verde acido del
     Mundo 3 (#a6ff2e);
  7. el cian de Isak y la esfera de Eco (la misma que en los Mundos 1-3: Eco se ve igual en todos los mundos,
     decision del usuario del 2026-10-29) contrastan >= 3:1 sobre el negro (fondo y medio).
Se informan, sin exigir: dE del blanco frente al texto del HUD (#f2f4f8) y frente al cian de Isak.

Genera assets/palettes/mundo5_provisional.gpl y escribe la seccion palette de data/world5_objects.json.
Con --check sale con 1 si algo no esta al dia o una regla falla (imprime las medidas con --verbose).

Uso: python3 -I tools/palette_mundo5_provisional.py [--check] [--verbose]
"""
import colorsys
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo5_provisional.gpl")
OBJECTS = os.path.join(ROOT, "data", "world5_objects.json")
HUD = os.path.join(ROOT, "data", "hud.json")
DEBUG_MODE = os.path.join(ROOT, "data", "debug_mode.json")
ATTENTION_POINT = os.path.join(ROOT, "scripts", "levels", "attention_point.gd")

TITLE = "Mundo 5 La Tienda - PROVISIONAL (solo desarrollo, hex sin cerrar salvo el blanco)"
# (nombre, hex, funcion)
COLORS = [
    ("tienda_noche", "0e0c14", "Negro de referencia de §6.1: contorno de 1 px (lo que revela el Debug, puntos de atencion)"),
    ("negro_fondo", "15121e", "Fondo del centro comercial de madrugada"),
    ("negro_medio", "221c30", "Fondo medio: escaparates en paralaje"),
    ("gris_escaparate", "3a3448", "Suelo de baldosa, paredes de escaparate, estanterias"),
    ("gris_etiqueta", "7a7488", "Bordes, etiquetas apagadas, maniquies"),
    ("crema_cartel", "e8e0c8", "Carteles «blancos» (crema, nunca blanco: L* <= 92)"),
    ("crema_sombra", "aea690", "Sombra y borde de los carteles"),
    ("amarillo_rebajas", "ffe600", "Amarillo chillon de rebajas: carteles de oferta, etiquetas de precio"),
    ("amarillo_sombra", "a89400", "Sombra del amarillo"),
    ("magenta_neon", "ff3df0", "Neon principal y precio tachado (nunca rojo); brillo de la Suscripcion"),
    ("magenta_sombra", "9a1c94", "Sombra del magenta"),
    ("violeta_neon", "9b5cff", "Neon secundario"),
    ("alerta", "ff4a2a", "Rojo de dano (el del Mundo 1, reservado: pinchos y el «Cancelar»)"),
    ("alerta_sombra", "a3221c", "Sombra de lo rojo (reservado)"),
    ("ambar", "ffa000", "Puntos de atencion (el del Mundo 1, reservado)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atencion (reservado)"),
]
## Decidido por el usuario el 2026-10-29 (docs/propuesta-mundo-5.md §10.1, opcion A «Blanco puro»).
DEBUG = ("debug_blanco", "ffffff", "Debug del Mundo 5: blanco puro (DECIDIDO; debug_colors[\"5\"] de data/hud.json)")

## Paso 9: variante elegida (tools/palette_mundo5_variants.py). Sus hex sustituyen a los de arriba; BASE_COLORS
## guarda la provisional (las variantes toman de ella los nombres y las funciones).
BASE_COLORS = list(COLORS)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_mundo5_variants as variants  # noqa: E402

if variants.ACTIVE:
    COLORS = variants.rows(variants.ACTIVE, BASE_COLORS)
    GPL = os.path.join(ROOT, "assets", "palettes", "mundo5.gpl")
    TITLE = "Mundo 5 La Tienda - variante %s (%s)" % (variants.ACTIVE, variants.VARIANTS[variants.ACTIVE]["title"])

## Reservados del Mundo 1 (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}
## Carmin del punto debil (Mundo 1) y su brillo.
CARMIN = ("e0004a", "ff5a8c")
## Cian de la ropa de Isak (hoja importada).
ISAK_CYANS = ("29defa", "36c0d4")
## Esfera de Eco (borde_luz y banner_blanco del Mundo 1, como ECO_CYANS de tools/palette_mundo3_provisional.py):
## Eco se ve igual en todos los mundos (decision del usuario del 2026-10-29; sin la «silueta de luz» de §6.3).
ECO_COLORS = ("9bb0e8", "f2f4f8")
## Texto del HUD (banner_blanco del Mundo 1).
HUD_TEXT = "f2f4f8"
## Verde acido del Debug del Mundo 3 (assets/palettes/mundo3.gpl).
WORLD3_GREEN = "a6ff2e"
OUTLINE_NAME = "tienda_noche"
BACKS = ("negro_fondo", "negro_medio")

# Umbrales de §6.1.
MIN_DE_WHITE_RED = 30.0
MIN_CONTRAST = 3.0
MAX_L = 92.0
MIN_DE_RED = 30.0
WARM_HUES = ((0.0, 45.0), (330.0, 360.0))
WARM_MIN_SAT = 0.4
MIN_DE_YELLOW_AMBER = 30.0
COOL_HUES = (70.0, 200.0)
COOL_MIN_SAT = 0.4
MIN_DE_GREEN_WORLD3 = 30.0


# ------------------------------------------------------------------ color
def hx(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def hsv(value):
    return colorsys.rgb_to_hsv(*(c / 255.0 for c in hx(value)))


def _lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def rel_lum(c):
    return 0.2126 * _lin(c[0]) + 0.7152 * _lin(c[1]) + 0.0722 * _lin(c[2])


def ratio(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def lab(c):
    r, g, b = (_lin(v) for v in c)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
    fx, fy, fz = f(x), f(y), f(z)
    return 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)


def de(a, b):
    """Delta E CIE76 (Lab), como tools/palette_mundo1_preview.py."""
    return math.dist(lab(a), lab(b))


def tint(c, tint_hex):
    """Tinte del Debug sin vineta (la misma formula que tools/palette_mundo4_provisional.tint)."""
    with open(DEBUG_MODE, encoding="utf-8") as fh:
        cfg = json.load(fh)
    t = tuple(x / 255.0 for x in hx(tint_hex))
    base = [x / 255.0 for x in c]
    luma = 0.299 * base[0] + 0.587 * base[1] + 0.114 * base[2]
    mono = [luma * k * cfg["tint_gain"] for k in t]
    s = cfg["tint_strength"]
    out = [b + (m - b) * s for b, m in zip(base, mono)]
    return tuple(max(0, min(255, round(x * 255))) for x in out)


def _in_hues(value, ranges, min_sat):
    h, s, v = hsv(value)
    return s >= min_sat and v >= 0.2 and any(lo <= h * 360.0 <= hi for lo, hi in ranges)


# ------------------------------------------------------------------ medidas
def metrics(colors=None, debug_hex=None):
    rows = COLORS if colors is None else colors
    p = {n: hx(v) for n, v, _ in rows}
    dbg = DEBUG[1] if debug_hex is None else debug_hex
    white = hx(dbg)
    reds = [hx(RESERVED["alerta"]), hx(RESERVED["alerta_sombra"])] + [hx(c) for c in CARMIN]
    own = [(n, v) for n, v, _ in rows if n not in RESERVED]
    outline = p[OUTLINE_NAME]
    return {
        "de_white_red": min(de(white, r) for r in reds),
        "de_white_red_debug": min(de(white, tint(r, dbg)) for r in reds),
        "cr_outline_yellow": ratio(outline, p["amarillo_rebajas"]),
        "cr_outline_tint": min(ratio(outline, tint(p["amarillo_rebajas"], dbg)), ratio(outline, white)),
        "max_l": max(lab(p[n])[0] for n, _v, _r in rows),
        "too_light": [n for n, _v, _r in rows if lab(p[n])[0] > MAX_L],
        "warm": [n for n, v in own if _in_hues(v, WARM_HUES, WARM_MIN_SAT)
                 or min(de(p[n], r) for r in reds[:2]) < MIN_DE_RED],
        "de_yellow_amber": de(p["amarillo_rebajas"], p["ambar"]),
        "cool": [n for n, v in own if _in_hues(v, (COOL_HUES,), COOL_MIN_SAT)
                 or de(p[n], hx(WORLD3_GREEN)) < MIN_DE_GREEN_WORLD3],
        "cr_isak": min(ratio(hx(c), p[b]) for c in ISAK_CYANS for b in BACKS),
        "cr_eco": min(ratio(hx(c), p[b]) for c in ECO_COLORS for b in BACKS),
        "de_white_hud": de(white, hx(HUD_TEXT)),
        "de_white_isak": min(de(white, hx(c)) for c in ISAK_CYANS),
        "cr_white_black": ratio(white, outline),
    }


def _hud_debug():
    with open(HUD, encoding="utf-8") as fh:
        return json.load(fh).get("debug_colors", {}).get("5", "").lower().lstrip("#")


def _outline_worlds():
    """AttentionPoint.OUTLINE_WORLDS leido del codigo."""
    with open(ATTENTION_POINT, encoding="utf-8") as fh:
        m = re.search(r"^const OUTLINE_WORLDS: Array\[int\] = \[([0-9, ]*)\]", fh.read(), re.M)
    return [int(x) for x in m.group(1).split(",") if x.strip()] if m else []


def check_rules(colors=None, debug_hex=None):
    rows = COLORS if colors is None else colors
    hexes = {n: v for n, v, _ in rows}
    dbg = DEBUG[1] if debug_hex is None else debug_hex
    errors = []
    for name, value in RESERVED.items():
        if hexes.get(name) != value:
            errors.append("%s esta reservado (#%s)" % (name, value))
    m = metrics(rows, dbg)
    # 1. Blanco frente al rojo de dano y al carmin.
    if m["de_white_red"] < MIN_DE_WHITE_RED:
        errors.append("regla 1: el Debug esta demasiado cerca del rojo de dano o del carmin (dE %.1f < %.0f)"
                      % (m["de_white_red"], MIN_DE_WHITE_RED))
    if m["de_white_red_debug"] < MIN_DE_WHITE_RED:
        errors.append("regla 1: con el tinte del Debug el rojo de dano se acerca al Debug (dE %.1f < %.0f)"
                      % (m["de_white_red_debug"], MIN_DE_WHITE_RED))
    if _hud_debug() != dbg:
        errors.append("regla 1: debug_colors[\"5\"] de data/hud.json (#%s) no es el Debug de la paleta (#%s)"
                      % (_hud_debug(), dbg))
    # 2. Contorno negro de lo que revela el Debug.
    if m["cr_outline_yellow"] < MIN_CONTRAST:
        errors.append("regla 2: el contorno negro sobre el amarillo < 3:1 (%.2f)" % m["cr_outline_yellow"])
    if m["cr_outline_tint"] < MIN_CONTRAST:
        errors.append("regla 2: el contorno negro sobre el blanco del tinte < 3:1 (%.2f)" % m["cr_outline_tint"])
    # 3. El blanco, reservado al Debug.
    if m["too_light"]:
        errors.append("regla 3: colores por encima de L* %.0f (reservado al Debug): %s"
                      % (MAX_L, ", ".join(m["too_light"])))
    # 4. Sin rojos ni naranjas.
    if m["warm"]:
        errors.append("regla 4: rojos o naranjas fuera de los reservados: %s" % ", ".join(m["warm"]))
    # 5. Amarillo frente al ambar; contorno de los puntos.
    if m["de_yellow_amber"] < MIN_DE_YELLOW_AMBER:
        errors.append("regla 5: amarillo de rebajas y puntos demasiado parecidos (dE %.1f < %.0f)"
                      % (m["de_yellow_amber"], MIN_DE_YELLOW_AMBER))
    if 5 not in _outline_worlds():
        errors.append("regla 5: AttentionPoint.OUTLINE_WORLDS no incluye el Mundo 5")
    # 6. Sin lima ni cian en los neones.
    if m["cool"]:
        errors.append("regla 6: verdes lima o cianes en la paleta: %s" % ", ".join(m["cool"]))
    # 7. Isak (y Eco) sobre el negro.
    if m["cr_isak"] < MIN_CONTRAST:
        errors.append("regla 7: el cian de Isak sobre el fondo < 3:1 (%.2f)" % m["cr_isak"])
    if m["cr_eco"] < MIN_CONTRAST:
        errors.append("regla 7: la esfera de Eco sobre el fondo < 3:1 (%.2f)" % m["cr_eco"])
    return errors


def metrics_line(m):
    return ("blanco dE rojo %.0f (con Debug %.0f), %.1f:1 sobre negro · contorno %.1f:1 sobre amarillo, %.1f:1 sobre "
            "el tinte · L* max %.1f · amarillo-puntos dE %.0f · Isak cian %.1f:1 · (informa) blanco-texto HUD dE %.0f, "
            "blanco-cian dE %.0f"
            % (m["de_white_red"], m["de_white_red_debug"], m["cr_white_black"], m["cr_outline_yellow"],
               m["cr_outline_tint"], m["max_l"], m["de_yellow_amber"], m["cr_isak"], m["de_white_hud"],
               m["de_white_isak"]))


# ------------------------------------------------------------------ salida
def gpl_text():
    head = ("# Variante %s elegida en el paso 9 (tools/palette_mundo5_variants.py; cambiable con --apply); el blanco "
            "del Debug lo decidio el usuario (#ffffff)." % variants.ACTIVE if variants.ACTIVE else
            "# PROVISIONAL: colores de desarrollo del Mundo 5, sin cerrar (el usuario elige variante en el paso 9);"
            " el blanco del Debug esta decidido (#ffffff).")
    lines = ["GIMP Palette", "Name: " + TITLE, "Columns: 4", head,
             "# Generado por tools/palette_mundo5_provisional.py"]
    for name, value, role in COLORS + [DEBUG]:
        r, g, b = hx(value)
        lines.append("# %s: %s" % (name, role))
        lines.append("%3d %3d %3d\t%s" % (r, g, b, name))
    return "\n".join(lines) + "\n"


def palette_section():
    if variants.ACTIVE:
        out = {"_notes": "Variante %s «%s» (paso 9; tools/palette_mundo5_variants.py, la escribe "
                         "tools/palette_mundo5_provisional.py; no editar a mano): colores del Mundo 5 por nombre. "
                         "debug_blanco (#ffffff) lo decidio el usuario el 2026-10-29."
                         % (variants.ACTIVE, variants.VARIANTS[variants.ACTIVE]["title"])}
    else:
        out = {"_notes": "PROVISIONAL (tools/palette_mundo5_provisional.py; no editar a mano): colores de desarrollo "
                         "del Mundo 5 por nombre. Los hex no estan cerrados (decision del usuario, paso 9) salvo "
                         "debug_blanco (#ffffff, decidido el 2026-10-29)."}
    for name, value, _role in COLORS + [DEBUG]:
        out[name] = "#" + value
    return out


def new_objects():
    return {
        "_notes": "Catalogo de objetos del Mundo 5 «La Tienda» (docs/propuesta-mundo-5.md). Mismo formato que "
                  "data/world1_objects.json. Un nivel del Mundo 5 usa los tipos de los Mundos 1-4 mas los de este "
                  "archivo (tools/level_catalog.py los une en ese orden; gana el del mundo mas alto). Colores: "
                  "seccion palette (PROVISIONAL, la escribe tools/palette_mundo5_provisional.py). Precios y "
                  "economia: data/economy.json. Los tipos llegan desde el paso 2.",
        "tile_size": 64,
        "types": {},
    }


def write_objects(data, palette):
    """Escribe la seccion palette sin reformatear el resto del archivo (solo sustituye su bloque)."""
    block = json.dumps({"palette": palette}, ensure_ascii=False, indent="\t")[1:-1].strip("\n")
    text = open(OBJECTS, encoding="utf-8").read() if os.path.exists(OBJECTS) else ""
    new, n = re.subn(r'\t"palette": \{.*?\n\t\}', lambda _m: block, text, count=1, flags=re.S)
    if n != 1:
        data = data or new_objects()
        data["palette"] = palette
        new = json.dumps(data, ensure_ascii=False, indent="\t") + "\n"
    with open(OBJECTS, "w", encoding="utf-8") as fh:
        fh.write(new)


def main(argv):
    check = "--check" in argv
    errors = check_rules()
    data = {}
    if os.path.exists(OBJECTS):
        with open(OBJECTS, encoding="utf-8") as fh:
            data = json.load(fh)
    if check:
        current = open(GPL, encoding="utf-8").read() if os.path.exists(GPL) else ""
        if current != gpl_text():
            errors.append("%s no esta al dia" % os.path.relpath(GPL, ROOT))
        if data.get("palette") != palette_section():
            errors.append("la seccion palette de %s no esta al dia" % os.path.relpath(OBJECTS, ROOT))
    else:
        with open(GPL, "w", encoding="utf-8") as fh:
            fh.write(gpl_text())
        write_objects(data, palette_section())
    if "--verbose" in argv or not check:
        print("palette_mundo5_provisional: " + metrics_line(metrics()))
    for error in errors:
        print("palette_mundo5_provisional: " + error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
