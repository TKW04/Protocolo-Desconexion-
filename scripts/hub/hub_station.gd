## Estacion del hub (docs/propuesta-hub-y-guardado.md §3; paso 4 de §6.2),
## extraida del patron de la terminal de salida (ExitTerminal; piezas comunes en
## PulsePrompt). Valores en la seccion station de data/hub.json.
## 1. Apagada (OFF). Con Isak dentro de prompt_zone_px (1,5 tiles a cada lado)
##    pasa a PROMPT y sale encima la tecla del pulso (leida del Input Map).
## 2. Al recibir el PULSO (EventBus.pulse_fired: el circulo toca hit_rect_px)
##    se abre (OPEN): Isak se pone de espaldas mirando la estacion
##    (Isak.face_back: queda quieto y sin control), destello cian del visual y
##    se abre el panel (HubPanel; las subclases dan el suyo con _create_panel).
## 3. Al cerrar el panel (close(): Volver o salto) vuelve (RETURNING): durante
##    return_physics_frames pasos de fisica Isak sigue de espaldas, para que el
##    salto que cierra el panel no le haga saltar; luego face_side() le devuelve
##    el control y la estacion vuelve a OFF/PROMPT.
## No es solida (Area2D, mascara player). El origen es la esquina superior
## izquierda de su primera celda; se apoya en el suelo (height_tiles hacia abajo).
## VISUAL: nodo hijo "Visual", el arte PROVISIONAL (HubProvisionalArt, kind
## visual_kind) o, si la estacion trae `frames` (SpriteFrames con off, prompt y
## active), un AnimatedSprite2D: asi se integra el arte final sin tocar la logica.
class_name HubStation
extends Area2D

enum State { OFF, PROMPT, OPEN, RETURNING }

const GROUP: StringName = &"hub_station"
const VISUAL_OFF: StringName = &"off"
const VISUAL_PROMPT: StringName = &"prompt"
const VISUAL_ACTIVE: StringName = &"active"

## Se abrio el panel (Isak de espaldas).
signal opened(station: HubStation)
## Isak recupera el control tras cerrar el panel.
signal closed(station: HubStation)

@export var station_id: StringName = &""
## Etiqueta opcional encima de la estacion (vacio = sin etiqueta).
@export var text: String = ""
@export_range(1, 8) var width_tiles: int = 1
@export_range(1, 8) var height_tiles: int = 2
## Arte provisional (HubProvisionalArt.kind) y su icono.
@export var visual_kind: StringName = &"terminal"
@export var visual_icon: StringName = &""
## Arte final opcional: SpriteFrames con animaciones off / prompt / active.
@export_file("*.tres") var frames: String = ""
## Borde superior del arte en px (la tecla del pulso y la etiqueta salen
## encima); negativo = top_px de la seccion station, escalado con el tamano.
@export var prompt_top_px: float = -1.0

var _config: Dictionary = HubData.section("station")
var _state: State = State.OFF
var _time: float = 0.0
var _player: Isak
var _near: Isak
var _open_count: int = 0
var _return_frames_left: int = 0
var _flash_left: float = 0.0
var _visual: Node2D
var _key_root: Node2D
var _key_label: Label
var _key_base_y: float = 0.0
var _panel: HubPanel


func _ready() -> void:
	add_to_group(GROUP)
	_build()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.pulse_fired.connect(receive_pulse)
	_panel = _create_panel()
	_panel.name = "Panel"
	add_child(_panel)
	_panel.close_requested.connect(close)
	_apply_visuals()


func _process(delta: float) -> void:
	advance(delta)


func _physics_process(_delta: float) -> void:
	if _state != State.RETURNING:
		return
	_return_frames_left -= 1
	if _return_frames_left <= 0:
		_finish_return()


# --- Consultas ---

func get_state() -> State:
	return _state


func get_open_count() -> int:
	return _open_count


func is_player_near() -> bool:
	return _near != null and is_instance_valid(_near)


func is_key_hint_visible() -> bool:
	return _key_root.visible


func get_key_hint_text() -> String:
	return _key_label.text


func get_panel() -> HubPanel:
	return _panel


func is_panel_open() -> bool:
	return _panel != null and _panel.is_open()


## Nodo del arte (provisional o final).
func get_visual() -> Node2D:
	return _visual


## Estado mostrado por el arte: off, prompt o active.
func get_visual_state() -> StringName:
	match _state:
		State.PROMPT:
			return VISUAL_PROMPT
		State.OPEN:
			return VISUAL_ACTIVE
	return VISUAL_OFF


func is_flashing() -> bool:
	return _flash_left > 0.0


## Zona que el pulso debe tocar, en coordenadas globales.
func get_hit_rect() -> Rect2:
	var r: Array = _config.get("hit_rect_px", [0, 0, 64, 128])
	var s: Vector2 = _size_scale()
	return Rect2(global_position + Vector2(float(r[0]) * s.x, float(r[1]) * s.y),
		Vector2(float(r[2]) * s.x, float(r[3]) * s.y))


## Zona de cercania, en coordenadas locales.
func get_prompt_zone() -> Rect2:
	var r: Array = _config.get("prompt_zone_px", [-96, 0, 256, 128])
	var extra: Vector2 = get_size() - Vector2(64.0, 128.0)
	return Rect2(float(r[0]), float(r[1]), float(r[2]) + extra.x, float(r[3]) + extra.y)


## Tamano en px (width_tiles x height_tiles).
func get_size() -> Vector2:
	var t: float = HubData.tile_size()
	return Vector2(width_tiles * t, height_tiles * t)


# --- Acciones ---

## Comprueba si el pulso (`area`, con un CircleShape2D) alcanza la estacion y,
## si es asi, la abre. Verdadero si se ha abierto ahora.
func receive_pulse(area: Area2D) -> bool:
	if _state != State.OFF and _state != State.PROMPT:
		return false
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	return open(isak if isak != null else _near)


## Abre el panel con `isak` de espaldas. Falso si ya estaba abierta o volviendo.
func open(isak: Isak) -> bool:
	if _state != State.OFF and _state != State.PROMPT:
		return false
	_state = State.OPEN
	_time = 0.0
	_open_count += 1
	_player = isak
	if _valid(_player):
		_player.face_back()
	_flash_left = float(_config.get("open_flash_s", 0.12))
	_apply_visuals()
	_panel.open()
	_on_opened()
	opened.emit(self)
	return true


## Cierra el panel. Isak sigue de espaldas return_physics_frames pasos de
## fisica y luego recupera el control. `immediate`: lo devuelve ya (pruebas y
## herramientas). Falso si no estaba abierta.
func close(immediate: bool = false) -> bool:
	if _state != State.OPEN:
		return false
	_panel.close()
	_state = State.RETURNING
	_return_frames_left = maxi(1, int(_config.get("return_physics_frames", 2)))
	_apply_visuals()
	if immediate:
		_finish_return()
	return true


## Avanza `delta` segundos (prompt, bote de la tecla y destello).
func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_apply_flash()
	if _state == State.OFF or _state == State.PROMPT:
		_update_near_state()
		if _key_root.visible:
			_key_root.position.y = PulsePrompt.bob_y(_key_base_y, _time, float(_config.get("key_bob_s", 0.35)),
				float(_config.get("key_bob_px", 2)))


## Destello cian del visual (al abrir; la copia local tambien al guardar).
func flash(duration_s: float = -1.0) -> void:
	_flash_left = duration_s if duration_s >= 0.0 else float(_config.get("open_flash_s", 0.12))
	_apply_flash()


# --- Para las subclases ---

## Panel de la estacion. Por defecto un HubPanel con `text` como titulo y la
## opcion Volver.
func _create_panel() -> HubPanel:
	var panel := HubPanel.new()
	panel.ready.connect(func() -> void:
		panel.set_title(text)
		panel.set_options([{"id": &"back", "text": panel._text("option_back", "Volver")}])
		panel.option_chosen.connect(func(_i: int, _id: StringName) -> void: close()))
	return panel


func _on_opened() -> void:
	pass


# --- Interno ---

func _finish_return() -> void:
	if _state != State.RETURNING:
		return
	if _valid(_player):
		_player.face_side()
	_player = null
	_state = State.OFF
	_update_near_state()
	_apply_visuals()
	closed.emit(self)


func _update_near_state() -> void:
	var target: State = State.PROMPT if is_player_near() else State.OFF
	if target != _state:
		_state = target
		_time = 0.0
		_apply_visuals()


func _apply_visuals() -> void:
	_key_root.visible = _state == State.PROMPT
	_show_visual_state(get_visual_state())
	_apply_flash()


func _show_visual_state(value: StringName) -> void:
	if _visual is HubProvisionalArt:
		(_visual as HubProvisionalArt).show_state(value)
	elif _visual is AnimatedSprite2D:
		var sprite := _visual as AnimatedSprite2D
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(value):
			sprite.play(value)


func _apply_flash() -> void:
	if _visual == null:
		return
	var color := Color.WHITE
	if _flash_left > 0.0:
		var c: Array = _config.get("flash_modulate", [1, 1, 1])
		color = Color(float(c[0]), float(c[1]), float(c[2]))
	_visual.modulate = color


func _size_scale() -> Vector2:
	return get_size() / Vector2(64.0, 128.0)


func _valid(isak: Isak) -> bool:
	return isak != null and is_instance_valid(isak)


func _on_body_entered(body: Node2D) -> void:
	var isak := body as Isak
	if isak != null:
		_near = isak


func _on_body_exited(body: Node2D) -> void:
	if body == _near:
		_near = null


func _build() -> void:
	var size: Vector2 = get_size()
	var zone: Rect2 = get_prompt_zone()
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = zone.size
	shape.shape = box
	shape.position = zone.get_center()
	add_child(shape)
	_visual = _build_visual(size)
	_visual.name = "Visual"
	add_child(_visual)
	var font: Font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var font_size: int = int(_config.get("font_size", 12))
	var font_scale: int = int(_config.get("font_scale", 2))
	var top: float = prompt_top_px if prompt_top_px >= 0.0 else float(_config.get("top_px", 30)) * _size_scale().y
	_key_root = PulsePrompt.make_plate(self, "KeyHint",
		PulsePrompt.key_text(StringName(String(_config.get("pulse_action", "pulse")))), font, font_size, font_scale,
		_hex("key_plate_color", "fondo_profundo"), _hex("key_border_color", "acento_cian"),
		float(_config.get("key_padding_px", 3)), size.x, top - float(_config.get("key_gap_px", 8)))
	_key_label = _key_root.get_node(^"Text") as Label
	_key_base_y = _key_root.position.y
	if not text.is_empty():
		PulsePrompt.make_plate(self, "Label", text, font, font_size, font_scale,
			_hex("label_plate_color", "fondo_profundo"), _hex("label_border_color", "borde"),
			float(_config.get("label_padding_px", 3)), size.x, top - float(_config.get("label_gap_px", 44)))


## Arte final si `frames` existe; si no, el provisional.
func _build_visual(size: Vector2) -> Node2D:
	if not frames.is_empty() and ResourceLoader.exists(frames):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = load(frames) as SpriteFrames
		sprite.centered = false
		var tex: Texture2D = sprite.sprite_frames.get_frame_texture(VISUAL_OFF, 0) \
			if sprite.sprite_frames.has_animation(VISUAL_OFF) else null
		if tex != null:
			sprite.scale = size / tex.get_size()
		return sprite
	var art := HubProvisionalArt.new()
	art.kind = visual_kind
	art.icon = visual_icon
	art.size = size
	return art


## Hex del rol de la paleta del hub nombrado en `key` de la seccion station.
func _hex(key: String, fallback_role: String) -> String:
	return "#" + HubData.color(String(_config.get(key, fallback_role))).to_html(false)
