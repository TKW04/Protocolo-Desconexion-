## Power bank de mapa (objeto `power_bank_pickup` del catalogo del Mundo 1).
## COLECCIONABLE PURO (decision del usuario 2026-10-25, docs/propuesta-mejoras.md
## §5.1; sustituye al power bank vacio que se cargaba con el sobrante y al tope
## de 3 con «Sin espacio»): se encuentra YA COMPLETO y al tocarlo Isak suma un
## power bank con GameState.collect_power_bank_pickup() (sin tope ni carga;
## solo se gasta al comprar un nivel 5 en Calc). Como los puntos de atencion,
## no se vuelve a recoger en el mismo mapa: el id (object_id o, si esta vacio,
## el nombre del nodo) se guarda por nivel y, si ya estaba recogido, no
## aparece; un rollback lo devuelve con lo no guardado. Aspecto: sprite
## power_bank_full (EnergySprite, docs/estilizacion-energia.md). Flota con
## bob_px / bob_hz de la seccion power_bank_pickup de data/world1_objects.json.
class_name PowerBankPickup
extends Area2D

signal collected

const CONFIG_PATH: String = "res://data/world1_objects.json"
## Estado del sprite: siempre completo (ya no hay power banks vacios).
const SPRITE_STATE: StringName = &"power_bank_full"

## Id persistente; vacio = el nombre del nodo.
@export var object_id: StringName = &""

var _taken: bool = false
var _time: float = 0.0
var _size := Vector2(24.0, 36.0)
var _bob_px: float = 4.0
var _bob_hz: float = 1.5
var _sprite: EnergySprite


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
	_sprite = EnergySprite.attach(self, SPRITE_STATE, _center())


func _process(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _sprite != null:
		_sprite.advance(dt)
		_sprite.position = (_center() + Vector2(0.0, roundf(sin(_time * TAU * _bob_hz) * _bob_px))).round()


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


## Estado que muestra el sprite (siempre power_bank_full).
func get_sprite_state() -> StringName:
	return SPRITE_STATE


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
