## Decorado de la sala secreta «Excepciones» del 1-3 (2026-10-20, paso 7 de
## docs/propuesta-1-3.md §5.4): la lista de contactos que pueden saltarse el
## No molestar («Permitir llamadas de: Favoritos»). Tipo `exceptions_panel` de
## la lista `objects` del nivel.
##
## Solo decorado: sin colision, sin Q (no esta en el grupo de ayuda) y sin
## estado. Panel de width_tiles x height_tiles con el titulo arriba y una fila
## por contacto (icono generico de persona, nombre y una estrella de favorito).
## Nombres genericos («Mamá», «Abuelito»), ninguna marca. ARTE PROVISIONAL
## dibujado por codigo con la paleta del Mundo 1 (el definitivo, en el paso 8);
## textos con la fuente de textos. Va detras de Isak (z_index de la seccion).
## El origen del nodo es la esquina superior izquierda de la primera celda.
class_name ExceptionsPanel
extends Node2D

const GROUP: StringName = &"exceptions_panel"

@export_range(1, 16) var width_tiles: int = 4
@export_range(1, 8) var height_tiles: int = 3
## Id propio (opcional).
@export var object_id: StringName = &""
## Titulo del panel (PROPUESTA de §5.4).
@export var title: String = "Permitir llamadas de: Favoritos"
## Nombres de las filas, de arriba abajo (genericos, sin marcas).
@export var contacts: Array = ["Mamá", "Abuelito"]

var _config: Dictionary = World1ObjectsConfig.section("exceptions_panel")
var _labels: Array[Label] = []


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_config.get("z_index", -1))
	_build_labels()
	queue_redraw()


## Tamano del panel en px.
func get_size_px() -> Vector2:
	var t: float = World1ObjectsConfig.tile_size()
	return Vector2(width_tiles * t, height_tiles * t)


## Textos visibles, de arriba abajo (titulo y contactos).
func get_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label in _labels:
		out.append(label.text)
	return out


## Filas de contacto que caben en el panel.
func get_row_count() -> int:
	return _rows().size()


func _rows() -> Array:
	var pad: float = float(_config.get("padding_px", 8))
	var title_h: float = float(_config.get("title_height_px", 24))
	var row_h: float = float(_config.get("row_height_px", 28))
	var fit: int = maxi(floori((get_size_px().y - pad * 2.0 - title_h) / row_h), 0)
	return contacts.slice(0, mini(contacts.size(), fit))


func _color(key: String, fallback: String) -> Color:
	return Color.html(String(_config.get(key, fallback)))


func _build_labels() -> void:
	var font := load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var size: int = int(_config.get("font_size", 12))
	var pad: float = float(_config.get("padding_px", 8))
	var title_h: float = float(_config.get("title_height_px", 24))
	var row_h: float = float(_config.get("row_height_px", 28))
	var icon: float = float(_config.get("icon_size_px", 16))
	var width: float = get_size_px().x - pad * 2.0
	_labels.append(_make_label(font, size, title, Vector2(pad, pad), Vector2(width, title_h)))
	var rows: Array = _rows()
	for i: int in rows.size():
		var y: float = pad + title_h + i * row_h
		var x: float = pad + icon + pad
		_labels.append(_make_label(font, size, String(rows[i]), Vector2(x, y),
			Vector2(width - icon * 2.0 - pad * 2.0, row_h)))


func _make_label(font: Font, size: int, text: String, pos: Vector2, box: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.size = box
	label.text = text
	add_child(label)
	return label


func _draw() -> void:
	var size: Vector2 = get_size_px()
	var border: float = float(_config.get("border_px", 2))
	draw_rect(Rect2(Vector2.ZERO, size), _color("border_color", "#343f66"))
	draw_rect(Rect2(Vector2.ONE * border, size - Vector2.ONE * border * 2.0), _color("panel_color", "#1a2138"))
	var pad: float = float(_config.get("padding_px", 8))
	var title_h: float = float(_config.get("title_height_px", 24))
	var row_h: float = float(_config.get("row_height_px", 28))
	var icon: float = float(_config.get("icon_size_px", 16))
	var line: Color = _color("line_color", "#343f66")
	var icon_color: Color = _color("icon_color", "#aeb8d2")
	var star_color: Color = _color("star_color", "#9bb0e8")
	draw_rect(Rect2(pad, pad + title_h - border, size.x - pad * 2.0, border), line)
	for i: int in _rows().size():
		var top: float = pad + title_h + i * row_h
		var mid: float = top + row_h * 0.5
		# Persona generica: cabeza y hombros.
		draw_rect(Rect2(pad + icon * 0.3, mid - icon * 0.5, icon * 0.4, icon * 0.4), icon_color)
		draw_rect(Rect2(pad, mid, icon, icon * 0.5), icon_color)
		_draw_star(Vector2(size.x - pad - icon * 0.5, mid), icon * 0.5, star_color)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k: int in 10:
		var r: float = radius if k % 2 == 0 else radius * 0.45
		var a: float = -PI * 0.5 + k * PI / 5.0
		points.append((center + Vector2(cos(a), sin(a)) * r).round())
	draw_colored_polygon(points, color)
