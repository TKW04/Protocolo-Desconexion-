## Destello del laser en el celular de Isak (PROVISIONAL, dibujado por codigo,
## seccion laser_visual de data/isak_abilities.json):
## - charge: anticipacion minima antes de que salga el disparo (glow, cuadrado
##   de charge_radius_px).
## - fizzle: intento sin energia suficiente; dos chispas cortas en banner_gris
##   que se apagan en fizzle_s (feedback sutil).
## Isak lo crea como hijo y lo coloca en get_pulse_origin(). Tiempo real.
class_name LaserMuzzle
extends Node2D

enum Mode { NONE, CHARGE, FIZZLE }

var _mode: Mode = Mode.NONE
var _left: float = 0.0
var _total: float = 0.0
var _direction: float = 1.0
var _glow := Color("#3dfff5")
var _core := Color("#f2f4f8")
var _fizzle := Color("#aeb8d2")
var _radius: float = 6.0
var _fizzle_s: float = 0.25


func configure(visual: Dictionary) -> void:
	_glow = Color(String(visual.get("glow", _glow.to_html(false))))
	_core = Color(String(visual.get("core", _core.to_html(false))))
	_fizzle = Color(String(visual.get("fizzle", _fizzle.to_html(false))))
	_radius = float(visual.get("charge_radius_px", _radius))
	_fizzle_s = float(visual.get("fizzle_s", _fizzle_s))


func show_charge(duration_s: float, direction: float) -> void:
	_start(Mode.CHARGE, duration_s, direction)


func show_fizzle(direction: float) -> void:
	_start(Mode.FIZZLE, _fizzle_s, direction)


func clear() -> void:
	_mode = Mode.NONE
	_left = 0.0
	queue_redraw()


func get_mode() -> Mode:
	return _mode


## Avanza `delta` segundos reales (lo llama Isak en cada paso).
func advance(delta: float) -> void:
	if _mode == Mode.NONE:
		return
	_left -= delta
	if _left <= 0.0:
		clear()
		return
	queue_redraw()


func _start(mode: Mode, duration_s: float, direction: float) -> void:
	_mode = mode
	_total = maxf(duration_s, 0.001)
	_left = _total
	_direction = -1.0 if direction < 0.0 else 1.0
	queue_redraw()


func _draw() -> void:
	match _mode:
		Mode.CHARGE:
			var r: float = _radius
			draw_rect(Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), Color(_glow, 0.6))
			draw_rect(Rect2(Vector2(-r * 0.5, -r * 0.5), Vector2(r, r)), _core)
		Mode.FIZZLE:
			# Dos chispas que se acortan (pasos de 2 px, pixel art).
			var t: float = clampf(_left / _total, 0.0, 1.0)
			var len_px: float = maxf(roundf(_radius * t * 0.5) * 2.0, 2.0)
			var d: float = _direction
			draw_rect(Rect2(Vector2(minf(0.0, d * len_px), -4.0), Vector2(len_px, 2.0)), _fizzle)
			draw_rect(Rect2(Vector2(minf(2.0 * d, d * (len_px + 2.0)), 2.0), Vector2(len_px, 2.0)), _fizzle)
