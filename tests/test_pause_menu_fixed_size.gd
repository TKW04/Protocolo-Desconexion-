# Menu de pausa de tamano fijo (2026-10-27, peticion del usuario: «la pantalla
# del menu de ESC haz que sea del mismo tamano siempre, que no este cambiando
# segun te mueves por el menu»): el panel tiene el mismo rect en todas las
# paginas y al mover la seleccion; el texto de las opciones no se mueve al
# elegirlas (ancho reservado al prefijo); detalle y ayuda en filas fijas; nada
# se sale del panel ni de la pantalla.
extends GutTest


class HubExitStub:
	extends RefCounted
	func can_exit_to_hub() -> bool:
		return true
	func request_exit_to_hub() -> bool:
		return true


var _menu: PauseMenu
var _rect: Rect2


func before_each() -> void:
	GameSettings.use_path(GameSettings.settings_path(), true)
	_menu = PauseMenu.new()
	_menu.hub_exit = HubExitStub.new()
	_menu.capture_arm_s = 0.0
	add_child(_menu)
	assert_true(_menu.request_open())
	_rect = _menu.get_panel_rect()


func after_each() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null
	get_tree().paused = false
	GameSettings.use_path(GameSettings.settings_path(), true)
	GameState.reset_progress()


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _font_size() -> int:
	return int(PauseMenu.load_data().get("font_size", 12))


## Mismo rect, texto que cabe y texto de cada opcion quieto al recorrer la seleccion.
func _check_page(label: String) -> void:
	assert_eq(_menu.get_panel_rect(), _rect, "%s: mismo rect del panel" % label)
	var panel: Control = _menu.get_option_label(0).get_parent() as Control if _menu.get_options().size() > 0 else null
	var starts: Dictionary = {}
	var n: int = _menu.get_options().size()
	var detail_y: float = -1.0
	for step: int in n + 1:
		assert_eq(_menu.get_panel_rect(), _rect, "%s: el panel no cambia al mover la seleccion" % label)
		for child: Node in _menu.find_children("*", "Label", true, false):
			var l: Label = child as Label
			if not l.visible:
				continue
			var font: Font = l.get_theme_font(&"font")
			var w: float = font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
			assert_lte(w, l.size.x + 0.5, "%s: «%s» cabe en su fila" % [label, l.text])
			assert_lte(l.position.x + l.size.x, (l.get_parent() as Control).size.x, "%s: dentro del panel" % label)
			assert_lte(l.position.y + l.size.y, (l.get_parent() as Control).size.y, "%s: dentro del panel" % label)
		if n > 0:
			for i: int in n:
				var opt: Label = _menu.get_option_label(i)
				var font: Font = opt.get_theme_font(&"font")
				var prefix: String = opt.text.substr(0, 2)
				var start: float = opt.position.x + font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1,
					_font_size()).x
				if starts.has(i):
					assert_almost_eq(start, float(starts[i]), 0.5, "%s: la opcion %d no se mueve" % [label, i])
				else:
					starts[i] = start
			if panel != null:
				var help: Label = panel.get_node("Help") as Label
				if detail_y < 0.0:
					detail_y = help.position.y
				assert_eq(help.position.y, detail_y, "%s: ayuda en fila fija" % label)
			_menu.move_selection(1)


func test_panel_rect_is_identical_on_every_page_and_selection() -> void:
	var size: Vector2 = _menu.fixed_panel_size() * 2.0
	assert_eq(_rect.size, size, "Tamano fijo")
	var screen: Vector2 = get_viewport().get_visible_rect().size
	assert_true(Rect2(Vector2.ZERO, screen).encloses(_rect), "Cabe en la pantalla")
	_check_page("Principal")
	_menu.activate(PauseMenu.Option.SETTINGS)
	_check_page("Ajustes")
	_menu.activate(PauseMenu.Option.SOUND)
	_check_page("Sonido")
	_menu.go_back()
	_menu.activate(PauseMenu.Option.DISPLAY)
	_check_page("Pantalla")
	_menu.go_back()
	_menu.activate(PauseMenu.Option.CONTROLS)
	assert_eq(_menu.get_page(), PauseMenu.Page.CONTROLS)
	_check_page("Controles")
	_menu.activate(PauseMenu.Option.RESET_CONTROLS)
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFIRM_RESET)
	_check_page("Restablecer")
	_menu.go_back()
	_menu.begin_capture(&"jump")
	assert_eq(_menu.get_page(), PauseMenu.Page.CAPTURE)
	_check_page("Captura")
	_menu.handle_capture(_key(KEY_G))
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFLICT, "G es del pulso")
	_check_page("Conflicto")
	_menu.go_back()
	_check_page("Controles con aviso")
	_menu.go_back()
	_menu.go_back()
	assert_eq(_menu.get_page(), PauseMenu.Page.MAIN)
	_menu.activate(PauseMenu.Option.EXIT_TO_HUB)
	assert_eq(_menu.get_page(), PauseMenu.Page.CONFIRM_HUB)
	_check_page("Salir al hub")


func test_toggling_a_setting_keeps_the_panel_and_options_still() -> void:
	_menu.activate(PauseMenu.Option.SETTINGS)
	var x: float = _menu.get_option_icon_rect(0).position.x
	_menu.activate(PauseMenu.Option.ECO_HELP)
	_menu.activate(PauseMenu.Option.DEBUG_OUTLINE)
	assert_eq(_menu.get_panel_rect(), _rect)
	assert_eq(_menu.get_option_icon_rect(0).position.x, x, "La columna de iconos no se mueve")
	_menu.activate(PauseMenu.Option.ECO_HELP)
	_menu.activate(PauseMenu.Option.DEBUG_OUTLINE)
