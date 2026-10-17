## Catalogo de mejoras de Calc POR PISTAS leido de data/upgrades.json (ver sus
## _notes; docs/propuesta-mejoras.md, tanda M1). Cinco pistas de 5 niveles: el
## nivel 1 es la base (gratis) y los 2-5 se compran en orden. Solo datos y su
## validacion: comprar, aplicar y guardar lo hace GameState.
class_name UpgradeCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/upgrades.json"
## Niveles por pista (el 1 es la base).
const LEVEL_MIN: int = 1
const LEVEL_MAX: int = 5


## Un efecto de un nivel: "<origen>.<clave>" pasa a `value`.
class Effect:
	extends RefCounted
	var target: StringName
	var value: float

	## Origen del target ("game_state", "debug_mode", "isak_abilities").
	func source() -> String:
		return String(target).get_slice(".", 0)

	## Clave dentro del origen ("pulse_radius_px").
	func key() -> String:
		return String(target).substr(source().length() + 1)


## Un nivel de una pista.
class Level:
	extends RefCounted
	var level: int
	var name: String
	var description: String
	var cost_points: int
	var cost_power_banks: int
	## Vuelta minima (GameState.lap) para comprarlo: tope por acceso.
	var min_lap: int = 1
	var effects: Array[Effect] = []
	## Falso: efecto de la tanda M2 («Proximamente»; no se compra ni se aplica).
	var implemented: bool = true
	## Id de la mejora suelta de antes (wide_pulse = pulso 2), o vacio.
	var legacy_id: StringName


## Una pista (Pulso, Laser, Debug, Sync Rate, Energia).
class Track:
	extends RefCounted
	var id: StringName
	var name: String
	var icon: String
	## Habilidad que hay que tener obtenida (vacia = siempre); sin ella, chip «?».
	var requires_ability: StringName
	## Niveles 1-5 en orden (indice = nivel - 1).
	var levels: Array[Level] = []

	func get_level(level: int) -> Level:
		if level < LEVEL_MIN or level > levels.size():
			return null
		return levels[level - 1]

	func max_level() -> int:
		return levels.size()

	## Coste total en puntos de los niveles 2-5.
	func total_points() -> int:
		var total: int = 0
		for entry: Level in levels:
			total += entry.cost_points
		return total


var _tracks: Array[Track] = []
var _by_id: Dictionary[StringName, Track] = {}
## legacy_id -> [track id, nivel].
var _legacy: Dictionary[StringName, Array] = {}
## Migracion de las mejoras sueltas del guardado v3 (seccion migration).
var _migration: Dictionary = {}
## Errores de validacion encontrados al cargar (vacio si es valido).
var errors: PackedStringArray = []

static var _shared: UpgradeCatalog


static func shared() -> UpgradeCatalog:
	if _shared == null:
		_shared = load_from_file()
	return _shared


## Solo pruebas: sustituye el catalogo compartido (null vuelve a data/upgrades.json).
static func set_shared(catalog: UpgradeCatalog) -> void:
	_shared = catalog


static func load_from_file(path: String = DEFAULT_PATH) -> UpgradeCatalog:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		var empty := UpgradeCatalog.new()
		empty._fail("no se pudo leer '%s'" % path)
		return empty
	return from_dict(parsed, path)


static func from_dict(data: Dictionary, source: String = "<dict>") -> UpgradeCatalog:
	var catalog := UpgradeCatalog.new()
	var raw_tracks: Variant = data.get("tracks", [])
	if not raw_tracks is Array or (raw_tracks as Array).is_empty():
		catalog._fail("'%s' no tiene pistas (tracks)" % source)
		return catalog
	for raw: Variant in raw_tracks:
		if not raw is Dictionary:
			catalog._fail("pista que no es un objeto en '%s'" % source)
			continue
		var track: Track = catalog._parse_track(raw)
		if track != null:
			catalog._tracks.append(track)
			catalog._by_id[track.id] = track
	var migration: Variant = data.get("migration", {})
	if migration is Dictionary:
		catalog._migration = migration
	return catalog


## Pistas en el orden del archivo (el de la tienda).
func tracks() -> Array[Track]:
	return _tracks


func get_track(id: StringName) -> Track:
	return _by_id.get(id, null)


func has_track(id: StringName) -> bool:
	return _by_id.has(id)


func track_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for track: Track in _tracks:
		out.append(track.id)
	return out


## Nivel de la pista `track` (null si no existe).
func get_level(track: StringName, level: int) -> Level:
	var t: Track = get_track(track)
	return t.get_level(level) if t != null else null


## [pista, nivel] de un legacy_id (p. ej. wide_pulse -> [pulso, 2]); vacio si no.
func resolve_legacy(legacy_id: StringName) -> Array:
	return _legacy.get(legacy_id, [])


## Migracion de la mejora suelta `legacy_id` del guardado v3: {track, level,
## refund: {attention_points, power_banks}} (vacio si no se conoce).
func migration_for(legacy_id: StringName) -> Dictionary:
	var entry: Variant = _migration.get(String(legacy_id), {})
	return entry if entry is Dictionary else {}


## Nivel mas alto que permite la vuelta `lap` en `track` (tope por acceso:
## Cache 3, Kernel 4, Raiz 5 con los datos actuales).
func access_cap(track: StringName, lap: int) -> int:
	var t: Track = get_track(track)
	if t == null:
		return LEVEL_MIN
	var cap: int = LEVEL_MIN
	for entry: Level in t.levels:
		if entry.min_lap <= lap:
			cap = maxi(cap, entry.level)
		else:
			break
	return cap


## Coste total en puntos de todas las pistas.
func total_points() -> int:
	var total: int = 0
	for track: Track in _tracks:
		total += track.total_points()
	return total


## Power banks que piden todas las pistas.
func total_power_banks() -> int:
	var total: int = 0
	for track: Track in _tracks:
		for entry: Level in track.levels:
			total += entry.cost_power_banks
	return total


func is_valid() -> bool:
	return errors.is_empty() and not _tracks.is_empty()


# --- Interno ---

func _parse_track(d: Dictionary) -> Track:
	var track := Track.new()
	track.id = StringName(String(d.get("id", "")))
	track.name = String(d.get("name", ""))
	track.icon = String(d.get("icon", ""))
	track.requires_ability = StringName(String(d.get("requires_ability", "")))
	if track.id == &"" or track.name.is_empty() or _by_id.has(track.id):
		_fail("pista sin id, sin nombre o repetida '%s'" % track.id)
		return null
	var raw_levels: Variant = d.get("levels", [])
	if not raw_levels is Array or (raw_levels as Array).size() != LEVEL_MAX:
		_fail("la pista '%s' debe tener %d niveles" % [track.id, LEVEL_MAX])
		return null
	var expected: int = LEVEL_MIN
	var previous_lap: int = 1
	for raw: Variant in raw_levels:
		if not raw is Dictionary:
			_fail("nivel que no es un objeto en '%s'" % track.id)
			return null
		var entry: Level = _parse_level(track.id, raw)
		if entry == null:
			return null
		if entry.level != expected:
			_fail("'%s': niveles fuera de orden (se esperaba %d)" % [track.id, expected])
			return null
		if entry.min_lap < previous_lap:
			_fail("'%s' nivel %d: min_lap menor que el del nivel anterior" % [track.id, entry.level])
			return null
		previous_lap = entry.min_lap
		if not entry.legacy_id.is_empty():
			_legacy[entry.legacy_id] = [track.id, entry.level]
		track.levels.append(entry)
		expected += 1
	if track.levels[0].cost_points != 0 or track.levels[0].cost_power_banks != 0:
		_fail("'%s': el nivel 1 es gratis" % track.id)
		return null
	return track


func _parse_level(track: StringName, d: Dictionary) -> Level:
	var entry := Level.new()
	entry.level = int(d.get("level", 0))
	entry.name = String(d.get("name", ""))
	entry.description = String(d.get("description", ""))
	var cost: Variant = d.get("cost", {})
	if not cost is Dictionary:
		_fail("'%s' nivel %d: cost no es un objeto" % [track, entry.level])
		return null
	entry.cost_points = int((cost as Dictionary).get("attention_points", -1))
	entry.cost_power_banks = int((cost as Dictionary).get("power_banks", -1))
	entry.min_lap = int(d.get("min_lap", 1))
	entry.implemented = bool(d.get("implemented", false))
	entry.legacy_id = StringName(String(d.get("legacy_id", "")))
	if entry.name.is_empty() or entry.description.is_empty() or entry.cost_points < 0 \
			or entry.cost_power_banks < 0 or entry.min_lap < 1:
		_fail("'%s' nivel %d: falta nombre, descripcion, coste o min_lap" % [track, entry.level])
		return null
	var raw_effects: Variant = d.get("effects", [])
	if not raw_effects is Array:
		_fail("'%s' nivel %d: effects no es una lista" % [track, entry.level])
		return null
	for raw: Variant in raw_effects:
		if not raw is Dictionary or String((raw as Dictionary).get("target", "")).is_empty() \
				or not ((raw as Dictionary).get("value") is float or (raw as Dictionary).get("value") is int):
			_fail("'%s' nivel %d: efecto sin target o sin valor numerico" % [track, entry.level])
			return null
		var effect := Effect.new()
		effect.target = StringName(String(raw["target"]))
		effect.value = float(raw["value"])
		entry.effects.append(effect)
	if entry.level > LEVEL_MIN and entry.effects.is_empty():
		_fail("'%s' nivel %d: sin efecto" % [track, entry.level])
		return null
	return entry


func _fail(message: String) -> void:
	errors.append(message)
	push_error("UpgradeCatalog: " + message)
