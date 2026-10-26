# Autoplay, jefe del Mundo 2, y su arena «Reproducción automática» (pasos 15-16
# de docs/propuesta-mundo-2.md §8, 2026-10-23). Paso 15: el cabezal (WeakPoint
# en modo golpe al suelo): la pausa solo con el Debug activo + golpe al suelo
# en su caja; en pausa el laser a la pantalla dana; sin pausa, chispa gris; el
# pulso nunca; heal_hits de BossBase. Paso 16: la arena 2-boss (cabe entera en
# pantalla, cinta de tarjetas, 4 cargadores, Debug x0,25 / x0,7) y las fases
# 1-3 con el tiempo avanzado a mano (advance), como las del jefe previo.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/2-boss.tscn")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_autoplay.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String
var _saved_lap: int
var _level: GeneratedLevel
var _boss: Autoplay
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
	_boss = _level.get_node(^"Objects/autoplay") as Autoplay
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
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


## Avanza el jefe y la pausa `seconds` del mundo (con el Isak manual si hay).
func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)
		if _sim != null:
			_sim.step()


## Avanza hasta que `cond` se cumpla (como mucho `max_s`); devuelve los segundos.
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


## Pies de Isak sobre el cabezal (la superficie de la barra).
func _feet_on_playhead() -> Vector2:
	return Vector2(_boss.get_playhead_x(), _boss.get_bar_surface_y())


## Pausa con el Debug + golpe al suelo en el cabezal y apaga el Debug.
func _pause() -> void:
	_debug_on()
	assert_true(_boss.get_core().receive_ground_pound(_feet_on_playhead()), "El golpe cae en la caja del cabezal")
	assert_true(_boss.is_paused(), "En pausa")
	DebugMode.reset()


func _to_phase(phase: int) -> void:
	while _boss.get_phase() < phase:
		_boss.take_core_hit(1)


## PulseArea falsa: un circulo de 96 px en `pos`.
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


# --- Paso 16: arena ---

func test_arena_fits_on_screen_without_goal() -> void:
	await _arena()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/2-boss.json"))
	var grid: Array = data["grid"]
	var size := Vector2(String(grid[0]).length() * TILE, grid.size() * TILE)
	assert_eq(size, Vector2(1280, 704), "20 x 11 tiles")
	var view := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	assert_true(size.x <= view.x and size.y <= view.y, "La arena cabe entera en la pantalla (%s en %s)" % [size, view])
	var isak: Isak = _level.get_isak()
	assert_eq(isak.camera_limits, Rect2i(0, 0, 1280, 704), "Limites de la camara = la arena")
	# Con la camara arriba del todo la vista cubre toda la arena (fija: no hay hacia donde moverse).
	assert_true(Rect2(Vector2.ZERO, view).encloses(Rect2(Vector2.ZERO, size)), "Toda la arena a la vista")
	assert_null(_level.get_node_or_null(^"Goal"), "Sin meta: la pelea acaba con el golpe final")
	assert_eq(data["kind"], "boss")
	assert_almost_eq(float(data["debug_drain_scale"]), 0.25, EPS, "Debug a un cuarto de gasto")
	assert_almost_eq(float(data["debug_world_scale"]), 0.7, EPS, "Mundo a x0,7 con el Debug")
	var chargers: Array = []
	for o: Dictionary in data["objects"]:
		if o["type"] == "charger":
			chargers.append(int(o["x"]))
	assert_eq(chargers, [1, 6, 13, 18], "4 cargadores en el suelo")
	assert_false(bool((_boss.get_config().get("camera", {}) as Dictionary).get("follow", true)), "Camara fija")


func test_bar_is_one_way_and_screen_is_not_solid() -> void:
	await _arena()
	var tiles := _level.get_node(^"Tiles") as TileMapLayer
	for col: int in range(5, 15):
		assert_true(tiles.get_cell_source_id(Vector2i(col, 6)) >= 0, "Barra en la columna %d" % col)
	for col: int in range(6, 14):
		for row: int in range(1, 5):
			assert_eq(tiles.get_cell_source_id(Vector2i(col, row)), -1, "La pantalla no es terreno")
	assert_almost_eq(_boss.get_bar_surface_y(), 384.0, EPS, "Superficie de la barra en la fila 6")
	assert_eq(_boss.get_screen_rect(), Rect2(384, 64, 512, 256), "Pantalla de 8 x 4 en las columnas 6-13")


func test_conveyor_cards_rise_and_wrap_without_touching_the_ceiling() -> void:
	await _arena()
	var cards: Array[MovingPlatform] = _boss.get_conveyor_cards()
	assert_eq(cards.size(), 6, "Tres tarjetas por columna (paso 17: la espera a una tarjeta util cabe en la ventana)")
	var card: MovingPlatform = cards[0]
	# Con sync_to_physics la posicion del nodo va un paso por detras: origen + desplazamiento.
	var y0: float = card.get_origin().y + card.get_offset().y
	_advance(1.0)
	assert_almost_eq(y0 - (card.get_origin().y + card.get_offset().y), 32.0, 0.5, "Sube 0,5 tiles/s")
	var top_seen: float = INF
	var bottom_seen: float = -INF
	var wrapped: bool = false
	var prev: float = card.get_origin().y + card.get_offset().y
	for i: int in ceili(15.0 / DT):
		_boss.advance(DT)
		var y: float = card.get_origin().y + card.get_offset().y
		top_seen = minf(top_seen, y)
		bottom_seen = maxf(bottom_seen, y)
		if y > prev + 100.0:
			wrapped = true
		prev = y
	assert_true(wrapped, "Al salir por arriba reaparece abajo")
	# Superficie (centro - 12) entre la fila 3 (192) y el suelo (640).
	assert_true(top_seen - 12.0 >= 192.0 - 1.0, "No sube mas alla de la fila 3: Isak no toca el techo (%s)" % top_seen)
	assert_true(bottom_seen - 12.0 <= 640.0 + 1.0, "Sale de la superficie del suelo (%s)" % bottom_seen)


func test_lap_settings_per_access() -> void:
	# Duracion de la pelea (2026-10-23, §8.1): 4/4/4 en Caché y 5/5/5 en Kernel y
	# Raíz, un impacto por pausa y los rayos de la fase 3 de Raíz en dos tandas.
	var expect: Dictionary = {1: [[4, 4, 4], 4.0, 4.0, 1, 1], 2: [[5, 5, 5], 3.0, 5.0, 1, 1], 3: [[5, 5, 5], 2.5, 6.0, 1, 2]}
	for lap: int in expect:
		await _arena(lap)
		_boss.start()
		assert_eq(str(_boss.get_hits_per_phase()), str(expect[lap][0]), "Golpes por fase, acceso %d" % lap)
		assert_almost_eq(_boss.get_core().get_mark_duration(), float(expect[lap][1]), EPS, "Pausa, acceso %d" % lap)
		var charger := _level.get_node(^"Objects/cargador_1") as Charger
		assert_almost_eq(charger.cooldown_s, float(expect[lap][2]), EPS, "Cargadores, acceso %d" % lap)
		assert_eq(_boss.get_pause_hits(), int(expect[lap][3]), "Impactos por pausa, acceso %d" % lap)
		_to_phase(3)
		assert_eq(_boss.get_ray_volleys(), int(expect[lap][4]), "Tandas de rayos en la fase 3, acceso %d" % lap)
		_level.queue_free()
		await wait_physics_frames(1)


func test_start_shows_full_counter_with_the_playhead_hidden() -> void:
	await _arena()
	_boss.start()
	assert_eq(_boss.get_counter_text(), "99+")
	assert_true(_boss.get_core().is_enabled(), "El cabezal esta activo")
	assert_false(_boss.get_core().is_revealed(), "Sin el Debug no se ve el boton de pausa")
	_debug_on()
	# El revelado se actualiza en WeakPoint._process: hay que esperar un frame
	# de proceso (con la carga, varios pasos de fisica caben en el mismo frame).
	await wait_process_frames(1)
	assert_true(_boss.get_core().is_revealed(), "Con el Debug se ve en rojo")


# --- Paso 15: la pausa (Debug + golpe al suelo) y el dano ---

func test_ground_pound_without_debug_only_sparks() -> void:
	await _arena()
	_boss.start()
	assert_true(_boss.get_core().receive_ground_pound(_feet_on_playhead()), "Cae en la caja")
	assert_false(_boss.is_paused(), "Sin el Debug no hay pausa")
	assert_true(_boss.get_core().is_spark_visible(), "Chispa gris en el cabezal")


func test_pulse_with_debug_never_pauses() -> void:
	await _arena()
	_boss.start()
	_debug_on()
	assert_false(_boss.get_core().receive_pulse(_pulse_area(_boss.get_playhead_position())), "El pulso no le hace nada")
	assert_false(_boss.is_paused())


func test_ground_pound_off_the_playhead_does_not_pause() -> void:
	await _arena()
	_boss.start()
	_debug_on()
	var feet: Vector2 = _feet_on_playhead() + Vector2(2.0 * TILE, 0.0)
	assert_false(_boss.get_core().receive_ground_pound(feet), "Fuera de la caja de 1 x 1")
	assert_false(_boss.is_paused())
	assert_false(_boss.get_core().receive_ground_pound(_feet_on_playhead() + Vector2(0.0, 4.0 * TILE)),
		"Desde el suelo, bajo la barra, tampoco")
	assert_false(_boss.is_paused())


func test_real_ground_pound_with_debug_pauses() -> void:
	await _arena()
	_boss.start()
	var isak: Isak = _level.get_isak()
	isak.global_position = _feet_on_playhead()
	_debug_on()
	isak.land_ground_pound()
	assert_true(_boss.is_paused(), "El golpe al suelo real de Isak con el Debug pausa al jefe")
	assert_almost_eq(_boss.get_core().get_mark_time_left(), 4.0, EPS, "4 s del mundo en Caché")
	assert_eq(_boss.get_attack_state(), Autoplay.ATTACK_PAUSED)


func test_real_ground_pound_without_debug_does_not_pause() -> void:
	await _arena()
	_boss.start()
	var isak: Isak = _level.get_isak()
	isak.global_position = _feet_on_playhead()
	isak.land_ground_pound()
	assert_false(_boss.is_paused())
	assert_true(_boss.get_core().is_spark_visible(), "Chispa gris")


func test_laser_without_pause_sparks_and_in_pause_hits() -> void:
	await _arena()
	_boss.start()
	var core: WeakPoint = _boss.get_core()
	var areas: Array = core.get_children().filter(func(n: Node) -> bool: return n is Area2D)
	assert_eq(areas.size(), 2, "La pantalla y su pie reciben el laser")
	assert_eq(LaserProjectile.find_laser_target(areas[0]), core, "El laser a la pantalla llega al cabezal")
	assert_eq((areas[0] as Area2D).collision_layer, WeakPoint.LAYER_ENEMY, "El laser ve la pantalla")
	assert_eq(core.get_core_layer(), 0, "Pero no el cabezal")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 12, "Sin pausa no dana")
	assert_true(core.is_spark_visible(), "Chispa gris en la pantalla")
	_pause()
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 11, "En pausa el laser es un golpe, sin el Debug")
	assert_eq(_boss.get_counter_text(), "91")
	assert_false(_boss.is_paused(), "Un impacto acaba la pausa (pause_hits 1)")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 11, "El segundo laser ya no dana")
	for i: int in 3:
		_pause()
		core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_phase(), 2, "Cuatro pausas con su golpe: fase 2")
	assert_false(_boss.is_paused(), "La pausa se pierde al cambiar de fase")


func test_laser_4_counts_two_hits_in_pause() -> void:
	await _arena()
	_boss.start()
	_pause()
	_boss.get_core().on_laser_hit(2.0, null)
	assert_eq(_boss.get_remaining_hits(), 10, "Laser 4: 2 golpes en un impacto")
	assert_false(_boss.is_paused(), "Y la pausa se acaba igual")


func test_pause_expires_after_its_duration_and_cannot_be_refreshed_without_debug() -> void:
	await _arena()
	_boss.start()
	_pause()
	_advance(2.0)
	_boss.get_core().receive_ground_pound(_feet_on_playhead())
	assert_almost_eq(_boss.get_core().get_mark_time_left(), 2.0, 0.02, "Sin el Debug no se refresca")
	_advance(2.0 + DT)
	assert_false(_boss.is_paused(), "Caduca a los 4 s")
	_boss.get_core().on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 12, "Ya no dana")


func test_heal_hits_never_goes_above_the_phase_start() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	assert_eq(_boss.heal_hits(1), 0, "Fase 2 entera: nada que recuperar")
	_boss.take_core_hit(1)
	assert_eq(_boss.get_remaining_hits(), 7)
	assert_eq(_boss.heal_hits(3), 1, "Solo hasta el inicio de la fase")
	assert_eq(_boss.get_remaining_hits(), 8)


# --- Paso 16: fase 1 «Clips» ---

func test_phase1_two_clips_then_window_with_the_playhead_still() -> void:
	await _arena()
	_boss.start()
	assert_eq(_boss.get_clip(), Autoplay.ATTACK_GAP, "Espera antes del primer clip")
	_advance(1.5 + DT)
	assert_eq(_boss.get_clip(), Autoplay.CLIP_WAVE, "Primer clip: la ola")
	var floor_banner := _boss.get_banners()["floor"] as SpamBanner
	var bar_banner := _boss.get_banners()["bar"] as SpamBanner
	assert_true(floor_banner.is_warning(), "Avisa")
	assert_almost_eq(floor_banner.get_warn_s(), 0.75, EPS, "9 cuadros")
	assert_false(bar_banner.is_busy(), "Nunca los dos carriles a la vez")
	_advance(0.75)
	assert_true(floor_banner.is_sweeping(), "Barre el suelo")
	assert_almost_eq(floor_banner.get_corridor_px(), 18.0 * TILE, EPS, "De muro a muro")
	var t: float = _advance_until(func() -> bool: return _boss.is_window_open(), 8.0)
	assert_true(_boss.is_window_open(), "Tras dos clips (ola y rayos), la ventana")
	assert_true(t > 1.0, "Despues del barrido, los rayos y los huecos")
	assert_eq(_boss.get_screen_text(), "A continuación…")
	assert_almost_eq(_boss.get_window_time_left(), 5.0, 0.05, "5 s del mundo")
	assert_almost_eq(_boss.get_playhead_x(), _boss.get_slot_x("center"), EPS, "Cabezal quieto en el centro")
	_advance(2.0)
	assert_almost_eq(_boss.get_playhead_x(), _boss.get_slot_x("center"), EPS, "Sigue quieto (Caché)")
	_advance(3.0 + 2.0 * DT)
	assert_false(_boss.is_window_open())
	assert_eq(_boss.get_clip(), Autoplay.CLIP_SWEEP_HIGH, "Siguiente clip: el barrido alto")


func test_playhead_advances_along_the_bar_during_clips() -> void:
	await _arena()
	_boss.start()
	var x0: float = _boss.get_playhead_x()
	_advance(1.0)
	assert_almost_eq(_boss.get_playhead_x() - x0, 1.5 * TILE, 0.5, "1,5 tiles/s con la reproduccion")


func test_rays_fall_one_after_another_in_distinct_columns_starting_on_isak() -> void:
	await _arena(1, true)
	_place_isak(4, 9)
	_boss.start()
	_boss.start_clip(Autoplay.CLIP_RAYS)
	_advance(DT)
	var bells: Array[AlarmBell] = _boss.get_bells()
	assert_true(bells[0].is_warning(), "Primer rayo avisando")
	assert_almost_eq(bells[0].get_warn_s(), 0.75, EPS, "9 cuadros")
	assert_almost_eq(bells[0].global_position.x, 4.5 * TILE, EPS, "En la columna de Isak")
	assert_false(bells[1].is_busy(), "El segundo aun no")
	_advance(1.1)
	var cols: Array = []
	for b: AlarmBell in bells:
		assert_true(b.get_wave_count() > 0 or b.is_busy(), "Han salido los tres")
		cols.append(roundi(b.global_position.x / TILE - 0.5))
	assert_eq(cols.size(), 3)
	assert_ne(cols[0], cols[1])
	assert_ne(cols[1], cols[2])
	assert_ne(cols[0], cols[2])
	var rect: Rect2 = bells[0].get_wave_rect()
	assert_almost_eq(rect.position.y, 64.0, EPS, "Desde la fila 1")
	assert_almost_eq(rect.end.y, 640.0, EPS, "Hasta el suelo")


func test_wave_hits_the_real_isak_on_the_floor_and_the_bar_is_safe() -> void:
	await _arena(1, true)
	_place_isak(10, 9)
	_boss.start()
	_boss.start_clip(Autoplay.CLIP_WAVE)
	var before: float = GameState.sync_rate
	_advance(3.0)
	assert_lt(GameState.sync_rate, before, "La ola le da en el suelo")
	GameState.sync_rate = GameState.get_sync_rate_max()
	_level.queue_free()
	await wait_physics_frames(1)
	await _arena(1, true)
	_place_isak(10, 5)
	_boss.start()
	_boss.start_clip(Autoplay.CLIP_WAVE)
	_advance(3.0)
	assert_almost_eq(GameState.sync_rate, GameState.get_sync_rate_max(), EPS, "En la barra no")


func test_sweep_high_runs_on_the_bar_lane() -> void:
	await _arena()
	_boss.start()
	_boss.start_clip(Autoplay.CLIP_SWEEP_HIGH)
	var banner := _boss.get_banners()["bar"] as SpamBanner
	assert_true(banner.is_warning())
	assert_almost_eq(banner.global_position.y, 384.0, EPS, "Superficie de la barra")
	assert_almost_eq(banner.get_corridor_px(), 10.0 * TILE, EPS, "Columnas 5-14")
	assert_false((_boss.get_banners()["floor"] as SpamBanner).is_busy(), "El suelo queda libre")


func test_pause_freezes_the_clip_and_the_window_then_resumes() -> void:
	await _arena()
	_boss.start()
	_advance(1.5 + 0.75 + 0.3)
	var banner := _boss.get_banners()["floor"] as SpamBanner
	assert_true(banner.is_sweeping())
	var x: float = banner.get_banner_center_x()
	var head: float = _boss.get_playhead_x()
	_pause()
	_advance(2.0)
	assert_almost_eq(banner.get_banner_center_x(), x, EPS, "La ola se congela a mitad")
	assert_almost_eq(_boss.get_playhead_x(), head, EPS, "El cabezal tambien")
	assert_eq(_boss.get_screen_text(), "En pausa")
	_advance(2.0 + DT)
	assert_false(_boss.is_paused())
	_advance(0.1)
	assert_gt(banner.get_banner_center_x(), x, "Al acabar la pausa la ola sigue")
	# En la ventana: congela la cuenta y al acabar pasa al clip siguiente.
	_advance_until(func() -> bool: return _boss.is_window_open(), 5.0)
	_advance(1.0)
	var left: float = _boss.get_window_time_left()
	_pause()
	_advance(3.0)
	assert_almost_eq(_boss.get_window_time_left(), left, EPS, "La ventana no corre en pausa")
	_advance(1.0 + 3.0 * DT)
	assert_false(_boss.is_window_open(), "Al caducar la pausa se cierra la ventana")
	assert_eq(_boss.get_clip(), Autoplay.CLIP_SWEEP_HIGH, "Y empieza el clip siguiente (ola y rayos antes de la ventana)")


## Duracion de la pelea (2026-10-23): una pausa da un golpe (pause_hits) y la
## ventana se cierra con el; la fase 1 de Caché pide cuatro ventanas.
func test_one_hit_per_pause_four_windows_go_to_phase_2_with_refills() -> void:
	await _arena()
	_boss.start()
	for i: int in 4:
		_advance_until(func() -> bool: return _boss.is_window_open(), 12.0)
		assert_true(_boss.is_window_open(), "Ventana %d" % i)
		_pause()
		if i == 3:
			GameState.debug_energy = 40.0
			GameState.sync_rate = 50.0
		_boss.get_core().on_laser_hit(1.0, null)
		if i < 3:
			assert_false(_boss.is_paused(), "La pausa acaba tras el golpe")
			assert_false(_boss.is_window_open(), "Y la ventana con ella")
			assert_eq(_boss.get_phase(), 1, "Sigue en la fase 1 tras %d golpe(s)" % (i + 1))
	assert_eq(_boss.get_phase(), 2)
	assert_eq(_boss.get_counter_text(), "66")
	assert_almost_eq(GameState.debug_energy, 65.0, EPS, "+25 de energia")
	assert_almost_eq(GameState.sync_rate, 75.0, EPS, "+25 de Sync")
	assert_false(_boss.is_window_open(), "La ventana se cierra con el cambio de fase")


# --- Paso 16: fase 2 «Siguiente video en 5» ---

## Lleva la fase 2 hasta su primera ventana.
func _phase2_window() -> void:
	_boss.start()
	_to_phase(2)
	_advance_until(func() -> bool: return _boss.is_window_open(), 20.0)
	assert_true(_boss.is_window_open(), "Ventana de la fase 2")


func test_phase2_runs_three_clips_then_the_countdown() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	var seen: Array = []
	_boss.attack_started.connect(func(a: StringName) -> void: seen.append(a))
	_advance_until(func() -> bool: return _boss.is_window_open(), 20.0)
	assert_eq(seen, [Autoplay.CLIP_COUNTDOWN, Autoplay.CLIP_WAVE, Autoplay.CLIP_RAYS, Autoplay.ATTACK_WINDOW], "Tres clips y la ventana")
	assert_eq(_boss.get_countdown(), 5, "Siguiente video en 5")
	assert_eq(_boss.get_screen_text(), "Siguiente video en 5")


func test_phase2_countdown_to_zero_heals_one_hit_and_punishes() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_boss.take_core_hit(1)
	assert_eq(_boss.get_remaining_hits(), 7)
	_advance_until(func() -> bool: return _boss.is_window_open(), 20.0)
	var ticks: Array = []
	_boss.countdown_tick.connect(func(n: int) -> void: ticks.append(n))
	var healed: Array = []
	_boss.countdown_expired.connect(func(n: int) -> void: healed.append(n))
	var seen: Array = []
	_boss.attack_started.connect(func(a: StringName) -> void: seen.append(a))
	_advance(5.0 + 2.0 * DT)
	assert_eq(ticks, [5, 4, 3, 2, 1], "Cada numero de la cuenta (sonido de accesibilidad)")
	assert_eq(healed, [1], "Llega a 0: recupera un golpe")
	assert_eq(_boss.get_remaining_hits(), 8, "Vuelve al inicio de la fase")
	assert_eq(_boss.get_counter_text(), "66")
	_advance_until(func() -> bool: return _boss.is_window_open(), 30.0)
	assert_eq(seen.size(), 4, "Tanda de 3 clips seguidos y despues la ventana: %s" % [seen])


func test_phase2_countdown_never_heals_above_the_phase_start() -> void:
	await _arena()
	_phase2_window()
	_advance(5.0 + 2.0 * DT)
	assert_eq(_boss.get_remaining_hits(), 8, "Con la fase entera no sube")


func test_phase2_pause_stops_the_countdown() -> void:
	await _arena()
	_phase2_window()
	_boss.take_core_hit(1)
	_advance(1.0)
	_pause()
	assert_true(_boss.is_countdown_stopped())
	_advance(4.0 + DT)
	assert_false(_boss.is_window_open(), "La pausa acaba y la ventana con ella")
	assert_eq(_boss.get_remaining_hits(), 7, "Pausado a tiempo: no recupera nada")


func test_phase2_playhead_seeks_to_another_slot_each_window() -> void:
	await _arena()
	_phase2_window()
	var first: String = _boss.get_slot()
	assert_almost_eq(_boss.get_playhead_x(), _boss.get_slot_x(first), EPS)
	_advance(5.0 + 2.0 * DT)
	_advance_until(func() -> bool: return _boss.is_window_open(), 30.0)
	assert_ne(_boss.get_slot(), first, "Salta a otro sitio de la barra")


func test_countdown_clip_fires_a_fan_of_three_after_3_2_1() -> void:
	await _arena(1, true)
	_place_isak(3, 9)
	_boss.start()
	_to_phase(2)
	var ticks: Array = []
	_boss.countdown_tick.connect(func(n: int) -> void: ticks.append(n))
	_boss.start_clip(Autoplay.CLIP_COUNTDOWN)
	_advance(0.7)
	assert_eq(_boss.get_shots().size(), 0, "Aun avisa")
	assert_eq(ticks, [3, 2, 1], "3-2-1 en la pantalla")
	_advance(0.1)
	var shots: Array[NotificationShot] = _boss.get_shots()
	assert_eq(shots.size(), 3, "Tres proyectiles")
	for shot: NotificationShot in shots:
		assert_lt(shot.heading.x, 0.0, "Hacia Isak (a la izquierda)")


## Paso 17 (arreglo, 2026-10-23): los proyectiles atraviesan la barra (de una
## via, a proposito) y se apagan al llegar al terreno macizo (aqui, el suelo o el
## muro), no cruzan la arena entera.
func test_countdown_shots_cross_the_bar_and_stop_at_the_terrain() -> void:
	await _arena(1, true)
	_place_isak(3, 9)
	_boss.start()
	_to_phase(2)
	_boss.start_clip(Autoplay.CLIP_COUNTDOWN)
	_advance(0.8)
	var shots: Array[NotificationShot] = _boss.get_shots()
	assert_eq(shots.size(), 3)
	var screen: Rect2 = _boss.get_screen_rect()
	var origin := Vector2(screen.get_center().x, screen.end.y)
	var ends: Array[Vector2] = []
	for shot: NotificationShot in shots:
		assert_lt(shot.travel_px, 1100.0 - 1.0, "Recorrido recortado por el terreno")
		ends.append(origin + shot.heading.normalized() * shot.travel_px)
	var floor_y: float = _level.global_position.y + 10.0 * TILE
	var wall_x: float = _level.global_position.x + 1.0 * TILE
	for end: Vector2 in ends:
		assert_gt(end.y, _boss.get_bar_surface_y(), "Pasa por debajo de la barra (la atraviesa)")
		assert_true(absf(end.y - floor_y) < 1.0 or absf(end.x - wall_x) < 1.0, "Termina en el suelo o en el muro: %s" % end)
	var seen_low: float = -INF
	for i: int in 200:
		_advance(DT)
		for shot: NotificationShot in _boss.get_shots():
			seen_low = maxf(seen_low, shot.global_position.y)
		if _boss.get_shots().is_empty():
			break
	assert_true(_boss.get_shots().is_empty(), "Se apagan al llegar al terreno")
	assert_lte(seen_low, floor_y + 1.0, "Nunca se hunden en el suelo")


# --- Paso 16: fase 3 «x2» ---

func test_phase3_doubles_everything_but_the_warnings() -> void:
	await _arena()
	_boss.start()
	_to_phase(3)
	assert_almost_eq(_boss.get_speed_scale(), 2.0, EPS)
	for card: MovingPlatform in _boss.get_conveyor_cards():
		assert_almost_eq(card.speed_scale, 2.0, EPS, "Cinta a x2")
	assert_eq(_boss.get_screen_text(), "x2")
	_boss.start_clip(Autoplay.CLIP_WAVE)
	var banner := _boss.get_banners()["floor"] as SpamBanner
	assert_almost_eq(banner.sweep_speed_px_s, 1280.0, EPS, "Ola a x2")
	assert_almost_eq(banner.get_warn_s(), 0.75, EPS, "El aviso sigue siendo de 9 cuadros")
	_advance(0.7)
	assert_true(banner.is_warning(), "Sigue avisando a los 0,7 s (a x2 seria 0,375)")
	_boss.start_clip(Autoplay.CLIP_RAYS)
	_advance(DT)
	assert_almost_eq(_boss.get_bells()[0].get_warn_s(), 0.75, EPS, "Rayos: 9 cuadros")
	_advance(0.25)
	assert_true(_boss.get_bells()[1].is_busy(), "Rayos a la mitad de separacion")
	var x0: float = _boss.get_playhead_x()
	_boss.start_clip(Autoplay.CLIP_SWEEP_HIGH)
	_advance(0.5)
	assert_almost_eq(_boss.get_playhead_x() - x0, 1.5 * TILE, 0.5, "Cabezal a x2")


func test_phase3_window_is_4_seconds() -> void:
	await _arena()
	_boss.start()
	_to_phase(3)
	_advance_until(func() -> bool: return _boss.is_window_open(), 20.0)
	assert_almost_eq(_boss.get_window_time_left(), 4.0, 0.05)


# --- Reaparicion y golpe final ---

func test_respawn_restarts_the_phase_and_clears_the_attacks() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_boss.take_core_hit(1)
	_boss.start_clip(Autoplay.CLIP_WAVE)
	GameState.debug_energy = 10.0
	_boss.restart_phase()
	assert_eq(_boss.get_remaining_hits(), 8, "Vuelve al inicio de la fase 2")
	assert_false((_boss.get_banners()["floor"] as SpamBanner).is_busy(), "Sin la ola")
	assert_almost_eq(GameState.debug_energy, 50.0, EPS, "Energia >= 50")


func test_final_blow_turns_the_screen_off() -> void:
	await _arena()
	_boss.start()
	var hooks: Array = []
	_boss.final_blow.connect(func() -> void: hooks.append(true))
	_to_phase(3)
	for i: int in 4:
		_pause()
		_boss.get_core().on_laser_hit(1.0, null)
	assert_true(_boss.is_defeated())
	assert_eq(hooks.size(), 1, "Gancho del golpe final")
	assert_true(_boss.is_screen_off(), "La pantalla se queda en negro")
	assert_false(_boss.get_core().is_enabled(), "Sin cabezal")
	assert_eq(_boss.get_counter_text(), "0")


# --- Duracion de la pelea (2026-10-23, §8.1) ---

func test_pause_ends_after_its_hit_mid_clip_and_the_clip_goes_on() -> void:
	await _arena()
	_boss.start()
	_advance(1.5 + 0.75 + 0.3)
	var banner := _boss.get_banners()["floor"] as SpamBanner
	assert_true(banner.is_sweeping())
	_pause()
	var x: float = banner.get_banner_center_x()
	_boss.get_core().on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 11)
	assert_false(_boss.is_paused(), "El impacto acaba la pausa")
	assert_eq(_boss.get_pause_impacts(), 0)
	_advance(0.1)
	assert_gt(banner.get_banner_center_x(), x, "La ola sigue")
	assert_eq(_boss.get_clip(), Autoplay.CLIP_WAVE, "El clip no se interrumpe")


func test_raiz_phase3_rays_fall_in_two_volleys() -> void:
	for lap: int in [2, 3]:
		await _arena(lap, true)
		_place_isak(9, 9)
		_boss.start()
		_to_phase(3)
		_boss.start_clip(Autoplay.CLIP_RAYS)
		var volleys: int = 1
		var t: float = 0.0
		var was_idle: bool = false
		while _boss.get_clip() == Autoplay.CLIP_RAYS and t < 10.0:
			_advance(DT)
			t += DT
			var busy: bool = _boss.get_bells().any(func(b: AlarmBell) -> bool: return b.is_busy())
			if busy and was_idle:
				volleys += 1
			was_idle = not busy
		assert_ne(_boss.get_clip(), Autoplay.CLIP_RAYS, "El clip acaba, acceso %d" % lap)
		assert_eq(volleys, 2 if lap == 3 else 1, "Tandas de rayos en la fase 3, acceso %d" % lap)
		_level.queue_free()
		await wait_physics_frames(1)
