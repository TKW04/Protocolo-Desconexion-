## Decorado de la sala secreta «Excepciones» del 1-3 (2026-10-20, paso 7 de
## docs/propuesta-1-3.md §5.4): la lista de contactos que pueden saltarse el
## No molestar («Permitir llamadas de: Favoritos»). Tipo `exceptions_panel` de
## la lista `objects` del nivel.
##
## Solo decorado: sin colision, sin Q (no esta en el grupo de ayuda) y sin
## estado. Panel de width_tiles x height_tiles con el titulo arriba y una fila
## por contacto (icono generico de persona, nombre y una estrella de favorito).
## Nombres genericos («Mamá», «Abuelito»), ninguna marca; textos definitivos
## desde el 2026-10-20. Arte por script (paso 8): marco nine-patch, persona y
## estrella (borde_luz) de tools/gen_world1_dnd.py; textos con la fuente de
## textos. Va detras de Isak (z_index de la seccion). 2026-10-22: texto a escala
## font_scale e iconos de 32 px (antes ilegibles en las capturas).
## El origen del nodo es la esquina superior izquierda de la primera celda.
class_name ExceptionsPanel
extends Node2D

const GROUP: StringName = &"exceptions_panel"

@export_range(1, 16) var width_tiles: int = 4
@export_range(1, 8) var height_tiles: int = 3
## Id propio (opcional).
@export var object_id: StringName = &""
## Titulo del panel (definitivo desde el 2026-10-20).
@export var title: String = "Permitir llamadas de: Favoritos"
## Nombres de las filas, de arriba abajo (genericos, sin marcas).
@export var contacts: Array = ["Mamá", "Abuelito"]

var _config: Dictionary = World1ObjectsConfig.section("exceptions_panel")
var _labels: Array[Label] = []
var _icons: Array[TextureRect] = []


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_config.get("z_index", -1))
	_build_frame()
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
	var contact: Texture2D = _texture("contact")
	var star: Texture2D = _texture("star")
	for i: int in rows.size():
		var y: float = pad + title_h + i * row_h
		var x: float = pad + icon + pad
		_labels.append(_make_label(font, size, String(rows[i]), Vector2(x, y),
			Vector2(width - icon * 2.0 - pad * 2.0, row_h)))
		# Iconos como nodos (2026-10-22: dibujados con draw_texture en _draw salian
		# como cuadrados blancos en el juego).
		var mid: float = roundf(y + row_h * 0.5 - icon * 0.5)
		_make_icon("Contact%d" % i, contact, Vector2(pad, mid))
		_make_icon("Star%d" % i, star, Vector2(get_size_px().x - pad - icon, mid))


func _make_label(font: Font, size: int, text: String, pos: Vector2, box: Vector2) -> Label:
	# Texto a escala entera (font_scale, 2026-10-22): la caja se mide en pixeles de
	# la fuente y el nodo se escala (pixeles dobles nitidos).
	var k: float = maxf(float(_config.get("font_scale", 1)), 1.0)
	var label := Label.new()
	label.scale = Vector2(k, k)
	box /= k
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


func _make_icon(node_name: String, texture: Texture2D, pos: Vector2) -> void:
	if texture == null:
		return
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.position = pos
	rect.size = texture.get_size()
	add_child(rect)
	_icons.append(rect)


## Iconos de las filas (persona y estrella por fila).
func get_icons() -> Array[TextureRect]:
	return _icons


func _texture(key: String) -> Texture2D:
	return load(String(_config.get(key, ""))) as Texture2D if _config.has(key) else null


## Marco nine-patch detras de los textos (hijo show_behind_parent: queda detras
## de lo que dibuja _draw y de las etiquetas).
func _build_frame() -> void:
	var texture: Texture2D = _texture("frame")
	if texture == null:
		return
	var margin: int = int(_config.get("frame_margin_px", 8))
	var frame := NinePatchRect.new()
	frame.name = "Frame"
	frame.texture = texture
	frame.patch_margin_left = margin
	frame.patch_margin_top = margin
	frame.patch_margin_right = margin
	frame.patch_margin_bottom = margin
	frame.size = get_size_px()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.show_behind_parent = true
	add_child(frame)
	move_child(frame, 0)


func _draw() -> void:
	var size: Vector2 = get_size_px()
	var border: float = float(_config.get("border_px", 2))
	var pad: float = float(_config.get("padding_px", 8))
	var title_h: float = float(_config.get("title_height_px", 24))
	draw_rect(Rect2(pad, pad + title_h - border, size.x - pad * 2.0, border), _color("line_color", "#343f66"))
