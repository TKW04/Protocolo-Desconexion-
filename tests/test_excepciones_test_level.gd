# Sala de prueba «Excepciones» (data/levels/excepciones_test.json, escena
# generada scenes/levels/excepciones_test.tscn; paso 7 de docs/propuesta-1-3.md
# §7 y §5.4, 2026-10-20) con el Isak real: la pared con glitch SOLO CON EL
# DEBUG (visible_only_with_debug) parece terreno normal sin el Debug y no se
# cruza; con el Debug muestra el glitch y se disuelve; detras, el decorado de
# la lista de contactos (exceptions_panel, sin colision ni Q) y el secreto
# secreto_excepciones con su punto y el mensaje msg_1_3 de Mamá
# (memory_pickup), que se recoge andando, sin el dash.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/excepciones_test.tscn")
const GLITCH_SCENE: PackedScene = preload("res://scenes/levels/glitch_wall.tscn")
const PATH: String = "user://test_excepciones.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const MSG: StringName = &"msg_1_3"
const WALL_COL: int = 18
const FORBIDDEN: Array[String] = ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]

var _saved_path: String
var _pulse_was: bool
var _debug_was: bool
var _dash_was: bool
var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_debug_was = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	_dash_was = GameState.is_ability_unlocked(&"dash")
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	get_tree().paused = false
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _debug_was)
	GameState.set_ability_unlocked(&"dash", _dash_was)


# --- Utilidades ---

func _load() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)


func _place(col: float, row: int) -> void:
	_sim.input.move_axis = 0.0
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0
	_sim.settle()


func _wall() -> GlitchWall:
	return _level.get_node(^"Objects/pared_excepciones") as GlitchWall


func _panel() -> ExceptionsPanel:
	return _level.get_node(^"Objects/panel_excepciones") as ExceptionsPanel


func _pickup() -> MemoryPickup:
	return _level.get_node_or_null(^"Objects/mensaje_1_3") as MemoryPickup


func _activate_debug() -> void:
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT) + 1:
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


## Camina hacia la derecha `seconds` (fisica real de Isak; nunca el dash).
func _walk_right(seconds: float) -> void:
	_sim.input.move_axis = 1.0
	for i: int in roundi(seconds / DT):
		_sim.step()
		if i % 4 == 0:
			await wait_physics_frames(1)
	_sim.input.move_axis = 0.0


## Cuadros de rafaga vistos en la pared durante `seconds` (cuadro != 0).
func _burst_frames(wall: GlitchWall, seconds: float) -> int:
	var seen: int = 0
	for i: int in roundi(seconds / DT):
		wall.advance(DT)
		for c: int in wall.get_cell_count():
			if wall.get_cell_frame(c) != 0:
				seen += 1
	return seen


# --- Escena ---

func test_scene_has_debug_only_wall_panel_and_message() -> void:
	await _load()
	assert_eq(_level.level_id, "excepciones_test")
	assert_true(_wall().visible_only_with_debug, "Pared solo con el Debug")
	assert_eq(_wall().get_cell_count(), 2, "Bloque de 1x2")
	assert_eq(_wall().global_position, Vector2(WALL_COL * T, 9 * T))
	assert_not_null(_pickup(), "El sobre del mensaje en la sala")
	assert_eq(_pickup().memory_id, MSG)
	assert_eq(MemoryCatalog.shared().entry(MSG).get("secret"), "secreto_excepciones",
		"El mensaje es del secreto de la sala")
	var lines: PackedStringArray = _panel().get_lines()
	assert_eq(lines, PackedStringArray(["Permitir llamadas de: Favoritos", "Mamá", "Abuelito"]))
	assert_eq(_panel().get_row_count(), 2)
	for line: String in lines:
		for word: String in FORBIDDEN:
			assert_false(line.contains(word), "Sin nombres de vueltas: %s" % line)


func test_panel_is_only_decoration() -> void:
	await _load()
	var panel: ExceptionsPanel = _panel()
	assert_false((panel as Node) is CollisionObject2D, "No es un cuerpo")
	for child: Node in panel.get_children():
		assert_false(child is CollisionObject2D or child is CollisionShape2D, "Sin colision: %s" % child.name)
	assert_false(panel.is_in_group(&"help_target"), "Sin Q")
	assert_lt(panel.z_index, 0, "Detras de Isak")


# --- Sin Debug ---

func test_wall_looks_like_terrain_and_blocks_without_debug() -> void:
	await _load()
	_wall().set_process(false)
	assert_false(_wall().is_glitch_shown(), "Sin el Debug no se ve el glitch")
	assert_eq(_burst_frames(_wall(), 6.0), 0, "Sin rafagas: parece terreno normal")
	_place(14.0, 10)
	await _walk_right(2.5)
	await wait_physics_frames(2)
	assert_true(_wall().is_solid(), "Sigue solida")
	assert_false(_wall().is_open())
	assert_lt(_isak.global_position.x, WALL_COL * T, "No la atraviesa")
	assert_false(GameState.has_memory(MSG), "El mensaje sigue sin obtener")


func test_plain_glitch_wall_still_bursts_without_debug() -> void:
	var wall := GLITCH_SCENE.instantiate() as GlitchWall
	add_child_autofree(wall)
	wall.set_process(false)
	assert_false(wall.visible_only_with_debug, "Por defecto, como en el 1-1 y el 1-2")
	assert_true(wall.is_glitch_shown())
	assert_gt(_burst_frames(wall, 6.0), 0, "La pared normal hace rafagas sin el Debug")


# --- Con Debug ---

func test_debug_reveals_glitch_far_away_without_opening() -> void:
	EcoProgress.obtain_debug()
	await _load()
	_wall().set_process(false)
	_place(8.0, 10)
	_activate_debug()
	assert_true(_wall().is_glitch_shown(), "Con el Debug se ve el glitch")
	assert_gt(_burst_frames(_wall(), 6.0), 0, "Y hace rafagas")
	assert_true(_wall().is_solid(), "Lejos (mas de 3 tiles) no se abre")
	DebugMode.reset()
	assert_false(_wall().is_glitch_shown(), "Al apagar el Debug vuelve a parecer terreno")
	_burst_frames(_wall(), DT)
	for c: int in _wall().get_cell_count():
		assert_eq(_wall().get_cell_frame(c), 0, "Celda %d limpia" % c)


func test_debug_opens_wall_and_message_is_collected_walking() -> void:
	EcoProgress.obtain_debug()
	await _load()
	var points_before: int = GameState.attention_points
	watch_signals(_wall())
	_place(15.0, 10)
	_activate_debug()
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return _wall().is_open(), 3.0)
	assert_signal_emitted(_wall(), "dissolve_started")
	assert_true(_wall().is_open(), "La pared se abre con el Debug")
	assert_false(_wall().is_solid())
	await _walk_right(4.5)
	await wait_physics_frames(2)
	assert_gt(_isak.global_position.x, 26.0 * T, "Entro en la sala andando (sin el dash)")
	assert_true(GameState.has_memory(MSG), "Obtiene msg_1_3")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar")
	assert_eq(GameState.attention_points, points_before + 1, "Y el punto del secreto")


func test_obtained_message_does_not_reappear() -> void:
	GameState.obtain_memory(MSG)
	await _load()
	await wait_physics_frames(2)
	assert_null(_pickup(), "Con el mensaje obtenido no sale")
