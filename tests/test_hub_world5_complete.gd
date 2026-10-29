# El Vendedor en el hub y el fondo completo (paso 18 de docs/propuesta-mundo-5.md
# §8, §4.6 y §5.9, 2026-10-29): la fila «Jefe: El Vendedor» de la carpeta M5 es
# jugable tras el 5-3; vencerlo entrega boss_w5_l1 sin guardar (BossReward.grant(5,
# vuelta)), enciende la QUINTA pieza del fondo en blanco (#ffffff) y con ella la
# foto queda COMPLETA (destello que recorre las cinco piezas, wallpaper_completed),
# enciende la quinta ranura del candado de M6, que se abre (animacion) cuando la
# camara llega a la pagina 3, y deja M6 «La Nube» disponible («Próximamente», sin
# subniveles). La barra del jefe es el ticket con las fichas. Un game over sin
# guardar lo deshace todo. Usa su propia ruta de guardado.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PATH: String = "user://test_hub_world5_complete.json"
const LONG_STEP_S: float = 5.0
const DT: float = 1.0 / 60.0
const CACHE_LAYERS: Array[StringName] = [&"boss_w1_l1", &"boss_w2_l1", &"boss_w3_l1", &"boss_w4_l1"]

var _hub: HubRoom
var _saved_path: String
var _saved_pulse: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	EcoTextBox.pause_important = true
	BossReward.pause_tree = true
	BossDefeat.freeze_tree = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


# --- Utilidades ---

func _m5() -> Dictionary:
	return HubWorlds.world(&"m5")


func _m6() -> Dictionary:
	return HubWorlds.world(&"m6")


func _row(world_entry: Dictionary, id: String) -> Dictionary:
	for level: Dictionary in HubWorlds.levels(world_entry):
		if String(level.get("id", "")) == id:
			return level
	return {}


## Lo mismo que LevelRunner._record_completion al terminar cada nivel.
func _complete(id: String) -> void:
	GameState.unlock_level(StringName(id))
	GameState.mark_level_completed(StringName(id))
	var path: String = "res://data/levels/%s.json" % id
	if not FileAccess.file_exists(path):
		return
	var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	for unlock: Variant in (level as Dictionary).get("unlocks", []):
		if String((unlock as Dictionary).get("type", "")) == "level":
			GameState.unlock_level(StringName(String((unlock as Dictionary).get("id", ""))))


## Mundos 1-4 completos (jefes incluidos), la actualizacion del hub instalada y
## el 5-1 a 5-3 como sus terminales; las capas Caché de los cuatro primeros jefes.
func _complete_worlds_1_4_and_5_3() -> void:
	for id: String in ["1-1", "1-2", "1-3", "1-boss", "2-1", "2-2", "2-3", "2-boss", "3-1", "3-2", "3-3", "3-boss"]:
		_complete(id)
	GameState.install_hub_upgrade(&"hub_update_4_6")
	for id: String in ["4-1", "4-2", "4-3", "4-boss", "5-1", "5-2", "5-3"]:
		_complete(id)
	for id: StringName in CACHE_LAYERS:
		GameState.obtain_memory(id)


func _new_hub() -> HubRoom:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = HUB_SCENE.instantiate() as HubRoom
	return _hub


func _start_main(level_id: String) -> LevelRunner:
	var main := MAIN_SCENE.instantiate() as LevelRunner
	main.auto_advance = false
	main.start_level_id = level_id
	add_child_autofree(main)
	main.advance(LONG_STEP_S)
	return main


# --- Filas y estados ---

func test_vendor_row_is_playable_after_5_3_and_world_6_waits_for_it() -> void:
	var boss: Dictionary = _row(_m5(), "5-boss")
	assert_true(HubWorlds.is_boss(boss))
	assert_true(HubWorlds.is_playable(boss), "playable: true desde el paso 18")
	assert_false(HubWorlds.is_coming_soon(boss))
	var panel := FolderPanel.new()
	panel.world_entry = _m5()
	add_child_autofree(panel)
	for id: String in ["1-1", "1-2", "1-3", "1-boss", "2-1", "2-2", "2-3", "2-boss", "3-1", "3-2", "3-3", "3-boss"]:
		_complete(id)
	GameState.install_hub_upgrade(&"hub_update_4_6")
	for id: String in ["4-1", "4-2", "4-3", "4-boss", "5-1", "5-2"]:
		_complete(id)
	assert_eq(panel.level_text(boss), "Jefe: El Vendedor - Bloqueado", "Antes del 5-3")
	assert_false(HubWorlds.can_enter(&"5-boss"))
	_complete("5-3")
	assert_eq(panel.level_text(boss), "Jefe: El Vendedor - Nuevo", "Tras el 5-3")
	assert_true(HubWorlds.can_enter(&"5-boss"))
	assert_eq(HubWorlds.folder_state(_m5()), HubWorlds.STATE_AVAILABLE, "Sin el jefe la carpeta no se completa")
	assert_eq(HubWorlds.folder_state(_m6()), HubWorlds.STATE_LOCKED, "M6 «Sin descargar» antes de El Vendedor")
	GameState.mark_level_completed(&"5-boss")
	assert_eq(HubWorlds.folder_state(_m5()), HubWorlds.STATE_COMPLETED, "M5 completada con el jefe")
	assert_eq(HubWorlds.folder_state(_m6()), HubWorlds.STATE_AVAILABLE, "M6 disponible al vencer a El Vendedor")
	assert_true(HubWorlds.levels(_m6()).is_empty(), "M6 sin subniveles: «Próximamente»")


func test_white_piece_hidden_then_blinking_then_lit_and_the_wallpaper_complete() -> void:
	for id: String in ["1-1", "1-2", "1-3", "1-boss", "2-1", "2-2", "2-3", "2-boss", "3-1", "3-2", "3-3", "3-boss"]:
		_complete(id)
	GameState.install_hub_upgrade(&"hub_update_4_6")
	add_child(_new_hub())
	assert_eq(_hub.get_piece_animation(5), &"hidden", "M5 bloqueado: la pieza 5 es una gris mas")
	assert_false(_hub.is_wallpaper_complete())
	_complete_worlds_1_4_and_5_3()
	add_child(_new_hub())
	assert_eq(_hub.get_piece_animation(5), &"off", "M5 disponible: contorno blanco")
	assert_false(_hub.is_wallpaper_complete(), "Falta la pieza 5")
	GameState.mark_level_completed(&"5-boss")
	add_child(_new_hub())
	assert_eq(_hub.get_piece_animation(5), &"on", "El Vendedor vencido: pieza blanca encendida")
	for world: int in [2, 3, 4]:
		assert_eq(_hub.get_piece_animation(world), &"on", "La pieza %d sigue encendida" % world)
	assert_true(_hub.is_wallpaper_complete(), "Las cinco piezas: el fondo esta completo")
	assert_false(_hub.is_wallpaper_completing(), "Sin llegar del jefe no hay destello")
	var frames: SpriteFrames = _hub.get_piece_sprite(5).sprite_frames
	assert_true(frames.has_animation(&"complete"), "Animacion del fondo completo")
	assert_eq(frames.get_frame_count(&"complete"), 5, "Un cuadro por pieza")
	assert_false(frames.get_animation_loop(&"complete"), "Una sola vez")
	var on_tex: Texture2D = frames.get_frame_texture(&"on", 0)
	var img: Image = on_tex.get_image()
	var white: int = 0
	for y: int in range(0, img.get_height(), 4):
		for x: int in range(0, img.get_width(), 4):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5 and c.r8 == 255 and c.g8 == 255 and c.b8 == 255:
				white += 1
	assert_gt(white, 100, "La pieza 5 encendida es blanca (#ffffff)")


func test_the_lock_waits_for_page_3_and_then_opens() -> void:
	_complete_worlds_1_4_and_5_3()
	GameState.mark_level_completed(&"5-boss")
	GameState.obtain_memory(&"boss_w5_l1")
	# Sin llegar del jefe: M6 disponible y sin candado.
	add_child(_new_hub())
	var m6: FolderStation = _hub.get_folder(&"m6")
	assert_eq(m6.get_lock_slots_lit(), 5, "Cinco ranuras encendidas")
	assert_false(m6.is_locked(), "M6 disponible")
	assert_false(m6.is_cloud_lock_visible(), "Sin el destello de la llegada, ya abierto")
	# Llegando tras la victoria: el candado espera cerrado hasta la pagina 3.
	_hub.free()
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.light_piece_on_arrival = true
	_hub.light_piece_world = 5
	add_child(_hub)
	m6 = _hub.get_folder(&"m6")
	assert_true(m6.is_lock_open_pending(), "Pendiente de abrirse")
	assert_true(m6.is_cloud_lock_visible(), "Se ve cerrado, con las cinco ranuras")
	watch_signals(m6)
	assert_true(_hub.slide_to_page(2))
	_hub.finish_page_slide()
	assert_true(m6.is_lock_open_pending(), "En la pagina 2 sigue esperando")
	assert_true(_hub.slide_to_page(3))
	_hub.finish_page_slide()
	assert_eq(_hub.get_current_page(), 3)
	assert_true(m6.is_lock_opening(), "En la pagina 3 se abre")
	assert_false(m6.is_lock_open_pending())
	await wait_seconds(1.8)
	assert_false(m6.is_lock_opening(), "Termino de abrirse")
	assert_false(m6.is_cloud_lock_visible(), "El candado desaparece")
	assert_signal_emitted(m6, "lock_opened")


func test_game_over_without_saving_undoes_the_victory() -> void:
	_complete_worlds_1_4_and_5_3()
	GameState.save_game()
	GameState.mark_level_completed(&"5-boss")
	GameState.obtain_memory(&"boss_w5_l1")
	assert_eq(HubWorlds.folder_state(_m6()), HubWorlds.STATE_AVAILABLE)
	GameState.apply_rollback()
	assert_false(GameState.is_level_completed(&"5-boss"), "La victoria sin guardar se pierde")
	assert_false(GameState.has_memory(&"boss_w5_l1"), "La capa sin guardar se pierde")
	assert_eq(HubWorlds.folder_state(_m6()), HubWorlds.STATE_LOCKED, "M6 vuelve a «Sin descargar»")
	add_child(_new_hub())
	assert_eq(_hub.get_piece_animation(5), &"off", "La pieza 5 vuelve al contorno")
	assert_false(_hub.is_wallpaper_complete())
	assert_eq(_hub.get_folder(&"m6").get_lock_slots_lit(), 4, "Cuatro ranuras")


# --- Flujo real ---

## Terminado cuando (paso 18): desde la carpeta M5 se entra a «Jefe: El Vendedor», se vence, se recibe
## boss_w5_l1 sin guardar (panel «Recuerdo recuperado» / «Fragmento de voluntad» / «Capa: Caché») y se vuelve
## al hub con la pieza blanca encendida, el fondo completo, la quinta ranura del candado y M6 disponible.
func test_vendor_from_the_m5_folder_and_back_with_the_full_wallpaper() -> void:
	EcoTextBox.pause_important = false
	BossReward.pause_tree = false
	BossDefeat.freeze_tree = false
	EcoProgress.meet_eco_with_pulse()
	_complete_worlds_1_4_and_5_3()
	GameState.save_game()
	GameState.request_save()
	var main: LevelRunner = _start_main("hub")
	var hub: HubRoom = main.get_hub()
	var arrival: WarpVortex = hub.get_arrival_vortex()
	if arrival != null:
		arrival.advance(LONG_STEP_S)
	assert_eq(hub.get_folder(&"m6").get_lock_slots_lit(), 4, "Cuatro ranuras antes de El Vendedor")
	var folder: FolderStation = hub.get_folder(&"m5")
	assert_true(folder.open(hub.get_isak()), "La carpeta del Mundo 5 se abre")
	var panel: FolderPanel = folder.get_folder_panel()
	panel.skip_input_delay()
	assert_true(panel.select_option(&"5-boss"), "Fila del jefe elegible")
	panel.confirm()
	assert_true(panel.is_confirming_unsaved())
	assert_true(panel.select_option(FolderPanel.OPTION_ENTER_UNSAVED))
	panel.confirm()
	hub.get_departure_vortex().advance(LONG_STEP_S)
	await wait_process_frames(2)
	main.advance(LONG_STEP_S)
	main.advance(LONG_STEP_S)
	assert_eq(main.get_level_id(), "5-boss", "Entra a la arena de El Vendedor")
	assert_eq(GameState.lives, GameState.lives_max, "Tres vidas por intento")
	main.auto_advance = true
	var boss := main.get_level().get_node(^"Objects/vendor") as Vendor
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	if not boss.is_fighting():
		boss.start()
	var hud := main.get_level().get_node_or_null(^"Hud") as Hud
	assert_not_null(hud, "HUD de la arena")
	var bar: BossBar = hud.get_boss_bar() if hud != null else null
	assert_not_null(bar, "Barra del jefe")
	if bar != null:
		assert_true(bar.visible, "Barra del jefe en el HUD")
		assert_eq(bar.get_style(), "ticket", "Barra «ticket»")
		assert_eq(bar.get_struck_lines(), 0, "Nada tachado al empezar")
		assert_eq(bar.get_tokens_shown(), 12, "Las 12 fichas al lado")
		boss.set_tokens(10)
		assert_eq(bar.get_tokens_shown(), 10, "Las fichas siguen al jefe")
	var guard: int = 0
	while not boss.is_defeated() and guard < 40:
		boss.take_core_hit(1)
		guard += 1
	assert_true(boss.is_defeated(), "Golpe final (simulado con la API del jefe)")
	await wait_physics_frames(2)
	if bar != null:
		assert_eq(bar.get_segment_count(), 9, "9 golpes en Caché")
		assert_eq(bar.get_struck_lines(), 9, "Todo el ticket tachado en el golpe final")
	var defeat: BossDefeat = boss.get_defeat()
	assert_not_null(defeat, "Secuencia de derrota")
	var texts: Dictionary = {}
	var t: float = 0.0
	while t < 25.0 and is_instance_valid(defeat) and defeat.get_stage() < BossDefeat.Stage.DONE:
		var reward: BossReward = defeat.get_reward()
		if reward != null and texts.is_empty():
			for key: StringName in [&"system", &"header", &"title", &"layer", &"notice"]:
				texts[key] = reward.get_text(key)
		if reward != null and reward.can_close():
			reward.confirm()
		await wait_physics_frames(1)
		t += DT
	assert_eq(texts.get(&"header", ""), "Recuerdo recuperado")
	assert_eq(texts.get(&"title", ""), "Fragmento de voluntad")
	assert_eq(texts.get(&"layer", ""), "Capa: Caché")
	assert_eq(texts.get(&"notice", ""), "Guarda en Notas para conservarlo.")
	assert_eq(texts.get(&"system", ""), "Compra cancelada.")
	assert_true(GameState.has_memory(&"boss_w5_l1"), "Capa Caché del Mundo 5")
	assert_false(GameState.has_memory(&"boss_w5_l2"), "Solo la capa del acceso actual")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar: se guarda en Notas")
	t = 0.0
	while t < 8.0 and not main.is_in_hub():
		await wait_physics_frames(1)
		t += DT
	assert_true(main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"5-boss"))
	hub = main.get_hub()
	assert_true(hub.light_piece_on_arrival)
	assert_eq(hub.light_piece_world, 5, "Se enciende la pieza del Mundo 5")
	watch_signals(hub)
	t = 0.0
	while t < 10.0 and (hub.get_piece_animation(5) != &"on" or hub.is_piece_lighting() or hub.is_piece_pending()
			or hub.is_wallpaper_completing()):
		await wait_physics_frames(1)
		t += DT
	assert_eq(hub.get_piece_animation(5), &"on", "Pieza blanca encendida")
	assert_signal_emitted_with_parameters(hub, "wallpaper_piece_lit", [5])
	assert_signal_emitted(hub, "wallpaper_completed", "El destello recorrio la foto completa")
	assert_true(hub.is_wallpaper_complete(), "Fondo completo")
	assert_eq(HubWorlds.folder_state(_m6()), HubWorlds.STATE_AVAILABLE, "Mundo 6 disponible")
	var m6: FolderStation = hub.get_folder(&"m6")
	assert_eq(m6.get_folder_state(), HubWorlds.STATE_AVAILABLE, "Carpeta M6 disponible")
	assert_eq(m6.get_lock_slots_lit(), 5, "Quinta ranura del candado de La Nube")
	assert_true(m6.is_lock_open_pending(), "El candado se abrira en la pagina 3")
	assert_true(GameState.has_unread_memories(), "Recuerdo sin leer")
	assert_true(hub.get_notas().is_unread_badge_visible(), "Placa «!» en Notas")
