# Pruebas de scenes/levels/debug_sandbox.tscn y de sus objetos: solo la
# sandbox desbloquea el Debug (en la arena K no hace nada), empieza con energia
# 100, K se mantiene para activar y se pulsa para desactivar, el camino oculto
# es alcanzable, world_time_scale llega a la plataforma
# movil y a la pelota, y los puntos de atencion suman +1 y +10 de energia
# (tambien con el Debug activo).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SANDBOX_SCENE: PackedScene = preload("res://scenes/levels/debug_sandbox.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/levels/test_arena.tscn")
const POINT_SCENE: PackedScene = preload("res://scenes/levels/attention_point.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const ACTION_DEBUG: StringName = &"debug"
const SETTLE_FRAMES: int = 30
## Margen de seguridad del level-builder: ningun salto exige mas del 85 %.
const REACH_MARGIN: float = 0.85
## Segundos de tiempo real que se simulan para medir la ralentizacion.
const PROBE_SECONDS: float = 0.5

var _saved: Dictionary = {}
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_each() -> void:
	_saved = {
		"energy": GameState.debug_energy,
		"points": GameState.attention_points,
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"pulse": GameState.is_ability_unlocked(GameState.ABILITY_PULSE),
		"dash": GameState.is_ability_unlocked(GameState.ABILITY_DASH),
		"ground_pound": GameState.is_ability_unlocked(GameState.ABILITY_GROUND_POUND),
		# La test_arena desbloquea tambien Pellizcar desde el paso 1 del Mundo 3 (paso 20: sin devolverlo,
		# test_dnd_switch y test_eco_encounter recibian el aviso de Pellizcar de mas en la suite).
		"compress": GameState.is_ability_unlocked(GameState.ABILITY_COMPRESS),
		# Y Agitar desde el paso 1 del Mundo 4 (2026-10-28): mismo motivo.
		"shockwave": GameState.is_ability_unlocked(GameState.ABILITY_SHOCKWAVE),
		"world": GameState.current_world,
	}
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)


func after_each() -> void:
	Input.action_release(ACTION_DEBUG)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.debug_energy = _saved.energy
	GameState.attention_points = _saved.points
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved.pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, _saved.dash)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, _saved.ground_pound)
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, _saved.compress)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, _saved.shockwave)
	GameState.current_world = _saved.world


func _make_sandbox() -> Node:
	var sandbox: Node = SANDBOX_SCENE.instantiate()
	(sandbox.get_node(^"Isak") as Isak).input = PlayerInput.new()
	return add_child_autofree(sandbox)


## Pulsacion larga hasta activar, soltar y esperar la transicion de entrada.
func _debug_on() -> void:
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(_config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)


## Cuadros de fisica que dura la pulsacion larga.
func _hold_frames() -> int:
	return roundi(_config.activation_hold_s / DT)


# --- Desbloqueo por escena ---

func test_sandbox_unlocks_debug_only_while_loaded() -> void:
	GameState.debug_energy = 30.0
	var sandbox: Node = _make_sandbox()
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "La sandbox desbloquea el Debug")
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "Empieza con energia 100")
	assert_eq(GameState.current_world, 1, "Mundo 1: Debug cian")
	assert_true(sandbox.get_node_or_null(^"Hud") is Hud, "HUD instanciado")
	remove_child(sandbox)
	sandbox.free()
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Al salir vuelve a bloquearse")


func test_k_does_nothing_in_test_arena() -> void:
	var arena: Node = add_child_autofree(ARENA_SCENE.instantiate())
	(arena.get_node(^"Isak") as Isak).input = PlayerInput.new()
	await wait_physics_frames(2)
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "La arena no desbloquea el Debug")
	var energy: float = GameState.debug_energy
	DebugMode.input_enabled = true
	Input.action_press(ACTION_DEBUG)
	await wait_physics_frames(SETTLE_FRAMES + _hold_frames())
	assert_false(DebugMode.is_active(), "K no activa el Debug en la arena")
	assert_almost_eq(DebugMode.get_activation_progress(), 0.0, EPS, "Ni muestra carga")
	assert_almost_eq(GameState.debug_energy, energy, EPS, "Ni gasta energia")
	assert_eq(GameState.world_time_scale, 1.0)
	Input.action_release(ACTION_DEBUG)
	# La arena (test_arena.gd) desbloquea pulso, Deslizar y el golpe al suelo al
	# cargarse y no los devuelve: after_each los restaura (2026-10-23, paso 21 de
	# docs/propuesta-mundo-2.md: quedaban desbloqueados para los scripts siguientes
	# y test_dnd_switch, test_eco_encounter y test_help_inert veian avisos de mas).


func test_k_activates_debug_in_sandbox() -> void:
	_make_sandbox()
	await wait_physics_frames(2)
	DebugMode.input_enabled = true
	Input.action_press(ACTION_DEBUG)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(DebugMode.is_active(), "Una pulsacion breve aun no lo activa")
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "La carga no gasta")
	await wait_physics_frames(_hold_frames())
	assert_true(DebugMode.is_active(), "Mantener K activa el Debug en la sandbox")
	Input.action_release(ACTION_DEBUG)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(DebugMode.is_active(), "Soltar K no lo apaga")
	assert_lt(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, "Gasta energia")
	Input.action_press(ACTION_DEBUG)
	await wait_physics_frames(2)
	Input.action_release(ACTION_DEBUG)
	await wait_physics_frames(2)
	assert_false(DebugMode.is_active(), "Pulsar K de nuevo lo apaga")


# --- Geometria ---

func test_hidden_path_reaches_ledge() -> void:
	var sandbox: Node = _make_sandbox()
	var hidden: Array[Node] = get_tree().get_nodes_in_group(HiddenPlatform.GROUP)
	assert_gte(hidden.size(), 3, "Al menos 3 plataformas ocultas")
	var p: PlayerPhysics = (sandbox.get_node(^"Isak") as Isak).physics
	var ground_top: float = (sandbox.get_node(^"Ground") as Node2D).position.y - p.tile_size * 0.5
	var tops: Array[float] = [ground_top]
	for node: Node in sandbox.get_node(^"HiddenPath").get_children():
		var platform: HiddenPlatform = node as HiddenPlatform
		tops.append(platform.position.y - platform.size.y * 0.5)
	var ledge: Node2D = sandbox.get_node(^"Ledge")
	tops.append(ledge.position.y - (ledge.get_node(^"CollisionShape2D") as CollisionShape2D).shape.get_rect().size.y * 0.5)
	for i: int in range(1, tops.size()):
		var rise: float = tops[i - 1] - tops[i]
		assert_gt(rise, 0.0, "Cada escalon sube")
		assert_lte(rise, p.jump_height_px * REACH_MARGIN, "Escalon %d alcanzable con margen" % i)
	assert_gt(ground_top - tops[-1], p.jump_height_px, "Sin Debug la repisa queda fuera de alcance")


# --- Tiempo del mundo ---

## Recorrido de la plataforma y tiempo de la pelota en PROBE_SECONDS reales.
func _probe(platform: MovingPlatform, ball: BouncingBall) -> Dictionary:
	var x0: float = platform.get_offset().x
	var t0: float = ball.get_world_time()
	for i: int in roundi(PROBE_SECONDS / DT):
		platform._physics_process(DT)
		ball._physics_process(DT)
	return {"platform": absf(platform.get_offset().x - x0), "ball": ball.get_world_time() - t0}


func test_world_time_scale_reaches_test_objects() -> void:
	var sandbox: Node = _make_sandbox()
	var platform: MovingPlatform = sandbox.get_node(^"MovingPlatform") as MovingPlatform
	var ball: BouncingBall = sandbox.get_node(^"BouncingBall") as BouncingBall
	platform.set_physics_process(false)
	ball.set_physics_process(false)
	var normal: Dictionary = _probe(platform, ball)
	assert_almost_eq(normal.platform, platform.speed_px_s * PROBE_SECONDS, 0.5)
	assert_almost_eq(normal.ball, PROBE_SECONDS, EPS)
	_debug_on()
	var slowed: Dictionary = _probe(platform, ball)
	assert_almost_eq(slowed.platform, normal.platform * _config.world_time_scale, 0.5, "Plataforma a x0,5")
	assert_almost_eq(slowed.ball, PROBE_SECONDS * _config.world_time_scale, EPS, "Pelota a x0,5")


# --- Puntos de atencion ---

func _pickup_world(debug: bool) -> AttentionPoint:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	var point: AttentionPoint = POINT_SCENE.instantiate() as AttentionPoint
	point.position = Vector2(0.0, -point.radius_px * 2.0)
	world.add_child(point)
	if debug:
		GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
		_debug_on()
	add_child_autofree(world)
	return point


func test_attention_point_adds_one_and_ten_energy() -> void:
	GameState.debug_energy = 50.0
	GameState.attention_points = 0
	var point: AttentionPoint = _pickup_world(false)
	var received: Array[int] = []
	point.collected.connect(func(value: int) -> void: received.append(value))
	await wait_physics_frames(3)
	assert_eq(GameState.attention_points, 1, "+1 punto")
	assert_almost_eq(GameState.debug_energy, 50.0 + GameState.ENERGY_PER_ATTENTION_POINT, EPS, "+10 energia")
	assert_eq(received, [1] as Array[int], "Senal collected con el valor")


func test_attention_point_can_be_collected_during_debug() -> void:
	var point: AttentionPoint = _pickup_world(true)
	GameState.debug_energy = 50.0
	GameState.attention_points = 0
	await wait_physics_frames(3)
	assert_true(DebugMode.is_active(), "Debug activo al recoger")
	assert_eq(GameState.attention_points, 1)
	assert_almost_eq(GameState.debug_energy, 50.0 + GameState.ENERGY_PER_ATTENTION_POINT, EPS)
	assert_false(is_instance_valid(point) and not point.is_queued_for_deletion(), "El punto desaparece")
