# Pruebas de la fisica de Isak simulada paso a paso (Isak.step con delta fijo
# e input falso): altura y tiempo del salto, gravedad de caida, coyote time,
# jump buffer, velocidades, friccion y alcance horizontal. Cada prueba se
# repite a 60 y 120 pasos por segundo para comprobar que el resultado no
# depende del framerate. Los valores esperados salen de data/isak_physics.json.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ARENA_SCENE: PackedScene = preload("res://scenes/levels/test_arena.tscn")
const DELTAS: Array[float] = [1.0 / 60.0, 1.0 / 120.0]
## Holgura para comparaciones que solo sufren error de coma flotante.
const FLOAT_TOLERANCE: float = 0.01
## Distancia horizontal desde el borde a la que se coloca a Isak antes de salir caminando.
const EDGE_START_OFFSET_PX: float = 16.0
## Cuadros reales maximos a esperar a que el motor adopte la nueva frecuencia de fisica.
const MAX_TICK_SYNC_FRAMES: int = 10

var _pulse_was_unlocked: bool
var _ticks_before: int
## Mundo de la simulacion en curso. Solo hay uno a la vez: dos Isak en el mismo
## sitio chocarian entre si.
var _world: Node


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_ticks_before = Engine.physics_ticks_per_second


func after_each() -> void:
	_free_world()
	Engine.physics_ticks_per_second = _ticks_before
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)


# --- Utilidades ---

func _free_world() -> void:
	if is_instance_valid(_world):
		_world.free()
	_world = null


## Sustituye el mundo actual por `world` y ajusta la frecuencia de fisica del
## motor a `delta`: move_and_slide() integra la posicion con el delta del motor,
## no con el que recibe Isak.step(), y ambos deben coincidir como en el juego.
func _use_world(sim: IsakSim, world: Node) -> void:
	_free_world()
	Engine.physics_ticks_per_second = roundi(1.0 / sim.delta)
	_world = world
	add_child(world)
	sim.take_manual_control()
	# El motor aplica la nueva frecuencia en un cuadro posterior, no al instante.
	for i: int in MAX_TICK_SYNC_FRAMES:
		await wait_physics_frames(1)
		if is_equal_approx(get_physics_process_delta_time(), sim.delta):
			break
	assert_almost_eq(get_physics_process_delta_time(), sim.delta, 0.0001,
			"El delta del motor debe coincidir con el de la simulacion")
	sim.settle()


## Simulacion nueva con suelo llano (superficie en y = 0, borde derecho en
## FLOOR_SIZE.x / 2) e Isak quieto en Idle.
func _make_sim(delta: float) -> IsakSim:
	var sim := IsakSim.new(delta)
	await _use_world(sim, sim.build_flat_world())
	return sim


## Coloca a Isak cerca del borde derecho del suelo llano y camina hasta que
## deja de tocar el suelo (sin saltar). Al volver, el ultimo paso fue el
## primero en el aire.
func _walk_off_edge(sim: IsakSim) -> void:
	sim.isak.global_position.x = IsakSim.FLOOR_SIZE.x * 0.5 - EDGE_START_OFFSET_PX
	sim.settle()
	sim.input.move_axis = 1.0
	sim.step_until(func() -> bool: return not sim.isak.is_on_floor())


## Salta desde el suelo y devuelve altura maxima, pasos hasta el apogeo y
## pasos hasta que la maquina de estados detecta el aterrizaje (contando el
## paso del salto como 1).
func _measure_jump(sim: IsakSim) -> Dictionary:
	var y0: float = sim.isak.global_position.y
	var min_y: float = y0
	sim.press_jump()
	var steps: int = 1
	var apex_steps: int = -1
	var limit: int = sim.steps_for(IsakSim.MAX_WAIT_S)
	while sim.state() in [PlayerState.JUMP, PlayerState.FALL] and steps < limit:
		if apex_steps < 0 and sim.isak.velocity.y >= 0.0:
			apex_steps = steps
		min_y = minf(min_y, sim.isak.global_position.y)
		sim.step()
		steps += 1
	return {"height": y0 - min_y, "apex_steps": apex_steps, "landing_steps": steps}


# --- Salto ---

## Integracion semi-implicita (v += g*dt; x += v*dt): la altura discreta queda
## por debajo de la continua en ~|v0|*dt/2 (4 px a 60 Hz, 2 px a 120 Hz).
## Tolerancia: un cuadro entero de subida a velocidad de despegue, |v0|*dt.
func test_jump_reaches_jump_height_and_apex_time() -> void:
	var heights: Array[float] = []
	for delta: float in DELTAS:
		var sim: IsakSim = await _make_sim(delta)
		var p: PlayerPhysics = sim.isak.physics
		var result: Dictionary = _measure_jump(sim)
		var height_tol: float = absf(p.jump_velocity) * delta
		assert_almost_eq(result.height, p.jump_height_px, height_tol,
				"Altura del salto a dt=%.4f" % delta)
		assert_lte(result.height, p.jump_height_px + FLOAT_TOLERANCE,
				"La integracion discreta no debe superar la altura de diseno")
		# El apogeo cae en un paso entero: tolerancia de un cuadro.
		assert_almost_eq(result.apex_steps * delta, p.time_to_apex_s, delta + FLOAT_TOLERANCE,
				"Tiempo al apogeo a dt=%.4f" % delta)
		gut.p("dt=%.4f altura=%.2f px apogeo=%.4f s" % [delta, result.height, result.apex_steps * delta])
		heights.append(result.height)
	var max_delta: float = DELTAS.max()
	var p_ref: PlayerPhysics = PlayerPhysics.load_from_file()
	assert_almost_eq(heights[0], heights[1], absf(p_ref.jump_velocity) * max_delta,
			"La altura no debe depender del framerate")


## Al subir se aplica gravity y al caer gravity * fall_gravity_multiplier.
## Se mide la aceleracion media en el aire, sin contacto: solo error de coma flotante.
func test_rise_and_fall_gravity() -> void:
	for delta: float in DELTAS:
		var sim: IsakSim = await _make_sim(delta)
		var p: PlayerPhysics = sim.isak.physics
		var window: int = sim.frames(p.time_to_apex_s * 0.25)
		sim.press_jump()
		var v_rise: float = sim.isak.velocity.y
		sim.step(window)
		assert_eq(sim.state(), PlayerState.JUMP)
		var rise_accel: float = (sim.isak.velocity.y - v_rise) / (window * delta)
		assert_almost_eq(rise_accel, p.gravity, FLOAT_TOLERANCE, "Gravedad de subida a dt=%.4f" % delta)
		sim.step_until(func() -> bool: return sim.state() == PlayerState.FALL)
		sim.step()
		var v_fall: float = sim.isak.velocity.y
		sim.step(window)
		assert_eq(sim.state(), PlayerState.FALL, "Debe seguir cayendo durante la medida")
		var fall_accel: float = (sim.isak.velocity.y - v_fall) / (window * delta)
		assert_almost_eq(fall_accel, p.gravity * p.fall_gravity_multiplier, FLOAT_TOLERANCE,
				"Gravedad de caida a dt=%.4f" % delta)


# --- Coyote time ---

## Tras salir caminando de un borde se puede saltar hasta coyote_time_s despues.
## Bordes: (coyote - 1 cuadro) salta; (coyote + 2 cuadros) no.
func test_coyote_time_edges() -> void:
	for delta: float in DELTAS:
		var cases: Dictionary = {}
		var probe: IsakSim = await _make_sim(delta)
		var coyote_frames: int = probe.frames(probe.isak.physics.coyote_time_s)
		cases[coyote_frames - 1] = true
		cases[coyote_frames + 2] = false
		for frames_after: int in cases:
			var sim: IsakSim = await _make_sim(delta)
			_walk_off_edge(sim)
			# El paso en que deja el suelo cuenta como 0; el salto llega en el paso frames_after.
			sim.step(frames_after - 1)
			assert_eq(sim.state(), PlayerState.FALL, "Debe estar cayendo antes de pulsar")
			sim.press_jump()
			var should_jump: bool = cases[frames_after]
			var label: String = "%d cuadros tras el borde a dt=%.4f" % [frames_after, delta]
			if should_jump:
				assert_eq(sim.state(), PlayerState.JUMP, "Coyote: debe saltar a " + label)
				assert_lt(sim.isak.velocity.y, 0.0, "Coyote: debe subir a " + label)
			else:
				assert_eq(sim.state(), PlayerState.FALL, "Fuera del coyote: no debe saltar a " + label)
				assert_gt(sim.isak.velocity.y, 0.0, "Fuera del coyote: debe seguir cayendo a " + label)


## Saltar durante el coyote gasta el coyote: no hay segundo salto en el aire.
func test_coyote_does_not_allow_double_jump() -> void:
	for delta: float in DELTAS:
		var sim: IsakSim = await _make_sim(delta)
		var p: PlayerPhysics = sim.isak.physics
		_walk_off_edge(sim)
		sim.press_jump()
		assert_eq(sim.state(), PlayerState.JUMP, "El primer salto (coyote) debe funcionar")
		# Segundo intento todavia dentro de la ventana original de coyote.
		var v_before: float = sim.isak.velocity.y
		sim.press_jump()
		assert_almost_eq(sim.isak.velocity.y, v_before + p.gravity * delta, FLOAT_TOLERANCE,
				"Un segundo salto no debe reiniciar la velocidad (dt=%.4f)" % delta)
		# Y tampoco ya cayendo tras el apogeo.
		sim.step_until(func() -> bool: return sim.state() == PlayerState.FALL)
		sim.press_jump()
		assert_eq(sim.state(), PlayerState.FALL, "Sin doble salto tras el apogeo (dt=%.4f)" % delta)
		assert_gt(sim.isak.velocity.y, 0.0)


# --- Jump buffer ---

## Pulsar saltar poco antes de aterrizar salta al tocar el suelo. Los cuadros se
## cuentan hacia atras desde el paso en que la maquina de estados detecta el
## suelo (el siguiente al contacto de move_and_slide).
## Bordes: (buffer - 1 cuadro) salta; (buffer + 2 cuadros) no.
func test_jump_buffer_edges() -> void:
	for delta: float in DELTAS:
		# Referencia: el mismo salto sin buffer, para conocer el paso de aterrizaje.
		var reference: IsakSim = await _make_sim(delta)
		var landing_steps: int = _measure_jump(reference).landing_steps
		assert_eq(reference.state(), PlayerState.IDLE, "La referencia debe aterrizar en Idle")
		var buffer_frames: int = reference.frames(reference.isak.physics.jump_buffer_s)
		var cases: Dictionary = {buffer_frames - 1: true, buffer_frames + 2: false}
		for frames_before: int in cases:
			var sim: IsakSim = await _make_sim(delta)
			sim.press_jump()
			# press_jump cuenta como paso 1; el aterrizaje se detecta en el paso landing_steps
			# y el segundo salto se pulsa en el paso landing_steps - frames_before.
			sim.step(landing_steps - frames_before - 2)
			assert_eq(sim.state(), PlayerState.FALL, "Debe estar en el aire al pulsar")
			sim.press_jump()
			sim.step(frames_before)
			var label: String = "%d cuadros antes de aterrizar a dt=%.4f" % [frames_before, delta]
			if cases[frames_before]:
				assert_eq(sim.state(), PlayerState.JUMP, "Buffer: debe saltar al aterrizar, " + label)
			else:
				assert_eq(sim.state(), PlayerState.IDLE, "Fuera del buffer: no debe saltar, " + label)


# --- Velocidades y friccion ---

func test_walk_run_speeds_and_friction() -> void:
	for delta: float in DELTAS:
		var sim: IsakSim = await _make_sim(delta)
		var p: PlayerPhysics = sim.isak.physics
		sim.input.move_axis = 1.0
		sim.step(sim.steps_for(p.walk_speed / p.ground_acceleration))
		assert_almost_eq(sim.isak.velocity.x, p.walk_speed, FLOAT_TOLERANCE, "Caminar a dt=%.4f" % delta)
		sim.input.run_held = true
		sim.step(sim.steps_for((p.run_speed - p.walk_speed) / p.ground_acceleration))
		assert_almost_eq(sim.isak.velocity.x, p.run_speed, FLOAT_TOLERANCE, "Correr a dt=%.4f" % delta)
		sim.input.move_axis = 0.0
		sim.input.run_held = false
		var stop_steps: int = sim.step_until(func() -> bool: return is_zero_approx(sim.isak.velocity.x))
		assert_almost_eq(stop_steps * delta, p.run_speed / p.ground_friction, delta + FLOAT_TOLERANCE,
				"La friccion debe frenar en run_speed / ground_friction (dt=%.4f)" % delta)
		var x_stopped: float = sim.isak.global_position.x
		sim.step(sim.steps_for(p.time_to_apex_s))
		assert_almost_eq(sim.isak.global_position.x, x_stopped, FLOAT_TOLERANCE, "Debe quedarse quieto")


# --- Alcance horizontal ---

## Salto corriendo en llano: distancia entre el despegue y el contacto con el suelo.
## Tolerancia de dos cuadros a run_speed: el contacto cae en un paso entero
## (hasta 1 cuadro) y la integracion discreta acorta la subida y la caida
## (menos de 1 cuadro en total).
func test_running_jump_reach_matches_formula() -> void:
	var reaches: Array[float] = []
	for delta: float in DELTAS:
		var sim: IsakSim = await _make_sim(delta)
		var p: PlayerPhysics = sim.isak.physics
		sim.input.move_axis = 1.0
		sim.input.run_held = true
		sim.step(sim.steps_for(p.run_speed / p.ground_acceleration))
		assert_almost_eq(sim.isak.velocity.x, p.run_speed, FLOAT_TOLERANCE)
		var x0: float = sim.isak.global_position.x
		sim.press_jump()
		sim.step_until(func() -> bool: return sim.isak.is_on_floor())
		var reach: float = sim.isak.global_position.x - x0
		assert_almost_eq(reach, p.horizontal_reach(p.run_speed), p.run_speed * 2.0 * delta,
				"Alcance corriendo a dt=%.4f" % delta)
		gut.p("dt=%.4f alcance corriendo=%.2f px (formula %.2f)" % [delta, reach, p.horizontal_reach(p.run_speed)])
		reaches.append(reach)
	var p_ref: PlayerPhysics = PlayerPhysics.load_from_file()
	assert_almost_eq(reaches[0], reaches[1], p_ref.run_speed * 2.0 * DELTAS.max(),
			"El alcance no debe depender del framerate")


## El hueco entre GroundLeft y GroundRight de test_arena se salva caminando,
## saltando en el ultimo momento con los pies todavia en el suelo.
func test_arena_gap_is_jumpable_walking() -> void:
	for delta: float in DELTAS:
		var arena: Node2D = ARENA_SCENE.instantiate() as Node2D
		var sim := IsakSim.new(delta)
		sim.attach(arena.get_node("Isak") as Isak)
		arena.set_physics_process(false)
		await _use_world(sim, arena)
		var left: StaticBody2D = arena.get_node("GroundLeft") as StaticBody2D
		var right: StaticBody2D = arena.get_node("GroundRight") as StaticBody2D
		var left_size: Vector2 = ((left.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		var right_size: Vector2 = ((right.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		var gap_start: float = left.global_position.x + left_size.x * 0.5
		var gap_end: float = right.global_position.x - right_size.x * 0.5
		var right_top: float = right.global_position.y - right_size.y * 0.5
		assert_gt(gap_end - gap_start, 0.0, "La arena debe tener un hueco")
		var isak: Isak = sim.isak
		# Se empieza pasada PlatformLow (Isak no cabe debajo) y con sitio para
		# llegar a walk_speed antes del borde.
		isak.global_position.x = gap_start - 2.0 * isak.physics.tile_size
		sim.settle()
		sim.input.move_axis = 1.0
		sim.step_until(func() -> bool: return isak.global_position.x >= gap_start - isak.hitbox_size.x * 0.5)
		assert_true(isak.is_on_floor(), "Debe saltar con los pies en el suelo")
		assert_almost_eq(isak.velocity.x, isak.physics.walk_speed, FLOAT_TOLERANCE, "Debe ir caminando")
		sim.press_jump()
		sim.step_until(func() -> bool: return isak.is_on_floor())
		gut.p("dt=%.4f hueco=%.0f px, aterriza en x=%.1f (borde %.0f)" % [delta, gap_end - gap_start, isak.global_position.x, gap_end])
		assert_true(isak.is_on_floor(), "Debe aterrizar (dt=%.4f)" % delta)
		assert_gt(isak.global_position.x, gap_end, "Debe aterrizar pasado el hueco (dt=%.4f)" % delta)
		assert_almost_eq(isak.global_position.y, right_top, 1.0, "Debe estar sobre GroundRight")
