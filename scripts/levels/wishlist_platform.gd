## Lista de deseos (tipo `wishlist_platform` del catalogo del Mundo 5; 2026-10-29, paso 7
## de docs/propuesta-mundo-5.md §8, §3.3, §3.7 y §4.3; Tramo 4 del 5-3). Ajustes en la
## seccion wishlist_platform de data/world5_objects.json.
##
## Plataforma DE UNA VIA de width_tiles (2-4) x 1 (tarjeta de card_height_px arriba de
## su celda) con un objeto deseado encima (item: reloj, cascos, curso; cosas que Isak
## nunca pidio, sin marcas) y una OFERTA INTEGRADA: esta en el grupo de TemptationField
## y tira de Isak hacia el objeto como una Oferta (get_pull_weight: zona de radius_tiles
## (6) a cada lado del objeto y height_tiles de alto, strength; se SUMA con las demas
## Ofertas y deseos con el tope de §3.3: deriva 90 px/s y x0,45 al alejarse).
## El objeto NO se coge: si Isak se queda add_s (1,5 s del mundo) SOBRE el (en el
## suelo de la plataforma y a menos de item_half_width_px del objeto en horizontal),
## «Añadido al carrito» y se le ENGANCHA una Suscripcion (Subscription.spawn). Despues
## el objeto ya esta en el carrito: la plataforma deja de tirar (una vez por intento).
## El pulso que alcanza el objeto apaga el tiron stun_s (3 s), como a una Oferta, y el
## tiempo sobre el objeto vuelve a cero. Tiempo del mundo. El origen es la esquina
## superior izquierda de su primera celda. Aspecto PROVISIONAL por codigo.
class_name WishlistPlatform
extends Node2D

const GROUP: StringName = &"wishlist_platform"
const LAYER_WORLD: int = 1
const ITEMS: Array[StringName] = [&"watch", &"headphones", &"course"]

## «Añadido al carrito»: la Suscripcion que se engancha (null sin Isak).
signal added_to_cart(subscription: Subscription)

@export var object_id: StringName = &""
@export var width_tiles: int = 3:
	set(value):
		width_tiles = clampi(value, 1, 6)
		_update_body()
## Objeto deseado (dibujo y texto): watch, headphones o course.
@export var item: StringName = &"watch"
## Columna del objeto dentro de la plataforma (-1 = en el centro).
@export var item_tile: int = -1:
	set(value):
		item_tile = value
		queue_redraw()
@export var radius_tiles: float = 6.0
@export var height_tiles: float = 3.0
@export var strength: float = 1.0

var _cfg: Dictionary = {}
var _on_item_s: float = 0.0
var _added: bool = false
var _stun_left: float = 0.0
var _message_left: float = 0.0
var _time: float = 0.0
var _subscription: Subscription
var _body: StaticBody2D
var _shape: CollisionShape2D


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("wishlist_platform")
	add_to_group(GROUP)
	add_to_group(TemptationField.GROUP)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_shape.one_way_collision = true
	_body.add_child(_shape)
	add_child(_body)
	_update_body()
	EventBus.pulse_fired.connect(receive_pulse)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

## Tarjeta de la plataforma (global).
func get_card_rect() -> Rect2:
	var t: float = World5ObjectsConfig.tile_size()
	return Rect2(global_position, Vector2(float(width_tiles) * t, float(_cfg.get("card_height_px", 32))))


## Centro de los pies del objeto (global), sobre la tarjeta.
func get_item_feet() -> Vector2:
	var t: float = World5ObjectsConfig.tile_size()
	var col: float = float(width_tiles) * 0.5 if item_tile < 0 else float(item_tile) + 0.5
	return global_position + Vector2(col * t, 0.0)


## Caja del objeto (global).
func get_item_rect() -> Rect2:
	var s: Array = _cfg.get("item_size_px", [40, 40])
	var size := Vector2(float(s[0]), float(s[1]))
	var feet: Vector2 = get_item_feet()
	return Rect2(feet - Vector2(size.x * 0.5, size.y), size)


## Zona de la Oferta integrada (global): radius_tiles a cada lado del objeto.
func get_zone_rect() -> Rect2:
	var t: float = World5ObjectsConfig.tile_size()
	var c: Vector2 = get_item_rect().get_center()
	var half := Vector2(radius_tiles * t, height_tiles * t * 0.5)
	return Rect2(c - half, half * 2.0)


func is_added() -> bool:
	return _added


func is_pull_stunned() -> bool:
	return _stun_left > 0.0


func is_pulling() -> bool:
	return not _added and _stun_left <= 0.0


func get_time_on_item() -> float:
	return _on_item_s


func get_message() -> String:
	return String(_cfg.get("text_added", "Añadido al carrito")) if _message_left > 0.0 else ""


func get_subscription() -> Subscription:
	return _subscription if _subscription != null and is_instance_valid(_subscription) else null


## Texto del objeto (item_names de la seccion).
func get_item_name() -> String:
	var names: Variant = _cfg.get("item_names", {})
	return String((names as Dictionary).get(String(item), String(item))) if names is Dictionary else String(item)


## Peso con signo con el que tira de un cuerpo con centro en `point` (TemptationField,
## como OfferSign.get_pull_weight): hacia el objeto, 0 fuera de la zona, a menos de
## `dead_zone_px`, con el tiron apagado o con el objeto ya en el carrito.
func get_pull_weight(point: Vector2, dead_zone_px: float = 4.0) -> float:
	if not is_pulling() or not get_zone_rect().has_point(point):
		return 0.0
	var dx: float = get_item_feet().x - point.x
	if absf(dx) < dead_zone_px:
		return 0.0
	return signf(dx) * strength


## Isak esta SOBRE el objeto: en el suelo de la plataforma y junto al objeto.
func is_isak_on_item(isak: Isak) -> bool:
	if isak == null or not is_instance_valid(isak) or isak.is_dead() or not isak.is_on_floor():
		return false
	var feet: Vector2 = isak.global_position
	var top: float = global_position.y
	if absf(feet.y - top) > float(_cfg.get("on_top_tolerance_px", 6.0)):
		return false
	return absf(feet.x - get_item_feet().x) <= float(_cfg.get("item_half_width_px", 24.0))


func is_help_available() -> bool:
	return not _added


# --- Acciones ---

## Pulso: si alcanza el objeto, apaga el tiron stun_s. Verdadero si lo alcanzaba.
func receive_pulse(area: Area2D) -> bool:
	if _added or not PulseReceiver.pulse_reaches(area, get_item_rect()):
		return false
	_stun_left = float(_cfg.get("stun_s", 3.0))
	_on_item_s = 0.0
	queue_redraw()
	return true


## «Añadido al carrito» (lo usan el tiempo sobre el objeto y las pruebas). Falso si ya.
func add_to_cart(isak: Isak = null) -> bool:
	if _added:
		return false
	_added = true
	_message_left = float(_cfg.get("message_s", 2.0))
	if isak != null and is_instance_valid(isak) and not isak.is_dead():
		_subscription = Subscription.spawn(get_parent(), isak.global_position, isak)
	else:
		_subscription = Subscription.spawn(get_parent(), get_item_feet())
	added_to_cart.emit(_subscription)
	queue_redraw()
	return true


## Avanza `dt` segundos del mundo: el tiempo sobre el objeto y el tiron apagado.
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	_message_left = maxf(_message_left - dt, 0.0)
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - dt, 0.0)
	if not _added:
		var isak: Isak = LevelLookup.find_isak(self)
		if is_isak_on_item(isak):
			_on_item_s += dt
			if _on_item_s >= float(_cfg.get("add_s", 1.5)):
				add_to_cart(isak)
		else:
			_on_item_s = 0.0
	queue_redraw()


# --- Interno ---

func _update_body() -> void:
	if _shape == null:
		return
	var card: Rect2 = get_card_rect()
	(_shape.shape as RectangleShape2D).size = card.size
	_shape.position = card.size * 0.5
	queue_redraw()


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, get_card_rect().size)
	var ink: Color = _c("ink", "negro_medio")
	var font: Font = ThemeDB.fallback_font
	# Tarjeta de la lista (papel rayado) con el borde de una via.
	draw_rect(card, _c("card", "crema_cartel"))
	var y: float = 10.0
	while y < card.end.y - 2.0:
		draw_line(Vector2(4.0, y), Vector2(card.end.x - 4.0, y), _c("lines", "crema_sombra"), 1.0)
		y += 8.0
	draw_line(Vector2(0.0, 1.0), Vector2(card.end.x, 1.0), _c("edge", "magenta_neon"), 2.0)
	if _added:
		draw_feedback_text(font, ink)
		return
	var item_rect := Rect2(get_item_rect().position - global_position, get_item_rect().size)
	var c: Vector2 = item_rect.get_center()
	# Brillo que late (mas deprisa con Isak encima): lo que tienta se ve antes de sentirse.
	var k: float = clampf(_on_item_s / maxf(float(_cfg.get("add_s", 1.5)), 0.001), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * (3.0 + 9.0 * k))
	if is_pulling():
		draw_circle(c, item_rect.size.x * 0.5 + 6.0 + 4.0 * pulse, Color(_c("glow", "magenta_neon"), 0.25 + 0.2 * pulse))
	var col: Color = _c("item", "amarillo_rebajas") if is_pulling() else _c("off", "gris_etiqueta")
	match item:
		&"headphones":
			draw_arc(c + Vector2(0.0, 4.0), 14.0, PI, TAU, 12, col, 4.0)
			draw_rect(Rect2(c + Vector2(-18.0, 2.0), Vector2(8.0, 12.0)), col)
			draw_rect(Rect2(c + Vector2(10.0, 2.0), Vector2(8.0, 12.0)), col)
		&"course":
			draw_rect(Rect2(c + Vector2(-14.0, -12.0), Vector2(28.0, 24.0)), col)
			draw_rect(Rect2(c + Vector2(-14.0, -12.0), Vector2(28.0, 24.0)), ink, false, 1.0)
			draw_line(c + Vector2(-8.0, -4.0), c + Vector2(8.0, -4.0), ink, 2.0)
			draw_line(c + Vector2(-8.0, 3.0), c + Vector2(4.0, 3.0), ink, 2.0)
		_:
			draw_rect(Rect2(c + Vector2(-5.0, -18.0), Vector2(10.0, 36.0)), col)
			draw_circle(c, 11.0, col)
			draw_circle(c, 8.0, ink)
			draw_line(c, c + Vector2(0.0, -6.0), col, 2.0)
	if k > 0.0:
		draw_rect(Rect2(Vector2(c.x - 16.0, item_rect.position.y - 10.0), Vector2(32.0 * k, 4.0)), _c("edge", "magenta_neon"))
	var label: String = get_item_name()
	draw_string(font, Vector2(c.x - 60.0, item_rect.position.y - 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 9,
		_c("text", "crema_cartel"))


func draw_feedback_text(font: Font, ink: Color) -> void:
	var msg: String = get_message()
	if msg.is_empty():
		return
	var feet: Vector2 = get_item_feet() - global_position
	var w: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var box := Rect2(Vector2(feet.x - w * 0.5, feet.y - 56.0), Vector2(w, 20.0))
	draw_rect(box, ink)
	draw_rect(box, _c("text", "crema_cartel"), false, 1.0)
	draw_string(font, Vector2(box.position.x, box.end.y - 6.0), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 12,
		_c("text", "crema_cartel"))
