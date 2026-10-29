## Filo (Combinacion: Pellizcar + Deslizar en el aire; 2026-10-29,
## docs/propuesta-mundo-5.md §3.2.2; valores provisionales de combo.edge de
## data/isak_abilities.json). Comprimido en el aire, Deslizar da un dash
## comprimido de distance_px en duration_s con gravedad 0, invulnerable, que
## derrota a los enemigos pequenos que atraviesa (Isak.edge_sweep). La pared lo
## para. Al acabar Isak sigue comprimido. Un vortice o la pose de espaldas lo cortan.
class_name ComboEdgeState
extends PlayerState

const DISTANCE_EPS: float = 0.5

var _direction: float = 1.0
var _start_x: float = 0.0
var _time: float = 0.0
var _completed: bool = false
var _blocked: bool = false
var _hit: Dictionary = {}


func enter() -> void:
	_direction = isak.begin_combo(COMBO_EDGE)
	_start_x = isak.global_position.x
	_time = 0.0
	_completed = false
	_blocked = false
	_hit = {}
	isak.velocity = Vector2(_direction * _speed(), 0.0)
	isak.update_combo_pose(COMBO_EDGE, false)


func exit() -> void:
	isak.end_combo(COMBO_EDGE, _direction, _completed and not _blocked)


func get_transition() -> StringName:
	if isak.is_warping() or isak.is_facing_back():
		return resting_state()
	if _travelled() >= isak.abilities.combo_edge_distance_px - DISTANCE_EPS \
			or _time >= isak.abilities.combo_edge_duration_s * 2.0:
		_completed = true
		return resting_state()
	if _time > 0.0 and isak.is_on_wall() and isak.get_wall_normal().x * _direction < 0.0:
		_blocked = true
		_completed = true
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time += delta
	isak.edge_sweep(_hit)
	var remaining: float = maxf(isak.abilities.combo_edge_distance_px - _travelled(), 0.0)
	var speed: float = minf(_speed(), remaining / maxf(delta, 0.0001))
	isak.velocity = Vector2(_direction * speed, 0.0)
	isak.update_combo_pose(COMBO_EDGE, false)


func get_direction() -> float:
	return _direction


func _travelled() -> float:
	return absf(isak.global_position.x - _start_x)


func _speed() -> float:
	return isak.abilities.combo_edge_distance_px / maxf(isak.abilities.combo_edge_duration_s, 0.001)
