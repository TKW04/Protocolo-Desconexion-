## Objeto que da una habilidad (tipo `ability_pickup` del catalogo del Mundo 1;
## decision del usuario 2026-10-15, la primera es el laser). Al tocarlo Isak:
## GameState.obtain_ability(ability) la desbloquea para siempre, la guarda en
## user://save.json (abilities_obtained) y emite EventBus.ability_obtained. El
## aviso del control lo da AbilityNotices (data/ability_notices.json, una vez
## por partida guardada); solo si el nivel da `message`, el cuadro de Eco
## muestra ademas ese texto. Si la habilidad ya estaba obtenida (o desbloqueada)
## al empezar el nivel no aparece (ni Q, ni aviso, ni la linea de Eco ligada a
## ella: EcoLine.unless_ability). No es
## solido. Aspecto (EnergySprite, docs/estilizacion-energia.md): chip
## ability_pickup_idle que flota (tiempo del mundo); al recogerlo pasa a
## ability_pickup_collected justo antes de liberarse.
## Por habilidad (seccion ability_pickup.by_ability de data/world1_objects.json;
## 2026-10-16, paso 9 de docs/propuesta-1-2.md §10): el chip del Debug usa su
## arte (debug_chip_idle de assets/sprites/puzzle_objects_frames.tres) y su
## propia ayuda con Q (help_id debug_chip, si el nivel no pone otra); al
## recogerlo la PRIMERA vez Eco dice su linea de historia (story_text, linea
## importante, ANTES del aviso de control que da AbilityNotices al obtenerla:
## las importantes salen en orden) y se ve la instalacion (anillo
## debug_chip_collect y un destello del tinte del Debug a pantalla completa,
## en tiempo real para que se vea con la pausa de la linea). refill_energy
## (param del nivel): llena la energia al recogerlo (decision aprobada: solo
## ese chip y la primera vez; con la habilidad ya obtenida el chip no aparece).
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
## Llena la energia de Debug al recogerlo (el chip del Debug del 1-2).
@export var refill_energy: bool = false

var _taken: bool = false
var _time: float = 0.0
var _size := Vector2(28.0, 28.0)
var _bob_px: float = 4.0
var _bob_hz: float = 1.5
var _message_s: float = 4.0
var _sprite: EnergySprite
## Ajustes de la habilidad (by_ability.<ability>; vacio si no tiene).
var _ability_cfg: Dictionary = {}


func _ready() -> void:
	_load_config()
	# Objeto de un solo uso (2026-10-16, fallo encontrado jugando el 1-1): con
	# la habilidad ya obtenida (o desbloqueada) al empezar el nivel no aparece:
	# sin dibujo, sin colision, sin Q ni aviso; Isak pasa de largo. Tras un
	# game over sin guardarla (rollback) vuelve a aparecer.
	if is_already_owned():
		_taken = true
		visible = false
		monitoring = false
		monitorable = false
		HelpCatalog.tag(self, &"")
		queue_free()
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	shape.position = _center()
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var own_help: StringName = StringName(String(_ability_cfg.get("help_id", "")))
	if own_help != &"" and HelpCatalog.help_id_of(self) == StringName(String(
			World1ObjectsConfig.type_entry("ability_pickup").get("help_id", ""))):
		HelpCatalog.tag(self, own_help)
	_sprite = EnergySprite.attach(self, StringName(String(_ability_cfg.get("idle", "ability_pickup_idle"))),
		_center(), false, String(_ability_cfg.get("frames", "")))


func _process(delta: float) -> void:
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	if _sprite != null:
		_sprite.advance(dt)
		_sprite.position = (_center() + Vector2(0.0, roundf(sin(_time * TAU * _bob_hz) * _bob_px))).round()


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; recogido (o ya obtenido al empezar el nivel), no.
func is_help_available() -> bool:
	return not _taken


## La habilidad ya es de Isak (obtenida o desbloqueada): el objeto sobra.
func is_already_owned() -> bool:
	return ability != &"" and (GameState.is_ability_obtained(ability) or GameState.is_ability_unlocked(ability))


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
	if _sprite != null and _ability_cfg.is_empty():
		_sprite.show_state(&"ability_pickup_collected")
	var first: bool = not GameState.is_ability_obtained(ability)
	if first:
		var story: String = get_story_text()
		if not story.is_empty():
			EventBus.eco_line_requested.emit(story, float(_ability_cfg.get("story_duration_s", _message_s)), true)
		_play_install()
	var obtained: bool = GameState.obtain_ability(ability)
	if obtained and refill_energy:
		GameState.refill_debug_energy()
	if obtained:
		var text: String = get_message()
		if not text.is_empty():
			EventBus.eco_line_requested.emit(text, _message_s, true)
		collected.emit(ability)
	queue_free()
	return obtained


## Linea de historia de Eco al recogerlo por primera vez (by_ability.<ability>.story_text; "" = ninguna).
func get_story_text() -> String:
	return String(_ability_cfg.get("story_text", ""))


## Instalacion: anillo y destello del tinte (tiempo real, siguen con la pausa
## de la linea de historia). Se cuelgan del padre: el chip se libera ya.
func _play_install() -> void:
	var anim: StringName = StringName(String(_ability_cfg.get("collect", "")))
	var parent: Node = get_parent()
	if anim == &"" or parent == null:
		return
	var effect := InstallEffect.new()
	effect.name = "%sInstall" % name
	effect.setup(String(_ability_cfg.get("frames", "")), anim, position + _center(),
		_ability_cfg.get("flash", {}))
	parent.add_child(effect)


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
	var by_ability: Variant = cfg.get("by_ability", {})
	if by_ability is Dictionary and (by_ability as Dictionary).get(String(ability)) is Dictionary:
		_ability_cfg = by_ability[String(ability)]


func _on_body_entered(body: Node2D) -> void:
	collect_by(body)
