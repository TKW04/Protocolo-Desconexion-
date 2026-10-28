## Estado base de la maquina de estados de Isak.
## Ciclo por paso de fisica (lo dirige Isak.step):
##   1. get_transition(): nombre del siguiente estado o NONE.
##   2. physics_update(delta): calcula la velocidad.
##   3. Isak llama a move_and_slide().
class_name PlayerState
extends RefCounted

const NONE: StringName = &""
const IDLE: StringName = &"idle"
const RUN: StringName = &"run"
const JUMP: StringName = &"jump"
const FALL: StringName = &"fall"
const PULSE: StringName = &"pulse"
const HURT: StringName = &"hurt"
const DEAD: StringName = &"dead"
## Dash (gesto Deslizar, 2026-10-19; DashState).
const DASH: StringName = &"dash"
## Golpe al suelo (gesto Mantener presionado, 2026-10-22; GroundPoundState).
const GROUND_POUND: StringName = &"ground_pound"
## Agitar (gesto Agitar, 2026-10-28; ShockwaveState).
const SHOCKWAVE: StringName = &"shockwave"

var isak: Isak


func _init(owner_isak: Isak) -> void:
	isak = owner_isak


func enter() -> void:
	pass


func exit() -> void:
	pass


func get_transition() -> StringName:
	return NONE


func physics_update(_delta: float) -> void:
	pass


## Transiciones comunes a los estados en el suelo (Idle y Run).
## Prioridad: caer > pulso > dash > golpe al suelo > Agitar > salto > movimiento.
func ground_transition() -> StringName:
	if not isak.is_on_floor():
		return FALL
	if isak.input.pulse_pressed and isak.can_pulse():
		return PULSE
	if isak.wants_dash():
		return DASH
	if isak.wants_ground_pound():
		return GROUND_POUND
	if isak.wants_shockwave():
		return SHOCKWAVE
	if isak.wants_jump() and isak.can_jump():
		return JUMP
	return NONE


## Estado de destino al terminar una accion (Pulse, Hurt) o al aterrizar.
func resting_state() -> StringName:
	if not isak.is_on_floor():
		return FALL
	if isak.has_move_input():
		return RUN
	return IDLE
