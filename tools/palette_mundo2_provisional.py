"""Paleta PROVISIONAL del Mundo 2 «El Feed» (paso 0 de docs/propuesta-mundo-2.md §8).

SOLO PARA DESARROLLO (decision del usuario, 2026-10-22): los hex del Mundo 2 NO
estan cerrados. El arte final comparara 2-3 variantes con el usuario (como la
variante B del Mundo 1) y resolvera el choque del Debug ambar con el ambar de
los puntos de atencion y el del magenta frente al rojo de dano. Hasta entonces
las piezas por script del Mundo 2 (tarjeta fragil, Historia, borde del scroll,
golpe al suelo, salas de prueba) usan estos colores, que se leen por nombre de
data/world2_objects.json (seccion palette).

Reglas que ya respeta (docs/propuesta-mundo-2.md §6.1, PROPUESTA):
- violeta y magenta neon, tarjetas; el magenta con tono >= 300 grados;
- el rojo de dano (alerta) y el carmin del punto debil se reservan (los del Mundo 1);
- el Debug ambar algo mas anaranjado que el ambar de los puntos de atencion.

Genera assets/palettes/mundo2_provisional.gpl y escribe la seccion palette de
data/world2_objects.json. Con --check sale con 1 si alguno no esta al dia.

Uso: python3 tools/palette_mundo2_provisional.py [--check]
"""
import colorsys
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GPL = os.path.join(ROOT, "assets", "palettes", "mundo2_provisional.gpl")
OBJECTS = os.path.join(ROOT, "data", "world2_objects.json")

TITLE = "Mundo 2 El Feed - PROVISIONAL (solo desarrollo, hex sin cerrar)"
# (nombre, hex, funcion)
COLORS = [
    ("feed_noche", "140a24", "Fondo profundo del feed, contorno oscuro"),
    ("feed_fondo", "2a1450", "Fondo lejano (videos borrosos)"),
    ("feed_medio", "45207a", "Fondo medio"),
    ("feed_resplandor", "6a3cb0", "Resplandor de pantalla"),
    ("tarjeta_sombra", "120a20", "Tarjeta: sombra"),
    ("tarjeta_base", "2a1d45", "Tarjeta: base"),
    ("tarjeta_luz", "4a3a78", "Tarjeta: luz/bisel"),
    ("tarjeta_borde", "b7a3f0", "Borde superior de las tarjetas"),
    ("blanco", "f4f0fa", "Texto, barras de progreso, brillo"),
    ("gris", "b8aecf", "Sombra de lo blanco, chispa gris"),
    ("alerta", "ff4a2a", "Rojo de dano (el del Mundo 1): borde del scroll, grietas que avisan"),
    ("alerta_sombra", "a3221c", "Sombra de lo rojo"),
    ("magenta", "ff3cf0", "Magenta neon (tono >= 300): Historias, acentos"),
    ("magenta_sombra", "8a1a8c", "Sombra del magenta"),
    ("ambar", "ffa000", "Puntos de atencion (el del Mundo 1)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atencion"),
]
DEBUG = ("debug_ambar", "ff9318", "Debug del Mundo 2 (provisional; mas anaranjado que los puntos)")


def hue_deg(hex_value):
    r, g, b = (int(hex_value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return colorsys.rgb_to_hsv(r, g, b)[0] * 360.0


def gpl_text():
    lines = ["GIMP Palette", "Name: " + TITLE, "Columns: 4",
             "# PROVISIONAL: colores de desarrollo del Mundo 2, sin cerrar (el arte final compara variantes).",
             "# Generado por tools/palette_mundo2_provisional.py"]
    for name, value, role in COLORS + [DEBUG]:
        r, g, b = (int(value[i:i + 2], 16) for i in (0, 2, 4))
        lines.append("# %s: %s" % (name, role))
        lines.append("%3d %3d %3d\t%s" % (r, g, b, name))
    return "\n".join(lines) + "\n"


def palette_section():
    out = {"_notes": "PROVISIONAL (tools/palette_mundo2_provisional.py; no editar a mano): colores de desarrollo "
                     "del Mundo 2 por nombre. Los hex no estan cerrados (decision abierta del usuario)."}
    for name, value, _role in COLORS + [DEBUG]:
        out[name] = "#" + value
    return out


def check_rules():
    errors = []
    magenta = dict((n, v) for n, v, _ in COLORS)["magenta"]
    if hue_deg(magenta) < 300.0:
        errors.append("el magenta debe tener tono >= 300 (tiene %.1f)" % hue_deg(magenta))
    if not hue_deg(DEBUG[1]) < hue_deg(dict((n, v) for n, v, _ in COLORS)["ambar"]):
        errors.append("el Debug ambar debe ser mas anaranjado que el ambar de los puntos")
    return errors


def main(argv):
    check = "--check" in argv
    errors = check_rules()
    expected_gpl = gpl_text()
    data = {}
    if os.path.exists(OBJECTS):
        with open(OBJECTS, encoding="utf-8") as fh:
            data = json.load(fh)
    expected_palette = palette_section()
    if check:
        current = open(GPL, encoding="utf-8").read() if os.path.exists(GPL) else ""
        if current != expected_gpl:
            errors.append("%s no esta al dia" % os.path.relpath(GPL, ROOT))
        if data.get("palette") != expected_palette:
            errors.append("la seccion palette de %s no esta al dia" % os.path.relpath(OBJECTS, ROOT))
    else:
        with open(GPL, "w", encoding="utf-8") as fh:
            fh.write(expected_gpl)
        data["palette"] = expected_palette
        with open(OBJECTS, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent="\t")
            fh.write("\n")
    for error in errors:
        print("palette_mundo2_provisional: " + error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
