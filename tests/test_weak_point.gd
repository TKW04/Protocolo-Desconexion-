# Pruebas del punto debil reutilizable (scenes/bosses/weak_point.tscn): solo
# visible con el Debug, dibujado por encima del tinte del Debug y por debajo
# del HUD, y con pulso de carmin a carmin_brillo (data/weak_point.json).
extends GutTest

const WEAK_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const DT: float = 1.0 / 60.0
const CARMIN: Color = Color("#e0004a")
const CARMIN_BRILLO: Color = Color("#ff5a8c")
const COLOR_TOLERANCE: float = 0.01

var _saved: Dictionary = {}
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_each() -> void:
	_saved = {
		"energy": GameState.debug_energy,
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
	}
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.debug_energy = _saved.energy
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)


func _debug_on() -> void:
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(_config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)


func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COLOR_TOLERANCE and absf(a.g - b.g) < COLOR_TOLERANCE \
		and absf(a.b - b.b) < COLOR_TOLERANCE


func test_weak_point_has_area_and_group() -> void:
	var wp: WeakPoint = add_child_autofree(WEAK_SCENE.instantiate())
	await wait_process_frames(1)
	assert_true(wp.is_in_group(WeakPoint.GROUP))
	var shapes: Array = wp.get_children().filter(func(n: Node) -> bool: return n is CollisionShape2D)
	assert_eq(shapes.size(), 1, "Tiene su forma de colision")


func test_only_visible_with_debug() -> void:
	var wp: WeakPoint = add_child_autofree(WEAK_SCENE.instantiate())
	await wait_process_frames(1)
	assert_false(wp.is_revealed(), "Sin Debug no se ve")
	_debug_on()
	await wait_process_frames(1)
	assert_true(wp.is_revealed(), "Con Debug se ve")


func test_drawn_above_debug_tint_and_below_hud() -> void:
	var wp: WeakPoint = add_child_autofree(WEAK_SCENE.instantiate())
	var hud: CanvasLayer = add_child_autofree(HUD_SCENE.instantiate())
	await wait_process_frames(1)
	assert_gt(wp.get_draw_layer(), DebugOverlay.OVERLAY_LAYER, "Por encima del tinte del Debug")
	assert_lt(wp.get_draw_layer(), hud.layer, "Por debajo del HUD")


func test_visual_follows_area_position() -> void:
	var wp: WeakPoint = add_child_autofree(WEAK_SCENE.instantiate())
	wp.position = Vector2(320.0, 128.0)
	_debug_on()
	await wait_process_frames(2)
	assert_eq(wp.get_visual_position(), wp.global_position)


func test_pulses_from_carmin_to_carmin_brillo() -> void:
	var hz: float = float(WeakPoint.config()["pulse_hz"])
	assert_true(_color_close(WeakPoint.color_at(0.0), CARMIN), "Empieza en carmin")
	assert_true(_color_close(WeakPoint.color_at(0.5 / hz), CARMIN_BRILLO), "Pico en carmin_brillo")
	assert_true(_color_close(WeakPoint.color_at(1.0 / hz), CARMIN), "Vuelve a carmin")
