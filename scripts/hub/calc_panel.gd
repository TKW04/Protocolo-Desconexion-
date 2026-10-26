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
class_name CalcPanel
extends HubPanel

## Se intento comprar el siguiente nivel de `track` (GameState.PurchaseResult).
signal purchase_attempted(track: StringName, result: int)

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


func _ready() -> void:
	_chips_tex = load(String(_art.get("chips", ""))) as Texture2D
	_boxes_tex = load(String(_art.get("boxes", ""))) as Texture2D
	_chip_size = _vec2i(_art.get("chip_size", [24, 24]), _chip_size)
	_box_size = _vec2i(_art.get("box_size", [10, 14]), _box_size)
	super._ready()
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
	super.open()


func _on_confirm(_id: StringName) -> void:
	purchase_selected()


func _on_selection_changed() -> void:
	set_message("")
	_refresh_detail()
	_update_rows()


func _option_row_height(_line_h: float) -> float:
	return float(_layout_cfg.get("row_height_px", 26))


func _option_inset_left() -> float:
	return float(_chip_size.x) + float(_layout_cfg.get("chip_gap_px", 6))


func _option_inset_right() -> float:
	return float(_layout_cfg.get("boxes_gap_px", 12)) + _boxes_width()


func _after_layout() -> void:
	var ids: Array[StringName] = get_track_ids()
	while _rows.size() < ids.size():
		_rows.append(_new_row(_rows.size()))
	var names_w: float = 0.0
	for i: int in ids.size():
		var label: Label = _get_option_label(i)
		if label != null and label.visible:
			names_w = maxf(names_w, ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(_config.get("font_size", 12))).x))
	var row_h: float = _option_row_height(0.0)
	for i: int in _rows.size():
		var label: Label = _get_option_label(i)
		var shown: bool = i < ids.size() and label != null and label.visible
		var chip := _rows[i]["chip"] as TextureRect
		chip.visible = shown
		for box: TextureRect in _rows[i]["boxes"]:
			box.visible = shown
		if not shown:
			continue
		var top: float = label.position.y - floorf((row_h - _line_height()) * 0.5)
		chip.position = Vector2(label.position.x - _option_inset_left(), top + floorf((row_h - _chip_size.y) * 0.5))
		var x: float = label.position.x + names_w + float(_layout_cfg.get("boxes_gap_px", 12))
		var y: float = top + floorf((row_h - _box_size.y) * 0.5)
		var gap: float = float(_layout_cfg.get("box_gap_px", 2))
		for k: int in _rows[i]["boxes"].size():
			(_rows[i]["boxes"][k] as TextureRect).position = Vector2(x + k * (_box_size.x + gap), y)
	_update_rows()


# --- Interno ---

func _text_of(key: String, fallback: String = "") -> String:
	return String(_calc.get("texts", {}).get(key, fallback))


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
