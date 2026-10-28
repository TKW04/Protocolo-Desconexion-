# Bot del chat (paso 12 de docs/propuesta-mundo-4.md, 2026-10-28): lanza tools/play_chat_bot.gd en un proceso
# aparte (--headless --fixed-fps 60, como los bots de los Mundos 2 y 3) y comprueba que completa el 4-1 «Chats
# recientes» real siguiendo el camino exportado (la Linterna al pasar, las burbujas, las cuatro «escribiendo…» del
# Modo oscuro, el Troll del escalon del Piso 3 aturdido con el pulso, los dos pulsos al doble check y las cuatro esperas de las
# zonas «Visto» con ciclo, y la terminal «Enviar»), vuelve al hub con el nivel completado, sin morir ni
# congelarse, y con la duracion de juego entre el 40 y el 55 % del objetivo (§4). Desde el paso 13 tambien el
# 4-2 «Grupo sin respuesta» (obtiene Agitar en el «¿Deshacer escritura?», deshace el muro de texto, aturde los
# grupos de Trolls y las tandas de Stickers con Agitar, pulsa a los Fantasmas y cruza las zonas «Visto»). Usa su
# propio guardado (ISAK_SAVE_PATH).
extends GutTest

const PLAYER: String = "res://tools/play_chat_bot.gd"


func _play(level: String, extra: PackedStringArray = []) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--level", level]
	args.append_array(extra)
	var output: Array = []
	var previous: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	OS.set_environment(GameState.SAVE_PATH_ENV, "user://chat_bot_test_%s.json" % level)
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	if previous.is_empty():
		OS.unset_environment(GameState.SAVE_PATH_ENV)
	else:
		OS.set_environment(GameState.SAVE_PATH_ENV, previous)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_chat_bot"), 0))}


func test_chat_bot_completes_level_4_1() -> void:
	var run: Dictionary = _play("4-1")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot del 4-1 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_chat_bot (4-1): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 4-1", "RESULTADO: recorrido", "muertes 0",
			"CHAT: muertes 0", "congelaciones 0", "pulsos al doble check 2", "esperas de «escribiendo…» 4",
			"esperas de zonas con ciclo 4", "pulsos al Troll 1", "Agitar 0", "Linterna conocida",
			"pulso a troll troll_1: stunned", "hub: carpeta M4"]:
		assert_string_contains(text, piece)


func test_chat_bot_completes_level_4_2_and_obtains_shockwave() -> void:
	var run: Dictionary = _play("4-2")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot del 4-2 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_chat_bot (4-2): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["linea importante (Papelera)", "«No necesitas a nadie más.»", "Agitar: U / LB (mando)",
			"interruptor deshacer_4_2 encendido", "hub cargado tras completar el 4-2", "CHAT: muertes 0",
			"congelaciones 0", "pulsos al doble check 2", "esperas de «escribiendo…» 3", "esperas de zonas con ciclo 4",
			"Linterna conocida", "Fantasma fantasma_pasillo: stunned", "hub: carpeta M4"]:
		assert_string_contains(text, piece)
	assert_false(text.contains("Agitar NO SALE"), "Cada Agitar del camino sale")
	assert_false(text.contains("SIN ATURDIR"), "Cada Fantasma que se activa queda aturdido")


func test_chat_bot_rejects_levels_of_other_worlds() -> void:
	var run: Dictionary = _play("9-9", ["--path", "/dev/null"])
	assert_eq(run["code"], 1, "un nivel desconocido falla")
	assert_string_contains(run["text"], "nivel desconocido: 9-9")
	var run2: Dictionary = _play("3-1", ["--path", "/dev/null"])
	assert_eq(run2["code"], 1, "un nivel de la galeria no es del chat")
