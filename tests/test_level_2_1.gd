# Nivel 2-1 «Para ti» con el flujo real (scenes/main.tscn, LevelRunner; paso
# 11 de docs/propuesta-mundo-2.md §8, 2026-10-22): carga por el atajo de
# depuracion (--start-level=2-1) con llegada por el vortice en la sala de
# inicio, scroll forzado, carteles con la Q del reloj y del borde, objetos y
# economia (8 puntos, 3 cargadores con el del bucle, vida extra, mensaje de Mamá), secreto «Video
# en negro», punto de sincronizacion y vidas, cierre con la cuenta automatica de
# 3 s (sin pulso) -> hub con el 2-1 completado, y entrada desde la carpeta del
# Mundo 2 tras vencer a Alerta Mayor. La ruta completa la comprueba
# tools/validate_level.py (tests/test_level_2_1.py); aqui Isak se coloca en cada
# punto. Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_2_1.json"
const LEVEL_ID: String = "2-1"
const TILE: float = 64.0
const ROWS: int = 130
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0

var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool
var _main: LevelRunner
var _isak: Isak


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	DebugMode.input_enabled = false
	# Se llega al 2-1 tras vencer a Alerta Mayor: todo el kit del Mundo 1 (sin el golpe al suelo).
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)


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
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, false)
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Fila del grid de la altura h (h 0 = suelo de la sala de inicio).
func _row(h: int) -> int:
	return ROWS - 1 - h


func _start(level_id: String = LEVEL_ID) -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = level_id
	add_child(_main)


func _arrive() -> void:
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	for i: int in 600:
		if vortex == null or not is_instance_valid(vortex) or vortex.is_done():
			break
		vortex.advance(1.0 / 60.0)
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()
	await wait_physics_frames(LAND_FRAMES)


func _level() -> GeneratedLevel:
	return _main.get_level()


func _obj(id: String) -> Node:
	return _level().get_node_or_null(NodePath("Objects/" + id))


func _teleport(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	_isak.snap_camera()


func _die() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead(), "Muere con Sync Rate 0")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


func _count(parent: String, cls: Variant) -> int:
	var n: int = 0
	var node: Node = _level().get_node_or_null(NodePath(parent))
	if node == null:
		return 0
	for child: Node in node.get_children():
		if is_instance_of(child, cls):
			n += 1
	return n


# --- Pruebas ---

func test_debug_shortcut_loads_the_2_1_with_the_forced_scroll() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=2-1"])), "2-1",
		"Atajo de depuracion -- --start-level=2-1")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(20 * 64, ROWS * 64), "Feed de 20 x 130")
	assert_eq(_level().world, 2, "Mundo 2")
	var vortex: WarpVortex = _main.get_arrival_vortex()
	assert_not_null(vortex, "Llega por el vortice")
	assert_almost_eq(vortex.global_position.x, 3.5 * TILE, TILE, "En la sala de inicio (columna 3)")
	await _arrive()
	assert_true(_isak.is_on_floor())
	assert_eq(roundi(_isak.global_position.y / TILE), _row(1) + 1, "De pie sobre el suelo de la sala de inicio")
	var camera: ScrollCamera = _isak.get_scroll_camera()
	assert_not_null(camera, "Camara de scroll forzado")
	assert_true(camera.is_parked(), "Parado en la sala de inicio hasta subir")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_GROUND_POUND), "Sin golpe al suelo (es del 2-2)")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 8, "8 puntos de atencion (6 + 2)")
	assert_eq(_count("Objects", Charger), 3, "3 cargadores (uno dentro del bucle)")
	assert_eq(_count("Objects", PowerBankPickup), 0, "Sin power bank")
	assert_eq(_count("Objects", ExtraLifePickup), 1, "La vida extra del Mundo 2 (secreto B)")
	assert_eq(_count("Objects", MemoryPickup), 1, "El mensaje de Mamá (secreto A)")
	assert_eq(_count("Objects", FragileCard), 3, "Tres tarjetas fragiles")
	assert_eq(_count("Objects", CloneZone), 1, "Una zona de clones")
	assert_eq(_count("Objects", LoopSection), 1, "Un bucle")
	assert_eq(_count("Objects", FeedSign), 6, "Carteles del feed")
	assert_eq(_count("Enemies", AutoplayVideo), 3, "Ola, rayo y cuenta")
	var wall := _obj("pared_vida_extra") as GlitchWall
	assert_not_null(wall)
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	assert_false(wall.is_glitch_shown())


func test_signs_carry_the_help_of_the_clock_and_the_edge() -> void:
	_start()
	await _arrive()
	var para_ti := _obj("cartel_para_ti") as FeedSign
	assert_not_null(para_ti)
	assert_eq(para_ti.text, "Para ti")
	assert_eq(HelpCatalog.help_id_of(para_ti), &"hud_clock", "Q de Eco sobre el reloj en la sala de inicio")
	assert_eq(HelpCatalog.help_id_of(_obj("cartel_desliza")), &"feed_edge", "Q del borde en el Tramo 1")
	assert_true(HelpCatalog.shared().has(&"hud_clock") and HelpCatalog.shared().has(&"feed_edge"))
	assert_eq(HelpCatalog.shared().world(&"hud_clock"), 2)
	assert_eq(HelpCatalog.help_id_of(_obj("terminal_siguiente_video")), &"", "La terminal automatica sin Q del pulso")
	var closing := _obj("cartel_siguiente_video") as FeedSign
	assert_eq(closing.get_lines(), PackedStringArray(["Quedan 3 segundos para el siguiente video.",
		"No puedes cancelar"]))


func test_secret_black_video_gives_the_message_and_a_point() -> void:
	_start()
	await _arrive()
	assert_false(GameState.has_memory(&"msg_2_1"))
	var before: int = GameState.attention_points
	# La tarjeta en negro solo se pisa con el Debug (lo comprueba el validador): Isak se coloca en el secreto,
	# sin el scroll (el techo de carga no lo deja adelantarse a la vista).
	_isak.set(&"_scroll_camera", null)
	_teleport(1, _row(81))
	await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_2_1"), "Obtiene el mensaje de Mamá")
	_teleport(2, _row(81))
	await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 1, "Y el punto del secreto")


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.y, (_row(63) + 1) * TILE, TILE, "sync_1 en la Pausa (h 63)")
	sync_1.activate()
	_teleport(9, _row(63))
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")


func test_closing_card_counts_down_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_siguiente_video") as ExitTerminal
	assert_not_null(terminal)
	assert_true(terminal.is_automatic(), "Cuenta automatica")
	assert_eq(terminal.countdown_s, 3.0)
	watch_signals(terminal)
	terminal.call(&"_on_body_entered", _isak)
	terminal.advance(0.1)
	assert_signal_emitted(terminal, "countdown_started")
	assert_eq(terminal.get_state(), ExitTerminal.State.COUNTDOWN)
	assert_true(terminal.is_key_hint_visible(), "La placa muestra la cuenta")
	assert_eq(terminal.get_key_hint_text(), "3")
	terminal.advance(1.0)
	assert_eq(terminal.get_key_hint_text(), "2")
	var pulse := Area2D.new()
	assert_false(terminal.receive_pulse(pulse), "El pulso no hace nada")
	pulse.free()
	# No se cancela al salir de la zona.
	terminal.call(&"_on_body_exited", _isak)
	terminal.advance(1.0)
	assert_eq(terminal.get_key_hint_text(), "1")
	terminal.advance(1.0)
	assert_signal_emitted(terminal, "activated")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"2-1"), "2-1 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"2-2"), "Desbloquea la fila del 2-2")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m2").get_folder_panel()
	assert_eq(panel.get_level_state(&"2-1"), HubWorlds.STATE_COMPLETED)


func test_world_2_folder_lists_2_1_after_the_boss_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m2")
	assert_false(folder.is_locked(), "Mundo 2 abierto tras Alerta Mayor")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m2"))
	assert_eq(panel.level_text(levels[0]), "2-1 Para ti - Nuevo")
	assert_eq(panel.get_level_state(&"2-2"), HubWorlds.STATE_LOCKED, "El 2-2 llega tras el 2-1")
	for line: String in panel.get_lines():
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(line.contains(word), "«%s» no dice «%s»" % [line, word])
	panel.skip_input_delay()
	assert_true(panel.select_option(&"2-1"))
	panel.confirm()
	if panel.is_confirming_unsaved():
		assert_true(panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED))
		panel.confirm()
	var departure: WarpVortex = hub.get_departure_vortex()
	assert_not_null(departure, "Vortice de salida")
	departure.advance(LONG_STEP_S)
	await wait_process_frames(2)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_false(_main.is_in_hub())
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 2-1")
