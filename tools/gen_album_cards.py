#!/usr/bin/env python3
"""Genera las fichas del album de Notas a partir de los sprites que ya existen.

docs/propuesta-asistentes-y-vidas.md §3.5 y §9: una ficha por tipo de ayuda
(data/help.json) con el primer cuadro de su sprite. Se recorta al contenido
opaco y, si pasa de MAX px, se reduce por un factor entero (cada bloque toma su
color opaco mas frecuente: no aparecen colores nuevos). La ficha queda centrada
en un lienzo de MAX x MAX px (px de pantalla: el album la dibuja a x1 en la
rejilla y a x2 en la vista de ficha). La silueta «???» es el mismo dibujo
relleno en `sombra` de assets/palettes/hub.gpl con un contorno de 1 px en
`base` (para que se lea sobre la celda oscura); el «???» lo escribe el album
con la fuente de textos.

Salidas (assets/sprites/ui/album/):
  album_card_<tipo>.png             ficha desbloqueada  64x64
  album_card_<tipo>_silhouette.png  silueta             64x64

Uso (desde la raiz del repo): python3 -I tools/gen_album_cards.py [--dry-run]
       [--preview <png>]
Validador: tools/validate_album_cards.py.
"""
import json
import os
import site
import sys
from collections import Counter

sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "assets/sprites/ui/album"
MAX = 64

# Tipo -> (PNG de origen, recorte del primer cuadro (x0, y0, x1, y1) o None, escala
# entera previa). attention_point se dibuja en el juego con el color del icono de
# puntos del HUD: su ficha es el icono del HUD a x2.
SOURCES = {
    "alert_bubble": ("assets/sprites/enemies/bubble_idle_00.png", None, 1),
    "attention_point": ("assets/sprites/ui/hud_attention.png", None, 2),
    "receiver": ("assets/sprites/tiles/mundo1_receiver.png", (0, 0, 64, 64), 1),
    "bridge": ("assets/sprites/tiles/mundo1_bridge.png", (0, 0, 64, 64), 1),
    "popup_blocker": ("assets/sprites/tiles/mundo1_popup.png", (0, 0, 192, 192), 1),
    "power_bank_pickup": ("assets/sprites/pickups/power_bank_full_00.png", None, 1),
    "sync_point": ("assets/sprites/tiles/mundo1_checkpoint.png", (64, 0, 128, 128), 1),
    "ability_pickup": ("assets/sprites/pickups/ability_pickup_idle_00.png", None, 1),
    "charger": ("assets/sprites/props/charger_ready_00.png", None, 1),
    "energy_drop": ("assets/sprites/pickups/energy_drop_idle_00.png", None, 2),
    "sync_drop": ("assets/sprites/pickups/sync_drop_idle_00.png", None, 2),
    "exit_terminal": ("assets/sprites/props/exit_terminal/terminal_prompt_00.png", None, 1),
    "glitch_wall": ("assets/sprites/tiles/mundo1_glitch_wall.png", (0, 0, 64, 64), 1),
    "extra_life": ("assets/sprites/pickups/extra_life_idle_00.png", None, 2),
    # Acertijo «Correo certificado» y chip del Debug del 1-2 (tools/gen_world1_puzzle.py).
    "laser_receiver": ("assets/sprites/props/laser_receiver_powered_00.png", None, 1),
    "relay_receiver": ("assets/sprites/props/relay_receiver_powered_00.png", None, 1),
    "ad_cover": ("assets/sprites/props/ad_cover_intact_00.png", None, 1),
    "debug_chip": ("assets/sprites/pickups/debug_chip_idle_00.png", None, 1),
    # Enemigos del 1-2 (tools/gen_world1_enemies.py): punto rojo despierto y el banner barriendo.
    "notification_badge": ("assets/sprites/enemies/badge_chase_00.png", None, 1),
    "spam_banner": ("assets/sprites/enemies/banner_sweep_00.png", None, 1),
}


def load_gpl(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            p = line.split()
            if len(p) >= 4 and all(v.isdigit() for v in p[:3]):
                out[p[3]] = tuple(int(v) for v in p[:3]) + (255,)
    return out


HUB = load_gpl(os.path.join(REPO, "assets", "palettes", "hub.gpl"))
SHADOW = HUB["sombra"]
OUTLINE = HUB["base"]


def help_types():
    with open(os.path.join(REPO, "data", "help.json"), encoding="utf-8") as fh:
        return list(json.load(fh)["types"].keys())


def reduce(img, factor):
    """Reduce por `factor` entero: cada bloque toma su color opaco mas frecuente
    si al menos la mitad del bloque es opaco; si no, transparente."""
    w, h = img.width // factor, img.height // factor
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            colors = Counter()
            for j in range(factor):
                for i in range(factor):
                    c = src[x * factor + i, y * factor + j]
                    if c[3] == 255:
                        colors[c] += 1
            if sum(colors.values()) * 2 >= factor * factor:
                dst[x, y] = colors.most_common(1)[0][0]
    return out


def card(help_type):
    path, box, scale = SOURCES[help_type]
    img = Image.open(os.path.join(REPO, path)).convert("RGBA")
    if box:
        img = img.crop(box)
    # Solo alfa 0 o 255 (los sprites ya lo cumplen; por si acaso).
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if 0 < px[x, y][3] < 255:
                px[x, y] = px[x, y][:3] + (255,) if px[x, y][3] >= 128 else (0, 0, 0, 0)
    img = img.crop(img.getbbox())
    if scale > 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    factor = 1
    while img.width / factor > MAX or img.height / factor > MAX:
        factor += 1
    if factor > 1:
        img = reduce(img, factor)
        img = img.crop(img.getbbox())
    out = Image.new("RGBA", (MAX, MAX), (0, 0, 0, 0))
    out.alpha_composite(img, ((MAX - img.width) // 2, (MAX - img.height) // 2))
    return out


def silhouette(img):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 255:
                dst[x, y] = SHADOW
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 255:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = x + dx, y + dy
                if 0 <= qx < w and 0 <= qy < h and src[qx, qy][3] == 255:
                    dst[x, y] = OUTLINE
                    break
    return out


def outputs():
    """{nombre de archivo: imagen} (orden estable). Tipos de help.json sin
    sprite en SOURCES no tienen ficha (el album dibuja solo el «???»/nombre)."""
    out = {}
    for t in help_types():
        if t not in SOURCES:
            continue
        im = card(t)
        out[f"album_card_{t}.png"] = im
        out[f"album_card_{t}_silhouette.png"] = silhouette(im)
    return out


def main(argv):
    imgs = outputs()
    if "--dry-run" not in argv:
        os.makedirs(os.path.join(REPO, OUT), exist_ok=True)
        for k, im in imgs.items():
            im.save(os.path.join(REPO, OUT, k), optimize=True)
    if "--preview" in argv:
        names = sorted(imgs)
        sheet = Image.new("RGBA", (len(names) * 140 + 10, 150), HUB["fondo_profundo"])
        for i, k in enumerate(names):
            im = imgs[k].resize((128, 128), Image.NEAREST)
            sheet.alpha_composite(im, (10 + i * 140, 10))
        sheet.save(argv[argv.index("--preview") + 1])
    print(f"{len(imgs)} PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
