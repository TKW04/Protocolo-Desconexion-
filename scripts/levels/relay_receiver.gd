## Receptor enlazado (tipo `relay_receiver` del catalogo del Mundo 1; patron 2
## de docs/propuesta-1-2.md §0.3 y acertijo «Correo certificado», §4; paso 3
## de §10). Receptor de pulso que SOLO responde mientras un lector laser
## enlazado (LaserReceiver con target_id == object_id) le da corriente:
## - Sin corriente: enchufe tachado; un pulso que lo alcanza da una chispa gris
##   y no hace nada (rejected). Sin castigo.
## - Con corriente: un pulso lo activa (para siempre), avisa a sus lectores
##   (LaserReceiver.complete: el cable queda encendido) y emite
##   activated(target_id): el puente con ese id (PulseBridge.object_id) se
##   extiende (el puente lo busca en el grupo pulse_receiver, como al receptor
##   del 1-1).
## Misma prueba del pulso que PulseReceiver (circulo de la PulseArea contra
## hit_rect). Tiempo del mundo para la animacion. El origen del nodo es la
## esquina superior izquierda de su celda (64x64).
class_name RelayReceiver
extends Node2D

const GROUP: StringName = &"relay_receiver"

## Se ha activado (con corriente y pulso).
signal activated(target_id: StringName)
## Un pulso lo ha alcanzado sin corriente: no hace nada (chispa gris).
signal rejected

## Id propio (params.id); lo usan los lectores (params.target).
@export var object_id: StringName = &""
## Id del puente que extiende (params.target).
@export var target_id: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("relay_receiver")
var _active: bool = false
var _readers: Array[LaserReceiver] = []
var _sprite: EnergySprite
var _spark: EnergySprite
var _spark_time: float = -1.0
var _rejections: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PulseReceiver.GROUP)
	var frames: String = String(_config.get("frames", ""))
	_sprite = EnergySprite.attach(self, &"relay_receiver_off", Vector2(32.0, 32.0), false, frames)
	_spark = EnergySprite.attach(self, &"gray_spark", LaserReceiver._vec(_config.get("spark_px", [32, 24])), false, frames)
	_spark.name = "Spark"
	_spark.visible = false
	EventBus.pulse_fired.connect(receive_pulse)
	_link_readers.call_deferred()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo (animacion y chispa).
func advance(dt: float) -> void:
	_update_sprite()
	if _sprite != null:
		_sprite.advance(dt)
	if _spark_time >= 0.0:
		_spark_time += dt
		var fps: float = _spark.sprite_frames.get_animation_speed(&"gray_spark")
		var count: int = _spark.sprite_frames.get_frame_count(&"gray_spark")
		var f: int = floori(_spark_time * fps)
		if f >= count:
			_spark_time = -1.0
			_spark.visible = false
		else:
			_spark.frame = f


# --- Consultas ---

func is_active() -> bool:
	return _active


## Algun lector enlazado le da corriente ahora.
func is_powered() -> bool:
	for reader: LaserReceiver in _readers:
		if is_instance_valid(reader) and reader.is_powered():
			return true
	return false


func get_readers() -> Array[LaserReceiver]:
	return _readers


func get_rejection_count() -> int:
	return _rejections


## La chispa gris se esta viendo.
func is_sparking() -> bool:
	return _spark_time >= 0.0


## Ayuda de Eco (HelpCatalog.is_help_live): lo usado no ayuda; ya activado, no.
func is_help_available() -> bool:
	return not _active


func get_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [12, 0, 40, 64])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


## Entrada del cable en coordenadas globales.
func get_cable_port() -> Vector2:
	return global_position + LaserReceiver._vec(_config.get("cable_port_px", [57, 32]))


# --- Acciones ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si se ha activado ahora.
func receive_pulse(area: Area2D) -> bool:
	if _active or not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	if not is_powered():
		_rejections += 1
		_spark_time = 0.0
		_spark.visible = true
		_spark.frame = 0
		rejected.emit()
		return false
	activate()
	return true


## Se activa (sin comprobar la corriente: lo usan el pulso y las pruebas).
func activate() -> void:
	if _active:
		return
	_active = true
	for reader: LaserReceiver in _readers:
		if is_instance_valid(reader):
			reader.complete()
	_update_sprite()
	activated.emit(target_id)


func _update_sprite() -> void:
	if _sprite == null:
		return
	if _active:
		_sprite.show_state(&"relay_receiver_on")
	elif is_powered():
		_sprite.show_state(&"relay_receiver_powered")
	else:
		_sprite.show_state(&"relay_receiver_off")


func _link_readers() -> void:
	if object_id == &"" or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(LaserReceiver.GROUP):
		var reader := node as LaserReceiver
		if reader != null and reader.target_id == object_id and not _readers.has(reader):
			_readers.append(reader)
			if reader.get_cable() != null:
				reader.get_cable().queue_redraw()
