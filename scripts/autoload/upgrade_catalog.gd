## Catalogo de mejoras permanentes leido de data/upgrades.json (ver sus
## _notes). Solo datos: comprar y aplicar lo hace GameState.
class_name UpgradeCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/upgrades.json"


## Una mejora del catalogo.
class Entry:
	extends RefCounted
	var id: StringName
	var name: String
	var label: String
	var unit: String
	## "<origen>.<clave>" (p. ej. "isak_abilities.pulse_radius_px").
	var target: StringName
	var value: float
	var cost_points: int
	var cost_power_banks: int

	## Origen del target ("game_state", "debug_mode", "isak_abilities").
	func source() -> String:
		return String(target).get_slice(".", 0)

	## Clave dentro del origen ("pulse_radius_px").
	func key() -> String:
		return String(target).substr(source().length() + 1)


var _entries: Array[Entry] = []
var _by_id: Dictionary[StringName, Entry] = {}

static var _shared: UpgradeCatalog


static func shared() -> UpgradeCatalog:
	if _shared == null:
		_shared = load_from_file()
	return _shared


static func load_from_file(path: String = DEFAULT_PATH) -> UpgradeCatalog:
	var catalog := UpgradeCatalog.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("UpgradeCatalog: no se pudo leer '%s'." % path)
		return catalog
	for raw: Variant in (parsed as Dictionary).get("upgrades", []):
		if not raw is Dictionary:
			continue
		var d: Dictionary = raw
		var entry := Entry.new()
		entry.id = StringName(String(d.get("id", "")))
		entry.name = String(d.get("name", entry.id))
		entry.label = String(d.get("label", entry.name))
		entry.unit = String(d.get("unit", ""))
		entry.target = StringName(String(d.get("target", "")))
		entry.value = float(d.get("value", 0.0))
		var cost: Dictionary = d.get("cost", {})
		entry.cost_points = int(cost.get("attention_points", 0))
		entry.cost_power_banks = int(cost.get("power_banks", 0))
		if entry.id == &"" or entry.target == &"" or catalog._by_id.has(entry.id):
			push_error("UpgradeCatalog: entrada invalida o repetida '%s' en '%s'." % [entry.id, path])
			continue
		catalog._entries.append(entry)
		catalog._by_id[entry.id] = entry
	return catalog


## Mejoras en el orden del archivo.
func entries() -> Array[Entry]:
	return _entries


func get_entry(id: StringName) -> Entry:
	return _by_id.get(id, null)


func has(id: StringName) -> bool:
	return _by_id.has(id)
