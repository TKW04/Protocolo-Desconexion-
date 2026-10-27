# Hub de varias paginas (2026-10-27, paso 2 de docs/propuesta-hub-mundos-4-6.md
# §1 y §3.2; HubRoom, room.pages de data/hub.json): sin 3-boss una sola pagina
# identica a la de siempre; con 3-boss (acertijo pendiente) se cruza a la
# pagina 2 «en instalacion» por el borde derecho con glitch y el indicador
# tiene 2 puntos (el segundo cargando); con el upgrade instalado existen las 3.
# La camara queda fija en una pagina y se desliza al cruzar (Isak en pausa); en
# reposo nunca ensena dos paginas. Llegada por pagina (P2/P3) y el Debug
# obtenido funciona en el hub. Usa su propia ruta de guardado.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_pages.json"
const T: float = 64.0
const LONG_STEP_S: float = 5.0
const UPGRADE: StringName = &"hub_update_4_6"

var _hub: HubRoom
var _saved_path: String
var _saved_debug: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)


func _spawn(from_level: String = "") -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.arrived_from_level = from_level
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(LONG_STEP_S)
	return _hub


func _beat_curator() -> void:
	GameState.mark_level_completed(&"3-boss")


func _install() -> void:
	_beat_curator()
	assert_true(GameState.install_hub_upgrade(UPGRADE))


func _page_rect(page: int) -> Rect2i:
	return Rect2i((page - 1) * 1280, 0, 1280, 720)


func _walk(fake: PlayerInput, axis: float, frames: int) -> void:
	fake.move_axis = axis
	await wait_physics_frames(frames)
	fake.move_axis = 0.0


func _wall_right_x() -> float:
	var shape := _hub.get_node(^"Room/Collision/WallRight") as CollisionShape2D
	return shape.position.x - (shape.shape as RectangleShape2D).size.x * 0.5


func test_room_data_describes_three_pages_of_20x11() -> void:
	_spawn()
	var pages: Array[Dictionary] = _hub.get_pages()
	assert_eq(pages.size(), 3, "Paginas 1-3")
	assert_eq(_hub.get_room_size_tiles(), Vector2i(60, 11), "Una sola sala de 60 x 11")
	for page: int in [1, 2, 3]:
		assert_eq(_hub.get_camera_rect(page), _page_rect(page), "Camara de la pagina %d" % page)
	assert_eq(String(pages[0].get("requires_upgrade", "")), "", "La 1 no pide nada")
	assert_eq(String(pages[1].get("requires_upgrade", "")), String(UPGRADE))
	assert_eq(String(pages[2].get("requires_upgrade", "")), String(UPGRADE))


func test_before_the_curator_the_hub_is_one_page_as_always() -> void:
	_spawn()
	assert_eq(_hub.get_page_count(), 1)
	assert_eq(_hub.get_page_state(2), HubRoom.PAGE_CLOSED)
	assert_eq(_hub.get_page_state(3), HubRoom.PAGE_CLOSED)
	assert_eq(_hub.get_size_tiles(), Vector2i(20, 11))
	assert_null(_hub.get_edge_glitch(), "Sin glitch")
	assert_not_null(_hub.get_node_or_null(^"Room/PageDot"), "El punto de siempre")
	assert_null(_hub.get_page_indicator(1), "Sin indicador de varias paginas")
	assert_null(_hub.get_node_or_null(^"Room/PageBackground2"))
	assert_eq(_wall_right_x(), 1280.0, "Pared derecha en el borde de la pantalla")
	assert_eq(_hub.get_view_rect(), _page_rect(1))


func test_with_the_curator_beaten_page_two_is_installing() -> void:
	_beat_curator()
	_spawn()
	assert_eq(_hub.get_page_count(), 2)
	assert_eq(_hub.get_page_state(1), HubRoom.PAGE_OPEN)
	assert_eq(_hub.get_page_state(2), HubRoom.PAGE_INSTALLING)
	assert_eq(_hub.get_page_state(3), HubRoom.PAGE_CLOSED, "La 3 no existe sin el upgrade")
	assert_eq(_hub.get_size_tiles(), Vector2i(40, 11))
	assert_eq(_wall_right_x(), 2560.0, "Sin pared entre la 1 y la 2")
	assert_eq(_hub.get_current_page(), 1, "Se llega a P, en la 1")
	assert_eq(_hub.get_view_rect(), _page_rect(1))
	assert_not_null(_hub.get_node_or_null(^"Room/PageBackground2"), "Sala de la pagina 2")
	assert_null(_hub.get_node_or_null(^"Room/PageDot"))


func test_edge_glitch_on_column_19_rows_5_to_8_flickers_every_1_5_s() -> void:
	_beat_curator()
	_spawn()
	var glitch: HubEdgeGlitch = _hub.get_edge_glitch()
	assert_not_null(glitch, "Glitch del borde derecho")
	if glitch == null:
		return
	assert_eq(glitch.position, Vector2(19.0 * T, 5.0 * T))
	assert_eq(glitch.size, Vector2(T, 4.0 * T))
	assert_eq(glitch.colors.size(), 3, "Cian, ambar y verde acido")
	assert_eq(glitch.colors[1], Color("#ffa858"))
	assert_eq(glitch.colors[2], Color("#a6ff2e"))
	assert_eq(glitch.flicker_every_s, 1.5)
	var before: int = glitch.get_flicker_count()
	await wait_seconds(1.7)
	assert_gt(glitch.get_flicker_count(), before, "Parpadea")


func test_indicator_shows_two_dots_and_the_second_loads() -> void:
	_beat_curator()
	_spawn()
	var first: HubPageIndicator = _hub.get_page_indicator(1)
	var second: HubPageIndicator = _hub.get_page_indicator(2)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	assert_eq(first.get_dot_count(), 2)
	assert_eq(first.get_current(), 1)
	assert_true(first.is_loading(2), "Desde la 1, el segundo punto carga")
	assert_eq(second.get_current(), 2)
	assert_false(second.is_loading(2), "En la 2 su punto esta lleno")
	assert_eq(first.position, Vector2(640.0, 10.5 * T), "Centrado en la fila 10 de la 1")
	assert_eq(second.position, Vector2(1280.0 + 640.0, 10.5 * T))
	var a: float = first.get_loading_fraction()
	await wait_seconds(0.4)
	assert_ne(first.get_loading_fraction(), a, "El relleno avanza")


func test_isak_crosses_to_page_two_and_the_camera_slides() -> void:
	_beat_curator()
	_spawn()
	var isak: Isak = _hub.get_isak()
	var fake := PlayerInput.new()
	isak.input = fake
	var changed: Array[int] = []
	_hub.page_changed.connect(func(page: int) -> void: changed.append(page))
	isak.global_position = Vector2(19.6 * T, _hub.get_floor_y())
	fake.move_axis = 1.0
	await wait_until(func() -> bool: return _hub.is_page_sliding(), 1.0)
	assert_true(_hub.is_page_sliding(), "Cruzar el borde desliza la camara")
	assert_eq(_hub.get_current_page(), 2)
	assert_false(isak.is_physics_processing(), "Isak en pausa durante el deslizamiento")
	assert_true(_hub.blocks_pause_menu(), "Sin menu de pausa mientras se desliza")
	await wait_until(func() -> bool: return not _hub.is_page_sliding(), 1.0)
	assert_false(_hub.is_page_sliding(), "Termina en unos 0,35 s")
	assert_eq(changed, [2] as Array[int])
	assert_eq(_hub.get_view_rect(), _page_rect(2), "La camara fija en la pagina 2")
	assert_true(isak.is_physics_processing(), "Isak recupera el control")
	# Pared derecha de la pagina 2.
	isak.global_position = Vector2(39.0 * T, _hub.get_floor_y())
	await wait_physics_frames(40)
	assert_lt(isak.global_position.x, 2560.0, "Pared derecha de la 2")
	assert_eq(_hub.get_current_page(), 2)
	fake.move_axis = 0.0


func test_walking_back_slides_to_page_one() -> void:
	_beat_curator()
	_spawn()
	var isak: Isak = _hub.get_isak()
	var fake := PlayerInput.new()
	isak.input = fake
	isak.global_position = Vector2(20.5 * T, _hub.get_floor_y())
	await wait_physics_frames(2)
	_hub.finish_page_slide()
	assert_eq(_hub.get_current_page(), 2)
	await _walk(fake, -1.0, 30)
	_hub.finish_page_slide()
	assert_eq(_hub.get_current_page(), 1, "Vuelve a la 1")
	assert_eq(_hub.get_view_rect(), _page_rect(1))


func test_camera_never_rests_showing_two_pages() -> void:
	_install()
	_spawn()
	var isak: Isak = _hub.get_isak()
	isak.input = PlayerInput.new()
	for x_tiles: float in [5.0, 25.0, 45.0, 30.0, 10.0]:
		isak.global_position = Vector2(x_tiles * T, _hub.get_floor_y())
		await wait_physics_frames(2)
		_hub.finish_page_slide()
		var page: int = int(x_tiles / 20.0) + 1
		var view: Rect2i = _hub.get_view_rect()
		assert_eq(view, _page_rect(page), "En reposo la camara ve solo la pagina %d" % page)
		assert_eq(view.size.x, 1280)


func test_with_the_upgrade_all_three_pages_exist() -> void:
	_install()
	_spawn()
	assert_eq(_hub.get_page_count(), 3)
	for page: int in [1, 2, 3]:
		assert_eq(_hub.get_page_state(page), HubRoom.PAGE_OPEN)
	assert_eq(_hub.get_size_tiles(), Vector2i(60, 11))
	assert_eq(_wall_right_x(), 3840.0, "Pared al final de la pagina 3")
	assert_null(_hub.get_edge_glitch(), "Instalado: sin glitch")
	var indicator: HubPageIndicator = _hub.get_page_indicator(3)
	assert_not_null(indicator)
	if indicator != null:
		assert_eq(indicator.get_dot_count(), 3, "Indicador de 3 puntos")
		assert_eq(indicator.get_current(), 3)
		assert_false(_hub.get_page_indicator(1).is_loading(2), "Nada carga")
	var isak: Isak = _hub.get_isak()
	isak.input = PlayerInput.new()
	isak.global_position = Vector2(41.0 * T, _hub.get_floor_y())
	await wait_physics_frames(2)
	_hub.finish_page_slide()
	assert_eq(_hub.get_current_page(), 3, "Se cruza a la 3")
	assert_eq(_hub.get_view_rect(), _page_rect(3))


func test_folders_stay_on_page_one() -> void:
	_install()
	_spawn()
	assert_eq(_hub.get_folder_ids(), [&"m1", &"m2", &"m3"] as Array[StringName],
		"Las carpetas M4-M6 llegan con la instalacion (paso 5)")


func test_arrival_is_on_the_page_of_the_world_folder() -> void:
	_install()
	_spawn("4-1")
	assert_eq(_hub.get_arrival_page(), 2, "Mundo 4: pagina 2")
	assert_eq(_hub.get_current_page(), 2)
	assert_eq(_hub.get_view_rect(), _page_rect(2))
	assert_almost_eq(_hub.get_isak().global_position.x, _hub.get_spawn_position(2).x, 0.5)
	assert_eq(_hub.get_spawn_position(2), Vector2(24.5 * T, 9.0 * T), "P2 sobre el dock")
	_hub.free()
	_spawn("6-boss")
	assert_eq(_hub.get_current_page(), 3, "Mundo 6: pagina 3")
	assert_eq(_hub.get_view_rect(), _page_rect(3))
	_hub.free()
	_spawn("3-boss")
	assert_eq(_hub.get_current_page(), 1, "Mundos 1-3: P")
	assert_eq(_hub.get_isak().global_position.x, 5.5 * T)


func test_arrival_falls_back_to_p_if_the_page_does_not_exist() -> void:
	_beat_curator()
	_spawn("6-1")
	assert_eq(_hub.get_current_page(), 1, "Sin la pagina 3, llegada en P")
	assert_eq(_hub.get_view_rect(), _page_rect(1))


func test_obtained_debug_works_in_the_hub() -> void:
	EcoProgress.obtain_debug()
	_beat_curator()
	_spawn()
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Obtenido: no se bloquea en el hub")
	for i: int in 120:
		DebugMode.step(1.0 / 60.0, true)
		if DebugMode.is_active():
			break
	assert_true(DebugMode.is_active(), "El Debug obtenido se activa en el hub")
	DebugMode.reset()


func test_debug_not_obtained_stays_locked_in_the_hub() -> void:
	_spawn()
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG))
	for i: int in 120:
		DebugMode.step(1.0 / 60.0, true)
	assert_false(DebugMode.is_active())
