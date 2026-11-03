# Avisos de habilidad en el cuadro de Eco (2026-11-03, peticion del usuario):
# solo la tecla o el boton del ultimo dispositivo usado, resaltada en una cajita
# que se ve pulsada; si el dispositivo cambia con el aviso abierto el texto y la
# cajita cambian al momento; y una mini animacion de Isak (AbilityDemo) que
# repite como se usa la habilidad, con la cajita pulsada a la vez que la demo.
extends GutTest

const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")

var _data: Dictionary = AbilityNotices.load_data()


func before_each() -> void:
	ControlBindings.reset_device()


func after_each() -> void:
	get_tree().paused = false
	ControlBindings.reset_device()
	ControlBindings.restore_defaults(false)


func _box() -> EcoTextBox:
	var box := BOX_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.set_process(false)
	return box


func _show(box: EcoTextBox, ability: StringName) -> void:
	box.show_line(AbilityNotices.notice_template(ability, _data), -1.0, true)
	box.finish_typing()


func test_keyboard_shows_the_key_highlighted() -> void:
	var box := _box()
	_show(box, &"laser")
	assert_eq(box.get_text(), "Láser: F", "Solo la tecla")
	var caps: Array[Dictionary] = box.get_key_highlights()
	assert_eq(caps.size(), 1, "Una cajita")
	assert_eq(caps[0]["text"], "F")
	assert_eq(caps[0]["action"], &"laser")
	assert_true(caps[0]["visible"], "Escrita: se ve")
	var rect: Rect2 = box.get_key_highlight_rect(0)
	var glyph: Rect2 = box.get_glyph_rect(box.get_text().find("F"))
	assert_true(rect.encloses(glyph), "La cajita rodea la tecla (%s / %s)" % [rect, glyph])
	assert_eq(box.get_confirm_hint_text(), "▼ [Espacio]")


func test_pad_shows_the_button() -> void:
	ControlBindings.set_last_device(ControlBindings.Device.PAD)
	var box := _box()
	_show(box, &"debug")
	assert_eq(box.get_text(), "Debug: mantén Y", "Solo el boton")
	assert_eq(box.get_key_highlights()[0]["text"], "Y")
	assert_eq(box.get_confirm_hint_text(), "▼ [A]", "La indicacion de cierre tambien")


func test_device_change_updates_the_open_notice() -> void:
	var box := _box()
	_show(box, &"dash")
	assert_eq(box.get_text(), "Deslizar: L")
	ControlBindings.set_last_device(ControlBindings.Device.PAD)
	assert_eq(box.get_text(), "Deslizar: B", "Cambia al momento")
	assert_eq(box.get_key_highlights()[0]["text"], "B")
	assert_eq(box.get_typed_count(), box.get_text().length(), "Sigue escrita entera")
	ControlBindings.set_last_device(ControlBindings.Device.KEYBOARD)
	assert_eq(box.get_text(), "Deslizar: L", "Y vuelve")


func test_remap_updates_the_open_notice() -> void:
	var box := _box()
	_show(box, &"dash")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	assert_eq(ControlBindings.assign(&"gesture_swipe", key), ControlBindings.Result.OK)
	assert_eq(box.get_text(), "Deslizar: E", "Reasignada en Ajustes: cambia")


func test_combo_lines_highlight_every_key() -> void:
	var box := _box()
	var line: String = AbilityNotices.explain_templates(GameState.ABILITY_COMBO, _data)[0]
	box.show_line(line, -1.0, true)
	box.finish_typing()
	var texts: Array = box.get_key_highlights().map(func(c: Dictionary) -> String: return c["text"])
	assert_eq(texts, ["Espacio", "L", "S"], "Saltar, Deslizar y abajo")


func test_demo_is_present_and_animates() -> void:
	var box := _box()
	_show(box, &"dash")
	var demo: AbilityDemo = box.get_demo()
	assert_not_null(demo, "El aviso lleva su mini animacion")
	assert_eq(demo.get_demo_id(), &"dash")
	assert_true(box.get_panel_rect().encloses(Rect2(demo.get_global_rect().position, demo.get_global_rect().size)),
			"Dentro del cuadro")
	assert_eq(demo.get_current_anim(), &"idle")
	var start: Vector2 = demo.get_isak_position()
	var seen_dash: bool = false
	var seen_lit: bool = false
	for i: int in 60:
		box.advance(1.0 / 60.0)
		if demo.get_current_anim() == &"dash":
			seen_dash = true
			seen_lit = seen_lit or bool(box.get_key_highlights()[0]["lit"])
	assert_true(seen_dash, "Pasa por el dash")
	assert_true(seen_lit, "La cajita se ve pulsada mientras la demo pulsa Deslizar")
	assert_ne(demo.get_isak_position(), start, "Isak se desliza")
	for i: int in 120:
		box.advance(1.0 / 60.0)
	assert_lt(demo.get_isak_position().x, demo.size.x, "En bucle: vuelve a empezar")


func test_line_without_markers_has_no_demo_or_caps() -> void:
	var box := _box()
	box.show_line("Hola.", -1.0, true)
	box.finish_typing()
	assert_null(box.get_demo())
	assert_eq(box.get_key_highlights().size(), 0)
	box.confirm()
	box.advance(1.0)
	_show(box, &"laser")
	assert_not_null(box.get_demo(), "La siguiente con demo la pone")
	box.confirm()
	box.advance(1.0)
	box.show_line("Adiós.", -1.0, false)
	assert_null(box.get_demo(), "Y la quita en la siguiente sin demo")


func test_pulse_notice_of_the_encounter_has_a_demo() -> void:
	var format: Dictionary = _data.duplicate(true)
	format["abilities"] = {"pulse": EcoEncounter.load_data()["notice"]}
	var box := _box()
	box.show_line(AbilityNotices.notice_template(&"pulse", format), -1.0, true)
	box.finish_typing()
	assert_eq(box.get_text(), "Pulso: G")
	assert_eq(box.get_demo().get_demo_id(), &"pulse")
