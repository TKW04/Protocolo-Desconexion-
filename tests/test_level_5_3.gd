# Nivel 5-3 «Última oportunidad» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 14 de docs/propuesta-mundo-5.md §8, 2026-10-29): carga por el atajo de
# depuracion (--start-level=5-3) con la Combinacion y llegada por el vortice,
# objetos (9 cuentas regresivas, 8 cajas sorpresa, 3 cargadores, 6 Ofertas, 2
# Suscripciones, la tienda, el atajo «Verificando pago…», Terminos y condiciones,
# 2 estanterias de saldos, 4 deseos, el tachon, la trastienda a oscuras con su paso
# en tinta, 9 puntos, power bank y msg_5_3), el laser real que destruye una caja
# peligrosa desde la B3, el atajo con trampa processing, «rechazar» con el laser,
# el secreto A (tachon), los dos puntos de sincronizacion, la puerta «Pagar» -> hub
# con el 5-3 completado y la fila de El Vendedor desbloqueada (jugable desde el paso 18) y la
# carpeta del Mundo 5 con el 5-3 jugable tras el 5-2. La ruta completa la comprueban
# tools/validate_level.py (tests/test_level_5_3.py) y el bot de la tienda
# (tests/test_mall_bot.gd); aqui Isak se coloca en cada punto. Usa su propia ruta de
# guardado (nunca user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_5_3.json"
const LEVEL_ID: String = "5-3"
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
	# Se llega al 5-3 tras el 5-2: todo el kit, con la Combinacion y la Linterna.
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS,
			GameState.ABILITY_COMBO]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1", &"4-2", &"4-3", &"4-boss", &"5-1", &"5-2"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"5-3")
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
	for ability: StringName in [GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]:
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
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMBO), "Se entra con la Combinacion")
	assert_eq(_count("Objects", CountdownPlatform), 9, "Nueve cuentas regresivas en el Tramo 1")
	assert_eq(_count("Objects", SurpriseBox), 8, "Ocho cajas sorpresa (siete en cadena y la del secreto C)")
	assert_eq(_count("Objects", Charger), 3, "Tres cargadores, ninguno en el Tramo 2")
	assert_eq(_count("Objects", ShopItem), 2, "La tienda: Sync y energia")
	assert_eq(_count("Objects", ShortcutDoor), 1, "El atajo con trampa")
	assert_eq(_count("Objects", TermsGate), 1, "Terminos y condiciones")
	assert_eq(_count("Objects", ClearanceShelf), 2, "Las estanterias del Sismo")
	assert_eq(_count("Objects", WishlistPlatform), 4, "Cuatro deseos")
	assert_eq(_count("Objects", WishStrike), 1, "El tachon")
	assert_eq(_count("Objects", DarkZone), 1, "La trastienda a oscuras")
	assert_eq(_count("Objects", InkOnly), 1, "El paso en tinta")
	assert_eq(_count("Enemies", OfferSign), 6, "Seis Ofertas")
	assert_eq(_count("Enemies", Subscription), 2, "Dos Suscripciones junto al atajo")
	assert_eq(_count("AttentionPoints", AttentionPoint), 9, "9 puntos de atencion en la rejilla")
	assert_eq(HubWorlds.level_points_total("5-3"), 11, "9 de la rejilla + las dos cajas de puntos")
	var door := _obj("atajo_verificando") as ShortcutDoor
	assert_eq(door.get_cost(), 3, "Atajo: 3")
	assert_true(door.has_trap(), "Con trampa")
	assert_eq(door.trap, ShortcutDoor.TRAP_PROCESSING, "«Verificando pago…»")
	assert_not_null(_obj("power_bank_5_3"), "Power bank del secreto B")
	assert_not_null(_obj("mensaje_5_3"), "msg_5_3 del secreto A")


## El laser real desde la B3 destruye la caja de la Suscripcion sin abrirla (lo que hace el camino tras mirarla con el
## Debug; la caja tiene su zona del laser por encima de la tapa).
func test_real_laser_destroys_the_subscription_box() -> void:
	_start()
	await _arrive()
	var box := _obj("caja_g1_3") as SurpriseBox
	assert_eq(box.content, SurpriseBox.CONTENT_SUBSCRIPTION)
	var col: int = int(floor(box.get_body_rect().position.x / TILE)) - 2
	_teleport(col, 5)
	_isak.facing = 1.0
	await wait_physics_frames(10)
	GameState.debug_energy = GameState.get_debug_energy_max()
	# Como el camino: mira dentro con el Debug (1 s) y lo suelta antes del laser.
	DebugMode.input_enabled = true
	for i: int in 90:
		DebugMode.step(1.0 / 60.0, true)
		await wait_physics_frames(1)
	DebugMode.step(1.0 / 60.0, false)
	DebugMode.input_enabled = false
	await wait_physics_frames(20)
	_isak.input.laser_pressed = true
	await wait_physics_frames(1)
	_isak.input.laser_pressed = false
	await wait_physics_frames(60)
	assert_true(box.is_destroyed(), "El laser desde la B3 la destruye")
	assert_null(box.get_released(), "Sin Suscripcion")


func test_shortcut_processing_freezes_once() -> void:
	_start()
	await _arrive()
	var door := _obj("atajo_verificando") as ShortcutDoor
	GameState.attention_points = 2
	assert_false(door.pay(), "Con 2 no se paga (sin deuda)")
	GameState.attention_points = 3
	assert_true(door.pay(), "Con 3, si")
	assert_true(door.is_open())
	assert_eq(GameState.get_refundable(&"5-3"), 3, "Lo pagado en un atajo con trampa va a Devoluciones")


func test_terms_reject_opens_without_subscription() -> void:
	_start()
	await _arrive()
	var gate := _obj("terminos_t3") as TermsGate
	assert_false(gate.is_open())
	assert_true(gate.reject(&"laser"), "«rechazar» abre")
	assert_true(gate.is_open())
	assert_null(gate.get_subscription(), "Sin Suscripcion")


func test_secret_a_strike_needs_the_debug() -> void:
	_start()
	await _arrive()
	var strike := _obj("tachon_radio") as WishStrike
	assert_not_null(strike)
	assert_true(strike.visible_only_with_debug, "Sin el Debug parece terreno")
	var memory := _obj("mensaje_5_3") as MemoryPickup
	assert_eq(memory.memory_id, &"msg_5_3")
	assert_true(memory.global_position.x < strike.global_position.x, "El mensaje, detras del tachon")


func test_sync_points_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	var sync_2 := _level().get_node(^"Checkpoints/sync_2") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 184.5 * TILE, TILE, "sync_1 en la Pausa del Tramo 2")
	assert_almost_eq(sync_2.global_position.x, 275.5 * TILE, TILE, "sync_2 en la Pausa de la lista de deseos")
	sync_2.activate()
	_teleport(290, 6)
	await wait_physics_frames(3)
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead(), "Muere con Sync Rate 0")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_2.get_spawn_position()), "Reaparece en sync_2")


func test_checkout_door_completes_the_level_and_unlocks_the_vendor_row() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_pagar") as ExitTerminal
	assert_eq(terminal.get_frames_path(), "res://assets/sprites/checkout_terminal_frames.tres", "Aspecto checkout")
	assert_eq(terminal.offline_text, "Pago realizado. Gracias por elegirnos.")
	_teleport(311, 6)
	await wait_physics_frames(3)
	_complete()
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"5-3"), "5-3 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"5-boss"), "Desbloquea la fila de El Vendedor")
	assert_false(HubWorlds.is_coming_soon(HubWorlds.levels(HubWorlds.world(&"m5"))[3]), "El Vendedor, jugable (paso 18)")


func test_world_5_folder_lists_5_3_after_5_2_and_loads_it() -> void:
	_start(LevelRunner.START_HUB)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	var hub: HubRoom = _main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m5")
	assert_not_null(folder, "Carpeta M5 en la pagina 2")
	assert_true(folder.open(hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	var levels: Array = HubWorlds.levels(HubWorlds.world(&"m5"))
	assert_false(HubWorlds.is_coming_soon(levels[2]), "El 5-3 se juega")
	assert_false(HubWorlds.is_coming_soon(levels[3]), "El Vendedor jugable (paso 18)")
	panel.skip_input_delay()
	assert_true(panel.select_option(&"5-3"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 5-3")
