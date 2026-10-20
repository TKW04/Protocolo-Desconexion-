## Efecto del dash (gesto Deslizar, 2026-10-19; docs/propuesta-1-3.md §2.3) con
## dash.visual de data/isak_abilities.json:
## - Estela de datos (arte por script desde el paso 8, 2026-10-20: trail_textures
##   de tools/gen_world1_dnd.py, filas de 32x4 que se repiten en x y alternan a
##   trail_fps): una fila por altura de trail_rows_px (desde los pies) entre donde
##   empezo el dash y donde esta Isak, en resplandor con el borde en borde_luz
##   (mundo1.gpl; sin debug_cian para no confundirse con el Debug); las filas de
##   los extremos, mas cortas; se apaga trail_s despues de acabar. Sin texturas,
##   lineas de color (trail / trail_edge).
## - Anillo en el celular que se rellena durante el enfriamiento (ring_*).
## Hijo de Isak; tiempo real (lo avanza Isak.step).
class_name DashEffect
extends Node2D

var _trail := Color("#4f71c4")
var _edge := Color("#9bb0e8")
var _ring := Color("#9bb0e8")
var _rows: Array = [-70, -56, -40, -24]
var _thickness: float = 2.0
var _trail_s: float = 0.18
var _ring_radius: float = 5.0
## Estela en coordenadas globales: x de inicio y x actual (pies) e y de los pies.
var _active: bool = false
var _from_x: float = 0.0
var _to_x: float = 0.0
var _feet_y: float = 0.0
var _fade_left: float = 0.0
var _cooldown_fraction: float = 0.0
var _phone := Vector2.ZERO
var _trail_textures: Array[Texture2D] = []
var _trail_fps: float = 20.0
var _time: float = 0.0


func configure(visual: Dictionary) -> void:
	_trail = Color(String(visual.get("trail", _trail.to_html(false))))
	_edge = Color(String(visual.get("trail_edge", _edge.to_html(false))))
	_ring = Color(String(visual.get("ring_color", _ring.to_html(false))))
	var rows: Variant = visual.get("trail_rows_px", _rows)
	if rows is Array and not (rows as Array).is_empty():
		_rows = rows
	_thickness = float(visual.get("trail_thickness_px", _thickness))
	_trail_s = float(visual.get("trail_s", _trail_s))
	_ring_radius = float(visual.get("ring_radius_px", _ring_radius))
	_trail_fps = float(visual.get("trail_fps", _trail_fps))
	_trail_textures.clear()
	for path: Variant in visual.get("trail_textures", []):
		var texture := load(String(path)) as Texture2D
		if texture != null:
			_trail_textures.append(texture)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func begin(_direction: float) -> void:
	var parent := get_parent() as Node2D
	_from_x = parent.global_position.x if parent != null else 0.0
	_to_x = _from_x
	_active = true
	_fade_left = 0.0
	queue_redraw()


func end() -> void:
	_active = false
	_fade_left = _trail_s
	queue_redraw()


func clear() -> void:
	_active = false
	_fade_left = 0.0
	_cooldown_fraction = 0.0
	queue_redraw()


## La estela se ve (durante el dash o apagandose).
func is_trail_visible() -> bool:
	return _active or _fade_left > 0.0


## Parte del enfriamiento que queda (0-1; el anillo se rellena al bajar).
func get_cooldown_fraction() -> float:
	return _cooldown_fraction


func advance(delta: float, isak: Isak) -> void:
	_time += delta
	if _active:
		_to_x = isak.global_position.x
		_feet_y = isak.global_position.y
	elif _fade_left > 0.0:
		_fade_left = maxf(_fade_left - delta, 0.0)
	var cooldown: float = isak.abilities.dash_cooldown_s
	_cooldown_fraction = clampf(isak.get_dash_cooldown_left() / cooldown, 0.0, 1.0) if cooldown > 0.0 else 0.0
	_phone = isak.get_pulse_origin()
	queue_redraw()


func _draw() -> void:
	if is_trail_visible() and absf(_to_x - _from_x) > 1.0:
		var alpha: float = 1.0 if _active else clampf(_fade_left / maxf(_trail_s, 0.001), 0.0, 1.0)
		var left: float = minf(_from_x, _to_x)
		var length: float = absf(_to_x - _from_x)
		var origin: Vector2 = to_local(Vector2(left, _feet_y)).round()
		for i: int in _rows.size():
			# Lineas escalonadas: la estela se acorta en las filas de los extremos.
			var inset: float = roundf(length * 0.12 * float(absi(i - (_rows.size() - 1) / 2)))
			var start: float = inset if _to_x >= _from_x else 0.0
			var rect := Rect2(origin + Vector2(start, float(_rows[i])), Vector2(maxf(length - inset, 2.0), _thickness))
			if not _trail_textures.is_empty():
				var texture: Texture2D = _trail_textures[int(_time * _trail_fps) % _trail_textures.size()]
				rect.size.y = texture.get_size().y
				draw_texture_rect(texture, rect, true, Color(1.0, 1.0, 1.0, alpha))
			else:
				draw_rect(rect, Color(_trail, 0.8 * alpha))
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Color(_edge, alpha))
	if _cooldown_fraction > 0.0:
		# Anillo que se rellena: arco de lo ya recargado (1 - fraccion).
		var filled: float = (1.0 - _cooldown_fraction) * TAU
		draw_arc(_phone, _ring_radius, -PI * 0.5, -PI * 0.5 + filled, 16, _ring, 1.0)
		draw_arc(_phone, _ring_radius, -PI * 0.5 + filled, -PI * 0.5 + TAU, 16, Color(_ring, 0.3), 1.0)
