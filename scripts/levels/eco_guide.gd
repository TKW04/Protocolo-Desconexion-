## Guion propio de Eco (tipo `eco_guide`; 2026-10-17, tanda H1 del paso 14 de
## docs/propuesta-1-2.md; diseno en docs/propuesta-calc-encuentro.md). Acciones
## de Eco que NO son la ayuda Q, data-driven: pasos en orden de
## data/eco_guides.json (guide_id), cada uno una espera o una accion:
## - wait_near {object, radius_tiles}: Isak a esa distancia de la pieza.
## - wait_inside {object}: Isak dentro del rectangulo de la pieza (get_room_rect).
## - wait_done {object}: la pieza esta hecha (CalcRoom.is_done).
## - wait_ability {ability: pulse | laser | debug}: Isak la usa (desde ese paso).
## - wait_s {seconds}: pausa del guion (tiempo de juego; la pausa la para).
## - wait_quiet {max_s}: espera a que el cuadro de texto del nivel no tenga
##   nada en pantalla ni en cola (asi las lineas del guion no se amontonan y Eco
##   no se va antes de que se lea lo que dice); como mucho max_s (15 s); sin
##   cuadro, no espera.
## - fly {object | cell, offset_px}: Eco vuela junto a la pieza o a la celda y
##   se queda (EcoCompanion.set_guide_point; sin brillo ni Q).
## - back: Eco vuelve a Isak.
## - line {text, important}: linea de Eco; por defecto NO importante (no pausa,
##   en cola). Admite {apodo}, {puntos} e {icono:<id>}.
## - point_help {object, radius_tiles, text}: con Isak cerca, si la ayuda Q de
##   esa pieza va a salir (Eco conocido, ayudas visibles, tipo sin aprender) deja
##   que la Q haga su trabajo (Eco vuela y brilla, el jugador la pide: pausa) y
##   espera a que el tipo se aprenda o la pieza se haga; si no va a salir (tipo
##   ya aprendido o «Ayudas de Eco: Ocultar») Eco vuela a la pieza y dice `text`
##   (no importante).
## Reglas: es HISTORIA, asi que sale aunque las ayudas esten ocultas. Las
## acciones solo se ejecutan con Isak con control (vivo y fuera de un vortice):
## al morir o reaparecer el guion espera, y Eco suelta el punto (lo hace el
## companero); las esperas miran el estado del mundo, que no se pierde al
## reaparecer. Con el arbol en pausa no avanza. Inerte si Eco no es conocido o
## si done_if_ally ya es conocido al cargar (no se repite: objetos de un solo
## uso). Sin companero (escenas de prueba), las lineas salen igual y los vuelos
## no hacen nada.
class_name EcoGuide
extends Node2D

const GROUP: StringName = &"eco_guide"
const DATA_PATH: String = "res://data/eco_guides.json"
const ACTIONS: Array[String] = ["wait_near", "wait_inside", "wait_done", "wait_ability", "wait_s", "wait_quiet",
	"fly", "back", "line", "point_help"]

## Empieza el paso `index` (pruebas y capturas).
signal step_started(index: int, step: Dictionary)
## El guion termino.
signal finished

@export var object_id: StringName = &""
@export var guide_id: StringName = &""
@export var done_if_ally: StringName = &""

var _steps: Array = []
var _index: int = 0
var _inert: bool = false
var _done: bool = false
var _wait_s: float = 0.0
## Paso en curso ya preparado (contadores a cero, senales escuchadas).
var _entered: bool = false
var _ability_used: bool = false
## point_help: fase (0 = esperando a Isak, 1 = esperando a que se aprenda).
var _help_phase: int = 0


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Pasos del guion `id` de data/eco_guides.json (vacio si no existe).
static func steps_of(id: StringName) -> Array:
	var guide: Variant = load_data().get("guides", {}).get(String(id), {})
	return (guide as Dictionary).get("steps", []) if guide is Dictionary else []


func _ready() -> void:
	add_to_group(GROUP)
	_steps = steps_of(guide_id)
	if _steps.is_empty():
		push_warning("EcoGuide %s: no hay guion '%s' en %s" % [object_id, guide_id, DATA_PATH])
	_inert = _steps.is_empty() or CalcRoom.skipped_for(done_if_ally) \
		or not GameState.has_met_ally(GameState.ALLY_ECO)
	if _inert:
		_done = true
	EventBus.pulse_fired.connect(_on_pulse)
	EventBus.laser_fired.connect(_on_laser)
	EventBus.debug_mode_changed.connect(_on_debug)


func _exit_tree() -> void:
	var eco: EcoCompanion = get_eco()
	if eco != null:
		eco.clear_guide_point()


func _process(delta: float) -> void:
	advance(delta)


# --- Consultas ---

func is_inert() -> bool:
	return _inert


func is_finished() -> bool:
	return _done


## Indice del paso en curso (== numero de pasos al terminar).
func get_step_index() -> int:
	return _index


func get_step_count() -> int:
	return _steps.size()


func get_current_action() -> String:
	return String((_steps[_index] as Dictionary).get("do", "")) if _index < _steps.size() else ""


## Cuadro de texto del nivel (hijo «EcoTextBox» del nivel o de un antepasado).
func get_text_box() -> EcoTextBox:
	var n: Node = get_parent()
	while n != null:
		var box := n.get_node_or_null(^"EcoTextBox") as EcoTextBox
		if box != null:
			return box
		n = n.get_parent()
	return null


func get_eco() -> EcoCompanion:
	var scope: Node = get_parent()
	while scope != null and not (scope is GeneratedLevel):
		scope = scope.get_parent()
	for node: Node in get_tree().get_nodes_in_group(EcoCompanion.GROUP):
		if node is EcoCompanion and (scope == null or scope.is_ancestor_of(node)):
			return node as EcoCompanion
	return null


# --- Avance ---

## Avanza el guion `delta` segundos de juego (lo llama _process). Ejecuta
## seguidas todas las acciones instantaneas hasta la siguiente espera.
func advance(delta: float) -> void:
	if _done or get_tree().paused:
		return
	var guard: int = 0
	while not _done and guard < 64:
		guard += 1
		if _index >= _steps.size():
			_finish()
			return
		var step: Dictionary = _steps[_index]
		if not _entered:
			_entered = true
			_wait_s = 0.0
			_ability_used = false
			_help_phase = 0
			step_started.emit(_index, step)
		if not _run(step, delta):
			return
		delta = 0.0
		_index += 1
		_entered = false


## Ejecuta o comprueba el paso; verdadero si ya se cumplio.
func _run(step: Dictionary, delta: float) -> bool:
	var action: String = String(step.get("do", ""))
	var isak: Isak = CalcRoom.find_isak(self)
	var has_control: bool = isak != null and not isak.is_dead() and not isak.is_warping()
	match action:
		"wait_near":
			var node := _node(step)
			return has_control and node != null and isak.global_position.distance_to(_center_of(node)) \
				<= float(step.get("radius_tiles", 3.0)) * World1ObjectsConfig.tile_size()
		"wait_inside":
			var node := _node(step)
			return has_control and node != null and node.has_method(&"get_room_rect") \
				and (node.call(&"get_room_rect") as Rect2).has_point(isak.global_position - Vector2(0.0, 8.0))
		"wait_done":
			return CalcRoom.is_done(_node(step))
		"wait_ability":
			return _ability_used
		"wait_s":
			_wait_s += maxf(delta, 0.0)
			return _wait_s >= float(step.get("seconds", 1.0))
		"wait_quiet":
			_wait_s += maxf(delta, 0.0)
			var box: EcoTextBox = get_text_box()
			return box == null or (not box.is_showing() and box.get_queue_size() == 0) \
				or _wait_s >= float(step.get("max_s", 15.0))
	if not has_control:
		return false  # Las acciones esperan a que Isak tenga el control.
	match action:
		"fly":
			var eco: EcoCompanion = get_eco()
			if eco != null:
				eco.set_guide_point(_fly_point(step))
			return true
		"back":
			var eco: EcoCompanion = get_eco()
			if eco != null:
				eco.clear_guide_point()
			return true
		"line":
			EventBus.eco_line_requested.emit(String(step.get("text", "")), float(step.get("duration_s", -1.0)),
				bool(step.get("important", false)))
			return true
		"point_help":
			return _point_help(step, isak)
	push_warning("EcoGuide %s: accion desconocida '%s'" % [guide_id, action])
	return true


func _point_help(step: Dictionary, isak: Isak) -> bool:
	var node := _node(step)
	if node == null or CalcRoom.is_done(node):
		return true
	var help_id: StringName = HelpCatalog.help_id_of(node)
	if _help_phase == 1:
		return GameState.is_help_learned(help_id)
	if isak.global_position.distance_to(_center_of(node)) > float(step.get("radius_tiles", 3.0)) \
			* World1ObjectsConfig.tile_size():
		return false
	if q_will_show(node):
		_help_phase = 1
		return false
	var eco: EcoCompanion = get_eco()
	if eco != null:
		eco.set_guide_point(_fly_point(step))
	EventBus.eco_line_requested.emit(String(step.get("text", "")), -1.0, false)
	return true


## La ayuda Q de `node` saldra (Eco conocido, ayudas visibles, tipo con texto
## sin aprender y la pieza aun ayuda).
static func q_will_show(node: Node) -> bool:
	var help_id: StringName = HelpCatalog.help_id_of(node)
	return help_id != &"" and HelpCatalog.shared().has(help_id) and GameState.has_met_ally(GameState.ALLY_ECO) \
		and GameSettings.is_eco_help_shown() and not GameState.is_help_learned(help_id) \
		and HelpCatalog.is_help_live(node)


func _finish() -> void:
	_done = true
	var eco: EcoCompanion = get_eco()
	if eco != null:
		eco.clear_guide_point()
	finished.emit()


func _node(step: Dictionary) -> Node2D:
	return CalcRoom.find(self, StringName(String(step.get("object", "")))) as Node2D


func _center_of(node: Node2D) -> Vector2:
	if node.has_method(&"get_outline_rect"):
		return (node.call(&"get_outline_rect") as Rect2).get_center()
	if node.has_method(&"get_hit_rect"):
		return (node.call(&"get_hit_rect") as Rect2).get_center()
	if node.has_method(&"get_world_rect"):
		return (node.call(&"get_world_rect") as Rect2).get_center()
	if node.has_method(&"get_room_rect"):
		return (node.call(&"get_room_rect") as Rect2).get_center()
	return node.global_position


## Punto de vuelo: encima de la pieza (offset_px, por defecto [0, -72] desde su
## centro) o el centro de la celda `cell`.
func _fly_point(step: Dictionary) -> Vector2:
	var t: float = World1ObjectsConfig.tile_size()
	var offset: Vector2 = LaserReceiver._vec(step.get("offset_px", [0, -72]))
	if step.has("cell"):
		var c: Array = step["cell"]
		return Vector2((float(c[0]) + 0.5) * t, (float(c[1]) + 0.5) * t) + offset
	var node := _node(step)
	return (_center_of(node) if node != null else global_position) + offset


func _on_pulse(_area: Area2D) -> void:
	_mark_ability(&"pulse")


func _on_laser(_projectile: Node2D) -> void:
	_mark_ability(&"laser")


func _on_debug(active: bool) -> void:
	if active:
		_mark_ability(&"debug")


func _mark_ability(ability: StringName) -> void:
	if _done or _index >= _steps.size() or not _entered:
		return
	var step: Dictionary = _steps[_index]
	if String(step.get("do", "")) == "wait_ability" and StringName(String(step.get("ability", ""))) == ability:
		_ability_used = true
