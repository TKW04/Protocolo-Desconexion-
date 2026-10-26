## Ladron de likes (Mundo 3 «La Vitrina»; paso 5 de docs/propuesta-mundo-3.md
## §8, comportamiento en §3.6). Valores y explicacion en
## data/enemies/like_thief.json.
##
## Mano pequena con marco que va por el suelo (origen en los pies). Estados
## (tiempo del mundo):
## - patrol: como la Burbuja (gira en paredes, bordes y limite de patrol_range_px).
##   Con Isak a <= detect_radius_px y dentro de la correa (la del punto rojo):
##   con likes, notice; sin likes, search.
## - notice: AVISO de anticipation_frames a anim_fps (0,75 s), quieto con los
##   dedos encendidos. Despues, chase.
## - chase: persigue a chase_speed_px_s sin salir de la correa. Al contacto roba
##   hasta steal_max likes (no quita Sync) y huye (flee); sin likes, search. Isak
##   fuera de la correa o lejos (give_up_radius_px): patrol.
## - flee: flee_s alejandose de Isak con la bolsa (la cifra de lo que lleva).
## - search: quieto search_s con «?» (Isak sin likes).
## - stunned: el pulso lo aturde stun_s y suelta lo robado como corazones
##   soltados (LikesSystem.drop_hearts: parpadean 2 s).
## - defeated: vida a 0 (laser aturdido; despierto, chispa gris); suelta lo que
##   lleve y no vuelve.
## El dash lo atraviesa sin que robe. Al reaparecer Isak, a su sitio sin bolsa.
## Aspecto PROVISIONAL por codigo.
class_name LikeThief
extends CharacterBody2D

signal state_changed(previous: StringName, current: StringName)
## Ha robado `amount` likes (lleva `carried`).
signal stole(amount: int, carried: int)
## Ha soltado `amount` likes como corazones.
signal released(amount: int)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected

const STATE_PATROL: StringName = &"patrol"
const STATE_NOTICE: StringName = &"notice"
const STATE_CHASE: StringName = &"chase"
const STATE_FLEE: StringName = &"flee"
const STATE_SEARCH: StringName = &"search"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/like_thief.json"
const GROUP: StringName = &"enemy"
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4
const EDGE_PROBE_INSET_PX: float = 2.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH
## Ancho total de la patrulla centrado en la aparicion. Negativo = el del JSON.
@export var patrol_range_px: float = -1.0
## Direccion inicial (1 / -1; 0 = la del JSON). Los params del nivel llegan tras _ready.
@export var start_direction: float = 0.0:
	set(value):
		start_direction = value
		if _ready_ok and _state == STATE_PATROL and not is_zero_approx(value):
			_direction = 1.0 if value > 0.0 else -1.0

var speed_px_s: float = 80.0
var gravity: float = 2400.0
var max_fall_speed_px_s: float = 1200.0
var edge_probe_depth_px: float = 16.0
var body_size: Vector2 = Vector2(48.0, 48.0)
var detect_radius_px: float = 256.0
var give_up_radius_px: float = 448.0
var leash_width_px: float = 768.0
var leash_height_px: float = 320.0
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var chase_speed_px_s: float = 140.0
var steal_max: int = 5
var flee_s: float = 2.0
var flee_speed_px_s: float = 200.0
var search_s: float = 1.0
var stun_s: float = 3.0
var deflect_s: float = 0.25
var drops: Dictionary = {}
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que roba (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _state_t: float = 0.0
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
var _time: float = 0.0
var _direction: float = 1.0
var _origin_x: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO
var _world_velocity: Vector2 = Vector2.ZERO
var _carried: int = 0
var _ready_ok: bool = false
var _health: EnemyHealth
var _body_shape: CollisionShape2D


## Suelta `count` likes como corazones soltados (1 like cada uno, los del golpe)
## sobre `feet`, como hijos de `host`. Usa el LikesSystem del nivel si lo hay.
static func drop_likes(from: Node, host: Node, feet: Vector2, count: int) -> Array[HeartPickup]:
	var out: Array[HeartPickup] = []
	if count <= 0 or host == null:
		return out
	var system: LikesSystem = null
	var node: Node = from
	while node != null and system == null:
		system = node.get_node_or_null(LikesSystem.NODE_NAME) as LikesSystem
		node = node.get_parent()
	if system != null:
		return system.drop_hearts(host, feet, count)
	var temp := LikesSystem.new()
	out = temp.drop_hearts(host, feet, count)
	temp.free()
	return out


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	_health = EnemyHealth.new(max_health)
	_body_shape = CollisionShape2D.new()
	_body_shape.name = "BodyShape"
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_body_shape.shape = rect
	_body_shape.position = Vector2(0.0, -body_size.y * 0.5)
	add_child(_body_shape)
	_origin_x = global_position.x
	_spawn_position = global_position
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	reset_patrol()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	_state_t += dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	var isak: Isak = _find_player()
	match _state:
		STATE_DEFEATED:
			return
		STATE_PATROL:
			_move(dt, _direction * speed_px_s)
			_update_direction()
			if _sees(isak, detect_radius_px):
				_change_state(STATE_NOTICE if GameState.likes > 0 else STATE_SEARCH)
		STATE_NOTICE:
			_move(dt, 0.0)
			if _state_t >= get_warn_s():
				_change_state(STATE_CHASE)
		STATE_CHASE:
			if not _sees(isak, give_up_radius_px):
				_back_to_patrol()
			else:
				var dx: float = isak.global_position.x - global_position.x
				_move(dt, _leash_clamped_vx(signf(dx) * chase_speed_px_s if absf(dx) > 2.0 else 0.0))
				_check_contact(isak)
		STATE_FLEE:
			var away: float = -signf(isak.global_position.x - global_position.x) if isak != null else _direction
			if is_zero_approx(away):
				away = -_direction
			_direction = away
			_move(dt, _leash_clamped_vx(away * flee_speed_px_s))
			if _state_t >= flee_s:
				_back_to_patrol()
		STATE_SEARCH:
			_move(dt, 0.0)
			if _state_t >= search_s:
				_back_to_patrol()
		STATE_STUNNED:
			_move(dt, 0.0)
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_back_to_patrol()
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func get_carried() -> int:
	return _carried


func is_noticing() -> bool:
	return _state == STATE_NOTICE


func is_chasing() -> bool:
	return _state == STATE_CHASE


func is_fleeing() -> bool:
	return _state == STATE_FLEE


func is_searching() -> bool:
	return _state == STATE_SEARCH


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


## No quita Sync: no cuenta como peligro para el contorno bajo el flash.
func is_dangerous() -> bool:
	return false


func is_combat_active() -> bool:
	return _state == STATE_NOTICE or _state == STATE_CHASE


func is_help_available() -> bool:
	return _state != STATE_DEFEATED


func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED


func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


func get_stun_left() -> float:
	return _stun_left


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


func get_leash_rect() -> Rect2:
	var size := Vector2(leash_width_px, leash_height_px)
	return Rect2(_spawn_position + Vector2(0.0, -body_size.y * 0.5) - size * 0.5, size)


func get_spawn_position() -> Vector2:
	return _spawn_position


# --- Acciones ---

func on_laser_hit(damage: float, _source: Node) -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	if not is_laser_vulnerable():
		_deflect_left = deflect_s
		deflected.emit()
		queue_redraw()
		return
	take_damage(damage)


func take_damage(amount: float) -> bool:
	if not _ready_ok or _state == STATE_DEFEATED or amount <= 0.0:
		return false
	var dies: bool = _health.take_damage(amount)
	damaged.emit(amount, _health.health)
	if dies:
		_defeat()
	return true


## Aturde stun_s x `duration_scale` y suelta lo robado como corazones.
func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_change_state(STATE_STUNNED)
	_world_velocity.x = 0.0
	_release()
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_DEFEATED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Vuelve a su sitio patrullando, sin bolsa (reaparicion de Isak). Derrotado
## sigue derrotado.
func reset_patrol() -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_world_velocity = Vector2.ZERO
	_direction = 1.0 if start_direction >= 0.0 else -1.0
	_stun_left = 0.0
	_deflect_left = 0.0
	_carried = 0
	_change_state(STATE_PATROL)
	queue_redraw()


# --- Interno ---

func _change_state(next: StringName) -> void:
	var previous: StringName = _state
	_state = next
	_state_t = 0.0
	if previous != next:
		state_changed.emit(previous, next)


func _back_to_patrol() -> void:
	_direction = signf(_origin_x - global_position.x) if absf(_origin_x - global_position.x) > 1.0 else _direction
	if is_zero_approx(_direction):
		_direction = 1.0
	_change_state(STATE_PATROL)


## Isak a <= `radius` (centro a centro) y con el centro dentro de la correa.
func _sees(isak: Isak, radius: float) -> bool:
	if isak == null or isak.is_dead():
		return false
	var center: Vector2 = LevelLookup.isak_body_rect(isak).get_center()
	if not get_leash_rect().has_point(center):
		return false
	return center.distance_to(get_body_rect().get_center()) <= radius


func _check_contact(isak: Isak) -> void:
	if isak == null or isak.is_dead() or isak.is_dashing():
		return
	if not LevelLookup.isak_body_rect(isak).intersects(get_body_rect()):
		return
	var taken: int = GameState.lose_likes(steal_max)
	if taken <= 0:
		_change_state(STATE_SEARCH)
		return
	_carried += taken
	stole.emit(taken, _carried)
	_change_state(STATE_FLEE)


func _release() -> void:
	if _carried <= 0:
		return
	var amount: int = _carried
	_carried = 0
	var host: Node = get_parent() if get_parent() != null else self
	LikeThief.drop_likes(self, host, global_position, amount)
	released.emit(amount)


func _defeat() -> void:
	_stun_left = 0.0
	_release()
	_change_state(STATE_DEFEATED)
	collision_layer = 0
	_body_shape.set_deferred(&"disabled", true)
	defeated.emit()
	EventBus.enemy_defeated.emit(self)
	RechargePickup.spawn_drops(get_parent() if get_parent() != null else self, global_position, drops)
	queue_redraw()


## Velocidad horizontal que no saca al ladron de su correa.
func _leash_clamped_vx(vx: float) -> float:
	var leash: Rect2 = get_leash_rect()
	var half: float = body_size.x * 0.5
	if vx > 0.0 and global_position.x + half >= leash.end.x:
		return 0.0
	if vx < 0.0 and global_position.x - half <= leash.position.x:
		return 0.0
	return vx


## Mueve con velocidad en tiempo del mundo (move_and_slide usa el delta real).
func _move(dt: float, vx: float) -> void:
	_world_velocity.x = vx
	_world_velocity.y = minf(_world_velocity.y + gravity * dt, max_fall_speed_px_s)
	velocity = _world_velocity * WorldTime.scale()
	move_and_slide()
	if is_on_floor() or is_on_ceiling():
		_world_velocity.y = 0.0


## Patrulla de la Burbuja: gira en paredes, bordes y el limite del rango.
func _update_direction() -> void:
	var turn: bool = false
	if is_on_wall() and signf(get_wall_normal().x) == -_direction:
		turn = true
	elif is_on_floor() and _at_edge():
		turn = true
	var half: float = patrol_range_px * 0.5
	if half > 0.0:
		if _direction > 0.0 and global_position.x >= _origin_x + half:
			turn = true
		elif _direction < 0.0 and global_position.x <= _origin_x - half:
			turn = true
	if turn:
		_direction = -_direction


func _at_edge() -> bool:
	var x: float = global_position.x + _direction * (body_size.x * 0.5 + EDGE_PROBE_INSET_PX)
	var params := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - EDGE_PROBE_INSET_PX),
		Vector2(x, global_position.y + edge_probe_depth_px), LAYER_WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(params).is_empty()


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


# --- Dibujo (PROVISIONAL por codigo) ---

func _draw() -> void:
	var defeated_now: bool = _state == STATE_DEFEATED
	var a: float = 0.5 if defeated_now else 1.0
	var gold := Color(World3ObjectsConfig.color("dorado"), a)
	var shadow := Color(World3ObjectsConfig.color("marco_sombra"), a)
	var skin := Color(World3ObjectsConfig.color("gris_perla"), a)
	var white := Color(World3ObjectsConfig.color("blanco_brillante"), a)
	var night := Color(World3ObjectsConfig.color("galeria_noche"), a)
	var lit: bool = _state == STATE_NOTICE or _state == STATE_CHASE
	var finger := Color(World3ObjectsConfig.color("ambar"), a) if lit else skin
	if _state == STATE_NOTICE and int(floor(_state_t * anim_fps)) % 2 == 1:
		finger = Color(World3ObjectsConfig.color("dorado_luz"), a)
	var w: float = body_size.x
	var h: float = body_size.y
	# Marco y palma.
	draw_rect(Rect2(-w * 0.5, -h * 0.55, w, h * 0.55), shadow)
	draw_rect(Rect2(-w * 0.5 + 3.0, -h * 0.55 + 3.0, w - 6.0, h * 0.55 - 6.0), gold)
	draw_rect(Rect2(-w * 0.5 + 7.0, -h * 0.55 + 7.0, w - 14.0, h * 0.55 - 14.0), skin)
	# Cuatro dedos (se encienden en el aviso y persiguiendo).
	var fw: float = (w - 12.0) / 4.0
	for i: int in 4:
		var fx: float = -w * 0.5 + 6.0 + float(i) * fw
		var fh: float = h * (0.38 if i in [1, 2] else 0.3)
		draw_rect(Rect2(fx + 1.0, -h * 0.55 - fh, fw - 2.0, fh), finger)
	if _carried > 0:
		var bag := Vector2(-float(signf(_direction)) * (w * 0.5 + 10.0), -h * 0.45)
		draw_circle(bag, 13.0, World3ObjectsConfig.color("rosa_sombra"))
		draw_circle(bag, 11.0, World3ObjectsConfig.color("rosa_pastel"))
		draw_string(ThemeDB.fallback_font, bag + Vector2(-12.0, 5.0), str(_carried), HORIZONTAL_ALIGNMENT_CENTER,
			24.0, 14, night)
	if _state == STATE_SEARCH:
		draw_string(ThemeDB.fallback_font, Vector2(-12.0, -h - 18.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 24.0, 22, white)
	elif _state == STATE_STUNNED:
		draw_string(ThemeDB.fallback_font, Vector2(-12.0, -h - 18.0), "||", HORIZONTAL_ALIGNMENT_CENTER, 24.0, 16, white)
	if _deflect_left > 0.0:
		var grey: Color = World3ObjectsConfig.color("gris_perla")
		var c := Vector2(0.0, -h * 0.5)
		for ang: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(ang))
			draw_line(c - d, c + d, grey, 2.0)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("LikeThief: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	speed_px_s = float(d["patrol_speed_px_s"])
	if patrol_range_px < 0.0:
		patrol_range_px = float(d["patrol_range_px"])
	if is_zero_approx(start_direction):
		start_direction = float(d.get("start_direction", 1))
	gravity = float(d["gravity"])
	max_fall_speed_px_s = float(d["max_fall_speed_px_s"])
	edge_probe_depth_px = float(d["edge_probe_depth_px"])
	var bs: Array = d.get("body_size", [48.0, 48.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	detect_radius_px = float(d["detect_radius_px"])
	give_up_radius_px = float(d["give_up_radius_px"])
	leash_width_px = float(d["leash_width_px"])
	leash_height_px = float(d["leash_height_px"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	chase_speed_px_s = float(d["chase_speed_px_s"])
	steal_max = int(d["steal_max"])
	flee_s = float(d["flee_s"])
	flee_speed_px_s = float(d["flee_speed_px_s"])
	search_s = float(d["search_s"])
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	deflect_s = float(d.get("deflect_s", 0.25))
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	return true
