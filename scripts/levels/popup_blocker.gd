## Pop-up bloqueante (Mundo 1, Tramo 4 del 1-1: "Pop-up que bloquea el paso. El
## boton de cerrar es diminuto y hay que acertarle con el pulso"; 6.2: "Pulso al
## boton de cerrar, que casi siempre es muy pequeno"). Tipo `popup_blocker` de
## la lista `objects` del nivel (V7). PROPUESTA V5 (docs/preguntas.md).
##
## - Ventana solida (capa world) de width_tiles x height_tiles con un texto de
##   humor (fuente de textos, recoloreada a noche_profunda) y un boton de cerrar
##   diminuto (close_button_size px, rojo alerta) en close_button_position.
## - El boton es un Area2D (mascara pulse). Solo un pulso cuya PulseArea toque el
##   boton cierra el pop-up: por EventBus.pulse_fired(area) (circulo real de la
##   PulseArea frente al rectangulo del boton, PulseReceiver.pulse_reaches) o
##   por solapamiento fisico mientras el pulso sigue activo (area_entered). Un
##   pulso que toca la ventana pero no el boton no hace nada.
## - Al acertarle se cierra por pasos (cuadros 1-4 de la hoja a close_fps:
##   lineas desplazadas, aplastado, raya, restos). Al terminar deja de ser
##   solido, desaparece y no se vuelve a abrir.
## - El Debug no cambia nada (solo ralentiza la animacion: tiempo del mundo).
## El origen del nodo es la esquina superior izquierda de su primera celda.
class_name PopupBlocker
extends StaticBody2D

enum State { OPEN, CLOSING, CLOSED }

const GROUP: StringName = &"popup_blocker"
const LAYER_WORLD: int = 1
const LAYER_PULSE: int = 8

## Un pulso ha acertado al boton: empieza la animacion de cierre.
signal closing_started
## Animacion terminada: ya no es solido.
signal closed

@export var object_id: StringName = &""
@export_multiline var text: String = ""
@export_range(1, 32) var width_tiles: int = 3
@export_range(1, 32) var height_tiles: int = 4
## Esquina superior izquierda del boton en px, relativa a la del pop-up.
@export var close_button_position: Vector2 = Vector2(4.0, 192.0)
## Lado del boton en px.
@export_range(4, 64) var close_button_size: int = 16

var _config: Dictionary = World1ObjectsConfig.section("popup_blocker")
var _state: State = State.OPEN
var _close_time: float = 0.0
var _blink_time: float = 0.0
var _font: Font
var _lines: PackedStringArray = []
var _shape: CollisionShape2D
var _window: Sprite2D
var _text_root: Node2D
var _label: Label
var _button: Area2D
var _button_shape: CollisionShape2D
var _button_sprite: Sprite2D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_build()
	EventBus.pulse_fired.connect(receive_pulse)
	_button.area_entered.connect(_on_button_area_entered)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; solo abierto (cerrandose o cerrado ya no da informacion).
func is_help_available() -> bool:
	return _state == State.OPEN


func is_open() -> bool:
	return _state == State.OPEN


func is_closed() -> bool:
	return _state == State.CLOSED


## Solido (bloquea el paso) hasta terminar de cerrarse.
func is_solid() -> bool:
	return _state != State.CLOSED


## Tamano del pop-up en px.
func get_size_px() -> Vector2:
	var t: float = World1ObjectsConfig.tile_size()
	return Vector2(width_tiles * t, height_tiles * t)


## Rectangulo del boton de cerrar en coordenadas globales.
func get_button_rect() -> Rect2:
	return Rect2(global_position + close_button_position, Vector2.ONE * close_button_size)


## Rectangulo de la ventana en coordenadas globales.
func get_window_rect() -> Rect2:
	return Rect2(global_position, get_size_px())


func get_button_area() -> Area2D:
	return _button


## Lineas del texto tal como se dibujan.
func get_text_lines() -> PackedStringArray:
	return _lines


func get_font() -> Font:
	return _font


## Cuadro actual de la ventana (0 = abierta; 1-4 = cierre).
func get_window_frame() -> int:
	return _window.frame


func get_button_frame() -> int:
	return _button_sprite.frame


# --- Acciones ---

## Comprueba si el pulso (`area`, con un CircleShape2D) toca el BOTON y, si es
## asi, cierra el pop-up. Devuelve verdadero si se ha empezado a cerrar ahora.
func receive_pulse(area: Area2D) -> bool:
	if _state != State.OPEN:
		return false
	if not PulseReceiver.pulse_reaches(area, get_button_rect()):
		return false
	close()
	return true


## Empieza a cerrarse (sin efecto si ya se cerro o se esta cerrando).
func close() -> void:
	if _state != State.OPEN:
		return
	_state = State.CLOSING
	_close_time = 0.0
	_label.visible = false
	_button_sprite.frame = _button_frame(&"hit")
	_button.set_deferred(&"monitoring", false)
	closing_started.emit()


## Avanza `delta` segundos de tiempo del mundo (parpadeo del boton y cierre).
func advance(delta: float) -> void:
	match _state:
		State.OPEN:
			_blink_time += delta
			var period: float = maxf(float(_config.get("button_blink_s", 0.4)), 0.01)
			var glow: bool = int(floorf(_blink_time / period)) % 2 == 1
			_button_sprite.frame = _button_frame(&"glow" if glow else &"normal")
		State.CLOSING:
			_close_time += delta
			var frames: int = int(_config.get("frames", 5))
			var step: int = 1 + floori(_close_time * float(_config.get("close_fps", 12.0)))
			_button_sprite.visible = false
			if step >= frames:
				_finish_close()
			else:
				_window.frame = step


# --- Interno ---

func _finish_close() -> void:
	_state = State.CLOSED
	_window.visible = false
	_shape.set_deferred(&"disabled", true)
	closed.emit()


func _button_frame(name: StringName) -> int:
	var frames: Dictionary = _config.get("button_frames", {})
	return int(frames.get(String(name), 0))


func _on_button_area_entered(area: Area2D) -> void:
	if area.collision_layer & LAYER_PULSE:
		receive_pulse(area)


func _build() -> void:
	var size: Vector2 = get_size_px()
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5
	add_child(_shape)
	# Ventana.
	_window = Sprite2D.new()
	_window.name = "Window"
	_window.texture = load(String(_config["texture"])) as Texture2D
	_window.hframes = int(_config.get("frames", 5))
	_window.centered = false
	var frame_size: Array = _config.get("frame_size", [192, 256])
	_window.scale = size / Vector2(float(frame_size[0]), float(frame_size[1]))
	add_child(_window)
	# Texto.
	_build_text()
	# Boton.
	_button = Area2D.new()
	_button.name = "CloseButton"
	_button.collision_layer = 0
	_button.collision_mask = LAYER_PULSE
	_button.monitorable = false
	_button.position = close_button_position
	_button_shape = CollisionShape2D.new()
	var button_rect := RectangleShape2D.new()
	button_rect.size = Vector2.ONE * close_button_size
	_button_shape.shape = button_rect
	_button_shape.position = button_rect.size * 0.5
	_button.add_child(_button_shape)
	_button_sprite = Sprite2D.new()
	_button_sprite.texture = load(String(_config["button_texture"])) as Texture2D
	_button_sprite.hframes = 3
	_button_sprite.centered = false
	_button_sprite.scale = Vector2.ONE * (float(close_button_size) / float(_config.get("button_frame_px", 16)))
	_button.add_child(_button_sprite)
	add_child(_button)


func _build_text() -> void:
	var scale_factor: int = maxi(1, int(_config.get("font_scale", 2)))
	var font_size: int = int(_config.get("font_size", 12))
	var r: Array = _config.get("text_rect_px", [12, 28, 168, 160])
	_font = load(String(_config["font"])) as Font
	_lines = EcoTextBox.wrap_text(text, _font, font_size, float(r[2]) / scale_factor)
	_text_root = Node2D.new()
	_text_root.name = "Text"
	_text_root.position = Vector2(float(r[0]), float(r[1]))
	_text_root.scale = Vector2.ONE * scale_factor
	add_child(_text_root)
	_label = Label.new()
	_label.add_theme_font_override(&"font", _font)
	_label.add_theme_font_size_override(&"font_size", font_size)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_constant_override(&"line_spacing", 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.text = "\n".join(_lines)
	_label.size = Vector2(float(r[2]), float(r[3])) / scale_factor
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(String(_config["key_swap_shader"])) as Shader
	material.set_shader_parameter(&"key_color", Color.html(String(_config["key_color"])))
	material.set_shader_parameter(&"target_color", Color.html(String(_config["text_color"])))
	_label.material = material
	_text_root.add_child(_label)
