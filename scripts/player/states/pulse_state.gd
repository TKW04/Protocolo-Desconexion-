## Pulso de datos: accion corta en el suelo. Bloquea el movimiento horizontal
## (solo friccion) y activa PulseArea mientras dura.
class_name PulseState
extends PlayerState

var _time_left: float = 0.0


func enter() -> void:
	_time_left = isak.abilities.pulse_duration_s
	isak.play_animation(Isak.ANIM_PULSE)
	isak.set_pulse_area_active(true)


func exit() -> void:
	isak.set_pulse_area_active(false)


func get_transition() -> StringName:
	if _time_left <= 0.0:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time_left -= delta
	isak.apply_horizontal(0.0, delta)
	isak.apply_gravity(delta)
