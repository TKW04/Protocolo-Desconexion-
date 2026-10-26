## Likes del Mundo 3 en un nivel (2026-10-26, paso 2 de docs/propuesta-mundo-3.md
## §8, §3.1): nodo «Likes» que GeneratedLevel anade a los niveles del Mundo 3.
## - Al entrar al nivel el contador empieza en 0 (GameState.reset_likes; con
##   LevelRunner tambien lo hace begin_attempt).
## - Golpe recibido (senal hurt de Isak, sin tocar Isak): quita hit_loss likes (3)
##   y salen como corazones (HeartPickup con `dropped`) alrededor de Isak que
##   parpadean drop_blink_s y se pueden recoger otra vez. Sin likes, nada.
## - La muerte (vuelta al valor del punto de sincronizacion) la hace GameState con
##   EventBus.player_respawned; el aviso «Los likes no se guardan.» al terminar el
##   nivel, HudLikes.
## Valores en la seccion likes de data/world3_objects.json.
class_name LikesSystem
extends Node

const WORLD: int = 3
const NODE_NAME: String = "Likes"

## Un golpe ha quitado `lost` likes (soltados como corazones).
signal likes_dropped(lost: int)

var _cfg: Dictionary = World3ObjectsConfig.section("likes")
var _isak: Isak


## Anade el sistema a `level` (si no lo tiene ya) y lo devuelve.
static func attach(level: Node) -> LikesSystem:
	var existing := level.get_node_or_null(NODE_NAME) as LikesSystem
	if existing != null:
		return existing
	var system := LikesSystem.new()
	system.name = NODE_NAME
	level.add_child(system)
	return system


func _ready() -> void:
	GameState.reset_likes()
	# Las plataformas del nivel se pusieron en su estado antes que este nodo: sin aviso.
	var level: Node = get_parent()
	for node: Node in get_tree().get_nodes_in_group(LikePlatform.GROUP):
		if level != null and level.is_ancestor_of(node):
			(node as LikePlatform).snap()
	_isak = LevelLookup.find_isak(get_parent() if get_parent() != null else self)
	if _isak != null and not _isak.hurt.is_connected(on_hit):
		_isak.hurt.connect(on_hit)


func get_isak() -> Isak:
	return _isak


## Golpe recibido: quita hit_loss likes y los suelta como corazones. Devuelve
## los corazones creados (publico para las pruebas).
func on_hit() -> Array[HeartPickup]:
	var lost: int = GameState.lose_likes(int(_cfg.get("hit_loss", 3)))
	var hearts: Array[HeartPickup] = []
	if lost <= 0:
		return hearts
	var feet: Vector2 = _isak.global_position if _isak != null and is_instance_valid(_isak) else Vector2.ZERO
	hearts = drop_hearts(get_parent(), feet, lost)
	likes_dropped.emit(lost)
	return hearts


## Crea `count` corazones soltados de 1 like cada uno, repartidos por encima de
## `feet` (px globales) como hijos de `host`.
func drop_hearts(host: Node, feet: Vector2, count: int) -> Array[HeartPickup]:
	var out: Array[HeartPickup] = []
	var spread: float = float(_cfg.get("drop_spread_px", 28))
	var rise: float = float(_cfg.get("drop_rise_px", 48))
	for i: int in count:
		var heart := HeartPickup.new()
		heart.name = "DroppedHeart"
		heart.dropped = true
		heart.value = 1
		host.add_child(heart, true)
		var side: float = (float(i) - float(count - 1) * 0.5) * spread
		heart.global_position = feet + Vector2(side, -rise - absf(side) * 0.25)
		out.append(heart)
	return out
