# Nivel 5-2 «Prueba gratis» con el flujo real (scenes/main.tscn, LevelRunner;
# paso 13 de docs/propuesta-mundo-5.md §8, 2026-10-29): carga por el atajo de
# depuracion (--start-level=5-2) sin la Combinacion y llegada por el vortice,
# objetos (la «Prueba gratis», 5 persianas, 5 ranuras de precios, 11 estanterias
# de saldos en 4 grupos, la caja registradora de Calc, la caja de puntos, 4
# cargadores, 3 Ofertas, 3 Suscripciones, 10 puntos, power bank y msg_5_2), la
# «Prueba gratis» que da la Combinacion, la persiana de la salida solida hasta la
# Embestida, el secreto A (Calc tras la pared con glitch), el punto de
# sincronizacion, la puerta «Pagar» -> hub con el 5-2 completado y el 5-3
# desbloqueado («Próximamente») y la carpeta del Mundo 5 con el 5-2 jugable tras
# el 5-1. La ruta completa la comprueban tools/validate_level.py
# (tests/test_level_5_2.py) y el bot de la tienda (tests/test_mall_bot.gd); aqui
# Isak se coloca en cada punto. Usa su propia ruta de guardado (nunca
# user://save.json).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_level_5_2.json"
const LEVEL_ID: String = "5-2"
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
	# Se llega al 5-2 tras el 5-1: todo el kit del Mundo 4 (sin la Combinacion).
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1", &"4-2", &"4-3", &"4-boss", &"5-1"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"5-2")
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
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_COMBO), "Se entra sin la Combinacion")
	assert_eq(_count("Objects", FreeTrialBox), 1, "La «Prueba gratis»")
	assert_eq(_count("Objects", Shutter), 5, "Cinco persianas (salida + 3 del Tramo 1 + Tramo 4)")
	assert_eq(_count("Objects", PriceRail), 5, "Cinco ranuras (3 del Tramo 2, Tramo 4 y el probador)")
	assert_eq(_count("Objects", ClearanceShelf), 11, "Estanterias: 3 + 4 + 2 + las 2 del secreto C")
	assert_eq(_count("Objects", CalcRegister), 1, "La caja registradora de Calc (secreto A)")
	assert_eq(_count("Objects", SurpriseBox), 1, "La caja de puntos bajo una persiana")
	assert_eq(_count("Objects", Charger), 4, "Un cargador a pie de cada tramo")
	assert_eq(_count("Enemies", OfferSign), 3, "Tres Ofertas")
	assert_eq(_count("Enemies", Subscription), 3, "Una Suscripcion en el Tramo 1 y dos en el 4")
	assert_eq(_count("AttentionPoints", AttentionPoint), 10, "10 puntos de atencion en la rejilla")
	assert_eq(HubWorlds.level_points_total("5-2"), 11, "10 de la rejilla + la caja de puntos")
	var register := _obj("caja_calc") as CalcRegister
	assert_eq(register.get_cost(), 2, "Atajo de Calc: 2")
	assert_false(register.has_trap(), "Sin trampa")
	assert_not_null(_obj("power_bank_5_2"), "Power bank del secreto B")
	assert_not_null(_obj("mensaje_5_2"), "msg_5_2 del secreto A")


func test_free_trial_gives_the_combo_once() -> void:
	_start()
	await _arrive()
	var box := _obj("prueba_gratis") as FreeTrialBox
	assert_not_null(box)
	assert_false(box.is_on(), "Cerrada al llegar")
	assert_true(box.switch_on(), "El pulso de espaldas la abre")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMBO), "Da la Combinacion")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_COMBO))
	assert_false(box.switch_on(), "Un solo uso")


func test_exit_shutter_is_solid_until_the_ram() -> void:
	_start()
	await _arrive()
	var shutter := _obj("persiana_salida") as Shutter
	assert_true(shutter.is_solid(), "La salida de «Paquete completo» esta cerrada")
	assert_false(shutter.is_broken())
	assert_lt(absf(shutter.get_shutter_rect().position.x - 20.0 * TILE), 1.0, "Cols 20-23, a 8 tiles de la caja")
	shutter.break_open()
	assert_true(shutter.is_broken(), "Rota (la Embestida la rompe: tests/test_combo_obstacles.gd)")


func test_secret_a_calc_shop_behind_the_glitch_wall() -> void:
	_start()
	await _arrive()
	var wall := _obj("pared_tienda_calc") as GlitchWall
	assert_not_null(wall)
	assert_true(wall.visible_only_with_debug, "Sin el Debug parece terreno")
	var register := _obj("caja_calc") as CalcRegister
	assert_true(register.global_position.x > wall.global_position.x, "Calc, detras de la pared")
	var memory := _obj("mensaje_5_2") as MemoryPickup
	assert_eq(memory.memory_id, &"msg_5_2")
	GameState.attention_points = 1
	assert_false(register.pay(), "Con 1 no se paga (sin deuda)")
	GameState.add_attention_points(1)
	assert_true(register.pay(), "Con 2, si")
	assert_true(register.is_open(), "El atajo legitimo se abre")
	assert_eq(GameState.get_refundable(&"5-2"), 0, "Lo pagado a Calc no va a Devoluciones")


func test_sync_point_and_lives() -> void:
	_start()
	await _arrive()
	assert_eq(GameState.lives, 3, "3 vidas al empezar el intento")
	var sync_1 := _level().get_node(^"Checkpoints/sync_1") as Checkpoint
	assert_almost_eq(sync_1.global_position.x, 164.5 * TILE, TILE, "sync_1 en la Pausa")
	sync_1.activate()
	_teleport(180, 5)
	await wait_physics_frames(3)
	_die()
	assert_eq(GameState.lives, 2, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_1.get_spawn_position()), "Reaparece en sync_1")


func test_checkout_door_completes_the_level() -> void:
	_start()
	await _arrive()
	var terminal := _obj("terminal_pagar") as ExitTerminal
	assert_eq(terminal.get_frames_path(), "res://assets/sprites/checkout_terminal_frames.tres", "Aspecto checkout")
	assert_eq(terminal.offline_text, "Su prueba gratis se ha convertido en suscripción anual.")
	_teleport(319, 5)
	await wait_physics_frames(3)
	_complete()
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"5-2"), "5-2 en completed_levels")
	assert_true(GameState.is_level_unlocked(&"5-3"), "Desbloquea la fila del 5-3")
	assert_true(HubWorlds.is_coming_soon(HubWorlds.levels(HubWorlds.world(&"m5"))[2]), "El 5-3, «Próximamente»")


func test_world_5_folder_lists_5_2_after_5_1_and_loads_it() -> void:
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
	assert_false(HubWorlds.is_coming_soon(levels[1]), "El 5-2 se juega")
	for i: int in [2, 3]:
		assert_true(HubWorlds.is_coming_soon(levels[i]), "%s «Próximamente»" % levels[i]["id"])
	panel.skip_input_delay()
	assert_true(panel.select_option(&"5-2"))
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
	assert_eq(_main.get_level_id(), LEVEL_ID, "Carga el 5-2")
