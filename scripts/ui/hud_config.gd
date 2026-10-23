## Ajustes del HUD leidos de data/hud.json. Es el unico sitio donde vive el
## aspecto del HUD (pixel base, medidas, tramos, colores, tiempos y rutas de
## los assets de assets/sprites/ui/).
## Las medidas *_px son pixeles de arte: el HUD se escala x hud_pixel_scale.
## GameState tambien lo lee para el umbral de Sync Rate bajo.
class_name HudConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/hud.json"
## Color si un mundo no tiene color de Debug en el JSON (magenta: se nota).
const MISSING_COLOR: Color = Color.MAGENTA
## Los tramos estan en % (0-100).
const PERCENT: float = 100.0
## Claves del JSON que no son numeros sueltos (se leen aparte).
const SPECIAL_KEYS: Array[String] = ["colors", "debug_colors", "assets", "signal_thresholds",
	"battery_thresholds", "font", "font_glyphs", "key_swap_shader", "lives", "hide", "boss_bar", "clock"]

var low_sync_threshold: float = 20.0
## Pixeles de pantalla por pixel de arte (entero).
var hud_pixel_scale: int = 2
var bar_height_px: int = 16
var panel_border_px: int = 2
var margin_px: int = 8
var spacing_px: int = 5
var font_size: int = 8
var charge_ring_steps: int = 16
var drain_delay_s: float = 0.35
var drain_duration_s: float = 0.4
var gain_pulse_scale: float = 1.25
var gain_pulse_duration_s: float = 0.18
var low_sync_blink_hz: float = 3.0
var low_sync_blink_min_alpha: float = 0.25
## Tramos (en %): la barra/segmento i se enciende si el valor es MAYOR que el tramo i.
var signal_thresholds: Array[float] = [0.0, 25.0, 50.0, 75.0]
var battery_thresholds: Array[float] = [0.0, 20.0, 40.0, 60.0, 80.0]
var font_path: String = ""
var font_glyphs: String = ""
var key_swap_shader_path: String = ""
var colors: Dictionary[StringName, Color] = {}
var debug_colors: Dictionary[int, Color] = {}
## Nombre -> {path, frame_size, columns, rows}.
var assets: Dictionary[StringName, Dictionary] = {}
## HUD de vidas (seccion lives de data/hud.json; Hud).
var lives: Dictionary = {}
## Indicador del Ocultarte (seccion hide; tanda M2 de las mejoras de Calc).
var hide: Dictionary = {}
## Reloj del Mundo 2 (seccion clock; HudClock, paso 8 de docs/propuesta-mundo-2.md).
var clock: Dictionary = {}

static var _cached: HudConfig


## Config compartida (se lee una vez).
static func shared() -> HudConfig:
	if _cached == null:
		_cached = load_from_file()
		if _cached == null:
			_cached = HudConfig.new()
	return _cached


static func load_from_file(path: String = DEFAULT_PATH) -> HudConfig:
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("HudConfig: no se pudo leer '%s'" % path)
		return null
	var config := HudConfig.new()
	var dict: Dictionary = data
	for key: String in dict:
		if key.begins_with("_") or key in SPECIAL_KEYS:
			continue
		if not key in config:
			push_error("HudConfig: clave desconocida '%s'" % key)
			continue
		var current: Variant = config.get(key)
		config.set(key, int(dict[key]) if current is int else float(dict[key]))
	config.signal_thresholds = _floats(dict.get("signal_thresholds", []))
	config.battery_thresholds = _floats(dict.get("battery_thresholds", []))
	config.font_path = dict.get("font", "")
	config.font_glyphs = dict.get("font_glyphs", "")
	config.key_swap_shader_path = dict.get("key_swap_shader", "")
	var raw_colors: Dictionary = dict.get("colors", {})
	for name: String in raw_colors:
		config.colors[StringName(name)] = Color.html(raw_colors[name])
	var raw_debug: Dictionary = dict.get("debug_colors", {})
	for world: String in raw_debug:
		config.debug_colors[int(world)] = Color.html(raw_debug[world])
	var raw_lives: Variant = dict.get("lives", {})
	config.lives = raw_lives if raw_lives is Dictionary else {}
	var raw_hide: Variant = dict.get("hide", {})
	config.hide = raw_hide if raw_hide is Dictionary else {}
	var raw_clock: Variant = dict.get("clock", {})
	config.clock = raw_clock if raw_clock is Dictionary else {}
	var raw_assets: Dictionary = dict.get("assets", {})
	for name: String in raw_assets:
		config.assets[StringName(name)] = raw_assets[name]
	return config


static func _floats(raw: Array) -> Array[float]:
	var out: Array[float] = []
	for v: Variant in raw:
		out.append(float(v))
	return out


## Cuantas partes (barras o segmentos) se encienden con `ratio` (0-1).
static func lit_count(ratio: float, thresholds: Array[float]) -> int:
	var percent: float = ratio * PERCENT
	var count: int = 0
	for t: float in thresholds:
		if percent > t:
			count += 1
	return count


func color(name: StringName) -> Color:
	return colors.get(name, MISSING_COLOR)


func debug_color_for_world(world: int) -> Color:
	return debug_colors.get(world, MISSING_COLOR)


func asset_texture(name: StringName) -> Texture2D:
	var info: Dictionary = assets.get(name, {})
	if info.is_empty():
		push_error("HudConfig: asset desconocido '%s'" % name)
		return null
	return load(info.path) as Texture2D


func asset_frame_size(name: StringName) -> Vector2i:
	var frame: Array = assets.get(name, {}).get("frame_size", [0, 0])
	return Vector2i(int(frame[0]), int(frame[1]))


func asset_columns(name: StringName) -> int:
	return int(assets.get(name, {}).get("columns", 0))


func load_font() -> Font:
	return load(font_path) as Font


func new_key_swap_material(key: Color, target: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(key_swap_shader_path) as Shader
	material.set_shader_parameter(&"key_color", key)
	material.set_shader_parameter(&"target_color", target)
	return material
