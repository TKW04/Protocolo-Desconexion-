## Cartel de interfaz del Mundo 2 (tipo `feed_sign` del catalogo del Mundo 2;
## 2026-10-22, paso 11 de docs/propuesta-mundo-2.md §8, el 2-1 real): una
## tarjeta del feed con texto, con la voz de una app de videos («Para ti»,
## «Desliza hacia arriba», «Quedan 3 segundos para el siguiente video. No puedes
## cancelar»). Nunca dice «vuelta».
## - text: el texto; «\n» parte lineas (cada una centrada).
## - width_tiles / height_tiles: tamano de la tarjeta en tiles.
## - SOLO DECORADO: sin colision ni estado; el validador lo ignora. Puede llevar
##   su propia ayuda con Q (help_id del objeto en el nivel; el 2-1 apunta asi el
##   reloj del HUD, hud_clock, y el borde del scroll, feed_edge, a sus carteles).
## - accent: color de la franja de arriba (nombre de la paleta del Mundo 2).
## Aspecto por codigo (FeedCardDraw, paleta del Mundo 2; seccion feed_sign de
## data/world2_objects.json). El origen del nodo es la esquina superior
## izquierda de su celda.
class_name FeedSign
extends Node2D

const GROUP: StringName = &"feed_sign"

@export var object_id: StringName = &""
@export_multiline var text: String = ""
@export_range(1, 18) var width_tiles: int = 4
@export_range(1, 4) var height_tiles: int = 1
@export var accent: String = "magenta"

var _cfg: Dictionary = World2ObjectsConfig.section("feed_sign")
var _font: Font


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_cfg.get("z_index", -1))
	_font = load(String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	queue_redraw()


## Ayuda de Eco (HelpCatalog.is_help_live): un cartel siempre ayuda.
func is_help_available() -> bool:
	return true


## Lineas del texto (pruebas).
func get_lines() -> PackedStringArray:
	return text.split("\n")


## Rectangulo de la tarjeta en coordenadas locales.
func get_card_rect() -> Rect2:
	var t: float = World2ObjectsConfig.tile_size()
	var inset: float = float(_cfg.get("inset_px", 6))
	return Rect2(Vector2(0.0, inset), Vector2(float(width_tiles) * t, float(height_tiles) * t - inset * 2.0))


func _draw() -> void:
	var rect: Rect2 = get_card_rect()
	FeedCardDraw.card(self, rect)
	draw_rect(Rect2(rect.position + Vector2(6.0, 0.0), Vector2(rect.size.x - 12.0, 2.0)),
			World2ObjectsConfig.color(accent))
	if _font == null:
		return
	var px: int = int(_cfg.get("font_size", 16))
	var line_h: float = float(_cfg.get("line_height_px", 18))
	var lines: PackedStringArray = get_lines()
	var top: float = rect.position.y + (rect.size.y - line_h * lines.size()) * 0.5
	for i in lines.size():
		var width: float = _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var baseline := Vector2(rect.position.x + (rect.size.x - width) * 0.5,
				top + line_h * i + (line_h + _font.get_ascent(px)) * 0.5 - 2.0)
		draw_string(_font, baseline, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, World2ObjectsConfig.color("blanco"))
