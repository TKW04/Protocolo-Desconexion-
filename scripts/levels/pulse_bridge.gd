## Puente desactivado del Mundo 1 (Tramo 2 del 1-1: "Puente desactivado. El
## pulso lo activa y ensena que el pulso afecta al entorno"). Tipo
## `bridge_inactive` de la lista `objects` del nivel (V7).
##
## PROPUESTA (docs/preguntas.md, V4): lo activa su receptor (PulseReceiver con
## target_id == object_id) y queda extendido para siempre. Los tiles aparecen
## uno a uno en `direction` (por defecto de izquierda a derecha), cada step_s
## de tiempo del mundo: el tile que llega se ve a medias un paso antes de
## hacerse solido. Retraido: solo un contorno discontinuo, sin colision.
## Extendido: tabla solida de collision_height_px arriba de cada celda.
##
## El origen del nodo es la esquina superior izquierda de la primera celda;
## con direction "left" el puente crece hacia la izquierda desde esa celda.
class_name PulseBridge
extends StaticBody2D

enum State { RETRACTED, EXTENDING, EXTENDED }

const GROUP: StringName = &"pulse_bridge"

## Cambia de estado (State).
signal state_changed(state: int)
## Ha terminado de extenderse (todos los tiles solidos).
signal extended

## Id del puente (params.id); lo usan los receptores (params.target).
@export var object_id: StringName = &""
## Longitud en tiles.
@export_range(1, 64) var length_tiles: int = 4
## "right" o "left": hacia donde crece desde la primera celda.
@export_enum("right", "left") var direction: String = "right"

var _config: Dictionary = World1ObjectsConfig.section("bridge")
var _state: State = State.RETRACTED
## Tiles ya solidos.
var _solid_count: int = 0
var _step_time: float = 0.0
var _sprites: Array[Sprite2D] = []
var _shapes: Array[CollisionShape2D] = []
## Receptores enlazados: PulseReceiver o RelayReceiver (grupo pulse_receiver,
## con target_id, is_active() y la senal activated).
var _receivers: Array[Node] = []


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	_link_receivers.call_deferred()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Estado actual (State).
func get_state() -> State:
	return _state


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; solo plegado (extendiendose o extendido ya no es un puente desactivado).
func is_help_available() -> bool:
	return _state == State.RETRACTED


func is_extended() -> bool:
	return _state == State.EXTENDED


## Tiles ya solidos (0 retraido, length_tiles extendido).
func get_solid_count() -> int:
	return _solid_count


## Verdadero si el tile `index` (0 = el primero) tiene colision.
func is_tile_solid(index: int) -> bool:
	return index >= 0 and index < _shapes.size() and not _shapes[index].disabled


## Empieza a extenderse. No hace nada si ya se extiende o esta extendido.
func activate() -> void:
	if _state != State.RETRACTED:
		return
	_set_state(State.EXTENDING)
	_step_time = 0.0
	_advance_tile()


## Avanza la extension `delta` segundos de tiempo del mundo (lo llama
## _physics_process; las pruebas lo pueden llamar directamente).
func advance(delta: float) -> void:
	if _state != State.EXTENDING:
		return
	_step_time += delta
	var step: float = maxf(float(_config.get("step_s", 0.08)), 0.001)
	while _step_time >= step and _state == State.EXTENDING:
		_step_time -= step
		_advance_tile()


## Rectangulo global (aprox.) que ocupa el puente: para camaras y pruebas.
func get_span_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	var x0: float = 0.0 if direction == "right" else -(length_tiles - 1) * t
	return Rect2(global_position + Vector2(x0, 0.0), Vector2(length_tiles * t, t))


func _build() -> void:
	var t: float = World1ObjectsConfig.tile_size()
	var texture := load(String(_config["texture"])) as Texture2D
	var height: float = float(_config.get("collision_height_px", 12))
	var one_way: bool = bool(_config.get("one_way", false))
	var sign_x: float = 1.0 if direction == "right" else -1.0
	for i: int in length_tiles:
		var x: float = i * t * sign_x
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.hframes = 3
		sprite.centered = false
		sprite.position = Vector2(x, 0.0)
		sprite.frame = _frame("off")
		add_child(sprite)
		_sprites.append(sprite)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(t, height)
		shape.shape = rect
		shape.position = Vector2(x + t * 0.5, height * 0.5)
		shape.one_way_collision = one_way
		shape.disabled = true
		add_child(shape)
		_shapes.append(shape)


func _advance_tile() -> void:
	if _solid_count < length_tiles:
		_sprites[_solid_count].frame = _frame("on")
		_shapes[_solid_count].disabled = false
		_solid_count += 1
	if _solid_count < length_tiles:
		_sprites[_solid_count].frame = _frame("half")
	else:
		_set_state(State.EXTENDED)
		extended.emit()


func _set_state(state: State) -> void:
	_state = state
	state_changed.emit(state)


func _frame(name: String) -> int:
	return int(_config.get("frames", {}).get(name, 0))


## Conecta con los receptores del arbol (grupo pulse_receiver: el del pulso y
## el receptor enlazado del 1-2) cuyo target_id es este puente. Si
## alguno ya estaba activado (estado restaurado), se extiende enseguida.
func _link_receivers() -> void:
	if object_id == &"" or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(PulseReceiver.GROUP):
		var receiver: Node = node
		if not receiver.has_signal(&"activated") or not receiver.has_method(&"is_active") \
				or StringName(receiver.get(&"target_id")) != object_id or _receivers.has(receiver):
			continue
		_receivers.append(receiver)
		receiver.connect(&"activated", _on_receiver_activated)
		if bool(receiver.call(&"is_active")):
			activate()


func _on_receiver_activated(_target_id: StringName) -> void:
	activate()
