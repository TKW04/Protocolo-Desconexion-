extends GutTest
# Accion `help` (ayuda de Eco con Q; docs/propuesta-asistentes-y-vidas.md §3.1
# y paso 1 de §10): Q en el teclado y R3 (boton 8) en el mando, sin choques con
# ninguna otra accion del Input Map.


func _q() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	return key


func _r3() -> InputEventJoypadButton:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_RIGHT_STICK
	return button


func test_help_action_exists_with_q_and_r3() -> void:
	assert_true(InputMap.has_action(&"help"), "Existe la accion help")
	assert_true(InputMap.event_is_action(_q(), &"help"), "Q pide ayuda")
	assert_true(InputMap.event_is_action(_r3(), &"help"), "R3 pide ayuda")
	assert_eq(InputMap.action_get_events(&"help").size(), 2, "Solo Q y R3")


func test_q_and_r3_belong_only_to_help() -> void:
	for action: StringName in InputMap.get_actions():
		if action == &"help":
			continue
		assert_false(InputMap.event_is_action(_q(), action), "Q no choca con %s" % action)
		assert_false(InputMap.event_is_action(_r3(), action), "R3 no choca con %s" % action)


func test_help_events_do_not_trigger_other_actions_keys() -> void:
	# Ninguna otra accion de juego reutiliza las teclas o botones de help.
	for event: InputEvent in InputMap.action_get_events(&"help"):
		for action: StringName in InputMap.get_actions():
			if action == &"help" or String(action).begins_with("ui_"):
				continue
			assert_false(InputMap.event_is_action(event, action), "%s libre en %s" % [event.as_text(), action])
