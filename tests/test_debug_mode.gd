# Pruebas del sistema Debug Mode (scripts/autoload/debug_mode.gd): requisitos
# de entrada (habilidad desbloqueada y energia > 0), activacion con pulsacion
# larga (activation_hold_s) y desactivacion con una nueva pulsacion, progreso de
# carga por EventBus, consumo en tiempo real (solo activo, no durante la carga),
# salidas (pulsar, energia a 0, muerte, bloqueo), escala de tiempo del mundo con
# transicion, tecla K simulada y acciones del Input Map.
extends GutTest

const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const ACTION_DEBUG: StringName = &"debug"
const HUD_DEBUG_ACTIONS: Array[StringName] = [
	&"hud_debug_sync_down", &"hud_debug_sync_up", &"hud_debug_energy_down", &"hud_debug_attention_add",
]

var _saved: Dictionary = {}
var _config: DebugModeConfig = DebugModeConfig.shared()
var _progress: Array[float] = []


func before_each() -> void:
	_saved = {
		"energy": GameState.debug_energy,
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"world": GameState.current_world,
	}
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	_progress.clear()
	EventBus.debug_activation_progress_changed.connect(_on_progress)


func after_each() -> void:
	EventBus.debug_activation_progress_changed.disconnect(_on_progress)
	Input.action_release(ACTION_DEBUG)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.debug_energy = _saved.energy
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.current_world = _saved.world


func _on_progress(progress: float) -> void:
	_progress.append(progress)


## Pasos de DT que dura `seconds` de tiempo real.
func _steps(seconds: float) -> int:
	return roundi(seconds / DT)


## Avanza `seconds` de tiempo real con la accion pulsada o no.
func _run(seconds: float, held: bool) -> void:
	for i: int in _steps(seconds):
		DebugMode.step(DT, held)


## Pulsacion larga completa (activation_hold_s) y soltar.
func _activate() -> void:
	_run(_config.activation_hold_s, true)
	DebugMode.step(DT, false)


## Pulsacion corta (un paso pulsada) y soltar.
func _tap() -> void:
	DebugMode.step(DT, true)
	DebugMode.step(DT, false)


# --- Datos ---

func test_config_values() -> void:
	var c: DebugModeConfig = DebugModeConfig.load_from_file()
	assert_not_null(c)
	assert_almost_eq(c.activation_hold_s, 1.0, EPS, "Propuesta: 1 s de pulsacion larga")
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


# --- Entrada con pulsacion larga ---

func test_does_not_charge_or_enter_when_locked() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	_run(_config.activation_hold_s * 2.0, true)
	assert_false(DebugMode.is_active())
	assert_eq(DebugMode.get_state(), DebugMode.State.INACTIVE, "No carga")
	assert_eq(_progress.size(), 0, "No muestra carga")
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "Bloqueado no gasta")
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS)


func test_does_not_charge_or_enter_with_zero_energy() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = 0.0
	_run(_config.activation_hold_s * 2.0, true)
	assert_false(DebugMode.is_active())
	assert_eq(DebugMode.get_state(), DebugMode.State.INACTIVE, "No carga")
	assert_eq(_progress.size(), 0, "No muestra carga")
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS)


func test_short_hold_cancels_without_cost() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	watch_signals(EventBus)
	_run(_config.activation_hold_s - 2.0 * DT, true)
	assert_eq(DebugMode.get_state(), DebugMode.State.CHARGING)
	assert_false(DebugMode.is_active(), "Aun no llega a activation_hold_s")
	DebugMode.step(DT, false)
	assert_eq(DebugMode.get_state(), DebugMode.State.INACTIVE, "Soltar antes cancela")
	assert_almost_eq(DebugMode.get_activation_progress(), 0.0, EPS)
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "Sin coste")
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS, "Sin efecto")
	assert_signal_not_emitted(EventBus, "debug_mode_changed")
	_run(1.0, false)
	assert_false(DebugMode.is_active())


func test_full_hold_activates() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	watch_signals(EventBus)
	_run(_config.activation_hold_s - DT, true)
	assert_false(DebugMode.is_active(), "Un paso antes aun no")
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Con activation_hold_s se activa")
	assert_signal_emitted_with_parameters(EventBus, "debug_mode_changed", [true])
	assert_almost_eq(DebugMode.get_activation_progress(), 0.0, EPS, "Al activar la carga vuelve a 0")


func test_no_energy_spent_while_charging() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s - DT, true)
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "La carga no gasta")
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS, "Ni ralentiza")
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_active())
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX, EPS, "El gasto empieza tras activarse")
	DebugMode.step(DT, true)
	assert_lt(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX)


func test_progress_emitted_in_0_1() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s * 0.5, true)
	assert_almost_eq(DebugMode.get_activation_progress(), 0.5, 0.02, "A media carga, 50 %")
	_run(_config.activation_hold_s * 0.5, true)
	assert_true(DebugMode.is_active())
	assert_gt(_progress.size(), 2)
	for i: int in _progress.size():
		assert_between(_progress[i], 0.0, 1.0, "Progreso en 0..1")
	for i: int in range(1, _progress.size() - 1):
		assert_gt(_progress[i], _progress[i - 1], "Sube mientras se mantiene")
	assert_almost_eq(_progress[-2], 1.0, EPS, "Llega a 1 al completar")
	assert_almost_eq(_progress[-1], 0.0, EPS, "Y vuelve a 0 al activarse")
	# Cancelar tambien emite 0.
	DebugMode.step(DT, false)
	_tap()
	assert_false(DebugMode.is_active())
	_run(_config.fade_out_s * 2.0, false)
	_progress.clear()
	_run(_config.activation_hold_s * 0.25, true)
	DebugMode.step(DT, false)
	assert_almost_eq(_progress[-1], 0.0, EPS, "Al cancelar vuelve a 0")


func test_enters_and_exits_with_simulated_k_key() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	DebugMode.input_enabled = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await wait_physics_frames(3)
	assert_true(Input.is_action_pressed(ACTION_DEBUG), "K esta en la accion debug")
	assert_eq(DebugMode.get_state(), DebugMode.State.CHARGING, "Mantener K carga")
	await wait_physics_frames(_steps(_config.activation_hold_s))
	assert_true(DebugMode.is_active(), "Mantener K el tiempo de carga activa el Debug")
	var release := InputEventKey.new()
	release.physical_keycode = KEY_K
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await wait_physics_frames(3)
	assert_true(DebugMode.is_active(), "Soltar K no lo apaga")
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await wait_physics_frames(2)
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await wait_physics_frames(2)
	assert_false(DebugMode.is_active(), "Pulsar K de nuevo lo apaga")


# --- Activo ---

func test_release_does_not_deactivate() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_activate()
	assert_true(DebugMode.is_active(), "Soltar tras activar no lo apaga")
	_run(1.0, false)
	assert_true(DebugMode.is_active(), "Se queda activo sin mantener nada")


func test_activating_press_does_not_deactivate() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s, true)
	assert_true(DebugMode.is_active())
	_run(1.0, true)
	assert_true(DebugMode.is_active(), "Seguir manteniendo la pulsacion que lo activo no lo apaga")
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Ni soltarla")
	assert_almost_eq(DebugMode.get_activation_progress(), 0.0, EPS, "Mantener estando activo no carga nada")


func test_new_press_deactivates_with_soft_exit() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_activate()
	_run(_config.fade_in_s, false)
	watch_signals(EventBus)
	DebugMode.step(DT, true)
	assert_false(DebugMode.is_active(), "Una nueva pulsacion lo apaga")
	assert_signal_emitted_with_parameters(EventBus, "debug_mode_changed", [false])
	assert_eq(DebugMode.get_state(), DebugMode.State.EXITING, "Salida suave")
	assert_gt(DebugMode.get_intensity(), 0.0)
	# Mantener la pulsacion que lo apago no vuelve a cargar.
	_run(_config.activation_hold_s * 2.0, true)
	assert_false(DebugMode.is_active(), "La pulsacion que lo apaga no lo reactiva")
	assert_eq(DebugMode.get_state(), DebugMode.State.INACTIVE)
	var energy: float = GameState.debug_energy
	_run(0.5, false)
	assert_almost_eq(GameState.debug_energy, energy, EPS, "Apagado no gasta")


# --- Consumo ---

func test_drains_20_per_second_in_real_time() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s, true)
	_run(1.0, false)
	assert_true(DebugMode.is_active())
	assert_almost_eq(GameState.world_time_scale, _config.world_time_scale, EPS, "Mundo a x0,5")
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX - _config.drain_per_second, EPS,
			"1 s real = 20 de energia aunque el mundo vaya a x0,5")
	_run(1.0, false)
	assert_almost_eq(GameState.debug_energy, GameState.DEBUG_ENERGY_MAX - 2.0 * _config.drain_per_second, EPS)


func test_no_passive_regeneration() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_activate()
	_run(1.0, false)
	_tap()
	var after: float = GameState.debug_energy
	_run(2.0, false)
	assert_almost_eq(GameState.debug_energy, after, EPS, "Sin regeneracion pasiva")


# --- Salida ---

func test_exits_when_energy_runs_out_and_needs_new_hold() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = 10.0
	_activate()
	var expected_s: float = GameState.debug_energy / _config.drain_per_second
	_run(expected_s - 0.1, false)
	assert_true(DebugMode.is_active(), "Aun queda energia")
	_run(0.2, false)
	assert_false(DebugMode.is_active(), "Se apaga solo al llegar a 0")
	assert_almost_eq(GameState.debug_energy, 0.0, EPS)
	# Al recargar no se reactiva solo, ni con una pulsacion corta.
	GameState.add_attention_points(1)
	_run(0.5, false)
	assert_false(DebugMode.is_active(), "Recargar no lo reactiva")
	_tap()
	assert_false(DebugMode.is_active(), "Una pulsacion corta no basta")
	_activate()
	assert_true(DebugMode.is_active(), "Una nueva pulsacion larga lo reactiva")


func test_exits_on_player_death_and_lock() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_activate()
	EventBus.player_died.emit()
	assert_false(DebugMode.is_active(), "Muerte de Isak")
	_activate()
	assert_true(DebugMode.is_active())
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	assert_false(DebugMode.is_active(), "Bloquear la habilidad lo apaga")


func test_lock_cancels_charge() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s * 0.5, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	assert_almost_eq(DebugMode.get_activation_progress(), 0.0, EPS, "Bloquear corta la carga")
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s, true)
	assert_false(DebugMode.is_active(), "Hace falta una pulsacion nueva")


# --- Escala de tiempo del mundo ---

func test_world_time_scale_fades_in_and_out() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_run(_config.activation_hold_s - DT, true)
	assert_almost_eq(GameState.world_time_scale, 1.0, EPS, "La carga no ralentiza")
	watch_signals(EventBus)
	DebugMode.step(DT, true)
	assert_between(GameState.world_time_scale, _config.world_time_scale + EPS, 1.0 - EPS,
			"La escala baja de forma gradual")
	assert_signal_emitted(EventBus, "world_time_scale_changed")
	_run(_config.fade_in_s, false)
	assert_almost_eq(GameState.world_time_scale, _config.world_time_scale, EPS)
	assert_almost_eq(DebugMode.get_intensity(), 1.0, EPS)
	_tap()
	_run(_config.fade_out_s * 0.5, false)
	assert_between(GameState.world_time_scale, _config.world_time_scale + EPS, 1.0 - EPS, "Salida suave")
	_run(_config.fade_out_s, false)
	assert_eq(GameState.world_time_scale, 1.0, "Vuelve exactamente a 1")
	assert_eq(DebugMode.get_intensity(), 0.0)


func test_engine_time_scale_untouched() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	_activate()
	_run(0.5, false)
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
