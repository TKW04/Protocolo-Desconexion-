# Pestana «Recuerdos» del album de Notas (paso 3 de docs/propuesta-recuerdos.md
# §7; §3): por carpeta de mundo, secciones «Jefe» y «Mensajes»; las capas de un
# acceso no alcanzado no aparecen (ni su nombre); lo alcanzado y no obtenido sale
# «???» (los mensajes, sin remitente); contador «Recuerdos: n/N» solo con lo
# visible; ficha con titulo, capa o remitente y asunto y el texto (sin
# ilustracion), que marca el recuerdo leido; y la placa de recuerdo nuevo en el
# icono (estacion) de Notas del hub. Usa su propia ruta de guardado.
extends GutTest

const PATH: String = "user://test_notas_memories.json"

var _album: NotasAlbum
var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	_album = NotasAlbum.new()
	add_child(_album)


func after_each() -> void:
	if is_instance_valid(_album):
		_album.free()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _open_memories() -> void:
	_album.open()
	assert_true(_album.open_folder(1), "El Mundo 1 se ha visitado")
	assert_true(_album.set_tab(NotasAlbum.CATEGORY_MEMORY), "Pestana Recuerdos")


## Ningun texto visible nombra un acceso por encima del actual ni filtra lo no obtenido.
func _assert_no_leak() -> void:
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var hidden := PackedStringArray()
	for lap: int in range(GameState.lap + 1, 4):
		hidden.append(HubWorlds.access_name(lap))
	for id: StringName in catalog.ids():
		if not GameState.has_memory(id):
			for value: String in [catalog.sender(id), catalog.subject(id)]:
				if not value.is_empty() and not value.contains("por escribir"):
					hidden.append(value)
			if not catalog.title(id).contains("por escribir"):
				hidden.append(catalog.title(id))
	for text: String in _album.get_visible_texts():
		for word: String in hidden:
			var obtained_title: bool = false
			for id: StringName in catalog.ids():
				if GameState.has_memory(id) and (catalog.title(id) == word or catalog.sender(id) == word):
					obtained_title = true
			if obtained_title:
				continue
			assert_false(text.contains(word), "No se filtra «%s» (en «%s»)" % [word, text])


func test_tabs_include_memories_after_objects() -> void:
	var tabs: Array = HubData.section("album").get("tabs", [])
	assert_eq(String(tabs[tabs.size() - 1].get("category", "")), NotasAlbum.CATEGORY_MEMORY)
	assert_eq(String(tabs[tabs.size() - 1].get("text", "")), "Recuerdos")
	_album.open()
	_album.set_tab("object")
	_album.move(0, -1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.TABS)
	_album.move(1, 0)
	assert_eq(_album.get_tab(), NotasAlbum.CATEGORY_MEMORY, "Derecha desde Objetos: Recuerdos")


func test_cache_shows_one_boss_layer_and_the_messages_as_unknown() -> void:
	GameState.lap = GameState.LAP_EASY
	_open_memories()
	assert_eq(_album.get_memory_rows(), PackedStringArray(["Jefe", "Caché: ???", "Mensajes", "???", "???", "???"]))
	assert_eq(_album.get_counter_text(), "Recuerdos: 0/4", "Solo lo visible: una capa y tres mensajes")
	_assert_no_leak()


func test_obtained_memories_show_title_and_sender_and_are_new() -> void:
	GameState.obtain_memory(&"boss_w1_l1")
	GameState.obtain_memory(&"msg_1_2")
	_open_memories()
	assert_eq(_album.get_memory_rows(), PackedStringArray(["Jefe", "Caché: Fragmento de concentración - Nuevo",
		"Mensajes", "???", "Mamá · ¿Cenas con nosotros? - Nuevo", "???"]))
	assert_eq(_album.get_counter_text(), "Recuerdos: 2/4")
	_assert_no_leak()


func test_layers_appear_with_each_access() -> void:
	GameState.obtain_memory(&"boss_w1_l1")
	GameState.lap = GameState.LAP_NORMAL
	_open_memories()
	var rows: PackedStringArray = _album.get_memory_rows()
	assert_eq(rows.slice(0, 3), PackedStringArray(["Jefe", "Caché: Fragmento de concentración - Nuevo", "Kernel: ???"]))
	assert_eq(_album.get_counter_text(), "Recuerdos: 1/5", "Kernel: dos capas y los tres mensajes de Caché")
	_assert_no_leak()
	GameState.lap = GameState.LAP_HARD
	_album.refresh()
	assert_eq(_album.get_memory_rows()[3], "Raíz: ???")
	assert_eq(_album.get_counter_text(), "Recuerdos: 1/6")


func test_boss_card_shows_layer_and_text_and_marks_read() -> void:
	GameState.obtain_memory(&"boss_w1_l1")
	_open_memories()
	_album.select_cell(0)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.CARD)
	assert_eq(_album.get_card_title(), "Fragmento de concentración")
	assert_true(_album.get_card_text().begins_with("Capa: Caché"), _album.get_card_text())
	assert_true(_album.get_card_text().contains("Archivado"), "Con el texto del recuerdo")
	assert_true(GameState.is_memory_read(&"boss_w1_l1"), "Abrir la ficha lo marca leido")
	_album.cancel()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID)
	assert_eq(_album.get_memory_rows()[1], "Caché: Fragmento de concentración", "Ya no es nuevo")


func test_message_card_shows_sender_and_subject() -> void:
	GameState.obtain_memory(&"msg_1_2")
	_open_memories()
	_album.select_cell(2)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.CARD)
	var text: String = _album.get_card_text()
	assert_true(text.begins_with("De: Mamá\nAsunto: ¿Cenas con nosotros?"), text)
	assert_true(text.contains("sopa"))
	for line: String in text.split("\n"):
		assert_false(line.contains("Capa:"), "Los mensajes no tienen capa")


func test_unknown_memory_does_not_open() -> void:
	_open_memories()
	_album.select_cell(1)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID)
	assert_eq(_album.get_message(), "Aún no lo has encontrado")
	_assert_no_leak()


func test_arrows_move_through_the_memory_list() -> void:
	_open_memories()
	assert_eq(_album.get_selected_index(), 0)
	_album.move(0, 1)
	assert_eq(_album.get_selected_index(), 1)
	for i: int in 10:
		_album.move(0, 1)
	assert_eq(_album.get_selected_index(), _album.get_entries().size() - 1, "No pasa del ultimo")
	for i: int in 10:
		_album.move(0, -1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.TABS, "Arriba del primero: pestanas")


func test_memory_texts_fit_the_font_and_never_say_lap_names() -> void:
	var font: Font = load("res://assets/sprites/ui/text_font.fnt") as Font
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var strings := PackedStringArray()
	for id: StringName in catalog.ids():
		strings.append_array([catalog.title(id), catalog.text(id), catalog.sender(id), catalog.subject(id)])
	for text: String in strings:
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(text.contains(word), "«%s» no dice «%s»" % [text, word])
		for ch: String in text:
			if ch != "\n":
				assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s» (%s)" % [ch, text])


# --- Placa de recuerdo nuevo en Notas (hub) ---

func test_notas_station_marks_unread_memories() -> void:
	var station := NotasStation.new()
	station.station_id = &"notas"
	add_child(station)
	assert_false(station.is_unread_badge_visible(), "Nada nuevo")
	GameState.obtain_memory(&"msg_1_1")
	assert_true(station.is_unread_badge_visible(), "Recuerdo sin leer: placa")
	station.set_powered(false)
	assert_false(station.is_unread_badge_visible(), "Apagada no marca nada")
	station.set_powered(true)
	assert_true(station.is_unread_badge_visible())
	GameState.mark_memory_read(&"msg_1_1")
	assert_false(station.is_unread_badge_visible(), "Leido: sin placa")
	station.free()
