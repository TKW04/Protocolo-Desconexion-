## Terminal de salida del nivel (2026-10-15; sustituye a la puerta del Cierre del
## 1-1). Tipo `exit_terminal` de la lista `objects` del nivel; contiene la celda
## G. Valores en la seccion exit_terminal de data/world1_objects.json; arte de
## tools/gen_warp_objects.py.
##
## Tocarla no basta:
## 1. Apagada (terminal_off: cursor parpadeando). Con Isak dentro de la zona
##    prompt_zone_px pasa a prompt (terminal_prompt) y aparece encima el icono de
##    la tecla del pulso (leida del Input Map, fuente de textos).
## 2. Al recibir el PULSO (EventBus.pulse_fired: el circulo del pulso toca
##    hit_rect_px, como en PulseReceiver) se activa una sola vez: emite
##    activated(level_id), Isak queda sin control (Isak.begin_warp(false)) y la
##    pantalla se enciende en cian (terminal_boot, luego terminal_on).
## 3. Al acabar el encendido se abre un vortice de salida (WarpVortex.depart)
##    alrededor de Isak, que es absorbido; al cerrarse emite completed(level_id)
##    y EventBus.level_completed(level_id) (LevelRunner lleva al hub).
## No es solida (Area2D, mascara player: solo detecta la cercania de Isak).
## Tiempo del mundo (Debug x0,5; se para con la pausa). El origen del nodo es la
## esquina superior izquierda de su primera celda.
class_name ExitTerminal
extends Area2D

enum State { OFF, PROMPT, BOOT, WARP, DONE }

const GROUP: StringName = &"exit_terminal"
const ANIM_OFF: StringName = &"terminal_off"
const ANIM_PROMPT: StringName = &"terminal_prompt"
const ANIM_BOOT: StringName = &"terminal_boot"
const ANIM_ON: StringName = &"terminal_on"

## El pulso la ha activado (empieza el encendido).
signal activated(level_id: String)
## Isak absorbido: nivel completado (tambien EventBus.level_completed).
signal completed(level_id: String)

@export var object_id: StringName = &""
## Etiqueta opcional encima de la terminal (vacio = sin etiqueta).
@export var text: String = ""
@export_range(1, 8) var width_tiles: int = 1
@export_range(1, 8) var height_tiles: int = 2
## Id del nivel que completa (lo pone el generador). Vacio: GameState.current_level.
@export var level_id: String = ""

var _config: Dictionary = World1ObjectsConfig.section("exit_terminal")
var _state: State = State.OFF
var _time: float = 0.0
var _player: Isak
var _near: Isak
var _completed_count: int = 0
var _sprite: AnimatedSprite2D
var _key_root: Node2D
var _key_label: Label
var _key_base_y: float = 0.0
var _vortex: WarpVortex


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.pulse_fired.connect(receive_pulse)
	_apply_visuals()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_state() -> State:
	return _state


func get_completed_count() -> int:
	return _completed_count


## Isak esta cerca (dentro de prompt_zone_px).
func is_player_near() -> bool:
	return _near != null and is_instance_valid(_near)


## El icono de la tecla del pulso se ve.
func is_key_hint_visible() -> bool:
	return _key_root.visible


## Texto del icono (la tecla del pulso del Input Map, p. ej. "G").
func get_key_hint_text() -> String:
	return _key_label.text


func get_animation() -> StringName:
	return _sprite.animation


func get_vortex() -> WarpVortex:
	return _vortex if _vortex != null and is_instance_valid(_vortex) else null


## Zona que el pulso debe tocar, en coordenadas globales.
func get_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect_px", [0, 0, 64, 128])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


## Zona de cercania, en coordenadas locales.
func get_prompt_zone() -> Rect2:
	var r: Array = _config.get("prompt_zone_px", [-96, 0, 256, 128])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func resolved_level_id() -> String:
	return level_id if not level_id.is_empty() else String(GameState.current_level)


# --- Acciones ---

## Comprueba si el pulso (`area`, con un CircleShape2D) alcanza la terminal y, si
## es asi, la activa. Verdadero si se ha activado ahora.
func receive_pulse(area: Area2D) -> bool:
	if _state != State.OFF and _state != State.PROMPT:
		return false
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	return activate(isak if isak != null else _near)


## Activa la terminal (encendido y luego vortice de salida para `isak`). Falso
## si ya estaba activada.
func activate(isak: Isak) -> bool:
	if _state != State.OFF and _state != State.PROMPT:
		return false
	_state = State.BOOT
	_time = 0.0
	_player = isak
	if _valid(_player):
		_player.begin_warp(false)
	_apply_visuals()
	activated.emit(resolved_level_id())
	return true


## Avanza `delta` segundos de tiempo del mundo.
func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	match _state:
		State.OFF, State.PROMPT:
			_update_near_state()
			_loop(ANIM_PROMPT if _state == State.PROMPT else ANIM_OFF)
			_bob_key()
		State.BOOT:
			var frames: SpriteFrames = _sprite.sprite_frames
			var count: int = frames.get_frame_count(ANIM_BOOT)
			var fps: float = maxf(frames.get_animation_speed(ANIM_BOOT), 0.001)
			var index: int = floori(_time * fps)
			if index < count:
				_sprite.frame = index
			else:
				_start_warp()
		State.WARP, State.DONE:
			_loop(ANIM_ON)


# --- Interno ---

func _start_warp() -> void:
	_state = State.WARP
	_time = 0.0
	_apply_visuals()
	if not _valid(_player):
		_finish()
		return
	_vortex = WarpVortex.depart(_player, self)
	_vortex.finished.connect(_finish)


func _finish() -> void:
	if _state == State.DONE:
		return
	_state = State.DONE
	_completed_count += 1
	var id: String = resolved_level_id()
	completed.emit(id)
	EventBus.level_completed.emit(id)


func _update_near_state() -> void:
	var near: bool = is_player_near()
	var target: State = State.PROMPT if near else State.OFF
	if target != _state:
		_state = target
		_time = 0.0
		_apply_visuals()


func _apply_visuals() -> void:
	match _state:
		State.OFF:
			_show(ANIM_OFF)
		State.PROMPT:
			_show(ANIM_PROMPT)
		State.BOOT:
			_show(ANIM_BOOT)
		_:
			_show(ANIM_ON)
	_key_root.visible = _state == State.PROMPT


func _show(anim: StringName) -> void:
	if _sprite.animation != anim:
		_sprite.animation = anim
	_sprite.frame = 0


func _loop(anim: StringName) -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	var count: int = frames.get_frame_count(anim)
	var fps: float = frames.get_animation_speed(anim)
	_sprite.frame = (floori(_time * fps) % count) if fps > 0.0 and count > 0 else 0


func _bob_key() -> void:
	if not _key_root.visible:
		return
	var period: float = maxf(float(_config.get("key_bob_s", 0.35)), 0.01)
	var up: bool = int(floorf(_time / period)) % 2 == 1
	_key_root.position.y = _key_base_y - (float(_config.get("key_bob_px", 2)) if up else 0.0)


func _valid(isak: Isak) -> bool:
	return isak != null and is_instance_valid(isak)


func _on_body_entered(body: Node2D) -> void:
	var isak := body as Isak
	if isak != null:
		_near = isak


func _on_body_exited(body: Node2D) -> void:
	if body == _near:
		_near = null


## Primera tecla de la accion del pulso en el Input Map (p. ej. "G").
func _pulse_key_text() -> String:
	var action := StringName(String(_config.get("pulse_action", "pulse")))
	if InputMap.has_action(action):
		var data: Dictionary = AbilityNotices.load_data()
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key: String = AbilityNotices.key_name(event as InputEventKey, data)
				if not key.is_empty():
					return key
	return "G"


func _build() -> void:
	var t: float = World1ObjectsConfig.tile_size()
	var size := Vector2(width_tiles * t, height_tiles * t)
	var zone: Rect2 = get_prompt_zone()
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = zone.size
	shape.shape = box
	shape.position = zone.get_center()
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Terminal"
	_sprite.sprite_frames = load(String(_config["frames"])) as SpriteFrames
	_sprite.centered = false
	var frame_size: Array = _config.get("frame_size", [64, 128])
	_sprite.scale = size / Vector2(float(frame_size[0]), float(frame_size[1]))
	_sprite.animation = ANIM_OFF
	add_child(_sprite)
	var font: Font = load(String(_config["font"])) as Font
	var monitor_top: float = float(_config.get("monitor_top_px", 30)) * _sprite.scale.y
	_key_root = _plate("KeyHint", _pulse_key_text(), font, String(_config["key_plate_color"]),
		String(_config["key_border_color"]), float(_config.get("key_padding_px", 3)), size.x,
		monitor_top - float(_config.get("key_gap_px", 8)))
	_key_label = _key_root.get_node(^"Text") as Label
	_key_base_y = _key_root.position.y
	if not text.is_empty():
		_plate("Label", text, font, String(_config["label_plate_color"]), String(_config["label_border_color"]),
			float(_config.get("label_padding_px", 3)), size.x, monitor_top - float(_config.get("label_gap_px", 44)))


## Placa con borde y texto (fuente de textos a font_scale), centrada en
## horizontal y con su borde inferior en `bottom` (px locales).
func _plate(node_name: String, label_text: String, font: Font, plate_color: String, border_color: String,
		pad: float, width: float, bottom: float) -> Node2D:
	var scale_factor: int = maxi(1, int(_config.get("font_scale", 2)))
	var font_size: int = int(_config.get("font_size", 12))
	var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	text_size.y = font.get_height(font_size)
	var plate_size := Vector2(ceilf(text_size.x) + pad * 2.0, ceilf(text_size.y) + pad * 2.0)
	var root := Node2D.new()
	root.name = node_name
	root.scale = Vector2.ONE * scale_factor
	root.position = Vector2(roundf((width - plate_size.x * scale_factor) * 0.5),
		roundf(bottom - plate_size.y * scale_factor))
	add_child(root)
	var border := ColorRect.new()
	border.color = Color.html(border_color)
	border.position = Vector2(-1.0, -1.0)
	border.size = plate_size + Vector2(2.0, 2.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border)
	var plate := ColorRect.new()
	plate.color = Color.html(plate_color)
	plate.size = plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	var label := Label.new()
	label.name = "Text"
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = label_text
	label.position = Vector2(pad, pad)
	label.size = Vector2(ceilf(text_size.x), ceilf(text_size.y))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return root
