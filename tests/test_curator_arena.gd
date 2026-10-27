# La Curadora en su arena «Exposición» (paso 15 de docs/propuesta-mundo-3.md §8,
# 2026-10-27; diseño en §5.2-§5.6): la arena 3-boss (cabe entera en pantalla,
# plataformas de likes, repisas con biombos, marcos pequeños, espejos y cazador
# de la fase 2, 4 cargadores, Debug x0,25 / x0,7) y las fases 1-3 con el tiempo
# avanzado a mano (advance), como las de Autoplay: sesión de fotos (flash, filtro
# de suelo, recorte y la ventana bajando a encuadrar), de espaldas (el cazador
# lleva el pulso y el laser a la espalda) y retrato perfecto (reflejo, marcos que
# se cierran y Pellizcar). Reaparicion por fase con energia >= 50 y likes >= 10.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/3-boss.tscn")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_curator_arena.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String
var _saved_lap: int
var _level: GeneratedLevel
var _boss: Curator
var _hunter: HunterMirror
var _sim: IsakSim
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_lap = GameState.lap
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()


func after_each() -> void:
	_level = null
	_boss = null
	_hunter = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## La arena sin LevelRunner; el jefe sin intro ni proceso propio (advance a mano).
func _arena(lap: int = 1, sim: bool = false) -> GeneratedLevel:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/curator") as Curator
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
	_hunter = _level.get_node(^"Objects/cazador") as HunterMirror
	_hunter.auto_process = false
	_sim = null
	if sim:
		_sim = IsakSim.new(DT)
		_sim.attach(_level.get_isak())
	add_child_autofree(_level)
	_boss.get_core().auto_process = false
	if sim:
		_sim.take_manual_control()
	await wait_physics_frames(2)
	if sim:
		_sim.settle()
	return _level


## Avanza el jefe, la marca y el cazador `seconds` del mundo (con el Isak manual si hay).
func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)
		if BossBase.is_phase_node_active(_hunter):
			_hunter.advance(DT)
		if _sim != null:
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


func _pulse_area(pos: Vector2) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	area.add_child(shape)
	area.position = pos
	add_child_autofree(area)
	return area


func _place_isak(col: int, row: int) -> void:
	var isak: Isak = _level.get_isak()
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	isak.velocity = Vector2.ZERO
	if _sim != null:
		_sim.settle()


func _laser_into_hunter(damage: float = 1.0) -> LaserProjectile:
	var shot := LaserProjectile.new()
	shot.auto_process = false
	shot.damage = damage
	add_child_autofree(shot)
	shot.global_position = _hunter.get_center() + Vector2(-80.0, 0.0)
	_hunter.laser_reflection(shot, _hunter.get_center())
	return shot


# --- Arena ---

func test_arena_fits_on_screen_without_goal() -> void:
	await _arena()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/3-boss.json"))
	var grid: Array = data["grid"]
	var size := Vector2(String(grid[0]).length() * TILE, grid.size() * TILE)
	assert_eq(size, Vector2(1280, 704), "20 x 11 tiles")
	var view := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	assert_true(Rect2(Vector2.ZERO, view).encloses(Rect2(Vector2.ZERO, size)), "La arena cabe entera (%s en %s)" % [size, view])
	assert_eq(_level.get_isak().camera_limits, Rect2i(0, 0, 1280, 704), "Limites de la camara = la arena")
	assert_null(_level.get_node_or_null(^"Goal"), "Sin meta")
	assert_eq(data["kind"], "boss")
	assert_eq(data["boss"], "curator")
	assert_almost_eq(float(data["debug_drain_scale"]), 0.25, EPS)
	assert_almost_eq(float(data["debug_world_scale"]), 0.7, EPS)
	var chargers: Array = []
	for o: Dictionary in data["objects"]:
		if o["type"] == "charger":
			chargers.append(int(o["x"]))
	assert_eq(chargers, [3, 7, 12, 16], "4 cargadores en el suelo")
	assert_false(bool((_boss.get_config().get("camera", {}) as Dictionary).get("follow", true)), "Camara fija")


func test_arena_pieces() -> void:
	await _arena()
	var tiles := _level.get_node(^"Tiles") as TileMapLayer
	for col: int in [1, 2, 17, 18]:
		assert_true(tiles.get_cell_source_id(Vector2i(col, 8)) >= 0, "Repisa en la columna %d" % col)
		assert_eq(tiles.get_cell_source_id(Vector2i(col, 9)), -1, "Hueco del marco pequeño bajo la repisa")
	for col: int in range(6, 14):
		for row: int in range(1, 5):
			assert_eq(tiles.get_cell_source_id(Vector2i(col, row)), -1, "El marco no es terreno")
	assert_eq(_boss.get_frame_rect(), Rect2(384, 64, 512, 256), "Marco de 8 x 4 en las columnas 6-13")
	for id: String in ["likes_izq", "likes_der"]:
		var p := _level.get_node("Objects/%s" % id) as LikePlatform
		assert_eq(p.threshold, 5, "Umbral 5")
		assert_almost_eq(p.global_position.y, 384.0, EPS, "Superficie en la fila 6")
	assert_eq(_boss.get_small_frame_rect("left"), Rect2(64, 576, 128, 64))
	assert_eq(_boss.get_cover_rects().size(), 4, "Dos biombos y dos plataformas tapan el flash")
	# Los objetos de la fase 2 solo existen en ella.
	var phase2: Array[Node] = [_hunter, _level.get_node(^"Objects/espejo_izq"), _level.get_node(^"Objects/espejo_der"),
		_level.get_node(^"Enemies/ladron_izq"), _level.get_node(^"Enemies/ladron_der")]
	_boss.start()
	for n: Node in phase2:
		assert_false(BossBase.is_phase_node_active(n), "%s inactivo en la fase 1" % n.name)
	_to_phase(2)
	for n: Node in phase2:
		assert_true(BossBase.is_phase_node_active(n), "%s activo en la fase 2" % n.name)
	_to_phase(3)
	assert_false(BossBase.is_phase_node_active(_hunter), "El cazador se va en la fase 3")


func test_every_attack_warns_6_to_12_frames() -> void:
	await _arena()
	var cfg: Dictionary = _boss.get_config()
	var fps: float = float(cfg["arena"]["anim_fps"])
	for frames: Variant in [cfg["flash"]["warn_frames"], cfg["floor_filter"]["enter_frames"], cfg["crop"]["warn_frames"],
			cfg["phase3"]["frame_warn_frames"]]:
		assert_between(int(frames), 6, 12, "Aviso de %s cuadros" % frames)
		assert_almost_eq(float(frames) / fps, 0.75, EPS, "0,75 s del mundo")


func test_start_gives_at_least_10_likes() -> void:
	await _arena()
	GameState.set_likes(0)
	_boss.start()
	assert_eq(GameState.likes, 10, "Likes >= 10 al empezar (las plataformas piden 5)")
	assert_eq(_boss.get_total_hits(), 9)


# --- Fase 1 «Sesión de fotos» ---

func test_phase1_session_flash_filter_crop_then_window() -> void:
	await _arena(1, true)
	_place_isak(9, 9)
	_boss.start()
	var flashes: Array = []
	_boss.flashed.connect(func(b: bool) -> void: flashes.append(b))
	assert_eq(_boss.get_attack_state(), Curator.ATTACK_GAP)
	_advance(1.5 + DT)
	assert_eq(_boss.get_attack_state(), Curator.ATTACK_FLASH, "Primero, el flash")
	assert_true(_boss.is_flash_warning(), "Aro de obturador")
	assert_eq(_boss.get_flash_text(), "3", "«3-2-1 ¡Sonríe!»")
	_advance(0.75)
	assert_eq(flashes, [true], "En el suelo abierto el flash ciega")
	assert_true(FlashVeil.find(_boss).is_active(), "Ceguera")
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max(), "El flash no hace dano")
	_advance_until(func() -> bool: return _boss.get_attack_state() == Curator.ATTACK_FLOOR_FILTER, 3.0)
	assert_eq(_boss.get_filter_side(), "left", "El filtro cubre la mitad de Isak")
	assert_false(_boss.is_spikes_active(), "Entra en 9 cuadros")
	assert_eq(_boss.get_spike_rects().size(), 3, "Tres pinchos ocultos")
	_advance(0.75)
	assert_true(_boss.is_spikes_active(), "Debajo, los pinchos")
	_advance_until(func() -> bool: return _boss.get_attack_state() == Curator.ATTACK_CROP, 8.0)
	var crop: Rect2 = _boss.get_crop_rect()
	assert_eq(crop.size, Vector2(3 * TILE, 9 * TILE), "Franja de 3 columnas hasta el suelo")
	assert_true(crop.has_point(_level.get_isak().global_position + Vector2(0, -40)), "Centrada en Isak")
	assert_false(_boss.is_crop_cutting(), "Primero el contorno rojo")
	_advance(0.75)
	assert_true(_boss.is_crop_cutting(), "Corta")
	var t: float = _advance_until(func() -> bool: return _boss.is_window_open(), 4.0)
	assert_true(_boss.is_window_open(), "Tras la sesion, la ventana (%s s)" % t)
	assert_almost_eq(_boss.get_window_time_left(), 5.0, 0.05, "5 s del mundo")
	assert_true(_boss.get_core().is_enabled(), "La lente se puede marcar")
	assert_eq(_boss.get_hearts().size(), 6, "Suelta 6 corazones")
	_advance(0.4)
	assert_almost_eq(_boss.get_lowered_offset(), 128.0, EPS, "Ha bajado 2 filas a encuadrar")


func test_phase1_spikes_hurt_only_while_active_and_crop_too() -> void:
	await _arena(1, true)
	_place_isak(4, 9)
	_boss.start()
	_boss.start_attack(Curator.ATTACK_FLOOR_FILTER)
	assert_eq(_boss.get_filter_side(), "left")
	_advance(0.5)
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max(), "Aun entrando, sin dano")
	_advance(0.4)
	assert_lt(GameState.sync_rate, GameState.get_sync_rate_max(), "El pincho oculto de la columna 4 hace dano")


func test_flash_is_blocked_by_biombo_platform_and_small_frame() -> void:
	await _arena(1, true)
	_boss.start()
	var lens: Vector2 = _boss.get_lens_point()
	_place_isak(9, 9)
	assert_true(_boss.can_flash_reach(lens), "En el suelo abierto llega")
	_place_isak(1, 7)
	assert_false(_boss.can_flash_reach(lens), "Detras del biombo de la repisa no llega")
	_place_isak(4, 9)
	assert_false(_boss.can_flash_reach(lens), "Bajo la plataforma de likes no llega")
	_place_isak(1, 9)
	assert_false(_boss.can_flash_reach(lens), "En el marco pequeño (bajo la repisa) no llega")
	# El flash reflejado (fase 2) sale de un espejo de esquina: el biombo solo tapa por un lado.
	_place_isak(1, 7)
	assert_true(_boss.can_flash_reach(_boss.get_corner_center("left")), "Desde la esquina de su lado, el biombo no tapa")
	_place_isak(18, 7)
	assert_false(_boss.can_flash_reach(_boss.get_corner_center("left")), "Desde la esquina contraria, si")


func test_phase1_hit_from_the_platform_closes_the_window() -> void:
	await _arena(1, true)
	_place_isak(5, 5)
	_boss.start()
	_boss.open_window(5.0)
	assert_eq(_boss.get_window_side(), "left", "La lente baja hacia el lado de Isak (Caché)")
	var core: WeakPoint = _boss.get_core()
	assert_almost_eq(core.global_position.y, 326.0, EPS, "A la altura del celular de Isak en la plataforma")
	var isak: Isak = _level.get_isak()
	var phone: Vector2 = isak.global_position + isak.get_pulse_origin()
	assert_lt(phone.distance_to(core.global_position), 96.0 + 24.0, "El pulso desde la plataforma la alcanza")
	_debug_on()
	core.receive_pulse(_pulse_area(phone))
	assert_true(core.is_marked())
	DebugMode.reset()
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8)
	assert_false(_boss.is_window_open(), "Un golpe por ventana")
	_advance(0.4)
	assert_almost_eq(_boss.get_lowered_offset(), 0.0, EPS, "Y vuelve a subir")


func test_kernel_window_side_is_random_and_flash_fires_twice() -> void:
	await _arena(2, true)
	_place_isak(9, 9)
	_boss.start()
	var flashes: Array = []
	_boss.flashed.connect(func(b: bool) -> void: flashes.append(b))
	_boss.start_attack(Curator.ATTACK_FLASH)
	_advance(0.75 * 2 + 0.1)
	assert_eq(flashes.size(), 2, "Kernel: el flash sale dos veces")
	var sides: Dictionary = {}
	for i: int in 8:
		_boss.open_window(5.0)
		sides[_boss.get_window_side()] = true
		_boss.close_window()
	assert_eq(sides.size(), 2, "Kernel: izquierda o derecha (hay que leer cual)")


# --- Fase 2 «De espaldas» ---

func test_phase2_attacks_then_pose_window_and_hit_through_the_hunter() -> void:
	await _arena(1, true)
	_place_isak(8, 9)
	_boss.start()
	_to_phase(2)
	assert_eq(_boss.get_counter_text(), "66")
	assert_true(_boss.get_core().is_via_only(), "De espaldas")
	_advance(float(_boss.phase_data(2).get("first_delay_s", 1.5)) + DT)
	assert_eq(_boss.get_attack_state(), Curator.ATTACK_FLASH_REFLECTED, "Flash reflejado")
	assert_eq(_boss.get_flash_source(), _boss.get_corner_center("left"), "Sale de un espejo de esquina")
	var t: float = _advance_until(func() -> bool: return _boss.is_window_open(), 20.0)
	assert_true(_boss.is_window_open(), "Tras 3 ataques posa (%s s)" % t)
	assert_almost_eq(_boss.get_window_time_left(), 5.0, 0.05, "5 s del mundo")
	assert_almost_eq(_boss.get_lowered_offset(), 0.0, EPS, "De espaldas no baja")
	# Lejos (a mas de 3 tiles) vuelve a su reposo, al norte; al acercarse Isak por
	# el oeste gira hacia el y pasa por el noroeste.
	_place_isak(14, 9)
	_advance_until(func() -> bool: return _hunter.get_facing_name() == "n", 3.0)
	assert_eq(_hunter.get_facing_name(), "n", "En reposo mira al marco")
	_place_isak(8, 9)
	_advance_until(func() -> bool: return _hunter.get_facing_name() == "nw", 2.0)
	assert_eq(_boss.get_hunter_corner(), "left", "Mira al espejo de la esquina izquierda")
	_debug_on()
	var isak: Isak = _level.get_isak()
	var area: Area2D = _pulse_area(isak.global_position + isak.get_pulse_origin())
	assert_false(_boss.get_core().receive_pulse(area), "El pulso directo no llega a la espalda")
	EventBus.pulse_fired.emit(area)
	assert_true(_hunter.is_frozen(), "El pulso congela al cazador")
	assert_true(_boss.get_core().is_marked(), "Y su haz, por el espejo de esquina, marca la espalda")
	DebugMode.reset()
	_laser_into_hunter()
	assert_eq(_boss.get_remaining_hits(), 5, "El laser por el cazador es el golpe")
	assert_false(_boss.is_window_open(), "Un golpe por ventana")


# --- Fase 3 «Retrato perfecto» ---

func test_phase3_reflection_frames_close_and_push() -> void:
	await _arena(1, true)
	_place_isak(5, 9)
	_boss.start()
	_to_phase(3)
	_advance(1.0 + 0.1)
	var refl: Array[FalseReflection] = _boss.get_reflections()
	assert_eq(refl.size(), 1, "Caché: un reflejo")
	assert_almost_eq(refl[0].delay_s, 0.5, EPS, "A 0,5 s (mas rapido que el del 3-3)")
	assert_true(refl[0].is_present(), "Sale")
	# Aturdido hasta despues del cierre (con first_delay_s 3 s, paso 18, el reflejo
	# alcanzaria a Isak quieto antes y su invulnerabilidad taparia el -10 del marco).
	refl[0].stun(2.0)
	var frames: Array = []
	_boss.frame_closed.connect(func(side: String, safe: bool) -> void: frames.append([side, safe]))
	_advance_until(func() -> bool: return _boss.get_frame_state() == Curator.FRAME_WARN, 4.0)
	assert_eq(_boss.get_frame_side(), "left", "El marco va a por la mitad de Isak")
	assert_eq(_boss.get_closing_rect(), _boss.get_half_rect("left"))
	_advance(0.75)
	assert_eq(_boss.get_frame_state(), Curator.FRAME_CLOSING, "Aviso de 9 cuadros y se estrecha")
	var sync_before: float = GameState.sync_rate
	_advance_until(func() -> bool: return not frames.is_empty(), 1.0)
	assert_eq(frames, [["left", false]], "Fuera del marco pequeño no se salva")
	assert_lt(GameState.sync_rate, sync_before, "-10")
	var isak: Isak = _level.get_isak()
	assert_eq(_boss.side_of_x(isak.global_position.x), "right", "Empujon a la otra mitad")
	assert_true(_boss.is_window_open(), "Baja a encuadrar tras el cierre")
	assert_almost_eq(_boss.get_window_time_left(), 3.0, 0.05, "3 s del mundo")
	assert_eq(_boss.get_window_side(), "right", "Hacia donde esta Isak ahora")


func test_phase3_compressed_in_the_small_frame_is_safe() -> void:
	await _arena(1, true)
	_place_isak(2, 9)
	var isak: Isak = _level.get_isak()
	assert_true(isak.compress(), "Pellizcar")
	_sim.step(20)
	_boss.start()
	_to_phase(3)
	var frames: Array = []
	_boss.frame_closed.connect(func(side: String, safe: bool) -> void: frames.append([side, safe]))
	var sync_before: float = GameState.sync_rate
	_advance_until(func() -> bool: return not frames.is_empty(), 6.0)
	assert_eq(frames, [["left", true]], "Comprimido en el marco pequeño de su lado, a salvo")
	assert_eq(GameState.sync_rate, sync_before, "Sin dano: ni el marco ni el reflejo (no cabe en el marco pequeño)")
	for r: FalseReflection in _boss.get_reflections():
		assert_false(r.is_dangerous() and _boss.get_small_frame_rect("left").has_point(r.get_body_rect_now().get_center()),
			"El reflejo no entra en el marco pequeño")


func test_phase3_frame_erases_the_reflection_which_comes_back() -> void:
	await _arena(1, true)
	_place_isak(5, 9)
	_boss.start()
	_to_phase(3)
	_advance(1.1)
	var r: FalseReflection = _boss.get_reflections()[0]
	assert_true(r.is_present())
	_advance_until(func() -> bool: return _boss.is_window_open(), 5.0)
	assert_false(r.is_present(), "El marco lo borra (no se pellizca)")
	_advance(2.1)
	assert_true(r.is_present(), "Y vuelve a salir 2 s despues")


func test_phase3_reflections_per_access() -> void:
	var expect: Dictionary = {2: [0.4], 3: [0.5, 1.0]}
	for lap: int in expect:
		await _arena(lap, true)
		_place_isak(5, 9)
		_boss.start()
		_to_phase(3)
		var delays: Array = _boss.get_reflections().map(func(r: FalseReflection) -> float: return r.delay_s)
		assert_eq(str(delays), str(expect[lap]), "Reflejos, acceso %d" % lap)
		assert_almost_eq(float(_boss.lap_value("frame_interval_s", 0.0)), 5.0, EPS, "Marcos cada 5 s, acceso %d" % lap)
		_level.queue_free()
		await wait_physics_frames(1)


# --- Reaparicion y golpe final ---

func test_respawn_restarts_the_phase_with_energy_and_likes() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_boss.take_core_hit(1)
	_boss.start_attack(Curator.ATTACK_CROP)
	GameState.debug_energy = 10.0
	GameState.set_likes(2)
	_boss.restart_phase()
	assert_eq(_boss.get_remaining_hits(), 6, "Vuelve al inicio de la fase 2")
	assert_eq(_boss.get_attack_state(), Curator.ATTACK_GAP, "Sin el recorte")
	assert_almost_eq(GameState.debug_energy, 50.0, EPS, "Energia >= 50")
	assert_eq(GameState.likes, 10, "Likes >= 10")


func test_final_blow_turns_the_frame_off() -> void:
	await _arena()
	_boss.start()
	var hooks: Array = []
	_boss.final_blow.connect(func() -> void: hooks.append(true))
	_to_phase(3)
	for i: int in 3:
		_boss.take_core_hit(1)
	assert_true(_boss.is_defeated())
	assert_eq(hooks.size(), 1, "Gancho del golpe final")
	assert_true(_boss.is_screen_off(), "El filtro se cae: pantalla rota apagada")
	assert_false(_boss.get_core().is_enabled())
	assert_eq(_boss.get_reflections().size(), 0, "Los reflejos se van")
	assert_eq(_boss.get_counter_text(), "0")


func test_fight_runs_on_its_own_through_the_three_phases() -> void:
	# Humo: el jefe con su proceso (y el cazador, los Ladrones y los reflejos) en
	# fisica real unos segundos por fase, sin errores.
	await _arena()
	_boss.auto_process = true
	_boss.get_core().auto_process = true
	_hunter.auto_process = true
	_boss.start()
	await wait_physics_frames(300)
	assert_true(_boss.is_fighting())
	assert_ne(_boss.get_attack_state(), Curator.ATTACK_GAP, "Ha empezado la sesion")
	_to_phase(2)
	await wait_physics_frames(240)
	assert_eq(_boss.get_phase(), 2)
	_to_phase(3)
	await wait_physics_frames(240)
	assert_eq(_boss.get_phase(), 3)
	assert_eq(_boss.get_reflections().size(), 1)
