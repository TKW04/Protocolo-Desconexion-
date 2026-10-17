## Marcadores de los textos de los cuadros de dialogo (2026-10-17, tanda H1 del
## paso 14 de docs/propuesta-1-2.md; ver _inline_notes de data/eco_text_box.json):
## - {apodo}: el apodo de la partida (GameState.apply_nickname; lo pone el cuadro
##   al poner la linea en cola, como siempre).
## - {puntos}: el saldo ACTUAL de puntos de atencion (GameState.attention_points).
## - {icono:<id>}: icono en linea; se cambia por el glifo de inline_icons (la
##   fuente de textos lo tiene con el ancho del icono) y el cuadro dibuja encima
##   el sprite. Un id desconocido se quita (con aviso).
## Solo texto: dibujar el icono lo hace EcoTextBox.
class_name TextMarkers
extends RefCounted

const POINTS_TAG: String = "{puntos}"
const ICON_PATTERN: String = "\\{icono:([a-z0-9_]+)\\}"

static var _icon_regex: RegEx


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
