## Reaparicion de los enemigos tras caer por un barranco (2026-10-30, peticion del usuario
## tras jugar el Mundo 5: «cuando te caes por un barranco pierdas una vida, y que los mobs
## hagan respawn pero los secretos que ya tomaste te queden con ellos»; docs/propuesta-mundo-5.md
## §8.1 y docs/propuesta-asistentes-y-vidas.md §5).
##
## Al empezar un intento (LevelRunner.start_level) se apunta, desde el SceneState de la escena
## generada del nivel, cada enemigo hijo directo de «Enemies» (escena, propiedades del nivel,
## metadatos y grupos). Tras una caida, `restore` recrea los que ya no estan o estan derrotados
## (is_defeated) como al empezar el nivel, con sus params (GeneratedLevel.apply_enemy_params_to);
## los vivos solo vuelven a su sitio (reset_patrol, como siempre). Solo toca «Enemies»: los
## objetos (puntos, recuerdos, vidas extra, power banks, cajas, puertas, cargadores...) siguen
## como estaban, asi que lo recogido de los secretos se conserva. Las arenas de jefe no usan
## esto (el jefe lleva su propia pelea).
class_name EnemyRespawn
extends RefCounted

const ENEMIES_NODE: String = "Enemies"
const DEFEATED_STATES: Array[StringName] = [&"popped", &"defeated", &"dead", &"destroyed", &"broken"]


## Plantillas de los enemigos de «Enemies» en `packed` (escena generada de un nivel):
## [{name, scene: PackedScene, props: {propiedad: valor}, groups: [StringName]}].
static func capture(packed: PackedScene) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if packed == null:
		return out
	var state: SceneState = packed.get_state()
	for i: int in state.get_node_count():
		var path: String = String(state.get_node_path(i))
		var parent: String = String(state.get_node_path(i, true))
		if parent.trim_prefix("./") != ENEMIES_NODE:
			continue
		var scene: PackedScene = state.get_node_instance(i)
		if scene == null:
			continue
		var props: Dictionary = {}
		for p: int in state.get_node_property_count(i):
			props[String(state.get_node_property_name(i, p))] = state.get_node_property_value(i, p)
		var groups: Array[StringName] = []
		for g: StringName in state.get_node_groups(i):
			groups.append(g)
		out.append({"name": path.get_file(), "scene": scene, "props": props, "groups": groups})
	return out


## Recrea en `level` los enemigos de `templates` que faltan o estan derrotados. Devuelve
## los nombres recreados.
static func restore(level: GeneratedLevel, templates: Array[Dictionary]) -> Array[StringName]:
	var done: Array[StringName] = []
	if level == null or templates.is_empty():
		return done
	var root: Node = level.get_node_or_null(NodePath(ENEMIES_NODE))
	if root == null:
		return done
	for t: Dictionary in templates:
		var name := StringName(String(t["name"]))
		var old: Node = root.get_node_or_null(NodePath(String(name)))
		if old != null and not old.is_queued_for_deletion() and not _is_defeated(old):
			continue
		var index: int = -1
		if old != null:
			index = old.get_index()
			root.remove_child(old)
			old.queue_free()
		var enemy: Node = (t["scene"] as PackedScene).instantiate()
		var props: Dictionary = t["props"]
		for key: String in props:
			enemy.set(key, props[key])
		enemy.name = String(name)
		for g: StringName in t["groups"]:
			enemy.add_to_group(g, true)
		root.add_child(enemy)
		if index >= 0:
			root.move_child(enemy, mini(index, root.get_child_count() - 1))
		# Como al cargar el nivel: los params se aplican tras el _ready del enemigo.
		level.apply_enemy_params_to(enemy)
		done.append(name)
	return done


## Derrotado: is_defeated() o un estado final (la Burbuja reventada, popped).
static func _is_defeated(node: Node) -> bool:
	if node.has_method(&"is_defeated") and bool(node.call(&"is_defeated")):
		return true
	return node.has_method(&"get_state") and StringName(str(node.call(&"get_state"))) in DEFEATED_STATES
