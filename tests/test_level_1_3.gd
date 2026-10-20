# Nivel 1-3 «No molestar» con el flujo real (scenes/main.tscn, LevelRunner; paso
# 10 de docs/propuesta-1-3.md §7, 2026-10-20): carga por el atajo de depuracion
# (--start-level=1-3) y llegada por el vortice en la sala «Ajustes», camara
# horizontal, obtencion de Deslizar con el interruptor «No molestar» (y el tinte
# de todo el nivel), banner obligatorio que devuelve a la entrada y se cruza con
# el dash, metronomo y tunel, secreto «Excepciones» con el Debug, economia (9
# puntos, 3 cargadores, 1 power bank, sin vida extra), puntos de sincronizacion
# y vidas, terminal de la pantalla de bloqueo -> hub con el 1-3 completado, y
# entrada desde la carpeta del Mundo 1. La ruta completa la comprueba
# tools/validate_level.py (tests/test_level_1_3.py); aqui Isak se coloca en cada
# punto. Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_1_3.json"
const LEVEL_ID: String = "1-3"
const TILE: float = 64.0
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
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, false)
	DebugMode.input_enabled = false
	# Se llega al 1-3 tras el 1-2: Eco, Notas, Calc, el pulso, el laser y el Debug ya estan.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	GameState.obtained_abilities[GameState.ABILITY_LASER] = true
	GameState.seen_notices[GameState.ABILITY_LASER] = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	EcoProgress.obtain_debug()
	GameState.mark_level_completed(&"1-1")
	GameState.mark_level_completed(&"1-2")
	GameState.unlock_level(&"1-2")
	GameState.unlock_level(&"1-3")


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


func _enemy(id: String) -> Node:
	return _level().get_node_or_null(NodePath("Enemies/" + id))


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

func test_debug_shortcut_loads_the_1_3_with_arrival_in_ajustes() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=1-3"])), "1-3",
		"Atajo de depuracion -- --start-level=1-3")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(260 * 64, 14 * 64), "Horizontal de 260 x 14")
	var vortex: WarpVortex = _main.get_arrival_vortex()
	assert_not_null(vortex, "Llega por el vortice")
	assert_almost_eq(vortex.global_position.x, 4.5 * TILE, TILE, "En la sala «Ajustes» (columna 4)")
	await _arrive()
	assert_ne(_isak.camera_mode, Isak.CAMERA_TOWER, "Camara horizontal, como el 1-1")
	assert_true(_isak.is_on_floor())
	assert_eq(roundi(_isak.global_position.y / TILE), 10, "De pie en la fila 9 (suelo en la 10)")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Con el Debug del 1-2")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DASH), "Sin Deslizar hasta el interruptor")


func test_dnd_switch_gives_the_dash_and_tints_the_whole_level() -> void:
	_start()
	await _arrive()
	var sw := _obj("dnd_1_3") as DndSwitch
	assert_not_null(sw, "Interruptor «No molestar» en la sala «Ajustes»")
	assert_false(sw.is_on())
	assert_false(sw.is_room_tinted())
	assert_true(sw.switch_on())
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DASH), "Obtiene Deslizar")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DASH))
	sw.advance(2.0)
	assert_true(sw.get_room_tint().is_equal_approx(sw.get_room_tint_target()), "Tinte de todo el nivel")
	var tints: Array[Node] = _level().find_children("*", "CanvasModulate", true, false)
	assert_eq(tints.size(), 1, "Un solo CanvasModulate en el nivel")
	# Al reiniciar el mapa con el dash ya obtenido arranca encendido, inerte y con el tinte.
	assert_true(_main.start_level(LEVEL_ID))
	_main.advance(LONG_STEP_S)
	await _arrive()
	var again := _obj("dnd_1_3") as DndSwitch
	assert_true(again.is_on() and again.is_inert(), "Un solo uso")
	assert_true(again.is_room_tinted(), "El nivel empieza con el tinte")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 9, "9 puntos de atencion (6 + 3)")
	assert_eq(_count("Objects", Charger), 3, "3 cargadores")
	assert_eq(_count("Objects", PowerBankPickup), 1, "1 power bank vacio (secreto C)")
	assert_eq(_count("Objects", ExtraLifePickup), 0, "Sin vida extra")
	assert_eq(_count("Objects", MemoryPickup), 1, "El mensaje de Mamá (secreto A)")
	assert_eq(_count("Objects", BlinkPlatform), 5)
	assert_eq(_count("Objects", AlarmTunnel), 1)
	assert_true(_obj("ritmo_2") is RhythmZone, "Metronomo del Tramo 2")
	assert_true(_obj("panel_excepciones") is ExceptionsPanel)
	assert_true(_obj("terminal_bloqueo") is ExitTerminal)
	assert_eq(_count("Enemies", SpamBanner), 8, "1a, 1b, dos del 1c, 3a y tres del tunel")
	assert_eq(_count("Enemies", AlarmBell), 9)
	assert_eq(_count("Enemies", AlertBubble), 2, "3a y 3c")
	assert_eq(_count("Enemies", NotificationBadge), 2, "3b")
	var tunnel := _obj("tunel_alarmas") as AlarmTunnel
	assert_not_null(tunnel)
	for bell_id: String in ["bell_4a_1", "bell_4c_3"]:
		assert_true(_enemy(bell_id) is AlarmBell, bell_id)


func test_mandatory_banner_returns_to_the_entry_and_needs_the_dash() -> void:
	_start()
	await _arrive()
	var banner := _enemy("banner_dash") as SpamBanner
	assert_not_null(banner)
	assert_true(banner.knockback_to_entry, "El golpe devuelve a la entrada del pasillo")
	assert_almost_eq(banner.get_return_position().x, 26.5 * TILE, 0.001, "Vuelta: la columna 26")
	assert_eq(HelpCatalog.help_id_of(banner), &"spam_banner_dash", "Ayuda propia del banner obligatorio")
	var cargador := _obj("cargador_1") as Charger
	assert_lt(cargador.global_position.x, 27.0 * TILE, "Cargador antes del pasillo")


func test_secret_excepciones_needs_the_debug() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_excepciones") as GlitchWall
	assert_not_null(wall)
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	assert_false(wall.is_glitch_shown())
	assert_false(GameState.has_memory(&"msg_1_3"))
	# Dentro de la sala (la ruta con el Debug la comprueba el validador): el mensaje y el punto.
	var before: int = GameState.attention_points
	_teleport(125, 4)
	await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_1_3"), "Obtiene el mensaje de Mamá")
	_teleport(127, 4)
	await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 1, "Y el punto del secreto")


func test_sync_points_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	var sync_2 := _level().get_node(^"Checkpoints/sync_2") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 75.5 * TILE, TILE, "sync_1 al entrar al Tramo 2")
	assert_almost_eq(sync_2.global_position.x, 187.5 * TILE, TILE, "sync_2 al entrar al Tramo 4")
	sync_1.activate()
	_teleport(90, 9)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")
	sync_2.activate()
	_teleport(200, 9)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 1)
	assert_true(_isak.global_position.is_equal_approx(sync_2.get_spawn_position()), "Reaparece en sync_2")


func test_lock_screen_terminal_completes_the_level_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_bloqueo") as ExitTerminal
	assert_true(terminal.activate(_isak), "El pulso activa la pantalla de bloqueo")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub (Alerta Mayor aun no existe)")
	assert_true(GameState.is_level_completed(&"1-3"), "1-3 en completed_levels")
	var m1: Dictionary = HubWorlds.world(&"m1")
	assert_eq(HubWorlds.folder_state(m1), HubWorlds.STATE_COMPLETED, "La carpeta del Mundo 1 completa")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m1").get_folder_panel()
	assert_eq(panel.get_level_state(&"1-3"), HubWorlds.STATE_COMPLETED)


func test_hub_lists_1_3_after_1_2_and_the_folder_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m1")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	assert_eq(panel.level_text(HubWorlds.levels(HubWorlds.world(&"m1"))[2]), "1-3 No molestar - Nuevo")
	for line: String in panel.get_lines():
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(line.contains(word), "«%s» no dice «%s»" % [line, word])
	panel.skip_input_delay()
	assert_true(panel.select_option(&"1-3"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "La carpeta carga el 1-3")
