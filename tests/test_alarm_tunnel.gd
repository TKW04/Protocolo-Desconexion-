# Tunel de alarmas, campanas y banners con ritmo (scripts/levels/alarm_tunnel.gd,
# scripts/enemies/alarm_bell.gd y spam_banner.gd con `rhythm`; paso 6 de
# docs/propuesta-1-3.md §7, §5.5, 2026-10-19): el compas del tunel lo marca la
# columna mas avanzada de Isak (no retrocede, sin bucle) y vuelve al principio
# al reaparecer; la campana avisa 9 cuadros y suelta una onda de 0,4 s que
# quita 10 una vez y empuja hacia atras; el dash la atraviesa; sigue el compas
# del tunel con su offset (o su propio intervalo); el Debug la ralentiza; el
# banner con `rhythm` usa el ciclo del metronomo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const TUNNEL_SCENE: PackedScene = preload("res://scenes/levels/alarm_tunnel.tscn")
const BELL_SCENE: PackedScene = preload("res://scenes/enemies/alarm_bell.tscn")
const BANNER_SCENE: PackedScene = preload("res://scenes/enemies/spam_banner.tscn")
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
		"dash": GameState.is_ability_unlocked(GameState.ABILITY_DASH),
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
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, _saved.dash)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


## Tunel con la zona [0, -4, 30, 4] (encima del suelo plano, en y = 0) y tres tramos.
func _tunnel() -> AlarmTunnel:
	var t := TUNNEL_SCENE.instantiate() as AlarmTunnel
	t.object_id = &"tunel_test"
	t.zone = [0, -4, 30, 4]
	t.stages = [{"x_from": 0, "x_to": 9, "cycle_s": 2.0}, {"x_from": 10, "x_to": 19, "cycle_s": 1.6},
		{"x_from": 20, "x_to": 29, "cycle_s": 1.4}]
	t.start_mode = RhythmZone.START_ON_ENTER
	t.position = Vector2(0.0, -3.0 * T)
	_world.add_child(t)
	t.set_physics_process(false)
	t.reset()
	return t


## Campana colgada en la celda (col, -3) con la onda de 3 celdas hasta el suelo.
func _bell(col: int, rhythm: String = "tunel_test", offset: float = 0.0) -> AlarmBell:
	var b := BELL_SCENE.instantiate() as AlarmBell
	b.position = Vector2((col + 0.5) * T, -2.0 * T)
	_world.add_child(b)
	b.set_physics_process(false)
	b.rhythm = rhythm
	b.offset = offset
	b.wave_tiles = 3
	b.target = _isak
	b.reset_patrol()
	return b


func _stand_at(col: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


func _step(nodes: Array, count: int = 1) -> void:
	for i: int in count:
		for n: Node in nodes:
			n.call(&"step", DT)
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


# --- Tunel ---

func test_tunnel_speeds_up_by_position_and_never_slows_down() -> void:
	var t: AlarmTunnel = _tunnel()
	assert_almost_eq(t.get_cycle_s(), 2.0, EPS, "Antes de entrar, el primer tramo")
	_stand_at(3)
	_step([t], 2)
	assert_true(t.is_started(), "Arranca al entrar")
	assert_almost_eq(t.get_cycle_s(), 2.0, EPS)
	_stand_at(12)
	_step([t], 2)
	assert_almost_eq(t.get_cycle_s(), 1.6, EPS, "Tramo 4b")
	_stand_at(25)
	_step([t], 2)
	assert_almost_eq(t.get_cycle_s(), 1.4, EPS, "Tramo 4c")
	_stand_at(3)
	_step([t], 60)
	assert_almost_eq(t.get_cycle_s(), 1.4, EPS, "Retroceder no lo hace mas lento")
	assert_eq(t.get_max_column(), 25)


func test_tunnel_has_no_loop_in_time() -> void:
	var t: AlarmTunnel = _tunnel()
	_stand_at(3)
	_step([t], roundi(20.0 / DT))
	assert_almost_eq(t.get_cycle_s(), 2.0, EPS, "El tiempo no lo acelera: solo la posicion")
	assert_gt(t.get_cycle_count(), 5)


func test_tunnel_restarts_on_respawn() -> void:
	var t: AlarmTunnel = _tunnel()
	_stand_at(25)
	_step([t], 30)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(t.get_max_column(), -1, "Vuelve al principio")
	assert_almost_eq(t.get_cycle_s(), 2.0, EPS)
	assert_false(t.is_started())


# --- Campana ---

func test_bell_warns_nine_frames_then_wave_hurts_once_and_pushes_back() -> void:
	var t: AlarmTunnel = _tunnel()
	var bell: AlarmBell = _bell(5)
	assert_almost_eq(bell.get_warn_s(), 0.75, EPS, "9 cuadros a 12 fps")
	assert_almost_eq(bell.wave_s, 0.4, EPS)
	var hits: Array = []
	bell.hit_player.connect(func(a: float) -> void: hits.append(a))
	_stand_at(5)
	_step([t, bell], 2)
	assert_true(bell.is_warning(), "Al empezar el ciclo avisa")
	var x0: float = _isak.global_position.x
	while bell.is_warning():
		assert_false(bell.is_dangerous())
		assert_eq(hits.size(), 0, "El aviso no dana")
		_step([t, bell])
	assert_true(bell.is_wave())
	_step([t, bell], 2)
	assert_eq(hits, [10.0], "La onda quita 10")
	_step([t, bell], 30)
	assert_eq(hits.size(), 1, "Una vez")
	assert_lt(_isak.global_position.x, x0, "Empuja hacia atras (push_direction -1)")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS)


func test_bell_wave_only_in_its_column() -> void:
	var t: AlarmTunnel = _tunnel()
	var bell: AlarmBell = _bell(5)
	var hits: Array = []
	bell.hit_player.connect(func(a: float) -> void: hits.append(a))
	_stand_at(7)
	_step([t, bell], roundi(2.0 / DT))
	assert_eq(bell.get_wave_count(), 1)
	assert_eq(hits.size(), 0, "A dos columnas no le alcanza")
	assert_almost_eq(bell.get_wave_rect().size.y, 3.0 * T, EPS, "Hasta el suelo")


func test_dash_passes_through_the_wave() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var t: AlarmTunnel = _tunnel()
	var bell: AlarmBell = _bell(5)
	var hits: Array = []
	bell.hit_player.connect(func(a: float) -> void: hits.append(a))
	_stand_at(3)
	_isak.facing = 1.0
	while not bell.is_wave():
		_step([t, bell])
	_sim.input.move_axis = 1.0
	_sim.input.dash_pressed = true
	_step([t, bell])
	_sim.input.dash_pressed = false
	assert_true(_isak.is_dashing())
	_step([t, bell], 12)
	_sim.input.move_axis = 0.0
	assert_gt(_isak.global_position.x, 6.0 * T, "Ha cruzado la columna de la onda")
	assert_eq(hits.size(), 0, "Invulnerable: sin dano")


func test_bell_follows_the_tunnel_with_its_offset() -> void:
	var t: AlarmTunnel = _tunnel()
	var a: AlarmBell = _bell(5, "tunel_test", 0.0)
	var b: AlarmBell = _bell(8, "tunel_test", 0.4)
	_stand_at(3)
	_step([t, a, b], 2)
	assert_true(a.is_warning())
	assert_eq(b.get_state(), AlarmBell.STATE_REST, "Desfasada 0,4 ciclos")
	_step([t, a, b], roundi(1.0 / DT))
	assert_true(b.is_warning() or b.is_wave(), "0,4 ciclos despues, la otra")
	_stand_at(25)
	_step([t, a, b], 2)
	assert_almost_eq(a.get_cycle_s(), 1.4, EPS, "Con el compas del tramo 4c")


func test_bell_without_rhythm_uses_its_interval_and_respawn_resets() -> void:
	var bell: AlarmBell = _bell(5, "")
	bell.interval_s = 2.0
	bell.reset_patrol()
	_stand_at(10)
	var waves: int = 0
	for i: int in roundi(4.05 / DT):
		_step([bell])
	waves = bell.get_wave_count()
	assert_eq(waves, 2, "Una onda cada 2 s")
	bell.reset_patrol()
	assert_almost_eq(bell.get_cycle_time(), 0.0, EPS)
	assert_eq(bell.get_wave_count(), 0)


func test_debug_slows_the_bell() -> void:
	var bell: AlarmBell = _bell(5, "")
	_stand_at(10)
	_step([bell], 30)
	var normal: float = bell.get_cycle_time()
	bell.reset_patrol()
	_activate_debug()
	_step([bell], 30)
	assert_almost_eq(bell.get_cycle_time() / normal, WorldTime.scale(), 0.03, "Tiempo del mundo")


func test_bell_is_indestructible() -> void:
	var bell: AlarmBell = _bell(5, "")
	assert_false(bell.has_method(&"on_laser_hit"), "El laser la atraviesa")
	assert_false(bell.has_method(&"receive_pulse"), "El pulso no le afecta")
	assert_true(bell.is_in_group(AlertBubble.GROUP), "Grupo enemy: LevelRunner la reinicia")
	assert_true(bell.is_help_available())


# --- Banner con ritmo ---

func test_banner_with_rhythm_uses_the_tunnel_cycle() -> void:
	var t: AlarmTunnel = _tunnel()
	var banner := BANNER_SCENE.instantiate() as SpamBanner
	banner.position = Vector2(20.5 * T, 0.0)
	_world.add_child(banner)
	banner.set_physics_process(false)
	banner.direction = -1
	banner.corridor_tiles = 6
	banner.rhythm = "tunel_test"
	banner.rhythm_offset = 0.25
	banner.target = _isak
	banner.reset_patrol()
	_stand_at(3)
	_step([t, banner], 30)
	assert_almost_eq(banner.get_interval_s(), 2.0, EPS, "El intervalo es el ciclo del metronomo")
	var expected: float = fposmod(t.get_beat_phase() - 0.25, 1.0) * t.get_cycle_s()
	assert_almost_eq(banner.get_cycle_time(), expected, EPS, "Su ciclo va con el compas (desfasado)")
	_stand_at(25)
	_step([t, banner], 2)
	assert_almost_eq(banner.get_interval_s(), 1.4, EPS, "Se acelera con el tunel")


func test_banner_without_rhythm_is_unchanged() -> void:
	var banner := BANNER_SCENE.instantiate() as SpamBanner
	_world.add_child(banner)
	assert_eq(banner.rhythm, "", "Por defecto sin ritmo (el 1-2 no cambia)")
	assert_almost_eq(banner.get_interval_s(), 3.0, EPS)
