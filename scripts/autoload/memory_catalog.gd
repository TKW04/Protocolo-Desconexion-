## Catalogo de los recuerdos (data/memories.json, ver sus _notes;
## docs/propuesta-recuerdos.md §7 y §10). Solo datos: obtenerlos y guardarlos lo
## hace GameState (memories, obtain_memory); mostrarlos, NotasAlbum (pestana
## «Recuerdos»). Dos tipos: KIND_BOSS (recuerdo de jefe, una capa por acceso:
## layer 1 Caché, 2 Kernel, 3 Raíz) y KIND_SECRET (mensaje de secreto, con
## sender, subject, level, secret y first_lap). Esquema validado por
## tools/validate_memories.py.
class_name MemoryCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/memories.json"
const KIND_BOSS: String = "boss"
const KIND_SECRET: String = "secret"

var _entries: Dictionary[StringName, Dictionary] = {}
var _order: Array[StringName] = []

static var _shared: MemoryCatalog


static func shared() -> MemoryCatalog:
	if _shared == null:
		_shared = load_from_file()
	return _shared


static func load_from_file(path: String = DEFAULT_PATH) -> MemoryCatalog:
	var catalog := MemoryCatalog.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("MemoryCatalog: no se pudo leer '%s'." % path)
		return catalog
	var items: Variant = (parsed as Dictionary).get("memories", [])
	if items is Array:
		for item: Variant in items:
			if item is Dictionary and (item as Dictionary).get("id", "") is String:
				var id := StringName(String((item as Dictionary)["id"]))
				catalog._entries[id] = item
				catalog._order.append(id)
	return catalog


## Todos los ids, en el orden del archivo.
func ids() -> Array[StringName]:
	return _order.duplicate()


func has(id: StringName) -> bool:
	return _entries.has(id)


func entry(id: StringName) -> Dictionary:
	return _entries.get(id, {})


func kind(id: StringName) -> String:
	return String(entry(id).get("kind", ""))


func is_boss(id: StringName) -> bool:
	return kind(id) == KIND_BOSS


func world(id: StringName) -> int:
	return int(entry(id).get("world", 0))


## Capa (1 Caché, 2 Kernel, 3 Raíz) de un recuerdo de jefe; 0 en los mensajes.
func layer(id: StringName) -> int:
	return int(entry(id).get("layer", 0))


func title(id: StringName) -> String:
	return String(entry(id).get("title", ""))


func text(id: StringName) -> String:
	return String(entry(id).get("text", ""))


func sender(id: StringName) -> String:
	return String(entry(id).get("sender", ""))


func subject(id: StringName) -> String:
	return String(entry(id).get("subject", ""))


## Subnivel y secreto que ofrecen un mensaje (vacios en los de jefe).
func level(id: StringName) -> String:
	return String(entry(id).get("level", ""))


func secret(id: StringName) -> String:
	return String(entry(id).get("secret", ""))


## Acceso (vuelta interna) desde el que aparece: la capa en los de jefe y
## first_lap en los mensajes.
func first_lap(id: StringName) -> int:
	return layer(id) if is_boss(id) else int(entry(id).get("first_lap", 1))


## Ids del mundo `world` del tipo `memory_kind` (vacio: los dos), por order.
func ids_of(world_id: int, memory_kind: String = "") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _order:
		if world(id) == world_id and (memory_kind.is_empty() or kind(id) == memory_kind):
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(entry(a).get("order", 0)) < int(entry(b).get("order", 0)))
	return out


## Id del recuerdo de jefe del mundo `world_id` y la capa `memory_layer` (&"" si no hay).
func boss_id(world_id: int, memory_layer: int) -> StringName:
	for id: StringName in ids_of(world_id, KIND_BOSS):
		if layer(id) == memory_layer:
			return id
	return &""


## Se ve (en Notas) o se ofrece (en el nivel) en el acceso `lap`: las capas y
## los mensajes cuyo acceso ya se alcanzo. Un mensaje no obtenido se sigue
## ofreciendo en los accesos siguientes («reaparece si no se obtuvo»).
func is_reached(id: StringName, lap: int) -> bool:
	return has(id) and first_lap(id) <= lap
