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
## En los niveles del Mundo 2 (GeneratedLevel.world == 2) el rombo lleva un
## contorno oscuro de 1 px (`feed_noche` de la paleta B, data/world2_objects.json)
## para que no se confunda con el tinte ambar del Debug (decision 2026-10-22,
## docs/propuesta-mundo-2.md §8.1); el Mundo 1 y el hub no cambian.
class_name AttentionPoint
extends Area2D

signal collected(value: int)

## Puntos que suma (A10: cada punto vale 1).
@export var value: int = 1
## Radio de recogida y de dibujo en px (un cuarto de tile).
@export var radius_px: float = 16.0
## Id persistente del punto; vacio = el nombre del nodo.
@export var point_id: String = ""

## Mundo con contorno en los puntos y color de la paleta del Mundo 2 que lo pinta.
const OUTLINE_WORLD: int = 2
const OUTLINE_PALETTE_NAME: String = "feed_noche"
## Grosor del contorno en px de pantalla.
const OUTLINE_PX: float = 1.0

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
	if has_outline():
		# Rombo mayor detras: grosor perpendicular de OUTLINE_PX en cada lado.
		draw_colored_polygon(_diamond(radius_px + OUTLINE_PX * sqrt(2.0)), get_outline_color())
	draw_colored_polygon(_diamond(radius_px), HudConfig.shared().color(&"attention_icon"))


func _diamond(r: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0)])


## true solo dentro de un nivel generado del Mundo 2.
func has_outline() -> bool:
	return get_level_world() == OUTLINE_WORLD


func get_outline_color() -> Color:
	return World2ObjectsConfig.color(OUTLINE_PALETTE_NAME, Color.BLACK)


## Mundo del nivel generado que lo contiene (0 fuera de uno: hub y escenas de prueba).
func get_level_world() -> int:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return (node as GeneratedLevel).world
		node = node.get_parent()
	return 0


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; recogido, no.
func is_help_available() -> bool:
	return not _taken


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
