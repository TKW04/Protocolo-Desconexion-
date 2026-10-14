## Ajustes del cuadro de texto de Eco leidos de data/eco_text_box.json (aspecto,
## medidas en pixeles de arte, tiempos y rutas). Ver "_notes" del JSON.
class_name EcoTextBoxConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/eco_text_box.json"
## Color si falta en el JSON (magenta: se nota).
const MISSING_COLOR: Color = Color.MAGENTA
## Claves del JSON que no son numeros sueltos (se leen aparte).
const SPECIAL_KEYS: Array[String] = ["colors", "assets", "speaker_name", "font", "key_swap_shader"]

var layer: int = 11
## Pixeles de pantalla por pixel de arte (entero).
var pixel_scale: int = 2
var top_px: int = 22
## Ancho maximo del panel; el panel se ajusta al texto sin bajar de min_width_px.
var width_px: int = 280
var min_width_px: int = 160
var padding_px: int = 6
var icon_gap_px: int = 6
var panel_margin_px: int = 3
var font_size: int = 12
var chars_per_second: float = 40.0
var default_duration_s: float = 4.0
var hold_base_s: float = 1.5
var hold_per_char_s: float = 0.06
var fade_in_s: float = 0.12
var fade_out_s: float = 0.2
var speaker_name: String = "Eco"
var font_path: String = ""
var key_swap_shader_path: String = ""
var colors: Dictionary[StringName, Color] = {}
## Nombre -> {path, frame_size, columns, rows}.
var assets: Dictionary[StringName, Dictionary] = {}

static var _cached: EcoTextBoxConfig


## Config compartida (se lee una vez).
static func shared() -> EcoTextBoxConfig:
	if _cached == null:
		_cached = load_from_file()
		if _cached == null:
			_cached = EcoTextBoxConfig.new()
	return _cached


static func load_from_file(path: String = DEFAULT_PATH) -> EcoTextBoxConfig:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("EcoTextBoxConfig: no se pudo leer '%s'" % path)
		return null
	var config := EcoTextBoxConfig.new()
	var dict: Dictionary = data
	for key: String in dict:
		if key.begins_with("_") or key in SPECIAL_KEYS:
			continue
		if not key in config:
			push_error("EcoTextBoxConfig: clave desconocida '%s'" % key)
			continue
		var current: Variant = config.get(key)
		config.set(key, int(dict[key]) if current is int else float(dict[key]))
	config.speaker_name = dict.get("speaker_name", config.speaker_name)
	config.font_path = dict.get("font", "")
	config.key_swap_shader_path = dict.get("key_swap_shader", "")
	var raw_colors: Dictionary = dict.get("colors", {})
	for name: String in raw_colors:
		config.colors[StringName(name)] = Color.html(raw_colors[name])
	var raw_assets: Dictionary = dict.get("assets", {})
	for name: String in raw_assets:
		config.assets[StringName(name)] = raw_assets[name]
	return config


func color(name: StringName) -> Color:
	return colors.get(name, MISSING_COLOR)


func asset_texture(name: StringName) -> Texture2D:
	var info: Dictionary = assets.get(name, {})
	if info.is_empty():
		push_error("EcoTextBoxConfig: asset desconocido '%s'" % name)
		return null
	return load(info.path) as Texture2D


func asset_frame_size(name: StringName) -> Vector2i:
	var frame: Array = assets.get(name, {}).get("frame_size", [0, 0])
	return Vector2i(int(frame[0]), int(frame[1]))


func load_font() -> Font:
	return load(font_path) as Font


## Segundos que el texto completo queda en pantalla tras escribirse: al menos
## `duration_s` (o default_duration_s si es <= 0) y mas para textos largos.
func hold_time(char_count: int, duration_s: float = -1.0) -> float:
	var minimum: float = duration_s if duration_s > 0.0 else default_duration_s
	return maxf(minimum, hold_base_s + hold_per_char_s * char_count)


func new_key_swap_material(key: Color, target: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(key_swap_shader_path) as Shader
	material.set_shader_parameter(&"key_color", key)
	material.set_shader_parameter(&"target_color", target)
	return material
