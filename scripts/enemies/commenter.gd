## Comentarista (Mundo 2 «El Feed»; paso 7 de docs/propuesta-mundo-2.md §8,
## comportamiento en §3.4). Valores y explicacion en data/enemies/commenter.json.
##
## Vive en un hueco de la pared lateral (la celda E es la suya; origen en sus
## pies, abajo-centro) mirando hacia `facing`. Su reloj (tiempo del mundo) va
## por ciclos de interval_s, desplazado offset_s al empezar:
## - warn: AVISO de anticipation_frames cuadros a anim_fps (0,75 s): el bocadillo
##   se infla en la boca.
## - al terminar el aviso ESCUPE un bocadillo de texto (NotificationShot con
##   heading hacia arriba) desde la columna de delante (shot_col_offset celdas
##   hacia facing), que sube shot_range_tiles celdas; el terreno lo apaga.
## - rest: hasta completar interval_s.
## - stunned: el pulso (o la onda del golpe) lo aturde stun_s: no escupe y el
##   aviso en curso se cancela (los bocadillos en el aire siguen); al despertar
##   el ciclo vuelve a empezar con su aviso.
## - defeated: vida a 0 (laser aturdido); suelta drops y no vuelve.
## El cuerpo no dana; el bocadillo si (el dash lo atraviesa). LASER: despierto,
## chispa gris (el disparo se consume); aturdido, dano. Al reaparecer Isak
## vuelve al estado inicial. Arte final de AutoSprite (2026-10-26;
## tools/import_commenter.py, ART_ANIMS); si faltan los cuadros, aspecto
## provisional por codigo. El aviso del bocadillo en la boca se dibuja siempre.
class_name Commenter
extends Node2D

signal state_changed(previous: StringName, current: StringName)
signal spat(shot: NotificationShot)
signal hit_player(amount: float)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected

const STATE_REST: StringName = &"rest"
const STATE_WARN: StringName = &"warn"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/commenter.json"
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4

## Arte final (tools/import_commenter.py): anim -> [cuadros, fps, bucle]. Lienzo
## de 80 x 88 con el cuerpo de 48 x 56 a ART_MARGIN_PX del borde izquierdo y del
## de arriba. El arte mira a la derecha (facing 1); con facing -1 se refleja.
## spit: cuadros 0-8 durante el aviso (uno por cuadro de anticipacion) y
## 9-13 justo despues de escupir.
const ART_DIR: String = "res://assets/sprites/enemies/commenter/"
const ART_ANIMS: Dictionary = {
	"idle": [24, 12.0, true],
	"spit": [14, 12.0, false],
	"stunned": [24, 12.0, true],
}
const ART_SPIT_WARN_FRAMES: int = 9
const ART_MARGIN_PX: float = 16.0

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

var facing: int = 1:
	set(value):
		facing = -1 if value < 0 else 1
var interval_s: float = 2.5
var offset_s: float = 0.0:
	set(value):
		offset_s = maxf(value, 0.0)
		# Los params del nivel llegan tras _ready: antes del primer bocadillo, a empezar.
		if _ready_ok and _spits == 0 and _state in [STATE_REST, STATE_WARN]:
			reset_patrol()
var min_rest_s: float = 0.25
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var contact_damage: float = 10.0
var stun_s: float = 3.0
var body_size: Vector2 = Vector2(48.0, 56.0)
var shot_col_offset: int = 1
var shot_speed_px_s: float = 320.0
var shot_range_tiles: int = 12
var shot_size_px: Vector2 = Vector2(64.0, 32.0)
var deflect_s: float = 0.25
var drops: Dictionary = {}
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que dana (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
## Tiempo dentro del ciclo (negativo = espera inicial de offset_s).
var _cycle_t: float = 0.0
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
var _time: float = 0.0
var _spits: int = 0
var _ready_ok: bool = false
var _health: EnemyHealth
var _body: StaticBody2D
var _shots: Array[NotificationShot] = []
## Tiempo del mundo desde el ultimo bocadillo (cuadros 9-13 del spit).
var _since_spit: float = INF
var _art_cache: Dictionary = {}


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
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	reset_patrol()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas: tambien
## avanza sus bocadillos (no procesan solos).
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	_since_spit += dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	match _state:
		STATE_DEFEATED:
			pass
		STATE_STUNNED:
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_cycle_t = 0.0
				_change_state(STATE_WARN)
		_:
			_cycle_t += dt
			if _state == STATE_REST and _cycle_t >= get_interval_s():
				_cycle_t -= get_interval_s()
			if _state == STATE_REST and _cycle_t >= 0.0 and _cycle_t < get_warn_s():
				_change_state(STATE_WARN)
			if _state == STATE_WARN and _cycle_t >= get_warn_s():
				_change_state(STATE_REST)
				_spit()
	_step_shots(dt)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_warning() -> bool:
	return _state == STATE_WARN


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


func is_dangerous() -> bool:
	return not get_shots().is_empty()


func is_combat_active() -> bool:
	return _state == STATE_WARN or is_dangerous()


func is_help_available() -> bool:
	return _state != STATE_DEFEATED


func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED


func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


## Ciclo: interval_s, o lo minimo para avisar y reposar.
func get_interval_s() -> float:
	return maxf(interval_s, get_warn_s() + min_rest_s)


func get_spit_count() -> int:
	return _spits


func get_stun_left() -> float:
	return _stun_left


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


## Centro global donde sale el bocadillo (columna de delante, a media altura de su celda).
func get_mouth_point() -> Vector2:
	return global_position + Vector2(float(facing * shot_col_offset) * TILE, -TILE * 0.5)


func get_shots() -> Array[NotificationShot]:
	var out: Array[NotificationShot] = []
	for shot: NotificationShot in _shots:
		if is_instance_valid(shot) and not shot.is_done() and not shot.is_queued_for_deletion():
			out.append(shot)
	return out


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


func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_DEFEATED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Estado inicial (reaparicion de Isak): reloj a cero (espera offset_s), sin
## bocadillos. Derrotado sigue derrotado.
func reset_patrol() -> void:
	if not _ready_ok:
		return
	for shot: NotificationShot in _shots:
		if is_instance_valid(shot):
			shot.queue_free()
	_shots.clear()
	_stun_left = 0.0
	_deflect_left = 0.0
	_cycle_t = -offset_s
	_spits = 0
	_since_spit = INF
	if _state != STATE_DEFEATED:
		_change_state(STATE_REST)
		if _cycle_t >= 0.0:
			_change_state(STATE_WARN)
	queue_redraw()


# --- Interno ---

func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)


func _spit() -> void:
	var shot := NotificationShot.new()
	shot.direction = facing
	shot.heading = Vector2.UP
	shot.speed_px_s = shot_speed_px_s
	shot.size_px = shot_size_px
	shot.contact_damage = contact_damage
	shot.travel_px = float(shot_range_tiles) * TILE
	shot.target = _find_player()
	shot.hit_player.connect(_on_shot_hit)
	shot.auto_process = false
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(shot)
	shot.global_position = get_mouth_point()
	_shots.append(shot)
	_spits += 1
	_since_spit = 0.0
	spat.emit(shot)


func _step_shots(dt: float) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state if is_inside_tree() else null
	for shot: NotificationShot in get_shots():
		shot.step(dt)
		if space == null or shot.is_queued_for_deletion():
			continue
		var query := PhysicsPointQueryParameters2D.new()
		query.position = shot.global_position + Vector2(0.0, -shot.size_px.y * 0.5)
		query.collision_mask = LAYER_WORLD
		if not space.intersect_point(query, 1).is_empty():
			shot.queue_free()
	_shots = get_shots()


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


func _on_shot_hit(amount: float) -> void:
	hit_player.emit(amount)


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


# --- Arte ---

## [animacion, cuadro] del arte final que toca ahora (ART_ANIMS).
func get_art_frame() -> Array:
	match _state:
		STATE_DEFEATED:
			return ["idle", 0]
		STATE_STUNNED:
			return ["stunned", _art_loop_frame("stunned")]
		STATE_WARN:
			var k: int = int(floor(maxf(_cycle_t, 0.0) * anim_fps))
			return ["spit", clampi(k, 0, ART_SPIT_WARN_FRAMES - 1)]
	var tail: int = int(ART_ANIMS["spit"][0]) - ART_SPIT_WARN_FRAMES
	var tail_s: float = float(tail) / float(ART_ANIMS["spit"][1])
	if _since_spit >= 0.0 and _since_spit < tail_s:
		var after: int = int(floor(_since_spit * float(ART_ANIMS["spit"][1])))
		return ["spit", ART_SPIT_WARN_FRAMES + mini(after, tail - 1)]
	return ["idle", _art_loop_frame("idle")]


func _art_loop_frame(anim: String) -> int:
	var spec: Array = ART_ANIMS[anim]
	return posmod(int(floor(_time * float(spec[1]))), int(spec[0]))


func _art_texture(anim: String, frame: int) -> Texture2D:
	var path: String = ART_DIR + "commenter_%s_%02d.png" % [anim, frame]
	if not _art_cache.has(path):
		_art_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _art_cache[path]


# --- Dibujo ---

func _draw() -> void:
	var body := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	var defeated_now: bool = _state == STATE_DEFEATED
	var grey: Color = World2ObjectsConfig.color("gris")
	var art: Array = get_art_frame()
	var tex: Texture2D = _art_texture(art[0], art[1])
	if tex != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1.0))
		var tint: Color = Color(0.6, 0.6, 0.7, 0.5) if defeated_now else Color.WHITE
		draw_texture(tex, body.position - Vector2(ART_MARGIN_PX, ART_MARGIN_PX), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_placeholder(body, defeated_now)
	if _state == STATE_WARN:
		# Aviso: el bocadillo se infla en la boca (crece con el aviso), en rojo.
		var k: float = clampf(_cycle_t / maxf(get_warn_s(), 0.001), 0.0, 1.0)
		var mouth: Vector2 = get_mouth_point() - global_position
		var size: Vector2 = shot_size_px * (0.3 + 0.7 * k)
		var bubble := Rect2(mouth - size * 0.5, size)
		draw_rect(bubble, World2ObjectsConfig.color("blanco"))
		if int(floor(_time * anim_fps)) % 2 == 0:
			draw_rect(bubble.grow(2.0), World2ObjectsConfig.color("alerta"), false, 2.0)
	if _deflect_left > 0.0:
		var c: Vector2 = body.get_center()
		for a: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(a))
			draw_line(c - d, c + d, grey, 2.0)


## Aspecto PROVISIONAL por codigo (sin los cuadros del arte final): tarjeta
## con cara de texto «...» (comentando), «||» aturdido, «x» derrotado.
func _draw_placeholder(body: Rect2, defeated_now: bool) -> void:
	FeedCardDraw.card(self, body, 0.5 if defeated_now else 1.0, false, "tarjeta_base")
	var white: Color = World2ObjectsConfig.color("blanco")
	var grey: Color = World2ObjectsConfig.color("gris")
	var face: String = "..."
	if defeated_now:
		face = "x"
	elif _state == STATE_STUNNED:
		face = "||"
	draw_string(ThemeDB.fallback_font, body.position + Vector2(0.0, body.size.y * 0.6), face,
		HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 18, grey if defeated_now else white)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("Commenter: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	facing = int(d.get("facing", 1))
	interval_s = float(d["interval_s"])
	offset_s = float(d.get("offset_s", 0.0))
	min_rest_s = float(d.get("min_rest_s", 0.25))
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	contact_damage = float(d["contact_damage"])
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	var bs: Array = d.get("body_size", [48.0, 56.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	shot_col_offset = int(d.get("shot_col_offset", 1))
	shot_speed_px_s = float(d["shot_speed_px_s"])
	shot_range_tiles = int(d["shot_range_tiles"])
	var ss: Array = d.get("shot_size_px", [64.0, 32.0])
	shot_size_px = Vector2(float(ss[0]), float(ss[1]))
	deflect_s = float(d.get("deflect_s", 0.25))
	return true
