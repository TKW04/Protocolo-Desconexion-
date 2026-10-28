# Acechadores del Modo oscuro (2026-10-28, peligros ocultos de las zonas oscuras del
# Mundo 4; docs/propuesta-mundo-4.md §8.1): un Troll o Sticker con `lurk` dentro de
# una DarkZone, en reposo / dormido y fuera de la Linterna, ACECHA (solo se le ven los
# ojos por encima del velo, sin contorno rojo: aun no dana) y no ofrece la Q (la Q lo
# delataria) salvo con el Debug, que lo revela; bajo la luz de la Linterna se ve
# entero. Al atacar por primera vez (el Troll empieza a escribir, el Sticker salta)
# se delata una vez por intento (`lurk_woke`, sonido sfx_w4_lurker_wake) y ya no se
# esconde hasta reaparecer Isak (reset_patrol). Fuera de lo oscuro, `lurk` no hace
# nada; el comportamiento y los tiempos no cambian.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const TROLL_SCENE: PackedScene = preload("res://scenes/enemies/troll.tscn")
const STICKER_SCENE: PackedScene = preload("res://scenes/enemies/sticker.tscn")
const DARK_SCENE: PackedScene = preload("res://scenes/levels/dark_zone.tscn")
const PATH: String = "user://test_dark_lurkers_save.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _zone: DarkZone
var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-30.0 * T, 0.0)
	await wait_physics_frames(1)
	_sim.settle()
	_zone = null


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


## Zona oscura de las columnas 5-34 y las 6 filas sobre el suelo.
func _dark() -> DarkZone:
	_zone = DARK_SCENE.instantiate() as DarkZone
	_zone.position = Vector2(5.0 * T, -6.0 * T)
	_zone.width_tiles = 30
	_zone.height_tiles = 6
	_zone.auto_process = false
	_zone.isak = _isak
	_world.add_child(_zone)
	return _zone


func _stand_at(col: float) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	if _zone != null:
		_zone.refresh()


func _run(nodes: Array, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		for n: Node in nodes:
			n.call(&"step", DT)
		_sim.step()


func _troll(col: float, lurk: bool = true) -> Troll:
	var t := TROLL_SCENE.instantiate() as Troll
	t.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(t)
	t.set_physics_process(false)
	t.facing = -1
	t.target = _isak
	t.lurk = lurk
	t.reset_patrol()
	return t


func _sticker(col: float, lurk: bool = true) -> Sticker:
	var s := STICKER_SCENE.instantiate() as Sticker
	s.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(s)
	s.set_physics_process(false)
	s.target = _isak
	s.lurk = lurk
	return s


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_revealing())


func test_lurking_troll_shows_only_its_eyes_until_it_writes() -> void:
	_dark()
	var t: Troll = _troll(20)
	await wait_physics_frames(2)
	assert_true(t.is_in_dark(), "Bajo el velo (capa DarkOverlay)")
	assert_true(t.is_lurking(), "Acecha: en reposo, a oscuras y sin Linterna")
	assert_false(t.is_help_available(), "Sin Q mientras acecha (la Q lo delataria)")
	watch_signals(t)
	_stand_at(12)
	_run([t], 0.1)
	assert_true(t.is_warning(), "Empieza a escribir: el aviso de siempre (9 cuadros)")
	assert_almost_eq(t.get_warn_s(), 0.75, 0.01)
	assert_signal_emit_count(t, "lurk_woke", 1)
	assert_false(t.is_lurking(), "Al atacar se delata (contorno rojo)")
	assert_true(t.is_help_available())
	_run([t], t.get_interval_s() + 0.2)
	assert_true(t.has_lurk_woken())
	assert_false(t.is_lurking(), "Ya no se esconde en este intento")
	assert_signal_emit_count(t, "lurk_woke", 1, "Una sola vez por intento")
	_stand_at(-20)
	t.reset_patrol()
	assert_true(t.is_lurking(), "Al reaparecer Isak vuelve a acechar")


func test_lurking_sticker_wakes_once_and_chases_as_usual() -> void:
	_dark()
	var s: Sticker = _sticker(20)
	await wait_physics_frames(2)
	assert_true(s.is_lurking())
	assert_false(s.is_help_available())
	watch_signals(s)
	_stand_at(15)
	var x0: float = s.global_position.x
	_run([s], 0.5)
	assert_eq(s.get_state(), Sticker.STATE_CHASE, "Se despierta a 6 tiles como siempre")
	assert_almost_eq(s.global_position.x, x0 - 60.0, 4.0, "Hacia Isak a 120 px/s")
	assert_signal_emit_count(s, "lurk_woke", 1)
	assert_false(s.is_lurking())
	_stand_at(-20)
	_run([s], 0.2)
	s.reset_patrol()
	assert_true(s.is_lurking(), "Al reaparecer Isak vuelve a dormir y acechar")


func test_flashlight_shows_the_lurker() -> void:
	_dark()
	var t: Troll = _troll(10)
	var s: Sticker = _sticker(12)
	await wait_physics_frames(2)
	GameState.meet_ally(GameState.ALLY_LINTERNA)
	_stand_at(11)
	_isak.global_position.y = -3.0 * T
	_zone.refresh()
	assert_true(_zone.is_hole_open())
	assert_false(t.is_lurking(), "Bajo la luz de la Linterna se ve entero")
	assert_false(s.is_lurking())
	assert_true(t.is_help_available(), "Visto, ofrece la Q")


func test_debug_reveals_the_lurker() -> void:
	_dark()
	var t: Troll = _troll(20)
	var s: Sticker = _sticker(24)
	await wait_physics_frames(2)
	_activate_debug()
	assert_true(t.is_lurking(), "Sigue acechando (el Debug no lo despierta)")
	assert_true(t.is_help_available(), "Revelado por el Debug: hay Q")
	assert_true(s.is_help_available())


func test_lurk_does_nothing_outside_the_dark() -> void:
	var t: Troll = _troll(20)
	var s: Sticker = _sticker(24)
	await wait_physics_frames(2)
	assert_false(t.is_in_dark())
	assert_false(t.is_lurking(), "Sin velo no hay nada que lo oculte")
	assert_false(s.is_lurking())
	assert_true(t.is_help_available())


func test_level_data_marks_the_lurkers() -> void:
	var counts: Dictionary = {}
	for id: String in ["4-1", "4-2", "4-3"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % id))
		var n: int = 0
		for e: Dictionary in (parsed as Dictionary)["enemies"]:
			if bool((e.get("params", {}) as Dictionary).get("lurk", false)):
				n += 1
				assert_eq(String(e.get("help_id", "")), "lurker", "%s: ayuda «Acechador»" % e["id"])
		counts[id] = n
	assert_eq(counts, {"4-1": 1, "4-2": 3, "4-3": 2})
	var help: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/help.json"))
	assert_true((help["types"] as Dictionary).has("lurker"))
	var audio: String = FileAccess.get_file_as_string("res://data/audio.json")
	assert_true(audio.contains("\"signal\": \"lurk_woke\""), "Sonido al delatarse")
