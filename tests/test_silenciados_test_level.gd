# Sala de prueba «Silenciados» (data/levels/silenciados_test.json, escena
# generada scenes/levels/silenciados_test.tscn; paso 4 de docs/propuesta-1-3.md
# §7, 2026-10-19) con el Isak real: la escena trae el banner obligatorio
# (knockback_to_entry, 320 px/s, help_id propio spam_banner_dash) y el del
# nicho con sus params; andando por el pasillo obligatorio el barrido alcanza
# a Isak y lo devuelve a la entrada (columna 5); con el dash se atraviesa sin
# dano; en el nicho del 1b no le alcanza; se reinician al reaparecer.
# Los banners se avanzan a mano junto a Isak (paso a paso).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/silenciados_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
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
	_enemies.clear()
	for e: Node in _level.get_node(^"Enemies").get_children():
		e.set_physics_process(false)
		_enemies.append(e)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _banner(id: String) -> SpamBanner:
	return _level.get_node_or_null(NodePath("Enemies/" + id)) as SpamBanner


func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for e: Node in _enemies:
			if is_instance_valid(e):
				e.call(&"step", DT)


func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


func _col() -> int:
	return floori(_isak.global_position.x / TILE)


func test_scene_has_the_banners_with_level_params() -> void:
	assert_eq(_level.level_id, "silenciados_test")
	var dash := _banner("banner_dash")
	var b1 := _banner("banner_1b")
	assert_not_null(dash)
	assert_not_null(b1)
	assert_true(dash.knockback_to_entry, "params.knockback_to_entry")
	assert_eq(dash.direction, -1, "Barre hacia Isak")
	assert_almost_eq(dash.sweep_speed_px_s, 320.0, 0.001, "Despacio")
	assert_eq(dash.corridor_tiles, 12)
	assert_almost_eq(dash.get_return_position().x, 5.5 * TILE, 0.001, "Vuelta: la columna 5")
	assert_false(b1.knockback_to_entry, "El del nicho, el banner normal")
	assert_eq(HelpCatalog.help_id_of(dash), &"spam_banner_dash", "Ayuda propia del banner obligatorio")
	assert_eq(HelpCatalog.help_id_of(b1), &"spam_banner")
	assert_true(HelpCatalog.shared().has(&"spam_banner_dash"))
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DASH), "La sala da el dash")


func test_walking_the_mandatory_corridor_sends_isak_back_to_the_entry() -> void:
	var dash := _banner("banner_dash")
	var hits: Array = []
	dash.hit_player.connect(func(a: float) -> void: hits.append(a))
	await _stand(6, 10)
	_sim.input.run_held = true
	_sim.input.move_axis = 1.0
	for i: int in roundi(6.0 / DT):
		_step()
		if not hits.is_empty() or _col() >= 18:
			break
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	assert_eq(hits, [10.0], "Corriendo, el barrido lo alcanza antes de salir")
	assert_lt(_col(), 6, "Vuelve a la entrada del pasillo (columna 5)")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, 0.001)
	_step(roundi(1.0 / DT))
	assert_lt(_col(), 6, "El retroceso lo deja fuera del pasillo")


func test_dash_through_the_mandatory_banner_without_damage() -> void:
	var dash := _banner("banner_dash")
	var hits: Array = []
	dash.hit_player.connect(func(a: float) -> void: hits.append(a))
	await _stand(5, 10)
	_isak.facing = 1.0
	# Desde la entrada: espera a que empiece un barrido, corre hacia el banner y,
	# cuando esta a un tile, se desliza a traves.
	for i: int in roundi(6.0 / DT):
		_step()
		if dash.get_state() == SpamBanner.STATE_WARN:
			break
	for i: int in roundi(2.0 / DT):
		_step()
		if dash.is_sweeping():
			break
	assert_true(dash.is_sweeping())
	_sim.input.run_held = true
	_sim.input.move_axis = 1.0
	for i: int in roundi(3.0 / DT):
		_step()
		if dash.get_damage_rect().position.x - _isak.global_position.x < 80.0:
			break
	assert_eq(hits.size(), 0, "Todavia no le ha alcanzado")
	var energy0: float = GameState.debug_energy
	_sim.input.dash_pressed = true
	_step()
	_sim.input.dash_pressed = false
	assert_true(_isak.is_dashing(), "Sale el dash")
	assert_almost_eq(GameState.debug_energy, energy0 - _isak.abilities.dash_energy_cost, 0.001, "10 de energia")
	for i: int in roundi(4.0 / DT):
		_step()
		if _col() >= 19:
			break
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	assert_eq(hits.size(), 0, "Invulnerable durante el dash: cruza sin golpe")
	assert_gte(_col(), 18, "Ha salido del pasillo obligatorio")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)


func test_niche_of_the_second_corridor_is_safe() -> void:
	var b1 := _banner("banner_1b")
	var hits: Array = []
	b1.hit_player.connect(func(a: float) -> void: hits.append(a))
	await _stand(27, 8)
	for i: int in roundi(6.5 / DT):
		_step()
	assert_eq(hits.size(), 0, "En el nicho de una via no le alcanza")
	await _stand(29, 10)
	for i: int in roundi(3.5 / DT):
		_step()
		_isak.velocity.x = 0.0
	assert_eq(hits, [10.0], "De pie en el pasillo, si")


func test_banners_reset_when_isak_respawns() -> void:
	var dash := _banner("banner_dash")
	_step(90)
	assert_gt(dash.get_cycle_time(), 1.0)
	# LevelRunner._respawn llama a reset_patrol de los del grupo enemy.
	assert_true(dash.is_in_group(AlertBubble.GROUP))
	for e: Node in _enemies:
		e.call(&"reset_patrol")
	assert_almost_eq(dash.get_cycle_time(), 0.0, 0.001, "Vuelve al inicio del ciclo")
	assert_eq(dash.get_state(), SpamBanner.STATE_REST)
