## Pop-up translucido (tipo `overlay_popup` del catalogo del Mundo 1; 1-2 §3.1,
## §3.3 y §3.4 de docs/propuesta-1-2.md; paso 7 de §10; docs/mundo-1-
## notificaciones.md §6.2: «aparece sobre la pantalla y tapa parte de la
## vista», con el boton de cerrar casi siempre muy pequeno).
##
## - Ventana de width_tiles x height_tiles con un texto de humor, dibujada POR
##   ENCIMA del mundo (z_index alto; por debajo de la interfaz) con `opacity`
##   (0,7): tapa lo que hay detras (una plataforma, un enemigo, un hueco).
## - NO tiene colision: no bloquea el movimiento ni el laser (a diferencia del
##   popup_blocker).
## - Se cierra con el PULSO a su boton (Area2D en la mascara pulse; misma prueba
##   que el popup_blocker: el circulo del pulso contra el rectangulo del boton).
##   Un pulso que solo toca la ventana no hace nada. Cerrado, queda cerrado.
## - Con el DEBUG se «ve a traves»: la opacidad baja a debug_opacity (0,15) con
##   la intensidad del Debug y aparece un contorno cian discontinuo (la ventana
##   «vista con Debug»). Sin Debug, tapa.
## - Anuncio encima (AdCover con target == su id): como en el popup_blocker,
##   mientras este entero el pulso al boton no lo cierra.
## - El cierre (unos cuadros en que se pliega) va en tiempo del mundo.
## El origen del nodo es la esquina superior izquierda de su primera celda.
## Pop-up escudo de Alerta Mayor (2026-10-21, paso 7 de
## docs/propuesta-jefe-alerta-mayor.md §6, §2.6): `opaque` (opaco del todo; el
## Debug tampoco ve a traves), `follow_target` + `follow_offset` (sigue a un nodo:
## el cuerpo del jefe), `icon_texture` (icono en el centro), `respawn_s` (cerrado,
## vuelve a abrirse tras esos s del mundo; 0 = nunca) y reopen(). Por defecto, el
## pop-up translucido del 1-2 de siempre.
class_name OverlayPopup
extends Node2D

enum State { OPEN, CLOSING, CLOSED }

const GROUP: StringName = &"overlay_popup"
const LAYER_PULSE: int = 8

signal closing_started
signal closed

@export var object_id: StringName = &""
@export_multiline var text: String = ""
@export_range(1, 16) var width_tiles: int = 5
@export_range(1, 16) var height_tiles: int = 3
## Esquina superior izquierda del boton en px, relativa a la del pop-up.
@export var close_button_position: Vector2 = Vector2(280.0, 152.0)
## Lado del boton (y de su zona de golpe) en px.
@export_range(8, 64) var close_button_size: int = 24
## Opacidad sin Debug (0-1).
@export var opacity: float = 0.7
## Opacidad con el Debug activo del todo.
@export var debug_opacity: float = 0.15
## Opaco del todo y sin ver a traves con el Debug (escudo del jefe).
@export var opaque: bool = false
## Cerrado, vuelve a abrirse tras respawn_s segundos del mundo (0 = nunca).
@export var respawn_s: float = 0.0
## Nodo al que sigue (su esquina superior izquierda = su posicion + follow_offset).
var follow_target: Node2D
var follow_offset: Vector2 = Vector2.ZERO
## Icono centrado sobre la ventana (null = ninguno).
var icon_texture: Texture2D

var _config: Dictionary = World1ObjectsConfig.section("overlay_popup")
var _state: State = State.OPEN
var _close_time: float = 0.0
var _time: float = 0.0
var _frames: SpriteFrames
var _window: Node2D
var _body: NinePatchRect
var _debug_frame: NinePatchRect
var _label: Label
var _button: Area2D
var _button_sprite: AnimatedSprite2D
var _covers: Array[Node] = []
var _closed_time: float = 0.0
var _icon: Sprite2D

## SpriteFrames ya cargados por ruta (rendimiento, 2026-10-21). La hoja de los
## objetos de la torre es grande: cargarla en el _ready de cada pop-up costaba un
## tiron de 75-140 ms cada vez que no quedaba ninguno vivo (la cache de recursos la
## suelta al liberarse el ultimo). Se guarda aqui y se puede precargar (preload_frames).
static var _frames_cache: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	_frames = frames_for(String(_config.get("frames", "")))
	_build()
	EventBus.pulse_fired.connect(receive_pulse)
	_button.area_entered.connect(_on_button_area_entered)
	_update_visual()


## SpriteFrames de `path` (cargado una vez y guardado en la cache estatica).
static func frames_for(path: String) -> SpriteFrames:
	if not _frames_cache.has(path):
		_frames_cache[path] = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
	return _frames_cache[path]


## Carga ya la hoja de los pop-ups (p. ej. al montar la arena del jefe, que los
## crea en plena pelea), para que el primero no de un tiron.
static func preload_frames() -> void:
	frames_for(String(World1ObjectsConfig.section("overlay_popup").get("frames", "")))


func _process(delta: float) -> void:
	if follow_target != null and is_instance_valid(follow_target):
		global_position = follow_target.global_position + follow_offset
	advance(WorldTime.scaled_delta(delta))


## Opacidad de una capa que el Debug «ve a traves» (la regla del pop-up
## translucido, compartida con el filtro del Mundo 3, FilterZone): de `base` sin
## Debug a `debug` con la intensidad de revelado del Debug (0-1).
static func see_through_alpha(base: float, debug: float, intensity: float) -> float:
	return lerpf(base, debug, clampf(intensity, 0.0, 1.0))


# --- Consultas ---

func get_state() -> State:
	return _state


func is_open() -> bool:
	return _state == State.OPEN


func is_closed() -> bool:
	return _state == State.CLOSED


## Ayuda de Eco: solo abierto (cerrandose o cerrado ya no tapa nada).
func is_help_available() -> bool:
	return _state == State.OPEN


func get_size_px() -> Vector2:
	var t: float = World1ObjectsConfig.tile_size()
	return Vector2(width_tiles * t, height_tiles * t)


func get_window_rect() -> Rect2:
	return Rect2(global_position, get_size_px())


func get_button_rect() -> Rect2:
	return Rect2(global_position + close_button_position, Vector2.ONE * close_button_size)


func get_button_area() -> Area2D:
	return _button


## Opacidad con la que se dibuja ahora la ventana (0 cerrada).
func get_current_opacity() -> float:
	if _state == State.CLOSED or _window == null or not _window.visible:
		return 0.0
	return _body.modulate.a


## Opacidad del contorno «visto con Debug» (0 sin Debug).
func get_debug_outline_alpha() -> float:
	return _debug_frame.modulate.a if _debug_frame != null and _debug_frame.visible else 0.0


## Tapa el punto `world_pos` (ventana abierta y opaca de verdad: mas de la mitad).
func hides_point(world_pos: Vector2) -> bool:
	return get_current_opacity() > 0.5 and get_window_rect().has_point(world_pos)


func get_text() -> String:
	return _label.text if _label != null else ""


func get_z() -> int:
	return int(_config.get("z_index", 50))


func is_button_covered() -> bool:
	for cover: Node in _covers:
		if is_instance_valid(cover) and bool(cover.call(&"is_intact")):
			return true
	return false


# --- Acciones ---

## Un anuncio (AdCover) tapa el boton mientras is_intact() sea verdadero.
func add_cover(cover: Node) -> void:
	if cover != null and not _covers.has(cover):
		_covers.append(cover)


## El pulso (`area`) toca el BOTON: se cierra. Verdadero si empieza a cerrarse ahora.
func receive_pulse(area: Area2D) -> bool:
	if _state != State.OPEN or is_button_covered():
		return false
	if not PulseReceiver.pulse_reaches(area, get_button_rect()):
		return false
	close()
	return true


## Vuelve a abrirse (cerrado o cerrandose): el escudo del jefe.
func reopen() -> void:
	if _state == State.OPEN:
		return
	_state = State.OPEN
	_closed_time = 0.0
	_window.scale = Vector2.ONE
	_window.position = Vector2.ZERO
	_button.set_deferred(&"monitoring", true)
	_update_visual()


func close() -> void:
	if _state != State.OPEN:
		return
	_state = State.CLOSING
	_close_time = 0.0
	_button.set_deferred(&"monitoring", false)
	closing_started.emit()
	_update_visual()


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += dt
	if _state == State.CLOSING:
		_close_time += dt
		if _close_time >= float(_config.get("close_s", 0.33)):
			_state = State.CLOSED
			_closed_time = 0.0
			closed.emit()
	elif _state == State.CLOSED and respawn_s > 0.0:
		_closed_time += dt
		if _closed_time >= respawn_s:
			reopen()
	_update_visual()


# --- Interno ---

func _update_visual() -> void:
	if _window == null:
		return
	# Revelado persistente (Debug 3): tras apagar el Debug se sigue viendo a traves.
	var intensity: float = 0.0 if opaque else DebugMode.get_reveal_intensity()
	var alpha: float = 1.0 if opaque else see_through_alpha(opacity, debug_opacity, intensity)
	_body.modulate.a = alpha
	_label.modulate.a = alpha
	_debug_frame.visible = intensity > 0.0
	_debug_frame.modulate.a = intensity
	match _state:
		State.OPEN:
			_window.visible = true
			_window.scale = Vector2.ONE
			var blink: float = maxf(float(_config.get("button_blink_s", 0.4)), 0.01)
			_button_sprite.frame = 1 if int(floorf(_time / blink)) % 2 == 1 else 0
			_button_sprite.modulate.a = maxf(alpha, float(_config.get("button_min_alpha", 0.85)))
		State.CLOSING:
			# Se pliega en pasos hacia su linea central (tiempo del mundo).
			var steps: int = maxi(1, int(_config.get("close_steps", 4)))
			var k: int = mini(floori(_close_time / maxf(float(_config.get("close_s", 0.33)), 0.01) * steps), steps - 1)
			var size: Vector2 = get_size_px()
			_window.scale = Vector2(1.0, 1.0 - float(k + 1) / float(steps + 1))
			_window.position.y = size.y * 0.5 * (1.0 - _window.scale.y)
			_button_sprite.frame = 2
		State.CLOSED:
			_window.visible = false


func _build() -> void:
	var size: Vector2 = get_size_px()
	_window = Node2D.new()
	_window.name = "Window"
	_window.z_index = get_z()
	_window.z_as_relative = false
	add_child(_window)
	_body = _nine_patch(&"overlay_frame", NinePatchRect.AXIS_STRETCH_MODE_STRETCH)
	_body.name = "Body"
	_body.size = size
	_window.add_child(_body)
	_debug_frame = _nine_patch(&"overlay_frame_debug", NinePatchRect.AXIS_STRETCH_MODE_TILE)
	_debug_frame.name = "DebugFrame"
	_debug_frame.size = size
	_window.add_child(_debug_frame)
	var bell := Sprite2D.new()
	bell.name = "Bell"
	bell.texture = _frames.get_frame_texture(&"overlay_bell", 0)
	bell.centered = false
	bell.position = Vector2(3.0, 2.0)
	_body.add_child(bell)
	_build_text(size)
	if icon_texture != null:
		_icon = Sprite2D.new()
		_icon.name = "Icon"
		_icon.texture = icon_texture
		_icon.position = size * 0.5
		_window.add_child(_icon)
	_button = Area2D.new()
	_button.name = "CloseButton"
	_button.collision_layer = 0
	_button.collision_mask = LAYER_PULSE
	_button.monitorable = false
	_button.position = close_button_position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * close_button_size
	shape.shape = rect
	shape.position = rect.size * 0.5
	_button.add_child(shape)
	_button_sprite = AnimatedSprite2D.new()
	_button_sprite.name = "Sprite"
	_button_sprite.sprite_frames = _frames
	_button_sprite.animation = &"overlay_close"
	_button_sprite.centered = false
	var art: float = float(_frames.get_frame_texture(&"overlay_close", 0).get_width())
	_button_sprite.scale = Vector2.ONE * (float(close_button_size) / art)
	_button.add_child(_button_sprite)
	_window.add_child(_button)


func _nine_patch(anim: StringName, mode: NinePatchRect.AxisStretchMode) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = _frames.get_frame_texture(anim, 0)
	var m: Array = _config.get("patch_margins", [4, 16, 4, 4])
	patch.patch_margin_left = int(m[0])
	patch.patch_margin_top = int(m[1])
	patch.patch_margin_right = int(m[2])
	patch.patch_margin_bottom = int(m[3])
	patch.axis_stretch_horizontal = mode
	patch.axis_stretch_vertical = mode
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return patch


func _build_text(size: Vector2) -> void:
	var scale_factor: int = maxi(1, int(_config.get("font_scale", 2)))
	var font_size: int = int(_config.get("font_size", 12))
	var pad: Array = _config.get("text_padding_px", [10, 22, 10, 8])
	var font := load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var width: float = (size.x - float(pad[0]) - float(pad[2])) / scale_factor
	var root := Node2D.new()
	root.name = "Text"
	root.position = Vector2(float(pad[0]), float(pad[1]))
	root.scale = Vector2.ONE * scale_factor
	_window.add_child(root)
	_label = Label.new()
	_label.add_theme_font_override(&"font", font)
	_label.add_theme_font_size_override(&"font_size", font_size)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_constant_override(&"line_spacing", 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.text = "\n".join(EcoTextBox.wrap_text(text, font, font_size, width))
	_label.size = Vector2(width, (size.y - float(pad[1]) - float(pad[3])) / scale_factor)
	_label.clip_text = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(String(_config.get("key_swap_shader", "res://assets/shaders/hud_key_swap.gdshader"))) as Shader
	material.set_shader_parameter(&"key_color", Color.html(String(_config.get("key_color", "#f2f4f8"))))
	material.set_shader_parameter(&"target_color", Color.html(String(_config.get("text_color", "#0b0e1a"))))
	_label.material = material
	root.add_child(_label)


func _on_button_area_entered(area: Area2D) -> void:
	if area.collision_layer & LAYER_PULSE:
		receive_pulse(area)
