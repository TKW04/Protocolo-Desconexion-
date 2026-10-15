# Aviso al salir con cambios sin guardar (QuitGuard + QuitPrompt; decision del
# usuario 2026-10-15). Logica de decision sin ventana, opciones del aviso,
# guardar y salir (en la ruta de prueba), volver (restaura la pausa) y que GUT
# no instala el aviso. El cierre real se sustituye por quit_handler.
extends GutTest

const PATH: String = "user://test_quit_guard_save.json"


class FakeStation:
	extends Node
	var allow: bool = true

	func can_save_now() -> bool:
		return allow


var _saved_path: String
var _guard: QuitGuard
var _quits: int = 0


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	_quits = 0
	_guard = QuitGuard.new()
	_guard.quit_handler = func() -> void: _quits += 1
	add_child(_guard)


func after_each() -> void:
	if is_instance_valid(_guard):
		_guard.free()
	get_tree().paused = false
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _add_station(allow: bool) -> FakeStation:
	var station := FakeStation.new()
	station.allow = allow
	station.add_to_group(QuitGuard.SAVE_STATION_GROUP)
	add_child_autofree(station)
	return station


func test_decision_logic() -> void:
	assert_eq(QuitGuard.decide(false, false), QuitGuard.Decision.QUIT, "Sin cambios sale sin preguntar")
	assert_eq(QuitGuard.decide(false, true), QuitGuard.Decision.QUIT)
	assert_eq(QuitGuard.decide(true, true), QuitGuard.Decision.ASK_WITH_SAVE, "En el hub se puede guardar")
	assert_eq(QuitGuard.decide(true, false), QuitGuard.Decision.ASK_WITHOUT_SAVE, "En un nivel no")
	assert_eq(QuitGuard.choices_for(QuitGuard.Decision.ASK_WITH_SAVE),
		[QuitGuard.Choice.SAVE_AND_QUIT, QuitGuard.Choice.QUIT, QuitGuard.Choice.BACK] as Array[QuitGuard.Choice])
	assert_eq(QuitGuard.choices_for(QuitGuard.Decision.ASK_WITHOUT_SAVE),
		[QuitGuard.Choice.QUIT, QuitGuard.Choice.BACK] as Array[QuitGuard.Choice], "Sin opcion de guardar")
	assert_true(QuitGuard.choices_for(QuitGuard.Decision.QUIT).is_empty())


func test_can_save_here_needs_an_active_station() -> void:
	assert_false(QuitGuard.can_save_here(get_tree()))
	var station: FakeStation = _add_station(false)
	assert_false(QuitGuard.can_save_here(get_tree()), "Estacion que ahora no deja guardar")
	station.allow = true
	assert_true(QuitGuard.can_save_here(get_tree()))


func test_quits_at_once_without_unsaved_changes() -> void:
	assert_eq(_guard.handle_close_request(), QuitGuard.Decision.QUIT)
	assert_eq(_quits, 1)
	assert_false(_guard.is_prompt_open())


func test_close_request_notification_is_handled() -> void:
	_guard.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_quits, 1, "La notificacion de cierre pasa por el aviso")


func test_in_a_level_asks_without_save_option_and_back_resumes() -> void:
	GameState.capture_attention_point(&"1-1", &"Point_8_9", 1)
	assert_eq(_guard.handle_close_request(), QuitGuard.Decision.ASK_WITHOUT_SAVE)
	assert_eq(_quits, 0, "No sale")
	assert_true(_guard.is_prompt_open())
	assert_true(get_tree().paused, "El juego se pausa con el aviso")
	var prompt: QuitPrompt = _guard.get_prompt()
	var data: Dictionary = QuitPrompt.load_data()
	var lines: PackedStringArray = prompt.get_lines()
	assert_eq(lines[0], String(data["texts"]["title_without_save"]))
	assert_true(lines[1].ends_with(String(data["texts"]["quit"])))
	assert_true(lines[2].ends_with(String(data["texts"]["back"])))
	for line: String in lines:
		assert_false(line.contains(String(data["texts"]["save_and_quit"])), "Sin guardar en un nivel")
	assert_eq(_guard.handle_close_request(), QuitGuard.Decision.ASK_WITHOUT_SAVE, "Otro cierre con el aviso abierto")
	assert_eq(_quits, 0)
	prompt.move_selection(1)
	assert_eq(prompt.get_selected_choice(), QuitGuard.Choice.BACK)
	prompt.confirm()
	assert_false(_guard.is_prompt_open(), "Volver cierra el aviso")
	assert_false(get_tree().paused, "Y deja la pausa como estaba")
	assert_eq(_quits, 0)
	assert_true(GameState.has_unsaved_changes(), "Nada se ha guardado")
	assert_false(FileAccess.file_exists(PATH))


func test_back_keeps_a_previous_pause() -> void:
	GameState.mark_level_completed(&"1-1")
	get_tree().paused = true
	_guard.handle_close_request()
	assert_false(_guard.choose(QuitGuard.Choice.BACK))
	assert_true(get_tree().paused, "Ya estaba en pausa (p. ej. linea importante de Eco)")


func test_quit_without_saving_loses_changes() -> void:
	GameState.mark_level_completed(&"1-1")
	_guard.handle_close_request()
	assert_true(_guard.choose(QuitGuard.Choice.QUIT))
	assert_eq(_quits, 1)
	assert_false(FileAccess.file_exists(PATH), "Salir no guarda")


func test_at_a_save_station_save_and_quit_writes_the_save() -> void:
	_add_station(true)
	GameState.capture_attention_point(&"1-1", &"Point_8_9", 1)
	assert_eq(_guard.handle_close_request(), QuitGuard.Decision.ASK_WITH_SAVE)
	var prompt: QuitPrompt = _guard.get_prompt()
	var data: Dictionary = QuitPrompt.load_data()
	var lines: PackedStringArray = prompt.get_lines()
	assert_eq(lines[0], String(data["texts"]["title_with_save"]))
	assert_true(lines[1].ends_with(String(data["texts"]["save_and_quit"])))
	assert_true(lines[2].ends_with(String(data["texts"]["quit_without_saving"])))
	assert_eq(prompt.get_selected_choice(), QuitGuard.Choice.SAVE_AND_QUIT, "Guardar y salir va primero")
	prompt.confirm()
	assert_eq(_quits, 1, "Sale tras guardar")
	assert_false(GameState.has_unsaved_changes())
	assert_eq(SaveFile.read(PATH).get("captured_points", {}).get("1-1"), ["Point_8_9"], "En la ruta de prueba")


func test_gut_does_not_install_the_guard() -> void:
	assert_null(GameState.get_quit_guard(), "En GUT (y con -s) el cierre no se intercepta")
