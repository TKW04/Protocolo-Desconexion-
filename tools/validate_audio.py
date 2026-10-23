#!/usr/bin/env python3
"""Valida el catalogo de audio data/audio.json (2026-10-20; docs/lista-sonidos.md, «Integracion»).

Comprueba:
  - buses: exactamente los seis de default_bus_layout.tres (Master, Music, World, Ambience,
    Voice, UI) y que el .tres los define (todos envian a Master);
  - sounds: ids con prefijo sfx_, amb_, mus_, stg_, vox_ o ui_ (minusculas, digitos y '_') y sin
    las palabras de las vueltas (vuelta, easy, normal, hard); bus uno de buses; files lista de
    nombres (sin '/' ni '..'), con extension de extensions si la traen; volume_db entre -40 y 6;
    pitch_random entre 0 y 0,5; cooldown_s >= 0; loop y cue booleanos; time real o world; las
    entradas loop no usan time world;
  - event_bus: cada signal declarada en scripts/autoload/event_bus.gd;
  - nodes / ambience / steps: la clase existe (class_name en scripts/) y, en nodes, la senal la
    declara esa clase o una de la que hereda; when es un diccionario indice -> valor;
  - todo sonido referenciado (event_bus, nodes, ambience, steps, text_blips) esta en sounds;
  - text_blips: every_chars >= 1; cada interlocutor con sound o by_lap {1, 2, 3}.
Los archivos AUSENTES no son error (el AudioManager los ignora en silencio): se listan con --missing.

Uso (desde la raiz del repo): python3 tools/validate_audio.py [--missing] [data/audio.json]
Sale con 1 si hay errores.
"""
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PATH = os.path.join(REPO, "data", "audio.json")
LAYOUT_PATH = os.path.join(REPO, "default_bus_layout.tres")
EVENT_BUS_PATH = os.path.join(REPO, "scripts", "autoload", "event_bus.gd")
BUSES = ["Master", "Music", "World", "Ambience", "Voice", "UI"]
PREFIXES = ("sfx_", "amb_", "mus_", "stg_", "vox_", "ui_")
ID_RE = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*$")
LAP_WORDS = ("vuelta", "easy", "normal", "hard")
TIMES = ("real", "world")


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def layout_buses(path=LAYOUT_PATH):
    """Buses del .tres: Master (siempre el 0) y los bus/N/name, con su send."""
    if not os.path.exists(path):
        return None
    text = _read(path)
    names = {int(i): n for i, n in re.findall(r'^bus/(\d+)/name = &"([^"]+)"', text, re.M)}
    sends = {int(i): n for i, n in re.findall(r'^bus/(\d+)/send = &"([^"]+)"', text, re.M)}
    names.setdefault(0, "Master")
    return {names[i]: sends.get(i, "") for i in sorted(names)}


def event_bus_signals(path=EVENT_BUS_PATH):
    return set(re.findall(r"^signal (\w+)", _read(path), re.M))


def script_classes(root=os.path.join(REPO, "scripts")):
    """class_name -> (senales propias, clase base o None)."""
    out = {}
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith(".gd"):
                continue
            text = _read(os.path.join(dirpath, name))
            m = re.search(r"^class_name (\w+)", text, re.M)
            if not m:
                continue
            base = re.search(r"^extends (\w+)", text, re.M)
            out[m.group(1)] = (set(re.findall(r"^signal (\w+)", text, re.M)), base.group(1) if base else None)
    return out


def class_has_signal(classes, cls, signal):
    seen = set()
    while cls in classes and cls not in seen:
        seen.add(cls)
        signals, base = classes[cls]
        if signal in signals:
            return True
        cls = base
    return False


def _number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def validate(data, layout=None, bus_signals=None, classes=None):
    errors = []
    layout = layout_buses() if layout is None else layout
    bus_signals = event_bus_signals() if bus_signals is None else bus_signals
    classes = script_classes() if classes is None else classes
    if data.get("buses") != BUSES:
        errors.append("buses debe ser %s" % BUSES)
    if layout is None:
        errors.append("falta default_bus_layout.tres")
    else:
        for bus in BUSES:
            if bus not in layout:
                errors.append("default_bus_layout.tres no define el bus %s" % bus)
            elif bus != "Master" and layout[bus] != "Master":
                errors.append("el bus %s debe enviar a Master" % bus)
    exts = data.get("extensions", [])
    if not isinstance(exts, list) or not exts or not all(isinstance(e, str) and e for e in exts):
        errors.append("extensions debe ser una lista de extensiones")
        exts = []
    sounds = data.get("sounds")
    if not isinstance(sounds, dict) or not sounds:
        return errors + ["sounds debe ser un diccionario no vacio"]
    for sid, entry in sounds.items():
        where = "sounds.%s" % sid
        if not ID_RE.match(sid) or not sid.startswith(PREFIXES):
            errors.append("%s: id con prefijo %s, minusculas y '_'" % (where, "/".join(PREFIXES)))
        if any(w in sid for w in LAP_WORDS):
            errors.append("%s: el id no nombra la vuelta" % where)
        if not isinstance(entry, dict):
            errors.append("%s: no es un diccionario" % where)
            continue
        if entry.get("bus") not in BUSES:
            errors.append("%s: bus %r no es uno de %s" % (where, entry.get("bus"), BUSES))
        files = entry.get("files", [sid])
        if not isinstance(files, list) or not files:
            errors.append("%s: files debe ser una lista no vacia" % where)
            files = []
        for f in files:
            if not isinstance(f, str) or not f or "/" in f or ".." in f:
                errors.append("%s: archivo %r no valido (solo el nombre)" % (where, f))
            elif "." in f and f.rsplit(".", 1)[1] not in exts:
                errors.append("%s: extension de %r no esta en extensions" % (where, f))
        vol = entry.get("volume_db", 0.0)
        if not _number(vol) or not -40.0 <= vol <= 6.0:
            errors.append("%s: volume_db entre -40 y 6" % where)
        pitch = entry.get("pitch_random", 0.0)
        if not _number(pitch) or not 0.0 <= pitch <= 0.5:
            errors.append("%s: pitch_random entre 0 y 0,5" % where)
        cooldown = entry.get("cooldown_s", 0.0)
        if not _number(cooldown) or cooldown < 0:
            errors.append("%s: cooldown_s >= 0" % where)
        for key in ("loop", "cue"):
            if key in entry and not isinstance(entry[key], bool):
                errors.append("%s: %s debe ser booleano" % (where, key))
        time = entry.get("time", "real")
        if time not in TIMES:
            errors.append("%s: time debe ser real o world" % where)
        if entry.get("loop") and time == "world":
            errors.append("%s: un bucle no sigue el tiempo del mundo" % where)

    def need_sound(where, sid):
        if sid not in sounds:
            errors.append("%s: sonido %r no esta en sounds" % (where, sid))

    def check_when(where, item):
        when = item.get("when", {})
        if not isinstance(when, dict) or not all(re.fullmatch(r"\d+", str(k)) for k in when):
            errors.append("%s: when debe ser {indice: valor}" % where)

    for i, item in enumerate(data.get("event_bus", [])):
        where = "event_bus[%d]" % i
        if not isinstance(item, dict):
            errors.append("%s: no es un diccionario" % where)
            continue
        if item.get("signal") not in bus_signals:
            errors.append("%s: EventBus no declara la senal %r" % (where, item.get("signal")))
        need_sound(where, item.get("sound"))
        check_when(where, item)
    for section in ("nodes", "ambience"):
        for i, item in enumerate(data.get(section, [])):
            where = "%s[%d]" % (section, i)
            if not isinstance(item, dict):
                errors.append("%s: no es un diccionario" % where)
                continue
            cls = item.get("class")
            if cls not in classes:
                errors.append("%s: no hay class_name %r en scripts/" % (where, cls))
            elif section == "nodes" and not class_has_signal(classes, cls, item.get("signal")):
                errors.append("%s: %s no declara la senal %r" % (where, cls, item.get("signal")))
            need_sound(where, item.get("sound"))
            if section == "nodes":
                check_when(where, item)
            if section == "ambience" and sounds.get(item.get("sound"), {}).get("loop") is not True:
                errors.append("%s: el ambiente %r debe tener loop" % (where, item.get("sound")))
            if section == "ambience" and (not isinstance(item.get("priority", 0), int)
                                          or isinstance(item.get("priority", 0), bool)):
                errors.append("%s: priority debe ser un entero" % where)
    fade = data.get("ambience_fade_s", 0.8)
    if isinstance(fade, bool) or not isinstance(fade, (int, float)) or not 0 <= fade <= 5:
        errors.append("ambience_fade_s debe ser un numero entre 0 y 5")
    steps = data.get("steps")
    if steps is not None:
        if not isinstance(steps, dict) or steps.get("class") not in classes:
            errors.append("steps: clase desconocida")
        else:
            need_sound("steps", steps.get("sound"))
            frames = steps.get("frames", {})
            if not isinstance(frames, dict) or not all(
                    isinstance(v, list) and all(isinstance(n, int) and n >= 0 for n in v) for v in frames.values()):
                errors.append("steps: frames debe ser {animacion: [cuadros]}")
    blips = data.get("text_blips")
    if blips is not None:
        if not isinstance(blips.get("every_chars", 1), int) or blips.get("every_chars", 1) < 1:
            errors.append("text_blips: every_chars >= 1")
        for speaker, spec in blips.get("speakers", {}).items():
            where = "text_blips.speakers[%r]" % speaker
            if "by_lap" in spec:
                if sorted(spec["by_lap"]) != ["1", "2", "3"]:
                    errors.append("%s: by_lap con los accesos 1, 2 y 3" % where)
                for sid in spec["by_lap"].values():
                    need_sound(where, sid)
            else:
                need_sound(where, spec.get("sound"))
    return errors


def missing_files(data, audio_root=REPO):
    """IDs sin ningun archivo (no es error: huecos para los sonidos definitivos)."""
    rel = data.get("audio_dir", "res://assets/audio").replace("res://", "")
    folder = os.path.join(audio_root, rel)
    out = []
    for sid, entry in data.get("sounds", {}).items():
        found = False
        for f in entry.get("files", [sid]):
            names = [f] if "." in f else ["%s.%s" % (f, e) for e in data.get("extensions", [])]
            found = found or any(os.path.exists(os.path.join(folder, n)) for n in names)
        if not found:
            out.append(sid)
    return out


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    path = args[0] if args else DEFAULT_PATH
    data = _load(path)
    errors = validate(data)
    for e in errors:
        print("ERROR: %s" % e)
    if errors:
        return 1
    missing = missing_files(data)
    if "--missing" in argv:
        for sid in missing:
            print("sin archivo: %s" % sid)
    print("%s: correcto (%d sonidos, %d sin archivo todavia)" % (
        os.path.relpath(path, REPO), len(data["sounds"]), len(missing)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
