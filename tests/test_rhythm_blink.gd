# Metronomo y plataformas que parpadean (scripts/levels/rhythm_zone.gd y
# scripts/levels/blink_platform.gd; paso 5 de docs/propuesta-1-3.md §7, §5.3,
# 2026-10-19): el compas se acelera cada cycles_per_step ciclos y vuelve al
# primero con loop (sin loop se queda en el ultimo); arranca al entrar Isak
# (on_enter) o siempre; tiempo del mundo (el Debug lo ralentiza); vuelve al
# principio al reaparecer. La plataforma sigue su metronomo: encendida
# on_fraction del ciclo desplazada offset, solida solo encendida, parpadeo de
# aviso de 9 cuadros antes de apagarse, segmentos que se vacian, Isak cae sin
# dano al apagarse y no se materializa con Isak dentro.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const RHYTHM_SCENE: PackedScene = preload("res://scenes/levels/rhythm_zone.tscn")
const BLINK_SCENE: PackedScene = preload("res://scenes/levels/blink_platform.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"energy": GameState.debug_energy,
	}
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-3000.0, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


## Metronomo en la celda (0, -5) con la zona [0, -10, 40, 10] (encima del suelo plano).
func _rhythm(steps: Array = [3.2, 2.6, 2.0], per_step: int = 4, loop: bool = true,
		start: String = RhythmZone.START_ALWAYS) -> RhythmZone:
	var r := RHYTHM_SCENE.instantiate() as RhythmZone
	r.object_id = &"ritmo_test"
	r.zone = [0, -10, 40, 10]
	r.tempo_steps_s = steps
	r.cycles_per_step = per_step
	r.loop = loop
	r.start_mode = start
	r.position = Vector2(0.0, -5.0 * T)
	_world.add_child(r)
	r.set_physics_process(false)
	r.reset()
	return r


func _blink(col: int, row: int, group: StringName = &"A", offset: float = 0.0,
		on_fraction: float = 0.5) -> BlinkPlatform:
	var b := BLINK_SCENE.instantiate() as BlinkPlatform
	b.rhythm_id = &"ritmo_test"
	b.group_id = group
	b.offset = offset
	b.on_fraction = on_fraction
	b.width_tiles = 2
	b.position = Vector2(col * T, row * T)
	_world.add_child(b)
	b.set_physics_process(false)
	b.refresh()
	return b


func _step(rhythm: RhythmZone, platforms: Array = [], count: int = 1) -> void:
	for i: int in count:
		rhythm.step(DT)
		for p: BlinkPlatform in platforms:
			p.refresh()
		_sim.step()


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())


# --- Metronomo ---

func test_tempo_speeds_up_every_four_cycles_and_loops() -> void:
	var r: RhythmZone = _rhythm()
	assert_almost_eq(r.get_cycle_s(), 3.2, EPS, "Empieza en el compas lento")
	r.advance(3.2 * 4.0 - 0.01)
	assert_eq(r.get_cycle_count(), 3)
	assert_almost_eq(r.get_cycle_s(), 3.2, EPS, "Cuatro ciclos en el primero")
	r.advance(0.02)
	assert_eq(r.get_step_index(), 1, "Al quinto ciclo, mas rapido")
	assert_almost_eq(r.get_cycle_s(), 2.6, EPS)
	r.advance(2.6 * 4.0)
	assert_almost_eq(r.get_cycle_s(), 2.0, EPS, "Despues, el mas rapido")
	r.advance(2.0 * 4.0)
	assert_eq(r.get_step_index(), 0, "Con loop vuelve al compas lento")
	assert_almost_eq(r.get_cycle_s(), 3.2, EPS)


func test_without_loop_stays_on_the_fastest() -> void:
	var r: RhythmZone = _rhythm([2.0, 1.5], 2, false)
	r.advance(2.0 * 2.0 + 1.5 * 2.0 + 1.5 * 6.0 + 0.1)
	assert_almost_eq(r.get_cycle_s(), 1.5, EPS, "Sin loop se queda en el ultimo")


func test_phase_and_beat_signal() -> void:
	var r: RhythmZone = _rhythm()
	var beats: Array = []
	r.beat.connect(func(n: int) -> void: beats.append(n))
	r.advance(1.6)
	assert_almost_eq(r.get_beat_phase(), 0.5, EPS, "Fase de 0 a 1")
	assert_almost_eq(r.get_cycle_time(), 1.6, EPS)
	r.advance(1.6)
	assert_eq(beats, [1], "Un latido al empezar cada ciclo")
	assert_almost_eq(r.get_beat_phase(), 0.0, EPS)


func test_on_enter_waits_for_isak_inside_the_zone() -> void:
	var r: RhythmZone = _rhythm([3.2], 4, true, RhythmZone.START_ON_ENTER)
	_step(r, [], 30)
	assert_false(r.is_started(), "Fuera de la zona no arranca")
	assert_almost_eq(r.get_cycle_time(), 0.0, EPS)
	_isak.global_position = Vector2(5.0 * T, 0.0)
	_sim.settle()
	_step(r, [], 30)
	assert_true(r.is_started(), "Arranca al entrar Isak")
	assert_gt(r.get_cycle_time(), 0.3)


func test_world_time_debug_slows_the_rhythm() -> void:
	var r: RhythmZone = _rhythm()
	_step(r, [], 60)
	var normal: float = r.get_cycle_time()
	r.reset()
	_activate_debug()
	_step(r, [], 60)
	var slowed: float = r.get_cycle_time()
	assert_almost_eq(slowed / normal, WorldTime.scale(), 0.02, "Con el Debug el compas va en tiempo del mundo")
	assert_lt(slowed, normal * 0.6, "Mas lento")


func test_respawn_resets_to_the_start() -> void:
	var r: RhythmZone = _rhythm([3.2, 2.6], 1, true, RhythmZone.START_ON_ENTER)
	_isak.global_position = Vector2(5.0 * T, 0.0)
	_sim.settle()
	_step(r, [], roundi(4.0 / DT))
	assert_eq(r.get_step_index(), 1)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_almost_eq(r.get_cycle_time(), 0.0, EPS, "Fase 0")
	assert_eq(r.get_step_index(), 0, "Compas lento")
	assert_false(r.is_started(), "Espera a que Isak vuelva a entrar")


# --- Plataforma ---

func test_platform_follows_the_rhythm_with_its_offset() -> void:
	var r: RhythmZone = _rhythm()
	var a: BlinkPlatform = _blink(10, -2, &"A", 0.0)
	var b: BlinkPlatform = _blink(14, -2, &"B", 0.5)
	assert_true(a.is_solid(), "A encendida al empezar")
	assert_false(b.is_solid(), "B apagada (desfasada medio ciclo)")
	r.advance(1.7)
	a.refresh()
	b.refresh()
	assert_false(a.is_solid(), "Al pasar on_fraction, A se apaga")
	assert_true(b.is_solid(), "Y B se enciende")


func test_warning_blinks_nine_frames_before_switching_off() -> void:
	var r: RhythmZone = _rhythm()
	var a: BlinkPlatform = _blink(10, -2)
	assert_almost_eq(a.get_warn_s(), 0.75, EPS, "9 cuadros a 12 fps")
	var warned: Array = []
	a.warning_started.connect(func() -> void: warned.append(r.get_cycle_time()))
	assert_eq(a.get_lit_segments(), BlinkPlatform.SEG_COUNT, "Cuatro segmentos al encenderse")
	r.advance(0.8)
	a.refresh()
	assert_false(a.is_warning())
	assert_lt(a.get_lit_segments(), BlinkPlatform.SEG_COUNT, "Los segmentos se vacian")
	r.advance(0.1)
	a.refresh()
	assert_true(a.is_warning(), "Los ultimos 0,75 s avisa")
	assert_eq(warned.size(), 1)
	assert_almost_eq(a.get_time_to_off(), 0.7, EPS)
	assert_true(a.is_solid(), "Avisando sigue solida")


func test_isak_falls_without_damage_when_it_switches_off() -> void:
	var r: RhythmZone = _rhythm()
	var a: BlinkPlatform = _blink(10, -2)
	_isak.global_position = Vector2(11.0 * T, -2.0 * T)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	_step(r, [a], 10)
	assert_true(_isak.is_on_floor(), "De pie en la plataforma encendida")
	assert_almost_eq(_isak.global_position.y, -2.0 * T, 1.0)
	_step(r, [a], roundi(1.8 / DT))
	assert_false(a.is_solid(), "Apagada")
	_step(r, [a], 40)
	assert_almost_eq(_isak.global_position.y, 0.0, 1.0, "Cae al suelo de abajo")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano")


func test_does_not_materialize_with_isak_inside() -> void:
	var r: RhythmZone = _rhythm()
	var a: BlinkPlatform = _blink(10, -1, &"A", 0.5)
	assert_false(a.is_solid())
	# Isak de pie en el suelo, dentro de la caja de la plataforma (fila -1).
	_isak.global_position = Vector2(11.0 * T, 0.0)
	_sim.settle()
	r.advance(1.7)
	a.refresh()
	assert_true(a.wants_on(), "Le toca encenderse")
	assert_false(a.is_solid(), "Con Isak dentro no se materializa")
	_isak.global_position = Vector2(20.0 * T, 0.0)
	a.refresh()
	assert_true(a.is_solid(), "Al salir Isak, si")


func test_without_rhythm_always_on() -> void:
	var a: BlinkPlatform = _blink(10, -2)
	a.rhythm_id = &"no_existe"
	a.refresh()
	assert_true(a.is_solid())
	assert_false(a.is_warning())
