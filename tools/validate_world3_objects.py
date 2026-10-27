#!/usr/bin/env python3
"""Valida el arte por script de los objetos y enemigos del Mundo 3 (paso 9 de docs/propuesta-mundo-3.md §8).

Para cada PNG de tools/gen_world3_objects.py y tools/gen_world3_enemies.py: existe y esta al dia con su generador,
alfa 0 o 255, no vacio, y sus colores son de assets/palettes/mundo3.gpl (paleta del mundo con su Debug), salvo el
Reflejo falso, que parte del sprite de Isak. Reglas de §6.1 sobre el dibujo: los corazones no llevan rojo de dano
(alerta, alerta_sombra) y llevan su borde blanco brillante; ningun objeto usa el ambar reservado de los puntos.
Ademas, todo tipo del Mundo 3 con help_id tiene su dibujo como origen de la ficha del album
(tools/gen_album_cards.py SOURCES).

Uso: python3 -I tools/validate_world3_objects.py   (sale con 1 si hay errores)
"""
import json
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image  # noqa: E402
import gen_album_cards as album  # noqa: E402
import gen_world3_enemies as enemies  # noqa: E402
import gen_world3_objects as objects  # noqa: E402
from gen_energy_objects import load_gpl  # noqa: E402

GPL = os.path.join(REPO, "assets", "palettes", "mundo3.gpl")
HEARTS = ("heart_pickup_00.png", "like_source_00.png", "like_platform_on_00.png", "hud_likes_00.png")


def main():
    errs = []
    pal = load_gpl(GPL)
    allowed = set(pal.values())
    red = {pal["alerta"], pal["alerta_sombra"]}
    amber = {pal["ambar"], pal["ambar_sombra"]}
    for gen, skip in ((objects, set()), (enemies, enemies.NOT_PALETTE_ONLY)):
        for name, expected in gen.outputs().items():
            rel = os.path.join(gen.OUT, name)
            path = os.path.join(REPO, rel)
            if not os.path.exists(path):
                errs.append("falta %s (python3 -I tools/%s.py)" % (rel, gen.__name__))
                continue
            img = Image.open(path).convert("RGBA")
            if img.tobytes() != expected.tobytes():
                errs.append("%s: no esta al dia con tools/%s.py" % (rel, gen.__name__))
            if any(0 < a < 255 for a in img.getchannel("A").getdata()):
                errs.append("%s: alfa distinto de 0 o 255" % rel)
            used = {c for c in img.getdata() if c[3] == 255}
            if not used:
                errs.append("%s: vacio" % rel)
            if name not in skip and not used <= allowed:
                errs.append("%s: %d colores fuera de assets/palettes/mundo3.gpl" % (rel, len(used - allowed)))
            if used & amber:
                errs.append("%s: usa el ambar reservado de los puntos de atencion" % rel)
            if name in HEARTS:
                if used & red:
                    errs.append("%s: el corazon no puede llevar el rojo de dano" % rel)
                if pal["corazon_rosa"] not in used or pal["blanco_brillante"] not in used:
                    errs.append("%s: el corazon es corazon_rosa con borde blanco_brillante" % rel)
    with open(os.path.join(REPO, "data", "world3_objects.json"), encoding="utf-8") as fh:
        types = json.load(fh)["types"]
    ids = [v.get("help_id") for v in types.values() if v.get("help_id")]
    for e in ("like_thief", "influencer_bot", "false_reflection"):
        with open(os.path.join(REPO, "data", "enemies", "%s.json" % e), encoding="utf-8") as fh:
            ids.append(json.load(fh).get("help_id"))
    for hid in ids:
        src = album.SOURCES.get(hid, ("",))[0]
        if "/world3/" not in src:
            errs.append("%s: su ficha del album no sale del arte del Mundo 3 (gen_album_cards.SOURCES)" % hid)
    print("\n".join(errs) if errs else "validate_world3_objects: OK (%d PNG)"
          % (len(objects.BUILDERS) + len(enemies.BUILDERS)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
