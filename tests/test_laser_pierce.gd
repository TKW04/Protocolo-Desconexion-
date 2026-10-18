# Laser 5 «Laser perforante» (tanda M2 de docs/propuesta-mejoras.md §2,
# 2026-10-17): el proyectil atraviesa a los enemigos (dana a todos los de la
# linea, una vez a cada uno) y sigue; NO atraviesa el terreno ni los objetos del
# laser (lector, anuncio, Posponer, interruptores, receptores), y un enemigo
# inmune (el punto rojo despierto) lo para con su chispa gris. Destello
# pierce_spark (UpgradeFx) en cada enemigo atravesado. Las salas del 1-2 con el
# laser que perfora: test_laser_pierce_correo.gd, _snooze.gd y _calc_room.gd.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const BADGE_SCENE: PackedScene = preload("res://scenes/enemies/notification_badge.tscn")
const PUZZLE_SCENES: Array[String] = [
	"res://scenes/levels/laser_receiver.tscn", "res://scenes/levels/ad_cover.tscn",
	"res://scenes/levels/snooze_button.tscn", "res://scenes/levels/laser_switch.tscn",
	"res://scenes/levels/relay_receiver.tscn",
]
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const MAX_STEPS: int = 120

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"laser": GameState.is_ability_unlocked(GameState.ABILITY_LASER),
		"energy": GameState.debug_energy,
	}
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.input_enabled = true
	GameState.upgrade_levels.clear()
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved.laser)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _fire() -> LaserProjectile:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	for i: int in ceili(_isak.abilities.laser_windup_s / DT) + 2:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	fired[0].auto_process = false
	return fired[0]


func _fly(p: LaserProjectile) -> void:
	for i: int in MAX_STEPS:
		if p.is_finished():
			return
		p.step(DT)


func _bubble(x: float) -> AlertBubble:
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.position = Vector2(x, 0.0)
	b.patrol_range_px = 0.0
	b.free_on_pop = false
	b.target = _isak
	_world.add_child(b)
	b.set_physics_process(false)
	return b


func _wall(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64.0, 256.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(x + 32.0, -128.0)
	_world.add_child(body)
	return body


func _sparks() -> int:
	var count: int = 0
	for node: Node in _world.get_children():
		if node is UpgradeFx and (node as UpgradeFx).kind == UpgradeFx.PIERCE_SPARK:
			count += 1
	return count


func test_upgrade_level_5_turns_pierce_on() -> void:
	assert_almost_eq(PlayerAbilities.load_from_file().laser_pierce, 0.0, EPS, "Base: no perfora")
	GameState.upgrade_levels[&"laser"] = 4
	var four := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(four)
	assert_almost_eq(four.abilities.laser_pierce, 0.0, EPS, "Laser 4: no perfora")
	GameState.upgrade_levels[&"laser"] = 5
	var five := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(five)
	assert_almost_eq(five.abilities.laser_pierce, 1.0, EPS, "Laser 5: perfora")
	assert_almost_eq(five.abilities.laser_damage, 2.0, EPS, "Conserva el dano del Laser 4")
	var shot := LaserProjectile.new()
	shot.setup(five.abilities, 1.0, five)
	assert_true(shot.pierce)
	shot.free()


func test_without_pierce_the_first_enemy_stops_the_beam() -> void:
	var first: AlertBubble = _bubble(_isak.global_position.x + 200.0)
	var second: AlertBubble = _bubble(_isak.global_position.x + 320.0)
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire()
	_fly(p)
	assert_eq(p.get_hit_target(), first)
	assert_almost_eq(first.get_health(), 1.0, EPS)
	assert_almost_eq(second.get_health(), 2.0, EPS, "El segundo no recibe nada")
	assert_eq(_sparks(), 0)


func test_pierce_damages_every_enemy_in_the_line() -> void:
	_isak.abilities.laser_pierce = 1.0
	var first: AlertBubble = _bubble(_isak.global_position.x + 200.0)
	var second: AlertBubble = _bubble(_isak.global_position.x + 320.0)
	var third: AlertBubble = _bubble(_isak.global_position.x + 440.0)
	third.stun()  # aturdida: su plataforma (capa world) tampoco para el haz
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire()
	watch_signals(p)
	_fly(p)
	assert_eq(p.get_pierced(), [first, second, third] as Array[Node], "Atraviesa a los tres")
	for b: AlertBubble in [first, second, third]:
		assert_almost_eq(b.get_health(), 1.0, EPS, "Cada uno recibe el dano una vez")
	assert_signal_emit_count(p, "pierced", 3)
	assert_null(p.get_hit_target(), "No choca con ninguno: llega a su alcance")
	assert_almost_eq(p.get_traveled(), p.range_px, 1.0, "Vuela todo su alcance")
	assert_eq(_sparks(), 3, "Un destello por enemigo atravesado")


func test_pierce_does_not_cross_terrain() -> void:
	_isak.abilities.laser_pierce = 1.0
	var near: AlertBubble = _bubble(_isak.global_position.x + 160.0)
	_wall(_isak.global_position.x + 260.0)
	var far: AlertBubble = _bubble(_isak.global_position.x + 420.0)
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire()
	_fly(p)
	assert_almost_eq(near.get_health(), 1.0, EPS, "Antes de la pared, atravesada")
	assert_almost_eq(far.get_health(), 2.0, EPS, "Detras de la pared, intacta")
	assert_true(p.is_finished())
	assert_null(p.get_hit_target(), "Choca con el terreno")
	assert_lt(p.global_position.x, _isak.global_position.x + 262.0, "Se para en la pared")


func test_immune_awake_badge_stops_the_beam() -> void:
	_isak.abilities.laser_pierce = 1.0
	var badge := BADGE_SCENE.instantiate() as NotificationBadge
	badge.free_on_pop = false
	_world.add_child(badge)
	badge.set_physics_process(false)
	# Centro del cuerpo a la altura del celular (pies - 56).
	badge.global_position = Vector2(_isak.global_position.x + 200.0, _isak.global_position.y - 56.0 - badge.center_y)
	var behind: AlertBubble = _bubble(_isak.global_position.x + 360.0)
	await wait_physics_frames(2)
	assert_false(badge.is_laser_vulnerable(), "Despierto es inmune")
	var p: LaserProjectile = _fire()
	_fly(p)
	assert_eq(p.get_hit_target(), badge, "El inmune para el haz")
	assert_true(badge.is_deflecting(), "Chispa gris")
	assert_almost_eq(behind.get_health(), 2.0, EPS, "Lo de detras no recibe nada")
	assert_true(p.get_pierced().is_empty())


func test_puzzle_objects_are_never_pierced() -> void:
	var shot := LaserProjectile.new()
	shot.pierce = true
	add_child_autofree(shot)
	for path: String in PUZZLE_SCENES:
		var obj: Node = (load(path) as PackedScene).instantiate()
		add_child_autofree(obj)
		assert_false(shot.can_pierce(obj), "%s para el haz" % path.get_file())
	var bubble: AlertBubble = _bubble(-4000.0)
	assert_true(shot.can_pierce(bubble), "Un enemigo si se atraviesa")
	shot.pierce = false
	assert_false(shot.can_pierce(bubble), "Sin la mejora no")


func test_pierce_beam_stops_at_laser_receiver() -> void:
	_isak.abilities.laser_pierce = 1.0
	var bubble: AlertBubble = _bubble(_isak.global_position.x + 160.0)
	var receiver := (load("res://scenes/levels/laser_receiver.tscn") as PackedScene).instantiate() as LaserReceiver
	_world.add_child(receiver)
	# El lector (su zona de golpe) a la altura del celular, detras de la Burbuja.
	var rect: Rect2 = receiver.get_hit_rect()
	var phone_y: float = _isak.global_position.y - 56.0
	receiver.global_position += Vector2(_isak.global_position.x + 320.0 - rect.position.x, phone_y - rect.get_center().y)
	var far: AlertBubble = _bubble(_isak.global_position.x + 520.0)
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire()
	_fly(p)
	assert_almost_eq(bubble.get_health(), 1.0, EPS, "Atraviesa la Burbuja")
	assert_eq(p.get_hit_target(), receiver, "El lector para el haz")
	assert_true(receiver.is_powered(), "Y recibe la corriente como siempre")
	assert_almost_eq(far.get_health(), 2.0, EPS, "Lo de detras del lector, intacto")
