## Objeto que da una habilidad (tipo `ability_pickup` del catalogo del Mundo 1;
## decision del usuario 2026-10-15, la primera es el laser). Al tocarlo Isak:
## GameState.obtain_ability(ability) la desbloquea para siempre, la guarda en
## user://save.json (abilities_obtained) y emite EventBus.ability_obtained. El
## aviso del control lo da AbilityNotices (data/ability_notices.json, una vez
## por partida guardada); solo si el nivel da `message`, el cuadro de Eco
## muestra ademas ese texto. Si la habilidad ya estaba obtenida no aparece. No es
## solido. Aspecto (EnergySprite, docs/estilizacion-energia.md): chip
## ability_pickup_idle que flota (tiempo del mundo); al recogerlo pasa a
## ability_pickup_collected justo antes de liberarse.
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
var _message_s: float = 4.0
var _sprite: EnergySprite


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
	_sprite = EnergySprite.attach(self, &"ability_pickup_idle", _center())


func _process(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _sprite != null:
		_sprite.advance(dt)
		_sprite.position = (_center() + Vector2(0.0, roundf(sin(_time * TAU * _bob_hz) * _bob_px))).round()


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; recogido (o ya obtenido al empezar el nivel), no.
func is_help_available() -> bool:
	return not _taken


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
	if _sprite != null:
		_sprite.show_state(&"ability_pickup_collected")
	var obtained: bool = GameState.obtain_ability(ability)
	if obtained:
		var text: String = get_message()
		if not text.is_empty():
			EventBus.eco_line_requested.emit(text, _message_s, true)
		collected.emit(ability)
	queue_free()
	return obtained


## Centro del sprite y de la zona de recogida: centro de la celda (x, y).
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
	_message_s = float(cfg.get("message_s", _message_s))


func _on_body_entered(body: Node2D) -> void:
	collect_by(body)
