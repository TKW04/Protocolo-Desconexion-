# Pruebas de conjunto del Mundo 4 (paso 21 de docs/propuesta-mundo-4.md §8, 2026-10-28;
# §7.4) con las escenas reales y el Isak real:
# - rejugar los Mundos 1-3 con Agitar (retirado el 2026-10-28: ya no sale nunca,
#   tests/test_shockwave.gd; la prueba sigue con la logica conservada, por si vuelve):
#   en cada nivel y arena real de los Mundos 1-3,
#   una onda de Agitar que alcanza TODO el nivel solo aturde enemigos (sin dano): no
#   activa receptores ni terminales, no completa el nivel, no da habilidades, no toca
#   el Sync Rate de Isak ni el contador del jefe y no abre su ventana;
# - congelarse no mata: Isak congelado mucho mas que una zona «Visto» sigue con su
#   Sync Rate y vivo;
# Los otros negativos de §7.4: la ola no mata sola (tests/test_seen_wave.gd), quieto pierde (tests/test_seen_bot.gd, perfil idle), sin
# usar el «¿Deshacer escritura?» no se sale de «Mensajes borrados» (tests/test_level_4_2.py y
# tests/test_world4_validator.py), salidas del validador de los Mundos 1-3 identicas
# y Kernel/Raiz sin cambios (comparacion del paso 21 en §8.1) y los del modelo en
# tests/test_world4_negatives.py.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const DT: float = 1.0 / 60.0
const LEVELS_1_3: Array[String] = ["1-1", "1-2", "1-3", "1-boss", "2-1", "2-2", "2-3", "2-boss", "3-1", "3-2",
	"3-3", "3-boss"]

var _completed: Array[String] = []


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	_completed.clear()
	EventBus.level_completed.connect(_on_completed)


func after_each() -> void:
	EventBus.level_completed.disconnect(_on_completed)
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_completed(level_id: String) -> void:
	_completed.append(level_id)


func _boss_of(level: Node) -> BossBase:
	for node: Node in level.find_children("*", "", true, false):
		if node is BossBase:
			return node
	return null


func test_shockwave_in_worlds_1_to_3_only_stuns_enemies() -> void:
	for id: String in LEVELS_1_3:
		var level := (load("res://scenes/levels/%s.tscn" % id) as PackedScene).instantiate() as GeneratedLevel
		var boss: BossBase = _boss_of(level)
		if boss != null:
			boss.set(&"intro_on_arrival", false)
			boss.set(&"defeat_sequence", false)
			boss.auto_process = false
		add_child_autofree(level)
		await wait_physics_frames(2)
		if boss != null:
			boss.start()
		var abilities: Dictionary = {}
		for ability: StringName in GameState.ABILITIES:
			abilities[ability] = GameState.is_ability_obtained(ability)
		var sync: float = GameState.sync_rate
		var hits: int = boss.get_remaining_hits() if boss != null else 0
		var isak: Isak = level.get_isak()
		var center: Vector2 = isak.global_position if isak != null else Vector2.ZERO
		var stunned: int = ShockwaveWave.apply_to_enemies(get_tree(), center, 1.0e6, 2.0)
		EventBus.shockwave_fired.emit(center, 1.0e6, isak)
		await wait_physics_frames(3)
		assert_true(_completed.is_empty(), "%s: Agitar no completa el nivel" % id)
		assert_eq(GameState.sync_rate, sync, "%s: Agitar no hace dano a Isak" % id)
		for ability: StringName in abilities:
			assert_eq(GameState.is_ability_obtained(ability), abilities[ability], "%s: Agitar no da %s" % [id, ability])
		if boss != null:
			assert_eq(boss.get_remaining_hits(), hits, "%s: Agitar no golpea al jefe" % id)
			assert_false(boss.is_window_open(), "%s: Agitar no abre la ventana del jefe" % id)
		gut.p("%s: %d enemigos aturdidos" % [id, stunned])
		level.queue_free()
		await wait_physics_frames(2)


func test_freezing_never_kills() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	await wait_physics_frames(1)
	sim.settle()
	GameState.sync_rate = 5.0
	assert_true(sim.isak.freeze(30.0, Isak.FREEZE_SOURCE_ZONE), "Se congela")
	sim.step(sim.steps_for(10.0))
	assert_true(sim.isak.is_frozen(), "Sigue congelado")
	assert_eq(GameState.sync_rate, 5.0, "Congelado no pierde Sync Rate")
	assert_false(sim.isak.is_dead(), "Congelarse no mata")

