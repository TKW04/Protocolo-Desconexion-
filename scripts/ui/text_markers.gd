## Marcadores de los textos de los cuadros de dialogo (2026-10-17, tanda H1 del
## paso 14 de docs/propuesta-1-2.md; ver _inline_notes de data/eco_text_box.json):
## - {apodo}: el apodo de la partida (GameState.apply_nickname; lo pone el cuadro
##   al poner la linea en cola, como siempre).
## - {puntos}: el saldo ACTUAL de puntos de atencion (GameState.attention_points).
## - {icono:<id>}: icono en linea; se cambia por el glifo de inline_icons (la
##   fuente de textos lo tiene con el ancho del icono) y el cuadro dibuja encima
##   el sprite. Un id desconocido se quita (con aviso).
## - {tecla:<accion>}: primera tecla de la accion en el Input Map (p. ej. «K»
##   para debug; cambia al reasignarla); con el mando como ultimo dispositivo
##   (2026-10-30, ControlBindings.last_device), su boton («Y»). Lo usan las ayudas Q (HelpCatalog.text)
##   y los carteles del Mundo 2 (LoopSection; 2026-10-23).
##   Desde el 2026-11-03 los avisos de habilidad (AbilityNotices) la mandan SIN
##   sustituir al cuadro de Eco: EcoTextBox la resuelve con apply_keys_ranges,
##   resalta la tecla en una cajita y la vuelve a resolver si cambia el
##   dispositivo (EventBus.input_device_changed) o se reasigna.
## - {demo:<id>}: al principio de una linea del cuadro de Eco, la mini animacion
##   del aviso (demos de data/ability_notices.json, AbilityDemo); solo la usa el
##   cuadro, el texto que se ve no la lleva (strip_demo).
## Solo texto: dibujar el icono, la cajita y la animacion lo hace EcoTextBox.
class_name TextMarkers
extends RefCounted

const POINTS_TAG: String = "{puntos}"
const ICON_PATTERN: String = "\\{icono:([a-z0-9_]+)\\}"
const KEY_PATTERN: String = "\\{tecla:([a-z0-9_]+)\\}"
const KEY_PREFIX: String = "{tecla:"
const DEMO_PATTERN: String = "^\\{demo:([a-z0-9_]+)\\}"
const DEMO_PREFIX: String = "{demo:"

static var _icon_regex: RegEx
static var _key_regex: RegEx
static var _demo_regex: RegEx


## Marca {tecla:<accion>} (la resuelve quien muestra el texto).
static func key_marker(action: StringName) -> String:
	return KEY_PREFIX + String(action) + "}"


## {tecla:<accion>} -> primera tecla de la accion en el Input Map (si no tiene,
## el nombre de la accion).
static func apply_keys(text: String) -> String:
	return String(apply_keys_ranges(text)["text"])


## Como apply_keys, y ademas donde quedo cada tecla: {text, ranges: [{start,
## length, action}]} (posiciones en el texto ya sustituido).
static func apply_keys_ranges(text: String) -> Dictionary:
	var ranges: Array[Dictionary] = []
	if not text.contains(KEY_PREFIX):
		return {"text": text, "ranges": ranges}
	if _key_regex == null:
		_key_regex = RegEx.create_from_string(KEY_PATTERN)
	var out: String = ""
	var last: int = 0
	for found: RegExMatch in _key_regex.search_all(text):
		out += text.substr(last, found.get_start() - last)
		var action := StringName(found.get_string(1))
		var label: String = key_label(action, String(action).to_upper())
		ranges.append({"start": out.length(), "length": label.length(), "action": action})
		out += label
		last = found.get_end()
	return {"text": out + text.substr(last), "ranges": ranges}


## Tecla o boton de `action` en el dispositivo actual (ControlBindings.last_device,
## 2026-10-30): con teclado, la primera tecla («K», «Espacio»); con mando, su
## boton o eje («Y», «gatillo izquierdo»). Si en ese dispositivo no tiene nada,
## el del otro; `fallback` si no tiene ninguno.
static func key_label(action: StringName, fallback: String = "?") -> String:
	var key: String = PulsePrompt.key_text(action, "")
	if ControlBindings.last_device() == ControlBindings.Device.PAD or key.is_empty():
		return ControlBindings.action_label(action, key if not key.is_empty() else fallback)
	return key


## Id de la animacion {demo:<id>} del principio del texto ("" si no tiene).
static func demo_id(text: String) -> StringName:
	if not text.begins_with(DEMO_PREFIX):
		return &""
	if _demo_regex == null:
		_demo_regex = RegEx.create_from_string(DEMO_PATTERN)
	var found: RegExMatch = _demo_regex.search(text)
	return StringName(found.get_string(1)) if found != null else &""


## El texto sin la marca {demo:<id>} del principio.
static func strip_demo(text: String) -> String:
	if not text.begins_with(DEMO_PREFIX):
		return text
	var close: int = text.find("}")
	return text.substr(close + 1) if close >= 0 else text


## Lo que se ve de una linea con marcas de aviso: sin {demo:} y con las teclas
## del dispositivo actual (pruebas y quien compara textos del cuadro).
static func display(text: String) -> String:
	return apply_keys(strip_demo(text))


## {puntos} -> `points` (negativo: el saldo actual de GameState).
static func apply_points(text: String, points: int = -1) -> String:
	if not text.contains(POINTS_TAG):
		return text
	return text.replace(POINTS_TAG, str(points if points >= 0 else GameState.attention_points))


## {icono:<id>} -> glifo de `icons` (id -> {glyph, ...}); los ids desconocidos se quitan.
static func apply_icons(text: String, icons: Dictionary) -> String:
	if not text.contains("{icono:"):
		return text
	if _icon_regex == null:
		_icon_regex = RegEx.create_from_string(ICON_PATTERN)
	var out: String = ""
	var last: int = 0
	for found: RegExMatch in _icon_regex.search_all(text):
		out += text.substr(last, found.get_start() - last)
		var id := StringName(found.get_string(1))
		var info: Variant = icons.get(id, null)
		if info is Dictionary and not String((info as Dictionary).get("glyph", "")).is_empty():
			out += String((info as Dictionary)["glyph"])
		else:
			push_warning("TextMarkers: icono en linea desconocido '%s'" % id)
		last = found.get_end()
	return out + text.substr(last)


## Puntos e iconos (el apodo ya lo pone el cuadro al encolar).
static func apply(text: String, icons: Dictionary, points: int = -1) -> String:
	return apply_icons(apply_points(text, points), icons)


## Glifo -> id del icono, para buscar los iconos en un texto ya sustituido.
static func glyph_map(icons: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in icons:
		var info: Variant = icons[id]
		if info is Dictionary and not String((info as Dictionary).get("glyph", "")).is_empty():
			out[String((info as Dictionary)["glyph"])] = StringName(String(id))
	return out
