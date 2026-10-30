# Pausa > Ajustes > Controles con iconos y deteccion de dispositivo (2026-10-30,
# peticion del usuario tras el 5-2: «en el menu de controles vamos a colocar
# iconos a cada movimiento y solo vas a colocar la tecla o el boton… ¿se puede
# hacer que detecte el control o el teclado?»; docs/05-hub.md §13.7 y
# docs/propuesta-mundo-5.md §8.1). Lista todas las habilidades y movimientos
# (menu_rows de data/settings.json), cada fila con su icono y solo la tecla o el
# boton del ultimo dispositivo usado, leidos del Input Map; el titulo, las filas
# y la ayuda cambian en vivo con eventos simulados de teclado y mando; mapeo por
# familia de mando; los avisos {key:} y las ayudas {tecla:} siguen al
# dispositivo; ningun texto se sale del panel.
extends GutTest

var _menu: PauseMenu
var _font: Font


func before_each() -> void:
	GameSettings.use_path(GameSettings.settings_path(), true)
	GameState.reset_progress()
	ControlBindings.restore_defaults(false)
	_font = load(String(PauseMenu.load_data()["font"])) as Font


func after_each() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null
	get_tree().paused = false
	ControlBindings.restore_defaults(false)
	ControlBindings.reset_device()
	GameSettings.use_path(GameSettings.settings_path(), true)
	GameState.reset_progress()


func _spawn_menu() -> PauseMenu:
	_menu = PauseMenu.new()
	_menu.capture_arm_s = 0.0
	add_child(_menu)
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	_menu.select(PauseMenu.Option.CONTROLS)
	_menu.activate(PauseMenu.Option.CONTROLS)
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	return _menu


## Entrada simulada que pasa por todo el arbol (el autoload InputDeviceWatcher la ve).
func _push(event: InputEvent) -> void:
	get_tree().root.push_input(event)


func _pad_button(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	event.device = 0
	return event


func _pad_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = 0
	return event


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _row_text(row_id: String) -> String:
	assert_true(_menu.select_row(row_id), "Fila %s" % row_id)
	return _menu.get_option_label(_index_of(row_id)).text.trim_prefix("– ").trim_prefix("  ")


func _index_of(row_id: String) -> int:
	for i: int in _menu.get_options().size():
		if String(_menu.get_row(i).get("id", "")) == row_id:
			return i
	return -1


# --- Todas las acciones, con icono y solo la tecla ---

func test_menu_lists_every_move_ability_and_combo_with_its_icon() -> void:
	_spawn_menu()
	var ids: Array[String] = []
	var actions: Array[StringName] = []
	for i: int in _menu.get_options().size():
		var row: Dictionary = _menu.get_row(i)
		if row.is_empty():
			continue
		ids.append(String(row["id"]))
		actions.append_array(ControlBindings.row_actions(row))
		var icon: Texture2D = _menu.get_option_icon(i)
		assert_not_null(icon, "%s con icono" % row["id"])
		assert_eq(icon.get_size(), Vector2(12, 12), "Icono de 12 px como los del menu")
	for needed: String in ["move_left", "move_right", "jump", "run", "pulse", "laser", "debug", "dash", "compress",
			"ground_pound", "hide", "combo_ram", "combo_edge", "combo_quake", "help", "pause", "restart"]:
		assert_has(ids, needed, "Fila de %s" % needed)
	for action: StringName in ControlBindings.actions():
		assert_has(actions, action, "Toda accion reasignable tiene su fila: %s" % action)
	var options: Array[PauseMenu.Option] = _menu.get_options()
	assert_eq(options[options.size() - 2], PauseMenu.Option.RESET_CONTROLS)
	assert_eq(options[options.size() - 1], PauseMenu.Option.BACK)


func test_rows_show_only_the_key_and_the_detail_says_the_name() -> void:
	_spawn_menu()
	assert_eq(_menu.get_lines()[0], "Controles · teclado")
	assert_eq(_row_text("jump"), "Espacio")
	assert_eq(_row_text("dash"), "L")
	assert_eq(_row_text("compress"), "I")
	assert_eq(_row_text("ground_pound"), "S")
	assert_eq(_row_text("combo_ram"), "Espacio, L, S", "Embestida: Saltar, Deslizar y abajo")
	assert_eq(_row_text("combo_edge"), "Espacio, I, L", "Filo: Saltar, Comprimir y Deslizar")
	assert_eq(_row_text("combo_quake"), "Espacio, I, S", "Sismo: Saltar, Comprimir y abajo")
	assert_eq(_row_text("restart"), "R")
	_menu.select_row("combo_ram")
	assert_true(_menu.get_lines().has("Embestida: salta, dash y abajo"), "El nombre va en el detalle")
	assert_true(_menu.get_lines().has("Arriba/abajo: elegir. Intro: cambiar. Esc: volver"))


func test_combo_and_fixed_rows_only_inform_and_actions_still_remap() -> void:
	_spawn_menu()
	_menu.select_row("combo_edge")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.CONTROL_INFO)
	_menu.activate(_menu.get_selected_option())
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS, "Un combo no se captura")
	assert_eq(_menu.get_notice(), "Se hace con sus acciones: cámbialas arriba.")
	_menu.select_row("restart")
	_menu.activate(_menu.get_selected_option())
	assert_eq(_menu.get_notice(), "Esta tecla no se puede cambiar.")
	_menu.select_row("compress")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.BINDING)
	_menu.activate(_menu.get_selected_option())
	assert_eq(_menu.get_page(), PauseMenu.Page.CAPTURE, "Comprimir se reasigna como siempre")
	assert_true(_menu.handle_capture(_key(KEY_O)))
	assert_eq(_row_text("compress"), "O")
	assert_eq(_row_text("combo_edge"), "Espacio, O, L", "El combo sigue a su accion")


func test_rows_follow_the_input_map_without_extra_data() -> void:
	# Lo que haria cambiar la tecla en project.godot: el Input Map. El menu no
	# guarda nombres: se lee cada vez.
	var old: Array[InputEvent] = InputMap.action_get_events(&"jump")
	InputMap.action_erase_events(&"jump")
	InputMap.action_add_event(&"jump", _key(KEY_J, false))
	for event: InputEvent in old:
		if not event is InputEventKey:
			InputMap.action_add_event(&"jump", event)
	_spawn_menu()
	assert_eq(_row_text("jump"), "J")
	assert_eq(_row_text("combo_quake"), "J, I, S")
	InputMap.action_erase_events(&"jump")
	for event: InputEvent in old:
		InputMap.action_add_event(&"jump", event)


# --- Deteccion de teclado o mando ---

func test_device_switches_live_with_simulated_events() -> void:
	_spawn_menu()
	watch_signals(EventBus)
	_push(_pad_button(JOY_BUTTON_DPAD_DOWN))
	_push(_pad_button(JOY_BUTTON_DPAD_DOWN, false))
	assert_eq(ControlBindings.last_device(), ControlBindings.Device.PAD, "Un boton del mando")
	assert_signal_emitted(EventBus, "input_device_changed")
	assert_eq(_menu.get_lines()[0], "Controles · mando", "El titulo cambia en vivo")
	assert_eq(_row_text("jump"), "A")
	assert_eq(_row_text("dash"), "B")
	assert_eq(_row_text("pulse"), "X")
	assert_eq(_row_text("debug"), "Y")
	assert_eq(_row_text("compress"), "RB")
	assert_eq(_row_text("laser"), "LT")
	assert_eq(_row_text("run"), "RT")
	assert_eq(_row_text("move_left"), "Stick izquierda")
	assert_eq(_row_text("ground_pound"), "Stick abajo")
	assert_eq(_row_text("combo_ram"), "A, B, Stick abajo")
	assert_eq(_row_text("pause"), "Start")
	assert_eq(_row_text("restart"), "Select")
	assert_true(_menu.get_lines().has("Arriba/abajo: elegir. A: cambiar. B: volver"), "%s" % _menu.get_lines())
	# Un eje casi quieto no cuenta; una tecla vuelve al teclado.
	_push(_key(KEY_W))
	assert_eq(ControlBindings.last_device(), ControlBindings.Device.KEYBOARD)
	assert_eq(_menu.get_lines()[0], "Controles · teclado")
	_push(_pad_axis(JOY_AXIS_LEFT_Y, 0.2))
	assert_eq(ControlBindings.last_device(), ControlBindings.Device.KEYBOARD, "Deriva del stick: no cambia")
	_push(_pad_axis(JOY_AXIS_LEFT_Y, 0.9))
	assert_eq(ControlBindings.last_device(), ControlBindings.Device.PAD, "Stick inclinado: mando")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_push(click)
	assert_eq(ControlBindings.last_device(), ControlBindings.Device.KEYBOARD, "El raton cuenta como teclado")
	assert_eq(_row_text("jump"), "Espacio")


func test_known_controller_families_use_their_names() -> void:
	assert_eq(ControlBindings.family_for_name("PS5 Controller"), "playstation")
	assert_eq(ControlBindings.family_for_name("Sony DualSense Wireless Controller"), "playstation")
	assert_eq(ControlBindings.family_for_name("Xbox Series Controller"), "xbox")
	assert_eq(ControlBindings.family_for_name("Nintendo Switch Pro Controller"), "nintendo")
	assert_eq(ControlBindings.family_for_name("USB Gamepad"), "", "Sin coincidencia: generico")
	_spawn_menu()
	ControlBindings.set_last_device(ControlBindings.Device.PAD, "playstation")
	assert_eq(_menu.get_lines()[0], "Controles · mando PlayStation")
	assert_eq(_row_text("jump"), "Cruz")
	assert_eq(_row_text("dash"), "Círculo")
	assert_eq(_row_text("pulse"), "Cuadrado")
	assert_eq(_row_text("debug"), "Triángulo")
	assert_eq(_row_text("compress"), "R1")
	assert_eq(_row_text("laser"), "L2")
	assert_eq(_row_text("pause"), "Options")
	ControlBindings.set_last_device(ControlBindings.Device.PAD, "xbox")
	assert_eq(_menu.get_lines()[0], "Controles · mando Xbox")
	assert_eq(_row_text("jump"), "A")
	ControlBindings.set_last_device(ControlBindings.Device.PAD, "nintendo")
	assert_eq(_row_text("jump"), "B", "Nintendo: el boton de abajo se llama B")
	assert_eq(_row_text("laser"), "ZL")


func test_notices_and_help_follow_the_device() -> void:
	var data: Dictionary = AbilityNotices.load_data()
	var ram: String = AbilityNotices.explain_lines(GameState.ABILITY_COMBO, data)[0]
	assert_true(ram.contains("Saltar (Espacio), Deslizar (L) y mantén abajo (S)"), ram)
	assert_eq(TextMarkers.apply_keys("{tecla:debug}"), "K")
	ControlBindings.set_last_device(ControlBindings.Device.PAD)
	ram = AbilityNotices.explain_lines(GameState.ABILITY_COMBO, data)[0]
	assert_true(ram.contains("Saltar (A), Deslizar (B) y mantén abajo (stick abajo)"), ram)
	assert_eq(TextMarkers.apply_keys("{tecla:debug}"), "Y")
	assert_eq(AbilityNotices.notice_text(&"dash", data), "Deslizar: L / B (mando)", "El control dice los dos")
	ControlBindings.reset_device()
	assert_eq(TextMarkers.apply_keys("{tecla:debug}"), "K")


# --- Tamano fijo y textos dentro del panel ---

func test_no_text_leaves_the_fixed_panel_on_any_device() -> void:
	_spawn_menu()
	var size: Vector2 = _menu.fixed_panel_size()
	var font_size: int = int(PauseMenu.load_data().get("font_size", 12))
	for setup: Array in [[ControlBindings.Device.KEYBOARD, ""], [ControlBindings.Device.PAD, ""],
			[ControlBindings.Device.PAD, "playstation"], [ControlBindings.Device.PAD, "nintendo"]]:
		ControlBindings.reset_device()
		ControlBindings.set_last_device(setup[0], setup[1])
		_menu.go_back()
		_menu.activate(PauseMenu.Option.CONTROLS)
		for i: int in _menu.get_options().size():
			if i > 0:
				_menu.move_selection(1)
			var label: Label = _menu.get_option_label(i)
			assert_true(_menu.is_option_shown(i), "La elegida siempre se ve")
			var w: float = _font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			assert_true(label.position.x >= 0.0 and label.position.x + w <= size.x - 3.0,
				"Fila %d «%s» dentro del panel (%s)" % [i, label.text, setup])
			for node_name: String in ["Title", "Detail", "Help"]:
				var fixed: Label = _menu.get_node("Frame/Panel/" + node_name) as Label
				var tw: float = _font.get_string_size(fixed.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				assert_true(tw <= fixed.size.x and fixed.position.x >= 0.0 and fixed.position.x + fixed.size.x <= size.x,
					"%s «%s» dentro del panel (%s)" % [node_name, fixed.text, setup])
		assert_eq(_menu.get_panel_rect().size / 2.0, size, "Mismo tamano fijo del panel")


func test_long_list_scrolls_with_arrows_and_ui_sound() -> void:
	_spawn_menu()
	watch_signals(_menu)
	assert_gt(_menu.get_options().size(), _menu.visible_option_rows(), "No caben: ventana con desplazamiento")
	assert_eq(_menu.scroll_arrows_shown(), Vector2i(0, 1), "Al principio, solo ▼")
	_menu.move_selection(-1)
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.BACK)
	assert_eq(_menu.scroll_arrows_shown(), Vector2i(1, 0), "Al final, solo ▲")
	assert_signal_emitted_with_parameters(_menu, "ui_feedback", [&"move"])

