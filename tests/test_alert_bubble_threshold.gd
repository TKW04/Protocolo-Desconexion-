# Pruebas del umbral de pop de la Burbuja de alerta aturdida (C7): con la fisica
# real de Isak (sin tocarla) se simulan los saltos y caidas tipicos sobre una
# Burbuja aturdida en el suelo y se comprueba que los saltos normales la pisan
# (plataforma) y las caidas desde una repisa muy alta la revientan, con margen
# de al menos el 10 % entre la velocidad de aterrizaje y el umbral.
# Isak y la Burbuja avanzan paso a paso con delta fijo (sin frames reales).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const DT: float = 1.0 / 60.0
const TILE: float = 64.0
const BUBBLE_X: float = 400.0
## Margen minimo entre la velocidad de aterrizaje y el umbral.
const MARGIN: float = 0.10
const FAR: Vector2 = Vector2(-2000.0, 0.0)

var _sim: IsakSim
var _isak: Isak
var _world: Node2D


func before_each() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = FAR
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

## Bloque solido con la cara de arriba en `top_y` que acaba en `right_x`.
func _block(right_x: float, top_y: float, width: float = 256.0) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, -top_y)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(right_x - width * 0.5, top_y * 0.5)
	_world.add_child(body)


func _bubble() -> AlertBubble:
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.position = Vector2(BUBBLE_X, 0.0)
	b.patrol_range_px = 0.0
	b.free_on_pop = false
	b.target = _isak
	_world.add_child(b)
	b.set_physics_process(false)
	return b


func _step(b: AlertBubble) -> void:
	_sim.step()
	b.step(DT)


## Lleva a Isak hacia el centro de la Burbuja en el aire (control analogico).
func _steer() -> void:
	_sim.input.move_axis = clampf((BUBBLE_X - _isak.global_position.x) / 24.0, -1.0, 1.0)


## Simula un caso y devuelve {vy: velocidad vertical de aterrizaje, popped, landed}.
## kind: "jump" (salto completo desde el suelo o desde un bloque de `height` px),
## "run" (salto corriendo desde el suelo) o "drop" (sale andando de una repisa
## de `height` px). La Burbuja se aturde justo antes de que Isak despegue.
## Con `measure` el umbral es infinito: nunca revienta y `vy` es la velocidad
## con la que la Burbuja ve llegar a Isak (la de su ultimo paso en el aire).
func _simulate(kind: String, height: float = 0.0, measure: bool = false) -> Dictionary:
	var b: AlertBubble = _bubble()
	_step(b)
	var start_x: float = BUBBLE_X - 110.0
	if kind == "run":
		start_x = BUBBLE_X - 400.0
	elif kind == "drop":
		_block(BUBBLE_X - 48.0, -height)
		start_x = BUBBLE_X - 140.0
	elif height > 0.0:
		_block(BUBBLE_X - 64.0, -height)
	_isak.global_position = Vector2(start_x, -height)
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	b.stun()
	if measure:
		b.pop_speed_threshold_px_s = INF
	var top: float = b.get_platform_top_y()
	var result := {"vy": 0.0, "popped": false, "landed": false}
	if kind == "run":
		_sim.input.run_held = true
		_sim.input.move_axis = 1.0
		while _isak.global_position.x < BUBBLE_X - 230.0:
			_step(b)
		_sim.input.jump_pressed = true
		_sim.input.jump_held = true
	elif kind == "jump":
		_sim.input.jump_pressed = true
		_sim.input.jump_held = true
	else:
		_sim.input.move_axis = 1.0
	var left_ground: bool = false
	for i: int in roundi(3.0 / DT):
		if left_ground or kind != "drop":
			_steer()
		var vy_before: float = _isak.velocity.y
		_step(b)
		if not _isak.is_on_floor():
			left_ground = true
		result.vy = maxf(result.vy, vy_before)
		if b.get_state() == AlertBubble.STATE_POPPED:
			result.popped = true
			break
		if left_ground and _isak.is_on_floor():
			result.landed = absf(_isak.global_position.y - top) < 2.0
			break
	_sim.input.clear_just_pressed()
	_sim.input.jump_held = false
	_sim.input.run_held = false
	_sim.input.move_axis = 0.0
	return result


func _cases() -> Array[Dictionary]:
	return [
		{"name": "a) salto completo desde el suelo", "kind": "jump", "h": 0.0, "pop": false},
		{"name": "b) salto desde un escalon de 1 tile", "kind": "jump", "h": TILE, "pop": false},
		{"name": "c) salto corriendo", "kind": "run", "h": 0.0, "pop": false},
		{"name": "d) caida desde repisa de 2 tiles", "kind": "drop", "h": 2.0 * TILE, "pop": false},
		{"name": "e) caida desde repisa de 3 tiles", "kind": "drop", "h": 3.0 * TILE, "pop": false},
		{"name": "f) caida desde repisa de 4 tiles", "kind": "drop", "h": 4.0 * TILE, "pop": false},
		{"name": "g) caida desde repisa de 6 tiles", "kind": "drop", "h": 6.0 * TILE, "pop": true},
		{"name": "h) caida desde repisa de 7 tiles", "kind": "drop", "h": 7.0 * TILE, "pop": true},
	]


func _reset_world() -> void:
	for n: Node in _world.get_children():
		if n is AlertBubble or (n is StaticBody2D and n.get_index() > 0):
			n.free()
	_isak.global_position = FAR
	_isak.velocity = Vector2.ZERO
	_sim.settle()


func _threshold() -> float:
	var b: AlertBubble = _bubble()
	var value: float = b.pop_speed_threshold_px_s
	b.free()
	return value


# --- Pruebas ---

func test_threshold_from_data() -> void:
	assert_almost_eq(_threshold(), 1150.0, 0.001, "Umbral de data/enemies/alert_bubble.json")


## Velocidad de aterrizaje real de cada caso (sin reventar) frente al umbral:
## los saltos y caidas cortas quedan al menos un 10 % por debajo y las caidas
## desde repisas muy altas al menos un 10 % por encima.
func test_landing_speeds_keep_ten_percent_margin() -> void:
	var threshold: float = _threshold()
	for c: Dictionary in _cases():
		var r: Dictionary = _simulate(c.kind, c.h, true)
		gut.p("%s: aterriza a %.0f px/s" % [c.name, r.vy])
		assert_true(r.landed, "%s: llega a la plataforma" % c.name)
		if c.pop:
			assert_gte(r.vy, threshold * (1.0 + MARGIN), "%s (%.0f px/s): >= 10 %% sobre el umbral" % [c.name, r.vy])
		else:
			assert_lte(r.vy * (1.0 + MARGIN), threshold, "%s (%.0f px/s): >= 10 %% bajo el umbral" % [c.name, r.vy])
		_reset_world()


## Con el umbral real: los saltos la pisan (se queda de pie encima) y las caidas
## desde repisas muy altas la revientan; nunca hay dano.
func test_jumps_step_and_high_drops_pop() -> void:
	for c: Dictionary in _cases():
		var r: Dictionary = _simulate(c.kind, c.h)
		assert_eq(r.popped, c.pop, "%s: %s" % [c.name, "revienta" if c.pop else "la pisa"])
		if not c.pop:
			assert_true(r.landed, "%s: de pie sobre la Burbuja" % c.name)
		assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, 0.001, "%s: sin dano" % c.name)
		_reset_world()
