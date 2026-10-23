# Nivel 2-3 «Scroll infinito» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 14 de docs/propuesta-mundo-2.md §8, 2026-10-23): carga por el atajo de
# depuracion (--start-level=2-3) con llegada por el vortice y el scroll parado,
# objetos y economia (10 puntos, 3 cargadores, power bank, mensaje de Mamá), la
# inversion del Tramo 2 que arma su zona (la camara del nivel), el muro «Cargando
# más…» que rompen 3 golpes y la zona de clones que limpia la onda, el secreto
# «Fuera del feed», el cierre con la cuenta automatica -> hub con el 2-3
# completado, y la carpeta del Mundo 2: el 2-3 «Siguiente video» tras el 2-2. La
# ruta completa la comprueban tools/validate_level.py (tests/test_level_2_3.py) y
# el bot del feed (tests/test_feed_bot.gd); aqui Isak se coloca en cada punto. Usa
# su propia ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_2_3.json"
const LEVEL_ID: String = "2-3"
const TILE: float = 64.0
const ROWS: int = 170
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
const DT: float = 1.0 / 60.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND

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
	# Se llega al 2-3 tras el 2-2: todo el kit, tambien el golpe al suelo.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"2-3")


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
	GameState.set_ability_unlocked(POUND, false)
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Fila del grid de la altura h (h 0 = suelo de la sala de inicio).
func _row(h: int) -> int:
	return 169 - h


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
		vortex.advance(DT)
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


func _feet(col: int, row: int) -> Vector2:
	return Vector2((col + 0.5) * TILE, (row + 1) * TILE)


func _count(parent: String, cls: Variant) -> int:
	var n: int = 0
	var node: Node = _level().get_node_or_null(NodePath(parent))
	if node == null:
		return 0
	for child: Node in node.get_children():
		if is_instance_of(child, cls):
			n += 1
	return n


## Una camara de scroll con la seccion scroll del nivel (sin la fisica de Isak).
func _level_camera() -> ScrollCamera:
	var cam := ScrollCamera.load_from_file()
	cam.configure(Vector2(1280.0, 720.0), Rect2(0.0, 0.0, 20.0 * TILE, ROWS * TILE), _isak.scroll_config, TILE)
	return cam


func _run(cam: ScrollCamera, feet: Vector2, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		cam.update(feet, DT)


# --- Pruebas ---

func test_debug_shortcut_loads_the_2_3_parked_in_the_start_room() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=2-3"])), "2-3",
		"Atajo de depuracion -- --start-level=2-3")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(20 * 64, ROWS * 64), "Feed de 20 x 170")
	assert_eq(_level().world, 2, "Mundo 2")
	await _arrive()
	assert_true(_isak.is_on_floor())
	assert_eq(roundi(_isak.global_position.y / TILE), _row(1) + 1, "De pie sobre el suelo de la sala de inicio")
	var camera: ScrollCamera = _isak.get_scroll_camera()
	assert_not_null(camera, "Camara de scroll forzado")
	assert_true(camera.is_parked(), "Parado en la sala de inicio hasta subir")
	assert_true(GameState.is_ability_obtained(POUND), "Llega con el golpe al suelo")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 10, "10 puntos de atencion (6 + 4)")
	assert_eq(_count("Objects", Charger), 3, "3 cargadores")
	assert_eq(_count("Objects", PowerBankPickup), 1, "Un power bank (vacio)")
	assert_eq(_count("Objects", ExtraLifePickup), 0, "Sin vida extra")
	assert_eq(_count("Objects", MemoryPickup), 1, "El mensaje de Mamá (secreto A)")
	assert_eq(_count("Objects", FragileCard), 6, "Bajadas, puertas de pie y la fragil del patron 13")
	assert_eq(_count("Objects", StoryCard), 4, "Tres Historias del camino y la del secreto C")
	assert_eq(_count("Objects", CloneZone), 1, "La zona del muro")
	assert_eq(_count("Objects", LoadingWall), 1, "El muro «Cargando más…»")
	assert_eq(_count("Enemies", AutoplayVideo), 3, "Un video en los Tramos 1, 3 y 4")
	assert_eq(_count("Enemies", Commenter), 1, "Un Comentarista abajo en el Tramo 2")


func test_reverse_is_armed_by_its_zone_down_the_pit() -> void:
	_start()
	await _arrive()
	var cam := _level_camera()
	_run(cam, _feet(13, _row(7)), 0.5)
	assert_false(cam.is_parked(), "Arranca al subir")
	# Isak sube por delante del scroll hasta el borde del Tramo 2 (h 66): ahi no se invierte.
	_run(cam, _feet(13, _row(67)), 40.0)
	assert_false(cam.is_reversing(), "En el borde aun no")
	# Baja al segundo piso (zona trigger): se arma con aviso y empieza 1 s despues.
	_run(cam, _feet(7, _row(64)), 0.2)
	assert_true(cam.reverse_soon(), "Aviso de inversion")
	_run(cam, _feet(7, _row(64)), 1.0)
	assert_true(cam.is_reversing(), "El scroll baja")
	assert_eq(cam.damaging_edge(), ScrollCamera.EDGE_TOP, "Dana el borde de arriba")
	var b0: float = cam.get_bottom()
	_run(cam, _feet(7, _row(60)), 1.0)
	assert_almost_eq(cam.get_bottom() - b0, 0.8 * TILE, 2.0, "Baja a 0,8 tiles/s")
	_run(cam, _feet(7, _row(60)), 5.2)
	assert_false(cam.is_reversing(), "Termina a los 6 s")
	assert_eq(cam.damaging_edge(), ScrollCamera.EDGE_BOTTOM)


func test_loading_wall_needs_three_pounds_and_the_wave_clears_the_clones() -> void:
	_start()
	await _arrive()
	var wall := _obj("muro_carga") as LoadingWall
	var zone := _obj("enjambre_muro") as CloneZone
	assert_not_null(wall)
	assert_not_null(zone)
	assert_true(wall.is_solid())
	_isak.set(&"_scroll_camera", null)  # Isak se coloca lejos de la vista: sin el borde del scroll
	_teleport(11, 24)
	for i: int in 200:
		zone.step(DT)
	assert_gt(zone.get_spawned_total(), 0, "Quedarse junto al muro hace nacer clones")
	var feet := _feet(11, 24) + Vector2(16.0, 0.0)
	var wave := Rect2(feet.x - 96.0, feet.y - 64.0, 192.0, 72.0)
	for k: int in 3:
		assert_true(wall.is_solid(), "Aun en pie antes del golpe %d" % (k + 1))
		EventBus.ground_pound_landed.emit(wave, _isak)
		wall.advance(0.5)
		assert_eq(zone.get_clone_count(), 0, "La onda limpia la zona")
	assert_true(wall.is_broken(), "Tres golpes lo rompen")
	assert_false(wall.is_solid())


func test_secret_out_of_the_feed_gives_the_message_and_two_points() -> void:
	_start()
	await _arrive()
	assert_false(GameState.has_memory(&"msg_2_3"))
	var before: int = GameState.attention_points
	_isak.set(&"_scroll_camera", null)  # Isak se coloca lejos de la vista: sin el borde del scroll
	for col: int in [16, 17, 18]:
		_teleport(col, 57)
		await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_2_3"), "Obtiene el mensaje de Mamá")
	assert_eq(GameState.attention_points, before + 2, "Y los dos puntos del secreto")


func test_closing_card_counts_down_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_scroll_infinito") as ExitTerminal
	assert_true(terminal.is_automatic(), "Cuenta automatica")
	terminal.call(&"_on_body_entered", _isak)
	terminal.advance(0.1)
	assert_eq(terminal.get_state(), ExitTerminal.State.COUNTDOWN)
	for i: int in 3:
		terminal.advance(1.0)
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"2-3"), "2-3 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"2-boss"), "Desbloquea la fila del jefe")


func test_world_2_folder_shows_the_next_video_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m2")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m2"))
	assert_eq(panel.get_level_state(&"2-3"), HubWorlds.STATE_AVAILABLE, "El 2-3, tras el 2-2")
	assert_eq(panel.level_text(levels[2]), "2-3 Scroll infinito - Siguiente video", "Como el 2-2: «Siguiente video»")
	assert_eq(panel.level_text(levels[3]), "Jefe: Autoplay - Bloqueado", "Jugable desde el paso 18, tras el 2-3")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"2-3"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 2-3")
