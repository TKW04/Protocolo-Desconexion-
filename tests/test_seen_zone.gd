# Zona «Visto» (seen_zone; paso 2 del plan de docs/propuesta-mundo-4.md §8, §3.5):
# activa congela 1,5 s al tocarla (sin dano); el pulso al doble check la interrumpe
# 4 s del mundo (y desde fuera de la zona); ciclo on_s / off_s con aviso de 9
# cuadros a 12 fps; la inmunidad de 0,5 s tras descongelarse evita la cadena;
# vuelve al estado inicial al reaparecer; datos del catalogo y esquema; la sala
# visto_test carga. Isak y la zona avanzan con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ZONE_SCENE: PackedScene = preload("res://scenes/levels/seen_zone.tscn")
const PATH: String = "user://test_seen_zone_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const TILE: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DEBUG, GameState.ABILITY_SHOCKWAVE]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, false)
	GameState.sync_rate = GameState.get_sync_rate_max()
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
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


## Zona de w x h con su esquina en (col, fila) relativa a Isak (los pies en y = 0).
func _zone(col: float, row: float, w: int = 1, h: int = 2, on: float = 0.0, off: float = 0.0) -> SeenZone:
	var zone := ZONE_SCENE.instantiate() as SeenZone
	zone.position = Vector2(_isak.global_position.x + col * TILE, row * TILE)
	zone.width_tiles = w
	zone.height_tiles = h
	zone.on_s = on
	zone.off_s = off
	zone.auto_process = false
	zone.isak = _isak
	_world.add_child(zone)
	return zone


## Avanza Isak y la zona juntos `n` pasos (la zona en tiempo del mundo).
func _step(zone: SeenZone, n: int = 1) -> void:
	for i: int in n:
		_sim.step()
		zone.advance(WorldTime.scaled_delta(DT))


func _pulse() -> void:
	_sim.input.pulse_pressed = true
	_sim.step()


# --- Datos ---

func test_catalog_and_config() -> void:
	var entry: Dictionary = World4ObjectsConfig.data()["types"]["seen_zone"]
	assert_eq(String(entry["scene"]), "res://scenes/levels/seen_zone.tscn")
	assert_eq(int(entry["level_params"]["width_tiles"]["max"]), 4, "1-4 tiles de ancho")
	assert_eq(int(entry["level_params"]["height_tiles"]["max"]), 3, "1-3 de alto")
	var zone := _zone(3.0, -2.0)
	assert_almost_eq(zone.freeze_s, 1.5, EPS, "Congela 1,5 s")
	assert_almost_eq(zone.get_interrupt_s(), 4.0, EPS, "Interrumpida 4 s")
	assert_almost_eq(zone.get_warn_s(), 0.75, EPS, "Aviso de 9 cuadros a 12 fps")
	assert_eq(zone.get_state(), SeenZone.State.ACTIVE, "Sin ciclo: siempre activa")
	assert_true(zone.is_help_available())


# --- Congelar ---

func test_touching_active_zone_freezes_without_damage() -> void:
	var zone := _zone(0.0, -2.0)
	var frozen: Array = []
	zone.froze_isak.connect(func(i: Isak) -> void: frozen.append(i))
	var sync: float = GameState.sync_rate
	_step(zone)
	assert_true(_isak.is_frozen(), "Activa: congela")
	assert_eq(_isak.get_frozen_source(), Isak.FREEZE_SOURCE_ZONE)
	assert_almost_eq(_isak.get_frozen_total(), 1.5, EPS)
	assert_eq(frozen, [_isak])
	assert_almost_eq(GameState.sync_rate, sync, EPS, "Congelarse no hace dano (el golpe llega al liberarse)")


func test_immunity_avoids_chain_then_refreezes() -> void:
	var zone := _zone(0.0, -2.0)
	_step(zone)
	assert_true(_isak.is_frozen())
	var steps: int = 0
	while _isak.is_frozen() and steps < _sim.steps_for(2.0):
		_step(zone)
		steps += 1
	assert_false(_isak.is_frozen(), "Se descongela a los 1,5 s")
	# 2026-10-28: al liberarse, el golpe (como un enemigo) lo saca de la zona, desde su centro.
	assert_eq(_sim.state(), PlayerState.HURT, "Golpe al liberarse")
	assert_almost_eq(GameState.sync_rate, GameState.get_sync_rate_max() - 10.0, EPS, "-10 al liberarse")
	var x: float = _isak.global_position.x
	_step(zone, _sim.frames(0.3))
	assert_false(_isak.is_frozen(), "0,5 s sin volver a congelarse")
	assert_ne(_isak.global_position.x, x, "El retroceso lo mueve")
	_isak.global_position.x = zone.get_zone_rect().get_center().x
	_step(zone, _sim.frames(0.3))
	assert_true(_isak.is_frozen(), "Si vuelve a entrar, se congela otra vez")


func test_shake_no_longer_frees_from_zone() -> void:
	var zone := _zone(0.0, -2.0)
	_step(zone)
	_sim.input.shake_pressed = true
	_step(zone)
	assert_true(_isak.is_frozen(), "Agitar (retirado el 2026-10-28) ya no libera: se espera")
	assert_false(_isak.is_shockwaving())


func test_outside_does_not_freeze() -> void:
	var zone := _zone(2.0, -2.0)
	_step(zone, 10)
	assert_false(_isak.is_frozen())


# --- Pulso al doble check ---

func test_pulse_to_check_interrupts_four_seconds_from_outside() -> void:
	# Zona a 1,5 tiles a la derecha con el doble check a la izquierda (a tiro de 96 px).
	var zone := _zone(1.5, -2.0)
	_step(zone)
	assert_false(_isak.is_frozen(), "Isak fuera")
	var events: Array = []
	zone.interrupted.connect(func() -> void: events.append(true))
	_pulse()
	assert_true(zone.is_interrupted(), "El pulso al doble check la interrumpe")
	assert_eq(events.size(), 1)
	_sim.step_until(func() -> bool: return _sim.state() == PlayerState.IDLE, _sim.steps_for(1.0))
	# Cruzarla interrumpida no congela.
	_isak.global_position.x = zone.global_position.x + 32.0
	_step(zone, 5)
	assert_false(_isak.is_frozen(), "Interrumpida no congela")
	_isak.global_position.x = zone.global_position.x - 200.0
	var left: float = zone.get_interrupt_left()
	assert_almost_eq(left, 4.0 - (_sim.frames(0.0) + 5) * DT, 0.6, "Unos 4 s")
	var n: int = 0
	while zone.is_interrupted() and n < _sim.steps_for(5.0):
		if zone.is_rearming():
			break
		_step(zone)
		n += 1
	assert_true(zone.is_rearming(), "Aviso de volver activa al final de la interrupcion")
	assert_almost_eq(zone.get_interrupt_left(), zone.get_warn_s(), 0.05)
	_step(zone, _sim.frames(0.8))
	assert_true(zone.is_active(), "Vuelve activa")


func test_pulse_out_of_reach_does_nothing() -> void:
	var zone := _zone(3.0, -2.0)
	_pulse()
	assert_true(zone.is_active(), "El doble check a mas de 96 px no se interrumpe")


func test_pulse_on_right_icon() -> void:
	var zone := _zone(-2.5, -2.0, 2, 2)
	zone.icon_side = &"right"
	_sim.input.move_axis = -1.0
	_sim.step()
	_sim.input.move_axis = 0.0
	_sim.settle()
	_pulse()
	assert_true(zone.is_interrupted(), "Doble check a la derecha")


func test_interruption_counts_world_time_with_debug() -> void:
	var zone := _zone(3.0, -2.0)
	zone.interrupt()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	var scale: float = WorldTime.scale()
	assert_lt(scale, 1.0)
	_step(zone, _sim.frames(1.0))
	assert_almost_eq(zone.get_interrupt_left(), 4.0 - 1.0 * scale, 0.05, "Tiempo del mundo")


# --- Ciclo ---

func test_cycle_states_and_warning() -> void:
	var zone := _zone(3.0, -2.0, 1, 2, 2.0, 2.0)
	assert_eq(zone.get_state(), SeenZone.State.ACTIVE, "Empieza activa")
	zone.advance(2.1)
	assert_eq(zone.get_state(), SeenZone.State.WAITING, "En espera")
	zone.advance(1.2)
	assert_eq(zone.get_state(), SeenZone.State.WARNING, "Aviso en los ultimos 0,75 s")
	zone.advance(0.6)
	assert_eq(zone.get_state(), SeenZone.State.WARNING)
	zone.advance(0.2)
	assert_eq(zone.get_state(), SeenZone.State.ACTIVE, "Activa otra vez (periodo 4 s)")


func test_waiting_does_not_freeze() -> void:
	var zone := _zone(0.0, -2.0, 1, 2, 2.0, 2.0)
	zone.phase_s = 2.5
	zone.reset()
	assert_eq(zone.get_state(), SeenZone.State.WAITING)
	_step(zone, 10)
	assert_false(_isak.is_frozen(), "En espera no congela")


func test_phase_offset_and_interrupt_pauses_cycle() -> void:
	var zone := _zone(3.0, -2.0, 1, 2, 2.0, 2.0)
	zone.phase_s = 1.0
	zone.reset()
	zone.advance(0.5)
	zone.interrupt()
	zone.advance(4.0)
	assert_eq(zone.get_state(), SeenZone.State.ACTIVE, "La cuenta del ciclo se para interrumpida")
	zone.advance(0.6)
	assert_eq(zone.get_state(), SeenZone.State.WAITING, "Y sigue donde estaba (1,5 + 0,6 s)")


func test_respawn_resets() -> void:
	var zone := _zone(3.0, -2.0, 1, 2, 2.0, 2.0)
	zone.advance(2.5)
	zone.interrupt()
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(zone.get_state(), SeenZone.State.ACTIVE, "Vuelve al estado inicial")
	assert_almost_eq(zone.get_interrupt_left(), 0.0, EPS)


# --- Sala de prueba ---

func test_visto_test_room_loads() -> void:
	var scene := load("res://scenes/levels/visto_test.tscn") as PackedScene
	assert_not_null(scene, "Sala visto_test generada")
	var level := scene.instantiate()
	add_child_autofree(level)
	var zones: Array[Node] = get_tree().get_nodes_in_group(SeenZone.GROUP)
	assert_eq(zones.size(), 3, "Tres zonas")
	var cycle := level.get_node(^"Objects/visto_ciclo") as SeenZone
	assert_eq(cycle.icon_side, &"right")
	assert_almost_eq(cycle.phase_s, 1.0, EPS)
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_SHOCKWAVE), "Sin Agitar en la sala (retirado)")
