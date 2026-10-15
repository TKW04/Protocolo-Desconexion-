"""Paleta del HUB («gris azulado apagado», PROPUESTA 2026-10-15).

Genera:
  assets/palettes/hub.gpl          16 colores nombrados por rol (el cian del Debug
                                   del Mundo 1 va DENTRO de los 16 como acento)
  assets/palettes/hub_paleta.png   muestras con nombre + maqueta sencilla del hub
                                   (fondo con la foto rota, dock, carpetas
                                   bloqueada/disponible/completada, copia local
                                   activa, Calc dormida, HUD con «sin guardar»)
e imprime la tabla de contrastes WCAG de los pares texto/fondo e icono/fondo.

Uso:
  python3 -I tools/palette_hub_preview.py            genera gpl + png y la tabla
  python3 -I tools/palette_hub_preview.py --check    solo valida hub.gpl (16
      colores, hex unicos, coincide con COLORS) y los contrastes minimos;
      sale con codigo 1 si algo falla
  python3 -I tools/palette_hub_preview.py --png <ruta>  ademas copia el png ahi

Rojos del usuario (#dc0000, #ff3838): RESERVADOS, no estan en el hub (rojo =
dano y puntos debiles; en el hub nada hace dano). Ver docs/07-estilo-visual.md.
"""
import os
import shutil
import site
import sys

# Pillow vive en los site-packages del usuario: se anade a mano para python3 -I.
sys.path.append(site.getusersitepackages())
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL_DIR = os.path.join(ROOT, "assets", "palettes")
GPL = os.path.join(PAL_DIR, "hub.gpl")
PNG = os.path.join(PAL_DIR, "hub_paleta.png")

TITLE = "Hub - Modo Avion, gris azulado apagado (PROPUESTA)"
# (nombre, hex, funcion)
COLORS = [
    ("fondo_profundo", "050e3c", "Contorno de todo, fondo del HUD (dato del usuario)"),
    ("sombra", "002455", "Sombras, interior del dock, hueco de la foto rota (dato del usuario)"),
    ("panel", "1a2a46", "Fondo de paneles de menu (copia local, Calc, carpetas)"),
    ("dock", "26354f", "Dock/suelo y repisas: superficie (mas oscuro que el fondo)"),
    ("base", "3a4862", "Fondo ambiente del hub (gris azulado apagado)"),
    ("gris_apagado", "56637a", "Piezas apagadas de la foto, carpeta bloqueada, Calc dormida"),
    ("gris_foto", "77849a", "Luz de las piezas apagadas de la foto, bisel del dock"),
    ("traza", "4f71c4", "Trazas de circuito de 1 px (= resplandor del Mundo 1)"),
    ("borde", "9bb0e8", "Borde superior del dock y repisas, bisel claro (= borde_luz del Mundo 1)"),
    ("texto_tenue", "aab4c6", "Texto secundario, icono de carpeta bloqueada, candado"),
    ("texto_claro", "eef1f7", "Texto de paneles y HUD, iconos claros, check de completada"),
    ("cian_tenue", "12857f", "Pieza 1 encendida: sombra; halo de lo interactivo (= pulse_dim)"),
    ("acento_cian", "3dfff5", "Interactivos, carpeta disponible, copia local activa, pieza 1 (= debug_cian del Mundo 1)"),
    ("cian_brillo", "c2fffc", "Pieza 1 encendida: brillo; pantalla de la copia local (= pulse_core)"),
    ("ambar", "ffa000", "Puntos de atencion e indicador «sin guardar» (= ambar del Mundo 1)"),
    ("ambar_sombra", "a85f00", "Sombra de los puntos de atencion"),
]
RESERVED = [("rojo_usuario", "dc0000"), ("rojo_usuario_claro", "ff3838")]

# Pares (frente, fondo, minimo, uso). 4.5 = texto; 3.0 = iconos/bordes (WCAG 1.4.11).
PAIRS = [
    ("texto_claro", "panel", 4.5, "texto de panel"),
    ("texto_claro", "fondo_profundo", 4.5, "texto del HUD"),
    ("texto_claro", "base", 4.5, "texto sobre el fondo del hub"),
    ("texto_claro", "dock", 4.5, "rotulo sobre el dock"),
    ("texto_tenue", "panel", 4.5, "texto secundario de panel"),
    ("texto_tenue", "fondo_profundo", 4.5, "texto secundario del HUD"),
    ("acento_cian", "panel", 4.5, "opcion seleccionada en panel"),
    ("ambar", "fondo_profundo", 4.5, "contador de puntos / «sin guardar» en HUD"),
    ("ambar", "panel", 4.5, "precio en puntos (panel de Calc)"),
    ("fondo_profundo", "acento_cian", 4.5, "texto oscuro sobre boton cian"),
    ("acento_cian", "base", 3.0, "contorno de carpeta disponible / pieza 1"),
    ("acento_cian", "dock", 3.0, "copia local activa sobre el dock"),
    ("ambar", "base", 3.0, "punto de atencion sobre el fondo"),
    ("borde", "dock", 3.0, "borde superior del dock"),
    ("borde", "base", 3.0, "borde de repisa sobre el fondo"),
    ("texto_tenue", "base", 3.0, "icono de carpeta bloqueada / candado"),
    ("fondo_profundo", "base", 3.0, "contorno sobre el fondo"),
    ("fondo_profundo", "gris_apagado", 3.0, "contorno de carpeta bloqueada"),
    ("fondo_profundo", "acento_cian", 3.0, "check sobre carpeta completada"),
    ("gris_apagado", "base", 3.0, "pieza apagada vs fondo (decorativo)"),
    ("cian_brillo", "gris_apagado", 3.0, "pieza 1 encendida vs piezas apagadas"),
]


# Pares que no llegan al minimo y se aceptan a proposito (no se usan para separar
# un objeto del fondo; ver docs/07-estilo-visual.md, paleta del hub).
ACCEPTED = {
    ("fondo_profundo", "base"): "el objeto se separa del fondo por su bisel borde (4,28:1) y su relleno",
    ("gris_apagado", "base"): "decorativo: la foto apagada debe fundirse con el fondo",
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
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


C = {n: hx(h) for n, h, _ in COLORS}


def contrast_rows():
    rows = []
    for fg, bg, need, use in PAIRS:
        r = ratio(C[fg], C[bg])
        rows.append((fg, bg, r, need, use, r >= need or (fg, bg) in ACCEPTED))
    return rows


def font(size):
    for path in ("/System/Library/Fonts/Menlo.ttc", "/System/Library/Fonts/Monaco.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def write_gpl():
    lines = [
        "GIMP Palette",
        f"Name: {TITLE}",
        "Columns: 4",
        "# Paleta del HUB (propuesta 2026-10-15; hex elegidos por el agente, a revisar por el usuario).",
        "# 16 colores; el acento cian es el debug_cian del Mundo 1 y cuenta dentro de los 16.",
        "# Sin rojo: #dc0000 y #ff3838 (del usuario) quedan reservados fuera del hub.",
        "# Generado por tools/palette_hub_preview.py",
    ]
    for name, h, fn in COLORS:
        r, g, b = hx(h)
        lines.append(f"# {name}: {fn}")
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    with open(GPL, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def read_gpl(path):
    out = []
    with open(path, encoding="utf-8") as fh:
        head = fh.readline().strip()
        if head != "GIMP Palette":
            raise ValueError("cabecera distinta de 'GIMP Palette'")
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or ":" in s.split()[0]:
                continue
            p = s.split()
            if len(p) < 4 or not all(x.isdigit() and int(x) <= 255 for x in p[:3]):
                raise ValueError(f"linea invalida: {s!r}")
            out.append((p[3], "%02x%02x%02x" % tuple(int(x) for x in p[:3])))
    return out


def check():
    errs = []
    try:
        entries = read_gpl(GPL)
    except (OSError, ValueError) as e:
        return [f"hub.gpl: {e}"]
    if len(entries) != 16:
        errs.append(f"hub.gpl tiene {len(entries)} colores (se esperan 16)")
    hexes = [h for _, h in entries]
    if len(set(hexes)) != len(hexes):
        errs.append("hub.gpl tiene hex repetidos")
    if len({n for n, _ in entries}) != len(entries):
        errs.append("hub.gpl tiene nombres repetidos")
    if entries != [(n, h) for n, h, _ in COLORS]:
        errs.append("hub.gpl no coincide con COLORS del generador (regenera)")
    for _, h in RESERVED:
        if h in hexes:
            errs.append(f"#{h} es un rojo reservado y no debe estar en el hub")
    for fg, bg, r, need, use, ok in contrast_rows():
        if not ok:
            errs.append(f"contraste {fg}/{bg} = {r:.2f} < {need} ({use})")
    return errs


# --------------------------------------------------------------- imagen
def mockup():
    """Maqueta 320x180 (1/4 de 1280x720) dibujada solo con colores de la paleta."""
    W, H = 320, 180
    im = Image.new("RGB", (W, H), C["base"])
    d = ImageDraw.Draw(im)
    d.fontmode = "1"  # sin antialias: la maqueta usa solo colores de la paleta
    # HUD
    d.rectangle([0, 0, W, 11], fill=C["fondo_profundo"])
    # avion
    d.polygon([(6, 6), (14, 3), (14, 9)], fill=C["texto_claro"])
    d.line([(9, 2), (11, 10)], fill=C["texto_claro"])
    # bateria
    d.rectangle([196, 3, 212, 8], outline=C["acento_cian"])
    d.rectangle([198, 5, 207, 6], fill=C["acento_cian"])
    d.rectangle([213, 4, 214, 7], fill=C["acento_cian"])
    # puntos
    d.polygon([(222, 5), (225, 2), (228, 5), (225, 8)], fill=C["ambar"], outline=C["ambar_sombra"])
    d.text((231, 0), "12", fill=C["ambar"], font=font(8))
    # sin guardar
    d.ellipse([252, 3, 257, 8], fill=C["ambar"])
    d.text((260, 0), "sin guardar", fill=C["ambar"], font=font(8))
    # trazas
    for y in (30, 70, 118):
        d.line([(0, y), (60, y), (66, y + 6), (120, y + 6)], fill=C["traza"])
        d.line([(200, y + 4), (254, y + 4), (260, y - 2), (320, y - 2)], fill=C["traza"])
    # foto rota (5 piezas) centrada al fondo
    fx, fy, fw, fh = 112, 20, 96, 64
    d.rectangle([fx - 2, fy - 2, fx + fw + 2, fy + fh + 2], fill=C["sombra"])
    pieces = [
        [(fx, fy), (fx + 40, fy), (fx + 30, fy + 34), (fx, fy + 28)],
        [(fx + 42, fy), (fx + fw, fy), (fx + fw, fy + 22), (fx + 32, fy + 34)],
        [(fx, fy + 30), (fx + 30, fy + 36), (fx + 24, fy + fh), (fx, fy + fh)],
        [(fx + 32, fy + 36), (fx + fw, fy + 24), (fx + fw, fy + fh), (fx + 26, fy + fh)],
    ]
    # pieza 1 encendida (cian), resto apagado
    p1 = pieces[0]
    d.polygon(p1, fill=C["cian_tenue"], outline=C["acento_cian"])
    d.polygon([(fx + 4, fy + 4), (fx + 30, fy + 4), (fx + 22, fy + 20), (fx + 4, fy + 18)],
              fill=C["acento_cian"])
    d.line([(fx + 6, fy + 6), (fx + 20, fy + 6)], fill=C["cian_brillo"])
    for p in pieces[1:]:
        d.polygon(p, fill=C["gris_apagado"], outline=C["fondo_profundo"])
        d.line([p[0], p[1]], fill=C["gris_foto"])
    # pieza 5: esquina suelta
    p5 = [(fx + 62, fy + 46), (fx + fw, fy + 40), (fx + fw, fy + fh), (fx + 70, fy + fh)]
    d.polygon(p5, fill=C["gris_apagado"], outline=C["fondo_profundo"])
    d.line([p5[0], p5[1]], fill=C["gris_foto"])

    def shelf(x, y, w):
        d.rectangle([x, y, x + w, y + 3], fill=C["dock"], outline=C["fondo_profundo"])
        d.line([(x + 1, y + 1), (x + w - 1, y + 1)], fill=C["borde"])

    def folder(x, y, state):
        fill = {"bloq": C["gris_apagado"], "disp": C["panel"], "comp": C["acento_cian"]}[state]
        line = {"bloq": C["fondo_profundo"], "disp": C["acento_cian"], "comp": C["fondo_profundo"]}[state]
        d.rectangle([x, y + 3, x + 7, y + 6], fill=fill, outline=line)
        d.rectangle([x, y + 5, x + 23, y + 22], fill=fill, outline=line)
        if state == "bloq":  # candado
            d.rectangle([x + 9, y + 12, x + 15, y + 18], fill=C["texto_tenue"])
            d.rectangle([x + 10, y + 9, x + 14, y + 12], outline=C["texto_tenue"])
        elif state == "disp":
            d.text((x + 7, y + 8), "M1", fill=C["acento_cian"], font=font(8))
        else:  # check
            d.line([(x + 6, y + 13), (x + 10, y + 17), (x + 18, y + 9)], fill=C["fondo_profundo"], width=2)

    # carpetas sobre repisas (bloqueada, disponible, completada)
    for x, st in ((40, "comp"), (148, "disp"), (256, "bloq")):
        folder(x, 90, st)
        shelf(x - 6, 114, 36)
    # dock / suelo
    d.rectangle([0, 148, W, H], fill=C["dock"])
    d.line([(0, 148), (W, 148)], fill=C["borde"])
    d.line([(0, 149), (W, 149)], fill=C["gris_foto"])
    d.rectangle([0, 160, W, H], fill=C["sombra"])
    d.line([(0, 0 + 159), (W, 159)], fill=C["fondo_profundo"])
    # huecos del dock (aliados futuros)
    for x in (170, 200, 230):
        d.rectangle([x, 133, x + 14, 147], outline=C["gris_apagado"])
    # Calc dormida
    d.rectangle([126, 128, 144, 147], fill=C["gris_apagado"], outline=C["fondo_profundo"])
    d.rectangle([129, 131, 141, 136], fill=C["panel"])
    d.line([(131, 134), (134, 134)], fill=C["texto_tenue"])
    d.line([(136, 134), (139, 134)], fill=C["texto_tenue"])
    for i in range(3):
        d.rectangle([129 + i * 4, 139, 131 + i * 4, 141], fill=C["gris_foto"])
        d.rectangle([129 + i * 4, 143, 131 + i * 4, 145], fill=C["gris_foto"])
    d.line([(147, 120), (151, 120), (147, 124), (151, 124)], fill=C["texto_tenue"])  # «z» de dormida
    # copia local (monitor activo) + prompt
    d.rectangle([12, 120, 34, 147], fill=C["panel"], outline=C["fondo_profundo"])
    d.rectangle([15, 123, 31, 136], fill=C["cian_brillo"], outline=C["acento_cian"])
    d.line([(18, 127), (28, 127)], fill=C["cian_tenue"])
    d.line([(18, 130), (25, 130)], fill=C["cian_tenue"])
    d.rectangle([20, 140, 26, 143], fill=C["acento_cian"])
    # prompt de la tecla
    d.rectangle([16, 106, 30, 116], fill=C["panel"], outline=C["acento_cian"])
    d.text((20, 106), "G", fill=C["texto_claro"], font=font(9))
    # Isak placeholder (silueta)
    d.rectangle([76, 124, 84, 147], fill=C["fondo_profundo"])
    d.rectangle([75, 116, 85, 126], fill=C["fondo_profundo"])
    # panel de menu (texto claro sobre panel)
    d.rectangle([214, 18, 312, 82], fill=C["panel"], outline=C["fondo_profundo"])
    d.rectangle([215, 19, 311, 81], outline=C["traza"])
    f = font(8)
    d.text((220, 22), "Copia local", fill=C["texto_claro"], font=f)
    d.text((220, 34), "> Guardar", fill=C["acento_cian"], font=f)
    d.text((220, 46), "  Volver", fill=C["texto_claro"], font=f)
    d.text((220, 58), "ult.: 1-1", fill=C["texto_tenue"], font=f)
    d.text((220, 70), "pts 12", fill=C["ambar"], font=f)
    pal = set(C.values())
    bad = {px for px in im.getdata() if px not in pal}
    assert not bad, f"colores fuera de la paleta en la maqueta: {sorted(bad)[:5]}"
    return im


def sheet():
    S = 4
    mock = mockup().resize((320 * S, 180 * S), Image.NEAREST)
    sw, rows = 160, 4
    top = 40
    pal_h = top + rows * 110 + 70
    out = Image.new("RGB", (1280, pal_h + mock.height + 40), C["fondo_profundo"])
    d = ImageDraw.Draw(out)
    d.text((20, 10), "Paleta del HUB (propuesta) - 16 colores", fill=C["texto_claro"], font=font(20))
    f, fs = font(14), font(12)
    for i, (n, h, _) in enumerate(COLORS):
        cx, cy = 20 + (i % 4) * 315, top + (i // 4) * 110
        d.rectangle([cx, cy, cx + sw, cy + 60], fill=hx(h), outline=C["texto_tenue"])
        d.text((cx, cy + 66), n, fill=C["texto_claro"], font=f)
        d.text((cx, cy + 84), "#" + h, fill=C["texto_tenue"], font=fs)
    ry = top + rows * 110
    d.text((20, ry), "Reservados (NO hub):", fill=C["texto_tenue"], font=f)
    for i, (n, h) in enumerate(RESERVED):
        x = 220 + i * 260
        d.rectangle([x, ry, x + 40, ry + 24], fill=hx(h))
        d.text((x + 50, ry + 4), "#" + h, fill=C["texto_tenue"], font=fs)
    d.text((760, ry + 4), "alertas / jefes / puntos debiles", fill=C["texto_tenue"], font=fs)
    out.paste(mock, (0, pal_h))
    d.text((20, pal_h + mock.height + 10),
           "Maqueta x4: completada / disponible / bloqueada, copia local activa, Calc dormida, '● sin guardar' en ambar",
           fill=C["texto_tenue"], font=fs)
    return out


def main(argv):
    if "--check" in argv:
        errs = check()
        for e in errs:
            print("ERROR:", e)
        print("hub.gpl OK" if not errs else f"{len(errs)} errores")
        return 1 if errs else 0
    write_gpl()
    img = sheet()
    img.save(PNG)
    if "--png" in argv:
        dst = argv[argv.index("--png") + 1]
        shutil.copyfile(PNG, dst)
    print("| Frente | Fondo | Ratio | Minimo | Uso | Cumple |")
    print("|---|---|---|---|---|---|")
    for fg, bg, r, need, use, ok in contrast_rows():
        mark = "si" if r >= need else ("NO (aceptado)" if ok else "NO")
        print(f"| `{fg}` | `{bg}` | {r:.2f}:1 | {need}:1 | {use} | {mark} |")
    errs = check()
    for e in errs:
        print("ERROR:", e)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
