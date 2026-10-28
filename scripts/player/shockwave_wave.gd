## Onda de Agitar (2026-10-28, docs/propuesta-mundo-4.md §3.2.1): circulo de
## shockwave.radius_px alrededor del celular y su efecto en los enemigos. La usan
## Isak (al nacer la onda) y las pruebas. Los proyectiles de texto y lo que se
## borra con la onda (desde el paso 5) se enganchan a EventBus.shockwave_fired y
## miran ellos si la onda los alcanza (reaches()).
class_name ShockwaveWave
extends RefCounted

## Metodo que un enemigo puede tener para decidir el mismo (centro, radio, aturdimiento).
const RECEIVER_METHOD: StringName = &"receive_shockwave"


## Verdadero si el circulo (`center`, `radius`) toca `rect` (px globales).
static func reaches(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_to(closest) <= radius


## Aplica la onda a los enemigos del grupo enemy de `tree`: los que tienen
## receive_shockwave(center, radius, stun_s) deciden; a los demas que alcanza
## (por su get_body_rect) los aturde `stun_s` segundos con su stun() (escala
## respecto a su aturdimiento propio, stun_duration_s o stun_s). Sin
## dano. Devuelve cuantos alcanzo.
static func apply_to_enemies(tree: SceneTree, center: Vector2, radius: float, stun_s: float) -> int:
	if tree == null:
		return 0
	var hits: int = 0
	for node: Node in tree.get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_method(RECEIVER_METHOD):
			if bool(node.call(RECEIVER_METHOD, center, radius, stun_s)):
				hits += 1
			continue
		if not node.has_method(&"get_body_rect") or not node.has_method(&"stun"):
			continue
		var body: Variant = node.call(&"get_body_rect")
		if not body is Rect2 or not reaches(center, radius, body as Rect2):
			continue
		node.call(&"stun", stun_scale_for(node, stun_s))
		hits += 1
	return hits


## Propiedades con el aturdimiento propio de un enemigo (Mundo 1: stun_duration_s;
## Mundos 2-3: stun_s).
const OWN_STUN_PROPERTIES: Array[StringName] = [&"stun_duration_s", &"stun_s"]


## Escala de stun() para que `node` quede aturdido `stun_s` segundos: stun_s
## entre su aturdimiento propio si lo expone (todos los enemigos de hoy); 1 si no.
static func stun_scale_for(node: Object, stun_s: float) -> float:
	for property: StringName in OWN_STUN_PROPERTIES:
		var own: Variant = node.get(property)
		if (typeof(own) == TYPE_FLOAT or typeof(own) == TYPE_INT) and float(own) > 0.0:
			return maxf(stun_s, 0.0) / float(own)
	return 1.0
