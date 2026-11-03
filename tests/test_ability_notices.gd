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
var _raw_lines: Array[String] = []
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
	_raw_lines.clear()
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
	# Los avisos llegan con marcas ({demo:}, {tecla:}; 2026-11-03): se compara lo que se ve.
	_raw_lines.append(text)
	_lines.append(TextMarkers.display(text))
	_important.append(important)


func _arm() -> void:
	_notices.begin_level()
	_notices.advance(float(_data["start_delay_s"]) + 0.01)
	assert_true(_notices.is_armed())


## Lineas de un aviso: el control y su explicacion (campo explain, 2026-10-30).
func _notice_lines(ability: StringName, control: String) -> Array[String]:
	var out: Array[String] = [control]
	for line: String in AbilityNotices.explain_lines(ability, _data):
		out.append(line)
	assert_gt(out.size(), 1, "%s tiene explicacion" % ability)
	return out


# --- Texto leido del Input Map ---

func test_texts_from_the_default_input_map() -> void:
	assert_eq(AbilityNotices.notice_text(&"pulse", _data), "", "El pulso ya no esta aqui: lo avisa el encuentro")
	assert_eq(AbilityNotices.notice_text(&"pulse", _pulse_format()), "Pulso: G",
			"Mismo formato con la entrada notice de data/eco_encounter.json")
	assert_eq(AbilityNotices.notice_text(&"laser", _data), "Láser: F")
	assert_eq(AbilityNotices.notice_text(&"debug", _data), "Debug: mantén K")
	assert_eq(AbilityNotices.notice_text(&"dash", _data), "Deslizar: L",
			"Gesto Deslizar (2026-10-19, docs/propuesta-1-3.md §2.4)")
	assert_eq(AbilityNotices.notice_text(&"ground_pound", _data), "Golpe al suelo: mantén S",
			"Golpe al suelo (2026-10-22, docs/propuesta-mundo-2.md §3.3.3): los eventos de move_down")
	assert_eq(AbilityNotices.notice_text(&"compress", _data), "Comprimir: I",
			"Comprimir (2026-10-26, docs/propuesta-mundo-3.md §3.3.1): accion gesture_pinch")
	assert_eq(AbilityNotices.notice_text(&"shockwave", _data), "",
			"Agitar retirado (2026-10-28, docs/propuesta-mundo-4.md §8.1): sin aviso")
	assert_eq(AbilityNotices.notice_text(&"no_such_ability", _data), "", "Sin entrada, sin aviso")


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
	assert_eq(remapped, "Pulso: H")
	assert_eq(pad_only, "Pulso: gatillo derecho", "Sin tecla, solo el mando")
	assert_eq(AbilityNotices.notice_text(&"pulse", _pulse_format()), "Pulso: G", "Restaurado")


# --- Cuando sale ---

func test_unlocked_ability_shows_once_after_the_start_delay() -> void:
	GameState.set_ability_unlocked(&"debug", true)
	_notices.begin_level()
	_notices.advance(float(_data["start_delay_s"]) * 0.5)
	assert_eq(_lines.size(), 0, "Espera start_delay_s")
	_notices.advance(float(_data["start_delay_s"]))
	assert_eq(_lines, _notice_lines(&"debug", "Debug: mantén K"))
	assert_eq(_important, [true, true] as Array[bool], "Habilidad adquirida: aviso y explicacion, importantes (pausa)")
	assert_true(GameState.is_notice_seen(&"debug"))
	_notices.begin_level()
	_notices.advance(10.0)
	assert_eq(_lines.size(), 2, "Una sola vez (aviso + explicacion), aunque se reinicie el nivel")


func test_locked_abilities_do_not_show() -> void:
	_arm()
	assert_eq(_lines.size(), 0)
	assert_false(GameState.is_notice_seen(&"debug"))


func test_debug_unlock_while_playing_shows_its_notice() -> void:
	_arm()
	GameState.set_ability_unlocked(&"debug", true)
	assert_eq(_lines, _notice_lines(&"debug", "Debug: mantén K"))
	GameState.set_ability_unlocked(&"debug", false)
	GameState.set_ability_unlocked(&"debug", true)
	assert_eq(_lines.size(), 2, "No se repite")


func test_obtaining_the_laser_shows_its_notice() -> void:
	_arm()
	watch_signals(_notices)
	assert_true(GameState.obtain_ability(&"laser"))
	assert_eq(_lines, _notice_lines(&"laser", "Láser: F"))
	assert_signal_emitted_with_parameters(_notices, "notice_shown", [&"laser", "Láser: F"])


func test_unlocks_before_arming_wait_and_stop_disarms() -> void:
	_notices.begin_level()
	GameState.set_ability_unlocked(&"debug", true)
	assert_eq(_lines.size(), 0, "Al entrar el nivel no hay cuadro de Eco aun")
	_notices.stop()
	_notices.advance(10.0)
	assert_eq(_lines.size(), 0, "Desarmado (hub)")
	_notices.begin_level()
	_notices.advance(10.0)
	assert_eq(_lines, _notice_lines(&"debug", "Debug: mantén K"))


func test_obtaining_the_dash_shows_its_notice_once() -> void:
	_arm()
	assert_true(GameState.obtain_ability(&"dash"))
	assert_eq(_lines, _notice_lines(&"dash", "Deslizar: L"))
	assert_eq(_important, [true, true] as Array[bool], "Aviso y explicacion, importantes (pausa)")
	assert_true(GameState.is_notice_seen(&"dash"))
	_notices.begin_level()
	_notices.advance(10.0)
	assert_eq(_lines.size(), 2, "Una vez por partida guardada")


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
	assert_eq(text, "Deslizar: E", "Leido del Input Map")
	assert_eq(AbilityNotices.notice_text(&"dash", _data), "Deslizar: L")


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
	assert_eq(_lines, _notice_lines(&"debug", "Debug: mantén K"), "Solo el Debug, no el laser")


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


# --- Explicacion (2026-10-30, peticion del usuario tras el 5-2) ---

func test_every_notice_explains_what_the_ability_does() -> void:
	for key: Variant in _data["abilities"]:
		var lines: PackedStringArray = AbilityNotices.explain_lines(StringName(String(key)), _data)
		assert_gt(lines.size(), 0, "%s: explica que hace" % key)
		for line: String in lines:
			assert_false(line.contains("{"), "%s: sin marcas sin sustituir (%s)" % [key, line])
			assert_lt(line.length(), 150, "%s: linea corta para el cuadro de Eco" % key)
	var combo: PackedStringArray = AbilityNotices.explain_lines(&"combo", _data)
	for name: String in ["Embestida", "Filo", "Sismo"]:
		var found: bool = false
		for line: String in combo:
			found = found or line.begins_with(name + ":")
		assert_true(found, "La Combinacion explica %s" % name)


# --- Solo el dispositivo actual, marcas y mini animacion (2026-11-03) ---

func test_notice_shows_only_the_current_device() -> void:
	assert_eq(AbilityNotices.notice_text(&"laser", _data), "Láser: F", "Teclado: solo la tecla")
	ControlBindings.set_last_device(ControlBindings.Device.PAD)
	assert_eq(AbilityNotices.notice_text(&"laser", _data), "Láser: gatillo izquierdo", "Mando: solo el gatillo")
	assert_eq(AbilityNotices.notice_text(&"debug", _data), "Debug: mantén Y")
	assert_eq(AbilityNotices.notice_text(&"dash", _data), "Deslizar: B")
	assert_eq(AbilityNotices.notice_text(&"compress", _data), "Comprimir: RB")
	assert_eq(AbilityNotices.notice_text(&"pulse", _pulse_format()), "Pulso: X")
	ControlBindings.set_last_device(ControlBindings.Device.PAD, "playstation")
	assert_false(AbilityNotices.notice_text(&"pulse", _pulse_format()).ends_with(": X"),
			"Con un mando de PlayStation, su nombre de boton")
	ControlBindings.reset_device()
	for key: Variant in _data["abilities"]:
		var text: String = AbilityNotices.notice_text(StringName(String(key)), _data)
		assert_false(text.contains("(mando)") or text.contains(" / "), "%s: un solo control (%s)" % [key, text])


func test_notice_reaches_the_box_with_markers_and_a_demo() -> void:
	_arm()
	assert_true(GameState.obtain_ability(&"dash"))
	assert_true(_raw_lines[0].begins_with("{demo:dash}"), "Lleva su mini animacion: %s" % _raw_lines[0])
	assert_true(_raw_lines[0].contains("{tecla:gesture_swipe}"), "La tecla va sin sustituir: la resuelve el cuadro")


func test_every_notice_has_a_valid_demo() -> void:
	var frames: SpriteFrames = load(AbilityDemo.FRAMES_PATH)
	var demos: Dictionary = _data["demos"]
	var used: Array[String] = [String(EcoEncounter.load_data()["notice"].get("demo", ""))]
	for key: Variant in _data["abilities"]:
		var entry: Dictionary = _data["abilities"][key]
		if entry.has("demo"):
			used.append(String(entry["demo"]))
		for demo: Variant in entry.get("explain_demos", []):
			if not String(demo).is_empty():
				used.append(String(demo))
		var template: String = AbilityNotices.notice_template(StringName(String(key)), _data)
		var demo_ids: Array[StringName] = [TextMarkers.demo_id(template)]
		for line: String in AbilityNotices.explain_templates(StringName(String(key)), _data):
			demo_ids.append(TextMarkers.demo_id(line))
		assert_true(demo_ids.any(func(id: StringName) -> bool: return id != &""), "%s: alguna linea con demo" % key)
	for id: String in used:
		assert_true(demos.has(id), "Demo %s definida" % id)
	for id: Variant in demos:
		for step: Dictionary in demos[id]["steps"]:
			assert_true(frames.has_animation(StringName(String(step["anim"]))), "%s: animacion %s" % [id, step["anim"]])
			if step.has("press"):
				assert_true(InputMap.has_action(StringName(String(step["press"]))), "%s: accion %s" % [id, step["press"]])
