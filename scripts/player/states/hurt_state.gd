## Golpe recibido: retroceso breve sin control. La invulnerabilidad la
## gestiona Isak y dura mas que este estado.
class_name HurtState
extends PlayerState

var _time_left: float = 0.0


func enter() -> void:
	_time_left = isak.get_hurt_duration_s()
	isak.apply_knockback()
	isak.restart_animation(Isak.ANIM_HURT)


func get_transition() -> StringName:
	if _time_left <= 0.0:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time_left -= delta
	if isak.is_on_floor():
		isak.apply_horizontal(0.0, delta)
	isak.apply_gravity(delta)
