# Sala de prueba del pop-up translucido (data/levels/overlay_test.json, escena
# generada scenes/levels/overlay_test.tscn; paso 7 de docs/propuesta-1-2.md §10,
# 2026-10-16) con el Isak real: el pop-up tapa la plataforma de una via de la
# subida, con el Debug se ve a traves, el pulso desde el suelo lo cierra y la
# subida a la terminal funciona con el pop-up abierto (no bloquea).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/overlay_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _overlay: OverlayPopup


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.debug_energy = GameState.get_debug_energy_max()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_overlay = _level.get_node(^"Objects/overlay_1") as OverlayPopup
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()


func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


func test_overlay_hides_the_platform_and_debug_sees_through() -> void:
	assert_eq(_level.level_id, "overlay_test")
	assert_not_null(_overlay)
	assert_eq(HelpCatalog.help_id_of(_overlay), &"overlay_popup")
	var platform := Vector2(13.5 * TILE, 9.1 * TILE)
	_overlay.advance(0.0)
	assert_true(_overlay.hides_point(platform), "Sin Debug no se ve la plataforma")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "La sala da el Debug")
	DebugMode.step(DT, true)
	for i: int in 180:
		DebugMode.step(DT, true)
		if DebugMode.get_intensity() >= 1.0:
			break
	_overlay.advance(0.0)
	assert_false(_overlay.hides_point(platform), "Con el Debug se ve a traves")


func test_climb_works_with_the_overlay_open() -> void:
	await _stand(14, 8)
	assert_true(_isak.is_on_floor(), "La plataforma tapada existe y se pisa")
	assert_true(_overlay.is_open())


func test_pulse_from_the_floor_closes_it() -> void:
	await _stand(11, 10)
	_sim.input.pulse_pressed = true
	_sim.step(30)
	assert_eq(_overlay.get_state(), OverlayPopup.State.CLOSING, "El boton se alcanza de pie en el suelo")
	await wait_physics_frames(30)
	assert_true(_overlay.is_closed())
	assert_false(_overlay.hides_point(Vector2(13.5 * TILE, 9.1 * TILE)), "Cerrado ya no tapa")
