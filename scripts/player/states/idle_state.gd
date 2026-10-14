## Quieto en el suelo. Cuenta el tiempo quieto y, al superar el umbral,
## reproduce la animacion de la terminal. Cualquier input la corta.
class_name IdleState
extends PlayerState


func enter() -> void:
	isak.reset_idle_time()
	isak.play_animation(Isak.ANIM_IDLE)


func exit() -> void:
	isak.reset_idle_time()


func get_transition() -> StringName:
	var next: StringName = ground_transition()
	if next != NONE:
		return next
	if isak.has_move_input():
		return RUN
	return NONE


func physics_update(delta: float) -> void:
	isak.apply_horizontal(0.0, delta)
	isak.apply_gravity(delta)
	if isak.input.has_any_intent():
		if isak.is_terminal_playing():
			isak.play_animation(Isak.ANIM_IDLE)
		isak.reset_idle_time()
		return
	if is_zero_approx(isak.velocity.x):
		isak.add_idle_time(delta)
