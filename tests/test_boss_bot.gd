# Bot del jefe Alerta Mayor (paso 14 de docs/propuesta-jefe-alerta-mayor.md §6,
# 2026-10-21): lanza tools/play_boss_bot.gd en procesos aparte (--headless
# --fixed-fps 60, como los bots del 1-1 al 1-3; unos 3-10 s de pared cada uno) y
# comprueba la pelea real en la arena 1-boss con el Isak real y solo acciones del
# Input Map, en los tres accesos (Caché, Kernel y Raíz por GameState.lap: el jefe
# lee laps.<n> de su JSON):
# - ideal: vence sin morir y sin golpes (Debug -> pulso -> laser con la marca,
#   dash contra barridos y lanzamientos, cambio de carril ante las rafagas);
# - torpe (validation_model del JSON del jefe): vence sin morir y sin que el
#   Debug se corte por falta de energia en una ventana;
# - quieto: pierde (game over) sin vencer.
# Al vencer: recompensa de la capa del acceso sin guardar, vuelta al hub con
# 1-boss completado y el Mundo 2 desbloqueado (y la pieza cian en Caché). El bot
# usa user://bot_save.json.
extends GutTest

const PLAYER: String = "res://tools/play_boss_bot.gd"
const ACCESS: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}


func _run_bot(profile: String, lap: int) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--profile", profile, "--lap", str(lap)]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_boss_bot"), 0))}


func _assert_victory(profile: String, lap: int) -> void:
	var r: Dictionary = _run_bot(profile, lap)
	var label: String = "play_boss_bot (%s, %s)" % [ACCESS[lap], profile]
	assert_eq(int(r["code"]), 0, "%s termina con 0:\n%s" % [label, r["summary"]])
	assert_string_contains(r["text"], label + ": OK")
	assert_false(String(r["text"]).contains("FALLO"), "Sin fallos:\n%s" % r["summary"])
	var hub: String = "hub tras la pelea: 1-boss completado si, recuerdo boss_w1_l%d sin guardar si, Mundo 2 desbloqueado si" % lap
	assert_string_contains(r["text"], hub)
	if lap == 1:
		assert_string_contains(r["text"], "pieza cian encendida si")
	assert_string_contains(r["text"], "muertes 0")
	assert_string_contains(r["text"], "Debug cortado en ventana 0")
	if profile == "ideal":
		assert_string_contains(r["text"], "golpes 0, muertes 0")


func test_ideal_wins_in_cache_without_dying_or_hits() -> void:
	_assert_victory("ideal", 1)


func test_ideal_wins_in_kernel() -> void:
	_assert_victory("ideal", 2)


func test_ideal_wins_in_raiz() -> void:
	_assert_victory("ideal", 3)


func test_clumsy_wins_in_cache_without_running_dry_in_a_window() -> void:
	_assert_victory("clumsy", 1)


func test_clumsy_wins_in_kernel() -> void:
	_assert_victory("clumsy", 2)


func test_clumsy_wins_in_raiz() -> void:
	_assert_victory("clumsy", 3)


## Negativo: quedarse quieto pierde (game over) sin vencer al jefe.
func test_standing_still_loses() -> void:
	var r: Dictionary = _run_bot("idle", 1)
	assert_eq(int(r["code"]), 0, "El quieto termina con 0 (pierde):\n%s" % r["summary"])
	assert_string_contains(r["text"], "play_boss_bot (Caché, idle): OK")
	assert_string_contains(r["text"], "quieto pierde")
	assert_false(String(r["text"]).contains("golpe final"), "Quieto no vence:\n%s" % r["summary"])
