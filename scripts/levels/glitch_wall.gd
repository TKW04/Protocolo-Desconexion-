## Pared con glitch: el secreto del 1-1 ("una pared con un leve glitch, sin
## forma de acceder todavia. Se retoma cuando Isak tenga el Debug"). Tipo
## `glitch_wall` de la lista `objects` del nivel (V7).
##
## Es solida y no tiene interaccion. Se dibuja como un bloque del tileset
## (mismos bordes segun solid_neighbors) y cada celda hace de vez en cuando
## una rafaga corta de lineas de pixeles desplazadas (cuadros discretos, tiempo
## del mundo). Gancho para el futuro: grupo "debug_secret" y la senal
## debug_revealed(active), que se emite cuando el Debug se enciende o se apaga.
## Que hace el Debug con ella (revelarla, abrirla) NO esta implementado.
##
## El origen del nodo es la esquina superior izquierda de la primera celda.
class_name GlitchWall
extends StaticBody2D

const GROUP: StringName = &"glitch_wall"
## Grupo comun de los secretos que el Debug revelara (gancho, ver V12).
const DEBUG_SECRET_GROUP: StringName = &"debug_secret"
## Bits de vecinos solidos (como solid.by_mask de data/tileset_mundo1.json).
const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

## Gancho: el Debug Mode se ha encendido (true) o apagado (false) con la pared
## en el nivel. Nadie lo consume todavia.
signal debug_revealed(active: bool)

@export_range(1, 32) var width_tiles: int = 1
@export_range(1, 32) var height_tiles: int = 2
## Lados del bloque con terreno solido al lado (bits N=1 E=2 S=4 W=8).
@export_range(0, 15) var solid_neighbors: int = 0

var _config: Dictionary = World1ObjectsConfig.section("glitch_wall")
var _cells: Array[Sprite2D] = []
## Por celda: segundos hasta la proxima rafaga y cuadro de rafaga (-1 = quieta).
var _wait: Array[float] = []
var _burst_time: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(DEBUG_SECRET_GROUP)
	_rng.seed = hash(Vector2i(roundi(global_position.x), roundi(global_position.y)))
	_build()
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Siempre solida (por ahora no hay forma de atravesarla).
func is_solid() -> bool:
	return _shape != null and not _shape.disabled


## Cuadro actual de la celda `index` (0 = limpia).
func get_cell_frame(index: int) -> int:
	return _cells[index].frame_coords.x


func get_cell_count() -> int:
	return _cells.size()


## Mascara de vecinos solidos de la celda (cx, cy): dentro del bloque cuenta
## la propia pared; en el borde, solid_neighbors.
func cell_mask(cx: int, cy: int) -> int:
	var mask: int = 0
	if cy > 0 or solid_neighbors & N:
		mask |= N
	if cx < width_tiles - 1 or solid_neighbors & E:
		mask |= E
	if cy < height_tiles - 1 or solid_neighbors & S:
		mask |= S
	if cx > 0 or solid_neighbors & W:
		mask |= W
	return mask


## Avanza la animacion `delta` segundos de tiempo del mundo.
func advance(delta: float) -> void:
	var frames: int = int(_config.get("frames", 4))
	var fps: float = float(_config.get("burst_fps", 12.0))
	for i: int in _cells.size():
		if _burst_time[i] < 0.0:
			_wait[i] -= delta
			if _wait[i] <= 0.0:
				_burst_time[i] = 0.0
		if _burst_time[i] >= 0.0:
			var f: int = 1 + floori(_burst_time[i] * fps)
			if f >= frames:
				_burst_time[i] = -1.0
				_wait[i] = _random_wait()
				f = 0
			else:
				_burst_time[i] += delta
			_cells[i].frame_coords = Vector2i(f, _cells[i].frame_coords.y)


func _build() -> void:
	var t: float = World1ObjectsConfig.tile_size()
	var texture := load(String(_config["texture"])) as Texture2D
	for cy: int in height_tiles:
		for cx: int in width_tiles:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.hframes = int(_config.get("frames", 4))
			sprite.vframes = 16
			sprite.centered = false
			sprite.position = Vector2(cx * t, cy * t)
			sprite.frame_coords = Vector2i(0, cell_mask(cx, cy))
			add_child(sprite)
			_cells.append(sprite)
			_wait.append(_random_wait())
			_burst_time.append(-1.0)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width_tiles * t, height_tiles * t)
	_shape.shape = rect
	_shape.position = rect.size * 0.5
	add_child(_shape)


func _random_wait() -> float:
	return _rng.randf_range(float(_config.get("idle_min_s", 0.8)), float(_config.get("idle_max_s", 2.2)))


func _on_debug_mode_changed(active: bool) -> void:
	debug_revealed.emit(active)
