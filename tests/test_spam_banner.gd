# Pruebas del banner de spam (scripts/enemies/spam_banner.gd, paso 5 de
# docs/propuesta-1-2.md §10): ciclo reposo -> aviso (6-12 cuadros) -> barrido a
# intervalos fijos, el aviso no dana, el barrido quita 10 de Sync Rate una vez
# (invulnerabilidad de Isak) y se salta por encima, direccion, desfase, vuelta
# al estado inicial al reaparecer, el laser lo atraviesa, y el Debug lo
# ralentiza a x0,5 (tiempo del mundo). Desde el 2026-10-19 (paso 4 de
# docs/propuesta-1-3.md §7): el dash lo atraviesa sin dano (invulnerable) y,
# con knockback_to_entry, el golpe devuelve a Isak a la entrada del pasillo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BANNER_SCENE: PackedScene = preload("res://scenes/enemies/spam_banner.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const FAR: Vector2 = Vector2(-3000.0, 0.0)
## Entrada del pasillo (pies de la celda E).
const ENTRY: Vector2 = Vector2(96.0, 0.0)

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"laser": GameState.is_ability_unlocked(GameState.ABILITY_LASER),
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"energy": GameState.debug_energy,
		"dash": GameState.is_ability_unlocked(GameState.ABILITY_DASH),
	}
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = FAR
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved.laser)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, _saved.dash)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _banner(dir: int = 1, entry: Vector2 = ENTRY) -> SpamBanner:
	var b := BANNER_SCENE.instantiate() as SpamBanner
	b.position = entry
	_world.add_child(b)
	b.set_physics_process(false)
	b.direction = dir
	b.target = _isak
	b.reset_patrol()
	return b


func _step(banners: Array, count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for b: SpamBanner in banners:
			b.step(DT)


## Pasos (de DT) hasta el estado `state`, o -1.
func _steps_until(b: SpamBanner, state: StringName, max_steps: int = 1200) -> int:
	for i: int in max_steps:
		if b.get_state() == state:
			return i
		_step([b])
	return -1


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())


func test_data_and_cycle_lengths() -> void:
	var b: SpamBanner = _banner()
	assert_true(b.is_in_group(SpamBanner.GROUP), "Grupo enemy: LevelRunner lo reinicia")
	assert_between(b.anticipation_frames, 6, 12, "Aviso de 6-12 cuadros antes de danar")
	assert_almost_eq(b.get_warn_s(), 0.75, EPS, "9 cuadros a 12 fps")
	assert_almost_eq(b.get_sweep_s(), (12.0 * 64.0 - 128.0) / 640.0, EPS, "Recorre el pasillo a 640 px/s")
	assert_almost_eq(b.get_interval_s(), 3.0, EPS, "Cada 3 s")
	assert_gt(b.get_rest_s(), 0.0, "Deja reposo")
	assert_eq(b.get_state(), SpamBanner.STATE_REST, "Empieza en reposo")
	assert_true(b.is_help_available(), "Un banner siempre ayuda (no se destruye)")


func test_cycle_rest_warn_sweep_at_fixed_intervals() -> void:
	var b: SpamBanner = _banner()
	var to_warn: int = _steps_until(b, SpamBanner.STATE_WARN)
	assert_almost_eq(to_warn * DT, b.get_rest_s(), DT * 1.5, "Reposo")
	assert_eq(b.get_state(), SpamBanner.STATE_WARN)
	var to_sweep: int = _steps_until(b, SpamBanner.STATE_SWEEP)
	assert_almost_eq(to_sweep * DT, b.get_warn_s(), DT * 1.5, "Aviso de 0,75 s")
	var x0: float = b.get_banner_center_x()
	var to_rest: int = _steps_until(b, SpamBanner.STATE_REST)
	assert_almost_eq(to_rest * DT, b.get_sweep_s(), DT * 1.5, "Barrido")
	var next_warn: int = _steps_until(b, SpamBanner.STATE_WARN)
	assert_almost_eq((to_sweep + to_rest + next_warn) * DT, b.get_interval_s(), DT * 2.0, "Intervalo fijo")
	assert_gt(x0, ENTRY.x - 32.0, "Sale de la entrada")


func test_warning_is_harmless_and_sweep_hurts_once() -> void:
	var b: SpamBanner = _banner()
	_isak.global_position = ENTRY + Vector2(64.0 * 6.0, 0.0)
	_sim.settle()
	var hits: Array = []
	b.hit_player.connect(func(a: float) -> void: hits.append(a))
	_steps_until(b, SpamBanner.STATE_WARN)
	while b.is_warning():
		assert_false(b.is_dangerous())
		_step([b])
	assert_eq(hits.size(), 0, "El aviso no dana")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)
	_steps_until(b, SpamBanner.STATE_REST)
	assert_eq(hits, [10.0], "El barrido quita 10 una vez")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS, "No mata de golpe")


func test_jumping_over_the_banner_avoids_it() -> void:
	var b: SpamBanner = _banner()
	var hits: Array = []
	b.hit_player.connect(func(a: float) -> void: hits.append(a))
	_steps_until(b, SpamBanner.STATE_SWEEP)
	# Isak en el aire por encima de la zona de dano mientras pasa.
	_isak.global_position = ENTRY + Vector2(64.0 * 6.0, -(b.damage_size.y + b.damage_bottom_px) - 4.0)
	while b.is_sweeping():
		_isak.global_position.y = ENTRY.y - (b.damage_size.y + b.damage_bottom_px) - 4.0
		_isak.velocity = Vector2.ZERO
		b.step(DT)
	assert_eq(hits.size(), 0, "Saltando por encima no dana")


func test_direction_left_sweeps_from_the_entry_to_the_left() -> void:
	var b: SpamBanner = _banner(-1, Vector2(1200.0, 0.0))
	_steps_until(b, SpamBanner.STATE_SWEEP)
	var x0: float = b.get_banner_center_x()
	_step([b], 20)
	assert_lt(b.get_banner_center_x(), x0, "Va a la izquierda")
	assert_lt(b.get_banner_center_x(), 1200.0 + 32.0, "Desde la entrada")
	var corridor: Rect2 = b.get_corridor_rect()
	assert_almost_eq(corridor.end.x, 1200.0 + 32.0, EPS, "El pasillo empieza en la celda E")


func test_phase_offsets_the_cycle_and_respawn_resets_it() -> void:
	var a: SpamBanner = _banner()
	var b: SpamBanner = _banner(1, ENTRY + Vector2(0.0, -400.0))
	b.phase_s = 1.5
	assert_almost_eq(b.get_cycle_time(), 1.5, EPS, "Desfasado")
	_step([a, b], 90)
	a.reset_patrol()
	assert_almost_eq(a.get_cycle_time(), 0.0, EPS, "Vuelve al inicio del ciclo")
	assert_eq(a.get_state(), SpamBanner.STATE_REST)
	b.reset_patrol()
	assert_almost_eq(b.get_cycle_time(), 1.5, EPS, "Con su desfase")


func test_laser_passes_through_and_pulse_does_nothing() -> void:
	var b: SpamBanner = _banner()
	assert_false(b.has_method(&"on_laser_hit"), "Indestructible: el laser no le hace nada")
	assert_false(b.has_method(&"receive_pulse"), "El pulso no le afecta")
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	_isak.global_position = ENTRY + Vector2(-64.0, 0.0)
	_sim.settle()
	_steps_until(b, SpamBanner.STATE_SWEEP)
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	_sim.input.laser_pressed = false
	for i: int in 30:
		if not fired.is_empty():
			break
		_sim.step()
	assert_eq(fired.size(), 1)
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in 120:
		if p.is_finished():
			break
		p.step(DT)
	assert_null(p.get_hit_target(), "Lo atraviesa (llega a su alcance sin chocar)")
	assert_gt(p.get_traveled(), b.get_banner_center_x() - _isak.global_position.x, "Paso por donde estaba el banner")


func test_debug_slows_the_sweep_by_half() -> void:
	var b: SpamBanner = _banner()
	_steps_until(b, SpamBanner.STATE_SWEEP)
	var x0: float = b.get_banner_center_x()
	_step([b], 15)
	var normal: float = b.get_banner_center_x() - x0
	b.reset_patrol()
	_activate_debug()
	_steps_until(b, SpamBanner.STATE_SWEEP)
	x0 = b.get_banner_center_x()
	_step([b], 15)
	var slowed: float = b.get_banner_center_x() - x0
	assert_almost_eq(slowed / normal, 0.5, 0.05, "Con el Debug barre a x0,5")


# --- Dash y banner obligatorio (paso 4 de docs/propuesta-1-3.md §7) ---

## Banner hacia la izquierda (hacia Isak), como el obligatorio del 1-3.
func _dash_banner(knockback: bool) -> SpamBanner:
	var b: SpamBanner = _banner(-1, Vector2(1200.0, 0.0))
	b.sweep_speed_px_s = 320.0
	b.knockback_to_entry = knockback
	b.reset_patrol()
	return b


func test_knockback_to_entry_defaults_off() -> void:
	var b: SpamBanner = _banner()
	assert_false(b.knockback_to_entry, "Por defecto el golpe no devuelve a la entrada (el 1-2 no cambia)")
	var d: SpamBanner = _dash_banner(true)
	assert_almost_eq(d.get_return_position().x, 1200.0 - 12.0 * 64.0, EPS,
		"La entrada por el lado de Isak: la celda siguiente al final del barrido")
	assert_almost_eq(d.get_return_position().y, 0.0, EPS, "A la altura de los pies de la E")


func test_dash_through_sweeping_banner_takes_no_hit() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var b: SpamBanner = _dash_banner(true)
	var hits: Array = []
	b.hit_player.connect(func(a: float) -> void: hits.append(a))
	_isak.global_position = Vector2(1200.0 - 64.0 * 9.0, 0.0)
	_isak.facing = 1.0
	_sim.settle()
	_steps_until(b, SpamBanner.STATE_SWEEP)
	# Espera a que el banner este a un tile de Isak y se desliza a traves.
	for i: int in 600:
		if b.get_damage_rect().position.x - _isak.global_position.x < 80.0:
			break
		_step([b])
	var x0: float = _isak.global_position.x
	_sim.input.move_axis = 1.0
	_sim.input.dash_pressed = true
	_step([b])
	_sim.input.dash_pressed = false
	assert_true(_isak.is_dashing(), "Sale el dash")
	_sim.input.move_axis = 0.0
	_step([b], _sim.frames(0.6))
	assert_eq(hits.size(), 0, "Invulnerable durante el dash: sin golpe")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, EPS, "Sin dano")
	assert_gt(_isak.global_position.x, x0 + 150.0, "Lo ha atravesado (no ha vuelto a la entrada)")
	assert_gt(_isak.global_position.x, b.get_banner_center_x(), "Queda detras del banner")


func test_knockback_to_entry_sends_isak_back_to_the_entry() -> void:
	var b: SpamBanner = _dash_banner(true)
	var hits: Array = []
	b.hit_player.connect(func(a: float) -> void: hits.append(a))
	# Isak a mitad del pasillo, andando hacia la salida (hacia el banner).
	_isak.global_position = Vector2(1200.0 - 64.0 * 6.0, 0.0)
	_sim.settle()
	_steps_until(b, SpamBanner.STATE_SWEEP)
	for i: int in 600:
		if not hits.is_empty():
			break
		_step([b])
	assert_eq(hits, [10.0], "El barrido le alcanza: -10")
	assert_almost_eq(_isak.global_position.x, b.get_return_position().x, 1.0, "Vuelve a la entrada del pasillo")
	assert_eq(_sim.state(), PlayerState.HURT, "Con el retroceso normal desde alli")
	_step([b], _sim.frames(0.3))
	assert_lt(_isak.global_position.x, b.get_return_position().x + 1.0,
		"El retroceso lo aleja del pasillo (hacia donde va el banner)")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS)


func test_without_knockback_to_entry_the_hit_stays_in_place() -> void:
	var b: SpamBanner = _dash_banner(false)
	var hits: Array = []
	b.hit_player.connect(func(a: float) -> void: hits.append(a))
	var at: float = 1200.0 - 64.0 * 6.0
	_isak.global_position = Vector2(at, 0.0)
	_sim.settle()
	_steps_until(b, SpamBanner.STATE_SWEEP)
	for i: int in 600:
		if not hits.is_empty():
			break
		_step([b])
	assert_eq(hits.size(), 1)
	assert_almost_eq(_isak.global_position.x, at, 64.0, "Sin knockback_to_entry no se teletransporta")
