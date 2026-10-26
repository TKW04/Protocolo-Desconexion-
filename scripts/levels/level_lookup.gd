## Busquedas comunes de los objetos del nivel (2026-10-16, pasos 6-8 de
## docs/propuesta-1-2.md §10): Isak sin grupos ni consultas de fisica (el nivel
## generado y las salas de prueba lo tienen como hijo "Isak" de la raiz).
class_name LevelLookup
extends RefCounted


## El Isak del nivel de `from`: el primer ancestro con un hijo "Isak" de tipo Isak.
static func find_isak(from: Node) -> Isak:
	var node: Node = from
	while node != null:
		var isak := node.get_node_or_null(^"Isak") as Isak
		if isak != null:
			return isak
		node = node.get_parent()
	return null


## Rectangulo aproximado del cuerpo de Isak (pies en su origen), en coordenadas globales.
static func isak_body_rect(isak: Isak) -> Rect2:
	var size: Vector2 = isak.get_hitbox_size()
	var feet: Vector2 = isak.global_position
	return Rect2(feet.x - size.x * 0.5, feet.y - size.y, size.x, size.y)
