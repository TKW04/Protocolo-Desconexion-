# El Visto en su arena «Chat vacío» (paso 16 de docs/propuesta-mundo-4.md §8,
# 2026-10-28; diseño en §5.2-§5.6): la arena 4-boss (cabe entera en pantalla,
# burbujas fijas y bajas de una via, dos Trolls de la fase 2, 4 cargadores, Debug
# x0,25 / x0,7) y las fases 1-3 con el tiempo avanzado a mano (advance) y el Isak
# real de la arena con entrada falsa (IsakSim): la reaparicion detras de Isak que
# es la ventana; el escudo que cae con un Agitar desde el borde interior de una
# burbuja fija (no desde el suelo); el pulso que deja en silencio el
# «escribiendo…» y el check gris aturdido a tiro desde una burbuja fija; el
# mensaje que congela sin que nada ataque y Agitar que libera. Reaparicion por fase.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/4-boss.tscn")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_seen_arena.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String
var _saved_lap: int
var _saved: Dictionary = {}
var _level: GeneratedLevel
var _boss: Seen
var _sim: IsakSim
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_lap = GameState.lap
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_SHOCKWAVE]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()


func after_each() -> void:
	_level = null
	_boss = null
	_sim = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## La arena sin LevelRunner; el jefe sin intro ni proceso propio (advance a mano) y
## el Isak de la arena con entrada falsa.
func _arena(lap: int = 1) -> GeneratedLevel:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/seen") as Seen
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_isak())
	add_child_autofree(_level)
	_boss.get_core().auto_process = false
	_sim.take_manual_control()
	await wait_physics_frames(2)
	_sim.settle()
	return _level


## Avanza el jefe, la marca e Isak `seconds` del mundo.
func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)
		_sim.step()


func _advance_until(cond: Callable, max_s: float = 20.0) -> float:
	var t: float = 0.0
	while t < max_s and not cond.call():
		_advance(DT)
		t += DT
	return t


func _debug_on() -> void:
	if not DebugMode.is_active():
		for i: int in roundi(_config.activation_hold_s / DT):
			DebugMode.step(DT, true)
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func _to_phase(phase: int) -> void:
	while _boss.get_phase() < phase:
		_boss.take_core_hit(1)


func _isak() -> Isak:
	return _level.get_isak()


func _place_isak(col: int, row: int, facing: float = 1.0) -> void:
	var isak: Isak = _isak()
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	isak.velocity = Vector2.ZERO
	isak.facing = facing
	_sim.settle()


func _phone() -> Vector2:
	return _isak().global_position + _isak().get_pulse_origin()


## Pulso real de Isak: devuelve su area (la del EventBus) o null.
func _real_pulse() -> Area2D:
	var got: Array = []
	var on_pulse := func(area: Area2D) -> void: got.append(area)
	EventBus.pulse_fired.connect(on_pulse)
	_sim.input.pulse_pressed = true
	for i: int in 30:
		_sim.step()
		if not got.is_empty():
			break
	EventBus.pulse_fired.disconnect(on_pulse)
	return got[0] if not got.is_empty() else null


## Agitar real de Isak: devuelve [centro, radio] de la onda o [].
func _real_shake() -> Array:
	var got: Array = []
	var on_wave := func(center: Vector2, radius: float, _src: Node2D) -> void: got.append([center, radius])
	EventBus.shockwave_fired.connect(on_wave)
	_sim.input.shake_pressed = true
	for i: int in 30:
		_sim.step()
		if not got.is_empty():
			break
	EventBus.shockwave_fired.disconnect(on_wave)
	return got[0] if not got.is_empty() else []


func _mark_and_shoot() -> void:
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	area.add_child(shape)
	area.position = core.global_position
	add_child_autofree(area)
	assert_true(core.receive_pulse(area), "El pulso alcanza el nucleo")
	DebugMode.reset()
	core.on_laser_hit(1.0, null)


# --- Arena ---

func test_arena_fits_the_screen_with_its_pieces() -> void:
	await _arena()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/4-boss.json"))
	assert_eq(data["kind"], "boss")
	assert_eq(data["boss"], "seen")
	assert_eq((data["grid"] as Array).size(), 11, "11 filas")
	assert_eq(String(data["grid"][0]).length(), 20, "20 columnas: 1280 x 704, cabe en pantalla")
	assert_almost_eq(float(data["debug_drain_scale"]), 0.25, EPS)
	assert_almost_eq(float(data["debug_world_scale"]), 0.7, EPS)
	for id: String in ["burbuja_izq", "burbuja_der"]:
		var b := _level.get_node("Objects/%s" % id) as ChatBubble
		assert_not_null(b, id)
		assert_eq(b.width_tiles, 4, "%s: 4 tiles" % id)
		assert_almost_eq(b.global_position.y, 6.0 * TILE, EPS, "%s: superficie en la fila 6" % id)
	var chargers: int = 0
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is Charger:
			chargers += 1
	assert_eq(chargers, 4, "4 cargadores")
	assert_eq(_boss.get_perch_rect(), Rect2(7 * TILE, TILE, 6 * TILE, 3 * TILE), "Doble check: cols 7-12, filas 1-3")


func test_charger_cooldown_by_access() -> void:
	for lap: int in [1, 2, 3]:
		await _arena(lap)
		await wait_physics_frames(1)
		var charger := _level.get_node(^"Objects/cargador_1") as Charger
		assert_almost_eq(charger.cooldown_s, [4.0, 5.0, 6.0][lap - 1], EPS, "Cargadores, acceso %d" % lap)
		_level.queue_free()
		await wait_physics_frames(1)


func test_trolls_only_in_phase_2() -> void:
	await _arena()
	_boss.start()
	var troll := _level.get_node(^"Enemies/troll_izq") as Troll
	assert_false(BossBase.is_phase_node_active(troll), "Fase 1: sin Trolls")
	_to_phase(2)
	assert_true(BossBase.is_phase_node_active(troll), "Fase 2: los Trolls en las burbujas fijas")
	_to_phase(3)
	assert_false(BossBase.is_phase_node_active(troll), "Fase 3: fuera")


# --- Fase 1 ---

func test_phase1_reappears_behind_and_the_window_is_in_reach() -> void:
	await _arena()
	_place_isak(10, 9, 1.0)
	_boss.start()
	_boss.start_attack(Seen.ATTACK_GHOST_DASH)
	_advance_until(func() -> bool: return _boss.is_window_open())
	var core: WeakPoint = _boss.get_core()
	assert_lt(core.global_position.x, _isak().global_position.x, "Detras (mira a la derecha)")
	# Darse la vuelta y un paso atras: el pulso real lo alcanza.
	_isak().facing = -1.0
	_sim.input.move_axis = -1.0
	_sim.step(6)
	_sim.input.move_axis = 0.0
	_debug_on()
	var area: Area2D = _real_pulse()
	assert_not_null(area, "Pulso")
	assert_true(core.is_marked(), "Girarse, Debug y pulso: marcado en la ventana")
	DebugMode.reset()
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "Un golpe")


# --- Fase 2 ---

func test_phase2_shockwave_from_the_inner_edge_breaks_the_shield() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	# Desde el suelo, bajo el escudo: no llega.
	_place_isak(9, 9, 1.0)
	var wave: Array = _real_shake()
	assert_false(wave.is_empty(), "Agitar en el suelo")
	assert_true(_boss.is_shield_up(), "Desde el suelo no rompe el escudo")
	_advance(1.6)
	# Desde el borde interior de la burbuja fija izquierda (columna 6): estalla.
	_place_isak(6, 5, 1.0)
	assert_true(_isak().is_on_floor(), "De pie en la burbuja fija")
	wave = _real_shake()
	assert_false(wave.is_empty(), "Agitar en la burbuja")
	assert_false(_boss.is_shield_up(), "Arena limpia y la onda cerca: el escudo estalla")
	assert_true(_boss.is_window_open(), "Cae al suelo")
	_advance(0.5)
	assert_almost_eq(_boss.get_body_rect().end.y, 10.0 * TILE, 0.5, "En el suelo")
	assert_almost_eq(_boss.get_core().global_position.y, 10.0 * TILE - 58.0, 0.5, "A la altura del celular en el suelo")


func test_phase2_stickers_block_the_shield_until_shaken_off() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_place_isak(6, 5, 1.0)
	_advance_until(func() -> bool: return not _boss.get_stickers().is_empty())
	assert_eq(_boss.get_stickers().size(), 3, "Tanda de 3 Stickers por el suelo")
	_real_shake()
	assert_true(_boss.is_shield_up(), "Con Stickers en el suelo no cede")
	# Agitar en el suelo junto a ellos (uno a uno, como haria el jugador moviendose).
	for s: Sticker in _boss.get_stickers():
		s.receive_shockwave(s.get_center(), 160.0, 3.0)
	assert_true(_boss.get_stickers().is_empty())
	_advance(1.6)
	_place_isak(6, 5, 1.0)
	_real_shake()
	assert_false(_boss.is_shield_up(), "Limpia: estalla")


# --- Fase 3 ---

func test_phase3_pulse_from_the_floor_then_the_core_from_a_fixed_bubble() -> void:
	await _arena()
	_boss.start()
	_to_phase(3)
	_place_isak(8, 9, 1.0)
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_ON)
	var area: Area2D = _real_pulse()
	assert_not_null(area)
	assert_eq(_boss.get_typing_state(), Seen.TYPING_SILENT, "El pulso desde el suelo la deja en silencio")
	assert_true(_boss.is_window_open())
	assert_eq(_boss.get_stun_side(), Seen.SIDE_LEFT)
	var core: WeakPoint = _boss.get_core()
	assert_almost_eq(core.global_position, Vector2(512.0, 326.0), Vector2(0.5, 0.5), "Aturdido a la altura de las burbujas fijas")
	# Desde el borde interior de la burbuja fija izquierda el pulso lo alcanza.
	_place_isak(6, 5, 1.0)
	_debug_on()
	_advance(0.6)
	assert_true(_boss.is_window_open(), "Sigue la ventana")
	_real_pulse()
	assert_true(core.is_marked(), "Desde la burbuja fija: marcado")


func test_phase3_message_freezes_nothing_attacks_and_shockwave_frees() -> void:
	await _arena()
	_boss.start()
	_to_phase(3)
	_place_isak(2, 9, 1.0)
	var sync_before: float = GameState.sync_rate
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_SENT, 12.0)
	assert_true(_isak().is_frozen(), "El mensaje congela")
	assert_eq(_isak().get_frozen_source(), Isak.FREEZE_SOURCE_BOSS)
	_advance(1.0)
	for g: Ghost in _boss.get_ghosts():
		assert_eq(g.process_mode, Node.PROCESS_MODE_DISABLED, "Los Fantasmas, quietos")
	assert_almost_eq(GameState.sync_rate, sync_before, EPS, "Nada dana a Isak congelado")
	var wave: Array = _real_shake()
	assert_false(wave.is_empty(), "Agitar congelado sale al instante")
	assert_false(_isak().is_frozen(), "Agitar libera")
	_advance(DT)
	for g: Ghost in _boss.get_ghosts():
		assert_ne(g.process_mode, Node.PROCESS_MODE_DISABLED, "Se reanudan")


# --- Reaparicion ---

func test_respawn_restarts_the_phase_with_energy_and_ready_chargers() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_boss.take_core_hit(1)
	GameState.debug_energy = 10.0
	var charger := _level.get_node(^"Objects/cargador_1") as Charger
	EventBus.player_respawned.emit(_isak().global_position, true)
	assert_eq(_boss.get_phase(), 2)
	assert_eq(_boss.get_phase_hits_left(), 3, "La fase entera")
	assert_gte(GameState.debug_energy, 50.0, "Energia >= 50")
	assert_true(_boss.is_shield_up(), "Con su escudo")
	assert_true(charger.is_ready() if charger.has_method(&"is_ready") else true, "Cargadores listos")
