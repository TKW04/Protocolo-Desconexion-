## Disparador de una linea de Eco (tipo `eco_line` de la lista `objects` del
## nivel, V7; PROPUESTA V6). Zona invisible de width_tiles x height_tiles desde
## la esquina superior izquierda de la celda (x, y). Cuando Isak entra, pide al
## cuadro de texto de Eco (EcoTextBox, por EventBus.eco_line_requested) que
## muestre `text` durante al menos `duration_s`. Con `once` (por defecto) solo
## se dispara la primera vez. No es solida, no pausa el juego y no toca a Isak.
## Detecta la capa de fisica `player` (2).
class_name EcoLine
extends Area2D

const GROUP: StringName = &"eco_line"

## Se ha disparado la linea (antes de que el cuadro la muestre).
signal triggered(text: String)

@export var object_id: StringName = &""
@export_multiline var text: String = ""
@export_range(1, 64) var width_tiles: int = 1
@export_range(1, 64) var height_tiles: int = 4
## Tiempo minimo en pantalla del texto completo (s); el cuadro alarga los textos largos.
@export var duration_s: float = 4.0
@export var once: bool = true

var _fired_count: int = 0
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	body_entered.connect(_on_body_entered)


func get_fired_count() -> int:
	return _fired_count


func has_fired() -> bool:
	return _fired_count > 0


## Zona de disparo en coordenadas locales (px).
func get_zone_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	return Rect2(Vector2.ZERO, Vector2(width_tiles * t, height_tiles * t))


func _build() -> void:
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var zone: Rect2 = get_zone_rect()
	rect.size = zone.size
	_shape.shape = rect
	_shape.position = zone.get_center()
	add_child(_shape)


func _on_body_entered(body: Node2D) -> void:
	if not body is Isak:
		return
	if once and _fired_count > 0:
		return
	_fired_count += 1
	triggered.emit(text)
	EventBus.eco_line_requested.emit(text, duration_s)
	if once:
		set_deferred(&"monitoring", false)
