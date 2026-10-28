# Menu de la tienda de Calc (2026-10-27, peticion del usuario; mismo idioma
# que el menu de ESC, tests/test_pause_menu_fixed_size.gd):
# - tamano fijo: el panel no cambia al moverse, con el detalle de 2 o 5
#   lineas, con o sin mensaje, ni con el numero de pistas; chip, nombre y
#   recuadros no se mueven al elegir; todos los textos caben en el ancho fijo;
#   con mas pistas que filas la ventana sigue a la eleccion con ▲ / ▼;
# - resalte: barra con relleno, contorno y marcador en la fila elegida;
# - sonido: ui_feedback move / confirm / back (ui_move... en data/audio.json);
# - confirmacion «¿Comprar …?» de tamano fijo antes de comprar: Sí compra,
#   No y salto vuelven sin gastar; sin compra posible no sale.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_calc_menu.json"

var _hub: HubRoom
var _calc: CalcStation
var _panel: CalcPanel
var _isak: Isak
var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool
var _feedback: Array[StringName] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_isak = _hub.get_isak()
	_isak.input = PlayerInput.new()
	_calc = _hub.get_calc()
	_panel = _calc.get_calc_panel()
	_feedback.clear()
	_panel.ui_feedback.connect(func(kind: StringName) -> void: _feedback.append(kind))


func after_each() -> void:
	if is_instance_valid(_hub):
		_hub.free()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, false)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _press(name: StringName) -> void:
	_panel._unhandled_input(_action(name))


func _open() -> void:
	assert_true(_calc.open(_isak), "Se abre")
	_panel.skip_input_delay()


func _obtain(ability: StringName) -> void:
	GameState.obtained_abilities[ability] = true
	GameState.set_ability_unlocked(ability, true)


func _row_positions() -> Array:
	var out: Array = []
	for i: int in _panel.get_track_ids().size():
		var row: Dictionary = _panel.get_row_nodes(_panel.get_track_ids()[i])
		var label: Label = _panel.get_option_label(i)
		var name_x: float = label.position.x + ceilf(label.get_theme_font(&"font").get_string_size(
			label.text.substr(0, label.text.length() - _panel.track_name(_panel.get_track_ids()[i]).length()),
			HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x)
		out.append([(row["chip"] as TextureRect).position, (row["boxes"][0] as TextureRect).position, name_x])
	return out


func _text_w(text: String) -> float:
	var label: Label = _panel.get_option_label(0)
	return ceilf(label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size(&"font_size")).x)


# --- Tamano fijo ---

func test_panel_size_is_fixed_while_moving_and_with_messages() -> void:
	_obtain(GameState.ABILITY_LASER)
	GameState.attention_points = 30
	_open()
	var rect: Rect2 = _panel.get_panel_rect()
	gut.p("Panel fijo: %s px de arte, %s en pantalla; confirmacion %s" % [_panel.fixed_panel_size(), rect,
		_panel.fixed_confirm_size()])
	assert_eq(rect.size, _panel.fixed_panel_size() * 2.0, "Mide el tamano fijo (x2 en pantalla)")
	var rows: Array = _row_positions()
	for step: int in 6:
		_press(&"move_down")
		assert_eq(_panel.get_panel_rect(), rect, "No cambia al moverse (paso %d)" % step)
		assert_eq(_row_positions(), rows, "Chip, nombre y recuadros quietos al elegir (paso %d)" % step)
	_panel.select_option(&"debug")
	assert_eq(_panel.get_detail_lines().size(), 2, "La pista «?» solo tiene 2 lineas")
	assert_eq(_panel.get_panel_rect(), rect, "Mismo tamano con 2 lineas de detalle")
	_press(&"pulse")
	assert_false(_panel.get_message().is_empty(), "Mensaje «Aún no tienes…»")
	assert_eq(_panel.get_panel_rect(), rect, "Mismo tamano con mensaje")
	assert_lte(rect.end.y, 720.0, "Cabe en pantalla")
	assert_gte(rect.position.x, 0.0)
	assert_lte(rect.end.x, 1280.0)


func test_every_text_fits_the_fixed_width() -> void:
	_obtain(GameState.ABILITY_LASER)
	_obtain(GameState.ABILITY_DEBUG)
	GameState.attention_points = 999
	GameState.power_banks = 9
	_open()
	var inner: float = _panel.fixed_panel_size().x - 2.0 * 10.0
	var texts: PackedStringArray = [_panel.get_title(), _panel.get_help()]
	texts.append_array(_panel.get_lines())
	for lap: int in [GameState.LAP_EASY, GameState.LAP_NORMAL, GameState.LAP_HARD]:
		GameState.lap = lap
		for owned: int in range(1, 6):
			for track: StringName in _panel.get_track_ids():
				GameState.upgrade_levels[track] = owned
				texts.append_array(_panel.detail_lines(track).map(func(l: Dictionary) -> String: return l["text"]))
	for text: String in texts:
		assert_lte(_text_w(text), inner, "Cabe en el ancho fijo: «%s»" % text)
	# Mensajes (compra y que falta).
	var calc_texts: Dictionary = HubData.section("calc").get("texts", {})
	for key: String in calc_texts:
		if String(key).begins_with("message_"):
			assert_lte(_text_w(String(calc_texts[key]).replace("%d", "999").replace("%s", "Pulso aturdidor")),
				inner, "Mensaje %s cabe" % key)
	# La confirmacion de cada nivel cabe en su ancho fijo.
	var confirm_inner: float = _panel.fixed_confirm_size().x - 2.0 * 10.0
	for track: StringName in _panel.get_track_ids():
		for owned: int in range(1, 5):
			GameState.upgrade_levels[track] = owned
			for text: String in _panel.confirm_lines(track):
				assert_lte(_text_w(text), confirm_inner, "Confirmacion cabe: «%s»" % text)


func test_more_tracks_than_rows_scroll_with_arrows() -> void:
	_open()
	var rect: Rect2 = _panel.get_panel_rect()
	assert_eq(_panel.visible_rows(), 5, "Ventana de 5 filas: hoy caben todas")
	assert_eq(_panel.scroll_arrows_shown(), Vector2i(0, 0), "Sin flechas con todas a la vista")
	_panel.set_visible_rows(3)
	var small: Rect2 = _panel.get_panel_rect()
	assert_lt(small.size.y, rect.size.y, "Menos filas, panel mas bajo (la ventana fija el alto)")
	assert_eq(_panel.scroll_arrows_shown(), Vector2i(0, 1), "Arriba del todo: solo ▼")
	assert_true(_panel.is_option_shown(0) and not _panel.is_option_shown(3))
	for i: int in 3:
		_press(&"move_down")
		assert_true(_panel.is_option_shown(_panel.get_selected_index()), "La elegida siempre se ve")
		assert_eq(_panel.get_panel_rect(), small, "El tamano no cambia al desplazarse")
	assert_eq(_panel.get_scroll(), 1)
	assert_eq(_panel.scroll_arrows_shown(), Vector2i(1, 1), "Filas por encima y por debajo: ▲ y ▼")
	_press(&"move_down")
	assert_eq(_panel.get_scroll(), 2)
	assert_eq(_panel.scroll_arrows_shown(), Vector2i(1, 0), "Abajo del todo: solo ▲")
	var hidden: CalcPanel = _panel
	assert_false((hidden.get_row_nodes(&"pulso")["chip"] as TextureRect).visible, "Fila fuera: sin chip")
	_panel.set_visible_rows(5)
	assert_eq(_panel.get_panel_rect(), rect)


# --- Resalte ---

func test_selected_row_has_a_highlight_bar() -> void:
	_open()
	var bar: Rect2 = _panel.get_selection_bar_rect()
	assert_ne(bar, Rect2(), "Barra visible")
	var colors: Dictionary = _panel.get_selection_bar_colors()
	assert_eq(Color(colors["border"]).to_html(false), HubData.color("acento_cian").to_html(false), "Contorno cian")
	assert_gt(Color(colors["fill"]).a, 0.0, "Relleno visible")
	assert_lt(Color(colors["fill"]).a, 1.0, "Relleno translucido: el texto se lee")
	var chip: TextureRect = _panel.get_row_nodes(&"pulso")["chip"]
	assert_true(bar.encloses(Rect2(chip.position, chip.size)), "La barra abarca el chip de la elegida")
	var boxes: Array = _panel.get_row_nodes(&"pulso")["boxes"]
	var last: TextureRect = boxes[4]
	assert_true(bar.encloses(Rect2(last.position, last.size)), "…y sus recuadros")
	assert_eq(_panel.get_option_color(0), HubData.color("acento_cian"), "Texto de la elegida en cian")
	assert_ne(_panel.get_option_color(1), HubData.color("acento_cian"), "Las demas no")
	_press(&"move_down")
	var moved: Rect2 = _panel.get_selection_bar_rect()
	assert_gt(moved.position.y, bar.position.y, "La barra baja con la eleccion")
	assert_eq(moved.size, bar.size, "Mismo tamano de barra")
	assert_true(moved.encloses(Rect2(_panel.get_row_nodes(&"laser")["chip"].position, chip.size)))


# --- Sonido ---

func test_moving_emits_the_menu_move_sound() -> void:
	_open()
	_press(&"move_down")
	_press(&"move_up")
	assert_eq(_feedback, [&"move", &"move"] as Array[StringName], "Arriba y abajo suenan")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	var found: Dictionary = {}
	for entry: Variant in catalog.get("nodes", []):
		if entry is Dictionary and String(entry.get("class", "")) == "CalcPanel":
			found[String((entry["when"] as Dictionary)["0"])] = String(entry["sound"])
	assert_eq(found, {"move": "ui_move", "confirm": "ui_confirm", "back": "ui_back"},
		"Los sonidos de navegacion del menu de ESC")


# --- Confirmacion ---

func test_accept_opens_confirmation_and_yes_buys() -> void:
	GameState.attention_points = 30
	_open()
	var rect: Rect2 = _panel.get_panel_rect()
	_press(&"pulse")
	assert_true(_panel.is_confirm_open(), "Pulso abre «¿Comprar …?»")
	assert_eq(GameState.get_upgrade_level(&"pulso"), 1, "Aun no compra")
	assert_eq(GameState.attention_points, 30, "Aun no cobra")
	assert_false(GameState.has_unsaved_changes())
	assert_eq(_panel.get_confirm_texts(), PackedStringArray(["¿Comprar Pulso amplio?", "Pulso - Nivel 2 de 5",
		"Coste: 25 puntos", "– Sí, comprar", "  No"]))
	assert_eq(_panel.get_confirm_selected(), CalcPanel.OPTION_YES, "Sí elegido al abrir")
	assert_eq(_panel.get_confirm_help(), "G Aceptar · W/S Elegir · Espacio Volver", "Pie de teclas")
	assert_true(rect.encloses(_panel.get_confirm_rect()), "Cuadro pequeno sobre la tienda")
	assert_eq(_panel.get_confirm_rect().size, _panel.fixed_confirm_size() * 2.0, "Tamano fijo")
	assert_eq(_panel.get_panel_rect(), rect, "La tienda no cambia de tamano")
	var confirm_rect: Rect2 = _panel.get_confirm_rect()
	_press(&"move_down")
	assert_eq(_panel.get_confirm_selected(), CalcPanel.OPTION_NO, "W/S eligen en la confirmacion")
	assert_eq(_panel.get_selected_track(), &"pulso", "La lista no se mueve debajo")
	assert_eq(_panel.get_confirm_rect(), confirm_rect, "La confirmacion no cambia al moverse")
	_press(&"move_up")
	assert_eq(_panel.get_confirm_selected(), CalcPanel.OPTION_YES)
	_press(&"pulse")
	assert_false(_panel.is_confirm_open(), "Se cierra al aceptar")
	assert_eq(GameState.get_upgrade_level(&"pulso"), 2, "Sí compra el siguiente nivel")
	assert_eq(GameState.attention_points, 5)
	assert_eq(_panel.get_message(), "Nivel 2 instalado: Pulso amplio.")
	assert_true(GameState.has_unsaved_changes())
	assert_eq(_feedback, [&"confirm", &"move", &"move"] as Array[StringName])


func test_no_and_jump_cancel_without_spending() -> void:
	GameState.attention_points = 30
	_open()
	_press(&"pulse")
	_press(&"move_down")
	_press(&"pulse")
	assert_false(_panel.is_confirm_open(), "No cierra la confirmacion")
	assert_true(_panel.is_open(), "…y vuelve a la lista (la tienda sigue abierta)")
	assert_eq(GameState.get_upgrade_level(&"pulso"), 1, "No no compra")
	assert_eq(GameState.attention_points, 30, "No no cobra")
	assert_false(GameState.has_unsaved_changes(), "Nada sin guardar")
	_press(&"pulse")
	assert_true(_panel.is_confirm_open())
	_press(&"jump")
	assert_false(_panel.is_confirm_open(), "Salto vuelve a la lista")
	assert_true(_calc.is_panel_open(), "Salto en la confirmacion no cierra la tienda")
	assert_eq(GameState.attention_points, 30)
	assert_eq(_feedback.count(&"back"), 2, "Cancelar suena como volver")
	_press(&"jump")
	await wait_physics_frames(4)
	assert_false(_calc.is_panel_open(), "Salto en la lista cierra como antes")


func test_no_confirmation_when_the_purchase_is_not_possible() -> void:
	GameState.attention_points = 10
	_open()
	_press(&"pulse")
	assert_false(_panel.is_confirm_open(), "Sin puntos no pregunta")
	assert_eq(_panel.get_message(), "Faltan 15 puntos.", "Dice que falta, como antes")
	_panel.select_option(&"debug")
	_press(&"pulse")
	assert_false(_panel.is_confirm_open(), "Pista «?»: no pregunta")


func test_reopening_the_shop_closes_a_pending_confirmation() -> void:
	GameState.attention_points = 30
	_open()
	_press(&"pulse")
	assert_true(_panel.is_confirm_open())
	_calc.close(true)
	assert_false(_panel.is_confirm_open(), "Cerrar la tienda cierra la confirmacion")
	_open()
	assert_false(_panel.is_confirm_open(), "Se abre en la lista")
	assert_eq(GameState.attention_points, 30)


func test_power_bank_cost_shows_in_confirmation() -> void:
	GameState.lap = GameState.LAP_HARD
	GameState.attention_points = 30
	GameState.power_banks = 1
	GameState.upgrade_levels[&"energia"] = 4
	_open()
	_panel.select_option(&"energia")
	_press(&"pulse")
	assert_true(_panel.is_confirm_open())
	assert_eq(_panel.get_confirm_texts()[2], "Coste: 25 puntos + 1 power bank")
	_press(&"pulse")
	assert_eq(GameState.get_upgrade_level(&"energia"), 5)
	assert_eq(GameState.power_banks, 0)
