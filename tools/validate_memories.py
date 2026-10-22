#!/usr/bin/env python3
"""Valida el esquema de data/memories.json (recuerdos; docs/propuesta-recuerdos.md §7 paso 1 y §10).

Comprueba:
  - lista `memories` con ids unicos (minusculas, digitos y '_');
  - world entero 1-6; kind boss o secret; title y text no vacios; order entero >= 1, unico
    dentro de cada mundo y tipo;
  - jefe (boss): layer 1-3 y exactamente las 3 capas por cada uno de los 6 mundos (18); sin
    campos de mensaje (sender, subject, level, secret, first_lap);
  - mensaje de secreto (secret): sin layer; sender y subject no vacios; level «W-N» del mismo
    mundo y registrado en worlds de data/hub.json; secret no vacio y, si el nivel ya tiene su
    data/levels/<level>.json, uno de los ids de su array secrets; first_lap entero 1-3 y una de
    las vueltas (laps) del subnivel en data/hub.json (reaparece en las siguientes si no se obtuvo);
  - textos solo con glifos de la fuente de textos (data/text_font.json) y sin las palabras de las
    vueltas (la UI nunca dice vuelta, Easy, Normal ni Hard);
  - coherencia mensaje <-> secreto del nivel (2026-10-19, paso 4 de docs/propuesta-recuerdos.md): si
    el nivel del mensaje ya tiene JSON, su secreto `secret` lo ofrece (recompensa memory con su
    memory_id) y el nivel tiene un objeto memory_pickup con ese memory_id; y al reves, toda
    recompensa memory y todo memory_pickup de data/levels/*.json apunta a un mensaje (kind secret)
    de ese nivel y de ese secreto (una sala de prueba con stands_for «W-N», de ese subnivel;
    2026-10-20, paso 7 de docs/propuesta-1-3.md: la sala «Excepciones» con msg_1_3).

Uso (desde la raiz del repo): python3 tools/validate_memories.py [data/memories.json]
Sale con 1 si hay errores.
"""
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PATH = os.path.join(REPO, "data", "memories.json")
WORLDS = range(1, 7)
LAYERS = (1, 2, 3)
LAPS = (1, 2, 3)
KINDS = ("boss", "secret")
ID_RE = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*$")
LEVEL_RE = re.compile(r"^(\d+)-(\d+)$")
MESSAGE_FIELDS = ("sender", "subject", "level", "secret", "first_lap")
TEXT_FIELDS = ("title", "text", "sender", "subject")
LAP_WORDS = re.compile(r"\b(vuelta|vueltas|easy|normal|hard)\b", re.IGNORECASE)
# Largo maximo del texto de un recuerdo (2026-10-22, paso 6): con la ilustracion de la
# ficha de Notas y el panel de BossReward, unas 7 lineas de la fuente de textos.
MAX_TEXT_CHARS = 280


def _load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def font_glyphs(repo=REPO):
    """Caracteres del .fnt de la fuente de textos (o None si no se encuentra)."""
    try:
        font = _load(os.path.join(repo, "data", "text_font.json"))["font"]
        path = os.path.join(repo, font.replace("res://", "", 1))
        chars = set()
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r"\s*char\s+id=(\d+)", line)
                if m:
                    chars.add(chr(int(m.group(1))))
        return chars or None
    except (OSError, KeyError, ValueError):
        return None


def hub_levels(repo=REPO):
    """{id de subnivel: (mundo, [vueltas])} de worlds de data/hub.json."""
    out = {}
    for world in _load(os.path.join(repo, "data", "hub.json")).get("worlds", []):
        for level in world.get("levels", []):
            out[str(level.get("id", ""))] = (int(world.get("world", 0)), list(level.get("laps", [1])))
    return out


def level_secrets(level_id, repo=REPO):
    """Ids del array secrets del nivel, o None si su JSON aun no existe."""
    path = os.path.join(repo, "data", "levels", "%s.json" % level_id)
    if not os.path.exists(path):
        return None
    return {str(s.get("id", "")) for s in _load(path).get("secrets", [])}


def level_links(repo=REPO):
    """{id de nivel: {"secrets": {secreto: memory_id o None}, "pickups": {memory_id}}} de todos los
    data/levels/*.json (recompensa memory de cada secreto y memory_pickup de los objetos)."""
    out = {}
    folder = os.path.join(repo, "data", "levels")
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".json"):
            continue
        level = _load(os.path.join(folder, name))
        secrets = {}
        for s in level.get("secrets", []):
            rewards = s.get("reward", [])
            rewards = [rewards] if isinstance(rewards, str) else list(rewards or [])
            secrets[str(s.get("id", ""))] = s.get("memory_id") if "memory" in rewards else None
        pickups = {str(o.get("params", {}).get("memory_id", "")) for o in level.get("objects", [])
                   if o.get("type") == "memory_pickup"}
        out[str(level.get("id", name[:-5]))] = {"secrets": secrets, "pickups": pickups,
                                                "stands_for": level.get("stands_for")}
    return out


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def validate(data, repo=REPO, glyphs="auto", levels=None, secrets_of=None, links=None):
    """Lista de errores (vacia si todo es correcto). `levels`, `secrets_of` y `links` (formato de
    level_links) permiten pruebas sinteticas (por defecto se leen de data/hub.json y data/levels/;
    con `secrets_of` sintetico y sin `links` no se comprueba la coherencia con los objetos)."""
    errors = []
    if glyphs == "auto":
        glyphs = font_glyphs(repo)
    if levels is None:
        levels = hub_levels(repo)
    if secrets_of is None:
        secrets_of = lambda lid: level_secrets(lid, repo)  # noqa: E731
        if links is None:
            links = level_links(repo)
    items = data.get("memories") if isinstance(data, dict) else None
    if not isinstance(items, list) or not items:
        return ["falta la lista 'memories' (o esta vacia)"]
    seen = set()
    orders = set()
    layers = {w: [] for w in WORLDS}
    for i, m in enumerate(items):
        if not isinstance(m, dict):
            errors.append("entrada %d: no es un objeto" % i)
            continue
        mid = m.get("id")
        where = "recuerdo %s" % (mid if isinstance(mid, str) else "#%d" % i)
        if not isinstance(mid, str) or not ID_RE.match(mid):
            errors.append("%s: id no valido (minusculas, digitos y '_')" % where)
        elif mid in seen:
            errors.append("%s: id repetido" % where)
        else:
            seen.add(mid)
        world = m.get("world")
        if not _is_int(world) or world not in WORLDS:
            errors.append("%s: world debe ser un entero de 1 a 6" % where)
            world = None
        kind = m.get("kind")
        if kind not in KINDS:
            errors.append("%s: kind debe ser boss o secret" % where)
        for field in ("title", "text"):
            if not isinstance(m.get(field), str) or not m[field].strip():
                errors.append("%s: falta %s" % (where, field))
        order = m.get("order")
        if not _is_int(order) or order < 1:
            errors.append("%s: order debe ser un entero >= 1" % where)
        elif (world, kind, order) in orders:
            errors.append("%s: order %d repetido en el mundo %s (%s)" % (where, order, world, kind))
        else:
            orders.add((world, kind, order))
        if kind == "boss":
            layer = m.get("layer")
            if not _is_int(layer) or layer not in LAYERS:
                errors.append("%s: layer debe ser 1, 2 o 3 (Caché, Kernel, Raíz)" % where)
            elif world is not None:
                layers[world].append(layer)
            for field in MESSAGE_FIELDS:
                if field in m:
                    errors.append("%s: un recuerdo de jefe no lleva %s" % (where, field))
        elif kind == "secret":
            if "layer" in m:
                errors.append("%s: un mensaje de secreto no lleva layer" % where)
            for field in ("sender", "subject"):
                if not isinstance(m.get(field), str) or not m[field].strip():
                    errors.append("%s: un mensaje necesita %s" % (where, field))
            _check_message_place(m, where, world, levels, secrets_of, errors)
            _check_message_links(m, where, links, errors)
        for field in TEXT_FIELDS:
            value = m.get(field)
            if not isinstance(value, str):
                continue
            if glyphs:
                missing = sorted({c for c in value if c not in glyphs and c != "\n"})
                if missing:
                    errors.append("%s: %s usa glifos que no tiene la fuente: %s" % (where, field, " ".join(missing)))
            if field == "text" and len(value) > MAX_TEXT_CHARS:
                errors.append("%s: text demasiado largo (%d > %d caracteres; no cabe en la ficha)"
                              % (where, len(value), MAX_TEXT_CHARS))
            if LAP_WORDS.search(value):
                errors.append("%s: %s nombra las vueltas (usa Caché, Kernel o Raíz)" % (where, field))
    _check_level_links(items, links, errors)
    for world in WORLDS:
        if sorted(layers[world]) != list(LAYERS):
            errors.append("mundo %d: el jefe debe tener exactamente las capas 1, 2 y 3 (tiene %s)"
                          % (world, sorted(layers[world])))
    return errors


def _check_message_place(m, where, world, levels, secrets_of, errors):
    level = m.get("level")
    if not isinstance(level, str) or not LEVEL_RE.match(level):
        errors.append("%s: level debe ser un subnivel «W-N»" % where)
        level = None
    elif world is not None and int(LEVEL_RE.match(level).group(1)) != world:
        errors.append("%s: el nivel %s no es del mundo %d" % (where, level, world))
    elif level not in levels:
        errors.append("%s: el nivel %s no esta en worlds de data/hub.json" % (where, level))
        level = None
    secret = m.get("secret")
    if not isinstance(secret, str) or not secret.strip():
        errors.append("%s: falta el secreto que lo ofrece (secret)" % where)
    elif level is not None:
        ids = secrets_of(level)
        if ids is not None and secret not in ids:
            errors.append("%s: el nivel %s no tiene el secreto %s" % (where, level, secret))
    first = m.get("first_lap")
    if not _is_int(first) or first not in LAPS:
        errors.append("%s: first_lap debe ser 1, 2 o 3 (Caché, Kernel, Raíz)" % where)
    elif level is not None and first not in levels[level][1]:
        errors.append("%s: el nivel %s no existe en el acceso %d (laps de data/hub.json)" % (where, level, first))


def _check_message_links(m, where, links, errors):
    """El secreto del mensaje lo ofrece (recompensa memory) y el nivel tiene su memory_pickup."""
    if not links or not isinstance(m.get("level"), str) or m["level"] not in links:
        return
    info = links[m["level"]]
    secret = m.get("secret")
    if secret not in info["secrets"]:
        return  # ya lo dice _check_message_place
    if info["secrets"][secret] != m.get("id"):
        errors.append("%s: el secreto %s del nivel %s no lo ofrece (recompensa memory con memory_id %s)"
                      % (where, secret, m["level"], m.get("id")))
    if m.get("id") not in info["pickups"]:
        errors.append("%s: el nivel %s no tiene ningun memory_pickup con memory_id %s"
                      % (where, m["level"], m.get("id")))


def _check_level_links(items, links, errors):
    """Al reves: cada recompensa memory y cada memory_pickup de los niveles apunta a un mensaje
    (kind secret) de ese nivel y de ese secreto."""
    if not links:
        return
    by_id = {m.get("id"): m for m in items if isinstance(m, dict)}
    for level_id in sorted(links):
        info = links[level_id]
        for secret, mid in sorted(info["secrets"].items()):
            if mid is None:
                continue
            m = by_id.get(mid)
            if m is None or m.get("kind") != "secret":
                errors.append("nivel %s, secreto %s: la recompensa memory apunta a %s, que no es un mensaje "
                              "de data/memories.json" % (level_id, secret, mid))
            elif m.get("level") != (info.get("stands_for") or level_id) or m.get("secret") != secret:
                errors.append("nivel %s, secreto %s: el mensaje %s es del nivel %s y del secreto %s"
                              % (level_id, secret, mid, m.get("level"), m.get("secret")))
        for mid in sorted(info["pickups"]):
            m = by_id.get(mid)
            if m is None or m.get("kind") != "secret":
                errors.append("nivel %s: memory_pickup con memory_id %s, que no es un mensaje de "
                              "data/memories.json" % (level_id, mid))
            elif m.get("level") != (info.get("stands_for") or level_id):
                errors.append("nivel %s: memory_pickup del mensaje %s, que es del nivel %s"
                              % (level_id, mid, m.get("level")))


def main(argv):
    path = argv[1] if len(argv) > 1 else DEFAULT_PATH
    errors = validate(_load(path))
    for e in errors:
        print("ERROR: %s" % e)
    if errors:
        return 1
    print("%s: correcto" % os.path.relpath(path, REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
