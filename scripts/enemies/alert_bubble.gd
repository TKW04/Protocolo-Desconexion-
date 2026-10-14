## Burbuja de alerta (Mundo 1). docs/mundo-1-notificaciones.md 6.2: "Patrulla de
## lado a lado. Hace dano al contacto. Pulso para aturdir y pasar, o saltar sobre
## ella aturdida." Valores en data/enemies/alert_bubble.json (propuestas A2, A5,
## A6, A7 marcadas alli).
##
## Estados:
## - patrol: va por el suelo y gira en paredes, bordes y el limite de su rango.
##   Dana al contacto por cualquier lado, tambien desde arriba (C7).
## - stunned: el pulso la aturde (stun_duration_s). Quieta, inofensiva y
##   plataforma solida de una via.
## - anticipate: los ultimos anticipation_frames cuadros (a anim_fps) del
##   aturdimiento: avisa de que vuelve a ser peligrosa (A8). Sigue inofensiva y
##   pisable. Al terminar vuelve a patrol y el dano es posible otra vez.
## - popped: Isak cayo sobre ella aturdida con velocidad vertical >=
##   pop_speed_threshold_px_s: revienta, Isak rebota y el nodo se libera al
##   acabar la animacion. Por debajo del umbral Isak solo la pisa (C7).
##
## Tiempo: todo avanza con WorldTime.scaled_delta (el Debug la ralentiza x0,5).
## Capas (project.godot): cuerpo en enemy (no choca con Isak) y mascara world;
## la plataforma esta en world (Isak la pisa). Isak se encuentra con una consulta
## a la capa player. El pulso llega por EventBus.pulse_fired(area) y se comprueba
## con el radio real de la PulseArea (PulseReceiver.pulse_reaches).
## El origen son los pies (abajo-centro), como Isak.
class_name AlertBubble
extends CharacterBody2D

signal state_changed(previous: StringName, current: StringName)
## Ha danado a Isak (amount = Sync Rate restado).
signal hit_player(amount: float)
signal stunned
signal popped

const STATE_PATROL: StringName = &"patrol"
const STATE_STUNNED: StringName = &"stunned"
const STATE_ANTICIPATE: StringName = &"anticipate"
const STATE_POPPED: StringName = &"popped"

const ANIM_IDLE: StringName = &"idle"
const ANIM_STUNNED: StringName = &"stunned"
const ANIM_ANTICIPATE: StringName = &"anticipate"
const ANIM_POP: StringName = &"pop"

const DEFAULT_DATA_PATH: String = "res://data/enemies/alert_bubble.json"
const GROUP: StringName = &"enemy"

## Bits de capa de fisica (nombres en project.godot, [layer_names]).
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_PULSE: int = 8

## Margen alrededor de la burbuja en el que se busca a Isak (px). No es un
## valor de juego: solo tiene que cubrir a Isak de pie sobre la plataforma.
const QUERY_MARGIN_PX: float = 160.0
## Separacion del rayo que detecta el borde respecto al costado del cuerpo (px).
const EDGE_PROBE_INSET_PX: float = 2.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH
## Ancho total del recorrido de patrulla centrado en el punto de aparicion (A7:
## lo fija el nivel). Negativo = valor de data_path.
@export var patrol_range_px: float = -1.0
## Direccion inicial (1 derecha, -1 izquierda).
@export var start_direction: float = 1.0
## Liberar el nodo al acabar la animacion de pop (las pruebas pueden quitarlo).
@export var free_on_pop: bool = true

var speed_px_s: float
var gravity: float
var max_fall_speed_px_s: float
var edge_probe_depth_px: float
var contact_damage: float
var body_size: Vector2
var damage_size: Vector2
var damage_center_y: float
var platform_top_px: float
var platform_width_px: float
var platform_thickness_px: float
var stun_duration_s: float
var anim_fps: float
var anticipation_frames: int
var pop_speed_threshold_px_s: float
var pop_bounce_velocity: float
var stomp_tolerance_px: float

## Isak al que afecta. Si es null se busca con una consulta a la capa player
## alrededor de la burbuja y se recuerda (el resto de comprobaciones son
## geometricas con su hitbox, asi no dependen del retraso de un paso de la
## fase ancha de la fisica).
var target: Isak

var _state: StringName = &""
var _direction: float = 1.0
var _origin_x: float = 0.0
## Velocidad en px/s de tiempo del mundo (sin escalar).
var _world_velocity: Vector2 = Vector2.ZERO
var _stun_left: float = 0.0
var _pop_left: float = 0.0
var _has_prev: bool = false
var _prev_target_vy: float = 0.0
var _prev_target_feet_y: float = 0.0
var _ready_ok: bool = false
var _query: PhysicsShapeQueryParameters2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
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
	_setup_shapes()
	_direction = 1.0 if start_direction >= 0.0 else -1.0
	_origin_x = global_position.x
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	_change_state(STATE_PATROL)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso completo con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_sprite.speed_scale = WorldTime.scale()
	match _state:
		STATE_PATROL:
			_move(dt, _direction * speed_px_s)
			_update_direction()
		STATE_STUNNED, STATE_ANTICIPATE:
			_move(dt, 0.0)
			_stun_left -= dt
			if _stun_left <= 0.0:
				_change_state(STATE_PATROL)
			elif _state == STATE_STUNNED and _stun_left <= get_anticipation_s():
				_change_state(STATE_ANTICIPATE)
		STATE_POPPED:
			_pop_left -= dt
			if _pop_left <= 0.0 and free_on_pop:
				queue_free()
			return
	_check_player(delta)


# --- Consultas ---

func get_state() -> StringName:
	return _state


## Verdadero si tocarla hace dano (solo patrullando).
func is_dangerous() -> bool:
	return _state == STATE_PATROL


## Verdadero si es una plataforma solida de una via (aturdida o avisando).
func is_platform() -> bool:
	return _state == STATE_STUNNED or _state == STATE_ANTICIPATE


func is_stunned() -> bool:
	return is_platform()


func get_direction() -> float:
	return _direction


## Segundos de tiempo del mundo que quedan de aturdimiento (aviso incluido).
func get_stun_left() -> float:
	return _stun_left


## Duracion de la anticipacion (fin del aturdimiento): cuadros / fps.
func get_anticipation_s() -> float:
	return float(anticipation_frames) / anim_fps


## Y global de la superficie de la plataforma.
func get_platform_top_y() -> float:
	return global_position.y - platform_top_px


## Zona de dano en coordenadas globales.
func get_damage_rect() -> Rect2:
	return Rect2(global_position + Vector2(-damage_size.x * 0.5, damage_center_y - damage_size.y * 0.5), damage_size)


## Cuerpo visible en coordenadas globales (lo que alcanza el pulso).
func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


func get_animation() -> StringName:
	return _sprite.animation


# --- Acciones ---

## Aturde (o reinicia el aturdimiento). Sin efecto si ya ha reventado.
func stun() -> void:
	if _state == STATE_POPPED:
		return
	_stun_left = stun_duration_s
	_change_state(STATE_STUNNED)
	stunned.emit()


## Comprueba si el pulso (`area`, con un CircleShape2D) la alcanza y la aturde.
func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_POPPED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun()
	return true


## Revienta y hace rebotar a `bouncer` (si lo hay).
func pop(bouncer: Isak = null) -> void:
	if _state == STATE_POPPED:
		return
	_change_state(STATE_POPPED)
	if bouncer != null:
		bouncer.velocity.y = pop_bounce_velocity
	popped.emit()
	EventBus.enemy_defeated.emit(self)


# --- Interno ---

func _change_state(next: StringName) -> void:
	var previous: StringName = _state
	_state = next
	_platform_shape.disabled = not is_platform()
	match next:
		STATE_PATROL:
			_stun_left = 0.0
			_play(ANIM_IDLE)
		STATE_STUNNED:
			_world_velocity.x = 0.0
			_play(ANIM_STUNNED)
		STATE_ANTICIPATE:
			_play(ANIM_ANTICIPATE)
		STATE_POPPED:
			_body_shape.disabled = true
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


## Mueve con velocidad en tiempo del mundo; move_and_slide usa el delta real,
## asi que la velocidad se escala al moverse y no se guarda escalada.
func _move(dt: float, vx: float) -> void:
	_world_velocity.x = vx
	_world_velocity.y = minf(_world_velocity.y + gravity * dt, max_fall_speed_px_s)
	velocity = _world_velocity * WorldTime.scale()
	move_and_slide()
	if is_on_floor() or is_on_ceiling():
		_world_velocity.y = 0.0


func _update_direction() -> void:
	var turn: bool = false
	if is_on_wall() and signf(get_wall_normal().x) == -_direction:
		turn = true
	elif is_on_floor() and _at_edge():
		turn = true
	var half: float = _range() * 0.5
	if half > 0.0:
		if _direction > 0.0 and global_position.x >= _origin_x + half:
			turn = true
		elif _direction < 0.0 and global_position.x <= _origin_x - half:
			turn = true
	if turn:
		_direction = -_direction


func _range() -> float:
	return patrol_range_px


func _at_edge() -> bool:
	var x: float = global_position.x + _direction * (body_size.x * 0.5 + EDGE_PROBE_INSET_PX)
	var params := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - EDGE_PROBE_INSET_PX),
		Vector2(x, global_position.y + edge_probe_depth_px), LAYER_WORLD, [get_rid(), _platform.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(params).is_empty()


## Isak recordado o, si no lo hay, el que este en la capa player cerca.
func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = null
	_query.transform = Transform2D(0.0, global_position + Vector2(0.0, -platform_top_px * 0.5))
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, 4):
		var isak := hit.get("collider") as Isak
		if isak != null:
			target = isak
			return isak
	return null


func _check_player(real_delta: float) -> void:
	var isak: Isak = _find_player()
	if isak == null:
		_has_prev = false
		return
	var feet: Vector2 = isak.global_position
	var hurt := Rect2(feet + Vector2(-isak.hitbox_size.x * 0.5, -isak.hitbox_size.y), isak.hitbox_size)
	if is_dangerous():
		if hurt.intersects(get_damage_rect()):
			_hit(isak)
	elif is_platform():
		_check_stomp(isak, hurt, real_delta)
	_has_prev = true
	_prev_target_vy = isak.velocity.y
	_prev_target_feet_y = feet.y


func _hit(isak: Isak) -> void:
	var direction: float = signf(isak.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = -isak.facing
	if not isak.take_hit(direction):
		return
	GameState.apply_sync_damage(contact_damage)
	hit_player.emit(contact_damage)


## C7: caer encima con velocidad vertical >= umbral la revienta. Cubre los dos
## ordenes de paso: Isak a punto de aterrizar en este paso (prediccion con su
## velocidad) o ya apoyado (velocidad del paso anterior, antes de que el
## aterrizaje la pusiera a 0). Solo si venia de arriba (una via).
func _check_stomp(isak: Isak, hurt: Rect2, real_delta: float) -> void:
	var half: float = platform_width_px * 0.5
	if hurt.end.x <= global_position.x - half or hurt.position.x >= global_position.x + half:
		return
	var top: float = get_platform_top_y()
	var feet_y: float = isak.global_position.y
	var from_above: bool = not _has_prev or _prev_target_feet_y <= top + stomp_tolerance_px
	var reaches: bool = feet_y + maxf(isak.velocity.y, 0.0) * real_delta >= top - stomp_tolerance_px
	if not from_above or not reaches or feet_y > top + stomp_tolerance_px:
		return
	var impact: float = isak.velocity.y
	if _has_prev:
		impact = maxf(impact, _prev_target_vy)
	if impact >= pop_speed_threshold_px_s:
		pop(isak)


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


func _setup_shapes() -> void:
	var body := RectangleShape2D.new()
	body.size = body_size
	_body_shape.shape = body
	_body_shape.position = Vector2(0.0, -body_size.y * 0.5)
	var plank := RectangleShape2D.new()
	plank.size = Vector2(platform_width_px, platform_thickness_px)
	_platform_shape.shape = plank
	_platform_shape.one_way_collision = true
	_platform_shape.position = Vector2(0.0, -platform_top_px + platform_thickness_px * 0.5)
	_platform_shape.disabled = true
	var area := RectangleShape2D.new()
	area.size = Vector2(maxf(body_size.x, platform_width_px) + 2.0 * QUERY_MARGIN_PX,
		platform_top_px + 2.0 * QUERY_MARGIN_PX)
	_query = PhysicsShapeQueryParameters2D.new()
	_query.shape = area
	_query.collision_mask = LAYER_PLAYER
	_query.collide_with_bodies = true
	_query.collide_with_areas = false


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("AlertBubble: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	speed_px_s = float(d["patrol_speed_px_s"])
	if patrol_range_px < 0.0:
		patrol_range_px = float(d["patrol_range_px"])
	gravity = float(d["gravity"])
	max_fall_speed_px_s = float(d["max_fall_speed_px_s"])
	edge_probe_depth_px = float(d["edge_probe_depth_px"])
	contact_damage = float(d["contact_damage"])
	body_size = Vector2(float(d["body_size"][0]), float(d["body_size"][1]))
	damage_size = Vector2(float(d["damage_size"][0]), float(d["damage_size"][1]))
	damage_center_y = float(d["damage_center_y"])
	platform_top_px = float(d["platform_top_px"])
	platform_width_px = float(d["platform_width_px"])
	platform_thickness_px = float(d["platform_thickness_px"])
	stun_duration_s = float(d["stun_duration_s"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	pop_speed_threshold_px_s = float(d["pop_speed_threshold_px_s"])
	pop_bounce_velocity = float(d["pop_bounce_velocity"])
	stomp_tolerance_px = float(d["stomp_tolerance_px"])
	var frames: SpriteFrames = load(String(d["sprites"]["frames_resource"])) as SpriteFrames
	if frames != null:
		_sprite.sprite_frames = frames
	return true
