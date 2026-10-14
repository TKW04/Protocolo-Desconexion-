## Intenciones de control de Isak, independientes del dispositivo.
## Esta clase base no lee nada: las pruebas la usan como entrada falsa
## escribiendo los campos a mano. ActionPlayerInput lee el Input Map y un
## futuro control tactil sera otra subclase.
class_name PlayerInput
extends RefCounted

## Eje horizontal en [-1, 1]. Negativo = izquierda.
var move_axis: float = 0.0
## Salto pulsado en este cuadro (flanco).
var jump_pressed: bool = false
## Salto mantenido.
var jump_held: bool = false
## Correr mantenido.
var run_held: bool = false
## Pulso pulsado en este cuadro (flanco).
var pulse_pressed: bool = false


## Actualiza las intenciones. Se llama una vez por paso de fisica.
func poll() -> void:
	pass


## Borra los flancos (uso tipico: entrada falsa tras cada paso de prueba).
func clear_just_pressed() -> void:
	jump_pressed = false
	pulse_pressed = false


## Verdadero si hay cualquier intencion activa (corta la animacion de terminal).
func has_any_intent() -> bool:
	return not is_zero_approx(move_axis) or jump_pressed or jump_held or run_held or pulse_pressed
