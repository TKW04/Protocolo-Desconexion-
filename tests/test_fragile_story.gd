# Tarjeta fragil e Historia del Mundo 2 (2026-10-22, paso 4 de
# docs/propuesta-mundo-2.md §8, §3.4): FragileCard (reutiliza ReminderPlatform:
# cuenta al pisarla, caida sin dano y vuelta; el golpe al suelo la rompe al
# instante y deja seguir cayendo; variantes de una via, de pie y oculta) y
# StoryCard (reutiliza BlinkPlatform con su propio reloj: encendida on_s de cada
# cycle_s, aviso antes de apagarse, no se materializa con Isak dentro). El tiempo
# se avanza a mano.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const FRAGILE_SCENE: PackedScene = preload("res://scenes/levels/fragile_card.tscn")
const STORY_SCENE: PackedScene = preload("res://scenes/levels/story_card.tscn")
const TARJETAS_SCENE: PackedScene = preload("res://scenes/levels/tarjetas_test.tscn")
const DT: float = 1.0 / 60.0
const T: float = 64.0
const EPS: float = 0.01

var _root: Node2D
var _saved_pound: bool
var _saved_debug: bool


func before_each() -> void:
	_saved_pound = GameState.is_ability_unlocked(GameState.ABILITY_GROUND_POUND)
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	_root = Node2D.new()
	add_child_autofree(_root)
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, _saved_pound)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)


func _fragile(params: Dictionary = {}, at: Vector2 = Vector2(0.0, 0.0)) -> FragileCard:
	var card := FRAGILE_SCENE.instantiate() as FragileCard
	for key: String in params:
		card.set(key, params[key])
	card.position = at
	card.set_physics_process(false)
	_root.add_child(card)
	return card


func _story(params: Dictionary = {}) -> StoryCard:
	var card := STORY_SCENE.instantiate() as StoryCard
	card.object_id = &"historia"
	for key: String in params:
		card.set(key, params[key])
	card.set_physics_process(false)
	_root.add_child(card)
	card.get_own_clock().set_physics_process(false)
	return card


func _advance(card: FragileCard, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		card.advance(DT)


func _shape(card: Node) -> CollisionShape2D:
	return card.get_node(^"Shape") as CollisionShape2D


# --- Tarjeta fragil ---

func test_fragile_data_and_size() -> void:
	var entry: Dictionary = World2ObjectsConfig.data()["types"]["fragile_card"]
	assert_almost_eq(float(entry["defaults"]["timer_s"]), 0.6, EPS, "Cuenta 0,6 s")
	assert_almost_eq(float(entry["defaults"]["respawn_s"]), 3.0, EPS, "Vuelve a los 3 s")
	var card := _fragile({"width_tiles": 3})
	assert_eq(card.get_card_size(), Vector2(3.0 * T, 32.0))
	assert_true(card.is_solid())
	assert_eq(card.collision_layer, ReminderPlatform.LAYER_WORLD)
	var upright := _fragile({"variant": FragileCard.VARIANT_UPRIGHT, "width_tiles": 1}, Vector2(256.0, 0.0))
	assert_eq(upright.get_card_size(), Vector2(T, 2.0 * T), "De pie: pared de 1 x 2")
	assert_eq(upright.trigger_mode, FragileCard.TRIGGER_POUND_ONLY, "La de pie solo la rompe la onda")


func test_fragile_counts_alone_then_falls_and_comes_back() -> void:
	var a := _fragile()
	var b := _fragile({}, Vector2(256.0, 0.0))
	assert_true(a.trigger(), "Pisarla empieza la cuenta")
	assert_true(a.is_counting())
	assert_false(b.is_counting(), "Sin grupos: la otra no cuenta")
	_advance(a, 0.3)
	assert_gt(a.get_crack(), 0.4, "La grieta crece")
	assert_true(a.is_warning(), "Los ultimos 0,5 s avisa")
	_advance(a, 0.35)
	assert_false(a.is_solid(), "A los 0,6 s cae")
	assert_true(_shape(a).disabled, "Sin colision")
	assert_false(a.is_broken_by_pound(), "Caer por la cuenta no es romperla")
	_advance(a, 3.2)
	assert_false(a.is_solid(), "Aun no (caida 0,3 s + 3 s)")
	_advance(a, 0.6)
	assert_true(a.is_solid(), "Vuelve a los 3 s")


func test_pound_breaks_it_instantly_and_lets_isak_fall() -> void:
	var card := _fragile({"width_tiles": 2})
	var far := Rect2(Vector2(1000.0, -64.0), Vector2(192.0, 72.0))
	EventBus.ground_pound_landed.emit(far, null)
	assert_true(card.is_solid(), "Fuera de la onda no le pasa nada")
	var on_top := Rect2(Vector2(-32.0, -64.0), Vector2(192.0, 72.0))
	EventBus.ground_pound_landed.emit(on_top, null)
	assert_false(card.is_solid(), "La onda la rompe al instante")
	assert_true(card.is_broken_by_pound(), "Isak sigue cayendo a traves de ella")
	assert_eq(card.get_pound_break_count(), 1)


func test_pound_only_does_not_count_when_stepped() -> void:
	var card := _fragile({"trigger_mode": FragileCard.TRIGGER_POUND_ONLY})
	assert_false(card.trigger(), "Pisarla no hace nada")
	assert_false(card.is_counting())


func test_upright_stays_broken_until_isak_respawns() -> void:
	var wall := _fragile({"variant": FragileCard.VARIANT_UPRIGHT, "width_tiles": 1})
	EventBus.ground_pound_landed.emit(Rect2(Vector2(-96.0, 64.0), Vector2(192.0, 72.0)), null)
	assert_false(wall.is_solid(), "La onda la rompe")
	_advance(wall, 10.0)
	assert_false(wall.is_solid(), "No vuelve sola")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_true(wall.is_solid(), "Vuelve al reaparecer Isak")


func test_one_way_and_hidden_variants() -> void:
	var thin := _fragile({"one_way": true})
	assert_true(_shape(thin).one_way_collision, "De una via")
	var hidden := _fragile({"hidden_card": true, "trigger_mode": FragileCard.TRIGGER_POUND_ONLY}, Vector2(256.0, 0.0))
	assert_false(hidden.is_help_available(), "Oculta: sin Debug no hay Q")
	var wave := Rect2(Vector2(160.0, -64.0), Vector2(192.0, 72.0))
	EventBus.ground_pound_landed.emit(wave, null)
	assert_true(hidden.is_solid(), "Oculta: sin el Debug la onda no la rompe (no se ve la grieta)")
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 30:
		DebugMode.step(DT, true)
	EventBus.ground_pound_landed.emit(wave, null)
	assert_false(hidden.is_solid(), "Con el Debug activo, si")


func test_isak_pounding_a_real_card_falls_through_it() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	var sim := IsakSim.new(DT)
	var world := sim.build_flat_world()
	_root.add_child(world)
	sim.take_manual_control()
	var isak: Isak = sim.isak
	var card := FRAGILE_SCENE.instantiate() as FragileCard
	card.width_tiles = 3
	card.trigger_mode = FragileCard.TRIGGER_POUND_ONLY
	card.position = Vector2(-96.0, -192.0)
	card.set_physics_process(false)
	world.add_child(card)
	await wait_physics_frames(1)
	isak.global_position = Vector2(0.0, -192.0 - 4.0)
	sim.step()
	sim.step_until(func() -> bool: return isak.is_on_floor(), sim.steps_for(1.0))
	assert_almost_eq(isak.global_position.y, -192.0, 2.0, "De pie en la tarjeta")
	sim.input.hold_held = true
	sim.step_until(func() -> bool: return not card.is_solid(), sim.steps_for(2.0))
	assert_true(card.is_broken_by_pound(), "El golpe la rompe")
	sim.step_until(func() -> bool: return isak.is_on_floor() and isak.global_position.y > -10.0, sim.steps_for(2.0))
	assert_almost_eq(isak.global_position.y, 0.0, 2.0, "Cae hasta el suelo de abajo")
	sim.input.hold_held = false


# --- Historia ---

func test_story_own_clock_on_and_off() -> void:
	var card := _story()
	var clock: RhythmZone = card.get_own_clock()
	assert_not_null(clock, "Sin rhythm: reloj propio")
	assert_almost_eq(card.on_fraction, 0.5, EPS, "1,6 de 3,2 s")
	clock.step(DT)
	card.refresh()
	assert_true(card.is_solid(), "Empieza encendida")
	for i: int in roundi(1.0 / DT):
		clock.advance(DT)
	card.refresh()
	assert_true(card.is_warning(), "Los ultimos 0,75 s parpadea")
	for i: int in roundi(0.7 / DT):
		clock.advance(DT)
	card.refresh()
	assert_false(card.is_solid(), "A los 1,6 s desaparece")
	assert_true(_shape(card).disabled)
	for i: int in roundi(1.7 / DT):
		clock.advance(DT)
	card.refresh()
	assert_true(card.is_solid(), "Vuelve en el ciclo siguiente")


func test_story_offset_and_size() -> void:
	var card := _story({"offset": 0.5, "width_tiles": 3})
	assert_eq(card.get_card_size(), Vector2(3.0 * T, 32.0))
	card.get_own_clock().step(DT)
	card.refresh()
	assert_false(card.is_solid(), "Desplazada medio ciclo: empieza apagada")


# --- Sala de prueba ---

func test_tarjetas_test_scene_builds_the_cards() -> void:
	var level := TARJETAS_SCENE.instantiate() as GeneratedLevel
	_root.add_child(level)
	await wait_physics_frames(1)
	var objects: Node = level.get_node(^"Objects")
	var fragiles: int = 0
	var stories: int = 0
	for node: Node in objects.get_children():
		if node is FragileCard:
			fragiles += 1
		elif node is StoryCard:
			stories += 1
	assert_eq(fragiles, 4)
	assert_eq(stories, 2)
	var hidden := objects.get_node(^"fragil_oculta") as FragileCard
	assert_true(hidden.hidden_card)
	var wall := objects.get_node(^"fragil_de_pie") as FragileCard
	assert_eq(wall.variant, FragileCard.VARIANT_UPRIGHT)
	level.free()
