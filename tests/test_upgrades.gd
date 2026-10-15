# Mejoras permanentes (data/upgrades.json, decisiones del 2026-10-14): catalogo
# valido, comprar sin puntos o sin power bank no cambia nada, comprar gasta y
# cambia el VALOR EFECTIVO (los JSON base no cambian), y la compra desde la
# pantalla provisional del hub (move_up/move_down + pulse) cambia el valor
# efectivo que usa el Isak siguiente. Guardado manual provisional en esa
# pantalla (save_game, 2026-10-15): comprar solo marca "sin guardar".
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub_placeholder.tscn")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const PATH: String = "user://test_upgrades_save.json"
const EPS: float = 0.001

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)


func after_each() -> void:
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
	var hub := HUB_SCENE.instantiate() as HubPlaceholder
	add_child_autofree(hub)
	hub.show_result("1-1", GameState.attention_points)
	assert_eq(hub.get_upgrade_ids().size(), UpgradeCatalog.shared().entries().size(), "Lista todas las mejoras")
	hub.skip_input_delay()
	# Seleccionar con el Input Map: abajo y arriba (vuelve a la primera).
	hub._unhandled_input(_action(&"move_down"))
	assert_eq(hub.get_selected_index(), 1)
	hub._unhandled_input(_action(&"move_up"))
	assert_eq(hub.get_selected_upgrade(), &"wide_pulse")
	assert_string_contains(hub.get_detail_text(), "96 px a 112 px")
	assert_string_contains(hub.get_upgrade_row_text(0), "Disponible")
	hub._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"), "Pulso compra la elegida")
	assert_eq(GameState.attention_points, 5)
	assert_eq(hub.get_line_text(&"points"), "Puntos de atención: 5")
	assert_string_contains(hub.get_upgrade_row_text(0), "Comprada")
	assert_eq(hub.get_restart_count(), 0, "Comprar no reinicia")
	# El Isak del siguiente nivel usa el radio mejorado; el JSON base no cambia.
	var isak := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(isak)
	assert_almost_eq(isak.abilities.pulse_radius_px, 112.0, EPS)
	assert_almost_eq(PlayerAbilities.load_from_file().pulse_radius_px, 96.0, EPS)
	# Sin puntos: no compra la siguiente y lo dice.
	hub._unhandled_input(_action(&"move_down"))
	hub._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"reinforced_sync"))
	assert_eq(hub.get_line_text(&"message"), "No tienes puntos suficientes")


func test_hub_input_waits_for_delay_and_fits_on_screen() -> void:
	GameState.attention_points = 100
	var hub := HUB_SCENE.instantiate() as HubPlaceholder
	add_child_autofree(hub)
	hub.show_result("1-1", GameState.attention_points)
	hub._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"wide_pulse"), "Retardo de entrada tambien para comprar")
	assert_lte(hub.get_panel_size().y, hub.get_screen_size().y, "El panel cabe en pantalla")
	assert_lte(hub.get_panel_size().x, hub.get_screen_size().x)


# --- Guardado manual provisional en la pantalla del hub (2026-10-15) ---

func test_hub_purchase_only_marks_unsaved_and_save_action_writes() -> void:
	GameState.attention_points = 30
	var hub := HUB_SCENE.instantiate() as HubPlaceholder
	add_child_autofree(hub)
	hub.show_result("1-1", GameState.attention_points)
	assert_eq(hub.get_line_text(&"save_status"), "Todo guardado")
	assert_eq(hub.get_line_text(&"help_save"), "Guardar: C / R3 (mando)", "Control leido del Input Map")
	hub.skip_input_delay()
	hub._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"))
	assert_false(FileAccess.file_exists(PATH), "Comprar no guarda")
	assert_true(GameState.has_unsaved_changes())
	assert_eq(hub.get_line_text(&"save_status"), "Sin guardar", "Indicador al comprar")
	hub._unhandled_input(_action(&"save_game"))
	assert_true(FileAccess.file_exists(PATH), "La accion save_game guarda")
	assert_false(GameState.has_unsaved_changes())
	assert_eq(hub.get_line_text(&"save_status"), "Todo guardado")
	assert_eq(hub.get_line_text(&"message"), "Copia guardada")
	assert_eq(hub.get_save_count(), 1)
	assert_eq(SaveFile.read(PATH).get("upgrades_purchased"), ["wide_pulse"])
	hub._unhandled_input(_action(&"save_game"))
	assert_eq(hub.get_line_text(&"message"), "Todo está guardado", "Sin cambios no vuelve a escribir")
	assert_eq(hub.get_save_count(), 1)
	assert_eq(hub.get_restart_count(), 0, "Guardar no reinicia")
	assert_lte(hub.get_panel_size().y, hub.get_screen_size().y, "Con las lineas de guardado sigue cabiendo")


func test_hub_save_waits_for_delay_and_is_a_save_station() -> void:
	var hub := HUB_SCENE.instantiate() as HubPlaceholder
	add_child_autofree(hub)
	assert_false(hub.can_save_now(), "Sin mostrarse no es sitio de guardado")
	GameState.mark_level_completed(&"1-1")
	hub.show_result("1-1", 0)
	assert_true(hub.can_save_now())
	assert_true(QuitGuard.can_save_here(get_tree()), "El aviso al salir ofrece guardar aqui")
	hub._unhandled_input(_action(&"save_game"))
	assert_false(FileAccess.file_exists(PATH), "Retardo de entrada tambien para guardar")
	assert_eq(QuitGuard.decide(GameState.has_unsaved_changes(), QuitGuard.can_save_here(get_tree())),
		QuitGuard.Decision.ASK_WITH_SAVE)


func test_save_action_is_c_and_r3_without_clashes() -> void:
	assert_true(InputMap.has_action(&"save_game"))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	var r3 := InputEventJoypadButton.new()
	r3.button_index = JOY_BUTTON_RIGHT_STICK
	assert_true(InputMap.event_is_action(key, &"save_game"), "C guarda")
	assert_true(InputMap.event_is_action(r3, &"save_game"), "R3 guarda")
	for action: StringName in InputMap.get_actions():
		if action == &"save_game" or String(action).begins_with("ui_"):
			continue
		assert_false(InputMap.event_is_action(key, action), "C solo guarda (%s)" % action)
		assert_false(InputMap.event_is_action(r3, action), "R3 solo guarda (%s)" % action)
