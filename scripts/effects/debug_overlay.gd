## Efecto de pantalla del Debug Mode (docs 15.6, A14): tinte del color del
## Debug del mundo actual y vineta, con transicion suave. Vive en un
## CanvasLayer propio por encima del mundo y por debajo del HUD (Hud.layer),
## asi que el HUD no se tine. Lo crea y lo alimenta el autoload DebugMode con
## set_intensity(); el color lo toma de data/hud.json (debug_colors) segun
## EventBus.world_changed. Valores en data/debug_mode.json.
class_name DebugOverlay
extends CanvasLayer

## Capa: por encima del mundo (0) y por debajo del HUD (10, scenes/ui/hud.tscn).
const OVERLAY_LAYER: int = 5

var _config: DebugModeConfig = DebugModeConfig.shared()
var _world: int = GameState.FIRST_WORLD
var _intensity: float = 0.0

@onready var _rect: ColorRect = $Effect
@onready var _material: ShaderMaterial = _rect.material as ShaderMaterial


func _ready() -> void:
	layer = OVERLAY_LAYER
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.set_shader_parameter(&"tint_strength", _config.tint_strength)
	_material.set_shader_parameter(&"vignette_size", _config.vignette_size)
	_material.set_shader_parameter(&"vignette_strength", _config.vignette_strength)
	_material.set_shader_parameter(&"vignette_steps", float(_config.vignette_steps))
	_material.set_shader_parameter(&"vignette_shade", _config.vignette_shade)
	_material.set_shader_parameter(&"tint_gain", _config.tint_gain)
	EventBus.world_changed.connect(_on_world_changed)
	_on_world_changed(GameState.current_world)
	set_intensity(_intensity)


## 0 = oculto (no cuesta nada dibujarlo), 1 = efecto completo.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _rect == null:
		return
	_rect.visible = _intensity > 0.0
	_material.set_shader_parameter(&"intensity", _intensity)


func get_intensity() -> float:
	return _intensity


func is_effect_visible() -> bool:
	return _rect.visible


func get_tint_color() -> Color:
	return HudConfig.shared().debug_color_for_world(_world)


func _on_world_changed(world: int) -> void:
	_world = world
	_material.set_shader_parameter(&"tint_color", get_tint_color())
