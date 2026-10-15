## PlayerInput que lee las acciones del Input Map (nunca teclas directas).
class_name ActionPlayerInput
extends PlayerInput

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
const ACTION_RUN: StringName = &"run"
const ACTION_PULSE: StringName = &"pulse"
const ACTION_LASER: StringName = &"laser"


func poll() -> void:
	move_axis = Input.get_axis(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT)
	jump_pressed = Input.is_action_just_pressed(ACTION_JUMP)
	jump_held = Input.is_action_pressed(ACTION_JUMP)
	run_held = Input.is_action_pressed(ACTION_RUN)
	pulse_pressed = Input.is_action_just_pressed(ACTION_PULSE)
	laser_pressed = Input.is_action_just_pressed(ACTION_LASER)
