## Lee data/world1_objects.json (catalogo de objetos del Mundo 1 y sus valores
## de ajuste). Se carga una vez y se comparte.
class_name World1ObjectsConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/world1_objects.json"

static var _shared: Dictionary = {}


## Datos completos del archivo (vacio si no se puede leer).
static func data() -> Dictionary:
	if _shared.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
		if parsed is Dictionary:
			_shared = parsed
		else:
			push_error("World1ObjectsConfig: no se pudo leer %s" % DEFAULT_PATH)
	return _shared


## Seccion de ajustes de un objeto ("bridge", "receiver", "glitch_wall").
static func section(name: String) -> Dictionary:
	return data().get(name, {})


## Entrada del catalogo para un tipo de la lista `objects` del nivel.
static func type_entry(type: String) -> Dictionary:
	return data().get("types", {}).get(type, {})


## Tamano de tile (64).
static func tile_size() -> float:
	return float(data().get("tile_size", 64))
