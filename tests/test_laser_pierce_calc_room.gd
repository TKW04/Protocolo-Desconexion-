# Laser 5 (perfora, tanda M2 de las mejoras de Calc): el acertijo de Calc
# (calc_test: interruptor laser lejano, interruptores, panel oculto, puerta)
# funciona IGUAL con el laser que atraviesa enemigos: los interruptores paran el
# haz (no son enemigos). Repite todas las pruebas de tests/test_calc_room.gd con
# laser_pierce encendido.
extends "res://tests/test_calc_room.gd"


func _load() -> void:
	await super._load()
	_isak.abilities.laser_pierce = 1.0


func test_pierce_is_on_in_this_room() -> void:
	await _load()
	assert_almost_eq(_isak.abilities.laser_pierce, 1.0, 0.001, "Laser que perfora encendido")
