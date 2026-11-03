## Mini animacion de un aviso de habilidad (2026-11-03, peticion del usuario:
## «una pequena animacion dentro del mensaje que muestre como se ve al usarla»).
## Ventanita del cuadro de Eco (marca {demo:<id>}, demos de
## data/ability_notices.json) con Isak a media escala (las hojas de
## scenes/player/isak_frames.tres: con el cuadro a x2 se ven a 1:1) que repite
## en bucle los pasos de la demo: animacion, desplazamiento, accion pulsada
## (su tecla del texto se ve pulsada: get_pressed_action) y un efecto por codigo
## (bolt, ring, wave, trail, debug, hide). Sin fisica ni nodos del juego: los
## cuadros se eligen a mano con el tiempo (advance, tiempo real; lo llama el
## cuadro de Eco, que procesa con el juego en pausa).
class_name AbilityDemo
extends Control

const FRAMES_PATH: String = "res://scenes/player/isak_frames.tres"
## Isak a media escala: el cuadro de Eco esta a x2, asi que se ve a 1:1.
const ISAK_SCALE: float = 0.5
## Pies de Isak respecto al centro del lienzo de 128 x 128 (como scenes/player/isak.tscn).
const ISAK_OFFSET: Vector2 = Vector2(0, -64)
## Alto (px de arte de la ventana) de Isak a media escala: 96 px visibles / 2.
const ISAK_HEIGHT_PX: float = 48.0
const FLOOR_MARGIN_PX: float = 5.0

var _steps: Array[Dictionary] = []
var _cycle_s: float = 0.0
var _time: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _colors: Dictionary = {}
var _id: StringName = &""
var _sprite: AnimatedSprite2D
var _frames: SpriteFrames
var _step_index: int = 0
var _step_t: float = 0.0


## Prepara la demo `id` con su definicion (demos de data/ability_notices.json) y
## los colores {bg, border, floor, fx} del cuadro.
func setup(id: StringName, def: Dictionary, colors: Dictionary, size_px: Vector2) -> void:
	_id = id
	_colors = colors
	size = size_px
	custom_minimum_size = size_px
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steps.clear()
	_cycle_s = 0.0
	for raw: Variant in def.get("steps", []):
		if raw is Dictionary and float((raw as Dictionary).get("time_s", 0.0)) > 0.0:
			_steps.append(raw)
			_cycle_s += float((raw as Dictionary)["time_s"])
	_start = Vector2(float(def.get("start_x", size_px.x * 0.5)), float(def.get("start_y", 0.0)))
	if _sprite == null:
		_frames = load(FRAMES_PATH) as SpriteFrames
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Isak"
		_sprite.sprite_frames = _frames
		_sprite.offset = ISAK_OFFSET
		_sprite.scale = Vector2.ONE * ISAK_SCALE
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_time = 0.0
	advance(0.0)


func get_demo_id() -> StringName:
	return _id


func get_step_count() -> int:
	return _steps.size()


func get_step_index() -> int:
	return _step_index


## Animacion de Isak que se ve ahora.
func get_current_anim() -> StringName:
	return _sprite.animation if _sprite != null else &""


func get_current_frame() -> int:
	return _sprite.frame if _sprite != null else 0


## Pies de Isak en la ventana (px de arte).
func get_isak_position() -> Vector2:
	return _sprite.position if _sprite != null else Vector2.ZERO


## Accion que la demo esta pulsando ahora (&"" si ninguna).
func get_pressed_action() -> StringName:
	if _steps.is_empty():
		return &""
	return StringName(String(_steps[_step_index].get("press", "")))


## Efecto del paso actual ("" si ninguno).
func get_current_fx() -> String:
	return String(_steps[_step_index].get("fx", "")) if not _steps.is_empty() else ""


func get_cycle_s() -> float:
	return _cycle_s


## Avanza `delta` segundos de tiempo real (bucle).
func advance(delta: float) -> void:
	if _steps.is_empty() or _sprite == null:
		return
	_time = fmod(_time + delta, _cycle_s)
	var t: float = _time
	var pos: Vector2 = _start
	_step_index = 0
	for i: int in _steps.size():
		var step: Dictionary = _steps[i]
		var dur: float = float(step["time_s"])
		var move := Vector2(float(step.get("dx_px", 0.0)), float(step.get("dy_px", 0.0)))
		if t < dur or i == _steps.size() - 1:
			_step_index = i
			_step_t = minf(t, dur)
			pos += move * (_step_t / dur)
			break
		t -= dur
		pos += move
	var step: Dictionary = _steps[_step_index]
	var anim := StringName(String(step.get("anim", "idle")))
	if not _frames.has_animation(anim):
		anim = &"idle"
	if _sprite.animation != anim:
		_sprite.animation = anim
	var count: int = _frames.get_frame_count(anim)
	var n: int = floori(_step_t * _frames.get_animation_speed(anim))
	_sprite.frame = (n % count) if _frames.get_animation_loop(anim) else mini(n, count - 1)
	_sprite.position = Vector2(roundf(pos.x), roundf(_floor_y() - pos.y))
	var fx: String = get_current_fx()
	var tint: Color = Color.WHITE
	if fx == "debug":
		tint = Color(1, 1, 1, 1).lerp(_color("fx"), 0.35 + 0.15 * sin(_step_t * TAU * 2.0))
	elif fx == "hide":
		tint = Color(_color("fx"), 0.45)
	_sprite.modulate = tint
	queue_redraw()


func _floor_y() -> float:
	return size.y - FLOOR_MARGIN_PX


func _color(key: String) -> Color:
	return _colors.get(key, Color.WHITE)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, _color("bg"))
	var floor_y: float = _floor_y()
	draw_rect(Rect2(2, floor_y, size.x - 4, 1), _color("floor"))
	if not _steps.is_empty():
		_draw_fx(get_current_fx(), _step_t / float(_steps[_step_index]["time_s"]))
	draw_rect(rect.grow(-0.5), _color("border"), false, 1.0)


## Efectos por codigo, solo rectangulos de 1 px (pixel art).
func _draw_fx(fx: String, k: float) -> void:
	var fx_color: Color = _color("fx")
	var feet: Vector2 = _sprite.position
	var chest_y: float = roundf(feet.y - ISAK_HEIGHT_PX * 0.55)
	match fx:
		"bolt":
			var x: float = roundf(feet.x + 8 + k * (size.x - feet.x))
			draw_rect(Rect2(x, chest_y, 8, 2), fx_color)
		"ring":
			var r: float = roundf(6 + k * 20)
			draw_arc(Vector2(feet.x, chest_y), r, 0.0, TAU, 24, Color(fx_color, 1.0 - k * 0.6), 1.0)
		"wave":
			var w: float = roundf(4 + k * 24)
			var c := Color(fx_color, 1.0 - k * 0.5)
			draw_rect(Rect2(feet.x - w - 4, _floor_y() - 2, 4, 2), c)
			draw_rect(Rect2(feet.x + w, _floor_y() - 2, 4, 2), c)
		"trail":
			for i: int in 3:
				var tx: float = roundf(feet.x - 10 - i * 6)
				draw_rect(Rect2(tx, roundf(feet.y - ISAK_HEIGHT_PX * 0.8), 1, roundf(ISAK_HEIGHT_PX * 0.6)),
					Color(fx_color, 0.8 - i * 0.25))
		"debug":
			# La plataforma oculta que el Debug ensena: contorno discontinuo.
			var y: float = roundf(size.y * 0.35)
			var x0: float = roundf(size.x * 0.55)
			for i: int in 5:
				draw_rect(Rect2(x0 + i * 4, y, 2, 1), fx_color)
				draw_rect(Rect2(x0 + i * 4, y + 4, 2, 1), fx_color)
