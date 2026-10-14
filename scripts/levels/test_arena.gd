## Escena de prueba de movimiento: suelo, dos plataformas y un hueco.
## Solo para jugar y ajustar valores; no es un nivel del juego.
extends Node2D

## Desbloquea el pulso al cargar esta escena (en tiempo de ejecucion; el valor
## por defecto de GameState sigue bloqueado).
@export var unlock_pulse: bool = true
## Si Isak cae por debajo de esta Y vuelve al punto de inicio.
@export var fall_limit_y: float = 480.0

var _spawn_position: Vector2

@onready var _isak: Isak = $Isak


func _ready() -> void:
	_spawn_position = _isak.global_position
	if unlock_pulse:
		GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)


func _physics_process(_delta: float) -> void:
	if _isak.global_position.y > fall_limit_y:
		_isak.global_position = _spawn_position
		_isak.velocity = Vector2.ZERO
