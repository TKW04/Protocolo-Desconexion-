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
## Laser pulsado en este cuadro (flanco).
var laser_pressed: bool = false
## Ocultarte pulsado en este cuadro (flanco; accion hide, Pulso 4).
var hide_pressed: bool = false
## Dash pulsado en este cuadro (flanco; gesto Deslizar, accion gesture_swipe).
var dash_pressed: bool = false
## Pellizcar pulsado en este cuadro (flanco; accion gesture_pinch, 2026-10-26).
var pinch_pressed: bool = false
## Agitar pulsado en este cuadro (flanco; accion gesture_shake, 2026-10-28).
var shake_pressed: bool = false
## Gesto Mantener presionado mantenido (golpe al suelo; 2026-10-22: los eventos
## de move_down —S / flecha abajo / abajo del mando— o los de gesture_hold).
var hold_held: bool = false


## Actualiza las intenciones. Se llama una vez por paso de fisica.
func poll() -> void:
	pass


## Borra los flancos (uso tipico: entrada falsa tras cada paso de prueba).
func clear_just_pressed() -> void:
	jump_pressed = false
	pulse_pressed = false
	laser_pressed = false
	hide_pressed = false
	dash_pressed = false
	pinch_pressed = false
	shake_pressed = false


## Verdadero si hay cualquier intencion activa (corta la animacion de terminal).
func has_any_intent() -> bool:
	return not is_zero_approx(move_axis) or jump_pressed or jump_held or run_held or pulse_pressed or laser_pressed or hide_pressed or dash_pressed \
			or hold_held or pinch_pressed or shake_pressed
