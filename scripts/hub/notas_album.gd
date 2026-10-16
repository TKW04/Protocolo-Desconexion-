## Album de Notas (docs/propuesta-asistentes-y-vidas.md §3.5, paso 9 de §10):
## una ficha por TIPO de ayuda con Q (data/help.json: categoria, orden y textos;
## no se duplican aqui). Lo abre NotasStation desde su panel («Álbum»). Aspecto,
## textos y colores en la seccion album de data/hub.json.
## - Dos pestanas (tabs: Enemigos y Objetos) con su contador «Fichas: n/N».
## - Rejilla de celdas (marco album_cell de tools/gen_hub_objects.py; la elegida,
##   album_cell_selected). Tipo aprendido (GameState.learned_help): su ficha
##   (tools/gen_album_cards.py). No aprendido: la silueta con «???»; ni el
##   nombre ni el texto se muestran en ningun sitio.
## - Solo salen los tipos cuyo first_level es de un mundo ya desbloqueado
##   (HubWorlds), para no adelantar nada.
## - Controles (Input Map, como los paneles del hub): arriba/abajo/izquierda/
##   derecha eligen (fila de pestanas, rejilla y «Olvidar ayudas»), el pulso
##   abre la ficha (dibujo x2, nombre y texto de Eco, con {apodo}) o confirma, el
##   salto vuelve (ficha -> rejilla -> cerrar: close_requested).
## - «Olvidar ayudas» pide confirmacion y llama a GameState.forget_help() (vuelven
##   las Q y las siluetas; marca «sin guardar»).
class_name NotasAlbum
extends CanvasLayer

enum Mode { GRID, CARD, CONFIRM_FORGET }
enum Focus { TABS, GRID, FORGET }

## El jugador pide cerrar el album.
signal close_requested

var _cfg: Dictionary = HubData.section("album")
var _font: Font
var _shader: Shader
var _key_color: Color
var _frame: Control
var _panel: NinePatchRect
var _labels: Dictionary[StringName, Label] = {}
var _tab_labels: Array[Label] = []
var _cells: Array[Control] = []
var _card_big: TextureRect
var _body_label: Label
var _open: bool = false
var _open_time: float = 0.0
var _mode: Mode = Mode.GRID
var _focus: Focus = Focus.GRID
var _tab: int = 0
var _selected: int = 0
var _confirm_yes: bool = false
var _entries: Array[Dictionary] = []


## Tipos del album de la categoria `category` (enemy u object) en su orden,
## solo de mundos desbloqueados.
static func album_ids(category: String) -> Array[StringName]:
	var catalog: HelpCatalog = HelpCatalog.shared()
	var ids: Array[StringName] = []
	for id: StringName in catalog.ids():
		if catalog.category(id) != category:
			continue
		var first_level := StringName(String(catalog.entry(id).get("first_level", "")))
		var world: Dictionary = HubWorlds.world_of_level(first_level)
		if not world.is_empty() and not HubWorlds.is_world_unlocked(world):
			continue
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(catalog.entry(a).get("order", 0)) < int(catalog.entry(b).get("order", 0)))
	return ids


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

func open() -> void:
	_open = true
	_open_time = 0.0
	_mode = Mode.GRID
	_focus = Focus.GRID
	_selected = 0
	_tab = 0
	_set_message("")
	visible = true
	refresh()


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func get_mode() -> Mode:
	return _mode


func get_focus() -> Focus:
	return _focus


## Categoria de la pestana actual (enemy u object).
func get_tab() -> String:
	return String(_tabs()[_tab].get("category", "object"))


## Cambia a la pestana de la categoria `category`. Falso si no existe.
func set_tab(category: String) -> bool:
	for i: int in _tabs().size():
		if String(_tabs()[i].get("category", "")) == category:
			_tab = i
			_selected = 0
			_focus = Focus.GRID
			_mode = Mode.GRID
			refresh()
			return true
	return false


## Fichas de la pestana: {id, learned}.
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


## Texto del contador («Fichas: 3/12»).
func get_counter_text() -> String:
	return _labels[&"counter"].text


## Texto de cada celda visible: el nombre si esta aprendida, «???» si no.
func get_cell_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in _entries:
		out.append(_cell_text(e))
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
		Mode.CONFIRM_FORGET:
			if dx != 0:
				_confirm_yes = not _confirm_yes
			refresh()
			return
	var cols: int = _columns()
	match _focus:
		Focus.TABS:
			if dx != 0:
				_tab = posmod(_tab + dx, _tabs().size())
				_selected = 0
			elif dy > 0:
				_focus = Focus.GRID if not _entries.is_empty() else Focus.FORGET
		Focus.GRID:
			if dx != 0:
				var row_start: int = (_selected / cols) * cols
				_selected = clampi(_selected + dx, row_start, mini(row_start + cols, _entries.size()) - 1)
			elif dy < 0:
				if _selected < cols:
					_focus = Focus.TABS
				else:
					_selected -= cols
			elif dy > 0:
				if _selected + cols < _entries.size():
					_selected += cols
				elif _selected / cols < (_entries.size() - 1) / cols:
					_selected = _entries.size() - 1
				else:
					_focus = Focus.FORGET
		Focus.FORGET:
			if dy < 0:
				_focus = Focus.GRID if not _entries.is_empty() else Focus.TABS
	refresh()


## Pulso: abre la ficha, cambia de pestana o confirma «Olvidar ayudas».
func confirm() -> void:
	if not _open:
		return
	var texts: Dictionary = _cfg.get("texts", {})
	match _mode:
		Mode.CARD:
			return
		Mode.CONFIRM_FORGET:
			if _confirm_yes:
				GameState.forget_help()
				_mode = Mode.GRID
				_focus = Focus.FORGET
				refresh()
				_set_message(String(texts.get("message_forgotten", "")))
			else:
				_mode = Mode.GRID
				refresh()
			return
	match _focus:
		Focus.TABS:
			_focus = Focus.GRID if not _entries.is_empty() else Focus.FORGET
			refresh()
		Focus.GRID:
			if _entries.is_empty():
				return
			if bool(_entries[_selected].get("learned", false)):
				_mode = Mode.CARD
				refresh()
			else:
				_set_message(String(texts.get("message_not_learned", "")))
		Focus.FORGET:
			if GameState.learned_help.is_empty():
				_set_message(String(texts.get("message_nothing_to_forget", "")))
				return
			_mode = Mode.CONFIRM_FORGET
			_confirm_yes = false
			refresh()


## Salto: ficha -> rejilla; confirmacion -> «Olvidar ayudas»; si no, cerrar.
func cancel() -> void:
	if not _open:
		return
	_set_message("")
	match _mode:
		Mode.CARD, Mode.CONFIRM_FORGET:
			_mode = Mode.GRID
			refresh()
		_:
			close_requested.emit()


## Vuelve a escribir todo con el estado actual.
func refresh() -> void:
	if _frame == null:
		return
	var category: String = get_tab()
	_entries.clear()
	for id: StringName in album_ids(category):
		_entries.append({"id": id, "learned": GameState.is_help_learned(id)})
	_selected = clampi(_selected, 0, maxi(_entries.size() - 1, 0))
	var texts: Dictionary = _cfg.get("texts", {})
	var colors: Dictionary = _cfg.get("colors", {})
	_labels[&"title"].text = String(texts.get("title", ""))
	for i: int in _tab_labels.size():
		var on: bool = i == _tab
		var name: String = String(_tabs()[i].get("text", ""))
		_tab_labels[i].text = (String(texts.get("tab_selected", "[%s]")) % name) if on else name
		var role: String = String(colors.get("tab", "texto_tenue"))
		if on:
			role = String(colors.get("tab_focus" if _focus == Focus.TABS else "tab_selected", "acento_cian"))
		_set_color(_tab_labels[i], role)
	var learned: int = 0
	for e: Dictionary in _entries:
		if bool(e["learned"]):
			learned += 1
	_labels[&"counter"].text = String(texts.get("counter", "%d/%d")) % [learned, _entries.size()]
	var grid_visible: bool = _mode != Mode.CARD
	for i: int in _cells.size():
		var cell: Control = _cells[i]
		cell.visible = grid_visible and i < _entries.size()
		if cell.visible:
			_fill_cell(cell, _entries[i], i == _selected and _focus == Focus.GRID)
	var sel_name: String = ""
	if not _entries.is_empty() and _focus == Focus.GRID:
		sel_name = _cell_text(_entries[_selected])
	elif _entries.is_empty():
		sel_name = String(texts.get("empty", ""))
	_labels[&"name"].text = sel_name
	_labels[&"name"].visible = grid_visible
	var forget: Label = _labels[&"forget"]
	forget.visible = grid_visible or _mode == Mode.CONFIRM_FORGET
	var prefix: String = String(texts.get("selected_prefix", "– ")) if _focus == Focus.FORGET else ""
	if _mode == Mode.CONFIRM_FORGET:
		forget.text = String(texts.get("forget_confirm", "")) % [
			(String(texts.get("selected_prefix", "– ")) if _confirm_yes else "") + String(texts.get("option_yes", "")),
			(String(texts.get("selected_prefix", "– ")) if not _confirm_yes else "") + String(texts.get("option_no", ""))]
		_set_color(forget, String(colors.get("forget_selected", "acento_cian")))
	else:
		forget.text = prefix + String(texts.get("forget", ""))
		_set_color(forget, String(colors.get("forget_selected" if _focus == Focus.FORGET else "forget", "texto_tenue")))
	var card_mode: bool = _mode == Mode.CARD
	_card_big.visible = card_mode
	_body_label.visible = card_mode
	_labels[&"card_title"].visible = card_mode
	if card_mode and not _entries.is_empty():
		var id: StringName = _entries[_selected]["id"]
		_labels[&"card_title"].text = HelpCatalog.shared().title(id)
		_card_big.texture = _card_texture(id, false)
		var width: float = float(_cfg.get("card_text_width_px", 200))
		_body_label.text = "\n".join(EcoTextBox.wrap_text(HelpCatalog.shared().text(id), _font,
			int(_cfg.get("font_size", 12)), width))
	var help_key: String = "help_card" if card_mode else ("help_confirm" if _mode == Mode.CONFIRM_FORGET else "help")
	_labels[&"help"].text = String(texts.get(help_key, ""))
	_layout()


# --- Interno ---

func _tabs() -> Array:
	var tabs: Variant = _cfg.get("tabs", [])
	return tabs if tabs is Array and not (tabs as Array).is_empty() else [{"category": "object", "text": ""}]


func _columns() -> int:
	return maxi(1, int(_cfg.get("columns", 6)))


func _cell_text(e: Dictionary) -> String:
	if bool(e.get("learned", false)):
		return HelpCatalog.shared().title(e["id"])
	return String(_cfg.get("texts", {}).get("unknown", "???"))


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
	for key: String in ["title", "counter", "name", "forget", "message", "help", "card_title"]:
		_labels[StringName(key)] = _new_label(_panel, key.capitalize().replace(" ", ""), String(colors.get(key, "texto_claro")))
	for i: int in _tabs().size():
		_tab_labels.append(_new_label(_panel, "Tab%d" % i, String(colors.get("tab", "texto_tenue"))))
	var max_cells: int = 0
	for tab: Variant in _tabs():
		max_cells = maxi(max_cells, album_ids(String((tab as Dictionary).get("category", ""))).size())
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
	_body_label = _new_label(_panel, "CardText", String(colors.get("card_text", "texto_claro")))
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.visible = false


## Maqueta en px de arte: titulo, pestanas, contador, rejilla (o ficha), nombre
## de la elegida, «Olvidar ayudas», mensaje y ayuda.
func _layout() -> void:
	if _frame == null or not is_inside_tree():
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale
	_frame.size = screen
	var fs: int = int(_cfg.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(fs))
	var pad: float = float(_cfg.get("padding_px", 10))
	var gap: float = float(_cfg.get("line_gap_px", 4))
	var width: float = float(_cfg.get("width_px", 300))
	var inner: float = width - pad * 2.0
	var y: float = pad
	y = _place(_labels[&"title"], pad, y, inner, line_h, gap)
	y += gap
	# Pestanas repartidas a lo ancho.
	var n: int = _tab_labels.size()
	for i: int in n:
		_tab_labels[i].position = Vector2(pad + inner * i / n, y)
		_tab_labels[i].size = Vector2(inner / n, line_h)
	y += line_h + gap
	y = _place(_labels[&"counter"], pad, y, inner, line_h, gap)
	y += gap
	if _mode == Mode.CARD:
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
	else:
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
	if _labels[&"forget"].visible:
		y += gap
		y = _place(_labels[&"forget"], pad, y, inner, line_h, gap)
	if not _labels[&"message"].text.is_empty():
		y = _place(_labels[&"message"], pad, y, inner, line_h, gap)
		_labels[&"message"].visible = true
	else:
		_labels[&"message"].visible = false
	y += gap
	y = _place(_labels[&"help"], pad, y, inner, line_h, gap)
	var height: float = y - gap + pad
	_panel.size = Vector2(width, height)
	var top: float = float(_cfg.get("top_px", 16))
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(minf(top, maxf(screen.y - height, 0.0))))


## Coloca `label` en la fila `y` (ancho `inner`) y devuelve la fila siguiente.
func _place(label: Label, x: float, y: float, inner: float, line_h: float, gap: float) -> float:
	label.position = Vector2(x, y)
	label.size = Vector2(inner, line_h)
	return y + line_h + gap
