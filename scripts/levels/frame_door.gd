## Puerta de marco (tipo `frame_door` del catalogo del Mundo 3; 2026-10-26, paso 6
## de docs/propuesta-mundo-3.md §8, §3.6, patron 17 de §3.5): puerta SOLIDA de
## 1 x 3 tiles (capa world, como la barra del 99 %, UpdateBar) que se abre
## mientras alguna placa «Posa aqui» enlazada (PosePlate con target_id ==
## object_id) la sostiene (is_holding: pisada y hold_s mas). Tiempo del mundo.
## - Abrir: AVISO + apertura en open_s (0,2 s): las lamparas del marco se
##   encienden y la hoja sube; sigue solida hasta abrirse del todo.
## - Cerrar (ninguna placa la sostiene): aviso de close_warn_frames cuadros (9 a
##   60 fps = 0,15 s; la hoja parpadea) y la hoja baja en open_s; es solida desde
##   que empieza a bajar. Nunca se cierra con Isak o un Reflejo falso dentro de su
##   hueco (espera, como la plataforma que parpadea). Si una placa la vuelve a
##   sostener durante el aviso o la bajada, vuelve a abrirse.
## Aspecto PROVISIONAL por codigo (seccion frame_door). El origen es la esquina
## superior izquierda de su celda de arriba.
class_name FrameDoor
extends StaticBody2D

enum State { CLOSED, OPENING, OPEN, WARN_CLOSE, CLOSING }

const GROUP: StringName = &"frame_door"
const LAYER_WORLD: int = 1
const HEIGHT_TILES: int = 3

## Empieza a abrirse (aviso + apertura).
signal opening_started
## Abierta del todo: ya no es solida.
signal opened
## Aviso de cierre.
signal close_warned
## Cerrada del todo.
signal closed

@export var object_id: StringName = &""
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true

var _cfg: Dictionary = World3ObjectsConfig.section("frame_door")
var _state: State = State.CLOSED
var _state_t: float = 0.0
## 0 = cerrada, 1 = abierta (la hoja).
var _open: float = 0.0
var _solid: bool = true
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	var size: Vector2 = get_size_px()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	add_child(_shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo. Publico para las pruebas.
func advance(dt: float) -> void:
	_state_t += dt
	var held: bool = is_held()
	var open_s: float = get_open_s()
	if _state == State.CLOSED and held:
		_set_state(State.OPENING)
		opening_started.emit()
	match _state:
		State.OPENING:
			_open = minf(_open + dt / maxf(open_s, 0.001), 1.0)
			if _open >= 1.0:
				_set_state(State.OPEN)
				_set_solid(false)
				opened.emit()
		State.OPEN:
			if not held:
				_set_state(State.WARN_CLOSE)
				close_warned.emit()
		State.WARN_CLOSE:
			if held:
				_set_state(State.OPEN)
			elif _state_t >= get_close_warn_s() - 0.0001 and not is_blocked():
				_set_state(State.CLOSING)
				_set_solid(true)
		State.CLOSING:
			if held:
				_set_state(State.OPENING)
				opening_started.emit()
			else:
				_open = maxf(_open - dt / maxf(open_s, 0.001), 0.0)
				if _open <= 0.0:
					_set_state(State.CLOSED)
					closed.emit()
	queue_redraw()


# --- Consultas ---

func get_state() -> State:
	return _state


func is_open() -> bool:
	return _state == State.OPEN or _state == State.WARN_CLOSE


func is_solid() -> bool:
	return _solid


## Fraccion abierta de la hoja (0-1).
func get_open_fraction() -> float:
	return _open


func get_open_s() -> float:
	return float(_cfg.get("open_s", 0.2))


func get_close_warn_s() -> float:
	return float(_cfg.get("close_warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 60.0)), 1.0)


func get_size_px() -> Vector2:
	var t: float = World3ObjectsConfig.tile_size()
	return Vector2(t, t * HEIGHT_TILES)


func get_rect() -> Rect2:
	return Rect2(global_position, get_size_px())


## Placas enlazadas (target_id == object_id).
func get_plates() -> Array[PosePlate]:
	var out: Array[PosePlate] = []
	if object_id == &"" or not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group(PosePlate.GROUP):
		var p := node as PosePlate
		if p != null and p.target_id == object_id:
			out.append(p)
	return out


## Alguna placa la sostiene.
func is_held() -> bool:
	for p: PosePlate in get_plates():
		if p.is_holding():
			return true
	return false


## Isak o un Reflejo falso estan en su hueco (no se cierra).
func is_blocked() -> bool:
	var r: Rect2 = get_rect()
	var isak: Isak = LevelLookup.find_isak(self)
	if isak != null and not isak.is_dead() and LevelLookup.isak_body_rect(isak).intersects(r):
		return true
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(PosePlate.PRESSER_GROUP):
			if node.has_method(&"get_body_rect_now"):
				var b: Rect2 = node.call(&"get_body_rect_now")
				if b.has_area() and b.intersects(r):
					return true
	return false


func is_help_available() -> bool:
	return true


# --- Interno ---

func _set_state(next: State) -> void:
	_state = next
	_state_t = 0.0


func _set_solid(solid: bool) -> void:
	_solid = solid
	if _shape != null:
		_shape.set_deferred(&"disabled", not solid)


# --- Dibujo PROVISIONAL ---

func _draw() -> void:
	var size: Vector2 = get_size_px()
	var frame: float = float(_cfg.get("frame_px", 6))
	# Marco dorado (siempre) y hoja que sube.
	draw_rect(Rect2(Vector2.ZERO, size), _c("frame_shadow", "marco_sombra"))
	draw_rect(Rect2(Vector2(frame, 0.0), Vector2(size.x - 2.0 * frame, size.y)), _c("opening", "galeria_noche"))
	var leaf_h: float = (size.y - frame) * (1.0 - _open)
	var blink: bool = _state == State.WARN_CLOSE and int(floor(_state_t * 60.0 / 3.0)) % 2 == 0
	var leaf: Color = _c("leaf_warn", "dorado_luz") if blink else _c("leaf", "trastienda_luz")
	if leaf_h > 0.5:
		draw_rect(Rect2(Vector2(frame, 0.0), Vector2(size.x - 2.0 * frame, leaf_h)), leaf)
		draw_rect(Rect2(Vector2(frame + 6.0, maxf(leaf_h - 10.0, 0.0)), Vector2(size.x - 2.0 * frame - 12.0, 4.0)),
			_c("leaf_edge", "dorado"))
	draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), _c("frame", "dorado"), false, 2.0)
	# Lamparas del aviso (arriba): encendidas al abrir / abierta.
	var lit: bool = _state != State.CLOSED and _state != State.CLOSING
	for i: int in 2:
		var p := Vector2(size.x * (0.3 + 0.4 * float(i)), 6.0)
		draw_circle(p, 4.0, _c("lamp_on", "dorado_luz") if lit else _c("lamp_off", "marco_sombra"))


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))
