## Catalogo de la ayuda de Eco con Q por tipo (data/help.json, ver sus _notes;
## docs/propuesta-asistentes-y-vidas.md §3). Solo datos: mostrar la Q y pausar
## lo hace HelpSystem; aprender un tipo, GameState.learn_help.
## Un objeto se apunta a la ayuda con tag(): queda en el grupo TARGET_GROUP con
## el metadato META_HELP_ID (el generador de niveles lo escribe en la escena y
## los objetos creados en juego, como los drops, lo hacen al crearse).
class_name HelpCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://data/help.json"
const TARGET_GROUP: StringName = &"help_target"
const META_HELP_ID: StringName = &"help_id"
const CATEGORY_ENEMY: String = "enemy"
const CATEGORY_OBJECT: String = "object"
const NICKNAME_TAG: String = "{apodo}"  # = GameState.NICKNAME_TAG

var _data: Dictionary = {}
var _types: Dictionary = {}

static var _shared: HelpCatalog


static func shared() -> HelpCatalog:
	if _shared == null:
		_shared = load_from_file()
	return _shared


static func load_from_file(path: String = DEFAULT_PATH) -> HelpCatalog:
	var catalog := HelpCatalog.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		catalog._data = parsed
		var types: Variant = (parsed as Dictionary).get("types", {})
		if types is Dictionary:
			catalog._types = types
	else:
		push_error("HelpCatalog: no se pudo leer '%s'." % path)
	return catalog


## Apunta `node` a la ayuda del tipo `help_id` (vacio: lo quita).
static func tag(node: Node, help_id: StringName) -> void:
	if node == null:
		return
	if help_id == &"":
		node.remove_from_group(TARGET_GROUP)
		node.remove_meta(META_HELP_ID)
		return
	node.set_meta(META_HELP_ID, help_id)
	node.add_to_group(TARGET_GROUP)


## LO DESTRUIDO NO AYUDA (2026-10-16, fallo encontrado jugando el 1-1): el
## objeto aun puede dar informacion (Q normal, relectura y Eco junto a el). No
## lo es si se ha liberado o va a liberarse, esta fuera del arbol u oculto, o
## si el propio objeto dice que ya no (metodo is_help_available(): pop-up
## cerrandose o cerrado, Burbuja reventada, receptor ya activado, puente ya
## extendido, recogidas ya tomadas, pared con glitch disuelta, terminal ya
## activada, cargador de un solo uso gastado...).
static func is_help_live(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
		return false
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	if node.has_method(&"is_help_available"):
		return bool(node.call(&"is_help_available"))
	return true


## Tipo de ayuda de `node` (&"" si no tiene).
static func help_id_of(node: Node) -> StringName:
	if node == null or not node.has_meta(META_HELP_ID):
		return &""
	return StringName(String(node.get_meta(META_HELP_ID)))


func has(help_id: StringName) -> bool:
	return _types.has(String(help_id))


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _types:
		out.append(StringName(String(key)))
	return out


func entry(help_id: StringName) -> Dictionary:
	var value: Variant = _types.get(String(help_id), {})
	return value if value is Dictionary else {}


func title(help_id: StringName) -> String:
	return String(entry(help_id).get("title", ""))


## Texto de Eco para el tipo, con {apodo} sustituido por `nickname` (vacio: el
## apodo de la partida, GameState.nickname).
func text(help_id: StringName, nickname: String = "") -> String:
	return GameState.apply_nickname(String(entry(help_id).get("text", "")), nickname)


func category(help_id: StringName) -> String:
	return String(entry(help_id).get("category", CATEGORY_OBJECT))


## Mundo (1-6) del tipo: carpeta del album de Notas. 0 si no lo tiene.
func world(help_id: StringName) -> int:
	return int(entry(help_id).get("world", 0))


func action() -> StringName:
	return StringName(String(_data.get("action", "help")))


## Radio (px) en que la Q sale para `help_id`, medido desde el centro de Isak.
func radius_px(help_id: StringName, tile_size: float = 64.0) -> float:
	var e: Dictionary = entry(help_id)
	var fallback_key: String = "enemy_radius_tiles" if category(help_id) == CATEGORY_ENEMY else "radius_tiles"
	var tiles: float = float(e.get("radius_tiles", _data.get(fallback_key, 2.5)))
	return tiles * tile_size


func center_offset(help_id: StringName) -> Vector2:
	return _vec(entry(help_id).get("center_px", [0, 0]))


func prompt_offset(help_id: StringName) -> Vector2:
	return _vec(entry(help_id).get("prompt_px", [0, 0]))


func isak_center_y() -> float:
	return float(_data.get("isak_center_y_px", -48.0))


func prompt_config() -> Dictionary:
	var value: Variant = _data.get("prompt", {})
	return value if value is Dictionary else {}


## Relectura (seccion reread de data/help.json): Q apagada sobre un objeto de
## un tipo ya aprendido, con Isak quieto.
func reread_config() -> Dictionary:
	var value: Variant = _data.get("reread", {})
	return value if value is Dictionary else {}


## Pelea con jefe (seccion boss_calm, 2026-10-22): highlight_s, blink_hz, blink_on.
func boss_calm_config() -> Dictionary:
	var value: Variant = _data.get("boss_calm", {})
	return value if value is Dictionary else {}


## Aspecto de la Q apagada: la seccion prompt con los campos de reread.prompt.
func reread_prompt_config() -> Dictionary:
	var out: Dictionary = prompt_config().duplicate()
	var overrides: Variant = reread_config().get("prompt", {})
	if overrides is Dictionary:
		out.merge(overrides as Dictionary, true)
	return out


## Segundos que Isak debe estar quieto para que salga la Q apagada.
func reread_still_s() -> float:
	return float(reread_config().get("still_s", 0.5))


## Velocidad horizontal (px/s) por debajo de la cual Isak, en el suelo, cuenta
## como quieto.
func reread_still_speed() -> float:
	return float(reread_config().get("still_speed_px_s", 8.0))


## Velocidad (px/s) por encima de la cual Isak se mueve de verdad y el tiempo
## quieto vuelve a 0 (entre los dos umbrales, ni cuenta ni se reinicia).
func reread_move_speed() -> float:
	return maxf(float(reread_config().get("move_speed_px_s", 40.0)), reread_still_speed())


## Tipos cuyo first_level es `level` (la migracion v2 -> v3 los da por
## aprendidos si ese nivel estaba completado).
func types_of_level(level: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _types:
		var e: Variant = _types[key]
		if e is Dictionary and String((e as Dictionary).get("first_level", "")) == String(level):
			out.append(StringName(String(key)))
	return out


static func _vec(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO
