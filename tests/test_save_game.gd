# Guardado en disco (GameState + SaveFile, decisiones del 2026-10-14): ida y
# vuelta de todo el progreso persistente, escritura atomica (sin .tmp al
# terminar; se recupera un .tmp huerfano), archivo ausente, corrupto (se aparta
# como .corrupt y se empieza de cero), version no soportada y campos con tipos
# raros. Usa una ruta propia: nunca el user://save.json del jugador.
extends GutTest

const PATH: String = "user://test_save_game.json"
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _saved_path: String
var _saved_autosave: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_autosave = GameState.autosave_enabled
	GameState.autosave_enabled = false
	GameState.use_save_path(PATH, true)


func after_each() -> void:
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.autosave_enabled = _saved_autosave


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


# El flujo de juego real (scenes/main.tscn) con autoguardado: el aviso del pulso
# y un punto de atencion se guardan en la ruta de prueba; el user://save.json del
# jugador no cambia (ni se crea) y la ruta resuelta al arrancar GUT no es la real.
func test_main_scene_under_gut_never_touches_the_real_save() -> void:
	var resolved: String = GameState.resolve_save_path(OS.get_cmdline_args(),
		OS.get_environment(GameState.SAVE_PATH_ENV))
	assert_ne(resolved, GameState.SAVE_PATH_DEFAULT, "GUT arranca con otra ruta")
	var real_before: String = _fingerprint(GameState.SAVE_PATH_DEFAULT)
	var saved_level: StringName = GameState.current_level
	var saved_pulse: bool = GameState.is_ability_unlocked(&"pulse")
	GameState.autosave_enabled = true
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


func test_request_save_writes_once_at_end_of_frame() -> void:
	GameState.autosave_enabled = true
	GameState.capture_attention_point(&"1-1", &"Point_8_9", 1)
	GameState.capture_attention_point(&"1-1", &"Point_14_8", 1)
	assert_false(FileAccess.file_exists(PATH), "Aun no: se agrupa al final del cuadro")
	await wait_process_frames(2)
	assert_true(FileAccess.file_exists(PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["attention_points"]), 2)
	assert_eq((data["captured_points"]["1-1"] as Array).size(), 2)
