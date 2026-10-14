# Pruebas de transiciones de la maquina de estados de Isak.
# La fisica avanza paso a paso con delta fijo llamando a Isak.step(); el input
# es un PlayerInput falso que se escribe a mano. Sin input real.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SHORT_RUN_STEPS: int = 10

var _sim: IsakSim
var _isak: Isak
var _input: PlayerInput
var _pulse_was_unlocked: bool


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_sim = IsakSim.new()
	add_child_autofree(_sim.build_flat_world())
	_sim.take_manual_control()
	_isak = _sim.isak
	_input = _sim.input
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Pruebas ---

func test_settles_idle_on_floor() -> void:
	assert_true(_isak.is_on_floor(), "Isak debe apoyarse en el suelo de prueba")
	assert_eq(_sim.state(), PlayerState.IDLE)


func test_idle_to_run_with_move_axis() -> void:
	_input.move_axis = 1.0
	_sim.step()
	assert_eq(_sim.state(), PlayerState.RUN)
	assert_gt(_isak.velocity.x, 0.0, "Debe acelerar hacia la derecha")


func test_run_uses_walk_or_run_speed() -> void:
	_input.move_axis = 1.0
	_sim.step(_sim.steps_for(_isak.physics.walk_speed / _isak.physics.ground_acceleration))
	assert_almost_eq(_isak.velocity.x, _isak.physics.walk_speed, 0.01, "Sin run_held camina")
	_input.run_held = true
	_sim.step(_sim.steps_for(_isak.physics.run_speed / _isak.physics.ground_acceleration))
	assert_almost_eq(_isak.velocity.x, _isak.physics.run_speed, 0.01, "Con run_held corre")


func test_run_to_idle_when_axis_released() -> void:
	_input.move_axis = -1.0
	_sim.step(SHORT_RUN_STEPS)
	assert_eq(_sim.state(), PlayerState.RUN)
	assert_lt(_isak.facing, 0.0, "Debe mirar a la izquierda")
	_input.move_axis = 0.0
	_sim.step()
	assert_eq(_sim.state(), PlayerState.IDLE)


func test_idle_to_jump_on_floor() -> void:
	_sim.press_jump()
	assert_eq(_sim.state(), PlayerState.JUMP)
	assert_lt(_isak.velocity.y, 0.0, "Debe subir")


func test_run_to_jump_on_floor() -> void:
	_input.move_axis = 1.0
	_sim.step(SHORT_RUN_STEPS)
	_sim.press_jump()
	assert_eq(_sim.state(), PlayerState.JUMP)


func test_jump_to_fall_at_apex() -> void:
	_sim.press_jump()
	var steps: int = _sim.step_until(func() -> bool: return _sim.state() != PlayerState.JUMP,
			_sim.steps_for(_isak.physics.time_to_apex_s))
	assert_eq(_sim.state(), PlayerState.FALL, "Tras el apogeo debe caer (pasos: %d)" % steps)
	assert_false(_isak.is_on_floor())


func test_fall_to_idle_on_landing() -> void:
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _sim.state() == PlayerState.FALL)
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.FALL)
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_true(_isak.is_on_floor())


func test_fall_to_run_on_landing_with_input() -> void:
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _sim.state() == PlayerState.FALL)
	_input.move_axis = 1.0
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.FALL)
	assert_eq(_sim.state(), PlayerState.RUN)


func test_pulse_from_idle_when_unlocked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	watch_signals(_isak)
	_input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)
	assert_signal_emitted(_isak, "pulse_fired")


func test_pulse_from_run_when_unlocked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.move_axis = 1.0
	_sim.step(SHORT_RUN_STEPS)
	_input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)


func test_pulse_blocked_when_locked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, false)
	watch_signals(_isak)
	_input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_signal_not_emitted(_isak, "pulse_fired")


func test_pulse_blocks_horizontal_movement() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.move_axis = 1.0
	_sim.step(SHORT_RUN_STEPS)
	var speed_before: float = _isak.velocity.x
	_input.pulse_pressed = true
	_sim.step(SHORT_RUN_STEPS)
	assert_eq(_sim.state(), PlayerState.PULSE)
	assert_lt(_isak.velocity.x, speed_before, "Durante el pulso solo hay friccion")


func test_pulse_to_idle_when_finished() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.pulse_pressed = true
	_sim.step()
	var steps: int = _sim.step_until(func() -> bool: return _sim.state() != PlayerState.PULSE,
			_sim.steps_for(_isak.abilities.pulse_duration_s))
	assert_eq(_sim.state(), PlayerState.IDLE, "El pulso debe acabar en Idle (pasos: %d)" % steps)
	assert_gte(float(steps) * _sim.delta, _isak.abilities.pulse_duration_s - _sim.delta, "No debe acabar antes de tiempo")


func test_hurt_then_back_to_idle() -> void:
	watch_signals(_isak)
	assert_true(_isak.take_hit(1.0))
	assert_eq(_sim.state(), PlayerState.HURT)
	assert_true(_isak.is_invulnerable())
	assert_signal_emitted(_isak, "hurt")
	assert_false(_isak.take_hit(1.0), "Invulnerable: el segundo golpe se ignora")
	_sim.step_until(func() -> bool: return _sim.state() == PlayerState.IDLE)
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_true(_isak.is_on_floor())


func test_invulnerability_expires() -> void:
	_isak.take_hit()
	_sim.step(_sim.steps_for(_isak.abilities.hurt_invulnerability_s))
	assert_false(_isak.is_invulnerable())
	assert_true(_isak.take_hit())


func test_any_state_to_dead() -> void:
	var setups: Array[Callable] = [
		func() -> void: pass,
		func() -> void:
			_input.move_axis = 1.0
			_sim.step(SHORT_RUN_STEPS),
		func() -> void: _sim.press_jump(),
		func() -> void: _isak.take_hit(),
	]
	for setup: Callable in setups:
		_input.move_axis = 0.0
		_isak.change_state(PlayerState.IDLE)
		setup.call()
		var from: StringName = _sim.state()
		watch_signals(_isak)
		_isak.die()
		assert_eq(_sim.state(), PlayerState.DEAD, "De %s a Dead" % from)
		assert_signal_emitted(_isak, "died")
		# Sale de Dead solo reiniciando el estado a mano para el siguiente caso.
		_isak.change_state(PlayerState.IDLE)
		_sim.settle()


func test_dead_ignores_input() -> void:
	_isak.die()
	_input.move_axis = 1.0
	_input.jump_pressed = true
	_sim.step(SHORT_RUN_STEPS)
	assert_eq(_sim.state(), PlayerState.DEAD)
	assert_almost_eq(_isak.velocity.x, 0.0, 0.001)


func test_dead_when_sync_rate_reaches_zero() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_eq(_sim.state(), PlayerState.DEAD)


func test_idle_time_grows_and_resets_on_move() -> void:
	var start: float = _isak.get_idle_time()
	assert_almost_eq(start, 0.0, _sim.delta * 2.0)
	_sim.step(SHORT_RUN_STEPS)
	assert_almost_eq(_isak.get_idle_time() - start, SHORT_RUN_STEPS * _sim.delta, 0.0001)
	_input.move_axis = 1.0
	_sim.step()
	assert_eq(_isak.get_idle_time(), 0.0)
	_input.move_axis = 0.0
	_sim.step_until(func() -> bool: return _isak.get_idle_time() > 0.0)
	assert_eq(_sim.state(), PlayerState.IDLE)


func test_terminal_animation_after_threshold_and_input_cuts_it() -> void:
	watch_signals(_isak)
	_sim.step(_sim.steps_for(_isak.terminal_idle_threshold_s))
	assert_signal_emitted(_isak, "idle_terminal_started")
	assert_true(_isak.is_terminal_playing())
	_input.run_held = true
	_sim.step()
	assert_false(_isak.is_terminal_playing(), "Cualquier input corta la terminal")
	assert_eq(_isak.get_idle_time(), 0.0)


## Escala 1280x720: cuadros de 128x128 con los pies en el origen de Isak y
## capsula de colision apoyada en el suelo.
func test_sprite_and_hitbox_feet_at_origin() -> void:
	var sprite: AnimatedSprite2D = _isak.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	assert_eq(Vector2i(frame.get_size()), Vector2i(128, 128), "Canvas de Isak de 128x128")
	assert_true(sprite.centered)
	assert_eq(sprite.position + sprite.offset + Vector2(0.0, frame.get_height() * 0.5), Vector2.ZERO,
			"El borde inferior del cuadro (pies) cae en el origen")
	var hitbox: CollisionShape2D = _isak.get_node("Hitbox") as CollisionShape2D
	var capsule: CapsuleShape2D = hitbox.shape as CapsuleShape2D
	assert_eq(hitbox.position.y + capsule.height * 0.5, 0.0, "La capsula apoya en los pies")
	assert_eq(Vector2(capsule.radius * 2.0, capsule.height), _isak.hitbox_size)
