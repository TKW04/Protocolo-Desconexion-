## Video en autoplay (Mundo 2 «El Feed»; paso 6 de docs/propuesta-mundo-2.md §8,
## comportamiento en §3.4 y patron 11 «Leer el clip» de §3.6). Valores y
## explicacion en data/enemies/autoplay_video.json.
##
## Tarjeta de 2 x 2 tiles en la pared del fondo (decorado: no dana al tocarla).
## El origen son los pies de su celda de abajo a la izquierda (celda E). Se
## activa con la CAMARA: cuando la tarjeta entra entera en la vista empieza un
## clip (tras start_delay_s) y los clips se repiten cada clip_s mientras siga
## entera a la vista. Estados:
## - idle: fuera de la vista (o esperando start_delay_s).
## - warn: AVISO, la miniatura del clip (anticipation_frames cuadros a anim_fps:
##   0,75 s). En la cuenta, la miniatura dice 3-2-1.
## - attack: el ataque de su clip (reutiliza piezas del Mundo 1):
##   wave  = barrido de un SpamBanner en modo disparo (su aviso coincide con la
##           miniatura) por la fila de abajo de la tarjeta hacia facing;
##   ray   = onda de una AlarmBell en modo disparo, sin campana, en la columna
##           de Isak al empezar el clip (la linea roja del suelo la marca);
##   count = fan_count NotificationShot en abanico hacia facing.
## - rest: hasta completar clip_s; si sigue entera a la vista, otro clip.
## - stunned: el pulso (o la onda del golpe al suelo) lo aturde stun_s: el clip
##   se PAUSA (icono de pausa) y el ataque en curso se cancela; al despertar el
##   clip vuelve a empezar con su miniatura (el aviso nunca falta).
## - broken: vida a 0 (laser aturdido); suelta drops y no vuelve.
## El dash atraviesa la ola, el rayo y los proyectiles (Isak.take_hit no hace
## nada mientras es invulnerable). LASER: despierto es inmune (chispa gris; el
## disparo se consume); aturdido le quita vida. Tiempo del mundo (el Debug lo
## ralentiza). Al reaparecer Isak vuelve a su estado inicial (sin clip; roto
## sigue roto). Aspecto PROVISIONAL por codigo (FeedCardDraw).
class_name AutoplayVideo
extends Node2D

signal state_changed(previous: StringName, current: StringName)
## Ha empezado un clip (su miniatura).
signal clip_started(clip: StringName)
## Algo de su clip (ola, rayo o proyectil) ha danado a Isak.
signal hit_player(amount: float)
signal stunned
signal damaged(amount: float, health_left: float)
signal broken
## El laser le ha dado despierto: no le hace nada (chispa gris).
signal deflected

const STATE_IDLE: StringName = &"idle"
const STATE_WARN: StringName = &"warn"
const STATE_ATTACK: StringName = &"attack"
const STATE_REST: StringName = &"rest"
const STATE_STUNNED: StringName = &"stunned"
const STATE_BROKEN: StringName = &"broken"

const CLIP_WAVE: StringName = &"wave"
const CLIP_RAY: StringName = &"ray"
const CLIP_COUNT: StringName = &"count"

const DEFAULT_DATA_PATH: String = "res://data/enemies/autoplay_video.json"
const BANNER_SCENE: PackedScene = preload("res://scenes/enemies/spam_banner.tscn")
const BELL_SCENE: PackedScene = preload("res://scenes/enemies/alarm_bell.tscn")
## El mismo grupo que los demas enemigos: LevelRunner llama a reset_patrol.
const GROUP: StringName = &"enemy"
const TILE: float = 64.0
## Capas de fisica (project.godot): el cuerpo en enemy (el laser lo encuentra).
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH

# Ajustes (data_path; los params del nivel los sobrescriben por nombre).
## «wave», «ray» o «count».
var clip: String = "wave"
## 1 derecha, -1 izquierda: hacia donde van la ola y la cuenta.
var facing: int = 1:
	set(value):
		facing = -1 if value < 0 else 1
var clip_s: float = 2.5
var start_delay_s: float = 0.0
var min_rest_s: float = 0.25
var anim_fps: float = 12.0
var anticipation_frames: int = 9
var contact_damage: float = 10.0
var stun_s: float = 3.0
var card_tiles: Vector2i = Vector2i(2, 2)
var wave_tiles: int = 10
var wave_row_offset: int = 0
var ray_tiles: int = 5
var ray_top_offset: int = 0
var ray_wave_s: float = 0.4
var fan_count: int = 3
var fan_deg: Array = [-20.0, 0.0, 20.0]
var shot_speed_px_s: float = 320.0
var shot_range_tiles: int = 10
var shot_size_px: Vector2 = Vector2(64.0, 32.0)
var count_attack_s: float = 0.5
var deflect_s: float = 0.25
var drops: Dictionary = {}
## Vida maxima (params.health del nivel). Cambiarla sin dano rellena la vida.
var max_health: float = 2.0:
	set(value):
		max_health = maxf(value, 1.0)
		if _health != null and _health.health >= _health.max_health:
			_health.reset(max_health)

## Isak al que dana y cuya columna sigue el rayo (si es null se busca en el nivel).
var target: Isak
## Vista de la camara en coordenadas globales para las pruebas (Rect2() = la del viewport).
var view_rect_override: Rect2 = Rect2()

var _state: StringName = &""
## Segundos (tiempo del mundo) dentro del clip actual / de la espera / del aturdimiento.
var _t: float = 0.0
var _stun_left: float = 0.0
var _delay_left: float = 0.0
var _deflect_left: float = 0.0
var _ready_ok: bool = false
var _health: EnemyHealth
var _banner: SpamBanner
var _bell: AlarmBell
var _shots: Array[NotificationShot] = []
var _body: StaticBody2D
var _clips: int = 0


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
	rect.size = get_card_size()
	shape.shape = rect
	shape.position = get_card_local_rect().get_center()
	_body.add_child(shape)
	add_child(_body)
	_banner = BANNER_SCENE.instantiate() as SpamBanner
	_banner.name = "Wave"
	add_child(_banner)
	_banner.manual = true
	_banner.interval_s = 0.0
	_banner.hit_player.connect(_on_child_hit)
	# El video avanza sus piezas en su propio paso (mismo cuadro que su clip).
	_banner.set_physics_process(false)
	_bell = BELL_SCENE.instantiate() as AlarmBell
	_bell.name = "Ray"
	add_child(_bell)
	_bell.manual = true
	_bell.draw_bell = false
	_bell.hit_player.connect(_on_child_hit)
	_bell.set_physics_process(false)
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_ready_ok = true
	reset_patrol()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas: tambien
## avanza la ola, el rayo y los proyectiles (si no procesan solos).
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var dt: float = WorldTime.scaled_delta(delta)
	var clips_before: int = _clips
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - dt, 0.0)
	match _state:
		STATE_BROKEN:
			pass
		STATE_STUNNED:
			_stun_left -= dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				if is_fully_in_view():
					_start_clip()
				else:
					_change_state(STATE_IDLE)
		STATE_IDLE:
			if is_fully_in_view():
				_delay_left -= dt
				if _delay_left <= 0.0:
					_start_clip()
			else:
				_delay_left = start_delay_s
		_:
			_t += dt
			if _state == STATE_WARN and _t >= get_warn_s():
				_change_state(STATE_ATTACK)
				if get_clip() == CLIP_COUNT:
					_fire_fan()
			if _state == STATE_ATTACK and _t >= get_warn_s() + get_attack_s():
				_change_state(STATE_REST)
			if _state == STATE_REST and _t >= get_clip_s():
				if is_fully_in_view():
					_start_clip()
				else:
					_delay_left = start_delay_s
					_change_state(STATE_IDLE)
	var started: bool = _clips != clips_before
	_step_children(delta, started)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func get_clip() -> StringName:
	return StringName(clip)


func is_warning() -> bool:
	return _state == STATE_WARN


func is_attacking() -> bool:
	return _state == STATE_ATTACK


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_broken() -> bool:
	return _state == STATE_BROKEN


## Algo de su clip puede danar ahora (la ola barriendo, el rayo o un proyectil).
func is_dangerous() -> bool:
	return (_banner != null and _banner.is_dangerous()) or (_bell != null and _bell.is_dangerous()) \
		or not get_shots().is_empty()


## En combate (PassiveRegen): con un clip en marcha o algo suyo volando.
func is_combat_active() -> bool:
	return _state in [STATE_WARN, STATE_ATTACK] or is_dangerous()


## Ayuda de Eco: mientras no este roto.
func is_help_available() -> bool:
	return _state != STATE_BROKEN


## Interfaz del laser que perfora (Laser 5): solo aturdido.
func is_laser_vulnerable() -> bool:
	return _state == STATE_STUNNED


## Aviso: anticipation_frames cuadros a anim_fps (s de tiempo del mundo).
func get_warn_s() -> float:
	return float(anticipation_frames) / anim_fps


## Duracion del ataque de su clip tras el aviso (s de tiempo del mundo).
func get_attack_s() -> float:
	match get_clip():
		CLIP_RAY:
			return ray_wave_s
		CLIP_COUNT:
			return count_attack_s
		_:
			return _banner.get_sweep_s() if _banner != null else 1.0


## Duracion de un clip: clip_s, o lo minimo para avisar, atacar y reposar.
func get_clip_s() -> float:
	return maxf(clip_s, get_warn_s() + get_attack_s() + min_rest_s)


## Segundos (tiempo del mundo) dentro del clip actual.
func get_clip_time() -> float:
	return _t


func get_stun_left() -> float:
	return _stun_left


func get_clip_count() -> int:
	return _clips


func get_health() -> float:
	return _health.health if _health != null else 0.0


func get_card_size() -> Vector2:
	return Vector2(card_tiles) * TILE


## Tarjeta en coordenadas locales: la celda E es la de abajo a la izquierda.
func get_card_local_rect() -> Rect2:
	var size: Vector2 = get_card_size()
	return Rect2(Vector2(-TILE * 0.5, -size.y), size)


func get_card_rect() -> Rect2:
	return Rect2(global_position + get_card_local_rect().position, get_card_size())


## Cuerpo para la onda del golpe al suelo (GroundPoundWave) y el pulso.
func get_body_rect() -> Rect2:
	return get_card_rect()


func get_banner() -> SpamBanner:
	return _banner


func get_bell() -> AlarmBell:
	return _bell


## Proyectiles de la cuenta que siguen volando.
func get_shots() -> Array[NotificationShot]:
	var out: Array[NotificationShot] = []
	for shot: NotificationShot in _shots:
		if is_instance_valid(shot) and not shot.is_done() and not shot.is_queued_for_deletion():
			out.append(shot)
	return out


## Vista de la camara (global): view_rect_override o la del viewport.
func get_view_rect() -> Rect2:
	if view_rect_override.has_area():
		return view_rect_override
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Rect2()
	var view := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	return viewport.get_canvas_transform().affine_inverse() * view


## La tarjeta entera dentro de la vista.
func is_fully_in_view() -> bool:
	return get_view_rect().encloses(get_card_rect())


# --- Acciones ---

## Interfaz del laser (LaserProjectile): despierto, chispa gris; aturdido, dano.
func on_laser_hit(damage: float, source: Node) -> void:
	if not _ready_ok or _state == STATE_BROKEN:
		return
	if not is_laser_vulnerable():
		_deflect(source)
		return
	take_damage(damage)


## Resta vida; a 0 se rompe y suelta sus drops. Verdadero si el golpe cuenta.
func take_damage(amount: float) -> bool:
	if not _ready_ok or _state == STATE_BROKEN or amount <= 0.0:
		return false
	var dies: bool = _health.take_damage(amount)
	damaged.emit(amount, _health.health)
	if dies:
		_break()
	return true


## Aturde (o reinicia el aturdimiento) stun_s x `duration_scale`: el clip se
## pausa y el ataque en curso se cancela. Sin efecto si esta roto.
func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or _state == STATE_BROKEN:
		return
	_cancel_attacks()
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_change_state(STATE_STUNNED)
	stunned.emit()


## Comprueba si el pulso (`area`) alcanza la tarjeta y la aturde (Pulso 3 y 5).
func receive_pulse(area: Area2D) -> bool:
	if _state == STATE_BROKEN or not PulseReceiver.pulse_reaches(area, get_card_rect()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	if GameState.claim_pulse_return(self) > 0.0:
		UpgradeFx.spawn(get_parent(), UpgradeFx.ENERGY_RETURN, get_card_rect().get_center())
	return true


## Vuelve al estado inicial (reaparicion de Isak, LevelRunner): sin clip ni
## ataques. Roto sigue roto.
func reset_patrol() -> void:
	if not _ready_ok:
		return
	_cancel_attacks()
	_stun_left = 0.0
	_deflect_left = 0.0
	_t = 0.0
	_delay_left = start_delay_s
	if _state != STATE_BROKEN:
		_change_state(STATE_IDLE)
	queue_redraw()


# --- Interno ---

func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)


func _start_clip() -> void:
	_t = 0.0
	_clips += 1
	_change_state(STATE_WARN)
	clip_started.emit(get_clip())
	match get_clip():
		CLIP_WAVE:
			_place_banner()
			_banner.trigger()
		CLIP_RAY:
			_place_bell()
			_bell.trigger()


## La ola sale de la columna de la tarjeta del lado de facing, por su fila de
## abajo (+ wave_row_offset), wave_tiles celdas hacia facing.
func _place_banner() -> void:
	var col: int = card_tiles.x - 1 if facing > 0 else 0
	_banner.direction = facing
	_banner.corridor_tiles = wave_tiles
	_banner.contact_damage = contact_damage
	_banner.global_position = global_position + Vector2(float(col) * TILE, float(wave_row_offset) * TILE)
	_banner.target = _find_player()
	_banner.reset_patrol()


## El rayo: la columna de Isak al empezar el clip (si no hay Isak, dos
## columnas por delante de la tarjeta), de la fila de arriba de la tarjeta
## (+ ray_top_offset) ray_tiles celdas hacia abajo.
func _place_bell() -> void:
	var col: int = card_tiles.x + 1 if facing > 0 else -2
	var isak: Isak = _find_player()
	if isak != null:
		col = int(floor((isak.global_position.x - get_card_rect().position.x) / TILE))
	var left: float = get_card_rect().position.x
	var top_row_y: float = get_card_rect().position.y + float(ray_top_offset) * TILE
	_bell.wave_tiles = ray_tiles
	_bell.wave_s = ray_wave_s
	_bell.contact_damage = contact_damage
	_bell.anticipation_frames = anticipation_frames
	_bell.anim_fps = anim_fps
	# La onda de la campana empieza un tile por encima de sus pies.
	_bell.global_position = Vector2(left + (float(col) + 0.5) * TILE, top_row_y + TILE)
	_bell.target = isak
	_bell.reset_patrol()


## La cuenta: fan_count proyectiles desde el centro de la tarjeta hacia facing.
func _fire_fan() -> void:
	var origin: Vector2 = get_card_rect().get_center()
	var host: Node = get_parent() if get_parent() != null else self
	for i: int in fan_count:
		var deg: float = float(fan_deg[i]) if i < fan_deg.size() else 0.0
		var heading := Vector2(float(facing), 0.0).rotated(deg_to_rad(deg) * float(facing))
		var shot := NotificationShot.new()
		shot.direction = facing
		shot.heading = heading
		shot.speed_px_s = shot_speed_px_s
		shot.size_px = shot_size_px
		shot.contact_damage = contact_damage
		shot.travel_px = float(shot_range_tiles) * TILE
		shot.target = _find_player()
		shot.hit_player.connect(_on_child_hit)
		shot.auto_process = false
		host.add_child(shot)
		shot.global_position = origin
		_shots.append(shot)


## Avanza la ola, el rayo y los proyectiles (no procesan solos: asi su aviso
## empieza en el mismo cuadro que la miniatura). En el cuadro en que empieza un
## clip (`started`) la ola y el rayo no avanzan: su tiempo cuenta desde el siguiente,
## como el del clip.
func _step_children(delta: float, started: bool = false) -> void:
	if not started:
		_banner.step(delta)
		_bell.step(delta)
	# Los proyectiles que tocan terreno se apagan (el abanico no atraviesa forjados).
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state if is_inside_tree() else null
	for shot: NotificationShot in get_shots():
		shot.step(WorldTime.scaled_delta(delta))
		if space == null or shot.is_queued_for_deletion():
			continue
		var query := PhysicsPointQueryParameters2D.new()
		query.position = shot.global_position
		query.collision_mask = LAYER_WORLD
		if not space.intersect_point(query, 1).is_empty():
			shot.queue_free()
	_shots = get_shots()


func _cancel_attacks() -> void:
	if _banner != null:
		_banner.reset_patrol()
	if _bell != null:
		_bell.reset_patrol()
	for shot: NotificationShot in _shots:
		if is_instance_valid(shot):
			shot.queue_free()
	_shots.clear()


func _break() -> void:
	_cancel_attacks()
	_stun_left = 0.0
	_change_state(STATE_BROKEN)
	_body.collision_layer = 0
	broken.emit()
	EventBus.enemy_defeated.emit(self)
	RechargePickup.spawn_drops(get_parent(), global_position, drops)
	queue_redraw()


func _deflect(_source: Node) -> void:
	_deflect_left = deflect_s
	deflected.emit()
	queue_redraw()


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


func _on_child_hit(amount: float) -> void:
	hit_player.emit(amount)


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 2) ---

func _draw() -> void:
	var rect: Rect2 = get_card_local_rect()
	var broken_now: bool = _state == STATE_BROKEN
	FeedCardDraw.card(self, rect, 0.55 if broken_now else 1.0)
	var screen := Rect2(rect.position + Vector2(10.0, 14.0), rect.size - Vector2(20.0, 30.0))
	draw_rect(screen, World2ObjectsConfig.color("feed_noche"))
	var white: Color = World2ObjectsConfig.color("blanco")
	var red: Color = World2ObjectsConfig.color("alerta")
	var frame: int = int(floor(_t * anim_fps))
	match _state:
		STATE_BROKEN:
			FeedCardDraw.crack(self, screen, 1.0, World2ObjectsConfig.color("gris"))
			return
		STATE_WARN:
			# Miniatura del clip que parpadea, con un marco rojo de aviso.
			if frame % 2 == 0:
				draw_rect(screen.grow(3.0), red, false, 3.0)
			_draw_thumbnail(screen, red)
		STATE_ATTACK:
			draw_rect(screen, World2ObjectsConfig.color("feed_resplandor"))
			_draw_thumbnail(screen, white)
		STATE_STUNNED:
			# Pausa: dos barras.
			var c: Vector2 = screen.get_center()
			draw_rect(Rect2(c + Vector2(-14.0, -16.0), Vector2(10.0, 32.0)), white)
			draw_rect(Rect2(c + Vector2(4.0, -16.0), Vector2(10.0, 32.0)), white)
		_:
			_draw_play(screen, World2ObjectsConfig.color("gris"))
	# Barra de progreso del clip.
	if _state in [STATE_WARN, STATE_ATTACK, STATE_REST]:
		var p: float = clampf(_t / get_clip_s(), 0.0, 1.0)
		var bar := Rect2(Vector2(screen.position.x, rect.end.y - 12.0), Vector2(screen.size.x, 4.0))
		draw_rect(bar, World2ObjectsConfig.color("tarjeta_sombra"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), World2ObjectsConfig.color("magenta"))
	if _deflect_left > 0.0:
		var c2: Vector2 = rect.get_center()
		var grey: Color = World2ObjectsConfig.color("gris")
		for a: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(14.0, 0.0).rotated(deg_to_rad(a))
			draw_line(c2 - d, c2 + d, grey, 2.0)


func _draw_play(screen: Rect2, color: Color) -> void:
	var c: Vector2 = screen.get_center()
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10.0, -14.0), c + Vector2(-10.0, 14.0),
		c + Vector2(14.0, 0.0)]), color)


func _draw_thumbnail(screen: Rect2, color: Color) -> void:
	var c: Vector2 = screen.get_center()
	match get_clip():
		CLIP_RAY:
			draw_rect(Rect2(Vector2(c.x - 6.0, screen.position.y + 4.0), Vector2(12.0, screen.size.y - 8.0)), color)
		CLIP_COUNT:
			var n: int = clampi(3 - int(floor(_t / maxf(get_warn_s() / 3.0, 0.001))), 1, 3)
			if _state == STATE_ATTACK:
				for i: int in fan_count:
					var deg: float = float(fan_deg[i]) if i < fan_deg.size() else 0.0
					var d := Vector2(float(facing) * 22.0, 0.0).rotated(deg_to_rad(deg) * float(facing))
					draw_line(c, c + d, color, 3.0)
			else:
				var font: Font = ThemeDB.fallback_font
				draw_string(font, c + Vector2(-9.0, 12.0), str(n), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 32, color)
		_:
			for i: int in 3:
				var y: float = screen.position.y + 10.0 + float(i) * 12.0
				var pts := PackedVector2Array()
				for k: int in 7:
					var x: float = screen.position.x + 4.0 + float(k) * (screen.size.x - 8.0) / 6.0
					pts.append(Vector2(x, y + (3.0 if (k + i) % 2 == 0 else -3.0)))
				draw_polyline(pts, color, 2.0)


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("AutoplayVideo: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	clip = String(d.get("clip", "wave"))
	facing = int(d.get("facing", 1))
	clip_s = float(d["clip_s"])
	start_delay_s = float(d.get("start_delay_s", 0.0))
	min_rest_s = float(d.get("min_rest_s", 0.25))
	anim_fps = float(d["anim_fps"])
	anticipation_frames = int(d["anticipation_frames"])
	contact_damage = float(d["contact_damage"])
	stun_s = float(d["stun_s"])
	max_health = float(d["health"])
	drops = EnemyHealth.parse_drops(d.get("drops", {}))
	var ct: Array = d.get("card_tiles", [2, 2])
	card_tiles = Vector2i(int(ct[0]), int(ct[1]))
	wave_tiles = int(d["wave_tiles"])
	wave_row_offset = int(d.get("wave_row_offset", 0))
	ray_tiles = int(d["ray_tiles"])
	ray_top_offset = int(d.get("ray_top_offset", 0))
	ray_wave_s = float(d["ray_wave_s"])
	fan_count = int(d["fan_count"])
	fan_deg = d.get("fan_deg", fan_deg)
	shot_speed_px_s = float(d["shot_speed_px_s"])
	shot_range_tiles = int(d["shot_range_tiles"])
	var ss: Array = d.get("shot_size_px", [64.0, 32.0])
	shot_size_px = Vector2(float(ss[0]), float(ss[1]))
	count_attack_s = float(d.get("count_attack_s", 0.5))
	deflect_s = float(d.get("deflect_s", 0.25))
	return true
