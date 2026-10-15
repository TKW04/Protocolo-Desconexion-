# Escena generada del nivel 1-1 (scenes/levels/1-1.tscn, tools/build_level.py):
# estructura (Isak, Burbuja, puntos de atencion, objetos del JSON con sus ids,
# camara, Debug bloqueado) y pasajes criticos simulados con la fisica real de
# Isak sobre la escena real (patron de tests/support/isak_sim.gd): salto del
# foso del Tramo 1, escalon de 2 tiles, plataforma de una via, puente con y sin
# pulso, y el pop-up que bloquea hasta el pulso.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const LEVEL_PATH: String = "res://data/levels/1-1.json"
const DT: float = 1.0 / 60.0
const RUN_FRAMES: int = 300

var _data: Dictionary
var _tile: float
var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _pulse_was: bool
var _debug_was: bool


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	_tile = float(_data["tile_size"])


func before_each() -> void:
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_debug_was = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

## Carga el nivel; con `manual` Isak solo avanza con el simulador.
func _load(manual: bool) -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	if manual:
		_sim = IsakSim.new(DT)
		_sim.attach(_isak)
	add_child(_level)
	if manual:
		_sim.take_manual_control()
	await wait_physics_frames(2)


## Isak quieto de pie en la celda (col, row) del grid.
func _place(col: float, row: int) -> void:
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	_sim.input.clear_just_pressed()
	_isak.global_position = Vector2((col + 0.5) * _tile, (row + 1) * _tile)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0
	_sim.settle()


func _floor_y(row: int) -> float:
	return (row + 1) * _tile


func _collect(node: Node, out: Array[Node], check: Callable) -> void:
	if check.call(node):
		out.append(node)
	for child: Node in node.get_children():
		_collect(child, out, check)


func _find(check: Callable) -> Array[Node]:
	var out: Array[Node] = []
	_collect(_level, out, check)
	return out


func _object(id: String) -> Node:
	return _level.get_node(NodePath("Objects/" + id))


func _count_char(ch: String) -> int:
	var n: int = 0
	for row: String in _data["grid"]:
		n += row.count(ch)
	return n


func _pulse() -> void:
	_sim.input.pulse_pressed = true
	_sim.step()
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.PULSE, _sim.steps_for(1.0))


# --- Estructura ---

func test_scene_structure_matches_json() -> void:
	await _load(false)
	assert_eq(_level.level_id, "1-1")
	assert_eq(_level.level_name, String(_data["name"]))
	assert_eq(_find(func(n: Node) -> bool: return n is Isak).size(), 1, "Un Isak")
	var bubbles: Array[Node] = _find(func(n: Node) -> bool: return n is AlertBubble)
	assert_eq(bubbles.size(), (_data["enemies"] as Array).size(), "Una Burbuja por enemigo del JSON")
	for enemy: Dictionary in _data["enemies"]:
		var bubble := _level.get_node(NodePath("Enemies/" + String(enemy["id"]))) as AlertBubble
		assert_not_null(bubble, String(enemy["id"]))
		assert_almost_eq(bubble.patrol_range_px, float(enemy["params"]["patrol_range_px"]), 0.001)
		assert_almost_eq(bubble.speed_px_s, float(enemy["params"]["patrol_speed_px_s"]), 0.001)
	var points: Array[Node] = _find(func(n: Node) -> bool: return n is AttentionPoint)
	assert_eq(points.size(), _count_char("o"), "Un punto de atencion por cada 'o'")
	# Objetos del JSON con sus ids y params.
	for obj: Dictionary in _data["objects"]:
		var params: Dictionary = obj["params"]
		var node: Node
		if params.has("id"):
			node = _object(String(params["id"]))
			assert_eq(String(node.get(&"object_id")), String(params["id"]), "id de %s" % obj["type"])
		else:
			node = _object("%s_%d_%d" % [obj["type"], obj["x"], obj["y"]])
		assert_not_null(node, "Objeto %s" % obj["type"])
		assert_eq((node as Node2D).position, Vector2(float(obj["x"]), float(obj["y"])) * _tile,
				"Posicion de %s" % obj["type"])
	assert_eq((_object("receiver_56_9") as PulseReceiver).target_id, &"puente_1")
	assert_eq(_find(func(n: Node) -> bool: return n is PowerBankPickup).size(), 3, "Un power bank por secreto")
	var popup := _object("popup_1") as PopupBlocker
	assert_eq(popup.close_button_position, Vector2(4, 192), "close_button_px -> Vector2")
	assert_eq((_object("puerta_salida") as ExitDoor).level_id, "1-1")
	assert_eq((_object("glitch_wall_298_8") as GlitchWall).solid_neighbors, 7)
	# Checkpoint minimo.
	var checkpoints: Array[Node] = get_tree().get_nodes_in_group(Checkpoint.GROUP)
	assert_eq(checkpoints.size(), 1)
	var cp := checkpoints[0] as Checkpoint
	assert_eq(cp.checkpoint_id, &"sync_1")
	assert_eq(cp.global_position, Vector2(150.5 * _tile, _floor_y(9)))
	# Tiles: uno por cada '#' y '-'.
	var tiles := _level.get_node(^"Tiles") as TileMapLayer
	assert_eq(tiles.get_used_cells().size(), _count_char("#") + _count_char("-"))
	assert_eq(tiles.tile_set.resource_path, "res://assets/tilesets/mundo1.tres")
	# HUD y cuadro de Eco.
	assert_not_null(_level.get_node_or_null(^"Hud"))
	assert_not_null(_level.get_node_or_null(^"EcoTextBox"))
	assert_not_null(_level.get_node_or_null(^"Background"))


func test_camera_limits_equal_level_size() -> void:
	await _load(false)
	var camera := _isak.get_node(^"Camera2D") as Camera2D
	var cols: int = String(_data["grid"][0]).length()
	var rows: int = (_data["grid"] as Array).size()
	assert_eq(camera.limit_left, 0)
	assert_eq(camera.limit_top, 0)
	assert_eq(camera.limit_right, cols * int(_tile))
	assert_eq(camera.limit_bottom, rows * int(_tile))
	assert_eq(_level.get_size_px(), Vector2i(300 * 64, 14 * 64))
	assert_true(camera.position_smoothing_enabled, "Suavizado de la camara de Isak")


func test_debug_blocked_inside_and_restored_after() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, false)
	await _load(false)
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Debug bloqueado en el 1-1")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Pulso disponible en el 1-1")
	assert_false(DebugMode.is_active())
	assert_eq(GameState.current_level, &"1-1")
	_level.free()
	_level = null
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Se restaura al salir")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Se restaura al salir")


func test_runs_300_frames_isak_lands_and_bubble_stays_under_ceiling() -> void:
	await _load(false)
	await wait_physics_frames(RUN_FRAMES)
	var start: Vector2 = Vector2(4.5 * _tile, 4.0 * _tile)
	assert_true(_isak.is_on_floor(), "Isak cae desde P al suelo")
	assert_almost_eq(_isak.global_position.y, _floor_y(9), 1.0)
	assert_almost_eq(_isak.global_position.x, start.x, 1.0)
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano")
	var bubble := _level.get_node(^"Enemies/burbuja_1") as AlertBubble
	assert_almost_eq(bubble.global_position.y, _floor_y(9), 1.0, "La Burbuja va por el suelo bajo el techo")
	var center: float = (float(_data["enemies"][0]["x"]) + 0.5) * _tile
	assert_between(bubble.global_position.x, center - bubble.patrol_range_px * 0.5 - 1.0,
			center + bubble.patrol_range_px * 0.5 + 1.0, "Dentro de su patrulla")
	assert_eq(bubble.get_state(), AlertBubble.STATE_PATROL)


# --- Pasajes criticos (fisica real) ---

func test_tramo1_pit_jump_and_pit_has_exit() -> void:
	await _load(true)
	# Salto desde el borde (columna 21) por encima del foso de 2 tiles (22-23).
	_place(19, 9)
	_sim.input.move_axis = 1.0
	_sim.step_until(func() -> bool: return _isak.global_position.x >= 22.0 * _tile - _isak.hitbox_size.x * 0.5)
	assert_true(_isak.is_on_floor())
	_sim.press_jump()
	var max_y: float = 0.0
	for i: int in _sim.steps_for(2.0):
		_sim.step()
		max_y = maxf(max_y, _isak.global_position.y)
		if _isak.is_on_floor():
			break
	assert_almost_eq(_isak.global_position.y, _floor_y(9), 1.0, "Aterriza al otro lado")
	assert_gt(_isak.global_position.x, 24.0 * _tile, "Pasa el foso")
	assert_lte(max_y, _floor_y(9) + 1.0, "No cae al foso")
	# Foso con fondo: si cae, sale saltando.
	_place(21, 9)
	_sim.input.move_axis = 1.0
	_sim.step_until(func() -> bool: return _isak.global_position.y > _floor_y(9) + 1.0)
	_sim.input.move_axis = 0.0
	_sim.settle()
	assert_almost_eq(_isak.global_position.y, _floor_y(11), 1.0, "Fondo del foso")
	_sim.input.move_axis = 1.0
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _isak.is_on_floor() and _isak.velocity.y >= 0.0, _sim.steps_for(2.0))
	assert_almost_eq(_isak.global_position.y, _floor_y(9), 1.0, "Sale del foso")


func test_two_tile_step() -> void:
	await _load(true)
	_place(30, 9)
	_sim.input.move_axis = 1.0
	_sim.step_until(func() -> bool: return _isak.global_position.x >= 31.0 * _tile)
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _isak.is_on_floor() and _isak.velocity.y >= 0.0, _sim.steps_for(2.0))
	_sim.input.move_axis = 0.0
	assert_almost_eq(_isak.global_position.y, _floor_y(7), 1.0, "Sube el escalon de 2 tiles (128 px)")
	assert_between(_isak.global_position.x, 32.0 * _tile, 36.0 * _tile)


func test_one_way_platform_from_below() -> void:
	await _load(true)
	_place(27, 9)
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _isak.is_on_floor() and _isak.velocity.y >= 0.0, _sim.steps_for(2.0))
	assert_almost_eq(_isak.global_position.y, _floor_y(7), 1.0, "Atraviesa la plataforma desde abajo y queda encima")
	assert_almost_eq(_isak.global_position.x, 27.5 * _tile, 1.0)


func test_bridge_pit_cannot_be_crossed_without_pulse() -> void:
	await _load(true)
	var bridge := _object("puente_1") as PulseBridge
	_place(53, 9)
	_sim.input.move_axis = 1.0
	_sim.input.run_held = true
	_sim.step_until(func() -> bool: return _isak.global_position.x >= 59.0 * _tile - _isak.hitbox_size.x * 0.5)
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _isak.is_on_floor() and _isak.velocity.y >= 0.0, _sim.steps_for(3.0))
	_sim.input.run_held = false
	assert_false(bridge.is_extended())
	assert_gt(_isak.global_position.y, _floor_y(9) + 1.0, "Cae al foso del puente (ni corriendo llega)")
	assert_lt(_isak.global_position.x, 65.0 * _tile)
	# Sale por la izquierda con el escalon.
	_sim.input.move_axis = -1.0
	for i: int in 6:
		_sim.press_jump()
		_sim.step_until(func() -> bool: return _isak.is_on_floor() and _isak.velocity.y >= 0.0, _sim.steps_for(2.0))
		if _isak.global_position.y <= _floor_y(9) + 1.0:
			break
	assert_almost_eq(_isak.global_position.y, _floor_y(9), 1.0, "Sale del foso por la izquierda")
	assert_lt(_isak.global_position.x, 59.0 * _tile)


func test_bridge_crossed_after_pulsing_receiver() -> void:
	await _load(true)
	var bridge := _object("puente_1") as PulseBridge
	var receiver := _object("receiver_56_9") as PulseReceiver
	_place(55, 9)
	_pulse()
	assert_true(receiver.is_active(), "El pulso activa el receptor")
	for i: int in _sim.steps_for(2.0):
		bridge.advance(DT)
		if bridge.is_extended():
			break
	assert_true(bridge.is_extended())
	await wait_physics_frames(2)
	_sim.input.move_axis = 1.0
	var max_y: float = 0.0
	for i: int in _sim.steps_for(4.0):
		_sim.step()
		max_y = maxf(max_y, _isak.global_position.y)
		if _isak.global_position.x >= 67.0 * _tile:
			break
	assert_gte(_isak.global_position.x, 67.0 * _tile, "Cruza el puente")
	assert_lte(max_y, _floor_y(9) + 1.0, "Sin caer al foso")


func test_popup_blocks_until_pulse() -> void:
	await _load(true)
	var popup := _object("popup_1") as PopupBlocker
	_place(211, 9)
	_sim.input.move_axis = 1.0
	_sim.step(_sim.steps_for(2.0))
	assert_almost_eq(_isak.global_position.x, popup.global_position.x - _isak.hitbox_size.x * 0.5, 1.0,
			"El pop-up cerrado es solido")
	_sim.input.move_axis = 0.0
	_sim.settle()
	_pulse()
	assert_ne(popup.get_state(), PopupBlocker.State.OPEN, "El pulso al boton lo cierra")
	for i: int in _sim.steps_for(3.0):
		popup.advance(DT)
		if popup.is_closed():
			break
	assert_true(popup.is_closed())
	await wait_physics_frames(2)
	_sim.input.move_axis = 1.0
	_sim.step_until(func() -> bool: return _isak.global_position.x >= 219.0 * _tile, _sim.steps_for(4.0))
	assert_gte(_isak.global_position.x, 219.0 * _tile, "Pasa tras cerrar el pop-up")
