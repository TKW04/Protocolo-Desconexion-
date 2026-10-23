# Nivel 2-2 «Un video más» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 13 de docs/propuesta-mundo-2.md §8, 2026-10-23): carga por el atajo de
# depuracion (--start-level=2-2) con llegada por el vortice en la sala de inicio
# y el scroll forzado parado, el reproductor que da el golpe al suelo (una vez:
# Eco dice «Mira cuánto tiempo ahorramos juntos.»), la puerta de pie de la sala,
# objetos y economia (9 puntos, 3 cargadores, power bank, mensaje de Mamá),
# secreto «Bajo el nivel», punto de sincronizacion, cierre con la cuenta
# automatica -> hub con el 2-2 completado y el 2-3 desbloqueado, y la carpeta del
# Mundo 2: el 2-2 «Siguiente video» tras el 2-1 y se entra en el. La ruta completa
# la comprueban tools/validate_level.py (tests/test_level_2_2.py) y el bot del
# feed (tests/test_feed_bot.gd); aqui Isak se coloca en cada punto. Usa su propia
# ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_2_2.json"
const LEVEL_ID: String = "2-2"
const TILE: float = 64.0
const ROWS: int = 156
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND

var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool
var _main: LevelRunner
var _isak: Isak
var _lines: Array[String] = []


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
	# Se llega al 2-2 tras el 2-1: todo el kit del Mundo 1, sin el golpe al suelo (lo da el reproductor).
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"2-2")
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)


func after_each() -> void:
	if EventBus.eco_line_requested.is_connected(_on_line):
		EventBus.eco_line_requested.disconnect(_on_line)
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


func _on_line(text: String, _duration: float, _important: bool) -> void:
	_lines.append(text)


# --- Utilidades ---

## Fila del grid de la altura h (h 0 = suelo de la sala de inicio).
func _row(h: int) -> int:
	return 149 - h


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

func test_debug_shortcut_loads_the_2_2_parked_in_the_player_room() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=2-2"])), "2-2",
		"Atajo de depuracion -- --start-level=2-2")
	_start()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().get_size_px(), Vector2i(20 * 64, ROWS * 64), "Feed de 20 x 156")
	assert_eq(_level().world, 2, "Mundo 2")
	await _arrive()
	assert_true(_isak.is_on_floor())
	assert_eq(roundi(_isak.global_position.y / TILE), _row(1) + 1, "De pie sobre el suelo de la sala de inicio")
	var camera: ScrollCamera = _isak.get_scroll_camera()
	assert_not_null(camera, "Camara de scroll forzado")
	assert_true(camera.is_parked(), "Parado en la sala de inicio hasta subir")
	assert_false(GameState.is_ability_obtained(POUND), "Empieza sin el golpe al suelo")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("AttentionPoints", AttentionPoint), 9, "9 puntos de atencion (6 + 3)")
	assert_eq(_count("Objects", Charger), 3, "3 cargadores")
	assert_eq(_count("Objects", PowerBankPickup), 1, "Un power bank (vacio)")
	assert_eq(_count("Objects", ExtraLifePickup), 0, "Sin vida extra")
	assert_eq(_count("Objects", MemoryPickup), 1, "El mensaje de Mamá (secreto A)")
	assert_eq(_count("Objects", PausePlayer), 1, "El reproductor")
	assert_eq(_count("Objects", FragileCard), 7, "Fragiles: puertas de pie, suelos y la salida oculta (y su copia)")
	assert_eq(_count("Objects", StoryCard), 2, "Dos Historias en el enjambre")
	assert_eq(_count("Objects", CloneZone), 3, "Dos salas del enjambre y la repisa del secreto B")
	assert_eq(_count("Objects", LoopSection), 1, "Un bucle")
	assert_eq(_count("Enemies", AutoplayVideo), 7, "Ola del Tramo 1, dos rayos del bucle y dos parejas")
	assert_eq(_count("Enemies", Commenter), 1, "Un Comentarista en el bucle")
	var hidden := _obj("salida_oculta") as FragileCard
	assert_true(hidden.hidden_card, "La salida del bucle es una fragil oculta")


func test_player_gives_the_ground_pound_once_and_the_door_breaks_with_the_wave() -> void:
	_start()
	await _arrive()
	var player := _obj("reproductor_2_2") as PausePlayer
	assert_not_null(player)
	assert_false(player.is_on())
	assert_true(player.switch_on(), "El pulso de espaldas al boton lo pausa (lo prueba test_pause_player)")
	assert_true(GameState.is_ability_obtained(POUND), "Obtiene el golpe al suelo")
	assert_true(_lines.has("Mira cuánto tiempo ahorramos juntos."), "La linea de Eco del mundo")
	assert_false(player.switch_on(), "Un solo uso")
	var door := _obj("puerta_reproductor") as FragileCard
	assert_eq(door.variant, FragileCard.VARIANT_UPRIGHT, "Fragil de pie: cierra la sala")
	assert_true(door.is_solid())
	# La onda de un golpe al suelo junto a ella la rompe.
	var feet := Vector2((11 + 0.5) * TILE, (_row(1) + 1) * TILE)
	EventBus.ground_pound_landed.emit(Rect2(feet.x - 96.0, feet.y - 64.0, 192.0, 72.0), _isak)
	assert_false(door.is_solid(), "La onda la rompe")


func test_secret_under_the_level_gives_the_message_and_two_points() -> void:
	_start()
	await _arrive()
	assert_false(GameState.has_memory(&"msg_2_2"))
	var crack := _obj("grieta_bajo_el_nivel") as FragileCard
	assert_eq(crack.trigger_mode, &"pound_only", "Solo la rompe el golpe")
	var before: int = GameState.attention_points
	# Bajo el nivel (con el scroll aun parado en la sala de inicio): Isak se coloca en el secreto.
	_teleport(13, _row(-5))
	await wait_physics_frames(6)
	assert_true(GameState.has_memory(&"msg_2_2"), "Obtiene el mensaje de Mamá")
	_teleport(14, _row(-5))
	await wait_physics_frames(6)
	_teleport(18, _row(-5))
	await wait_physics_frames(6)
	assert_eq(GameState.attention_points, before + 2, "Y los dos puntos del secreto")
	assert_true(_isak.get_scroll_camera().is_parked(), "Bajo el nivel, la vista sigue parada (sin tocar el borde)")


func test_closing_card_counts_down_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_siguiente_video") as ExitTerminal
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
	assert_true(GameState.is_level_completed(&"2-2"), "2-2 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"2-3"), "Desbloquea la fila del 2-3")


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
	assert_eq(panel.get_level_state(&"2-2"), HubWorlds.STATE_AVAILABLE, "El 2-2, tras el 2-1")
	assert_eq(panel.level_text(levels[1]), "2-2 Un video más - Siguiente video", "§4.6: «Siguiente video»")
	assert_eq(panel.level_text(levels[2]), "2-3 Scroll infinito - Próximamente")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"2-2"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 2-2")
