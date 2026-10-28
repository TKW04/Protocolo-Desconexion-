# Instalacion y upgrade del hub (2026-10-27, paso 5 de
# docs/propuesta-hub-mundos-4-6.md §3; HubUpdateInstall, HubRoom.apply_update_install,
# FolderStation). Secuencia de §3.1 (pausa, barra de 3 s, destello, la pagina 2
# pasa a su forma final con M4 y M5, se abre la 3 con M6, linea importante de
# Notas y control devuelto); instalar solo marca «sin guardar»; M4 disponible
# («Próximamente»), M5 y M6 bloqueadas con «Sin descargar» + «Completa el mundo
# anterior»; candado de 5 ranuras de M6; pieza 4 del fondo hidden -> off; album
# «El Chat» al instalar; game over sin guardar devuelve la pagina 2 «en
# instalacion» (y el acertijo); guardado se conserva; Kernel y Raiz conservan el
# upgrade; un guardado v5 con 3-boss carga con el acertijo pendiente.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_update_install.json"
const T: float = 64.0
const X0: float = 1280.0
const FLOOR_Y: float = 576.0
const UPGRADE: StringName = &"hub_update_4_6"
const ALL: Array[StringName] = [&"pulse", &"laser", &"debug", &"dash", &"ground_pound", &"compress"]

var _hub: HubRoom
var _isak: Isak
var _input: PlayerInput
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in ALL:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	# La linea de Eco al entrar en la pagina 2 (paso 6) pausa el juego: aqui se
	# da por vista (se prueba en tests/test_hub_update_texts.gd).
	GameState.mark_notice_seen(&"hub_update_intro")
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])


# --- Utilidades ---

func _obtain() -> void:
	for ability: StringName in ALL:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)


func _spawn() -> HubRoom:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_isak = _hub.get_isak()
	_input = PlayerInput.new()
	_isak.input = _input
	return _hub


## Tras vencer a La Curadora, con todo obtenido.
func _setup() -> void:
	_obtain()
	GameState.mark_level_completed(&"3-boss")
	_spawn()


func _ids() -> Array[String]:
	var out: Array[String] = []
	for id: StringName in _hub.get_folder_ids():
		out.append(String(id))
	return out


func _close_line() -> void:
	var box: EcoTextBox = _hub.get_text_box()
	box.finish_typing()
	box.confirm()
	box.advance(1.0)
	await get_tree().process_frame
	await get_tree().process_frame


## Pulso al instalador con 3/3 (sin recorrer el acertijo: lo prueba
## tests/test_hub_update_puzzle.gd).
func _request_install() -> HubUpdateInstall:
	var puzzle: HubUpdatePuzzle = _hub.get_update_puzzle()
	for id: StringName in puzzle.get_check_ids():
		puzzle.get_check(id).complete()
	_isak.global_position = Vector2(X0 + 8.0 * T, FLOOR_Y)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(3)
	_hub.finish_page_slide()
	await wait_physics_frames(2)
	_input.pulse_pressed = true
	await wait_physics_frames(2)
	_input.pulse_pressed = false
	await wait_physics_frames(30)
	return _hub.get_update_install()


## Instalacion completa (barra, destello y linea de Notas).
func _install_through_sequence() -> HubUpdateInstall:
	var install: HubUpdateInstall = await _request_install()
	install.advance(install.get_bar_s() + 0.01)
	install.advance(install.get_flash_s() + 0.01)
	await _close_line()
	await get_tree().process_frame
	return install


func _stand_on_shelf(id: StringName) -> FolderStation:
	var folder: FolderStation = _hub.get_folder(id)
	_isak.global_position = Vector2(folder.position.x + folder.get_size().x * 0.5, _hub.get_shelf_top_y())
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(4)
	_hub.finish_page_slide()
	await wait_physics_frames(4)
	folder.advance(0.1)
	return folder


# --- Secuencia de §3.1 ---

func test_install_sequence_pauses_fills_the_bar_and_rebuilds_the_hub() -> void:
	_setup()
	assert_eq(_hub.get_page_count(), 2, "Antes: pagina 1 y la 2 en instalacion")
	assert_eq(_ids(), ["m1", "m2", "m3"] as Array[String])
	var install: HubUpdateInstall = await _request_install()
	assert_not_null(install, "El pulso con 3/3 empieza la instalacion")
	assert_eq(install.get_step(), HubUpdateInstall.Step.BAR)
	assert_true(get_tree().paused, "Momento de historia: el juego se pausa")
	assert_true(_hub.blocks_pause_menu(), "Sin menu de pausa durante la instalacion")
	assert_eq(install.get_bar_text(), "Instalando… No apagues el dispositivo")
	assert_almost_eq(install.get_bar_s(), 3.0, 0.001, "Barra de 3 s")
	var fill: float = install.get_bar_fill()
	assert_lt(fill, 1.0)
	install.advance(0.3)
	assert_almost_eq(install.get_bar_fill(), fill + 0.1, 0.01, "Se llena con el tiempo real")
	assert_false(GameState.has_hub_upgrade(UPGRADE), "Aun no instalado")
	assert_not_null(_hub.get_update_puzzle())
	install.advance(install.get_bar_s())
	assert_eq(install.get_step(), HubUpdateInstall.Step.FLASH, "Destello")
	assert_true(GameState.has_hub_upgrade(UPGRADE), "Instalado en el destello")
	assert_true(GameState.has_unsaved_changes(), "Solo marca «sin guardar»")
	assert_null(_hub.get_update_puzzle(), "Las piezas del acertijo desaparecen")
	assert_false(_isak.hub_gestures, "Sin acertijo, sin gestos en el hub")
	assert_eq(_hub.get_page_count(), 3, "Se abre la pagina 3")
	assert_eq(_hub.get_page_state(2), HubRoom.PAGE_OPEN, "Pagina 2 en su forma final")
	assert_eq(_hub.get_size_tiles(), Vector2i(60, 11))
	assert_eq(_ids(), ["m1", "m2", "m3", "m4", "m5", "m6"] as Array[String], "Carpetas M4, M5 y M6")
	assert_not_null(_hub.get_installer_decor(), "El instalador queda como decorado apagado")
	assert_null(_hub.get_edge_glitch(), "Sin glitch del borde")
	assert_not_null(_hub.get_page_indicator(3), "Indicador de 3 puntos")
	assert_eq(_hub.get_page_indicator(2).count, 3)
	assert_eq(_hub.get_page_indicator(1).loading_page, 0, "Ningun punto cargando")
	assert_eq(_hub.get_current_page(), 2, "Isak sigue en la pagina 2")
	assert_true(get_tree().paused, "Sigue en pausa")
	install.advance(install.get_flash_s() + 0.01)
	assert_eq(install.get_step(), HubUpdateInstall.Step.NOTAS)
	var box: EcoTextBox = _hub.get_text_box()
	assert_eq(box.get_speaker_id(), &"notas", "Habla Notas")
	assert_true(box.is_important(), "Linea importante")
	assert_eq(box.get_text(), "¡Tres carpetas nuevas! Las apunto. Una ya se puede abrir.")
	await _close_line()
	await get_tree().process_frame
	assert_true(install.is_done(), "Termina")
	assert_false(get_tree().paused, "Se suelta el control")
	assert_false(_hub.is_update_installing())
	assert_almost_eq(_isak.global_position.x, X0 + 8.0 * T, 2.0, "Isak junto al instalador")


func test_folders_on_their_pages_and_states() -> void:
	_setup()
	await _install_through_sequence()
	var m4: FolderStation = _hub.get_folder(&"m4")
	var m5: FolderStation = _hub.get_folder(&"m5")
	var m6: FolderStation = _hub.get_folder(&"m6")
	assert_eq(m4.position.x, X0 + 4.0 * T, "M4 en la columna 4 de la pagina 2")
	assert_eq(m5.position.x, X0 + 14.0 * T, "M5 en la columna 14 de la pagina 2")
	assert_eq(m6.position.x, 2.0 * X0 + 9.0 * T, "M6 en la columna 9 de la pagina 3")
	assert_eq(m4.get_folder_state(), HubWorlds.STATE_AVAILABLE, "M4 disponible al instalar")
	assert_eq(m5.get_folder_state(), HubWorlds.STATE_LOCKED, "M5 bloqueada hasta 4-boss")
	assert_eq(m6.get_folder_state(), HubWorlds.STATE_LOCKED, "M6 bloqueada hasta 5-boss")
	assert_eq(m5.get_folder_animation(), &"locked", "Silueta gris con candado")
	assert_false(m5.is_miniature_visible(), "Sin miniatura")
	# M4 se abre con sus subniveles (desde el paso 11 de docs/propuesta-mundo-4.md, el 4-1 jugable; antes,
	# «Próximamente» sin niveles).
	var folder: FolderStation = await _stand_on_shelf(&"m4")
	assert_true(folder.is_key_hint_visible(), "Tecla del pulso")
	assert_false(folder.is_locked_condition_visible())
	assert_true(folder.open(_isak), "M4 abre su panel")
	var panel: FolderPanel = folder.get_folder_panel()
	assert_eq(panel.get_title(), "Mundo 4 - El Chat")
	assert_true(panel.get_option_ids().has(&"4-1"), "El 4-1 en la carpeta: %s" % [panel.get_option_ids()])
	assert_eq(panel.level_text(HubWorlds.levels(HubWorlds.world(&"m4"))[0]), "4-1 Chats recientes - Nuevo")
	folder.close(true)
	await wait_physics_frames(2)
	# M5: «Sin descargar» + la condicion.
	folder = await _stand_on_shelf(&"m5")
	assert_true(folder.is_locked_hint_visible(), "Sin descargar")
	assert_eq(folder.get_locked_hint_text(), "Sin descargar")
	assert_true(folder.is_locked_condition_visible(), "Segunda linea")
	assert_eq(folder.get_locked_condition_text(), "Completa el mundo anterior")
	assert_false(folder.open(_isak), "Bloqueada: no abre")
	assert_false(folder.is_cloud_lock_visible(), "M5 no tiene candado de ranuras")
	# M6: igual y con el candado de 5 ranuras.
	folder = await _stand_on_shelf(&"m6")
	assert_eq(_hub.get_current_page(), 3)
	assert_true(folder.is_locked_condition_visible())
	assert_eq(folder.get_locked_condition_text(), "Completa el mundo anterior")
	assert_true(folder.is_cloud_lock_visible(), "Candado de La Nube")
	assert_eq(folder.get_lock_slot_count(), 5)
	assert_eq(folder.get_lock_slots_lit(), 0)
	GameState.obtain_memory(&"boss_w1_l1")
	GameState.obtain_memory(&"boss_w2_l1")
	GameState.obtain_memory(&"boss_w3_l1")
	assert_eq(folder.get_lock_slots_lit(), 3, "Una ranura por cada recuerdo de jefe")


func test_locked_m1_m3_keep_a_single_line() -> void:
	_obtain()
	_spawn()
	var folder: FolderStation = await _stand_on_shelf(&"m2")
	assert_true(folder.is_locked_hint_visible())
	assert_false(folder.is_locked_condition_visible(), "M2 y M3 sin segunda linea (no cambian)")


func test_piece_4_hidden_until_installed_then_blinking() -> void:
	_setup()
	assert_eq(_hub.get_piece_animation(4), &"hidden", "Pieza coral oculta con M4 oculto")
	await _install_through_sequence()
	assert_eq(_hub.get_piece_animation(4), &"off", "Contorno que parpadea: M4 disponible")
	_spawn()
	assert_eq(_hub.get_piece_animation(4), &"off", "Al volver al hub, igual (hasta completar M4)")


func test_album_el_chat_opens_on_install() -> void:
	_setup()
	assert_true(HubWorlds.is_requires_upgrade_enforced(), "El requisito se aplica (paso 5)")
	assert_false(HubWorlds.is_world_unlocked(HubWorlds.world(&"m4")), "M4 oculto tras La Curadora")
	assert_false(NotasAlbum.is_world_visited(4), "«El Chat» cerrada hasta instalar")
	await _install_through_sequence()
	assert_true(NotasAlbum.is_world_visited(4), "«El Chat» se abre al instalar")
	assert_false(NotasAlbum.is_world_visited(5), "«La Tienda» sigue cerrada")


# --- Guardado, game over y vueltas ---

func test_game_over_without_saving_returns_the_page_to_installing() -> void:
	_obtain()
	GameState.mark_level_completed(&"3-boss")
	assert_true(GameState.save_game(), "Copia tras La Curadora, sin upgrade")
	_spawn()
	await _install_through_sequence()
	assert_true(GameState.has_hub_upgrade(UPGRADE))
	_hub.free()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.has_hub_upgrade(UPGRADE), "Sin guardar se pierde")
	GameState.recover_trash()
	_spawn()
	assert_eq(_hub.get_page_count(), 2, "Vuelve la pagina 2")
	assert_eq(_hub.get_page_state(2), HubRoom.PAGE_INSTALLING, "«En instalacion»")
	assert_not_null(_hub.get_update_puzzle(), "El acertijo se repite")
	assert_eq(_hub.get_update_puzzle().get_done_count(), 0, "Desde 0/3")
	assert_eq(_ids(), ["m1", "m2", "m3"] as Array[String], "Sin M4-M6")
	assert_null(_hub.get_installer_decor())


func test_saved_upgrade_survives_a_game_over() -> void:
	_setup()
	await _install_through_sequence()
	assert_true(GameState.save_game(), "Guardado en Notas")
	_hub.free()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.has_hub_upgrade(UPGRADE), "Guardado: se conserva")
	GameState.recover_trash()
	_spawn()
	assert_eq(_hub.get_page_count(), 3)
	assert_null(_hub.get_update_puzzle(), "Sin acertijo")
	assert_eq(_ids(), ["m1", "m2", "m3", "m4", "m5", "m6"] as Array[String])


func test_kernel_and_root_keep_the_upgrade_and_skip_the_puzzle() -> void:
	_obtain()
	GameState.mark_level_completed(&"3-boss")
	assert_true(GameState.install_hub_upgrade(UPGRADE))
	for lap: int in [GameState.LAP_NORMAL, GameState.LAP_HARD]:
		GameState.lap = lap
		assert_true(GameState.save_game())
		assert_true(GameState.load_game())
		_spawn()
		assert_eq(_hub.get_page_count(), 3, "Acceso %d: las tres paginas desde el principio" % lap)
		assert_null(_hub.get_update_puzzle(), "Acceso %d: el acertijo no se repite" % lap)
		assert_not_null(_hub.get_folder(&"m6"), "Acceso %d: M6 visible" % lap)


func test_v5_save_with_3_boss_loads_with_the_puzzle_pending() -> void:
	var data: Dictionary = {
		"version": 5,
		"lap": 1,
		"completed_levels": ["1-1", "1-2", "1-3", "1-boss", "2-1", "2-2", "2-3", "2-boss", "3-1", "3-2", "3-3", "3-boss"],
		"allies_met": ["eco", "notas", "calc"],
		"abilities_obtained": ["pulse", "laser", "debug", "dash", "ground_pound", "compress"],
		"nickname": "Isak",
	}
	assert_true(SaveFile.write(PATH, data), "Guardado v5 escrito")
	GameState.use_save_path(PATH, false)
	assert_true(GameState.started_from_save)
	assert_true(HubWorlds.is_hub_upgrade_pending(), "Acertijo pendiente al cargar")
	assert_eq(HubWorlds.folder_state(HubWorlds.world(&"m4")), HubWorlds.STATE_HIDDEN, "M4 espera al upgrade")
	_spawn()
	assert_eq(_hub.get_page_state(2), HubRoom.PAGE_INSTALLING)
	assert_not_null(_hub.get_update_puzzle(), "Se encuentra el acertijo")
	assert_not_null(_hub.get_edge_glitch(), "Glitch del borde de la pagina 1")
