# Bot del hub «Actualización del sistema» (paso 8 de docs/propuesta-hub-mundos-4-6.md
# §2.7 y §5.2, 2026-10-27): lanza tools/play_hub_update_bot.gd (logica en
# tools/hub_update_bot.gd) en procesos aparte (--headless --fixed-fps 60; unos
# 3-4 s de pared cada uno) desde un guardado tras vencer a La Curadora, con el
# Isak real y solo acciones del Input Map:
# - ideal: cierra las lineas de Calc y de Eco, resuelve V1-V3, instala, guarda
#   en Notas y abre M4 («Próximamente»); M5 y M6 bloqueadas («Sin descargar»);
# - quieto: en la pagina 2 no resuelve nada (y sale la pista de Eco de los 90 s);
# - sin guardar: instala, entra al 1-1 sin guardar y game over: el upgrade se
#   pierde y el acertijo vuelve a 0/3;
# - Kernel y Raiz con el upgrade conservado: 3 paginas sin acertijo.
# El bot usa user://bot_save.json.
extends GutTest

const PLAYER: String = "res://tools/play_hub_update_bot.gd"


func _run_bot(profile: String, lap: int = 1) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--profile", profile, "--lap", str(lap)]
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_hub_update_bot"), 0))}


func _assert_ok(r: Dictionary, label: String) -> void:
	assert_eq(int(r["code"]), 0, "%s termina con 0:\n%s" % [label, r["summary"]])
	assert_string_contains(r["text"], label + ": OK")
	assert_false(String(r["text"]).contains("FALLO"), "Sin fallos:\n%s" % r["summary"])


func test_ideal_solves_installs_saves_and_opens_world_4() -> void:
	var r: Dictionary = _run_bot("ideal")
	_assert_ok(r, "play_hub_update_bot (Caché, ideal)")
	assert_string_contains(r["text"], "Calc: «Actualización detectada.")
	assert_string_contains(r["text"], "Eco: «¿Una actualización?")
	for check: String in ["V1 encendida", "V2 encendida", "V3 encendida"]:
		assert_string_contains(r["text"], check)
	assert_string_contains(r["text"], "instalacion vista: barra y destello")
	assert_string_contains(r["text"], "guardado en Notas con el upgrade")
	assert_string_contains(r["text"], "M4 disponible: Mundo 4 - El Chat")
	assert_string_contains(r["text"], "4-1 Chats recientes - Nuevo")
	assert_string_contains(r["text"], "m5 bloqueada: «Sin descargar»")
	assert_string_contains(r["text"], "m6 bloqueada: «Sin descargar»")
	assert_string_contains(r["text"], "ACCIONES:")


func test_standing_still_does_not_solve() -> void:
	var r: Dictionary = _run_bot("idle")
	_assert_ok(r, "play_hub_update_bot (Caché, idle)")
	assert_string_contains(r["text"], "quieto no resuelve: 0/3")


func test_game_over_without_saving_loses_the_upgrade_and_repeats_the_puzzle() -> void:
	var r: Dictionary = _run_bot("nosave")
	_assert_ok(r, "play_hub_update_bot (Caché, nosave)")
	assert_string_contains(r["text"], "game over sin guardar: upgrade perdido, pagina 2 «en instalacion»")
	assert_string_contains(r["text"], "el acertijo se repite: pagina 2 en 0/3")


func test_kernel_keeps_the_upgrade_without_the_puzzle() -> void:
	var r: Dictionary = _run_bot("kept", 2)
	_assert_ok(r, "play_hub_update_bot (Kernel, kept)")
	assert_string_contains(r["text"], "Kernel: 3 paginas, sin acertijo")


func test_raiz_keeps_the_upgrade_without_the_puzzle() -> void:
	var r: Dictionary = _run_bot("kept", 3)
	_assert_ok(r, "play_hub_update_bot (Raíz, kept)")
	assert_string_contains(r["text"], "Raíz: 3 paginas, sin acertijo")
