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
## 3. Al acabar el encendido, giro (TURN, turn_ticks pasos de turn_tick_s): la
##    pantalla se queda llena de cian e Isak se tine de cian (destello,
##    turn_flash_ticks pasos) y en el paso turn_back_tick se pone de espaldas,
##    mirando al monitor (Isak.face_back). Sin arte nuevo.
## 4. Al acabar el giro se abre un vortice de salida (WarpVortex.depart)
##    alrededor de Isak de espaldas, que es absorbido; al cerrarse emite
##    completed(level_id) y EventBus.level_completed(level_id) (LevelRunner
##    lleva al hub).
## No es solida (Area2D, mascara player: solo detecta la cercania de Isak).
## Tiempo del mundo (Debug x0,5; se para con la pausa). El origen del nodo es la
## esquina superior izquierda de su primera celda.
class_name ExitTerminal
extends Area2D

enum State { OFF, PROMPT, BOOT, TURN, WARP, DONE }

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
	# La tecla se vuelve a leer del Input Map al reasignar los controles.
	EventBus.controls_changed.connect(refresh_key)
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
			return
		State.WARP, State.DONE:
			_loop(ANIM_ON)
			return
	# Encendido y giro: un paso largo puede cruzar los dos (el tiempo sobrante
	# pasa al giro).
	if _state == State.BOOT:
		var frames: SpriteFrames = _sprite.sprite_frames
		var count: int = frames.get_frame_count(ANIM_BOOT)
		var fps: float = maxf(frames.get_animation_speed(ANIM_BOOT), 0.001)
		var index: int = floori(_time * fps)
		if index < count:
			_sprite.frame = index
			return
		_time -= count / fps
		_start_turn()
	if _state == State.TURN:
		_update_turn()


## Paso actual del giro (0 .. turn_ticks - 1); -1 fuera del giro.
func get_turn_tick() -> int:
	if _state != State.TURN:
		return -1
	return floori(_time / _turn_tick_s())


## Destello cian del giro en curso (pantalla llena de cian e Isak tenido).
func is_turn_flashing() -> bool:
	return _state == State.TURN and get_turn_tick() < int(_config.get("turn_flash_ticks", 2))


# --- Interno ---

func _turn_tick_s() -> float:
	return maxf(float(_config.get("turn_tick_s", 1.0 / 12.0)), 0.001)


func _start_turn() -> void:
	_state = State.TURN
	_apply_visuals()


## Destello (pantalla llena: ultimo cuadro del encendido; Isak tenido de cian),
## giro de Isak en turn_back_tick y, al acabar los turn_ticks, el vortice.
func _update_turn() -> void:
	var tick: int = get_turn_tick()
	if tick >= maxi(int(_config.get("turn_ticks", 3)), 0):
		_start_warp()
		return
	var flashing: bool = is_turn_flashing()
	if flashing:
		_show(ANIM_BOOT)
		_sprite.frame = _sprite.sprite_frames.get_frame_count(ANIM_BOOT) - 1
	else:
		if _sprite.animation != ANIM_ON:
			_sprite.animation = ANIM_ON
		_loop(ANIM_ON)
	_tint_player(flashing)
	if tick >= int(_config.get("turn_back_tick", 1)) and _valid(_player) and not _player.is_facing_back():
		_player.face_back()


## Tine a Isak con turn_flash_modulate (solo RGB; la opacidad es del vortice).
func _tint_player(on: bool) -> void:
	if not _valid(_player):
		return
	var color := Color.WHITE
	if on:
		var c: Array = _config.get("turn_flash_modulate", [1, 1, 1])
		color = Color(float(c[0]), float(c[1]), float(c[2]))
	_player.modulate = Color(color.r, color.g, color.b, _player.modulate.a)


func _start_warp() -> void:
	_state = State.WARP
	_time = 0.0
	_tint_player(false)
	if _valid(_player) and not _player.is_facing_back():
		_player.face_back()
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
		State.BOOT, State.TURN:
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
	_key_root.position.y = PulsePrompt.bob_y(_key_base_y, _time, float(_config.get("key_bob_s", 0.35)),
		float(_config.get("key_bob_px", 2)))


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
	return PulsePrompt.key_text(StringName(String(_config.get("pulse_action", "pulse"))))


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
## horizontal y con su borde inferior en `bottom` (px locales). PulsePrompt.
func _plate(node_name: String, label_text: String, font: Font, plate_color: String, border_color: String,
		pad: float, width: float, bottom: float) -> Node2D:
	return PulsePrompt.make_plate(self, node_name, label_text, font, int(_config.get("font_size", 12)),
		int(_config.get("font_scale", 2)), plate_color, border_color, pad, width, bottom)


## Vuelve a leer la tecla del pulso del Input Map (tras reasignar los controles).
func refresh_key() -> void:
	if _key_root == null:
		return
	PulsePrompt.set_plate_text(_key_root, _pulse_key_text(), load(String(_config["font"])) as Font, int(_config.get("font_size", 12)),
		float(_config.get("key_padding_px", 3)))


## Texto de la tecla que muestra el prompt (pruebas).
func get_key_text() -> String:
	return (_key_root.get_node(^"Text") as Label).text if _key_root != null else ""
