# Menu de pausa (PauseMenu, data/pause_menu.json; 2026-10-16, paso 13 de
# docs/propuesta-asistentes-y-vidas.md y preguntas 6 y 9 de
# docs/propuesta-hub-y-guardado.md): accion pause (Esc / Start) sin choques;
# abrir y cerrar (pause, «Reanudar», mando) sin dejar el arbol en pausa;
# convencion de pausas anidadas (no pisa ni quita la pausa de una linea
# importante de Eco; no se abre con el arbol en pausa ni con un bloqueador);
# se libera al salir del arbol; play_time_s no avanza con el menu abierto;
# «Cerrar el juego» pasa por QuitGuard; en el hub, el icono de ajustes lo abre y
# los paneles lo bloquean; en un nivel, los fundidos y el vortice lo bloquean;
# textos sin vuelta ni Easy/Normal/Hard.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const ECO_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SAVE_PATH: String = "user://test_pause_menu.json"
const LONG_STEP_S: float = 5.0
const FORBIDDEN: Array[String] = ["vuelta", "easy", "normal", "hard"]


class Blocker:
	extends Node
	var block: bool = true

	func blocks_pause_menu() -> bool:
		return block


var _menu: PauseMenu
var _hub: HubRoom
var _main: LevelRunner
var _saved_path: String
var _saved_pause_important: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	GameState.use_save_path(SAVE_PATH, true)
	GameSettings.reset_defaults()


func after_each() -> void:
	for node: Node in [_menu, _hub, _main]:
		if node != null and is_instance_valid(node):
			node.free()
	_menu = null
	_hub = null
	_main = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	GameState.reset_progress()
	SaveFile.delete(SAVE_PATH)
	GameState.save_path = _saved_path
	GameSettings.reset_defaults()


func _spawn_menu() -> PauseMenu:
	_menu = PauseMenu.new()
	add_child(_menu)
	return _menu


func _push(event: InputEvent) -> void:
	get_viewport().push_input(event)


func _action(action: StringName, pressed: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _press(action: StringName) -> void:
	_push(_action(action))
	_push(_action(action, false))


func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_push(event)


func _esc() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	return key


func _start() -> InputEventJoypadButton:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_START
	return button


# --- Accion pause ---

func test_pause_action_has_esc_and_start() -> void:
	assert_true(InputMap.has_action(&"pause"))
	assert_true(InputMap.event_is_action(_esc(), &"pause"), "Esc pausa")
	assert_true(InputMap.event_is_action(_start(), &"pause"), "Start pausa")
	assert_eq(InputMap.action_get_events(&"pause").size(), 2, "Solo Esc y Start")


func test_esc_and_start_do_not_clash_with_game_actions() -> void:
	for action: StringName in InputMap.get_actions():
		if action == &"pause" or String(action).begins_with("ui_"):
			continue
		assert_false(InputMap.event_is_action(_esc(), action), "Esc libre en %s" % action)
		assert_false(InputMap.event_is_action(_start(), action), "Start libre en %s" % action)
	var select := InputEventJoypadButton.new()
	select.button_index = JOY_BUTTON_BACK
	assert_true(InputMap.event_is_action(select, &"restart_level"), "Select/Back sigue siendo restart_level")
	assert_false(InputMap.event_is_action(select, &"pause"))


# --- Abrir y cerrar ---

func test_pause_action_opens_and_closes_without_leaving_tree_paused() -> void:
	_spawn_menu()
	assert_false(_menu.is_open())
	assert_false(_menu.visible)
	_press(&"pause")
	assert_true(_menu.is_open(), "pause lo abre")
	assert_true(_menu.visible)
	assert_true(get_tree().paused, "Pausa el juego")
	assert_true(_menu.owns_pause())
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.get_options(), [PauseMenu.Option.RESUME, PauseMenu.Option.SETTINGS,
		PauseMenu.Option.QUIT] as Array[PauseMenu.Option])
	_press(&"pause")
	assert_false(_menu.is_open(), "pause lo cierra")
	assert_false(get_tree().paused, "Reanuda")
	assert_false(_menu.owns_pause())


func test_resume_option_closes() -> void:
	_spawn_menu()
	assert_true(_menu.request_open())
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.RESUME, "Reanudar, la primera")
	_press(&"ui_accept")
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_gamepad_navigation_accept_back_and_start() -> void:
	_spawn_menu()
	_joy(JOY_BUTTON_START)
	assert_true(_menu.is_open(), "Start lo abre")
	_joy(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.SETTINGS, "La cruceta baja")
	_joy(JOY_BUTTON_A)
	assert_eq(_menu.get_page(), PauseMenu.Page.SETTINGS, "A acepta")
	_joy(JOY_BUTTON_B)
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN, "B vuelve a la principal")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.SETTINGS)
	_joy(JOY_BUTTON_B)
	assert_false(_menu.is_open(), "B en la principal reanuda")
	_joy(JOY_BUTTON_START)
	_joy(JOY_BUTTON_START)
	assert_false(_menu.is_open(), "Start lo cierra")
	assert_false(get_tree().paused)


func test_settings_page_toggles_eco_help_and_back() -> void:
	_spawn_menu()
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	assert_eq(_menu.get_options(), [PauseMenu.Option.ECO_HELP, PauseMenu.Option.BACK] as Array[PauseMenu.Option])
	assert_eq(_menu.option_text(PauseMenu.Option.ECO_HELP), "Ayudas de Eco: Mostrar")
	_press(&"ui_accept")
	assert_false(GameSettings.is_eco_help_shown(), "Aceptar cambia el ajuste")
	assert_eq(_menu.option_text(PauseMenu.Option.ECO_HELP), "Ayudas de Eco: Ocultar")
	assert_true(_menu.get_lines()[1].ends_with("Ayudas de Eco: Ocultar"))
	_press(&"ui_right")
	assert_true(GameSettings.is_eco_help_shown(), "Izquierda/derecha tambien")
	assert_true(get_tree().paused, "Sigue en pausa en Ajustes")
	_menu.activate(PauseMenu.Option.BACK)
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN)
	_menu.close()


func test_exit_tree_releases_pause() -> void:
	_spawn_menu()
	_menu.request_open()
	assert_true(get_tree().paused)
	remove_child(_menu)
	assert_false(get_tree().paused, "Quitar el menu (cambio de escena) reanuda")
	_menu.free()
	_menu = null


# --- Pausas anidadas ---

func test_does_not_open_over_an_important_eco_line_nor_release_it() -> void:
	_spawn_menu()
	var box := ECO_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.show_line("Linea importante.", -1.0, true)
	assert_true(get_tree().paused, "La linea importante pausa")
	assert_true(box.is_pausing_game())
	assert_false(_menu.request_open(), "Con la pausa de otro no se abre")
	_press(&"pause")
	assert_false(_menu.is_open())
	assert_true(get_tree().paused, "La pausa de Eco sigue")
	box.finish_typing()
	assert_true(box.confirm())
	box.advance(1.0)
	assert_false(get_tree().paused, "Al cerrar la linea se reanuda")


func test_open_menu_keeps_ownership_when_others_try_to_pause() -> void:
	_spawn_menu()
	_menu.request_open()
	var box := ECO_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.show_line("Linea importante.", -1.0, true)
	assert_false(box.is_pausing_game(), "El cuadro no es dueno de una pausa ajena")
	box.finish_typing()
	box.confirm()
	box.advance(1.0)
	assert_false(box.is_showing())
	assert_true(get_tree().paused, "Cerrar la linea no quita la pausa del menu")
	_menu.close()
	assert_false(get_tree().paused)


func test_blockers_and_normal_eco_lines_prevent_opening() -> void:
	_spawn_menu()
	var blocker := Blocker.new()
	blocker.add_to_group(PauseMenu.BLOCKER_GROUP)
	add_child_autofree(blocker)
	assert_false(_menu.can_open(), "Un bloqueador lo impide")
	blocker.block = false
	assert_true(_menu.can_open())
	var box := ECO_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.show_line("Linea normal.")
	assert_false(get_tree().paused, "Las normales no pausan")
	assert_false(_menu.can_open(), "Con una linea de Eco en pantalla no se abre")


func test_quit_guard_prompt_takes_over_and_back_keeps_menu() -> void:
	var quits: Array[int] = []
	var guard := QuitGuard.new()
	guard.quit_handler = func() -> void: quits.append(1)
	add_child_autofree(guard)
	_spawn_menu()
	_menu.quit_guard = guard
	_menu.request_open()
	_menu.activate(PauseMenu.Option.QUIT)
	assert_eq(quits.size(), 1, "Sin cambios sin guardar, cierra")
	GameState.request_save()
	_menu.activate(PauseMenu.Option.QUIT)
	assert_true(guard.is_prompt_open(), "Con cambios, el aviso de QuitGuard")
	assert_eq(quits.size(), 1)
	_press(&"ui_down")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.RESUME, "Con el aviso abierto el menu no lee la entrada")
	guard.choose(QuitGuard.Choice.BACK)
	assert_true(_menu.is_open(), "Volver deja el menu abierto")
	assert_true(get_tree().paused)
	_menu.close()
	assert_false(get_tree().paused)


func test_play_time_does_not_advance_while_open() -> void:
	_spawn_menu()
	await wait_process_frames(2)
	_menu.request_open()
	var before: float = GameState.play_time_s
	await wait_process_frames(10)
	assert_eq(GameState.play_time_s, before, "Con el menu abierto no cuenta el tiempo de juego")
	_menu.close()
	await wait_process_frames(5)
	assert_gt(GameState.play_time_s, before, "Al reanudar vuelve a contar")


func test_texts_never_name_laps_or_difficulty() -> void:
	_spawn_menu()
	var texts: PackedStringArray = _menu.get_all_texts()
	assert_gt(texts.size(), 5)
	for text: String in texts:
		for word: String in FORBIDDEN:
			assert_false(text.to_lower().contains(word), "«%s» no dice %s" % [text, word])
	assert_false(texts.has("Salir al hub"), "Sin «Salir al hub» (no definido en el documento)")


# --- Hub ---

func _spawn_hub() -> void:
	EcoProgress.meet_notas()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	_hub.get_arrival_vortex().advance(LONG_STEP_S)


func test_hub_blocks_during_arrival_and_with_a_panel_open() -> void:
	EcoProgress.meet_notas()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var menu: PauseMenu = PauseMenu.find_in(get_tree())
	assert_false(menu.can_open(), "Durante la llegada no")
	_hub.get_arrival_vortex().advance(LONG_STEP_S)
	assert_true(menu.can_open())
	var notas: NotasStation = _hub.get_notas()
	assert_true(notas.open(_hub.get_isak()), "Abre el panel de Notas")
	assert_true(_hub.blocks_pause_menu(), "Con un panel abierto no")
	assert_false(menu.request_open())
	_press(&"pause")
	assert_false(menu.is_open())
	assert_false(get_tree().paused, "Los paneles del hub no pausan y el menu no los pisa")


func test_hub_menu_does_not_mark_unsaved_nor_write_the_save() -> void:
	_spawn_hub()
	var menu: PauseMenu = PauseMenu.find_in(get_tree())
	menu.request_open()
	menu.activate(PauseMenu.Option.SETTINGS)
	menu.activate(PauseMenu.Option.ECO_HELP)
	assert_false(GameState.has_unsaved_changes(), "El ajuste no marca «sin guardar»")
	assert_false(FileAccess.file_exists(SAVE_PATH), "Ni escribe el guardado")
	menu.close()


# --- Nivel (flujo del juego) ---

func test_level_flow_hosts_menu_and_blocks_during_fade_and_arrival() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.get_ability_notices().auto_advance = false
	var menu: PauseMenu = _main.get_pause_menu()
	assert_eq(PauseMenu.find_in(get_tree()), menu, "Un solo menu: el del flujo")
	assert_false(menu.can_open(), "Durante el fundido de entrada no")
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	assert_false(menu.can_open(), "Con Isak en el vortice de llegada no")
	var vortex: WarpVortex = _main.get_arrival_vortex()
	var guard: int = 600
	while vortex != null and not vortex.is_done() and guard > 0:
		vortex.advance(1.0 / 60.0)
		guard -= 1
	assert_false(_main.get_isak().is_warping())
	_press(&"pause")
	assert_true(menu.is_open(), "Jugando, pause abre el menu")
	assert_true(get_tree().paused)
	_press(&"restart_level")
	assert_eq(_main.get_restart_count(), 0, "En pausa la R no reinicia")
	_press(&"pause")
	assert_false(get_tree().paused)
