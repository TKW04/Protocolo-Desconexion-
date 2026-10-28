## Congelado (estado nuevo del Mundo 4; 2026-10-28, docs/propuesta-mundo-4.md §3.3 y
## decision 3 de su §9). Lo pide quien congela con Isak.freeze(segundos, fuente).
## Isak queda QUIETO donde esta (tambien en el aire: sin gravedad); su velocidad se
## guarda al entrar y se devuelve al salir (Isak.begin_freeze / end_freeze). La cuenta
## va en tiempo del mundo (el Debug la alarga, no la rompe).
## Salidas:
##   - se acaba la cuenta: reposo con la velocidad que llevaba;
##   - Agitar (Isak.wants_shockwave, tambien en el aire): ShockwaveState con la onda
##     al instante;
##   - un vortice o la pose de espaldas; morir (Isak.die) cambia a Dead directamente.
## Un golpe recibido congelado resta Sync pero no lo saca de aqui (Isak.take_hit).
class_name FrozenState
extends PlayerState


func enter() -> void:
	isak.begin_freeze()


func exit() -> void:
	isak.end_freeze()


func get_transition() -> StringName:
	if isak.wants_shockwave():
		isak.mark_shockwave_instant()
		return SHOCKWAVE
	if isak.is_warping() or isak.is_facing_back() or isak.get_frozen_left() <= 0.0:
		return _after_freeze()
	return NONE


func physics_update(delta: float) -> void:
	isak.velocity = Vector2.ZERO
	isak.advance_freeze(WorldTime.scaled_delta(delta))


## Reposo segun la velocidad que se devolvera al salir (la de antes de congelarse).
func _after_freeze() -> StringName:
	if isak.get_frozen_velocity().y < 0.0 or not isak.is_on_floor():
		return FALL
	if isak.has_move_input():
		return RUN
	return IDLE
