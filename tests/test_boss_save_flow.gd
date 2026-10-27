# Pruebas de conjunto del jefe Alerta Mayor (paso 15 de
# docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21): la victoria en la arena
# real (LevelRunner) vuelve al hub, se guarda en Notas (su panel, save_now) y al
# arrancar otra vez con esa partida (hub, started_from_save) siguen la capa
# boss_w1_l1 (sin leer: placa de Notas), el 1-boss completado, el Mundo 2
# desbloqueado con «Próximamente» y la pieza cian encendida (sin volver a
# animarse); un game over en la revancha (rollback a esa copia) no quita nada de
# lo guardado. El flujo hub -> arena -> recompensa -> hub sin guardar y el game
# over sin guardar estan en test_hub_boss_entry.gd y test_boss_reward.gd; la
# pelea entera con el Isak real, en test_boss_bot.gd. Usa su propia ruta de
# guardado.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_boss_save_flow.json"
const DT: float = 1.0 / 60.0
const LONG_STEP_S: float = 5.0

var _saved_path: String
var _saved_abilities: Dictionary = {}
var _main: LevelRunner


func before_all() -> void:
	EcoTextBox.pause_important = false
	BossReward.pause_tree = false
	BossDefeat.freeze_tree = false


func after_all() -> void:
	EcoTextBox.pause_important = true
	BossReward.pause_tree = true
	BossDefeat.freeze_tree = true


func before_each() -> void:
	_saved_path = GameState.save_path
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		_saved_abilities[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()


func after_each() -> void:
	_free_main()
	get_tree().paused = false
	DebugMode.reset()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.started_from_save = false
	GameState.save_path = _saved_path
	for ability: StringName in _saved_abilities:
		GameState.set_ability_unlocked(ability, _saved_abilities[ability])
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _free_main() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null


## Progreso de quien acaba de completar el 1-3 (como la terminal del 1-3).
func _after_1_3() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	for id: StringName in [&"1-1", &"1-2", &"1-3"]:
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"1-boss")


## Vence en la arena real (golpes directos al jefe: la pelea con el Isak real es
## del bot) y sigue el flujo de la derrota hasta el hub con la pieza encendida.
func _win_and_return_to_hub() -> HubRoom:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.start_level_id = "1-boss"
	add_child(_main)
	var boss := _main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	boss.start()
	while not boss.is_defeated():
		boss.take_core_hit(1)
	await wait_physics_frames(2)
	var defeat: BossDefeat = boss.get_defeat()
	var t: float = 0.0
	while t < 30.0 and not _main.is_in_hub():
		if is_instance_valid(defeat) and defeat.get_reward() != null and defeat.get_reward().can_close():
			defeat.get_reward().confirm()
		await wait_physics_frames(1)
		t += DT
	assert_true(_main.is_in_hub(), "Vuelve al hub tras vencer")
	var hub: HubRoom = _main.get_hub()
	t = 0.0
	while t < 10.0 and (not hub.has_arrived() or hub.is_piece_pending() or hub.is_piece_lighting()):
		await wait_physics_frames(1)
		t += DT
	return hub


## Guarda como Notas: su panel, save_now (lo que hace «Guardar» con el pulso).
func _save_in_notas(hub: HubRoom) -> void:
	var notas: NotasStation = hub.get_notas()
	assert_true(notas.is_powered(), "Notas encendida")
	assert_true(notas.open(hub.get_isak()), "Se abre Notas")
	assert_true(notas.get_notas_panel().save_now(), "Notas guarda")
	notas.close(true)
	assert_false(GameState.has_unsaved_changes(), "Todo guardado")


func test_saved_victory_survives_a_restart_in_the_hub() -> void:
	_after_1_3()
	var hub: HubRoom = await _win_and_return_to_hub()
	assert_eq(hub.get_background_state(), &"on", "Pieza cian encendida tras vencer")
	assert_true(GameState.has_memory(&"boss_w1_l1") and GameState.has_unsaved_changes(), "Recuerdo sin guardar")
	_save_in_notas(hub)
	_free_main()
	# Otra sesion: se carga el guardado y se arranca en el hub, como al abrir el juego.
	GameState.reset_progress()
	assert_false(GameState.has_memory(&"boss_w1_l1"))
	assert_true(GameState.load_game(), "Carga la partida")
	GameState.started_from_save = true
	_main = MAIN_SCENE.instantiate() as LevelRunner
	add_child(_main)
	var t: float = 0.0
	while t < 10.0 and not (_main.is_in_hub() and _main.get_hub().has_arrived()):
		await wait_physics_frames(1)
		t += DT
	assert_true(_main.is_in_hub(), "Con partida guardada se arranca en el hub")
	var hub2: HubRoom = _main.get_hub()
	assert_true(GameState.is_level_completed(&"1-boss"), "1-boss completado")
	assert_true(GameState.has_memory(&"boss_w1_l1"), "La capa Caché sigue")
	assert_true(GameState.has_unread_memories(), "Sin leer")
	assert_true(hub2.get_notas().is_unread_badge_visible(), "Placa de recuerdo nuevo en Notas")
	assert_false(GameState.has_unsaved_changes(), "Nada sin guardar al cargar")
	var m2: Dictionary = HubWorlds.world(&"m2")
	assert_true(HubWorlds.is_world_unlocked(m2), "Mundo 2 desbloqueado")
	assert_ne(HubWorlds.folder_state(m2), HubWorlds.STATE_LOCKED)
	var panel := FolderPanel.new()
	panel.world_entry = m2
	add_child_autofree(panel)
	panel.refresh()
	# Desde el paso 11 del Mundo 2 (2026-10-22) el 2-1 es jugable, desde el 13 el 2-2 (bloqueado hasta
	# completar el 2-1), desde el 14 el 2-3 (tras el 2-2) y desde el 18 (2026-10-23) el jefe, tras el 2-3.
	assert_eq(panel.get_level_state(&"2-1"), HubWorlds.STATE_AVAILABLE, "El 2-1, disponible")
	assert_eq(panel.level_text(HubWorlds.levels(m2)[1]), "2-2 Un video más - Bloqueado", "El 2-2, tras el 2-1")
	assert_eq(panel.level_text(HubWorlds.levels(m2)[2]), "2-3 Scroll infinito - Bloqueado", "El 2-3, tras el 2-2")
	assert_eq(panel.level_text(HubWorlds.levels(m2)[3]), "Jefe: Autoplay - Bloqueado",
		"El jefe del Mundo 2, tras el 2-3")
	assert_eq(HubWorlds.folder_state(HubWorlds.world(&"m1")), HubWorlds.STATE_COMPLETED, "Carpeta del Mundo 1")
	assert_eq(hub2.get_background_state(), &"on", "La pieza sigue encendida")
	assert_false(hub2.light_piece_on_arrival, "Sin volver a animarla")


func test_game_over_in_the_rematch_keeps_the_saved_victory() -> void:
	_after_1_3()
	var hub: HubRoom = await _win_and_return_to_hub()
	_save_in_notas(hub)
	_free_main()
	# Revancha: se entra de nuevo y se pierden las tres vidas.
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-boss"
	add_child(_main)
	_main.advance(LONG_STEP_S)
	var boss := _main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	boss.start()
	var reports: Array = []
	_main.game_over.connect(func(report: Dictionary) -> void: reports.append(report))
	for i: int in 3:
		await wait_physics_frames(2)
		GameState.sync_rate = GameState.SYNC_RATE_MIN
		_main.advance(_main.get_death_wait_s() + 0.01)
		_main.advance(LONG_STEP_S)
		_main.advance(LONG_STEP_S)
	assert_eq(reports.size(), 1, "Un game over")
	assert_true(_main.is_in_hub(), "Al hub")
	assert_true(GameState.is_level_completed(&"1-boss"), "Lo guardado se conserva: el jefe sigue vencido")
	assert_true(GameState.has_memory(&"boss_w1_l1"), "Y su recuerdo")
	assert_true(HubWorlds.is_world_unlocked(HubWorlds.world(&"m2")), "Y el Mundo 2")
	assert_eq(GameState.lap, 1, "Sin cambio de vuelta")


## Paso 18 de docs/propuesta-mundo-2.md (2026-10-23): la victoria sobre Autoplay
## (capa boss_w2_l1 sin guardar) se guarda en Notas y al arrancar otra vez en el
## hub siguen el 2-boss completado, la capa, la pieza ambar encendida (sin volver
## a animarse) y el Mundo 3 desbloqueado.
func test_saved_autoplay_victory_survives_a_restart_in_the_hub() -> void:
	_after_1_3()
	GameState.mark_level_completed(&"1-boss")
	for id: StringName in [&"2-1", &"2-2", &"2-3"]:
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"2-boss")
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.start_level_id = "2-boss"
	add_child(_main)
	var boss := _main.get_level().get_node(^"Objects/autoplay") as Autoplay
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	boss.start()
	while not boss.is_defeated():
		boss.take_core_hit(1)
	await wait_physics_frames(2)
	var defeat: BossDefeat = boss.get_defeat()
	var t: float = 0.0
	while t < 30.0 and not _main.is_in_hub():
		if is_instance_valid(defeat) and defeat.get_reward() != null and defeat.get_reward().can_close():
			defeat.get_reward().confirm()
		await wait_physics_frames(1)
		t += DT
	assert_true(_main.is_in_hub(), "Vuelve al hub tras vencer a Autoplay")
	var hub: HubRoom = _main.get_hub()
	t = 0.0
	while t < 10.0 and (not hub.has_arrived() or hub.is_piece_pending() or hub.is_piece_lighting()):
		await wait_physics_frames(1)
		t += DT
	assert_eq(hub.get_piece_animation(2), &"on", "Pieza ambar encendida")
	assert_true(GameState.has_memory(&"boss_w2_l1") and GameState.has_unsaved_changes(), "Recuerdo sin guardar")
	_save_in_notas(hub)
	_free_main()
	GameState.reset_progress()
	assert_true(GameState.load_game(), "Carga la partida")
	GameState.started_from_save = true
	_main = MAIN_SCENE.instantiate() as LevelRunner
	add_child(_main)
	t = 0.0
	while t < 10.0 and not (_main.is_in_hub() and _main.get_hub().has_arrived()):
		await wait_physics_frames(1)
		t += DT
	var hub2: HubRoom = _main.get_hub()
	assert_true(GameState.is_level_completed(&"2-boss"), "2-boss completado")
	assert_true(GameState.has_memory(&"boss_w2_l1"), "La capa Caché del Mundo 2 sigue")
	assert_eq(hub2.get_piece_animation(2), &"on", "La pieza ambar sigue encendida")
	assert_false(hub2.light_piece_on_arrival, "Sin volver a animarla")
	assert_true(HubWorlds.is_world_unlocked(HubWorlds.world(&"m3")), "Mundo 3 desbloqueado")


## Paso 17 de docs/propuesta-mundo-3.md (2026-10-27): la victoria sobre La
## Curadora (capa boss_w3_l1 sin guardar) se guarda en Notas y al arrancar otra
## vez en el hub siguen el 3-boss completado, la capa, la pieza verde encendida
## (sin volver a animarse) y el acertijo del hub pendiente (M4 oculto hasta instalar).
func test_saved_curator_victory_survives_a_restart_in_the_hub() -> void:
	_after_1_3()
	for id: StringName in [&"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2", &"3-3"]:
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"3-boss")
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.start_level_id = "3-boss"
	add_child(_main)
	var boss := _main.get_level().get_node(^"Objects/curator") as Curator
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	if not boss.is_fighting():
		boss.start()
	var guard: int = 0
	while not boss.is_defeated() and guard < 40:
		boss.take_core_hit(1)
		guard += 1
	await wait_physics_frames(2)
	var defeat: BossDefeat = boss.get_defeat()
	var t: float = 0.0
	while t < 30.0 and not _main.is_in_hub():
		if is_instance_valid(defeat) and defeat.get_reward() != null and defeat.get_reward().can_close():
			defeat.get_reward().confirm()
		await wait_physics_frames(1)
		t += DT
	assert_true(_main.is_in_hub(), "Vuelve al hub tras vencer a La Curadora")
	var hub: HubRoom = _main.get_hub()
	t = 0.0
	while t < 10.0 and (not hub.has_arrived() or hub.is_piece_pending() or hub.is_piece_lighting()):
		await wait_physics_frames(1)
		t += DT
	assert_eq(hub.get_piece_animation(3), &"on", "Pieza verde encendida")
	assert_true(GameState.has_memory(&"boss_w3_l1") and GameState.has_unsaved_changes(), "Recuerdo sin guardar")
	_save_in_notas(hub)
	_free_main()
	GameState.reset_progress()
	assert_false(GameState.has_memory(&"boss_w3_l1"))
	assert_true(GameState.load_game(), "Carga la partida")
	GameState.started_from_save = true
	_main = MAIN_SCENE.instantiate() as LevelRunner
	add_child(_main)
	t = 0.0
	while t < 10.0 and not (_main.is_in_hub() and _main.get_hub().has_arrived()):
		await wait_physics_frames(1)
		t += DT
	var hub2: HubRoom = _main.get_hub()
	assert_true(GameState.is_level_completed(&"3-boss"), "3-boss completado")
	assert_true(GameState.has_memory(&"boss_w3_l1"), "La capa Caché del Mundo 3 sigue")
	assert_true(hub2.get_notas().is_unread_badge_visible(), "Placa «!» en Notas: sin leer")
	assert_eq(hub2.get_piece_animation(3), &"on", "La pieza verde sigue encendida")
	assert_eq(hub2.get_piece_animation(2), &"on", "Y la ambar")
	assert_false(hub2.light_piece_on_arrival, "Sin volver a animarla")
	assert_true(HubWorlds.is_hub_upgrade_pending(), "Acertijo del hub pendiente (paso 5 de la propuesta 4-6)")
	assert_eq(HubWorlds.folder_state(HubWorlds.world(&"m4")), HubWorlds.STATE_HIDDEN, "Mundo 4 oculto hasta instalar")
	assert_eq(hub2.get_page_state(2), HubRoom.PAGE_INSTALLING, "Pagina 2 «en instalacion» al cargar")
	assert_false(NotasAlbum.is_world_visited(4), "«El Chat» cerrada en el album hasta instalar")
