## Parametros de fisica de Isak cargados desde data/isak_physics.json.
## El validador de niveles (Python) lee el mismo JSON: esta clase es la
## unica fuente de verdad en GDScript. No contiene el jugador ni sus estados.
class_name PlayerPhysics
extends RefCounted

const DEFAULT_PATH: String = "res://data/isak_physics.json"

## Claves numericas obligatorias del JSON (las que empiezan por "_" son notas).
const REQUIRED_KEYS: PackedStringArray = [
	"jump_height_px",
	"time_to_apex_s",
	"jump_velocity",
	"gravity",
	"fall_gravity_multiplier",
	"walk_speed",
	"run_speed",
	"coyote_time_s",
	"jump_buffer_s",
	"tile_size",
	"ground_acceleration",
	"ground_friction",
	"air_acceleration",
]

var jump_height_px: float
var time_to_apex_s: float
var jump_velocity: float
var gravity: float
var fall_gravity_multiplier: float
var walk_speed: float
var run_speed: float
var coyote_time_s: float
var jump_buffer_s: float
var tile_size: float
var ground_acceleration: float
var ground_friction: float
var air_acceleration: float

## Ultimo error de carga ("" si la ultima carga fue correcta).
static var last_error: String = ""


## Carga y valida el JSON. Devuelve null y registra un error claro si falla.
static func load_from_file(path: String = DEFAULT_PATH) -> PlayerPhysics:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("PlayerPhysics: no existe el archivo de fisica '%s'." % path)
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("PlayerPhysics: JSON invalido en '%s' (linea %d): %s." % [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("PlayerPhysics: '%s' debe contener un objeto JSON." % path)
	return from_dict(json.data, path)


## Construye desde un diccionario ya parseado. `source` solo se usa en mensajes.
static func from_dict(data: Dictionary, source: String = "<dict>") -> PlayerPhysics:
	last_error = ""
	var physics := PlayerPhysics.new()
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			return _fail("PlayerPhysics: falta la clave '%s' en '%s'." % [key, source])
		var value: Variant = data[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerPhysics: la clave '%s' en '%s' debe ser numerica." % [key, source])
		physics.set(key, float(value))
	return physics


## Altura maxima de un salto completo (v^2 / 2g).
func max_jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * gravity)


## Alcance horizontal de un salto completo en llano a velocidad constante.
## Subida: t_up = |v| / g. Bajada desde la misma altura h con gravedad g*m:
## t_down = sqrt(2h / (g*m)) = t_up / sqrt(m). Alcance = speed * (t_up + t_down).
func horizontal_reach(speed: float) -> float:
	var t_up: float = absf(jump_velocity) / gravity
	var t_down: float = sqrt(2.0 * max_jump_height() / (gravity * fall_gravity_multiplier))
	return speed * (t_up + t_down)


static func _fail(message: String) -> PlayerPhysics:
	last_error = message
	push_error(message)
	return null
