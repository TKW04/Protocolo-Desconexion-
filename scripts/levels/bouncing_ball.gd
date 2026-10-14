## Pelota de prueba que bota sin parar (solo para scenes/levels/debug_sandbox).
## No colisiona ni hace dano: sirve para VER la ralentizacion del Debug, porque
## integra su movimiento con WorldTime.scaled_delta().
class_name BouncingBall
extends Node2D

@export var radius_px: float = 24.0
## Altura del bote (px por encima de la posicion inicial, que es el suelo).
@export var bounce_height_px: float = 256.0
## Gravedad en px/s^2 de tiempo del mundo.
@export var gravity_px_s2: float = 1800.0
@export var color: Color = Color(1.0, 0.29, 0.16, 1.0)

var _floor_y: float
var _velocity_y: float = 0.0
## Segundos de tiempo del mundo acumulados (pruebas).
var _world_time: float = 0.0


func _ready() -> void:
	_floor_y = position.y
	_velocity_y = -_launch_speed()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `world_delta` segundos de tiempo del mundo.
func advance(world_delta: float) -> void:
	_world_time += world_delta
	_velocity_y += gravity_px_s2 * world_delta
	position.y += _velocity_y * world_delta
	if position.y >= _floor_y:
		position.y = _floor_y
		_velocity_y = -_launch_speed()


func get_world_time() -> float:
	return _world_time


func _launch_speed() -> float:
	return sqrt(2.0 * gravity_px_s2 * bounce_height_px)


func _draw() -> void:
	# El origen es el punto de apoyo: la pelota se dibuja por encima.
	draw_circle(Vector2(0.0, -radius_px), radius_px, color)
