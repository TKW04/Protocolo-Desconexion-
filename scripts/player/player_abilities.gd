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

## Claves numericas opcionales (0 si faltan): efectos de las mejoras de Calc.
const OPTIONAL_KEYS: PackedStringArray = ["laser_pierce", "pulse_energy_on_stun"]
## Claves numericas de la seccion opcional dash (propiedad dash_<clave>).
const DASH_KEYS: PackedStringArray = ["distance_px", "duration_s", "invulnerable_s", "energy_cost",
	"cooldown_s", "end_speed_px_s", "air_dashes"]

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
## Mejoras de Calc, tanda M2 (opcionales; base 0 en data/isak_abilities.json):
## Laser 5 atraviesa enemigos (1 = si) y Pulso 5 da energia al aturdir (4).
var laser_pierce: float = 0.0
var pulse_energy_on_stun: float = 0.0
## Dash, gesto Deslizar (seccion dash, opcional; 2026-10-19, docs/propuesta-1-3.md
## §2.1, valores provisionales): distancia, duracion, invulnerabilidad desde el
## inicio, coste de energia, enfriamiento desde el final, velocidad al terminar y
## dashes por estancia en el aire. Sin la seccion valen estos valores por defecto.
var dash_distance_px: float = 192.0
var dash_duration_s: float = 0.2
var dash_invulnerable_s: float = 0.3
var dash_energy_cost: float = 10.0
var dash_cooldown_s: float = 0.5
var dash_end_speed_px_s: float = 360.0
var dash_air_dashes: int = 1
## Aspecto provisional del dash (dash.visual).
var dash_visual: Dictionary = {}

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
	for key: String in OPTIONAL_KEYS:
		var optional: Variant = data.get(key, 0.0)
		if typeof(optional) != TYPE_FLOAT and typeof(optional) != TYPE_INT:
			return _fail("PlayerAbilities: la clave '%s' en '%s' debe ser numerica." % [key, source])
		abilities.set(key, float(optional))
	var visual: Variant = data.get("laser_visual", {})
	if visual is Dictionary:
		abilities.laser_visual = visual
	var dash: Variant = data.get("dash", {})
	if not dash is Dictionary:
		return _fail("PlayerAbilities: la clave 'dash' en '%s' debe ser un objeto." % source)
	for key: String in DASH_KEYS:
		if not (dash as Dictionary).has(key):
			continue
		var value: Variant = dash[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerAbilities: la clave 'dash.%s' en '%s' debe ser numerica." % [key, source])
		if key == "air_dashes":
			abilities.dash_air_dashes = maxi(int(value), 0)
		else:
			abilities.set("dash_" + key, float(value))
	var dash_visual: Variant = (dash as Dictionary).get("visual", {})
	if dash_visual is Dictionary:
		abilities.dash_visual = dash_visual
	return abilities


static func _fail(message: String) -> PlayerAbilities:
	last_error = message
	push_error(message)
	return null
