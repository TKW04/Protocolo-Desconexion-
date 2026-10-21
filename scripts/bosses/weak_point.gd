## Punto debil de un jefe (regla fija: rojo = dano y puntos debiles; en el
## Mundo 1 carmin puro y pulsante). Componente reutilizable: los jefes lo
## anaden como hijo (BossBase.set_weak_point).
##
## La MARCA (2026-10-21, docs/propuesta-jefe-alerta-mayor.md §2.3; sustituye a
## «solo dana con el Debug activo» del paso 3). Tres estados:
## - OCULTO (sin Debug ni marca): no se dibuja y no es objetivo. El laser lo
##   atraviesa y, si el jefe dio su cuerpo (set_shell_rect), se para en el
##   CUERPO; el pulso o el laser que tocan el cuerpo sacan la CHISPA GRIS en el
##   borde del cuerpo mas cercano a Isak, nunca en el nucleo (no lo delata).
## - REVELADO (intensidad del Debug > 0): se dibuja en carmin. Solo con el Debug
##   ACTIVO (DebugMode.is_active(); la carga, la salida y el revelado persistente
##   del Debug 3 no cuentan) un PULSO que lo alcanza lo MARCA (senal marked). El
##   laser contra el nucleo revelado sin marca: chispa gris en el nucleo.
## - MARCADO durante mark_duration_s segundos del MUNDO (el Debug la alarga en
##   tiempo real; set_mark_duration, BossBase la toma de laps del jefe): se
##   dibuja aunque el Debug este apagado, con un halo de segmentos que se apagan
##   como un reloj y parpadea en los ultimos mark_warning_s (mark_warning). Cada
##   LASER que lo alcanza es un golpe de su dano (1; 2 con el Laser 4; senal
##   hit), sin Debug y todos los que quepan. El pulso NO dana: con el Debug
##   activo refresca la marca entera (marked con refreshed); sin el, chispa gris
##   y la marca sigue igual. Al acabar, mark_expired.
## La marca se pierde (sin mark_expired) con clear_mark: al desactivarse el
## nucleo (set_enabled(false), el jefe sube), al cambiar de fase, en el golpe
## final y al reaparecer Isak (BossBase). El DASH nunca hace dano: el nucleo no
## reacciona a cuerpos. Desactivado no reacciona a nada, no para el laser y no
## se dibuja.
##
## Decision 2026-10-14 (docs/preguntas.md, V10): se dibuja POR ENCIMA del tinte
## del Debug, para que no quede apagado. El visual vive en un CanvasLayer propio
## (follow_viewport, asi sigue a la camara) cuya capa esta entre DebugOverlay
## (5) y el HUD (10); su posicion copia la global del Area2D cada cuadro. Pulsa
## de `color` a `pulse_color` en tiempo real. Valores en data/weak_point.json.
class_name WeakPoint
extends Area2D

const GROUP: StringName = &"weak_point"
const GROUP_LASER_ACTIVATABLE: StringName = &"laser_activatable"
## Capa de fisica enemy (project.godot, layer_3): el rayo del laser la mira.
const LAYER_ENEMY: int = 4
const ANIM_SPARK: StringName = &"gray_spark"
const LASER_ORIGIN_METHOD: StringName = &"get_laser_origin"

## Un golpe cuenta (nucleo marcado): `damage` golpes (el dano del laser).
signal hit(damage: int, source: Node)
## Golpe sin efecto: chispa gris, sin dano ni marca.
signal deflected(source: Node)
## El pulso con el Debug activo marca el nucleo `duration_s` s del mundo
## (`refreshed`: ya estaba marcado y vuelve a la duracion entera).
signal marked(duration_s: float, refreshed: bool)
## A la marca le quedan mark_warning_s (aviso: parpadeo y sonido).
signal mark_warning
## La marca ha caducado (no se emite si se pierde con clear_mark).
signal mark_expired
const DEFAULT_PATH: String = "res://data/weak_point.json"
const MSEC_PER_S: float = 1000.0

static var _cfg: Dictionary = {}

## Si es falso, la cuenta de la marca no avanza sola (pruebas: advance_mark).
@export var auto_process: bool = true

var _layer: CanvasLayer
var _visual: Node2D
var _shape: CollisionShape2D
var _intensity: float = 0.0
var _pulse: float = 0.0
var _enabled: bool = true
var _spark: EnergySprite
## Segundos del mundo que lleva la chispa gris (-1 = apagada).
var _spark_time: float = -1.0
var _mark_duration_s: float = 0.0
var _mark_left: float = 0.0
var _mark_warned: bool = false
## Segundos reales que le quedan al destello de marcar.
var _mark_flash_left: float = 0.0
var _shell: Area2D
var _shell_shape: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	if _mark_duration_s <= 0.0:
		_mark_duration_s = default_mark_duration()
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
	_sync_targets()


func _process(delta: float) -> void:
	_mark_flash_left = maxf(_mark_flash_left - delta, 0.0)
	_update(Time.get_ticks_msec() / MSEC_PER_S)
	_update_spark(WorldTime.scaled_delta(delta))


func _physics_process(delta: float) -> void:
	if auto_process:
		advance_mark(WorldTime.scaled_delta(delta))
	_sync_targets()


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


## Duracion de la marca por defecto (s del mundo; el jefe la cambia por vuelta).
static func default_mark_duration() -> float:
	return float(config().get("mark_duration_s", 4.0))


## Color del relleno en el instante `time_s` (s reales): 0 = color, medio
## periodo = pulse_color.
static func color_at(time_s: float) -> Color:
	var cfg: Dictionary = config()
	var f: float = 0.5 - 0.5 * cos(TAU * float(cfg["pulse_hz"]) * time_s)
	return Color.html(cfg["color"]).lerp(Color.html(cfg["pulse_color"]), f)


## Verdadero si se dibuja (Debug activo o en su transicion, o marcado).
func is_revealed() -> bool:
	return _visual.visible


## Activa o desactiva el nucleo (sin forma, sin dibujo y sin reaccionar).
## Desactivarlo pierde la marca.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		clear_mark()
	if _shape != null:
		_shape.set_deferred(&"disabled", not enabled)
	if _shell_shape != null:
		_shell_shape.set_deferred(&"disabled", not enabled)
	_sync_targets()
	if _visual != null:
		_update(_pulse)


func is_enabled() -> bool:
	return _enabled


## Expuesto: activo y visible para el jugador (Debug con intensidad o marca). Solo
## entonces el nucleo es objetivo del laser y del pulso; oculto, lo es el cuerpo.
func is_exposed() -> bool:
	return _enabled and (DebugMode.get_intensity() > 0.0 or is_marked())


## Un pulso que lo alcance ahora lo marca: activo y con el Debug ACTIVO.
func can_mark() -> bool:
	return _enabled and DebugMode.is_active()


## Un laser que lo alcance ahora cuenta: activo y marcado.
func can_take_damage() -> bool:
	return is_marked()


# --- Marca ---

## Ayuda de Eco (alert_major_core, paso 12 del jefe): solo cuando el nucleo se
## ve (revelado por el Debug o marcado); oculto no da pistas de donde esta.
func is_help_available() -> bool:
	return is_enabled() and (is_revealed() or is_marked())


func is_marked() -> bool:
	return _enabled and _mark_left > 0.0


## Segundos del mundo que le quedan a la marca (0 sin marca).
func get_mark_time_left() -> float:
	return _mark_left if is_marked() else 0.0


func get_mark_duration() -> float:
	return _mark_duration_s


## Duracion de la marca en s del mundo (BossBase: laps.<vuelta>.mark_duration_s).
func set_mark_duration(duration_s: float) -> void:
	_mark_duration_s = maxf(duration_s, 0.0)


## Avanza la cuenta de la marca `dt` segundos del mundo.
func advance_mark(dt: float) -> void:
	if _mark_left <= 0.0:
		return
	_mark_left = maxf(_mark_left - dt, 0.0)
	if _mark_left <= 0.0:
		_mark_warned = false
		_sync_targets()
		mark_expired.emit()
		return
	if not _mark_warned and _mark_left <= mark_warning_s():
		_mark_warned = true
		mark_warning.emit()


## Quita la marca sin mark_expired (el jefe sube, cambia de fase o reaparece).
func clear_mark() -> void:
	_mark_left = 0.0
	_mark_warned = false
	_mark_flash_left = 0.0
	_sync_targets()


static func mark_warning_s() -> float:
	return float(config().get("mark_warning_s", 1.0))


## Segmentos del halo encendidos (cuenta atras: 0 sin marca).
func get_mark_segments_lit() -> int:
	if not is_marked() or _mark_duration_s <= 0.0:
		return 0
	var n: int = int(config().get("mark_halo_segments", 8))
	return clampi(ceili(float(n) * _mark_left / _mark_duration_s - 0.0001), 1, n)


## En el aviso final el halo parpadea: verdadero si en este instante va apagado.
func is_mark_blink_off() -> bool:
	if not is_marked() or _mark_left > mark_warning_s():
		return false
	var hz: float = maxf(float(config().get("mark_blink_hz", 6.0)), 0.01)
	return fmod(_mark_left * hz, 1.0) < 0.5


# --- Cuerpo (chispa sin delatar el nucleo) ---

## Cuerpo del jefe en coordenadas locales del nucleo: con el nucleo oculto el
## laser se para en el y la chispa gris sale en su borde. Sin cuerpo, el nucleo
## oculto no reacciona a nada.
func set_shell_rect(rect: Rect2) -> void:
	if _shell == null:
		_shell = Area2D.new()
		_shell.name = "Shell"
		_shell.collision_mask = 0
		_shell.monitoring = false
		_shell.monitorable = true
		_shell.add_to_group(GROUP_LASER_ACTIVATABLE)
		_shell_shape = CollisionShape2D.new()
		_shell_shape.shape = RectangleShape2D.new()
		_shell.add_child(_shell_shape)
		add_child(_shell)
	(_shell_shape.shape as RectangleShape2D).size = rect.size
	_shell.position = rect.get_center()
	_shell_shape.disabled = not _enabled
	_sync_targets()


func has_shell() -> bool:
	return _shell != null


## Rectangulo global del cuerpo (Rect2() sin cuerpo).
func get_shell_global_rect() -> Rect2:
	if _shell == null:
		return Rect2()
	var size: Vector2 = (_shell_shape.shape as RectangleShape2D).size * _shell.global_scale.abs()
	return Rect2(_shell.global_position - size * 0.5, size)


## Capa de fisica que el laser ve ahora del nucleo y del cuerpo (pruebas).
func get_core_layer() -> int:
	return collision_layer


func get_shell_layer() -> int:
	return _shell.collision_layer if _shell != null else 0


# --- Golpes ---

## Golpes que hacia un pulso antes de la marca (data/weak_point.json); el pulso ya
## no dana (solo marca). Se conserva para datos y pruebas antiguas.
static func pulse_damage() -> int:
	return int(config().get("pulse_damage", 1))


## Interfaz del laser (LaserProjectile; lo llama el rayo al parar en el nucleo o
## en el cuerpo, que es su hijo). Marcado: golpe; expuesto sin marca: chispa en
## el nucleo; oculto: chispa en el borde del cuerpo.
func on_laser_hit(damage: float, source: Node) -> void:
	if not _enabled:
		return
	if is_marked():
		hit.emit(maxi(roundi(damage), 1), source)
		return
	if is_exposed():
		_deflect(global_position, source)
		return
	if _shell != null:
		_deflect(_shell_point_towards(_source_point(source)), source)


## Comprueba si el pulso (`area`, PulseArea con un CircleShape2D) alcanza el
## nucleo expuesto (lo marca con el Debug activo; si no, chispa gris en el
## nucleo) o, con el nucleo oculto, el cuerpo (chispa en su borde). Verdadero si
## alcanza algo.
func receive_pulse(area: Area2D) -> bool:
	if not _enabled or area == null:
		return false
	var source: Node = area.get_parent()
	if is_exposed():
		if not pulse_reaches(area, global_position, radius_px()):
			return false
		if can_mark():
			_mark()
		else:
			_deflect(global_position, source)
		return true
	if _shell == null or not PulseReceiver.pulse_reaches(area, get_shell_global_rect()):
		return false
	_deflect(_shell_point_towards(_pulse_center(area)), source)
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


## Chispa gris visible (golpe sin efecto).
func is_spark_visible() -> bool:
	return _spark != null and _spark.visible


## Posicion global de la ultima chispa gris.
func get_spark_position() -> Vector2:
	return _spark.global_position


## Capa del CanvasLayer del visual (por encima del efecto del Debug).
func get_draw_layer() -> int:
	return _layer.layer


func get_visual_position() -> Vector2:
	return _visual.position


func get_fill_color() -> Color:
	return Color(color_at(_pulse), _draw_alpha())


# --- Interno ---

func _draw_alpha() -> float:
	return 1.0 if is_marked() else _intensity


func _update(time_s: float) -> void:
	_intensity = DebugMode.get_intensity()
	_pulse = time_s
	_visual.visible = _enabled and (_intensity > 0.0 or is_marked()) and is_visible_in_tree()
	_visual.position = global_position
	if _visual.visible:
		_visual.queue_redraw()


## El laser ve el nucleo solo expuesto y el cuerpo solo con el nucleo oculto.
func _sync_targets() -> void:
	var exposed: bool = is_exposed()
	collision_layer = LAYER_ENEMY if (_enabled and exposed) else 0
	if _shell != null:
		_shell.collision_layer = LAYER_ENEMY if (_enabled and not exposed) else 0


func _draw_visual() -> void:
	var cfg: Dictionary = config()
	var r: float = radius_px()
	var a: float = _draw_alpha()
	var bright: Color = Color.html(cfg["pulse_color"])
	_visual.draw_circle(Vector2.ZERO, r + float(cfg["outline_width_px"]), Color(Color.html(cfg["outline_color"]), a))
	_visual.draw_circle(Vector2.ZERO, r, get_fill_color())
	var ring: float = float(cfg["ring_width_px"])
	_visual.draw_arc(Vector2.ZERO, r - ring * 0.5, 0.0, TAU, 32, Color(bright, a), ring)
	_visual.draw_circle(Vector2.ZERO, float(cfg["core_radius_px"]), Color(bright, a))
	if is_marked():
		_draw_mark_halo(cfg, r)


## Halo de la marca (arte provisional por script): anillo de segmentos en
## mark_halo_color fuera del contorno; los encendidos son los ultimos en sentido
## horario desde arriba (se apagan uno a uno); parpadea en el aviso final; al
## marcar, destello breve (mas grueso).
func _draw_mark_halo(cfg: Dictionary, r: float) -> void:
	if is_mark_blink_off():
		return
	var n: int = int(cfg.get("mark_halo_segments", 8))
	var lit: int = get_mark_segments_lit()
	var width: float = float(cfg.get("mark_halo_width_px", 4.0))
	if _mark_flash_left > 0.0:
		width += float(cfg.get("mark_flash_extra_px", 3.0))
	var radius: float = r + float(cfg["outline_width_px"]) + float(cfg.get("mark_halo_gap_px", 4.0)) + width * 0.5
	var color: Color = Color.html(String(cfg.get("mark_halo_color", "#f2f4f8")))
	var outline: Color = Color.html(cfg["outline_color"])
	var step: float = TAU / float(n)
	var gap: float = deg_to_rad(float(cfg.get("mark_halo_segment_gap_deg", 10.0)))
	for i: int in n:
		if i < n - lit:
			continue
		var from: float = -PI * 0.5 + float(i) * step + gap * 0.5
		var to: float = from + step - gap
		_visual.draw_arc(Vector2.ZERO, radius, from, to, 8, outline, width + 2.0)
		_visual.draw_arc(Vector2.ZERO, radius, from, to, 8, color, width)


func _mark() -> void:
	var refreshed: bool = is_marked()
	_mark_left = _mark_duration_s
	_mark_warned = false
	_mark_flash_left = float(config().get("mark_flash_s", 0.15))
	_sync_targets()
	marked.emit(_mark_duration_s, refreshed)


func _deflect(at: Vector2, source: Node) -> void:
	_spark_time = 0.0
	_spark.global_position = at
	_spark.visible = true
	_spark.frame = 0
	deflected.emit(source)


## Punto del borde del cuerpo mas cercano a `from` (o su centro si esta dentro).
func _shell_point_towards(from: Vector2) -> Vector2:
	var rect: Rect2 = get_shell_global_rect()
	return Vector2(clampf(from.x, rect.position.x, rect.end.x), clampf(from.y, rect.position.y, rect.end.y))


## Boca del laser de quien dispara (Isak) o su posicion; el centro del cuerpo si
## no hay nadie.
func _source_point(source: Node) -> Vector2:
	var node := source as Node2D
	if node == null or not is_instance_valid(node):
		return get_shell_global_rect().get_center()
	if node.has_method(LASER_ORIGIN_METHOD):
		return node.global_position + (node.call(LASER_ORIGIN_METHOD) as Vector2)
	return node.global_position


static func _pulse_center(area: Area2D) -> Vector2:
	for child: Node in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape is CircleShape2D:
			return shape_node.global_position
	return area.global_position


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
