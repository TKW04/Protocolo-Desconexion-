## Indicador del HUD dibujado con primitivas (arte provisional; paso 12).
## - SIGNAL: barras de senal (Sync Rate), cada barra es una fraccion igual.
## - BATTERY: bateria por segmentos (energia de Debug).
## - ATTENTION_ICON: icono del contador de puntos de atencion.
## Todos los tamanos salen de HudConfig (data/hud.json).
class_name HudMeter
extends Control

enum Kind { SIGNAL, BATTERY, ATTENTION_ICON }

@export var kind: Kind = Kind.SIGNAL

## Valor mostrado (0-1).
var value: float = 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## Rastro del dano (0-1): lo que se acaba de perder, en el color de dano.
var trail: float = 1.0:
	set(v):
		trail = clampf(v, 0.0, 1.0)
		queue_redraw()
var fill_color: Color = Color.WHITE:
	set(v):
		fill_color = v
		queue_redraw()
var empty_color: Color = Color(1, 1, 1, 0.2)
var trail_color: Color = Color.RED
var border_color: Color = Color.WHITE

var _config: HudConfig = HudConfig.shared()


func setup(config: HudConfig) -> void:
	_config = config
	empty_color = config.color(&"empty")
	trail_color = config.color(&"damage")
	border_color = config.color(&"battery_border")
	custom_minimum_size = get_meter_size()
	queue_redraw()


func get_meter_size() -> Vector2:
	match kind:
		Kind.SIGNAL:
			var n: int = _config.signal_bar_count
			return Vector2(n * _config.signal_bar_width_px + (n - 1) * _config.signal_bar_gap_px,
				_config.signal_bar_max_height_px)
		Kind.BATTERY:
			return Vector2(_config.battery_width_px + _config.battery_tip_width_px, _config.battery_height_px)
		_:
			return Vector2(_config.attention_icon_size_px, _config.attention_icon_size_px)


func _draw() -> void:
	# Centrado vertical dentro del alto que le de el contenedor.
	var top: float = floorf((size.y - get_meter_size().y) * 0.5)
	match kind:
		Kind.SIGNAL:
			_draw_signal(top)
		Kind.BATTERY:
			_draw_battery(top)
		Kind.ATTENTION_ICON:
			_draw_attention_icon(top)


## Fraccion (0-1) de la parte `index` de `count` que cubre `amount` (0-1).
static func part_fill(amount: float, index: int, count: int) -> float:
	return clampf(amount * count - index, 0.0, 1.0)


func _draw_signal(top: float) -> void:
	var n: int = _config.signal_bar_count
	var max_h: float = _config.signal_bar_max_height_px
	var w: float = _config.signal_bar_width_px
	for i: int in n:
		var t: float = float(i) / maxf(n - 1, 1)
		var h: float = roundf(lerpf(_config.signal_bar_min_height_px, max_h, t))
		var x: float = i * (w + _config.signal_bar_gap_px)
		var bottom: float = top + max_h
		draw_rect(Rect2(x, bottom - h, w, h), empty_color)
		var trail_h: float = roundf(h * part_fill(trail, i, n))
		if trail_h > 0.0:
			draw_rect(Rect2(x, bottom - trail_h, w, trail_h), trail_color)
		var fill_h: float = roundf(h * part_fill(value, i, n))
		if fill_h > 0.0:
			draw_rect(Rect2(x, bottom - fill_h, w, fill_h), fill_color)


func _draw_battery(top: float) -> void:
	var b: float = _config.battery_border_px
	var w: float = _config.battery_width_px
	var h: float = _config.battery_height_px
	var body := Rect2(0, top, w, h)
	# Borde (cuatro lados) y punta del polo.
	draw_rect(Rect2(body.position, Vector2(w, b)), border_color)
	draw_rect(Rect2(0, top + h - b, w, b), border_color)
	draw_rect(Rect2(0, top, b, h), border_color)
	draw_rect(Rect2(w - b, top, b, h), border_color)
	var tip_h: float = _config.battery_tip_height_px
	draw_rect(Rect2(w, top + floorf((h - tip_h) * 0.5), _config.battery_tip_width_px, tip_h), border_color)
	# Segmentos dentro del borde, con un hueco de 1 borde.
	var n: int = _config.battery_segments
	var gap: float = _config.battery_segment_gap_px
	var inner := Rect2(b + gap, top + b + gap, w - 2.0 * (b + gap), h - 2.0 * (b + gap))
	var seg_w: float = floorf((inner.size.x - (n - 1) * gap) / n)
	for j: int in n:
		var x: float = inner.position.x + j * (seg_w + gap)
		draw_rect(Rect2(x, inner.position.y, seg_w, inner.size.y), empty_color)
		var trail_w: float = roundf(seg_w * part_fill(trail, j, n))
		if trail_w > 0.0:
			draw_rect(Rect2(x, inner.position.y, trail_w, inner.size.y), trail_color)
		var fill_w: float = roundf(seg_w * part_fill(value, j, n))
		if fill_w > 0.0:
			draw_rect(Rect2(x, inner.position.y, fill_w, inner.size.y), fill_color)


## Icono provisional: un punto con brillo (como el coleccionable `o`).
func _draw_attention_icon(top: float) -> void:
	var s: float = _config.attention_icon_size_px
	var center := Vector2(s * 0.5, top + s * 0.5)
	draw_circle(center, s * 0.5, fill_color)
	draw_circle(center, s * 0.25, empty_color)
