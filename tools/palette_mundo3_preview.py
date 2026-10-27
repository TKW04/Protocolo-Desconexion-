#!/usr/bin/env python3
"""Comparativa de las 3 variantes de paleta del Mundo 3 «La Vitrina» (paso 9 de docs/propuesta-mundo-3.md §8) y
comando para cambiar la elegida.

Variantes en tools/palette_mundo3_variants.py (A, B, C); la primera fila de la hoja es la provisional del paso 0
(referencia). Por variante: muestras de los 17 colores, una maqueta a media escala (1 tile = 32 px) con el fondo
de la galeria (tools/gen_world3_background.py), el suelo (tools/gen_world3_tiles.py), los objetos y enemigos del
mundo (tools/gen_world3_objects.py, tools/gen_world3_enemies.py), Isak, Eco con su marco dorado, puntos de atencion
con contorno de 1 px y un pincho; la misma con el tinte del Debug; y la mitad derecha bajo el velo del flash.
Debajo de cada fila, las medidas de las 5 reglas de §6.1 y el margen minimo (cuanto pasa la regla mas justa,
en % sobre su umbral).

Uso:
  python3 -I tools/palette_mundo3_preview.py            hoja docs/arte/mundo3_paleta_variantes.png + tabla
  python3 -I tools/palette_mundo3_preview.py --table    solo la tabla comparativa (Markdown)
  python3 -I tools/palette_mundo3_preview.py --check    las 3 variantes cumplen las 5 reglas (sale con 1 si no)
  python3 -I tools/palette_mundo3_preview.py --apply B  cambia la variante del juego: ACTIVE en
      palette_mundo3_variants.py, assets/palettes/mundo3.gpl, seccion palette de data/world3_objects.json, arte por
      script del Mundo 3 (objetos, enemigos, tileset, fondo, marco de Eco) y fichas del album. Despues hay que
      reconstruir el TileSet ($GODOT --headless --path . -s tools/build_tileset_mundo1.gd -- --map
      res://data/tileset_mundo3.json) y actualizar docs/propuesta-mundo-3.md §8.1.
"""
import os
import re
import site
import subprocess
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from PIL import Image, ImageDraw  # noqa: E402
import gen_world3_background as bgmod  # noqa: E402
import gen_world3_enemies as enemies  # noqa: E402
import gen_world3_objects as objects  # noqa: E402
import gen_world3_tiles as tiles  # noqa: E402
import palette_mundo1_preview as m1  # noqa: E402
import palette_mundo3_provisional as pal  # noqa: E402
import palette_mundo3_variants as variants  # noqa: E402

OUT_DIR = os.path.join(ROOT, "docs", "arte")
OUT = os.path.join(OUT_DIR, "mundo3_paleta_variantes.png")
W, H = 640, 360
GROUND = 296
ECO = os.path.join(ROOT, "assets", "sprites", "eco", "companion", "eco_idle_00.png")

## Umbrales por regla (los de §6.1, iguales que palette_mundo3_provisional.check_rules).
RULES = {
    1: (("de_gold_amber", pal.MIN_DE_GOLD_AMBER), ("de_gold_amber_debug", pal.MIN_DE_GOLD_AMBER),
        ("de_goldlight_amber", pal.MIN_DE_GOLD_AMBER)),
    2: (("pink_l", pal.PINK_MIN_L), ("de_pink_red", pal.MIN_DE_PINK_RED), ("de_pink_carmin", pal.MIN_DE_PINK_RED),
        ("de_heart_red", pal.MIN_DE_HEART_RED)),
    3: (("cr_isak", pal.MIN_CONTRAST), ("cr_eco", pal.MIN_CONTRAST), ("cr_white_bg", pal.MIN_CONTRAST)),
    5: (("cr_flash_outline", pal.MIN_CONTRAST),),
}


def provisional_rows():
    """La provisional del paso 0 tal cual esta en el codigo (aunque haya una variante aplicada)."""
    src = open(os.path.join(TOOLS, "palette_mundo3_provisional.py"), encoding="utf-8").read()
    block = re.search(r"COLORS = \[(.*?)\n\]", src, re.S).group(1)
    return re.findall(r'\("(\w+)", "([0-9a-f]{6})", "([^"]*)"\)', block)


def options():
    """[(id, titulo, como, filas sin el Debug)]."""
    out = [("PROV", "Provisional del paso 0 (referencia)", "La de desarrollo de los pasos 0-8.", provisional_rows())]
    for vid, var in variants.VARIANTS.items():
        out.append((vid, var["title"], var["how"], variants.rows(vid, provisional_rows())))
    return out


# ------------------------------------------------------------------ medidas
def margins(rows):
    m = pal.metrics(rows, variants.DEBUG_HEX)
    per_rule = {}
    for rule, checks in RULES.items():
        per_rule[rule] = min((m[key] - limit) / limit for key, limit in checks)
    per_rule[4] = 1.0 if not m["greens"] else -1.0
    worst = min((v, r) for r, v in per_rule.items() if r != 4)
    return m, per_rule, worst


def table():
    lines = ["| Variante | Regla 1: dorado (tono, sat., ΔE puntos / con Debug) | Regla 2: rosa L, ΔE rojo; corazón ΔE "
             "| Regla 3: Isak / Eco / blanco sobre el malva | Regla 4 | Regla 5: contorno bajo el velo "
             "| Errores | Margen mínimo |",
             "|---|---|---|---|---|---|---|---|"]
    for vid, title, _how, rows in options():
        errors = pal.check_rules(rows, variants.DEBUG_HEX)
        m, per_rule, (worst, rule) = margins(rows)
        lines.append("| %s %s%s | %.0f°, %.0f %%, %.0f / %.0f | L %.0f, %.0f; %.0f | %.1f / %.1f / %.1f:1 | %s | %.1f:1 "
                     "| %s | %+.0f %% (regla %d) |"
                     % (vid, title, " **(elegida)**" if vid == variants.ACTIVE else "", m["gold_hue"],
                        m["gold_sat"] * 100, m["de_gold_amber"], m["de_gold_amber_debug"], m["pink_l"],
                        m["de_pink_red"], m["de_heart_red"], m["cr_isak"], m["cr_eco"], m["cr_white_bg"],
                        "solo el Debug" if not m["greens"] else "otros verdes", m["cr_flash_outline"],
                        len(errors), worst * 100, rule))
    return "\n".join(lines)


def check_variants():
    errors = []
    names = [n for n, _v, _r in provisional_rows()]
    for vid, var in variants.VARIANTS.items():
        if sorted(var["hex"]) != sorted(names):
            errors.append("%s: los nombres no son los de la provisional" % vid)
            continue
        for e in pal.check_rules(variants.rows(vid, provisional_rows()), variants.DEBUG_HEX):
            errors.append("%s: %s" % (vid, e))
    if variants.ACTIVE not in (None,) + tuple(variants.VARIANTS):
        errors.append("ACTIVE = %r no es una variante" % variants.ACTIVE)
    return errors


# ------------------------------------------------------------------ maqueta
class _Palette:
    """Pinta los generadores del Mundo 3 con otra paleta mientras dura el bloque."""

    def __init__(self, rows):
        self.colors = objects.palette_colors(rows + [("debug_verde", variants.DEBUG_HEX, "")])

    def __enter__(self):
        self.saved = objects.COLORS
        objects.COLORS = self.colors
        return self

    def __exit__(self, *_exc):
        objects.COLORS = self.saved


def _half(img):
    return img.resize((max(1, img.width // 2), max(1, img.height // 2)), Image.NEAREST)


def attention_point(d, cx, cy, p, r=6):
    d.polygon([(cx, cy - r - 1), (cx + r + 1, cy), (cx, cy + r + 1), (cx - r - 1, cy)], fill=p["galeria_noche"])
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=p["ambar"])


def scene(rows):
    with _Palette(rows) as ctx:
        p = ctx.colors
        img = _half(bgmod.composite()).convert("RGBA")
        atlas, _entries = tiles.build()
        top = _half(atlas.crop((64 * 6, 64, 64 * 7, 128)))    # mascara E+S+W (14): canto de marco arriba
        body = _half(atlas.crop((64 * 7, 64, 64 * 8, 128)))   # mascara 15: interior
        for x in range(0, W, 32):
            img.alpha_composite(top, (x, GROUND))
            img.alpha_composite(body, (x, GROUND + 32))
        one_way = _half(atlas.crop((64, 256, 128, 320)))
        for x in (420, 452):
            img.alpha_composite(one_way, (x, 200))
        spikes = _half(atlas.crop((256, 256, 320, 320)))
        img.alpha_composite(spikes, (360, GROUND - 32))
        art = objects.outputs()
        foes = enemies.outputs()
        img.alpha_composite(_half(art["like_source_00.png"]), (40, 150))
        img.alpha_composite(_half(art["like_platform_on_00.png"]), (180, 210))
        img.alpha_composite(_half(art["filter_zone_00.png"]), (520, GROUND - 56))
        img.alpha_composite(_half(art["mirror_00.png"]), (300, GROUND - 32))
        img.alpha_composite(_half(art["hunter_mirror_00.png"]), (470, 168))
        img.alpha_composite(_half(art["small_frame_00.png"]), (600, 120))
        for x in (110, 128, 146):
            img.alpha_composite(_half(art["heart_pickup_00.png"]), (x, 250))
        img.alpha_composite(_half(foes["like_thief_00.png"]), (400, GROUND - 24))
        img.alpha_composite(_half(foes["influencer_bot_placeholder_00.png"]), (560, GROUND - 120))
        img.alpha_composite(_half(art["hud_likes_00.png"]), (8, 8))
        isak = Image.open(m1.ISAK).convert("RGBA").resize((64, 64), Image.NEAREST)
        img.alpha_composite(isak, (230, GROUND - 64 + 6))
        eco = Image.open(ECO).convert("RGBA")
        frame = Image.new("RGBA", eco.size, (0, 0, 0, 0))
        fd = ImageDraw.Draw(frame)
        for y in range(eco.height):
            for x in range(eco.width):
                if 11.5 <= ((x + 0.5 - 16) ** 2 + (y + 0.5 - 16) ** 2) ** 0.5 < 12.5:
                    fd.point((x, y), fill=p["dorado"])
        img.alpha_composite(eco, (206, GROUND - 92))
        img.alpha_composite(frame, (206, GROUND - 92))
        d = ImageDraw.Draw(img)
        for cx, cy in ((150, 200), (330, 190), (500, 140)):
            attention_point(d, cx, cy, p)
    return img


def veiled(img, rows):
    """Mitad derecha bajo el velo del flash (70 % de blanco_brillante) con lo que dana contorneado."""
    p = {n: m1.hx(v) for n, v, _ in rows}
    out = img.copy()
    veil = Image.new("RGBA", (W // 2, H), p["blanco_brillante"] + (round(255 * pal.FLASH_VEIL),))
    out.alpha_composite(veil, (W // 2, 0))
    d = ImageDraw.Draw(out)
    d.rectangle((358, GROUND - 34, 393, GROUND - 1), outline=p["alerta_sombra"], width=2)   # pincho
    d.rectangle((398, GROUND - 26, 425, GROUND - 1), outline=p["alerta_sombra"], width=2)   # ladron
    return out


def build():
    pad, label_h, sw_h = 16, 74, 30
    opts = options()
    row_h = label_h + sw_h + H + pad
    width = pad * 4 + W * 3
    sheet = Image.new("RGB", (width, 64 + row_h * len(opts)), (18, 14, 22))
    d = ImageDraw.Draw(sheet)
    state = "elegida la %s" % variants.ACTIVE if variants.ACTIVE else "sin elegir"
    d.text((pad, 10), "Mundo 3 «La Vitrina»: variantes de paleta (%s)" % state, font=m1.font(20, True),
           fill=(245, 238, 250))
    d.text((pad, 38), "Columnas: maqueta · con el tinte del Debug (verde ácido) · mitad derecha bajo el velo del "
           "flash del Influencer (70 %, contorno de lo que daña en alerta_sombra).", font=m1.font(13),
           fill=(200, 190, 210))
    for i, (vid, title, how, rows) in enumerate(opts):
        y = 64 + i * row_h
        errors = pal.check_rules(rows, variants.DEBUG_HEX)
        m, _per, (worst, rule) = margins(rows)
        mark = "  (ELEGIDA)" if vid == variants.ACTIVE else ""
        d.text((pad, y), "%s · %s%s" % ("Provisional" if vid == "PROV" else "Variante " + vid, title, mark),
               font=m1.font(17, True), fill=(255, 255, 255))
        d.text((pad, y + 22), how, font=m1.font(12), fill=(205, 196, 215))
        d.text((pad, y + 38), pal.metrics_line(m), font=m1.font(12), fill=(170, 230, 190))
        d.text((pad, y + 54), "Reglas: %s · margen mínimo %+.0f %% (regla %d)"
               % ("todas" if not errors else "%d errores" % len(errors), worst * 100, rule),
               font=m1.font(12), fill=(170, 230, 190) if not errors else (255, 140, 120))
        sx = pad
        for _name, value, _r in rows + [("debug_verde", variants.DEBUG_HEX, "")]:
            d.rectangle((sx, y + label_h, sx + 40, y + label_h + 22), fill=m1.hx(value), outline=(60, 52, 70))
            sx += 44
        normal = scene(rows)
        py = y + label_h + sw_h
        sheet.paste(normal.convert("RGB"), (pad, py))
        sheet.paste(m1.apply_debug(normal, variants.DEBUG_HEX).convert("RGB"), (pad * 2 + W, py))
        sheet.paste(veiled(normal, rows).convert("RGB"), (pad * 3 + W * 2, py))
    os.makedirs(OUT_DIR, exist_ok=True)
    gdignore = os.path.join(OUT_DIR, ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()
    sheet.save(OUT, optimize=True)


# ------------------------------------------------------------------ cambiar la elegida
def apply(vid):
    if vid not in variants.VARIANTS:
        print("palette_mundo3_preview: variante desconocida %r (hay %s)" % (vid, ", ".join(variants.VARIANTS)),
              file=sys.stderr)
        return 2
    path = os.path.join(TOOLS, "palette_mundo3_variants.py")
    src = open(path, encoding="utf-8").read()
    src = re.sub(r"^ACTIVE = .*$", 'ACTIVE = "%s"' % vid, src, count=1, flags=re.M)
    open(path, "w", encoding="utf-8").write(src)
    for cmd in (["tools/palette_mundo3_provisional.py"], ["tools/gen_world3_objects.py"],
                ["tools/gen_world3_enemies.py"], ["tools/gen_world3_tiles.py"], ["tools/gen_world3_background.py"],
                ["tools/gen_eco_companion.py"], ["tools/gen_album_cards.py"],
                ["tools/palette_mundo3_provisional.py", "--check"]):
        result = subprocess.run([sys.executable, "-I"] + cmd, cwd=ROOT)
        if result.returncode != 0:
            print("palette_mundo3_preview: fallo %s" % " ".join(cmd), file=sys.stderr)
            return result.returncode
    print("Variante %s aplicada. Reconstruye el TileSet (tools/build_tileset_mundo1.gd -- --map "
          "res://data/tileset_mundo3.json), regenera la hoja (este script) y revisa tools/run_tests.sh." % vid)
    return 0


def main(argv):
    if "--apply" in argv:
        i = argv.index("--apply")
        return apply(argv[i + 1] if i + 1 < len(argv) else "")
    errors = check_variants()
    for error in errors:
        print("palette_mundo3_preview: " + error, file=sys.stderr)
    if "--check" in argv:
        return 1 if errors else 0
    print(table())
    if "--table" not in argv:
        build()
        print(os.path.relpath(OUT, ROOT))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
