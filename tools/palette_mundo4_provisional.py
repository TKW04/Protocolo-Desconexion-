"""Paleta PROVISIONAL del Mundo 4 «El Chat» (paso 0 de docs/propuesta-mundo-4.md §8).

SOLO PARA DESARROLLO (decision abierta del usuario en CLAUDE.md: los hex de los mundos 4 en adelante los elige
el usuario). En el paso 10 se le ensenan 3 variantes con maqueta y contrastes y elige una, como en los Mundos 1-3.
Hasta entonces las piezas por script del Mundo 4 (burbujas, «escribiendo…», zonas «Visto», salas de prueba...)
usan estos colores, que se leen por nombre de data/world4_objects.json (seccion palette).

EL CORAL DEL DEBUG YA ESTA DECIDIDO (usuario, 2026-10-27, §10.1): opcion B «Coral melocotón» #ff9f7a. Es el de
debug_colors["4"] de data/hud.json y el CORAL de tools/gen_hub_update_art.py (pieza 4 del hub); --check comprueba
que los tres coinciden. Lo que sigue provisional son los otros 16 colores.

Unos 16 colores mas el del Debug: azul marino y gris, burbujas crema, acento verde apagado (`07` §15.3). Se reservan
los del Mundo 1 que significan algo en todo el juego: alerta / alerta_sombra (dano) y ambar / ambar_sombra (puntos
de atencion, icono del HUD, brillo de Eco con la Q, «sin guardar»).

--check comprueba que el .gpl y la seccion palette estan al dia y las 5 reglas de docs/propuesta-mundo-4.md §6.1:
  1. coral frente al rojo de dano (alerta / alerta_sombra) y al carmin del punto debil: dE >= 30, tambien con el
     tinte del Debug (el rojo tenido por assets/shaders/debug_overlay.gdshader + data/debug_mode.json frente al
     coral sin tenir de los contornos del Debug); el coral contrasta >= 3:1 sobre el marino;
  2. crema de las burbujas (y su sombra) frente al ambar de los puntos: dE >= 20; los puntos llevan contorno oscuro
     de 1 px (AttentionPoint.has_outline(), Mundos 2-4; chat_noche);
  3. el cian de Isak y el de Eco contrastan >= 3:1 sobre el marino (fondo y medio); los tres puntos de Eco (cian) y
     los del «escribiendo…» (crema) nunca del mismo color (dE >= 20). Medida WCAG, como
     tools/measure_tower_contrast.py; el cuerpo casi negro de Isak se informa, no se exige (criterio del Mundo 2);
  4. el verde apagado del «Visto» (y todo verde de la paleta) con saturacion <= 40 %, lejos del verde acido del
     Debug del Mundo 3 (#a6ff2e); el fondo es marino (tono 210-240);
  5. bajo el velo del Modo oscuro (chat_noche al 60 %) el contorno de lo que dana (el mejor de alerta /
     alerta_sombra), los puntos del «escribiendo…» (crema) y los checks del «Visto» (verde_apagado) contrastan
     >= 3:1; bajo el velo del congelado (gris_oscuro al 50 %) el contorno de lo que dana tambien.

Genera assets/palettes/mundo4_provisional.gpl y escribe la seccion palette de data/world4_objects.json.
Con --check sale con 1 si algo no esta al dia o una regla falla (imprime las medidas con --verbose).

Uso: python3 -I tools/palette_mundo4_provisional.py [--check] [--verbose]
"""
import colorsys
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo4_provisional.gpl")
OBJECTS = os.path.join(ROOT, "data", "world4_objects.json")
HUD = os.path.join(ROOT, "data", "hud.json")
DEBUG_MODE = os.path.join(ROOT, "data", "debug_mode.json")
HUB_UPDATE_ART = os.path.join(ROOT, "tools", "gen_hub_update_art.py")

TITLE = "Mundo 4 El Chat - PROVISIONAL (solo desarrollo, hex sin cerrar salvo el coral)"
# (nombre, hex, funcion)
COLORS = [
    ("chat_noche", "0f1422", "Contorno oscuro (puntos de atencion, siluetas), sombra profunda, velo del Modo oscuro"),
    ("marino_fondo", "1a2238", "Fondo del chat: azul marino de madrugada (marino de referencia de §6.1)"),
    ("marino_medio", "243050", "Fondo medio: lista de chats en paralaje"),
    ("marino_luz", "34446a", "Luz de pantalla del fondo, avatares apagados"),
    ("gris_oscuro", "3c4250", "Barra de escribir (suelo), paredes de la lista de chats; velo del congelado"),
    ("gris_medio", "6b7280", "Bordes, sellos de hora"),
    ("gris_claro", "a9aebb", "Texto secundario, check gris «sin leer»"),
    ("blanco_pantalla", "f4f6fa", "Brillos de la pantalla, destellos"),
    ("crema", "eee4cc", "Burbujas de mensaje (plataformas) y puntos del «escribiendo…»"),
    ("crema_sombra", "b8ad94", "Sombra y borde de las burbujas"),
    ("verde_apagado", "7d9a80", "Acento: checks del «Visto», ola «Leído» (saturacion <= 40 %)"),
    ("verde_sombra", "4d6452", "Sombra del verde apagado"),
    ("alerta", "ff4a2a", "Rojo de dano (el del Mundo 1, reservado)"),
    ("alerta_sombra", "a3221c", "Sombra de lo rojo; contorno de lo que dana en la oscuridad y bajo el congelado"),
    ("ambar", "ffa000", "Puntos de atencion (el del Mundo 1, reservado)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atencion (reservado)"),
]
## Decidido por el usuario el 2026-10-27 (docs/propuesta-mundo-4.md §10.1, opcion B «Coral melocotón»).
DEBUG = ("debug_coral", "ff9f7a", "Debug del Mundo 4: coral melocotón (DECIDIDO; debug_colors[\"4\"] de data/hud.json)")

## Paso 10: variante elegida (tools/palette_mundo4_variants.py). Sus hex sustituyen a los de arriba; BASE_COLORS
## guarda la provisional (las variantes toman de ella los nombres y las funciones).
BASE_COLORS = list(COLORS)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_mundo4_variants as variants  # noqa: E402

if variants.ACTIVE:
    COLORS = variants.rows(variants.ACTIVE, BASE_COLORS)
    GPL = os.path.join(ROOT, "assets", "palettes", "mundo4.gpl")
    TITLE = "Mundo 4 El Chat - variante %s (%s)" % (variants.ACTIVE, variants.VARIANTS[variants.ACTIVE]["title"])

## Reservados del Mundo 1 (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}
## Carmin del punto debil (Mundo 1) y su brillo.
CARMIN = ("e0004a", "ff5a8c")
## Cian de la ropa de Isak (hoja importada) y colores de la esfera de Eco (tools/gen_eco_companion.py).
ISAK_CYANS = ("29defa", "36c0d4")
ISAK_BODY = "232324"
ECO_CYANS = ("9bb0e8", "f2f4f8")
## Los tres puntos de Eco del Mundo 4 (`04` §12.1; arte en el paso 10): cian, el de la ropa de Isak.
ECO_DOTS = "29defa"
## Verde acido del Debug del Mundo 3 (assets/palettes/mundo3.gpl).
WORLD3_GREEN = "a6ff2e"
## Velos (§3.3 y §3.6; los valores definitivos se ajustan en los pasos 2 y 4).
DARK_VEIL = 0.60    # chat_noche sobre el fondo en las zonas «Modo oscuro»
FROZEN_VEIL = 0.50  # gris_oscuro sobre la escena mientras Isak esta congelado

# Umbrales de §6.1.
MIN_DE_CORAL_RED = 30.0
MIN_DE_CREAM_AMBER = 20.0
MIN_DE_DOTS = 20.0
MIN_DE_GREEN_WORLD3 = 30.0
GREEN_MAX_SAT = 0.40
NAVY_HUE = (210.0, 240.0)
MIN_CONTRAST = 3.0


# ------------------------------------------------------------------ color
def hx(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def hsv(value):
    return colorsys.rgb_to_hsv(*(c / 255.0 for c in hx(value)))


def hue_deg(value):
    return hsv(value)[0] * 360.0


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
    """Tinte del Debug sin vineta (fragment() de assets/shaders/debug_overlay.gdshader con data/debug_mode.json;
    la misma formula que tools/palette_mundo3_provisional.tint)."""
    with open(DEBUG_MODE, encoding="utf-8") as fh:
        cfg = json.load(fh)
    t = tuple(x / 255.0 for x in hx(tint_hex))
    base = [x / 255.0 for x in c]
    luma = 0.299 * base[0] + 0.587 * base[1] + 0.114 * base[2]
    mono = [luma * k * cfg["tint_gain"] for k in t]
    s = cfg["tint_strength"]
    out = [b + (m - b) * s for b, m in zip(base, mono)]
    return tuple(max(0, min(255, round(x * 255))) for x in out)


def mix(a, b, k):
    return tuple(round(x + (y - x) * k) for x, y in zip(a, b))


def _is_green(value):
    h, s, v = hsv(value)
    return 75.0 <= h * 360.0 <= 165.0 and s >= 0.08 and v >= 0.2


# ------------------------------------------------------------------ medidas
def metrics(colors=None, debug_hex=None):
    rows = COLORS if colors is None else colors
    p = {n: hx(v) for n, v, _ in rows}
    dbg = DEBUG[1] if debug_hex is None else debug_hex
    coral = hx(dbg)
    reds = [p["alerta"], p["alerta_sombra"]] + [hx(c) for c in CARMIN]
    backs = ("marino_fondo", "marino_medio")
    dark = [mix(p[b], p["chat_noche"], DARK_VEIL) for b in backs]
    frozen = [mix(p[b], p["gris_oscuro"], FROZEN_VEIL) for b in backs]

    def outline(veils):
        return min(max(ratio(p["alerta"], v), ratio(p["alerta_sombra"], v)) for v in veils)
    greens = [n for n, v, _ in rows if _is_green(v)]
    return {
        "de_coral_red": min(de(coral, r) for r in reds),
        "de_coral_red_debug": min(de(coral, tint(r, dbg)) for r in reds),
        "cr_coral_navy": ratio(coral, p["marino_fondo"]),
        "de_cream_amber": min(de(p[n], p["ambar"]) for n in ("crema", "crema_sombra")),
        "cr_isak": min(ratio(hx(c), p[b]) for c in ISAK_CYANS for b in backs),
        "cr_eco": min(ratio(hx(c), p[b]) for c in ECO_CYANS + (ECO_DOTS,) for b in backs),
        "cr_isak_body": min(ratio(hx(ISAK_BODY), p[b]) for b in backs),
        "de_eco_typing_dots": de(hx(ECO_DOTS), p["crema"]),
        "green_sat": max([hsv(v)[1] for n, v, _ in rows if n in greens] or [0.0]),
        "de_green_world3": min([de(p[n], hx(WORLD3_GREEN)) for n in greens] or [999.0]),
        "greens": greens,
        "cr_dark_outline": outline(dark),
        "cr_dark_dots": min(ratio(p["crema"], v) for v in dark),
        "cr_dark_checks": min(ratio(p["verde_apagado"], v) for v in dark),
        "cr_frozen_outline": outline(frozen),
    }


def _hud_debug():
    with open(HUD, encoding="utf-8") as fh:
        return json.load(fh).get("debug_colors", {}).get("4", "").lower().lstrip("#")


def _hub_coral():
    """Hex del CORAL de tools/gen_hub_update_art.py (pieza 4 del hub), leido del codigo sin importarlo (Pillow)."""
    with open(HUB_UPDATE_ART, encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"^CORAL = \(0x([0-9a-fA-F]{2}), 0x([0-9a-fA-F]{2}), 0x([0-9a-fA-F]{2}), 255\)", text, re.M)
    return "".join(m.groups()).lower() if m else ""


def check_rules(colors=None, debug_hex=None):
    rows = COLORS if colors is None else colors
    hexes = {n: v for n, v, _ in rows}
    dbg = DEBUG[1] if debug_hex is None else debug_hex
    errors = []
    for name, value in RESERVED.items():
        if hexes.get(name) != value:
            errors.append("%s esta reservado (#%s)" % (name, value))
    m = metrics(rows, dbg)
    # 1. Coral frente al rojo de dano y al carmin.
    if m["de_coral_red"] < MIN_DE_CORAL_RED:
        errors.append("regla 1: coral demasiado cerca del rojo de dano o del carmin (dE %.1f < %.0f)"
                      % (m["de_coral_red"], MIN_DE_CORAL_RED))
    if m["de_coral_red_debug"] < MIN_DE_CORAL_RED:
        errors.append("regla 1: con el tinte del Debug el rojo de dano se acerca al coral (dE %.1f < %.0f)"
                      % (m["de_coral_red_debug"], MIN_DE_CORAL_RED))
    if m["cr_coral_navy"] < MIN_CONTRAST:
        errors.append("regla 1: el coral sobre el marino < 3:1 (%.2f)" % m["cr_coral_navy"])
    if _hud_debug() != dbg:
        errors.append("regla 1: debug_colors[\"4\"] de data/hud.json (#%s) no es el Debug de la paleta (#%s)"
                      % (_hud_debug(), dbg))
    if _hub_coral() != dbg:
        errors.append("regla 1: CORAL de tools/gen_hub_update_art.py (#%s) no es el Debug de la paleta (#%s)"
                      % (_hub_coral(), dbg))
    # 2. Crema frente al ambar de los puntos.
    if m["de_cream_amber"] < MIN_DE_CREAM_AMBER:
        errors.append("regla 2: crema y puntos demasiado parecidos (dE %.1f < %.0f)"
                      % (m["de_cream_amber"], MIN_DE_CREAM_AMBER))
    # 3. Isak y Eco sobre el marino; puntos de Eco frente a los del «escribiendo…».
    if m["cr_isak"] < MIN_CONTRAST:
        errors.append("regla 3: el cian de Isak sobre el fondo < 3:1 (%.2f)" % m["cr_isak"])
    if m["cr_eco"] < MIN_CONTRAST:
        errors.append("regla 3: Eco sobre el fondo < 3:1 (%.2f)" % m["cr_eco"])
    if m["de_eco_typing_dots"] < MIN_DE_DOTS:
        errors.append("regla 3: los puntos de Eco y los del «escribiendo…» se parecen (dE %.1f < %.0f)"
                      % (m["de_eco_typing_dots"], MIN_DE_DOTS))
    bg_hue = hue_deg(hexes["marino_fondo"])
    if not NAVY_HUE[0] <= bg_hue <= NAVY_HUE[1]:
        errors.append("regla 3: el fondo debe ser marino (tono %d-%d, tiene %.1f)" % (NAVY_HUE + (bg_hue,)))
    # 4. Verde apagado.
    if "verde_apagado" not in m["greens"]:
        errors.append("regla 4: verde_apagado debe ser verde")
    if m["green_sat"] > GREEN_MAX_SAT:
        errors.append("regla 4: los verdes deben ser apagados (saturacion %.0f %% > %.0f %%)"
                      % (m["green_sat"] * 100, GREEN_MAX_SAT * 100))
    if m["de_green_world3"] < MIN_DE_GREEN_WORLD3:
        errors.append("regla 4: un verde se parece al verde acido del Mundo 3 (dE %.1f < %.0f)"
                      % (m["de_green_world3"], MIN_DE_GREEN_WORLD3))
    # 5. Modo oscuro y congelado.
    for key, what in (("cr_dark_outline", "el contorno de lo que dana"), ("cr_dark_dots", "los puntos del «escribiendo…»"),
                      ("cr_dark_checks", "los checks del «Visto»")):
        if m[key] < MIN_CONTRAST:
            errors.append("regla 5: en el Modo oscuro %s < 3:1 (%.2f)" % (what, m[key]))
    if m["cr_frozen_outline"] < MIN_CONTRAST:
        errors.append("regla 5: bajo el velo del congelado el contorno de lo que dana < 3:1 (%.2f)"
                      % m["cr_frozen_outline"])
    return errors


def metrics_line(m):
    return ("coral dE rojo %.0f (con Debug %.0f), %.1f:1 sobre marino · crema-puntos dE %.0f · Isak cian %.1f:1 "
            "(cuerpo %.1f:1) · Eco %.1f:1 · puntos Eco/escribiendo dE %.0f · verde sat %.0f %% · oscuro: contorno "
            "%.1f:1, puntos %.1f:1, checks %.1f:1 · congelado: contorno %.1f:1"
            % (m["de_coral_red"], m["de_coral_red_debug"], m["cr_coral_navy"], m["de_cream_amber"], m["cr_isak"],
               m["cr_isak_body"], m["cr_eco"], m["de_eco_typing_dots"], m["green_sat"] * 100, m["cr_dark_outline"],
               m["cr_dark_dots"], m["cr_dark_checks"], m["cr_frozen_outline"]))


# ------------------------------------------------------------------ salida
def gpl_text():
    head = ("# Variante %s elegida en el paso 10 (tools/palette_mundo4_variants.py; cambiable con --apply); el coral "
            "del Debug lo decidio el usuario (#ff9f7a)." % variants.ACTIVE if variants.ACTIVE else
            "# PROVISIONAL: colores de desarrollo del Mundo 4, sin cerrar (el usuario elige variante en el paso 10);"
            " el coral del Debug esta decidido (#ff9f7a).")
    lines = ["GIMP Palette", "Name: " + TITLE, "Columns: 4", head,
             "# Generado por tools/palette_mundo4_provisional.py"]
    for name, value, role in COLORS + [DEBUG]:
        r, g, b = hx(value)
        lines.append("# %s: %s" % (name, role))
        lines.append("%3d %3d %3d\t%s" % (r, g, b, name))
    return "\n".join(lines) + "\n"


def palette_section():
    if variants.ACTIVE:
        out = {"_notes": "Variante %s «%s» (paso 10; tools/palette_mundo4_variants.py, la escribe "
                         "tools/palette_mundo4_provisional.py; no editar a mano): colores del Mundo 4 por nombre. "
                         "debug_coral (#ff9f7a) lo decidio el usuario el 2026-10-28."
                         % (variants.ACTIVE, variants.VARIANTS[variants.ACTIVE]["title"])}
    else:
        out = {"_notes": "PROVISIONAL (tools/palette_mundo4_provisional.py; no editar a mano): colores de desarrollo "
                         "del Mundo 4 por nombre. Los hex no estan cerrados (decision abierta del usuario, paso 10) "
                         "salvo debug_coral (#ff9f7a, decidido el 2026-10-27)."}
    for name, value, _role in COLORS + [DEBUG]:
        out[name] = "#" + value
    return out


def new_objects():
    return {
        "_notes": "Catalogo de objetos del Mundo 4 «El Chat» (docs/propuesta-mundo-4.md). Mismo formato que "
                  "data/world1_objects.json. Un nivel del Mundo 4 usa los tipos de los Mundos 1-3 mas los de este "
                  "archivo (tools/level_catalog.py los une en ese orden; gana el del mundo mas alto). Colores: "
                  "seccion palette (PROVISIONAL, la escribe tools/palette_mundo4_provisional.py). Los tipos llegan "
                  "desde el paso 2.",
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
        print("palette_mundo4_provisional: " + metrics_line(metrics()))
    for error in errors:
        print("palette_mundo4_provisional: " + error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
