## Capa por encima del velo del Modo oscuro (DarkZone) para lo que siempre se ve
## (2026-10-28, paso 5 de docs/propuesta-mundo-4.md §8 y regla de legibilidad de
## §3.6): la crea un objeto o enemigo del Mundo 4 que esta dentro de una zona
## oscura (DarkOverlay.attach) y llama cada cuadro a host.draw_dark_overlay(capa)
## para dibujar ahi, en coordenadas locales del host, su contorno rojo o su aviso.
## Fuera de lo oscuro no se crea (el dibujo normal no cambia).
class_name DarkOverlay
extends Node2D

const METHOD: StringName = &"draw_dark_overlay"

## Nodo que dibuja en la capa (debe tener draw_dark_overlay(canvas)).
var host: Node


## Crea la capa como hija de `host` si `point` (global) esta bajo el velo de una
## DarkZone; si no, null.
static func attach(host_node: Node2D, point: Vector2) -> DarkOverlay:
	if host_node == null or not host_node.is_inside_tree():
		return null
	if DarkZone.covering(host_node.get_tree(), point) == null:
		return null
	var layer := DarkOverlay.new()
	layer.name = "DarkOverlay"
	layer.host = host_node
	layer.z_as_relative = false
	layer.z_index = DarkZone.veil_z() + 1
	host_node.add_child(layer)
	return layer


func _process(_delta: float) -> void:
	queue_redraw()


# --- Acecho (2026-10-28, peligros ocultos del Modo oscuro; docs/propuesta-mundo-4.md
# §8.1): un enemigo con `lurk` que espera a oscuras no dibuja su contorno rojo (aun no
# dana) sino dos OJOS crema que parpadean; bajo la Linterna se ve entero y, en cuanto
# ataca (aviso de 9 cuadros), vuelve el contorno rojo. El Debug lo revela: silueta
# en coral por encima del velo. Valores en la seccion dark_zone.lurk de
# data/world4_objects.json.

## Seccion lurk de dark_zone (ojos y revelado).
static func lurk_cfg() -> Dictionary:
	var cfg: Variant = World4ObjectsConfig.section("dark_zone").get("lurk", {})
	return cfg if cfg is Dictionary else {}


## Verdadero si el punto global esta bajo la luz de la Linterna.
static func lit_at(host_node: Node2D, point: Vector2) -> bool:
	return host_node != null and host_node.is_inside_tree() \
			and DarkZone.lit_by_flashlight(host_node.get_tree(), point)


## Ojos del acechador en `center` (coordenadas de la capa), mirando hacia `look`
## (-1 / 1); cerrados un instante cada blink_every_s.
static func draw_lurk_eyes(canvas: CanvasItem, center: Vector2, look: int, time_s: float) -> void:
	var cfg: Dictionary = lurk_cfg()
	var every: float = maxf(float(cfg.get("blink_every_s", 2.6)), 0.1)
	var closed: bool = fmod(time_s, every) < float(cfg.get("blink_s", 0.15))
	var color: Color = World4ObjectsConfig.color(String(cfg.get("eye_color", "crema")), Color("#eee4cc"))
	color.a = float(cfg.get("eye_alpha", 0.6))
	var gap: float = float(cfg.get("eye_gap_px", 7.0))
	var size := Vector2(4.0, 1.0 if closed else 3.0)
	var shift := Vector2(2.0 * float(look), 0.0)
	for side: float in [-1.0, 1.0]:
		var p: Vector2 = center + shift + Vector2(side * gap * 0.5, 0.0)
		canvas.draw_rect(Rect2(p - size * 0.5, size), color)


## Silueta en coral (revelado del Debug) de `rect` (coordenadas de la capa).
static func draw_debug_reveal(canvas: CanvasItem, rect: Rect2) -> void:
	var coral: Color = World4ObjectsConfig.color("debug_coral", Color("#ff9f7a"))
	canvas.draw_rect(rect, Color(coral, 0.25))
	canvas.draw_rect(rect, coral, false, 2.0)


func _draw() -> void:
	if host != null and is_instance_valid(host) and host.has_method(METHOD):
		host.call(METHOD, self)
