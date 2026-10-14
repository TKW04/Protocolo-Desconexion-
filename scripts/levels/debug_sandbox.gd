## Escena de prueba del Debug Mode (no es un nivel del juego). Tiles de 64 px,
## suelo en y = 640, resolucion 1280x720.
## - Camino de plataformas ocultas (tipo `h`) para subir a una repisa con un
##   punto de atencion: solo se ve y se pisa con el Debug activo (mantener K /
##   mando Y para activar, pulsar de nuevo para desactivar).
## - Plataforma movil y pelota que botan con el tiempo del mundo (se ve la
##   ralentizacion x0,5 mientras Isak va a velocidad normal).
## - Puntos de atencion de prueba (+1 punto, +10 de energia cada uno).
## Es la UNICA escena que desbloquea el Debug (C2: en el 1-1, en la arena y en
## el estado global por defecto sigue bloqueado). Al salir restaura el estado
## anterior de la habilidad y apaga el Debug. Empieza con energia 100.
extends Node2D

## Si Isak cae por debajo de esta Y vuelve al punto de inicio.
@export var fall_limit_y: float = 960.0
## Mundo cuyo color de Debug se usa (1 = cian).
@export var world: int = 1

var _spawn_position: Vector2
var _debug_was_unlocked: bool = false
var _pulse_was_unlocked: bool = false

@onready var _isak: Isak = $Isak


func _ready() -> void:
	_spawn_position = _isak.global_position
	_debug_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.current_world = world
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _exit_tree() -> void:
	DebugMode.reset()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was_unlocked)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)


func _physics_process(_delta: float) -> void:
	if _isak.global_position.y > fall_limit_y:
		_isak.global_position = _spawn_position
		_isak.velocity = Vector2.ZERO
