## Punto rojo (badge, Mundo 1; 1-2 piso 1). docs/mundo-1-notificaciones.md 6.2:
## "Persigue lentamente a Isak. Si lo alcanza, quita Sync Rate. Aturdir con el
## pulso o dejarlo atras con saltos". Paso 4 de docs/propuesta-1-2.md §10.
## Valores y explicacion en data/enemies/notification_badge.json.
##
## Estados:
## - idle: dormido en su sitio. Despierta (chase) si el centro de Isak esta a
##   menos de wake_radius_px y dentro de su correa.
## - chase: vuela (sin gravedad) hacia el centro de Isak a chase_speed_px_s; el
##   terreno lo para (move_and_slide contra world) y nunca sale de la correa
##   (rectangulo leash_width_px x leash_height_px centrado en su aparicion).
##   Tocarlo persiguiendo no dana: solo dana lanzado, tras el aviso.
## - anticipate: a menos de lunge_radius_px se para y se infla
##   anticipation_frames cuadros a anim_fps (AVISO de 6-12 cuadros).
## - lunge: se lanza lunge_s en linea recta hacia donde estaba Isak al acabar
##   el aviso; si toca a Isak le quita contact_damage de Sync Rate
##   (Isak.take_hit: invulnerabilidad breve ya existente).
## - recover: quieto recover_s y vuelve a chase.
## - return: Isak lejos (give_up_radius_px) o fuera de la correa: vuelve a su
##   sitio a return_speed_px_s y se duerme (idle).
## - stunned / wake: el pulso lo aturde stun_duration_s; quieto en el aire,
##   inofensivo y plataforma solida de una via; los ultimos wake_warn_frames
##   cuadros (wake) parpadea: aviso de que vuelve a perseguir.
## - popped: vida a 0 (solo el laser, y solo aturdido); suelta drops y se libera.
##
## LASER (decision 2026-10-16): despierto es INMUNE: on_laser_hit no resta vida
## y muestra la chispa gris (animacion deflect en el sprite Fx, senal
## deflected); el disparo choca con el y se consume (su energia ya se gasto al
## disparar). Aturdido (stunned o wake) recibe el dano normal.
##
## Tiempo: todo con WorldTime.scaled_delta (el Debug lo ralentiza x0,5).
## Capas: cuerpo en enemy con mascara world (el laser lo encuentra por la capa
## enemy); la plataforma en world. Isak se busca con una consulta a la capa player.
## Origen en los pies de su celda (abajo-centro); centro del cuerpo en center_y.
class_name NotificationBadge
extends CharacterBody2D

signal state_changed(previous: StringName, current: StringName)
## Ha danado a Isak (amount = Sync Rate restado).
signal hit_player(amount: float)
signal stunned
signal popped
signal damaged(amount: float, health_left: float)
## El laser le ha dado despierto: no le hace nada (chispa gris).
signal deflected

const STATE_IDLE: StringName = &"idle"
const STATE_CHASE: StringName = &"chase"
const STATE_ANTICIPATE: StringName = &"anticipate"
const STATE_LUNGE: StringName = &"lunge"
const STATE_RECOVER: StringName = &"recover"
const STATE_RETURN: StringName = &"return"
const STATE_STUNNED: StringName = &"stunned"
const STATE_WAKE: StringName = &"wake"
const STATE_POPPED: StringName = &"popped"

const ANIM_DEFLECT: StringName = &"deflect"
const ANIM_POP: StringName = &"pop"

const DEFAULT_DATA_PATH: String = "res://data/enemies/notification_badge.json"
## El mismo grupo que la Burbuja: LevelRunner llama a reset_patrol al reaparecer.
const GROUP: StringName = &"enemy"

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
## Altura del centro de Isak sobre sus pies (px; = isak_center_y_px de help.json).
const ISAK_CENTER_Y: float = -48.0
## Distancia a su sitio a la que se considera de vuelta (px).
const HOME_EPS_PX: float = 4.0
## Separacion horizontal de la chispa gris hacia el lado del disparo (px).
const DEFLECT_OFFSET_PX: float = 16.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH
## Liberar el nodo al acabar la animacion de pop (las pruebas pueden quitarlo).
@export var free_on_pop: bool = true
## Recargas que suelta al morir; vacio = seccion drops de data_path.
@export var drops: Dictionary = {}
## Vida maxima. Negativo = `health` de data_path; params.health del nivel la
## cambia tras _ready y vuelve a llenarla.
@export var max_health: float = -1.0:
	set(value):
		max_health = value
		if _health != null and value > 0.0:
			_health.reset(value)

# Ajustes (data_path; los params del nivel los sobrescriben por nombre).
var chase_speed_px_s: float
var return_speed_px_s: float
var wake_radius_px: float
var give_up_radius_px: float
var leash_width_px: float
var leash_height_px: float
var lunge_radius_px: float
var lunge_speed_px_s: float
var lunge_s: float
var recover_s: float
var contact_damage: float
var center_y: float
var body_size: Vector2
var damage_size: Vector2
var platform_top_px: float
var platform_width_px: float
var platform_thickness_px: float
var stun_duration_s: float
var anim_fps: float
var anticipation_frames: int
var wake_warn_frames: int
var laser_immune_awake: bool = true
var deflect_s: float = 0.33
var damage_flash_s: float = 0.3
var damage_flash_period_s: float = 0.08
var damage_flash_alpha: float = 0.35

## Isak al que persigue. Si es null se busca en la capa player.
var target: Isak

var _state: StringName = &""
var _spawn_position: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _stun_left: float = 0.0
var _pop_left: float = 0.0
var _deflect_left: float = 0.0
var _flash_left: float = 0.0
var _ready_ok: bool = false
var _health: EnemyHealth
var _query: PhysicsShapeQueryParameters2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _fx: AnimatedSprite2D = $Fx
@onready var _body_shape: CollisionShape2D = $BodyShape
@onready var _platform: StaticBody2D = $Platform
@onready var _platform_shape: CollisionShape2D = $Platform/CollisionShape2D


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	_platform.collision_layer = LAYER_WORLD
	_platform.collision_mask = 0
	add_collision_exception_with(_platform)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_setup_shapes()
	_spawn_position = global_position
	_fx.visible = false
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	_change_state(STATE_IDLE)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_sprite.speed_scale = WorldTime.scale()
	_fx.speed_scale = WorldTime.scale()
	_update_flash(dt)
	_update_deflect(dt)
	var isak: Isak = _find_player()
	match _state:
		STATE_IDLE:
			_move(Vector2.ZERO)
			if _should_chase(isak):
				_change_state(STATE_CHASE)
		STATE_CHASE:
			if not _should_chase(isak, true):
				_change_state(STATE_RETURN)
			else:
				var to: Vector2 = _isak_center(isak) - get_center()
				if to.length() <= lunge_radius_px:
					_move(Vector2.ZERO)
					_timer = get_anticipation_s()
					_change_state(STATE_ANTICIPATE)
				else:
					_move(to.normalized() * chase_speed_px_s)
		STATE_ANTICIPATE:
			_move(Vector2.ZERO)
			_timer -= dt
			if isak != null:
				var aim: Vector2 = _isak_center(isak) - get_center()
				if aim.length() > 0.5:
					_lunge_dir = aim.normalized()
			if _timer <= 0.0:
				_timer = lunge_s
				_change_state(STATE_LUNGE)
		STATE_LUNGE:
			_move(_lunge_dir * lunge_speed_px_s)
			_timer -= dt
			if isak != null and _check_hit(isak):
				_timer = 0.0
			if _timer <= 0.0:
				_timer = recover_s
				_change_state(STATE_RECOVER)
		STATE_RECOVER:
			_move(Vector2.ZERO)
			_timer -= dt
			if _timer <= 0.0:
				_change_state(STATE_CHASE)
		STATE_RETURN:
			var home: Vector2 = _spawn_position - global_position
			if _should_chase(isak):
				_change_state(STATE_CHASE)
			elif home.length() <= maxf(HOME_EPS_PX, return_speed_px_s * dt):
				global_position = _spawn_position
				_move(Vector2.ZERO)
				_change_state(STATE_IDLE)
			else:
				_move(home.normalized() * return_speed_px_s)
		STATE_STUNNED, STATE_WAKE:
			_move(Vector2.ZERO)
			_stun_left -= dt
			if _stun_left <= 0.0:
				_change_state(STATE_CHASE)
			elif _state == STATE_STUNNED and _stun_left <= get_wake_warn_s():
				_change_state(STATE_WAKE)
		STATE_POPPED:
			_pop_left -= dt
			if _pop_left <= 0.0 and free_on_pop:
				queue_free()


# --- Consultas ---

func get_state() -> StringName:
	return _state


## Ayuda de Eco (HelpCatalog.is_help_live): mientras exista y no este derrotado
## (dormido, persiguiendo o aturdido sigue siendo un punto rojo).
func is_help_available() -> bool:
	return _state != STATE_POPPED


## Verdadero si tocarlo hace dano: solo lanzado (tras el aviso).
func is_dangerous() -> bool:
	return _state == STATE_LUNGE


func is_platform() -> bool:
	return _state == STATE_STUNNED or _state == STATE_WAKE


func is_stunned() -> bool:
	return is_platform()


## Verdadero si el laser le hace dano ahora (aturdido) o no (despierto).
func is_laser_vulnerable() -> bool:
	return is_stunned() or not laser_immune_awake


func is_defeated() -> bool:
	return _state == STATE_POPPED


func get_spawn_position() -> Vector2:
	return _spawn_position


## Centro del cuerpo (global).
func get_center() -> Vector2:
	return global_position + Vector2(0.0, center_y)


func get_body_rect() -> Rect2:
	return Rect2(get_center() - body_size * 0.5, body_size)


func get_damage_rect() -> Rect2:
	return Rect2(get_center() - damage_size * 0.5, damage_size)


func get_leash_rect() -> Rect2:
	var size := Vector2(leash_width_px, leash_height_px)
	return Rect2(_spawn_position + Vector2(0.0, center_y) - size * 0.5, size)


func get_platform_top_y() -> float:
	return global_position.y - platform_top_px


func get_anticipation_s() -> float:
	return float(anticipation_frames) / anim_fps


func get_wake_warn_s() -> float:
	return float(wake_warn_frames) / anim_fps


func get_stun_left() -> float:
	return _stun_left


func get_animation() -> StringName:
	return _sprite.animation


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_max_health() -> float:
	return _health.max_health if _health != null else 0.0


func is_flashing() -> bool:
	return _flash_left > 0.0


## Verdadero mientras se ve la chispa gris de un disparo que no le hace nada.
func is_deflecting() -> bool:
	return _deflect_left > 0.0


# --- Acciones ---

## Interfaz del laser (LaserProjectile). Despierto: chispa gris, sin dano.
func on_laser_hit(damage: float, source: Node) -> void:
	if not _ready_ok or _state == STATE_POPPED:
		return
	if not is_laser_vulnerable():
		_deflect(source)
		return
	take_damage(damage)


## Resta vida (parpadeo); a 0 muere. Verdadero si el golpe cuenta.
func take_damage(amount: float) -> bool:
	if not _ready_ok or _state == STATE_POPPED or amount <= 0.0:
		return false
	var dies: bool = _health.take_damage(amount)
	_flash_left = damage_flash_s
	damaged.emit(amount, _health.health)
	if dies:
		pop()
	return true


## Aturde (o reinicia el aturdimiento). Sin efecto si ya ha muerto.
func stun() -> void:
	if _state == STATE_POPPED:
		return
	_stun_left = stun_duration_s
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_POPPED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun()
	return true


## Reaparicion de Isak (LevelRunner): vuelve a su sitio, dormido, con la vida
## llena. Si ha muerto sigue muerto (como la Burbuja reventada).
func reset_patrol() -> void:
	if not _ready_ok or _state == STATE_POPPED:
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_timer = 0.0
	_stun_left = 0.0
	_flash_left = 0.0
	_sprite.self_modulate.a = 1.0
	_health.reset(_health.max_health)
	_change_state(STATE_IDLE)


## Muere: suelta sus drops y se libera al acabar la animacion.
func pop() -> void:
	if _state == STATE_POPPED:
		return
	_flash_left = 0.0
	_sprite.self_modulate.a = 1.0
	_change_state(STATE_POPPED)
	popped.emit()
	EventBus.enemy_defeated.emit(self)
	RechargePickup.spawn_drops(get_parent(), get_center(), drops)


# --- Interno ---

func _change_state(next: StringName) -> void:
	var previous: StringName = _state
	_state = next
	_platform_shape.disabled = not is_platform()
	match next:
		STATE_IDLE, STATE_RETURN:
			_play(&"idle")
		STATE_CHASE, STATE_RECOVER:
			_stun_left = 0.0
			_play(&"chase")
		STATE_ANTICIPATE:
			_play(&"anticipate")
		STATE_LUNGE:
			_play(&"lunge")
		STATE_STUNNED:
			_play(&"stunned")
		STATE_WAKE:
			_play(&"wake")
		STATE_POPPED:
			_body_shape.set_deferred(&"disabled", true)
			_pop_left = _anim_length(ANIM_POP)
			_play(ANIM_POP)
	state_changed.emit(previous, next)


func _play(anim: StringName) -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_sprite.set_frame_and_progress(0, 0.0)


func _anim_length(anim: StringName) -> float:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return 0.0
	return float(frames.get_frame_count(anim)) / frames.get_animation_speed(anim)


## Mueve con velocidad en tiempo del mundo y lo mantiene dentro de la correa.
func _move(world_velocity: Vector2) -> void:
	velocity = world_velocity * WorldTime.scale()
	if world_velocity != Vector2.ZERO:
		move_and_slide()
	var leash: Rect2 = get_leash_rect()
	var c: Vector2 = get_center()
	var clamped := Vector2(clampf(c.x, leash.position.x, leash.end.x), clampf(c.y, leash.position.y, leash.end.y))
	if clamped != c:
		global_position += clamped - c


func _isak_center(isak: Isak) -> Vector2:
	return isak.global_position + Vector2(0.0, ISAK_CENTER_Y)


## Verdadero si debe perseguir a `isak`: vivo, dentro de la correa y a menos de
## wake_radius_px (o de give_up_radius_px si ya lo perseguia).
func _should_chase(isak: Isak, chasing: bool = false) -> bool:
	if isak == null or isak.is_dead():
		return false
	var center: Vector2 = _isak_center(isak)
	if not get_leash_rect().has_point(center):
		return false
	var radius: float = give_up_radius_px if chasing else wake_radius_px
	return center.distance_to(get_center()) <= radius


func _check_hit(isak: Isak) -> bool:
	var feet: Vector2 = isak.global_position
	var hurt := Rect2(feet + Vector2(-isak.hitbox_size.x * 0.5, -isak.hitbox_size.y), isak.hitbox_size)
	if not hurt.intersects(get_damage_rect()):
		return false
	var direction: float = signf(_lunge_dir.x)
	if is_zero_approx(direction):
		direction = signf(isak.global_position.x - global_position.x)
	if not isak.take_hit(direction):
		return false
	GameState.apply_sync_damage(contact_damage)
	hit_player.emit(contact_damage)
	return true


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = null
	if not is_inside_tree():
		return null
	_query.transform = Transform2D(0.0, get_center())
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, 4):
		var isak := hit.get("collider") as Isak
		if isak != null:
			target = isak
			return isak
	return null


func _deflect(source: Node) -> void:
	var side: float = 0.0
	if source is Node2D and is_instance_valid(source):
		side = signf((source as Node2D).global_position.x - global_position.x)
	_fx.position = Vector2(side * DEFLECT_OFFSET_PX, center_y)
	_fx.visible = true
	if _fx.sprite_frames != null and _fx.sprite_frames.has_animation(ANIM_DEFLECT):
		_fx.play(ANIM_DEFLECT)
		_fx.set_frame_and_progress(0, 0.0)
	_deflect_left = deflect_s
	deflected.emit()


func _update_deflect(dt: float) -> void:
	if _deflect_left <= 0.0:
		return
	_deflect_left = maxf(_deflect_left - dt, 0.0)
	if _deflect_left <= 0.0:
		_fx.visible = false


func _update_flash(dt: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - dt, 0.0)
	var dim: bool = _flash_left > 0.0 and fmod(_flash_left, damage_flash_period_s) < damage_flash_period_s * 0.5
	_sprite.self_modulate.a = damage_flash_alpha if dim else 1.0


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


func _setup_shapes() -> void:
	var body := RectangleShape2D.new()
	body.size = body_size
	_body_shape.shape = body
	_body_shape.position = Vector2(0.0, center_y)
	var plank := RectangleShape2D.new()
	plank.size = Vector2(platform_width_px, platform_thickness_px)
	_platform_shape.shape = plank
	_platform_shape.one_way_collision = true
	_platform_shape.position = Vector2(0.0, -platform_top_px + platform_thickness_px * 0.5)
	_platform_shape.disabled = true
	var area := CircleShape2D.new()
	area.radius = maxf(wake_radius_px, give_up_radius_px) + 64.0
	_query = PhysicsShapeQueryParameters2D.new()
	_query.shape = area
	_query.collision_mask = LAYER_PLAYER
	_query.collide_with_bodies = true
	_query.collide_with_areas = false


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("NotificationBadge: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	chase_speed_px_s = float(d["chase_speed_px_s"])
	return_speed_px_s = float(d["return_speed_px_s"])
	wake_radius_px = float(d["wake_radius_px"])
	give_up_radius_px = float(d["give_up_radius_px"])
	leash_width_px = float(d["leash_width_px"])
	leash_height_px = float(d["leash_height_px"])
	lunge_radius_px = float(d["lunge_radius_px"])
	lunge_speed_px_s = float(d["lunge_speed_px_s"])
	lunge_s = float(d["lunge_s"])
	recover_s = float(d["recover_s"])
	contact_damage = float(d["contact_damage"])
	center_y = float(d["center_y"])
	body_size = Vector2(float(d["body_size"][0]), float(d["body_size"][1]))
	damage_size = Vector2(float(d["damage_size"][0]), float(d["damage_size"][1]))
	platform_top_px = float(d["platform_top_px"])
	platform_width_px = float(d["platform_width_px"])
	platform_thickness_px = float(d["platform_thickness_px"])
	stun_duration_s = float(d["stun_duration_s"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	wake_warn_frames = int(d["wake_warn_frames"])
	laser_immune_awake = bool(d.get("laser_immune_awake", true))
	deflect_s = float(d.get("deflect_s", deflect_s))
	damage_flash_s = float(d.get("damage_flash_s", damage_flash_s))
	damage_flash_alpha = float(d.get("damage_flash_alpha", damage_flash_alpha))
	damage_flash_period_s = maxf(float(d.get("damage_flash_period_s", damage_flash_period_s)), 0.001)
	if max_health <= 0.0:
		max_health = float(d["health"])
	_health = EnemyHealth.new(max_health)
	if drops.is_empty():
		drops = EnemyHealth.parse_drops(d.get("drops", {}))
	var frames: SpriteFrames = load(String(d["sprites"]["frames_resource"])) as SpriteFrames
	if frames != null:
		_sprite.sprite_frames = frames
		_fx.sprite_frames = frames
	return true
