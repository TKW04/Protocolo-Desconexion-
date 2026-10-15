## Objeto que da una habilidad (tipo `ability_pickup` del catalogo del Mundo 1;
## decision del usuario 2026-10-15, la primera es el laser). Al tocarlo Isak:
## GameState.obtain_ability(ability) la desbloquea para siempre, la guarda en
## user://save.json (abilities_obtained) y emite EventBus.ability_obtained. El
## aviso del control lo da AbilityNotices (data/ability_notices.json, una vez
## por partida guardada); solo si el nivel da `message`, el cuadro de Eco
## muestra ademas ese texto. Si la habilidad ya estaba obtenida no aparece. No es solido. Aspecto PROVISIONAL dibujado por
## codigo: un chip con contorno noche_profunda y nucleo en el color del Debug
## del Mundo 1 que flota (tiempo del mundo).
class_name AbilityPickup
extends Area2D

signal collected(ability: StringName)

const CONFIG_PATH: String = "res://data/world1_objects.json"

## Id del objeto (nombre del nodo en la escena generada).
@export var object_id: StringName = &""
## Habilidad que da (GameState.ABILITIES; p. ej. &"laser").
@export var ability: StringName = &""
## Texto extra en el cuadro de Eco al recogerlo (vacio = ninguno; el aviso del
## control lo da AbilityNotices).
@export var message: String = ""

var _taken: bool = false
var _time: float = 0.0
var _size := Vector2(28.0, 28.0)
var _bob_px: float = 4.0
var _bob_hz: float = 1.5
var _outline := Color("#0b0e1a")
var _body := Color("#f2f4f8")
var _core := Color("#3dfff5")
var _message_s: float = 4.0


func _ready() -> void:
	_load_config()
	if GameState.is_ability_obtained(ability):
		_taken = true
		queue_free()
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	shape.position = _center()
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += WorldTime.scaled_delta(delta)
	queue_redraw()


func _draw() -> void:
	var offset: float = roundf(sin(_time * TAU * _bob_hz) * _bob_px)
	var center: Vector2 = (_center() + Vector2(0.0, offset)).round()
	var half: Vector2 = _size * 0.5
	# Rombo escalonado (pixel art): tres franjas que se estrechan.
	var outer := Rect2(center - half, _size)
	draw_rect(outer.grow_individual(-half.x * 0.5, 0.0, -half.x * 0.5, 0.0), _outline)
	draw_rect(outer.grow_individual(0.0, -half.y * 0.5, 0.0, -half.y * 0.5), _outline)
	var inner := outer.grow(-2.0)
	draw_rect(inner.grow_individual(-half.x * 0.5, 0.0, -half.x * 0.5, 0.0), _body)
	draw_rect(inner.grow_individual(0.0, -half.y * 0.5, 0.0, -half.y * 0.5), _body)
	draw_rect(Rect2(center - half * 0.4, _size * 0.4), _core)


func is_taken() -> bool:
	return _taken


## Texto extra al recogerlo (`message`).
func get_message() -> String:
	return message


## Lo recoge `body` si es Isak. Verdadero si da la habilidad.
func collect_by(body: Node) -> bool:
	if _taken or not body is Isak:
		return false
	_taken = true
	var obtained: bool = GameState.obtain_ability(ability)
	if obtained:
		var text: String = get_message()
		if not text.is_empty():
			EventBus.eco_line_requested.emit(text, _message_s)
		collected.emit(ability)
	queue_free()
	return obtained


## Centro del dibujo y de la zona de recogida: centro de la celda (x, y).
func _center() -> Vector2:
	return Vector2(32.0, 32.0)


func _load_config() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or not (parsed as Dictionary).get("ability_pickup") is Dictionary:
		return
	var cfg: Dictionary = parsed["ability_pickup"]
	var size: Variant = cfg.get("size_px", [])
	if size is Array and (size as Array).size() == 2:
		_size = Vector2(float(size[0]), float(size[1]))
	_bob_px = float(cfg.get("bob_px", _bob_px))
	_bob_hz = float(cfg.get("bob_hz", _bob_hz))
	_outline = Color(String(cfg.get("outline", _outline.to_html(false))))
	_body = Color(String(cfg.get("body", _body.to_html(false))))
	_core = Color(String(cfg.get("core", _core.to_html(false))))
	_message_s = float(cfg.get("message_s", _message_s))


func _on_body_entered(body: Node2D) -> void:
	collect_by(body)
