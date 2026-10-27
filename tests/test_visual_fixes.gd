# Arreglos visuales de las capturas del 1-3 y de Alerta Mayor (2026-10-22;
# docs/propuesta-1-3.md §7, paso 12, y docs/propuesta-jefe-alerta-mayor.md §6.5):
# terreno falso de «Excepciones», decorado de la sala «Ajustes», rotulo de la
# ranura del banner, terminal de pantalla de bloqueo, iconos del panel de
# favoritos, Eco bajo un techo bajo, cuadro de Eco abajo con un jefe, Q calmada
# en la pelea, encuadre de la arena, contador del badge y ayuda de la carpeta
# del Mundo 2. Solo aspecto: nada de esto cambia colisiones ni rutas.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const LEVEL_1_3: String = "res://scenes/levels/1-3.tscn"
const STEP: float = 1.0 / 60.0

var _root: Node2D


func before_each() -> void:
	GameState.reset_progress()


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	DebugMode.reset()
	GameState.reset_progress()


func _level_1_3() -> Node:
	var level: Node = (load(LEVEL_1_3) as PackedScene).instantiate()
	add_child_autofree(level)
	return level


# --- 1-3 ---

func test_excepciones_is_covered_by_fake_terrain_until_the_wall_opens() -> void:
	var level: Node = _level_1_3()
	var wall := level.get_node(^"Objects/pared_excepciones") as GlitchWall
	var cover: TileMapLayer = wall.get_cover()
	assert_not_null(cover, "La pared lleva su terreno falso")
	assert_false(cover.collision_enabled, "El terreno falso no choca")
	assert_eq(wall.cover_tiles, [121, 1, 9, 4])
	assert_true(wall.is_cover_shown(), "Cerrada: el interior queda tapado")
	assert_gt(cover.z_index, 0, "Por encima de lo que tapa")
	for cell: Vector2i in [Vector2i(121, 1), Vector2i(125, 4), Vector2i(129, 4), Vector2i(130, 2)]:
		assert_ne(cover.get_cell_source_id(cell), -1, "Celda %s dibujada como terreno" % cell)
	wall.open_with_debug()
	for i: int in 120:
		wall.advance(STEP)
	assert_true(wall.is_open(), "Se abre con el Debug")
	assert_false(wall.is_cover_shown(), "Abierta: el interior se ve")
	assert_true(wall.visible_only_with_debug, "visible_only_with_debug no cambia")


func test_settings_room_sign_and_lock_clock_are_decor_without_collision() -> void:
	var level: Node = _level_1_3()
	var arts: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(DecorSprite.GROUP):
		if not level.is_ancestor_of(node):
			continue
		var decor := node as DecorSprite
		assert_not_null(decor.texture, "%s tiene dibujo" % decor.art)
		assert_eq(decor.get_child_count(), 0, "Sin colision ni hijos")
		arts[String(decor.art)] = decor
	for art: String in ["settings_wifi", "settings_brightness", "settings_rotation", "banner_slot", "lock_clock"]:
		assert_true(arts.has(art), "Decorado %s en el 1-3" % art)
	assert_lt((arts["settings_wifi"] as DecorSprite).z_index, 0, "Paneles detras de Isak y de los objetos")
	assert_eq((arts["banner_slot"] as DecorSprite).z_index, 0, "El rotulo va sobre el terreno")
	# Paneles de Ajustes en la pared (filas 5-6), por encima de los interactivos de la fila 9.
	for art: String in ["settings_wifi", "settings_brightness", "settings_rotation"]:
		var rect := Rect2((arts[art] as DecorSprite).position, (arts[art] as DecorSprite).texture.get_size())
		assert_lte(rect.end.y, 7.0 * 64.0, "%s no baja hasta Isak ni Eco" % art)


func test_lock_screen_terminal_keeps_its_behaviour() -> void:
	var level: Node = _level_1_3()
	var terminal := level.get_node(^"Objects/terminal_bloqueo") as ExitTerminal
	assert_eq(terminal.skin, &"lock_screen")
	assert_eq(terminal.get_frames_path(), "res://assets/sprites/lock_terminal_frames.tres")
	assert_eq(terminal.text, "Deslizar para desbloquear", "El texto no cambia")
	var frames := load(terminal.get_frames_path()) as SpriteFrames
	var base := load("res://assets/sprites/warp_objects_frames.tres") as SpriteFrames
	for anim: StringName in [&"terminal_off", &"terminal_prompt", &"terminal_boot", &"terminal_on"]:
		assert_true(frames.has_animation(anim), "Animacion %s" % anim)
		assert_eq(frames.get_frame_count(anim), base.get_frame_count(anim), "Mismos cuadros que %s" % anim)
		assert_eq(frames.get_animation_speed(anim), base.get_animation_speed(anim), "Mismos fps que %s" % anim)
		assert_eq(frames.get_frame_texture(anim, 0).get_size(), Vector2(64, 128), "Mismo tamano")


func test_favourites_panel_has_readable_text_and_icons() -> void:
	var level: Node = _level_1_3()
	var panel := level.get_node(^"Objects/panel_excepciones") as ExceptionsPanel
	assert_eq(panel.get_lines(), PackedStringArray(["Permitir llamadas de: Favoritos", "Mamá", "Abuelito"]))
	assert_eq(panel.get_icons().size(), 4, "Persona y estrella por contacto")
	for icon: TextureRect in panel.get_icons():
		assert_eq(icon.texture.get_size(), Vector2(32, 32), "Iconos de 32 px")
	for label: Node in panel.get_children():
		if label is Label:
			assert_eq((label as Label).scale, Vector2(2, 2), "Texto a escala 2")


func test_eco_stays_under_a_low_ceiling() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_root = Node2D.new()
	add_child(_root)
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	var feet := Vector2(640.0, 400.0)
	var isak := ISAK_SCENE.instantiate() as Isak
	isak.name = "Isak"
	isak.position = feet
	_root.add_child(isak)
	var eco: EcoCompanion = EcoCompanion.attach(isak, _root)
	eco.auto_advance = false
	var data: Dictionary = EcoCompanion.load_data()
	await wait_physics_frames(2)
	var open_y: float = eco.get_follow_position().y
	assert_almost_eq(open_y, feet.y - float((data["offset_px"] as Array)[1]), 21.0, "Sin techo: sitio de siempre")
	# Pasillo de 2 filas: techo 128 px sobre los pies.
	var ceiling := StaticBody2D.new()
	ceiling.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(1024.0, 64.0)
	shape.shape = box
	ceiling.position = Vector2(feet.x, feet.y - 128.0 - 32.0)
	ceiling.add_child(shape)
	_root.add_child(ceiling)
	await wait_physics_frames(2)
	var y: float = eco.get_follow_position().y
	assert_gte(y, feet.y - 128.0 + float(data["ceiling_clear_px"]) - 0.5, "Bajo el techo con su margen")
	assert_lt(y, feet.y, "Nunca por debajo de los pies")


# --- Jefe ---

func _boss() -> BossBase:
	var boss := BossBase.new()
	boss.boss_id = &"alert_major"
	boss.auto_process = false
	add_child_autofree(boss)
	return boss


func test_eco_box_goes_to_the_bottom_while_a_boss_is_alive() -> void:
	var box := (load("res://scenes/ui/eco_text_box.tscn") as PackedScene).instantiate() as EcoTextBox
	add_child_autofree(box)
	box.show_line("Linea por el jefe")
	var top: Rect2 = box.get_panel_rect()
	assert_false(box.is_boss_layout())
	var boss: BossBase = _boss()
	boss.start()
	box.show_line("Otra linea por el jefe")
	box.finish_typing()
	while box.get_text() != "Otra linea por el jefe" and box.is_showing():
		box.advance(10.0)
	assert_true(box.is_boss_layout(), "Con un jefe sin vencer")
	var bottom: Rect2 = box.get_panel_rect()
	assert_lt(top.position.y, 100.0, "Sin jefe: arriba, como siempre")
	assert_gt(bottom.position.y, 360.0, "Abajo, lejos de la barra del jefe")
	assert_lte(bottom.end.y, 720.0, "Dentro de la pantalla")


func test_help_calms_down_after_highlighting_during_a_boss_fight() -> void:
	var cfg: Dictionary = HelpCatalog.shared().boss_calm_config()
	assert_gt(float(cfg.get("highlight_s", 0.0)), 0.0)
	assert_gt(float(cfg.get("blink_hz", 0.0)), 0.0)
	var help := HelpSystem.new()
	add_child_autofree(help)
	var target := Node2D.new()
	add_child_autofree(target)
	HelpCatalog.tag(target, &"charger")
	assert_false(help.is_boss_calm_for(target), "Sin jefe nunca se calma")
	var boss: BossBase = _boss()
	boss.start()
	assert_false(help.is_boss_calm_for(target), "Recien salida: se destaca")
	help.set(&"_target", target)
	help.call(&"_count_boss_highlight", float(cfg["highlight_s"]) + 0.1)
	assert_true(help.is_boss_calm_for(target), "Tras highlight_s queda fija")
	assert_gt(help.get_boss_highlight_s(&"charger"), float(cfg["highlight_s"]))


func test_eco_calm_help_stays_with_isak_without_glow() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_root = Node2D.new()
	add_child(_root)
	var isak := ISAK_SCENE.instantiate() as Isak
	isak.name = "Isak"
	isak.position = Vector2(640.0, 400.0)
	_root.add_child(isak)
	var eco: EcoCompanion = EcoCompanion.attach(isak, _root)
	eco.auto_advance = false
	for i: int in 120:
		eco.advance(STEP)
	var target := Node2D.new()
	target.position = Vector2(900.0, 380.0)
	_root.add_child(target)
	HelpCatalog.tag(target, &"charger")
	eco.set_help_calm(true)
	assert_true(eco.set_help_target(target, &"charger"))
	assert_true(eco.is_helping())
	assert_false(eco.is_glowing(), "Calmada: sin brillo")
	assert_eq(eco.get_target_position(), eco.get_follow_position(), "Se queda junto a Isak")
	eco.set_help_calm(false)
	assert_true(eco.is_glowing(), "Al destacarse brilla")


func test_counter_follows_the_badge_while_it_moves() -> void:
	var level: Node = (load("res://scenes/levels/1-boss.tscn") as PackedScene).instantiate()
	var boss := level.get_node(^"Objects/alerta_mayor") as AlertMajor
	boss.intro_on_arrival = false
	boss.defeat_sequence = false
	boss.auto_process = false
	add_child_autofree(level)
	await wait_physics_frames(2)
	assert_eq(boss.get_label_up_weight(), 1.0, "Arriba: en la pastilla")
	boss.move_body_to(boss.get_spot_center(&"floor_center"), true)
	assert_almost_eq(boss.get_label_up_weight(), 1.0, 0.01, "Al empezar a bajar sigue en la pastilla")
	for i: int in 120:
		boss.call(&"_advance_move", STEP)
	assert_eq(boss.get_label_up_weight(), 0.0, "Abajo: encima del cuerpo")


func test_arena_camera_frames_isak_and_the_boss() -> void:
	var level: Node = (load("res://scenes/levels/1-boss.tscn") as PackedScene).instantiate()
	var boss := level.get_node(^"Objects/alerta_mayor") as AlertMajor
	boss.intro_on_arrival = false
	boss.auto_process = false
	add_child_autofree(level)
	await wait_physics_frames(2)
	var cam := boss.get_node(^"BossCamera") as BossCamera
	assert_not_null(cam, "camera.follow en el JSON del jefe")
	var isak := LevelLookup.find_isak(boss)
	isak.global_position = Vector2(9.5 * 64.0, 10.0 * 64.0)
	var cfg: Dictionary = boss.get_config()["camera"]
	var focus: float = boss.get_camera_focus_xs()[0]
	var expected: float = lerpf(focus, isak.global_position.x, float(cfg["isak_weight"])) - isak.global_position.x
	var half: float = 640.0 - float(cfg["isak_margin_px"])
	assert_almost_eq(cam.get_offset_x(), clampf(expected, -half, half), 0.5, "Centro entre Isak y el jefe")
	cam.apply()
	assert_almost_eq(isak.get_camera().position.x, roundf(clampf(expected, -half, half)), 0.5)
	assert_eq(isak.get_camera().zoom, Vector2.ONE, "Sin cambiar la escala")


# --- Hub ---

## Carpeta de un mundo sin subniveles (desde el paso 11 del Mundo 2, 2026-10-22, el Mundo 2 tiene el 2-1:
## se comprueba con el Mundo 3, que se abre al vencer a Autoplay).
func test_world_without_levels_folder_has_no_enter_hint() -> void:
	GameState.mark_level_completed(&"2-boss")
	MenuHints.set_device(MenuHints.Device.KEYBOARD)
	var panel := FolderPanel.new()
	# Desde el paso 10 de docs/propuesta-mundo-3.md el Mundo 3 tiene el 3-1: el mismo mundo sin sus filas.
	var no_levels: Dictionary = HubWorlds.world(&"m3").duplicate()
	no_levels["levels"] = []
	panel.world_entry = no_levels
	add_child_autofree(panel)
	panel.refresh()
	assert_false(panel.get_help().contains("Entrar"), "Sin nada que entrar")
	assert_eq(panel.get_help(), "G o Espacio Volver")
	var m1 := FolderPanel.new()
	m1.world_entry = HubWorlds.world(&"m1")
	add_child_autofree(m1)
	m1.refresh()
	assert_true(m1.get_help().contains("G Entrar"), "El Mundo 1 sigue igual")
