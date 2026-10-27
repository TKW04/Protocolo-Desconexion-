## Mensaje de secreto recogible (objeto `memory_pickup` del catalogo del Mundo 1;
## paso 4 de docs/propuesta-recuerdos.md §7 y §10, 2026-10-19). Un sobre en un
## secreto del nivel: al tocarlo Isak, GameState.obtain_memory(memory_id) lo deja
## obtenido SIN GUARDAR (se lee en Notas desde ese momento) y sale el aviso del
## sistema «Recuerdo obtenido: <remitente>. Guarda en Notas para conservarlo.»
## (MemoryNotice; texto del sistema, no de Eco).
## REAPARECE SI NO SE OBTUVO: solo mira GameState.has_memory(memory_id) al entrar
## al arbol (no found_secrets ni el numero de vuelta). Ya obtenido (guardado o no)
## no aparece; si un game over sin guardar lo quita del registro, al volver a
## cargar el mapa esta otra vez en su sitio, en cualquier vuelta.
## Flota con bob_px / bob_hz (tiempo del mundo) en center_px de su celda (mitad
## alta: no tapa un punto de atencion de la misma celda) y al recogerlo reproduce
## memory_pickup_collect subiendo collect_rise_px y se libera. Ajustes en la
## seccion memory_pickup de data/world1_objects.json. Arte:
## tools/gen_memory_pickup.py (assets/sprites/memory_pickup_frames.tres).
class_name MemoryPickup
extends Area2D

signal collected(memory_id: StringName)

const GROUP: StringName = &"memory_pickup"
const FRAMES_PATH: String = "res://assets/sprites/memory_pickup_frames.tres"
const IDLE_ANIM: StringName = &"memory_pickup_idle"
const COLLECT_ANIM: StringName = &"memory_pickup_collect"

## Id del objeto en el nivel (no se guarda: lo que se guarda es memory_id).
@export var object_id: StringName = &""
## Id del mensaje en data/memories.json (kind secret).
@export var memory_id: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("memory_pickup")
var _sprite: AnimatedSprite2D
var _shape: CollisionShape2D
var _taken: bool = false
var _time: float = 0.0
## Segundos desde que se recogio (tiempo del mundo); -1 = no recogido.
var _collect_time: float = -1.0
var _notice: MemoryNotice


func _ready() -> void:
	add_to_group(GROUP)
	if not MemoryCatalog.shared().has(memory_id):
		push_error("MemoryPickup: memory_id desconocido '%s'" % memory_id)
		_taken = true
		queue_free()
		return
	if GameState.has_memory(memory_id):
		_taken = true
		queue_free()
		return
	var hit: Rect2 = get_pickup_rect()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit.size
	_shape.shape = rect
	_shape.position = hit.get_center()
	add_child(_shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = load(FRAMES_PATH) as SpriteFrames
	_sprite.animation = IDLE_ANIM
	_sprite.position = _center()
	_sprite.scale = Vector2.ONE * _draw_scale()
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	if _collect_time >= 0.0:
		_advance_collect(dt)
		return
	_time += dt
	var fps: float = _sprite.sprite_frames.get_animation_speed(IDLE_ANIM)
	_sprite.frame = floori(_time * fps) % _sprite.sprite_frames.get_frame_count(IDLE_ANIM)
	var bob: float = roundf(sin(_time * TAU * float(_config.get("bob_hz", 1.0))) * float(_config.get("bob_px", 2.0)))
	_sprite.position = (_center() + Vector2(0.0, bob)).round()


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; recogido, no.
func is_help_available() -> bool:
	return not _taken


func is_taken() -> bool:
	return _taken


## Aviso del sistema que salio al recogerlo (null si aun no).
func get_notice() -> MemoryNotice:
	return _notice


## Id del nivel generado que lo contiene (GameState.NO_LEVEL si no hay).
func get_level_id() -> StringName:
	var level: GeneratedLevel = _level()
	return StringName(level.level_id) if level != null else GameState.NO_LEVEL


## Recoge el mensaje (una sola vez): lo obtiene sin guardar y saca el aviso.
## Falso si ya estaba recogido.
func collect() -> bool:
	if _taken:
		return false
	_taken = true
	remove_from_group(HelpCatalog.TARGET_GROUP)
	_shape.set_deferred(&"disabled", true)
	set_deferred(&"monitoring", false)
	GameState.obtain_memory(memory_id)
	_notice = MemoryNotice.show_for(memory_id, _notice_host())
	_collect_time = 0.0
	_sprite.animation = COLLECT_ANIM
	_sprite.frame = 0
	collected.emit(memory_id)
	return true


func _draw_scale() -> float:
	return float(_config.get("draw_scale", 2))


## Zona de recogida (local, desde la esquina de la celda): size_px centrada en
## center_px y alargada hacia abajo hasta reach_floor_px (el suelo de la celda,
## 64). Paso 12 de docs/propuesta-mundo-3.md (2026-10-27): asi tambien la toca
## Isak comprimido (caja de 32 x 40 pegada al suelo), que no llegaba a la zona de
## la mitad alta (el msg_3_2 tras el marco pequeno del 3-1); de pie no cambia nada.
func get_pickup_rect() -> Rect2:
	var size_px: Array = _config.get("size_px", [36, 32])
	var size := Vector2(float(size_px[0]), float(size_px[1]))
	var rect := Rect2(_center() - size * 0.5, size)
	var floor_y: float = float(_config.get("reach_floor_px", 0.0))
	if floor_y > rect.end.y:
		rect.size.y = floor_y - rect.position.y
	return rect


func _center() -> Vector2:
	var c: Variant = _config.get("center_px", [32, 4])
	if c is Array and (c as Array).size() == 2:
		return Vector2(float(c[0]), float(c[1]))
	return Vector2(32.0, 4.0)


func _level() -> GeneratedLevel:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return node as GeneratedLevel
		node = node.get_parent()
	return null


## Donde vive el aviso: el nivel (el objeto se libera al terminar la recogida).
func _notice_host() -> Node:
	var level: GeneratedLevel = _level()
	if level != null:
		return level
	return get_parent() if get_parent() != null else self


func _advance_collect(dt: float) -> void:
	_collect_time += dt
	var frames: SpriteFrames = _sprite.sprite_frames
	var count: int = frames.get_frame_count(COLLECT_ANIM)
	var length: float = count / maxf(frames.get_animation_speed(COLLECT_ANIM), 0.001)
	var k: float = clampf(_collect_time / length, 0.0, 1.0)
	_sprite.frame = mini(floori(k * count), count - 1)
	_sprite.position = (_center() - Vector2(0.0, float(_config.get("collect_rise_px", 32.0)) * k)).round()
	if _collect_time >= length:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Isak:
		collect()
