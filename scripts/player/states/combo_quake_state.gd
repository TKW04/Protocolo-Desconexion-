## Sismo (Combinacion: Pellizcar + abajo en el aire; 2026-10-29,
## docs/propuesta-mundo-5.md §3.2.2 y §3.2.4; valores provisionales de
## combo.quake de data/isak_abilities.json). Comprimido en el aire, mantener
## abajo: caida vertical a drop_speed_px_s; al aterrizar nace la onda que recorre
## todo el suelo visible (Isak.land_combo) y queda la pose land_pose_s. Isak sigue
## comprimido. Un golpe (Hurt), un vortice o la pose de espaldas lo cortan.
class_name ComboQuakeState
extends PlayerState

enum Phase { DROP, LAND }

var _phase: Phase = Phase.DROP
var _time: float = 0.0


func enter() -> void:
	isak.begin_combo(COMBO_QUAKE)
	_phase = Phase.DROP
	_time = 0.0
	isak.velocity = Vector2(0.0, isak.abilities.combo_quake_drop_speed_px_s)
	isak.update_combo_pose(COMBO_QUAKE, false)


func exit() -> void:
	isak.end_combo(COMBO_QUAKE)


func get_transition() -> StringName:
	if isak.is_warping() or isak.is_facing_back():
		return resting_state()
	if _phase == Phase.LAND and _time >= isak.abilities.combo_quake_land_pose_s:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time += delta
	if _phase == Phase.DROP:
		if isak.is_on_floor():
			isak.land_combo(COMBO_QUAKE)
			_phase = Phase.LAND
			_time = 0.0
			isak.velocity = Vector2.ZERO
			isak.update_combo_pose(COMBO_QUAKE, true)
			return
		isak.velocity = Vector2(0.0, isak.abilities.combo_quake_drop_speed_px_s)
		return
	isak.velocity.x = 0.0
	isak.apply_gravity(delta)


func get_phase() -> Phase:
	return _phase
