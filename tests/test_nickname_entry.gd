# Entrada del apodo (NicknameEntry, data/nickname_entry.json;
# docs/propuesta-asistentes-y-vidas.md §2.1, paso 5 de §10) y apodo en
# GameState (get_nickname, set_nickname, sanitize_nickname) y en los textos de
# Eco ({apodo} en EcoTextBox y HelpCatalog). La entrada muestra el apodo actual
# («Isak» por defecto), pausa el juego, se escribe con el teclado (letras,
# numeros y espacio; maximo 12; sin caracteres de control), recorta espacios,
# Intro acepta, Esc / ui_cancel o la opcion «Dejar» mantienen el actual, guarda
# en GameState y marca «sin guardar», emite el nombre elegido y la pausa se
# libera siempre.
extends GutTest

const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/nickname_entry.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")

var _entry: NicknameEntry
var _chosen: Array[String] = []
var _closed: int = 0


func before_each() -> void:
	GameState.reset_progress()
	get_tree().paused = false
	_chosen.clear()
	_closed = 0


func after_each() -> void:
	if _entry != null and is_instance_valid(_entry):
		_entry.free()
	_entry = null
	get_tree().paused = false
	GameState.reset_progress()


func _open() -> NicknameEntry:
	_entry = ENTRY_SCENE.instantiate() as NicknameEntry
	_entry.free_on_close = false
	_entry.nickname_chosen.connect(func(nick: String) -> void: _chosen.append(nick))
	_entry.closed.connect(func() -> void: _closed += 1)
	add_child(_entry)
	return _entry


func _key(keycode: Key, unicode: int = 0) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.unicode = unicode
	event.pressed = true
	return event


func _type(text: String) -> void:
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		_entry.handle_event(_key(KEY_SPACE if code == 32 else KEY_A, code))


func test_shows_the_default_nickname_and_pauses_the_game() -> void:
	_open()
	assert_eq(GameState.get_nickname(), "Isak")
	assert_eq(_entry.get_text(), "Isak", "El campo empieza con el apodo actual")
	assert_true(_entry.is_pristine())
	assert_true(get_tree().paused, "Pausa el juego")
	assert_true(_entry.is_pausing_game())
	assert_true(_entry.get_lines().has('  Dejar "Isak"') or _entry.get_lines().has('– Dejar "Isak"'),
		"Opcion visible para dejar el actual: %s" % [_entry.get_lines()])


func test_typing_replaces_then_enter_saves_and_marks_unsaved() -> void:
	_open()
	assert_false(GameState.has_unsaved_changes())
	_type("Maya")
	assert_eq(_entry.get_text(), "Maya", "La primera tecla sustituye el apodo mostrado")
	_entry.handle_event(_key(KEY_ENTER))
	assert_eq(GameState.nickname, "Maya", "Guarda en GameState.nickname")
	assert_true(GameState.has_unsaved_changes(), "Marca «sin guardar»")
	assert_eq(_chosen, ["Maya"] as Array[String], "Emite el apodo elegido")
	assert_eq(_closed, 1)
	assert_false(get_tree().paused, "Libera la pausa al cerrar")


func test_all_texts_use_only_glyphs_of_the_text_font() -> void:
	_open()
	var font: Font = load(String(NicknameEntry.load_data()["font"])) as Font
	for line: String in _entry.get_lines():
		for i: int in line.length():
			assert_true(font.has_char(line.unicode_at(i)), "La fuente tiene '%s' (%s)" % [line[i], line])


func test_max_length_is_twelve() -> void:
	_open()
	_type("Abcdefghijklmnop")
	assert_eq(_entry.get_text().length(), GameState.NICKNAME_MAX_LENGTH)
	assert_eq(_entry.get_text(), "Abcdefghijkl")
	_entry.accept()
	assert_eq(GameState.nickname, "Abcdefghijkl")


func test_letters_digits_accents_and_spaces_but_no_control_or_symbols() -> void:
	_open()
	_type("Ñoño 7")
	_entry.type_char("\t")
	_entry.type_char("\n")
	_entry.type_char("!")
	_entry.type_char("@")
	_entry.type_char(char(7))
	assert_eq(_entry.get_text(), "Ñoño 7", "Solo letras (con tildes y ene), numeros y espacio")
	_entry.handle_event(_key(KEY_BACKSPACE))
	assert_eq(_entry.get_text(), "Ñoño ")


func test_spaces_are_trimmed_when_accepting() -> void:
	_open()
	_entry.type_char(" ")
	_type("Ana  Luz ")
	_entry.accept()
	assert_eq(GameState.nickname, "Ana Luz", "Recorta y une espacios")
	assert_eq(GameState.sanitize_nickname("  a\u0001b   c  "), "ab c")
	assert_eq(GameState.sanitize_nickname("x".repeat(20)).length(), 12)


func test_empty_name_keeps_the_current_one() -> void:
	_open()
	for i: int in 6:
		_entry.erase_char()
	assert_eq(_entry.get_text(), "")
	_entry.handle_event(_key(KEY_ENTER))
	assert_eq(GameState.nickname, "Isak", "Vacio: se queda el actual")
	assert_false(GameState.has_unsaved_changes())
	assert_eq(_chosen, ["Isak"] as Array[String])


func test_escape_keeps_the_current_nickname() -> void:
	GameState.nickname = "Leo"
	_open()
	_type("Otro")
	_entry.handle_event(_key(KEY_ESCAPE))
	assert_eq(GameState.nickname, "Leo", "Esc deja el actual")
	assert_false(GameState.has_unsaved_changes())
	assert_eq(_chosen, ["Leo"] as Array[String])
	assert_false(get_tree().paused)


func test_keep_option_and_gamepad_cancel_keep_the_current_nickname() -> void:
	_open()
	_type("Zed")
	_entry.handle_event(_key(KEY_RIGHT))
	assert_eq(_entry.get_selected(), NicknameEntry.Option.KEEP)
	_entry.handle_event(_key(KEY_ENTER))
	assert_eq(GameState.nickname, "Isak", "Opcion «Dejar»")
	_entry.free()
	_open()
	var action := InputEventAction.new()
	action.action = &"ui_cancel"
	action.pressed = true
	assert_true(_entry.handle_event(action), "ui_cancel (B del mando)")
	assert_eq(GameState.nickname, "Isak")
	assert_eq(_closed, 2)


func test_gamepad_accept_without_keyboard_keeps_the_default() -> void:
	_open()
	var action := InputEventAction.new()
	action.action = &"ui_accept"
	action.pressed = true
	_entry.handle_event(action)
	assert_eq(GameState.nickname, "Isak", "Sin teclado se queda el apodo por defecto")
	assert_false(GameState.has_unsaved_changes(), "Sin cambio no marca «sin guardar»")


func test_space_and_a_d_are_text_not_actions() -> void:
	_open()
	_type("a d")
	assert_eq(_entry.get_text(), "a d", "Espacio, A y D escriben (no saltan ni mueven)")
	assert_true(_entry.is_open(), "Espacio no confirma")


func test_pause_is_released_when_removed_from_the_tree() -> void:
	_open()
	assert_true(get_tree().paused)
	_entry.free()
	_entry = null
	assert_false(get_tree().paused, "La pausa se libera siempre")


func test_does_not_steal_someone_elses_pause() -> void:
	get_tree().paused = true
	_open()
	assert_false(_entry.is_pausing_game())
	_entry.keep_current()
	assert_true(get_tree().paused, "No quita una pausa que no puso")


func test_nickname_tag_is_replaced_in_eco_lines_and_help() -> void:
	GameState.set_nickname("Maya")
	assert_eq(GameState.get_nickname(), "Maya")
	assert_eq(GameState.apply_nickname("Hola, {apodo}."), "Hola, Maya.")
	var box := BOX_SCENE.instantiate() as EcoTextBox
	add_child(box)
	box.show_line("Perfecto, {apodo}.", -1.0, false)
	assert_eq(box.get_text(), "Perfecto, Maya.", "El cuadro de Eco resuelve {apodo}")
	box.free()
	GameState.nickname = ""
	assert_eq(GameState.get_nickname(), GameState.NICKNAME_DEFAULT, "Vacio = «Isak»")

