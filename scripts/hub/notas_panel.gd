## Panel de Notas (antes «copia local»; docs/propuesta-hub-y-guardado.md §4.2 y
## docs/propuesta-asistentes-y-vidas.md §2.2, paso 8 de §10). Textos y colores
## en la seccion notas de data/hub.json.
## - Resumen de progreso (cabecera reordenada el 2026-10-26, peticion del
##   usuario; notas.line_icons): puntos de atencion (rombo + numero), power
##   banks, nivel de acceso («Acceso: Caché», HubWorlds.access_label(), con el
##   icono de su vuelta), «Guardado en: aaaa-mm-dd hh:mm» (o «Sin guardar» sin
##   copia) y «Sin guardar» (ambar) solo con copia y cambios pendientes. Sin
##   «Último nivel» ni «Todo guardado». Pie de teclas hub_notas: Aceptar y
##   Volver, sin «Elegir».
## - Opciones Guardar, Álbum, Apodo y Volver. Guardar sin cambios pendientes
##   dice «Todo esta guardado» (no escribe); con cambios pide confirmacion
##   (Si / No) y al confirmar llama a GameState.save_game(): mensaje y destello
##   cian en el monitor (senal saved). Álbum y Apodo los abre la estacion
##   (senales album_requested y nickname_requested).
## - Iconos junto a cada opcion (2026-10-26, peticion del usuario; notas.option_icons):
##   Guardar = disquete, Álbum = álbum de fotos, Apodo = credencial, Volver =
##   flecha de regreso; en la confirmacion, Sí = check y No = aspa.
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
	var pending: bool = GameState.has_unsaved_changes()
	var never: bool = GameState.saved_at.is_empty()
	var lines: Array = [
		{"text": String(texts.get("points", "%d")) % GameState.attention_points, "color": colors.get("points", "ambar"),
			"icon": line_icon_path(&"points")},
		{"text": String(texts.get("power_banks", "%d %d")) % [GameState.get_power_banks_found(), GameState.get_power_banks_spent()],
			"color": colors.get("power_banks", "acento_cian")},
		{"text": HubWorlds.access_label(), "color": colors.get("summary", "texto_tenue"), "icon": access_icon_path()},
		{"text": saved_at_line(), "color": colors.get("unsaved" if never and pending else "summary", "texto_tenue")},
	]
	var status: String = status_text()
	if not status.is_empty():
		lines.append({"text": status, "color": colors.get("unsaved", "ambar")})
	set_lines(lines)
	if _mode == Mode.CONFIRM:
		set_title(String(texts.get("confirm_title", "")))
		set_options([{"id": OPTION_YES, "text": String(texts.get("option_yes", "")), "icon": option_icon_path(OPTION_YES)},
			{"id": OPTION_NO, "text": String(texts.get("option_no", "")), "icon": option_icon_path(OPTION_NO)}])
	else:
		set_title(String(texts.get("title", "")))
		set_options([{"id": OPTION_SAVE, "text": String(texts.get("option_save", "")), "icon": option_icon_path(OPTION_SAVE)},
			{"id": OPTION_ALBUM, "text": String(texts.get("option_album", "")), "icon": option_icon_path(OPTION_ALBUM)},
			{"id": OPTION_NICKNAME, "text": String(texts.get("option_nickname", "%s")) % GameState.get_nickname(),
				"icon": option_icon_path(OPTION_NICKNAME)},
			{"id": OPTION_BACK, "text": String(texts.get("option_back", "")), "icon": option_icon_path(OPTION_BACK)}])
	set_hints("hub_notas")
	super.refresh()


## Ruta del icono de la opcion `id` (notas.option_icons; vacia si no tiene).
func option_icon_path(id: StringName) -> String:
	return String(_notas.get("option_icons", {}).get(String(id), ""))


## Ruta del icono de la linea `id` de la cabecera (notas.line_icons; "" si no tiene).
func line_icon_path(id: StringName) -> String:
	var value: Variant = _notas.get("line_icons", {}).get(String(id), "")
	return String(value) if value is String else ""


## Icono del nivel de acceso actual (notas.line_icons.access, uno por vuelta).
func access_icon_path(lap: int = -1) -> String:
	var list: Variant = _notas.get("line_icons", {}).get("access", [])
	if not (list is Array) or (list as Array).is_empty():
		return ""
	var current: int = GameState.lap if lap < 0 else lap
	return String((list as Array)[clampi(current, 1, (list as Array).size()) - 1])


## Estado bajo la fecha: «Sin guardar» solo si ya hay copia y cambios
## pendientes (sin copia ya lo dice la linea de la fecha), o la papelera; si
## no, vacio (sin «Todo guardado» desde el 2026-10-26).
func status_text() -> String:
	var texts: Dictionary = _notas.get("texts", {})
	if GameState.has_trash_pending():
		return String(texts.get("status_trash", ""))
	if GameState.has_unsaved_changes() and not GameState.saved_at.is_empty():
		return String(texts.get("status_unsaved", ""))
	return ""


## «Guardado en: 2026-10-15 18:04» o, sin copia, «Sin guardar».
func saved_at_line() -> String:
	var texts: Dictionary = _notas.get("texts", {})
	if GameState.saved_at.is_empty():
		return String(texts.get("never_saved", ""))
	return String(texts.get("saved_at", "%s")) % saved_at_text()


## Fecha de la ultima copia en hora local («2026-10-15 18:04»; aaaa-mm-dd hh:mm)
## o «Sin guardar».
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
