# Camara de torre y fondo vertical (2026-10-16, paso 2 de docs/propuesta-1-2.md
# §10): TowerCamera (scripts/player/tower_camera.gd, data/camera_tower.json) en
# la torre de prueba (scenes/levels/tower_test.tscn, 28x40, desde
# data/levels/tower_test.json): limites del grid, ancla al suelo con zona muerta
# (saltar no mueve la camara), encaje en el piso, subida por el zigzag sin
# sacudidas (Isak simulado con la fisica real) y fondo que se desplaza en Y. La
# camara del 1-1 (camera.vertical simple) no cambia: prueba de regresion.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const TOWER_SCENE: PackedScene = preload("res://scenes/levels/tower_test.tscn")
const LEVEL_1_1_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const TOWER_PATH: String = "res://data/levels/tower_test.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const VIEW: Vector2 = Vector2(1280.0, 720.0)
## Oscilacion admitida de la camara (px) al subir o al saltar en el sitio.
const JITTER_PX: float = 1.0

var _level: GeneratedLevel
var _isak: Isak
var _sim: IsakSim
var _pulse_was: bool
var _rows: int
var _cols: int


func before_all() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TOWER_PATH))
	_rows = (data["grid"] as Array).size()
	_cols = String(data["grid"][0]).length()


func before_each() -> void:
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was)


func _load(scene: PackedScene) -> void:
	_level = scene.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)


## Isak quieto de pie en la celda (col, row) del grid, con la camara colocada.
func _place(col: float, row: int) -> void:
	_sim.input.move_axis = 0.0
	_sim.input.clear_just_pressed()
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	_isak.snap_camera()


func _cam() -> Vector2:
	return _isak.get_camera().global_position


func _tower() -> TowerCamera:
	return _isak.get_tower_camera()


## Isak apoyado en la fila de pie `row` (pies en lo alto de la fila de abajo).
func _standing_row() -> int:
	return roundi(_isak.global_position.y / T) - 1


# --- Datos y escena ---

func test_tower_scene_is_generated_with_tower_camera_and_vertical_background() -> void:
	await _load(TOWER_SCENE)
	assert_eq(_level.get_size_px(), Vector2i(_cols * 64, _rows * 64))
	assert_gt(_rows, 14, "Nivel vertical (alto > 14)")
	assert_eq(_isak.camera_mode, Isak.CAMERA_TOWER)
	assert_not_null(_tower(), "Camara de torre")
	var camera := _isak.get_camera()
	assert_true(camera.top_level, "La camara ya no va pegada a Isak")
	assert_false(camera.position_smoothing_enabled, "Suavizado propio de TowerCamera")
	assert_eq(camera.limit_bottom, _rows * 64)
	assert_eq(_isak.camera_bands.size(), 5, "Vestibulo, tres pisos y azotea")
	var background := _level.get_node(^"Background") as World1Background
	assert_true(background.vertical)


func test_parameters_come_from_json_and_jumps_fit_the_dead_zone() -> void:
	var cam := TowerCamera.load_from_file()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TowerCamera.DEFAULT_PATH))
	assert_eq(cam.anchor_offset_px, float(data["anchor_offset_px"]))
	assert_eq(cam.standing_zone_px, Vector2(data["standing_zone_px"][0], data["standing_zone_px"][1]))
	assert_eq(cam.air_zone_px, Vector2(data["air_zone_px"][0], data["air_zone_px"][1]))
	var physics := PlayerPhysics.load_from_file(PlayerPhysics.DEFAULT_PATH)
	var jump_px: float = physics.jump_velocity * physics.jump_velocity / (2.0 * physics.gravity)
	assert_gt(cam.standing_zone_px.x - cam.air_zone_px.x, jump_px,
		"Saltar desde el suelo no saca a Isak de la zona muerta (%.0f px)" % jump_px)


# --- Limites ---

func test_limits_clamp_the_view_inside_the_grid() -> void:
	var cam := TowerCamera.load_from_file()
	cam.configure(VIEW, Rect2(0, 0, _cols * T, _rows * T), PackedVector2Array())
	var bottom: Vector2 = cam.snap(Vector2(3.5 * T, 39.0 * T))
	assert_almost_eq(bottom.y, _rows * T - VIEW.y * 0.5, 0.01, "Abajo: el borde inferior del grid")
	assert_almost_eq(bottom.x, VIEW.x * 0.5, 0.01, "A la izquierda: el borde del grid")
	var top: Vector2 = cam.snap(Vector2(25.5 * T, 3.0 * T))
	assert_almost_eq(top.y, VIEW.y * 0.5, 0.01, "Arriba: el borde superior del grid")
	assert_almost_eq(top.x, _cols * T - VIEW.x * 0.5, 0.01, "A la derecha")
	for i: int in 120:
		var c: Vector2 = cam.update(Vector2(25.5 * T, -400.0), false, DT)
		assert_true(c.y >= VIEW.y * 0.5 - 0.01, "Nunca por encima del grid")


func test_scene_camera_limits_at_bottom_middle_and_top() -> void:
	await _load(TOWER_SCENE)
	_place(3.0, 38)
	assert_almost_eq(_cam().y, _rows * T - VIEW.y * 0.5, 0.5, "Abajo, en el vestibulo")
	assert_almost_eq(_isak.get_viewport().get_camera_2d().get_screen_center_position().y,
		_rows * T - VIEW.y * 0.5, 1.0)
	_place(22.0, 2)
	assert_almost_eq(_cam().y, VIEW.y * 0.5, 0.5, "Arriba, en la azotea")


# --- Ancla, zona muerta y bandas ---

func test_jump_in_place_does_not_move_the_camera() -> void:
	await _load(TOWER_SCENE)
	_place(10.0, 32)  # suelo del piso 1, bajo nada
	for i: int in 30:
		_sim.step()
	var before: Vector2 = _cam()
	var max_dy: float = 0.0
	var max_rise: float = 0.0
	var floor_y: float = _isak.global_position.y
	_sim.press_jump()
	for i: int in 90:
		_sim.step()
		max_dy = maxf(max_dy, absf(_cam().y - before.y))
		max_rise = maxf(max_rise, floor_y - _isak.global_position.y)
	assert_gt(max_rise, 150.0, "Isak salta de verdad (%.0f px)" % max_rise)
	assert_true(_isak.is_on_floor())
	assert_lt(max_dy, JITTER_PX, "La camara no se mueve al saltar en el sitio (%.2f px)" % max_dy)


func test_landing_higher_moves_the_camera_smoothly_and_falling_follows_the_dead_zone() -> void:
	var cam := TowerCamera.load_from_file()
	cam.configure(VIEW, Rect2(0, 0, _cols * T, 100.0 * T), PackedVector2Array())
	var feet := Vector2(10.0 * T, 60.0 * T)
	var start: Vector2 = cam.snap(feet)
	# Aterriza 2 tiles mas arriba: la camara va hacia arriba sin saltos bruscos.
	feet.y -= 2.0 * T
	var previous: float = start.y
	var biggest_step: float = 0.0
	for i: int in 120:
		var c: Vector2 = cam.update(feet, true, DT)
		assert_true(c.y <= previous + 0.001, "Solo sube")
		biggest_step = maxf(biggest_step, previous - c.y)
		previous = c.y
	assert_almost_eq(previous, start.y - 2.0 * T, 1.0, "Llega al nuevo suelo")
	assert_lt(biggest_step, 2.0 * T * 0.2, "Suavizado: ningun paso mayor que el 20 % del cambio")
	# Cae 10 tiles por el aire: la zona muerta mantiene a Isak en pantalla.
	for i: int in 60:
		feet.y += 10.0 * T / 60.0
		var c: Vector2 = cam.update(feet, false, DT)
		var body_from_top: float = (feet.y - cam.body_center_px) - (c.y - VIEW.y * 0.5)
		assert_true(body_from_top <= cam.air_zone_px.y + 0.01, "Isak en la zona muerta al caer (%.1f)" % body_from_top)
	assert_eq(cam.get_ground_y(), 58.0 * T, "En el aire el ancla no cambia")


func test_floor_that_fits_on_screen_is_centered_and_still() -> void:
	var cam := TowerCamera.load_from_file()
	var band := Vector2(24.0 * T, 34.0 * T)  # piso 1 de la torre de prueba: filas 24-33 (640 px)
	cam.configure(VIEW, Rect2(0, 0, _cols * T, _rows * T), PackedVector2Array([band]))
	var on_floor: Vector2 = cam.snap(Vector2(10.0 * T, 33.0 * T))
	assert_almost_eq(on_floor.y, (band.x + band.y) * 0.5, 0.01, "Piso entero en pantalla")
	var first_step: Vector2 = cam.snap(Vector2(15.0 * T, 31.0 * T))
	assert_almost_eq(first_step.y, on_floor.y, 0.01, "La primera repisa no mueve la camara")
	assert_eq(cam.band_at(40.0 * T), Vector2.ZERO)


# --- Subida real por el zigzag ---

## Recorrido del validador (python3 tools/validate_level.py data/levels/tower_test.json)
## por el vestibulo y los pisos 1 y 2: [columna a la que andar, eje del salto] (eje
## 2 = solo andar). Isak simulado con la fisica real.
const CLIMB: Array = [
	[21, 0.0], [23, 0.0], [23, 0.0],                                   # vestibulo
	[15, 0.0], [14, -1.0], [9, -1.0], [4, -1.0], [3, 0.0],             # piso 1
	[10, 0.0], [13, 1.0], [18, 1.0], [23, 0.0], [24, 0.0],             # piso 2
]


func _walk_to(col: int) -> void:
	var target: float = (col + 0.5) * T
	var dir: float = signf(target - _isak.global_position.x)
	if absf(target - _isak.global_position.x) < 8.0:
		return
	_sim.input.move_axis = dir
	_sim.step_until(func() -> bool: return (target - _isak.global_position.x) * dir <= 4.0, _sim.steps_for(6.0))
	_sim.input.move_axis = 0.0
	_sim.step_until(func() -> bool: return absf(_isak.velocity.x) < 1.0, _sim.steps_for(1.0))


func _jump(axis: float) -> void:
	_sim.input.move_axis = axis
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _isak.is_on_floor() and _isak.velocity.y >= 0.0, _sim.steps_for(2.0))
	_sim.input.move_axis = 0.0
	_sim.settle()


func test_climbing_the_zigzag_moves_the_camera_up_without_shaking() -> void:
	await _load(TOWER_SCENE)
	_place(3.0, 38)
	var samples: Array[float] = []
	var record := func() -> void: samples.append(_cam().y)
	_isak.state_changed.connect(func(_a: StringName, _b: StringName) -> void: record.call())
	var start_y: float = _cam().y
	for step: Array in CLIMB:
		_walk_to(int(step[0]))
		record.call()
		if float(step[1]) <= 1.0:
			var rows_before: int = _standing_row()
			_jump(float(step[1]))
			assert_eq(_standing_row(), rows_before - 2, "Sube 2 filas en el paso %s" % [step])
	for i: int in 120:
		_sim.step()
		record.call()
	assert_eq(_standing_row(), 12, "Isak llega al suelo del piso 3")
	var end_y: float = _cam().y
	assert_lt(end_y, start_y - 18.0 * T, "La camara subio con Isak (%.0f -> %.0f)" % [start_y, end_y])
	var worst_down: float = 0.0
	for i: int in range(1, samples.size()):
		worst_down = maxf(worst_down, samples[i] - samples[i - 1])
	assert_lt(worst_down, JITTER_PX, "Subiendo, la camara nunca baja (peor: %.2f px)" % worst_down)
	var body_from_top: float = (_isak.global_position.y - _tower().body_center_px) - (end_y - VIEW.y * 0.5)
	assert_between(body_from_top, _tower().standing_zone_px.x - 0.5, _tower().standing_zone_px.y + 0.5,
		"Isak de pie dentro de la zona de reposo")


func test_climb_samples_every_physics_step() -> void:
	# Igual que la subida, pero con muestras en cada paso (no solo en los cambios de estado).
	await _load(TOWER_SCENE)
	_place(15.0, 32)
	var samples: Array[float] = [_cam().y]
	_sim.input.move_axis = 0.0
	_sim.press_jump()
	for i: int in 80:
		_sim.step()
		samples.append(_cam().y)
	_sim.input.move_axis = -1.0
	_sim.press_jump()
	for i: int in 80:
		_sim.step()
		samples.append(_cam().y)
	_sim.input.move_axis = 0.0
	for i: int in 120:
		_sim.step()
		samples.append(_cam().y)
	assert_eq(_standing_row(), 28, "Dos repisas mas arriba")
	var reversals: int = 0
	var worst_down: float = 0.0
	for i: int in range(1, samples.size()):
		var d: float = samples[i] - samples[i - 1]
		worst_down = maxf(worst_down, d)
		if d > JITTER_PX * 0.1:
			reversals += 1
	assert_lt(worst_down, JITTER_PX, "Sin sacudidas hacia abajo (%.3f px)" % worst_down)
	assert_eq(reversals, 0, "Ningun cambio de sentido")


# --- Fondo vertical ---

func _layer_screen_y(background: World1Background, layer_name: String) -> float:
	var layer: Parallax2D = background.get_layer(layer_name)
	return (layer.get_child(0) as Node2D).get_global_transform_with_canvas().origin.y


func test_vertical_background_scrolls_in_y() -> void:
	var background := (load("res://scenes/levels/world1_background.tscn") as PackedScene).instantiate() as World1Background
	background.vertical = true
	add_child_autofree(background)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	camera.make_current()
	for layer: Parallax2D in background.get_layers():
		assert_gt(layer.scroll_scale.y, 0.0, "%s se mueve en Y" % layer.name)
		assert_eq(layer.repeat_size.y, 720.0, "%s se repite en vertical" % layer.name)
	camera.global_position = Vector2(640.0, 360.0)
	await wait_process_frames(3)
	var before: float = _layer_screen_y(background, "Resplandor")
	var far_before: float = _layer_screen_y(background, "Cielo")
	camera.global_position = Vector2(640.0, 560.0)
	await wait_process_frames(3)
	var moved: float = before - _layer_screen_y(background, "Resplandor")
	var far_moved: float = far_before - _layer_screen_y(background, "Cielo")
	var near_scale: float = background.get_layer("Resplandor").scroll_scale.y
	assert_almost_eq(moved, 200.0 * near_scale, 1.0, "La capa cercana sube al subir la camara")
	assert_gt(moved, far_moved, "La lejana se mueve menos")


func test_horizontal_background_stays_fixed_in_y() -> void:
	var background := (load("res://scenes/levels/world1_background.tscn") as PackedScene).instantiate() as World1Background
	add_child_autofree(background)
	for layer: Parallax2D in background.get_layers():
		assert_eq(layer.scroll_scale.y, 0.0, "1-1: %s fija en Y" % layer.name)
		assert_eq(layer.repeat_size.y, 0.0)


# --- Regresion: la camara del 1-1 no cambia ---

func test_level_1_1_keeps_the_simple_follow_camera() -> void:
	await _load(LEVEL_1_1_SCENE)
	assert_eq(_isak.camera_mode, Isak.CAMERA_SIMPLE)
	assert_null(_tower(), "Sin camara de torre")
	var camera := _isak.get_camera()
	assert_false(camera.top_level, "Hija de Isak")
	assert_true(camera.position_smoothing_enabled)
	assert_eq(camera.position_smoothing_speed, 8.0)
	assert_eq(camera.position, Vector2(0.0, -64.0))
	assert_eq(camera.process_callback, Camera2D.CAMERA2D_PROCESS_PHYSICS)
	var background := _level.get_node(^"Background") as World1Background
	assert_false(background.vertical)
	# Saltar: la camara sigue pegada a Isak (0, -64) como siempre.
	_sim.settle()
	_sim.press_jump()
	for i: int in 12:
		_sim.step()
		assert_eq(camera.global_position, _isak.global_position + Vector2(0.0, -64.0), "Sigue a Isak en Y")
