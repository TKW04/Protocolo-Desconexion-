"""Pruebas de la fuente de textos en espanol (tools/gen_text_font.py, data/text_font.json).

- Cobertura: cada caracter de una lista Unicode de espanol esta en el .fnt.
- Todas las cadenas de texto del juego usadas hasta ahora (nombres y textos de los niveles,
  textos del catalogo de objetos del Mundo 1, glifos del HUD, textos del cuadro de Eco) solo
  usan glifos existentes.
- Metricas: celdas de 12 filas, base 10, interlineado 13; digitos identicos a los del HUD.
- validate_ui_assets.py devuelve 0.

Uso: python3 -m unittest tests/test_text_font.py
"""
import glob
import json
import re
import os
import subprocess
import sys
import unittest

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_ui_assets as vua  # noqa: E402

TEXT_FONT_JSON = os.path.join(ROOT, "data", "text_font.json")
# Lista independiente del generador: alfabeto espanol completo y signos habituales.
SPANISH = (
    "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
    "abcdefghijklmnñopqrstuvwxyz"
    "ÁÉÍÓÚÜáéíóúü"
    "0123456789"
    "¿?¡!.,;:-–—\"'()/%+… "
)
# Claves cuyo valor es texto que el jugador ve.
TEXT_KEYS = ("text", "speaker_name")


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def font_chars():
    data = load_json(TEXT_FONT_JSON)
    info, chars, page = vua.parse_fnt(vua.res_to_path(data["font"]))
    return data, info, chars, page


def collect_texts(node, out, keys=TEXT_KEYS):
    """Recorre un JSON y guarda los valores de texto de las claves de `keys`."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k.startswith("_"):
                continue
            if k in keys and isinstance(v, str):
                out.append(v)
            else:
                collect_texts(v, out, keys)
    elif isinstance(node, list):
        for v in node:
            collect_texts(v, out, keys)
    return out


def ability_notice_strings():
    """Piezas de los avisos de control (data/ability_notices.json) sin las marcas {..}."""
    data = load_json(os.path.join(ROOT, "data", "ability_notices.json"))
    out = [data["hold_prefix"]]
    for key in ("control_format", "pad_button_format"):
        out.append(re.sub(r"\{[a-z]+\}", "", data[key]))
    for key in ("key_names", "pad_buttons", "pad_axes"):
        out.extend(v for k, v in data[key].items() if not k.startswith("_"))
    for entry in data["abilities"].values():
        out.append(entry["name"])
        out.append(re.sub(r"\{[a-z]+\}", "", entry["text"]))
    return out


def game_strings():
    texts = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "levels", "*.json"))):
        level = load_json(path)
        texts.append(level.get("name", ""))
        collect_texts(level, texts)
    collect_texts(load_json(os.path.join(ROOT, "data", "world1_objects.json")), texts)
    eco_path = os.path.join(ROOT, "data", "eco_text_box.json")
    if os.path.exists(eco_path):
        collect_texts(load_json(eco_path), texts)
    texts.extend(ability_notice_strings())
    # Encuentro con Eco (data/eco_encounter.json): lineas y aviso del pulso.
    encounter = load_json(os.path.join(ROOT, "data", "eco_encounter.json"))
    for key in ("intro", "gift", "outro"):
        texts.extend(t.replace("{apodo}", "") for t in encounter[key])
    texts.append(encounter["notice"]["name"])
    texts.append(re.sub(r"\{[a-z]+\}", "", encounter["notice"]["text"]))
    # Ayuda de Eco con Q (data/help.json): titulos y textos de cada tipo.
    for entry in load_json(os.path.join(ROOT, "data", "help.json"))["types"].values():
        texts.append(entry["title"])
        texts.append(entry["text"].replace("{apodo}", ""))
    # Menu de pausa (data/pause_menu.json): todos sus textos sin las marcas {..}.
    pause = load_json(os.path.join(ROOT, "data", "pause_menu.json"))
    texts.extend(re.sub(r"\{[a-z_]+\}", "", v) for k, v in pause["texts"].items() if not k.startswith("_"))
    hud = load_json(os.path.join(ROOT, "data", "hud.json"))
    texts.append(hud["font_glyphs"])
    texts.append("100 % 0 % 999")
    return [t for t in texts if t]


class TextFontTest(unittest.TestCase):
    def test_spanish_coverage(self):
        _, _, chars, _ = font_chars()
        missing = [c for c in SPANISH if ord(c) not in chars]
        self.assertEqual(missing, [], "Faltan glifos del espanol")

    def test_font_glyphs_list_matches_fnt(self):
        data, _, chars, _ = font_chars()
        self.assertEqual(sorted(chars), sorted({ord(c) for c in data["font_glyphs"]}))
        self.assertGreaterEqual(len(chars), 75)
        self.assertLessEqual(len(chars), 100)

    def test_game_strings_use_existing_glyphs(self):
        _, _, chars, _ = font_chars()
        texts = game_strings()
        self.assertIn("Bienvenido. He optimizado tu espacio.", texts)
        self.assertIn("Marcar como leído", texts)
        for text in texts:
            missing = sorted({c for c in text if ord(c) not in chars})
            self.assertEqual(missing, [], "Glifos que faltan en %r" % text)

    def test_metrics(self):
        data, info, chars, _ = font_chars()
        self.assertEqual(int(info["size"]), data["font_size"])
        self.assertEqual(int(info["lineHeight"]), 13)
        self.assertEqual(int(info["base"]), 10)
        fw, fh = data["assets"]["font"]["frame_size"]
        for cid, c in chars.items():
            if cid == ord(" "):
                self.assertGreater(c["xadvance"], 0)
                continue
            self.assertEqual(c["height"], data["font_size"], chr(cid))
            self.assertLessEqual(c["width"], fw, chr(cid))
            self.assertEqual(c["xadvance"], 6 if chr(cid).isdigit() else c["width"] + 1, chr(cid))
        # Estrechos para leer mejor: i y l mas estrechas que la m.
        self.assertLess(chars[ord("i")]["width"], chars[ord("m")]["width"])
        self.assertLess(chars[ord("l")]["width"], chars[ord("m")]["width"])

    def test_glyphs_inside_their_rows(self):
        """Acentos de mayuscula en filas 0-1, nada por debajo de la fila 11, base en la 10."""
        data, _, chars, _ = font_chars()
        atlas = Image.open(vua.res_to_path(data["assets"]["font"]["path"])).convert("RGBA")
        alpha = atlas.getchannel("A")

        def bbox(ch):
            c = chars[ord(ch)]
            return alpha.crop((c["x"], c["y"], c["x"] + c["width"], c["y"] + c["height"])).getbbox()

        self.assertEqual(bbox("A")[1], 3)          # mayuscula desde la fila 3
        self.assertEqual(bbox("A")[3], 10)         # termina en la fila 9 (base 10)
        self.assertEqual(bbox("Á")[1], 0)          # tilde dentro de la celda
        self.assertEqual(bbox("Ñ")[1], 0)
        self.assertEqual(bbox("á")[1], 2)
        for ch in "gjpqy":
            self.assertEqual(bbox(ch)[3], 12, ch)  # descendente hasta la fila 11
        self.assertEqual(bbox("o")[1], 5)          # altura x de 5

    def test_digits_match_hud(self):
        data, _, chars, _ = font_chars()
        hud = load_json(os.path.join(ROOT, "data", "hud.json"))
        _, hud_chars, _ = vua.parse_fnt(vua.res_to_path(hud["font"]))
        hud_atlas = Image.open(vua.res_to_path(hud["assets"]["font"]["path"])).convert("RGBA")
        atlas = Image.open(vua.res_to_path(data["assets"]["font"]["path"])).convert("RGBA")
        for ch in "0123456789%":
            h, t = hud_chars[ord(ch)], chars[ord(ch)]
            a = hud_atlas.crop((h["x"], h["y"], h["x"] + h["width"], h["y"] + h["height"]))
            b = atlas.crop((t["x"], t["y"] + 3, t["x"] + t["width"], t["y"] + 10))
            self.assertEqual(list(a.getdata()), list(b.getdata()), ch)

    def test_validate_ui_assets(self):
        result = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_ui_assets.py")],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
