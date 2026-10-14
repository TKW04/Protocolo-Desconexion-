## Cuadro de texto de Eco (PROPUESTA V6, docs/preguntas.md): una notificacion
## arriba, debajo de la barra de estado del HUD, con la esfera de Eco, su
## nombre y el texto. No pausa el juego ni lee entradas: Isak sigue jugando.
## - Maquina de escribir discreta (chars_per_second de data/eco_text_box.json).
## - El texto se parte por palabras al ancho util del panel (fuente bitmap de
##   textos, con tildes y ene) y el panel crece con las lineas.
## - Al terminar de escribirse queda hold_time() segundos y se cierra solo.
## - Tiempo REAL: el Debug ralentiza el mundo (GameState.world_time_scale), no
##   este cuadro, y no se usa Engine.time_scale.
## Entrada: EventBus.eco_line_requested (o show_line()). Si llega otra linea
## con una en pantalla, se pone en cola. Salida: EventBus.eco_line_started y
## EventBus.eco_line_finished.
## Pixel base como el HUD: Frame se maqueta en pixeles de arte y se escala
## x pixel_scale (entero).
class_name EcoTextBox
extends CanvasLayer

enum Phase { IDLE, TYPING, HOLD, CLOSING }

const PANEL_ASSET: StringName = &"panel"
const ICON_ASSET: StringName = &"icon"
const LINE_BREAK: String = "\n"
const WORD_SEPARATOR: String = " "
const OPAQUE: float = 1.0
const TRANSPARENT: float = 0.0
## Modulacion neutra: el color sale de la fuente (banner_blanco) o del shader.
const NEUTRAL_MODULATE: Color = Color.WHITE

var _config: EcoTextBoxConfig = EcoTextBoxConfig.shared()
var _font: Font
var _phase: Phase = Phase.IDLE
## Lineas pendientes: {text, duration_s}.
var _queue: Array[Dictionary] = []
var _text: String = ""
## Texto ya partido en lineas, unido con saltos de linea (misma longitud que
## _text salvo si se corto una palabra mas ancha que el panel).
var _wrapped: String = ""
var _lines: PackedStringArray = []
var _typed: int = 0
var _type_time: float = 0.0
var _hold_s: float = 0.0
var _hold_left: float = 0.0
var _close_time: float = 0.0

@onready var _frame: Control = $Frame
@onready var _panel: NinePatchRect = $Frame/Panel
@onready var _icon: TextureRect = $Frame/Panel/Icon
@onready var _speaker: Label = $Frame/Panel/Speaker
@onready var _body: Label = $Frame/Panel/Body


func _ready() -> void:
	layer = _config.layer
	_apply_config()
	get_viewport().size_changed.connect(_fit_frame)
	EventBus.eco_line_requested.connect(_on_eco_line_requested)
	_set_alpha(TRANSPARENT)
	_panel.visible = false


func _process(delta: float) -> void:
	advance(delta)


# --- API ---

## Muestra `text` (o lo pone en cola). `duration_s` <= 0: tiempo por defecto.
func show_line(text: String, duration_s: float = -1.0) -> void:
	_queue.append({"text": text, "duration_s": duration_s})
	if _phase == Phase.IDLE:
		_start_next()


## Avanza `delta` segundos de tiempo real (lo llama _process; util en pruebas).
func advance(delta: float) -> void:
	match _phase:
		Phase.TYPING:
			_type_time += delta
			_set_alpha(_fade_in_alpha())
			_set_typed(mini(_wrapped.length(), floori(_type_time * _config.chars_per_second)))
			if _typed >= _wrapped.length():
				_phase = Phase.HOLD
				_hold_left = _hold_s
		Phase.HOLD:
			_type_time += delta
			_set_alpha(_fade_in_alpha())
			_hold_left -= delta
			if _hold_left <= 0.0:
				_phase = Phase.CLOSING
				_close_time = 0.0
		Phase.CLOSING:
			_close_time += delta
			if _config.fade_out_s <= 0.0 or _close_time >= _config.fade_out_s:
				_finish_line()
			else:
				_set_alpha(OPAQUE - _close_time / _config.fade_out_s)


## Escribe ya todo el texto de la linea actual (no cambia el tiempo en pantalla).
func finish_typing() -> void:
	if _phase == Phase.TYPING:
		_type_time = maxf(_type_time, _wrapped.length() / _config.chars_per_second)
		advance(0.0)


func is_showing() -> bool:
	return _phase != Phase.IDLE


func get_phase() -> Phase:
	return _phase


## Texto completo de la linea actual (vacio si no hay ninguna).
func get_text() -> String:
	return _text


## Caracteres ya escritos por la maquina de escribir (del texto ya partido).
func get_typed_count() -> int:
	return _typed


## Lo que se ve ahora (con los saltos de linea del ajuste).
func get_visible_text() -> String:
	return _body.text


func get_lines() -> PackedStringArray:
	return _lines


## Segundos que el texto completo queda en pantalla tras escribirse.
func get_hold_time() -> float:
	return _hold_s


func get_queue_size() -> int:
	return _queue.size()


## Ancho util para el texto, en pixeles de arte.
func get_text_width() -> float:
	return _text_width()


func get_font() -> Font:
	return _font


func get_panel_rect() -> Rect2:
	return Rect2(_panel.position * _frame.scale, _panel.size * _frame.scale)


func get_speaker_text() -> String:
	return _speaker.text


func get_pixel_scale() -> Vector2:
	return _frame.scale


func get_alpha() -> float:
	return _frame.modulate.a


## Parte `text` en lineas que caben en `max_width` (por palabras; una palabra
## mas ancha que la linea se corta por caracteres). Los espacios entre palabras
## se sustituyen por saltos de linea, asi que unir las lineas con "\n" da un
## texto de la misma longitud que el original.
static func wrap_text(text: String, font: Font, font_size: int, max_width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(WORD_SEPARATOR):
		var candidate: String = word if line.is_empty() else line + WORD_SEPARATOR + word
		if line.is_empty() or _width(font, candidate, font_size) <= max_width:
			line = candidate
		else:
			lines.append(line)
			line = word
		while _width(font, line, font_size) > max_width and line.length() > 1:
			var cut: int = line.length() - 1
			while cut > 1 and _width(font, line.substr(0, cut), font_size) > max_width:
				cut -= 1
			lines.append(line.substr(0, cut))
			line = line.substr(cut)
	lines.append(line)
	return lines


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# --- Interno ---

func _start_next() -> void:
	if _queue.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	_text = item["text"]
	_lines = wrap_text(_text, _font, _config.font_size, _text_width())
	_wrapped = LINE_BREAK.join(_lines)
	_hold_s = _config.hold_time(_text.length(), float(item["duration_s"]))
	_type_time = 0.0
	_phase = Phase.TYPING
	_set_typed(0)
	_layout()
	_panel.visible = true
	_set_alpha(_fade_in_alpha())
	EventBus.eco_line_started.emit(_text)
	if _wrapped.is_empty():
		advance(0.0)


func _finish_line() -> void:
	_phase = Phase.IDLE
	_set_alpha(TRANSPARENT)
	_panel.visible = false
	_text = ""
	_wrapped = ""
	_lines = []
	_set_typed(0)
	EventBus.eco_line_finished.emit()
	_start_next()


func _set_typed(count: int) -> void:
	_typed = count
	# Los saltos de linea ocupan el lugar de un espacio: el corte es estable.
	_body.text = _wrapped.substr(0, count)


func _fade_in_alpha() -> float:
	if _config.fade_in_s <= 0.0:
		return OPAQUE
	return minf(OPAQUE, _type_time / _config.fade_in_s)


func _set_alpha(alpha: float) -> void:
	_frame.modulate.a = alpha


func _line_height() -> int:
	return ceili(_font.get_height(_config.font_size))


func _text_left() -> int:
	return _config.padding_px + _config.asset_frame_size(ICON_ASSET).x + _config.icon_gap_px


func _text_width() -> float:
	return _config.width_px - _text_left() - _config.padding_px


func _apply_config() -> void:
	var c: EcoTextBoxConfig = _config
	_font = c.load_font()
	_frame.scale = Vector2.ONE * c.pixel_scale
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture = c.asset_texture(PANEL_ASSET)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, c.panel_margin_px)
	_icon.texture = c.asset_texture(ICON_ASSET)
	_icon.position = Vector2(c.padding_px, c.padding_px)
	_icon.size = Vector2(c.asset_frame_size(ICON_ASSET))
	for label: Label in [_speaker, _body]:
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", c.font_size)
		label.add_theme_color_override("font_color", NEUTRAL_MODULATE)
		label.add_theme_constant_override("line_spacing", 0)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
	_speaker.text = c.speaker_name
	_speaker.material = c.new_key_swap_material(c.color(&"body"), c.color(&"speaker"))
	_fit_frame()
	_layout()


## Frame ocupa la pantalla en pixeles de arte (su escala la lleva a 1280x720).
func _fit_frame() -> void:
	_frame.size = get_viewport().get_visible_rect().size / _frame.scale
	_layout()


func _layout() -> void:
	if _font == null:
		return
	var c: EcoTextBoxConfig = _config
	var line_h: int = _line_height()
	var lines: int = maxi(1, _lines.size())
	var icon_h: int = c.asset_frame_size(ICON_ASSET).y
	var height: int = maxi(c.padding_px * 2 + line_h * (1 + lines), c.padding_px * 2 + icon_h)
	var width: int = panel_width_for(_lines)
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(floorf((_frame.size.x - width) * 0.5), c.top_px)
	var left: int = _text_left()
	var inner: float = width - left - c.padding_px
	_speaker.position = Vector2(left, c.padding_px)
	_speaker.size = Vector2(inner, line_h)
	_body.position = Vector2(left, c.padding_px + line_h)
	_body.size = Vector2(inner, line_h * lines)


## Ancho del panel (px de arte) para estas lineas: se ajusta a la linea mas
## ancha (y al nombre), entre min_width_px y width_px.
func panel_width_for(lines: PackedStringArray) -> int:
	var c: EcoTextBoxConfig = _config
	var widest: float = _width(_font, c.speaker_name, c.font_size)
	for line: String in lines:
		widest = maxf(widest, _width(_font, line, c.font_size))
	return clampi(_text_left() + ceili(widest) + c.padding_px, c.min_width_px, c.width_px)


func _on_eco_line_requested(text: String, duration_s: float) -> void:
	show_line(text, duration_s)
