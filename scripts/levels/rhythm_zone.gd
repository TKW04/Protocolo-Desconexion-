## Metronomo del nivel (tipo `rhythm_zone` del catalogo del Mundo 1; Tramo 2
## «Vibracion» del 1-3, docs/propuesta-1-3.md §3.3 y §5.3; paso 5 de §7).
##
## Objeto logico: marca un compas que siguen las plataformas que parpadean
## (blink_platform), los banners con `rhythm` y las campanas de alarma. RITMO
## SOLO VISUAL (no hay audio): un icono de vibracion en el fondo, en su celda,
## late con cada ciclo.
## - zone: rectangulo de celdas [columna, fila, ancho, alto] (absoluto).
## - tempo_steps_s: duraciones del ciclo; cada cycles_per_step ciclos pasa a la
##   siguiente (se acelera). Con loop vuelve a la primera tras la ultima; sin
##   loop se queda en la ultima.
## - start: on_enter (arranca cuando Isak entra en la zona; antes esta quieto
##   en la fase 0) o always.
## - TIEMPO DEL MUNDO (WorldTime: el Debug lo ralentiza; la pausa lo para).
## - Al reaparecer Isak (EventBus.player_respawned) vuelve al principio.
## El origen del nodo es la esquina superior izquierda de la celda del icono.
## AlarmTunnel (alarm_tunnel.gd) lo amplia con el compas por posicion.
class_name RhythmZone
extends Node2D

const GROUP: StringName = &"rhythm_zone"
const START_ON_ENTER: String = "on_enter"
const START_ALWAYS: String = "always"

## Empieza un ciclo nuevo (numero de ciclos completos hasta ahora).
signal beat(cycle_count: int)
## Cambia el ciclo (paso de tempo_steps_s o tramo del tunel).
signal tempo_changed(cycle_s: float)
## Ha arrancado (Isak entro en la zona).
signal started

@export var object_id: StringName = &""
## [columna, fila, ancho, alto] en celdas.
@export var zone: Array = [0, 0, 1, 1]
@export var tempo_steps_s: Array = [3.2, 2.6, 2.0]
@export var cycles_per_step: int = 4
@export var loop: bool = true
@export var start_mode: String = START_ON_ENTER

var _config: Dictionary = World1ObjectsConfig.section("rhythm_zone")
var _started: bool = false
var _t: float = 0.0
var _cycles: int = 0
var _last_cycle_s: float = -1.0
var _isak: Isak


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_config.get("icon_z_index", -1))
	EventBus.player_respawned.connect(_on_player_respawned)
	reset()


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso con `delta` real (se escala aqui). Publico para las pruebas.
func step(delta: float) -> void:
	if not _started:
		if start_mode == START_ALWAYS or _isak_inside():
			_start()
		else:
			return
	_update_progress()
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo (ya arrancado).
func advance(dt: float) -> void:
	if not _started:
		return
	_t += dt
	var cycle: float = get_cycle_s()
	while _t >= cycle:
		_t -= cycle
		_cycles += 1
		beat.emit(_cycles)
		cycle = get_cycle_s()
	_check_tempo()
	queue_redraw()


# --- Consultas ---

func is_started() -> bool:
	return _started


## Duracion del ciclo actual (s de tiempo del mundo).
func get_cycle_s() -> float:
	if tempo_steps_s.is_empty():
		return 1.0
	return maxf(float(tempo_steps_s[get_step_index()]), 0.05)


## Indice del paso de tempo_steps_s que suena ahora.
func get_step_index() -> int:
	var n: int = tempo_steps_s.size()
	if n == 0:
		return 0
	var k: int = _cycles / maxi(cycles_per_step, 1)
	return k % n if loop else mini(k, n - 1)


## Ciclos completos desde que arranco.
func get_cycle_count() -> int:
	return _cycles


## Segundos (tiempo del mundo) desde que empezo el ciclo actual.
func get_cycle_time() -> float:
	return _t


## Fase del ciclo actual, de 0 a 1.
func get_beat_phase() -> float:
	return clampf(_t / get_cycle_s(), 0.0, 1.0)


## Zona en coordenadas globales (px).
func get_zone_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	var parent_origin: Vector2 = global_position - position
	return Rect2(parent_origin + Vector2(float(zone[0]), float(zone[1])) * t,
		Vector2(float(zone[2]), float(zone[3])) * t)


## Sin ayuda con Q (objeto logico).
func is_help_available() -> bool:
	return false


## El metronomo con id `id` del mismo nivel que `from` (o null).
static func find(from: Node, id: StringName) -> RhythmZone:
	if id == &"" or from == null or not from.is_inside_tree():
		return null
	for node: Node in from.get_tree().get_nodes_in_group(GROUP):
		var zone_node := node as RhythmZone
		if zone_node != null and zone_node.object_id == id and zone_node.get_parent() == from.get_parent():
			return zone_node
	for node: Node in from.get_tree().get_nodes_in_group(GROUP):
		var zone_node := node as RhythmZone
		if zone_node != null and zone_node.object_id == id:
			return zone_node
	return null


# --- Acciones ---

## Vuelve al principio (fase 0, primer paso; quieto si arranca al entrar).
func reset() -> void:
	_t = 0.0
	_cycles = 0
	_started = start_mode == START_ALWAYS
	_reset_progress()
	_last_cycle_s = get_cycle_s()
	queue_redraw()


# --- Para AlarmTunnel ---

## Progreso propio (AlarmTunnel: la columna mas avanzada). Aqui, nada.
func _update_progress() -> void:
	pass


func _reset_progress() -> void:
	pass


func _find_isak() -> Isak:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	return _isak


# --- Interno ---

func _start() -> void:
	_started = true
	started.emit()


func _isak_inside() -> bool:
	var isak: Isak = _find_isak()
	if isak == null or isak.is_dead():
		return false
	return get_zone_rect().has_point(isak.global_position - Vector2(0.0, 1.0))


func _check_tempo() -> void:
	var cycle: float = get_cycle_s()
	if not is_equal_approx(cycle, _last_cycle_s):
		_last_cycle_s = cycle
		tempo_changed.emit(cycle)


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


## Icono de vibracion (arte por script, paso 8: tools/gen_world1_dnd.py): el
## celular con los arcos apagados; la primera arc_lit_fraction de cada ciclo,
## encendido y desplazado lit_shake_px a un lado y a otro (vibra).
func is_icon_lit() -> bool:
	return _started and get_beat_phase() < float(_config.get("arc_lit_fraction", 0.25))


func _draw() -> void:
	var lit: bool = is_icon_lit()
	var key: String = "icon_lit" if lit else "icon_dim"
	var texture: Texture2D = _cached_texture(String(_config.get(key, "")))
	if texture == null:
		return
	var t: float = World1ObjectsConfig.tile_size()
	var shake: float = 0.0
	if lit:
		var shake_px: float = float(_config.get("lit_shake_px", 2.0))
		shake = shake_px if get_cycle_count() % 2 == 0 else -shake_px
	draw_texture(texture, (Vector2(t, t) - texture.get_size()) * 0.5 + Vector2(shake, 0.0))

## Texturas ya cargadas por ruta. _draw se llama cada cuadro y load() de un
## recurso importado relee su .import en disco (~0,7 ms por llamada aunque este
## en cache): con varias instancias hundia el 1-3 a menos de 10 FPS.
static var _texture_cache: Dictionary = {}


static func _cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _texture_cache[path]
