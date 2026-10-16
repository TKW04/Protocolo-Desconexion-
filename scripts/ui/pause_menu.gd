## Menu de pausa (2026-10-16; docs/propuesta-hub-y-guardado.md preguntas 6 y 9,
## docs/propuesta-asistentes-y-vidas.md §3.4 y paso 13 de §10). Datos, textos y
## controles en data/pause_menu.json.
## - Se abre con la accion pause (Esc / Start) en los niveles y en el hub; en el
##   hub tambien con el icono de ajustes del HUD (Hud, junto al Modo Avion).
##   Se cierra con pause o «Reanudar».
## - Paginas: principal (Reanudar, Ajustes, [Salir al hub], Cerrar el juego) y
##   Ajustes («Ayudas de Eco: Mostrar / Ocultar», «Reducir efectos de Sync
##   bajo: Si / No», «Contorno del Debug de alto contraste: Si / No», Volver).
##   Los ajustes se guardan al instante (GameSettings, settings.cfg), aparte del
##   guardado de la partida, y se aplican al momento. El detalle explica el
##   ajuste elegido. «Pantalla» abre su subpagina: «Modo: Ventana / Pantalla
##   completa» y «Tamano de ventana» (presets de data/settings.json que caben en
##   el monitor), con el factor de escala entero y si quedan bordes negros en el
##   detalle (GameSettings.apply_display; no se aplica en pruebas ni scripts).
##   «Controles» abre la lista de acciones reasignables (ControlBindings,
##   data/settings.json) con su tecla y su boton de mando; elegir una abre «Pulsa
##   una tecla o boton…» (Esc o Start cancelan; la primera tecla o boton o eje
##   pulsado se asigna). Si ya es de otra accion: «Intercambiar» / «Cancelar».
##   Las entradas reservadas (Esc / Start de la pausa, R / Select, F9, F1-F4) se
##   rechazan con un aviso en el detalle. «Restablecer valores» pide
##   confirmacion. Todo se guarda al instante en settings.cfg.
## - NAVEGACION (2026-10-16): pause (Esc / Start) y back_actions (B) vuelven UNA
##   pagina atras (de una subpagina a la anterior; en la principal, reanudan).
## - «Cerrar el juego» pasa por QuitGuard: con cambios sin guardar sale el mismo
##   aviso que al cerrar la ventana (en el hub, «Guardar y salir»...; en un
##   nivel, «Salir / Volver»); «Volver» deja el menu abierto.
## - «Salir al hub» (2026-10-16, decision del usuario): solo en un nivel ya
##   completado en la partida actual (lo decide hub_exit, el LevelRunner:
##   can_exit_to_hub / request_exit_to_hub). Pide confirmacion («¿Salir al hub?
##   Perderas este intento.», Salir / Volver); Salir cierra el menu (quita su
##   pausa) y el LevelRunner funde y carga el hub con la llegada normal. No
##   aparece en el hub ni en niveles no completados.
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

enum Page { MAIN, SETTINGS, CONFIRM_HUB, DISPLAY, CONTROLS, CAPTURE, CONFLICT, CONFIRM_RESET }
enum Option { RESUME, SETTINGS, QUIT, ECO_HELP, BACK, EXIT_TO_HUB, CONFIRM_EXIT, LOW_SYNC, DEBUG_OUTLINE, DISPLAY, WINDOW_MODE,
	WINDOW_SIZE, CONTROLS, BINDING, RESET_CONTROLS, CONFIRM_RESET, SWAP, CANCEL }

## Interruptores Si / No de Ajustes: opcion -> [clave de GameSettings, clave de texto].
const SWITCHES: Dictionary = {
	Option.LOW_SYNC: [&"reduce_low_sync_effects", "low_sync"],
	Option.DEBUG_OUTLINE: [&"debug_high_contrast_outline", "debug_outline"],
}

signal opened
signal closed

## Aviso al salir que usa «Cerrar el juego» (pruebas). Si es null se usa el de
## GameState (juego normal) y, si no hay ninguno (GUT, scripts), quit_handler o
## get_tree().quit().
var quit_guard: QuitGuard = null
## Funcion que cierra el juego sin QuitGuard (pruebas).
var quit_handler: Callable = Callable()
## Quien ofrece «Salir al hub» (el LevelRunner; null = nunca): debe tener
## can_exit_to_hub() -> bool y request_exit_to_hub() -> bool.
var hub_exit: Object = null
## Segundos reales tras abrir la captura en que se ignora la entrada (la
## pulsacion que la abrio; las pruebas lo ponen a 0).
var capture_arm_s: float = ControlBindings.capture_arm_s()

var _data: Dictionary = {}
var _open: bool = false
var _owns_pause: bool = false
var _page: Page = Page.MAIN
var _options: Array[Option] = []
## Accion de cada opcion BINDING (paralela a _options).
var _option_actions: Array[StringName] = []
## Accion que se esta reasignando (captura y conflicto).
var _capture_action: StringName = &""
var _capture_started_ms: int = 0
## Entrada capturada que choca con otra accion (pagina CONFLICT).
var _pending_event: InputEvent
var _conflict: Dictionary = {}
## Aviso de una sola vez en el detalle de Controles (reservada, cancelada...).
var _notice: String = ""
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


## La captura de una tecla o boton va antes que nadie (las demas acciones no
## reaccionan a la entrada que se esta asignando).
func _input(event: InputEvent) -> void:
	if not _open or _page != Page.CAPTURE or _quit_prompt_open():
		return
	if handle_capture(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or _quit_prompt_open():
		return
	if not _open:
		if _matches_action(event, StringName(String(_data.get("pause_action", "pause")))) and request_open():
			get_viewport().set_input_as_handled()
		return
	if _page == Page.CAPTURE:
		# La captura la lleva _input (teclas, botones y ejes); el resto se ignora.
		return
	if _matches_action(event, StringName(String(_data.get("pause_action", "pause")))):
		go_back()
	elif _matches(event, "up_actions"):
		move_selection(-1)
	elif _matches(event, "down_actions"):
		move_selection(1)
	elif _matches(event, "left_actions") or _matches(event, "right_actions"):
		var step: int = -1 if _matches(event, "left_actions") else 1
		if get_selected_option() == Option.WINDOW_SIZE:
			cycle_window_size(step)
		elif is_switch(get_selected_option()):
			activate(get_selected_option())
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
	_notice = ""
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
		Option.LOW_SYNC, Option.DEBUG_OUTLINE:
			var key: StringName = SWITCHES[option][0]
			GameSettings.set_bool(key, not GameSettings.get_bool(key))
			_refresh()
		Option.BACK:
			go_back()
		Option.DISPLAY:
			_show_page(Page.DISPLAY)
		Option.WINDOW_MODE:
			GameSettings.set_fullscreen(not GameSettings.is_fullscreen())
			_refresh()
		Option.WINDOW_SIZE:
			cycle_window_size(1)
		Option.CONTROLS:
			_show_page(Page.CONTROLS)
		Option.BINDING:
			begin_capture(get_selected_action())
		Option.RESET_CONTROLS:
			_show_page(Page.CONFIRM_RESET)
		Option.CONFIRM_RESET:
			ControlBindings.restore_defaults()
			_show_page(Page.CONTROLS)
			select(Option.RESET_CONTROLS)
			_notice = _text("controls_reset_done")
			_refresh()
		Option.SWAP:
			_finish_conflict(true)
		Option.CANCEL:
			go_back()
		Option.EXIT_TO_HUB:
			if can_exit_to_hub():
				_show_page(Page.CONFIRM_HUB)
		Option.CONFIRM_EXIT:
			confirm_exit_to_hub()


## La opcion es un ajuste que se cambia con izquierda/derecha o aceptar.
func is_switch(option: Option) -> bool:
	return option == Option.ECO_HELP or option == Option.WINDOW_MODE or SWITCHES.has(option)


## Pasa al tamano de ventana siguiente (`step` 1) o anterior (-1) de los que
## caben en el monitor.
func cycle_window_size(step: int) -> void:
	var sizes: Array[Vector2i] = GameSettings.available_presets(GameSettings.screen_size())
	if sizes.is_empty():
		return
	var index: int = sizes.find(GameSettings.get_window_size())
	index = posmod((index if index >= 0 else 0) + step, sizes.size())
	GameSettings.set_window_size(sizes[index])
	_refresh()


## Atras: una pagina (de Ajustes o de la confirmacion a la principal); en la
## principal, reanuda.
func go_back() -> void:
	match _page:
		Page.SETTINGS:
			_show_page(Page.MAIN)
			select(Option.SETTINGS)
		Page.CONFIRM_HUB:
			_show_page(Page.MAIN)
			select(Option.EXIT_TO_HUB)
		Page.DISPLAY:
			_show_page(Page.SETTINGS)
			select(Option.DISPLAY)
		Page.CONTROLS:
			_show_page(Page.SETTINGS)
			select(Option.CONTROLS)
		Page.CAPTURE, Page.CONFLICT:
			_back_to_controls(_capture_action, _text("capture_cancelled"))
		Page.CONFIRM_RESET:
			_show_page(Page.CONTROLS)
			select(Option.RESET_CONTROLS)
		_:
			close()


# --- Controles ---

## Accion de la fila elegida en Controles (&"" si no es una fila de accion).
func get_selected_action() -> StringName:
	return _option_actions[_selected] if _selected < _option_actions.size() else &""


## Elige la fila de `action` en Controles.
func select_action(action: StringName) -> bool:
	var index: int = _option_actions.find(action)
	if index < 0 or _options[index] != Option.BINDING:
		return false
	_selected = index
	_refresh()
	return true


## Accion que se esta reasignando.
func get_capture_action() -> StringName:
	return _capture_action


## Aviso actual del detalle de Controles.
func get_notice() -> String:
	return _notice


## Abre «Pulsa una tecla o boton…» para `action`.
func begin_capture(action: StringName) -> void:
	if not ControlBindings.is_remappable(action):
		return
	_capture_action = action
	_capture_started_ms = Time.get_ticks_msec()
	_show_page(Page.CAPTURE)


## Trata una entrada durante la captura: Esc / Start cancelan; una tecla, un
## boton o un eje se asignan (o abren el conflicto). Verdadero si la consumio.
func handle_capture(event: InputEvent) -> bool:
	if _page != Page.CAPTURE:
		return false
	if event is InputEventMouse or event is InputEventAction:
		return false
	if Time.get_ticks_msec() - _capture_started_ms < int(capture_arm_s * 1000.0):
		return true
	if ControlBindings.is_cancel(event):
		if (event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo()) \
				or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed):
			go_back()
		return true
	var captured: InputEvent = ControlBindings.capture_from(event)
	if captured == null:
		return true
	var result: ControlBindings.Result = ControlBindings.assign(_capture_action, captured)
	match result:
		ControlBindings.Result.CONFLICT:
			_pending_event = captured
			_conflict = ControlBindings.find_conflict(captured, _capture_action)
			_show_page(Page.CONFLICT)
		ControlBindings.Result.RESERVED:
			_back_to_controls(_capture_action, _text("controls_reserved").replace("{input}",
				ControlBindings.input_label(captured, _font)))
		ControlBindings.Result.BLOCKED:
			_back_to_controls(_capture_action, _text("controls_blocked"))
		_:
			_back_to_controls(_capture_action, "")
	return true


## Conflicto: intercambiar (`swap`) o cancelar.
func _finish_conflict(swap: bool) -> void:
	var action: StringName = _capture_action
	if swap and _pending_event != null:
		var result: ControlBindings.Result = ControlBindings.assign(action, _pending_event, true)
		_back_to_controls(action, "" if result == ControlBindings.Result.OK else _text("controls_blocked"))
	else:
		_back_to_controls(action, _text("capture_cancelled"))
	_pending_event = null
	_conflict = {}


func _back_to_controls(action: StringName, notice: String) -> void:
	_show_page(Page.CONTROLS)
	select_action(action)
	_notice = notice
	_refresh()


## Accion con la que choca la entrada capturada (pagina CONFLICT).
func get_conflict_action() -> StringName:
	return StringName(_conflict.get("action", &""))


## Se ofrece «Salir al hub» ahora (nivel completado en la partida actual).
func can_exit_to_hub() -> bool:
	return hub_exit != null and is_instance_valid(hub_exit) and hub_exit.has_method(&"can_exit_to_hub") \
		and bool(hub_exit.call(&"can_exit_to_hub"))


## «Salir» en la confirmacion: cierra el menu (quita su pausa) y pide al
## LevelRunner que vuelva al hub. Falso si ya no se puede.
func confirm_exit_to_hub() -> bool:
	if not can_exit_to_hub():
		_show_page(Page.MAIN)
		return false
	close()
	return bool(hub_exit.call(&"request_exit_to_hub"))


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
		Option.EXIT_TO_HUB:
			return _text("exit_to_hub")
		Option.CONFIRM_EXIT:
			return _text("exit_to_hub_confirm")
		Option.ECO_HELP:
			var value: String = _text("eco_help_shown" if GameSettings.is_eco_help_shown() else "eco_help_hidden")
			return _text("eco_help").replace("{value}", value)
		Option.LOW_SYNC, Option.DEBUG_OUTLINE:
			var on: bool = GameSettings.get_bool(SWITCHES[option][0])
			return _text(String(SWITCHES[option][1])).replace("{value}", _text("yes" if on else "no"))
		Option.DISPLAY:
			return _text("display")
		Option.CONTROLS:
			return _text("controls")
		Option.RESET_CONTROLS:
			return _text("controls_reset")
		Option.CONFIRM_RESET:
			return _text("controls_reset_confirm")
		Option.SWAP:
			return _text("conflict_swap")
		Option.CANCEL:
			return _text("conflict_cancel")
		Option.WINDOW_MODE:
			return _text("window_mode").replace("{value}",
				_text("window_mode_fullscreen" if GameSettings.is_fullscreen() else "window_mode_windowed"))
		Option.WINDOW_SIZE:
			return _text("window_size").replace("{value}", size_text(GameSettings.get_window_size()))
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
	_selected = 0
	_option_actions.clear()
	_notice = ""
	match page:
		Page.MAIN:
			_options = [Option.RESUME, Option.SETTINGS]
			if can_exit_to_hub():
				_options.append(Option.EXIT_TO_HUB)
			_options.append(Option.QUIT)
		Page.DISPLAY:
			_options = [Option.WINDOW_MODE, Option.WINDOW_SIZE, Option.BACK]
		Page.CONTROLS:
			_options = []
			for action: StringName in ControlBindings.actions():
				_options.append(Option.BINDING)
				_option_actions.append(action)
			_options.append_array([Option.RESET_CONTROLS, Option.BACK])
		Page.CAPTURE:
			_options = []
		Page.CONFLICT:
			_options = [Option.SWAP, Option.CANCEL]
			_selected = 1
		Page.CONFIRM_RESET:
			_options = [Option.CONFIRM_RESET, Option.BACK]
			_selected = 1
		Page.CONFIRM_HUB:
			_options = [Option.CONFIRM_EXIT, Option.BACK]
			# Por seguridad empieza en «Volver».
			_selected = 1
		_:
			_options = [Option.ECO_HELP, Option.LOW_SYNC, Option.DEBUG_OUTLINE, Option.DISPLAY,
				Option.CONTROLS, Option.BACK]
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
	_title.text = _text(_page_title_key())
	while _option_labels.size() < _options.size():
		_option_labels.append(_new_label("Option_%d" % _option_labels.size(), _color("option")))
	for i: int in _option_labels.size():
		var label: Label = _option_labels[i]
		if i >= _options.size():
			label.text = ""
			continue
		var prefix: String = _text("selected_prefix" if i == _selected else "unselected_prefix")
		label.text = prefix + _option_text_at(i)
		_set_color(label, _color("option_selected" if i == _selected else "option"))
	match _page:
		Page.SETTINGS, Page.DISPLAY:
			_detail.text = _option_detail(get_selected_option())
		Page.CONTROLS:
			if not _notice.is_empty():
				_detail.text = _notice
			elif get_selected_option() == Option.RESET_CONTROLS:
				_detail.text = _text("controls_reset_detail")
			elif get_selected_option() == Option.BINDING:
				_detail.text = _text("controls_detail")
			else:
				_detail.text = ""
		Page.CAPTURE:
			_detail.text = ControlBindings.action_name(_capture_action)
		Page.CONFLICT:
			_detail.text = _text("conflict_detail").replace("{input}",
				ControlBindings.input_label(_pending_event, _font)).replace("{action}",
				ControlBindings.action_name(get_conflict_action()))
		Page.CONFIRM_RESET:
			_detail.text = _text("controls_reset_confirm_detail")
		Page.CONFIRM_HUB:
			_detail.text = _text("exit_to_hub_detail")
		_:
			_detail.text = ""
	_help.text = _text(_page_help_key())
	_layout()


## Texto de la opcion `index` de la pagina actual (las filas de Controles:
## «Saltar: Espacio / A»).
func _option_text_at(index: int) -> String:
	if _options[index] == Option.BINDING and index < _option_actions.size():
		var action: StringName = _option_actions[index]
		return _text("binding").replace("{action}", ControlBindings.action_name(action)).replace("{inputs}",
			ControlBindings.binding_label(action, _font))
	return option_text(_options[index])


## Detalle de un ajuste de la pagina Ajustes (segun su valor).
func _option_detail(option: Option) -> String:
	match option:
		Option.ECO_HELP:
			return _text("eco_help_detail_shown" if GameSettings.is_eco_help_shown() else "eco_help_detail_hidden")
		Option.LOW_SYNC, Option.DEBUG_OUTLINE:
			var on: bool = GameSettings.get_bool(SWITCHES[option][0])
			return _text("%s_detail_%s" % [SWITCHES[option][1], "yes" if on else "no"])
		Option.DISPLAY:
			return _text("display_detail")
		Option.CONTROLS:
			return _text("controls_settings_detail")
		Option.WINDOW_MODE, Option.WINDOW_SIZE:
			if option == Option.WINDOW_SIZE and GameSettings.is_fullscreen():
				return _text("window_size_detail_fullscreen")
			return scale_text(display_area())
	return ""


## Area en que se dibuja el juego con los ajustes actuales: la pantalla en
## pantalla completa (o la ventana si no se conoce) o el tamano de la ventana.
func display_area() -> Vector2i:
	var screen: Vector2i = GameSettings.screen_size()
	if GameSettings.is_fullscreen() and screen.x > 0:
		return screen
	return GameSettings.get_window_size()


## «1600x900».
func size_text(size: Vector2i) -> String:
	return _text("size_format").replace("{w}", str(size.x)).replace("{h}", str(size.y))


## Factor entero y bordes del juego en `area` («Pixeles a x1, con bordes negros.»).
func scale_text(area: Vector2i) -> String:
	var key: String = "scale_detail_letterbox" if GameSettings.has_letterbox(area) else "scale_detail_exact"
	return _text(key).replace("{scale}", str(GameSettings.integer_scale(area)))


func _page_title_key() -> String:
	match _page:
		Page.SETTINGS:
			return "title_settings"
		Page.CONFIRM_HUB:
			return "title_exit_to_hub"
		Page.DISPLAY:
			return "title_display"
		Page.CONTROLS:
			return "title_controls"
		Page.CAPTURE:
			return "title_capture"
		Page.CONFLICT:
			return "title_conflict"
		Page.CONFIRM_RESET:
			return "title_reset"
	return "title_main"


func _page_help_key() -> String:
	match _page:
		Page.SETTINGS, Page.DISPLAY:
			return "help_settings"
		Page.CONFIRM_HUB, Page.CONFLICT, Page.CONFIRM_RESET:
			return "help_confirm"
		Page.CONTROLS:
			return "help_controls"
		Page.CAPTURE:
			return "help_capture"
	return "help_main"


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
