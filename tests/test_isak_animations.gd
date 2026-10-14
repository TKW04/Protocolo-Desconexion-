# Pruebas del arte y de las animaciones por fase de Isak (scenes/player/isak_frames.tres):
# cuadros de 128x128 con los pies en la fila base, animaciones referenciadas
# por Isak.ANIM_*, salto por velocidad vertical, aterrizaje, pulso, golpe,
# muerte (se queda en el ultimo cuadro) y terminal (intro -> bucle -> salida).
# La fisica avanza con Isak.step(); el AnimatedSprite2D avanza en tiempo real,
# asi que las pruebas que esperan el final de una animacion suben speed_scale.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const FRAME_SIZE: Vector2i = Vector2i(128, 128)
## Acelera el sprite para no esperar la duracion real de las animaciones.
const FAST_SPEED_SCALE: float = 20.0
## Distancia maxima (px) entre pulse_effect_origin y un pixel opaco del celular.
const PHONE_TOLERANCE_PX: int = 3

var _sim: IsakSim
var _isak: Isak
var _input: PlayerInput
var _sprite: AnimatedSprite2D
var _pulse_was_unlocked: bool


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_sim = IsakSim.new()
	add_child_autofree(_sim.build_flat_world())
	_sim.take_manual_control()
	_isak = _sim.isak
	_input = _sim.input
	_sprite = _isak.get_node("AnimatedSprite2D") as AnimatedSprite2D
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _anim_constants() -> Array[StringName]:
	var out: Array[StringName] = []
	var constants: Dictionary = (Isak as Script).get_script_constant_map()
	for key: String in constants:
		if key.begins_with("ANIM_"):
			out.append(constants[key])
	return out


func _wait_animation_end(timeout_s: float = 2.0) -> void:
	_sprite.speed_scale = FAST_SPEED_SCALE
	await wait_until(func() -> bool: return not _sprite.is_playing(), timeout_s)


# --- Arte ---

func test_every_referenced_animation_exists() -> void:
	var anims: Array[StringName] = _anim_constants()
	assert_gt(anims.size(), 10, "Isak declara sus animaciones en constantes ANIM_*")
	for anim: StringName in anims:
		assert_true(_sprite.sprite_frames.has_animation(anim), "isak_frames.tres tiene '%s'" % anim)
		assert_gt(_sprite.sprite_frames.get_frame_count(anim), 0, "'%s' tiene cuadros" % anim)


func test_all_frames_128_with_feet_on_last_row() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	for anim: StringName in frames.get_animation_names():
		for i: int in frames.get_frame_count(anim):
			var image: Image = frames.get_frame_texture(anim, i).get_image()
			assert_eq(Vector2i(image.get_size()), FRAME_SIZE, "%s %d: 128x128" % [anim, i])
			assert_eq(image.get_used_rect().end.y, image.get_height(), "%s %d: pies en la fila base" % [anim, i])


## Sin temblor: pies quietos en la fila base y en la x comun (64), altura
## ~96 px y pocos pixeles cambiando entre cuadros consecutivos (incluido el
## empalme del bucle). Idle: importado con --stabilize (el ruido del arte de IA
## cambiaba ~1100 px por cuadro). Terminal: un instante de cada 4 de la hoja y
## --stabilize (antes los pies saltaban 2 px en cada cuadro y cambiaban ~2700 px).
func test_idle_is_stable() -> void:
	_assert_stable(Isak.ANIM_IDLE, 400, 150)


func test_terminal_is_stable() -> void:
	_assert_stable(Isak.ANIM_TERMINAL_LOOP, 400, 150)
	# intro y salida mueven el brazo: solo se limita el maximo
	_assert_stable(Isak.ANIM_TERMINAL_INTRO, 1000, 1000)
	_assert_stable(Isak.ANIM_TERMINAL_OUTRO, 1000, 1000)


func _assert_stable(anim: StringName, max_changed: int, max_mean: int) -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	var count: int = frames.get_frame_count(anim)
	var feet_min: float = INF
	var feet_max: float = -INF
	var total_changed: int = 0
	var prev: Image = frames.get_frame_texture(anim, count - 1).get_image()
	for i: int in count:
		var image: Image = frames.get_frame_texture(anim, i).get_image()
		var used: Rect2i = image.get_used_rect()
		assert_eq(used.end.y, 128, "%s %d: pies en la fila 127" % [anim, i])
		assert_almost_eq(used.size.y, 96, 2, "%s %d: ~96 px de alto" % [anim, i])
		var xs: Array[int] = []
		for y: int in range(used.end.y - 7, used.end.y):
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					xs.append(x)
		var feet_x: float = (xs.min() + xs.max() + 1) / 2.0
		feet_min = minf(feet_min, feet_x)
		feet_max = maxf(feet_max, feet_x)
		var changed: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var a: Color = image.get_pixel(x, y)
				var b: Color = prev.get_pixel(x, y)
				# el importador de Godot rellena el RGB de los transparentes
				if (a.a > 0.0 or b.a > 0.0) and a != b:
					changed += 1
		if i > 0 or frames.get_animation_loop(anim):
			assert_lt(changed, max_changed, "%s %d: menos de %d px cambian respecto al anterior" % [anim, i, max_changed])
			total_changed += changed
		prev = image
	assert_lte(feet_max - feet_min, 1.0, "%s: los pies no se desplazan mas de 1 px" % anim)
	assert_almost_eq(feet_min, 64.0, 1.0, "%s: pies en la x comun (centro del canvas)" % anim)
	assert_lt(total_changed / count, max_mean, "%s: media de pixeles cambiados por cuadro < %d" % [anim, max_mean])


func test_one_shot_animations_do_not_loop() -> void:
	for anim: StringName in [Isak.ANIM_PULSE, Isak.ANIM_HURT, Isak.ANIM_DEATH, Isak.ANIM_JUMP_LAND,
			Isak.ANIM_TERMINAL_INTRO, Isak.ANIM_TERMINAL_OUTRO]:
		assert_false(_sprite.sprite_frames.get_animation_loop(anim), "%s no es bucle" % anim)
	for anim: StringName in [Isak.ANIM_IDLE, Isak.ANIM_WALK, Isak.ANIM_RUN, Isak.ANIM_TERMINAL_LOOP]:
		assert_true(_sprite.sprite_frames.get_animation_loop(anim), "%s es bucle" % anim)


# --- Salto por fases ---

func test_air_animation_follows_vertical_speed() -> void:
	_sim.press_jump()
	assert_eq(_isak.get_animation(), Isak.ANIM_JUMP_RISE, "Al saltar: subida, sin anticipacion")
	assert_eq(_isak.get_animation_frame(), 0)
	_sim.step_until(func() -> bool: return absf(_isak.velocity.y) < Isak.AIR_APEX_SPEED)
	_sim.step()
	assert_eq(_isak.get_animation(), Isak.ANIM_JUMP_APEX, "Cerca del apogeo")
	_sim.step_until(func() -> bool: return _isak.velocity.y > Isak.AIR_APEX_SPEED * 2.0)
	assert_eq(_isak.get_animation(), Isak.ANIM_JUMP_FALL, "Cayendo")
	assert_false(_sprite.is_playing(), "El cuadro lo elige la velocidad, no el tiempo")


func test_landing_plays_land_then_idle_without_blocking() -> void:
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _sim.state() == PlayerState.FALL)
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.FALL)
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_eq(_isak.get_animation(), Isak.ANIM_JUMP_LAND)
	await _wait_animation_end()
	assert_eq(_isak.get_animation(), Isak.ANIM_IDLE, "Tras aterrizar vuelve a idle")
	_sim.press_jump()
	assert_eq(_sim.state(), PlayerState.JUMP, "El aterrizaje no bloquea el salto")


func test_landing_does_not_block_jump_during_land_animation() -> void:
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _sim.state() == PlayerState.FALL)
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.FALL)
	assert_eq(_isak.get_animation(), Isak.ANIM_JUMP_LAND)
	_sim.press_jump()
	assert_eq(_sim.state(), PlayerState.JUMP, "Se puede saltar en mitad del aterrizaje")


# --- Pulso, golpe y muerte ---

func test_pulse_wave_born_on_phone_frame() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)
	assert_eq(_isak.get_animation(), Isak.ANIM_PULSE)
	assert_eq(_isak.get_animation_frame(), Isak.PULSE_WAVE_FRAME, "La onda nace en el cuadro previsto")
	assert_not_null(_isak.get_pulse_effect(), "La onda existe desde ese cuadro")
	# En ese cuadro hay un pixel opaco (celular) junto a pulse_effect_origin.
	var image: Image = _sprite.sprite_frames.get_frame_texture(Isak.ANIM_PULSE, Isak.PULSE_WAVE_FRAME).get_image()
	var phone := Vector2i(FRAME_SIZE.x / 2, FRAME_SIZE.y) + Vector2i(_isak.pulse_effect_origin)
	var found: bool = false
	for y: int in range(phone.y - PHONE_TOLERANCE_PX, phone.y + PHONE_TOLERANCE_PX + 1):
		for x: int in range(phone.x - PHONE_TOLERANCE_PX, phone.x + PHONE_TOLERANCE_PX + 1):
			if image.get_pixel(x, y).a > 0.5:
				found = true
	assert_true(found, "El celular del cuadro %d esta en pulse_effect_origin" % Isak.PULSE_WAVE_FRAME)


func test_pulse_animation_fits_pulse_duration() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	var length: float = frames.get_frame_count(Isak.ANIM_PULSE) / frames.get_animation_speed(Isak.ANIM_PULSE)
	assert_almost_eq(length, _isak.abilities.pulse_duration_s, 0.01, "Pulso: animacion = pulse_duration_s")


func test_hurt_plays_hurt_animation_within_duration() -> void:
	_isak.take_hit(1.0)
	assert_eq(_isak.get_animation(), Isak.ANIM_HURT)
	var frames: SpriteFrames = _sprite.sprite_frames
	var length: float = frames.get_frame_count(Isak.ANIM_HURT) / frames.get_animation_speed(Isak.ANIM_HURT)
	assert_lte(length, _isak.abilities.hurt_duration_s, "La animacion de golpe cabe en hurt_duration_s")


func test_invulnerability_blinks_and_stops() -> void:
	_isak.take_hit(1.0)
	var dimmed: bool = false
	for i: int in _sim.frames(0.3):
		_sim.step()
		dimmed = dimmed or _sprite.modulate.a < 1.0
	assert_true(dimmed, "Parpadea durante la invulnerabilidad")
	_sim.step(_sim.steps_for(_isak.abilities.hurt_invulnerability_s))
	assert_eq(_sprite.modulate.a, 1.0, "Sin parpadeo al acabar la invulnerabilidad")


func test_dead_ends_on_last_frame() -> void:
	_isak.die()
	assert_eq(_isak.get_animation(), Isak.ANIM_DEATH)
	await _wait_animation_end()
	var last: int = _sprite.sprite_frames.get_frame_count(Isak.ANIM_DEATH) - 1
	assert_eq(_isak.get_animation(), Isak.ANIM_DEATH, "Sigue en la muerte")
	assert_eq(_isak.get_animation_frame(), last, "Se queda en el ultimo cuadro")
	assert_false(_sprite.is_playing(), "Sin bucle")


# --- Terminal holografica ---

func test_terminal_intro_loop_outro_and_cut_by_input() -> void:
	_sim.step(_sim.steps_for(_isak.terminal_idle_threshold_s))
	assert_eq(_isak.get_animation(), Isak.ANIM_TERMINAL_INTRO, "Tras el umbral empieza la intro")
	await _wait_animation_end()
	assert_eq(_isak.get_animation(), Isak.ANIM_TERMINAL_LOOP, "Intro -> bucle")
	assert_true(_sprite.is_playing())
	_sprite.speed_scale = 1.0
	_input.run_held = true
	_sim.step()
	_input.run_held = false
	assert_false(_isak.is_terminal_playing(), "El input corta la terminal")
	assert_eq(_sim.state(), PlayerState.IDLE, "Sin cambiar la logica de Idle")
	assert_eq(_isak.get_animation(), Isak.ANIM_TERMINAL_OUTRO, "Corte suave: salida del holograma")
	await _wait_animation_end()
	assert_eq(_isak.get_animation(), Isak.ANIM_IDLE, "Salida -> idle")


func test_terminal_cut_by_movement_goes_to_run() -> void:
	_sim.step(_sim.steps_for(_isak.terminal_idle_threshold_s))
	assert_eq(_isak.get_animation(), Isak.ANIM_TERMINAL_INTRO)
	_input.move_axis = 1.0
	_sim.step()
	assert_eq(_sim.state(), PlayerState.RUN, "Moverse corta la terminal al instante")
	assert_eq(_isak.get_animation(), Isak.ANIM_WALK)
