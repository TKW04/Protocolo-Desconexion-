## Clon de «Un video mas» (Mundo 2 «El Feed»; paso 7 de docs/propuesta-mundo-2.md
## §8, comportamiento en §3.4 y patron 12 «Limpiar y seguir» de §3.6). Valores y
## explicacion en data/enemies/video_clone.json.
##
## Lo crea una ClonZone (scripts/levels/clone_zone.gd) en un borde de la zona
## tras su aviso. Tarjeta pequena que patrulla por el suelo como la Burbuja
## (gira en paredes, bordes y el limite de su zona: patrol_min_x / patrol_max_x)
## y dana al contacto (el dash la atraviesa: Isak.take_hit no hace nada). Estados:
## - patrol: se mueve y dana al contacto.
## - stunned: el pulso (o la onda del golpe) la aturde stun_s; quieta e
##   inofensiva. Los ultimos anticipation_frames cuadros parpadea (aviso de que
##   vuelve a danar).
## - popped: vida a 0 (laser u onda del golpe; vida 1). Sin drops. Destello de
##   pop_s y se libera.
## Tiempo del mundo (el Debug la ralentiza). reset_patrol (reaparicion de Isak)
## la quita: los clones no sobreviven a un intento. Aspecto PROVISIONAL por
## codigo (FeedCardDraw). El origen son los pies (abajo-centro).
class_name VideoClone
extends CharacterBody2D

signal state_changed(previous: StringName, current: StringName)
signal hit_player(amount: float)
signal stunned
signal popped

const STATE_PATROL: StringName = &"patrol"
const STATE_STUNNED: StringName = &"stunned"
const STATE_POPPED: StringName = &"popped"

const DEFAULT_DATA_PATH: String = "res://data/enemies/video_clone.json"
const GROUP: StringName = &"enemy"
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4
const EDGE_PROBE_INSET_PX: float = 2.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH
## Rango total de patrulla centrado en el punto de aparicion (0 = sin limite).
## Las zonas fijan patrol_min_x / patrol_max_x en su lugar.
@export var patrol_range_px: float = -1.0
@export var start_direction: float = 1.0
## Liberar el nodo al acabar el destello (las pruebas pueden quitarlo).
@export var free_on_pop: bool = true
## Vida maxima (params.health). Negativo = la del JSON.
@export var max_health: float = -1.0:
	set(value):
		max_health = value
		if _health != null and value > 0.0:
			_health.reset(value)

## Limites globales de patrulla (los fija la zona; iguales = sin limite).
var patrol_min_x: float = 0.0
var patrol_max_x: float = 0.0
var speed_px_s: float = 100.0
var gravity: float = 2400.0
var max_fall_speed_px_s: float = 1200.0
var edge_probe_depth_px: float = 16.0
var contact_damage: float = 10.0
var body_size: Vector2 = Vector2(48.0, 40.0)
var damage_size: Vector2 = Vector2(40.0, 32.0)
var stun_s: float = 3.0
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var pop_s: float = 0.25
var drops: Dictionary = {}
## Isak al que dana (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _direction: float = 1.0
var _origin_x: float = 0.0
var _world_velocity: Vector2 = Vector2.ZERO
var _stun_left: float = 0.0
var _pop_left: float = 0.0
var _time: float = 0.0
var _ready_ok: bool = false
var _health: EnemyHealth
var _shape: CollisionShape2D


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	_shape = CollisionShape2D.new()
	_shape.name = "BodyShape"
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect
	_shape.position = Vector2(0.0, -body_size.y * 0.5)
	add_child(_shape)
	_direction = 1.0 if start_direction >= 0.0 else -1.0
	_origin_x = global_position.x
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	_change_state(STATE_PATROL)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	match _state:
		STATE_PATROL:
			_move(dt, _direction * speed_px_s)
			_update_direction()
			_check_player()
		STATE_STUNNED:
			_move(dt, 0.0)
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_change_state(STATE_PATROL)
		STATE_POPPED:
			_pop_left -= dt
			if _pop_left <= 0.0 and free_on_pop:
				queue_free()
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_dangerous() -> bool:
	return _state == STATE_PATROL


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_popped() -> bool:
	return _state == STATE_POPPED


## Aturdida en sus ultimos cuadros: avisa de que vuelve a danar.
func is_anticipating() -> bool:
	return _state == STATE_STUNNED and _stun_left <= get_anticipation_s()


func is_combat_active() -> bool:
	return _ready_ok and _state == STATE_PATROL


func is_help_available() -> bool:
	return _state != STATE_POPPED


func get_direction() -> float:
	return _direction


func get_stun_left() -> float:
	return _stun_left


func get_anticipation_s() -> float:
	return float(anticipation_frames) / anim_fps


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_damage_rect() -> Rect2:
	return Rect2(global_position + Vector2(-damage_size.x * 0.5, -body_size.y * 0.5 - damage_size.y * 0.5),
		damage_size)


## Cuerpo visible (lo que alcanzan el pulso y la onda del golpe).
func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


# --- Acciones ---

## Interfaz del laser: le quita vida (vida 1: un disparo).
func on_laser_hit(damage: float, _source: Node) -> void:
	take_damage(damage)


func take_damage(amount: float) -> bool:
	if not _ready_ok or _state == STATE_POPPED or amount <= 0.0:
		return false
	if _health.take_damage(amount):
		pop()
	return true


func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or _state == STATE_POPPED:
		return
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_POPPED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Eliminada (sin drops): destello de pop_s, sin colision, y se libera.
func pop() -> void:
	if _state == STATE_POPPED:
		return
	_pop_left = pop_s
	collision_layer = 0
	_change_state(STATE_POPPED)
	popped.emit()
	EventBus.enemy_defeated.emit(self)
	if not drops.is_empty():
		RechargePickup.spawn_drops(get_parent(), global_position, drops)


## Reaparicion de Isak (LevelRunner): los clones no sobreviven al intento.
func reset_patrol() -> void:
	if not _ready_ok:
		return
	_state = STATE_POPPED
	collision_layer = 0
	if free_on_pop:
		queue_free()


# --- Interno ---

func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)


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
	var lo: float = patrol_min_x
	var hi: float = patrol_max_x
	if hi <= lo and patrol_range_px > 0.0:
		lo = _origin_x - patrol_range_px * 0.5
		hi = _origin_x + patrol_range_px * 0.5
	if hi > lo:
		if _direction > 0.0 and global_position.x >= hi:
			turn = true
		elif _direction < 0.0 and global_position.x <= lo:
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


func _check_player() -> void:
	var isak: Isak = _find_player()
	if isak == null or not LevelLookup.isak_body_rect(isak).intersects(get_damage_rect()):
		return
	var direction: float = signf(isak.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = -isak.facing
	if not isak.take_hit(direction):
		return
	GameState.apply_sync_damage(contact_damage)
	hit_player.emit(contact_damage)


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 2) ---

func _draw() -> void:
	var rect := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	var alpha: float = 1.0
	if _state == STATE_POPPED:
		alpha = clampf(_pop_left / maxf(pop_s, 0.001), 0.0, 1.0)
		rect = rect.grow(6.0 * (1.0 - alpha))
	elif is_anticipating() and int(floor(_time * anim_fps)) % 2 == 0:
		alpha = 0.55
	FeedCardDraw.card(self, rect, alpha, false, "magenta_sombra")
	var screen := Rect2(rect.position + Vector2(6.0, 8.0), rect.size - Vector2(12.0, 16.0))
	draw_rect(screen, Color(World2ObjectsConfig.color("feed_noche"), alpha))
	var c: Vector2 = screen.get_center()
	var white := Color(World2ObjectsConfig.color("blanco"), alpha)
	if _state == STATE_STUNNED:
		draw_rect(Rect2(c + Vector2(-7.0, -7.0), Vector2(5.0, 14.0)), white)
		draw_rect(Rect2(c + Vector2(2.0, -7.0), Vector2(5.0, 14.0)), white)
	else:
		var d: float = _direction
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6.0 * d, -7.0), c + Vector2(-6.0 * d, 7.0),
			c + Vector2(8.0 * d, 0.0)]), white)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("VideoClone: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	speed_px_s = float(d["patrol_speed_px_s"])
	if patrol_range_px < 0.0:
		patrol_range_px = float(d.get("patrol_range_px", 0.0))
	gravity = float(d["gravity"])
	max_fall_speed_px_s = float(d["max_fall_speed_px_s"])
	edge_probe_depth_px = float(d["edge_probe_depth_px"])
	contact_damage = float(d["contact_damage"])
	body_size = Vector2(float(d["body_size"][0]), float(d["body_size"][1]))
	damage_size = Vector2(float(d["damage_size"][0]), float(d["damage_size"][1]))
	stun_s = float(d["stun_s"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	pop_s = float(d.get("pop_s", 0.25))
	if max_health <= 0.0:
		max_health = float(d["health"])
	_health = EnemyHealth.new(max_health)
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	return true
