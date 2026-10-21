# Fila del jefe «Alerta Mayor» en la carpeta del Mundo 1 (paso 1 de
# docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21): entrada 1-boss de
# data/hub.json (kind boss, no jugable aun: «Próximamente»), texto «Jefe: »
# sin id ni puntos, desbloqueo por la terminal del 1-3 (unlocks), y la carpeta
# no pasa a completed ni se enciende la pieza cian del hub hasta vencer al
# jefe. Los 1-1 a 1-3 siguen igual. Usa su propia ruta de guardado.
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


func test_entry_is_the_last_row_of_m1_and_a_boss_not_yet_playable() -> void:
	var boss: Dictionary = _boss()
	assert_false(boss.is_empty(), "1-boss registrado en m1")
	var levels: Array[Dictionary] = HubWorlds.levels(_m1())
	assert_eq(String(levels[levels.size() - 1].get("id", "")), "1-boss", "Tras el 1-3")
	assert_eq(String(boss.get("name", "")), "Alerta Mayor")
	assert_true(HubWorlds.is_boss(boss))
	assert_eq(boss.get("laps", []), [1.0], "Solo en Caché por ahora")
	assert_false(HubWorlds.is_playable(boss), "playable: false hasta el paso 13")
	assert_true(HubWorlds.is_coming_soon(boss))
	for level: Dictionary in levels:
		if String(level.get("id", "")) != "1-boss":
			assert_false(HubWorlds.is_boss(level), "%s no es jefe" % level.get("id", ""))
			assert_true(HubWorlds.is_playable(level), "%s sigue jugable" % level.get("id", ""))


func test_terminal_of_1_3_unlocks_the_boss_row() -> void:
	assert_false(GameState.is_level_unlocked(&"1-boss"))
	_complete_1_3_like_the_terminal()
	assert_true(GameState.is_level_unlocked(&"1-boss"), "unlocks del 1-3")
	# No jugable: sigue «Próximamente» y no se entra.
	assert_eq(HubWorlds.level_state(_m1(), _boss()), HubWorlds.STATE_LOCKED)
	assert_false(HubWorlds.can_enter(&"1-boss"))
	assert_ne(HubWorlds.most_advanced_level(), &"1-boss", "R no reanuda un jefe no jugable")


func test_panel_text_has_boss_prefix_and_no_points() -> void:
	var panel: FolderPanel = _panel()
	assert_eq(panel.level_text(_boss()), "Jefe: Alerta Mayor - Próximamente", "Partida nueva")
	_complete_1_3_like_the_terminal()
	assert_eq(panel.level_text(_boss()), "Jefe: Alerta Mayor - Próximamente", "Tras el 1-3, aun sin arena")
	assert_eq(HubWorlds.level_points_total("1-boss"), 0, "La arena no tiene puntos")
	GameState.mark_level_completed(&"1-boss")
	# Con el jefe completado (y jugable, en el futuro) el texto no lleva puntos.
	var playable_boss: Dictionary = _boss().duplicate()
	playable_boss["playable"] = true
	var text: String = panel.level_text(playable_boss)
	assert_true(text.begins_with("Jefe: Alerta Mayor - "), text)
	assert_false(text.contains("/"), "Sin puntos: %s" % text)
	assert_false(text.contains("1-boss"), "Sin id: %s" % text)
	for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
		assert_false(text.contains(word))


func test_other_rows_do_not_change() -> void:
	var panel: FolderPanel = _panel()
	_complete_1_3_like_the_terminal()
	var levels: Array[Dictionary] = HubWorlds.levels(_m1())
	assert_eq(panel.level_text(levels[0]), "1-1 Bandeja de entrada - Completado 0/9")
	assert_eq(panel.level_text(levels[2]), "1-3 No molestar - Completado 0/9")


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
