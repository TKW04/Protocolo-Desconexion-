# Game over, rollback y papelera (docs/propuesta-asistentes-y-vidas.md §2.5, §5.2
# y §5.3, paso 12 de §10): GameState.apply_rollback (la regla unica que usara el
# rollback del jefe final) vuelve a la ultima copia guardada (lo posterior se
# pierde y los niveles completados despues se revierten), nunca quita el
# registro (Eco, Notas, Calc, apodo, ayudas) ni el pulso, deja lo guardado en
# la papelera y se recupera todo de golpe; sin copia, «nada guardado» y la
# papelera se activa vacia. Mientras la papelera tiene contenido: carpetas
# bloqueadas, Notas no guarda y QuitGuard sale sin aviso ni escritura. En el
# hub: lineas de Eco (data/game_over.json), papelera que parpadea y se recupera
# al acercarse.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_game_over.json"
const T: float = 64.0
const FORBIDDEN: Array[String] = ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]

var _saved_path: String
var _saved_pulse: bool
var _saved_laser: bool
var _saved_pause_important: bool
var _hub: HubRoom
var _guard: QuitGuard
var _quits: int = 0


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_laser = GameState.is_ability_unlocked(GameState.ABILITY_LASER)
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	GameState.use_save_path(PATH, true)
	_quits = 0


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	if is_instance_valid(_guard):
		_guard.free()
	_guard = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved_laser)


# --- Utilidades ---

## Mejora de la copia: Energia 3 (tanda M1: niveles por pista; maximo 120).
func _upgrade_id() -> StringName:
	return &"energia:3"


## Partida con Eco, Notas y pulso; laser, 9 puntos, dos power banks (completos:
## coleccionable puro desde el 2026-10-25), una mejora y el 1-1 completado; GUARDADA.
func _saved_progress() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.obtain_ability(GameState.ABILITY_LASER)
	GameState.attention_points = 9
	GameState.power_banks = 2
	GameState.upgrade_levels[&"energia"] = 3
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	GameState.capture_attention_point(&"1-1", &"p1", 0)
	assert_true(GameState.save_game(), "Copia guardada")


## Progreso DESPUES de guardar (se pierde con el game over) y registro (no).
func _progress_after_save() -> void:
	GameState.attention_points += 4
	GameState.mark_level_completed(&"1-2")
	GameState.capture_attention_point(&"1-2", &"p9", 0)
	GameState.mark_secret_found(&"1-2", &"s1")
	GameState.learn_help(&"charger")
	GameState.meet_ally(GameState.ALLY_CALC)


func _spawn_hub(report: Dictionary) -> void:
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.rollback_report = report
	add_child(_hub)
	_hub.get_isak().input = PlayerInput.new()


func _arrive() -> void:
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)


func _close_lines(count: int) -> Array[String]:
	var seen: Array[String] = []
	var box: EcoTextBox = _hub.get_text_box()
	for i: int in count:
		if box.is_showing():
			seen.append(box.get_text())
		box.finish_typing()
		box.confirm()
		box.advance(1.0)
		await get_tree().process_frame
	return seen


func _isak_at(x: float, y: float) -> void:
	var isak: Isak = _hub.get_isak()
	isak.global_position = Vector2(x, y)
	isak.velocity = Vector2.ZERO


# --- apply_rollback ---

func test_rollback_returns_to_the_last_copy_and_loses_what_came_after() -> void:
	_saved_progress()
	var disk: String = FileAccess.get_file_as_string(PATH)
	_progress_after_save()
	var report: Dictionary = GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(report["had_copy"], "Habia copia")
	assert_true(report["first"], "Primer game over")
	assert_true(report["trash_has_content"])
	assert_true(GameState.is_level_completed(&"1-1"), "Lo guardado sigue")
	assert_false(GameState.is_level_completed(&"1-2"), "El nivel completado despues de guardar hay que rejugarlo")
	assert_false(GameState.is_attention_point_captured(&"1-2", &"p9"), "Los puntos capturados despues vuelven al mapa")
	assert_false(GameState.is_secret_found(&"1-2", &"s1"), "Lo posterior se pierde")
	assert_true(GameState.is_attention_point_captured(&"1-1", &"p1"))
	assert_eq(FileAccess.get_file_as_string(PATH), disk, "El rollback no escribe el disco")
	assert_false(GameState.has_unsaved_changes(), "Tras el rollback no hay cambios pendientes")


func test_saved_things_go_to_the_trash_and_come_back_all_at_once() -> void:
	_saved_progress()
	_progress_after_save()
	GameState.apply_rollback()
	assert_true(GameState.has_trash_pending(), "Lo guardado esta en la papelera")
	assert_eq(GameState.attention_points, 0, "Isak llega sin puntos")
	assert_eq(GameState.power_banks, 0)
	assert_false(GameState.is_upgrade_purchased(_upgrade_id()), "Sin mejoras")
	assert_eq(GameState.get_upgrade_level(&"energia"), 1)
	assert_almost_eq(GameState.get_debug_energy_max(), 100.0, 0.001, "Papelera: maximo base")
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_LASER), "Sin el laser")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_LASER))
	var trash: Dictionary = GameState.get_trash()
	assert_eq(int(trash[GameState.TRASH_POINTS]), 9, "Los puntos de la copia (no los de despues)")
	assert_eq(int(trash[GameState.TRASH_POWER_BANKS]), 2)
	assert_eq(trash[GameState.TRASH_ABILITIES], ["laser"])
	assert_eq(trash[GameState.TRASH_UPGRADES], {"energia": 3}, "La papelera guarda los niveles por pista")
	assert_true(GameState.recover_trash(), "Se recupera todo de golpe")
	assert_false(GameState.has_trash_pending())
	assert_eq(GameState.attention_points, 9)
	assert_eq(GameState.power_banks, 2)
	assert_true(GameState.is_upgrade_purchased(_upgrade_id()))
	assert_eq(GameState.get_upgrade_level(&"energia"), 3, "Recupera el nivel")
	assert_almost_eq(GameState.get_debug_energy_max(), 120.0, 0.001, "y su maximo")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_LASER))
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER))
	assert_false(GameState.has_unsaved_changes(), "Igual que la copia: sin cambios pendientes")
	assert_false(GameState.recover_trash(), "No hay nada mas")


func test_registry_and_pulse_are_never_lost() -> void:
	_saved_progress()
	_progress_after_save()
	assert_true(GameState.set_nickname("Neo"))
	GameState.apply_rollback()
	assert_true(GameState.has_met_ally(GameState.ALLY_ECO), "Eco conocido")
	assert_true(GameState.has_met_ally(GameState.ALLY_NOTAS), "Notas conocida")
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC), "Calc conocida aunque fuera despues de guardar")
	assert_true(GameState.has_met_ally(GameState.ALLY_PAPELERA), "La papelera queda activada")
	assert_eq(GameState.get_nickname(), "Neo", "El apodo no se pierde")
	assert_true(GameState.is_help_learned(&"charger"), "Las ayudas aprendidas (album) no se pierden")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_PULSE), "El pulso no se pierde")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))
	assert_false(GameState.get_trash()[GameState.TRASH_ABILITIES].has("pulse"), "El pulso no va a la papelera")
	GameState.recover_trash()
	assert_true(GameState.has_unsaved_changes(), "El apodo nuevo queda sin guardar tras recuperar")


func test_without_any_copy_nothing_is_returned_but_the_trash_is_activated() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.learn_help(&"receiver")
	GameState.obtain_ability(GameState.ABILITY_LASER)
	GameState.attention_points = 5
	GameState.mark_level_completed(&"1-1")
	assert_false(FileAccess.file_exists(PATH), "Nunca se guardo")
	var report: Dictionary = GameState.apply_rollback()
	assert_false(report["had_copy"], "No habia copia")
	assert_false(report["trash_has_content"], "Nada que devolver")
	assert_true(report["first"])
	assert_true(GameState.has_met_ally(GameState.ALLY_PAPELERA), "La papelera se activa igualmente")
	assert_false(GameState.has_trash_pending(), "Vacia: no bloquea nada")
	assert_eq(GameState.attention_points, 0, "Lo no guardado se pierde")
	assert_false(GameState.is_level_completed(&"1-1"), "Hay que rehacer el 1-1")
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_LASER))
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_PULSE), "El pulso (regalo de Eco) se queda")
	assert_true(GameState.has_met_ally(GameState.ALLY_ECO) and GameState.has_met_ally(GameState.ALLY_NOTAS))
	assert_true(GameState.is_help_learned(&"receiver"))
	assert_false(FileAccess.file_exists(PATH), "No escribe nada")
	assert_true(HubWorlds.can_enter(&"1-1"), "Las carpetas siguen abiertas")
	var again: Dictionary = GameState.apply_rollback()
	assert_false(again["first"], "El segundo game over ya no es el primero")


func test_unknown_rollback_reason_changes_nothing() -> void:
	_saved_progress()
	GameState.attention_points = 30
	assert_true(GameState.apply_rollback(&"inventado").is_empty())
	assert_eq(GameState.attention_points, 30)
	assert_push_error("rollback desconocido")


# --- Mientras la papelera tiene contenido ---

func test_folders_and_saving_are_blocked_while_the_trash_is_full() -> void:
	_saved_progress()
	var disk: String = FileAccess.get_file_as_string(PATH)
	GameState.apply_rollback()
	assert_false(HubWorlds.can_enter(&"1-1"), "No se entra a niveles")
	GameState.request_save()
	assert_false(GameState.save_game(), "No se guarda: sobrescribiria la copia buena")
	assert_eq(FileAccess.get_file_as_string(PATH), disk, "La copia buena sigue en disco")
	GameState.recover_trash()
	assert_true(HubWorlds.can_enter(&"1-1"), "Tras recuperar, las carpetas se abren")


func test_quit_guard_quits_silently_without_writing_while_the_trash_is_full() -> void:
	_saved_progress()
	var disk: String = FileAccess.get_file_as_string(PATH)
	GameState.apply_rollback()
	GameState.request_save()
	assert_eq(QuitGuard.decide(true, true, true), QuitGuard.Decision.QUIT, "Con la papelera llena no avisa")
	_guard = QuitGuard.new()
	_guard.quit_handler = func() -> void: _quits += 1
	add_child(_guard)
	assert_eq(_guard.handle_close_request(), QuitGuard.Decision.QUIT)
	assert_eq(_quits, 1, "Sale sin preguntar")
	assert_false(_guard.is_prompt_open())
	assert_eq(FileAccess.get_file_as_string(PATH), disk, "No escribe: el disco conserva la ultima copia")


# --- Hub tras el game over ---

func test_hub_after_game_over_eco_talks_and_the_trash_blinks() -> void:
	_saved_progress()
	_progress_after_save()
	var report: Dictionary = GameState.apply_rollback()
	_spawn_hub(report)
	var papelera: Papelera = _hub.get_papelera()
	assert_eq(papelera.get_state(), Papelera.State.ACTIVE, "La papelera parpadea y se mueve")
	assert_eq(papelera.get_animation(), &"active")
	assert_null(_hub.get_notas_intro(), "Notas ya conocida")
	var intro: GameOverIntro = _hub.get_game_over_intro()
	assert_not_null(intro)
	assert_false(intro.is_running(), "Espera a que Isak termine de llegar")
	_arrive()
	assert_true(intro.is_running(), "Eco habla al llegar")
	assert_true(get_tree().paused, "Momento de historia: pausa")
	assert_eq(_hub.get_text_box().get_speaker_id(), &"", "Habla Eco")
	var expected: PackedStringArray = GameOverIntro.lines_for(report)
	assert_eq(expected.size(), 3, "Primer game over: la version larga")
	var seen: Array[String] = await _close_lines(expected.size())
	assert_eq(seen.size(), expected.size())
	assert_string_contains(seen[0], "he tenido que restaurar tu última copia")
	assert_string_contains(seen[0], GameState.get_nickname(), "Usa el apodo")
	assert_true(intro.is_done())
	assert_false(get_tree().paused, "La pausa se libera")


func test_hub_folder_is_blocked_with_a_notice_and_notas_does_not_save() -> void:
	_saved_progress()
	var report: Dictionary = GameState.apply_rollback()
	_spawn_hub(report)
	_arrive()
	await _close_lines(3)
	var folder: FolderStation = _hub.get_folder(&"m1")
	assert_true(folder.is_blocked_by_trash())
	assert_false(folder.open(_hub.get_isak()), "La carpeta no se abre")
	_isak_at(folder.position.x + T, _hub.get_shelf_top_y())
	await wait_physics_frames(6)
	assert_true(folder.is_trash_hint_visible(), "Con Isak cerca sale el aviso")
	assert_eq(folder.get_trash_hint_text(), "Recupera tus archivos de la papelera")
	assert_false(folder.is_key_hint_visible(), "Sin la tecla del pulso")
	assert_false(_hub.enter_level(&"1-1"), "No se entra al nivel")
	assert_false(_hub.can_save_now(), "El aviso al salir no ofrece guardar")
	var notas: NotasStation = _hub.get_notas()
	_isak_at(notas.position.x + 2.6 * T - 64.0, _hub.get_floor_y())
	await wait_physics_frames(3)
	assert_true(notas.open(_hub.get_isak()))
	var panel := notas.get_panel() as NotasPanel
	assert_true(panel.get_lines().has("Tus archivos están en la papelera"), "El resumen lo dice")
	GameState.request_save()
	assert_false(panel.save_now(), "Notas no guarda")
	assert_eq(panel.get_message(), "Primero recupera tus archivos de la papelera", "Aviso claro")
	notas.close(true)


func test_walking_to_the_trash_recovers_everything_and_unblocks_the_folders() -> void:
	_saved_progress()
	var report: Dictionary = GameState.apply_rollback()
	_spawn_hub(report)
	_arrive()
	await _close_lines(3)
	var papelera: Papelera = _hub.get_papelera()
	var recovered: Array = []
	papelera.recovered.connect(func(trash: Dictionary) -> void: recovered.append(trash))
	_isak_at(papelera.get_center().x - 4.0 * T, _hub.get_floor_y())
	await wait_physics_frames(4)
	assert_eq(papelera.get_state(), Papelera.State.ACTIVE, "Lejos no recupera")
	_isak_at(papelera.get_center().x - 1.0 * T, _hub.get_floor_y())
	await wait_physics_frames(4)
	assert_eq(recovered.size(), 1, "Al acercarse (sin boton) lo recupera todo")
	assert_eq(papelera.get_state(), Papelera.State.EMPTYING, "Animacion de vaciado")
	assert_eq(GameState.attention_points, 9)
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_LASER))
	assert_false(GameState.has_unsaved_changes(), "Sin cambios pendientes")
	papelera.finish_emptying()
	assert_eq(papelera.get_state(), Papelera.State.EMPTY, "Despues queda vacia y quieta")
	var folder: FolderStation = _hub.get_folder(&"m1")
	assert_false(folder.is_blocked_by_trash())
	assert_true(folder.open(_hub.get_isak()), "Las carpetas vuelven a abrirse")


func test_hub_without_copy_says_nothing_was_saved_and_the_trash_is_empty() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	var report: Dictionary = GameState.apply_rollback()
	_spawn_hub(report)
	assert_eq(_hub.get_papelera().get_state(), Papelera.State.EMPTY, "Activada y vacia")
	_arrive()
	var lines: PackedStringArray = GameOverIntro.lines_for(report)
	var seen: Array[String] = await _close_lines(lines.size())
	assert_string_contains(seen[0], "no había nada guardado")
	assert_true(_hub.get_folder(&"m1").open(_hub.get_isak()), "Sin nada pendiente, las carpetas se abren")


func test_hub_before_any_game_over_has_a_dormant_trash() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	_spawn_hub({})
	var papelera: Papelera = _hub.get_papelera()
	assert_eq(papelera.get_state(), Papelera.State.DORMANT, "Hueco apagado hasta que hace falta")
	assert_eq(papelera.get_animation(), &"dormant")
	assert_null(_hub.get_game_over_intro())
	assert_almost_eq(papelera.position.y + papelera.get_size().y, _hub.get_floor_y(), 0.5, "De pie sobre el dock")
	assert_eq(papelera.position.x, 10.0 * T, "Columna 10")


func test_second_game_over_line_is_brief() -> void:
	var report: Dictionary = {"reason": GameState.ROLLBACK_GAME_OVER, "had_copy": true, "first": false,
		"trash_has_content": true}
	assert_eq(GameOverIntro.lines_for(report).size(), 1, "Los siguientes: breve")
	report["first"] = true
	assert_gt(GameOverIntro.lines_for(report).size(), 1, "El primero: mas largo")


func test_game_over_texts_use_eco_voice_font_glyphs_and_never_name_laps() -> void:
	var data: Dictionary = GameOverIntro.load_data()
	var font: Font = load("res://assets/sprites/ui/text_font.fnt") as Font
	var count: int = 0
	for group: String in ["first", "again"]:
		for variant: String in [GameOverIntro.VARIANT_WITH_COPY, GameOverIntro.VARIANT_EMPTY_COPY,
				GameOverIntro.VARIANT_NO_COPY]:
			var lines: Array = data.get(group, {}).get(variant, [])
			assert_false(lines.is_empty(), "%s/%s tiene lineas" % [group, variant])
			for text: String in lines:
				count += 1
				for word: String in FORBIDDEN:
					assert_false(text.contains(word), "«%s» no dice «%s»" % [text, word])
				for ch: String in GameState.apply_nickname(text, "Isak"):
					assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s»" % ch)
	assert_true(String(data["first"][GameOverIntro.VARIANT_WITH_COPY][0]).begins_with("Lo siento, {apodo}"),
		"Voz de Eco: «Lo siento...»")
	for text: String in data["first"][GameOverIntro.VARIANT_NO_COPY]:
		if text.contains("nada guardado"):
			count += 1000
	assert_gt(count, 1000, "Sin copia: dice que no habia nada guardado")
	var hub_texts: Dictionary = HubData.section("folders").get("texts", {})
	for key: String in ["trash_blocked_text", "confirm_unsaved_risk"]:
		for word: String in FORBIDDEN:
			assert_false(String(hub_texts[key]).contains(word))
	assert_true(String(hub_texts["confirm_unsaved_title"]).begins_with("¿Seguro? Aún no has guardado."))
	for key: String in ["status_trash", "message_trash_pending"]:
		var text: String = String(HubData.section("notas").get("texts", {})[key])
		for word: String in FORBIDDEN:
			assert_false(text.contains(word))
		for ch: String in text:
			assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s»" % ch)


func test_changes_made_while_the_trash_is_full_stay_unsaved_after_recovering() -> void:
	_saved_progress()
	GameState.apply_rollback()
	assert_true(GameState.set_nickname("Kai"), "Se puede cambiar el apodo en Notas")
	assert_false(GameState.save_game(), "Pero no guardar")
	GameState.recover_trash()
	assert_true(GameState.has_unsaved_changes(), "El cambio sigue pendiente tras recuperar")
	assert_true(GameState.save_game(), "Y ya se puede guardar")


func test_folder_confirmation_keeps_its_title_and_explains_the_game_over_risk() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	_spawn_hub({})
	_arrive()
	GameState.request_save()
	var folder: FolderStation = _hub.get_folder(&"m1")
	assert_true(folder.open(_hub.get_isak()))
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	assert_true(panel.select_option(&"1-1"))
	panel.confirm()
	assert_true(panel.is_confirming_unsaved())
	assert_eq(panel.get_title(), "¿Seguro? Aún no has guardado.", "Se mantiene el aviso de siempre")
	assert_true(panel.get_lines().has("Si caes sin guardar, Eco te devolverá a tu última copia."),
		"Relaciona el aviso con el game over")
	folder.close(true)
