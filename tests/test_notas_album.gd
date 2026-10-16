# Album de Notas (NotasAlbum; docs/propuesta-asistentes-y-vidas.md §3.5, paso 9
# de §10; carpetas por mundo desde el 2026-10-16): al abrir, una carpeta por
# mundo (1-6) con contador global; los mundos visitados muestran su nombre
# (worlds de data/hub.json) y su contador «n/N»; los no alcanzados salen
# cerrados con candado y «???» sin filtrar nada. Al abrir una carpeta, pestanas
# Enemigos / Objetos con las fichas aprendidas (nombre y texto) y siluetas
# «???»; pulso abre, salto vuelve (ficha -> carpeta -> carpetas -> cerrar). Sin
# «Olvidar ayudas». Usa su propia ruta de guardado.
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
	var hidden_worlds := PackedStringArray()
	for world: int in range(1, NotasAlbum.world_count() + 1):
		if not NotasAlbum.is_world_visited(world) and not NotasAlbum.world_name(world).is_empty():
			hidden_worlds.append(NotasAlbum.world_name(world))
	for text: String in _album.get_visible_texts():
		for title: String in titles:
			assert_false(text.contains(title), "No se filtra «%s» (en «%s»)" % [title, text])
		for world_name: String in hidden_worlds:
			assert_false(text.contains(world_name), "No se filtra el mundo «%s» (en «%s»)" % [world_name, text])


# --- Datos ---

func test_every_help_type_has_a_world() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HelpCatalog.DEFAULT_PATH))
	for id: String in raw["types"]:
		var entry: Dictionary = raw["types"][id]
		assert_true(entry.has("world"), "%s tiene world" % id)
		var world: int = int(entry.get("world", 0))
		assert_between(world, 1, NotasAlbum.world_count(), "%s: mundo de 1 a 6" % id)
		var level_world: Dictionary = HubWorlds.world_of_level(StringName(String(entry.get("first_level", ""))))
		if not level_world.is_empty():
			assert_eq(int(level_world.get("world", 0)), world, "%s: world coincide con su first_level" % id)
	for id: StringName in HelpCatalog.shared().ids():
		assert_eq(HelpCatalog.shared().world(id), 1, "Hoy todos los tipos son del Mundo 1 (%s)" % id)


func test_album_lists_every_type_of_world_1_in_two_sections_in_order() -> void:
	var enemies: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_ENEMY)
	var objects: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_OBJECT)
	assert_eq(enemies, [&"alert_bubble"] as Array[StringName])
	assert_eq(enemies.size() + objects.size(), HelpCatalog.shared().ids().size(), "Todos los tipos del 1-1")
	assert_eq(objects[0], &"attention_point", "Orden de help.json")
	for i: int in range(1, objects.size()):
		assert_true(int(HelpCatalog.shared().entry(objects[i - 1]).get("order", 0))
			< int(HelpCatalog.shared().entry(objects[i]).get("order", 0)))
	for world: int in range(2, 7):
		assert_eq(NotasAlbum.album_ids(world).size(), 0, "Mundo %d aun sin tipos" % world)


func test_visited_rule() -> void:
	assert_eq(NotasAlbum.world_count(), 6)
	assert_true(NotasAlbum.is_world_visited(1), "Mundo 1: desbloqueado desde el inicio")
	assert_false(NotasAlbum.is_world_visited(2), "Mundo 2 sin alcanzar")
	assert_false(NotasAlbum.is_world_visited(6), "Mundo 6 sin datos")
	GameState.unlocked_levels[&"m2-dummy"] = true  # Un nivel que no es del Mundo 2 no cuenta.
	assert_false(NotasAlbum.is_world_visited(2))


# --- Vista de carpetas ---

## Nombres de los mundos del diseno (docs/INDEX.md y docs/mundo-N-*.md).
const DESIGN_WORLD_NAMES: Array[String] = ["Notificaciones", "El Feed", "La Vitrina", "El Chat", "La Tienda",
	"La Nube"]


func test_world_names_come_from_the_design_and_hub_json() -> void:
	for i: int in DESIGN_WORLD_NAMES.size():
		assert_eq(NotasAlbum.world_name(i + 1), DESIGN_WORLD_NAMES[i], "Mundo %d en worlds de data/hub.json" % (i + 1))
	assert_eq(HubWorlds.world_title(NotasAlbum.world_entry(1)), "Mundo 1 - Notificaciones",
		"Mismo formato que el panel de subniveles")
	var album_texts: Dictionary = HubData.section("album").get("texts", {})
	assert_false(album_texts.has("folder_title"), "Una sola fuente del formato: folders.texts.title")


func test_reached_world_shows_its_name_and_locked_ones_hide_it() -> void:
	# Se simula que el Mundo 4 ya se alcanzo (hoy no tiene subniveles).
	var m4: Dictionary = NotasAlbum.world_entry(4)
	m4["unlocked"] = true
	_album.open()
	var texts: PackedStringArray = _album.get_folder_texts(3)
	m4["unlocked"] = false
	assert_eq(texts, PackedStringArray(["Mundo 4", "El Chat", "0/0"]), "Alcanzado: su nombre")
	_album.close()
	_album.open()
	assert_eq(_album.get_folder_texts(3), PackedStringArray(["Mundo 4", "???", ""]), "Sin alcanzar: «???»")
	for i: int in range(1, 6):
		assert_true(_album.is_folder_locked(i))
		for name: String in DESIGN_WORLD_NAMES:
			for text: String in _album.get_folder_texts(i):
				assert_false(text.contains(name), "Mundo %d bloqueado no filtra «%s»" % [i + 1, name])
	_assert_no_leak()


func test_open_folder_title_uses_the_panel_format() -> void:
	_album.open()
	_album.confirm()
	assert_eq(_album.get_title_text(), HubWorlds.world_title(NotasAlbum.world_entry(1)))
	assert_eq(_album.get_title_text(), "Mundo 1 - Notificaciones")



func test_opens_on_the_folders_view_with_counters() -> void:
	GameState.learn_help(&"alert_bubble")
	GameState.learn_help(&"receiver")
	_album.open()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.FOLDERS, "Primero, las carpetas")
	var total: int = NotasAlbum.album_ids(1).size()
	assert_eq(_album.get_counter_text(), "Fichas: 2/%d" % total, "Contador global")
	assert_eq(_album.get_folder_texts(0), PackedStringArray(["Mundo 1", "Notificaciones", "2/%d" % total]))
	assert_false(_album.is_folder_locked(0))
	assert_eq(_album.get_folder_icon(0).resource_path, "res://assets/sprites/hub/album/album_folder_open_00.png",
		"La elegida, abierta")
	for i: int in range(1, 6):
		assert_true(_album.is_folder_locked(i), "Mundo %d cerrado" % (i + 1))
		assert_eq(_album.get_folder_texts(i), PackedStringArray(["Mundo %d" % (i + 1), "???", ""]),
			"Sin nombre ni contador")
		assert_eq(_album.get_folder_icon(i).resource_path,
			"res://assets/sprites/hub/album/album_folder_locked_00.png", "Con candado")
	_album.move(1, 0)
	assert_eq(_album.get_folder_icon(0).resource_path, "res://assets/sprites/hub/album/album_folder_closed_00.png",
		"No elegida: cerrada")
	_assert_no_leak()


func test_locked_folder_does_not_open() -> void:
	_album.open()
	_album.move(1, 0)
	assert_eq(_album.get_selected_folder(), 1)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.FOLDERS, "Mundo sin alcanzar: no se abre")
	assert_ne(_album.get_message(), "")
	_assert_no_leak()


func test_a_world_becomes_visited_with_hub_worlds() -> void:
	GameState.reset_progress()
	var m2: Dictionary = NotasAlbum.world_entry(2)
	assert_false(m2.is_empty(), "El Mundo 2 esta en worlds de data/hub.json")
	# Con un subnivel desbloqueado (hoy el Mundo 2 no tiene: se simula con el dato).
	var levels: Array = m2.get("levels", [])
	if levels.is_empty():
		pass_test("El Mundo 2 aun no tiene subniveles; la regla la cubre HubWorlds.is_world_unlocked")
		return
	GameState.unlocked_levels[StringName(String(levels[0]["id"]))] = true
	assert_true(NotasAlbum.is_world_visited(2))


func test_arrows_move_between_folders() -> void:
	_album.open()
	assert_eq(_album.get_selected_folder(), 0)
	_album.move(0, 1)
	assert_eq(_album.get_selected_folder(), 2, "Abajo: fila siguiente (dos columnas)")
	_album.move(1, 0)
	assert_eq(_album.get_selected_folder(), 3)
	_album.move(0, 1)
	_album.move(0, 1)
	assert_eq(_album.get_selected_folder(), 5, "No pasa de la ultima fila")
	_album.move(0, -1)
	assert_eq(_album.get_selected_folder(), 3)


# --- Dentro de una carpeta ---

func test_open_folder_shows_cards_and_silhouettes() -> void:
	GameState.learn_help(&"alert_bubble")
	GameState.learn_help(&"receiver")
	_album.open()
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID, "Pulso abre la carpeta")
	assert_eq(_album.get_world(), 1)
	assert_eq(_album.get_title_text(), "Mundo 1 - Notificaciones")
	assert_eq(_album.get_tab(), "enemy", "Primera seccion: Enemigos")
	assert_eq(_album.get_counter_text(), "Fichas: 1/1")
	assert_eq(_album.get_cell_texts(), PackedStringArray(["Burbuja de alerta"]))
	assert_false(_album.is_cell_silhouette(0))
	assert_true(_album.set_tab("object"))
	var objects: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_OBJECT)
	assert_eq(_album.get_counter_text(), "Fichas: 1/%d" % objects.size())
	var texts: PackedStringArray = _album.get_cell_texts()
	var receiver: int = objects.find(&"receiver")
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


func test_pulse_opens_a_card_and_jump_goes_back_step_by_step() -> void:
	GameState.learn_help(&"alert_bubble")
	_album.open()
	_album.confirm()
	_album.select_cell(0)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.CARD)
	assert_eq(_album.get_card_title(), "Burbuja de alerta")
	assert_true(_album.get_card_text().replace("\n", " ").begins_with("Una alerta."), "Texto de la ayuda de Eco")
	_album.cancel()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID, "Ficha -> carpeta")
	_album.cancel()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.FOLDERS, "Carpeta -> carpetas")
	assert_eq(_album.get_selected_folder(), 0, "Con la carpeta abierta elegida")
	assert_eq(_closed, 0)
	_album.cancel()
	assert_eq(_closed, 1, "Salto desde las carpetas cierra")


func test_unlearned_card_does_not_open_nor_leak() -> void:
	_album.open()
	_album.set_tab("object")
	_album.select_cell(2)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.GRID, "No abre la ficha")
	assert_ne(_album.get_message(), "", "Notas dice que aun no lo apunto")
	_assert_no_leak()


func test_arrows_move_through_tabs_and_grid() -> void:
	_album.open()
	_album.set_tab("object")
	_album.select_cell(0)
	_album.move(1, 0)
	assert_eq(_album.get_selected_index(), 1)
	_album.move(0, 1)
	var columns: int = int(HubData.section("album").get("columns", 6))
	assert_eq(_album.get_selected_index(), 1 + columns, "Abajo: fila siguiente")
	var rows: int = ceili(float(_album.get_entries().size()) / float(columns))
	for i: int in rows + 1:
		_album.move(0, 1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.GRID, "Bajo la rejilla no hay nada mas")
	# Ultima fila: misma columna si existe; si no (fila incompleta), la ultima ficha.
	assert_eq(_album.get_selected_index(), mini(1 + (rows - 1) * columns, _album.get_entries().size() - 1))
	for i: int in rows + 1:
		_album.move(0, -1)
	assert_eq(_album.get_focus(), NotasAlbum.Focus.TABS, "Arriba de la rejilla: pestanas")
	_album.move(-1, 0)
	assert_eq(_album.get_tab(), "enemy", "Izquierda/derecha cambian de pestana")


func test_no_forget_option() -> void:
	GameState.learn_help(&"receiver")
	_album.open()
	assert_false(GameState.has_method(&"forget_help"), "GameState.forget_help ya no existe")
	assert_false("FORGET" in NotasAlbum.Focus.keys())
	for text: String in _album.get_visible_texts():
		assert_false(text.contains("Olvidar"), "Sin «Olvidar» (%s)" % text)
	_album.confirm()
	for i: int in 20:
		_album.move(0, 1)
	_album.confirm()
	for text: String in _album.get_visible_texts():
		assert_false(text.contains("Olvidar"), "Sin «Olvidar» dentro de la carpeta (%s)" % text)
	assert_true(GameState.is_help_learned(&"receiver"), "Nada se olvida")
	for key: Variant in HubData.section("album").get("texts", {}):
		assert_false(String(key).begins_with("forget"), "Sin textos de olvidar en data/hub.json (%s)" % key)


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
	for world: int in range(1, NotasAlbum.world_count() + 1):
		strings.append(NotasAlbum.world_name(world))
	for text: String in strings:
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(text.contains(word), "«%s» no dice «%s»" % [text, word])
		for ch: String in text:
			assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s» (%s)" % [ch, text])
