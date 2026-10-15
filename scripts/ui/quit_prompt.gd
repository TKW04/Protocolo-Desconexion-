## Aviso PROVISIONAL de cambios sin guardar al cerrar la ventana (lo abre
## QuitGuard). Velo sobre el juego y el panel del cuadro de Eco con el titulo,
## las opciones (la elegida con prefijo y color) y la ayuda. Funciona con el
## arbol en pausa (PROCESS_MODE_ALWAYS). Textos, colores y acciones en
## data/quit_prompt.json; todo por el Input Map.
class_name QuitPrompt
extends CanvasLayer

const DATA_PATH: String = "res://data/quit_prompt.json"

## El jugador acepta la opcion `choice` (QuitGuard.Choice).
signal chosen(choice: QuitGuard.Choice)

var _data: Dictionary = {}
var _decision: QuitGuard.Decision = QuitGuard.Decision.ASK_WITHOUT_SAVE
var _choices: Array[QuitGuard.Choice] = []
var _selected: int = 0
var _font: Font
var _shader: Shader
var _key_color: Color
var _frame: Control
var _backdrop: ColorRect
var _panel: NinePatchRect
var _title: Label
var _help: Label
var _message: Label
var _option_labels: Array[Label] = []


## Prepara el aviso antes de añadirlo al arbol.
func setup(decision: QuitGuard.Decision, choices: Array[QuitGuard.Choice]) -> void:
	_decision = decision
	_choices = choices.duplicate()
	_selected = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = load_data()
	layer = int(_data.get("layer", 50))
	_build()
	_refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if _matches(event, "up_actions"):
		move_selection(-1)
	elif _matches(event, "down_actions"):
		move_selection(1)
	elif _matches(event, "confirm_actions"):
		confirm()
	elif _matches(event, "cancel_actions"):
		chosen.emit(QuitGuard.Choice.BACK)
	else:
		return
	get_viewport().set_input_as_handled()


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


func get_decision() -> QuitGuard.Decision:
	return _decision


func get_choices() -> Array[QuitGuard.Choice]:
	return _choices


func get_selected_choice() -> QuitGuard.Choice:
	return _choices[_selected]


func move_selection(step: int) -> void:
	if _choices.is_empty():
		return
	_selected = posmod(_selected + step, _choices.size())
	_refresh()


## Acepta la opcion elegida.
func confirm() -> void:
	if not _choices.is_empty():
		chosen.emit(_choices[_selected])


## Muestra que no se pudo guardar (el aviso sigue abierto).
func show_save_failed() -> void:
	_message.text = _text("save_failed")
	_layout()


## Lineas visibles (titulo, opciones, mensaje y ayuda), para pruebas.
func get_lines() -> PackedStringArray:
	var out: PackedStringArray = [_title.text]
	for label: Label in _option_labels:
		out.append(label.text)
	out.append(_message.text)
	out.append(_help.text)
	return out


static func choice_text_key(choice: QuitGuard.Choice, decision: QuitGuard.Decision) -> String:
	match choice:
		QuitGuard.Choice.SAVE_AND_QUIT:
			return "save_and_quit"
		QuitGuard.Choice.QUIT:
			return "quit_without_saving" if decision == QuitGuard.Decision.ASK_WITH_SAVE else "quit"
	return "back"


# --- Interno ---

func _matches(event: InputEvent, key: String) -> bool:
	for action: Variant in _data.get(key, []):
		var name := StringName(String(action))
		if InputMap.has_action(name) and event.is_action_pressed(name, false, true):
			return true
	return false


func _text(key: String) -> String:
	return String(_data.get("texts", {}).get(key, ""))


func _color(key: String) -> Color:
	return Color.html(String(_data.get("colors", {}).get(key, "#f2f4f8")))


func _refresh() -> void:
	var title_key: String = "title_with_save" if _decision == QuitGuard.Decision.ASK_WITH_SAVE else "title_without_save"
	_title.text = _text(title_key)
	for i: int in _option_labels.size():
		var prefix: String = _text("selected_prefix" if i == _selected else "unselected_prefix")
		_option_labels[i].text = prefix + _text(choice_text_key(_choices[i], _decision))
		_set_color(_option_labels[i], _color("option_selected" if i == _selected else "option"))
	_layout()


func _new_label(node_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", int(_data.get("font_size", 12)))
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_backdrop.color = Color(_color("backdrop"), float(_data.get("backdrop_alpha", 0.75)))
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
	_title = _new_label("Title", _color("title"))
	for i: int in _choices.size():
		_option_labels.append(_new_label("Option_%d" % i, _color("option")))
	_message = _new_label("Message", _color("message"))
	_help = _new_label("Help", _color("help"))


func _ordered_labels() -> Array[Label]:
	var out: Array[Label] = [_title]
	out.append_array(_option_labels)
	out.append(_message)
	out.append(_help)
	return out


func _layout() -> void:
	if _frame == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale.x
	_frame.size = screen
	_backdrop.size = screen
	var font_size: int = int(_data.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(font_size))
	var pad: float = float(_data.get("padding_px", 12))
	var gap: float = float(_data.get("line_gap_px", 6))
	var width: float = float(_data.get("panel_width_px", 240))
	for label: Label in _ordered_labels():
		width = maxf(width, ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + pad * 2.0)
	var y: float = pad
	for label: Label in _ordered_labels():
		label.visible = not label.text.is_empty()
		if not label.visible:
			continue
		label.position = Vector2(pad, y)
		label.size = Vector2(width - pad * 2.0, line_h)
		y += line_h + gap
		if label == _title or label == _option_labels.back():
			y += gap
	var height: float = y - gap + pad
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(maxf(screen.y - height, 0.0) * 0.5))
