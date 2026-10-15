# Guardado en disco (GameState + SaveFile, decisiones del 2026-10-14): ida y
# vuelta de todo el progreso persistente, escritura atomica (sin .tmp al
# terminar; se recupera un .tmp huerfano), archivo ausente, corrupto (se aparta
# como .corrupt y se empieza de cero), version no soportada y campos con tipos
# raros. Usa una ruta propia: nunca el user://save.json del jugador.
extends GutTest

const PATH: String = "user://test_save_game.json"

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


func test_round_trip_keeps_all_progress() -> void:
	_fill_progress()
	assert_eq(GameState.attention_points, 42 + 2 - 15)
	assert_true(GameState.save_game())
	assert_true(FileAccess.file_exists(PATH))
	assert_false(FileAccess.file_exists(PATH + SaveFile.TMP_SUFFIX), "Sin .tmp: renombrado atomico")
	GameState.reset_progress()
	assert_eq(GameState.attention_points, 0)
	assert_true(GameState.load_game())
	assert_eq(GameState.attention_points, 29)
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
