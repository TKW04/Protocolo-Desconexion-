## Escena de prueba de la Burbuja de alerta (no es un nivel del juego; el 1-1
## llega en el paso 14). Suelo del Mundo 1, una repisa de 2 tiles para caer
## sobre la Burbuja aturdida, una Burbuja patrullando, Isak, HUD y el fondo del
## mundo. Como la sandbox del Debug: desbloquea el pulso (J) y el Debug (mantener
## K) con energia 100 para ver la ralentizacion x0,5 de la Burbuja, y los
## restaura al salir. Si la Burbuja revienta, aparece otra al rato.
extends Node2D

const World1Test = preload("res://scripts/levels/world1_objects_test.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")

## '#' solido, '.' vacio. 32 x 12 tiles, suelo en y = 576.
const GRID: Array[String] = [
	"................................",
	"................................",
	"................................",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#.........##...................#",
	"#.........##...................#",
	"################################",
	"################################",
	"################################",
]

## Si Isak cae por debajo de esta Y vuelve al punto de inicio.
@export var fall_limit_y: float = 960.0
@export var world: int = 1
## Segundos (reales) hasta que reaparece una Burbuja reventada.
@export var respawn_s: float = 2.0

var _spawn_position: Vector2
var _bubble_position: Vector2
var _bubble_range: float
var _pulse_was_unlocked: bool = false
var _debug_was_unlocked: bool = false

@onready var _isak: Isak = $Isak
@onready var _tiles: TileMapLayer = $Tiles


func _ready() -> void:
	_spawn_position = _isak.global_position
	var bubble: AlertBubble = $AlertBubble
	_bubble_position = bubble.global_position
	_bubble_range = bubble.patrol_range_px
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_debug_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.current_world = world
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	World1Test.paint_tiles(_tiles, GRID)
	var camera: Camera2D = _isak.get_node(^"Camera2D") as Camera2D
	var t: int = int(World1ObjectsConfig.tile_size())
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID[0].length() * t
	camera.limit_bottom = GRID.size() * t
	EventBus.enemy_defeated.connect(_on_enemy_defeated)


func _exit_tree() -> void:
	DebugMode.reset()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was_unlocked)


func _physics_process(_delta: float) -> void:
	if _isak.global_position.y > fall_limit_y:
		_isak.global_position = _spawn_position
		_isak.velocity = Vector2.ZERO


func _on_enemy_defeated(enemy: Node2D) -> void:
	if not enemy is AlertBubble or not is_ancestor_of(enemy):
		return
	await get_tree().create_timer(respawn_s).timeout
	if not is_inside_tree():
		return
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.position = _bubble_position
	bubble.patrol_range_px = _bubble_range
	add_child(bubble)
