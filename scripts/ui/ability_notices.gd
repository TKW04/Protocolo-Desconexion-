## Avisos de control de las habilidades (data/ability_notices.json; decision
## 2026-10-15). Dice el control de una habilidad (p. ej. «Láser: F / gatillo
## izquierdo»; el del pulso lo da el encuentro con Eco, EcoEncounter, con
## notice_text y estas mismas tablas)
## la primera vez que el jugador la tiene: al empezar un nivel con ella ya
## desbloqueada (tras start_delay_s de tiempo real) o al desbloquearse durante
## el nivel (EventBus.ability_unlock_changed, que tambien emite el
## ability_pickup al dar la habilidad). Sale una sola vez por habilidad y
## partida guardada (GameState.seen_notices).
## El control se LEE DEL INPUT MAP al mostrar el aviso: desde el 2026-11-03
## (peticion del usuario) solo la tecla o solo el boton, segun el ultimo
## dispositivo usado (ControlBindings.last_device). El aviso va al cuadro de Eco
## con marcas sin sustituir ({tecla:<accion>} y {demo:<id>}, TextMarkers): el
## cuadro resalta la tecla en una cajita, la cambia en vivo si cambia el
## dispositivo o se reasigna, y pone la mini animacion de `demo` (demos de
## data/ability_notices.json, AbilityDemo).
## Se muestra en el cuadro de Eco (EventBus.eco_line_requested) como linea
## IMPORTANTE (decision 2026-10-15): pausa el juego hasta que el jugador la cierra. Lo crea LevelRunner (flujo de juego); se arma
## con begin_level() y se desarma con stop().
class_name AbilityNotices
extends Node

const DATA_PATH: String = "res://data/ability_notices.json"
const NAME_TAG: String = "{name}"
const CONTROL_TAG: String = "{control}"
const KEY_TAG: String = "{key}"
const PAD_TAG: String = "{pad}"
## {key:<accion>} en el texto: la tecla (o el boton) de esa accion del Input Map
## (avisos con varios controles, como el de la Combinacion); es {tecla:<accion>}.
const ACTION_KEY_PREFIX: String = "{key:"
## Aviso del Ocultarte (Pulso 4 de la tienda de Calc; no es de GameState.ABILITIES).
const HIDE_NOTICE: StringName = &"hide"

## Se ha mostrado (pedido al cuadro de Eco) el aviso de `ability`.
signal notice_shown(ability: StringName, text: String)

## Si es false, _process no avanza (las pruebas llaman a advance()).
@export var auto_advance: bool = true

var _data: Dictionary = load_data()
## Hay un nivel en marcha (begin_level sin stop).
var _active: bool = false
## Ya paso start_delay_s: los desbloqueos se avisan al momento.
var _armed: bool = false
var _elapsed: float = 0.0


func _enter_tree() -> void:
	EventBus.ability_unlock_changed.connect(_on_ability_unlock_changed)
	EventBus.ability_obtained.connect(_on_ability_obtained)


func _exit_tree() -> void:
	EventBus.ability_unlock_changed.disconnect(_on_ability_unlock_changed)
	EventBus.ability_obtained.disconnect(_on_ability_obtained)


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


# --- API ---

## Empieza un nivel: espera start_delay_s y entonces avisa de las habilidades
## desbloqueadas que aun no tienen el aviso visto. Llamalo ANTES de anadir el
## nivel (los cambios de habilidades al entrar se ignoran hasta armarse).
func begin_level() -> void:
	_active = true
	_armed = false
	_elapsed = 0.0


## Sin nivel (hub, nivel quitado): no avisa de nada hasta el proximo begin_level.
func stop() -> void:
	_active = false
	_armed = false
	_elapsed = 0.0


func is_armed() -> bool:
	return _armed


## Avanza `delta` segundos de tiempo real.
func advance(delta: float) -> void:
	if not _active or _armed:
		return
	_elapsed += delta
	if _elapsed >= float(_data.get("start_delay_s", 0.0)):
		_armed = true
		show_pending()


## Muestra los avisos de todas las habilidades desbloqueadas con aviso sin ver
## (en el orden de data/ability_notices.json). Devuelve las mostradas.
func show_pending() -> Array[StringName]:
	var shown: Array[StringName] = []
	for key: Variant in get_abilities():
		var ability := StringName(String(key))
		if try_show(ability):
			shown.append(ability)
	return shown


## Muestra el aviso de `ability` si esta desbloqueada, tiene aviso y no se ha
## visto; lo marca como visto (se guarda). Verdadero si lo mostro.
func try_show(ability: StringName) -> bool:
	if GameState.is_notice_seen(ability) or not is_available(ability):
		return false
	var template: String = notice_template(ability, _data)
	if template.is_empty():
		return false
	GameState.mark_notice_seen(ability)
	EventBus.eco_line_requested.emit(template, float(_data.get("duration_s", -1.0)), true)
	# Explicacion (2026-10-30, peticion del usuario tras el 5-2: «uno no sabe como
	# usarlas»): lineas importantes que siguen al control y dicen que hace la
	# habilidad (y, en la Combinacion, cada combo con su secuencia y sus teclas).
	for line: String in explain_templates(ability, _data):
		EventBus.eco_line_requested.emit(line, float(_data.get("duration_s", -1.0)), true)
	notice_shown.emit(ability, TextMarkers.display(template))
	return true


## El jugador tiene ya lo que avisa `ability`: una habilidad desbloqueada o, para
## hide (Ocultarte, Pulso 4 de la tienda de Calc; tanda M2), la mejora comprada.
static func is_available(ability: StringName) -> bool:
	if ability == HIDE_NOTICE:
		return GameState.is_hide_available()
	return GameState.is_ability_unlocked(ability)


func get_abilities() -> Dictionary:
	var abilities: Variant = _data.get("abilities", {})
	return abilities if abilities is Dictionary else {}


# --- Texto (estatico: lo usan las pruebas y las herramientas) ---

static func load_data(path: String = DATA_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Texto del aviso de `ability` tal como se ve ahora («Láser: F» con teclado,
## «Láser: gatillo izquierdo» con mando; "" si no tiene entrada o su accion no
## existe o no tiene ninguna tecla ni boton).
static func notice_text(ability: StringName, data: Dictionary) -> String:
	return TextMarkers.display(notice_template(ability, data))


## El aviso con marcas sin sustituir: {demo:<id>} delante (si la entrada tiene
## `demo`) y {tecla:<accion>} donde va el control (lo resuelve el cuadro de Eco).
static func notice_template(ability: StringName, data: Dictionary) -> String:
	var entry: Dictionary = _entry(ability, data)
	if entry.is_empty():
		return ""
	var action := StringName(String(entry.get("action", "")))
	if control_text(action, data).is_empty():
		return ""
	var control: String = TextMarkers.key_marker(action)
	if bool(entry.get("hold", false)):
		control = String(data.get("hold_prefix", "")) + control
	var text: String = String(entry.get("text", NAME_TAG + ": " + CONTROL_TAG)) \
			.replace(NAME_TAG, String(entry.get("name", ability))).replace(CONTROL_TAG, control)
	return _demo_prefix(String(entry.get("demo", "")), data) + _mark_action_keys(text)


## Lineas de explicacion de `ability` (campo `explain` de su entrada: texto o
## lista de textos) tal como se ven ahora. Vacio si no tiene.
static func explain_lines(ability: StringName, data: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in explain_templates(ability, data):
		out.append(TextMarkers.display(line))
	return out


## Lineas de explicacion con marcas: {key:<accion>} pasa a {tecla:<accion>} y
## cada una lleva delante su {demo:<id>} si `explain_demos` (lista paralela a
## `explain`) se lo da.
static func explain_templates(ability: StringName, data: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var entry: Dictionary = _entry(ability, data)
	var raw: Variant = entry.get("explain", [])
	var lines: Array = raw if raw is Array else ([raw] if raw is String else [])
	var demos: Variant = entry.get("explain_demos", [])
	for i: int in lines.size():
		var text: String = String(lines[i])
		if text.is_empty():
			continue
		var demo: String = String((demos as Array)[i]) if demos is Array and i < (demos as Array).size() else ""
		out.append(_demo_prefix(demo, data) + _mark_action_keys(text))
	return out


## Mini animacion `id` de la tabla demos ({} si no existe).
static func demo_def(id: StringName, data: Dictionary) -> Dictionary:
	var demos: Variant = data.get("demos", {})
	if demos is Dictionary and (demos as Dictionary).get(String(id)) is Dictionary:
		return (demos as Dictionary)[String(id)]
	return {}


static func _entry(ability: StringName, data: Dictionary) -> Dictionary:
	var abilities: Variant = data.get("abilities", {})
	if not abilities is Dictionary or not (abilities as Dictionary).get(String(ability)) is Dictionary:
		return {}
	return (abilities as Dictionary)[String(ability)]


static func _demo_prefix(demo: String, data: Dictionary) -> String:
	if demo.is_empty() or demo_def(StringName(demo), data).is_empty():
		return ""
	return TextMarkers.DEMO_PREFIX + demo + "}"


## {key:<accion>} -> {tecla:<accion>} (la misma marca que las ayudas Q).
static func _mark_action_keys(text: String) -> String:
	return text.replace(ACTION_KEY_PREFIX, TextMarkers.KEY_PREFIX)


## Primera tecla de `action` del Input Map, con key_names ("" si no tiene).
static func action_key_text(action: StringName, data: Dictionary) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return key_name(event as InputEventKey, data)
	return ""


## Control de `action` leido del Input Map: primera tecla y primer boton o eje
## de mando, unidos con control_format. "" si la accion no existe o no tiene
## eventos que se sepan nombrar.
static func control_text(action: StringName, data: Dictionary) -> String:
	if not InputMap.has_action(action):
		return ""
	var key: String = ""
	var pad: String = ""
	for event: InputEvent in InputMap.action_get_events(action):
		if key.is_empty() and event is InputEventKey:
			key = key_name(event as InputEventKey, data)
		elif pad.is_empty() and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			pad = pad_name(event, data)
	if key.is_empty() or pad.is_empty():
		return key + pad
	return String(data.get("control_format", KEY_TAG + " / " + PAD_TAG)) \
			.replace(KEY_TAG, key).replace(PAD_TAG, pad)


## Nombre de la tecla (keycode, o si no hay, physical_keycode), traducido con
## key_names.
static func key_name(event: InputEventKey, data: Dictionary) -> String:
	var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if code == KEY_NONE:
		return ""
	var raw: String = OS.get_keycode_string(code)
	var names: Variant = data.get("key_names", {})
	if names is Dictionary and (names as Dictionary).has(raw):
		return String(names[raw])
	return raw


## Nombre del boton (pad_buttons + pad_button_format) o del eje (pad_axes) del
## mando. "" si no esta en la tabla.
static func pad_name(event: InputEvent, data: Dictionary) -> String:
	if event is InputEventJoypadButton:
		var buttons: Variant = data.get("pad_buttons", {})
		var index: String = str(int((event as InputEventJoypadButton).button_index))
		if not buttons is Dictionary or not (buttons as Dictionary).has(index):
			return ""
		return String(data.get("pad_button_format", "{name}")).replace(NAME_TAG, String(buttons[index]))
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var axes: Variant = data.get("pad_axes", {})
		var axis_key: String = "%d%s" % [int(motion.axis), "+" if motion.axis_value >= 0.0 else "-"]
		if axes is Dictionary and (axes as Dictionary).has(axis_key):
			return String(axes[axis_key])
	return ""


func _on_ability_unlock_changed(ability: StringName, unlocked: bool) -> void:
	if unlocked and _armed:
		try_show(ability)


func _on_ability_obtained(ability: StringName) -> void:
	if _armed:
		try_show(ability)
