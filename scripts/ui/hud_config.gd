## Ajustes del HUD leidos de data/hud.json. Es el unico sitio donde vive el
## aspecto del HUD (colores, tamanos, tiempos): para cambiar el arte en el
## paso 12 basta con tocar el JSON (o sustituir este recurso).
## GameState tambien lo lee para el umbral de Sync Rate bajo.
class_name HudConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/hud.json"
## Color si un mundo no tiene color de Debug en el JSON (magenta: se nota).
const MISSING_COLOR: Color = Color.MAGENTA

var low_sync_threshold: float = 20.0
var bar_height_px: int = 32
var margin_px: int = 16
var spacing_px: int = 12
var font_size: int = 20
var signal_bar_count: int = 4
var signal_bar_width_px: int = 6
var signal_bar_gap_px: int = 3
var signal_bar_min_height_px: int = 6
var signal_bar_max_height_px: int = 20
var battery_segments: int = 5
var battery_width_px: int = 52
var battery_height_px: int = 20
var battery_border_px: int = 2
var battery_tip_width_px: int = 4
var battery_tip_height_px: int = 8
var battery_segment_gap_px: int = 2
var attention_icon_size_px: int = 16
var drain_delay_s: float = 0.35
var drain_duration_s: float = 0.4
var gain_pulse_scale: float = 1.25
var gain_pulse_duration_s: float = 0.18
var low_sync_blink_hz: float = 3.0
var low_sync_blink_min_alpha: float = 0.25
var colors: Dictionary[StringName, Color] = {}
var debug_colors: Dictionary[int, Color] = {}

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
		if key.begins_with("_") or key == "colors" or key == "debug_colors":
			continue
		if not key in config:
			push_error("HudConfig: clave desconocida '%s'" % key)
			continue
		var current: Variant = config.get(key)
		config.set(key, int(dict[key]) if current is int else float(dict[key]))
	var raw_colors: Dictionary = dict.get("colors", {})
	for name: String in raw_colors:
		config.colors[StringName(name)] = Color.html(raw_colors[name])
	var raw_debug: Dictionary = dict.get("debug_colors", {})
	for world: String in raw_debug:
		config.debug_colors[int(world)] = Color.html(raw_debug[world])
	return config


func color(name: StringName) -> Color:
	return colors.get(name, MISSING_COLOR)


func debug_color_for_world(world: int) -> Color:
	return debug_colors.get(world, MISSING_COLOR)
