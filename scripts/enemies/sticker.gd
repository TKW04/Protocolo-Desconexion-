## Sticker (Mundo 4 «El Chat»; paso 5 de docs/propuesta-mundo-4.md §8, §3.7).
## Valores y explicacion en data/enemies/sticker.json.
##
## Estados (tiempo del mundo):
## - sleep: quieto hasta que Isak esta a <= detect_tiles.
## - chase: rebota hacia Isak por su suelo (no cae por los bordes).
## - inflate: a <= trigger_tiles se para y se infla anticipation_frames cuadros
##   (el aviso) y EXPLOTA: Isak a <= blast_tiles pierde blast_damage.
## - exploded: confeti sin dano; vuelve al reaparecer Isak.
## - stunned: (con pulse_deflates false) el pulso lo para stun_s; al despertar,
##   inflate si Isak sigue cerca.
## - defeated: el PULSO lo desinfla (pulse_deflates, desde que se retiro Agitar el
##   2026-10-28) o el laser (vida 1): drops y no vuelve.
## El cuerpo no dana al contacto. Aspecto PROVISIONAL por codigo.
class_name Sticker
extends CharacterBody2D

signal state_changed(previous: StringName, current: StringName)
signal exploded(hit: bool)
signal hit_player(amount: float)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
## Lo desinflo el pulso (o, antes del 2026-10-28, Agitar).
signal deflated

const STATE_SLEEP: StringName = &"sleep"
const STATE_CHASE: StringName = &"chase"
const STATE_INFLATE: StringName = &"inflate"
const STATE_EXPLODED: StringName = &"exploded"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/sticker.json"
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4
const EDGE_PROBE_INSET_PX: float = 2.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

var detect_tiles: float = 6.0
var trigger_tiles: float = 1.5
var blast_tiles: float = 1.5
var chase_speed_px_s: float = 120.0
var hop_s: float = 0.4
var hop_px: float = 10.0
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var blast_damage: float = 10.0
var confetti_s: float = 0.8
var stun_s: float = 3.0
## El pulso lo desinfla para siempre (drops) en vez de aturdirlo (2026-10-28: sustituye
## a Agitar, retirado; data pulse_deflates).
var pulse_deflates: bool = true
var body_size: Vector2 = Vector2(40.0, 40.0)
var gravity: float = 2400.0
var max_fall_speed_px_s: float = 1200.0
var edge_probe_depth_px: float = 16.0
var drops: Dictionary = {}
var max_health: float = 1.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que persigue (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _t: float = 0.0
var _stun_left: float = 0.0
var _time: float = 0.0
var _vy: float = 0.0
var _direction: float = 1.0
var _spawn: Vector2
var _ready_ok: bool = false
var _health: EnemyHealth
var _shape: CollisionShape2D
var _dark: DarkOverlay


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	_health = EnemyHealth.new(max_health)
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect
	_shape.position = Vector2(0.0, -body_size.y * 0.5)
	add_child(_shape)
	_spawn = global_position
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	_change_state(STATE_SLEEP)
	_attach_dark.call_deferred()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	match _state:
		STATE_DEFEATED:
			pass
		STATE_EXPLODED:
			_t += dt
		STATE_STUNNED:
			_move(dt, 0.0)
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_change_state(STATE_INFLATE if _isak_distance() <= trigger_tiles * TILE else STATE_CHASE)
				_t = 0.0
		STATE_INFLATE:
			_move(dt, 0.0)
			_t += dt
			if _t >= get_warn_s():
				_explode()
		STATE_CHASE:
			var d: float = _isak_distance()
			if d <= trigger_tiles * TILE:
				_t = 0.0
				_change_state(STATE_INFLATE)
				_move(dt, 0.0)
			elif d > detect_tiles * TILE:
				_change_state(STATE_SLEEP)
				_move(dt, 0.0)
			else:
				var isak: Isak = _find_player()
				var dx: float = isak.global_position.x - global_position.x
				_direction = signf(dx) if absf(dx) > 1.0 else _direction
				var vx: float = 0.0 if absf(dx) <= 1.0 or _blocked() else _direction * chase_speed_px_s
				_move(dt, vx)
		_:
			_move(dt, 0.0)
			var near: float = _isak_distance()
			if near <= trigger_tiles * TILE:
				_t = 0.0
				_change_state(STATE_INFLATE)
			elif near <= detect_tiles * TILE:
				_change_state(STATE_CHASE)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_inflating() -> bool:
	return _state == STATE_INFLATE


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


func is_exploded() -> bool:
	return _state == STATE_EXPLODED


func is_dangerous() -> bool:
	return _state == STATE_INFLATE


func is_combat_active() -> bool:
	return _state == STATE_CHASE or _state == STATE_INFLATE


func is_help_available() -> bool:
	return _state != STATE_DEFEATED and _state != STATE_EXPLODED


func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


func get_stun_left() -> float:
	return _stun_left


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


func get_center() -> Vector2:
	return global_position + Vector2(0.0, -body_size.y * 0.5)


# --- Acciones ---

func on_laser_hit(damage: float, _source: Node) -> void:
	take_damage(damage)


func take_damage(amount: float) -> bool:
	if not _ready_ok or not _alive() or amount <= 0.0:
		return false
	var dies: bool = _health.take_damage(amount)
	damaged.emit(amount, _health.health)
	if dies:
		_defeat()
	return true


func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or not _alive():
		return
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_t = 0.0
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if not _alive() or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	if pulse_deflates:
		if GameState.claim_pulse_return(self) > 0.0:
			UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
		deflated.emit()
		_defeat()
		return true
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Agitar: se desinfla y desaparece para siempre (drops) si la onda lo alcanza.
func receive_shockwave(center: Vector2, radius: float, _stun_s: float) -> bool:
	if not _ready_ok or not _alive() or not ShockwaveWave.reaches(center, radius, get_body_rect()):
		return false
	deflated.emit()
	_defeat()
	return true


## Estado inicial (reaparicion de Isak): dormido en su sitio; tambien tras explotar.
## Derrotado sigue derrotado.
func reset_patrol() -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	global_position = _spawn
	velocity = Vector2.ZERO
	_vy = 0.0
	_t = 0.0
	_stun_left = 0.0
	_shape.set_deferred(&"disabled", false)
	_change_state(STATE_SLEEP)
	queue_redraw()


# --- Interno ---

func _alive() -> bool:
	return _state != STATE_DEFEATED and _state != STATE_EXPLODED


func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)


## Mueve con velocidad en tiempo del mundo (move_and_slide usa el delta real).
func _move(dt: float, vx: float) -> void:
	_vy = minf(_vy + gravity * dt, max_fall_speed_px_s)
	velocity = Vector2(vx, _vy) * WorldTime.scale()
	move_and_slide()
	if is_on_floor() or is_on_ceiling():
		_vy = 0.0


## No sigue: pared delante o borde (no cae).
func _blocked() -> bool:
	if not is_inside_tree():
		return true
	if is_on_wall() and signf(get_wall_normal().x) == -_direction:
		return true
	if not is_on_floor():
		return false
	var x: float = global_position.x + _direction * (body_size.x * 0.5 + EDGE_PROBE_INSET_PX)
	var params := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - EDGE_PROBE_INSET_PX),
		Vector2(x, global_position.y + edge_probe_depth_px), LAYER_WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(params).is_empty()


func _isak_distance() -> float:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead():
		return INF
	return LevelLookup.isak_body_rect(isak).get_center().distance_to(get_center())


func _explode() -> void:
	_t = 0.0
	_change_state(STATE_EXPLODED)
	_shape.set_deferred(&"disabled", true)
	var hit: bool = false
	var isak: Isak = _find_player()
	if isak != null and not isak.is_dead() \
			and ShockwaveWave.reaches(get_center(), blast_tiles * TILE, LevelLookup.isak_body_rect(isak)):
		var push: float = signf(isak.global_position.x - global_position.x)
		if is_zero_approx(push):
			push = -float(isak.facing)
		if isak.take_hit(push):
			GameState.apply_sync_damage(blast_damage)
			hit_player.emit(blast_damage)
			hit = true
	exploded.emit(hit)


func _defeat() -> void:
	_stun_left = 0.0
	_change_state(STATE_DEFEATED)
	_shape.set_deferred(&"disabled", true)
	defeated.emit()
	EventBus.enemy_defeated.emit(self)
	RechargePickup.spawn_drops(get_parent(), global_position, drops)
	queue_redraw()


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


# --- Modo oscuro ---

func _attach_dark() -> void:
	if _dark == null:
		_dark = DarkOverlay.attach(self, get_center())


func is_in_dark() -> bool:
	return _dark != null


## Por encima del velo: contorno rojo (vivo), el inflado y la explosion.
func draw_dark_overlay(canvas: CanvasItem) -> void:
	var red: Color = World4ObjectsConfig.color("alerta", Color("#e8473c"))
	match _state:
		STATE_DEFEATED:
			return
		STATE_EXPLODED:
			if _t < confetti_s * 0.4:
				canvas.draw_arc(get_center() - global_position, blast_tiles * TILE, 0.0, TAU, 32, red, 2.0)
			return
	canvas.draw_arc(get_center() - global_position + Vector2(0.0, -_hop()), _radius() + 2.0, 0.0, TAU, 24, red, 2.0)


# --- Dibujo ---

func _hop() -> float:
	if _state != STATE_CHASE or hop_s <= 0.0:
		return 0.0
	return absf(sin(_time * PI / hop_s)) * hop_px


func _radius() -> float:
	var r: float = body_size.x * 0.5
	if _state == STATE_INFLATE:
		r *= 1.0 + 0.5 * clampf(_t / maxf(get_warn_s(), 0.001), 0.0, 1.0)
	return r


func _draw() -> void:
	var center: Vector2 = get_center() - global_position + Vector2(0.0, -_hop())
	var amber: Color = World4ObjectsConfig.color("ambar", Color("#f2b84b"))
	var ink: Color = World4ObjectsConfig.color("chat_noche", Color("#0f1422"))
	var red: Color = World4ObjectsConfig.color("alerta", Color("#e8473c"))
	match _state:
		STATE_DEFEATED:
			return
		STATE_EXPLODED:
			if _t >= confetti_s:
				return
			var a: float = 1.0 - _t / maxf(confetti_s, 0.001)
			var colors: Array[Color] = [amber, World4ObjectsConfig.color("crema", Color("#eee4cc")),
				World4ObjectsConfig.color("verde_apagado", Color("#7d9a80"))]
			for i: int in 10:
				var ang: float = float(i) * TAU / 10.0
				var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * (12.0 + 60.0 * (1.0 - a)) + Vector2(0.0, 30.0 * (1.0 - a))
				draw_rect(Rect2(p, Vector2(4.0, 4.0)), Color(colors[i % 3], a))
			return
	var r: float = _radius()
	draw_circle(center, r, amber)
	# Cara inventada: ojos y boca.
	var eye_y: float = center.y - r * 0.2
	if _state == STATE_STUNNED:
		draw_line(center + Vector2(-r * 0.45, eye_y - center.y - 3.0), center + Vector2(-r * 0.15, eye_y - center.y + 3.0), ink, 2.0)
		draw_line(center + Vector2(r * 0.15, eye_y - center.y - 3.0), center + Vector2(r * 0.45, eye_y - center.y + 3.0), ink, 2.0)
	else:
		draw_circle(Vector2(center.x - r * 0.3, eye_y), 3.0, ink)
		draw_circle(Vector2(center.x + r * 0.3, eye_y), 3.0, ink)
	draw_arc(center + Vector2(0.0, r * 0.1), r * 0.45, 0.3, PI - 0.3, 10, ink, 2.0)
	if _state == STATE_INFLATE and int(floor(_t * anim_fps)) % 2 == 0:
		draw_arc(center, r + 2.0, 0.0, TAU, 24, red, 3.0)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("Sticker: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	detect_tiles = float(d["detect_tiles"])
	trigger_tiles = float(d["trigger_tiles"])
	blast_tiles = float(d["blast_tiles"])
	chase_speed_px_s = float(d["chase_speed_px_s"])
	hop_s = float(d.get("hop_s", 0.4))
	hop_px = float(d.get("hop_px", 10.0))
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	blast_damage = float(d["blast_damage"])
	confetti_s = float(d.get("confetti_s", 0.8))
	stun_s = float(d["stun_s"])
	pulse_deflates = bool(d.get("pulse_deflates", true))
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	var bs: Array = d.get("body_size", [40.0, 40.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	gravity = float(d.get("gravity", 2400.0))
	max_fall_speed_px_s = float(d.get("max_fall_speed_px_s", 1200.0))
	edge_probe_depth_px = float(d.get("edge_probe_depth_px", 16.0))
	return true
