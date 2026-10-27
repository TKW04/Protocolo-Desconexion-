"""Paleta PROVISIONAL del Mundo 3 «La Vitrina» (paso 0 de docs/propuesta-mundo-3.md §8).

SOLO PARA DESARROLLO (decision abierta del usuario en CLAUDE.md: los hex de los mundos 3 en adelante los elige
el usuario). En el paso 9 se le ensenan 3 variantes con maqueta y contrastes y elige una, como en los Mundos 1 y 2.
Hasta entonces las piezas por script del Mundo 3 (corazones, plataformas de likes, publicaciones, HUD de likes,
salas de prueba...) usan estos colores, que se leen por nombre de data/world3_objects.json (seccion palette).

Unos 16 colores mas el del Debug (verde acido, el de debug_colors["3"] de data/hud.json). Se reservan los del
Mundo 1 que significan algo en todo el juego: alerta / alerta_sombra (dano) y ambar / ambar_sombra (puntos de
atencion, icono del HUD, brillo de Eco con la Q, «sin guardar»).

--check comprueba que el .gpl y la seccion palette estan al dia y las 5 reglas de docs/propuesta-mundo-3.md §6.1:
  1. dorado de los marcos apagado (saturacion <= 55 %, tono 45-52 grados) y a dE >= 20 del ambar de los puntos
     (#ffa000), tambien con el tinte del Debug (assets/shaders/debug_overlay.gdshader + data/debug_mode.json);
     los puntos llevan contorno oscuro de 1 px (AttentionPoint.has_outline(), Mundos 2 y 3; galeria_noche);
  2. rosa pastel claro y poco saturado (L >= 75) y lejos del rojo de dano y del carmin del punto debil; los
     corazones son rosa (nunca rojos) con borde blanco brillante;
  3. el cian de Isak y el de Eco contrastan >= 3:1 sobre el fondo malva de la galeria (fondo y medio); el blanco
     brillante no es fondo. Medida: WCAG, como tools/measure_tower_contrast.py. El cuerpo de Isak es casi negro a
     proposito (chaqueta gris oscura, hoja importada): lo que lo despega del fondo es su cian (mismo criterio que el
     Mundo 2, tools/palette_mundo2_preview.py); su cuerpo gris se informa, no se exige;
  4. el Debug verde acido es el unico verde de la paleta;
  5. bajo el velo blanco del flash (70 %, sobre el fondo y el medio) el contorno rojo de lo que dana contrasta
     >= 3:1 (con el mejor de alerta / alerta_sombra: sobre blanco el contorno va en alerta_sombra).

Genera assets/palettes/mundo3_provisional.gpl y escribe la seccion palette de data/world3_objects.json.
Con --check sale con 1 si algo no esta al dia o una regla falla (imprime las medidas con --verbose).

Desde el paso 9 (2026-10-26) hay una variante ELEGIDA en tools/palette_mundo3_variants.py (ACTIVE): sus hex
sustituyen a los de abajo (que se quedan como referencia de la provisional) y la salida es
assets/palettes/mundo3.gpl (la provisional, assets/palettes/mundo3_provisional.gpl, se borro). Con ACTIVE = None
volveria la provisional. Las 3 variantes y su comparativa: tools/palette_mundo3_preview.py.

Uso: python3 tools/palette_mundo3_provisional.py [--check] [--verbose]
"""
import colorsys
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROVISIONAL_GPL = os.path.join(ROOT, "assets", "palettes", "mundo3_provisional.gpl")
GPL = PROVISIONAL_GPL
OBJECTS = os.path.join(ROOT, "data", "world3_objects.json")
HUD = os.path.join(ROOT, "data", "hud.json")
DEBUG_MODE = os.path.join(ROOT, "data", "debug_mode.json")

TITLE = "Mundo 3 La Vitrina - PROVISIONAL (solo desarrollo, hex sin cerrar)"
# (nombre, hex, funcion)
COLORS = [
    ("galeria_noche", "1e1426", "Contorno oscuro (puntos de atencion, siluetas), sombra profunda"),
    ("trastienda_fondo", "5a3d62", "Fondo de la galeria: malva medio-oscuro («trastienda»)"),
    ("trastienda_medio", "6a4c72", "Fondo medio: fotos enmarcadas en paralaje"),
    ("trastienda_luz", "8a6c92", "Focos y luz del fondo"),
    ("marco_sombra", "5c4a2c", "Sombra de los marcos dorados"),
    ("dorado", "b3a05c", "Marcos dorados APAGADOS (tono 45-52, saturacion <= 55 %)"),
    ("dorado_luz", "d8c78c", "Bisel y brillo de los marcos"),
    ("rosa_pastel", "f6c8dc", "Rosa pastel: plataformas de likes, carteles, acentos"),
    ("rosa_sombra", "b88aa2", "Sombra del rosa pastel"),
    ("corazon_rosa", "ffaad2", "Corazones de likes (rosa, nunca rojo; borde blanco_brillante)"),
    ("blanco_brillante", "fbf8fc", "Blanco brillante: marcos, plataformas, destellos, borde de los corazones"),
    ("gris_perla", "c8bccb", "Sombra de lo blanco, texto secundario"),
    ("alerta", "ff4a2a", "Rojo de dano (el del Mundo 1, reservado)"),
    ("alerta_sombra", "a3221c", "Sombra de lo rojo; contorno de lo que dana bajo el velo del flash"),
    ("ambar", "ffa000", "Puntos de atencion (el del Mundo 1, reservado)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atencion (reservado)"),
]
DEBUG = ("debug_verde", "a6ff2e", "Debug del Mundo 3: verde acido (debug_colors[\"3\"] de data/hud.json)")

## Paso 9: variante elegida (tools/palette_mundo3_variants.py). Sus hex sustituyen a los de arriba.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_mundo3_variants as variants  # noqa: E402

if variants.ACTIVE:
    COLORS = variants.rows(variants.ACTIVE, COLORS)
    DEBUG = (DEBUG[0], variants.DEBUG_HEX, DEBUG[2])
    TITLE = "Mundo 3 La Vitrina - variante %s (%s)" % (variants.ACTIVE, variants.VARIANTS[variants.ACTIVE]["title"])
    GPL = os.path.join(ROOT, "assets", "palettes", "mundo3.gpl")

## Reservados del Mundo 1 (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}
## Carmin del punto debil (Mundo 1): el rosa tampoco se le puede parecer.
CARMIN = ("e0004a", "ff5a8c")
## Cian de la ropa de Isak (hoja importada) y colores de la esfera de Eco (tools/gen_eco_companion.py: borde_luz y
## banner_blanco del Mundo 1).
ISAK_CYANS = ("29defa", "36c0d4")
ISAK_BODY = "232324"
ECO_CYANS = ("9bb0e8", "f2f4f8")
## Velo del flash del Influencer bot (§3.6): blanco al 70 % (con «Reducir efectos», 40 %).
FLASH_VEIL = 0.70

# Umbrales de §6.1.
MIN_DE_GOLD_AMBER = 20.0
GOLD_HUE = (45.0, 52.0)
GOLD_MAX_SAT = 0.55
PINK_MIN_L = 75.0
MIN_DE_PINK_RED = 40.0
MIN_DE_HEART_RED = 30.0
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
    la misma formula que tools/palette_mundo1_preview.tint_px)."""
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


# ------------------------------------------------------------------ medidas
def metrics(colors=None, debug_hex=None):
    rows = COLORS if colors is None else colors
    p = {n: hx(v) for n, v, _ in rows}
    hexes = {n: v for n, v, _ in rows}
    dbg = DEBUG[1] if debug_hex is None else debug_hex
    gold_t, amber_t = tint(p["dorado"], dbg), tint(p["ambar"], dbg)
    backs = ("trastienda_fondo", "trastienda_medio")
    veiled = [mix(p[b], p["blanco_brillante"], FLASH_VEIL) for b in backs]
    gold_h, gold_s, _v = hsv(hexes["dorado"])
    return {
        "gold_hue": gold_h * 360.0,
        "gold_sat": gold_s,
        "de_gold_amber": de(p["dorado"], p["ambar"]),
        "de_gold_amber_debug": de(gold_t, amber_t),
        "de_goldlight_amber": de(p["dorado_luz"], p["ambar"]),
        "pink_l": lab(p["rosa_pastel"])[0],
        "pink_sat": hsv(hexes["rosa_pastel"])[1],
        "de_pink_red": min(de(p["rosa_pastel"], p[n]) for n in ("alerta", "alerta_sombra")),
        "de_pink_carmin": min(de(p["rosa_pastel"], hx(c)) for c in CARMIN),
        "de_heart_red": min([de(p["corazon_rosa"], p[n]) for n in ("alerta", "alerta_sombra")]
                            + [de(p["corazon_rosa"], hx(c)) for c in CARMIN]),
        "heart_l": lab(p["corazon_rosa"])[0],
        "cr_isak": min(ratio(hx(c), p[b]) for c in ISAK_CYANS for b in backs),
        "cr_eco": min(ratio(hx(c), p[b]) for c in ECO_CYANS for b in backs),
        "cr_isak_body": min(ratio(hx(ISAK_BODY), p[b]) for b in backs),
        "cr_white_bg": ratio(p["blanco_brillante"], p["trastienda_fondo"]),
        "cr_flash_outline": min(max(ratio(p["alerta"], v), ratio(p["alerta_sombra"], v)) for v in veiled),
        "greens": [n for n, v, _ in rows if _is_green(v)],
    }


def _is_green(value):
    h, s, v = hsv(value)
    return 75.0 <= h * 360.0 <= 165.0 and s >= 0.25 and v >= 0.2


def check_rules(colors=None, debug_hex=None):
    rows = COLORS if colors is None else colors
    hexes = {n: v for n, v, _ in rows}
    dbg = DEBUG[1] if debug_hex is None else debug_hex
    errors = []
    for name, value in RESERVED.items():
        if hexes.get(name) != value:
            errors.append("%s esta reservado (#%s)" % (name, value))
    m = metrics(rows, dbg)
    # 1. Dorado frente al ambar de los puntos.
    if not GOLD_HUE[0] <= m["gold_hue"] <= GOLD_HUE[1]:
        errors.append("regla 1: el dorado debe tener tono %d-%d (tiene %.1f)" % (GOLD_HUE + (m["gold_hue"],)))
    if m["gold_sat"] > GOLD_MAX_SAT:
        errors.append("regla 1: el dorado debe ser apagado (saturacion %.0f %% > %.0f %%)"
                      % (m["gold_sat"] * 100, GOLD_MAX_SAT * 100))
    for key, what in (("de_gold_amber", "sin Debug"), ("de_gold_amber_debug", "con el tinte del Debug"),
                      ("de_goldlight_amber", "dorado_luz sin Debug")):
        if m[key] < MIN_DE_GOLD_AMBER:
            errors.append("regla 1: dorado y puntos demasiado parecidos %s (dE %.1f < %.0f)"
                          % (what, m[key], MIN_DE_GOLD_AMBER))
    # 2. Rosa frente al rojo de dano.
    if m["pink_l"] < PINK_MIN_L:
        errors.append("regla 2: el rosa pastel debe ser claro (L %.1f < %.0f)" % (m["pink_l"], PINK_MIN_L))
    if m["pink_sat"] > 0.4:
        errors.append("regla 2: el rosa pastel debe ser poco saturado (%.0f %% > 40 %%)" % (m["pink_sat"] * 100))
    if m["de_pink_red"] < MIN_DE_PINK_RED or m["de_pink_carmin"] < MIN_DE_PINK_RED:
        errors.append("regla 2: rosa demasiado cerca del rojo de dano o del carmin (dE %.1f / %.1f < %.0f)"
                      % (m["de_pink_red"], m["de_pink_carmin"], MIN_DE_PINK_RED))
    if m["de_heart_red"] < MIN_DE_HEART_RED:
        errors.append("regla 2: el corazon se parece al rojo de dano o al carmin (dE %.1f < %.0f)"
                      % (m["de_heart_red"], MIN_DE_HEART_RED))
    heart_hue = hue_deg(hexes["corazon_rosa"])
    if not 300.0 <= heart_hue <= 345.0:
        errors.append("regla 2: el corazon debe ser rosa (tono 300-345, tiene %.1f)" % heart_hue)
    # 3. Isak y Eco sobre el fondo malva.
    if m["cr_isak"] < MIN_CONTRAST:
        errors.append("regla 3: el cian de Isak sobre el fondo < 3:1 (%.2f)" % m["cr_isak"])
    if m["cr_eco"] < MIN_CONTRAST:
        errors.append("regla 3: Eco sobre el fondo < 3:1 (%.2f)" % m["cr_eco"])
    if m["cr_white_bg"] < MIN_CONTRAST:
        errors.append("regla 3: el blanco brillante no se despega del fondo (%.2f)" % m["cr_white_bg"])
    bg_hue = hue_deg(hexes["trastienda_fondo"])
    if not 270.0 <= bg_hue <= 330.0:
        errors.append("regla 3: el fondo debe ser malva (tono 270-330, tiene %.1f)" % bg_hue)
    # 4. El Debug es el unico verde.
    if m["greens"] or not _is_green(dbg):
        errors.append("regla 4: el unico verde debe ser el Debug (verdes en la paleta: %s; Debug verde: %s)"
                      % (", ".join(m["greens"]) or "ninguno", "si" if _is_green(dbg) else "no"))
    with open(HUD, encoding="utf-8") as fh:
        hud_debug = json.load(fh).get("debug_colors", {}).get("3", "")
    if hud_debug.lower().lstrip("#") != dbg:
        errors.append("regla 4: debug_colors[\"3\"] de data/hud.json (%s) no es el Debug de la paleta (#%s)"
                      % (hud_debug, dbg))
    # 5. Velo del flash.
    if m["cr_flash_outline"] < MIN_CONTRAST:
        errors.append("regla 5: bajo el velo del flash el contorno rojo < 3:1 (%.2f)" % m["cr_flash_outline"])
    return errors


def metrics_line(m):
    return ("dorado %.0f° sat %.0f %% · dorado-puntos dE %.0f (con Debug %.0f) · rosa L %.0f, dE rojo %.0f / "
            "carmin %.0f · corazon dE %.0f · Isak cian %.1f:1 (cuerpo %.1f:1) · Eco %.1f:1 · velo: contorno %.1f:1"
            % (m["gold_hue"], m["gold_sat"] * 100, m["de_gold_amber"], m["de_gold_amber_debug"], m["pink_l"],
               m["de_pink_red"], m["de_pink_carmin"], m["de_heart_red"], m["cr_isak"], m["cr_isak_body"],
               m["cr_eco"], m["cr_flash_outline"]))


# ------------------------------------------------------------------ salida
def gpl_text():
    head = ("# Variante %s elegida en el paso 9 (tools/palette_mundo3_variants.py; cambiable con "
            "tools/palette_mundo3_preview.py --apply)." % variants.ACTIVE if variants.ACTIVE else
            "# PROVISIONAL: colores de desarrollo del Mundo 3, sin cerrar (el usuario elige variante en el paso 9).")
    lines = ["GIMP Palette", "Name: " + TITLE, "Columns: 4", head,
             "# Generado por tools/palette_mundo3_provisional.py"]
    for name, value, role in COLORS + [DEBUG]:
        r, g, b = hx(value)
        lines.append("# %s: %s" % (name, role))
        lines.append("%3d %3d %3d\t%s" % (r, g, b, name))
    return "\n".join(lines) + "\n"


def palette_section():
    if variants.ACTIVE:
        out = {"_notes": "Variante %s (tools/palette_mundo3_variants.py, escrita por tools/palette_mundo3_provisional.py; "
                         "no editar a mano): colores del Mundo 3 por nombre. Elegida en el paso 9; se cambia con "
                         "tools/palette_mundo3_preview.py --apply." % variants.ACTIVE}
    else:
        out = {"_notes": "PROVISIONAL (tools/palette_mundo3_provisional.py; no editar a mano): colores de desarrollo "
                         "del Mundo 3 por nombre. Los hex no estan cerrados (decision abierta del usuario, paso 9)."}
    for name, value, _role in COLORS + [DEBUG]:
        out[name] = "#" + value
    return out


def write_objects(data, palette):
    """Escribe la seccion palette sin reformatear el resto del archivo (solo sustituye su bloque)."""
    block = json.dumps({"palette": palette}, ensure_ascii=False, indent="\t")[1:-1].strip("\n")
    text = open(OBJECTS, encoding="utf-8").read() if os.path.exists(OBJECTS) else ""
    new, n = re.subn(r'\t"palette": \{.*?\n\t\}', lambda _m: block, text, count=1, flags=re.S)
    if n != 1:
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
        if variants.ACTIVE and os.path.exists(PROVISIONAL_GPL):
            errors.append("%s sobra con la variante %s elegida (ejecuta tools/palette_mundo3_provisional.py)"
                          % (os.path.relpath(PROVISIONAL_GPL, ROOT), variants.ACTIVE))
    else:
        with open(GPL, "w", encoding="utf-8") as fh:
            fh.write(gpl_text())
        if variants.ACTIVE and os.path.exists(PROVISIONAL_GPL):
            os.remove(PROVISIONAL_GPL)
        write_objects(data, palette_section())
    if "--verbose" in argv or not check:
        print("palette_mundo3_provisional: " + metrics_line(metrics()))
    for error in errors:
        print("palette_mundo3_provisional: " + error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
