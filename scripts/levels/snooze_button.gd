## Boton Posponer (tipo `snooze_button` del catalogo del Mundo 1; patron 3
## «Posponer» de docs/propuesta-1-2.md §0.4 y piso 3, §3.3; paso 6 de §10).
##
## - Objetivo del LASER (Area2D en la capa world y en el grupo
##   laser_activatable): placa con un boton redondo y una diana cian a la
##   altura del celular de Isak de pie en el suelo de su celda (como el lector
##   laser). El pulso no le hace nada.
## - Enlaces: target_groups (params.targets), grupos de recordatorios
##   (ReminderPlatform.group_id) del mismo nivel.
## - Un impacto con algun recordatorio enlazado CONTANDO: les suma extend_s
##   (ReminderPlatform.extend) sin pasar de cap_s de cuenta, sale el «Zzz» y
##   el boton se enfria cooldown_s (tiempo del mundo; un impacto enfriandose no
##   hace nada: chispa gris). Asi no se pospone sin fin gratis: el tope limita
##   la cuenta y cada disparo cuesta energia.
## - Sin nada contando (en reposo, ya caidos o volviendo): chispa gris «nada
##   que posponer» y no se enfria.
## - Aspecto: apagado (wait) si sus grupos no cuentan; diana cian que late
##   (ready) si cuentan; golpe (hit) y enfriamiento con el anillo que se rellena.
## - Al reaparecer Isak vuelve a estar listo (sin enfriamiento).
## El origen del nodo es la esquina superior izquierda de su celda.
class_name SnoozeButton
extends Area2D

enum State { READY, HIT, COOLDOWN }

const GROUP: StringName = &"snooze_button"
const LAYER_WORLD: int = 1

## Ha pospuesto `count` recordatorios.
signal snoozed(count: int)
## Impacto sin nada que posponer (o enfriandose): chispa gris.
signal nothing_to_snooze

@export var object_id: StringName = &""
## Grupos de recordatorios que pospone (params.targets).
@export var target_groups: Array = []
## Segundos que suma cada impacto (tiempo del mundo).
@export var extend_s: float = 4.0
## Tope de la cuenta tras posponer.
@export var cap_s: float = 8.0
## Enfriamiento tras un impacto valido.
@export var cooldown_s: float = 1.0

## Numero de cada impacto valido (una cuenta compartida solo se alarga una vez por impacto).
static var _serial: int = 0

var _config: Dictionary = World1ObjectsConfig.section("snooze_button")
var _state: State = State.READY
var _state_time: float = 0.0
var _time: float = 0.0
var _sprite: AnimatedSprite2D
var _spark: EnergySprite
var _spark_time: float = -1.0
var _hits: int = 0
var _snoozes: int = 0


func _ready() -> void:
	add_to_group(GROUP)
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
	_sprite.sprite_frames = load(String(_config.get("frames", ""))) as SpriteFrames
	_sprite.position = LaserReceiver._vec(_config.get("sprite_center_px", [32, 8]))
	add_child(_sprite)
	_spark = EnergySprite.attach(self, &"gray_spark", _sprite.position, false,
		String(_config.get("spark_frames", "")))
	_spark.name = "Spark"
	_spark.visible = false
	EventBus.laser_fired.connect(_on_laser_fired)
	EventBus.player_respawned.connect(func(_at: Vector2, _d: bool) -> void: reset())
	_update_visual()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


func is_cooling_down() -> bool:
	return _state != State.READY


## Algun recordatorio enlazado esta contando.
func has_counting_target() -> bool:
	for reminder: ReminderPlatform in get_targets():
		if reminder.is_counting():
			return true
	return false


## Recordatorios de sus grupos (del mismo nivel).
func get_targets() -> Array[ReminderPlatform]:
	var out: Array[ReminderPlatform] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group(ReminderPlatform.GROUP):
		var reminder := node as ReminderPlatform
		if reminder != null and links_group(reminder.group_id) \
				and reminder.get_parent() == get_parent():
			out.append(reminder)
	return out


## `group` esta en sus enlaces (textos o StringName).
func links_group(group: StringName) -> bool:
	for g: Variant in target_groups:
		if String(g) == String(group):
			return true
	return false


func get_hit_count() -> int:
	return _hits


func get_snooze_count() -> int:
	return _snoozes


func is_sparking() -> bool:
	return _spark_time >= 0.0


## Animacion que se ve (pruebas y capturas).
func get_animation() -> StringName:
	return _sprite.animation


## Ayuda de Eco: se puede usar siempre (reutilizable), asi que siempre ayuda.
func is_help_available() -> bool:
	return true


func get_local_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [8, -16, 48, 48])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func get_hit_rect() -> Rect2:
	var r: Rect2 = get_local_hit_rect()
	return Rect2(global_position + r.position, r.size)


# --- Acciones ---

## Impacto del laser.
func on_laser_hit(_damage: float, _source: Node) -> void:
	_hits += 1
	snooze()


## Pospone sus recordatorios que cuentan. Verdadero si ha pospuesto alguno.
func snooze() -> bool:
	if _state != State.READY:
		_spark_now()
		nothing_to_snooze.emit()
		return false
	var count: int = 0
	_serial += 1
	for reminder: ReminderPlatform in get_targets():
		if reminder.extend(extend_s, cap_s, _serial):
			count += 1
	if count == 0:
		_spark_now()
		nothing_to_snooze.emit()
		return false
	_snoozes += 1
	_set_state(State.HIT)
	snoozed.emit(count)
	return true


## Listo, sin enfriamiento ni chispa.
func reset() -> void:
	_spark_time = -1.0
	if _spark != null:
		_spark.visible = false
	_set_state(State.READY)


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += dt
	_state_time += dt
	match _state:
		State.HIT:
			if _state_time >= _anim_length(&"snooze_hit"):
				_set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_time >= maxf(cooldown_s - _anim_length(&"snooze_hit"), 0.0):
				_set_state(State.READY)
	if _spark_time >= 0.0:
		_spark_time += dt
		var fps: float = _spark.sprite_frames.get_animation_speed(&"gray_spark")
		var f: int = floori(_spark_time * fps)
		if f >= _spark.sprite_frames.get_frame_count(&"gray_spark"):
			_spark_time = -1.0
			_spark.visible = false
		else:
			_spark.frame = f
	_update_visual()


# --- Interno ---

func _spark_now() -> void:
	_spark_time = 0.0
	_spark.visible = true
	_spark.frame = 0


func _set_state(next: State) -> void:
	_state = next
	_state_time = 0.0
	_update_visual()


func _anim_length(anim: StringName) -> float:
	var frames: SpriteFrames = _sprite.sprite_frames
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.01)


func _update_visual() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = _sprite.sprite_frames
	match _state:
		State.READY:
			if has_counting_target():
				_sprite.animation = &"snooze_ready"
				_sprite.frame = floori(_time * frames.get_animation_speed(&"snooze_ready")) % 2
			else:
				_sprite.animation = &"snooze_wait"
				_sprite.frame = 0
		State.HIT:
			_sprite.animation = &"snooze_hit"
			_sprite.frame = mini(floori(_state_time * frames.get_animation_speed(&"snooze_hit")), 2)
		State.COOLDOWN:
			_sprite.animation = &"snooze_cooldown"
			var length: float = maxf(cooldown_s - _anim_length(&"snooze_hit"), 0.01)
			_sprite.frame = clampi(floori(_state_time / length * 4.0), 0, 3)


## Isak dispara pegado al boton: el proyectil choca ya (como el lector laser).
func _on_laser_fired(projectile: Node2D) -> void:
	if is_inside_tree() and projectile is LaserProjectile \
			and LaserProjectile.muzzle_crosses(projectile, get_hit_rect()):
		(projectile as LaserProjectile).strike(self)
