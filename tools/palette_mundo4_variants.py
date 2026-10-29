"""Variantes de paleta del Mundo 4 «El Chat» (paso 10 de docs/propuesta-mundo-4.md §8 y §6.1).

Las tres usan los MISMOS nombres que la provisional del paso 0 (el juego lee los colores por nombre de la seccion
palette de data/world4_objects.json), el mismo coral del Debug (#ff9f7a, decidido por el usuario el 2026-10-28 y
fijado en data/hud.json) y reservan los del Mundo 1 que significan algo en todo el juego: alerta / alerta_sombra
(dano) y ambar / ambar_sombra (puntos de atencion). Cambian el marino, los grises, la crema y el verde apagado.
Todas cumplen las 5 reglas de §6.1 (tools/palette_mundo4_provisional.py, check_rules).

La elegida la pone --apply en ACTIVE (reescribe assets/palettes/mundo4.gpl, la seccion palette de
data/world4_objects.json y el arte por script del Mundo 4 con las fichas del album):
  python3 -I tools/palette_mundo4_variants.py --apply A|B|C
Comparativa con maqueta y medidas: docs/arte/mundo4_paleta_variantes.png
  python3 -I tools/palette_mundo4_variants.py --preview
Con --check sale con 1 si alguna variante incumple una regla o la comparativa no esta al dia.
"""
import os
import site
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
PREVIEW = os.path.join(ROOT, "docs", "arte", "mundo4_paleta_variantes.png")

## Variante que usa el juego. None = la paleta PROVISIONAL de desarrollo. La escribe --apply; no editar a mano.
ACTIVE = 'B'

## Debug del Mundo 4 (no cambia entre variantes: debug_colors["4"] de data/hud.json).
DEBUG_HEX = "ff9f7a"

## Colores que ninguna variante puede cambiar (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}

# Por variante: titulo, como resuelve las reglas de §6.1 (una linea) y los hex por nombre (16).
VARIANTS = {
    "A": {
        "title": "Madrugada marina (provisional pulida)",
        "how": "La provisional del paso 0 con el marino algo mas profundo y la crema un punto mas calida: Isak y "
               "Eco a 6,1-6,2:1 sin tocar el verde apagado; congelado a 3,5:1.",
        "hex": {
            "chat_noche": "0d1220", "marino_fondo": "182036", "marino_medio": "222e4e", "marino_luz": "324268",
            "gris_oscuro": "3a404e", "gris_medio": "6a717f", "gris_claro": "a8adba", "blanco_pantalla": "f4f6fa",
            "crema": "f0e4c8", "crema_sombra": "b9ac90", "verde_apagado": "7d9a80", "verde_sombra": "4d6452",
        },
    },
    "B": {
        "title": "Pantalla a las 3:47",
        "how": "Marino casi negro de madrugada (el chat con el brillo al minimo): Isak y Eco con el mayor "
               "contraste (6,7-6,8:1) y el mayor margen bajo los dos velos (oscuro 5,3:1, congelado 3,8:1); crema "
               "de papel algo mas clara y verde salvia apagado (22 %, lejos del acido del Mundo 3).",
        "hex": {
            "chat_noche": "0a0e1a", "marino_fondo": "141a2e", "marino_medio": "1e2844", "marino_luz": "2e3c60",
            "gris_oscuro": "373d4b", "gris_medio": "666d7c", "gris_claro": "a6abb8", "blanco_pantalla": "f6f7fb",
            "crema": "f2e8d0", "crema_sombra": "bcb098", "verde_apagado": "7f9a84", "verde_sombra": "4c6152",
        },
    },
    "C": {
        "title": "Pizarra y lino",
        "how": "Marino agrisado (pizarra) y crema de lino: la mas suave y la mas «gris» del brief, pero con el "
               "margen mas corto bajo el velo del congelado (3,2:1).",
        "hex": {
            "chat_noche": "121722", "marino_fondo": "1f2738", "marino_medio": "2a3448", "marino_luz": "3c4860",
            "gris_oscuro": "424754", "gris_medio": "727885", "gris_claro": "afb3be", "blanco_pantalla": "f2f3f6",
            "crema": "ebe2cf", "crema_sombra": "b4ab98", "verde_apagado": "7c967f", "verde_sombra": "4e6252",
        },
    },
}


def rows(variant_id, base_rows):
    """Filas (nombre, hex, funcion) de la variante con las funciones de la provisional (base_rows)."""
    hexes = dict(VARIANTS[variant_id]["hex"], **RESERVED)
    return [(name, hexes[name], role) for name, _value, role in base_rows]


def _pal():
    sys.path.insert(0, TOOLS)
    import palette_mundo4_provisional as pal
    return pal


def check_variants():
    """Errores de las variantes: nombres que faltan o sobran y reglas de §6.1 que incumplen."""
    pal = _pal()
    names = [n for n, _v, _r in pal.BASE_COLORS]
    errors = []
    for vid, v in VARIANTS.items():
        missing = set(names) - set(v["hex"]) - set(RESERVED)
        extra = set(v["hex"]) - set(names)
        if missing or extra:
            errors.append("variante %s: faltan %s / sobran %s" % (vid, sorted(missing), sorted(extra)))
            continue
        colors = rows(vid, pal.BASE_COLORS)
        for e in pal.check_rules(colors, DEBUG_HEX):
            errors.append("variante %s: %s" % (vid, e))
    return errors


def measures():
    pal = _pal()
    return {vid: pal.metrics(rows(vid, pal.BASE_COLORS), DEBUG_HEX) for vid in VARIANTS}


def preview_image():
    """Comparativa: por variante, muestras de los 16 colores + el coral y la maqueta del arte del Mundo 4."""
    sys.path.append(site.getusersitepackages())
    from PIL import Image, ImageDraw
    pal = _pal()
    sys.path.insert(0, TOOLS)
    import gen_world4_objects as art
    W, H = 1280, 3 * 300
    img = Image.new("RGBA", (W, H), (8, 8, 12, 255))
    d = ImageDraw.Draw(img)
    for k, vid in enumerate(sorted(VARIANTS)):
        colors = rows(vid, pal.BASE_COLORS) + [pal.DEBUG]
        y0 = k * 300
        hexes = {n: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for n, v, _r in colors}
        d.rectangle((0, y0, W - 1, y0 + 299), fill=hexes["marino_fondo"])
        d.rectangle((0, y0 + 220, W - 1, y0 + 299), fill=hexes["gris_oscuro"])
        d.rectangle((0, y0 + 220, W - 1, y0 + 223), fill=hexes["gris_medio"])
        for i, (name, _v, _r) in enumerate(colors):
            x = 8 + i * 30
            d.rectangle((x, y0 + 8, x + 26, y0 + 34), fill=hexes[name], outline=(0, 0, 0))
        d.text((8, y0 + 40), "%s  %s%s" % (vid, VARIANTS[vid]["title"], "  (ACTIVA)" if vid == ACTIVE else ""),
               fill=hexes["blanco_pantalla"])
        m = pal.metrics(colors[:-1], DEBUG_HEX)
        d.text((8, y0 + 54), pal.metrics_line(m), fill=hexes["gris_claro"])
        objects, enemies = art.outputs_for(colors)
        x = 8
        for name in ("chat_bubble_00.png", "chat_bubble_friend_00.png", "typing_bubble_00.png", "seen_zone_00.png",
                     "undo_prompt_00.png"):
            im = objects[name]
            img.alpha_composite(im, (x, y0 + 216 - im.height))
            x += im.width + 16
        for name in ("troll_placeholder_00.png", "ghost_00.png", "sticker_00.png", "troll_message_00.png"):
            im = enemies[name]
            img.alpha_composite(im, (x, y0 + 216 - im.height))
            x += im.width + 16
        # Modo oscuro: velo chat_noche al DARK_VEIL (93 %) con el contorno rojo de los pinchos (alerta, el del juego;
        # los enemigos no lo llevan desde el 2026-10-28, se delatan por los ojos crema) y los checks por encima.
        veil = Image.new("RGBA", (180, 140), hexes["chat_noche"] + (int(255 * pal.DARK_VEIL),))
        img.alpha_composite(veil, (W - 196, y0 + 76))
        d.rectangle((W - 170, y0 + 150, W - 140, y0 + 180), outline=hexes["alerta"], width=2)
        d.text((W - 120, y0 + 160), "vv", fill=hexes["verde_apagado"])
    return img


def write_preview(check):
    img = preview_image()
    if check:
        sys.path.append(site.getusersitepackages())
        from PIL import Image
        if not os.path.exists(PREVIEW) or Image.open(PREVIEW).convert("RGBA").tobytes() != img.tobytes():
            return ["%s no esta al dia (python3 -I tools/palette_mundo4_variants.py --preview)"
                    % os.path.relpath(PREVIEW, ROOT)]
        return []
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    img.save(PREVIEW, optimize=True)
    return []


def apply(vid):
    """Pone ACTIVE = vid aqui y regenera la paleta, el arte por script del Mundo 4 y las fichas del album."""
    if vid not in VARIANTS:
        raise SystemExit("variante desconocida: %s" % vid)
    path = os.path.abspath(__file__)
    text = open(path, encoding="utf-8").read()
    new = text.replace("\nACTIVE = %r\n" % ACTIVE, "\nACTIVE = %r\n" % vid, 1)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new)
    for cmd in (["palette_mundo4_provisional.py"], ["gen_world4_objects.py"], ["gen_album_cards.py"]):
        subprocess.run([sys.executable, "-I", os.path.join(TOOLS, cmd[0])] + cmd[1:], check=True, cwd=ROOT)
    old = os.path.join(ROOT, "assets", "palettes", "mundo4_provisional.gpl")
    if os.path.exists(old):
        os.remove(old)
    subprocess.run([sys.executable, "-I", path, "--preview"], check=True, cwd=ROOT)


def main(argv):
    if "--apply" in argv:
        apply(argv[argv.index("--apply") + 1])
        return 0
    errors = check_variants()
    if "--preview" in argv:
        errors += write_preview(False)
    if "--check" in argv:
        errors += write_preview(True)
    if "--verbose" in argv or not ("--check" in argv):
        pal = _pal()
        for vid, m in measures().items():
            print("%s: %s" % (vid, pal.metrics_line(m)))
    for e in errors:
        print("palette_mundo4_variants: " + e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
