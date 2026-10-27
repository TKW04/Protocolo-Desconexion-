# Bot de la galeria (paso 11 de docs/propuesta-mundo-3.md, 2026-10-27): lanza tools/play_gallery_bot.gd en un
# proceso aparte (--headless --fixed-fps 60, como los bots del 1-3 y del feed; unos 15 s de pared en el 3-1 con la
# exportacion del camino) y comprueba que completa el 3-1 «Galería de perfil» real siguiendo el camino exportado
# (corazones, plataformas de likes ♥5 / ♥10 / ♥15, columnas-marco ante el Influencer, el Ladron aturdido antes del
# contacto, el espejo con las plataformas del reflejo y la terminal «Publicar») y vuelve al hub con el nivel
# completado, sin morir, sin golpes y sin robos. Tambien las salas recorte_test (Recortar, pinch / unpinch) y
# reflejo_test (laser por espejo, pulso reflejado por el espejo cazador, placas y puertas de marco con el Reflejo
# falso), para los pasos que el 3-1 no usa. Desde el paso 12 (2026-10-27), tambien el 3-2 «Sin filtro» real, que
# obtiene Pellizcar en «Recortar». Cada caso usa su propio guardado (ISAK_SAVE_PATH).
extends GutTest

const PLAYER: String = "res://tools/play_gallery_bot.gd"


func _play(level: String, extra: PackedStringArray = []) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--level", level]
	args.append_array(extra)
	var output: Array = []
	var previous: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	OS.set_environment(GameState.SAVE_PATH_ENV, "user://gallery_bot_test_%s.json" % level)
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	if previous.is_empty():
		OS.unset_environment(GameState.SAVE_PATH_ENV)
	else:
		OS.set_environment(GameState.SAVE_PATH_ENV, previous)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_gallery_bot"), 0))}


func test_gallery_bot_completes_level_3_1() -> void:
	var run: Dictionary = _play("3-1")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot del 3-1 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_gallery_bot (3-1): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 3-1", "RESULTADO: recorrido", "golpes 0, muertes 0",
			"GALERIA: muertes 0, golpes 0, robos 0 (0 likes), corazones cogidos 18", "likes_5 ", "likes_10 ", "likes_15 ",
			"hub: llegada tras el 3-1 (3-1 completado true; likes 0)"]:
		assert_string_contains(text, piece)


## Paso 12 (2026-10-27): el 3-2 «Sin filtro» real con el progreso de quien acaba de completar el 3-1 (sin
## Pellizcar): «Recortar» con el pulso de espaldas, los marcos pequenos del Estudio, del Recorte y de entre filtros
## (pinch / unpinch), el Debug en los tres filtros, el Ladron aturdido antes de la ♥10 y la terminal «Publicar sin
## filtro»; vuelve al hub con el 3-2 completado y Pellizcar obtenido.
func test_gallery_bot_completes_level_3_2_and_obtains_compress() -> void:
	var run: Dictionary = _play("3-2")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot del 3-2 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_gallery_bot (3-2): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["linea importante (Eco): «Te queda mejor así.»", "Pellizcar obtenido true",
			"hub cargado tras completar el 3-2", "golpes 0, muertes 0", "GALERIA: muertes 0, golpes 0, robos 0 (0 likes)",
			"pellizcos 4 / vueltas 4", "likes_10 ", "hub: llegada tras el 3-2 (3-2 completado true; likes 0)"]:
		assert_string_contains(text, piece)


func test_gallery_bot_pinches_in_the_crop_room() -> void:
	var run: Dictionary = _play("recorte_test")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot de recorte_test termina con 0:\n%s" % run["summary"])
	for piece: String in ["linea importante (Eco): «Te queda mejor así.»", "Pellizcar obtenido true",
			"pellizcos 2 / vueltas 2", "golpes 0, muertes 0"]:
		assert_string_contains(text, piece)


func test_gallery_bot_uses_the_hunter_mirror_and_the_frame_doors() -> void:
	var run: Dictionary = _play("reflejo_test")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot de reflejo_test termina con 0:\n%s" % run["summary"])
	for piece: String in ["laser a lector_techo", "pulso reflejado por cazador (mira al e) a receptor_cazador",
			"hub cargado tras completar el reflejo_test", "golpes 0, muertes 0"]:
		assert_string_contains(text, piece)


func test_gallery_bot_rejects_unknown_level() -> void:
	var run: Dictionary = _play("9-9", ["--path", "/dev/null"])
	assert_eq(run["code"], 1, "un nivel que no es del Mundo 3 falla")
	assert_string_contains(run["text"], "nivel desconocido: 9-9")
	var run2: Dictionary = _play("2-1", ["--path", "/dev/null"])
	assert_eq(run2["code"], 1, "un nivel del feed no es de la galeria")
