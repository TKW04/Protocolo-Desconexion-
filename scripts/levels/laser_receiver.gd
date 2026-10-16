## Lector laser (tipo `laser_receiver` del catalogo del Mundo 1; patron 2
## «Desbloquear a distancia y activar de cerca» de docs/propuesta-1-2.md §0.3 y
## acertijo «Correo certificado», §4; paso 3 de §10).
##
## - Objetivo del laser: Area2D en la capa world y en el grupo
##   laser_activatable (LaserProjectile lo choca y le llama on_laser_hit). El
##   pulso no le hace nada.
## - Al recibir un impacto da corriente durante window_s segundos de TIEMPO DEL
##   MUNDO (decision aprobada: el Debug lo ralentiza a la mitad) al receptor
##   enlazado (RelayReceiver con object_id == target_id) por un cable visible
##   (LaserCable, hijo; recorrido en celdas: cable_cells). Un impacto con
##   corriente vuelve a llenar la ventana. Al vencer, el cable se apaga y el
##   lector vuelve a estar listo: lo temporal vuelve solo (sin castigo).
## - Cuando el receptor se activa (complete()), el lector queda HECHO: cable
##   encendido fijo, sin Q (lo usado no ayuda) y los impactos ya no hacen nada.
## El origen del nodo es la esquina superior izquierda de su celda.
class_name LaserReceiver
extends Area2D

enum State { READY, POWERED, DONE }

const GROUP: StringName = &"laser_receiver"
const LAYER_WORLD: int = 1

## Ha empezado (o se ha rellenado) la corriente.
signal powered(window_s: float)
## Se ha acabado la corriente sin activar el receptor.
signal power_lost
## El receptor enlazado se ha activado: el lector ya no hace falta.
signal completed

## Id propio (params.id).
@export var object_id: StringName = &""
## Id del receptor enlazado (RelayReceiver.object_id; params.target).
@export var target_id: StringName = &""
## Segundos de corriente (tiempo del mundo); <= 0 usa window_s de la seccion.
@export var window_s: float = 0.0
## Recorrido del cable en celdas del grid ([[col, fila], ...], absolutas): de
## la salida del lector a la entrada del receptor pasando por estos centros.
@export var cable_cells: Array = []

var _config: Dictionary = World1ObjectsConfig.section("laser_receiver")
var _state: State = State.READY
var _power_left: float = 0.0
var _sprite: EnergySprite
var _cable: LaserCable
var _hits: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	monitoring = false
	if window_s <= 0.0:
		window_s = float(_config.get("window_s", 6.0))
	var r: Rect2 = get_local_hit_rect()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	add_child(shape)
	_cable = LaserCable.new()
	_cable.name = "Cable"
	_cable.reader = self
	add_child(_cable)
	_sprite = EnergySprite.attach(self, &"laser_receiver_idle", _vec(_config.get("sprite_center_px", [48, 8])),
		false, String(_config.get("frames", "")))
	_update_sprite()
	_cable.queue_redraw.call_deferred()
	EventBus.laser_fired.connect(_on_laser_fired)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo (las pruebas lo llaman directamente).
func advance(dt: float) -> void:
	if _state == State.POWERED:
		_power_left = maxf(_power_left - dt, 0.0)
		if _power_left <= 0.0:
			_state = State.READY
			_update_sprite()
			power_lost.emit()
	if _sprite != null:
		_sprite.advance(dt)
	if _cable != null:
		_cable.advance(dt)


# --- Consultas ---

func get_state() -> State:
	return _state


func is_powered() -> bool:
	return _state == State.POWERED


func is_done() -> bool:
	return _state == State.DONE


## Segundos de corriente que quedan (0 sin corriente).
func get_power_left() -> float:
	return _power_left if _state == State.POWERED else 0.0


## Fraccion de la ventana que queda (1 recien disparado, 0 sin corriente; 1 hecho).
func get_power_fraction() -> float:
	if _state == State.DONE:
		return 1.0
	return clampf(get_power_left() / maxf(window_s, 0.001), 0.0, 1.0)


## Ultimos warn_s segundos de la ventana: el cable parpadea.
func is_warning() -> bool:
	return _state == State.POWERED and _power_left <= float(_config.get("warn_s", 1.5))


func get_hit_count() -> int:
	return _hits


## Ayuda de Eco (HelpCatalog.is_help_live): lo usado no ayuda; con su receptor ya activado, no.
func is_help_available() -> bool:
	return _state != State.DONE


## Zona de impacto en coordenadas locales.
func get_local_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect", [32, -16, 32, 48])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func get_hit_rect() -> Rect2:
	var r: Rect2 = get_local_hit_rect()
	return Rect2(global_position + r.position, r.size)


## Salida del cable en coordenadas globales.
func get_cable_port() -> Vector2:
	return global_position + _vec(_config.get("cable_port_px", [48, 32]))


func get_cable() -> LaserCable:
	return _cable


# --- Acciones ---

## Impacto del laser (LaserProjectile): da corriente (o rellena la ventana).
func on_laser_hit(_damage: float, _source: Node) -> void:
	_hits += 1
	power()


## Da corriente window_s segundos. Sin efecto si ya esta hecho.
func power() -> void:
	if _state == State.DONE:
		return
	_state = State.POWERED
	_power_left = window_s
	_update_sprite()
	powered.emit(window_s)


## El receptor enlazado se ha activado: cable fijo encendido, sin Q.
func complete() -> void:
	if _state == State.DONE:
		return
	_state = State.DONE
	_power_left = 0.0
	_update_sprite()
	completed.emit()


func _update_sprite() -> void:
	if _sprite == null:
		return
	match _state:
		State.READY:
			_sprite.show_state(&"laser_receiver_idle")
		State.POWERED:
			_sprite.show_state(&"laser_receiver_powered")
		State.DONE:
			_sprite.show_state(&"laser_receiver_done")
	if _cable != null:
		_cable.queue_redraw()


static func _vec(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


## Isak dispara pegado al objetivo (el celular ya esta dentro de el o de la
## pared de detras): el rayo no lo veria, asi que el proyectil choca ya.
func _on_laser_fired(projectile: Node2D) -> void:
	if _state != State.DONE and is_inside_tree() and projectile is LaserProjectile \
			and LaserProjectile.muzzle_crosses(projectile, get_hit_rect()):
		(projectile as LaserProjectile).strike(self)
