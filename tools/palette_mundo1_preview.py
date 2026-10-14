"""Paleta DEFINITIVA del Mundo 1 (aprobada 2026-10-14, variante B del paso 10).

Genera:
  assets/palettes/mundo1.gpl            16 colores del mundo + debug_cian aparte
  assets/palettes/mundo1_paleta.png     muestras con nombre y funcion
  assets/palettes/mundo1_maqueta.png    1280x1440: arriba normal, abajo con el
      tinte del Debug reproducido de assets/shaders/debug_overlay.gdshader
  assets/palettes/mundo1_debug_cian_comparativa.png  candidatos del cian del
      Debug sobre la maqueta tenida (Isak real, plataforma oculta con contorno,
      punto debil sobre el tinte, bateria del HUD)
e imprime los contrastes y distancias de color medidos.

Uso: python3 tools/palette_mundo1_preview.py
"""
import colorsys
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL_DIR = os.path.join(ROOT, "assets", "palettes")
ISAK = os.path.join(ROOT, "assets", "sprites", "isak", "isak_idle_00.png")

## Cian del Debug del Mundo 1 (decision 2026-10-14): mas verdoso y claro que el
## cian de la ropa de Isak (#29defa) para no confundirse con el ni con los azules.
DEBUG_CYAN = ("debug_cian", "3dfff5", "Color del Debug (tinte, contornos de plataformas ocultas, bateria "
              "y anillo de carga del HUD). Aparte de los 16.")
## Cian anterior (paso 10) y candidatos evaluados en la comparativa.
OLD_DEBUG_CYAN = "4fe3ff"
CYAN_CANDIDATES = ["00f5ff", "3dfff5", "00ffe1"]
## Cianes de la ropa de Isak (hoja importada).
ISAK_CYANS = ["29defa", "36c0d4"]

TITLE = "Noche con resplandor de pantalla (DEFINITIVA)"
# (nombre, hex, funcion)
COLORS = [
    ("noche_profunda", "0b0e1a", "Cielo superior, fondo del HUD/UI, contorno oscuro y halo de lo oculto"),
    ("cielo", "1c2a58", "Fondo lejano (cielo nocturno, más claro)"),
    ("fondo_medio", "2e4688", "Fondo medio: siluetas de relojes/pantalla de bloqueo"),
    ("resplandor", "4f71c4", "Resplandor de pantalla tras la zona de juego"),
    ("tile_sombra", "0c1022", "Tile sólido: sombra/interior profundo"),
    ("tile_base", "1a2138", "Tile sólido: base (más oscuro que el fondo)"),
    ("tile_luz", "343f66", "Tile sólido: luz/bisel"),
    ("borde_luz", "9bb0e8", "Borde superior de tiles y plataforma de una vía"),
    ("banner_blanco", "f2f4f8", "Banners/pop-ups, texto del HUD, brillo de borde"),
    ("banner_gris", "aeb8d2", "Sombra de banners, metal de pinchos"),
    ("alerta", "ff4a2a", "Rojo anaranjado: burbujas de alerta, badges, puntas de pinchos, daño"),
    ("alerta_sombra", "a3221c", "Sombra/contorno de lo rojo anaranjado"),
    ("carmin", "e0004a", "Punto débil del jefe (carmín puro, solo con Debug, por encima del tinte)"),
    ("carmin_brillo", "ff5a8c", "Pulso/brillo del punto débil"),
    ("ambar", "ffa000", "Puntos de atención, icono del HUD (ámbar: sigue dorado bajo el tinte)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atención"),
]


def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def rel_lum(c):
    return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])


def ratio(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def lab(c):
    r, g, b = (lin(v) for v in c)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def de(a, b):
    """Delta E CIE76 (Lab)."""
    return math.dist(lab(a), lab(b))


def hue(c):
    return round(colorsys.rgb_to_hsv(*(v / 255 for v in c))[0] * 360)


def hexs(c):
    return "#" + "".join("%02x" % v for v in c)


# --- Tinte del Debug (assets/shaders/debug_overlay.gdshader + data/debug_mode.json) ---
with open(os.path.join(ROOT, "data", "debug_mode.json")) as fh:
    DBG = json.load(fh)


def tint_px(c, v=0.0, tint_hex=DEBUG_CYAN[1]):
    """Reproduce fragment(): mezcla monocroma tenida + vineta (v = factor 0-1)."""
    tint = tuple(x / 255 for x in hx(tint_hex))
    base = [x / 255 for x in c]
    luma = 0.299 * base[0] + 0.587 * base[1] + 0.114 * base[2]
    mono = [luma * t * DBG["tint_gain"] for t in tint]
    k = DBG["tint_strength"]
    col = [b + (m - b) * k for b, m in zip(base, mono)]
    vk = v * DBG["vignette_strength"]
    col = [x + (t * DBG["vignette_shade"] - x) * vk for x, t in zip(col, tint)]
    return tuple(max(0, min(255, round(x * 255))) for x in col)


def apply_debug(img, tint_hex=DEBUG_CYAN[1]):
    w, h = img.size
    src = img.convert("RGB")
    out = Image.new("RGB", (w, h))
    sp, op = src.load(), out.load()
    size, steps = DBG["vignette_size"], DBG["vignette_steps"]
    cache = {}

    def smooth(e):
        t = max(0.0, min(1.0, e / size))
        return t * t * (3 - 2 * t)

    for y in range(h):
        uy = (y + 0.5) / h
        iy = smooth(min(uy, 1 - uy))
        for x in range(w):
            ux = (x + 0.5) / w
            v = 1 - smooth(min(ux, 1 - ux)) * iy
            if steps > 0:
                v = math.ceil(v * steps - 1e-9) / steps
            key = (sp[x, y], v)
            if key not in cache:
                cache[key] = tint_px(sp[x, y], v, tint_hex)
            op[x, y] = cache[key]
    return out


def font(size, bold=False):
    for path in ("/System/Library/Fonts/Menlo.ttc", "/System/Library/Fonts/Monaco.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=1 if bold and path.endswith("ttc") else 0)
    return ImageFont.load_default()


# --------------------------------------------------------------------------- GPL
def write_gpl():
    path = os.path.join(PAL_DIR, "mundo1.gpl")
    lines = [
        "GIMP Palette",
        f"Name: Mundo 1 Notificaciones - {TITLE}",
        "Columns: 4",
        "# Paleta DEFINITIVA del Mundo 1 (aprobada por el usuario el 2026-10-14; variante B del paso 10).",
        "# 16 colores del mundo + debug_cian aparte (ultima fila). Ningun asset del Mundo 1 usa",
        "# colores fuera de esta lista (salvo el arte de Isak, que tiene su propia paleta).",
        "# Generado por tools/palette_mundo1_preview.py",
    ]
    for name, h, fn in COLORS + [DEBUG_CYAN]:
        r, g, b = hx(h)
        lines.append(f"# {name}: {fn}")
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


# ---------------------------------------------------------------- swatch sheet
def palette_sheet():
    cols = COLORS + [DEBUG_CYAN]
    W, sw, rowh = 1280, 96, 92
    H = 110 + 9 * rowh + 30
    img = Image.new("RGB", (W, H), (24, 26, 32))
    d = ImageDraw.Draw(img)
    d.text((24, 20), f"Mundo 1 - Notificaciones | {TITLE}", font=font(26, True), fill=(242, 244, 248))
    d.text((24, 60), "Aprobada 2026-10-14 - 16 colores + cian del Debug (aparte)", font=font(18),
           fill=(200, 205, 215))
    for i, (name, h, fn) in enumerate(cols):
        if i < 16:
            col, row = i // 9, i % 9 if i < 9 else i - 9
        else:
            col, row = 1, 7
        x = 24 + col * 640
        y = 110 + row * rowh
        d.rectangle([x, y, x + sw, y + rowh - 10], fill=hx(h), outline=(90, 94, 104))
        d.text((x + sw + 14, y + 4), f"{i:02d} {name}" if i < 16 else f"+  {name}", font=font(20, True),
               fill=(242, 244, 248))
        d.text((x + sw + 14, y + 30), f"#{h}", font=font(18), fill=(200, 205, 215))
        words, line, yy = fn.split(), "", y + 54
        for wd in words:
            if len(line) + len(wd) > 46:
                d.text((x + sw + 14, yy), line, font=font(14), fill=(170, 176, 190))
                line, yy = "", yy + 16
            line += wd + " "
        d.text((x + sw + 14, yy), line, font=font(14), fill=(170, 176, 190))
    path = os.path.join(PAL_DIR, "mundo1_paleta.png")
    img.save(path)
    return path


# ---------------------------------------------------------------- mock-up 1-1
P = {n: hx(h) for n, h, _ in COLORS}


def scene():
    W, H, T = 1280, 720, 64
    img = Image.new("RGB", (W, H), P["noche_profunda"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 120, W, H], fill=P["cielo"])
    d.rectangle([0, 300, W, H], fill=P["fondo_medio"])
    d.rectangle([0, 380, W, H], fill=P["resplandor"])
    for cx, cy, r in ((180, 210, 70), (760, 170, 54), (1100, 250, 80)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=P["fondo_medio"], outline=P["resplandor"], width=4)
        d.line([cx, cy, cx, cy - r + 14], fill=P["resplandor"], width=6)
        d.line([cx, cy, cx + r - 22, cy + 6], fill=P["resplandor"], width=6)
    for bx, by in ((420, 150), (900, 340)):
        d.rounded_rectangle([bx, by, bx + 220, by + 46], 8, fill=P["fondo_medio"], outline=P["resplandor"], width=2)
        d.rectangle([bx + 10, by + 10, bx + 36, by + 36], fill=P["resplandor"])
    for i, x in enumerate(range(0, W, 160)):
        hgt = 140 + (i * 53) % 120
        d.rectangle([x + 20, H - 96 - hgt, x + 130, H - 96], fill=P["fondo_medio"])
        d.rectangle([x + 36, H - 96 - hgt + 16, x + 60, H - 96 - hgt + 40], fill=P["resplandor"])

    def solid(x0, y0, x1, y1):
        d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=P["tile_base"])
        d.rectangle([x0, y0 + 6, x0 + 3, y1 - 1], fill=P["tile_luz"])
        for tx in range(x0, x1, T):
            for ty in range(y0 + T, y1, T):
                d.rectangle([tx + 12, ty + 12, tx + 24, ty + 24], fill=P["tile_sombra"])
        d.rectangle([x0, y0, x1 - 1, y0 + 3], fill=P["borde_luz"])
        d.rectangle([x0, y0 + 4, x1 - 1, y0 + 7], fill=P["tile_luz"])
        d.rectangle([x1 - 4, y0 + 8, x1 - 1, y1 - 1], fill=P["tile_sombra"])

    ground = H - 96
    solid(0, ground, 520, H)
    solid(680, ground, W, H)
    solid(860, ground - 128, 1060, ground)
    for sx in range(520, 680, 32):
        d.polygon([(sx, H), (sx + 16, H - 40), (sx + 32, H)], fill=P["banner_gris"], outline=P["alerta_sombra"])
        d.polygon([(sx + 10, H - 24), (sx + 16, H - 40), (sx + 22, H - 24)], fill=P["alerta"])
    for sx in range(320, 416, 32):
        d.polygon([(sx, ground), (sx + 16, ground - 28), (sx + 32, ground)], fill=P["banner_gris"])
        d.polygon([(sx + 10, ground - 16), (sx + 16, ground - 28), (sx + 22, ground - 16)], fill=P["alerta"])
    for px, py, pw in ((560, 470, 128), (720, 380, 160)):
        d.rectangle([px, py, px + pw - 1, py + 7], fill=P["borde_luz"])
        d.rectangle([px, py + 8, px + pw - 1, py + 11], fill=P["tile_luz"])
        for k in range(px + 8, px + pw, 32):
            d.rectangle([k, py + 12, k + 4, py + 20], fill=P["tile_luz"])
    bx, by, r = 1000, 300, 34
    d.ellipse([bx - r - 3, by - r - 3, bx + r + 3, by + r + 3], fill=P["alerta_sombra"])
    d.ellipse([bx - r, by - r, bx + r, by + r], fill=P["alerta"])
    d.ellipse([bx - 18, by - 22, bx - 6, by - 10], fill=P["banner_blanco"])
    d.rectangle([bx - 4, by - 16, bx + 4, by + 6], fill=P["banner_blanco"])
    d.rectangle([bx - 4, by + 12, bx + 4, by + 20], fill=P["banner_blanco"])
    d.ellipse([450, ground - 70, 478, ground - 42], fill=P["alerta"], outline=P["alerta_sombra"], width=3)
    x0, y0 = 120, 250
    d.rounded_rectangle([x0 + 6, y0 + 6, x0 + 346, y0 + 86], 10, fill=P["noche_profunda"])
    d.rounded_rectangle([x0, y0, x0 + 340, y0 + 80], 10, fill=P["banner_blanco"], outline=P["banner_gris"], width=3)
    d.rounded_rectangle([x0 + 14, y0 + 14, x0 + 66, y0 + 66], 8, fill=P["alerta"])
    d.text((x0 + 80, y0 + 14), "Chatter · ahora", font=font(18, True), fill=P["noche_profunda"])
    d.text((x0 + 80, y0 + 44), "Tienes 12 mensajes nuevos", font=font(16), fill=P["tile_luz"])
    for ax, ay in ((600, 430), (640, 430), (780, 340), (820, 340), (900, ground - 170)):
        d.polygon([(ax, ay - 12), (ax + 12, ay), (ax, ay + 12), (ax - 12, ay)], fill=P["ambar"],
                  outline=P["ambar_sombra"])
        d.rectangle([ax - 3, ay - 6, ax, ay - 3], fill=P["banner_blanco"])
    return img, ground


def draw_hidden(img, rect, cyan_hex, halo=True):
    """Plataforma oculta como la dibuja scripts/levels/hidden_platform.gd (intensidad 1)."""
    cy = hx(cyan_hex)
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    x0, y0, x1, y1 = rect
    fill_a = DBG["hidden_fill_alpha"] if halo else 0.18
    od.rectangle([x0, y0, x1 - 1, y1 - 1], fill=cy + (round(255 * fill_a),))
    img.paste(Image.alpha_composite(img.convert("RGBA"), over).convert("RGB"))
    d = ImageDraw.Draw(img)
    if halo and DBG.get("hidden_halo_width_px", 0) > 0:
        hw = DBG["hidden_halo_width_px"]
        d.rectangle([x0 - hw, y0 - hw, x1 - 1 + hw, y1 - 1 + hw], outline=P["noche_profunda"], width=hw)
    d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=cy, width=DBG["hidden_outline_width_px"])


def draw_weak_point(img, cx, cy_, bright=False):
    """Punto debil (sobre el tinte): carmin con anillo; bright = pico del pulso."""
    d = ImageDraw.Draw(img)
    r = 24
    d.ellipse([cx - r - 4, cy_ - r - 4, cx + r + 4, cy_ + r + 4], fill=P["noche_profunda"])
    d.ellipse([cx - r, cy_ - r, cx + r, cy_ + r], fill=P["carmin_brillo"] if bright else P["carmin"],
              outline=P["carmin_brillo"], width=4)
    d.ellipse([cx - 8, cy_ - 8, cx + 8, cy_ + 8], fill=P["carmin_brillo"] if not bright else P["banner_blanco"])


def hud(img, cyan_hex=None):
    d = ImageDraw.Draw(img)
    W = img.size[0]
    x1, y0, y1 = W - 16, 16, 48
    x0 = x1 - 300
    d.rectangle([x0, y0, x1, y1], fill=P["noche_profunda"])
    x = x0 + 12
    for i in range(4):
        hgt = 6 + i * 14 // 3
        d.rectangle([x, y1 - 6 - hgt, x + 5, y1 - 6], fill=P["banner_blanco"])
        x += 9
    d.text((x + 6, y0 + 5), "100%", font=font(18, True), fill=P["banner_blanco"])
    x += 70
    fill = hx(cyan_hex) if cyan_hex else P["banner_blanco"]
    d.rectangle([x, y0 + 6, x + 51, y0 + 25], outline=P["banner_blanco"], width=2)
    d.rectangle([x + 52, y0 + 12, x + 55, y0 + 19], fill=P["banner_blanco"])
    for s in range(5):
        sx = x + 4 + s * 9
        d.rectangle([sx, y0 + 10, sx + 7, y0 + 21], fill=fill if s < 3 else P["tile_base"])
    x += 72
    d.polygon([(x + 8, y0 + 8), (x + 16, y0 + 16), (x + 8, y0 + 24), (x, y0 + 16)], fill=P["ambar"])
    d.text((x + 22, y0 + 5), "x 07", font=font(18, True), fill=P["banner_blanco"])


def place_isak(img, ground):
    isak = Image.open(ISAK).convert("RGBA")
    img.paste(isak, (190, ground - 128), isak)


HIDDEN_RECT = (300, 400, 428, 464)


def mockup():
    img, ground = scene()
    place_isak(img, ground)
    normal = img.copy()
    hud(normal)
    dbg = apply_debug(img)
    draw_hidden(dbg, HIDDEN_RECT, DEBUG_CYAN[1])
    draw_weak_point(dbg, 1178, 488)
    hud(dbg, DEBUG_CYAN[1])
    for im, label in ((normal, "NORMAL"), (dbg, f"DEBUG (tinte+viñeta, cian #{DEBUG_CYAN[1]})")):
        ImageDraw.Draw(im).text((16, 16), f"Mundo 1 - {label}", font=font(18, True), fill=P["banner_blanco"])
    out = Image.new("RGB", (1280, 1440))
    out.paste(normal, (0, 0))
    out.paste(dbg, (0, 720))
    path = os.path.join(PAL_DIR, "mundo1_maqueta.png")
    out.save(path)
    return path


# ------------------------------------------------------- comparativa del cian
def cyan_metrics(h):
    c = hx(h)
    t = tint_px(P["resplandor"], 0.0, h)
    return {
        "hue": hue(c),
        "de_isak": min(de(c, hx(i)) for i in ISAK_CYANS),
        "de_resplandor": de(c, P["resplandor"]),
        "de_borde_luz": de(c, P["borde_luz"]),
        "de_blanco": de(c, P["banner_blanco"]),
        "cr_resplandor": ratio(c, P["resplandor"]),
        "cr_resplandor_tenido": ratio(c, t),
        "de_resplandor_tenido": de(c, t),
    }


def cyan_comparison():
    """2x3: antes (cian del paso 10 sin refuerzo) y cada candidato con el refuerzo actual."""
    panels = [(OLD_DEBUG_CYAN, False, "ANTES")] + [(h, True, "") for h in CYAN_CANDIDATES]
    cw, ch = 640, 360
    crop = (80, 340, 80 + cw, 340 + ch)
    out = Image.new("RGB", (cw * 2, 70 + ch * 2 + 480), (24, 26, 32))
    d = ImageDraw.Draw(out)
    d.text((16, 12), "Cian del Debug - Mundo 1: candidatos sobre la maqueta tenida (Isak real, plataforma oculta,"
           " punto débil, batería)", font=font(16, True), fill=(242, 244, 248))
    d.text((16, 40), f"ΔE76 mínimo vs cian de Isak {', '.join('#' + i for i in ISAK_CYANS)}; CR = contraste WCAG."
           f" Elegido: #{DEBUG_CYAN[1]}", font=font(14), fill=(200, 205, 215))
    for i, (h, reinforced, tag) in enumerate(panels):
        img, ground = scene()
        place_isak(img, ground)
        dbg = apply_debug(img, h)
        draw_hidden(dbg, HIDDEN_RECT, h, halo=reinforced)
        draw_weak_point(dbg, 600, 420, bright=False)
        hud(dbg, h)
        panel = dbg.crop(crop)
        # bateria del HUD (esquina) pegada en el panel
        panel.paste(dbg.crop((1280 - 316, 16, 1280 - 16, 49)), (cw - 304, 4))
        pd = ImageDraw.Draw(panel)
        m = cyan_metrics(h)
        label = (f"{tag + ' ' if tag else ''}#{h}{'  <- ELEGIDO' if h == DEBUG_CYAN[1] else ''}  tono {m['hue']}°")
        pd.rectangle([0, ch - 52, cw, ch], fill=P["noche_profunda"])
        pd.rectangle([6, ch - 46, 46, ch - 6], fill=hx(h))
        pd.text((54, ch - 48), label, font=font(15, True), fill=P["banner_blanco"])
        pd.text((54, ch - 26), f"ΔE Isak {m['de_isak']:.1f} | resplandor {m['de_resplandor']:.1f} | "
                f"CR vs resplandor tenido {m['cr_resplandor_tenido']:.2f}", font=font(13), fill=P["banner_gris"])
        out.paste(panel, ((i % 2) * cw, 70 + (i // 2) * ch))
    # ultima fila: zoom x2 de la plataforma oculta antes vs elegido
    zy = 70 + 2 * ch
    for j, (h, reinforced) in enumerate(((OLD_DEBUG_CYAN, False), (DEBUG_CYAN[1], True))):
        img, ground = scene()
        place_isak(img, ground)
        dbg = apply_debug(img, h)
        draw_hidden(dbg, HIDDEN_RECT, h, halo=reinforced)
        z = dbg.crop((150, 384, 470, 624)).resize((640, 480), Image.NEAREST)
        ImageDraw.Draw(z).text((8, 6), f"x2 {'antes' if j == 0 else 'después'} #{h}"
                               f"{' + halo' if reinforced else ''}", font=font(15, True), fill=P["banner_blanco"])
        out.paste(z, (j * cw, zy))
    path = os.path.join(PAL_DIR, "mundo1_debug_cian_comparativa.png")
    out.save(path)
    return path


# ---------------------------------------------------------------- contrastes
def isak_stats():
    im = Image.open(ISAK).convert("RGBA")
    px = [p[:3] for p in im.getdata() if p[3] > 128]
    ls = sorted(rel_lum(c) for c in px)
    return px, ls[len(ls) // 2]


def report():
    px, med = isak_stats()
    print(f"\n== {TITLE} ==")
    for b in ("cielo", "fondo_medio", "resplandor", "tile_base"):
        bl = rel_lum(P[b])
        r_med = (max(bl, med) + 0.05) / (min(bl, med) + 0.05)
        print(f"  Isak (L mediana {med:.3f}) vs {b}: {r_med:.2f}:1")
    for a, b in (("tile_base", "resplandor"), ("borde_luz", "resplandor"), ("alerta", "tile_base"),
                 ("banner_gris", "tile_base"), ("banner_blanco", "noche_profunda"), ("ambar", "noche_profunda")):
        print(f"  {a} vs {b}: {ratio(P[a], P[b]):.2f}:1")
    print("  Cian del Debug (ΔE76 / contraste):")
    for h in [OLD_DEBUG_CYAN] + CYAN_CANDIDATES:
        m = cyan_metrics(h)
        print(f"    #{h} tono {m['hue']:3d}: ΔE Isak {m['de_isak']:.1f}, resplandor {m['de_resplandor']:.1f}, "
              f"borde_luz {m['de_borde_luz']:.1f}, blanco {m['de_blanco']:.1f}; CR resplandor "
              f"{m['cr_resplandor']:.2f} (tenido {m['cr_resplandor_tenido']:.2f}, ΔE {m['de_resplandor_tenido']:.1f})")
    print("  Bajo el tinte del Debug (centro, sin viñeta):")
    for name in ("ambar", "alerta", "carmin", "resplandor"):
        t = tint_px(P[name])
        print(f"    {name} #{''.join('%02x' % v for v in P[name])} -> {hexs(t)} tono {hue(P[name])}->{hue(t)}")


if __name__ == "__main__":
    assert len(COLORS) == 16
    print(write_gpl())
    print(palette_sheet())
    print(mockup())
    print(cyan_comparison())
    report()
