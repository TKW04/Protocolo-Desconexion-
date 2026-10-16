# Estacion «copia local» del hub real (NotasStation + NotasPanel; paso
# 6 de docs/propuesta-hub-y-guardado.md §6.2): el pulso abre el panel con el
# resumen (ultimo nivel, puntos, vuelta, ultima copia, «Sin guardar» en ambar);
# Guardar pide confirmacion y escribe con GameState.save_game() en la ruta de
# pruebas; despues el indicador del HUD se apaga. Sin cambios no escribe.
# Nunca toca el user://save.json del jugador.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_copy_local.json"
const T: float = 64.0

var _hub: HubRoom
var _station: NotasStation
var _panel: NotasPanel
var _isak: Isak
var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_isak = _hub.get_isak()
	_isak.input = PlayerInput.new()
	_station = _hub.get_station(&"notas") as NotasStation
	_panel = _station.get_notas_panel() if _station != null else null


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


func test_notas_is_in_the_hub_next_to_p() -> void:
	assert_not_null(_station, "Estacion notas")
	assert_true(_station.is_powered(), "Encendida (Notas conocida)")
	assert_null(_hub.get_notas_intro(), "Sin presentacion: Notas ya era conocida")
	assert_eq(_station.position, Vector2(1.0 * T, 7.0 * T), "Celdas (1, 7-8)")
	assert_eq(_station.position.y + _station.get_size().y, _hub.get_floor_y(), "Apoyada en el dock")
	assert_true(_hub.can_save_now())
	assert_true(QuitGuard.can_save_here(get_tree()), "El aviso al salir ofrece guardar en el hub")


func test_pulse_opens_the_summary_with_isak_facing_back() -> void:
	_progress()
	await _open_with_pulse()
	assert_true(_station.is_panel_open(), "El pulso abre el panel")
	assert_true(_isak.is_facing_back())
	assert_eq(_panel.get_mode(), NotasPanel.Mode.SUMMARY)
	assert_eq(_panel.get_title(), "Notas")
	assert_eq(_panel.get_lines(), PackedStringArray([
		"Último nivel: Bandeja de entrada (1-1)",
		"Puntos de atención: 9",
		"Acceso: Caché",
		"Última copia: nunca",
		"Sin guardar"]))
	_assert_no_internal_lap_words(_panel.get_lines())
	assert_eq(_panel.get_line_color(4), Color.html("#ffa000"), "Sin guardar en ambar")
	assert_eq(_panel.get_option_ids(), [NotasPanel.OPTION_SAVE, NotasPanel.OPTION_ALBUM, NotasPanel.OPTION_NICKNAME,
		NotasPanel.OPTION_BACK] as Array[StringName], "Guardar / Álbum / Apodo / Volver")


func test_save_asks_for_confirmation_then_writes_and_clears_the_indicator() -> void:
	_progress()
	var hud: Hud = _hub.get_hud()
	assert_true(hud.is_unsaved_indicator_shown(), "Indicador encendido antes de guardar")
	await _open_with_pulse()
	_panel.select_option(NotasPanel.OPTION_SAVE)
	_panel.confirm()
	assert_eq(_panel.get_mode(), NotasPanel.Mode.CONFIRM, "Pide confirmacion")
	assert_eq(_panel.get_title(), "¿Guardar en Notas?")
	assert_false(FileAccess.file_exists(PATH), "Aun no escribe")
	_panel.select_option(NotasPanel.OPTION_YES)
	_panel.confirm()
	assert_true(FileAccess.file_exists(PATH), "Escribe en la ruta de pruebas")
	assert_eq(GameState.save_path, PATH)
	assert_false(GameState.has_unsaved_changes())
	assert_false(hud.is_unsaved_indicator_shown(), "El indicador del HUD se apaga")
	assert_eq(_panel.get_lines()[4], "Todo guardado")
	assert_eq(_panel.get_message(), "Apuntado. Copia guardada")
	assert_eq(_panel.get_mode(), NotasPanel.Mode.SUMMARY)
	assert_eq(_panel.get_save_count(), 1)
	assert_true(_station.is_flashing(), "Destello cian del monitor")
	assert_ne(_panel.get_lines()[3], "Última copia: nunca", "Muestra la fecha de la copia")
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data.get("attention_points", -1)), 9)


func test_nothing_to_save_does_not_write() -> void:
	await _open_with_pulse()
	assert_false(GameState.has_unsaved_changes())
	assert_eq(_panel.get_lines()[4], "Todo guardado")
	_panel.select_option(NotasPanel.OPTION_SAVE)
	_panel.confirm()
	assert_eq(_panel.get_mode(), NotasPanel.Mode.SUMMARY, "Sin confirmacion")
	assert_eq(_panel.get_message(), "Todo está guardado")
	assert_false(FileAccess.file_exists(PATH), "No escribe")


func test_no_and_jump_in_the_confirmation_go_back_without_saving() -> void:
	_progress()
	await _open_with_pulse()
	_panel.select_option(NotasPanel.OPTION_SAVE)
	_panel.confirm()
	_panel.select_option(NotasPanel.OPTION_NO)
	_panel.confirm()
	assert_eq(_panel.get_mode(), NotasPanel.Mode.SUMMARY)
	_panel.select_option(NotasPanel.OPTION_SAVE)
	_panel.confirm()
	_panel.cancel()
	assert_eq(_panel.get_mode(), NotasPanel.Mode.SUMMARY, "Salto vuelve al resumen")
	assert_true(_station.is_panel_open(), "Sin cerrar el panel")
	assert_false(FileAccess.file_exists(PATH))
	assert_true(GameState.has_unsaved_changes())


func test_back_closes_and_returns_control() -> void:
	await _open_with_pulse()
	_panel.select_option(NotasPanel.OPTION_BACK)
	_panel.confirm()
	assert_false(_station.is_panel_open())
	await wait_physics_frames(4)
	assert_false(_isak.is_facing_back(), "Isak vuelve de perfil")
	_panel.cancel()
	assert_false(_station.is_panel_open(), "Cerrado sigue cerrado")


func test_album_option_hides_the_panel_and_jump_brings_it_back() -> void:
	await _open_with_pulse()
	_panel.select_option(NotasPanel.OPTION_ALBUM)
	_panel.confirm()
	assert_true(_station.is_album_open(), "Se abre el album")
	assert_false(_panel.is_open(), "El panel se oculta")
	assert_true(_isak.is_facing_back(), "Isak sigue de espaldas")
	var album: NotasAlbum = _station.get_album()
	album.cancel()
	assert_false(_station.is_album_open())
	assert_true(_panel.is_open(), "Vuelve el panel")
	assert_eq(_panel.get_selected_option(), NotasPanel.OPTION_ALBUM, "Con Álbum elegido")


func test_nickname_option_opens_the_entry_and_returns_to_the_panel() -> void:
	await _open_with_pulse()
	_panel.select_option(NotasPanel.OPTION_NICKNAME)
	_panel.confirm()
	var entry: NicknameEntry = _station.get_nickname_entry()
	assert_not_null(entry, "Abre la entrada del apodo")
	assert_false(_panel.is_open())
	entry.type_text("Kai")
	entry.accept()
	await wait_frames(2)
	assert_eq(GameState.get_nickname(), "Kai")
	assert_true(GameState.has_unsaved_changes(), "Cambiar el apodo marca «sin guardar»")
	assert_false(get_tree().paused, "La entrada libera la pausa")
	assert_true(_panel.is_open(), "Vuelve el panel")


func test_texts_never_say_lap_names() -> void:
	for section: String in ["notas", "notas_intro", "album", "calc"]:
		_assert_no_internal_lap_words(_strings(HubData.section(section)))


func _strings(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is String:
		out.append(value)
	elif value is Dictionary:
		for key: Variant in value:
			if not String(key).begins_with("_"):
				out.append_array(_strings(value[key]))
	elif value is Array:
		for item: Variant in value:
			out.append_array(_strings(item))
	return out


## La UI nunca dice vuelta ni Easy/Normal/Hard (decision del 2026-10-15).
func _assert_no_internal_lap_words(lines: PackedStringArray) -> void:
	for line: String in lines:
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(line.contains(word), "«%s» no dice «%s»" % [line, word])
