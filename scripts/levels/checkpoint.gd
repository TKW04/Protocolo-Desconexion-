## Punto de sincronizacion (tipo `C` del level-builder; docs 6.3: "uno a mitad
## de nivel"; V2 aprobada). El origen son los pies de Isak al reaparecer (abajo
## en el centro de la celda C).
##
## Al tocarlo Isak (vivo) por primera vez:
## - pasa a ser el ultimo punto del nivel (GameState.set_last_checkpoint, que
##   emite EventBus.checkpoint_activated); solo hay uno activo por nivel, el mas
##   reciente: los demas vuelven a verse apagados;
## - repone el Sync Rate al 100 % (V2: "tocar un punto de sincronizacion lo
##   activa y repone el Sync Rate");
## - la baliza cambia de bandera gris a media asta a bandera cian izada que
##   ondea (data/world1_objects.json, seccion checkpoint). Sin texto.
## Se guarda una sola vez por checkpoint: volver a tocarlo no hace nada.
## La reaparicion en el (muerte o caida) la hace LevelRunner.
class_name Checkpoint
extends Marker2D

const GROUP: StringName = &"checkpoint"
## Capa de fisica de Isak (project.godot, [layer_names]).
const LAYER_PLAYER: int = 2

## Isak lo ha tocado por primera vez.
signal activated(checkpoint_id: StringName)

## Id de la lista `checkpoints` del nivel.
@export var checkpoint_id: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("checkpoint")
var _taken: bool = false
var _time: float = 0.0
var _sprite: Sprite2D
var _area: Area2D


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	_taken = GameState.get_last_checkpoint(GameState.current_level) == checkpoint_id \
		and checkpoint_id != &""
	_update_frame()
	EventBus.checkpoint_activated.connect(_on_checkpoint_activated)


func _process(delta: float) -> void:
	_time += WorldTime.scaled_delta(delta)
	_update_frame()


## Posicion de reaparicion (pies de Isak) en coordenadas globales.
func get_spawn_position() -> Vector2:
	return global_position


## Verdadero si ya se ha tocado (se guarda una sola vez).
func is_taken() -> bool:
	return _taken


## Verdadero si es el ultimo punto del nivel (el que se ve encendido).
func is_active() -> bool:
	return _taken and GameState.get_last_checkpoint(GameState.current_level) == checkpoint_id


## Cuadro actual de la baliza (off 0, on_a 1, on_b 2).
func get_frame() -> int:
	return _sprite.frame


func get_trigger_area() -> Area2D:
	return _area


## Isak toca el punto. Falso si ya se habia tocado.
func activate() -> bool:
	if _taken:
		return false
	_taken = true
	_time = 0.0
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.set_last_checkpoint(GameState.current_level, checkpoint_id)
	_update_frame()
	activated.emit(checkpoint_id)
	return true


func _update_frame() -> void:
	var frames: Dictionary = _config.get("frames", {})
	if not is_active():
		_sprite.frame = int(frames.get("off", 0))
		return
	var period: float = maxf(float(_config.get("wave_s", 0.4)), 0.01)
	var wave: bool = int(floorf(_time / period)) % 2 == 1
	_sprite.frame = int(frames.get("on_b" if wave else "on_a", 1))


func _build() -> void:
	var frame_size: Array = _config.get("frame_size", [64, 64])
	_sprite = Sprite2D.new()
	_sprite.name = "Beacon"
	_sprite.texture = load(String(_config["texture"])) as Texture2D
	_sprite.hframes = int(_config.get("frames", {}).get("on_b", 2)) + 1
	_sprite.centered = false
	_sprite.position = Vector2(-float(frame_size[0]) * 0.5, -float(frame_size[1]))
	add_child(_sprite)
	var trigger: Array = _config.get("trigger_size_px", [64, 128])
	_area = Area2D.new()
	_area.name = "Trigger"
	_area.collision_layer = 0
	_area.collision_mask = LAYER_PLAYER
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(float(trigger[0]), float(trigger[1]))
	shape.shape = box
	shape.position = Vector2(0.0, -box.size.y * 0.5)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var isak := body as Isak
	if isak != null and not isak.is_dead():
		activate()


func _on_checkpoint_activated(_level_id: String, _id: StringName) -> void:
	_update_frame()
