## Parametros de habilidades y dano de Isak cargados desde data/isak_abilities.json.
## Mismo patron que PlayerPhysics: claves obligatorias y numericas.
class_name PlayerAbilities
extends RefCounted

const DEFAULT_PATH: String = "res://data/isak_abilities.json"

const REQUIRED_KEYS: PackedStringArray = [
	"pulse_duration_s",
	"pulse_radius_px",
	"hurt_duration_s",
	"hurt_knockback_x",
	"hurt_knockback_y",
	"hurt_invulnerability_s",
	"laser_energy_cost",
	"laser_damage",
	"laser_cooldown_s",
	"laser_windup_s",
	"laser_speed_px_s",
	"laser_range_px",
	"laser_length_px",
	"laser_thickness_px",
]

var pulse_duration_s: float
var pulse_radius_px: float
var hurt_duration_s: float
## Velocidad horizontal del retroceso (se aplica alejandose del golpe).
var hurt_knockback_x: float
## Velocidad vertical del retroceso (negativa = hacia arriba).
var hurt_knockback_y: float
var hurt_invulnerability_s: float
## Laser (2026-10-15): energia de Debug por disparo, dano, enfriamiento,
## anticipacion, velocidad y alcance del proyectil y su tamano.
var laser_energy_cost: float
var laser_damage: float
var laser_cooldown_s: float
var laser_windup_s: float
var laser_speed_px_s: float
var laser_range_px: float
var laser_length_px: float
var laser_thickness_px: float
## Mientras dura la pose del laser (anticipacion + brazo extendido) Isak no se
## mueve en horizontal: misma regla que el pulso (2026-10-15). Opcional
## (booleano); sin la clave, falso.
var laser_locks_movement: bool = false
## Aspecto provisional del laser (seccion laser_visual; colores y tiempos).
var laser_visual: Dictionary = {}

static var last_error: String = ""


static func load_from_file(path: String = DEFAULT_PATH) -> PlayerAbilities:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("PlayerAbilities: no existe el archivo '%s'." % path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _fail("PlayerAbilities: JSON invalido en '%s' (linea %d): %s." % [path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("PlayerAbilities: '%s' debe contener un objeto JSON." % path)
	return from_dict(json.data, path)


static func from_dict(data: Dictionary, source: String = "<dict>") -> PlayerAbilities:
	last_error = ""
	var abilities := PlayerAbilities.new()
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			return _fail("PlayerAbilities: falta la clave '%s' en '%s'." % [key, source])
		var value: Variant = data[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerAbilities: la clave '%s' en '%s' debe ser numerica." % [key, source])
		abilities.set(key, float(value))
	var locks: Variant = data.get("laser_locks_movement", false)
	if typeof(locks) != TYPE_BOOL:
		return _fail("PlayerAbilities: la clave 'laser_locks_movement' en '%s' debe ser booleana." % source)
	abilities.laser_locks_movement = locks
	var visual: Variant = data.get("laser_visual", {})
	if visual is Dictionary:
		abilities.laser_visual = visual
	return abilities


static func _fail(message: String) -> PlayerAbilities:
	last_error = message
	push_error(message)
	return null
