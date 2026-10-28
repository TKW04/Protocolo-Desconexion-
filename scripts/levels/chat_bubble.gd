## Burbuja de chat (tipo `chat_bubble` del catalogo del Mundo 4; 2026-10-28, paso 3 de
## docs/propuesta-mundo-4.md §8 y §3.1): plataforma DE UNA VIA (se sube saltando desde
## debajo, como las '-') con un mensaje `text`, su autor (`side`, propiedad author_side: left = otros, right =
## Isak; la cola del bocadillo hacia su lado) y un sello de hora pequeno (`stamp`).
## - Largo: 1 tile por cada CHARS_PER_TILE (6) caracteres del texto, redondeo hacia
##   arriba, entre 1 y 8 (width_for_text; tools/build_level.py lo escribe en
##   width_tiles y el esquema rechaza uno que no cuadre). «El largo del mensaje define
##   el largo de la plataforma.»
## - De amigo (`friend`: lia, marco o tomi; 4-3): avatar con la inicial a su lado. No
##   se rompe ni dana.
## - «Se elimino este mensaje» (`deleted`): contorno discontinuo SIN colision.
## La tarjeta ocupa card_height_px arriba de su celda (como una plataforma '-').
## Base de TypingBubble y AutocorrectBubble: is_solid / set_solid, isak_stepping
## (pisada) y el dibujo. Avisa con `stepped` al pisarla Isak (dispara un
## «escribiendo…» enlazado). Aspecto PROVISIONAL por codigo (seccion chat_bubble de
## data/world4_objects.json, paleta provisional). El origen es la esquina superior
## izquierda de su primera celda.
class_name ChatBubble
extends StaticBody2D

const GROUP: StringName = &"chat_bubble"
const LAYER_WORLD: int = 1
const CHARS_PER_TILE: int = 6
const MIN_TILES: int = 1
const MAX_TILES: int = 8
const DELETED_TEXT: String = "Se eliminó este mensaje"
## Lo que se dibuja si DELETED_TEXT no cabe en la tarjeta (2026-10-28, paso 22:
## en las capturas salia cortado, «Se eliminó este me»).
const DELETED_SHORT_TEXT: String = "Eliminado"
const FRIEND_INITIALS: Dictionary = {&"lia": "L", &"marco": "M", &"tomi": "T"}

## Isak la empieza a pisar (pies encima, en el suelo).
signal stepped

@export var object_id: StringName = &""
@export var text: String = ""
## Autor: &"left" (otros) o &"right" (Isak).
@export var author_side: StringName = &"left"
@export_range(1, 8) var width_tiles: int = 1
## Sello de hora («03:47»; vacio = sin sello).
@export var stamp: String = ""
## Amigo remitente (&"lia", &"marco", &"tomi"; &"" = ninguno).
@export var friend_id: StringName = &""
## «Se elimino este mensaje»: sin colision.
@export var deleted: bool = false

var _cfg: Dictionary = World4ObjectsConfig.section("chat_bubble")
var _shape: CollisionShape2D
var _solid: bool = true
var _stepping: bool = false
var _isak: Isak
var _font: Font
var _dark_outline: _BubbleDarkOutline


## Largo en tiles de un texto (regla de §3.1).
static func width_for_text(value: String) -> int:
	return clampi(ceili(float(value.length()) / float(CHARS_PER_TILE)), MIN_TILES, MAX_TILES)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	var font_path: String = String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))
	if ResourceLoader.exists(font_path):
		_font = load(font_path) as Font
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	_shape.shape = RectangleShape2D.new()
	_shape.one_way_collision = true
	add_child(_shape)
	_apply_shape()
	_set_solid(_initial_solid())
	_attach_dark_outline.call_deferred()


func _physics_process(_delta: float) -> void:
	_update_stepping()
	if is_in_dark():
		queue_redraw()  # el texto sigue a la luz de la Linterna


# --- Consultas ---

func is_solid() -> bool:
	return _solid


## Isak la esta pisando ahora.
func is_stepped_on() -> bool:
	return _stepping


## Texto que se ve ahora (DELETED_TEXT si esta eliminada).
func get_shown_text() -> String:
	return DELETED_TEXT if deleted else text


func get_card_height() -> float:
	return float(_cfg.get("card_height_px", 32))


## Ancho actual en tiles (el autocorrector lo cambia).
func get_width_tiles() -> int:
	return width_tiles


## Desplazamiento en X de la tarjeta dentro de su ranura (px; el autocorrector la mueve).
func get_card_offset_x() -> float:
	return 0.0


func get_card_size() -> Vector2:
	return Vector2(float(get_width_tiles()) * World4ObjectsConfig.tile_size(), get_card_height())


## Tarjeta (global).
func get_card_rect() -> Rect2:
	return Rect2(global_position + Vector2(get_card_offset_x(), 0.0), get_card_size())


## Inicial del avatar del amigo («» sin amigo).
func get_friend_initial() -> String:
	return String(FRIEND_INITIALS.get(friend_id, ""))


## Ayuda de Eco: siempre (no se destruye).
## Ayuda de Eco: las eliminadas («Se eliminó este mensaje») son decorado y no ayudan.
func is_help_available() -> bool:
	return not deleted


## Verdadero si unos pies en `feet` con ese ancho pisan la tarjeta (en el suelo).
func feet_on(feet: Vector2, width: float, on_floor: bool) -> bool:
	if not on_floor or not _solid:
		return false
	var r: Rect2 = get_card_rect()
	var tol: float = float(_cfg.get("step_tolerance_px", 6))
	if absf(feet.y - r.position.y) > tol:
		return false
	var half: float = width * 0.5
	return feet.x + half > r.position.x and feet.x - half < r.end.x


# --- Para las subclases ---

## Estado de colision al empezar (deleted: sin colision).
func _initial_solid() -> bool:
	return not deleted


func _set_solid(on: bool) -> void:
	_solid = on
	if _shape != null:
		_shape.disabled = not on
	queue_redraw()


## Ajusta la forma al ancho y desplazamiento actuales.
func _apply_shape() -> void:
	if _shape == null:
		return
	var size: Vector2 = get_card_size()
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = Vector2(get_card_offset_x(), 0.0) + size * 0.5
	queue_redraw()


func _find_isak() -> Isak:
	if _isak == null or not is_instance_valid(_isak) or not _isak.is_inside_tree():
		_isak = LevelLookup.find_isak(self)
	return _isak


## El cuerpo de Isak se solapa con la tarjeta (no materializarse con el dentro).
func _isak_overlaps() -> bool:
	var isak: Isak = _find_isak()
	if isak == null:
		return false
	return LevelLookup.isak_body_rect(isak).intersects(get_card_rect())


func _update_stepping() -> void:
	var isak: Isak = _find_isak()
	var now: bool = isak != null and not isak.is_dead() \
			and feet_on(isak.global_position, isak.get_hitbox_size().x, isak.is_on_floor())
	if now and not _stepping:
		_stepping = true
		stepped.emit()
	elif not now:
		_stepping = false


# --- Modo oscuro (paso 4) ---

## Dentro de una zona «Modo oscuro» (DarkZone) la burbuja queda bajo el velo; una
## capa hija por encima del velo dibuja lo que siempre se ve: el borde al 30 % (y
## los puntos del «escribiendo…», TypingBubble). Lo demas lo enseña la Linterna.
func _attach_dark_outline() -> void:
	if not is_inside_tree() or _dark_outline != null:
		return
	if DarkZone.covering(get_tree(), get_card_rect().get_center()) == null:
		return
	_dark_outline = _BubbleDarkOutline.new()
	_dark_outline.name = "DarkOutline"
	_dark_outline.bubble = self
	_dark_outline.z_as_relative = false
	_dark_outline.z_index = DarkZone.veil_z() + 1
	add_child(_dark_outline)


## Esta bajo el velo de una zona oscura (tiene su capa DarkOutline).
func is_in_dark() -> bool:
	return _dark_outline != null


## Lo que se ve por encima del velo (local en `canvas`): el borde al dark_border_alpha.
func draw_dark_overlay(canvas: CanvasItem) -> void:
	if not _solid:
		return
	var shade: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var rect := Rect2(Vector2(get_card_offset_x(), 0.0), get_card_size())
	canvas.draw_rect(rect, Color(shade, float(_cfg.get("dark_border_alpha", 0.3))), false, 2.0)


class _BubbleDarkOutline:
	extends Node2D
	var bubble: ChatBubble

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if bubble != null:
			bubble.draw_dark_overlay(self)


# --- Dibujo ---

func _draw() -> void:
	draw_bubble(get_shown_text(), _solid and not deleted, 1.0)


## Dibuja la burbuja (local): texto, solida (crema) o eliminada (contorno
## discontinuo), con alpha `alpha`.
func draw_bubble(shown: String, solid: bool, alpha: float) -> void:
	var size: Vector2 = get_card_size()
	var rect := Rect2(Vector2(get_card_offset_x(), 0.0), size)
	var cream: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var shade: Color = World4ObjectsConfig.color("crema_sombra", Color("#b8ad94"))
	var ink: Color = World4ObjectsConfig.color("chat_noche", Color("#0f1422"))
	var gray: Color = World4ObjectsConfig.color("gris_claro", Color("#a9aebb"))
	var tail_w: float = float(_cfg.get("tail_px", 8))
	var tail_x: float = rect.position.x + 6.0 if author_side == &"left" else rect.end.x - 6.0 - tail_w
	var tail := PackedVector2Array([Vector2(tail_x, rect.end.y), Vector2(tail_x + tail_w, rect.end.y),
		Vector2(tail_x + (0.0 if author_side == &"left" else tail_w), rect.end.y + tail_w)])
	if solid:
		draw_rect(rect, Color(cream, alpha))
		draw_rect(rect, Color(shade, alpha), false, 2.0)
		draw_colored_polygon(tail, Color(cream, alpha))
	else:
		var dash: float = float(_cfg.get("dash_px", 6))
		var c: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
		for i: int in 4:
			draw_dashed_line(c[i], c[(i + 1) % 4], Color(gray, 0.7 * alpha), 2.0, dash)
	var initial: String = get_friend_initial()
	if not initial.is_empty():
		var r: float = float(_cfg.get("avatar_radius_px", 10))
		var center := Vector2(rect.position.x - r - 4.0 if author_side == &"left" else rect.end.x + r + 4.0, rect.size.y * 0.5)
		draw_circle(center, r, Color(World4ObjectsConfig.color("verde_apagado", Color("#7d9a80")), alpha))
		if _font != null:
			_draw_text(initial, center + Vector2(-r * 0.4, r * 0.4), Color(ink, alpha))
	if _font == null or shown.is_empty():
		return
	var text_color: Color = Color(ink, alpha) if solid else Color(gray, alpha)
	shown = fit_text(shown, rect.size.x - 12.0)
	if is_in_dark():
		# Modo oscuro (2026-10-28, arreglo de las capturas del paso 22): bajo el velo el texto se leia sin la
		# Linterna; ahora solo se dibujan los caracteres bajo su luz (el borde al 30 % sigue por encima del velo).
		_draw_text_lit(shown, rect.position + Vector2(6.0, rect.size.y * 0.5 + 5.0), text_color, rect.size.x - 12.0)
		if not stamp.is_empty() and solid:
			_draw_text_lit(stamp, Vector2(rect.end.x - stamp_width() - 6.0, rect.end.y - 2.0), Color(shade, alpha))
		return
	_draw_text(shown, rect.position + Vector2(6.0, rect.size.y * 0.5 + 5.0), text_color, rect.size.x - 12.0)
	if not stamp.is_empty() and solid:
		_draw_text(stamp, Vector2(rect.end.x - stamp_width() - 6.0, rect.end.y - 2.0), Color(shade, alpha))


## Ancho del sello de hora en px (2026-10-28, paso 22: con un ancho fijo de 34 px
## los sellos largos, «3 meses», salian cortados por el borde de la tarjeta).
func stamp_width() -> float:
	if _font == null or stamp.is_empty():
		return 0.0
	return _font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_cfg.get("font_size", 16))).x


## Texto que se dibuja en `width` px: el aviso de eliminada se acorta a
## DELETED_SHORT_TEXT si no cabe entero y, si tampoco cabe (1 tile), queda solo
## el contorno discontinuo; los demas textos no cambian.
func fit_text(shown: String, width: float) -> String:
	if shown != DELETED_TEXT or _font == null:
		return shown
	var px: int = int(_cfg.get("font_size", 16))
	for candidate: String in [shown, DELETED_SHORT_TEXT]:
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
			return candidate
	return ""


func _draw_text(value: String, at: Vector2, color: Color, max_width: float = -1.0) -> void:
	var px: int = int(_cfg.get("font_size", 16))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, px, color)


## Dibuja `value` caracter a caracter, solo los que caen bajo la luz de la Linterna (DarkZone.lit_by_flashlight
## en el centro de cada caracter); sin luz no se dibuja nada.
func _draw_text_lit(value: String, at: Vector2, color: Color, max_width: float = -1.0) -> void:
	var px: int = int(_cfg.get("font_size", 16))
	var x: float = 0.0
	for i: int in value.length():
		var ch: String = value[i]
		var w: float = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if max_width >= 0.0 and x + w > max_width:
			return
		var center: Vector2 = to_global(at + Vector2(x + w * 0.5, -px * 0.35))
		if ch != " " and DarkZone.lit_by_flashlight(get_tree(), center):
			draw_string(_font, at + Vector2(x, 0.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
		x += w


## Caracteres del texto que se ven ahora (pruebas: en el Modo oscuro, solo los que alumbra la Linterna).
func count_visible_text_chars() -> int:
	var shown: String = get_shown_text().replace(" ", "")
	if not is_in_dark():
		return shown.length()
	var size: Vector2 = get_card_size()
	var rect := Rect2(Vector2(get_card_offset_x(), 0.0), size)
	var px: int = int(_cfg.get("font_size", 16))
	var at: Vector2 = rect.position + Vector2(6.0, rect.size.y * 0.5 + 5.0)
	var x: float = 0.0
	var n: int = 0
	var full: String = fit_text(get_shown_text(), rect.size.x - 12.0)
	for i: int in full.length():
		var w: float = _font.get_string_size(full[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if full[i] != " " and DarkZone.lit_by_flashlight(get_tree(), to_global(at + Vector2(x + w * 0.5, -px * 0.35))):
			n += 1
		x += w
	return n
