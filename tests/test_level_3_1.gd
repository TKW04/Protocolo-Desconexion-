# Nivel 3-1 «Galería de perfil» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 10 de docs/propuesta-mundo-3.md §8, 2026-10-26): carga por el atajo de
# depuracion (--start-level=3-1) y llegada por el vortice con el contador de likes
# a 0, objetos y economia (7 puntos, 2 cargadores, 18 corazones, 3 publicaciones,
# power bank, vida extra y los mensajes msg_3_1 / msg_3_2), la Q del contador de
# likes en el cartel de la sala de inicio, los corazones que encienden la ♥5, los
# tres secretos (A tras el marco pequeno, tambien rejugado con Pellizcar desde el paso 12, B con «Borrar publicaciones» y las
# inversas, C tras la pared con glitch), el punto de sincronizacion, la terminal
# «Publicar» -> hub con el 3-1 completado, y la carpeta del Mundo 3 tras Autoplay.
# La ruta completa la comprueba tools/validate_level.py (tests/test_level_3_1.py);
# aqui Isak se coloca en cada punto. Usa su propia ruta de guardado (nunca
# user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_3_1.json"
const LEVEL_ID: String = "3-1"
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
	# Se llega al 3-1 tras vencer a Autoplay: todo el kit del Mundo 2, sin Pellizcar.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss"]:
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

func test_debug_shortcut_loads_the_3_1_with_zero_likes() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=3-1"])), "3-1",
		"Atajo de depuracion -- --start-level=3-1")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(220 * 64, 14 * 64), "Galeria de 220 x 14")
	assert_eq(_level().world, 3, "Mundo 3")
	await _arrive()
	assert_true(_isak.is_on_floor())
	assert_almost_eq(_isak.global_position.x, 3.5 * TILE, TILE, "Vortice en la columna 3")
	assert_eq(roundi(_isak.global_position.y / TILE), 12, "De pie sobre el suelo de la fila 12")
	assert_eq(GameState.likes, 0, "El contador empieza en 0")
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), "Sin Pellizcar (llega en el 3-2)")
	assert_true(GameState.is_ability_obtained(POUND), "Con todo el kit del Mundo 2")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 7, "7 puntos de atencion (6 + 1 del secreto A)")
	assert_eq(_count("Objects", Charger), 2, "2 cargadores")
	assert_eq(_count("Objects", HeartPickup), 18, "18 corazones")
	assert_eq(_count("Objects", LikeSource), 3, "3 publicaciones")
	assert_eq(_count("Objects", LikePlatform), 6, "♥5, ♥10, ♥15 y las tres inversas")
	assert_eq(_count("Objects", LikeReset), 1, "«Borrar publicaciones» del secreto B")
	assert_eq(_count("Objects", SmallFrame), 1, "El marco pequeno del secreto A")
	assert_eq(_count("Objects", MirrorWall), 1, "La pared de espejo del Tramo 4")
	assert_eq(_count("Objects", MirrorOnlyPlatform), 2, "Dos plataformas del reflejo")
	assert_eq(_count("Objects", PowerBankPickup), 1, "Un power bank (secreto A)")
	assert_eq(_count("Objects", ExtraLifePickup), 1, "La vida extra del Mundo 3 (secreto C)")
	assert_eq(_count("Objects", MemoryPickup), 2, "msg_3_1 y msg_3_2")
	assert_eq(_count("Enemies", InfluencerBot), 2, "Dos Influencer en el Tramo 2")
	assert_eq(_count("Enemies", LikeThief), 1, "Un Ladron en el Tramo 3")


func test_sign_carries_the_help_of_the_likes_counter() -> void:
	_start()
	await _arrive()
	var sign := _obj("cartel_bendecido") as FeedSign
	assert_not_null(sign)
	assert_eq(sign.get_lines(), PackedStringArray(["Mi vida es increíble", "#bendecido"]))
	assert_eq(HelpCatalog.help_id_of(sign), &"hud_likes", "Q de Eco sobre el contador en la sala de inicio")
	assert_true(HelpCatalog.shared().has(&"hud_likes"))
	assert_eq(HelpCatalog.shared().world(&"hud_likes"), 3)
	assert_eq(HelpCatalog.help_id_of(_obj("marco_decorativo")), &"small_frame")


func test_hearts_light_the_first_like_platforms() -> void:
	_start()
	await _arrive()
	var first := _obj("likes_5") as LikePlatform
	var second := _obj("likes_10") as LikePlatform
	assert_false(first.is_solid(), "Sin likes, la ♥5 no esta")
	for col: int in range(22, 40):
		_teleport(col, 11)
		await wait_physics_frames(3)
	assert_eq(GameState.likes, 18, "Los 18 corazones se cogen andando")
	assert_true(first.is_solid(), "♥5 encendida")
	assert_true(second.is_solid(), "♥10 encendida")


func test_secret_a_room_behind_the_small_frame() -> void:
	_start()
	await _arrive()
	assert_false(GameState.has_memory(&"msg_3_2"))
	var frame := _obj("marco_decorativo") as SmallFrame
	assert_eq(frame.global_position, Vector2(58 * TILE, 11 * TILE), "Marco en la pared (58, 11)")
	assert_eq(frame.get_hole_rect().size, Vector2(TILE, TILE), "Hueco de 1 tile")
	# El paso comprimido por el marco lo comprueba el validador (requires_abilities): aqui, dentro de la salita.
	var before: int = GameState.attention_points
	var banks: int = GameState.get_power_banks_found()
	for col: int in [54, 55, 56]:
		_teleport(col, 11)
		await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_3_2"), "El mensaje de Mamá")
	assert_eq(GameState.attention_points, before + 1, "Y el punto del secreto")
	assert_eq(GameState.get_power_banks_found(), banks + 1, "Y el power bank")


## Paso 12 (2026-10-27, §4.1.1 y §9.8): el 3-1 rejugado con Pellizcar ya obtenido en el
## 3-2. Sin el gesto el marco pequeno (58, 11) cierra el paso; comprimido, Isak lo cruza
## andando desde la derecha y recoge en la salita msg_3_2, su punto y el power bank.
func test_secret_a_replayed_with_compress_through_the_small_frame() -> void:
	GameState.obtain_ability(GameState.ABILITY_COMPRESS)
	GameState.seen_notices[GameState.ABILITY_COMPRESS] = true
	GameState.unlock_level(&"3-2")
	GameState.mark_level_completed(&"3-1")
	GameState.mark_level_completed(&"3-2")
	_start()
	await _arrive()
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMPRESS), "Pellizcar, del 3-2")
	assert_false(GameState.has_memory(&"msg_3_2"))
	var frame_x: float = 58 * TILE
	# Sin comprimir: el marco no deja pasar.
	_teleport(60, 11)
	await wait_physics_frames(3)
	_isak.input.move_axis = -1.0
	await wait_physics_frames(90)
	_isak.input.move_axis = 0.0
	assert_gt(_isak.global_position.x, frame_x + TILE, "De pie no cabe por el marco de 1 tile")
	assert_false(GameState.has_memory(&"msg_3_2"))
	# Comprimido: pasa y recoge lo de la salita.
	var before: int = GameState.attention_points
	var banks: int = GameState.get_power_banks_found()
	assert_eq(_isak.compress_denial(), &"", "Pellizcar disponible en el 3-1")
	# Un toque de gesture_pinch: el flanco se borra en cuanto Isak lo usa (si siguiera puesto, el cuadro
	# siguiente pediria ya el tamano).
	var release := func(_compressed: bool) -> void: _isak.input.pinch_pressed = false
	_isak.compress_changed.connect(release)
	_isak.input.pinch_pressed = true
	await wait_physics_frames(15)
	_isak.compress_changed.disconnect(release)
	_isak.input.pinch_pressed = false
	assert_true(_isak.is_compressed(), "Pellizcar en el 3-1")
	_isak.input.move_axis = -1.0
	for i: int in 360:
		if _isak.global_position.x < 54 * TILE:
			break
		await wait_physics_frames(1)
	_isak.input.move_axis = 0.0
	assert_lt(_isak.global_position.x, frame_x, "Comprimido cruza el marco hasta la salita")
	await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_3_2"), "El mensaje de Mamá del capitulo del 3-2")
	assert_eq(GameState.attention_points, before + 1, "Y el punto del secreto")
	assert_eq(GameState.get_power_banks_found(), banks + 1, "Y el power bank")


func test_secret_b_needs_zero_likes() -> void:
	_start()
	await _arrive()
	GameState.set_likes(18)
	var inverse := _obj("inversa_1") as LikePlatform
	for i: int in 60:
		inverse.advance(1.0 / 60.0)
	assert_false(inverse.is_solid(), "Con likes, la inversa no esta")
	assert_eq((_obj("borrar_publicaciones") as LikeReset).clear_likes(), 18)
	assert_eq(GameState.likes, 0, "«Borrar publicaciones» pone el contador a 0")
	inverse.advance(0.1)
	assert_true(inverse.is_solid(), "Con 0 likes aparece")
	_teleport(140, 4)
	await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_3_1"), "El mensaje de Mamá en la vitrina")


func test_secret_c_extra_life_behind_the_glitch_wall() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_vida_extra") as GlitchWall
	var life := _obj("vida_extra_3_1") as ExtraLifePickup
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	assert_eq(life.get_wall(), wall, "La vida extra esta dentro de la pared con glitch")
	assert_false(life.is_shown(), "Oculta hasta abrir la pared")
	assert_eq(HubWorlds.level_extra_life_secrets(&"3-1"), [&"C"] as Array[StringName])


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 121.5 * TILE, TILE, "sync_1 en la Pausa")
	GameState.set_likes(12)
	sync_1.activate()
	_teleport(130, 11)
	await wait_physics_frames(3)
	GameState.set_likes(4)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")
	assert_eq(GameState.likes, 12, "Los likes vuelven al valor de sync_1")


func test_publish_terminal_completes_the_level_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_publicar") as ExitTerminal
	assert_not_null(terminal)
	assert_true(terminal.activate(_isak), "El pulso activa «Publicar»")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"3-1"), "3-1 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"3-2"), "Desbloquea la fila del 3-2")
	assert_eq(GameState.likes, 0, "Los likes no se guardan")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m3").get_folder_panel()
	assert_eq(panel.get_level_state(&"3-1"), HubWorlds.STATE_COMPLETED)
	# Paso 12 (2026-10-27): el 3-2 «Sin filtro» ya es jugable.
	assert_eq(panel.get_level_state(&"3-2"), HubWorlds.STATE_AVAILABLE, "El 3-2 disponible («Nueva foto»)")


func test_world_3_folder_lists_3_1_after_autoplay_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m3")
	assert_false(folder.is_locked(), "Mundo 3 abierto tras Autoplay")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m3"))
	assert_eq(levels.size(), 4, "3-1, 3-2, 3-3 y el jefe")
	assert_eq(panel.level_text(levels[0]), "3-1 Galería de perfil - Nuevo")
	# Pasos 12 y 13 (2026-10-27): el 3-2 y el 3-3 son jugables (bloqueados hasta completar el anterior); el jefe,
	# «Próximamente».
	assert_false(HubWorlds.is_coming_soon(levels[1]), "El 3-2 ya existe")
	assert_false(HubWorlds.is_coming_soon(levels[2]), "El 3-3 ya existe")
	assert_true(HubWorlds.is_coming_soon(levels[3]), "El jefe «Próximamente»")
	assert_eq(panel.level_text(levels[3]), "Jefe: La Curadora - Próximamente")
	for line: String in panel.get_lines():
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(line.contains(word), "«%s» no dice «%s»" % [line, word])
	panel.skip_input_delay()
	assert_true(panel.select_option(&"3-1"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 3-1")
