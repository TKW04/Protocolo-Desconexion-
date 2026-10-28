## Efecto PROVISIONAL del congelado (estado Frozen, 2026-10-28; docs/propuesta-mundo-4.md
## §3.3), dibujado por codigo con frozen.visual de data/isak_abilities.json y la paleta
## provisional del Mundo 4 (World4ObjectsConfig):
## - Velo de la escena: gris_oscuro al veil_alpha sobre lo que se ve (la regla 5 de
##   tools/palette_mundo4_provisional.py mide el contorno de lo que dana bajo el).
## - Doble check sobre la cabeza de Isak (verde_apagado, el color del «Visto»).
## - Barra de bar_segments segmentos (crema) que se vacia con la cuenta. En el aviso
##   del golpe al liberarse (2026-10-28: los ultimos release_warn_s, 9 cuadros) la barra
##   y su marco pasan a rojo (alerta) y laten: lo que va a danar se anticipa en rojo.
## Hijo de Isak, top_level (dibuja en coordenadas globales); lo actualiza Isak.step
## con su posicion y lo que queda. El arte final, si lo hay, es del paso 24.
class_name FrozenEffect
extends Node2D

var _veil_alpha: float = 0.5
var _check_offset: float = 18.0
var _check_size: float = 14.0
var _check_width: float = 3.0
var _segments: int = 4
var _bar_width: float = 44.0
var _bar_height: float = 6.0
var _bar_gap: float = 2.0
var _veil_color := Color("#3c4250")
var _check_color := Color("#7d9a80")
var _bar_color := Color("#eee4cc")
var _bar_back := Color("#0f1422")
var _warn_color := Color("#ff4a2a")
## Aviso del golpe al liberarse (los ultimos release_warn_s de la cuenta).
var _warning: bool = false
var _warn_time: float = 0.0
var _showing: bool = false
## Fraccion que queda (1 = recien congelado, 0 = se acaba).
var _left: float = 0.0
## Tope de la caja de Isak (global) y su centro en X.
var _head := Vector2.ZERO


func configure(visual: Dictionary) -> void:
	_veil_alpha = clampf(float(visual.get("veil_alpha", _veil_alpha)), 0.0, 1.0)
	_check_offset = float(visual.get("check_offset_px", _check_offset))
	_check_size = float(visual.get("check_size_px", _check_size))
	_check_width = float(visual.get("check_width_px", _check_width))
	_segments = maxi(int(visual.get("bar_segments", _segments)), 1)
	_bar_width = float(visual.get("bar_width_px", _bar_width))
	_bar_height = float(visual.get("bar_height_px", _bar_height))
	_bar_gap = float(visual.get("bar_gap_px", _bar_gap))
	_veil_color = World4ObjectsConfig.color("gris_oscuro", _veil_color)
	_check_color = World4ObjectsConfig.color("verde_apagado", _check_color)
	_bar_color = World4ObjectsConfig.color("crema", _bar_color)
	_bar_back = World4ObjectsConfig.color("chat_noche", _bar_back)
	_warn_color = World4ObjectsConfig.color("alerta", _warn_color)
	top_level = true
	z_index = 50
	visible = false


## Muestra o actualiza el efecto: `head` = tope de la caja de Isak (global) y
## `left` = fraccion de la congelacion que queda; `warning` = aviso del golpe al
## liberarse (barra en rojo que late).
func show_frozen(head: Vector2, left: float, warning: bool = false) -> void:
	if warning and not _warning:
		_warn_time = 0.0
	elif warning:
		_warn_time += get_process_delta_time()
	_warning = warning
	_showing = true
	_head = head
	_left = clampf(left, 0.0, 1.0)
	global_position = Vector2.ZERO
	visible = true
	queue_redraw()


func clear() -> void:
	_showing = false
	_warning = false
	visible = false
	queue_redraw()


func is_showing() -> bool:
	return _showing


## Segmentos de la barra que siguen llenos (redondeo hacia arriba).
func get_segments_left() -> int:
	if not _showing:
		return 0
	return clampi(ceili(_left * float(_segments) - 0.0001), 0, _segments)


func get_segments() -> int:
	return _segments


func get_veil_alpha() -> float:
	return _veil_alpha


## Esta avisando del golpe al liberarse (barra en rojo).
func is_warning() -> bool:
	return _showing and _warning


func _draw() -> void:
	if not _showing:
		return
	if is_inside_tree() and get_viewport() != null:
		var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
		draw_rect(view.grow(64.0), Color(_veil_color, _veil_alpha))
	# Doble check sobre la cabeza.
	var base := Vector2(_head.x, _head.y - _check_offset)
	var s: float = _check_size
	for dx: float in [-s * 0.35, s * 0.35]:
		var a := base + Vector2(dx - s * 0.5, 0.0)
		var b := base + Vector2(dx - s * 0.15, s * 0.35)
		var c := base + Vector2(dx + s * 0.5, -s * 0.4)
		draw_polyline(PackedVector2Array([a, b, c]), _check_color, _check_width)
	# Barra de segmentos que se vacia.
	var top: float = base.y + s * 0.6
	var seg_w: float = (_bar_width - _bar_gap * float(_segments - 1)) / float(_segments)
	var x0: float = _head.x - _bar_width * 0.5
	draw_rect(Rect2(x0 - 1.0, top - 1.0, _bar_width + 2.0, _bar_height + 2.0), _bar_back)
	var fill: Color = _bar_color
	if _warning:
		var pulse: float = 0.6 + 0.4 * absf(sin(_warn_time * TAU * 4.0))
		fill = Color(_warn_color, pulse)
		draw_rect(Rect2(x0 - 2.0, top - 2.0, _bar_width + 4.0, _bar_height + 4.0), _warn_color, false, 2.0)
	var full: int = get_segments_left()
	for i: int in _segments:
		var r := Rect2(x0 + float(i) * (seg_w + _bar_gap), top, seg_w, _bar_height)
		if i < full:
			draw_rect(r, fill)
		else:
			draw_rect(r, Color(fill, 0.25))
