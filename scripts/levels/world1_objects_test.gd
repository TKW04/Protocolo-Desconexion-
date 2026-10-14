## Escena de prueba de los objetos del Mundo 1 (no es un nivel del juego):
## fondo de relojes con parallax, un receptor en el borde de un hueco de 5
## tiles (no se puede saltar), el puente retraido que se extiende al activar el
## receptor con el pulso (J) y la pared con glitch en la cara de un muro.
## Los tiles se colocan desde GRID con las reglas de data/tileset_mundo1.json
## (misma logica que select_tile de tools/gen_tileset_mundo1.py). Si Isak cae
## al hueco vuelve al inicio. Desbloquea el pulso y el Debug mientras esta
## abierta (K para ver el tinte sobre el fondo) y los restaura al salir.
extends Node2D

## '#' solido, '.' vacio, 'g' pared con glitch (cuenta como solido para los
## bordes del tileset pero la dibuja GlitchWall). 32 x 12 tiles.
const GRID: Array[String] = [
	"................................",
	"................................",
	"................................",
	"#...............................",
	"#.....................##########",
	"#.....................##########",
	"#.....................##########",
	"#.....................g#########",
	"#.....................g#########",
	"###########.....################",
	"###########.....################",
	"###########.....################",
]
const TILE_MAP_PATH: String = "res://data/tileset_mundo1.json"

## Si Isak cae por debajo de esta Y vuelve al punto de inicio.
@export var fall_limit_y: float = 960.0
@export var world: int = 1

var _spawn_position: Vector2
var _pulse_was_unlocked: bool = false
var _debug_was_unlocked: bool = false

@onready var _isak: Isak = $Isak
@onready var _tiles: TileMapLayer = $Tiles


func _ready() -> void:
	_spawn_position = _isak.global_position
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_debug_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.current_world = world
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	paint_tiles(_tiles, GRID)
	var camera: Camera2D = _isak.get_node(^"Camera2D") as Camera2D
	var t: int = int(World1ObjectsConfig.tile_size())
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID[0].length() * t
	camera.limit_bottom = GRID.size() * t


func _exit_tree() -> void:
	DebugMode.reset()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was_unlocked)


func _physics_process(_delta: float) -> void:
	if _isak.global_position.y > fall_limit_y:
		_isak.global_position = _spawn_position
		_isak.velocity = Vector2.ZERO


## Pinta '#' con los tiles del Mundo 1 segun sus vecinos ('g' cuenta como solido).
static func paint_tiles(layer: TileMapLayer, grid: Array[String]) -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TILE_MAP_PATH))
	layer.tile_set = load(String(m["tileset"])) as TileSet
	var sid: int = int(m["source_id"])
	for r: int in grid.size():
		for c: int in grid[r].length():
			if grid[r][c] == "#":
				layer.set_cell(Vector2i(c, r), sid, _select_solid(grid, r, c, m))


static func _select_solid(grid: Array[String], r: int, c: int, m: Dictionary) -> Vector2i:
	var solid := func(dr: int, dc: int) -> bool:
		var rr: int = r + dr
		var cc: int = c + dc
		if rr < 0 or rr >= grid.size() or cc < 0 or cc >= grid[rr].length():
			return bool(m["outside_is_solid"])
		return grid[rr][cc] == "#" or grid[rr][cc] == "g"
	var mask: int = (1 if solid.call(-1, 0) else 0) | (2 if solid.call(0, 1) else 0) \
		| (4 if solid.call(1, 0) else 0) | (8 if solid.call(0, -1) else 0)
	var key: Array
	if mask == 15:
		var diag: int = (0 if solid.call(-1, 1) else 1) | (0 if solid.call(1, 1) else 2) \
			| (0 if solid.call(1, -1) else 4) | (0 if solid.call(-1, -1) else 8)
		if diag == 0 and (r * 7 + c * 3) % int(m["solid"]["alt_every"]) == 0:
			key = m["solid"]["interior_alt"]
		else:
			key = m["solid"]["interior_by_diag"][str(diag)]
	else:
		key = m["solid"]["by_mask"][str(mask)]
	return Vector2i(int(key[0]), int(key[1]))
