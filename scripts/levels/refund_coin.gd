## Moneda de lo que robo una Suscripcion (2026-10-30, peticion del usuario tras jugar el
## Mundo 5; docs/propuesta-mundo-5.md §8.1, cambio «la Suscripcion devuelve lo robado»).
## Al derrotarla (laser, Filo, Embestida) o cancelarla (pulso, golpe al suelo, Sismo) la
## Suscripcion lanza en arco una moneda por cada punto drenado que aun no devolvio (o por
## cada `energy_per_coin` de energia en el «te fio» de El Vendedor). Cada moneda cae, se
## posa en el suelo y se recoge al tocarla: un punto vuelve al saldo sacandolo del
## registro de Devoluciones (GameState.reclaim_refundable: nunca se devuelve dos veces ni
## se pasa de lo robado) o la energia vuelve a la barra (acotada al maximo). Si no se
## recoge en `lifetime_s` (parpadea los ultimos `blink_s`) desaparece y lo que queda en el
## registro sigue en Devoluciones. Valores en la seccion refund_coins de
## data/enemies/subscription.json. Aspecto PROVISIONAL por codigo: rombo del icono de
## puntos (o del color del Debug para la energia) con contorno oscuro.
class_name RefundCoin
extends Area2D

signal collected(kind: StringName, amount: float)
signal expired

const KIND_POINTS: StringName = &"attention_points"
const KIND_ENERGY: StringName = &"debug_energy"
const GROUP: StringName = &"refund_coin"
const PLAYER_LAYER: int = 2
const WORLD_LAYER: int = 1

var kind: StringName = KIND_POINTS
## Puntos (1) o energia que devuelve.
var amount: float = 1.0
## Nivel y tipo del registro de Devoluciones del que sale el punto.
var refund_level: StringName = &""
var refund_kind: StringName = &""

var lifetime_s: float = 6.0
var blink_s: float = 2.0
var arm_delay_s: float = 0.35
var gravity_px_s2: float = 1800.0
var radius_px: float = 12.0
var velocity: Vector2 = Vector2.ZERO

var _age: float = 0.0
var _taken: bool = false
var _landed: bool = false


## Lanza `count` monedas de `kind` desde `origin` (global) como hijas de `parent`, en
## abanico hacia arriba. `amounts` (opcional) da la cantidad de cada una (por defecto 1).
static func launch(parent: Node, origin: Vector2, count: int, coin_kind: StringName, cfg: Dictionary,
		level: StringName = &"", refund: StringName = &"", amounts: Array = []) -> Array[RefundCoin]:
	var out: Array[RefundCoin] = []
	if parent == null or count <= 0:
		return out
	var speed: float = float(cfg.get("launch_speed_px_s", 420.0))
	var spread_deg: float = float(cfg.get("spread_deg", 100.0))
	for i: int in count:
		var coin := RefundCoin.new()
		coin.kind = coin_kind
		coin.amount = float(amounts[i]) if i < amounts.size() else 1.0
		coin.refund_level = level
		coin.refund_kind = refund
		coin.lifetime_s = float(cfg.get("lifetime_s", 6.0))
		coin.blink_s = float(cfg.get("blink_s", 2.0))
		coin.arm_delay_s = float(cfg.get("arm_delay_s", 0.35))
		coin.gravity_px_s2 = float(cfg.get("gravity_px_s2", 1800.0))
		coin.radius_px = float(cfg.get("radius_px", 12.0))
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var deg: float = -90.0 + (t - 0.5) * spread_deg
		coin.velocity = Vector2.RIGHT.rotated(deg_to_rad(deg)) * speed * (0.85 + 0.15 * float(i % 2))
		coin.name = "RefundCoin_%d" % i
		parent.add_child(coin)
		coin.global_position = origin
		out.append(coin)
	return out


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_px + 6.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos del mundo: vuelo en arco, posado, recogida y caducidad.
func advance(dt: float) -> void:
	if _taken:
		return
	_age += dt
	if _age >= lifetime_s:
		_taken = true
		expired.emit()
		queue_free()
		return
	if not _landed:
		velocity.y += gravity_px_s2 * dt
		var motion: Vector2 = velocity * dt
		var hit: Dictionary = _ray(global_position, global_position + motion + Vector2(0.0, radius_px) * signf(motion.y))
		var normal: Vector2 = Vector2(hit.get("normal", Vector2.ZERO))
		if not hit.is_empty() and normal.y < -0.5:
			global_position = Vector2(hit["position"]) - Vector2(0.0, radius_px)
			velocity = Vector2.ZERO
			_landed = true
		elif not hit.is_empty():
			# Pared o techo: pierde la componente que choca y sigue cayendo.
			if absf(normal.x) > 0.5:
				velocity.x = 0.0
			if normal.y > 0.5:
				velocity.y = 0.0
		else:
			global_position += motion
	if is_armed():
		for body: Node2D in get_overlapping_bodies():
			if body is Isak:
				collect()
				return
	queue_redraw()


func is_armed() -> bool:
	return _age >= arm_delay_s


func is_taken() -> bool:
	return _taken


func is_landed() -> bool:
	return _landed


func is_blinking() -> bool:
	return not _taken and _age >= lifetime_s - blink_s


func get_time_left() -> float:
	return maxf(lifetime_s - _age, 0.0)


## Devuelve lo suyo (una sola vez) y se libera. Los puntos salen del registro de
## Devoluciones: si ya se devolvieron alli, la moneda no da nada.
func collect() -> bool:
	if _taken:
		return false
	_taken = true
	var given: float = 0.0
	match kind:
		KIND_POINTS:
			given = float(GameState.reclaim_refundable(refund_level, refund_kind, int(round(amount))))
		KIND_ENERGY:
			var before: float = GameState.debug_energy
			GameState.add_debug_energy(amount)
			given = GameState.debug_energy - before
	collected.emit(kind, given)
	queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is Isak and is_armed():
		collect()


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	if not is_inside_tree() or from.is_equal_approx(to):
		return {}
	var space := get_world_2d().direct_space_state
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER)
	q.collide_with_areas = false
	return space.intersect_ray(q)


func _draw() -> void:
	if _taken:
		return
	if is_blinking() and int(_age * 8.0) % 2 == 1:
		return
	var fill: Color = HudConfig.shared().color(&"attention_icon")
	if kind == KIND_ENERGY:
		fill = World5ObjectsConfig.color("debug_blanco", Color("#ffffff"))
	var outline: Color = World5ObjectsConfig.color("tienda_noche", Color("#140f1e"))
	var r: float = radius_px
	var outer := PackedVector2Array([Vector2(0, -r - 2), Vector2(r + 2, 0), Vector2(0, r + 2), Vector2(-r - 2, 0)])
	var inner := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	draw_colored_polygon(outer, outline)
	draw_colored_polygon(inner, fill)
