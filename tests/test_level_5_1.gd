# Nivel 5-1 «Oferta del día» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 10 de docs/propuesta-mundo-5.md §8, 2026-10-29): carga por el atajo de
# depuracion (--start-level=5-1) y llegada por el vortice, objetos y economia
# (8 puntos, la caja de 2, tienda de Sync y energia, cuatro cajas, seis Ofertas,
# la Suscripcion suelta, el atajo con trampa, la cuenta regresiva, 2 cargadores,
# power bank, vida extra y msg_5_1), Eco con la esfera de siempre, los secretos
# (A tras la pared con glitch con Devoluciones, C con la vida extra), el punto de
# sincronizacion, la puerta «Pagar» -> hub con el 5-1 completado, el comentario de
# Calc con lo gastado y la carpeta del Mundo 5 tras vencer a El Visto.
# La ruta completa la comprueba tools/validate_level.py (tests/test_level_5_1.py);
# aqui Isak se coloca en cada punto. Usa su propia ruta de guardado (nunca
# user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_5_1.json"
const LEVEL_ID: String = "5-1"
const TILE: float = 64.0
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND
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
	# Se llega al 5-1 tras vencer a El Visto: todo el kit del Mundo 4 (sin la Combinacion).
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1", &"4-2", &"4-3", &"4-boss"]:
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


func _complete() -> void:
	var terminal := _obj("terminal_pagar") as ExitTerminal
	assert_true(terminal.activate(_isak), "El pulso activa «Pagar»")
	for i: int in 4:
		terminal.advance(LONG_STEP_S)
	if terminal.get_vortex() != null:
		terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


# --- Pruebas ---

func test_objects_enemies_and_economy() -> void:
	_start()
	await _arrive()
	assert_eq(_main.get_level_id(), LEVEL_ID)
	assert_eq(_count("Objects", ShopItem), 2, "Tienda: Sync y energia")
	assert_eq(_count("Objects", SurpriseBox), 4, "Cuatro cajas sorpresa (patron 24)")
	assert_eq(_count("Objects", ShortcutDoor), 1, "El primer atajo con trampa")
	assert_eq(_count("Objects", RefundDesk), 1, "Devoluciones (secreto A)")
	assert_eq(_count("Objects", CountdownPlatform), 1, "La primera cuenta regresiva")
	assert_eq(_count("Objects", Charger), 2, "Dos cargadores")
	assert_eq(_count("Enemies", OfferSign), 6, "Seis Ofertas")
	assert_eq(_count("Enemies", Subscription), 1, "La primera Suscripcion suelta")
	assert_eq(_count("AttentionPoints", AttentionPoint), 8, "8 puntos de atencion en la rejilla")
	assert_eq(HubWorlds.level_points_total("5-1"), 9, "8 de la rejilla + la caja de puntos (un punto del nivel)")
	var door := _obj("atajo_dos_plantas") as ShortcutDoor
	assert_eq(door.get_cost(), 3, "Atajo: 3")
	assert_true(door.has_trap(), "Esconde una trampa (una Suscripcion)")
	assert_not_null(_obj("power_bank_5_1"), "Power bank del secreto B")
	assert_not_null(_obj("mensaje_5_1"), "msg_5_1 del secreto A")
	assert_not_null(_obj("vida_extra_5_1"), "Vida extra del secreto C")


func test_eco_is_the_usual_sphere_in_world_5() -> void:
	_start()
	await _arrive()
	var eco: EcoCompanion = _main.get_eco_companion()
	assert_not_null(eco, "Eco acompaña a Isak")
	assert_eq(eco.get_sprite_frames().resource_path, String(EcoCompanion.load_data()["frames"]),
		"La esfera de siempre (Eco igual en todos los mundos, decision del usuario 2026-10-29)")


func test_shop_can_be_paid_with_the_points_of_the_level() -> void:
	_start()
	await _arrive()
	GameState.attention_points = 0
	var shop := _obj("tienda_energia") as ShopItem
	assert_false(GameState.can_afford(2), "Con 0 no se paga (sin deuda)")
	GameState.add_attention_points(6)
	assert_true(GameState.spend_attention(2, &"shop", &"5-1"), "Con los puntos del nivel, si")
	assert_eq(GameState.attention_points, 4)
	assert_eq(GameState.get_attempt_spent(&"5-1"), 2, "Gastado en el intento")
	assert_not_null(shop)


func test_secret_a_refund_room_behind_the_glitch_wall() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_devoluciones") as GlitchWall
	assert_not_null(wall)
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	var desk := _obj("devoluciones_5_1") as RefundDesk
	assert_true(desk.global_position.x < wall.global_position.x, "Devoluciones, detras de la pared")
	var memory := _obj("mensaje_5_1") as MemoryPickup
	assert_eq(memory.memory_id, &"msg_5_1")


func test_secret_c_extra_life() -> void:
	_start()
	await _arrive()
	assert_eq(HubWorlds.level_extra_life_secrets(&"5-1"), [&"C"] as Array[StringName])
	var life := _obj("vida_extra_5_1") as ExtraLifePickup
	assert_true(life.is_shown(), "A la vista en su repisa (sin pared con glitch)")
	assert_eq(GameState.lives_max, 3)
	_teleport(257, 7)
	await wait_physics_frames(10)
	assert_eq(GameState.lives_max, 4, "Recogerla sube el maximo de vidas")


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 138.5 * TILE, TILE, "sync_1 en la Pausa")
	sync_1.activate()
	_teleport(160, 11)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")


func test_checkout_door_completes_the_level_and_calc_counts_the_spending() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_pagar") as ExitTerminal
	assert_eq(terminal.get_frames_path(), "res://assets/sprites/checkout_terminal_frames.tres", "Aspecto checkout")
	assert_eq(terminal.offline_text, "Total: 0. Gracias por mirar.")
	GameState.add_attention_points(5)
	assert_true(GameState.spend_attention(3, &"shortcut", &"5-1"))
	_teleport(254, 11)
	await wait_physics_frames(3)
	_complete()
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"5-1"), "5-1 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"5-2"), "Desbloquea la fila del 5-2")
	var hub: HubRoom = _main.get_hub()
	var remark: Dictionary = {}
	for entry: Variant in (HubData.section("calc") as Dictionary).get("remarks", []):
		if String((entry as Dictionary).get("after_level", "")) == "5-1":
			remark = entry
	assert_false(remark.is_empty(), "Comentario de Calc tras el 5-1")
	assert_string_contains(hub.calc_remark_text(remark), "Has gastado 3 ")
	assert_false(HubWorlds.is_coming_soon(HubWorlds.levels(HubWorlds.world(&"m5"))[1]), "El 5-2, jugable (paso 13)")
	assert_false(HubWorlds.is_coming_soon(HubWorlds.levels(HubWorlds.world(&"m5"))[2]), "El 5-3, jugable (paso 14)")
	assert_true(HubWorlds.is_coming_soon(HubWorlds.levels(HubWorlds.world(&"m5"))[3]), "El Vendedor, «Próximamente»")


func test_calc_remark_without_spending() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	var hub: HubRoom = _main.get_hub()
	GameState.begin_attempt()
	var remark: Dictionary = {"after_level": "5-1", "text": "Has gastado {gastado}.", "text_if_zero": "Gastado fuera: 0. Bien."}
	assert_eq(hub.calc_remark_text(remark), "Gastado fuera: 0. Bien.", "Sin gasto, el texto del cero")
	GameState.add_attention_points(4)
	GameState.spend_attention(4, &"shop", &"5-1")
	GameState.claim_refunds(&"5-1")
	assert_eq(hub.calc_remark_text(remark), "Has gastado 4.", "Lo gastado en tiendas no lo devuelve Devoluciones")
	GameState.begin_attempt()
	assert_eq(GameState.get_attempt_spent(&"5-1"), 0, "Un intento nuevo empieza a 0")


func test_world_5_folder_lists_5_1_after_el_visto_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m5")
	assert_not_null(folder, "Carpeta M5 en la pagina 2")
	assert_false(folder.is_locked(), "Mundo 5 abierto tras El Visto")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m5"))
	assert_eq(levels.size(), 4, "5-1, 5-2, 5-3 y el jefe")
	assert_eq(panel.level_text(levels[0]), "5-1 Oferta del día - Nuevo")
	assert_false(HubWorlds.is_coming_soon(levels[1]), "5-2 jugable (paso 13)")
	assert_false(HubWorlds.is_coming_soon(levels[2]), "5-3 jugable (paso 14)")
	assert_true(HubWorlds.is_coming_soon(levels[3]), "El Vendedor «Próximamente»")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"5-1"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 5-1")
