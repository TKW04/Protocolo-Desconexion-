# Nivel 3-3 «Espejo, espejito» con el flujo real (scenes/main.tscn, LevelRunner; paso 13
# de docs/propuesta-mundo-3.md §8, 2026-10-27): carga por el atajo de depuracion
# (--start-level=3-3) y llegada por el vortice con Pellizcar y 0 likes, objetos y
# economia (10 puntos, 3 cargadores, 15 corazones, 4 publicaciones, power bank, msg_3_3),
# el espejo cazador de la sala (pulso congelado mirando al n -> puente), las placas y
# puertas de marco con el Reflejo falso, el examen (filtro con pinchos ocultos, Ladrones,
# cazador y reflejo), los secretos A (vitrina tras la pared que solo se ve con el Debug,
# con msg_3_3), B (vitrina alta con el power bank) y C (♥25), el marco dorado de salida
# (skin golden_frame) -> hub con el 3-3 completado y la fila del jefe desbloqueada (aun
# «Próximamente»), y la fila del 3-3 en la carpeta del Mundo 3 tras el 3-2. La ruta
# completa la comprueban tools/validate_level.py (tests/test_level_3_3.py) y el bot de la
# galeria (tests/test_gallery_bot.gd); aqui Isak se coloca en cada punto. Usa su propia
# ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_3_3.json"
const LEVEL_ID: String = "3-3"
const TILE: float = 64.0
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
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
	# Se llega al 3-3 tras completar el 3-2: todo el kit, Pellizcar incluido.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"3-3")


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
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, false)
	GameState.set_likes(0)
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


func _teleport(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	_isak.snap_camera()


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

func test_debug_shortcut_loads_the_3_3_with_compress() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=3-3"])), "3-3",
		"Atajo de depuracion -- --start-level=3-3")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(280 * 64, 14 * 64), "Galeria de 280 x 14")
	assert_eq(_level().world, 3, "Mundo 3")
	await _arrive()
	assert_true(_isak.is_on_floor())
	assert_almost_eq(_isak.global_position.x, 3.5 * TILE, TILE, "Vortice en la columna 3")
	assert_eq(GameState.likes, 0, "El contador empieza en 0")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), "Llega con Pellizcar")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 10, "10 puntos (6 + 2 del A + 1 del B + 1 del C)")
	assert_eq(_count("Objects", Charger), 3, "3 cargadores")
	assert_eq(_count("Objects", HeartPickup), 15, "15 corazones")
	assert_eq(_count("Objects", LikeSource), 4, "4 publicaciones")
	assert_eq(_count("Objects", LikePlatform), 3, "♥10, ♥15 y ♥25")
	assert_eq(_count("Objects", Mirror), 5, "Espejos fijos: 1 + 2 de la sala y 2 del secreto B")
	assert_eq(_count("Objects", HunterMirror), 3, "Cazadores: sala, secreto B y examen")
	assert_eq(_count("Objects", MirrorWall), 3, "Paredes de espejo: ambos lados, reflejo y examen")
	assert_eq(_count("Objects", PosePlate), 3)
	assert_eq(_count("Objects", FrameDoor), 3)
	assert_eq(_count("Objects", FilterZone), 1, "El filtro del examen")
	assert_eq(_count("Objects", SmallFrame), 1, "El marco de la pared de marcos")
	assert_eq(_count("Objects", PowerBankPickup), 1, "Un power bank (secreto B)")
	assert_eq(_count("Objects", MemoryPickup), 1, "msg_3_3 (secreto A)")
	assert_eq(_count("Objects", ExtraLifePickup), 0, "Sin vida extra")
	assert_eq(_count("Enemies", FalseReflection), 2, "Reflejo falso del Tramo 3 y del examen")
	assert_eq(_count("Enemies", LikeThief), 2)


func test_hunter_frozen_facing_north_extends_its_bridge() -> void:
	_start()
	await _arrive()
	var hunter := _obj("cazador_sala") as HunterMirror
	var bridge := _obj("puente_cazador") as PulseBridge
	assert_eq(hunter.get_rest_facing_name(), "e", "Reposa mirando al este (al foso)")
	_teleport(58, 11)
	await wait_physics_frames(2)
	hunter.auto_process = false
	for i: int in 2:
		hunter.advance(hunter.get_turn_interval_s() + 0.01)
	assert_eq(hunter.get_facing_name(), "n", "Con Isak al oeste gira e -> ne -> n")
	hunter.freeze()
	hunter.fire_beam()
	bridge.advance(LONG_STEP_S)
	assert_true(bridge.is_extended(), "El haz hacia el norte llega al receptor del techo y tiende el puente")


func test_plates_hold_their_frame_doors() -> void:
	_start()
	await _arrive()
	for pair: Array in [["placa_1", "puerta_1"], ["placa_2", "puerta_2"], ["placa_examen", "puerta_examen"]]:
		var plate := _obj(pair[0]) as PosePlate
		var door := _obj(pair[1]) as FrameDoor
		assert_not_null(plate)
		assert_true(door.is_solid(), "%s cerrada" % pair[1])
		var plate_col: int = roundi(plate.global_position.x / TILE)
		var door_col: int = roundi(door.global_position.x / TILE)
		assert_between(door_col - plate_col, 3, 3, "%s a 3 tiles de su placa: Isak solo llega antes de que abra" % pair[1])
		_teleport(plate_col, 11)
		await wait_physics_frames(3)
		plate.advance(0.05)
		door.advance(door.get_open_s() + 0.05)
		assert_true(door.is_open(), "%s se abre con su placa pisada" % pair[1])
		_teleport(door_col + 2, 11)
		await wait_physics_frames(3)


func test_exam_filter_hides_two_spikes() -> void:
	_start()
	await _arrive()
	var filter := _obj("filtro_examen") as FilterZone
	assert_eq(filter.get_label_text(), "Filtro: Retrato · Sin poros")
	assert_eq(filter.get_hidden_spike_cells(), [Vector2i(231, 12), Vector2i(234, 12)] as Array[Vector2i])


func test_secret_a_hidden_vitrine_only_with_the_debug() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_vitrina") as GlitchWall
	assert_not_null(wall)
	assert_true(wall.visible_only_with_debug, "Parece terreno normal sin el Debug")
	var pickup := _obj("mensaje_3_3") as MemoryPickup
	assert_eq(pickup.memory_id, &"msg_3_3")
	var before: int = GameState.attention_points
	for col: int in [217, 218, 219]:
		_teleport(col, 11)
		await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 2, "Los 2 puntos de la vitrina")
	assert_true(GameState.has_memory(&"msg_3_3"), "msg_3_3 recogido")


func test_secret_b_vitrine_with_the_power_bank() -> void:
	_start()
	await _arrive()
	var banks: int = GameState.get_power_banks_found()
	var before: int = GameState.attention_points
	for col: int in [197, 198]:
		_teleport(col, 7)
		await wait_physics_frames(6)
	assert_eq(GameState.get_power_banks_found(), banks + 1, "El power bank de la vitrina alta")
	assert_eq(GameState.attention_points, before + 1, "Y su punto")


func test_secret_c_needs_twenty_five_likes() -> void:
	_start()
	await _arrive()
	var top := _obj("likes_25") as LikePlatform
	GameState.set_likes(24)
	top.advance(0.1)
	assert_false(top.is_solid(), "Con 24 likes la ♥25 no esta")
	GameState.set_likes(25)
	top.advance(0.1)
	assert_true(top.is_solid(), "Con 25 aparece")


func test_golden_frame_completes_the_level_and_unlocks_the_boss_row() -> void:
	_start()
	await _arrive()
	var terminal := _obj("marco_dorado") as ExitTerminal
	assert_not_null(terminal)
	assert_eq(terminal.skin, &"golden_frame")
	assert_eq(terminal.get_frames_path(), "res://assets/sprites/golden_frame_terminal_frames.tres")
	var frames := load(terminal.get_frames_path()) as SpriteFrames
	var base := load("res://assets/sprites/warp_objects_frames.tres") as SpriteFrames
	for anim: StringName in [&"terminal_off", &"terminal_prompt", &"terminal_boot", &"terminal_on"]:
		assert_eq(frames.get_frame_count(anim), base.get_frame_count(anim), "Mismos cuadros que %s" % anim)
		assert_eq(frames.get_frame_texture(anim, 0).get_size(), Vector2(64, 128), "Mismo tamano")
	_teleport(275, 11)
	await wait_physics_frames(3)
	assert_true(terminal.activate(_isak), "El pulso activa el marco dorado")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"3-3"), "3-3 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"3-boss"), "Desbloquea la fila del jefe")
	assert_eq(GameState.likes, 0, "Los likes no se guardan")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m3").get_folder_panel()
	assert_eq(panel.get_level_state(&"3-3"), HubWorlds.STATE_COMPLETED)
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m3"))
	assert_true(HubWorlds.is_coming_soon(levels[3]), "La Curadora sigue «Próximamente» hasta el paso 17")


func test_world_3_folder_lists_3_3_after_the_3_2_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m3")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m3"))
	assert_eq(panel.level_text(levels[2]), "3-3 Espejo, espejito - Nueva foto")
	assert_false(HubWorlds.is_coming_soon(levels[2]), "3-3 jugable")
	assert_true(HubWorlds.is_coming_soon(levels[3]), "Jefe «Próximamente»")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"3-3"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 3-3")
