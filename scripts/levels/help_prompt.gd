## Icono «Q» de la ayuda de Eco (docs/propuesta-asistentes-y-vidas.md §3.4):
## placa de tecla con el mismo estilo que la tecla del pulso (PulsePrompt:
## placa, borde de 1 px, fuente de textos a font_scale y bote), con la tecla de
## la accion help leida del Input Map. Se apoya con su borde inferior centrado
## en la posicion del nodo. Aspecto en la seccion prompt de data/help.json.
## Solo dibujo: cuando sale y sobre que objeto lo decide HelpSystem.
class_name HelpPrompt
extends Node2D

const PLATE_NAME: String = "KeyHint"

var _config: Dictionary = {}
var _plate: Node2D
var _label: Label
var _base_y: float = 0.0
var _time: float = 0.0


func _init() -> void:
	_config = HelpCatalog.shared().prompt_config()
	var action: StringName = HelpCatalog.shared().action()
	name = "HelpPrompt"
	var font: Font = load(String(_config.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_plate = PulsePrompt.make_plate(self, PLATE_NAME,
		PulsePrompt.key_text(action, String(_config.get("fallback_key", "Q"))), font,
		int(_config.get("font_size", 12)), int(_config.get("font_scale", 2)),
		String(_config.get("key_plate_color", "#0b0e1a")), String(_config.get("key_border_color", "#f2f4f8")),
		float(_config.get("padding_px", 3)), 0.0, 0.0)
	_label = _plate.get_node(^"Text") as Label
	_base_y = _plate.position.y


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_plate.position.y = PulsePrompt.bob_y(_base_y, _time, float(_config.get("key_bob_s", 0.35)),
		float(_config.get("key_bob_px", 2)))


## Texto de la tecla que se muestra (p. ej. "Q").
func get_key_text() -> String:
	return _label.text


## Rectangulo de la placa en coordenadas globales (pruebas y capturas).
func get_plate_global_rect() -> Rect2:
	var size: Vector2 = (_label.size + Vector2.ONE * float(_config.get("padding_px", 3)) * 2.0) * _plate.scale
	return Rect2(to_global(_plate.position), size)
