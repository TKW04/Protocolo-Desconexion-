## Agitar (gesto Agitar; 2026-10-28, docs/propuesta-mundo-4.md §3.2.1; valores
## provisionales de la seccion shockwave de data/isak_abilities.json). Lo pide
## Isak (wants_shockwave) al pulsar gesture_shake en el suelo.
## Fases:
##   - WINDUP: windup_s sacudiendo el celular, sin moverse; al terminar nace la
##     onda (Isak.fire_shockwave).
##   - EXPOSED: exposed_s sin moverse ni saltar y SIN invulnerabilidad («deja a
##     Isak expuesto un instante»); despues, reposo.
## La energia se cobra al entrar (como el dash). Un golpe (Hurt), la muerte, un
## vortice o la pose de espaldas lo cortan (si es antes de la onda, no sale). El
## enfriamiento empieza al salir.
class_name ShockwaveState
extends PlayerState

enum Phase { WINDUP, EXPOSED }

var _phase: Phase = Phase.WINDUP
var _time: float = 0.0


func enter() -> void:
	_phase = Phase.WINDUP
	_time = 0.0
	isak.begin_shockwave()


func exit() -> void:
	isak.end_shockwave()


func get_transition() -> StringName:
	if isak.is_warping() or isak.is_facing_back():
		return resting_state()
	if _phase == Phase.EXPOSED and _time >= isak.abilities.shockwave_exposed_s:
		return resting_state()
	return NONE


func physics_update(delta: float) -> void:
	_time += delta
	isak.apply_horizontal(0.0, delta)
	isak.apply_gravity(delta)
	if _phase == Phase.WINDUP:
		isak.update_shockwave_pose(_time)
		if _time + 0.0001 >= isak.abilities.shockwave_windup_s:
			isak.fire_shockwave()
			_phase = Phase.EXPOSED
			_time = 0.0


func get_phase() -> Phase:
	return _phase
