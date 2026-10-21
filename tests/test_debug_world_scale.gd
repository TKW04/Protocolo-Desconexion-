# Escala del mundo con el Debug por nivel (2026-10-21,
# docs/propuesta-jefe-alerta-mayor.md §6.4): debug_world_scale del nivel
# sustituye al x0,5 global (la arena de Alerta Mayor, x0,7), conserva la
# proporcion del Debug 4 (0,7 -> 0,56), la fija GeneratedLevel al entrar y la
# quita al salir; el 1-1, el 1-2 y el 1-3 siguen a x0,5. El gasto del Debug
# sigue en tiempo real y la carga no cambia.
extends GutTest

const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _config: DebugModeConfig = DebugModeConfig.shared()
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"energy": GameState.debug_energy,
		"levels": GameState.upgrade_levels.duplicate(),
	}
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	DebugMode.set_level_world_scale(DebugMode.LEVEL_WORLD_SCALE_NONE)


func after_each() -> void:
	DebugMode.reset()
	DebugMode.set_level_world_scale(DebugMode.LEVEL_WORLD_SCALE_NONE)
	DebugMode.set_level_drain_scale(1.0)
	DebugMode.input_enabled = true
	GameState.upgrade_levels = _saved["levels"]
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved["debug"])
	GameState.debug_energy = _saved["energy"]


func _debug_on() -> void:
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	# Entrada completa (fade_in_s).
	for i: int in roundi(_config.fade_in_s / DT) + 2:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())


func test_default_is_the_global_half() -> void:
	assert_lt(DebugMode.get_level_world_scale(), 0.0, "Sin escala propia")
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.5, EPS)


func test_level_scale_replaces_the_global_one() -> void:
	DebugMode.set_level_world_scale(0.7)
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.7, EPS)
	_debug_on()
	assert_almost_eq(GameState.world_time_scale, 0.7, EPS, "El mundo va a x0,7 con el Debug")
	var before: float = GameState.debug_energy
	for i: int in 60:
		DebugMode.step(DT, false)
	assert_almost_eq(before - GameState.debug_energy, 20.0, 0.4, "El gasto sigue en tiempo real (20/s)")


func test_debug_4_keeps_its_ratio() -> void:
	GameState.upgrade_levels[&"debug"] = 4
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.4, EPS, "Debug 4 global: x0,4")
	DebugMode.set_level_world_scale(0.7)
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.56, EPS, "Arena + Debug 4: 0,7 x 0,8")


func test_changing_the_scale_with_the_debug_active_applies_at_once() -> void:
	_debug_on()
	assert_almost_eq(GameState.world_time_scale, 0.5, EPS)
	DebugMode.set_level_world_scale(0.7)
	assert_almost_eq(GameState.world_time_scale, 0.7, EPS)
	DebugMode.set_level_world_scale(DebugMode.LEVEL_WORLD_SCALE_NONE)
	assert_almost_eq(GameState.world_time_scale, 0.5, EPS)


func test_scale_is_clamped_and_survives_reset() -> void:
	DebugMode.set_level_world_scale(1.5)
	assert_eq(DebugMode.get_level_world_scale(), 1.0)
	DebugMode.set_level_world_scale(0.7)
	DebugMode.reset()
	assert_almost_eq(DebugMode.get_level_world_scale(), 0.7, EPS, "Reaparecer (reset) no la cambia")
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS, "Sin Debug el mundo va a x1")


func test_generated_level_applies_and_restores_it() -> void:
	var level := GeneratedLevel.new()
	level.debug_world_scale = 0.7
	level.abilities_available = {"debug": true}
	add_child(level)
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.7, EPS, "Dentro del nivel: x0,7")
	remove_child(level)
	level.free()
	assert_lt(DebugMode.get_level_world_scale(), 0.0, "Al salir, sin escala propia")
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.5, EPS)


func test_boss_arena_is_0_7_and_other_levels_keep_0_5() -> void:
	var arena := (load("res://scenes/levels/1-boss.tscn") as PackedScene).instantiate() as GeneratedLevel
	assert_almost_eq(arena.debug_world_scale, 0.7, EPS)
	arena.free()
	for id: String in ["1-1", "1-2", "1-3", "boss_test"]:
		DebugMode.set_level_world_scale(0.7)
		var level := (load("res://scenes/levels/%s.tscn" % id) as PackedScene).instantiate() as GeneratedLevel
		assert_lt(level.debug_world_scale, 0.0, "%s sin debug_world_scale" % id)
		add_child(level)
		assert_almost_eq(DebugMode.get_world_time_scale(), 0.5, EPS, "%s: x0,5" % id)
		remove_child(level)
		level.free()
