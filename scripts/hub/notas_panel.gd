## Panel de Notas (antes «copia local»; docs/propuesta-hub-y-guardado.md §4.2 y
## docs/propuesta-asistentes-y-vidas.md §2.2, paso 8 de §10). Textos y colores
## en la seccion notas de data/hub.json.
## - Resumen de progreso: ultimo nivel, puntos de atencion, nivel de acceso
##   («Acceso: Caché», HubWorlds.access_label()), ultima copia
##   y el estado «Sin guardar» (ambar) / «Todo guardado».
## - Opciones Guardar, Álbum, Apodo y Volver. Guardar sin cambios pendientes
##   dice «Todo esta guardado» (no escribe); con cambios pide confirmacion
##   (Si / No) y al confirmar llama a GameState.save_game(): mensaje y destello
##   cian en el monitor (senal saved). Álbum y Apodo los abre la estacion
##   (senales album_requested y nickname_requested).
## - Salto: desde la confirmacion vuelve al resumen; desde el resumen cierra.
## - Papelera llena tras un game over (2026-10-16, propuesta de asistentes
##   §5.2): Guardar no guarda y avisa «Primero recupera tus archivos de la
##   papelera»; el estado dice que los archivos estan en la papelera. Guardar el
##   estado sin lo desechado sobrescribiria la copia buena.
class_name NotasPanel
extends HubPanel

enum Mode { SUMMARY, CONFIRM }

const OPTION_SAVE: StringName = &"save"
const OPTION_ALBUM: StringName = &"album"
const OPTION_NICKNAME: StringName = &"nickname"
const OPTION_BACK: StringName = &"back"
const OPTION_YES: StringName = &"yes"
const OPTION_NO: StringName = &"no"

## Se intento guardar (ok = se escribio la copia).
signal saved(ok: bool)
## El jugador eligio Álbum.
signal album_requested
## El jugador eligio Apodo.
signal nickname_requested

var _notas: Dictionary = HubData.section("notas")
var _mode: Mode = Mode.SUMMARY
var _save_count: int = 0


func _ready() -> void:
	super._ready()
	EventBus.unsaved_changes_changed.connect(_on_unsaved_changes_changed)
	EventBus.trash_changed.connect(_on_unsaved_changes_changed)


func open() -> void:
	_mode = Mode.SUMMARY
	super.open()


func get_mode() -> Mode:
	return _mode


func get_save_count() -> int:
	return _save_count


## Rellena el panel segun el modo y el estado de GameState.
func refresh() -> void:
	if _title == null:
		return
	var texts: Dictionary = _notas.get("texts", {})
	var colors: Dictionary = _notas.get("colors", {})
	var lines: Array = [
		{"text": String(texts.get("last_level", "%s")) % last_level_text(), "color": colors.get("summary", "texto_tenue")},
		{"text": String(texts.get("points", "%d")) % GameState.attention_points, "color": colors.get("points", "ambar")},
		{"text": String(texts.get("power_banks", "%d %d")) % [GameState.get_power_banks_found(), GameState.get_power_banks_spent()],
			"color": colors.get("power_banks", "acento_cian")},
		{"text": HubWorlds.access_label(), "color": colors.get("summary", "texto_tenue")},
		{"text": String(texts.get("saved_at", "%s")) % saved_at_text(), "color": colors.get("summary", "texto_tenue")},
		{"text": status_text(), "color": colors.get("unsaved" if GameState.has_unsaved_changes() or GameState.has_trash_pending() else "saved", "texto_tenue")},
	]
	set_lines(lines)
	if _mode == Mode.CONFIRM:
		set_title(String(texts.get("confirm_title", "")))
		set_options([{"id": OPTION_YES, "text": String(texts.get("option_yes", ""))},
			{"id": OPTION_NO, "text": String(texts.get("option_no", ""))}])
	else:
		set_title(String(texts.get("title", "")))
		set_options([{"id": OPTION_SAVE, "text": String(texts.get("option_save", ""))},
			{"id": OPTION_ALBUM, "text": String(texts.get("option_album", ""))},
			{"id": OPTION_NICKNAME, "text": String(texts.get("option_nickname", "%s")) % GameState.get_nickname()},
			{"id": OPTION_BACK, "text": String(texts.get("option_back", ""))}])
	set_hints("hub_list")
	super.refresh()


## Texto del estado: «Sin guardar» o «Todo guardado».
func status_text() -> String:
	var key: String = "status_unsaved" if GameState.has_unsaved_changes() else "status_saved"
	if GameState.has_trash_pending():
		key = "status_trash"
	return String(_notas.get("texts", {}).get(key, ""))


## Ultimo nivel: el actual de GameState o, si no hay, el ultimo completado;
## con su nombre de data/levels/<id>.json («Bandeja de entrada (1-1)»).
func last_level_text() -> String:
	var texts: Dictionary = _notas.get("texts", {})
	var id: String = String(GameState.current_level)
	if id.is_empty() and not GameState.completed_levels.is_empty():
		id = String(GameState.completed_levels.keys().back())
	if id.is_empty():
		return String(texts.get("no_level", ""))
	var name: String = level_name(id)
	return id if name == id else String(texts.get("level_with_id", "%s (%s)")) % [name, id]


## Nombre del nivel (campo name de su JSON) o el id.
func level_name(level_id: String) -> String:
	var path: String = String(_notas.get("level_data_pattern", "res://data/levels/%s.json")) % level_id
	if not FileAccess.file_exists(path):
		return level_id
	var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return String(level.get("name", level_id)) if level is Dictionary else level_id


## Fecha de la ultima copia en hora local («2026-10-15 18:04») o «nunca».
func saved_at_text() -> String:
	if GameState.saved_at.is_empty():
		return String(_notas.get("texts", {}).get("never_saved", ""))
	var utc: String = GameState.saved_at.trim_suffix("Z")
	var unix: int = Time.get_unix_time_from_datetime_string(utc)
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_string_from_unix_time(unix + bias_min * 60, true).left(16)


## Guarda ya (GameState.save_game) y muestra el resultado. Sin cambios no
## escribe. Verdadero si todo quedo guardado.
func save_now() -> bool:
	var texts: Dictionary = _notas.get("texts", {})
	var colors: Dictionary = _notas.get("colors", {})
	_mode = Mode.SUMMARY
	if GameState.has_trash_pending():
		refresh()
		set_message(String(texts.get("message_trash_pending", "")), String(colors.get("message", "texto_claro")))
		saved.emit(false)
		return false
	if not GameState.has_unsaved_changes():
		refresh()
		set_message(String(texts.get("message_nothing_to_save", "")), String(colors.get("message", "texto_claro")))
		return true
	var ok: bool = GameState.save_game()
	if ok:
		_save_count += 1
	refresh()
	set_message(String(texts.get("message_saved" if ok else "message_save_failed", "")),
		String(colors.get("message_saved" if ok else "message", "texto_claro")))
	saved.emit(ok)
	return ok


# --- HubPanel ---

func _on_confirm(id: StringName) -> void:
	match id:
		OPTION_SAVE:
			if GameState.has_trash_pending() or not GameState.has_unsaved_changes():
				save_now()
				return
			_mode = Mode.CONFIRM
			_selected = 0
			set_message("")
			refresh()
		OPTION_YES:
			save_now()
		OPTION_NO:
			_back_to_summary()
		OPTION_ALBUM:
			album_requested.emit()
		OPTION_NICKNAME:
			nickname_requested.emit()
		OPTION_BACK:
			close_requested.emit()


func _on_cancel() -> void:
	if _mode == Mode.CONFIRM:
		_back_to_summary()
	else:
		close_requested.emit()


func _back_to_summary() -> void:
	_mode = Mode.SUMMARY
	_selected = 0
	set_message("")
	refresh()


func _on_unsaved_changes_changed(_has_changes: bool) -> void:
	if is_open():
		refresh()
