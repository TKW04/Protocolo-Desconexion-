# Confirmacion al entrar a una carpeta del hub con cambios sin guardar
# (FolderPanel; decision 2026-10-15): SIEMPRE que se elige un subnivel
# disponible o completado con GameState.has_unsaved_changes() sale «¿Seguro?
# Aun no has guardado.» (Entrar sin guardar / Volver); con todo guardado entra
# directo. Usa su propia ruta de guardado.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_unsaved_confirm.json"
const LONG_STEP_S: float = 5.0

var _hub: HubRoom
var _isak: Isak
var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool
var _requested: Array[StringName] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()
	_requested.clear()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


# --- Utilidades ---

func _spawn(arrive: bool = true) -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	# Entrar a un subnivel no carga nada: solo se anota.
	_hub.level_handler = func(id: StringName) -> void: _requested.append(id)
	add_child(_hub)
	if arrive:
		var vortex: WarpVortex = _hub.get_arrival_vortex()
		if vortex != null:
			vortex.advance(LONG_STEP_S)
	_isak = _hub.get_isak()
	_isak.input = PlayerInput.new()
	return _hub


func _progress() -> void:
	GameState.current_level = &"1-1"
	GameState.attention_points = 5
	GameState.mark_level_completed(&"1-1")


func _open_folder() -> FolderPanel:
	var folder: FolderStation = _hub.get_folder(&"m1")
	assert_true(folder.open(_isak), "La carpeta del Mundo 1 se abre")
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	return panel


func _choose_1_1(panel: FolderPanel) -> void:
	assert_true(panel.select_option(&"1-1"))
	panel.confirm()


func _save_in_copy_local() -> bool:
	var station := _hub.get_station(&"notas") as NotasStation
	assert_true(station.open(_isak))
	var ok: bool = station.get_notas_panel().save_now()
	station.close(true)
	return ok


# --- Confirmacion al entrar a una carpeta sin guardar ---

func test_confirmation_appears_with_unsaved_changes_on_every_entry() -> void:
	_progress()
	_spawn()
	assert_true(GameState.has_unsaved_changes())
	var panel: FolderPanel = _open_folder()
	for i: int in 2:
		_choose_1_1(panel)
		assert_true(panel.is_confirming_unsaved(), "Pide confirmacion (vez %d)" % (i + 1))
		assert_eq(panel.get_title(), "¿Seguro? Aún no has guardado.")
		assert_eq(panel.get_option_ids(), [FolderPanel.OPTION_ENTER_UNSAVED, FolderPanel.OPTION_STAY] as Array[StringName])
		assert_eq(_hub.get_entering_level(), &"", "Aun no entra")
		# Volver deja en el panel, en la lista.
		panel.select_option(FolderPanel.OPTION_STAY)
		panel.confirm()
		assert_false(panel.is_confirming_unsaved())
		assert_true(panel.is_open(), "Sigue en el panel")
		assert_eq(panel.get_selected_option(), &"1-1", "Con el subnivel elegido")
	# Salto (cancelar) tambien vuelve a la lista sin cerrar.
	_choose_1_1(panel)
	panel.cancel()
	assert_false(panel.is_confirming_unsaved())
	assert_true(panel.is_open())
	# Cerrar y volver a abrir: vuelve a preguntar.
	_hub.get_folder(&"m1").close(true)
	panel = _open_folder()
	_choose_1_1(panel)
	assert_true(panel.is_confirming_unsaved(), "Pregunta en cada entrada")
	assert_eq(_requested.size(), 0)


func test_no_confirmation_when_everything_is_saved() -> void:
	_progress()
	_spawn()
	assert_true(_save_in_copy_local())
	assert_false(GameState.has_unsaved_changes())
	var panel: FolderPanel = _open_folder()
	_choose_1_1(panel)
	assert_false(panel.is_confirming_unsaved(), "Todo guardado: sin pregunta")
	assert_eq(_hub.get_entering_level(), &"1-1", "Entra directo")


func test_enter_without_saving_launches_the_level() -> void:
	_progress()
	_spawn()
	var panel: FolderPanel = _open_folder()
	_choose_1_1(panel)
	panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED)
	panel.confirm()
	assert_eq(_hub.get_entering_level(), &"1-1", "Entra")
	assert_false(panel.is_open(), "El panel se cierra")
	var vortex: WarpVortex = _hub.get_departure_vortex()
	assert_not_null(vortex, "Vortice de salida")
	vortex.advance(LONG_STEP_S)
	await wait_process_frames(2)
	assert_eq(_requested, [&"1-1"] as Array[StringName], "Se lanza el nivel")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar")


func test_texts_do_not_name_laps_or_difficulty() -> void:
	var data: Dictionary = HubData.load_data()
	var texts: Array = [data["folders"]["texts"]["confirm_unsaved_title"],
		data["folders"]["texts"]["option_enter_unsaved"], data["folders"]["texts"]["option_stay"]]
	for text: Variant in texts:
		for word: String in ["Vuelta", "Easy", "Normal", "Hard"]:
			assert_false(String(text).contains(word), "«%s» no dice %s" % [text, word])
