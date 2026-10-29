## Estanteria de saldos (tipo `clearance_shelf` del catalogo del Mundo 5; 2026-10-29,
## paso 6 de docs/propuesta-mundo-5.md §8, §3.2.2, §3.7, §3.9 y patron 27). Ajustes
## en la seccion clearance_shelf de data/world5_objects.json.
##
## Columna SOLIDA de cajas de saldo de 1 x height_tiles (2-3) apoyada en el suelo que
## bloquea el paso; las estanterias con el mismo `group` forman un grupo. Un golpe
## suelto la TUMBA (sin colision): golpe al suelo cuya onda la alcanza, Embestida
## (EventBus.combo_landed), pulso o laser. A los restock_s (0,5 s del mundo) SE
## REPONE (sin materializarse con Isak dentro: espera a que salga) SI queda alguna del
## grupo en pie. Si todas las del grupo estan tumbadas a la vez, el grupo cae PARA
## SIEMPRE (el resto del intento): solo un SISMO, que llega a la vez a toda la planta
## en pantalla, las tumba todas a la vez. Un grupo de una sola estanteria solo cae
## para siempre con el Sismo (si no, un golpe suelto bastaria y el Sismo sobraria,
## §3.9). Reaparecer repone las tumbadas que no han caido para siempre.
## El origen es la esquina superior izquierda de su celda de arriba. Aspecto PROVISIONAL.
class_name ClearanceShelf
extends StaticBody2D

const GROUP: StringName = &"clearance_shelf"
const LAYER_WORLD: int = 1
const BY_PULSE: StringName = &"pulse"
const BY_LASER: StringName = &"laser"
const BY_POUND: StringName = &"ground_pound"
const BY_RAM: StringName = &"ram"
const BY_QUAKE: StringName = &"quake"

enum State { STANDING, DOWN, CLEARED }

## Un golpe la ha tumbado (`by`).
signal knocked(by: StringName)
## Se ha repuesto («¡Reponiendo!»).
signal restocked
## Su grupo ha caido para siempre.
signal cleared

@export var object_id: StringName = &""
## Grupo (params.group): las que deben caer a la vez.
@export var group_id: StringName = &""
@export var height_tiles: int = 2:
	set(value):
		height_tiles = clampi(value, 1, 4)
		_update_shape()

var _cfg: Dictionary = {}
var _state: State = State.STANDING
var _restock_left: float = 0.0
var _flash_left: float = 0.0
var _last_by: StringName = &""
var _shape: CollisionShape2D


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("clearance_shelf")
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_shape()
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)
	EventBus.combo_landed.connect(_on_combo_landed)
	EventBus.pulse_fired.connect(receive_pulse)
	EventBus.player_respawned.connect(_on_player_respawned)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_size() -> Vector2:
	var t: float = World5ObjectsConfig.tile_size()
	return Vector2(t, t * float(height_tiles))


## Estanteria en pie (global).
func get_shelf_rect() -> Rect2:
	return Rect2(global_position, get_size())


func get_state() -> State:
	return _state


func is_standing() -> bool:
	return _state == State.STANDING


func is_down() -> bool:
	return _state != State.STANDING


func is_cleared() -> bool:
	return _state == State.CLEARED


func is_solid() -> bool:
	return _state == State.STANDING


func get_restock_left() -> float:
	return _restock_left if _state == State.DOWN else 0.0


## Las estanterias de su grupo (ella incluida) en el arbol.
func get_group_members() -> Array[ClearanceShelf]:
	var out: Array[ClearanceShelf] = []
	if not is_inside_tree():
		out.append(self)
		return out
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var shelf := node as ClearanceShelf
		if shelf == null or not is_instance_valid(shelf) or shelf.is_queued_for_deletion():
			continue
		if shelf == self or (group_id != &"" and shelf.group_id == group_id):
			out.append(shelf)
	return out


func is_help_available() -> bool:
	return _state != State.CLEARED


# --- Acciones ---

## La tumba un golpe `by`. Verdadero si estaba en pie.
func knock(by: StringName) -> bool:
	if _state != State.STANDING:
		return false
	_state = State.DOWN
	_last_by = by
	_restock_left = float(_cfg.get("restock_s", 0.5))
	_set_solid(false)
	knocked.emit(by)
	_check_group(by)
	queue_redraw()
	return true


## Pulso: la tumba. Verdadero si la alcanzaba en pie.
func receive_pulse(area: Area2D) -> bool:
	if _state != State.STANDING or not PulseReceiver.pulse_reaches(area, get_shelf_rect()):
		return false
	return knock(BY_PULSE)


## Interfaz del laser: la tumba.
func on_laser_hit(_damage: float, _source: Node) -> void:
	knock(BY_LASER)


## Avanza `dt` segundos del mundo: la reposicion.
func advance(dt: float) -> void:
	_flash_left = maxf(_flash_left - dt, 0.0)
	if _state == State.DOWN:
		_restock_left -= dt
		if _restock_left <= 0.0:
			_restock_left = 0.0
			if not _isak_inside():
				_restock()
	queue_redraw()


# --- Interno ---

## Si todas las del grupo estan tumbadas, el grupo cae para siempre (un grupo de una
## sola estanteria, solo con el Sismo).
func _check_group(by: StringName) -> void:
	var members: Array[ClearanceShelf] = get_group_members()
	if members.size() < 2 and by != BY_QUAKE:
		return
	for shelf: ClearanceShelf in members:
		if shelf.is_standing():
			return
	for shelf: ClearanceShelf in members:
		shelf._clear()


func _clear() -> void:
	if _state == State.CLEARED:
		return
	_state = State.CLEARED
	_restock_left = 0.0
	_set_solid(false)
	cleared.emit()
	queue_redraw()


func _restock() -> void:
	_state = State.STANDING
	_flash_left = float(_cfg.get("restock_flash_s", 0.3))
	_set_solid(true)
	restocked.emit()


func _isak_inside() -> bool:
	var isak: Isak = LevelLookup.find_isak(self)
	return isak != null and not isak.is_dead() and LevelLookup.isak_body_rect(isak).intersects(get_shelf_rect())


func _set_solid(solid: bool) -> void:
	collision_layer = LAYER_WORLD if solid else 0
	if _shape != null:
		_shape.set_deferred(&"disabled", not solid)


func _on_ground_pound_landed(rect: Rect2, _source: Node2D) -> void:
	if rect.intersects(get_shelf_rect()):
		knock(BY_POUND)


func _on_combo_landed(kind: StringName, rect: Rect2, _source: Node2D) -> void:
	if not rect.intersects(get_shelf_rect()):
		return
	if kind == Isak.COMBO_QUAKE:
		knock(BY_QUAKE)
	elif kind == Isak.COMBO_RAM:
		knock(BY_RAM)


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	if _state == State.DOWN:
		_restock_left = 0.0
		_restock()


func _update_shape() -> void:
	if _shape == null:
		return
	(_shape.shape as RectangleShape2D).size = get_size()
	_shape.position = get_size() * 0.5
	queue_redraw()


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var size: Vector2 = get_size()
	var t: float = World5ObjectsConfig.tile_size()
	var box_col: Color = _c("box", "crema_sombra")
	var tag_col: Color = _c("tag", "amarillo_rebajas")
	var ink: Color = _c("ink", "negro_medio")
	var font: Font = ThemeDB.fallback_font
	if _state == State.STANDING:
		draw_rect(Rect2(Vector2(2.0, 0.0), Vector2(4.0, size.y)), _c("frame", "gris_escaparate"))
		draw_rect(Rect2(Vector2(size.x - 6.0, 0.0), Vector2(4.0, size.y)), _c("frame", "gris_escaparate"))
		var boxes: int = height_tiles * 2
		var h: float = size.y / float(boxes)
		for i: int in boxes:
			var r := Rect2(Vector2(8.0 + float(i % 2) * 2.0, float(i) * h + 2.0), Vector2(size.x - 18.0, h - 4.0))
			draw_rect(r, box_col if _flash_left <= 0.0 else _c("flash", "debug_blanco"))
			draw_rect(r, ink, false, 1.0)
		var tag := Rect2(Vector2(10.0, 6.0), Vector2(size.x - 20.0, 12.0))
		draw_rect(tag, tag_col)
		draw_string(font, Vector2(tag.position.x, tag.end.y - 2.0), String(_cfg.get("text_tag", "SALDO")),
			HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 9, ink)
		return
	# Tumbada: cajas por el suelo; a punto de reponerse, parpadea («¡Reponiendo!»).
	var floor_y: float = size.y
	for i: int in 3:
		var r := Rect2(Vector2(-8.0 + float(i) * 26.0, floor_y - 16.0 - float(i % 2) * 6.0), Vector2(24.0, 16.0))
		draw_rect(r, Color(box_col, 0.6 if _state == State.CLEARED else 1.0))
		draw_rect(r, ink, false, 1.0)
	if _state == State.DOWN:
		var k: float = 1.0 - _restock_left / maxf(float(_cfg.get("restock_s", 0.5)), 0.001)
		draw_rect(Rect2(Vector2(4.0, size.y - t - 4.0), Vector2((size.x - 8.0) * k, 4.0)), tag_col)
		draw_string(font, Vector2(-20.0, size.y - t - 8.0), String(_cfg.get("text_restock", "¡Reponiendo!")),
			HORIZONTAL_ALIGNMENT_CENTER, size.x + 40.0, 9, tag_col)
