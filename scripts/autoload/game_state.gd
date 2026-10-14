# GameState (autoload)
# Estado global de la partida. Única fuente de verdad para:
# - Sync Rate (la vida de Isak, en porcentaje).
# - Energía de Debug (barra secundaria que gasta el Debug Mode).
# - Puntos de atención (la moneda).
# - Fragmentos recuperados y nivel actual.
# - Habilidades desbloqueadas (se desbloquean por mundo).
# Cada setter acota el valor y emite la señal correspondiente por EventBus.
# No contiene reglas de juego: quién gasta, cura o desbloquea vive en otros scripts.
extends Node

const SYNC_RATE_MAX: float = 100.0
const SYNC_RATE_MIN: float = 0.0
# Barra normalizada a 100 hasta que el diseño fije su capacidad real.
const DEBUG_ENERGY_MAX: float = 100.0
const DEBUG_ENERGY_MIN: float = 0.0
const ATTENTION_POINTS_MIN: int = 0
const FRAGMENTS_MIN: int = 0
const NO_LEVEL: StringName = &""

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

var abilities_unlocked: Dictionary[StringName, bool] = _build_locked_abilities()


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


func _build_locked_abilities() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for ability: StringName in ABILITIES:
		result[ability] = false
	return result
