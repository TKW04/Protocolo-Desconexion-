## Punto debil de un jefe (regla fija: rojo = dano y puntos debiles; en el
## Mundo 1 carmin puro y pulsante). Componente reutilizable: los jefes lo
## anaden como hijo (BossBase.set_weak_point).
##
## Dano (2026-10-21, paso 3 de docs/propuesta-jefe-alerta-mayor.md §6; §2.3):
## SOLO recibe golpes con el Debug activo (DebugMode.is_active(); la carga, la
## salida y el revelado persistente del Debug 3 no cuentan), por el PULSO (1
## golpe, pulse_damage; si su circulo toca el del nucleo) o el LASER (su dano:
## 1, o 2 con el Laser 4; grupo laser_activatable en la capa enemy, el haz se
## para en el). Senal hit(damage, source). Sin el Debug, el pulso o el laser que
## lo alcanzan sacan la CHISPA GRIS (gray_spark de spark_frames) y no hacen dano
## (senal deflected). El DASH nunca hace dano: el nucleo no reacciona a cuerpos.
## Desactivado (set_enabled(false), p. ej. con el jefe arriba) no reacciona a
## nada, no para el laser y no se dibuja.
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
const GROUP_LASER_ACTIVATABLE: StringName = &"laser_activatable"
## Capa de fisica enemy (project.godot, layer_3): el rayo del laser la mira.
const LAYER_ENEMY: int = 4
const ANIM_SPARK: StringName = &"gray_spark"

## Un golpe cuenta (Debug activo): `damage` golpes (pulso 1; laser su dano).
signal hit(damage: int, source: Node)
## Golpe sin el Debug: chispa gris, sin dano.
signal deflected(source: Node)
const DEFAULT_PATH: String = "res://data/weak_point.json"
const MSEC_PER_S: float = 1000.0

static var _cfg: Dictionary = {}

var _layer: CanvasLayer
var _visual: Node2D
var _shape: CollisionShape2D
var _intensity: float = 0.0
var _pulse: float = 0.0
var _enabled: bool = true
var _spark: EnergySprite
## Segundos del mundo que lleva la chispa gris (-1 = apagada).
var _spark_time: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_px()
	_shape.shape = circle
	add_child(_shape)
	add_to_group(GROUP_LASER_ACTIVATABLE)
	collision_layer = LAYER_ENEMY
	collision_mask = 0
	monitoring = false
	monitorable = true
	_spark = EnergySprite.attach(self, ANIM_SPARK, Vector2.ZERO, false, String(config().get("spark_frames", "")))
	_spark.name = "Spark"
	_spark.visible = false
	_spark.z_index = int(config().get("spark_z_index", 5))
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_layer = CanvasLayer.new()
	_layer.layer = int(config()["layer"])
	_layer.follow_viewport_enabled = true
	add_child(_layer)
	_visual = Node2D.new()
	_visual.draw.connect(_draw_visual)
	_layer.add_child(_visual)
	_update(0.0)


func _process(delta: float) -> void:
	_update(Time.get_ticks_msec() / MSEC_PER_S)
	_update_spark(WorldTime.scaled_delta(delta))


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


## Activa o desactiva el nucleo (sin forma, sin dibujo y sin reaccionar).
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _shape != null:
		_shape.set_deferred(&"disabled", not enabled)
	if _visual != null:
		_update(_pulse)


func is_enabled() -> bool:
	return _enabled


## Ahora un golpe cuenta: activo y con el Debug activo.
func can_take_damage() -> bool:
	return _enabled and DebugMode.is_active()


## Golpes que hace un pulso (data/weak_point.json, pulse_damage).
static func pulse_damage() -> int:
	return int(config().get("pulse_damage", 1))


## Interfaz del laser (LaserProjectile): con el Debug cuenta su dano; sin el,
## chispa gris.
func on_laser_hit(damage: float, source: Node) -> void:
	if not _enabled:
		return
	_receive(maxi(roundi(damage), 1), source)


## Comprueba si el pulso (`area`, PulseArea con un CircleShape2D) toca el nucleo
## y, si es asi, lo golpea (o saca la chispa gris). Verdadero si lo alcanza.
func receive_pulse(area: Area2D) -> bool:
	if not _enabled or not pulse_reaches(area, global_position, radius_px()):
		return false
	_receive(pulse_damage(), area.get_parent() if area != null else null)
	return true


## Verdadero si algun circulo de `area` toca el circulo (`center`, `radius`).
static func pulse_reaches(area: Area2D, center: Vector2, radius: float) -> bool:
	if area == null:
		return false
	for child: Node in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or not (shape_node.shape is CircleShape2D):
			continue
		var scale_factor: float = maxf(absf(shape_node.global_scale.x), absf(shape_node.global_scale.y))
		var r: float = (shape_node.shape as CircleShape2D).radius * scale_factor
		if shape_node.global_position.distance_to(center) <= r + radius:
			return true
	return false


## Chispa gris visible (golpe sin el Debug).
func is_spark_visible() -> bool:
	return _spark != null and _spark.visible


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
	_visual.visible = _enabled and _intensity > 0.0 and is_visible_in_tree()
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


func _receive(damage: int, source: Node) -> void:
	if can_take_damage():
		hit.emit(damage, source)
		return
	_spark_time = 0.0
	_spark.visible = true
	_spark.frame = 0
	deflected.emit(source)


func _update_spark(dt: float) -> void:
	if _spark_time < 0.0:
		return
	_spark_time += dt
	var fps: float = _spark.sprite_frames.get_animation_speed(ANIM_SPARK)
	var f: int = floori(_spark_time * fps)
	if f >= _spark.sprite_frames.get_frame_count(ANIM_SPARK):
		_spark_time = -1.0
		_spark.visible = false
	else:
		_spark.frame = f


func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)
