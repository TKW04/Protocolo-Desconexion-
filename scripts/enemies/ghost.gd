## Fantasma (Mundo 4 «El Chat»; paso 6 de docs/propuesta-mundo-4.md §8, §3.7 y
## patron 21 de §3.8). Valores y explicacion en data/enemies/ghost.json.
##
## Flota (sin gravedad); origen en sus pies, abajo-centro. Estados (tiempo del mundo):
## - patrol: va y viene en horizontal; dana al contacto. Con Isak a <= detect_tiles
##   (y sin enfriamiento) pasa a vanish.
## - vanish: se esfuma vanish_s (intangible).
## - hidden: no esta hidden_s. El punto de reaparicion sigue a Isak (behind_tiles
##   detras de donde mira); con el Debug se ve el RASTRO hasta el.
## - warn: reaparece en el punto (fijado) con aviso de anticipation_frames cuadros.
## - ready: visible y quieto ready_s (a tiro del pulso); despues charge.
## - charge: embiste charge_tiles hacia Isak; dana al contacto; luego patrol.
## - stunned: el pulso o Agitar lo aturden stun_s; el laser le hace dano.
## - defeated: vida a 0; drops y no vuelve.
## Al reaparecer Isak vuelve a su sitio. Aspecto PROVISIONAL por codigo.
class_name Ghost
extends Node2D

signal state_changed(previous: StringName, current: StringName)
## Empieza a reaparecer en `at` (global, pies): el sonido posicional del paso 20.
signal appearing(at: Vector2)
signal hit_player(amount: float)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected

const STATE_PATROL: StringName = &"patrol"
const STATE_VANISH: StringName = &"vanish"
const STATE_HIDDEN: StringName = &"hidden"
const STATE_WARN: StringName = &"warn"
const STATE_READY: StringName = &"ready"
const STATE_CHARGE: StringName = &"charge"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/ghost.json"
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

var start_direction: int = 1:
	set(value):
		start_direction = -1 if value < 0 else 1
		# Param del nivel tras _ready: aun en su sitio, a patrullar hacia ahi.
		if _ready_ok and _state == STATE_PATROL:
			_direction = float(start_direction)
## Velocidad de patrulla (param del nivel patrol_speed_px_s).
var speed_px_s: float = 60.0
var patrol_range_px: float = 256.0
var detect_tiles: float = 3.0
var vanish_s: float = 0.3
var hidden_s: float = 1.0
var behind_tiles: float = 2.0
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var ready_s: float = 0.5
var charge_speed_px_s: float = 360.0
var charge_tiles: float = 4.0
var cooldown_s: float = 1.0
var contact_damage: float = 10.0
var stun_s: float = 3.0
var body_size: Vector2 = Vector2(40.0, 56.0)
var deflect_s: float = 0.25
var drops: Dictionary = {}
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que persigue (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _t: float = 0.0
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
var _cooldown_left: float = 0.0
var _time: float = 0.0
var _direction: float = 1.0
var _origin_x: float = 0.0
var _spawn: Vector2
var _vanish_from: Vector2
var _appear_at: Vector2
var _charge_left: float = 0.0
var _ready_ok: bool = false
var _health: EnemyHealth
var _body: StaticBody2D
var _trail: _GhostTrail
var _dark: DarkOverlay


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	_health = EnemyHealth.new(max_health)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER_ENEMY
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	shape.position = Vector2(0.0, -body_size.y * 0.5)
	_body.add_child(shape)
	add_child(_body)
	_trail = _GhostTrail.new()
	_trail.name = "Trail"
	_trail.ghost = self
	_trail.z_as_relative = false
	_trail.z_index = DarkZone.veil_z() + 1
	add_child(_trail)
	_spawn = global_position
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	reset_patrol()
	_attach_dark.call_deferred()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - dt, 0.0)
	match _state:
		STATE_DEFEATED:
			pass
		STATE_STUNNED:
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_begin_patrol_here()
		STATE_PATROL:
			_patrol(dt)
			if _cooldown_left <= 0.0 and _isak_distance() <= detect_tiles * TILE:
				_vanish_from = global_position
				_t = 0.0
				_change_state(STATE_VANISH)
		STATE_VANISH:
			_t += dt
			if _t >= vanish_s:
				_t = 0.0
				_change_state(STATE_HIDDEN)
		STATE_HIDDEN:
			_t += dt
			_appear_at = compute_appear_point()
			if _t >= hidden_s:
				_t = 0.0
				global_position = _appear_at
				var isak: Isak = _find_player()
				if isak != null:
					_direction = signf(isak.global_position.x - _appear_at.x)
					if is_zero_approx(_direction):
						_direction = 1.0
				_change_state(STATE_WARN)
				appearing.emit(_appear_at)
		STATE_WARN:
			_t += dt
			if _t >= get_warn_s():
				_t = 0.0
				_change_state(STATE_READY)
		STATE_READY:
			_t += dt
			if _t >= ready_s:
				_t = 0.0
				_charge_left = charge_tiles * TILE
				_change_state(STATE_CHARGE)
		STATE_CHARGE:
			var move: float = minf(charge_speed_px_s * dt, _charge_left)
			if _blocked_ahead(move):
				_charge_left = 0.0
			else:
				global_position.x += _direction * move
				_charge_left -= move
			if _charge_left <= 0.001:
				_cooldown_left = cooldown_s
				_begin_patrol_here()
	if is_dangerous():
		_check_contact()
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


## Se ve (y el pulso, Agitar y el laser lo alcanzan).
func is_visible_ghost() -> bool:
	return _state in [STATE_PATROL, STATE_WARN, STATE_READY, STATE_CHARGE, STATE_STUNNED]


## Dana al contacto: patrullando o embistiendo.
func is_dangerous() -> bool:
	return _state == STATE_PATROL or _state == STATE_CHARGE


func is_combat_active() -> bool:
	return _state in [STATE_VANISH, STATE_HIDDEN, STATE_WARN, STATE_READY, STATE_CHARGE]


func is_help_available() -> bool:
	return _state != STATE_DEFEATED and is_visible_ghost()


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


## Donde se esfumo (global, pies).
func get_vanish_point() -> Vector2:
	return _vanish_from


## Donde va a reaparecer (global, pies): fijo desde el aviso.
func get_appear_point() -> Vector2:
	return _appear_at


## Se ve el rastro (Debug activo y el Fantasma oculto o avisando).
func is_trail_visible() -> bool:
	return DebugMode.is_revealing() and _state in [STATE_HIDDEN, STATE_WARN]


## Punto de reaparicion para el Isak de ahora: behind_tiles detras de donde mira, a
## la altura de sus pies; si ahi hay terreno, delante.
func compute_appear_point() -> Vector2:
	var isak: Isak = _find_player()
	if isak == null:
		return global_position
	var face: float = float(isak.facing) if isak.facing != 0 else 1.0
	var behind: Vector2 = isak.global_position + Vector2(-face * behind_tiles * TILE, 0.0)
	if not _solid_at(behind):
		return behind
	var ahead: Vector2 = isak.global_position + Vector2(face * behind_tiles * TILE, 0.0)
	return behind if _solid_at(ahead) else ahead


# --- Acciones ---

func on_laser_hit(damage: float, _source: Node) -> void:
	if not _ready_ok or _state == STATE_DEFEATED or not is_visible_ghost():
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


func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or _state == STATE_DEFEATED or not is_visible_ghost():
		return
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_charge_left = 0.0
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if not is_visible_ghost() or _state == STATE_DEFEATED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Agitar: aturde si se ve y la onda lo alcanza.
func receive_shockwave(center: Vector2, radius: float, wave_stun_s: float) -> bool:
	if not _ready_ok or _state == STATE_DEFEATED or not is_visible_ghost() \
			or not ShockwaveWave.reaches(center, radius, get_body_rect()):
		return false
	stun(ShockwaveWave.stun_scale_for(self, wave_stun_s))
	return true


## Estado inicial (reaparicion de Isak): en su sitio patrullando. Derrotado sigue.
func reset_patrol() -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	global_position = _spawn
	_origin_x = _spawn.x
	_direction = float(start_direction)
	_t = 0.0
	_stun_left = 0.0
	_charge_left = 0.0
	_cooldown_left = 0.0
	_vanish_from = _spawn
	_appear_at = _spawn
	_change_state(STATE_PATROL)
	queue_redraw()


# --- Interno ---

func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	if _body != null:
		_body.collision_layer = LAYER_ENEMY if is_visible_ghost() else 0
	state_changed.emit(previous, next)


func _begin_patrol_here() -> void:
	_origin_x = global_position.x
	_change_state(STATE_PATROL)


func _patrol(dt: float) -> void:
	if speed_px_s <= 0.0:
		return
	var move: float = speed_px_s * dt
	var half: float = patrol_range_px * 0.5
	var turn: bool = _blocked_ahead(move)
	if _direction > 0.0 and global_position.x + move > _origin_x + half:
		turn = true
	elif _direction < 0.0 and global_position.x - move < _origin_x - half:
		turn = true
	if turn:
		_direction = -_direction
		return
	global_position.x += _direction * move


## Hay terreno a `move` px por delante (a media altura del cuerpo).
func _blocked_ahead(move: float) -> bool:
	var probe: Vector2 = global_position + Vector2(_direction * (body_size.x * 0.5 + move), 0.0)
	return _solid_at(probe)


## Terreno en el cuerpo de unos pies en `feet` (consulta en la capa world).
func _solid_at(feet: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = feet + Vector2(0.0, -body_size.y * 0.5)
	query.collision_mask = LAYER_WORLD
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(query, 4):
		if hit.get("collider") is ChatBubble:
			continue
		return true
	return false


func _isak_distance() -> float:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead():
		return INF
	return LevelLookup.isak_body_rect(isak).get_center().distance_to(get_body_rect().get_center())


func _check_contact() -> void:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead():
		return
	if not LevelLookup.isak_body_rect(isak).intersects(get_body_rect()):
		return
	var push: float = signf(isak.global_position.x - global_position.x)
	if is_zero_approx(push):
		push = _direction
	if isak.take_hit(push):
		GameState.apply_sync_damage(contact_damage)
		hit_player.emit(contact_damage)


func _defeat() -> void:
	_stun_left = 0.0
	_change_state(STATE_DEFEATED)
	_body.collision_layer = 0
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
		_dark = DarkOverlay.attach(self, get_body_rect().get_center())


func is_in_dark() -> bool:
	return _dark != null


## Por encima del velo: contorno rojo cuando dana y la silueta del aviso.
func draw_dark_overlay(canvas: CanvasItem) -> void:
	var body := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	if is_dangerous() or _state == STATE_READY:
		canvas.draw_rect(body.grow(2.0), World4ObjectsConfig.color("alerta", Color("#e8473c")), false, 2.0)
	elif _state == STATE_WARN:
		_draw_warn(canvas, body)


# --- Dibujo ---

## Alpha del avatar segun el estado (esfumarse y reaparecer).
func get_alpha() -> float:
	match _state:
		STATE_DEFEATED, STATE_HIDDEN:
			return 0.0
		STATE_VANISH:
			return 0.6 * (1.0 - clampf(_t / maxf(vanish_s, 0.001), 0.0, 1.0))
		STATE_WARN:
			return 0.6 * clampf(_t / maxf(get_warn_s(), 0.001), 0.0, 1.0)
	return 0.6


func _draw() -> void:
	var body := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	var a: float = get_alpha()
	if a > 0.0:
		var white: Color = World4ObjectsConfig.color("blanco_pantalla", Color("#f4f6fb"))
		var ink: Color = World4ObjectsConfig.color("marino_medio", Color("#2a3658"))
		# Silueta de fantasma: cabeza redonda y borde inferior en ondas.
		var head_r: float = body.size.x * 0.5
		var head_c := Vector2(0.0, body.position.y + head_r)
		draw_circle(head_c, head_r, Color(white, a))
		draw_rect(Rect2(Vector2(body.position.x, head_c.y), Vector2(body.size.x, body.end.y - head_c.y - 6.0)), Color(white, a))
		for i: int in 3:
			var w: float = body.size.x / 3.0
			draw_circle(Vector2(body.position.x + w * (float(i) + 0.5), body.end.y - 6.0), w * 0.5, Color(white, a))
		var eyes: String = "x x" if _state == STATE_STUNNED else "o o"
		draw_string(ThemeDB.fallback_font, Vector2(body.position.x, head_c.y + 5.0), eyes,
			HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 14, Color(ink, minf(a * 1.6, 1.0)))
	if _state == STATE_WARN:
		_draw_warn(self, body)
	if _deflect_left > 0.0:
		var grey: Color = World4ObjectsConfig.color("gris_claro", Color("#a9aebb"))
		var center: Vector2 = body.get_center()
		for deg: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(deg))
			draw_line(center - d, center + d, grey, 2.0)


## Aviso de reaparicion: la silueta en contorno rojo que late (9 cuadros).
func _draw_warn(canvas: CanvasItem, body: Rect2) -> void:
	if int(floor(_t * anim_fps)) % 2 == 0:
		canvas.draw_rect(body.grow(2.0), World4ObjectsConfig.color("alerta", Color("#e8473c")), false, 2.0)


## El rastro (Debug): linea de puntos coral de donde se esfumo a donde reaparece,
## en coordenadas locales de `canvas` (hijo sin desplazamiento).
func draw_trail(canvas: CanvasItem) -> void:
	if not is_trail_visible():
		return
	var coral: Color = World4ObjectsConfig.color("debug_coral", Color("#ff9f7a"))
	var mid := Vector2(0.0, -body_size.y * 0.5)
	var from: Vector2 = _vanish_from - global_position + mid
	var to: Vector2 = _appear_at - global_position + mid
	var length: float = from.distance_to(to)
	var n: int = maxi(int(length / 12.0), 1)
	for i: int in n + 1:
		canvas.draw_circle(from.lerp(to, float(i) / float(n)), 2.5, coral)
	canvas.draw_arc(to, 10.0, 0.0, TAU, 16, coral, 2.0)


class _GhostTrail:
	extends Node2D
	var ghost: Ghost

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ghost != null:
			ghost.draw_trail(self)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("Ghost: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	start_direction = int(d.get("start_direction", 1))
	speed_px_s = float(d["patrol_speed_px_s"])
	patrol_range_px = float(d["patrol_range_px"])
	detect_tiles = float(d["detect_tiles"])
	vanish_s = float(d["vanish_s"])
	hidden_s = float(d["hidden_s"])
	behind_tiles = float(d["behind_tiles"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	ready_s = float(d["ready_s"])
	charge_speed_px_s = float(d["charge_speed_px_s"])
	charge_tiles = float(d["charge_tiles"])
	cooldown_s = float(d.get("cooldown_s", 1.0))
	contact_damage = float(d["contact_damage"])
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	var bs: Array = d.get("body_size", [40.0, 56.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	deflect_s = float(d.get("deflect_s", 0.25))
	return true
