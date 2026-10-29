## Oferta (Mundo 5 «La Tienda»; paso 2 de docs/propuesta-mundo-5.md §8, §3.3 y §3.7).
## Valores y explicacion en data/enemies/offer_sign.json.
##
## Cartel quieto que no dana: TIENTA. Su zona (radius_tiles a cada lado del centro,
## height_tiles de alto centrada en el cuerpo) tira de Isak hacia el con la fuerza de
## TemptationField (get_pull_weight). Estados (tiempo del mundo):
## - awake: tira; el pulso lo aturde; el laser rebota (chispa gris).
## - stunned: stun_s sin tiron; el laser le hace dano.
## - defeated: vida a 0; drops y no vuelve.
## Origen en sus pies (floor) o en el pie de la celda donde cuelga (wall). Aspecto
## PROVISIONAL por codigo.
class_name OfferSign
extends Node2D

signal state_changed(previous: StringName, current: StringName)
## Isak entra (true) o sale (false) de su zona mientras tira: el sonido del paso 20.
signal pull_changed(active: bool)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected

const STATE_AWAKE: StringName = &"awake"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"
const MOUNT_FLOOR: StringName = &"floor"
const MOUNT_WALL: StringName = &"wall"

const DEFAULT_DATA_PATH: String = "res://data/enemies/offer_sign.json"
const DEFAULT_SCENE_PATH: String = "res://scenes/enemies/offer_sign.tscn"
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
const LAYER_ENEMY: int = 4

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

## floor (de pie) o wall (colgado; el Sismo no lo alcanza). Param del nivel.
var mount: StringName = MOUNT_FLOOR:
	set(value):
		var m := StringName(value)
		if m != MOUNT_FLOOR and m != MOUNT_WALL:
			push_warning("OfferSign: mount '%s' desconocido; se usa floor" % m)
			m = MOUNT_FLOOR
		mount = m
		_update_body()
var radius_tiles: float = 5.0
var height_tiles: float = 3.0
var strength: float = 1.0
var stun_s: float = 3.0
var body_size: Vector2 = Vector2(56.0, 64.0)
var wall_body_size: Vector2 = Vector2(56.0, 48.0)
var deflect_s: float = 0.25
var pulse_hz_far: float = 0.8
var pulse_hz_near: float = 3.0
var particles: int = 6
var price_text: String = "99"
var sale_text: String = "9"
var drops: Dictionary = {}
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que tienta (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
var _time: float = 0.0
var _beat: float = 0.0
var _pulling: bool = false
var _ready_ok: bool = false
var _health: EnemyHealth
var _body: StaticBody2D
var _shape: CollisionShape2D


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	add_to_group(TemptationField.GROUP)
	_health = EnemyHealth.new(max_health)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER_ENEMY
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_body.add_child(_shape)
	add_child(_body)
	_update_body()
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	_change_state(STATE_AWAKE)


func _physics_process(delta: float) -> void:
	step(delta)


## Ayuda de Eco de las Ofertas que salen durante el juego (cajas sorpresa, atajos con trampa...;
## paso 9 de docs/propuesta-mundo-5.md): el help_id de su JSON por defecto.
static func spawned_help_id() -> StringName:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_DATA_PATH))
	if parsed is Dictionary:
		return StringName(String((parsed as Dictionary).get("help_id", "")))
	return &""


## Saca una Oferta de pie con los pies en `feet` (global) bajo `parent`, con su ayuda de Eco.
static func spawn(parent: Node, feet: Vector2) -> OfferSign:
	if parent == null:
		return null
	var offer := (load(DEFAULT_SCENE_PATH) as PackedScene).instantiate() as OfferSign
	HelpCatalog.tag(offer, spawned_help_id())
	parent.add_child(offer)
	offer.global_position = feet
	return offer


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	if _state == STATE_STUNNED:
		_stun_left -= dt
		if _stun_left <= 0.0:
			_stun_left = 0.0
			_change_state(STATE_AWAKE)
	var closeness: float = get_closeness()
	_beat += dt * lerpf(pulse_hz_far, pulse_hz_near, closeness)
	var pulling: bool = is_pulling_isak()
	if pulling != _pulling:
		_pulling = pulling
		pull_changed.emit(pulling)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_awake() -> bool:
	return _state == STATE_AWAKE


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED


func is_help_available() -> bool:
	return _state != STATE_DEFEATED


func get_stun_left() -> float:
	return _stun_left


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_size() -> Vector2:
	return wall_body_size if mount == MOUNT_WALL else body_size


func get_body_rect() -> Rect2:
	var size: Vector2 = get_size()
	return Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)


## Zona de tentacion (global): radius_tiles a cada lado del centro del cuerpo y
## height_tiles de alto centrada en el.
func get_zone_rect() -> Rect2:
	var c: Vector2 = get_body_rect().get_center()
	var half := Vector2(radius_tiles * TILE, height_tiles * TILE * 0.5)
	return Rect2(c - half, half * 2.0)


## Peso con signo con el que tira de un cuerpo con centro en `point` (TemptationField):
## +strength hacia la derecha, -strength hacia la izquierda, 0 despierto fuera de la
## zona, a menos de `dead_zone_px` en horizontal, aturdido o derrotado.
func get_pull_weight(point: Vector2, dead_zone_px: float = 4.0) -> float:
	if not _ready_ok or _state != STATE_AWAKE or not get_zone_rect().has_point(point):
		return 0.0
	var dx: float = get_body_rect().get_center().x - point.x
	if absf(dx) < dead_zone_px:
		return 0.0
	return signf(dx) * strength


## 0 (borde de la zona o fuera) .. 1 (encima): lo rapido que late el cartel.
func get_closeness() -> float:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead() or _state != STATE_AWAKE:
		return 0.0
	var p: Vector2 = LevelLookup.isak_body_rect(isak).get_center()
	if not get_zone_rect().has_point(p):
		return 0.0
	var dx: float = absf(get_body_rect().get_center().x - p.x)
	return clampf(1.0 - dx / maxf(radius_tiles * TILE, 1.0), 0.0, 1.0)


## Isak esta en su zona y el cartel tira (aunque Isak este en un estado que lo ignora).
func is_pulling_isak() -> bool:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead():
		return false
	return not is_zero_approx(get_pull_weight(LevelLookup.isak_body_rect(isak).get_center()))


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
	if _stun_left <= 0.0:
		return
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_DEFEATED or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Ondas de la Combinacion (ComboWave): la colgada no la alcanza el Sismo; el Filo no
## la derrota (vida > lo que derrota); lo demas, como a cualquier enemigo.
func receive_combo(kind: StringName, rect: Rect2, damage: float, wave_stun_s: float) -> bool:
	if not _ready_ok or _state == STATE_DEFEATED or not rect.intersects(get_body_rect()):
		return false
	if kind == Isak.COMBO_QUAKE and mount == MOUNT_WALL:
		return false
	if kind == Isak.COMBO_EDGE:
		if get_health() > damage + 0.0001:
			return false
		return take_damage(get_health())
	if wave_stun_s > 0.0:
		stun(ShockwaveWave.stun_scale_for(self, wave_stun_s))
	if damage > 0.0:
		take_damage(damage)
	return true


## Estado inicial (reaparicion de Isak): despierto. Derrotado sigue.
func reset_patrol() -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	_stun_left = 0.0
	_deflect_left = 0.0
	_change_state(STATE_AWAKE)
	queue_redraw()


# --- Interno ---

func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)


func _update_body() -> void:
	if _shape == null:
		return
	var size: Vector2 = get_size()
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = Vector2(0.0, -size.y * 0.5)
	queue_redraw()


func _defeat() -> void:
	_stun_left = 0.0
	_change_state(STATE_DEFEATED)
	_body.collision_layer = 0
	if _pulling:
		_pulling = false
		pull_changed.emit(false)
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


# --- Dibujo ---

func _c(name: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(name, Color(fallback))


func _draw() -> void:
	if _state == STATE_DEFEATED:
		return
	var size: Vector2 = get_size()
	var body := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var stunned_now: bool = _state == STATE_STUNNED
	# Latido: mas deprisa cuanto mas cerca esta Isak (aviso visual de §3.3).
	var glow: float = 0.0 if stunned_now else 0.5 + 0.5 * sin(_beat * TAU)
	var frame: Color = _c("gris_etiqueta", "#7a7488") if stunned_now else _c("magenta_neon", "#ff3df0")
	if mount == MOUNT_FLOOR:
		# Pie del cartel.
		draw_rect(Rect2(Vector2(-3.0, body.end.y - 14.0), Vector2(6.0, 14.0)), _c("gris_escaparate", "#3a3448"))
		body.size.y -= 12.0
	else:
		# Cuelga de dos cordones.
		draw_line(Vector2(body.position.x + 8.0, body.position.y), Vector2(body.position.x + 8.0, body.position.y - 8.0),
			_c("gris_etiqueta", "#7a7488"), 2.0)
		draw_line(Vector2(body.end.x - 8.0, body.position.y), Vector2(body.end.x - 8.0, body.position.y - 8.0),
			_c("gris_etiqueta", "#7a7488"), 2.0)
	if glow > 0.0:
		draw_rect(body.grow(2.0 + 3.0 * glow), Color(frame, 0.25 * glow))
	draw_rect(body, frame)
	draw_rect(body.grow(-3.0), _c("crema_cartel", "#e8e0c8"))
	var font: Font = ThemeDB.fallback_font
	var ink: Color = _c("negro_medio", "#221c30")
	# Precio tachado en magenta (nunca rojo) y el «rebajado» en grande.
	var top := Vector2(body.position.x, body.position.y + 16.0)
	draw_string(font, top, price_text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 12, ink)
	draw_line(top + Vector2(body.size.x * 0.3, -4.0), top + Vector2(body.size.x * 0.7, -4.0), _c("magenta_neon", "#ff3df0"), 2.0)
	var big := Vector2(body.position.x, body.end.y - 6.0)
	draw_string(font, big, "x x" if stunned_now else sale_text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x,
		14 if stunned_now else 22, ink)
	# Particulas que van hacia el cartel mientras tira de Isak.
	if _pulling and particles > 0:
		var isak: Isak = _find_player()
		if isak != null:
			var from: Vector2 = LevelLookup.isak_body_rect(isak).get_center() - global_position
			var to: Vector2 = body.get_center()
			for i: int in particles:
				var k: float = fposmod(_time * 0.8 + float(i) / float(particles), 1.0)
				draw_circle(from.lerp(to, k), 2.0, Color(_c("amarillo_rebajas", "#ffe600"), 0.9 - 0.6 * k))
	if _deflect_left > 0.0:
		var grey: Color = _c("gris_etiqueta", "#7a7488")
		var center: Vector2 = body.get_center()
		for deg: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(deg))
			draw_line(center - d, center + d, grey, 2.0)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("OfferSign: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	var bs: Array = d.get("body_size", [56.0, 64.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	var ws: Array = d.get("wall_body_size", [56.0, 48.0])
	wall_body_size = Vector2(float(ws[0]), float(ws[1]))
	mount = StringName(String(d.get("mount", "floor")))
	radius_tiles = float(d["radius_tiles"])
	height_tiles = float(d["height_tiles"])
	strength = float(d.get("strength", 1.0))
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	deflect_s = float(d.get("deflect_s", 0.25))
	pulse_hz_far = float(d.get("pulse_hz_far", 0.8))
	pulse_hz_near = float(d.get("pulse_hz_near", 3.0))
	particles = int(d.get("particles", 6))
	price_text = String(d.get("price_text", "99"))
	sale_text = String(d.get("sale_text", "9"))
	return true
