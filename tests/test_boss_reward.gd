# Golpe final y recompensa de Alerta Mayor (paso 10 de
# docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21; paso 5 de
# docs/propuesta-recuerdos.md): BossReward entrega la capa Caché boss_w1_l1 SIN
# GUARDAR (y las inferiores que falten: red de seguridad; la revancha no
# entrega nada), panel con «Capa: Caché» y «Guarda en Notas para conservarlo.»;
# BossDefeat: congelacion, desarme en pixeles, recompensa, linea de derrota y
# vortice que emite level_completed (sin rollback ni cambio de vuelta); con
# LevelRunner, vuelta al hub con 1-boss completado, carpeta del Mundo 1
# completada, pieza cian que se enciende al llegar y Mundo 2 desbloqueado con
# «Próximamente»; guardar y cargar conserva la capa; un game over sin guardar
# la pierde y vuelve a bloquear el Mundo 2.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-boss.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_boss_reward.json"
const DT: float = 1.0 / 60.0

var _saved_path: String
var _saved_lap: int
var _saved_abilities: Dictionary = {}
var _main: LevelRunner
var _level: GeneratedLevel
var _boss: AlertMajor
var _completed: Array[String] = []


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
	_saved_lap = GameState.lap
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		_saved_abilities[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	_completed.clear()
	EventBus.level_completed.connect(_on_completed)


func after_each() -> void:
	if EventBus.level_completed.is_connected(_on_completed):
		EventBus.level_completed.disconnect(_on_completed)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_level = null
	_boss = null
	get_tree().paused = false
	DebugMode.reset()
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	for ability: StringName in _saved_abilities:
		GameState.set_ability_unlocked(ability, _saved_abilities[ability])
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_completed(id: String) -> void:
	_completed.append(id)


## Golpes hasta el golpe final (sin ventanas: take_core_hit directo).
func _defeat(boss: AlertMajor) -> void:
	if not boss.is_fighting():
		boss.start()
	while not boss.is_defeated():
		boss.take_core_hit(1)


## Espera (tiempo real del arbol) hasta `stage` o `max_s`. Cierra la recompensa
## en cuanto se pueda.
func _drive_until(defeat: BossDefeat, stage: BossDefeat.Stage, max_s: float) -> void:
	var t: float = 0.0
	while t < max_s and is_instance_valid(defeat) and defeat.get_stage() < stage:
		var reward: BossReward = defeat.get_reward()
		if reward != null and reward.can_close():
			reward.confirm()
		await wait_physics_frames(1)
		t += DT


# --- BossReward ---

func test_grant_gives_the_cache_layer_unsaved_and_no_double() -> void:
	assert_false(GameState.has_unsaved_changes())
	var got: Array[StringName] = BossReward.grant(1, 1)
	assert_eq(got, [&"boss_w1_l1"] as Array[StringName], "Capa Caché del Mundo 1")
	assert_true(GameState.has_memory(&"boss_w1_l1"))
	assert_true(GameState.has_unsaved_changes(), "Sin guardar: hay que guardar en Notas")
	assert_true(GameState.has_unread_memories(), "Notas lleva la placa de recuerdo nuevo")
	assert_eq(BossReward.grant(1, 1), [] as Array[StringName], "Revancha: sin entrega doble")


func test_safety_net_gives_missing_lower_layers() -> void:
	var got: Array[StringName] = BossReward.grant(1, 2)
	assert_eq(got, [&"boss_w1_l1", &"boss_w1_l2"] as Array[StringName], "Kernel entrega tambien la Caché")
	assert_false(GameState.has_memory(&"boss_w1_l3"))


func test_reward_survives_save_and_load_and_is_lost_by_game_over_without_saving() -> void:
	BossReward.grant(1, 1)
	GameState.mark_level_completed(&"1-boss")
	assert_true(GameState.save_game(), "Guardar en Notas")
	GameState.reset_progress()
	assert_false(GameState.has_memory(&"boss_w1_l1"))
	assert_true(GameState.load_game(), "Cargar")
	assert_true(GameState.has_memory(&"boss_w1_l1"), "La capa se guarda")
	assert_true(GameState.is_level_completed(&"1-boss"))
	assert_true(HubWorlds.is_world_unlocked(HubWorlds.world(&"m2")), "Mundo 2 desbloqueado tras cargar")
	# Otra partida: vencido sin guardar y game over -> se pierde todo.
	SaveFile.delete(PATH)
	GameState.reset_progress()
	assert_true(GameState.save_game(), "Copia sin el jefe")
	BossReward.grant(1, 1)
	GameState.mark_level_completed(&"1-boss")
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.has_memory(&"boss_w1_l1"), "Game over sin guardar: la capa se pierde")
	assert_false(GameState.is_level_completed(&"1-boss"), "Hay que vencerlo otra vez")
	assert_false(HubWorlds.is_world_unlocked(HubWorlds.world(&"m2")), "El Mundo 2 vuelve a bloquearse")


func test_reward_panel_texts_and_close() -> void:
	BossReward.grant(1, 1)
	var reward: BossReward = BossReward.show_for(&"boss_w1_l1", self, "Linea del sistema")
	watch_signals(reward)
	assert_true(reward.is_open())
	assert_eq(reward.get_text(&"system"), "Linea del sistema")
	assert_eq(reward.get_text(&"header"), "Recuerdo recuperado")
	assert_eq(reward.get_text(&"title"), MemoryCatalog.shared().title(&"boss_w1_l1"))
	assert_eq(reward.get_text(&"layer"), "Capa: Caché", "Nombre del acceso, nunca vuelta")
	assert_eq(reward.get_text(&"text"), MemoryCatalog.shared().text(&"boss_w1_l1"))
	assert_eq(reward.get_text(&"notice"), "Guarda en Notas para conservarlo.")
	assert_false(reward.confirm(), "No se cierra antes de min_show_s")
	reward.advance(1.0)
	assert_true(reward.confirm())
	assert_signal_emitted(reward, "closed")
	for key: StringName in [&"system", &"header", &"title", &"layer", &"text", &"notice"]:
		for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard", "rollback"]:
			assert_false(reward.get_text(key).contains(word), "%s sin «%s»" % [key, word])


## Paso 5 en Kernel y Raíz (docs/propuesta-recuerdos.md §11.1): la misma entrega
## da la capa del acceso y el panel lo nombra; en Raíz la reaccion de Eco es la
## ultima linea del texto.
func test_reward_panel_in_kernel_and_root_names_the_access() -> void:
	var names: Dictionary = {2: "Capa: Kernel", 3: "Capa: Raíz"}
	for lap: int in [2, 3]:
		GameState.reset_progress()
		var got: Array[StringName] = BossReward.grant(1, lap)
		assert_eq(got.size(), lap, "Capa del acceso y las inferiores que faltaban")
		var id: StringName = BossReward.layer_id(1, lap)
		var reward: BossReward = BossReward.show_for(id, self)
		assert_eq(reward.get_text(&"layer"), names[lap])
		assert_eq(reward.get_text(&"text"), MemoryCatalog.shared().text(id))
		if lap == 3:
			var lines: PackedStringArray = reward.get_text(&"text").split("\n")
			assert_true(lines[lines.size() - 1].begins_with("Eco: «"), "Eco reacciona tras la capa Raíz")
		reward.free()


## Los textos definitivos (paso 6) caben en el panel de la recompensa.
func test_every_boss_layer_fits_the_reward_panel() -> void:
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var cfg: Dictionary = BossReward.load_config()
	var scale_px: float = float(cfg.get("pixel_scale", 2))
	for id: StringName in catalog.ids():
		if not catalog.is_boss(id):
			continue
		var reward: BossReward = BossReward.show_for(id, self, "Sin notificaciones pendientes.")
		var panel := reward.get_node(^"Frame/Panel") as NinePatchRect
		assert_lt(panel.size.y * scale_px, 720.0, "%s cabe en pantalla (%.0f px)" % [id, panel.size.y * scale_px])
		reward.free()


# --- BossDefeat en la arena ---

func test_final_blow_sequence_disarms_rewards_and_leaves_by_vortex() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.intro_on_arrival = false
	_boss.auto_process = false
	add_child_autofree(_level)
	await wait_physics_frames(3)
	var lap: int = GameState.lap
	watch_signals(_boss)
	_defeat(_boss)
	assert_signal_emitted(_boss, "final_blow")
	await wait_physics_frames(2)
	var defeat: BossDefeat = _boss.get_defeat()
	assert_not_null(defeat, "Empieza la secuencia de derrota")
	await _drive_until(defeat, BossDefeat.Stage.REWARD, 3.0)
	assert_signal_emitted(_boss, "disarmed", "Se desarma en pixeles")
	assert_eq(_boss.get_move(), AlertMajor.MOVE_GONE, "El cuerpo ya no esta")
	assert_eq(defeat.get_granted(), [&"boss_w1_l1"] as Array[StringName], "Capa Caché obtenida")
	await _drive_until(defeat, BossDefeat.Stage.DONE, 20.0)
	assert_true(is_instance_valid(defeat) and defeat.is_done(), "Isak se va por el vortice")
	assert_eq(_completed, ["1-boss"] as Array[String], "level_completed del 1-boss")
	assert_eq(GameState.lap, lap, "Sin rollback ni cambio de vuelta")
	assert_true(GameState.has_memory(&"boss_w1_l1"))


func test_rematch_skips_the_reward_panel() -> void:
	BossReward.grant(1, 1)
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.intro_on_arrival = false
	_boss.auto_process = false
	add_child_autofree(_level)
	await wait_physics_frames(3)
	_defeat(_boss)
	await wait_physics_frames(2)
	var defeat: BossDefeat = _boss.get_defeat()
	await _drive_until(defeat, BossDefeat.Stage.LINE, 4.0)
	assert_true(defeat.get_granted().is_empty(), "Nada nuevo")
	assert_null(defeat.get_reward(), "Sin panel de recompensa")


# --- Flujo real: arena -> hub ---

func test_victory_returns_to_hub_with_world_2_unlocked_and_cyan_piece() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	for id: StringName in [&"1-1", &"1-2", &"1-3"]:
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"1-boss")
	assert_false(HubWorlds.is_world_unlocked(HubWorlds.world(&"m2")), "Mundo 2 bloqueado antes")
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.start_level_id = "1-boss"
	add_child(_main)
	var boss := _main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	boss.intro_on_arrival = false
	await wait_physics_frames(3)
	_defeat(boss)
	await wait_physics_frames(2)
	var defeat: BossDefeat = boss.get_defeat()
	await _drive_until(defeat, BossDefeat.Stage.DONE, 20.0)
	var t: float = 0.0
	while t < 6.0 and not _main.is_in_hub():
		await wait_physics_frames(1)
		t += DT
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"1-boss"), "1-boss completado")
	assert_eq(HubWorlds.folder_state(HubWorlds.world(&"m1")), HubWorlds.STATE_COMPLETED, "Carpeta del Mundo 1")
	var m2: Dictionary = HubWorlds.world(&"m2")
	assert_true(HubWorlds.is_world_unlocked(m2), "Mundo 2 desbloqueado")
	assert_ne(HubWorlds.folder_state(m2), HubWorlds.STATE_LOCKED)
	var hub: HubRoom = _main.get_hub()
	assert_true(hub.light_piece_on_arrival, "La pieza se enciende al llegar")
	watch_signals(hub)
	t = 0.0
	while t < 8.0 and hub.get_background_state() != &"on" or hub.is_piece_lighting() or hub.is_piece_pending():
		await wait_physics_frames(1)
		t += DT
		if t >= 8.0:
			break
	assert_eq(hub.get_background_state(), &"on", "Pieza cian encendida")
	assert_signal_emitted(hub, "wallpaper_piece_lit")
	assert_true(GameState.has_memory(&"boss_w1_l1"), "Recuerdo sin guardar")
	assert_true(GameState.has_unsaved_changes())
	var panel := FolderPanel.new()
	panel.world_entry = m2
	add_child_autofree(panel)
	panel.refresh()
	# Desde el paso 11 del Mundo 2 (2026-10-22) el 2-1 es jugable, desde el 13 el 2-2 (bloqueado hasta
	# completar el 2-1) y desde el 14 el 2-3 (tras el 2-2); el jefe sigue «Próximamente».
	assert_eq(panel.get_level_state(&"2-1"), HubWorlds.STATE_AVAILABLE, "El 2-1, disponible")
	assert_eq(panel.level_text(HubWorlds.levels(m2)[1]), "2-2 Un video más - Bloqueado", "El 2-2, tras el 2-1")
	assert_eq(panel.level_text(HubWorlds.levels(m2)[2]), "2-3 Scroll infinito - Bloqueado", "El 2-3, tras el 2-2")
	assert_eq(panel.level_text(HubWorlds.levels(m2)[3]), "Jefe: Autoplay - Próximamente",
		"El jefe del Mundo 2 dice «Próximamente»")
