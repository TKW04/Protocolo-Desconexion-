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
## TOPE (tanda M2, 2026-10-17; docs/propuesta-mejoras.md §5.1): con el tope de
## power banks lleno (GameState.can_take_power_bank, max_total 3 de
## data/power_bank.json) NO se recoge: Isak lo atraviesa, sale «Sin espacio»
## encima (seccion no_room) y el objeto se queda en el mapa sin apuntarse, asi que
## se puede volver a por el con hueco (p. ej. tras pagar un nivel 5 en Calc).
class_name PowerBankPickup
extends Area2D

signal collected
## Isak lo toco con el tope lleno: se queda y sale «Sin espacio».
signal no_room

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
## Aviso «Sin espacio»: segundos que le quedan a la vista (0 = oculto).
var _no_room_left: float = 0.0
var _no_room_cfg: Dictionary = {}
var _no_room_font: Font
var _isak_inside: bool = false
## Nodo del aviso (por encima del sprite del objeto; como todo el mundo, por
## debajo de Isak: el aviso va sobre su cabeza).
var _no_room_layer: Node2D


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
	body_exited.connect(_on_body_exited)
	_sprite = EnergySprite.attach(self, _state(), _center())
	_no_room_cfg = GameState.get_power_bank_no_room_data()
	if not _no_room_cfg.is_empty():
		_no_room_font = load(String(_no_room_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_no_room_layer = Node2D.new()
	_no_room_layer.name = "NoRoom"
	_no_room_layer.draw.connect(_draw_no_room)
	add_child(_no_room_layer)


func _process(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _sprite != null:
		_sprite.show_state(_state())
		_sprite.advance(dt)
		_sprite.position = (_center() + Vector2(0.0, roundf(sin(_time * TAU * _bob_hz) * _bob_px))).round()
	if _no_room_left > 0.0:
		# Mientras Isak siga encima el aviso no se apaga; al salir dura show_s.
		if not _isak_inside:
			_no_room_left = maxf(_no_room_left - delta, 0.0)
		_no_room_layer.queue_redraw()
	elif _isak_inside and not _taken:
		_try_take()


func _state() -> StringName:
	return state_for_charge(display_charge, GameState.get_power_bank_capacity())


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; recogido, no.
func is_help_available() -> bool:
	return not _taken


func is_taken() -> bool:
	return _taken


## Verdadero mientras se ve el aviso «Sin espacio» (tope lleno).
func is_no_room_shown() -> bool:
	return _no_room_left > 0.0


## Texto del aviso (no_room.text de data/power_bank.json).
func get_no_room_text() -> String:
	return String(_no_room_cfg.get("text", "Sin espacio"))


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
	_isak_inside = true
	_try_take()


func _on_body_exited(body: Node2D) -> void:
	if body is Isak:
		_isak_inside = false


## Recoge el power bank si cabe; con el tope lleno se queda y avisa.
func _try_take() -> void:
	if _taken:
		return
	if not GameState.can_take_power_bank():
		if _no_room_left <= 0.0:
			no_room.emit()
			EventBus.power_bank_no_room.emit(self)
		_no_room_left = float(_no_room_cfg.get("show_s", 1.5))
		_no_room_layer.queue_redraw()
		return
	_taken = true
	_no_room_left = 0.0
	if GameState.collect_power_bank_pickup(get_level_id(), get_pickup_id()):
		collected.emit()
	queue_free()


## Aviso «Sin espacio» (texto en un panel oscuro con borde cian; sin rojos),
## sobre la cabeza de Isak.
func _draw_no_room() -> void:
	if _no_room_left <= 0.0 or _no_room_font == null:
		return
	var canvas: Node2D = _no_room_layer
	var text: String = get_no_room_text()
	var scale_px: float = float(_no_room_cfg.get("scale", 2))
	var pad: float = float(_no_room_cfg.get("padding_px", 3))
	var size_px: int = _no_room_font.get_fixed_size() if _no_room_font is FontFile else 12
	if size_px <= 0:
		size_px = 12
	var text_size: Vector2 = _no_room_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var box := Vector2(text_size.x + pad * 2.0, _no_room_font.get_height(size_px) + pad * 2.0)
	var center: Vector2 = _center() + Vector2(0.0, float(_no_room_cfg.get("offset_y_px", -44.0)))
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * scale_px)
	var rect := Rect2((-box * 0.5).round(), box)
	var fill := Color(String(_no_room_cfg.get("fill_color", "#0b0e1a")))
	fill.a = float(_no_room_cfg.get("fill_alpha", 0.85))
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, Color(String(_no_room_cfg.get("border_color", "#3dfff5"))), false, 1.0)
	var baseline := Vector2(rect.position.x + pad, rect.position.y + pad + _no_room_font.get_ascent(size_px))
	canvas.draw_string(_no_room_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
			Color(String(_no_room_cfg.get("text_color", "#f2f4f8"))))
	canvas.draw_set_transform(Vector2.ZERO)
