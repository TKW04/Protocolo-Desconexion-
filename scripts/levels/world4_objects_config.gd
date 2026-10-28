## Lee data/world4_objects.json (catalogo de objetos del Mundo 4, sus valores de
## ajuste y la paleta PROVISIONAL de desarrollo, con el coral del Debug ya decidido;
## 2026-10-27, docs/propuesta-mundo-4.md, paso 0). Se carga una vez y se comparte.
## Los tipos de los Mundos 1-3 siguen en World1ObjectsConfig, World2ObjectsConfig y
## World3ObjectsConfig.
class_name World4ObjectsConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/world4_objects.json"

static var _shared: Dictionary = {}


## Datos completos del archivo (vacio si no se puede leer).
static func data() -> Dictionary:
	if _shared.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
		if parsed is Dictionary:
			_shared = parsed
		else:
			push_error("World4ObjectsConfig: no se pudo leer %s" % DEFAULT_PATH)
	return _shared


## Seccion de ajustes de un objeto ("chat_bubble", "seen_zone"...).
static func section(name: String) -> Dictionary:
	return data().get(name, {})


## Color de la paleta provisional por nombre (`fallback` si no esta).
static func color(name: String, fallback: Color = Color.MAGENTA) -> Color:
	var palette: Dictionary = data().get("palette", {})
	if not palette.has(name):
		return fallback
	return Color(String(palette[name]))


## Tamano de tile (64).
static func tile_size() -> float:
	return float(data().get("tile_size", 64))
