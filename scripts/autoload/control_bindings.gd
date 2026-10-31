## Reasignacion de controles (2026-10-16, decision del usuario; datos en la
## seccion controls de data/settings.json, ver sus _notes). Clase estatica que
## trabaja sobre el Input Map; GameSettings guarda y carga (seccion controls de
## settings.cfg) y el menu de pausa (Ajustes > Controles) la usa.
## - Cada accion reasignable tiene una entrada PRINCIPAL por dispositivo (la
##   primera tecla y el primer boton o eje de mando); assign() la sustituye y
##   conserva las demas entradas (flechas, cruceta).
## - Conflicto: si la entrada ya es de otra accion reasignable, assign() sin
##   swap devuelve CONFLICT sin cambiar nada; con swap, la otra accion recibe la
##   entrada anterior (nunca queda sin entrada de su dispositivo).
## - Reservadas: Esc y Start siempre abren la pausa (se anaden a pause aunque
##   se reasigne su fila) y no se dan a otra accion; las entradas de
##   reserved_actions (R / Select, F9, F1-F4) no se asignan.
## - Tras cada cambio: EventBus.controls_changed (los prompts «G» / «Q» y los
##   avisos de control se vuelven a leer del Input Map).
class_name ControlBindings
extends RefCounted

enum Device { NONE = -1, KEYBOARD, PAD }
enum Result { OK, UNCHANGED, CONFLICT, RESERVED, BLOCKED }

const DATA_PATH: String = "res://data/settings.json"
const NOTICES_PATH: String = "res://data/ability_notices.json"
const CODE_TAG: String = "{code}"

static var _data: Dictionary = {}
static var _names: Dictionary = {}
## Ultimo dispositivo usado (2026-10-30; note_input) y familia del mando
## (pad_families de data/settings.json: "xbox", "playstation", "nintendo" o ""
## = generico, con los nombres de ability_notices.json).
static var _last_device: Device = Device.KEYBOARD
static var _pad_family: String = ""


# --- Datos ---

static func config() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		var section: Variant = (parsed as Dictionary).get("controls", {}) if parsed is Dictionary else {}
		_data = section if section is Dictionary and not (section as Dictionary).is_empty() else {"actions": []}
	return _data


static func _name_tables() -> Dictionary:
	if _names.is_empty():
		_names = AbilityNotices.load_data(NOTICES_PATH)
	return _names


## Acciones reasignables, en el orden de la pantalla.
static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Variant in config().get("actions", []):
		if entry is Dictionary and InputMap.has_action(StringName(String(entry.get("action", "")))):
			out.append(StringName(String(entry["action"])))
	return out


static func is_remappable(action: StringName) -> bool:
	return actions().has(action)


## Nombre de la accion en la UI («Saltar»).
static func action_name(action: StringName) -> String:
	for entry: Variant in config().get("actions", []):
		if entry is Dictionary and String(entry.get("action", "")) == String(action):
			return String(entry.get("name", action))
	return String(action)


## Accion de las entradas fijas (pause).
static func reserved_action() -> StringName:
	return StringName(String(config().get("reserved", {}).get("action", "pause")))


## Entradas fijas de la pausa (Esc y Start).
static func reserved_events() -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for raw: Variant in config().get("reserved", {}).get("events", []):
		var event: InputEvent = deserialize(raw)
		if event != null:
			out.append(event)
	return out


static func capture_arm_s() -> float:
	return float(config().get("capture_arm_s", 0.15))


# --- Eventos ---

static func device_of(event: InputEvent) -> Device:
	if event is InputEventKey:
		return Device.KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Device.PAD
	return Device.NONE


static func _key_code(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


## Misma tecla fisica, mismo boton o mismo eje y sentido.
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		return _key_code(a as InputEventKey) == _key_code(b as InputEventKey)
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var ma := a as InputEventJoypadMotion
		var mb := b as InputEventJoypadMotion
		return ma.axis == mb.axis and signf(ma.axis_value) == signf(mb.axis_value)
	return false


## {type: key, physical_keycode} / {type: joy_button, button} / {type: joy_axis, axis, value}.
static func serialize(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": int(_key_code(event as InputEventKey))}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": int((event as InputEventJoypadButton).button_index)}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"type": "joy_axis", "axis": int(motion.axis), "value": 1.0 if motion.axis_value >= 0.0 else -1.0}
	return {}


## Evento de un diccionario de serialize (null si no es valido).
static func deserialize(raw: Variant) -> InputEvent:
	if not raw is Dictionary:
		return null
	var data := raw as Dictionary
	match String(data.get("type", "")):
		"key":
			var code: int = int(data.get("physical_keycode", 0))
			if code <= 0:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = code as Key
			return key
		"joy_button":
			var index: int = int(data.get("button", -1))
			if index < 0 or index >= JOY_BUTTON_MAX:
				return null
			var button := InputEventJoypadButton.new()
			button.button_index = index as JoyButton
			return button
		"joy_axis":
			var axis: int = int(data.get("axis", -1))
			if axis < 0 or axis >= JOY_AXIS_MAX:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = axis as JoyAxis
			motion.axis_value = 1.0 if float(data.get("value", 1.0)) >= 0.0 else -1.0
			return motion
	return null


## Entrada capturada de `event` (tecla o boton pulsados, eje inclinado mas de
## axis_threshold), limpia y lista para el Input Map; null si no vale.
static func capture_from(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo or _key_code(key) == KEY_NONE:
			return null
		var out := InputEventKey.new()
		out.physical_keycode = _key_code(key)
		return out
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed or (config().get("ignored_buttons", []) as Array).has(int(button.button_index)):
			return null
		var out_button := InputEventJoypadButton.new()
		out_button.button_index = button.button_index
		return out_button
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < float(config().get("axis_threshold", 0.6)):
			return null
		var out_motion := InputEventJoypadMotion.new()
		out_motion.axis = motion.axis
		out_motion.axis_value = 1.0 if motion.axis_value > 0.0 else -1.0
		return out_motion
	return null


## La entrada cancela la captura (Esc o Start, las fijas de la pausa).
static func is_cancel(event: InputEvent) -> bool:
	for reserved: InputEvent in reserved_events():
		if same_input(reserved, event):
			return true
	return false


# --- Input Map ---

## Eventos por defecto de `action` (project.godot), copiados.
static func default_events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	var setting: Variant = ProjectSettings.get_setting("input/" + String(action), {})
	if setting is Dictionary:
		for event: Variant in (setting as Dictionary).get("events", []):
			if event is InputEvent:
				out.append((event as InputEvent).duplicate())
	return out


static func events_of(action: StringName) -> Array[InputEvent]:
	return InputMap.action_get_events(action) if InputMap.has_action(action) else [] as Array[InputEvent]


## Indice de la entrada principal de `device` en `action` (-1 si no hay).
static func slot_index(action: StringName, device: Device) -> int:
	var events: Array[InputEvent] = events_of(action)
	for i: int in events.size():
		if device_of(events[i]) == device:
			return i
	return -1


## Entrada principal de `device` (null si no hay).
static func primary(action: StringName, device: Device) -> InputEvent:
	var index: int = slot_index(action, device)
	return events_of(action)[index] if index >= 0 else null


## Accion reasignable (distinta de `except`) que ya usa `event` y su indice:
## {action, index}; vacio si ninguna.
static func find_conflict(event: InputEvent, except: StringName = &"") -> Dictionary:
	for action: StringName in actions():
		if action == except:
			continue
		var events: Array[InputEvent] = events_of(action)
		for i: int in events.size():
			if same_input(events[i], event):
				return {"action": action, "index": i}
	return {}


## La entrada no se puede dar a `action`: fija de la pausa (salvo a la pausa)
## o de una accion de depuracion / pruebas.
static func is_reserved_for(event: InputEvent, action: StringName) -> bool:
	if action != reserved_action() and is_cancel(event):
		return true
	for reserved: Variant in config().get("reserved_actions", []):
		for other: InputEvent in events_of(StringName(String(reserved))):
			if same_input(other, event):
				return true
	return false


## Pone `event` como entrada principal de su dispositivo en `action`. Con
## conflicto y sin `swap` no cambia nada (CONFLICT); con `swap` la otra accion
## recibe la entrada anterior. Guarda y avisa si cambio (OK).
static func assign(action: StringName, event: InputEvent, swap: bool = false) -> Result:
	var device: Device = device_of(event)
	if not is_remappable(action) or device == Device.NONE:
		return Result.BLOCKED
	if is_reserved_for(event, action):
		return Result.RESERVED
	var events: Array[InputEvent] = events_of(action)
	var slot: int = slot_index(action, device)
	var old: InputEvent = events[slot] if slot >= 0 else null
	if old != null and same_input(old, event):
		return Result.UNCHANGED
	var conflict: Dictionary = find_conflict(event, action)
	if not conflict.is_empty():
		if not swap:
			return Result.CONFLICT
		var other: StringName = conflict["action"]
		var other_events: Array[InputEvent] = events_of(other)
		if old != null:
			other_events[int(conflict["index"])] = old.duplicate()
		else:
			var same_device: int = 0
			for e: InputEvent in other_events:
				if device_of(e) == device:
					same_device += 1
			if same_device <= 1:
				return Result.BLOCKED
			other_events.remove_at(int(conflict["index"]))
		_set_events(other, other_events)
	events = events_of(action)
	# Si la accion ya tenia la entrada como secundaria, se intercambia dentro.
	for i: int in events.size():
		if i != slot and same_input(events[i], event):
			if old != null:
				events[i] = old.duplicate()
			else:
				events.remove_at(i)
			break
	if slot >= 0:
		events[slot] = event.duplicate()
	else:
		events.append(event.duplicate())
	_set_events(action, events)
	_changed()
	return Result.OK


## Vuelve a los controles de project.godot. Con `notify`, guarda y avisa.
static func restore_defaults(notify: bool = true) -> void:
	for action: StringName in actions():
		_set_events(action, default_events(action))
	if notify:
		_changed()


## Los controles son los de project.godot.
static func is_default() -> bool:
	return overrides().is_empty()


## Acciones cambiadas -> sus eventos serializados (para settings.cfg).
static func overrides() -> Dictionary:
	var out: Dictionary = {}
	for action: StringName in actions():
		var current: Array[InputEvent] = events_of(action)
		var defaults: Array[InputEvent] = default_events(action)
		var same: bool = current.size() == defaults.size()
		for i: int in current.size():
			if not same:
				break
			same = same_input(current[i], defaults[i])
		if not same:
			var list: Array = []
			for event: InputEvent in current:
				list.append(serialize(event))
			out[String(action)] = list
	return out


## Aplica los controles guardados (accion -> lista serializada) sobre los de
## project.godot. Una accion invalida (sin entrada de algun dispositivo que
## tenga por defecto) vuelve a su valor por defecto; si quedan entradas
## repetidas entre acciones, todos vuelven a los de project.godot. Avisa.
static func apply_overrides(saved: Dictionary) -> void:
	restore_defaults(false)
	for key: Variant in saved:
		var action := StringName(String(key))
		# 2026-10-31: la accion `run` (mantener para correr) paso a ser `walk`
		# (mantener para caminar) con las mismas entradas; lo reasignado se conserva.
		if action == &"run" and not saved.has("walk"):
			action = &"walk"
		if not is_remappable(action) or not saved[key] is Array:
			continue
		var events: Array[InputEvent] = []
		for raw: Variant in saved[key]:
			var event: InputEvent = deserialize(raw)
			if event != null and not events.any(func(e: InputEvent) -> bool: return same_input(e, event)):
				events.append(event)
		if _covers_devices(action, events):
			_set_events(action, events)
	if _has_duplicates():
		restore_defaults(false)
	EventBus.controls_changed.emit()


static func _covers_devices(action: StringName, events: Array[InputEvent]) -> bool:
	for device: Device in [Device.KEYBOARD, Device.PAD]:
		var wanted: bool = default_events(action).any(func(e: InputEvent) -> bool: return device_of(e) == device)
		if wanted and not events.any(func(e: InputEvent) -> bool: return device_of(e) == device):
			return false
	return true


static func _has_duplicates() -> bool:
	var seen: Array[InputEvent] = []
	for action: StringName in actions():
		for event: InputEvent in events_of(action):
			if action != reserved_action() and is_cancel(event):
				return true
			for other: InputEvent in seen:
				if same_input(other, event):
					return true
		seen.append_array(events_of(action))
	return false


## Escribe los eventos de `action`; a la pausa le anade siempre Esc y Start.
static func _set_events(action: StringName, events: Array[InputEvent]) -> void:
	var list: Array[InputEvent] = []
	for event: InputEvent in events:
		if not list.any(func(e: InputEvent) -> bool: return same_input(e, event)):
			list.append(event)
	if action == reserved_action():
		# Solo la principal de cada dispositivo y las fijas.
		var kept: Array[InputEvent] = []
		for device: Device in [Device.KEYBOARD, Device.PAD]:
			for event: InputEvent in list:
				if device_of(event) == device:
					kept.append(event)
					break
		for reserved: InputEvent in reserved_events():
			if not kept.any(func(e: InputEvent) -> bool: return same_input(e, reserved)):
				kept.append(reserved)
		list = kept
	InputMap.action_erase_events(action)
	for event: InputEvent in list:
		InputMap.action_add_event(action, event)


static func _changed() -> void:
	GameSettings.save()
	EventBus.controls_changed.emit()


# --- Nombres ---

## Nombre legible de una entrada («Espacio», «G», «A», «gatillo derecho»).
## Con `font`, si falta algun glifo, «Tecla <codigo>».
static func input_label(event: InputEvent, font: Font = null) -> String:
	var tables: Dictionary = _name_tables()
	var label: String = ""
	var code: String = ""
	if event is InputEventKey:
		var key := event as InputEventKey
		code = str(int(_key_code(key)))
		label = AbilityNotices.key_name(key, tables)
		if label.is_empty() or not _has_glyphs(label, font):
			label = String(config().get("unknown_key", "Tecla {code}")).replace(CODE_TAG, code)
	elif event is InputEventJoypadButton:
		code = str(int((event as InputEventJoypadButton).button_index))
		label = String((tables.get("pad_buttons", {}) as Dictionary).get(code, ""))
		if label.is_empty() or not _has_glyphs(label, font):
			label = String(config().get("unknown_button", "Botón {code}")).replace(CODE_TAG, code)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		code = "%d%s" % [int(motion.axis), "+" if motion.axis_value >= 0.0 else "-"]
		label = String((tables.get("pad_axes", {}) as Dictionary).get(code, ""))
		if label.is_empty() or not _has_glyphs(label, font):
			label = String(config().get("unknown_axis", "Eje {code}")).replace(CODE_TAG, code)
	else:
		label = String(config().get("none", "Sin asignar"))
	return label


## «{tecla} / {mando}» de la accion (entradas principales).
static func binding_label(action: StringName, font: Font = null) -> String:
	var key: InputEvent = primary(action, Device.KEYBOARD)
	var pad: InputEvent = primary(action, Device.PAD)
	return "%s / %s" % [input_label(key, font), input_label(pad, font)]


static func _has_glyphs(text: String, font: Font) -> bool:
	if font == null:
		return true
	for i: int in text.length():
		var ch: int = text.unicode_at(i)
		if ch != 32 and not font.has_char(ch):
			return false
	return true


# --- Dispositivo actual (2026-10-30, peticion del usuario: «¿se puede hacer que
# detecte el control o el teclado?») ---
# El ultimo dispositivo usado decide que se muestra en Ajustes > Controles y en
# los textos con teclas ({key:<accion>} de los avisos, {tecla:<accion>} de las
# ayudas Q): la tecla o el boton del mando. Lo alimenta el autoload
# InputDeviceWatcher (scripts/autoload/input_device_watcher.gd) con cada
# entrada, sin consumirla.

## Apunta el dispositivo de `event` (tecla o raton = teclado; boton o eje
## inclinado mas de device_axis_threshold = mando). Verdadero si cambio (y emite
## EventBus.input_device_changed).
static func note_input(event: InputEvent) -> bool:
	var device: Device = Device.NONE
	if event is InputEventKey and (event as InputEventKey).pressed:
		device = Device.KEYBOARD
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		device = Device.KEYBOARD
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		device = Device.PAD
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) \
			> float(config().get("device_axis_threshold", 0.5)):
		device = Device.PAD
	if device == Device.NONE:
		return false
	var family: String = _pad_family
	if device == Device.PAD:
		family = family_for_name(Input.get_joy_name(event.device)) if event.device >= 0 else ""
	if device == _last_device and family == _pad_family:
		return false
	set_last_device(device, family)
	return true


## Ultimo dispositivo usado (KEYBOARD al arrancar).
static func last_device() -> Device:
	return _last_device


## Familia del ultimo mando ("" = generico).
static func pad_family() -> String:
	return _pad_family


## Fija el dispositivo (y la familia del mando) y avisa si cambia. Lo usan
## note_input y las pruebas.
static func set_last_device(device: Device, family: String = "") -> void:
	if device == Device.NONE:
		return
	var changed: bool = device != _last_device or (device == Device.PAD and family != _pad_family)
	_last_device = device
	_pad_family = family if device == Device.PAD else _pad_family
	if changed:
		EventBus.input_device_changed.emit(int(device))


## Vuelve al teclado sin avisar (GameState.reset_progress: cada prueba empieza
## igual).
static func reset_device() -> void:
	_last_device = Device.KEYBOARD
	_pad_family = ""


## Familia de un mando por su nombre (Input.get_joy_name): la primera de
## pad_families con alguna palabra de `match` en el nombre ("" si ninguna).
static func family_for_name(joy_name: String) -> String:
	var lower: String = joy_name.to_lower()
	var families: Variant = config().get("pad_families", {})
	if families is Dictionary:
		for family: Variant in families:
			var entry: Variant = (families as Dictionary)[family]
			if not entry is Dictionary:
				continue
			for word: Variant in (entry as Dictionary).get("match", []):
				if not String(word).is_empty() and lower.contains(String(word).to_lower()):
					return String(family)
	return ""


## Nombre de la familia del mando para la UI («Xbox»; "" si es generico).
static func pad_family_name(family: String = _pad_family) -> String:
	var families: Variant = config().get("pad_families", {})
	if families is Dictionary and (families as Dictionary).get(family) is Dictionary:
		return String(((families as Dictionary)[family] as Dictionary).get("name", ""))
	return ""


## Nombre de una entrada para la UI: la tecla como input_label; el boton o el eje
## con la tabla de la familia del mando (Cruz, L1...) y, con `compact`, la corta
## de pad_short (LT, «Stick abajo»); si no, el de ability_notices.json.
static func device_label(event: InputEvent, compact: bool = false, font: Font = null) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var code: String = ""
		var table: String = "buttons"
		if event is InputEventJoypadButton:
			code = str(int((event as InputEventJoypadButton).button_index))
		else:
			var motion := event as InputEventJoypadMotion
			code = "%d%s" % [int(motion.axis), "+" if motion.axis_value >= 0.0 else "-"]
			table = "axes"
		var sources: Array = []
		var families: Variant = config().get("pad_families", {})
		if families is Dictionary and (families as Dictionary).get(_pad_family) is Dictionary:
			sources.append(((families as Dictionary)[_pad_family] as Dictionary).get(table, {}))
		if compact:
			sources.append((config().get("pad_short", {}) as Dictionary).get(table, {}))
		for source: Variant in sources:
			if source is Dictionary and (source as Dictionary).has(code):
				var label: String = String((source as Dictionary)[code])
				if _has_glyphs(label, font):
					return label
	return input_label(event, font)


## Entrada de `action` en el dispositivo actual (o en el otro si en este no
## tiene); null si no tiene ninguna.
static func current_event(action: StringName) -> InputEvent:
	var order: Array = [Device.KEYBOARD, Device.PAD]
	if _last_device == Device.PAD:
		order.reverse()
	for device: Variant in order:
		var event: InputEvent = primary(action, device as Device)
		if event != null:
			return event
	return null


## Tecla o boton de `action` en el dispositivo actual («Espacio», «A»);
## `fallback` si no tiene. Se lee del Input Map cada vez: si una accion cambia
## de tecla en project.godot o en Ajustes, el texto cambia solo.
static func action_label(action: StringName, fallback: String = "", compact: bool = false,
		font: Font = null) -> String:
	var event: InputEvent = current_event(action) if InputMap.has_action(action) else null
	return device_label(event, compact, font) if event != null else fallback


# --- Filas del menu de Controles (2026-10-30; menu_rows de data/settings.json) ---

## Filas de Ajustes > Controles en orden: {id, icon, detail y action (una
## accion) o sequence (un combo: varias acciones en orden)}. Se saltan las que
## nombran una accion que no existe en el Input Map.
static func menu_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in config().get("menu_rows", []):
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw
		var ok: bool = row.has("action") or row.has("sequence")
		for action: StringName in row_actions(row):
			ok = ok and InputMap.has_action(action)
		if ok:
			out.append(row)
	return out


## Acciones de una fila (la suya o las del combo, en orden).
static func row_actions(row: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if row.has("action"):
		out.append(StringName(String(row["action"])))
	for action: Variant in row.get("sequence", []):
		out.append(StringName(String(action)))
	return out


## Texto de una fila: solo la tecla o el boton (los de un combo, en orden,
## separados por sequence_join).
static func row_label(row: Dictionary, font: Font = null) -> String:
	var parts: PackedStringArray = []
	for action: StringName in row_actions(row):
		parts.append(action_label(action, String(config().get("none", "Sin asignar")), true, font))
	return String(config().get("sequence_join", ", ")).join(parts)
