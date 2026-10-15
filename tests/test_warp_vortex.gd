# Vortice de llegada y salida de Isak (WarpVortex, data/warp.json): espera con
# `held`, se abre, gira y se cierra; Isak se muestra al empezar el cierre, se
# materializa en pasos discretos y recupera el control al terminar (llegada) o
# se desvanece y queda sin control (salida). Sin control, Isak no se mueve ni
# recibe golpes.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const DT: float = 1.0 / 60.0

var _root: Node2D
var _isak: Isak
var _input: PlayerInput


func before_each() -> void:
	_root = Node2D.new()
	add_child_autofree(_root)
	_isak = ISAK_SCENE.instantiate() as Isak
	_input = PlayerInput.new()
	_isak.input = _input
	_isak.position = Vector2(200.0, 300.0)
	_root.add_child(_isak)


func _run(vortex: WarpVortex, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds and not vortex.is_done():
		vortex.advance(DT)
		t += DT


func test_frames_resource_has_the_three_animations() -> void:
	var frames := load(String(WarpVortex.load_data()["frames"])) as SpriteFrames
	for anim: StringName in [WarpVortex.ANIM_OPEN, WarpVortex.ANIM_SPIN, WarpVortex.ANIM_CLOSE]:
		assert_true(frames.has_animation(anim), String(anim))
		assert_gt(frames.get_frame_count(anim), 2)
	assert_true(frames.get_animation_loop(WarpVortex.ANIM_SPIN))
	assert_false(frames.get_animation_loop(WarpVortex.ANIM_CLOSE))


func test_held_arrival_waits_for_release_with_isak_hidden_and_locked() -> void:
	var vortex := WarpVortex.arrive(_isak, _root, true)
	_run(vortex, 3.0)
	assert_eq(vortex.get_phase(), WarpVortex.Phase.HELD)
	assert_false(vortex.get_sprite().visible, "Sin soltar no se ve")
	assert_eq(_isak.modulate.a, 0.0, "Isak oculto")
	assert_true(_isak.is_warp_hidden())
	assert_lt(vortex.get_index(), _isak.get_index(), "Se dibuja detras de Isak")
	assert_almost_eq(vortex.global_position, _isak.global_position + Vector2(0.0, -48.0), Vector2.ONE)


func test_arrival_reveals_on_close_materializes_and_returns_control() -> void:
	var vortex := WarpVortex.arrive(_isak, _root, true)
	var revealed: Array[float] = []
	_isak.warp_revealed.connect(func() -> void: revealed.append(_isak.modulate.a))
	assert_true(vortex.release())
	vortex.advance(DT)
	assert_eq(vortex.get_animation(), WarpVortex.ANIM_OPEN)
	assert_true(vortex.get_sprite().visible)
	while vortex.get_phase() != WarpVortex.Phase.CLOSE:
		assert_eq(_isak.modulate.a, 0.0, "Oculto mientras se abre y gira")
		vortex.advance(DT)
	assert_eq(revealed.size(), 1, "Se muestra al empezar a cerrarse")
	assert_true(_isak.is_warping(), "Aun sin control")
	var alphas: Array[float] = []
	while not vortex.is_done():
		if alphas.is_empty() or alphas.back() != _isak.modulate.a:
			alphas.append(_isak.modulate.a)
		vortex.advance(DT)
	assert_gt(alphas.size(), 2, "Se materializa por pasos")
	for i: int in range(1, alphas.size()):
		assert_gt(alphas[i], alphas[i - 1], "La opacidad solo sube")
	assert_eq(_isak.modulate.a, 1.0)
	assert_false(_isak.is_warping(), "Control al terminar")
	assert_eq(revealed.size(), 1)


func test_locked_isak_ignores_input_and_hits() -> void:
	WarpVortex.arrive(_isak, _root, true)
	_input.move_axis = 1.0
	var x: float = _isak.global_position.x
	for i: int in 30:
		_isak.step(DT)
	assert_almost_eq(_isak.global_position.x, x, 0.5, "No camina sin control")
	assert_false(_isak.take_hit(1.0), "No recibe golpes en el vortice")
	assert_eq(_isak.input, _input, "La entrada del jugador se conserva")


func test_departure_fades_isak_out_and_keeps_him_locked() -> void:
	var finished: Array[bool] = []
	var vortex := WarpVortex.depart(_isak, _root)
	vortex.finished.connect(func() -> void: finished.append(true))
	assert_eq(_isak.modulate.a, 1.0, "Visible al abrirse")
	assert_false(_isak.is_warp_hidden())
	_run(vortex, 5.0)
	assert_eq(finished.size(), 1)
	assert_eq(_isak.modulate.a, 0.0, "Absorbido")
	assert_true(_isak.is_warping(), "Sin control tras la salida")
