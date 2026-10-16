# Reasignar controles (2026-10-16, decision del usuario; ControlBindings,
# seccion controls de data/settings.json y Ajustes > Controles del menu de
# pausa): asignar una tecla o un boton, conflicto con intercambiar o cancelar,
# entradas reservadas (Esc / Start de la pausa, R / Select, F9), restablecer con
# confirmacion, guardado al instante y carga al arrancar (eventos
# serializados), nunca una accion sin entrada de su dispositivo ni la pausa sin
# Esc y Start, prompts «G» / «Q» y avisos de control que se actualizan, nombres
# con glifos de la fuente y mando para navegar.
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const FONT_PATH: String = "res://assets/sprites/ui/text_font.fnt"

var _menu: PauseMenu
var _changes: int = 0


func before_each() -> void:
	GameSettings.use_path(GameSettings.settings_path(), true)
	_changes = 0
	EventBus.controls_changed.connect(_on_controls_changed)


func after_each() -> void:
	if EventBus.controls_changed.is_connected(_on_controls_changed):
		EventBus.controls_changed.disconnect(_on_controls_changed)
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null
	get_tree().paused = false
	GameSettings.use_path(GameSettings.settings_path(), true)
	GameState.reset_progress()


func _on_controls_changed() -> void:
	_changes += 1


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _button(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _is_action(event: InputEvent, action: StringName) -> bool:
	return InputMap.event_is_action(event, action, true)


func _spawn_menu() -> PauseMenu:
	_menu = PauseMenu.new()
	_menu.capture_arm_s = 0.0
	add_child(_menu)
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	_menu.select(PauseMenu.Option.CONTROLS)
	_menu.activate(PauseMenu.Option.CONTROLS)
	return _menu


func _push(event: InputEvent) -> void:
	get_viewport().push_input(event)


func _tap(event: InputEvent) -> void:
	_push(event)
	var release: InputEvent = event.duplicate()
	if release is InputEventKey:
		(release as InputEventKey).pressed = false
	elif release is InputEventJoypadButton:
		(release as InputEventJoypadButton).pressed = false
	elif release is InputEventJoypadMotion:
		(release as InputEventJoypadMotion).axis_value = 0.0
	_push(release)


func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_push(event)


# --- Datos ---

func test_remappable_actions_exclude_dev_and_ui_keys() -> void:
	var actions: Array[StringName] = ControlBindings.actions()
	assert_eq(actions, [&"move_left", &"move_right", &"jump", &"run", &"pulse", &"laser", &"debug", &"help",
		&"pause"] as Array[StringName])
	for action: StringName in actions:
		assert_false(String(action).begins_with("ui_"))
		assert_false([&"restart_level", &"debug_wipe_save"].has(action), "Sin teclas de pruebas")
		assert_false(String(action).begins_with("hud_debug"))
	assert_eq(ControlBindings.action_name(&"jump"), "Saltar")


func test_default_labels_and_glyphs() -> void:
	var font: Font = load(FONT_PATH) as Font
	assert_eq(ControlBindings.binding_label(&"jump", font), "Espacio / A")
	assert_eq(ControlBindings.binding_label(&"pulse", font), "G / X")
	assert_eq(ControlBindings.binding_label(&"run", font), "Mayús / gatillo derecho")
	assert_eq(ControlBindings.binding_label(&"pause", font), "Esc / Start")
	assert_eq(ControlBindings.binding_label(&"move_left", font), "A / stick a la izquierda")
	for action: StringName in ControlBindings.actions():
		var text: String = ControlBindings.binding_label(action, font)
		for i: int in text.length():
			assert_true(text.unicode_at(i) == 32 or font.has_char(text.unicode_at(i)), "Glifo de %s en «%s»" % [
				text[i], text])
	# Cualquier tecla imprimible o especial se nombra con glifos de la fuente
	# (si faltara alguno, «Tecla <codigo>»).
	var codes: Array[int] = []
	for code: int in range(32, 256):
		codes.append(code)
	codes.append_array([KEY_ESCAPE, KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_INSERT, KEY_DELETE,
		KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_CTRL,
		KEY_META, KEY_ALT, KEY_CAPSLOCK, KEY_F1, KEY_F5, KEY_F12, KEY_KP_0, KEY_KP_5, KEY_KP_ADD, KEY_KP_MULTIPLY,
		KEY_MENU])
	for code: int in codes:
		var text: String = ControlBindings.input_label(_key(code as Key), font)
		for i: int in text.length():
			if text.unicode_at(i) != 32 and not font.has_char(text.unicode_at(i)):
				fail_test("Tecla %d: «%s» sin glifo" % [code, text])
				return
	assert_eq(ControlBindings.input_label(_button(JOY_BUTTON_PADDLE1), font), "Botón %d" % JOY_BUTTON_PADDLE1)


func test_serialization_roundtrip() -> void:
	for event: InputEvent in [_key(KEY_P), _button(JOY_BUTTON_Y), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0),
			_axis(JOY_AXIS_LEFT_X, -0.8)]:
		var back: InputEvent = ControlBindings.deserialize(ControlBindings.serialize(event))
		assert_true(ControlBindings.same_input(event, back), "Ida y vuelta de %s" % event)
	assert_null(ControlBindings.deserialize({"type": "raton"}))
	assert_null(ControlBindings.deserialize({"type": "key", "physical_keycode": 0}))


# --- Asignar ---

func test_assign_key_replaces_primary_and_keeps_others() -> void:
	assert_eq(ControlBindings.assign(&"pulse", _key(KEY_H)), ControlBindings.Result.OK)
	assert_true(_is_action(_key(KEY_H), &"pulse"), "H es el pulso")
	assert_false(_is_action(_key(KEY_G), &"pulse"), "G ya no")
	assert_true(_is_action(_button(JOY_BUTTON_X), &"pulse"), "El mando no cambia")
	assert_eq(_changes, 1, "Avisa a los prompts")
	assert_eq(ControlBindings.assign(&"move_left", _key(KEY_J)), ControlBindings.Result.OK)
	assert_true(_is_action(_key(KEY_LEFT), &"move_left"), "Las flechas siguen")
	assert_eq(ControlBindings.assign(&"pulse", _key(KEY_H)), ControlBindings.Result.UNCHANGED)


func test_assign_pad_button_and_axis() -> void:
	assert_eq(ControlBindings.assign(&"jump", _button(JOY_BUTTON_LEFT_SHOULDER)), ControlBindings.Result.OK,
		"LB no es de ninguna accion reasignable")
	assert_true(_is_action(_button(JOY_BUTTON_LEFT_SHOULDER), &"jump"))
	assert_false(_is_action(_button(JOY_BUTTON_A), &"jump"))
	assert_true(_is_action(_key(KEY_SPACE), &"jump"), "El teclado no cambia")
	assert_eq(ControlBindings.assign(&"laser", _axis(JOY_AXIS_RIGHT_Y, 1.0)), ControlBindings.Result.OK)
	assert_true(_is_action(_axis(JOY_AXIS_RIGHT_Y, 1.0), &"laser"))


func test_conflict_cancel_or_swap() -> void:
	assert_eq(ControlBindings.assign(&"jump", _key(KEY_G)), ControlBindings.Result.CONFLICT, "G es del pulso")
	assert_true(_is_action(_key(KEY_SPACE), &"jump"), "Sin intercambiar no cambia nada")
	assert_true(_is_action(_key(KEY_G), &"pulse"))
	assert_eq(_changes, 0)
	assert_eq(ControlBindings.find_conflict(_key(KEY_G), &"jump").get("action"), &"pulse")
	assert_eq(ControlBindings.assign(&"jump", _key(KEY_G), true), ControlBindings.Result.OK)
	assert_true(_is_action(_key(KEY_G), &"jump"), "Saltar con G")
	assert_true(_is_action(_key(KEY_SPACE), &"pulse"), "El pulso recibe Espacio")
	assert_false(_is_action(_key(KEY_G), &"pulse"))


func test_swap_never_leaves_an_action_without_its_device() -> void:
	ControlBindings.assign(&"jump", _key(KEY_RIGHT), true)
	assert_true(_is_action(_key(KEY_RIGHT), &"jump"))
	assert_true(_is_action(_key(KEY_SPACE), &"move_right"), "Mover a la derecha recibe la anterior")
	assert_true(_is_action(_key(KEY_D), &"move_right"))
	for action: StringName in ControlBindings.actions():
		assert_not_null(ControlBindings.primary(action, ControlBindings.Device.KEYBOARD), "%s con tecla" % action)
		assert_not_null(ControlBindings.primary(action, ControlBindings.Device.PAD), "%s con mando" % action)


func test_reserved_inputs_are_rejected() -> void:
	assert_eq(ControlBindings.assign(&"jump", _key(KEY_ESCAPE)), ControlBindings.Result.RESERVED, "Esc es de la pausa")
	assert_eq(ControlBindings.assign(&"jump", _button(JOY_BUTTON_START)), ControlBindings.Result.RESERVED)
	assert_eq(ControlBindings.assign(&"jump", _key(KEY_R)), ControlBindings.Result.RESERVED, "R reinicia")
	assert_eq(ControlBindings.assign(&"jump", _button(JOY_BUTTON_BACK)), ControlBindings.Result.RESERVED)
	assert_eq(ControlBindings.assign(&"jump", _key(KEY_F9)), ControlBindings.Result.RESERVED)
	assert_eq(ControlBindings.assign(&"restart_level", _key(KEY_P)), ControlBindings.Result.BLOCKED,
		"Las de pruebas no se reasignan")
	assert_eq(ControlBindings.assign(&"ui_accept", _key(KEY_P)), ControlBindings.Result.BLOCKED)
	assert_true(_is_action(_key(KEY_SPACE), &"jump"))


func test_pause_always_keeps_esc_and_start() -> void:
	assert_eq(ControlBindings.assign(&"pause", _key(KEY_P)), ControlBindings.Result.OK)
	assert_true(_is_action(_key(KEY_P), &"pause"), "P pausa")
	assert_true(_is_action(_key(KEY_ESCAPE), &"pause"), "Esc sigue pausando")
	assert_true(_is_action(_button(JOY_BUTTON_START), &"pause"), "Start tambien")
	assert_eq(ControlBindings.binding_label(&"pause"), "P / Start")
	ControlBindings.assign(&"pause", _button(JOY_BUTTON_RIGHT_SHOULDER), true)
	assert_true(_is_action(_button(JOY_BUTTON_START), &"pause"))
	assert_true(_is_action(_button(JOY_BUTTON_RIGHT_SHOULDER), &"pause"))


# --- Guardado ---

func test_saved_at_once_as_serialized_events_and_loaded_on_start() -> void:
	ControlBindings.assign(&"jump", _key(KEY_G), true)
	ControlBindings.assign(&"laser", _button(JOY_BUTTON_LEFT_SHOULDER))
	var config := ConfigFile.new()
	assert_eq(config.load(GameSettings.settings_path()), OK, "Guardado al instante")
	var jump: Variant = config.get_value(GameSettings.SECTION_CONTROLS, "jump")
	assert_true(jump is Array and (jump as Array).has({"type": "key", "physical_keycode": KEY_G}), "Tecla fisica")
	assert_true((config.get_value(GameSettings.SECTION_CONTROLS, "laser") as Array).has(
		{"type": "joy_button", "button": JOY_BUTTON_LEFT_SHOULDER}), "Boton")
	assert_false(config.has_section_key(GameSettings.SECTION_CONTROLS, "debug"), "Solo las que cambian")
	ControlBindings.restore_defaults(false)
	assert_true(_is_action(_key(KEY_SPACE), &"jump"))
	GameSettings.load_from_disk()
	assert_true(_is_action(_key(KEY_G), &"jump"), "Se aplican al arrancar")
	assert_true(_is_action(_key(KEY_SPACE), &"pulse"))
	assert_true(_is_action(_button(JOY_BUTTON_LEFT_SHOULDER), &"laser"))
	assert_false(GameState.has_unsaved_changes(), "No es progreso")


func test_bad_saved_controls_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value(GameSettings.SECTION_CONTROLS, "jump", [{"type": "key", "physical_keycode": KEY_G}])
	config.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_true(_is_action(_key(KEY_SPACE), &"jump"), "Sin boton de mando: la accion vuelve a su valor")
	assert_true(_is_action(_key(KEY_G), &"pulse"), "Y no queda repetida")
	config.set_value(GameSettings.SECTION_CONTROLS, "jump", [{"type": "key", "physical_keycode": KEY_G},
		{"type": "joy_button", "button": 0}])
	config.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_true(_is_action(_key(KEY_SPACE), &"jump"), "G repetida con el pulso: todo por defecto")
	config.set_value(GameSettings.SECTION_CONTROLS, "jump", [{"type": "key", "physical_keycode": KEY_ESCAPE},
		{"type": "joy_button", "button": 0}])
	config.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_false(_is_action(_key(KEY_ESCAPE), &"jump"), "Esc nunca va a otra accion")


func test_restore_defaults() -> void:
	ControlBindings.assign(&"jump", _key(KEY_G), true)
	assert_false(ControlBindings.is_default())
	ControlBindings.restore_defaults()
	assert_true(ControlBindings.is_default())
	assert_true(_is_action(_key(KEY_SPACE), &"jump"))
	var config := ConfigFile.new()
	config.load(GameSettings.settings_path())
	assert_false(config.has_section(GameSettings.SECTION_CONTROLS), "Sin cambios guardados")


# --- Prompts dinamicos ---

func test_prompts_and_notices_follow_the_new_keys() -> void:
	var prompt := HelpPrompt.new()
	add_child_autofree(prompt)
	assert_eq(prompt.get_key_text(), "Q")
	ControlBindings.assign(&"help", _key(KEY_E))
	assert_eq(prompt.get_key_text(), "E", "La Q de la ayuda pasa a E")
	assert_eq(PulsePrompt.key_text(&"help"), "E")
	ControlBindings.assign(&"pulse", _key(KEY_H))
	var notices: Dictionary = AbilityNotices.load_data()
	assert_eq(AbilityNotices.control_text(&"pulse", notices), "H / X (mando)", "«Pulso: H / X (mando)»")
	assert_eq(AbilityNotices.notice_text(&"laser", notices), "Láser: F / gatillo izquierdo")
	ControlBindings.assign(&"laser", _key(KEY_V))
	assert_eq(AbilityNotices.notice_text(&"laser", notices), "Láser: V / gatillo izquierdo")


func test_hub_station_prompt_follows_the_pulse_key() -> void:
	EcoProgress_meet_notas()
	var hub := HUB_SCENE.instantiate() as HubRoom
	add_child_autofree(hub)
	var notas: HubStation = hub.get_notas()
	assert_eq(notas.get_key_text(), "G")
	ControlBindings.assign(&"pulse", _key(KEY_H))
	assert_eq(notas.get_key_text(), "H", "El prompt de la estacion se actualiza")
	ControlBindings.restore_defaults()
	assert_eq(notas.get_key_text(), "G")


func EcoProgress_meet_notas() -> void:
	GameState.meet_ally(GameState.ALLY_NOTAS)


# --- Menu ---

func test_menu_lists_actions_with_key_and_pad() -> void:
	_spawn_menu()
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	var lines: PackedStringArray = _menu.get_lines()
	assert_eq(lines[0], "Controles")
	assert_true(lines.has("– Mover a la izquierda: A / stick a la izquierda"), "%s" % lines)
	assert_true(lines.has("  Saltar: Espacio / A"))
	assert_true(lines.has("  Restablecer valores"))
	assert_eq(_menu.get_selected_action(), &"move_left")


func test_menu_capture_assigns_and_esc_cancels() -> void:
	_spawn_menu()
	_menu.select_action(&"pulse")
	_action(&"ui_accept")
	assert_eq(_menu.get_page(), PauseMenu.Page.CAPTURE, "Pulsa una tecla o boton")
	assert_eq(_menu.get_lines()[0], "Pulsa una tecla o botón…")
	_tap(_key(KEY_ESCAPE))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS, "Esc cancela")
	assert_true(_menu.is_open(), "Sin cerrar el menu")
	assert_true(_is_action(_key(KEY_G), &"pulse"), "Sin cambios")
	assert_eq(_menu.get_selected_action(), &"pulse")
	_action(&"ui_accept")
	_tap(_key(KEY_H))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	assert_true(_is_action(_key(KEY_H), &"pulse"), "H asignada")
	assert_true(_menu.get_lines().has("– Pulso: H / X"))
	_action(&"ui_accept")
	_tap(_button(JOY_BUTTON_START))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS, "Start tambien cancela")
	_action(&"ui_accept")
	_tap(_button(JOY_BUTTON_RIGHT_SHOULDER))
	assert_true(_is_action(_button(JOY_BUTTON_RIGHT_SHOULDER), &"pulse"), "Boton de mando asignado")
	assert_true(get_tree().paused, "Todo con el juego en pausa")


func test_menu_conflict_swap_and_cancel() -> void:
	_spawn_menu()
	_menu.select_action(&"jump")
	_action(&"ui_accept")
	_tap(_key(KEY_G))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFLICT)
	assert_eq(_menu.get_conflict_action(), &"pulse")
	var lines: PackedStringArray = _menu.get_lines()
	assert_eq(lines[0], "Ya está en uso")
	assert_true(lines.has("G ya es de Pulso."), "%s" % lines)
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.CANCEL, "Empieza en Cancelar")
	_action(&"ui_accept")
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	assert_true(_is_action(_key(KEY_SPACE), &"jump"), "Cancelar no cambia nada")
	_action(&"ui_accept")
	_tap(_key(KEY_G))
	_menu.activate(PauseMenu.Option.SWAP)
	assert_true(_is_action(_key(KEY_G), &"jump"), "Intercambiar")
	assert_true(_is_action(_key(KEY_SPACE), &"pulse"))
	assert_true(_menu.get_lines().has("– Saltar: G / A"))
	_action(&"ui_accept")
	_tap(_key(KEY_H))
	_action(&"ui_accept")
	_tap(_key(KEY_H))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS, "Sin conflicto si ya es suya")


func test_menu_reserved_shows_notice() -> void:
	_spawn_menu()
	_menu.select_action(&"jump")
	_action(&"ui_accept")
	_tap(_key(KEY_R))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	assert_eq(_menu.get_notice(), "R está reservada: no se puede asignar.")
	assert_true(_is_action(_key(KEY_SPACE), &"jump"))


func test_menu_reset_asks_for_confirmation() -> void:
	ControlBindings.assign(&"jump", _key(KEY_G), true)
	_spawn_menu()
	_menu.select(PauseMenu.Option.RESET_CONTROLS)
	_action(&"ui_accept")
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFIRM_RESET)
	assert_eq(_menu.get_lines()[0], "¿Restablecer los controles?")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.BACK, "Empieza en Volver")
	_action(&"pause")
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS, "Esc vuelve sin restablecer")
	assert_false(ControlBindings.is_default())
	_action(&"ui_accept")
	_menu.activate(PauseMenu.Option.CONFIRM_RESET)
	assert_true(ControlBindings.is_default(), "Restablecido")
	assert_eq(_menu.get_notice(), "Controles restablecidos.")


func test_menu_navigation_back_and_gamepad() -> void:
	_spawn_menu()
	_tap(_button(JOY_BUTTON_DPAD_DOWN))
	assert_eq(_menu.get_selected_action(), &"move_right", "Cruceta")
	_tap(_button(JOY_BUTTON_A))
	assert_eq(_menu.get_page(), PauseMenu.Page.CAPTURE, "A acepta")
	_tap(_button(JOY_BUTTON_B))
	assert_true(_is_action(_button(JOY_BUTTON_B), &"move_right"), "En la captura, B se puede asignar")
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	ControlBindings.restore_defaults()
	_tap(_button(JOY_BUTTON_B))
	assert_eq(_menu.get_page(), PauseMenu.Page.SETTINGS, "B vuelve a Ajustes")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.CONTROLS)
	_action(&"pause")
	_action(&"pause")
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_menu_texts_have_no_difficulty_words_and_existing_glyphs() -> void:
	_spawn_menu()
	var font: Font = load(FONT_PATH) as Font
	var tags := RegEx.create_from_string("\\{[a-z_]+\\}")
	for raw: String in _menu.get_all_texts():
		var text: String = tags.sub(raw, "", true)
		for word: String in ["vuelta", "easy", "normal", "hard"]:
			assert_false(text.to_lower().contains(word), "«%s»" % text)
		for i: int in text.length():
			assert_true(text.unicode_at(i) == 32 or font.has_char(text.unicode_at(i)), "Glifo %s" % text[i])
