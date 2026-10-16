## Llegada al hub tras un game over (docs/propuesta-asistentes-y-vidas.md §5.2,
## paso 12 de §10; textos en data/game_over.json). Lo crea HubRoom cuando
## LevelRunner le pasa el informe del rollback (HubRoom.rollback_report) y
## empieza al terminar la llegada de Isak (start()). Momento de historia, como
## NotasIntro: pausa el arbol de principio a fin y pide al cuadro de texto del
## hub lineas IMPORTANTES de Eco (atenuado en el hub, pero habla para esto). La
## variante sale del informe:
## - first (la papelera no se habia activado nunca) o again (breve);
## - with_copy (habia copia y lo guardado esta en la papelera), empty_copy
##   (habia copia sin nada que desechar) o no_copy (no habia nada guardado).
## Con EcoTextBox.pause_important en false (pruebas y herramientas) no pausa y
## las lineas se cierran solas. La pausa se libera siempre al salir del arbol.
class_name GameOverIntro
extends Node

const DATA_PATH: String = "res://data/game_over.json"
const VARIANT_WITH_COPY: String = "with_copy"
const VARIANT_EMPTY_COPY: String = "empty_copy"
const VARIANT_NO_COPY: String = "no_copy"

## Termina: el jugador cerro la ultima linea.
signal finished

var text_box: EcoTextBox
## Informe de GameState.apply_rollback.
var report: Dictionary = {}

var _pending: int = 0
var _running: bool = false
var _done: bool = false
var _owns_pause: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_release_pause()


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Variante del informe: with_copy, empty_copy o no_copy.
static func variant_for(rollback: Dictionary) -> String:
	if not bool(rollback.get("had_copy", false)):
		return VARIANT_NO_COPY
	return VARIANT_WITH_COPY if bool(rollback.get("trash_has_content", false)) else VARIANT_EMPTY_COPY


## Lineas para el informe (first o again segun rollback.first).
static func lines_for(rollback: Dictionary) -> PackedStringArray:
	var data: Dictionary = load_data()
	var group: Dictionary = data.get("first" if bool(rollback.get("first", false)) else "again", {})
	var out := PackedStringArray()
	for text: Variant in group.get(variant_for(rollback), []):
		if not String(text).is_empty():
			out.append(String(text))
	return out


func get_lines() -> PackedStringArray:
	return lines_for(report)


func is_running() -> bool:
	return _running


func is_done() -> bool:
	return _done


## Empieza. Falso si ya empezo, no hay informe o no hay cuadro de texto.
func start() -> bool:
	if _running or _done or report.is_empty() or text_box == null:
		return false
	var lines: PackedStringArray = get_lines()
	_running = true
	_hold_pause()
	text_box.line_finished.connect(_on_line_finished)
	_pending = lines.size()
	var duration: float = float(load_data().get("duration_s", -1.0))
	for text: String in lines:
		text_box.show_line(text, duration, true)
	if _pending == 0:
		_finish.call_deferred()
	return true


func _on_line_finished(_speaker: StringName) -> void:
	if not _running:
		return
	_pending -= 1
	if _pending <= 0:
		_finish.call_deferred()


func _finish() -> void:
	if _done:
		return
	_running = false
	_done = true
	if text_box != null and text_box.line_finished.is_connected(_on_line_finished):
		text_box.line_finished.disconnect(_on_line_finished)
	_release_pause()
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
