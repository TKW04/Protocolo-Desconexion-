## Luz de un hueco del dock (2026-10-28, paso 4 de docs/propuesta-mundo-4.md §8 y §3.6;
## docs/propuesta-asistentes-y-vidas.md §2.4): el hueco de la Linterna (columna 13) se
## ENCIENDE al conocerla (GameState.has_met_ally del `lit_by_ally` del hueco en
## data/hub.json): un haz crema por encima y el hueco a plena luz. Sin panel ni logica.
## La crea HubRoom como hija del hueco; escucha EventBus.ally_met. Aspecto PROVISIONAL
## por codigo (lit_glow del hueco).
class_name DockSlotLight
extends Node2D

## Asistente que la enciende.
var ally: StringName = &""
## Tamano del hueco (px).
var slot_size := Vector2(64.0, 96.0)
## lit_glow del hueco: color, alpha y alto del haz.
var glow: Dictionary = {}

var _lit: bool = false


func _ready() -> void:
	EventBus.ally_met.connect(_on_ally_met)
	set_lit(GameState.has_met_ally(ally))


func _exit_tree() -> void:
	if EventBus.ally_met.is_connected(_on_ally_met):
		EventBus.ally_met.disconnect(_on_ally_met)


func is_lit() -> bool:
	return _lit


func set_lit(on: bool) -> void:
	_lit = on
	var visual := get_parent().get_node_or_null(^"Visual") as CanvasItem if get_parent() != null else null
	if visual != null:
		var level: float = float(glow.get("on_brightness", 1.25)) if on else float(glow.get("off_brightness", 1.0))
		visual.modulate = Color(level, level, level)
	if get_parent() != null:
		get_parent().set_meta(&"lit", on)
	queue_redraw()


func _on_ally_met(id: StringName) -> void:
	if id == ally:
		set_lit(true)


func _draw() -> void:
	if not _lit:
		return
	var color := Color(String(glow.get("color", "#eee4cc")))
	color.a = float(glow.get("alpha", 0.28))
	var top: float = float(glow.get("top_px", 30))
	var height: float = float(glow.get("height_px", 80))
	var cx: float = slot_size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 10.0, top), Vector2(cx + 10.0, top),
		Vector2(cx + 30.0, top - height), Vector2(cx - 30.0, top - height)]), color)
