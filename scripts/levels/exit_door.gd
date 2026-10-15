## Puerta de salida del nivel (Cierre del 1-1: puerta "Marcar como leido", que
## da paso al siguiente nivel; C4: al terminar se vuelve al hub). Tipo
## `exit_door` de la lista `objects` del nivel (V7); contiene la celda G.
##
## PROPUESTA: Isak entra con solo tocarla (no se anade ninguna accion). Al
## tocarla (una sola vez):
## 1. emite entered(level_id) y bloquea la entrada de Isak (le pone un
##    PlayerInput neutro: se frena con su friccion normal);
## 2. la puerta se abre por pasos (cuadros 2-4 a open_fps) mientras Isak se
##    desvanece en fade_steps pasos discretos;
## 3. al terminar emite completed(level_id) y EventBus.level_completed(level_id).
## Nunca se dispara dos veces. No es solida (Area2D, mascara player).
## Encima lleva la etiqueta `text` con la fuente de textos (banner_blanco) sobre
## una placa noche_profunda con borde borde_luz, y la puerta cerrada brilla
## (parpadeo de su borde) por ser interactiva. Tiempo del mundo (Debug x0,5).
## El origen del nodo es la esquina superior izquierda de su primera celda.
class_name ExitDoor
extends Area2D

enum State { CLOSED, OPENING, DONE }

const GROUP: StringName = &"exit_door"

## Isak ha tocado la puerta (empieza la animacion).
signal entered(level_id: String)
## Animacion terminada: nivel completado (tambien EventBus.level_completed).
signal completed(level_id: String)

@export var object_id: StringName = &""
@export var text: String = "Marcar como leído"
@export_range(1, 8) var width_tiles: int = 1
@export_range(1, 8) var height_tiles: int = 2
## Id del nivel que completa (lo pone el generador). Vacio: GameState.current_level.
@export var level_id: String = ""

var _config: Dictionary = World1ObjectsConfig.section("exit_door")
var _state: State = State.CLOSED
var _time: float = 0.0
var _player: Isak
var _saved_input: PlayerInput
var _completed_count: int = 0
var _font: Font
var _sprite: Sprite2D
var _label_root: Node2D
var _label: Label
var _plate: ColorRect


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


func get_completed_count() -> int:
	return _completed_count


func get_frame() -> int:
	return _sprite.frame


func get_font() -> Font:
	return _font


func get_label() -> Label:
	return _label


## Rectangulo de la placa de la etiqueta en coordenadas globales.
func get_label_rect() -> Rect2:
	return Rect2(_label_root.global_position + _plate.position * _label_root.scale,
		_plate.size * _label_root.scale)


func get_door_rect() -> Rect2:
	var t: float = World1ObjectsConfig.tile_size()
	return Rect2(global_position, Vector2(width_tiles * t, height_tiles * t))


## Id del nivel que emite (level_id o, si esta vacio, el nivel actual).
func resolved_level_id() -> String:
	return level_id if not level_id.is_empty() else String(GameState.current_level)


# --- Acciones ---

## Isak entra por la puerta. Devuelve falso si ya se habia entrado.
func enter(isak: Isak) -> bool:
	if _state != State.CLOSED:
		return false
	_state = State.OPENING
	_time = 0.0
	_player = isak
	if isak != null:
		_saved_input = isak.input
		isak.input = PlayerInput.new()
	entered.emit(resolved_level_id())
	return true


## Devuelve el control a Isak y lo hace visible (p. ej. una escena de prueba
## que no cambia de escena). No reabre la puerta.
func release_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _saved_input != null:
		_player.input = _saved_input
	_player.modulate.a = 1.0


## Avanza `delta` segundos de tiempo del mundo.
func advance(delta: float) -> void:
	var frames: Dictionary = _config.get("frames", {})
	match _state:
		State.CLOSED:
			_time += delta
			var period: float = maxf(float(_config.get("glow_blink_s", 0.5)), 0.01)
			var glow: bool = int(floorf(_time / period)) % 2 == 1
			_sprite.frame = int(frames.get("glow" if glow else "closed", 0))
		State.OPENING:
			_time += delta
			var first: int = int(frames.get("open_first", 2))
			var last: int = int(frames.get("open", 4))
			var steps: int = last - first + 1
			var step: int = floori(_time * float(_config.get("open_fps", 8.0)))
			_sprite.frame = first + mini(step, steps - 1)
			_fade_player(float(step) / float(steps))
			if step >= steps:
				_finish()


# --- Interno ---

func _finish() -> void:
	_state = State.DONE
	_sprite.frame = int(_config.get("frames", {}).get("open", 4))
	_fade_player(1.0)
	_completed_count += 1
	var id: String = resolved_level_id()
	completed.emit(id)
	EventBus.level_completed.emit(id)


## Desvanece a Isak en pasos discretos (0 = visible, 1 = invisible).
func _fade_player(progress: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var fade_steps: int = maxi(1, int(_config.get("fade_steps", 4)))
	var k: int = clampi(floori(progress * fade_steps), 0, fade_steps)
	_player.modulate.a = 1.0 - float(k) / float(fade_steps)


func _on_body_entered(body: Node2D) -> void:
	var isak := body as Isak
	if isak != null:
		enter(isak)


func _build() -> void:
	var rect: Rect2 = get_door_rect()
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.size * 0.5
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.name = "Door"
	_sprite.texture = load(String(_config["texture"])) as Texture2D
	_sprite.hframes = int(_config.get("frames", {}).get("open", 4)) + 1
	_sprite.centered = false
	var frame_size: Array = _config.get("frame_size", [64, 128])
	_sprite.scale = rect.size / Vector2(float(frame_size[0]), float(frame_size[1]))
	add_child(_sprite)
	_build_label(rect.size)


func _build_label(door_size: Vector2) -> void:
	var scale_factor: int = maxi(1, int(_config.get("font_scale", 2)))
	var font_size: int = int(_config.get("font_size", 12))
	var pad: float = float(_config.get("label_padding_px", 3))
	_font = load(String(_config["font"])) as Font
	var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	text_size.y = _font.get_height(font_size)
	var plate_size := Vector2(ceilf(text_size.x) + pad * 2.0, ceilf(text_size.y) + pad * 2.0)
	_label_root = Node2D.new()
	_label_root.name = "Label"
	_label_root.scale = Vector2.ONE * scale_factor
	var gap: float = float(_config.get("label_gap_px", 12))
	_label_root.position = Vector2(roundf((door_size.x - plate_size.x * scale_factor) * 0.5),
		-gap - plate_size.y * scale_factor)
	add_child(_label_root)
	var border := ColorRect.new()
	border.color = Color.html(String(_config["label_border_color"]))
	border.position = Vector2(-1.0, -1.0)
	border.size = plate_size + Vector2(2.0, 2.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_root.add_child(border)
	_plate = ColorRect.new()
	_plate.color = Color.html(String(_config["label_plate_color"]))
	_plate.size = plate_size
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_root.add_child(_plate)
	_label = Label.new()
	_label.add_theme_font_override(&"font", _font)
	_label.add_theme_font_size_override(&"font_size", font_size)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.text = text
	_label.position = Vector2(pad, pad)
	_label.size = Vector2(ceilf(text_size.x), ceilf(text_size.y))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_root.add_child(_label)
