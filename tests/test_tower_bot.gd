# Bot vertical del 1-2 (paso 15 de docs/propuesta-1-2.md, 2026-10-18): lanza
# tools/play_tower_bot.gd en un proceso aparte (--headless --fixed-fps 60, como
# el bot del 1-1; unos 20-30 s de pared por caso, la mitad exportando el camino
# con el validador) y comprueba que completa el 1-2 real siguiendo el camino
# exportado: Calc conocida (camino directo) y Calc desconocida (azotea completa
# y escena de Calc en el hub). El bot usa su propio guardado (user://bot_save.json).
extends GutTest

const PLAYER: String = "res://tools/play_tower_bot.gd"


func _run_bot(case_name: String) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--case", case_name]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	return {"code": code, "text": "".join(output)}


func _check(result: Dictionary, label: String) -> void:
	var text: String = result["text"]
	var summary: String = text.substr(maxi(text.find("play_tower_bot"), 0))
	assert_eq(int(result["code"]), 0, "El bot del 1-2 (%s) termina con 0:\n%s" % [label, summary])
	assert_string_contains(text, "play_tower_bot (%s): OK" % label)
	assert_string_contains(text, "RESULTADO: recorrido")
	assert_false(text.contains("FALLO"), "Sin fallos (%s)" % label)


func test_tower_bot_calc_known() -> void:
	var result: Dictionary = _run_bot("known")
	_check(result, "Calc conocida")
	assert_string_contains(result["text"], "sin escena (correcto)")


func test_tower_bot_calc_unknown() -> void:
	var result: Dictionary = _run_bot("unknown")
	_check(result, "Calc desconocida")
	var text: String = result["text"]
	for piece: String in ["pared con glitch disuelta", "interruptor_luz (3 de 3)", "laser a interruptor_laser",
			"panel_oculto (1 de 1)", "Calc teletransportada; terminal con corriente true",
			"terminal de la azotea activada", "allies_met['calc'] = true"]:
		assert_string_contains(text, piece)
