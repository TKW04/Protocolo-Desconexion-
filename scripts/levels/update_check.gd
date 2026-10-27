## Verificacion del acertijo «Actualizacion del sistema» del hub (2026-10-27,
## paso 3 de docs/propuesta-hub-mundos-4-6.md §2.2-§2.3; la monta
## HubUpdatePuzzle desde data/hub_update.json). Terminal de 1 x 2 tiles con un
## marco del color del Debug de su mundo que se ENCIENDE y QUEDA ENCENDIDA
## (durante la visita: no se guarda, §2.6).
## Modos (`mode`):
## - "pulse": un pulso que toca hit_rect la enciende y Isak se pone de espaldas
##   pose_s segundos (como el interruptor de pulso, PowerSwitch). V2 y V3.
## - "linked": no responde al pulso; la enciende quien la enlaza con complete()
##   (V1: el receptor enlazado RE al activarse).
## Inerte (set_inert, p. ej. con la Papelera llena, §2.5): el pulso no hace nada.
## No es solida ni objetivo del laser. Sin rojo (en el hub nada hace dano).
## Arte PROVISIONAL por codigo (pantalla apagada / encendida y marco de color)
## hasta el paso 7; sin pictogramas todavia. El origen es la esquina superior
## izquierda de su celda de arriba.
class_name UpdateCheck
extends Node2D

const GROUP: StringName = &"update_check"
const MODE_PULSE: StringName = &"pulse"
const MODE_LINKED: StringName = &"linked"

## Se ha encendido (para el resto de la visita).
signal completed(check_id: StringName)
## Un pulso la ha tocado sin efecto (inerte o en modo linked).
signal rejected(check_id: StringName)

@export var check_id: StringName = &""
@export var mode: StringName = MODE_PULSE
## Color del marco (color del Debug del mundo de la verificacion).
@export var frame_color: Color = Color("#3dfff5")
## Nombre corto (texto de interfaz PROVISIONAL bajo la pantalla; vacio = sin).
@export var label_text: String = ""
@export var size: Vector2 = Vector2(64.0, 128.0)
## Segundos (tiempo del mundo) que Isak queda de espaldas tras el pulso.
@export var pose_s: float = 0.45

var _done: bool = false
var _inert: bool = false
var _posed: Isak
var _pose_left: float = 0.0
var _time: float = 0.0
var _rejections: int = 0
var _label: Label


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.pulse_fired.connect(receive_pulse)
	if not label_text.is_empty():
		_label = Label.new()
		_label.name = "Label"
		_label.text = label_text
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override(&"font_size", 10)
		_label.add_theme_color_override(&"font_color", frame_color)
		_label.position = Vector2(-32.0, -18.0)
		_label.size = Vector2(size.x + 64.0, 16.0)
		add_child(_label)
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo (pose y brillo).
func advance(dt: float) -> void:
	_time += maxf(dt, 0.0)
	if _pose_left > 0.0:
		_pose_left -= dt
		if _pose_left <= 0.0:
			_pose_left = 0.0
			if _posed != null and is_instance_valid(_posed) and _posed.is_facing_back():
				_posed.face_side()
			_posed = null
	queue_redraw()


# --- Consultas ---

func is_completed() -> bool:
	return _done


func is_inert() -> bool:
	return _inert


func get_rejection_count() -> int:
	return _rejections


func get_hit_rect() -> Rect2:
	return Rect2(global_position, size)


func is_posing() -> bool:
	return _pose_left > 0.0


# --- Acciones ---

func set_inert(value: bool) -> void:
	_inert = value
	queue_redraw()


## Pulso de Isak (EventBus.pulse_fired). Verdadero si la ha encendido ahora.
func receive_pulse(area: Area2D) -> bool:
	if _done or not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	if _inert or mode != MODE_PULSE:
		_rejections += 1
		rejected.emit(check_id)
		return false
	var isak := area.get_parent() as Isak if area != null else null
	if isak != null and is_instance_valid(isak) and not isak.is_dead() and isak.face_back():
		_posed = isak
		_pose_left = pose_s
	return complete()


## La enciende (modo linked o pruebas). Falso si ya lo estaba o esta inerte.
func complete() -> bool:
	if _done or _inert:
		return false
	_done = true
	queue_redraw()
	completed.emit(check_id)
	return true


func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size)
	draw_rect(body, HubData.color("panel"))
	var frame: Color = frame_color if not _inert else HubData.color("gris_apagado")
	var border: float = 4.0
	draw_rect(body.grow(-border * 0.5), frame, false, border)
	var screen := Rect2(Vector2(10.0, 12.0), Vector2(size.x - 20.0, size.y * 0.45))
	if _done:
		var glow: float = 0.85 + 0.15 * sin(_time * 4.0)
		draw_rect(screen, Color(frame_color, glow))
		# Marca de «hecho»: una V del fondo profundo.
		var c: Vector2 = screen.get_center()
		draw_polyline(PackedVector2Array([c + Vector2(-10, 0), c + Vector2(-3, 8), c + Vector2(11, -9)]),
			HubData.color("fondo_profundo"), 4.0)
	else:
		draw_rect(screen, HubData.color("fondo_profundo"))
		draw_rect(screen, Color(frame, 0.45), false, 2.0)
	# Pie de la terminal.
	draw_rect(Rect2(Vector2(size.x * 0.5 - 10.0, size.y - 14.0), Vector2(20.0, 14.0)), HubData.color("dock"))
