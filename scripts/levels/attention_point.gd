## Punto de atencion recogible (tipo `o` del level-builder), version minima:
## al tocarlo Isak suma `value` puntos con GameState.add_attention_points(),
## que tambien repone energia de Debug (A10: +10 por punto). Se puede recoger
## con el Debug activo. Aspecto provisional (rombo del color del icono de
## puntos del HUD, data/hud.json); el arte llega con el tileset del Mundo 1.
class_name AttentionPoint
extends Area2D

signal collected(value: int)

## Puntos que suma (A10: cada punto vale 1).
@export var value: int = 1
## Radio de recogida y de dibujo en px (un cuarto de tile).
@export var radius_px: float = 16.0

var _taken: bool = false


func _ready() -> void:
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


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Isak:
		return
	_taken = true
	GameState.add_attention_points(value)
	collected.emit(value)
	queue_free()
