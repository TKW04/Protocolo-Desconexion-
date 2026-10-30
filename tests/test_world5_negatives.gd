# Pruebas de conjunto del Mundo 5 (paso 21 de docs/propuesta-mundo-5.md §8, 2026-10-29;
# §7.4) con las escenas reales:
# - rejugar los Mundos 1-4 con la Combinacion: en cada nivel y arena real de los
#   Mundos 1-4, una Embestida y un Sismo cuya onda alcanza TODO el nivel y un Filo que
#   lo atraviesa entero solo tocan enemigos (aturden, danan o derrotan a los pequenos):
#   no completan el nivel, no dan habilidades, no apuntan secretos ni recuerdos, no
#   tocan el Sync Rate de Isak ni el contador del jefe y no abren su ventana. Ninguna
#   pieza de los Mundos 1-4 escucha EventBus.combo_landed (solo las del Mundo 5).
# Los otros negativos de §7.4: quieto pierde (tests/test_vendor_bot.gd, perfil idle), sin la
# Combinacion no se sale de «Paquete completo» (tests/test_level_5_2.py y tests/test_level_5_2.gd),
# con 0 puntos se completan los tres niveles (tests/test_mall_bot.gd, que entra con 0, y
# tests/test_world5_negatives.py) y el validador de los Mundos 1-4 con la Combinacion
# (tests/test_world5_negatives.py y la comparacion del paso 21 en §8.1).
extends GutTest

const LEVELS_1_4: Array[String] = ["1-1", "1-2", "1-3", "1-boss", "2-1", "2-2", "2-3", "2-boss", "3-1", "3-2",
	"3-3", "3-boss", "4-1", "4-2", "4-3", "4-boss"]
const HUGE: float = 1.0e6

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


func test_combos_in_worlds_1_to_4_only_touch_enemies() -> void:
	for id: String in LEVELS_1_4:
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
		var listeners: Array[String] = []
		for connection: Dictionary in EventBus.combo_landed.get_connections():
			var target: Object = (connection["callable"] as Callable).get_object()
			if target is Node and level.is_ancestor_of(target as Node):
				listeners.append(String((target as Node).name))
		assert_eq(listeners, [] as Array[String], "%s: ninguna pieza de los Mundos 1-4 escucha la Combinacion" % id)
		var abilities: Dictionary = {}
		for ability: StringName in GameState.ABILITIES:
			abilities[ability] = GameState.is_ability_obtained(ability)
		var sync: float = GameState.sync_rate
		var secrets: int = GameState.found_secrets.size()
		var memories: int = GameState.memories.size()
		var hits: int = boss.get_remaining_hits() if boss != null else 0
		var isak: Isak = level.get_isak()
		var feet: Vector2 = isak.global_position if isak != null else Vector2.ZERO
		var everything := Rect2(-HUGE, -HUGE, 2.0 * HUGE, 2.0 * HUGE)
		var touched: int = 0
		for kind: StringName in [Isak.COMBO_RAM, Isak.COMBO_QUAKE]:
			var damage: float = isak.abilities.combo_ram_damage if kind == Isak.COMBO_RAM \
					else isak.abilities.combo_quake_damage
			var stun_s: float = isak.abilities.combo_ram_stun_s if kind == Isak.COMBO_RAM \
					else isak.abilities.combo_quake_stun_s
			touched += ComboWave.apply_to_enemies(get_tree(), kind, everything, damage, stun_s)
			EventBus.combo_landed.emit(kind, everything, isak)
			await wait_physics_frames(2)
		touched += ComboWave.defeat_small(get_tree(), everything, isak.abilities.combo_edge_defeat_max_health, {})
		await wait_physics_frames(3)
		assert_true(_completed.is_empty(), "%s: la Combinacion no completa el nivel" % id)
		assert_eq(GameState.sync_rate, sync, "%s: la Combinacion no hace dano a Isak" % id)
		assert_eq(GameState.found_secrets.size(), secrets, "%s: la Combinacion no apunta secretos" % id)
		assert_eq(GameState.memories.size(), memories, "%s: la Combinacion no da recuerdos" % id)
		for ability: StringName in abilities:
			assert_eq(GameState.is_ability_obtained(ability), abilities[ability],
					"%s: la Combinacion no da %s" % [id, ability])
		if boss != null:
			assert_eq(boss.get_remaining_hits(), hits, "%s: la Combinacion no golpea al jefe" % id)
			assert_false(boss.is_window_open(), "%s: la Combinacion no abre la ventana del jefe" % id)
		gut.p("%s: %d enemigos alcanzados (feet %s)" % [id, touched, feet])
		level.queue_free()
		await wait_physics_frames(2)
