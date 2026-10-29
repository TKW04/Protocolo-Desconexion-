## Caja sorpresa (tipo `surprise_box` del catalogo del Mundo 5; 2026-10-29, paso 4 de
## docs/propuesta-mundo-5.md §8, §3.4 y §3.7). Caja SOLIDA de 1 x 1 tile en el suelo o
## en una repisa (se puede pisar). Contenido FIJO en los datos (`content`: points
## (amount 1-2), energy (+30), subscription, offer o empty): nunca aleatorio.
## - Abrir: golpe al suelo ENCIMA (los pies de Isak sobre la tapa), Embestida que la
##   alcanza o PULSO DE CARA desde el suelo (Isak mirandola, no de espaldas). Sale el
##   contenido con un «pop» de pop_frames cuadros.
## - Ver dentro: con el Debug (DebugMode.is_revealing) se vuelve translucida y ensena
##   el icono del contenido con contorno negro de 1 px.
## - Laser (vida 1): la destruye sin abrirla; el contenido se pierde (tambien lo malo).
## - Lanzada (launch(), la usara El Vendedor): vuela con gravedad sin ser solida; el
##   pulso la deja ATURDIDA stun_s: inerte en el aire, solida, sirve de ESCALON; despues
##   sigue cayendo y en el suelo queda como una caja normal. El Filo derrota a la
##   aturdida (vida <= 1); el Sismo no le hace nada.
## Los puntos se capturan como un punto de atencion (`box:<id>` del nivel, una vez por
## partida guardada): ya capturados, la caja esta vacia (y el Debug lo dice).
## El origen es la esquina superior izquierda de su celda. Tiempo del mundo. Aspecto
## PROVISIONAL por codigo (seccion surprise_box de data/world5_objects.json).
class_name SurpriseBox
extends CharacterBody2D

const GROUP: StringName = &"surprise_box"
const ENEMY_GROUP: StringName = &"enemy"
const CONTENT_POINTS: StringName = &"points"
const CONTENT_ENERGY: StringName = &"energy"
const CONTENT_SUBSCRIPTION: StringName = &"subscription"
const CONTENT_OFFER: StringName = &"offer"
const CONTENT_EMPTY: StringName = &"empty"
const CONTENTS: Array[StringName] = [CONTENT_POINTS, CONTENT_ENERGY, CONTENT_SUBSCRIPTION, CONTENT_OFFER, CONTENT_EMPTY]
const STATE_CLOSED: StringName = &"closed"
const STATE_FLYING: StringName = &"flying"
const STATE_STUNNED: StringName = &"stunned"
const STATE_OPENED: StringName = &"opened"
const STATE_DESTROYED: StringName = &"destroyed"
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4
const OFFER_SCENE_PATH: String = "res://scenes/enemies/offer_sign.tscn"

## Se abre y suelta `content` (lo efectivo: points ya capturados = empty).
signal opened(content: StringName)
## El laser (o un Filo, aturdida) la destruye sin abrirla.
signal destroyed
signal stunned
signal state_changed(previous: StringName, current: StringName)

@export var object_id: StringName = &""
@export var content: StringName = CONTENT_EMPTY:
	set(value):
		var c := StringName(value)
		if not CONTENTS.has(c):
			push_warning("SurpriseBox: contenido '%s' desconocido; vacia" % c)
			c = CONTENT_EMPTY
		content = c
		queue_redraw()
## Puntos que da (content points; 1-2).
@export var amount: int = 1

var _cfg: Dictionary = {}
var _state: StringName = STATE_CLOSED
var _timer: float = 0.0
var _pop_left: float = 0.0
var _time: float = 0.0
var _released: Node
var _shape: CollisionShape2D


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("surprise_box")
	add_to_group(GROUP)
	add_to_group(ENEMY_GROUP)
	collision_mask = LAYER_WORLD
	var r: Rect2 = _local_rect()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = r.size
	_shape.shape = rect
	_shape.position = r.get_center()
	add_child(_shape)
	_set_solid(true)
	EventBus.pulse_fired.connect(receive_pulse)
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _pop_left > 0.0:
		_pop_left = maxf(_pop_left - dt, 0.0)
	match _state:
		STATE_FLYING:
			velocity.y = minf(velocity.y + float(_cfg.get("gravity_px_s2", 2400.0)) * dt,
				float(_cfg.get("max_fall_px_s", 960.0)))
			if is_inside_tree():
				move_and_slide()
				if is_on_floor():
					velocity = Vector2.ZERO
					_change_state(STATE_CLOSED)
					_set_solid(true)
		STATE_STUNNED:
			_timer -= dt
			if _timer <= 0.0:
				_timer = 0.0
				velocity = Vector2.ZERO
				_change_state(STATE_FLYING)
				_set_solid(false)
	queue_redraw()


# --- Consultas ---

func get_state() -> StringName:
	return _state


func is_closed() -> bool:
	return _state == STATE_CLOSED or _state == STATE_FLYING or _state == STATE_STUNNED


func is_opened() -> bool:
	return _state == STATE_OPENED


func is_destroyed() -> bool:
	return _state == STATE_DESTROYED


func is_stunned() -> bool:
	return _state == STATE_STUNNED


func is_flying() -> bool:
	return _state == STATE_FLYING


## Solida (se pisa): en reposo o aturdida.
func is_solid() -> bool:
	return _state == STATE_CLOSED or _state == STATE_STUNNED


## Nunca dana por tocarla.
func is_dangerous() -> bool:
	return false


## El Debug ensena lo que hay dentro.
func is_revealed() -> bool:
	return is_closed() and DebugMode.is_revealing()


## Contenido efectivo: los puntos ya capturados en esta partida son una caja vacia.
func get_effective_content() -> StringName:
	if content == CONTENT_POINTS and GameState.is_attention_point_captured(GameState.current_level, _point_id()):
		return CONTENT_EMPTY
	return content


## Lo que salio al abrirla (Subscription u OfferSign), o null.
func get_released() -> Node:
	return _released if _released != null and is_instance_valid(_released) else null


func get_health() -> float:
	return 1.0 if is_closed() else 0.0


func get_stun_left() -> float:
	return _timer if _state == STATE_STUNNED else 0.0


func get_body_rect() -> Rect2:
	var r: Rect2 = _local_rect()
	return Rect2(global_position + r.position, r.size)


func get_pop_s() -> float:
	return float(_cfg.get("pop_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)


## Ayuda de Eco: cerrada.
func is_help_available() -> bool:
	return is_closed()


# --- Acciones ---

## Abre la caja y suelta su contenido. Verdadero si se ha abierto ahora.
func open() -> bool:
	if not is_closed():
		return false
	var what: StringName = get_effective_content()
	_finish(STATE_OPENED)
	match what:
		CONTENT_POINTS:
			GameState.capture_attention_point(GameState.current_level, _point_id(), maxi(amount, 1))
		CONTENT_ENERGY:
			GameState.add_debug_energy(float(_cfg.get("energy", 30.0)))
		CONTENT_SUBSCRIPTION:
			_released = Subscription.spawn(get_parent(), _feet())
		CONTENT_OFFER:
			var offer := (load(OFFER_SCENE_PATH) as PackedScene).instantiate() as OfferSign
			get_parent().add_child(offer)
			offer.global_position = _feet()
			_released = offer
	opened.emit(what)
	return true


## La destruye sin abrirla (laser; Filo aturdida): el contenido se pierde.
func destroy() -> bool:
	if not is_closed():
		return false
	_finish(STATE_DESTROYED)
	destroyed.emit()
	return true


## Lanzada (El Vendedor): vuela con `initial_velocity` y gravedad, sin ser solida.
func launch(initial_velocity: Vector2) -> void:
	if not is_closed():
		return
	velocity = initial_velocity
	_change_state(STATE_FLYING)
	_set_solid(false)


## Aturde la caja lanzada: inerte stun_s y solida (escalon). En reposo no hace nada.
func stun(duration_scale: float = 1.0) -> void:
	if _state != STATE_FLYING and _state != STATE_STUNNED:
		return
	var t: float = float(_cfg.get("stun_s", 3.0)) * maxf(duration_scale, 0.0)
	if t <= 0.0:
		return
	_timer = t
	velocity = Vector2.ZERO
	_change_state(STATE_STUNNED)
	_set_solid(true)
	stunned.emit()


## Pulso (EventBus.pulse_fired): a la lanzada la aturde; a la de reposo la abre si
## Isak esta en el suelo y de cara a ella (sin Isak, pruebas, basta con alcanzarla).
func receive_pulse(area: Area2D) -> bool:
	if not is_closed() or not PulseReceiver.pulse_reaches(area, get_body_rect()):
		return false
	if _state != STATE_CLOSED:
		stun(GameState.get_pulse_stun_multiplier())
		return true
	var isak := area.get_parent() as Isak if area != null else null
	if isak != null and is_instance_valid(isak):
		if not isak.is_on_floor() or isak.is_facing_back():
			return false
		var dx: float = get_body_rect().get_center().x - isak.global_position.x
		if absf(dx) > float(_cfg.get("face_dead_zone_px", 8.0)) and signf(dx) != signf(isak.facing):
			return false
	return open()


func on_laser_hit(_damage: float, _source: Node) -> void:
	destroy()


## La onda del golpe al suelo de GroundPoundWave no la abre (solo encima: EventBus).
func receive_ground_pound(_rect: Rect2, _damage: float) -> bool:
	return false


## Agitar (retirado): nada.
func receive_shockwave(_center: Vector2, _radius: float, _stun_s: float) -> bool:
	return false


## Combinacion: la Embestida la abre; el Filo destruye a la aturdida; el Sismo, nada.
func receive_combo(kind: StringName, rect: Rect2, damage: float, _wave_stun_s: float) -> bool:
	if not is_closed() or not rect.intersects(get_body_rect()):
		return false
	if kind == Isak.COMBO_RAM:
		return open()
	if kind == Isak.COMBO_EDGE and _state == STATE_STUNNED and damage >= get_health() - 0.0001:
		return destroy()
	return false


## Reaparicion de Isak: sin cambios (abierta sigue abierta en el intento).
func reset_patrol() -> void:
	pass


# --- Interno ---

func _point_id() -> StringName:
	var key: String = String(object_id) if object_id != &"" else "%d_%d" % [roundi(position.x), roundi(position.y)]
	return StringName("box:" + key)


func _feet() -> Vector2:
	var r: Rect2 = get_body_rect()
	return Vector2(r.get_center().x, r.end.y)


func _local_rect() -> Rect2:
	var r: Array = _cfg.get("box_rect", [4, 8, 56, 56])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _finish(next: StringName) -> void:
	_timer = 0.0
	velocity = Vector2.ZERO
	_pop_left = get_pop_s()
	_change_state(next)
	collision_layer = 0
	if _shape != null:
		_shape.set_deferred("disabled", true)


func _set_solid(on: bool) -> void:
	collision_layer = LAYER_WORLD if on else LAYER_ENEMY


func _change_state(next: StringName) -> void:
	if next == _state:
		return
	var previous: StringName = _state
	_state = next
	state_changed.emit(previous, next)


func _on_ground_pound_landed(_rect: Rect2, source: Node2D) -> void:
	if _state != STATE_CLOSED and _state != STATE_STUNNED:
		return
	var isak := source as Isak
	if isak == null:
		return
	var r: Rect2 = get_body_rect()
	var feet: Vector2 = isak.global_position
	var tol: float = float(_cfg.get("pound_top_tolerance_px", 8.0))
	var half: float = isak.get_hitbox_size().x * 0.5
	if absf(feet.y - r.position.y) <= tol and feet.x + half > r.position.x and feet.x - half < r.end.x:
		open()


# --- Dibujo ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var r: Rect2 = _local_rect()
	if not is_closed():
		if _pop_left > 0.0:
			# «Pop»: anillo que crece y se apaga.
			var k: float = 1.0 - _pop_left / maxf(get_pop_s(), 0.001)
			var col: Color = _c("gris", "gris_etiqueta") if _state == STATE_DESTROYED else _c("pop", "amarillo_rebajas")
			draw_arc(r.get_center(), 10.0 + 30.0 * k, 0.0, TAU, 20, Color(col, 1.0 - k), 3.0)
		return
	var revealed: bool = is_revealed()
	var alpha: float = float(_cfg.get("reveal_alpha", 0.45)) if revealed else 1.0
	var body: Color = _c("box", "crema_sombra")
	var band: Color = _c("ribbon", "magenta_neon")
	var ink: Color = _c("ink", "negro_medio")
	draw_rect(r, Color(ink, alpha))
	draw_rect(r.grow(-2.0), Color(body, alpha))
	draw_rect(Rect2(Vector2(r.get_center().x - 4.0, r.position.y + 2.0), Vector2(8.0, r.size.y - 4.0)), Color(band, alpha))
	draw_rect(Rect2(r.position + Vector2(2.0, 12.0), Vector2(r.size.x - 4.0, 4.0)), Color(ink, alpha * 0.6))
	if _state == STATE_STUNNED:
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y - 4.0), "x x", HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, 12, ink)
	if revealed:
		_draw_icon(r.get_center() + Vector2(0.0, 6.0), get_effective_content())
	else:
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y - 12.0), "?", HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, 22, ink)


## Icono del contenido con contorno negro de 1 px (se lee sobre el blanco del Debug).
func _draw_icon(c: Vector2, what: StringName) -> void:
	var ink: Color = _c("ink", "negro_medio")
	match what:
		CONTENT_POINTS:
			var y: Color = _c("points", "amarillo_rebajas")
			var pts := PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 0), c + Vector2(0, 11), c + Vector2(-11, 0)])
			var inner := PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0)])
			draw_colored_polygon(pts, ink)
			draw_colored_polygon(inner, y)
			if amount > 1:
				draw_string(ThemeDB.fallback_font, c + Vector2(8.0, 14.0), "x%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
		CONTENT_ENERGY:
			var bolt := PackedVector2Array([c + Vector2(2, -12), c + Vector2(-7, 2), c + Vector2(-1, 2),
				c + Vector2(-3, 12), c + Vector2(7, -3), c + Vector2(1, -3)])
			draw_colored_polygon(bolt, _c("energy_color", "debug_blanco"))
			draw_polyline(_closed(bolt), ink, 1.0)
		CONTENT_SUBSCRIPTION:
			var card := Rect2(c + Vector2(-10.0, -7.0), Vector2(20.0, 14.0))
			draw_rect(card.grow(1.0), ink)
			draw_rect(card, _c("ribbon", "magenta_neon"))
			draw_arc(c + Vector2(0.0, 1.0), 4.0, 0.2, PI - 0.2, 6, ink, 1.5)
		CONTENT_OFFER:
			var tag := Rect2(c + Vector2(-9.0, -10.0), Vector2(18.0, 20.0))
			draw_rect(tag.grow(1.0), ink)
			draw_rect(tag, _c("box", "crema_cartel"))
			draw_line(c + Vector2(-6.0, -3.0), c + Vector2(6.0, -3.0), _c("ribbon", "magenta_neon"), 2.0)
		_:
			draw_arc(c, 9.0, 0.0, TAU, 16, ink, 3.0)
			draw_arc(c, 9.0, 0.0, TAU, 16, _c("gris", "gris_etiqueta"), 1.5)
			draw_line(c + Vector2(-6.0, 6.0), c + Vector2(6.0, -6.0), ink, 2.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
