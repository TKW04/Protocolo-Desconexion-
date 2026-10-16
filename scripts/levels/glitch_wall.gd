## Pared con glitch: el secreto del 1-1 ("una pared con un leve glitch, sin
## forma de acceder todavia. Se retoma cuando Isak tenga el Debug"). Tipo
## `glitch_wall` de la lista `objects` del nivel (V7).
##
## Es solida. Se dibuja como un bloque del tileset (mismos bordes segun
## solid_neighbors) y cada celda hace de vez en cuando una rafaga corta de
## lineas de pixeles desplazadas (cuadros discretos, tiempo del mundo). Grupo
## "debug_secret" y senal debug_revealed(active) cuando el Debug se enciende o
## se apaga.
##
## Se abre con el Debug (paso 14 de §10 de docs/propuesta-asistentes-y-vidas.md,
## 2026-10-16; interaccion minima, sin tocar el Debug): con el Debug ACTIVO
## (DebugMode.is_active(): solo es posible con la habilidad desbloqueada) e Isak
## a menos de reveal_radius_px del bloque (una Area2D propia), la pared se
## disuelve: cada celda parpadea con la capa glitch_dissolve
## (extra_life_frames.tres, tools/gen_extra_life.py) a dissolve_fps; al acabar
## deja de ser solida, se oculta y emite opened. Queda abierta hasta que se
## recarga el nivel (cada intento la vuelve a cerrar). Lo que hay dentro (la vida
## extra del secreto D del 1-1, ExtraLifePickup) escucha opened. Sin el Debug
## sigue solida y su ayuda con Q no cambia.
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

## El Debug Mode se ha encendido (true) o apagado (false) con la pared en el
## nivel.
signal debug_revealed(active: bool)
## Empieza a disolverse (Debug activo con Isak cerca).
signal dissolve_started
## Se termino de disolver: ya no es solida ni se ve.
signal opened

const FRAMES_PATH: String = "res://assets/sprites/extra_life_frames.tres"
const DISSOLVE_ANIM: StringName = &"glitch_dissolve"
## Capa de colision de Isak (scenes/player/isak.tscn).
const ISAK_LAYER: int = 2

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
var _detector: Area2D
var _dissolve_frames: SpriteFrames
var _overlays: Array[Sprite2D] = []
## Segundos de disolucion (tiempo del mundo); -1 = no se esta disolviendo.
var _dissolve_time: float = -1.0
var _open: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(DEBUG_SECRET_GROUP)
	_rng.seed = hash(Vector2i(roundi(global_position.x), roundi(global_position.y)))
	_build()
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)


func _process(delta: float) -> void:
	if not _open and _dissolve_time < 0.0 and DebugMode.is_active() and is_isak_near():
		open_with_debug()
	advance(WorldTime.scaled_delta(delta))


## Solida mientras no se ha abierto con el Debug.
func is_solid() -> bool:
	return _shape != null and not _shape.disabled and not _open


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; disolviendose o abierta, no.
func is_help_available() -> bool:
	return not _open and _dissolve_time < 0.0


func is_open() -> bool:
	return _open


func is_dissolving() -> bool:
	return _dissolve_time >= 0.0


## Isak dentro de reveal_radius_px del bloque.
func is_isak_near() -> bool:
	if _detector == null:
		return false
	for body: Node2D in _detector.get_overlapping_bodies():
		if body is Isak:
			return true
	return false


## Rectangulo del bloque en coordenadas globales.
func get_world_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	return Rect2(global_position, Vector2(width_tiles * t, height_tiles * t))


## Empieza a disolverse (lo llama _process con el Debug activo e Isak cerca).
## Falso si ya estaba abierta o disolviendose.
func open_with_debug() -> bool:
	if _open or _dissolve_time >= 0.0:
		return false
	_dissolve_time = 0.0
	if _dissolve_frames == null:
		_dissolve_frames = load(FRAMES_PATH) as SpriteFrames
	for cell: Sprite2D in _cells:
		var overlay := Sprite2D.new()
		overlay.centered = false
		overlay.position = cell.position
		overlay.texture = _dissolve_frames.get_frame_texture(DISSOLVE_ANIM, 0)
		add_child(overlay)
		_overlays.append(overlay)
	dissolve_started.emit()
	return true


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
	if _open:
		return
	if _dissolve_time >= 0.0:
		_advance_dissolve(delta)
		return
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
	var radius: float = float(_config.get("reveal_radius_px", 192.0))
	_detector = Area2D.new()
	_detector.name = "DebugReveal"
	_detector.collision_layer = 0
	_detector.collision_mask = ISAK_LAYER
	_detector.monitorable = false
	var zone := CollisionShape2D.new()
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = rect.size + Vector2.ONE * radius * 2.0
	zone.shape = zone_rect
	zone.position = rect.size * 0.5
	_detector.add_child(zone)
	add_child(_detector)


## Un paso de la disolucion: cada celda parpadea (dissolve_blink: 1 = se ve) y
## la capa avanza un cuadro a dissolve_fps; al terminar, se abre.
func _advance_dissolve(delta: float) -> void:
	var count: int = _dissolve_frames.get_frame_count(DISSOLVE_ANIM)
	var fps: float = float(_config.get("dissolve_fps", _dissolve_frames.get_animation_speed(DISSOLVE_ANIM)))
	var frame: int = floori(_dissolve_time * fps)
	if frame >= count:
		_finish_open()
		return
	var blink: Array = _config.get("dissolve_blink", [1, 0, 1, 0, 0, 0])
	var shown: bool = frame < blink.size() and int(blink[frame]) == 1
	for i: int in _cells.size():
		_cells[i].visible = shown
		_overlays[i].texture = _dissolve_frames.get_frame_texture(DISSOLVE_ANIM, frame)
	_dissolve_time += delta


func _finish_open() -> void:
	_dissolve_time = -1.0
	_open = true
	_shape.set_deferred(&"disabled", true)
	for overlay: Sprite2D in _overlays:
		overlay.queue_free()
	_overlays.clear()
	visible = false
	opened.emit()


func _random_wait() -> float:
	return _rng.randf_range(float(_config.get("idle_min_s", 0.8)), float(_config.get("idle_max_s", 2.2)))


func _on_debug_mode_changed(active: bool) -> void:
	debug_revealed.emit(active)
