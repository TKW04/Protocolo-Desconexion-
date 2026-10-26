## Regeneracion pasiva de las mejoras de Calc (tanda M2, 2026-10-17;
## docs/propuesta-mejoras.md §5.2 y §6). Solo con las mejoras compradas:
## - Sync Rate 5 (Resincronizacion): fuera de combate el Sync Rate sube
##   GameState.get_sync_regen_per_s() (1/s) hasta el 60 % del maximo efectivo.
## - Energia 5 (recarga pasiva): GameState.get_energy_regen_pct_s() (0,5 %) del
##   maximo por segundo, delay_s (3 s) despues del ultimo gasto; nunca con el
##   Debug ni el Ocultarte activos ni con la barra llena; no desborda.
## Condiciones y tiempos en data/passive_regen.json (ver sus _notes). Isak la
## avanza (step) en cada paso de fisica con el delta REAL; aqui se pasa a tiempo
## del mundo (WorldTime). Detecta el gasto de energia y el dano porque la barra
## baja (sin tocar a quien gasta); Isak le avisa ademas de disparos, pulsos y
## golpes (note_combat). RefCounted: las pruebas la crean y la avanzan sola.
class_name PassiveRegen
extends RefCounted

const DATA_PATH: String = "res://data/passive_regen.json"
## Grupos que pueden poner a Isak «en combate» (enemigos y, en el futuro, jefes).
const GROUP_ENEMY: StringName = &"enemy"
const GROUP_BOSS: StringName = &"boss"
const COMBAT_METHOD: StringName = &"is_combat_active"
const CHASING_METHOD: StringName = &"is_chasing"
## Altura del centro de Isak sobre sus pies (px; = isak_center_y_px de help.json).
const ISAK_CENTER_Y: float = -48.0
const EPS: float = 0.0001

var out_of_combat_s: float = 6.0
var sync_cap_fraction: float = 0.6
var combat_radius_px: float = 384.0
var energy_delay_s: float = 3.0

## Segundos (del mundo) sin combate y desde el ultimo gasto de energia.
var _quiet_s: float = 0.0
var _since_spend_s: float = 0.0
var _last_energy: float = -1.0
var _last_sync: float = -1.0

static var _cached: Dictionary = {}


func _init() -> void:
	var d: Dictionary = load_data()
	var sync: Dictionary = d.get("sync", {})
	var energy: Dictionary = d.get("energy", {})
	out_of_combat_s = float(sync.get("out_of_combat_s", out_of_combat_s))
	sync_cap_fraction = float(sync.get("cap_fraction", sync_cap_fraction))
	combat_radius_px = float(sync.get("combat_radius_px", combat_radius_px))
	energy_delay_s = float(energy.get("delay_s", energy_delay_s))
	reset()


static func load_data() -> Dictionary:
	if _cached.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_cached = parsed
		else:
			push_error("PassiveRegen: no se pudo leer '%s'." % DATA_PATH)
	return _cached


## Empieza de cero (al reaparecer o al empezar el nivel): hace falta volver a
## esperar los 6 s fuera de combate y los 3 s sin gastar.
func reset() -> void:
	_quiet_s = 0.0
	_since_spend_s = 0.0
	_last_energy = GameState.debug_energy
	_last_sync = GameState.sync_rate


## Isak disparo, lanzo el pulso o recibio un golpe: vuelve a contar los 6 s.
func note_combat() -> void:
	_quiet_s = 0.0


func get_quiet_s() -> float:
	return _quiet_s


func get_since_spend_s() -> float:
	return _since_spend_s


## Tope de la Resincronizacion (60 % del maximo efectivo).
func get_sync_cap() -> float:
	return GameState.get_sync_rate_max() * sync_cap_fraction


## Un paso con `real_delta` (se pasa a tiempo del mundo). `isak` (puede ser null
## en pruebas sin escena) da la posicion para los enemigos cercanos.
## Devuelve {"sync": lo que subio, "energy": lo que subio}.
func step(real_delta: float, isak: Node2D) -> Dictionary:
	var dt: float = WorldTime.scaled_delta(real_delta)
	var out: Dictionary = {"sync": 0.0, "energy": 0.0}
	# Gasto de energia y dano detectados porque la barra baja.
	if GameState.debug_energy < _last_energy - EPS:
		_since_spend_s = 0.0
	else:
		_since_spend_s += dt
	if GameState.sync_rate < _last_sync - EPS:
		_quiet_s = 0.0
	if is_in_combat(isak):
		_quiet_s = 0.0
	else:
		_quiet_s += dt
	if not GameState.is_player_hidden():
		out["energy"] = _regen_energy(dt)
		out["sync"] = _regen_sync(dt)
	_last_energy = GameState.debug_energy
	_last_sync = GameState.sync_rate
	return out


## En combate: un perseguidor persigue (en cualquier sitio), un jefe activo o un
## enemigo activo (is_combat_active) a menos de combat_radius_px de Isak.
func is_in_combat(isak: Node2D) -> bool:
	if isak == null or not isak.is_inside_tree():
		return false
	var tree: SceneTree = isak.get_tree()
	for boss: Node in tree.get_nodes_in_group(GROUP_BOSS):
		if boss.has_method(COMBAT_METHOD) and bool(boss.call(COMBAT_METHOD)):
			return true
	var center: Vector2 = isak.global_position + Vector2(0.0, ISAK_CENTER_Y)
	for enemy: Node in tree.get_nodes_in_group(GROUP_ENEMY):
		if enemy.has_method(CHASING_METHOD) and bool(enemy.call(CHASING_METHOD)):
			return true
		if not enemy.has_method(COMBAT_METHOD) or not bool(enemy.call(COMBAT_METHOD)):
			continue
		if _distance_to(enemy, center) <= combat_radius_px:
			return true
	return false


## Distancia de `point` a la zona de dano del enemigo (o a su posicion).
static func _distance_to(enemy: Node, point: Vector2) -> float:
	if enemy.has_method(&"get_damage_rect"):
		var rect: Rect2 = enemy.call(&"get_damage_rect")
		var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		return point.distance_to(closest)
	if enemy is Node2D:
		return point.distance_to((enemy as Node2D).global_position)
	return INF


func _regen_energy(dt: float) -> float:
	var pct: float = GameState.get_energy_regen_pct_s()
	if pct <= 0.0 or DebugMode.is_active() or _since_spend_s < energy_delay_s:
		return 0.0
	var max_value: float = GameState.get_debug_energy_max()
	if GameState.debug_energy >= max_value - EPS:
		return 0.0
	# Nunca desborda (recharge_debug_energy pierde el sobrante).
	return GameState.recharge_debug_energy(max_value * pct / 100.0 * dt)


func _regen_sync(dt: float) -> float:
	var rate: float = GameState.get_sync_regen_per_s()
	if rate <= 0.0 or _quiet_s < out_of_combat_s:
		return 0.0
	var cap: float = get_sync_cap()
	if GameState.sync_rate >= cap - EPS:
		return 0.0
	var before: float = GameState.sync_rate
	GameState.sync_rate = minf(before + rate * dt, cap)
	return GameState.sync_rate - before
