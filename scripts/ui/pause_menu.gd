## Menu de pausa (2026-10-16; docs/propuesta-hub-y-guardado.md preguntas 6 y 9,
## docs/propuesta-asistentes-y-vidas.md §3.4 y paso 13 de §10). Datos, textos y
## controles en data/pause_menu.json.
## - Se abre con la accion pause (Esc / Start) en los niveles y en el hub; en el
##   hub tambien con el icono de ajustes del HUD (Hud, junto al Modo Avion).
##   Se cierra con pause o «Reanudar».
## - Paginas: principal (Reanudar, Ajustes, Cerrar el juego) y Ajustes («Ayudas
##   de Eco: Mostrar / Ocultar», Volver). El ajuste se guarda al instante
##   (GameSettings, settings.cfg), aparte del guardado de la partida.
## - «Cerrar el juego» pasa por QuitGuard: con cambios sin guardar sale el mismo
##   aviso que al cerrar la ventana (en el hub, «Guardar y salir»...; en un
##   nivel, «Salir / Volver»); «Volver» deja el menu abierto.
## - Sin «Salir al hub»: el documento no lo define (duda en docs/preguntas.md).
## PAUSAS ANIDADAS (convencion del proyecto; la siguen EcoTextBox,
## NicknameEntry, EcoEncounter, NotasIntro, GameOverIntro y este menu): quien
## quiere pausar solo pone get_tree().paused si el arbol NO estaba en pausa, y
## entonces es su dueno (_owns_pause); solo el dueno la quita, al cerrarse y
## siempre al salir del arbol. QuitGuard es la excepcion: se pone encima de
## cualquiera y deja la pausa como estaba. Por eso este menu NO se abre con el
## arbol en pausa (linea importante de Eco, ayuda con Q, entrada del apodo,
## presentaciones del hub, aviso al salir) ni nunca pisa ni quita la pausa de
## otro. Tampoco se abre mientras un nodo del grupo BLOCKER_GROUP devuelva
## verdadero en blocks_pause_menu(): LevelRunner (fundidos, muerte, game over,
## vortices), HubRoom (llegada, salida, paneles de estacion abiertos) y
## EcoTextBox (con una linea en pantalla o en cola).
## Con el arbol en pausa no avanzan el mundo, los temporizadores ni
## GameState.play_time_s (todos son pausables); el menu procesa siempre.
## El nodo vive siempre en el arbol (oculto si esta cerrado): lo crea LevelRunner
## (niveles y hub del flujo del juego) o HubRoom si se abre solo.
class_name PauseMenu
extends CanvasLayer

const DATA_PATH: String = "res://data/pause_menu.json"
## Grupo del menu (el icono del HUD lo busca aqui).
const GROUP: StringName = &"pause_menu"
## Grupo de los nodos que pueden impedir abrirlo (blocks_pause_menu()).
const BLOCKER_GROUP: StringName = &"pause_menu_blocker"

enum Page { MAIN, SETTINGS }
enum Option { RESUME, SETTINGS, QUIT, ECO_HELP, BACK }

signal opened
signal closed

## Aviso al salir que usa «Cerrar el juego» (pruebas). Si es null se usa el de
## GameState (juego normal) y, si no hay ninguno (GUT, scripts), quit_handler o
## get_tree().quit().
var quit_guard: QuitGuard = null
## Funcion que cierra el juego sin QuitGuard (pruebas).
var quit_handler: Callable = Callable()

var _data: Dictionary = {}
var _open: bool = false
var _owns_pause: bool = false
var _page: Page = Page.MAIN
var _options: Array[Option] = []
var _selected: int = 0
var _font: Font
var _shader: Shader
var _key_color: Color
var _frame: Control
var _backdrop: ColorRect
var _panel: NinePatchRect
var _title: Label
var _detail: Label
var _help: Label
var _option_labels: Array[Label] = []


func _init() -> void:
	name = "PauseMenu"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_data = load_data()
	layer = int(_data.get("layer", 40))
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)


func _exit_tree() -> void:
	# Cambio de escena o nodo quitado: nunca deja el arbol en pausa.
	_open = false
	_release_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or _quit_prompt_open():
		return
	if not _open:
		if _matches_action(event, StringName(String(_data.get("pause_action", "pause")))) and request_open():
			get_viewport().set_input_as_handled()
		return
	if _matches_action(event, StringName(String(_data.get("pause_action", "pause")))):
		close()
	elif _matches(event, "up_actions"):
		move_selection(-1)
	elif _matches(event, "down_actions"):
		move_selection(1)
	elif _matches(event, "left_actions") or _matches(event, "right_actions"):
		if get_selected_option() == Option.ECO_HELP:
			activate(Option.ECO_HELP)
	elif _matches(event, "confirm_actions"):
		activate(get_selected_option())
	elif _matches(event, "back_actions"):
		go_back()
	else:
		return
	get_viewport().set_input_as_handled()


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Menu de pausa del arbol (null si no hay).
static func find_in(tree: SceneTree) -> PauseMenu:
	return tree.get_first_node_in_group(GROUP) as PauseMenu if tree != null else null


## Algun nodo del grupo BLOCKER_GROUP impide abrir el menu ahora.
static func is_blocked(tree: SceneTree) -> bool:
	if tree == null:
		return true
	for node: Node in tree.get_nodes_in_group(BLOCKER_GROUP):
		if node.has_method(&"blocks_pause_menu") and bool(node.call(&"blocks_pause_menu")):
			return true
	return false


# --- API ---

func is_open() -> bool:
	return _open


## El menu puso la pausa del arbol (y la quitara al cerrarse).
func owns_pause() -> bool:
	return _owns_pause


## Se puede abrir ahora: cerrado, en el arbol, sin pausa de otro, sin el aviso
## al salir y sin nada que lo impida (BLOCKER_GROUP).
func can_open() -> bool:
	return not _open and is_inside_tree() and not get_tree().paused and not _quit_prompt_open() \
		and not is_blocked(get_tree())


## Abre el menu en la pagina principal si can_open(). Verdadero si se abrio.
func request_open() -> bool:
	if not can_open():
		return false
	_open = true
	_hold_pause()
	_show_page(Page.MAIN)
	visible = true
	opened.emit()
	EventBus.pause_menu_opened.emit()
	return true


## Cierra el menu (reanuda: quita la pausa si era suya).
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_release_pause()
	closed.emit()
	EventBus.pause_menu_closed.emit()


func get_page() -> Page:
	return _page


func get_options() -> Array[Option]:
	return _options.duplicate()


func get_selected_option() -> Option:
	return _options[_selected] if not _options.is_empty() else Option.RESUME


func select(option: Option) -> bool:
	var index: int = _options.find(option)
	if index < 0:
		return false
	_selected = index
	_refresh()
	return true


func move_selection(step: int) -> void:
	if _options.is_empty():
		return
	_selected = posmod(_selected + step, _options.size())
	_refresh()


## Acepta `option` (de la pagina actual).
func activate(option: Option) -> void:
	if not _open:
		return
	match option:
		Option.RESUME:
			close()
		Option.SETTINGS:
			_show_page(Page.SETTINGS)
		Option.QUIT:
			request_quit()
		Option.ECO_HELP:
			GameSettings.set_eco_help_shown(not GameSettings.is_eco_help_shown())
			_refresh()
		Option.BACK:
			go_back()


## Atras: de Ajustes a la pagina principal; en la principal, reanuda.
func go_back() -> void:
	if _page == Page.SETTINGS:
		_show_page(Page.MAIN)
		select(Option.SETTINGS)
	else:
		close()


## «Cerrar el juego»: con QuitGuard, su decision (aviso si hay cambios sin
## guardar); sin el (GUT, scripts), quit_handler o get_tree().quit().
func request_quit() -> void:
	var guard: QuitGuard = quit_guard if quit_guard != null else GameState.get_quit_guard()
	if guard != null:
		guard.handle_close_request()
	elif quit_handler.is_valid():
		quit_handler.call()
	else:
		get_tree().quit()


## Lineas visibles (titulo, opciones, detalle y ayuda), para pruebas.
func get_lines() -> PackedStringArray:
	var out: PackedStringArray = [_title.text]
	for i: int in _options.size():
		out.append(_option_labels[i].text)
	out.append(_detail.text)
	out.append(_help.text)
	return out


## Texto de una opcion (sin prefijo de seleccion).
func option_text(option: Option) -> String:
	match option:
		Option.RESUME:
			return _text("resume")
		Option.SETTINGS:
			return _text("settings")
		Option.QUIT:
			return _text("quit")
		Option.ECO_HELP:
			var value: String = _text("eco_help_shown" if GameSettings.is_eco_help_shown() else "eco_help_hidden")
			return _text("eco_help").replace("{value}", value)
	return _text("back")


## Todos los textos del menu (pruebas: ninguno dice vuelta ni la dificultad).
func get_all_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for value: Variant in _data.get("texts", {}).values():
		out.append(String(value))
	return out


func get_panel_rect() -> Rect2:
	return Rect2(_panel.global_position * _frame.scale.x, _panel.size * _frame.scale.x)


# --- Interno ---

func _hold_pause() -> void:
	if _owns_pause or not is_inside_tree() or get_tree().paused:
		return
	get_tree().paused = true
	_owns_pause = true


func _release_pause() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	if is_inside_tree():
		get_tree().paused = false


func _quit_prompt_open() -> bool:
	var guard: QuitGuard = quit_guard if quit_guard != null else GameState.get_quit_guard()
	return guard != null and guard.is_prompt_open()


func _show_page(page: Page) -> void:
	_page = page
	if page == Page.MAIN:
		_options = [Option.RESUME, Option.SETTINGS, Option.QUIT]
	else:
		_options = [Option.ECO_HELP, Option.BACK]
	_selected = 0
	_refresh()


func _matches_action(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, false, true)


func _matches(event: InputEvent, key: String) -> bool:
	for action: Variant in _data.get(key, []):
		if _matches_action(event, StringName(String(action))):
			return true
	return false


func _text(key: String) -> String:
	return String(_data.get("texts", {}).get(key, ""))


func _color(key: String) -> Color:
	return Color.html(String(_data.get("colors", {}).get(key, "#f2f4f8")))


func _refresh() -> void:
	if _title == null:
		return
	_title.text = _text("title_main" if _page == Page.MAIN else "title_settings")
	while _option_labels.size() < _options.size():
		_option_labels.append(_new_label("Option_%d" % _option_labels.size(), _color("option")))
	for i: int in _option_labels.size():
		var label: Label = _option_labels[i]
		if i >= _options.size():
			label.text = ""
			continue
		var prefix: String = _text("selected_prefix" if i == _selected else "unselected_prefix")
		label.text = prefix + option_text(_options[i])
		_set_color(label, _color("option_selected" if i == _selected else "option"))
	if _page == Page.SETTINGS:
		_detail.text = _text("eco_help_detail_shown" if GameSettings.is_eco_help_shown() else "eco_help_detail_hidden")
	else:
		_detail.text = ""
	_help.text = _text("help_main" if _page == Page.MAIN else "help_settings")
	_layout()


func _new_label(node_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override(&"font", _font)
	label.add_theme_font_size_override(&"font_size", int(_data.get("font_size", 12)))
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"key_color", _key_color)
	material.set_shader_parameter(&"target_color", color)
	label.material = material
	_panel.add_child(label)
	return label


func _set_color(label: Label, color: Color) -> void:
	(label.material as ShaderMaterial).set_shader_parameter(&"target_color", color)


func _build() -> void:
	_font = load(String(_data["font"])) as Font
	_shader = load(String(_data["key_swap_shader"])) as Shader
	_key_color = _color("key")
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.scale = Vector2.ONE * maxi(1, int(_data.get("pixel_scale", 2)))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(_color("backdrop"), float(_data.get("backdrop_alpha", 0.75)))
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_child(_backdrop)
	_panel = NinePatchRect.new()
	_panel.name = "Panel"
	_panel.texture = load(String(_data["panel"])) as Texture2D
	var margin: int = int(_data.get("panel_margin_px", 3))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, margin)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_panel)
	_title = _new_label("Title", _color("title"))
	_detail = _new_label("Detail", _color("detail"))
	_help = _new_label("Help", _color("help"))
	_show_page(Page.MAIN)


func _ordered_labels() -> Array[Label]:
	var out: Array[Label] = [_title]
	for i: int in _options.size():
		out.append(_option_labels[i])
	out.append(_detail)
	out.append(_help)
	return out


func _layout() -> void:
	if _frame == null or not is_inside_tree():
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size / _frame.scale.x
	_frame.size = screen
	_backdrop.size = screen
	var font_size: int = int(_data.get("font_size", 12))
	var line_h: float = ceilf(_font.get_height(font_size))
	var pad: float = float(_data.get("padding_px", 12))
	var gap: float = float(_data.get("line_gap_px", 6))
	var width: float = float(_data.get("panel_width_px", 240))
	for label: Label in _ordered_labels():
		width = maxf(width, ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + pad * 2.0)
	for i: int in range(_options.size(), _option_labels.size()):
		_option_labels[i].visible = false
	var last_option: Label = _option_labels[_options.size() - 1] if not _options.is_empty() else null
	var y: float = pad
	for label: Label in _ordered_labels():
		label.visible = not label.text.is_empty()
		if not label.visible:
			continue
		label.position = Vector2(pad, y)
		label.size = Vector2(width - pad * 2.0, line_h)
		y += line_h + gap
		if label == _title or label == last_option:
			y += gap
	var height: float = y - gap + pad
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(floorf((screen.x - width) * 0.5), floorf(maxf(screen.y - height, 0.0) * 0.5))
