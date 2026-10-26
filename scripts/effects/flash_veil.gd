## Ceguera del flash del Influencer bot (2026-10-26, paso 5 de
## docs/propuesta-mundo-3.md §8, §3.6 y decision 6 de §9). Un solo velo por
## nivel (nodo «FlashVeil» del GeneratedLevel o, sin nivel, del padre de quien
## dispara), en coordenadas del mundo y con el z de los pop-ups translucidos
## (OverlayPopup: por encima del mundo, por debajo de la interfaz):
## - rectangulo blanco que cubre la vista de la camara al `peak` (0,7; 0,4 con
##   «Reducir efectos») durante hold_s y que se desvanece en fade_s;
## - encima, el contorno de lo que dana (outline_color, alerta_sombra): pinchos
##   (grupo hazard) y enemigos peligrosos (grupo enemy con is_dangerous(): su
##   get_damage_rect(), sus get_shots() o su get_body_rect()).
## Sin dano: solo tapa la vista. Tiempo del mundo (el Debug lo ralentiza). Se
## quita al reaparecer Isak. Otro flash con el velo puesto lo vuelve a llenar.
class_name FlashVeil
extends Node2D

const NODE_NAME: String = "FlashVeil"

var _peak: float = 0.0
var _hold_left: float = 0.0
var _fade_s: float = 0.5
var _fade_left: float = 0.0
var _color: Color = Color.WHITE
var _outline_color: Color = Color.RED
var _outline_px: float = 3.0


## Velo del nivel de `from` (lo crea si no existe).
static func for_node(from: Node) -> FlashVeil:
	var host: Node = _host_of(from)
	var existing := host.get_node_or_null(NODE_NAME) as FlashVeil
	if existing != null:
		return existing
	var veil := FlashVeil.new()
	veil.name = NODE_NAME
	host.add_child(veil)
	return veil


## Velo ya creado en el nivel de `from` (null si nunca hubo flash).
static func find(from: Node) -> FlashVeil:
	return _host_of(from).get_node_or_null(NODE_NAME) as FlashVeil


static func _host_of(from: Node) -> Node:
	var node: Node = from
	while node != null:
		if node is GeneratedLevel:
			return node
		node = node.get_parent()
	return from.get_parent() if from.get_parent() != null else from


func _ready() -> void:
	EventBus.player_respawned.connect(_on_player_respawned)
	set_process(true)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Ciega: `peak` de opacidad durante hold_s y se desvanece en fade_s.
func blind(peak: float, hold_s: float, fade_s: float, color: Color, outline_color: Color,
		outline_px: float, z: int) -> void:
	_peak = clampf(peak, 0.0, 1.0)
	_hold_left = maxf(hold_s, 0.0)
	_fade_s = maxf(fade_s, 0.001)
	_fade_left = _fade_s
	_color = color
	_outline_color = outline_color
	_outline_px = outline_px
	z_as_relative = false
	z_index = z
	queue_redraw()


## Avanza `dt` segundos de tiempo del mundo (publico para las pruebas).
func advance(dt: float) -> void:
	if not is_active():
		return
	dt = maxf(dt, 0.0)
	if _hold_left > 0.0:
		var used: float = minf(dt, _hold_left)
		_hold_left -= used
		dt -= used
	if _hold_left <= 0.0:
		_fade_left = maxf(_fade_left - dt, 0.0)
	queue_redraw()


func clear() -> void:
	_hold_left = 0.0
	_fade_left = 0.0
	queue_redraw()


func is_active() -> bool:
	return _hold_left > 0.0 or _fade_left > 0.0


## Opacidad actual del velo (0 = sin velo).
func get_alpha() -> float:
	if _hold_left > 0.0:
		return _peak
	return _peak * clampf(_fade_left / _fade_s, 0.0, 1.0)


func get_peak() -> float:
	return _peak


## Rectangulos (globales) de lo que dana ahora mismo: el contorno que conserva.
func get_danger_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	var level: Node = get_parent()
	for node: Node in get_tree().get_nodes_in_group(&"hazard"):
		if level != null and not level.is_ancestor_of(node):
			continue
		for child: Node in node.get_children():
			var cs := child as CollisionShape2D
			if cs != null and cs.shape is RectangleShape2D and not cs.disabled:
				var size: Vector2 = (cs.shape as RectangleShape2D).size
				out.append(Rect2(cs.global_position - size * 0.5, size))
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if level != null and not level.is_ancestor_of(node):
			continue
		if not node.has_method(&"is_dangerous") or not bool(node.call(&"is_dangerous")):
			continue
		if node.has_method(&"get_damage_rect"):
			out.append(node.call(&"get_damage_rect"))
		elif node.has_method(&"get_shots"):
			for shot: Variant in node.call(&"get_shots"):
				if shot is Node2D and (shot as Node2D).has_method(&"get_damage_rect"):
					out.append((shot as Node2D).call(&"get_damage_rect"))
		elif node.has_method(&"get_body_rect"):
			out.append(node.call(&"get_body_rect"))
	return out


func _draw() -> void:
	var alpha: float = get_alpha()
	if alpha <= 0.0:
		return
	var inv: Transform2D = get_global_transform().affine_inverse()
	var view: Rect2 = get_viewport_rect()
	var canvas_inv: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var top_left: Vector2 = inv * (canvas_inv * view.position)
	var bottom_right: Vector2 = inv * (canvas_inv * view.end)
	draw_rect(Rect2(top_left, bottom_right - top_left).grow(64.0), Color(_color, alpha))
	# El contorno de lo que dana se ve entero mientras haya velo.
	for rect: Rect2 in get_danger_rects():
		var local := Rect2(inv * rect.position, rect.size)
		draw_rect(local.grow(_outline_px * 0.5), _outline_color, false, _outline_px)


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	clear()
