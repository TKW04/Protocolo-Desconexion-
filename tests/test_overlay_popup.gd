# Pop-up translucido (overlay_popup; paso 7 de docs/propuesta-1-2.md §10,
# 2026-10-16) con el Isak real sobre un suelo llano: tapa la vista (opacidad
# 0,7 por encima del mundo), no bloquea el paso, se cierra solo con el pulso a
# su boton (cerrado, queda cerrado), con el Debug se ve a traves (0,15 y
# contorno cian) y un anuncio encima del boton impide cerrarlo hasta romperlo
# con el laser.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const OVERLAY_SCENE: PackedScene = preload("res://scenes/levels/overlay_popup.tscn")
const AD_SCENE: PackedScene = preload("res://scenes/levels/ad_cover.tscn")
const DT: float = 1.0 / 60.0

var _world: Node2D
var _sim: IsakSim
var _isak: Isak


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	_isak = _sim.isak
	add_child(_world)
	_sim.take_manual_control()
	await wait_physics_frames(2)
	_sim.settle()


func after_each() -> void:
	if is_instance_valid(_world):
		_world.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()


## Pop-up de 5 x 4 tiles con la esquina en `pos` y el boton en `button` (px).
func _overlay(pos: Vector2, button: Vector2 = Vector2(8.0, 224.0)) -> OverlayPopup:
	var overlay := OVERLAY_SCENE.instantiate() as OverlayPopup
	overlay.object_id = &"overlay_t"
	overlay.text = "Tienes 99+ mensajes que no son importantes"
	overlay.width_tiles = 5
	overlay.height_tiles = 4
	overlay.close_button_position = button
	overlay.position = pos
	_world.add_child(overlay)
	return overlay


func _pulse() -> void:
	_sim.input.pulse_pressed = true
	_sim.step(30)


func _close_fully(overlay: OverlayPopup) -> void:
	for i: int in 40:
		overlay.advance(DT)


func test_covers_the_view_above_the_world_without_blocking() -> void:
	var overlay := _overlay(Vector2(64.0, -256.0))
	await wait_physics_frames(1)
	overlay.advance(0.0)
	assert_almost_eq(overlay.get_current_opacity(), 0.7, 0.001, "70 % de opacidad")
	assert_true(overlay.hides_point(overlay.get_window_rect().get_center()), "Tapa lo que hay detras")
	assert_gt(overlay.get_z(), 0, "Por encima del mundo")
	assert_eq(overlay.get_debug_outline_alpha(), 0.0, "Sin Debug, sin contorno cian")
	assert_true(overlay.is_help_available())
	# Sin colision: ningun cuerpo ni area del pop-up esta en la capa world.
	for node: Node in overlay.find_children("*", "CollisionObject2D", true, false):
		assert_eq((node as CollisionObject2D).collision_layer & 1, 0, "%s no choca con Isak" % node.name)
	# Isak lo atraviesa caminando.
	_sim.input.move_axis = 1.0
	_sim.step(roundi(2.0 / DT))
	_sim.input.move_axis = 0.0
	assert_gt(_isak.global_position.x, overlay.get_window_rect().end.x, "No bloquea el paso")


func test_only_a_pulse_on_the_button_closes_it_for_good() -> void:
	# Boton lejos (arriba a la derecha): el pulso toca la ventana, no el boton.
	var far := _overlay(Vector2(-40.0, -300.0), Vector2(280.0, 24.0))
	_pulse()
	assert_true(far.is_open(), "Un pulso que solo toca la ventana no hace nada")
	far.queue_free()
	await wait_physics_frames(1)
	var overlay := _overlay(Vector2(-40.0, -300.0))
	await wait_physics_frames(1)
	var closed: Array = []
	overlay.closed.connect(func() -> void: closed.append(true))
	_pulse()
	assert_eq(overlay.get_state(), OverlayPopup.State.CLOSING, "El pulso al boton lo cierra")
	assert_false(overlay.is_help_available(), "Cerrandose ya no ayuda")
	_close_fully(overlay)
	assert_true(overlay.is_closed())
	assert_eq(closed.size(), 1)
	assert_eq(overlay.get_current_opacity(), 0.0, "Ya no tapa nada")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	_close_fully(overlay)
	assert_true(overlay.is_closed(), "Cerrado queda cerrado (tambien al reaparecer)")


func test_debug_sees_through_it() -> void:
	var overlay := _overlay(Vector2(64.0, -256.0))
	await wait_physics_frames(1)
	var center: Vector2 = overlay.get_window_rect().get_center()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.step(DT, true)
	for i: int in 180:
		DebugMode.step(DT, true)
		if DebugMode.get_intensity() >= 1.0:
			break
	assert_true(DebugMode.is_active())
	overlay.advance(0.0)
	assert_almost_eq(overlay.get_current_opacity(), 0.15, 0.001, "Con el Debug, casi transparente")
	assert_almost_eq(overlay.get_debug_outline_alpha(), 1.0, 0.001, "Contorno cian «visto con Debug»")
	assert_false(overlay.hides_point(center), "Se ve lo que hay detras")
	assert_true(overlay.is_open(), "Ver a traves no lo cierra")
	DebugMode.reset()
	overlay.advance(0.0)
	assert_true(overlay.hides_point(center), "Sin Debug vuelve a tapar")


func test_ad_cover_protects_the_button_until_the_laser_breaks_it() -> void:
	var overlay := _overlay(Vector2(-40.0, -300.0))
	var ad := AD_SCENE.instantiate() as AdCover
	ad.target_id = &"overlay_t"
	ad.text = "Saltar anuncio en 5…"
	_world.add_child(ad)
	await wait_physics_frames(2)
	assert_true(overlay.is_button_covered())
	assert_eq(ad.get_rect().get_center().round(), overlay.get_button_rect().get_center().round(), "Sobre el boton")
	assert_gt(ad.z_index, overlay.get_z(), "Se dibuja encima de la ventana")
	_pulse()
	assert_true(overlay.is_open(), "Con el anuncio el pulso rebota")
	ad.on_laser_hit(1.0, null)
	_pulse()
	assert_eq(overlay.get_state(), OverlayPopup.State.CLOSING, "Roto el anuncio, el pulso lo cierra")


func test_closing_runs_in_world_time() -> void:
	var overlay := _overlay(Vector2(-40.0, -300.0))
	await wait_physics_frames(1)
	overlay.close()
	GameState.world_time_scale = 0.5
	for i: int in 30:
		overlay._process(DT)
	GameState.world_time_scale = 1.0
	assert_eq(overlay.get_state(), OverlayPopup.State.CLOSING, "Con el Debug el cierre va a la mitad")
	for i: int in 20:
		overlay._process(DT)
	assert_true(overlay.is_closed())
