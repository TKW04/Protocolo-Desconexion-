# Bot del feed en el 2-1 «Para ti» (paso 12 de docs/propuesta-mundo-2.md, 2026-10-23):
# lanza tools/play_feed_bot.gd en un proceso aparte (--headless --fixed-fps 60, como
# los bots del 1-2 y del 1-3; unos 40 s de pared, 30 de ellos exportando el camino
# con el validador) y comprueba que completa el 2-1 real siguiendo el camino
# exportado: esperas del scroll (wait_scroll), fase de los videos en autoplay
# (wait_phase con clip_cycle_s), el bucle con su salida por el Debug, el dash entre
# las frágiles, la cuenta automatica de 3 s de la terminal y la vuelta al hub, SIN
# tocar el borde del scroll, sin morir, sin golpes y sin repetir el bucle. El bot usa
# user://bot_save.json.
extends GutTest

const PLAYER: String = "res://tools/play_feed_bot.gd"


func test_feed_bot_completes_level_2_1() -> void:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--level", "2-1"]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	var summary: String = text.substr(maxi(text.find("play_feed_bot"), 0))
	assert_eq(code, 0, "El bot del 2-1 termina con 0:\n%s" % summary)
	assert_string_contains(text, "play_feed_bot (2-1): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % summary)
	for piece: String in ["terminal terminal_siguiente_video: cuenta empezada y terminada",
			"hub cargado tras completar el 2-1", "RESULTADO: recorrido", "golpes 0, muertes 0",
			"contactos con el borde 0, muertes 0, repeticiones de bucle 0", "dashes 1",
			"hub: llegada tras el 2-1 (2-1 completado true)"]:
		assert_string_contains(text, piece)


func test_feed_bot_rejects_unknown_level() -> void:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--level", "9-9", "--path", "/dev/null"]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	assert_eq(code, 1, "un nivel que no es del feed falla")
	assert_string_contains("".join(output), "nivel desconocido: 9-9")
