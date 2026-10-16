# Ayuda de pruebas (encuentro con Eco del 1-1, 2026-10-16): desde el encuentro
# el 1-1 empieza SIN pulso y Eco es desconocido hasta las columnas 10-12. Las
# pruebas que juegan mas alla del encuentro (receptores, Burbujas, pop-ups,
# terminal) empiezan como una partida que ya paso por el: Eco conocido y el
# pulso obtenido (y su aviso visto), sin marcar «sin guardar». Llamar ANTES de
# cargar el nivel (GeneratedLevel aplica abilities_available al entrar; el pulso
# obtenido no se bloquea). No empieza por "test_", asi que GUT no lo ejecuta.
extends RefCounted


## Eco conocido y pulso obtenido para siempre (como tras el encuentro).
static func meet_eco_with_pulse() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.obtained_abilities[GameState.ABILITY_PULSE] = true
	GameState.seen_notices[GameState.ABILITY_PULSE] = true
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)


## Notas conocida (como tras su presentacion en el primer hub, 2026-10-16): el
## hub abre con Notas encendida y sin presentacion. Llamar ANTES de instanciar
## el hub.
static func meet_notas() -> void:
	GameState.meet_ally(GameState.ALLY_NOTAS)


## Calc conocida: su estacion del hub esta encendida y vende (hasta que exista
## el encuentro del final del 1-2, es la forma de activarla en las pruebas).
static func meet_calc() -> void:
	GameState.meet_ally(GameState.ALLY_CALC)


## Debug obtenido para siempre (como tras el final del 1-2, que aun no existe;
## paso 14: abre la pared con glitch del secreto D del 1-1). Llamar ANTES de
## cargar el nivel: el 1-1 tiene abilities_available.debug false, pero una
## habilidad obtenida no se bloquea. Sin marcar «sin guardar».
static func obtain_debug() -> void:
	GameState.obtained_abilities[GameState.ABILITY_DEBUG] = true
	GameState.seen_notices[GameState.ABILITY_DEBUG] = true
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
