# Hub real del Mundo 1 (HubRoom, scenes/hub/hub.tscn; paso 5 de
# docs/propuesta-hub-y-guardado.md §6.2): sala de 20x11 tiles con camara fija,
# Isak llega por un vortice en P y recupera el control, la energia se llena al
# entrar, paredes y suelo (dock), huecos apagados (Calc dormida, Notas,
# Linterna, Papelera) y HUD en modo hub (Modo Avion e indicador «sin guardar»
# en ambar). Usa su propia ruta de guardado.
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_room.json"
const T: float = 64.0
const LONG_STEP_S: float = 5.0

var _hub: HubRoom
var _saved_path: String
var _saved_pulse: bool
var _saved_debug: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)


func _spawn() -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	return _hub


func _finish_arrival() -> void:
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(LONG_STEP_S)


func test_room_is_one_screen_of_20x11_tiles_with_a_fixed_camera() -> void:
	_spawn()
	assert_eq(_hub.get_size_tiles(), Vector2i(20, 11))
	assert_eq(_hub.get_size_px(), Vector2(1280.0, 704.0))
	var camera := _hub.get_isak().get_node(^"Camera2D") as Camera2D
	assert_eq(Rect2i(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left,
		camera.limit_bottom - camera.limit_top), Rect2i(0, 0, 1280, 720), "Camara fija: la pantalla")


func test_energy_and_sync_are_full_on_enter() -> void:
	GameState.debug_energy = 5.0
	GameState.sync_rate = 30.0
	_spawn()
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "Energia llena al entrar")
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max())


func test_isak_arrives_at_p_through_a_vortex_and_gets_control() -> void:
	var arrived: Array[bool] = []
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.arrived.connect(func() -> void: arrived.append(true))
	add_child(_hub)
	var isak: Isak = _hub.get_isak()
	assert_eq(_hub.get_spawn_position(), Vector2(5.5 * T, 9.0 * T), "P en (5, 8), pies sobre el dock")
	assert_almost_eq(isak.global_position.x, 5.5 * T, 0.5)
	assert_not_null(_hub.get_arrival_vortex(), "Vortice de llegada")
	assert_true(isak.is_warping(), "Sin control durante la llegada")
	assert_false(_hub.has_arrived())
	_finish_arrival()
	assert_true(_hub.has_arrived())
	assert_eq(arrived.size(), 1, "Senal arrived")
	assert_false(isak.is_warping(), "Recupera el control")
	assert_eq(isak.modulate.a, 1.0, "Visible")
	var fake := PlayerInput.new()
	isak.input = fake
	await wait_physics_frames(10)
	assert_true(isak.is_on_floor(), "De pie sobre el dock")
	assert_almost_eq(isak.global_position.y, _hub.get_floor_y(), 1.0)
	var x: float = isak.global_position.x
	fake.move_axis = 1.0
	await wait_physics_frames(10)
	assert_gt(isak.global_position.x, x + 1.0, "Camina")


func test_walls_keep_isak_inside_the_screen() -> void:
	_spawn()
	_finish_arrival()
	var isak: Isak = _hub.get_isak()
	var fake := PlayerInput.new()
	isak.input = fake
	isak.global_position = Vector2(1.0 * T, _hub.get_floor_y())
	fake.move_axis = -1.0
	await wait_physics_frames(40)
	assert_gt(isak.global_position.x, 0.0, "Pared izquierda")
	isak.global_position = Vector2(19.0 * T, _hub.get_floor_y())
	fake.move_axis = 1.0
	await wait_physics_frames(40)
	assert_lt(isak.global_position.x, 1280.0, "Pared derecha")


func test_dormant_slots_stand_on_the_dock() -> void:
	_spawn()
	for id: StringName in [&"calc", &"notas", &"linterna", &"papelera"]:
		var node: Node2D = _hub.get_dormant(id)
		assert_not_null(node, String(id))
		if node == null:
			continue
		var visual: Node2D = node.get_node_or_null(^"Visual")
		assert_not_null(visual, "Visual sustituible")
		assert_true(visual is HubProvisionalArt, "Arte provisional")
		var art := visual as HubProvisionalArt
		assert_almost_eq(node.position.y + art.size.y, _hub.get_floor_y(), 0.5, "%s de pie sobre el dock" % id)
	assert_eq((_hub.get_dormant(&"calc").get_node(^"Visual") as HubProvisionalArt).kind, &"calc_dormant",
		"Calc dormida")
	assert_eq(_hub.get_dormant(&"calc").position.x, 7.0 * T, "Calc en la columna 7")


func test_hub_unlocks_the_pulse_and_restores_abilities_on_exit() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, false)
	_spawn()
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Pulso para las estaciones")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Sin Debug en el hub")
	_hub.free()
	_hub = null
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Se restaura al salir")


func test_hud_shows_airplane_mode_and_amber_unsaved_indicator() -> void:
	_spawn()
	var hud: Hud = _hub.get_hud()
	assert_true(hud.is_hub_mode())
	assert_true(hud.is_airplane_mode_shown(), "Modo Avion en lugar de la senal")
	assert_false(hud.is_unsaved_indicator_shown(), "Sin cambios: sin indicador")
	GameState.request_save()
	assert_true(hud.is_unsaved_indicator_shown(), "Cambios sin guardar: indicador")
	assert_eq(hud.get_unsaved_text(), "Sin guardar")
	assert_eq(hud.get_unsaved_color(), Color.html("#ffa000"), "Ambar de hub.gpl")
	assert_true(GameState.save_game())
	assert_false(hud.is_unsaved_indicator_shown(), "Tras guardar se apaga")


func test_level_hud_is_not_in_hub_mode() -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	add_child_autofree(hud)
	assert_false(hud.is_hub_mode())
	assert_false(hud.is_unsaved_indicator_shown(), "En los niveles no se muestra")
