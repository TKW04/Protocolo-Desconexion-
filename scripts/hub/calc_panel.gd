## Tienda de Calc POR PISTAS (tanda M1 de docs/propuesta-mejoras.md §1,
## 2026-10-17; sustituye a la lista de mejoras sueltas). Usa la base HubPanel
## (NinePatch, fuente de textos, arriba/abajo, pulso y salto). Textos, colores,
## arte y medidas en la seccion calc de data/hub.json; pistas y niveles en
## data/upgrades.json (UpgradeCatalog); reglas en GameState.
## - Lineas: saldo de puntos de atencion (con el rombo, ambar), power banks
##   (los que se tienen, encontrados y gastados; 2026-10-25) y «Sin guardar» / «Todo guardado».
## - Una FILA por pista (Pulso, Laser, Debug, Sync Rate, Energia): chip con el
##   icono (elegida: marco cian), nombre y 5 recuadros: comprado, siguiente
##   (late), vacio, bloqueado por acceso (candado), Proximamente y desconocido
##   (pista con chip «?» mientras su habilidad no este obtenida, sin nombre).
## - Detalle de la elegida: pista y nivel, nombre y descripcion del SIGUIENTE
##   nivel (o «Nivel maximo»), coste y estado (disponible o que falta).
## - Pulso compra el siguiente nivel de la elegida (GameState.purchase_upgrade):
##   mensaje y animacion del recuadro que se carga; comprar solo marca «sin
##   guardar» (se guarda en Notas). Salto cierra.
## Menu de tamano fijo, resalte y confirmacion (2026-10-27, peticion del
## usuario; mismo idioma que el menu de ESC, commits 2521794 y 8fca36a):
## - El panel mide siempre lo mismo (layout.panel_width_px de ancho; alto para
##   el titulo, layout.header_rows lineas, una ventana de layout.visible_rows
##   filas, layout.detail_rows lineas de detalle, el mensaje y el pie): no cambia
##   al moverse ni con el numero de pistas. Con mas pistas que filas la ventana
##   sigue a la eleccion y salen ▲ / ▼ a la derecha (▲ = el glifo ▼ volteado).
##   El prefijo de seleccion tiene ancho reservado: nada se mueve al elegir.
## - La fila elegida lleva una barra (relleno, contorno y marcador a la
##   izquierda; colores de la seccion selection) ademas del texto cian y el chip.
## - ui_feedback (move / confirm / back) avisa al AudioManager (ui_move...).
## - Pulso con una compra posible abre una confirmacion pequena de tamano fijo
##   (layout.confirm_width_px): «¿Comprar <nivel>?», pista y nivel, coste, Si /
##   No y el pie hub_confirm. Si compra lo de siempre; No o salto vuelven a la
##   lista sin gastar nada. Sin compra posible el pulso dice que falta, como antes.
class_name CalcPanel
extends HubPanel

## Se intento comprar el siguiente nivel de `track` (GameState.PurchaseResult).
signal purchase_attempted(track: StringName, result: int)
## Sonido de navegacion: &"move" (arriba/abajo), &"confirm" (abre la
## confirmacion) o &"back" (la cancela). Solo lo escucha el AudioManager.
signal ui_feedback(kind: StringName)

const OPTION_YES: StringName = &"yes"
const OPTION_NO: StringName = &"no"

const BOX_FULL: StringName = &"full"
const BOX_NEXT: StringName = &"next"
const BOX_EMPTY: StringName = &"empty"
const BOX_LOCKED: StringName = &"locked"
const BOX_SOON: StringName = &"soon"
const BOX_UNKNOWN: StringName = &"unknown"
const BOX_FILLING: StringName = &"filling"
const ICON_UNKNOWN: String = "unknown"

var _calc: Dictionary = HubData.section("calc")
var _art: Dictionary = _calc.get("art", {})
var _layout_cfg: Dictionary = _calc.get("layout", {})
var _chips_tex: Texture2D
var _boxes_tex: Texture2D
var _chip_size: Vector2i = Vector2i(24, 24)
var _box_size: Vector2i = Vector2i(10, 14)
## Por fila: {"chip": TextureRect, "boxes": Array[TextureRect]}.
var _rows: Array[Dictionary] = []
var _time: float = 0.0
## Animacion de compra: pista, nivel comprado y tiempo transcurrido (s).
var _buy_track: StringName = &""
var _buy_level: int = 0
var _buy_elapsed: float = 0.0
## Ventana de filas (primera visible) y medidas fijas de la ultima colocacion
## (px de arte del panel).
var _visible_rows: int = 5
var _scroll: int = 0
var _option_x: float = 0.0
var _names_x: float = 0.0
var _boxes_x: float = 0.0
var _options_y: float = 0.0
var _block_w: float = 0.0
var _arrow_up: Label
var _arrow_down: Label
var _bar: SelectionBar
## Confirmacion: abierta, opcion elegida (0 Si, 1 No) y pista que se compraria.
var _confirm_open: bool = false
var _confirm_index: int = 0
var _confirm_track: StringName = &""
var _dim: ColorRect
var _dialog: NinePatchRect
var _dialog_title: Label
var _dialog_lines: Array[Label] = []
var _dialog_options: Array[Label] = []
var _dialog_icons: Array[TextureRect] = []
var _dialog_bar: SelectionBar
var _dialog_hints: MenuHints


## Barra de la fila elegida: relleno, contorno de 1 px y marcador a la izquierda.
class SelectionBar extends Control:
	var fill: Color = Color(0, 0, 0, 0)
	var border: Color = Color.WHITE
	var marker: Color = Color.WHITE
	var marker_px: float = 2.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, fill, true)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), border, false, 1.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(marker_px, size.y)), marker, true)


func _ready() -> void:
	_chips_tex = load(String(_art.get("chips", ""))) as Texture2D
	_boxes_tex = load(String(_art.get("boxes", ""))) as Texture2D
	_chip_size = _vec2i(_art.get("chip_size", [24, 24]), _chip_size)
	_box_size = _vec2i(_art.get("box_size", [10, 14]), _box_size)
	_visible_rows = maxi(1, int(_layout_cfg.get("visible_rows", 5)))
	super._ready()
	_build_fixed_parts()
	EventBus.unsaved_changes_changed.connect(_on_unsaved_changes_changed)


func _process(delta: float) -> void:
	super._process(delta)
	if is_open():
		advance_for_tests(delta)


## Avanza el latido del siguiente recuadro y la animacion de compra `delta` s
## (lo llama _process; las pruebas y capturas lo usan para no esperar).
func advance_for_tests(delta: float) -> void:
	_time += delta
	if is_buy_animating():
		_buy_elapsed += delta
	_update_rows()


## Rellena el panel con el estado actual de GameState (conserva la eleccion).
func refresh() -> void:
	if _title == null:
		return
	var colors: Dictionary = _calc.get("colors", {})
	set_title(_text_of("title"))
	var unsaved: bool = GameState.has_unsaved_changes()
	set_lines([
		{"text": points_text(), "color": String(colors.get("points", "ambar"))},
		{"text": power_banks_text(), "color": String(colors.get("power_banks", "acento_cian"))},
		{"text": _text_of("status_unsaved" if unsaved else "status_saved"),
			"color": String(colors.get("unsaved" if unsaved else "saved", "texto_tenue"))},
	])
	var options: Array = []
	for track: StringName in get_track_ids():
		var known: bool = GameState.is_upgrade_track_available(track)
		options.append({"id": track, "text": track_name(track),
			"role": String(colors.get("track" if known else "track_unknown", "texto_claro"))})
	set_options(options)
	_refresh_detail()
	set_hints("hub_shop")
	super.refresh()


## «◆ 30 puntos de atención».
func points_text() -> String:
	return _text_of("points", "%d") % GameState.attention_points


## «Power banks: 1 (encontrados 2, gastados 1)»: los que se tienen, los
## encontrados y los gastados (coleccionable puro, 2026-10-25).
func power_banks_text() -> String:
	return _text_of("power_banks", "%d %d %d") % [
		GameState.power_banks, GameState.get_power_banks_found(), GameState.get_power_banks_spent()]


## Pistas en el orden de la tienda (el del catalogo).
func get_track_ids() -> Array[StringName]:
	return UpgradeCatalog.shared().track_ids()


## Pista elegida (vacio si no hay).
func get_selected_track() -> StringName:
	return get_selected_option()


## Nombre de la pista en su fila («???» si su habilidad no esta obtenida).
func track_name(track: StringName) -> String:
	if not GameState.is_upgrade_track_available(track):
		return _text_of("unknown_name", "???")
	var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
	return t.name if t != null else ""


## Estado de los 5 recuadros de `track` (BOX_*; BOX_NEXT para el siguiente
## comprable en este acceso y BOX_FILLING para el que se carga al comprar).
func box_states(track: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
	if t == null:
		return out
	var known: bool = GameState.is_upgrade_track_available(track)
	var owned: int = GameState.get_upgrade_level(track)
	var cap: int = GameState.get_upgrade_access_cap(track)
	for entry: UpgradeCatalog.Level in t.levels:
		var state: StringName = BOX_EMPTY
		if not known:
			state = BOX_UNKNOWN
		elif entry.level <= owned:
			state = BOX_FILLING if is_buy_animating() and track == _buy_track and entry.level == _buy_level \
					else BOX_FULL
		elif entry.level > cap:
			state = BOX_LOCKED
		elif not entry.implemented:
			state = BOX_SOON
		elif entry.level == owned + 1:
			state = BOX_NEXT
		out.append(state)
	return out


## Recuadros cargados de `track` (el nivel actual: 1 a 5).
func filled_count(track: StringName) -> int:
	return box_states(track).count(BOX_FULL) + box_states(track).count(BOX_FILLING)


## Estado del siguiente nivel de `track` para el detalle: «Disponible»,
## «Faltan 8 puntos», «Requiere acceso Kernel», «Próximamente»...
func state_text(track: StringName) -> String:
	var result: int = GameState.check_purchase(track)
	var next: UpgradeCatalog.Level = GameState.get_next_upgrade_level(track)
	match result:
		GameState.PurchaseResult.OK:
			return _text_of("state_available")
		GameState.PurchaseResult.MAX_LEVEL:
			return _text_of("state_max")
		GameState.PurchaseResult.ABILITY_MISSING:
			return _text_of("state_unknown")
		GameState.PurchaseResult.ACCESS_LOCKED:
			return _text_of("state_access", "%s") % access_name(next.min_lap)
		GameState.PurchaseResult.NOT_IMPLEMENTED:
			return _text_of("state_soon")
		GameState.PurchaseResult.NOT_ENOUGH_POINTS:
			return _text_of("state_not_enough_points", "%d") % (next.cost_points - GameState.attention_points)
		GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS:
			return _text_of("state_not_enough_power_banks")
	return ""


## Lineas del detalle de `track` (por defecto la elegida): [{text, color}].
func detail_lines(track: StringName = &"") -> Array:
	if track.is_empty():
		track = get_selected_track()
	var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
	if t == null:
		return []
	var colors: Dictionary = _calc.get("colors", {})
	if not GameState.is_upgrade_track_available(track):
		return [
			{"text": _text_of("unknown_name", "???"), "color": String(colors.get("detail_header", "texto_claro"))},
			{"text": _text_of("unknown_detail"), "color": String(colors.get("detail", "texto_tenue"))},
		]
	var owned: int = GameState.get_upgrade_level(track)
	var lines: Array = [{"text": _text_of("detail_header", "%s %d %d") % [t.name, owned, t.max_level()],
		"color": String(colors.get("detail_header", "texto_claro"))}]
	var next: UpgradeCatalog.Level = GameState.get_next_upgrade_level(track)
	if next == null:
		var current: UpgradeCatalog.Level = t.get_level(owned)
		lines.append({"text": _text_of("detail_max"), "color": String(colors.get("state_max", "acento_cian"))})
		lines.append({"text": "%s: %s" % [current.name, current.description],
			"color": String(colors.get("detail", "texto_tenue"))})
		return lines
	lines.append({"text": _text_of("detail_next", "%d %s") % [next.level, next.name],
		"color": String(colors.get("detail_next", "acento_cian"))})
	lines.append({"text": next.description, "color": String(colors.get("detail", "texto_tenue"))})
	var cost: String = _text_of("detail_cost", "%d") % next.cost_points
	if next.cost_power_banks > 0:
		cost = _text_of("detail_cost_banks", "%d %d") % [next.cost_points, next.cost_power_banks]
	lines.append({"text": cost, "color": String(colors.get("detail_cost", "ambar"))})
	var ok: bool = GameState.check_purchase(track) == GameState.PurchaseResult.OK
	lines.append({"text": state_text(track),
		"color": String(colors.get("state_available" if ok else "state_blocked", "texto_tenue"))})
	return lines


## Nombre del acceso de la vuelta `lap` (HubWorlds.access_name: Caché, Kernel
## o Raíz). La UI nunca dice vuelta.
static func access_name(lap: int) -> String:
	return HubWorlds.access_name(lap)


## Compra el siguiente nivel de la pista elegida (GameState.purchase_upgrade) y
## muestra el resultado. Devuelve el GameState.PurchaseResult.
func purchase_selected() -> int:
	var track: StringName = get_selected_track()
	var next: UpgradeCatalog.Level = GameState.get_next_upgrade_level(track)
	var result: int = GameState.purchase_upgrade(track)
	var colors: Dictionary = _calc.get("colors", {})
	var message: String = ""
	match result:
		GameState.PurchaseResult.OK:
			message = _text_of("message_bought", "%d %s") % [next.level, next.name]
			_buy_track = track
			_buy_level = next.level
			_buy_elapsed = 0.0
		GameState.PurchaseResult.MAX_LEVEL:
			message = _text_of("message_max")
		GameState.PurchaseResult.ABILITY_MISSING:
			message = _text_of("message_unknown")
		GameState.PurchaseResult.ACCESS_LOCKED:
			message = _text_of("message_access", "%s") % access_name(next.min_lap)
		GameState.PurchaseResult.NOT_IMPLEMENTED:
			message = _text_of("message_soon")
		GameState.PurchaseResult.NOT_ENOUGH_POINTS:
			message = _text_of("message_not_enough_points", "%d") % (next.cost_points - GameState.attention_points)
		GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS:
			message = _text_of("message_not_enough_power_banks")
	refresh()
	set_message(message, String(colors.get("message_bought" if result == GameState.PurchaseResult.OK else "message",
		"texto_claro")))
	purchase_attempted.emit(track, result)
	return result


## La animacion del recuadro que se carga tras comprar sigue en marcha.
func is_buy_animating() -> bool:
	return not _buy_track.is_empty() and _buy_elapsed < float(_layout_cfg.get("buy_anim_s", 0.4))


## Termina ya la animacion de compra (pruebas y capturas).
func finish_buy_animation() -> void:
	_buy_elapsed = float(_layout_cfg.get("buy_anim_s", 0.4))
	_update_rows()


## Cuadro del arte de los recuadros que se ve ahora en la fila `track`, recuadro
## `index` (0-4): nombre de art.box_states (full, next_a, locked, fill_2...).
func get_box_frame(track: StringName, index: int) -> String:
	var row: int = get_track_ids().find(track)
	if row < 0 or row >= _rows.size():
		return ""
	var rect := _rows[row]["boxes"][index] as TextureRect
	return String(rect.get_meta(&"frame", ""))


## Icono del chip de la fila `track` (pulse, laser... o unknown) y si se ve elegido.
func get_chip_frame(track: StringName) -> String:
	var row: int = get_track_ids().find(track)
	if row < 0 or row >= _rows.size():
		return ""
	return String((_rows[row]["chip"] as TextureRect).get_meta(&"frame", ""))


## Para pruebas: el nodo del chip y de un recuadro (posicion y visibilidad).
func get_row_nodes(track: StringName) -> Dictionary:
	var row: int = get_track_ids().find(track)
	return _rows[row] if row >= 0 and row < _rows.size() else {}


# --- HubPanel ---

func open() -> void:
	_buy_track = &""
	_scroll = 0
	_confirm_open = false
	super.open()
	_layout()


func close() -> void:
	_confirm_open = false
	super.close()
	_layout()


func move_selection(step: int) -> void:
	if _confirm_open:
		_confirm_index = posmod(_confirm_index + step, 2)
		ui_feedback.emit(&"move")
		_layout()
		return
	var before: int = get_selected_index()
	super.move_selection(step)
	if get_selected_index() != before:
		ui_feedback.emit(&"move")


func _on_confirm(_id: StringName) -> void:
	if _confirm_open:
		if _confirm_index == 0:
			_close_confirm()
			purchase_selected()
		else:
			cancel_purchase()
		return
	var track: StringName = get_selected_track()
	if GameState.check_purchase(track) == GameState.PurchaseResult.OK:
		_open_confirm(track)
	else:
		purchase_selected()


func _on_cancel() -> void:
	if _confirm_open:
		cancel_purchase()
	else:
		super._on_cancel()


func _on_selection_changed() -> void:
	set_message("")
	_refresh_detail()
	_update_rows()
	_layout()


func _option_row_height(_line_h: float) -> float:
	return float(_layout_cfg.get("row_height_px", 26))


func _option_inset_left() -> float:
	return float(_chip_size.x) + float(_layout_cfg.get("chip_gap_px", 6))


func _option_inset_right() -> float:
	return float(_layout_cfg.get("boxes_gap_px", 12)) + _boxes_width()


## Colocacion de TAMANO FIJO (sustituye a la de HubPanel, que mide el
## contenido): titulo, header_rows lineas, ventana de visible_rows filas,
## detail_rows lineas de detalle, una de mensaje y el pie, siempre en el
## mismo sitio.
func _layout() -> void:
	if _frame == null or not is_inside_tree() or _bar == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale
	_frame.size = screen
	var font_size: int = int(_config.get("font_size", 12))
	var line_h: float = _line_height()
	var pad: float = float(_config.get("padding_px", 10))
	var gap: float = float(_config.get("line_gap_px", 4))
	var size: Vector2 = fixed_panel_size()
	var width: float = size.x
	var row_h: float = maxf(_option_row_height(line_h), line_h)
	var pitch: float = row_h + _row_gap()
	var rows: int = visible_rows()
	var n: int = _option_ids.size()
	var scrolls: bool = n > rows
	# Ventana: la eleccion siempre visible, moviendo lo minimo.
	_scroll = clampi(_scroll, 0, maxi(n - rows, 0))
	if _selected < _scroll:
		_scroll = _selected
	elif _selected >= _scroll + rows:
		_scroll = _selected - rows + 1
	var y: float = pad
	_place_line(_title, y, width, pad, line_h)
	y += line_h + gap * 2.0
	for label: Label in _line_labels:
		if label.visible:
			_place_line(label, y, width, pad, line_h)
		y += line_h + gap
	y += float(maxi(header_rows() - _line_labels.size(), 0)) * (line_h + gap) + gap
	_options_y = y
	# Bloque de opciones centrado, de ancho fijo (todas las pistas y «???»).
	var slot: float = _prefix_slot(font_size)
	var names_w: float = _names_width(font_size)
	var arrow_w: float = _text_w(_text_of("scroll_arrow", "▼"), font_size)
	var arrow_gap: float = float(_layout_cfg.get("scroll_arrow_gap_px", 6))
	_block_w = _option_inset_left() + slot + names_w + float(_layout_cfg.get("boxes_gap_px", 12)) + _boxes_width()
	if scrolls:
		_block_w += arrow_gap + arrow_w
	_option_x = pad + maxf(floorf((width - pad * 2.0 - _block_w) * 0.5), 0.0)
	_names_x = _option_x + _option_inset_left() + slot
	_boxes_x = _names_x + names_w + float(_layout_cfg.get("boxes_gap_px", 12))
	for i: int in _option_labels.size():
		var label: Label = _option_labels[i]
		label.visible = i < n and i >= _scroll and i < _scroll + rows
		if not label.visible:
			continue
		var prefix: String = _text("selected_prefix" if i == _selected else "unselected_prefix")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.position = Vector2(_names_x - _text_w(prefix, font_size), _row_top(i) + floorf((row_h - line_h) * 0.5))
		label.size = Vector2(maxf(_boxes_x - label.position.x, 0.0), line_h)
	var arrow_x: float = _boxes_x + _boxes_width() + arrow_gap
	_arrow_up.visible = scrolls and _scroll > 0
	_arrow_down.visible = scrolls and _scroll + rows < n
	for arrow: Label in [_arrow_up, _arrow_down]:
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.size = Vector2(arrow_w, line_h)
		arrow.pivot_offset = arrow.size * 0.5
	_arrow_up.position = Vector2(arrow_x, _row_top(_scroll) + floorf((row_h - line_h) * 0.5))
	_arrow_down.position = Vector2(arrow_x, _row_top(_scroll + mini(n, rows) - 1) + floorf((row_h - line_h) * 0.5))
	# Barra de la fila elegida.
	var bar_pad: float = float(_selection_cfg().get("pad_x_px", 4))
	_bar.visible = n > 0
	_bar.position = Vector2(_option_x - bar_pad, _row_top(_selected) - 1.0)
	_bar.size = Vector2(_block_w - (arrow_gap + arrow_w if scrolls else 0.0) + bar_pad * 2.0, row_h + 2.0)
	_bar.queue_redraw()
	y = _options_y + float(rows) * pitch - _row_gap() + gap * 2.0
	for k: int in _detail_labels.size():
		var label: Label = _detail_labels[k]
		label.visible = not label.text.is_empty() and k < detail_rows()
		_place_line(label, y + float(k) * (line_h + gap), width, pad, line_h)
	y += float(detail_rows()) * (line_h + gap)
	_message.visible = not _message.text.is_empty()
	_place_line(_message, y, width, pad, line_h)
	y += line_h + gap
	_hints.position = Vector2(floorf((width - _hints.get_row_width()) * 0.5), y)
	_panel.size = size
	var top: float = float(_config.get("top_px", 48))
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(minf(top, maxf(screen.y - size.y, 0.0))))
	_after_layout()
	_layout_confirm(line_h, pad, gap, font_size)


## Tamano fijo del panel en px de arte.
func fixed_panel_size() -> Vector2:
	var line_h: float = _line_height()
	var pad: float = float(_config.get("padding_px", 10))
	var gap: float = float(_config.get("line_gap_px", 4))
	var row_h: float = maxf(_option_row_height(line_h), line_h)
	var height: float = pad + line_h + gap * 2.0 + float(header_rows()) * (line_h + gap) + gap \
		+ float(visible_rows()) * (row_h + _row_gap()) - _row_gap() + gap * 2.0 \
		+ float(detail_rows()) * (line_h + gap) + line_h + gap + _hints.get_row_height() + pad
	return Vector2(float(_layout_cfg.get("panel_width_px", 320)), height)


## Filas visibles de pistas (layout.visible_rows; mas pistas = desplazamiento).
func visible_rows() -> int:
	return _visible_rows


## Pruebas: cambia el numero de filas de la ventana.
func set_visible_rows(rows: int) -> void:
	_visible_rows = maxi(1, rows)
	_layout()


## Lineas fijas bajo el titulo reservadas (saldo, power banks y estado).
func header_rows() -> int:
	return int(_layout_cfg.get("header_rows", 3))


## Lineas de detalle reservadas (cabecera, siguiente, descripcion, coste, estado).
func detail_rows() -> int:
	return int(_layout_cfg.get("detail_rows", 5))


## Primera fila visible.
func get_scroll() -> int:
	return _scroll


## La pista `index` se ve (dentro de la ventana).
func is_option_shown(index: int) -> bool:
	return index >= 0 and index < _option_ids.size() and index >= _scroll and index < _scroll + visible_rows()


## Flechas ▲ / ▼ visibles.
func scroll_arrows_shown() -> Vector2i:
	return Vector2i(int(_arrow_up.visible), int(_arrow_down.visible))


## Rectangulo de la barra de seleccion en px de arte del panel (pruebas).
func get_selection_bar_rect() -> Rect2:
	return Rect2(_bar.position, _bar.size) if _bar != null and _bar.visible else Rect2()


## Colores de la barra (fill, border, marker).
func get_selection_bar_colors() -> Dictionary:
	return {"fill": _bar.fill, "border": _bar.border, "marker": _bar.marker}


## Color del texto de la pista `index` (pruebas: la elegida en cian).
func get_option_color(index: int) -> Color:
	return _label_color(_option_labels[index])


## Etiqueta de la pista `index` (pruebas: posicion).
func get_option_label(index: int) -> Label:
	return _get_option_label(index)


# --- Confirmacion de compra ---

## La confirmacion «¿Comprar …?» esta abierta.
func is_confirm_open() -> bool:
	return _confirm_open


## Opcion elegida en la confirmacion: OPTION_YES u OPTION_NO.
func get_confirm_selected() -> StringName:
	return OPTION_YES if _confirm_index == 0 else OPTION_NO


## Pista que se compraria al aceptar la confirmacion.
func get_confirm_track() -> StringName:
	return _confirm_track


## Titulo y lineas de la confirmacion (pruebas).
func get_confirm_texts() -> PackedStringArray:
	var out: PackedStringArray = [_dialog_title.text]
	for label: Label in _dialog_lines:
		out.append(label.text)
	for label: Label in _dialog_options:
		out.append(label.text)
	return out


## Texto del pie de la confirmacion.
func get_confirm_help() -> String:
	return _dialog_hints.get_text()


## Rectangulo de la confirmacion en pantalla (px reales).
func get_confirm_rect() -> Rect2:
	return Rect2(_dialog.position * _frame.scale, _dialog.size * _frame.scale)


## Tamano fijo de la confirmacion en px de arte.
func fixed_confirm_size() -> Vector2:
	var line_h: float = _line_height()
	var pad: float = float(_config.get("padding_px", 10))
	var gap: float = float(_config.get("line_gap_px", 4))
	var height: float = pad + line_h + gap * 2.0 + 2.0 * (line_h + gap) + gap + 2.0 * (line_h + gap) + gap \
		+ _dialog_hints.get_row_height() + pad
	return Vector2(float(_layout_cfg.get("confirm_width_px", 220)), height)


## Lineas de la confirmacion de `track` (titulo, pista y nivel, coste).
func confirm_lines(track: StringName) -> PackedStringArray:
	var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
	var next: UpgradeCatalog.Level = GameState.get_next_upgrade_level(track)
	if t == null or next == null:
		return PackedStringArray(["", "", ""])
	var cost: String = _text_of("detail_cost", "%d") % next.cost_points
	if next.cost_power_banks > 0:
		cost = _text_of("detail_cost_banks", "%d %d") % [next.cost_points, next.cost_power_banks]
	return PackedStringArray([_text_of("confirm_title", "%s") % next.name,
		_text_of("confirm_level", "%s %d %d") % [t.name, next.level, t.max_level()], cost])


## Cancela la confirmacion: vuelve a la lista sin comprar nada.
func cancel_purchase() -> void:
	if not _confirm_open:
		return
	_close_confirm()
	ui_feedback.emit(&"back")


func _open_confirm(track: StringName) -> void:
	_confirm_open = true
	_confirm_index = 0
	_confirm_track = track
	set_message("")
	var lines: PackedStringArray = confirm_lines(track)
	_dialog_title.text = lines[0]
	_dialog_lines[0].text = lines[1]
	_dialog_lines[1].text = lines[2]
	_dialog_hints.notify_opened("CalcConfirm")
	ui_feedback.emit(&"confirm")
	_layout()


func _close_confirm() -> void:
	_confirm_open = false
	_confirm_track = &""
	_layout()


func _layout_confirm(line_h: float, pad: float, gap: float, font_size: int) -> void:
	_dim.visible = _confirm_open
	_dialog.visible = _confirm_open
	_dim.position = _panel.position
	_dim.size = _panel.size
	var size: Vector2 = fixed_confirm_size()
	_dialog.size = size
	_dialog.position = _panel.position + ((_panel.size - size) * 0.5).floor()
	var y: float = pad
	_place_line(_dialog_title, y, size.x, pad, line_h)
	y += line_h + gap * 2.0
	for label: Label in _dialog_lines:
		_place_line(label, y, size.x, pad, line_h)
		y += line_h + gap
	y += gap
	var texts: Dictionary = _calc.get("texts", {})
	var icon_px: float = _icon_px()
	var inset: float = _icon_inset()
	var slot: float = _prefix_slot(font_size)
	var opt_w: float = 0.0
	for key: String in ["confirm_yes", "confirm_no"]:
		opt_w = maxf(opt_w, _text_w(String(texts.get(key, "")), font_size))
	var block: float = inset + slot + opt_w
	var x: float = floorf((size.x - block) * 0.5)
	for i: int in _dialog_options.size():
		var label: Label = _dialog_options[i]
		var selected: bool = i == _confirm_index
		var prefix: String = _text("selected_prefix" if selected else "unselected_prefix")
		label.text = prefix + String(texts.get("confirm_yes" if i == 0 else "confirm_no", ""))
		_set_color(label, String(_config.get("colors", {}).get("option_selected" if selected else "option",
			"acento_cian" if selected else "texto_tenue")))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var row_y: float = y + float(i) * (line_h + gap)
		label.position = Vector2(x + inset + slot - _text_w(prefix, font_size), row_y)
		label.size = Vector2(maxf(size.x - pad - label.position.x, 0.0), line_h)
		var icon: TextureRect = _dialog_icons[i]
		icon.size = Vector2(icon_px, icon_px)
		icon.position = Vector2(x, row_y + floorf((line_h - icon_px) * 0.5))
		icon.visible = icon.texture != null
	var bar_pad: float = float(_selection_cfg().get("pad_x_px", 4))
	_dialog_bar.position = Vector2(x - bar_pad, y + float(_confirm_index) * (line_h + gap) - 1.0)
	_dialog_bar.size = Vector2(block + bar_pad * 2.0, line_h + 2.0)
	_dialog_bar.queue_redraw()
	y += 2.0 * (line_h + gap) + gap
	_dialog_hints.position = Vector2(floorf((size.x - _dialog_hints.get_row_width()) * 0.5), y)


func _after_layout() -> void:
	var ids: Array[StringName] = get_track_ids()
	while _rows.size() < ids.size():
		_rows.append(_new_row(_rows.size()))
	var row_h: float = _option_row_height(0.0)
	var gap: float = float(_layout_cfg.get("box_gap_px", 2))
	for i: int in _rows.size():
		var label: Label = _get_option_label(i)
		var shown: bool = i < ids.size() and label != null and label.visible
		var chip := _rows[i]["chip"] as TextureRect
		chip.visible = shown
		for box: TextureRect in _rows[i]["boxes"]:
			box.visible = shown
		if not shown:
			continue
		var top: float = _row_top(i)
		chip.position = Vector2(_option_x, top + floorf((row_h - _chip_size.y) * 0.5))
		var y: float = top + floorf((row_h - _box_size.y) * 0.5)
		for k: int in _rows[i]["boxes"].size():
			(_rows[i]["boxes"][k] as TextureRect).position = Vector2(_boxes_x + k * (_box_size.x + gap), y)
	_update_rows()


# --- Interno ---

func _text_of(key: String, fallback: String = "") -> String:
	return String(_calc.get("texts", {}).get(key, fallback))


func _selection_cfg() -> Dictionary:
	var value: Variant = _calc.get("selection", {})
	return value if value is Dictionary else {}


func _text_w(text: String, font_size: int) -> float:
	return ceilf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


## Ancho reservado al prefijo de seleccion (el mayor de los dos).
func _prefix_slot(font_size: int) -> float:
	return maxf(_text_w(_text("selected_prefix"), font_size), _text_w(_text("unselected_prefix"), font_size))


## Ancho de la columna de nombres: la pista mas larga o «???».
func _names_width(font_size: int) -> float:
	var w: float = _text_w(_text_of("unknown_name", "???"), font_size)
	for track: StringName in get_track_ids():
		var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
		if t != null:
			w = maxf(w, _text_w(t.name, font_size))
	return w


## Borde superior de la fila `index` (px de arte del panel) en la ventana.
func _row_top(index: int) -> float:
	var row_h: float = maxf(_option_row_height(0.0), _line_height())
	return _options_y + float(index - _scroll) * (row_h + _row_gap())


## Hueco entre filas de pistas (layout.row_gap_px; menor que el de las lineas
## para que el panel fijo quepa en 720 px).
func _row_gap() -> float:
	return float(_layout_cfg.get("row_gap_px", 2))


func _place_line(label: Label, y: float, width: float, pad: float, line_h: float) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(pad, y)
	label.size = Vector2(width - pad * 2.0, line_h)


func _new_bar(parent: Control, node_name: String) -> SelectionBar:
	var cfg: Dictionary = _selection_cfg()
	var bar := SelectionBar.new()
	bar.name = node_name
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = HubData.color(String(cfg.get("fill", "cian_tenue")))
	fill.a = float(cfg.get("fill_alpha", 0.35))
	bar.fill = fill
	bar.border = HubData.color(String(cfg.get("border", "acento_cian")))
	bar.marker = HubData.color(String(cfg.get("marker", "acento_cian")))
	bar.marker_px = float(cfg.get("marker_px", 2))
	parent.add_child(bar)
	parent.move_child(bar, 0)
	return bar


## Flechas, barra de seleccion y la confirmacion (encima del panel).
func _build_fixed_parts() -> void:
	var colors: Dictionary = _calc.get("colors", {})
	_arrow_up = _new_label("ScrollUp", "texto_tenue")
	_arrow_down = _new_label("ScrollDown", "texto_tenue")
	_arrow_up.text = _text_of("scroll_arrow", "▼")
	_arrow_down.text = _text_of("scroll_arrow", "▼")
	_arrow_up.scale = Vector2(1.0, -1.0)
	_arrow_up.visible = false
	_arrow_down.visible = false
	_bar = _new_bar(_panel, "SelectionBar")
	_dim = ColorRect.new()
	_dim.name = "ConfirmDim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim: Color = HubData.color(String(_selection_cfg().get("dim", "fondo_profundo")))
	dim.a = float(_selection_cfg().get("dim_alpha", 0.6))
	_dim.color = dim
	_dim.visible = false
	_frame.add_child(_dim)
	_dialog = NinePatchRect.new()
	_dialog.name = "Confirm"
	_dialog.texture = _panel.texture
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_dialog.set_patch_margin(side, _panel.get_patch_margin(side))
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.visible = false
	_frame.add_child(_dialog)
	_dialog_bar = _new_bar(_dialog, "ConfirmBar")
	_dialog_title = _move_to_dialog(_new_label("ConfirmTitle", String(colors.get("confirm_title", "texto_claro"))))
	_dialog_lines = [
		_move_to_dialog(_new_label("ConfirmLevel", String(colors.get("confirm_level", "acento_cian")))),
		_move_to_dialog(_new_label("ConfirmCost", String(colors.get("detail_cost", "ambar")))),
	]
	var icons: Dictionary = HubData.section("notas").get("option_icons", {})
	for key: String in ["yes", "no"]:
		_dialog_options.append(_move_to_dialog(_new_label("Confirm_" + key, "texto_tenue")))
		var rect := TextureRect.new()
		rect.name = "ConfirmIcon_" + key
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.texture = _icon_texture(icons.get(key, null))
		_dialog.add_child(rect)
		_dialog_icons.append(rect)
	_dialog_hints = MenuHints.new()
	_dialog_hints.setup(_font, int(_config.get("font_size", 12)), _shader, _key_color, hint_colors())
	_dialog_hints.show_set("hub_confirm")
	_dialog.add_child(_dialog_hints)
	_dialog_hints.row_changed.connect(_layout)


func _move_to_dialog(label: Label) -> Label:
	_panel.remove_child(label)
	_dialog.add_child(label)
	return label


func _boxes_width() -> float:
	return 5.0 * _box_size.x + 4.0 * float(_layout_cfg.get("box_gap_px", 2))


func _new_row(index: int) -> Dictionary:
	var panel: NinePatchRect = _get_panel_node()
	var chip := TextureRect.new()
	chip.name = "Chip%d" % index
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.texture = _atlas(_chips_tex, Rect2(Vector2.ZERO, Vector2(_chip_size)))
	panel.add_child(chip)
	var boxes: Array[TextureRect] = []
	for k: int in 5:
		var box := TextureRect.new()
		box.name = "Box%d_%d" % [index, k]
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.texture = _atlas(_boxes_tex, Rect2(Vector2.ZERO, Vector2(_box_size)))
		panel.add_child(box)
		boxes.append(box)
	return {"chip": chip, "boxes": boxes}


func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


## Pone en cada fila el cuadro del chip y de los recuadros que tocan ahora.
func _update_rows() -> void:
	var ids: Array[StringName] = get_track_ids()
	var icons: Array = _art.get("chip_icons", [])
	var states: Array = _art.get("box_states", [])
	var selected: StringName = get_selected_track()
	var beat: bool = fmod(_time * float(_layout_cfg.get("next_hz", 2.0)), 1.0) < 0.5
	for i: int in mini(ids.size(), _rows.size()):
		var track: StringName = ids[i]
		var t: UpgradeCatalog.Track = UpgradeCatalog.shared().get_track(track)
		var icon: String = t.icon if GameState.is_upgrade_track_available(track) else ICON_UNKNOWN
		var col: int = maxi(icons.find(icon), 0)
		var row: int = 1 if track == selected else 0
		var chip := _rows[i]["chip"] as TextureRect
		(chip.texture as AtlasTexture).region = Rect2(Vector2(col * _chip_size.x, row * _chip_size.y), Vector2(_chip_size))
		chip.set_meta(&"frame", "%s%s" % [icon, "_selected" if row == 1 else ""])
		var box_list: Array[StringName] = box_states(track)
		for k: int in mini(box_list.size(), _rows[i]["boxes"].size()):
			var frame: String = _box_frame_name(box_list[k], beat)
			var box := _rows[i]["boxes"][k] as TextureRect
			var index: int = maxi(states.find(frame), 0)
			(box.texture as AtlasTexture).region = Rect2(Vector2(index * _box_size.x, 0), Vector2(_box_size))
			box.set_meta(&"frame", frame)


func _box_frame_name(state: StringName, beat: bool) -> String:
	match state:
		BOX_NEXT:
			return "next_a" if beat else "next_b"
		BOX_FILLING:
			var duration: float = maxf(float(_layout_cfg.get("buy_anim_s", 0.4)), 0.001)
			var step: int = clampi(int(_buy_elapsed / duration * 4.0), 0, 3)
			return ["fill_1", "fill_2", "fill_3", "flash"][step]
	return String(state)


func _refresh_detail() -> void:
	set_detail_lines(detail_lines())


static func _vec2i(raw: Variant, fallback: Vector2i) -> Vector2i:
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return fallback


func _on_unsaved_changes_changed(_has_changes: bool) -> void:
	if is_open():
		var message: String = get_message()
		refresh()
		_message.text = message
		_layout()
