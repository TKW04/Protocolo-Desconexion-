## Placa de golpe al suelo con su plataforma temporal «Cargando...» (2026-10-27,
## paso 3 de docs/propuesta-hub-mundos-4-6.md §2.2-§2.3, verificacion V2 del
## acertijo del hub; la monta HubUpdatePuzzle desde data/hub_update.json).
## - La placa SOLO responde al golpe al suelo (EventBus.ground_pound_landed: la
##   onda toca la placa y los pies de Isak estan sobre ella, con tolerancia
##   feet_tolerance_px). El pulso no le hace nada (§2.7).
## - Al pulsarla sube la plataforma (platform_rect: solida, una sola pieza)
##   durante up_s segundos de TIEMPO DEL MUNDO; los ultimos warn_s parpadea
##   (aviso) y despues baja (sin colision; sin dano: Isak cae al suelo). Otro
##   golpe con la plataforma arriba vuelve a llenar el tiempo. Lo temporal vuelve
##   solo y se repite sin limite (§2.5).
## - Inerte (set_inert; Papelera llena): el golpe no hace nada.
## La plataforma se coloca ya arriba: su caja queda por encima de la cabeza de
## Isak de pie en el suelo, asi que nunca lo atrapa (aparece con un crecimiento
## solo visual de rise_s). Arte PROVISIONAL por codigo hasta el paso 7. Origen:
## esquina superior izquierda de la celda de la placa (apoyada en el suelo de la
## fila de abajo); platform_rect en coordenadas locales.
class_name PoundPlate
extends Node2D

const GROUP: StringName = &"pound_plate"

## La placa ha recibido un golpe al suelo (la plataforma sube o se rellena).
signal pressed
## La plataforma ha empezado a bajar.
signal platform_lowered

@export var plate_id: StringName = &""
## Plataforma en coordenadas locales (x, y = borde de arriba, ancho, grosor).
@export var platform_rect: Rect2 = Rect2(64.0, -64.0, 128.0, 16.0)
@export var up_s: float = 3.0
@export var warn_s: float = 0.5
@export var rise_s: float = 0.2
@export var plate_color: Color = Color("#ffa858")
## Ancho de la placa en px (alto: plate_height_px, sobre el suelo).
@export var plate_width_px: float = 64.0
@export var plate_height_px: float = 8.0
@export var feet_tolerance_px: float = 16.0

var _inert: bool = false
var _up_left: float = 0.0
var _rise_t: float = 0.0
var _presses: int = 0
var _lowered_count: int = 0
var _body: StaticBody2D
var _shape: CollisionShape2D
var _time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_body = StaticBody2D.new()
	_body.name = "Platform"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = platform_rect.size
	_shape.shape = box
	_shape.position = platform_rect.get_center()
	_shape.disabled = true
	_body.add_child(_shape)
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	_time += maxf(dt, 0.0)
	if _up_left > 0.0:
		_rise_t = minf(_rise_t + dt, rise_s)
		_up_left = maxf(_up_left - dt, 0.0)
		if _up_left <= 0.0:
			_lower()
	queue_redraw()


# --- Consultas ---

func is_platform_up() -> bool:
	return _up_left > 0.0


func is_platform_solid() -> bool:
	return _shape != null and not _shape.disabled


## Ultimos warn_s segundos: la plataforma parpadea antes de bajar.
func is_warning() -> bool:
	return _up_left > 0.0 and _up_left <= warn_s


func get_up_left() -> float:
	return _up_left


func get_press_count() -> int:
	return _presses


## Veces que la plataforma ha bajado sola (intentos que se acaban).
func get_lowered_count() -> int:
	return _lowered_count


func is_inert() -> bool:
	return _inert


## Caja de la placa en coordenadas globales (sobre el suelo de la celda).
func get_plate_rect() -> Rect2:
	var t: float = 64.0
	return Rect2(global_position + Vector2((t - plate_width_px) * 0.5, t - plate_height_px),
		Vector2(plate_width_px, plate_height_px))


## Caja de la plataforma en coordenadas globales.
func get_platform_rect() -> Rect2:
	return Rect2(global_position + platform_rect.position, platform_rect.size)


# --- Acciones ---

func set_inert(value: bool) -> void:
	_inert = value
	if _inert and is_platform_up():
		_lower()
	queue_redraw()


## Pulsa la placa (el golpe al suelo; pruebas). Falso si esta inerte.
func press() -> bool:
	if _inert:
		return false
	_presses += 1
	if not is_platform_up():
		_rise_t = 0.0
	_up_left = up_s
	# Diferido: el golpe llega durante el paso de fisica.
	_shape.set_deferred(&"disabled", false)
	pressed.emit()
	queue_redraw()
	return true


func _lower() -> void:
	_up_left = 0.0
	_rise_t = 0.0
	_shape.set_deferred(&"disabled", true)
	_lowered_count += 1
	platform_lowered.emit()
	queue_redraw()


func _on_ground_pound_landed(rect: Rect2, source: Node2D) -> void:
	if _inert or not is_inside_tree():
		return
	var plate: Rect2 = get_plate_rect()
	if not rect.intersects(plate.grow(1.0)):
		return
	if source != null and is_instance_valid(source):
		var x: float = source.global_position.x
		if x < plate.position.x - feet_tolerance_px or x > plate.end.x + feet_tolerance_px:
			return
	press()


func _draw() -> void:
	var t: float = 64.0
	# Placa: losa del color del Debug del Mundo 2 con el dibujo de la onda.
	var plate := Rect2(Vector2((t - plate_width_px) * 0.5, t - plate_height_px), Vector2(plate_width_px, plate_height_px))
	var color: Color = plate_color if not _inert else HubData.color("gris_apagado")
	draw_rect(plate, HubData.color("dock"))
	draw_rect(plate, color, false, 2.0)
	var mid: float = plate.get_center().x
	for i: int in 3:
		var r: float = 6.0 + 7.0 * float(i)
		draw_arc(Vector2(mid, plate.position.y), r, PI, TAU, 10, Color(color, 0.9 - 0.25 * float(i)), 2.0)
	if not is_platform_up():
		return
	if is_warning() and int(_time * 10.0) % 2 == 0:
		return
	var p: Rect2 = platform_rect
	var grow: float = clampf(_rise_t / maxf(rise_s, 0.01), 0.0, 1.0)
	# Columna «Cargando...» desde el suelo (solo dibujo) y la losa encima.
	var floor_y: float = t
	var top: float = lerpf(floor_y, p.position.y, grow)
	draw_rect(Rect2(Vector2(p.position.x + 8.0, top), Vector2(p.size.x - 16.0, floor_y - top)), Color(HubData.color("traza"), 0.55))
	draw_rect(Rect2(Vector2(p.position.x, top), p.size), HubData.color("panel"))
	draw_rect(Rect2(Vector2(p.position.x, top), p.size), plate_color, false, 2.0)
	var fill: float = clampf(_up_left / maxf(up_s, 0.01), 0.0, 1.0)
	draw_rect(Rect2(Vector2(p.position.x + 4.0, top + 4.0), Vector2((p.size.x - 8.0) * fill, p.size.y - 8.0)), plate_color)
