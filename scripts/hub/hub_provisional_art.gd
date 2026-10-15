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
## kind room: altura del suelo (dock), foto rota y punto del indicador de pagina.
var room_floor_y: float = 576.0
var room_photo: Rect2 = Rect2()
var room_page_dot: Vector2 = Vector2.ZERO

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
		&"room":
			_draw_room()
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


## Sala: fondo, foto rota en 5 piezas (gris; pieza 1 con contorno cian
## tenue), marco de paredes, dock (suelo) y punto de pagina.
func _draw_room() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), _c("base"))
	# Trazas de circuito de 1 px.
	for y: float in [room_floor_y - 200.0, room_floor_y - 120.0]:
		draw_rect(Rect2(24.0, y, w - 48.0, 1.0), _c("traza"))
	if room_photo.has_area():
		_box(room_photo, _c("gris_apagado"))
		var inner: Rect2 = room_photo.grow(-2.0)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2.0)), _c("gris_foto"))
		# Grietas entre las 5 piezas (sombra) y contorno de la pieza 1.
		var xs: Array[float] = []
		for i: int in range(1, 5):
			xs.append(inner.position.x + inner.size.x * i / 5.0 + (8.0 if i % 2 == 0 else -8.0))
		var prev: float = inner.position.x
		for i: int in xs.size():
			var x: float = xs[i]
			draw_rect(Rect2(x - 1.0, inner.position.y, 2.0, inner.size.y * 0.5), _c("sombra"))
			draw_rect(Rect2(x + (6.0 if i % 2 == 0 else -6.0) - 1.0, inner.position.y + inner.size.y * 0.5, 2.0,
				inner.size.y * 0.5), _c("sombra"))
			if i == 0:
				draw_rect(Rect2(prev, inner.position.y, x - prev, inner.size.y), _c("cian_tenue"), false, 2.0)
			prev = x
	# Paredes: marco a los lados.
	for x: float in [0.0, w - 6.0]:
		draw_rect(Rect2(x, 0.0, 6.0, room_floor_y), _c("dock"))
	draw_rect(Rect2(6.0, 0.0, 1.0, room_floor_y), _c("borde"))
	draw_rect(Rect2(w - 7.0, 0.0, 1.0, room_floor_y), _c("borde"))
	# Dock (suelo).
	draw_rect(Rect2(0.0, room_floor_y, w, h - room_floor_y), _c("dock"))
	draw_rect(Rect2(0.0, room_floor_y, w, 4.0), _c("borde"))
	draw_rect(Rect2(0.0, room_floor_y + 4.0, w, 2.0), _c("gris_foto"))
	draw_rect(Rect2(16.0, room_floor_y + 16.0, w - 32.0, 1.0), _c("traza"))
	draw_rect(Rect2(0.0, h - 8.0, w, 8.0), _c("sombra"))
	if room_page_dot != Vector2.ZERO:
		draw_rect(Rect2(room_page_dot - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), _c("texto_claro"))


func _draw_slot() -> void:
	var rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	draw_rect(rect, _c("panel"))
	draw_rect(rect, _c("gris_apagado"), false, 2.0)
	draw_rect(Rect2(rect.position.x + 6.0, rect.end.y - 8.0, rect.size.x - 12.0, 2.0), _c("sombra"))
