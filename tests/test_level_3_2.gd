# Nivel 3-2 «Sin filtro» con el flujo real (scenes/main.tscn, LevelRunner; paso 12
# de docs/propuesta-mundo-3.md §8, 2026-10-27): carga por el atajo de depuracion
# (--start-level=3-2) y llegada por el vortice sin Pellizcar y con 0 likes, objetos y
# economia (10 puntos, 3 cargadores, 15 corazones, 2 publicaciones, power bank, sin
# mensaje ni vida extra), «Recortar» que da Pellizcar con «Te queda mejor así.», la
# linea de Eco que recuerda el marco del 3-1, los marcos pequenos, los filtros (suelo
# falso, pinchos ocultos y el filtro movil), los secretos A (vitrina tras el sotano), B
# (♥20) y C (nicho tras el marco de la repisa), el punto de sincronizacion, la terminal
# «Publicar sin filtro» -> hub con el 3-2 completado y el 3-3 desbloqueado, y la fila
# del 3-2 en la carpeta del Mundo 3 tras el 3-1. La ruta completa la comprueban
# tools/validate_level.py (tests/test_level_3_2.py) y el bot de la galeria
# (tests/test_gallery_bot.gd); aqui Isak se coloca en cada punto. Usa su propia ruta de
# guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_3_2.json"
const LEVEL_ID: String = "3-2"
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
	# Se llega al 3-2 tras completar el 3-1: todo el kit del Mundo 2, sin Pellizcar (lo da «Recortar»).
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1"]:
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

func test_debug_shortcut_loads_the_3_2_without_compress() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=3-2"])), "3-2",
		"Atajo de depuracion -- --start-level=3-2")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(250 * 64, 14 * 64), "Galeria de 250 x 14")
	assert_eq(_level().world, 3, "Mundo 3")
	await _arrive()
	assert_true(_isak.is_on_floor())
	assert_almost_eq(_isak.global_position.x, 3.5 * TILE, TILE, "Vortice en la columna 3")
	assert_eq(GameState.likes, 0, "El contador empieza en 0")
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), "Sin Pellizcar: lo da «Recortar»")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 10, "10 puntos (6 + 2 del A + 1 del B + 1 del C)")
	assert_eq(_count("Objects", Charger), 3, "3 cargadores")
	assert_eq(_count("Objects", HeartPickup), 15, "15 corazones en el Tramo 3")
	assert_eq(_count("Objects", LikeSource), 2, "2 publicaciones")
	assert_eq(_count("Objects", LikePlatform), 2, "♥10 y ♥20")
	assert_eq(_count("Objects", CropTool), 1, "«Recortar»")
	assert_eq(_count("Objects", SmallFrame), 6, "Seis marcos pequenos")
	assert_eq(_count("Objects", FilterZone), 3, "Dos filtros fijos y el movil")
	assert_eq(_count("Objects", PowerBankPickup), 1, "Un power bank (secreto B)")
	assert_eq(_count("Objects", ExtraLifePickup), 0, "Sin vida extra")
	assert_eq(_count("Objects", MemoryPickup), 0, "Sin mensaje propio (msg_3_2 esta en el 3-1)")
	assert_eq(_count("Enemies", InfluencerBot), 1)
	assert_eq(_count("Enemies", LikeThief), 1)


func test_crop_tool_gives_compress_with_the_decided_line() -> void:
	_start()
	await _arrive()
	var tool := _obj("recortar") as CropTool
	assert_not_null(tool)
	assert_eq(tool.global_position.x, 12 * TILE, "«Recortar» en la columna 12")
	assert_eq(tool.get_story_text(), "Te queda mejor así.", "La frase decidida del mundo")
	assert_true(tool.switch_on(), "El pulso de espaldas la usa")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), "Pellizcar obtenido")
	assert_false(tool.switch_on(), "Un solo uso")
	var exit := _obj("marco_salida") as SmallFrame
	assert_eq(exit.global_position, Vector2(21 * TILE, 11 * TILE), "La salida del Estudio es un marco pequeno")
	assert_eq(exit.get_hole_rect().size, Vector2(TILE, TILE), "Hueco de 1 tile")


func test_eco_line_recalls_the_small_frame_of_the_3_1() -> void:
	_start()
	await _arrive()
	var line := _obj("eco_marco_galeria") as EcoLine
	assert_not_null(line)
	assert_eq(line.text, "Ese marco de la galería… ahora sí cabes.")
	assert_false(line.important, "Linea no importante (no pausa)")
	assert_eq(roundi(line.global_position.x / TILE), 40, "En la columna 40, tras el primer marco del Recorte")


func test_filters_hide_fake_floors_and_spikes() -> void:
	_start()
	await _arrive()
	var first := _obj("filtro_orejitas") as FilterZone
	assert_eq(first.get_label_text(), "Filtro: Orejitas · Brillo +40")
	assert_eq(first.get_fake_floor_cells(), [Vector2i(91, 10), Vector2i(94, 10)] as Array[Vector2i],
		"Dos suelos falsos")
	assert_false(first.is_moving_filter())
	var second := _obj("filtro_glamour") as FilterZone
	assert_eq(second.get_hidden_spike_cells(), [Vector2i(181, 12)] as Array[Vector2i], "Un pincho oculto")
	var moving := _obj("filtro_movil") as FilterZone
	assert_true(moving.is_moving_filter())
	assert_eq(moving.get_position_count(), 3, "Tres sitios")
	assert_eq(moving.get_hidden_spike_cells().size(), 3, "Tres pinchos ocultos que no se mueven")


func test_secret_a_vitrine_behind_the_basement_frame() -> void:
	_start()
	await _arrive()
	var frame := _obj("marco_original") as SmallFrame
	assert_eq(frame.global_position, Vector2(95 * TILE, 11 * TILE), "Marco del sotano (95, 11)")
	var before: int = GameState.attention_points
	for col: int in [96, 97, 98]:
		_teleport(col, 11)
		await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 2, "Los 2 puntos de la vitrina «Original»")


func test_secret_b_needs_twenty_likes() -> void:
	_start()
	await _arrive()
	var high := _obj("likes_20") as LikePlatform
	GameState.set_likes(19)
	high.advance(0.1)
	assert_false(high.is_solid(), "Con 19 likes la ♥20 no esta")
	GameState.set_likes(20)
	high.advance(0.1)
	assert_true(high.is_solid(), "Con 20 aparece")
	var banks: int = GameState.get_power_banks_found()
	var before: int = GameState.attention_points
	for col: int in [165, 166]:
		_teleport(col, 3)
		await wait_physics_frames(6)
	assert_eq(GameState.get_power_banks_found(), banks + 1, "El power bank de la repisa")
	assert_eq(GameState.attention_points, before + 1, "Y su punto")


func test_secret_c_nook_behind_the_ledge_frame() -> void:
	_start()
	await _arrive()
	var frame := _obj("marco_repisa") as SmallFrame
	assert_eq(frame.global_position, Vector2(236 * TILE, 6 * TILE), "Marco de la repisa (236, 6)")
	var before: int = GameState.attention_points
	_teleport(237, 6)
	await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 1, "El punto del nicho")


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 127.5 * TILE, TILE, "sync_1 en la Pausa")
	GameState.obtain_ability(GameState.ABILITY_COMPRESS)
	sync_1.activate()
	_teleport(135, 11)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), "Pellizcar sigue obtenido")


func test_terminal_completes_the_level_and_unlocks_the_3_3() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_sin_filtro") as ExitTerminal
	assert_not_null(terminal)
	assert_true(terminal.activate(_isak), "El pulso activa «Publicar sin filtro»")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"3-2"), "3-2 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"3-3"), "Desbloquea la fila del 3-3")
	assert_eq(GameState.likes, 0, "Los likes no se guardan")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m3").get_folder_panel()
	assert_eq(panel.get_level_state(&"3-2"), HubWorlds.STATE_COMPLETED)
	assert_eq(panel.get_level_state(&"3-3"), HubWorlds.STATE_AVAILABLE, "El 3-3 disponible (paso 13)")


func test_world_3_folder_lists_3_2_after_the_3_1_and_loads_it() -> void:
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
	assert_eq(panel.level_text(levels[1]), "3-2 Sin filtro - Nueva foto")
	assert_false(HubWorlds.is_coming_soon(levels[2]), "3-3 jugable (paso 13)")
	assert_false(HubWorlds.is_coming_soon(levels[3]), "Jefe jugable (paso 17)")
	assert_eq(panel.get_level_state(&"3-boss"), HubWorlds.STATE_LOCKED, "Jefe bloqueado hasta el 3-3")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"3-2"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 3-2")
