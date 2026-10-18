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
	# Con el Ocultarte no se corre (is_running): camina.
	isak.play_animation(Isak.ANIM_RUN if isak.is_running() else Isak.ANIM_WALK)
