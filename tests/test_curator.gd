# La Curadora, jefe del Mundo 3: datos y logica de la marca (paso 14 de
# docs/propuesta-mundo-3.md §8, 2026-10-27; diseño en §5.3). El punto debil
# (WeakPoint, la «pantalla rota») solo esta activo en las ventanas: sin el Debug
# el pulso no marca; con el Debug activo lo marca y el laser es UN golpe por
# marca (laps.<n>.mark_hits = 1) sin necesitar el Debug; el golpe cierra la
# ventana. Fase 2 «De espaldas»: el pulso y el laser solo llegan por el espejo
# cazador mirando a un espejo de esquina (WeakPoint.set_via_only). Sin arena:
# el jefe y un espejo cazador en un nodo de prueba, con el tiempo a mano. Las
# fases en la arena real 3-boss: tests/test_curator_arena.gd (paso 15).
extends GutTest

const CURATOR_SCENE: PackedScene = preload("res://scenes/bosses/curator.tscn")
const HUNTER_SCENE: PackedScene = preload("res://scenes/levels/hunter_mirror.tscn")
const PATH: String = "user://test_curator.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String
var _saved_lap: int
var _saved_debug: bool = false
var _root: Node2D
var _boss: Curator
var _hunter: HunterMirror
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_lap = GameState.lap
	# El Debug desbloqueado no lo quita reset_progress: se devuelve en after_each (paso 20 del Mundo 3:
	# dejarlo encendido hacia que test_debug_chip, test_dnd_switch y test_eco_encounter fallaran en la suite).
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()


func after_each() -> void:
	_root = null
	_boss = null
	_hunter = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## El jefe y el espejo cazador de la arena (columna 9, fila 9) sin nivel ni Isak.
func _setup(lap: int = 1) -> void:
	_root = Node2D.new()
	_boss = CURATOR_SCENE.instantiate() as Curator
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
	_boss.position = Vector2(6, 1) * TILE
	_root.add_child(_boss)
	_hunter = HUNTER_SCENE.instantiate() as HunterMirror
	_hunter.object_id = &"cazador"
	_hunter.facing = "n"
	_hunter.auto_process = false
	_hunter.position = Vector2(9, 9) * TILE
	_root.add_child(_hunter)
	add_child_autofree(_root)
	_boss.get_core().auto_process = false
	await wait_physics_frames(2)
	_boss.start()


func _debug_on() -> void:
	if not DebugMode.is_active():
		for i: int in roundi(_config.activation_hold_s / DT):
			DebugMode.step(DT, true)
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


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


## Disparo del laser que llega al cazador (lo desvia hacia donde mira).
func _laser_into_hunter(damage: float = 1.0) -> LaserProjectile:
	var shot := LaserProjectile.new()
	shot.auto_process = false
	shot.damage = damage
	add_child_autofree(shot)
	shot.global_position = _hunter.get_center() + Vector2(-80.0, 0.0)
	var answer: Dictionary = _hunter.laser_reflection(shot, _hunter.get_center())
	assert_false(answer.is_empty(), "El cazador desvia el laser")
	return shot


# --- Datos ---

func test_data_laps_hits_and_marks() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/curator.json"))
	assert_eq(data["id"], "curator")
	assert_eq(int(data["world"]), 3)
	var expect: Dictionary = {"1": [[3, 3, 3], 4.0, 4.0], "2": [[4, 4, 4], 3.0, 5.0], "3": [[4, 4, 4], 2.5, 6.0]}
	for lap: String in expect:
		var entry: Dictionary = data["laps"][lap]
		assert_eq(str((entry["hits_per_phase"] as Array).map(func(v: Variant) -> int: return int(v))), str(expect[lap][0]), "Golpes por fase, acceso %s" % lap)
		assert_almost_eq(float(entry["mark_duration_s"]), float(expect[lap][1]), EPS, "Marca, acceso %s" % lap)
		assert_eq(int(entry["mark_hits"]), 1, "Un golpe por marca, acceso %s" % lap)
		assert_almost_eq(float(entry["charger_cooldown_s"]), float(expect[lap][2]), EPS, "Cargadores, acceso %s" % lap)
	var vm: Dictionary = data["validation_model"]
	for key: String in ["min_margin", "window_k", "misses_per_window", "early_debug_s", "laps"]:
		assert_true(vm.has(key), "validation_model.%s (como el de Autoplay)" % key)
	assert_eq(float(data["respawn_min_energy"]), 50.0)
	assert_eq(int(data["respawn_min_likes"]), 10)


func test_lap_settings_reach_the_weak_point() -> void:
	for lap: int in [1, 2, 3]:
		await _setup(lap)
		var hits: int = 9 if lap == 1 else 12
		assert_eq(_boss.get_total_hits(), hits, "Golpes totales, acceso %d" % lap)
		assert_almost_eq(_boss.get_core().get_mark_duration(), [4.0, 3.0, 2.5][lap - 1], EPS, "Marca, acceso %d" % lap)
		assert_eq(_boss.get_core().get_mark_hits(), 1, "Un golpe por marca, acceso %d" % lap)
		assert_eq(_boss.get_counter_text(), "99+")
		_root.queue_free()
		await wait_physics_frames(1)


# --- La marca (fases 1 y 3) ---

func test_core_only_active_in_windows() -> void:
	await _setup()
	assert_false(_boss.get_core().is_enabled(), "Fuera de la ventana el punto debil no esta")
	_boss.open_window(5.0)
	assert_true(_boss.get_core().is_enabled(), "En la ventana, si")
	assert_eq(_boss.get_attack_state(), Curator.ATTACK_WINDOW)
	_boss.close_window()
	assert_false(_boss.get_core().is_enabled(), "Al cerrarse, otra vez no")


func test_without_debug_pulse_does_not_mark() -> void:
	await _setup()
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	core.receive_pulse(_pulse_area(core.global_position))
	assert_false(core.is_marked(), "Sin el Debug el pulso no marca")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 9, "Sin marca el laser no hace dano")
	_debug_on()
	assert_true(core.receive_pulse(_pulse_area(core.global_position)), "Con el Debug el pulso la alcanza")
	assert_true(core.is_marked(), "Con el Debug activo, marca")
	assert_almost_eq(core.get_mark_time_left(), 4.0, EPS, "Caché: 4 s")


func test_one_hit_per_mark_without_debug_and_window_closes() -> void:
	await _setup()
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	DebugMode.reset()
	assert_true(core.is_marked(), "La marca sigue sin el Debug")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "Un golpe sin el Debug")
	assert_false(core.is_marked(), "La marca termina con el golpe")
	assert_false(_boss.is_window_open(), "Un golpe por ventana: se cierra")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "El segundo laser ya no cuenta")


func test_mark_hits_ends_the_mark_even_with_the_window_open() -> void:
	# WeakPoint solo: con mark_hits = 1 la marca acaba al primer golpe.
	await _setup()
	var core: WeakPoint = _boss.get_core()
	core.set_enabled(true)
	# Sin el jefe escuchando: solo la regla de la marca (sin cambios de fase).
	core.hit.disconnect(_boss._on_weak_point_hit)
	var hits: Array = []
	core.hit.connect(func(d: int, _s: Node) -> void: hits.append(d))
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	DebugMode.reset()
	core.on_laser_hit(2.0, null)
	assert_eq(hits, [2], "Laser 4: un golpe de 2")
	assert_false(core.is_marked(), "Y la marca termina")
	core.set_mark_hits(0)
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	DebugMode.reset()
	core.on_laser_hit(1.0, null)
	core.on_laser_hit(1.0, null)
	assert_eq(hits.size(), 3, "Sin tope (mark_hits 0, Alerta Mayor) cuenta todos")
	assert_true(core.is_marked(), "Y la marca sigue")


func test_mark_expires_and_is_lost_on_phase_change() -> void:
	await _setup()
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	DebugMode.reset()
	core.advance_mark(4.0 + EPS)
	assert_false(core.is_marked(), "Caduca a los 4 s del mundo")
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	_boss.take_core_hit(3)
	assert_eq(_boss.get_phase(), 2)
	assert_false(core.is_marked(), "Se pierde al cambiar de fase")


# --- Fase 2: la via por el espejo cazador ---

func test_phase2_direct_pulse_and_laser_never_reach_the_back() -> void:
	await _setup()
	_to_phase(2)
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	assert_true(core.is_via_only(), "De espaldas")
	assert_eq(core.get_core_layer(), 0, "El laser directo no la ve")
	_debug_on()
	assert_false(core.receive_pulse(_pulse_area(core.global_position)), "El pulso directo no llega")
	assert_false(core.is_marked())
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 6, "El laser directo no dana")


func test_phase2_mark_by_the_hunter_only_with_debug_and_aimed_at_a_corner() -> void:
	await _setup()
	_to_phase(2)
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	# Mirando al norte da en el frente del marco: chispa gris, sin marca.
	_debug_on()
	_hunter.set_rest_facing("n")
	_hunter.fire_beam()
	assert_false(core.is_marked(), "Al frente del marco no marca")
	assert_true(core.is_spark_visible(), "Chispa gris en el marco")
	# Al noroeste mira al espejo de la esquina izquierda: sube y llega a la espalda.
	DebugMode.reset()
	_hunter.set_rest_facing("nw")
	assert_eq(_boss.get_hunter_corner(), Curator.SIDE_LEFT)
	_hunter.fire_beam()
	assert_false(core.is_marked(), "Sin el Debug no hay marca ni por el cazador")
	_debug_on()
	_hunter.fire_beam()
	assert_true(core.is_marked(), "Con el Debug, la marca por el cazador")
	assert_eq(_boss.get_route().size(), 3, "Camino cazador -> esquina -> espalda")
	core.clear_mark()
	_hunter.set_rest_facing("ne")
	assert_eq(_boss.get_hunter_corner(), Curator.SIDE_RIGHT, "Al noreste, el espejo de la derecha")
	_hunter.fire_beam()
	assert_true(core.is_marked(), "Tambien por la esquina derecha")


func test_phase2_laser_by_the_hunter_is_one_hit_per_mark() -> void:
	await _setup()
	_to_phase(2)
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	_hunter.set_rest_facing("nw")
	# Sin marca, el laser por el cazador no dana.
	_laser_into_hunter()
	assert_eq(_boss.get_remaining_hits(), 6, "Sin marca no dana")
	_debug_on()
	_hunter.fire_beam()
	DebugMode.reset()
	# Mirando a otro lado (este) el laser no llega a la espalda.
	_hunter.set_rest_facing("e")
	_laser_into_hunter()
	assert_eq(_boss.get_remaining_hits(), 6, "Si el cazador no mira a una esquina, no llega")
	assert_true(core.is_marked(), "La marca sigue")
	_hunter.set_rest_facing("nw")
	var shot: LaserProjectile = _laser_into_hunter()
	assert_eq(_boss.get_remaining_hits(), 5, "Por el cazador a la esquina: un golpe sin Debug")
	assert_false(core.is_marked(), "Un golpe por marca")
	assert_false(_boss.is_window_open(), "Y la ventana se cierra")
	await wait_physics_frames(1)
	assert_true(not is_instance_valid(shot) or shot.is_finished(), "El disparo se apaga en el camino")


func test_nothing_else_damages() -> void:
	await _setup()
	_boss.open_window(5.0)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	assert_false(core.receive_ground_pound(core.global_position), "El golpe al suelo no hace nada")
	assert_eq(_boss.get_remaining_hits(), 9)


# --- Arte final (paso 23, AutoSprite) ---

func test_final_art_follows_its_state() -> void:
	await _setup()
	assert_true(_boss.has_final_art(), "Cuadros de tools/import_boss_curator.py")
	assert_eq(String(_boss.get_art_frame()[0]), "idle", "Fase 1 entre ataques")
	var sprite := _boss.get_node(^"Frame") as Sprite2D
	var rect: Rect2 = _boss.get_frame_rect()
	assert_eq(sprite.global_position, rect.position - Vector2(Curator.ART_MARGIN_PX, Curator.ART_MARGIN_PX + Curator.ART_TOP_PX),
		"El lienzo sobresale de la caja (la caja no cambia)")
	assert_eq(sprite.texture.get_size(), Vector2(576.0, 356.0))
	_boss.open_window(5.0)
	_boss.advance(DT)
	assert_eq(String(_boss.get_art_frame()[0]), "frame_down", "Ventana: baja a encuadrar")
	_to_phase(2)
	_boss.advance(DT)
	assert_eq(_boss.get_art_frame(), ["turn", 0], "Fase 2: empieza a darse la vuelta")
	for i: int in roundi(1.5 / DT):
		_boss.advance(DT)
	assert_eq(_boss.get_art_frame(), ["turn", 12], "De espaldas: el ultimo cuadro del giro")
	_to_phase(3)
	_boss.advance(DT)
	assert_eq(_boss.get_art_frame(), ["turn", 12], "Fase 3: se vuelve de frente (giro al reves)")
	for i: int in roundi(1.2 / DT):
		_boss.advance(DT)
	assert_ne(String(_boss.get_art_frame()[0]), "turn", "Tras el giro, de frente")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	_boss.advance(DT)
	assert_eq(String(_boss.get_art_frame()[0]), "defeat", "Golpe final: se apaga")
