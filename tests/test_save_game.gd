# Guardado en disco (GameState + SaveFile, decisiones del 2026-10-14): ida y
# vuelta de todo el progreso persistente, escritura atomica (sin .tmp al
# terminar; se recupera un .tmp huerfano), archivo ausente, corrupto (se aparta
# como .corrupt y se empieza de cero), version no soportada y campos con tipos
# raros. Guardado manual (2026-10-15): request_save solo marca "sin guardar";
# esquema v2 (lap, found_secrets, hub_tutorial_done, saved_at, play_time_s),
# migracion desde v1 y copia anterior (.bak). Usa una ruta propia: nunca el
# user://save.json del jugador.
extends GutTest

const PATH: String = "user://test_save_game.json"
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)


func after_each() -> void:
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _fill_progress() -> void:
	GameState.attention_points = 42
	GameState.capture_attention_point(&"1-1", &"Point_8_9", 1)
	GameState.capture_attention_point(&"1-1", &"Point_14_8", 1)
	GameState.power_banks = 2
	GameState.empty_power_banks = 1
	GameState.power_bank_charge = 35.0
	GameState.purchase_upgrade(&"wide_pulse")
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")


func test_tests_never_use_the_real_save() -> void:
	assert_ne(_saved_path, GameState.SAVE_PATH_DEFAULT, "GUT no escribe user://save.json")
	assert_true(GameState.is_running_tests())


# Resolucion de la ruta con argumentos simulados (no escribe ningun archivo).
func test_normal_game_start_uses_the_real_save() -> void:
	var editor_run := PackedStringArray(["--path", "/p", "--remote-debug", "tcp://127.0.0.1:6007"])
	assert_eq(GameState.resolve_save_path(PackedStringArray(), ""), GameState.SAVE_PATH_DEFAULT)
	assert_eq(GameState.resolve_save_path(editor_run, ""), GameState.SAVE_PATH_DEFAULT)
	assert_eq(GameState.resolve_save_path(PackedStringArray(["res://scenes/main.tscn"]), ""),
		GameState.SAVE_PATH_DEFAULT)


func test_scripts_and_tools_never_resolve_to_the_real_save() -> void:
	var gut := PackedStringArray(["--headless", "-s", "addons/gut/gut_cmdln.gd", "-gexit"])
	var gut_panel := PackedStringArray(["res://addons/gut/gui/GutRunner.tscn"])
	assert_eq(GameState.resolve_save_path(gut, ""), GameState.SAVE_PATH_TESTS)
	assert_eq(GameState.resolve_save_path(gut_panel, ""), GameState.SAVE_PATH_TESTS)
	for tool: String in ["res://tools/play_level_bot.gd", "res://tools/render_level_1_1.gd",
			"res://tools/render_tramo4.gd"]:
		for flag: String in ["-s", "--script"]:
			var args := PackedStringArray(["--path", "/p", flag, tool])
			assert_eq(GameState.resolve_save_path(args, ""), GameState.SAVE_PATH_TOOLS, tool)
	assert_eq(GameState.resolve_save_path(gut, "user://env.json"), "user://env.json", "ISAK_SAVE_PATH manda")
	assert_eq(GameState.resolve_save_path(PackedStringArray(), "user://env.json"), "user://env.json")


# El flujo de juego real (scenes/main.tscn): capturar un punto solo marca "sin
# guardar" (no escribe); una copia manual escribe en la ruta de prueba el aviso
# del pulso y el punto; el user://save.json del jugador no cambia (ni se crea)
# y la ruta resuelta al arrancar GUT no es la real.
func test_main_scene_under_gut_never_touches_the_real_save() -> void:
	var resolved: String = GameState.resolve_save_path(OS.get_cmdline_args(),
		OS.get_environment(GameState.SAVE_PATH_ENV))
	assert_ne(resolved, GameState.SAVE_PATH_DEFAULT, "GUT arranca con otra ruta")
	var real_before: String = _fingerprint(GameState.SAVE_PATH_DEFAULT)
	var saved_level: StringName = GameState.current_level
	var saved_pulse: bool = GameState.is_ability_unlocked(&"pulse")
	var main: LevelRunner = MAIN_SCENE.instantiate() as LevelRunner
	main.auto_advance = false
	main.start_level_id = "1-1"
	add_child(main)
	assert_ne(GameState.save_path, GameState.SAVE_PATH_DEFAULT, "main.tscn no cambia la ruta")
	var notices: AbilityNotices = main.get_ability_notices()
	notices.auto_advance = false
	notices.advance(float(AbilityNotices.load_data()["start_delay_s"]) + 0.01)
	assert_true(GameState.capture_attention_point(&"1-1", &"Point_8_9", 1))
	await wait_process_frames(2)
	assert_false(FileAccess.file_exists(PATH), "Jugando no se escribe nada")
	assert_true(GameState.has_unsaved_changes())
	assert_true(GameState.save_game())
	var written: Dictionary = SaveFile.read(PATH)
	assert_eq(written.get("captured_points", {}).get("1-1"), ["Point_8_9"], "Guardado en la ruta de prueba")
	assert_true(GameState.is_notice_seen(&"pulse"))
	main.free()
	DebugMode.reset()
	GameState.set_ability_unlocked(&"pulse", saved_pulse)
	GameState.current_level = saved_level
	assert_eq(_fingerprint(GameState.SAVE_PATH_DEFAULT), real_before, "user://save.json intacto")


static func _fingerprint(path: String) -> String:
	return FileAccess.get_md5(path) if FileAccess.file_exists(path) else "ausente"


func test_round_trip_keeps_all_progress() -> void:
	_fill_progress()
	assert_eq(GameState.attention_points, 42 + 2 - 25, "Pulso amplio cuesta 25 (economia 2026-10-15)")
	assert_true(GameState.save_game())
	assert_true(FileAccess.file_exists(PATH))
	assert_false(FileAccess.file_exists(PATH + SaveFile.TMP_SUFFIX), "Sin .tmp: renombrado atomico")
	GameState.reset_progress()
	assert_eq(GameState.attention_points, 0)
	assert_true(GameState.load_game())
	assert_eq(GameState.attention_points, 19)
	assert_eq(GameState.get_captured_points(&"1-1"), [&"Point_14_8", &"Point_8_9"] as Array[StringName])
	assert_eq(GameState.power_banks, 2)
	assert_eq(GameState.empty_power_banks, 1)
	assert_almost_eq(GameState.power_bank_charge, 35.0, 0.001)
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"))
	assert_true(GameState.is_level_completed(&"1-1"))
	assert_true(GameState.is_level_unlocked(&"1-2"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), GameState.SAVE_VERSION, "Version del esquema")


func test_missing_file_starts_fresh() -> void:
	GameState.attention_points = 9
	assert_false(GameState.load_game())
	assert_eq(SaveFile.last_status, SaveFile.Status.MISSING)
	assert_eq(GameState.attention_points, 0)


func test_corrupt_file_is_set_aside_and_game_starts_fresh() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"attention_points\": 5,")
	file.close()
	GameState.attention_points = 9
	assert_false(GameState.load_game(), "Corrupto: no carga")
	assert_eq(SaveFile.last_status, SaveFile.Status.CORRUPT)
	assert_eq(GameState.attention_points, 0, "Empieza de cero")
	assert_false(FileAccess.file_exists(PATH), "El corrupto se aparta")
	assert_true(FileAccess.file_exists(PATH + SaveFile.CORRUPT_SUFFIX), "Se conserva como .corrupt")
	GameState.attention_points = 3
	assert_true(GameState.save_game(), "Despues se puede guardar")
	assert_true(GameState.load_game())
	assert_eq(GameState.attention_points, 3)


func test_non_object_json_counts_as_corrupt() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	assert_false(GameState.load_game())
	assert_eq(SaveFile.last_status, SaveFile.Status.CORRUPT)


func test_unknown_version_is_not_applied() -> void:
	SaveFile.write(PATH, {"version": GameState.SAVE_VERSION + 1, "attention_points": 99})
	assert_false(GameState.load_game())
	assert_eq(GameState.attention_points, 0)
	SaveFile.write(PATH, {"attention_points": 99})
	assert_false(GameState.load_game(), "Sin version tampoco")
	assert_eq(GameState.attention_points, 0)


func test_odd_field_types_are_tolerated() -> void:
	SaveFile.write(PATH, {
		"version": 1,
		"attention_points": "muchos",
		"captured_points": {"1-1": ["Point_8_9", 7, null], "1-2": "x"},
		"upgrades_purchased": ["wide_pulse", "no_existe", 3],
		"power_banks": {"full": -4, "charge": 99999.0},
		"completed_levels": "1-1",
	})
	assert_true(GameState.load_game())
	assert_eq(GameState.attention_points, 0)
	assert_eq(GameState.get_captured_points(&"1-1"), [&"Point_8_9"] as Array[StringName])
	assert_eq(GameState.get_captured_points(&"1-2"), [] as Array[StringName])
	assert_eq(GameState.purchased_upgrades.keys(), [&"wide_pulse"], "Ids desconocidos se ignoran")
	assert_eq(GameState.power_banks, 0)
	assert_almost_eq(GameState.power_bank_charge, GameState.get_power_bank_capacity(), 0.001, "Carga acotada")
	assert_false(GameState.is_level_completed(&"1-1"))


func test_power_bank_charge_needs_an_empty_power_bank() -> void:
	# Guardado de antes de los power banks vacios: la carga se conserva en uno.
	SaveFile.write(PATH, {"version": 1, "power_banks": {"full": 1, "charge": 40.0}})
	assert_true(GameState.load_game())
	assert_eq(GameState.power_banks, 1)
	assert_eq(GameState.empty_power_banks, 1)
	assert_almost_eq(GameState.power_bank_charge, 40.0, 0.001)
	# Con "empty" 0 la carga no tiene donde estar: se descarta.
	SaveFile.write(PATH, {"version": 1, "power_banks": {"full": 0, "empty": 0, "charge": 40.0}})
	assert_true(GameState.load_game())
	assert_eq(GameState.empty_power_banks, 0)
	assert_almost_eq(GameState.power_bank_charge, 0.0, 0.001)


func test_orphan_tmp_is_recovered() -> void:
	SaveFile.write(PATH, {"version": 1, "attention_points": 12})
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH),
		ProjectSettings.globalize_path(PATH + SaveFile.TMP_SUFFIX))
	assert_true(GameState.load_game(), "Cierre entre escribir y renombrar: usa el .tmp")
	assert_eq(GameState.attention_points, 12)


func test_request_save_only_marks_unsaved_changes() -> void:
	var events: Array[bool] = []
	var on_change := func(value: bool) -> void: events.append(value)
	EventBus.unsaved_changes_changed.connect(on_change)
	assert_false(GameState.has_unsaved_changes(), "Recien cargado: nada pendiente")
	GameState.capture_attention_point(&"1-1", &"Point_8_9", 1)
	GameState.capture_attention_point(&"1-1", &"Point_14_8", 1)
	assert_true(GameState.has_unsaved_changes())
	await wait_process_frames(2)
	assert_false(FileAccess.file_exists(PATH), "Guardado manual: nada se escribe solo")
	assert_true(GameState.save_game())
	assert_false(GameState.has_unsaved_changes(), "Guardar limpia la marca")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["attention_points"]), 2)
	assert_eq((data["captured_points"]["1-1"] as Array).size(), 2)
	assert_eq(events, [true, false] as Array[bool], "Una senal al ensuciar y otra al guardar")
	EventBus.unsaved_changes_changed.disconnect(on_change)


func test_every_progress_change_marks_unsaved() -> void:
	var changes: Dictionary[String, Callable] = {
		"punto": func() -> void: GameState.capture_attention_point(&"1-1", &"Point_8_9", 1),
		"objeto": func() -> void: GameState.mark_pickup_collected(&"1-1", &"cargador_x"),
		"power bank": func() -> void: GameState.add_empty_power_bank(),
		"habilidad": func() -> void: GameState.obtain_ability(&"laser"),
		"nivel completado": func() -> void: GameState.mark_level_completed(&"1-1"),
		"nivel desbloqueado": func() -> void: GameState.unlock_level(&"1-2"),
		"secreto": func() -> void: GameState.mark_secret_found(&"1-1", &"secreto_a"),
	}
	for name: String in changes:
		assert_true(GameState.save_game())
		assert_false(GameState.has_unsaved_changes())
		changes[name].call()
		assert_true(GameState.has_unsaved_changes(), name)
	GameState.attention_points = 30
	assert_true(GameState.save_game())
	assert_eq(GameState.purchase_upgrade(&"wide_pulse"), GameState.PurchaseResult.OK)
	assert_true(GameState.has_unsaved_changes(), "Comprar una mejora")


func test_seen_notice_and_play_time_do_not_mark_unsaved() -> void:
	assert_true(GameState.mark_notice_seen(&"pulse"))
	await wait_process_frames(2)
	assert_false(GameState.has_unsaved_changes(), "Abrir el juego unos segundos no pide guardar")


func test_load_and_reset_clear_unsaved_changes() -> void:
	GameState.capture_attention_point(&"1-1", &"Point_8_9", 1)
	assert_true(GameState.save_game())
	GameState.mark_level_completed(&"1-1")
	assert_true(GameState.has_unsaved_changes())
	assert_true(GameState.load_game())
	assert_false(GameState.has_unsaved_changes(), "Lo cargado es lo que hay en disco")
	assert_false(GameState.is_level_completed(&"1-1"), "Lo no guardado se pierde")
	GameState.mark_level_completed(&"1-1")
	GameState.reset_progress()
	assert_false(GameState.has_unsaved_changes())


# --- Esquema v2 ---

func test_v2_round_trip_keeps_new_fields() -> void:
	GameState.lap = GameState.LAP_NORMAL
	assert_true(GameState.mark_secret_found(&"1-1", &"secreto_b"))
	assert_true(GameState.mark_secret_found(&"1-1", &"secreto_a"))
	assert_false(GameState.mark_secret_found(&"1-1", &"secreto_a"), "Una vez")
	GameState.hub_tutorial_done = true
	GameState.play_time_s = 123.5
	assert_true(GameState.save_game())
	var stamp: String = GameState.saved_at
	assert_true(stamp.ends_with("Z") and stamp.length() == 20, "Fecha UTC: %s" % stamp)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), 2)
	assert_eq(int(data["lap"]), GameState.LAP_NORMAL)
	assert_eq(data["found_secrets"], {"1-1": ["secreto_a", "secreto_b"]})
	assert_eq(data["hub_tutorial_done"], true)
	assert_eq(data["saved_at"], stamp)
	GameState.reset_progress()
	assert_eq(GameState.lap, GameState.LAP_EASY)
	assert_true(GameState.load_game())
	assert_eq(GameState.lap, GameState.LAP_NORMAL)
	assert_true(GameState.is_secret_found(&"1-1", &"secreto_a"))
	assert_true(GameState.is_secret_found(&"1-1", &"secreto_b"))
	assert_true(GameState.hub_tutorial_done)
	assert_almost_eq(GameState.play_time_s, 123.5, 0.001)
	assert_eq(GameState.saved_at, stamp)


func test_v1_save_is_migrated() -> void:
	SaveFile.write(PATH, {
		"version": 1,
		"attention_points": 7,
		"captured_points": {"1-1": ["Point_8_9"]},
		"completed_levels": ["1-1"],
		"unlocked_levels": ["1-2"],
	})
	assert_true(GameState.load_game(), "Una v1 se carga")
	assert_eq(GameState.attention_points, 7)
	assert_eq(GameState.lap, GameState.LAP_EASY, "Vuelta 1 por defecto")
	assert_true(GameState.found_secrets.is_empty())
	assert_true(GameState.hub_tutorial_done, "Con el 1-1 completado no repite el tutorial")
	assert_eq(GameState.saved_at, "")
	assert_almost_eq(GameState.play_time_s, 0.0, 0.001)
	assert_false(GameState.has_unsaved_changes())
	assert_true(GameState.save_game())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), GameState.SAVE_VERSION, "La copia siguiente escribe la v2")
	assert_eq(int(data["attention_points"]), 7)
	# Una v1 sin el 1-1 completado si hace el tutorial.
	SaveFile.write(PATH, {"version": 1, "attention_points": 1})
	assert_true(GameState.load_game())
	assert_false(GameState.hub_tutorial_done)


func test_v2_odd_fields_are_tolerated() -> void:
	SaveFile.write(PATH, {"version": 2, "lap": 9, "found_secrets": {"1-1": "x", "1-2": ["s", 3]},
		"hub_tutorial_done": "si", "saved_at": 5, "play_time_s": -3})
	assert_true(GameState.load_game())
	assert_eq(GameState.lap, GameState.LAP_HARD, "Vuelta acotada")
	assert_false(GameState.found_secrets.has(&"1-1"))
	assert_true(GameState.is_secret_found(&"1-2", &"s"))
	assert_false(GameState.hub_tutorial_done, "Tipo raro: como v1 sin el 1-1")
	assert_eq(GameState.saved_at, "")
	assert_almost_eq(GameState.play_time_s, 0.0, 0.001)


func test_unknown_future_version_is_set_aside() -> void:
	SaveFile.write(PATH, {"version": 3, "attention_points": 99})
	assert_false(GameState.load_game(), "Version 3 desconocida: no carga")
	assert_eq(GameState.attention_points, 0, "Empieza de cero")
	assert_false(FileAccess.file_exists(PATH), "Se aparta")
	assert_true(FileAccess.file_exists(PATH + SaveFile.CORRUPT_SUFFIX), "Se conserva como .corrupt")
	assert_false(GameState.has_unsaved_changes())


func test_save_keeps_previous_copy_as_bak() -> void:
	var bak: String = PATH + SaveFile.BACKUP_SUFFIX
	GameState.attention_points = 5
	assert_true(GameState.save_game())
	assert_false(FileAccess.file_exists(bak), "Primera copia: no habia anterior")
	GameState.attention_points = 8
	assert_true(GameState.save_game())
	assert_true(FileAccess.file_exists(bak), "La copia anterior pasa a .bak")
	assert_eq(int(SaveFile.read_backup(PATH)["attention_points"]), 5)
	assert_eq(int(SaveFile.read(PATH)["attention_points"]), 8)
	GameState.attention_points = 11
	assert_true(GameState.save_game())
	assert_eq(int(SaveFile.read_backup(PATH)["attention_points"]), 8, "El .bak es siempre la anterior")
	SaveFile.delete(PATH)
	assert_false(FileAccess.file_exists(bak), "Borrar el guardado borra tambien el .bak")


func test_corrupt_save_falls_back_to_bak() -> void:
	GameState.attention_points = 5
	assert_true(GameState.save_game())
	GameState.attention_points = 8
	assert_true(GameState.save_game())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{roto")
	file.close()
	assert_true(GameState.load_game(), "Corrupto: se carga la copia anterior")
	assert_eq(GameState.attention_points, 5)
	assert_true(FileAccess.file_exists(PATH + SaveFile.CORRUPT_SUFFIX), "El roto se aparta")
	assert_false(GameState.has_unsaved_changes())
