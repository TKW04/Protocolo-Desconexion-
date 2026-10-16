# Torre de prueba con el flujo real (scenes/main.tscn, LevelRunner; 2026-10-16,
# pasos 1 y 2 de docs/propuesta-1-2.md §10): el vortice de llegada y la terminal
# de salida funcionan con coordenadas de torre (abajo en el vestibulo y arriba en
# la azotea), la camara de torre empieza abajo, la red de caida usa el alto del
# grid y al reaparecer la camara se coloca sin suavizado. No es un nivel del
# juego (data/levels/tower_test.json; no se enlaza desde el hub).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TILE: float = 64.0
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0
const LEVEL_ID: String = "tower_test"

var _main: LevelRunner
var _isak: Isak
var _saved_level: StringName
var _saved_pulse: bool
var _completed: Array[String] = []


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	DebugMode.input_enabled = false
	GameState.reset_progress()
	_completed.clear()
	EventBus.level_completed.connect(_on_completed)
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = LEVEL_ID
	add_child(_main)


func after_each() -> void:
	EventBus.level_completed.disconnect(_on_completed)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_isak = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.reset_progress()
	GameState.last_checkpoint.clear()


func _on_completed(level_id: String) -> void:
	_completed.append(level_id)


func _arrive() -> void:
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	while vortex != null and is_instance_valid(vortex) and not vortex.is_done():
		vortex.advance(1.0 / 60.0)
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()
	await wait_physics_frames(LAND_FRAMES)


func test_arrival_vortex_opens_at_the_bottom_with_the_camera_there() -> void:
	assert_eq(_main.get_level_id(), LEVEL_ID)
	var level: GeneratedLevel = _main.get_level()
	var vortex: WarpVortex = _main.get_arrival_vortex()
	assert_not_null(vortex, "Llegada por el vortice")
	var isak: Isak = _main.get_isak()
	var size: Vector2i = level.get_size_px()
	assert_gt(vortex.global_position.y, size.y - 3.0 * TILE, "El vortice esta en el vestibulo (abajo)")
	assert_almost_eq(vortex.global_position.x, isak.global_position.x, 1.0)
	assert_almost_eq(isak.get_camera().global_position.y, size.y - 360.0, 1.0, "La camara empieza abajo")
	await _arrive()
	assert_false(_isak.is_warping(), "Control devuelto al cerrarse el vortice")
	assert_true(_isak.is_on_floor())
	assert_eq(roundi(_isak.global_position.y / TILE), 39, "De pie en el suelo del vestibulo")


func test_exit_terminal_at_the_top_completes_the_level() -> void:
	await _arrive()
	var terminal := _main.get_level().get_node(^"Objects/terminal_torre") as ExitTerminal
	assert_lt(terminal.global_position.y, 3.0 * TILE, "La terminal esta en la azotea (arriba)")
	_isak.global_position = Vector2(terminal.global_position.x - 0.4 * TILE, 3.0 * TILE)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0
	_isak.snap_camera()
	await wait_physics_frames(6)
	assert_almost_eq(_isak.get_camera().global_position.y, 360.0, 1.0, "Camara arriba del todo")
	_isak.set_pulse_area_active(true)
	assert_eq(terminal.get_state(), ExitTerminal.State.BOOT, "El pulso la activa")
	terminal.advance(LONG_STEP_S)
	var vortex: WarpVortex = terminal.get_vortex()
	assert_not_null(vortex, "Vortice de salida")
	if vortex == null:
		return
	assert_lt(vortex.global_position.y, 3.0 * TILE, "El vortice de salida se abre arriba, junto a Isak")
	vortex.advance(LONG_STEP_S)
	assert_eq(_completed, [LEVEL_ID] as Array[String], "Nivel completado")


func test_falling_below_the_tower_respawns_at_the_start_with_the_camera_snapped() -> void:
	await _arrive()
	var start: Vector2 = _main.get_start_position()
	assert_eq(_main.get_fall_limit_y(), float(_main.get_level().get_size_px().y) + 64.0, "Red de caida al fondo de la torre")
	_isak.global_position = Vector2(14.0 * TILE, 4.0 * TILE)
	_isak.snap_camera()
	assert_lt(_isak.get_camera().global_position.y, 600.0, "Camara arriba")
	_isak.global_position = Vector2(14.0 * TILE, _main.get_fall_limit_y() + 10.0)
	assert_true(_main.check_fall(), "Cae por debajo del nivel")
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_almost_eq(_isak.global_position, start, Vector2.ONE, "Reaparece en P")
	assert_almost_eq(_isak.get_camera().global_position.y, float(_main.get_level().get_size_px().y) - 360.0, 1.0,
		"La camara vuelve abajo sin suavizado")
