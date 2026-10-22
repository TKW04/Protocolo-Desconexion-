## Golpe al suelo (gesto Mantener presionado; 2026-10-22, docs/propuesta-mundo-2.md
## §3.3; valores provisionales de la seccion ground_pound de
## data/isak_abilities.json). Lo pide Isak (wants_ground_pound) al mantener el
## gesto air_hold_s en el aire o ground_hold_s en el suelo.
## Fases:
##   - HOP (desde el suelo): saltito de ground_hop_px; al llegar arriba, DROP.
##   - ANTICIPATE (desde el aire): quieto en el aire anticipation_s; luego DROP.
##   - DROP: caida vertical a drop_speed_px_s, sin control horizontal. Al tocar
##     suelo nace la onda (Isak.land_ground_pound); si lo que pisa se rompe con
##     ella (tarjeta fragil del Mundo 2) sigue cayendo hasta el suelo siguiente.
##   - LAND: pose de land_pose_s sin moverse ni saltar; despues, reposo.
## Las plataformas de una via normales lo paran (aterriza en ellas). Un golpe
## (Hurt), la muerte, un vortice o la pose de espaldas lo cortan.
class_name GroundPoundState
extends PlayerState

enum Phase { HOP, ANTICIPATE, DROP, LAND }

## Pasos maximos que DROP sigue cayendo tras romper lo que pisa (la colision se
## quita en diferido) antes de aterrizar de todos modos.
const PASS_THROUGH_STEPS: int = 3

var _phase: Phase = Phase.DROP
var _time: float = 0.0
var _pass_through_left: int = 0
var _from_ground: bool = false


func enter() -> void:
	_from_ground = isak.is_on_floor()
	isak.begin_ground_pound(_from_ground)
	_time = 0.0
	_pass_through_left = 0
	if _from_ground:
		_phase = Phase.HOP
		isak.velocity = Vector2(0.0, -sqrt(2.0 * isak.physics.gravity * maxf(isak.abilities.pound_ground_hop_px, 0.0)))
	else:
		_phase = Phase.ANTICIPATE
		isak.velocity = Vector2.ZERO
	isak.update_ground_pound_pose(_phase == Phase.LAND)


func exit() -> void:
	isak.end_ground_pound()


func get_transition() -> StringName:
	if isak.is_warping() or isak.is_facing_back():
		return resting_state()
	if _phase == Phase.LAND and _time >= isak.abilities.pound_land_pose_s:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time += delta
	match _phase:
		Phase.HOP:
			isak.velocity.x = 0.0
			isak.apply_gravity(delta)
			if isak.velocity.y >= 0.0:
				_start_drop()
		Phase.ANTICIPATE:
			isak.velocity = Vector2.ZERO
			if _time >= isak.abilities.pound_anticipation_s:
				_start_drop()
		Phase.DROP:
			if isak.is_on_floor():
				if _pass_through_left > 0:
					_pass_through_left -= 1
				elif isak.land_ground_pound():
					# Lo pisado se rompe: sigue cayendo (la colision se quita en diferido).
					_pass_through_left = PASS_THROUGH_STEPS
				else:
					_phase = Phase.LAND
					_time = 0.0
					isak.velocity = Vector2.ZERO
					isak.update_ground_pound_pose(true)
					return
			isak.velocity = Vector2(0.0, isak.abilities.pound_drop_speed_px_s)
		Phase.LAND:
			isak.velocity.x = 0.0
			isak.apply_gravity(delta)


func get_phase() -> Phase:
	return _phase


func is_from_ground() -> bool:
	return _from_ground


func _start_drop() -> void:
	_phase = Phase.DROP
	_time = 0.0
	isak.velocity = Vector2(0.0, isak.abilities.pound_drop_speed_px_s)
	isak.begin_ground_pound_drop()
