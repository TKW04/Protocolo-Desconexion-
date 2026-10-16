## Icono «Q» de la ayuda de Eco (docs/propuesta-asistentes-y-vidas.md §3.4):
## placa de tecla con el mismo estilo que la tecla del pulso (PulsePrompt:
## placa, borde de 1 px, fuente de textos a font_scale y bote), con la tecla de
## la accion help leida del Input Map (se actualiza al reasignar los controles:
## EventBus.controls_changed). Se apoya con su borde inferior centrado en la
## posicion del nodo. Aspecto en la seccion prompt de data/help.json.
## Variante REREAD (relectura, 2026-10-16): Q pequena y apagada (reread.prompt:
## escala 1, sin bote, glifo tenido con el shader de color clave a text_color).
## Solo dibujo: cuando sale y sobre que objeto lo decide HelpSystem.
class_name HelpPrompt
extends Node2D

enum Style { NORMAL, REREAD }

const PLATE_NAME: String = "KeyHint"
const KEY_SWAP_SHADER: String = "res://assets/shaders/hud_key_swap.gdshader"

var style: Style = Style.NORMAL

var _config: Dictionary = {}
var _font: Font
var _plate: Node2D
var _label: Label
var _base_y: float = 0.0
var _time: float = 0.0


func _init(prompt_style: Style = Style.NORMAL) -> void:
	style = prompt_style
	var catalog: HelpCatalog = HelpCatalog.shared()
	_config = catalog.reread_prompt_config() if style == Style.REREAD else catalog.prompt_config()
	name = "RereadPrompt" if style == Style.REREAD else "HelpPrompt"
	_font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_plate = PulsePrompt.make_plate(self, PLATE_NAME, _key_text(), _font,
		int(_config.get("font_size", 12)), int(_config.get("font_scale", 2)),
		String(_config.get("key_plate_color", "#0b0e1a")), String(_config.get("key_border_color", "#f2f4f8")),
		float(_config.get("padding_px", 3)), 0.0, 0.0)
	_label = _plate.get_node(^"Text") as Label
	_base_y = _plate.position.y
	if _config.has("text_color"):
		var material := ShaderMaterial.new()
		material.shader = load(KEY_SWAP_SHADER) as Shader
		material.set_shader_parameter(&"key_color", Color.html(String(_config.get("key_color", "#f2f4f8"))))
		material.set_shader_parameter(&"target_color", Color.html(String(_config["text_color"])))
		_label.material = material


func _enter_tree() -> void:
	if not EventBus.controls_changed.is_connected(refresh_key):
		EventBus.controls_changed.connect(refresh_key)
	refresh_key()


func _exit_tree() -> void:
	if EventBus.controls_changed.is_connected(refresh_key):
		EventBus.controls_changed.disconnect(refresh_key)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_plate.position.y = PulsePrompt.bob_y(_base_y, _time, float(_config.get("key_bob_s", 0.35)),
		float(_config.get("key_bob_px", 2)))


## Vuelve a leer la tecla del Input Map (tras reasignar los controles).
func refresh_key() -> void:
	PulsePrompt.set_plate_text(_plate, _key_text(), _font, int(_config.get("font_size", 12)),
		float(_config.get("padding_px", 3)))


## Texto de la tecla que se muestra (p. ej. "Q").
func get_key_text() -> String:
	return _label.text


## Color del glifo (el de text_color en la variante apagada; blanco si no).
func get_text_color() -> Color:
	var material := _label.material as ShaderMaterial
	return material.get_shader_parameter(&"target_color") as Color if material != null else Color.WHITE


## Colores de la placa y del borde (pruebas).
func get_plate_colors() -> Dictionary:
	return {"border": (_plate.get_child(0) as ColorRect).color, "plate": (_plate.get_child(1) as ColorRect).color}


## Escala entera de la placa (2 la normal, 1 la apagada).
func get_plate_scale() -> int:
	return int(_plate.scale.x)


## Rectangulo de la placa en coordenadas globales (pruebas y capturas).
func get_plate_global_rect() -> Rect2:
	var size: Vector2 = (_label.size + Vector2.ONE * float(_config.get("padding_px", 3)) * 2.0) * _plate.scale
	return Rect2(to_global(_plate.position), size)


func _key_text() -> String:
	return PulsePrompt.key_text(HelpCatalog.shared().action(), String(_config.get("fallback_key", "Q")))
