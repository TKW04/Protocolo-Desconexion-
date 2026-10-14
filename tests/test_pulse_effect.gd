# Pruebas del efecto visual del pulso: se crea al entrar en Pulse, se libera al
# salir, su tamano sale de pulse_radius_px y no aparece si el pulso esta bloqueado.
# Tambien valida los cuadros: lienzo multiplo de 8, fondo transparente y solo
# colores de assets/palettes/effects_pulse.gpl. PulseArea (zona de golpe) y la
# onda comparten centro: el celular.
# Los cuadros se dibujan en pixeles de arte de PulseEffect.PIXEL_SIZE px y se
# amplian: el radio medido en px de pantalla puede pasarse hasta un pixel de
# arte (el bloque del borde exterior), de ahi la tolerancia RADIUS_TOLERANCE.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const PALETTE_PATH: String = "res://assets/palettes/effects_pulse.gpl"
const RADIUS_TOLERANCE: float = PulseEffect.PIXEL_SIZE

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


func _fire_pulse() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_input.pulse_pressed = true
	_sim.step()


# --- Ciclo de vida ---

func test_effect_created_on_pulse() -> void:
	_fire_pulse()
	assert_eq(_sim.state(), PlayerState.PULSE)
	var fx: PulseEffect = _isak.get_pulse_effect()
	assert_not_null(fx, "Debe existir la onda al entrar en Pulse")
	assert_eq(fx.get_parent(), _isak, "La onda sigue a Isak")
	assert_eq(fx.position, Vector2(_isak.pulse_effect_origin.x * _isak.facing, _isak.pulse_effect_origin.y),
			"Nace en el celular")


func test_effect_mirrors_when_facing_left() -> void:
	_isak.facing = -1.0
	_fire_pulse()
	assert_lt(_isak.get_pulse_effect().position.x, 0.0, "Mirando a la izquierda el celular esta a la izquierda")


func test_pulse_area_centered_on_phone_and_effect() -> void:
	for facing: float in [1.0, -1.0]:
		_isak.facing = facing
		_fire_pulse()
		var area: Area2D = _isak.get_node("PulseArea") as Area2D
		var phone := Vector2(_isak.pulse_effect_origin.x * facing, _isak.pulse_effect_origin.y)
		assert_eq(area.position, phone, "PulseArea centrada en el celular (facing %s)" % facing)
		assert_eq(area.position, _isak.get_pulse_effect().position, "La onda coincide con la zona de golpe")
		var circle: CircleShape2D = (area.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
		assert_eq(circle.radius, _isak.abilities.pulse_radius_px, "Radio de la zona = pulse_radius_px")
		_sim.step_until(func() -> bool: return _sim.state() != PlayerState.PULSE,
				_sim.steps_for(_isak.abilities.pulse_duration_s))


func test_phone_origin_on_art_pixel_grid() -> void:
	# El centro de la onda cae en la rejilla de pixeles de arte del sprite de Isak.
	assert_eq(int(_isak.pulse_effect_origin.x) % PulseEffect.PIXEL_SIZE, 0)
	assert_eq(int(_isak.pulse_effect_origin.y) % PulseEffect.PIXEL_SIZE, 0)


func test_effect_advances_and_freed_on_exit() -> void:
	_fire_pulse()
	var fx: PulseEffect = _isak.get_pulse_effect()
	watch_signals(fx)
	var count: int = fx.get_frame_count()
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.PULSE,
			_sim.steps_for(_isak.abilities.pulse_duration_s))
	assert_ne(_sim.state(), PlayerState.PULSE)
	assert_signal_emitted(fx, "finished", "La onda termina con el estado")
	assert_eq(fx.get_frame_index(), count - 1, "Llega al ultimo cuadro")
	assert_null(_isak.get_pulse_effect())
	assert_true(fx.is_queued_for_deletion(), "Se libera al salir de Pulse")
	await wait_process_frames(1)
	assert_false(is_instance_valid(fx))


func test_effect_freed_when_pulse_interrupted() -> void:
	_fire_pulse()
	var fx: PulseEffect = _isak.get_pulse_effect()
	_isak.take_hit(1.0)
	assert_eq(_sim.state(), PlayerState.HURT)
	assert_true(fx.is_queued_for_deletion(), "Un golpe que corta el pulso libera la onda")


func test_no_effect_when_pulse_locked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, false)
	_input.pulse_pressed = true
	_sim.step()
	assert_ne(_sim.state(), PlayerState.PULSE)
	assert_null(_isak.get_pulse_effect())
	for child: Node in _isak.get_children():
		assert_false(child is PulseEffect, "No debe haber ninguna onda colgando de Isak")


# --- Tamano y cuadros ---

func test_frames_match_duration_at_24_fps() -> void:
	_fire_pulse()
	var fx: PulseEffect = _isak.get_pulse_effect()
	assert_eq(fx.get_frame_count(), roundi(_isak.abilities.pulse_duration_s * PulseEffect.FPS))


func test_max_size_matches_pulse_radius() -> void:
	_fire_pulse()
	var fx: PulseEffect = _isak.get_pulse_effect()
	var radius: float = _isak.abilities.pulse_radius_px
	assert_eq(fx.get_max_radius_px(), roundi(radius))
	var count: int = fx.get_frame_count()
	assert_eq(PulseEffect.ring_radius(radius, count - 1, count), roundi(radius), "El ultimo anillo mide el radio")
	assert_almost_eq(float(_measure_radius(PulseEffect.build_image(radius, count - 1, count))), radius,
			RADIUS_TOLERANCE, "El pixel opaco mas lejano esta a pulse_radius_px del centro")


func test_size_scales_with_radius() -> void:
	for radius: float in [24.0, 48.0, 61.0, 96.0]:
		var side: int = PulseEffect.canvas_size_for(radius)
		assert_eq(side % 8, 0, "Lienzo multiplo de 8 para radio %s" % radius)
		assert_gte(side, 2 * roundi(radius) + 1, "Cabe el anillo para radio %s" % radius)
		var last: Image = PulseEffect.build_image(radius, 7, 8)
		assert_eq(last.get_width(), side, "El cuadro mide el lienzo para radio %s" % radius)
		# Un radio impar no cae en la rejilla de arte: se ajusta al pixel de arte mas cercano.
		var snapped: int = PulseEffect.ring_radius(radius, 7, 8)
		assert_almost_eq(float(snapped), radius, float(PulseEffect.PIXEL_SIZE), "Radio en la rejilla de arte para %s" % radius)
		assert_almost_eq(float(_measure_radius(last)), float(snapped), RADIUS_TOLERANCE, "Radio medido para radio %s" % radius)


func test_ring_grows_every_frame() -> void:
	var radius: float = 96.0
	var previous: int = 0
	for i: int in 8:
		var r: int = PulseEffect.ring_radius(radius, i, 8)
		assert_gt(r, previous, "El anillo crece en el cuadro %d" % i)
		previous = r


func test_frames_use_palette_and_transparent_background() -> void:
	var palette: Array[Color] = _load_gpl(PALETTE_PATH)
	assert_eq(palette.size(), PulseEffect.PALETTE.size(), "El script copia la paleta .gpl")
	for color: Color in PulseEffect.PALETTE:
		assert_true(palette.has(color), "Color %s en la paleta" % color.to_html(false))
	for image: Image in PulseEffect.build_images(96.0, 8):
		var side: int = image.get_width()
		assert_eq(image.get_height(), side)
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(side - 1, 0), Vector2i(0, side - 1), Vector2i(side - 1, side - 1)]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "Esquina transparente")
		var bad: int = 0
		for y: int in side:
			for x: int in side:
				var c: Color = image.get_pixel(x, y)
				if c.a == 0.0:
					continue
				if c.a != 1.0 or not palette.has(Color(c.r, c.g, c.b)):
					bad += 1
		assert_eq(bad, 0, "Solo colores de la paleta, opacos o transparentes")


func test_alpha_fades_and_stays_translucent() -> void:
	var previous: float = 1.0
	for i: int in 8:
		var a: float = PulseEffect.frame_alpha(i, 8)
		assert_lt(a, 1.0, "Siempre con transparencia")
		assert_lte(a, previous, "No vuelve a aparecer")
		previous = a


# --- Apoyo ---

func _measure_radius(image: Image) -> int:
	var c: int = image.get_width() >> 1
	var best: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				best = maxi(best, roundi(Vector2(x - c, y - c).length()))
	return best


func _load_gpl(path: String) -> Array[Color]:
	var colors: Array[Color] = []
	var text: String = FileAccess.get_file_as_string(path)
	for line: String in text.split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 3 and fields[0].is_valid_int() and fields[1].is_valid_int() and fields[2].is_valid_int():
			colors.append(Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()))
	return colors
