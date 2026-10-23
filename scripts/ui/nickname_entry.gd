## Entrada del apodo (docs/propuesta-asistentes-y-vidas.md §2.1 y §9, paso 5 de
## §10; datos y aspecto en data/nickname_entry.json, ver sus _notes).
## Componente reutilizable (encuentro con Eco del 1-1, menu «Apodo» de Notas):
## se anade al arbol, pausa el juego y emite nickname_chosen con el apodo
## elegido y closed al cerrarse (y se libera si free_on_close).
## - Teclado: se escribe directamente (letras, numeros y espacio que tenga la
##   fuente; maximo max_length), Retroceso borra, Intro elige la opcion marcada,
##   Esc deja el actual, izquierda/derecha cambian de opcion. La primera tecla
##   sustituye el apodo mostrado.
## - Mando minimo: ui_accept elige la opcion marcada, ui_cancel deja el actual.
##   Sin teclado el apodo no cambia (la rejilla de letras queda para el port a
##   movil).
## - Aceptar: GameState.set_nickname (limpia el texto; si cambia marca «sin
##   guardar»); vacio = dejar el actual.
## - La pausa se libera siempre: al cerrar y al salir del arbol.
class_name NicknameEntry
extends CanvasLayer

enum Option { ACCEPT, KEEP }

const DATA_PATH: String = "res://data/nickname_entry.json"

## Se eligio el apodo (`nickname`: el que queda en GameState).
signal nickname_chosen(nickname: String)
## La entrada se cerro (tras nickname_chosen).
signal closed

## Liberar el nodo al cerrarse.
@export var free_on_close: bool = true

var _data: Dictionary = {}
var _text: String = ""
var _initial: String = ""
var _pristine: bool = true
var _selected: Option = Option.ACCEPT
var _open: bool = false
var _owns_pause: bool = false
var _time: float = 0.0
var _font: Font
var _shader: Shader
var _key_color: Color
var _frame: Control
var _backdrop: ColorRect
var _panel: NinePatchRect
var _icon: TextureRect
var _title: Label
var _field_border: ColorRect
var _field_fill: ColorRect
var _field: Label
var _cursor: ColorRect
var _counter: Label
var _options: Array[Label] = []
## Pie de teclas (MenuHints, grupo nickname de data/menu_hints.json; acepta con ui_accept).
var _hints: MenuHints


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = load_data()
	layer = int(_data.get("layer", 30))
	_initial = GameState.get_nickname()
	_text = _initial
	_build()
	get_viewport().size_changed.connect(_layout)
	_open = true
	_hold_pause()
	_refresh()
	_hints.notify_opened("NicknameEntry")


func _exit_tree() -> void:
	_release_pause()


func _process(delta: float) -> void:
	_time += delta
	if _open:
		_refresh_field()


func _input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if handle_event(event):
		get_viewport().set_input_as_handled()


# --- API ---

## Procesa una entrada (teclado o acciones). Verdadero si la uso.
func handle_event(event: InputEvent) -> bool:
	if not _open:
		return false
	var key := event as InputEventKey
	if key != null:
		if not key.pressed:
			return true
		match key.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				activate_selected()
			KEY_ESCAPE:
				keep_current()
			KEY_BACKSPACE:
				erase_char()
			KEY_LEFT, KEY_UP:
				select(Option.ACCEPT)
			KEY_RIGHT, KEY_DOWN:
				select(Option.KEEP)
			_:
				if key.unicode > 0:
					type_char(char(key.unicode))
		# Todo el teclado es de la entrada (A/D, Espacio no son acciones aqui).
		return true
	if _matches(event, "accept_actions"):
		activate_selected()
	elif _matches(event, "cancel_actions"):
		keep_current()
	elif _matches(event, "left_actions"):
		select(Option.ACCEPT)
	elif _matches(event, "right_actions"):
		select(Option.KEEP)
	else:
		return false
	return true


## Escribe `ch` (si es valido y cabe). La primera escritura sustituye el texto
## mostrado. Verdadero si lo anadio.
func type_char(ch: String) -> bool:
	if not is_allowed_char(ch):
		return false
	if _pristine:
		_text = ""
		_pristine = false
	if _text.length() >= max_length():
		return false
	if ch == " " and (_text.is_empty() or _text.ends_with(" ")):
		return false
	_text += ch
	_refresh()
	return true


## Escribe cada caracter de `text` (pruebas y herramientas).
func type_text(text: String) -> void:
	for i: int in text.length():
		type_char(text[i])


## Borra el ultimo caracter (en el texto inicial, solo deja de estar resaltado).
func erase_char() -> void:
	_pristine = false
	if not _text.is_empty():
		_text = _text.substr(0, _text.length() - 1)
	_refresh()


func select(option: Option) -> void:
	_selected = option
	_refresh()


func activate_selected() -> void:
	if _selected == Option.KEEP:
		keep_current()
	else:
		accept()


## Acepta lo escrito: lo guarda en GameState (si cambia, «sin guardar»); vacio
## deja el actual. Cierra.
func accept() -> void:
	if not _open:
		return
	GameState.set_nickname(_text)
	_finish()


## Deja el apodo actual sin cambiarlo y cierra.
func keep_current() -> void:
	if not _open:
		return
	_finish()


func is_open() -> bool:
	return _open


## Texto del campo (sin el cursor).
func get_text() -> String:
	return _text


## El campo aun muestra el apodo inicial resaltado (la primera tecla lo sustituye).
func is_pristine() -> bool:
	return _pristine


func get_selected() -> Option:
	return _selected


func max_length() -> int:
	return clampi(int(_data.get("max_length", GameState.NICKNAME_MAX_LENGTH)), 1, GameState.NICKNAME_MAX_LENGTH)


## La entrada tiene el arbol en pausa.
func is_pausing_game() -> bool:
	return _owns_pause


## Caracter que se puede escribir: letra o numero (GameState.is_nickname_char)
## o espacio, y que la fuente de textos tenga.
func is_allowed_char(ch: String) -> bool:
	if ch.length() != 1:
		return false
	if ch != " " and not GameState.is_nickname_char(ch):
		return false
	return _font == null or _font.has_char(ch.unicode_at(0))


## Lineas visibles (titulo, campo, opciones, ayuda), para pruebas y capturas.
func get_lines() -> PackedStringArray:
	var out: PackedStringArray = [_title.text, _text, _counter.text]
	for label: Label in _options:
		out.append(label.text)
	out.append(_hints.get_text())
	return out


# --- Interno ---

func _finish() -> void:
	_open = false
	_release_pause()
	nickname_chosen.emit(GameState.get_nickname())
	closed.emit()
	if free_on_close:
		queue_free()


func _hold_pause() -> void:
	if _owns_pause or not is_inside_tree() or get_tree().paused:
		return
	get_tree().paused = true
	_owns_pause = true


func _release_pause() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	if is_inside_tree():
		get_tree().paused = false


func _matches(event: InputEvent, key: String) -> bool:
	for action: Variant in _data.get(key, []):
		var action_name := StringName(String(action))
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name, false, true):
			return true
	return false


func _txt(key: String) -> String:
	return String(_data.get("texts", {}).get(key, ""))


func _color(key: String) -> Color:
	return Color.html(String(_data.get("colors", {}).get(key, "#f2f4f8")))


func _refresh() -> void:
	if _title == null:
		return
	_title.text = _txt("title")
	var labels: Array[String] = [_txt("accept"), GameState.apply_nickname(_txt("keep_template"), _initial)]
	for i: int in _options.size():
		var on: bool = i == int(_selected)
		_options[i].text = _txt("selected_prefix" if on else "unselected_prefix") + labels[i]
		_set_color(_options[i], _color("option_selected" if on else "option"))
	_counter.text = _txt("counter") % [_text.length(), max_length()]
	_refresh_field()
	_layout()


func _refresh_field() -> void:
	if _field == null:
		return
	var blink: bool = fmod(_time * float(_data.get("cursor_blink_hz", 2.0)), 1.0) < 0.5
	_field.text = _text
	_set_color(_field, _color("field_pristine" if _pristine else "field"))
	_cursor.visible = blink and not _pristine and _text.length() < max_length()
	_cursor.position = Vector2(_field.position.x + _width_of(_text) + 1.0, _field.position.y)


func _new_label(node_name: String, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", int(_data.get("font_size", 12)))
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_constant_override(&"line_spacing", 0)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"key_color", _key_color)
	material.set_shader_parameter(&"target_color", color)
	label.material = material
	_panel.add_child(label)
	return label


func _set_color(label: Label, color: Color) -> void:
	(label.material as ShaderMaterial).set_shader_parameter(&"target_color", color)


func _build() -> void:
	_font = load(String(_data["font"])) as Font
	_shader = load(String(_data["key_swap_shader"])) as Shader
	_key_color = _color("key")
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.scale = Vector2.ONE * maxi(1, int(_data.get("pixel_scale", 2)))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(_color("backdrop"), float(_data.get("backdrop_alpha", 0.6)))
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_child(_backdrop)
	_panel = NinePatchRect.new()
	_panel.name = "Panel"
	_panel.texture = load(String(_data["panel"])) as Texture2D
	var margin: int = int(_data.get("panel_margin_px", 3))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, margin)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_panel)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.texture = load(String(_data["icon"])) as Texture2D
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_icon)
	_title = _new_label("Title", _color("title"), HORIZONTAL_ALIGNMENT_LEFT)
	_field_border = ColorRect.new()
	_field_border.name = "FieldBorder"
	_field_border.color = _color("field_border")
	_field_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_field_border)
	_field_fill = ColorRect.new()
	_field_fill.name = "FieldFill"
	_field_fill.color = _color("field_fill")
	_field_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_border.add_child(_field_fill)
	_field = _new_label("Field", _color("field"), HORIZONTAL_ALIGNMENT_LEFT)
	_cursor = ColorRect.new()
	_cursor.name = "Cursor"
	_cursor.color = _color("cursor")
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cursor)
	_counter = _new_label("Counter", _color("counter"), HORIZONTAL_ALIGNMENT_RIGHT)
	for i: int in 2:
		_options.append(_new_label("Option_%d" % i, _color("option"), HORIZONTAL_ALIGNMENT_LEFT))
	_hints = MenuHints.new()
	var hint_colors: Dictionary = {}
	for key: String in (_data.get("hint_colors", {}) as Dictionary):
		hint_colors[key] = Color.html(String(_data["hint_colors"][key]))
	_hints.setup(_font, int(_data.get("font_size", 12)), _shader, _key_color, hint_colors)
	_hints.show_set("nickname")
	_panel.add_child(_hints)
	_hints.row_changed.connect(_layout)


func _width_of(text: String) -> float:
	return ceilf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_data.get("font_size", 12))).x)


func _layout() -> void:
	if _frame == null or _font == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale.x
	_frame.size = screen
	_backdrop.size = screen
	var line_h: float = ceilf(_font.get_height(int(_data.get("font_size", 12))))
	var pad: float = float(_data.get("padding_px", 10))
	var gap: float = float(_data.get("line_gap_px", 6))
	var fpad: float = float(_data.get("field_padding_px", 4))
	var icon_size: Vector2 = _icon.texture.get_size() if _icon.texture != null else Vector2.ZERO
	var cursor_w: float = float(_data.get("cursor_width_px", 1))
	var widest_name: float = _width_of("W".repeat(max_length())) + cursor_w + 2.0
	var width: float = float(_data.get("panel_width_px", 240))
	width = maxf(width, icon_size.x + gap + _width_of(_title.text) + pad * 2.0)
	width = maxf(width, _hints.get_row_width() + pad * 2.0)
	width = maxf(width, widest_name + fpad * 2.0 + _width_of(_counter.text) + gap + pad * 2.0)
	var options_w: float = 0.0
	for label: Label in _options:
		options_w += _width_of(label.text) + gap * 2.0
	width = maxf(width, options_w + pad * 2.0)
	var y: float = pad
	_icon.position = Vector2(pad, y)
	_icon.size = icon_size
	_title.position = Vector2(pad + icon_size.x + gap, y + floorf((icon_size.y - line_h) * 0.5))
	_title.size = Vector2(width - pad * 2.0 - icon_size.x - gap, line_h)
	y += maxf(icon_size.y, line_h) + gap
	var field_w: float = widest_name + fpad * 2.0
	var field_h: float = line_h + fpad * 2.0
	var field_x: float = floorf((width - field_w) * 0.5)
	_field_border.position = Vector2(field_x, y)
	_field_border.size = Vector2(field_w, field_h)
	_field_fill.position = Vector2.ONE
	_field_fill.size = Vector2(field_w - 2.0, field_h - 2.0)
	_field.position = Vector2(field_x + fpad, y + fpad)
	_field.size = Vector2(field_w - fpad * 2.0, line_h)
	_cursor.size = Vector2(cursor_w, line_h)
	_counter.position = Vector2(field_x + field_w + gap, y + fpad)
	_counter.size = Vector2(width - pad - (field_x + field_w + gap), line_h)
	y += field_h + gap
	var x: float = floorf((width - options_w) * 0.5) + gap
	for label: Label in _options:
		var w: float = _width_of(label.text)
		label.position = Vector2(x, y)
		label.size = Vector2(w, line_h)
		x += w + gap * 2.0
	y += line_h + gap
	_hints.position = Vector2(floorf((width - _hints.get_row_width()) * 0.5), y)
	y += _hints.get_row_height() + pad
	_panel.size = Vector2(width, y)
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(maxf(screen.y - y, 0.0) * 0.5))
	_refresh_field()
