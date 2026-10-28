## Efecto PROVISIONAL de Agitar (gesto Agitar, 2026-10-28; docs/propuesta-mundo-4.md
## §3.2), dibujado por codigo con shockwave.visual de data/isak_abilities.json:
## - Anticipacion: Isak sacude el celular (el sprite oscila shake_px a izquierda y
##   derecha a shake_hz; lo aplica Isak con shake_offset()).
## - Onda: un anillo que nace en el celular y crece hasta el radio de la onda en
##   ring_s, con un relleno tenue, y se apaga.
## Hijo de Isak, top_level (la onda se queda donde nacio); tiempo real (lo avanza
## Isak.step). La pose final con AutoSprite llega en el paso 24 (decision del
## usuario 2026-10-28: placeholders por script hasta tener los niveles y el jefe).
class_name ShockwaveEffect
extends Node2D

var _shake_px: float = 3.0
var _shake_hz: float = 20.0
var _ring_s: float = 0.25
var _ring_width: float = 4.0
var _ring_color := Color("#3dfff5")
var _fill_alpha: float = 0.18
## Onda en curso (global): centro, radio final y tiempo restante.
var _center := Vector2.ZERO
var _radius: float = 160.0
var _ring_left: float = 0.0


func configure(visual: Dictionary) -> void:
	_shake_px = float(visual.get("shake_px", _shake_px))
	_shake_hz = maxf(float(visual.get("shake_hz", _shake_hz)), 0.01)
	_ring_s = maxf(float(visual.get("ring_s", _ring_s)), 0.01)
	_ring_width = float(visual.get("ring_width_px", _ring_width))
	_ring_color = Color(String(visual.get("ring_color", _ring_color.to_html(false))))
	_fill_alpha = clampf(float(visual.get("ring_fill_alpha", _fill_alpha)), 0.0, 1.0)
	top_level = true
	z_index = 1


## Desplazamiento horizontal del sprite tras `t` s de anticipacion (sacudida).
func shake_offset(t: float) -> float:
	var phase: int = floori(maxf(t, 0.0) * _shake_hz * 2.0)
	return _shake_px if phase % 2 == 0 else -_shake_px


## Nace la onda en `center` (global) con radio final `radius`.
func show_wave(center: Vector2, radius: float) -> void:
	_center = center
	_radius = maxf(radius, 0.0)
	_ring_left = _ring_s
	global_position = Vector2.ZERO
	queue_redraw()


## Verdadero mientras se dibuja la onda.
func is_wave_visible() -> bool:
	return _ring_left > 0.0


## Radio dibujado ahora (crece de 0 al radio final). Pruebas.
func get_ring_radius() -> float:
	if _ring_left <= 0.0:
		return 0.0
	return _radius * clampf(1.0 - _ring_left / _ring_s, 0.0, 1.0)


func advance(delta: float) -> void:
	if _ring_left <= 0.0:
		return
	_ring_left = maxf(_ring_left - delta, 0.0)
	queue_redraw()


func clear() -> void:
	_ring_left = 0.0
	queue_redraw()


func _draw() -> void:
	if _ring_left <= 0.0:
		return
	var r: float = maxf(get_ring_radius(), 1.0)
	var fade: float = clampf(_ring_left / _ring_s, 0.0, 1.0)
	var fill := Color(_ring_color, _fill_alpha * fade)
	var edge := Color(_ring_color, fade)
	draw_circle(_center, r, fill)
	draw_arc(_center, r, 0.0, TAU, 48, edge, _ring_width)
