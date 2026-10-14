# Pruebas del TileSet del Mundo 1 (assets/tilesets/mundo1.tres, construido por
# tools/build_tileset_mundo1.gd desde data/tileset_mundo1.json): tamano de 64,
# capas de fisica y de datos, colision de solidos, one_way en la plataforma de
# una via, pinchos sin colision y con hazard; e Isak sobre un TileMapLayer
# creado aqui (se apoya en el suelo, atraviesa la plataforma de una via desde
# abajo y la pisa desde arriba).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const MAP_PATH: String = "res://data/tileset_mundo1.json"
const DT: float = 1.0 / 60.0
const POSITION_TOLERANCE: float = 1.0
const PHYSICS_LAYER: int = 0
## Ancho del suelo de prueba (tiles) y fila de la plataforma de una via
## (2 tiles por encima del suelo: 128 px, menos que el salto de 192 px).
const FLOOR_TILES: int = 12
const ONE_WAY_ROW: int = -2
const ONE_WAY_FIRST: int = 3
const ONE_WAY_LAST: int = 6

var _map: Dictionary
var _tileset: TileSet
var _source: TileSetAtlasSource


func before_all() -> void:
	_map = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	_tileset = load(_map["tileset"]) as TileSet
	_source = _tileset.get_source(int(_map["source_id"])) as TileSetAtlasSource


func _coords(entry: Dictionary) -> Vector2i:
	return Vector2i(int(entry["atlas"][0]), int(entry["atlas"][1]))


func _atlas(key: Array) -> Vector2i:
	return Vector2i(int(key[0]), int(key[1]))


func _data(coords: Vector2i) -> TileData:
	return _source.get_tile_data(coords, 0)


# --- Recurso ---

func test_tileset_loads_with_64_px_tiles() -> void:
	assert_not_null(_tileset, "Carga el TileSet")
	assert_eq(_tileset.tile_size, Vector2i(64, 64))
	assert_not_null(_source, "Tiene la fuente de atlas")
	assert_eq(_source.texture_region_size, Vector2i(64, 64))
	assert_eq(_source.texture.resource_path, String(_map["atlas_png"]))
	assert_eq(_source.texture.get_size(), Vector2(int(_map["columns"]) * 64, int(_map["rows"]) * 64))


func test_layers_exist() -> void:
	assert_eq(_tileset.get_physics_layers_count(), 1, "Capa de fisica")
	assert_ne(_tileset.get_custom_data_layer_by_name("kind"), -1, "Custom data 'kind'")
	assert_ne(_tileset.get_custom_data_layer_by_name("hazard"), -1, "Custom data 'hazard'")


func test_every_mapped_tile_exists_with_its_kind() -> void:
	for entry: Dictionary in _map["tiles"]:
		var coords: Vector2i = _coords(entry)
		assert_true(_source.has_tile(coords), "Existe %s" % entry["name"])
		assert_eq(_data(coords).get_custom_data("kind"), entry["kind"], entry["name"])


func test_solid_tiles_have_full_collision() -> void:
	var count: int = 0
	for entry: Dictionary in _map["tiles"]:
		if entry["kind"] != "solid":
			continue
		count += 1
		var data: TileData = _data(_coords(entry))
		assert_eq(data.get_collision_polygons_count(PHYSICS_LAYER), 1, entry["name"])
		assert_false(data.is_collision_polygon_one_way(PHYSICS_LAYER, 0), entry["name"])
		var points: PackedVector2Array = data.get_collision_polygon_points(PHYSICS_LAYER, 0)
		var box := Rect2(points[0], Vector2.ZERO)
		for p: Vector2 in points:
			box = box.expand(p)
		assert_eq(box.size, Vector2(64, 64), "Colision de tile completo: %s" % entry["name"])
	assert_gt(count, 16, "Bloques solidos")


func test_one_way_platform_uses_one_way_collision() -> void:
	for key: String in ["left", "center", "right", "single"]:
		var data: TileData = _data(_atlas(_map["one_way"][key]))
		assert_eq(data.get_collision_polygons_count(PHYSICS_LAYER), 1, key)
		assert_true(data.is_collision_polygon_one_way(PHYSICS_LAYER, 0), "one_way_collision: %s" % key)


func test_spikes_are_hazard_without_solid_collision() -> void:
	for key: String in ["floor", "ceiling"]:
		var data: TileData = _data(_atlas(_map["spikes"][key]))
		assert_eq(data.get_collision_polygons_count(PHYSICS_LAYER), 0, "Sin colision: %s" % key)
		assert_eq(data.get_custom_data("hazard"), "spikes", key)
		assert_eq(data.get_custom_data("kind"), "hazard", key)


func test_decor_has_no_collision() -> void:
	for key: String in ["grid", "window"]:
		var data: TileData = _data(_atlas(_map["decor"][key]))
		assert_eq(data.get_collision_polygons_count(PHYSICS_LAYER), 0, key)
		assert_eq(data.get_custom_data("hazard"), "", key)


# --- Isak sobre un TileMapLayer ---

## Suelo de solidos con la superficie en y = 0 (fila 0) y una plataforma de una
## via en la fila ONE_WAY_ROW (superficie en y = -128). Isak en la columna 1.
func _build_world(sim: IsakSim) -> Node2D:
	var world := Node2D.new()
	var layer := TileMapLayer.new()
	layer.tile_set = _tileset
	var sid: int = int(_map["source_id"])
	var top: Vector2i = _atlas(_map["solid"]["by_mask"][str(2 | 4 | 8)])
	var inner: Vector2i = _atlas(_map["solid"]["interior_by_diag"]["0"])
	for x: int in FLOOR_TILES:
		layer.set_cell(Vector2i(x, 0), sid, top)
		layer.set_cell(Vector2i(x, 1), sid, inner)
	for x: int in range(ONE_WAY_FIRST, ONE_WAY_LAST + 1):
		var key: String = "left" if x == ONE_WAY_FIRST else "right" if x == ONE_WAY_LAST else "center"
		layer.set_cell(Vector2i(x, ONE_WAY_ROW), sid, _atlas(_map["one_way"][key]))
	world.add_child(layer)
	var isak: Isak = IsakSim.ISAK_SCENE.instantiate() as Isak
	sim.attach(isak)
	isak.position = Vector2(1.5 * 64.0, -1.0)
	world.add_child(isak)
	return world


func test_isak_stands_and_walks_on_tiles() -> void:
	var sim := IsakSim.new(DT)
	add_child_autofree(_build_world(sim))
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	assert_true(sim.isak.is_on_floor(), "Se apoya en el suelo de tiles")
	assert_almost_eq(sim.isak.global_position.y, 0.0, POSITION_TOLERANCE)
	var x0: float = sim.isak.global_position.x
	sim.input.move_axis = 1.0
	sim.step(30)
	assert_true(sim.isak.is_on_floor(), "Sigue en el suelo al caminar (sin tropezar en las juntas)")
	assert_almost_eq(sim.isak.global_position.y, 0.0, POSITION_TOLERANCE)
	assert_gt(sim.isak.global_position.x, x0 + 64.0, "Avanza")


func test_one_way_platform_passes_from_below_and_holds_from_above() -> void:
	var sim := IsakSim.new(DT)
	add_child_autofree(_build_world(sim))
	sim.isak.position = Vector2((ONE_WAY_FIRST + 1.5) * 64.0, -1.0)
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	assert_almost_eq(sim.isak.global_position.y, 0.0, POSITION_TOLERANCE, "Empieza bajo la plataforma")
	var surface: float = ONE_WAY_ROW * 64.0
	sim.input.jump_pressed = true
	sim.input.jump_held = true
	sim.step()
	# Mantiene saltar para el salto completo: sube atravesando la plataforma.
	var min_y: float = sim.isak.global_position.y
	for i: int in sim.steps_for(1.0):
		min_y = minf(min_y, sim.isak.global_position.y)
		sim.input.jump_held = true
		sim.step()
		if sim.isak.is_on_floor():
			break
	sim.input.jump_held = false
	assert_lt(min_y, surface, "La atraviesa desde abajo")
	sim.settle()
	assert_true(sim.isak.is_on_floor(), "Aterriza")
	assert_almost_eq(sim.isak.global_position.y, surface, POSITION_TOLERANCE, "Se queda encima de la plataforma")
