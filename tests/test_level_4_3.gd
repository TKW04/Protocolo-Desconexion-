# Nivel 4-3 «Mensajes sin leer» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 14 de docs/propuesta-mundo-4.md §8, 2026-10-28): carga por el atajo de
# depuracion (--start-level=4-3) con Agitar ya obtenido, objetos y economia
# (9 puntos, 3 cargadores, la ola, zonas «Visto», «escribiendo…», Fantasmas,
# Trolls disfrazados de Marco, Modo oscuro, power bank y msg_4_3), la ola que
# espera hasta la columna 20 y se mueve despues, los disfrazados que el Debug
# delata, los secretos (A tras la pared con glitch del nicho alto, B en tinta,
# C la burbuja dentro de una zona «Visto»), los puntos de sincronizacion y el
# cierre segun V15: la puerta «Responder más tarde» muestra «Sin conexión» e
# Isak sale sin responder al hub con el 4-3 completado y la fila del jefe
# desbloqueada. La ruta completa la comprueban tools/validate_level.py
# (tests/test_level_4_3.py) y el bot del chat (tests/test_chat_bot.gd). Usa su
# propia ruta de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_4_3.json"
const LEVEL_ID: String = "4-3"
const TILE: float = 64.0
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND
const SHAKE: StringName = GameState.ABILITY_SHOCKWAVE
const UPGRADE: StringName = &"hub_update_4_6"

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
	# Se llega al 4-3 tras el 4-2: todo el kit del Mundo 3, la Linterna y Agitar.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS,
			SHAKE]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1", &"4-2"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"4-3")
	GameState.install_hub_upgrade(UPGRADE)


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
	for ability: StringName in [GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS, SHAKE]:
		GameState.set_ability_unlocked(ability, false)
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


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


func _count(parent: String, cls: Variant) -> int:
	var n: int = 0
	var node: Node = _level().get_node_or_null(NodePath(parent))
	if node == null:
		return 0
	for child: Node in node.get_children():
		if is_instance_of(child, cls):
			n += 1
	return n


## Agitar desde la celda (col, fila) mirando a `facing`, con el centro y el radio de la onda del Isak real.
func _shake_from(col: int, row: int, facing: int) -> void:
	_teleport(col, row)
	_isak.facing = facing
	ShockwaveWave.apply_to_enemies(get_tree(), _isak.get_shockwave_center(), _isak.abilities.shockwave_radius_px,
		_isak.abilities.shockwave_stun_s)


# --- Pruebas ---

func test_debug_shortcut_loads_the_4_3_with_shockwave() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=4-3"])), "4-3")
	_start()
	await _arrive()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().world, 4)
	assert_ne(_isak.camera_mode, Isak.CAMERA_TOWER, "Nivel horizontal")
	assert_almost_eq(_isak.global_position.x, 3.5 * TILE, TILE, "Llega por el vortice de (3, 11)")
	assert_true(GameState.is_ability_unlocked(SHAKE), "Con Agitar (del 4-2)")
	assert_true((_obj("linterna_4_3") as FlashlightPickup).is_taken(), "La Linterna ya es de Isak")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("Objects", SeenWave), 1, "La ola de «Visto»")
	assert_eq(_count("Objects", TypingBubble), 6)
	assert_eq(_count("Objects", SeenZone), 8)
	assert_eq(_count("Objects", DarkZone), 1, "Modo oscuro de la segunda mitad del Tramo 3")
	assert_eq(_count("Objects", Charger), 3)
	assert_eq(_count("Enemies", TrollMimic), 3, "Tres burbujas «de Marco» que son Trolls")
	assert_eq(_count("Enemies", Ghost), 6)
	assert_eq(_count("AttentionPoints", AttentionPoint), 9, "9 puntos de atencion")
	assert_not_null(_obj("power_bank_4_3"), "Power bank del secreto B")
	assert_not_null(_obj("mensaje_4_3"), "msg_4_3 del secreto A")


func test_wave_waits_for_column_20_then_moves() -> void:
	_start()
	await _arrive()
	var wave := _obj("ola_leido") as SeenWave
	assert_eq(wave.get_state(), SeenWave.State.WAITING, "Parada hasta que Isak cruza la columna 20")
	var front: float = wave.get_front_x()
	_teleport(24, 11)
	await wait_physics_frames(2)
	wave.advance(2.0)
	assert_eq(wave.get_state(), SeenWave.State.MOVING, "Al cruzarla, avanza")
	assert_almost_eq(wave.get_front_x() - front, 2.0 * TILE, 8.0, "A 1,0 tiles/s en el Tramo 1")


func test_mimics_look_like_marco_until_the_debug_reveals_them() -> void:
	_start()
	await _arrive()
	var mimic := _enemy("marco_falso_1") as TrollMimic
	assert_true(mimic.is_disguised(), "Parece una burbuja de Marco")
	assert_false(mimic.is_revealed_by_debug())
	GameState.debug_energy = GameState.get_debug_energy_max()
	var config: DebugModeConfig = DebugModeConfig.shared()
	var dt: float = 1.0 / 60.0
	for i: int in roundi(config.activation_hold_s / dt):
		DebugMode.step(dt, true)
	for i: int in ceili(config.fade_in_s / dt) + 1:
		DebugMode.step(dt, false)
	assert_true(DebugMode.is_active())
	assert_true(mimic.is_revealed_by_debug(), "Con el Debug, avatar anonimo y costuras rojas")


func test_secret_a_conversation_behind_the_glitch_wall() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_conversacion") as GlitchWall
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	assert_gt(_level().get_node(^"HiddenPlatforms").get_child_count(), 0, "Escalera oculta (solo con el Debug)")
	assert_false(GameState.has_memory(&"msg_4_3"))
	_teleport(112, 3)
	await wait_physics_frames(4)
	assert_true(GameState.has_memory(&"msg_4_3"), "Obtiene la conversacion de Lia")


func test_secret_b_draft_in_ink_and_secret_c_in_an_air_zone() -> void:
	_start()
	await _arrive()
	assert_not_null(_obj("borrador_paso") as InkOnly, "Paso en tinta del borrador")
	var bank := _obj("power_bank_4_3") as Node2D
	assert_almost_eq(bank.global_position.x, 266.5 * TILE, TILE, "Power bank en la repisa del borrador")
	var zone := _obj("visto_alto") as SeenZone
	assert_not_null(zone)
	assert_true((_obj("tres_meses_alta") as ChatBubble) != null, "La burbuja alta del secreto C")


func test_sync_points() -> void:
	_start()
	await _arrive()
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	var sync_2 := _level().get_node(^"Checkpoints/sync_2") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 104.5 * TILE, TILE)
	assert_almost_eq(sync_2.global_position.x, 203.5 * TILE, TILE)


func test_reply_later_shows_no_connection_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_responder") as ExitTerminal
	assert_not_null(terminal)
	assert_eq(terminal.get_frames_path(), "res://assets/sprites/chat_reply_terminal_frames.tres", "Aspecto chat_reply")
	watch_signals(terminal)
	assert_true(terminal.activate(_isak), "El pulso activa «Responder más tarde»")
	assert_signal_emitted_with_parameters(terminal, "offline_shown", ["Sin conexión"])
	assert_eq(terminal.get_state(), ExitTerminal.State.OFFLINE, "Primero, «Sin conexión»")
	assert_true(terminal.is_offline_shown())
	assert_eq(terminal.get_animation(), ExitTerminal.ANIM_PROMPT, "El campo de respuesta con el cursor")
	terminal.advance(1.0)
	assert_eq(terminal.get_state(), ExitTerminal.State.OFFLINE, "Dura offline_s (1,6 s)")
	terminal.advance(0.7)
	assert_ne(terminal.get_state(), ExitTerminal.State.OFFLINE, "Despues, el encendido: Isak sale sin responder")
	assert_false(terminal.is_offline_shown())
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"4-3"), "4-3 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"4-boss"), "Desbloquea la fila del jefe")
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m4"))
	assert_false(HubWorlds.is_coming_soon(levels[3]), "El Visto, jugable (paso 18)")


func test_world_4_folder_loads_the_4_3() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m4")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	assert_eq(panel.get_level_state(&"4-3"), HubWorlds.STATE_AVAILABLE, "Disponible tras el 4-2")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"4-3"))
	panel.confirm()
	if panel.is_confirming_unsaved():
		assert_true(panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED))
		panel.confirm()
	var departure: WarpVortex = hub.get_departure_vortex()
	assert_not_null(departure)
	departure.advance(LONG_STEP_S)
	await wait_process_frames(2)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_false(_main.is_in_hub())
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 4-3")
