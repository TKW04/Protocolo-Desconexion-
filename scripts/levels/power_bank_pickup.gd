## Power bank de mapa (objeto `power_bank_pickup` del catalogo del Mundo 1;
## desde el 1-2; el 1-1 no tiene ninguno desde el 2026-10-15). Al tocarlo Isak suma un power bank
## VACIO (carga 0, decision 2026-10-14: se carga con el sobrante de energia de
## los drops) con GameState.collect_power_bank_pickup(). Como los puntos de
## atencion, no se vuelve a recoger en el mismo mapa: el id (object_id o, si esta
## vacio, el nombre del nodo) se guarda por nivel y, si ya estaba recogido, no
## aparece. Aspecto: sprite power_bank_empty / partial / full (EnergySprite,
## docs/estilizacion-energia.md) segun display_charge; en el mapa siempre llega
## vacio. Flota con bob_px / bob_hz de la seccion power_bank_pickup de
## data/world1_objects.json.
class_name PowerBankPickup
extends Area2D

signal collected

const CONFIG_PATH: String = "res://data/world1_objects.json"

## Id persistente; vacio = el nombre del nodo.
@export var object_id: StringName = &""
## Carga que se MUESTRA (solo aspecto; el power bank que se recoge siempre llega
## vacio). Para el hub o la tienda: 0 vacio, menos de la capacidad parcial, llena.
@export var display_charge: float = 0.0

var _taken: bool = false
var _time: float = 0.0
var _size := Vector2(24.0, 36.0)
var _bob_px: float = 4.0
var _bob_hz: float = 1.5
var _sprite: EnergySprite


## Estado del sprite para una carga `charge` de `capacity`.
static func state_for_charge(charge: float, capacity: float) -> StringName:
	if charge <= 0.0:
		return &"power_bank_empty"
	if charge < capacity:
		return &"power_bank_partial"
	return &"power_bank_full"


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
	_sprite = EnergySprite.attach(self, _state(), _center())


func _process(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _sprite != null:
		_sprite.show_state(_state())
		_sprite.advance(dt)
		_sprite.position = (_center() + Vector2(0.0, roundf(sin(_time * TAU * _bob_hz) * _bob_px))).round()


func _state() -> StringName:
	return state_for_charge(display_charge, GameState.get_power_bank_capacity())


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; recogido, no.
func is_help_available() -> bool:
	return not _taken


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


## Centro del sprite y de la zona de recogida: centro de la celda (x, y).
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


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Isak:
		return
	_taken = true
	if GameState.collect_power_bank_pickup(get_level_id(), get_pickup_id()):
		collected.emit()
	queue_free()
