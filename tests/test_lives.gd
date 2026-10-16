# Vidas (intentos; docs/propuesta-asistentes-y-vidas.md §5.1, paso 11 de §10):
# GameState (cuentan desde la primera llegada al hub, se reponen al empezar cada
# intento y no en el punto de sincronizacion, la ultima lleva al game over, hueco
# de la vida extra), el flujo real del 1-1 (LevelRunner: morir resta una y
# reaparece en el checkpoint, ilimitadas antes de conocer a Notas, 0 -> game over
# y hub) y el HUD de vidas (mini telefonos junto a la senal, oculto antes de que
# cuenten y en el hub, animacion al perder una, «x<n>» con muchas).
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_lives.json"
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


# --- Utilidades ---

func _start() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.advance(LONG_STEP_S)
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()
	await wait_physics_frames(LAND_FRAMES)


func _teleport(col: float, floor_row: int = 10) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, floor_row * TILE)
	_isak.velocity = Vector2.ZERO


## Mata a Isak (Sync Rate 0) y avanza el flujo hasta despues del fundido.
func _die() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead(), "Muere con Sync Rate 0")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


func _level_hud() -> Hud:
	return _main.get_level().get_node_or_null(^"Hud") as Hud


# --- GameState ---

func test_lives_do_not_count_before_the_first_hub() -> void:
	assert_false(GameState.are_lives_active(), "Partida nueva: sin Notas, las vidas no cuentan")
	GameState.refill_lives()
	for i: int in 5:
		assert_false(GameState.lose_life(), "Muertes ilimitadas en el primer recorrido del 1-1")
	assert_eq(GameState.lives, GameState.LIVES_MAX_DEFAULT, "No se resta nada")


func test_lives_start_at_three_and_the_last_one_is_game_over() -> void:
	EcoProgress.meet_notas()
	assert_true(GameState.are_lives_active(), "Desde la primera llegada al hub (Notas conocida)")
	assert_eq(GameState.lives_max, 3, "Base 3 (lives_max del guardado v3)")
	GameState.refill_lives()
	var lost: Array = []
	EventBus.life_lost.connect(func(left: int) -> void: lost.append(left))
	assert_false(GameState.lose_life())
	assert_false(GameState.lose_life())
	assert_true(GameState.lose_life(), "La tercera muerte es game over")
	assert_eq(GameState.lives, 0)
	assert_eq(lost, [2, 1, 0])
	assert_false(GameState.has_unsaved_changes(), "Las vidas actuales no se guardan")


func test_lives_are_not_saved_but_lives_max_is() -> void:
	EcoProgress.meet_notas()
	GameState.refill_lives()
	GameState.lose_life()
	var data: Dictionary = GameState.to_save_data()
	assert_false(data.has("lives"), "Las vidas actuales no van a disco")
	assert_eq(int(data["lives_max"]), 3)


func test_add_max_life_is_the_hook_for_the_extra_life() -> void:
	EcoProgress.meet_notas()
	GameState.refill_lives()
	GameState.lose_life()
	GameState.add_max_life()
	assert_eq(GameState.lives_max, 4, "Sube el maximo para siempre")
	assert_eq(GameState.lives, 3, "Y suma una al intento en curso")
	assert_true(GameState.has_unsaved_changes(), "Es progreso: sin guardar")
	GameState.refill_lives()
	assert_eq(GameState.lives, 4)


# --- Flujo real (LevelRunner) ---

func test_starting_an_attempt_refills_lives() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.lives = 1
	await _start()
	assert_eq(GameState.lives, 3, "Empezar el nivel repone las vidas a lives_max")


func test_death_loses_one_life_and_respawns_at_the_checkpoint_which_does_not_refill() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	await _start()
	var checkpoint: Checkpoint = _main.get_level().get_node(^"Checkpoints/sync_1") as Checkpoint
	checkpoint.activate()
	_teleport(152.0)
	await wait_physics_frames(3)
	_die()
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_false(_main.is_in_hub(), "Con vidas restantes no hay game over")
	assert_true(_isak.global_position.is_equal_approx(checkpoint.get_spawn_position()), "Reaparece en el checkpoint")
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max(), "Con el Sync Rate lleno")
	# Volver a tocar el punto de sincronizacion no repone vidas.
	checkpoint.activate()
	_teleport(150.0, 10)
	await wait_physics_frames(20)
	assert_eq(GameState.lives, 2, "El punto de sincronizacion no repone vidas")


func test_unlimited_deaths_in_the_first_run_of_1_1() -> void:
	EcoProgress.meet_eco_with_pulse()
	await _start()
	for i: int in 4:
		_teleport(20.0 + i)
		await wait_physics_frames(3)
		_die()
		assert_false(_main.is_in_hub(), "Sin game over antes de la primera llegada al hub")
	assert_eq(_main.get_game_over_count(), 0)


func test_the_last_life_leads_to_game_over_and_the_hub() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	await _start()
	var reports: Array = []
	_main.game_over.connect(func(report: Dictionary) -> void: reports.append(report))
	for i: int in 2:
		_teleport(20.0 + i)
		await wait_physics_frames(3)
		_die()
		assert_false(_main.is_in_hub())
	_teleport(25.0)
	await wait_physics_frames(3)
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_main.is_game_over_pending(), "La ultima vida: game over pendiente")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Game over: Eco lleva a Isak al hub")
	assert_eq(reports.size(), 1)
	assert_eq(_main.get_game_over_count(), 1)
	assert_eq(_main.get_hub().rollback_report, reports[0], "El hub recibe el informe del rollback")
	assert_eq(GameState.lives, 3, "Tras el rollback las vidas se reponen")
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	var hub_isak: Isak = _main.get_hub().get_isak()
	await wait_physics_frames(3)
	assert_false(hub_isak.is_dead(), "Isak llega al hub entero (Sync Rate lleno)")
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max())


# --- HUD de vidas ---

func _spawn_hud() -> void:
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.finish_animations()


func test_hud_hides_lives_until_they_count() -> void:
	_spawn_hud()
	assert_false(_hud.is_lives_shown(), "Primer recorrido del 1-1: sin iconos de vidas")
	GameState.meet_ally(GameState.ALLY_NOTAS)
	GameState.refill_lives()
	assert_true(_hud.is_lives_shown(), "Desde la primera llegada al hub se ven")
	assert_eq(_hud.get_life_icon_count(), 3, "Un mini telefono por vida maxima")
	assert_eq(_hud.get_lives_lit(), 3)
	assert_eq(_hud.get_lives_text(), "", "Con pocas vidas no hay «x<n>»")


func test_hud_animates_a_lost_life() -> void:
	EcoProgress.meet_notas()
	GameState.refill_lives()
	_spawn_hud()
	assert_eq(_hud.get_lives_lit(), 3)
	GameState.lose_life()
	assert_eq(_hud.get_lives_lit(), 2, "Se apaga un telefono")
	assert_true(_hud.is_life_loss_animating(), "El que se apaga parpadea")
	await wait_seconds(float(HudConfig.shared().lives.get("lost_blink_s", 0.6)) + 0.2)
	assert_false(_hud.is_life_loss_animating(), "La animacion es breve")
	var icon: TextureRect = _hud.get_life_icons()[2]
	assert_eq(icon.modulate.a, 1.0)
	assert_eq(icon.scale, Vector2.ONE)


func test_hud_lives_icons_sit_left_of_the_signal_and_keep_the_other_indicators() -> void:
	EcoProgress.meet_notas()
	GameState.refill_lives()
	_spawn_hud()
	var row: HBoxContainer = _hud.get_node(^"Frame/Row") as HBoxContainer
	var lives: Node = row.get_node(^"Lives")
	assert_lt(lives.get_index(), row.get_node(^"Signal").get_index(), "Junto a la senal, a su izquierda")
	for node: String in ["Signal", "SyncLabel", "Battery", "AttentionIcon", "AttentionLabel"]:
		assert_true((row.get_node(NodePath(node)) as Control).visible, "%s sigue visible" % node)
	assert_eq(_hud.get_sync_text(), "100 %")


func test_hud_compacts_many_lives_and_hides_them_in_the_hub() -> void:
	EcoProgress.meet_notas()
	GameState.lives_max = 9
	GameState.refill_lives()
	_spawn_hud()
	assert_eq(_hud.get_life_icon_count(), 1, "Mas de max_icons: un solo icono")
	assert_eq(_hud.get_lives_text(), "x9")
	GameState.lose_life()
	assert_eq(_hud.get_lives_text(), "x8")
	_hud.enable_hub_mode(HubData.section("hud"))
	assert_false(_hud.is_lives_shown(), "En el hub no se muestran")


func test_hud_lives_art_has_full_and_empty_frames_without_red() -> void:
	var config: HudConfig = HudConfig.shared()
	var image: Image = config.asset_texture(&"lives").get_image()
	assert_eq(image.get_size(), Vector2i(32, 16), "Dos cuadros de 16x16 (lleno, vacio)")
	for red: Color in [config.color(&"low_sync"), config.color(&"damage"), Color.html("#e0004a")]:
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c: Color = image.get_pixel(x, y)
				if c.a > 0.0 and c.is_equal_approx(Color(red, 1.0)):
					fail_test("Rojo en el icono de vidas (%d, %d)" % [x, y])
					return
	pass_test("Sin rojo")


func test_level_hud_shows_lives_after_the_first_hub() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	await _start()
	var hud: Hud = _level_hud()
	assert_not_null(hud, "El nivel tiene HUD")
	if hud == null:
		return
	assert_true(hud.is_lives_shown())
	assert_eq(hud.get_lives_lit(), 3)
	_teleport(20.0)
	await wait_physics_frames(3)
	_die()
	assert_eq(hud.get_lives_lit(), 2, "Al reaparecer se ve una vida menos")
