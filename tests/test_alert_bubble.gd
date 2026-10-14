# Pruebas de la Burbuja de alerta (scripts/enemies/alert_bubble.gd): patrulla,
# dano por contacto (C7: de lado y desde arriba, 10 % con la invulnerabilidad de
# 1 s de Isak), aturdimiento por el pulso solo dentro del radio, plataforma de
# una via aturdida, pop con rebote por encima del umbral y pisada suave por
# debajo (los casos de salto y caida reales estan en
# test_alert_bubble_threshold.gd), anticipacion de 6-12 cuadros a 12 fps antes de volver a danar (A8) y
# ralentizacion x0,5 del Debug sin afectar a Isak.
# Isak y la Burbuja avanzan paso a paso con delta fijo (sin frames reales).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const TEST_SCENE: PackedScene = preload("res://scenes/levels/alert_bubble_test.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const BUBBLE_X: float = 400.0
## Lejos de todo: fuera del alcance de la consulta de la Burbuja.
const FAR: Vector2 = Vector2(-2000.0, 0.0)

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"pulse": GameState.is_ability_unlocked(GameState.ABILITY_PULSE),
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"energy": GameState.debug_energy,
		"world": GameState.current_world,
	}
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = FAR
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved.pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.debug_energy = _saved.energy
	GameState.current_world = _saved.world
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

func _bubble(pos: Vector2 = Vector2(BUBBLE_X, 0.0), range_px: float = -1.0) -> AlertBubble:
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.position = pos
	b.patrol_range_px = range_px
	b.free_on_pop = false
	b.target = _isak
	_world.add_child(b)
	b.set_physics_process(false)
	return b


## Avanza Isak y luego las burbujas `count` pasos de DT.
func _step(bubbles: Array, count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for b: AlertBubble in bubbles:
			b.step(DT)


func _place_isak(feet: Vector2, vy: float = 0.0) -> void:
	_isak.global_position = feet
	_isak.velocity = Vector2(0.0, vy)


func _fake_pulse(center: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


## Pasos hasta que la burbuja llegue a `state` (o -1).
func _steps_until_state(b: AlertBubble, state: StringName, max_steps: int = 600) -> int:
	for i: int in max_steps:
		if b.get_state() == state:
			return i
		_step([b])
	return -1


# --- Deteccion por capas ---

func test_finds_isak_on_player_layer() -> void:
	assert_eq(_isak.collision_layer, AlertBubble.LAYER_PLAYER, "Isak en la capa player")
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.position = Vector2(BUBBLE_X, 0.0)
	b.patrol_range_px = 0.0
	_world.add_child(b)
	b.set_physics_process(false)
	assert_eq(b.collision_layer, AlertBubble.LAYER_ENEMY, "Burbuja en la capa enemy")
	assert_eq(b.collision_mask, AlertBubble.LAYER_WORLD, "Choca solo con el mundo, no con Isak")
	_place_isak(Vector2(BUBBLE_X - 100.0, 0.0))
	await wait_physics_frames(2)
	b.step(DT)
	assert_eq(b.target, _isak, "Encuentra a Isak con una consulta a la capa player")


# --- Patrulla ---

func test_patrols_slowly_and_turns_at_range_limit() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 256.0)
	_step([b], 30)
	assert_true(b.is_on_floor(), "Va por el suelo (A7)")
	assert_almost_eq(b.velocity.x, b.speed_px_s, EPS, "Patrulla a patrol_speed_px_s")
	assert_lt(b.speed_px_s, _isak.physics.walk_speed, "Mas lenta que Isak caminando")
	var max_x: float = b.global_position.x
	for i: int in roundi(6.0 / DT):
		_step([b])
		max_x = maxf(max_x, b.global_position.x)
	assert_almost_eq(max_x, BUBBLE_X + 128.0, 3.0, "Gira al llegar a la mitad del rango")
	assert_gt(b.global_position.x, BUBBLE_X - 128.0 - 3.0, "No pasa del otro limite")


func test_turns_at_wall_and_at_edge() -> void:
	# Repisa de 3 tiles flotando: la burbuja no se cae por los bordes.
	var ledge := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(192.0, 32.0)
	shape.shape = rect
	ledge.add_child(shape)
	ledge.position = Vector2(BUBBLE_X, -300.0 + 16.0)
	_world.add_child(ledge)
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, -300.0), 100000.0)
	var turns: int = 0
	var last_dir: float = b.get_direction()
	for i: int in roundi(8.0 / DT):
		_step([b])
		if b.get_direction() != last_dir:
			turns += 1
			last_dir = b.get_direction()
	assert_gte(turns, 2, "Gira en los dos bordes")
	assert_almost_eq(b.global_position.y, -300.0, 2.0, "Sigue sobre la repisa")
	# Pared a la derecha en el suelo.
	var wall := StaticBody2D.new()
	var wshape := CollisionShape2D.new()
	var wrect := RectangleShape2D.new()
	wrect.size = Vector2(64.0, 256.0)
	wshape.shape = wrect
	wall.add_child(wshape)
	wall.position = Vector2(BUBBLE_X + 200.0, -128.0)
	_world.add_child(wall)
	var c: AlertBubble = _bubble(Vector2(BUBBLE_X + 60.0, 0.0), 100000.0)
	var max_x: float = 0.0
	for i: int in roundi(4.0 / DT):
		_step([c])
		max_x = maxf(max_x, c.global_position.x)
	assert_lt(c.get_direction(), 0.0, "Ha girado al chocar con la pared")
	assert_lte(max_x + c.body_size.x * 0.5, BUBBLE_X + 200.0 - 32.0 + 1.0, "No atraviesa la pared")


# --- Dano por contacto (C7) ---

func test_contact_from_side_damages_ten_percent_once_per_invulnerability() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_place_isak(Vector2(BUBBLE_X - 120.0, 0.0))
	_step([b], 2)
	_sim.input.move_axis = 1.0
	var hits: Array[float] = []
	b.hit_player.connect(func(amount: float) -> void: hits.append(amount))
	for i: int in 120:
		_step([b])
		if not hits.is_empty():
			break
	_sim.input.move_axis = 0.0
	assert_eq(hits.size(), 1, "Golpe de lado")
	assert_almost_eq(GameState.sync_rate, 90.0, EPS, "Quita un 10 % de Sync Rate (A6)")
	assert_eq(_sim.state(), PlayerState.HURT)
	assert_lt(_isak.velocity.x, 0.0, "Retroceso hacia fuera de la burbuja")
	# Pegado a la burbuja durante la invulnerabilidad: sin doble golpe.
	for i: int in roundi(0.8 / DT):
		_isak.global_position = Vector2(b.global_position.x - 20.0, 0.0)
		_step([b])
	assert_eq(hits.size(), 1, "Invulnerable 1 s: no hay doble golpe")
	assert_almost_eq(GameState.sync_rate, 90.0, EPS)
	for i: int in roundi(0.4 / DT):
		_isak.global_position = Vector2(b.global_position.x - 20.0, 0.0)
		_step([b])
	assert_eq(hits.size(), 2, "Pasada la invulnerabilidad vuelve a danar")
	assert_almost_eq(GameState.sync_rate, 80.0, EPS)


func test_contact_from_above_damages_when_not_stunned() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_place_isak(Vector2(BUBBLE_X, b.get_platform_top_y() - 120.0), 600.0)
	var hit: bool = false
	for i: int in 60:
		_step([b])
		if GameState.sync_rate < GameState.SYNC_RATE_MAX:
			hit = true
			break
	assert_true(hit, "Sin aturdir, caer encima tambien dana (C7)")
	assert_almost_eq(GameState.sync_rate, 90.0, EPS)
	assert_eq(b.get_state(), AlertBubble.STATE_PATROL, "No revienta sin aturdir")


# --- Pulso ---

func test_pulse_stuns_only_bubbles_inside_radius() -> void:
	var near: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	var far: AlertBubble = _bubble(Vector2(BUBBLE_X + 600.0, 0.0), 0.0)
	_step([near, far], 2)
	var radius: float = _isak.abilities.pulse_radius_px
	var rect: Rect2 = near.get_body_rect()
	var center := Vector2(rect.position.x - radius + 1.0, rect.get_center().y)
	EventBus.pulse_fired.emit(_fake_pulse(center, radius))
	assert_eq(near.get_state(), AlertBubble.STATE_STUNNED, "Dentro del radio: aturdida")
	assert_eq(far.get_state(), AlertBubble.STATE_PATROL, "Fuera del radio: sigue patrullando")
	assert_almost_eq(near.get_stun_left(), near.stun_duration_s, EPS)
	var rect_far: Rect2 = far.get_body_rect()
	var outside := Vector2(rect_far.position.x - radius - 2.0, rect_far.get_center().y)
	EventBus.pulse_fired.emit(_fake_pulse(outside, radius))
	assert_eq(far.get_state(), AlertBubble.STATE_PATROL, "Justo fuera del borde del radio no aturde")


func test_real_isak_pulse_stuns_bubble_in_front() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_place_isak(Vector2(BUBBLE_X - 110.0, 0.0))
	_isak.facing = 1.0
	_sim.settle()
	_sim.input.pulse_pressed = true
	_step([b])
	_sim.input.pulse_pressed = false
	assert_eq(_sim.state(), PlayerState.PULSE)
	assert_true(b.is_stunned(), "La PulseArea real de Isak la aturde")
	assert_almost_eq(GameState.sync_rate, 100.0, EPS, "Sin dano")


func test_stunned_bubble_does_not_damage() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	b.stun()
	for i: int in roundi(1.0 / DT):
		_isak.global_position = Vector2(BUBBLE_X, 0.0)
		_step([b])
	assert_true(b.is_stunned())
	assert_almost_eq(GameState.sync_rate, 100.0, EPS, "Aturdida no dana")
	assert_ne(_sim.state(), PlayerState.HURT)


# --- Plataforma de una via, pop y pisada suave ---

func test_stunned_is_one_way_platform_passed_from_below() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, -40.0), 0.0)
	b.gravity = 0.0
	b.stun()
	var top: float = b.get_platform_top_y()
	_place_isak(Vector2(BUBBLE_X, 0.0))
	_sim.settle()
	_sim.press_jump()
	_step([b])
	var min_feet: float = 0.0
	for i: int in roundi(0.45 / DT):
		_step([b])
		min_feet = minf(min_feet, _isak.global_position.y)
	assert_lt(min_feet, top - 40.0, "Atraviesa la plataforma de abajo hacia arriba")
	assert_true(b.is_stunned(), "Subir a traves no la revienta")


func test_soft_landing_uses_it_as_platform() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_step([b], 2)
	b.stun()
	var top: float = b.get_platform_top_y()
	_place_isak(Vector2(BUBBLE_X, top - 3.0))
	_step([b], 20)
	assert_true(_isak.is_on_floor(), "Se apoya encima")
	assert_almost_eq(_isak.global_position.y, top, 1.0, "Los pies sobre el canto")
	assert_true(b.is_stunned(), "Aterrizaje suave: no revienta")
	_sim.input.move_axis = 1.0
	_step([b], 6)
	_sim.input.move_axis = 0.0
	assert_true(_isak.is_on_floor(), "Puede caminar encima")
	assert_almost_eq(_isak.global_position.y, top, 1.0)
	assert_almost_eq(GameState.sync_rate, 100.0, EPS)


func test_hard_fall_pops_and_bounces() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_step([b], 2)
	b.stun()
	var popped: Array[bool] = []
	var defeated: Array[Node2D] = []
	b.popped.connect(func() -> void: popped.append(true))
	var on_defeat := func(enemy: Node2D) -> void: defeated.append(enemy)
	EventBus.enemy_defeated.connect(on_defeat)
	var top: float = b.get_platform_top_y()
	# Caida de ~4,7 tiles sobre el canto (como saltar desde una repisa de 6 tiles).
	_place_isak(Vector2(BUBBLE_X, top - 300.0))
	var vy_before: float = 0.0
	for i: int in 90:
		vy_before = _isak.velocity.y
		_step([b])
		if b.get_state() == AlertBubble.STATE_POPPED:
			break
	EventBus.enemy_defeated.disconnect(on_defeat)
	assert_eq(b.get_state(), AlertBubble.STATE_POPPED, "Caer con velocidad la revienta (C7)")
	assert_gte(vy_before, b.pop_speed_threshold_px_s, "Caia por encima del umbral")
	assert_eq(popped.size(), 1)
	assert_eq(defeated, [b] as Array[Node2D], "Avisa por EventBus.enemy_defeated")
	_step([b], 3)
	assert_lt(_isak.velocity.y, 0.0, "Isak rebota hacia arriba")
	assert_lt(_isak.global_position.y, top - 10.0, "Sube por encima del canto")
	assert_almost_eq(GameState.sync_rate, 100.0, EPS, "Sin dano al reventarla")
	assert_eq(b.get_animation(), AlertBubble.ANIM_POP)


func test_threshold_separates_step_and_pop() -> void:
	# Isak justo encima del canto con velocidad bajo y sobre el umbral (1150):
	# la de un salto normal (780) la pisa y la de una caida muy alta la revienta.
	for vy: float in [780.0, 1400.0]:
		var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
		_step([b], 2)
		b.stun()
		_place_isak(Vector2(BUBBLE_X, b.get_platform_top_y() - 2.0), vy)
		b.step(DT)
		_step([b], 4)
		var expect_pop: bool = vy >= b.pop_speed_threshold_px_s
		assert_eq(expect_pop, vy > 1000.0, "El umbral queda entre los dos casos")
		assert_eq(b.get_state() == AlertBubble.STATE_POPPED, expect_pop, "vy %.0f" % vy)
		b.free()
		_place_isak(FAR)
		_sim.settle()


# --- Anticipacion (A8) ---

func test_anticipation_lasts_6_to_12_frames_and_blocks_damage() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_step([b], 2)
	var frames: SpriteFrames = (b.get_node(^"AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var n: int = frames.get_frame_count(AlertBubble.ANIM_ANTICIPATE)
	assert_eq(n, b.anticipation_frames, "La animacion tiene los cuadros de la anticipacion")
	assert_between(n, 6, 12, "Entre 6 y 12 cuadros")
	assert_almost_eq(frames.get_animation_speed(AlertBubble.ANIM_ANTICIPATE), 12.0, EPS, "A 12 fps")
	b.stun()
	var stunned_steps: int = _steps_until_state(b, AlertBubble.STATE_ANTICIPATE)
	assert_gt(stunned_steps, 0)
	assert_eq(b.get_animation(), AlertBubble.ANIM_ANTICIPATE)
	assert_true(b.is_platform(), "Durante el aviso sigue siendo plataforma")
	# Isak dentro de la zona de dano durante todo el aviso: sin dano.
	var anticipate_steps: int = 0
	while b.get_state() == AlertBubble.STATE_ANTICIPATE and anticipate_steps < 600:
		_isak.global_position = Vector2(BUBBLE_X, 0.0)
		_isak.velocity = Vector2.ZERO
		_step([b])
		if b.get_state() == AlertBubble.STATE_ANTICIPATE:
			assert_almost_eq(GameState.sync_rate, 100.0, EPS, "Sin dano durante la anticipacion")
		anticipate_steps += 1
	var seconds: float = anticipate_steps * DT
	assert_between(seconds, 6.0 / 12.0 - DT, 12.0 / 12.0 + DT, "Anticipacion de 0,5-1 s (6-12 cuadros a 12 fps)")
	assert_almost_eq(seconds, b.get_anticipation_s(), 2.0 * DT)
	assert_almost_eq((stunned_steps + anticipate_steps) * DT, b.stun_duration_s, 2.0 * DT,
		"El aviso ocupa el final del aturdimiento")
	assert_eq(b.get_state(), AlertBubble.STATE_PATROL)
	assert_almost_eq(GameState.sync_rate, 90.0, EPS, "En cuanto vuelve a patrullar el contacto dana")


func test_isak_on_top_warned_then_falls_in_when_it_wakes() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 0.0)
	_step([b], 2)
	b.stun()
	_place_isak(Vector2(BUBBLE_X, b.get_platform_top_y() - 2.0))
	assert_gt(_steps_until_state(b, AlertBubble.STATE_ANTICIPATE), 0)
	assert_true(_isak.is_on_floor(), "Sobre la burbuja cuando empieza el aviso")
	assert_almost_eq(GameState.sync_rate, 100.0, EPS)
	_steps_until_state(b, AlertBubble.STATE_PATROL)
	_step([b], 10)
	assert_almost_eq(GameState.sync_rate, 90.0, EPS, "Si sigue encima al despertar, dana")


# --- Debug ---

func test_debug_slows_bubble_by_half_but_not_isak() -> void:
	var b: AlertBubble = _bubble(Vector2(BUBBLE_X, 0.0), 100000.0)
	_step([b], 10)
	var seconds: float = 0.5
	var x0: float = b.global_position.x
	_step([b], roundi(seconds / DT))
	var normal: float = b.global_position.x - x0
	# Debug activo de verdad (sandbox: desbloqueado y con energia).
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())
	assert_almost_eq(GameState.world_time_scale, 0.5, EPS)
	x0 = b.global_position.x
	_step([b], roundi(seconds / DT))
	var slowed: float = b.global_position.x - x0
	assert_almost_eq(slowed / normal, 0.5, 0.02, "La Burbuja va a x0,5")
	# Isak camina igual con y sin Debug.
	_place_isak(Vector2(-1000.0, 0.0))
	_sim.settle()
	_sim.input.move_axis = 1.0
	var ix: float = _isak.global_position.x
	_sim.step(roundi(seconds / DT))
	var isak_debug: float = _isak.global_position.x - ix
	_sim.input.move_axis = 0.0
	DebugMode.reset()
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS)
	_place_isak(Vector2(-1000.0, 0.0))
	_sim.settle()
	_sim.input.move_axis = 1.0
	ix = _isak.global_position.x
	_sim.step(roundi(seconds / DT))
	_sim.input.move_axis = 0.0
	assert_almost_eq(isak_debug, _isak.global_position.x - ix, 0.5, "Isak no se ralentiza")
	# El aturdimiento tambien dura el doble en tiempo real.
	b.stun()
	DebugMode.reset()
	GameState.world_time_scale = 0.5
	_step([b], roundi(1.0 / DT))
	assert_almost_eq(b.get_stun_left(), b.stun_duration_s - 0.5, 0.02, "1 s real = 0,5 s de aturdimiento")
	GameState.world_time_scale = 1.0


# --- Escena de prueba ---

func test_test_scene_has_bubble_isak_hud_and_unlocks() -> void:
	var scene: Node = TEST_SCENE.instantiate()
	(scene.get_node(^"Isak") as Isak).input = PlayerInput.new()
	add_child_autofree(scene)
	await wait_physics_frames(2)
	assert_true(scene.get_node_or_null(^"AlertBubble") is AlertBubble, "Una Burbuja")
	assert_true(scene.get_node_or_null(^"Hud") is Hud, "HUD instanciado")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Debug disponible (como la sandbox)")
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "Con energia")
	assert_eq(GameState.current_world, 1)
