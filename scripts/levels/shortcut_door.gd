## Atajo (tipo `shortcut_door` del catalogo del Mundo 5; 2026-10-29, paso 3 de
## docs/propuesta-mundo-5.md §8 y §3.7). Puerta SOLIDA de 1 x height_tiles desde su
## celda con el cartel «Atajo: N ◆». Un PULSO DE ESPALDAS (PayPoint) paga con el saldo
## real (GameState.spend_attention; sin saldo, «Saldo insuficiente» y chispa gris) y la
## abre para el resto del intento (un uso por intento: el nivel se crea de nuevo en cada
## intento). Lo pagado en una puerta CON trampa va al registro de Devoluciones
## (GameState.REFUND_SHORTCUT_TRAP). La trampa salta la primera vez que Isak cruza la
## puerta abierta:
## - processing («Verificando pago…»): Isak.freeze(processing_s) con el FrozenState del
##   Mundo 4 y su golpe al liberarse;
## - subscription (paso 4): una Suscripcion «te espera dentro»: sale avisando a
##   trap_distance_tiles tiles de la puerta hacia donde va Isak y lo persigue;
## - offer (paso 4): una Oferta de pie a esa distancia, al pie de la puerta (el nivel
##   pone los pinchos junto a ella: «tiron hacia pinchos al salir»);
## - countdown (paso 5): «la salida es una cuenta regresiva»: pone en marcha las
##   CountdownPlatform del nivel con trigger_id = el id de esta puerta (esperan solidas
##   y sin cuenta hasta entonces).
## Lo que sale de la trampa: get_trap_spawn().
## Con el Debug (DebugMode.is_revealing) se ve el icono de la trampa en la puerta.
## Aspecto PROVISIONAL por codigo (seccion shortcut_door de data/world5_objects.json).
class_name ShortcutDoor
extends PayPoint

const GROUP: StringName = &"shortcut_door"
const TRAP_NONE: StringName = &""
const TRAP_SUBSCRIPTION: StringName = &"subscription"
const TRAP_OFFER: StringName = &"offer"
const TRAP_COUNTDOWN: StringName = &"countdown"
const TRAP_PROCESSING: StringName = &"processing"
const TRAPS: Array[StringName] = [TRAP_NONE, TRAP_SUBSCRIPTION, TRAP_OFFER, TRAP_COUNTDOWN, TRAP_PROCESSING]
## Fuente del congelado de la trampa processing (Isak.freeze; sin la inmunidad de las zonas).
const FREEZE_SOURCE: StringName = &"shortcut_processing"
const LAYER_WORLD: int = 1
const TILE: float = 64.0
const OFFER_SCENE_PATH: String = "res://scenes/enemies/offer_sign.tscn"

## Pagado: la puerta se abre.
signal paid(cost: int)
## Isak cruza la puerta abierta y salta su trampa.
signal trap_sprung(trap: StringName)

## Precio propio (params.cost); -1 = prices.shortcut_door de data/economy.json.
@export var cost: int = -1
## Trampa (params.trap): '' (atajo legitimo), subscription, offer, countdown o processing.
@export var trap: StringName = TRAP_NONE:
	set(value):
		var t := StringName(value)
		if not TRAPS.has(t):
			push_warning("ShortcutDoor: trampa '%s' desconocida; sin trampa" % t)
			t = TRAP_NONE
		trap = t
		queue_redraw()
## Distancia (tiles) de la puerta a la que sale la Suscripcion o la Oferta de la trampa.
@export var trap_distance_tiles: int = 2
@export var height_tiles: int = 3:
	set(value):
		height_tiles = maxi(value, 1)
		_update_body()

var _open: bool = false
var _sprung: bool = false
var _trap_spawn: Node
var _body: StaticBody2D
var _shape: CollisionShape2D


func _section_name() -> String:
	return "shortcut_door"


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_body.add_child(_shape)
	add_child(_body)
	_update_body()


# --- Consultas ---

func get_cost() -> int:
	return cost if cost >= 0 else int(price_section("shortcut_door").get("cost", 3))


func has_trap() -> bool:
	return trap != TRAP_NONE


func is_open() -> bool:
	return _open


func is_trap_sprung() -> bool:
	return _sprung


## Lo que ha sacado la trampa (Subscription u OfferSign), o null.
func get_trap_spawn() -> Node:
	return _trap_spawn if _trap_spawn != null and is_instance_valid(_trap_spawn) else null


## Pies (global) de lo que saca la trampa hacia `direction` (+1 derecha, -1 izquierda).
func get_trap_spawn_feet(direction: float) -> Vector2:
	var door: Rect2 = get_door_rect()
	var dir: float = 1.0 if direction >= 0.0 else -1.0
	return Vector2(door.get_center().x + dir * float(trap_distance_tiles) * TILE, door.end.y)


## El Debug ensena el icono de la trampa.
func is_trap_revealed() -> bool:
	return has_trap() and not _sprung and DebugMode.is_revealing()


## Rectangulo de la puerta (global).
func get_door_rect() -> Rect2:
	var w: float = float(_cfg.get("width_px", 40))
	return Rect2(global_position + Vector2((TILE - w) * 0.5, 0.0), Vector2(w, float(height_tiles) * TILE))


func get_hit_rect() -> Rect2:
	return get_door_rect().grow(float(_cfg.get("hit_grow_px", 24)))


## Ayuda de Eco: abierta, no ayuda.
func is_help_available() -> bool:
	return not _open


# --- Acciones ---

func _on_pulsed(_isak: Isak) -> void:
	pay()


## Paga y abre (lo usan el pulso y las pruebas). Verdadero si se ha abierto ahora.
func pay() -> bool:
	if _open:
		return false
	var price: int = get_cost()
	var kind: StringName = GameState.REFUND_SHORTCUT_TRAP if has_trap() else &""
	if not GameState.spend_attention(price, GROUP, GameState.current_level, kind):
		show_message(String(_cfg.get("text_no_funds", "Saldo insuficiente")))
		spark(REJECT_NO_FUNDS)
		return false
	open()
	paid.emit(price)
	return true


## Se abre sin cobrar (pruebas).
func open() -> void:
	if _open:
		return
	_open = true
	if _body != null:
		_body.collision_layer = 0
	queue_redraw()


## Salta la trampa sobre `isak` (lo usan el cruce y las pruebas). Verdadero si salto.
func spring_trap(isak: Isak) -> bool:
	if not _open or _sprung or not has_trap():
		return false
	_sprung = true
	if trap == TRAP_PROCESSING:
		show_message(String(_cfg.get("text_processing", "Verificando pago…")))
		if isak != null and is_instance_valid(isak):
			isak.freeze(float(_cfg.get("processing_s", 1.5)), FREEZE_SOURCE, float(isak.facing))
	elif trap == TRAP_SUBSCRIPTION or trap == TRAP_OFFER:
		var dir: float = _crossing_direction(isak)
		var feet: Vector2 = get_trap_spawn_feet(dir)
		if trap == TRAP_SUBSCRIPTION:
			show_message(String(_cfg.get("text_subscription", "¡Bienvenido!")))
			_trap_spawn = Subscription.spawn(get_parent(), feet - Vector2(0.0, TILE))
		else:
			var offer := (load(OFFER_SCENE_PATH) as PackedScene).instantiate() as OfferSign
			get_parent().add_child(offer)
			offer.global_position = feet
			_trap_spawn = offer
	elif trap == TRAP_COUNTDOWN and object_id != &"" and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(CountdownPlatform.GROUP):
			var platform := node as CountdownPlatform
			if platform != null and platform.trigger_id == object_id:
				platform.start()
	trap_sprung.emit(trap)
	queue_redraw()
	return true


func _advance(_dt: float) -> void:
	if not _open or _sprung or not has_trap():
		return
	var isak: Isak = LevelLookup.find_isak(self)
	if isak != null and not isak.is_dead() and LevelLookup.isak_body_rect(isak).intersects(get_door_rect()):
		spring_trap(isak)


# --- Interno ---

## Hacia donde cruza Isak: su velocidad, o hacia donde mira; sin Isak, a la derecha.
func _crossing_direction(isak: Isak) -> float:
	if isak == null or not is_instance_valid(isak):
		return 1.0
	if absf(isak.velocity.x) > 1.0:
		return signf(isak.velocity.x)
	return 1.0 if isak.facing >= 0.0 else -1.0


func _update_body() -> void:
	if _shape == null:
		return
	var rect: Rect2 = Rect2(Vector2((TILE - float(_cfg.get("width_px", 40))) * 0.5, 0.0),
		Vector2(float(_cfg.get("width_px", 40)), float(height_tiles) * TILE))
	(_shape.shape as RectangleShape2D).size = rect.size
	_shape.position = rect.get_center()
	queue_redraw()


func _draw() -> void:
	var door := Rect2(get_door_rect().position - global_position, get_door_rect().size)
	draw_rect(door.grow(3.0), _c("frame", "gris_escaparate"))
	if _open:
		draw_rect(door, _c("open", "tienda_noche"))
	else:
		draw_rect(door, _c("door", "negro_medio"))
		draw_line(Vector2(door.end.x - 8.0, door.get_center().y - 6.0), Vector2(door.end.x - 8.0, door.get_center().y + 6.0),
			_c("sign", "amarillo_rebajas"), 3.0)
	# Cartel de precio encima de la puerta.
	var plate := Rect2(Vector2(door.get_center().x - 34.0, door.position.y - 22.0), Vector2(68.0, 18.0))
	draw_rect(plate, _c("sign", "amarillo_rebajas"))
	var text: String = String(_cfg.get("text_sign", "Atajo: {cost}")).replace("{cost}", str(get_cost()))
	draw_price(plate.get_center().x, plate.end.y - 4.0, text, 11, _c("ink", "negro_medio"))
	if is_trap_revealed():
		_draw_trap_icon(door.get_center() + Vector2(0.0, -door.size.y * 0.2))
	draw_feedback(Vector2(door.get_center().x, door.position.y - 4.0))


## Icono de la trampa con contorno negro de 1 px (se lee sobre el blanco del Debug).
func _draw_trap_icon(c: Vector2) -> void:
	var col: Color = _c("trap", "debug_blanco")
	var ink: Color = _c("ink", "negro_medio")
	draw_circle(c, 13.0, ink)
	draw_circle(c, 12.0, col)
	match trap:
		TRAP_PROCESSING:
			draw_arc(c, 7.0, -PI * 0.5, PI, 12, ink, 2.0)
		TRAP_SUBSCRIPTION:
			draw_rect(Rect2(c + Vector2(-7.0, -5.0), Vector2(14.0, 10.0)), ink, false, 2.0)
		TRAP_OFFER:
			draw_line(c + Vector2(-6.0, 6.0), c + Vector2(6.0, -6.0), ink, 2.0)
		TRAP_COUNTDOWN:
			draw_line(c, c + Vector2(0.0, -7.0), ink, 2.0)
			draw_line(c, c + Vector2(5.0, 0.0), ink, 2.0)
