# Desbloqueos derivados del progreso (2026-10-21): un guardado escrito antes de
# que existiera el jefe (1-1 a 1-3 completados, sin 1-boss en unlocked_levels)
# muestra «Jefe: Alerta Mayor - Nuevo», porque HubWorlds lee los `unlocks` de
# los subniveles completados (docs/propuesta-jefe-alerta-mayor.md §6, paso 13).
# Sin el 1-3 sigue Bloqueado; con el jefe vencido, Completado. El Mundo 2 sigue
# bloqueado hasta vencer al jefe. Usa su propia ruta de guardado.
extends GutTest

const PATH: String = "user://test_hub_legacy_unlocks.json"

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)


func after_each() -> void:
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _m1() -> Dictionary:
	return HubWorlds.world(&"m1")


func _boss() -> Dictionary:
	for level: Dictionary in HubWorlds.levels(_m1()):
		if String(level.get("id", "")) == "1-boss":
			return level
	return {}


## Escribe un guardado v5 como el de una partida anterior al jefe y lo carga.
func _load_legacy(completed: Array, unlocked: Array) -> void:
	var data: Dictionary = {
		"version": GameState.SAVE_VERSION,
		"lap": 1,
		"completed_levels": completed,
		"unlocked_levels": unlocked,
		"allies_met": ["eco", "notas", "calc"],
		"abilities_obtained": ["pulse", "laser", "debug", "dash"],
		"nickname": "Isak",
	}
	assert_true(SaveFile.write(PATH, data), "Guardado de prueba escrito")
	GameState.use_save_path(PATH, false)
	assert_true(GameState.started_from_save, "Se carga el guardado")


func _panel() -> FolderPanel:
	var panel := FolderPanel.new()
	panel.world_entry = _m1()
	add_child_autofree(panel)
	return panel


func test_legacy_save_with_1_3_completed_shows_boss_as_new() -> void:
	_load_legacy(["1-1", "1-2", "1-3"], ["1-2", "1-3"])
	assert_false(GameState.is_level_unlocked(&"1-boss"), "El guardado no lo trae")
	assert_eq(HubWorlds.level_state(_m1(), _boss()), HubWorlds.STATE_AVAILABLE, "Derivado del 1-3 completado")
	assert_eq(_panel().level_text(_boss()), "Jefe: Alerta Mayor - Nuevo")
	assert_true(HubWorlds.can_enter(&"1-boss"))
	assert_eq(HubWorlds.most_advanced_level(), &"1-boss")
	assert_eq(HubWorlds.folder_state(HubWorlds.world(&"m2")), HubWorlds.STATE_LOCKED, "Mundo 2 hasta vencer al jefe")
	assert_false(GameState.has_unsaved_changes(), "Derivar no marca «sin guardar»")


func test_save_with_boss_completed_shows_completed() -> void:
	_load_legacy(["1-1", "1-2", "1-3", "1-boss"], ["1-2", "1-3"])
	assert_eq(HubWorlds.level_state(_m1(), _boss()), HubWorlds.STATE_COMPLETED)
	assert_string_starts_with(_panel().level_text(_boss()), "Jefe: Alerta Mayor - Completado")
	assert_ne(HubWorlds.folder_state(HubWorlds.world(&"m2")), HubWorlds.STATE_LOCKED, "Mundo 2 tras el jefe")


func test_save_without_1_3_keeps_boss_locked() -> void:
	_load_legacy(["1-1", "1-2"], ["1-2", "1-3"])
	assert_eq(HubWorlds.level_state(_m1(), _boss()), HubWorlds.STATE_LOCKED)
	assert_eq(_panel().level_text(_boss()), "Jefe: Alerta Mayor - Bloqueado")
	assert_false(HubWorlds.can_enter(&"1-boss"))
	var levels: Array[Dictionary] = HubWorlds.levels(_m1())
	assert_eq(HubWorlds.level_state(_m1(), levels[1]), HubWorlds.STATE_COMPLETED, "1-2 sin cambios")
	assert_eq(HubWorlds.level_state(_m1(), levels[2]), HubWorlds.STATE_AVAILABLE, "1-3 sin cambios")


func test_derived_from_completed_even_without_unlocked_levels() -> void:
	# Sin unlocked_levels: cada subnivel sale de los unlocks del anterior completado.
	_load_legacy(["1-1"], [])
	var levels: Array[Dictionary] = HubWorlds.levels(_m1())
	assert_eq(HubWorlds.level_state(_m1(), levels[1]), HubWorlds.STATE_AVAILABLE, "1-2 por los unlocks del 1-1")
	assert_eq(HubWorlds.level_state(_m1(), levels[2]), HubWorlds.STATE_LOCKED, "1-3 hasta completar el 1-2")
	assert_eq(HubWorlds.level_state(_m1(), _boss()), HubWorlds.STATE_LOCKED)
