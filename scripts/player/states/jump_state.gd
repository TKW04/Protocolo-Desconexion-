## Subida del salto. Salto completo: sin corte por soltar el boton.
## Pasa a Fall en el apogeo (velocidad vertical >= 0) o al chocar con un techo.
class_name JumpState
extends PlayerState


func enter() -> void:
	isak.start_jump()
	isak.update_air_animation()


func get_transition() -> StringName:
	# Dash aereo (uno por estancia en el aire; Isak.wants_dash lo comprueba).
	if isak.wants_dash():
		return DASH
	# Golpe al suelo en el aire (tambien tras un dash aereo: golpe normal).
	if isak.wants_ground_pound():
		return GROUND_POUND
	if isak.velocity.y >= 0.0:
		return FALL
	return NONE


func physics_update(delta: float) -> void:
	isak.apply_horizontal(isak.input.move_axis, delta)
	isak.apply_gravity(delta)
	isak.update_air_animation()
