## Piezas comunes del acertijo de la azotea del 1-2 (encuentro con Calc,
## 2026-10-17, tanda H1 del paso 14; docs/propuesta-calc-encuentro.md):
## interruptor de pulso y panel oculto (PowerSwitch), interruptor laser
## (LaserSwitch), pared con glitch que se vuelve puerta (GlitchWall con
## door_when), cuarto a oscuras (DarkRoom), punto de carga (ChargeDock), Calc
## (CalcActor), terminal con corriente (ExitTerminal.requires_power) y el guion
## de Eco (EcoGuide).
## - Enlaces por id: cada pieza esta en el grupo LINK_GROUP con su object_id;
##   las demas la buscan con find() (dentro del mismo nivel).
## - «Hecho» comun: is_activated() (interruptores, puerta transformada, punto de
##   carga terminado).
## - Un solo uso (regla de los objetos de historia del proyecto): con
##   done_if_ally (p. ej. "calc") y ese asistente ya conocido al cargar el
##   nivel, la pieza arranca resuelta e inerte (sin Q), Calc no esta y la
##   terminal tiene corriente.
class_name CalcRoom
extends RefCounted

const LINK_GROUP: StringName = &"calc_room_link"


## Pieza con `id` en el mismo arbol que `from` (dentro de su nivel si lo hay).
static func find(from: Node, id: StringName) -> Node:
	if from == null or id == &"" or not from.is_inside_tree():
		return null
	var scope: Node = _level_of(from)
	for node: Node in from.get_tree().get_nodes_in_group(LINK_GROUP):
		if StringName(String(node.get(&"object_id"))) == id and (scope == null or scope.is_ancestor_of(node)):
			return node
	return null


## La pieza `node` ya esta hecha (is_activated()).
static func is_done(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.has_method(&"is_activated") \
		and bool(node.call(&"is_activated"))


## Todas las piezas `ids` estan hechas (vacio: verdadero).
static func all_done(from: Node, ids: Array) -> bool:
	for id: Variant in ids:
		if not is_done(find(from, StringName(String(id)))):
			return false
	return true


## Cuantas de las piezas `ids` estan hechas.
static func count_done(from: Node, ids: Array) -> int:
	var n: int = 0
	for id: Variant in ids:
		if is_done(find(from, StringName(String(id)))):
			n += 1
	return n


## El acertijo ya no hace falta: `ally` ("" = nunca) ya es conocido.
static func skipped_for(ally: StringName) -> bool:
	return ally != &"" and GameState.has_met_ally(ally)


## Isak del nivel de `from` (hijo «Isak» del nivel o del primer antepasado que lo tenga).
static func find_isak(from: Node) -> Isak:
	var n: Node = from
	while n != null:
		var isak := n.get_node_or_null(^"Isak") as Isak
		if isak != null:
			return isak
		n = n.get_parent()
	return null


static func _level_of(node: Node) -> Node:
	var n: Node = node
	while n != null:
		if n.is_in_group(GeneratedLevel.GROUP):
			return n
		n = n.get_parent()
	return null
