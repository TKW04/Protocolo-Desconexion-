"""Variantes de paleta del Mundo 5 «La Tienda» (paso 9 de docs/propuesta-mundo-5.md §8 y §6.1).

Las tres usan los MISMOS nombres que la provisional del paso 0 (el juego lee los colores por nombre de la seccion
palette de data/world5_objects.json), el mismo blanco del Debug (#ffffff, decidido por el usuario el 2026-10-29 y
fijado en data/hud.json) y reservan los del Mundo 1 que significan algo en todo el juego: alerta / alerta_sombra
(dano) y ambar / ambar_sombra (puntos de atencion). Cambian los negros, los grises, la crema, el amarillo de
rebajas, el magenta y el violeta. Todas cumplen las 7 reglas de §6.1 (tools/palette_mundo5_provisional.py,
check_rules).

La elegida la pone --apply en ACTIVE (reescribe assets/palettes/mundo5.gpl, la seccion palette de
data/world5_objects.json y el arte por script del Mundo 5 con las fichas del album):
  python3 -I tools/palette_mundo5_variants.py --apply A|B|C
Comparativa con maqueta y medidas: docs/arte/mundo5_paleta_variantes.png
  python3 -I tools/palette_mundo5_variants.py --preview
Con --check sale con 1 si alguna variante incumple una regla o la comparativa no esta al dia.
--verbose imprime las medidas y el margen minimo de contraste de cada variante (el criterio de eleccion).
"""
import os
import site
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
PREVIEW = os.path.join(ROOT, "docs", "arte", "mundo5_paleta_variantes.png")

## Variante que usa el juego. None = la paleta PROVISIONAL de desarrollo. La escribe --apply; no editar a mano.
ACTIVE = 'B'

## Debug del Mundo 5 (no cambia entre variantes: debug_colors["5"] de data/hud.json).
DEBUG_HEX = "ffffff"

## Colores que ninguna variante puede cambiar (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}

# Por variante: titulo, como resuelve las reglas de §6.1 (una linea) y los hex por nombre (12).
VARIANTS = {
    "A": {
        "title": "Neón de madrugada (provisional pulida)",
        "how": "La provisional del paso 0 con los negros y los grises un punto mas violetas y la crema algo mas "
               "calida; el amarillo #ffe600 y el magenta #ff3df0 de §6.1 sin tocar.",
        "hex": {
            "tienda_noche": "0e0c14", "negro_fondo": "16121f", "negro_medio": "231c31", "gris_escaparate": "3b3449",
            "gris_etiqueta": "7b7489", "crema_cartel": "e8dfc6", "crema_sombra": "ada48e",
            "amarillo_rebajas": "ffe600", "amarillo_sombra": "a89400", "magenta_neon": "ff3df0",
            "magenta_sombra": "9a1c94", "violeta_neon": "9b5cff",
        },
    },
    "B": {
        "title": "Cierre a medianoche",
        "how": "Centro comercial con las luces de servicio: negros casi puros (el contorno y el fondo mas "
               "oscuros), crema de cartel algo mas clara (sin pasar de L* 92), el mismo amarillo y neones un punto "
               "mas vivos: el mayor contraste de Isak, del contorno sobre el amarillo y sobre el tinte.",
        "hex": {
            "tienda_noche": "08070c", "negro_fondo": "0f0d16", "negro_medio": "1b1626", "gris_escaparate": "332c40",
            "gris_etiqueta": "757087", "crema_cartel": "ece4cc", "crema_sombra": "b2aa92",
            "amarillo_rebajas": "ffe600", "amarillo_sombra": "a69200", "magenta_neon": "ff40f2",
            "magenta_sombra": "961a90", "violeta_neon": "a066ff",
        },
    },
    "C": {
        "title": "Rebajas violeta",
        "how": "Negros tenidos de violeta (la tienda iluminada por los neones) y un amarillo algo mas dorado "
               "(#ffdc00): la mas calida y la mas «neon», pero el fondo mas claro acorta el margen de Isak y el "
               "amarillo se acerca al ambar de los puntos.",
        "hex": {
            "tienda_noche": "120c1c", "negro_fondo": "1d1529", "negro_medio": "2b203d", "gris_escaparate": "453a59",
            "gris_etiqueta": "867c99", "crema_cartel": "e4dcc8", "crema_sombra": "aaa290",
            "amarillo_rebajas": "ffdc00", "amarillo_sombra": "a08a00", "magenta_neon": "f23ce6",
            "magenta_sombra": "8e1a8a", "violeta_neon": "9358f0",
        },
    },
}

## Medidas de contraste (WCAG) que exige §6.1 y su umbral: el margen de cada una es medida / umbral. El criterio
## de eleccion es el MENOR margen (la regla que la variante cumple mas justa), como en los Mundos 3 y 4.
CONTRAST_KEYS = (("cr_outline_yellow", 3.0, "contorno sobre el amarillo"),
                 ("cr_outline_tint", 3.0, "contorno sobre el tinte"),
                 ("cr_isak", 3.0, "Isak sobre el negro"),
                 ("cr_eco", 3.0, "Eco sobre el negro"))


def rows(variant_id, base_rows):
    """Filas (nombre, hex, funcion) de la variante con las funciones de la provisional (base_rows)."""
    hexes = dict(VARIANTS[variant_id]["hex"], **RESERVED)
    return [(name, hexes[name], role) for name, _value, role in base_rows]


def _pal():
    sys.path.insert(0, TOOLS)
    import palette_mundo5_provisional as pal
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
        for e in pal.check_rules(rows(vid, pal.BASE_COLORS), DEBUG_HEX):
            errors.append("variante %s: %s" % (vid, e))
    return errors


def measures():
    pal = _pal()
    return {vid: pal.metrics(rows(vid, pal.BASE_COLORS), DEBUG_HEX) for vid in VARIANTS}


def min_margin(m):
    """(margen, regla) mas justo de las medidas de contraste de §6.1."""
    return min((m[k] / t, label) for k, t, label in CONTRAST_KEYS)


def _ascii(text):
    """La fuente por defecto de PIL no tiene tildes ni «·»: se escriben sin ellas en la comparativa."""
    import unicodedata
    text = text.replace("·", "|")
    return "".join(c for c in unicodedata.normalize("NFKD", text) if ord(c) < 128)


def preview_image():
    """Comparativa: por variante, muestras de los 16 colores + el blanco y la maqueta del arte del Mundo 5 sobre
    el suelo y el fondo de la tienda, con el cian de Isak y una caja revelada por el Debug (contorno de 1 px)."""
    sys.path.append(site.getusersitepackages())
    from PIL import Image, ImageDraw
    pal = _pal()
    sys.path.insert(0, TOOLS)
    import gen_world5_objects as art
    W, H = 1280, 3 * 300
    img = Image.new("RGBA", (W, H), (8, 8, 12, 255))
    d = ImageDraw.Draw(img)
    for k, vid in enumerate(sorted(VARIANTS)):
        colors = rows(vid, pal.BASE_COLORS) + [pal.DEBUG]
        y0 = k * 300
        hexes = {n: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for n, v, _r in colors}
        d.rectangle((0, y0, W - 1, y0 + 299), fill=hexes["negro_fondo"])
        d.rectangle((0, y0 + 220, W - 1, y0 + 299), fill=hexes["gris_escaparate"])
        d.rectangle((0, y0 + 220, W - 1, y0 + 223), fill=hexes["gris_etiqueta"])
        for i, (name, _v, _r) in enumerate(colors):
            x = 8 + i * 30
            d.rectangle((x, y0 + 8, x + 26, y0 + 34), fill=hexes[name], outline=(0, 0, 0))
        d.text((8, y0 + 40), _ascii("%s  %s%s" % (vid, VARIANTS[vid]["title"], "  (ACTIVA)" if vid == ACTIVE else "")),
               fill=hexes["crema_cartel"])
        m = pal.metrics(colors[:-1], DEBUG_HEX)
        margin, rule = min_margin(m)
        d.text((8, y0 + 54), _ascii(pal.metrics_line(m)), fill=hexes["gris_etiqueta"])
        d.text((8, y0 + 68), "margen minimo de contraste x%.2f (%s)" % (margin, rule), fill=hexes["gris_etiqueta"])
        objects, enemies = art.outputs_for(colors)
        x = 8
        for name in ("shop_item_00.png", "surprise_box_00.png", "countdown_platform_00.png", "shutter_00.png",
                     "clearance_shelf_00.png", "wishlist_platform_00.png", "refund_desk_00.png"):
            im = objects[name]
            img.alpha_composite(im, (x, y0 + 220 - im.height))
            x += im.width + 8
        for name in ("offer_sign_00.png", "subscription_placeholder_00.png"):
            im = enemies[name]
            img.alpha_composite(im, (x, y0 + 220 - im.height))
            x += im.width + 10
        # Cian de Isak (los dos de su hoja) y la caja translucida que revela el Debug sobre el tinte blanco.
        for j, c in enumerate(pal.ISAK_CYANS):
            cy = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
            d.rectangle((W - 230 + j * 20, y0 + 150, W - 216 + j * 20, y0 + 216), fill=cy)
        tinted = tuple(pal.tint(hexes["amarillo_rebajas"], DEBUG_HEX))
        d.rectangle((W - 170, y0 + 140, W - 20, y0 + 216), fill=tinted)
        box = objects["surprise_box_debug_00.png"]
        img.alpha_composite(box, (W - 120, y0 + 216 - box.height))
    return img


def write_preview(check):
    img = preview_image()
    if check:
        sys.path.append(site.getusersitepackages())
        from PIL import Image
        if not os.path.exists(PREVIEW) or Image.open(PREVIEW).convert("RGBA").tobytes() != img.tobytes():
            return ["%s no esta al dia (python3 -I tools/palette_mundo5_variants.py --preview)"
                    % os.path.relpath(PREVIEW, ROOT)]
        return []
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    img.save(PREVIEW, optimize=True)
    return []


## Generadores del arte por script del Mundo 5 que dependen de la paleta (en este orden: las fichas del album
## leen los PNG de los objetos; la comparativa, al final).
REGEN = ("palette_mundo5_provisional.py", "gen_world5_objects.py", "gen_world5_tiles.py",
         "gen_world5_background.py", "gen_album_cards.py")


def apply(vid):
    """Pone ACTIVE = vid aqui y regenera la paleta, el arte por script del Mundo 5 y las fichas del album."""
    if vid not in VARIANTS:
        raise SystemExit("variante desconocida: %s" % vid)
    path = os.path.abspath(__file__)
    text = open(path, encoding="utf-8").read()
    new = text.replace("\nACTIVE = %r\n" % ACTIVE, "\nACTIVE = %r\n" % vid, 1)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new)
    for tool in REGEN:
        subprocess.run([sys.executable, "-I", os.path.join(TOOLS, tool)], check=True, cwd=ROOT)
    old = os.path.join(ROOT, "assets", "palettes", "mundo5_provisional.gpl")
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
            margin, rule = min_margin(m)
            print("%s: %s · margen minimo x%.2f (%s)" % (vid, pal.metrics_line(m), margin, rule))
    for e in errors:
        print("palette_mundo5_variants: " + e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
