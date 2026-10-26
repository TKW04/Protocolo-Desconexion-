## Proyectil del laser de Isak (decision del usuario 2026-10-15). Lo crea
## Isak._fire_laser() en el celular y vuela en horizontal (direction -1/1) a
## laser_speed_px_s hasta recorrer laser_range_px o chocar. Valores en
## data/isak_abilities.json (laser_*); aspecto PROVISIONAL dibujado por codigo
## (laser_visual, paleta del Mundo 1).
##
## Colision: en cada paso lanza un rayo desde la punta hasta la nueva punta
## contra los cuerpos de las capas world (terreno, pop-ups, puentes, plataforma
## de la Burbuja aturdida) y enemy. Las Area2D solo cuentan si estan en el
## grupo laser_activatable (las zonas de Eco, checkpoints, etc. no lo paran).
## Al chocar busca, en el colisionador y hasta MAX_PARENT_HOPS padres, el metodo
## on_laser_hit(damage: float, source: Node) y lo llama (enemigos: EnemyHealth).
##
## Interfaz para el entorno (IDEA, sin activaciones implementadas todavia,
## docs/preguntas.md): un objeto que deba reaccionar al laser implementa
## on_laser_hit(damage, source) y, si es una Area2D, se anade al grupo
## GROUP_LASER_ACTIVATABLE.
##
## Tiempo: real (es de Isak; el Debug no lo ralentiza).
##
## REBOTES (2026-10-26, paso 4 de docs/propuesta-mundo-3.md §3.4; espejos del
## Mundo 3): el haz vuela segun `heading` (vector unitario; horizontal al salir
## de Isak, pero tras un rebote puede ir en vertical o, con el espejo cazador
## del paso 6, en diagonal). Un colisionador cuyo nodo (o padres, como
## on_laser_hit) tenga REFLECT_METHOD, laser_reflection(projectile,
## hit_position) -> Dictionary, es un REFLECTOR: si devuelve {"heading":
## Vector2, "position": Vector2} el proyectil se coloca en position, sigue en
## heading con el alcance que le quedaba (lo recorrido cuenta hasta el punto de
## rebote) y emite bounced; si devuelve {} se trata como un choque normal (el
## reflector puede tener on_laser_hit: el 4.o espejo «consume» el disparo). El
## limite de rebotes lo decide el reflector con get_bounce_count() (Mirror,
## data/world3_objects.json mirror.max_bounces = 3). Tras un rebote el
## colisionador del reflector se excluye del rayo hasta el siguiente rebote (el
## haz sale desde dentro de el). exclude_source = false deja que el haz
## reflejado alcance a quien disparo (el cazador del paso 6 lo usara).
##
## PERFORA (Laser 5, tanda M2 de las mejoras de Calc, laser_pierce de
## isak_abilities con la mejora): el haz atraviesa a los ENEMIGOS (grupo enemy;
## tambien la plataforma del enemigo aturdido) y dana a cada uno una vez por
## disparo (destello pierce_spark de UpgradeFx), y sigue volando. NO atraviesa el
## terreno ni los objetos del laser (lector, anuncio, Posponer, interruptores,
## receptores: no son del grupo enemy), que lo paran igual que antes. Un enemigo
## inmune (el punto rojo despierto, is_laser_vulnerable falso) tambien lo para
## con su chispa gris.
class_name LaserProjectile
extends Node2D

## Ha alcanzado a `target` (el nodo con on_laser_hit) o, si es null, terreno.
signal hit(target: Node, damage: float)
## Se apaga sin chocar al llegar al alcance.
signal expired
## Ha atravesado a `target` (Laser 5) y sigue volando.
signal pierced(target: Node, damage: float)
## Ha rebotado en `reflector` en `at` (global) y sigue hacia `new_heading`.
signal bounced(reflector: Node, at: Vector2, new_heading: Vector2)

## Objetos del entorno (Area2D) que el laser debe tocar.
const GROUP_LASER_ACTIVATABLE: StringName = &"laser_activatable"
const HIT_METHOD: StringName = &"on_laser_hit"
## Bits de capa de fisica (project.godot, [layer_names]).
const LAYER_WORLD: int = 1
const LAYER_ENEMY: int = 4
## Padres que se suben buscando on_laser_hit (la plataforma de la Burbuja es
## hija de la Burbuja).
const MAX_PARENT_HOPS: int = 3
## Areas que se ignoran como mucho en un mismo paso (zonas de Eco seguidas).
const MAX_IGNORED_AREAS: int = 8
## Enemigos que se pueden atravesar como mucho en un mismo paso (Laser 5).
const MAX_PIERCES_PER_STEP: int = 8
## Grupo de los enemigos (lo que el laser que perfora atraviesa).
const GROUP_ENEMY: StringName = &"enemy"
const VULNERABLE_METHOD: StringName = &"is_laser_vulnerable"
## Interfaz de los reflectores (espejos): ver la cabecera.
const REFLECT_METHOD: StringName = &"laser_reflection"
## Rebotes que se resuelven como mucho en un mismo paso (salvaguarda).
const MAX_BOUNCES_PER_STEP: int = 8

## 1 derecha, -1 izquierda (sentido horizontal del disparo). Asignarlo pone
## `heading` en horizontal; tras un rebote vertical conserva el ultimo sentido.
var direction: float = 1.0:
	set(value):
		direction = -1.0 if value < 0.0 else 1.0
		heading = Vector2(direction, 0.0)
## Direccion de vuelo (unitaria). Ver REBOTES en la cabecera.
var heading: Vector2 = Vector2.RIGHT
## Si es false, el haz (tambien el reflejado) puede alcanzar a `source`.
var exclude_source: bool = true
var speed_px_s: float = 1200.0
var range_px: float = 768.0
var damage: float = 1.0
var length_px: float = 32.0
var thickness_px: float = 4.0
## Quien dispara (Isak); se pasa a on_laser_hit y se excluye del rayo.
var source: Node
## Laser 5: atraviesa enemigos (ver la cabecera).
var pierce: bool = false
## Si es false, _physics_process no avanza (las pruebas llaman a step()).
var auto_process: bool = true

var _core := Color("#f2f4f8")
var _glow := Color("#3dfff5")
var _impact_s: float = 0.12
var _impact_size_px: float = 12.0
var _glow_px: float = 2.0
var _glow_alpha: float = 0.5
var _traveled: float = 0.0
var _done: bool = false
var _impact_left: float = 0.0
var _hit_target: Node
## Laser 5: colisionadores ya atravesados (se excluyen del rayo) y enemigos ya danados.
var _pierced_rids: Array[RID] = []
var _pierced: Array[Node] = []
## Rebotes de este disparo, reflector excluido del rayo y recorrido desde el
## ultimo rebote (para el dibujo de la estela).
var _bounces: int = 0
var _reflector_rid: RID = RID()
var _segment_traveled: float = 0.0
var _bounce_points: Array[Vector2] = []


## Configura con los valores de `abilities` (PlayerAbilities).
func setup(abilities: PlayerAbilities, dir: float, from: Node) -> void:
	direction = -1.0 if dir < 0.0 else 1.0
	speed_px_s = abilities.laser_speed_px_s
	range_px = abilities.laser_range_px
	damage = abilities.laser_damage
	length_px = abilities.laser_length_px
	thickness_px = abilities.laser_thickness_px
	pierce = abilities.laser_pierce > 0.5
	source = from
	var visual: Dictionary = abilities.laser_visual
	_core = Color(String(visual.get("core", _core.to_html(false))))
	_glow = Color(String(visual.get("glow", _glow.to_html(false))))
	_impact_s = float(visual.get("impact_s", _impact_s))
	_impact_size_px = float(visual.get("impact_size_px", _impact_size_px))
	_glow_px = float(visual.get("glow_px", _glow_px))
	_glow_alpha = float(visual.get("glow_alpha", _glow_alpha))


func _physics_process(delta: float) -> void:
	if auto_process:
		step(delta)


## Un paso de `delta` segundos reales. Publico para las pruebas.
func step(delta: float) -> void:
	if _done:
		_impact_left -= delta
		queue_redraw()
		if _impact_left <= 0.0:
			queue_free()
		return
	var budget: float = minf(speed_px_s * delta, range_px - _traveled)
	if budget <= 0.0:
		_finish(null, false)
		return
	for guard: int in MAX_BOUNCES_PER_STEP + 1:
		var from_pos: Vector2 = global_position
		var to_pos: Vector2 = from_pos + heading * budget
		var result: Dictionary = _cast(from_pos, to_pos)
		# Laser 5: atraviesa enemigos y sigue el rayo desde alli en el mismo paso.
		var pierces: int = 0
		while pierce and not result.is_empty() and pierces < MAX_PIERCES_PER_STEP:
			var collider: Node = result.get("collider") as Node
			var target: Node = find_laser_target(collider)
			if not can_pierce(target):
				break
			_pierce(target, result["rid"], result["position"])
			pierces += 1
			result = _cast(result["position"], to_pos)
		if result.is_empty():
			global_position = to_pos
			_advance_traveled(budget)
			break
		var hit_pos: Vector2 = result["position"]
		var hit_collider: Node = result.get("collider") as Node
		var moved: float = from_pos.distance_to(hit_pos)
		var bounce: Dictionary = _ask_reflector(hit_collider, hit_pos)
		if bounce.is_empty() or guard >= MAX_BOUNCES_PER_STEP:
			global_position = hit_pos
			_advance_traveled(moved)
			_on_collision(hit_collider)
			return
		var at: Vector2 = bounce["position"]
		moved += hit_pos.distance_to(at)
		_advance_traveled(moved)
		redirect(bounce["heading"], at, find_reflector(hit_collider), result["rid"])
		budget -= moved
		if budget <= 0.0 or _traveled >= range_px - 0.001:
			break
	queue_redraw()
	if _traveled >= range_px - 0.001:
		_finish(null, false)


## Cambia la direccion del haz en `at` (global) hacia `new_heading` (se
## normaliza): cuenta un rebote, excluye `rid` (el colisionador del reflector)
## del rayo hasta el siguiente rebote y emite bounced. Lo usa step() con los
## reflectores; publico para el espejo cazador (paso 6) y las pruebas. No cambia
## el alcance: sigue con el que le quedaba.
func redirect(new_heading: Vector2, at: Vector2, reflector: Node = null, rid: RID = RID()) -> void:
	if _done or new_heading.is_zero_approx():
		return
	heading = new_heading.normalized()
	global_position = at
	_bounces += 1
	_reflector_rid = rid
	_segment_traveled = 0.0
	_bounce_points.append(at)
	queue_redraw()
	bounced.emit(reflector, at, heading)


## Rebotes hechos en este disparo.
func get_bounce_count() -> int:
	return _bounces


## Puntos (globales) donde ha rebotado, en orden.
func get_bounce_points() -> Array[Vector2]:
	return _bounce_points


## Alcance que le queda (px).
func get_remaining_range() -> float:
	return maxf(range_px - _traveled, 0.0)


func get_heading() -> Vector2:
	return heading


## Nodo reflector (con laser_reflection) en `node` o sus padres; null si no.
static func find_reflector(node: Node) -> Node:
	var current: Node = node
	for i: int in MAX_PARENT_HOPS + 1:
		if current == null:
			return null
		if current.has_method(REFLECT_METHOD):
			return current
		current = current.get_parent()
	return null


func _ask_reflector(collider: Node, hit_pos: Vector2) -> Dictionary:
	var reflector: Node = find_reflector(collider)
	if reflector == null:
		return {}
	var answer: Variant = reflector.call(REFLECT_METHOD, self, hit_pos)
	if answer is Dictionary and (answer as Dictionary).has("heading") and (answer as Dictionary).has("position"):
		return answer
	return {}


func _advance_traveled(distance: float) -> void:
	_traveled += distance
	_segment_traveled += distance


## Choca ya con `target` (un objeto con on_laser_hit) sin volar: lo usan los
## objetivos del entorno pegados a Isak (2026-10-16, lector laser y anuncio del
## 1-2), que el rayo no ve si el celular ya esta dentro de ellos o de la pared
## de detras. Sin efecto si el proyectil ya termino.
func strike(target: Node) -> void:
	if _done:
		return
	_on_collision(target)


## Verdadero si el tramo horizontal de Isak (source) a la boca del disparo, a la
## altura del celular, cruza `rect` (coordenadas globales): el objetivo esta entre
## Isak y el punto donde nace el proyectil, asi que el rayo no lo veria.
static func muzzle_crosses(projectile: Node2D, rect: Rect2) -> bool:
	if projectile == null or not is_instance_valid(projectile):
		return false
	var muzzle: Vector2 = projectile.global_position
	if muzzle.y < rect.position.y or muzzle.y > rect.end.y:
		return false
	var from_x: float = muzzle.x
	var shooter: Variant = projectile.get(&"source")
	if shooter is Node2D and is_instance_valid(shooter):
		from_x = (shooter as Node2D).global_position.x
	return maxf(from_x, muzzle.x) >= rect.position.x and minf(from_x, muzzle.x) <= rect.end.x


func is_finished() -> bool:
	return _done


## Enemigos atravesados por este disparo (Laser 5).
func get_pierced() -> Array[Node]:
	return _pierced


## Laser 5: `target` (el nodo con on_laser_hit) se puede atravesar: es un
## enemigo y el laser le hace dano ahora. Nunca el terreno ni los objetos del
## laser (no son del grupo enemy) ni un enemigo inmune (el punto rojo despierto).
func can_pierce(target: Node) -> bool:
	if not pierce or target == null or not is_instance_valid(target) or not target.is_in_group(GROUP_ENEMY):
		return false
	if target.has_method(VULNERABLE_METHOD) and not bool(target.call(VULNERABLE_METHOD)):
		return false
	return true


## Distancia recorrida desde el celular (px).
func get_traveled() -> float:
	return _traveled


## Nodo alcanzado (con on_laser_hit) o null.
func get_hit_target() -> Node:
	return _hit_target


func _draw() -> void:
	if _done:
		if _impact_left > 0.0:
			var size: float = _impact_size_px
			draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), _glow)
			draw_rect(Rect2(Vector2(-thickness_px * 0.5, -thickness_px * 0.5), Vector2(thickness_px, thickness_px)), _core)
		return
	# Haz detras de la punta (sin pasar por detras del celular al salir).
	# Se dibuja en el eje de `heading` (horizontal, vertical o diagonal); tras un
	# rebote la estela empieza en el espejo.
	var visible_len: float = minf(length_px, _segment_traveled)
	if visible_len <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, heading.angle())
	var glow_h: float = thickness_px + 2.0 * _glow_px
	draw_rect(Rect2(Vector2(-visible_len, -glow_h * 0.5), Vector2(visible_len, glow_h)), Color(_glow, _glow_alpha))
	draw_rect(Rect2(Vector2(-visible_len, -thickness_px * 0.5), Vector2(visible_len, thickness_px)), _core)
	draw_set_transform(Vector2.ZERO)


## Rayo de la punta a `to` contra world y enemy; ignora Isak y las Area2D que no
## esten en GROUP_LASER_ACTIVATABLE.
func _cast(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from_pos, to_pos, LAYER_WORLD | LAYER_ENEMY)
	params.collide_with_areas = true
	params.hit_from_inside = true
	var exclude: Array[RID] = _pierced_rids.duplicate()
	if _reflector_rid.is_valid():
		exclude.append(_reflector_rid)
	if exclude_source and source is CollisionObject2D:
		exclude.append((source as CollisionObject2D).get_rid())
	for i: int in MAX_IGNORED_AREAS:
		params.exclude = exclude
		var result: Dictionary = space.intersect_ray(params)
		if result.is_empty():
			return result
		var collider: Object = result.get("collider")
		if collider is Area2D and not (collider as Area2D).is_in_group(GROUP_LASER_ACTIVATABLE):
			exclude.append(result["rid"])
			continue
		return result
	return {}


## Atraviesa a `target` (una vez por enemigo y disparo): le hace el dano, pinta el
## destello y excluye su colisionador del rayo.
func _pierce(target: Node, rid: RID, at: Vector2) -> void:
	_pierced_rids.append(rid)
	if _pierced.has(target):
		return
	_pierced.append(target)
	target.call(HIT_METHOD, damage, source)
	pierced.emit(target, damage)
	UpgradeFx.spawn(get_parent() if get_parent() != null else self, UpgradeFx.PIERCE_SPARK, at)


func _on_collision(collider: Node) -> void:
	var target: Node = find_laser_target(collider)
	if target != null:
		target.call(HIT_METHOD, damage, source)
	_finish(target, true)


## Nodo con on_laser_hit en `node` o sus padres (hasta MAX_PARENT_HOPS); null si no.
static func find_laser_target(node: Node) -> Node:
	var current: Node = node
	for i: int in MAX_PARENT_HOPS + 1:
		if current == null:
			return null
		if current.has_method(HIT_METHOD):
			return current
		current = current.get_parent()
	return null


func _finish(target: Node, collided: bool) -> void:
	_done = true
	_hit_target = target
	_impact_left = _impact_s if collided else 0.0
	queue_redraw()
	if collided:
		hit.emit(target, damage)
	else:
		expired.emit()
