## Escena de prueba del Tramo 4 y el Cierre del 1-1 (no es el nivel): Isak, un
## pop-up bloqueante (mismos params que data/levels/1-1.json), la puerta de
## salida "Marcar como leído", dos puntos de atencion, el HUD y el suelo. Al
## cruzar la puerta (level_completed) se va al hub real (scenes/hub/hub.tscn,
## paso 9 de docs/propuesta-hub-y-guardado.md; antes, la pantalla provisional
## del hub, retirada). Desbloquea el pulso mientras esta abierta y lo restaura
## al salir.
extends Node2D

const ObjectsTest = preload("res://scripts/levels/world1_objects_test.gd")
const HUB_SCENE_PATH: String = "res://scenes/hub/hub.tscn"

## Se pidio ir al hub tras completar `level_id`.
signal hub_requested(level_id: String)

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

## Si es valido, se llama con la ruta del hub en lugar de cambiar de escena
## (pruebas y herramientas).
var scene_switcher: Callable = Callable()

var _pulse_was_unlocked: bool = false
var _completed_level: String = ""

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


## Nivel completado al cruzar la puerta (vacio si aun no).
func get_completed_level() -> String:
	return _completed_level


func _on_level_completed(level_id: String) -> void:
	if not _completed_level.is_empty():
		return
	_completed_level = level_id
	hub_requested.emit(level_id)
	if scene_switcher.is_valid():
		scene_switcher.call(HUB_SCENE_PATH)
	else:
		get_tree().change_scene_to_file.call_deferred(HUB_SCENE_PATH)
