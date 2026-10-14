## Isak sin Sync Rate: ignora el input y no sale de este estado.
class_name DeadState
extends PlayerState


func enter() -> void:
	isak.set_pulse_area_active(false)
	# Una sola vez (sin bucle): se queda en el ultimo cuadro.
	isak.restart_animation(Isak.ANIM_DEATH)
	isak.notify_died()


func physics_update(delta: float) -> void:
	isak.apply_horizontal(0.0, delta)
	isak.apply_gravity(delta)
