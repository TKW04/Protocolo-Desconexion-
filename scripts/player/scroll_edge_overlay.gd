## Aviso PROVISIONAL del scroll forzado (2026-10-22, paso 2 de
## docs/propuesta-mundo-2.md §3.1.1 y §3.2; colores de data/camera_scroll.json,
## paleta provisional del Mundo 2), dibujado por codigo en coordenadas del mundo:
## - el borde que dana: una franja de edge_bar_px («barra de progreso» del video)
##   con muescas que parpadean si Isak esta a menos de near_px;
## - flechas en los bordes laterales antes de un cambio de velocidad (dos =
##   mas rapido, una = mas lento: cambian de forma, no solo de color) y en el
##   borde de arriba antes de una inversion (apuntando abajo).
## Hijo de Isak (top_level); lo avanza Isak.step en tiempo real.
class_name ScrollEdgeOverlay
extends Node2D

var _camera: ScrollCamera
var _width: float = 1280.0
var _left: float = 0.0
var _bar: float = 16.0
var _near: float = 64.0
var _blink_hz: float = 6.0
var _edge := Color("#ff4a2a")
var _edge_shadow := Color("#a3221c")
var _notch := Color("#f4f0fa")
var _arrow := Color("#f4f0fa")
var _arrow_shadow := Color("#140a24")
var _time: float = 0.0
var _feet := Vector2.ZERO
var _near_edge: bool = false
var _change: int = 0
var _reverse_soon: bool = false


func configure(camera: ScrollCamera, limits: Rect2) -> void:
	_camera = camera
	var data: Dictionary = camera.data
	_bar = float(data.get("edge_bar_px", _bar))
	_near = float(data.get("near_px", _near))
	_blink_hz = float(data.get("blink_hz", _blink_hz))
	var colors: Dictionary = data.get("colors", {})
	_edge = Color(String(colors.get("edge", _edge.to_html(false))))
	_edge_shadow = Color(String(colors.get("edge_shadow", _edge_shadow.to_html(false))))
	_notch = Color(String(colors.get("notch", _notch.to_html(false))))
	_arrow = Color(String(colors.get("arrow", _arrow.to_html(false))))
	_arrow_shadow = Color(String(colors.get("arrow_shadow", _arrow_shadow.to_html(false))))
	if limits.has_area():
		_left = limits.position.x
		_width = limits.size.x
	else:
		_width = camera.get_view_size().x
	top_level = true
	z_index = 50


func advance(delta: float, feet: Vector2, head_y: float) -> void:
	if _camera == null:
		return
	global_position = Vector2.ZERO
	_time += delta
	_feet = feet
	if _camera.damaging_edge() == ScrollCamera.EDGE_TOP:
		_near_edge = head_y - _camera.get_top() < _near
	else:
		_near_edge = _camera.get_bottom() - feet.y < _near
	_change = _camera.upcoming_change()
	_reverse_soon = _camera.reverse_soon()
	queue_redraw()


## Isak esta a menos de near_px del borde que dana (las muescas parpadean).
func is_near_edge() -> bool:
	return _near_edge


## Aviso de cambio de velocidad en pantalla (+1 / -1 / 0).
func get_change_warning() -> int:
	return _change


func is_reverse_warning() -> bool:
	return _reverse_soon


func _draw() -> void:
	if _camera == null:
		return
	var top: bool = _camera.damaging_edge() == ScrollCamera.EDGE_TOP
	var y0: float = _camera.get_top() if top else _camera.get_bottom() - _bar
	draw_rect(Rect2(_left, y0, _width, _bar), _edge)
	draw_rect(Rect2(_left, y0 + (_bar - 2.0 if not top else 0.0), _width, 2.0), _edge_shadow)
	if _near_edge and fmod(_time * _blink_hz, 1.0) < 0.5:
		var step: float = 64.0
		var x: float = _left + step * 0.5
		while x < _left + _width:
			draw_rect(Rect2(x - 4.0, y0 + 4.0, 8.0, _bar - 8.0), _notch)
			x += step
	if _change != 0:
		var count: int = 2 if _change > 0 else 1
		var mid: float = _camera.get_top() + _camera.get_view_size().y * 0.5
		for side: float in [0.0, 1.0]:
			var x: float = _left + 24.0 if side == 0.0 else _left + _width - 24.0
			for i: int in count:
				_draw_arrow(Vector2(x, mid - float(i) * 22.0), -1.0)
	if _reverse_soon:
		var y: float = _camera.get_top() + 28.0
		var x2: float = _left + _width * 0.25
		while x2 < _left + _width:
			_draw_arrow(Vector2(x2, y), 1.0)
			x2 += _width * 0.25


## Flecha vertical (dir -1 = arriba, 1 = abajo) centrada en `at`.
func _draw_arrow(at: Vector2, dir: float) -> void:
	var tip := at + Vector2(0.0, 10.0 * dir)
	var points := PackedVector2Array([tip, at + Vector2(-10.0, -6.0 * dir), at + Vector2(10.0, -6.0 * dir)])
	var shadow := PackedVector2Array()
	for p: Vector2 in points:
		shadow.append(p + Vector2(2.0, 2.0))
	draw_colored_polygon(shadow, _arrow_shadow)
	draw_colored_polygon(points, _arrow)
