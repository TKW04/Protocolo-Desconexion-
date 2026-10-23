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
	# Desde el 2026-10-22 (paso 4 de docs/propuesta-mundo-2.md) hay tipos del Mundo 2.
	for id: StringName in HelpCatalog.shared().ids():
		assert_between(HelpCatalog.shared().world(id), 1, 2, "Hoy los tipos son del Mundo 1 o 2 (%s)" % id)


func test_album_lists_every_type_of_world_1_in_two_sections_in_order() -> void:
	var enemies: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_ENEMY)
	var objects: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_OBJECT)
	assert_eq(enemies, [&"alert_bubble", &"notification_badge", &"spam_banner", &"spam_banner_dash", &"alarm_bell",
		&"alert_major", &"alert_major_bubble", &"notification_shot", &"alert_major_clone"] as Array[StringName],
		"Burbuja (1-1), punto rojo y banner (1-2), banner obligatorio con el dash y campana (1-3) y Alerta Mayor, sus Burbujas, la rafaga y las copias (1-boss), en orden")
	assert_eq(enemies.size() + objects.size() + NotasAlbum.album_ids(2).size(), HelpCatalog.shared().ids().size(),
		"Todos los tipos del Mundo 1 (y los del Mundo 2 aparte)")
	assert_eq(objects[0], &"attention_point", "Orden de help.json")
	for i: int in range(1, objects.size()):
		assert_true(int(HelpCatalog.shared().entry(objects[i - 1]).get("order", 0))
			< int(HelpCatalog.shared().entry(objects[i]).get("order", 0)))
	assert_eq(NotasAlbum.album_ids(2, HelpCatalog.CATEGORY_OBJECT),
		[&"fragile_card", &"story_card", &"loop_section", &"loading_wall", &"pause_player", &"hud_clock",
			&"feed_edge", &"autoplay_playhead", &"autoplay_pause_button", &"autoplay_card",
			&"autoplay_countdown"] as Array[StringName],
		"Mundo 2: tarjeta fragil, Historia (paso 4), seccion en bucle (paso 5), muro «Cargando mas…» (paso 7), reproductor (paso 8), la hora y el borde del feed (paso 11) y el cabezal, el boton de pausa, la cinta y la cuenta de Autoplay (paso 20)")
	assert_eq(NotasAlbum.album_ids(2, HelpCatalog.CATEGORY_ENEMY),
		[&"autoplay_video", &"video_clone", &"commenter", &"autoplay", &"autoplay_clip", &"autoplay_fan"] as Array[StringName],
		"Mundo 2: el video en autoplay (paso 6), el clon y el Comentarista (paso 7 de docs/propuesta-mundo-2.md) y Autoplay, sus clips y el abanico (paso 20)")
	for world: int in range(3, 7):
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
		"El panel de subniveles conserva «Mundo n - nombre»")
	var album_texts: Dictionary = HubData.section("album").get("texts", {})
	assert_false(album_texts.has("folder_title"), "El album no tiene formato propio de titulo")
	assert_false(album_texts.has("folder_number"), "El album ya no muestra «Mundo n» (2026-10-18)")


## 2026-10-18 (decision del usuario): SOLO el nombre del mundo, en una sola
## linea que cabe en la carpeta (los 6 nombres, alcanzados o no).
func test_folder_names_fit_on_one_line() -> void:
	var worlds: Array[Dictionary] = []
	for i: int in DESIGN_WORLD_NAMES.size():
		var entry: Dictionary = NotasAlbum.world_entry(i + 1)
		entry["unlocked"] = true
		worlds.append(entry)
	_album.open()
	for i: int in DESIGN_WORLD_NAMES.size():
		var texts: PackedStringArray = _album.get_folder_texts(i)
		assert_eq(texts[0], DESIGN_WORLD_NAMES[i], "Carpeta %d: solo el nombre" % (i + 1))
		var label: Label = _album.get_folder_name_label(i)
		var font: Font = label.get_theme_font(&"font")
		var width: float = font.get_string_size(texts[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size(&"font_size")).x
		assert_true(width <= label.size.x, "«%s» cabe en una linea (%.0f <= %.0f px)" % [texts[0], width, label.size.x])
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_OFF, "Sin partir en dos lineas")
		assert_false(texts[0].contains("Mundo"), "Sin «Mundo n»")
	for i: int in worlds.size():
		worlds[i]["unlocked"] = i == 0
	_album.close()


func test_reached_world_shows_its_name_and_locked_ones_hide_it() -> void:
	# Se simula que el Mundo 4 ya se alcanzo (hoy no tiene subniveles).
	var m4: Dictionary = NotasAlbum.world_entry(4)
	m4["unlocked"] = true
	_album.open()
	var texts: PackedStringArray = _album.get_folder_texts(3)
	m4["unlocked"] = false
	assert_eq(texts, PackedStringArray(["El Chat", "0/0"]), "Alcanzado: solo su nombre")
	_album.close()
	_album.open()
	assert_eq(_album.get_folder_texts(3), PackedStringArray(["???", ""]), "Sin alcanzar: «???»")
	for i: int in range(1, 6):
		assert_true(_album.is_folder_locked(i))
		for name: String in DESIGN_WORLD_NAMES:
			for text: String in _album.get_folder_texts(i):
				assert_false(text.contains(name), "Mundo %d bloqueado no filtra «%s»" % [i + 1, name])
	_assert_no_leak()


func test_open_folder_title_is_only_the_world_name() -> void:
	_album.open()
	assert_null(_album.get_title_icon(), "Vista de carpetas: sin miniatura en el titulo")
	_album.confirm()
	assert_eq(_album.get_title_text(), "Notificaciones", "Solo el nombre del mundo (2026-10-18)")
	assert_eq(_album.get_title_icon(), NotasAlbum.world_miniature(1), "Con la miniatura del Mundo 1 (campana)")
	assert_not_null(_album.get_title_icon())
	assert_ne(_album.get_title_text(), HubWorlds.world_title(NotasAlbum.world_entry(1)),
		"El panel de subniveles conserva su formato; el album no")



func test_opens_on_the_folders_view_with_counters() -> void:
	GameState.learn_help(&"alert_bubble")
	GameState.learn_help(&"receiver")
	_album.open()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.FOLDERS, "Primero, las carpetas")
	var total: int = NotasAlbum.album_ids(1).size()
	assert_eq(_album.get_counter_text(), "Fichas: 2/%d" % total, "Contador global")
	assert_eq(_album.get_folder_texts(0), PackedStringArray(["Notificaciones", "2/%d" % total]))
	assert_false(_album.is_folder_locked(0))
	assert_not_null(_album.get_folder_miniature(0), "Miniatura del Mundo 1 sobre su carpeta")
	assert_eq(_album.get_folder_miniature(0).resource_path, String(NotasAlbum.world_entry(1)["miniature"]))
	assert_eq(_album.get_folder_icon(0).resource_path, "res://assets/sprites/hub/album/album_folder_open_00.png",
		"La elegida, abierta")
	for i: int in range(1, 6):
		assert_true(_album.is_folder_locked(i), "Mundo %d cerrado" % (i + 1))
		assert_eq(_album.get_folder_texts(i), PackedStringArray(["???", ""]),
			"Sin nombre, sin numero ni contador")
		assert_null(_album.get_folder_miniature(i), "Mundo %d cerrado: sin miniatura" % (i + 1))
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
	assert_eq(_album.get_title_text(), "Notificaciones")
	assert_eq(_album.get_tab(), "enemy", "Primera seccion: Enemigos")
	assert_eq(_album.get_counter_text(), "Fichas: 1/9")
	assert_eq(_album.get_cell_texts(), PackedStringArray(["Burbuja de alerta", "???", "???", "???", "???", "???", "???",
		"???", "???"]),
		"Punto rojo y banners sin aprender: «???»")
	assert_false(_album.is_cell_silhouette(0))
	assert_true(_album.is_cell_silhouette(1))
	assert_true(_album.is_cell_silhouette(2))
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


func test_red_dot_and_banner_cards_in_the_enemies_tab() -> void:
	GameState.learn_help(&"notification_badge")
	GameState.learn_help(&"spam_banner")
	_album.open()
	_album.confirm()
	assert_eq(_album.get_tab(), "enemy")
	assert_eq(_album.get_counter_text(), "Fichas: 2/9")
	assert_eq(_album.get_cell_texts(), PackedStringArray(["???", "Punto rojo", "Banner", "???", "???", "???", "???", "???",
		"???"]))
	assert_true(_album.is_cell_silhouette(0), "La Burbuja sin aprender: silueta")
	assert_eq(_album.get_cell_texture(1).resource_path, "res://assets/sprites/ui/album/album_card_notification_badge.png")
	assert_eq(_album.get_cell_texture(2).resource_path, "res://assets/sprites/ui/album/album_card_spam_banner.png")
	_album.select_cell(1)
	_album.confirm()
	assert_eq(_album.get_mode(), NotasAlbum.Mode.CARD)
	assert_eq(_album.get_card_title(), "Punto rojo")
	assert_true(_album.get_card_text().replace("\n", " ").begins_with("Un aviso sin leer."), "Texto de su ayuda")
	_album.cancel()
	_album.select_cell(2)
	_album.confirm()
	assert_eq(_album.get_card_title(), "Banner")
	assert_true(_album.get_card_text().replace("\n", " ").begins_with("Publicidad que cruza"))
	_assert_no_leak()


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


## Pisos 3 y 4 del 1-2 (pasos 6-8): recordatorio, Posponer, pop-up translucido y
## barra del 99 %, en la pestana Objetos del Mundo 1, al final y en orden.
func test_tower_objects_cards_in_the_objects_tab() -> void:
	var objects: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_OBJECT)
	# Despues van las piezas del encuentro con Calc (2026-10-17): ver la prueba siguiente.
	var start: int = objects.find(&"reminder_platform")
	var tail: Array[StringName] = objects.slice(start, start + 4)
	assert_eq(tail, [&"reminder_platform", &"snooze_button", &"overlay_popup", &"update_bar"] as Array[StringName])
	for id: StringName in tail:
		assert_eq(HelpCatalog.shared().category(id), HelpCatalog.CATEGORY_OBJECT)
		assert_eq(String(HelpCatalog.shared().entry(id).get("first_level", "")), "1-2")
	assert_eq(HelpCatalog.shared().title(&"overlay_popup"), "Pop-up translúcido")


## Encuentro con Calc en la azotea del 1-2 (2026-10-17, tanda H1 del paso 14):
## interruptor de pulso, interruptor laser, panel oculto y punto de carga, al
## final de la pestana Objetos del Mundo 1, en orden y con ficha.
func test_calc_room_cards_in_the_objects_tab() -> void:
	var objects: Array[StringName] = NotasAlbum.album_ids(1, HelpCatalog.CATEGORY_OBJECT)
	# Despues van el mensaje de secreto (memory_pickup, paso 4 de propuesta-recuerdos.md, 2026-10-19)
	# y los objetos del 1-3 (interruptor «No molestar» y plataforma que vibra, paso 8 de propuesta-1-3.md).
	# Y al final, los del jefe Alerta Mayor (nucleo, pop-up insistente y escudo; paso 12 del jefe, 2026-10-21).
	assert_eq(objects.slice(objects.size() - 3), [&"alert_major_core", &"alert_major_popup", &"boss_popup_shield"] as Array[StringName])
	assert_eq(objects.slice(objects.size() - 6, objects.size() - 3), [&"memory_pickup", &"dnd_switch", &"blink_platform"] as Array[StringName])
	var tail: Array[StringName] = objects.slice(objects.size() - 10, objects.size() - 6)
	assert_eq(tail, [&"power_switch", &"laser_switch", &"debug_switch", &"charge_dock"] as Array[StringName])
	for id: StringName in tail:
		assert_eq(String(HelpCatalog.shared().entry(id).get("first_level", "")), "1-2")
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id), "Ficha de %s" % id)
