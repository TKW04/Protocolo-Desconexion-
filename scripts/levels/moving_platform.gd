## Plataforma movil simple de ida y vuelta. Es un objeto del MUNDO: avanza con
## WorldTime.scaled_delta(), asi que el Debug Mode la ralentiza (x0,5) sin
## tocar a Isak. Ejemplo de referencia para enemigos y proyectiles futuros.
## Cinta con vuelta (2026-10-23, arena de Autoplay, docs/propuesta-mundo-2.md
## §5.2): con `wrap` no va y vuelve: avanza siempre hacia `travel` y al llegar
## al final reaparece en el principio; el paso en que salta va sin colision (no
## arrastra a Isak). `speed_scale` multiplica la velocidad (fase 3: x2),
## `one_way` la hace de una via y `texture` se dibuja en vez del rectangulo.
class_name MovingPlatform
extends AnimatableBody2D

## Tamano en px; el origen es el centro.
@export var size: Vector2 = Vector2(192.0, 32.0)
## Desplazamiento maximo desde la posicion inicial (px).
@export var travel: Vector2 = Vector2(384.0, 0.0)
## Velocidad en px/s de tiempo del mundo.
@export var speed_px_s: float = 160.0
@export var color: Color = Color(0.36, 0.42, 0.5, 1.0)
@export var wrap: bool = false
@export var one_way: bool = false
@export var texture: Texture2D
## Multiplica speed_px_s (cinta de Autoplay: x2 en la fase 3).
var speed_scale: float = 1.0
var _shape: CollisionShape2D
## Cinta: tras saltar al principio, la colision vuelve en el paso siguiente.
var _rejoin: bool = false

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
	shape.one_way_collision = one_way
	add_child(shape)
	_shape = shape


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `world_delta` segundos de tiempo del mundo.
func advance(world_delta: float) -> void:
	var length: float = travel.length()
	if length <= 0.0:
		return
	if wrap:
		_advance_wrap(world_delta, length)
		return
	_cycle_px = fmod(_cycle_px + speed_px_s * world_delta, 2.0 * length)
	var along: float = _cycle_px if _cycle_px <= length else 2.0 * length - _cycle_px
	_offset = travel * (along / length)
	position = _origin + _offset


## Posicion inicial (local al padre); con sync_to_physics la del nodo va un
## paso de fisica por detras: la actual es get_origin() + get_offset().
func get_origin() -> Vector2:
	return _origin


## Cinta: recorrido dentro del ciclo (px desde el principio, 0 a |travel|).
func get_cycle_px() -> float:
	return _cycle_px


## Cinta: coloca la plataforma a `px` del principio (sin colision ese paso si salta).
func set_cycle_px(px: float) -> void:
	var length: float = travel.length()
	if length <= 0.0:
		return
	_cycle_px = fposmod(px, length)
	_offset = travel * (_cycle_px / length)
	position = _origin + _offset


func is_colliding_enabled() -> bool:
	return _shape != null and not _shape.disabled


func _advance_wrap(world_delta: float, length: float) -> void:
	if _rejoin and _shape != null:
		_shape.disabled = false
		_rejoin = false
	var next: float = _cycle_px + speed_px_s * speed_scale * world_delta
	if next >= length or next < 0.0:
		if _shape != null:
			_shape.disabled = true
		_rejoin = true
	_cycle_px = fposmod(next, length)
	_offset = travel * (_cycle_px / length)
	position = _origin + _offset


## Desplazamiento actual respecto a la posicion inicial (px).
func get_offset() -> Vector2:
	return _offset


func _draw() -> void:
	if texture != null:
		draw_texture(texture, -texture.get_size() * 0.5)
		return
	draw_rect(Rect2(-size * 0.5, size), color)
