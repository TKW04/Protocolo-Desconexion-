# Estacion «copia local» del hub real (CopyLocalStation + CopyLocalPanel; paso
# 6 de docs/propuesta-hub-y-guardado.md §6.2): el pulso abre el panel con el
# resumen (ultimo nivel, puntos, vuelta, ultima copia, «Sin guardar» en ambar);
# Guardar pide confirmacion y escribe con GameState.save_game() en la ruta de
# pruebas; despues el indicador del HUD se apaga. Sin cambios no escribe.
# Nunca toca el user://save.json del jugador.
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_copy_local.json"
const T: float = 64.0

var _hub: HubRoom
var _station: CopyLocalStation
var _panel: CopyLocalPanel
var _isak: Isak
var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_isak = _hub.get_isak()
	_isak.input = PlayerInput.new()
	_station = _hub.get_station(&"copia_local") as CopyLocalStation
	_panel = _station.get_copy_panel() if _station != null else null


func after_each() -> void:
	if is_instance_valid(_hub):
		_hub.free()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _progress() -> void:
	GameState.current_level = &"1-1"
	GameState.attention_points = 9
	GameState.mark_level_completed(&"1-1")


func _open_with_pulse() -> void:
	_isak.global_position = Vector2(2.6 * T, _hub.get_floor_y())
	_isak.facing = -1.0
	await wait_physics_frames(6)
	_station.advance(0.1)
	_isak.set_pulse_area_active(true)


func test_copy_local_is_in_the_hub_next_to_p() -> void:
	assert_not_null(_station, "Estacion copia_local")
	assert_eq(_station.position, Vector2(1.0 * T, 7.0 * T), "Celdas (1, 7-8)")
	assert_eq(_station.position.y + _station.get_size().y, _hub.get_floor_y(), "Apoyada en el dock")
	assert_true(_hub.can_save_now())
	assert_true(QuitGuard.can_save_here(get_tree()), "El aviso al salir ofrece guardar en el hub")


func test_pulse_opens_the_summary_with_isak_facing_back() -> void:
	_progress()
	await _open_with_pulse()
	assert_true(_station.is_panel_open(), "El pulso abre el panel")
	assert_true(_isak.is_facing_back())
	assert_eq(_panel.get_mode(), CopyLocalPanel.Mode.SUMMARY)
	assert_eq(_panel.get_title(), "Copia local")
	assert_eq(_panel.get_lines(), PackedStringArray([
		"Último nivel: Bandeja de entrada (1-1)",
		"Puntos de atención: 9",
		"Acceso: Caché",
		"Última copia: nunca",
		"Sin guardar"]))
	_assert_no_internal_lap_words(_panel.get_lines())
	assert_eq(_panel.get_line_color(4), Color.html("#ffa000"), "Sin guardar en ambar")
	assert_eq(_panel.get_option_ids(), [CopyLocalPanel.OPTION_SAVE, CopyLocalPanel.OPTION_BACK] as Array[StringName])


func test_save_asks_for_confirmation_then_writes_and_clears_the_indicator() -> void:
	_progress()
	var hud: Hud = _hub.get_hud()
	assert_true(hud.is_unsaved_indicator_shown(), "Indicador encendido antes de guardar")
	await _open_with_pulse()
	_panel.select_option(CopyLocalPanel.OPTION_SAVE)
	_panel.confirm()
	assert_eq(_panel.get_mode(), CopyLocalPanel.Mode.CONFIRM, "Pide confirmacion")
	assert_eq(_panel.get_title(), "¿Guardar copia local?")
	assert_false(FileAccess.file_exists(PATH), "Aun no escribe")
	_panel.select_option(CopyLocalPanel.OPTION_YES)
	_panel.confirm()
	assert_true(FileAccess.file_exists(PATH), "Escribe en la ruta de pruebas")
	assert_eq(GameState.save_path, PATH)
	assert_false(GameState.has_unsaved_changes())
	assert_false(hud.is_unsaved_indicator_shown(), "El indicador del HUD se apaga")
	assert_eq(_panel.get_lines()[4], "Todo guardado")
	assert_eq(_panel.get_message(), "Copia guardada")
	assert_eq(_panel.get_mode(), CopyLocalPanel.Mode.SUMMARY)
	assert_eq(_panel.get_save_count(), 1)
	assert_true(_station.is_flashing(), "Destello cian del monitor")
	assert_ne(_panel.get_lines()[3], "Última copia: nunca", "Muestra la fecha de la copia")
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data.get("attention_points", -1)), 9)


func test_nothing_to_save_does_not_write() -> void:
	await _open_with_pulse()
	assert_false(GameState.has_unsaved_changes())
	assert_eq(_panel.get_lines()[4], "Todo guardado")
	_panel.select_option(CopyLocalPanel.OPTION_SAVE)
	_panel.confirm()
	assert_eq(_panel.get_mode(), CopyLocalPanel.Mode.SUMMARY, "Sin confirmacion")
	assert_eq(_panel.get_message(), "Todo está guardado")
	assert_false(FileAccess.file_exists(PATH), "No escribe")


func test_no_and_jump_in_the_confirmation_go_back_without_saving() -> void:
	_progress()
	await _open_with_pulse()
	_panel.select_option(CopyLocalPanel.OPTION_SAVE)
	_panel.confirm()
	_panel.select_option(CopyLocalPanel.OPTION_NO)
	_panel.confirm()
	assert_eq(_panel.get_mode(), CopyLocalPanel.Mode.SUMMARY)
	_panel.select_option(CopyLocalPanel.OPTION_SAVE)
	_panel.confirm()
	_panel.cancel()
	assert_eq(_panel.get_mode(), CopyLocalPanel.Mode.SUMMARY, "Salto vuelve al resumen")
	assert_true(_station.is_panel_open(), "Sin cerrar el panel")
	assert_false(FileAccess.file_exists(PATH))
	assert_true(GameState.has_unsaved_changes())


func test_back_closes_and_returns_control() -> void:
	await _open_with_pulse()
	_panel.select_option(CopyLocalPanel.OPTION_BACK)
	_panel.confirm()
	assert_false(_station.is_panel_open())
	await wait_physics_frames(4)
	assert_false(_isak.is_facing_back(), "Isak vuelve de perfil")
	_panel.cancel()
	assert_false(_station.is_panel_open(), "Cerrado sigue cerrado")


## La UI nunca dice vuelta ni Easy/Normal/Hard (decision del 2026-10-15).
func _assert_no_internal_lap_words(lines: PackedStringArray) -> void:
	for line: String in lines:
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(line.contains(word), "«%s» no dice «%s»" % [line, word])
