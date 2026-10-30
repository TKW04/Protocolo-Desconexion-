# Combinacion con la entrada REAL (arreglo del 2026-10-30, docs/propuesta-mundo-5.md
# §8.1): eventos de tecla del Input Map (Input.parse_input_event, sin PlayerInput
# falso ni llamadas internas) y cuadros de fisica reales entre pulsaciones, como un
# jugador con teclado. Las demas pruebas de la Combinacion inyectan los campos de
# PlayerInput y no veian el fallo.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const PATH: String = "user://test_combo_real_input_save.json"
const ABILITIES: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
	GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]
const A_JUMP: StringName = &"jump"
const A_DASH: StringName = &"gesture_swipe"
const A_PINCH: StringName = &"gesture_pinch"
const A_DOWN: StringName = &"move_down"
const A_RIGHT: StringName = &"move_right"

var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _held: Array[StringName] = []
var _seen: Array[StringName] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND,
			GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]:
		GameState.set_ability_unlocked(ability, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_held = []
	_seen = []
	_world = Node2D.new()
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8192.0, 128.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(0.0, 64.0)
	_world.add_child(floor_body)
	_isak = ISAK_SCENE.instantiate() as Isak
	_world.add_child(_isak)
	add_child_autofree(_world)
	_isak.state_changed.connect(_on_state)
	await _frames(20)
	assert_true(_isak.input is ActionPlayerInput, "Entrada real del Input Map")
	assert_true(_isak.is_on_floor(), "En el suelo")


func after_each() -> void:
	for action: StringName in _held.duplicate():
		_key(action, false)
	await _frames(2)
	Input.flush_buffered_events()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_state(_from: StringName, to: StringName) -> void:
	if _seen.is_empty() or _seen[-1] != to:
		_seen.append(to)


## Evento de tecla real: el primer InputEventKey de la accion en el Input Map.
func _key(action: StringName, pressed: bool) -> void:
	var key: InputEventKey = null
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			key = (event as InputEventKey).duplicate() as InputEventKey
			break
	assert_not_null(key, "Tecla de %s en el Input Map" % action)
	if key == null:
		return
	key.pressed = pressed
	if key.keycode == KEY_NONE:
		key.keycode = key.physical_keycode
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	if pressed and not _held.has(action):
		_held.append(action)
	elif not pressed:
		_held.erase(action)


## Avanza `count` cuadros de fisica reales y apunta los estados por los que pasa.
func _frames(count: int) -> void:
	var target: int = Engine.get_physics_frames() + count
	while Engine.get_physics_frames() < target:
		await get_tree().physics_frame
		if _isak != null and is_instance_valid(_isak):
			var s: StringName = _isak.get_state_name()
			if _seen.is_empty() or _seen[-1] != s:
				_seen.append(s)


func _tap(action: StringName) -> void:
	_key(action, true)
	await _frames(1)
	_key(action, false)


func _jump_and_rise(frames: int = 10) -> void:
	_key(A_JUMP, true)
	await _frames(frames)
	assert_false(_isak.is_on_floor(), "En el aire")


func _report(label: String) -> String:
	return "%s: estados %s" % [label, str(_seen)]


# --- Embestida (Deslizar en el aire + abajo) ---

func test_ram_dash_then_down_a_few_frames_later() -> void:
	await _jump_and_rise()
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	await _frames(2)
	_key(A_DOWN, true)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_RAM, _report("Deslizar y abajo 2 cuadros despues"))


func test_ram_dash_and_down_on_the_same_frame() -> void:
	await _jump_and_rise()
	_key(A_RIGHT, true)
	_key(A_DOWN, true)
	await _tap(A_DASH)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_RAM, _report("Deslizar y abajo a la vez"))


func test_ram_down_slightly_before_the_dash() -> void:
	await _jump_and_rise()
	_key(A_RIGHT, true)
	_key(A_DOWN, true)
	await _frames(3)
	await _tap(A_DASH)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_RAM, _report("Abajo 3 cuadros antes de Deslizar"))
	assert_does_not_have(_seen, PlayerState.GROUND_POUND, "Sin golpe al suelo")


func test_ram_down_late_in_the_dash() -> void:
	await _jump_and_rise()
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	await _frames(8)
	_key(A_DOWN, true)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_RAM, _report("Abajo 8 cuadros despues de Deslizar"))


# --- Filo (comprimido + Deslizar) ---

func test_edge_compressed_jump_then_dash() -> void:
	await _tap(A_PINCH)
	await _frames(15)
	assert_true(_isak.is_compressed(), "Comprimido")
	await _jump_and_rise(8)
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	await _frames(5)
	assert_has(_seen, PlayerState.COMBO_EDGE, _report("Comprimido, salto y Deslizar"))


# --- Sismo (comprimido + abajo) ---

func test_quake_compressed_jump_then_down() -> void:
	await _tap(A_PINCH)
	await _frames(15)
	assert_true(_isak.is_compressed(), "Comprimido")
	await _jump_and_rise(8)
	_key(A_DOWN, true)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_QUAKE, _report("Comprimido, salto y abajo"))


func test_ram_down_just_after_the_dash_ends() -> void:
	await _jump_and_rise()
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	await _frames(13)
	assert_does_not_have(_seen, PlayerState.COMBO_RAM)
	_key(A_DOWN, true)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_RAM, _report("Abajo justo al acabar el dash (bufer)"))
	assert_does_not_have(_seen, PlayerState.GROUND_POUND, "Sin golpe al suelo")


func test_down_well_after_the_dash_is_not_a_ram() -> void:
	await _jump_and_rise()
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	_key(A_RIGHT, false)
	await _frames(12 + 14)
	assert_false(_isak.is_on_floor(), "Sigue en el aire")
	assert_does_not_have(_seen, PlayerState.COMBO_RAM)
	_key(A_DOWN, true)
	await _frames(30)
	assert_does_not_have(_seen, PlayerState.COMBO_RAM, _report("Abajo 0,23 s tras el dash: fuera del margen"))


func test_ground_dash_and_down_is_not_a_ram() -> void:
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	_key(A_DOWN, true)
	await _frames(30)
	assert_does_not_have(_seen, PlayerState.COMBO_RAM, _report("Dash en el suelo + abajo"))


func test_edge_dash_on_the_jump_frame() -> void:
	await _tap(A_PINCH)
	await _frames(15)
	assert_true(_isak.is_compressed(), "Comprimido")
	_key(A_RIGHT, true)
	_key(A_JUMP, true)
	await _tap(A_DASH)
	await _frames(10)
	assert_has(_seen, PlayerState.COMBO_EDGE, _report("Saltar y Deslizar a la vez, comprimido"))


func test_edge_dash_a_frame_after_the_jump() -> void:
	await _tap(A_PINCH)
	await _frames(15)
	_key(A_RIGHT, true)
	_key(A_JUMP, true)
	await _frames(1)
	await _tap(A_DASH)
	await _frames(10)
	assert_has(_seen, PlayerState.COMBO_EDGE, _report("Deslizar un cuadro tras saltar, comprimido"))


func test_edge_pinch_in_the_air_then_dash() -> void:
	await _jump_and_rise(6)
	await _tap(A_PINCH)
	await _frames(2)
	_key(A_RIGHT, true)
	await _tap(A_DASH)
	await _frames(10)
	assert_has(_seen, PlayerState.COMBO_EDGE, _report("Pellizcar en el aire y Deslizar"))


func test_edge_pinch_and_dash_together_in_the_air() -> void:
	await _jump_and_rise(6)
	_key(A_RIGHT, true)
	_key(A_PINCH, true)
	await _tap(A_DASH)
	await _frames(10)
	assert_has(_seen, PlayerState.COMBO_EDGE, _report("Pellizcar y Deslizar a la vez en el aire"))


func test_quake_down_held_through_the_takeoff() -> void:
	await _tap(A_PINCH)
	await _frames(15)
	_key(A_DOWN, true)
	await _frames(5)
	_key(A_JUMP, true)
	await _frames(25)
	assert_has(_seen, PlayerState.COMBO_QUAKE, _report("Abajo mantenido desde el suelo y saltar, comprimido"))


func test_quake_pinch_and_down_together_in_the_air() -> void:
	await _jump_and_rise(8)
	_key(A_PINCH, true)
	_key(A_DOWN, true)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_QUAKE, _report("Pellizcar y abajo a la vez en el aire"))


# --- Mando (B = Deslizar, RB = Pellizcar, stick abajo) ---

func _pad_button(action: StringName, pressed: bool) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var b := InputEventJoypadButton.new()
			b.device = 0
			b.button_index = (event as InputEventJoypadButton).button_index
			b.pressed = pressed
			Input.parse_input_event(b)
			Input.flush_buffered_events()
			return
	fail_test("Sin boton de mando para %s" % action)


func _stick_down(value: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.device = 0
	m.axis = JOY_AXIS_LEFT_Y
	m.axis_value = value
	Input.parse_input_event(m)
	Input.flush_buffered_events()


func test_pad_ram_and_quake() -> void:
	await _jump_and_rise()
	_pad_button(A_DASH, true)
	await _frames(1)
	_pad_button(A_DASH, false)
	await _frames(13)
	_stick_down(0.8)
	await _frames(20)
	assert_has(_seen, PlayerState.COMBO_RAM, _report("Mando: B y stick abajo al acabar el dash"))
	_stick_down(0.0)
	_key(A_JUMP, false)
	await _frames(40)
	_seen.clear()
	_pad_button(A_PINCH, true)
	await _frames(1)
	_pad_button(A_PINCH, false)
	await _frames(15)
	assert_true(_isak.is_compressed(), "RB comprime")
	_key(A_JUMP, true)
	await _frames(8)
	_stick_down(0.8)
	await _frames(20)
	_stick_down(0.0)
	assert_has(_seen, PlayerState.COMBO_QUAKE, _report("Mando: RB, salto y stick abajo"))
