## Dash (gesto Deslizar, accion gesture_swipe; 2026-10-19, docs/propuesta-1-3.md
## §2, valores provisionales de la seccion dash de data/isak_abilities.json).
## Tramo horizontal de dash_distance_px en dash_duration_s con gravedad 0 (la
## altura no cambia), en suelo o en aire. Isak lo empieza (begin_dash: cobra la
## energia, invulnerabilidad, dash aereo gastado) y lo termina (end_dash:
## enfriamiento, velocidad final). El terreno y los objetos solidos lo paran
## (move_and_slide; el dash acaba antes, sin rebote ni dano); las plataformas
## de una via no frenan en horizontal. Un vortice o una pose de espaldas lo
## cortan. Sin control durante el dash (ni pulso, ni laser, ni salto: el buffer
## de salto sigue contando y vale al terminar).
class_name DashState
extends PlayerState

## Margen (px) para dar el recorrido por completo.
const DISTANCE_EPS: float = 0.5

var _direction: float = 1.0
var _start_x: float = 0.0
var _time: float = 0.0
var _blocked: bool = false
var _completed: bool = false


func enter() -> void:
	_direction = isak.begin_dash()
	_start_x = isak.global_position.x
	_time = 0.0
	_blocked = false
	_completed = false
	isak.velocity = Vector2(_direction * _speed(), 0.0)


func exit() -> void:
	isak.end_dash(_direction, _completed and not _blocked, _blocked)


func get_transition() -> StringName:
	if isak.is_warping() or isak.is_facing_back():
		return resting_state()
	# Embestida: abajo durante un dash aereo (con la Combinacion; corta el dash).
	if isak.wants_combo() == COMBO_RAM:
		return COMBO_RAM
	if _travelled() >= isak.abilities.dash_distance_px - DISTANCE_EPS \
			or _time >= isak.abilities.dash_duration_s * 2.0:
		_completed = true
		return resting_state()
	# Contra una pared en su direccion: el dash termina antes.
	if _time > 0.0 and isak.is_on_wall() and isak.get_wall_normal().x * _direction < 0.0:
		_blocked = true
		_completed = true
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time += delta
	var remaining: float = maxf(isak.abilities.dash_distance_px - _travelled(), 0.0)
	var speed: float = minf(_speed(), remaining / maxf(delta, 0.0001))
	isak.velocity = Vector2(_direction * speed, 0.0)
	isak.update_dash_pose()


func get_direction() -> float:
	return _direction


func _travelled() -> float:
	return absf(isak.global_position.x - _start_x)


func _speed() -> float:
	return isak.abilities.dash_distance_px / maxf(isak.abilities.dash_duration_s, 0.001)
