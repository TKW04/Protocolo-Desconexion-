# Encuentro con Calc en el hub (CalcIntro; 2026-10-17, tanda H3 del paso 14 de
# docs/propuesta-1-2.md, docs/propuesta-calc-encuentro.md §6; textos en
# data/calc_intro.json): solo con Calc teletransportada en la sesion
# (EventBus.ally_teleported) y aun desconocida; Calc espera despierta y sin
# tienda; al terminar la llegada el juego se pausa y Calc habla (estilo LCD, con
# el saldo actual y el icono del punto), Eco se descuelga entre sus lineas y al
# final meet_ally("calc") enciende la estacion (tienda), marca «sin guardar» y no
# se repite. Sin teletransporte, con Calc conocida o tras un game over no hay
# escena. Usa sus propias rutas de guardado y ajustes (nunca las reales).
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_calc_intro.json"
const LCD_FONT: String = "res://assets/sprites/ui/text_font_lcd.fnt"
const LCD_PANEL: String = "res://assets/sprites/hub/icons/lcd_panel_00.png"
const POINTS_LINE: String = "Has recogido"
const ECO_LINE: String = "Treinta días."

var _hub: HubRoom
var _saved_path: String
var _saved_pulse: bool
var _saved_pause_important: bool
var _settings_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	GameState.use_save_path(PATH, true)
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	GameState.reset_progress()
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.mark_level_completed(&"1-1")


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameSettings.use_path(_settings_path, true)


func _spawn() -> void:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	_hub.get_isak().input = PlayerInput.new()


func _arrive() -> void:
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)


func _teleport_calc() -> void:
	EventBus.ally_teleported.emit(GameState.ALLY_CALC)


## Cierra la linea importante en pantalla como el jugador.
func _close_line() -> void:
	var box: EcoTextBox = _hub.get_text_box()
	box.finish_typing()
	box.confirm()
	box.advance(1.0)
	await get_tree().process_frame
	await get_tree().process_frame


## Cierra lineas hasta la que contiene `fragment` (falso si el encuentro acaba antes).
func _close_until(fragment: String) -> bool:
	var box: EcoTextBox = _hub.get_text_box()
	for i: int in 12:
		if box.get_text().contains(fragment):
			return true
		if not _hub.get_calc_intro().is_running():
			return false
		await _close_line()
	return box.get_text().contains(fragment)


func _close_all() -> void:
	for i: int in 12:
		if _hub.get_calc_intro() == null or not _hub.get_calc_intro().is_running():
			return
		await _close_line()


func test_teleport_sets_a_session_arrival_that_is_not_saved() -> void:
	assert_false(CalcIntro.is_pending())
	_teleport_calc()
	assert_true(CalcIntro.is_pending(), "ally_teleported apunta la llegada")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "No la da por conocida")
	assert_false(GameState.to_save_data().has("ally_arrivals"), "No va en save.json")
	assert_false(JSON.stringify(GameState.to_save_data()).contains("arrival"))
	assert_eq(GameState.apply_debug_teleport_args(PackedStringArray(["--ally-teleported=calc", "--x"])),
		[GameState.ALLY_CALC] as Array[StringName], "Argumento de depuracion")
	assert_false(GameState.note_ally_teleported(&"nadie"), "Asistente desconocido")


func test_calc_waits_awake_and_talks_once_after_the_arrival() -> void:
	_teleport_calc()
	_spawn()
	var intro: CalcIntro = _hub.get_calc_intro()
	var calc: CalcStation = _hub.get_calc()
	assert_not_null(intro, "Hay encuentro")
	assert_eq(intro.get_step(), CalcIntro.Step.WAITING, "Espera a la llegada")
	assert_false(calc.is_powered(), "Sin tienda hasta el encuentro")
	assert_true(calc.is_arrived())
	assert_eq(calc.get_calc_animation(), &"awake", "Ya despierta y cargada al llegar")
	assert_false(calc.open(_hub.get_isak()), "La tienda aun no abre")
	assert_false(get_tree().paused)
	_arrive()
	var box: EcoTextBox = _hub.get_text_box()
	assert_eq(intro.get_step(), CalcIntro.Step.CALC, "Habla Calc")
	assert_true(get_tree().paused, "Momento de historia: pausa")
	assert_eq(box.get_speaker_id(), &"calc")
	assert_eq(box.get_speaker_text(), "Calc", "Nombre propio")
	assert_true(box.is_important())
	assert_true(box.get_text().contains("100 %"), "Cargada: 100 %")
	assert_false(box.get_text().contains("3 %"), "Ya no dice que esta al 3 %")
	var whos: Array[String] = []
	intro.line_shown.connect(func(_i: int, who: String) -> void: whos.append(who))
	var seen: Array[String] = [box.get_text()]
	for i: int in 12:
		if not intro.is_running():
			break
		assert_true(get_tree().paused, "Sigue en pausa entre lineas")
		await _close_line()
		if intro.is_running():
			seen.append(box.get_text())
	assert_true(intro.is_done())
	assert_eq(seen.size(), intro.lines().size(), "Todas las lineas, una a una")
	assert_true(seen[-1].contains("Eco sabe sumar atención. Nunca ha sabido restarla."), "Frase de cierre")
	var eco_at: int = whos.find("eco") + 1
	assert_gt(eco_at, 1, "Eco no abre la escena")
	assert_lt(eco_at, seen.size() - 1, "Eco se descuelga ENTRE lineas de Calc")
	assert_true(seen[eco_at].contains(ECO_LINE), "La linea de Eco: %s" % seen[eco_at])
	assert_true(seen[eco_at + 1].begins_with("Eco: treinta días"), "Calc le responde")
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC), "Calc conocida")
	assert_false(CalcIntro.is_pending(), "Llegada consumida")
	assert_false(get_tree().paused, "Se reanuda")
	assert_true(calc.is_powered(), "Estacion encendida")
	assert_false(calc.is_arrived())
	assert_eq(calc.get_calc_animation(), &"awake", "Sigue despierta")
	assert_true(calc.open(_hub.get_isak()), "Tienda disponible")
	assert_true(calc.get_calc_panel().is_open(), "Tienda abierta")
	calc.close(true)
	# Reabrir la escena del hub: no se repite.
	_hub.free()
	_spawn()
	_arrive()
	assert_null(_hub.get_calc_intro(), "No se repite")
	assert_true(_hub.get_calc().is_powered())
	assert_false(get_tree().paused)


func test_points_line_uses_the_current_balance_with_the_icon() -> void:
	for points: int in [0, 17, 130]:
		GameState.reset_progress()
		EcoProgress.meet_eco_with_pulse()
		EcoProgress.meet_notas()
		GameState.attention_points = 0
		_teleport_calc()
		_spawn()
		_arrive()
		# El saldo se lee al empezar la linea, no al llegar.
		GameState.attention_points = points
		assert_true(await _close_until(POINTS_LINE), "Llega la linea de los puntos")
		var box: EcoTextBox = _hub.get_text_box()
		assert_true(box.get_text().begins_with("%s %d ◆." % [POINTS_LINE, points]),
			"Saldo actual con el icono: %s" % box.get_text())
		assert_eq(box.get_speaker_id(), &"calc")
		box.finish_typing()
		assert_eq(box.get_inline_icons().size(), 1, "Icono en linea")
		assert_eq(box.get_inline_icon_id(0), &"atencion")
		assert_true(box.get_inline_icons()[0].visible)
		var icon: Rect2 = box.get_inline_icon_rect(0)
		assert_true(box.get_panel_rect().encloses(icon), "El icono cabe en el cuadro LCD")
		await _close_all()
		_hub.free()
		_hub = null


func test_calc_lines_use_the_lcd_style_and_digits_appear_at_once() -> void:
	GameState.attention_points = 130
	_teleport_calc()
	_spawn()
	_arrive()
	var box: EcoTextBox = _hub.get_text_box()
	assert_eq(box.get_style_id(), &"lcd", "Estilo LCD")
	assert_eq(box.get_font().resource_path, LCD_FONT, "Fuente monoespaciada")
	var font: Font = box.get_font()
	assert_eq(font.get_string_size("i", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x,
		font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, "Monoespaciada")
	assert_eq(box.get_panel_texture().resource_path, LCD_PANEL, "Pantalla LCD")
	assert_eq(box.get_body_color(), Color.html("#050e3c"), "Texto oscuro del LCD")
	assert_ne(box.get_body_color(), EcoTextBoxConfig.shared().color(&"body"))
	assert_true(await _close_until(POINTS_LINE))
	var text: String = box.get_text()
	assert_eq(box.get_type_steps(), text.length() - 2, "«130» se escribe en un solo paso")
	var cps: float = box.get_chars_per_second()
	var saw_number: bool = false
	for i: int in text.length() + 2:
		var visible: String = box.get_visible_text()
		if visible.contains("1"):
			assert_true(visible.contains("130"), "Las cifras salen de golpe: «%s»" % visible)
			saw_number = true
		box.advance(1.0 / cps)
	assert_true(saw_number)
	assert_true(await _close_until(ECO_LINE), "Llega la linea de Eco")
	assert_eq(box.get_speaker_id(), &"", "Eco se descuelga")
	assert_eq(box.get_speaker_text(), "Eco")
	assert_eq(box.get_style_id(), &"", "Eco con su estilo")
	assert_eq(box.get_font().resource_path, EcoTextBoxConfig.shared().font_path)
	assert_eq(box.get_body_color(), EcoTextBoxConfig.shared().color(&"body"))
	assert_true(box.get_text().contains(GameState.get_nickname()), "Eco usa el apodo")
	await _close_line()
	assert_eq(box.get_style_id(), &"lcd", "Calc vuelve a su LCD")
	await _close_all()


func test_calc_already_known_has_no_scene() -> void:
	EcoProgress.meet_calc()
	_teleport_calc()
	assert_false(CalcIntro.is_pending(), "Conocida: nada que esperar")
	_spawn()
	_arrive()
	assert_null(_hub.get_calc_intro())
	assert_true(_hub.get_calc().is_powered())
	assert_false(get_tree().paused)
	assert_false(_hub.get_text_box().is_showing())


func test_without_teleport_there_is_no_scene_and_calc_stays_off() -> void:
	_spawn()
	_arrive()
	assert_null(_hub.get_calc_intro(), "Sin teletransporte no hay escena")
	assert_false(_hub.get_calc().is_powered(), "Apagada")
	assert_eq(_hub.get_calc().get_calc_animation(), &"powered_off")
	assert_false(get_tree().paused)


func test_game_over_loses_the_pending_arrival() -> void:
	GameState.save_game()
	_teleport_calc()
	var report: Dictionary = GameState.apply_rollback()
	assert_false(CalcIntro.is_pending(), "El rollback pierde la llegada (lo no guardado)")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC))
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.rollback_report = report
	add_child(_hub)
	_hub.get_isak().input = PlayerInput.new()
	_arrive()
	assert_null(_hub.get_calc_intro(), "Sin encuentro tras el game over")
	assert_false(_hub.get_calc().is_powered())


func test_teleport_then_rollback_with_report_does_not_start_the_scene() -> void:
	_teleport_calc()
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.rollback_report = {"reason": GameState.ROLLBACK_GAME_OVER, "had_copy": false, "first": true,
		"trash_has_content": false, "trash": {}}
	add_child(_hub)
	assert_null(_hub.get_calc_intro(), "Con el informe del game over no hay encuentro")


func test_marks_unsaved_and_survives_save_and_load() -> void:
	GameState.save_game()
	assert_false(GameState.has_unsaved_changes())
	_teleport_calc()
	_spawn()
	_arrive()
	await _close_all()
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC))
	assert_true(GameState.has_unsaved_changes(), "Conocer a Calc marca «sin guardar»")
	assert_true(_hub.can_save_now(), "Notas puede guardar")
	assert_eq(QuitGuard.decide(GameState.has_unsaved_changes(), QuitGuard.can_save_here(get_tree())),
		QuitGuard.Decision.ASK_WITH_SAVE, "El aviso al salir ofrece guardar")
	assert_true(GameState.save_game())
	GameState.reset_progress()
	assert_true(GameState.load_game())
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC), "Calc conocida en la copia")
	_hub.free()
	_spawn()
	_arrive()
	assert_null(_hub.get_calc_intro(), "Tras cargar no se repite")
	assert_true(_hub.get_calc().is_powered())


func test_pause_menu_cannot_open_during_the_scene_and_pause_is_released() -> void:
	_teleport_calc()
	_spawn()
	_arrive()
	var menu: PauseMenu = PauseMenu.find_in(get_tree())
	assert_not_null(menu)
	assert_true(get_tree().paused)
	assert_false(menu.request_open(), "El menu de pausa no se abre en la escena")
	assert_true(_hub.blocks_pause_menu(), "El hub lo bloquea mientras dura")
	await _close_all()
	assert_false(get_tree().paused, "Pausa liberada al terminar")
	assert_false(_hub.blocks_pause_menu())


func test_without_pausing_lines_the_hub_still_blocks_the_pause_menu() -> void:
	EcoTextBox.pause_important = false
	_teleport_calc()
	_spawn()
	_arrive()
	assert_false(get_tree().paused, "Sin pausa (herramientas)")
	assert_true(_hub.get_calc_intro().is_running())
	assert_true(_hub.blocks_pause_menu(), "El encuentro bloquea el menu aun sin pausa")


func test_leaving_mid_scene_releases_the_pause_and_keeps_it_pending() -> void:
	_teleport_calc()
	_spawn()
	_arrive()
	await _close_line()
	assert_true(get_tree().paused)
	_hub.free()
	_hub = null
	assert_false(get_tree().paused, "La pausa se libera al salir del arbol")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "No se dio por vista")
	assert_true(CalcIntro.is_pending(), "La proxima llegada al hub la repite entera")


func test_nested_pause_is_not_taken_over() -> void:
	_teleport_calc()
	_spawn()
	get_tree().paused = true
	_arrive()
	assert_true(_hub.get_calc_intro().is_running(), "Empieza aunque ya hubiera pausa")
	await _close_all()
	assert_true(get_tree().paused, "No quita una pausa que no puso")
	get_tree().paused = false


func test_scene_plays_with_eco_help_hidden() -> void:
	GameSettings.set_eco_help_shown(false)
	_teleport_calc()
	_spawn()
	_arrive()
	assert_true(_hub.get_calc_intro().is_running(), "Es historia: sale igual")
	assert_true(await _close_until(ECO_LINE), "Eco se descuelga igual")
	await _close_all()
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC))
	GameSettings.set_eco_help_shown(true)


func test_notas_first_then_calc_when_both_are_pending() -> void:
	GameState.allies_met.erase(GameState.ALLY_NOTAS)
	_teleport_calc()
	_spawn()
	_arrive()
	assert_true(_hub.get_notas_intro().is_running(), "Primero Notas")
	assert_eq(_hub.get_calc_intro().get_step(), CalcIntro.Step.WAITING, "Calc espera a Notas")
	for i: int in 6:
		if _hub.get_notas_intro().is_done():
			break
		await _close_line()
	assert_true(GameState.has_met_ally(GameState.ALLY_NOTAS))
	assert_true(_hub.get_calc_intro().is_running(), "Despues habla Calc")
	assert_true(get_tree().paused)
	await _close_all()
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC))
	assert_false(get_tree().paused)


func test_without_eco_known_the_eco_line_is_skipped() -> void:
	GameState.allies_met.erase(GameState.ALLY_ECO)
	_teleport_calc()
	_spawn()
	_arrive()
	var intro: CalcIntro = _hub.get_calc_intro()
	for entry: Dictionary in intro.lines():
		assert_ne(String(entry["who"]), "eco", "Sin Eco no se descuelga")
	await _close_all()
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC))


func test_texts_use_font_glyphs_and_never_name_laps() -> void:
	var data: Dictionary = CalcIntro.load_data()
	var lines: Array = data.get("lines", [])
	assert_eq(lines.size(), 8)
	var whos: Array[String] = []
	var fonts: Array[Font] = [load("res://assets/sprites/ui/text_font.fnt") as Font, load(LCD_FONT) as Font]
	var icons: Dictionary = EcoTextBoxConfig.shared().inline_icons
	for entry: Dictionary in lines:
		whos.append(String(entry["who"]))
		var raw: String = String(entry["text"])
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(raw.contains(word), "«%s» no dice «%s»" % [raw, word])
		var text: String = TextMarkers.apply(GameState.apply_nickname(raw, "Isak"), icons, 130)
		for font: Font in fonts:
			for ch: String in text:
				assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s» (%s)" % [ch, raw])
	assert_eq(whos.count("eco"), 1, "Una linea de Eco")
	assert_true(String(lines[2]["text"]).contains("{puntos} {icono:atencion}"), "Numero dinamico con el icono")
	assert_eq(String(lines[-1]["text"]), "Eco sabe sumar atención. Nunca ha sabido restarla.")
	assert_true(JSON.stringify(data).contains("no un banco"), "Sin comision: no un banco")
