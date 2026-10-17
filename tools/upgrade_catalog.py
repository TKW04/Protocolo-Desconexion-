"""Catalogo de mejoras de Calc por pistas (data/upgrades.json, tanda M1 de docs/propuesta-mejoras.md).

Lo mismo que scripts/autoload/upgrade_catalog.gd y GameState.effective_value, para las
herramientas de Python (validador de niveles, esquema, pruebas de economia):

- load_catalog(root): el JSON con las pistas.
- parse_upgrades(catalog, ids): convierte "pista:nivel" (p. ej. "laser:3") o un legacy_id
  ("wide_pulse" = "pulso:2") en {pista: nivel}; ValueError si no se conoce.
- effective_value(catalog, levels, target, base): valor efectivo con esos niveles (cada nivel
  comprado e implementado suma su efecto; gana el mas alto).
- purchasable_levels(catalog): los niveles 2-5 de todas las pistas (lo que se compra).
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVEL_MIN = 1


def load_catalog(root=ROOT):
    with open(os.path.join(root, "data", "upgrades.json"), encoding="utf-8") as handle:
        return json.load(handle)


def tracks(catalog):
    return list(catalog.get("tracks", []))


def track(catalog, track_id):
    return next((t for t in tracks(catalog) if t.get("id") == track_id), None)


def level_entry(catalog, track_id, level):
    t = track(catalog, track_id)
    if t is None:
        return None
    return next((lv for lv in t.get("levels", []) if int(lv.get("level", 0)) == int(level)), None)


def legacy_ids(catalog):
    """legacy_id -> (pista, nivel)."""
    out = {}
    for t in tracks(catalog):
        for lv in t.get("levels", []):
            if lv.get("legacy_id"):
                out[str(lv["legacy_id"])] = (str(t["id"]), int(lv["level"]))
    return out


def resolve(catalog, upgrade_id):
    """(pista, nivel) de "pista:nivel" o de un legacy_id; None si no se conoce."""
    text = str(upgrade_id)
    if ":" in text:
        track_id, _, level = text.partition(":")
        if not level.strip().isdigit() or level_entry(catalog, track_id.strip(), int(level)) is None:
            return None
        return track_id.strip(), int(level)
    return legacy_ids(catalog).get(text)


def parse_upgrades(catalog, ids):
    """{pista: nivel} de una lista de ids ("pista:nivel" o legacy_id). ValueError con los
    desconocidos."""
    levels = {}
    unknown = []
    for upgrade_id in ids:
        found = resolve(catalog, upgrade_id)
        if found is None:
            unknown.append(str(upgrade_id))
            continue
        levels[found[0]] = max(levels.get(found[0], LEVEL_MIN), found[1])
    if unknown:
        raise ValueError("mejora desconocida en data/upgrades.json: %s" % ", ".join(unknown))
    return levels


def satisfies(catalog, levels, upgrade_id):
    """Con esos niveles se tiene la mejora `upgrade_id` (GameState.is_upgrade_purchased)."""
    found = resolve(catalog, upgrade_id)
    return found is not None and levels.get(found[0], LEVEL_MIN) >= found[1]


def effective_value(catalog, levels, target, base):
    """Igual que GameState.effective_value: cada nivel comprado e implementado de cada pista
    (en orden) cambia su target; gana el mas alto."""
    value = base
    for t in tracks(catalog):
        owned = int(levels.get(t["id"], LEVEL_MIN))
        for lv in t.get("levels", []):
            if LEVEL_MIN < int(lv["level"]) <= owned and lv.get("implemented", False):
                for effect in lv.get("effects", []):
                    if effect.get("target") == target:
                        value = float(effect["value"])
    return value


def purchasable_levels(catalog):
    """[(pista, entrada de nivel)] de los niveles 2-5 de todas las pistas, en orden."""
    out = []
    for t in tracks(catalog):
        for lv in t.get("levels", []):
            if int(lv["level"]) > LEVEL_MIN:
                out.append((t["id"], lv))
    return out


def access_cap(catalog, track_id, lap):
    """Nivel mas alto comprable en `track_id` con la vuelta `lap` (min_lap de cada nivel)."""
    cap = LEVEL_MIN
    for lv in track(catalog, track_id).get("levels", []):
        if int(lv.get("min_lap", 1)) <= lap:
            cap = max(cap, int(lv["level"]))
    return cap
