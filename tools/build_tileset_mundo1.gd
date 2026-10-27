## Genera res://assets/tilesets/mundo1.tres (TileSet de 64x64) desde el atlas
## assets/sprites/tiles/mundo1_tileset.png y el mapa data/tileset_mundo1.json
## (los dos salen de tools/gen_tileset_mundo1.py).
## - Capa de fisica 0: colision completa para los solidos; banda superior de
##   one_way_collision_height_px con one_way para la plataforma de una via;
##   pinchos y decorado sin colision (el peligro lo pone el generador de
##   niveles con un Area, paso 15).
## - Custom data: `kind` (solid, one_way, hazard, decor) y `hazard` ("spikes"
##   en los pinchos, "" en el resto).
## Requiere el PNG importado antes (Godot --headless --import).
## Uso: Godot --headless --path . -s tools/build_tileset_mundo1.gd [-- --map res://data/tileset_mundo3.json]
## (--map: otro mapa con el mismo formato, p. ej. el del Mundo 3 de tools/gen_world3_tiles.py; 2026-10-26).
extends SceneTree

const MAP_PATH: String = "res://data/tileset_mundo1.json"
const PHYSICS_LAYER: int = 0
const KIND_LAYER: String = "kind"
const HAZARD_LAYER: String = "hazard"
const KIND_SOLID: String = "solid"
const KIND_ONE_WAY: String = "one_way"


func _init() -> void:
	var map_path: String = MAP_PATH
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--map")
	if i >= 0 and i + 1 < args.size():
		map_path = args[i + 1]
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	var tileset: TileSet = build(map)
	var out: String = map["tileset"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var err: Error = ResourceSaver.save(tileset, out)
	if err != OK:
		push_error("build_tileset_mundo1: no se pudo guardar '%s' (%d)" % [out, err])
		quit(1)
		return
	print("build_tileset_mundo1: %s (%d tiles)" % [out, (map["tiles"] as Array).size()])
	quit(0)


static func build(map: Dictionary) -> TileSet:
	var size: int = int(map["tile_size"])
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(size, size)
	tileset.add_physics_layer()
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, KIND_LAYER)
	tileset.set_custom_data_layer_type(0, TYPE_STRING)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(1, HAZARD_LAYER)
	tileset.set_custom_data_layer_type(1, TYPE_STRING)

	var source := TileSetAtlasSource.new()
	source.texture = load(map["atlas_png"]) as Texture2D
	source.texture_region_size = Vector2i(size, size)
	tileset.add_source(source, int(map["source_id"]))

	var half: float = size * 0.5
	var full := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half),
			Vector2(-half, half)])
	var band: float = float(map["one_way_collision_height_px"])
	var top := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + band),
			Vector2(-half, -half + band)])
	for entry: Dictionary in map["tiles"]:
		var coords := Vector2i(int(entry["atlas"][0]), int(entry["atlas"][1]))
		source.create_tile(coords)
		var data: TileData = source.get_tile_data(coords, 0)
		var kind: String = entry["kind"]
		data.set_custom_data(KIND_LAYER, kind)
		data.set_custom_data(HAZARD_LAYER, String(entry["hazard"]))
		if kind == KIND_SOLID:
			data.add_collision_polygon(PHYSICS_LAYER)
			data.set_collision_polygon_points(PHYSICS_LAYER, 0, full)
		elif kind == KIND_ONE_WAY:
			data.add_collision_polygon(PHYSICS_LAYER)
			data.set_collision_polygon_points(PHYSICS_LAYER, 0, top)
			data.set_collision_polygon_one_way(PHYSICS_LAYER, 0, true)
	return tileset
