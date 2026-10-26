## Efecto PROVISIONAL de Pellizcar (2026-10-26; docs/propuesta-mundo-3.md §3.3.1),
## dibujado por codigo con compress.visual de data/isak_abilities.json: el icono
## pequeno «sin espacio» (barra de techo con una flecha hacia arriba debajo) sobre
## la cabeza de Isak comprimido mientras la vuelta al tamano esta pedida y no cabe.
## Hijo de Isak; tiempo real (lo avanza Isak.step). Colores provisionales hasta la
## paleta del Mundo 3 (nunca rojo: no es dano).
class_name CompressEffect
extends Node2D

var _color := Color("#f2f4f8")
var _edge := Color("#aeb8d2")
var _gap: float = 14.0
var _size: float = 12.0
var _blink_hz: float = 2.0
var _blocked: bool = false
var _time: float = 0.0
## Altura de la cabeza sobre los pies (px) en el ultimo advance().
var _head: float = 40.0


func configure(visual: Dictionary) -> void:
	_color = Color(String(visual.get("blocked_color", _color.to_html(false))))
	_edge = Color(String(visual.get("blocked_edge", _edge.to_html(false))))
	_gap = float(visual.get("blocked_gap_px", _gap))
	_size = maxf(float(visual.get("blocked_size_px", _size)), 4.0)
	_blink_hz = maxf(float(visual.get("blocked_blink_hz", _blink_hz)), 0.0)
	z_index = 2


## Muestra u oculta el icono «sin espacio».
func set_blocked(blocked: bool) -> void:
	if blocked == _blocked:
		return
	_blocked = blocked
	_time = 0.0
	queue_redraw()


func is_blocked_icon_visible() -> bool:
	return _blocked


func clear() -> void:
	set_blocked(false)


## `head_px`: alto de la caja actual (la cabeza esta a -head_px de los pies).
func advance(delta: float, head_px: float) -> void:
	_head = head_px
	if _blocked:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if not _blocked:
		return
	var alpha: float = 1.0
	if _blink_hz > 0.0:
		alpha = 0.55 + 0.45 * (0.5 + 0.5 * cos(TAU * _blink_hz * _time))
	var half: float = _size * 0.5
	var top: float = -_head - _gap - _size
	# Barra del techo.
	draw_line(Vector2(-half - 2.0, top), Vector2(half + 2.0, top), Color(_edge, alpha), 3.0)
	# Flecha hacia arriba que no llega a la barra.
	var tip := Vector2(0.0, top + 4.0)
	var base := Vector2(0.0, top + _size)
	draw_line(base, tip, Color(_color, alpha), 2.0)
	draw_line(tip, tip + Vector2(-4.0, 4.0), Color(_color, alpha), 2.0)
	draw_line(tip, tip + Vector2(4.0, 4.0), Color(_color, alpha), 2.0)
