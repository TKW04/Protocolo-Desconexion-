## Panel de menu de una estacion del hub (docs/propuesta-hub-y-guardado.md §3):
## el NinePatch del cuadro de Eco y la fuente de textos, en pixeles de arte
## escalados x pixel_scale (como el HUD). Lineas de texto fijas, una lista de
## opciones y un mensaje. Valores en la seccion panel de data/hub.json; colores
## por rol de la paleta del hub (hub.gpl).
##
## Controles (solo acciones del Input Map, con el panel abierto y pasado
## input_delay_s de tiempo real): up_action / down_action eligen opcion,
## confirm_action (pulse) confirma y cancel_action (jump) vuelve. Por defecto
## confirmar emite option_chosen y volver emite close_requested; las
## subclases (NotasPanel, FolderPanel, CalcPanel) cambian _on_confirm y
## _on_cancel. Bajo las opciones pueden ir lineas de detalle (set_detail o
## set_detail_lines, cada una con su color; la tienda de Calc las usa para el
## siguiente nivel de la pista elegida) y cada opcion puede llevar su rol de
## color cuando no esta elegida ("role"). Las subclases pueden dar mas alto a
## las filas de opciones y reservar sitio a su izquierda y derecha para dibujar
## (_option_row_height, _option_inset_left/right; _after_layout coloca lo suyo).
## Al pie, la fila de teclas (MenuHints, 2026-10-23): «[G] Aceptar · W/S
## Elegir · Espacio Volver» con las teclas del Input Map; las subclases eligen
## el grupo de data/menu_hints.json con set_hints.
class_name HubPanel
extends CanvasLayer

## El jugador pide cerrar el panel (la estacion lo cierra y devuelve el control).
signal close_requested
## Se confirmo la opcion `id` (indice `index`).
signal option_chosen(index: int, id: StringName)

var _config: Dictionary = HubData.section("panel")
var _font: Font
var _shader: Shader
var _key_color: Color
var _frame: Control
var _panel: NinePatchRect
var _title: Label
var _line_labels: Array[Label] = []
var _option_labels: Array[Label] = []
var _detail_labels: Array[Label] = []
var _message: Label
var _hints: MenuHints
var _option_ids: Array[StringName] = []
var _option_texts: Array[String] = []
var _option_roles: Array[String] = []
var _selected: int = 0
var _open: bool = false
var _open_time: float = 0.0


func _ready() -> void:
	layer = int(_config.get("layer", 20))
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if _open:
		_open_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not _accepts_input():
		return
	if event.is_action_pressed(_action("up_action", "move_up")):
		move_selection(-1)
	elif event.is_action_pressed(_action("down_action", "move_down")):
		move_selection(1)
	elif event.is_action_pressed(_action("confirm_action", "pulse")):
		confirm()
	elif event.is_action_pressed(_action("cancel_action", "jump")):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


# --- API ---

func open() -> void:
	_open = true
	_open_time = 0.0
	_selected = 0
	set_message("")
	refresh()
	visible = true
	_hints.notify_opened(_menu_id())
	_layout()


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


## Vuelve a escribir el contenido con el estado actual (las subclases lo
## rellenan; la base solo repinta las opciones).
func refresh() -> void:
	_refresh_options()
	_layout()


func set_title(text: String) -> void:
	_title.text = text


## Lineas fijas bajo el titulo: cada una {"text": String, "color": rol}.
func set_lines(lines: Array) -> void:
	while _line_labels.size() < lines.size():
		_line_labels.append(_new_label("Line%d" % _line_labels.size(), "texto_tenue"))
	for i: int in _line_labels.size():
		var label: Label = _line_labels[i]
		label.visible = i < lines.size()
		if label.visible:
			var line: Dictionary = lines[i]
			label.text = String(line.get("text", ""))
			_set_color(label, String(line.get("color", "texto_tenue")))
	_layout()


## Opciones elegibles: cada una {"id": StringName, "text": String} y, si se
## quiere, "role" (rol de color cuando no esta elegida).
func set_options(options: Array) -> void:
	_option_ids.clear()
	_option_texts.clear()
	_option_roles.clear()
	for option: Dictionary in options:
		_option_ids.append(StringName(option.get("id", "")))
		_option_texts.append(String(option.get("text", "")))
		_option_roles.append(String(option.get("role", "")))
	while _option_labels.size() < _option_ids.size():
		var label: Label = _new_label("Option%d" % _option_labels.size(), "texto_tenue")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_option_labels.append(label)
	_selected = clampi(_selected, 0, maxi(_option_ids.size() - 1, 0))
	_refresh_options()
	_layout()


## Linea de detalle bajo las opciones (vacia = no ocupa sitio).
func set_detail(text: String, role: String = "texto_tenue") -> void:
	set_detail_lines([{"text": text, "color": role}] if not text.is_empty() else [])


## Lineas de detalle bajo las opciones: cada una {"text": String, "color": rol}.
func set_detail_lines(lines: Array) -> void:
	while _detail_labels.size() < lines.size():
		_detail_labels.append(_new_label("Detail%d" % _detail_labels.size(), "texto_tenue"))
	for i: int in _detail_labels.size():
		var label: Label = _detail_labels[i]
		var line: Dictionary = lines[i] if i < lines.size() else {}
		label.text = String(line.get("text", ""))
		if not line.is_empty():
			_set_color(label, String(line.get("color", "texto_tenue")))
	_layout()


## Texto del detalle (las lineas no vacias separadas por saltos de linea).
func get_detail() -> String:
	return "\n".join(get_detail_lines())


func get_detail_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label in _detail_labels:
		if not label.text.is_empty():
			out.append(label.text)
	return out


## Color de la linea de detalle `index` (de las no vacias).
func get_detail_color(index: int) -> Color:
	var shown: Array[Label] = []
	for label: Label in _detail_labels:
		if not label.text.is_empty():
			shown.append(label)
	return _label_color(shown[index])


func set_message(text: String, role: String = "texto_claro") -> void:
	_message.text = text
	_set_color(_message, role)
	_layout()


## Pie de teclas: grupo `set_id` de data/menu_hints.json.
func set_hints(set_id: String) -> void:
	_hints.show_set(set_id)
	_layout()


func get_title() -> String:
	return _title.text


## Lineas fijas visibles (sin titulo, opciones ni mensaje).
func get_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label in _line_labels:
		if label.visible:
			out.append(label.text)
	return out


func get_line_color(index: int) -> Color:
	return _label_color(_line_labels[index])


func get_option_ids() -> Array[StringName]:
	return _option_ids


func get_selected_index() -> int:
	return _selected


func get_selected_option() -> StringName:
	return _option_ids[_selected] if not _option_ids.is_empty() else &""


func get_message() -> String:
	return _message.text


## Texto plano del pie de teclas («G Aceptar · W/S Elegir · Espacio Volver»).
func get_help() -> String:
	return _hints.get_text()


func get_hints() -> MenuHints:
	return _hints


func select(index: int) -> void:
	if _option_ids.is_empty():
		return
	_selected = clampi(index, 0, _option_ids.size() - 1)
	_refresh_options()
	_on_selection_changed()


## Elige la opcion `id` (falso si no existe).
func select_option(id: StringName) -> bool:
	var index: int = _option_ids.find(id)
	if index < 0:
		return false
	select(index)
	return true


func move_selection(step: int) -> void:
	if _option_ids.is_empty():
		return
	_selected = posmod(_selected + step, _option_ids.size())
	_refresh_options()
	_on_selection_changed()


## Confirma la opcion elegida (accion confirm_action).
func confirm() -> void:
	if not _open:
		return
	_on_confirm(get_selected_option())


## Vuelve (accion cancel_action).
func cancel() -> void:
	if not _open:
		return
	_on_cancel()


## Para pruebas: da por pasado el retardo de entrada.
func skip_input_delay() -> void:
	_open_time = float(_config.get("input_delay_s", 0.15))


func get_panel_rect() -> Rect2:
	return Rect2(_panel.position * _frame.scale, _panel.size * _frame.scale)


# --- Para las subclases ---

func _on_confirm(id: StringName) -> void:
	option_chosen.emit(_selected, id)


func _on_cancel() -> void:
	close_requested.emit()


## La opcion elegida cambio (arriba/abajo o select).
func _on_selection_changed() -> void:
	pass


## Alto de cada fila de opcion en px de arte (por defecto, una linea de texto).
func _option_row_height(line_h: float) -> float:
	return line_h


## Sitio reservado a la izquierda del texto de cada opcion (px de arte).
func _option_inset_left() -> float:
	return 0.0


## Sitio reservado a la derecha del texto de cada opcion (px de arte).
func _option_inset_right() -> float:
	return 0.0


## Identificador del menu para el latido de la primera apertura (MenuHints).
func _menu_id() -> String:
	var script: Script = get_script()
	var id: String = String(script.get_global_name()) if script != null else ""
	return id if not id.is_empty() else "HubPanel"


## Tras colocar las etiquetas (las subclases colocan sus dibujos).
func _after_layout() -> void:
	pass


## Etiqueta de la opcion `index` (para colocar dibujos junto a ella).
func _get_option_label(index: int) -> Label:
	return _option_labels[index] if index < _option_labels.size() else null


## Nodo del cuadro del panel (padre de las etiquetas; px de arte).
func _get_panel_node() -> NinePatchRect:
	return _panel


func _line_height() -> float:
	return ceilf(_font.get_height(int(_config.get("font_size", 12))))


## Texto de `key` en texts de la seccion panel (o `fallback`).
func _text(key: String, fallback: String = "") -> String:
	return String(_config.get("texts", {}).get(key, fallback))


# --- Interno ---

func _action(key: String, fallback: String) -> StringName:
	return StringName(String(_config.get(key, fallback)))


func _accepts_input() -> bool:
	return _open_time >= float(_config.get("input_delay_s", 0.15))


func _refresh_options() -> void:
	var colors: Dictionary = _config.get("colors", {})
	for i: int in _option_labels.size():
		var label: Label = _option_labels[i]
		label.visible = i < _option_ids.size()
		if not label.visible:
			continue
		var selected: bool = i == _selected
		label.text = _text("selected_prefix" if selected else "unselected_prefix") + _option_texts[i]
		var role: String = String(colors.get("option", "texto_tenue"))
		if selected:
			role = String(colors.get("option_selected", "acento_cian"))
		elif i < _option_roles.size() and not _option_roles[i].is_empty():
			role = _option_roles[i]
		_set_color(label, role)


func _new_label(node_name: String, role: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", int(_config.get("font_size", 12)))
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"key_color", _key_color)
	material.set_shader_parameter(&"target_color", HubData.color(role))
	label.material = material
	_panel.add_child(label)
	return label


func _set_color(label: Label, role: String) -> void:
	(label.material as ShaderMaterial).set_shader_parameter(&"target_color", HubData.color(role))


func _label_color(label: Label) -> Color:
	return (label.material as ShaderMaterial).get_shader_parameter(&"target_color")


func _build() -> void:
	var colors: Dictionary = _config.get("colors", {})
	_font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_shader = load(String(_config.get("key_swap_shader", "res://assets/shaders/hud_key_swap.gdshader"))) as Shader
	_key_color = Color.html(String(_config.get("font_key_color", "#f2f4f8")))
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.scale = Vector2.ONE * maxi(1, int(_config.get("pixel_scale", 2)))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_panel = NinePatchRect.new()
	_panel.name = "Panel"
	_panel.texture = load(String(_config.get("texture", "res://assets/sprites/ui/eco_text_panel.png"))) as Texture2D
	var margin: int = int(_config.get("margin_px", 3))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, margin)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_panel)
	_title = _new_label("Title", String(colors.get("title", "texto_claro")))
	_message = _new_label("Message", String(colors.get("message", "texto_claro")))
	_hints = MenuHints.new()
	_hints.setup(_font, int(_config.get("font_size", 12)), _shader, _key_color, hint_colors())
	_hints.show_set("hub_list")
	_panel.add_child(_hints)
	_hints.row_changed.connect(_layout)


## Colores del pie de teclas con los roles del hub (hints de colors de la
## seccion panel).
static func hint_colors() -> Dictionary:
	var roles: Dictionary = HubData.section("panel").get("hint_colors", {})
	var out: Dictionary = {}
	var defaults: Dictionary = {"text": "texto_tenue", "key": "texto_claro", "label": "texto_tenue",
		"primary_label": "texto_claro", "key_plate": "acento_cian", "key_plate_pulse": "texto_claro",
		"key_text": "fondo_profundo", "key_border": "texto_claro"}
	for key: String in defaults:
		out[key] = HubData.color(String(roles.get(key, defaults[key])))
	return out


## Orden de pantalla: titulo, lineas, opciones, detalle y mensaje (los vacios
## o invisibles no ocupan sitio); el pie de teclas va debajo (_layout).
func _ordered_labels() -> Array[Label]:
	var out: Array[Label] = [_title]
	for label: Label in _line_labels + _option_labels:
		if label.visible:
			out.append(label)
	for label: Label in _detail_labels + [_message]:
		if not label.text.is_empty():
			out.append(label)
	return out


func _layout() -> void:
	if _frame == null or not is_inside_tree():
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale
	_frame.size = screen
	var font_size: int = int(_config.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(font_size))
	var pad: float = float(_config.get("padding_px", 10))
	var gap: float = float(_config.get("line_gap_px", 4))
	var width: float = float(_config.get("min_width_px", 240))
	var labels: Array[Label] = _ordered_labels()
	var inset_left: float = _option_inset_left()
	var inset_right: float = _option_inset_right()
	var row_h: float = maxf(_option_row_height(line_h), line_h)
	for label: Label in labels:
		var extra: float = inset_left + inset_right if _option_labels.has(label) else 0.0
		width = maxf(width, ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
				+ pad * 2.0 + extra)
	width = maxf(width, _hints.get_row_width() + pad * 2.0)
	for label: Label in _detail_labels + [_message]:
		label.visible = labels.has(label)
	var y: float = pad
	for i: int in labels.size():
		var label: Label = labels[i]
		if _option_labels.has(label):
			label.position = Vector2(pad + inset_left, y + floorf((row_h - line_h) * 0.5))
			label.size = Vector2(width - pad * 2.0 - inset_left - inset_right, line_h)
			y += row_h + gap
		else:
			label.position = Vector2(pad, y)
			label.size = Vector2(width - pad * 2.0, line_h)
			y += line_h + gap
		# Aire bajo el titulo y antes de las opciones.
		var next: Label = labels[i + 1] if i + 1 < labels.size() else null
		if label == _title or (next != null and _option_labels.has(next) and not _option_labels.has(label)) \
				or (_option_labels.has(label) and next != null and not _option_labels.has(next)):
			y += gap
	# Pie de teclas, centrado, con aire encima.
	y += gap
	_hints.position = Vector2(floorf((width - _hints.get_row_width()) * 0.5), y)
	y += _hints.get_row_height() + gap
	var height: float = y - gap + pad
	_panel.size = Vector2(width, height)
	var top: float = float(_config.get("top_px", 48))
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(minf(top, maxf(screen.y - height, 0.0))))
	_after_layout()
