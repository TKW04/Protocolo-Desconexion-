## Embestida (Combinacion: Deslizar + abajo en el aire; 2026-10-29,
## docs/propuesta-mundo-5.md §3.2.2; valores provisionales de combo.ram de
## data/isak_abilities.json). La pide Isak (wants_combo) al mantener abajo
## durante un dash aereo: corta el dash y cae en diagonal (angle_deg bajo la
## horizontal, speed_px_s) hacia donde iba, invulnerable hasta tocar suelo.
## Al aterrizar nace la onda (Isak.land_combo) y queda la pose land_pose_s.
## Un vortice o la pose de espaldas lo cortan; un golpe no (invulnerable).
class_name ComboRamState
extends PlayerState

enum Phase { DIVE, LAND }

var _phase: Phase = Phase.DIVE
var _direction: float = 1.0
var _time: float = 0.0


func enter() -> void:
	_direction = isak.begin_combo(COMBO_RAM)
	_phase = Phase.DIVE
	_time = 0.0
	isak.velocity = _dive_velocity()
	isak.update_combo_pose(COMBO_RAM, false)


func exit() -> void:
	isak.end_combo(COMBO_RAM)


func get_transition() -> StringName:
	if isak.is_warping() or isak.is_facing_back():
		return resting_state()
	if _phase == Phase.LAND and _time >= isak.abilities.combo_ram_land_pose_s:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time += delta
	if _phase == Phase.DIVE:
		if isak.is_on_floor():
			isak.land_combo(COMBO_RAM)
			_phase = Phase.LAND
			_time = 0.0
			isak.velocity = Vector2.ZERO
			isak.update_combo_pose(COMBO_RAM, true)
			return
		isak.velocity = _dive_velocity()
		isak.update_combo_pose(COMBO_RAM, false)
		return
	isak.velocity.x = 0.0
	isak.apply_gravity(delta)


func get_phase() -> Phase:
	return _phase


func get_direction() -> float:
	return _direction


func _dive_velocity() -> Vector2:
	var angle: float = deg_to_rad(isak.abilities.combo_ram_angle_deg)
	return Vector2(_direction * cos(angle), sin(angle)) * isak.abilities.combo_ram_speed_px_s
