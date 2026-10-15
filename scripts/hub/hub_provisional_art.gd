## Arte PROVISIONAL del hub (2026-10-15): rectangulos dibujados con _draw en los
## colores de assets/palettes/hub.gpl (roles de data/hub.json, colors). Es la
## capa que se sustituye por el arte final (assets/sprites/hub/, de
## tools/gen_hub_objects.py): cada estacion o hueco tiene un nodo "Visual"; si su
## entrada de datos trae "frames" (SpriteFrames que existan), se usa un
## AnimatedSprite2D con animaciones off / prompt / active y este nodo no se crea
## (ver HubStation._build_visual y HubRoom). El origen es la esquina superior
## izquierda; `size` en px de pantalla.
## Tipos (kind):
## - terminal: monitor sobre pedestal (copia local). state off (pantalla en
##   sombra, cursor), prompt (cian_tenue) o active (cian_brillo); icon "copy"
##   dibuja dos hojas superpuestas en la pantalla.
## - calc_dormant: calculadora gris apagada (visor con ojos cerrados, teclado).
## - slot: silueta apagada (hueco del dock para un aliado futuro).
class_name HubProvisionalArt
extends Node2D

const STATE_OFF: StringName = &"off"
const STATE_PROMPT: StringName = &"prompt"
const STATE_ACTIVE: StringName = &"active"

@export var kind: StringName = &"terminal"
@export var size: Vector2 = Vector2(64.0, 128.0)
@export var icon: StringName = &""

var state: StringName = STATE_OFF:
	set(value):
		state = value
		queue_redraw()


## Cambia el estado mostrado (off / prompt / active). Misma API que el
## AnimatedSprite2D del arte final (ver HubStation._show_visual_state).
func show_state(value: StringName) -> void:
	state = value


func _draw() -> void:
	match kind:
		&"terminal":
			_draw_terminal()
		&"calc_dormant":
			_draw_calc()
		&"slot":
			_draw_slot()
		_:
			draw_rect(Rect2(Vector2.ZERO, size), HubData.color("gris_apagado"))


func _c(role: String) -> Color:
	return HubData.color(role)


## Rectangulo con contorno de 2 px en fondo_profundo.
func _box(rect: Rect2, fill: Color, outline: String = "fondo_profundo") -> void:
	draw_rect(rect, _c(outline))
	draw_rect(rect.grow(-2.0), fill)


func _draw_terminal() -> void:
	var w: float = size.x
	var h: float = size.y
	# Pedestal y pie.
	_box(Rect2(w * 0.375, h * 0.62, w * 0.25, h * 0.3), _c("dock"))
	_box(Rect2(w * 0.125, h * 0.88, w * 0.75, h * 0.12), _c("dock"))
	draw_rect(Rect2(w * 0.125 + 2.0, h * 0.88 + 2.0, w * 0.75 - 4.0, 2.0), _c("borde"))
	# Monitor.
	var monitor := Rect2(0.0, h * 0.23, w, h * 0.42)
	_box(monitor, _c("panel"))
	draw_rect(Rect2(monitor.position + Vector2(2.0, 2.0), Vector2(monitor.size.x - 4.0, 2.0)), _c("borde"))
	var screen: Rect2 = monitor.grow(-6.0)
	var screen_color: Color = _c("sombra")
	if state == STATE_PROMPT:
		screen_color = _c("cian_tenue")
	elif state == STATE_ACTIVE:
		screen_color = _c("cian_brillo")
	draw_rect(screen, screen_color)
	# Traza de 1 px bajo la pantalla.
	draw_rect(Rect2(screen.position.x, monitor.end.y - 4.0, screen.size.x, 1.0), _c("traza"))
	var ink: Color = _c("acento_cian") if state == STATE_OFF else _c("fondo_profundo")
	if icon == &"copy":
		var s: float = minf(screen.size.x, screen.size.y) * 0.45
		var center: Vector2 = screen.get_center()
		var back := Rect2(center + Vector2(-s * 0.35, -s * 0.65), Vector2(s * 0.8, s))
		var front := Rect2(center + Vector2(-s * 0.55, -s * 0.35), Vector2(s * 0.8, s))
		draw_rect(back, ink, false, 2.0)
		draw_rect(front, screen_color)
		draw_rect(front, ink, false, 2.0)
	else:
		draw_rect(Rect2(screen.position + Vector2(4.0, screen.size.y - 10.0), Vector2(6.0, 4.0)), ink)


func _draw_calc() -> void:
	var w: float = size.x
	var h: float = size.y
	_box(Rect2(0.0, 0.0, w, h), _c("gris_apagado"))
	draw_rect(Rect2(2.0, 2.0, w - 4.0, 2.0), _c("gris_foto"))
	var display := Rect2(w * 0.15, h * 0.1, w * 0.7, h * 0.24)
	_box(display, _c("sombra"))
	# Ojos cerrados (dormida): dos rayas.
	var eye_y: float = display.get_center().y
	draw_rect(Rect2(display.position.x + display.size.x * 0.2, eye_y, display.size.x * 0.2, 2.0), _c("texto_tenue"))
	draw_rect(Rect2(display.position.x + display.size.x * 0.6, eye_y, display.size.x * 0.2, 2.0), _c("texto_tenue"))
	# Teclado 3x3.
	var key_w: float = w * 0.18
	var key_h: float = h * 0.12
	for row: int in 3:
		for col: int in 3:
			var pos := Vector2(w * 0.15 + col * (key_w + w * 0.08), h * 0.42 + row * (key_h + h * 0.06))
			draw_rect(Rect2(pos, Vector2(key_w, key_h)), _c("base"))


func _draw_slot() -> void:
	var rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	draw_rect(rect, _c("panel"))
	draw_rect(rect, _c("gris_apagado"), false, 2.0)
	draw_rect(Rect2(rect.position.x + 6.0, rect.end.y - 8.0, rect.size.x - 12.0, 2.0), _c("sombra"))
