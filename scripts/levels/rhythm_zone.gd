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


## Icono de vibracion (provisional por codigo): un celular con arcos que se
## encienden al principio de cada ciclo; mas rapido = arcos mas cortos.
func _draw() -> void:
	var t: float = World1ObjectsConfig.tile_size()
	var body := Color(String(_config.get("icon_color", "#aeb8d2")))
	var dim := Color(String(_config.get("arc_dim_color", "#2e4688")))
	var lit := Color(String(_config.get("arc_lit_color", "#9bb0e8")))
	var lit_fraction: float = float(_config.get("arc_lit_fraction", 0.25))
	var center := Vector2(t * 0.5, t * 0.5)
	var phone := Rect2(center - Vector2(10.0, 18.0), Vector2(20.0, 36.0))
	draw_rect(phone, body, false, 3.0)
	draw_rect(Rect2(center + Vector2(-4.0, 11.0), Vector2(8.0, 3.0)), body)
	var on: bool = _started and get_beat_phase() < lit_fraction
	var color: Color = lit if on else dim
	var shake: float = 2.0 if on else 0.0
	for side: float in [-1.0, 1.0]:
		for k: int in 2:
			var r: float = 18.0 + 8.0 * k
			var c: Vector2 = center + Vector2(side * shake, 0.0)
			var from_angle: float = -0.6 if side > 0.0 else PI - 0.6
			draw_arc(c + Vector2(side * 4.0, 0.0), r, from_angle, from_angle + 1.2, 6, color, 3.0)
