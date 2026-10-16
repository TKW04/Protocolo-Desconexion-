## Receptor del pulso (Mundo 1, Tramo 2 del 1-1): objeto del entorno que el
## pulso de datos activa (docs 3.2: "si golpea un objeto del entorno, lo
## activa"). PROPUESTA (docs/preguntas.md, V4): esta en el extremo del puente,
## un pulso basta y se queda activado (stays_active en data/world1_objects.json).
##
## Escucha EventBus.pulse_fired(area), que Isak emite con su PulseArea: se
## activa si el circulo del area (radio pulse_radius_px, centrado en el
## celular) toca la zona de golpe del receptor (hit_rect). Al activarse emite
## activated(target_id); el puente con ese id (PulseBridge.object_id) lo escucha.
## El origen del nodo es la esquina superior izquierda de su celda (64x64).
class_name PulseReceiver
extends Node2D

const GROUP: StringName = &"pulse_receiver"

## Se activa por primera vez (o de nuevo, si stays_active fuera falso).
signal activated(target_id: StringName)

## Id del objeto que activa (params.target en la lista `objects` del nivel).
@export var target_id: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("receiver")
var _active: bool = false
var _blink_time: float = 0.0
var _frames: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group(GROUP)
	_frames = _config.get("frames", {"off_a": 0, "off_b": 1, "on": 2})
	_sprite.texture = load(String(_config["texture"])) as Texture2D
	_sprite.hframes = 3
	_sprite.centered = false
	EventBus.pulse_fired.connect(receive_pulse)
	_update_frame()


func _process(delta: float) -> void:
	if _active:
		return
	_blink_time += WorldTime.scaled_delta(delta)
	_update_frame()


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; ya activado (y se queda activo) es inerte.
func is_help_available() -> bool:
	return not (_active and bool(_config.get("stays_active", true)))


## Verdadero si ya esta activado.
func is_active() -> bool:
	return _active


## Zona de golpe en coordenadas globales.
func get_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [0, 0, 64, 64])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


## Comprueba si el pulso (`area`, con un CircleShape2D) alcanza al receptor y,
## si es asi, lo activa. Devuelve verdadero si se ha activado ahora.
func receive_pulse(area: Area2D) -> bool:
	if _active and bool(_config.get("stays_active", true)):
		return false
	if not pulse_reaches(area, get_hit_rect()):
		return false
	activate()
	return true


## Activa el receptor sin pulso (p. ej. al restaurar un estado guardado).
func activate() -> void:
	if _active and bool(_config.get("stays_active", true)):
		return
	_active = true
	_update_frame()
	activated.emit(target_id)


## Verdadero si algun circulo del area toca el rectangulo (coordenadas globales).
static func pulse_reaches(area: Area2D, rect: Rect2) -> bool:
	if area == null:
		return false
	for child: Node in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or not (shape_node.shape is CircleShape2D):
			continue
		var circle := shape_node.shape as CircleShape2D
		var center: Vector2 = shape_node.global_position
		var scale_factor: float = maxf(absf(shape_node.global_scale.x), absf(shape_node.global_scale.y))
		var radius: float = circle.radius * scale_factor
		var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y))
		if center.distance_to(closest) <= radius:
			return true
	return false


func _update_frame() -> void:
	if _sprite == null:
		return
	if _active:
		_sprite.frame = int(_frames["on"])
		return
	var blink: float = maxf(float(_config.get("blink_s", 0.5)), 0.01)
	var odd: bool = int(floorf(_blink_time / blink)) % 2 == 1
	_sprite.frame = int(_frames["off_b"] if odd else _frames["off_a"])
