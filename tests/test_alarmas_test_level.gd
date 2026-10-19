# Sala de prueba «Alarmas» (data/levels/alarmas_test.json, escena generada
# scenes/levels/alarmas_test.tscn; paso 6 de docs/propuesta-1-3.md §7,
# 2026-10-19) con el Isak real: la escena trae el tunel con sus tres tramos,
# seis campanas y dos banners con rhythm; el compas se acelera al avanzar
# Isak (2,0 -> 1,6 -> 1,4 s) y no retrocede; las campanas y los banners lo
# siguen; una campana golpea de pie en su columna y el dash la atraviesa; al
# reaparecer el tunel vuelve al principio.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/alarmas_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _tunnel: AlarmTunnel
var _enemies: Array[Node] = []
var _saved_pause: bool


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_tunnel = _level.get_node(^"Objects/tunel_alarmas") as AlarmTunnel
	_tunnel.set_physics_process(false)
	_enemies.clear()
	for e: Node in _level.get_node(^"Enemies").get_children():
		e.set_physics_process(false)
		_enemies.append(e)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	EcoTextBox.pause_important = _saved_pause
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _step(count: int = 1) -> void:
	for i: int in count:
		_tunnel.step(DT)
		for e: Node in _enemies:
			e.call(&"step", DT)
		_sim.step()


func _stand(col: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, 11.0 * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()


func _enemy(id: String) -> Node:
	return _level.get_node(NodePath("Enemies/" + id))


func test_scene_has_the_tunnel_bells_and_rhythm_banners() -> void:
	assert_eq(_level.level_id, "alarmas_test")
	assert_eq(_tunnel.stages.size(), 3)
	assert_eq(_tunnel.zone, [6, 7, 27, 4])
	var bells: int = 0
	for e: Node in _enemies:
		if e is AlarmBell:
			bells += 1
			assert_eq((e as AlarmBell).get_rhythm(), _tunnel, "%s sigue al tunel" % e.name)
	assert_eq(bells, 6)
	assert_eq((_enemy("bell_4b_2") as AlarmBell).wave_tiles, 2)
	assert_almost_eq((_enemy("bell_4a_2") as AlarmBell).offset, 0.5, EPS)
	var banner := _enemy("banner_4c") as SpamBanner
	assert_eq(banner.rhythm, "tunel_alarmas")
	assert_almost_eq(banner.rhythm_offset, 0.25, EPS)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DASH))


func test_tunnel_accelerates_as_isak_advances() -> void:
	await _stand(8)
	_step(2)
	assert_almost_eq(_tunnel.get_cycle_s(), 2.0, EPS, "4a")
	var banner := _enemy("banner_4a") as SpamBanner
	assert_almost_eq(banner.get_interval_s(), 2.0, EPS, "El banner con el mismo compas")
	await _stand(16)
	_step(2)
	assert_almost_eq(_tunnel.get_cycle_s(), 1.6, EPS, "4b")
	await _stand(27)
	_step(2)
	assert_almost_eq(_tunnel.get_cycle_s(), 1.4, EPS, "4c")
	assert_almost_eq(banner.get_interval_s(), 1.4, EPS)
	await _stand(8)
	_step(30)
	assert_almost_eq(_tunnel.get_cycle_s(), 1.4, EPS, "Retroceder no lo frena")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_almost_eq(_tunnel.get_cycle_s(), 2.0, EPS, "Al reaparecer, vuelve al principio")


func test_bell_hits_in_its_column_and_dash_passes() -> void:
	var bell := _enemy("bell_4c_1") as AlarmBell
	var hits: Array = []
	bell.hit_player.connect(func(a: float) -> void: hits.append(a))
	await _stand(26)
	for i: int in roundi(3.0 / DT):
		_step()
		_isak.velocity.x = 0.0
		if not hits.is_empty():
			break
	assert_eq(hits, [10.0], "De pie bajo la campana, la onda le alcanza")
	# Con el dash, a traves de la onda de la siguiente (sin el banner del 4c, que tambien golpearia).
	_enemies.erase(_enemy("banner_4c"))
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	var bell2 := _enemy("bell_4c_2") as AlarmBell
	var hits2: Array = []
	bell2.hit_player.connect(func(a: float) -> void: hits2.append(a))
	await _stand(28)
	_step(roundi(1.2 / DT))
	_isak.facing = 1.0
	for i: int in roundi(3.0 / DT):
		_step()
		if bell2.is_wave():
			break
	assert_true(bell2.is_wave())
	_sim.input.move_axis = 1.0
	_sim.input.dash_pressed = true
	_step()
	_sim.input.dash_pressed = false
	assert_true(_isak.is_dashing())
	_step(12)
	_sim.input.move_axis = 0.0
	assert_gt(_isak.global_position.x, 31.0 * TILE, "Cruza la columna 30 bajo el techo bajo")
	assert_eq(hits2.size(), 0, "Invulnerable durante el dash")
