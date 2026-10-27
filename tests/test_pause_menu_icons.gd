# Iconos del menu de pausa (2026-10-27, peticion del usuario: «iconicemos el
# menu de ESC»): cada opcion lleva un icono de 12x12 px de arte del set menu_*
# del hub (option_icons de data/pause_menu.json), a la izquierda del texto y
# centrado en la fila; las filas de Controles (BINDING) no llevan. La
# navegacion y los textos no cambian.
extends GutTest

const MENU: String = "res://assets/sprites/hub/menu/menu_%s_00.png"


class HubExitStub:
	extends RefCounted
	func can_exit_to_hub() -> bool:
		return true
	func request_exit_to_hub() -> bool:
		return true


var _menu: PauseMenu


func before_each() -> void:
	GameSettings.reset_defaults()
	_menu = PauseMenu.new()
	add_child(_menu)


func after_each() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null
	get_tree().paused = false
	GameSettings.reset_defaults()


func _assert_icons(expected: Array[String]) -> void:
	assert_eq(_menu.get_options().size(), expected.size())
	for i: int in expected.size():
		var tex: Texture2D = _menu.get_option_icon(i)
		if expected[i].is_empty():
			assert_null(tex, "Fila %d sin icono" % i)
			assert_false(_menu.get_option_icon_rect(i).visible)
			continue
		assert_not_null(tex, "Fila %d con icono" % i)
		assert_eq(tex.resource_path, MENU % expected[i])
		assert_eq(tex.get_size(), Vector2(12.0, 12.0), "12x12 px de arte")
		var rect: TextureRect = _menu.get_option_icon_rect(i)
		var label: Label = _menu.get_option_label(i)
		assert_true(rect.visible)
		assert_lt(rect.position.x + rect.size.x, label.position.x + 0.5, "Icono a la izquierda del texto")
		assert_almost_eq(rect.position.y + rect.size.y * 0.5, label.position.y + label.size.y * 0.5, 1.0,
			"Centrado en la fila")
		var panel: Rect2 = Rect2(Vector2.ZERO, (label.get_parent() as Control).size)
		assert_true(panel.has_point(rect.position), "Dentro del panel")


func test_main_page_has_an_icon_per_option() -> void:
	_menu.hub_exit = HubExitStub.new()
	assert_true(_menu.request_open())
	_assert_icons(["pause_resume", "pause_settings", "pause_exit_hub", "pause_quit"] as Array[String])
	var x: float = _menu.get_option_icon_rect(0).position.x
	for i: int in _menu.get_options().size():
		assert_eq(_menu.get_option_icon_rect(i).position.x, x, "Columna de iconos alineada")
	assert_eq(_menu.get_selected_option(), PauseMenu.Option.RESUME, "La navegacion no cambia")
	_menu.close()


func test_settings_display_sound_and_confirm_pages() -> void:
	_menu.hub_exit = HubExitStub.new()
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	_assert_icons(["pause_eco_help", "pause_low_sync", "pause_debug_outline", "pause_rhythm", "pause_sound",
		"pause_display", "pause_controls", "back"] as Array[String])
	_menu.activate(PauseMenu.Option.DISPLAY)
	_assert_icons(["pause_window_mode", "pause_window_size", "pause_scale_mode", "back"] as Array[String])
	_menu.go_back()
	_menu.activate(PauseMenu.Option.SOUND)
	for i: int in _menu.get_options().size() - 1:
		assert_eq(_menu.get_option_icon(i).resource_path, MENU % "pause_sound", "Volumen: altavoz")
	_menu.go_back()
	_menu.go_back()
	_menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFIRM_HUB)
	_assert_icons(["pause_exit_hub", "back"] as Array[String])
	_menu.close()


func test_controls_rows_have_no_icon_but_reset_and_back_do() -> void:
	_menu.request_open()
	_menu.activate(PauseMenu.Option.SETTINGS)
	_menu.activate(PauseMenu.Option.CONTROLS)
	var options: Array[PauseMenu.Option] = _menu.get_options()
	for i: int in options.size():
		if options[i] == PauseMenu.Option.BINDING:
			assert_null(_menu.get_option_icon(i), "Fila de accion sin icono")
	var n: int = options.size()
	assert_eq(_menu.get_option_icon(n - 2).resource_path, MENU % "pause_reset")
	assert_eq(_menu.get_option_icon(n - 1).resource_path, MENU % "back")
	_menu.close()
