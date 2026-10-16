## Ayuda de Eco con Q por tipo (docs/propuesta-asistentes-y-vidas.md §3, paso 3
## de §10; datos en data/help.json, ver HelpCatalog).
## - Con Eco conocido (GameState.has_met_ally("eco")), busca entre los objetos
##   del nivel apuntados a la ayuda (grupo HelpCatalog.TARGET_GROUP, metadato
##   help_id) el mas cercano al centro de Isak cuyo tipo no se ha aprendido,
##   dentro de su radio y en pantalla, y pone sobre el una Q (HelpPrompt). Una
##   sola Q a la vez. Sin Isak con control (muerto, en un vortice o de espaldas)
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
## La Q se dibuja en un CanvasLayer propio que sigue a la camara
## (follow_viewport, como el punto debil): por encima del mundo y del tinte del
## Debug y por debajo del HUD y del cuadro de Eco (layer de la seccion prompt).
## El generador de niveles (tools/build_level.py) lo pone en cada nivel como
## nodo «Help», hermano de Isak.
class_name HelpSystem
extends Node

## El jugador ha pedido ayuda sobre un objeto del tipo `help_id`.
signal help_shown(help_id: StringName, text: String)

## Capa por defecto de la Q (entre el Debug, 5, y el HUD, 10).
const DEFAULT_LAYER: int = 6

@export var isak_path: NodePath = ^"../Isak"

var _catalog: HelpCatalog = HelpCatalog.shared()
var _layer: CanvasLayer
var _prompt: HelpPrompt
var _target: Node2D


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PromptLayer"
	_layer.layer = int(_catalog.prompt_config().get("layer", DEFAULT_LAYER))
	_layer.follow_viewport_enabled = true
	add_child(_layer)
	_prompt = HelpPrompt.new()
	_prompt.visible = false
	_layer.add_child(_prompt)
	EventBus.help_learned.connect(_on_help_learned)


func _exit_tree() -> void:
	if EventBus.help_learned.is_connected(_on_help_learned):
		EventBus.help_learned.disconnect(_on_help_learned)


func _process(_delta: float) -> void:
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
	_prompt.visible = _target != null
	if _target != null:
		_prompt.global_position = (_target.global_position
			+ _catalog.prompt_offset(HelpCatalog.help_id_of(_target))).round()


## Pide la ayuda del objeto con Q (accion help). Falso si no hay Q visible.
func request_help() -> bool:
	if _target == null or not is_instance_valid(_target) or get_tree().paused:
		return false
	var help_id: StringName = HelpCatalog.help_id_of(_target)
	var text: String = _catalog.text(help_id)
	if text.is_empty():
		return false
	_target = null
	_prompt.visible = false
	# Primero la linea (pausa el juego) y despues aprender: asi el refresco que
	# provoca help_learned ya no pone la Q sobre otro objeto durante la pausa.
	EventBus.eco_line_requested.emit(text, -1.0, true)
	GameState.learn_help(help_id)
	help_shown.emit(help_id, text)
	return true


## Objeto con Q visible ahora (null si no hay).
func get_target() -> Node2D:
	return _target if _target != null and is_instance_valid(_target) else null


func is_prompt_visible() -> bool:
	return _prompt.visible


func get_prompt() -> HelpPrompt:
	return _prompt


## El objeto no aprendido mas cercano a Isak dentro de su radio y en pantalla.
func find_target() -> Node2D:
	if not GameState.has_met_ally(GameState.ALLY_ECO) or not GameSettings.is_eco_help_shown():
		return null
	var isak := get_node_or_null(isak_path) as Isak
	if isak == null or not isak.is_inside_tree() or not isak.visible or isak.is_dead() \
			or isak.is_warping() or isak.is_facing_back():
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
		if GameState.is_help_learned(help_id) or not _catalog.has(help_id):
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
