## Pantalla PROVISIONAL de regreso al hub (C4: "al terminar un nivel se vuelve
## al hub"; el hub no existe en el vertical slice). No es el hub y no inventa su
## contenido: muestra solo
##   «Regreso al hub (provisional)»
##   «Nivel completado: <nombre del nivel>»
##   «Puntos de atención: <n>»
##   «Pulsa salto para volver a jugar»
## con la fuente de textos y colores de la paleta del Mundo 1. Todo sale de
## data/hub_placeholder.json.
##
## Uso: show_result(level_id, attention_points). El flujo de nivel (paso 16) la
## cargara con EventBus.level_completed. Con la accion restart_action (jump),
## pasado input_delay_s (tiempo real), emite restart_requested(level_id) y, si
## restart_scene_path existe, cambia a esa escena.
class_name HubPlaceholder
extends CanvasLayer

const DATA_PATH: String = "res://data/hub_placeholder.json"
const LINE_KEYS: Array[StringName] = [&"title", &"completed", &"points", &"help"]

## El jugador pide volver a jugar el nivel.
signal restart_requested(level_id: String)

## Escena a la que ir al reiniciar (vacio: solo se emite restart_requested).
@export_file("*.tscn") var restart_scene_path: String = ""

var _data: Dictionary = {}
var _font: Font
var _level_id: String = ""
var _attention_points: int = 0
var _shown_time: float = 0.0
var _restart_count: int = 0
var _frame: Control
var _background: ColorRect
var _panel: NinePatchRect
var _labels: Dictionary[StringName, Label] = {}


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	layer = int(_data.get("layer", 20))
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_shown_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(StringName(_data.get("restart_action", "jump"))):
		if request_restart():
			get_viewport().set_input_as_handled()


# --- API ---

## Muestra el resultado del nivel `level_id` con `attention_points` puntos.
func show_result(level_id: String, attention_points: int) -> void:
	_level_id = level_id
	_attention_points = attention_points
	_shown_time = 0.0
	var texts: Dictionary = _data.get("texts", {})
	_labels[&"title"].text = String(texts.get("title", ""))
	_labels[&"completed"].text = String(texts.get("completed", "%s")) % level_name(level_id)
	_labels[&"points"].text = String(texts.get("points", "%d")) % attention_points
	_labels[&"help"].text = String(texts.get("help", ""))
	visible = true
	_layout()


## Pide reiniciar el nivel. Falso si aun no ha pasado input_delay_s.
func request_restart() -> bool:
	if _shown_time < float(_data.get("input_delay_s", 0.5)):
		return false
	_restart_count += 1
	restart_requested.emit(_level_id)
	if not restart_scene_path.is_empty() and ResourceLoader.exists(restart_scene_path):
		get_tree().change_scene_to_file.call_deferred(restart_scene_path)
	return true


## Nombre del nivel (campo name de data/levels/<id>.json) o el id si no hay.
func level_name(level_id: String) -> String:
	var path: String = String(_data.get("level_data_dir", "res://data/levels/")) + level_id + ".json"
	if not FileAccess.file_exists(path):
		return level_id
	var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if level is Dictionary:
		return String(level.get("name", level_id))
	return level_id


func get_line_text(key: StringName) -> String:
	return _labels[key].text


func get_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for key: StringName in LINE_KEYS:
		out.append(_labels[key].text)
	return out


func get_font() -> Font:
	return _font


func get_level_id() -> String:
	return _level_id


func get_restart_count() -> int:
	return _restart_count


## Para pruebas: da por pasado el retardo de entrada.
func skip_input_delay() -> void:
	_shown_time = float(_data.get("input_delay_s", 0.5))


# --- Interno ---

func _build() -> void:
	var scale_factor: int = maxi(1, int(_data.get("pixel_scale", 2)))
	var font_size: int = int(_data.get("font_size", 12))
	var colors: Dictionary = _data.get("colors", {})
	_font = load(String(_data["font"])) as Font
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.scale = Vector2.ONE * scale_factor
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color.html(String(colors.get("background", "#0b0e1a")))
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_background)
	_panel = NinePatchRect.new()
	_panel.name = "Panel"
	_panel.texture = load(String(_data["panel"])) as Texture2D
	var margin: int = int(_data.get("panel_margin_px", 3))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, margin)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_panel)
	var shader := load(String(_data["key_swap_shader"])) as Shader
	var key := Color.html(String(colors.get("key", "#f2f4f8")))
	for name: StringName in LINE_KEYS:
		var label := Label.new()
		label.name = String(name).capitalize()
		label.add_theme_font_override(&"font", _font)
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", Color.WHITE)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"key_color", key)
		material.set_shader_parameter(&"target_color", Color.html(String(colors.get(String(name), "#f2f4f8"))))
		label.material = material
		_panel.add_child(label)
		_labels[name] = label


func _layout() -> void:
	if _frame == null:
		return
	var scale_factor: float = _frame.scale.x
	var screen: Vector2 = get_viewport().get_visible_rect().size / scale_factor
	_frame.size = screen
	_background.size = screen
	var font_size: int = int(_data.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(font_size))
	var pad: float = float(_data.get("padding_px", 12))
	var gap: float = float(_data.get("line_gap_px", 8))
	var width: float = float(_data.get("panel_width_px", 280))
	for label: Label in _labels.values():
		width = maxf(width, ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + pad * 2.0)
	var height: float = pad * 2.0 + line_h * LINE_KEYS.size() + gap * (LINE_KEYS.size() - 1) + gap
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf((screen.y - height) * 0.5))
	var y: float = pad
	for i: int in LINE_KEYS.size():
		var label: Label = _labels[LINE_KEYS[i]]
		label.position = Vector2(pad, y)
		label.size = Vector2(width - pad * 2.0, line_h)
		y += line_h + gap
		if i == 0:
			y += gap  # aire extra bajo el titulo
