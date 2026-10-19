# Sala de prueba «Vibracion» (data/levels/vibracion_test.json, escena generada
# scenes/levels/vibracion_test.tscn; paso 5 de docs/propuesta-1-3.md §7,
# 2026-10-19) con el Isak real: la escena trae el metronomo y las cinco
# plataformas con los params del nivel; el compas arranca al entrar Isak en la
# zona; los grupos A y B del foso se alternan; la ola de tres grupos va en
# orden; con el Debug el compas se ralentiza; al reaparecer vuelve al principio.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/vibracion_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _rhythm: RhythmZone
var _platforms: Array[BlinkPlatform] = []
var _saved_pause: bool


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.debug_energy = GameState.get_debug_energy_max()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_rhythm = _level.get_node(^"Objects/ritmo_v") as RhythmZone
	_rhythm.set_physics_process(false)
	_platforms.clear()
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is BlinkPlatform:
			node.set_physics_process(false)
			_platforms.append(node as BlinkPlatform)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	EcoTextBox.pause_important = _saved_pause
	GameState.reset_progress()


func _blink(id: String) -> BlinkPlatform:
	return _level.get_node(NodePath("Objects/" + id)) as BlinkPlatform


func _step(count: int = 1) -> void:
	for i: int in count:
		_rhythm.step(DT)
		for p: BlinkPlatform in _platforms:
			p.refresh()
		_sim.step()


func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()


func test_scene_has_the_rhythm_and_the_platforms() -> void:
	assert_eq(_level.level_id, "vibracion_test")
	assert_eq(_rhythm.object_id, &"ritmo_v")
	assert_eq(_rhythm.tempo_steps_s, [3.2, 2.6, 2.0], "Lista de ciclos (no un Vector2)")
	assert_eq(_rhythm.cycles_per_step, 4)
	assert_true(_rhythm.loop)
	assert_eq(_rhythm.start_mode, RhythmZone.START_ON_ENTER)
	assert_eq(_platforms.size(), 5)
	for p: BlinkPlatform in _platforms:
		assert_eq(p.get_rhythm(), _rhythm, "%s sigue a ritmo_v" % p.name)
	assert_almost_eq(_blink("blink_2a_b").offset, 0.5, 0.001)
	assert_almost_eq(_blink("blink_2a_a").on_fraction, 0.6, 0.001)
	assert_eq(_blink("blink_2b_c").group_id, &"C")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "La sala da el Debug")


func test_rhythm_starts_when_isak_enters_the_zone() -> void:
	await _stand(2, 9)
	_step(60)
	assert_false(_rhythm.is_started(), "En la entrada (columna 2) aun no")
	await _stand(7, 9)
	_step(30)
	assert_true(_rhythm.is_started(), "Dentro de la zona arranca")


func test_pit_groups_alternate_and_wave_goes_in_order() -> void:
	await _stand(7, 9)
	var a := _blink("blink_2a_a")
	var b := _blink("blink_2a_b")
	_step(2)
	assert_true(a.is_solid() and b.is_solid(), "Al principio del ciclo se solapan (60 % cada una)")
	_step(roundi(0.5 / DT))
	assert_true(a.is_solid())
	assert_false(b.is_solid(), "Despues, solo A")
	_step(roundi(1.5 / DT))
	assert_false(a.is_solid(), "A apagada pasado el 60 % del ciclo")
	assert_true(b.is_solid(), "B encendida")
	# Ola de tres grupos: cada uno encendido medio ciclo, un tercio de ciclo despues del anterior.
	_rhythm.reset()
	_step(1)
	var wave: Array[BlinkPlatform] = [_blink("blink_2b_a"), _blink("blink_2b_b"), _blink("blink_2b_c")]
	var expected: Dictionary = {0.1: [true, false, true], 0.4: [true, true, false], 0.55: [false, true, false],
		0.75: [false, true, true], 0.9: [false, false, true]}
	var cycle: float = _rhythm.get_cycle_s()
	for phase: float in [0.1, 0.4, 0.55, 0.75, 0.9]:
		_rhythm.advance(phase * cycle - _rhythm.get_cycle_time())
		var got: Array = []
		for p: BlinkPlatform in wave:
			p.refresh()
			got.append(p.is_solid())
		assert_eq(got, expected[phase], "Ola A -> B -> C en la fase %.2f" % phase)


func test_debug_slows_the_room_rhythm() -> void:
	await _stand(7, 9)
	_step(60)
	var normal: float = _rhythm.get_cycle_time()
	_rhythm.reset()
	_step(1)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())
	var t0: float = _rhythm.get_cycle_time()
	_step(60)
	assert_almost_eq((_rhythm.get_cycle_time() - t0) / normal, WorldTime.scale(), 0.03,
		"Con el Debug, en tiempo del mundo")


func test_respawn_restarts_the_rhythm() -> void:
	await _stand(7, 9)
	_step(roundi(5.0 / DT))
	assert_gt(_rhythm.get_cycle_count(), 0)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(_rhythm.get_cycle_count(), 0)
	assert_false(_rhythm.is_started(), "Espera a que Isak vuelva a entrar")
