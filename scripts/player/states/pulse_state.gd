## Pulso de datos: accion corta en el suelo. Bloquea el movimiento horizontal
## (solo friccion), activa PulseArea y muestra la onda visual mientras dura.
class_name PulseState
extends PlayerState

var _time_left: float = 0.0


func enter() -> void:
	_time_left = isak.abilities.pulse_duration_s
	isak.play_animation(Isak.ANIM_PULSE)
	isak.set_pulse_area_active(true)
	isak.start_pulse_effect()


func exit() -> void:
	isak.set_pulse_area_active(false)
	isak.stop_pulse_effect()


func get_transition() -> StringName:
	if _time_left <= 0.0:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time_left -= delta
	isak.advance_pulse_effect(delta)
	isak.apply_horizontal(0.0, delta)
	isak.apply_gravity(delta)
