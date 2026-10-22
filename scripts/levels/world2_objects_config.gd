## Lee data/world2_objects.json (catalogo de objetos del Mundo 2, sus valores de
## ajuste y la paleta PROVISIONAL de desarrollo; 2026-10-22,
## docs/propuesta-mundo-2.md). Se carga una vez y se comparte. Los tipos genericos
## del Mundo 1 siguen en World1ObjectsConfig.
class_name World2ObjectsConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/world2_objects.json"

static var _shared: Dictionary = {}


## Datos completos del archivo (vacio si no se puede leer).
static func data() -> Dictionary:
	if _shared.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
		if parsed is Dictionary:
			_shared = parsed
		else:
			push_error("World2ObjectsConfig: no se pudo leer %s" % DEFAULT_PATH)
	return _shared


## Seccion de ajustes de un objeto ("fragile_card", "story_card"...).
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
