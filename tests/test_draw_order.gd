# Orden de dibujo del 1-1 (scenes/levels/1-1.tscn): el fondo parallax del
# Mundo 1 queda siempre por debajo de todo el lienzo del mundo (tiles, pinchos,
# objetos, enemigos e Isak), y nada del lienzo del mundo se dibuja encima de
# Isak salvo sus propios hijos (p. ej. la onda del pulso). La UI va en
# CanvasLayer propios y no cuenta.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")

var _level: GeneratedLevel
var _items: Array[CanvasItem] = []


func before_each() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	add_child(_level)
	await wait_physics_frames(2)
	_items.clear()
	_collect(_level)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null


func test_background_is_below_every_world_item() -> void:
	var background: Node = _level.get_node(^"Background")
	var bg_max: int = RenderingServer.CANVAS_ITEM_Z_MIN
	var others_min: int = RenderingServer.CANVAS_ITEM_Z_MAX
	for item: CanvasItem in _items:
		if _in_canvas_layer(item):
			continue
		var z: int = _effective_z(item)
		if item == background or background.is_ancestor_of(item):
			bg_max = maxi(bg_max, z)
		else:
			others_min = mini(others_min, z)
	assert_lt(bg_max, others_min, "el fondo (z %d) debe quedar por debajo de todo el mundo (z min %d)" % [bg_max, others_min])


func test_nothing_in_world_draws_over_isak() -> void:
	var isak: Node = _level.get_node(^"Isak")
	var sprite: CanvasItem = _level.get_node(^"Isak/AnimatedSprite2D")
	var sprite_z: int = _effective_z(sprite)
	var sprite_index: int = _items.find(sprite)
	var over: PackedStringArray = []
	for i: int in _items.size():
		var item: CanvasItem = _items[i]
		if _in_canvas_layer(item) or item == isak or isak.is_ancestor_of(item):
			continue
		var z: int = _effective_z(item)
		if z > sprite_z or (z == sprite_z and i > sprite_index):
			over.append(String(_level.get_path_to(item)))
	assert_eq(over.size(), 0, "se dibujan encima de Isak: %s" % ", ".join(over))


## Recorrido en preorden = orden de dibujo a igual z.
func _collect(node: Node) -> void:
	if node is CanvasLayer:
		return
	if node is CanvasItem:
		_items.append(node as CanvasItem)
	for child: Node in node.get_children(true):
		_collect(child)


func _in_canvas_layer(item: Node) -> bool:
	var node: Node = item.get_parent()
	while node != null and node != _level:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false


func _effective_z(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		var ci := node as CanvasItem
		z += ci.z_index
		if not ci.z_as_relative:
			break
		node = node.get_parent()
	return z
