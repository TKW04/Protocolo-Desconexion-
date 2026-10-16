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
