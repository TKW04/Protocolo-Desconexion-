## Interruptor laser (tipo `laser_switch`; acertijo de la azotea del 1-2,
## 2026-10-17, tanda H1 del paso 14; docs/propuesta-calc-encuentro.md). Como el
## lector laser (LaserReceiver: placa en el lado derecho de su celda, diana a la
## altura del celular de Isak de pie en esa celda, grupo laser_activatable) pero
## un impacto lo ACTIVA PARA SIEMPRE: sin ventana ni cable. El pulso no le hace
## nada. Activado no da Q. Con done_if_ally conocido arranca activado.
## El origen es la esquina superior izquierda de su celda.
class_name LaserSwitch
extends Area2D

const GROUP: StringName = &"laser_switch"
const LAYER_WORLD: int = 1

## Un disparo lo ha activado.
signal activated(id: StringName)

@export var object_id: StringName = &""
@export var done_if_ally: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("laser_switch")
var _active: bool = false
var _hits: int = 0
var _sprite: AnimatedSprite2D
var _time: float = 0.0
var _hit_time: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(CalcRoom.LINK_GROUP)
	add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	monitoring = false
	var r: Rect2 = get_local_hit_rect()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = load(PowerSwitch.FRAMES_PATH) as SpriteFrames
	_sprite.position = LaserReceiver._vec(_config.get("sprite_center_px", [48, 8]))
	_sprite.animation = &"laser_switch_idle"
	add_child(_sprite)
	if CalcRoom.skipped_for(done_if_ally):
		_active = true
	EventBus.laser_fired.connect(_on_laser_fired)
	advance(0.0)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


func is_activated() -> bool:
	return _active


func get_hit_count() -> int:
	return _hits


func get_animation() -> StringName:
	return _sprite.animation


## Ayuda de Eco (HelpCatalog.is_help_live): activado no ayuda.
func is_help_available() -> bool:
	return not _active


func get_local_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [32, -16, 32, 48])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func get_hit_rect() -> Rect2:
	var r: Rect2 = get_local_hit_rect()
	return Rect2(global_position + r.position, r.size)


## Impacto del laser (LaserProjectile): se activa para siempre.
func on_laser_hit(_damage: float, _source: Node) -> void:
	_hits += 1
	activate()


## Se activa (sin laser: lo usan las pruebas). Falso si ya lo estaba.
func activate() -> bool:
	if _active:
		return false
	_active = true
	_hit_time = 0.0
	activated.emit(object_id)
	return true


## Avanza `dt` segundos de tiempo del mundo (la animacion).
func advance(dt: float) -> void:
	_time += maxf(dt, 0.0)
	var frames: SpriteFrames = _sprite.sprite_frames
	var anim: StringName = &"laser_switch_on" if _active else &"laser_switch_idle"
	var t: float = _time
	if _hit_time >= 0.0:
		_hit_time += maxf(dt, 0.0)
		var length: float = frames.get_frame_count(&"laser_switch_hit") / frames.get_animation_speed(&"laser_switch_hit")
		if _hit_time < length:
			anim = &"laser_switch_hit"
			t = _hit_time
		else:
			_hit_time = -1.0
	if _sprite.animation != anim:
		_sprite.animation = anim
	var count: int = frames.get_frame_count(anim)
	var index: int = floori(t * frames.get_animation_speed(anim))
	_sprite.frame = index % count if frames.get_animation_loop(anim) else mini(index, count - 1)


## Isak dispara pegado (el celular ya dentro de la zona): el proyectil choca ya.
func _on_laser_fired(projectile: Node2D) -> void:
	if not _active and is_inside_tree() and projectile is LaserProjectile \
			and LaserProjectile.muzzle_crosses(projectile, get_hit_rect()):
		(projectile as LaserProjectile).strike(self)
