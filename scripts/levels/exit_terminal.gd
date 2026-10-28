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
## CORRIENTE (2026-10-17, tanda H1 del paso 14 del 1-2, encuentro con Calc):
## con requires_power (por defecto falso: el 1-1 no cambia) esta APAGADA hasta
## que la pieza power_source (CalcRoom; p. ej. el ChargeDock cuando Calc se va)
## tiene corriente (is_power_on()): pantalla negra (primer cuadro de
## terminal_off tenido con unpowered_modulate), sin prompt ni tecla, sin Q y el
## pulso no hace nada. Al llegar la corriente emite powered y funciona como
## siempre.
## CUENTA AUTOMATICA (2026-10-22, paso 11 de docs/propuesta-mundo-2.md, cierre
## del 2-1 «Quedan 3 segundos para el siguiente video. No puedes cancelar»;
## decision 6 de su §9): con countdown_s > 0 el pulso no hace nada y no sale la
## tecla; al entrar Isak en la zona de cercania empieza una cuenta de
## countdown_s (tiempo del mundo) que se ve en la placa de encima («3», «2»,
## «1»; senal countdown_started) y que NO se cancela al salir de la zona; al
## acabar se activa sola (encendido, giro y vortice de salida, como con el
## pulso). Por defecto 0: el 1-1 al 1-3 no cambian.
## SIN CONEXION (2026-10-28, paso 14 de docs/propuesta-mundo-4.md, cierre del
## 4-3 «Responder más tarde» segun V15, §10.2: en Caché Isak sale sin responder):
## con offline_text (por defecto vacio: los cierres anteriores no cambian), el
## pulso la activa como siempre pero antes del encendido pasa offline_s segundos
## (tiempo del mundo) con Isak sin control, el campo de respuesta con el cursor
## que parpadea (terminal_prompt) y la placa offline_text («Sin conexión») en
## lugar de la etiqueta (senal offline_shown); despues, encendido, giro y vortice.
## No es solida (Area2D, mascara player: solo detecta la cercania de Isak).
## Tiempo del mundo (Debug x0,5; se para con la pausa). El origen del nodo es la
## esquina superior izquierda de su primera celda.
class_name ExitTerminal
extends Area2D

enum State { OFF, PROMPT, COUNTDOWN, BOOT, TURN, WARP, DONE, OFFLINE }

const GROUP: StringName = &"exit_terminal"
const ANIM_OFF: StringName = &"terminal_off"
const ANIM_PROMPT: StringName = &"terminal_prompt"
const ANIM_BOOT: StringName = &"terminal_boot"
const ANIM_ON: StringName = &"terminal_on"

## El pulso la ha activado (empieza el encendido).
signal activated(level_id: String)
## Isak absorbido: nivel completado (tambien EventBus.level_completed).
signal completed(level_id: String)
## Le ha llegado la corriente (requires_power).
signal powered
## Empieza la cuenta automatica (countdown_s > 0).
signal countdown_started(seconds: float)
## Sale la placa «Sin conexión» (offline_text) al activarla (2026-10-28).
signal offline_shown(text: String)

@export var object_id: StringName = &""
## Etiqueta opcional encima de la terminal (vacio = sin etiqueta).
@export var text: String = ""
@export_range(1, 8) var width_tiles: int = 1
@export_range(1, 8) var height_tiles: int = 2
## Id del nivel que completa (lo pone el generador). Vacio: GameState.current_level.
@export var level_id: String = ""
## Apagada hasta que power_source tenga corriente (2026-10-17).
@export var requires_power: bool = false
## Id de la pieza que le da corriente (CalcRoom; is_power_on()).
@export var power_source: StringName = &""
## Aspecto (2026-10-22): vacio = monitor de siempre; lock_screen = pantalla de
## bloqueo (cierre del 1-3). Mismas animaciones y tamano: solo cambia el dibujo.
@export var skin: StringName = &""
## Cuenta automatica en segundos (2026-10-22): > 0 = se activa sola al acabar la
## cuenta, que empieza al entrar Isak en la zona; sin pulso. 0 = con el pulso.
@export_range(0.0, 10.0) var countdown_s: float = 0.0
## Placa que sale al activarla, antes del encendido (2026-10-28; vacio = sin ella).
@export var offline_text: String = ""
## Segundos (tiempo del mundo) con la placa offline_text antes del encendido.
@export_range(0.5, 4.0) var offline_s: float = 1.6

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
var _had_power: bool = true
var _label_root: Node2D
var _offline_root: Node2D


func _ready() -> void:
	add_to_group(GROUP)
	# Pieza enlazable del acertijo de la azotea (guion de Eco; 2026-10-17).
	add_to_group(CalcRoom.LINK_GROUP)
	_build()
	# La tecla se vuelve a leer del Input Map al reasignar los controles.
	EventBus.controls_changed.connect(refresh_key)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.pulse_fired.connect(receive_pulse)
	_had_power = not requires_power
	_apply_visuals()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

## Ayuda de Eco (HelpCatalog.is_help_live): lo destruido no ayuda; activada (encendiendose, girando, vortice), no.
func is_help_available() -> bool:
	return (_state == State.OFF or _state == State.PROMPT) and is_powered()


## Se activa sola con la cuenta (countdown_s > 0), sin pulso.
func is_automatic() -> bool:
	return countdown_s > 0.0


## Segundos que le quedan a la cuenta (-1 si no esta contando).
func get_countdown_left() -> float:
	return maxf(countdown_s - _time, 0.0) if _state == State.COUNTDOWN else -1.0


## Tiene corriente (sin requires_power, siempre).
func is_powered() -> bool:
	if not requires_power:
		return true
	if not is_inside_tree():
		return false
	var source: Node = CalcRoom.find(self, power_source)
	return source != null and source.has_method(&"is_power_on") and bool(source.call(&"is_power_on"))


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


## La placa offline_text se ve (mientras dura el «Sin conexión»).
func is_offline_shown() -> bool:
	return _offline_root != null and _offline_root.visible


## SpriteFrames del aspecto (skin; sin skin o desconocido, frames de la seccion).
func get_frames_path() -> String:
	var skins: Dictionary = _config.get("skins", {})
	return String(skins.get(String(skin), _config["frames"]))


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
	if is_automatic():
		return false
	if (_state != State.OFF and _state != State.PROMPT) or not is_powered():
		return false
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	return activate(isak if isak != null else _near)


## Activa la terminal (encendido y luego vortice de salida para `isak`). Falso
## si ya estaba activada.
func activate(isak: Isak) -> bool:
	if (_state != State.OFF and _state != State.PROMPT and _state != State.COUNTDOWN) or not is_powered():
		return false
	_state = State.OFFLINE if not offline_text.is_empty() else State.BOOT
	_time = 0.0
	_player = isak
	if _valid(_player):
		_player.begin_warp(false)
	_apply_visuals()
	activated.emit(resolved_level_id())
	if _state == State.OFFLINE:
		offline_shown.emit(offline_text)
	return true


## Avanza `delta` segundos de tiempo del mundo.
func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	match _state:
		State.OFF, State.PROMPT:
			var power: bool = is_powered()
			if power != _had_power:
				_had_power = power
				_apply_visuals()
				if power:
					powered.emit()
			if not power:
				return
			if is_automatic():
				if is_player_near():
					_start_countdown()
				else:
					_loop(ANIM_OFF)
				return
			_update_near_state()
			_loop(ANIM_PROMPT if _state == State.PROMPT else ANIM_OFF)
			_bob_key()
			return
		State.WARP, State.DONE:
			_loop(ANIM_ON)
			return
		State.COUNTDOWN:
			_loop(ANIM_PROMPT)
			_set_countdown_text()
			if _time >= countdown_s:
				activate(_player if _valid(_player) else _near)
			return
		State.OFFLINE:
			_loop(ANIM_PROMPT)
			if _time < offline_s:
				return
			_time -= offline_s
			_state = State.BOOT
			_apply_visuals()
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


func _start_countdown() -> void:
	_state = State.COUNTDOWN
	_time = 0.0
	_player = _near
	_apply_visuals()
	_set_countdown_text()
	countdown_started.emit(countdown_s)


## La placa de la tecla muestra los segundos que quedan («3», «2», «1»).
func _set_countdown_text() -> void:
	var text_now: String = str(maxi(ceili(countdown_s - _time - 0.0001), 1))
	if _key_label != null and _key_label.text != text_now:
		PulsePrompt.set_plate_text(_key_root, text_now, load(String(_config["font"])) as Font,
			int(_config.get("font_size", 12)), float(_config.get("key_padding_px", 3)))


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
	if requires_power and not _had_power:
		_state = State.OFF
		_show(ANIM_OFF)
		var c: Array = _config.get("unpowered_modulate", [0.45, 0.45, 0.6])
		_sprite.modulate = Color(float(c[0]), float(c[1]), float(c[2]))
		_key_root.visible = false
		return
	_sprite.modulate = Color.WHITE
	match _state:
		State.OFF:
			_show(ANIM_OFF)
		State.PROMPT, State.COUNTDOWN, State.OFFLINE:
			_show(ANIM_PROMPT)
		State.BOOT, State.TURN:
			_show(ANIM_BOOT)
		_:
			_show(ANIM_ON)
	_key_root.visible = _state == State.PROMPT or _state == State.COUNTDOWN
	if _offline_root != null:
		_offline_root.visible = _state == State.OFFLINE
		if _label_root != null:
			_label_root.visible = _state != State.OFFLINE


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
	_sprite.sprite_frames = load(get_frames_path()) as SpriteFrames
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
		_label_root = _plate("Label", text, font, String(_config["label_plate_color"]),
			String(_config["label_border_color"]), float(_config.get("label_padding_px", 3)), size.x,
			monitor_top - float(_config.get("label_gap_px", 44)))
	if not offline_text.is_empty():
		_offline_root = _plate("Offline", offline_text, font, String(_config["label_plate_color"]),
			String(_config.get("offline_border_color", _config["label_border_color"])),
			float(_config.get("label_padding_px", 3)), size.x, monitor_top - float(_config.get("label_gap_px", 44)))
		_offline_root.visible = false


## Placa con borde y texto (fuente de textos a font_scale), centrada en
## horizontal y con su borde inferior en `bottom` (px locales). PulsePrompt.
func _plate(node_name: String, label_text: String, font: Font, plate_color: String, border_color: String,
		pad: float, width: float, bottom: float) -> Node2D:
	return PulsePrompt.make_plate(self, node_name, label_text, font, int(_config.get("font_size", 12)),
		int(_config.get("font_scale", 2)), plate_color, border_color, pad, width, bottom)


## Vuelve a leer la tecla del pulso del Input Map (tras reasignar los controles).
func refresh_key() -> void:
	if _key_root == null or is_automatic():
		return
	PulsePrompt.set_plate_text(_key_root, _pulse_key_text(), load(String(_config["font"])) as Font, int(_config.get("font_size", 12)),
		float(_config.get("key_padding_px", 3)))


## Texto de la tecla que muestra el prompt (pruebas).
func get_key_text() -> String:
	return (_key_root.get_node(^"Text") as Label).text if _key_root != null else ""
