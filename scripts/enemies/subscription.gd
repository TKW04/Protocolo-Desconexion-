## Suscripcion (Mundo 5 «La Tienda»; paso 4 de docs/propuesta-mundo-5.md §8, §3.1,
## §3.5 y §3.7). Valores y explicacion en data/enemies/subscription.json; drenaje en
## la seccion subscription de data/economy.json.
##
## Bichito-tarjeta que NO HACE DANO NUNCA: cuesta puntos. Reutiliza la idea del punto
## rojo del 1-2 (vuela sin gravedad, el terreno lo para, aviso de 9 cuadros, aturdido).
## Estados (tiempo del mundo):
## - idle: dormida en su sitio; despierta con Isak a <= wake_radius_px (no oculto).
## - alert: alert_frames cuadros iluminada («¡Bienvenido!») antes de lanzarse.
## - chase: vuela hacia el centro de Isak a chase_speed_px_s; lejos u oculto, return.
## - return: vuelve a su sitio y se duerme.
## - attached: enganchada a la espalda de Isak; drena drain_points cada
##   drain_interval_s hasta drain_cap (GameState.spend_attention, devoluble). Con
##   saldo 0: declined.
## - declined: «Pago rechazado»; a los declined_release_s se suelta (stunned).
## - stunned: cae al suelo y queda aturdida stun_s; el laser o un Filo la derrotan;
##   al despertar vuelve a perseguir.
## - spent: ha drenado su tope; se suelta, cae y ya no persigue (vulnerable).
## - defeated: vida a 0; drops y no vuelve.
## Devuelve lo robado (2026-10-30, peticion del usuario; docs/propuesta-mundo-5.md §8.1):
## al derrotarla o cancelarla lanza en arco una moneda (RefundCoin) por cada punto drenado
## que aun no devolvio (en el «te fio», una por cada energy_per_coin de energia); cada
## moneda devuelve su punto sacandolo del registro de Devoluciones (o su energia) si se
## recoge antes de lifetime_s. Seccion refund_coins de data/enemies/subscription.json.
## Origen en los pies de su celda (abajo-centro); centro del cuerpo en center_y.
## Aspecto PROVISIONAL por codigo.
class_name Subscription
extends CharacterBody2D

signal state_changed(previous: StringName, current: StringName)
## Se engancha a Isak (sonido sfx_w5_subscription_attach, paso 20).
signal attached(isak: Isak)
## Drena `amount` puntos (sfx_w5_subscription_drain).
signal drained(amount: int, total: int)
## Saldo 0: «Pago rechazado».
signal declined
## Isak la cancela (pulso, golpe al suelo, Embestida o Sismo; sfx_w5_subscription_cancel).
signal cancelled
## Lanza las monedas de lo robado (`count` monedas de `kind`, RefundCoin.KIND_*).
signal coins_thrown(count: int, kind: StringName)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected

const STATE_IDLE: StringName = &"idle"
const STATE_ALERT: StringName = &"alert"
const STATE_CHASE: StringName = &"chase"
const STATE_RETURN: StringName = &"return"
const STATE_ATTACHED: StringName = &"attached"
const STATE_DECLINED: StringName = &"declined"
const STATE_STUNNED: StringName = &"stunned"
const STATE_SPENT: StringName = &"spent"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/subscription.json"
const SCENE_PATH: String = "res://scenes/enemies/subscription.tscn"
const GROUP: StringName = &"enemy"
const SUBSCRIPTION_GROUP: StringName = &"subscription"
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4
const HOME_EPS_PX: float = 4.0
## Motivo del gasto (EventBus.attention_spent).
const SPEND_REASON: StringName = &"subscription"

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH
## «Te fio» de El Vendedor (2026-10-29, paso 16 de docs/propuesta-mundo-5.md §5.2):
## > 0 = enganchada drena esta ENERGIA por segundo del mundo (no puntos, sin tope ni
## «Pago rechazado») hasta cancelarla. 0 = la de siempre.
var energy_drain_per_s: float = 0.0

var wake_radius_px: float = 320.0
var give_up_radius_px: float = 768.0
var chase_speed_px_s: float = 90.0
var return_speed_px_s: float = 120.0
var anim_fps: float = 12.0
var alert_frames: int = 9
var stun_s: float = 3.0
var gravity_px_s2: float = 2400.0
var max_fall_px_s: float = 960.0
var center_y: float = -24.0
var body_size: Vector2 = Vector2(32.0, 28.0)
var attach_offset: Vector2 = Vector2(-20.0, -60.0)
## Alto (px, desde la base del cuerpo, que es la que se posa) de la zona de golpe en el suelo (aturdida o saciada): el laser sale a la altura del
## celular (56 px sobre los pies) y pasaba por encima del cuerpo tumbado de 28 px (bot del 5-1, paso 11).
var down_hit_height_px: float = 64.0
var deflect_s: float = 0.25
var message_s: float = 1.5
var text_declined: String = "Pago rechazado"
var text_welcome: String = "¡Bienvenido!"
var drops: Dictionary = {}
var drain_points: int = 1
var drain_interval_s: float = 2.0
var drain_cap: int = 5
var declined_release_s: float = 3.0
## Monedas de lo robado (seccion refund_coins de su JSON; vacia = no lanza).
var refund_coins: Dictionary = {}
var max_health: float = 1.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que persigue (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _home: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _drain_left: float = 0.0
var _drained: int = 0
## Puntos drenados ya lanzados como monedas (no se lanzan dos veces).
var _thrown: int = 0
## Energia drenada en el «te fio» y la ya lanzada como monedas.
var _energy_drained: float = 0.0
var _host: Isak
var _deflect_left: float = 0.0
var _message: String = ""
var _message_left: float = 0.0
var _time: float = 0.0
var _ready_ok: bool = false
var _health: EnemyHealth
var _shape: CollisionShape2D


## Ayuda de Eco de las Suscripciones que salen durante el juego (cajas sorpresa, atajos con trampa...;
## paso 9 de docs/propuesta-mundo-5.md): el help_id de su JSON por defecto.
static func spawned_help_id() -> StringName:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_DATA_PATH))
	if parsed is Dictionary:
		return StringName(String((parsed as Dictionary).get("help_id", "")))
	return &""


## Crea una Suscripcion en `parent` con los pies en `feet` (global). Con `host`, sale
## ya enganchada a el; si no, sale avisando (alert) y persigue. La usan la caja
## sorpresa, el atajo con trampa y Terminos y condiciones.
static func spawn(parent: Node, feet: Vector2, host: Isak = null) -> Subscription:
	if parent == null:
		return null
	var scene := load(SCENE_PATH) as PackedScene
	var sub := scene.instantiate() as Subscription
	HelpCatalog.tag(sub, spawned_help_id())
	parent.add_child(sub)
	sub.global_position = feet
	sub._home = feet
	if host != null and is_instance_valid(host):
		sub.attach_to(host)
	else:
		sub.wake()
	return sub


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	add_to_group(SUBSCRIPTION_GROUP)
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_health = EnemyHealth.new(max_health)
	_shape = CollisionShape2D.new()
	_shape.name = "BodyShape"
	var rect := RectangleShape2D.new()
	rect.size = body_size
	_shape.shape = rect
	_shape.position = Vector2(0.0, center_y)
	add_child(_shape)
	_home = global_position
	EventBus.pulse_fired.connect(receive_pulse)
	_ready_ok = true
	_change_state(STATE_IDLE)


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
	if _message_left > 0.0:
		_message_left = maxf(_message_left - dt, 0.0)
	var isak: Isak = _find_player()
	match _state:
		STATE_IDLE:
			_move(Vector2.ZERO, dt)
			if _sees(isak, wake_radius_px):
				wake()
		STATE_ALERT:
			_move(Vector2.ZERO, dt)
			_timer -= dt
			if _timer <= 0.0:
				_change_state(STATE_CHASE)
		STATE_CHASE:
			if not _sees(isak, give_up_radius_px):
				_change_state(STATE_RETURN)
			elif get_body_rect().intersects(LevelLookup.isak_body_rect(isak)):
				attach_to(isak)
			else:
				var to: Vector2 = LevelLookup.isak_body_rect(isak).get_center() - get_center()
				_move(to.normalized() * chase_speed_px_s if to.length() > 0.5 else Vector2.ZERO, dt)
		STATE_RETURN:
			var home: Vector2 = _home - global_position
			if _sees(isak, wake_radius_px):
				_change_state(STATE_CHASE)
			elif home.length() <= maxf(HOME_EPS_PX, return_speed_px_s * dt):
				global_position = _home
				_move(Vector2.ZERO, dt)
				_change_state(STATE_IDLE)
			else:
				_move(home.normalized() * return_speed_px_s, dt)
		STATE_ATTACHED, STATE_DECLINED:
			if _host == null or not is_instance_valid(_host) or _host.is_dead():
				_release(STATE_STUNNED)
				return
			_follow_host()
			if _state == STATE_DECLINED:
				_timer -= dt
				if _timer <= 0.0:
					_release(STATE_STUNNED)
				return
			if energy_drain_per_s > 0.0:
				var before_e: float = GameState.debug_energy
				GameState.debug_energy = maxf(GameState.debug_energy - energy_drain_per_s * dt, 0.0)
				_energy_drained += before_e - GameState.debug_energy
				queue_redraw()
				return
			_drain_left -= dt
			if _drain_left <= 0.0:
				_drain_left += drain_interval_s
				_drain_tick()
		STATE_STUNNED:
			_fall(dt)
			_timer -= dt
			if _timer <= 0.0:
				_change_state(STATE_CHASE if _sees(isak, give_up_radius_px) else STATE_RETURN)
		STATE_SPENT:
			_fall(dt)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_attached() -> bool:
	return _state == STATE_ATTACHED or _state == STATE_DECLINED


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_spent() -> bool:
	return _state == STATE_SPENT


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


func is_chasing() -> bool:
	return _state == STATE_ALERT or _state == STATE_CHASE


## Persiguiendo o enganchada (PassiveRegen: «en combate»).
func is_combat_active() -> bool:
	return is_chasing() or is_attached()


## Nunca dana (cuesta puntos, no Sync).
func is_dangerous() -> bool:
	return false


## En el suelo (aturdida o saciada): el laser y el Filo la derrotan.
func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED or _state == STATE_SPENT


## Vuela (despierta o persiguiendo): el Sismo no la alcanza.
func is_flying() -> bool:
	return _state in [STATE_IDLE, STATE_ALERT, STATE_CHASE, STATE_RETURN]


func is_help_available() -> bool:
	return _state != STATE_DEFEATED


func get_host() -> Isak:
	return _host if is_attached() else null


## Puntos drenados por esta Suscripcion (tope drain_cap).
func get_drained() -> int:
	return _drained


## Puntos drenados que aun no ha lanzado como monedas.
func get_unthrown() -> int:
	return _drained - _thrown


## Energia drenada en el «te fio» que aun no ha lanzado como monedas.
func get_energy_drained() -> float:
	return _energy_drained


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_stun_left() -> float:
	return _timer if _state == STATE_STUNNED else 0.0


func get_alert_s() -> float:
	return float(alert_frames) / maxf(anim_fps, 1.0)


func get_message() -> String:
	return _message if _message_left > 0.0 else ""


func get_home() -> Vector2:
	return _home


func get_center() -> Vector2:
	return global_position + Vector2(0.0, center_y)


func get_body_rect() -> Rect2:
	return Rect2(get_center() - body_size * 0.5, body_size)


# --- Acciones ---

## Despierta: aviso de alert_frames cuadros y despues persigue.
func wake() -> void:
	if not _ready_ok or _state == STATE_DEFEATED or _state == STATE_SPENT or is_attached():
		return
	_timer = get_alert_s()
	_show(text_welcome)
	_change_state(STATE_ALERT)


## Se engancha a `isak` (sin dano). Con saldo 0, «Pago rechazado» al momento.
func attach_to(isak: Isak) -> void:
	if not _ready_ok or isak == null or _state == STATE_DEFEATED or _state == STATE_SPENT:
		return
	_host = isak
	target = isak
	velocity = Vector2.ZERO
	collision_layer = 0
	_drain_left = drain_interval_s
	_change_state(STATE_ATTACHED)
	_follow_host()
	attached.emit(isak)
	if energy_drain_per_s <= 0.0 and GameState.attention_points <= 0:
		_decline()


## Isak la cancela (pulso o golpe al suelo): la suelta aturdida en el suelo.
func cancel() -> bool:
	if not is_attached():
		return false
	_release(STATE_STUNNED)
	throw_coins()
	cancelled.emit()
	return true


func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or _state == STATE_DEFEATED or _state == STATE_SPENT:
		return
	if is_attached():
		cancel()
		return
	var t: float = stun_s * maxf(duration_scale, 0.0)
	if t <= 0.0:
		return
	_timer = t
	_change_state(STATE_STUNNED)
	stunned.emit()


## Pulso de Isak: enganchada a quien pulsa, se la quita; si no, la aturde si la alcanza.
func receive_pulse(area: Area2D) -> bool:
	if not _ready_ok or _state == STATE_DEFEATED or area == null:
		return false
	if is_attached():
		if area.get_parent() == _host or PulseReceiver.pulse_reaches(area, get_body_rect()):
			return cancel()
		return false
	if _state == STATE_SPENT or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_center())
	return true


## Golpe al suelo (GroundPoundWave): enganchada, la onda la suelta; suelta y alcanzada,
## la aturde. Sin dano (solo el laser y el Filo la derrotan).
func receive_ground_pound(rect: Rect2, _damage: float) -> bool:
	if not _ready_ok or _state == STATE_DEFEATED:
		return false
	if is_attached():
		return cancel()
	if _state == STATE_SPENT or not rect.intersects(get_body_rect()):
		return false
	stun()
	return true


## Combinacion (ComboWave): Embestida y Sismo la sueltan enganchada; la Embestida
## aturde y hace su dano a la que alcanza; el Sismo solo a las del suelo; el Filo
## la derrota (vida <= lo que derrota) salvo enganchada.
func receive_combo(kind: StringName, rect: Rect2, damage: float, wave_stun_s: float) -> bool:
	if not _ready_ok or _state == STATE_DEFEATED:
		return false
	if is_attached():
		return kind != Isak.COMBO_EDGE and cancel()
	if not rect.intersects(get_body_rect()):
		return false
	if kind == Isak.COMBO_EDGE:
		if get_health() > damage + 0.0001:
			return false
		return take_damage(get_health())
	if kind == Isak.COMBO_QUAKE and is_flying():
		return false
	if wave_stun_s > 0.0 and _state != STATE_SPENT:
		stun(ShockwaveWave.stun_scale_for(self, wave_stun_s))
	if damage > 0.0:
		take_damage(damage)
	return true


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


## Reaparicion de Isak: dormida en su sitio (la derrotada no vuelve; lo drenado se queda).
func reset_patrol() -> void:
	if not _ready_ok or _state == STATE_DEFEATED:
		return
	_host = null
	velocity = Vector2.ZERO
	collision_layer = LAYER_ENEMY
	global_position = _home
	_timer = 0.0
	_deflect_left = 0.0
	_message_left = 0.0
	_change_state(STATE_SPENT if _drained >= drain_cap else STATE_IDLE)
	queue_redraw()


## Lanza en arco las monedas de lo robado que aun no devolvio (al derrotarla o
## cancelarla). Puntos: una por punto drenado sin lanzar, nunca mas de lo que sigue en el
## registro de Devoluciones (lo ya devuelto alli no se duplica). Energia del «te fio»: una
## por cada energy_per_coin (la ultima, el resto), hasta max_energy_coins. Devuelve las
## monedas lanzadas.
func throw_coins() -> Array[RefundCoin]:
	var out: Array[RefundCoin] = []
	if refund_coins.is_empty() or not is_inside_tree():
		return out
	var parent: Node = get_parent()
	var origin: Vector2 = get_center()
	var pts: int = mini(_drained - _thrown, GameState.get_refundable(GameState.current_level, [GameState.REFUND_SUBSCRIPTION]))
	_thrown = _drained
	if pts > 0:
		out.append_array(RefundCoin.launch(parent, origin, pts, RefundCoin.KIND_POINTS, refund_coins,
			GameState.current_level, GameState.REFUND_SUBSCRIPTION))
		coins_thrown.emit(pts, RefundCoin.KIND_POINTS)
	var per: float = maxf(float(refund_coins.get("energy_per_coin", 5.0)), 0.1)
	var energy: float = _energy_drained
	_energy_drained = 0.0
	if energy >= float(refund_coins.get("min_energy", 0.5)):
		var n: int = mini(int(ceil(energy / per - 0.0001)), int(refund_coins.get("max_energy_coins", 6)))
		var amounts: Array = []
		var left: float = energy
		for i: int in n:
			var a: float = left if i == n - 1 else minf(per, left)
			amounts.append(a)
			left -= a
		out.append_array(RefundCoin.launch(parent, origin, n, RefundCoin.KIND_ENERGY, refund_coins, &"", &"", amounts))
		coins_thrown.emit(n, RefundCoin.KIND_ENERGY)
	return out


# --- Interno ---

func _drain_tick() -> void:
	if _drained >= drain_cap:
		_release(STATE_SPENT)
		return
	var amount: int = mini(drain_points, drain_cap - _drained)
	if GameState.attention_points <= 0:
		_decline()
		return
	amount = mini(amount, GameState.attention_points)
	if not GameState.spend_attention(amount, SPEND_REASON, GameState.current_level, GameState.REFUND_SUBSCRIPTION):
		_decline()
		return
	_drained += amount
	drained.emit(amount, _drained)
	if _drained >= drain_cap:
		_release(STATE_SPENT)


func _decline() -> void:
	_timer = declined_release_s
	_show(text_declined)
	_change_state(STATE_DECLINED)
	declined.emit()


## Se suelta de Isak y cae: aturdida (stunned) o saciada (spent).
func _release(next: StringName) -> void:
	_host = null
	velocity = Vector2.ZERO
	collision_layer = LAYER_ENEMY
	if next == STATE_STUNNED:
		_timer = stun_s
		_change_state(STATE_STUNNED)
		stunned.emit()
	else:
		_change_state(next)


func _follow_host() -> void:
	if _host == null:
		return
	var off := Vector2(attach_offset.x * signf(_host.facing if _host.facing != 0.0 else 1.0), attach_offset.y)
	global_position = _host.global_position + off - Vector2(0.0, center_y)


func _move(v: Vector2, _dt: float) -> void:
	velocity = v
	if is_inside_tree():
		move_and_slide()


func _fall(dt: float) -> void:
	velocity.x = 0.0
	velocity.y = minf(velocity.y + gravity_px_s2 * dt, max_fall_px_s)
	if is_inside_tree():
		move_and_slide()
		if is_on_floor() or get_slide_collision_count() > 0:
			velocity.y = 0.0


func _sees(isak: Isak, radius: float) -> bool:
	if isak == null or isak.is_dead() or GameState.is_player_hidden():
		return false
	return LevelLookup.isak_body_rect(isak).get_center().distance_to(get_center()) <= radius


func _show(text: String) -> void:
	_message = text
	_message_left = message_s


func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	_update_shape()
	state_changed.emit(previous, next)


## Forma de colision (la que ve el rayo del laser): el cuerpo, o en el suelo (aturdida o saciada) el cuerpo alargado
## hacia arriba hasta down_hit_height_px sobre su base (la que se posa en el suelo), para que el laser de Isak en el mismo suelo la alcance. No choca con Isak
## (su mascara es el mundo).
func _update_shape() -> void:
	if _shape == null or not _shape.shape is RectangleShape2D:
		return
	var rect := _shape.shape as RectangleShape2D
	if _state == STATE_STUNNED or _state == STATE_SPENT:
		# La base no cambia (la del cuerpo: cae y se posa igual); solo sube el techo hasta down_hit_height_px.
		var bottom: float = center_y + body_size.y * 0.5
		var top: float = minf(center_y - body_size.y * 0.5, bottom - down_hit_height_px)
		rect.size = Vector2(body_size.x, bottom - top)
		_shape.position = Vector2(0.0, (top + bottom) * 0.5)
	else:
		rect.size = body_size
		_shape.position = Vector2(0.0, center_y)


func _defeat() -> void:
	_host = null
	_change_state(STATE_DEFEATED)
	collision_layer = 0
	collision_mask = 0
	throw_coins()
	defeated.emit()
	EventBus.enemy_defeated.emit(self)
	RechargePickup.spawn_drops(get_parent(), global_position, drops)
	queue_redraw()


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


# --- Dibujo ---

func _c(name: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(name, Color(fallback))


func _draw() -> void:
	if _state == STATE_DEFEATED:
		return
	var body := Rect2(Vector2(-body_size.x * 0.5, center_y - body_size.y * 0.5), body_size)
	var down: bool = _state == STATE_STUNNED or _state == STATE_SPENT
	var glow: float = 0.0
	if _state == STATE_ALERT:
		glow = 1.0
	elif not down:
		glow = 0.35 + 0.25 * sin(_time * TAU * 1.2)
	var magenta: Color = _c("magenta_neon", "#ff3df0")
	if glow > 0.0:
		draw_rect(body.grow(3.0 + 3.0 * glow), Color(magenta, 0.25 * glow))
	# Tarjeta con banda magnetica y una sonrisa (sin marcas).
	draw_rect(body, _c("gris_etiqueta", "#7a7488") if down else magenta)
	draw_rect(body.grow(-2.0), _c("crema_cartel", "#e8e0c8"))
	draw_rect(Rect2(body.position + Vector2(2.0, 5.0), Vector2(body.size.x - 4.0, 5.0)), _c("negro_medio", "#221c30"))
	var ink: Color = _c("negro_medio", "#221c30")
	var face := body.get_center() + Vector2(0.0, 4.0)
	if down:
		draw_string(ThemeDB.fallback_font, Vector2(body.position.x, face.y + 3.0), "x x", HORIZONTAL_ALIGNMENT_CENTER,
			body.size.x, 10, ink)
	else:
		draw_circle(face + Vector2(-6.0, -2.0), 1.5, ink)
		draw_circle(face + Vector2(6.0, -2.0), 1.5, ink)
		draw_arc(face + Vector2(0.0, 1.0), 5.0, 0.2, PI - 0.2, 8, ink, 1.5)
	if _deflect_left > 0.0:
		var grey: Color = _c("gris_etiqueta", "#7a7488")
		for deg: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(10.0, 0.0).rotated(deg_to_rad(deg))
			draw_line(body.get_center() - d, body.get_center() + d, grey, 2.0)
	var msg: String = get_message()
	if not msg.is_empty():
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		var box := Rect2(Vector2(-w * 0.5, body.position.y - 26.0), Vector2(w, 18.0))
		draw_rect(box, ink)
		draw_rect(box, magenta, false, 1.0)
		draw_string(font, Vector2(box.position.x, box.end.y - 5.0), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 12,
			_c("crema_cartel", "#e8e0c8"))


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("Subscription: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	wake_radius_px = float(d["wake_radius_px"])
	give_up_radius_px = float(d.get("give_up_radius_px", 768.0))
	chase_speed_px_s = float(d["chase_speed_px_s"])
	return_speed_px_s = float(d.get("return_speed_px_s", 120.0))
	anim_fps = float(d.get("anim_fps", 12.0))
	alert_frames = int(d.get("alert_frames", 9))
	stun_s = float(d["stun_s"])
	gravity_px_s2 = float(d.get("gravity_px_s2", 2400.0))
	max_fall_px_s = float(d.get("max_fall_px_s", 960.0))
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	center_y = float(d.get("center_y", -24.0))
	var bs: Array = d.get("body_size", [32.0, 28.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	down_hit_height_px = float(d.get("down_hit_height_px", down_hit_height_px))
	var ao: Array = d.get("attach_offset", [-20.0, -60.0])
	attach_offset = Vector2(float(ao[0]), float(ao[1]))
	deflect_s = float(d.get("deflect_s", 0.25))
	message_s = float(d.get("message_s", 1.5))
	text_declined = String(d.get("text_declined", text_declined))
	text_welcome = String(d.get("text_welcome", text_welcome))
	var eco: Dictionary = PayPoint.economy().get("subscription", {})
	drain_points = int(eco.get("drain_points", 1))
	drain_interval_s = float(eco.get("drain_interval_s", 2.0))
	drain_cap = int(eco.get("drain_cap", 5))
	declined_release_s = float(eco.get("declined_release_s", 3.0))
	refund_coins = d.get("refund_coins", {}) if d.get("refund_coins", {}) is Dictionary else {}
	return true
