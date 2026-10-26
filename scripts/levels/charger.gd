## Cargador de energia (tipo `charger` del catalogo del Mundo 1; decision del
## usuario 2026-10-15: en los mapas hay cargadores en ciertos puntos que reponen
## la energia de Debug, la misma que gasta el laser). Se activa AL TOCARLO
## (como el punto de sincronizacion y la puerta de salida: sin accion nueva).
## Repone `amount` (el sobrante se pierde). Si la barra ya esta llena no se
## gasta.
## - reusable true (PROPUESTA por defecto): tras usarse se enfria cooldown_s
##   (tiempo del mundo) y vuelve a estar listo. El enfriamiento no se guarda.
## - reusable false: un solo uso; queda gastado y se guarda por nivel en
##   user://save.json (collected_pickups, como los power banks de mapa).
## Aspecto (EnergySprite, docs/estilizacion-energia.md): charger_ready en bucle
## cuando esta listo; enfriandose, el cuadro floor(progress * 8) de
## charger_cooling (progress = tiempo enfriado / cooldown_s); gastado,
## charger_spent. Lienzo de 32x64 centrado en x en la celda y apoyado en su
## borde inferior.
class_name Charger
extends Area2D

## Ha repuesto `amount` de energia.
signal used(amount: float)

const CONFIG_PATH: String = "res://data/world1_objects.json"

## Id persistente; vacio = el nombre del nodo.
@export var object_id: StringName = &""
## Energia que repone cada uso.
@export var amount: float = 50.0
## Reutilizable con enfriamiento (true) o de un solo uso (false).
@export var reusable: bool = true
## Enfriamiento entre usos (s de tiempo del mundo) si es reutilizable.
@export var cooldown_s: float = 20.0
## SpriteFrames con las animaciones charger_ready / charger_cooling /
## charger_spent; vacio = el de los niveles (EnergySprite.FRAMES_PATH). El hub
## usa la variante con la paleta del hub (data/hub.json, seccion charger).
@export var frames_path: String = ""

var _spent: bool = false
var _cooldown_left: float = 0.0
var _size := Vector2(32.0, 64.0)
var _sprite: EnergySprite


func _ready() -> void:
	_load_config()
	if not reusable and GameState.is_pickup_collected(get_level_id(), get_charger_id()):
		_spent = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _size
	shape.shape = rect
	shape.position = _center()
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_sprite = EnergySprite.attach(self, &"charger_ready", Vector2.ZERO, false, frames_path)
	# Apoyado en el borde inferior de la celda (x, y).
	var canvas_h: float = _sprite.sprite_frames.get_frame_texture(&"charger_ready", 0).get_height()
	_sprite.position = Vector2(32.0, 64.0 - canvas_h * 0.5)
	_update_sprite(0.0)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))
	# Isak quieto encima cuando termina el enfriamiento o gasta energia.
	if is_ready():
		for body: Node2D in get_overlapping_bodies():
			if try_use(body) > 0.0:
				break


## Avanza el enfriamiento `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - dt, 0.0)
	_update_sprite(dt)


func is_ready() -> bool:
	return not _spent and _cooldown_left <= 0.0


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; un cargador de un solo uso gastado, no.
func is_help_available() -> bool:
	return not is_spent()


func is_spent() -> bool:
	return _spent


func get_cooldown_left() -> float:
	return _cooldown_left


func get_charger_id() -> StringName:
	return object_id if object_id != &"" else StringName(name)


## Id del nivel generado que lo contiene (&"" si no hay).
func get_level_id() -> StringName:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return StringName((node as GeneratedLevel).level_id)
		node = node.get_parent()
	return GameState.NO_LEVEL


## Lo usa `body` si es Isak y esta listo. Devuelve la energia repuesta (0 si no
## se usa: no es Isak, gastado, enfriandose o la barra ya estaba llena).
func try_use(body: Node) -> float:
	if not body is Isak or not is_ready():
		return 0.0
	var gained: float = GameState.recharge_debug_energy(amount)
	if gained <= 0.0:
		return 0.0
	if reusable:
		_cooldown_left = cooldown_s
	else:
		_spent = true
		GameState.mark_pickup_collected(get_level_id(), get_charger_id())
	_update_sprite(0.0)
	used.emit(gained)
	EventBus.charger_used.emit(get_charger_id(), gained)
	return gained


## Vuelve a estar listo ya (sin enfriamiento; uno gastado sigue gastado). Lo usa
## la arena del jefe al reaparecer Isak (docs/propuesta-jefe-alerta-mayor.md §2.9).
func make_ready() -> void:
	_cooldown_left = 0.0
	_update_sprite(0.0)


## Progreso del enfriamiento: 0 recien usado, 1 listo.
func get_cooldown_progress() -> float:
	if _cooldown_left <= 0.0:
		return 1.0
	return 1.0 - _cooldown_left / maxf(cooldown_s, 0.001)


func _update_sprite(dt: float) -> void:
	if _sprite == null:
		return
	if _spent:
		_sprite.show_state(&"charger_spent")
	elif _cooldown_left > 0.0:
		_sprite.show_progress(&"charger_cooling", get_cooldown_progress())
	else:
		_sprite.show_state(&"charger_ready")
		_sprite.advance(dt)


## Centro de la zona de contacto: centrado en x en la celda (x, y)
## y apoyado en su borde inferior (con size_px 32x64 ocupa justo esa celda).
func _center() -> Vector2:
	return Vector2(32.0, 64.0 - _size.y * 0.5)


func _load_config() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or not (parsed as Dictionary).get("charger") is Dictionary:
		return
	var cfg: Dictionary = parsed["charger"]
	var size: Variant = cfg.get("size_px", [])
	if size is Array and (size as Array).size() == 2:
		_size = Vector2(float(size[0]), float(size[1]))


func _on_body_entered(body: Node2D) -> void:
	try_use(body)
