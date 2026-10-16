## Cable del lector laser a su receptor enlazado (docs/propuesta-1-2.md §4.2:
## «el cable de circuito ... se ilumina en cian y empieza a vaciarse»). Hijo de
## LaserReceiver; lo dibuja con las piezas de 16 px de
## assets/sprites/puzzle_objects_frames.tres (tools/gen_world1_puzzle.py):
## - Recorrido: salida del lector -> centros de cable_cells -> entrada del
##   receptor (RelayReceiver.get_cable_port); dos puntos no alineados se unen
##   en L (primero en horizontal). Nodos en las esquinas y en los extremos.
## - Sin corriente: cable_off. Con corriente: cable_lit con un trazo que corre
##   hacia el receptor (el flujo de corriente) y que SE VACIA: solo queda
##   encendido el tramo final (del lado del receptor) proporcional al tiempo
##   que queda; los ultimos warn_s segundos ese tramo parpadea con cable_dim
##   (aviso). Hecho (receptor activado): todo encendido para siempre.
## Tiempo del mundo (lo avanza el lector).
class_name LaserCable
extends Node2D

const PIECE_PX: float = 16.0

var reader: LaserReceiver

var _frames: SpriteFrames
var _time: float = 0.0
var _relay: Node2D
var _config: Dictionary = World1ObjectsConfig.section("laser_receiver")


func _ready() -> void:
	_frames = load(String(_config.get("frames", ""))) as SpriteFrames
	z_index = int(_config.get("cable_z_index", 0))


func advance(dt: float) -> void:
	_time += dt
	if reader != null and reader.get_state() != LaserReceiver.State.READY:
		queue_redraw()


## Receptor enlazado (RelayReceiver con object_id == reader.target_id) o null.
func get_relay() -> Node2D:
	if _relay != null and is_instance_valid(_relay):
		return _relay
	if reader == null or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(RelayReceiver.GROUP):
		if node is RelayReceiver and (node as RelayReceiver).object_id == reader.target_id:
			_relay = node as Node2D
			return _relay
	return null


## Puntos del recorrido en coordenadas globales (salida, esquinas, entrada).
func get_global_points() -> PackedVector2Array:
	var raw: Array[Vector2] = []
	if reader == null:
		return PackedVector2Array()
	raw.append(reader.get_cable_port())
	var t: float = World1ObjectsConfig.tile_size()
	for cell: Variant in reader.cable_cells:
		var v: Vector2 = cell if cell is Vector2 else LaserReceiver._vec(cell)
		raw.append((v + Vector2(0.5, 0.5)) * t)
	var relay := get_relay() as RelayReceiver
	if relay != null:
		raw.append(relay.get_cable_port())
	var out := PackedVector2Array()
	for p: Vector2 in raw:
		if not out.is_empty():
			var last: Vector2 = out[out.size() - 1]
			if not is_equal_approx(last.x, p.x) and not is_equal_approx(last.y, p.y):
				out.append(Vector2(p.x, last.y))
		if out.is_empty() or not out[out.size() - 1].is_equal_approx(p):
			out.append(p)
	return out


## Longitud total del recorrido (px).
func get_length() -> float:
	var pts := get_global_points()
	var total: float = 0.0
	for i: int in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## Longitud encendida ahora (del lado del receptor).
func get_lit_length() -> float:
	if reader == null:
		return 0.0
	match reader.get_state():
		LaserReceiver.State.DONE:
			return get_length()
		LaserReceiver.State.POWERED:
			return get_length() * reader.get_power_fraction()
	return 0.0


## En el parpadeo del aviso (los ultimos warn_s), la mitad del tiempo apagado.
func is_blink_dim() -> bool:
	if reader == null or not reader.is_warning():
		return false
	var hz: float = maxf(float(_config.get("warn_blink_hz", 6.0)), 0.01)
	return int(floorf(_time * hz * 2.0)) % 2 == 1


func _draw() -> void:
	if _frames == null or reader == null:
		return
	var pts := get_global_points()
	if pts.size() < 2:
		return
	var total: float = get_length()
	var lit_from: float = total - get_lit_length()
	var dim: bool = is_blink_dim()
	var lit_anim: StringName = &"cable_dim" if dim else &"cable_lit"
	var flow: int = int(floorf(_time * _frames.get_animation_speed(&"cable_lit"))) % _frames.get_frame_count(&"cable_lit")
	var traveled: float = 0.0
	for i: int in range(1, pts.size()):
		var a: Vector2 = to_local(pts[i - 1])
		var b: Vector2 = to_local(pts[i])
		var seg: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(seg, 0.001)
		var d: float = 0.0
		while d < seg - 0.01:
			var w: float = minf(PIECE_PX, seg - d)
			var lit: bool = traveled + d + w * 0.5 >= lit_from and lit_from < total
			var tex: Texture2D = _frames.get_frame_texture(lit_anim if lit else &"cable_off",
				flow if lit and not dim else 0)
			draw_set_transform(a + dir * d, dir.angle())
			draw_texture_rect_region(tex, Rect2(0.0, -PIECE_PX * 0.5, w, PIECE_PX), Rect2(0.0, 0.0, w, PIECE_PX))
			d += w
		traveled += seg
	draw_set_transform(Vector2.ZERO, 0.0)
	traveled = 0.0
	for i: int in pts.size():
		if i > 0:
			traveled += pts[i - 1].distance_to(pts[i])
		var on: bool = traveled >= lit_from - 0.01 and lit_from < total and not dim
		var node_tex: Texture2D = _frames.get_frame_texture(&"cable_node_on" if on else &"cable_node_off", 0)
		draw_texture(node_tex, (to_local(pts[i]) - Vector2.ONE * PIECE_PX * 0.5).round())
