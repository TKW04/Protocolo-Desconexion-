## Plataforma que parpadea al ritmo (tipo `blink_platform` del catalogo del
## Mundo 1; Tramo 2 «Vibracion» del 1-3, docs/propuesta-1-3.md §3.3 y §5.3;
## paso 5 de §7; patron 9 «Compas», §4).
##
## - Plataforma SOLIDA (capa world, no de una via, como el recordatorio: caer
##   se lee claro) de width_tiles x 1 con la tarjeta de card_height_px arriba
##   de su celda.
## - Sigue el metronomo `rhythm_id` (RhythmZone o AlarmTunnel): encendida la
##   parte on_fraction de cada ciclo, desplazada offset (fraccion del ciclo).
##   `group` (A, B, C...) es su etiqueta de grupo (las del mismo grupo llevan
##   el mismo offset). Sin metronomo, siempre encendida.
## - Encendida: solida, con SEG_COUNT segmentos que se vacian con lo que le
##   queda encendida. Los ultimos warn_frames cuadros a anim_fps (9 a 12 fps:
##   0,75 s; regla de 6-12 cuadros) PARPADEA. Apagada: contorno punteado sin
##   colision (Isak cae, sin dano).
## - Si Isak esta dentro de su caja al encenderse, no se materializa hasta que
##   salga.
## - Tiempo del mundo: lo marca su metronomo (el Debug lo ralentiza).
## El origen del nodo es la esquina superior izquierda de su primera celda.
## Arte PROVISIONAL por codigo (paso 8: arte por script).
class_name BlinkPlatform
extends StaticBody2D

const GROUP: StringName = &"blink_platform"
const LAYER_WORLD: int = 1
const SEG_COUNT: int = 4

## Se enciende (se vuelve solida).
signal switched_on
## Se apaga (deja de ser solida).
signal switched_off
## Empieza el parpadeo de aviso antes de apagarse.
signal warning_started

@export var object_id: StringName = &""
## Id del metronomo (rhythm_zone / alarm_tunnel) que sigue.
@export var rhythm_id: StringName = &""
@export var group_id: StringName = &"A"
@export_range(1, 3) var width_tiles: int = 2
## Parte del ciclo encendida (0-1).
@export var on_fraction: float = 0.5
## Desplazamiento en el ciclo (fraccion, 0-1).
@export var offset: float = 0.0

var _config: Dictionary = World1ObjectsConfig.section("blink_platform")
var _rhythm: RhythmZone
var _solid: bool = true
var _wants_on: bool = true
var _warned: bool = false
var _shape: CollisionShape2D
var _isak: Isak


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	var size: Vector2 = get_card_size()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	add_child(_shape)
	refresh()


func _physics_process(_delta: float) -> void:
	refresh()


# --- Consultas ---

## Solida ahora (encendida y materializada).
func is_solid() -> bool:
	return _solid


## Le toca estar encendida segun el compas (aunque Isak no la deje materializarse).
func wants_on() -> bool:
	return _wants_on


## En los ultimos cuadros de aviso antes de apagarse.
func is_warning() -> bool:
	return _solid and _wants_on and get_time_to_off() <= get_warn_s()


## Aviso: warn_frames cuadros a anim_fps (s de tiempo del mundo).
func get_warn_s() -> float:
	return float(_config.get("warn_frames", 9)) / maxf(float(_config.get("anim_fps", 12.0)), 1.0)


## Segundos (tiempo del mundo) hasta apagarse (0 si apagada; INF sin metronomo).
func get_time_to_off() -> float:
	var rhythm: RhythmZone = get_rhythm()
	if rhythm == null:
		return INF
	var local: float = _local_phase(rhythm)
	if local >= on_fraction:
		return 0.0
	return (on_fraction - local) * rhythm.get_cycle_s()


## Segmentos encendidos (lo que le queda encendida; SEG_COUNT sin metronomo).
func get_lit_segments() -> int:
	if not _solid:
		return 0
	var rhythm: RhythmZone = get_rhythm()
	if rhythm == null:
		return SEG_COUNT
	var left: float = clampf((on_fraction - _local_phase(rhythm)) / maxf(on_fraction, 0.001), 0.0, 1.0)
	return clampi(ceili(SEG_COUNT * left - 0.0001), 0, SEG_COUNT)


func get_rhythm() -> RhythmZone:
	if _rhythm == null or not is_instance_valid(_rhythm):
		_rhythm = RhythmZone.find(self, rhythm_id)
	return _rhythm


func get_card_size() -> Vector2:
	return Vector2(width_tiles * World1ObjectsConfig.tile_size(), float(_config.get("card_height_px", 32)))


func get_card_rect() -> Rect2:
	return Rect2(global_position, get_card_size())


## Ayuda de Eco (cuando la tenga, paso 8): siempre (no se destruye).
func is_help_available() -> bool:
	return true


# --- Acciones ---

## Recalcula el estado con la fase del metronomo (lo llama cada paso; publico
## para las pruebas, que avanzan el metronomo a mano).
func refresh() -> void:
	var rhythm: RhythmZone = get_rhythm()
	_wants_on = rhythm == null or _local_phase(rhythm) < on_fraction
	if _wants_on and not _solid:
		if not _isak_overlaps():
			_set_solid(true)
	elif not _wants_on and _solid:
		_set_solid(false)
	if is_warning() and not _warned:
		_warned = true
		warning_started.emit()
	queue_redraw()


# --- Interno ---

func _local_phase(rhythm: RhythmZone) -> float:
	return fposmod(rhythm.get_beat_phase() - offset, 1.0)


func _set_solid(on: bool) -> void:
	_solid = on
	if _shape != null:
		_shape.disabled = not on
	if on:
		_warned = false
		switched_on.emit()
	else:
		switched_off.emit()


func _isak_overlaps() -> bool:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	if _isak == null:
		return false
	return LevelLookup.isak_body_rect(_isak).intersects(get_card_rect())


func _draw() -> void:
	var size: Vector2 = get_card_size()
	var edge := Color(String(_config.get("edge_color", "#9bb0e8")))
	if not _solid:
		var dots := Color(String(_config.get("off_color", "#4f71c4")))
		var dash: float = float(_config.get("off_dash_px", 8.0))
		var x: float = 0.0
		while x < size.x:
			var w: float = minf(dash, size.x - x)
			draw_rect(Rect2(Vector2(x, 0.0), Vector2(w, 3.0)), dots)
			draw_rect(Rect2(Vector2(x, size.y - 3.0), Vector2(w, 3.0)), dots)
			x += dash * 2.0
		var y: float = 0.0
		while y < size.y:
			var h: float = minf(dash, size.y - y)
			draw_rect(Rect2(Vector2(0.0, y), Vector2(3.0, h)), dots)
			draw_rect(Rect2(Vector2(size.x - 3.0, y), Vector2(3.0, h)), dots)
			y += dash * 2.0
		return
	if is_warning():
		var fps: float = maxf(float(_config.get("anim_fps", 12.0)), 1.0)
		# Parpadeo: un cuadro de cada dos (a anim_fps) se dibuja solo el contorno.
		if int(floor(get_time_to_off() * fps)) % 2 == 1:
			draw_rect(Rect2(Vector2.ZERO, size), edge, false, 2.0)
			return
	draw_rect(Rect2(Vector2.ZERO, size), Color(String(_config.get("body_color", "#343f66"))))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 4.0)), edge)
	var lit := Color(String(_config.get("segment_lit_color", "#9bb0e8")))
	var unlit := Color(String(_config.get("segment_unlit_color", "#1a2138")))
	var seg := Vector2(float(_config.get("segment_w_px", 10.0)), float(_config.get("segment_h_px", 8.0)))
	var gap: float = float(_config.get("segment_gap_px", 4.0))
	var total: float = SEG_COUNT * seg.x + (SEG_COUNT - 1) * gap
	var x0: float = (size.x - total) * 0.5
	var lit_count: int = get_lit_segments()
	for i: int in SEG_COUNT:
		var r := Rect2(Vector2(x0 + i * (seg.x + gap), (size.y - seg.y) * 0.5 + 2.0), seg)
		draw_rect(r, lit if i < lit_count else unlit)
