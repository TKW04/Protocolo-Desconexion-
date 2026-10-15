## Panel de subniveles de una carpeta del hub (docs/propuesta-hub-y-guardado.md
## §3.3; paso 7 de §6.2). Textos y colores en la seccion folders de
## data/hub.json; estados de HubWorlds.
## - Titulo: «Mundo N - Nombre»; linea con la vuelta actual («Vuelta 1 (Easy)»;
##   no se elige: solo cambia con el rollback).
## - Una opcion por subnivel de la vuelta actual con su estado: Completado (y
##   puntos capturados/total), Nuevo, Bloqueado o Proximamente; y Volver.
## - Pulso sobre un subnivel disponible o completado: emite level_chosen (la
##   carpeta cierra el panel e Isak se va por el vortice). Sobre uno bloqueado:
##   mensaje (Bloqueado / Proximamente) y no pasa nada mas. Salto o Volver:
##   close_requested.
class_name FolderPanel
extends HubPanel

const OPTION_BACK: StringName = &"back"

## Se eligio entrar al subnivel `level_id`.
signal level_chosen(level_id: StringName)

## Mundo de la carpeta (entrada de worlds de data/hub.json).
var world_entry: Dictionary = {}

var _folders: Dictionary = HubData.section("folders")


## Rellena el panel con el estado actual de GameState.
func refresh() -> void:
	if _title == null:
		return
	var texts: Dictionary = _folders.get("texts", {})
	var colors: Dictionary = _folders.get("colors", {})
	set_title(String(texts.get("title", "%d %s")) % [int(world_entry.get("world", 0)), String(world_entry.get("name", ""))])
	set_lines([{"text": String(texts.get("lap", "%d %s")) % [GameState.lap, lap_name(GameState.lap)],
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
func level_text(level: Dictionary) -> String:
	var texts: Dictionary = _folders.get("texts", {})
	var id: String = String(level.get("id", ""))
	var name: String = String(level.get("name", id))
	var state: StringName = HubWorlds.level_state(world_entry, level)
	var label: String = state_text(level)
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


## Nombre de la vuelta (1 Easy, 2 Normal, 3 Hard).
func lap_name(lap: int) -> String:
	return String(_folders.get("texts", {}).get("lap_names", {}).get(str(lap), str(lap)))


# --- HubPanel ---

func _on_confirm(id: StringName) -> void:
	if id == OPTION_BACK:
		close_requested.emit()
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
	level_chosen.emit(id)


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
