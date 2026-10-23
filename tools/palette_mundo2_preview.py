#!/usr/bin/env python3
"""Comparativa de las variantes de paleta del Mundo 2 «El Feed» (paso 10 de docs/propuesta-mundo-2.md, fase A)
y comando para aplicar la elegida (fase B).

Variantes en tools/palette_mundo2_variants.py (A, B, C). La primera fila de la imagen es la paleta ACTUAL de
desarrollo (tools/palette_mundo2_provisional.py) con el Debug que pinta hoy el juego en el Mundo 2
(debug_colors["2"] de data/hud.json), como referencia del problema.

Por variante: muestras de los 17 colores, una maqueta a media escala (1 tile = 32 px) con los dibujos del Mundo 2
que ya existen (tools/gen_world2_cards.py: tarjetas, Historia, cartel del bucle, video en autoplay, clon,
Comentarista, muro «Cargando mas...», reproductor) mas Isak, puntos de atencion con contorno de 1 px, el borde que
dana y el HUD (bateria en el color del Debug); la misma maqueta con el tinte del Debug (el del shader, reproducido
por tools/palette_mundo1_preview.py) y una tarjeta oculta revelada; y dos ampliaciones x2 de los choques
(punto de atencion junto al contorno del Debug, con el tinte; Historia magenta junto al rojo de dano).

Uso:
  python3 -I tools/palette_mundo2_preview.py            imagen docs/arte/mundo2_paleta_variantes.png + medidas
  python3 -I tools/palette_mundo2_preview.py --check    solo las reglas de las variantes (sale con 1 si falla)
  python3 -I tools/palette_mundo2_preview.py --apply B  FASE B: aplica la variante B (no lo ejecutes sin que el
      usuario la haya elegido): ACTIVE en palette_mundo2_variants.py, assets/palettes/mundo2.gpl, seccion palette
      de data/world2_objects.json, debug_colors["2"] de data/hud.json, dibujos de assets/sprites/props/world2/ y
      fichas del album; borra assets/palettes/mundo2_provisional.gpl.
"""
import json
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
import gen_world2_cards as cards  # noqa: E402
import palette_mundo1_preview as m1  # noqa: E402
import palette_mundo2_provisional as pal  # noqa: E402
import palette_mundo2_variants as variants  # noqa: E402

OUT_DIR = os.path.join(ROOT, "docs", "arte")
OUT = os.path.join(OUT_DIR, "mundo2_paleta_variantes.png")
HUD = os.path.join(ROOT, "data", "hud.json")
W, H = 640, 360           # maqueta a media escala (1280 x 720 del juego / 2)
GROUND = 328              # y del suelo (1 tile = 32 px)
HIDDEN = (64, 232, 127, 247)   # tarjeta oculta (solo con el Debug)
CLASH_DEBUG = (40, 196, 200, 286)   # recorte x2: punto de atencion junto al contorno del Debug
CLASH_RED = (140, 250, 300, 340)    # recorte x2: Historia magenta junto al rojo de dano

def hx(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def provisional_rows():
    """Paleta provisional tal cual esta en el codigo de palette_mundo2_provisional.py (aunque haya una variante
    aplicada, que sustituye pal.COLORS al importarlo)."""
    src = open(os.path.join(TOOLS, "palette_mundo2_provisional.py"), encoding="utf-8").read()
    colors = re.search(r"COLORS = \[(.*?)\n\]", src, re.S).group(1)
    debug = re.search(r'DEBUG = \("debug_ambar", "([0-9a-f]{6})"', src).group(1)
    rows = re.findall(r'\("(\w+)", "([0-9a-f]{6})", "([^"]*)"\)', colors)
    return rows + [("debug_ambar", debug, pal.DEBUG[2])]


def hud_debug_w2():
    with open(HUD, encoding="utf-8") as fh:
        return json.load(fh)["debug_colors"]["2"].lstrip("#").lower()


def options():
    """(id, titulo, como, filas, hex del Debug que se ve en el juego)."""
    out = [("ACTUAL", "Provisional de desarrollo (referencia)",
            "Hoy: el juego tiñe el Debug del Mundo 2 con #%s (data/hud.json), casi el mismo tono que los puntos; "
            "la paleta provisional propone #%s." % (hud_debug_w2(), provisional_rows()[-1][1]),
            provisional_rows(), hud_debug_w2())]
    for vid, var in variants.VARIANTS.items():
        rows = variants.rows(vid, provisional_rows())
        out.append((vid, var["title"], var["how"], rows, var["hex"]["debug_ambar"]))
    return out


# ------------------------------------------------------------------ medidas
def metrics(rows, debug_hex):
    p = {n: hx(v) for n, v, _ in rows}
    dbg = hx(debug_hex)
    point_tinted = m1.tint_px(p["ambar"], 0.0, debug_hex)
    medio_tinted = m1.tint_px(p["feed_medio"], 0.0, debug_hex)
    return {
        "hue_debug": m1.hue(dbg), "hue_ambar": m1.hue(p["ambar"]), "hue_magenta": m1.hue(p["magenta"]),
        "de_debug_ambar": m1.de(dbg, p["ambar"]),
        "de_debug_punto_tenido": m1.de(dbg, point_tinted),
        "de_debug_alerta": m1.de(dbg, p["alerta"]),
        "de_magenta_alerta": m1.de(p["magenta"], p["alerta"]),
        "cr_debug_medio_tenido": m1.ratio(dbg, medio_tinted),
        # El cuerpo de Isak es oscuro a proposito (chaqueta gris): lo que lo despega del fondo es el cian.
        "cr_isak_fondo": min(m1.ratio(hx(c), p[b]) for c in m1.ISAK_CYANS for b in ("feed_fondo", "feed_medio")),
        "cr_punto_fondo": m1.ratio(p["ambar"], p["feed_fondo"]),
    }


def metrics_line(m):
    return ("Debug %d° / puntos %d°: ΔE %.0f (con tinte %.0f) · Debug-rojo ΔE %.0f · magenta %d° - rojo ΔE %.0f · "
            "contorno Debug/fondo tenido %.1f:1 · cian de Isak/fondo >= %.1f:1"
            % (m["hue_debug"], m["hue_ambar"], m["de_debug_ambar"], m["de_debug_punto_tenido"],
               m["de_debug_alerta"], m["hue_magenta"], m["de_magenta_alerta"], m["cr_debug_medio_tenido"],
               m["cr_isak_fondo"]))


def check_variants():
    errors = []
    for vid, var in variants.VARIANTS.items():
        hexes = var["hex"]
        names = [n for n, _v, _r in provisional_rows()]
        if sorted(hexes) != sorted(names):
            errors.append("%s: los nombres no son los de la provisional" % vid)
            continue
        for name, value in variants.RESERVED.items():
            if hexes[name] != value:
                errors.append("%s: %s esta reservado (#%s)" % (vid, name, value))
        m = metrics(variants.rows(vid, provisional_rows()), hexes["debug_ambar"])
        if not 300.0 <= pal.hue_deg(hexes["magenta"]) <= 315.0:
            errors.append("%s: el magenta debe ser violaceo (300-315 grados)" % vid)
        if not pal.hue_deg(hexes["debug_ambar"]) < pal.hue_deg(hexes["ambar"]):
            errors.append("%s: el Debug debe ser mas anaranjado que los puntos" % vid)
        if m["de_debug_ambar"] < 10.0:
            errors.append("%s: Debug y puntos demasiado parecidos (ΔE %.1f < 10)" % (vid, m["de_debug_ambar"]))
        if m["de_magenta_alerta"] < 40.0:
            errors.append("%s: magenta y rojo de dano demasiado parecidos (ΔE %.1f)" % (vid, m["de_magenta_alerta"]))
        if m["cr_isak_fondo"] < 3.0:
            errors.append("%s: el cian de Isak sobre el fondo < 3:1 (%.2f)" % (vid, m["cr_isak_fondo"]))
    return errors


# ------------------------------------------------------------------ maqueta
def card_tile(d, x, y, w, p):
    d.rectangle((x, y, x + w - 1, y + 31), fill=p["tarjeta_base"])
    d.rectangle((x + 2, y, x + w - 3, y + 1), fill=p["tarjeta_borde"])
    d.rectangle((x + 1, y + 2, x + w - 2, y + 4), fill=p["tarjeta_luz"])
    d.rectangle((x, y + 29, x + w - 1, y + 31), fill=p["tarjeta_sombra"])
    for k in range(x, x + w, 64):
        d.line((k, y + 2, k, y + 31), fill=p["tarjeta_sombra"])


def attention_point(d, cx, cy, p, r=6):
    d.polygon([(cx, cy - r - 1), (cx + r + 1, cy), (cx, cy + r + 1), (cx - r - 1, cy)], fill=p["feed_noche"])
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=p["ambar"])
    d.line((cx, cy + 1, cx + r - 1, cy), fill=p["ambar_sombra"])


def scene(rows):
    p = {n: hx(v) + (255,) for n, v, _ in rows}
    sprites = cards.outputs_for(rows)
    img = Image.new("RGBA", (W, H), p["feed_fondo"])
    d = ImageDraw.Draw(img)
    for i, name in enumerate(("feed_noche", "feed_noche", "feed_fondo")):
        d.rectangle((0, i * 16, W, i * 16 + 15), fill=p[name])
    d.rectangle((0, 0, W, 9), fill=p["feed_noche"])
    for x, y, w, h in ((12, 64, 120, 150), (176, 30, 100, 120), (330, 90, 110, 160), (470, 150, 150, 120)):
        d.rectangle((x - 2, y - 2, x + w + 1, y + h + 1), fill=p["feed_resplandor"])
        d.rectangle((x, y, x + w - 1, y + h - 1), fill=p["feed_medio"])
        d.rectangle((x + 8, y + h - 14, x + w - 9, y + h - 12), fill=p["feed_fondo"])
    card_tile(d, 0, GROUND, W, p)
    # tarjetas de plataforma
    img.alpha_composite(sprites["story_card_00.png"], (160, 280))
    img.alpha_composite(sprites["fragile_card_00.png"], (300, 232))
    img.alpha_composite(sprites["loop_sign_00.png"], (300, 40))
    img.alpha_composite(sprites["autoplay_video_00.png"], (36, 120))
    img.alpha_composite(sprites["pause_player_00.png"], (520, 60))
    img.alpha_composite(sprites["video_clone_00.png"], (380, GROUND - 40))
    img.alpha_composite(sprites["commenter_00.png"], (450, GROUND - 56))
    img.alpha_composite(sprites["loading_wall_00.png"], (590, GROUND - 96))
    isak = Image.open(m1.ISAK).convert("RGBA")
    isak = isak.resize((64, 64), Image.NEAREST)
    img.alpha_composite(isak, (236, GROUND - 64 + 6))
    for cx, cy in ((150, 222), (332, 212), (520, 200)):
        attention_point(d, cx, cy, p)
    # borde que dana (franja roja con muescas), abajo de la vista
    d.rectangle((0, H - 8, W, H - 1), fill=p["alerta"])
    d.rectangle((0, H - 8, W, H - 7), fill=p["alerta_sombra"])
    for k in range(0, W, 16):
        d.polygon([(k, H - 8), (k + 8, H - 14), (k + 16, H - 8)], fill=p["alerta"])
    # punto rojo de dano junto a la Historia (aviso del video en rojo)
    d.rectangle((236, 286, 251, 301), fill=p["alerta_sombra"])
    d.rectangle((238, 288, 249, 299), fill=p["alerta"])
    return img


def hud(img, rows, debug_hex):
    p = {n: hx(v) + (255,) for n, v, _ in rows}
    dbg = hx(debug_hex) + (255,)
    d = ImageDraw.Draw(img)
    d.rectangle((8, 8, 92, 24), fill=p["feed_noche"])
    d.rectangle((10, 10, 76, 22), outline=dbg)
    d.rectangle((77, 13, 79, 19), fill=dbg)
    for i in range(4):
        d.rectangle((13 + i * 16, 13, 25 + i * 16, 19), fill=dbg)
    d.rectangle((100, 8, 140, 24), fill=p["feed_noche"])
    attention_point(d, 112, 16, p, 5)
    d.rectangle((122, 13, 124, 19), fill=p["blanco"])
    d.rectangle((128, 13, 134, 19), fill=p["blanco"])


def debug_view(normal, rows, debug_hex):
    p = {n: hx(v) for n, v, _ in rows}
    out = m1.apply_debug(normal, debug_hex).convert("RGBA")
    dbg = hx(debug_hex)
    x0, y0, x1, y1 = HIDDEN
    over = Image.new("RGBA", out.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    od.rectangle((x0 - 2, y0 - 2, x1 + 2, y1 + 2), outline=p["feed_noche"] + (255,), width=1)
    od.rectangle((x0, y0, x1, y1), fill=dbg + (64,))
    od.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), outline=dbg + (255,), width=1)
    out.alpha_composite(over)
    return out


# ------------------------------------------------------------------ hoja
def build():
    pad, label_h, sw_h = 16, 58, 30
    zoom_w = (CLASH_DEBUG[2] - CLASH_DEBUG[0]) * 2
    row_h = label_h + sw_h + H + pad
    opts = options()
    width = pad + W + pad + W + pad + zoom_w + pad
    head_h = 64
    sheet = Image.new("RGB", (width, head_h + row_h * len(opts)), (16, 14, 22))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), "Mundo 2 «El Feed»: variantes de paleta (PROPUESTA, sin elegir)", font=m1.font(20, True),
           fill=(240, 236, 250))
    d.text((pad, 38), "Columnas: maqueta normal · con el Debug (tinte + tarjeta oculta revelada) · choques x2 "
           "(arriba: punto de atención junto al contorno del Debug; abajo: Historia magenta junto al rojo de daño).",
           font=m1.font(13), fill=(190, 186, 205))
    report = []
    for i, (vid, title, how, rows, debug_hex) in enumerate(opts):
        y = head_h + i * row_h
        m = metrics(rows, debug_hex)
        report.append((vid, title, debug_hex, m))
        d.text((pad, y), "%s · %s" % (vid if vid == "ACTUAL" else "Variante " + vid, title),
               font=m1.font(17, True), fill=(255, 255, 255))
        d.text((pad, y + 22), how, font=m1.font(12), fill=(200, 196, 215))
        d.text((pad, y + 38), metrics_line(m), font=m1.font(12), fill=(170, 230, 190))
        sx = pad
        swatch_rows = rows[:-1] + [("debug_ambar", debug_hex, "")]
        for name, value, _r in swatch_rows:
            d.rectangle((sx, y + label_h, sx + 44, y + label_h + 22), fill=hx(value), outline=(60, 56, 72))
            sx += 48
        d.text((sx + 4, y + label_h + 4), "(último: Debug)", font=m1.font(12), fill=(170, 166, 185))
        normal = scene(rows)
        dbg = debug_view(normal, rows, debug_hex)
        hud(normal, rows, debug_hex)
        hud(dbg, rows, debug_hex)
        py = y + label_h + sw_h
        sheet.paste(normal.convert("RGB"), (pad, py))
        sheet.paste(dbg.convert("RGB"), (pad * 2 + W, py))
        zx = pad * 3 + 2 * W
        z1 = dbg.crop(CLASH_DEBUG).resize((zoom_w, (CLASH_DEBUG[3] - CLASH_DEBUG[1]) * 2), Image.NEAREST)
        z2 = normal.crop(CLASH_RED).resize((zoom_w, (CLASH_RED[3] - CLASH_RED[1]) * 2), Image.NEAREST)
        sheet.paste(z1.convert("RGB"), (zx, py))
        sheet.paste(z2.convert("RGB"), (zx, py + z1.size[1]))
    os.makedirs(OUT_DIR, exist_ok=True)
    gdignore = os.path.join(OUT_DIR, ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()
    sheet.save(OUT, optimize=True)
    return report


# ------------------------------------------------------------------ fase B
def apply(vid):
    if vid not in variants.VARIANTS:
        print("palette_mundo2_preview: variante desconocida %r (hay %s)" % (vid, ", ".join(variants.VARIANTS)),
              file=sys.stderr)
        return 2
    path = os.path.join(TOOLS, "palette_mundo2_variants.py")
    src = open(path, encoding="utf-8").read()
    src = re.sub(r"^ACTIVE = .*$", 'ACTIVE = "%s"' % vid, src, count=1, flags=re.M)
    open(path, "w", encoding="utf-8").write(src)
    debug = "#" + variants.VARIANTS[vid]["hex"]["debug_ambar"]
    hud_text = open(HUD, encoding="utf-8").read()
    hud_text, n = re.subn(r'("debug_colors":\s*\{[^}]*?"2":\s*")#[0-9a-fA-F]{6}', r"\g<1>" + debug, hud_text)
    if n != 1:
        print("palette_mundo2_preview: no encuentro debug_colors[\"2\"] en data/hud.json", file=sys.stderr)
        return 1
    open(HUD, "w", encoding="utf-8").write(hud_text)
    for cmd in (["tools/palette_mundo2_provisional.py"], ["tools/gen_world2_cards.py"],
                ["tools/gen_album_cards.py"], ["tools/palette_mundo2_provisional.py", "--check"],
                ["tools/gen_world2_cards.py", "--check"]):
        result = subprocess.run([sys.executable, "-I"] + cmd, cwd=ROOT)
        if result.returncode != 0:
            print("palette_mundo2_preview: fallo %s" % " ".join(cmd), file=sys.stderr)
            return result.returncode
    if os.path.exists(pal.PROVISIONAL_GPL):
        os.remove(pal.PROVISIONAL_GPL)
    print("Variante %s aplicada. Revisa: python3 -I tools/validate_album_cards.py y tools/run_tests.sh; "
          "actualiza docs/propuesta-mundo-2.md §6.1/§8.1 y los textos que digan PROVISIONAL." % vid)
    return 0


def main(argv):
    if "--apply" in argv:
        i = argv.index("--apply")
        return apply(argv[i + 1] if i + 1 < len(argv) else "")
    errors = check_variants()
    for error in errors:
        print("palette_mundo2_preview: " + error, file=sys.stderr)
    if "--check" in argv:
        return 1 if errors else 0
    for vid, title, debug_hex, m in build():
        print("%-6s %-38s Debug #%s  %s" % (vid, title, debug_hex, metrics_line(m)))
    print(os.path.relpath(OUT, ROOT))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
