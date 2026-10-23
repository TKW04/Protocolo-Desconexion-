# Seccion en bucle del Mundo 2 (2026-10-22, paso 5 de docs/propuesta-mundo-2.md
# §8, §3.5) en la sala scenes/levels/bucle_test.tscn (banda de las filas 20-44,
# periodo 24, salida en las columnas 16-18): al llegar el borde de arriba de la
# camara a la banda sin la salida, camara e Isak bajan 24 filas juntos (se ve lo
# mismo), el cartel cuenta, EventBus.loop_wrapped (reloj), lo de la banda vuelve
# a su estado inicial, la pista parpadea en la segunda repeticion; con los pies en
# la salida se resuelve y ya no se repite; al reaparecer vuelve a empezar.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BUCLE_SCENE: PackedScene = preload("res://scenes/levels/bucle_test.tscn")
const FRAGILE_SCENE: PackedScene = preload("res://scenes/levels/fragile_card.tscn")
const DT: float = 1.0 / 60.0
const T: float = 64.0
const EPS: float = 0.01
const PERIOD_PX: float = 24.0 * T

var _level: GeneratedLevel
var _isak: Isak
var _sim: IsakSim
var _loop: LoopSection
var _camera: ScrollCamera
var _saved: Dictionary = {}
var _wraps: Array = []


func before_each() -> void:
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DEBUG, GameState.ABILITY_GROUND_POUND]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_wraps.clear()
	_level = BUCLE_SCENE.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)
	_sim.settle()
	_loop = _level.get_node(^"Objects/bucle_1") as LoopSection
	_loop.set_physics_process(false)
	_camera = _isak.get_scroll_camera()
	EventBus.loop_wrapped.connect(_on_wrapped)


func after_each() -> void:
	if EventBus.loop_wrapped.is_connected(_on_wrapped):
		EventBus.loop_wrapped.disconnect(_on_wrapped)
	if is_instance_valid(_level):
		_level.free()
	_level = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _on_wrapped(loop_id: StringName, count: int) -> void:
	_wraps.append([loop_id, count])


## Isak de pie en (col, row) y la camara con su borde de arriba `top_px`.
func _setup(col: float, row: int, top_px: float) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, float(row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_camera.shift(top_px + _camera.get_view_size().y - _camera.get_bottom())


func test_data() -> void:
	assert_eq(_loop.get_period_rows(), 24)
	assert_almost_eq(_loop.get_band_top_px(), 20.0 * T, EPS)
	assert_eq(_loop.get_sign_text(), "Solo uno más (llevas 1)", "Nunca dice «vuelta»")
	assert_false(_loop.get_sign_text().to_lower().contains("vuelta"))


# Pista clara de la salida (2026-10-23, arreglo tras la prueba del usuario: «hay
# que ser mas especificos de que tienes que subir antes de que se reinicie»).
func test_repeat_bar_fills_until_the_loop_repeats() -> void:
	_setup(4, 30, 20.0 * T + PERIOD_PX)
	assert_almost_eq(_loop.get_repeat_progress(), 0.0, EPS, "Recien repetido: barra vacia")
	_setup(4, 30, 20.0 * T + PERIOD_PX * 0.25)
	assert_almost_eq(_loop.get_repeat_progress(), 0.75, EPS, "Tres cuartos del camino")
	_setup(4, 22, 20.0 * T + 1.0)
	assert_gt(_loop.get_repeat_progress(), 0.99, "A punto de repetirse: llena")
	_setup(18, 18, 20.0 * T + 30.0)
	_loop.step(DT)
	assert_true(_loop.is_solved())
	assert_eq(_loop.get_repeat_progress(), 0.0, "Resuelto: ya no hay cuenta")


func test_marker_and_sign_hint_read_the_key_from_the_input_map() -> void:
	_loop.hint_rect = [16, 20, 3, 2]
	_loop.sign_hint = "Sube antes de que se repita"
	_loop.marker_text = "Mantén {tecla:debug} y sube por aquí"
	assert_true(_loop.is_marker_visible(), "Marca fija mientras no se resuelve")
	var key: String = PulsePrompt.key_text(&"debug", "?")
	assert_eq(_loop.get_marker_text(), "Mantén %s y sube por aquí" % key)
	assert_false(_loop.get_marker_text().contains("{"), "Sin marcadores sueltos")
	_setup(18, 18, 20.0 * T + 30.0)
	_loop.step(DT)
	assert_false(_loop.is_marker_visible(), "Resuelto: la marca desaparece")


func test_real_loops_of_the_2_1_and_2_2_say_what_to_do() -> void:
	for spec: Array in [["res://scenes/levels/2-1.tscn", "Objects/bucle_para_ti", "up", "sube"],
			["res://scenes/levels/2-2.tscn", "Objects/bucle_uno_mas", "down", "golpea"]]:
		var level: Node = (load(String(spec[0])) as PackedScene).instantiate()
		var loop := level.get_node(NodePath(String(spec[1]))) as LoopSection
		assert_not_null(loop, String(spec[0]))
		assert_true(loop.is_marker_visible(), "%s: marca de la salida" % spec[0])
		assert_eq(loop.marker_dir, String(spec[2]))
		assert_true(loop.get_marker_text().contains(PulsePrompt.key_text(&"debug", "?")), "Tecla del Debug")
		assert_true(loop.get_marker_text().to_lower().contains(String(spec[3])), "Dice que hacer")
		assert_true(loop.get_sign_hint().contains("antes de que se repita"), "Y antes de cuando")
		for text: String in [loop.get_sign_text(), loop.get_sign_hint(), loop.get_marker_text()]:
			assert_false(text.to_lower().contains("vuelta"), "La UI nunca dice vuelta")
		level.free()
	var help: String = HelpCatalog.shared().text(&"loop_section")
	assert_true(help.contains(PulsePrompt.key_text(&"debug", "?")), "La Q del bucle dice la tecla del Debug")
	assert_true(help.contains("barra") and help.contains("marca"), "Y que mirar: la barra y la marca")
	assert_false(help.contains("{"), "Sin marcadores sueltos")


func test_wraps_camera_and_isak_together() -> void:
	_setup(4, 22, 20.0 * T + 10.0)
	_loop.step(DT)
	assert_eq(_loop.get_count(), 0, "Aun no llega")
	var feet_y: float = _isak.global_position.y
	_camera.shift(-11.0)
	var bottom: float = _camera.get_bottom()
	_loop.step(DT)
	assert_eq(_loop.get_count(), 1, "Se repite")
	assert_almost_eq(_isak.global_position.y, feet_y + PERIOD_PX, EPS, "Isak baja 24 filas")
	assert_almost_eq(_camera.get_bottom(), bottom + PERIOD_PX, EPS, "Y la camara con el")
	assert_almost_eq(_isak.get_camera().global_position.y, _camera.get_center().y, EPS)
	assert_eq(_wraps, [[&"bucle_1", 1]], "EventBus.loop_wrapped (reloj)")
	assert_eq(_loop.get_sign_text(), "Solo uno más (llevas 2)")
	assert_false(_loop.is_hint_visible(), "La pista no sale en la primera")


func test_hint_blinks_on_the_second_repeat() -> void:
	for i: int in 2:
		_setup(4, 22, 20.0 * T - 1.0)
		_loop.step(DT)
	assert_eq(_loop.get_count(), 2)
	assert_true(_loop.is_hint_visible(), "Segunda repeticion: glitch en la salida")
	for i: int in 40:
		_loop.step(DT)
	assert_false(_loop.is_hint_visible(), "Dura 0,5 s")


func test_exit_solves_the_loop() -> void:
	_setup(18, 18, 20.0 * T + 30.0)
	_loop.step(DT)
	assert_true(_loop.is_solved(), "Con los pies en la salida")
	assert_false(_loop.is_help_available(), "Resuelto: sin Q")
	_camera.shift(-200.0)
	var feet_y: float = _isak.global_position.y
	_loop.step(DT)
	assert_eq(_loop.get_count(), 0, "Ya no se repite")
	assert_almost_eq(_isak.global_position.y, feet_y, EPS)


func test_band_objects_go_back_to_their_start() -> void:
	var card := FRAGILE_SCENE.instantiate() as FragileCard
	card.position = Vector2(12.0 * T, 30.0 * T)
	card.set_physics_process(false)
	_level.get_node(^"Objects").add_child(card)
	card.break_now()
	assert_false(card.is_solid())
	_setup(4, 22, 20.0 * T - 1.0)
	_loop.step(DT)
	assert_true(card.is_solid(), "La tarjeta de la banda vuelve a estar entera")


func test_respawn_starts_over() -> void:
	_setup(4, 22, 20.0 * T - 1.0)
	_loop.step(DT)
	assert_eq(_loop.get_count(), 1)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(_loop.get_count(), 0)
	assert_false(_loop.is_solved())


func test_eco_moves_with_isak() -> void:
	var eco := EcoCompanion.attach(_isak, _level)
	eco.auto_advance = false
	var before: Vector2 = eco.global_position
	_setup(4, 22, 20.0 * T - 1.0)
	_loop.step(DT)
	assert_almost_eq(eco.global_position.y, before.y + PERIOD_PX, EPS, "Eco baja con Isak")
