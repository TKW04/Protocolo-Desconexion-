# Pulso 5 «Pulso de retorno» (tanda M2 de docs/propuesta-mejoras.md §2,
# 2026-10-17): aturdir a un enemigo con el pulso da +4 de energia, UNA vez por
# enemigo y por intento de nivel (GameState.begin_attempt, que llama
# LevelRunner.start_level); no desborda a los power banks; «+4» (UpgradeFx
# energy_return) sobre el enemigo. Sin la mejora no da nada.
extends GutTest

const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const BADGE_SCENE: PackedScene = preload("res://scenes/enemies/notification_badge.tscn")
const PATH: String = "user://test_pulse_return_save.json"
const EPS: float = 0.001

var _saved_path: String
var _area: Area2D
var _world: Node2D


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.debug_energy = 50.0
	_world = Node2D.new()
	add_child_autofree(_world)
	_area = Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4000.0
	shape.shape = circle
	_area.add_child(shape)
	_world.add_child(_area)


func after_each() -> void:
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _bubble(x: float) -> AlertBubble:
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.name = "Burbuja%d" % roundi(x)
	b.position = Vector2(x, 0.0)
	_world.add_child(b)
	b.set_physics_process(false)
	return b


func _fx_count() -> int:
	var count: int = 0
	for node: Node in _world.get_children():
		if node is UpgradeFx and (node as UpgradeFx).kind == UpgradeFx.ENERGY_RETURN:
			count += 1
	return count


func test_values() -> void:
	assert_almost_eq(PlayerAbilities.load_from_file().pulse_energy_on_stun, 0.0, EPS, "Base: nada")
	var target := &"isak_abilities.pulse_energy_on_stun"
	GameState.upgrade_levels[&"pulso"] = 4
	assert_almost_eq(GameState.effective_value(target, 0.0), 0.0, EPS)
	GameState.upgrade_levels[&"pulso"] = 5
	assert_almost_eq(GameState.effective_value(target, 0.0), 4.0, EPS, "Pulso 5: +4")
	assert_almost_eq(GameState.get_pulse_stun_multiplier(), 1.5, EPS, "Conserva el aturdimiento del Pulso 3")


func test_without_upgrade_no_energy() -> void:
	var b: AlertBubble = _bubble(0.0)
	assert_true(b.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, 50.0, EPS)
	assert_eq(_fx_count(), 0)


func test_once_per_enemy_and_attempt() -> void:
	GameState.upgrade_levels[&"pulso"] = 5
	var a: AlertBubble = _bubble(0.0)
	var b: AlertBubble = _bubble(200.0)
	watch_signals(EventBus)
	assert_true(a.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, 54.0, EPS, "+4 al aturdir")
	assert_eq(_fx_count(), 1, "Sale «+4»")
	assert_signal_emitted(EventBus, "pulse_energy_returned")
	assert_true(GameState.is_pulse_return_claimed(a))
	# Volver a aturdirla (sigue viva) no da mas: no es infinito.
	a.reset_patrol()
	assert_true(a.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, 54.0, EPS, "Una sola vez por enemigo")
	# Otro enemigo si.
	assert_true(b.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, 58.0, EPS)
	# Intento nuevo (LevelRunner.start_level): vuelve a dar.
	GameState.begin_attempt()
	assert_false(GameState.is_pulse_return_claimed(a))
	a.reset_patrol()
	assert_true(a.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, 62.0, EPS, "Se reinicia en un intento nuevo")


func test_badge_also_returns_energy() -> void:
	GameState.upgrade_levels[&"pulso"] = 5
	var badge := BADGE_SCENE.instantiate() as NotificationBadge
	_world.add_child(badge)
	badge.set_physics_process(false)
	assert_true(badge.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, 54.0, EPS, "El punto rojo aturdido tambien")


func test_full_bar_never_overflows() -> void:
	GameState.upgrade_levels[&"pulso"] = 5
	GameState.debug_energy = GameState.get_debug_energy_max()
	var b: AlertBubble = _bubble(0.0)
	assert_true(b.receive_pulse(_area))
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS)
	assert_eq(GameState.power_banks, 0, "No da power banks")
	assert_true(GameState.is_pulse_return_claimed(b), "Se gasta igual (una vez por enemigo)")


func test_fx_rises_and_frees_itself() -> void:
	var fx := UpgradeFx.spawn(_world, UpgradeFx.ENERGY_RETURN, Vector2(10.0, 20.0))
	assert_not_null(fx)
	fx.auto_process = false
	assert_eq(fx.get_frame(), 0)
	fx.advance(fx.get_duration_s() * 0.5)
	assert_eq(fx.get_frame(), 3)
	fx.advance(fx.get_duration_s())
	assert_true(fx.is_queued_for_deletion(), "Se libera al acabar")
	assert_null(UpgradeFx.spawn(_world, &"no_existe", Vector2.ZERO))
