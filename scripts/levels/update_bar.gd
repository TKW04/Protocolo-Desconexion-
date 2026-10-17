## Barra de actualizacion del 99 % (tipo `update_bar` del catalogo del Mundo 1;
## piso 4 «Actualizaciones» del 1-2, §3.4 de docs/propuesta-1-2.md; paso 8 de
## §10; docs/mundo-1-notificaciones.md §6.4: «barra de progreso trabada en
## 99 % y un tramo de espera humoristico con enemigos cayendo»).
##
## - Puerta SOLIDA de 1 x 3 tiles (capa world) con un indicador de progreso y
##   un cartel de texto encima («Instalando… 97 %»).
## - Se ARMA cuando Isak entra en su zona (arm_zone, rectangulo de celdas):
##   sube rapido (rise_s) a 99 % y se TRABA: espera wait_s segundos de TIEMPO
##   DEL MUNDO (el Debug la alarga x2; la pausa la para) con textos que cambian
##   («99 %», «99,9 %», «Calculando tiempo restante…», «Casi listo»).
## - Oleadas (waves: [{t, type, x, params}], t en segundos de la espera): cada
##   enemigo se anuncia warn_s antes (0,75 s = 9 cuadros a 12 fps) con una
##   flecha roja en el techo y una sombra en el suelo de la columna x; en t cae
##   un «paquete» desde el techo de la zona y, al tocar el suelo, se abre y
##   sale el enemigo (type: alert_bubble o notification_badge, con sus params
##   como los de la lista enemies del nivel). Los enemigos se esquivan o se
##   matan (sus drops reponen energia). El paquete no hace dano.
## - Al acabar la espera llega al 100 % («Reiniciando…»): los enemigos que
##   queden se apagan con un pop (sin drops) y la puerta se recoge hacia el
##   techo y deja de ser solida. Abierta, queda abierta.
## - Si Isak reaparece (EventBus.player_respawned) antes de abrirla, vuelve al
##   principio: 97 %, sin enemigos ni avisos; se vuelve a armar al entrar en la
##   zona. Abierta, no se reinicia.
## El origen del nodo es la esquina superior izquierda de su celda de arriba.
class_name UpdateBar
extends StaticBody2D

enum State { IDLE, RISING, STUCK, FULL, OPENING, OPEN }

const GROUP: StringName = &"update_bar"
const LAYER_WORLD: int = 1
const HEIGHT_TILES: int = 3
const ENEMY_SCENE: String = "res://scenes/enemies/%s.tscn"
const ENEMY_DATA: String = "res://data/enemies/%s.json"

signal armed
## Ha llegado al 99 % y empieza la espera.
signal stuck
## Aviso de la caida de un enemigo de la oleada (indice en waves).
signal wave_warned(index: int)
## Ha salido un enemigo de la oleada.
signal enemy_spawned(enemy: Node2D, index: int)
## 100 %: se abre.
signal completed
## Puerta recogida: ya no es solida.
signal opened
## Ha vuelto al principio (reaparicion de Isak).
signal reset_done

@export var object_id: StringName = &""
## Segundos de espera trabada en el 99 % (tiempo del mundo).
@export var wait_s: float = 20.0
## Segundos de la subida de 97 % a 99 %.
@export var rise_s: float = 1.0
## Zona que la arma: [columna, fila, ancho, alto] en celdas.
@export var arm_zone: Array = []
## Oleadas: [{t, type, x, params}].
@export var waves: Array = []

var _config: Dictionary = World1ObjectsConfig.section("update_bar")
var _state: State = State.IDLE
var _state_time: float = 0.0
var _time: float = 0.0
var _frames: SpriteFrames
var _shape: CollisionShape2D
var _sprite: AnimatedSprite2D
var _plate: Node2D
var _label: Label
var _font: Font
var _effects: Node2D
## Por oleada: 0 pendiente, 1 avisada, 2 cayendo, 3 hecha.
var _wave_phase: Array[int] = []
var _wave_nodes: Array = []
var _wave_floor: Array[float] = []
var _spawned: Array[Node2D] = []
var _isak: Isak
var _resets: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_frames = load(String(_config.get("frames", ""))) as SpriteFrames
	var size: Vector2 = get_size_px()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	add_child(_shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = _frames
	_sprite.centered = false
	add_child(_sprite)
	_effects = Node2D.new()
	_effects.name = "Waves"
	_effects.top_level = true
	_effects.z_index = int(_config.get("effects_z_index", 5))
	add_child(_effects)
	_build_plate()
	_clear_waves()
	EventBus.player_respawned.connect(_on_player_respawned)
	_update_visual()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


func is_open() -> bool:
	return _state == State.OPEN


func is_solid() -> bool:
	return _state != State.OPENING and _state != State.OPEN


func is_waiting() -> bool:
	return _state == State.STUCK


## Segundos de espera que quedan (wait_s antes de armarla; 0 al acabar).
func get_wait_left() -> float:
	match _state:
		State.IDLE, State.RISING:
			return wait_s
		State.STUCK:
			return maxf(wait_s - _state_time, 0.0)
	return 0.0


## Segundos de espera trabada transcurridos.
func get_wait_elapsed() -> float:
	return _state_time if _state == State.STUCK else (wait_s if _state > State.STUCK else 0.0)


## Porcentaje que muestra (97 en reposo, 99 trabada, 100 al acabar).
func get_percent() -> float:
	match _state:
		State.IDLE:
			return float(_config.get("idle_percent", 97))
		State.RISING:
			return lerpf(float(_config.get("idle_percent", 97)), 99.0, clampf(_state_time / maxf(rise_s, 0.01), 0.0, 1.0))
		State.STUCK:
			return 99.0
	return 100.0


func get_text() -> String:
	return _label.text if _label != null else ""


func get_size_px() -> Vector2:
	var t: float = World1ObjectsConfig.tile_size()
	return Vector2(t, t * HEIGHT_TILES)


## Zona que la arma en px (globales).
func get_arm_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	if arm_zone.size() < 4:
		return Rect2()
	return Rect2(float(arm_zone[0]) * t, float(arm_zone[1]) * t, float(arm_zone[2]) * t, float(arm_zone[3]) * t)


## Enemigos de las oleadas que siguen vivos.
func get_spawned() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for e: Node2D in _spawned:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			out.append(e)
	return out


## Avisos (flecha y sombra) en pantalla ahora.
func get_warning_count() -> int:
	var count: int = 0
	for i: int in _wave_phase.size():
		if _wave_phase[i] == 1:
			count += 1
	return count


## Paquetes cayendo ahora.
func get_falling_count() -> int:
	var count: int = 0
	for i: int in _wave_phase.size():
		if _wave_phase[i] == 2:
			count += 1
	return count


func get_reset_count() -> int:
	return _resets


func get_animation() -> StringName:
	return _sprite.animation


## Ayuda de Eco: hasta abrirse (abierta ya no hay nada que esperar).
func is_help_available() -> bool:
	return _state != State.OPENING and _state != State.OPEN


# --- Acciones ---

## Empieza (Isak ha entrado en su zona). Verdadero si se ha armado ahora.
func arm() -> bool:
	if _state != State.IDLE:
		return false
	_set_state(State.RISING)
	armed.emit()
	return true


## Termina la espera ya (pruebas y herramientas).
func finish() -> void:
	if _state == State.IDLE or _state == State.RISING or _state == State.STUCK:
		_complete()


## Vuelve al principio (sin efecto si ya esta abierta o abriendose).
func reset() -> void:
	if _state == State.OPENING or _state == State.OPEN:
		return
	for e: Node2D in get_spawned():
		e.queue_free()
	_spawned.clear()
	_clear_waves()
	_resets += 1
	_set_state(State.IDLE)
	reset_done.emit()


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += dt
	_state_time += dt
	match _state:
		State.IDLE:
			if _isak_in_zone():
				arm()
		State.RISING:
			if _state_time >= rise_s:
				_set_state(State.STUCK)
				stuck.emit()
		State.STUCK:
			_update_waves(dt)
			if _state_time >= wait_s:
				_complete()
		State.FULL:
			if _state_time >= float(_config.get("full_s", 0.6)):
				_shape.disabled = true
				_set_state(State.OPENING)
		State.OPENING:
			if _state_time >= _anim_length(&"update_bar_open"):
				_set_state(State.OPEN)
				opened.emit()
	_update_falling(dt)
	_update_visual()


# --- Oleadas ---

func _clear_waves() -> void:
	for nodes: Variant in _wave_nodes:
		for n: Variant in (nodes as Array):
			if is_instance_valid(n):
				(n as Node).queue_free()
	_wave_phase.clear()
	_wave_nodes.clear()
	_wave_floor.clear()
	for i: int in waves.size():
		_wave_phase.append(0)
		_wave_nodes.append([])
		_wave_floor.append(0.0)


func _wave_time(i: int) -> float:
	return float((waves[i] as Dictionary).get("t", 0.0))


func _wave_x(i: int) -> float:
	return (float((waves[i] as Dictionary).get("x", 0)) + 0.5) * World1ObjectsConfig.tile_size()


func _update_waves(_dt: float) -> void:
	var warn: float = get_warn_s()
	for i: int in waves.size():
		if _wave_phase[i] == 0 and _state_time >= _wave_time(i) - warn:
			_warn_wave(i)
		if _wave_phase[i] == 1 and _state_time >= _wave_time(i):
			_drop_wave(i)


## Segundos de aviso antes de cada caida (anticipation_frames a anim_fps).
func get_warn_s() -> float:
	return float(_config.get("anticipation_frames", 9)) / maxf(float(_config.get("anim_fps", 12.0)), 0.01)


func _top_y() -> float:
	var r: Rect2 = get_arm_rect()
	return r.position.y if r.size != Vector2.ZERO else global_position.y


func _floor_y(x: float) -> float:
	var r: Rect2 = get_arm_rect()
	var fallback: float = r.end.y if r.size != Vector2.ZERO else global_position.y + get_size_px().y
	if not is_inside_tree():
		return fallback
	var from := Vector2(x, _top_y() + 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, Vector2(x, fallback + 4.0), LAYER_WORLD)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return float((hit["position"] as Vector2).y) if not hit.is_empty() else fallback


func _warn_wave(i: int) -> void:
	_wave_phase[i] = 1
	var x: float = _wave_x(i)
	_wave_floor[i] = _floor_y(x)
	var arrow := _fx_sprite(&"drop_arrow", Vector2(x, _top_y() + 80.0))
	var shadow := _fx_sprite(&"drop_shadow", Vector2(x, _wave_floor[i] - 12.0))
	_wave_nodes[i] = [arrow, shadow]
	wave_warned.emit(i)


func _drop_wave(i: int) -> void:
	_wave_phase[i] = 2
	for n: Variant in (_wave_nodes[i] as Array):
		if is_instance_valid(n):
			(n as Node).queue_free()
	var pack := _fx_sprite(&"package_fall", Vector2(_wave_x(i), _top_y() + 32.0))
	_wave_nodes[i] = [pack]


func _update_falling(dt: float) -> void:
	var speed: float = float(_config.get("package_fall_px_s", 900.0))
	for i: int in _wave_phase.size():
		var nodes: Array = _wave_nodes[i]
		if nodes.is_empty() or not is_instance_valid(nodes[0]):
			continue
		var sprite := nodes[0] as AnimatedSprite2D
		sprite.set_meta(&"t", float(sprite.get_meta(&"t", 0.0)) + dt)
		var t: float = float(sprite.get_meta(&"t"))
		var anim: StringName = sprite.animation
		var count: int = _frames.get_frame_count(anim)
		var f: int = floori(t * _frames.get_animation_speed(anim))
		sprite.frame = f % count if _frames.get_animation_loop(anim) else mini(f, count - 1)
		if _wave_phase[i] == 2 and anim == &"package_fall":
			sprite.position.y = minf(sprite.position.y + speed * dt, _wave_floor[i] - 32.0)
			if sprite.position.y >= _wave_floor[i] - 32.0:
				_wave_phase[i] = 3
				sprite.animation = &"package_open"
				sprite.set_meta(&"t", 0.0)
				sprite.frame = 0
				_spawn_enemy(i)
		elif anim == &"package_open" and f >= count:
			sprite.queue_free()
			_wave_nodes[i] = []


func _fx_sprite(anim: StringName, pos: Vector2) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _frames
	sprite.animation = anim
	sprite.centered = true
	sprite.position = pos
	sprite.scale = Vector2.ONE * float(_config.get("effects_scale", 2))
	sprite.set_meta(&"t", 0.0)
	_effects.add_child(sprite)
	return sprite


func _spawn_enemy(i: int) -> Node2D:
	var wave: Dictionary = waves[i]
	var type: String = String(wave.get("type", "alert_bubble"))
	var scene := load(ENEMY_SCENE % type) as PackedScene
	if scene == null:
		push_warning("UpdateBar %s: no hay escena de enemigo '%s'" % [object_id, type])
		return null
	var enemy := scene.instantiate() as Node2D
	enemy.name = "%s_ola_%d_%d" % [object_id, i, _resets]
	enemy.position = Vector2(_wave_x(i), _wave_floor[i])
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_DATA % type))
	if data is Dictionary and String((data as Dictionary).get("help_id", "")) != "":
		HelpCatalog.tag(enemy, StringName(String((data as Dictionary)["help_id"])))
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(enemy)
	enemy.global_position = Vector2(_wave_x(i), _wave_floor[i])
	# Params de la oleada tras su _ready, como GeneratedLevel con los del nivel.
	var params: Variant = wave.get("params", {})
	if params is Dictionary:
		for key: Variant in params:
			var property: String = String(GeneratedLevel.ENEMY_PARAM_ALIASES.get(String(key), String(key)))
			if property in enemy:
				enemy.set(property, params[key])
	_spawned.append(enemy)
	enemy_spawned.emit(enemy, i)
	return enemy


func _complete() -> void:
	for i: int in _wave_phase.size():
		if _wave_phase[i] < 3:
			for n: Variant in (_wave_nodes[i] as Array):
				if is_instance_valid(n):
					(n as Node).queue_free()
			_wave_nodes[i] = []
			_wave_phase[i] = 3
	# Los enemigos que queden se apagan con un pop (sin drops: no es un premio).
	for e: Node2D in get_spawned():
		if e.has_method(&"get_state") and e.call(&"get_state") == &"popped":
			continue
		if &"drops" in e:
			e.set(&"drops", {})
		if e.has_method(&"pop"):
			e.call(&"pop")
		else:
			e.queue_free()
	_set_state(State.FULL)
	completed.emit()


# --- Interno ---

func _set_state(next: State) -> void:
	_state = next
	_state_time = 0.0
	_update_visual()


func _anim_length(anim: StringName) -> float:
	return _frames.get_frame_count(anim) / maxf(_frames.get_animation_speed(anim), 0.01)


func _update_visual() -> void:
	if _sprite == null:
		return
	var anim: StringName = &"update_bar_progress"
	var t: float = _time
	match _state:
		State.STUCK:
			anim = &"update_bar_stuck"
		State.FULL:
			anim = &"update_bar_full"
		State.OPENING:
			anim = &"update_bar_open"
			t = _state_time
	_sprite.visible = _state != State.OPEN
	_sprite.animation = anim
	var count: int = _frames.get_frame_count(anim)
	var f: int = floori(t * _frames.get_animation_speed(anim))
	_sprite.frame = f % count if _frames.get_animation_loop(anim) else mini(f, count - 1)
	_set_text(_current_text())
	_plate.visible = _state != State.OPEN


func _current_text() -> String:
	var texts: Dictionary = _config.get("texts", {})
	match _state:
		State.IDLE, State.RISING:
			return String(texts.get("installing", "Instalando… %d %%")) % roundi(get_percent())
		State.STUCK:
			var out: String = ""
			var progress: float = _state_time / maxf(wait_s, 0.01)
			for entry: Variant in texts.get("stuck", []):
				if entry is Array and progress >= float(entry[0]):
					out = String(entry[1])
			return out
	return String(texts.get("done", "Reiniciando…"))


func _set_text(value: String) -> void:
	if _label.text == value:
		return
	_label.text = value
	var size: Vector2 = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_config.get("font_size", 12)))
	var pad: float = float(_config.get("plate_padding_px", 3))
	_label.position = Vector2(-size.x * 0.5, -size.y * 0.5)
	_label.size = size
	_plate.set_meta(&"rect", Rect2(-size.x * 0.5 - pad, -size.y * 0.5 - pad, size.x + pad * 2.0, size.y + pad * 2.0))
	_plate.queue_redraw()


func _build_plate() -> void:
	_font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_plate = Node2D.new()
	_plate.name = "Plate"
	var at: Array = _config.get("plate_center_px", [32, -24])
	_plate.position = Vector2(float(at[0]), float(at[1]))
	_plate.scale = Vector2.ONE * float(_config.get("font_scale", 2))
	_plate.z_index = int(_config.get("effects_z_index", 5))
	_plate.draw.connect(_draw_plate)
	add_child(_plate)
	_label = Label.new()
	_label.add_theme_font_override(&"font", _font)
	_label.add_theme_font_size_override(&"font_size", int(_config.get("font_size", 12)))
	_label.add_theme_color_override(&"font_color", Color.html(String(_config.get("text_color", "#f2f4f8"))))
	_label.add_theme_constant_override(&"line_spacing", 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_label)


func _draw_plate() -> void:
	var rect: Rect2 = _plate.get_meta(&"rect", Rect2())
	if rect.size == Vector2.ZERO:
		return
	_plate.draw_rect(rect, Color.html(String(_config.get("plate_color", "#0b0e1a"))))
	_plate.draw_rect(rect, Color.html(String(_config.get("plate_border_color", "#9bb0e8"))), false, 1.0)


func _isak_in_zone() -> bool:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	if _isak == null or _isak.is_dead():
		return false
	return get_arm_rect().has_point(_isak.global_position - Vector2(0.0, 1.0))


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()
