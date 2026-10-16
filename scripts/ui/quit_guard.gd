## Aviso al salir con cambios sin guardar (decision del usuario 2026-10-15,
## docs/propuesta-hub-y-guardado.md §4.4). GameState lo crea en el juego normal
## (no en GUT ni con -s) y desactiva auto_accept_quit: al cerrar la ventana
## (NOTIFICATION_WM_CLOSE_REQUEST) decide con decide():
## - sin cambios sin guardar: sale ya;
## - con cambios, donde se puede guardar (un nodo del grupo SAVE_STATION_GROUP
##   con can_save_now() verdadero; hoy el hub real, HubRoom):
##   «Guardar y salir / Salir sin guardar / Volver»;
## - con cambios en un nivel: «Salir / Volver» (fuera del hub no se guarda).
## El aviso (QuitPrompt) pausa el arbol mientras esta abierto y lo deja como
## estaba al volver. La regla no cambia: lo no guardado se pierde al salir.
class_name QuitGuard
extends Node

## Que hacer ante una peticion de cierre.
enum Decision { QUIT, ASK_WITH_SAVE, ASK_WITHOUT_SAVE }
## Lo que elige el jugador en el aviso.
enum Choice { SAVE_AND_QUIT, QUIT, BACK }

## Grupo de los nodos donde se puede guardar (implementan can_save_now()).
const SAVE_STATION_GROUP: StringName = &"save_station"

## Se abre el aviso (`decision` es ASK_WITH_SAVE o ASK_WITHOUT_SAVE).
signal prompt_opened(decision: Decision)
## Se cierra el aviso con Volver.
signal prompt_closed

## Funcion que cierra el juego (las pruebas la sustituyen). Por defecto
## get_tree().quit().
var quit_handler: Callable = Callable()

var _prompt: QuitPrompt
var _paused_before: bool = false


## Decision pura (sin ventana): ver la cabecera.
static func decide(has_unsaved_changes: bool, can_save_here: bool) -> Decision:
	if not has_unsaved_changes:
		return Decision.QUIT
	return Decision.ASK_WITH_SAVE if can_save_here else Decision.ASK_WITHOUT_SAVE


## Opciones del aviso para `decision`, en orden de pantalla (vacio si QUIT).
static func choices_for(decision: Decision) -> Array[Choice]:
	match decision:
		Decision.ASK_WITH_SAVE:
			return [Choice.SAVE_AND_QUIT, Choice.QUIT, Choice.BACK]
		Decision.ASK_WITHOUT_SAVE:
			return [Choice.QUIT, Choice.BACK]
	return []


## Verdadero si algun nodo del grupo SAVE_STATION_GROUP permite guardar ahora.
static func can_save_here(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(SAVE_STATION_GROUP):
		if node.has_method(&"can_save_now") and bool(node.call(&"can_save_now")):
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		handle_close_request()


## Atiende una peticion de cierre. Devuelve la decision tomada. Con el aviso
## ya abierto no hace nada (devuelve la decision del aviso abierto).
func handle_close_request() -> Decision:
	if is_prompt_open():
		return _prompt.get_decision()
	var decision: Decision = decide(GameState.has_unsaved_changes(), can_save_here(get_tree()))
	if decision == Decision.QUIT:
		_quit()
	else:
		_open_prompt(decision)
	return decision


func is_prompt_open() -> bool:
	return is_instance_valid(_prompt)


func get_prompt() -> QuitPrompt:
	return _prompt if is_prompt_open() else null


## Aplica la opcion `choice` del aviso abierto. SAVE_AND_QUIT guarda
## (GameState.save_game) y sale; si no se pudo guardar, el aviso sigue abierto
## con un mensaje. Devuelve verdadero si el juego se cierra.
func choose(choice: Choice) -> bool:
	match choice:
		Choice.SAVE_AND_QUIT:
			if not GameState.save_game():
				if is_prompt_open():
					_prompt.show_save_failed()
				return false
			_quit()
			return true
		Choice.QUIT:
			_quit()
			return true
	_close_prompt()
	return false


func _open_prompt(decision: Decision) -> void:
	_paused_before = get_tree().paused
	_prompt = QuitPrompt.new()
	_prompt.setup(decision, choices_for(decision))
	_prompt.chosen.connect(choose)
	add_child(_prompt)
	get_tree().paused = true
	prompt_opened.emit(decision)


func _close_prompt() -> void:
	if is_prompt_open():
		_prompt.queue_free()
		remove_child(_prompt)
	_prompt = null
	get_tree().paused = _paused_before
	prompt_closed.emit()


func _quit() -> void:
	if quit_handler.is_valid():
		quit_handler.call()
	else:
		get_tree().quit()
