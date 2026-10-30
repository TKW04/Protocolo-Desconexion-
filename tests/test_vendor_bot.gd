# Bot del jefe El Vendedor (paso 19 de docs/propuesta-mundo-5.md §8, 2026-10-29):
# lanza tools/play_boss_bot.gd -- --boss vendor (logica en tools/vendor_bot.gd) en
# procesos aparte (--headless --fixed-fps 60) y comprueba la pelea real en la arena
# 5-boss con el Isak real y solo acciones del Input Map, en los tres accesos (Caché,
# Kernel y Raíz por GameState.lap: El Vendedor lee laps.<n> de su JSON):
# - ideal: vence sin morir (fase 1: paga la buena con un pulso desde el estante,
#   sube al techo y baja por detras con el Debug ya cargando; fase 2: abre el ticket
#   con el pulso y cruza la bandeja comprimido; fase 3: Filo por la ranura y, detras,
#   pulso + laser contra el tiron); en Caché tarda entre 100 y 160 s;
# - torpe (validation_model de data/bosses/vendor.json): vence sin morir y sin que el
#   Debug se corte por falta de energia en una ventana;
# - quieto: pierde (game over) sin vencer.
# Al vencer: recompensa de la capa del acceso (boss_w5_l<n>) sin guardar, vuelta al
# hub con 5-boss completado y el Mundo 6 disponible (y, en Caché, la quinta pieza
# encendida, el fondo completo y las cinco ranuras del candado de M6). El bot usa
# user://bot_save.json (los procesos van en serie).
extends GutTest

const PLAYER: String = "res://tools/play_boss_bot.gd"
const ACCESS: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}


func _run_bot(profile: String, lap: int) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--boss", "vendor", "--profile", profile, "--lap", str(lap)]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_boss_bot"), 0))}


func _assert_victory(profile: String, lap: int) -> void:
	var r: Dictionary = _run_bot(profile, lap)
	var label: String = "play_boss_bot vendor (%s, %s)" % [ACCESS[lap], profile]
	assert_eq(int(r["code"]), 0, "%s termina con 0:\n%s" % [label, r["summary"]])
	assert_string_contains(r["text"], label + ": OK")
	assert_false(String(r["text"]).contains("FALLO"), "Sin fallos:\n%s" % r["summary"])
	var hub: String = "hub tras la pelea: 5-boss completado si, recuerdo boss_w5_l%d sin guardar si, Mundo 6 disponible si" % lap
	assert_string_contains(r["text"], hub)
	if lap == 1:
		assert_string_contains(r["text"], "quinta pieza encendida si, fondo completo si, cinco ranuras del candado si")
	assert_string_contains(r["text"], "muertes 0")
	assert_string_contains(r["text"], "Debug cortado en ventana 0")
	assert_string_contains(r["text"], "golpe final")
	if profile == "ideal":
		assert_string_contains(r["text"], "golpes 0, muertes 0, congelaciones 0")


func test_ideal_wins_in_cache_without_hits_in_100_to_160_s() -> void:
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


## Negativo: quedarse quieto pierde (game over) sin vencer a El Vendedor.
func test_standing_still_loses() -> void:
	var r: Dictionary = _run_bot("idle", 1)
	assert_eq(int(r["code"]), 0, "El quieto termina con 0 (pierde):\n%s" % r["summary"])
	assert_string_contains(r["text"], "play_boss_bot vendor (Caché, idle): OK")
	assert_string_contains(r["text"], "quieto pierde")
	assert_false(String(r["text"]).contains("golpe final"), "Quieto no vence:\n%s" % r["summary"])
