#!/usr/bin/env python3
"""Valida el aspecto de la Q de la ayuda de Eco y de su variante apagada de
relectura (secciones prompt y reread.prompt de data/help.json; HelpPrompt).

La Q no es un PNG: se dibuja en juego con la fuente de textos
(assets/sprites/ui/text_font.fnt, glifo en banner_blanco) sobre una placa con
borde; la variante apagada tine el glifo con el shader de color clave. Por eso
este validador comprueba los datos en lugar de un sprite:
- todos los colores (placa, borde, glifo y color clave) estan en
  assets/palettes/mundo1.gpl;
- la variante apagada no usa rojos (alerta, alerta_sombra, carmin,
  carmin_brillo) ni ambar (puntos de atencion, brillo de Eco);
- su glifo es mas oscuro que el de la Q normal (atenuado) y su escala entera es
  menor (mas pequena) y sin bote;
- el color clave es el del glifo de la fuente (banner_blanco);
- la fuente tiene el glifo de la tecla por defecto (fallback_key).

Uso (desde la raiz del repo): python3 -I tools/validate_help_prompt.py
Sale con 1 si hay errores.
"""
import json
import os
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)

FORBIDDEN = ("alerta", "alerta_sombra", "carmin", "carmin_brillo", "ambar", "ambar_sombra")
COLOR_KEYS = ("key_plate_color", "key_border_color", "text_color", "key_color")


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def palette_by_name(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                out[parts[3]] = tuple(int(p) for p in parts[:3])
    return out


def fnt_chars(path):
    out = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("char "):
                for part in line.split():
                    if part.startswith("id="):
                        out.add(int(part[3:]))
    return out


def luminance(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def main():
    with open(os.path.join(REPO, "data", "help.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    gpl = os.path.join(REPO, "assets/palettes/mundo1.gpl")
    names = palette_by_name(gpl)
    pal = set(names.values())
    forbidden = {names[n] for n in FORBIDDEN if n in names}
    errs = []
    normal = dict(data.get("prompt", {}))
    reread = dict(normal)
    reread.update(data.get("reread", {}).get("prompt", {}))
    for label, cfg in (("prompt", normal), ("reread.prompt", reread)):
        for key in COLOR_KEYS:
            if key not in cfg:
                continue
            rgb = hex_rgb(cfg[key])
            if rgb not in pal:
                errs.append(f"{label}.{key} {cfg[key]} no esta en mundo1.gpl")
            if label == "reread.prompt" and rgb in forbidden:
                errs.append(f"{label}.{key} {cfg[key]} es rojo o ambar (prohibido en la Q apagada)")
    if "text_color" not in reread:
        errs.append("reread.prompt.text_color: falta (el glifo apagado)")
    else:
        glyph = names.get("banner_blanco")
        if hex_rgb(reread.get("key_color", "#f2f4f8")) != glyph:
            errs.append("reread.prompt.key_color debe ser banner_blanco (color del glifo de text_font)")
        if luminance(hex_rgb(reread["text_color"])) >= luminance(glyph) * 0.6:
            errs.append("reread.prompt.text_color no esta atenuado respecto al glifo normal")
    if int(reread.get("font_scale", 2)) >= int(normal.get("font_scale", 2)):
        errs.append("reread.prompt.font_scale debe ser menor que el de la Q normal")
    if float(reread.get("key_bob_px", 0)) != 0:
        errs.append("reread.prompt.key_bob_px debe ser 0 (apagada, sin bote)")
    still = data.get("reread", {}).get("still_s")
    if not isinstance(still, (int, float)) or still <= 0:
        errs.append("reread.still_s debe ser un numero positivo")
    chars = fnt_chars(os.path.join(REPO, normal.get("font", "res://assets/sprites/ui/text_font.fnt")
                                   .replace("res://", "", 1)))
    key = normal.get("fallback_key", "Q")
    for ch in key:
        if ord(ch) not in chars:
            errs.append(f"text_font no tiene el glifo {ch!r} de la Q")
    for e in errs:
        print("validate_help_prompt:", e)
    if not errs:
        print("validate_help_prompt: OK (Q normal y Q apagada de relectura)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
