# GameState (autoload)
# Estado global de la partida. Única fuente de verdad para:
# - Sync Rate (la vida de Isak, en porcentaje).
# - Energía de Debug (barra secundaria que gasta el Debug Mode).
# - Puntos de atención (la moneda).
# - Fragmentos recuperados y nivel actual.
# - Habilidades desbloqueadas (se desbloquean por mundo).
# - Mundo actual y los ajustes de accesibilidad (Sync Rate bajo, contorno del Debug).
# - Escala de tiempo del mundo (world_time_scale): la fija DebugMode y la leen
#   los objetos del mundo con WorldTime.scaled_delta() (Isak y el HUD no).
# Cada setter acota el valor y emite la señal correspondiente por EventBus.
# Apenas contiene reglas de juego (solo la recarga de energía por punto de
# atención, A10): quién gasta, cura o desbloquea vive en otros scripts.
extends Node

const SYNC_RATE_MAX: float = 100.0
const SYNC_RATE_MIN: float = 0.0
# Barra normalizada a 100 hasta que el diseño fije su capacidad real.
const DEBUG_ENERGY_MAX: float = 100.0
const DEBUG_ENERGY_MIN: float = 0.0
const ATTENTION_POINTS_MIN: int = 0
const FRAGMENTS_MIN: int = 0
const NO_LEVEL: StringName = &""
const FIRST_WORLD: int = 1
const LAST_WORLD: int = 6
## Escala de tiempo del mundo sin Debug (ver WorldTime).
const WORLD_TIME_SCALE_NORMAL: float = 1.0
## Energia que repone cada punto de atencion recogido (A10, aprobado).
const ENERGY_PER_ATTENTION_POINT: float = 10.0

const ABILITY_PULSE: StringName = &"pulse"
const ABILITY_DEBUG: StringName = &"debug"
const ABILITY_DASH: StringName = &"dash"
const ABILITY_GROUND_POUND: StringName = &"ground_pound"
const ABILITY_COMPRESS: StringName = &"compress"
const ABILITY_SHOCKWAVE: StringName = &"shockwave"
const ABILITIES: Array[StringName] = [
	ABILITY_PULSE,
	ABILITY_DEBUG,
	ABILITY_DASH,
	ABILITY_GROUND_POUND,
	ABILITY_COMPRESS,
	ABILITY_SHOCKWAVE,
]

var sync_rate: float = SYNC_RATE_MAX:
	set(value):
		sync_rate = clampf(value, SYNC_RATE_MIN, SYNC_RATE_MAX)
		EventBus.sync_rate_changed.emit(sync_rate, SYNC_RATE_MAX)
		_update_low_sync()

var debug_energy: float = DEBUG_ENERGY_MAX:
	set(value):
		debug_energy = clampf(value, DEBUG_ENERGY_MIN, DEBUG_ENERGY_MAX)
		EventBus.energy_changed.emit(debug_energy, DEBUG_ENERGY_MAX)

var attention_points: int = ATTENTION_POINTS_MIN:
	set(value):
		attention_points = maxi(value, ATTENTION_POINTS_MIN)
		EventBus.attention_points_changed.emit(attention_points)

var fragments_recovered: int = FRAGMENTS_MIN:
	set(value):
		fragments_recovered = maxi(value, FRAGMENTS_MIN)

var current_level: StringName = NO_LEVEL

## Ultimo punto de sincronizacion tocado en cada nivel (id de nivel -> id de
## checkpoint). Solo hay uno activo por nivel: el mas reciente. Lo escribe
## Checkpoint y lo borra el flujo de nivel (LevelRunner) al empezar de cero.
var last_checkpoint: Dictionary[StringName, StringName] = {}
## Niveles completados y niveles desbloqueados (por `unlocks` del JSON del
## nivel). Los guarda LevelRunner al terminar un nivel; aun no van a disco.
var completed_levels: Dictionary[StringName, bool] = {}
var unlocked_levels: Dictionary[StringName, bool] = {}

## Mundo actual (1-6). Decide el color del Debug.
var current_world: int = FIRST_WORLD:
	set(value):
		current_world = clampi(value, FIRST_WORLD, LAST_WORLD)
		EventBus.world_changed.emit(current_world)

## Ajuste de accesibilidad (docs 3.3 y 15.6): reducir el ruido y la distorsion
## de Sync Rate bajo. Aun no se guarda en disco (no hay menu de opciones).
var reduce_low_sync_effects: bool = false:
	set(value):
		reduce_low_sync_effects = value
		EventBus.reduce_low_sync_effects_changed.emit(value)

## Ajuste de accesibilidad (docs 15.6, "contorno claro para daltonismo"): las
## plataformas ocultas del Debug usan un contorno mas claro y grueso
## (data/debug_mode.json, high_contrast_*). Aun no se guarda en disco.
var debug_high_contrast_outline: bool = false:
	set(value):
		debug_high_contrast_outline = value
		EventBus.debug_high_contrast_outline_changed.emit(value)

## Escala de tiempo del mundo (1 = normal). Solo la escribe DebugMode; el
## mundo la consume con WorldTime.scaled_delta(). No es Engine.time_scale.
var world_time_scale: float = WORLD_TIME_SCALE_NORMAL:
	set(value):
		var clamped: float = maxf(value, 0.0)
		if clamped == world_time_scale:
			return
		world_time_scale = clamped
		EventBus.world_time_scale_changed.emit(world_time_scale)

## Umbral (en % de Sync Rate) del estado de Sync Rate bajo; de data/hud.json.
var low_sync_threshold: float = HudConfig.shared().low_sync_threshold

var _is_sync_low: bool = false

var abilities_unlocked: Dictionary[StringName, bool] = _build_locked_abilities()


func _ready() -> void:
	EventBus.state_refresh_requested.connect(emit_state)


## Sync Rate bajo: por debajo del umbral (estrictamente menor, docs: "menor al 20%").
func is_sync_low() -> bool:
	return _is_sync_low


## Resta Sync Rate (dano de prueba de la arena; el dano real llega en el paso 9).
func apply_sync_damage(amount: float) -> void:
	sync_rate -= maxf(amount, 0.0)


## Suma puntos de atencion; cada uno repone energia de Debug (A10).
## GANCHO (pendiente de decidir): otras fuentes de recarga de energia o de
## Sync Rate (puntos de sincronizacion, objetos, mejoras del hub) iran en
## funciones propias aqui; de momento no hay regeneracion pasiva ni curacion.
func add_attention_points(amount: int) -> void:
	if amount <= 0:
		return
	attention_points += amount
	debug_energy += amount * ENERGY_PER_ATTENTION_POINT


## Reemite todo el estado que muestra el HUD (al aparecer un HUD nuevo).
func emit_state() -> void:
	EventBus.world_changed.emit(current_world)
	EventBus.reduce_low_sync_effects_changed.emit(reduce_low_sync_effects)
	EventBus.debug_high_contrast_outline_changed.emit(debug_high_contrast_outline)
	EventBus.sync_rate_changed.emit(sync_rate, SYNC_RATE_MAX)
	EventBus.energy_changed.emit(debug_energy, DEBUG_ENERGY_MAX)
	EventBus.attention_points_changed.emit(attention_points)
	EventBus.low_sync_changed.emit(_is_sync_low)


## Fija el ultimo punto de sincronizacion de `level` (sustituye al anterior).
func set_last_checkpoint(level: StringName, checkpoint_id: StringName) -> void:
	if last_checkpoint.get(level, NO_LEVEL) == checkpoint_id:
		return
	last_checkpoint[level] = checkpoint_id
	EventBus.checkpoint_activated.emit(String(level), checkpoint_id)


## Ultimo punto de sincronizacion de `level` o &"" si no hay ninguno.
func get_last_checkpoint(level: StringName) -> StringName:
	return last_checkpoint.get(level, NO_LEVEL)


func clear_last_checkpoint(level: StringName) -> void:
	last_checkpoint.erase(level)


func mark_level_completed(level: StringName) -> void:
	completed_levels[level] = true


func is_level_completed(level: StringName) -> bool:
	return completed_levels.get(level, false)


func unlock_level(level: StringName) -> void:
	unlocked_levels[level] = true


func is_level_unlocked(level: StringName) -> bool:
	return unlocked_levels.get(level, false)


func is_ability_unlocked(ability: StringName) -> bool:
	return abilities_unlocked.get(ability, false)


func set_ability_unlocked(ability: StringName, unlocked: bool) -> void:
	if not abilities_unlocked.has(ability):
		push_error("GameState: unknown ability '%s'" % ability)
		return
	if abilities_unlocked[ability] == unlocked:
		return
	abilities_unlocked[ability] = unlocked
	EventBus.ability_unlock_changed.emit(ability, unlocked)


func _update_low_sync() -> void:
	var low: bool = sync_rate < low_sync_threshold
	if low == _is_sync_low:
		return
	_is_sync_low = low
	EventBus.low_sync_changed.emit(low)


func _build_locked_abilities() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for ability: StringName in ABILITIES:
		result[ability] = false
	return result
