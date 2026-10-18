# Laser 5 (perfora, tanda M2 de las mejoras de Calc): el acertijo «Correo
# certificado» (correo_test) funciona IGUAL con el laser que atraviesa enemigos:
# el lector y el anuncio paran el haz (no son enemigos). Repite todas las pruebas
# de tests/test_correo_test_level.gd con laser_pierce encendido.
extends "res://tests/test_correo_test_level.gd"


func _load() -> void:
	await super._load()
	_isak.abilities.laser_pierce = 1.0


func test_pierce_is_on_in_this_room() -> void:
	assert_almost_eq(_isak.abilities.laser_pierce, 1.0, 0.001, "Laser que perfora encendido")
