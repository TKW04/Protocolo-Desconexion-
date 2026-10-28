# Nivel 4-1 «Chats recientes» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 11 de docs/propuesta-mundo-4.md §8, 2026-10-28): carga por el atajo de
# depuracion (--start-level=4-1) y llegada por el vortice al pie de la torre,
# objetos y economia (8 puntos, 2 cargadores, burbujas, cuatro «escribiendo…»,
# zona oscura, cinco zonas «Visto», el Troll, power bank, vida extra y msg_4_1),
# la Linterna que se recoge al pasar (aliada de registro) y enciende su luz en el
# Modo oscuro, Eco de tres puntos en el Mundo 4 (y la esfera en el hub), los tres
# secretos (A por la burbuja oculta, B tras el marco pequeno, C tras la pared con
# glitch), el punto de sincronizacion, la terminal «Enviar» -> hub con el 4-1
# completado y la carpeta del Mundo 4 tras instalar la actualizacion del hub.
# La ruta completa la comprueba tools/validate_level.py (tests/test_level_4_1.py);
# aqui Isak se coloca en cada punto. Usa su propia ruta de guardado (nunca
# user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_4_1.json"
const LEVEL_ID: String = "4-1"
const TILE: float = 64.0
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND
const UPGRADE: StringName = &"hub_update_4_6"
const W4_FRAMES: String = "res://assets/sprites/eco_companion_w4_frames.tres"

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
	# Se llega al 4-1 tras vencer a La Curadora e instalar la actualizacion del hub: todo el kit del Mundo 3.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
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
	for ability: StringName in [GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
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


func _fake_pulse(center: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


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

func test_debug_shortcut_loads_the_4_1_at_the_foot_of_the_tower() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=4-1"])), "4-1",
		"--start-level=4-1 es un atajo valido")
	_start()
	await _arrive()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_level().world, 4)
	assert_eq(_isak.camera_mode, Isak.CAMERA_TOWER, "Camara de torre del 1-2")
	assert_gt(_isak.global_position.y, 90.0 * TILE, "Llega al pie de la torre (fila 94)")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_SHOCKWAVE), "Sin Agitar en el 4-1")


func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/4-1.json"))
	var fixed: int = 0
	for o: Dictionary in data["objects"]:
		if String(o["type"]) == "chat_bubble":
			var node: Node = _obj(String(o["params"]["id"]))
			assert_true(node is ChatBubble and not node is TypingBubble, "Burbuja %s" % o["params"]["id"])
			fixed += 1
	assert_eq(fixed, 102, "Burbujas fijas (y la eliminada): las pasarelas de los pisos 1-4 y la azotea")
	assert_eq(_count("Objects", TypingBubble), 4, "Cuatro «escribiendo…»")
	assert_eq(_count("Objects", SeenZone), 6, "Seis zonas «Visto» en el Piso 4")
	assert_eq(_count("Objects", DarkZone), 1, "Modo oscuro del Piso 2")
	assert_eq(_count("Objects", Charger), 2, "Dos cargadores")
	assert_eq(_count("Objects", FlashlightPickup), 1, "La Linterna")
	assert_eq(_count("Enemies", Troll), 1, "El primer Troll")
	assert_not_null(_obj("power_bank_4_1"), "Power bank del secreto B")
	assert_not_null(_obj("mensaje_4_1"), "msg_4_1 del secreto A")
	assert_eq(_count("AttentionPoints", AttentionPoint), 8, "8 puntos de atencion")
	var deleted := _obj("b1_borrado") as ChatBubble
	assert_true(deleted.deleted, "La burbuja eliminada no tiene colision")
	assert_eq((_obj("b1_puente") as ChatBubble).get_width_tiles(), 7, "El puente largo")


func test_flashlight_is_met_on_the_way_and_lights_the_dark_floor() -> void:
	_start()
	await _arrive()
	var lamp := _obj("linterna_4_1") as FlashlightPickup
	assert_false(GameState.has_met_ally(GameState.ALLY_LINTERNA))
	var unsaved_before: bool = GameState.has_unsaved_changes()
	_teleport(7, 94)
	await wait_physics_frames(4)
	assert_true(lamp.is_taken(), "Se recoge al pasar")
	assert_true(GameState.has_met_ally(GameState.ALLY_LINTERNA), "Aliada de registro")
	assert_eq(GameState.has_unsaved_changes(), unsaved_before, "Conocerla no marca «sin guardar»")
	var light: FlashlightCompanion = _main.get_flashlight_companion()
	assert_not_null(light)
	_teleport(5, 59)
	await wait_physics_frames(4)
	var center: Vector2 = _isak.global_position + Vector2(0.0, -40.0)
	assert_eq(DarkZone.covering(get_tree(), center), _obj("modo_oscuro") as DarkZone, "Piso 2 a oscuras")
	assert_true(DarkZone.lit_by_flashlight(get_tree(), center), "La Linterna abre su circulo de luz")


func test_eco_is_three_dots_in_world_4() -> void:
	_start()
	await _arrive()
	var eco: EcoCompanion = _main.get_eco_companion()
	assert_not_null(eco)
	assert_eq(eco.get_sprite_frames().resource_path, W4_FRAMES, "Eco de tres puntos en el Mundo 4")
	for anim: StringName in [&"idle", &"talk", &"notice", &"appear", &"disappear", &"idle_amber", &"glow_in",
			&"glow_out"]:
		assert_true(eco.get_sprite_frames().has_animation(anim), "Animacion %s" % anim)


func test_typing_bubble_appears_one_second_after_its_trigger() -> void:
	_start()
	await _arrive()
	var t2 := _obj("t2") as TypingBubble
	assert_false(t2.is_triggered())
	_teleport(8, 59)  # sobre la burbuja de Tomi, que la dispara
	await wait_physics_frames(6)
	assert_true(t2.is_triggered(), "Pisar la burbuja de Tomi dispara t2")
	assert_false(t2.is_solid(), "Aun no existe")
	_main.advance(1.1)
	await wait_physics_frames(70)
	assert_true(t2.is_solid(), "Al segundo, la burbuja es solida")


func test_troll_is_stunned_by_the_pulse_from_the_path() -> void:
	_start()
	await _arrive()
	var troll := _level().get_node(^"Enemies/troll_1") as Troll
	assert_not_null(troll)
	_teleport(12, 47)
	await wait_physics_frames(3)
	assert_false(troll.sees_isak(), "Desde el forjado de la Pausa no esta en su linea")
	_teleport(20, 45)
	await wait_physics_frames(3)
	assert_true(troll.sees_isak(), "En el escalon, a su altura: lo ve")
	# Pulso desde el escalon (columna 20, mirando a la derecha; tools/validate_level.py lo pide desde ahi), con el
	# origen y el radio del pulso de Isak.
	var phone: Vector2 = _isak.global_position + Vector2(absf(_isak.pulse_effect_origin.x), _isak.pulse_effect_origin.y)
	assert_true(troll.receive_pulse(_fake_pulse(phone, _isak.abilities.pulse_radius_px)), "El pulso lo alcanza desde el escalon")
	assert_true(troll.is_stunned(), "Aturdido por el pulso")


func test_secret_a_old_message_behind_the_hidden_bubble() -> void:
	_start()
	await _arrive()
	var hidden: Node = _level().get_node(^"HiddenPlatforms")
	assert_gt(hidden.get_child_count(), 0, "Burbuja oculta del secreto A (solo con el Debug)")
	var pickup := _obj("mensaje_4_1") as MemoryPickup
	assert_false(GameState.has_memory(&"msg_4_1"))
	_teleport(21, 57)
	await wait_physics_frames(4)
	assert_true(pickup == null or not is_instance_valid(pickup) or GameState.has_memory(&"msg_4_1"),
		"Recoge el mensaje de Tomi")
	assert_true(GameState.has_memory(&"msg_4_1"), "Obtiene el mensaje de Tomi")


func test_secret_b_archived_room_behind_the_small_frame() -> void:
	_start()
	await _arrive()
	var frame := _obj("marco_archivado") as SmallFrame
	assert_not_null(frame, "Marco pequeno de «Archivado»")
	var bank := _obj("power_bank_4_1")
	assert_not_null(bank)
	assert_almost_eq((bank as Node2D).global_position.x, 2.5 * TILE, TILE, "Power bank dentro de la sala")


func test_secret_c_extra_life_behind_the_glitch_wall() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_vida_extra") as GlitchWall
	var life := _obj("vida_extra_4_1") as ExtraLifePickup
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	assert_eq(life.get_wall(), wall, "La vida extra esta dentro de la pared con glitch")
	assert_false(life.is_shown(), "Oculta hasta abrir la pared")
	assert_eq(HubWorlds.level_extra_life_secrets(&"4-1"), [&"C"] as Array[StringName])


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 12.5 * TILE, TILE, "sync_1 en la Pausa")
	sync_1.activate()
	_teleport(5, 38)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")


func test_send_terminal_completes_the_level_and_returns_to_the_hub() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_enviar") as ExitTerminal
	assert_not_null(terminal)
	assert_true(terminal.activate(_isak), "El pulso activa «Enviar»")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"4-1"), "4-1 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"4-2"), "Desbloquea la fila del 4-2")
	var panel: FolderPanel = _main.get_hub().get_folder(&"m4").get_folder_panel()
	assert_eq(panel.get_level_state(&"4-1"), HubWorlds.STATE_COMPLETED)
	assert_false(HubWorlds.is_coming_soon(HubWorlds.levels(HubWorlds.world(&"m4"))[1]), "El 4-2, jugable (paso 13)")
	assert_eq(panel.get_level_state(&"4-2"), HubWorlds.STATE_AVAILABLE, "El 4-2, disponible")
	# La esfera vuelve en el hub (atenuada): el cuerpo de tres puntos es solo de los niveles del Mundo 4.
	var hub_eco: EcoCompanion = _main.get_hub().get_eco_companion()
	if hub_eco != null:
		assert_ne(hub_eco.get_sprite_frames().resource_path, W4_FRAMES, "En el hub, la esfera")


func test_world_4_folder_lists_4_1_after_the_update_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m4")
	assert_not_null(folder, "Carpeta M4 en la pagina 2")
	assert_false(folder.is_locked(), "Mundo 4 abierto tras La Curadora y la actualizacion")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m4"))
	assert_eq(levels.size(), 4, "4-1, 4-2, 4-3 y el jefe")
	assert_eq(panel.level_text(levels[0]), "4-1 Chats recientes - Nuevo")
	assert_false(HubWorlds.is_coming_soon(levels[1]), "El 4-2 existe desde el paso 13 (bloqueado hasta el 4-1)")
	assert_true(HubWorlds.is_coming_soon(levels[2]), "El 4-3 aun no existe")
	assert_true(HubWorlds.is_coming_soon(levels[3]), "El jefe aun no existe")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"4-1"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 4-1")
