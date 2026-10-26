# Pruebas de las fuentes de energia y de habilidades (decisiones del usuario
# 2026-10-15): ability_pickup desbloquea el laser, lo guarda y avisa; charger
# repone energia (reutilizable con enfriamiento o de un solo uso guardado); la
# hub real llena la barra al llegar (antes la pantalla provisional del hub);
# catalogo de objetos.
# Usa su propio guardado de prueba (nunca user://save.json).
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const IsakSim = preload("res://tests/support/isak_sim.gd")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/ability_pickup.tscn")
const CHARGER_SCENE: PackedScene = preload("res://scenes/levels/charger.tscn")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_energy_sources_save.json"
const LEVEL_ID: String = "test_energia"
const EPS: float = 0.001

var _saved_path: String
var _saved_level: StringName
var _saved_energy: float
var _sim: IsakSim
var _isak: Isak
var _world: Node2D


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_energy = GameState.debug_energy
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_notas()
	_sim = IsakSim.new()
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-2000.0, 0.0)
	await wait_physics_frames(1)


func after_each() -> void:
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.debug_energy = _saved_energy


## Nivel generado minimo (para el id de nivel de los objetos de un solo uso).
func _level() -> GeneratedLevel:
	var level := GeneratedLevel.new()
	level.level_id = LEVEL_ID
	_world.add_child(level)
	return level


func _pickup(parent: Node, ability: StringName = GameState.ABILITY_LASER) -> AbilityPickup:
	var p := PICKUP_SCENE.instantiate() as AbilityPickup
	p.object_id = &"laser_1"
	p.ability = ability
	parent.add_child(p)
	return p


func _charger(parent: Node, reusable: bool = true, id: StringName = &"cargador_1") -> Charger:
	var c := CHARGER_SCENE.instantiate() as Charger
	c.object_id = id
	c.reusable = reusable
	parent.add_child(c)
	c.set_physics_process(false)
	return c


# --- ability_pickup ---

func test_pickup_unlocks_laser_persists_and_announces() -> void:
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "Bloqueado al empezar")
	var obtained: Array[StringName] = []
	var lines: Array[String] = []
	var on_obtained := func(ability: StringName) -> void: obtained.append(ability)
	var on_line := func(text: String, _d: float, _i: bool) -> void: lines.append(text)
	EventBus.ability_obtained.connect(on_obtained)
	EventBus.eco_line_requested.connect(on_line)
	var p: AbilityPickup = _pickup(_world)
	assert_false(p.collect_by(_world), "Solo Isak lo recoge")
	assert_true(p.collect_by(_isak))
	EventBus.ability_obtained.disconnect(on_obtained)
	EventBus.eco_line_requested.disconnect(on_line)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "Desbloquea el laser")
	assert_eq(obtained, [GameState.ABILITY_LASER] as Array[StringName], "EventBus.ability_obtained")
	# El aviso del control lo da AbilityNotices (test_ability_notices.gd), no el objeto.
	assert_eq(lines.size(), 0, "Sin message, el objeto no pide lineas de Eco")
	assert_true(p.is_taken())
	# Se guarda y se recupera.
	assert_true(GameState.save_game())
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(data.get("abilities_obtained"), ["laser"], "abilities_obtained en el guardado")
	GameState.reset_progress()
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "Empezar de cero lo bloquea")
	assert_true(GameState.load_game())
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "Cargar la partida lo desbloquea")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_LASER))


func test_pickup_absent_when_already_obtained() -> void:
	GameState.obtain_ability(GameState.ABILITY_LASER)
	var p: AbilityPickup = _pickup(_world)
	assert_true(p.is_taken(), "Ya obtenido: no aparece")
	assert_true(p.is_queued_for_deletion())
	assert_false(GameState.obtain_ability(GameState.ABILITY_LASER), "No se obtiene dos veces")


func test_obtained_ability_survives_level_abilities() -> void:
	GameState.obtain_ability(GameState.ABILITY_LASER)
	var level := GeneratedLevel.new()
	level.abilities_available = {"laser": false, "pulse": true}
	_world.add_child(level)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "El nivel no bloquea lo obtenido")
	level.free()
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER))


func test_isak_touching_pickup_collects_it() -> void:
	var p: AbilityPickup = _pickup(_world)
	p.position = Vector2(-32.0, -64.0)
	_isak.global_position = Vector2(0.0, 0.0)
	await wait_physics_frames(4)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "Al tocarlo")


# --- charger ---

func test_charger_refills_energy_with_cooldown() -> void:
	var c: Charger = _charger(_world)
	assert_almost_eq(c.amount, 50.0, EPS, "PROPUESTA: 50 por uso")
	assert_true(c.reusable)
	GameState.debug_energy = 20.0
	var used: Array[float] = []
	var on_used := func(_id: StringName, amount: float) -> void: used.append(amount)
	EventBus.charger_used.connect(on_used)
	assert_almost_eq(c.try_use(_world), 0.0, EPS, "Solo Isak")
	assert_almost_eq(c.try_use(_isak), 50.0, EPS)
	assert_almost_eq(GameState.debug_energy, 70.0, EPS, "Repone la energia")
	assert_false(c.is_ready(), "Se enfria")
	assert_almost_eq(c.try_use(_isak), 0.0, EPS, "Enfriandose no repone")
	c.advance(c.cooldown_s * 0.5)
	assert_false(c.is_ready())
	c.advance(c.cooldown_s * 0.5)
	assert_true(c.is_ready(), "Vuelve a estar listo tras cooldown_s")
	assert_almost_eq(c.try_use(_isak), 30.0, EPS, "Hasta llenar la barra (sin desbordar)")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS)
	EventBus.charger_used.disconnect(on_used)
	assert_eq(used, [50.0, 30.0] as Array[float], "EventBus.charger_used")


func test_charger_full_bar_is_not_spent_and_no_power_bank_overflow() -> void:
	var c: Charger = _charger(_world)
	GameState.debug_energy = GameState.get_debug_energy_max()
	assert_almost_eq(c.try_use(_isak), 0.0, EPS, "Barra llena: no se gasta")
	assert_true(c.is_ready())
	assert_eq(GameState.power_banks, 0, "No da power banks (coleccionable puro)")


func test_single_use_charger_is_saved() -> void:
	var level: GeneratedLevel = _level()
	var c: Charger = _charger(level, false)
	GameState.debug_energy = 0.0
	assert_almost_eq(c.try_use(_isak), 50.0, EPS)
	assert_true(c.is_spent(), "Un solo uso")
	c.advance(1000.0)
	assert_almost_eq(c.try_use(_isak), 0.0, EPS, "No vuelve")
	assert_true(GameState.is_pickup_collected(StringName(LEVEL_ID), &"cargador_1"), "Apuntado por nivel")
	assert_true(GameState.save_game())
	GameState.reset_progress()
	assert_true(GameState.load_game())
	var again: Charger = _charger(level, false)
	assert_true(again.is_spent(), "Al rejugar el nivel sigue gastado")
	var reusable: Charger = _charger(level, true, &"cargador_1")
	assert_false(reusable.is_spent(), "El reutilizable no se guarda")


func test_isak_touching_charger_uses_it() -> void:
	var c: Charger = _charger(_world)
	c.set_physics_process(true)
	c.position = Vector2(-32.0, -64.0)
	GameState.debug_energy = 10.0
	_isak.global_position = Vector2(0.0, 0.0)
	await wait_physics_frames(4)
	assert_almost_eq(GameState.debug_energy, 60.0, EPS, "Al tocarlo repone")


# --- Hub ---

func test_hub_refills_energy() -> void:
	GameState.debug_energy = 5.0
	var pulse_was: bool = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	var hub := HUB_SCENE.instantiate() as HubRoom
	add_child(hub)
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS, "En el hub se recarga")
	hub.free()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, pulse_was)


# --- Catalogo ---

func test_catalog_has_charger_and_ability_pickup() -> void:
	var types: Dictionary = World1ObjectsConfig.data()["types"]
	for type: String in ["charger", "ability_pickup"]:
		assert_true(types.has(type), "Tipo %s en el catalogo" % type)
		var entry: Dictionary = types[type]
		var node: Node = (load(String(entry["scene"])) as PackedScene).instantiate()
		for field: String in entry["fields"]:
			assert_true(String(entry["fields"][field]) in node, "%s.%s" % [type, field])
		for field: String in entry["required"]:
			assert_true(entry["example"]["params"].has(field), "El ejemplo de %s trae %s" % [type, field])
		for field: String in entry.get("defaults", {}):
			assert_almost_eq(float(node.get(String(entry["fields"][field]))), float(entry["defaults"][field]), EPS,
				"%s: default %s igual en la escena" % [type, field])
		node.free()
	assert_true((types["ability_pickup"]["allowed"]["ability"] as Array).has("laser"))
