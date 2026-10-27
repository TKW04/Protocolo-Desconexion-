# Fila del jefe «Alerta Mayor» en la carpeta del Mundo 1 (pasos 1 y 13 de
# docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21): entrada 1-boss de
# data/hub.json (kind boss, JUGABLE desde el paso 13), texto «Jefe: » sin id ni
# puntos, Bloqueado hasta completar el 1-3 y Nuevo despues (desbloqueo por la
# terminal del 1-3, unlocks), y la carpeta no pasa a completed ni se enciende la
# pieza cian del hub hasta vencer al jefe. Paso 13: desde el hub se entra a la
# arena (confirmacion sin guardar, 3 vidas), morir reaparece al principio de la
# fase con energia >= 50, el game over es el rollback a la ultima copia y,
# vencido, se repite desde la carpeta. Los 1-1 a 1-3 siguen igual. Usa su
# propia ruta de guardado.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_boss_entry.json"

var _hub: HubRoom
var _saved_path: String
var _saved_pulse: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _m1() -> Dictionary:
	return HubWorlds.world(&"m1")


func _boss() -> Dictionary:
	for level: Dictionary in HubWorlds.levels(_m1()):
		if String(level.get("id", "")) == "1-boss":
			return level
	return {}


func _complete_1_3_like_the_terminal() -> void:
	# Lo mismo que LevelRunner._record_completion al terminar cada nivel.
	for id: String in ["1-1", "1-2", "1-3"]:
		GameState.mark_level_completed(StringName(id))
		var level: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % id))
		for unlock: Variant in (level as Dictionary).get("unlocks", []):
			if String((unlock as Dictionary).get("type", "")) == "level":
				GameState.unlock_level(StringName(String((unlock as Dictionary).get("id", ""))))


func _panel() -> FolderPanel:
	var panel := FolderPanel.new()
	panel.world_entry = _m1()
	add_child_autofree(panel)
	return panel


func test_entry_is_the_last_row_of_m1_and_a_playable_boss() -> void:
	var boss: Dictionary = _boss()
	assert_false(boss.is_empty(), "1-boss registrado en m1")
	var levels: Array[Dictionary] = HubWorlds.levels(_m1())
	assert_eq(String(levels[levels.size() - 1].get("id", "")), "1-boss", "Tras el 1-3")
	assert_eq(String(boss.get("name", "")), "Alerta Mayor")
	assert_true(HubWorlds.is_boss(boss))
	assert_eq(boss.get("laps", []), [1.0], "Solo en Caché por ahora")
	assert_true(HubWorlds.is_playable(boss), "playable: true desde el paso 13")
	assert_false(HubWorlds.is_coming_soon(boss))
	for level: Dictionary in levels:
		if String(level.get("id", "")) != "1-boss":
			assert_false(HubWorlds.is_boss(level), "%s no es jefe" % level.get("id", ""))
			assert_true(HubWorlds.is_playable(level), "%s sigue jugable" % level.get("id", ""))


func test_terminal_of_1_3_unlocks_the_boss_row() -> void:
	assert_false(GameState.is_level_unlocked(&"1-boss"))
	_complete_1_3_like_the_terminal()
	assert_true(GameState.is_level_unlocked(&"1-boss"), "unlocks del 1-3")
	assert_eq(HubWorlds.level_state(_m1(), _boss()), HubWorlds.STATE_AVAILABLE, "Jugable tras el 1-3")
	assert_true(HubWorlds.can_enter(&"1-boss"))
	assert_eq(HubWorlds.most_advanced_level(), &"1-boss", "R en el hub reanuda el jefe")


func test_panel_text_has_boss_prefix_and_no_points() -> void:
	var panel: FolderPanel = _panel()
	assert_eq(panel.level_text(_boss()), "Jefe: Alerta Mayor - Bloqueado", "Partida nueva")
	assert_false(HubWorlds.can_enter(&"1-boss"), "Sin el 1-3 no se entra")
	_complete_1_3_like_the_terminal()
	assert_eq(panel.level_text(_boss()), "Jefe: Alerta Mayor - Nuevo", "Tras el 1-3")
	assert_eq(HubWorlds.level_points_total("1-boss"), 0, "La arena no tiene puntos")
	GameState.mark_level_completed(&"1-boss")
	# Con el jefe completado el texto no lleva puntos y se puede repetir.
	var text: String = panel.level_text(_boss())
	assert_eq(text, "Jefe: Alerta Mayor - Completado")
	assert_true(HubWorlds.can_enter(&"1-boss"), "Revancha desde la carpeta")
	assert_true(text.begins_with("Jefe: Alerta Mayor - "), text)
	assert_false(text.contains("/"), "Sin puntos: %s" % text)
	assert_false(text.contains("1-boss"), "Sin id: %s" % text)
	for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
		assert_false(text.contains(word))


func test_other_rows_do_not_change() -> void:
	var panel: FolderPanel = _panel()
	_complete_1_3_like_the_terminal()
	var levels: Array[Dictionary] = HubWorlds.levels(_m1())
	assert_eq(panel.level_text(levels[0]), "1-1 Bandeja de entrada - Completado 0/9 - Power bank 0/1")
	assert_eq(panel.level_text(levels[2]), "1-3 No molestar - Completado 0/9 - Power bank 0/1")


func test_folder_and_cyan_piece_wait_for_the_boss() -> void:
	_complete_1_3_like_the_terminal()
	assert_eq(HubWorlds.folder_state(_m1()), HubWorlds.STATE_AVAILABLE,
		"1-1 a 1-3 completados: la carpeta no se completa sin el jefe")
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_background_state(), &"off", "Pieza cian apagada tras el 1-3")
	_hub.free()
	GameState.mark_level_completed(&"1-boss")
	assert_eq(HubWorlds.folder_state(_m1()), HubWorlds.STATE_COMPLETED, "Jefe vencido: carpeta completa")
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_background_state(), &"on", "Pieza cian encendida con el jefe vencido")


# --- Paso 13: jugable desde el hub ---

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LONG_STEP_S: float = 5.0


func _start_main(level_id: String) -> LevelRunner:
	var main := MAIN_SCENE.instantiate() as LevelRunner
	main.auto_advance = false
	main.start_level_id = level_id
	add_child_autofree(main)
	main.advance(LONG_STEP_S)
	return main


func _arena_boss(main: LevelRunner) -> AlertMajor:
	var boss := main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	boss.intro_on_arrival = false
	return boss


## Muere Isak y el flujo avanza hasta despues del fundido (como test_lives.gd).
func _die(main: LevelRunner) -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	main.advance(main.get_death_wait_s() + 0.01)
	main.advance(LONG_STEP_S)
	main.advance(LONG_STEP_S)


func test_enter_the_arena_from_the_hub_with_the_unsaved_confirmation_and_three_lives() -> void:
	EcoProgress.meet_eco_with_pulse()
	_complete_1_3_like_the_terminal()
	GameState.request_save()
	var main: LevelRunner = _start_main("hub")
	var hub: HubRoom = main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	assert_true(hub.has_arrived())
	var folder: FolderStation = hub.get_folder(&"m1")
	assert_true(folder.open(hub.get_isak()), "La carpeta del Mundo 1 se abre")
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	assert_true(panel.select_option(&"1-boss"), "Fila del jefe elegible")
	panel.confirm()
	assert_true(panel.is_confirming_unsaved(), "Con cambios sin guardar pide confirmacion")
	assert_true(panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED))
	panel.confirm()
	var departure: WarpVortex = hub.get_departure_vortex()
	assert_not_null(departure, "Vortice de salida")
	departure.advance(LONG_STEP_S)
	await wait_process_frames(2)
	main.advance(LONG_STEP_S)
	main.advance(LONG_STEP_S)
	assert_false(main.is_in_hub(), "Sale del hub")
	assert_eq(main.get_level_id(), "1-boss", "Entra a la arena")
	assert_eq(GameState.lives, GameState.lives_max, "Tres vidas por intento")
	assert_eq(GameState.lives_max, 3)


func test_death_restarts_the_phase_with_at_least_50_energy() -> void:
	EcoProgress.meet_eco_with_pulse()
	_complete_1_3_like_the_terminal()
	var main: LevelRunner = _start_main("1-boss")
	var boss: AlertMajor = _arena_boss(main)
	await wait_physics_frames(3)
	boss.start()
	for i: int in 4:
		boss.take_core_hit(1)
	assert_eq(boss.get_phase(), 2)
	assert_eq(boss.get_counter_label(), "55")
	GameState.debug_energy = 10.0
	await wait_physics_frames(2)
	_die(main)
	assert_false(main.is_in_hub(), "Con vidas no hay game over")
	assert_eq(GameState.lives, 2, "Se pierde una vida")
	assert_eq(boss.get_phase(), 2, "Sigue en la fase 2")
	assert_eq(boss.get_counter_label(), "66", "Al principio de la fase")
	assert_gte(GameState.debug_energy, 50.0, "Energia al menos 50")


func test_game_over_in_the_arena_rolls_back_to_the_last_copy() -> void:
	EcoProgress.meet_eco_with_pulse()
	_complete_1_3_like_the_terminal()
	assert_true(GameState.save_game(), "Copia con el 1-3 completado")
	var main: LevelRunner = _start_main("1-boss")
	var boss: AlertMajor = _arena_boss(main)
	await wait_physics_frames(3)
	boss.start()
	var reports: Array = []
	main.game_over.connect(func(report: Dictionary) -> void: reports.append(report))
	for i: int in 3:
		await wait_physics_frames(2)
		_die(main)
	assert_true(main.is_in_hub(), "Game over: al hub")
	assert_eq(reports.size(), 1, "Un game over")
	assert_true(GameState.is_level_completed(&"1-3"), "Lo guardado se conserva")
	assert_false(GameState.is_level_completed(&"1-boss"), "El jefe sigue sin vencer")
	assert_true(HubWorlds.can_enter(&"1-boss") or GameState.has_trash_pending(),
		"Se vuelve a entrar (tras recuperar la papelera si la hay)")


## Terminado cuando (paso 13): desde el hub, tras el 1-3, se entra a «Jefe: Alerta Mayor», se juega la pelea
## completa con la barra del jefe, se vence, se recibe el recuerdo y se vuelve al hub con el Mundo 2
## desbloqueado y la pieza cian encendida. Flujo real en un proceso aparte (tools/smoke_boss_arena.gd --full).
func test_full_flow_from_the_hub_and_back() -> void:
	var output: Array = []
	var args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/smoke_boss_arena.gd", "--", "--full"])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "".join(output)
	assert_eq(code, 0, "Vuelta al hub:\n%s" % text.substr(maxi(text.find("smoke_boss_arena"), 0)))
	assert_string_contains(text, "barra true, 1-boss true, recuerdo true, Mundo 2 true, pieza on")
	assert_false(text.contains("SCRIPT ERROR"), "Sin errores de script")


# --- Paso 18 de docs/propuesta-mundo-2.md (2026-10-23): «Jefe: Autoplay» ---

const DT: float = 1.0 / 60.0


func _m2() -> Dictionary:
	return HubWorlds.world(&"m2")


func _row(world_entry: Dictionary, id: String) -> Dictionary:
	for level: Dictionary in HubWorlds.levels(world_entry):
		if String(level.get("id", "")) == id:
			return level
	return {}


## Mundo 1 completo (Alerta Mayor vencida) y el 2-1 a 2-3 como sus terminales.
func _complete_world_1_and_2_3() -> void:
	_complete_1_3_like_the_terminal()
	GameState.mark_level_completed(&"1-boss")
	for id: String in ["2-1", "2-2", "2-3"]:
		GameState.mark_level_completed(StringName(id))
		var level: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % id))
		for unlock: Variant in (level as Dictionary).get("unlocks", []):
			if String((unlock as Dictionary).get("type", "")) == "level":
				GameState.unlock_level(StringName(String((unlock as Dictionary).get("id", ""))))


func test_autoplay_row_is_playable_after_2_3() -> void:
	var boss: Dictionary = _row(_m2(), "2-boss")
	assert_true(HubWorlds.is_boss(boss))
	assert_true(HubWorlds.is_playable(boss), "playable: true desde el paso 18")
	var panel := FolderPanel.new()
	panel.world_entry = _m2()
	add_child_autofree(panel)
	_complete_1_3_like_the_terminal()
	GameState.mark_level_completed(&"1-boss")
	assert_eq(panel.level_text(boss), "Jefe: Autoplay - Bloqueado", "Antes del 2-3")
	assert_false(HubWorlds.can_enter(&"2-boss"))
	_complete_world_1_and_2_3()
	assert_eq(panel.level_text(boss), "Jefe: Autoplay - Nuevo", "Tras el 2-3")
	assert_true(HubWorlds.can_enter(&"2-boss"))
	assert_eq(HubWorlds.folder_state(_m2()), HubWorlds.STATE_AVAILABLE, "Sin el jefe la carpeta no se completa")
	assert_false(HubWorlds.is_world_unlocked(HubWorlds.world(&"m3")), "Mundo 3 bloqueado antes del jefe")


func test_amber_piece_hidden_then_blinking_then_lit() -> void:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_piece_animation(2), &"hidden", "Mundo 2 bloqueado: pieza gris")
	_hub.free()
	_complete_1_3_like_the_terminal()
	GameState.mark_level_completed(&"1-boss")
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_background_state(), &"on", "La cian sigue en el fondo")
	assert_eq(_hub.get_piece_animation(2), &"off", "Mundo 2 desbloqueado: contorno ambar")
	_hub.free()
	_complete_world_1_and_2_3()
	GameState.mark_level_completed(&"2-boss")
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_piece_animation(2), &"on", "Autoplay vencido: pieza ambar encendida")


## Terminado cuando (paso 18): desde la carpeta M2 se entra a «Jefe: Autoplay», se vence, se recibe
## boss_w2_l1 sin guardar y se vuelve al hub con la pieza ambar encendida y el Mundo 3 «Próximamente».
func test_autoplay_from_the_m2_folder_and_back_with_the_amber_piece() -> void:
	EcoTextBox.pause_important = false
	BossReward.pause_tree = false
	BossDefeat.freeze_tree = false
	EcoProgress.meet_eco_with_pulse()
	_complete_world_1_and_2_3()
	GameState.request_save()
	var main: LevelRunner = _start_main("hub")
	var hub: HubRoom = main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m2")
	assert_true(folder.open(hub.get_isak()), "La carpeta del Mundo 2 se abre")
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	assert_true(panel.select_option(&"2-boss"), "Fila del jefe elegible")
	panel.confirm()
	assert_true(panel.is_confirming_unsaved())
	assert_true(panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED))
	panel.confirm()
	hub.get_departure_vortex().advance(LONG_STEP_S)
	await wait_process_frames(2)
	main.advance(LONG_STEP_S)
	main.advance(LONG_STEP_S)
	assert_eq(main.get_level_id(), "2-boss", "Entra a la arena de Autoplay")
	main.auto_advance = true
	var boss := main.get_level().get_node(^"Objects/autoplay") as Autoplay
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	if not boss.is_fighting():
		boss.start()
	while not boss.is_defeated():
		boss.take_core_hit(1)
	await wait_physics_frames(2)
	var defeat: BossDefeat = boss.get_defeat()
	assert_not_null(defeat, "Secuencia de derrota")
	var t: float = 0.0
	while t < 25.0 and is_instance_valid(defeat) and defeat.get_stage() < BossDefeat.Stage.DONE:
		var reward: BossReward = defeat.get_reward()
		if reward != null and reward.can_close():
			reward.confirm()
		await wait_physics_frames(1)
		t += DT
	assert_true(GameState.has_memory(&"boss_w2_l1"), "Capa Caché del Mundo 2")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar: se guarda en Notas")
	t = 0.0
	while t < 8.0 and not main.is_in_hub():
		await wait_physics_frames(1)
		t += DT
	assert_true(main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"2-boss"))
	hub = main.get_hub()
	assert_true(hub.light_piece_on_arrival)
	assert_eq(hub.light_piece_world, 2, "Se enciende la pieza del Mundo 2")
	watch_signals(hub)
	t = 0.0
	while t < 10.0 and (hub.get_piece_animation(2) != &"on" or hub.is_piece_lighting() or hub.is_piece_pending()):
		await wait_physics_frames(1)
		t += DT
	assert_eq(hub.get_piece_animation(2), &"on", "Pieza ambar encendida")
	assert_eq(hub.get_background_state(), &"on", "La cian sigue encendida")
	assert_signal_emitted_with_parameters(hub, "wallpaper_piece_lit", [2])
	var m3: Dictionary = HubWorlds.world(&"m3")
	assert_true(HubWorlds.is_world_unlocked(m3), "Mundo 3 desbloqueado (unlocked_by 2-boss)")
	var p3 := FolderPanel.new()
	p3.world_entry = m3
	add_child_autofree(p3)
	p3.refresh()
	# Desde el paso 10 de docs/propuesta-mundo-3.md (2026-10-26) el Mundo 3 tiene el 3-1: disponible tras Autoplay.
	assert_eq(p3.get_level_state(&"3-1"), HubWorlds.STATE_AVAILABLE, "El 3-1 disponible al vencer a Autoplay")
	EcoTextBox.pause_important = true
	BossReward.pause_tree = true
	BossDefeat.freeze_tree = true


# --- Paso 17 de docs/propuesta-mundo-3.md (2026-10-27): «Jefe: La Curadora» ---

func _m3() -> Dictionary:
	return HubWorlds.world(&"m3")


## Mundos 1 y 2 completos (Autoplay vencido) y el 3-1 a 3-3 como sus terminales.
func _complete_worlds_1_2_and_3_3() -> void:
	_complete_world_1_and_2_3()
	GameState.mark_level_completed(&"2-boss")
	for id: String in ["3-1", "3-2", "3-3"]:
		GameState.mark_level_completed(StringName(id))
		var level: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % id))
		for unlock: Variant in (level as Dictionary).get("unlocks", []):
			if String((unlock as Dictionary).get("type", "")) == "level":
				GameState.unlock_level(StringName(String((unlock as Dictionary).get("id", ""))))


func test_curator_row_is_playable_after_3_3_and_world_4_waits_for_her() -> void:
	var boss: Dictionary = _row(_m3(), "3-boss")
	assert_true(HubWorlds.is_boss(boss))
	assert_true(HubWorlds.is_playable(boss), "playable: true desde el paso 17")
	var panel := FolderPanel.new()
	panel.world_entry = _m3()
	add_child_autofree(panel)
	_complete_world_1_and_2_3()
	GameState.mark_level_completed(&"2-boss")
	assert_eq(panel.level_text(boss), "Jefe: La Curadora - Bloqueado", "Antes del 3-3")
	assert_false(HubWorlds.can_enter(&"3-boss"))
	_complete_worlds_1_2_and_3_3()
	assert_eq(panel.level_text(boss), "Jefe: La Curadora - Nuevo", "Tras el 3-3")
	assert_true(HubWorlds.can_enter(&"3-boss"))
	assert_eq(HubWorlds.folder_state(_m3()), HubWorlds.STATE_AVAILABLE, "Sin el jefe la carpeta no se completa")
	var m4: Dictionary = HubWorlds.world(&"m4")
	assert_eq(m4.get("unlocked_by", []), ["3-boss"], "El Mundo 4 se abre con La Curadora")
	assert_false(HubWorlds.is_world_unlocked(m4), "Mundo 4 bloqueado antes del jefe")
	assert_false(HubWorlds.is_hub_upgrade_pending(), "Sin acertijo antes del jefe")
	GameState.mark_level_completed(&"3-boss")
	# Paso 5 de docs/propuesta-hub-mundos-4-6.md: vencerla deja el acertijo del hub
	# pendiente; M4 sigue oculto hasta instalar el upgrade (y el album, cerrado).
	assert_true(HubWorlds.is_hub_upgrade_pending(), "Acertijo del hub pendiente al vencerla")
	assert_eq(HubWorlds.folder_state(m4), HubWorlds.STATE_HIDDEN, "Mundo 4 oculto hasta instalar")
	assert_false(NotasAlbum.is_world_visited(4), "El album no abre «El Chat» hasta instalar")
	for entry: Dictionary in HubWorlds.folder_worlds():
		assert_ne(String(entry.get("id", "")), "m4", "El Mundo 4 no tiene carpeta en la pagina 1")
	GameState.install_hub_upgrade(&"hub_update_4_6")
	assert_true(HubWorlds.is_world_unlocked(m4), "Mundo 4 desbloqueado al instalar (unlocked_by 3-boss)")
	assert_true(NotasAlbum.is_world_visited(4), "El album abre la carpeta «El Chat»")


func test_green_piece_hidden_then_blinking_then_lit() -> void:
	_complete_world_1_and_2_3()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_piece_animation(3), &"hidden", "Mundo 3 bloqueado: pieza gris")
	_hub.free()
	GameState.mark_level_completed(&"2-boss")
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_piece_animation(2), &"on", "La ambar sigue encendida")
	assert_eq(_hub.get_piece_animation(3), &"off", "Mundo 3 desbloqueado: contorno verde")
	_hub.free()
	_complete_worlds_1_2_and_3_3()
	GameState.mark_level_completed(&"3-boss")
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_eq(_hub.get_piece_animation(3), &"on", "La Curadora vencida: pieza verde encendida")
	assert_eq(_hub.get_background_state(), &"on", "La cian sigue en el fondo")


## Terminado cuando (paso 17): desde la carpeta M3 se entra a «Jefe: La Curadora», se vence, se recibe
## boss_w3_l1 sin guardar (panel «Recuerdo recuperado» / «Fragmento de imagen» / «Capa: Caché») y se vuelve al
## hub con la pieza verde encendida, el acertijo del hub pendiente (M4 oculto) y la placa «!» en Notas.
func test_curator_from_the_m3_folder_and_back_with_the_green_piece() -> void:
	EcoTextBox.pause_important = false
	BossReward.pause_tree = false
	BossDefeat.freeze_tree = false
	EcoProgress.meet_eco_with_pulse()
	_complete_worlds_1_2_and_3_3()
	GameState.request_save()
	var main: LevelRunner = _start_main("hub")
	var hub: HubRoom = main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	var folder: FolderStation = hub.get_folder(&"m3")
	assert_true(folder.open(hub.get_isak()), "La carpeta del Mundo 3 se abre")
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	assert_true(panel.select_option(&"3-boss"), "Fila del jefe elegible")
	panel.confirm()
	assert_true(panel.is_confirming_unsaved())
	assert_true(panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED))
	panel.confirm()
	hub.get_departure_vortex().advance(LONG_STEP_S)
	await wait_process_frames(2)
	main.advance(LONG_STEP_S)
	main.advance(LONG_STEP_S)
	assert_eq(main.get_level_id(), "3-boss", "Entra a la arena de La Curadora")
	assert_eq(GameState.lives, GameState.lives_max, "Tres vidas por intento")
	main.auto_advance = true
	var boss := main.get_level().get_node(^"Objects/curator") as Curator
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	if not boss.is_fighting():
		boss.start()
	var hud := main.get_level().get_node_or_null(^"Hud") as Hud
	assert_not_null(hud, "HUD de la arena")
	var bar: BossBar = hud.get_boss_bar() if hud != null else null
	if bar != null:
		assert_true(bar.visible, "Barra del jefe en el HUD")
		assert_eq(bar.get_style(), "portrait", "Barra «retrato»")
	var guard: int = 0
	while not boss.is_defeated() and guard < 40:
		boss.take_core_hit(1)
		guard += 1
	assert_true(boss.is_defeated(), "Golpe final (simulado con la API del jefe)")
	await wait_physics_frames(2)
	if bar != null:
		assert_eq(bar.get_frame_cracks(), 3, "Marco agrietado entero en el golpe final")
	var defeat: BossDefeat = boss.get_defeat()
	assert_not_null(defeat, "Secuencia de derrota")
	var texts: Dictionary = {}
	var t: float = 0.0
	while t < 25.0 and is_instance_valid(defeat) and defeat.get_stage() < BossDefeat.Stage.DONE:
		var reward: BossReward = defeat.get_reward()
		if reward != null and texts.is_empty():
			for key: StringName in [&"system", &"header", &"title", &"layer", &"notice"]:
				texts[key] = reward.get_text(key)
		if reward != null and reward.can_close():
			reward.confirm()
		await wait_physics_frames(1)
		t += DT
	assert_eq(texts.get(&"header", ""), "Recuerdo recuperado")
	assert_eq(texts.get(&"title", ""), "Fragmento de imagen")
	assert_eq(texts.get(&"layer", ""), "Capa: Caché")
	assert_eq(texts.get(&"notice", ""), "Guarda en Notas para conservarlo.")
	assert_eq(texts.get(&"system", ""), "Filtro: eliminado.")
	assert_true(GameState.has_memory(&"boss_w3_l1"), "Capa Caché del Mundo 3")
	assert_false(GameState.has_memory(&"boss_w3_l2"), "Solo la capa del acceso actual")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar: se guarda en Notas")
	t = 0.0
	while t < 8.0 and not main.is_in_hub():
		await wait_physics_frames(1)
		t += DT
	assert_true(main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"3-boss"))
	hub = main.get_hub()
	assert_true(hub.light_piece_on_arrival)
	assert_eq(hub.light_piece_world, 3, "Se enciende la pieza del Mundo 3")
	watch_signals(hub)
	t = 0.0
	while t < 10.0 and (hub.get_piece_animation(3) != &"on" or hub.is_piece_lighting() or hub.is_piece_pending()):
		await wait_physics_frames(1)
		t += DT
	assert_eq(hub.get_piece_animation(3), &"on", "Pieza verde encendida")
	assert_eq(hub.get_piece_animation(2), &"on", "La ambar sigue encendida")
	assert_eq(hub.get_background_state(), &"on", "La cian sigue encendida")
	assert_signal_emitted_with_parameters(hub, "wallpaper_piece_lit", [3])
	assert_true(HubWorlds.is_hub_upgrade_pending(), "Acertijo del hub pendiente (paso 5 de la propuesta 4-6)")
	assert_eq(HubWorlds.folder_state(HubWorlds.world(&"m4")), HubWorlds.STATE_HIDDEN, "Mundo 4 oculto hasta instalar")
	assert_eq(hub.get_page_state(2), HubRoom.PAGE_INSTALLING, "Pagina 2 «en instalacion»")
	assert_false(NotasAlbum.is_world_visited(4), "«El Chat» cerrada en el album hasta instalar")
	assert_true(GameState.has_unread_memories(), "Recuerdo sin leer")
	assert_true(hub.get_notas().is_unread_badge_visible(), "Placa «!» en Notas")
	EcoTextBox.pause_important = true
	BossReward.pause_tree = true
	BossDefeat.freeze_tree = true


## Linea de Calc (§2.3, paso 17): al llegar del 3-1 con Calc conocida, una vez por partida, en su LCD.
func test_calc_remark_after_3_1_once() -> void:
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.arrived_from_level = "3-1"
	add_child(_hub)
	assert_true(_hub.pending_calc_remark().is_empty(), "Sin Calc conocida no hay comentario")
	_hub.free()
	EcoProgress.meet_calc()
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.arrived_from_level = "2-3"
	add_child(_hub)
	assert_true(_hub.pending_calc_remark().is_empty(), "Solo al llegar del 3-1")
	_hub.free()
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.arrived_from_level = "3-1"
	add_child(_hub)
	assert_true(_hub.start_calc_remark(), "Calc comenta los likes")
	assert_eq(_hub.get_text_box().get_speaker_id(), &"calc", "Con su estilo LCD")
	assert_string_contains(_hub.get_text_box().get_text(), "Likes canjeables: 0.")
	assert_false(_hub.start_calc_remark(), "Una sola vez")
	assert_true(GameState.is_notice_seen(&"calc_remark_likes_3_1"))
