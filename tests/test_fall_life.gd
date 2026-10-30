# Caer por un barranco cuesta una vida (2026-10-30, peticion del usuario; docs/propuesta-mundo-5.md
# §8.1 y docs/propuesta-asistentes-y-vidas.md §5): en todos los mapas (un nivel real de cada
# Mundo 1-5) la red de seguridad resta una vida y reaparece con el Sync Rate lleno; con la
# ultima, game over y hub; tras la caida los enemigos derrotados se recrean (EnemyRespawn) y
# lo recogido de los secretos (puntos, mensajes) se conserva; morir por dano no los recrea.
# Usa su propia ruta de guardado.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_fall_life.json"
const TILE: float = 64.0
const LAND_FRAMES: int = 60
const LONG_STEP_S: float = 5.0

var _saved_path: String
var _saved_level: StringName
var _main: LevelRunner
var _isak: Isak


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false


func after_each() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_isak = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _start(level_id: String) -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = level_id
	add_child(_main)
	_main.advance(LONG_STEP_S)
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()
	await wait_physics_frames(LAND_FRAMES)


## Isak por debajo del nivel: salta la red de seguridad y avanza el fundido.
func _fall() -> void:
	_isak.global_position = Vector2(_isak.global_position.x, _main.get_fall_limit_y() + 10.0)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


func test_a_fall_costs_a_life_in_every_world() -> void:
	for level_id: String in ["1-1", "2-1", "3-1", "4-1", "5-1"]:
		EcoProgress.meet_notas()
		await _start(level_id)
		assert_true(GameState.are_lives_active())
		var lives: int = GameState.lives
		GameState.sync_rate = 40.0
		await _fall()
		assert_eq(_main.get_fall_count(), 1, "%s: salta la red" % level_id)
		assert_eq(GameState.lives, lives - 1, "%s: caer cuesta una vida" % level_id)
		assert_eq(GameState.sync_rate, GameState.get_sync_rate_max(), "%s: reaparece con el Sync Rate lleno" % level_id)
		assert_false(_isak.is_dead())
		assert_false(_main.is_in_hub(), "%s: sigue en el nivel" % level_id)
		_main.free()
		_main = null
		GameState.reset_progress()


func test_the_last_life_lost_by_falling_is_game_over() -> void:
	EcoProgress.meet_notas()
	await _start("1-1")
	var overs: Array = []
	_main.game_over.connect(func(report: Dictionary) -> void: overs.append(report))
	for i: int in 2:
		await _fall()
		_isak = _main.get_isak()
	assert_eq(GameState.lives, 1)
	assert_false(_main.is_in_hub())
	await _fall()
	assert_eq(overs.size(), 1, "La ultima caida es game over")
	assert_true(_main.is_in_hub(), "Y vuelve al hub con el rollback")


func test_before_meeting_notas_falls_are_free_like_deaths() -> void:
	await _start("1-1")
	assert_false(GameState.are_lives_active())
	await _fall()
	await _fall()
	await _fall()
	assert_eq(_main.get_fall_count(), 3)
	assert_false(_main.is_in_hub(), "Sin vidas activas no hay game over")


func test_after_a_fall_enemies_come_back_and_secrets_stay_taken() -> void:
	EcoProgress.meet_notas()
	await _start("1-1")
	var level: GeneratedLevel = _main.get_level()
	var bubble := level.get_node(^"Enemies/burbuja_1") as AlertBubble
	var home: Vector2 = bubble._spawn_position
	bubble.free_on_pop = false
	bubble.stun()
	bubble.pop()
	assert_eq(bubble.get_state(), AlertBubble.STATE_POPPED)
	var memory := level.get_node(^"Objects/mensaje_1_1") as MemoryPickup
	assert_true(memory.collect(), "Mensaje del secreto A")
	var point := level.get_node(^"AttentionPoints/Point_8_9") as AttentionPoint
	_isak.global_position = point.global_position + Vector2(0.0, 40.0)
	await wait_physics_frames(3)
	var points: int = GameState.attention_points
	assert_gt(points, 0, "Punto recogido")
	await _fall()
	var again := level.get_node_or_null(^"Enemies/burbuja_1") as AlertBubble
	assert_not_null(again, "La Burbuja vuelve")
	assert_ne(again, bubble, "Recreada")
	assert_eq(again.get_state(), AlertBubble.STATE_PATROL, "Patrullando como al empezar")
	assert_true(again.global_position.is_equal_approx(home), "En su sitio")
	assert_true(again.is_in_group(&"help_target"), "Con su Q")
	assert_eq(GameState.attention_points, points, "Los puntos se quedan")
	assert_null(level.get_node_or_null(^"AttentionPoints/Point_8_9"), "El punto recogido no vuelve")
	assert_true(GameState.has_memory(&"msg_1_1"), "El mensaje del secreto se queda")
	var m2 := level.get_node_or_null(^"Objects/mensaje_1_1") as MemoryPickup
	assert_true(m2 == null or m2.is_taken() or not m2.visible, "Y su sobre no vuelve")


func test_dying_by_damage_does_not_recreate_enemies() -> void:
	EcoProgress.meet_notas()
	await _start("1-1")
	var bubble := _main.get_level().get_node(^"Enemies/burbuja_1") as AlertBubble
	bubble.free_on_pop = false
	bubble.stun()
	bubble.pop()
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_level().get_node(^"Enemies/burbuja_1"), bubble, "Morir por dano: la regla de siempre")
	assert_eq(bubble.get_state(), AlertBubble.STATE_POPPED)
