## Datos del hub real (data/hub.json): secciones y colores por rol de
## assets/palettes/hub.gpl. Se lee una vez y se comparte.
class_name HubData
extends RefCounted

const DATA_PATH: String = "res://data/hub.json"

static var _cache: Dictionary = {}


## Todo data/hub.json (vacio si no se puede leer).
static func load_data() -> Dictionary:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_cache = parsed if parsed is Dictionary else {}
	return _cache


## Seccion `name` de data/hub.json (vacia si falta).
static func section(name: String) -> Dictionary:
	var value: Variant = load_data().get(name, {})
	return value if value is Dictionary else {}


## Color del rol `role` de la paleta del hub (colors de data/hub.json, copiados
## de hub.gpl). Magenta si falta, para que se note.
static func color(role: String) -> Color:
	var colors: Dictionary = section("colors")
	return Color.html(String(colors.get(role, "#ff00ff")))


## Tamano de tile en px.
static func tile_size() -> float:
	return float(load_data().get("tile_size", 64))
