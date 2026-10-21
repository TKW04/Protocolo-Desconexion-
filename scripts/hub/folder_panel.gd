## Panel de subniveles de una carpeta del hub (docs/propuesta-hub-y-guardado.md
## §3.3; paso 7 de §6.2). Textos y colores en la seccion folders de
## data/hub.json; estados de HubWorlds.
## - Titulo: «Mundo N - Nombre»; linea con el nivel de acceso de la vuelta actual
##   («Acceso: Caché», HubWorlds.access_label(); no se elige: solo cambia con el
##   rollback; la UI nunca dice vuelta ni Easy/Normal/Hard).
## - Una opcion por subnivel de la vuelta actual con su estado: Completado (y
##   puntos capturados/total), Nuevo, Bloqueado o Proximamente; y Volver.
## - Pulso sobre un subnivel disponible o completado: emite level_chosen (la
##   carpeta cierra el panel e Isak se va por el vortice). Sobre uno bloqueado:
##   mensaje (Bloqueado / Proximamente) y no pasa nada mas. Salto o Volver:
##   close_requested.
## - Cambios sin guardar (paso 10, primer hub guiado; decision 2026-10-15):
##   SIEMPRE que se elige un subnivel disponible o completado con
##   GameState.has_unsaved_changes(), antes de entrar se pide confirmacion
##   («¿Seguro? Aún no has guardado.»: Entrar sin guardar / Volver). Volver (o
##   salto) deja en la lista del panel; con todo guardado entra directo. Desde
##   el 2026-10-16 el aviso anade el riesgo del game over (confirm_unsaved_risk:
##   «Si caes sin guardar, Eco te devolverá a tu última copia.»).
class_name FolderPanel
extends HubPanel

enum Mode { LIST, CONFIRM_UNSAVED }

const OPTION_BACK: StringName = &"back"
const OPTION_ENTER_UNSAVED: StringName = &"enter_unsaved"
const OPTION_STAY: StringName = &"stay"

## Se eligio entrar al subnivel `level_id`.
signal level_chosen(level_id: StringName)

## Mundo de la carpeta (entrada de worlds de data/hub.json).
var world_entry: Dictionary = {}

var _folders: Dictionary = HubData.section("folders")
var _mode: Mode = Mode.LIST
## Subnivel pendiente de confirmar (modo CONFIRM_UNSAVED).
var _pending_level: StringName = &""


func open() -> void:
	_mode = Mode.LIST
	_pending_level = &""
	super.open()


func get_mode() -> Mode:
	return _mode


## Verdadero mientras se pide confirmar la entrada sin guardar.
func is_confirming_unsaved() -> bool:
	return _mode == Mode.CONFIRM_UNSAVED


func get_pending_level() -> StringName:
	return _pending_level


## Rellena el panel con el estado actual de GameState.
func refresh() -> void:
	if _title == null:
		return
	var texts: Dictionary = _folders.get("texts", {})
	var colors: Dictionary = _folders.get("colors", {})
	if _mode == Mode.CONFIRM_UNSAVED:
		set_title(String(texts.get("confirm_unsaved_title", "")))
		var lines: Array = [{"text": level_text(_level(_pending_level)), "color": String(colors.get("summary", "texto_tenue"))}]
		var risk: String = String(texts.get("confirm_unsaved_risk", ""))
		if not risk.is_empty():
			lines.append({"text": risk, "color": String(colors.get("message", "texto_claro"))})
		set_lines(lines)
		set_options([{"id": OPTION_ENTER_UNSAVED, "text": String(texts.get("option_enter_unsaved", ""))},
			{"id": OPTION_STAY, "text": String(texts.get("option_stay", "Volver"))}])
		set_help(String(texts.get("confirm_help", texts.get("help", ""))))
		super.refresh()
		return
	set_title(HubWorlds.world_title(world_entry))
	set_lines([{"text": HubWorlds.access_label(),
		"color": String(colors.get("summary", "texto_tenue"))}])
	var options: Array = []
	for level: Dictionary in HubWorlds.levels_for_lap(world_entry):
		options.append({"id": StringName(String(level.get("id", ""))), "text": level_text(level)})
	options.append({"id": OPTION_BACK, "text": String(texts.get("option_back", "Volver"))})
	set_options(options)
	set_help(String(texts.get("help", "")))
	super.refresh()


## Estado del subnivel `level_id` (HubWorlds.STATE_*; locked si no esta).
func get_level_state(level_id: StringName) -> StringName:
	var level: Dictionary = _level(level_id)
	return HubWorlds.STATE_LOCKED if level.is_empty() else HubWorlds.level_state(world_entry, level)


## Texto del subnivel: «1-1 Bandeja de entrada - Completado 9/9», «... - Nuevo».
## El jefe (kind "boss") sale como «Jefe: Alerta Mayor - Nuevo», sin id ni
## puntos (la arena no tiene puntos de atencion).
func level_text(level: Dictionary) -> String:
	var texts: Dictionary = _folders.get("texts", {})
	var id: String = String(level.get("id", ""))
	var name: String = String(level.get("name", id))
	var state: StringName = HubWorlds.level_state(world_entry, level)
	var label: String = state_text(level)
	if HubWorlds.is_boss(level):
		return String(texts.get("boss_level", "%s - %s")) % [name, label]
	if state == HubWorlds.STATE_COMPLETED:
		return String(texts.get("level_points", "%s %s %s %d/%d")) % [id, name, label,
			GameState.get_captured_points(StringName(id)).size(), HubWorlds.level_points_total(id)]
	return String(texts.get("level", "%s %s")) % [id, name] + " - " + label


## Nombre del estado del subnivel (Completado, Nuevo, Bloqueado, Proximamente).
func state_text(level: Dictionary) -> String:
	var texts: Dictionary = _folders.get("texts", {})
	match HubWorlds.level_state(world_entry, level):
		HubWorlds.STATE_COMPLETED:
			return String(texts.get("state_completed", ""))
		HubWorlds.STATE_AVAILABLE:
			return String(texts.get("state_available", ""))
	if HubWorlds.is_coming_soon(level):
		return String(texts.get("state_coming_soon", ""))
	return String(texts.get("state_locked", ""))


# --- HubPanel ---

func _on_confirm(id: StringName) -> void:
	match id:
		OPTION_BACK:
			close_requested.emit()
			return
		OPTION_ENTER_UNSAVED:
			var pending: StringName = _pending_level
			_back_to_list()
			if not pending.is_empty():
				level_chosen.emit(pending)
			return
		OPTION_STAY:
			_back_to_list()
			return
	var level: Dictionary = _level(id)
	if level.is_empty():
		return
	var texts: Dictionary = _folders.get("texts", {})
	var colors: Dictionary = _folders.get("colors", {})
	if HubWorlds.level_state(world_entry, level) == HubWorlds.STATE_LOCKED:
		var key: String = "message_coming_soon" if HubWorlds.is_coming_soon(level) else "message_locked"
		set_message(String(texts.get(key, "")), String(colors.get("message", "texto_claro")))
		return
	if GameState.has_unsaved_changes():
		_mode = Mode.CONFIRM_UNSAVED
		_pending_level = id
		_selected = 0
		set_message("")
		refresh()
		return
	level_chosen.emit(id)


func _on_cancel() -> void:
	if _mode == Mode.CONFIRM_UNSAVED:
		_back_to_list()
	else:
		close_requested.emit()


## Vuelve a la lista de subniveles con el subnivel pendiente elegido.
func _back_to_list() -> void:
	var pending: StringName = _pending_level
	_mode = Mode.LIST
	_pending_level = &""
	set_message("")
	refresh()
	if not pending.is_empty():
		select_option(pending)


func _refresh_options() -> void:
	super._refresh_options()
	# Los subniveles bloqueados se ven apagados aunque se puedan recorrer.
	var colors: Dictionary = _folders.get("colors", {})
	for i: int in mini(_option_labels.size(), _option_ids.size()):
		var level: Dictionary = _level(_option_ids[i])
		if level.is_empty() or i == _selected:
			continue
		var state: StringName = HubWorlds.level_state(world_entry, level)
		_set_color(_option_labels[i], String(colors.get(String(state), "texto_tenue")))


func _level(level_id: StringName) -> Dictionary:
	for level: Dictionary in HubWorlds.levels(world_entry):
		if StringName(String(level.get("id", ""))) == level_id:
			return level
	return {}
