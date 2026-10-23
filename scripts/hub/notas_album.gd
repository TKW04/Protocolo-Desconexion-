## Album de Notas (docs/propuesta-asistentes-y-vidas.md §3.5, paso 9 de §10;
## carpetas por mundo desde el 2026-10-16, decision del usuario): una ficha por
## TIPO de ayuda con Q (data/help.json: mundo, categoria, orden y textos; no se
## duplican aqui). Lo abre NotasStation desde su panel («Álbum»). Aspecto,
## textos y colores en la seccion album de data/hub.json.
## - Vista de CARPETAS (al abrir): una por mundo (1..world_count, 6) en una
##   rejilla de folder_columns columnas, con el contador global «Fichas: n/N»
##   (tipos de los mundos visitados). Carpeta de un mundo visitado: icono de
##   carpeta (album_folder_closed; la elegida, album_folder_open) con la
##   miniatura del mundo encima si la tiene (miniature de worlds), SOLO el
##   nombre del mundo en una linea (worlds de data/hub.json; sin «Mundo n»,
##   2026-10-18, decision del usuario) y su contador «n/N». Mundo sin alcanzar:
##   carpeta bloqueada con candado y «???»; ni su nombre, ni su numero, ni sus
##   fichas, ni su contador se muestran.
## - Regla de mundo visitado (is_world_visited): el mundo existe en worlds de
##   data/hub.json y HubWorlds lo da por desbloqueado (unlocked en los datos, o
##   alguno de sus subniveles en unlocked_levels / completed_levels), o el
##   jugador ha aprendido algun tipo de ese mundo (world de help.json).
## - Al abrir una carpeta: titulo con SOLO el nombre del mundo (y su miniatura a
##   la izquierda si la tiene; el panel de subniveles del hub sigue con
##   «Mundo 1 - Notificaciones», HubWorlds.world_title); sus dos pestanas (tabs: Enemigos y Objetos) con su
##   contador «Fichas: n/N», rejilla de celdas (marco album_cell; la elegida,
##   album_cell_selected). Tipo aprendido (GameState.learned_help): su ficha
##   (tools/gen_album_cards.py). No aprendido: la silueta con «???»; ni el
##   nombre ni el texto se muestran en ningun sitio.
## - Controles (Input Map, como los paneles del hub): flechas eligen (carpetas;
##   dentro, fila de pestanas y rejilla), el pulso abre la carpeta o la ficha
##   (dibujo x2, nombre y texto de Eco, con {apodo}), el salto vuelve (ficha ->
##   carpeta -> carpetas -> cerrar: close_requested).
## (Desde el 2026-10-16 el album no tiene «Olvidar ayudas».)
## - Pestana «Recuerdos» (2026-10-19, paso 3 de docs/propuesta-recuerdos.md §7;
##   §3; category memory de tabs, datos de data/memories.json): una lista con
##   las secciones «Jefe» (las capas del recuerdo de jefe cuyo acceso ya se
##   alcanzo, GameState.lap; las de un acceso no alcanzado no aparecen, ni su
##   nombre) y «Mensajes» (los mensajes de secretos con first_lap alcanzado). Lo
##   no obtenido sale «???» (en los mensajes, sin remitente); lo obtenido sin
##   leer, con «Nuevo». Contador «Recuerdos: n/N» de lo visible. La ficha (sin
##   ilustracion todavia) muestra titulo, capa (Caché, Kernel, Raíz;
##   HubWorlds.access_name) o remitente y asunto, y el texto; abrirla lo marca
##   leido (GameState.mark_memory_read).
class_name NotasAlbum
extends CanvasLayer

const CATEGORY_MEMORY: String = "memory"

enum Mode { FOLDERS, GRID, CARD }
enum Focus { TABS, GRID }

## El jugador pide cerrar el album.
signal close_requested

var _cfg: Dictionary = HubData.section("album")
var _font: Font
var _shader: Shader
var _key_color: Color
var _frame: Control
var _panel: NinePatchRect
## Miniatura del mundo junto al titulo de la carpeta abierta.
var _title_icon: TextureRect
var _labels: Dictionary[StringName, Label] = {}
## Pie de teclas (MenuHints, data/menu_hints.json: album_folders / album_grid / album_card).
var _hints: MenuHints
var _tab_labels: Array[Label] = []
var _cells: Array[Control] = []
var _folders: Array[Control] = []
## Filas de la pestana Recuerdos (cabeceras de seccion y recuerdos).
var _memory_rows: Array[Label] = []
## Filas visibles ahora: {text, role, entry} (entry -1 en las cabeceras).
var _rows: Array[Dictionary] = []
var _card_big: TextureRect
## Ilustracion de la ficha de un recuerdo de jefe (capas Caché y Kernel; §8.3).
var _memory_art: TextureRect
var _body_label: Label
var _open: bool = false
var _open_time: float = 0.0
var _mode: Mode = Mode.FOLDERS
var _focus: Focus = Focus.GRID
var _tab: int = 0
var _selected: int = 0
var _folder_selected: int = 0
var _world: int = 1
var _entries: Array[Dictionary] = []


# --- Datos (estaticos) ---

## Numero de carpetas (mundos 1..N).
static func world_count() -> int:
	return maxi(1, int(HubData.section("album").get("world_count", 6)))


## Entrada de worlds de data/hub.json del mundo `world` (vacia si no existe).
static func world_entry(world: int) -> Dictionary:
	for entry: Dictionary in HubWorlds.worlds():
		if int(entry.get("world", 0)) == world:
			return entry
	return {}


## Nombre del mundo (worlds de data/hub.json; vacio si no existe).
static func world_name(world: int) -> String:
	return String(world_entry(world).get("name", ""))


## Miniatura del mundo (miniature de worlds; null si no tiene o no existe).
static func world_miniature(world: int) -> Texture2D:
	var path: String = String(world_entry(world).get("miniature", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Mundo visitado: desbloqueado segun HubWorlds (unlocked o algun subnivel
## desbloqueado o completado) o con algun tipo aprendido.
static func is_world_visited(world: int) -> bool:
	var entry: Dictionary = world_entry(world)
	if not entry.is_empty() and HubWorlds.is_world_unlocked(entry):
		return true
	for id: StringName in album_ids(world):
		if GameState.is_help_learned(id):
			return true
	return false


## Tipos del mundo `world` (de la categoria `category`, enemy u object; vacia:
## todas) en su orden de data/help.json.
static func album_ids(world: int, category: String = "") -> Array[StringName]:
	var catalog: HelpCatalog = HelpCatalog.shared()
	var ids: Array[StringName] = []
	for id: StringName in catalog.ids():
		if catalog.world(id) != world or (not category.is_empty() and catalog.category(id) != category):
			continue
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(catalog.entry(a).get("order", 0)) < int(catalog.entry(b).get("order", 0)))
	return ids


## [aprendidos, total] del mundo `world`.
static func world_progress(world: int) -> Vector2i:
	var ids: Array[StringName] = album_ids(world)
	var learned: int = 0
	for id: StringName in ids:
		if GameState.is_help_learned(id):
			learned += 1
	return Vector2i(learned, ids.size())


## [aprendidos, total] de todos los mundos visitados (no adelanta cuantos
## tipos tienen los demas).
static func global_progress() -> Vector2i:
	var out := Vector2i.ZERO
	for world: int in range(1, world_count() + 1):
		if is_world_visited(world):
			out += world_progress(world)
	return out


## Recuerdos visibles del mundo `world` en el acceso `lap` (por defecto, el
## actual), en orden: primero las capas de jefe alcanzadas, luego los mensajes
## alcanzados. Cada uno: {id, memory: true, kind, obtained, read}.
static func memory_entries(world: int, lap: int = -1) -> Array[Dictionary]:
	var current: int = GameState.lap if lap < 0 else lap
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var out: Array[Dictionary] = []
	for memory_kind: String in [MemoryCatalog.KIND_BOSS, MemoryCatalog.KIND_SECRET]:
		for id: StringName in catalog.ids_of(world, memory_kind):
			if catalog.is_reached(id, current):
				out.append({"id": id, "memory": true, "kind": memory_kind,
					"obtained": GameState.has_memory(id), "read": GameState.is_memory_read(id)})
	return out


## [obtenidos, visibles] de los recuerdos del mundo `world` (solo lo visible).
static func memory_progress(world: int, lap: int = -1) -> Vector2i:
	var entries: Array[Dictionary] = memory_entries(world, lap)
	var obtained: int = 0
	for e: Dictionary in entries:
		if bool(e["obtained"]):
			obtained += 1
	return Vector2i(obtained, entries.size())


func _ready() -> void:
	layer = int(_cfg.get("layer", 21))
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if _open:
		_open_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if not _open or _open_time < float(_cfg.get("input_delay_s", 0.15)) or event.is_echo():
		return
	if event.is_action_pressed(&"move_up"):
		move(0, -1)
	elif event.is_action_pressed(&"move_down"):
		move(0, 1)
	elif event.is_action_pressed(&"move_left"):
		move(-1, 0)
	elif event.is_action_pressed(&"move_right"):
		move(1, 0)
	elif event.is_action_pressed(StringName(String(_cfg.get("confirm_action", "pulse")))):
		confirm()
	elif event.is_action_pressed(StringName(String(_cfg.get("cancel_action", "jump")))):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


# --- API ---

## Abre en la vista de carpetas, con la del mundo mas alto visitado elegida.
func open() -> void:
	_open = true
	_open_time = 0.0
	_mode = Mode.FOLDERS
	_focus = Focus.GRID
	_selected = 0
	_tab = 0
	_folder_selected = 0
	for world: int in range(1, world_count() + 1):
		if is_world_visited(world):
			_folder_selected = world - 1
	_set_message("")
	visible = true
	refresh()
	_hints.notify_opened("NotasAlbum")


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func get_mode() -> Mode:
	return _mode


func get_focus() -> Focus:
	return _focus


## Mundo de la carpeta abierta (o elegida en la vista de carpetas).
func get_world() -> int:
	return _world if _mode != Mode.FOLDERS else _folder_selected + 1


## Indice (0..) de la carpeta elegida en la vista de carpetas.
func get_selected_folder() -> int:
	return _folder_selected


func select_folder(index: int) -> void:
	_folder_selected = clampi(index, 0, world_count() - 1)
	refresh()


## Abre la carpeta del mundo `world`. Falso si el mundo no esta visitado.
func open_folder(world: int) -> bool:
	if world < 1 or world > world_count() or not is_world_visited(world):
		_set_message(String(_cfg.get("texts", {}).get("message_folder_locked", "")))
		return false
	_folder_selected = world - 1
	_world = world
	_mode = Mode.GRID
	_focus = Focus.GRID
	_tab = 0
	_selected = 0
	_set_message("")
	refresh()
	return true


## Texto de cada carpeta: [nombre del mundo o «???», contador o ""].
func get_folder_texts(index: int) -> PackedStringArray:
	if index < 0 or index >= _folders.size():
		return PackedStringArray()
	var out := PackedStringArray()
	for key: String in ["Name", "Count"]:
		out.append((_folders[index].get_node(NodePath(key)) as Label).text)
	return out


## La carpeta `index` sale cerrada con candado (mundo sin alcanzar).
func is_folder_locked(index: int) -> bool:
	return not is_world_visited(index + 1)


func get_folder_icon(index: int) -> Texture2D:
	if index < 0 or index >= _folders.size():
		return null
	return (_folders[index].get_node(^"Icon") as TextureRect).texture


## Miniatura del mundo sobre la carpeta `index` (null si no se ve).
func get_folder_miniature(index: int) -> Texture2D:
	if index < 0 or index >= _folders.size():
		return null
	var mini := _folders[index].get_node(^"Miniature") as TextureRect
	return mini.texture if mini.visible else null


## Etiqueta del nombre de la carpeta `index` (pruebas: cabe en una linea).
func get_folder_name_label(index: int) -> Label:
	if index < 0 or index >= _folders.size():
		return null
	return _folders[index].get_node(^"Name") as Label


## Categoria de la pestana actual (enemy u object).
func get_tab() -> String:
	return String(_tabs()[_tab].get("category", "object"))


## Cambia a la pestana de la categoria `category` de la carpeta abierta (si
## esta en la vista de carpetas, abre la del mundo elegido). Falso si no existe.
func set_tab(category: String) -> bool:
	if _mode == Mode.FOLDERS and not open_folder(_folder_selected + 1):
		return false
	for i: int in _tabs().size():
		if String(_tabs()[i].get("category", "")) == category:
			_tab = i
			_selected = 0
			_focus = Focus.GRID
			_mode = Mode.GRID
			refresh()
			return true
	return false


## Fichas de la pestana de la carpeta abierta: {id, learned}.
func get_entries() -> Array[Dictionary]:
	return _entries


func get_selected_index() -> int:
	return _selected


func select_cell(index: int) -> void:
	_focus = Focus.GRID
	_selected = clampi(index, 0, maxi(_entries.size() - 1, 0))
	refresh()


## Pasa el retardo de entrada (pruebas).
func skip_input_delay() -> void:
	_open_time = float(_cfg.get("input_delay_s", 0.15))


## Texto del contador («Fichas: 3/12»: global en las carpetas, de la pestana
## dentro de una carpeta).
func get_counter_text() -> String:
	return _labels[&"counter"].text


func get_title_text() -> String:
	return _labels[&"title"].text


## Miniatura junto al titulo de la carpeta abierta (null si no se ve).
func get_title_icon() -> Texture2D:
	return _title_icon.texture if _title_icon != null and _title_icon.visible else null


## Texto de cada celda visible: el nombre si esta aprendida, «???» si no.
func get_cell_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in _entries:
		out.append(_cell_text(e))
	return out


## Texto de las filas visibles de la pestana Recuerdos (cabeceras incluidas).
func get_memory_rows() -> PackedStringArray:
	var out := PackedStringArray()
	if _mode == Mode.GRID and _is_memory_tab():
		for row: Dictionary in _rows:
			out.append(String(row["text"]))
	return out


## La celda `index` muestra la silueta (tipo no aprendido).
func is_cell_silhouette(index: int) -> bool:
	return index < _entries.size() and not bool(_entries[index].get("learned", false))


## Textura de la ficha de la celda `index` (silueta si no esta aprendida).
func get_cell_texture(index: int) -> Texture2D:
	if index >= _cells.size():
		return null
	return (_cells[index].get_node(^"Card") as TextureRect).texture


## Todo el texto visible ahora (comprueba que no se filtran nombres).
func get_visible_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for label: Label in _all_labels():
		if label.is_visible_in_tree() and not label.text.is_empty():
			out.append(label.text)
	return out


func get_card_title() -> String:
	return _labels[&"card_title"].text if _mode == Mode.CARD else ""


func get_card_text() -> String:
	return _body_label.text if _mode == Mode.CARD else ""


## Ilustracion de la ficha abierta (null sin ficha de recuerdo o sin ilustracion).
func get_card_art() -> Texture2D:
	return _memory_art.texture if _mode == Mode.CARD and _memory_art.visible else null


## Texto plano del pie de teclas.
func get_help() -> String:
	return _hints.get_text()


func get_hints() -> MenuHints:
	return _hints


func get_message() -> String:
	return _labels[&"message"].text


func get_panel_rect() -> Rect2:
	return Rect2(_panel.position * _frame.scale, _panel.size * _frame.scale)


## Mueve la seleccion (dx: izquierda/derecha; dy: arriba/abajo).
func move(dx: int, dy: int) -> void:
	if not _open:
		return
	_set_message("")
	match _mode:
		Mode.CARD:
			return
		Mode.FOLDERS:
			_folder_selected = _grid_move(_folder_selected, world_count(), _folder_columns(), dx, dy)
			refresh()
			return
	var cols: int = _columns()
	match _focus:
		Focus.TABS:
			if dx != 0:
				_tab = posmod(_tab + dx, _tabs().size())
				_selected = 0
			elif dy > 0 and not _entries.is_empty():
				_focus = Focus.GRID
		Focus.GRID:
			if _is_memory_tab():
				if dy < 0 and _selected == 0:
					_focus = Focus.TABS
				elif dy != 0:
					_selected = clampi(_selected + dy, 0, maxi(_entries.size() - 1, 0))
			elif dy < 0 and _selected < cols:
				_focus = Focus.TABS
			elif dy > 0 and _selected + cols >= _entries.size() and _selected / cols < (_entries.size() - 1) / cols:
				_selected = _entries.size() - 1
			else:
				_selected = _grid_move(_selected, _entries.size(), cols, dx, dy)
	refresh()


## Pulso: abre la carpeta elegida, cambia de pestana a la rejilla o abre la
## ficha.
func confirm() -> void:
	if not _open:
		return
	var texts: Dictionary = _cfg.get("texts", {})
	match _mode:
		Mode.CARD:
			return
		Mode.FOLDERS:
			open_folder(_folder_selected + 1)
			return
	match _focus:
		Focus.TABS:
			if not _entries.is_empty():
				_focus = Focus.GRID
			refresh()
		Focus.GRID:
			if _entries.is_empty():
				return
			if bool(_entries[_selected].get("memory", false)):
				if bool(_entries[_selected].get("obtained", false)):
					_mode = Mode.CARD
					GameState.mark_memory_read(_entries[_selected]["id"])
					refresh()
				else:
					_set_message(String(texts.get("message_memory_missing", "")))
				return
			if bool(_entries[_selected].get("learned", false)):
				_mode = Mode.CARD
				refresh()
			else:
				_set_message(String(texts.get("message_not_learned", "")))


## Salto: ficha -> carpeta -> carpetas -> cerrar.
func cancel() -> void:
	if not _open:
		return
	_set_message("")
	match _mode:
		Mode.CARD:
			_mode = Mode.GRID
			refresh()
		Mode.GRID:
			_mode = Mode.FOLDERS
			_folder_selected = _world - 1
			refresh()
		_:
			close_requested.emit()


## Vuelve a escribir todo con el estado actual.
func refresh() -> void:
	if _frame == null:
		return
	var texts: Dictionary = _cfg.get("texts", {})
	var colors: Dictionary = _cfg.get("colors", {})
	var folders_mode: bool = _mode == Mode.FOLDERS
	var card_mode: bool = _mode == Mode.CARD
	_entries.clear()
	var memory_tab: bool = not folders_mode and _is_memory_tab()
	if memory_tab:
		_entries = memory_entries(_world)
	elif not folders_mode:
		for id: StringName in album_ids(_world, get_tab()):
			_entries.append({"id": id, "learned": GameState.is_help_learned(id)})
	_selected = clampi(_selected, 0, maxi(_entries.size() - 1, 0))
	if folders_mode:
		_labels[&"title"].text = String(texts.get("title", ""))
		var total: Vector2i = global_progress()
		_labels[&"counter"].text = String(texts.get("counter", "%d/%d")) % [total.x, total.y]
	else:
		# Solo el nombre del mundo (2026-10-18; el panel de subniveles sigue con
		# HubWorlds.world_title, «Mundo 1 - Notificaciones»).
		_labels[&"title"].text = world_name(_world)
		var learned: int = 0
		for e: Dictionary in _entries:
			if bool(e.get("learned", false)) or bool(e.get("obtained", false)):
				learned += 1
		var counter_key: String = "counter_memories" if memory_tab else "counter"
		_labels[&"counter"].text = String(texts.get(counter_key, "%d/%d")) % [learned, _entries.size()]
	for i: int in _folders.size():
		_folders[i].visible = folders_mode
		if folders_mode:
			_fill_folder(_folders[i], i + 1, i == _folder_selected)
	for i: int in _tab_labels.size():
		_tab_labels[i].visible = not folders_mode
		var on: bool = i == _tab
		var tab_name: String = String(_tabs()[i].get("text", ""))
		_tab_labels[i].text = (String(texts.get("tab_selected", "[%s]")) % tab_name) if on else tab_name
		var role: String = String(colors.get("tab", "texto_tenue"))
		if on:
			role = String(colors.get("tab_focus" if _focus == Focus.TABS else "tab_selected", "acento_cian"))
		_set_color(_tab_labels[i], role)
	var grid_visible: bool = _mode == Mode.GRID
	_fill_memory_rows(grid_visible and memory_tab)
	for i: int in _cells.size():
		var cell: Control = _cells[i]
		cell.visible = grid_visible and not memory_tab and i < _entries.size()
		if cell.visible:
			_fill_cell(cell, _entries[i], i == _selected and _focus == Focus.GRID)
	var sel_name: String = ""
	if folders_mode:
		sel_name = ""
	elif _entries.is_empty():
		sel_name = String(texts.get("empty", ""))
	elif memory_tab:
		sel_name = ""
	elif _focus == Focus.GRID:
		sel_name = _cell_text(_entries[_selected])
	_labels[&"name"].text = sel_name
	_labels[&"name"].visible = grid_visible and not (memory_tab and not _entries.is_empty())
	_card_big.visible = card_mode and not memory_tab
	_memory_art.visible = false
	_body_label.visible = card_mode
	_labels[&"card_title"].visible = card_mode
	if card_mode and memory_tab and not _entries.is_empty():
		_fill_memory_card(_entries[_selected]["id"])
	elif card_mode and not _entries.is_empty():
		var id: StringName = _entries[_selected]["id"]
		_labels[&"card_title"].text = HelpCatalog.shared().title(id)
		_card_big.texture = _card_texture(id, false)
		var width: float = float(_cfg.get("card_text_width_px", 200))
		_body_label.text = "\n".join(EcoTextBox.wrap_text(HelpCatalog.shared().text(id), _font,
			int(_cfg.get("font_size", 12)), width))
	_hints.show_set("album_card" if card_mode else ("album_folders" if folders_mode else "album_grid"))
	_layout()


# --- Interno ---

func _tabs() -> Array:
	var tabs: Variant = _cfg.get("tabs", [])
	return tabs if tabs is Array and not (tabs as Array).is_empty() else [{"category": "object", "text": ""}]


func _is_memory_tab() -> bool:
	return get_tab() == CATEGORY_MEMORY


## Filas de la pestana Recuerdos: cabecera «Jefe», capas; cabecera «Mensajes»,
## mensajes (una seccion sin filas no sale).
func _fill_memory_rows(active: bool) -> void:
	var texts: Dictionary = _cfg.get("texts", {})
	var colors: Dictionary = _cfg.get("colors", {})
	_rows.clear()
	if active:
		var last_kind: String = ""
		for i: int in _entries.size():
			var e: Dictionary = _entries[i]
			var memory_kind: String = String(e["kind"])
			if memory_kind != last_kind:
				last_kind = memory_kind
				var header: String = "section_boss" if memory_kind == MemoryCatalog.KIND_BOSS else "section_messages"
				_rows.append({"text": String(texts.get(header, "")), "role": String(colors.get("section", "texto_tenue")),
					"entry": -1})
			var role: String = String(colors.get("memory_row", "texto_claro"))
			if not bool(e["obtained"]):
				role = String(colors.get("unknown", "texto_tenue"))
			elif not bool(e["read"]):
				role = String(colors.get("memory_new", "ambar"))
			if i == _selected and _focus == Focus.GRID:
				role = String(colors.get("memory_row_selected", "acento_cian"))
			_rows.append({"text": _cell_text(e), "role": role, "entry": i})
	for i: int in _memory_rows.size():
		var label: Label = _memory_rows[i]
		label.visible = i < _rows.size()
		if label.visible:
			label.text = String(_rows[i]["text"])
			_set_color(label, String(_rows[i]["role"]))
		else:
			label.text = ""


## Ficha de un recuerdo obtenido: titulo, capa o remitente y asunto, y el texto.
func _fill_memory_card(id: StringName) -> void:
	var texts: Dictionary = _cfg.get("texts", {})
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	_labels[&"card_title"].text = catalog.title(id)
	_memory_art.texture = memory_art(id)
	_memory_art.visible = _memory_art.texture != null
	var paragraphs := PackedStringArray()
	if catalog.is_boss(id):
		paragraphs.append(String(texts.get("card_layer", "%s")) % HubWorlds.access_name(catalog.layer(id)))
	else:
		paragraphs.append(String(texts.get("card_sender", "%s")) % catalog.sender(id))
		paragraphs.append(String(texts.get("card_subject", "%s")) % catalog.subject(id))
	paragraphs.append("")
	paragraphs.append_array(catalog.text(id).split("\n"))
	var width: float = float(_cfg.get("width_px", 300)) - float(_cfg.get("padding_px", 10)) * 2.0
	var lines := PackedStringArray()
	for paragraph: String in paragraphs:
		if paragraph.is_empty():
			lines.append("")
			continue
		lines.append_array(EcoTextBox.wrap_text(GameState.apply_nickname(paragraph), _font,
			int(_cfg.get("font_size", 12)), width))
	_body_label.text = "\n".join(lines)


func _columns() -> int:
	return maxi(1, int(_cfg.get("columns", 6)))


func _folder_columns() -> int:
	return maxi(1, int(_cfg.get("folder_columns", 2)))


## Mueve `index` en una rejilla de `count` elementos y `cols` columnas.
static func _grid_move(index: int, count: int, cols: int, dx: int, dy: int) -> int:
	if count <= 0:
		return 0
	if dx != 0:
		var row_start: int = (index / cols) * cols
		return clampi(index + dx, row_start, mini(row_start + cols, count) - 1)
	if dy < 0 and index >= cols:
		return index - cols
	if dy > 0 and index + cols < count:
		return index + cols
	return index


func _cell_text(e: Dictionary) -> String:
	if bool(e.get("memory", false)):
		return _memory_row_text(e)
	if bool(e.get("learned", false)):
		return HelpCatalog.shared().title(e["id"])
	return String(_cfg.get("texts", {}).get("unknown", "???"))


## Ilustracion de la ficha del recuerdo `id` (paso 7 de docs/propuesta-recuerdos.md,
## §11.3): solo los recuerdos de jefe cuya capa tiene ruta en memory_art de la
## seccion album de data/hub.json (Caché, la imagen borrosa; Kernel, la nitida;
## tools/gen_memory_art.py). Raíz y los mensajes: null (solo texto).
static func memory_art(id: StringName) -> Texture2D:
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	if not catalog.is_boss(id):
		return null
	var patterns: Variant = HubData.section("album").get("memory_art", {})
	if not patterns is Dictionary:
		return null
	var pattern: String = String((patterns as Dictionary).get(str(catalog.layer(id)), ""))
	if pattern.is_empty():
		return null
	var path: String = pattern % catalog.world(id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Fila de un recuerdo: «Caché: <titulo>» (jefe) o «<remitente>: <asunto>»
## (mensaje); sin obtener, «Caché: ???» o «???» (sin remitente); sin leer, «Nuevo».
func _memory_row_text(e: Dictionary) -> String:
	var texts: Dictionary = _cfg.get("texts", {})
	var unknown: String = String(texts.get("unknown", "???"))
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var id: StringName = e["id"]
	var obtained: bool = bool(e.get("obtained", false))
	var row: String
	if catalog.is_boss(id):
		row = String(texts.get("layer_row", "%s: %s")) % [HubWorlds.access_name(catalog.layer(id)),
			catalog.title(id) if obtained else unknown]
	elif obtained:
		row = String(texts.get("message_row", "%s: %s")) % [catalog.sender(id), catalog.subject(id)]
	else:
		row = unknown
	if obtained and not bool(e.get("read", false)):
		row = String(texts.get("row_new", "%s")) % row
	return row


func _card_texture(id: StringName, silhouette: bool) -> Texture2D:
	var key: String = "silhouette_pattern" if silhouette else "card_pattern"
	var path: String = String(_cfg.get(key, "")) % String(id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _fill_cell(cell: Control, e: Dictionary, selected: bool) -> void:
	var learned: bool = bool(e.get("learned", false))
	(cell.get_node(^"Frame") as TextureRect).texture = load(String(
		_cfg.get("cell_selected" if selected else "cell", ""))) as Texture2D
	(cell.get_node(^"Card") as TextureRect).texture = _card_texture(e["id"], not learned)
	(cell.get_node(^"Unknown") as Label).visible = not learned


func _fill_folder(folder: Control, world: int, selected: bool) -> void:
	var texts: Dictionary = _cfg.get("texts", {})
	var colors: Dictionary = _cfg.get("colors", {})
	var visited: bool = is_world_visited(world)
	(folder.get_node(^"Frame") as NinePatchRect).texture = load(String(
		_cfg.get("cell_selected" if selected else "cell", ""))) as Texture2D
	var icon_key: String = "folder_locked"
	if visited:
		icon_key = "folder_open" if selected else "folder_closed"
	(folder.get_node(^"Icon") as TextureRect).texture = load(String(_cfg.get(icon_key, ""))) as Texture2D
	var mini := folder.get_node(^"Miniature") as TextureRect
	mini.texture = world_miniature(world) if visited else null
	mini.visible = mini.texture != null
	var name_label := folder.get_node(^"Name") as Label
	var count := folder.get_node(^"Count") as Label
	if visited:
		var progress: Vector2i = world_progress(world)
		name_label.text = world_name(world)
		count.text = String(texts.get("folder_counter", "%d/%d")) % [progress.x, progress.y]
	else:
		name_label.text = String(texts.get("unknown", "???"))
		count.text = ""
	var name_role: String = "unknown"
	if visited:
		name_role = "folder_name_selected" if selected else "folder_name"
	_set_color(name_label, String(colors.get(name_role, "texto_claro")))
	_set_color(count, String(colors.get("counter", "texto_tenue")))


func _set_message(text: String) -> void:
	_labels[&"message"].text = text
	_layout()


func _all_labels() -> Array[Label]:
	var out: Array[Label] = []
	for key: StringName in _labels:
		out.append(_labels[key])
	out.append_array(_tab_labels)
	out.append(_body_label)
	for cell: Control in _cells:
		out.append(cell.get_node(^"Unknown") as Label)
	for folder: Control in _folders:
		for key: String in ["Name", "Count"]:
			out.append(folder.get_node(NodePath(key)) as Label)
	out.append_array(_memory_rows)
	return out


func _new_label(parent: Node, node_name: String, role: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", int(_cfg.get("font_size", 12)))
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_constant_override(&"line_spacing", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"key_color", _key_color)
	material.set_shader_parameter(&"target_color", HubData.color(role))
	label.material = material
	parent.add_child(label)
	return label


func _set_color(label: Label, role: String) -> void:
	(label.material as ShaderMaterial).set_shader_parameter(&"target_color", HubData.color(role))


func _build() -> void:
	var colors: Dictionary = _cfg.get("colors", {})
	_font = load(String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	_shader = load(String(_cfg.get("key_swap_shader", "res://assets/shaders/hud_key_swap.gdshader"))) as Shader
	_key_color = Color.html(String(_cfg.get("font_key_color", "#f2f4f8")))
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.scale = Vector2.ONE * maxi(1, int(_cfg.get("pixel_scale", 2)))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_panel = NinePatchRect.new()
	_panel.name = "Panel"
	_panel.texture = load(String(_cfg.get("texture", "res://assets/sprites/ui/eco_text_panel.png"))) as Texture2D
	var margin: int = int(_cfg.get("margin_px", 3))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, margin)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_panel)
	for key: String in ["title", "counter", "name", "message", "card_title"]:
		_labels[StringName(key)] = _new_label(_panel, key.capitalize().replace(" ", ""), String(colors.get(key, "texto_claro")))
	_hints = MenuHints.new()
	_hints.setup(_font, int(_cfg.get("font_size", 12)), _shader, _key_color, HubPanel.hint_colors())
	_panel.add_child(_hints)
	_hints.row_changed.connect(_layout)
	_title_icon = TextureRect.new()
	_title_icon.name = "TitleIcon"
	_title_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_icon.visible = false
	_panel.add_child(_title_icon)
	for i: int in _tabs().size():
		_tab_labels.append(_new_label(_panel, "Tab%d" % i, String(colors.get("tab", "texto_tenue"))))
	_build_folders()
	var max_cells: int = 0
	for world: int in range(1, world_count() + 1):
		for tab: Variant in _tabs():
			max_cells = maxi(max_cells, album_ids(world, String((tab as Dictionary).get("category", ""))).size())
	var cell_px: int = int(_cfg.get("cell_px", 40))
	var card_scale: float = 1.0 / float(_frame.scale.x)
	for i: int in max_cells:
		var cell := Control.new()
		cell.name = "Cell%d" % i
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size = Vector2(cell_px, cell_px)
		_panel.add_child(cell)
		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(frame)
		var card := TextureRect.new()
		card.name = "Card"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.scale = Vector2.ONE * card_scale
		var card_art: float = float(_cfg.get("card_px", 64)) * card_scale
		card.position = Vector2.ONE * floorf((cell_px - card_art) * 0.5)
		cell.add_child(card)
		var unknown: Label = _new_label(cell, "Unknown", String(colors.get("unknown", "texto_tenue")))
		unknown.text = String(_cfg.get("texts", {}).get("unknown", "???"))
		unknown.size = Vector2(cell_px, cell_px)
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cells.append(cell)
	_card_big = TextureRect.new()
	_card_big.name = "CardBig"
	_card_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_big.visible = false
	_panel.add_child(_card_big)
	_memory_art = TextureRect.new()
	_memory_art.name = "MemoryArt"
	_memory_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_memory_art.visible = false
	_panel.add_child(_memory_art)
	_body_label = _new_label(_panel, "CardText", String(colors.get("card_text", "texto_claro")))
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.visible = false
	# Filas de la pestana Recuerdos: las del mundo con mas (dos cabeceras + recuerdos).
	var max_rows: int = 0
	for world: int in range(1, world_count() + 1):
		max_rows = maxi(max_rows, MemoryCatalog.shared().ids_of(world).size() + 2)
	for i: int in max_rows:
		var row: Label = _new_label(_panel, "MemoryRow%d" % i, String(colors.get("memory_row", "texto_claro")))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.visible = false
		_memory_rows.append(row)


## Carpeta: marco (album_cell estirado), icono de carpeta con la miniatura del
## mundo encima (abajo a la derecha) y dos lineas: nombre y contador.
func _build_folders() -> void:
	var size: Array = _cfg.get("folder_card_px", [136, 48])
	var icon_px: float = float(_cfg.get("folder_icon_px", 32))
	var mini_px: float = float(_cfg.get("folder_miniature_px", 16))
	var pad: float = float(_cfg.get("folder_padding_px", 6))
	var line_h: float = ceilf(_font.get_height(int(_cfg.get("font_size", 12))))
	var w: float = float(size[0])
	var h: float = float(size[1])
	var frame_margin: int = int(_cfg.get("folder_frame_margin_px", 5))
	for i: int in world_count():
		var folder := Control.new()
		folder.name = "Folder%d" % (i + 1)
		folder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		folder.size = Vector2(w, h)
		_panel.add_child(folder)
		var frame := NinePatchRect.new()
		frame.name = "Frame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			frame.set_patch_margin(side, frame_margin)
		frame.size = Vector2(w, h)
		folder.add_child(frame)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(pad, floorf((h - icon_px) * 0.5))
		folder.add_child(icon)
		var mini := TextureRect.new()
		mini.name = "Miniature"
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.position = icon.position + Vector2(icon_px - mini_px, icon_px - mini_px)
		mini.visible = false
		folder.add_child(mini)
		var tx: float = pad * 2.0 + icon_px
		var top: float = floorf((h - line_h * 2.0) * 0.5)
		for j: int in 2:
			var key: String = ["Name", "Count"][j]
			var label: Label = _new_label(folder, key, "texto_claro")
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.position = Vector2(tx, top + line_h * j)
			label.size = Vector2(w - tx - pad, line_h)
		_folders.append(folder)


## Maqueta en px de arte: titulo, contador, carpetas; o titulo, pestanas,
## contador, rejilla (o ficha) y nombre de la elegida; mensaje y ayuda.
func _layout() -> void:
	if _frame == null or not is_inside_tree():
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale
	_frame.size = screen
	var fs: int = int(_cfg.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(fs))
	var pad: float = float(_cfg.get("padding_px", 10))
	var gap: float = float(_cfg.get("line_gap_px", 4))
	var width: float = maxf(float(_cfg.get("width_px", 300)), _hints.get_row_width() + float(_cfg.get("padding_px", 10)) * 2.0)
	var inner: float = width - pad * 2.0
	var y: float = pad
	# Carpeta abierta: la miniatura del mundo (si la tiene) a la izquierda del titulo.
	var mini: Texture2D = world_miniature(_world) if _mode != Mode.FOLDERS else null
	_title_icon.texture = mini
	_title_icon.visible = mini != null
	if mini != null:
		# Icono y nombre centrados juntos (el titulo esta centrado).
		var mini_size: Vector2 = mini.get_size()
		var text_w: float = ceilf(_font.get_string_size(_labels[&"title"].text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var x0: float = pad + floorf((inner - (mini_size.x + gap + text_w)) * 0.5)
		_title_icon.size = mini_size
		_title_icon.position = Vector2(x0, y + floorf((line_h - mini_size.y) * 0.5))
		_place(_labels[&"title"], x0 + mini_size.x + gap, y, text_w, line_h, gap)
		y += line_h + gap
	else:
		y = _place(_labels[&"title"], pad, y, inner, line_h, gap)
	y += gap
	if _mode == Mode.FOLDERS:
		y = _place(_labels[&"counter"], pad, y, inner, line_h, gap)
		y += gap
		var size: Array = _cfg.get("folder_card_px", [136, 48])
		var fgap: float = float(_cfg.get("folder_gap_px", 8))
		var cols: int = _folder_columns()
		var grid_w: float = cols * float(size[0]) + (cols - 1) * fgap
		var x0: float = floorf((width - grid_w) * 0.5)
		var rows: int = ceili(float(_folders.size()) / cols)
		for i: int in _folders.size():
			_folders[i].position = Vector2(x0 + (i % cols) * (float(size[0]) + fgap),
				y + (i / cols) * (float(size[1]) + fgap))
		y += rows * float(size[1]) + (rows - 1) * fgap + gap * 2.0
	else:
		# Pestanas repartidas a lo ancho.
		var n: int = _tab_labels.size()
		for i: int in n:
			_tab_labels[i].position = Vector2(pad + inner * i / n, y)
			_tab_labels[i].size = Vector2(inner / n, line_h)
		y += line_h + gap
		y = _place(_labels[&"counter"], pad, y, inner, line_h, gap)
		y += gap
	if _mode == Mode.CARD and _is_memory_tab():
		# Ficha de un recuerdo: la ilustracion (capas Caché y Kernel de jefe; §8.3)
		# centrada arriba, a x1 de los pixeles del panel; despues, el texto a todo el ancho.
		if _memory_art.visible:
			var art_size: Vector2 = _memory_art.texture.get_size()
			_memory_art.size = art_size
			_memory_art.position = Vector2(floorf((width - art_size.x) * 0.5), y)
			y += art_size.y + gap * 2.0
		_labels[&"card_title"].position = Vector2(pad, y)
		_labels[&"card_title"].size = Vector2(inner, line_h)
		_labels[&"card_title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_body_label.position = Vector2(pad, y + line_h + gap)
		var body_lines: int = maxi(1, _body_label.text.count("\n") + 1)
		_body_label.size = Vector2(inner, line_h * body_lines)
		y += line_h * (body_lines + 1) + gap * 2.0
	elif _mode == Mode.GRID and _is_memory_tab():
		var row_h: float = maxf(float(_cfg.get("memory_row_px", 16)), line_h)
		var indent: float = float(_cfg.get("cell_gap_px", 4)) * 2.0
		for i: int in _memory_rows.size():
			if i >= _rows.size():
				continue
			var header: bool = int(_rows[i]["entry"]) < 0
			var x: float = pad if header else pad + indent
			_memory_rows[i].position = Vector2(x, y + i * row_h)
			_memory_rows[i].size = Vector2(width - x - pad, line_h)
		y += maxi(_rows.size(), 1) * row_h + gap
		if _entries.is_empty():
			y = _place(_labels[&"name"], pad, y, inner, line_h, gap)
	elif _mode == Mode.CARD:
		# La ficha (64 px de pantalla) a x2: 128 px de pantalla.
		var card_px: float = float(_cfg.get("card_px", 64))
		var big_scale: float = 2.0 / _frame.scale.x
		var card_art: float = card_px * big_scale
		_card_big.position = Vector2(pad, y)
		_card_big.size = Vector2(card_px, card_px)
		_card_big.scale = Vector2.ONE * big_scale
		var tx: float = pad + card_art + pad
		_labels[&"card_title"].position = Vector2(tx, y)
		_labels[&"card_title"].size = Vector2(width - tx - pad, line_h)
		_labels[&"card_title"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_body_label.position = Vector2(tx, y + line_h + gap)
		var lines: int = maxi(1, _body_label.text.count("\n") + 1)
		_body_label.size = Vector2(width - tx - pad, line_h * lines)
		y += maxf(card_art, line_h * (lines + 1) + gap) + gap
	elif _mode == Mode.GRID:
		var cols: int = _columns()
		var cell_px: float = float(_cfg.get("cell_px", 40))
		var cgap: float = float(_cfg.get("cell_gap_px", 4))
		var grid_w: float = cols * cell_px + (cols - 1) * cgap
		var x0: float = floorf((width - grid_w) * 0.5)
		var rows: int = maxi(1, ceili(float(_entries.size()) / cols))
		for i: int in _cells.size():
			_cells[i].position = Vector2(x0 + (i % cols) * (cell_px + cgap), y + (i / cols) * (cell_px + cgap))
		y += rows * cell_px + (rows - 1) * cgap + gap * 2.0
		y = _place(_labels[&"name"], pad, y, inner, line_h, gap)
	if not _labels[&"message"].text.is_empty():
		y = _place(_labels[&"message"], pad, y, inner, line_h, gap)
		_labels[&"message"].visible = true
	else:
		_labels[&"message"].visible = false
	y += gap
	_hints.position = Vector2(floorf((width - _hints.get_row_width()) * 0.5), y)
	y += _hints.get_row_height() + gap
	var height: float = y - gap + pad
	_panel.size = Vector2(width, height)
	var top: float = float(_cfg.get("top_px", 16))
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(minf(top, maxf(screen.y - height, 0.0))))


## Coloca `label` en la fila `y` (ancho `inner`) y devuelve la fila siguiente.
func _place(label: Label, x: float, y: float, inner: float, line_h: float, gap: float) -> float:
	label.position = Vector2(x, y)
	label.size = Vector2(inner, line_h)
	return y + line_h + gap
