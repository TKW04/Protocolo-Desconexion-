## Copia de Alerta Mayor en la fase 3 (docs/propuesta-jefe-alerta-mayor.md
## §2.7; paso 8 de §6, 2026-10-21). Un badge desinflado IGUAL que el real (solo
## el Debug distingue la real: la copia no tiene nucleo). AlertMajor la mueve
## (bajar a su sitio, lanzarse contra Isak, volver, subir) y comprueba el dano
## de sus lanzamientos; aqui solo esta el cuerpo y su descarte: un pulso que
## alcanza su cuerpo o un laser que lo toca la DESCARTA con un «pop» (señal
## discarded; el jefe suelta una Burbuja en su sitio, decision 6). Sin
## colision fisica (el dash la atraviesa). Arte PROVISIONAL (_placeholder) de
## tools/gen_boss_alert_major.py.
class_name AlertMajorClone
extends Node2D

## Golpeada por el pulso o el laser (`source`): se descarta.
signal discarded(clone: AlertMajorClone)

const GROUP_LASER_ACTIVATABLE: StringName = &"laser_activatable"
const LAYER_ENEMY: int = 4
const ART_DIR: String = "res://assets/sprites/bosses/"
const POP_S: float = 0.3

## Tamano del cuerpo (px, el del jefe desinflado).
var body_size: Vector2 = Vector2(128.0, 128.0)
var draw_scale: float = 2.0

var _sprite: Sprite2D
var _hurt: Area2D
var _shape: CollisionShape2D
var _popped: bool = false
var _pop_left: float = 0.0
var _lunging: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.texture = load(ART_DIR + "alert_major_clone_placeholder.png") as Texture2D
	_sprite.scale = Vector2(draw_scale, draw_scale)
	add_child(_sprite)
	_hurt = _HurtRelay.new()
	_hurt.name = "Hurt"
	_hurt.collision_layer = LAYER_ENEMY
	_hurt.collision_mask = 0
	_hurt.monitoring = false
	_hurt.monitorable = true
	_hurt.add_to_group(GROUP_LASER_ACTIVATABLE)
	_hurt.set_meta(&"clone", self)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect
	_hurt.add_child(_shape)
	add_child(_hurt)
	EventBus.pulse_fired.connect(receive_pulse)


func _process(delta: float) -> void:
	if _popped:
		_pop_left -= WorldTime.scaled_delta(delta)
		if _pop_left <= 0.0:
			queue_free()


func is_popped() -> bool:
	return _popped


func get_body_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)


## Aspecto de lanzamiento (estirada) o de reposo.
func set_lunging(on: bool) -> void:
	_lunging = on
	if _sprite != null and not _popped:
		_sprite.texture = load(ART_DIR + ("alert_major_lunge_placeholder.png" if on
			else "alert_major_clone_placeholder.png")) as Texture2D


## Interfaz del laser (LaserProjectile, por el Area2D Hurt): se descarta.
func on_laser_hit(_damage: float, _source: Node) -> void:
	discard(true)


## Un pulso que alcanza su cuerpo la descarta. Verdadero si la alcanza.
func receive_pulse(area: Area2D) -> bool:
	if _popped or area == null or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	discard(true)
	return true


## Se descarta con un «pop»; `notify`: avisa al jefe (Burbuja). Sin notify (golpe
## final) solo hace el pop.
func discard(notify: bool) -> void:
	if _popped:
		return
	_popped = true
	_pop_left = POP_S
	_shape.set_deferred(&"disabled", true)
	_hurt.collision_layer = 0
	_sprite.texture = load(ART_DIR + "alert_major_pop_placeholder.png") as Texture2D
	if EventBus.pulse_fired.is_connected(receive_pulse):
		EventBus.pulse_fired.disconnect(receive_pulse)
	if notify:
		discarded.emit(self)


## El Area2D del cuerpo pasa los golpes del laser a la copia.
class _HurtRelay extends Area2D:
	func on_laser_hit(damage: float, source: Node) -> void:
		var clone: Variant = get_meta(&"clone", null)
		if clone != null and is_instance_valid(clone):
			(clone as AlertMajorClone).on_laser_hit(damage, source)
