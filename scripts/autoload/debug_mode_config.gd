## Ajustes del Debug Mode leidos de data/debug_mode.json (activacion, consumo, escala de
## tiempo del mundo, transiciones, tinte, vineta y plataformas ocultas).
## La logica (DebugMode, DebugOverlay, HiddenPlatform) no tiene numeros sueltos.
class_name DebugModeConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/debug_mode.json"

## Segundos (reales) de pulsacion larga para activar el Debug.
var activation_hold_s: float = 1.0
var world_time_scale: float = 0.5
var drain_per_second: float = 20.0
var fade_in_s: float = 0.15
var fade_out_s: float = 0.25
var tint_strength: float = 0.25
var vignette_size: float = 0.15
var vignette_strength: float = 0.4
var vignette_steps: int = 3
var vignette_shade: float = 0.45
var tint_gain: float = 1.3
var hidden_outline_width_px: int = 2
var hidden_fill_alpha: float = 0.25
## Halo oscuro por fuera del contorno de las plataformas ocultas (0 = sin halo).
var hidden_halo_width_px: int = 2
var hidden_halo_color: Color = Color("#0b0e1a")
var high_contrast_outline_width_px: int = 4
var high_contrast_lighten: float = 0.6
var hidden_platforms_solid_only_in_debug: bool = true
## Revelado persistente (Debug 3, tanda M2): segundos reales que lo revelado sigue
## visible y solido tras apagar el Debug (0 de base), aviso final y su parpadeo.
var reveal_linger_s: float = 0.0
var reveal_linger_warn_s: float = 0.5
var reveal_linger_blink_hz: float = 8.0

static var _cached: DebugModeConfig


## Config compartida (se lee una vez).
static func shared() -> DebugModeConfig:
	if _cached == null:
		_cached = load_from_file()
		if _cached == null:
			_cached = DebugModeConfig.new()
	return _cached


static func load_from_file(path: String = DEFAULT_PATH) -> DebugModeConfig:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("DebugModeConfig: no se pudo leer '%s'" % path)
		return null
	var config := DebugModeConfig.new()
	var dict: Dictionary = data
	for key: String in dict:
		if key.begins_with("_"):
			continue
		if not key in config:
			push_error("DebugModeConfig: clave desconocida '%s'" % key)
			continue
		var current: Variant = config.get(key)
		if current is bool:
			config.set(key, bool(dict[key]))
		elif current is Color:
			config.set(key, Color.html(String(dict[key])))
		elif current is int:
			config.set(key, int(dict[key]))
		else:
			config.set(key, float(dict[key]))
	return config
