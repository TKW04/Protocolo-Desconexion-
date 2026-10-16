# Escena generada del nivel 1-1 (scenes/levels/1-1.tscn, tools/build_level.py):
# estructura (Isak, Burbuja, puntos de atencion, objetos del JSON con sus ids,
# camara, Debug bloqueado) y pasajes criticos simulados con la fisica real de
# Isak sobre la escena real (patron de tests/support/isak_sim.gd): salto del
# foso del Tramo 1, escalon de 2 tiles, plataforma de una via, puente con y sin
# pulso, el pop-up que bloquea hasta el pulso, el nicho del Pulso amplio (con su
# unico power bank), las Burbujas en abierto (escalon aturdidas; la caida ya no
# las mata) y la sala del laser (rediseno 2026-10-15: dos receptores en escalera,
# pop-up en alto y el objeto del laser en un tunel bajo que no se puede saltar).
# Desde el encuentro con Eco (2026-10-16) el 1-1 empieza sin pulso: las pruebas
# empiezan como una partida que ya paso por el encuentro (EcoProgress), salvo la
# del pulso al empezar.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
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


## Las lineas importantes de Eco (laser) pausarian el nivel
## esperando al jugador; aqui nadie confirma (se prueba en test_eco_text_box.gd).
func before_all() -> void:
	EcoTextBox.pause_important = false
	_data = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	_tile = float(_data["tile_size"])


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_debug_was = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.reset_progress()
	EcoProgress.meet_eco_with_pulse()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	GameState.reset_progress()
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
	var banks: Array[Node] = _find(func(n: Node) -> bool: return n is PowerBankPickup)
	assert_eq(banks.size(), 1, "Un solo power bank en el 1-1: el del nicho del Pulso amplio (2026-10-15)")
	assert_eq(String(banks[0].get(&"object_id")), "power_bank_pulso_amplio")
	var popup := _object("popup_1") as PopupBlocker
	assert_eq(popup.close_button_position, Vector2(4, 192), "close_button_px -> Vector2")
	assert_eq((_object("terminal_salida") as ExitTerminal).level_id, "1-1")
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
	# Partida nueva: el 1-1 empieza sin pulso (lo da Eco en el encuentro).
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	await _load(false)
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Debug bloqueado en el 1-1")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Sin pulso al empezar el 1-1")
	assert_false(DebugMode.is_active())
	assert_eq(GameState.current_level, &"1-1")
	_level.free()
	_level = null
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Se restaura al salir")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Se restaura al salir")
	# Con el pulso ya obtenido (tras el encuentro) se tiene dentro y fuera.
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, false)
	EcoProgress.meet_eco_with_pulse()
	await _load(false)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Pulso obtenido: disponible en el 1-1")
	_level.free()
	_level = null
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Y sigue al salir")


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
	var low: Dictionary = (_data["enemies"] as Array).filter(func(e: Dictionary) -> bool: return e["id"] == "burbuja_1")[0]
	var center: float = (float(low["x"]) + 0.5) * _tile
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


# --- Secreto del Pulso amplio (2026-10-15) ---

## Isak pegado a la cara derecha del pop-up popup_lejano (encima del techo de 3a,
## columna 129, fila 4), mirando a la izquierda, lanza el pulso. Devuelve el pop-up.
func _pulse_at_far_popup() -> PopupBlocker:
	await _load(true)
	var popup := _object("popup_lejano") as PopupBlocker
	_place(129, 4)
	_sim.input.move_axis = -1.0
	_sim.step(_sim.steps_for(1.0))
	assert_almost_eq(_isak.global_position.x, popup.global_position.x + popup.get_size_px().x
			+ _isak.hitbox_size.x * 0.5, 1.0, "Pegado al pop-up")
	assert_eq(_isak.facing, -1.0, "Mira al pop-up")
	_sim.input.move_axis = 0.0
	_sim.settle()
	_pulse()
	return popup


func test_far_popup_out_of_base_pulse_reach() -> void:
	var popup: PopupBlocker = await _pulse_at_far_popup()
	assert_almost_eq(_isak.abilities.pulse_radius_px, 96.0, 0.001)
	assert_eq(popup.get_state(), PopupBlocker.State.OPEN, "Con el pulso base el boton queda fuera (104 px)")


func test_far_popup_closes_with_wide_pulse() -> void:
	var saved_path: String = GameState.save_path
	GameState.use_save_path("user://test_level_1_1_save.json", true)
	EcoProgress.meet_eco_with_pulse()
	GameState.attention_points = 25
	assert_eq(GameState.purchase_upgrade(&"wide_pulse"), GameState.PurchaseResult.OK)
	var popup: PopupBlocker = await _pulse_at_far_popup()
	assert_almost_eq(_isak.abilities.pulse_radius_px, 112.0, 0.001)
	assert_ne(popup.get_state(), PopupBlocker.State.OPEN, "Con Pulso amplio el pulso llega al boton")
	# Detras, el unico power bank (vacio) del 1-1.
	await wait_physics_frames(60)
	var bank := _object("power_bank_pulso_amplio") as PowerBankPickup
	var banks_before: int = GameState.empty_power_banks
	_sim.input.move_axis = -1.0
	_sim.step_until(func() -> bool: return _isak.global_position.x <= bank.global_position.x + _tile * 0.5,
			_sim.steps_for(3.0))
	_sim.input.move_axis = 0.0
	await wait_physics_frames(3)
	assert_true(not is_instance_valid(bank) or bank.is_taken(), "Con el pop-up cerrado se llega al power bank")
	assert_true(GameState.is_pickup_collected(&"1-1", &"power_bank_pulso_amplio"), "Queda recogido en el guardado")
	assert_eq(GameState.empty_power_banks, banks_before + 1, "Suma un power bank vacio")
	GameState.reset_progress()
	SaveFile.delete("user://test_level_1_1_save.json")
	GameState.save_path = saved_path


# --- Burbujas en abierto con su repisa (2026-10-15) ---

## Burbujas en abierto con repisa ("open" en el JSON; 3c, rediseno 2026-10-15: la repisa
## guarda un punto de la ruta y se sube con la Burbuja aturdida de escalon) -> [columna del
## borde de su repisa de una via que da a la Burbuja, fila donde Isak se queda de pie en ella].
const OPEN_BUBBLE_LEDGES: Dictionary = {
	"burbuja_3": [184, 6],
	"burbuja_4": [188, 6],
}


## Avanza Isak y la Burbuja (sin su _physics_process) un paso.
func _step_with(bubble: AlertBubble) -> void:
	_sim.step()
	bubble.step(DT)


## Salta (mantenido) dirigiendo a Isak en el aire hacia `target_x`; para al aterrizar o si
## la Burbuja revienta. Devuelve los pasos dados.
func _jump_towards(bubble: AlertBubble, target_x: float, run: bool = false) -> int:
	_sim.input.run_held = run
	_sim.input.jump_pressed = true
	_sim.input.jump_held = true
	var left_ground: bool = false
	var steps: int = 0
	for i: int in roundi(2.0 / DT):
		_sim.input.move_axis = clampf((target_x - _isak.global_position.x) / 24.0, -1.0, 1.0)
		_step_with(bubble)
		steps += 1
		if not _isak.is_on_floor():
			left_ground = true
		if bubble.get_state() == AlertBubble.STATE_POPPED or (left_ground and _isak.is_on_floor()):
			break
	_sim.input.jump_held = false
	_sim.input.run_held = false
	_sim.input.move_axis = 0.0
	_sim.input.clear_just_pressed()
	return steps


func test_open_bubbles_have_no_low_ceiling() -> void:
	var opened: Array = []
	for enemy: Dictionary in _data["enemies"]:
		if bool(enemy.get("open", false)):
			opened.append(enemy["id"])
			var col: int = int(enemy["x"])
			for row: int in int(enemy["y"]):
				assert_ne((_data["grid"][row] as String)[col], "#", "%s sin techo encima" % enemy["id"])
		else:
			assert_eq(enemy["id"], "burbuja_1", "Solo la Burbuja de 3a va bajo techo bajo")
	assert_eq(opened.size(), (_data["enemies"] as Array).size() - 1, "Todas en abierto salvo burbuja_1")
	for id: String in OPEN_BUBBLE_LEDGES:
		assert_has(opened, id, "%s en abierto" % id)


## Aturdida desde el suelo, Isak la usa de escalon para subir a la repisa (3 tiles sobre
## su suelo) y salta desde la repisa sobre ella. Desde el 2026-10-15 la caida ya no la revienta
## (solo muere por vida, con el laser): aterriza encima, sin dano y dentro del aturdimiento.
## El rediseno del 1-1 para el laser es la fase siguiente.
func test_open_bubbles_step_to_ledge_and_land() -> void:
	await _load(true)
	for id: String in OPEN_BUBBLE_LEDGES:
		var bubble := _level.get_node(NodePath("Enemies/" + id)) as AlertBubble
		bubble.set_physics_process(false)
		# Con el paso manual el espacio fisico no se actualiza: se le da a Isak como objetivo
		# (en el juego lo detecta al acercarse a aturdirla, como en test_alert_bubble_threshold.gd).
		bubble.target = _isak
		bubble.free_on_pop = false
		var ledge: Array = OPEN_BUBBLE_LEDGES[id]
		var edge_x: float = float(ledge[0]) * _tile
		var away: float = -1.0 if bubble.global_position.x < edge_x else 1.0
		if away > 0.0:
			edge_x += _tile
		var bx: float = bubble.global_position.x
		var floor_row: int = roundi(bubble.global_position.y / _tile) - 1
		# Isak en el suelo, al otro lado de la Burbuja, y la aturde.
		_place(bx / _tile - 0.5 + away * 1.5, floor_row)
		bubble.stun()
		var steps: int = _jump_towards(bubble, bx)
		assert_almost_eq(_isak.global_position.y, bubble.get_platform_top_y(), 2.0, "%s: de pie encima (escalon)" % id)
		assert_eq(bubble.get_state(), AlertBubble.STATE_STUNNED, "%s: pisarla no la revienta" % id)
		steps += _jump_towards(bubble, edge_x - away * _tile)
		assert_almost_eq(_isak.global_position.y, _floor_y(int(ledge[1])), 2.0, "%s: sube a la repisa desde la Burbuja" % id)
		# Hasta el borde de la repisa y salto hacia la Burbuja.
		_sim.input.move_axis = away * -1.0
		while (edge_x - _isak.global_position.x) * -away > _isak.hitbox_size.x * 0.5 and steps < 600:
			_step_with(bubble)
			steps += 1
		steps += _jump_towards(bubble, bx)
		assert_true(bubble.is_stunned(), "%s: saltando desde la repisa ya no revienta (2026-10-15)" % id)
		gut.p("%s: escalon, repisa y vuelta encima en %.2f s (aturdimiento %.2f s)" % [id, steps * DT, bubble.stun_duration_s])
		assert_lt(steps * DT, bubble.stun_duration_s, "%s: cabe en el aturdimiento" % id)
		assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "%s: sin dano" % id)


# --- Sala del laser (rediseno 2026-10-15) ---

func test_laser_room_objects() -> void:
	await _load(false)
	var pickup := _object("laser_1_1") as AbilityPickup
	assert_not_null(pickup)
	assert_eq(pickup.ability, GameState.ABILITY_LASER)
	for id: String in ["cargador_1", "cargador_2"]:
		var charger := _object(id) as Charger
		assert_not_null(charger, id)
		assert_almost_eq(charger.amount, 50.0, 0.001)
		assert_true(charger.reusable, id)
		assert_almost_eq(charger.cooldown_s, 20.0, 0.001)
	var bubble := _level.get_node(^"Enemies/burbuja_cierre") as AlertBubble
	assert_almost_eq(bubble.get_max_health(), 3.0, 0.001, "Burbuja del Cierre con vida 3")
	assert_almost_eq((_level.get_node(^"Enemies/burbuja_3") as AlertBubble).get_max_health(), 2.0, 0.001)


## La linea del primer disparo (eco_laser_disparo) se elimino (2026-10-16, §4.1): se funde con
## la historia del laser y con la ayuda Q de la Burbuja. Disparar no hace hablar a Eco.
func test_first_laser_shot_has_no_eco_line() -> void:
	await _load(false)
	assert_null(_level.get_node_or_null(^"Objects/eco_laser_disparo"))
	watch_signals(EventBus)
	EventBus.laser_fired.emit(null)
	assert_signal_emit_count(EventBus, "eco_line_requested", 0)


## Isak en el puente en alto (puente_laser_2) cierra el pop-up de la sala con el pulso y,
## andando por el tunel, recoge el laser. En el tunel (2 tiles) un salto no pasa por encima.
func test_laser_room_popup_and_pickup() -> void:
	var saved_path: String = GameState.save_path
	GameState.use_save_path("user://test_level_1_1_save.json", true)
	EcoProgress.meet_eco_with_pulse()
	await _load(true)
	var receiver := _object("receiver_164_5") as PulseReceiver
	var bridge := _object("puente_laser_2") as PulseBridge
	var popup := _object("popup_laser") as PopupBlocker
	receiver.activate()
	for i: int in _sim.steps_for(2.0):
		bridge.advance(DT)
		if bridge.is_extended():
			break
	assert_true(bridge.is_extended())
	await wait_physics_frames(2)
	_place(166, 5)
	_sim.input.move_axis = 1.0
	_sim.step(_sim.steps_for(1.0))
	assert_almost_eq(_isak.global_position.y, _floor_y(5), 1.0, "De pie en el puente en alto")
	assert_almost_eq(_isak.global_position.x, popup.global_position.x - _isak.hitbox_size.x * 0.5, 1.0,
			"El pop-up cerrado es solido")
	_sim.input.move_axis = 0.0
	_sim.settle()
	_pulse()
	assert_ne(popup.get_state(), PopupBlocker.State.OPEN, "El pulso desde el puente alcanza el boton")
	for i: int in _sim.steps_for(3.0):
		popup.advance(DT)
		if popup.is_closed():
			break
	await wait_physics_frames(2)
	# Corre y salta por el tunel: la cabeza choca con el techo y toca el objeto igual.
	var pickup := _object("laser_1_1") as AbilityPickup
	# El tunel empieza tras el pop-up (3 tiles de ancho).
	var tunnel_x: float = popup.global_position.x + popup.get_size_px().x + _isak.hitbox_size.x * 0.5
	var max_rise: float = 0.0
	_sim.input.move_axis = 1.0
	_sim.input.run_held = true
	for i: int in _sim.steps_for(3.0):
		var in_tunnel: bool = _isak.global_position.x > tunnel_x
		if _isak.is_on_floor() and in_tunnel:
			_sim.input.jump_pressed = true
			_sim.input.jump_held = true
		_sim.step()
		_sim.input.clear_just_pressed()
		if in_tunnel:
			max_rise = maxf(max_rise, _floor_y(5) - _isak.global_position.y)
		if _isak.global_position.x >= pickup.global_position.x + _tile * 0.5:
			break
	_sim.input.run_held = false
	_sim.input.jump_held = false
	_sim.input.move_axis = 0.0
	_sim.settle()
	assert_almost_eq(_isak.global_position.x, pickup.global_position.x + _tile * 0.5, _tile * 0.5,
			"Sobre la celda del laser")
	await wait_physics_frames(3)
	assert_lt(max_rise, 64.0, "El techo bajo del tunel corta el salto")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_LASER), "Recoge el laser")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER))
	GameState.reset_progress()
	SaveFile.delete("user://test_level_1_1_save.json")
	GameState.save_path = saved_path


# --- Objetos de historia de un solo uso (2026-10-16, fallo encontrado jugando) ---

## Con el laser ya obtenido (guardado y de vuelta al 1-1 desde el hub), al pasar
## por la sala del laser no hay chip, ni Q, ni aviso, ni la linea eco_laser:
## Isak pasa de largo.
func test_laser_already_obtained_skips_pickup_and_its_story() -> void:
	GameState.obtain_ability(GameState.ABILITY_LASER)
	GameState.mark_notice_seen(GameState.ABILITY_LASER)
	await _load(true)
	watch_signals(EventBus)
	var pickup: Node = _level.get_node_or_null(^"Objects/laser_1_1")
	assert_true(pickup == null or pickup.is_queued_for_deletion(), "El chip no aparece")
	await wait_physics_frames(1)
	assert_null(_level.get_node_or_null(^"Objects/laser_1_1"), "Liberado")
	var line := _object("eco_laser") as EcoLine
	assert_true(line.is_skipped(), "La linea de historia del laser no sale")
	for col: float in [172.0, 173.0, 174.0, 175.0]:
		_place(col, 5)
		await wait_physics_frames(3)
	assert_eq(line.get_fired_count(), 0)
	assert_signal_emit_count(EventBus, "eco_line_requested", 0, "Sin linea de Eco ni aviso")
	assert_signal_emit_count(EventBus, "ability_obtained", 0)
	for node: Node in get_tree().get_nodes_in_group(HelpCatalog.TARGET_GROUP):
		if _level.is_ancestor_of(node) and HelpCatalog.help_id_of(node) == &"ability_pickup":
			assert_false(HelpCatalog.is_help_live(node), "Sin Q del chip")


## Sin el laser (partida nueva) el chip esta y la linea sale una vez.
func test_without_laser_the_pickup_and_its_story_are_there() -> void:
	await _load(true)
	var pickup := _object("laser_1_1") as AbilityPickup
	assert_not_null(pickup)
	assert_true(pickup.visible and HelpCatalog.is_help_live(pickup))
	var line := _object("eco_laser") as EcoLine
	assert_false(line.is_skipped())
	_place(174, 5)
	await wait_physics_frames(3)
	assert_eq(line.get_fired_count(), 1, "La historia del laser sale")


## Tras un game over sin el laser en la copia (rollback), vuelve a aparecer.
func test_laser_pickup_returns_after_a_rollback_without_it() -> void:
	var saved_path: String = GameState.save_path
	GameState.use_save_path("user://test_level_1_1_rollback.json", true)
	EcoProgress.meet_eco_with_pulse()
	assert_true(GameState.save_game(), "Copia sin el laser")
	GameState.obtain_ability(GameState.ABILITY_LASER)
	GameState.apply_rollback()
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_LASER), "El rollback se lo quita")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_LASER))
	await _load(true)
	var pickup := _object("laser_1_1") as AbilityPickup
	assert_not_null(pickup, "Vuelve el chip")
	assert_true(HelpCatalog.is_help_live(pickup))
	assert_false((_object("eco_laser") as EcoLine).is_skipped(), "Y su historia")
	GameState.reset_progress()
	SaveFile.delete("user://test_level_1_1_rollback.json")
	GameState.save_path = saved_path


## Relectura (2026-10-16, fallo «la Q apagada a veces no sale»): contra el
## escalon de la columna 71 la velocity pedida se queda en 30 px/s aunque Isak
## no avanza; antes eso reiniciaba el tiempo quieto en cada cuadro. Ahora cuenta
## el movimiento real.
func test_reread_still_time_counts_when_pushing_against_a_step() -> void:
	await _load(true)
	var help := _level.get_node(^"Help") as HelpSystem
	help.set_process(false)
	_place(70.75, 9)
	_sim.input.move_axis = 1.0
	var pushing: bool = false
	for i: int in _sim.steps_for(1.0):
		_sim.step()
		help.update_still(DT)
		if absf(_isak.velocity.x) > HelpCatalog.shared().reread_still_speed():
			pushing = true
	_sim.input.move_axis = 0.0
	assert_true(pushing, "La velocity pedida sigue empujando el escalon")
	assert_lt(absf(_isak.get_real_velocity().x), 1.0, "Pero Isak no avanza")
	assert_gt(help.get_still_s(), HelpCatalog.shared().reread_still_s(), "Cuenta como quieto")
