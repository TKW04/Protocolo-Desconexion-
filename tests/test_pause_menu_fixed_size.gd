# Menu de pausa de tamano fijo (2026-10-27, peticion del usuario: «la pantalla
# del menu de ESC haz que sea del mismo tamano siempre, que no este cambiando
# segun te mueves por el menu»): el panel tiene el mismo rect en todas las
# paginas y al mover la seleccion; el texto de las opciones no se mueve al
# elegirlas (ancho reservado al prefijo); detalle y ayuda en filas fijas; nada
# se sale del panel ni de la pantalla.
# Compacto (2026-10-27, peticion del usuario: «hazlo mas pequeno, tiene mucho
# espacio en blanco»): una ventana de panel_option_rows filas; Controles se
# desplaza con la seleccion (la elegida siempre visible, todas alcanzables,
# ▲ / ▼ si hay filas fuera) y el ancho lo fija el texto mas largo.
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
				if not opt.visible:
					continue  # Fuera de la ventana (Controles se desplaza)
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


func test_panel_is_compact() -> void:
	var data: Dictionary = PauseMenu.load_data()
	assert_eq(_menu.visible_option_rows(), int(data["panel_option_rows"]))
	assert_lte(_menu.visible_option_rows(), 8, "Ventana de 8 filas como mucho")
	var size: Vector2 = _menu.fixed_panel_size()
	assert_lte(size.y, 240.0, "Alto compacto (px de arte): %s" % size)
	assert_lte(size.x, 320.0, "Ancho compacto (px de arte): %s" % size)
	# Ajustes (8) y Sonido (7) caben enteras: no se desplazan.
	_menu.activate(PauseMenu.Option.SETTINGS)
	assert_lte(_menu.get_options().size(), _menu.visible_option_rows())
	assert_eq(_menu.scroll_arrows_shown(), Vector2i.ZERO, "Ajustes sin flechas")
	_menu.activate(PauseMenu.Option.SOUND)
	assert_lte(_menu.get_options().size(), _menu.visible_option_rows())
	assert_eq(_menu.scroll_arrows_shown(), Vector2i.ZERO, "Sonido sin flechas")


## Los textos de titulo, detalle, avisos y ayuda (con valores largos reales)
## caben en el ancho del panel.
func test_longest_texts_fit_the_width() -> void:
	var data: Dictionary = PauseMenu.load_data()
	var font: Font = load(String(data["font"])) as Font
	var room: float = float(data["panel_width_px"]) - 2.0 * float(data["padding_px"])
	var values: Dictionary = {"{w}": "1920", "{h}": "1080", "{scale}": "3", "{input}": "stick a la izquierda",
		"{action}": "Mover a la izquierda"}
	var keyed := RegEx.create_from_string("detail|^help_|^title_|reserved|blocked|cancelled|_done")
	for key: String in data["texts"]:
		if keyed.search(key) == null:
			continue
		var text: String = String(data["texts"][key])
		for tag: String in values:
			text = text.replace(tag, String(values[tag]))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
		assert_lte(w, room, "«%s» cabe en el ancho (%s px)" % [text, w])


## Controles: cada fila se alcanza con W/S, la elegida siempre se ve, nunca hay
## mas filas que la ventana, las filas no salen de su zona y las flechas dicen
## si hay filas fuera.
func test_controls_scroll_follows_the_selection() -> void:
	_menu.activate(PauseMenu.Option.SETTINGS)
	_menu.activate(PauseMenu.Option.CONTROLS)
	var n: int = _menu.get_options().size()
	var rows: int = _menu.visible_option_rows()
	assert_gt(n, rows, "Controles tiene mas filas que la ventana")
	assert_eq(_menu.scroll_arrows_shown(), Vector2i(0, 1), "Al inicio: solo ▼")
	var top: float = _menu.get_option_label(0).position.y
	var seen: Dictionary = {}
	for step: int in n * 2 + 1:
		var sel: int = _menu.get_options().find(_menu.get_selected_option()) if step == 0 else -1
		var shown: int = 0
		for i: int in n:
			var label: Label = _menu.get_option_label(i)
			assert_eq(label.visible, _menu.is_option_shown(i), "Fila %d visible solo en la ventana" % i)
			if label.visible:
				shown += 1
				seen[i] = true
				assert_gte(label.position.y, top - 0.5, "Fila %d no sube por encima de la ventana" % i)
				assert_lte(label.position.y, top + (rows - 1) * (label.size.y + 4.0) + 0.5,
					"Fila %d no baja de la ventana" % i)
		assert_eq(shown, rows, "Siempre %d filas visibles" % rows)
		var scroll: int = _menu.get_scroll()
		assert_eq(_menu.scroll_arrows_shown(), Vector2i(int(scroll > 0), int(scroll + rows < n)), "Flechas")
		if sel >= 0:
			assert_true(_menu.is_option_shown(sel))
		_menu.move_selection(1)
		# La elegida (tras moverse) siempre se ve.
		var index: int = (step + 1) % n
		assert_true(_menu.is_option_shown(index), "La fila elegida %d se ve" % index)
		assert_true(_menu.get_option_label(index).text.begins_with("–"), "Y es la marcada")
	assert_eq(seen.size(), n, "Todas las filas se alcanzan con el desplazamiento")
	# Al final de la lista: ▲ y Volver en la ultima fila visible; W desde el
	# principio salta al final y S desde el final vuelve al principio.
	_menu.select(PauseMenu.Option.BACK)
	assert_eq(_menu.get_scroll(), n - rows)
	assert_eq(_menu.scroll_arrows_shown(), Vector2i(1, 0), "Al final: solo ▲")
	_menu.move_selection(1)
	assert_eq(_menu.get_scroll(), 0, "Vuelta al principio")
	_menu.move_selection(-1)
	assert_eq(_menu.get_scroll(), n - rows, "Arriba desde el principio: al final")
	# Volver de un conflicto a una fila profunda la deja a la vista.
	var actions: Array[StringName] = ControlBindings.actions()
	_menu.select_action(actions[actions.size() - 1])
	assert_true(_menu.is_option_shown(actions.size() - 1))
	assert_eq(_menu.get_panel_rect(), _rect, "El panel no cambia al desplazarse")
