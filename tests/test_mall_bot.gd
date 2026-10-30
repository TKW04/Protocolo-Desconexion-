# Bot de la tienda (paso 11 de docs/propuesta-mundo-5.md, 2026-10-29): lanza tools/play_mall_bot.gd en un proceso
# aparte (--headless --fixed-fps 60, como los bots de los Mundos 2-4) y comprueba que completa el 5-1 «Oferta del
# día» real siguiendo el camino exportado, en los dos perfiles: frugal (el camino largo, sin gastar nada, contra el
# tiron de las Ofertas, la Suscripcion del Tramo 3 cancelada con el pulso y derrotada con el laser, las cajas
# sorpresa por encima, la cuenta regresiva del foso y la puerta «Pagar»; duracion entre el 40 y el 55 % del
# objetivo) y comprador (`--buy`: compra la energia, paga el atajo con trampa y cancela su Suscripcion; el saldo
# nunca baja de 0 y lo gastado es lo del camino). Sin muertes, sin golpes ni «Añadido al carrito», y vuelve al hub
# con el nivel completado. Usa su propio guardado (ISAK_SAVE_PATH).
# Desde el paso 13 (2026-10-29), tambien el 5-2 «Prueba gratis»: obtiene la Combinacion en la «Prueba gratis» y hace
# las 5 Embestidas, los 4 Filos y los 3 Sismos del camino (frugal, en el 40-55 %; comprador: paga el atajo de Calc),
# y la sala combos_test.
# Desde el paso 14 (2026-10-29), tambien el 5-3 «Última oportunidad» con la Combinacion y 0 puntos de entrada: frugal
# (las cuentas regresivas, las siete cajas en cadena —las dos peligrosas, miradas con el Debug y destruidas con el
# laser—, las Suscripciones, «rechazar» con el laser, el Sismo y la lista de deseos sin «Añadido al carrito»; en el
# 40-55 %) y comprador (compra la energia y paga el atajo con su «Verificando pago…»: congelado 1,5 s y el golpe al
# liberarse, la unica congelacion y el unico golpe del camino).
extends GutTest

const PLAYER: String = "res://tools/play_mall_bot.gd"


func _play(level: String, extra: PackedStringArray = []) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PLAYER, "--", "--level", level]
	args.append_array(extra)
	var output: Array = []
	var previous: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	OS.set_environment(GameState.SAVE_PATH_ENV, "user://mall_bot_test_%s.json" % level)
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	if previous.is_empty():
		OS.unset_environment(GameState.SAVE_PATH_ENV)
	else:
		OS.set_environment(GameState.SAVE_PATH_ENV, previous)
	var text: String = "".join(output)
	return {"code": code, "text": text, "summary": text.substr(maxi(text.find("play_mall_bot"), 0))}


func test_mall_bot_completes_level_5_1_frugal() -> void:
	var run: Dictionary = _play("5-1")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot frugal del 5-1 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_mall_bot (5-1, frugal): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 5-1", "RESULTADO: recorrido", "golpes 0, muertes 0",
			"TIENDA (frugal): muertes 0, golpes 0, congelaciones 0, «Añadido al carrito» 0, compras []",
			"gastado 0", "drenado 0", "Suscripciones canceladas 4 / derrotadas 4",
			"laser a la Suscripcion suscripcion_t1: derrotada", "laser a la Suscripcion suscripcion_t3: derrotada",
			"cuentas regresivas: 3 tramo(s) andando partidos", "dash 5 (suelo)", "terminal de la azotea activada",
			"hub: carpeta M5"]:
		assert_string_contains(text, piece)
	assert_false(text.contains("SIN EFECTO"), "Cada pulso del camino hace efecto")
	# Mas peligro desde el 2026-10-30: la tentacion quita Sync, pero el frugal (que apaga las Ofertas con el pulso con
	# el Sync por debajo del 60 %) termina con al menos 20.
	var found := RegEx.create_from_string("Sync minimo (\\d+)").search(text)
	assert_not_null(found, "El bot anota el Sync minimo de la tentacion")
	if found != null:
		assert_gte(int(found.get_string(1)), 20, "Sync minimo de la tentacion >= 20")


func test_mall_bot_completes_level_5_1_buying() -> void:
	var run: Dictionary = _play("5-1", ["--profile", "comprador"])
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot comprador del 5-1 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_mall_bot (5-1, comprador): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 5-1", "TIENDA (comprador): muertes 0, golpes 0",
			"«Añadido al carrito» 0", "compras [tienda_energia (2)]", "gastado 5", "camino 5)", "drenado 0",
			"buy tienda_energia con el pulso de espaldas: hecho", "pay_door atajo_dos_plantas con el pulso de espaldas: hecho",
			"(minimo 0;", "hub: carpeta M5"]:
		assert_string_contains(text, piece)


func test_mall_bot_completes_level_5_2_frugal() -> void:
	var run: Dictionary = _play("5-2")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot frugal del 5-2 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_mall_bot (5-2, frugal): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["linea importante (Isak): «Esto no lo compré. Es mío.»", "hub cargado tras completar el 5-2",
			"golpes 0, muertes 0", "TIENDA (frugal): muertes 0, golpes 0, congelaciones 0, «Añadido al carrito» 0",
			"gastado 0", "drenado 0", "Suscripciones canceladas 3 / derrotadas 3",
			"COMBOS: Combinacion true; Embestidas 5 (camino 5), Filos 4 (camino 4), Sismos 3 (camino 3); denegados []",
			"caja caja_puntos_t1 abierta con el pulso: hecho", "terminal de la azotea activada", "hub: carpeta M5"]:
		assert_string_contains(text, piece)
	assert_false(text.contains("SIN EFECTO"), "Cada pulso del camino hace efecto")
	assert_false(text.contains("siguen en pie"), "Cada combo rompe lo suyo")


func test_mall_bot_completes_level_5_2_buying() -> void:
	var run: Dictionary = _play("5-2", ["--profile", "comprador"])
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot comprador del 5-2 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_mall_bot (5-2, comprador): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 5-2", "TIENDA (comprador): muertes 0, golpes 0",
			"gastado 2", "camino 2)", "drenado 0", "pared con glitch disuelta con el Debug",
			"pay_door caja_calc con el pulso de espaldas: hecho", "(minimo 0;", "hub: carpeta M5"]:
		assert_string_contains(text, piece)


func test_mall_bot_completes_level_5_3_frugal() -> void:
	var run: Dictionary = _play("5-3")
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot frugal del 5-3 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_mall_bot (5-3, frugal): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 5-3", "golpes 0, muertes 0",
			"TIENDA (frugal): muertes 0, golpes 0, congelaciones 0, «Añadido al carrito» 0, compras []",
			"gastado 0", "drenado 0", "Suscripciones canceladas 2 / derrotadas 2", "«rechazar» [terminos_t3]",
			"saldo 0 -> 10", "caja caja_g1_3 abierta con el laser: hecho", "caja caja_g2_2 abierta con el laser: hecho",
			"caja caja_g3_1 abierta con el pulso: hecho", "Sismos 1 (camino 1)", "hub: carpeta M5"]:
		assert_string_contains(text, piece)
	assert_false(text.contains("SIN EFECTO"), "Cada pulso y laser del camino hace efecto")


func test_mall_bot_completes_level_5_3_buying() -> void:
	var run: Dictionary = _play("5-3", ["--profile", "comprador"])
	var text: String = run["text"]
	assert_eq(run["code"], 0, "El bot comprador del 5-3 termina con 0:\n%s" % run["summary"])
	assert_string_contains(text, "play_mall_bot (5-3, comprador): OK")
	assert_false(text.contains("FALLO"), "Sin fallos:\n%s" % run["summary"])
	for piece: String in ["hub cargado tras completar el 5-3", "TIENDA (comprador): muertes 0, golpes 1, congelaciones 1",
			"«Añadido al carrito» 0", "compras [tienda_energia (2)]", "gastado 5", "camino 5)", "drenado 0",
			"pay_door atajo_verificando con el pulso de espaldas: hecho", "CONGELADO 1.5 s por shortcut_processing",
			"(minimo 0;", "hub: carpeta M5"]:
		assert_string_contains(text, piece)


func test_mall_bot_completes_the_combos_room() -> void:
	var run: Dictionary = _play("combos_test")
	assert_eq(run["code"], 0, "El bot recorre combos_test:\n%s" % run["summary"])
	assert_string_contains(run["text"], "Embestidas 2 (camino 2), Filos 2 (camino 2), Sismos 1 (camino 1)")


func test_mall_bot_rejects_other_worlds_and_profiles() -> void:
	var run: Dictionary = _play("4-1", ["--path", "/dev/null"])
	assert_eq(run["code"], 1, "un nivel del chat no es de la tienda")
	assert_string_contains(run["text"], "nivel desconocido: 4-1")
	var run2: Dictionary = _play("5-1", ["--profile", "derrochador", "--path", "/dev/null"])
	assert_eq(run2["code"], 1, "un perfil desconocido falla")
	assert_string_contains(run2["text"], "perfil desconocido: derrochador")
