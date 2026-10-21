# Energia de la arena (paso 4 de docs/propuesta-jefe-alerta-mayor.md §6,
# 2026-10-21; §2.4.5): debug_drain_scale por nivel multiplica el gasto del Debug
# (0,5: 20 -> 10/s; con Debug 2, 15 -> 7,5/s); lo fija GeneratedLevel al entrar
# y vuelve a 1 al salir; el 1-1, el 1-2 y el 1-3 siguen en 20/s; la carga del
# Debug no cambia. Cargadores con cooldown_s propio por instancia (4 s en la sala
# del jefe) sin tocar los de los niveles existentes.
extends GutTest

const DT: float = 1.0 / 60.0
const EPS: float = 0.01

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
	DebugMode.set_level_drain_scale(1.0)


func after_each() -> void:
	DebugMode.reset()
	DebugMode.set_level_drain_scale(1.0)
	DebugMode.input_enabled = true
	GameState.upgrade_levels = _saved["levels"]
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved["debug"])
	GameState.debug_energy = _saved["energy"]


func _debug_on() -> void:
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())


## Energia gastada en `seconds` reales con el Debug activo.
func _drain_over(seconds: float) -> float:
	var before: float = GameState.debug_energy
	for i: int in roundi(seconds / DT):
		DebugMode.step(DT, false)
	return before - GameState.debug_energy


func test_default_scale_is_one_and_drain_is_20() -> void:
	assert_eq(DebugMode.get_level_drain_scale(), 1.0)
	assert_almost_eq(DebugMode.get_drain_per_second(), 20.0, EPS)


func test_half_scale_drains_10_per_second() -> void:
	DebugMode.set_level_drain_scale(0.5)
	assert_almost_eq(DebugMode.get_drain_per_second(), 10.0, EPS)
	var before: float = GameState.debug_energy
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Carga de 1 s sin cambios")
	assert_almost_eq(GameState.debug_energy, before, EPS, "La carga no gasta")
	assert_almost_eq(_drain_over(1.0), 10.0, 0.2, "10 por segundo real")


func test_half_scale_with_debug_2_drains_7_5() -> void:
	GameState.upgrade_levels[&"debug"] = 2
	assert_almost_eq(DebugMode.get_drain_per_second(), 15.0, EPS, "Debug 2: 15/s")
	DebugMode.set_level_drain_scale(0.5)
	assert_almost_eq(DebugMode.get_drain_per_second(), 7.5, EPS, "Arena + Debug 2: 7,5/s")


func test_scale_is_clamped_and_survives_reset() -> void:
	DebugMode.set_level_drain_scale(2.0)
	assert_eq(DebugMode.get_level_drain_scale(), 1.0, "Nunca mas de 1")
	DebugMode.set_level_drain_scale(-1.0)
	assert_eq(DebugMode.get_level_drain_scale(), 0.0)
	DebugMode.set_level_drain_scale(0.5)
	DebugMode.reset()
	assert_eq(DebugMode.get_level_drain_scale(), 0.5, "Reaparecer (reset) no cambia el nivel")


func test_generated_level_applies_and_restores_the_scale() -> void:
	var level := GeneratedLevel.new()
	level.debug_drain_scale = 0.5
	level.abilities_available = {"debug": true}
	add_child(level)
	assert_almost_eq(DebugMode.get_drain_per_second(), 10.0, EPS, "Dentro del nivel: 10/s")
	remove_child(level)
	level.free()
	assert_eq(DebugMode.get_level_drain_scale(), 1.0, "Al salir vuelve a 1")
	assert_almost_eq(DebugMode.get_drain_per_second(), 20.0, EPS)


func test_existing_levels_keep_20_per_second() -> void:
	for id: String in ["1-1", "1-2", "1-3", "boss_test"]:
		DebugMode.set_level_drain_scale(0.5)
		var level := (load("res://scenes/levels/%s.tscn" % id) as PackedScene).instantiate() as GeneratedLevel
		assert_eq(level.debug_drain_scale, 1.0, "%s sin debug_drain_scale" % id)
		add_child(level)
		assert_almost_eq(DebugMode.get_drain_per_second(), 20.0, EPS, "%s: 20/s" % id)
		remove_child(level)
		level.free()


func test_charger_cooldown_is_per_instance() -> void:
	var level := (load("res://scenes/levels/boss_test.tscn") as PackedScene).instantiate() as GeneratedLevel
	add_child_autofree(level)
	await wait_physics_frames(1)
	var charger := level.find_child("cargador_saco", true, false) as Charger
	assert_almost_eq(charger.cooldown_s, 4.0, EPS)
	GameState.debug_energy = 10.0
	assert_almost_eq(charger.try_use(level.get_isak()), 50.0, EPS, "+50")
	assert_false(charger.is_ready())
	charger.advance(3.9)
	assert_false(charger.is_ready(), "Aun enfriandose a los 3,9 s")
	charger.advance(0.11)
	assert_true(charger.is_ready(), "Listo a los 4 s del mundo")
	for id: String in ["1-2", "1-3"]:
		var other := (load("res://scenes/levels/%s.tscn" % id) as PackedScene).instantiate() as GeneratedLevel
		for node: Node in other.find_children("*", "", true, false):
			if node is Charger:
				assert_almost_eq((node as Charger).cooldown_s, 10.0, EPS, "%s %s: 10 s" % [id, node.name])
		other.free()
