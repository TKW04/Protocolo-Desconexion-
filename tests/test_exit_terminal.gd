# Terminal de salida (ExitTerminal, scenes/levels/exit_terminal.tscn; 2026-10-15):
# tocarla no termina el nivel; con Isak cerca muestra el prompt y la tecla del
# pulso (Input Map); el pulso de Isak la activa: pantalla encendida, vortice de
# salida, Isak absorbido y EventBus.level_completed una sola vez.
extends GutTest

const TERMINAL_SCENE: PackedScene = preload("res://scenes/levels/exit_terminal.tscn")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const T: float = 64.0
const LONG_STEP_S: float = 5.0

var _root: Node2D
var _terminal: ExitTerminal
var _isak: Isak
var _completed: Array[String] = []
var _saved_pulse: bool


func before_each() -> void:
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_completed.clear()
	EventBus.level_completed.connect(_on_completed)
	_root = Node2D.new()
	add_child_autofree(_root)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0 * T, T)
	shape.shape = rect
	shape.position = Vector2(20.0 * T, 10.5 * T)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_terminal = TERMINAL_SCENE.instantiate() as ExitTerminal
	_terminal.level_id = "test"
	_terminal.text = "Marcar como leído"
	_terminal.position = Vector2(20.0 * T, 8.0 * T)
	_root.add_child(_terminal)
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.input = PlayerInput.new()
	_isak.position = Vector2(5.5 * T, 10.0 * T)
	_root.add_child(_isak)


func after_each() -> void:
	EventBus.level_completed.disconnect(_on_completed)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _on_completed(level_id: String) -> void:
	_completed.append(level_id)


func _place_isak(col: float) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 10.0 * T)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0


func _finish_activation() -> void:
	_terminal.advance(LONG_STEP_S)
	var vortex: WarpVortex = _terminal.get_vortex()
	assert_not_null(vortex, "Se abre el vortice de salida")
	if vortex != null:
		vortex.advance(LONG_STEP_S)


func test_far_isak_sees_the_terminal_off() -> void:
	await wait_physics_frames(4)
	_terminal.advance(0.1)
	assert_eq(_terminal.get_state(), ExitTerminal.State.OFF)
	assert_eq(_terminal.get_animation(), ExitTerminal.ANIM_OFF)
	assert_false(_terminal.is_key_hint_visible())


func test_touching_shows_the_pulse_key_but_does_not_finish() -> void:
	_place_isak(20.0)
	await wait_physics_frames(6)
	_terminal.advance(1.0)
	assert_true(_terminal.is_player_near())
	assert_eq(_terminal.get_state(), ExitTerminal.State.PROMPT)
	assert_eq(_terminal.get_animation(), ExitTerminal.ANIM_PROMPT)
	assert_true(_terminal.is_key_hint_visible(), "Icono de la tecla del pulso")
	assert_eq(_terminal.get_key_hint_text(), "G", "Leida del Input Map (accion pulse)")
	assert_eq(_completed, [] as Array[String], "Tocarla no termina el nivel")
	_place_isak(5.0)
	await wait_physics_frames(6)
	_terminal.advance(0.1)
	assert_eq(_terminal.get_state(), ExitTerminal.State.OFF, "Al alejarse se apaga el prompt")
	assert_false(_terminal.is_key_hint_visible())


func test_pulse_from_far_away_does_nothing() -> void:
	_place_isak(10.0)
	await wait_physics_frames(2)
	_isak.set_pulse_area_active(true)
	assert_eq(_terminal.get_state(), ExitTerminal.State.OFF)


func test_pulse_activates_boots_and_absorbs_isak_once() -> void:
	_place_isak(19.5)
	await wait_physics_frames(6)
	var activated: Array[String] = []
	_terminal.activated.connect(func(id: String) -> void: activated.append(id))
	_isak.set_pulse_area_active(true)
	assert_eq(activated, ["test"] as Array[String], "El pulso la activa")
	assert_eq(_terminal.get_state(), ExitTerminal.State.BOOT)
	assert_eq(_terminal.get_animation(), ExitTerminal.ANIM_BOOT, "La pantalla se enciende")
	assert_false(_terminal.is_key_hint_visible())
	assert_true(_isak.is_warping(), "Isak sin control")
	_finish_activation()
	assert_eq(_terminal.get_animation(), ExitTerminal.ANIM_ON)
	assert_eq(_completed, ["test"] as Array[String], "Nivel completado al cerrarse el vortice")
	assert_eq(_isak.modulate.a, 0.0, "Isak absorbido")
	_isak.set_pulse_area_active(true)
	_terminal.advance(LONG_STEP_S)
	assert_eq(_completed.size(), 1, "Una sola vez")
	assert_eq(_terminal.get_completed_count(), 1)
