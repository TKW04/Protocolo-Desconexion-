# Terminos y condiciones del Mundo 5 (paso 5 de docs/propuesta-mundo-5.md §8; §3.7 y
# pruebas de §7.4): puerta solida; «ACEPTAR» lo pulsa cualquier pulso que lo alcance y
# engancha una Suscripcion; «rechazar» solo con el laser (desde el suelo de enfrente:
# desde el suelo de la puerta el disparo choca con ella) o con un Filo que lo roza;
# abre sin coste; la Embestida y el Sismo no hacen nada. Usa su propia ruta de guardado.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SCENE: PackedScene = preload("res://scenes/levels/terms_gate.tscn")
const PATH: String = "user://test_terms_gate.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const ABILITIES: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DASH,
	GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.begin_attempt()
	GameState.current_level = &"5-3"
	_saved = {}
	for ability: StringName in ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.attention_points = 6
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.current_level = GameState.NO_LEVEL
	GameState.begin_attempt()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Puerta de 3 tiles en la columna `col` apoyada en el suelo (y = 0), botones por la izquierda.
func _gate(col: float = 2.0) -> TermsGate:
	var gate := SCENE.instantiate() as TermsGate
	gate.object_id = &"terminos"
	gate.position = Vector2(col * T, -3.0 * T)
	_world.add_child(gate)
	gate.set_process(false)
	return gate


func _fake_pulse(center: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


func _isak_pulse(radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = Vector2(0.0, -56.0)
	_isak.add_child(area)
	return area


## Repisa solida con la superficie en `top` (y) de `left` a `right` (x).
func _ledge(left: float, right: float, top: float) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right - left, 64.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2((left + right) * 0.5, top + 32.0)
	_world.add_child(body)


## Dispara el laser y lo hace volar hasta que acabe (como tests/test_correo_test_level.gd).
func _fire() -> LaserProjectile:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	for i: int in 40:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in 120:
		if p.is_finished():
			break
		p.step(DT)
	return p


# --- Puerta y ACEPTAR ---

func test_closed_gate_is_solid() -> void:
	var gate: TermsGate = _gate(2.0)
	await wait_physics_frames(1)
	_isak.global_position = Vector2(0.0, 0.0)
	_sim.input.move_axis = 1.0
	_sim.step(_sim.frames(1.5))
	_sim.input.move_axis = 0.0
	assert_lt(_isak.global_position.x, gate.get_door_rect().position.x, "No se cruza cerrada")
	assert_false(gate.is_open())


func test_any_pulse_reaching_accept_opens_it_and_attaches_a_subscription() -> void:
	var gate: TermsGate = _gate(4.0)
	watch_signals(gate)
	assert_false(gate.receive_pulse(_fake_pulse(Vector2(-6.0 * T, -T))), "Lejos no")
	_isak.global_position = Vector2(gate.get_accept_rect().get_center().x, 0.0)
	_isak.facing = -1.0
	assert_true(gate.receive_pulse(_isak_pulse()), "Cualquier pulso cercano, aunque mire a otro lado")
	assert_true(gate.is_open())
	assert_eq(gate.get_opened_by(), TermsGate.HOW_ACCEPT)
	assert_signal_emitted(gate, "accepted")
	var sub: Subscription = gate.get_subscription()
	assert_not_null(sub, "Engancha una Suscripcion")
	assert_true(sub.is_attached())
	assert_eq(sub.get_host(), _isak)
	assert_eq(gate.get_message(), "Al continuar aceptas términos que nadie lee")
	assert_eq(gate.get_node("Body").collision_layer, 0, "Abierta deja pasar")
	assert_false(gate.receive_pulse(_isak_pulse()), "Una vez")


func test_pulse_on_the_reject_button_does_not_reject() -> void:
	var gate: TermsGate = _gate(4.0)
	assert_false(gate.receive_pulse(_fake_pulse(gate.get_reject_rect().get_center(), 20.0)),
		"El pulso no pulsa «rechazar»")
	assert_false(gate.is_open())


# --- Rechazar ---

func test_laser_from_the_opposite_floor_rejects_for_free() -> void:
	var gate: TermsGate = _gate(4.0)
	_ledge(-3.0 * T, 1.5 * T, -2.0 * T)
	await wait_physics_frames(2)
	_isak.global_position = Vector2(T, -2.0 * T)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0
	_sim.step(10)
	assert_true(_isak.is_on_floor(), "En la repisa de enfrente")
	watch_signals(gate)
	assert_not_null(_fire(), "Dispara")
	assert_true(gate.is_open(), "El laser alcanza «rechazar»")
	assert_eq(gate.get_opened_by(), TermsGate.HOW_LASER)
	assert_signal_emitted_with_parameters(gate, "rejected", [TermsGate.HOW_LASER])
	assert_null(gate.get_subscription(), "Sin Suscripcion")
	assert_eq(GameState.attention_points, 6, "Sin coste")


func test_laser_from_the_gate_floor_hits_the_door() -> void:
	var gate: TermsGate = _gate(4.0)
	await wait_physics_frames(1)
	_isak.global_position = Vector2(T, 0.0)
	_isak.facing = 1.0
	_sim.step(5)
	var p: LaserProjectile = _fire()
	assert_not_null(p)
	assert_false(gate.is_open(), "Desde el suelo de la puerta choca con ella")
	assert_lt(p.global_position.x, gate.get_door_rect().position.x + 8.0, "El disparo se para en la puerta")


## Salta, sube `frames` pasos, se comprime y hace un Filo hacia la derecha.
func _edge_after(frames: int) -> void:
	_isak.global_position = Vector2(0.0, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.press_jump()
	_sim.step(frames)
	_sim.input.pinch_pressed = true
	_sim.step()
	assert_true(_isak.is_compressed(), "Comprimido en el aire")
	_sim.input.move_axis = 1.0
	_sim.input.dash_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.COMBO_EDGE, "Filo")
	_sim.step(_sim.frames(0.3))
	_sim.input.move_axis = 0.0


func test_edge_grazing_the_button_rejects() -> void:
	var gate: TermsGate = _gate(2.0)
	await wait_physics_frames(1)
	_edge_after(15)
	assert_true(gate.is_open(), "El Filo roza «rechazar»")
	assert_eq(gate.get_opened_by(), TermsGate.HOW_EDGE)
	assert_null(gate.get_subscription())
	assert_eq(GameState.attention_points, 6, "Sin coste")


func test_edge_below_the_button_hits_the_door() -> void:
	var gate: TermsGate = _gate(2.0)
	await wait_physics_frames(1)
	_edge_after(3)
	assert_false(gate.is_open(), "Por debajo del boton no lo roza")
	assert_lt(_isak.global_position.x, gate.get_door_rect().position.x, "Choca con la puerta")


func test_edge_wave_rect_and_other_combos() -> void:
	var gate: TermsGate = _gate(4.0)
	var wide := Rect2(-2000.0, -400.0, 4000.0, 500.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_RAM, wide, 2.0, 3.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_QUAKE, wide, 0.0, 3.0)
	GroundPoundWave.apply_to_enemies(get_tree(), wide, 1.0)
	assert_false(gate.is_open(), "Embestida, Sismo y golpe al suelo no rechazan")
	ComboWave.defeat_small(get_tree(), Rect2(gate.get_door_rect().position + Vector2(-40.0, 120.0), Vector2(32.0, 40.0)), 1.0, {})
	assert_false(gate.is_open(), "Un Filo lejos del boton no")
	ComboWave.defeat_small(get_tree(), Rect2(gate.get_reject_rect().position + Vector2(-34.0, -10.0), Vector2(32.0, 40.0)), 1.0, {})
	assert_true(gate.is_open(), "Un Filo que lo roza si")
	assert_eq(gate.get_opened_by(), TermsGate.HOW_EDGE)
