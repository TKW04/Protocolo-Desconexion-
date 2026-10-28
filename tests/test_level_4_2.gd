# Nivel 4-2 «Grupo sin respuesta» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 13 de docs/propuesta-mundo-4.md §8, 2026-10-28): carga por el atajo de
# depuracion (--start-level=4-2) y llegada por el vortice de la sala «Mensajes
# borrados», objetos y economia (10 puntos, 3 cargadores, Trolls, Fantasmas,
# Stickers, zonas «Visto», autocorrectores, «escribiendo…», power bank y
# msg_4_2), la Linterna del 4-1 que no vuelve a salir, la Papelera que habla al
# llegar, el «¿Deshacer escritura?» que da Agitar y el muro de texto que solo cae
# con Agitar, un grupo de Trolls y una tanda de Stickers que caen con un Agitar
# desde el sitio del camino, los secretos (A tras el marco pequeno a oscuras, B
# con el autocorrector que crece, C la burbuja alta), el punto de sincronizacion,
# la terminal «Salir del chat» -> hub con el 4-2 completado y el 4-2 jugable
# desde la carpeta del Mundo 4. La ruta completa la comprueba
# tools/validate_level.py (tests/test_level_4_2.py) y el bot del chat
# (tests/test_chat_bot.gd); aqui Isak se coloca en cada punto. Usa su propia ruta
# de guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_4_2.json"
const LEVEL_ID: String = "4-2"
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
	# Se llega al 4-2 tras el 4-1: todo el kit del Mundo 3 y la Linterna; sin Agitar.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"4-2")
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

func test_debug_shortcut_loads_the_4_2_in_the_deleted_messages_room() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=4-2"])), "4-2")
	_start()
	await _arrive()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().world, 4)
	assert_ne(_isak.camera_mode, Isak.CAMERA_TOWER, "Nivel horizontal")
	assert_almost_eq(_isak.global_position.x, 3.5 * TILE, TILE, "Llega por el vortice de (3, 11)")
	assert_false(GameState.is_ability_unlocked(SHAKE), "Empieza sin Agitar")
	var lamp := _obj("linterna_4_2") as FlashlightPickup
	assert_true(lamp.is_taken(), "La Linterna del 4-1 ya es de Isak: no vuelve a salir")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_count("Objects", TypingBubble), 4, "«escribiendo…» de los tramos 1, 3 y del secreto C")
	assert_eq(_count("Objects", AutocorrectBubble), 2, "El autocorrector del Tramo 3 y el del secreto B")
	assert_eq(_count("Objects", SeenZone), 6, "Seis zonas «Visto» en el Tramo 3")
	assert_eq(_count("Objects", DarkZone), 1, "La sala a oscuras del secreto A")
	assert_eq(_count("Objects", Charger), 3, "Tres cargadores")
	assert_eq(_count("Objects", UndoPrompt), 1)
	assert_eq(_count("Objects", TypedWall), 1)
	assert_eq(_count("Objects", PapeleraActor), 1)
	assert_eq(_count("Enemies", Troll), 9, "Siete en los grupos del Tramo 1, el de la zona y el de los Stickers")
	assert_eq(_count("Enemies", Ghost), 6)
	assert_eq(_count("Enemies", Sticker), 12)
	assert_eq(_count("AttentionPoints", AttentionPoint), 10, "10 puntos de atencion")
	assert_not_null(_obj("power_bank_4_2"), "Power bank del secreto B")
	assert_not_null(_obj("mensaje_4_2"), "msg_4_2 del secreto A")


func test_papelera_speaks_and_the_prompt_gives_shockwave_for_the_typed_wall() -> void:
	_start()
	await _arrive()
	var papelera := _obj("papelera_4_2") as PapeleraActor
	papelera.advance(0.1)
	assert_ne(papelera.get_state(), PapeleraActor.State.WAITING, "Habla al llegar Isak (a 2 tiles)")
	assert_true(GameState.is_notice_seen(&"papelera_4_2"))
	var wall := _obj("muro_4_2") as TypedWall
	assert_true(wall.is_solid())
	var prompt := _obj("deshacer_4_2") as UndoPrompt
	assert_true(prompt.switch_on(), "El «¿Deshacer escritura?» se usa")
	assert_true(GameState.is_ability_obtained(SHAKE), "Agitar obtenido")
	assert_eq(papelera.get_state(), PapeleraActor.State.DONE, "La Papelera dice su ultima linea")
	# Agitar desde la celda 19 del camino (mirando al muro) lo deshace.
	_teleport(19, 11)
	_isak.facing = 1
	EventBus.shockwave_fired.emit(_isak.get_shockwave_center(), _isak.abilities.shockwave_radius_px, _isak)
	assert_true(wall.is_erasing(), "La onda alcanza el muro")
	wall.advance(0.41)
	assert_false(wall.is_solid(), "Deshecho para siempre")


func test_troll_group_falls_to_one_shake_from_the_path() -> void:
	_start()
	await _arrive()
	var a := _enemy("troll_grupo_1a") as Troll
	var b := _enemy("troll_grupo_1b") as Troll
	_teleport(35, 11)
	await wait_physics_frames(2)
	assert_false(a.sees_isak() or b.sees_isak(), "A 5 tiles el grupo aun no lo ve (detect_tiles 3)")
	_teleport(37, 11)
	await wait_physics_frames(2)
	assert_true(a.sees_isak() and b.sees_isak(), "A 3 tiles empieza a escribir: el Agitar sale antes del mensaje")
	_shake_from(37, 11, 1)
	assert_true(a.is_stunned() and b.is_stunned(), "Un Agitar desde la celda 37 aturde a los dos")
	var g3 := ["troll_grupo_3a", "troll_grupo_3b", "troll_grupo_3c"]
	_shake_from(59, 5, 1)
	for id: String in g3:
		assert_true((_enemy(id) as Troll).is_stunned(), "%s aturdido por el mismo Agitar" % id)


func test_sticker_swarm_falls_to_one_shake_where_isak_lands() -> void:
	_start()
	await _arrive()
	_shake_from(239, 8, 1)
	for i: int in 4:
		var sticker := _enemy("sticker_b2_%d" % i) as Sticker
		assert_true(sticker == null or not is_instance_valid(sticker) or sticker.is_defeated(),
			"sticker_b2_%d desinflado por el Agitar de la llegada" % i)


func test_secret_a_muted_room_in_the_dark() -> void:
	_start()
	await _arrive()
	assert_not_null(_obj("marco_silenciado") as SmallFrame, "Marco pequeno bajo «Garaje · Silenciado»")
	assert_true((_obj("garaje_silenciado") as ChatBubble).deleted, "Parece decorado (sin colision)")
	var dark := _obj("silenciado_oscuro") as DarkZone
	assert_not_null(dark)
	assert_not_null(_obj("tinta_puente_1"), "Puente en tinta sobre los pinchos")
	_teleport(86, 9)
	await wait_physics_frames(3)
	assert_eq(DarkZone.covering(get_tree(), _isak.global_position + Vector2(0.0, -40.0)), dark, "Sala a oscuras")
	assert_false(GameState.has_memory(&"msg_4_2"))
	_teleport(82, 11)
	await wait_physics_frames(4)
	assert_true(GameState.has_memory(&"msg_4_2"), "Obtiene el mensaje de Marco")


func test_secret_b_ok_grows_into_a_bridge() -> void:
	_start()
	await _arrive()
	var ok := _obj("ok_y_tu") as AutocorrectBubble
	assert_eq(ok.get_width_tiles(), 1, "«ok», de 1 tile")
	_teleport(139, 11)
	for i: int in 90:
		ok.advance(1.0 / 60.0)
	assert_true(ok.is_corrected(), "Al acercarse, se corrige")
	assert_eq(ok.get_width_tiles(), 5, "«ok, ¿y tú qué tal? cuéntame»: un puente de 5")
	var bank := _obj("power_bank_4_2") as Node2D
	assert_almost_eq(bank.global_position.x, 147.5 * TILE, TILE, "El power bank, en la repisa del final")


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3)
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 133.5 * TILE, TILE, "sync_1 en la Pausa")
	sync_1.activate()
	_teleport(150, 11)
	await wait_physics_frames(3)
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead())
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")


func test_exit_terminal_completes_the_level_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_salir") as ExitTerminal
	assert_not_null(terminal)
	assert_true(terminal.activate(_isak), "El pulso activa «Salir del chat»")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"4-2"), "4-2 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"4-3"), "Desbloquea la fila del 4-3")
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m4"))
	assert_false(HubWorlds.is_coming_soon(levels[2]), "El 4-3, jugable (paso 14)")


func test_world_4_folder_loads_the_4_2() -> void:
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
	assert_eq(panel.get_level_state(&"4-2"), HubWorlds.STATE_AVAILABLE, "Disponible tras el 4-1")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"4-2"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 4-2")
