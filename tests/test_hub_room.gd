# Hub real del Mundo 1 (HubRoom, scenes/hub/hub.tscn; paso 5 de
# docs/propuesta-hub-y-guardado.md §6.2): sala de 20x11 tiles con camara fija,
# Isak llega por un vortice en P y recupera el control, la energia se llena al
# entrar, paredes y suelo (dock), huecos apagados (Calc dormida, Notas,
# Linterna, Papelera) con el arte final y HUD en modo hub (Modo Avion e indicador «sin guardar»
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


func test_dormant_slots_stand_on_the_dock_with_final_art() -> void:
	_spawn()
	assert_eq(_hub.get_dormant_ids(), [&"notas", &"linterna", &"papelera"] as Array[StringName],
		"Calc ya no es un hueco: es la estacion de mejoras (test_calc_station.gd)")
	for id: StringName in [&"notas", &"linterna", &"papelera"]:
		var node: Node2D = _hub.get_dormant(id)
		assert_not_null(node, String(id))
		if node == null:
			continue
		var visual: Node2D = node.get_node_or_null(^"Visual")
		assert_not_null(visual, "Visual sustituible")
		assert_false(visual is HubProvisionalArt, "%s: arte final, no provisional" % id)
		var height: float = 0.0
		if visual is AnimatedSprite2D:
			var sprite := visual as AnimatedSprite2D
			height = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size().y
		elif visual is Sprite2D:
			height = (visual as Sprite2D).texture.get_size().y
		assert_eq(height, 96.0, "%s: 64x96" % id)
		assert_almost_eq(node.position.y + height, _hub.get_floor_y(), 0.5, "%s de pie sobre el dock" % id)
	var calc := _hub.get_calc().get_visual() as AnimatedSprite2D
	assert_not_null(calc, "Calc animada")
	if calc != null:
		assert_eq(calc.animation, &"sleep", "Calc dormida")
		assert_true(calc.is_playing())
	assert_eq(_hub.get_calc().position.x, 7.0 * T, "Calc en la columna 7")


func test_room_uses_final_background_dock_and_page_dot() -> void:
	_spawn()
	var room: Node = _hub.get_node(^"Room")
	var bg := room.get_node_or_null(^"Background") as AnimatedSprite2D
	assert_not_null(bg, "Fondo con la foto rota")
	assert_eq(bg.sprite_frames.get_frame_texture(&"off", 0).get_size(), Vector2(1280.0, 720.0))
	assert_eq(bg.sprite_frames.get_frame_count(&"off"), 2, "Contorno cian que parpadea")
	assert_eq(_hub.get_background_state(), &"off", "Sin el Mundo 1 completo: pieza 1 apagada")
	var dock: Node = room.get_node_or_null(^"Dock")
	assert_not_null(dock, "Dock de tiles")
	var top_row: int = 0
	for tile: Node in dock.get_children():
		var sprite := tile as Sprite2D
		assert_not_null(sprite.texture, "Tile con textura")
		if is_equal_approx(sprite.position.y, _hub.get_floor_y()):
			top_row += 1
	assert_eq(top_row, 20, "Una fila de 20 tiles de superficie sobre el suelo")
	assert_not_null(room.get_node_or_null(^"PageDot"), "Indicador de pagina")


func test_background_lights_piece_one_when_world_1_is_completed() -> void:
	for id: StringName in [&"1-1", &"1-2", &"1-3"]:
		GameState.mark_level_completed(id)
	_spawn()
	assert_eq(_hub.get_background_state(), &"on", "Mundo 1 completo: pieza 1 encendida")


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
	var icons: Array[TextureRect] = hud.get_hub_icons()
	assert_eq(icons.size(), 2, "Modo Avion y «sin guardar»")
	assert_eq(icons[0].texture.resource_path, "res://assets/sprites/hub/icons/icon_airplane_mode_00.png")
	assert_eq(icons[1].texture.resource_path, "res://assets/sprites/hub/icons/icon_unsaved_00.png")
	assert_true(GameState.save_game())
	assert_false(hud.is_unsaved_indicator_shown(), "Tras guardar se apaga")


func test_level_hud_is_not_in_hub_mode() -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	add_child_autofree(hud)
	assert_false(hud.is_hub_mode())
	assert_false(hud.is_unsaved_indicator_shown(), "En los niveles no se muestra")
