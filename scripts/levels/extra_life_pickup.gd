## Vida extra (objeto `extra_life_pickup` del catalogo del Mundo 1; paso 14 de
## §10 de docs/propuesta-asistentes-y-vidas.md, 2026-10-16). Al tocarla Isak,
## GameState.collect_extra_life(nivel, secret_id) sube lives_max para siempre
## (+1 tambien en el intento en curso) y apunta el secreto en found_secrets
## (registro por mapa e id: «1-1» / «D»). Una sola vez por mapa: si el secreto ya
## esta encontrado (guardado cargado, o recogida en este intento) no aparece.
## Si una pared con glitch (GlitchWall) cubre su celda, esta OCULTA (invisible,
## sin colision ni Q) hasta que la pared se abre con el Debug (senal opened);
## entonces aparece con un bote. Flota con bob_px / bob_hz (tiempo del mundo) y
## al recogerla reproduce extra_life_collect subiendo collect_rise_px y se
## libera. Arte: tools/gen_extra_life.py (assets/sprites/extra_life_frames.tres).
class_name ExtraLifePickup
extends Area2D

signal collected
## Aparece al abrirse la pared que la tapaba (o al empezar, si no hay pared).
signal revealed

const GROUP: StringName = &"extra_life_pickup"
const FRAMES_PATH: String = "res://assets/sprites/extra_life_frames.tres"
const IDLE_ANIM: StringName = &"extra_life_idle"
const COLLECT_ANIM: StringName = &"extra_life_collect"

## Id del objeto en el nivel (no se guarda: lo que se guarda es secret_id).
@export var object_id: StringName = &""
## Id estable del secreto en el registro (found_secrets[nivel][secret_id]).
@export var secret_id: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("extra_life_pickup")
var _sprite: AnimatedSprite2D
var _shape: CollisionShape2D
var _wall: GlitchWall
var _shown: bool = false
var _taken: bool = false
var _time: float = 0.0
## Segundos desde que se recogio (tiempo del mundo); -1 = no recogida.
var _collect_time: float = -1.0
var _appear_time: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	if GameState.is_secret_found(get_level_id(), secret_id):
		_taken = true
		queue_free()
		return
	var size_px: Array = _config.get("size_px", [24, 28])
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(size_px[0]), float(size_px[1]))
	_shape.shape = rect
	_shape.position = _center()
	add_child(_shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = load(FRAMES_PATH) as SpriteFrames
	_sprite.animation = IDLE_ANIM
	_sprite.position = _center()
	_sprite.scale = Vector2.ONE * _draw_scale()
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	# Oculta hasta saber si una pared la tapa (la pared puede entrar despues).
	_set_shown(false)
	_link_wall.call_deferred()


func _process(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	if _sprite == null:
		return
	if _collect_time >= 0.0:
		_advance_collect(dt)
		return
	if not _shown:
		return
	_time += dt
	var fps: float = _sprite.sprite_frames.get_animation_speed(IDLE_ANIM)
	_sprite.frame = floori(_time * fps) % _sprite.sprite_frames.get_frame_count(IDLE_ANIM)
	var bob: float = roundf(sin(_time * TAU * float(_config.get("bob_hz", 1.2))) * float(_config.get("bob_px", 3.0)))
	_sprite.position = (_center() + Vector2(0.0, bob)).round()
	if _appear_time >= 0.0:
		_appear_time += dt
		var length: float = maxf(float(_config.get("appear_s", 0.3)), 0.001)
		var k: float = clampf(_appear_time / length, 0.0, 1.0)
		var pop: float = float(_config.get("appear_pop_scale", 1.5))
		_sprite.scale = Vector2.ONE * lerpf(pop, 1.0, k) * _draw_scale()
		if k >= 1.0:
			_appear_time = -1.0


## Se ve y se puede recoger (la pared que la tapaba ya se abrio).
func is_shown() -> bool:
	return _shown


func is_taken() -> bool:
	return _taken


## Pared con glitch que la tapa (null si no hay).
func get_wall() -> GlitchWall:
	return _wall


## Id del nivel generado que la contiene (GameState.NO_LEVEL si no hay).
func get_level_id() -> StringName:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return StringName((node as GeneratedLevel).level_id)
		node = node.get_parent()
	return GameState.NO_LEVEL


## Recoge la vida extra (una sola vez). Falso si ya estaba recogida u oculta.
func collect() -> bool:
	if _taken or not _shown:
		return false
	_taken = true
	remove_from_group(HelpCatalog.TARGET_GROUP)
	_shape.set_deferred(&"disabled", true)
	set_deferred(&"monitoring", false)
	GameState.collect_extra_life(get_level_id(), secret_id)
	_collect_time = 0.0
	_sprite.scale = Vector2.ONE * _draw_scale()
	_sprite.animation = COLLECT_ANIM
	_sprite.frame = 0
	collected.emit()
	return true


## Escala entera del dibujo (arte de 32x32 a x2, como Eco companero).
func _draw_scale() -> float:
	return float(_config.get("draw_scale", 2))


func _center() -> Vector2:
	return Vector2(32.0, 32.0)


func _advance_collect(dt: float) -> void:
	_collect_time += dt
	var frames: SpriteFrames = _sprite.sprite_frames
	var count: int = frames.get_frame_count(COLLECT_ANIM)
	var length: float = count / maxf(frames.get_animation_speed(COLLECT_ANIM), 0.001)
	var k: float = clampf(_collect_time / length, 0.0, 1.0)
	_sprite.frame = mini(floori(k * count), count - 1)
	_sprite.position = (_center() - Vector2(0.0, float(_config.get("collect_rise_px", 32.0)) * k)).round()
	if _collect_time >= length:
		queue_free()


## Busca una pared con glitch que cubra su celda; sin pared (o ya abierta),
## aparece.
func _link_wall() -> void:
	if _taken or not is_inside_tree():
		return
	var point: Vector2 = global_position + _center()
	for node: Node in get_tree().get_nodes_in_group(GlitchWall.GROUP):
		var wall := node as GlitchWall
		if wall != null and wall.get_world_rect().has_point(point):
			_wall = wall
			break
	if _wall == null or _wall.is_open():
		_reveal(false)
	else:
		_wall.opened.connect(_reveal.bind(true))


func _reveal(animated: bool) -> void:
	if _taken or _shown:
		return
	_set_shown(true)
	if animated:
		_appear_time = 0.0
		_sprite.scale = Vector2.ONE * float(_config.get("appear_pop_scale", 1.5)) * _draw_scale()
	revealed.emit()


func _set_shown(shown: bool) -> void:
	_shown = shown
	visible = shown
	_shape.set_deferred(&"disabled", not shown)
	set_deferred(&"monitoring", shown)


func _on_body_entered(body: Node2D) -> void:
	if body is Isak:
		collect()
