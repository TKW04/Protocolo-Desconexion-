## PlayerInput que lee las acciones del Input Map (nunca teclas directas).
class_name ActionPlayerInput
extends PlayerInput

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
const ACTION_RUN: StringName = &"run"
const ACTION_PULSE: StringName = &"pulse"
const ACTION_LASER: StringName = &"laser"
const ACTION_HIDE: StringName = &"hide"
## Gesto Deslizar (dash; 2026-10-19).
const ACTION_DASH: StringName = &"gesture_swipe"


func poll() -> void:
	move_axis = Input.get_axis(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT)
	jump_pressed = Input.is_action_just_pressed(ACTION_JUMP)
	jump_held = Input.is_action_pressed(ACTION_JUMP)
	run_held = Input.is_action_pressed(ACTION_RUN)
	pulse_pressed = Input.is_action_just_pressed(ACTION_PULSE)
	laser_pressed = Input.is_action_just_pressed(ACTION_LASER)
	hide_pressed = InputMap.has_action(ACTION_HIDE) and Input.is_action_just_pressed(ACTION_HIDE)
	dash_pressed = InputMap.has_action(ACTION_DASH) and Input.is_action_just_pressed(ACTION_DASH)
