## Raiz de una escena de nivel generada por tools/build_level.py desde
## data/levels/<id>.json (no editar la escena a mano: se regenera).
##
## Al entrar en el arbol fija el nivel y el mundo actuales en GameState y aplica
## `abilities_available` del JSON (en el 1-1: pulso si, Debug no); al salir
## restaura el estado de las habilidades que habia antes. Las habilidades
## obtenidas para siempre (GameState.obtained_abilities, p. ej. el laser) no se
## bloquean ni al entrar ni al salir. Tras el _ready de los
## hijos aplica los `params` de cada enemigo (metadata "params" del nodo) a sus
## propiedades. Muerte, reaparicion, checkpoints activos y final del nivel no
## estan aqui (paso 16); las senales de los objetos siguen yendo al EventBus.
class_name GeneratedLevel
extends Node2D

const GROUP: StringName = &"level"
## Param del JSON -> propiedad del nodo, cuando el nombre no coincide.
## `health` (2026-10-15): vida del enemigo en ese nivel (sobrescribe la de su JSON).
const ENEMY_PARAM_ALIASES: Dictionary = {"patrol_speed_px_s": "speed_px_s", "health": "max_health"}
const ENEMY_PARAMS_META: StringName = &"params"

@export var level_id: String = ""
@export var level_name: String = ""
@export var world: int = 1
@export var tile_size: int = 64
## Tamano del grid en tiles (columnas, filas).
@export var size_tiles: Vector2i = Vector2i.ZERO
@export var debug_color: String = ""
## Habilidades del nivel ({"pulse": true, "debug": false}).
@export var abilities_available: Dictionary = {}
## Multiplicador del gasto del Debug en este nivel (debug_drain_scale del JSON;
## 1 = normal; la arena de Alerta Mayor, 0,5). Se aplica al entrar y vuelve a 1
## al salir (paso 4 de docs/propuesta-jefe-alerta-mayor.md §6).
@export var debug_drain_scale: float = 1.0
## JSON de origen.
@export var source_path: String = ""

var _previous_abilities: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)
	GameState.current_level = StringName(level_id)
	GameState.current_world = world
	_previous_abilities.clear()
	for key: Variant in abilities_available:
		var ability := StringName(String(key))
		if GameState.is_ability_obtained(ability):
			continue
		_previous_abilities[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, bool(abilities_available[key]))
	if not is_ability_available(GameState.ABILITY_DEBUG):
		DebugMode.reset()
	DebugMode.set_level_drain_scale(debug_drain_scale)


func _ready() -> void:
	_apply_enemy_params()
	# Arena de jefe (2026-10-21): los objetos y enemigos con active_in_phase
	# empiezan inactivos; el jefe los activa en sus fases.
	BossBase.apply_phase_nodes(self, 0)


func _exit_tree() -> void:
	if not is_ability_available(GameState.ABILITY_DEBUG):
		DebugMode.reset()
	DebugMode.set_level_drain_scale(1.0)
	for ability: StringName in _previous_abilities:
		if GameState.is_ability_obtained(ability):
			continue
		GameState.set_ability_unlocked(ability, bool(_previous_abilities[ability]))
	_previous_abilities.clear()


func is_ability_available(ability: StringName) -> bool:
	return bool(abilities_available.get(String(ability), false))


## Tamano del nivel en px (los limites de la camara de Isak).
func get_size_px() -> Vector2i:
	return size_tiles * tile_size


func get_isak() -> Isak:
	return get_node_or_null(^"Isak") as Isak


func _apply_enemy_params() -> void:
	var enemies: Node = get_node_or_null(^"Enemies")
	if enemies == null:
		return
	for enemy: Node in enemies.get_children():
		var params: Dictionary = enemy.get_meta(ENEMY_PARAMS_META, {})
		for key: Variant in params:
			var property: String = String(ENEMY_PARAM_ALIASES.get(String(key), String(key)))
			if property in enemy:
				enemy.set(property, params[key])
			else:
				push_warning("GeneratedLevel: %s no tiene la propiedad '%s'" % [enemy.name, property])
