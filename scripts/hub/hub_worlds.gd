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
##   es el primero de un mundo desbloqueado o esta desbloqueado (en
##   unlocked_levels o en los `unlocks` del JSON de un subnivel completado:
##   is_level_unlocked_by_progress); si no, locked. Un subnivel no jugable o de otra vuelta es «proximamente».
## - unlocked_by (2026-10-21): el mundo se desbloquea al completar alguno de
##   esos subniveles (Mundo 2 tras Alerta Mayor). Sin subniveles en la vuelta,
##   su carpeta abre con «Próximamente» (FolderPanel).
## - Jefe (kind "boss", 2026-10-21; docs/propuesta-jefe-alerta-mayor.md §1.3):
##   cuenta como un subnivel mas de la vuelta. Mientras no este completado, la
##   carpeta no pasa a completed (ni se enciende la pieza del fondo del hub),
##   aunque aun no sea jugable.
## - Check de la carpeta (2026-10-26, peticion del usuario): completed solo dice
##   que se superaron todos los subniveles (y enciende la pieza del fondo); el
##   check sale con is_world_all_done: ademas, todos los puntos, power banks,
##   vidas extra y recuerdos del mundo en la vuelta (world_progress).
## - Mundos 4-6 (2026-10-27, paso 0 de docs/propuesta-hub-mundos-4-6.md §3.3-§3.4):
##   requires_upgrade (id de GameState.HUB_UPGRADES). Sin el upgrade el mundo
##   esta OCULTO (folder_state STATE_HIDDEN; nunca desbloqueado); con el, visible
##   y bloqueado hasta su unlocked_by (m4 3-boss, m5 4-boss, m6 5-boss) y
##   disponible despues. page: pagina del hub de su carpeta (por defecto 1;
##   folder_worlds filtra por pagina). Desde el paso 5 (2026-10-27,
##   instalacion en el hub) hub_upgrades.enforce_requires_upgrade es true: el
##   requisito se aplica (la bandera y requires_upgrade_override quedan para las
##   pruebas).
class_name HubWorlds
extends RefCounted

const STATE_LOCKED: StringName = &"locked"
const STATE_AVAILABLE: StringName = &"available"
const STATE_COMPLETED: StringName = &"completed"
## Solo arte de la carpeta (folder_art_state): TODO el mundo obtenido, con check.
const STATE_ALL_DONE: StringName = &"all_done"
## Mundo con requires_upgrade sin ese upgrade instalado: sin carpeta.
const STATE_HIDDEN: StringName = &"hidden"
## Pagina del hub por defecto (la unica que existe hasta el paso 2 del plan).
const DEFAULT_PAGE: int = 1
const KIND_BOSS: String = "boss"


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


## Mundos con carpeta en la pagina `page` del hub (los que tienen `col` y esa
## `page`, por defecto 1). Hasta que exista el hub de varias paginas (paso 2 de
## docs/propuesta-hub-mundos-4-6.md) solo se construye la pagina 1: M1-M3.
static func folder_worlds(page: int = DEFAULT_PAGE) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in worlds():
		if entry.has("col") and world_page(entry) == page:
			out.append(entry)
	return out


## Pagina del hub de la carpeta del mundo (`page`; por defecto 1).
static func world_page(world_entry: Dictionary) -> int:
	return int(world_entry.get("page", DEFAULT_PAGE))


## Override de pruebas de hub_upgrades.enforce_requires_upgrade: -1 = el de los
## datos, 0 = no se aplica, 1 = se aplica.
static var requires_upgrade_override: int = -1


## requires_upgrade se aplica (hub_upgrades.enforce_requires_upgrade de
## data/hub.json). true desde el paso 5 (la instalacion existe en el hub).
static func is_requires_upgrade_enforced() -> bool:
	if requires_upgrade_override >= 0:
		return requires_upgrade_override == 1
	return bool(HubData.section("hub_upgrades").get("enforce_requires_upgrade", false))


## Upgrade del hub que el mundo necesita para verse (vacio si ninguno).
static func required_upgrade(world_entry: Dictionary) -> StringName:
	return StringName(String(world_entry.get("requires_upgrade", "")))


## El mundo es visible: no pide upgrade, o lo tiene instalado (o el requisito
## aun no se aplica). Si no, esta oculto (STATE_HIDDEN).
static func is_world_visible(world_entry: Dictionary) -> bool:
	var upgrade: StringName = required_upgrade(world_entry)
	if upgrade.is_empty() or not is_requires_upgrade_enforced():
		return true
	return GameState.has_hub_upgrade(upgrade)


## Acertijo del upgrade `id` pendiente: su after_level (hub_upgrades.upgrades
## de data/hub.json; 3-boss para hub_update_4_6) esta completado y el upgrade no
## esta instalado. Se calcula (no se guarda): quien vencio a La Curadora con un
## guardado anterior lo ve al cargar. Un game over sin guardar tras instalar lo
## vuelve a dejar pendiente; en Kernel y Raiz, con el upgrade conservado, no.
static func is_hub_upgrade_pending(id: StringName = GameState.HUB_UPGRADE_UPDATE_4_6) -> bool:
	if GameState.has_hub_upgrade(id):
		return false
	var upgrades: Variant = HubData.section("hub_upgrades").get("upgrades", {})
	if not upgrades is Dictionary or not (upgrades as Dictionary).has(String(id)):
		return false
	var spec: Variant = (upgrades as Dictionary)[String(id)]
	var after: String = String((spec as Dictionary).get("after_level", "")) if spec is Dictionary else ""
	return not after.is_empty() and GameState.is_level_completed(StringName(after))


## Nombre del mundo con su numero, «Mundo 1 - Notificaciones» (folders.texts.title
## de data/hub.json) para el panel de subniveles (2026-10-16, decision del
## usuario). Desde el 2026-10-18 el album de Notas muestra SOLO el nombre del
## mundo (NotasAlbum.world_name). Quien lo muestre decide si
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
	# requires_upgrade (paso 0 de la propuesta de los Mundos 4-6): oculto = nunca
	# desbloqueado (la carpeta «El Chat» del album se abre al instalar).
	if not is_world_visible(world_entry):
		return false
	if bool(world_entry.get("unlocked", false)):
		return true
	# unlocked_by (2026-10-21): se desbloquea al completar alguno de esos
	# subniveles (el Mundo 2 al vencer a Alerta Mayor; decision 8 del jefe).
	for value: Variant in world_entry.get("unlocked_by", []):
		if GameState.is_level_completed(StringName(String(value))):
			return true
	for level: Dictionary in levels(world_entry):
		var id := StringName(String(level.get("id", "")))
		if is_level_unlocked_by_progress(id) or GameState.is_level_completed(id):
			return true
	return false


## `unlocks` de nivel ({"type": "level", "id": ...}) del JSON del subnivel
## `level_id` (level_data_pattern de folders), en cache por id.
static var _unlocks_cache: Dictionary = {}


static func level_unlocks(level_id: StringName) -> Array[StringName]:
	if _unlocks_cache.has(level_id):
		return _unlocks_cache[level_id]
	var out: Array[StringName] = []
	var pattern: String = String(HubData.section("folders").get("level_data_pattern", "res://data/levels/%s.json"))
	var path: String = pattern % String(level_id)
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for unlock: Variant in (data as Dictionary).get("unlocks", []):
				if unlock is Dictionary and String(unlock.get("type", "")) == "level":
					out.append(StringName(String(unlock.get("id", ""))))
	_unlocks_cache[level_id] = out
	return out


## El subnivel `level_id` esta desbloqueado: en unlocked_levels o en los
## `unlocks` de algun subnivel completado (2026-10-21: derivado del progreso,
## sin migracion; una partida guardada antes de existir el jefe con el 1-3 ya
## completado tiene la fila del jefe disponible). Como sale de completed_levels,
## un game over sin guardar lo vuelve a bloquear igual que antes.
static func is_level_unlocked_by_progress(level_id: StringName) -> bool:
	if GameState.is_level_unlocked(level_id):
		return true
	for done: StringName in GameState.completed_levels:
		if not GameState.is_level_completed(done):
			continue
		if level_id in level_unlocks(done):
			return true
	return false


## Estado de la carpeta del mundo: hidden (requires_upgrade sin instalar),
## locked, available o completed.
static func folder_state(world_entry: Dictionary) -> StringName:
	if not world_entry.is_empty() and not is_world_visible(world_entry):
		return STATE_HIDDEN
	if world_entry.is_empty() or not is_world_unlocked(world_entry):
		return STATE_LOCKED
	var current: Array[Dictionary] = levels_for_lap(world_entry)
	if current.is_empty():
		return STATE_AVAILABLE
	for level: Dictionary in current:
		if not GameState.is_level_completed(StringName(String(level.get("id", "")))):
			return STATE_AVAILABLE
	return STATE_COMPLETED


## TODO el mundo obtenido en la vuelta actual (2026-10-26, peticion del usuario:
## el check de la carpeta solo sale entonces). Partes (world_progress):
## - levels: subniveles de la vuelta completados (jefe incluido; folder_state).
## - points: puntos de atencion capturados / total de cada subnivel (como la fila
##   «Completado 9/9» del panel).
## - power_banks: power banks de mapa recogidos / total (« - Power bank n/N»).
## - extra_lives: vidas extra de los mapas (extra_life_pickup; secreto encontrado).
## - memories: mensajes de secretos del mundo ofrecidos en la vuelta
##   (MemoryCatalog.is_reached) y la capa del jefe de la vuelta, obtenidos.
## Cada parte es Vector2i(obtenido, total). Sin subniveles en la vuelta, nunca.
static func world_progress(world_entry: Dictionary) -> Dictionary:
	var levels_done := Vector2i.ZERO
	var points := Vector2i.ZERO
	var banks := Vector2i.ZERO
	var lives := Vector2i.ZERO
	var mems := Vector2i.ZERO
	for level: Dictionary in levels_for_lap(world_entry):
		var id := StringName(String(level.get("id", "")))
		levels_done += Vector2i(1 if GameState.is_level_completed(id) else 0, 1)
		var total: int = level_points_total(String(id))
		points += Vector2i(mini(GameState.get_captured_points(id).size(), total), total)
		banks += GameState.get_level_power_bank_progress(id)
		for secret: StringName in level_extra_life_secrets(id):
			lives += Vector2i(1 if GameState.is_secret_found(id, secret) else 0, 1)
	var world_id: int = int(world_entry.get("world", 0))
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	if not levels_for_lap(world_entry).is_empty():
		for id: StringName in catalog.ids_of(world_id, MemoryCatalog.KIND_SECRET):
			if catalog.is_reached(id, GameState.lap):
				mems += Vector2i(1 if GameState.has_memory(id) else 0, 1)
		var boss_layer: StringName = catalog.boss_id(world_id, GameState.lap)
		if not boss_layer.is_empty():
			mems += Vector2i(1 if GameState.has_memory(boss_layer) else 0, 1)
	return {"levels": levels_done, "points": points, "power_banks": banks, "extra_lives": lives, "memories": mems}


## Partes de world_progress que aun faltan, en su orden (vacio = todo obtenido).
static func world_missing(world_entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var progress: Dictionary = world_progress(world_entry)
	for key: String in progress:
		var v: Vector2i = progress[key]
		if v.x < v.y:
			out.append(key)
	return out


## Check de la carpeta: mundo desbloqueado con subniveles en la vuelta y TODO
## obtenido (world_progress sin nada pendiente).
static func is_world_all_done(world_entry: Dictionary) -> bool:
	if folder_state(world_entry) != STATE_COMPLETED:
		return false
	return world_missing(world_entry).is_empty()


## Estado del arte de la carpeta: el de folder_state y, si ademas esta todo
## obtenido, STATE_ALL_DONE (con check). La pieza del fondo del hub sigue con
## folder_state (se enciende al vencer al jefe).
static func folder_art_state(world_entry: Dictionary) -> StringName:
	return STATE_ALL_DONE if is_world_all_done(world_entry) else folder_state(world_entry)


## Secretos con vida extra del subnivel (extra_life_pickup de su JSON,
## params.secret_id), en cache por id.
static var _extra_life_cache: Dictionary = {}


static func level_extra_life_secrets(level_id: StringName) -> Array[StringName]:
	if _extra_life_cache.has(level_id):
		return _extra_life_cache[level_id]
	var out: Array[StringName] = []
	var pattern: String = String(HubData.section("folders").get("level_data_pattern", "res://data/levels/%s.json"))
	var path: String = pattern % String(level_id)
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for obj: Variant in (data as Dictionary).get("objects", []):
				if obj is Dictionary and String((obj as Dictionary).get("type", "")) == "extra_life_pickup":
					var params: Variant = (obj as Dictionary).get("params", {})
					var secret: String = String((params as Dictionary).get("secret_id", "")) if params is Dictionary else ""
					if not secret.is_empty():
						out.append(StringName(secret))
	_extra_life_cache[level_id] = out
	return out


## El subnivel es el jefe del mundo (kind "boss").
static func is_boss(level: Dictionary) -> bool:
	return String(level.get("kind", "")) == KIND_BOSS


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
	if first or is_level_unlocked_by_progress(id):
		return STATE_AVAILABLE
	return STATE_LOCKED


## Subnivel mas avanzado al que se puede entrar en la vuelta actual (disponible
## o completado; el ultimo en el orden de worlds y levels de data/hub.json), sin
## mirar la papelera. Vacio si ninguno. LevelRunner lo usa como «ultimo nivel
## jugado» al arrancar en el hub (tecla R) si aun no se jugo ninguno.
static func most_advanced_level() -> StringName:
	var best: StringName = &""
	for entry: Dictionary in worlds():
		for level: Dictionary in levels_for_lap(entry):
			if level_state(entry, level) != STATE_LOCKED:
				best = StringName(String(level.get("id", "")))
	return best


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
## no hay datos). Desde el paso 10 del Mundo 5 (2026-10-29) cuenta tambien cada
## caja sorpresa con puntos (se captura como un punto del nivel, «box:<id>»).
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
	for obj: Variant in (data as Dictionary).get("objects", []):
		if obj is Dictionary and String((obj as Dictionary).get("type", "")) == "surprise_box" \
				and String(((obj as Dictionary).get("params", {}) as Dictionary).get("content", "")) == "points":
			total += 1
	return total
