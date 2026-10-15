# DebugMode (autoload)
# Debug Mode de Isak (docs 3.2, 3.3 y 15.6; A4 y A14 de docs/preguntas.md):
# - Control (cambio 2026-10-14 pedido por el usuario): se ACTIVA con una
#   pulsacion larga de la accion `debug` (K / Y) de `activation_hold_s`; una
#   vez activo se queda activo sin mantener nada y se DESACTIVA con una nueva
#   pulsacion (flanco de pulsacion de un ciclo nuevo: ni la pulsacion que lo
#   activo ni el soltarla lo apagan).
# - Maquina de estados: INACTIVE -> CHARGING -> ACTIVE -> EXITING -> INACTIVE.
#   CHARGING solo empieza con una pulsacion nueva, la habilidad desbloqueada
#   (GameState.abilities_unlocked["debug"]) y energia > 0. Soltar antes de
#   tiempo cancela sin coste. La carga no gasta energia; su progreso (0-1) va
#   por EventBus.debug_activation_progress_changed (0 si no se carga).
# - Mientras esta activo gasta energia en TIEMPO REAL (delta real, no el del
#   mundo) y el mundo va a `world_time_scale` (Isak y el HUD no se ralentizan).
# - Se apaga al pulsar de nuevo, al llegar la energia a 0, si se bloquea la
#   habilidad o si Isak muere. Para volver a entrar hay que repetir la
#   pulsacion larga.
# - Entrada y salida suaves: `intensity` (0-1) sube en fade_in_s y baja en
#   fade_out_s; de ella salen la escala de tiempo y el tinte.
# - Crea y alimenta el efecto de pantalla (DebugOverlay: tinte + vineta en un
#   CanvasLayer entre el mundo y el HUD), asi que vale para cualquier escena.
# Los valores salen de data/debug_mode.json (DebugModeConfig). El estado
# global (energia, escala de tiempo) vive en GameState; los avisos van por
# EventBus (debug_mode_changed, debug_activation_progress_changed,
# world_time_scale_changed).
extends Node

enum State { INACTIVE, CHARGING, ACTIVE, EXITING }

const ACTION_DEBUG: StringName = &"debug"
const INTENSITY_OFF: float = 0.0
const INTENSITY_FULL: float = 1.0
const PROGRESS_NONE: float = 0.0
const PROGRESS_FULL: float = 1.0
## Tolerancia al sumar deltas de coma flotante (60 x 1/60 puede dar 0,9999...).
const HOLD_EPSILON_S: float = 0.000001
const OVERLAY_SCENE: PackedScene = preload("res://scenes/effects/debug_overlay.tscn")

## Si es false, _physics_process no lee el Input Map (pruebas: llaman a step()).
var input_enabled: bool = true
var config: DebugModeConfig = DebugModeConfig.shared()

var _state: State = State.INACTIVE
var _intensity: float = INTENSITY_OFF
## Segundos reales que lleva mantenida la pulsacion de activacion.
var _hold_s: float = 0.0
var _progress: float = PROGRESS_NONE
## Estado de la accion en el paso anterior (para detectar pulsaciones nuevas).
var _was_held: bool = false
var _overlay: DebugOverlay


func _ready() -> void:
	_overlay = OVERLAY_SCENE.instantiate() as DebugOverlay
	add_child(_overlay)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ability_unlock_changed.connect(_on_ability_unlock_changed)


func _physics_process(delta: float) -> void:
	if input_enabled:
		step(delta, Input.is_action_pressed(ACTION_DEBUG))


## Un paso del Debug con `real_delta` (sin escalar) y la accion pulsada o no.
## Las pulsaciones nuevas se detectan comparando con el paso anterior.
## Publico para que las pruebas avancen con delta fijo.
func step(real_delta: float, held: bool) -> void:
	var pressed: bool = held and not _was_held
	_was_held = held
	# El gasto empieza en el paso siguiente al de la activacion.
	var was_active: bool = is_active()
	match _state:
		State.INACTIVE, State.EXITING:
			if pressed and can_enter():
				_state = State.CHARGING
				_hold_s = 0.0
				_charge(real_delta)
		State.CHARGING:
			if not held or not can_enter():
				_cancel_charge()
			else:
				_charge(real_delta)
		State.ACTIVE:
			if pressed:
				_set_active(false)
	if was_active and is_active():
		GameState.debug_energy -= get_drain_per_second() * real_delta
		if GameState.debug_energy <= GameState.DEBUG_ENERGY_MIN:
			_set_active(false)
	_update_intensity(real_delta)


## Gasto de energia por segundo real: data/debug_mode.json con las mejoras
## compradas ("Debug eficiente"). config no se modifica.
func get_drain_per_second() -> float:
	return GameState.effective_value(&"debug_mode.drain_per_second", config.drain_per_second)


## Segundos de pulsacion larga para activar, con mejoras ("Arranque rapido").
func get_activation_hold_s() -> float:
	return GameState.effective_value(&"debug_mode.activation_hold_s", config.activation_hold_s)


## Requisitos para entrar: habilidad desbloqueada y energia por encima de 0.
func can_enter() -> bool:
	return GameState.is_ability_unlocked(GameState.ABILITY_DEBUG) \
			and GameState.debug_energy > GameState.DEBUG_ENERGY_MIN


func is_active() -> bool:
	return _state == State.ACTIVE


func get_state() -> State:
	return _state


## Progreso de la pulsacion larga de activacion (0-1; 0 si no se carga).
func get_activation_progress() -> float:
	return _progress


## 0 = apagado del todo, 1 = efecto completo. Sigue a `active` con transicion.
func get_intensity() -> float:
	return _intensity


## Efecto de pantalla (pruebas y capturas).
func get_overlay() -> DebugOverlay:
	return _overlay


## Escala de tiempo que tendria el mundo con esta intensidad.
func time_scale_for(intensity: float) -> float:
	return lerpf(GameState.WORLD_TIME_SCALE_NORMAL, config.world_time_scale, intensity)


## Apaga el Debug al instante, sin transicion (cambio de escena, pruebas).
func reset() -> void:
	_was_held = false
	_cancel_charge()
	_set_active(false)
	_state = State.INACTIVE
	_intensity = INTENSITY_OFF
	_apply_intensity()


## Suma tiempo a la pulsacion larga; al llegar a `activation_hold_s` entra.
func _charge(real_delta: float) -> void:
	_hold_s += real_delta
	var hold_s: float = get_activation_hold_s()
	if hold_s <= 0.0 or _hold_s >= hold_s - HOLD_EPSILON_S:
		_set_progress(PROGRESS_FULL)
		_hold_s = 0.0
		_set_progress(PROGRESS_NONE)
		_set_active(true)
	else:
		_set_progress(_hold_s / hold_s)


## Corta la carga sin coste ni efecto.
func _cancel_charge() -> void:
	_hold_s = 0.0
	_set_progress(PROGRESS_NONE)
	if _state == State.CHARGING:
		_state = State.EXITING if _intensity > INTENSITY_OFF else State.INACTIVE


func _set_progress(progress: float) -> void:
	progress = clampf(progress, PROGRESS_NONE, PROGRESS_FULL)
	if progress == _progress:
		return
	_progress = progress
	EventBus.debug_activation_progress_changed.emit(progress)


## Apagado forzado (muerte, habilidad bloqueada): corta tambien la carga.
func _force_exit() -> void:
	_cancel_charge()
	_set_active(false)


func _set_active(active: bool) -> void:
	if is_active() == active:
		return
	_state = State.ACTIVE if active else State.EXITING
	EventBus.debug_mode_changed.emit(active)


func _update_intensity(real_delta: float) -> void:
	var active: bool = is_active()
	var target: float = INTENSITY_FULL if active else INTENSITY_OFF
	if _intensity == target:
		if _state == State.EXITING:
			_state = State.INACTIVE
		return
	var fade_s: float = config.fade_in_s if active else config.fade_out_s
	if fade_s <= 0.0:
		_intensity = target
	else:
		_intensity = move_toward(_intensity, target, real_delta / fade_s)
	_apply_intensity()
	if _state == State.EXITING and _intensity == INTENSITY_OFF:
		_state = State.INACTIVE


func _apply_intensity() -> void:
	GameState.world_time_scale = time_scale_for(_intensity)
	if _overlay != null:
		_overlay.set_intensity(_intensity)


func _on_player_died() -> void:
	_force_exit()


func _on_ability_unlock_changed(ability: StringName, unlocked: bool) -> void:
	if ability == GameState.ABILITY_DEBUG and not unlocked:
		_force_exit()
