# Pruebas de PlayerPhysics: carga de data/isak_physics.json, coherencia del
# salto (h, t, velocidad, gravedad), errores de carga y alcance horizontal.
extends GutTest

const TEMP_JSON_PATH: String = "user://test_isak_physics_missing_key.json"
const MISSING_FILE_PATH: String = "user://no_existe_isak_physics.json"
const REMOVED_KEY: String = "gravity"
const FLOAT_TOLERANCE: float = 0.001

var _physics: PlayerPhysics


func before_each() -> void:
	_physics = PlayerPhysics.load_from_file()


func after_each() -> void:
	if FileAccess.file_exists(TEMP_JSON_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_JSON_PATH))


func test_loads_default_json() -> void:
	assert_not_null(_physics, "Debe cargar res://data/isak_physics.json")
	assert_eq(PlayerPhysics.last_error, "", "No debe haber error de carga")
	for key: String in PlayerPhysics.REQUIRED_KEYS:
		assert_gt(absf(_physics.get(key)), 0.0, "La clave '%s' debe tener un valor no nulo" % key)


func test_jump_velocity_matches_height_and_apex_time() -> void:
	var expected: float = -2.0 * _physics.jump_height_px / _physics.time_to_apex_s
	assert_almost_eq(_physics.jump_velocity, expected, FLOAT_TOLERANCE, "jump_velocity debe ser -2h/t")


func test_gravity_matches_height_and_apex_time() -> void:
	var t: float = _physics.time_to_apex_s
	var expected: float = 2.0 * _physics.jump_height_px / (t * t)
	assert_almost_eq(_physics.gravity, expected, FLOAT_TOLERANCE, "gravity debe ser 2h/t^2")


func test_max_jump_height_equals_jump_height() -> void:
	assert_almost_eq(_physics.max_jump_height(), _physics.jump_height_px, FLOAT_TOLERANCE)


func test_missing_key_fails_with_clear_error() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PlayerPhysics.DEFAULT_PATH))
	data.erase(REMOVED_KEY)
	var file := FileAccess.open(TEMP_JSON_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var result: PlayerPhysics = PlayerPhysics.load_from_file(TEMP_JSON_PATH)
	assert_null(result, "Debe fallar si falta una clave")
	assert_string_contains(PlayerPhysics.last_error, REMOVED_KEY)
	assert_push_error(REMOVED_KEY)


func test_missing_file_fails_with_clear_error() -> void:
	var result: PlayerPhysics = PlayerPhysics.load_from_file(MISSING_FILE_PATH)
	assert_null(result, "Debe fallar si no existe el archivo")
	assert_string_contains(PlayerPhysics.last_error, MISSING_FILE_PATH)
	assert_push_error("no existe")


func test_horizontal_reach_positive_and_increasing() -> void:
	var walk_reach: float = _physics.horizontal_reach(_physics.walk_speed)
	var run_reach: float = _physics.horizontal_reach(_physics.run_speed)
	assert_gt(walk_reach, 0.0, "El alcance caminando debe ser positivo")
	assert_gt(run_reach, walk_reach, "El alcance debe crecer con la velocidad")
