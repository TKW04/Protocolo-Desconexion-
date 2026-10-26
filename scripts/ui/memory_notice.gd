## Aviso del SISTEMA al recoger un mensaje de secreto (MemoryPickup; paso 4 de
## docs/propuesta-recuerdos.md §7): «Recuerdo obtenido: <remitente>.» /
## «Guarda en Notas para conservarlo.» arriba en el centro de la pantalla, en un
## panel oscuro con borde cian (sin rojos). No es Eco (§1.4 y §9.5: Eco no tiene
## interes en que Isak recuerde), no pausa y no se puede cerrar: se ve show_s
## segundos reales (lo ultimo, fade_s, desvaneciendose) y se libera. Textos y
## aspecto en notice de la seccion memory_pickup de data/world1_objects.json.
class_name MemoryNotice
extends CanvasLayer

var _cfg: Dictionary = {}
var _lines: PackedStringArray = []
var _font: Font
var _left: float = 0.0
var _canvas: Node2D


## Crea el aviso del mensaje `memory_id` como hijo de `host` y lo devuelve.
static func show_for(memory_id: StringName, host: Node) -> MemoryNotice:
	var notice := MemoryNotice.new()
	notice.name = "MemoryNotice"
	notice.setup(memory_id)
	host.add_child(notice)
	return notice


## Lineas del aviso del mensaje `memory_id` ({remitente} = su remitente).
static func lines_for(memory_id: StringName) -> PackedStringArray:
	var cfg: Dictionary = World1ObjectsConfig.section("memory_pickup").get("notice", {})
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var sender: String = catalog.sender(memory_id)
	if sender.is_empty():
		sender = catalog.title(memory_id)
	var out: PackedStringArray = []
	for line: Variant in cfg.get("lines", []):
		out.append(String(line).replace("{remitente}", sender))
	return out


## Aviso del sistema con otras lineas y otro aspecto (`cfg`, mismas claves que
## notice con colores en hex; 2026-10-26: «Los likes no se guardan.» de HudLikes,
## docs/propuesta-mundo-3.md §2.3). Hijo de `host`.
static func show_lines(lines: PackedStringArray, cfg: Dictionary, host: Node) -> MemoryNotice:
	var notice := MemoryNotice.new()
	notice.name = "SystemNotice"
	notice.setup_lines(lines, cfg)
	host.add_child(notice)
	return notice


func setup(memory_id: StringName) -> void:
	setup_lines(lines_for(memory_id), World1ObjectsConfig.section("memory_pickup").get("notice", {}))


func setup_lines(lines: PackedStringArray, cfg: Dictionary) -> void:
	_cfg = cfg
	_lines = lines
	layer = int(_cfg.get("layer", 12))
	_left = float(_cfg.get("show_s", 3.5))
	var font_path: String = String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))
	if ResourceLoader.exists(font_path):
		_font = load(font_path) as Font


func _ready() -> void:
	_canvas = Node2D.new()
	_canvas.name = "Canvas"
	_canvas.draw.connect(_draw_notice)
	add_child(_canvas)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var fade: float = maxf(float(_cfg.get("fade_s", 0.5)), 0.001)
	_canvas.modulate.a = clampf(_left / fade, 0.0, 1.0)
	_canvas.queue_redraw()


func get_lines() -> PackedStringArray:
	return _lines


## Verdadero mientras se ve.
func is_showing() -> bool:
	return _left > 0.0 and is_inside_tree()


func _draw_notice() -> void:
	if _font == null or _lines.is_empty():
		return
	var scale_px: float = float(_cfg.get("scale", 2))
	var pad: float = float(_cfg.get("padding_px", 4))
	var gap: float = float(_cfg.get("line_gap_px", 2))
	var size_px: int = _font.get_fixed_size() if _font is FontFile else 12
	if size_px <= 0:
		size_px = 12
	var line_h: float = _font.get_height(size_px)
	var width: float = 0.0
	for line: String in _lines:
		width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
	var box := Vector2(width + pad * 2.0, line_h * _lines.size() + gap * (_lines.size() - 1) + pad * 2.0)
	var view: Vector2 = _canvas.get_viewport_rect().size
	var origin := Vector2(roundf(view.x * 0.5 - box.x * scale_px * 0.5), float(_cfg.get("top_px", 96)))
	_canvas.draw_set_transform(origin, 0.0, Vector2.ONE * scale_px)
	var rect := Rect2(Vector2.ZERO, box.round())
	var fill := Color(String(_cfg.get("fill_color", "#0b0e1a")))
	fill.a = float(_cfg.get("fill_alpha", 0.85))
	_canvas.draw_rect(rect, fill)
	_canvas.draw_rect(rect, Color(String(_cfg.get("border_color", "#3dfff5"))), false, 1.0)
	var color := Color(String(_cfg.get("text_color", "#f2f4f8")))
	for i: int in _lines.size():
		var w: float = _font.get_string_size(_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var x: float = roundf((box.x - w) * 0.5)
		var baseline := Vector2(x, pad + i * (line_h + gap) + _font.get_ascent(size_px))
		_canvas.draw_string(_font, baseline, _lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
	_canvas.draw_set_transform(Vector2.ZERO)
