## Ondas y golpes de la Combinacion (2026-10-29, docs/propuesta-mundo-5.md §3.2):
## la onda de la Embestida y del Sismo a ras de suelo y lo que el Filo atraviesa.
## La usan Isak y las pruebas. Los objetos de los combos (persianas, estanterias...)
## se enganchan a EventBus.combo_landed y miran ellos si la onda los alcanza.
class_name ComboWave
extends RefCounted

## Metodo que un enemigo puede tener para decidir el mismo (tipo, rect, dano, aturdimiento).
const RECEIVER_METHOD: StringName = &"receive_combo"


## Zona a ras de suelo con los pies en `feet`: de `left` a `right` (x globales),
## `height` por encima y `below` por debajo de los pies.
static func floor_rect(feet: Vector2, left: float, right: float, height: float, below: float) -> Rect2:
	return Rect2(left, feet.y - height, maxf(right - left, 0.0), height + below)


## Aplica la onda de `kind` a los enemigos del grupo enemy de `tree`: los que tienen
## receive_combo(kind, rect, damage, stun_s) deciden; a los demas que alcanza (por
## su get_body_rect) los aturde `stun_s` segundos (ShockwaveWave.stun_scale_for) y
## les hace `damage`. Devuelve cuantos alcanzo.
static func apply_to_enemies(tree: SceneTree, kind: StringName, rect: Rect2, damage: float, stun_s: float) -> int:
	if tree == null:
		return 0
	var hits: int = 0
	for node: Node in tree.get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_method(RECEIVER_METHOD):
			if bool(node.call(RECEIVER_METHOD, kind, rect, damage, stun_s)):
				hits += 1
			continue
		if not node.has_method(&"get_body_rect"):
			continue
		var body: Variant = node.call(&"get_body_rect")
		if not body is Rect2 or not rect.intersects(body as Rect2):
			continue
		var hit: bool = false
		if stun_s > 0.0 and node.has_method(&"stun"):
			node.call(&"stun", ShockwaveWave.stun_scale_for(node, stun_s))
			hit = true
		if damage > 0.0 and node.has_method(&"take_damage"):
			node.call(&"take_damage", damage)
			hit = true
		if hit:
			hits += 1
	return hits


## El Filo atraviesa `rect`: derrota a los enemigos que toca con vida entre 0 y
## `max_health` (les quita toda la vida); los que tienen receive_combo deciden.
## `done` guarda los ya tratados en este Filo (no se repiten). Devuelve cuantos derroto.
static func defeat_small(tree: SceneTree, rect: Rect2, max_health: float, done: Dictionary) -> int:
	if tree == null:
		return 0
	var hits: int = 0
	for node: Node in tree.get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion() or done.has(node.get_instance_id()):
			continue
		if not node.has_method(&"get_body_rect"):
			continue
		var body: Variant = node.call(&"get_body_rect")
		if not body is Rect2 or not rect.intersects(body as Rect2):
			continue
		done[node.get_instance_id()] = true
		if node.has_method(RECEIVER_METHOD):
			if bool(node.call(RECEIVER_METHOD, Isak.COMBO_EDGE, rect, max_health, 0.0)):
				hits += 1
			continue
		if not node.has_method(&"get_health") or not node.has_method(&"take_damage"):
			continue
		var health: float = float(node.call(&"get_health"))
		if health <= 0.0 or health > max_health + 0.0001:
			continue
		if bool(node.call(&"take_damage", health)):
			hits += 1
	return hits
