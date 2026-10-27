## Indicador de paginas del hub de varias paginas (2026-10-27, paso 2 de
## docs/propuesta-hub-mundos-4-6.md §1 y §3.2): `count` puntos centrados en el
## origen, separados `spacing_px`; el de `current` lleno (page_dot) y los demas
## en anillo (page_dot_other). La pagina `loading_page` (la 2 «en instalacion»)
## se ve como un anillo que se llena de abajo arriba en bucle (`loading_s` s),
## salvo si es la actual. Con una sola pagina el hub usa su PageDot de siempre.
class_name HubPageIndicator
extends Node2D

var count: int = 1
var current: int = 1
var loading_page: int = 0
var spacing_px: float = 16.0
var loading_s: float = 1.2
var current_texture: Texture2D
var other_texture: Texture2D

var _dots: Array[Sprite2D] = []
var _fill: Sprite2D
var _t: float = 0.0


func _ready() -> void:
	var first_x: float = -spacing_px * float(count - 1) * 0.5
	for i: int in count:
		var page: int = i + 1
		var dot := Sprite2D.new()
		dot.name = "Dot%d" % page
		dot.texture = current_texture if page == current else other_texture
		dot.position = Vector2(first_x + spacing_px * float(i), 0.0)
		add_child(dot)
		_dots.append(dot)
		if page == loading_page and page != current and current_texture != null:
			_fill = Sprite2D.new()
			_fill.name = "Loading"
			_fill.texture = current_texture
			_fill.centered = false
			_fill.region_enabled = true
			dot.add_child(_fill)
			_update_fill()


func _process(delta: float) -> void:
	if _fill == null:
		return
	_t = fposmod(_t + delta, maxf(loading_s, 0.05))
	_update_fill()


## Puntos del indicador.
func get_dot_count() -> int:
	return _dots.size()


## Pagina que se muestra llena.
func get_current() -> int:
	return current


## La pagina `page` se muestra «cargando» (relleno en bucle).
func is_loading(page: int) -> bool:
	return _fill != null and page == loading_page


## Fraccion del relleno del punto que carga (0-1; 0 si no hay).
func get_loading_fraction() -> float:
	if _fill == null:
		return 0.0
	return clampf(_t / maxf(loading_s, 0.05), 0.0, 1.0)


func _update_fill() -> void:
	var size: Vector2 = current_texture.get_size()
	var h: float = floorf(size.y * get_loading_fraction())
	_fill.region_rect = Rect2(0.0, size.y - h, size.x, h)
	_fill.position = Vector2(-size.x * 0.5, size.y * 0.5 - h)
	_fill.visible = h > 0.0
