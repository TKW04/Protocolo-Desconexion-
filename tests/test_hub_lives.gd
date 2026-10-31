extends GutTest
# Vidas al volver al hub (pedido del usuario 2026-10-31): las vidas perdidas en
# un nivel se conservan al volver al hub (completar o «Salir al hub»; p. ej.
# entra con 5, pierde 2, vuelve con 3) y el HUD del hub muestra las vidas
# actuales (antes ocultas en el hub). Lo que las repone sigue igual: empezar un
# intento de nivel (start_level), arrancar el juego en el hub y el game over
# (apply_rollback). Las vidas no se guardan: no cambia el rollback ni «sin guardar».

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_hub_lives.json"
const TILE: float = 64.0
const LAND_FRAMES: int = 90
const LONG_STEP_S: float = 5.0

var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool
var _main: LevelRunner
var _isak: Isak
var _hud: Hud


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false


func after_each() -> void:
	if is_instance_valid(_main):
		_main.free()
	if is_instance_valid(_hud):
		_hud.free()
	_main = null
	_hud = null
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
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _start() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.advance(LONG_STEP_S)
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()
	await wait_physics_frames(LAND_FRAMES)


func _die() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


func _lose_one_life_in_level(before: int = 3) -> void:
	_isak.global_position = Vector2((17.5 + before) * TILE, 10 * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(3)
	_die()
	assert_false(_main.is_in_hub(), "Con vidas restantes sigue en el nivel")
	assert_eq(GameState.lives, before - 1, "Morir resta una vida")


func _hub_hud() -> Hud:
	var hub: HubRoom = _main.get_hub()
	return hub.get_hud() if hub != null else null


func _assert_hub_shows_lives(expected: int) -> void:
	assert_true(_main.is_in_hub(), "Esta en el hub")
	assert_eq(GameState.lives, expected, "Vidas al llegar al hub")
	var hud: Hud = _hub_hud()
	assert_not_null(hud, "El hub tiene HUD")
	if hud == null:
		return
	assert_true(hud.is_hub_mode())
	assert_true(hud.is_lives_shown(), "El HUD del hub muestra las vidas")
	assert_eq(hud.get_life_icon_count(), GameState.lives_max, "Un telefono por vida maxima")
	assert_eq(hud.get_lives_lit(), expected, "Telefonos llenos = vidas actuales")


func _complete_level() -> void:
	EventBus.level_completed.emit("1-1")
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


# --- Vidas al llegar al hub ---

func test_completing_a_level_keeps_the_lost_lives_in_the_hub() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	await _start()
	await _lose_one_life_in_level()
	_complete_level()
	_assert_hub_shows_lives(2)
	_main.advance(LONG_STEP_S)
	assert_eq(GameState.lives, 2, "Seguir en el hub no las repone")


func test_user_example_five_lives_lose_two_return_with_three() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.lives_max = 5
	await _start()
	assert_eq(GameState.lives, 5, "Entra al nivel con 5")
	await _lose_one_life_in_level(5)
	await _lose_one_life_in_level(4)
	_complete_level()
	_assert_hub_shows_lives(3)


func test_exit_to_hub_keeps_the_lost_lives() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.mark_level_completed(&"1-1")
	await _start()
	await _lose_one_life_in_level()
	assert_true(_main.request_exit_to_hub(), "«Salir al hub» disponible en un nivel completado")
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_hub_exit_count(), 1)
	_assert_hub_shows_lives(2)


func test_entering_a_level_from_the_hub_still_refills_lives() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	await _start()
	await _lose_one_life_in_level()
	_complete_level()
	assert_eq(GameState.lives, 2)
	assert_true(_main.start_level("1-1"))
	assert_eq(GameState.lives, GameState.lives_max, "Empezar un intento las repone (regla existente)")


func test_game_over_still_refills_lives_and_keeps_the_rollback() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	await _start()
	# Algo obtenido sin guardar: el game over lo pierde (rollback intacto).
	GameState.attention_points = 7
	for i: int in 2:
		_isak.global_position = Vector2((20.5 + i) * TILE, 10 * TILE)
		await wait_physics_frames(3)
		_die()
	_isak.global_position = Vector2(25.5 * TILE, 10 * TILE)
	await wait_physics_frames(3)
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_game_over_count(), 1, "Game over")
	assert_eq(GameState.attention_points, 0, "Lo no guardado se pierde (rollback)")
	_assert_hub_shows_lives(GameState.lives_max)


func test_starting_the_game_in_the_hub_has_full_lives() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.lives = 1
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "hub"
	add_child(_main)
	_main.advance(LONG_STEP_S)
	_assert_hub_shows_lives(GameState.lives_max)


# --- HUD del hub ---

func test_hub_hud_shows_the_current_lives_with_extra_max() -> void:
	EcoProgress.meet_notas()
	GameState.lives_max = 4
	GameState.refill_lives()
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.enable_hub_mode(HubData.section("hud"))
	_hud.finish_animations()
	assert_true(_hud.is_lives_shown(), "En el hub se ven las vidas")
	assert_eq(_hud.get_life_icon_count(), 4, "Un telefono por vida maxima (con la extra)")
	assert_eq(_hud.get_lives_lit(), 4)
	GameState.lose_life()
	assert_eq(_hud.get_lives_lit(), 3, "Sigue el numero actual")


func test_hub_hud_hides_lives_before_they_count_and_shows_them_on_meeting_notas() -> void:
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.enable_hub_mode(HubData.section("hud"))
	_hud.finish_animations()
	assert_false(_hud.is_lives_shown(), "Sin Notas las vidas aun no cuentan")
	GameState.meet_ally(GameState.ALLY_NOTAS)
	assert_true(_hud.is_lives_shown(), "Al conocer a Notas (primer hub) se ven ya")
	assert_eq(_hud.get_lives_lit(), GameState.lives_max)


func test_hub_hud_lives_do_not_overlap_the_other_hub_indicators() -> void:
	EcoProgress.meet_notas()
	GameState.refill_lives()
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.enable_hub_mode(HubData.section("hud"))
	_hud.finish_animations()
	await wait_frames(2)
	var row: HBoxContainer = _hud.get_node(^"Frame/Row") as HBoxContainer
	var lives: Control = row.get_node(^"Lives") as Control
	var rect: Rect2 = lives.get_global_rect()
	assert_gt(rect.size.x, 0.0)
	var viewport: Rect2 = Rect2(Vector2.ZERO, Vector2(1280, 720))
	assert_true(viewport.encloses(rect), "Las vidas caben en pantalla: %s" % rect)
	assert_lt(rect.end.y, 120.0, "En la franja superior del HUD (no baja al juego)")
	for node: Control in row.get_children():
		if node == lives or not node.visible:
			continue
		assert_false(rect.intersects(node.get_global_rect()), "No tapa %s" % node.name)
