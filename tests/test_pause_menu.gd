# Menu de pausa (PauseMenu, data/pause_menu.json; 2026-10-16, paso 13 de
# docs/propuesta-asistentes-y-vidas.md y preguntas 6 y 9 de
# docs/propuesta-hub-y-guardado.md): accion pause (Esc / Start) sin choques;
# abrir y cerrar (pause, «Reanudar», mando) sin dejar el arbol en pausa;
# convencion de pausas anidadas (no pisa ni quita la pausa de una linea
# importante de Eco; no se abre con el arbol en pausa ni con un bloqueador);
# se libera al salir del arbol; play_time_s no avanza con el menu abierto;
# «Cerrar el juego» pasa por QuitGuard; en el hub, el icono de ajustes lo abre y
# los paneles lo bloquean; en un nivel, los fundidos y el vortice lo bloquean;
# textos sin vuelta ni Easy/Normal/Hard. Navegacion (2026-10-16): pause y B
# vuelven una pagina atras. «Salir al hub» solo en un nivel completado, con
# confirmacion; no gasta vidas, no marca «sin guardar», no escribe y vuelve al
# hub con la llegada normal; ausente en el hub y en niveles no completados.
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
	assert_eq(_menu.get_options(), [PauseMenu.Option.ECO_HELP, PauseMenu.Option.LOW_SYNC,
		PauseMenu.Option.DEBUG_OUTLINE, PauseMenu.Option.DISPLAY, PauseMenu.Option.CONTROLS, PauseMenu.Option.BACK] as Array[PauseMenu.Option])
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
	assert_true(texts.has("Salir al hub"), "«Salir al hub» (decision del 2026-10-16)")
	assert_true(texts.has("¿Salir al hub?") and texts.has("Perderás este intento."), "Con su confirmacion")


# --- Hub ---

func _spawn_hub() -> void:
	EcoProgress.meet_notas()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	_hub.get_arrival_vortex().advance(LONG_STEP_S)


func test_hub_has_its_own_menu_and_icon_opens_it() -> void:
	_spawn_hub()
	var menu: PauseMenu = PauseMenu.find_in(get_tree())
	assert_not_null(menu, "Abierto solo, el hub crea su menu")
	assert_eq(menu.get_parent(), _hub)
	assert_true(_hub.has_arrived())
	var icon: TextureRect = _hub.get_hud().get_settings_icon()
	assert_not_null(icon, "Icono de ajustes en el HUD del hub")
	assert_eq(icon.texture.resource_path, "res://assets/sprites/hub/icons/icon_settings_00.png")
	assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_STOP, "Se puede pulsar")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	icon.gui_input.emit(click)
	assert_true(menu.is_open(), "El icono abre el menu de pausa")
	assert_true(get_tree().paused)
	menu.close()
	_press(&"pause")
	assert_true(menu.is_open(), "En el hub tambien con la accion pause")
	menu.close()
	assert_false(get_tree().paused)


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


# --- Navegacion: pause / B vuelven una pagina ---

func test_pause_on_settings_goes_back_one_page_then_resumes() -> void:
	_spawn_menu()
	_press(&"pause")
	_menu.activate(PauseMenu.Option.SETTINGS)
	assert_eq(_menu.get_page(), PauseMenu.Page.SETTINGS)
	_press(&"pause")
	assert_true(_menu.is_open(), "Esc en Ajustes no reanuda")
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN, "Vuelve a la principal")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.SETTINGS, "Con Ajustes elegido")
	assert_true(get_tree().paused)
	_press(&"pause")
	assert_false(_menu.is_open(), "La segunda pulsacion reanuda")
	assert_false(get_tree().paused)


func test_start_on_settings_goes_back_one_page() -> void:
	_spawn_menu()
	_joy(JOY_BUTTON_START)
	_menu.activate(PauseMenu.Option.SETTINGS)
	_joy(JOY_BUTTON_START)
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN, "Start tambien vuelve una pagina")
	_joy(JOY_BUTTON_START)
	assert_false(_menu.is_open())


# --- Salir al hub ---

class HubExitStub:
	extends RefCounted
	var available: bool = true
	var requests: int = 0

	func can_exit_to_hub() -> bool:
		return available

	func request_exit_to_hub() -> bool:
		requests += 1
		return available


func test_exit_to_hub_absent_without_provider_or_when_unavailable() -> void:
	_spawn_menu()
	_menu.request_open()
	assert_false(_menu.get_options().has(PauseMenu.Option.EXIT_TO_HUB), "Sin LevelRunner, no")
	_menu.close()
	var stub := HubExitStub.new()
	stub.available = false
	_menu.hub_exit = stub
	_menu.request_open()
	assert_false(_menu.get_options().has(PauseMenu.Option.EXIT_TO_HUB), "No disponible, no")
	_menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN, "Ni se puede forzar")
	_menu.close()


func test_exit_to_hub_asks_for_confirmation() -> void:
	var stub := HubExitStub.new()
	_spawn_menu()
	_menu.hub_exit = stub
	_menu.request_open()
	assert_eq(_menu.get_options(), [PauseMenu.Option.RESUME, PauseMenu.Option.SETTINGS,
		PauseMenu.Option.EXIT_TO_HUB, PauseMenu.Option.QUIT] as Array[PauseMenu.Option])
	assert_eq(_menu.option_text(PauseMenu.Option.EXIT_TO_HUB), "Salir al hub")
	_menu.select(PauseMenu.Option.EXIT_TO_HUB)
	_press(&"ui_accept")
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFIRM_HUB, "Pide confirmacion")
	var lines: PackedStringArray = _menu.get_lines()
	assert_eq(lines[0], "¿Salir al hub?")
	assert_true(lines[1].ends_with("Salir") and lines[2].ends_with("Volver"), "Salir / Volver: %s" % lines)
	assert_true(lines.has("Perderás este intento."))
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.BACK, "Empieza en Volver")
	assert_eq(stub.requests, 0)
	_press(&"ui_accept")
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN, "Volver")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.EXIT_TO_HUB)
	_menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	_press(&"pause")
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN, "Esc en la confirmacion vuelve a la principal")
	assert_true(_menu.is_open())
	assert_eq(stub.requests, 0, "Sin confirmar no sale")
	_menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	_menu.activate(PauseMenu.Option.CONFIRM_EXIT)
	assert_eq(stub.requests, 1, "Salir lo pide")
	assert_false(_menu.is_open(), "Y cierra el menu")
	assert_false(get_tree().paused, "Quitando su pausa")


func _start_flow_playing() -> PauseMenu:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.get_ability_notices().auto_advance = false
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	var guard: int = 600
	while vortex != null and not vortex.is_done() and guard > 0:
		vortex.advance(1.0 / 60.0)
		guard -= 1
	return _main.get_pause_menu()


func test_level_not_completed_has_no_exit_to_hub() -> void:
	var menu: PauseMenu = _start_flow_playing()
	assert_false(_main.can_exit_to_hub(), "1-1 sin completar")
	assert_true(menu.request_open())
	assert_false(menu.get_options().has(PauseMenu.Option.EXIT_TO_HUB))
	menu.close()


func test_exit_to_hub_from_a_completed_level() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	# Completado en la partida actual sin marcar «sin guardar» (como tras cargar).
	GameState.completed_levels[&"1-1"] = true
	var menu: PauseMenu = _start_flow_playing()
	assert_false(GameState.has_unsaved_changes())
	var lives: int = GameState.lives
	assert_true(GameState.lose_life() == false, "Gasta una vida en el intento")
	lives = GameState.lives
	var points: int = GameState.attention_points
	assert_true(_main.can_exit_to_hub(), "Nivel completado: se ofrece")
	_press(&"pause")
	assert_true(menu.get_options().has(PauseMenu.Option.EXIT_TO_HUB))
	menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	assert_true(get_tree().paused, "La confirmacion sigue en pausa")
	assert_true(menu.owns_pause())
	menu.activate(PauseMenu.Option.CONFIRM_EXIT)
	assert_false(menu.is_open())
	assert_false(get_tree().paused, "El menu quita su pausa")
	assert_true(_main.blocks_pause_menu(), "Durante el fundido no se reabre")
	assert_false(menu.request_open())
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_eq(_main.get_hub_exit_count(), 1)
	assert_eq(_main.get_game_over_count(), 0, "Sin game over")
	assert_eq(GameState.lives, lives, "No gasta vidas")
	assert_eq(GameState.attention_points, points)
	assert_false(GameState.has_unsaved_changes(), "No marca «sin guardar»")
	assert_false(FileAccess.file_exists(SAVE_PATH), "Ni escribe el guardado")
	assert_true(GameState.is_level_completed(&"1-1"), "El nivel sigue completado")
	assert_not_null(_main.get_hub().get_arrival_vortex(), "Llegada normal por el vortice")
	_main.advance(LONG_STEP_S)
	_main.get_hub().get_arrival_vortex().advance(LONG_STEP_S)
	assert_true(_main.get_hub().has_arrived())
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max(), "Sync Rate lleno")
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "Energia llena")
	assert_false(_main.can_exit_to_hub(), "En el hub no se ofrece")
	assert_true(menu.request_open(), "El menu del flujo sirve en el hub")
	assert_false(menu.get_options().has(PauseMenu.Option.EXIT_TO_HUB), "Sin «Salir al hub» en el hub")
	menu.close()
	assert_false(get_tree().paused)


func test_exit_confirmation_does_not_break_nested_pauses() -> void:
	GameState.completed_levels[&"1-1"] = true
	var menu: PauseMenu = _start_flow_playing()
	menu.request_open()
	menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	var box := ECO_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.show_line("Linea importante.", -1.0, true)
	assert_false(box.is_pausing_game(), "El cuadro no se apropia de la pausa del menu")
	menu.go_back()
	assert_eq(menu.get_page(), PauseMenu.Page.MAIN)
	assert_true(get_tree().paused, "Volver de la confirmacion no quita la pausa")
	menu.close()
	assert_false(get_tree().paused)
	box.finish_typing()
	box.confirm()
	box.advance(1.0)
	assert_false(get_tree().paused)


# --- Ajustes de accesibilidad (Si / No) ---

func test_accessibility_switches_save_and_apply_at_once() -> void:
	_spawn_menu()
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	assert_eq(_menu.option_text(PauseMenu.Option.LOW_SYNC), "Reducir efectos de Sync bajo: No")
	assert_eq(_menu.option_text(PauseMenu.Option.DEBUG_OUTLINE), "Contorno del Debug de alto contraste: No")
	_menu.select(PauseMenu.Option.LOW_SYNC)
	assert_true(_menu.get_lines().has("Con Sync Rate bajo, la señal parpadea en rojo."), "El detalle del elegido")
	_press(&"ui_accept")
	assert_true(GameSettings.is_low_sync_reduced())
	assert_true(GameState.reduce_low_sync_effects, "Se aplica al momento")
	assert_eq(_menu.option_text(PauseMenu.Option.LOW_SYNC), "Reducir efectos de Sync bajo: Sí")
	assert_true(_menu.get_lines().has("Con Sync Rate bajo, la señal queda en rojo sin parpadear."))
	_menu.select(PauseMenu.Option.DEBUG_OUTLINE)
	_press(&"ui_left")
	assert_true(GameSettings.is_debug_outline_high_contrast(), "Izquierda/derecha tambien")
	assert_true(GameState.debug_high_contrast_outline)
	var config := ConfigFile.new()
	assert_eq(config.load(GameSettings.settings_path()), OK, "Guardado al instante")
	assert_eq(config.get_value(GameSettings.SECTION_ACCESSIBILITY, "reduce_low_sync_effects"), true)
	assert_eq(config.get_value(GameSettings.SECTION_ACCESSIBILITY, "debug_high_contrast_outline"), true)
	assert_false(GameState.has_unsaved_changes(), "No es progreso")
	_press(&"ui_right")
	assert_false(GameState.debug_high_contrast_outline, "Vuelve a No")
	_menu.close()
	GameSettings.use_path(GameSettings.settings_path(), true)
	assert_false(GameState.reduce_low_sync_effects, "Ajustes nuevos: valores por defecto")


# --- Pantalla ---

func test_display_page_mode_size_and_back() -> void:
	_spawn_menu()
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	_menu.select(PauseMenu.Option.DISPLAY)
	_press(&"ui_accept")
	assert_eq(_menu.get_page(), PauseMenu.Page.DISPLAY)
	assert_eq(_menu.get_options(), [PauseMenu.Option.WINDOW_MODE, PauseMenu.Option.WINDOW_SIZE,
		PauseMenu.Option.BACK] as Array[PauseMenu.Option])
	assert_eq(_menu.get_lines()[0], "Pantalla")
	assert_eq(_menu.option_text(PauseMenu.Option.WINDOW_MODE), "Modo: Ventana")
	assert_eq(_menu.option_text(PauseMenu.Option.WINDOW_SIZE), "Tamaño de ventana: 1280x720")
	assert_true(_menu.get_lines().has("Píxeles a x1, sin bordes."), "Escala entera en el detalle")
	_press(&"ui_right")
	assert_true(GameSettings.is_fullscreen(), "Pantalla completa")
	assert_eq(_menu.option_text(PauseMenu.Option.WINDOW_MODE), "Modo: Pantalla completa")
	_press(&"ui_left")
	assert_false(GameSettings.is_fullscreen())
	_menu.select(PauseMenu.Option.WINDOW_SIZE)
	_press(&"ui_right")
	assert_eq(GameSettings.get_window_size(), Vector2i(1600, 900), "Siguiente preset")
	assert_eq(_menu.option_text(PauseMenu.Option.WINDOW_SIZE), "Tamaño de ventana: 1600x900")
	assert_true(_menu.get_lines().has("Píxeles a x1, con bordes negros."), "1600x900 deja bordes")
	_press(&"ui_left")
	_press(&"ui_left")
	var presets: Array[Vector2i] = GameSettings.available_presets(GameSettings.screen_size())
	assert_eq(GameSettings.get_window_size(), presets[presets.size() - 1], "Da la vuelta")
	_press(&"pause")
	assert_eq(_menu.get_page(), PauseMenu.Page.SETTINGS, "Esc en Pantalla vuelve a Ajustes")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.DISPLAY)
	_press(&"pause")
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN)
	_press(&"pause")
	assert_false(_menu.is_open())
	GameSettings.use_path(GameSettings.settings_path(), true)
