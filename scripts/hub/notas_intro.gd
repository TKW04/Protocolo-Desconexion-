## Presentacion de Notas la primera vez que Isak entra al hub
## (docs/propuesta-asistentes-y-vidas.md §2.2 y §4, paso 8 de §10; textos en la
## seccion notas_intro de data/hub.json). Sustituye al tutorial de guardado B + C.
## Momento de historia: lo crea HubRoom si "notas" no esta en
## GameState.allies_met y empieza al terminar la llegada de Isak (start()). Pausa
## el arbol de principio a fin (como EcoEncounter) y pide al cuadro de texto del
## hub (EcoTextBox) lineas importantes:
## 1. `eco`: Eco (atenuado, sin cobertura: solo habla para esto) presenta a
##    Notas. Si Eco aun no es conocido (hub abierto con una partida nueva), se
##    omite.
## 2. Notas se enciende (NotasStation.set_powered(true) y destello).
## 3. `notas`: Notas habla con su nombre e icono (speaker "notas"): que guarda y
##    que si se cierra sin guardar se pierde.
## Al cerrarse la ultima, Notas queda conocida (GameState.meet_ally("notas"); no
## marca «sin guardar») y ya no se repite. Con EcoTextBox.pause_important en
## false (pruebas y herramientas) no pausa y las lineas se cierran solas. La pausa
## se libera siempre al salir del arbol.
class_name NotasIntro
extends Node

enum Step { WAITING, ECO, NOTAS, DONE }

## Cambia de paso (pruebas, capturas y bot).
signal step_changed(step: Step)
## Termina la presentacion: Notas encendida y conocida.
signal finished

var station: NotasStation
var text_box: EcoTextBox

var _data: Dictionary = HubData.section("notas_intro")
var _step: Step = Step.WAITING
var _pending: int = 0
var _owns_pause: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_release_pause()


func get_step() -> Step:
	return _step


func is_running() -> bool:
	return _step == Step.ECO or _step == Step.NOTAS


func is_done() -> bool:
	return _step == Step.DONE


## Textos de `key` (eco o notas) de la seccion notas_intro.
func get_lines(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = _data.get(key, [])
	if raw is Array:
		for text: Variant in raw:
			if not String(text).is_empty():
				out.append(String(text))
	return out


## Empieza la presentacion. Falso si ya empezo o Notas ya es conocida.
func start() -> bool:
	if _step != Step.WAITING or GameState.has_met_ally(GameState.ALLY_NOTAS) or text_box == null:
		return false
	_hold_pause()
	text_box.line_finished.connect(_on_line_finished)
	var eco: PackedStringArray = get_lines("eco") if GameState.has_met_ally(GameState.ALLY_ECO) else PackedStringArray()
	if eco.is_empty():
		_power_on_and_talk()
	else:
		_say(Step.ECO, eco, &"")
	return true


func _say(step: Step, texts: PackedStringArray, speaker: StringName) -> void:
	_step = step
	step_changed.emit(step)
	_pending = texts.size()
	var duration: float = float(_data.get("duration_s", -1.0))
	for text: String in texts:
		text_box.show_line(text, duration, true, speaker)
	if _pending == 0:
		_next.call_deferred()


func _on_line_finished(_speaker: StringName) -> void:
	if not is_running():
		return
	_pending -= 1
	if _pending <= 0:
		# Diferido: el cuadro emite line_finished antes de empezar la siguiente.
		_next.call_deferred()


func _next() -> void:
	if not is_inside_tree():
		return
	match _step:
		Step.ECO:
			_power_on_and_talk()
		Step.NOTAS:
			_finish()


func _power_on_and_talk() -> void:
	if station != null and is_instance_valid(station):
		station.set_powered(true)
		station.flash(float(_data.get("power_on_flash_s", 0.3)))
	_say(Step.NOTAS, get_lines("notas"), StringName(String(_data.get("speaker", "notas"))))


func _finish() -> void:
	_step = Step.DONE
	if text_box != null and text_box.line_finished.is_connected(_on_line_finished):
		text_box.line_finished.disconnect(_on_line_finished)
	GameState.meet_ally(GameState.ALLY_NOTAS)
	_release_pause()
	step_changed.emit(_step)
	finished.emit()


func _hold_pause() -> void:
	if _owns_pause or not EcoTextBox.pause_important or not is_inside_tree() or get_tree().paused:
		return
	get_tree().paused = true
	_owns_pause = true


func _release_pause() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	if is_inside_tree():
		get_tree().paused = false
