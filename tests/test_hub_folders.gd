# Carpetas de los mundos y panel de subniveles del hub real (FolderStation,
# FolderPanel, HubWorlds; paso 7 de docs/propuesta-hub-y-guardado.md §6.2):
# estados de carpeta y de subnivel segun completed_levels / unlocked_levels y la
# vuelta; repisas alcanzables de un salto desde el dock; la carpeta bloqueada no
# abre el panel; elegir el 1-1 se va por el vortice y carga el nivel; el arte
# del hub existe y carga. Usa su propia ruta de guardado.
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_hub_folders.json"
const T: float = 64.0
const LONG_STEP_S: float = 5.0

var _hub: HubRoom
var _isak: Isak
var _input: OneShotJumpInput
var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool
var _runners: Array[Node] = []


## Entrada falsa con el salto como flanco de un solo paso de fisica.
class OneShotJumpInput:
	extends PlayerInput
	var _queued: bool = false
	var hold: bool = false

	func queue_jump() -> void:
		_queued = true
		hold = true

	func poll() -> void:
		jump_pressed = _queued
		jump_held = hold
		_queued = false


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()
	_runners.clear()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	for runner: Node in _runners:
		if is_instance_valid(runner):
			runner.free()
	_runners.clear()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _spawn() -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(LONG_STEP_S)
	_isak = _hub.get_isak()
	_input = OneShotJumpInput.new()
	_isak.input = _input
	return _hub


func _world(id: StringName) -> Dictionary:
	return HubWorlds.world(id)


## Isak de pie sobre la repisa de la carpeta `id`, en su centro.
func _stand_on_shelf(id: StringName) -> FolderStation:
	var folder: FolderStation = _hub.get_folder(id)
	_isak.global_position = Vector2(folder.position.x + folder.get_size().x * 0.5, _hub.get_shelf_top_y())
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(6)
	folder.advance(0.1)
	return folder


# --- Registro y estados (HubWorlds) ---

func test_worlds_registry_has_world_1_with_three_sublevels_and_locked_2_and_3() -> void:
	var ids: Array[StringName] = []
	for entry: Dictionary in HubWorlds.folder_worlds():
		ids.append(StringName(String(entry["id"])))
	assert_eq(ids, [&"m1", &"m2", &"m3"] as Array[StringName], "Carpetas del hub: M1-M3")
	var all: Array[StringName] = []
	for entry: Dictionary in HubWorlds.worlds():
		all.append(StringName(String(entry["id"])))
	assert_eq(all, [&"m1", &"m2", &"m3", &"m4", &"m5", &"m6"] as Array[StringName],
		"Los 6 mundos con su nombre (los 4-6, sin carpeta en el hub)")
	for id: StringName in [&"m4", &"m5", &"m6"]:
		assert_false(HubWorlds.is_world_unlocked(_world(id)), "%s bloqueado" % id)
	var levels: Array[String] = []
	for level: Dictionary in HubWorlds.levels(_world(&"m1")):
		levels.append(String(level["id"]))
	assert_eq(levels, ["1-1", "1-2", "1-3"] as Array[String])
	assert_true(HubWorlds.is_playable(HubWorlds.levels(_world(&"m1"))[0]), "1-1 jugable")
	assert_true(HubWorlds.is_playable(HubWorlds.levels(_world(&"m1"))[1]), "1-2 jugable (paso 13 del 1-2)")
	assert_true(HubWorlds.is_playable(HubWorlds.levels(_world(&"m1"))[2]), "1-3 jugable (paso 10 del 1-3)")
	assert_eq(HubWorlds.level_points_total("1-2"), 9, "9 puntos de atencion en el 1-2")
	assert_eq(HubWorlds.level_points_total("1-1"), 9, "9 puntos de atencion en el 1-1")


func test_folder_states_follow_progress() -> void:
	assert_eq(HubWorlds.folder_state(_world(&"m1")), HubWorlds.STATE_AVAILABLE, "M1 disponible desde el inicio")
	assert_eq(HubWorlds.folder_state(_world(&"m2")), HubWorlds.STATE_LOCKED)
	assert_eq(HubWorlds.folder_state(_world(&"m3")), HubWorlds.STATE_LOCKED)
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	assert_eq(HubWorlds.folder_state(_world(&"m1")), HubWorlds.STATE_AVAILABLE, "Faltan 1-2 y 1-3")
	GameState.mark_level_completed(&"1-2")
	GameState.mark_level_completed(&"1-3")
	assert_eq(HubWorlds.folder_state(_world(&"m1")), HubWorlds.STATE_COMPLETED, "Todos los de la vuelta")


func test_sublevel_states_follow_completed_and_unlocked_levels() -> void:
	var m1: Dictionary = _world(&"m1")
	var l: Array[Dictionary] = HubWorlds.levels(m1)
	assert_eq(HubWorlds.level_state(m1, l[0]), HubWorlds.STATE_AVAILABLE, "1-1 disponible (primero)")
	assert_eq(HubWorlds.level_state(m1, l[1]), HubWorlds.STATE_LOCKED)
	assert_eq(HubWorlds.level_state(m1, l[2]), HubWorlds.STATE_LOCKED)
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	assert_eq(HubWorlds.level_state(m1, l[0]), HubWorlds.STATE_COMPLETED)
	assert_eq(HubWorlds.level_state(m1, l[1]), HubWorlds.STATE_AVAILABLE, "1-2 disponible tras completar el 1-1")
	assert_false(HubWorlds.is_coming_soon(l[1]))
	assert_true(HubWorlds.can_enter(&"1-1"), "Un completado se puede rejugar en la vuelta actual")
	assert_true(HubWorlds.can_enter(&"1-2"))
	assert_eq(HubWorlds.level_state(m1, l[2]), HubWorlds.STATE_LOCKED, "1-3 bloqueado hasta desbloquearlo")
	assert_false(HubWorlds.can_enter(&"1-3"))
	GameState.unlock_level(&"1-3")
	assert_eq(HubWorlds.level_state(m1, l[2]), HubWorlds.STATE_AVAILABLE, "1-3 desbloqueado y jugable (paso 10 del 1-3)")
	assert_false(HubWorlds.is_coming_soon(l[2]))
	assert_true(HubWorlds.can_enter(&"1-3"))
	# «Proximamente»: un subnivel sin nivel jugable (hoy ninguno del Mundo 1; uno sintetico).
	var soon := {"id": "y", "world": 9, "unlocked": true, "levels": [
		{"id": "1-1", "laps": [1], "playable": true},
		{"id": "9-2", "laps": [1], "playable": false}]}
	GameState.unlock_level(&"9-2")
	assert_true(HubWorlds.is_coming_soon(HubWorlds.levels(soon)[1]), "Proximamente")
	assert_eq(HubWorlds.level_state(soon, HubWorlds.levels(soon)[1]), HubWorlds.STATE_LOCKED)
	assert_false(HubWorlds.can_enter(&"9-2"))
	# Un subnivel jugable que no es el primero solo se abre con unlocked_levels.
	var synthetic := {"id": "x", "world": 9, "unlocked": true, "levels": [
		{"id": "9-1", "laps": [1], "playable": false},
		{"id": "1-1", "laps": [1], "playable": true}]}
	var second: Dictionary = HubWorlds.levels(synthetic)[1]
	GameState.reset_progress()
	assert_eq(HubWorlds.level_state(synthetic, second), HubWorlds.STATE_LOCKED, "Sin desbloquear")
	GameState.unlock_level(&"1-1")
	assert_eq(HubWorlds.level_state(synthetic, second), HubWorlds.STATE_AVAILABLE, "En unlocked_levels")


func test_locked_world_unlocks_through_its_levels() -> void:
	var synthetic := {"id": "x", "world": 9, "unlocked": false, "levels": [
		{"id": "1-1", "laps": [1], "playable": true}]}
	assert_eq(HubWorlds.folder_state(synthetic), HubWorlds.STATE_LOCKED)
	assert_eq(HubWorlds.level_state(synthetic, HubWorlds.levels(synthetic)[0]), HubWorlds.STATE_LOCKED)
	GameState.unlock_level(&"1-1")
	assert_eq(HubWorlds.folder_state(synthetic), HubWorlds.STATE_AVAILABLE)


func test_only_the_current_lap_is_listed() -> void:
	var m1: Dictionary = _world(&"m1")
	assert_eq(HubWorlds.levels_for_lap(m1).size(), 3, "Vuelta 1 (Easy): 1-1, 1-2 y 1-3")
	GameState.mark_level_completed(&"1-1")
	GameState.lap = GameState.LAP_NORMAL
	assert_eq(HubWorlds.levels_for_lap(m1).size(), 0, "No se rejuegan subniveles de vueltas anteriores")
	assert_false(HubWorlds.can_enter(&"1-1"), "El 1-1 de la vuelta 1 ya no se elige")


# --- Carpetas en el hub ---

func test_folders_sit_on_shelves_with_their_state_and_number() -> void:
	_spawn()
	assert_eq(_hub.get_folder_ids(), [&"m1", &"m2", &"m3"] as Array[StringName])
	var expected_cols: Dictionary = {&"m1": 4, &"m2": 10, &"m3": 16}
	for id: StringName in expected_cols:
		var folder: FolderStation = _hub.get_folder(id)
		assert_eq(folder.get_size(), Vector2(128.0, 128.0), "Carpeta de 2x2 tiles")
		assert_eq(folder.position.x, float(expected_cols[id]) * T, "%s en su columna" % id)
		var sink: float = float(HubData.section("folders").get("folder_sink_px", 0))
		assert_almost_eq(folder.position.y + folder.get_size().y - sink, _hub.get_shelf_top_y(), 0.5, "Sobre la repisa")
	assert_eq(_hub.get_folder(&"m1").get_folder_state(), HubWorlds.STATE_AVAILABLE)
	assert_eq(_hub.get_folder(&"m1").get_folder_animation(), &"available")
	assert_eq(_hub.get_folder(&"m2").get_folder_animation(), &"locked")
	assert_eq(_hub.get_folder(&"m3").get_folder_animation(), &"locked")
	assert_eq(_hub.get_folder(&"m1").get_number_text(), "1")
	assert_eq(_hub.get_folder(&"m3").get_number_text(), "3")


# Miniatura del mundo (2026-10-15): campana en la carpeta del Mundo 1 junto al
# numero; las bloqueadas, sin miniatura (no se adelanta el mundo).
func test_world_1_folder_shows_its_bell_miniature_and_locked_ones_do_not() -> void:
	_spawn()
	var m1: FolderStation = _hub.get_folder(&"m1")
	assert_true(m1.is_miniature_visible(), "Campana en la carpeta del Mundo 1")
	assert_eq(m1.get_miniature().texture.resource_path, "res://assets/sprites/hub/icons/world_icon_m1_00.png")
	assert_eq(m1.get_miniature().texture.get_size(), Vector2(16.0, 16.0), "Icono de 16x16")
	var mr: Array = HubData.section("folders")["miniature_rect_px"]
	assert_eq(m1.get_miniature().position, Vector2(float(mr[0]), float(mr[1])))
	assert_eq(m1.get_miniature().scale, Vector2(2.0, 2.0), "x2, como el arte de la carpeta")
	var nr: Array = HubData.section("folders")["number_rect_with_miniature_px"]
	assert_eq(m1.get_node(^"Number").position, Vector2(float(nr[0]), float(nr[1])), "Numero a la derecha")
	for id: StringName in [&"m2", &"m3"]:
		var locked: FolderStation = _hub.get_folder(id)
		assert_false(locked.is_miniature_visible(), "%s bloqueada: sin miniatura" % id)
		var r: Array = HubData.section("folders")["number_rect_px"]
		assert_eq(locked.get_node(^"Number").position, Vector2(float(r[0]), float(r[1])), "Numero centrado")
	for id: StringName in [&"1-1", &"1-2", &"1-3"]:
		GameState.mark_level_completed(id)
	m1.refresh_state()
	assert_true(m1.is_miniature_visible(), "Tambien completada")


func test_completed_world_shows_the_completed_folder() -> void:
	for id: StringName in [&"1-1", &"1-2", &"1-3"]:
		GameState.mark_level_completed(id)
	_spawn()
	assert_eq(_hub.get_folder(&"m1").get_folder_animation(), &"completed")


func test_shelves_are_reachable_with_one_jump_from_the_dock() -> void:
	_spawn()
	var physics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/isak_physics.json"))
	var shelf_h: float = _hub.get_floor_y() - _hub.get_shelf_top_y()
	assert_lt(shelf_h, float(physics["jump_height_px"]), "Repisa por debajo del salto de diseno")
	# Salto real de Isak en el hub, en una columna sin repisa encima (8).
	_isak.global_position = Vector2(8.5 * T, _hub.get_floor_y())
	await wait_physics_frames(4)
	assert_true(_isak.is_on_floor())
	var y0: float = _isak.global_position.y
	var min_y: float = y0
	_input.queue_jump()
	for i: int in 60:
		await wait_physics_frames(1)
		min_y = minf(min_y, _isak.global_position.y)
	var jump_h: float = y0 - min_y
	gut.p("Salto maximo medido: %.1f px; repisa a %.1f px" % [jump_h, shelf_h])
	assert_gt(jump_h, shelf_h + 8.0, "El salto supera la repisa con margen")
	# Desde el dock, bajo la repisa de M1: atraviesa la repisa de una via y queda encima.
	_input.hold = false
	_isak.global_position = Vector2(5.0 * T, _hub.get_floor_y())
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(6)
	_input.queue_jump()
	await wait_physics_frames(50)
	assert_true(_isak.is_on_floor(), "Aterriza")
	assert_almost_eq(_isak.global_position.y, _hub.get_shelf_top_y(), 1.0, "De pie sobre la repisa")
	var folder: FolderStation = _hub.get_folder(&"m1")
	folder.advance(0.1)
	assert_true(folder.is_key_hint_visible(), "Junto a la carpeta: tecla del pulso")


func test_pulse_from_the_dock_does_not_open_the_folder() -> void:
	_spawn()
	_isak.global_position = Vector2(5.0 * T, _hub.get_floor_y())
	await wait_physics_frames(6)
	var folder: FolderStation = _hub.get_folder(&"m1")
	folder.advance(0.1)
	assert_false(folder.is_player_near(), "Desde el dock no esta cerca")
	_isak.set_pulse_area_active(true)
	await wait_physics_frames(2)
	assert_false(folder.is_panel_open())


func test_pulse_on_the_shelf_opens_the_sublevel_panel() -> void:
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	GameState.capture_attention_point(&"1-1", &"p1", 1)
	GameState.capture_attention_point(&"1-1", &"p2", 1)
	_spawn()
	var folder: FolderStation = await _stand_on_shelf(&"m1")
	assert_true(folder.is_key_hint_visible())
	_isak.set_pulse_area_active(true)
	await wait_physics_frames(2)
	assert_true(folder.is_panel_open(), "El pulso abre el panel")
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	var panel: FolderPanel = folder.get_folder_panel()
	assert_eq(panel.get_title(), "Mundo 1 - Notificaciones")
	assert_eq(panel.get_lines(), PackedStringArray(["Acceso: Caché"]), "Nivel de acceso, no la vuelta")
	for line: String in panel.get_lines():
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(line.contains(word), "«%s» no dice «%s»" % [line, word])
	assert_eq(panel.get_option_ids(), [&"1-1", &"1-2", &"1-3", FolderPanel.OPTION_BACK] as Array[StringName])
	assert_eq(panel.level_text(HubWorlds.levels(_world(&"m1"))[0]), "1-1 Bandeja de entrada - Completado 2/9")
	assert_eq(panel.level_text(HubWorlds.levels(_world(&"m1"))[1]), "1-2 Centro de notificaciones - Nuevo",
		"El 1-2 disponible tras completar el 1-1 (paso 13 del 1-2)")
	assert_eq(panel.level_text(HubWorlds.levels(_world(&"m1"))[2]), "1-3 No molestar - Bloqueado",
		"El 1-3 existe (paso 10 del 1-3): bloqueado hasta completar el 1-2")
	assert_eq(panel.get_level_state(&"1-1"), HubWorlds.STATE_COMPLETED)
	assert_eq(panel.get_level_state(&"1-2"), HubWorlds.STATE_AVAILABLE)
	# Un subnivel bloqueado no se elige: solo un mensaje.
	var chosen: Array[StringName] = []
	panel.level_chosen.connect(func(id: StringName) -> void: chosen.append(id))
	panel.skip_input_delay()
	panel.select_option(&"1-3")
	panel.confirm()
	assert_eq(panel.get_message(), "Bloqueado: completa el anterior")
	assert_eq(chosen.size(), 0)
	assert_true(folder.is_panel_open())
	# Volver cierra y devuelve el control.
	panel.select_option(FolderPanel.OPTION_BACK)
	panel.confirm()
	await wait_physics_frames(4)
	assert_false(folder.is_panel_open())
	assert_false(_isak.is_facing_back(), "Recupera el control")


func test_new_game_lists_1_1_as_new() -> void:
	_spawn()
	var panel: FolderPanel = _hub.get_folder(&"m1").get_folder_panel()
	panel.open()
	assert_eq(panel.level_text(HubWorlds.levels(_world(&"m1"))[0]), "1-1 Bandeja de entrada - Nuevo")
	assert_eq(panel.get_level_state(&"1-3"), HubWorlds.STATE_LOCKED)
	panel.close()


func test_locked_folder_does_not_open_and_says_not_downloaded() -> void:
	_spawn()
	var folder: FolderStation = await _stand_on_shelf(&"m2")
	assert_true(folder.is_locked())
	assert_true(folder.is_player_near())
	assert_false(folder.is_key_hint_visible(), "Sin tecla del pulso")
	assert_true(folder.is_locked_hint_visible(), "Aviso en su lugar")
	assert_eq(folder.get_locked_hint_text(), "Sin descargar")
	_isak.set_pulse_area_active(true)
	await wait_physics_frames(2)
	assert_false(folder.is_panel_open(), "Bloqueada: no abre el panel")
	assert_false(folder.open(_isak))
	assert_false(_isak.is_facing_back())


func test_choosing_1_1_departs_through_the_vortex_and_loads_the_level() -> void:
	# Al hub se llega tras el 1-1: Eco ya dio el pulso en el encuentro.
	EcoProgress.meet_eco_with_pulse()
	_spawn()
	var requested: Array[StringName] = []
	_hub.level_requested.connect(func(id: StringName) -> void: requested.append(id))
	_hub.scene_switcher = func(runner: Node) -> void:
		_runners.append(runner)
		add_child(runner)
	var folder: FolderStation = await _stand_on_shelf(&"m1")
	assert_true(folder.open(_isak))
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	panel.select_option(&"1-1")
	panel.confirm()
	assert_false(folder.is_panel_open(), "El panel se cierra")
	assert_eq(folder.get_entering_level(), &"1-1")
	assert_eq(_hub.get_entering_level(), &"1-1")
	assert_true(_isak.is_facing_back(), "De espaldas frente a la carpeta")
	var vortex: WarpVortex = _hub.get_departure_vortex()
	assert_not_null(vortex, "Vortice de salida")
	assert_eq(_runners.size(), 0, "El nivel espera al vortice")
	vortex.advance(LONG_STEP_S)
	await wait_process_frames(2)
	assert_eq(requested, [&"1-1"] as Array[StringName])
	assert_eq(_runners.size(), 1, "Se carga el flujo del nivel")
	var runner := _runners[0] as LevelRunner
	assert_not_null(runner, "LevelRunner (scenes/main.tscn)")
	assert_eq(runner.get_level_id(), "1-1")
	assert_not_null(runner.get_level(), "Nivel 1-1 cargado")
	assert_false(_hub.is_inside_tree(), "El hub sale del arbol")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "El nivel conserva el pulso obtenido")
	var encounter := runner.get_level().get_node(^"Objects/eco_encuentro") as EcoEncounter
	assert_true(encounter.is_done(), "Con Eco conocido el encuentro no se repite")
	assert_false(encounter.is_eco_visible())


func test_locked_sublevel_cannot_be_entered() -> void:
	_spawn()
	assert_false(_hub.enter_level(&"1-2"), "Sin completar el 1-1, el 1-2 sigue bloqueado")
	assert_false(_hub.enter_level(&"1-3"))
	assert_false(_hub.enter_level(&"9-9"))
	assert_eq(_hub.get_entering_level(), &"")


# --- Arte ---

func test_hub_sprite_frames_and_tiles_exist_and_load() -> void:
	var specs: Dictionary = {
		"res://assets/sprites/hub/hub_bg_frames.tres": {&"off": 2, &"on": 1},
		"res://assets/sprites/hub/notas_frames.tres": {&"powered_off": 1, &"off": 2, &"prompt": 2, &"active": 2},
		"res://assets/sprites/hub/folder_frames.tres": {&"locked": 1, &"available": 2, &"completed": 1},
		"res://assets/sprites/hub/calc_frames.tres": {&"powered_off": 1, &"sleep": 3, &"awake": 4},
	}
	for path: String in specs:
		var frames := load(path) as SpriteFrames
		assert_not_null(frames, path)
		if frames == null:
			continue
		for anim: StringName in specs[path]:
			assert_true(frames.has_animation(anim), "%s: %s" % [path, anim])
			assert_eq(frames.get_frame_count(anim), int(specs[path][anim]), "%s: cuadros de %s" % [path, anim])
			for i: int in frames.get_frame_count(anim):
				assert_not_null(frames.get_frame_texture(anim, i))
	var dirs: Dictionary = {"tiles": Vector2(64, 64), "dock_slots": Vector2(64, 96), "icons": Vector2.ZERO}
	for dir: String in dirs:
		for file: String in DirAccess.get_files_at("res://assets/sprites/hub/" + dir):
			if not file.ends_with(".png"):
				continue
			var tex := load("res://assets/sprites/hub/%s/%s" % [dir, file]) as Texture2D
			assert_not_null(tex, file)
			if tex != null and dirs[dir] != Vector2.ZERO:
				assert_eq(tex.get_size(), dirs[dir], file)


# --- Nombres de cara al jugador de las vueltas (2026-10-15) ---

func test_access_names_per_lap() -> void:
	assert_eq(HubWorlds.access_name(1), "Caché")
	assert_eq(HubWorlds.access_name(2), "Kernel")
	assert_eq(HubWorlds.access_name(3), "Raíz")
	assert_eq(HubWorlds.access_name(4), "Raíz", "Vuelta mayor que las definidas: el ultimo nombre")
	assert_eq(HubWorlds.access_name(0), "Caché", "Acotado por abajo")
	assert_eq(HubWorlds.access_label(1), "Acceso: Caché")
	assert_eq(HubWorlds.access_label(2), "Acceso: Kernel")
	assert_eq(HubWorlds.access_label(3), "Acceso: Raíz")


func test_access_label_follows_current_lap() -> void:
	var saved: int = GameState.lap
	GameState.lap = GameState.LAP_HARD
	assert_eq(HubWorlds.access_label(), "Acceso: Raíz")
	GameState.lap = saved


func test_hub_texts_never_name_laps() -> void:
	var text: String = JSON.stringify(_strip_notes(HubData.load_data()))
	for word: String in ["Vuelta", "Easy", "\"Normal\"", "Hard"]:
		assert_false(text.contains(word), "data/hub.json (sin _notes) no dice «%s»" % word)


func _strip_notes(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			if not String(key).ends_with("_notes") and String(key) != "_notes":
				out[key] = _strip_notes(value[key])
		return out
	if value is Array:
		return (value as Array).map(_strip_notes)
	return value
