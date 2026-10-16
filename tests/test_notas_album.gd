# Album de Notas (NotasAlbum; docs/propuesta-asistentes-y-vidas.md §3.5, paso 9
# de §10): una ficha por tipo de data/help.json en pestanas Enemigos / Objetos;
# los aprendidos (GameState.learned_help) muestran su ficha, nombre y texto; los
# demas, silueta «???» sin filtrar el nombre; contador por pestana; navegacion
# con flechas, pulso abre, salto vuelve; «Olvidar ayudas» vacia learned_help y
# marca «sin guardar». Usa su propia ruta de guardado.
extends GutTest

const PATH: String = "user://test_notas_album.json"

var _album: NotasAlbum
var _saved_path: String
var _closed: int = 0


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	_album = NotasAlbum.new()
	add_child(_album)
	_closed = 0
	_album.close_requested.connect(func() -> void: _closed += 1)


func after_each() -> void:
	if is_instance_valid(_album):
		_album.free()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _titles_of_unlearned() -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in HelpCatalog.shared().ids():
		if not GameState.is_help_learned(id):
			out.append(HelpCatalog.shared().title(id))
	return out


func _assert_no_leak() -> void:
	var titles: PackedStringArray = _titles_of_unlearned()
	for text: String in _album.get_visible_texts():
		for title: String in titles:
			assert_false(text.contains(title), "No se filtra «%s» (en «%s»)" % [title, text])


func test_album_lists_every_help_type_in_two_tabs_in_order() -> void:
	var enemies: Array[StringName] = NotasAlbum.album_ids(HelpCatalog.CATEGORY_ENEMY)
	var objects: Array[StringName] = NotasAlbum.album_ids(HelpCatalog.CATEGORY_OBJECT)
	assert_eq(enemies, [&"alert_bubble"] as Array[StringName])
	assert_eq(enemies.size() + objects.size(), HelpCatalog.shared().ids().size(), "Todos los tipos del 1-1")
	assert_eq(objects[0], &"attention_point", "Orden de help.json")
	for i: int in range(1, objects.size()):
		assert_true(int(HelpCatalog.shared().entry(objects[i - 1]).get("order", 0))
			< int(HelpCatalog.shared().entry(objects[i]).get("order", 0)))


func test_learned_types_show_their_card_and_others_a_silhouette() -> void:
	GameState.learn_help(&"alert_bubble")
	GameState.learn_help(&"receiver")
	_album.open()
	assert_eq(_album.get_tab(), "enemy", "Primera pestana: Enemigos")
	assert_eq(_album.get_counter_text(), "Fichas: 1/1")
	assert_eq(_album.get_cell_texts(), PackedStringArray(["Burbuja de alerta"]))
	assert_false(_album.is_cell_silhouette(0))
	assert_true(_album.set_tab("object"))
	var total: int = NotasAlbum.album_ids(HelpCatalog.CATEGORY_OBJECT).size()
	assert_eq(_album.get_counter_text(), "Fichas: 1/%d" % total)
	var texts: PackedStringArray = _album.get_cell_texts()
	var receiver: int = NotasAlbum.album_ids(HelpCatalog.CATEGORY_OBJECT).find(&"receiver")
	for i: int in texts.size():
		if i == receiver:
			assert_eq(texts[i], "Receptor del pulso")
			assert_false(_album.is_cell_silhouette(i))
			assert_eq(_album.get_cell_texture(i).resource_path, "res://assets/sprites/ui/album/album_card_receiver.png")
		else:
			assert_eq(texts[i], "???", "No aprendido: «???»")
			assert_true(_album.is_cell_silhouette(i))
			assert_true(_album.get_cell_texture(i).resource_path.ends_with("_silhouette.png"), "Silueta")
	_album.select_cell(0)
	_assert_no_leak()


func test_every_type_has_card_and_silhouette_art() -> void:
	for id: StringName in HelpCatalog.shared().ids():
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id), "Ficha de %s" % id)
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s_silhouette.png" % id),
			"Silueta de %s" % id)


func test_pulse_opens_a_learned_card_and_jump_goes_back() -> void:
	GameState.learn_help(&"alert_bubble")
	_album.open()
	_album.select_cell(0)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.CARD)
	assert_eq(_album.get_card_title(), "Burbuja de alerta")
	assert_true(_album.get_card_text().replace("\n", " ").begins_with("Una alerta."), "Texto de la ayuda de Eco")
	_album.cancel()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID)
	assert_eq(_closed, 0)
	_album.cancel()
	assert_eq(_closed, 1, "Salto desde la rejilla cierra")


func test_unlearned_card_does_not_open_nor_leak() -> void:
	_album.open()
	_album.set_tab("object")
	_album.select_cell(2)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID, "No abre la ficha")
	assert_ne(_album.get_message(), "", "Notas dice que aun no lo apunto")
	_assert_no_leak()


func test_arrows_move_through_tabs_grid_and_forget() -> void:
	_album.open()
	_album.set_tab("object")
	_album.select_cell(0)
	_album.move(1, 0)
	assert_eq(_album.get_selected_index(), 1)
	_album.move(0, 1)
	var columns: int = int(HubData.section("album").get("columns", 6))
	assert_eq(_album.get_selected_index(), 1 + columns, "Abajo: fila siguiente")
	# Filas de la rejilla (con la vida extra, paso 14, los objetos ocupan 3).
	var rows: int = ceili(float(_album.get_entries().size()) / float(columns))
	for i: int in rows - 1:
		_album.move(0, 1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.FORGET, "Bajo la rejilla: Olvidar ayudas")
	for i: int in rows + 1:
		_album.move(0, -1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.TABS, "Arriba de la rejilla: pestanas")
	_album.move(-1, 0)
	assert_eq(_album.get_tab(), "enemy", "Izquierda/derecha cambian de pestana")


func test_forget_help_asks_then_clears_and_marks_unsaved() -> void:
	GameState.learn_help(&"alert_bubble")
	GameState.learn_help(&"receiver")
	assert_false(GameState.has_unsaved_changes())
	_album.open()
	_album.move(0, 1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.FORGET)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.CONFIRM_FORGET, "Pide confirmacion")
	_album.confirm()
	assert_eq(GameState.learned_help.size(), 2, "No (por defecto) no olvida")
	_album.confirm()
	_album.move(1, 0)
	_album.confirm()
	assert_true(GameState.learned_help.is_empty(), "Olvida todas")
	assert_true(GameState.has_unsaved_changes(), "Marca «sin guardar»")
	assert_eq(_album.get_counter_text(), "Fichas: 0/1")
	assert_true(_album.is_cell_silhouette(0), "Vuelven las siluetas")


func test_album_texts_fit_the_font_and_never_say_lap_names() -> void:
	var font: Font = load("res://assets/sprites/ui/text_font.fnt") as Font
	var strings := PackedStringArray()
	for section: String in ["album", "notas"]:
		var texts: Dictionary = HubData.section(section).get("texts", {})
		for key: Variant in texts:
			strings.append(String(texts[key]))
	for tab: Dictionary in HubData.section("album").get("tabs", []):
		strings.append(String(tab.get("text", "")))
	for id: StringName in HelpCatalog.shared().ids():
		strings.append(HelpCatalog.shared().title(id))
	for text: String in strings:
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(text.contains(word), "«%s» no dice «%s»" % [text, word])
		for ch: String in text:
			assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s» (%s)" % [ch, text])
