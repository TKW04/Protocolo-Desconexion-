## Cargador de energia (tipo `charger` del catalogo del Mundo 1; decision del
## usuario 2026-10-15: en los mapas hay cargadores en ciertos puntos que reponen
## la energia de Debug, la misma que gasta el laser). Se activa AL TOCARLO
## (como el punto de sincronizacion y la puerta de salida: sin accion nueva).
## Repone `amount` (sin desbordar a los power banks: el desborde es solo de los
## drops). Si la barra ya esta llena no se gasta.
## - reusable true (PROPUESTA por defecto): tras usarse se enfria cooldown_s
##   (tiempo del mundo) y vuelve a estar listo. El enfriamiento no se guarda.
## - reusable false: un solo uso; queda gastado y se guarda por nivel en
##   user://save.json (collected_pickups, como los power banks de mapa).
## Aspecto PROVISIONAL dibujado por codigo (seccion charger de
## data/world1_objects.json, paleta del Mundo 1): poste con pantalla; lista en
## el color del Debug, enfriandose con una barra que se llena, gastado apagado.
class_name Charger
extends Area2D

## Ha repuesto `amount` de energia.
signal used(amount: float)

const CONFIG_PATH: String = "res://data/world1_objects.json"

## Id persistente; vacio = el nombre del nodo.
@export var object_id: StringName = &""
## Energia que repone cada uso.
@export var amount: float = 50.0
## Reutilizable con enfriamiento (true) o de un solo uso (false).
@export var reusable: bool = true
## Enfriamiento entre usos (s de tiempo del mundo) si es reutilizable.
@export var cooldown_s: float = 20.0

var _spent: bool = false
var _cooldown_left: float = 0.0
var _size := Vector2(32.0, 64.0)
var _outline := Color("#0b0e1a")
var _body := Color("#343f66")
var _screen_off := Color("#1a2138")
var _ready_color := Color("#3dfff5")
var _cooling_color := Color("#9bb0e8")


func _ready() -> void:
	_load_config()
	if not reusable and GameState.is_pickup_collected(get_level_id(), get_charger_id()):
		_spent = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	shape.position = _center()
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))
	# Isak quieto encima cuando termina el enfriamiento o gasta energia.
	if is_ready():
		for body: Node2D in get_overlapping_bodies():
			if try_use(body) > 0.0:
				break


## Avanza el enfriamiento `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - dt, 0.0)
		queue_redraw()


func is_ready() -> bool:
	return not _spent and _cooldown_left <= 0.0


func is_spent() -> bool:
	return _spent


func get_cooldown_left() -> float:
	return _cooldown_left


func get_charger_id() -> StringName:
	return object_id if object_id != &"" else StringName(name)


## Id del nivel generado que lo contiene (&"" si no hay).
func get_level_id() -> StringName:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return StringName((node as GeneratedLevel).level_id)
		node = node.get_parent()
	return GameState.NO_LEVEL


## Lo usa `body` si es Isak y esta listo. Devuelve la energia repuesta (0 si no
## se usa: no es Isak, gastado, enfriandose o la barra ya estaba llena).
func try_use(body: Node) -> float:
	if not body is Isak or not is_ready():
		return 0.0
	var gained: float = GameState.recharge_debug_energy(amount)
	if gained <= 0.0:
		return 0.0
	if reusable:
		_cooldown_left = cooldown_s
	else:
		_spent = true
		GameState.mark_pickup_collected(get_level_id(), get_charger_id())
	queue_redraw()
	used.emit(gained)
	EventBus.charger_used.emit(get_charger_id(), gained)
	return gained


func _draw() -> void:
	var top_left := Vector2(_center() - _size * 0.5).round()
	var body := Rect2(top_left, _size)
	draw_rect(body, _outline)
	draw_rect(body.grow(-2.0), _body)
	var screen := Rect2(top_left + Vector2(6.0, 8.0), Vector2(_size.x - 12.0, _size.y * 0.5))
	draw_rect(screen, _outline)
	var inner := screen.grow(-2.0)
	if _spent:
		draw_rect(inner, _screen_off)
	elif _cooldown_left > 0.0:
		draw_rect(inner, _screen_off)
		var progress: float = 1.0 - _cooldown_left / maxf(cooldown_s, 0.001)
		var h: float = roundf(inner.size.y * progress * 0.5) * 2.0
		draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - h), Vector2(inner.size.x, h)), _cooling_color)
	else:
		draw_rect(inner, _ready_color)
		# Rayo (dos escalones de noche_profunda).
		var c: Vector2 = inner.get_center().round()
		draw_rect(Rect2(c + Vector2(-2.0, -8.0), Vector2(4.0, 8.0)), _outline)
		draw_rect(Rect2(c + Vector2(0.0, 0.0), Vector2(4.0, 8.0)), _outline)


## Centro del dibujo y de la zona de contacto: centrado en x en la celda (x, y)
## y apoyado en su borde inferior (con size_px 32x64 ocupa justo esa celda).
func _center() -> Vector2:
	return Vector2(32.0, 64.0 - _size.y * 0.5)


func _load_config() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or not (parsed as Dictionary).get("charger") is Dictionary:
		return
	var cfg: Dictionary = parsed["charger"]
	var size: Variant = cfg.get("size_px", [])
	if size is Array and (size as Array).size() == 2:
		_size = Vector2(float(size[0]), float(size[1]))
	_outline = Color(String(cfg.get("outline", _outline.to_html(false))))
	_body = Color(String(cfg.get("body", _body.to_html(false))))
	_screen_off = Color(String(cfg.get("screen_off", _screen_off.to_html(false))))
	_ready_color = Color(String(cfg.get("ready", _ready_color.to_html(false))))
	_cooling_color = Color(String(cfg.get("cooling", _cooling_color.to_html(false))))


func _on_body_entered(body: Node2D) -> void:
	try_use(body)
