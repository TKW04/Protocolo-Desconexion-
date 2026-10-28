## Troll (Mundo 4 «El Chat»; paso 5 de docs/propuesta-mundo-4.md §8, comportamiento
## en §3.7 y patron 20 de §3.8). Valores y explicacion en data/enemies/troll.json.
##
## Avatar anonimo de pie en su celda E (origen en sus pies, abajo-centro). Estados:
## - idle: espera. Con Isak en linea horizontal (cuerpos solapados en vertical) y a
##   <= detect_tiles, y el reposo cumplido, se gira hacia el y pasa a warn.
## - warn: AVISO de anticipation_frames cuadros a anim_fps (0,75 s): «escribiendo…»
##   sobre la cabeza. Al terminar LANZA un TrollMessage horizontal hacia facing y
##   reposa hasta completar interval_s. Un aviso empezado termina.
## - stunned: el pulso o Agitar lo aturden stun_s; el aviso se cancela. Al despertar,
##   reposo cumplido (avisa en cuanto vuelve a ver a Isak).
## - defeated: vida a 0 (laser aturdido); suelta drops y no vuelve.
## El cuerpo no dana; sus mensajes si (el dash los atraviesa; Agitar los borra).
## Tiempo del mundo. Al reaparecer Isak vuelve al estado inicial. Base de
## TrollMimic (el disfrazado).
## Arte final con AutoSprite (paso 24, etapa 3b, 2026-10-28; tools/import_troll.py,
## docs/plan-arte-mundo-4.md): ART_ANIMS por estado (get_art_frame); el dibujo mide
## 76 px y sobresale 20 por encima de la caja (body_size no cambia). El bocadillo
## del aviso, los chispazos y el contorno rojo del Modo oscuro siguen por codigo.
## Sin los cuadros vuelve a la silueta provisional por codigo.
class_name Troll
extends Node2D

signal state_changed(previous: StringName, current: StringName)
signal shot_fired(shot: TrollMessage)
signal hit_player(amount: float)
signal stunned
signal damaged(amount: float, health_left: float)
signal defeated
signal deflected
## Agitar borro `count` mensajes suyos.
signal messages_erased(count: int)
## Acecho: el Troll que esperaba a oscuras (lurk) empieza a escribir por primera vez.
signal lurk_woke

const STATE_IDLE: StringName = &"idle"
const STATE_WARN: StringName = &"warn"
const STATE_STUNNED: StringName = &"stunned"
const STATE_DEFEATED: StringName = &"defeated"

const DEFAULT_DATA_PATH: String = "res://data/enemies/troll.json"
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4

## Arte final (tools/import_troll.py): troll_<anim>_<NN>.png en ART_DIR, lienzo de
## 80 x 108 colocado en ART_OFFSET de los pies (ART_OFFSET_PX del importador).
const ART_DIR: String = "res://assets/sprites/enemies/world4/"
const ART_OFFSET: Vector2 = Vector2(-40.0, -92.0)
## Alto del dibujo (pies -> capucha): el bocadillo del aviso va por encima.
const ART_HEIGHT_PX: float = 76.0
## anim: [cuadros, fps]. idle en reposo (bucle), typing por el progreso del aviso
## (9 = anticipation_frames), shot al lanzar (una vez), stunned aturdido (bucle).
const ART_ANIMS: Dictionary = {
	"idle": [24, 8.0],
	"typing": [9, 12.0],
	"shot": [6, 12.0],
	"stunned": [18, 10.0],
}
## Derrotado: el primer cuadro de idle apagado.
const ART_DEFEATED_MODULATE: Color = Color(0.55, 0.55, 0.6, 0.45)

## Cuadros cargados (anim -> Array[Texture2D]); vacio si faltan.
static var _art_cache: Dictionary = {}

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

## Hacia donde mira al empezar (-1 / 1); get_facing() es hacia donde mira ahora.
var facing: int = -1:
	set(value):
		facing = -1 if value < 0 else 1
		_dir = facing
var turns_to_isak: bool = true
var detect_tiles: float = 9.0
var interval_s: float = 2.5
var min_rest_s: float = 0.25
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var contact_damage: float = 10.0
var stun_s: float = 3.0
var body_size: Vector2 = Vector2(40.0, 56.0)
var messages: PackedStringArray = PackedStringArray(["ok.", "¿y?", "jajaja"])
var shot_speed_px_s: float = 240.0
var shot_range_tiles: int = 10
var shot_height_px: float = 28.0
var shot_min_width_px: float = 48.0
var deflect_s: float = 0.25
## Acecho (2026-10-28, peligros ocultos del Modo oscuro): dentro de una dark_zone, en
## reposo y fuera de la Linterna, solo se le ven los ojos (DarkOverlay.draw_lurk_eyes);
## al empezar a escribir por primera vez se delata (contorno rojo) hasta reaparecer
## Isak. El comportamiento no cambia. params.lurk del nivel.
var lurk: bool = false
var drops: Dictionary = {}
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que mira y dana (si es null se busca en el nivel).
var target: Isak

var _state: StringName = &""
var _dir: int = -1
var _warn_t: float = 0.0
var _rest_left: float = 0.0
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
## Tiempo desde el ultimo lanzamiento (cuadros de shot); < 0 = no se dibuja.
var _shot_anim_t: float = -1.0
var _time: float = 0.0
var _shots_fired: int = 0
var _ready_ok: bool = false
var _health: EnemyHealth
var _body: StaticBody2D
var _shots: Array[TrollMessage] = []
var _dark: DarkOverlay
var _lurk_woke: bool = false


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
	_attach_dark.call_deferred()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas: tambien
## avanza sus mensajes (no procesan solos).
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	if _shot_anim_t >= 0.0:
		_shot_anim_t += dt
		if _shot_anim_t >= get_shot_anim_s():
			_shot_anim_t = -1.0
	_step_state(dt)
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


## Acechando a oscuras no ayuda (la Q lo delataria): solo cuando se ve (bajo la
## Linterna, despierto o revelado por el Debug).
func is_help_available() -> bool:
	return _state != STATE_DEFEATED and (not is_lurking() or DebugMode.is_revealing())


func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED


func get_facing() -> int:
	return _dir


func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


## Ciclo: interval_s, o lo minimo para avisar y reposar.
func get_interval_s() -> float:
	return maxf(interval_s, get_warn_s() + min_rest_s)


func get_shot_count() -> int:
	return _shots_fired


func get_stun_left() -> float:
	return _stun_left


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y), body_size)


## Centro global donde nace el mensaje (delante del cuerpo, a media altura).
func get_mouth_point(shot_width: float = 0.0) -> Vector2:
	return global_position + Vector2(float(_dir) * (body_size.x * 0.5 + shot_width * 0.5), -body_size.y * 0.5)


func get_shots() -> Array[TrollMessage]:
	var out: Array[TrollMessage] = []
	for shot: TrollMessage in _shots:
		if is_instance_valid(shot) and not shot.is_done() and not shot.is_queued_for_deletion():
			out.append(shot)
	return out


## Isak esta en su linea horizontal y a <= detect_tiles (vivo).
func sees_isak() -> bool:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead():
		return false
	var r: Rect2 = LevelLookup.isak_body_rect(isak)
	var b: Rect2 = get_body_rect()
	if r.end.y <= b.position.y or r.position.y >= b.end.y:
		return false
	return absf(r.get_center().x - b.get_center().x) <= detect_tiles * TILE


# --- Arte ---

## Duracion de los cuadros de lanzar (shot) tras cada mensaje.
func get_shot_anim_s() -> float:
	var spec: Array = ART_ANIMS["shot"]
	return float(spec[0]) / float(spec[1])


## [anim, cuadro] del arte final segun el estado (ART_ANIMS).
func get_art_frame() -> Array:
	if _state == STATE_DEFEATED:
		return ["idle", 0]
	if _state == STATE_STUNNED:
		return ["stunned", _loop_frame("stunned")]
	if _state == STATE_WARN:
		var n: int = int(ART_ANIMS["typing"][0])
		var k: float = _warn_t / maxf(get_warn_s(), 0.001)
		return ["typing", clampi(floori(k * float(n)), 0, n - 1)]
	if _shot_anim_t >= 0.0:
		var spec: Array = ART_ANIMS["shot"]
		return ["shot", clampi(floori(_shot_anim_t * float(spec[1])), 0, int(spec[0]) - 1)]
	return ["idle", _loop_frame("idle")]


## Hay cuadros del arte final (si no, la silueta provisional por codigo).
static func has_art() -> bool:
	return not _art_frames("idle").is_empty()


## Textura del cuadro actual o null sin arte.
func get_art_texture() -> Texture2D:
	var f: Array = get_art_frame()
	var frames: Array = _art_frames(String(f[0]))
	if frames.is_empty():
		return null
	return frames[mini(int(f[1]), frames.size() - 1)]


## Lo que se ve del Troll (local): el dibujo sobresale por encima de la caja.
func get_visual_rect() -> Rect2:
	var h: float = ART_HEIGHT_PX if has_art() else body_size.y
	return Rect2(Vector2(-body_size.x * 0.5, -h), Vector2(body_size.x, h))


func _loop_frame(anim: String) -> int:
	var spec: Array = ART_ANIMS[anim]
	return posmod(floori(_time * float(spec[1])), int(spec[0]))


static func _art_frames(anim: String) -> Array:
	if _art_cache.has(anim):
		return _art_cache[anim]
	var out: Array = []
	var n: int = int(ART_ANIMS[anim][0]) if ART_ANIMS.has(anim) else 0
	for i: int in n:
		var path: String = ART_DIR + "troll_%s_%02d.png" % [anim, i]
		if not ResourceLoader.exists(path):
			out.clear()
			break
		out.append(load(path))
	_art_cache[anim] = out
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
	_warn_t = 0.0
	_shot_anim_t = -1.0
	_change_state(STATE_STUNNED)
	stunned.emit()


func receive_pulse(area: Area2D) -> bool:
	if not _can_be_hit() or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_body_rect().get_center())
	return true


## Agitar (ShockwaveWave.apply_to_enemies): borra los mensajes que alcanza la onda
## y aturde `stun_s` segundos al Troll si la onda lo alcanza. Verdadero si lo alcanzo.
func receive_shockwave(center: Vector2, radius: float, wave_stun_s: float) -> bool:
	if not _ready_ok:
		return false
	var erased: int = 0
	for shot: TrollMessage in get_shots():
		if ShockwaveWave.reaches(center, radius, shot.get_damage_rect()):
			shot.queue_free()
			erased += 1
	_shots = get_shots()
	if erased > 0:
		messages_erased.emit(erased)
	if _state == STATE_DEFEATED or not ShockwaveWave.reaches(center, radius, get_body_rect()):
		return false
	_on_shockwave_hit()
	stun(ShockwaveWave.stun_scale_for(self, wave_stun_s))
	return true


## Estado inicial (reaparicion de Isak): sin mensajes, mirando a facing, reposo
## cumplido. Derrotado sigue derrotado.
func reset_patrol() -> void:
	if not _ready_ok:
		return
	for shot: TrollMessage in _shots:
		if is_instance_valid(shot):
			shot.queue_free()
	_shots.clear()
	_stun_left = 0.0
	_deflect_left = 0.0
	_shot_anim_t = -1.0
	_warn_t = 0.0
	_rest_left = 0.0
	_shots_fired = 0
	_dir = facing
	_lurk_woke = false
	if _state != STATE_DEFEATED:
		_change_state(STATE_IDLE)
	queue_redraw()


# --- Para la subclase (TrollMimic) ---

## Puede recibir el pulso (no derrotado; el disfrazado lo ignora).
func _can_be_hit() -> bool:
	return _state != STATE_DEFEATED


## Agitar lo alcanzo (el disfrazado se descubre).
func _on_shockwave_hit() -> void:
	pass


func _step_state(dt: float) -> void:
	match _state:
		STATE_DEFEATED:
			pass
		STATE_STUNNED:
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_rest_left = 0.0
				_change_state(STATE_IDLE)
		STATE_WARN:
			_warn_t += dt
			if _warn_t >= get_warn_s():
				_shoot()
				_rest_left = get_interval_s() - get_warn_s()
				_change_state(STATE_IDLE)
		_:
			_rest_left = maxf(_rest_left - dt, 0.0)
			if _rest_left <= 0.0 and sees_isak():
				if turns_to_isak:
					var isak: Isak = _find_player()
					var dx: float = isak.global_position.x - global_position.x
					if absf(dx) > 0.5:
						_dir = int(signf(dx))
				_warn_t = 0.0
				_change_state(STATE_WARN)


# --- Interno ---

func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)
	if next == STATE_WARN and lurk and not _lurk_woke:
		_lurk_woke = true
		lurk_woke.emit()


func _shoot() -> void:
	var shot := TrollMessage.new()
	shot.text = messages[_shots_fired % messages.size()] if not messages.is_empty() else "ok."
	shot.size_px = TrollMessage.size_for(shot.text, shot_min_width_px, shot_height_px)
	shot.direction = _dir
	shot.speed_px_s = shot_speed_px_s
	shot.contact_damage = contact_damage
	shot.travel_px = float(shot_range_tiles) * TILE
	shot.target = _find_player()
	shot.hit_player.connect(_on_shot_hit)
	shot.auto_process = false
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(shot)
	shot.global_position = get_mouth_point(shot.size_px.x)
	_shots.append(shot)
	_shots_fired += 1
	_shot_anim_t = 0.0
	shot_fired.emit(shot)


func _step_shots(dt: float) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state if is_inside_tree() else null
	for shot: TrollMessage in get_shots():
		shot.step(dt)
		if space == null or shot.is_queued_for_deletion():
			continue
		var query := PhysicsPointQueryParameters2D.new()
		query.position = shot.global_position + Vector2(float(shot.direction) * shot.size_px.x * 0.5, 0.0)
		query.collision_mask = LAYER_WORLD
		for hit: Dictionary in space.intersect_point(query, 4):
			# Las burbujas de chat son de una via: el mensaje las cruza.
			if hit.get("collider") is ChatBubble:
				continue
			shot.queue_free()
			break
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


# --- Modo oscuro ---

func _attach_dark() -> void:
	if _dark == null:
		_dark = DarkOverlay.attach(self, get_body_rect().get_center())


## Bajo el velo de una zona oscura (tiene su capa DarkOverlay).
func is_in_dark() -> bool:
	return _dark != null


## Acecha: con lurk, a oscuras, sin haberse delatado en este intento, en reposo y
## fuera de la luz de la Linterna (bajo la luz se ve entero).
func is_lurking() -> bool:
	return lurk and is_in_dark() and not _lurk_woke and _state == STATE_IDLE \
			and not DarkOverlay.lit_at(self, get_body_rect().get_center())


## Ya se delato en este intento (empezo a escribir).
func has_lurk_woken() -> bool:
	return _lurk_woke


## Por encima del velo: contorno rojo del cuerpo (despierto) y el aviso; acechando,
## solo los ojos (y su silueta en coral con el Debug).
func draw_dark_overlay(canvas: CanvasItem) -> void:
	if _state == STATE_DEFEATED:
		return
	if is_lurking():
		if DebugMode.is_revealing():
			DarkOverlay.draw_debug_reveal(canvas, get_visual_rect().grow(2.0))
		var vr: Rect2 = get_visual_rect()
		DarkOverlay.draw_lurk_eyes(canvas, Vector2(0.0, vr.position.y + vr.size.y * 0.3), _dir, _time)
		return
	if _state != STATE_STUNNED:
		canvas.draw_rect(get_visual_rect().grow(2.0), World4ObjectsConfig.color("alerta", Color("#e8473c")), false, 2.0)
	if _state == STATE_WARN:
		_draw_warn(canvas)


# --- Dibujo ---

func _draw() -> void:
	var body := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
	var art: Texture2D = get_art_texture()
	if art != null:
		draw_texture(art, ART_OFFSET, ART_DEFEATED_MODULATE if _state == STATE_DEFEATED else Color.WHITE)
	else:
		_draw_avatar(self, body, 0.45 if _state == STATE_DEFEATED else 1.0)
	if _state == STATE_WARN:
		_draw_warn(self)
	elif _state == STATE_STUNNED and art == null:
		# Las estrellas ya estan en el arte final.
		var c := Vector2(0.0, body.position.y - 10.0)
		var cream: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
		for i: int in 3:
			var a: float = _time * 4.0 + float(i) * TAU / 3.0
			draw_circle(c + Vector2(cos(a) * 14.0, sin(a) * 4.0), 2.5, cream)
	if _deflect_left > 0.0:
		var grey: Color = World4ObjectsConfig.color("gris_claro", Color("#a9aebb"))
		var center: Vector2 = body.get_center()
		for deg: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(deg))
			draw_line(center - d, center + d, grey, 2.0)


## Avatar con `alpha` (el disfrazado lo hace aparecer al descubrirse): el primer
## cuadro de idle del arte final o, sin el, la silueta anonima PROVISIONAL
## (cabeza redonda y hombros grises, sin cara).
func _draw_avatar(canvas: CanvasItem, body: Rect2, alpha: float) -> void:
	var frames: Array = _art_frames("idle")
	if not frames.is_empty():
		canvas.draw_texture(frames[0], ART_OFFSET, Color(1.0, 1.0, 1.0, alpha))
		return
	var mid: Color = World4ObjectsConfig.color("gris_medio", Color("#6b7080"))
	var dark: Color = World4ObjectsConfig.color("gris_oscuro", Color("#3a3f4c"))
	var shoulders := Rect2(body.position + Vector2(0.0, body.size.y * 0.5), Vector2(body.size.x, body.size.y * 0.5))
	canvas.draw_rect(shoulders, Color(mid, alpha))
	canvas.draw_circle(Vector2(0.0, body.position.y + body.size.y * 0.3), body.size.x * 0.32, Color(mid, alpha))
	canvas.draw_rect(shoulders, Color(dark, alpha), false, 2.0)
	# Signo de perfil anonimo: «?» oscuro en la cabeza.
	canvas.draw_string(ThemeDB.fallback_font, Vector2(-5.0, body.position.y + body.size.y * 0.38), "?",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(dark, alpha))


## Aviso: bocadillo «escribiendo…» sobre la cabeza; los puntos salen de uno en uno
## y el contorno rojo parpadea.
func _draw_warn(canvas: CanvasItem) -> void:
	var k: float = clampf(_warn_t / maxf(get_warn_s(), 0.001), 0.0, 1.0)
	var rect := Rect2(Vector2(-22.0, -get_visual_rect().size.y - 28.0), Vector2(44.0, 22.0))
	canvas.draw_rect(rect, World4ObjectsConfig.color("crema", Color("#eee4cc")))
	if int(floor(_warn_t * anim_fps)) % 2 == 0:
		canvas.draw_rect(rect.grow(2.0), World4ObjectsConfig.color("alerta", Color("#e8473c")), false, 2.0)
	var dots: int = 1 + mini(int(floor(k * 3.0)), 2)
	var ink: Color = World4ObjectsConfig.color("chat_noche", Color("#0f1422"))
	for i: int in dots:
		canvas.draw_circle(rect.position + Vector2(10.0 + 12.0 * float(i), rect.size.y * 0.5), 3.0, ink)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("Troll: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	facing = int(d.get("facing", -1))
	turns_to_isak = bool(d.get("turns_to_isak", true))
	detect_tiles = float(d["detect_tiles"])
	interval_s = float(d["interval_s"])
	min_rest_s = float(d.get("min_rest_s", 0.25))
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	contact_damage = float(d["contact_damage"])
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	var bs: Array = d.get("body_size", [40.0, 56.0])
	body_size = Vector2(float(bs[0]), float(bs[1]))
	messages = PackedStringArray(d.get("messages", ["ok."]))
	shot_speed_px_s = float(d["shot_speed_px_s"])
	shot_range_tiles = int(d["shot_range_tiles"])
	shot_height_px = float(d.get("shot_height_px", 28.0))
	shot_min_width_px = float(d.get("shot_min_width_px", 48.0))
	deflect_s = float(d.get("deflect_s", 0.25))
	lurk = bool(d.get("lurk", false))
	return true
