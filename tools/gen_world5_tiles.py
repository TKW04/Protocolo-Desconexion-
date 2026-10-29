#!/usr/bin/env python3
"""Tileset del Mundo 5 «La Tienda» por script (paso 9 de docs/propuesta-mundo-5.md §8 y §6.3).

Mismas piezas, mascaras y coordenadas de atlas que el del Mundo 1 (tools/gen_tileset_mundo1.py: el generador de
niveles y el TileSet usan las mismas reglas), repintadas con la paleta del Mundo 5 (variante elegida): baldosa
del centro comercial (gris_escaparate con juntas negro_medio) con el brillo del canto superior en gris_etiqueta y
crema_sombra, la banda de una via «estante con etiqueta» en gris_etiqueta y crema, pinchos con su rojo de dano
reservado (el unico rojo del mundo con el «Cancelar») y el decorado en los negros y el violeta de los neones.
Lo claro (crema_sombra) es solo el brillo de 1-2 px del canto: el cian de Isak contrasta >= 3:1 con el resto
(lo mide tools/validate_world5_tiles.py).

Escribe assets/sprites/tiles/mundo5_tileset.png y data/tileset_mundo5.json (mismo formato que
data/tileset_mundo1.json, con su atlas, su TileSet res://assets/tilesets/mundo5.tres y su paleta). El TileSet se
construye con Godot: $GODOT --headless --path . -s tools/build_tileset_mundo1.gd -- --map res://data/tileset_mundo5.json
(tools/level_catalog.py usa data/tileset_mundo5.json para los niveles con "world": 5).

Uso: python3 -I tools/gen_world5_tiles.py [--check]   (--check: 1 si el atlas o el JSON no estan al dia)
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
import gen_tileset_mundo1 as t1  # noqa: E402
import gen_world5_objects as obj  # noqa: E402

ATLAS_REL = os.path.join("assets", "sprites", "tiles", "mundo5_tileset.png")
MAP_REL = os.path.join("data", "tileset_mundo5.json")

## Color del Mundo 1 que pinta cada pieza del tileset -> color del Mundo 5 (por nombre).
REMAP = {
    "tile_base": "gris_escaparate",   # cuerpo del bloque: baldosa del centro comercial
    "tile_sombra": "negro_medio",     # juntas, remaches y sombra
    "tile_luz": "gris_etiqueta",      # banda del canto y laterales (estante)
    "borde_luz": "crema_sombra",      # brillo de la baldosa arriba
    "banner_gris": "gris_escaparate", # base de los pinchos
    "banner_blanco": "crema_cartel",  # etiqueta del estante
    "alerta": "alerta",               # pinchos: rojo de dano (reservado)
    "alerta_sombra": "alerta_sombra",
    "cielo": "negro_fondo",           # decorado del fondo
    "fondo_medio": "negro_medio",
    "resplandor": "violeta_neon",
}


def build():
    saved = dict(t1.P)
    t1.P.clear()
    t1.P.update({k: obj.C(v) for k, v in REMAP.items()})
    try:
        atlas, entries = t1.build()
    finally:
        t1.P.clear()
        t1.P.update(saved)
    return obj.binarize(atlas), entries


def map_data(entries):
    path = os.path.join(REPO, "data", "tileset_mundo1.json")
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    data["_notes"] = ("Tileset del Mundo 5 (generado por tools/gen_world5_tiles.py; no editar a mano). Mismas reglas, "
                      "mascaras y coordenadas de atlas que data/tileset_mundo1.json (ver sus _notes), con el atlas "
                      "assets/sprites/tiles/mundo5_tileset.png en la paleta del Mundo 5 y el TileSet "
                      "res://assets/tilesets/mundo5.tres (tools/build_tileset_mundo1.gd -- --map "
                      "res://data/tileset_mundo5.json).")
    data["atlas_png"] = "res://" + ATLAS_REL
    data["tileset"] = "res://assets/tilesets/mundo5.tres"
    data["palette"] = "res://assets/palettes/" + os.path.basename(obj.pal.GPL)   # la de la variante elegida
    if [e["atlas"] for e in data["tiles"]] != [e["atlas"] for e in entries]:
        raise SystemExit("gen_world5_tiles: data/tileset_mundo1.json no coincide con tools/gen_tileset_mundo1.py")
    return data


def map_text(entries):
    return json.dumps(map_data(entries), indent="\t", ensure_ascii=False) + "\n"


def main(argv):
    atlas, entries = build()
    text = map_text(entries)
    atlas_path, map_path = os.path.join(REPO, ATLAS_REL), os.path.join(REPO, MAP_REL)
    if "--check" in argv:
        errors = []
        if not os.path.exists(atlas_path) or Image.open(atlas_path).convert("RGBA").tobytes() != atlas.tobytes():
            errors.append("%s no esta al dia" % ATLAS_REL)
        if not os.path.exists(map_path) or open(map_path, encoding="utf-8").read() != text:
            errors.append("%s no esta al dia" % MAP_REL)
        for error in errors:
            print("gen_world5_tiles: %s (python3 -I tools/gen_world5_tiles.py)" % error, file=sys.stderr)
        return 1 if errors else 0
    atlas.save(atlas_path, optimize=True)
    with open(map_path, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(ATLAS_REL)
    print(MAP_REL)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
