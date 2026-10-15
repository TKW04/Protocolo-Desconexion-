## Power bank de mapa (objeto `power_bank_pickup` del catalogo del Mundo 1;
## desde el 1-2; el 1-1 no tiene ninguno desde el 2026-10-15). Al tocarlo Isak suma un power bank
## VACIO (carga 0, decision 2026-10-14: se carga con el sobrante de energia de
## los drops) con GameState.collect_power_bank_pickup(). Como los puntos de
## atencion, no se vuelve a recoger en el mismo mapa: el id (object_id o, si esta
## vacio, el nombre del nodo) se guarda por nivel y, si ya estaba recogido, no
## aparece. Aspecto PROVISIONAL (sin sprite): una pila dibujada con contorno
## noche_profunda y una franja en el color del Debug del mundo, como el icono del
## HUD, que flota (valores en la seccion power_bank_pickup de data/world1_objects.json).
class_name PowerBankPickup
extends Area2D

signal collected

const CONFIG_PATH: String = "res://data/world1_objects.json"

## Id persistente; vacio = el nombre del nodo.
@export var object_id: StringName = &""

var _taken: bool = false
var _time: float = 0.0
var _size := Vector2(24.0, 36.0)
var _bob_px: float = 4.0
var _bob_hz: float = 1.5
var _outline := Color("#0b0e1a")
var _body := Color("#f2f4f8")
var _fill := Color("#3dfff5")


func _ready() -> void:
	_load_config()
	if GameState.is_pickup_collected(get_level_id(), get_pickup_id()):
		_taken = true
		queue_free()
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	shape.position = _center()
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += WorldTime.scaled_delta(delta)
	queue_redraw()


func _draw() -> void:
	var offset: float = roundf(sin(_time * TAU * _bob_hz) * _bob_px)
	var top_left: Vector2 = (_center() - _size * 0.5 + Vector2(0.0, offset)).round()
	var body := Rect2(top_left + Vector2(0.0, 4.0), _size - Vector2(0.0, 4.0))
	draw_rect(Rect2(top_left + Vector2(_size.x * 0.5 - 4.0, 0.0), Vector2(8.0, 4.0)), _outline)
	draw_rect(body, _outline)
	draw_rect(body.grow(-2.0), _body)
	var inner := body.grow(-6.0)
	draw_rect(inner, _fill)


func is_taken() -> bool:
	return _taken


func get_pickup_id() -> StringName:
	return object_id if object_id != &"" else StringName(name)


## Id del nivel generado que lo contiene (&"" si no hay).
func get_level_id() -> StringName:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return StringName((node as GeneratedLevel).level_id)
		node = node.get_parent()
	return GameState.NO_LEVEL


## Centro del dibujo y de la zona de recogida: centro de la celda (x, y).
func _center() -> Vector2:
	return Vector2(32.0, 32.0)


func _load_config() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or not (parsed as Dictionary).get("power_bank_pickup") is Dictionary:
		return
	var cfg: Dictionary = parsed["power_bank_pickup"]
	var size: Variant = cfg.get("size_px", [])
	if size is Array and (size as Array).size() == 2:
		_size = Vector2(float(size[0]), float(size[1]))
	_bob_px = float(cfg.get("bob_px", _bob_px))
	_bob_hz = float(cfg.get("bob_hz", _bob_hz))
	_outline = Color(String(cfg.get("outline", _outline.to_html(false))))
	_body = Color(String(cfg.get("body", _body.to_html(false))))
	_fill = Color(String(cfg.get("fill", _fill.to_html(false))))


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Isak:
		return
	_taken = true
	if GameState.collect_power_bank_pickup(get_level_id(), get_pickup_id()):
		collected.emit()
	queue_free()
