# DebugMode (autoload)
# Debug Mode de Isak (docs 3.2, 3.3 y 15.6; A4 y A14 de docs/preguntas.md):
# - Se activa MANTENIENDO la accion `debug` (K / Y) y solo si la habilidad
#   esta desbloqueada (GameState.abilities_unlocked["debug"]) y queda energia.
# - Mientras esta activo gasta energia en TIEMPO REAL (delta real, no el del
#   mundo) y el mundo va a `world_time_scale` (Isak y el HUD no se ralentizan).
# - Se apaga al soltar, al llegar la energia a 0, si se bloquea la habilidad o
#   si Isak muere. Tras apagarse por falta de energia hay que soltar y volver a
#   pulsar (evita que se encienda y apague solo al recoger un punto).
# - Entrada y salida suaves: `intensity` (0-1) sube en fade_in_s y baja en
#   fade_out_s; de ella salen la escala de tiempo y el tinte.
# Los valores salen de data/debug_mode.json (DebugModeConfig). El estado
# global (energia, escala de tiempo) vive en GameState; los avisos van por
# EventBus (debug_mode_changed, world_time_scale_changed).
extends Node

const ACTION_DEBUG: StringName = &"debug"
const INTENSITY_OFF: float = 0.0
const INTENSITY_FULL: float = 1.0

## Si es false, _physics_process no lee el Input Map (pruebas: llaman a step()).
var input_enabled: bool = true
var config: DebugModeConfig = DebugModeConfig.shared()

var _active: bool = false
var _intensity: float = INTENSITY_OFF
## Tras un apagado forzado se espera a que se suelte la accion.
var _await_release: bool = false


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.ability_unlock_changed.connect(_on_ability_unlock_changed)


func _physics_process(delta: float) -> void:
	if input_enabled:
		step(delta, Input.is_action_pressed(ACTION_DEBUG))


## Un paso del Debug con `real_delta` (sin escalar) y la accion mantenida o no.
## Publico para que las pruebas avancen con delta fijo.
func step(real_delta: float, held: bool) -> void:
	if not held:
		_await_release = false
	if _active and not held:
		_set_active(false)
	elif not _active and held and not _await_release and can_enter():
		_set_active(true)
	if _active:
		GameState.debug_energy -= config.drain_per_second * real_delta
		if GameState.debug_energy <= GameState.DEBUG_ENERGY_MIN:
			_force_exit()
	_update_intensity(real_delta)


## Requisitos para entrar: habilidad desbloqueada y energia por encima de 0.
func can_enter() -> bool:
	return GameState.is_ability_unlocked(GameState.ABILITY_DEBUG) \
			and GameState.debug_energy > GameState.DEBUG_ENERGY_MIN


func is_active() -> bool:
	return _active


## 0 = apagado del todo, 1 = efecto completo. Sigue a `active` con transicion.
func get_intensity() -> float:
	return _intensity


## Escala de tiempo que tendria el mundo con esta intensidad.
func time_scale_for(intensity: float) -> float:
	return lerpf(GameState.WORLD_TIME_SCALE_NORMAL, config.world_time_scale, intensity)


## Apaga el Debug al instante, sin transicion (cambio de escena, pruebas).
func reset() -> void:
	_await_release = false
	if _active:
		_set_active(false)
	_intensity = INTENSITY_OFF
	_apply_intensity()


func _force_exit() -> void:
	if not _active:
		return
	_await_release = true
	_set_active(false)


func _set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	EventBus.debug_mode_changed.emit(active)


func _update_intensity(real_delta: float) -> void:
	var target: float = INTENSITY_FULL if _active else INTENSITY_OFF
	if _intensity == target:
		return
	var fade_s: float = config.fade_in_s if _active else config.fade_out_s
	if fade_s <= 0.0:
		_intensity = target
	else:
		_intensity = move_toward(_intensity, target, real_delta / fade_s)
	_apply_intensity()


func _apply_intensity() -> void:
	GameState.world_time_scale = time_scale_for(_intensity)


func _on_player_died() -> void:
	_force_exit()


func _on_ability_unlock_changed(ability: StringName, unlocked: bool) -> void:
	if ability == GameState.ABILITY_DEBUG and not unlocked:
		_force_exit()
