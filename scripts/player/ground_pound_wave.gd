## Onda del golpe al suelo (2026-10-22, docs/propuesta-mundo-2.md §3.3.1): zona a
## ras de suelo y su efecto en los enemigos. La usan Isak (al aterrizar) y las
## pruebas. Los objetos (tarjeta fragil, muro «Cargando mas...») se enganchan a
## EventBus.ground_pound_landed y miran ellos si la onda los alcanza.
class_name GroundPoundWave
extends RefCounted

## Metodo que un enemigo puede tener para decidir el mismo (rect, dano).
const RECEIVER_METHOD: StringName = &"receive_ground_pound"
## Metodo de un collider (o de su padre) que dice si se acaba de romper con el
## golpe: Isak sigue cayendo a traves de el.
const BROKEN_METHOD: StringName = &"is_broken_by_pound"


## Zona de la onda con los pies en `feet` (global): wave_half_width_px a cada
## lado, wave_height_px por encima y wave_below_px por debajo de los pies.
static func rect_at(feet: Vector2, abilities: PlayerAbilities) -> Rect2:
	var half: float = abilities.pound_wave_half_width_px
	var height: float = abilities.pound_wave_height_px
	return Rect2(feet.x - half, feet.y - height, half * 2.0, height + abilities.pound_wave_below_px)


## Aplica la onda a los enemigos del grupo enemy de `tree`: los que tienen
## receive_ground_pound(rect, dano) deciden; a los demas que alcanza (por su
## get_body_rect) los aturde (su aturdimiento propio) y les hace `damage`.
## Devuelve cuantos alcanzo.
static func apply_to_enemies(tree: SceneTree, rect: Rect2, damage: float) -> int:
	if tree == null:
		return 0
	var hits: int = 0
	for node: Node in tree.get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_method(RECEIVER_METHOD):
			if bool(node.call(RECEIVER_METHOD, rect, damage)):
				hits += 1
			continue
		if not node.has_method(&"get_body_rect"):
			continue
		var body: Variant = node.call(&"get_body_rect")
		if not body is Rect2 or not rect.intersects(body as Rect2):
			continue
		var hit: bool = false
		if node.has_method(&"stun"):
			node.call(&"stun", 1.0)
			hit = true
		if damage > 0.0 and node.has_method(&"take_damage"):
			node.call(&"take_damage", damage)
			hit = true
		if hit:
			hits += 1
	return hits


## Verdadero si `collider` (o su padre) se acaba de romper con el golpe.
static func is_broken(collider: Object) -> bool:
	var node := collider as Node
	for i: int in 2:
		if node == null:
			return false
		if node.has_method(BROKEN_METHOD) and bool(node.call(BROKEN_METHOD)):
			return true
		node = node.get_parent()
	return false
