## Escena de prueba de Eco companero y de la entrada del apodo (no es un nivel
## del juego; docs/propuesta-asistentes-y-vidas.md, pasos 4 y 5 de §10). Eco
## queda conocido en memoria (no se guarda nada) y sigue a Isak, que llega por
## un vortice. Teclas de prueba (solo en esta escena): N abre la entrada del
## apodo; T hace que Eco diga una linea con {apodo} (importante: se cierra con
## Espacio / A / Intro); V hace que Isak se vaya por el vortice y vuelva.
extends Node2D

const ObjectsTest = preload("res://scripts/levels/world1_objects_test.gd")
const NICKNAME_SCENE: PackedScene = preload("res://scenes/ui/nickname_entry.tscn")
const TEST_LINE: String = "Hola, {apodo}. Sigo aquí contigo."

## '#' solido, '.' vacio. 24 x 12 tiles.
const GRID: Array[String] = [
	"........................",
	"........................",
	"........................",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"#......................#",
	"########################",
	"########################",
	"########################",
]

var _companion: EcoCompanion
var _entry: NicknameEntry

@onready var _isak: Isak = $Isak
@onready var _tiles: TileMapLayer = $Tiles


func _ready() -> void:
	GameState.current_world = 1
	GameState.meet_ally(GameState.ALLY_ECO)
	ObjectsTest.paint_tiles(_tiles, GRID)
	var camera: Camera2D = _isak.get_node(^"Camera2D") as Camera2D
	var t: int = int(World1ObjectsConfig.tile_size())
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GRID[0].length() * t
	camera.limit_bottom = GRID.size() * t
	_companion = EcoCompanion.attach(_isak, self)
	WarpVortex.arrive(_isak, self)


func get_companion() -> EcoCompanion:
	return _companion


## Abre la entrada del apodo (null si ya esta abierta).
func open_nickname_entry() -> NicknameEntry:
	if _entry != null and is_instance_valid(_entry):
		return null
	_entry = NICKNAME_SCENE.instantiate() as NicknameEntry
	add_child(_entry)
	return _entry


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or get_tree().paused:
		return
	match key.keycode:
		KEY_N:
			open_nickname_entry()
		KEY_T:
			EventBus.eco_line_requested.emit(TEST_LINE, -1.0, true)
		KEY_V:
			if not _isak.is_warping():
				var vortex: WarpVortex = WarpVortex.depart(_isak, self)
				vortex.finished.connect(func() -> void: WarpVortex.arrive(_isak, self))
		_:
			return
	get_viewport().set_input_as_handled()
