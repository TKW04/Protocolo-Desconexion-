# Bot del jefe Autoplay (paso 19 de docs/propuesta-mundo-2.md §8, 2026-10-23):
# lanza tools/play_boss_bot.gd -- --boss autoplay (logica en tools/autoplay_bot.gd)
# en procesos aparte (--headless --fixed-fps 60; unos 3-6 s de pared cada uno, el
# quieto unos 12 s) y comprueba la pelea real en la arena 2-boss con el Isak real
# y solo acciones del Input Map, en los tres accesos (Caché, Kernel y Raíz por
# GameState.lap: el jefe lee laps.<n> de su JSON):
# - ideal: vence sin morir y sin golpes (en la barra: Debug -> golpe al suelo
#   sobre el cabezal -> pausa -> laser; dash contra ola, barrido y proyectiles,
#   fuera de la columna de los rayos; sube por la cinta tras recargar);
# - torpe (validation_model de data/bosses/autoplay.json): vence sin morir y sin
#   que el Debug se corte por falta de energia en una ventana;
# - quieto: pierde (game over) sin vencer.
# Al vencer: recompensa de la capa del acceso (boss_w2_l<n>) sin guardar, vuelta
# al hub con 2-boss completado y el Mundo 3 desbloqueado: en Caché con el 3-1
# disponible (paso 10 del Mundo 3) y la pieza ambar encendida; en Kernel y Raíz,
# «Próximamente» (sin subniveles todavia). El bot usa user://bot_save.json.
extends GutTest

const PLAYER: String = "res://tools/play_boss_bot.gd"
const ACCESS: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}


func _run_bot(profile: String, lap: int) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--boss", "autoplay", "--profile", profile, "--lap", str(lap)]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_boss_bot"), 0))}


func _assert_victory(profile: String, lap: int) -> void:
	var r: Dictionary = _run_bot(profile, lap)
	var label: String = "play_boss_bot autoplay (%s, %s)" % [ACCESS[lap], profile]
	assert_eq(int(r["code"]), 0, "%s termina con 0:\n%s" % [label, r["summary"]])
	assert_string_contains(r["text"], label + ": OK")
	assert_false(String(r["text"]).contains("FALLO"), "Sin fallos:\n%s" % r["summary"])
	var m3: String = "Mundo 3 con el 3-1 disponible si" if lap == 1 else "Mundo 3 Próximamente si"
	var hub: String = "hub tras la pelea: 2-boss completado si, recuerdo boss_w2_l%d sin guardar si, Mundo 3 desbloqueado si, %s" % [lap, m3]
	assert_string_contains(r["text"], hub)
	if lap == 1:
		assert_string_contains(r["text"], "pieza ambar encendida si")
	assert_string_contains(r["text"], "muertes 0")
	assert_string_contains(r["text"], "Debug cortado en ventana 0")
	assert_string_contains(r["text"], "golpe final")
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
	assert_string_contains(r["text"], "play_boss_bot autoplay (Caché, idle): OK")
	assert_string_contains(r["text"], "quieto pierde")
	assert_false(String(r["text"]).contains("golpe final"), "Quieto no vence:\n%s" % r["summary"])
