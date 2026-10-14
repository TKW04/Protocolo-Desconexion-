## Escena de prueba del cuadro de texto de Eco (no es un nivel del juego):
## Isak cae al mundo dentro de la zona eco_line (como en el Tramo 1 del 1-1) y
## Eco dice su primera frase (docs 6.3). Mas a la derecha, una segunda zona con
## otra frase de Eco del documento (12.1, humor) para probar el ajuste de linea.
## Isak se puede mover mientras habla Eco. Desbloquea el Debug mientras esta
## abierta (K: el mundo se ralentiza, el cuadro no) y lo restaura al salir.
## Los tiles se pintan con la logica de la escena de objetos del Mundo 1.
## Captura: con el argumento de usuario --eco-demo-walk (Godot ... -- --eco-demo-walk)
## Isak camina solo a la derecha hasta la segunda zona (accion move_right).
extends Node2D

const DEMO_WALK_ARG: String = "--eco-demo-walk"
const ACTION_RIGHT: StringName = &"move_right"

const ObjectsTest = preload("res://scripts/levels/world1_objects_test.gd")

## '#' solido, '.' vacio. 32 x 12 tiles.
const GRID: Array[String] = [
	"................................",
	"................................",
	"................................",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"################################",
	"################################",
	"################################",
]

## Si Isak cae por debajo de esta Y vuelve al punto de inicio.
@export var fall_limit_y: float = 960.0
@export var world: int = 1
## Demo de captura: segundos antes de empezar a caminar y X donde se detiene.
@export var demo_walk_delay_s: float = 1.5
@export var demo_walk_stop_x: float = 1344.0

var _spawn_position: Vector2
var _debug_was_unlocked: bool = false
var _demo_walk: bool = false
var _demo_time: float = 0.0

@onready var _isak: Isak = $Isak
@onready var _tiles: TileMapLayer = $Tiles


func _ready() -> void:
	_spawn_position = _isak.global_position
	_debug_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.current_world = world
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	ObjectsTest.paint_tiles(_tiles, GRID)
	var camera: Camera2D = _isak.get_node(^"Camera2D") as Camera2D
	var t: int = int(World1ObjectsConfig.tile_size())
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID[0].length() * t
	camera.limit_bottom = GRID.size() * t
	_demo_walk = DEMO_WALK_ARG in OS.get_cmdline_user_args()


func _exit_tree() -> void:
	if _demo_walk:
		Input.action_release(ACTION_RIGHT)
	DebugMode.reset()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was_unlocked)


func _physics_process(delta: float) -> void:
	if _demo_walk:
		_demo_time += delta
		var walking: bool = _demo_time >= demo_walk_delay_s and _isak.global_position.x < demo_walk_stop_x
		if walking:
			Input.action_press(ACTION_RIGHT)
		else:
			Input.action_release(ACTION_RIGHT)
	if _isak.global_position.y > fall_limit_y:
		_isak.global_position = _spawn_position
		_isak.velocity = Vector2.ZERO
