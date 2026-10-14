## Plataforma movil simple de ida y vuelta. Es un objeto del MUNDO: avanza con
## WorldTime.scaled_delta(), asi que el Debug Mode la ralentiza (x0,5) sin
## tocar a Isak. Ejemplo de referencia para enemigos y proyectiles futuros.
class_name MovingPlatform
extends AnimatableBody2D

## Tamano en px; el origen es el centro.
@export var size: Vector2 = Vector2(192.0, 32.0)
## Desplazamiento maximo desde la posicion inicial (px).
@export var travel: Vector2 = Vector2(384.0, 0.0)
## Velocidad en px/s de tiempo del mundo.
@export var speed_px_s: float = 160.0
@export var color: Color = Color(0.36, 0.42, 0.5, 1.0)

var _origin: Vector2
## Distancia recorrida en el ciclo de ida y vuelta (0 a 2 * |travel|).
var _cycle_px: float = 0.0
## Desplazamiento actual respecto al origen. Con sync_to_physics el nodo
## adopta la posicion en el siguiente paso de fisica, asi que se guarda aparte.
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_origin = position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `world_delta` segundos de tiempo del mundo.
func advance(world_delta: float) -> void:
	var length: float = travel.length()
	if length <= 0.0:
		return
	_cycle_px = fmod(_cycle_px + speed_px_s * world_delta, 2.0 * length)
	var along: float = _cycle_px if _cycle_px <= length else 2.0 * length - _cycle_px
	_offset = travel * (along / length)
	position = _origin + _offset


## Desplazamiento actual respecto a la posicion inicial (px).
func get_offset() -> Vector2:
	return _offset


func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), color)
