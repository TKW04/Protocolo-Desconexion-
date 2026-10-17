# Marcadores del cuadro de texto (2026-10-17, tanda H1 del paso 14 de
# docs/propuesta-1-2.md; TextMarkers y EcoTextBox): {puntos} es el saldo ACTUAL
# de puntos de atencion (al empezar a escribirse la linea, no al encolarla) e
# {icono:atencion} dibuja el rombo del punto de atencion dentro de la linea,
# sobre su glifo de la fuente y alineado con las mayusculas; sale cuando la
# maquina de escribir llega a el. Las lineas sin marcadores no cambian y un id
# desconocido se quita. El cuadro del hub es la misma escena.
extends GutTest

const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const DT: float = 1.0 / 60.0
const GLYPH: String = "◆"

var _config: EcoTextBoxConfig = EcoTextBoxConfig.shared()
var _points: int


func before_each() -> void:
	_points = GameState.attention_points


func after_each() -> void:
	get_tree().paused = false
	GameState.attention_points = _points


func _box() -> EcoTextBox:
	var box := BOX_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.set_process(false)
	return box


func _advance(box: EcoTextBox, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		box.advance(DT)


func test_markers_helpers() -> void:
	assert_eq(TextMarkers.apply_points("Tienes {puntos}.", 7), "Tienes 7.")
	GameState.attention_points = 12
	assert_eq(TextMarkers.apply_points("{puntos} y {puntos}"), "12 y 12", "Saldo actual, todas las veces")
	assert_eq(TextMarkers.apply_icons("Uno {icono:atencion} dos", _config.inline_icons), "Uno %s dos" % GLYPH)
	assert_eq(TextMarkers.apply_icons("Sin marcas.", _config.inline_icons), "Sin marcas.")
	assert_eq(TextMarkers.apply_icons("A{icono:nada}B", _config.inline_icons), "AB", "Id desconocido: se quita")
	assert_eq(TextMarkers.glyph_map(_config.inline_icons).get(GLYPH), &"atencion")


func test_font_has_the_icon_glyph_with_the_icon_width() -> void:
	var box := _box()
	var font: Font = box.get_font()
	assert_true(font.has_char(GLYPH.unicode_at(0)), "La fuente tiene el hueco del icono")
	var texture: Texture2D = _config.asset_texture(&"inline_attention")
	var width: float = font.get_string_size(GLYPH, HORIZONTAL_ALIGNMENT_LEFT, -1, _config.font_size).x
	assert_eq(width, 8.0, "Avance = ancho del rombo (7) + 1")
	assert_eq(texture.get_size(), Vector2(8, 8))


func test_points_are_the_balance_when_the_line_starts() -> void:
	var box := _box()
	GameState.attention_points = 3
	box.show_line("Primera.")
	box.show_line("Tienes {puntos} puntos.")
	GameState.attention_points = 41
	while box.get_text() == "Primera.":
		box.advance(DT)
	assert_eq(box.get_text(), "Tienes 41 puntos.", "El saldo de cuando empieza la linea")


func test_inline_icon_is_drawn_on_its_glyph_and_typed_in_order() -> void:
	var box := _box()
	GameState.attention_points = 25
	box.show_line("Te devuelvo {puntos} {icono:atencion} convertidos en mejoras.")
	assert_eq(box.get_text(), "Te devuelvo 25 %s convertidos en mejoras." % GLYPH)
	var icons: Array[TextureRect] = box.get_inline_icons()
	assert_eq(icons.size(), 1, "Un icono")
	assert_eq(box.get_inline_icon_id(0), &"atencion")
	assert_false(icons[0].visible, "Aun no se ha escrito")
	var index: int = "\n".join(box.get_lines()).find(GLYPH)
	# Antes del glifo: oculto; justo despues: visible.
	box.advance(float(index) / _config.chars_per_second - 0.001)
	assert_false(icons[0].visible, "Sale cuando la maquina de escribir llega")
	box.advance(2.0 / _config.chars_per_second)
	assert_true(icons[0].visible, "Escrito: se ve")
	var glyph: Rect2 = box.get_glyph_rect(index)
	var icon: Rect2 = box.get_inline_icon_rect(0)
	var scale: Vector2 = box.get_pixel_scale()
	assert_eq(icon.position.x, glyph.position.x, "Alineado con el glifo en x")
	assert_eq(icon.position.y, glyph.position.y + 3.0 * scale.y, "A la altura de las mayusculas (fila 3)")
	assert_eq(icon.size, Vector2(8, 8) * scale)
	assert_eq(icons[0].texture, _config.asset_texture(&"inline_attention"))


func test_icon_on_a_wrapped_line_and_cleared_with_the_line() -> void:
	var box := _box()
	var text: String = "Eco sabe sumar atención. Nunca ha sabido restarla. Aquí tienes tus {icono:atencion} de vuelta, {icono:atencion} a {icono:atencion}."
	box.show_line(text)
	var lines: PackedStringArray = box.get_lines()
	assert_gt(lines.size(), 1, "Texto largo: varias lineas")
	var icons: Array[TextureRect] = box.get_inline_icons()
	assert_eq(icons.size(), 3)
	var joined: String = "\n".join(lines)
	var at: int = -1
	for i: int in 3:
		at = joined.find(GLYPH, at + 1)
		assert_eq(box.get_inline_icon_rect(i).position.x, box.get_glyph_rect(at).position.x, "Icono %d en su glifo" % i)
		assert_eq(box.get_inline_icon_rect(i).position.y, box.get_glyph_rect(at).position.y + 3.0 * box.get_pixel_scale().y)
	_advance(box, 30.0)
	assert_false(box.is_showing())
	assert_eq(box.get_inline_icons().size(), 0, "Se quitan al cerrar la linea")


func test_lines_without_markers_are_unchanged() -> void:
	var box := _box()
	box.show_line("Bienvenido. He optimizado tu espacio.")
	assert_eq(box.get_text(), "Bienvenido. He optimizado tu espacio.")
	assert_eq(box.get_inline_icons().size(), 0)


func test_important_line_and_other_speaker_keep_markers() -> void:
	var box := _box()
	GameState.attention_points = 9
	var saved: bool = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	box.show_line("Saldo: {puntos} {icono:atencion}", -1.0, true, &"notas")
	EcoTextBox.pause_important = saved
	assert_eq(box.get_text(), "Saldo: 9 %s" % GLYPH)
	assert_eq(box.get_speaker_id(), &"notas")
	assert_eq(box.get_inline_icons().size(), 1)
