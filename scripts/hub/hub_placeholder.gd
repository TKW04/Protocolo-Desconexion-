## Pantalla PROVISIONAL de regreso al hub (C4: "al terminar un nivel se vuelve
## al hub"; el hub no existe en el vertical slice). No es el hub y no inventa su
## contenido: muestra solo
##   «Regreso al hub (provisional)»
##   «Nivel completado: <nombre del nivel>»
##   «Puntos de atención: <n>»
##   «Pulsa salto para volver a jugar»
## con la fuente de textos y colores de la paleta del Mundo 1. Todo sale de
## data/hub_placeholder.json.
##
## Uso: show_result(level_id, attention_points). El flujo de nivel (paso 16) la
## cargara con EventBus.level_completed. Con la accion restart_action (jump),
## pasado input_delay_s (tiempo real), emite restart_requested(level_id) y, si
## restart_scene_path existe, cambia a esa escena.
##
## MEJORAS (decision 2026-10-14; provisional hasta que exista el hub real con
## Calc): bajo el resultado lista las mejoras de data/upgrades.json con su
## coste y estado, los power banks y el detalle de la elegida. move_up /
## move_down eligen y pulse compra (GameState.purchase_upgrade); todo por el
## Input Map (teclado o mando).
##
## ENERGIA (decision 2026-10-15): en el hub se recarga la energia de Debug (la
## misma que gasta el laser). Mientras no exista el hub real, show_result()
## llena la barra si refill_debug_energy es true (data/hub_placeholder.json).
##
## GUARDADO MANUAL (decision 2026-10-15; PROVISIONAL hasta la estacion "copia
## local" del hub real, docs/propuesta-hub-y-guardado.md): la accion
## save_action (save_game) guarda con GameState.save_game(). Muestra el control
## ("Guardar: C / R3 (mando)", leido del Input Map) y el indicador "Sin
## guardar" / "Todo guardado". Mientras se muestra esta en el grupo
## QuitGuard.SAVE_STATION_GROUP: el aviso al salir ofrece guardar.
class_name HubPlaceholder
extends CanvasLayer

const DATA_PATH: String = "res://data/hub_placeholder.json"
const LINE_KEYS: Array[StringName] = [&"title", &"completed", &"points", &"help"]
## Lineas fijas en orden de pantalla (las filas de mejoras van tras upgrades_title).
const HEADER_KEYS: Array[StringName] = [&"title", &"completed", &"points", &"save_status", &"power_banks", &"upgrades_title"]
const FOOTER_KEYS: Array[StringName] = [&"detail", &"message", &"help_upgrades", &"help_save", &"help"]

## El jugador pide volver a jugar el nivel.
signal restart_requested(level_id: String)

## Escena a la que ir al reiniciar (vacio: solo se emite restart_requested).
@export_file("*.tscn") var restart_scene_path: String = ""

var _data: Dictionary = {}
var _font: Font
var _level_id: String = ""
var _attention_points: int = 0
var _shown_time: float = 0.0
var _restart_count: int = 0
var _frame: Control
var _background: ColorRect
var _panel: NinePatchRect
var _labels: Dictionary[StringName, Label] = {}
var _row_labels: Array[Label] = []
var _upgrade_ids: Array[StringName] = []
var _selected: int = 0
var _shader: Shader
var _key_color: Color
var _shown: bool = false
var _save_count: int = 0


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	layer = int(_data.get("layer", 20))
	_build()
	get_viewport().size_changed.connect(_layout)
	EventBus.unsaved_changes_changed.connect(_on_unsaved_changes_changed)
	add_to_group(QuitGuard.SAVE_STATION_GROUP)
	_layout()


func _process(delta: float) -> void:
	_shown_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(StringName(_data.get("restart_action", "jump"))):
		if request_restart():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(StringName(_data.get("save_action", "save_game"))):
		if _accepts_input():
			save_now()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(StringName(_data.get("select_up_action", "move_up"))):
		if _accepts_input():
			move_selection(-1)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(StringName(_data.get("select_down_action", "move_down"))):
		if _accepts_input():
			move_selection(1)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(StringName(_data.get("purchase_action", "pulse"))):
		if _accepts_input():
			purchase_selected()
			get_viewport().set_input_as_handled()


# --- API ---

## Muestra el resultado del nivel `level_id` con `attention_points` puntos.
func show_result(level_id: String, attention_points: int) -> void:
	_level_id = level_id
	_attention_points = attention_points
	_shown_time = 0.0
	if bool(_data.get("refill_debug_energy", true)):
		GameState.refill_debug_energy()
	var texts: Dictionary = _data.get("texts", {})
	_labels[&"title"].text = String(texts.get("title", ""))
	_labels[&"completed"].text = String(texts.get("completed", "%s")) % level_name(level_id)
	_labels[&"points"].text = String(texts.get("points", "%d")) % attention_points
	_labels[&"help"].text = String(texts.get("help", ""))
	_labels[&"upgrades_title"].text = String(texts.get("upgrades_title", ""))
	_labels[&"help_upgrades"].text = String(texts.get("help_upgrades", ""))
	_labels[&"message"].text = String(texts.get("message_idle", ""))
	_labels[&"help_save"].text = String(texts.get("help_save", "%s")) % save_control_text()
	_shown = true
	refresh_upgrades()
	visible = true


## Vuelve a escribir puntos, power banks, filas de mejoras y detalle con el
## estado actual de GameState.
func refresh_upgrades() -> void:
	var texts: Dictionary = _data.get("texts", {})
	_labels[&"points"].text = String(texts.get("points", "%d")) % _attention_points
	_labels[&"power_banks"].text = String(texts.get("power_banks", "%d %d %d")) % [
		GameState.power_banks, floori(GameState.power_bank_charge), roundi(GameState.get_power_bank_capacity())]
	var colors: Dictionary = _data.get("colors", {})
	for i: int in _upgrade_ids.size():
		var id: StringName = _upgrade_ids[i]
		var label: Label = _row_labels[i]
		label.text = get_upgrade_row_text(i)
		var color_key: String = "upgrade"
		if i == _selected:
			color_key = "upgrade_selected"
		elif GameState.is_upgrade_purchased(id):
			color_key = "upgrade_owned"
		_set_color(label, String(colors.get(color_key, "#f2f4f8")))
	_labels[&"detail"].text = get_detail_text()
	_refresh_save_status()
	_layout()


## Texto de la fila `index`: prefijo, nombre, coste y estado.
func get_upgrade_row_text(index: int) -> String:
	var texts: Dictionary = _data.get("texts", {})
	var entry: UpgradeCatalog.Entry = UpgradeCatalog.shared().get_entry(_upgrade_ids[index])
	var prefix: String = String(texts.get("selected_prefix" if index == _selected else "unselected_prefix", ""))
	var cost: String
	if entry.cost_power_banks > 0:
		cost = String(texts.get("cost_points_and_banks", "%d %d")) % [entry.cost_points, entry.cost_power_banks]
	else:
		cost = String(texts.get("cost_points", "%d")) % entry.cost_points
	return String(texts.get("upgrade_row", "%s%s %s %s")) % [prefix, entry.name, cost, _state_text(entry.id)]


## Detalle de la mejora elegida: etiqueta, valor base y valor nuevo.
func get_detail_text() -> String:
	if _upgrade_ids.is_empty():
		return ""
	var entry: UpgradeCatalog.Entry = UpgradeCatalog.shared().get_entry(_upgrade_ids[_selected])
	var texts: Dictionary = _data.get("texts", {})
	return String(texts.get("detail", "%s %s%s %s%s")) % [
		entry.label, format_number(GameState.base_value(entry.target)), entry.unit,
		format_number(entry.value), entry.unit]


## Numero para pantalla: sin decimales si es entero; coma decimal.
static func format_number(value: float) -> String:
	if is_nan(value):
		return "?"
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2).replace(".", ",")


func get_upgrade_ids() -> Array[StringName]:
	return _upgrade_ids


func get_selected_index() -> int:
	return _selected


func get_selected_upgrade() -> StringName:
	return _upgrade_ids[_selected] if not _upgrade_ids.is_empty() else &""


## Elige la fila `index` (acotada).
func select(index: int) -> void:
	if _upgrade_ids.is_empty():
		return
	_selected = clampi(index, 0, _upgrade_ids.size() - 1)
	refresh_upgrades()


## Mueve la seleccion `step` filas (da la vuelta).
func move_selection(step: int) -> void:
	if _upgrade_ids.is_empty():
		return
	_selected = posmod(_selected + step, _upgrade_ids.size())
	refresh_upgrades()


## Compra la mejora elegida y muestra el resultado.
## Devuelve el GameState.PurchaseResult.
func purchase_selected() -> int:
	var id: StringName = get_selected_upgrade()
	var result: int = GameState.purchase_upgrade(id)
	var texts: Dictionary = _data.get("texts", {})
	var message: String = ""
	if result == GameState.PurchaseResult.OK:
		message = String(texts.get("message_bought", "%s")) % UpgradeCatalog.shared().get_entry(id).name
	elif result == GameState.PurchaseResult.ALREADY_OWNED:
		message = String(texts.get("message_owned", ""))
	elif result == GameState.PurchaseResult.NOT_ENOUGH_POINTS:
		message = String(texts.get("message_not_enough_points", ""))
	elif result == GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS:
		message = String(texts.get("message_not_enough_power_banks", ""))
	_labels[&"message"].text = message
	_attention_points = GameState.attention_points
	refresh_upgrades()
	return result


## Guarda la partida (GameState.save_game) y muestra el resultado. Sin cambios
## pendientes no escribe: dice que todo esta guardado. Verdadero si todo quedo
## guardado.
func save_now() -> bool:
	var texts: Dictionary = _data.get("texts", {})
	var ok: bool = true
	if not GameState.has_unsaved_changes():
		_labels[&"message"].text = String(texts.get("message_nothing_to_save", ""))
	else:
		ok = GameState.save_game()
		if ok:
			_save_count += 1
		_labels[&"message"].text = String(texts.get("message_saved" if ok else "message_save_failed", ""))
	refresh_upgrades()
	return ok


## Se puede guardar aqui (QuitGuard): la pantalla se esta mostrando.
func can_save_now() -> bool:
	return _shown and visible and is_inside_tree()


## Control de save_action leido del Input Map ("C / R3 (mando)").
func save_control_text() -> String:
	return AbilityNotices.control_text(StringName(_data.get("save_action", "save_game")), AbilityNotices.load_data())


func get_save_count() -> int:
	return _save_count


## Pide reiniciar el nivel. Falso si aun no ha pasado input_delay_s.
func request_restart() -> bool:
	if not _accepts_input():
		return false
	_restart_count += 1
	restart_requested.emit(_level_id)
	if not restart_scene_path.is_empty() and ResourceLoader.exists(restart_scene_path):
		get_tree().change_scene_to_file.call_deferred(restart_scene_path)
	return true


## Nombre del nivel (campo name de data/levels/<id>.json) o el id si no hay.
func level_name(level_id: String) -> String:
	var path: String = String(_data.get("level_data_dir", "res://data/levels/")) + level_id + ".json"
	if not FileAccess.file_exists(path):
		return level_id
	var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if level is Dictionary:
		return String(level.get("name", level_id))
	return level_id


func get_line_text(key: StringName) -> String:
	return _labels[key].text


## Todas las lineas visibles (fijas y filas de mejoras).
func get_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label in _ordered_labels():
		out.append(label.text)
	return out


func get_font() -> Font:
	return _font


func get_level_id() -> String:
	return _level_id


func get_restart_count() -> int:
	return _restart_count


## Para pruebas: da por pasado el retardo de entrada.
func skip_input_delay() -> void:
	_shown_time = float(_data.get("input_delay_s", 0.5))


# --- Interno ---

func _accepts_input() -> bool:
	return _shown_time >= float(_data.get("input_delay_s", 0.5))


func _state_text(id: StringName) -> String:
	var texts: Dictionary = _data.get("texts", {})
	var result: int = GameState.check_purchase(id)
	if result == GameState.PurchaseResult.ALREADY_OWNED:
		return String(texts.get("state_owned", ""))
	if result == GameState.PurchaseResult.NOT_ENOUGH_POINTS:
		return String(texts.get("state_not_enough_points", ""))
	if result == GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS:
		return String(texts.get("state_not_enough_power_banks", ""))
	return String(texts.get("state_available", ""))


func _refresh_save_status() -> void:
	var unsaved: bool = GameState.has_unsaved_changes()
	var key: String = "save_status_unsaved" if unsaved else "save_status_saved"
	_labels[&"save_status"].text = String(_data.get("texts", {}).get(key, ""))
	_set_color(_labels[&"save_status"], String(_data.get("colors", {}).get(key, "#f2f4f8")))


func _on_unsaved_changes_changed(_has_changes: bool) -> void:
	if _shown and is_inside_tree():
		_refresh_save_status()
		_layout()


func _ordered_labels() -> Array[Label]:
	var out: Array[Label] = []
	for key: StringName in HEADER_KEYS:
		out.append(_labels[key])
	out.append_array(_row_labels)
	for key: StringName in FOOTER_KEYS:
		out.append(_labels[key])
	return out


func _new_label(node_name: String, color: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", int(_data.get("font_size", 12)))
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"key_color", _key_color)
	material.set_shader_parameter(&"target_color", Color.html(color))
	label.material = material
	_panel.add_child(label)
	return label


func _set_color(label: Label, color: String) -> void:
	(label.material as ShaderMaterial).set_shader_parameter(&"target_color", Color.html(color))


func _build() -> void:
	var scale_factor: int = maxi(1, int(_data.get("pixel_scale", 2)))
	var colors: Dictionary = _data.get("colors", {})
	_font = load(String(_data["font"])) as Font
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.scale = Vector2.ONE * scale_factor
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color.html(String(colors.get("background", "#0b0e1a")))
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_background)
	_panel = NinePatchRect.new()
	_panel.name = "Panel"
	_panel.texture = load(String(_data["panel"])) as Texture2D
	var margin: int = int(_data.get("panel_margin_px", 3))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, margin)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_panel)
	_shader = load(String(_data["key_swap_shader"])) as Shader
	_key_color = Color.html(String(colors.get("key", "#f2f4f8")))
	for name: StringName in HEADER_KEYS + FOOTER_KEYS:
		_labels[name] = _new_label(String(name).capitalize(), String(colors.get(String(name), "#f2f4f8")))
	for entry: UpgradeCatalog.Entry in UpgradeCatalog.shared().entries():
		_upgrade_ids.append(entry.id)
		var row: Label = _new_label("Upgrade_%s" % entry.id, String(colors.get("upgrade", "#f2f4f8")))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_row_labels.append(row)


func _layout() -> void:
	if _frame == null or not is_inside_tree():
		return
	var scale_factor: float = _frame.scale.x
	var screen: Vector2 = get_viewport().get_visible_rect().size / scale_factor
	_frame.size = screen
	_background.size = screen
	var font_size: int = int(_data.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(font_size))
	var pad: float = float(_data.get("padding_px", 12))
	var gap: float = float(_data.get("line_gap_px", 8))
	var width: float = float(_data.get("panel_width_px", 280))
	for label: Label in _ordered_labels():
		width = maxf(width, ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + pad * 2.0)
	var labels: Array[Label] = _ordered_labels()
	var row_gap: float = float(_data.get("row_gap_px", gap))
	var y: float = pad
	for i: int in labels.size():
		var label: Label = labels[i]
		label.position = Vector2(pad, y)
		label.size = Vector2(width - pad * 2.0, line_h)
		var is_row: bool = _row_labels.has(label)
		var next_is_row: bool = i + 1 < labels.size() and _row_labels.has(labels[i + 1])
		y += line_h + (row_gap if is_row and next_is_row else gap)
		if label == _labels[&"title"] or label == _labels[&"power_banks"] or (is_row and not next_is_row):
			y += gap  # aire extra bajo el titulo, antes y despues de la lista
	var height: float = y - gap + pad
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(maxf(screen.y - height, 0.0) * 0.5))


## Alto del panel en pixeles de arte (pruebas: debe caber en pantalla).
func get_panel_size() -> Vector2:
	return _panel.size


func get_screen_size() -> Vector2:
	return _frame.size
