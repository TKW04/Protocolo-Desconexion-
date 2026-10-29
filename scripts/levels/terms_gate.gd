## Terminos y condiciones (tipo `terms_gate` del catalogo del Mundo 5; 2026-10-29, paso 5
## de docs/propuesta-mundo-5.md §8 y §3.7). Puerta SOLIDA de 1 x height_tiles desde su
## celda con dos botones en la cara de `side` (por donde se llega):
## - «ACEPTAR»: enorme (accept_tiles x 1 tiles junto al pie de la puerta). CUALQUIER
##   pulso que lo alcance lo pulsa (de cara o de espaldas): la puerta se abre y se
##   ENGANCHA una Suscripcion a Isak (Subscription.spawn).
## - «rechazar»: diminuto (reject_size_px, en lo alto de la puerta). Solo lo alcanza el
##   LASER (un Area2D del grupo laser_activatable; el laser sale a la altura del celular,
##   asi que hay que disparar desde un suelo de enfrente una fila por debajo de lo alto
##   de la puerta: desde el suelo de la puerta el disparo choca con ella) o un FILO que
##   lo roza (receive_combo con Isak.COMBO_EDGE: la puerta esta en el grupo enemy solo
##   para eso). Abre sin coste.
## Abierta se queda abierta el resto del intento. El origen es la esquina superior
## izquierda de su celda. Aspecto PROVISIONAL por codigo (seccion terms_gate).
class_name TermsGate
extends Node2D

const GROUP: StringName = &"terms_gate"
const ENEMY_GROUP: StringName = &"enemy"
const LAYER_WORLD: int = 1
const TILE: float = 64.0
const SIDE_LEFT: StringName = &"left"
const SIDE_RIGHT: StringName = &"right"
const HOW_ACCEPT: StringName = &"accept"
const HOW_LASER: StringName = &"laser"
const HOW_EDGE: StringName = &"edge"

## Aceptado: abierta y Suscripcion enganchada.
signal accepted(subscription: Subscription)
## Rechazado (`how`: laser o edge): abierta sin coste.
signal rejected(how: StringName)

@export var object_id: StringName = &""
## Cara de los botones (por donde se llega): left o right.
@export var side: StringName = SIDE_LEFT:
	set(value):
		var s := StringName(value)
		if s != SIDE_LEFT and s != SIDE_RIGHT:
			push_warning("TermsGate: side '%s' desconocido; left" % s)
			s = SIDE_LEFT
		side = s
		_update_shapes()
@export var height_tiles: int = 3:
	set(value):
		height_tiles = maxi(value, 2)
		_update_shapes()


## Boton «rechazar»: objetivo del laser.
class RejectButton:
	extends Area2D

	var gate: TermsGate

	func on_laser_hit(_damage: float, _source: Node) -> void:
		if gate != null:
			gate.reject(TermsGate.HOW_LASER)


var _cfg: Dictionary = {}
var _open: bool = false
var _how: StringName = &""
var _subscription: Subscription
var _message: String = ""
var _message_left: float = 0.0
var _pressed_left: float = 0.0
var _body: StaticBody2D
var _body_shape: CollisionShape2D
var _button: RejectButton
var _button_shape: CollisionShape2D


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("terms_gate")
	add_to_group(GROUP)
	add_to_group(ENEMY_GROUP)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	_body_shape = CollisionShape2D.new()
	_body_shape.shape = RectangleShape2D.new()
	_body.add_child(_body_shape)
	add_child(_body)
	_button = RejectButton.new()
	_button.name = "RejectButton"
	_button.gate = self
	_button.collision_layer = LAYER_WORLD
	_button.collision_mask = 0
	_button.monitoring = false
	_button.add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	_button_shape = CollisionShape2D.new()
	_button_shape.shape = RectangleShape2D.new()
	_button.add_child(_button_shape)
	add_child(_button)
	_update_shapes()
	EventBus.pulse_fired.connect(receive_pulse)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func is_open() -> bool:
	return _open


## Como se abrio: accept, laser, edge ("" cerrada).
func get_opened_by() -> StringName:
	return _how


func get_subscription() -> Subscription:
	return _subscription if _subscription != null and is_instance_valid(_subscription) else null


func get_message() -> String:
	return _message if _message_left > 0.0 else ""


## Puerta (global).
func get_door_rect() -> Rect2:
	var w: float = float(_cfg.get("width_px", 40))
	return Rect2(global_position + Vector2((TILE - w) * 0.5, 0.0), Vector2(w, float(height_tiles) * TILE))


## Boton «ACEPTAR» (global): accept_tiles x 1 junto al pie de la puerta, por su cara.
func get_accept_rect() -> Rect2:
	var door: Rect2 = get_door_rect()
	var w: float = float(_cfg.get("accept_tiles", 3)) * TILE
	var x: float = door.position.x - w if side == SIDE_LEFT else door.end.x
	return Rect2(Vector2(x, door.end.y - TILE), Vector2(w, TILE))


## Boton «rechazar» (global): pegado a la cara de la puerta, en lo alto.
func get_reject_rect() -> Rect2:
	var door: Rect2 = get_door_rect()
	var s: Array = _cfg.get("reject_size_px", [8, 16])
	var size := Vector2(float(s[0]), float(s[1]))
	var x: float = door.position.x - size.x if side == SIDE_LEFT else door.end.x
	return Rect2(Vector2(x, door.position.y + float(_cfg.get("reject_top_px", 0))), size)


## Para ComboWave (Filo): el boton «rechazar» con el margen del roce.
func get_body_rect() -> Rect2:
	return get_reject_rect().grow(float(_cfg.get("edge_graze_px", 4)))


func is_dangerous() -> bool:
	return false


func is_help_available() -> bool:
	return not _open


# --- Acciones ---

## Pulso: cualquier pulso que alcance «ACEPTAR» lo pulsa (acepta).
func receive_pulse(area: Area2D) -> bool:
	if _open or not PulseReceiver.pulse_reaches(area, get_accept_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	return accept(isak)


## Acepta: abre y engancha una Suscripcion a `isak` (sin Isak, sale a avisar a sus pies).
func accept(isak: Isak = null) -> bool:
	if _open:
		return false
	_open_now(HOW_ACCEPT)
	_pressed_left = float(_cfg.get("press_s", 0.3))
	_show(String(_cfg.get("text_accepted", "Al continuar aceptas términos que nadie lee")))
	var feet: Vector2 = get_accept_rect().get_center() + Vector2(0.0, TILE * 0.5)
	if isak != null and is_instance_valid(isak) and not isak.is_dead():
		_subscription = Subscription.spawn(get_parent(), isak.global_position, isak)
	else:
		_subscription = Subscription.spawn(get_parent(), feet)
	accepted.emit(_subscription)
	return true


## Rechaza (laser o Filo): abre sin coste.
func reject(how: StringName) -> bool:
	if _open:
		return false
	_open_now(how)
	_show(String(_cfg.get("text_rejected", "Rechazado. Sin coste.")))
	rejected.emit(how)
	return true


## Filo que roza «rechazar» (ComboWave.defeat_small). La Embestida y el Sismo, nada.
func receive_combo(kind: StringName, rect: Rect2, _damage: float, _stun_s: float) -> bool:
	if _open or kind != Isak.COMBO_EDGE or not rect.intersects(get_body_rect()):
		return false
	return reject(HOW_EDGE)


func receive_ground_pound(_rect: Rect2, _damage: float) -> bool:
	return false


func receive_shockwave(_center: Vector2, _radius: float, _stun_s: float) -> bool:
	return false


func reset_patrol() -> void:
	pass


func advance(dt: float) -> void:
	if _message_left > 0.0:
		_message_left = maxf(_message_left - dt, 0.0)
	if _pressed_left > 0.0:
		_pressed_left = maxf(_pressed_left - dt, 0.0)
	queue_redraw()


# --- Interno ---

func _open_now(how: StringName) -> void:
	_open = true
	_how = how
	if _body != null:
		_body.collision_layer = 0
	if _button != null:
		_button.collision_layer = 0
	queue_redraw()


func _show(text: String) -> void:
	_message = text
	_message_left = float(_cfg.get("message_s", 2.0))


func _update_shapes() -> void:
	if _body_shape == null or _button_shape == null:
		return
	var door := Rect2(get_door_rect().position - global_position, get_door_rect().size)
	(_body_shape.shape as RectangleShape2D).size = door.size
	_body_shape.position = door.get_center()
	var rej := Rect2(get_reject_rect().position - global_position, get_reject_rect().size)
	(_button_shape.shape as RectangleShape2D).size = rej.size
	_button_shape.position = rej.get_center()
	queue_redraw()


# --- Dibujo ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var door := Rect2(get_door_rect().position - global_position, get_door_rect().size)
	var ink: Color = _c("ink", "negro_medio")
	var font: Font = ThemeDB.fallback_font
	draw_rect(door.grow(3.0), _c("frame", "gris_escaparate"))
	draw_rect(door, _c("open", "tienda_noche") if _open else _c("door", "crema_cartel"))
	if not _open:
		# Letra pequena que nadie lee.
		var y: float = door.position.y + 22.0
		while y < door.end.y - 8.0:
			draw_line(Vector2(door.position.x + 5.0, y), Vector2(door.end.x - 5.0, y), _c("fine", "gris_etiqueta"), 1.0)
			y += 6.0
		draw_string(font, Vector2(door.position.x, door.position.y + 16.0), "T&C", HORIZONTAL_ALIGNMENT_CENTER,
			door.size.x, 11, ink)
	# «ACEPTAR» enorme.
	var acc := Rect2(get_accept_rect().position - global_position, get_accept_rect().size)
	var btn := Rect2(acc.position + Vector2(8.0, 14.0), acc.size - Vector2(16.0, 18.0))
	if _pressed_left > 0.0:
		btn.position.y += 4.0
	draw_rect(btn.grow(2.0), ink)
	draw_rect(btn, _c("off", "gris_etiqueta") if _open else _c("accept", "amarillo_rebajas"))
	draw_string(font, Vector2(btn.position.x, btn.end.y - 12.0), "ACEPTAR", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 20, ink)
	# «rechazar» diminuto.
	var rej := Rect2(get_reject_rect().position - global_position, get_reject_rect().size)
	var dot := Rect2(rej.position + Vector2(0.0, 4.0), Vector2(rej.size.x, 8.0))
	draw_rect(dot, _c("off", "gris_etiqueta") if _open else _c("reject", "violeta_neon"))
	var label_x: float = rej.position.x - 44.0 if side == SIDE_LEFT else rej.end.x + 2.0
	draw_string(font, Vector2(label_x, rej.position.y + 11.0), "rechazar", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, _c("fine", "gris_etiqueta"))
	var msg: String = get_message()
	if not msg.is_empty():
		var w: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
		var box := Rect2(Vector2(door.get_center().x - w * 0.5, door.position.y - 30.0), Vector2(w, 20.0))
		draw_rect(box, ink)
		draw_rect(box, _c("text", "crema_cartel"), false, 1.0)
		draw_string(font, Vector2(box.position.x, box.end.y - 6.0), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 12, _c("text", "crema_cartel"))
