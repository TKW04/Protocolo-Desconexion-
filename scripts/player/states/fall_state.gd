## En el aire bajando (o tras salir de un borde). Permite saltar durante el
## coyote time y aterriza en Idle o Run.
class_name FallState
extends PlayerState


func enter() -> void:
	isak.update_air_animation()


func get_transition() -> StringName:
	# Dash aereo (uno por estancia en el aire; Isak.wants_dash lo comprueba).
	if isak.wants_dash():
		return DASH
	if isak.is_on_floor():
		if isak.wants_jump() and isak.can_jump():
			return JUMP
		return resting_state()
	if isak.wants_jump() and isak.can_jump():
		return JUMP
	return NONE


func physics_update(delta: float) -> void:
	isak.apply_horizontal(isak.input.move_axis, delta)
	isak.apply_gravity(delta)
	isak.update_air_animation()
