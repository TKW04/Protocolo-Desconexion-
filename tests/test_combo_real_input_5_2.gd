# Embestida con la entrada REAL contra la persiana de la salida de «Paquete
# completo» del 5-2 (flujo real: scenes/main.tscn; arreglo del 2026-10-30,
# docs/propuesta-mundo-5.md §8.1).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_combo_real_input_5_2.json"
const TILE: float = 64.0
const POUND: StringName = GameState.ABILITY_GROUND_POUND
const A_JUMP: StringName = &"jump"
const A_DASH: StringName = &"gesture_swipe"
const A_DOWN: StringName = &"move_down"
const A_RIGHT: StringName = &"move_right"

var _saved_path: String
var _saved_level: StringName
var _main: LevelRunner
var _isak: Isak
var _held: Array[StringName] = []
var _seen: Array[StringName] = []


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	DebugMode.input_enabled = false
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	for ability: StringName in [GameState.ABILITY_LASER, GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	EcoProgress.obtain_debug()
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss", &"4-1", &"4-2", &"4-3", &"4-boss", &"5-1"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"5-2")
	GameState.install_hub_upgrade(&"hub_update_4_6")
	_held = []
	_seen = []


func after_each() -> void:
	for action: StringName in _held.duplicate():
		_key(action, false)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_isak = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	for ability: StringName in [GameState.ABILITY_DASH, POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]:
		GameState.set_ability_unlocked(ability, false)
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _key(action: StringName, pressed: bool) -> void:
	var key: InputEventKey = null
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			key = (event as InputEventKey).duplicate() as InputEventKey
			break
	if key == null:
		fail_test("Sin tecla para %s" % action)
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


func _frames(count: int) -> void:
	var target: int = Engine.get_physics_frames() + count
	while Engine.get_physics_frames() < target:
		await get_tree().physics_frame
		if is_instance_valid(_isak):
			var s: StringName = _isak.get_state_name()
			if _seen.is_empty() or _seen[-1] != s:
				_seen.append(s)


func _arrive() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.start_level_id = "5-2"
	add_child(_main)
	for i: int in 900:
		await wait_physics_frames(1)
		_isak = _main.get_isak()
		if _isak != null and not get_tree().paused and _isak.is_on_floor() and _isak.get_state_name() == PlayerState.IDLE \
				and not _isak.is_warping():
			break
	assert_not_null(_isak)
	assert_true(_isak.input is ActionPlayerInput, "Entrada real")


func _obj(id: String) -> Node:
	return _main.get_level().get_node_or_null(NodePath("Objects/" + id))


func test_ram_breaks_the_exit_shutter_with_real_keys() -> void:
	await _arrive()
	var box := _obj("prueba_gratis") as FreeTrialBox
	assert_true(box.switch_on(), "La «Prueba gratis» da la Combinacion")
	for i: int in 600:
		await wait_physics_frames(1)
		if not get_tree().paused:
			break
	await _frames(30)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_COMBO))
	_isak.global_position = Vector2(15.5 * TILE, 6.0 * TILE)
	_isak.velocity = Vector2.ZERO
	await _frames(20)
	_seen.clear()
	var shutter := _obj("persiana_salida") as Shutter
	_key(A_JUMP, true)
	await _frames(10)
	_key(A_RIGHT, true)
	_key(A_DASH, true)
	await _frames(1)
	_key(A_DASH, false)
	await _frames(3)
	_key(A_DOWN, true)
	await _frames(60)
	assert_has(_seen, PlayerState.COMBO_RAM, "Embestida con teclas reales: %s" % str(_seen))
	assert_true(shutter.is_broken(), "La persiana de la salida se rompe")


func test_ram_after_opening_the_box_with_the_real_pulse() -> void:
	await _arrive()
	_isak.global_position = Vector2(12.0 * TILE, 6.0 * TILE)
	_isak.velocity = Vector2.ZERO
	await _frames(10)
	_key(&"pulse", true)
	await _frames(1)
	_key(&"pulse", false)
	for i: int in 900:
		await wait_physics_frames(1)
		if GameState.is_ability_obtained(GameState.ABILITY_COMBO) and not get_tree().paused and not _isak.is_facing_back():
			break
	await _frames(120)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_COMBO), "Combinacion por el pulso real")
	_isak.global_position = Vector2(15.5 * TILE, 6.0 * TILE)
	_isak.velocity = Vector2.ZERO
	await _frames(20)
	_seen.clear()
	var shutter := _obj("persiana_salida") as Shutter
	_key(A_JUMP, true)
	await _frames(10)
	_key(A_RIGHT, true)
	_key(A_DASH, true)
	await _frames(1)
	_key(A_DASH, false)
	# Como un jugador: abajo justo despues de que acabe el dash (12 cuadros).
	await _frames(14)
	_key(A_DOWN, true)
	await _frames(60)
	assert_has(_seen, PlayerState.COMBO_RAM, "Embestida tras la caja: %s" % str(_seen))
	assert_true(shutter.is_broken(), "La persiana de la salida se rompe")
