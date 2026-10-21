## Recompensa de un jefe vencido (paso 10 de docs/propuesta-jefe-alerta-mayor.md
## §6 y paso 5 de docs/propuesta-recuerdos.md §7; 2026-10-21). Compartida por
## los 6 jefes.
## - grant(world, lap): entrega la capa del recuerdo del mundo del acceso actual
##   (boss_w<mundo>_l<capa>, capa = vuelta interna 1-3) y, como RED DE
##   SEGURIDAD, las capas inferiores que falten. GameState.obtain_memory: SIN
##   GUARDAR (un game over la pierde; hay que guardar en Notas). Una revancha no
##   entrega nada (obtain_memory no repite).
## - La escena (CanvasLayer): un panel centrado con la linea del sistema del
##   jefe (p. ej. «Sin notificaciones pendientes.»), «Recuerdo recuperado», el
##   titulo del recuerdo, «Capa: Caché» (nombre del acceso, nunca vuelta), su
##   texto y el aviso del sistema «Guarda en Notas para conservarlo.». Pausa el
##   arbol (si no lo estaba; solo quien pausa quita la pausa) y se cierra con
##   saltar / aceptar (como las lineas importantes) tras min_show_s. No es Eco:
##   es texto del sistema y del recuerdo (sin blip). Emite shown y closed.
## Textos y aspecto en data/boss_reward.json; arte PROVISIONAL (_placeholder) de
## tools/gen_boss_alert_major.py. Tiempo real.
class_name BossReward
extends CanvasLayer

const DATA_PATH: String = "res://data/boss_reward.json"
const CONFIRM_ACTIONS: Array[StringName] = [&"jump", &"ui_accept"]
const MEMORY_ID: String = "boss_w%d_l%d"

## Pruebas: falso = no pausa el arbol (como EcoTextBox.pause_important).
static var pause_tree: bool = true

## Se ve el panel (audio: stg_boss_defeated, y mus_memory mientras esta).
signal shown(memory_id: StringName)
## El jugador lo cerro.
signal closed

var memory_id: StringName = &""
## Linea del sistema del jefe arriba del panel (vacio = ninguna).
var system_line: String = ""

var _cfg: Dictionary = {}
var _paused_by_me: bool = false
var _shown_s: float = 0.0
var _open: bool = false
var _frame: Control
var _labels: Dictionary[StringName, Label] = {}


## Id de la capa `lap` (1-3) del recuerdo del mundo `world`.
static func layer_id(world: int, lap: int) -> StringName:
	return StringName(MEMORY_ID % [world, clampi(lap, 1, 3)])


## Entrega la capa `lap` del recuerdo del mundo `world` y las inferiores que
## falten. Devuelve las que se obtuvieron ahora (vacia en una revancha).
static func grant(world: int, lap: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for layer: int in range(1, clampi(lap, 1, 3) + 1):
		var id: StringName = layer_id(world, layer)
		if MemoryCatalog.shared().has(id) and GameState.obtain_memory(id):
			out.append(id)
	return out


## Crea y muestra la recompensa de `id` como hija de `host`.
static func show_for(id: StringName, host: Node, line: String = "") -> BossReward:
	var reward := BossReward.new()
	reward.name = "BossReward"
	reward.memory_id = id
	reward.system_line = line
	host.add_child(reward)
	return reward


static func load_config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return data if data is Dictionary else {}


func _ready() -> void:
	_cfg = load_config()
	layer = int(_cfg.get("layer", 30))
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(PauseMenu.BLOCKER_GROUP)
	_build()
	_open = true
	if pause_tree and not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	shown.emit(memory_id)


func _exit_tree() -> void:
	_release_pause()


func _process(delta: float) -> void:
	_shown_s += delta
	if _labels.has(&"hint"):
		var hz: float = float(_cfg.get("hint_blink_hz", 2.0))
		_labels[&"hint"].visible = can_close() and int(_shown_s * hz * 2.0) % 2 == 0


func _unhandled_input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	for action: StringName in CONFIRM_ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			if confirm():
				get_viewport().set_input_as_handled()
			return


# --- API ---

func is_open() -> bool:
	return _open


## Ya se puede cerrar (tras min_show_s).
func can_close() -> bool:
	return _open and _shown_s >= float(_cfg.get("min_show_s", 0.6))


## Cierra el panel (accion del jugador). Verdadero si lo cerro.
func confirm() -> bool:
	if not can_close():
		return false
	_open = false
	_release_pause()
	closed.emit()
	queue_free()
	return true


## Avanza `seconds` reales (pruebas).
func advance(seconds: float) -> void:
	_process(seconds)


## Textos visibles, por clave (system, header, title, layer, text, notice).
func get_text(key: StringName) -> String:
	return _labels[key].text if _labels.has(key) else ""


func is_pausing() -> bool:
	return _paused_by_me


func blocks_pause_menu() -> bool:
	return _open


# --- Interno ---

func _release_pause() -> void:
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
	_paused_by_me = false


func _build() -> void:
	var texts: Dictionary = _cfg.get("texts", {})
	var colors: Dictionary = _cfg.get("colors", {})
	var scale_px: float = float(_cfg.get("pixel_scale", 2))
	var width: float = float(_cfg.get("width_px", 300))
	var pad: float = float(_cfg.get("padding_px", 8))
	var font: Font = load(String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var font_size: int = int(_cfg.get("font_size", 12))
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var layer_index: int = clampi(catalog.layer(memory_id), 1, 3)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.scale = Vector2(scale_px, scale_px)
	add_child(_frame)
	var panel := NinePatchRect.new()
	panel.name = "Panel"
	var panel_path: String = String(_cfg.get("panel", ""))
	if ResourceLoader.exists(panel_path):
		panel.texture = load(panel_path) as Texture2D
		var m: int = int(_cfg.get("panel_margin_px", 4))
		panel.patch_margin_left = m
		panel.patch_margin_top = m
		panel.patch_margin_right = m
		panel.patch_margin_bottom = m
	_frame.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", int(_cfg.get("line_gap_px", 3)))
	box.position = Vector2(pad, pad)
	box.size = Vector2(width - pad * 2.0, 0.0)
	_frame.add_child(box)
	var entries: Array = []
	if not system_line.is_empty():
		entries.append([&"system", system_line, "system"])
	entries.append([&"header", String(texts.get("header", "")), "header"])
	entries.append([&"title", catalog.title(memory_id), "title"])
	var access: String = HubWorlds.access_name(layer_index)
	entries.append([&"layer", String(texts.get("layer", "%s")) % access, "dim"])
	entries.append([&"text", catalog.text(memory_id), "body"])
	entries.append([&"notice", String(texts.get("save_notice", "")), "notice"])
	entries.append([&"hint", String(texts.get("confirm_hint", "")), "dim"])
	for entry: Array in entries:
		var label := Label.new()
		label.name = String(entry[0]).capitalize()
		label.text = String(entry[1])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(width - pad * 2.0, 0.0)
		if font != null:
			label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", Color.html(String(colors.get(String(entry[2]), "#f2f4f8"))))
		if entry[0] == &"hint":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elif entry[0] != &"text":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		_labels[entry[0]] = label
	# Alto del panel: lo que ocupa el texto (los Label calculan su alto al entrar).
	var height: float = pad * 2.0
	for label: Label in _labels.values():
		height += label.get_minimum_size().y + float(_cfg.get("line_gap_px", 3))
	var screen: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(width, height)
	_frame.position = ((screen - Vector2(width, height) * scale_px) * 0.5).round()
