## Prompt de "activar con el pulso" (2026-10-15): piezas comunes de la terminal
## de salida del nivel (ExitTerminal) y de las estaciones del hub (HubStation),
## extraidas de ExitTerminal sin cambiar su aspecto:
## - key_text: la primera tecla de la accion del pulso en el Input Map ("G"),
##   con los nombres de data/ability_notices.json.
## - make_plate: placa con borde y texto (fuente de textos a font_scale),
##   centrada en horizontal sobre `width` y con su borde inferior en `bottom`.
## - bob_y: bote del icono de la tecla (sube bob_px cada medio periodo).
class_name PulsePrompt
extends RefCounted

const FALLBACK_KEY: String = "G"


## Primera tecla de `action` en el Input Map (p. ej. "G"); `fallback` si no hay.
static func key_text(action: StringName, fallback: String = FALLBACK_KEY) -> String:
	if InputMap.has_action(action):
		var data: Dictionary = AbilityNotices.load_data()
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key: String = AbilityNotices.key_name(event as InputEventKey, data)
				if not key.is_empty():
					return key
	return fallback


## Crea bajo `parent` un Node2D `node_name` con una placa `plate_color` con
## borde `border_color` de 1 px y el texto (Label "Text") en blanco. Escala
## entera `scale_factor`; `pad` en px de arte; `width` y `bottom` en px locales
## de `parent`.
static func make_plate(parent: Node, node_name: String, label_text: String, font: Font, font_size: int,
		scale_factor: int, plate_color: String, border_color: String, pad: float, width: float,
		bottom: float) -> Node2D:
	scale_factor = maxi(1, scale_factor)
	var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	text_size.y = font.get_height(font_size)
	var plate_size := Vector2(ceilf(text_size.x) + pad * 2.0, ceilf(text_size.y) + pad * 2.0)
	var root := Node2D.new()
	root.name = node_name
	root.scale = Vector2.ONE * scale_factor
	root.position = Vector2(roundf((width - plate_size.x * scale_factor) * 0.5),
		roundf(bottom - plate_size.y * scale_factor))
	parent.add_child(root)
	var border := ColorRect.new()
	border.color = Color.html(border_color)
	border.position = Vector2(-1.0, -1.0)
	border.size = plate_size + Vector2(2.0, 2.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border)
	var plate := ColorRect.new()
	plate.color = Color.html(plate_color)
	plate.size = plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	var label := Label.new()
	label.name = "Text"
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = label_text
	label.position = Vector2(pad, pad)
	label.size = Vector2(ceilf(text_size.x), ceilf(text_size.y))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return root


## Altura del icono en el instante `time`: `base_y` o `bob_px` mas arriba en
## los medios periodos impares de `period_s`.
static func bob_y(base_y: float, time: float, period_s: float, bob_px: float) -> float:
	var period: float = maxf(period_s, 0.01)
	var up: bool = int(floorf(time / period)) % 2 == 1
	return base_y - (bob_px if up else 0.0)
