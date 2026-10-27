#!/usr/bin/env python3
"""Arte PROVISIONAL del jefe del Mundo 3 «La Curadora» (2026-10-27, paso 15 de docs/propuesta-mundo-3.md §8).

El arte final saldra de AutoSprite (paso 23, con permiso del usuario); hasta entonces, formas planas con la
paleta B del Mundo 3 ya aplicada (assets/palettes/mundo3.gpl, «Terciopelo de trastienda») y el sufijo
_placeholder que pide CLAUDE.md para los jefes sin arte final. Las cajas y los tiempos ya son los definitivos
(data/bosses/curator.json); el arte final se encaja sin cambiarlos. Nada en rojo: el rojo es solo para lo que
dana y el punto debil (la pantalla rota la dibuja WeakPoint por encima del tinte del Debug). En
assets/sprites/bosses/:
  curator_frame_placeholder.png       marco dorado de 8 x 4 tiles (512 x 256) con el retrato «filtrado» (rosa,
                                      sonrisa perfecta) y la camara-cabeza en el centro de arriba (lente en
                                      (256, 24), lens_px de la arena)
  curator_frame_back_placeholder.png  la trasera (fase 2 «De espaldas»): tablero de madera con travesanos y el
                                      alambre de colgar
  curator_frame_off_placeholder.png   golpe final: el marco con la pantalla rota apagada (grietas gris perla)
  curator_biombo_placeholder.png      biombo de 1 x 2 tiles (64 x 128) que tapa el flash: tres hojas rosa
                                      sombra con marco dorado
  curator_lens_card_placeholder.png   ficha del album de la lente (paso 19): la camara-cabeza bajada a
                                      encuadrar, con el aro dorado del flash (64 x 64)
  curator_closing_frame_card_placeholder.png  ficha del album del marco que se cierra (paso 19): marco dorado
                                      con el contorno rojo del aviso estrechandose y el marco pequeno a salvo
                                      abajo (64 x 64; rojo = lo que dana)
Los avisos (aro del flash, filtro de suelo, recorte, marco que se cierra) los dibuja scripts/bosses/curator.gd
por codigo.

Uso: python3 -I tools/gen_boss_curator.py [--check]   (--check: 1 si algun PNG no esta al dia)
"""
import io
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
from PIL import Image, ImageDraw  # noqa: E402

OUT = os.path.join("assets", "sprites", "bosses")
PALETTE = os.path.join(REPO, "assets", "palettes", "mundo3.gpl")


def load_palette(path):
    colors = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) >= 4 and all(p.isdigit() for p in parts[:3]):
                colors[parts[3]] = (int(parts[0]), int(parts[1]), int(parts[2]), 255)
    return colors


C = load_palette(PALETTE)


def frame_border(d, w, h):
    """Marco dorado con bisel y sombra (24 px)."""
    d.rectangle((0, 0, w - 1, h - 1), fill=C["marco_sombra"])
    d.rectangle((4, 4, w - 5, h - 5), fill=C["dorado"])
    d.rectangle((4, 4, w - 5, 9), fill=C["dorado_luz"])
    d.rectangle((4, 4, 9, h - 5), fill=C["dorado_luz"])
    d.rectangle((20, 20, w - 21, h - 21), fill=C["marco_sombra"])
    # Adornos en las esquinas.
    for cx, cy in ((12, 12), (w - 13, 12), (12, h - 13), (w - 13, h - 13)):
        d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=C["dorado_luz"])
        d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=C["marco_sombra"])


def camera_head(d, cx):
    """Camara-cabeza en el centro del lado de arriba (lente en (cx, 24))."""
    d.rectangle((cx - 52, 2, cx + 52, 46), fill=C["galeria_noche"])
    d.rectangle((cx - 48, 6, cx + 48, 42), fill=C["trastienda_medio"])
    d.rectangle((cx + 26, 0, cx + 44, 6), fill=C["galeria_noche"])
    d.ellipse((cx - 20, 4, cx + 20, 44), fill=C["galeria_noche"])
    d.ellipse((cx - 15, 9, cx + 15, 39), fill=C["gris_perla"])
    d.ellipse((cx - 8, 16, cx + 8, 32), fill=C["trastienda_fondo"])
    d.ellipse((cx - 6, 14, cx - 1, 19), fill=C["blanco_brillante"])


def frame(state):
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    frame_border(d, w, h)
    inner = (24, 24, w - 25, h - 25)
    if state == "off":
        d.rectangle(inner, fill=C["galeria_noche"])
        # Pantalla rota apagada: grietas desde un punto.
        cx, cy = 256, 132
        for ex, ey in ((40, 40), (470, 60), (90, 220), (420, 226), (256, 30), (30, 140), (480, 150)):
            d.line((cx, cy, ex, ey), fill=C["gris_perla"], width=2)
        d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), outline=C["gris_perla"], width=2)
    else:
        d.rectangle(inner, fill=C["rosa_pastel"])
        # Retrato «filtrado»: fondo suave, cara perfecta y sonrisa.
        for i, name in enumerate(("rosa_sombra", "corazon_rosa", "rosa_sombra")):
            d.rectangle((24, 170 + i * 12, w - 25, 176 + i * 12), fill=C[name])
        d.ellipse((196, 60, 316, 190), fill=C["blanco_brillante"])
        d.ellipse((222, 104, 236, 118), fill=C["trastienda_medio"])
        d.ellipse((276, 104, 290, 118), fill=C["trastienda_medio"])
        d.arc((226, 120, 286, 164), 20, 160, fill=C["corazon_rosa"], width=4)
        # Destellos de filtro.
        for sx, sy in ((150, 70), (360, 90), (130, 150), (380, 160)):
            d.line((sx - 6, sy, sx + 6, sy), fill=C["blanco_brillante"], width=2)
            d.line((sx, sy - 6, sx, sy + 6), fill=C["blanco_brillante"], width=2)
    camera_head(d, 256)
    return img


def frame_back():
    w, h = 512, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), fill=C["marco_sombra"])
    d.rectangle((8, 8, w - 9, h - 9), fill=C["trastienda_medio"])
    # Tablas.
    for y in range(8, h - 8, 32):
        d.line((8, y, w - 9, y), fill=C["trastienda_fondo"], width=2)
    # Travesanos en aspa.
    d.line((16, 16, w - 17, h - 17), fill=C["marco_sombra"], width=10)
    d.line((16, h - 17, w - 17, 16), fill=C["marco_sombra"], width=10)
    # Alambre de colgar y su clavo.
    d.line((120, 40, 256, 14), fill=C["gris_perla"], width=2)
    d.line((392, 40, 256, 14), fill=C["gris_perla"], width=2)
    d.ellipse((250, 8, 262, 20), fill=C["dorado"])
    # Etiqueta de la galeria.
    d.rectangle((200, 180, 312, 220), fill=C["rosa_pastel"])
    d.rectangle((210, 192, 302, 196), fill=C["rosa_sombra"])
    d.rectangle((210, 204, 280, 208), fill=C["rosa_sombra"])
    return img


def biombo():
    w, h = 64, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel = (w - 8) // 3
    for i in range(3):
        x0 = 4 + i * panel
        top = 6 if i == 1 else 12
        d.rectangle((x0, top, x0 + panel - 1, h - 9), fill=C["dorado"])
        d.rectangle((x0 + 2, top + 2, x0 + panel - 3, h - 11), fill=C["rosa_sombra"])
        d.line((x0 + 4, top + 10, x0 + panel - 5, top + 10), fill=C["rosa_pastel"], width=2)
    # Patas.
    for x in (8, w - 9):
        d.rectangle((x - 2, h - 9, x + 2, h - 1), fill=C["marco_sombra"])
    return img


def lens_card():
    """Ficha de la lente (curator_lens): la camara-cabeza con el aro del flash."""
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, w - 3, h - 3), outline=C["dorado"], width=3)
    d.rectangle((10, 18, 54, 50), fill=C["galeria_noche"])
    d.rectangle((13, 21, 51, 47), fill=C["trastienda_medio"])
    d.rectangle((40, 14, 50, 18), fill=C["galeria_noche"])
    d.ellipse((19, 21, 45, 47), fill=C["galeria_noche"])
    d.ellipse((23, 25, 41, 43), fill=C["gris_perla"])
    d.ellipse((28, 30, 36, 38), fill=C["trastienda_fondo"])
    d.ellipse((26, 27, 29, 30), fill=C["blanco_brillante"])
    return img


def closing_frame_card():
    """Ficha del marco que se cierra (closing_frame): marco dorado, aviso rojo y marco pequeno."""
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, 47), fill=C["marco_sombra"])
    d.rectangle((3, 3, w - 4, 44), fill=C["dorado"])
    d.rectangle((3, 3, w - 4, 5), fill=C["dorado_luz"])
    d.rectangle((8, 8, w - 9, 39), fill=C["galeria_noche"])
    d.rectangle((14, 13, w - 15, 34), outline=C["alerta"], width=3)
    # Flechas hacia dentro (se estrecha).
    for x0, x1 in ((9, 13), (w - 10, w - 14)):
        d.line((x0, 23, x1, 23), fill=C["alerta"], width=2)
    # Marco pequeno abajo, a salvo.
    d.rectangle((20, 52, 43, 63), fill=C["dorado"])
    d.rectangle((23, 55, 40, 63), fill=C["galeria_noche"])
    d.rectangle((29, 58, 34, 63), fill=C["gris_perla"])
    return img


def outputs():
    return {
        "curator_lens_card_placeholder.png": lens_card(),
        "curator_closing_frame_card_placeholder.png": closing_frame_card(),
        "curator_frame_placeholder.png": frame("on"),
        "curator_frame_back_placeholder.png": frame_back(),
        "curator_frame_off_placeholder.png": frame("off"),
        "curator_biombo_placeholder.png": biombo(),
    }


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=False)
    return buf.getvalue()


def main(argv):
    check = "--check" in argv
    stale = []
    for name, img in outputs().items():
        path = os.path.join(REPO, OUT, name)
        if check:
            if not os.path.exists(path):
                stale.append(name)
                continue
            with Image.open(path) as old:
                if old.convert("RGBA").tobytes() != img.tobytes() or old.size != img.size:
                    stale.append(name)
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(png_bytes(img))
            print("escrito", os.path.join(OUT, name))
    if check:
        for name in stale:
            print("desactualizado:", name)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
