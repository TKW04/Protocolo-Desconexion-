# El Visto, jefe del Mundo 4: datos y logica (paso 15 de docs/propuesta-mundo-4.md
# §8, 2026-10-28; diseño en §5.3-§5.6). El punto debil (WeakPoint, el check gris
# «sin leer») solo esta activo en las ventanas: sin el Debug el pulso no marca;
# con el Debug activo lo marca y el laser es UN golpe por marca (laps.<n>.mark_hits
# = 1) sin necesitar el Debug; el golpe cierra la ventana. Cada fase lo pone a
# tiro con su mecanica: fase 1, la reaparicion detras de Isak; fase 2, en el
# suelo al romperse el escudo (solo con un pulso y la arena limpia; Agitar se
# retiro el 2026-10-28); fase 3,
# aturdido junto a una burbuja fija al interrumpirle el «escribiendo…». Si el
# mensaje sale, Isak se congela y El Visto no ataca mientras dura. Sin arena: el
# jefe sobre un suelo llano con el Isak real (IsakSim), con el tiempo a mano.
# Las fases en la arena real 4-boss: tests/test_seen_arena.gd (paso 16).
extends GutTest

const SEEN_SCENE: PackedScene = preload("res://scenes/bosses/seen.tscn")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_seen_boss.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
## El suelo llano del arnes esta en y = 0; la arena pone el suyo en la fila 10.
const ARENA_OFFSET: Vector2 = Vector2(0.0, -10.0 * TILE)

var _saved_path: String
var _saved_lap: int
var _saved: Dictionary = {}
var _world: Node2D
var _objects: Node2D
var _boss: Seen
var _isak: Isak
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
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG]:
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
	_world = null
	_objects = null
	_boss = null
	_isak = null
	_sim = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## El jefe (en su celda de la arena, 7, 1) sobre un suelo llano con Isak en la
## columna `col` mirando a la derecha.
func _setup(lap: int = 1, col: int = 9) -> void:
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	_isak = _sim.isak
	_objects = Node2D.new()
	_objects.name = "Objects"
	_objects.position = ARENA_OFFSET
	_world.add_child(_objects)
	_boss = SEEN_SCENE.instantiate() as Seen
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
	_boss.position = Vector2(7, 1) * TILE
	_objects.add_child(_boss)
	add_child_autofree(_world)
	_sim.take_manual_control()
	_boss.get_core().auto_process = false
	await wait_physics_frames(2)
	_place_isak(col)
	_boss.start()


func _place_isak(col: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, 0.0)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0
	_sim.settle()


func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)


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


func _pulse_area(pos: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = pos
	add_child_autofree(area)
	return area


## Marca con el Debug (pulso en el nucleo), lo apaga y dispara: un golpe.
func _mark_and_shoot() -> void:
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	assert_true(core.receive_pulse(_pulse_area(core.global_position)), "El pulso alcanza el nucleo")
	DebugMode.reset()
	assert_true(core.is_marked(), "Marcado")
	core.on_laser_hit(1.0, null)


## Celular de Isak (centro del pulso), global.
## Quita los Stickers vivos de la tanda con el laser (vida 1), sin depender del pulso.
func _clear_stickers() -> void:
	for s: Sticker in _boss.get_stickers():
		s.on_laser_hit(1.0, null)
	assert_true(_boss.get_stickers().is_empty(), "Sin Stickers vivos")


func _phone() -> Vector2:
	return _isak.global_position + _isak.get_pulse_origin()


func _cell_center(col: float, row: float) -> Vector2:
	return Vector2((col + 0.5) * TILE, (row + 0.5) * TILE) + ARENA_OFFSET


# --- Datos ---

func test_data_laps_hits_and_marks() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/seen.json"))
	assert_eq(data["id"], "seen")
	assert_eq(int(data["world"]), 4)
	var expect: Dictionary = {"1": [[3, 3, 3], 4.0, 4.0], "2": [[4, 4, 4], 3.0, 5.0], "3": [[4, 4, 4], 2.5, 6.0]}
	for lap: String in expect:
		var entry: Dictionary = data["laps"][lap]
		assert_eq(str((entry["hits_per_phase"] as Array).map(func(v: Variant) -> int: return int(v))), str(expect[lap][0]), "Golpes por fase, acceso %s" % lap)
		assert_almost_eq(float(entry["mark_duration_s"]), float(expect[lap][1]), EPS, "Marca, acceso %s" % lap)
		assert_eq(int(entry["mark_hits"]), 1, "Un golpe por marca, acceso %s" % lap)
		assert_almost_eq(float(entry["charger_cooldown_s"]), float(expect[lap][2]), EPS, "Cargadores, acceso %s" % lap)
	assert_almost_eq(float(data["laps"]["3"]["dot_interval_s"]), 1.0, EPS, "Raíz: un punto por segundo")
	assert_eq(int(data["laps"]["2"]["shield_layers"]), 2, "Kernel: escudo de dos capas")
	assert_eq(float(data["respawn_min_energy"]), 50.0)
	assert_almost_eq(float(data["phase1"]["window_s"]), 1.2, EPS, "Fase 1: 1,2 s del mundo")
	assert_almost_eq(float(data["phase2"]["window_s"]), 4.0, EPS, "Fase 2: 4 s en el suelo")
	assert_almost_eq(float(data["phase3"]["window_s"]), 3.0, EPS, "Fase 3: 3 s aturdido")
	assert_almost_eq(float(data["phase3"]["message_freeze_s"]), 2.5, EPS)
	for key: String in ["intro", "final_system", "defeat"]:
		assert_false(String(data["texts"][key]).is_empty(), "texts.%s" % key)


func test_lap_settings_reach_the_weak_point() -> void:
	for lap: int in [1, 2, 3]:
		await _setup(lap)
		assert_eq(_boss.get_total_hits(), 9 if lap == 1 else 12, "Golpes totales, acceso %d" % lap)
		assert_almost_eq(_boss.get_core().get_mark_duration(), [4.0, 3.0, 2.5][lap - 1], EPS, "Marca, acceso %d" % lap)
		assert_eq(_boss.get_core().get_mark_hits(), 1, "Un golpe por marca, acceso %d" % lap)
		assert_eq(_boss.get_counter_label(), "99+")
		_world.queue_free()
		await wait_physics_frames(1)


# --- La marca ---

func test_without_debug_no_mark_and_one_hit_per_mark() -> void:
	await _setup()
	assert_false(_boss.get_core().is_enabled(), "Fuera de la ventana el punto debil no esta")
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	assert_true(core.is_enabled(), "En la ventana, si")
	core.receive_pulse(_pulse_area(core.global_position))
	assert_false(core.is_marked(), "Sin el Debug el pulso no marca")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 9, "Sin marca el laser no hace dano")
	_mark_and_shoot()
	assert_eq(_boss.get_remaining_hits(), 8, "Un golpe sin el Debug")
	assert_false(core.is_marked(), "La marca termina con el golpe")
	assert_false(_boss.is_window_open(), "Un golpe por ventana: se cierra")
	assert_false(core.is_enabled())
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "El segundo laser ya no cuenta")


func test_mark_lost_on_phase_change_and_nothing_else_damages() -> void:
	await _setup()
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	assert_false(core.receive_ground_pound(core.global_position), "El golpe al suelo no hace nada")
	assert_eq(_boss.get_remaining_hits(), 9)
	core.receive_pulse(_pulse_area(core.global_position))
	assert_true(core.is_marked())
	_boss.take_core_hit(3)
	assert_eq(_boss.get_phase(), 2)
	assert_false(core.is_marked(), "Se pierde al cambiar de fase")


# --- Fase 1: Ghosting ---

func test_phase1_reappears_behind_isak_and_that_is_the_window() -> void:
	await _setup()
	_boss.start_attack(Seen.ATTACK_GHOST_DASH)
	assert_eq(_boss.get_dash_stage(), Seen.DASH_VANISH, "Se esfuma")
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_HIDDEN)
	assert_false(_boss.is_trail_visible(), "Sin el Debug no se ve el rastro")
	_debug_on()
	assert_true(_boss.is_trail_visible(), "Con el Debug, el rastro")
	DebugMode.reset()
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_WARN)
	var at: Vector2 = _boss.get_appear_point()
	assert_almost_eq(at.x, _isak.global_position.x - 2.0 * TILE, 0.5, "2 tiles detras de Isak (mira a la derecha)")
	assert_almost_eq(at.y, _isak.global_position.y, 0.5, "A la altura de sus pies")
	assert_false(_boss.is_window_open(), "Avisa antes (silueta)")
	var warn_s: float = _advance_until(func() -> bool: return _boss.is_window_open())
	assert_between(warn_s, 0.5, 1.0, "Aviso de 9 cuadros (0,75 s)")
	var core: WeakPoint = _boss.get_core()
	assert_true(core.is_enabled(), "La reaparicion es la ventana")
	assert_almost_eq(_boss.get_window_time_left(), 1.2, 0.02, "1,2 s del mundo")
	assert_almost_eq(core.global_position.y, _isak.global_position.y - 58.0, 0.5, "A la altura del celular")
	assert_lt(core.global_position.distance_to(_phone()), 96.0 + 24.0 + 64.0, "A tiro con un paso atras")
	_mark_and_shoot()
	assert_eq(_boss.get_remaining_hits(), 8)
	assert_eq(_boss.get_dash_stage(), Seen.DASH_RETURN, "Con el golpe vuelve sin embestir")


func test_phase1_charges_when_the_window_runs_out() -> void:
	await _setup()
	var sync_before: float = GameState.sync_rate
	_boss.start_attack(Seen.ATTACK_GHOST_DASH)
	_advance_until(func() -> bool: return _boss.is_window_open())
	_advance_until(func() -> bool: return not _boss.is_window_open())
	assert_eq(_boss.get_dash_stage(), Seen.DASH_CHARGE, "Sin golpe, embiste")
	_advance_until(func() -> bool: return _boss.get_dash_stage() != Seen.DASH_CHARGE, 3.0)
	assert_almost_eq(GameState.sync_rate, sync_before - 10.0, EPS, "La embestida quita 10")


func test_raiz_reappears_in_front_one_of_three() -> void:
	await _setup(3)
	var sides: Array[float] = []
	for i: int in 3:
		_boss.start_attack(Seen.ATTACK_GHOST_DASH)
		_advance_until(func() -> bool: return _boss.is_window_open())
		sides.append(signf(_boss.get_appear_point().x - _isak.global_position.x))
		_mark_and_shoot()
		_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_NONE)
	assert_eq(sides, [-1.0, -1.0, 1.0], "Detras, detras y la tercera delante")


func test_kernel_decoy_has_no_weak_point() -> void:
	await _setup(2)
	_boss.start_attack(Seen.ATTACK_GHOST_DASH)
	_advance_until(func() -> bool: return _boss.is_window_open())
	var decoy: Vector2 = _boss.get_decoy_point()
	assert_ne(decoy, Vector2.INF, "Kernel: una silueta falsa")
	assert_almost_eq(decoy.x, _isak.global_position.x + 2.0 * TILE, 0.5, "Al otro lado")
	assert_lt(_boss.get_core().global_position.x, _isak.global_position.x, "El punto debil va en la real (detras)")


func test_phase1_seen_zones_freeze_and_pulse_turns_them_off() -> void:
	await _setup()
	_boss.start_attack(Seen.ATTACK_SEEN_ZONES)
	assert_eq(_boss.get_zone_state(), Seen.ZONE_WARN, "Avisa")
	assert_eq(_boss.get_zone_rects().size(), 2, "Dos zonas")
	_advance(0.2)
	assert_false(_isak.is_frozen(), "En el aviso no congela")
	_advance_until(func() -> bool: return _boss.get_zone_state() == Seen.ZONE_ACTIVE)
	_advance(DT)
	assert_true(_isak.is_frozen(), "Activa con los pies dentro: congela")
	assert_eq(_isak.get_frozen_source(), Isak.FREEZE_SOURCE_ZONE)
	# Otra zona: el pulso la apaga.
	_world.queue_free()
	await wait_physics_frames(1)
	await _setup()
	_boss.start_attack(Seen.ATTACK_SEEN_ZONES)
	var zones: Array[Rect2] = _boss.get_zone_rects()
	assert_true(_boss.receive_pulse(_pulse_area(_phone())), "El pulso la alcanza")
	assert_eq(_boss.get_zone_rects().size(), zones.size() - 1, "Apagada")
	_advance_until(func() -> bool: return _boss.get_zone_state() == Seen.ZONE_ACTIVE)
	_advance(DT)
	assert_false(_isak.is_frozen(), "Apagada no congela")


func test_phase1_falling_bubbles_warn_then_hurt() -> void:
	await _setup()
	var sync_before: float = GameState.sync_rate
	_boss.start_attack(Seen.ATTACK_FALLING_BUBBLES)
	assert_eq(_boss.get_falling_columns().size(), 3, "Tres mensajes")
	assert_true(_boss.get_falling_columns().has(9), "Uno en la columna de Isak")
	assert_false(_boss.is_bubble_falling(), "Primero el aviso")
	var warn_s: float = _advance_until(func() -> bool: return _boss.is_bubble_falling())
	assert_between(warn_s, 0.5, 1.0, "9 cuadros")
	_advance(0.6)
	assert_almost_eq(GameState.sync_rate, sync_before - 10.0, EPS, "Quedarse en la columna duele")


# --- Fase 2: Grupo ---

func test_phase2_shield_only_breaks_with_a_pulse_and_clean_arena() -> void:
	await _setup()
	_to_phase(2)
	assert_true(_boss.is_shield_up(), "Escudo")
	var shield: Rect2 = _boss.get_shield_rect()
	# Desde el suelo el pulso (96 px) no llega al escudo.
	assert_false(_boss.receive_pulse(_pulse_area(_phone())), "Desde el suelo no llega")
	assert_true(_boss.is_shield_up())
	# Stickers vivos: no cede.
	_advance_until(func() -> bool: return not _boss.get_stickers().is_empty())
	assert_eq(_boss.get_stickers().size(), 3, "Tanda de 3 Stickers")
	var near: Vector2 = Vector2(shield.position.x - 8.0, shield.end.y + 40.0)
	var blocked: Array = []
	_boss.shield_blocked.connect(func() -> void: blocked.append(true))
	assert_false(_boss.receive_pulse(_pulse_area(near)), "Con Stickers no cede")
	assert_eq(blocked.size(), 1)
	assert_true(_boss.is_shield_up())
	assert_false(_boss.get_core().is_enabled())
	_clear_stickers()
	assert_true(_boss.receive_pulse(_pulse_area(near)), "Arena limpia y el pulso cerca: estalla")
	assert_false(_boss.is_shield_up())
	assert_true(_boss.is_window_open(), "Cae al suelo: ventana")
	assert_almost_eq(_boss.get_window_time_left(), 4.0, 0.02, "4 s del mundo")
	var core: WeakPoint = _boss.get_core()
	assert_almost_eq(core.global_position.y, _isak.global_position.y - 58.0, 0.5, "En el suelo, a la altura del celular")
	_mark_and_shoot()
	assert_eq(_boss.get_phase_hits_left(), 2)
	assert_true(_boss.is_shield_up(), "Al cerrarse, vuelve el escudo")


## Paso 19 (el bot lo encontro): un Sticker que ya exploto (confeti) no cuenta
## como vivo: no bloquea el escudo ni ocupa sitio en la tanda.
func test_phase2_exploded_stickers_do_not_block_the_shield() -> void:
	await _setup()
	_to_phase(2)
	var shield: Rect2 = _boss.get_shield_rect()
	_advance_until(func() -> bool: return not _boss.get_stickers().is_empty())
	assert_eq(_boss.get_stickers().size(), 3)
	for s: Sticker in _boss.get_stickers():
		s.call(&"_explode")
	assert_true(_boss.get_stickers().is_empty(), "El confeti no cuenta")
	var near: Vector2 = Vector2(shield.position.x - 8.0, shield.end.y + 40.0)
	assert_true(_boss.receive_pulse(_pulse_area(near)), "Sin Stickers vivos: estalla")


func test_kernel_shield_has_two_layers() -> void:
	await _setup(2)
	_to_phase(2)
	var shield: Rect2 = _boss.get_shield_rect()
	var near: Vector2 = Vector2(shield.get_center().x, shield.end.y + 40.0)
	assert_true(_boss.receive_pulse(_pulse_area(near)), "Primera capa")
	assert_true(_boss.is_shield_up(), "Queda otra")
	assert_eq(_boss.get_shield_layers_left(), 1)
	assert_true(_boss.receive_pulse(_pulse_area(near)), "Segunda capa")
	assert_true(_boss.is_window_open())


# --- Fase 3: Escribiendo… ---

func test_phase3_pulse_interrupts_typing_before_the_last_dot() -> void:
	await _setup()
	_to_phase(3)
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_ON)
	var t: float = _advance_until(func() -> bool: return _boss.get_dots() == 1)
	assert_almost_eq(t, 1.5, 0.05, "Un punto cada 1,5 s del mundo")
	_advance_until(func() -> bool: return _boss.get_dots() == 2)
	assert_true(PulseReceiver.pulse_reaches(_pulse_area(_phone()), _boss.get_typing_rect()),
		"Desde el suelo, debajo, a tiro de pulso")
	assert_true(_boss.receive_pulse(_pulse_area(_phone())), "El pulso la deja en silencio")
	assert_eq(_boss.get_typing_state(), Seen.TYPING_SILENT)
	assert_true(_boss.is_window_open(), "Aturdido: ventana")
	assert_almost_eq(_boss.get_window_time_left(), 3.0, 0.02, "3 s del mundo")
	assert_eq(_boss.get_stun_side(), Seen.SIDE_LEFT, "Del lado de Isak (columna 9: mitad izquierda)")
	var core: WeakPoint = _boss.get_core()
	assert_almost_eq(core.global_position.y, 326.0 + ARENA_OFFSET.y, 0.5, "A la altura del celular en una burbuja fija")
	_mark_and_shoot()
	assert_eq(_boss.get_phase_hits_left(), 2)
	assert_eq(_boss.get_typing_state(), Seen.TYPING_IDLE, "Vuelve a escribir tras una pausa")


func test_phase3_message_freezes_isak_and_nothing_attacks_while_frozen() -> void:
	await _setup()
	_to_phase(3)
	var sent: Array = []
	_boss.message_sent.connect(func(frozen: bool) -> void: sent.append(frozen))
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_SENT, 10.0)
	assert_eq(sent, [true], "El mensaje sale y congela")
	assert_true(_isak.is_frozen())
	assert_eq(_isak.get_frozen_source(), Isak.FREEZE_SOURCE_BOSS)
	assert_almost_eq(_isak.get_frozen_left(), 2.5, 0.02, "2,5 s")
	assert_false(_boss.receive_pulse(_pulse_area(_phone())), "Ya enviado: el pulso no lo interrumpe")
	_advance(DT)
	assert_eq(_boss.get_ghosts().size(), 2, "Dos Fantasmas pequenos")
	for g: Ghost in _boss.get_ghosts():
		assert_eq(g.process_mode, Node.PROCESS_MODE_DISABLED, "Quietos mientras Isak esta congelado")
	# Congelado, El Visto no avanza: sigue en el mensaje aunque pase el tiempo.
	_advance(1.5)
	assert_eq(_boss.get_typing_state(), Seen.TYPING_SENT, "No vuelve a escribir mientras dura")
	assert_eq(_boss.get_attack_state(), Seen.ATTACK_MESSAGE)
	# Se descongela (sin Agitar: el tiempo): se reanudan y vuelve a escribir.
	_sim.step(_sim.steps_for(2.6))
	assert_false(_isak.is_frozen())
	_advance(DT)
	for g: Ghost in _boss.get_ghosts():
		assert_ne(g.process_mode, Node.PROCESS_MODE_DISABLED, "Se reanudan")
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_ON,
		float(_boss.phase_data(3).get("typing_gap_s", 2.0)) + 3.0)
	assert_eq(_boss.get_typing_state(), Seen.TYPING_ON, "Vuelve a escribir (tras typing_gap_s)")


func test_final_blow_and_reappearance_restart_the_phase() -> void:
	await _setup()
	var blows: Array = []
	_boss.final_blow.connect(func() -> void: blows.append(true))
	_to_phase(3)
	_boss.take_core_hit(1)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(_boss.get_phase(), 3, "Reaparece en la fase 3")
	assert_eq(_boss.get_phase_hits_left(), 3, "Con la fase entera")
	assert_gte(GameState.debug_energy, 50.0)
	_boss.take_core_hit(3)
	assert_true(_boss.is_defeated())
	assert_eq(blows.size(), 1, "Golpe final")
	assert_true(_boss.is_screen_off())
	assert_true(_boss.get_ghosts().is_empty(), "Sin Fantasmas tras el golpe final")


# --- Arte final (paso 24, etapa 2: tools/import_boss_seen.py) ---

func test_final_art_follows_its_state() -> void:
	await _setup()
	assert_true(_boss.has_final_art(), "Cuadros de tools/import_boss_seen.py")
	assert_eq(String(_boss.get_art_frame()[0]), "idle", "Fase 1 entre ataques")
	var body := _boss.get_node(^"Body") as Sprite2D
	var box: Rect2 = _boss.get_perch_rect()
	assert_eq(box.size, Vector2(384.0, 192.0), "La caja no cambia (6 x 3 tiles)")
	assert_eq(body.global_position, box.position + Seen.ART_BODY_OFFSET, "Lienzo en su sitio")
	assert_eq(body.texture.get_size(), Vector2(336.0, 256.0))
	var perch: Array = _boss.get_config()["arena"]["perch_core_px"]
	assert_almost_eq(Seen.ART_CHECK_PX.x, float(perch[0]), 4.0, "Check gris centrado (perch_core_px)")
	assert_almost_eq(Seen.ART_CHECK_PX.y, float(perch[1]), 0.5)
	# Fase 1: se esfuma, oculto, silueta con su arte y vuelve.
	_boss.start_attack(Seen.ATTACK_GHOST_DASH)
	_advance(DT)
	assert_eq(String(_boss.get_art_frame()[0]), "vanish")
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_HIDDEN)
	assert_eq(int(_boss.get_art_frame()[1]), -1, "Oculto: sin cuerpo")
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_WARN)
	_advance(DT)
	var sil := _boss.get_node(^"Silhouette") as Sprite2D
	assert_true(sil.visible, "La silueta es el doble check pequeno")
	assert_eq(String(_boss.get_silhouette_art_frame()[0]), "reappear")
	var sil_rect: Rect2 = _boss.get_silhouette_rect()
	assert_eq(sil.global_position, (sil_rect.get_center() + Seen.ART_SILHOUETTE_OFFSET).round(),
		"El check gris de la silueta en el punto debil")
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_CHARGE)
	_advance(DT)
	assert_eq(String(_boss.get_silhouette_art_frame()[0]), "charge", "Embiste")
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_RETURN)
	_advance(DT)
	assert_false(sil.visible, "Sin silueta al volver")
	assert_eq(String(_boss.get_art_frame()[0]), "reappear", "Vuelve arriba con el glitch")
	# Fase 2: escudo y, en el suelo, aturdido con el check gris en el punto debil.
	_to_phase(2)
	_advance(DT)
	assert_eq(String(_boss.get_art_frame()[0]), "shield")
	var shield: Rect2 = _boss.get_shield_rect()
	_clear_stickers()
	assert_true(_boss.receive_pulse(_pulse_area(Vector2(shield.position.x - 8.0, shield.end.y + 40.0))))
	_advance(1.0)
	assert_eq(String(_boss.get_art_frame()[0]), "stunned", "En el suelo")
	assert_lt((body.global_position + Seen.ART_CHECK_PX - Seen.ART_BODY_OFFSET).distance_to(_boss.get_core().global_position), 3.0,
		"El check gris del dibujo cae en el punto debil")
	# Fase 3: escribiendo y aturdido del lado de Isak.
	_to_phase(3)
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_ON)
	_advance(DT)
	assert_eq(String(_boss.get_art_frame()[0]), "typing")
	assert_true(_boss.receive_pulse(_pulse_area(_phone())))
	_advance(1.0)
	assert_eq(String(_boss.get_art_frame()[0]), "stunned", "Aturdido")
	assert_lt((body.global_position + Seen.ART_CHECK_PX - Seen.ART_BODY_OFFSET).distance_to(_boss.get_core().global_position), 3.0,
		"Aturdido a un lado: el dibujo se desliza hasta el punto debil")
	assert_eq(_boss.get_body_rect().size, Vector2(384.0, 192.0), "La caja sigue igual")
	# Golpe final: agrietado y gris.
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	_advance(DT)
	assert_eq(_boss.get_art_frame(), ["defeat", Seen.ART_DEFEAT_FROM], "Golpe final: ya agrietado")
	_advance(3.0)
	assert_eq(_boss.get_art_frame(), ["defeat", 24], "Se queda gris y roto")
