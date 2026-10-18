# Laser 5 (perfora, tanda M2 de las mejoras de Calc): los recordatorios y el boton
# «Posponer» (recordatorios_test) funcionan IGUAL con el laser que atraviesa
# enemigos: el Posponer para el haz (no es un enemigo). Repite todas las pruebas
# de tests/test_reminder_snooze.gd con laser_pierce encendido.
extends "res://tests/test_reminder_snooze.gd"


func before_each() -> void:
	await super.before_each()
	_isak.abilities.laser_pierce = 1.0


func test_pierce_is_on_in_this_room() -> void:
	assert_almost_eq(_isak.abilities.laser_pierce, 1.0, 0.001, "Laser que perfora encendido")
