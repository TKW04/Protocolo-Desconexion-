# Pruebas de transiciones de la maquina de estados de Isak.
# La fisica avanza paso a paso con delta fijo llamando a Isak.step(); el input
# es un PlayerInput falso que se escribe a mano. Sin input real.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const DELTA: float = 1.0 / 60.0
const FLOOR_SIZE: Vector2 = Vector2(4096.0, 64.0)
## Margen de pasos extra sobre los calculados con los datos.
const STEP_MARGIN: int = 10
## Limite de pasos para esperar algo que deberia ocurrir en pocos segundos.
const MAX_WAIT_STEPS: int = 600
const SHORT_RUN_STEPS: int = 10

var _isak: Isak
var _input: PlayerInput
var _pulse_was_unlocked: bool


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	var world := Node2D.new()
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = FLOOR_SIZE
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	# Superficie del suelo en y = 0.
	floor_body.position = Vector2(0.0, FLOOR_SIZE.y * 0.5)
	world.add_child(floor_body)
	_input = PlayerInput.new()
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.input = _input
	world.add_child(_isak)
	add_child_autofree(world)
	_isak.set_physics_process(false)
	await wait_physics_frames(1)
	_settle()


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

func _step(count: int = 1) -> void:
	for i: int in count:
		_isak.step(DELTA)
		_input.clear_just_pressed()


## Avanza hasta que se cumpla `condition` o se agoten los pasos. Devuelve los pasos dados.
func _step_until(condition: Callable, max_steps: int = MAX_WAIT_STEPS) -> int:
	for i: int in max_steps:
		if condition.call():
			return i
		_step()
	return max_steps


func _settle() -> void:
	_step_until(func() -> bool: return _isak.is_on_floor() and _isak.get_state_name() == PlayerState.IDLE)


func _state() -> StringName:
	return _isak.get_state_name()


func _steps_for(seconds: float) -> int:
	return ceili(seconds / DELTA) + STEP_MARGIN


func _press_jump() -> void:
	_input.jump_pressed = true
	_input.jump_held = true
	_step()
	_input.jump_held = false


# --- Pruebas ---

func test_settles_idle_on_floor() -> void:
	assert_true(_isak.is_on_floor(), "Isak debe apoyarse en el suelo de prueba")
	assert_eq(_state(), PlayerState.IDLE)


func test_idle_to_run_with_move_axis() -> void:
	_input.move_axis = 1.0
	_step()
	assert_eq(_state(), PlayerState.RUN)
	assert_gt(_isak.velocity.x, 0.0, "Debe acelerar hacia la derecha")


func test_run_uses_walk_or_run_speed() -> void:
	_input.move_axis = 1.0
	_step(_steps_for(_isak.physics.walk_speed / _isak.physics.ground_acceleration))
	assert_almost_eq(_isak.velocity.x, _isak.physics.walk_speed, 0.01, "Sin run_held camina")
	_input.run_held = true
	_step(_steps_for(_isak.physics.run_speed / _isak.physics.ground_acceleration))
	assert_almost_eq(_isak.velocity.x, _isak.physics.run_speed, 0.01, "Con run_held corre")


func test_run_to_idle_when_axis_released() -> void:
	_input.move_axis = -1.0
	_step(SHORT_RUN_STEPS)
	assert_eq(_state(), PlayerState.RUN)
	assert_lt(_isak.facing, 0.0, "Debe mirar a la izquierda")
	_input.move_axis = 0.0
	_step()
	assert_eq(_state(), PlayerState.IDLE)


func test_idle_to_jump_on_floor() -> void:
	_press_jump()
	assert_eq(_state(), PlayerState.JUMP)
	assert_lt(_isak.velocity.y, 0.0, "Debe subir")


func test_run_to_jump_on_floor() -> void:
	_input.move_axis = 1.0
	_step(SHORT_RUN_STEPS)
	_press_jump()
	assert_eq(_state(), PlayerState.JUMP)


func test_jump_to_fall_at_apex() -> void:
	_press_jump()
	var steps: int = _step_until(func() -> bool: return _state() != PlayerState.JUMP,
			_steps_for(_isak.physics.time_to_apex_s))
	assert_eq(_state(), PlayerState.FALL, "Tras el apogeo debe caer (pasos: %d)" % steps)
	assert_false(_isak.is_on_floor())


func test_fall_to_idle_on_landing() -> void:
	_press_jump()
	_step_until(func() -> bool: return _state() == PlayerState.FALL)
	_step_until(func() -> bool: return _state() != PlayerState.FALL)
	assert_eq(_state(), PlayerState.IDLE)
	assert_true(_isak.is_on_floor())


func test_fall_to_run_on_landing_with_input() -> void:
	_press_jump()
	_step_until(func() -> bool: return _state() == PlayerState.FALL)
	_input.move_axis = 1.0
	_step_until(func() -> bool: return _state() != PlayerState.FALL)
	assert_eq(_state(), PlayerState.RUN)


func test_pulse_from_idle_when_unlocked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	watch_signals(_isak)
	_input.pulse_pressed = true
	_step()
	assert_eq(_state(), PlayerState.PULSE)
	assert_signal_emitted(_isak, "pulse_fired")


func test_pulse_from_run_when_unlocked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.move_axis = 1.0
	_step(SHORT_RUN_STEPS)
	_input.pulse_pressed = true
	_step()
	assert_eq(_state(), PlayerState.PULSE)


func test_pulse_blocked_when_locked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, false)
	watch_signals(_isak)
	_input.pulse_pressed = true
	_step()
	assert_eq(_state(), PlayerState.IDLE)
	assert_signal_not_emitted(_isak, "pulse_fired")


func test_pulse_blocks_horizontal_movement() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.move_axis = 1.0
	_step(SHORT_RUN_STEPS)
	var speed_before: float = _isak.velocity.x
	_input.pulse_pressed = true
	_step(SHORT_RUN_STEPS)
	assert_eq(_state(), PlayerState.PULSE)
	assert_lt(_isak.velocity.x, speed_before, "Durante el pulso solo hay friccion")


func test_pulse_to_idle_when_finished() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.pulse_pressed = true
	_step()
	var steps: int = _step_until(func() -> bool: return _state() != PlayerState.PULSE,
			_steps_for(_isak.abilities.pulse_duration_s))
	assert_eq(_state(), PlayerState.IDLE, "El pulso debe acabar en Idle (pasos: %d)" % steps)
	assert_gte(float(steps) * DELTA, _isak.abilities.pulse_duration_s - DELTA, "No debe acabar antes de tiempo")


func test_hurt_then_back_to_idle() -> void:
	watch_signals(_isak)
	assert_true(_isak.take_hit(1.0))
	assert_eq(_state(), PlayerState.HURT)
	assert_true(_isak.is_invulnerable())
	assert_signal_emitted(_isak, "hurt")
	assert_false(_isak.take_hit(1.0), "Invulnerable: el segundo golpe se ignora")
	_step_until(func() -> bool: return _state() == PlayerState.IDLE)
	assert_eq(_state(), PlayerState.IDLE)
	assert_true(_isak.is_on_floor())


func test_invulnerability_expires() -> void:
	_isak.take_hit()
	_step(_steps_for(_isak.abilities.hurt_invulnerability_s))
	assert_false(_isak.is_invulnerable())
	assert_true(_isak.take_hit())


func test_any_state_to_dead() -> void:
	var setups: Array[Callable] = [
		func() -> void: pass,
		func() -> void:
			_input.move_axis = 1.0
			_step(SHORT_RUN_STEPS),
		func() -> void: _press_jump(),
		func() -> void: _isak.take_hit(),
	]
	for setup: Callable in setups:
		_input.move_axis = 0.0
		_isak.change_state(PlayerState.IDLE)
		setup.call()
		var from: StringName = _state()
		watch_signals(_isak)
		_isak.die()
		assert_eq(_state(), PlayerState.DEAD, "De %s a Dead" % from)
		assert_signal_emitted(_isak, "died")
		# Sale de Dead solo reiniciando el estado a mano para el siguiente caso.
		_isak.change_state(PlayerState.IDLE)
		_settle()


func test_dead_ignores_input() -> void:
	_isak.die()
	_input.move_axis = 1.0
	_input.jump_pressed = true
	_step(SHORT_RUN_STEPS)
	assert_eq(_state(), PlayerState.DEAD)
	assert_almost_eq(_isak.velocity.x, 0.0, 0.001)


func test_dead_when_sync_rate_reaches_zero() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_eq(_state(), PlayerState.DEAD)


func test_idle_time_grows_and_resets_on_move() -> void:
	var start: float = _isak.get_idle_time()
	assert_almost_eq(start, 0.0, DELTA * 2.0)
	_step(SHORT_RUN_STEPS)
	assert_almost_eq(_isak.get_idle_time() - start, SHORT_RUN_STEPS * DELTA, 0.0001)
	_input.move_axis = 1.0
	_step()
	assert_eq(_isak.get_idle_time(), 0.0)
	_input.move_axis = 0.0
	_step_until(func() -> bool: return _isak.get_idle_time() > 0.0)
	assert_eq(_state(), PlayerState.IDLE)


func test_terminal_animation_after_threshold_and_input_cuts_it() -> void:
	watch_signals(_isak)
	_step(_steps_for(_isak.terminal_idle_threshold_s))
	assert_signal_emitted(_isak, "idle_terminal_started")
	assert_true(_isak.is_terminal_playing())
	_input.run_held = true
	_step()
	assert_false(_isak.is_terminal_playing(), "Cualquier input corta la terminal")
	assert_eq(_isak.get_idle_time(), 0.0)
