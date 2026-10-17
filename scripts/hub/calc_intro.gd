## Encuentro con Calc en el hub (2026-10-17, tanda H3 del paso 14 de
## docs/propuesta-1-2.md; diseno en docs/propuesta-calc-encuentro.md §6, historia
## «Resta»; textos en data/calc_intro.json). Solo texto: sin voz ni sonido.
## Lo crea HubRoom si Calc se teletransporto al hub en esta sesion (azotea del
## 1-2: EventBus.ally_teleported -> GameState.ally_arrivals) y aun no es
## conocida; Calc ya esta en su estacion, despierta (CalcStation.set_arrived) y
## sin tienda. Empieza al terminar la llegada de Isak (o tras la presentacion de
## Notas, si toca): pausa el arbol de principio a fin (como NotasIntro; convencion
## de pausas anidadas: solo pausa si nadie lo habia hecho y solo quita su pausa)
## y pide al cuadro de texto del hub (EcoTextBox) las lineas de `lines` UNA A
## UNA, importantes:
## - `calc`: Calc habla con su nombre, icono y estilo LCD (speaker "calc" de
##   data/eco_text_box.json); {puntos} es el saldo actual al empezar la linea.
## - `eco`: Eco (atenuado, sin cobertura) se descuelga entre las de Calc. Si Eco
##   no es conocido, se omite.
## Al cerrarse la ultima: GameState.meet_ally("calc") (EventBus.ally_met: HubRoom
## enciende la estacion y la tienda queda disponible; la tienda no cambia),
## destello de la estacion, «sin guardar» (GameState.request_save: conocer a Calc
## es progreso que se guarda en Notas) y la llegada pendiente se consume
## (GameState.clear_ally_arrival): no se repite. Con EcoTextBox.pause_important
## en false (pruebas y herramientas) no pausa y las lineas se cierran solas. La
## pausa se libera siempre al salir del arbol. Es historia: sale aunque las
## ayudas de Eco esten ocultas.
class_name CalcIntro
extends Node

enum Step { WAITING, CALC, ECO, DONE }

const DATA_PATH: String = "res://data/calc_intro.json"
const WHO_CALC: String = "calc"
const WHO_ECO: String = "eco"

## Cambia de paso (pruebas, capturas y herramientas).
signal step_changed(step: Step)
## Empieza la linea `index` de lines() (pruebas y capturas).
signal line_shown(index: int, who: String)
## Termina el encuentro: Calc conocida y su estacion encendida.
signal finished

var station: CalcStation
var text_box: EcoTextBox

var _data: Dictionary = {}
var _step: Step = Step.WAITING
var _index: int = -1
var _lines: Array[Dictionary] = []
var _owns_pause: bool = false


func _init() -> void:
	_data = load_data()
	for entry: Variant in _data.get("lines", []):
		if entry is Dictionary and not String((entry as Dictionary).get("text", "")).is_empty():
			_lines.append(entry)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_release_pause()


## Datos de data/calc_intro.json (vacio si no se puede leer).
static func load_data() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return data if data is Dictionary else {}


## El encuentro toca al llegar al hub: Calc se teletransporto y no es conocida.
static func is_pending() -> bool:
	return GameState.is_ally_arrival_pending(GameState.ALLY_CALC)


func get_step() -> Step:
	return _step


func is_running() -> bool:
	return _step == Step.CALC or _step == Step.ECO


func is_done() -> bool:
	return _step == Step.DONE


## Lineas que van a salir ({who, text}; sin la de Eco si Eco no es conocido).
func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var eco_known: bool = GameState.has_met_ally(GameState.ALLY_ECO)
	for entry: Dictionary in _lines:
		if String(entry.get("who", WHO_CALC)) == WHO_ECO and not eco_known:
			continue
		out.append(entry)
	return out


## Indice (en lines()) de la linea en pantalla; -1 si ninguna.
func get_line_index() -> int:
	return _index


## Empieza el encuentro. Falso si ya empezo, Calc ya es conocida o no hay cuadro.
func start() -> bool:
	if _step != Step.WAITING or GameState.has_met_ally(GameState.ALLY_CALC) or text_box == null:
		return false
	_hold_pause()
	text_box.line_finished.connect(_on_line_finished)
	if station != null and is_instance_valid(station):
		station.set_arrived(true)
	_index = -1
	_show_next()
	return true


func _show_next() -> void:
	var all: Array[Dictionary] = lines()
	_index += 1
	if _index >= all.size():
		_finish()
		return
	var entry: Dictionary = all[_index]
	var who: String = String(entry.get("who", WHO_CALC))
	var step: Step = Step.ECO if who == WHO_ECO else Step.CALC
	if step != _step:
		_step = step
		step_changed.emit(step)
	line_shown.emit(_index, who)
	var speaker := StringName(String(_data.get("speaker", WHO_CALC))) if step == Step.CALC else &""
	text_box.show_line(String(entry.get("text", "")), float(_data.get("duration_s", -1.0)), true, speaker)


func _on_line_finished(_speaker: StringName) -> void:
	if not is_running():
		return
	# Diferido: el cuadro emite line_finished antes de empezar la siguiente.
	_next.call_deferred()


func _next() -> void:
	if not is_inside_tree() or not is_running():
		return
	_show_next()


func _finish() -> void:
	_step = Step.DONE
	_index = -1
	if text_box != null and text_box.line_finished.is_connected(_on_line_finished):
		text_box.line_finished.disconnect(_on_line_finished)
	GameState.meet_ally(GameState.ALLY_CALC)
	GameState.clear_ally_arrival(GameState.ALLY_CALC)
	GameState.request_save()
	if station != null and is_instance_valid(station):
		station.set_arrived(false)
		station.set_powered(true)
		station.flash(float(_data.get("power_on_flash_s", 0.3)))
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
