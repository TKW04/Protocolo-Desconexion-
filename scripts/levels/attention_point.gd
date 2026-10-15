## Punto de atencion recogible (tipo `o` del level-builder), version minima:
## al tocarlo Isak suma `value` puntos con GameState.capture_attention_point(),
## que tambien repone energia de Debug (A10: +10 por punto). Se puede recoger
## con el Debug activo.
## No se puede volver a capturar en el mismo mapa (decision 2026-10-14): el id
## (point_id o, si esta vacio, el nombre del nodo, p. ej. Point_8_9, estable
## porque lo genera build_level.py desde la celda) se guarda por nivel en
## GameState (persistente) y, si ya estaba capturado, el punto no aparece. Fuera
## de un nivel generado (escenas de prueba) no se apunta nada. Aspecto provisional (rombo del color del icono de
## puntos del HUD, data/hud.json); el arte llega con el tileset del Mundo 1.
class_name AttentionPoint
extends Area2D

signal collected(value: int)

## Puntos que suma (A10: cada punto vale 1).
@export var value: int = 1
## Radio de recogida y de dibujo en px (un cuarto de tile).
@export var radius_px: float = 16.0
## Id persistente del punto; vacio = el nombre del nodo.
@export var point_id: String = ""

var _taken: bool = false


func _ready() -> void:
	if GameState.is_attention_point_captured(get_level_id(), get_point_id()):
		_taken = true
		queue_free()
		return
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_px
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var r: float = radius_px
	var points := PackedVector2Array([Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0)])
	draw_colored_polygon(points, HudConfig.shared().color(&"attention_icon"))


func is_taken() -> bool:
	return _taken


func get_point_id() -> StringName:
	return StringName(point_id) if not point_id.is_empty() else StringName(name)


## Id del nivel generado que lo contiene (&"" si no hay).
func get_level_id() -> StringName:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return StringName((node as GeneratedLevel).level_id)
		node = node.get_parent()
	return GameState.NO_LEVEL


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Isak:
		return
	_taken = true
	if GameState.capture_attention_point(get_level_id(), get_point_id(), value):
		collected.emit(value)
	queue_free()
