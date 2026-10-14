## Movimiento en el suelo. Camina o corre segun run_held.
class_name RunState
extends PlayerState


func get_transition() -> StringName:
	var next: StringName = ground_transition()
	if next != NONE:
		return next
	if not isak.has_move_input():
		return IDLE
	return NONE


func physics_update(delta: float) -> void:
	isak.apply_horizontal(isak.input.move_axis, delta)
	isak.apply_gravity(delta)
	isak.play_animation(Isak.ANIM_RUN if isak.input.run_held else Isak.ANIM_WALK)
