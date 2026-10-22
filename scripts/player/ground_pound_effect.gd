## Efecto PROVISIONAL del golpe al suelo (gesto Mantener presionado, 2026-10-22;
## docs/propuesta-mundo-2.md §3.3), dibujado por codigo con ground_pound.visual
## de data/isak_abilities.json (colores de la paleta provisional del Mundo 2):
## - Carga en el suelo: el celular se ilumina en charge_steps pasos (puntos que
##   se encienden mientras se mantiene).
## - Caida: estela vertical sobre Isak.
## - Onda al aterrizar: dos lineas a ras de suelo que se abren hasta el ancho de
##   la onda en wave_s y se apagan.
## Hijo de Isak; tiempo real (lo avanza Isak.step). El arte final llegara con el
## del Mundo 2.
class_name GroundPoundEffect
extends Node2D

var _charge_color := Color("#ff9318")
var _charge_radius: float = 4.0
var _charge_steps: int = 3
var _streak := Color("#b7a3f0")
var _wave := Color("#f4f0fa")
var _wave_edge := Color("#b7a3f0")
var _wave_s: float = 0.3
## 0..1 de la carga en el suelo (0 = nada).
var _charge: float = 0.0
var _phone := Vector2.ZERO
var _dropping: bool = false
var _drop_from_y: float = 0.0
## Onda en curso (coordenadas globales): pies, medio ancho y tiempo restante.
var _wave_feet := Vector2.ZERO
var _wave_half: float = 96.0
var _wave_left: float = 0.0
## Pies de Isak (global) en el ultimo advance().
var _owner_feet := Vector2.ZERO


func configure(visual: Dictionary) -> void:
	_charge_color = Color(String(visual.get("charge_color", _charge_color.to_html(false))))
	_charge_radius = float(visual.get("charge_radius_px", _charge_radius))
	_charge_steps = maxi(int(visual.get("charge_steps", _charge_steps)), 1)
	_streak = Color(String(visual.get("streak_color", _streak.to_html(false))))
	_wave = Color(String(visual.get("wave_color", _wave.to_html(false))))
	_wave_edge = Color(String(visual.get("wave_edge", _wave_edge.to_html(false))))
	_wave_s = maxf(float(visual.get("wave_s", _wave_s)), 0.01)
	top_level = true
	z_index = 1


## Carga del golpe en el suelo (0..1) y posicion del celular (px desde los pies).
func set_charge(fraction: float, phone: Vector2) -> void:
	var next: float = clampf(fraction, 0.0, 1.0)
	if is_equal_approx(next, _charge) and phone == _phone:
		return
	_charge = next
	_phone = phone
	queue_redraw()


## Pasos de la carga encendidos (0..charge_steps). Pruebas.
func get_charge_steps_lit() -> int:
	return floori(_charge * float(_charge_steps) + 0.0001)


func begin_drop(feet: Vector2) -> void:
	_dropping = true
	_drop_from_y = feet.y
	queue_redraw()


func end_drop() -> void:
	_dropping = false
	queue_redraw()


## Empieza la onda en los pies (`feet`, global) con medio ancho `half_width`.
func show_wave(feet: Vector2, half_width: float) -> void:
	_wave_feet = feet
	_wave_half = half_width
	_wave_left = _wave_s
	queue_redraw()


func is_wave_visible() -> bool:
	return _wave_left > 0.0


func clear() -> void:
	_charge = 0.0
	_dropping = false
	_wave_left = 0.0
	queue_redraw()


func advance(delta: float, owner_isak: Node2D) -> void:
	global_position = Vector2.ZERO
	if _wave_left > 0.0:
		_wave_left = maxf(_wave_left - delta, 0.0)
		queue_redraw()
	if _dropping or _charge > 0.0:
		queue_redraw()
	_owner_feet = owner_isak.global_position


func _draw() -> void:
	var feet: Vector2 = _owner_feet
	if _charge > 0.0:
		var lit: int = get_charge_steps_lit()
		for i: int in _charge_steps:
			var at: Vector2 = feet + _phone + Vector2(0.0, -float(i) * (_charge_radius * 2.0 + 2.0))
			var color: Color = _charge_color if i < lit else Color(_charge_color, 0.25)
			draw_circle(at, _charge_radius, color)
	if _dropping:
		var top: float = minf(_drop_from_y, feet.y - 1.0)
		for dx: float in [-10.0, 10.0]:
			draw_line(Vector2(feet.x + dx, top - 80.0), Vector2(feet.x + dx, feet.y - 80.0), _streak, 2.0)
	if _wave_left > 0.0:
		var t: float = 1.0 - _wave_left / _wave_s
		var half: float = lerpf(16.0, _wave_half, t)
		var alpha: float = 1.0 - t * 0.7
		for side: float in [-1.0, 1.0]:
			var a := Vector2(_wave_feet.x + side * 8.0, _wave_feet.y - 2.0)
			var b := Vector2(_wave_feet.x + side * half, _wave_feet.y - 2.0)
			draw_line(a, b, Color(_wave, alpha), 3.0)
			draw_line(a + Vector2(0.0, -6.0), b + Vector2(-side * 12.0, -6.0), Color(_wave_edge, alpha * 0.8), 2.0)
