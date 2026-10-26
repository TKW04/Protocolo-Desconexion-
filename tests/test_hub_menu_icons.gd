# Iconos de los menus del hub y check de la carpeta (2026-10-26, peticion del
# usuario): Notas lleva un icono por opcion (disquete en Guardar), el panel de
# una carpeta un icono por subnivel (gris si esta bloqueado) y Volver; la
# carpeta solo se marca con check (animacion all_done) con TODO el mundo
# obtenido: subniveles y jefe, puntos, power banks, vidas extra y recuerdos
# (HubWorlds.world_progress / is_world_all_done). La pieza del fondo sigue con
# folder_state (subniveles completados). Usa su propia ruta de guardado.
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_hub_menu_icons.json"
const MENU: String = "res://assets/sprites/hub/menu/menu_%s_00.png"
const M1_LEVELS: Array[StringName] = [&"1-1", &"1-2", &"1-3", &"1-boss"]

var _hub: HubRoom
var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _spawn() -> HubRoom:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	return _hub


func _m1() -> Dictionary:
	return HubWorlds.world(&"m1")


## Obtiene TODO lo del Mundo 1 menos `skip` (una parte de world_progress).
func _complete_world_1(skip: String = "") -> void:
	for id: StringName in M1_LEVELS:
		if skip != "levels" or id != &"1-boss":
			GameState.mark_level_completed(id)
		if skip != "points":
			for i: int in HubWorlds.level_points_total(String(id)):
				GameState.capture_attention_point(id, StringName("p%d" % i), 1)
		if skip != "power_banks":
			for bank: StringName in GameState.level_power_bank_ids(id):
				GameState.collect_power_bank_pickup(id, bank)
		if skip != "extra_lives":
			for secret: StringName in HubWorlds.level_extra_life_secrets(id):
				GameState.collect_extra_life(id, secret)
	if skip != "memories":
		for id: StringName in MemoryCatalog.shared().ids_of(1, MemoryCatalog.KIND_SECRET):
			GameState.obtain_memory(id)
		GameState.obtain_memory(MemoryCatalog.shared().boss_id(1, GameState.lap))


# --- Condicion del check ---

func test_world_progress_counts_every_part_of_world_1() -> void:
	var p: Dictionary = HubWorlds.world_progress(_m1())
	assert_eq(p["levels"], Vector2i(0, 4), "3 subniveles y el jefe")
	assert_eq(p["points"], Vector2i(0, 27), "9 puntos por mapa")
	assert_eq(p["power_banks"].y, 3, "Un power bank en cada mapa")
	assert_eq(p["extra_lives"], Vector2i(0, 1), "La vida extra del 1-1 (secreto D)")
	assert_eq(p["memories"], Vector2i(0, 4), "msg_1_1..msg_1_3 y la capa Caché del jefe")
	assert_eq(HubWorlds.world_missing(_m1()),
		["levels", "points", "power_banks", "extra_lives", "memories"] as Array[String])


func test_check_needs_everything_not_only_the_levels() -> void:
	for id: StringName in M1_LEVELS:
		GameState.mark_level_completed(id)
	assert_eq(HubWorlds.folder_state(_m1()), HubWorlds.STATE_COMPLETED, "Subniveles superados (pieza del fondo)")
	assert_false(HubWorlds.is_world_all_done(_m1()), "Sin lo coleccionable no hay check")
	assert_eq(HubWorlds.folder_art_state(_m1()), HubWorlds.STATE_COMPLETED)
	for part: String in ["levels", "points", "power_banks", "extra_lives", "memories"]:
		GameState.reset_progress()
		_complete_world_1(part)
		assert_false(HubWorlds.is_world_all_done(_m1()), "Falta %s: sin check" % part)
		assert_eq(HubWorlds.world_missing(_m1()), [part] as Array[String], "Solo falta %s" % part)
	GameState.reset_progress()
	_complete_world_1()
	assert_true(HubWorlds.is_world_all_done(_m1()), "Todo obtenido")
	assert_eq(HubWorlds.folder_art_state(_m1()), HubWorlds.STATE_ALL_DONE)
	assert_eq(HubWorlds.folder_state(_m1()), HubWorlds.STATE_COMPLETED, "folder_state no cambia")


func test_world_without_levels_in_the_lap_never_shows_the_check() -> void:
	GameState.mark_level_completed(&"2-boss")
	var m3: Dictionary = HubWorlds.world(&"m3")
	assert_eq(HubWorlds.folder_state(m3), HubWorlds.STATE_AVAILABLE, "Mundo 3 «Próximamente»")
	assert_false(HubWorlds.is_world_all_done(m3))


func test_folder_art_shows_the_check_only_with_everything() -> void:
	for id: StringName in M1_LEVELS:
		GameState.mark_level_completed(id)
	_spawn()
	var folder: FolderStation = _hub.get_folder(&"m1")
	assert_eq(folder.get_folder_animation(), &"completed")
	assert_false(folder.is_check_shown())
	_complete_world_1()
	folder.refresh_state()
	assert_eq(folder.get_folder_animation(), &"all_done", "Con todo: check")
	assert_true(folder.is_check_shown())
	assert_eq(_hub.get_folder(&"m2").get_folder_animation(), &"available", "Mundo 2 recien desbloqueado")


func test_folder_panel_says_what_is_missing_or_all_done() -> void:
	for id: StringName in M1_LEVELS:
		GameState.mark_level_completed(id)
	_complete_world_1("memories")
	_spawn()
	var panel: FolderPanel = _hub.get_folder(&"m1").get_folder_panel()
	panel.open()
	assert_eq(panel.get_lines()[1], "Para el check: recuerdos")
	panel.close()
	GameState.obtain_memory(&"msg_1_1")
	GameState.obtain_memory(&"msg_1_2")
	GameState.obtain_memory(&"msg_1_3")
	GameState.obtain_memory(&"boss_w1_l1")
	panel.open()
	assert_eq(panel.get_lines()[1], "Todo obtenido")
	assert_eq(panel.get_line_color(1), HubData.color("acento_cian"))
	panel.close()


# --- Iconos de los menus ---

func test_notas_menu_has_an_icon_per_option_with_the_floppy_for_save() -> void:
	_spawn()
	var notas := _hub.get_station(&"notas") as NotasStation
	var panel := notas.get_panel() as NotasPanel
	panel.open()
	var expected: Dictionary = {NotasPanel.OPTION_SAVE: "save", NotasPanel.OPTION_ALBUM: "album",
		NotasPanel.OPTION_NICKNAME: "nickname", NotasPanel.OPTION_BACK: "back"}
	assert_eq(panel.get_option_ids().size(), 4)
	for i: int in panel.get_option_ids().size():
		var id: StringName = panel.get_option_ids()[i]
		var tex: Texture2D = panel.get_option_icon(i)
		assert_not_null(tex, "%s con icono" % id)
		assert_eq(tex.resource_path, MENU % expected[id])
		assert_eq(tex.get_size(), Vector2(12.0, 12.0), "12x12 px de arte")
		var rect: TextureRect = panel.get_option_icon_rect(i)
		assert_true(rect.visible)
		var label: Label = panel._get_option_label(i)
		assert_lt(rect.position.x + rect.size.x, label.position.x + 0.5, "Icono a la izquierda del texto")
		assert_almost_eq(rect.position.y + rect.size.y * 0.5, label.position.y + label.size.y * 0.5, 1.0,
			"Centrado en la fila")
	assert_eq(panel.get_option_icon(0).resource_path, MENU % "save", "Guardar: disquete")
	# Confirmacion: check y aspa.
	panel.skip_input_delay()
	GameState.request_save()
	panel.select_option(NotasPanel.OPTION_SAVE)
	panel.confirm()
	assert_eq(panel.get_mode(), NotasPanel.Mode.CONFIRM)
	assert_eq(panel.get_option_icon(0).resource_path, MENU % "yes")
	assert_eq(panel.get_option_icon(1).resource_path, MENU % "no")
	assert_eq(panel.get_help(), "G Aceptar · Espacio Volver", "Notas: sin «Elegir» (2026-10-26)")
	panel.close()


func test_notas_header_icons_are_12px_from_the_menu_set() -> void:
	for name: String in ["attention", "access_cache", "access_kernel", "access_root"]:
		var tex: Texture2D = load(MENU % name)
		assert_not_null(tex, name)
		assert_eq(tex.get_size(), Vector2(12.0, 12.0), "%s: 12x12" % name)


func test_folder_panel_has_an_icon_per_level_and_grey_when_locked() -> void:
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	_spawn()
	var panel: FolderPanel = _hub.get_folder(&"m1").get_folder_panel()
	panel.open()
	var ids: Array[StringName] = panel.get_option_ids()
	assert_eq(ids, [&"1-1", &"1-2", &"1-3", &"1-boss", FolderPanel.OPTION_BACK] as Array[StringName])
	assert_eq(panel.get_option_icon(0).resource_path, MENU % "level_1_1", "Completado: en color")
	assert_eq(panel.get_option_icon(1).resource_path, MENU % "level_1_2", "Disponible: en color")
	assert_eq(panel.get_option_icon(2).resource_path, MENU % "level_1_3_off", "Bloqueado: gris")
	assert_eq(panel.get_option_icon(3).resource_path, MENU % "level_1_boss_off", "Jefe bloqueado: gris")
	assert_eq(panel.get_option_icon(4).resource_path, MENU % "back", "Volver")
	for i: int in ids.size():
		assert_true(panel.get_option_icon_rect(i).visible, "Icono visible en %s" % ids[i])
	assert_true(panel.get_help().contains("W/S Elegir"), "El pie de teclas sigue")
	# «¿Seguro?»: Entrar sin guardar y Volver con icono.
	GameState.request_save()
	panel.skip_input_delay()
	panel.select_option(&"1-1")
	panel.confirm()
	assert_true(panel.is_confirming_unsaved())
	assert_eq(panel.get_option_icon(0).resource_path, MENU % "enter")
	assert_eq(panel.get_option_icon(1).resource_path, MENU % "back")
	panel.close()


func test_world_2_levels_have_their_own_icons() -> void:
	for id: StringName in M1_LEVELS:
		GameState.mark_level_completed(id)
	var m2: Dictionary = HubWorlds.world(&"m2")
	var expected: Array[String] = ["level_2_1", "level_2_2_off", "level_2_3_off", "level_2_boss_off"]
	var levels: Array[Dictionary] = HubWorlds.levels_for_lap(m2)
	_spawn()
	var panel: FolderPanel = _hub.get_folder(&"m2").get_folder_panel()
	for i: int in levels.size():
		assert_eq(panel.level_icon_path(levels[i]), MENU % expected[i])


func test_calc_shop_keeps_its_own_drawing_without_option_icons() -> void:
	_spawn()
	EcoProgress.meet_calc()
	var calc := _hub.get_station(&"calc")
	var panel: HubPanel = calc.get_panel()
	panel.open()
	for i: int in panel.get_option_ids().size():
		assert_null(panel.get_option_icon(i), "La tienda no usa iconos de opcion")
	panel.close()
