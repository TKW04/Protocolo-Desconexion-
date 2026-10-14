## Tiempo del mundo: la ralentizacion del Debug Mode sin Engine.time_scale.
##
## El Debug ralentiza el MUNDO (enemigos, plataformas moviles, proyectiles,
## efectos del nivel) pero no a Isak ni a la UI, asi que no se usa
## Engine.time_scale (afectaria a todo). En su lugar GameState guarda un
## factor propio, `world_time_scale` (1 = normal, 0,5 = Debug), que avisa con
## EventBus.world_time_scale_changed.
##
## Como lo consume un objeto del mundo (enemigos futuros incluidos):
## - Movimiento y temporizadores: usa `WorldTime.scaled_delta(delta)` en lugar
##   de `delta` en _physics_process/_process:
##       func _physics_process(delta: float) -> void:
##           var dt: float = WorldTime.scaled_delta(delta)
##           position.x += speed * dt
##           _attack_timer -= dt
## - Velocidades que se pasan al motor (CharacterBody2D.velocity con
##   move_and_slide, que usa el delta real): multiplica la velocidad por
##   `WorldTime.scale()` al mover y no la guardes escalada.
## - AnimatedSprite2D / AnimationPlayer: `speed_scale = WorldTime.scale()`
##   (o conecta EventBus.world_time_scale_changed).
## - Tweens del mundo: `tween.set_speed_scale(WorldTime.scale())`.
## - Telegrafos de ataques (6-12 cuadros): cuentalos en tiempo escalado, asi
##   tambien se alargan con el Debug.
## Isak y el HUD usan siempre el delta real.
class_name WorldTime
extends RefCounted

## Escala de tiempo del mundo sin Debug.
const NORMAL_SCALE: float = 1.0


## Factor actual (1 = normal). Lo fija DebugMode a traves de GameState.
static func scale() -> float:
	return GameState.world_time_scale


## Delta del mundo: el delta real por la escala actual.
static func scaled_delta(real_delta: float) -> float:
	return real_delta * GameState.world_time_scale
