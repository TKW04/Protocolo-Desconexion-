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
## Arte por script (paso 8, 2026-10-20): tools/gen_world1_dnd.py.
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


## Ayuda de Eco (tipo blink_platform): siempre (no se destruye).
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


## Textura del estado actual (tools/gen_world1_dnd.py): on con los segmentos
## llenos, warn (un cuadro de cada dos del aviso) u off (contorno punteado).
func get_texture_name() -> String:
	var base: String = "blink_w%d_" % clampi(width_tiles, 1, 3)
	if not _solid:
		return base + "off_00.png"
	if is_warning():
		var fps: float = maxf(float(_config.get("anim_fps", 12.0)), 1.0)
		if int(floor(get_time_to_off() * fps)) % 2 == 1:
			return base + "warn_00.png"
	return base + "on_%02d.png" % get_lit_segments()


func _draw() -> void:
	var dir: String = String(_config.get("texture_dir", "res://assets/sprites/props/dnd/"))
	var texture := load(dir + get_texture_name()) as Texture2D
	if texture != null:
		draw_texture(texture, Vector2.ZERO)
