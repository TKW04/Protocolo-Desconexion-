# Bot del 1-3 «No molestar» (paso 11 de docs/propuesta-1-3.md, 2026-10-20): lanza
# tools/play_dnd_bot.gd en un proceso aparte (--headless --fixed-fps 60, como los
# bots del 1-1 y del 1-2; unos 2 min de pared, 40 s de ellos exportando el camino
# con el validador) y comprueba que completa el 1-3 real siguiendo el camino
# exportado: interruptor «No molestar» (da el dash), los dashes del camino
# (banner obligatorio, ola, tunel y cierre), los compases (wait_beat) y la terminal
# «Deslizar para desbloquear», de vuelta al hub, SIN golpes (desde el 2026-10-20 el
# camino usa el arco real y validation.hazard_margin_s). El bot usa user://bot_save.json.
extends GutTest

const PLAYER: String = "res://tools/play_dnd_bot.gd"


func test_dnd_bot_completes_level_1_3() -> void:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	var summary: String = text.substr(maxi(text.find("play_dnd_bot"), 0))
	assert_eq(code, 0, "El bot del 1-3 termina con 0:\n%s" % summary)
	assert_string_contains(text, "play_dnd_bot (1-3): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % summary)
	for piece: String in ["interruptor dnd_1_3 encendido con el pulso de espaldas: dash obtenido true",
			"dashes 9 (camino 9)", "activada con el pulso (Cierre", "hub cargado tras completar el 1-3",
			"RESULTADO: recorrido", "golpes 0, muertes 0"]:
		assert_string_contains(text, piece)
