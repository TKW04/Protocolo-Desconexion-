## Base reutilizable de los jefes (2026-10-21, paso 2 de
## docs/propuesta-jefe-alerta-mayor.md §6; §4.1). Lleva lo comun a los 6 jefes:
## - Fases y contador: la vida es un numero de golpes al nucleo por fase
##   (hits_per_phase de la vuelta actual en data/bosses/<id>.json, laps). El
##   contador que ve el jugador es round(counter.max x golpes que quedan /
##   golpes totales), con counter.full_label («99+») con la vida entera.
##   Al vaciar una fase empieza la siguiente (EventBus.boss_phase_changed) y el
##   jefe suelta phase_change_refill (+25 de energia y +25 de Sync Rate). Un golpe
##   que sobra al acabar una fase no pasa a la siguiente.
## - Golpes: take_core_hit(damage) (lo llama su WeakPoint, que solo recibe dano con
##   el Debug activo; el dash nunca). EventBus.boss_weak_point_hit.
## - Ventanas: open_window(s) / close_window() con su cuenta en tiempo del mundo
##   (el Debug la alarga en tiempo real). El jefe concreto decide cuando se abren.
## - Reaparicion por fase (decision 3, §2.9): al reaparecer Isak tras morir
##   (EventBus.player_respawned con after_death), el jefe vuelve al principio de
##   la fase actual (contador incluido) y la energia queda en max(la que habia,
##   respawn_min_energy). La tecla R recarga el nivel: pelea desde la fase 1.
## - Golpe final: al llegar a 0, estado DEFEATED y EventBus.boss_defeated. Ni
##   rollback ni cambio de vuelta (decision 1). La congelacion, el desarme y la
##   recompensa son del paso 10.
## - is_combat_active() (grupo boss): la regeneracion pasiva de Sync 5 se para.
## - API de consulta para el bot (como get_beat_phase del 1-3): get_phase(),
##   get_window_time_left(), get_attack_state(), get_core_target().
## Los jefes concretos (AlertMajor) heredan y sobrescriben los _on_* virtuales.
## Tiempo del mundo: advance(dt) avanza con el delta escalado (pruebas: con
## auto_process falso llaman a advance a mano).
class_name BossBase
extends Node2D

const GROUP: StringName = &"boss"
const STATE_IDLE: StringName = &"idle"
const STATE_FIGHTING: StringName = &"fighting"
const STATE_DEFEATED: StringName = &"defeated"
const ATTACK_NONE: StringName = &"none"
const DATA_DIR: String = "res://data/bosses/%s.json"

## Cambia la fase (no se emite al empezar en la 1).
signal phase_changed(phase: int)
## Un golpe al nucleo ha contado; quedan `remaining` golpes.
signal hit_taken(remaining: int)
## Se abre una ventana de `duration_s` segundos del mundo.
signal window_opened(duration_s: float)
signal window_closed
## Isak reaparecio: la fase `phase` vuelve a empezar.
signal phase_restarted(phase: int)
## Golpe final (contador a 0).
signal defeated

## Id del jefe (data/bosses/<boss_id>.json y senales de EventBus).
@export var boss_id: StringName = &""
## Empieza la pelea al entrar en el arbol (salas de prueba); la arena la empieza
## al terminar la llegada (pasos siguientes).
@export var auto_start: bool = false
## Si es falso, _physics_process no avanza (las pruebas llaman a advance).
@export var auto_process: bool = true
## Vuelta forzada (pruebas); -1 = GameState.lap.
@export var lap_override: int = -1

var _config: Dictionary = {}
var _hits_per_phase: Array[int] = []
var _state: StringName = STATE_IDLE
var _phase: int = 0
var _remaining: int = 0
var _window_left: float = 0.0
var _window_open: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	load_config()
	EventBus.player_respawned.connect(_on_player_respawned)
	if auto_start:
		start.call_deferred()


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Lee data/bosses/<boss_id>.json (o `data`, para pruebas) y prepara la vida de
## la vuelta actual. Devuelve falso si los datos no valen.
func load_config(data: Dictionary = {}) -> bool:
	if data.is_empty():
		var path: String = DATA_DIR % String(boss_id)
		if boss_id.is_empty() or not FileAccess.file_exists(path):
			push_error("BossBase: sin datos para '%s'" % boss_id)
			return false
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			push_error("BossBase: no se pudo leer '%s'" % path)
			return false
		data = parsed
	_config = data
	var lap: int = lap_override if lap_override > 0 else GameState.lap
	var laps: Dictionary = _config.get("laps", {})
	var entry: Variant = laps.get(str(lap), laps.get("1", {}))
	_hits_per_phase.clear()
	if entry is Dictionary:
		for value: Variant in (entry as Dictionary).get("hits_per_phase", []):
			_hits_per_phase.append(maxi(int(value), 1))
	if _hits_per_phase.is_empty():
		_hits_per_phase.append(1)
	_remaining = get_total_hits()
	return true


func get_config() -> Dictionary:
	return _config


# --- Pelea ---

## Empieza la pelea en la fase 1 con la vida entera.
func start() -> void:
	if _state == STATE_FIGHTING:
		return
	_state = STATE_FIGHTING
	_phase = 1
	_remaining = get_total_hits()
	_set_window_closed()
	EventBus.boss_started.emit(boss_id)
	_on_phase_started(_phase)


## Avanza `dt` segundos del mundo (ventana y logica del jefe concreto).
func advance(dt: float) -> void:
	if _state != STATE_FIGHTING:
		return
	if _window_open:
		_window_left = maxf(_window_left - dt, 0.0)
		if _window_left <= 0.0:
			close_window()
	if _state == STATE_FIGHTING:
		_on_advance(dt)


## Golpe al nucleo de `damage` golpes (pulso 1; laser su dano, Laser 4 = 2).
## Verdadero si cuenta (pelea en curso y damage > 0).
func take_core_hit(damage: int = 1) -> bool:
	if _state != STATE_FIGHTING or damage <= 0:
		return false
	var floor_hits: int = _phase_floor(_phase)
	_remaining = maxi(_remaining - mini(damage, _remaining - floor_hits), floor_hits)
	hit_taken.emit(_remaining)
	EventBus.boss_weak_point_hit.emit(boss_id, _remaining)
	_on_core_hit(_remaining)
	if _remaining <= 0:
		_defeat()
	elif _remaining == floor_hits:
		_next_phase()
	return true


## Abre una ventana de `duration_s` segundos del mundo (reinicia la cuenta).
func open_window(duration_s: float) -> void:
	if _state != STATE_FIGHTING:
		return
	_window_open = true
	_window_left = maxf(duration_s, 0.0)
	window_opened.emit(_window_left)
	_on_window_opened(_window_left)


## Cierra la ventana (si estaba abierta).
func close_window() -> void:
	if not _window_open:
		return
	_set_window_closed()
	window_closed.emit()
	_on_window_closed()


## La fase actual vuelve a empezar (reaparicion tras morir).
func restart_phase() -> void:
	if _state != STATE_FIGHTING:
		return
	_remaining = _phase_floor(_phase - 1)
	if _window_open:
		_set_window_closed()
		window_closed.emit()
	var min_energy: float = float(_config.get("respawn_min_energy", 0.0))
	GameState.debug_energy = maxf(GameState.debug_energy, min_energy)
	phase_restarted.emit(_phase)
	_on_phase_restarted(_phase)


# --- Consultas (HUD y bot) ---

func get_state() -> StringName:
	return _state


func is_fighting() -> bool:
	return _state == STATE_FIGHTING


func is_defeated() -> bool:
	return _state == STATE_DEFEATED


## En combate (PassiveRegen: la regeneracion de Sync 5 se para).
func is_combat_active() -> bool:
	return _state == STATE_FIGHTING


## Fase actual (1..n; 0 antes de empezar).
func get_phase() -> int:
	return _phase


func get_phase_count() -> int:
	return _hits_per_phase.size()


func get_hits_per_phase() -> Array[int]:
	return _hits_per_phase.duplicate()


func get_total_hits() -> int:
	var total: int = 0
	for hits: int in _hits_per_phase:
		total += hits
	return total


func get_remaining_hits() -> int:
	return _remaining


## Golpes que faltan para acabar la fase actual.
func get_phase_hits_left() -> int:
	return _remaining - _phase_floor(_phase) if _phase > 0 else 0


## Contador visible: round(max x quedan / total).
func get_counter() -> int:
	return counter_for(_remaining)


func counter_for(remaining: int) -> int:
	var total: int = maxi(get_total_hits(), 1)
	var top: int = int((_config.get("counter", {}) as Dictionary).get("max", 99))
	return roundi(float(top) * float(clampi(remaining, 0, total)) / float(total))


## Texto del contador: full_label («99+») con la vida entera; si no, el numero.
func get_counter_label() -> String:
	if _remaining >= get_total_hits():
		return String((_config.get("counter", {}) as Dictionary).get("full_label", str(get_counter())))
	return str(get_counter())


func is_window_open() -> bool:
	return _window_open


## Segundos del mundo que le quedan a la ventana (0 si esta cerrada).
func get_window_time_left() -> float:
	return _window_left if _window_open else 0.0


## Ataque en curso (el jefe concreto lo sobrescribe; ATTACK_NONE por defecto).
func get_attack_state() -> StringName:
	return ATTACK_NONE


## Posicion global del nucleo si se puede golpear ahora; Vector2.INF si no (sin
## punto debil todavia: lo anade el paso 3).
func get_core_target() -> Vector2:
	return Vector2.INF


# --- Virtuales del jefe concreto ---

## Empieza la fase `phase` (tambien la 1 al empezar).
func _on_phase_started(_phase_index: int) -> void:
	pass


## La fase `phase` vuelve a empezar tras reaparecer Isak.
func _on_phase_restarted(phase_index: int) -> void:
	_on_phase_started(phase_index)


func _on_advance(_dt: float) -> void:
	pass


func _on_core_hit(_remaining_hits: int) -> void:
	pass


func _on_window_opened(_duration_s: float) -> void:
	pass


func _on_window_closed() -> void:
	pass


func _on_defeated() -> void:
	pass


# --- Interno ---

## Golpes que quedan al acabar la fase `phase_index` (0 = toda la vida).
func _phase_floor(phase_index: int) -> int:
	var left: int = 0
	for i: int in range(maxi(phase_index, 0), _hits_per_phase.size()):
		left += _hits_per_phase[i]
	return left


func _next_phase() -> void:
	if _window_open:
		_set_window_closed()
		window_closed.emit()
	_phase += 1
	var refill: Dictionary = _config.get("phase_change_refill", {})
	GameState.debug_energy += float(refill.get("energy", 0.0))
	GameState.heal_sync(float(refill.get("sync", 0.0)))
	phase_changed.emit(_phase)
	EventBus.boss_phase_changed.emit(boss_id, _phase)
	_on_phase_started(_phase)


func _defeat() -> void:
	if _window_open:
		_set_window_closed()
		window_closed.emit()
	_state = STATE_DEFEATED
	defeated.emit()
	EventBus.boss_defeated.emit(boss_id)
	_on_defeated()


func _set_window_closed() -> void:
	_window_open = false
	_window_left = 0.0


func _on_player_respawned(_position: Vector2, after_death: bool) -> void:
	if after_death:
		restart_phase()
