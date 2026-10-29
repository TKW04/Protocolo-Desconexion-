# Combinacion de Isak (habilidad combo; paso 1 de docs/propuesta-mundo-5.md §8, reglas
# de §3.2 y pruebas de §7.4): sin combo las tres combinaciones siguen negadas; con
# el: Embestida (diagonal desde un dash aereo, onda de 2 tiles, dano 2), Filo (dash
# comprimido de 4 tiles, derrota a los de vida <= 1) y Sismo (onda por todo el suelo
# visible, solo lo que toca el suelo); 15 de energia; nada con el Debug ni sin
# energia (chispa gris); solo en el aire; apagan el Ocultarte; vortice y muerte; aviso
# con las teclas leidas del Input Map. Isak avanza paso a paso con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_combo_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const T: float = 64.0
const ABILITIES: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
	GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]


## Enemigo de prueba: cuerpo de 48 x 64 con los pies en su posicion, vida y aturdimiento propio.
class FakeEnemy:
	extends Node2D
	var size := Vector2(48.0, 64.0)
	var health: float = 1.0
	var stun_duration_s: float = 1.5
	var stuns: Array = []
	var damage_taken: float = 0.0

	func _ready() -> void:
		add_to_group(&"enemy")

	func get_body_rect() -> Rect2:
		return Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)

	func stun(duration_scale: float = 1.0) -> void:
		stuns.append(duration_scale)

	func get_health() -> float:
		return health

	func take_damage(amount: float) -> bool:
		if health <= 0.0:
			return false
		health -= amount
		damage_taken += amount
		return true


var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _denied: Array = []
var _landed: Array = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND,
			GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]:
		GameState.set_ability_unlocked(ability, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_denied = []
	_landed = []
	EventBus.combo_denied.connect(_on_denied)
	EventBus.combo_landed.connect(_on_landed)
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	EventBus.combo_denied.disconnect(_on_denied)
	EventBus.combo_landed.disconnect(_on_landed)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_player_hidden(false)
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_denied(reason: StringName) -> void:
	_denied.append(reason)


func _on_landed(kind: StringName, rect: Rect2, _source: Node2D) -> void:
	_landed.append([kind, rect])


# --- Utilidades ---

func _enemy(at: Vector2, health: float = 1.0) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	enemy.health = health
	enemy.position = at
	_world.add_child(enemy)
	return enemy


## Salta y sube `frames` pasos.
func _jump(frames: int = 12) -> void:
	_sim.press_jump()
	_sim.step(frames)
	assert_false(_isak.is_on_floor(), "En el aire")


func _pinch() -> void:
	_sim.input.pinch_pressed = true
	_sim.step()


func _press_dash(axis: float = 0.0) -> void:
	_sim.input.move_axis = axis
	_sim.input.dash_pressed = true
	_sim.step()
	_sim.input.move_axis = 0.0


## Mantiene abajo `seconds` (el gesto del golpe al suelo).
func _hold_down(seconds: float) -> void:
	_sim.input.hold_held = true
	_sim.step(_sim.frames(seconds) + 1)


func _release_down() -> void:
	_sim.input.hold_held = false


func _wait_not(state: StringName, seconds: float = 2.0) -> void:
	_sim.step_until(func() -> bool: return _sim.state() != state, _sim.steps_for(seconds))


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Debug activo")


# --- Datos ---

func test_data_values() -> void:
	var a: PlayerAbilities = _isak.abilities
	assert_almost_eq(a.combo_energy_cost, 15.0, EPS, "15 de energia por combo")
	assert_almost_eq(a.combo_ram_angle_deg, 45.0, EPS)
	assert_almost_eq(a.combo_ram_speed_px_s, 960.0, EPS)
	assert_almost_eq(a.combo_ram_wave_half_width_px, 2.0 * T, EPS, "Onda de 2 tiles a cada lado")
	assert_almost_eq(a.combo_ram_damage, 2.0, EPS)
	assert_almost_eq(a.combo_ram_stun_s, 3.0, EPS)
	assert_almost_eq(a.combo_edge_distance_px, 4.0 * T, EPS, "4 tiles")
	assert_almost_eq(a.combo_edge_duration_s, 0.22, EPS)
	assert_almost_eq(a.combo_edge_defeat_max_health, 1.0, EPS)
	assert_almost_eq(a.combo_quake_wave_speed_px_s, 1280.0, EPS)
	assert_almost_eq(a.combo_quake_wave_s, 0.5, EPS)
	assert_almost_eq(a.combo_quake_damage, 0.0, EPS)
	assert_true(GameState.ABILITIES.has(GameState.ABILITY_COMBO))


# --- Sin la Combinacion todo sigue negado ---

func test_without_combo_the_three_pairs_stay_denied() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_COMBO, false)
	# Dash aereo + abajo: dash normal y, tras el, golpe al suelo normal.
	_jump()
	_press_dash(1.0)
	assert_eq(_sim.state(), PlayerState.DASH)
	_sim.input.hold_held = true
	_wait_not(PlayerState.DASH)
	assert_ne(_sim.state(), PlayerState.COMBO_RAM, "Sin Embestida")
	_sim.step_until(func() -> bool: return _isak.is_on_floor(), _sim.steps_for(2.0))
	_release_down()
	_wait_not(PlayerState.GROUND_POUND)
	_sim.settle()
	# Comprimido en el aire: ni dash ni golpe.
	_jump()
	_pinch()
	assert_true(_isak.is_compressed())
	var energy: float = GameState.debug_energy
	_press_dash(1.0)
	assert_ne(_sim.state(), PlayerState.COMBO_EDGE, "Sin Filo")
	assert_ne(_sim.state(), PlayerState.DASH, "Ni dash comprimido")
	_hold_down(0.3)
	assert_ne(_sim.state(), PlayerState.COMBO_QUAKE, "Sin Sismo")
	assert_ne(_sim.state(), PlayerState.GROUND_POUND, "Ni golpe comprimido")
	assert_almost_eq(GameState.debug_energy, energy, EPS, "Nada cobra")
	assert_eq(_denied, [], "Sin aviso")
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.NONE, "Sin chispa")


# --- Embestida ---

func test_ram_dives_diagonally_and_its_wave_hits_two_tiles() -> void:
	_jump()
	var energy: float = GameState.debug_energy
	_press_dash(1.0)
	assert_eq(_sim.state(), PlayerState.DASH)
	_sim.input.hold_held = true
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.DASH, _sim.steps_for(0.5))
	assert_eq(_sim.state(), PlayerState.COMBO_RAM, "Abajo durante el dash aereo = Embestida")
	assert_almost_eq(GameState.debug_energy, energy - 10.0 - 15.0, EPS, "El dash y 15 del combo")
	assert_true(_isak.is_invulnerable(), "Invulnerable hasta tocar suelo")
	_sim.step()
	var v: Vector2 = _isak.velocity
	assert_almost_eq(v.x, v.y, 1.0, "45 grados hacia delante y abajo")
	assert_almost_eq(v.length(), 960.0, 1.0)
	var landing_x: float = _isak.global_position.x + absf(_isak.global_position.y)
	var near := _enemy(Vector2(landing_x + 100.0, 0.0), 3.0)
	var far := _enemy(Vector2(landing_x + 3.0 * T + 40.0, 0.0), 3.0)
	_sim.step_until(func() -> bool: return _isak.is_on_floor(), _sim.steps_for(2.0))
	_sim.step()
	assert_eq(_landed.size(), 1, "EventBus.combo_landed")
	assert_eq(_landed[0][0], Isak.COMBO_RAM)
	var rect: Rect2 = _landed[0][1]
	assert_almost_eq(rect.size.x, 4.0 * T, EPS, "2 tiles a cada lado")
	assert_almost_eq(near.damage_taken, 2.0, EPS, "Dano 2 (el golpe al suelo hace 1)")
	assert_eq(near.stuns.size(), 1)
	assert_almost_eq(float(near.stuns[0]), 3.0 / near.stun_duration_s, EPS, "Aturde 3 s")
	assert_eq(far.stuns, [], "A 3 tiles no llega")
	assert_false(_isak.is_invulnerable(), "Al aterrizar deja de ser invulnerable")
	_release_down()
	_wait_not(PlayerState.COMBO_RAM)
	assert_ne(_sim.state(), PlayerState.GROUND_POUND, "Sin golpe al suelo encadenado")


func test_ram_only_from_an_air_dash() -> void:
	_press_dash(1.0)
	assert_eq(_sim.state(), PlayerState.DASH, "Dash en el suelo")
	_sim.input.hold_held = true
	_sim.step(3)
	assert_ne(_sim.state(), PlayerState.COMBO_RAM, "Dash en el suelo + abajo: nada")
	_release_down()


# --- Filo ---

func test_edge_compressed_dash_of_four_tiles_defeats_small_enemies() -> void:
	_jump(8)
	_pinch()
	assert_true(_isak.is_compressed())
	var start: Vector2 = _isak.global_position
	var small := _enemy(Vector2(start.x + 2.0 * T, start.y + 8.0), 1.0)
	var big := _enemy(Vector2(start.x + 3.0 * T, start.y + 8.0), 2.0)
	var energy: float = GameState.debug_energy
	_press_dash(1.0)
	assert_eq(_sim.state(), PlayerState.COMBO_EDGE, "Comprimido en el aire + Deslizar = Filo")
	assert_almost_eq(GameState.debug_energy, energy - 15.0, EPS)
	assert_true(_isak.is_invulnerable(), "Atraviesa sin dano")
	var steps: int = 1 + _sim.step_until(func() -> bool: return _sim.state() != PlayerState.COMBO_EDGE, _sim.steps_for(1.0))
	var travelled: float = _isak.global_position.x - start.x
	assert_almost_eq(travelled, 4.0 * T, 12.0, "4 tiles")
	assert_almost_eq(float(steps) * DT, 0.22, 0.05, "En 0,22 s")
	assert_true(_isak.is_compressed(), "Sigue comprimido")
	assert_almost_eq(small.health, 0.0, EPS, "Derrota al de vida 1")
	assert_almost_eq(big.damage_taken, 0.0, EPS, "El de vida 2 no")
	# Gasta el dash aereo: otro Filo en el mismo salto no sale (sin aviso).
	_press_dash(1.0)
	assert_ne(_sim.state(), PlayerState.COMBO_EDGE, "Uno por estancia en el aire")


func test_edge_keeps_height() -> void:
	_jump(20)
	_pinch()
	var y: float = _isak.global_position.y
	_press_dash(-1.0)
	assert_eq(_sim.state(), PlayerState.COMBO_EDGE)
	assert_almost_eq(_isak.global_position.y, y, 2.0, "Gravedad 0")
	assert_lt(_isak.global_position.x, 0.0, "Hacia la direccion mantenida")


# --- Sismo ---

func test_quake_wave_covers_the_visible_floor_only() -> void:
	_jump()
	_pinch()
	var span: Vector2 = _isak.get_quake_span()
	var on_floor := _enemy(Vector2(lerpf(span.x, span.y, 0.9), 0.0), 2.0)
	var other_side := _enemy(Vector2(lerpf(span.x, span.y, 0.05), 0.0), 2.0)
	var flying := _enemy(Vector2(lerpf(span.x, span.y, 0.8), -3.0 * T), 2.0)
	var off_screen := _enemy(Vector2(span.y + 200.0, 0.0), 2.0)
	var energy: float = GameState.debug_energy
	_hold_down(0.1)
	assert_eq(_sim.state(), PlayerState.COMBO_QUAKE, "Comprimido en el aire + abajo = Sismo")
	assert_almost_eq(GameState.debug_energy, energy - 15.0, EPS)
	_sim.step_until(func() -> bool: return _isak.is_on_floor(), _sim.steps_for(2.0))
	_sim.step()
	assert_eq(_landed.size(), 1)
	assert_eq(_landed[0][0], Isak.COMBO_QUAKE)
	for enemy: FakeEnemy in [on_floor, other_side]:
		assert_eq(enemy.stuns.size(), 1, "Aturde a los del suelo en pantalla")
		assert_almost_eq(float(enemy.stuns[0]), 3.0 / enemy.stun_duration_s, EPS, "3 s")
		assert_almost_eq(enemy.damage_taken, 0.0, EPS, "0 de dano")
	assert_eq(flying.stuns, [], "Lo que vuela no")
	assert_eq(off_screen.stuns, [], "Fuera de la pantalla no")
	assert_true(_isak.is_compressed(), "Sigue comprimido")
	_release_down()
	_wait_not(PlayerState.COMBO_QUAKE)


func test_quake_not_on_the_ground() -> void:
	_pinch()
	assert_true(_isak.is_on_floor())
	_hold_down(0.5)
	assert_ne(_sim.state(), PlayerState.COMBO_QUAKE, "En el suelo, nada")
	_press_dash(1.0)
	assert_ne(_sim.state(), PlayerState.COMBO_EDGE, "Ni Filo en el suelo")
	assert_eq(_denied, [])


# --- Energia, Debug y Ocultarte ---

func test_without_energy_grey_spark_and_denied() -> void:
	_jump()
	_pinch()
	GameState.debug_energy = 10.0
	_press_dash(1.0)
	assert_ne(_sim.state(), PlayerState.COMBO_EDGE, "Sin energia no sale")
	assert_almost_eq(GameState.debug_energy, 10.0, EPS, "Ni cobra")
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.FIZZLE, "Chispa gris")
	assert_eq(_denied, [Isak.COMBO_DENIED_ENERGY])
	_hold_down(0.3)
	assert_ne(_sim.state(), PlayerState.COMBO_QUAKE)
	assert_eq(_denied, [Isak.COMBO_DENIED_ENERGY, Isak.COMBO_DENIED_ENERGY], "Un aviso por pulsacion")


func test_nothing_with_debug_active_or_charging() -> void:
	_activate_debug()
	_jump()
	_pinch()
	var energy: float = GameState.debug_energy
	_press_dash(1.0)
	assert_ne(_sim.state(), PlayerState.COMBO_EDGE, "Con el Debug activo no hay Filo")
	_hold_down(0.2)
	assert_ne(_sim.state(), PlayerState.COMBO_QUAKE, "Ni Sismo")
	assert_true(DebugMode.is_active(), "El Debug sigue")
	assert_almost_eq(GameState.debug_energy, energy, 1.0, "Solo lo que gasta el Debug")
	assert_eq(_denied, [Isak.COMBO_DENIED_DEBUG, Isak.COMBO_DENIED_DEBUG])
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.FIZZLE)


func test_combos_turn_off_hide_and_no_pulse_or_laser() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.upgrade_levels[&"pulso"] = 4
	_sim.input.hide_pressed = true
	_sim.step()
	assert_true(_isak.is_hidden(), "Ocultarte activo")
	var reasons: Array = []
	_isak.get_hide_mode().ended.connect(func(r: StringName) -> void: reasons.append(r))
	_sim.press_jump()
	_sim.step(4)
	assert_true(_isak.is_hidden(), "Sigue oculto en el aire")
	_isak.change_state(PlayerState.COMBO_QUAKE)
	assert_false(_isak.is_hidden(), "El combo apaga el Ocultarte")
	assert_eq(reasons, [HideMode.REASON_COMBO])
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	assert_false(_isak.can_start_laser(), "Sin laser durante el combo")
	assert_false(_isak.can_pulse(), "Ni pulso")
	_sim.input.hide_pressed = true
	_sim.step()
	assert_false(_isak.is_hidden(), "No se oculta durante el combo")


# --- Vortice, muerte y reaparicion ---

func test_warp_cuts_the_combo_and_respawn_resets() -> void:
	_jump()
	_pinch()
	_press_dash(1.0)
	assert_eq(_sim.state(), PlayerState.COMBO_EDGE)
	_isak.begin_warp(false)
	_sim.step()
	assert_ne(_sim.state(), PlayerState.COMBO_EDGE, "El vortice lo corta")
	assert_false(_isak.is_invulnerable(), "Sin la invulnerabilidad del combo")
	_isak.end_warp()
	_isak.die()
	_isak.respawn(Vector2.ZERO)
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_eq(_isak.wants_combo(), &"")
	assert_false(_isak.is_comboing())


func test_locked_in_hub_or_without_the_gestures() -> void:
	_isak.level_mode = false
	_jump()
	_isak.compress()
	assert_eq(_isak.combo_denial(Isak.COMBO_QUAKE), Isak.COMBO_DENIED_LOCKED, "En el hub no")
	_isak.level_mode = true
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, false)
	_isak.compress()
	assert_true(_isak.is_compressed())
	assert_eq(_isak.combo_denial(Isak.COMBO_QUAKE), Isak.COMBO_DENIED_LOCKED, "Sismo pide el golpe al suelo")
	assert_eq(_isak.combo_denial(Isak.COMBO_EDGE), &"", "Filo si")


# --- Aviso ---

func test_notice_reads_the_keys_from_the_input_map() -> void:
	var data: Dictionary = AbilityNotices.load_data()
	var text: String = AbilityNotices.notice_text(GameState.ABILITY_COMBO, data)
	var swipe: String = AbilityNotices.action_key_text(&"gesture_swipe", data)
	var down: String = AbilityNotices.action_key_text(&"move_down", data)
	var pinch: String = AbilityNotices.action_key_text(&"gesture_pinch", data)
	assert_false(swipe.is_empty() or down.is_empty() or pinch.is_empty())
	assert_eq(text, "Combinación en el aire · Embestida: Deslizar (%s) + abajo (%s) · Filo: Pellizcar (%s) + Deslizar · Sismo: Pellizcar + abajo" % [swipe, down, pinch])
	assert_false(text.contains("{"), "Sin marcas sin sustituir")
	assert_true(AbilityNotices.is_available(GameState.ABILITY_COMBO))
