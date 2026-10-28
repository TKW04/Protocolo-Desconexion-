# Contorno de 1 px de los puntos de atencion solo en el Mundo 2 (decision del
# usuario, 2026-10-22; docs/propuesta-mundo-2.md §8.1, paso 10, fase B): el
# Mundo 1 y el hub siguen sin contorno; el del Mundo 2 usa `feed_noche` de la
# paleta B (seccion palette de data/world2_objects.json).
extends GutTest


func _point_in_world(world: int) -> AttentionPoint:
	var level := GeneratedLevel.new()
	level.world = world
	var point := AttentionPoint.new()
	level.add_child(point)
	autofree(level)
	return point


func test_world_1_points_have_no_outline() -> void:
	var point := _point_in_world(1)
	assert_eq(point.get_level_world(), 1)
	assert_false(point.has_outline())


func test_points_outside_a_level_have_no_outline() -> void:
	var point: AttentionPoint = autofree(AttentionPoint.new())
	assert_eq(point.get_level_world(), 0)
	assert_false(point.has_outline())


func test_world_2_points_have_the_dark_palette_outline() -> void:
	var point := _point_in_world(2)
	assert_true(point.has_outline())
	var palette: Dictionary = World2ObjectsConfig.data().get("palette", {})
	assert_true(palette.has(AttentionPoint.OUTLINE_PALETTE_NAME))
	assert_eq(point.get_outline_color(), Color(String(palette[AttentionPoint.OUTLINE_PALETTE_NAME])))
	assert_eq(AttentionPoint.OUTLINE_PX, 1.0)


# Desde el 2026-10-26 (regla 1 de docs/propuesta-mundo-3.md §6.1): tambien en el Mundo 3,
# con `galeria_noche` de la paleta provisional (data/world3_objects.json).
func test_world_3_points_have_the_gallery_outline() -> void:
	var point := _point_in_world(3)
	assert_true(point.has_outline())
	var palette: Dictionary = World3ObjectsConfig.data().get("palette", {})
	assert_true(palette.has(AttentionPoint.OUTLINE_PALETTE_NAME_W3))
	assert_eq(point.get_outline_color(), Color(String(palette[AttentionPoint.OUTLINE_PALETTE_NAME_W3])))


# Desde el 2026-10-27 (regla 2 de docs/propuesta-mundo-4.md §6.1): tambien en el Mundo 4,
# con `chat_noche` de la paleta provisional (data/world4_objects.json).
func test_world_4_points_have_the_chat_outline() -> void:
	var point := _point_in_world(4)
	assert_true(point.has_outline())
	var palette: Dictionary = World4ObjectsConfig.data().get("palette", {})
	assert_true(palette.has(AttentionPoint.OUTLINE_PALETTE_NAME_W4))
	assert_eq(point.get_outline_color(), Color(String(palette[AttentionPoint.OUTLINE_PALETTE_NAME_W4])))
