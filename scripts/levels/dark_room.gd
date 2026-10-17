## Cuarto a oscuras (tipo `dark_room`; acertijo de la azotea del 1-2,
## 2026-10-17, tanda H1 del paso 14; docs/propuesta-calc-encuentro.md; seccion
## dark_room de data/world1_objects.json). Velo oscuro de width_tiles x
## height_tiles desde la esquina de su celda, dibujado por encima del mundo (z
## de la seccion) y sin colision. La LUZ sigue el progreso del PowerSwitch con
## id == switch_id (0, 1/3, 2/3, 1 con tres pulsos; activado, luz completa) con
## una transicion corta (fade_s, tiempo del mundo). Con el Debug el velo baja
## (debug_factor) y se dibujan los contornos discontinuos de las piezas del
## acertijo que estan dentro (interruptores, panel oculto ya visible, punto de
## carga): «con el Debug se ven los contornos de lo oculto». Con done_if_ally
## conocido arranca con luz.
## Halos: Eco es una esfera de luz, asi que alrededor de Eco companero (y, mas
## pequeno, de cada interruptor sin activar) el velo se aclara en anillos
## escalonados de cell_px (pixel art, sin degradados): en la oscuridad se ve a
## Eco y lo que senala.
class_name DarkRoom
extends Node2D

const GROUP: StringName = &"dark_room"

@export var object_id: StringName = &""
@export_range(1, 64) var width_tiles: int = 4
@export_range(1, 64) var height_tiles: int = 4
@export var switch_id: StringName = &""
@export var done_if_ally: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("dark_room")
## Luz mostrada (0 a 1) y la que toca.
var _light: float = 0.0
var _target: float = 0.0
var _drawn_alpha: float = -1.0
var _drawn_intensity: float = -1.0
var _drawn_lights: Array = []


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(CalcRoom.LINK_GROUP)
	z_index = int(_config.get("z", 40))
	if CalcRoom.skipped_for(done_if_ally):
		_light = 1.0
		_target = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

## Luz que toca ahora (progreso del interruptor).
func get_target_light() -> float:
	return _target


## Luz mostrada (sube hacia la que toca en fade_s).
func get_light() -> float:
	return _light


## Opacidad del velo ahora (con el Debug, mas baja).
func get_veil_alpha() -> float:
	var alpha: float = float(_config.get("darkness", 0.9)) * (1.0 - _light)
	return alpha * lerpf(1.0, float(_config.get("debug_factor", 0.45)), DebugMode.get_intensity())


func get_room_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	return Rect2(global_position, Vector2(width_tiles * t, height_tiles * t))


## El cuarto esta del todo iluminado.
func is_lit() -> bool:
	return _light >= 1.0


## Piezas del acertijo dentro del cuarto cuyo contorno se dibuja con el Debug.
func get_outlined_nodes() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if not is_inside_tree():
		return out
	var room: Rect2 = get_room_rect()
	for node: Node in get_tree().get_nodes_in_group(CalcRoom.LINK_GROUP):
		var item := node as Node2D
		if item == null or item == self or not room.has_point(_outline_rect(item).get_center()):
			continue
		if item is PowerSwitch and not (item as PowerSwitch).is_revealed():
			continue
		if item is PowerSwitch or item is LaserSwitch or item is ChargeDock:
			out.append(item)
	return out


# --- Acciones ---

## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	var source := CalcRoom.find(self, switch_id) as PowerSwitch
	if source != null:
		_target = maxf(_target, 1.0 if source.is_activated() else source.get_progress())
	var fade: float = maxf(float(_config.get("fade_s", 0.35)), 0.001)
	_light = move_toward(_light, _target, dt / fade)
	var alpha: float = get_veil_alpha()
	var intensity: float = DebugMode.get_intensity()
	if not is_equal_approx(alpha, _drawn_alpha) or not is_equal_approx(intensity, _drawn_intensity) \
			or get_lights() != _drawn_lights:
		queue_redraw()


## Fuentes de luz dentro del cuarto: [[centro local redondeado a cell_px, radio], ...].
func get_lights() -> Array:
	var out: Array = []
	if not is_inside_tree() or _light >= 1.0:
		return out
	var cell: float = float(_config.get("cell_px", 16))
	var room: Rect2 = get_room_rect().grow(float(_config.get("eco_light_px", 112)))
	for node: Node in get_tree().get_nodes_in_group(EcoCompanion.GROUP):
		var eco := node as EcoCompanion
		if eco != null and eco.is_shown() and room.has_point(eco.global_position):
			out.append([((eco.global_position - global_position) / cell).floor(), float(_config.get("eco_light_px", 112))])
	for node: Node in get_tree().get_nodes_in_group(PowerSwitch.GROUP):
		var sw := node as PowerSwitch
		if sw != null and sw.is_revealed() and not sw.is_activated() and room.has_point(sw.get_hit_rect().get_center()):
			out.append([((sw.get_hit_rect().get_center() - global_position) / cell).floor(),
				float(_config.get("switch_light_px", 48))])
	return out


func _draw() -> void:
	var t: float = World1ObjectsConfig.tile_size()
	var size := Vector2(width_tiles * t, height_tiles * t)
	_drawn_alpha = get_veil_alpha()
	_drawn_intensity = DebugMode.get_intensity()
	var color := Color.html(String(_config.get("color", "#05070f")))
	color.a = _drawn_alpha
	_drawn_lights = get_lights()
	if _drawn_alpha > 0.0 and _drawn_lights.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), color)
	elif _drawn_alpha > 0.0:
		_draw_lit_veil(size, color)
	if _drawn_intensity <= 0.0 or _light >= 1.0:
		return
	var outline := Color.html(String(_config.get("outline_color", "#3dfff5")))
	outline.a = _drawn_intensity
	var dash: float = float(_config.get("dash_px", 4))
	for item: Node2D in get_outlined_nodes():
		var r: Rect2 = _outline_rect(item)
		r.position -= global_position
		_dashed_rect(r.grow(2.0), outline, dash)


## Velo por celdas de cell_px con la opacidad rebajada en anillos alrededor de
## cada luz (light_steps escalones hasta light_min de la opacidad).
func _draw_lit_veil(size: Vector2, color: Color) -> void:
	var cell: float = float(_config.get("cell_px", 16))
	var steps: int = maxi(int(_config.get("light_steps", 3)), 1)
	var lowest: float = float(_config.get("light_min", 0.25))
	var cols: int = ceili(size.x / cell)
	var rows: int = ceili(size.y / cell)
	for row: int in rows:
		var run_start: int = 0
		var run_factor: float = -1.0
		for col: int in cols + 1:
			var factor: float = -2.0
			if col < cols:
				factor = 1.0
				var center := Vector2((col + 0.5) * cell, (row + 0.5) * cell)
				for light: Array in _drawn_lights:
					var at: Vector2 = (light[0] as Vector2) * cell + Vector2(cell, cell) * 0.5
					var d: float = center.distance_to(at) / maxf(float(light[1]), 1.0)
					if d < 1.0:
						var step: int = floori(d * steps)
						factor = minf(factor, lerpf(lowest, 1.0, float(step) / steps))
			if factor != run_factor:
				if run_factor >= 0.0 and col > run_start:
					var c := color
					c.a = color.a * run_factor
					draw_rect(Rect2(run_start * cell, row * cell, (col - run_start) * cell, cell)
						.intersection(Rect2(Vector2.ZERO, size)), c)
				run_start = col
				run_factor = factor


func _outline_rect(item: Node2D) -> Rect2:
	if item.has_method(&"get_outline_rect"):
		return item.call(&"get_outline_rect")
	if item.has_method(&"get_hit_rect"):
		return item.call(&"get_hit_rect")
	return Rect2(item.global_position, Vector2(64, 64))


func _dashed_rect(r: Rect2, color: Color, dash: float) -> void:
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i: int in 4:
		var a: Vector2 = corners[i].round()
		var b: Vector2 = corners[(i + 1) % 4].round()
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(length, 0.001)
		var d: float = 0.0
		while d < length:
			draw_line(a + dir * d, a + dir * minf(d + dash, length), color, 2.0)
			d += dash * 2.0
