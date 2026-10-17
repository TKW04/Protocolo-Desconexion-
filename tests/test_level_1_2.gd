# Nivel 1-2 «Centro de notificaciones» con el flujo real (scenes/main.tscn,
# LevelRunner; paso 13 de docs/propuesta-1-2.md §10, 2026-10-16): carga y
# llegada por el vortice en el vestibulo, camara de torre y fachada con sus
# cuatro pestanas, puntos de sincronizacion en los pisos 2 y 4, acertijo y
# objetos de cada piso, economia (9 puntos, 2 cargadores, 1 power bank vacio,
# sin vida extra), puntos capturados una sola vez, vidas (rollback y papelera),
# terminal de la azotea -> hub con el 1-2 completado, y entrada desde la carpeta
# del Mundo 1. La ruta a pie la comprueba tools/validate_level.py
# (tests/test_level_1_2.py); aqui Isak se coloca en cada punto. El bot del 1-1
# no recorre el 1-2 (camara de torre: el bot vertical es el paso 15).
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_1_2.json"
const LEVEL_ID: String = "1-2"
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
	DebugMode.input_enabled = false
	# Se llega al 1-2 tras el 1-1: Eco, el pulso, el laser y Notas ya estan.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.obtained_abilities[GameState.ABILITY_LASER] = true
	GameState.seen_notices[GameState.ABILITY_LASER] = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")


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

func test_loads_with_arrival_at_the_bottom_tower_camera_and_facade() -> void:
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	var level: GeneratedLevel = _level()
	assert_eq(level.get_size_px(), Vector2i(28 * 64, 62 * 64), "Torre de 28 x 62")
	var vortex: WarpVortex = _main.get_arrival_vortex()
	assert_not_null(vortex, "Llega por el vortice")
	assert_gt(vortex.global_position.y, 56.0 * TILE, "El vortice esta en el vestibulo (abajo)")
	await _arrive()
	assert_eq(_isak.camera_mode, Isak.CAMERA_TOWER, "Camara de torre (el bot del 1-1 se niega a recorrerla)")
	assert_true(_isak.is_on_floor())
	assert_eq(roundi(_isak.global_position.y / TILE), 61, "De pie en el suelo del vestibulo")
	assert_gt(_isak.get_camera().global_position.y, 56.0 * TILE, "La camara empieza abajo")
	var background := level.get_node(^"Background") as World1Background
	assert_true(background.vertical)
	assert_not_null(background.get_layer("Fachada"), "Fachada de la torre")
	var labels: Array[String] = []
	for tab: Sprite2D in background.get_tabs():
		labels.append(String(tab.get_meta(&"label")))
	assert_eq(labels, ["Actualizaciones", "Recordatorios", "Correo", "Mensajes"] as Array[String],
		"Una pestana por piso")
	var mensajes: Sprite2D = background.get_tabs()[3]
	assert_almost_eq(mensajes.position.y, 44.0 * TILE + 72.0, 0.5, "La pestana de Mensajes en lo alto del piso 1 (por debajo del HUD)")


func test_objects_puzzles_and_economy_of_each_floor() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 9, "9 puntos de atencion")
	assert_eq(_count("Objects", Charger), 2, "2 cargadores")
	assert_eq(_count("Objects", PowerBankPickup), 1, "1 power bank (vacio, secreto C)")
	assert_eq(_count("Objects", ExtraLifePickup), 0, "Sin vida extra en el 1-2")
	# Piso 1: puntos rojos y pop-up translucido.
	assert_eq(_count("Enemies", NotificationBadge), 4)
	assert_true(_obj("overlay_1") is OverlayPopup)
	# Piso 2: banner, acertijo «Correo certificado» y chip del Debug.
	assert_eq(_count("Enemies", SpamBanner), 2, "Banners de los pisos 2 y 4")
	assert_true(_obj("lector_1") is LaserReceiver)
	assert_true(_obj("receptor_enlazado_1") is RelayReceiver)
	assert_true(_obj("puente_correo") is PulseBridge)
	assert_true(_obj("popup_buzon") is PopupBlocker)
	assert_true(_obj("anuncio_buzon") is AdCover)
	assert_eq((_obj("lector_1") as LaserReceiver).window_s, 6.0)
	assert_true(_obj("debug_1_2") is AbilityPickup, "El chip del Debug esta (aun no obtenido)")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG))
	assert_eq(_count("HiddenPlatforms", Node), 5, "Plataformas ocultas de 2c y del secreto A")
	# Piso 3: recordatorios y Posponer (los grupos del camino y el del secreto C).
	var snooze_1 := _obj("snooze_1") as SnoozeButton
	var snooze_2 := _obj("snooze_2") as SnoozeButton
	assert_true(snooze_1.links_group(&"posponer_3b"))
	assert_true(snooze_2.links_group(&"posponer_3c"))
	assert_true((_obj("snooze_olvidado") as SnoozeButton).links_group(&"olvidado"))
	assert_eq((_obj("posponer_3b_a") as ReminderPlatform).get_group_members().size(), 3)
	assert_eq((_obj("olvidado_a") as ReminderPlatform).get_group_members().size(), 5)
	# Posponer en la practica: sin cuenta, nada; contando, +4 s.
	assert_false(snooze_1.snooze(), "Sin cuenta: nada que posponer")
	var first := _obj("posponer_3b_a") as ReminderPlatform
	assert_true(first.trigger())
	var left: float = first.get_time_left()
	assert_true(snooze_1.snooze(), "Contando, el Posponer suma tiempo")
	assert_almost_eq(first.get_time_left(), left + 4.0, 0.01)
	# Piso 4: pop-up translucido, banner y barra del 99 %.
	assert_true(_obj("overlay_3") is OverlayPopup)
	assert_true(_obj("barra_99") is UpdateBar)
	assert_true((_obj("barra_99") as UpdateBar).is_solid(), "La barra cierra la subida a la azotea")
	assert_true(_obj("terminal_1_2") is ExitTerminal)
	assert_lt((_obj("terminal_1_2") as Node2D).global_position.y, 6.0 * TILE, "Terminal en la azotea")


func test_sync_points_at_floors_2_and_4_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	var sync_2 := _level().get_node(^"Checkpoints/sync_2") as Checkpoint
	assert_true(sync_1.global_position.y > 32.0 * TILE and sync_1.global_position.y < 44.0 * TILE, "sync_1 en el piso 2")
	assert_true(sync_2.global_position.y > 7.0 * TILE and sync_2.global_position.y < 18.0 * TILE, "sync_2 en el piso 4")
	sync_1.activate()
	_teleport(10, 42)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")
	sync_2.activate()
	_teleport(12, 16)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 1)
	assert_true(_isak.global_position.is_equal_approx(sync_2.get_spawn_position()), "Reaparece en sync_2")
	assert_false(_main.is_in_hub())
	# La ultima vida: game over (rollback a la copia) y papelera en el hub.
	_teleport(12, 16)
	await wait_physics_frames(3)
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_main.is_game_over_pending(), "Ultima vida: game over")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Eco lleva a Isak al hub")
	assert_eq(_main.get_game_over_count(), 1)
	assert_eq(GameState.lives, 3, "Tras el rollback las vidas se reponen")


func test_attention_points_are_captured_once_per_level() -> void:
	_start()
	await _arrive()
	var before: int = GameState.attention_points
	_teleport(12, 60)
	await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 1, "Punto del vestibulo capturado")
	assert_eq(GameState.get_captured_points(&"1-2").size(), 1, "Registrado en el 1-2")
	assert_true(GameState.get_captured_points(&"1-1").is_empty(), "No cuenta en el 1-1")
	# Reiniciar el mapa: el punto capturado no reaparece ni vuelve a contar.
	assert_true(_main.start_level(LEVEL_ID))
	_main.advance(LONG_STEP_S)
	await _arrive()
	var point: Node = _level().get_node_or_null(^"AttentionPoints/Point_12_60")
	assert_true(point == null or point.is_queued_for_deletion(), "El punto capturado no reaparece")
	_teleport(12, 60)
	await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 1, "Una sola vez por nivel")


func test_debug_chip_unlocks_and_fills_energy() -> void:
	_start()
	await _arrive()
	GameState.debug_energy = 10.0
	(_obj("popup_buzon") as PopupBlocker).close()
	_teleport(19, 33)
	await wait_physics_frames(4)
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DEBUG), "Debug obtenido en el piso 2")
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "El chip llena la energia")


func test_terminal_completes_the_level_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_1_2") as ExitTerminal
	assert_true(terminal.activate(_isak), "El pulso activa la terminal")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"1-2"), "1-2 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"1-3"), "Desbloquea el 1-3 (aun Proximamente)")
	assert_false(HubWorlds.can_enter(&"1-3"))
	var m1: Dictionary = HubWorlds.world(&"m1")
	assert_eq(HubWorlds.folder_state(m1), HubWorlds.STATE_AVAILABLE, "La carpeta no se completa sin el 1-3")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m1").get_folder_panel()
	assert_eq(panel.get_level_state(&"1-2"), HubWorlds.STATE_COMPLETED)


func test_hub_lists_1_2_after_1_1_and_the_folder_loads_it() -> void:
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
	assert_eq(panel.get_option_ids(), [&"1-1", &"1-2", &"1-3", FolderPanel.OPTION_BACK] as Array[StringName])
	assert_eq(panel.level_text(HubWorlds.levels(_m1())[1]), "1-2 Centro de notificaciones - Nuevo")
	assert_eq(panel.level_text(HubWorlds.levels(_m1())[2]), "1-3 No molestar - Próximamente")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"1-2"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "La carpeta carga el 1-2")
	assert_eq(_main.get_isak().camera_mode, Isak.CAMERA_TOWER)


func _m1() -> Dictionary:
	return HubWorlds.world(&"m1")
