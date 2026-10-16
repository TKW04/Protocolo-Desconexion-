# Mejoras permanentes (data/upgrades.json, decisiones del 2026-10-14): catalogo
# valido, comprar sin puntos o sin power bank no cambia nada, comprar gasta y
# cambia el VALOR EFECTIVO (los JSON base no cambian), y la compra en la tienda
# de Calc dormida del hub real (paso 8: move_up/move_down + pulse; antes en la
# pantalla provisional del hub) cambia el valor efectivo que usa el Isak
# siguiente. Guardado manual (2026-10-15): comprar solo marca "sin guardar"; se
# guarda en la copia local. Mas pruebas de la tienda en test_calc_station.gd.
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const PATH: String = "user://test_upgrades_save.json"
const EPS: float = 0.001

var _saved_path: String
var _saved_pulse: bool
var _hub: HubRoom


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


## Hub real con la tienda de Calc abierta (sin retardo de entrada).
func _open_calc() -> CalcPanel:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_hub.get_isak().input = PlayerInput.new()
	var calc: CalcStation = _hub.get_calc()
	assert_true(calc.open(_hub.get_isak()), "Calc abre la tienda")
	var panel: CalcPanel = calc.get_calc_panel()
	panel.skip_input_delay()
	return panel


func test_catalog_matches_proposal_and_targets_exist() -> void:
	var expected: Dictionary = {
		# Costes: economia del 2026-10-15, revisada (9 puntos por mapa; docs/propuesta-1-1-ampliado.md §6).
		&"wide_pulse": [&"isak_abilities.pulse_radius_px", 96.0, 112.0, 25, 0],
		&"reinforced_sync": [&"game_state.sync_rate_max", 100.0, 120.0, 45, 1],
		&"efficient_debug": [&"debug_mode.drain_per_second", 20.0, 15.0, 60, 1],
		&"extended_battery": [&"game_state.debug_energy_max", 100.0, 150.0, 35, 1],
		&"quick_start": [&"debug_mode.activation_hold_s", 1.0, 0.5, 20, 0],
		&"improved_recharge": [&"game_state.energy_per_attention_point", 10.0, 15.0, 25, 0],
	}
	var catalog := UpgradeCatalog.load_from_file()
	assert_eq(catalog.entries().size(), expected.size())
	for entry: UpgradeCatalog.Entry in catalog.entries():
		assert_true(expected.has(entry.id), String(entry.id))
		var e: Array = expected[entry.id]
		assert_eq(entry.target, e[0])
		assert_almost_eq(GameState.base_value(entry.target), float(e[1]), EPS, "Base de " + String(entry.id))
		assert_almost_eq(entry.value, float(e[2]), EPS)
		assert_eq(entry.cost_points, e[3])
		assert_eq(entry.cost_power_banks, e[4])
		assert_false(entry.name.is_empty())


func test_cannot_buy_without_points() -> void:
	GameState.attention_points = 14
	assert_eq(GameState.purchase_upgrade(&"wide_pulse"), GameState.PurchaseResult.NOT_ENOUGH_POINTS)
	assert_eq(GameState.attention_points, 14, "No gasta")
	assert_false(GameState.is_upgrade_purchased(&"wide_pulse"))
	assert_almost_eq(GameState.effective_value(&"isak_abilities.pulse_radius_px", 96.0), 96.0, EPS)


func test_cannot_buy_without_power_bank() -> void:
	GameState.attention_points = 200
	assert_eq(GameState.purchase_upgrade(&"reinforced_sync"), GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS)
	assert_eq(GameState.attention_points, 200)
	assert_almost_eq(GameState.get_sync_rate_max(), 100.0, EPS)
	assert_eq(GameState.purchase_upgrade(&"no_existe"), GameState.PurchaseResult.UNKNOWN)


func test_buying_spends_and_changes_effective_values_only() -> void:
	GameState.attention_points = 700
	GameState.power_banks = 3
	assert_eq(GameState.purchase_upgrade(&"reinforced_sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"efficient_debug"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"extended_battery"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"quick_start"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"improved_recharge"), GameState.PurchaseResult.OK)
	assert_eq(GameState.attention_points, 700 - 45 - 60 - 35 - 20 - 25)
	assert_eq(GameState.power_banks, 0)
	assert_eq(GameState.purchase_upgrade(&"reinforced_sync"), GameState.PurchaseResult.ALREADY_OWNED)
	assert_almost_eq(GameState.get_sync_rate_max(), 120.0, EPS)
	GameState.sync_rate = 500.0
	assert_almost_eq(GameState.sync_rate, 120.0, EPS, "Sync Rate hasta 120")
	assert_almost_eq(GameState.get_debug_energy_max(), 150.0, EPS)
	assert_almost_eq(DebugMode.get_drain_per_second(), 15.0, EPS)
	assert_almost_eq(DebugMode.get_activation_hold_s(), 0.5, EPS)
	assert_almost_eq(GameState.get_energy_per_attention_point(), 15.0, EPS)
	# Los datos base no cambian.
	assert_almost_eq(DebugModeConfig.load_from_file().drain_per_second, 20.0, EPS)
	assert_almost_eq(DebugMode.config.activation_hold_s, 1.0, EPS)
	assert_almost_eq(GameState.SYNC_RATE_MAX, 100.0, EPS)


func test_hub_purchase_changes_effective_pulse_radius() -> void:
	GameState.attention_points = 30
	var panel: CalcPanel = _open_calc()
	assert_eq(panel.get_upgrade_ids().size(), UpgradeCatalog.shared().entries().size(), "Lista todas las mejoras")
	# Seleccionar con el Input Map: abajo y arriba (vuelve a la primera).
	panel._unhandled_input(_action(&"move_down"))
	assert_eq(panel.get_selected_index(), 1)
	panel._unhandled_input(_action(&"move_up"))
	assert_eq(panel.get_selected_upgrade(), &"wide_pulse")
	assert_string_contains(panel.get_detail(), "96 px a 112 px")
	assert_string_contains(panel.upgrade_text(&"wide_pulse"), "Disponible")
	panel._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"), "Pulso compra la elegida")
	assert_eq(GameState.attention_points, 5)
	assert_eq(panel.get_lines()[0], "Puntos de atención: 5")
	assert_string_contains(panel.upgrade_text(&"wide_pulse"), "Comprada")
	# El Isak del siguiente nivel usa el radio mejorado; el JSON base no cambia.
	var isak := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(isak)
	assert_almost_eq(isak.abilities.pulse_radius_px, 112.0, EPS)
	assert_almost_eq(PlayerAbilities.load_from_file().pulse_radius_px, 96.0, EPS)
	# Sin puntos: no compra la siguiente y lo dice.
	panel._unhandled_input(_action(&"move_down"))
	panel._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"reinforced_sync"))
	assert_eq(panel.get_message(), "No tienes puntos suficientes")


# --- Guardado manual en el hub real (2026-10-15): comprar en Calc solo marca
# «sin guardar»; se guarda en la copia local ---

func test_hub_purchase_only_marks_unsaved_and_copy_local_writes() -> void:
	GameState.attention_points = 30
	var panel: CalcPanel = _open_calc()
	assert_eq(panel.get_lines()[2], "Todo guardado")
	panel._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"))
	assert_false(FileAccess.file_exists(PATH), "Comprar no guarda")
	assert_true(GameState.has_unsaved_changes())
	assert_eq(panel.get_lines()[2], "Sin guardar", "Indicador al comprar")
	assert_true(QuitGuard.can_save_here(get_tree()), "El aviso al salir ofrece guardar en el hub")
	var copy := (_hub.get_station(&"copia_local") as CopyLocalStation).get_copy_panel()
	assert_true(copy.save_now(), "La copia local guarda")
	assert_true(FileAccess.file_exists(PATH))
	assert_false(GameState.has_unsaved_changes())
	assert_eq(panel.get_lines()[2], "Todo guardado", "El panel de Calc se entera")
	assert_eq(SaveFile.read(PATH).get("upgrades_purchased"), ["wide_pulse"])


# La accion save_game (C / R3) se retiro (2026-10-15): se guarda en la copia
# local del hub. C y R3 quedan libres.
func test_save_action_removed_and_keys_free() -> void:
	assert_false(InputMap.has_action(&"save_game"), "Ya no hay accion save_game")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	var r3 := InputEventJoypadButton.new()
	r3.button_index = JOY_BUTTON_RIGHT_STICK
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		assert_false(InputMap.event_is_action(key, action), "C libre (%s)" % action)
		assert_false(InputMap.event_is_action(r3, action), "R3 libre (%s)" % action)

