## Cuadro de texto de Eco (PROPUESTA V6, docs/preguntas.md): una notificacion
## arriba, debajo de la barra de estado del HUD, con la esfera de Eco, su
## nombre y el texto. Las lineas normales no pausan el juego ni leen entradas:
## Isak sigue jugando.
## Lineas IMPORTANTES (habilidad adquirida, historia; decision 2026-10-15):
## pausan el arbol (get_tree().paused; el cuadro procesa siempre) y, escritas,
## esperan a que el jugador confirme (CONFIRM_ACTIONS o confirm()); la primera
## pulsacion durante la escritura la completa. Pasan delante de las normales
## en cola (y desplazan la normal en pantalla, que vuelve a la cola) sin
## perder ninguna. El arbol se reanuda al cerrarse la ultima importante y
## siempre al salir el cuadro del arbol (cambio de escena, nivel quitado).
## - Maquina de escribir discreta (chars_per_second de data/eco_text_box.json).
## - El texto se parte por palabras al ancho util del panel (fuente bitmap de
##   textos, con tildes y ene) y el panel crece con las lineas.
## - Al terminar de escribirse queda hold_time() segundos y se cierra solo.
## - Lineas importantes ya escritas: indicacion parpadeante de la tecla que las
##   cierra ("▼ [Espacio]", confirm_hint_text) en la esquina inferior derecha;
##   el cuadro reserva esa fila desde que empieza la linea (no salta al acabar).
## - Tiempo REAL: el Debug ralentiza el mundo (GameState.world_time_scale), no
##   este cuadro, y no se usa Engine.time_scale.
## Entrada: EventBus.eco_line_requested (o show_line()). Si llega otra linea
## con una en pantalla, se pone en cola (las importantes, delante). Salida: EventBus.eco_line_started y
## EventBus.eco_line_finished.
## OTROS QUE HABLAN (2026-10-16): show_line(..., speaker) con un id de speakers
## de data/eco_text_box.json (hoy "notas", en la presentacion de Notas del hub)
## cambia nombre, icono y color del nombre para esa linea. Las lineas de otros
## no emiten EventBus.eco_line_started / eco_line_finished (Eco no las «dice»);
## todas emiten las senales propias line_started / line_finished.
## MARCADORES (2026-10-17, tanda H1 del paso 14 del 1-2; TextMarkers): {apodo}
## al encolar; {puntos} (saldo actual de puntos de atencion) e {icono:<id>} al
## empezar a escribirse la linea. El icono en linea es un glifo de la fuente con
## su ancho (inline_icons de data/eco_text_box.json) sobre el que el cuadro pone
## el sprite (TextureRect hijo de Body), alineado con la altura de las
## mayusculas; sale cuando la maquina de escribir llega a el. Igual en el hub
## (misma escena).
## ESTILO POR INTERLOCUTOR (2026-10-17, tanda H3 del paso 14 del 1-2): la
## entrada de speakers puede llevar `style` (speaker_styles de
## data/eco_text_box.json): otra fuente con las mismas metricas, otro panel,
## color del texto y de la indicacion de cierre, velocidad de escritura y
## caracteres que aparecen de golpe (instant_chars: una racha seguida, p. ej. las
## cifras de un numero, se escribe en un solo paso). Calc usa "lcd" (pantalla de
## calculadora: fuente monoespaciada, cifras de golpe). Sin estilo = el de Eco.
## Pixel base como el HUD: Frame se maqueta en pixeles de arte y se escala
## x pixel_scale (entero).
class_name EcoTextBox
extends CanvasLayer

enum Phase { IDLE, TYPING, HOLD, CLOSING }

const PANEL_ASSET: StringName = &"panel"
const ICON_ASSET: StringName = &"icon"
const LINE_BREAK: String = "\n"
const WORD_SEPARATOR: String = " "
const OPAQUE: float = 1.0
const TRANSPARENT: float = 0.0
## Modulacion neutra: el color sale de la fuente (banner_blanco) o del shader.
const NEUTRAL_MODULATE: Color = Color.WHITE
## Acciones que cierran una linea importante (Espacio / A del mando e Intro).
const CONFIRM_ACTIONS: Array[StringName] = [&"jump", &"ui_accept"]
## Parpadeo de la indicacion de cierre: fraccion del ciclo en que se ve.
const HINT_ON_FRACTION: float = 0.5

## Si es false, las lineas importantes no pausan ni esperan confirmacion (se
## cierran solas como las normales; conservan la prioridad en la cola). Solo
## para pruebas y herramientas que juegan el nivel sin jugador.
static var pause_important: bool = true

## Empieza una linea de `speaker` (vacio = Eco).
signal line_started(text: String, speaker: StringName)
## Se cerro una linea de `speaker` (vacio = Eco).
signal line_finished(speaker: StringName)

var _config: EcoTextBoxConfig = EcoTextBoxConfig.shared()
var _font: Font
var _phase: Phase = Phase.IDLE
## Lineas pendientes: {text, duration_s, important}; las importantes, delante.
var _queue: Array[Dictionary] = []
var _text: String = ""
## Texto ya partido en lineas, unido con saltos de linea (misma longitud que
## _text salvo si se corto una palabra mas ancha que el panel).
var _wrapped: String = ""
var _lines: PackedStringArray = []
var _typed: int = 0
var _type_time: float = 0.0
var _hold_s: float = 0.0
var _hold_left: float = 0.0
var _close_time: float = 0.0
var _important: bool = false
var _current_duration: float = -1.0
## El cuadro puso get_tree().paused (solo entonces lo quita).
var _owns_pause: bool = false
## Tiempo (real) desde que se ve la indicacion de cierre (para el parpadeo).
var _hint_time: float = 0.0
var _hint: Label
## Quien dice la linea actual (vacio = Eco).
var _speaker_id: StringName = &""
## La linea en pantalla va arriba aunque haya un jefe (show_line con `top`).
var _force_top: bool = false
## Iconos en linea de la linea actual: {node: TextureRect, index: posicion en _wrapped, id}.
var _inline: Array[Dictionary] = []
## Estilo de la linea actual (vacio = Eco), su velocidad y sus caracteres de golpe.
var _style_id: StringName = &""
var _cps: float = 40.0
var _instant: String = ""
## Caracteres escritos tras cada paso de la maquina de escribir (vacio: uno por paso).
var _steps: PackedInt32Array = []
## Fuentes ya cargadas por ruta (vacia = la de Eco).
var _fonts: Dictionary[String, Font] = {}
var _body_material: ShaderMaterial

@onready var _frame: Control = $Frame
@onready var _panel: NinePatchRect = $Frame/Panel
@onready var _icon: TextureRect = $Frame/Panel/Icon
@onready var _speaker: Label = $Frame/Panel/Speaker
@onready var _body: Label = $Frame/Panel/Body


func _ready() -> void:
	layer = _config.layer
	# Sigue escribiendo y leyendo la confirmacion con el arbol en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_config()
	get_viewport().size_changed.connect(_fit_frame)
	EventBus.eco_line_requested.connect(_on_eco_line_requested)
	add_to_group(PauseMenu.BLOCKER_GROUP)
	_set_alpha(TRANSPARENT)
	_panel.visible = false


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _important or event.is_echo():
		return
	for action: StringName in CONFIRM_ACTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			if confirm():
				get_viewport().set_input_as_handled()
			return


func _exit_tree() -> void:
	_release_pause()


# --- API ---

## Muestra `text` (o lo pone en cola). `duration_s` <= 0: tiempo por defecto.
## `important`: pausa el juego y espera confirmacion; pasa delante de las
## normales (la normal en pantalla vuelve a la cola, a la cabeza de las normales).
## El marcador {apodo} (GameState.NICKNAME_TAG) se sustituye por el apodo.
## `speaker`: id de speakers de data/eco_text_box.json (vacio = Eco).
## `top`: arriba aunque haya un jefe activo (una pista que no debe tapar lo que
## explica abajo; fase 2 de La Curadora, 2026-10-27).
func show_line(text: String, duration_s: float = -1.0, important: bool = false, speaker: StringName = &"",
		top: bool = false) -> void:
	text = GameState.apply_nickname(text)
	var item: Dictionary = {"text": text, "duration_s": duration_s, "important": important, "speaker": speaker,
		"top": top}
	if not important:
		_queue.append(item)
	else:
		_queue.insert(_first_normal_index(), item)
		if _phase != Phase.IDLE and not _important:
			_preempt_current()
	if _phase == Phase.IDLE:
		_start_next()


## Cierra la linea importante en pantalla (accion del jugador). Si aun se esta
## escribiendo, la completa. Verdadero si hizo algo.
func confirm() -> bool:
	if not _important:
		return false
	match _phase:
		Phase.TYPING:
			finish_typing()
			return true
		Phase.HOLD:
			_phase = Phase.CLOSING
			_close_time = 0.0
			_update_hint()
			return true
	return false


## Avanza `delta` segundos de tiempo real (lo llama _process; util en pruebas).
func advance(delta: float) -> void:
	match _phase:
		Phase.TYPING:
			_type_time += delta
			_set_alpha(_fade_in_alpha())
			_set_typed(_typed_for_time(_type_time))
			if _typed >= _wrapped.length():
				_phase = Phase.HOLD
				_hold_left = _hold_s
				_hint_time = 0.0
				_update_hint()
		Phase.HOLD:
			_type_time += delta
			_set_alpha(_fade_in_alpha())
			if _important:
				_hint_time += delta
				_update_hint()
				return
			_hold_left -= delta
			if _hold_left <= 0.0:
				_phase = Phase.CLOSING
				_close_time = 0.0
		Phase.CLOSING:
			_close_time += delta
			if _config.fade_out_s <= 0.0 or _close_time >= _config.fade_out_s:
				_finish_line()
			else:
				_set_alpha(OPAQUE - _close_time / _config.fade_out_s)


## Escribe ya todo el texto de la linea actual (no cambia el tiempo en pantalla).
func finish_typing() -> void:
	if _phase == Phase.TYPING:
		_type_time = maxf(_type_time, _step_count() / _cps)
		advance(0.0)


## El menu de pausa no se abre con una linea en pantalla o en cola
## (PauseMenu.BLOCKER_GROUP): las normales corren en tiempo real.
func blocks_pause_menu() -> bool:
	return is_showing() or not _queue.is_empty()


func is_showing() -> bool:
	return _phase != Phase.IDLE


func get_phase() -> Phase:
	return _phase


## Texto completo de la linea actual (vacio si no hay ninguna).
func get_text() -> String:
	return _text


## Caracteres ya escritos por la maquina de escribir (del texto ya partido).
func get_typed_count() -> int:
	return _typed


## Lo que se ve ahora (con los saltos de linea del ajuste).
func get_visible_text() -> String:
	return _body.text


func get_lines() -> PackedStringArray:
	return _lines


## Segundos que el texto completo queda en pantalla tras escribirse.
func get_hold_time() -> float:
	return _hold_s


func get_queue_size() -> int:
	return _queue.size()


## La linea en pantalla es importante (pausa y espera confirmacion).
func is_important() -> bool:
	return _important


## Textos en cola, en el orden en que saldran.
func get_queued_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for item: Dictionary in _queue:
		texts.append(String(item["text"]))
	return texts


## El cuadro tiene el arbol en pausa.
func is_pausing_game() -> bool:
	return _owns_pause


## Ancho util para el texto, en pixeles de arte.
func get_text_width() -> float:
	return _text_width()


func get_font() -> Font:
	return _font


## Estilo de texto de la linea actual (vacio = el de Eco; "lcd" = Calc).
func get_style_id() -> StringName:
	return _style_id


## Textura del panel de la linea actual.
func get_panel_texture() -> Texture2D:
	return _panel.texture


## Color del texto de la linea actual.
func get_body_color() -> Color:
	if _body.material == null:
		return _config.color(&"body")
	return (_body.material as ShaderMaterial).get_shader_parameter(&"target_color")


## Caracteres por segundo de la maquina de escribir en la linea actual.
func get_chars_per_second() -> float:
	return _cps


## Pasos de la maquina de escribir de la linea actual (una racha de
## instant_chars cuenta uno).
func get_type_steps() -> int:
	return _step_count()


## Hay un jefe en el nivel sin vencer (grupo BossBase.GROUP): el cuadro va abajo
## para no tapar la barra del jefe ni su cuerpo (2026-10-22). Mismo contenido.
func is_boss_layout() -> bool:
	return is_inside_tree() and BossBase.is_any_active(get_tree())


func get_panel_rect() -> Rect2:
	return Rect2(_panel.position * _frame.scale, _panel.size * _frame.scale)


func get_speaker_text() -> String:
	return _speaker.text


## Id de quien dice la linea actual (vacio = Eco).
func get_speaker_id() -> StringName:
	return _speaker_id


func get_pixel_scale() -> Vector2:
	return _frame.scale


func get_alpha() -> float:
	return _frame.modulate.a


## La indicacion de cierre esta puesta (linea importante ya escrita). Puede
## estar en la mitad apagada del parpadeo: ver is_confirm_hint_lit().
func is_confirm_hint_visible() -> bool:
	return _hint.visible


## La indicacion se ve ahora (mitad encendida del parpadeo).
func is_confirm_hint_lit() -> bool:
	return _hint.visible and _hint.modulate.a > TRANSPARENT


func get_confirm_hint_text() -> String:
	return _hint.text


## Iconos en linea de la linea actual (TextureRect hijos de Body, en orden).
func get_inline_icons() -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	for icon: Dictionary in _inline:
		out.append(icon["node"] as TextureRect)
	return out


## Id del icono en linea `i` de la linea actual.
func get_inline_icon_id(i: int) -> StringName:
	return StringName(_inline[i]["id"]) if i >= 0 and i < _inline.size() else &""


## Rectangulo del icono en linea `i` en pixeles de pantalla.
func get_inline_icon_rect(i: int) -> Rect2:
	var node := _inline[i]["node"] as TextureRect
	return Rect2((_panel.position + _body.position + node.position) * _frame.scale, node.size * _frame.scale)


## Rectangulo (pixeles de pantalla) del caracter `index` del texto partido: donde
## la fuente dibuja el glifo (pruebas de alineacion del icono en linea).
func get_glyph_rect(index: int) -> Rect2:
	var line: int = 0
	var start: int = 0
	for i: int in _lines.size():
		if index < start + _lines[i].length():
			line = i
			break
		start += _lines[i].length() + 1
	var ch: String = _wrapped.substr(index, 1)
	var x: float = _width(_font, _lines[line].substr(0, index - start), _config.font_size)
	var size := Vector2(_width(_font, ch, _config.font_size), _line_height())
	return Rect2((_panel.position + _body.position + Vector2(x, line * _line_height())) * _frame.scale,
		size * _frame.scale)


## Rectangulo de la indicacion en pixeles de pantalla.
func get_confirm_hint_rect() -> Rect2:
	return Rect2((_panel.position + _hint.position) * _frame.scale, _hint.size * _frame.scale)


## Parte `text` en lineas que caben en `max_width` (por palabras; una palabra
## mas ancha que la linea se corta por caracteres). Los espacios entre palabras
## se sustituyen por saltos de linea, asi que unir las lineas con "\n" da un
## texto de la misma longitud que el original.
static func wrap_text(text: String, font: Font, font_size: int, max_width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(WORD_SEPARATOR):
		var candidate: String = word if line.is_empty() else line + WORD_SEPARATOR + word
		if line.is_empty() or _width(font, candidate, font_size) <= max_width:
			line = candidate
		else:
			lines.append(line)
			line = word
		while _width(font, line, font_size) > max_width and line.length() > 1:
			var cut: int = line.length() - 1
			while cut > 1 and _width(font, line.substr(0, cut), font_size) > max_width:
				cut -= 1
			lines.append(line.substr(0, cut))
			line = line.substr(cut)
	lines.append(line)
	return lines


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


# --- Interno ---

func _start_next() -> void:
	if _queue.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	_important = bool(item.get("important", false)) and pause_important
	if _important:
		_hold_pause()
	else:
		_release_pause()
	_text = TextMarkers.apply(String(item["text"]), _config.inline_icons)
	_apply_speaker(StringName(item.get("speaker", &"")))
	_force_top = bool(item.get("top", false))
	_lines = wrap_text(_text, _font, _config.font_size, _text_width())
	_wrapped = LINE_BREAK.join(_lines)
	_build_steps()
	_build_inline_icons()
	_current_duration = float(item["duration_s"])
	_hold_s = _config.hold_time(_text.length(), _current_duration)
	_type_time = 0.0
	_phase = Phase.TYPING
	_set_typed(0)
	_update_hint()
	_layout()
	_panel.visible = true
	_set_alpha(_fade_in_alpha())
	if _speaker_id == &"":
		EventBus.eco_line_started.emit(_text)
	line_started.emit(_text, _speaker_id)
	if _wrapped.is_empty():
		advance(0.0)


func _finish_line() -> void:
	var speaker: StringName = _speaker_id
	_clear_line()
	if _queue.is_empty() or not bool(_queue[0].get("important", false)):
		_release_pause()
	if speaker == &"":
		EventBus.eco_line_finished.emit()
	line_finished.emit(speaker)
	_start_next()


func _clear_line() -> void:
	_phase = Phase.IDLE
	_important = false
	_update_hint()
	_set_alpha(TRANSPARENT)
	_panel.visible = false
	_text = ""
	_wrapped = ""
	_lines = []
	_clear_inline_icons()
	_set_typed(0)


## Quita la linea normal en pantalla para dejar paso a una importante: vuelve
## a la cola (tras las importantes) salvo si ya se estaba cerrando.
func _preempt_current() -> void:
	var speaker: StringName = _speaker_id
	if _phase != Phase.CLOSING:
		_queue.insert(_first_normal_index(), {"text": _text, "duration_s": _current_duration, "important": false,
			"speaker": speaker, "top": _force_top})
	_clear_line()
	if speaker == &"":
		EventBus.eco_line_finished.emit()
	line_finished.emit(speaker)


func _first_normal_index() -> int:
	for i: int in _queue.size():
		if not bool(_queue[i].get("important", false)):
			return i
	return _queue.size()


func _hold_pause() -> void:
	if _owns_pause or not is_inside_tree():
		return
	if get_tree().paused:
		return  # Ya lo pauso otro: no es nuestro.
	get_tree().paused = true
	_owns_pause = true


func _release_pause() -> void:
	if not _owns_pause:
		return
	_owns_pause = false
	if is_inside_tree():
		get_tree().paused = false


func _set_typed(count: int) -> void:
	_typed = count
	# Los saltos de linea ocupan el lugar de un espacio: el corte es estable.
	_body.text = _wrapped.substr(0, count)
	for icon: Dictionary in _inline:
		(icon["node"] as TextureRect).visible = int(icon["index"]) < count


## Caracteres escritos tras `t` segundos de escritura.
func _typed_for_time(t: float) -> int:
	var n: int = floori(t * _cps)
	if _steps.is_empty():
		return mini(_wrapped.length(), n)
	if n <= 0:
		return 0
	return _steps[mini(n, _steps.size()) - 1]


func _step_count() -> int:
	return _steps.size() if not _steps.is_empty() else _wrapped.length()


## Pasos de la maquina de escribir: con instant_chars, cada racha seguida de
## ellos (p. ej. «130») sale entera en un paso; el resto, caracter a caracter.
func _build_steps() -> void:
	_steps = PackedInt32Array()
	if _instant.is_empty():
		return
	var i: int = 0
	var n: int = _wrapped.length()
	while i < n:
		if _instant.contains(_wrapped[i]):
			var j: int = i
			while j < n and _instant.contains(_wrapped[j]):
				j += 1
			i = j
		else:
			i += 1
		_steps.append(i)


func _fade_in_alpha() -> float:
	if _config.fade_in_s <= 0.0:
		return OPAQUE
	return minf(OPAQUE, _type_time / _config.fade_in_s)


func _set_alpha(alpha: float) -> void:
	_frame.modulate.a = alpha


func _line_height() -> int:
	return ceili(_font.get_height(_config.font_size))


func _text_left() -> int:
	return _config.padding_px + _config.asset_frame_size(ICON_ASSET).x + _config.icon_gap_px


func _text_width() -> float:
	return _config.width_px - _text_left() - _config.padding_px


func _apply_config() -> void:
	var c: EcoTextBoxConfig = _config
	_font = c.load_font()
	_frame.scale = Vector2.ONE * c.pixel_scale
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture = c.asset_texture(PANEL_ASSET)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_patch_margin(side, c.panel_margin_px)
	_icon.texture = c.asset_texture(ICON_ASSET)
	_icon.position = Vector2(c.padding_px, c.padding_px)
	_icon.size = Vector2(c.asset_frame_size(ICON_ASSET))
	for label: Label in [_speaker, _body]:
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", c.font_size)
		label.add_theme_color_override("font_color", NEUTRAL_MODULATE)
		label.add_theme_constant_override("line_spacing", 0)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
	_speaker.text = c.speaker_name
	_speaker.material = c.new_key_swap_material(c.color(&"body"), c.color(&"speaker"))
	_hint = Label.new()
	_hint.name = "ConfirmHint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", c.font_size)
	_hint.add_theme_color_override("font_color", NEUTRAL_MODULATE)
	_hint.add_theme_constant_override("line_spacing", 0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.text = c.confirm_hint_text
	_hint.material = c.new_key_swap_material(c.color(&"body"), c.color(&"confirm_hint"))
	_hint.visible = false
	_panel.add_child(_hint)
	_body_material = c.new_key_swap_material(c.color(&"body"), c.color(&"body"))
	_fonts[""] = _font
	_cps = c.chars_per_second
	_fit_frame()
	_layout()


## Frame ocupa la pantalla en pixeles de arte (su escala la lleva a 1280x720).
func _fit_frame() -> void:
	_frame.size = get_viewport().get_visible_rect().size / _frame.scale
	_layout()


func _layout() -> void:
	if _font == null:
		return
	var c: EcoTextBoxConfig = _config
	var line_h: int = _line_height()
	var lines: int = maxi(1, _lines.size())
	var icon_h: int = c.asset_frame_size(ICON_ASSET).y
	# Las importantes reservan una fila para la indicacion de cierre.
	var hint_rows: int = 1 if _important else 0
	var height: int = maxi(c.padding_px * 2 + line_h * (1 + lines + hint_rows), c.padding_px * 2 + icon_h)
	var width: int = panel_width_for(_lines)
	var hint_w: int = ceili(_width(_font, _hint.text, c.font_size))
	if _important:
		width = clampi(maxi(width, _text_left() + hint_w + c.padding_px), c.min_width_px, c.width_px)
	_panel.size = Vector2(width, height)
	var top: float = c.top_px
	if is_boss_layout() and not _force_top:
		top = _frame.size.y - height - c.boss_bottom_px
	_panel.position = Vector2(floorf((_frame.size.x - width) * 0.5), top)
	var left: int = _text_left()
	var inner: float = width - left - c.padding_px
	_speaker.position = Vector2(left, c.padding_px)
	_speaker.size = Vector2(inner, line_h)
	_body.position = Vector2(left, c.padding_px + line_h)
	_body.size = Vector2(inner, line_h * lines)
	_hint.size = Vector2(hint_w, line_h)
	_hint.position = Vector2(width - c.padding_px - hint_w, height - c.padding_px - line_h)


## Indicacion de cierre: solo en lineas importantes ya escritas; parpadea
## (onda cuadrada, mitad del ciclo visible) en tiempo real.
func _update_hint() -> void:
	if _hint == null:
		return
	_hint.visible = _important and _phase == Phase.HOLD
	if not _hint.visible:
		return
	var phase: float = fmod(_hint_time * _config.confirm_hint_blink_hz, OPAQUE)
	_hint.modulate.a = OPAQUE if phase < HINT_ON_FRACTION else TRANSPARENT


## Nombre, icono y color del nombre de quien habla (speakers de la config;
## vacio o desconocido = Eco).
func _apply_speaker(id: StringName) -> void:
	var c: EcoTextBoxConfig = _config
	var info: Dictionary = c.speakers.get(id, {})
	_speaker_id = id if not info.is_empty() else &""
	if info.is_empty():
		_speaker.text = c.speaker_name
		_icon.texture = c.asset_texture(ICON_ASSET)
		(_speaker.material as ShaderMaterial).set_shader_parameter(&"target_color", c.color(&"speaker"))
		_apply_style(&"", {})
		return
	_speaker.text = String(info.get("name", c.speaker_name))
	var icon_path: String = String(info.get("icon", ""))
	_icon.texture = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else c.asset_texture(ICON_ASSET)
	(_speaker.material as ShaderMaterial).set_shader_parameter(&"target_color",
		Color.html(String(info.get("color", "#9bb0e8"))))
	var style_id := StringName(String(info.get("style", "")))
	_apply_style(style_id if c.speaker_styles.has(style_id) else &"", c.style_for(id))


## Estilo de texto (speaker_styles): fuente, panel, colores, velocidad y
## caracteres de golpe; lo que no trae sale del estilo de Eco.
func _apply_style(id: StringName, style: Dictionary) -> void:
	var c: EcoTextBoxConfig = _config
	_style_id = id
	var font_path: String = String(style.get("font", ""))
	if not _fonts.has(font_path):
		_fonts[font_path] = load(font_path) as Font if ResourceLoader.exists(font_path) else _fonts[""]
	_font = _fonts[font_path]
	for label: Label in [_speaker, _body, _hint]:
		label.add_theme_font_override("font", _font)
	var panel_path: String = String(style.get("panel", ""))
	_panel.texture = load(panel_path) as Texture2D if ResourceLoader.exists(panel_path) else c.asset_texture(PANEL_ASSET)
	var colors: Dictionary = style.get("colors", {})
	if colors.has("body"):
		_body_material.set_shader_parameter(&"target_color", Color.html(String(colors["body"])))
		_body.material = _body_material
	else:
		_body.material = null
	(_hint.material as ShaderMaterial).set_shader_parameter(&"target_color",
		Color.html(String(colors["confirm_hint"])) if colors.has("confirm_hint") else c.color(&"confirm_hint"))
	_cps = maxf(1.0, float(style.get("chars_per_second", c.chars_per_second)))
	_instant = String(style.get("instant_chars", ""))


## Ancho del panel (px de arte) para estas lineas: se ajusta a la linea mas
## ancha (y al nombre), entre min_width_px y width_px.
func panel_width_for(lines: PackedStringArray) -> int:
	var c: EcoTextBoxConfig = _config
	var widest: float = _width(_font, _speaker.text, c.font_size)
	for line: String in lines:
		widest = maxf(widest, _width(_font, line, c.font_size))
	return clampi(_text_left() + ceili(widest) + c.padding_px, c.min_width_px, c.width_px)


## Pone un TextureRect por cada glifo de icono en linea del texto partido
## (ocultos hasta que la maquina de escribir llega a ellos).
func _build_inline_icons() -> void:
	_clear_inline_icons()
	if _config.inline_icons.is_empty():
		return
	var glyphs: Dictionary = TextMarkers.glyph_map(_config.inline_icons)
	var start: int = 0
	var line_h: int = _line_height()
	for li: int in _lines.size():
		var line: String = _lines[li]
		for ci: int in line.length():
			var ch: String = line.substr(ci, 1)
			if not glyphs.has(ch):
				continue
			var id: StringName = glyphs[ch]
			var info: Dictionary = _config.inline_icons[id]
			var texture: Texture2D = _config.asset_texture(StringName(String(info.get("asset", ""))))
			if texture == null:
				continue
			var offset: Array = info.get("offset_px", [0, 0])
			var rect := TextureRect.new()
			rect.name = "InlineIcon%d" % _inline.size()
			rect.texture = texture
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.stretch_mode = TextureRect.STRETCH_KEEP
			rect.size = texture.get_size()
			rect.position = Vector2(_width(_font, line.substr(0, ci), _config.font_size) + float(offset[0]),
				li * line_h + float(offset[1]))
			rect.visible = false
			_body.add_child(rect)
			_inline.append({"node": rect, "index": start + ci, "id": id})
		start += line.length() + 1


func _clear_inline_icons() -> void:
	for icon: Dictionary in _inline:
		var node: Node = icon["node"]
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_inline.clear()


func _on_eco_line_requested(text: String, duration_s: float, important: bool) -> void:
	show_line(text, duration_s, important)
