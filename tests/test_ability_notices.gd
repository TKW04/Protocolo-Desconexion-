# Avisos de control de las habilidades (AbilityNotices, data/ability_notices.json):
# el texto sale del Input Map (y cambia si se remapea), cada aviso sale una sola
# vez, se guarda y se recarga (seen_notices), un guardado antiguo sin
# seen_notices no repite el aviso del laser, y el flujo de juego (main.tscn) ya
# no avisa del pulso al empezar el 1-1: desde el 2026-10-16 el pulso y su aviso
# los da el encuentro con Eco (data/eco_encounter.json, mismo formato y tablas).
# Usa una ruta de guardado propia.
extends GutTest

const PATH: String = "user://test_ability_notices_save.json"
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ABILITIES: Array[StringName] = [&"pulse", &"laser", &"debug", &"dash"]

var _saved_path: String
var _saved_unlocked: Dictionary = {}
var _saved_level: StringName
var _notices: AbilityNotices
var _main: LevelRunner
var _lines: Array[String] = []
var _important: Array[bool] = []
var _data: Dictionary = AbilityNotices.load_data()


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	for ability: StringName in ABILITIES:
		_saved_unlocked[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, false)
	_lines.clear()
	_important.clear()
	EventBus.eco_line_requested.connect(_on_line)
	_notices = AbilityNotices.new()
	_notices.auto_advance = false
	add_child(_notices)


func after_each() -> void:
	EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_notices.free()
	DebugMode.reset()
	GameState.reset_progress()
	for ability: StringName in ABILITIES:
		GameState.set_ability_unlocked(ability, bool(_saved_unlocked[ability]))
	GameState.current_level = _saved_level
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _on_line(text: String, _duration_s: float, important: bool) -> void:
	_lines.append(text)
	_important.append(important)


func _arm() -> void:
	_notices.begin_level()
	_notices.advance(float(_data["start_delay_s"]) + 0.01)
	assert_true(_notices.is_armed())


# --- Texto leido del Input Map ---

func test_texts_from_the_default_input_map() -> void:
	assert_eq(AbilityNotices.notice_text(&"pulse", _data), "", "El pulso ya no esta aqui: lo avisa el encuentro")
	assert_eq(AbilityNotices.notice_text(&"pulse", _pulse_format()), "Pulso: G / X (mando)",
			"Mismo formato con la entrada notice de data/eco_encounter.json")
	assert_eq(AbilityNotices.notice_text(&"laser", _data), "Láser: F / gatillo izquierdo")
	assert_eq(AbilityNotices.notice_text(&"debug", _data), "Debug: mantén K / Y (mando)")
	assert_eq(AbilityNotices.notice_text(&"dash", _data), "Deslizar: L / B (mando)",
			"Gesto Deslizar (2026-10-19, docs/propuesta-1-3.md §2.4)")
	assert_eq(AbilityNotices.notice_text(&"ground_pound", _data), "", "Sin entrada, sin aviso")


func test_text_changes_when_an_action_is_remapped() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"pulse")
	InputMap.action_erase_events(&"pulse")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	InputMap.action_add_event(&"pulse", key)
	InputMap.action_add_event(&"pulse", button)
	var remapped: String = AbilityNotices.notice_text(&"pulse", _pulse_format())
	InputMap.action_erase_events(&"pulse")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	InputMap.action_add_event(&"pulse", trigger)
	var pad_only: String = AbilityNotices.notice_text(&"pulse", _pulse_format())
	InputMap.action_erase_events(&"pulse")
	for event: InputEvent in original:
		InputMap.action_add_event(&"pulse", event)
	assert_eq(remapped, "Pulso: H / B (mando)")
	assert_eq(pad_only, "Pulso: gatillo derecho", "Sin tecla, solo el mando")
	assert_eq(AbilityNotices.notice_text(&"pulse", _pulse_format()), "Pulso: G / X (mando)", "Restaurado")


# --- Cuando sale ---

func test_unlocked_ability_shows_once_after_the_start_delay() -> void:
	GameState.set_ability_unlocked(&"debug", true)
	_notices.begin_level()
	_notices.advance(float(_data["start_delay_s"]) * 0.5)
	assert_eq(_lines.size(), 0, "Espera start_delay_s")
	_notices.advance(float(_data["start_delay_s"]))
	assert_eq(_lines, ["Debug: mantén K / Y (mando)"] as Array[String])
	assert_eq(_important, [true] as Array[bool], "Habilidad adquirida: linea importante (pausa)")
	assert_true(GameState.is_notice_seen(&"debug"))
	_notices.begin_level()
	_notices.advance(10.0)
	assert_eq(_lines.size(), 1, "Una sola vez, aunque se reinicie el nivel")


func test_locked_abilities_do_not_show() -> void:
	_arm()
	assert_eq(_lines.size(), 0)
	assert_false(GameState.is_notice_seen(&"debug"))


func test_debug_unlock_while_playing_shows_its_notice() -> void:
	_arm()
	GameState.set_ability_unlocked(&"debug", true)
	assert_eq(_lines, ["Debug: mantén K / Y (mando)"] as Array[String])
	GameState.set_ability_unlocked(&"debug", false)
	GameState.set_ability_unlocked(&"debug", true)
	assert_eq(_lines.size(), 1, "No se repite")


func test_obtaining_the_laser_shows_its_notice() -> void:
	_arm()
	watch_signals(_notices)
	assert_true(GameState.obtain_ability(&"laser"))
	assert_eq(_lines, ["Láser: F / gatillo izquierdo"] as Array[String])
	assert_signal_emitted_with_parameters(_notices, "notice_shown", [&"laser", "Láser: F / gatillo izquierdo"])


func test_unlocks_before_arming_wait_and_stop_disarms() -> void:
	_notices.begin_level()
	GameState.set_ability_unlocked(&"debug", true)
	assert_eq(_lines.size(), 0, "Al entrar el nivel no hay cuadro de Eco aun")
	_notices.stop()
	_notices.advance(10.0)
	assert_eq(_lines.size(), 0, "Desarmado (hub)")
	_notices.begin_level()
	_notices.advance(10.0)
	assert_eq(_lines, ["Debug: mantén K / Y (mando)"] as Array[String])


func test_obtaining_the_dash_shows_its_notice_once() -> void:
	_arm()
	assert_true(GameState.obtain_ability(&"dash"))
	assert_eq(_lines, ["Deslizar: L / B (mando)"] as Array[String])
	assert_eq(_important, [true] as Array[bool], "Linea importante (pausa)")
	assert_true(GameState.is_notice_seen(&"dash"))
	_notices.begin_level()
	_notices.advance(10.0)
	assert_eq(_lines.size(), 1, "Una vez por partida guardada")


func test_dash_notice_follows_a_remapped_gesture_swipe() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"gesture_swipe")
	InputMap.action_erase_events(&"gesture_swipe")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event(&"gesture_swipe", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event(&"gesture_swipe", pad)
	var text: String = AbilityNotices.notice_text(&"dash", _data)
	InputMap.action_erase_events(&"gesture_swipe")
	for event: InputEvent in original:
		InputMap.action_add_event(&"gesture_swipe", event)
	assert_eq(text, "Deslizar: E / RB (mando)", "Leido del Input Map")
	assert_eq(AbilityNotices.notice_text(&"dash", _data), "Deslizar: L / B (mando)")


# --- Guardado ---

func test_seen_notices_are_saved_and_reloaded() -> void:
	GameState.set_ability_unlocked(&"debug", true)
	_arm()
	assert_true(GameState.save_game())
	assert_eq(SaveFile.read(PATH).get("seen_notices"), ["debug"])
	GameState.reset_progress()
	assert_false(GameState.is_notice_seen(&"debug"), "Empezar de cero los olvida")
	assert_true(GameState.load_game())
	assert_true(GameState.is_notice_seen(&"debug"))
	GameState.set_ability_unlocked(&"debug", true)
	_lines.clear()
	_arm()
	assert_eq(_lines.size(), 0, "Tras recargar no se repite")


func test_old_save_with_the_laser_does_not_repeat_its_notice() -> void:
	assert_true(SaveFile.write(PATH, {"version": 1, "attention_points": 3, "abilities_obtained": ["laser"]}))
	assert_true(GameState.load_game())
	assert_true(GameState.is_notice_seen(&"laser"))
	assert_false(GameState.is_notice_seen(&"debug"))
	GameState.set_ability_unlocked(&"debug", true)
	_arm()
	assert_eq(_lines, ["Debug: mantén K / Y (mando)"] as Array[String], "Solo el Debug, no el laser")


# --- Flujo de juego ---

func test_main_scene_has_no_pulse_notice_at_the_start_of_1_1() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	var notices: AbilityNotices = _main.get_ability_notices()
	notices.auto_advance = false
	assert_false(notices.is_armed())
	notices.advance(float(_data["start_delay_s"]) + 0.01)
	assert_true(notices.is_armed())
	assert_eq(_lines.size(), 0, "El 1-1 empieza sin pulso: ningun aviso al empezar (lo da el encuentro con Eco)")
	assert_false(GameState.is_ability_unlocked(&"pulse"))
	assert_false(GameState.is_notice_seen(&"pulse"))
	assert_false(GameState.is_notice_seen(&"debug"), "El Debug sigue bloqueado en el 1-1")
	assert_false(GameState.is_notice_seen(&"laser"))


func test_pulse_gained_with_ability_notices_armed_is_not_repeated() -> void:
	# El encuentro marca el aviso como visto antes de dar el pulso: AbilityNotices no lo repite.
	_arm()
	GameState.mark_notice_seen(&"pulse")
	assert_true(GameState.obtain_ability(&"pulse"))
	assert_eq(_lines.size(), 0)


func _pulse_format() -> Dictionary:
	var format: Dictionary = _data.duplicate(true)
	format["abilities"] = {"pulse": EcoEncounter.load_data()["notice"]}
	return format
