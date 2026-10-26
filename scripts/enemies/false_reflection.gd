## Reflejo falso (Mundo 3 «La Vitrina»; paso 6 de docs/propuesta-mundo-3.md §8,
## comportamiento en §3.6, patron 17 de §3.5). Valores y explicacion en
## data/enemies/false_reflection.json. Primera aparicion de Isak Optimizado:
## INDESTRUCTIBLE.
##
## Estados:
## - dormant: invisible y sin colision. Graba a Isak (IsakPoseBuffer) mientras esta
##   en su sala (`zone`, [columna, fila, ancho, alto] en celdas; vacia = sin
##   limite). Cuando Isak CRUZA LA LINEA de su pared de espejo (`mirror_wall`, id
##   de un MirrorWall: su eje get_axis_x(); o axis_x en las pruebas) sale.
## - emerging: aparece en emerge_frames cuadros (9 a 60 fps = 0,15 s) donde Isak
##   cruzo la linea y espera ahi hasta empezar a reproducir (delay_s): es el
##   aviso, aun no dana (decision del paso 6: si danara al salir, Isak, que acaba
##   de cruzar a su lado, se lo comeria sin margen). Despues, active.
## - active: REPRODUCE la posicion y la pose de Isak de hace delay_s (1 s; nunca
##   de antes de salir: el primer segundo se queda en la linea). Dibujo = el cuadro
##   del sprite de Isak de ese momento con la variante SATURADA (shader de
##   MirrorWall); sin peso (ni mochila ni glitch: solo el cuadro). DANA AL
##   CONTACTO contact_damage (10; take_hit + apply_sync_damage). PISA las placas
##   «Posa aqui» como Isak (grupo PosePlate.PRESSER_GROUP, get_plate_feet()).
## - stunned: el PULSO (de Isak o el haz del espejo cazador) lo aturde stun_s
##   (x el multiplicador del Pulso 3): quieto donde estaba, con un velo de
##   estatica, sin danar (sigue pisando la placa en la que este). Al despertar
##   SALTA AL PUNTO ACTUAL del bufer (otra vez delay_s por detras de Isak).
## El laser rebota en el (chispa gris; indestructible). Desaparece (dormant) al
## salir Isak de su sala y al reaparecer Isak.
## Tiempo: el bufer graba en tiempo real (como Isak) y la reproduccion va en
## tiempo del mundo: con el Debug el retraso crece (lo ralentiza) y despues
## vuelve a delay_s a catchup_rate segundos por segundo (sin pasar de
## max_lag_s). Origen = los pies (como Isak).
class_name FalseReflection
extends Area2D

signal state_changed(previous: StringName, current: StringName)
## Ha salido de la pared (sonido sfx_w3_reflection_spawn, paso 19).
signal emerged
## Ha desaparecido (Isak salio de la sala o reaparecio).
signal vanished
signal stunned
signal woke
## Ha danado a Isak.
signal hit_player(damage: float)
## El laser ha rebotado en el.
signal deflected

const STATE_DORMANT: StringName = &"dormant"
const STATE_EMERGING: StringName = &"emerging"
const STATE_ACTIVE: StringName = &"active"
const STATE_STUNNED: StringName = &"stunned"

const DEFAULT_DATA_PATH: String = "res://data/enemies/false_reflection.json"
const GROUP: StringName = &"enemy"
const LAYER_ENEMY: int = 4

@export_file("*.json") var data_path: String = DEFAULT_DATA_PATH
## Id de la pared de espejo de la que sale (params del nivel).
@export var mirror_wall: String = ""
## Sala: [columna, fila, ancho, alto] en celdas (params del nivel).
@export var zone: Array = []
## Eje de salida (x global) si no hay pared de espejo (pruebas). NAN = el de la pared.
var axis_x: float = NAN
## Si es false, _physics_process no avanza (las pruebas llaman a step()).
var auto_process: bool = true
## Isak al que copia (si es null se busca en el nivel).
var target: Isak

var delay_s: float = 1.0
var buffer_s: float = 3.0
var max_lag_s: float = 2.5
var catchup_rate: float = 0.5
var contact_damage: float = 10.0
var stun_s: float = 3.0
var emerge_frames: int = 9
var anim_fps: float = 60.0
var deflect_s: float = 0.25
var saturation: float = 1.35
var tint: String = "rosa_pastel"
var veil_alpha: float = 0.55
var veil_cells_px: float = 6.0

var _state: StringName = STATE_DORMANT
var _state_t: float = 0.0
var _buffer: IsakPoseBuffer
var _lag: float = 1.0
var _emerge_t: float = 0.0
var _prev_side: float = 0.0
var _sample: Dictionary = {}
var _stun_left: float = 0.0
var _deflect_left: float = 0.0
var _noise_t: float = 0.0
var _ready_ok: bool = false
var _shape: CollisionShape2D
var _sprite: Sprite2D
var _veil: Node2D
var _material: ShaderMaterial


func _ready() -> void:
	if not _load_data():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	add_to_group(PosePlate.PRESSER_GROUP)
	add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	_buffer = IsakPoseBuffer.new(buffer_s)
	_lag = delay_s
	_shape = CollisionShape2D.new()
	_shape.name = "BodyShape"
	_shape.shape = RectangleShape2D.new()
	_shape.disabled = true
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MirrorWall.SATURATION_SHADER
	_material.shader = shader
	_material.set_shader_parameter(&"saturation", saturation)
	_material.set_shader_parameter(&"tint", World3ObjectsConfig.color(tint, Color.WHITE))
	_sprite.material = _material
	add_child(_sprite)
	_veil = Node2D.new()
	_veil.name = "StaticVeil"
	_veil.draw.connect(_draw_veil)
	add_child(_veil)
	EventBus.pulse_fired.connect(_on_pulse_fired)
	EventBus.player_respawned.connect(_on_player_respawned)
	_ready_ok = true
	_update_visual()


func _physics_process(delta: float) -> void:
	if auto_process:
		step(delta)


## Un paso con `delta` REAL (la reproduccion se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _ready_ok:
		return
	var world_dt: float = WorldTime.scaled_delta(delta)
	_state_t += world_dt
	_noise_t += world_dt
	if _deflect_left > 0.0:
		_deflect_left = maxf(_deflect_left - world_dt, 0.0)
	var isak: Isak = _find_player()
	var inside: bool = isak != null and not isak.is_dead() and is_isak_in_zone(isak)
	if not inside:
		if _state != STATE_DORMANT:
			vanish()
		_prev_side = 0.0
		_buffer.clear()
		_update_visual()
		return
	_buffer.record(isak, delta)
	# Retraso: crece con el Debug y vuelve despues a delay_s.
	_lag += delta - world_dt
	if WorldTime.scale() >= 0.999 and _lag > delay_s:
		_lag = maxf(delay_s, _lag - catchup_rate * delta)
	_lag = clampf(_lag, delay_s, maxf(max_lag_s, delay_s))
	match _state:
		STATE_DORMANT:
			var side: float = signf(isak.global_position.x - get_axis_x())
			if _prev_side != 0.0 and side != 0.0 and side != _prev_side:
				emerge()
			if side != 0.0:
				_prev_side = side
		STATE_EMERGING:
			_follow()
			# Sale (aviso de emerge_frames) y espera en la linea hasta reproducir.
			if _state_t >= get_emerge_s() - 0.0001 and _buffer.now() - _emerge_t >= _lag - 0.0001:
				_change_state(STATE_ACTIVE)
		STATE_ACTIVE:
			_follow()
			_check_contact(isak)
		STATE_STUNNED:
			_stun_left -= world_dt
			if _stun_left <= 0.0:
				_stun_left = 0.0
				# Salta al punto actual del bufer.
				_lag = delay_s
				_change_state(STATE_ACTIVE)
				_follow()
				woke.emit()
	_update_visual()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_dormant() -> bool:
	return _state == STATE_DORMANT


func is_active() -> bool:
	return _state == STATE_ACTIVE


func is_emerging() -> bool:
	return _state == STATE_EMERGING


func is_stunned() -> bool:
	return _state == STATE_STUNNED


## Visible (fuera de la pared).
func is_present() -> bool:
	return _state != STATE_DORMANT


func is_dangerous() -> bool:
	return _state == STATE_ACTIVE


func is_combat_active() -> bool:
	return _state == STATE_ACTIVE


func is_laser_vulnerable() -> bool:
	return false


func is_help_available() -> bool:
	return is_present()


func get_emerge_s() -> float:
	return float(emerge_frames) / maxf(anim_fps, 1.0)


func get_stun_left() -> float:
	return _stun_left


## Retraso actual de la reproduccion (s; delay_s sin Debug).
func get_lag_s() -> float:
	return _lag


func get_buffer() -> IsakPoseBuffer:
	return _buffer


## Eje de la pared de espejo (x global).
func get_axis_x() -> float:
	if not is_nan(axis_x):
		return axis_x
	var wall: MirrorWall = get_mirror_wall()
	return wall.get_axis_x() if wall != null else global_position.x


func get_mirror_wall() -> MirrorWall:
	if mirror_wall == "" or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(MirrorWall.GROUP):
		var w := node as MirrorWall
		if w != null and String(w.object_id) == mirror_wall:
			return w
	return null


## Sala en px (global); Rect2() sin zona.
func get_zone_rect() -> Rect2:
	if zone.size() != 4:
		return Rect2()
	var t: float = World3ObjectsConfig.tile_size()
	return Rect2(float(zone[0]) * t, float(zone[1]) * t, float(zone[2]) * t, float(zone[3]) * t)


func is_isak_in_zone(isak: Isak) -> bool:
	var r: Rect2 = get_zone_rect()
	if not r.has_area():
		return true
	return r.has_point(LevelLookup.isak_body_rect(isak).get_center())


## Muestra que reproduce ({} dormido).
func get_sample() -> Dictionary:
	return _sample


## Cuerpo (global) con la caja de Isak de ese momento; Rect2() dormido.
func get_body_rect_now() -> Rect2:
	if not is_present() or _sample.is_empty():
		return Rect2()
	var size: Vector2 = _sample.get("hitbox_size", Vector2(40.0, 96.0))
	return Rect2(global_position.x - size.x * 0.5, global_position.y - size.y, size.x, size.y)


## Pies para las placas «Posa aqui»; {} dormido.
func get_plate_feet() -> Dictionary:
	if not is_present() or _sample.is_empty():
		return {}
	var size: Vector2 = _sample.get("hitbox_size", Vector2(40.0, 96.0))
	return {"feet": global_position, "width": size.x, "on_floor": bool(_sample.get("on_floor", true))}


func get_sprite() -> Sprite2D:
	return _sprite


func get_shader_material() -> ShaderMaterial:
	return _material


# --- Acciones ---

## Sale de la pared donde esta Isak ahora (lo llama el cruce de la linea).
func emerge() -> void:
	if not _ready_ok or _state != STATE_DORMANT:
		return
	_emerge_t = _buffer.now()
	_lag = delay_s
	_change_state(STATE_EMERGING)
	_follow()
	emerged.emit()


## Vuelve a la pared (dormido) y olvida el bufer.
func vanish() -> void:
	if _state == STATE_DORMANT:
		return
	_change_state(STATE_DORMANT)
	_stun_left = 0.0
	_sample = {}
	_buffer.clear()
	_prev_side = 0.0
	_update_visual()
	vanished.emit()


func stun(duration_scale: float = 1.0) -> void:
	if not _ready_ok or not is_present():
		return
	_stun_left = stun_s * maxf(duration_scale, 0.0)
	_change_state(STATE_STUNNED)
	stunned.emit()
	_update_visual()


func receive_pulse(area: Area2D) -> bool:
	if not is_present() or not PulseReceiver.pulse_reaches(area, get_body_rect_now()):
		return false
	stun(GameState.get_pulse_stun_multiplier())
	return true


func on_laser_hit(_damage: float, _source: Node) -> void:
	_deflect_left = deflect_s
	deflected.emit()
	_veil.queue_redraw()


# --- Interno ---

func _change_state(next: StringName) -> void:
	var previous: StringName = _state
	_state = next
	_state_t = 0.0
	if previous != next:
		state_changed.emit(previous, next)


## Coloca el reflejo en la muestra de hace min(retraso, tiempo desde que salio).
func _follow() -> void:
	var since: float = _buffer.now() - _emerge_t
	var s: Dictionary = _buffer.sample(minf(_lag, maxf(since, 0.0)))
	if s.is_empty():
		return
	_sample = s
	global_position = s["position"]


func _check_contact(isak: Isak) -> void:
	if isak == null or isak.is_dead():
		return
	var body: Rect2 = get_body_rect_now()
	if not body.has_area() or not LevelLookup.isak_body_rect(isak).intersects(body):
		return
	var dir: float = signf(isak.global_position.x - global_position.x)
	if isak.take_hit(dir):
		GameState.apply_sync_damage(contact_damage)
		hit_player.emit(contact_damage)


func _update_visual() -> void:
	if _sprite == null:
		return
	var present: bool = is_present() and not _sample.is_empty()
	collision_layer = LAYER_ENEMY if present else 0
	var size: Vector2 = _sample.get("hitbox_size", Vector2(40.0, 96.0)) if present else Vector2(40.0, 96.0)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = Vector2(0.0, -size.y * 0.5)
	_shape.set_deferred(&"disabled", not present)
	var texture: Texture2D = _sample.get("texture") as Texture2D if present else null
	_sprite.visible = present and texture != null
	if _sprite.visible:
		_sprite.texture = texture
		_sprite.centered = bool(_sample["centered"])
		_sprite.flip_h = bool(_sample["flip_h"])
		_sprite.position = _sample["sprite_position"]
		_sprite.scale = _sample["sprite_scale"]
		_sprite.rotation = float(_sample["sprite_rotation"])
		_sprite.offset = _sample["sprite_offset"]
		var a: float = 1.0
		if _state == STATE_EMERGING:
			a = clampf(_state_t / maxf(get_emerge_s(), 0.001), 0.15, 1.0)
		_sprite.modulate = Color(1.0, 1.0, 1.0, a)
	_veil.queue_redraw()


## Velo de estatica (aturdido) y chispa del laser. PROVISIONAL por codigo.
func _draw_veil() -> void:
	if not is_present():
		return
	var body: Rect2 = get_body_rect_now()
	var local := Rect2(body.position - global_position, body.size)
	if _state == STATE_STUNNED:
		var light: Color = World3ObjectsConfig.color("blanco_brillante")
		var dark: Color = World3ObjectsConfig.color("galeria_noche")
		var cell: float = maxf(veil_cells_px, 2.0)
		var seed_t: int = int(floor(_noise_t * 20.0))
		var cols: int = int(ceil(local.size.x / cell))
		var rows: int = int(ceil(local.size.y / cell))
		for j: int in rows:
			for i: int in cols:
				var h: int = hash(Vector3i(i, j, seed_t))
				if h % 3 == 0:
					continue
				var col: Color = light if h % 2 == 0 else dark
				_veil.draw_rect(Rect2(local.position + Vector2(i, j) * cell, Vector2(cell, cell)), Color(col, veil_alpha))
	if _deflect_left > 0.0:
		var grey: Color = World3ObjectsConfig.color("gris_perla")
		var c: Vector2 = local.get_center()
		for ang: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(12.0, 0.0).rotated(deg_to_rad(ang))
			_veil.draw_line(c - d, c + d, grey, 2.0)


func _find_player() -> Isak:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target
	target = LevelLookup.find_isak(self)
	return target


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


func _on_player_respawned(_position: Vector2, _after_death: bool) -> void:
	vanish()
	_buffer.clear()
	_prev_side = 0.0
	_lag = delay_s


func _load_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not parsed is Dictionary:
		push_error("FalseReflection: no se pudo leer '%s'." % data_path)
		return false
	var d: Dictionary = parsed
	delay_s = float(d["delay_s"])
	buffer_s = float(d["buffer_s"])
	max_lag_s = float(d.get("max_lag_s", 2.5))
	catchup_rate = float(d.get("catchup_rate", 0.5))
	contact_damage = float(d["contact_damage"])
	stun_s = float(d["stun_s"])
	emerge_frames = int(d["emerge_frames"])
	anim_fps = float(d.get("anim_fps", 60.0))
	deflect_s = float(d.get("deflect_s", 0.25))
	saturation = float(d.get("saturation", 1.35))
	tint = String(d.get("tint", "rosa_pastel"))
	veil_alpha = float(d.get("veil_alpha", 0.55))
	veil_cells_px = float(d.get("veil_cells_px", 6.0))
	return true
