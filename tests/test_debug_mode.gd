# Pruebas del sistema Debug Mode (scripts/autoload/debug_mode.gd): requisitos
# de entrada (habilidad desbloqueada y energia > 0), entrada con la tecla K
# simulada, consumo en tiempo real, salidas (soltar, energia a 0, muerte),
# escala de tiempo del mundo con transicion y acciones del Input Map.
extends GutTest

const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const ACTION_DEBUG: StringName = &"debug"
const HUD_DEBUG_ACTIONS: Array[StringName] = [
	&"hud_debug_sync_down", &"hud_debug_sync_up", &"hud_debug_energy_down", &"hud_debug_attention_add",
]

var _saved: Dictionary = {}
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_each() -> void:
	_saved = {
		"energy": GameState.debug_energy,
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"world": GameState.current_world,
	}
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func after_each() -> void:
	Input.action_release(ACTION_DEBUG)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.debug_energy = _saved.energy
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.current_world = _saved.world


## Avanza `seconds` de tiempo real con la accion mantenida o no.
func _run(seconds: float, held: bool) -> void:
	for i: int in roundi(seconds / DT):
		DebugMode.step(DT, held)


# --- Datos ---

func test_config_values() -> void:
	var c: DebugModeConfig = DebugModeConfig.load_from_file()
	assert_not_null(c)
	assert_almost_eq(c.world_time_scale, 0.5, EPS, "A4: mundo a x0,5")
	assert_almost_eq(c.drain_per_second, 20.0, EPS, "A4: 20/s")
	assert_almost_eq(GameState.DEBUG_ENERGY_MAX, 100.0, EPS, "A4: energia max 100")
	assert_gt(c.fade_in_s, 0.0)
	assert_gt(c.fade_out_s, 0.0)
	assert_true(c.hidden_platforms_solid_only_in_debug, "Propuesta: plataformas ocultas solidas solo con Debug")


func test_debug_locked_by_default() -> void:
	var fresh: Node = load("res://scripts/autoload/game_state.gd").new()
	assert_false(fresh.is_ability_unlocked(GameState.ABILITY_DEBUG), "C2: el Debug empieza bloqueado")
	fresh.free()


# --- Entrada ---

func test_does_not_enter_when_locked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	_run(0.5, true)
	assert_false(DebugMode.is_active())
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "Bloqueado no gasta")
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS)


func test_does_not_enter_with_zero_energy() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = 0.0
	_run(0.5, true)
	assert_false(DebugMode.is_active())
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS)


func test_enters_while_held_when_unlocked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	watch_signals(EventBus)
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_active())
	assert_signal_emitted_with_parameters(EventBus, "debug_mode_changed", [true])


func test_enters_with_simulated_k_key() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	DebugMode.input_enabled = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await wait_physics_frames(3)
	assert_true(Input.is_action_pressed(ACTION_DEBUG), "K esta en la accion debug")
	assert_true(DebugMode.is_active(), "Mantener K activa el Debug")
	var release := InputEventKey.new()
	release.physical_keycode = KEY_K
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await wait_physics_frames(3)
	assert_false(DebugMode.is_active(), "Soltar K lo apaga")


# --- Consumo ---

func test_drains_20_per_second_in_real_time() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(1.0, true)
	assert_true(DebugMode.is_active())
	assert_almost_eq(GameState.world_time_scale, _config.world_time_scale, EPS, "Mundo a x0,5")
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX - _config.drain_per_second, EPS,
			"1 s real = 20 de energia aunque el mundo vaya a x0,5")
	_run(1.0, true)
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX - 2.0 * _config.drain_per_second, EPS)


func test_no_passive_regeneration() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(1.0, true)
	var after: float = GameState.debug_energy
	_run(2.0, false)
	assert_almost_eq(GameState.debug_energy, after, EPS, "Sin regeneracion pasiva")


# --- Salida ---

func test_exits_on_release() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(0.5, true)
	watch_signals(EventBus)
	DebugMode.step(DT, false)
	assert_false(DebugMode.is_active())
	assert_signal_emitted_with_parameters(EventBus, "debug_mode_changed", [false])
	var energy: float = GameState.debug_energy
	_run(0.5, false)
	assert_almost_eq(GameState.debug_energy, energy, EPS, "Apagado no gasta")


func test_exits_when_energy_runs_out() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = 10.0
	var expected_s: float = 10.0 / _config.drain_per_second
	_run(expected_s - 0.1, true)
	assert_true(DebugMode.is_active(), "Aun queda energia")
	_run(0.2, true)
	assert_false(DebugMode.is_active(), "Se apaga al llegar a 0")
	assert_almost_eq(GameState.debug_energy, 0.0, EPS)
	# Recarga mientras se mantiene: no se reactiva hasta soltar y pulsar.
	GameState.add_attention_points(1)
	_run(0.2, true)
	assert_false(DebugMode.is_active(), "Tras agotarse hay que soltar")
	DebugMode.step(DT, false)
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Soltar y pulsar de nuevo lo reactiva")


func test_exits_on_player_death_and_lock() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(0.2, true)
	EventBus.player_died.emit()
	assert_false(DebugMode.is_active(), "Muerte de Isak")
	DebugMode.step(DT, false)
	_run(0.2, true)
	assert_true(DebugMode.is_active())
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	assert_false(DebugMode.is_active(), "Bloquear la habilidad lo apaga")


# --- Escala de tiempo del mundo ---

func test_world_time_scale_fades_in_and_out() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	watch_signals(EventBus)
	DebugMode.step(DT, true)
	assert_between(GameState.world_time_scale, _config.world_time_scale + EPS, 1.0 - EPS,
			"La escala baja de forma gradual")
	assert_signal_emitted(EventBus, "world_time_scale_changed")
	_run(_config.fade_in_s, true)
	assert_almost_eq(GameState.world_time_scale, _config.world_time_scale, EPS)
	assert_almost_eq(DebugMode.get_intensity(), 1.0, EPS)
	_run(_config.fade_out_s * 0.5, false)
	assert_between(GameState.world_time_scale, _config.world_time_scale + EPS, 1.0 - EPS, "Salida suave")
	_run(_config.fade_out_s, false)
	assert_eq(GameState.world_time_scale, 1.0, "Vuelve exactamente a 1")
	assert_eq(DebugMode.get_intensity(), 0.0)


func test_engine_time_scale_untouched() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(0.5, true)
	assert_eq(Engine.time_scale, 1.0, "No se usa Engine.time_scale")
	assert_almost_eq(WorldTime.scaled_delta(DT), DT * _config.world_time_scale, EPS * DT)
	assert_almost_eq(WorldTime.scale(), _config.world_time_scale, EPS)


# --- Acciones ---

func test_actions_do_not_collide() -> void:
	assert_true(InputMap.has_action(ACTION_DEBUG))
	var debug_keys: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(ACTION_DEBUG):
		if event is InputEventKey:
			debug_keys.append((event as InputEventKey).physical_keycode)
	assert_has(debug_keys, KEY_K, "Debug en K")
	var has_y: bool = InputMap.action_get_events(ACTION_DEBUG).any(func(e: InputEvent) -> bool:
		return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_Y)
	assert_true(has_y, "Debug en Y del mando")
	for action: StringName in HUD_DEBUG_ACTIONS:
		assert_true(InputMap.has_action(action), "%s existe" % action)
	# Ninguna tecla fisica esta en dos acciones del proyecto.
	var owner_of: Dictionary[int, StringName] = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		var name: String = property.name
		if not name.begins_with("input/"):
			continue
		var action: StringName = StringName(name.trim_prefix("input/"))
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if not event is InputEventKey:
				continue
			var code: int = (event as InputEventKey).physical_keycode
			assert_false(owner_of.has(code) and owner_of[code] != action,
					"Tecla %d en %s y %s" % [code, owner_of.get(code, &""), action])
			owner_of[code] = action
