# Teclas de prueba del flujo de nivel (LevelRunner, dev_keys de data/flow.json):
# restart_level (R / Select) reinicia el mapa desde el inicio conservando el
# guardado (puntos capturados, mejoras, power banks); se acepta jugando, en el
# hub y durante la muerte, y se ignora durante un fundido. Mantener
# debug_wipe_save (F9) wipe_hold_s borra el guardado y reinicia, con aviso en
# pantalla. Sin fugas tras 5 reinicios. Usa su propia ruta de guardado: nunca
# el user://save.json del jugador. No depende de la geometria del 1-1.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PATH: String = "user://test_dev_keys_save.json"
const LAND_FRAMES: int = 30
const LONG_STEP_S: float = 5.0

var _main: LevelRunner
var _saved_path: String
var _saved_level: StringName


## Las lineas importantes de Eco pausarian el nivel esperando al jugador; aqui
## nadie confirma (la pausa se prueba en test_eco_text_box.gd).
func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false


func after_each() -> void:
	# Deja que se liberen los niveles y hubs descartados (queue_free).
	await wait_process_frames(2)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	SaveFile.delete(PATH)
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.current_level = _saved_level
	GameState.save_path = _saved_path


func _start() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.advance(LONG_STEP_S)
	_main.get_isak().input = PlayerInput.new()
	await wait_physics_frames(LAND_FRAMES)


## Acaba el fundido en curso y engancha la entrada falsa al Isak nuevo.
func _finish_fades() -> void:
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	_main.get_isak().input = PlayerInput.new()


func _fill_progress() -> void:
	GameState.attention_points = 5000
	GameState.power_banks = 3
	GameState.capture_attention_point(&"1-1", &"Point_test_a", 1)
	GameState.capture_attention_point(&"1-1", &"Point_test_b", 1)
	assert_eq(GameState.purchase_upgrade(&"reinforced_sync"), GameState.PurchaseResult.OK)
	GameState.add_empty_power_bank()


func _eventbus_connections() -> int:
	var total: int = 0
	for info: Dictionary in EventBus.get_signal_list():
		total += EventBus.get_signal_connection_list(StringName(info["name"])).size()
	return total


func _count_in_tree(script_class: String) -> int:
	var count: int = 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.is_queued_for_deletion():
			continue
		var script: Script = node.get_script() as Script
		if script != null and script.get_global_name() == script_class:
			count += 1
		stack.append_array(node.get_children())
	return count


func _count_named(node_name: String) -> int:
	var count: int = 0
	for child: Node in _main.get_children():
		if child.name == node_name and not child.is_queued_for_deletion():
			count += 1
	return count


# --- Input Map ---

func test_actions_exist_and_do_not_clash() -> void:
	assert_true(InputMap.has_action(&"restart_level"))
	assert_true(InputMap.has_action(&"debug_wipe_save"))
	var r_key: bool = false
	var select: bool = false
	for event: InputEvent in InputMap.action_get_events(&"restart_level"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_R:
			r_key = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
			select = true
	assert_true(r_key, "R reinicia")
	assert_true(select, "Select / Back reinicia")
	var f9: bool = InputMap.action_get_events(&"debug_wipe_save").any(func(e: InputEvent) -> bool:
		return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F9)
	assert_true(f9, "F9 borra el guardado")
	# Ninguna otra accion usa R, F9 ni el boton Select.
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or action == &"restart_level" or action == &"debug_wipe_save":
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: Key = (event as InputEventKey).physical_keycode
				assert_ne(code, KEY_R, "%s no usa R" % action)
				assert_ne(code, KEY_F9, "%s no usa F9" % action)
			elif event is InputEventJoypadButton:
				assert_ne((event as InputEventJoypadButton).button_index, JOY_BUTTON_BACK, "%s no usa Select" % action)


# --- Reiniciar ---

func test_restart_resets_level_and_keeps_save() -> void:
	_fill_progress()
	await _start()
	assert_true(GameState.save_game())
	var old_level: GeneratedLevel = _main.get_level()
	var points: int = GameState.attention_points
	var banks: int = GameState.power_banks
	GameState.sync_rate = 30.0
	GameState.debug_energy = 10.0
	GameState.set_last_checkpoint(&"1-1", &"sync_1")
	assert_true(_main.request_restart(), "Jugando se acepta")
	assert_eq(_main.get_phase(), LevelRunner.Phase.FADE_OUT)
	_finish_fades()
	assert_ne(_main.get_level(), old_level, "Nivel nuevo")
	assert_eq(_main.get_level_id(), "1-1")
	assert_eq(_main.get_restart_count(), 1)
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max(), "Sync Rate inicial (con la mejora)")
	assert_gt(GameState.get_sync_rate_max(), GameState.SYNC_RATE_MAX, "Sync reforzado sigue comprado")
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "Energia inicial")
	assert_eq(GameState.get_last_checkpoint(&"1-1"), &"", "Checkpoint inicial")
	assert_eq(_main.get_isak().global_position, _main.get_start_position(), "Isak en P")
	# El guardado se conserva.
	assert_eq(GameState.attention_points, points)
	assert_true(GameState.is_attention_point_captured(&"1-1", &"Point_test_a"))
	assert_true(GameState.is_attention_point_captured(&"1-1", &"Point_test_b"))
	assert_true(GameState.is_upgrade_purchased(&"reinforced_sync"))
	assert_eq(GameState.power_banks, banks)
	assert_eq(GameState.empty_power_banks, 1)
	assert_true(FileAccess.file_exists(PATH), "El archivo de guardado sigue ahi")
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq((data["captured_points"]["1-1"] as Array).size(), 2)


func test_restart_key_goes_through_input_map() -> void:
	await _start()
	var event := InputEventAction.new()
	event.action = &"restart_level"
	event.pressed = true
	get_viewport().push_input(event)
	assert_eq(_main.get_phase(), LevelRunner.Phase.FADE_OUT, "La accion restart_level reinicia")
	_finish_fades()
	assert_eq(_main.get_restart_count(), 1)


func test_restart_is_ignored_during_fades() -> void:
	await _start()
	assert_true(_main.request_restart())
	assert_false(_main.request_restart(), "Durante el fundido de salida no se acepta")
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.FADE_IN)
	assert_false(_main.request_restart(), "Durante el fundido de entrada no se acepta")
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_restart_count(), 1, "Un solo reinicio")


func test_restart_during_death_replaces_respawn() -> void:
	await _start()
	var respawns: Array = []
	_main.respawned.connect(func(at: Vector2, after_death: bool) -> void: respawns.append([at, after_death]))
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_eq(_main.get_phase(), LevelRunner.Phase.DYING)
	assert_true(_main.request_restart(), "Durante la muerte se acepta")
	_finish_fades()
	assert_eq(respawns, [], "No reaparece: reinicia")
	assert_false(_main.get_isak().is_dead())
	assert_eq(_main.get_death_count(), 0, "Contador de muertes del mapa nuevo")
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max())


func test_restart_from_hub() -> void:
	await _start()
	EventBus.level_completed.emit("1-1")
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub())
	assert_true(_main.request_restart(), "En el hub se acepta")
	_finish_fades()
	assert_false(_main.is_in_hub())
	assert_eq(_main.get_level_id(), "1-1")
	assert_eq(_count_in_tree("HubPlaceholder"), 0)


# --- Borrar el guardado ---

func test_holding_wipe_deletes_test_save_and_restarts() -> void:
	assert_ne(GameState.save_path, GameState.SAVE_PATH_DEFAULT, "Nunca el save real")
	_fill_progress()
	await _start()
	assert_true(GameState.save_game())
	assert_true(FileAccess.file_exists(PATH))
	var wiped: Array = []
	_main.save_wiped.connect(func(path: String) -> void: wiped.append(path))
	var prompt: Label = _main.get_wipe_prompt()
	assert_not_null(prompt, "Hay aviso en builds de depuracion")
	assert_false(prompt.is_visible_in_tree(), "Sin mantener, sin aviso")
	assert_false(_main.update_wipe_hold(1.0, true))
	assert_true(prompt.is_visible_in_tree(), "Aviso mientras se mantiene")
	assert_eq(prompt.text, "Mantén F9: borrar guardado")
	assert_true(FileAccess.file_exists(PATH), "A medias no borra")
	assert_true(_main.update_wipe_hold(1.1, true), "A los 2 s borra")
	assert_eq(wiped, [PATH])
	assert_false(FileAccess.file_exists(PATH), "Archivo de prueba borrado")
	assert_eq(GameState.attention_points, 0)
	assert_false(GameState.is_attention_point_captured(&"1-1", &"Point_test_a"))
	assert_false(GameState.is_upgrade_purchased(&"reinforced_sync"))
	assert_eq(GameState.power_banks, 0)
	assert_false(_main.update_wipe_hold(5.0, true), "Sin soltar no vuelve a borrar")
	assert_false(prompt.is_visible_in_tree())
	_finish_fades()
	assert_eq(_main.get_restart_count(), 1, "Reinicia el mapa")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sync Rate sin mejoras")
	await wait_process_frames(2)
	assert_false(FileAccess.file_exists(PATH), "Nada lo vuelve a escribir")


func test_releasing_early_cancels_wipe() -> void:
	await _start()
	assert_true(GameState.save_game())
	_main.update_wipe_hold(1.5, true)
	_main.update_wipe_hold(0.1, false)
	assert_eq(_main.get_wipe_hold_s(), 0.0)
	assert_false(_main.update_wipe_hold(1.5, true), "La cuenta vuelve a empezar")
	assert_true(FileAccess.file_exists(PATH))


func test_wipe_disabled_does_nothing() -> void:
	await _start()
	assert_true(GameState.save_game())
	_main.wipe_enabled = false
	assert_false(_main.update_wipe_hold(10.0, true))
	assert_false(_main.wipe_save_and_restart())
	assert_true(FileAccess.file_exists(PATH))


# --- Fugas ---

func test_no_leaks_after_five_restarts() -> void:
	await _start()
	await wait_process_frames(2)
	var base_connections: int = _eventbus_connections()
	for i: int in 5:
		match i % 3:
			0:
				assert_true(_main.request_restart())
			1:
				GameState.sync_rate = GameState.SYNC_RATE_MIN
				assert_true(_main.request_restart())
			2:
				EventBus.level_completed.emit("1-1")
				_main.advance(LONG_STEP_S)
				_main.advance(LONG_STEP_S)
				assert_true(_main.request_restart())
		_finish_fades()
		await wait_process_frames(2)
	assert_eq(_main.get_restart_count(), 5)
	assert_eq(_eventbus_connections(), base_connections, "Sin conexiones colgadas")
	assert_eq(_main.get_isak().died.get_connections().size(), 1, "Una sola conexion a died")
	assert_eq(_count_in_tree("GeneratedLevel"), 1, "Un solo nivel")
	assert_eq(_count_in_tree("Isak"), 1, "Un solo Isak")
	assert_eq(_count_in_tree("Hud"), 1, "Un solo HUD")
	assert_eq(_count_in_tree("HubPlaceholder"), 0, "Sin hub")
	assert_eq(_main.get_transition_layer().get_child_count(), 1, "Un solo fundido")
	assert_eq(_count_named("DevPrompt"), 1, "Un solo aviso")
	assert_eq(Engine.time_scale, 1.0)
