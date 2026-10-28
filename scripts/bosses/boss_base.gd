## Base reutilizable de los jefes (2026-10-21, paso 2 de
## docs/propuesta-jefe-alerta-mayor.md §6; §4.1). Lleva lo comun a los 6 jefes:
## - Fases y contador: la vida es un numero de golpes al nucleo por fase
##   (hits_per_phase de la vuelta actual en data/bosses/<id>.json, laps). El
##   contador que ve el jugador es round(counter.max x golpes que quedan /
##   golpes totales), con counter.full_label («99+») con la vida entera.
##   Al vaciar una fase empieza la siguiente (EventBus.boss_phase_changed) y el
##   jefe suelta phase_change_refill (+25 de energia y +25 de Sync Rate). Un golpe
##   que sobra al acabar una fase no pasa a la siguiente.
## - Golpes: take_core_hit(damage) (lo llama su WeakPoint: el Debug lo revela, el
##   pulso lo marca y el laser lo dana mientras dura la marca, 2026-10-21; el dash
##   nunca). EventBus.boss_weak_point_hit. La duracion de la marca es
##   laps.<vuelta>.mark_duration_s (s del mundo; Alerta Mayor 4 / 3 / 2,5) y la
##   marca se pierde al cambiar de fase, en el golpe final y al reaparecer.
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
## Los jefes concretos (AlertMajor, Autoplay) heredan y sobrescriben los _on_*
## virtuales. Tiempo del mundo: advance(dt) avanza con el delta escalado
## (pruebas: con auto_process falso llaman a advance a mano).
## Generalizado para el jefe del Mundo 2 (2026-10-23, paso 15 de
## docs/propuesta-mundo-2.md §8): heal_hits (la cuenta de la fase 2 de Autoplay
## devuelve golpes sin pasar del inicio de la fase; senal healed y
## EventBus.boss_healed) y lo comun que antes vivia en AlertMajor: say_line
## (Eco hablando por el jefe, interlocutor SPEAKER, senal line_said), la raiz
## del nivel, los cargadores de la arena (apply_charger_cooldown), find_isak y
## el interruptor de la secuencia de derrota (defeat_sequence; BossDefeat lo
## empieza cada jefe: BossDefeat nombra a BossBase).
class_name BossBase
extends Node2D

## Interlocutor del cuadro de texto: Eco hablando por el jefe (icono con
## interferencia, blip vox_boss_eco_filter; speakers de data/eco_text_box.json).
const SPEAKER: StringName = &"eco_boss"
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
## El jefe recupera golpes (heal_hits); quedan `remaining`.
signal healed(remaining: int)
## Eco dice una linea por el jefe (kind: intro, phase, defeat; audio:
## mus_eco_motif en la intro y la derrota).
signal line_said(kind: StringName)

## Id del jefe (data/bosses/<boss_id>.json y senales de EventBus).
@export var boss_id: StringName = &""
## Tras el golpe final empieza la secuencia de derrota (BossDefeat: congelacion,
## desarme en pixeles, recompensa, linea de derrota y vortice al hub). La llama
## el jefe concreto con begin_defeat().
@export var defeat_sequence: bool = true
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
var _weak_point: WeakPoint
## Marca del nucleo de la vuelta actual (s del mundo; <= 0 = la del WeakPoint).
var _mark_duration_s: float = 0.0
## Golpes de laser por marca de la vuelta actual (laps.<n>.mark_hits; 0 = sin
## tope). La Curadora: 1 (2026-10-27, paso 14 de docs/propuesta-mundo-3.md §5.3).
var _mark_hits: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	load_config()
	# Encuadre de la arena (2026-10-22): camera.follow del JSON del jefe.
	if bool((_config.get("camera", {}) as Dictionary).get("follow", false)):
		BossCamera.attach(self)
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
	_mark_duration_s = 0.0
	_mark_hits = 0
	if entry is Dictionary:
		for value: Variant in (entry as Dictionary).get("hits_per_phase", []):
			_hits_per_phase.append(maxi(int(value), 1))
		_mark_duration_s = float((entry as Dictionary).get("mark_duration_s", 0.0))
		_mark_hits = maxi(int((entry as Dictionary).get("mark_hits", 0)), 0)
	_apply_mark_duration()
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


## El jefe recupera `count` golpes sin pasar de los que tenia al empezar la fase
## actual (Autoplay: la cuenta de la fase 2 llega a 0). Devuelve los recuperados.
func heal_hits(count: int = 1) -> int:
	if _state != STATE_FIGHTING or count <= 0:
		return 0
	var top: int = _phase_floor(_phase - 1)
	var before: int = _remaining
	_remaining = mini(_remaining + count, top)
	var gained: int = _remaining - before
	if gained > 0:
		healed.emit(_remaining)
		EventBus.boss_healed.emit(boss_id, _remaining)
	return gained


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
	_clear_mark()
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


## Hay un jefe en el arbol sin vencer (2026-10-22: el cuadro de Eco va abajo y la
## Q de Eco se calma mientras dura la pelea).
static func is_any_active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node is BossBase and not (node as BossBase).is_defeated():
			return true
	return false


## X globales que la camara de la arena encuadra junto a Isak (BossCamera). El
## jefe concreto anade lo suyo (Alerta Mayor: cuerpo y copias).
func get_camera_focus_xs() -> PackedFloat32Array:
	return PackedFloat32Array([global_position.x])


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


## Duracion de la marca de la vuelta actual (s del mundo; 0 = la del WeakPoint).
func get_mark_duration() -> float:
	return _mark_duration_s


## Golpes de laser por marca de la vuelta actual (0 = sin tope).
func get_mark_hits() -> int:
	return _mark_hits


## Punto debil de este jefe (null si no tiene).
func get_weak_point() -> WeakPoint:
	return _weak_point


## Asigna el punto debil: sus golpes (laser con la marca) cuentan como
## take_core_hit; le pasa la duracion de la marca de la vuelta. Paso 3 de la
## propuesta (2026-10-21).
func set_weak_point(weak_point: WeakPoint) -> void:
	if _weak_point != null and is_instance_valid(_weak_point) and _weak_point.hit.is_connected(_on_weak_point_hit):
		_weak_point.hit.disconnect(_on_weak_point_hit)
	_weak_point = weak_point
	if _weak_point != null:
		_weak_point.hit.connect(_on_weak_point_hit)
	_apply_mark_duration()


## Posicion global del nucleo si se puede golpear ahora (punto debil activo y
## pelea en curso); Vector2.INF si no.
func get_core_target() -> Vector2:
	if _state != STATE_FIGHTING or _weak_point == null or not is_instance_valid(_weak_point) \
			or not _weak_point.is_enabled():
		return Vector2.INF
	return _weak_point.global_position


# --- Objetos por fase (arena de jefe, paso 5 de la propuesta, 2026-10-21) ---

## Metadata de los nodos de una arena que solo existen en ciertas fases
## (active_in_phase del JSON del nivel; tools/build_level.py).
const PHASE_META: StringName = &"active_in_phase"
const META_LAYER: StringName = &"_phase_saved_layer"
const META_TILES: StringName = &"_phase_replaced_tiles"


## Activa los nodos de `root` con active_in_phase que incluyen `phase` y
## desactiva los demas (phase 0 = antes de empezar: todos inactivos). Lo llama
## GeneratedLevel al empezar y el jefe al empezar cada fase.
static func apply_phase_nodes(root: Node, phase: int) -> void:
	if root == null:
		return
	for node: Node in phase_nodes(root):
		var phases: Array = node.get_meta(PHASE_META, [])
		set_phase_node_active(node, phases.has(phase))


## Nodos de `root` (y descendientes) con active_in_phase.
static func phase_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta(PHASE_META):
			out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out


## Verdadero si el nodo de fase esta activo.
static func is_phase_node_active(node: Node) -> bool:
	return node.process_mode != Node.PROCESS_MODE_DISABLED


## Activa o desactiva un nodo de fase: sin proceso, invisible y sin capa de
## colision (se guarda la suya). Al activarse vuelve a su estado inicial
## (reset_patrol / reset / refresh). Una plataforma que parpadea activa borra
## las celdas del TileMapLayer «Tiles» del nivel que ocupa (las '-' que
## reemplaza) y las devuelve al desactivarse.
static func set_phase_node_active(node: Node, active: bool) -> void:
	var was_active: bool = is_phase_node_active(node)
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = active
	var body := node as CollisionObject2D
	if body != null:
		if not body.has_meta(META_LAYER):
			body.set_meta(META_LAYER, body.collision_layer)
		body.collision_layer = int(body.get_meta(META_LAYER)) if active else 0
	if node is BlinkPlatform:
		_replace_tiles(node as BlinkPlatform, active)
	if active and not was_active:
		if node.has_method(&"reset_patrol"):
			node.call(&"reset_patrol")
		elif node is RhythmZone:
			(node as RhythmZone).reset()
		if node is BlinkPlatform:
			(node as BlinkPlatform).refresh()


static func _replace_tiles(platform: BlinkPlatform, active: bool) -> void:
	var tiles: TileMapLayer = _level_tiles(platform)
	if tiles == null:
		return
	if active:
		if platform.has_meta(META_TILES):
			return
		var saved: Array = []
		var size: float = float(World1ObjectsConfig.tile_size())
		var origin: Vector2 = tiles.to_local(platform.global_position)
		var row: int = floori(origin.y / size + 0.001)
		var col: int = floori(origin.x / size + 0.001)
		for i: int in platform.width_tiles:
			var cell := Vector2i(col + i, row)
			var source: int = tiles.get_cell_source_id(cell)
			if source < 0:
				continue
			saved.append([cell, source, tiles.get_cell_atlas_coords(cell), tiles.get_cell_alternative_tile(cell)])
			tiles.erase_cell(cell)
		platform.set_meta(META_TILES, saved)
	elif platform.has_meta(META_TILES):
		for entry: Array in platform.get_meta(META_TILES):
			tiles.set_cell(entry[0], entry[1], entry[2], entry[3])
		platform.remove_meta(META_TILES)


static func _level_tiles(from: Node) -> TileMapLayer:
	var node: Node = from.get_parent()
	while node != null:
		var tiles := node.get_node_or_null(^"Tiles") as TileMapLayer
		if tiles != null:
			return tiles
		node = node.get_parent()
	return null


# --- Comun de los jefes concretos (antes en AlertMajor; 2026-10-23) ---

## Isak del nivel (o null).
func find_isak() -> Isak:
	return LevelLookup.find_isak(self)


## Raiz del nivel (GeneratedLevel: el primer padre con level_id) o el padre. Sin
## tipos de GeneratedLevel ni EcoTextBox aqui: los dos nombran a BossBase y el
## ciclo rompe la carga de los jefes que heredan de esta clase.
func _level_root() -> Node:
	var node: Node = get_parent()
	while node != null:
		if &"level_id" in node:
			return node
		node = node.get_parent()
	return get_parent()


## Cargadores de la arena (los del nivel).
func _chargers() -> Array[Charger]:
	var out: Array[Charger] = []
	var root: Node = _level_root()
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Charger:
			out.append(node as Charger)
		for child: Node in node.get_children():
			stack.append(child)
	return out


## Enfriamiento de los cargadores de la arena (laps.<n>.charger_cooldown_s; <= 0 no cambia).
func apply_charger_cooldown(cooldown_s: float) -> void:
	if cooldown_s <= 0.0:
		return
	for charger: Charger in _chargers():
		charger.cooldown_s = cooldown_s


## Dice una linea del jefe: Eco hablando por el (interlocutor SPEAKER en el
## cuadro de texto del nivel: icono con interferencia y su blip; importante =
## pausa). Llama a `on_done` cuando esa linea se cierra (las no importantes,
## enseguida). Sin cuadro de texto en el nivel, por EventBus como Eco. `top`: el cuadro arriba aunque haya jefe
## (EcoTextBox.show_line; abajo taparia algo de la pelea).
func say_line(text: String, important: bool, on_done: Callable = Callable(), kind: StringName = &"",
		top: bool = false) -> void:
	line_said.emit(kind)
	var box: Node = _text_box()
	if box == null:
		if important and on_done.is_valid():
			EventBus.eco_line_finished.connect(on_done, CONNECT_ONE_SHOT)
		EventBus.eco_line_requested.emit(text, -1.0, important)
		if not important and on_done.is_valid():
			on_done.call()
		return
	if important and on_done.is_valid():
		_watch_line(box, GameState.apply_nickname(text), on_done)
	box.call(&"show_line", text, -1.0, important, SPEAKER, top)
	if not important and on_done.is_valid():
		on_done.call()


## Cuadro de texto del nivel (hijo EcoTextBox de la escena generada) o null.
func _text_box() -> Node:
	var root: Node = _level_root()
	return root.get_node_or_null(^"EcoTextBox") if root != null else null


## Espera a que la linea `text` del jefe empiece y despues se cierre (una normal
## del jefe que se quita para dejarle paso no cuenta) y llama a `done`. Con
## lambdas y no con una clase interna: una clase interna en BossBase rompe la
## carga de los jefes que heredan cuando se cargan antes que ella (Godot 4.7).
func _watch_line(box: Node, text: String, done: Callable) -> void:
	var state: Dictionary = {"started": false}
	state["start"] = func(t: String, speaker: StringName) -> void:
		if speaker == SPEAKER and t == text:
			state["started"] = true
	state["finish"] = func(speaker: StringName) -> void:
		if not bool(state["started"]) or speaker != SPEAKER:
			return
		box.disconnect(&"line_started", state["start"])
		box.disconnect(&"line_finished", state["finish"])
		done.call()
	box.connect(&"line_started", state["start"])
	box.connect(&"line_finished", state["finish"])


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
	_clear_mark()
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
	_clear_mark()
	if _window_open:
		_set_window_closed()
		window_closed.emit()
	_state = STATE_DEFEATED
	defeated.emit()
	EventBus.boss_defeated.emit(boss_id)
	_on_defeated()


func _apply_mark_duration() -> void:
	if _weak_point != null and is_instance_valid(_weak_point) and _mark_duration_s > 0.0:
		_weak_point.set_mark_duration(_mark_duration_s)
	if _weak_point != null and is_instance_valid(_weak_point) and _mark_hits > 0:
		_weak_point.set_mark_hits(_mark_hits)


func _clear_mark() -> void:
	if _weak_point != null and is_instance_valid(_weak_point):
		_weak_point.clear_mark()


func _set_window_closed() -> void:
	_window_open = false
	_window_left = 0.0


func _on_weak_point_hit(damage: int, _source: Node) -> void:
	take_core_hit(damage)


func _on_player_respawned(_position: Vector2, after_death: bool) -> void:
	if after_death:
		restart_phase()
