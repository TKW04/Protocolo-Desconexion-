## Base de los objetos que cobran o devuelven con un PULSO DE ESPALDAS en el Mundo 5
## (2026-10-29, paso 3 de docs/propuesta-mundo-5.md §3.1, §3.6 y §3.7): la tienda
## (ShopItem), el atajo (ShortcutDoor) y Devoluciones (RefundDesk). Como LikeReset /
## DndSwitch: el pulso alcanza su get_hit_rect(), Isak se pone de espaldas pose_s
## (Isak.face_back) y la hija decide en _on_pulsed. Cartel temporal (show_message:
## «Saldo insuficiente»...) y chispa gris (spark) por codigo. Lee data/economy.json
## (economy()) y su seccion de data/world5_objects.json (SECTION de la hija). Tiempo del
## mundo. El origen es la esquina superior izquierda de su celda.
class_name PayPoint
extends Node2D

const ECONOMY_PATH: String = "res://data/economy.json"

## Un pulso lo ha alcanzado sin poder hacer nada (sin saldo, agotado): chispa gris.
signal rejected(reason: StringName)

const REJECT_NO_FUNDS: StringName = &"no_funds"
const REJECT_USED: StringName = &"used"

static var _economy: Dictionary = {}

## Id propio (params.id).
@export var object_id: StringName = &""

var _cfg: Dictionary = {}
var _pose_left: float = 0.0
var _posed: Isak
var _message: String = ""
var _message_left: float = 0.0
var _spark_left: float = 0.0
var _time: float = 0.0


## data/economy.json (se lee una vez).
static func economy() -> Dictionary:
	if _economy.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_PATH))
		if parsed is Dictionary:
			_economy = parsed
		else:
			push_error("PayPoint: no se pudo leer %s" % ECONOMY_PATH)
	return _economy


## prices.<kind> de data/economy.json.
static func price_section(kind: String) -> Dictionary:
	return (economy().get("prices", {}) as Dictionary).get(kind, {})


## Nombre de la seccion de data/world5_objects.json (lo pone la hija).
func _section_name() -> String:
	return ""


func _ready() -> void:
	_cfg = World5ObjectsConfig.section(_section_name())
	EventBus.pulse_fired.connect(receive_pulse)
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

## Zona del pulso (global): hit_rect de la seccion, en px desde la esquina de la celda.
func get_hit_rect() -> Rect2:
	var r: Array = _cfg.get("hit_rect", [4, -24, 56, 72])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


func is_posing() -> bool:
	return _pose_left > 0.0


func get_message() -> String:
	return _message if _message_left > 0.0 else ""


func is_sparking() -> bool:
	return _spark_left > 0.0


# --- Acciones ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si lo ha alcanzado.
func receive_pulse(area: Area2D) -> bool:
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	if isak != null and is_instance_valid(isak) and not isak.is_dead() and isak.face_back():
		_posed = isak
		_pose_left = float(_cfg.get("pose_s", 0.45))
	_on_pulsed(isak)
	return true


## Lo que hace con el pulso (la hija). `isak` puede ser null (pruebas).
func _on_pulsed(_isak: Isak) -> void:
	pass


## Cartel temporal encima del objeto.
func show_message(text: String) -> void:
	_message = text
	_message_left = float(_cfg.get("message_s", 1.5))
	queue_redraw()


## Chispa gris y rejected(reason).
func spark(reason: StringName) -> void:
	_spark_left = float(_cfg.get("spark_s", 0.3))
	rejected.emit(reason)
	queue_redraw()


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	if _pose_left > 0.0:
		_pose_left -= dt
		if _pose_left <= 0.0:
			_pose_left = 0.0
			if _posed != null and is_instance_valid(_posed) and _posed.is_facing_back():
				_posed.face_side()
			_posed = null
	if _message_left > 0.0:
		_message_left = maxf(_message_left - dt, 0.0)
	if _spark_left > 0.0:
		_spark_left = maxf(_spark_left - dt, 0.0)
	_advance(dt)
	queue_redraw()


## Avance propio de la hija.
func _advance(_dt: float) -> void:
	pass


# --- Dibujo ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


## Rombo de los puntos de atencion (el glifo «◆» no esta en la fuente por defecto).
func draw_diamond(center: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -r), center + Vector2(r, 0.0),
		center + Vector2(0.0, r), center + Vector2(-r, 0.0)]), color)


## Texto con un rombo detras («3 ◆»), centrado en `center_x` con la linea base en `y`.
func draw_price(center_x: float, y: float, text: String, size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r: float = float(size) * 0.3
	var x0: float = center_x - (w + r * 2.0 + 4.0) * 0.5
	draw_string(font, Vector2(x0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_diamond(Vector2(x0 + w + 4.0 + r, y - float(size) * 0.35), r, color)


## Cartel temporal y chispa gris (lo llama el _draw de la hija al final).
func draw_feedback(anchor: Vector2) -> void:
	if _spark_left > 0.0:
		var grey: Color = World5ObjectsConfig.color("gris_etiqueta", Color("#7a7488"))
		for deg: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(10.0, 0.0).rotated(deg_to_rad(deg))
			draw_line(anchor - d, anchor + d, grey, 2.0)
	var msg: String = get_message()
	if msg.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var size: int = 14
	var w: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	var box := Rect2(Vector2(anchor.x - w * 0.5, anchor.y - 40.0), Vector2(w, 22.0))
	draw_rect(box, World5ObjectsConfig.color("negro_medio", Color("#221c30")))
	draw_rect(box, World5ObjectsConfig.color("crema_cartel", Color("#e8e0c8")), false, 2.0)
	draw_string(font, Vector2(box.position.x, box.end.y - 6.0), msg, HORIZONTAL_ALIGNMENT_CENTER, w, size,
		World5ObjectsConfig.color("crema_cartel", Color("#e8e0c8")))
