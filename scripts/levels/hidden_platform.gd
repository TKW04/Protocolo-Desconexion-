## Plataforma oculta (tipo `h` del level-builder; grupo "hidden_platform"):
## un "error del sistema" que Isak solo ve con el Debug Mode (docs 3.2, 15.6).
##
## PROPUESTA (docs/preguntas.md, notas del paso 9): solo es visible Y solida
## mientras el Debug esta activo. Al activarse aparece con contorno del color
## del Debug del mundo; al apagarse desaparece y, si Isak estaba encima, cae.
## Alternativa (una constante en data/debug_mode.json,
## hidden_platforms_solid_only_in_debug = false): siempre solida, solo visible
## con el Debug.
##
## La colision cambia al instante con EventBus.debug_mode_changed; el dibujo
## sigue la transicion (DebugMode.get_intensity()). Accesibilidad:
## GameState.debug_high_contrast_outline usa un contorno mas claro y grueso.
## Halo oscuro (hidden_halo_*) por fuera del contorno para que no se pierda.
## Revelado persistente (Debug 3, tanda M2 de las mejoras de Calc): tras apagar
## el Debug sigue visible y solida DebugMode.get_reveal_linger_s() (1,5 s) y
## parpadea en sus ultimos reveal_linger_warn_s (EventBus.debug_reveal_changed,
## DebugMode.get_reveal_intensity). Sin la mejora, igual que antes.
class_name HiddenPlatform
extends StaticBody2D

const GROUP: StringName = &"hidden_platform"
## Tamano de un tile (64 px): por defecto la plataforma ocupa un tile `h`.
const TILE_SIZE_PX: float = 64.0

## Tamano en px; el origen es el centro (como un StaticBody2D con un rectangulo).
@export var size: Vector2 = Vector2(TILE_SIZE_PX, TILE_SIZE_PX)
## Plataforma de una via (se atraviesa desde abajo).
@export var one_way: bool = false

var _config: DebugModeConfig = DebugModeConfig.shared()
var _shape: CollisionShape2D
var _drawn_intensity: float = -1.0
var _drawn_blink_off: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.one_way_collision = one_way
	add_child(_shape)
	EventBus.debug_reveal_changed.connect(_on_debug_reveal_changed)
	EventBus.world_changed.connect(_on_look_changed.unbind(1))
	EventBus.debug_high_contrast_outline_changed.connect(_on_look_changed.unbind(1))
	_update_solid(DebugMode.is_revealing())
	_update_visual()


func _process(_delta: float) -> void:
	if DebugMode.get_reveal_intensity() != _drawn_intensity or DebugMode.is_reveal_blink_off() != _drawn_blink_off:
		_update_visual()


## Verdadero si Isak puede pisarla ahora.
func is_solid() -> bool:
	return not _shape.disabled


## Verdadero si se dibuja algo (con el Debug activo o en su transicion).
func is_shown() -> bool:
	return visible and _drawn_intensity > 0.0


func get_outline_color() -> Color:
	var color: Color = HudConfig.shared().debug_color_for_world(GameState.current_world)
	if GameState.debug_high_contrast_outline:
		color = color.lerp(Color.WHITE, _config.high_contrast_lighten)
	return color


func get_outline_width() -> int:
	if GameState.debug_high_contrast_outline:
		return _config.high_contrast_outline_width_px
	return _config.hidden_outline_width_px


func _draw() -> void:
	if _drawn_intensity <= 0.0 or _drawn_blink_off:
		return
	var rect := Rect2(-size * 0.5, size)
	var color: Color = get_outline_color()
	draw_rect(rect, Color(color, _config.hidden_fill_alpha * _drawn_intensity))
	# Halo oscuro por fuera: separa el contorno de los azules del fondo.
	var halo: float = _config.hidden_halo_width_px
	if halo > 0.0:
		draw_rect(rect.grow(halo * 0.5), Color(_config.hidden_halo_color, _drawn_intensity), false, halo)
	var width: float = get_outline_width()
	# Contorno por dentro del rectangulo, con ancho en px enteros.
	draw_rect(rect.grow(-width * 0.5), Color(color, _drawn_intensity), false, width)


func _update_solid(revealing: bool) -> void:
	var solid: bool = revealing or not _config.hidden_platforms_solid_only_in_debug
	_shape.disabled = not solid


func _update_visual() -> void:
	_drawn_intensity = DebugMode.get_reveal_intensity()
	_drawn_blink_off = DebugMode.is_reveal_blink_off()
	visible = _drawn_intensity > 0.0
	queue_redraw()


## Debug activo o persistencia del revelado (Debug 3): visible y solida.
func _on_debug_reveal_changed(revealing: bool) -> void:
	_update_solid(revealing)
	_update_visual()


func _on_look_changed() -> void:
	queue_redraw()
