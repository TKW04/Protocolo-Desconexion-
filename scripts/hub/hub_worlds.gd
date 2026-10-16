## Registro de mundos y subniveles del hub (worlds de data/hub.json) y sus
## estados segun el progreso (docs/propuesta-hub-y-guardado.md §3.3; paso 7 de
## §6.2). Sin estado propio: todo sale de los datos y de GameState
## (completed_levels, unlocked_levels y lap).
## - Carpeta (mundo): locked si el mundo no esta desbloqueado (unlocked en los
##   datos, o alguno de sus subniveles en unlocked_levels / completed_levels);
##   completed si tiene subniveles en la vuelta actual y estan todos
##   completados; si no, available.
## - Subnivel: solo cuentan los de la vuelta actual (laps contiene
##   GameState.lap; no se rejuegan vueltas anteriores). completed si esta en
##   completed_levels; available si es jugable (playable y su escena existe) y
##   es el primero de un mundo desbloqueado o esta en unlocked_levels; si no,
##   locked. Un subnivel no jugable o de otra vuelta es «proximamente».
class_name HubWorlds
extends RefCounted

const STATE_LOCKED: StringName = &"locked"
const STATE_AVAILABLE: StringName = &"available"
const STATE_COMPLETED: StringName = &"completed"


## Nombre de cara al jugador de la vuelta `lap` (access_levels.names de
## data/hub.json: 1 Caché, 2 Kernel, 3 Raíz; decision del 2026-10-15). La UI
## nunca dice vuelta, Easy, Normal ni Hard. Fuera de rango se acota (una vuelta
## mayor usa el ultimo nombre).
static func access_name(lap: int) -> String:
	var names: Variant = HubData.load_data().get("access_levels", {}).get("names", [])
	if not (names is Array) or (names as Array).is_empty():
		return ""
	var list: Array = names
	return String(list[clampi(lap, 1, list.size()) - 1])


## Linea «Acceso: <nombre>» de la vuelta `lap` (por defecto, la actual).
static func access_label(lap: int = -1) -> String:
	var current: int = GameState.lap if lap < 0 else lap
	var label: String = String(HubData.load_data().get("access_levels", {}).get("label", "%s"))
	return label % access_name(current)


## Mundos registrados (worlds de data/hub.json), en orden.
static func worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var value: Variant = HubData.load_data().get("worlds", [])
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				out.append(entry)
	return out


## Mundos con carpeta en el hub (los que tienen `col`). Los demas (4-6, aun sin
## contenido) solo guardan su nombre para el album de Notas.
static func folder_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in worlds():
		if entry.has("col"):
			out.append(entry)
	return out


## Nombre del mundo con su numero, «Mundo 1 - Notificaciones»: el MISMO formato
## (folders.texts.title de data/hub.json) en el panel de subniveles y en el
## album de Notas (2026-10-16, decision del usuario). Quien lo muestre decide si
## el mundo ya se alcanzo (nunca se muestra el de uno sin alcanzar).
static func world_title(world_entry: Dictionary) -> String:
	var texts: Variant = HubData.section("folders").get("texts", {})
	var pattern: String = String((texts as Dictionary).get("title", "Mundo %d - %s")) if texts is Dictionary \
			else "Mundo %d - %s"
	return pattern % [int(world_entry.get("world", 0)), String(world_entry.get("name", ""))]


## Mundo con id `id` (vacio si no existe).
static func world(id: StringName) -> Dictionary:
	for entry: Dictionary in worlds():
		if StringName(String(entry.get("id", ""))) == id:
			return entry
	return {}


## Mundo que contiene el subnivel `level_id` (vacio si ninguno).
static func world_of_level(level_id: StringName) -> Dictionary:
	for entry: Dictionary in worlds():
		for level: Dictionary in levels(entry):
			if StringName(String(level.get("id", ""))) == level_id:
				return entry
	return {}


## Subniveles registrados del mundo (todas las vueltas).
static func levels(world_entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for level: Variant in world_entry.get("levels", []):
		if level is Dictionary:
			out.append(level)
	return out


## Subniveles del mundo en la vuelta `lap` (por defecto, la actual).
static func levels_for_lap(world_entry: Dictionary, lap: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for level: Dictionary in levels(world_entry):
		if is_in_lap(level, lap):
			out.append(level)
	return out


static func is_in_lap(level: Dictionary, lap: int = -1) -> bool:
	var current: int = GameState.lap if lap < 0 else lap
	for value: Variant in level.get("laps", [GameState.LAP_EASY]):
		if int(value) == current:
			return true
	return false


static func is_world_unlocked(world_entry: Dictionary) -> bool:
	if bool(world_entry.get("unlocked", false)):
		return true
	for level: Dictionary in levels(world_entry):
		var id := StringName(String(level.get("id", "")))
		if GameState.is_level_unlocked(id) or GameState.is_level_completed(id):
			return true
	return false


## Estado de la carpeta del mundo: locked, available o completed.
static func folder_state(world_entry: Dictionary) -> StringName:
	if world_entry.is_empty() or not is_world_unlocked(world_entry):
		return STATE_LOCKED
	var current: Array[Dictionary] = levels_for_lap(world_entry)
	if current.is_empty():
		return STATE_AVAILABLE
	for level: Dictionary in current:
		if not GameState.is_level_completed(StringName(String(level.get("id", "")))):
			return STATE_AVAILABLE
	return STATE_COMPLETED


## El subnivel tiene escena y se marca como jugable.
static func is_playable(level: Dictionary) -> bool:
	if not bool(level.get("playable", false)):
		return false
	var pattern: String = String(HubData.section("folders").get("level_scene_pattern", "res://scenes/levels/%s.tscn"))
	return ResourceLoader.exists(pattern % String(level.get("id", "")))


## «Proximamente»: no jugable aun o no pertenece a la vuelta actual.
static func is_coming_soon(level: Dictionary) -> bool:
	return not is_playable(level) or not is_in_lap(level)


## Estado del subnivel `level` del mundo `world_entry` en la vuelta actual.
static func level_state(world_entry: Dictionary, level: Dictionary) -> StringName:
	if not is_world_unlocked(world_entry) or is_coming_soon(level):
		return STATE_LOCKED
	var id := StringName(String(level.get("id", "")))
	if GameState.is_level_completed(id):
		return STATE_COMPLETED
	var current: Array[Dictionary] = levels_for_lap(world_entry)
	var first: bool = not current.is_empty() and String(current[0].get("id", "")) == String(id)
	if first or GameState.is_level_unlocked(id):
		return STATE_AVAILABLE
	return STATE_LOCKED


## Se puede entrar al subnivel `level_id` ahora (disponible o completado).
static func can_enter(level_id: StringName) -> bool:
	# Papelera llena tras un game over: no se entra a ningun nivel hasta
	# recuperarla (propuesta de asistentes §2.5).
	if GameState.has_trash_pending():
		return false
	var entry: Dictionary = world_of_level(level_id)
	if entry.is_empty():
		return false
	for level: Dictionary in levels(entry):
		if StringName(String(level.get("id", ""))) == level_id:
			return level_state(entry, level) != STATE_LOCKED
	return false


## Puntos de atencion del subnivel: total ('o' de la rejilla de su JSON; 0 si
## no hay datos).
static func level_points_total(level_id: String) -> int:
	var pattern: String = String(HubData.section("folders").get("level_data_pattern", "res://data/levels/%s.json"))
	var path: String = pattern % level_id
	if not FileAccess.file_exists(path):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return 0
	var total: int = 0
	for row: Variant in (data as Dictionary).get("grid", []):
		total += String(row).count("o")
	return total
