## Ocultarte (Pulso 4 de las mejoras de Calc; tanda M2 de
## docs/propuesta-mejoras.md §4). Estado activo de Isak: lo tiene cada Isak
## (Isak.get_hide_mode) y lo avanza Isak.step con el delta REAL. Valores y reglas
## en data/hide_mode.json (ver sus _notes):
## - Accion `hide` (H / L3): pulsacion corta para activar (en el suelo, fuera de
##   una pose, en un nivel, con el Pulso 4 comprado y por encima del 15 % del
##   Sync Rate y de la energia) y otra para apagarlo (tambien en el aire).
## - Gasta 5 de energia y 1,5 de Sync Rate por segundo real; se corta solo cuando
##   el Sync Rate o la energia llegan al 10 % del maximo efectivo (el primero que
##   llegue; el gasto se para ahi, nunca mata).
## - Lo apagan el pulso, el laser (al empezar la pose) y el dash (al empezar;
##   tampoco se activa durante un dash; 2026-10-19), recibir dano, activar el
##   Debug (y activarlo apaga el Debug: no se combinan), morir, los vortices, la
##   pose de espaldas y reaparecer. No se corre mientras dura.
## - GameState.set_player_hidden avisa a los enemigos (EventBus.hide_changed);
##   EventBus.hide_ended dice por que se apago.
## - Visual: shader assets/shaders/hide_glitch.gdshader en el sprite (entrada y
##   salida, aviso por debajo del 20 % y destello al cortarse solo).
class_name HideMode
extends RefCounted

## Se activa / se apaga (`reason` = REASON_*).
signal started
signal ended(reason: StringName)

const DATA_PATH: String = "res://data/hide_mode.json"
const SHADER_PATH: String = "res://assets/shaders/hide_glitch.gdshader"
const REASON_TOGGLE: StringName = &"toggle"
const REASON_CUT: StringName = &"cut"
const REASON_PULSE: StringName = &"pulse"
const REASON_LASER: StringName = &"laser"
## El dash (gesto Deslizar, 2026-10-19) lo apaga como el pulso y el laser.
const REASON_DASH: StringName = &"dash"
## Golpe al suelo (2026-10-22): lo apaga como el pulso y el laser.
const REASON_POUND: StringName = &"ground_pound"
const REASON_HURT: StringName = &"hurt"
const REASON_DEBUG: StringName = &"debug"
const REASON_DEAD: StringName = &"dead"
const REASON_WARP: StringName = &"warp"
const REASON_RESET: StringName = &"reset"
## Motivos de no poder activarlo (try_activate).
enum Denied { NONE, NOT_OWNED, NOT_IN_LEVEL, NOT_ON_FLOOR, BUSY, LOW_SYNC, LOW_ENERGY }
const EPS: float = 0.0001

var energy_per_s: float = 5.0
var sync_per_s: float = 1.5
var enter_min_fraction: float = 0.15
var cut_fraction: float = 0.10
var warn_fraction: float = 0.20
var fade_s: float = 0.2
var cut_flash_s: float = 0.3
var data: Dictionary = {}

var _active: bool = false
## Intensidad del efecto (0-1; sigue a _active en fade_s) y destello del corte.
var _amount: float = 0.0
var _flash_left: float = 0.0
var _time: float = 0.0
var _last_denied: Denied = Denied.NONE
var _material: ShaderMaterial

static var _cached: Dictionary = {}


func _init() -> void:
	data = load_data()
	energy_per_s = float(data.get("energy_per_s", energy_per_s))
	sync_per_s = float(data.get("sync_per_s", sync_per_s))
	enter_min_fraction = float(data.get("enter_min_fraction", enter_min_fraction))
	cut_fraction = float(data.get("cut_fraction", cut_fraction))
	warn_fraction = float(data.get("warn_fraction", warn_fraction))
	fade_s = float(data.get("fade_s", fade_s))
	cut_flash_s = float(data.get("cut_flash_s", cut_flash_s))
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)


static func load_data() -> Dictionary:
	if _cached.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_cached = parsed
		else:
			push_error("HideMode: no se pudo leer '%s'." % DATA_PATH)
	return _cached


# --- Consultas ---

func is_active() -> bool:
	return _active


## Intensidad del efecto visual (0-1).
func get_amount() -> float:
	return _amount


## Destello del corte automatico en curso.
func is_flashing() -> bool:
	return _flash_left > 0.0


## Motivo del ultimo intento fallido de activarlo (Denied).
func get_last_denied() -> Denied:
	return _last_denied


## Sync Rate y energia por encima del minimo para activarlo (15 %).
static func has_enough_to_enter(config: Dictionary = {}) -> bool:
	var d: Dictionary = config if not config.is_empty() else load_data()
	var minimum: float = float(d.get("enter_min_fraction", 0.15))
	return GameState.sync_rate > GameState.get_sync_rate_max() * minimum + EPS \
			and GameState.debug_energy > GameState.get_debug_energy_max() * minimum + EPS


## Aviso (por debajo del 20 % de cualquiera de las dos barras): se va a cortar.
static func is_low(config: Dictionary = {}) -> bool:
	var d: Dictionary = config if not config.is_empty() else load_data()
	var warn: float = float(d.get("warn_fraction", 0.2))
	return GameState.sync_rate < GameState.get_sync_rate_max() * warn - EPS \
			or GameState.debug_energy < GameState.get_debug_energy_max() * warn - EPS


## Lo que queda hasta el corte (0-1): la barra que antes llega al 10 %, medida
## entre el 10 % y su maximo efectivo. Lo usa el HUD para su barra.
static func remaining_fraction(config: Dictionary = {}) -> float:
	var d: Dictionary = config if not config.is_empty() else load_data()
	var cut: float = float(d.get("cut_fraction", 0.1))
	var s_max: float = GameState.get_sync_rate_max()
	var e_max: float = GameState.get_debug_energy_max()
	var s: float = (GameState.sync_rate - s_max * cut) / maxf(s_max * (1.0 - cut), EPS)
	var e: float = (GameState.debug_energy - e_max * cut) / maxf(e_max * (1.0 - cut), EPS)
	return clampf(minf(s, e), 0.0, 1.0)


## Segundos que quedan hasta el corte con el gasto actual.
static func seconds_left(config: Dictionary = {}) -> float:
	var d: Dictionary = config if not config.is_empty() else load_data()
	var cut: float = float(d.get("cut_fraction", 0.1))
	var s_left: float = (GameState.sync_rate - GameState.get_sync_rate_max() * cut) / maxf(float(d.get("sync_per_s", 1.5)), EPS)
	var e_left: float = (GameState.debug_energy - GameState.get_debug_energy_max() * cut) / maxf(float(d.get("energy_per_s", 5.0)), EPS)
	return maxf(minf(s_left, e_left), 0.0)


# --- Acciones ---

## Intenta activarlo con `isak` (Denied.NONE si se activo). Apaga el Debug.
func try_activate(isak: Isak) -> Denied:
	_last_denied = _check(isak)
	if _last_denied != Denied.NONE:
		return _last_denied
	# No se combinan: activar el Ocultarte apaga el Debug (o su carga).
	DebugMode.cancel()
	_active = true
	GameState.set_player_hidden(true)
	started.emit()
	return Denied.NONE


## Lo apaga con `reason`. Sin efecto si no estaba activo.
func end(reason: StringName) -> void:
	if not _active:
		return
	_active = false
	if reason == REASON_CUT:
		_flash_left = cut_flash_s
	GameState.set_player_hidden(false)
	ended.emit(reason)
	EventBus.hide_ended.emit(reason)


## Apaga sin transicion (reaparecer, cambiar de escena).
func reset() -> void:
	end(REASON_RESET)
	_amount = 0.0
	_flash_left = 0.0


## Un paso de `real_delta` con `isak` (pulsacion de hide en su entrada, gasto,
## corte y efecto). Lo llama Isak.step.
func step(real_delta: float, isak: Isak) -> void:
	_time += real_delta
	if isak.input != null and isak.input.hide_pressed:
		if _active:
			end(REASON_TOGGLE)
		else:
			try_activate(isak)
	if _active:
		_drain(real_delta)
	_amount = move_toward(_amount, 1.0 if _active else 0.0, real_delta / maxf(fade_s, EPS))
	_flash_left = maxf(_flash_left - real_delta, 0.0)
	_apply_visual(isak)


func _check(isak: Isak) -> Denied:
	if not GameState.is_hide_available():
		return Denied.NOT_OWNED
	if isak == null or not isak.level_mode:
		return Denied.NOT_IN_LEVEL
	if not isak.is_on_floor():
		return Denied.NOT_ON_FLOOR
	if isak.is_dead() or isak.is_warping() or isak.is_facing_back() or isak.is_laser_posing() \
			or isak.is_laser_charging() or isak.get_state_name() in [PlayerState.PULSE, PlayerState.HURT, PlayerState.DASH]:
		return Denied.BUSY
	var minimum: float = enter_min_fraction
	if GameState.sync_rate <= GameState.get_sync_rate_max() * minimum + EPS:
		return Denied.LOW_SYNC
	if GameState.debug_energy <= GameState.get_debug_energy_max() * minimum + EPS:
		return Denied.LOW_ENERGY
	return Denied.NONE


## Gasto en tiempo real; se para y se corta al 10 % (el primero que llegue).
func _drain(real_delta: float) -> void:
	var sync_cut: float = GameState.get_sync_rate_max() * cut_fraction
	var energy_cut: float = GameState.get_debug_energy_max() * cut_fraction
	GameState.sync_rate = maxf(GameState.sync_rate - sync_per_s * real_delta, minf(sync_cut, GameState.sync_rate))
	GameState.debug_energy = maxf(GameState.debug_energy - energy_per_s * real_delta, minf(energy_cut, GameState.debug_energy))
	if GameState.sync_rate <= sync_cut + EPS or GameState.debug_energy <= energy_cut + EPS:
		end(REASON_CUT)


func _apply_visual(isak: Isak) -> void:
	var sprite: CanvasItem = isak.get_sprite()
	if sprite == null:
		return
	if _amount <= 0.0 and _flash_left <= 0.0:
		if sprite.material == _material and _material != null:
			sprite.material = null
		return
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
		_material.set_shader_parameter(&"alpha_hidden", float(data.get("alpha", 0.45)))
		_material.set_shader_parameter(&"tint", float(data.get("tint", 0.25)))
		_material.set_shader_parameter(&"outline_color", Color(String(data.get("outline_color", "#3dfff5"))))
		_material.set_shader_parameter(&"glitch_px", float(data.get("glitch_px", 2.0)))
		_material.set_shader_parameter(&"warn_glitch_px", float(data.get("warn_glitch_px", 3.0)))
		_material.set_shader_parameter(&"row_px", float(data.get("row_px", 3.0)))
		_material.set_shader_parameter(&"glitch_hz", float(data.get("glitch_hz", 12.0)))
		_material.set_shader_parameter(&"warn_blink_hz", float(data.get("warn_blink_hz", 6.0)))
		_material.set_shader_parameter(&"warn_alpha", float(data.get("warn_alpha", 0.25)))
	sprite.material = _material
	_material.set_shader_parameter(&"amount", _amount)
	_material.set_shader_parameter(&"time_s", _time)
	_material.set_shader_parameter(&"warn", 1.0 if _active and is_low(data) else 0.0)
	_material.set_shader_parameter(&"flash", _flash_left / maxf(cut_flash_s, EPS))


## Material del efecto (null si no se ha usado; pruebas y capturas).
func get_material() -> ShaderMaterial:
	return _material


func _on_debug_mode_changed(active: bool) -> void:
	if active:
		end(REASON_DEBUG)
