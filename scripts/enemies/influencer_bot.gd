## Influencer bot (Mundo 3 «La Vitrina»; paso 5 de docs/propuesta-mundo-3.md §8,
## comportamiento en §3.6 y decision 6 de §9). Valores y explicacion en
## data/enemies/influencer_bot.json.
##
## Posa en un pedestal de 1 x 2 (origen en los pies de la celda de abajo).
## Estados (tiempo del mundo):
## - idle: posa con su bocadillo; si ve a Isak (can_see_isak: franja horizontal
##   de la lente, <= sight_tiles, rayo sin terreno) empieza a cargar.
## - charge: AVISO de anticipation_frames a anim_fps (0,75 s; el del video en
##   autoplay): aro de obturador que se cierra y «3-2-1 ¡Sonríe!». Al terminar
##   dispara el flash: si sigue viendo a Isak, FlashVeil lo ciega (sin dano; el
##   dash no lo esquiva); si se ha tapado, nada. Pasa a cooldown.
## - cooldown: cooldown_s sin mirar.
## - stunned: el pulso lo aturde stun_s y cancela la carga; al despertar, idle.
## - defeated: vida a 0 (laser aturdido; despierto rebota con chispa gris como
##   el Comentarista); suelta drops y heart_drops corazones y no vuelve.
## Al reaparecer Isak vuelve a idle (el velo lo quita FlashVeil). Aspecto
## PROVISIONAL por codigo (_draw_placeholder) hasta el arte de AutoSprite.
class_name InfluencerBot
extends Node2D

signal state_changed(previous: StringName, current: StringName)
signal charge_started
## Ha disparado; `blinded` = Isak estaba a la vista (si no, lo tapaba algo).
signal flashed(blinded: bool)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected

const STATE_IDLE: StringName = &"idle"
const STATE_CHARGE: StringName = &"charge"
const STATE_COOLDOWN: StringName = &"cooldown"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/influencer_bot.json"
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

## -1 / 1: solo mira a ese lado; 0: a los dos (se gira hacia Isak).
var facing: int = 0:
	set(value):
		facing = clampi(value, -1, 1)
		if facing != 0:
			_look = facing
var sight_tiles: int = 8
var sight_band_px: float = 64.0
var lens_height_px: float = 96.0
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var cooldown_s: float = 3.0
var stun_s: float = 3.0
var heart_drops: int = 2
var body_size: Vector2 = Vector2(48.0, 120.0)
var deflect_s: float = 0.25
var veil_alpha: float = 0.7
var veil_alpha_reduced: float = 0.4
var veil_hold_s: float = 1.0
var veil_fade_s: float = 0.5
var veil_color_name: String = "blanco_brillante"
var veil_z_index: int = 50
var outline_color_name: String = "alerta_sombra"
var outline_px: float = 3.0
var speech: String = "No olviden suscribirse"
var countdown_text: Array = ["3", "2", "1", "¡Sonríe!"]
var drops: Dictionary = {}
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que mira (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _state_t: float = 0.0
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
var _time: float = 0.0
var _look: int = 1
var _flashes: int = 0
var _ready_ok: bool = false
var _health: EnemyHealth
var _body: StaticBody2D


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


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	_state_t += dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	match _state:
		STATE_IDLE:
			if can_see_isak():
				_change_state(STATE_CHARGE)
				charge_started.emit()
		STATE_CHARGE:
			if _state_t >= get_warn_s():
				_fire()
		STATE_COOLDOWN:
			if _state_t >= cooldown_s:
				_change_state(STATE_IDLE)
		STATE_STUNNED:
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_change_state(STATE_IDLE)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_charging() -> bool:
	return _state == STATE_CHARGE


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


## El cuerpo no dana; el flash tampoco (sin contorno rojo propio bajo el velo).
func is_dangerous() -> bool:
	return false


func is_combat_active() -> bool:
	return _state == STATE_CHARGE


func is_help_available() -> bool:
	return _state != STATE_DEFEATED


func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED


## Duracion del aviso (carga del flash): cuadros / fps.
func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


## Segundos de carga ya cumplidos (0 fuera de la carga).
func get_charge_t() -> float:
	return _state_t if _state == STATE_CHARGE else 0.0


func get_flash_count() -> int:
	return _flashes


func get_stun_left() -> float:
	return _stun_left


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_look() -> int:
	return _look


func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


## Lente de la camara (px globales).
func get_lens_point() -> Vector2:
	return global_position + Vector2(0.0, -lens_height_px)


## Ve a Isak: su caja corta la franja de la lente, esta a <= sight_tiles en
## horizontal (hacia facing si no es 0) y el rayo de la lente no cruza terreno.
func can_see_isak() -> bool:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead() or not is_inside_tree():
		return false
	var r: Rect2 = LevelLookup.isak_body_rect(isak)
	var lens: Vector2 = get_lens_point()
	var half: float = sight_band_px * 0.5
	if r.end.y < lens.y - half or r.position.y > lens.y + half:
		return false
	var dx: float = r.get_center().x - lens.x
	if absf(dx) > float(sight_tiles) * TILE:
		return false
	if facing != 0 and not is_zero_approx(dx) and signf(dx) != float(facing):
		return false
	var aim := Vector2(r.get_center().x, clampf(lens.y, r.position.y, r.end.y))
	var params := PhysicsRayQueryParameters2D.create(lens, aim, LAYER_WORLD)
	if not get_world_2d().direct_space_state.intersect_ray(params).is_empty():
		return false
	if facing == 0 and not is_zero_approx(dx):
		_look = int(signf(dx))
	return true


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


## Aturde stun_s x `duration_scale` y cancela la carga en curso.
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


## Estado inicial (reaparicion de Isak). Derrotado sigue derrotado.
func reset_patrol() -> void:
	if not _ready_ok:
		return
	_stun_left = 0.0
	_deflect_left = 0.0
	_flashes = 0
	if facing != 0:
		_look = facing
	if _state != STATE_DEFEATED:
		_change_state(STATE_IDLE)
	queue_redraw()


## Opacidad del velo que pone su flash (0,7; 0,4 con «Reducir efectos»).
func get_veil_peak() -> float:
	return veil_alpha_reduced if GameSettings.is_low_sync_reduced() else veil_alpha


# --- Interno ---

func _change_state(next: StringName) -> void:
	var previous: StringName = _state
	_state = next
	_state_t = 0.0
	if previous != next:
		state_changed.emit(previous, next)


func _fire() -> void:
	var blinded: bool = can_see_isak()
	_flashes += 1
	if blinded:
		FlashVeil.for_node(self).blind(get_veil_peak(), veil_hold_s, veil_fade_s,
			World3ObjectsConfig.color(veil_color_name, Color.WHITE),
			World3ObjectsConfig.color(outline_color_name), outline_px, veil_z_index)
	_change_state(STATE_COOLDOWN)
	flashed.emit(blinded)


func _defeat() -> void:
	_stun_left = 0.0
	_change_state(STATE_DEFEATED)
	_body.collision_layer = 0
	defeated.emit()
	EventBus.enemy_defeated.emit(self)
	var host: Node = get_parent() if get_parent() != null else self
	RechargePickup.spawn_drops(host, global_position, drops)
	LikeThief.drop_likes(self, host, get_body_rect().get_center() + Vector2(0.0, body_size.y * 0.5), heart_drops)
	queue_redraw()


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
	_draw_placeholder(defeated_now)
	var lens: Vector2 = get_lens_point() - global_position
	if _state == STATE_CHARGE:
		# Aviso: aro de obturador que se cierra (ambar: el flash no dana) y la cuenta.
		var k: float = clampf(_state_t / maxf(get_warn_s(), 0.001), 0.0, 1.0)
		var ring: float = lerpf(30.0, 8.0, k)
		var amber: Color = World3ObjectsConfig.color("ambar")
		draw_arc(lens, ring, 0.0, TAU, 24, amber, 3.0)
		for i: int in 6:
			var a: float = TAU * float(i) / 6.0 + k * 1.5
			draw_line(lens + Vector2(ring, 0.0).rotated(a), lens + Vector2(ring * 0.4, 0.0).rotated(a + 0.9), amber, 2.0)
		if not countdown_text.is_empty():
			var idx: int = clampi(int(floor(k * float(countdown_text.size()))), 0, countdown_text.size() - 1)
			_draw_bubble(lens + Vector2(0.0, -60.0), String(countdown_text[idx]))
	elif _state in [STATE_IDLE, STATE_COOLDOWN] and not speech.is_empty():
		_draw_bubble(lens + Vector2(0.0, -60.0), speech)
	if _deflect_left > 0.0:
		var grey: Color = World3ObjectsConfig.color("gris_perla")
		var c: Vector2 = get_body_rect().get_center() - global_position
		for a: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(a))
			draw_line(c - d, c + d, grey, 2.0)


## Pedestal (celda de abajo) y bot con cabeza de camara (celda de arriba).
func _draw_placeholder(defeated_now: bool) -> void:
	var a: float = 0.5 if defeated_now else 1.0
	var gold := Color(World3ObjectsConfig.color("dorado"), a)
	var gold_light := Color(World3ObjectsConfig.color("dorado_luz"), a)
	var shadow := Color(World3ObjectsConfig.color("marco_sombra"), a)
	var pink := Color(World3ObjectsConfig.color("rosa_pastel"), a)
	var pink_dark := Color(World3ObjectsConfig.color("rosa_sombra"), a)
	var white := Color(World3ObjectsConfig.color("blanco_brillante"), a)
	var night := Color(World3ObjectsConfig.color("galeria_noche"), a)
	draw_rect(Rect2(-28.0, -48.0, 56.0, 48.0), shadow)
	draw_rect(Rect2(-24.0, -52.0, 48.0, 44.0), gold)
	draw_rect(Rect2(-24.0, -52.0, 48.0, 4.0), gold_light)
	draw_rect(Rect2(-14.0, -84.0, 28.0, 32.0), pink_dark)
	draw_rect(Rect2(-12.0, -84.0, 24.0, 30.0), pink)
	var lens: Vector2 = get_lens_point() - global_position
	draw_rect(Rect2(lens + Vector2(-20.0, -16.0), Vector2(40.0, 30.0)), night)
	draw_rect(Rect2(lens + Vector2(-18.0, -14.0), Vector2(36.0, 26.0)), white)
	draw_circle(lens + Vector2(float(_look) * 2.0, 0.0), 9.0, night)
	if _state == STATE_STUNNED:
		draw_string(ThemeDB.fallback_font, lens + Vector2(-18.0, 6.0), "||", HORIZONTAL_ALIGNMENT_CENTER, 36.0, 16, white)
	elif defeated_now:
		draw_string(ThemeDB.fallback_font, lens + Vector2(-18.0, 6.0), "x", HORIZONTAL_ALIGNMENT_CENTER, 36.0, 16, white)
	else:
		draw_circle(lens + Vector2(float(_look) * 2.0, 0.0), 4.0, World3ObjectsConfig.color("trastienda_luz"))


func _draw_bubble(center: Vector2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = 14
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	var box := Rect2(center - Vector2(w * 0.5, 12.0), Vector2(w, 22.0))
	draw_rect(box.grow(2.0), World3ObjectsConfig.color("marco_sombra"))
	draw_rect(box, World3ObjectsConfig.color("blanco_brillante"))
	draw_string(font, box.position + Vector2(0.0, 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size,
		World3ObjectsConfig.color("galeria_noche"))


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("InfluencerBot: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	facing = int(d.get("facing", 0))
	sight_tiles = int(d["sight_tiles"])
	sight_band_px = float(d["sight_band_px"])
	lens_height_px = float(d["lens_height_px"])
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	cooldown_s = float(d["cooldown_s"])
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	heart_drops = int(d.get("heart_drops", 2))
	var bs: Array = d.get("body_size", [48.0, 120.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	deflect_s = float(d.get("deflect_s", 0.25))
	veil_alpha = float(d["veil_alpha"])
	veil_alpha_reduced = float(d["veil_alpha_reduced"])
	veil_hold_s = float(d["veil_hold_s"])
	veil_fade_s = float(d["veil_fade_s"])
	veil_color_name = String(d.get("veil_color", veil_color_name))
	veil_z_index = int(d.get("veil_z_index", veil_z_index))
	outline_color_name = String(d.get("outline_color", outline_color_name))
	outline_px = float(d.get("outline_px", outline_px))
	speech = String(d.get("speech", speech))
	countdown_text = d.get("countdown_text", countdown_text)
	return true
