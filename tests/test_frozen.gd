# Congelado (estado Frozen; paso 2 del plan de docs/propuesta-mundo-4.md §8, valores
# de §3.3 y decision 3 de §9): Isak queda quieto donde esta (tambien en el aire) con
# su velocidad guardada y al terminar sigue con ella; la cuenta va en tiempo del mundo
# (el Debug la alarga); Agitar la rompe al instante tambien en el aire (onda sin la
# anticipacion, 10 de energia); un golpe congelado resta pero no descongela;
# inmunidad de 0,5 s solo frente a otra zona «Visto»; morir y reaparecer lo cortan;
# sin pulso, laser, dash ni Pellizcar mientras dura. Isak avanza con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_frozen_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _started: Array = []
var _ended: Array = []
var _fired: Array = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_COMPRESS, GameState.ABILITY_SHOCKWAVE]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_started = []
	_ended = []
	_fired = []
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.frozen_started.connect(func(s: float, src: StringName) -> void: _started.append([s, src]))
	_isak.frozen_ended.connect(func(broken: bool) -> void: _ended.append(broken))
	_isak.shockwave_fired.connect(func(c: Vector2, r: float) -> void: _fired.append([c, r]))
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Debug activo")


func _shake() -> void:
	_sim.input.shake_pressed = true
	_sim.step()


## Sube hasta `steps` pasos tras saltar (en el aire, subiendo).
func _jump_and_rise(steps: int) -> void:
	_sim.press_jump()
	_sim.step(steps)
	assert_false(_isak.is_on_floor(), "En el aire")


# --- Datos ---

func test_data() -> void:
	assert_almost_eq(_isak.abilities.frozen_seen_immunity_s, 0.5, EPS, "Inmunidad 0,5 s")
	assert_eq(_isak.get_frozen_effect().get_segments(), 4, "Barra de 4 segmentos")
	assert_almost_eq(_isak.get_frozen_effect().get_veil_alpha(), 0.5, EPS, "Velo gris_oscuro al 50 %")


# --- Congelarse ---

func test_freeze_on_floor_holds_still_and_ends_on_time() -> void:
	var x: float = _isak.global_position.x
	assert_true(_isak.freeze(1.5, Isak.FREEZE_SOURCE_ZONE))
	assert_eq(_sim.state(), PlayerState.FROZEN)
	assert_eq(_started, [[1.5, Isak.FREEZE_SOURCE_ZONE]])
	assert_true(_isak.get_frozen_effect().is_showing(), "Velo, doble check y barra")
	assert_eq(_isak.get_frozen_effect().get_segments_left(), 4)
	_sim.input.move_axis = 1.0
	_sim.input.jump_pressed = true
	_sim.step(_sim.frames(0.8))
	assert_eq(_sim.state(), PlayerState.FROZEN, "Ni andar ni saltar lo sacan")
	assert_almost_eq(_isak.global_position.x, x, 0.5, "Quieto")
	assert_lt(_isak.get_frozen_effect().get_segments_left(), 4, "La barra se vacia")
	_sim.input.jump_pressed = false
	var steps: int = _sim.step_until(func() -> bool: return not _isak.is_frozen(), _sim.steps_for(1.5))
	assert_almost_eq((_sim.frames(0.8) + steps) * DT, 1.5, 0.05, "1,5 s")
	assert_eq(_ended, [false], "Se descongela solo")
	assert_false(_isak.get_frozen_effect().is_showing())
	assert_eq(_sim.state(), PlayerState.RUN, "Sigue con el control")


func test_freeze_in_the_air_keeps_velocity() -> void:
	_jump_and_rise(6)
	var pos: Vector2 = _isak.global_position
	var vel: Vector2 = _isak.velocity
	assert_lt(vel.y, 0.0, "Subiendo")
	assert_true(_isak.freeze(2.0, Isak.FREEZE_SOURCE_WAVE))
	_sim.step(_sim.frames(1.0))
	assert_true(_isak.is_frozen())
	assert_almost_eq(_isak.global_position.y, pos.y, 0.5, "Sin gravedad: quieto en el aire")
	assert_eq(_isak.get_frozen_velocity(), vel, "Velocidad guardada")
	_sim.step_until(func() -> bool: return not _isak.is_frozen(), _sim.steps_for(1.5))
	assert_lt(_isak.global_position.y, pos.y, "Sigue subiendo con la velocidad que llevaba")
	assert_eq(_sim.state(), PlayerState.FALL)


func test_freeze_counts_world_time_with_debug() -> void:
	_activate_debug()
	assert_lt(WorldTime.scale(), 1.0, "El Debug ralentiza el mundo")
	_isak.freeze(1.5)
	var steps: int = _sim.step_until(func() -> bool: return not _isak.is_frozen(), _sim.steps_for(6.0))
	assert_almost_eq(steps * DT, 1.5 / WorldTime.scale(), 0.06, "El Debug alarga la cuenta, no la rompe")


func test_refused_cases() -> void:
	assert_false(_isak.freeze(0.0), "Sin duracion")
	_isak.begin_warp(true)
	assert_false(_isak.freeze(1.5), "En un vortice")
	_isak.end_warp()
	_isak.die()
	assert_false(_isak.freeze(1.5), "Muerto")
	assert_eq(_started, [])


func test_already_frozen_only_extends() -> void:
	_isak.freeze(1.5, Isak.FREEZE_SOURCE_ZONE)
	_sim.step(_sim.frames(1.0))
	assert_false(_isak.freeze(2.5, Isak.FREEZE_SOURCE_BOSS), "No es una congelacion nueva")
	assert_almost_eq(_isak.get_frozen_left(), 2.5, EPS, "Alarga la cuenta")
	assert_false(_isak.freeze(0.5), "Mas corta no cambia nada")
	assert_almost_eq(_isak.get_frozen_left(), 2.5, EPS)
	assert_eq(_started.size(), 1)


# --- Agitar libera ---

func test_shake_breaks_freeze_on_floor() -> void:
	_isak.freeze(1.5)
	_sim.step(3)
	_shake()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE, "Agitar rompe la congelacion")
	assert_eq(_fired.size(), 1, "La onda sale al instante (sin la anticipacion)")
	assert_eq(_ended, [true], "Rota por Agitar")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max() - 10.0, EPS, "10 de energia")
	assert_eq(_isak.get_shockwave_phase(), ShockwaveState.Phase.EXPOSED, "Sigue la exposicion")
	_sim.step_until(func() -> bool: return not _isak.is_shockwaving(), _sim.steps_for(1.0))
	assert_eq(_sim.state(), PlayerState.IDLE)


func test_shake_breaks_freeze_in_the_air() -> void:
	_jump_and_rise(6)
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "En el aire sin congelar, no")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_AIR)
	_isak.freeze(2.0, Isak.FREEZE_SOURCE_WAVE)
	assert_eq(_isak.shockwave_denial(), &"", "Congelado sale tambien en el aire")
	_shake()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE)
	assert_eq(_fired.size(), 1)
	assert_eq(_ended, [true])
	_sim.step_until(func() -> bool: return _isak.is_on_floor() and not _isak.is_shockwaving(), _sim.steps_for(3.0))
	assert_true(_isak.is_on_floor(), "Cae despues")


func test_shake_without_energy_keeps_frozen() -> void:
	GameState.debug_energy = 5.0
	_isak.freeze(1.5)
	_shake()
	assert_true(_isak.is_frozen(), "Sin energia no libera")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_ENERGY)
	assert_eq(_fired.size(), 0)


func test_shake_locked_keeps_frozen() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, false)
	_isak.freeze(1.5)
	_shake()
	assert_true(_isak.is_frozen(), "Sin Agitar (4-1) se espera")


# --- Dano, inmunidad, muerte ---

func test_hit_while_frozen_counts_but_keeps_frozen() -> void:
	_isak.freeze(1.5)
	assert_true(_isak.take_hit(1.0), "Congelado si se recibe dano")
	assert_true(_isak.is_frozen(), "No descongela")
	assert_true(_isak.is_invulnerable(), "Invulnerabilidad del golpe")
	assert_eq(_isak.velocity, Vector2.ZERO, "Sin retroceso")


func test_seen_immunity_only_against_zones() -> void:
	_isak.freeze(0.5)
	_sim.step_until(func() -> bool: return not _isak.is_frozen(), _sim.steps_for(1.0))
	assert_almost_eq(_isak.get_seen_immunity_left(), 0.5, 0.02)
	assert_false(_isak.freeze(1.5, Isak.FREEZE_SOURCE_ZONE), "Otra zona no lo congela en 0,5 s")
	_sim.step(_sim.frames(0.55))
	assert_true(_isak.freeze(1.5, Isak.FREEZE_SOURCE_ZONE), "Despues si")
	_shake()
	assert_false(_isak.is_frozen())
	assert_true(_isak.get_seen_immunity_left() > 0.0, "Tambien tras romperla con Agitar")
	assert_true(_isak.freeze(2.0, Isak.FREEZE_SOURCE_WAVE), "La ola no respeta la inmunidad")


func test_death_and_respawn_clear_freeze() -> void:
	_isak.freeze(1.5)
	_isak.die()
	assert_eq(_sim.state(), PlayerState.DEAD, "Morir congelado")
	assert_false(_isak.get_frozen_effect().is_showing())
	_isak.respawn(Vector2(0.0, 0.0))
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_eq(_isak.velocity, Vector2.ZERO)
	assert_almost_eq(_isak.get_seen_immunity_left(), 0.0, EPS)
	_isak.freeze(1.5)
	_isak.respawn(Vector2(0.0, 0.0))
	assert_false(_isak.is_frozen(), "Reaparecer descongela")
	assert_eq(_isak.velocity, Vector2.ZERO)


func test_no_actions_while_frozen() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, true)
	_isak.freeze(1.5)
	assert_false(_isak.can_pulse(), "Sin pulso")
	assert_false(_isak.can_start_laser(), "Sin laser")
	assert_eq(_isak.dash_denial(), Isak.DASH_DENIED_BUSY, "Sin dash")
	assert_eq(_isak.compress_denial(), Isak.COMPRESS_DENIED_BUSY, "Sin Pellizcar")
	_sim.input.pulse_pressed = true
	_sim.input.laser_pressed = true
	_sim.input.dash_pressed = true
	_sim.step()
	assert_true(_isak.is_frozen())
	assert_false(_isak.is_laser_charging())


func test_vortex_cuts_freeze() -> void:
	_isak.freeze(1.5)
	_isak.begin_warp(false)
	_sim.step()
	assert_false(_isak.is_frozen(), "Un vortice lo corta")
	_isak.end_warp()
