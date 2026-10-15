# Techo bajo del Tramo 3 del 1-1 (decision del usuario 2026-10-14: obligar a usar
# el pulso). Se construye la geometria REAL de data/levels/1-1.json (columnas
# 66-102) con la Burbuja de la lista `enemies` (rango y velocidad del nivel) y se
# simula con la fisica real de Isak, paso a paso con delta fijo:
# - sin aturdirla, ningun salto (corriendo, desde cualquier punto) pasa por
#   encima: el techo corta el salto y la Burbuja le hace dano;
# - bajo el techo los pies de Isak no suben mas de 48 px (la Burbuja mide 76);
# - aturdida con el pulso, Isak la cruza de lado andando y sale del techo sin dano.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const LEVEL_PATH: String = "res://data/levels/1-1.json"
const DT: float = 1.0 / 60.0
const COL_FROM: int = 66
const COL_TO: int = 102
## Isak empieza aqui (columna 74, antes de los escalones del techo).
const START_COL: float = 74.0
## Isak "ha pasado" la Burbuja cuando su hitbox queda entera a su derecha.
const PASS_MARGIN: float = 32.0 + 16.0
const MAX_ATTEMPT_S: float = 6.0

var _level: Dictionary
var _tile: float
var _floor_y: float
var _world: Node2D
var _sim: IsakSim
var _isak: Isak
var _bubble: AlertBubble
var _pulse_was_unlocked: bool = false


func before_all() -> void:
	_level = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	_tile = float(_level["tile_size"])


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	var enemy: Dictionary = _level["enemies"][0]
	_floor_y = (float(enemy["y"]) + 1.0) * _tile
	_world = Node2D.new()
	_world.add_child(_build_tiles())
	add_child_autofree(_world)
	_sim = IsakSim.new(DT)
	_sim.attach(ISAK_SCENE.instantiate() as Isak)
	_isak = _sim.isak
	_world.add_child(_isak)
	_sim.take_manual_control()
	_isak.global_position = Vector2(START_COL * _tile, _floor_y)
	await wait_physics_frames(2)
	_sim.settle()


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

## Un StaticBody2D (capa world) con un rectangulo por tramo horizontal de '#'.
func _build_tiles() -> StaticBody2D:
	var body := StaticBody2D.new()
	var grid: Array = _level["grid"]
	for r: int in grid.size():
		var row: String = grid[r]
		var c: int = COL_FROM
		while c <= COL_TO:
			if row[c] != "#":
				c += 1
				continue
			var end: int = c
			while end + 1 <= COL_TO and row[end + 1] == "#":
				end += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((end - c + 1) * _tile, _tile)
			shape.shape = rect
			shape.position = Vector2(c * _tile, r * _tile) + rect.size * 0.5
			body.add_child(shape)
			c = end + 1
	return body


## La Burbuja del nivel (posicion de su celda, pies abajo-centro, params del JSON).
func _spawn_bubble() -> AlertBubble:
	var enemy: Dictionary = _level["enemies"][0]
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.position = Vector2((float(enemy["x"]) + 0.5) * _tile, _floor_y)
	b.patrol_range_px = float(enemy["params"]["patrol_range_px"])
	b.target = _isak
	b.free_on_pop = false
	_world.add_child(b)
	b.set_physics_process(false)
	b.speed_px_s = float(enemy["params"]["patrol_speed_px_s"])
	return b


func _step() -> void:
	_sim.step()
	if _bubble != null:
		_bubble.step(DT)


func _was_hit() -> bool:
	return GameState.sync_rate < GameState.SYNC_RATE_MAX


func _reset_isak() -> void:
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	_sim.input.jump_held = false
	_sim.input.clear_just_pressed()
	_isak.global_position = Vector2(START_COL * _tile, _floor_y)
	_isak.velocity = Vector2.ZERO
	_isak.change_state(PlayerState.IDLE)
	_sim.settle()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


## Columnas con el techo de 2 tiles (hueco de 2 sobre el suelo).
func _low_ceiling_range_px() -> Vector2:
	var grid: Array = _level["grid"]
	var row: int = int(_floor_y / _tile) - 3
	var first: int = -1
	var last: int = -1
	for c: int in range(COL_FROM, COL_TO + 1):
		if grid[row][c] == "#" and grid[row + 1][c] == ".":
			if first < 0:
				first = c
			last = c
	return Vector2(first * _tile, (last + 1) * _tile)


# --- Pruebas ---

func test_ceiling_limits_jump_height() -> void:
	var span: Vector2 = _low_ceiling_range_px()
	assert_gt(span.y - span.x, 0.0, "Hay techo de 2 tiles en el Tramo 3")
	_isak.global_position = Vector2((span.x + span.y) * 0.5, _floor_y)
	_sim.settle()
	var min_y: float = _isak.global_position.y
	_sim.press_jump()
	for i: int in _sim.steps_for(1.2):
		_step()
		min_y = minf(min_y, _isak.global_position.y)
	var rise: float = _floor_y - min_y
	gut.p("Salto bajo el techo: los pies suben %.1f px" % rise)
	assert_lt(rise, 76.0 - 8.0, "Bajo el techo los pies no superan la Burbuja (76 px)")
	assert_almost_eq(rise, 2.0 * _tile - _isak.hitbox_size.y, 2.0, "Tope = hueco - alto de Isak")


func test_cannot_jump_over_unstunned_bubble() -> void:
	var span: Vector2 = _low_ceiling_range_px()
	var attempts: int = 0
	var passed_clean: int = 0
	# Corre hacia la Burbuja y salta en distintos puntos (antes, en los escalones
	# y bajo el techo); tambien sin saltar.
	var jump_xs: Array[float] = [-1.0]
	var x: float = (START_COL + 1.0) * _tile
	while x < span.y:
		jump_xs.append(x)
		x += 24.0
	for jump_x: float in jump_xs:
		_bubble = _spawn_bubble()
		await wait_physics_frames(1)
		_reset_isak()
		_sim.input.move_axis = 1.0
		_sim.input.run_held = true
		var jumped: bool = jump_x < 0.0
		var outcome: String = "timeout"
		for i: int in roundi(MAX_ATTEMPT_S / DT):
			if not jumped and _isak.global_position.x >= jump_x:
				_sim.input.jump_pressed = true
				_sim.input.jump_held = true
				jumped = true
			_step()
			if _was_hit():
				outcome = "hit"
				break
			if _isak.global_position.x > _bubble.global_position.x + PASS_MARGIN:
				outcome = "passed"
				break
		attempts += 1
		if outcome == "passed":
			passed_clean += 1
			gut.p("Paso sin dano saltando en x=%.0f" % jump_x)
		assert_eq(outcome, "hit", "Salto en x=%.0f: la Burbuja sin aturdir le hace dano" % jump_x)
		_bubble.free()
		_bubble = null
	gut.p("%d intentos, %d pasan sin dano" % [attempts, passed_clean])
	assert_eq(passed_clean, 0)


func test_stunned_bubble_can_be_crossed_sideways() -> void:
	var span: Vector2 = _low_ceiling_range_px()
	_bubble = _spawn_bubble()
	await wait_physics_frames(1)
	_reset_isak()
	_sim.input.move_axis = 1.0
	var pulsed: bool = false
	var stunned_seen: bool = false
	var max_rise: float = 0.0
	for i: int in roundi(10.0 / DT):
		if not pulsed and _bubble.global_position.x - _isak.global_position.x < 140.0:
			_sim.input.pulse_pressed = true
			pulsed = true
		_step()
		stunned_seen = stunned_seen or _bubble.is_stunned()
		max_rise = maxf(max_rise, _floor_y - _isak.global_position.y)
		if _was_hit() or _isak.global_position.x > span.y + _tile:
			break
	assert_true(pulsed, "Isak dispara el pulso cerca de la Burbuja")
	assert_true(stunned_seen, "El pulso la aturde")
	assert_false(_was_hit(), "Cruza sin dano")
	assert_gt(_isak.global_position.x, span.y + _tile, "Sale del techo por la derecha")
	assert_lt(max_rise, 2.0, "La cruza de lado, por el suelo (sin subirse encima)")
	assert_gt(_isak.global_position.x, _bubble.global_position.x + PASS_MARGIN, "Queda detras de la Burbuja")
