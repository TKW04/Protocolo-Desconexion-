# Datos y guardado del upgrade del hub (paso 0 de docs/propuesta-hub-mundos-4-6.md,
# 2026-10-27; decisiones del usuario del mismo dia): m4-m6 con page, col,
# requires_upgrade hub_update_4_6 y unlocked_by en orden (3-boss, 4-boss,
# 5-boss); GameState.hub_upgrades (guardado v6) con migracion desde v5;
# install_hub_upgrade solo marca «sin guardar»; un game over sin guardar lo
# pierde (el acertijo vuelve a estar pendiente); guardado, vuelve con la copia y
# no va a la Papelera; el cambio de vuelta (Kernel y Raiz) lo conserva. Con
# hub_upgrades.enforce_requires_upgrade false (TEMPORAL, hasta que el acertijo
# exista en el hub) M4 se comporta como hasta hoy. Usa su propia ruta de guardado.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_hub_worlds_4_6.json"
const UPGRADE: StringName = &"hub_update_4_6"

var _saved_path: String
var _saved_pulse: bool
var _installed: Array[StringName] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	_installed.clear()
	EventBus.hub_upgrade_installed.connect(_on_installed)


func after_each() -> void:
	EventBus.hub_upgrade_installed.disconnect(_on_installed)
	HubWorlds.requires_upgrade_override = -1
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _on_installed(id: StringName) -> void:
	_installed.append(id)


func _w(id: StringName) -> Dictionary:
	return HubWorlds.world(id)


func _ids(entries: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in entries:
		out.append(String(entry.get("id", "")))
	return out


# --- Datos ---

func test_data_of_worlds_4_to_6() -> void:
	assert_eq(GameState.HUB_UPGRADE_UPDATE_4_6, UPGRADE)
	var expected: Dictionary = {
		&"m4": [2, 4, ["3-boss"]],
		&"m5": [2, 14, ["4-boss"]],
		&"m6": [3, 9, ["5-boss"]],
	}
	for id: StringName in expected:
		var entry: Dictionary = _w(id)
		var want: Array = expected[id]
		assert_eq(HubWorlds.world_page(entry), want[0], "%s: pagina" % id)
		assert_eq(int(entry.get("col", -1)), want[1], "%s: columna" % id)
		assert_eq(entry.get("unlocked_by", []), want[2], "%s: unlocked_by en orden" % id)
		assert_eq(HubWorlds.required_upgrade(entry), UPGRADE, "%s: requires_upgrade" % id)
	for id: StringName in [&"m1", &"m2", &"m3"]:
		assert_eq(HubWorlds.world_page(_w(id)), 1, "%s en la pagina 1" % id)
		assert_eq(HubWorlds.required_upgrade(_w(id)), &"", "%s sin requisito" % id)


func test_folder_worlds_by_page() -> void:
	assert_eq(_ids(HubWorlds.folder_worlds()), ["m1", "m2", "m3"] as Array[String], "El hub de hoy: pagina 1")
	assert_eq(_ids(HubWorlds.folder_worlds(2)), ["m4", "m5"] as Array[String])
	assert_eq(_ids(HubWorlds.folder_worlds(3)), ["m6"] as Array[String])


func test_temporary_flag_keeps_world_4_as_today() -> void:
	assert_false(HubWorlds.is_requires_upgrade_enforced(), "TEMPORAL: aun no se aplica (no se puede instalar)")
	assert_false(HubWorlds.is_world_unlocked(_w(&"m4")), "Bloqueado antes de La Curadora")
	GameState.mark_level_completed(&"3-boss")
	assert_true(HubWorlds.is_world_unlocked(_w(&"m4")), "Como hoy: desbloqueado con 3-boss")
	assert_true(NotasAlbum.is_world_visited(4), "Como hoy: el album abre «El Chat»")
	assert_false(HubWorlds.is_world_unlocked(_w(&"m5")), "M5 espera a 4-boss")
	assert_true(HubWorlds.is_hub_upgrade_pending(), "El acertijo ya cuenta como pendiente")


# --- Estados con el requisito aplicado ---

func test_hidden_locked_available_in_order() -> void:
	HubWorlds.requires_upgrade_override = 1
	for id: StringName in [&"m4", &"m5", &"m6"]:
		assert_eq(HubWorlds.folder_state(_w(id)), HubWorlds.STATE_HIDDEN, "%s oculto sin upgrade" % id)
	assert_false(HubWorlds.is_hub_upgrade_pending(), "Sin 3-boss no hay acertijo")
	GameState.mark_level_completed(&"3-boss")
	assert_true(HubWorlds.is_hub_upgrade_pending(), "3-boss y sin upgrade: acertijo pendiente")
	assert_eq(HubWorlds.folder_state(_w(&"m4")), HubWorlds.STATE_HIDDEN, "M4 sigue oculto hasta instalar")
	assert_false(HubWorlds.is_world_unlocked(_w(&"m4")))
	assert_false(NotasAlbum.is_world_visited(4), "«El Chat» del album sigue cerrada")
	assert_true(GameState.install_hub_upgrade(UPGRADE))
	assert_false(HubWorlds.is_hub_upgrade_pending(), "Instalado: ya no esta pendiente")
	assert_eq(HubWorlds.folder_state(_w(&"m4")), HubWorlds.STATE_AVAILABLE, "M4 disponible al instalar")
	assert_true(NotasAlbum.is_world_visited(4), "«El Chat» se abre al instalar")
	assert_eq(HubWorlds.folder_state(_w(&"m5")), HubWorlds.STATE_LOCKED, "M5 visible y bloqueado")
	assert_eq(HubWorlds.folder_state(_w(&"m6")), HubWorlds.STATE_LOCKED, "M6 visible y bloqueado")
	assert_false(NotasAlbum.is_world_visited(5))
	GameState.mark_level_completed(&"4-boss")
	assert_eq(HubWorlds.folder_state(_w(&"m5")), HubWorlds.STATE_AVAILABLE, "M5 con 4-boss")
	assert_eq(HubWorlds.folder_state(_w(&"m6")), HubWorlds.STATE_LOCKED, "M6 aun no")
	GameState.mark_level_completed(&"5-boss")
	assert_eq(HubWorlds.folder_state(_w(&"m6")), HubWorlds.STATE_AVAILABLE, "M6 con 5-boss")


func test_upgrade_without_3_boss_keeps_world_4_locked() -> void:
	HubWorlds.requires_upgrade_override = 1
	assert_true(GameState.install_hub_upgrade(UPGRADE))
	assert_eq(HubWorlds.folder_state(_w(&"m4")), HubWorlds.STATE_LOCKED, "Visible pero pide 3-boss de la vuelta")


# --- GameState y guardado ---

func test_install_marks_unsaved_once_and_rejects_unknown_ids() -> void:
	assert_false(GameState.has_unsaved_changes())
	assert_true(GameState.install_hub_upgrade(UPGRADE))
	assert_true(GameState.has_hub_upgrade(UPGRADE))
	assert_true(GameState.has_unsaved_changes(), "Instalar solo marca «sin guardar»")
	assert_false(GameState.install_hub_upgrade(UPGRADE), "Una vez")
	assert_false(GameState.install_hub_upgrade(&"otro_upgrade"), "Id desconocido")
	assert_eq(_installed, [UPGRADE] as Array[StringName], "Se anuncia una vez")
	assert_false(FileAccess.file_exists(PATH), "No escribe el disco")


func test_round_trip_v6() -> void:
	assert_eq(GameState.SAVE_VERSION, 6)
	GameState.install_hub_upgrade(UPGRADE)
	assert_true(GameState.save_game())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), 6)
	assert_eq(data["hub_upgrades"], ["hub_update_4_6"])
	GameState.reset_progress()
	assert_false(GameState.has_hub_upgrade(UPGRADE))
	assert_true(GameState.load_game())
	assert_true(GameState.has_hub_upgrade(UPGRADE), "Vuelve al cargar")
	assert_false(GameState.has_unsaved_changes())


func test_v5_save_migrates_with_empty_upgrades_and_pending_puzzle() -> void:
	SaveFile.write(PATH, {"version": 5, "lap": 1, "completed_levels": ["3-3", "3-boss"],
		"allies_met": ["eco", "notas", "calc"], "memories": ["boss_w3_l1"],
		"hub_upgrades": ["hub_update_4_6"]})
	assert_true(GameState.load_game(), "Un v5 se carga")
	assert_false(GameState.has_hub_upgrade(UPGRADE), "v5: hub_upgrades no existia (se ignora y queda vacio)")
	assert_true(GameState.is_level_completed(&"3-boss"), "No pierde nada")
	assert_true(GameState.has_memory(&"boss_w3_l1"))
	assert_true(HubWorlds.is_hub_upgrade_pending(), "Quien vencio a La Curadora ve el acertijo al cargar")
	assert_true(GameState.save_game())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data["version"]), 6, "La copia siguiente escribe la v6")
	assert_eq(data["hub_upgrades"], [])


func test_odd_hub_upgrades_are_tolerated() -> void:
	SaveFile.write(PATH, {"version": 6, "hub_upgrades": ["nada", 3, "hub_update_4_6", null]})
	assert_true(GameState.load_game())
	assert_eq(GameState.hub_upgrades.keys(), [UPGRADE], "Solo ids conocidos")
	SaveFile.write(PATH, {"version": 6, "hub_upgrades": "hub_update_4_6"})
	assert_true(GameState.load_game())
	assert_true(GameState.hub_upgrades.is_empty(), "Tipo raro: vacio")


func test_game_over_without_saving_loses_the_upgrade() -> void:
	HubWorlds.requires_upgrade_override = 1
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.mark_level_completed(&"3-boss")
	assert_true(GameState.save_game(), "Copia tras La Curadora, sin upgrade")
	assert_true(GameState.install_hub_upgrade(UPGRADE))
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.has_hub_upgrade(UPGRADE), "Sin guardar se pierde (no es excepcion)")
	assert_true(HubWorlds.is_hub_upgrade_pending(), "El acertijo se repite")
	assert_eq(HubWorlds.folder_state(_w(&"m4")), HubWorlds.STATE_HIDDEN)


func test_saved_upgrade_survives_game_over_and_is_not_trashed() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.mark_level_completed(&"3-boss")
	GameState.attention_points = 5
	GameState.install_hub_upgrade(UPGRADE)
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.has_hub_upgrade(UPGRADE), "Guardado: vuelve con la copia")
	assert_true(GameState.has_trash_pending(), "Los puntos van a la papelera")
	for key: Variant in GameState.get_trash():
		assert_false(String(key).contains("hub"), "El upgrade no va a la papelera (%s)" % key)
	assert_true(GameState.recover_trash())
	assert_true(GameState.has_hub_upgrade(UPGRADE))


func test_kernel_and_root_keep_the_upgrade() -> void:
	HubWorlds.requires_upgrade_override = 1
	GameState.mark_level_completed(&"3-boss")
	GameState.install_hub_upgrade(UPGRADE)
	for lap: int in [GameState.LAP_NORMAL, GameState.LAP_HARD]:
		# Cambio de vuelta como lo hara el rollback de fin de vuelta (paso 16 de
		# asistentes, sin implementar): hub_upgrades no se toca.
		GameState.lap = lap
		assert_true(GameState.save_game())
		assert_true(GameState.load_game())
		assert_eq(GameState.lap, lap)
		assert_true(GameState.has_hub_upgrade(UPGRADE), "Acceso %d: el upgrade se conserva" % lap)
		assert_false(HubWorlds.is_hub_upgrade_pending(), "Acceso %d: el acertijo no se repite" % lap)
		assert_ne(HubWorlds.folder_state(_w(&"m4")), HubWorlds.STATE_HIDDEN, "Acceso %d: M4 visible" % lap)
