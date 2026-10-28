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
## Claves numericas de la seccion opcional ground_pound (propiedad pound_<clave>;
## golpe al suelo, docs/propuesta-mundo-2.md §3.3).
const POUND_KEYS: PackedStringArray = ["air_hold_s", "ground_hold_s", "anticipation_s", "drop_speed_px_s",
	"ground_hop_px", "wave_half_width_px", "wave_height_px", "wave_below_px", "damage", "land_pose_s",
	"cooldown_s", "energy_cost"]
## Claves numericas de la seccion opcional compress (propiedad compress_<clave>;
## Pellizcar, docs/propuesta-mundo-3.md §3.3.1).
const COMPRESS_KEYS: PackedStringArray = ["width_px", "height_px", "squash_s", "walk_speed_px_s",
	"jump_height_px", "energy_cost"]
## Claves numericas de la seccion opcional shockwave (propiedad shockwave_<clave>;
## Agitar, docs/propuesta-mundo-4.md §3.2.1).
const SHOCKWAVE_KEYS: PackedStringArray = ["radius_px", "windup_s", "exposed_s", "stun_s", "energy_cost",
	"cooldown_s"]
## Claves numericas de la seccion opcional frozen (propiedad frozen_<clave>;
## Congelado, docs/propuesta-mundo-4.md §3.3).
const FROZEN_KEYS: PackedStringArray = ["seen_immunity_s", "release_damage", "release_warn_s"]

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
## Golpe al suelo, gesto Mantener presionado (seccion ground_pound, opcional;
## 2026-10-22, docs/propuesta-mundo-2.md §3.3, valores provisionales): tiempo
## mantenido en el aire y en el suelo, anticipacion en el aire, velocidad de
## caida, saltito del golpe desde el suelo, onda (medio ancho, alto y margen bajo
## los pies), dano, pose al aterrizar, enfriamiento y energia.
var pound_air_hold_s: float = 0.12
var pound_ground_hold_s: float = 0.35
var pound_anticipation_s: float = 0.1
var pound_drop_speed_px_s: float = 960.0
var pound_ground_hop_px: float = 32.0
var pound_wave_half_width_px: float = 96.0
var pound_wave_height_px: float = 64.0
var pound_wave_below_px: float = 8.0
var pound_damage: float = 1.0
var pound_land_pose_s: float = 0.35
var pound_cooldown_s: float = 0.4
var pound_energy_cost: float = 0.0
## Aspecto provisional del golpe (ground_pound.visual).
var pound_visual: Dictionary = {}
## Pellizcar (seccion compress, opcional; 2026-10-26, docs/propuesta-mundo-3.md
## §3.3.1, valores provisionales): caja comprimida (ancho y alto, pies abajo),
## tiempo del aplastado del sprite, velocidad al andar (sin correr), altura del
## salto (la gravedad no cambia) y energia (0: gratis).
var compress_width_px: float = 32.0
var compress_height_px: float = 40.0
var compress_squash_s: float = 0.15
var compress_walk_speed_px_s: float = 160.0
var compress_jump_height_px: float = 96.0
var compress_energy_cost: float = 0.0
## Aspecto provisional (compress.visual): escala del sprite comprimido e icono
## «sin espacio».
var compress_visual: Dictionary = {}
## Agitar (seccion shockwave, opcional; 2026-10-28, docs/propuesta-mundo-4.md
## §3.2.1, valores provisionales): radio de la onda alrededor del celular,
## anticipacion (la onda nace al terminarla), exposicion tras la onda (sin
## moverse ni saltar), aturdimiento de los enemigos, energia y enfriamiento
## desde el final de la pose.
var shockwave_radius_px: float = 160.0
var shockwave_windup_s: float = 0.15
var shockwave_exposed_s: float = 0.25
var shockwave_stun_s: float = 3.0
var shockwave_energy_cost: float = 10.0
var shockwave_cooldown_s: float = 1.0
## Agitar RETIRADO del juego (2026-10-28, prueba del usuario: «hace lo mismo que el
## pulso»): shockwave.enabled false. La logica, la pose y los datos se conservan,
## pero Isak.shockwave_denial() lo niega siempre (nunca sale, ni con la habilidad).
var shockwave_enabled: bool = true
## Aspecto provisional (shockwave.visual): sacudida del sprite y anillo de la onda.
var shockwave_visual: Dictionary = {}
## Congelado (seccion frozen, opcional; 2026-10-28, docs/propuesta-mundo-4.md
## §3.3, valores provisionales): tras descongelarse, otra zona «Visto» no lo
## vuelve a congelar durante seen_immunity_s.
var frozen_seen_immunity_s: float = 0.5
## Golpe al liberarse (2026-10-28, prueba del usuario): al terminar SOLA una congelacion,
## Isak recibe un golpe de enemigo (take_hit: retroceso e invulnerabilidad) que resta
## release_damage de Sync SIN MATAR (nunca baja de 1); release_warn_s antes la barra
## avisa en rojo.
var frozen_release_damage: float = 10.0
var frozen_release_warn_s: float = 0.75
## Aspecto provisional (frozen.visual): velo, doble check y barra de segmentos.
var frozen_visual: Dictionary = {}

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
	var pound: Variant = data.get("ground_pound", {})
	if not pound is Dictionary:
		return _fail("PlayerAbilities: la clave 'ground_pound' en '%s' debe ser un objeto." % source)
	for key: String in POUND_KEYS:
		if not (pound as Dictionary).has(key):
			continue
		var value: Variant = pound[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerAbilities: la clave 'ground_pound.%s' en '%s' debe ser numerica." % [key, source])
		abilities.set("pound_" + key, float(value))
	var pound_visual: Variant = (pound as Dictionary).get("visual", {})
	if pound_visual is Dictionary:
		abilities.pound_visual = pound_visual
	var compress: Variant = data.get("compress", {})
	if not compress is Dictionary:
		return _fail("PlayerAbilities: la clave 'compress' en '%s' debe ser un objeto." % source)
	for key: String in COMPRESS_KEYS:
		if not (compress as Dictionary).has(key):
			continue
		var value: Variant = compress[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerAbilities: la clave 'compress.%s' en '%s' debe ser numerica." % [key, source])
		abilities.set("compress_" + key, float(value))
	var compress_visual: Variant = (compress as Dictionary).get("visual", {})
	if compress_visual is Dictionary:
		abilities.compress_visual = compress_visual
	var shockwave: Variant = data.get("shockwave", {})
	if not shockwave is Dictionary:
		return _fail("PlayerAbilities: la clave 'shockwave' en '%s' debe ser un objeto." % source)
	for key: String in SHOCKWAVE_KEYS:
		if not (shockwave as Dictionary).has(key):
			continue
		var value: Variant = shockwave[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerAbilities: la clave 'shockwave.%s' en '%s' debe ser numerica." % [key, source])
		abilities.set("shockwave_" + key, float(value))
	abilities.shockwave_enabled = bool((shockwave as Dictionary).get("enabled", true))
	var shockwave_visual: Variant = (shockwave as Dictionary).get("visual", {})
	if shockwave_visual is Dictionary:
		abilities.shockwave_visual = shockwave_visual
	var frozen: Variant = data.get("frozen", {})
	if not frozen is Dictionary:
		return _fail("PlayerAbilities: la clave 'frozen' en '%s' debe ser un objeto." % source)
	for key: String in FROZEN_KEYS:
		if not (frozen as Dictionary).has(key):
			continue
		var value: Variant = frozen[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return _fail("PlayerAbilities: la clave 'frozen.%s' en '%s' debe ser numerica." % [key, source])
		abilities.set("frozen_" + key, float(value))
	var frozen_visual: Variant = (frozen as Dictionary).get("visual", {})
	if frozen_visual is Dictionary:
		abilities.frozen_visual = frozen_visual
	return abilities


static func _fail(message: String) -> PlayerAbilities:
	last_error = message
	push_error(message)
	return null
