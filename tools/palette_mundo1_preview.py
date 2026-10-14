"""Propuesta de paleta del Mundo 1 (paso 10): muestras, maqueta y contrastes.

Genera, para cada variante (B recomendada sin sufijo, A con sufijo _a):
  assets/palettes/mundo1_propuesta[_a].gpl
  assets/palettes/mundo1_propuesta[_a]_paleta.png
  assets/palettes/mundo1_propuesta[_a]_maqueta.png  (1280x1440: arriba normal,
      abajo con el tinte del Debug reproducido de debug_overlay.gdshader)
e imprime los contrastes medidos. PROPUESTA: no usar en assets hasta aprobar.

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

DEBUG_CYAN = ("debug_cian", "4fe3ff", "Color del Debug (tinte, contornos de plataformas ocultas). Aparte de los 16.")

# (nombre, hex, funcion). El orden es el mismo en las dos variantes.
COMMON_TAIL = [
    ("banner_blanco", "f2f4f8", "Banners/pop-ups, texto del HUD, brillo de borde"),
    ("banner_gris", "aeb8d2", "Sombra de banners, metal de pinchos"),
    ("alerta", "ff4a2a", "Rojo anaranjado: burbujas de alerta, badges, puntas de pinchos, daño"),
    ("alerta_sombra", "a3221c", "Sombra/contorno de lo rojo anaranjado"),
    ("carmin", "e0004a", "Punto débil del jefe (carmín puro, solo con Debug)"),
    ("carmin_brillo", "ff5a8c", "Pulso/brillo del punto débil"),
    ("ambar", "ffa000", "Puntos de atención, icono del HUD (ámbar: sigue dorado bajo el tinte cian)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atención"),
]

VARIANTS = {
    "A": {
        "suffix": "_a",
        "title": "Variante A - Noche profunda",
        "colors": [
            ("noche_profunda", "0b0e1a", "Cielo superior, fondo del HUD/UI, contorno oscuro"),
            ("cielo", "161f40", "Fondo lejano (cielo nocturno)"),
            ("fondo_medio", "23336a", "Fondo medio: siluetas de relojes/pantalla de bloqueo"),
            ("resplandor", "3a55a0", "Resplandor de pantalla, esferas de reloj lejanas"),
            ("tile_sombra", "0f1428", "Tile sólido: sombra/interior profundo"),
            ("tile_base", "1f2742", "Tile sólido: base"),
            ("tile_luz", "3a4670", "Tile sólido: luz/bisel"),
            ("borde_luz", "8fa3d9", "Borde superior de tiles y plataforma de una vía"),
        ] + COMMON_TAIL,
    },
    "B": {
        "suffix": "",
        "title": "Variante B (recomendada) - Noche con resplandor de pantalla",
        "colors": [
            ("noche_profunda", "0b0e1a", "Cielo superior, fondo del HUD/UI, contorno oscuro"),
            ("cielo", "1c2a58", "Fondo lejano (cielo nocturno, más claro)"),
            ("fondo_medio", "2e4688", "Fondo medio: siluetas de relojes/pantalla de bloqueo"),
            ("resplandor", "4f71c4", "Resplandor de pantalla tras la zona de juego"),
            ("tile_sombra", "0c1022", "Tile sólido: sombra/interior profundo"),
            ("tile_base", "1a2138", "Tile sólido: base (más oscuro que el fondo)"),
            ("tile_luz", "343f66", "Tile sólido: luz/bisel"),
            ("borde_luz", "9bb0e8", "Borde superior de tiles y plataforma de una vía"),
        ] + COMMON_TAIL,
    },
}


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
    return math.dist(lab(a), lab(b))


def hue(c):
    return round(colorsys.rgb_to_hsv(*(v / 255 for v in c))[0] * 360)


# --- Tinte del Debug (assets/shaders/debug_overlay.gdshader + data/debug_mode.json) ---
with open(os.path.join(ROOT, "data", "debug_mode.json")) as fh:
    DBG = json.load(fh)
TINT = tuple(v / 255 for v in hx(DEBUG_CYAN[1]))


def tint_px(c, v=0.0):
    """Reproduce fragment(): mezcla monocroma tenida + vineta (v = factor 0-1)."""
    base = [x / 255 for x in c]
    luma = 0.299 * base[0] + 0.587 * base[1] + 0.114 * base[2]
    mono = [luma * t * DBG["tint_gain"] for t in TINT]
    k = DBG["tint_strength"]
    col = [b + (m - b) * k for b, m in zip(base, mono)]
    vk = v * DBG["vignette_strength"]
    col = [x + (t * DBG["vignette_shade"] - x) * vk for x, t in zip(col, TINT)]
    return tuple(max(0, min(255, round(x * 255))) for x in col)


def apply_debug(img):
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
                cache[key] = tint_px(sp[x, y], v)
            op[x, y] = cache[key]
    return out


def font(size, bold=False):
    for path in ("/System/Library/Fonts/Menlo.ttc", "/System/Library/Fonts/Monaco.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=1 if bold and path.endswith("ttc") else 0)
    return ImageFont.load_default()


# --------------------------------------------------------------------------- GPL
def write_gpl(var):
    path = os.path.join(PAL_DIR, f"mundo1_propuesta{var['suffix']}.gpl")
    lines = [
        "GIMP Palette",
        f"Name: Mundo 1 Notificaciones - {var['title']} (PROPUESTA, pendiente de aprobacion)",
        "Columns: 4",
        "# Paleta del Mundo 1 (paso 10). Hex PROPUESTOS, no aprobados: no usar en assets.",
        "# 16 colores del mundo + debug_cian aparte (ultima fila).",
        "# Generado por tools/palette_mundo1_preview.py",
    ]
    for name, h, fn in var["colors"] + [DEBUG_CYAN]:
        r, g, b = hx(h)
        lines.append(f"# {name}: {fn}")
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


# ---------------------------------------------------------------- swatch sheet
def palette_sheet(var):
    cols = var["colors"] + [DEBUG_CYAN]
    W, sw, rowh = 1280, 96, 92
    H = 110 + 9 * rowh + 30
    img = Image.new("RGB", (W, H), (24, 26, 32))
    d = ImageDraw.Draw(img)
    d.text((24, 20), f"Mundo 1 - Notificaciones | {var['title']}", font=font(26, True), fill=(242, 244, 248))
    d.text((24, 60), "PROPUESTA pendiente de aprobación - 16 colores + cian del Debug (aparte)",
           font=font(18), fill=(200, 205, 215))
    for i, (name, h, fn) in enumerate(cols):
        col = i // 9 if i < 16 else 1
        row = i % 9 if i < 16 else 8
        if i < 16 and i >= 9:
            row = i - 9
        if i == 16:
            col, row = 1, 7
        x = 24 + col * 640
        y = 110 + row * rowh
        c = hx(h)
        d.rectangle([x, y, x + sw, y + rowh - 10], fill=c, outline=(90, 94, 104))
        d.text((x + sw + 14, y + 4), f"{i:02d} {name}" if i < 16 else f"+  {name}", font=font(20, True),
               fill=(242, 244, 248))
        d.text((x + sw + 14, y + 30), f"#{h}", font=font(18), fill=(200, 205, 215))
        # funcion en 1-2 lineas
        words, line, yy = fn.split(), "", y + 54
        for wd in words:
            if len(line) + len(wd) > 46:
                d.text((x + sw + 14, yy), line, font=font(14), fill=(170, 176, 190))
                line, yy = "", yy + 16
            line += wd + " "
        d.text((x + sw + 14, yy), line, font=font(14), fill=(170, 176, 190))
    path = os.path.join(PAL_DIR, f"mundo1_propuesta{var['suffix']}_paleta.png")
    img.save(path)
    return path


# ---------------------------------------------------------------- mock-up 1-1
def scene(var):
    P = {n: hx(h) for n, h, _ in var["colors"]}
    W, H, T = 1280, 720, 64
    img = Image.new("RGB", (W, H), P["noche_profunda"])
    d = ImageDraw.Draw(img)
    # cielo en bandas (sin degradado)
    d.rectangle([0, 120, W, H], fill=P["cielo"])
    # resplandor de pantalla de bloqueo, detras de la zona de juego
    d.rectangle([0, 300, W, H], fill=P["fondo_medio"])
    d.rectangle([0, 380, W, H], fill=P["resplandor"]) if var["suffix"] == "" else None
    # relojes lejanos (circulos) y banners lejanos apagados
    for cx, cy, r in ((180, 210, 70), (760, 170, 54), (1100, 250, 80)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=P["fondo_medio"], outline=P["resplandor"], width=4)
        d.line([cx, cy, cx, cy - r + 14], fill=P["resplandor"], width=6)
        d.line([cx, cy, cx + r - 22, cy + 6], fill=P["resplandor"], width=6)
    for bx, by in ((420, 150), (900, 340)):
        d.rounded_rectangle([bx, by, bx + 220, by + 46], 8, fill=P["fondo_medio"], outline=P["resplandor"], width=2)
        d.rectangle([bx + 10, by + 10, bx + 36, by + 36], fill=P["resplandor"])
    # siluetas de fondo medio (bloques de iconos)
    for i, x in enumerate(range(0, W, 160)):
        hgt = 140 + (i * 53) % 120
        d.rectangle([x + 20, H - 96 - hgt, x + 130, H - 96], fill=P["fondo_medio"] if var["suffix"] == "" else P["cielo"])
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
    solid(860, ground - 128, 1060, ground)  # escalon
    # foso con pinchos
    for sx in range(520, 680, 32):
        d.polygon([(sx, H), (sx + 16, H - 40), (sx + 32, H)], fill=P["banner_gris"], outline=P["alerta_sombra"])
        d.polygon([(sx + 10, H - 24), (sx + 16, H - 40), (sx + 22, H - 24)], fill=P["alerta"])
    # pinchos sobre el suelo
    for sx in range(320, 416, 32):
        d.polygon([(sx, ground), (sx + 16, ground - 28), (sx + 32, ground)], fill=P["banner_gris"])
        d.polygon([(sx + 10, ground - 16), (sx + 16, ground - 28), (sx + 22, ground - 16)], fill=P["alerta"])
    # plataformas de una via
    for px, py, pw in ((560, 470, 128), (720, 380, 160)):
        d.rectangle([px, py, px + pw - 1, py + 7], fill=P["borde_luz"])
        d.rectangle([px, py + 8, px + pw - 1, py + 11], fill=P["tile_luz"])
        for k in range(px + 8, px + pw, 32):
            d.rectangle([k, py + 12, k + 4, py + 20], fill=P["tile_luz"])
    # burbuja de alerta (enemigo) y punto rojo (badge)
    bx, by, r = 1000, 300, 34
    d.ellipse([bx - r - 3, by - r - 3, bx + r + 3, by + r + 3], fill=P["alerta_sombra"])
    d.ellipse([bx - r, by - r, bx + r, by + r], fill=P["alerta"])
    d.ellipse([bx - 18, by - 22, bx - 6, by - 10], fill=P["banner_blanco"])
    d.rectangle([bx - 4, by - 16, bx + 4, by + 6], fill=P["banner_blanco"])
    d.rectangle([bx - 4, by + 12, bx + 4, by + 20], fill=P["banner_blanco"])
    d.ellipse([450, ground - 70, 478, ground - 42], fill=P["alerta"], outline=P["alerta_sombra"], width=3)
    # banner blanco (pop-up)
    x0, y0 = 120, 250
    d.rounded_rectangle([x0 + 6, y0 + 6, x0 + 346, y0 + 86], 10, fill=P["noche_profunda"])
    d.rounded_rectangle([x0, y0, x0 + 340, y0 + 80], 10, fill=P["banner_blanco"], outline=P["banner_gris"], width=3)
    d.rounded_rectangle([x0 + 14, y0 + 14, x0 + 66, y0 + 66], 8, fill=P["alerta"])
    d.text((x0 + 80, y0 + 14), "Chatter · ahora", font=font(18, True), fill=P["noche_profunda"])
    d.text((x0 + 80, y0 + 44), "Tienes 12 mensajes nuevos", font=font(16), fill=P["tile_luz"])
    # puntos de atencion
    for ax, ay in ((600, 430), (640, 430), (780, 340), (820, 340), (900, ground - 170)):
        d.polygon([(ax, ay - 12), (ax + 12, ay), (ax, ay + 12), (ax - 12, ay)], fill=P["ambar"],
                  outline=P["ambar_sombra"])
        d.rectangle([ax - 3, ay - 6, ax, ay - 3], fill=P["banner_blanco"])
    # punto debil del jefe (muestra)
    d.ellipse([1150, 460, 1206, 516], fill=P["carmin"], outline=P["carmin_brillo"], width=5)
    d.ellipse([1170, 480, 1186, 496], fill=P["carmin_brillo"])
    # plataforma oculta (contorno del Debug)
    hp = [380, 340, 508, 352]
    return img, P, ground, hp


def hud(img, P):
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
    d.rectangle([x, y0 + 6, x + 51, y0 + 25], outline=P["banner_blanco"], width=2)
    d.rectangle([x + 52, y0 + 12, x + 55, y0 + 19], fill=P["banner_blanco"])
    for s in range(5):
        sx = x + 4 + s * 9
        d.rectangle([sx, y0 + 10, sx + 7, y0 + 21], fill=P["banner_blanco"] if s < 3 else P["tile_base"])
    x += 72
    d.polygon([(x + 8, y0 + 8), (x + 16, y0 + 16), (x + 8, y0 + 24), (x, y0 + 16)], fill=P["ambar"])
    d.text((x + 22, y0 + 5), "x 07", font=font(18, True), fill=P["banner_blanco"])


def mockup(var):
    img, P, ground, hp = scene(var)
    isak = Image.open(ISAK).convert("RGBA")
    img.paste(isak, (190, ground - 128), isak)
    normal = img.copy()
    hud(normal, P)
    dbg = apply_debug(img)
    dd = ImageDraw.Draw(dbg)
    cy = hx(DEBUG_CYAN[1])
    dd.rectangle(hp, outline=cy, width=DBG["hidden_outline_width_px"])
    hud(dbg, P)
    for im, label in ((normal, "NORMAL"), (dbg, "DEBUG (tinte+viñeta)")):
        ImageDraw.Draw(im).text((16, 16), f"{var['title'].split(' - ')[0]} - {label}", font=font(18, True),
                                fill=P["banner_blanco"])
    out = Image.new("RGB", (1280, 1440))
    out.paste(normal, (0, 0))
    out.paste(dbg, (0, 720))
    path = os.path.join(PAL_DIR, f"mundo1_propuesta{var['suffix']}_maqueta.png")
    out.save(path)
    return path


# ---------------------------------------------------------------- contrastes
def isak_stats():
    im = Image.open(ISAK).convert("RGBA")
    px = [p[:3] for p in im.getdata() if p[3] > 128]
    ls = sorted(rel_lum(c) for c in px)
    return px, ls[len(ls) // 2]


def report(var):
    P = {n: hx(h) for n, h, _ in var["colors"]}
    px, med = isak_stats()
    print(f"\n== {var['title']} ==")

    def isak_vs(bgname):
        bl = rel_lum(P[bgname])
        r_med = (max(bl, med) + 0.05) / (min(bl, med) + 0.05)
        frac = sum(1 for c in px if ratio(c, P[bgname]) >= 1.5) / len(px)
        print(f"  Isak (L mediana {med:.3f}) vs {bgname}: {r_med:.2f}:1, px con >=1.5:1 = {frac:.0%}")

    for b in ("cielo", "fondo_medio", "resplandor", "tile_base"):
        isak_vs(b)
    for a, b in (("tile_base", "fondo_medio"), ("tile_base", "resplandor"), ("borde_luz", "fondo_medio"),
                 ("borde_luz", "resplandor"), ("alerta", "tile_base"), ("banner_gris", "tile_base"),
                 ("alerta", "fondo_medio"), ("banner_blanco", "noche_profunda"), ("ambar", "noche_profunda"),
                 ("ambar", "resplandor"), ("noche_profunda", "banner_blanco")):
        print(f"  {a} vs {b}: {ratio(P[a], P[b]):.2f}:1")
    cy = hx(DEBUG_CYAN[1])
    for a, b in (("alerta", "carmin"),):
        print(f"  dE {a} vs {b}: {de(P[a], P[b]):.1f} (tono {hue(P[a])} vs {hue(P[b])})")
    for a in ("alerta", "carmin"):
        print(f"  dE {a} vs debug_cian: {de(P[a], cy):.1f}")
    print(f"  dE debug_cian vs cian Isak #29defa: {de(cy, hx('29defa')):.1f}; vs #36c0d4: {de(cy, hx('36c0d4')):.1f}")
    print("  Bajo el tinte del Debug (centro, sin viñeta):")
    for name in ("ambar", "alerta", "carmin", "fondo_medio", "resplandor"):
        t = tint_px(P[name])
        print(f"    {name} #{''.join('%02x' % v for v in P[name])} -> #{''.join('%02x' % v for v in t)} "
              f"tono {hue(P[name])}->{hue(t)}")
    old = hx("ffd34a")
    to = tint_px(old)
    print(f"    (amarillo actual HUD #ffd34a -> #{''.join('%02x' % v for v in to)} tono {hue(old)}->{hue(to)})")
    ta, tl = tint_px(P["ambar"]), tint_px(P["alerta"])
    print(f"    dE ambar vs alerta tenidos: {de(ta, tl):.1f}; ambar tenido vs resplandor tenido: "
          f"{ratio(ta, tint_px(P['resplandor'])):.2f}:1")


if __name__ == "__main__":
    for key in ("A", "B"):
        v = VARIANTS[key]
        assert len(v["colors"]) == 16, key
        print(write_gpl(v))
        print(palette_sheet(v))
        print(mockup(v))
        report(v)
