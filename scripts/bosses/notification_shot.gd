## Notificacion de la rafaga de Alerta Mayor (fase 2, docs/propuesta-jefe-
## alerta-mayor.md §2.6; paso 7 de §6, 2026-10-21). Proyectil horizontal de
## size_px (1 x 0,5 tiles) que cruza un carril a speed_px_s desde `position`
## hacia `direction` hasta recorrer travel_px y desaparece. Familia del banner:
## no es un cuerpo (el laser lo atraviesa y el pulso no le afecta) y el dash lo
## atraviesa (Isak invulnerable: take_hit no hace nada). Tocarlo quita
## contact_damage de Sync Rate con el retroceso de siempre. Tiempo del mundo
## (el Debug lo ralentiza). Lo crea y configura AlertMajor; arte por script
## de tools/gen_boss_alert_major.py (definitivo desde el 2026-10-22).
class_name NotificationShot
extends Node2D

signal hit_player(amount: float)
signal finished

const TEXTURE_PATH: String = "res://assets/sprites/bosses/notification_shot.png"
const HELP_ID: String = "notification_shot"

## Centro del proyectil en `position`; avanza hacia direction (-1 / 1).
var direction: int = 1
var speed_px_s: float = 640.0
var travel_px: float = 1408.0
var size_px: Vector2 = Vector2(64.0, 32.0)
var contact_damage: float = 10.0
## Si es falso, _physics_process no avanza (pruebas: step).
var auto_process: bool = true
## Isak al que dana (si es null se busca en el nivel).
var target: Isak

var _travelled: float = 0.0
var _done: bool = false
var _sprite: Sprite2D

static var _texture: Texture2D


func _ready() -> void:
	if _texture == null and ResourceLoader.exists(TEXTURE_PATH):
		_texture = load(TEXTURE_PATH) as Texture2D
	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.flip_h = direction < 0
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if auto_process:
		step(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos del mundo.
func step(dt: float) -> void:
	if _done:
		return
	var move: float = minf(speed_px_s * dt, travel_px - _travelled)
	position.x += float(direction) * move
	_travelled += move
	var isak: Isak = _find_player()
	if isak != null and LevelLookup.isak_body_rect(isak).intersects(get_damage_rect()):
		if isak.take_hit(float(direction)):
			GameState.apply_sync_damage(contact_damage)
			hit_player.emit(contact_damage)
	if _travelled >= travel_px - 0.001:
		_done = true
		finished.emit()
		queue_free()


func is_done() -> bool:
	return _done


func get_damage_rect() -> Rect2:
	return Rect2(global_position - size_px * 0.5, size_px)


## Ayuda de Eco (tipo notification_shot, paso 12): mientras vuela.
func is_help_available() -> bool:
	return not _done


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target
