# Carteles del feed (FeedSign) y su orden de dibujo (2026-10-23, paso 12 de
# docs/propuesta-mundo-2.md §8.1): en el 2-1 el cartel «Reproduccion automatica:
# siempre» (2 filas) tenia la tarjeta de una via de su segunda fila cruzandole el
# texto: el terreno (z 0) se dibuja encima del cartel (z -1, detras de Isak y de
# los objetos). Subir el cartel por encima del terreno taparia la tarjeta en la
# que se apoya Isak, asi que el arreglo es de colocacion: en cada nivel del Mundo 2
# ningun cartel pisa una celda de terreno ni una tarjeta del feed, y el cartel queda
# por encima del fondo y por debajo de los objetos y de Isak. El Mundo 1 no tiene
# carteles del feed.
extends GutTest

const LEVELS_DIR: String = "res://data/levels"


## Niveles del Mundo 2 con carteles: [id] (escena scenes/levels/<id>.tscn).
func _world2_levels_with_signs() -> PackedStringArray:
	var out: PackedStringArray = []
	for file: String in DirAccess.get_files_at(LEVELS_DIR):
		if not file.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_DIR.path_join(file)))
		if not data is Dictionary or int((data as Dictionary).get("world", 1)) != 2:
			continue
		for obj: Variant in (data as Dictionary).get("objects", []):
			if obj is Dictionary and String((obj as Dictionary).get("type", "")) == "feed_sign":
				out.append(file.get_basename())
				break
	return out


## Un nivel por vez, liberado aqui y en after_each: cada GeneratedLevel desbloquea
## sus habilidades al entrar y devuelve las anteriores al salir; con varios vivos a
## la vez liberados por el autofree (despues de after_each) quedaban pulso, laser,
## Debug y dash desbloqueados para los scripts siguientes (2026-10-23, paso 21 de
## docs/propuesta-mundo-2.md: fallaba test_help_inert en la suite completa).
var _level: Node2D


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null


func _load_level(id: String) -> Node2D:
	if is_instance_valid(_level):
		_level.free()
	_level = (load("res://scenes/levels/%s.tscn" % id) as PackedScene).instantiate()
	add_child(_level)
	return _level


func _signs(level: Node) -> Array[FeedSign]:
	var out: Array[FeedSign] = []
	for node: Node in level.get_node(^"Objects").get_children():
		if node is FeedSign:
			out.append(node as FeedSign)
	return out


func _sign_rect(sign: FeedSign) -> Rect2:
	var local: Rect2 = sign.get_card_rect()
	return Rect2(sign.global_position + local.position, local.size)


func _absolute_z(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z


func test_the_2_1_has_signs() -> void:
	assert_has(_world2_levels_with_signs(), "2-1", "el 2-1 lleva carteles del feed")


func test_no_sign_overlaps_terrain_or_feed_cards() -> void:
	for id: String in _world2_levels_with_signs():
		var level := _load_level(id)
		var tiles := level.get_node(^"Tiles") as TileMapLayer
		var tile: Vector2 = Vector2(tiles.tile_set.tile_size)
		var signs := _signs(level)
		assert_gt(signs.size(), 0, "%s: carteles en Objects" % id)
		for sign: FeedSign in signs:
			var rect: Rect2 = _sign_rect(sign).grow(-1.0)
			var hits: PackedStringArray = []
			for cell: Vector2i in tiles.get_used_cells():
				if rect.intersects(Rect2(Vector2(cell) * tile, tile)):
					hits.append(str(cell))
			# Tarjetas del feed con rectangulo global: frágiles, Historias y videos.
			var cards: Array[Node] = level.get_node(^"Objects").get_children()
			cards.append_array(level.get_node(^"Enemies").get_children())
			for node: Node in cards:
				if node is FragileCard or node is StoryCard or node is AutoplayVideo:
					if rect.intersects(node.call(&"get_card_rect")):
						hits.append(String(node.name))
			assert_eq(hits.size(), 0, "%s: el cartel %s no pisa terreno ni tarjetas (pisa %s)" % [id, sign.object_id, hits])


func test_signs_draw_above_the_background_and_below_objects() -> void:
	for id: String in _world2_levels_with_signs():
		var level := _load_level(id)
		var background := level.get_node(^"Background") as CanvasItem
		var tiles := level.get_node(^"Tiles") as CanvasItem
		for sign: FeedSign in _signs(level):
			var z: int = _absolute_z(sign)
			assert_gt(z, _absolute_z(background), "%s: %s por encima del fondo" % [id, sign.object_id])
			assert_lt(z, _absolute_z(tiles), "%s: %s detras del terreno y de Isak" % [id, sign.object_id])
