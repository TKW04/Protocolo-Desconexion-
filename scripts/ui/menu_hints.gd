## Pie de teclas de un menu (2026-10-23, peticion del usuario: «que sea claro
## que G es el boton de accion para acceder a las opciones de los menus del
## hub»). Una fila «[G] Aceptar · W/S Elegir · Espacio Volver»: la accion
## principal (primary) va con su tecla en una cajita resaltada (acento_cian,
## como la placa «G» de las estaciones) y las demas en texto. Lo comparten
## todos los paneles del hub (HubPanel y sus subclases, NotasAlbum) y la
## entrada del apodo (NicknameEntry).
##
## - Las teclas se leen del Input Map (ControlBindings.primary + input_label,
##   las mismas tablas que los avisos de control y Ajustes > Controles): nunca
##   se escriben a mano; al reasignar (EventBus.controls_changed) cambian.
## - Dispositivo: el ultimo usado (teclado o mando), compartido por todas las
##   instancias (_input, sin consumir el evento). Con mando se ve el boton
##   («X», «A») y la navegacion dice pad_nav («Cruceta»).
## - Textos y grupos en data/menu_hints.json (sets por menu); colores, los que
##   pase quien lo usa (roles del hub o colores del apodo).
## - La primera vez de la sesion que se abre cada menu (notify_opened), la
##   cajita de la accion principal late suave first_open_pulse_s segundos
##   (alterna con key_plate_pulse); con «Reducir efectos» (GameSettings) no
##   late. No pausa ni anade pasos.
class_name MenuHints
extends Control

## La fila cambio de tamano (otras teclas o dispositivo): el panel la recoloca.
signal row_changed

const DATA_PATH: String = "res://data/menu_hints.json"

enum Device { KEYBOARD, PAD }

static var _data_cache: Dictionary = {}
static var _device: Device = Device.KEYBOARD
static var _seen_menus: Dictionary = {}

var _font: Font
var _font_size: int = 12
var _shader: Shader
var _key_color: Color = Color.WHITE
var _colors: Dictionary = {}
var _items: Array = []
var _rendered_device: Device = Device.KEYBOARD
var _pulse_left: float = 0.0
var _pulse_time: float = 0.0
var _plates: Array[ColorRect] = []
var _key_texts: PackedStringArray = []
var _text: String = ""


# --- Datos ---

static func load_data() -> Dictionary:
	if _data_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data_cache = parsed if parsed is Dictionary else {}
	return _data_cache


## Grupo de pistas `set_id` de data/menu_hints.json (vacio si falta).
static func hint_set(set_id: String) -> Array:
	var sets: Variant = load_data().get("sets", {})
	if sets is Dictionary and (sets as Dictionary).get(set_id) is Array:
		return (sets as Dictionary)[set_id]
	return []


## Dispositivo con el que se muestran las teclas.
static func current_device() -> Device:
	return _device


## Para pruebas: fija el dispositivo.
static func set_device(device: Device) -> void:
	_device = device


## Para pruebas: olvida que menus se han abierto ya en la sesion.
static func reset_seen() -> void:
	_seen_menus.clear()


# --- API ---

## Fuente, tamano, shader de color clave (fuente dibujada en `key_color`) y
## colores: text, key, label, primary_label, key_plate, key_plate_pulse,
## key_text, key_border (Color).
func setup(font: Font, font_size: int, shader: Shader, key_color: Color, colors: Dictionary) -> void:
	_font = font
	_font_size = font_size
	_shader = shader
	_key_color = key_color
	_colors = colors
	name = "MenuHints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebuild()


## Pistas del grupo `set_id` de data/menu_hints.json.
func show_set(set_id: String) -> void:
	set_items(hint_set(set_id))


## Pistas: cada una {action | actions, label, primary, join, compact, nav,
## text (solo texto, sin tecla)}.
func set_items(items: Array) -> void:
	_items = items.duplicate(true)
	_rebuild()


## Texto plano de la fila («G Aceptar · W/S Elegir · Espacio Volver»).
func get_text() -> String:
	return _text


## Teclas de la accion principal tal como se ven en sus cajitas.
func get_key_texts() -> PackedStringArray:
	return _key_texts


## Ancho de la fila en px de arte.
func get_row_width() -> float:
	return size.x


## Alto de la fila en px de arte (texto + borde de la cajita).
func get_row_height() -> float:
	if _font == null:
		return 0.0
	return ceilf(_font.get_height(_font_size)) + 2.0


## El menu `menu_id` se ha abierto: la primera vez en la sesion la cajita late.
## Devuelve si era la primera vez.
func notify_opened(menu_id: String) -> bool:
	var first: bool = not _seen_menus.has(menu_id)
	_seen_menus[menu_id] = true
	_pulse_time = 0.0
	_pulse_left = 0.0
	if first and not _effects_reduced():
		_pulse_left = float(load_data().get("first_open_pulse_s", 3.0))
	_apply_plate_color()
	return first


## La cajita esta latiendo ahora.
func is_pulsing() -> bool:
	return _pulse_left > 0.0


## Color actual de la (primera) cajita de la accion principal.
func get_plate_color() -> Color:
	return _plates[0].color if not _plates.is_empty() else Color.TRANSPARENT


# --- Godot ---

func _ready() -> void:
	if EventBus.has_signal(&"controls_changed") and not EventBus.controls_changed.is_connected(_rebuild):
		EventBus.controls_changed.connect(_rebuild)


func _input(event: InputEvent) -> void:
	var device: int = -1
	if event is InputEventKey and event.is_pressed():
		device = Device.KEYBOARD
	elif event is InputEventJoypadButton and event.is_pressed():
		device = Device.PAD
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		device = Device.PAD
	if device >= 0:
		_device = device as Device
	if _rendered_device != _device:
		_rebuild()


func _process(delta: float) -> void:
	if _pulse_left <= 0.0:
		return
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	_pulse_time += delta
	_apply_plate_color()


# --- Interno ---

func _effects_reduced() -> bool:
	return GameSettings.is_low_sync_reduced()


func _apply_plate_color() -> void:
	var lit: bool = false
	if _pulse_left > 0.0:
		var period: float = maxf(float(load_data().get("pulse_period_s", 0.6)), 0.05)
		lit = fmod(_pulse_time, period) < period * 0.5
	for plate: ColorRect in _plates:
		plate.color = _color("key_plate_pulse" if lit else "key_plate")


func _color(key: String) -> Color:
	return _colors.get(key, Color.WHITE)


## Texto de la tecla de `action` en el dispositivo actual (o en el otro si en
## este no tiene); "" si no tiene ninguna.
func _key_of(action: StringName) -> String:
	var order: Array = [ControlBindings.Device.KEYBOARD, ControlBindings.Device.PAD]
	if _device == Device.PAD:
		order.reverse()
	for device: Variant in order:
		var event: InputEvent = ControlBindings.primary(action, device)
		if event != null:
			return ControlBindings.input_label(event, _font)
	return ""


## Teclas de una pista (una por accion con tecla).
func _keys_of(item: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if bool(item.get("nav", false)) and _device == Device.PAD:
		var pad_nav: String = String(load_data().get("pad_nav", ""))
		if not pad_nav.is_empty():
			out.append(pad_nav)
			return out
	var actions: Array = item.get("actions", [])
	if item.has("action"):
		actions = [item["action"]]
	for action: Variant in actions:
		var key: String = _key_of(StringName(String(action)))
		if not key.is_empty() and not out.has(key):
			out.append(key)
	return out


func _join_keys(keys: PackedStringArray, item: Dictionary) -> String:
	var join: String = String(item.get("join", "/"))
	if bool(item.get("compact", false)):
		var single: bool = true
		for key: String in keys:
			single = single and key.length() == 1
		if single:
			join = ""
	return join.join(keys)


func _rebuild() -> void:
	_rendered_device = _device
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_plates.clear()
	_key_texts = []
	_text = ""
	if _font == null:
		return
	var line_h: float = ceilf(_font.get_height(_font_size))
	var sep: String = String(load_data().get("separator", " · "))
	var pad_x: float = float(load_data().get("key_pad_px", 2))
	var x: float = 0.0
	var parts: PackedStringArray = []
	var first: bool = true
	for raw: Variant in _items:
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		var label: String = String(item.get("label", ""))
		var plain: String = String(item.get("text", ""))
		if not plain.is_empty():
			if not first:
				x = _add_text(sep, "text", x)
			x = _add_text(plain, "text", x)
			parts.append(plain)
			first = false
			continue
		var keys: PackedStringArray = _keys_of(item)
		if keys.is_empty():
			continue
		if not first:
			x = _add_text(sep, "text", x)
		first = false
		var primary: bool = bool(item.get("primary", false))
		var plain_keys: String = _join_keys(keys, item)
		if primary:
			var join: String = String(item.get("join", "/"))
			for i: int in keys.size():
				if i > 0:
					x = _add_text(join, "text", x)
				x = _add_keycap(keys[i], x, line_h, pad_x)
				_key_texts.append(keys[i])
			x = _add_text(" " + label, "primary_label", x)
			plain_keys = join.join(keys)
		else:
			x = _add_text(plain_keys, "key", x)
			x = _add_text(" " + label, "label", x)
		parts.append(plain_keys + " " + label)
	_text = sep.join(parts)
	size = Vector2(ceilf(x), line_h + 2.0)
	custom_minimum_size = size
	_apply_plate_color()
	row_changed.emit()


func _add_label(text: String, color_key: String, pos: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", _font_size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	if _shader != null:
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter(&"key_color", _key_color)
		material.set_shader_parameter(&"target_color", _color(color_key))
		label.material = material
	else:
		label.add_theme_color_override(&"font_color", _color(color_key))
	label.position = pos
	label.size = Vector2(_width_of(text), ceilf(_font.get_height(_font_size)))
	add_child(label)
	return label


func _add_text(text: String, color_key: String, x: float) -> float:
	_add_label(text, color_key, Vector2(x, 1.0))
	return x + _width_of(text)


## Cajita: borde de 1 px, placa y la tecla; ocupa todo el alto de la fila.
func _add_keycap(key: String, x: float, line_h: float, pad_x: float) -> float:
	var w: float = _width_of(key) + pad_x * 2.0 + 2.0
	var border := ColorRect.new()
	border.name = "KeyBorder"
	border.color = _color("key_border")
	border.position = Vector2(x, 0.0)
	border.size = Vector2(w, line_h + 2.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	var plate := ColorRect.new()
	plate.name = "KeyPlate"
	plate.color = _color("key_plate")
	plate.position = Vector2(x + 1.0, 1.0)
	plate.size = Vector2(w - 2.0, line_h)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	_plates.append(plate)
	var label: Label = _add_label(key, "key_text", Vector2(x + 1.0 + pad_x, 1.0))
	label.name = "KeyText"
	return x + w


func _width_of(text: String) -> float:
	return ceilf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x)
