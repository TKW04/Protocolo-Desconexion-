## Punto debil de un jefe (regla fija: rojo = dano y puntos debiles; en el
## Mundo 1 carmin puro y pulsante). Componente reutilizable: los jefes lo
## anadiran como hijo (aun no hay jefes).
##
## Decision 2026-10-14 (docs/preguntas.md, V10): solo es visible con el Debug
## activo y se dibuja POR ENCIMA del tinte del Debug, para que no quede
## apagado. El visual vive en un CanvasLayer propio (follow_viewport, asi sigue
## a la camara) cuya capa esta entre DebugOverlay (5) y el HUD (10); su
## posicion copia la global del Area2D cada cuadro. Pulsa de `color` a
## `pulse_color` en tiempo real. Valores en data/weak_point.json.
class_name WeakPoint
extends Area2D

const GROUP: StringName = &"weak_point"
const DEFAULT_PATH: String = "res://data/weak_point.json"
const MSEC_PER_S: float = 1000.0

static var _cfg: Dictionary = {}

var _layer: CanvasLayer
var _visual: Node2D
var _shape: CollisionShape2D
var _intensity: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_px()
	_shape.shape = circle
	add_child(_shape)
	_layer = CanvasLayer.new()
	_layer.layer = int(config()["layer"])
	_layer.follow_viewport_enabled = true
	add_child(_layer)
	_visual = Node2D.new()
	_visual.draw.connect(_draw_visual)
	_layer.add_child(_visual)
	_update(0.0)


func _process(_delta: float) -> void:
	_update(Time.get_ticks_msec() / MSEC_PER_S)


## Ajustes compartidos de data/weak_point.json.
static func config() -> Dictionary:
	if _cfg.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PATH))
		if data is Dictionary:
			_cfg = data
		else:
			push_error("WeakPoint: no se pudo leer '%s'" % DEFAULT_PATH)
	return _cfg


static func radius_px() -> float:
	return float(config()["radius_px"])


## Color del relleno en el instante `time_s` (s reales): 0 = color, medio
## periodo = pulse_color.
static func color_at(time_s: float) -> Color:
	var cfg: Dictionary = config()
	var f: float = 0.5 - 0.5 * cos(TAU * float(cfg["pulse_hz"]) * time_s)
	return Color.html(cfg["color"]).lerp(Color.html(cfg["pulse_color"]), f)


## Verdadero si se dibuja (Debug activo o en su transicion).
func is_revealed() -> bool:
	return _visual.visible


## Capa del CanvasLayer del visual (por encima del efecto del Debug).
func get_draw_layer() -> int:
	return _layer.layer


func get_visual_position() -> Vector2:
	return _visual.position


func get_fill_color() -> Color:
	return Color(color_at(_pulse), _intensity)


func _update(time_s: float) -> void:
	_intensity = DebugMode.get_intensity()
	_pulse = time_s
	_visual.visible = _intensity > 0.0 and is_visible_in_tree()
	_visual.position = global_position
	if _visual.visible:
		_visual.queue_redraw()


func _draw_visual() -> void:
	var cfg: Dictionary = config()
	var r: float = radius_px()
	var a: float = _intensity
	var bright: Color = Color.html(cfg["pulse_color"])
	_visual.draw_circle(Vector2.ZERO, r + float(cfg["outline_width_px"]), Color(Color.html(cfg["outline_color"]), a))
	_visual.draw_circle(Vector2.ZERO, r, get_fill_color())
	var ring: float = float(cfg["ring_width_px"])
	_visual.draw_arc(Vector2.ZERO, r - ring * 0.5, 0.0, TAU, 32, Color(bright, a), ring)
	_visual.draw_circle(Vector2.ZERO, float(cfg["core_radius_px"]), Color(bright, a))
