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

## 1 derecha, -1 izquierda.
var direction: float = 1.0
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
	var distance: float = minf(speed_px_s * delta, range_px - _traveled)
	if distance <= 0.0:
		_finish(null, false)
		return
	var from_pos: Vector2 = global_position
	var to_pos: Vector2 = from_pos + Vector2(direction * distance, 0.0)
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
	if not result.is_empty():
		global_position = result["position"]
		_traveled += absf(global_position.x - from_pos.x)
		_on_collision(result.get("collider") as Node)
		return
	global_position = to_pos
	_traveled += distance
	queue_redraw()
	if _traveled >= range_px - 0.001:
		_finish(null, false)


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
	var visible_len: float = minf(length_px, _traveled)
	if visible_len <= 0.0:
		return
	var x0: float = -direction * visible_len
	var left: float = minf(x0, 0.0)
	var glow_h: float = thickness_px + 2.0 * _glow_px
	draw_rect(Rect2(Vector2(left, -glow_h * 0.5), Vector2(visible_len, glow_h)), Color(_glow, _glow_alpha))
	draw_rect(Rect2(Vector2(left, -thickness_px * 0.5), Vector2(visible_len, thickness_px)), _core)


## Rayo de la punta a `to` contra world y enemy; ignora Isak y las Area2D que no
## esten en GROUP_LASER_ACTIVATABLE.
func _cast(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from_pos, to_pos, LAYER_WORLD | LAYER_ENEMY)
	params.collide_with_areas = true
	params.hit_from_inside = true
	var exclude: Array[RID] = _pierced_rids.duplicate()
	if source is CollisionObject2D:
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
