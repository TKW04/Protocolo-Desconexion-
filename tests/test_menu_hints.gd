## Pie de teclas de los menus del hub (MenuHints, 2026-10-23): cada panel lo
## tiene, la accion principal sale en su cajita con la tecla del Input Map
## (G; X con mando), cambia al reasignar, late la primera vez y no con
## «Reducir efectos», cabe en el panel y solo usa glifos de la fuente.
extends GutTest

const PATH: String = "user://test_save.json"
const NICKNAME_SCENE: PackedScene = preload("res://scenes/ui/nickname_entry.tscn")

var _saved_path: String = ""
var _reduced: bool = false


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	get_tree().paused = false
	MenuHints.set_device(MenuHints.Device.KEYBOARD)
	MenuHints.reset_seen()
	_reduced = GameSettings.is_low_sync_reduced()


func after_each() -> void:
	ControlBindings.restore_defaults()
	GameSettings.set_low_sync_reduced(_reduced)
	MenuHints.set_device(MenuHints.Device.KEYBOARD)
	get_tree().paused = false
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _font() -> Font:
	return load("res://assets/sprites/ui/text_font.fnt") as Font


func _assert_glyphs(text: String, why: String) -> void:
	var font: Font = _font()
	for i: int in text.length():
		var ch: int = text.unicode_at(i)
		assert_true(ch == 32 or font.has_char(ch), "%s: glifo %s de «%s»" % [why, char(ch), text])


func _panels() -> Dictionary:
	var notas := NotasPanel.new()
	var calc := CalcPanel.new()
	var folder := FolderPanel.new()
	folder.world_entry = HubWorlds.world(&"m1")
	var out: Dictionary = {"notas": notas, "calc": calc, "folder": folder}
	for key: String in out:
		add_child_autofree(out[key])
		(out[key] as HubPanel).open()
	return out


func test_every_hub_panel_has_hints_with_g() -> void:
	var expected: Dictionary = {"notas": "G Aceptar", "calc": "G Comprar", "folder": "G Entrar"}
	var panels: Dictionary = _panels()
	for key: String in panels:
		var panel: HubPanel = panels[key]
		var hints: MenuHints = panel.get_hints()
		assert_not_null(hints, "%s tiene pie de teclas" % key)
		assert_true(hints.is_visible_in_tree(), "%s: pie visible" % key)
		assert_eq(hints.get_key_texts(), PackedStringArray(["G"]), "%s: G en la cajita" % key)
		assert_true(panel.get_help().begins_with(expected[key]), "%s: %s" % [key, panel.get_help()])
		assert_true(panel.get_help().contains("W/S Elegir"), "%s: elegir" % key)
		assert_true(panel.get_help().contains("Espacio Volver"), "%s: volver" % key)
		_assert_glyphs(panel.get_help(), key)
		assert_false(panel.get_help().to_lower().contains("vuelta"), "Nunca dice vuelta")
		# Cabe en el panel y el panel en la pantalla (1280x720 a x2 = 640x360).
		var rect: Rect2 = panel.get_panel_rect()
		var hint_rect := Rect2(hints.position * 2.0 + rect.position, hints.size * 2.0)
		assert_true(rect.encloses(hint_rect), "%s: el pie cabe en el panel" % key)
		assert_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect), "%s: el panel cabe" % key)


func test_hints_sit_below_options() -> void:
	var panel: HubPanel = _panels()["notas"]
	var hints: MenuHints = panel.get_hints()
	for child: Node in panel._get_panel_node().get_children():
		if child is Label and (child as Label).visible and child.get_parent() == panel._get_panel_node():
			assert_true((child as Label).position.y + 12.0 <= hints.position.y,
				"%s por encima del pie" % child.name)


func test_folder_confirm_and_empty_world() -> void:
	GameState.request_save()
	var folder := FolderPanel.new()
	folder.world_entry = HubWorlds.world(&"m1")
	add_child_autofree(folder)
	folder.open()
	folder.select_option(&"1-1")
	folder.confirm()
	assert_true(folder.is_confirming_unsaved(), "Pregunta antes de entrar sin guardar")
	assert_true(folder.get_help().begins_with("G Aceptar"), folder.get_help())
	var empty := FolderPanel.new()
	empty.world_entry = HubWorlds.world(&"m3")
	add_child_autofree(empty)
	empty.open()
	assert_eq(empty.get_help(), "G o Espacio Volver")
	assert_eq(empty.get_hints().get_key_texts(), PackedStringArray(["G", "Espacio"]))


func test_album_hints_by_mode() -> void:
	var album := NotasAlbum.new()
	add_child_autofree(album)
	album.open()
	assert_true(album.get_help().begins_with("G Abrir"), album.get_help())
	assert_true(album.get_help().contains("WASD Elegir"), album.get_help())
	assert_true(album.get_help().contains("Espacio Salir"), album.get_help())
	assert_true(album.open_folder(1), "Abre la carpeta del Mundo 1")
	assert_true(album.get_help().contains("Espacio Volver"), album.get_help())
	_assert_glyphs(album.get_help(), "album")
	var rect: Rect2 = album.get_panel_rect()
	var hints: MenuHints = album.get_hints()
	assert_true(rect.encloses(Rect2(hints.position * 2.0 + rect.position, hints.size * 2.0)), "Cabe en el album")


func test_nickname_entry_shows_real_accept_key() -> void:
	var entry: NicknameEntry = NICKNAME_SCENE.instantiate()
	add_child_autofree(entry)
	var help: String = entry.get_lines()[entry.get_lines().size() - 1]
	assert_true(help.contains("Intro Aceptar"), "Acepta con Intro (ui_accept): %s" % help)
	assert_true(help.contains("Esc Dejar el actual"), help)
	_assert_glyphs(help, "apodo")
	entry.free()
	get_tree().paused = false


func test_pad_shows_buttons() -> void:
	var panel: HubPanel = _panels()["notas"]
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_Y
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(2)
	assert_eq(MenuHints.current_device(), MenuHints.Device.PAD, "Ultimo dispositivo: mando")
	assert_eq(panel.get_hints().get_key_texts(), PackedStringArray(["X"]), "Pulso del mando")
	assert_true(panel.get_help().contains("Cruceta Elegir"), panel.get_help())
	assert_true(panel.get_help().contains("A Volver"), panel.get_help())
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.physical_keycode = KEY_Z
	key.pressed = true
	# Sin ventana las teclas no llegan por parse_input_event: se entrega directa.
	panel.get_hints()._input(key)
	assert_eq(panel.get_hints().get_key_texts(), PackedStringArray(["G"]), "Vuelve al teclado")


func test_remap_changes_hint() -> void:
	var panel: HubPanel = _panels()["notas"]
	var event := InputEventKey.new()
	event.physical_keycode = KEY_H
	ControlBindings.assign(&"pulse", event, true)
	assert_eq(panel.get_hints().get_key_texts(), PackedStringArray(["H"]), "Tecla reasignada")
	assert_true(panel.get_help().begins_with("H Aceptar"), panel.get_help())
	ControlBindings.restore_defaults()
	assert_eq(panel.get_hints().get_key_texts(), PackedStringArray(["G"]), "Restaurada")


func test_first_open_pulses_once_per_menu() -> void:
	var panel := NotasPanel.new()
	add_child_autofree(panel)
	panel.open()
	var hints: MenuHints = panel.get_hints()
	assert_true(hints.is_pulsing(), "La primera vez late")
	var colors: Array[Color] = []
	for i: int in 30:
		await wait_frames(1)
		if not colors.has(hints.get_plate_color()):
			colors.append(hints.get_plate_color())
	assert_gt(colors.size(), 1, "Alterna de color")
	panel.close()
	panel.open()
	assert_false(hints.is_pulsing(), "La segunda vez no late")
	assert_eq(hints.get_plate_color(), HubData.color("acento_cian"), "Cajita resaltada fija")
	var other := CalcPanel.new()
	add_child_autofree(other)
	other.open()
	assert_true(other.get_hints().is_pulsing(), "Cada menu late su primera vez")


func test_reduced_effects_do_not_pulse() -> void:
	GameSettings.set_low_sync_reduced(true)
	var panel := NotasPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_false(panel.get_hints().is_pulsing(), "Con «Reducir efectos» no late")
	assert_eq(panel.get_hints().get_plate_color(), HubData.color("acento_cian"), "Pero sigue resaltada")
