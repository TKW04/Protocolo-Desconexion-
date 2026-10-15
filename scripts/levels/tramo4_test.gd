## Escena de prueba del Tramo 4 y el Cierre del 1-1 (no es el nivel): Isak, un
## pop-up bloqueante (mismos params que data/levels/1-1.json), la puerta de
## salida "Marcar como leído", dos puntos de atencion, el HUD y el suelo. Al
## cruzar la puerta muestra la pantalla provisional de regreso al hub; con
## salto (jump) se recarga la escena. Desbloquea el pulso mientras esta
## abierta y lo restaura al salir.
extends Node2D

const ObjectsTest = preload("res://scripts/levels/world1_objects_test.gd")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub_placeholder.tscn")

## '#' solido, '.' vacio. 32 x 12 tiles; suelo arriba en la fila 10 (y = 640),
## como en el 1-1.
const GRID: Array[String] = [
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"################################",
	"################################",
]

@export var world: int = 1

var _pulse_was_unlocked: bool = false
var _hub: HubPlaceholder

@onready var _isak: Isak = $Isak
@onready var _tiles: TileMapLayer = $Tiles


func _ready() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.current_world = world
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	ObjectsTest.paint_tiles(_tiles, GRID)
	var camera: Camera2D = _isak.get_node(^"Camera2D") as Camera2D
	var t: int = int(World1ObjectsConfig.tile_size())
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID[0].length() * t
	camera.limit_bottom = GRID.size() * t
	EventBus.level_completed.connect(_on_level_completed)


func _exit_tree() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)


func get_hub() -> HubPlaceholder:
	return _hub


func _on_level_completed(level_id: String) -> void:
	if _hub != null:
		return
	_hub = HUB_SCENE.instantiate() as HubPlaceholder
	add_child(_hub)
	_hub.show_result(level_id, GameState.attention_points)
	_hub.restart_requested.connect(_on_restart_requested)


func _on_restart_requested(_level_id: String) -> void:
	get_tree().reload_current_scene.call_deferred()
