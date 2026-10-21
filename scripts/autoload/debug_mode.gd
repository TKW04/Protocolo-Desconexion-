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
# - Mejoras de Calc (tanda M2, data/upgrades.json): Debug 3 «Revelado
#   persistente»: al apagarse, lo revelado (plataformas ocultas, vista a traves de
#   los pop-ups) sigue visible y solido reveal_linger_s (1,5 s reales;
#   is_revealing, get_reveal_intensity, EventBus.debug_reveal_changed); Debug 4:
#   el mundo va a x0,4 (get_world_time_scale); Debug 5 «Arranque rapido»: carga
#   de 0,4 s (get_activation_hold_s). El gasto sigue en tiempo real. No se
#   combina con el Ocultarte (Pulso 4): activar el Debug apaga el Ocultarte
#   (HideMode escucha debug_mode_changed) y activar el Ocultarte apaga el Debug
#   (cancel).
# - Gasto por nivel (2026-10-21, paso 4 de docs/propuesta-jefe-alerta-mayor.md
#   §6, §2.4.5): el nivel puede pedir que el Debug gaste menos con
#   `debug_drain_scale` (0-1; la arena de Alerta Mayor, 0,5: 20 -> 10/s y 15 ->
#   7,5/s con Debug 2). Lo fija GeneratedLevel al entrar (set_level_drain_scale)
#   y lo devuelve a 1 al salir; el hub y los demas niveles van a 1. Ni la carga
#   ni la regla «Debug y dash no se combinan» cambian. reset() no lo toca.
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
## Revelado persistente: segundos reales que quedan tras apagarse (0 = nada) y
## la intensidad con que se dibuja lo revelado (1 mientras dura; se apaga con
## fade_out_s al acabar).
var _linger_left: float = 0.0
var _reveal_intensity: float = INTENSITY_OFF
var _revealing: bool = false
## Multiplicador del gasto del nivel actual (debug_drain_scale; 1 por defecto).
var _level_drain_scale: float = 1.0


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
	elif not is_active() and _linger_left > 0.0 and not was_active:
		_linger_left = maxf(_linger_left - real_delta, 0.0)
	_update_intensity(real_delta)
	_update_reveal(real_delta)


## Gasto de energia por segundo real: data/debug_mode.json con las mejoras
## compradas ("Debug eficiente") por el debug_drain_scale del nivel actual.
## config no se modifica.
func get_drain_per_second() -> float:
	return GameState.effective_value(&"debug_mode.drain_per_second", config.drain_per_second) * _level_drain_scale


## Multiplicador del gasto del nivel actual (0-1; lo fija GeneratedLevel).
func set_level_drain_scale(scale: float) -> void:
	_level_drain_scale = clampf(scale, 0.0, 1.0)


func get_level_drain_scale() -> float:
	return _level_drain_scale


## Segundos de pulsacion larga para activar, con mejoras ("Arranque rapido").
func get_activation_hold_s() -> float:
	return GameState.effective_value(&"debug_mode.activation_hold_s", config.activation_hold_s)


## Escala del mundo con el Debug activo, con mejoras (Debug 4: 0,5 a 0,4).
func get_world_time_scale() -> float:
	return GameState.effective_value(&"debug_mode.world_time_scale", config.world_time_scale)


## Revelado persistente tras apagar el Debug, con mejoras (Debug 3: 0 a 1,5 s).
func get_reveal_linger_s() -> float:
	return GameState.effective_value(&"debug_mode.reveal_linger_s", config.reveal_linger_s)


## Lo revelado se ve y es solido: Debug activo o en su persistencia (Debug 3).
func is_revealing() -> bool:
	return _revealing


## Segundos de persistencia que quedan tras apagar el Debug (0 si no hay).
func get_reveal_linger_left() -> float:
	return _linger_left


## Intensidad con la que se dibuja lo revelado (0-1): la del Debug o, durante la
## persistencia, 1 (y despues se apaga con fade_out_s).
func get_reveal_intensity() -> float:
	return _reveal_intensity


## Persistencia en su aviso final (ultimos reveal_linger_warn_s): lo revelado
## parpadea; is_reveal_blink_off dice si en este instante se dibuja apagado.
func is_reveal_warning() -> bool:
	return not is_active() and _linger_left > 0.0 and _linger_left <= config.reveal_linger_warn_s


func is_reveal_blink_off() -> bool:
	if not is_reveal_warning():
		return false
	var hz: float = maxf(config.reveal_linger_blink_hz, 0.01)
	return fmod(_linger_left * hz, 1.0) < 0.5


## Apaga el Debug sin persistencia ni transicion de golpe (Ocultarte, Pulso 4:
## activar uno apaga el otro). Corta tambien una carga en curso.
func cancel() -> void:
	_cancel_charge()
	_set_active(false)


## Requisitos para entrar: habilidad desbloqueada y energia por encima de 0.
func can_enter() -> bool:
	return GameState.is_ability_unlocked(GameState.ABILITY_DEBUG) \
			and GameState.debug_energy > GameState.DEBUG_ENERGY_MIN


func is_active() -> bool:
	return _state == State.ACTIVE


## Activo o cargando (pulsacion larga en curso). Con el Debug asi no sale el dash
## (2026-10-19, docs/propuesta-1-3.md §2.2: no se combinan; chispa gris).
func is_engaged() -> bool:
	return _state == State.ACTIVE or _state == State.CHARGING


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


## Escala de tiempo que tendria el mundo con esta intensidad (con mejoras).
func time_scale_for(intensity: float) -> float:
	return lerpf(GameState.WORLD_TIME_SCALE_NORMAL, get_world_time_scale(), intensity)


## Apaga el Debug al instante, sin transicion (cambio de escena, pruebas).
func reset() -> void:
	_was_held = false
	_cancel_charge()
	_set_active(false)
	_state = State.INACTIVE
	_intensity = INTENSITY_OFF
	_linger_left = 0.0
	_reveal_intensity = INTENSITY_OFF
	_set_revealing(false)
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


## Apagado forzado (muerte, habilidad bloqueada): corta tambien la carga y
## la persistencia del revelado.
func _force_exit() -> void:
	_cancel_charge()
	_set_active(false)
	_linger_left = 0.0
	_set_revealing(false)


func _set_active(active: bool) -> void:
	if is_active() == active:
		return
	_state = State.ACTIVE if active else State.EXITING
	# Debug 3: al apagarse, lo revelado se queda reveal_linger_s.
	_linger_left = 0.0 if active else maxf(get_reveal_linger_s(), 0.0)
	EventBus.debug_mode_changed.emit(active)
	_set_revealing(active or _linger_left > 0.0)


## Revelado (activo o persistente) y su intensidad de dibujo.
func _update_reveal(real_delta: float) -> void:
	_set_revealing(is_active() or _linger_left > 0.0)
	if is_active():
		_reveal_intensity = _intensity
	elif _linger_left > 0.0:
		_reveal_intensity = INTENSITY_FULL
	elif config.fade_out_s <= 0.0:
		_reveal_intensity = minf(_reveal_intensity, _intensity)
	else:
		_reveal_intensity = maxf(move_toward(_reveal_intensity, INTENSITY_OFF, real_delta / config.fade_out_s), _intensity)


func _set_revealing(revealing: bool) -> void:
	if revealing == _revealing:
		return
	_revealing = revealing
	EventBus.debug_reveal_changed.emit(revealing)


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
