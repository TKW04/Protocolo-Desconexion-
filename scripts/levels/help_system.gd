## Ayuda de Eco con Q por tipo (docs/propuesta-asistentes-y-vidas.md §3, paso 3
## de §10; datos en data/help.json, ver HelpCatalog).
## - Con Eco conocido (GameState.has_met_ally("eco")), busca entre los objetos
##   del nivel apuntados a la ayuda (grupo HelpCatalog.TARGET_GROUP, metadato
##   help_id) el mas cercano al centro de Isak cuyo tipo no se ha aprendido,
##   dentro de su radio y en pantalla (el candidato: HelpSystem es la fuente de
##   verdad), y muestra una Q (HelpPrompt). Una sola Q a la vez.
## - Eco lleva la Q (2026-10-16, decision del usuario): el candidato se le pasa
##   al companero del nivel (EcoCompanion.set_help_target), que vuela junto al
##   objeto y brilla en ambar; la Q se dibuja SOBRE ECO
##   (EcoCompanion.get_prompt_position) y lo sigue mientras se mueve. Si no hay
##   companero visible (escenas de prueba sin Eco), la Q va sobre el objeto
##   como antes. Al pedir la ayuda, Eco se queda brillando mientras explica
##   (begin_help_explanation) y vuelve a Isak al cerrar la linea. Sin Isak con control (muerto, en un vortice o de espaldas)
##   o con el juego en pausa no hay Q.
## - Al pulsar la accion help con una Q visible: el tipo queda aprendido
##   (GameState.learn_help; ninguna otra instancia de ese tipo vuelve a mostrar
##   la Q) y Eco lo explica en su cuadro como linea IMPORTANTE
##   (EventBus.eco_line_requested): el cuadro pausa el arbol hasta que el
##   jugador la cierra con saltar / ui_accept (la primera pulsacion completa el
##   texto) y la pausa se libera siempre al salir el cuadro del arbol (cambio de
##   escena, nivel quitado). Sin Q visible, help no hace nada.
## - No toca la logica de los objetos: funcionan igual con Q o sin ella.
## - Eco se conoce en el encuentro del 1-1 (EcoEncounter, paso 6): hasta
##   entonces no hay Q. (La regla provisional que lo daba por conocido en cuanto
##   hablaba por primera vez se retiro con el encuentro.)
## - Ajuste «Ayudas de Eco: Ocultar» (GameSettings, menu de pausa; paso 13):
##   no sale ninguna Q y help no hace nada, asi que ningun tipo se aprende sin
##   pedirlo; lo aprendido sigue en el album y la historia de Eco no cambia.
## - RELECTURA (2026-10-16, decision del usuario; seccion reread de
##   data/help.json): si no hay ningun candidato sin aprender, cerca de un
##   objeto de un tipo YA aprendido sale una Q pequena y apagada (HelpPrompt,
##   estilo REREAD) SOBRE EL OBJETO (Eco no vuela ni brilla: eso es solo del
##   primer encuentro), y solo con Isak quieto (velocidad < still_speed_px_s)
##   still_s segundos de juego dentro del radio del tipo; al moverse
##   desaparece. Una sola, la del mas cercano. Pulsar help abre la misma
##   explicacion (linea importante: misma pausa y mismo cuadro) sin aprender
##   nada (learned_help no cambia; EventBus.help_reread). Mismas condiciones
##   que la Q normal: Eco conocido, «Ayudas de Eco: Mostrar», Isak con control
##   y sin pausa. Se dibuja en la misma capa que la Q.
## La Q se dibuja en un CanvasLayer propio que sigue a la camara
## (follow_viewport, como el punto debil): por encima del mundo y del tinte del
## Debug y por debajo del HUD y del cuadro de Eco (layer de la seccion prompt).
## El generador de niveles (tools/build_level.py) lo pone en cada nivel como
## nodo «Help», hermano de Isak.
class_name HelpSystem
extends Node

## El jugador ha pedido ayuda sobre un objeto del tipo `help_id`.
signal help_shown(help_id: StringName, text: String)
## El jugador ha vuelto a leer la ayuda de un tipo ya aprendido (Q apagada).
signal help_reread(help_id: StringName, text: String)

## Capa por defecto de la Q (entre el Debug, 5, y el HUD, 10).
const DEFAULT_LAYER: int = 6
## Se procesa despues de Eco (prioridad 0): la Q usa su posicion de este cuadro.
const PROCESS_PRIORITY: int = 10

@export var isak_path: NodePath = ^"../Isak"

var _catalog: HelpCatalog = HelpCatalog.shared()
var _layer: CanvasLayer
var _prompt: HelpPrompt
var _target: Node2D
var _reread_prompt: HelpPrompt
var _reread_target: Node2D
## Segundos de juego que Isak lleva quieto (relectura).
var _still_s: float = 0.0
var _eco: EcoCompanion


func _ready() -> void:
	# Tiempo real: con el arbol en pausa (menu de pausa, ayuda abierta) quita la
	# Q y suelta a Eco, que vuelve a Isak (no se queda junto al objeto).
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = PROCESS_PRIORITY
	_layer = CanvasLayer.new()
	_layer.name = "PromptLayer"
	_layer.layer = int(_catalog.prompt_config().get("layer", DEFAULT_LAYER))
	_layer.follow_viewport_enabled = true
	add_child(_layer)
	_prompt = HelpPrompt.new()
	_prompt.visible = false
	_layer.add_child(_prompt)
	_reread_prompt = HelpPrompt.new(HelpPrompt.Style.REREAD)
	_reread_prompt.visible = false
	_layer.add_child(_reread_prompt)
	EventBus.help_learned.connect(_on_help_learned)


func _exit_tree() -> void:
	if EventBus.help_learned.is_connected(_on_help_learned):
		EventBus.help_learned.disconnect(_on_help_learned)


func _process(delta: float) -> void:
	update_still(delta)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not InputMap.has_action(_catalog.action()):
		return
	if event.is_action_pressed(_catalog.action()) and request_help():
		get_viewport().set_input_as_handled()


# --- API ---

## Recalcula el objeto con Q y coloca el icono. Lo llama _process.
func refresh() -> void:
	# Con el juego en pausa (linea importante, ayuda abierta) no hay Q.
	var previous: Node2D = _target
	_target = null if get_tree().paused else find_target()
	if _target != null and _target != previous:
		EventBus.help_prompt_shown.emit(_target)
	var eco: EcoCompanion = get_eco()
	if eco != null:
		eco.set_help_target(_target, HelpCatalog.help_id_of(_target) if _target != null else &"")
	_prompt.visible = _target != null
	if _target != null:
		if is_prompt_on_eco():
			_prompt.global_position = eco.get_prompt_position().round()
		else:
			_prompt.global_position = (_target.global_position
				+ _catalog.prompt_offset(HelpCatalog.help_id_of(_target))).round()
	# Relectura: solo sin candidato sin aprender (la Q normal va primero).
	_reread_target = null if _target != null or get_tree().paused else find_reread_target()
	_reread_prompt.visible = _reread_target != null
	if _reread_target != null:
		_reread_prompt.global_position = (_reread_target.global_position
			+ _catalog.prompt_offset(HelpCatalog.help_id_of(_reread_target))).round()


## Cuenta el tiempo que Isak lleva quieto (relectura). Con el juego en pausa
## no avanza; al moverse (o sin Isak con control) vuelve a 0.
func update_still(delta: float) -> void:
	if get_tree().paused:
		return
	var isak: Isak = _controlled_isak()
	if isak == null or isak.velocity.length() >= _catalog.reread_still_speed():
		_still_s = 0.0
	else:
		_still_s += delta


## Segundos que Isak lleva quieto.
func get_still_s() -> float:
	return _still_s


## Pide la ayuda del objeto con Q (accion help). Falso si no hay Q visible.
## Con la Q apagada (relectura), vuelve a explicar el tipo sin aprender nada.
func request_help() -> bool:
	if get_tree().paused:
		return false
	if (_target == null or not is_instance_valid(_target)) and _reread_target != null \
			and is_instance_valid(_reread_target):
		return _request_reread()
	if _target == null or not is_instance_valid(_target):
		return false
	var help_id: StringName = HelpCatalog.help_id_of(_target)
	var text: String = _catalog.text(help_id)
	if text.is_empty():
		return false
	_target = null
	_prompt.visible = false
	# Eco se queda junto al objeto, brillando, mientras explica.
	var eco: EcoCompanion = get_eco()
	if eco != null:
		eco.begin_help_explanation()
	# Primero la linea (pausa el juego) y despues aprender: asi el refresco que
	# provoca help_learned ya no pone la Q sobre otro objeto durante la pausa.
	EventBus.eco_line_requested.emit(text, -1.0, true)
	GameState.learn_help(help_id)
	help_shown.emit(help_id, text)
	return true


## Relectura: misma linea importante (misma pausa, mismo cuadro), sin aprender
## y sin que Eco vuele ni brille.
func _request_reread() -> bool:
	var help_id: StringName = HelpCatalog.help_id_of(_reread_target)
	var text: String = _catalog.text(help_id)
	if text.is_empty():
		return false
	_reread_target = null
	_reread_prompt.visible = false
	# Al cerrar, la Q apagada vuelve solo tras otro rato quieto.
	_still_s = 0.0
	EventBus.eco_line_requested.emit(text, -1.0, true)
	EventBus.help_reread.emit(help_id)
	help_reread.emit(help_id, text)
	return true


## Objeto con la Q apagada de relectura ahora (null si no hay).
func get_reread_target() -> Node2D:
	return _reread_target if _reread_target != null and is_instance_valid(_reread_target) else null


func is_reread_visible() -> bool:
	return _reread_prompt.visible


func get_reread_prompt() -> HelpPrompt:
	return _reread_prompt


## Objeto con Q visible ahora (null si no hay).
func get_target() -> Node2D:
	return _target if _target != null and is_instance_valid(_target) else null


func is_prompt_visible() -> bool:
	return _prompt.visible


func get_prompt() -> HelpPrompt:
	return _prompt


## Companero Eco de este nivel (null si no hay).
func get_eco() -> EcoCompanion:
	if _eco != null and is_instance_valid(_eco) and _eco.is_inside_tree():
		return _eco
	_eco = null
	var scope: Node = get_parent()
	for node: Node in get_tree().get_nodes_in_group(EcoCompanion.GROUP):
		if node is EcoCompanion and (scope == null or scope.is_ancestor_of(node)):
			_eco = node as EcoCompanion
			break
	return _eco


## La Q visible va sobre Eco (y no sobre el objeto).
func is_prompt_on_eco() -> bool:
	var eco: EcoCompanion = get_eco()
	return _target != null and eco != null and eco.is_shown() and eco.get_help_target() == _target


## El objeto no aprendido mas cercano a Isak dentro de su radio y en pantalla.
func find_target() -> Node2D:
	return _find_nearest(false)


## Relectura: el objeto de un tipo YA aprendido mas cercano a Isak dentro de su
## radio y en pantalla, solo con Isak quieto still_s segundos (null si no).
func find_reread_target() -> Node2D:
	if _still_s < _catalog.reread_still_s():
		return null
	return _find_nearest(true)


## Isak con control (visible, vivo, fuera de un vortice y de lado) o null.
func _controlled_isak() -> Isak:
	var isak := get_node_or_null(isak_path) as Isak
	if isak == null or not isak.is_inside_tree() or not isak.visible or isak.is_dead() \
			or isak.is_warping() or isak.is_facing_back():
		return null
	return isak


## El objeto mas cercano cuyo tipo esta aprendido (`learned`) o no.
func _find_nearest(learned: bool) -> Node2D:
	if not GameState.has_met_ally(GameState.ALLY_ECO) or not GameSettings.is_eco_help_shown():
		return null
	var isak: Isak = _controlled_isak()
	if isak == null:
		return null
	var from: Vector2 = isak.global_position + Vector2(0.0, _catalog.isak_center_y())
	var screen: Rect2 = _visible_world_rect()
	var scope: Node = get_parent()
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(HelpCatalog.TARGET_GROUP):
		var item := node as Node2D
		if item == null or not item.is_visible_in_tree() or (scope != null and not scope.is_ancestor_of(item)):
			continue
		var help_id: StringName = HelpCatalog.help_id_of(item)
		if GameState.is_help_learned(help_id) != learned or not _catalog.has(help_id):
			continue
		var center: Vector2 = item.global_position + _catalog.center_offset(help_id)
		var distance: float = from.distance_to(center)
		if distance > _catalog.radius_px(help_id) or distance >= best_distance or not screen.has_point(center):
			continue
		best = item
		best_distance = distance
	return best


func _visible_world_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	var view := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	return viewport.get_canvas_transform().affine_inverse() * view


func _on_help_learned(_help_id: StringName) -> void:
	refresh()
